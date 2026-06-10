#!/usr/bin/env python3
"""Trace one ``0x4a54a7`` commit selected by stack return address.

This WineDbg probe is intentionally return-site driven instead of owner-entry
driven. It exists for owner loops where the natural owner entry can take nested
or branch-only paths before the desired callback. The probe breaks on
``0x4a54a7``, ignores commits whose stack return does not match
``--target-return``, and arms the expensive ``0x4a56b6`` projection-write
breakpoint only after the target return is found.

No native RMG behavior is changed; this is recovery evidence only.
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
    parse_memory_words,
    parse_registers,
    qhex,
    stack_word,
)
from rmg_h3maped_recovery_interactive_trace import PROMPT_RE, STOP_RE, drive_h3maped_ui, normalize_address
from rmg_h3maped_recovery_trace import parse_winedbg_log


DEFAULT_OUT_DIR = Path(".artifacts/rmg_recovery/4a54a7_target_return_dynamic_trace_20260610")


def run_xvfb(args: argparse.Namespace, repo_root: Path, log_path: Path) -> dict[str, Any]:
    target_return = f"0x{int(args.target_return, 0) & 0xFFFFFFFF:08x}"
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
    metadata: dict[str, Any] = {
        "target_return": target_return,
        "initial_breakpoint": COMMIT_4A54A7,
        "target_commit_event": None,
        "target_cell": None,
        "target_coordinate": None,
        "object_record": None,
        "non_target_commit_returns": [],
        "projection_breakpoint_armed_after_event": None,
        "commit_return_breakpoint_armed_after_event": None,
        "event_count": 0,
    }
    target_cell: int | None = None
    target_active = False
    projection_armed = False
    return_armed = False

    with log_path.open("w", encoding="utf-8") as log:
        child.logfile_read = log
        try:
            child.expect(PROMPT_RE, timeout=args.debugger_timeout)
            issue_capture(child, f"break *{COMMIT_4A54A7}", args.debugger_timeout)
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

                if address == COMMIT_4A54A7:
                    return_address = qhex(stack_word(stack_memory, esp, 0))
                    if return_address != target_return:
                        if len(metadata["non_target_commit_returns"]) < args.max_non_target_records:
                            metadata["non_target_commit_returns"].append(
                                {"event_index": metadata["event_count"], "return_address": return_address}
                            )
                        child.send("cont\r")
                        continue

                    target_active = True
                    metadata["target_commit_event"] = metadata["event_count"]
                    object_record = stack_word(stack_memory, esp, 4)
                    x = stack_word(stack_memory, esp, 8)
                    y = stack_word(stack_memory, esp, 12)
                    level = stack_word(stack_memory, esp, 16)
                    metadata["object_record"] = qhex(object_record)
                    metadata["commit_return_address"] = return_address
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

                    if not projection_armed:
                        issue_capture(child, f"break *{PROJECTION_WRITE}", args.debugger_timeout)
                        metadata["projection_breakpoint_armed_after_event"] = metadata["event_count"]
                        projection_armed = True
                    if not return_armed:
                        issue_capture(child, f"break *{COMMIT_RETURN}", args.debugger_timeout)
                        issue_capture(child, f"break *{target_return}", args.debugger_timeout)
                        metadata["commit_return_breakpoint_armed_after_event"] = metadata["event_count"]
                        return_armed = True

                elif address == PROJECTION_WRITE and target_active:
                    issue_capture(child, "x/16x $eax", args.debugger_timeout)

                elif target_active and address in {COMMIT_RETURN, target_return}:
                    issue_capture(child, "x/16x $ebx+0xeb8", args.debugger_timeout)
                    issue_capture(child, "x/16x $ebx+0xec4", args.debugger_timeout)
                    issue_capture(child, "x/16x $ecx+0xec4", args.debugger_timeout)
                    dump_cell_and_refs(child, target_cell, args.debugger_timeout)
                    if address == target_return and args.stop_after_target_return:
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
    parser.add_argument("--target-return", default="0x004a9c3f")
    parser.add_argument("--display-number", type=int, default=170)
    parser.add_argument("--screen-size", default="1024x768x24")
    parser.add_argument("--wineprefix", type=Path, default=Path(".artifacts/wine/h3maped"))
    parser.add_argument("--generate-wait-seconds", type=int, default=8)
    parser.add_argument("--debugger-timeout", type=int, default=180)
    parser.add_argument("--max-events", type=int, default=2000)
    parser.add_argument("--max-non-target-records", type=int, default=40)
    parser.add_argument("--stop-after-target-return", action="store_true", default=True)
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
    target_name = f"{int(args.target_return, 0) & 0xFFFFFFFF:08x}"
    args.out_dir = args.out_dir / target_name
    args.wineprefix = (
        (repo_root / args.wineprefix).resolve()
        if not args.wineprefix.is_absolute()
        else args.wineprefix.resolve()
    )
    args.out_dir.mkdir(parents=True, exist_ok=True)
    log_path = args.out_dir / f"winedbg_4a54a7_to_{target_name}_dynamic_trace.log"
    meta_path = args.out_dir / "dynamic_trace_meta.json"
    ledger_path = args.out_dir / f"winedbg_4a54a7_to_{target_name}_dynamic_trace_ledger.json"

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
            "--target-return",
            args.target_return,
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
            "--max-non-target-records",
            str(args.max_non_target_records),
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
        if args.stop_after_target_return:
            command.append("--stop-after-target-return")
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
        "RMG_H3MAPED_4A54A7_TARGET_RETURN_DYNAMIC_TRACE "
        f"status={status} target_return={metadata.get('target_return')} "
        f"events={ledger.get('event_count')} target_event={metadata.get('target_commit_event')} "
        f"target_cell={metadata.get('target_cell')} object_record={metadata.get('object_record')} "
        f"ledger={ledger_path}"
    )
    return 0 if ledger.get("event_count") and metadata.get("target_commit_event") else 1


if __name__ == "__main__":
    raise SystemExit(main())
