#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACT_DIR = ROOT / ".artifacts" / "packaging_release_bundle_manifest_report"
REPORT_PATH = ARTIFACT_DIR / "report.json"
REPORT_ID = "PACKAGING_RELEASE_BUNDLE_MANIFEST_REPORT"
SCHEMA_ID = "packaging_release_bundle_manifest_v1"
MIN_BINARY_BYTES = 500_000
MIN_PCK_BYTES = 10_000_000
MIN_NATIVE_BYTES = 100_000
FORBIDDEN_PATH_PARTS = (".git", ".godot", ".artifacts", "tmp")
FORBIDDEN_SUFFIXES = (".dll.a", ".import", ".pdb", ".ilk", ".exp", ".lib")
FORBIDDEN_NAME_TOKENS = ("template_debug",)


@dataclass(frozen=True)
class BundleSpec:
    platform_id: str
    preset_name: str
    export_dir: Path
    smoke_report: Path
    expected_schema_id: str
    required_files: dict[str, int]
    required_smoke_ok_field: str = "ok"


BUNDLE_SPECS = (
    BundleSpec(
        platform_id="linux",
        preset_name="Linux Release",
        export_dir=ROOT / ".artifacts" / "packaging_linux_export_smoke" / "export",
        smoke_report=ROOT / ".artifacts" / "packaging_linux_export_smoke" / "report.json",
        expected_schema_id="packaging_linux_export_smoke_v1",
        required_files={
            "heroes-like.x86_64": MIN_BINARY_BYTES,
            "heroes-like.pck": MIN_PCK_BYTES,
            "libaurelion_map_persistence.linux.template_release.x86_64.so": MIN_NATIVE_BYTES,
        },
    ),
    BundleSpec(
        platform_id="windows",
        preset_name="Windows Release",
        export_dir=ROOT / ".artifacts" / "packaging_windows_export_smoke" / "export",
        smoke_report=ROOT / ".artifacts" / "packaging_windows_export_smoke" / "report.json",
        expected_schema_id="packaging_windows_export_smoke_v2",
        required_files={
            "heroes-like.exe": MIN_BINARY_BYTES,
            "heroes-like.pck": MIN_PCK_BYTES,
            "aurelion_map_persistence.windows.template_release.x86_64.dll": MIN_NATIVE_BYTES,
        },
    ),
)


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def load_json(path: Path) -> dict:
    if not path.exists():
        return {}
    try:
        loaded = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}
    return loaded if isinstance(loaded, dict) else {}


def relative(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


def file_rows(export_dir: Path) -> list[dict]:
    if not export_dir.exists():
        return []
    rows: list[dict] = []
    for path in sorted(export_dir.rglob("*")):
        if not path.is_file():
            continue
        rel_path = path.relative_to(export_dir).as_posix()
        rows.append({"path": rel_path, "size_bytes": path.stat().st_size})
    return rows


def forbidden_reasons(rel_path: str) -> list[str]:
    parts = Path(rel_path).parts
    reasons: list[str] = []
    for part in FORBIDDEN_PATH_PARTS:
        if part in parts:
            reasons.append("forbidden path part: %s" % part)
    lowered = rel_path.lower()
    for suffix in FORBIDDEN_SUFFIXES:
        if lowered.endswith(suffix):
            reasons.append("forbidden suffix: %s" % suffix)
    for token in FORBIDDEN_NAME_TOKENS:
        if token in lowered:
            reasons.append("forbidden name token: %s" % token)
    return reasons


def bundle_summary(spec: BundleSpec) -> dict:
    smoke_report = load_json(spec.smoke_report)
    rows = file_rows(spec.export_dir)
    row_by_path = {str(row["path"]): row for row in rows}
    required = []
    missing_required: list[str] = []
    undersized_required: list[str] = []
    for rel_path, min_size in spec.required_files.items():
        row = row_by_path.get(rel_path)
        size = int(row.get("size_bytes", 0)) if row else 0
        required_row = {
            "path": rel_path,
            "exists": row is not None,
            "size_bytes": size,
            "min_size_bytes": min_size,
            "large_enough": size >= min_size,
        }
        required.append(required_row)
        if row is None:
            missing_required.append(rel_path)
        elif size < min_size:
            undersized_required.append(rel_path)

    expected_paths = set(spec.required_files.keys())
    unexpected = [row for row in rows if str(row["path"]) not in expected_paths]
    forbidden = []
    for row in rows:
        reasons = forbidden_reasons(str(row["path"]))
        if reasons:
            forbidden.append({"path": row["path"], "reasons": reasons})

    schema_id = str(smoke_report.get("schema_id", ""))
    smoke_ok = bool(smoke_report.get(spec.required_smoke_ok_field, False))
    ok = (
        spec.export_dir.exists()
        and spec.smoke_report.exists()
        and schema_id == spec.expected_schema_id
        and smoke_ok
        and not missing_required
        and not undersized_required
        and not unexpected
        and not forbidden
    )
    return {
        "platform_id": spec.platform_id,
        "preset_name": spec.preset_name,
        "ok": ok,
        "export_dir": relative(spec.export_dir),
        "smoke_report": relative(spec.smoke_report),
        "smoke_report_exists": spec.smoke_report.exists(),
        "smoke_schema_id": schema_id,
        "smoke_schema_expected": spec.expected_schema_id,
        "smoke_ok": smoke_ok,
        "required_files": required,
        "file_count": len(rows),
        "files": rows,
        "unexpected_files": unexpected,
        "forbidden_files": forbidden,
        "missing_required_files": missing_required,
        "undersized_required_files": undersized_required,
    }


def main() -> int:
    ARTIFACT_DIR.mkdir(parents=True, exist_ok=True)
    platform_reports = [bundle_summary(spec) for spec in BUNDLE_SPECS]
    report = {
        "schema_id": SCHEMA_ID,
        "report_id": REPORT_ID,
        "generated_at": utc_now(),
        "ok": all(bool(platform.get("ok", False)) for platform in platform_reports),
        "scope": {
            "claim": "Post-export release-bundle manifest hygiene for local Linux and Windows smoke artifacts.",
            "required_smokes": [
                "python3 tests/packaging_linux_export_smoke.py",
                "python3 tests/packaging_windows_export_smoke.py",
            ],
            "forbidden_release_bundle_content": {
                "path_parts": list(FORBIDDEN_PATH_PARTS),
                "suffixes": list(FORBIDDEN_SUFFIXES),
                "name_tokens": list(FORBIDDEN_NAME_TOKENS),
            },
            "does_not_claim": [
                "installer readiness",
                "clean-machine smoke coverage",
                "clean native Windows execution",
                "code signing",
                "package signing",
                "distribution channel metadata",
                "release readiness",
            ],
        },
        "platforms": platform_reports,
    }
    REPORT_PATH.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    summary = {
        "ok": report["ok"],
        "platforms": {str(platform["platform_id"]): bool(platform["ok"]) for platform in platform_reports},
        "unexpected_files": {
            str(platform["platform_id"]): [row["path"] for row in platform["unexpected_files"]]
            for platform in platform_reports
        },
        "forbidden_files": {
            str(platform["platform_id"]): [row["path"] for row in platform["forbidden_files"]]
            for platform in platform_reports
        },
        "report": relative(REPORT_PATH),
    }
    print(f"{REPORT_ID} {json.dumps(summary, sort_keys=True)}")
    if not report["ok"]:
        print(f"Report written to {relative(REPORT_PATH)}", file=sys.stderr)
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
