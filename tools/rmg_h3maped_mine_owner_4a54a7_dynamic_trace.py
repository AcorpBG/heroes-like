#!/usr/bin/env python3
"""Trace mine-owner selected callbacks through ``0x4a54a7``.

This is a focused WineDbg recovery probe for the remaining non-fallback
``0x4a54a7`` owner loops named by the Ghidra owner summary:

* ``0x4a9641 -> 0x4a98f0``
* ``0x4a9911 -> 0x4a9c3f``

It intentionally uses only Wine/Ghidra/Python recovery evidence and does not
change native RMG behavior.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any

import pexpect

from rmg_h3maped_4aa3e9_4a54a7_dynamic_trace import (
    COMMIT_4A54A7,
    COMMIT_RETURN,
    DEFAULT_RUNTIME,
    PROJECTION_WRITE,
    dump_cell_and_refs,
    generated_cell_pointer,
    issue_capture,
    memory_word,
    parse_memory_words,
    parse_registers,
    qhex,
    stack_word,
)
from rmg_h3maped_recovery_interactive_trace import PROMPT_RE, STOP_RE, drive_h3maped_ui, normalize_address
from rmg_h3maped_recovery_trace import parse_winedbg_log


DEFAULT_OUT_DIR = Path(".artifacts/rmg_recovery/mine_owner_4a54a7_dynamic_trace_20260610")

OWNER_PROFILES: dict[str, dict[str, str]] = {
    "4a9641": {
        "owner_entry": "0x004a9641",
        "callsite": "0x004a98ed",
        "after_callback": "0x004a98f0",
        "owner_exit": "0x004a9910",
        "owner_name": "mine_coordinate_object_builder_followup",
    },
    "4a9911": {
        "owner_entry": "0x004a9911",
        "callsite": "0x004a9c3c",
        "after_callback": "0x004a9c3f",
        "owner_exit": "0x004a9c7b",
        "owner_name": "mine_requirement_coordinate_object_loop",
    },
}


def owner_profile(owner: str) -> dict[str, str]:
    try:
        return OWNER_PROFILES[owner.lower()]
    except KeyError as exc:
        choices = ", ".join(sorted(OWNER_PROFILES))
        raise SystemExit(f"unknown owner {owner!r}; expected one of: {choices}") from exc


def run_xvfb(args: argparse.Namespace, repo_root: Path, log_path: Path) -> dict[str, Any]:
    profile = owner_profile(args.owner)
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

    armed_breakpoints = [
        profile["callsite"],
        COMMIT_4A54A7,
        COMMIT_RETURN,
        profile["after_callback"],
        profile["owner_exit"],
    ]
    child = pexpect.spawn(
        "winedbg",
        ["./h3maped.exe"],
        cwd=str(args.h3maped_runtime),
        env=env,
        encoding="utf-8",
        timeout=args.debugger_timeout,
    )
    metadata: dict[str, Any] = {
        "owner": args.owner.lower(),
        "owner_name": profile["owner_name"],
        "owner_entry": profile["owner_entry"],
        "callsite": profile["callsite"],
        "after_callback": profile["after_callback"],
        "owner_exit": profile["owner_exit"],
        "armed_breakpoints": armed_breakpoints,
        "entry_hits": 0,
        "skipped_entry_hits": [],
        "armed_after_event": None,
        "target_commit_return": profile["after_callback"],
        "target_cell": None,
        "target_coordinate": None,
        "object_record": None,
        "callsite_stack0": None,
        "non_target_commit_returns": [],
        "projection_breakpoint_armed_after_event": None,
        "event_count": 0,
    }
    armed = False
    capture_commit_active = False
    projection_breakpoint_armed = False
    target_cell: int | None = None

    with log_path.open("w", encoding="utf-8") as log:
        child.logfile_read = log
        try:
            child.expect(PROMPT_RE, timeout=args.debugger_timeout)
            issue_capture(child, f"break *{profile['owner_entry']}", args.debugger_timeout)
            child.send("cont\r")
            drive_h3maped_ui(args, args.out_dir / "screenshots")

            while metadata["event_count"] < args.max_events:
                index = child.expect([STOP_RE, pexpect.EOF, pexpect.TIMEOUT], timeout=args.debugger_timeout)
                if index != 0:
                    break
                address = normalize_address("0x" + child.match.group(1))
                metadata["event_count"] += 1
                child.expect(PROMPT_RE, timeout=args.debugger_timeout)

                info = issue_capture(child, "info reg", args.debugger_timeout)
                stack = issue_capture(child, "x/20x $esp", args.debugger_timeout)
                registers = parse_registers(info)
                stack_memory = parse_memory_words(stack)
                esp = registers.get("esp")

                if address == profile["owner_entry"] and not armed:
                    entry_index = int(metadata["entry_hits"])
                    metadata["entry_hits"] = entry_index + 1
                    issue_capture(child, "x/20x $ebp-0x80", args.debugger_timeout)
                    if entry_index < args.skip_entry_hits:
                        metadata["skipped_entry_hits"].append(
                            {"entry_index": entry_index, "event_index": metadata["event_count"]}
                        )
                        child.send("cont\r")
                        continue
                    for breakpoint in armed_breakpoints:
                        issue_capture(child, f"break *{breakpoint}", args.debugger_timeout)
                    metadata["armed_after_event"] = metadata["event_count"]
                    metadata["armed_entry_index"] = entry_index
                    armed = True

                elif armed and address == profile["callsite"]:
                    member = stack_word(stack_memory, esp, 0)
                    metadata["callsite_stack0"] = qhex(member)
                    issue_capture(child, "x/20x $ebp-0x80", args.debugger_timeout)
                    if member:
                        issue_capture(child, f"x/16x {qhex(member)}", args.debugger_timeout)

                elif armed and address == COMMIT_4A54A7:
                    return_address = stack_word(stack_memory, esp, 0)
                    return_text = qhex(return_address)
                    if args.require_target_return and return_text != profile["after_callback"]:
                        metadata["non_target_commit_returns"].append(
                            {"event_index": metadata["event_count"], "return_address": return_text}
                        )
                        capture_commit_active = False
                        target_cell = None
                        child.send("cont\r")
                        continue
                    capture_commit_active = True
                    if not projection_breakpoint_armed:
                        issue_capture(child, f"break *{PROJECTION_WRITE}", args.debugger_timeout)
                        metadata["projection_breakpoint_armed_after_event"] = metadata["event_count"]
                        projection_breakpoint_armed = True
                    object_record = stack_word(stack_memory, esp, 4)
                    x = stack_word(stack_memory, esp, 8)
                    y = stack_word(stack_memory, esp, 12)
                    level = stack_word(stack_memory, esp, 16)
                    metadata["object_record"] = qhex(object_record)
                    metadata["commit_return_address"] = qhex(return_address)
                    metadata["target_coordinate"] = {"x": x, "y": y, "level": level}
                    generator = registers.get("ecx")
                    generator_dump = issue_capture(child, "x/16x $ecx", args.debugger_timeout)
                    issue_capture(child, "x/16x $ecx+0xec4", args.debugger_timeout)
                    generator_memory = parse_memory_words(generator_dump)
                    if (
                        generator is not None
                        and x is not None
                        and y is not None
                        and level is not None
                    ):
                        target_cell = generated_cell_pointer(
                            generator_memory,
                            int(generator),
                            int(x),
                            int(y),
                            int(level),
                        )
                        metadata["target_cell"] = qhex(target_cell)
                    if object_record:
                        issue_capture(child, f"x/16x {qhex(object_record)}", args.debugger_timeout)
                    dump_cell_and_refs(child, target_cell, args.debugger_timeout)

                elif armed and address == PROJECTION_WRITE and capture_commit_active:
                    issue_capture(child, "x/16x $eax", args.debugger_timeout)

                elif armed and address in {COMMIT_RETURN, profile["after_callback"], profile["owner_exit"]}:
                    if address == COMMIT_RETURN and not capture_commit_active:
                        child.send("cont\r")
                        continue
                    issue_capture(child, "x/20x $ebp-0x80", args.debugger_timeout)
                    issue_capture(child, "x/16x $ebx+0xeb8", args.debugger_timeout)
                    issue_capture(child, "x/16x $ebx+0xec4", args.debugger_timeout)
                    issue_capture(child, "x/16x $ecx+0xec4", args.debugger_timeout)
                    dump_cell_and_refs(child, target_cell, args.debugger_timeout)
                    if (
                        address == profile["after_callback"]
                        and args.stop_after_callback
                        and (capture_commit_active or not args.require_target_return)
                    ):
                        break
                    if address == profile["owner_exit"]:
                        break

                child.send("cont\r")

            child.send("q\r")
            child.expect([pexpect.EOF, PROMPT_RE], timeout=5)
        finally:
            child.close(force=True)
    return metadata


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--h3maped-runtime", type=Path, default=DEFAULT_RUNTIME)
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR)
    parser.add_argument("--owner", choices=sorted(OWNER_PROFILES), default="4a9641")
    parser.add_argument("--display-number", type=int, default=165)
    parser.add_argument("--screen-size", default="1024x768x24")
    parser.add_argument("--wineprefix", type=Path, default=Path(".artifacts/wine/h3maped"))
    parser.add_argument("--generate-wait-seconds", type=int, default=8)
    parser.add_argument("--debugger-timeout", type=int, default=180)
    parser.add_argument("--max-events", type=int, default=1800)
    parser.add_argument("--skip-entry-hits", type=int, default=0)
    parser.add_argument("--stop-after-callback", action="store_true", default=True)
    parser.add_argument(
        "--require-target-return",
        action="store_true",
        default=True,
        help="Only capture 0x4a54a7 write state when its stack return matches the owner after-callback.",
    )
    parser.add_argument("--map-size", choices=["small", "medium", "large", "xlarge"], default="medium")
    parser.add_argument("--human-computer-down", type=int, default=-1)
    parser.add_argument("--computer-only-down", type=int, default=-1)
    parser.add_argument("--monster-strength-down", type=int, default=-1)
    parser.add_argument("--water-none", action="store_true", default=True)
    parser.add_argument("--inside-xvfb", action="store_true")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    repo_root = args.repo_root.resolve()
    args.h3maped_runtime = (
        (repo_root / args.h3maped_runtime).resolve()
        if not args.h3maped_runtime.is_absolute()
        else args.h3maped_runtime.resolve()
    )
    args.out_dir = (
        (repo_root / args.out_dir).resolve()
        if not args.out_dir.is_absolute()
        else args.out_dir.resolve()
    )
    args.out_dir = args.out_dir / args.owner.lower()
    args.wineprefix = (
        (repo_root / args.wineprefix).resolve()
        if not args.wineprefix.is_absolute()
        else args.wineprefix.resolve()
    )
    args.out_dir.mkdir(parents=True, exist_ok=True)
    log_path = args.out_dir / f"winedbg_{args.owner.lower()}_4a54a7_dynamic_trace.log"
    meta_path = args.out_dir / "dynamic_trace_meta.json"
    ledger_path = args.out_dir / f"winedbg_{args.owner.lower()}_4a54a7_dynamic_trace_ledger.json"

    if not args.inside_xvfb:
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
            "--out-dir",
            str(args.out_dir.parent),
            "--owner",
            args.owner,
            "--wineprefix",
            str(args.wineprefix),
            "--display-number",
            str(args.display_number),
            "--screen-size",
            args.screen_size,
            "--generate-wait-seconds",
            str(args.generate_wait_seconds),
            "--debugger-timeout",
            str(args.debugger_timeout),
            "--max-events",
            str(args.max_events),
            "--skip-entry-hits",
            str(args.skip_entry_hits),
            "--map-size",
            args.map_size,
            "--human-computer-down",
            str(args.human_computer_down),
            "--computer-only-down",
            str(args.computer_only_down),
            "--monster-strength-down",
            str(args.monster_strength_down),
        ]
        if args.water_none:
            command.append("--water-none")
        if args.stop_after_callback:
            command.append("--stop-after-callback")
        if args.require_target_return:
            command.append("--require-target-return")
        completed = subprocess.run(command, cwd=repo_root, text=True)
        if completed.returncode != 0:
            return completed.returncode
    else:
        metadata = run_xvfb(args, repo_root, log_path)
        meta_path.write_text(json.dumps(metadata, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        return 0 if metadata["event_count"] else 1

    ledger = parse_winedbg_log(log_path)
    metadata = json.loads(meta_path.read_text(encoding="utf-8")) if meta_path.exists() else {}
    ledger["dynamic_trace_meta"] = metadata
    ledger_path.write_text(json.dumps(ledger, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    status = "pass" if ledger.get("event_count") else "no_events"
    print(
        "RMG_H3MAPED_MINE_OWNER_4A54A7_DYNAMIC_TRACE "
        f"status={status} owner={args.owner.lower()} events={ledger.get('event_count')} "
        f"commit_return={metadata.get('commit_return_address')} "
        f"target_cell={metadata.get('target_cell')} "
        f"object_record={metadata.get('object_record')} "
        f"ledger={ledger_path}"
    )
    return 0 if ledger.get("event_count") else 1


if __name__ == "__main__":
    raise SystemExit(main())
