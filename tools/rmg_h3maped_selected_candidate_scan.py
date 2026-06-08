#!/usr/bin/env python3
"""Run a focused natural H3MapEd selected-candidate relation scan.

This wraps ``rmg_h3maped_recovery_interactive_trace.py`` with the exact
``0x4ac5a6`` address commands needed by
``rmg_h3maped_selected_candidate_summary.py``. The scan is intentionally about
natural candidate selection only; it does not force the selected index and does
not change native RMG behavior.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path


TRACE_TOOL = Path("tools/rmg_h3maped_recovery_interactive_trace.py")
SUMMARY_TOOL = Path("tools/rmg_h3maped_selected_candidate_summary.py")
DEFAULT_OUT_ROOT = Path(".artifacts/rmg_recovery")


def selected_expr() -> str:
    return "*(int*)(*(int*)($esi+0x10d4)+$edx*4)"


def owner_expr(owner_index: int) -> str:
    offset = owner_index * 4
    return (
        "*(int*)("
        f"*(int*)({selected_expr()}+0x14)"
        f"+0x{offset:02x})"
    )


def build_address_commands() -> list[str]:
    commands = [
        f"0x004ac5a6=x/48x *(int*)($esi+0x10d4)",
        f"0x004ac5a6=x/24x {selected_expr()}",
        f"0x004ac5a6=x/16x *(int*)({selected_expr()}+0x14)",
    ]
    for owner_index in range(8):
        commands.append(f"0x004ac5a6=x/4x ({owner_expr(owner_index)}+0xc4)")
    for owner_index in range(8):
        commands.append(f"0x004ac5a6=x/32x *(int*)({owner_expr(owner_index)}+0xc8)")
    return commands


def run_command(command: list[str], cwd: Path) -> None:
    subprocess.run(command, cwd=cwd, check=True, text=True)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--h3maped-runtime", type=Path)
    parser.add_argument("--wineprefix", type=Path)
    parser.add_argument("--out-root", type=Path, default=DEFAULT_OUT_ROOT)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--map-size", default="medium", choices=["small", "medium", "large", "xlarge"])
    parser.add_argument("--human-computer-down", type=int, default=1)
    parser.add_argument("--computer-only-down", type=int, default=1)
    parser.add_argument("--monster-strength-down", type=int, default=-1)
    parser.add_argument("--water-none", action="store_true")
    parser.add_argument("--display-number", type=int, default=116)
    parser.add_argument("--generate-wait-seconds", type=int, default=2)
    parser.add_argument("--debugger-timeout", type=int, default=120)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    repo_root = args.repo_root.resolve()
    out_dir = args.out_root / f"medium_selected_candidate_relation_scan_{args.tag}"
    summary_path = out_dir / "selected_candidate_relation_summary.json"
    ledger_path = out_dir / "winedbg_interactive_trace_ledger.json"

    trace_command = [
        sys.executable,
        str(TRACE_TOOL),
        "--out-dir",
        str(out_dir),
        "--map-size",
        args.map_size,
        "--human-computer-down",
        str(args.human_computer_down),
        "--computer-only-down",
        str(args.computer_only_down),
        "--generate-wait-seconds",
        str(args.generate_wait_seconds),
        "--debugger-timeout",
        str(args.debugger_timeout),
        "--display-number",
        str(args.display_number),
        "--max-events",
        "1",
        "--breakpoints",
        "0x004ac5a6",
        "--stop-after",
        "0x004ac5a6",
        "--lite",
    ]
    if args.h3maped_runtime:
        trace_command.extend(["--h3maped-runtime", str(args.h3maped_runtime)])
    if args.wineprefix:
        trace_command.extend(["--wineprefix", str(args.wineprefix)])
    if args.water_none:
        trace_command.append("--water-none")
    if args.monster_strength_down >= 0:
        trace_command.extend(["--monster-strength-down", str(args.monster_strength_down)])
    for address_command in build_address_commands():
        trace_command.extend(["--address-command", address_command])

    run_command(trace_command, repo_root)
    run_command(
        [
            sys.executable,
            str(SUMMARY_TOOL),
            "--ledger",
            str(ledger_path),
            "--out",
            str(summary_path),
        ],
        repo_root,
    )
    summary = json.loads(summary_path.read_text(encoding="utf-8"))
    print(
        "RMG_H3MAPED_SELECTED_CANDIDATE_SCAN "
        f"tag={args.tag} status={summary['status']} "
        f"selected_index={summary['selected_index']} "
        f"candidate_count={summary['candidate_count']} "
        f"relations={summary['total_relation_record_count']} "
        f"border_guard_records={summary['border_guard_relation_record_count']} "
        f"summary={summary_path}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
