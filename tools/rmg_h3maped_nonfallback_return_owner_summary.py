#!/usr/bin/env python3
"""Name the owners of unresolved non-fallback ``0x4a54a7`` return sites.

This does not recover the missing cell-transition/write-stream state. It turns
the remaining return addresses into source-backed owner/function surfaces so the
next Wine/Ghidra probe can target the correct private loop instead of treating
the non-fallback commits as one undifferentiated block.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


DEFAULT_CROSS_SEED_COMMIT_SURFACE = Path(
    ".artifacts/rmg_recovery/medium_4a54a7_cross_seed_commit_surface_summary_20260610.json"
)
DEFAULT_NONFALLBACK_CONTEXTS = Path(
    ".artifacts/rmg_recovery/nonfallback_4a54a7_return_context_summary_20260610.json"
)
DEFAULT_GHIDRA_4A9641 = Path(
    ".artifacts/rmg_recovery/ghidra_49b76d_policy_helper_dump/caller_004a9641_FUN_004a9641.txt"
)
DEFAULT_GHIDRA_4A9911 = Path(
    ".artifacts/rmg_recovery/ghidra_49b76d_policy_helper_dump/caller_004a9911_FUN_004a9911.txt"
)
DEFAULT_GHIDRA_4AA3E9 = Path(
    ".artifacts/rmg_recovery/ghidra_coord12_candidate_vector_helper_dump/"
    "caller_004aa3e9_FUN_004aa3e9.txt"
)
DEFAULT_4AA3E9_INNER = Path(
    ".artifacts/rmg_recovery/direct_generation_4aa3e9_inner_calls/4aa3e9_inner_summary.json"
)
DEFAULT_4AA9B7_ORDERED = Path(
    ".artifacts/rmg_recovery/direct_generation_4aa9b7_ordered_commit_trace/"
    "4aa9b7_ordered_commit_summary.json"
)
DEFAULT_4AA3E9_4A54A7_DYNAMIC = Path(
    ".artifacts/rmg_recovery/4aa3e9_4a54a7_dynamic_summary_20260610.json"
)
DEFAULT_4A9641_4A54A7_DYNAMIC = Path(
    ".artifacts/rmg_recovery/mine_owner_4a9641_4a54a7_dynamic_summary_20260610.json"
)
DEFAULT_4A9911_4A54A7_DYNAMIC = Path(
    ".artifacts/rmg_recovery/4a54a7_target_return_004a9c3f_dynamic_summary_20260610.json"
)
DEFAULT_OUT = Path(
    ".artifacts/rmg_recovery/nonfallback_4a54a7_return_owner_summary_20260610.json"
)


RETURN_SITE_OWNERS = {
    "0x004a98f0": {
        "owner_function": "0x004a9641",
        "owner_name": "mine_coordinate_object_builder_followup",
        "static_file_arg": "ghidra_4a9641",
        "required_markers": [
            "004a98ed: CALL dword ptr [EDX + 0x4]",
            "const, 0x4a98f0",
            "004a98f0: MOV BL,0x1",
        ],
        "next_state_needed": (
            "same-ledger capture from 0x4a9641 selected object callback through 0x4a54a7, "
            "0x4a56b6 projection writes, object-vector append, target-cell reference, and "
            "post-callback loop state"
        ),
    },
    "0x004a9c3f": {
        "owner_function": "0x004a9911",
        "owner_name": "mine_requirement_coordinate_object_loop",
        "static_file_arg": "ghidra_4a9911",
        "required_markers": [
            "004a9c3c: CALL dword ptr [EDX + 0x4]",
            "const, 0x4a9c3f",
            "004a9c3f: MOV EAX,dword ptr [EBP + -0x44]",
        ],
        "next_state_needed": (
            "same-ledger capture from 0x4a9911 eligibility/selection state through the "
            "selected object callback, 0x4a54a7 projection writes, object-vector append, "
            "target-cell reference, and loop counter/limit continuation state"
        ),
    },
    "0x004aa44d": {
        "owner_function": "0x004aa3e9",
        "owner_name": "reward_guard_final_wrapper_selected_member_commit",
        "static_file_arg": "ghidra_4aa3e9",
        "required_markers": [
            "004aa44a: CALL dword ptr [EDX + 0x4]",
            "const, 0x4aa44d",
            "004aa44d: INC dword ptr [EBP + 0x8]",
        ],
        "next_state_needed": (
            "same-ledger capture tying each 0x4aa3e9 selected-member slot +0x04 callback to "
            "0x4a54a7 target-cell afterstate, followed by wrapper projection source/destination "
            "bit mirroring and selected-member loop continuation"
        ),
    },
}


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def markers_present(text: str, markers: list[str]) -> dict[str, bool]:
    return {marker: marker in text for marker in markers}


def summarize(args: argparse.Namespace) -> dict[str, Any]:
    cross_seed = load_json(args.cross_seed_commit_surface)
    nonfallback = load_json(args.nonfallback_contexts)
    inner_4aa3e9 = load_json(args.inner_4aa3e9)
    ordered_4aa9b7 = load_json(args.ordered_4aa9b7)
    dynamic_4aa3e9 = load_json(args.dynamic_4aa3e9_4a54a7)
    dynamic_4a9641 = load_json(args.dynamic_4a9641_4a54a7)
    dynamic_4a9911 = load_json(args.dynamic_4a9911_4a54a7)
    static_texts = {
        "ghidra_4a9641": read_text(args.ghidra_4a9641),
        "ghidra_4a9911": read_text(args.ghidra_4a9911),
        "ghidra_4aa3e9": read_text(args.ghidra_4aa3e9),
    }
    return_site_counts = {
        str(key): int(value)
        for key, value in cross_seed.get("return_site_counts", {}).items()
        if isinstance(value, int)
    }

    unresolved_sites: dict[str, dict[str, Any]] = {}
    static_marker_matrix: dict[str, dict[str, bool]] = {}
    for return_site, owner in RETURN_SITE_OWNERS.items():
        markers = markers_present(
            static_texts[owner["static_file_arg"]], list(owner["required_markers"])
        )
        static_marker_matrix[return_site] = markers
        unresolved_sites[return_site] = {
            "cross_seed_count": return_site_counts.get(return_site, 0),
            "owner_function": owner["owner_function"],
            "owner_name": owner["owner_name"],
            "static_evidence": str(getattr(args, owner["static_file_arg"])),
            "static_markers": markers,
            "recovery_state": "owner_recovered_state_transition_pending",
            "next_state_needed": owner["next_state_needed"],
        }
    unresolved_sites["0x004aa44d"]["recovery_state"] = (
        "owner_recovered_sampled_same_ledger_write_stream_recovered_broader_coverage_pending"
    )
    unresolved_sites["0x004aa44d"]["sampled_write_stream_evidence"] = str(
        args.dynamic_4aa3e9_4a54a7
    )
    unresolved_sites["0x004aa44d"]["sampled_write_stream_contract"] = {
        "projection_write_count": dynamic_4aa3e9.get("projection_write_count"),
        "target_cell_low_word_before": dynamic_4aa3e9.get("metrics", {}).get(
            "target_cell_low_word_before"
        ),
        "target_cell_low_word_after": dynamic_4aa3e9.get("metrics", {}).get(
            "target_cell_low_word_after"
        ),
        "target_cell_low_word_cleared_to_zero": dynamic_4aa3e9.get("metrics", {}).get(
            "target_cell_low_word_cleared_to_zero"
        ),
    }
    unresolved_sites["0x004a98f0"]["recovery_state"] = (
        "owner_recovered_sampled_same_ledger_write_stream_recovered"
    )
    unresolved_sites["0x004a98f0"]["sampled_write_stream_evidence"] = str(
        args.dynamic_4a9641_4a54a7
    )
    unresolved_sites["0x004a98f0"]["sampled_write_stream_contract"] = {
        "projection_write_count": dynamic_4a9641.get("projection_write_count"),
        "target_cell_low_word_before": dynamic_4a9641.get("metrics", {}).get(
            "target_cell_low_word_before"
        ),
        "target_cell_low_word_after": dynamic_4a9641.get("metrics", {}).get(
            "target_cell_low_word_after"
        ),
        "target_cell_low_word_cleared_to_zero": dynamic_4a9641.get("metrics", {}).get(
            "target_cell_low_word_cleared_to_zero"
        ),
    }
    unresolved_sites["0x004a9c3f"]["recovery_state"] = (
        "owner_recovered_sampled_target_return_write_stream_recovered"
    )
    unresolved_sites["0x004a9c3f"]["sampled_write_stream_evidence"] = str(
        args.dynamic_4a9911_4a54a7
    )
    unresolved_sites["0x004a9c3f"]["sampled_write_stream_contract"] = {
        "status": dynamic_4a9911.get("status"),
        "projection_write_count": dynamic_4a9911.get("projection_write_count"),
        "target_cell_low_word_before": dynamic_4a9911.get("metrics", {}).get(
            "target_cell_low_word_before"
        ),
        "target_cell_low_word_after": dynamic_4a9911.get("metrics", {}).get(
            "target_cell_low_word_after"
        ),
        "target_cell_low_word_cleared_to_zero": dynamic_4a9911.get("metrics", {}).get(
            "target_cell_low_word_cleared_to_zero"
        ),
    }

    inner_slot4_targets = inner_4aa3e9.get("combined_slot4_targets", {})
    ordered_invariants = ordered_4aa9b7.get("invariants", {})
    dynamic_invariants = dynamic_4aa3e9.get("invariants", {})
    dynamic_4a9641_invariants = dynamic_4a9641.get("invariants", {})
    dynamic_4a9911_invariants = dynamic_4a9911.get("invariants", {})
    unresolved_count = sum(item["cross_seed_count"] for item in unresolved_sites.values())
    invariants = {
        "no_native_behavior_change": cross_seed.get("metrics", {}).get(
            "native_behavior_changed"
        )
        is False
        and nonfallback.get("metrics", {}).get("native_behavior_changed") is False,
        "no_objdump_used": cross_seed.get("metrics", {}).get("used_objdump") is False
        and nonfallback.get("metrics", {}).get("used_objdump") is False,
        "prior_744a_context_remains_recovered": nonfallback.get("status")
        == "nonfallback_4a54a7_744a_sampled_contract_recovered_remaining_contexts_pending",
        "all_unresolved_return_sites_have_cross_seed_counts": set(unresolved_sites)
        == {"0x004a98f0", "0x004a9c3f", "0x004aa44d"}
        and all(item["cross_seed_count"] > 0 for item in unresolved_sites.values()),
        "unresolved_count_matches_prior_summary": unresolved_count
        == nonfallback.get("metrics", {}).get("unresolved_nonfallback_commit_count"),
        "all_static_owner_markers_found": all(
            all(markers.values()) for markers in static_marker_matrix.values()
        ),
        "4aa3e9_runtime_slot4_targets_4a54a7": inner_slot4_targets.get("0x004a54a7", 0) > 0
        and len(inner_slot4_targets) == 1,
        "4aa9b7_successful_handoff_to_4aa3e9_recovered": ordered_invariants.get(
            "successful_commits_have_ordered_4aa3e9_handoff"
        )
        is True,
        "4aa3e9_4aa44d_sampled_write_stream_recovered": dynamic_4aa3e9.get("status")
        == "4aa3e9_4aa44d_4a54a7_write_stream_recovered"
        and dynamic_invariants.get("no_native_behavior_change") is True
        and dynamic_invariants.get("no_objdump_used") is True
        and dynamic_invariants.get("commit_returns_to_4aa44d") is True
        and dynamic_invariants.get("projection_write_stream_captured") is True,
        "4a9641_4a98f0_sampled_write_stream_recovered": dynamic_4a9641.get("status")
        == "mine_owner_4a9641_4a54a7_write_stream_recovered"
        and dynamic_4a9641_invariants.get("no_native_behavior_change") is True
        and dynamic_4a9641_invariants.get("no_objdump_used") is True
        and dynamic_4a9641_invariants.get("commit_returns_to_owner_after_callback") is True
        and dynamic_4a9641_invariants.get("projection_write_stream_captured") is True,
        "4a9911_4a9c3f_sampled_target_return_write_stream_recovered": dynamic_4a9911.get(
            "status"
        )
        == "4a54a7_target_return_004a9c3f_write_stream_recovered"
        and dynamic_4a9911_invariants.get("no_native_behavior_change") is True
        and dynamic_4a9911_invariants.get("no_objdump_used") is True
        and dynamic_4a9911_invariants.get("commit_returns_to_target") is True
        and dynamic_4a9911_invariants.get("projection_write_stream_captured") is True,
    }
    status = (
        "nonfallback_4a54a7_return_owners_sampled_streams_recovered"
        if all(invariants.values())
        else "nonfallback_4a54a7_return_owner_recovery_incomplete"
    )

    return {
        "schema_id": "h3maped_nonfallback_4a54a7_return_owner_summary_v1",
        "status": status,
        "scope": (
            "Owner/function classification for unresolved non-fallback 0x4a54a7 return sites "
            "in current one-level land evidence. This does not recover the missing target-cell "
            "afterstate or authorize native RMG behavior changes."
        ),
        "inputs": {
            "cross_seed_commit_surface": str(args.cross_seed_commit_surface),
            "nonfallback_contexts": str(args.nonfallback_contexts),
            "ghidra_4a9641": str(args.ghidra_4a9641),
            "ghidra_4a9911": str(args.ghidra_4a9911),
            "ghidra_4aa3e9": str(args.ghidra_4aa3e9),
            "inner_4aa3e9": str(args.inner_4aa3e9),
            "ordered_4aa9b7": str(args.ordered_4aa9b7),
            "dynamic_4aa3e9_4a54a7": str(args.dynamic_4aa3e9_4a54a7),
            "dynamic_4a9641_4a54a7": str(args.dynamic_4a9641_4a54a7),
            "dynamic_4a9911_4a54a7": str(args.dynamic_4a9911_4a54a7),
        },
        "invariants": invariants,
        "metrics": {
            "native_behavior_changed": False,
            "used_objdump": False,
            "overall_goal_complete": False,
            "unresolved_return_site_count": len(unresolved_sites),
            "unresolved_nonfallback_commit_count": unresolved_count,
            "4aa3e9_slot4_callback_count": inner_slot4_targets.get("0x004a54a7", 0),
            "4aa9b7_success_call_count": ordered_4aa9b7.get("success_call_count"),
            "4aa3e9_4aa44d_sampled_projection_write_count": dynamic_4aa3e9.get(
                "projection_write_count"
            ),
            "4a9641_4a98f0_sampled_projection_write_count": dynamic_4a9641.get(
                "projection_write_count"
            ),
            "4a9911_4a9c3f_sampled_projection_write_count": dynamic_4a9911.get(
                "projection_write_count"
            ),
        },
        "unresolved_return_sites": unresolved_sites,
        "source_backed_conclusion": (
            "The remaining non-fallback 0x4a54a7 surface splits into three source-backed owner "
            "loops. 0x4a98f0 is the selected object callback return in 0x4a9641; 0x4a9c3f is "
            "the selected object callback return in 0x4a9911; and 0x4aa44d is the selected-member "
            "callback return in 0x4aa3e9. Existing 0x4aa9b7/0x4aa3e9 runtime summaries prove the "
            "reward/guard wrapper handoff and sampled 0x4aa3e9 slot +0x04 callbacks into 0x4a54a7. "
            "Focused Wine traces now recover one sampled 0x4aa44d same-ledger write stream "
            "one sampled 0x4a98f0 same-ledger write stream, and one sampled 0x4a9c3f "
            "target-return same-ledger write stream. The 0x4aa44d sample lowers the target "
            "low word from 14 to 2 and performs 90 unique projection writes. The 0x4a98f0 "
            "sample lowers the target low word from 27 to 2 and performs 319 unique projection "
            "writes. The 0x4a9c3f sample clears the target low word from 2 to 0 and performs "
            "98 unique projection writes."
        ),
        "remaining_gap": (
            "Broaden the sampled 0x4aa3e9 -> 0x4aa44d, 0x4a9641 -> 0x4a98f0, and "
            "0x4a9911 -> 0x4a9c3f write-stream recovery only if native port authority needs "
            "all instances rather than sampled contracts. Full end-to-end native-port authority "
            "still also needs the separate generator+0xf5c, relation/control linkage, global "
            "label, broader mode/source-state, and reached-cleanup gaps."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--cross-seed-commit-surface",
        type=Path,
        default=DEFAULT_CROSS_SEED_COMMIT_SURFACE,
    )
    parser.add_argument("--nonfallback-contexts", type=Path, default=DEFAULT_NONFALLBACK_CONTEXTS)
    parser.add_argument("--ghidra-4a9641", type=Path, default=DEFAULT_GHIDRA_4A9641)
    parser.add_argument("--ghidra-4a9911", type=Path, default=DEFAULT_GHIDRA_4A9911)
    parser.add_argument("--ghidra-4aa3e9", type=Path, default=DEFAULT_GHIDRA_4AA3E9)
    parser.add_argument("--inner-4aa3e9", type=Path, default=DEFAULT_4AA3E9_INNER)
    parser.add_argument("--ordered-4aa9b7", type=Path, default=DEFAULT_4AA9B7_ORDERED)
    parser.add_argument(
        "--dynamic-4aa3e9-4a54a7",
        type=Path,
        default=DEFAULT_4AA3E9_4A54A7_DYNAMIC,
    )
    parser.add_argument(
        "--dynamic-4a9641-4a54a7",
        type=Path,
        default=DEFAULT_4A9641_4A54A7_DYNAMIC,
    )
    parser.add_argument(
        "--dynamic-4a9911-4a54a7",
        type=Path,
        default=DEFAULT_4A9911_4A54A7_DYNAMIC,
    )
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_NONFALLBACK_4A54A7_OWNERS status={summary['status']} out={args.out}")
    return (
        0
        if summary["status"]
        == "nonfallback_4a54a7_return_owners_sampled_streams_recovered"
        else 1
    )


if __name__ == "__main__":
    raise SystemExit(main())
