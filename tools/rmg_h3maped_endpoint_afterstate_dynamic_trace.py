#!/usr/bin/env python3
"""Trace direct endpoint commits and dynamically dump selected target cells.

The direct ``0x4a7605 -> 0x4a7312 -> 0x4a54a7`` path selects endpoint
coordinates at runtime. This driver captures those coordinates at ``0x4a7447``
and dumps the matching generated cells later in the same process, avoiding
stale absolute cell addresses from previous runs.
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


DEFAULT_OUT_DIR = Path(".artifacts/rmg_recovery/direct_endpoint_afterstate_dynamic_trace_20260608")
TRACE_BREAKPOINTS = [
    "0x4a696b",
    "0x4a7605",
    "0x4a7312",
    "0x4a7447",
    "0x4a54a7",
    "0x4a54ef",
    "0x4a5756",
    "0x4a744c",
    "0x4a7e21",
    "0x4a7e25",
]
HEX_WORD_RE = re.compile(r"\b[0-9a-fA-F]{1,8}\b")


def qhex(value: int | None) -> str | None:
    return None if value is None else f"0x{value & 0xFFFFFFFF:08x}"


def parse_registers(text: str) -> dict[str, int]:
    text = ANSI_RE.sub("", text).replace("\r", "")
    return {reg.lower(): int(value, 16) for reg, value in REGISTER_RE.findall(text)}


def parse_memory_words(text: str) -> dict[int, list[int]]:
    text = ANSI_RE.sub("", text).replace("\r", "")
    lines: dict[int, list[int]] = {}
    for line in text.splitlines():
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


def generated_cell_pointer(generator_words: dict[int, list[int]], generator: int, x: int, y: int, level: int) -> int | None:
    base = memory_word(generator_words, generator + 0x14)
    width = memory_word(generator_words, generator + 0x18)
    height = memory_word(generator_words, generator + 0x1C)
    if base is None or width is None or height is None:
        return None
    return base + ((level * width * height) + (y * width) + x) * 0x30


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
    captured_cells: list[dict[str, Any]] = []
    events = 0
    with log_path.open("w", encoding="utf-8") as log:
        child.logfile_read = log
        try:
            child.expect(PROMPT_RE, timeout=args.debugger_timeout)
            for address in TRACE_BREAKPOINTS:
                issue_capture(child, f"break *{address}", args.debugger_timeout)
            child.send("cont\r")
            drive_h3maped_ui(args, args.out_dir / "screenshots")

            while events < args.max_events:
                index = child.expect([STOP_RE, pexpect.EOF, pexpect.TIMEOUT], timeout=args.debugger_timeout)
                if index == 1:
                    break
                if index == 2:
                    break
                address = normalize_address("0x" + child.match.group(1))
                events += 1
                child.expect(PROMPT_RE, timeout=args.debugger_timeout)

                info = issue_capture(child, "info reg", args.debugger_timeout)
                stack = issue_capture(child, "x/12x $esp", args.debugger_timeout)
                registers = parse_registers(info)
                stack_memory = parse_memory_words(stack)
                esp = registers.get("esp")

                issue_capture(child, "x/12x $ecx", args.debugger_timeout)
                issue_capture(child, "x/12x $esi", args.debugger_timeout)

                if address in {"0x004a7447", "0x004a54a7"} and esp is not None:
                    object_record = memory_word(stack_memory, esp + (0 if address == "0x004a7447" else 4))
                    x = memory_word(stack_memory, esp + (4 if address == "0x004a7447" else 8))
                    y = memory_word(stack_memory, esp + (8 if address == "0x004a7447" else 12))
                    level = memory_word(stack_memory, esp + (12 if address == "0x004a7447" else 16))
                    generator = registers.get("ecx")
                    generator_dump = issue_capture(child, "x/12x $ecx", args.debugger_timeout)
                    generator_memory = parse_memory_words(generator_dump)
                    cell = (
                        generated_cell_pointer(generator_memory, generator, x, y, level)
                        if generator is not None and None not in {x, y, level}
                        else None
                    )
                    captured_cells.append(
                        {
                            "event_index": events,
                            "site": address,
                            "object_record": qhex(object_record),
                            "coordinate": {"x": x, "y": y, "level": level},
                            "generator": qhex(generator),
                            "cell_pointer": qhex(cell),
                        }
                    )
                    if cell is not None:
                        issue_capture(child, f"x/16x {qhex(cell)}", args.debugger_timeout)
                        issue_capture(child, f"x/4x *(int*)({qhex(cell)}+4)", args.debugger_timeout)
                    issue_capture(child, "x/16x $ecx+0xec4", args.debugger_timeout)

                if address == "0x004a54ef":
                    issue_capture(child, "x/16x $esi+0xec4", args.debugger_timeout)
                    issue_capture(child, "x/4x $edx", args.debugger_timeout)

                if address in {"0x004a5756", "0x004a744c", "0x004a7e21", "0x004a7e25"}:
                    for cell_record in captured_cells:
                        cell_text = cell_record.get("cell_pointer")
                        if cell_text:
                            issue_capture(child, f"x/16x {cell_text}", args.debugger_timeout)
                            issue_capture(child, f"x/4x *(int*)({cell_text}+4)", args.debugger_timeout)

                if address == "0x004a7e25":
                    break
                child.send("cont\r")
            child.send("q\r")
            child.expect([pexpect.EOF, PROMPT_RE], timeout=5)
        finally:
            child.close(force=True)
    return {"event_count": events, "captured_cells": captured_cells}


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--h3maped-runtime", type=Path, default=DEFAULT_RUNTIME)
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR)
    parser.add_argument("--display-number", type=int, default=117)
    parser.add_argument("--screen-size", default="1024x768x24")
    parser.add_argument("--wineprefix", type=Path, default=Path(".artifacts/wine/h3maped"))
    parser.add_argument("--generate-wait-seconds", type=int, default=2)
    parser.add_argument("--debugger-timeout", type=int, default=90)
    parser.add_argument("--max-events", type=int, default=120)
    parser.add_argument("--map-size", choices=["small", "medium", "large", "xlarge"], default="medium")
    parser.add_argument("--human-computer-down", type=int, default=1)
    parser.add_argument("--computer-only-down", type=int, default=1)
    parser.add_argument("--monster-strength-down", type=int, default=-1)
    parser.add_argument("--water-none", action="store_true", default=True)
    parser.add_argument("--inside-xvfb", action="store_true")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    repo_root = args.repo_root.resolve()
    args.h3maped_runtime = (repo_root / args.h3maped_runtime).resolve() if not args.h3maped_runtime.is_absolute() else args.h3maped_runtime.resolve()
    args.out_dir = (repo_root / args.out_dir).resolve() if not args.out_dir.is_absolute() else args.out_dir.resolve()
    args.wineprefix = (repo_root / args.wineprefix).resolve() if not args.wineprefix.is_absolute() else args.wineprefix.resolve()
    args.out_dir.mkdir(parents=True, exist_ok=True)
    log_path = args.out_dir / "winedbg_dynamic_endpoint_afterstate_trace.log"
    meta_path = args.out_dir / "dynamic_endpoint_afterstate_meta.json"
    ledger_path = args.out_dir / "winedbg_dynamic_endpoint_afterstate_trace_ledger.json"

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
        meta = run_xvfb(args, repo_root, log_path)
        meta_path.write_text(json.dumps(meta, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        return 0 if meta["event_count"] else 1

    ledger = parse_winedbg_log(log_path)
    meta = json.loads(meta_path.read_text(encoding="utf-8")) if meta_path.exists() else {}
    ledger["trace_breakpoints"] = TRACE_BREAKPOINTS
    ledger["dynamic_captured_cells"] = meta.get("captured_cells", [])
    ledger_path.write_text(json.dumps(ledger, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    status = "pass" if ledger["event_count"] else "no_events"
    print(
        "RMG_H3MAPED_ENDPOINT_AFTERSTATE_DYNAMIC_TRACE "
        f"status={status} events={ledger['event_count']} cells={len(ledger['dynamic_captured_cells'])} "
        f"ledger={ledger_path}"
    )
    return 0 if ledger["event_count"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
