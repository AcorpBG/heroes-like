#!/usr/bin/env python3
"""Dynamically trace a 0x4a61bc-origin 0x4a54a7 write stream.

The heavy 0x4a56b6 generated-cell write breakpoint is armed only after the
0x4a61bc caller reaches the 0x4a6578 -> 0x4a5e03 materialization boundary.
This avoids collecting unrelated earlier 0x4a54a7 projection writes.
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


DEFAULT_OUT_DIR = Path(".artifacts/rmg_recovery/4a61bc_4a54a7_dynamic_write_trace_20260609")
INITIAL_BREAKPOINT = "0x004a6578"
ARMED_BREAKPOINTS = [
    "0x004a5e03",
    "0x004a5e55",
    "0x004a5e69",
    "0x004a54a7",
    "0x004a558a",
    "0x004a56b6",
    "0x004a5756",
    "0x004a5e6c",
    "0x004a657d",
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


def dump_cell_and_refs(child: pexpect.spawn, cell: int, timeout: int) -> None:
    cell_text = qhex(cell)
    if not cell_text:
        return
    cell_dump = issue_capture(child, f"x/16x {cell_text}", timeout)
    memory = parse_memory_words(cell_dump)
    begin = memory_word(memory, cell + 0x04)
    end = memory_word(memory, cell + 0x08)
    if begin and end and begin <= end and end - begin <= 0x40:
        issue_capture(child, f"x/16x {qhex(begin)}", timeout)


def run_xvfb(args: argparse.Namespace, repo_root: Path, log_path: Path) -> dict[str, Any]:
    runtime = args.h3maped_runtime
    env = os.environ.copy()
    env["WINEPREFIX"] = str(args.wineprefix)
    env["WINEARCH"] = "win32"
    subprocess.run(["wineboot", "-u"], cwd=runtime, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)

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
        "target_cell": None,
        "target_coordinate": None,
        "object_record": None,
        "armed_after_event": None,
        "skip_caller_boundaries": args.skip_caller_boundaries,
        "caller_boundary_hits": 0,
        "skipped_caller_boundaries": [],
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
                stack = issue_capture(child, "x/12x $esp", args.debugger_timeout)
                registers = parse_registers(info)
                stack_memory = parse_memory_words(stack)
                esp = registers.get("esp")

                if address == INITIAL_BREAKPOINT and not armed:
                    boundary_index = int(metadata["caller_boundary_hits"])
                    metadata["caller_boundary_hits"] = boundary_index + 1
                    issue_capture(child, "x/16x $ebx+0xec4", args.debugger_timeout)
                    if boundary_index < args.skip_caller_boundaries:
                        metadata["skipped_caller_boundaries"].append(
                            {
                                "boundary_index": boundary_index,
                                "event_index": metadata["event_count"],
                            }
                        )
                        child.send("cont\r")
                        continue
                    for breakpoint in ARMED_BREAKPOINTS:
                        issue_capture(child, f"break *{breakpoint}", args.debugger_timeout)
                    metadata["armed_after_event"] = metadata["event_count"]
                    metadata["armed_caller_boundary_index"] = boundary_index
                    armed = True

                elif address == "0x004a5e03":
                    generator = registers.get("ecx")
                    generator_dump = issue_capture(child, "x/16x $ecx+0xec4", args.debugger_timeout)
                    issue_capture(child, "x/12x $ecx", args.debugger_timeout)
                    generator_memory = parse_memory_words(issue_capture(child, "x/12x $ecx", args.debugger_timeout))
                    if generator is not None and esp is not None:
                        x = memory_word(stack_memory, esp + 8)
                        y = memory_word(stack_memory, esp + 12)
                        level = memory_word(stack_memory, esp + 16)
                        if None not in {x, y, level}:
                            target_cell = generated_cell_pointer(generator_memory, generator, int(x), int(y), int(level))
                            metadata["target_cell"] = qhex(target_cell)
                            metadata["target_coordinate"] = {"x": x, "y": y, "level": level}
                    if target_cell is not None:
                        dump_cell_and_refs(child, target_cell, args.debugger_timeout)

                elif address == "0x004a5e55":
                    object_record = registers.get("eax")
                    metadata["object_record"] = qhex(object_record)
                    if object_record:
                        issue_capture(child, "x/16x $eax", args.debugger_timeout)

                elif address in {"0x004a5e69", "0x004a54a7"}:
                    issue_capture(child, "x/16x $ecx+0xec4", args.debugger_timeout)

                elif address == "0x004a558a":
                    issue_capture(child, "x/16x $eax", args.debugger_timeout)

                elif address == "0x004a56b6":
                    issue_capture(child, "x/12x $eax", args.debugger_timeout)

                elif address in {"0x004a5756", "0x004a5e6c", "0x004a657d"}:
                    # Inside 0x4a54a7 EBX is generator+0x0c; outside it EBX is
                    # the generator. Dump both candidate vector headers where
                    # useful and let the parser keep the valid one.
                    issue_capture(child, "x/16x $ebx+0xec4", args.debugger_timeout)
                    issue_capture(child, "x/16x $ebx+0xeb8", args.debugger_timeout)
                    if target_cell is not None:
                        dump_cell_and_refs(child, target_cell, args.debugger_timeout)

                if address == "0x004a657d" and armed:
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
    parser.add_argument("--display-number", type=int, default=135)
    parser.add_argument("--screen-size", default="1024x768x24")
    parser.add_argument("--wineprefix", type=Path, default=Path(".artifacts/wine/h3maped"))
    parser.add_argument("--generate-wait-seconds", type=int, default=2)
    parser.add_argument("--debugger-timeout", type=int, default=180)
    parser.add_argument("--max-events", type=int, default=1200)
    parser.add_argument(
        "--skip-caller-boundaries",
        type=int,
        default=0,
        help="Skip this many 0x4a6578 caller-frame hits before arming detailed breakpoints.",
    )
    parser.add_argument("--map-size", choices=["small", "medium", "large", "xlarge"], default="small")
    parser.add_argument("--human-computer-down", type=int, default=-1)
    parser.add_argument("--computer-only-down", type=int, default=-1)
    parser.add_argument("--monster-strength-down", type=int, default=-1)
    parser.add_argument("--water-none", action="store_true", default=False)
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
    log_path = args.out_dir / "winedbg_4a61bc_4a54a7_dynamic_trace.log"
    meta_path = args.out_dir / "dynamic_trace_meta.json"
    ledger_path = args.out_dir / "winedbg_4a61bc_4a54a7_dynamic_trace_ledger.json"

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
            "--skip-caller-boundaries",
            str(args.skip_caller_boundaries),
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
        "RMG_H3MAPED_4A61BC_4A54A7_DYNAMIC_TRACE "
        f"status={status} events={ledger.get('event_count')} "
        f"target_cell={metadata.get('target_cell')} "
        f"object_record={metadata.get('object_record')} "
        f"ledger={ledger_path}"
    )
    return 0 if ledger.get("event_count") else 1


if __name__ == "__main__":
    raise SystemExit(main())
