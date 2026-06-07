#!/usr/bin/env python3
"""Summarize H3MapEd reward/guard-chain breakpoint traces."""

from __future__ import annotations

import argparse
import json
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any


REWARD_CHAIN = [
    "0x004ac552",
    "0x004a8c15",
    "0x004a9d6a",
    "0x004aadd2",
    "0x004aab7e",
    "0x004aa354",
    "0x004aa1db",
    "0x0049d471",
    "0x0049d2e0",
    "0x004aa9b7",
    "0x004aa3e9",
]

KNOWN_RETURNS = {
    "0x004ac552": "outer_generation_stage_entry",
    "0x004a8c15": "pre_reward_normalization_return_to_0x4ac552",
    "0x004a9d6a": "mine_phase_return_to_0x4ac552",
    "0x004aadd2": "reward_phase_setup_return_to_0x4ac552",
    "0x004aab7e": "reward_scheduler_return_to_0x4ac552",
    "0x004aa354": "wrapper_seed_return_to_0x4aab7e",
    "0x004aa1db": "wrapper_member_seed_return_to_0x4aa354",
    "0x0049d471": "secondary_member_validator_return_to_0x4aa1db",
    "0x004aa9b7": "reward_coordinate_scan_return_to_0x4aab7e_or_0x4ad7f7",
    "0x004aa3e9": "reward_wrapper_projection_return_to_0x4aa9b7",
}

KNOWN_CALLER_RETURNS = {
    "0x0049d5a5": "0x49d471 secondary-member validator",
    "0x0049d111": "0x49cf34 selected-member candidate filter",
    "0x004aacee": "0x4aab7e first reward-coordinate projection attempt",
    "0x004aad47": "0x4aab7e later reward-coordinate projection attempt",
}


def normalize_address(value: str) -> str:
    return "0x%08x" % int(value, 0)


def summarize(ledger: dict[str, Any]) -> dict[str, Any]:
    counts: Counter[str] = Counter()
    returns: dict[str, Counter[str]] = defaultdict(Counter)
    first_seen: dict[str, int] = {}
    ordered_prefix: list[dict[str, Any]] = []

    for index, event in enumerate(ledger.get("events", []), start=1):
        address = normalize_address(str(event.get("address", "0")))
        counts[address] += 1
        first_seen.setdefault(address, index)
        ret = event.get("derived", {}).get("return_address")
        if ret:
            returns[address][normalize_address(str(ret))] += 1
        if len(ordered_prefix) < 120 and address in REWARD_CHAIN:
            ordered_prefix.append(
                {
                    "index": index,
                    "address": address,
                    "return_address": normalize_address(str(ret)) if ret else "",
                    "registers": {
                        key: event.get("registers", {}).get(key)
                        for key in ("eax", "ebx", "ecx", "edx", "esi", "edi", "ebp", "esp")
                        if key in event.get("registers", {})
                    },
                }
            )

    missing = [address for address in REWARD_CHAIN if counts[address] == 0]
    hit_counts = {
        address: {
            "count": counts[address],
            "first_seen_event": first_seen.get(address),
            "return_addresses": [
                {
                    "return_address": ret,
                    "count": count,
                    "label": KNOWN_CALLER_RETURNS.get(ret, KNOWN_RETURNS.get(address, "")),
                }
                for ret, count in returns[address].most_common()
            ],
        }
        for address in REWARD_CHAIN
        if counts[address] > 0
    }

    d2e0_returns = returns.get("0x0049d2e0", Counter())
    return {
        "schema_id": "h3maped_reward_chain_trace_summary_v1",
        "ledger": ledger.get("log_path", ""),
        "event_count": int(ledger.get("event_count", 0)),
        "reward_chain_addresses": REWARD_CHAIN,
        "missing_reward_chain_addresses": missing,
        "hit_counts": hit_counts,
        "ordered_prefix": ordered_prefix,
        "invariants": {
            "reaches_reward_scheduler_after_0x4a8c15": counts["0x004aab7e"] > 0,
            "reaches_wrapper_seed_helper": counts["0x004aa354"] > 0 and counts["0x004aa1db"] > 0,
            "reaches_secondary_member_validator": counts["0x0049d471"] > 0,
            "reaches_candidate_acceptance_helper": counts["0x0049d2e0"] > 0,
            "reaches_candidate_acceptance_from_secondary_member_validator": d2e0_returns["0x0049d5a5"] > 0,
            "reaches_candidate_acceptance_from_selected_member_filter": d2e0_returns["0x0049d111"] > 0,
            "reaches_reward_coordinate_commit": counts["0x004aa9b7"] > 0 and counts["0x004aa3e9"] > 0,
        },
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ledger", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    ledger = json.loads(args.ledger.read_text(encoding="utf-8"))
    summary = summarize(ledger)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    missing = ",".join(summary["missing_reward_chain_addresses"])
    status = "pass" if not summary["missing_reward_chain_addresses"] else "partial"
    print(
        "RMG_H3MAPED_REWARD_CHAIN_TRACE_SUMMARY "
        f"status={status} events={summary['event_count']} missing={missing or 'none'} out={args.out}"
    )
    return 0 if status == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
