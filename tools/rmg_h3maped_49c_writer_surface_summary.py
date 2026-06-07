#!/usr/bin/env python3
"""Summarize the H3MapEd 0x49c projection writer/serializer helper surface."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


DEFAULT_DUMP_DIR = Path(".artifacts/rmg_recovery/ghidra_49c019_49c0a6_wrapper_callers_dump")
DEFAULT_CONSTRUCTOR_SUMMARY = Path(
    ".artifacts/rmg_recovery/direct_generation_49cac2_projection_constructor_hit_trace/49c_projection_constructor_summary.json"
)

WRITER_HELPERS = {
    "0x0049be93": {
        "file": "target_0049be93_FUN_0049be93.txt",
        "internal_labels": ["0x0049bf53", "0x0049bfd0"],
        "expected_needles": [
            "0049be99: MOV ESI,dword ptr [EBP + 0x8]",
            "0049bea0: MOV EDI,ECX",
            "0049bea3: CALL 0x0049baf8",
            "0049beb8: CALL dword ptr [EAX + 0x8]",
            "0049bf09: CALL dword ptr [EAX + 0x8]",
            "0049bf8c: CALL dword ptr [EAX + 0x8]",
            "0049bfd9: CALL dword ptr [EAX + 0x8]",
            "0049c00f: CALL dword ptr [EAX + 0x8]",
        ],
    },
    "0x0049c273": {
        "file": "target_0049c273_FUN_0049c273.txt",
        "internal_labels": ["0x0049c2b7"],
        "expected_needles": [
            "0049c27b: MOV ESI,dword ptr [EBP + 0x8]",
            "0049c282: MOV EDI,ECX",
            "0049c285: CALL 0x0049baf8",
            "0049c2a2: CALL dword ptr [EAX + 0x8]",
            "0049c2f0: CALL dword ptr [EAX + 0x8]",
            "0049c316: CALL dword ptr [EAX + 0x8]",
            "0049c3cd: CALL dword ptr [EAX + 0x8]",
            "0049c3ea: CALL dword ptr [EAX + 0x8]",
        ],
    },
}

PROJECTION_METHOD_REFERENCE_FILES = {
    "0x0049c019": "target_0049c019_references.txt",
    "0x0049c0a6": "target_0049c0a6_references.txt",
}


CALL_SLOT8_RE = re.compile(r"^(?P<address>[0-9a-f]{8}): CALL dword ptr \[EAX \+ 0x8\]$", re.MULTILINE)
MOV_ECX_ESI_RE = re.compile(r"^(?P<address>[0-9a-f]{8}): MOV ECX,ESI$", re.MULTILINE)


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8") if path.exists() else ""


def normalize_address(value: str) -> str:
    return f"0x{int(value, 16):08x}"


def helper_summary(dump_dir: Path, entry: str, config: dict[str, Any]) -> dict[str, Any]:
    path = dump_dir / config["file"]
    text = read_text(path)
    slot8_calls = [normalize_address(match.group("address")) for match in CALL_SLOT8_RE.finditer(text)]
    mov_ecx_esi_sites = [normalize_address(match.group("address")) for match in MOV_ECX_ESI_RE.finditer(text)]
    return {
        "entry": entry,
        "dump": str(path),
        "exists": path.exists(),
        "internal_labels": config["internal_labels"],
        "slot8_call_count": len(slot8_calls),
        "slot8_call_sites": slot8_calls,
        "mov_ecx_esi_site_count": len(mov_ecx_esi_sites),
        "mov_ecx_esi_sites": mov_ecx_esi_sites,
        "expected_static_needles_present": all(needle in text for needle in config["expected_needles"]),
        "shape": {
            "loads_writer_from_stack_arg_0x08": "MOV ESI,dword ptr [EBP + 0x8]" in text,
            "keeps_projection_object_in_edi_from_ecx": "MOV EDI,ECX" in text,
            "calls_common_writer_preamble_49baf8": "CALL 0x0049baf8" in text,
            "dispatches_writer_slot8_repeatedly": len(slot8_calls) >= 8,
            "sets_ecx_to_writer_before_slot8": len(mov_ecx_esi_sites) >= 8,
        },
    }


def reference_summary(dump_dir: Path) -> dict[str, Any]:
    out: dict[str, Any] = {}
    for address, filename in PROJECTION_METHOD_REFERENCE_FILES.items():
        text = read_text(dump_dir / filename)
        references_to = text.split("references_from_target_function:", 1)[0]
        data_refs = re.findall(r"from=(00540b[0-9a-f]{2}) type=DATA", references_to)
        code_refs = re.findall(r"type=(?!DATA)([A-Z_]+).*instruction=", references_to)
        out[address] = {
            "file": str(dump_dir / filename),
            "data_refs": [normalize_address(ref) for ref in data_refs],
            "non_data_reference_types": code_refs,
        }
    return out


def constructor_trace_summary(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {"exists": False}
    data = json.loads(path.read_text(encoding="utf-8"))
    counts = data.get("constructor_counts", {})
    breakpoints = data.get("constructor_breakpoints", [])
    return {
        "exists": True,
        "path": str(path),
        "breakpoints_include_writer_helpers": "0x49be93" in breakpoints and "0x49c273" in breakpoints,
        "writer_helper_runtime_counts": {
            "0x0049be93": int(counts.get("0x0049be93", 0)),
            "0x0049c273": int(counts.get("0x0049c273", 0)),
        },
        "constructor_counts": counts,
    }


def summarize(dump_dir: Path, constructor_summary_path: Path) -> dict[str, Any]:
    helpers = {
        entry: helper_summary(dump_dir, entry, config)
        for entry, config in WRITER_HELPERS.items()
    }
    references = reference_summary(dump_dir)
    trace = constructor_trace_summary(constructor_summary_path)
    return {
        "schema_id": "h3maped_49c_writer_surface_summary_v1",
        "dump_dir": str(dump_dir),
        "constructor_summary": str(constructor_summary_path),
        "writer_helpers": helpers,
        "projection_method_references": references,
        "runtime_trace": trace,
        "invariants": {
            "writer_helper_dumps_exist": all(helper["exists"] for helper in helpers.values()),
            "writer_helper_static_shapes_match": all(
                helper["expected_static_needles_present"] and all(helper["shape"].values())
                for helper in helpers.values()
            ),
            "projection_methods_have_only_vtable_data_references_in_dump": all(
                item["data_refs"] and not item["non_data_reference_types"]
                for item in references.values()
            ),
            "constructor_trace_instrumented_writer_helpers": bool(trace.get("breakpoints_include_writer_helpers")),
            "writer_helpers_not_hit_in_sampled_generation_trace": all(
                count == 0 for count in trace.get("writer_helper_runtime_counts", {}).values()
            ),
        },
        "notes": [
            "0x49be93 and 0x49c273 are close projection-family helpers, but their shape is writer/serializer-like: ESI is loaded from stack arg +0x08, EDI keeps the projection object from ECX, and repeated CALL [EAX+0x08] dispatches use ECX=ESI.",
            "The sampled constructor/generation trace explicitly had breakpoints on both helpers and recorded zero hits.",
            "This narrows the missing runtime target away from these writer helpers and back to storage/consumption of projection objects whose vtables are 0x540b00 or 0x540b14.",
        ],
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dump-dir", type=Path, default=DEFAULT_DUMP_DIR)
    parser.add_argument("--constructor-summary", type=Path, default=DEFAULT_CONSTRUCTOR_SUMMARY)
    parser.add_argument("--out", type=Path, required=True)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args.dump_dir, args.constructor_summary)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    status = "pass" if all(summary["invariants"].values()) else "partial"
    print(
        "RMG_H3MAPED_49C_WRITER_SURFACE_SUMMARY "
        f"status={status} helpers={len(summary['writer_helpers'])} out={args.out}"
    )
    return 0 if status == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
