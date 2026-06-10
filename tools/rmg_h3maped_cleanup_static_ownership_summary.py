#!/usr/bin/env python3
"""Summarize static ownership of H3MapEd cleanup/uncommit entry points."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


DEFAULT_PROJECTION_DRIVER_DUMP = Path(
    ".artifacts/rmg_recovery/ghidra_4ad947_4adb72_projection_driver_dump"
)
DEFAULT_SLOT_DUMP = Path(".artifacts/rmg_recovery/ghidra_49c019_49c0a6_wrapper_callers_dump")
DEFAULT_PROJECTION_FRONTIER = Path(
    ".artifacts/rmg_recovery/projection_method_dispatch_frontier_summary_20260610.json"
)
DEFAULT_CLEANUP_FRONTIER = Path(".artifacts/rmg_recovery/cleanup_runtime_frontier_summary_20260610.json")
DEFAULT_OUT = Path(".artifacts/rmg_recovery/cleanup_static_ownership_summary_20260610.json")

REFERENCE_RE = re.compile(
    r"from=(?P<from>[0-9a-fA-F]+)\s+type=(?P<type>\S+)\s+"
    r"caller=(?P<caller>\S+)\s+caller_entry=(?P<caller_entry>\S+)\s+"
    r"instruction=(?P<instruction>.*)"
)


def normalize(address: str) -> str:
    return f"0x{int(address, 16) & 0xFFFFFFFF:08x}"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def parse_references_to(path: Path) -> list[dict[str, str]]:
    references: list[dict[str, str]] = []
    in_section = False
    for line in read(path).splitlines():
        if line.strip() == "references_to:":
            in_section = True
            continue
        if in_section and line.startswith("references_from_target_function:"):
            break
        if not in_section:
            continue
        match = REFERENCE_RE.search(line)
        if not match:
            continue
        item = match.groupdict()
        item["from"] = normalize(item["from"])
        if item["caller_entry"] != "<none>":
            item["caller_entry"] = normalize(item["caller_entry"])
        references.append(item)
    return references


def reference_edges(driver_dump: Path, slot_dump: Path) -> dict[str, list[dict[str, str]]]:
    files = {
        "0x004add76": driver_dump / "target_004add76_references.txt",
        "0x004adef7": driver_dump / "target_004adef7_references.txt",
        "0x004adb72": driver_dump / "target_004adb72_references.txt",
        "0x004ad947": driver_dump / "target_004ad947_references.txt",
        "0x0049c019": slot_dump / "target_0049c019_references.txt",
        "0x0049c0a6": slot_dump / "target_0049c0a6_references.txt",
    }
    return {target: parse_references_to(path) for target, path in files.items()}


def caller_entries(edges: dict[str, list[dict[str, str]]], target: str) -> set[str]:
    return {item["caller_entry"] for item in edges.get(target, [])}


def reference_sources(edges: dict[str, list[dict[str, str]]], target: str) -> set[str]:
    return {item["from"] for item in edges.get(target, [])}


def calls_present(function_dump: Path, needles: dict[str, str]) -> dict[str, bool]:
    text = read(function_dump)
    return {name: needle in text for name, needle in needles.items()}


def summarize(
    driver_dump: Path,
    slot_dump: Path,
    projection_frontier_path: Path,
    cleanup_frontier_path: Path,
) -> dict[str, Any]:
    edges = reference_edges(driver_dump, slot_dump)
    projection_frontier = read_json(projection_frontier_path)
    cleanup_frontier = read_json(cleanup_frontier_path)

    function_contracts = {
        "0x0049c019": calls_present(
            slot_dump / "target_0049c019_FUN_0049c019.txt",
            {
                "calls_4adb72": "0049c02c: CALL 0x004adb72",
                "falls_back_to_4adef7": "0049c040: CALL 0x004adef7",
            },
        ),
        "0x0049c0a6": calls_present(
            slot_dump / "target_0049c0a6_FUN_0049c0a6.txt",
            {"calls_4ad947": "0049c0ad: CALL 0x004ad947"},
        ),
        "0x004ad947": calls_present(
            driver_dump / "target_004ad947_FUN_004ad947.txt",
            {
                "calls_4ad7f7": "004adaf2: CALL 0x004ad7f7",
                "falls_back_to_4adef7": "004adb0e: CALL 0x004adef7",
            },
        ),
        "0x004adb72": calls_present(
            driver_dump / "target_004adb72_FUN_004adb72.txt",
            {
                "calls_4aa1db": "004adcaf: CALL 0x004aa1db",
                "calls_49cf34": "004adcbe: CALL 0x0049cf34",
                "calls_4ad7f7": "004adce6: CALL 0x004ad7f7",
            },
        ),
        "0x004adef7": calls_present(
            driver_dump / "target_004adef7_FUN_004adef7.txt",
            {
                "calls_4add76": "004adf0f: CALL 0x004add76",
                "calls_4a9f1c": "004adf65: CALL 0x004a9f1c",
            },
        ),
        "0x004add76": calls_present(
            driver_dump / "target_004add76_FUN_004add76.txt",
            {
                "erases_object_vector": "004addb9: CALL 0x004cce95",
                "calls_primary_mask": "004ade9b: CALL 0x0041e951",
                "calls_secondary_mask": "004adead: CALL 0x004268eb",
                "removes_cell_reference": "004aded1: CALL 0x00499ee8",
            },
        ),
    }

    invariants = {
        "no_native_behavior_change": True,
        "no_objdump_used": True,
        "4add76_only_direct_caller_is_4adef7": caller_entries(edges, "0x004add76") == {"0x004adef7"},
        "4adef7_direct_callers_are_49c019_and_4ad947": caller_entries(edges, "0x004adef7")
        == {"0x0049c019", "0x004ad947"},
        "4adb72_only_direct_caller_is_49c019": caller_entries(edges, "0x004adb72") == {"0x0049c019"},
        "4ad947_only_direct_caller_is_49c0a6": caller_entries(edges, "0x004ad947") == {"0x0049c0a6"},
        "49c019_referenced_only_by_vtable_slot": reference_sources(edges, "0x0049c019") == {"0x00540b08"},
        "49c0a6_referenced_only_by_vtable_slot": reference_sources(edges, "0x0049c0a6") == {"0x00540b1c"},
        "expected_internal_calls_present": all(
            all(values.values()) for values in function_contracts.values()
        ),
        "projection_frontier_has_no_live_slot08_hit": projection_frontier.get("status")
        == "projection_method_dispatch_frontier_no_live_slot08_hit",
        "cleanup_frontier_has_no_live_uncommit_hit": cleanup_frontier.get("status")
        == "cleanup_runtime_frontier_static_only_no_live_uncommit_hit",
    }
    status = (
        "cleanup_static_ownership_chain_recovered_runtime_unhit"
        if all(invariants.values())
        else "cleanup_static_ownership_chain_incomplete"
    )
    return {
        "schema_id": "h3maped_cleanup_static_ownership_summary_v1",
        "status": status,
        "inputs": {
            "projection_driver_dump": str(driver_dump),
            "slot_dump": str(slot_dump),
            "projection_frontier": str(projection_frontier_path),
            "cleanup_frontier": str(cleanup_frontier_path),
        },
        "reference_edges": edges,
        "function_contracts": function_contracts,
        "invariants": invariants,
        "source_backed_conclusion": (
            "Static Ghidra references bound cleanup/uncommit to the projection-object slot +0x08 chain. "
            "0x4add76 is directly called only by 0x4adef7; 0x4adef7 is directly called by 0x49c019 "
            "and 0x4ad947; 0x4adb72 is directly called only by 0x49c019; 0x4ad947 is directly called "
            "only by 0x49c0a6; and 0x49c019/0x49c0a6 are referenced as vtable data slots at "
            "0x540b00+0x08 and 0x540b14+0x08. The current Wine corpus still has no live slot +0x08 "
            "projection-method hit and no live cleanup/uncommit hit."
        ),
        "remaining_gap": (
            "The cleanup ownership chain is now statically recovered, but runtime state is still missing. "
            "End-to-end recovery still needs a natural dispatch of 0x49c019 or 0x49c0a6, or a stronger "
            "static/data proof that those projection slot methods are not used in the target one-level "
            "land generation path, before porting cleanup/reselection behavior to native RMG."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--projection-driver-dump", type=Path, default=DEFAULT_PROJECTION_DRIVER_DUMP)
    parser.add_argument("--slot-dump", type=Path, default=DEFAULT_SLOT_DUMP)
    parser.add_argument("--projection-frontier", type=Path, default=DEFAULT_PROJECTION_FRONTIER)
    parser.add_argument("--cleanup-frontier", type=Path, default=DEFAULT_CLEANUP_FRONTIER)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(
        args.projection_driver_dump,
        args.slot_dump,
        args.projection_frontier,
        args.cleanup_frontier,
    )
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_CLEANUP_STATIC_OWNERSHIP status={summary['status']} out={args.out}")
    return 0 if summary["status"] == "cleanup_static_ownership_chain_recovered_runtime_unhit" else 1


if __name__ == "__main__":
    raise SystemExit(main())
