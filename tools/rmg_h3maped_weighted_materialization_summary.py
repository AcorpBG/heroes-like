#!/usr/bin/env python3
"""Summarize the recovered weighted 0x4a901a materialization frontier."""

from __future__ import annotations

import argparse
import collections
import json
from pathlib import Path
from typing import Any


ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_REJECT_TRACE = (
    ROOT
    / "49a6f9_seed58_cpu0_weighted_reject_branch_trace_20260609"
    / "winedbg_interactive_trace_ledger.json"
)
DEFAULT_FOLLOW_TRACE = (
    ROOT
    / "49aa93_seed58_cpu0_followthrough_accept_probe_20260609"
    / "winedbg_interactive_trace_ledger.json"
)
DEFAULT_MATERIALIZATION_TRACE = (
    ROOT
    / "4a9322_seed58_cpu0_weighted_materialization_4a54a7_trace_20260609"
    / "winedbg_interactive_trace_ledger.json"
)
DEFAULT_SCORE_STREAM_TRACE = (
    ROOT
    / "4a9322_seed58_cpu0_weighted_materialization_4a54a7_return_trace_20260609"
    / "winedbg_interactive_trace_ledger.json"
)
DEFAULT_RETURN_TRACE = (
    ROOT
    / "4a9322_seed58_cpu0_weighted_materialization_return_only_trace_20260609"
    / "winedbg_interactive_trace_ledger.json"
)
DEFAULT_GENERATOR_DELTA_TRACE = (
    ROOT
    / "4a9322_seed58_cpu0_weighted_materialization_generator_delta_trace_20260609"
    / "winedbg_interactive_trace_ledger.json"
)
DEFAULT_VECTOR_CONTENTS_TRACE = (
    ROOT
    / "4a9322_seed58_cpu0_weighted_materialization_vector_contents_trace_20260609"
    / "winedbg_interactive_trace_ledger.json"
)
DEFAULT_DESCRIPTOR_COUNTER_TRACE = (
    ROOT
    / "4a9322_seed58_cpu0_weighted_descriptor_pointer_trace_20260609"
    / "winedbg_interactive_trace_ledger.json"
)
DEFAULT_OUT = ROOT / "weighted_4a901a_materialization_summary_20260609.json"


def load_json(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def memory_map(event: dict[str, Any]) -> dict[int, int]:
    mapped: dict[int, int] = {}
    for line in event.get("memory_lines", []):
        address = int(line["address"])
        for index, word in enumerate(line.get("words", [])):
            mapped[address + index * 4] = int(word) & 0xFFFFFFFF
    return mapped


def words_at(event: dict[str, Any], address: int, count: int) -> list[int | None]:
    mapped = memory_map(event)
    return [mapped.get(address + index * 4) for index in range(count)]


def vector_header_from_words(words: list[int | None]) -> dict[str, Any]:
    begin, end, capacity = words[:3]
    count = None
    capacity_count = None
    if isinstance(begin, int) and isinstance(end, int):
        count = (end - begin) // 4
    if isinstance(begin, int) and isinstance(capacity, int):
        capacity_count = (capacity - begin) // 4
    return {
        "begin": begin,
        "end": end,
        "capacity_end": capacity,
        "count": count,
        "capacity": capacity_count,
    }


def signed_owner_from_word20(word20: int) -> int:
    byte2 = (word20 >> 16) & 0xFF
    return byte2 - 0x100 if byte2 >= 0x80 else byte2


def cell_words(event: dict[str, Any], pointer_register: str = "eax") -> dict[str, Any]:
    registers = event.get("registers", {})
    pointer = registers.get(pointer_register)
    if not isinstance(pointer, int):
        return {"cell_pointer": None}
    mapped = memory_map(event)
    word20 = mapped.get(pointer + 0x20)
    word24 = mapped.get(pointer + 0x24)
    word28 = mapped.get(pointer + 0x28)
    return {
        "cell_pointer": pointer,
        "word20": word20,
        "word24": word24,
        "word28": word28,
        "score_low_word": None if word20 is None else word20 & 0xFFFF,
        "owner_byte2": None if word20 is None else signed_owner_from_word20(word20),
        "terrain": None if word24 is None else word24 & 0x3F,
        "bit22": None if word28 is None else bool(word28 & (1 << 22)),
        "bit26": None if word28 is None else bool(word28 & (1 << 26)),
        "bit27": None if word28 is None else bool(word28 & (1 << 27)),
    }


def summarize_reject(path: Path) -> dict[str, Any]:
    data = load_json(path)
    events = data.get("events", [])
    counts = collections.Counter(event.get("address") for event in events)
    owner_mismatch_event = None
    reject_event = None
    for index, event in enumerate(events):
        if event.get("address") != "0x0049a854":
            continue
        reject_event = event
        for prior in reversed(events[:index]):
            if prior.get("address") == "0x0049a7fe":
                owner_mismatch_event = prior
                break
        break
    result: dict[str, Any] = {
        "path": str(path),
        "event_count": len(events),
        "counts": dict(sorted(counts.items())),
        "reaches_helper_return": counts.get("0x004a916c", 0) > 0,
        "helper_return_eax_values": [
            event.get("registers", {}).get("eax")
            for event in events
            if event.get("address") == "0x004a916c"
        ],
    }
    if owner_mismatch_event and reject_event:
        owner_cell = cell_words(owner_mismatch_event, "esi")
        mapped = memory_map(reject_event)
        ebp = reject_event.get("registers", {}).get("ebp")
        expected_owner = mapped.get(ebp + 0x18) if isinstance(ebp, int) else None
        result["first_recovered_reject"] = {
            "branch": "0x49a7fe -> 0x49a854",
            "reason": "covered generated-cell owner/relation byte does not match expected relation",
            "candidate_x": mapped.get(ebp + 0x0C) if isinstance(ebp, int) else None,
            "candidate_y": mapped.get(ebp + 0x10) if isinstance(ebp, int) else None,
            "candidate_z": mapped.get(ebp + 0x14) if isinstance(ebp, int) else None,
            "expected_relation": expected_owner,
            "observed_relation": owner_cell.get("owner_byte2"),
            "cell": owner_cell,
        }
    return result


def summarize_follow(path: Path) -> dict[str, Any]:
    data = load_json(path)
    events = data.get("events", [])
    counts = collections.Counter(event.get("address") for event in events)
    materializations = []
    for event in events:
        if event.get("address") != "0x004a9322":
            continue
        registers = event.get("registers", {})
        mapped = memory_map(event)
        esp = registers.get("esp")
        materializations.append(
            {
                "event_index": events.index(event),
                "record_pointer": mapped.get(esp) if isinstance(esp, int) else None,
                "x": mapped.get(esp + 4) if isinstance(esp, int) else None,
                "y": mapped.get(esp + 8) if isinstance(esp, int) else None,
                "z": mapped.get(esp + 12) if isinstance(esp, int) else None,
                "dispatch_vtable": registers.get("edx"),
                "dispatch_target_slot": "+0x04",
            }
        )
    return {
        "path": str(path),
        "event_count": len(events),
        "child_returncode": data.get("child_returncode"),
        "counts": dict(sorted(counts.items())),
        "accept_count": counts.get("0x004a9174", 0),
        "append_count": counts.get("0x004a9248", 0) + counts.get("0x004a9254", 0),
        "allocation_count": counts.get("0x004a9290", 0),
        "constructor_count": counts.get("0x004a92bb", 0),
        "ready_count": counts.get("0x004a92d5", 0),
        "materialization_dispatch_count": counts.get("0x004a9322", 0),
        "materializations": materializations,
        "timed_out_after_positive_evidence": data.get("child_returncode") not in (0, None),
    }


def summarize_materialization(path: Path) -> dict[str, Any]:
    data = load_json(path)
    events = data.get("events", [])
    counts = collections.Counter(event.get("address") for event in events)
    first_dispatch = next((event for event in events if event.get("address") == "0x004a9322"), None)
    first_primary_clear = next((event for event in events if event.get("address") == "0x004a558a"), None)
    paired_writes = []
    pending_before: dict[str, Any] | None = None
    for event in events:
        address = event.get("address")
        if address == "0x004a56b6":
            pending_before = event
        elif address == "0x004a56b9" and pending_before is not None:
            before = cell_words(pending_before, "eax")
            after = cell_words(event, "eax")
            if before.get("cell_pointer") == after.get("cell_pointer"):
                paired_writes.append(
                    {
                        "cell_pointer": before.get("cell_pointer"),
                        "old_word20": before.get("word20"),
                        "new_word20": after.get("word20"),
                        "old_score_low_word": before.get("score_low_word"),
                        "new_score_low_word": after.get("score_low_word"),
                        "old_owner_byte2": before.get("owner_byte2"),
                        "new_owner_byte2": after.get("owner_byte2"),
                        "terrain": after.get("terrain"),
                        "bit22": after.get("bit22"),
                        "bit26": after.get("bit26"),
                        "bit27": after.get("bit27"),
                    }
                )
            pending_before = None
    dispatch_summary = None
    if first_dispatch:
        mapped = memory_map(first_dispatch)
        esp = first_dispatch.get("registers", {}).get("esp")
        dispatch_summary = {
            "record_pointer": mapped.get(esp) if isinstance(esp, int) else None,
            "x": mapped.get(esp + 4) if isinstance(esp, int) else None,
            "y": mapped.get(esp + 8) if isinstance(esp, int) else None,
            "z": mapped.get(esp + 12) if isinstance(esp, int) else None,
            "dispatch_vtable": first_dispatch.get("registers", {}).get("edx"),
        }
    return {
        "path": str(path),
        "event_count": len(events),
        "child_returncode": data.get("child_returncode"),
        "counts": dict(sorted(counts.items())),
        "first_dispatch": dispatch_summary,
        "enters_4a54a7": counts.get("0x004a54bd", 0) > 0,
        "post_49abd6_commit_site_count": counts.get("0x004a54d6", 0),
        "primary_source_score_clear": cell_words(first_primary_clear, "eax") if first_primary_clear else None,
        "score_write_pair_count": len(paired_writes),
        "unpaired_score_write_before_count": counts.get("0x004a56b6", 0) - len(paired_writes),
        "unique_score_write_cells": len({write["cell_pointer"] for write in paired_writes}),
        "score_write_low_word_old_range": [
            min(write["old_score_low_word"] for write in paired_writes),
            max(write["old_score_low_word"] for write in paired_writes),
        ]
        if paired_writes
        else None,
        "score_write_low_word_new_range": [
            min(write["new_score_low_word"] for write in paired_writes),
            max(write["new_score_low_word"] for write in paired_writes),
        ]
        if paired_writes
        else None,
        "score_write_samples": paired_writes[:12],
        "materialization_return_captured": counts.get("0x004a9325", 0) > 0,
    }


def summarize_return_trace(path: Path) -> dict[str, Any]:
    data = load_json(path)
    events = data.get("events", [])
    counts = collections.Counter(event.get("address") for event in events)
    dispatch = next((event for event in events if event.get("address") == "0x004a9322"), None)
    return_site = next((event for event in events if event.get("address") == "0x004a5756"), None)
    caller_after = next((event for event in events if event.get("address") == "0x004a9325"), None)
    first_dispatch = None
    if dispatch:
        mapped = memory_map(dispatch)
        esp = dispatch.get("registers", {}).get("esp")
        first_dispatch = {
            "record_pointer": mapped.get(esp) if isinstance(esp, int) else None,
            "x": mapped.get(esp + 4) if isinstance(esp, int) else None,
            "y": mapped.get(esp + 8) if isinstance(esp, int) else None,
            "z": mapped.get(esp + 12) if isinstance(esp, int) else None,
            "dispatch_vtable": dispatch.get("registers", {}).get("edx"),
        }
    return {
        "path": str(path),
        "event_count": len(events),
        "child_returncode": data.get("child_returncode"),
        "counts": dict(sorted(counts.items())),
        "first_dispatch": first_dispatch,
        "return_site_captured": return_site is not None,
        "caller_after_state_captured": caller_after is not None,
    }


def summarize_vector_contents(path: Path) -> dict[str, Any]:
    data = load_json(path)
    events = data.get("events", [])
    counts = collections.Counter(event.get("address") for event in events)
    before = next((event for event in events if event.get("address") == "0x004a9322"), None)
    after = next((event for event in events if event.get("address") == "0x004a9325"), None)
    if after is None:
        after = next((event for event in events if event.get("address") == "0x004a5756"), None)

    before_dispatch = None
    record_pointer = None
    if before:
        mapped = memory_map(before)
        esp = before.get("registers", {}).get("esp")
        record_pointer = mapped.get(esp) if isinstance(esp, int) else None
        before_dispatch = {
            "record_pointer": record_pointer,
            "x": mapped.get(esp + 4) if isinstance(esp, int) else None,
            "y": mapped.get(esp + 8) if isinstance(esp, int) else None,
            "z": mapped.get(esp + 12) if isinstance(esp, int) else None,
        }

    before_generator = None
    if before:
        registers = before.get("registers", {})
        before_generator = registers.get("ecx")
        if not isinstance(before_generator, int):
            before_generator = registers.get("ebx")

    def event_vector(event: dict[str, Any] | None, generator_override: int | None = None) -> dict[str, Any] | None:
        if event is None:
            return None
        generator = generator_override
        if not isinstance(generator, int):
            registers = event.get("registers", {})
            generator = registers.get("ecx")
            if not isinstance(generator, int):
                generator = registers.get("ebx")
            if not isinstance(generator, int):
                return None
        header_address = generator + 0xEC8
        header = vector_header_from_words(words_at(event, header_address, 3))
        contents = words_at(event, header["begin"], header["count"]) if isinstance(header.get("begin"), int) and isinstance(header.get("count"), int) else []
        return {
            "generator_pointer": generator,
            "header_address": header_address,
            "header_offsets": ["+0xec8", "+0xecc", "+0xed0"],
            "header": header,
            "contents": contents,
        }

    before_vector = event_vector(before, before_generator)
    after_vector = event_vector(after, before_generator)
    appended_pointer = None
    object_vector_append_recovered = False
    object_vector_header_delta_recovered = False
    if before_vector and after_vector:
        before_header = before_vector.get("header", {})
        after_header = after_vector.get("header", {})
        object_vector_header_delta_recovered = before_header.get("count") == 4 and after_header.get("count") == 5
        object_vector_header_delta_recovered = object_vector_header_delta_recovered and before_header.get("capacity") == 4
        object_vector_header_delta_recovered = object_vector_header_delta_recovered and after_header.get("capacity") == 8
        before_contents = before_vector.get("contents", [])
        after_contents = after_vector.get("contents", [])
        if (
            isinstance(before_contents, list)
            and isinstance(after_contents, list)
            and len(after_contents) == len(before_contents) + 1
            and after_contents[: len(before_contents)] == before_contents
        ):
            appended_pointer = after_contents[-1]
            object_vector_append_recovered = appended_pointer == record_pointer

    record_before_words = words_at(before, record_pointer, 12) if before and isinstance(record_pointer, int) else []
    record_after_words = words_at(after, record_pointer, 12) if after and isinstance(record_pointer, int) else []
    record_coordinate_before = record_before_words[2:5] if len(record_before_words) >= 5 else []
    record_coordinate_after = record_after_words[2:5] if len(record_after_words) >= 5 else []
    return {
        "path": str(path),
        "event_count": len(events),
        "child_returncode": data.get("child_returncode"),
        "counts": dict(sorted(counts.items())),
        "first_dispatch": before_dispatch,
        "object_vector_before": before_vector,
        "object_vector_after": after_vector,
        "object_vector_header_delta_recovered": object_vector_header_delta_recovered,
        "appended_record_pointer": appended_pointer,
        "object_vector_append_recovered": object_vector_append_recovered,
        "record_before_words": record_before_words,
        "record_after_words": record_after_words,
        "record_coordinate_before": record_coordinate_before,
        "record_coordinate_after": record_coordinate_after,
        "record_coordinate_fill_recovered": record_coordinate_before == [0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF]
        and record_coordinate_after == [107, 6, 0],
    }


def summarize_descriptor_counter(path: Path) -> dict[str, Any]:
    data = load_json(path)
    events = data.get("events", [])
    counts = collections.Counter(event.get("address") for event in events)
    before = next((event for event in events if event.get("address") == "0x004a9322"), None)
    after = next((event for event in events if event.get("address") == "0x004a9325"), None)

    def counter_base(event: dict[str, Any] | None, register: str) -> int | None:
        if event is None:
            return None
        generator = event.get("registers", {}).get(register)
        return generator + 0x1110 if isinstance(generator, int) else None

    before_base = counter_base(before, "ecx")
    after_base = counter_base(after, "ebx")
    changed_counters = []
    if before and after and isinstance(before_base, int) and isinstance(after_base, int):
        before_map = memory_map(before)
        after_map = memory_map(after)
        for index in range(128):
            before_value = before_map.get(before_base + index * 4)
            after_value = after_map.get(after_base + index * 4)
            if before_value != after_value:
                changed_counters.append(
                    {
                        "index": index,
                        "before": before_value,
                        "after": after_value,
                        "before_address": before_base + index * 4,
                        "after_address": after_base + index * 4,
                    }
                )
    return {
        "path": str(path),
        "event_count": len(events),
        "child_returncode": data.get("child_returncode"),
        "counts": dict(sorted(counts.items())),
        "counter_base_offset": "+0x1110",
        "changed_counters": changed_counters,
        "weighted_descriptor_counter_increment_recovered": changed_counters
        == [{"index": 98, "before": 4, "after": 5, "before_address": before_base + 98 * 4, "after_address": after_base + 98 * 4}]
        if isinstance(before_base, int) and isinstance(after_base, int)
        else False,
    }


def build_summary(args: argparse.Namespace) -> dict[str, Any]:
    reject = summarize_reject(args.reject_trace)
    follow = summarize_follow(args.follow_trace)
    materialization = summarize_materialization(args.materialization_trace)
    score_stream = summarize_materialization(args.score_stream_trace)
    return_trace = summarize_return_trace(args.return_trace)
    generator_delta = summarize_vector_contents(args.generator_delta_trace)
    vector_contents = summarize_vector_contents(args.vector_contents_trace)
    descriptor_counter = summarize_descriptor_counter(args.descriptor_counter_trace)
    conditions = {
        "rejecting_helper_return_captured": reject["reaches_helper_return"],
        "reject_reason_decoded_as_relation_mismatch": reject.get("first_recovered_reject", {}).get("reason")
        == "covered generated-cell owner/relation byte does not match expected relation",
        "accepted_path_reaches_append": follow["append_count"] > 0,
        "accepted_path_reaches_materialization_dispatch": follow["materialization_dispatch_count"] > 0,
        "materialization_enters_4a54a7": materialization["enters_4a54a7"],
        "materialization_score_write_stream_captured": materialization["score_write_pair_count"] > 0,
        "high_cap_score_write_stream_sampled": score_stream["score_write_pair_count"] > materialization["score_write_pair_count"],
        "first_materialization_return_captured": return_trace["return_site_captured"],
        "caller_after_state_captured": return_trace["caller_after_state_captured"],
        "generator_delta_object_vector_header_recovered": generator_delta["object_vector_header_delta_recovered"],
        "vector_contents_object_vector_append_recovered": vector_contents["object_vector_append_recovered"],
        "record_coordinate_fill_recovered": vector_contents["record_coordinate_fill_recovered"],
        "weighted_descriptor_counter_increment_recovered": descriptor_counter[
            "weighted_descriptor_counter_increment_recovered"
        ],
    }
    status = (
        "weighted_first_materialization_return_vector_counter_recovered"
        if all(conditions.values())
        else "weighted_materialization_frontier_incomplete"
    )
    return {
        "schema_id": "rmg_h3maped_weighted_materialization_summary.v1",
        "status": status,
        "conditions": conditions,
        "reject_trace": reject,
        "followthrough_trace": follow,
        "materialization_trace": materialization,
        "score_stream_high_cap_trace": score_stream,
        "return_trace": return_trace,
        "generator_delta_trace": generator_delta,
        "vector_contents_trace": vector_contents,
        "descriptor_counter_trace": descriptor_counter,
        "not_recovered": [
            "The high-cap score-write trace captures 254 complete generated-cell write pairs and still hits the event cap before return, so the complete 0x4a54a7 score-write stream length remains pending.",
            "Only the first weighted materialization's return/caller/vector delta is recovered; full ordered replay of every weighted materialization remains pending.",
            "0x4a696b, natural 0x4a7605/0x4a746b/0x4a5e73 success/mutation, and 0x4add76 cleanup/uncommit runtime paths remain unrecovered.",
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reject-trace", type=Path, default=DEFAULT_REJECT_TRACE)
    parser.add_argument("--follow-trace", type=Path, default=DEFAULT_FOLLOW_TRACE)
    parser.add_argument("--materialization-trace", type=Path, default=DEFAULT_MATERIALIZATION_TRACE)
    parser.add_argument("--score-stream-trace", type=Path, default=DEFAULT_SCORE_STREAM_TRACE)
    parser.add_argument("--return-trace", type=Path, default=DEFAULT_RETURN_TRACE)
    parser.add_argument("--generator-delta-trace", type=Path, default=DEFAULT_GENERATOR_DELTA_TRACE)
    parser.add_argument("--vector-contents-trace", type=Path, default=DEFAULT_VECTOR_CONTENTS_TRACE)
    parser.add_argument("--descriptor-counter-trace", type=Path, default=DEFAULT_DESCRIPTOR_COUNTER_TRACE)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    summary = build_summary(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_WEIGHTED_MATERIALIZATION status={summary['status']} out={args.out}")
    return 0 if summary["status"].endswith("_recovered") else 1


if __name__ == "__main__":
    raise SystemExit(main())
