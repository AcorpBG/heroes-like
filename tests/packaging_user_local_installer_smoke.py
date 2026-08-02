#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tarfile
import zipfile
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACT_DIR = Path(
    os.environ.get(
        "HEROES_PACKAGING_INSTALLER_ARTIFACT_DIR",
        ROOT / ".artifacts" / "packaging_user_local_installer_smoke",
    )
).resolve()
REPORT_PATH = ARTIFACT_DIR / "report.json"
REPORT_ID = "PACKAGING_USER_LOCAL_INSTALLER_SMOKE"
SCHEMA_ID = "packaging_user_local_installer_smoke_v1"
VERSION = "0.1.0-alpha.1-installer-smoke"
PACKAGER = ROOT / "tools" / "package_release.py"
WINE = os.environ.get("WINE", shutil.which("wine") or "")
WINESERVER = shutil.which("wineserver") or ""
FATAL_PATTERNS = (
    "SCRIPT ERROR",
    "Parse Error",
    "ERROR:",
    "Failed loading resource",
    "No loader found",
    "Cannot open file",
    "GDExtension library not found",
    "Failed to open GDExtension library",
    "Unhandled page fault",
)
WINDOWS_MARKERS = (
    "Godot Engine v",
    "Boot.scn",
    "MainMenu.scn",
    "aurelion_map_persistence.windows.template_release.x86_64.dll",
)


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def run(
    args: list[str],
    *,
    env: dict[str, str] | None = None,
    timeout: int = 900,
) -> dict:
    process_env = os.environ.copy()
    process_env["GODOT_SILENCE_ROOT_WARNING"] = "1"
    if env:
        process_env.update(env)
    try:
        completed = subprocess.run(
            args,
            cwd=ROOT,
            env=process_env,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            errors="replace",
            check=False,
            timeout=timeout,
        )
        output = completed.stdout or ""
        return {
            "args": args,
            "returncode": completed.returncode,
            "timed_out": False,
            "fatal_matches": [pattern for pattern in FATAL_PATTERNS if pattern in output],
            "output_tail": output.splitlines()[-100:],
            "output": output,
        }
    except (OSError, subprocess.TimeoutExpired) as exc:
        output = str(exc)
        return {
            "args": args,
            "returncode": None,
            "timed_out": isinstance(exc, subprocess.TimeoutExpired),
            "fatal_matches": [pattern for pattern in FATAL_PATTERNS if pattern in output],
            "output_tail": [output],
            "output": output,
        }


def command_ok(result: dict, *, reject_fatal: bool = False) -> bool:
    return (
        result.get("returncode") == 0
        and not result.get("timed_out", False)
        and (not reject_fatal or not result.get("fatal_matches", []))
    )


def wine_path(path: Path) -> str:
    return "Z:" + str(path.resolve()).replace("/", "\\")


def linux_lifecycle(bundle: Path) -> dict:
    root = ARTIFACT_DIR / "linux-installed"
    install_dir = root / "program"
    bin_dir = root / "bin"
    applications_dir = root / "applications"
    user_data = root / "user-data" / "save.json"
    user_data.parent.mkdir(parents=True, exist_ok=True)
    user_data.write_text("preserve-linux", encoding="utf-8")
    env = {
        "HEROES_LIKE_INSTALL_DIR": str(install_dir),
        "HEROES_LIKE_BIN_DIR": str(bin_dir),
        "HEROES_LIKE_APPLICATIONS_DIR": str(applications_dir),
    }
    install = run(["sh", str(bundle / "install.sh")], env=env, timeout=60)
    launcher = bin_dir / "heroes-like"
    payload_installed = (install_dir / "heroes-like.x86_64").is_file()
    launcher_created = launcher.is_file()
    desktop_entry_created = (applications_dir / "heroes-like.desktop").is_file()
    boot = run(
        [str(launcher), "--headless", "--audio-driver", "Dummy", "--quit-after", "20"],
        timeout=90,
    ) if command_ok(install) and launcher_created else {
        "returncode": None,
        "timed_out": False,
        "fatal_matches": [],
        "output": "installer failed",
        "output_tail": ["installer failed"],
    }
    uninstall = run(["sh", str(bundle / "uninstall.sh")], env=env, timeout=60)
    return {
        "install": install,
        "boot": boot,
        "uninstall": uninstall,
        "payload_installed_before_uninstall": payload_installed,
        "launcher_created_before_uninstall": launcher_created,
        "desktop_entry_created_before_uninstall": desktop_entry_created,
        "program_removed": not install_dir.exists(),
        "launcher_removed": not launcher.exists(),
        "desktop_entry_removed": not (applications_dir / "heroes-like.desktop").exists(),
        "user_data_preserved": user_data.read_text(encoding="utf-8") == "preserve-linux",
        "ok": command_ok(install) and payload_installed and launcher_created and desktop_entry_created
            and command_ok(boot, reject_fatal=True) and command_ok(uninstall)
            and not install_dir.exists() and not launcher.exists() and user_data.is_file(),
    }


def windows_lifecycle(bundle: Path) -> dict:
    if not WINE:
        return {"ok": False, "error": "wine executable not found"}
    prefix = ARTIFACT_DIR / "wine-prefix"
    if prefix.exists():
        shutil.rmtree(prefix)
    install_dir = prefix / "drive_c" / "HeroesLikeInstall"
    start_menu_dir = prefix / "drive_c" / "HeroesLikeMenu"
    user_data = prefix / "drive_c" / "users" / "root" / "AppData" / "Roaming" / "Godot" / "app_userdata" / "Heroes Like" / "save.json"
    env = {
        "WINEPREFIX": str(prefix),
        "WINEARCH": "win64",
        "WINEDEBUG": "-all",
        "WINEDLLOVERRIDES": "dinput8=",
        "HEROES_LIKE_INSTALL_DIR": "C:\\HeroesLikeInstall",
        "HEROES_LIKE_START_MENU_DIR": "C:\\HeroesLikeMenu",
    }
    install = run([WINE, "cmd", "/c", wine_path(bundle / "install.cmd")], env=env, timeout=180)
    user_data.parent.mkdir(parents=True, exist_ok=True)
    user_data.write_text("preserve-windows", encoding="utf-8")
    boot_env = dict(env)
    boot_env["WINEDEBUG"] = "-all,+loaddll"
    boot = run(
        [
            WINE,
            wine_path(install_dir / "heroes-like.exe"),
            "--headless",
            "--audio-driver",
            "Dummy",
            "--rendering-method",
            "gl_compatibility",
            "--quit-after",
            "30",
            "--verbose",
        ],
        env=boot_env,
        timeout=180,
    ) if command_ok(install) and (install_dir / "heroes-like.exe").is_file() else {"returncode": None, "output": "installer failed", "fatal_matches": []}
    uninstall = run([WINE, "cmd", "/c", wine_path(bundle / "uninstall.cmd")], env=env, timeout=120)
    if WINESERVER and prefix.exists():
        run([WINESERVER, "-k"], env={"WINEPREFIX": str(prefix), "WINEDEBUG": "-all"}, timeout=30)
    output = str(boot.get("output", ""))
    markers = {marker: marker in output for marker in WINDOWS_MARKERS}
    return {
        "install": install,
        "boot": {key: value for key, value in boot.items() if key != "output"},
        "uninstall": uninstall,
        "boot_markers": markers,
        "program_removed": not install_dir.exists(),
        "start_menu_removed": not start_menu_dir.exists(),
        "user_data_preserved": user_data.read_text(encoding="utf-8") == "preserve-windows",
        "ok": command_ok(install) and command_ok(boot, reject_fatal=True) and all(markers.values())
            and command_ok(uninstall) and not install_dir.exists() and not start_menu_dir.exists() and user_data.is_file(),
    }


def main() -> int:
    if ARTIFACT_DIR.exists():
        shutil.rmtree(ARTIFACT_DIR)
    ARTIFACT_DIR.mkdir(parents=True)
    package = run(
        [
            sys.executable,
            str(PACKAGER),
            "--version",
            VERSION,
            "--output-dir",
            str(ARTIFACT_DIR),
            "--godot",
            os.environ.get("GODOT", "godot4"),
        ],
        timeout=900,
    )
    if not command_ok(package):
        print(f"{REPORT_ID} {json.dumps({'ok': False, 'package': package}, sort_keys=True)}")
        return 1

    archives = ARTIFACT_DIR / "archives"
    extract_root = ARTIFACT_DIR / "extracted"
    linux_archive = archives / f"heroes-like-{VERSION}-linux-x86_64.tar.gz"
    windows_archive = archives / f"heroes-like-{VERSION}-windows-x86_64.zip"
    with tarfile.open(linux_archive, "r:gz") as archive:
        archive.extractall(extract_root, filter="data")
    with zipfile.ZipFile(windows_archive, "r") as archive:
        archive.extractall(extract_root)
    linux = linux_lifecycle(extract_root / f"heroes-like-{VERSION}-linux-x86_64")
    windows = windows_lifecycle(extract_root / f"heroes-like-{VERSION}-windows-x86_64")
    report = {
        "schema_id": SCHEMA_ID,
        "report_id": REPORT_ID,
        "generated_at": utc_now(),
        "ok": bool(linux.get("ok", False) and windows.get("ok", False)),
        "package": {key: value for key, value in package.items() if key != "output"},
        "linux": linux,
        "windows": windows,
        "user_data_policy": "program uninstall preserves Godot user-data directories",
        "does_not_claim": [
            "code signing or package signing",
            "MSI, NSIS, AppImage, or system-wide installation",
            "clean native Windows hardware certification",
            "distribution-channel upload or automatic update service",
            "overall release readiness",
        ],
    }
    REPORT_PATH.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    summary = {
        "ok": report["ok"],
        "linux_install_boot_uninstall": linux.get("ok", False),
        "linux_user_data_preserved": linux.get("user_data_preserved", False),
        "windows_install_boot_uninstall": windows.get("ok", False),
        "windows_user_data_preserved": windows.get("user_data_preserved", False),
        "windows_boot_markers": windows.get("boot_markers", {}),
        "report": str(REPORT_PATH.relative_to(ROOT)),
    }
    print(f"{REPORT_ID} {json.dumps(summary, sort_keys=True)}")
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
