#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import sys
import time
import zipfile
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools import package_release as package_release_module

ARTIFACT_DIR = Path(
    os.environ.get(
        "HEROES_PACKAGING_INSTALLER_ARTIFACT_DIR",
        ROOT / ".artifacts" / "packaging_user_local_installer_smoke",
    )
).resolve()
REPORT_PATH = ARTIFACT_DIR / "report.json"
REPORT_ID = "PACKAGING_USER_LOCAL_INSTALLER_SMOKE"
SCHEMA_ID = "packaging_user_local_installer_smoke_v6"
VERSION = next(
    line.split('"', 2)[1]
    for line in (ROOT / "project.godot").read_text(encoding="utf-8").splitlines()
    if line.startswith('config/version="')
)
WINDOWS_NUMERIC_VERSION = package_release_module.windows_numeric_version(VERSION)
SOURCE_REVISION = "c" * 40
PACKAGER = ROOT / "tools" / "package_release.py"
WINE = os.environ.get("WINE", shutil.which("wine") or "")
WINEBOOT = shutil.which("wineboot") or ""
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
WINDOWS_UNINSTALL_REGISTRY_KEY = r"HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\Heroes Like"


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


def windows_registry_values(env: dict[str, str], registry_view: str = "64") -> dict[str, dict[str, str]]:
    query = run(
        [WINE, "reg", "query", WINDOWS_UNINSTALL_REGISTRY_KEY, f"/reg:{registry_view}"],
        env=env,
        timeout=60,
    )
    if not command_ok(query):
        return {}
    values: dict[str, dict[str, str]] = {}
    for raw_line in str(query.get("output", "")).splitlines():
        line = raw_line.strip()
        if not line or line.startswith("HKEY_"):
            continue
        fields = line.split(None, 2)
        if len(fields) == 3 and fields[1].startswith("REG_"):
            values[fields[0]] = {"type": fields[1], "value": fields[2]}
    return values


def expected_windows_uninstall_values(install_dir: str) -> dict[str, dict[str, str]]:
    quoted_uninstaller = f'"{install_dir}\\uninstall.exe"'
    return {
        "DisplayName": {"type": "REG_SZ", "value": "Aurelion Reach"},
        "DisplayVersion": {"type": "REG_SZ", "value": VERSION},
        "Publisher": {"type": "REG_SZ", "value": "Aurelion Reach contributors"},
        "InstallLocation": {"type": "REG_SZ", "value": install_dir},
        "DisplayIcon": {"type": "REG_SZ", "value": f'"{install_dir}\\heroes-like.exe",0'},
        "UninstallString": {"type": "REG_SZ", "value": quoted_uninstaller},
        "QuietUninstallString": {"type": "REG_SZ", "value": f"{quoted_uninstaller} /S"},
        "NoModify": {"type": "REG_DWORD", "value": "0x1"},
        "NoRepair": {"type": "REG_DWORD", "value": "0x1"},
    }


def windows_pe_version_summary(path: Path, string_version: str | None = None) -> dict:
    try:
        identity = package_release_module.verify_windows_pe_version(
            path,
            VERSION,
            string_version=string_version,
        )
    except (OSError, RuntimeError, ValueError) as exc:
        return {"ok": False, "path": str(path), "error": str(exc)}
    return {
        "ok": True,
        "path": str(path),
        "file_version": identity.get("file_version"),
        "product_version": identity.get("product_version"),
        "strings": identity.get("strings", {}),
    }


def wine_path(path: Path) -> str:
    return "Z:" + str(path.resolve()).replace("/", "\\")


def verify_installed_payload(install_dir: Path, expected_platform: str) -> dict:
    manifest_path = install_dir / "release-manifest.json"
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return {"ok": False, "error": str(exc), "verified_file_count": 0}
    rows = manifest.get("files")
    if not isinstance(rows, list):
        return {"ok": False, "error": "release manifest has no file rows", "verified_file_count": 0}
    errors: list[str] = []
    verified = 0
    for row in rows:
        name = str(row.get("path", "")) if isinstance(row, dict) else ""
        path = install_dir / name
        if not name or Path(name).name != name or not path.is_file():
            errors.append(f"missing or unsafe payload path: {name!r}")
            continue
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if path.stat().st_size != int(row.get("size_bytes", -1)) or digest != str(row.get("sha256", "")):
            errors.append(f"payload identity mismatch: {name}")
            continue
        verified += 1
    try:
        build_info = json.loads((install_dir / "build-info.json").read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        errors.append(f"invalid installed build info: {exc}")
        build_info = {}
    expected_build_info = {
        "schema_id": "heroes_like_build_info_v1",
        "product_id": "heroes-like",
        "version": VERSION,
        "platform": expected_platform,
        "source_revision": SOURCE_REVISION,
        "source_date_epoch": 315532800,
    }
    if build_info != expected_build_info:
        errors.append(f"installed build info identity mismatch: {expected_platform}")
    return {
        "ok": not errors and verified == len(rows),
        "expected_file_count": len(rows),
        "verified_file_count": verified,
        "build_info_verified": build_info == expected_build_info,
        "errors": errors,
    }


def program_tree_identity(install_dir: Path) -> dict[str, str]:
    if not install_dir.is_dir():
        return {}
    return {
        path.relative_to(install_dir).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
        for path in sorted(install_dir.rglob("*"))
        if path.is_file()
    }


def file_identity(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else ""


def make_owned_prior_install(install_dir: Path, legacy_name: str) -> dict[str, str]:
    manifest_path = install_dir / "release-manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    rows = manifest.get("files")
    if not isinstance(rows, list):
        raise RuntimeError("installed release manifest has no file rows")
    build_info_path = install_dir / "build-info.json"
    build_info = json.loads(build_info_path.read_text(encoding="utf-8"))
    build_info["version"] = VERSION + "-prior"
    build_info_path.write_text(json.dumps(build_info, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    legacy_path = install_dir / legacy_name
    legacy_path.write_text("owned only by prior release\n", encoding="utf-8")
    for row in rows:
        if isinstance(row, dict) and row.get("path") == "build-info.json":
            row["size_bytes"] = build_info_path.stat().st_size
            row["sha256"] = hashlib.sha256(build_info_path.read_bytes()).hexdigest()
    rows.append(
        {
            "path": legacy_name,
            "size_bytes": legacy_path.stat().st_size,
            "sha256": hashlib.sha256(legacy_path.read_bytes()).hexdigest(),
        }
    )
    manifest["version"] = VERSION + "-prior"
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return program_tree_identity(install_dir)


def make_windows_owned_prior_install(install_dir: Path, legacy_name: str) -> tuple[dict[str, str], str, int]:
    make_owned_prior_install(install_dir, legacy_name)
    manifest_path = install_dir / "release-manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    rows = list(manifest["files"])
    rows.append(
        {
            "path": "release-manifest.json",
            "size_bytes": manifest_path.stat().st_size,
            "sha256": hashlib.sha256(manifest_path.read_bytes()).hexdigest(),
        }
    )
    ownership_lines = [
        "[Ownership]",
        "Schema=heroes-like-windows-install-ownership-v1",
        "Product=heroes-like",
        "Platform=windows-x86_64",
        "Marker=heroes-like-user-local-install-v1",
        f"FileCount={len(rows)}",
    ]
    for index, row in enumerate(rows):
        ownership_lines.extend(
            [
                "",
                f"[File{index}]",
                f"Path={row['path']}",
                f"Size={row['size_bytes']}",
                f"Sha256={row['sha256']}",
            ]
        )
    ownership_path = install_dir / "install-ownership.ini"
    ownership_path.write_text("\n".join(ownership_lines) + "\n", encoding="ascii", newline="\n")
    ownership_digest = hashlib.sha256(ownership_path.read_bytes()).hexdigest()
    return program_tree_identity(install_dir), ownership_digest, ownership_path.stat().st_size


def linux_lifecycle(installer: Path) -> dict:
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
    install = run([str(installer)], env=env, timeout=120)
    unowned_dir = root / "unowned-program"
    unowned_dir.mkdir(parents=True, exist_ok=True)
    unowned_sentinel = unowned_dir / "keep.txt"
    unowned_sentinel.write_text("do not adopt\n", encoding="utf-8")
    unowned_failure = run(
        [str(installer)], env={**env, "HEROES_LIKE_INSTALL_DIR": str(unowned_dir)}, timeout=120
    ) if command_ok(install) else {
        "returncode": None,
        "timed_out": False,
        "fatal_matches": [],
        "output": "initial installer failed",
        "output_tail": ["initial installer failed"],
    }
    unowned_refused_without_mutation = (
        unowned_failure.get("returncode") not in (None, 0)
        and program_tree_identity(unowned_dir) == {"keep.txt": hashlib.sha256(b"do not adopt\n").hexdigest()}
    )
    same_version_reinstall = run([str(installer)], env=env, timeout=120) if command_ok(install) else {
        "returncode": None,
        "timed_out": False,
        "fatal_matches": [],
        "output": "initial installer failed",
        "output_tail": ["initial installer failed"],
    }
    prior_identity = make_owned_prior_install(install_dir, "legacy-linux-sidecar.dat") if command_ok(
        same_version_reinstall
    ) else {}
    precommit_env = {**env, "HEROES_LIKE_INSTALL_FAIL_PHASE": "precommit"}
    precommit_failure = run([str(installer)], env=precommit_env, timeout=120) if prior_identity else {
        "returncode": None,
        "timed_out": False,
        "fatal_matches": [],
        "output": "prior install unavailable",
        "output_tail": ["prior install unavailable"],
    }
    precommit_rollback_exact = bool(prior_identity) and program_tree_identity(install_dir) == prior_identity
    commit_env = {**env, "HEROES_LIKE_INSTALL_FAIL_PHASE": "after_backup"}
    commit_failure = run([str(installer)], env=commit_env, timeout=120) if prior_identity else {
        "returncode": None,
        "timed_out": False,
        "fatal_matches": [],
        "output": "prior install unavailable",
        "output_tail": ["prior install unavailable"],
    }
    commit_rollback_exact = bool(prior_identity) and program_tree_identity(install_dir) == prior_identity
    upgrade = run([str(installer)], env=env, timeout=120) if prior_identity else {
        "returncode": None,
        "timed_out": False,
        "fatal_matches": [],
        "output": "prior install unavailable",
        "output_tail": ["prior install unavailable"],
    }
    launcher = bin_dir / "heroes-like"
    payload_installed = (install_dir / "heroes-like.x86_64").is_file()
    payload_verification = verify_installed_payload(install_dir, "linux-x86_64")
    launcher_created = launcher.is_file()
    desktop_entry_created = (applications_dir / "heroes-like.desktop").is_file()
    stale_prior_file_removed = not (install_dir / "legacy-linux-sidecar.dat").exists()
    boot = run(
        [str(launcher), "--headless", "--audio-driver", "Dummy", "--quit-after", "20"],
        timeout=90,
    ) if command_ok(upgrade) and launcher_created else {
        "returncode": None,
        "timed_out": False,
        "fatal_matches": [],
        "output": "installer failed",
        "output_tail": ["installer failed"],
    }
    uninstall = run(["sh", str(install_dir / "uninstall.sh")], env=env, timeout=60)
    return {
        "install": install,
        "unowned_failure": unowned_failure,
        "same_version_reinstall": same_version_reinstall,
        "precommit_failure": precommit_failure,
        "commit_failure": commit_failure,
        "upgrade": upgrade,
        "boot": boot,
        "uninstall": uninstall,
        "payload_installed_before_uninstall": payload_installed,
        "payload_verification": payload_verification,
        "launcher_created_before_uninstall": launcher_created,
        "desktop_entry_created_before_uninstall": desktop_entry_created,
        "precommit_rollback_exact": precommit_rollback_exact,
        "commit_rollback_exact": commit_rollback_exact,
        "stale_prior_file_removed": stale_prior_file_removed,
        "unowned_refused_without_mutation": unowned_refused_without_mutation,
        "program_removed": not install_dir.exists(),
        "launcher_removed": not launcher.exists(),
        "desktop_entry_removed": not (applications_dir / "heroes-like.desktop").exists(),
        "user_data_preserved": user_data.read_text(encoding="utf-8") == "preserve-linux",
        "ok": command_ok(install) and unowned_refused_without_mutation and command_ok(same_version_reinstall)
            and precommit_failure.get("returncode") not in (None, 0) and precommit_rollback_exact
            and commit_failure.get("returncode") not in (None, 0) and commit_rollback_exact
            and command_ok(upgrade) and stale_prior_file_removed
            and payload_installed and payload_verification["ok"] and launcher_created and desktop_entry_created
            and command_ok(boot, reject_fatal=True) and command_ok(uninstall)
            and not install_dir.exists() and not launcher.exists() and user_data.is_file(),
    }


def windows_lifecycle(installer: Path) -> dict:
    if not WINE:
        return {"ok": False, "error": "wine executable not found"}
    prefix = ARTIFACT_DIR / "wine-prefix"
    if prefix.exists():
        shutil.rmtree(prefix)
    install_dir = prefix / "drive_c" / "HeroesLikeInstall"
    user_data = prefix / "drive_c" / "users" / "root" / "AppData" / "Roaming" / "Godot" / "app_userdata" / "Heroes Like" / "save.json"
    env = {
        "WINEPREFIX": str(prefix),
        "WINEARCH": "win64",
        "WINEDEBUG": "-all",
        "WINEDLLOVERRIDES": "dinput8=",
    }
    expected_registry = expected_windows_uninstall_values(r"C:\HeroesLikeInstall")
    setup_pe_version = windows_pe_version_summary(installer)
    prefix_init = run([WINEBOOT, "--init"], env=env, timeout=180) if WINEBOOT else {
        "returncode": None,
        "output": "wineboot executable not found",
        "fatal_matches": [],
    }
    prefix_init_wait = run([WINESERVER, "-w"], env=env, timeout=60) if WINESERVER else {
        "returncode": None,
        "output": "wineserver executable not found",
        "fatal_matches": [],
    }
    install = run(
        [WINE, wine_path(installer), "/S", "/D=C:\\HeroesLikeInstall"], env=env, timeout=240
    ) if command_ok(prefix_init) and command_ok(prefix_init_wait) else {
        "returncode": None,
        "output": "Wine prefix initialization failed",
        "fatal_matches": [],
    }
    registry_after_install = windows_registry_values(env) if command_ok(install) else {}
    install_registry_exact = registry_after_install == expected_registry
    unowned_dir = prefix / "drive_c" / "HeroesLikeUnowned"
    unowned_dir.mkdir(parents=True, exist_ok=True)
    unowned_sentinel = unowned_dir / "keep.txt"
    unowned_sentinel.write_text("do not adopt\n", encoding="utf-8")
    unowned_failure = run(
        [WINE, wine_path(installer), "/S", "/D=C:\\HeroesLikeUnowned"], env=env, timeout=240
    ) if command_ok(install) else {"returncode": None, "output": "initial installer failed", "fatal_matches": []}
    unowned_refused_without_mutation = (
        unowned_failure.get("returncode") not in (None, 0)
        and program_tree_identity(unowned_dir) == {"keep.txt": hashlib.sha256(b"do not adopt\n").hexdigest()}
    )
    unowned_failure_registry_preserved = windows_registry_values(env) == registry_after_install
    same_version_reinstall = run(
        [WINE, wine_path(installer), "/S", "/D=C:\\HeroesLikeInstall"], env=env, timeout=240
    ) if command_ok(install) else {"returncode": None, "output": "initial installer failed", "fatal_matches": []}
    if command_ok(same_version_reinstall):
        public_game_shortcuts = list(prefix.rglob("Aurelion Reach.lnk"))
        public_uninstall_shortcuts = list(prefix.rglob("Uninstall Aurelion Reach.lnk"))
        if len(public_game_shortcuts) == 1 and len(public_uninstall_shortcuts) == 1:
            public_group = public_game_shortcuts[0].parent
            legacy_group = public_group.parent / "Heroes Like"
            legacy_group.mkdir(parents=True, exist_ok=True)
            public_game_shortcuts[0].replace(legacy_group / "Heroes Like.lnk")
            public_uninstall_shortcuts[0].replace(legacy_group / "Uninstall Heroes Like.lnk")
            public_group.rmdir()
        prior_identity, prior_ownership_sha256, prior_ownership_size = make_windows_owned_prior_install(
            install_dir, "legacy-windows-sidecar.dat"
        )
        ownership_registry_sha = run(
            [WINE, "reg", "add", "HKCU\\Software\\Heroes Like", "/v", "OwnershipSha256", "/d", prior_ownership_sha256, "/f"],
            env=env,
            timeout=60,
        )
        ownership_registry_size = run(
            [WINE, "reg", "add", "HKCU\\Software\\Heroes Like", "/v", "OwnershipSize", "/d", str(prior_ownership_size), "/f"],
            env=env,
            timeout=60,
        )
        if not command_ok(ownership_registry_sha) or not command_ok(ownership_registry_size):
            prior_identity = {}
        unmanaged_registry_seed = run(
            [
                WINE, "reg", "add", WINDOWS_UNINSTALL_REGISTRY_KEY,
                "/v", "UnmanagedSentinel", "/t", "REG_SZ", "/d", "preserve", "/f", "/reg:64",
            ],
            env=env,
            timeout=60,
        )
        if not command_ok(unmanaged_registry_seed):
            prior_identity = {}
    else:
        prior_identity = {}
    legacy_shortcut_paths = [
        *prefix.rglob("Heroes Like.lnk"),
        *prefix.rglob("Uninstall Heroes Like.lnk"),
    ]
    legacy_shortcut_identity_before_failures = {str(path): file_identity(path) for path in legacy_shortcut_paths}
    registry_before_failures = windows_registry_values(env) if prior_identity else {}
    precommit_failure = run(
        [WINE, wine_path(installer), "/S", "/D=C:\\HeroesLikeInstall"],
        env={**env, "HEROES_LIKE_INSTALL_FAIL_PHASE": "precommit"},
        timeout=240,
    ) if prior_identity else {"returncode": None, "output": "prior install unavailable", "fatal_matches": []}
    precommit_rollback_exact = (
        bool(prior_identity)
        and program_tree_identity(install_dir) == prior_identity
        and {str(path): file_identity(path) for path in legacy_shortcut_paths} == legacy_shortcut_identity_before_failures
    )
    precommit_registry_preserved = bool(registry_before_failures) and windows_registry_values(env) == registry_before_failures
    commit_failure = run(
        [WINE, wine_path(installer), "/S", "/D=C:\\HeroesLikeInstall"],
        env={**env, "HEROES_LIKE_INSTALL_FAIL_PHASE": "after_backup"},
        timeout=240,
    ) if prior_identity else {"returncode": None, "output": "prior install unavailable", "fatal_matches": []}
    commit_rollback_exact = (
        bool(prior_identity)
        and program_tree_identity(install_dir) == prior_identity
        and {str(path): file_identity(path) for path in legacy_shortcut_paths} == legacy_shortcut_identity_before_failures
    )
    commit_registry_preserved = bool(registry_before_failures) and windows_registry_values(env) == registry_before_failures
    upgrade = run(
        [WINE, wine_path(installer), "/S", "/D=C:\\HeroesLikeInstall"], env=env, timeout=240
    ) if prior_identity else {"returncode": None, "output": "prior install unavailable", "fatal_matches": []}
    payload_verification = verify_installed_payload(install_dir, "windows-x86_64")
    registry_after_upgrade = windows_registry_values(env) if command_ok(upgrade) else {}
    upgrade_registry_exact = all(registry_after_upgrade.get(key) == value for key, value in expected_registry.items())
    upgrade_unmanaged_registry_preserved = registry_after_upgrade.get("UnmanagedSentinel") == {
        "type": "REG_SZ",
        "value": "preserve",
    }
    game_pe_version = windows_pe_version_summary(install_dir / "heroes-like.exe")
    stale_prior_file_removed = not (install_dir / "legacy-windows-sidecar.dat").exists()
    game_shortcuts = list(prefix.rglob("Aurelion Reach.lnk"))
    uninstall_shortcuts = list(prefix.rglob("Uninstall Aurelion Reach.lnk"))
    legacy_shortcuts_removed_on_upgrade = (
        not list(prefix.rglob("Heroes Like.lnk"))
        and not list(prefix.rglob("Uninstall Heroes Like.lnk"))
    )
    shortcut_paths = [*game_shortcuts, *uninstall_shortcuts]
    shortcut_identity_before_refusals = {str(path): file_identity(path) for path in shortcut_paths}
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
    ) if command_ok(upgrade) and (install_dir / "heroes-like.exe").is_file() else {"returncode": None, "output": "installer failed", "fatal_matches": []}
    ownership_path = install_dir / "install-ownership.ini"
    if command_ok(upgrade) and (install_dir / "uninstall.exe").is_file() and ownership_path.is_file():
        ownership_bytes = ownership_path.read_bytes()
        malformed_bytes = ownership_bytes.replace(
            b"Schema=heroes-like-windows-install-ownership-v1",
            b"Schema=heroes-like-windows-install-ownership-tampered",
            1,
        )
        ownership_path.write_bytes(malformed_bytes)
        malformed_ownership_sha = run(
            [
                WINE, "reg", "add", "HKCU\\Software\\Heroes Like", "/v", "OwnershipSha256",
                "/d", hashlib.sha256(malformed_bytes).hexdigest(), "/f",
            ],
            env=env,
            timeout=60,
        )
        malformed_ownership_size = run(
            [
                WINE, "reg", "add", "HKCU\\Software\\Heroes Like", "/v", "OwnershipSize",
                "/d", str(len(malformed_bytes)), "/f",
            ],
            env=env,
            timeout=60,
        )
        malformed_uninstall_root_before = program_tree_identity(install_dir)
        malformed_uninstall = run(
            [WINE, wine_path(install_dir / "uninstall.exe"), "/S"], env=env, timeout=180
        ) if command_ok(malformed_ownership_sha) and command_ok(malformed_ownership_size) else {
            "returncode": None,
            "output": "malformed ownership identity seed failed",
            "fatal_matches": [],
        }
        malformed_uninstall_wait = run([WINESERVER, "-w"], env=env, timeout=60) if WINESERVER else {
            "returncode": None,
            "output": "wineserver executable not found",
            "fatal_matches": [],
        }
    else:
        ownership_bytes = b""
        malformed_bytes = b""
        malformed_uninstall_root_before = {}
        malformed_ownership_sha = {"returncode": None, "output": "installer failed", "fatal_matches": []}
        malformed_ownership_size = {"returncode": None, "output": "installer failed", "fatal_matches": []}
        malformed_uninstall = {"returncode": None, "output": "installer failed", "fatal_matches": []}
        malformed_uninstall_wait = {"returncode": None, "output": "installer failed", "fatal_matches": []}
    malformed_uninstall_preserved = (
        bool(ownership_bytes)
        and malformed_bytes != ownership_bytes
        and malformed_uninstall.get("returncode") is not None
        and not malformed_uninstall.get("timed_out", False)
        and command_ok(malformed_uninstall_wait)
        and program_tree_identity(install_dir) == malformed_uninstall_root_before
        and windows_registry_values(env) == registry_after_upgrade
        and {str(path): file_identity(path) for path in shortcut_paths} == shortcut_identity_before_refusals
    )
    ownership_restore_sha = {"returncode": None, "output": "malformed refusal failed", "fatal_matches": []}
    ownership_restore_size = {"returncode": None, "output": "malformed refusal failed", "fatal_matches": []}
    if malformed_uninstall_preserved:
        ownership_path.write_bytes(ownership_bytes)
        ownership_restore_sha = run(
            [
                WINE, "reg", "add", "HKCU\\Software\\Heroes Like", "/v", "OwnershipSha256",
                "/d", hashlib.sha256(ownership_bytes).hexdigest(), "/f",
            ],
            env=env,
            timeout=60,
        )
        ownership_restore_size = run(
            [
                WINE, "reg", "add", "HKCU\\Software\\Heroes Like", "/v", "OwnershipSize",
                "/d", str(len(ownership_bytes)), "/f",
            ],
            env=env,
            timeout=60,
        )
    unowned_uninstall_sentinel = install_dir / "unowned-uninstall-sentinel.txt"
    if command_ok(upgrade) and (install_dir / "uninstall.exe").is_file():
        unowned_uninstall_sentinel.write_text("preserve\n", encoding="utf-8")
        refused_uninstall_root_before = program_tree_identity(install_dir)
        refused_uninstall = run([WINE, wine_path(install_dir / "uninstall.exe"), "/S"], env=env, timeout=180)
        refused_uninstall_wait = run([WINESERVER, "-w"], env=env, timeout=60) if WINESERVER else {
            "returncode": None,
            "output": "wineserver executable not found",
            "fatal_matches": [],
        }
    else:
        refused_uninstall_root_before = {}
        refused_uninstall = {"returncode": None, "output": "installer failed", "fatal_matches": []}
        refused_uninstall_wait = {"returncode": None, "output": "installer failed", "fatal_matches": []}
    refused_uninstall_root_preserved = (
        bool(refused_uninstall_root_before)
        and command_ok(ownership_restore_sha)
        and command_ok(ownership_restore_size)
        and command_ok(refused_uninstall_wait)
        and program_tree_identity(install_dir) == refused_uninstall_root_before
        and {str(path): file_identity(path) for path in shortcut_paths} == shortcut_identity_before_refusals
    )
    refused_uninstall_registry_preserved = (
        refused_uninstall.get("returncode") is not None
        and not refused_uninstall.get("timed_out", False)
        and command_ok(refused_uninstall_wait)
        and windows_registry_values(env) == registry_after_upgrade
    )
    unowned_uninstall_sentinel.unlink(missing_ok=True)
    uninstall = run([WINE, wine_path(install_dir / "uninstall.exe"), "/S"], env=env, timeout=180)
    uninstall_wait = run([WINESERVER, "-w"], env=env, timeout=60) if WINESERVER else {
        "returncode": None,
        "output": "wineserver executable not found",
        "fatal_matches": [],
    }
    uninstall_registry_removed = (
        command_ok(uninstall)
        and command_ok(uninstall_wait)
        and windows_registry_values(env) == {}
    )
    if WINESERVER and prefix.exists():
        run([WINESERVER, "-k"], env={"WINEPREFIX": str(prefix), "WINEDEBUG": "-all"}, timeout=30)
    output = str(boot.get("output", ""))
    markers = {marker: marker in output for marker in WINDOWS_MARKERS}
    return {
        "prefix_init": prefix_init,
        "prefix_init_wait": prefix_init_wait,
        "install": install,
        "unowned_failure": unowned_failure,
        "same_version_reinstall": same_version_reinstall,
        "precommit_failure": precommit_failure,
        "commit_failure": commit_failure,
        "upgrade": upgrade,
        "boot": {key: value for key, value in boot.items() if key != "output"},
        "uninstall": uninstall,
        "uninstall_wait": uninstall_wait,
        "malformed_uninstall": malformed_uninstall,
        "malformed_uninstall_wait": malformed_uninstall_wait,
        "malformed_ownership_sha": malformed_ownership_sha,
        "malformed_ownership_size": malformed_ownership_size,
        "ownership_restore_sha": ownership_restore_sha,
        "ownership_restore_size": ownership_restore_size,
        "refused_uninstall": refused_uninstall,
        "refused_uninstall_wait": refused_uninstall_wait,
        "boot_markers": markers,
        "payload_verification": payload_verification,
        "precommit_rollback_exact": precommit_rollback_exact,
        "commit_rollback_exact": commit_rollback_exact,
        "setup_pe_version": setup_pe_version,
        "game_pe_version": game_pe_version,
        "registry_after_install": registry_after_install,
        "install_registry_exact": install_registry_exact,
        "unowned_failure_registry_preserved": unowned_failure_registry_preserved,
        "precommit_registry_preserved": precommit_registry_preserved,
        "commit_registry_preserved": commit_registry_preserved,
        "registry_after_upgrade": registry_after_upgrade,
        "upgrade_registry_exact": upgrade_registry_exact,
        "upgrade_unmanaged_registry_preserved": upgrade_unmanaged_registry_preserved,
        "malformed_uninstall_preserved": malformed_uninstall_preserved,
        "refused_uninstall_root_preserved": refused_uninstall_root_preserved,
        "refused_uninstall_registry_preserved": refused_uninstall_registry_preserved,
        "uninstall_registry_removed": uninstall_registry_removed,
        "stale_prior_file_removed": stale_prior_file_removed,
        "unowned_refused_without_mutation": unowned_refused_without_mutation,
        "program_removed": not install_dir.exists(),
        "game_shortcut_created_before_uninstall": len(game_shortcuts) == 1,
        "uninstall_shortcut_created_before_uninstall": len(uninstall_shortcuts) == 1,
        "legacy_shortcuts_removed_on_upgrade": legacy_shortcuts_removed_on_upgrade,
        "game_shortcut_removed": not list(prefix.rglob("Aurelion Reach.lnk")) and not list(prefix.rglob("Heroes Like.lnk")),
        "uninstall_shortcut_removed": not list(prefix.rglob("Uninstall Aurelion Reach.lnk")) and not list(prefix.rglob("Uninstall Heroes Like.lnk")),
        "user_data_preserved": user_data.read_text(encoding="utf-8") == "preserve-windows",
        "ok": command_ok(prefix_init) and command_ok(prefix_init_wait)
            and command_ok(install) and install_registry_exact and setup_pe_version["ok"]
            and unowned_refused_without_mutation and unowned_failure_registry_preserved
            and command_ok(same_version_reinstall)
            and precommit_failure.get("returncode") not in (None, 0) and precommit_rollback_exact
            and precommit_registry_preserved
            and commit_failure.get("returncode") not in (None, 0) and commit_rollback_exact
            and commit_registry_preserved
            and command_ok(upgrade) and stale_prior_file_removed
            and payload_verification["ok"] and game_pe_version["ok"] and upgrade_registry_exact
            and upgrade_unmanaged_registry_preserved
            and command_ok(boot, reject_fatal=True) and all(markers.values())
            and len(game_shortcuts) == 1 and len(uninstall_shortcuts) == 1
            and legacy_shortcuts_removed_on_upgrade
            and malformed_uninstall_preserved
            and refused_uninstall_root_preserved and refused_uninstall_registry_preserved
            and command_ok(uninstall) and command_ok(uninstall_wait)
            and uninstall_registry_removed and not install_dir.exists()
            and not list(prefix.rglob("Aurelion Reach.lnk"))
            and not list(prefix.rglob("Uninstall Aurelion Reach.lnk"))
            and not list(prefix.rglob("Heroes Like.lnk"))
            and not list(prefix.rglob("Uninstall Heroes Like.lnk")) and user_data.is_file(),
    }


def windows_archive_lifecycle(archive: Path) -> dict:
    if not WINE:
        return {"ok": False, "error": "wine executable not found"}
    bundle_parent = ARTIFACT_DIR / "windows archive bundle"
    with zipfile.ZipFile(archive, "r") as handle:
        handle.extractall(bundle_parent)
    bundle_roots = [path for path in bundle_parent.iterdir() if path.is_dir()]
    if len(bundle_roots) != 1:
        return {"ok": False, "error": f"expected one archive bundle root, found {len(bundle_roots)}"}
    installer = bundle_roots[0] / "install.cmd"
    prefix = ARTIFACT_DIR / "wine-prefix-archive"
    if prefix.exists():
        shutil.rmtree(prefix)
    install_dir = prefix / "drive_c" / "HeroesLikeArchiveInstall"
    start_menu_dir = prefix / "drive_c" / "HeroesLikeArchiveMenu"
    launcher = start_menu_dir / "Aurelion Reach.cmd"
    legacy_launcher = start_menu_dir / "Heroes Like.cmd"
    user_data = (
        prefix / "drive_c" / "users" / "root" / "AppData" / "Roaming" / "Godot"
        / "app_userdata" / "Heroes Like" / "archive-save.json"
    )
    env = {
        "WINEPREFIX": str(prefix),
        "WINEARCH": "win64",
        "WINEDEBUG": "-all",
        "WINEDLLOVERRIDES": "dinput8=",
        "HEROES_LIKE_INSTALL_DIR": "C:\\HeroesLikeArchiveInstall",
        "HEROES_LIKE_START_MENU_DIR": "C:\\HeroesLikeArchiveMenu",
    }

    def run_installer(extra_env: dict[str, str] | None = None) -> dict:
        return run(
            [WINE, "cmd", "/d", "/c", wine_path(installer)],
            env={**env, **(extra_env or {})},
            timeout=240,
        )

    install = run_installer()
    unowned_dir = prefix / "drive_c" / "HeroesLikeArchiveUnowned"
    unowned_dir.mkdir(parents=True, exist_ok=True)
    unowned_sentinel = unowned_dir / "keep.txt"
    unowned_sentinel.write_text("do not adopt\n", encoding="utf-8")
    unowned_failure = run(
        [WINE, "cmd", "/d", "/c", wine_path(installer)],
        env={**env, "HEROES_LIKE_INSTALL_DIR": "C:\\HeroesLikeArchiveUnowned"},
        timeout=240,
    ) if command_ok(install) else {"returncode": None, "output": "initial installer failed", "fatal_matches": []}
    unowned_refused_without_mutation = (
        unowned_failure.get("returncode") not in (None, 0)
        and program_tree_identity(unowned_dir) == {"keep.txt": hashlib.sha256(b"do not adopt\n").hexdigest()}
    )
    same_version_reinstall = run_installer() if command_ok(install) else {
        "returncode": None, "output": "initial installer failed", "fatal_matches": []
    }
    if command_ok(same_version_reinstall) and launcher.is_file():
        launcher.replace(legacy_launcher)
    prior_identity = make_owned_prior_install(
        install_dir, "legacy-windows-archive-sidecar.dat"
    ) if command_ok(same_version_reinstall) else {}
    prior_launcher_identity = file_identity(legacy_launcher)
    precommit_failure = run_installer({"HEROES_LIKE_INSTALL_FAIL_PHASE": "precommit"}) if prior_identity else {
        "returncode": None, "output": "prior install unavailable", "fatal_matches": []
    }
    precommit_rollback_exact = (
        bool(prior_identity)
        and program_tree_identity(install_dir) == prior_identity
        and file_identity(legacy_launcher) == prior_launcher_identity
    )
    commit_failure = run_installer({"HEROES_LIKE_INSTALL_FAIL_PHASE": "after_backup"}) if prior_identity else {
        "returncode": None, "output": "prior install unavailable", "fatal_matches": []
    }
    commit_rollback_exact = (
        bool(prior_identity)
        and program_tree_identity(install_dir) == prior_identity
        and file_identity(legacy_launcher) == prior_launcher_identity
    )
    upgrade = run_installer() if prior_identity else {
        "returncode": None, "output": "prior install unavailable", "fatal_matches": []
    }
    payload_verification = verify_installed_payload(install_dir, "windows-x86_64")
    stale_prior_file_removed = not (install_dir / "legacy-windows-archive-sidecar.dat").exists()
    legacy_launcher_removed_on_upgrade = not legacy_launcher.exists()
    user_data.parent.mkdir(parents=True, exist_ok=True)
    user_data.write_text("preserve-windows-archive", encoding="utf-8")
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
        ],
        env=env,
        timeout=180,
    ) if command_ok(upgrade) else {"returncode": None, "output": "installer failed", "fatal_matches": []}
    uninstall = run(
        [WINE, "cmd", "/d", "/c", "C:\\HeroesLikeArchiveInstall\\uninstall.cmd"],
        env=env,
        timeout=180,
    )
    for _attempt in range(100):
        if not install_dir.exists() and not start_menu_dir.exists():
            break
        time.sleep(0.1)
    if WINESERVER and prefix.exists():
        run([WINESERVER, "-k"], env={"WINEPREFIX": str(prefix), "WINEDEBUG": "-all"}, timeout=30)
    return {
        "install": install,
        "unowned_failure": unowned_failure,
        "same_version_reinstall": same_version_reinstall,
        "precommit_failure": precommit_failure,
        "commit_failure": commit_failure,
        "upgrade": upgrade,
        "boot": {key: value for key, value in boot.items() if key != "output"},
        "uninstall": uninstall,
        "payload_verification": payload_verification,
        "precommit_rollback_exact": precommit_rollback_exact,
        "commit_rollback_exact": commit_rollback_exact,
        "stale_prior_file_removed": stale_prior_file_removed,
        "legacy_launcher_removed_on_upgrade": legacy_launcher_removed_on_upgrade,
        "unowned_refused_without_mutation": unowned_refused_without_mutation,
        "launcher_created_before_uninstall": bool(prior_launcher_identity),
        "program_removed": not install_dir.exists(),
        "launcher_removed": not launcher.exists(),
        "user_data_preserved": user_data.read_text(encoding="utf-8") == "preserve-windows-archive",
        "ok": command_ok(install) and unowned_refused_without_mutation and command_ok(same_version_reinstall)
            and precommit_failure.get("returncode") not in (None, 0) and precommit_rollback_exact
            and commit_failure.get("returncode") not in (None, 0) and commit_rollback_exact
            and command_ok(upgrade) and stale_prior_file_removed and legacy_launcher_removed_on_upgrade
            and payload_verification["ok"]
            and bool(prior_launcher_identity) and command_ok(boot, reject_fatal=True)
            and command_ok(uninstall) and not install_dir.exists() and not launcher.exists()
            and user_data.is_file(),
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
            "--source-revision",
            SOURCE_REVISION,
            "--output-dir",
            str(ARTIFACT_DIR),
            "--godot",
            os.environ.get("GODOT", "godot4"),
        ],
        env={"SOURCE_DATE_EPOCH": "315532800"},
        timeout=900,
    )
    if not command_ok(package):
        print(f"{REPORT_ID} {json.dumps({'ok': False, 'package': package}, sort_keys=True)}")
        return 1

    archives = ARTIFACT_DIR / "archives"
    linux_installer = archives / f"heroes-like-{VERSION}-linux-x86_64.run"
    windows_installer = archives / f"heroes-like-{VERSION}-windows-x86_64.setup.exe"
    windows_archive = archives / f"heroes-like-{VERSION}-windows-x86_64.zip"
    linux = linux_lifecycle(linux_installer)
    windows = windows_lifecycle(windows_installer)
    windows_archive_result = windows_archive_lifecycle(windows_archive)
    report = {
        "schema_id": SCHEMA_ID,
        "report_id": REPORT_ID,
        "generated_at": utc_now(),
        "version": VERSION,
        "windows_numeric_version": WINDOWS_NUMERIC_VERSION,
        "ok": bool(
            linux.get("ok", False)
            and windows.get("ok", False)
            and windows_archive_result.get("ok", False)
        ),
        "package": {key: value for key, value in package.items() if key != "output"},
        "linux": linux,
        "windows": windows,
        "windows_archive": windows_archive_result,
        "user_data_policy": "program uninstall preserves Godot user-data directories",
        "does_not_claim": [
            "code signing or package signing",
            "MSI, AppImage, or system-wide installation",
            "clean native Windows hardware certification",
            "distribution-channel upload or automatic update service",
            "overall release readiness",
        ],
    }
    REPORT_PATH.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    summary = {
        "ok": report["ok"],
        "linux_install_boot_uninstall": linux.get("ok", False),
        "linux_upgrade_rollback_exact": bool(linux.get("precommit_rollback_exact") and linux.get("commit_rollback_exact")),
        "linux_user_data_preserved": linux.get("user_data_preserved", False),
        "windows_install_boot_uninstall": windows.get("ok", False),
        "windows_upgrade_rollback_exact": bool(windows.get("precommit_rollback_exact") and windows.get("commit_rollback_exact")),
        "windows_registry_transaction_exact": bool(
            windows.get("install_registry_exact")
            and windows.get("precommit_registry_preserved")
            and windows.get("commit_registry_preserved")
            and windows.get("upgrade_registry_exact")
            and windows.get("upgrade_unmanaged_registry_preserved")
            and windows.get("refused_uninstall_registry_preserved")
            and windows.get("uninstall_registry_removed")
        ),
        "windows_pe_versions_coherent": bool(
            windows.get("setup_pe_version", {}).get("ok")
            and windows.get("game_pe_version", {}).get("ok")
        ),
        "windows_user_data_preserved": windows.get("user_data_preserved", False),
        "windows_boot_markers": windows.get("boot_markers", {}),
        "windows_archive_install_boot_uninstall": windows_archive_result.get("ok", False),
        "windows_archive_upgrade_rollback_exact": bool(
            windows_archive_result.get("precommit_rollback_exact")
            and windows_archive_result.get("commit_rollback_exact")
        ),
        "windows_archive_user_data_preserved": windows_archive_result.get("user_data_preserved", False),
        "report": str(REPORT_PATH.relative_to(ROOT)) if REPORT_PATH.is_relative_to(ROOT) else str(REPORT_PATH),
    }
    print(f"{REPORT_ID} {json.dumps(summary, sort_keys=True)}")
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
