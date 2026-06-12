#!/usr/bin/env python3
"""Audit recovered H3MapEd reward/guard artifacts for source-stream coverage.

This is a focused evidence inventory, not a parity gate and not a native tuning
tool. It answers one narrow question before native RMG behavior changes:
whether existing recovered artifacts contain the same-run H3MapEd 0x4aa354
selected reward/guard stream needed to justify active 0x4a5c07/0x49cf34
adoption for the current seed-58 boundary gap.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]

DEFAULT_ARTIFACTS: dict[str, Path] = {
    "seed58_route_replay_verify": Path(
        ".artifacts/rmg_recovery/seed58_4a8260_route_replay_verify_20260611.json"
    ),
    "seed58_phase_driver_ledger": Path(
        ".artifacts/rmg_recovery/seed58_phase_driver_trace/winedbg_recovery_trace_ledger.json"
    ),
    "seed58_phase_entry_ledger": Path(
        ".artifacts/rmg_recovery/seed58_phase_entry_trace/winedbg_recovery_trace_ledger.json"
    ),
    "seed58_route_call_sites_lite": Path(
        ".artifacts/rmg_recovery/seed58_piped_4a8260_route_call_sites_to_4a4c8e/"
        "winedbg_recovery_trace_ledger.json"
    ),
    "seed58_route_call_sites_full": Path(
        ".artifacts/rmg_recovery/seed58_piped_4a8260_route_call_sites_to_4a4c8e_full/"
        "winedbg_recovery_trace_ledger.json"
    ),
    "seed58_4aa9b7_success_handoff": Path(
        ".artifacts/rmg_recovery/small2p_seed58_4aa9b7_success_handoff_20260610/"
        "winedbg_interactive_trace_ledger.json"
    ),
    "medium_seed10_reward_attach_order": Path(
        ".artifacts/rmg_recovery/medium_seed10_reward_attach_order_replay_20260610/"
        "winedbg_interactive_trace_ledger.json"
    ),
    "medium_seed10_reward_attach_order_summary": Path(
        ".artifacts/rmg_recovery/reward_attach_order_summary_20260610.json"
    ),
    "broad_unseeded_reward_chain": Path(
        ".artifacts/rmg_recovery/direct_generation_reward_chain_through_4ac552/"
        "winedbg_recovery_trace_ledger.json"
    ),
    "medium_seed10_49cf34_cell_mutation": Path(
        ".artifacts/rmg_recovery/medium_seed10_49cf34_cell_mutation_replay_20260610/"
        "winedbg_interactive_trace_ledger.json"
    ),
    "direct_49cf34_finalization": Path(
        ".artifacts/rmg_recovery/direct_generation_49cf34_finalization_trace/"
        "winedbg_recovery_trace_ledger.json"
    ),
    "direct_49d69d_runtime": Path(
        ".artifacts/rmg_recovery/direct_generation_49d69d_runtime_trace/"
        "winedbg_recovery_trace_ledger.json"
    ),
}

REQUIRED_STREAM_ADDRESSES = [
    "0x004aa354",
    "0x004aa38a",
    "0x004aa38f",
    "0x004aa3a8",
    "0x004aa3b6",
    "0x0049cf34",
    "0x0049d2be",
    "0x004aa3bb",
]

DOWNSTREAM_ADDRESSES = [
    "0x004aa9b7",
    "0x004aa3e9",
]

DESCRIPTOR_VECTOR_FIELDS = ["0x398", "+0x398", "0x39c", "+0x39c"]
SELECTED_DESCRIPTOR_FIELDS = ["0x94", "+0x94", "0x95", "+0x95"]


def normalize_address(value: Any) -> str:
    try:
        return "0x%08x" % int(str(value), 0)
    except (TypeError, ValueError):
        return ""


def load_json(path: Path) -> dict[str, Any] | None:
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def requested_seed(data: dict[str, Any]) -> int | None:
    seed_control = data.get("seed_control")
    if not isinstance(seed_control, dict):
        return None
    patch = seed_control.get("patch")
    if isinstance(patch, dict) and "requested_seed_uint32" in patch:
        return int(patch["requested_seed_uint32"])
    value = seed_control.get("requested_seed")
    if value is None:
        return None
    return int(value)


def address_counts(data: dict[str, Any]) -> Counter[str]:
    counts: Counter[str] = Counter()
    for event in data.get("events", []):
        if isinstance(event, dict):
            counts[normalize_address(event.get("address"))] += 1
    return counts


def first_indexes(data: dict[str, Any]) -> dict[str, int]:
    indexes: dict[str, int] = {}
    for index, event in enumerate(data.get("events", []), start=1):
        if not isinstance(event, dict):
            continue
        address = normalize_address(event.get("address"))
        indexes.setdefault(address, index)
    return indexes


def command_text(data: dict[str, Any]) -> str:
    parts: list[str] = []
    for key in ("address_command", "dump_command", "extra_command", "lite_extra_command", "pre_cont_command"):
        value = data.get(key)
        if isinstance(value, str):
            parts.append(value)
        elif isinstance(value, dict):
            parts.extend(str(item) for item in value.values())
        elif isinstance(value, list):
            parts.extend(str(item) for item in value)
    return "\n".join(parts).lower()


def has_order(indexes: dict[str, int], addresses: list[str]) -> bool:
    positions = [indexes.get(address, -1) for address in addresses]
    return all(position > 0 for position in positions) and positions == sorted(positions)


def classify_artifact(
    *,
    seed: int | None,
    counts: Counter[str],
    indexes: dict[str, int],
    dumps_descriptor_vector: bool,
    dumps_selected_descriptor_state: bool,
) -> str:
    has_full_address_order = has_order(indexes, REQUIRED_STREAM_ADDRESSES)
    has_downstream = counts["0x004aa9b7"] > 0 or counts["0x004aa3e9"] > 0
    if (
        seed == 58
        and has_full_address_order
        and dumps_descriptor_vector
        and dumps_selected_descriptor_state
    ):
        return "candidate_full_seed58_same_run_source_stream"
    if seed == 58 and counts["0x004aa354"] == 0:
        return "seed58_route_or_downstream_only_missing_0x4aa354"
    if seed == 58 and counts["0x004aa354"] > 0:
        return "seed58_constructor_trace_incomplete_for_descriptor_vector_or_selected_state"
    if has_full_address_order:
        return "single_attach_order_sample_not_seed58_full_stream"
    if counts["0x004aa354"] > 0:
        return "unseeded_or_nonparity_reward_chain_reaches_0x4aa354_only"
    if has_downstream:
        return "downstream_reward_projection_only"
    if counts["0x0049cf34"] > 0 or counts["0x0049d69d"] > 0:
        return "downstream_attach_mechanics_only"
    return "unrelated_or_route_phase_only"


def artifact_summary(label: str, relative_path: Path) -> dict[str, Any]:
    path = ROOT / relative_path
    data = load_json(path)
    if data is None:
        return {
            "label": label,
            "path": str(relative_path),
            "exists": False,
            "classification": "missing_artifact",
        }

    counts = address_counts(data)
    indexes = first_indexes(data)
    text = command_text(data)
    seed = requested_seed(data)
    dumps_descriptor_vector = any(token in text for token in DESCRIPTOR_VECTOR_FIELDS)
    dumps_selected_descriptor_state = any(token in text for token in SELECTED_DESCRIPTOR_FIELDS)
    classification = classify_artifact(
        seed=seed,
        counts=counts,
        indexes=indexes,
        dumps_descriptor_vector=dumps_descriptor_vector,
        dumps_selected_descriptor_state=dumps_selected_descriptor_state,
    )
    required_counts = {
        address: counts[address] for address in REQUIRED_STREAM_ADDRESSES + DOWNSTREAM_ADDRESSES
    }
    return {
        "label": label,
        "path": str(relative_path),
        "exists": True,
        "schema_id": data.get("schema_id"),
        "event_count": int(data.get("event_count", len(data.get("events", [])) or 0)),
        "seed_controlled": seed is not None,
        "requested_seed": seed,
        "required_address_counts": required_counts,
        "first_required_event_indexes": {
            address: indexes.get(address) for address in REQUIRED_STREAM_ADDRESSES + DOWNSTREAM_ADDRESSES
        },
        "has_0x4aa354_to_0x49cf34_attach_order": has_order(indexes, REQUIRED_STREAM_ADDRESSES),
        "has_0x4aa9b7_to_0x4aa3e9_downstream_handoff": has_order(indexes, DOWNSTREAM_ADDRESSES),
        "dumps_generator_descriptor_vector_0x398_0x39c": dumps_descriptor_vector,
        "dumps_selected_descriptor_state_0x94_0x95": dumps_selected_descriptor_state,
        "classification": classification,
    }


def summarize(artifacts: dict[str, Path]) -> dict[str, Any]:
    summaries = [artifact_summary(label, path) for label, path in artifacts.items()]
    full_stream_candidates = [
        item
        for item in summaries
        if item.get("classification") == "candidate_full_seed58_same_run_source_stream"
    ]
    seed58_constructor_ledgers = [
        item
        for item in summaries
        if item.get("requested_seed") == 58
        and item.get("required_address_counts", {}).get("0x004aa354", 0) > 0
    ]
    broad_aa354_count = sum(
        int(item.get("required_address_counts", {}).get("0x004aa354", 0))
        for item in summaries
        if item.get("classification") == "unseeded_or_nonparity_reward_chain_reaches_0x4aa354_only"
    )
    return {
        "schema_id": "rmg_h3maped_reward_guard_source_stream_coverage_v1",
        "purpose": (
            "Inventory existing recovered H3MapEd artifacts for the same-run seed58 "
            "0x4aa354 reward/guard source stream required before native 0x4a5c07/0x49cf34 "
            "behavior changes."
        ),
        "is_parity_gate": False,
        "native_behavior_changed": False,
        "windows_dll_build_required": False,
        "windows_dll_build_policy": (
            "Do not build Windows DLLs in this evidence loop; build once after Linux/Python "
            "parity reaches a final boundary."
        ),
        "required_source_stream": {
            "seed": 58,
            "ordered_addresses": REQUIRED_STREAM_ADDRESSES,
            "required_generator_state": [
                "generator +0x398 descriptor-vector begin",
                "generator +0x39c descriptor-vector end",
                "selected descriptor +0x94/+0x95 state",
                "selected descriptor/object identity for each 0x4aa354 call",
                "per-call branch into or around 0x4a5c07/0x49cf34",
            ],
        },
        "artifacts": summaries,
        "invariants": {
            "full_same_run_seed58_source_stream_artifact_found": bool(full_stream_candidates),
            "source_backed_native_rule_available": bool(full_stream_candidates),
            "seed58_0x4aa354_constructor_ledgers_found": len(seed58_constructor_ledgers),
            "broad_unseeded_0x4aa354_hit_count": broad_aa354_count,
        },
        "exact_blocker": (
            "Existing recovered artifacts do not contain a full same-run seed58 H3MapEd "
            "0x4aa354 selected reward/guard source stream with descriptor-vector and selected "
            "descriptor state. Available artifacts prove route entry, one seed10 attach-order "
            "sample, downstream 0x49cf34/0x49d69d mechanics, and an unseeded broad reward-chain "
            "flow, but they do not justify changing active native 0x4a5c07/0x49cf34 behavior for "
            "the seed58 route-entry gap."
        ),
        "next_source_backed_step": (
            "Provide or produce the same-run seed58 0x4aa354 stream artifact, or a source-backed "
            "replay artifact that proves the descriptor-vector membership and branch decisions for "
            "the exact pre-0x4a8260 boundary."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(DEFAULT_ARTIFACTS)
    output_path = args.out
    if not output_path.is_absolute():
        output_path = ROOT / output_path
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    invariants = summary["invariants"]
    status = "found" if invariants["full_same_run_seed58_source_stream_artifact_found"] else "missing"
    print(
        "RMG_H3MAPED_REWARD_GUARD_SOURCE_STREAM_COVERAGE "
        f"status={status} seed58_constructor_ledgers="
        f"{invariants['seed58_0x4aa354_constructor_ledgers_found']} "
        f"unseeded_0x4aa354_hits={invariants['broad_unseeded_0x4aa354_hit_count']} "
        f"windows_dll_build_required=false out={output_path}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
