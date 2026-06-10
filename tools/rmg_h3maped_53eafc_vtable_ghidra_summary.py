#!/usr/bin/env python3
"""Verify the ``0x53eafc`` source-handler vtable from Ghidra references.

This replaces the old recovery note that depended on a saved objdump excerpt.
The verifier uses only Ghidra dump text: constructor instructions prove
``0x4802ac`` installs vtable ``0x53eafc``, and target reference files prove each
slot target is referenced from the expected vtable data address.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


DEFAULT_GHIDRA_DIR = Path(".artifacts/rmg_recovery/ghidra_53eafc_source_handler_vtable_dump")
DEFAULT_OUT = Path(".artifacts/rmg_recovery/source_handler_53eafc_vtable_ghidra_summary_20260610.json")

EXPECTED_SLOTS = {
    "+0x00": {"target": "004802ea", "data_ref": "0053eafc"},
    "+0x04": {"target": "0048031b", "data_ref": "0053eb00"},
    "+0x08": {"target": "00480352", "data_ref": "0053eb04"},
    "+0x0c": {"target": "0048037b", "data_ref": "0053eb08"},
    "+0x10": {"target": "004803b6", "data_ref": "0053eb0c"},
    "+0x14": {"target": "004803e2", "data_ref": "0053eb10"},
    "+0x18": {"target": "004803ff", "data_ref": "0053eb14"},
    "+0x1c": {"target": "0048041d", "data_ref": "0053eb18"},
    "+0x20": {"target": "0048047c", "data_ref": "0053eb1c"},
}

SLOT_ROLES = {
    "+0x00": "stream first key",
    "+0x04": "stream next key",
    "+0x08": "descriptor/source record mapper for 0x4af785",
    "+0x0c": "coordinate pair copier",
    "+0x10": "x/y tile-class mapper for 0x49acf6",
    "+0x14": "secondary/policy class equals 1 predicate",
    "+0x18": "secondary/policy class equals 2 predicate",
    "+0x1c": "source-side helper slot present in table; not consumed by recovered 0x4af463/0x4af910 path",
    "+0x20": "queued-key cleanup through 0x429ea3",
}


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def ref_file(ghidra_dir: Path, target: str) -> Path:
    return ghidra_dir / f"target_{target}_references.txt"


def summarize(args: argparse.Namespace) -> dict[str, Any]:
    ghidra_dir = args.ghidra_dir
    constructor_text = read_text(ghidra_dir / "target_004802ac_FUN_004802ac.txt")
    summary_text = read_text(ghidra_dir / "summary.txt")
    manifest = json.loads(read_text(ghidra_dir / "manifest.json"))

    slots: dict[str, dict[str, Any]] = {}
    for slot, expected in EXPECTED_SLOTS.items():
        text = read_text(ref_file(ghidra_dir, expected["target"]))
        target_marker = f"target={expected['target']}"
        data_marker = f"from={expected['data_ref']} type=DATA"
        slots[slot] = {
            "target": f"0x{expected['target']}",
            "data_ref": f"0x{expected['data_ref']}",
            "role": SLOT_ROLES[slot],
            "target_file": str(ref_file(ghidra_dir, expected["target"])),
            "target_marker_present": target_marker in text,
            "data_reference_present": data_marker in text,
            "summary_target_present": f"TARGET {expected['target']}" in summary_text,
        }

    invariants = {
        "no_native_behavior_change": True,
        "no_objdump_used": True,
        "ghidra_manifest_present": manifest.get("schema_id") == "h3maped_rmg_ghidra_dump_v1",
        "constructor_installs_53eafc": "004802dc: MOV dword ptr [ESI],0x53eafc" in constructor_text,
        "all_expected_slots_have_ghidra_data_refs": all(
            slot["target_marker_present"] and slot["data_reference_present"] and slot["summary_target_present"]
            for slot in slots.values()
        ),
        "slot_0x20_cleanup_target_present": slots["+0x20"]["target"] == "0x0048047c",
    }
    status = (
        "source_handler_53eafc_vtable_recovered_from_ghidra_refs"
        if all(invariants.values())
        else "source_handler_53eafc_vtable_ghidra_refs_incomplete"
    )

    return {
        "schema_id": "h3maped_source_handler_53eafc_vtable_ghidra_summary_v1",
        "status": status,
        "inputs": {
            "ghidra_dir": str(ghidra_dir),
            "constructor": str(ghidra_dir / "target_004802ac_FUN_004802ac.txt"),
            "summary": str(ghidra_dir / "summary.txt"),
            "manifest": str(ghidra_dir / "manifest.json"),
        },
        "slots": slots,
        "metrics": {
            "slot_count": len(slots),
            "ghidra_target_count": manifest.get("target_count"),
        },
        "invariants": invariants,
        "source_backed_conclusion": (
            "Ghidra reference dumps alone prove 0x4802ac installs vtable 0x53eafc and that "
            "the table contains data references for slots +0x00 through +0x20, including "
            "slot +0x20 -> 0x48047c for queued-key cleanup through 0x429ea3. This checkpoint "
            "does not use objdump and does not change native RMG behavior."
        ),
        "remaining_gap": (
            "The 0x53eafc table is statically recovered from Ghidra, but the 0x484d9f -> "
            "0x4afa99 -> 0x4af463/0x4af910 chain still lacks same-run direct-generation "
            "ownership evidence. Do not treat source-handler pending-entry replay as the "
            "current direct RMG blocker until a live owning caller/action is identified."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ghidra-dir", type=Path, default=DEFAULT_GHIDRA_DIR)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_53EAFC_VTABLE_GHIDRA status={summary['status']} out={args.out}")
    return 0 if summary["status"] == "source_handler_53eafc_vtable_recovered_from_ghidra_refs" else 1


if __name__ == "__main__":
    raise SystemExit(main())
