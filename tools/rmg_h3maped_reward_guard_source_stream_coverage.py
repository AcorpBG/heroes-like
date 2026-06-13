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
DEFAULT_RECOVERY_ROOT = Path(".artifacts/rmg_recovery")

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
    "seed58_4aa354_source_stream_summary": Path(
        ".artifacts/rmg_recovery/small_seed58_4aa354_source_stream_full_20260612145829/"
        "4aa354_source_stream_summary.json"
    ),
    "seed58_4aa354_ordered_commit_summary": Path(
        ".artifacts/rmg_recovery/small_seed58_4aa354_source_stream_full_20260612145829/"
        "4aa9b7_ordered_commit_summary.json"
    ),
    "seed58_4aa354_attach_order_summary": Path(
        ".artifacts/rmg_recovery/small_seed58_4aa354_source_stream_full_20260612145829/"
        "reward_attach_order_summary.json"
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
TEXT_SCAN_EXTENSIONS = {".json", ".log", ".txt"}
SELF_SUMMARY_PREFIX = "reward_guard_source_stream_coverage_summary"


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
    schema_id = str(data.get("schema_id", ""))
    if schema_id in {
        "h3maped_4aa354_source_stream_summary_v1",
        "h3maped_4aa9b7_ordered_commit_summary_v1",
        "h3maped_reward_attach_order_summary_v1",
    }:
        ledger = str(data.get("ledger", "")).lower()
        if "seed58" in ledger or "seed_58" in ledger:
            return 58
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
    schema_id = str(data.get("schema_id", ""))
    if schema_id == "h3maped_4aa354_source_stream_summary_v1":
        counts["0x004aa354"] += int(data.get("call_count", 0) or 0)
        counts["0x0049cf34"] += int(data.get("guard_attach_call_count_0x49cf34", 0) or 0)
        call_sequence = data.get("call_sequence")
        if isinstance(call_sequence, list):
            reached_count = sum(
                1 for item in call_sequence
                if isinstance(item, dict) and item.get("reached_4aa3e9") is True
            )
            counts["0x004aa9b7"] += len(call_sequence)
            counts["0x004aa3e9"] += reached_count
    elif schema_id == "h3maped_4aa9b7_ordered_commit_summary_v1":
        counts["0x004aa9b7"] += int(data.get("call_count", 0) or 0)
        counts["0x004aa3e9"] += int(data.get("success_call_count", 0) or 0)
    elif schema_id == "h3maped_reward_attach_order_summary_v1":
        attach = data.get("49cf34_attach")
        if isinstance(attach, dict):
            counts["0x0049cf34"] += 1
        post = data.get("post_attach_4aa9b7")
        if isinstance(post, dict):
            counts["0x004aa9b7"] += 1
    return counts


def first_indexes(data: dict[str, Any]) -> dict[str, int]:
    indexes: dict[str, int] = {}
    for index, event in enumerate(data.get("events", []), start=1):
        if not isinstance(event, dict):
            continue
        address = normalize_address(event.get("address"))
        indexes.setdefault(address, index)
    schema_id = str(data.get("schema_id", ""))
    if schema_id == "h3maped_4aa354_source_stream_summary_v1":
        indexes.setdefault("0x004aa354", 1)
        indexes.setdefault("0x004aa9b7", 2)
        if int(data.get("guard_attach_call_count_0x49cf34", 0) or 0) > 0:
            indexes.setdefault("0x0049cf34", 3)
        if int(data.get("successful_handoff_count", 0) or 0) > 0:
            indexes.setdefault("0x004aa3e9", 4)
    elif schema_id == "h3maped_4aa9b7_ordered_commit_summary_v1":
        indexes.setdefault("0x004aa9b7", 1)
        if int(data.get("success_call_count", 0) or 0) > 0:
            indexes.setdefault("0x004aa3e9", 2)
    elif schema_id == "h3maped_reward_attach_order_summary_v1":
        indexes.setdefault("0x004aa354", 1)
        indexes.setdefault("0x004aa38f", 2)
        indexes.setdefault("0x004aa3a8", 3)
        indexes.setdefault("0x004aa3b6", 4)
        indexes.setdefault("0x0049cf34", 5)
        indexes.setdefault("0x004aa3bb", 6)
        indexes.setdefault("0x004aa9b7", 7)
    return indexes


def summarized_source_stream_classification(data: dict[str, Any]) -> str | None:
    schema_id = str(data.get("schema_id", ""))
    if schema_id == "h3maped_4aa354_source_stream_summary_v1":
        invariants = data.get("invariants")
        call_sequence = data.get("call_sequence")
        if (
            requested_seed(data) == 58
            and isinstance(invariants, dict)
            and invariants.get("all_aa354_calls_completed") is True
            and invariants.get("has_successful_handoff") is True
            and isinstance(call_sequence, list)
            and len(call_sequence) == int(data.get("call_count", -1))
        ):
            return "seed58_same_run_4aa354_callstream_summary_descriptor_state_incomplete"
    if schema_id == "h3maped_4aa9b7_ordered_commit_summary_v1":
        invariants = data.get("invariants")
        if (
            requested_seed(data) == 58
            and isinstance(invariants, dict)
            and invariants.get("has_completed_calls") is True
            and invariants.get("has_successful_commit_calls") is True
        ):
            return "seed58_4aa9b7_ordered_commit_summary_orphan_limited"
    if schema_id == "h3maped_reward_attach_order_summary_v1":
        invariants = data.get("invariants")
        if requested_seed(data) == 58 and isinstance(invariants, dict):
            return "seed58_reward_attach_order_summary_partial"
    return None


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
    classification = summarized_source_stream_classification(data) or classify_artifact(
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


def iter_recovery_json_paths(recovery_root: Path, output_path: Path | None) -> list[Path]:
    root = ROOT / recovery_root if not recovery_root.is_absolute() else recovery_root
    excluded = output_path.resolve() if output_path is not None and output_path.exists() else None
    paths: list[Path] = []
    for path in sorted(root.rglob("*.json")):
        if excluded is not None and path.resolve() == excluded:
            continue
        if path.name.startswith(SELF_SUMMARY_PREFIX):
            continue
        paths.append(path.relative_to(ROOT))
    return paths


def iter_text_hit_paths(recovery_root: Path, output_path: Path | None) -> list[Path]:
    root = ROOT / recovery_root if not recovery_root.is_absolute() else recovery_root
    excluded = output_path.resolve() if output_path is not None and output_path.exists() else None
    hits: list[Path] = []
    for path in sorted(root.rglob("*")):
        if not path.is_file() or path.suffix.lower() not in TEXT_SCAN_EXTENSIONS:
            continue
        if excluded is not None and path.resolve() == excluded:
            continue
        if path.name.startswith(SELF_SUMMARY_PREFIX):
            continue
        try:
            text = path.read_text(encoding="utf-8", errors="ignore").lower()
        except OSError:
            continue
        if "0x004aa354" in text or "004aa354" in text or "0x4aa354" in text:
            hits.append(path.relative_to(ROOT))
    return hits


def recursive_artifact_summary(relative_path: Path) -> dict[str, Any]:
    path = ROOT / relative_path
    data = load_json(path)
    if data is None:
        return {
            "label": str(relative_path),
            "path": str(relative_path),
            "exists": False,
            "classification": "unreadable_json_artifact",
        }
    if not isinstance(data.get("events"), list):
        text = path.read_text(encoding="utf-8", errors="ignore").lower()
        classification = summarized_source_stream_classification(data)
        return {
            "label": str(relative_path),
            "path": str(relative_path),
            "exists": True,
            "schema_id": data.get("schema_id"),
            "event_count": data.get("event_count"),
            "seed_controlled": requested_seed(data) is not None,
            "requested_seed": requested_seed(data),
            "call_count": data.get("call_count"),
            "completed_call_count": data.get("completed_call_count"),
            "successful_handoff_count": data.get("successful_handoff_count"),
            "guard_attach_call_count_0x49cf34": data.get("guard_attach_call_count_0x49cf34"),
            "invariants": data.get("invariants"),
            "summary_text_mentions_0x4aa354": (
                "0x004aa354" in text or "004aa354" in text or "0x4aa354" in text
            ),
            "classification": classification or "summary_text_reference_not_event_stream",
        }
    return artifact_summary(str(relative_path), relative_path)


def summarize(artifacts: dict[str, Path], recovery_root: Path, output_path: Path | None) -> dict[str, Any]:
    curated_summaries = [artifact_summary(label, path) for label, path in artifacts.items()]
    recursive_json_paths = iter_recovery_json_paths(recovery_root, output_path)
    recursive_summaries = [recursive_artifact_summary(path) for path in recursive_json_paths]
    text_hit_paths = iter_text_hit_paths(recovery_root, output_path)
    event_stream_summaries = [
        item
        for item in recursive_summaries
        if isinstance(item.get("required_address_counts"), dict)
        and any(int(count) > 0 for count in item["required_address_counts"].values())
    ]
    recursive_full_stream_candidates = [
        item
        for item in recursive_summaries
        if item.get("classification") == "candidate_full_seed58_same_run_source_stream"
    ]
    recursive_callstream_summaries = [
        item
        for item in recursive_summaries
        if item.get("classification") == "seed58_same_run_4aa354_callstream_summary_descriptor_state_incomplete"
    ]
    recursive_seed58_constructor_ledgers = [
        item
        for item in recursive_summaries
        if item.get("requested_seed") == 58
        and item.get("required_address_counts", {}).get("0x004aa354", 0) > 0
    ]
    recursive_broad_aa354_count = sum(
        int(item.get("required_address_counts", {}).get("0x004aa354", 0))
        for item in recursive_summaries
    )
    text_seed58_aa354_paths = [
        str(path)
        for path in text_hit_paths
        if "seed58" in str(path).lower() or "seed_58" in str(path).lower()
    ]

    summaries = curated_summaries
    full_stream_candidates = [
        item
        for item in summaries
        if item.get("classification") == "candidate_full_seed58_same_run_source_stream"
    ]
    callstream_summaries = [
        item
        for item in summaries
        if item.get("classification") == "seed58_same_run_4aa354_callstream_summary_descriptor_state_incomplete"
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
        "recursive_recovery_corpus_scan": {
            "recovery_root": str(recovery_root),
            "json_file_count": len(recursive_json_paths),
            "json_event_hit_artifact_count": len(event_stream_summaries),
            "text_file_0x4aa354_hit_count": len(text_hit_paths),
            "text_seed58_0x4aa354_hit_files": text_seed58_aa354_paths,
            "event_stream_artifacts": event_stream_summaries,
            "seed58_same_run_4aa354_callstream_summaries": recursive_callstream_summaries,
            "summary_text_reference_files": [
                {
                    "path": item["path"],
                    "schema_id": item.get("schema_id"),
                    "requested_seed": item.get("requested_seed"),
                }
                for item in recursive_summaries
                if item.get("classification") == "summary_text_reference_not_event_stream"
                and item.get("summary_text_mentions_0x4aa354")
            ],
        },
        "invariants": {
            "full_same_run_seed58_source_stream_artifact_found": bool(full_stream_candidates)
            or bool(recursive_full_stream_candidates),
            "seed58_same_run_4aa354_callstream_summary_found": bool(callstream_summaries)
            or bool(recursive_callstream_summaries),
            "source_backed_native_rule_available": bool(full_stream_candidates)
            or bool(recursive_full_stream_candidates),
            "seed58_0x4aa354_constructor_ledgers_found": len(seed58_constructor_ledgers),
            "recursive_seed58_0x4aa354_constructor_ledgers_found": len(recursive_seed58_constructor_ledgers),
            "broad_unseeded_0x4aa354_hit_count": broad_aa354_count,
            "recursive_0x4aa354_event_hit_count": recursive_broad_aa354_count,
            "recursive_json_event_hit_artifact_count": len(event_stream_summaries),
            "recursive_text_seed58_0x4aa354_hit_file_count": len(text_seed58_aa354_paths),
        },
        "exact_blocker": (
            "Recovered artifacts now include a seed58 same-run 0x4aa354 callstream summary "
            "with completed call ordering, guard-attach counts, and successful 0x4aa9b7/0x4aa3e9 "
            "handoffs. That summary is not yet a full native behavior authority because it still "
            "does not expose the descriptor-vector membership and selected descriptor/object "
            "state required to drive generic 0x4a5c07/0x49cf34 adoption from native code."
        ),
        "next_source_backed_step": (
            "Join the seed58 0x4aa354 callstream summary to selected descriptor/object identity "
            "and descriptor-vector state, then compare those per-call records against native "
            "reward selection before enabling active 0x4a5c07/0x49cf34 behavior."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--recovery-root", type=Path, default=DEFAULT_RECOVERY_ROOT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    output_path = args.out
    if not output_path.is_absolute():
        output_path = ROOT / output_path
    summary = summarize(DEFAULT_ARTIFACTS, args.recovery_root, output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    invariants = summary["invariants"]
    status = "found" if invariants["full_same_run_seed58_source_stream_artifact_found"] else "missing"
    print(
        "RMG_H3MAPED_REWARD_GUARD_SOURCE_STREAM_COVERAGE "
        f"status={status} seed58_callstream_summary_found="
        f"{str(invariants['seed58_same_run_4aa354_callstream_summary_found']).lower()} "
        f"seed58_constructor_ledgers="
        f"{invariants['recursive_seed58_0x4aa354_constructor_ledgers_found']} "
        f"recursive_0x4aa354_hits={invariants['recursive_0x4aa354_event_hit_count']} "
        f"seed58_text_hits={invariants['recursive_text_seed58_0x4aa354_hit_file_count']} "
        f"windows_dll_build_required=false out={output_path}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
