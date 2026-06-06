#!/usr/bin/env python3
"""Bootstrap a reproducible Ghidra project for H3MapEd RMG recovery."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import urllib.request
import zipfile
from pathlib import Path


DEFAULT_GHIDRA_URL = "https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_12.1.2_build/ghidra_12.1.2_PUBLIC_20260605.zip"
DEFAULT_H3MAPED = Path(".artifacts/rmg_20seed_2p_small_h3maped_20260605/small_2p_seed_58_manual20/runtime/h3maped.exe")
DEFAULT_TOOLS_DIR = Path(".artifacts/tools")
DEFAULT_PROJECT_DIR = Path("tmp/rmg_recovery/ghidra_project")
DEFAULT_MANIFEST = Path(".artifacts/rmg_recovery/ghidra_bootstrap_manifest.json")


def download(url: str, out: Path) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    if out.exists() and out.stat().st_size > 0:
        return
    with urllib.request.urlopen(url, timeout=60) as response, out.open("wb") as fh:
        shutil.copyfileobj(response, fh)


def find_analyze_headless(tools_dir: Path) -> Path | None:
    existing = shutil.which("analyzeHeadless")
    if existing:
        return Path(existing)
    for script in tools_dir.glob("ghidra_*/support/*.sh"):
        try:
            script.chmod(script.stat().st_mode | 0o755)
        except OSError:
            pass
    candidates = sorted(tools_dir.glob("ghidra_*/support/analyzeHeadless"))
    for candidate in candidates:
        try:
            candidate.chmod(candidate.stat().st_mode | 0o755)
        except OSError:
            pass
    return candidates[-1] if candidates else None


def extract_ghidra(zip_path: Path, tools_dir: Path) -> Path:
    before = set(tools_dir.glob("ghidra_*"))
    with zipfile.ZipFile(zip_path) as archive:
        archive.extractall(tools_dir)
    after = set(tools_dir.glob("ghidra_*"))
    new_dirs = sorted(after - before)
    if new_dirs:
        return new_dirs[-1]
    existing = sorted(after)
    if not existing:
        raise RuntimeError("Ghidra zip extraction produced no ghidra_* directory")
    return existing[-1]


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--h3maped-exe", type=Path, default=DEFAULT_H3MAPED)
    parser.add_argument("--tools-dir", type=Path, default=DEFAULT_TOOLS_DIR)
    parser.add_argument("--project-dir", type=Path, default=DEFAULT_PROJECT_DIR)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--ghidra-url", default=DEFAULT_GHIDRA_URL)
    parser.add_argument("--download", action="store_true", help="Download Ghidra when analyzeHeadless is not already available.")
    parser.add_argument("--import-project", action="store_true", help="Run analyzeHeadless import for h3maped.exe.")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    repo_root = Path.cwd()
    exe = (repo_root / args.h3maped_exe).resolve() if not args.h3maped_exe.is_absolute() else args.h3maped_exe.resolve()
    tools_dir = (repo_root / args.tools_dir).resolve() if not args.tools_dir.is_absolute() else args.tools_dir.resolve()
    project_dir = (repo_root / args.project_dir).resolve() if not args.project_dir.is_absolute() else args.project_dir.resolve()
    manifest_path = (repo_root / args.manifest).resolve() if not args.manifest.is_absolute() else args.manifest.resolve()
    tools_dir.mkdir(parents=True, exist_ok=True)
    project_dir.mkdir(parents=True, exist_ok=True)

    ghidra_zip = tools_dir / Path(args.ghidra_url).name
    analyze = find_analyze_headless(tools_dir)
    ghidra_dir = None
    download_status = "not_needed" if analyze else "not_requested"
    if analyze is None and args.download:
        download(args.ghidra_url, ghidra_zip)
        ghidra_dir = extract_ghidra(ghidra_zip, tools_dir)
        analyze = find_analyze_headless(tools_dir)
        download_status = "downloaded"

    import_status = "not_requested"
    import_returncode = None
    import_stdout = ""
    import_stderr = ""
    if args.import_project:
        if analyze is None:
            import_status = "blocked_missing_analyzeHeadless"
        elif not exe.exists():
            import_status = "blocked_missing_h3maped"
        else:
            command = [
                str(analyze),
                str(project_dir),
                "h3maped_rmg_recovery",
                "-import",
                str(exe),
                "-overwrite",
            ]
            completed = subprocess.run(
                command,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                env=os.environ.copy(),
                timeout=900,
            )
            import_returncode = completed.returncode
            import_stdout = completed.stdout[-12000:]
            import_stderr = completed.stderr[-12000:]
            import_status = "pass" if completed.returncode == 0 else "failed"

    manifest = {
        "schema_id": "h3maped_ghidra_bootstrap_v1",
        "h3maped_exe": str(exe),
        "tools_dir": str(tools_dir),
        "ghidra_url": args.ghidra_url,
        "ghidra_zip": str(ghidra_zip),
        "ghidra_dir": str(ghidra_dir) if ghidra_dir else "",
        "analyze_headless": str(analyze) if analyze else "",
        "download_status": download_status,
        "project_dir": str(project_dir),
        "project_name": "h3maped_rmg_recovery",
        "import_status": import_status,
        "import_returncode": import_returncode,
        "import_stdout_tail": import_stdout,
        "import_stderr_tail": import_stderr,
    }
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_GHIDRA_BOOTSTRAP status={import_status} analyze={analyze or ''} manifest={manifest_path}")
    if args.import_project and import_status != "pass":
        return 1
    if analyze is None:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
