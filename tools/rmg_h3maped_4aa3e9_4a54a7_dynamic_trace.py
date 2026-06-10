#!/usr/bin/env python3
"""Trace 0x4aa3e9 selected-member callbacks through 0x4a54a7.

This is a WineDbg recovery probe for the largest unresolved non-fallback
0x4a54a7 return site: 0x4aa44d, owned by 0x4aa3e9. It intentionally avoids
static disassembly tools; the output is a live debugger ledger.
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

from rmg_h3maped_recovery_interactive_trace import (
    DEFAULT_RUNTIME,
    PROMPT_RE,
    STOP_RE,
    drive_h3maped_ui,
    normalize_address,
)
from rmg_h3maped_recovery_trace import ANSI_RE, DWORD_LINE_RE, REGISTER_RE, parse_winedbg_log


DEFAULT_OUT_DIR = Path(".artifacts/rmg_recovery/4aa3e9_4a54a7_dynamic_trace_20260610")

ENTRY_4AA3E9 = "0x004aa3e9"
SLOT4_CALLSITE = "0x004aa44a"
COMMIT_4A54A7 = "0x004a54a7"
PROJECTION_WRITE = "0x004a56b6"
COMMIT_RETURN = "0x004a5756"
AFTER_SLOT4 = "0x004aa44d"
EXIT_4AA3E9 = "0x004aa5fc"

INITIAL_BREAKPOINT = ENTRY_4AA3E9
ARMED_BREAKPOINTS = [
    SLOT4_CALLSITE,
    COMMIT_4A54A7,
    PROJECTION_WRITE,
    COMMIT_RETURN,
    AFTER_SLOT4,
    EXIT_4AA3E9,
]

HEX_WORD_RE = re.compile(r"\b[0-9a-fA-F]{1,8}\b")


def qhex(value: int | None) -> str | None:
    return None if value is None else f"0x{value & 0xFFFFFFFF:08x}"


def parse_registers(text: str) -> dict[str, int]:
    clean = ANSI_RE.sub("", text).replace("\r", "")
    return {reg.lower(): int(value, 16) for reg, value in REGISTER_RE.findall(clean)}


def parse_memory_words(text: str) -> dict[int, list[int]]:
    clean = ANSI_RE.sub("", text).replace("\r", "")
    lines: dict[int, list[int]] = {}
    for line in clean.splitlines():
        match = DWORD_LINE_RE.search(line)
        if not match:
            continue
        words = [int(token, 16) & 0xFFFFFFFF for token in HEX_WORD_RE.findall(match.group(2))]
        if words:
            lines[int(match.group(1), 16)] = words
    return lines


def memory_word(memory: dict[int, list[int]], address: int) -> int | None:
    for base, words in memory.items():
        if base <= address < base + len(words) * 4 and (address - base) % 4 == 0:
            return words[(address - base) // 4]
    return None


def issue_capture(child: pexpect.spawn, command: str, timeout: int) -> str:
    child.send(command + "\r")
    child.expect(PROMPT_RE, timeout=timeout)
    return child.before or ""


def generated_cell_pointer(
    generator_memory: dict[int, list[int]],
    generator: int,
    x: int,
    y: int,
    level: int,
) -> int | None:
    base = memory_word(generator_memory, generator + 0x14)
    width = memory_word(generator_memory, generator + 0x18)
    height = memory_word(generator_memory, generator + 0x1C)
    if None in {base, width, height}:
        return None
    return int(base) + ((level * int(width) * int(height)) + (y * int(width)) + x) * 0x30


def dump_cell_and_refs(child: pexpect.spawn, cell: int | None, timeout: int) -> None:
    if cell is None:
        return
    cell_dump = issue_capture(child, f"x/16x {qhex(cell)}", timeout)
    memory = parse_memory_words(cell_dump)
    begin = memory_word(memory, cell + 0x04)
    end = memory_word(memory, cell + 0x08)
    if begin and end and begin <= end and end - begin <= 0x80:
        issue_capture(child, f"x/32x {qhex(begin)}", timeout)


def stack_word(stack_memory: dict[int, list[int]], esp: int | None, offset: int) -> int | None:
    if esp is None:
        return None
    return memory_word(stack_memory, esp + offset)


def run_xvfb(args: argparse.Namespace, repo_root: Path, log_path: Path) -> dict[str, Any]:
    runtime = args.h3maped_runtime
    env = os.environ.copy()
    env["WINEPREFIX"] = str(args.wineprefix)
    env["WINEARCH"] = "win32"
    subprocess.run(
        ["wineboot", "-u"],
        cwd=runtime,
        env=env,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )

    child = pexpect.spawn(
        "winedbg",
        ["./h3maped.exe"],
        cwd=str(runtime),
        env=env,
        encoding="utf-8",
        timeout=args.debugger_timeout,
    )
    metadata: dict[str, Any] = {
        "initial_breakpoint": INITIAL_BREAKPOINT,
        "armed_breakpoints": ARMED_BREAKPOINTS,
        "entry_hits": 0,
        "skipped_entry_hits": [],
        "armed_after_event": None,
        "target_commit_return": AFTER_SLOT4,
        "target_cell": None,
        "target_coordinate": None,
        "object_record": None,
        "slot4_member": None,
        "event_count": 0,
    }
    armed = False
    target_cell: int | None = None

    with log_path.open("w", encoding="utf-8") as log:
        child.logfile_read = log
        try:
            child.expect(PROMPT_RE, timeout=args.debugger_timeout)
            issue_capture(child, f"break *{INITIAL_BREAKPOINT}", args.debugger_timeout)
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
                stack = issue_capture(child, "x/16x $esp", args.debugger_timeout)
                registers = parse_registers(info)
                stack_memory = parse_memory_words(stack)
                esp = registers.get("esp")

                if address == INITIAL_BREAKPOINT and not armed:
                    entry_index = int(metadata["entry_hits"])
                    metadata["entry_hits"] = entry_index + 1
                    if entry_index < args.skip_entry_hits:
                        metadata["skipped_entry_hits"].append(
                            {"entry_index": entry_index, "event_index": metadata["event_count"]}
                        )
                        child.send("cont\r")
                        continue
                    for breakpoint in ARMED_BREAKPOINTS:
                        issue_capture(child, f"break *{breakpoint}", args.debugger_timeout)
                    metadata["armed_after_event"] = metadata["event_count"]
                    metadata["armed_entry_index"] = entry_index
                    armed = True
                    issue_capture(child, "x/24x $esp", args.debugger_timeout)

                elif armed and address == SLOT4_CALLSITE:
                    member = stack_word(stack_memory, esp, 0)
                    metadata["slot4_member"] = qhex(member)
                    if member:
                        issue_capture(child, f"x/16x {qhex(member)}", args.debugger_timeout)

                elif armed and address == COMMIT_4A54A7:
                    return_address = stack_word(stack_memory, esp, 0)
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

                elif armed and address == PROJECTION_WRITE:
                    issue_capture(child, "x/16x $eax", args.debugger_timeout)

                elif armed and address in {COMMIT_RETURN, AFTER_SLOT4, EXIT_4AA3E9}:
                    issue_capture(child, "x/16x $ebx+0xeb8", args.debugger_timeout)
                    issue_capture(child, "x/16x $ebx+0xec4", args.debugger_timeout)
                    issue_capture(child, "x/16x $ecx+0xec4", args.debugger_timeout)
                    dump_cell_and_refs(child, target_cell, args.debugger_timeout)
                    if address == AFTER_SLOT4 and args.stop_after_commit:
                        break
                    if address == EXIT_4AA3E9:
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
    parser.add_argument("--display-number", type=int, default=164)
    parser.add_argument("--screen-size", default="1024x768x24")
    parser.add_argument("--wineprefix", type=Path, default=Path(".artifacts/wine/h3maped"))
    parser.add_argument("--generate-wait-seconds", type=int, default=8)
    parser.add_argument("--debugger-timeout", type=int, default=180)
    parser.add_argument("--max-events", type=int, default=1800)
    parser.add_argument("--skip-entry-hits", type=int, default=0)
    parser.add_argument("--stop-after-commit", action="store_true", default=False)
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
    args.wineprefix = (
        (repo_root / args.wineprefix).resolve()
        if not args.wineprefix.is_absolute()
        else args.wineprefix.resolve()
    )
    args.out_dir.mkdir(parents=True, exist_ok=True)
    log_path = args.out_dir / "winedbg_4aa3e9_4a54a7_dynamic_trace.log"
    meta_path = args.out_dir / "dynamic_trace_meta.json"
    ledger_path = args.out_dir / "winedbg_4aa3e9_4a54a7_dynamic_trace_ledger.json"

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
            str(args.out_dir),
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
        if args.stop_after_commit:
            command.append("--stop-after-commit")
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
        "RMG_H3MAPED_4AA3E9_4A54A7_DYNAMIC_TRACE "
        f"status={status} events={ledger.get('event_count')} "
        f"commit_return={metadata.get('commit_return_address')} "
        f"target_cell={metadata.get('target_cell')} "
        f"object_record={metadata.get('object_record')} "
        f"ledger={ledger_path}"
    )
    return 0 if ledger.get("event_count") else 1


if __name__ == "__main__":
    raise SystemExit(main())
