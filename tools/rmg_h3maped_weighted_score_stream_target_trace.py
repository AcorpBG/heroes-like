#!/usr/bin/env python3
"""Trace one weighted 0x4a901a materialization score-write stream.

This is recovery tooling only. The generic interactive tracer can arm
``0x4a56b6`` after the first ``0x4a9322`` dispatch, but then it also stops on
large intervening non-weighted projection streams. This focused tracer waits
for a requested weighted dispatch index, arms the score-write breakpoints only
then, and stops at that dispatch's caller-after site.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

import pexpect

from rmg_h3maped_controlled_reference import DEFAULT_H3MAPED_EXE
from rmg_h3maped_recovery_interactive_trace import (
    PROMPT_RE,
    STOP_RE,
    drive_h3maped_ui,
    normalize_address,
    prepare_seed_patched_runtime,
)
from rmg_h3maped_recovery_trace import DEFAULT_RUNTIME


DEFAULT_OUT_DIR = Path(".artifacts/rmg_recovery/r3_weighted_score_stream_target_trace_20260611")
DISPATCH = "0x004a9322"
WRITE_BEFORE = "0x004a56b6"
WRITE_AFTER = "0x004a56b9"
RETURN_SITE = "0x004a5756"
CALLER_AFTER = "0x004a9325"
HEX_LINE_RE = re.compile(r"0x([0-9a-fA-F]+):\s+((?:[0-9a-fA-F]{8}\s*)+)")


def issue_capture(child: pexpect.spawn, command: str, timeout: int) -> str:
    child.send(command + "\r")
    child.expect(PROMPT_RE, timeout=timeout)
    return child.before


def parse_hex_words(output: str) -> list[dict[str, Any]]:
    lines: list[dict[str, Any]] = []
    for match in HEX_LINE_RE.finditer(output):
        lines.append(
            {
                "address": int(match.group(1), 16),
                "words": [int(word, 16) for word in match.group(2).split()],
            }
        )
    return lines


def parse_registers(output: str) -> dict[str, int]:
    registers: dict[str, int] = {}
    for name, value in re.findall(r"\b([A-Z]{2,3}):([0-9a-fA-F]{8})\b", output):
        registers[name.lower()] = int(value, 16)
    return registers


def qhex(value: int | None) -> str | None:
    return None if value is None else f"0x{value & 0xFFFFFFFF:08x}"


def stack_dispatch_from_lines(lines: list[dict[str, Any]]) -> dict[str, Any]:
    if not lines:
        return {}
    words = lines[0].get("words", [])
    return {
        "record_pointer": qhex(words[0] if len(words) > 0 else None),
        "x": words[1] if len(words) > 1 else None,
        "y": words[2] if len(words) > 2 else None,
        "level": words[3] if len(words) > 3 else None,
    }


def cell_snapshot(lines: list[dict[str, Any]]) -> dict[str, Any]:
    if not lines:
        return {"cell_pointer": None}
    base = int(lines[0]["address"])
    words: list[int] = []
    for line in lines:
        words.extend(int(word) & 0xFFFFFFFF for word in line.get("words", []))
    word20 = words[8] if len(words) > 8 else None
    word24 = words[9] if len(words) > 9 else None
    word28 = words[10] if len(words) > 10 else None
    return {
        "cell_pointer": qhex(base),
        "word20": qhex(word20),
        "word24": qhex(word24),
        "word28": qhex(word28),
        "score_low_word": None if word20 is None else word20 & 0xFFFF,
        "owner_byte2": None if word20 is None else ((word20 >> 16) & 0xFF),
        "terrain": None if word24 is None else word24 & 0x3F,
        "bit22": None if word28 is None else bool(word28 & (1 << 22)),
        "bit26": None if word28 is None else bool(word28 & (1 << 26)),
        "bit27": None if word28 is None else bool(word28 & (1 << 27)),
    }


def vector_count(lines: list[dict[str, Any]]) -> int | None:
    if not lines:
        return None
    words = lines[0].get("words", [])
    if len(words) < 2:
        return None
    begin, end = int(words[0]), int(words[1])
    return (end - begin) // 4


def counter98(lines: list[dict[str, Any]]) -> int | None:
    words: list[int] = []
    for line in lines:
        words.extend(int(word) & 0xFFFFFFFF for word in line.get("words", []))
    return words[98] if len(words) > 98 else None


def run_inside_xvfb(args: argparse.Namespace) -> dict[str, Any]:
    env = os.environ.copy()
    env["WINEPREFIX"] = str(args.wineprefix)
    env["WINEARCH"] = "win32"
    subprocess.run(
        ["wineboot", "-u"],
        cwd=args.h3maped_runtime,
        env=env,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )

    child = pexpect.spawn(
        "winedbg",
        ["./h3maped.exe"],
        cwd=str(args.h3maped_runtime),
        env=env,
        encoding="utf-8",
        timeout=args.debugger_timeout,
    )
    log_path = args.out_dir / f"winedbg_weighted_dispatch{args.target_dispatch_index}_score_stream.log"
    summary: dict[str, Any] = {
        "schema_id": "h3maped_weighted_score_stream_target_trace_v1",
        "target_dispatch_index": args.target_dispatch_index,
        "events": [],
        "dispatches_seen": [],
        "score_write_before_count": 0,
        "score_write_after_count": 0,
        "score_write_before_samples": [],
        "score_write_after_samples": [],
        "return_site_captured": False,
        "caller_after_captured": False,
        "native_behavior_changed": False,
        "used_objdump": False,
    }

    active_target = False
    target_generator: int | None = None
    with log_path.open("w", encoding="utf-8") as log:
        child.logfile_read = log
        try:
            child.expect(PROMPT_RE, timeout=args.debugger_timeout)
            issue_capture(child, f"break *{DISPATCH}", args.debugger_timeout)
            child.send("cont\r")
            drive_h3maped_ui(args, args.out_dir / "screenshots")

            while len(summary["events"]) < args.max_events:
                index = child.expect([STOP_RE, pexpect.EOF, pexpect.TIMEOUT], timeout=args.breakpoint_timeout)
                if index == 1:
                    summary["terminated"] = "eof"
                    break
                if index == 2:
                    summary["terminated"] = "timeout"
                    break
                address = normalize_address("0x" + child.match.group(1))
                child.expect(PROMPT_RE, timeout=args.debugger_timeout)
                event: dict[str, Any] = {"address": address}

                if address == DISPATCH:
                    dispatch_index = len(summary["dispatches_seen"])
                    registers = parse_registers(issue_capture(child, "info reg", args.debugger_timeout))
                    stack_lines = parse_hex_words(issue_capture(child, "x/8x $esp", args.debugger_timeout))
                    record_lines = parse_hex_words(
                        issue_capture(child, "x/24x *(int*)$esp", args.debugger_timeout)
                    )
                    generator = registers.get("ecx") or registers.get("ebx")
                    vector_lines = (
                        parse_hex_words(issue_capture(child, "x/16x $ecx+0xec8", args.debugger_timeout))
                        if generator is not None
                        else []
                    )
                    counter_lines = (
                        parse_hex_words(issue_capture(child, "x/128x $ecx+0x1110", args.debugger_timeout))
                        if generator is not None
                        else []
                    )
                    dispatch = {
                        "dispatch_index": dispatch_index,
                        "registers": {key: qhex(value) for key, value in registers.items()},
                        "stack_args": stack_dispatch_from_lines(stack_lines),
                        "record_words_sample": record_lines,
                        "vector_count_before": vector_count(vector_lines),
                        "counter98_before": counter98(counter_lines),
                    }
                    summary["dispatches_seen"].append(dispatch)
                    event["dispatch"] = dispatch
                    if dispatch_index == args.target_dispatch_index:
                        active_target = True
                        target_generator = generator
                        issue_capture(child, f"break *{WRITE_BEFORE}", args.debugger_timeout)
                        issue_capture(child, f"break *{WRITE_AFTER}", args.debugger_timeout)
                        issue_capture(child, f"break *{RETURN_SITE}", args.debugger_timeout)
                        issue_capture(child, f"break *{CALLER_AFTER}", args.debugger_timeout)
                elif active_target and address in {WRITE_BEFORE, WRITE_AFTER}:
                    lines = parse_hex_words(issue_capture(child, "x/12x $eax", args.debugger_timeout))
                    snapshot = cell_snapshot(lines)
                    sample_key = (
                        "score_write_before_samples"
                        if address == WRITE_BEFORE
                        else "score_write_after_samples"
                    )
                    count_key = (
                        "score_write_before_count"
                        if address == WRITE_BEFORE
                        else "score_write_after_count"
                    )
                    summary[count_key] += 1
                    if len(summary[sample_key]) < args.sample_limit:
                        summary[sample_key].append(snapshot)
                    event["cell"] = snapshot
                elif active_target and address == RETURN_SITE:
                    summary["return_site_captured"] = True
                elif active_target and address == CALLER_AFTER:
                    registers = parse_registers(issue_capture(child, "info reg", args.debugger_timeout))
                    generator = target_generator
                    vector_lines = (
                        parse_hex_words(
                            issue_capture(child, f"x/16x 0x{generator:08x}+0xec8", args.debugger_timeout)
                        )
                        if generator is not None
                        else []
                    )
                    counter_lines = (
                        parse_hex_words(
                            issue_capture(child, f"x/128x 0x{generator:08x}+0x1110", args.debugger_timeout)
                        )
                        if generator is not None
                        else []
                    )
                    summary["caller_after_captured"] = True
                    summary["caller_after"] = {
                        "registers": {key: qhex(value) for key, value in registers.items()},
                        "vector_count_after": vector_count(vector_lines),
                        "counter98_after": counter98(counter_lines),
                    }
                    event["caller_after"] = summary["caller_after"]
                    summary["events"].append(event)
                    summary["terminated"] = "target_caller_after"
                    break

                summary["events"].append(event)
                child.send("cont\r")
            else:
                summary["terminated"] = "event_cap"
            child.send("q\r")
            child.expect([pexpect.EOF, PROMPT_RE, pexpect.TIMEOUT], timeout=5)
        finally:
            child.close(force=True)

    summary["event_count"] = len(summary["events"])
    summary["log_path"] = str(log_path)
    dispatch = (
        summary["dispatches_seen"][args.target_dispatch_index]
        if len(summary["dispatches_seen"]) > args.target_dispatch_index
        else None
    )
    summary["target_dispatch"] = dispatch
    if dispatch:
        before_counter = dispatch.get("counter98_before")
        after_counter = summary.get("caller_after", {}).get("counter98_after")
        before_vector = dispatch.get("vector_count_before")
        after_vector = summary.get("caller_after", {}).get("vector_count_after")
        summary["counter98_delta"] = (
            None if before_counter is None or after_counter is None else after_counter - before_counter
        )
        summary["vector_count_delta"] = (
            None if before_vector is None or after_vector is None else after_vector - before_vector
        )
    summary["invariants"] = {
        "target_dispatch_seen": dispatch is not None,
        "return_site_captured": summary["return_site_captured"],
        "caller_after_captured": summary["caller_after_captured"],
        "score_write_before_count_positive": summary["score_write_before_count"] > 0,
        "score_write_before_after_counts_match": summary["score_write_before_count"]
        == summary["score_write_after_count"],
        "vector_count_increments_by_one": summary.get("vector_count_delta") == 1,
        "counter98_increments_by_one": summary.get("counter98_delta") == 1,
    }
    summary["status"] = (
        "weighted_target_dispatch_score_stream_recovered"
        if all(summary["invariants"].values())
        else "weighted_target_dispatch_score_stream_incomplete"
    )
    return summary


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--h3maped-runtime", type=Path, default=DEFAULT_RUNTIME)
    parser.add_argument("--h3maped-exe", type=Path, default=DEFAULT_H3MAPED_EXE)
    parser.add_argument("--resource-dir", type=Path, default=None)
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR)
    parser.add_argument("--target-dispatch-index", type=int, required=True)
    parser.add_argument("--max-events", type=int, default=4096)
    parser.add_argument("--sample-limit", type=int, default=16)
    parser.add_argument("--display-number", type=int, default=161)
    parser.add_argument("--screen-size", default="1024x768x24")
    parser.add_argument("--wineprefix", type=Path, default=Path(".artifacts/wine/h3maped"))
    parser.add_argument("--generate-wait-seconds", type=int, default=2)
    parser.add_argument("--debugger-timeout", type=int, default=300)
    parser.add_argument("--breakpoint-timeout", type=int, default=300)
    parser.add_argument("--map-size", choices=["small", "medium", "large", "xlarge"], default="large")
    parser.add_argument("--human-computer-down", type=int, default=3)
    parser.add_argument("--computer-only-down", type=int, default=1)
    parser.add_argument("--monster-strength-down", type=int, default=-1)
    parser.add_argument("--water-none", action="store_true", default=True)
    parser.add_argument("--seed", default="58")
    parser.add_argument("--seed-control-mode", choices=["none", "pe-patch"], default="pe-patch")
    parser.add_argument("--inside-xvfb", action="store_true")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    repo_root = args.repo_root.resolve()
    args.h3maped_runtime = (
        repo_root / args.h3maped_runtime
        if not args.h3maped_runtime.is_absolute()
        else args.h3maped_runtime
    ).resolve()
    args.h3maped_exe = (
        repo_root / args.h3maped_exe if not args.h3maped_exe.is_absolute() else args.h3maped_exe
    ).resolve()
    args.out_dir = (
        repo_root / args.out_dir if not args.out_dir.is_absolute() else args.out_dir
    ).resolve()
    args.wineprefix = (
        repo_root / args.wineprefix if not args.wineprefix.is_absolute() else args.wineprefix
    ).resolve()
    args.resource_dir = (
        (repo_root / args.resource_dir).resolve()
        if args.resource_dir and not args.resource_dir.is_absolute()
        else args.resource_dir
    )
    args.out_dir.mkdir(parents=True, exist_ok=True)

    if not args.inside_xvfb:
        seed_control = prepare_seed_patched_runtime(args)
        seed_meta_path = args.out_dir / "seed_control.json"
        seed_meta_path.write_text(json.dumps(seed_control, indent=2, sort_keys=True) + "\n")
        command = [
            "xvfb-run",
            "-n",
            str(args.display_number),
            "-s",
            f"-screen 0 {args.screen_size} -ac +extension GLX +render -noreset",
            sys.executable,
            str(Path(__file__).resolve()),
            "--inside-xvfb",
            "--repo-root",
            str(repo_root),
            "--h3maped-runtime",
            str(args.h3maped_runtime),
            "--h3maped-exe",
            str(args.h3maped_exe),
            "--out-dir",
            str(args.out_dir),
            "--wineprefix",
            str(args.wineprefix),
            "--target-dispatch-index",
            str(args.target_dispatch_index),
            "--max-events",
            str(args.max_events),
            "--sample-limit",
            str(args.sample_limit),
            "--display-number",
            str(args.display_number),
            "--screen-size",
            args.screen_size,
            "--generate-wait-seconds",
            str(args.generate_wait_seconds),
            "--debugger-timeout",
            str(args.debugger_timeout),
            "--breakpoint-timeout",
            str(args.breakpoint_timeout),
            "--map-size",
            args.map_size,
            "--human-computer-down",
            str(args.human_computer_down),
            "--computer-only-down",
            str(args.computer_only_down),
            "--monster-strength-down",
            str(args.monster_strength_down),
            "--seed",
            str(args.seed),
            "--seed-control-mode",
            args.seed_control_mode,
        ]
        if args.resource_dir:
            command.extend(["--resource-dir", str(args.resource_dir)])
        if args.water_none:
            command.append("--water-none")
        completed = subprocess.run(command, cwd=repo_root, text=True)
        summary_path = args.out_dir / f"weighted_dispatch{args.target_dispatch_index}_score_stream_summary.json"
        if summary_path.exists():
            summary = json.loads(summary_path.read_text(encoding="utf-8"))
            print(
                "RMG_H3MAPED_WEIGHTED_SCORE_STREAM_TARGET "
                f"status={summary.get('status')} "
                f"dispatch={args.target_dispatch_index} "
                f"writes={summary.get('score_write_before_count')} "
                f"out={summary_path}"
            )
        return completed.returncode

    summary = run_inside_xvfb(args)
    seed_meta = args.out_dir / "seed_control.json"
    if seed_meta.exists():
        summary["seed_control"] = json.loads(seed_meta.read_text(encoding="utf-8"))
    summary["profile"] = {
        "seed": args.seed,
        "map_size": args.map_size,
        "human_computer_down": args.human_computer_down,
        "computer_only_down": args.computer_only_down,
        "water_none": args.water_none,
    }
    out = args.out_dir / f"weighted_dispatch{args.target_dispatch_index}_score_stream_summary.json"
    out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_WEIGHTED_SCORE_STREAM_TARGET "
        f"status={summary['status']} "
        f"dispatch={args.target_dispatch_index} "
        f"writes={summary['score_write_before_count']} "
        f"out={out}"
    )
    return 0 if summary["status"] == "weighted_target_dispatch_score_stream_recovered" else 1


if __name__ == "__main__":
    raise SystemExit(main())
