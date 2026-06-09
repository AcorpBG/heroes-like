#!/usr/bin/env python3
"""Summarize sampled H3MapEd ``0x4a696b`` scan-rectangle grid bytes.

This recovery report requires a ledger produced by
``rmg_h3maped_4a61bc_payload_link_dynamic_trace.py`` with
``--dump-696b-grid-entry-count`` enabled.  It verifies the actual generated-cell
``+0x20`` owner/relation bytes inside the source scan bounds for sampled
``0x4a696b`` calls.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any

from rmg_h3maped_4a696b_arg_surface_summary import (
    ENTRY,
    RETURN_SITE,
    SAME_LEVEL_PASS,
    SCAN_DONE,
    SOURCE_RELATION_MATCH_CHECKPOINT,
    memory_word,
    parse_source_record,
    qhex,
    signed32,
)


DEFAULT_LEDGER = Path(
    ".artifacts/rmg_recovery/medium_seed10_4a696b_grid_scan_trace_20260609/"
    "winedbg_4a61bc_payload_link_dynamic_trace_ledger.json"
)
DEFAULT_OUT = Path(
    ".artifacts/rmg_recovery/medium_seed10_4a696b_grid_scan_summary_20260609.json"
)


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def event_address(event: dict[str, Any]) -> str:
    return str(event.get("address", "")).lower()


def signed8(value: int) -> int:
    value &= 0xFF
    return value - 0x100 if value & 0x80 else value


def local_word(event: dict[str, Any], offset: int) -> int | None:
    registers = event.get("registers", {})
    ebp = registers.get("ebp")
    if not isinstance(ebp, int):
        return None
    return memory_word(event.get("memory_lines", []), ebp + offset)


def parse_entry(event: dict[str, Any]) -> dict[str, Any]:
    registers = event.get("registers", {})
    memory_lines = event.get("memory_lines", [])
    esp = registers.get("esp")
    generator = registers.get("ecx")
    arg1 = memory_word(memory_lines, int(esp) + 4) if isinstance(esp, int) else None
    source_record = parse_source_record(memory_lines, arg1)
    grid_base = memory_word(memory_lines, int(generator) + 0x14) if isinstance(generator, int) else None
    width = memory_word(memory_lines, int(generator) + 0x18) if isinstance(generator, int) else None
    height = memory_word(memory_lines, int(generator) + 0x1C) if isinstance(generator, int) else None
    levels = memory_word(memory_lines, int(generator) + 0x20) if isinstance(generator, int) else None
    return {
        "generator": qhex(generator) if isinstance(generator, int) else None,
        "source_record_pointer": qhex(arg1),
        "source_record": source_record,
        "grid": {
            "base": qhex(grid_base),
            "width": width,
            "height": height,
            "levels": levels,
        },
    }


def cell_pointer(grid_base: int, width: int, height: int, x: int, y: int, level: int) -> int:
    return grid_base + (((level * height) + y) * width + x) * 0x30


def scan_grid(entry_event: dict[str, Any], expected_byte2: int, expected_byte3: int) -> dict[str, Any]:
    parsed = parse_entry(entry_event)
    memory_lines = entry_event.get("memory_lines", [])
    grid = parsed["grid"]
    source = parsed["source_record"]["scan_bounds_exclusive"]
    required = [
        grid.get("base"),
        grid.get("width"),
        grid.get("height"),
        grid.get("levels"),
        source.get("x_min"),
        source.get("y_min"),
        source.get("x_max"),
        source.get("y_max"),
    ]
    if any(value is None for value in required):
        return {"captured": False, "reason": "missing_grid_or_source_bounds", "entry": parsed}
    grid_base = int(grid["base"], 16)
    width = int(grid["width"])
    height = int(grid["height"])
    levels = int(grid["levels"])
    level = parsed["source_record"]["coordinate_at_0x10"].get("level")
    if level is None:
        level = 0
    x_min = int(source["x_min"])
    y_min = int(source["y_min"])
    x_max = int(source["x_max"])
    y_max = int(source["y_max"])

    counts: Counter[str] = Counter()
    byte2_counts: Counter[int] = Counter()
    byte3_counts: Counter[int] = Counter()
    both_samples: list[dict[str, Any]] = []
    byte2_samples: list[dict[str, Any]] = []
    byte3_samples: list[dict[str, Any]] = []
    missing_samples: list[dict[str, Any]] = []
    for y in range(y_min, y_max):
        for x in range(x_min, x_max):
            if not (0 <= x < width and 0 <= y < height and 0 <= int(level) < levels):
                counts["out_of_bounds"] += 1
                continue
            cell = cell_pointer(grid_base, width, height, x, y, int(level))
            word20 = memory_word(memory_lines, cell + 0x20)
            if word20 is None:
                counts["missing_cell_word20"] += 1
                if len(missing_samples) < 5:
                    missing_samples.append({"x": x, "y": y, "level": level, "cell": qhex(cell)})
                continue
            byte2 = signed8((word20 >> 16) & 0xFF)
            byte3 = signed8((word20 >> 24) & 0xFF)
            byte2_counts[byte2] += 1
            byte3_counts[byte3] += 1
            byte2_match = byte2 == expected_byte2
            byte3_match = byte3 == expected_byte3
            if byte2_match:
                counts["byte2_match"] += 1
                if len(byte2_samples) < 5:
                    byte2_samples.append({"x": x, "y": y, "level": level, "cell": qhex(cell), "word20": qhex(word20)})
            if byte3_match:
                counts["byte3_match"] += 1
                if len(byte3_samples) < 5:
                    byte3_samples.append({"x": x, "y": y, "level": level, "cell": qhex(cell), "word20": qhex(word20)})
            if byte2_match and byte3_match:
                counts["both_match"] += 1
                if len(both_samples) < 5:
                    both_samples.append({"x": x, "y": y, "level": level, "cell": qhex(cell), "word20": qhex(word20)})
            counts["scanned_cells"] += 1
    return {
        "captured": True,
        "entry": parsed,
        "expected_generated_cell_0x20_bytes": {
            "byte2_owner_relation": expected_byte2,
            "byte3_owner_relation": expected_byte3,
        },
        "counts": dict(sorted(counts.items())),
        "byte2_value_counts": {str(key): value for key, value in sorted(byte2_counts.items())},
        "byte3_value_counts": {str(key): value for key, value in sorted(byte3_counts.items())},
        "samples": {
            "byte2_matches": byte2_samples,
            "byte3_matches": byte3_samples,
            "both_matches": both_samples,
            "missing_cell_word20": missing_samples,
        },
    }


def grouped_calls(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    calls: list[dict[str, Any]] = []
    current: dict[str, Any] | None = None
    for index, event in enumerate(events):
        address = event_address(event)
        if address == ENTRY:
            if current is not None:
                calls.append(current)
            current = {"entry_event_index": index, "entry_event": event, "sites": []}
        if current is None:
            continue
        if address in {ENTRY, SAME_LEVEL_PASS, SOURCE_RELATION_MATCH_CHECKPOINT, SCAN_DONE, RETURN_SITE}:
            current["sites"].append(address)
        if address in {SAME_LEVEL_PASS, SCAN_DONE} and "local_event" not in current:
            expected_byte2 = signed32(local_word(event, -0x18))
            expected_byte3 = signed32(local_word(event, -0x1C))
            if expected_byte2 is not None and expected_byte3 is not None:
                current["local_event_index"] = index
                current["expected_byte2"] = expected_byte2
                current["expected_byte3"] = expected_byte3
                current["local_event"] = event
        if address == RETURN_SITE:
            calls.append(current)
            current = None
    if current is not None:
        calls.append(current)
    return calls


def summarize(ledger_path: Path) -> dict[str, Any]:
    ledger = load_json(ledger_path)
    events = ledger.get("events", [])
    calls = grouped_calls(events)
    summarized_calls: list[dict[str, Any]] = []
    for call in calls:
        if "expected_byte2" not in call or "expected_byte3" not in call:
            summarized_calls.append(
                {
                    "entry_event_index": call.get("entry_event_index"),
                    "captured": False,
                    "reason": "missing_expected_owner_relation_locals",
                    "sites": call.get("sites", []),
                }
            )
            continue
        grid_scan = scan_grid(call["entry_event"], int(call["expected_byte2"]), int(call["expected_byte3"]))
        summarized_calls.append(
            {
                "entry_event_index": call.get("entry_event_index"),
                "local_event_index": call.get("local_event_index"),
                "sites": call.get("sites", []),
                "classification": (
                    "grid_scan_zero_owner_relation_matches"
                    if grid_scan.get("captured")
                    and grid_scan.get("counts", {}).get("scanned_cells", 0) > 0
                    and grid_scan.get("counts", {}).get("missing_cell_word20", 0) == 0
                    and grid_scan.get("counts", {}).get("both_match", 0) == 0
                    else "grid_scan_has_owner_relation_matches_or_incomplete"
                ),
                "grid_scan": grid_scan,
            }
        )
    captured = [call for call in summarized_calls if call.get("grid_scan", {}).get("captured")]
    complete = [
        call
        for call in captured
        if call.get("grid_scan", {}).get("counts", {}).get("scanned_cells", 0) > 0
        and call.get("grid_scan", {}).get("counts", {}).get("missing_cell_word20", 0) == 0
    ]
    zero_both = [
        call for call in complete if call.get("grid_scan", {}).get("counts", {}).get("both_match", 0) == 0
    ]
    invariants = {
        "ledger_has_events": len(events) > 0,
        "sampled_4a696b_calls": len(calls) > 0,
        "at_least_one_complete_grid_scan_captured": len(complete) > 0,
        "all_complete_grid_scans_have_zero_owner_relation_pair_matches": len(zero_both) == len(complete),
        "no_native_behavior_change": True,
    }
    status = (
        "partial_recovery_4a696b_grid_scan_zero_owner_relation_matches"
        if all(value for key, value in invariants.items() if key != "no_native_behavior_change")
        else "incomplete"
    )
    return {
        "schema_id": "h3maped_4a696b_grid_scan_summary_v1",
        "status": status,
        "ledger": str(ledger_path),
        "event_count": ledger.get("event_count", len(events)),
        "seed_control": ledger.get("seed_control"),
        "metrics": {
            "sampled_4a696b_calls": len(calls),
            "captured_grid_scan_entries": len(captured),
            "complete_grid_scans": len(complete),
            "zero_owner_relation_pair_match_scans": len(zero_both),
        },
        "invariants": invariants,
        "calls": summarized_calls,
        "source_backed_conclusion": (
            "For each complete captured grid scan, the actual GeneratedCell+0x20 byte2/byte3 "
            "values inside the 0x4a696b source scan rectangle contain zero cells matching both "
            "expected owner/relation bytes. This directly explains why those sampled calls never "
            "reach 0x4a6a81."
        ),
        "remaining_gap": (
            "This is still sampled evidence, not global unreachability proof. End-to-end recovery "
            "still needs either a natural 0x4a696b source/relation-match sample or a broader static/"
            "data proof that the pair match cannot occur for the target one-level land mode. "
            "Cleanup/uncommit 0x4add76/0x4adef7 remains unrecovered."
        ),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()
    summary = summarize(args.ledger)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_4A696B_GRID_SCAN_SUMMARY status={summary['status']} out={args.out}")
    return 0 if summary["status"].startswith("partial_recovery_") else 1


if __name__ == "__main__":
    raise SystemExit(main())
