#!/usr/bin/env python3
"""Create controlled h3maped.exe RMG reference artifacts.

The phase-drift audit needs reference maps with known generation identity. A
shipped `.h3m` can be parsed as corpus evidence, but it cannot prove the seed
and template identity used by h3maped.exe. This tool enforces that boundary:
reference generation must come from a committed controlled h3maped runner.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import platform
import shutil
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


DEFAULT_H3MAPED_EXE = Path("/root/Downloads/h3maped.exe")
EXPECTED_H3MAPED_SHA256 = "4480fba145c9f885942cc668d4bce430fe39c0fa482d1a6e58f96318ab857a37"
DEFAULT_OUT_ROOT = Path(".artifacts/rmg_h3maped_controlled_reference")


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def write_markdown(manifest: dict[str, Any], path: Path) -> None:
    inputs = manifest.get("inputs", {})
    identity = manifest.get("controlled_identity", {})
    lines = [
        "# Controlled h3maped Reference",
        "",
        f"- Status: `{manifest.get('status')}`",
        f"- Case: `{manifest.get('case_id')}`",
        f"- Mode: `{manifest.get('mode')}`",
        f"- h3maped SHA-256: `{manifest.get('h3maped', {}).get('sha256', '')}`",
        f"- Seed: `{inputs.get('seed', '')}`",
        f"- Players: `{inputs.get('players', '')}`",
        f"- Size: `{inputs.get('size', '')}`",
        f"- Water: `{inputs.get('water', '')}`",
        f"- Source template: `{identity.get('source_template_id', '')}`",
        f"- Source catalog index: `{identity.get('source_catalog_index', '')}`",
        "",
    ]
    if manifest.get("status") != "ready":
        lines.extend([
            "## Blocker",
            "",
            str(manifest.get("blocker", manifest.get("error", ""))),
            "",
        ])
    metrics = manifest.get("metrics", {})
    compact = metrics.get("compact", {}) if isinstance(metrics, dict) else {}
    if compact:
        lines.extend(["## Compact Metrics", ""])
        for key in ["object_count", "counts_by_category", "road_cell_count_total", "nearest_town_manhattan_min"]:
            lines.append(f"- `{key}`: `{compact.get(key)}`")
    path.write_text("\n".join(lines) + "\n")


def backend_report() -> dict[str, Any]:
    return {
        "host_platform": platform.platform(),
        "os_name": os.name,
        "is_windows_host": os.name == "nt",
        "wine": shutil.which("wine"),
        "xvfb_run": shutil.which("xvfb-run"),
        "xdotool": shutil.which("xdotool"),
        "automation_backend": "not_configured",
    }


def verify_exe(path: Path) -> dict[str, Any]:
    result: dict[str, Any] = {
        "path": str(path),
        "exists": path.exists(),
        "expected_sha256": EXPECTED_H3MAPED_SHA256,
    }
    if not path.exists():
        result["status"] = "missing"
        return result
    data = path.read_bytes()[:2]
    result["mz_header"] = data == b"MZ"
    result["size_bytes"] = path.stat().st_size
    result["sha256"] = sha256_file(path)
    result["status"] = "verified" if result["mz_header"] and result["sha256"] == EXPECTED_H3MAPED_SHA256 else "mismatch"
    return result


def build_base_manifest(args: argparse.Namespace, out_dir: Path, mode: str) -> dict[str, Any]:
    h3maped = verify_exe(args.h3maped_exe)
    return {
        "schema_id": "rmg_h3maped_controlled_reference_manifest_v1",
        "status": "initializing",
        "mode": mode,
        "case_id": args.case,
        "created_at": utc_now(),
        "tool": "tools/rmg_h3maped_controlled_reference.py",
        "output_dir": str(out_dir),
        "h3maped": h3maped,
        "inputs": {
            "seed": str(args.seed),
            "players": int(args.players),
            "human_players": int(args.human_players),
            "size": args.size,
            "width": int(args.width),
            "height": int(args.height),
            "level_count": int(args.level_count),
            "water": args.water,
            "template_id": args.template_id,
        },
        "controlled_identity": {
            "seed": str(args.seed),
            "players": int(args.players),
            "source_template_id": args.source_template_id,
            "source_catalog_index": args.source_catalog_index,
            "identity_authority": "pending_h3maped_runner",
        },
        "backend": backend_report(),
    }


def write_manifest(manifest: dict[str, Any], out_dir: Path, pretty: bool) -> tuple[Path, Path]:
    out_dir.mkdir(parents=True, exist_ok=True)
    manifest_path = out_dir / "controlled_reference_manifest.json"
    md_path = out_dir / "controlled_reference_manifest.md"
    manifest_path.write_text(json.dumps(manifest, indent=2 if pretty else None, sort_keys=True) + "\n")
    write_markdown(manifest, md_path)
    return manifest_path, md_path


def run_generate(args: argparse.Namespace, out_dir: Path) -> dict[str, Any]:
    manifest = build_base_manifest(args, out_dir, "generate")
    if manifest["h3maped"].get("status") != "verified":
        manifest["status"] = "blocked_h3maped_exe_unverified"
        manifest["blocker"] = "h3maped.exe must exist, have an MZ header, and match the pinned SHA-256 before controlled output can be generated."
        return manifest

    backend = manifest["backend"]
    if backend.get("wine"):
        probe_cmd = [str(backend["wine"]), "--version"]
        probe = subprocess.run(probe_cmd, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False)
        backend["wine_version"] = probe.stdout.strip()

    manifest["status"] = "blocked_missing_runner_backend"
    manifest["blocker"] = (
        "No committed h3maped.exe GUI automation backend exists in this repository. "
        "Install and wire a deterministic Windows/Wine automation runner. "
        "This tool intentionally refuses shipped H3M corpus files and caller-supplied maps as parity references."
    )
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--case", required=True, help="Stable case id for the artifact directory")
    parser.add_argument("--seed", required=True)
    parser.add_argument("--players", type=int, required=True)
    parser.add_argument("--human-players", type=int, default=1)
    parser.add_argument("--size", default="small")
    parser.add_argument("--width", type=int, default=36)
    parser.add_argument("--height", type=int, default=36)
    parser.add_argument("--level-count", type=int, default=1)
    parser.add_argument("--water", default="land", choices=["land", "water", "mixed"])
    parser.add_argument("--template-id", default="")
    parser.add_argument("--source-template-id", default="")
    parser.add_argument("--source-catalog-index", type=int)
    parser.add_argument("--h3maped-exe", type=Path, default=DEFAULT_H3MAPED_EXE)
    parser.add_argument("--out-root", type=Path, default=DEFAULT_OUT_ROOT)
    parser.add_argument("--allow-blocked", action="store_true", help="Return success while writing a blocked manifest")
    parser.add_argument("--pretty", action="store_true")
    args = parser.parse_args()

    out_dir = args.out_root / args.case
    manifest = run_generate(args, out_dir)
    manifest_path, md_path = write_manifest(manifest, out_dir, args.pretty)
    print(json.dumps({"status": manifest["status"], "manifest": str(manifest_path), "markdown": str(md_path)}, sort_keys=True))
    if manifest["status"] == "ready" or (args.allow_blocked and str(manifest["status"]).startswith("blocked_")):
        return 0
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
