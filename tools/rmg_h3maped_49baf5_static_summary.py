#!/usr/bin/env python3
"""Verify the H3MapEd 0x49baf5 final-member callback leaf."""

from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path
from typing import Any


DEFAULT_BINARY = Path(".artifacts/rmg_20seed_2p_small_h3maped_20260605/small_2p_seed_58_manual20/runtime/h3maped.exe")
DEFAULT_INNER_SUMMARY = Path(".artifacts/rmg_recovery/direct_generation_4aa3e9_inner_calls/4aa3e9_inner_summary.json")
TARGET = "0x0049baf5"
EXPECTED_BYTES = ["b0", "01", "c3"]
EXPECTED_TARGET = "0x0049baf5"


def run_objdump(binary: Path) -> str:
    completed = subprocess.run(
        [
            "objdump",
            "-Mintel",
            "-d",
            "--start-address=0x49baf5",
            "--stop-address=0x49baf8",
            str(binary),
        ],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return completed.stdout


def parse_instruction_bytes(objdump_text: str) -> list[str]:
    bytes_out: list[str] = []
    for line in objdump_text.splitlines():
        stripped = line.strip()
        if not stripped.startswith("49baf"):
            continue
        parts = stripped.split("\t")
        if len(parts) < 2:
            continue
        byte_tokens = [token.lower() for token in parts[1].split()]
        bytes_out.extend(byte_tokens)
    return bytes_out


def load_inner_summary(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def summarize(binary: Path, inner_summary_path: Path) -> dict[str, Any]:
    objdump_text = run_objdump(binary)
    instruction_bytes = parse_instruction_bytes(objdump_text)
    inner_summary = load_inner_summary(inner_summary_path)
    slot8_targets = inner_summary.get("combined_slot8_targets", {})
    slot8_count = int(slot8_targets.get(EXPECTED_TARGET, 0))
    return {
        "schema_id": "h3maped_49baf5_static_summary_v1",
        "binary": str(binary),
        "target": TARGET,
        "objdump": objdump_text,
        "instruction_bytes": instruction_bytes,
        "static_contract": {
            "returns_al": 1,
            "writes_memory": False,
            "stack_delta": 0,
            "description": "Leaf callback that returns true in AL and performs no memory writes.",
        },
        "inner_summary": str(inner_summary_path),
        "slot8_target_count_from_4aa3e9_inner_summary": slot8_count,
        "invariants": {
            "expected_leaf_bytes": instruction_bytes == EXPECTED_BYTES,
            "linked_from_4aa3e9_slot8_trace": slot8_count > 0,
            "no_memory_write_in_static_leaf": instruction_bytes == EXPECTED_BYTES,
        },
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", type=Path, default=DEFAULT_BINARY)
    parser.add_argument("--inner-summary", type=Path, default=DEFAULT_INNER_SUMMARY)
    parser.add_argument("--out", type=Path, required=True)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args.binary, args.inner_summary)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    status = "pass" if all(summary["invariants"].values()) else "partial"
    print(
        "RMG_H3MAPED_49BAF5_STATIC_SUMMARY "
        f"status={status} slot8_count={summary['slot8_target_count_from_4aa3e9_inner_summary']} out={args.out}"
    )
    return 0 if status == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
