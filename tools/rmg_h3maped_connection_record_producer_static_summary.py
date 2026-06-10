#!/usr/bin/env python3
"""Summarize the static producer surface for H3MapEd compact record +0x09.

This is a recovery checkpoint, not a native RMG behavior change. It checks the
focused Ghidra dump around the only non-stack +0x09 writer candidate currently
known from the broad offset scan.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


DEFAULT_ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_DUMP = DEFAULT_ROOT / "ghidra_connection_record_plus9_writer_dump"
DEFAULT_FIELD_SUMMARY = DEFAULT_ROOT / "connection_record_field_summary.json"
DEFAULT_OUT = DEFAULT_ROOT / "connection_record_producer_static_summary.json"

TARGET_WRITER = "004b3c03"
TARGET_WRITE_SITE = "004b3c37"
COMPACT_VECTOR_NEEDLES = ("+ 0xc8", "+0xc8", "+ 0xcc", "+0xcc")

REF_RE = re.compile(
    r"^\s*from=(?P<from>[0-9a-f]{8}) type=(?P<type>\S+) "
    r"caller=(?P<caller>\S+) caller_entry=(?P<caller_entry>\S+) instruction=(?P<instruction>.*)$",
    re.IGNORECASE,
)


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace") if path.exists() else ""


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}


def parse_references(path: Path) -> list[dict[str, str]]:
    refs: list[dict[str, str]] = []
    for line in read_text(path).splitlines():
        match = REF_RE.match(line)
        if match:
            refs.append(match.groupdict())
    return refs


def caller_files(dump_dir: Path) -> list[Path]:
    return sorted(dump_dir.glob("caller_*.txt"))


def contains_any(text: str, needles: tuple[str, ...]) -> bool:
    return any(needle in text for needle in needles)


def call_sites_in(text: str) -> list[str]:
    sites: list[str] = []
    for line in text.splitlines():
        stripped = line.strip()
        if ": CALL" in stripped:
            sites.append(stripped)
    return sites


def summarize(dump_dir: Path, field_summary_path: Path) -> dict[str, Any]:
    writer_dump = read_text(dump_dir / f"target_{TARGET_WRITER}_FUN_{TARGET_WRITER}.txt")
    writer_refs = parse_references(dump_dir / f"target_{TARGET_WRITER}_references.txt")
    field_summary = read_json(field_summary_path)

    direct_code_refs = [ref for ref in writer_refs if ref["type"] != "DATA"]
    data_refs = [ref for ref in writer_refs if ref["type"] == "DATA"]

    callers: list[dict[str, Any]] = []
    callers_touch_compact_stream = False
    for path in caller_files(dump_dir):
        text = read_text(path)
        has_compact_stream = contains_any(text, COMPACT_VECTOR_NEEDLES)
        callers_touch_compact_stream = callers_touch_compact_stream or has_compact_stream
        callers.append(
            {
                "file": str(path),
                "entry": path.name.split("_", 2)[1] if "_" in path.name else "",
                "has_generator_c8_cc_text": has_compact_stream,
                "mentions_large_runtime_vectors_0x928_0x92c": "+ 0x928" in text
                or "+0x928" in text
                or "+ 0x92c" in text
                or "+0x92c" in text,
                "calls_of_interest": [
                    site
                    for site in call_sites_in(text)
                    if "004b3c4e" in site
                    or "004b3cd2" in site
                    or "004b3d3c" in site
                    or "0049ba89" in site
                    or "004a489d" in site
                ],
            }
        )

    invariants = {
        "dump_exists": dump_dir.exists(),
        "writer_function_dump_exists": bool(writer_dump),
        "writer_has_indirect_source_call_slot_0x10": "004b3c17: CALL dword ptr [EAX + 0x10]" in writer_dump,
        "writer_copies_local_record_to_output_plus_8": "004b3c34: MOV byte ptr [EAX + 0x8],CL" in writer_dump,
        "writer_copies_local_record_to_output_plus_9": "004b3c37: MOV byte ptr [EAX + 0x9],CH" in writer_dump,
        "writer_references_are_data_vtable_refs": bool(data_refs) and not direct_code_refs,
        "focused_callers_do_not_touch_generator_c8_cc": callers and not callers_touch_compact_stream,
        "field_summary_names_plus9_border_guard_surface": field_summary.get("status")
        == "recovered_connection_record_plus9_border_guard_surface",
        "no_native_behavior_change": True,
    }
    status = (
        "partial_static_ruleout_4b3c03_direct_generator_c8_producer"
        if all(invariants.values())
        else "incomplete"
    )

    return {
        "schema_id": "h3maped_connection_record_producer_static_summary_v1",
        "status": status,
        "invariants": invariants,
        "source_artifacts": {
            "ghidra_dump_dir": str(dump_dir),
            "field_summary": str(field_summary_path),
        },
        "candidate": {
            "writer_function": "0x4b3c03",
            "writer_site": "0x4b3c37",
            "classification": (
                "copy_adapter_or_serializer_not_direct_generator_c8_producer"
                if status != "incomplete"
                else "unclassified"
            ),
            "why": [
                "The function is reached through data/vtable references, not direct RMG compact-stream call sites.",
                "It calls an indirect vtable slot +0x10 to fill a stack-local 12-byte record.",
                "It copies the local record bytes into the caller output at +0x08/+0x09.",
                "The focused owning callers do not show generator+0xc8/+0xcc compact-vector access.",
            ],
        },
        "data_vtable_references": data_refs,
        "direct_code_references": direct_code_refs,
        "focused_callers": callers,
        "human_readable_result": (
            "0x4b3c03 is still relevant as a serialization/copy family for records that contain bytes "
            "+0x08/+0x09, but this static pass does not tie it to the RMG compact connection-record "
            "stream at generator+0xc8/+0xcc. Later relation-builder evidence recovers the sampled "
            "+0x09 semantic producer as 0x49f7c4 copying the template connection Border Guard column; "
            "this summary remains only a ruleout for 0x4b3c03."
        ),
        "next_recovery_target": (
            "Use the runtime boundary summary to continue from the actual 0x4a79a3 edge/control-record "
            "iterator. The sampled 0x4a7605 ESI record is not the generator+0xc8 header itself, so the "
            "next recovery must link the selected edge/control records back to their relation-owner "
            "records before 0x4a7dcd/0x4a7dd0 selects the pair."
        ),
        "native_behavior_changed": False,
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dump-dir", type=Path, default=DEFAULT_DUMP)
    parser.add_argument("--field-summary", type=Path, default=DEFAULT_FIELD_SUMMARY)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args.dump_dir, args.field_summary)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_CONNECTION_RECORD_PRODUCER_STATIC_SUMMARY status={summary['status']} out={args.out}")
    return 0 if summary["status"] == "partial_static_ruleout_4b3c03_direct_generator_c8_producer" else 1


if __name__ == "__main__":
    raise SystemExit(main())
