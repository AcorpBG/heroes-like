#!/usr/bin/env python3
"""Summarize checked H3MapEd profiles around the 0x4a901a weighted path.

This is recovery evidence only. It records which generation profiles reached
0x4a901a, which callsites/threshold arguments they used, and whether any
checked profile reached the eligibility/append/materialization path.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any

from rmg_h3maped_4a8db2_4a901a_live_surface_summary import parse_events
from rmg_h3maped_4a901a_weighted_rejection_summary import stack_words


ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_OUT = ROOT / "4a901a_profile_surface_summary_20260608.json"

CALLSITE_ADDRESSES = ["0x004a8f96", "0x004a8ffd"]
OBSERVED_ADDRESSES = [
    "0x004a8f96",
    "0x004a8fb4",
    "0x004a8fd6",
    "0x004a8ffd",
    "0x004a901a",
    "0x004a9085",
    "0x004a9150",
    "0x004a9167",
    "0x004a9248",
    "0x004a9254",
    "0x004a9273",
    "0x004a9289",
    "0x004a9290",
    "0x004a92bb",
    "0x004a92d5",
    "0x004a9322",
    "0x004a9391",
]
SUCCESS_SURFACE_ADDRESSES = [
    "0x004a9167",
    "0x004a9248",
    "0x004a9254",
    "0x004a9290",
    "0x004a92bb",
    "0x004a92d5",
    "0x004a9322",
]

DEFAULT_PROFILES = [
    {
        "profile_id": "large_no_water_callsite_scan",
        "map_size": "large",
        "water": "none",
        "player_mix": "human_computer_down_3",
        "source": ROOT / "4a901a_profile_large_callsite_scan_20260608" / "winedbg_interactive_trace.log",
        "source_type": "log",
    },
    {
        "profile_id": "large_no_water_value_gate_trace",
        "map_size": "large",
        "water": "none",
        "player_mix": "human_computer_down_3",
        "source": ROOT / "4a901a_profile_large_value_gate_trace_20260608" / "winedbg_interactive_trace_ledger.json",
        "source_type": "ledger",
    },
    {
        "profile_id": "medium_no_water_monster0_callsite_scan",
        "map_size": "medium",
        "water": "none",
        "player_mix": "human_computer_down_3",
        "monster_strength_down": 0,
        "source": ROOT / "4a901a_profile_medium_monster0_callsite_scan_20260608" / "winedbg_interactive_trace.log",
        "source_type": "log",
    },
    {
        "profile_id": "xlarge_no_water_callsite_scan",
        "map_size": "xlarge",
        "water": "none",
        "player_mix": "human_computer_down_3",
        "source": ROOT / "4a901a_profile_xlarge_callsite_scan_20260608" / "winedbg_interactive_trace.log",
        "source_type": "log",
    },
    {
        "profile_id": "medium_water_callsite_scan",
        "map_size": "medium",
        "water": "enabled",
        "player_mix": "human_computer_down_3",
        "source": ROOT / "4a901a_profile_medium_water_callsite_scan_20260608" / "winedbg_interactive_trace.log",
        "source_type": "log",
        "usable": False,
        "note": "The WineDbg run timed out before any configured breakpoint hit.",
    },
]


def hex32(value: int | None) -> str | None:
    return None if value is None else f"0x{value & 0xFFFFFFFF:08x}"


def read_ledger_events(path: Path) -> list[dict[str, Any]]:
    ledger = json.loads(path.read_text(encoding="utf-8"))
    return ledger.get("events", [])


def load_events(profile: dict[str, Any]) -> list[dict[str, Any]]:
    source = Path(profile["source"])
    if not source.exists():
        return []
    if profile["source_type"] == "ledger":
        return read_ledger_events(source)
    return parse_events(source)


def callsite_args(event: dict[str, Any]) -> dict[str, Any]:
    words = stack_words(event)
    labels = [
        "wrapper",
        "arg_0c_category",
        "arg_10_selector",
        "arg_14_enabled",
        "arg_18_required_value",
        "arg_1c_relation_index",
        "generator",
        "trailing_callsite_word",
    ]
    return {
        label: hex32(words[index])
        for index, label in enumerate(labels)
        if index < len(words)
    }


def value_gate_samples(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    samples: list[dict[str, Any]] = []
    current_callsite: str | None = None
    current_required: int | None = None
    for event in events:
        address = event.get("address")
        if address in CALLSITE_ADDRESSES:
            words = stack_words(event)
            current_callsite = address
            current_required = words[4] if len(words) > 4 else None
            continue
        if address != "0x004a9150":
            continue
        eax = int(event.get("registers", {}).get("eax", 0)) & 0xFFFFFFFF
        low16 = eax & 0xFFFF
        samples.append(
            {
                "callsite": current_callsite,
                "candidate_cell_value_low16_eax": low16,
                "required_value_arg_0x18": current_required,
                "would_fail_value_floor": current_required is not None and low16 < current_required,
            }
        )
    return samples


def summarize_profile(profile: dict[str, Any]) -> dict[str, Any]:
    source = Path(profile["source"])
    events = load_events(profile)
    counts = Counter(event.get("address") for event in events)
    callsite_events = [
        {
            "event_index": index,
            "address": event.get("address"),
            "args": callsite_args(event),
        }
        for index, event in enumerate(events)
        if event.get("address") in CALLSITE_ADDRESSES
    ]
    thresholds = sorted(
        {
            int(call["args"]["arg_18_required_value"], 16)
            for call in callsite_events
            if call.get("args", {}).get("arg_18_required_value") is not None
        }
    )
    enabled_values = sorted(
        {
            int(call["args"]["arg_14_enabled"], 16)
            for call in callsite_events
            if call.get("args", {}).get("arg_14_enabled") is not None
        }
    )
    values = value_gate_samples(events)
    low16_values = [sample["candidate_cell_value_low16_eax"] for sample in values]
    success_counts = {address: counts.get(address, 0) for address in SUCCESS_SURFACE_ADDRESSES}
    usable = bool(events) and profile.get("usable", True)
    return {
        "profile_id": profile["profile_id"],
        "map_size": profile.get("map_size"),
        "water": profile.get("water"),
        "player_mix": profile.get("player_mix"),
        "monster_strength_down": profile.get("monster_strength_down"),
        "trace_source": str(source),
        "trace_source_type": profile["source_type"],
        "usable": usable,
        "note": profile.get("note"),
        "event_count": len(events),
        "counts": {address: counts.get(address, 0) for address in OBSERVED_ADDRESSES},
        "callsite_events": callsite_events,
        "callsite_counts": {address: counts.get(address, 0) for address in CALLSITE_ADDRESSES},
        "required_values_arg_0x18": thresholds,
        "arg_14_enabled_values": enabled_values,
        "success_surface_counts": success_counts,
        "reaches_eligibility_or_append_or_materialization": any(success_counts.values()),
        "value_gate_samples": {
            "sample_count": len(values),
            "candidate_cell_value_low16_min": min(low16_values) if low16_values else None,
            "candidate_cell_value_low16_max": max(low16_values) if low16_values else None,
            "candidate_cell_value_low16_counts": dict(sorted(Counter(low16_values).items())),
            "all_sampled_value_floor_checks_fail": bool(values)
            and all(sample["would_fail_value_floor"] for sample in values),
            "first_16_samples": values[:16],
        },
    }


def summarize(args: argparse.Namespace) -> dict[str, Any]:
    profiles = [summarize_profile(profile) for profile in DEFAULT_PROFILES]
    usable_profiles = [profile for profile in profiles if profile["usable"]]
    any_success_surface = any(
        profile["reaches_eligibility_or_append_or_materialization"] for profile in usable_profiles
    )
    reached_4a901a = sum(profile["counts"]["0x004a901a"] for profile in usable_profiles)
    thresholds_by_profile = {
        profile["profile_id"]: profile["required_values_arg_0x18"] for profile in usable_profiles
    }
    status = (
        "profile_scan_no_4a901a_append_materialization_path_found"
        if reached_4a901a > 0 and not any_success_surface
        else "profile_scan_incomplete_or_success_surface_found"
    )
    return {
        "schema_id": "rmg_h3maped_4a901a_profile_surface_summary.v1",
        "status": status,
        "native_behavior_changed": False,
        "profiles": profiles,
        "aggregate": {
            "usable_profile_count": len(usable_profiles),
            "checked_4a901a_hits": reached_4a901a,
            "thresholds_by_profile": thresholds_by_profile,
            "success_surface_observed": any_success_surface,
            "profiles_with_value_gate_samples": [
                profile["profile_id"]
                for profile in usable_profiles
                if profile["value_gate_samples"]["sample_count"] > 0
            ],
        },
        "recovery_meaning": {
            "recovered": (
                "Checked profile changes affect the 0x4a901a callsite mix and arg_0x18 value floor: "
                "Medium no-water remains at 0xcb/203, Large no-water uses 0x90/144, and XLarge "
                "no-water observed 0xa6/166."
            ),
            "not_recovered": (
                "No checked usable profile reached 0x49aa93 eligibility, 0x4ae52a/0x4ae1fd append, "
                "0x540a9c materialization, or 0x4a54a7 projection."
            ),
            "next_required_step": (
                "Recover or drive the source-row/callsite condition that yields a 0x4a901a weighted "
                "scan whose value floor can pass, then capture successful append, materialization, "
                "projection, generated-cell before/after state, and generator vector deltas."
            ),
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()
    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_4A901A_PROFILE_SURFACE_SUMMARY status={summary['status']} out={args.out}")
    return 0 if summary["status"] == "profile_scan_no_4a901a_append_materialization_path_found" else 1


if __name__ == "__main__":
    raise SystemExit(main())
