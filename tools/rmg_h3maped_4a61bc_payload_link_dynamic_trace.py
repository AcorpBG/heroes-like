#!/usr/bin/env python3
"""Trace a 0x4a61bc-origin object commit into the 0x4a79a3 payload loop.

This is recovery evidence only. It captures one selected 0x4a6578 caller
boundary, records the constructed object pointer that reaches 0x4a54a7 through
0x4a5e03, then continues the same H3MapEd run into the later 0x4a79a3 payload
and dispatch sites.
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
    DEFAULT_H3MAPED_EXE,
    DEFAULT_RUNTIME,
    PROMPT_RE,
    STOP_RE,
    drive_h3maped_ui,
    normalize_address,
    prepare_seed_patched_runtime,
)
from rmg_h3maped_recovery_trace import ANSI_RE, DWORD_LINE_RE, REGISTER_RE, parse_winedbg_log


DEFAULT_OUT_DIR = Path(".artifacts/rmg_recovery/4a61bc_payload_link_dynamic_trace_20260609")
INITIAL_BREAKPOINT = "0x004a6578"
ARMED_BREAKPOINTS = [
    "0x004a5e03",
    "0x004a5e55",
    "0x004a54a7",
    "0x004a5756",
    "0x004a5e6c",
    "0x004a657d",
    "0x004a79a3",
    "0x004a7d2c",
    "0x004a7d36",
    "0x004a7d99",
    "0x004a696b",
    "0x004a69bb",
    "0x004a69c2",
    "0x004a6a81",
    "0x004a6a8f",
    "0x004a6ac8",
    "0x004a6ade",
    "0x004a6ae2",
    "0x004a6b10",
    "0x004a6b27",
    "0x004a6b2e",
    "0x004a6b9b",
    "0x004a6c13",
    "0x004a6c2c",
    "0x004a6c59",
    "0x004a6c78",
    "0x004a6cd3",
    "0x004a6ce1",
    "0x004a7605",
    "0x004a7312",
    "0x004a7447",
    "0x004a744c",
    "0x004a774a",
    "0x004a7763",
    "0x004a7773",
    "0x004a783a",
    "0x004a7853",
    "0x004a7860",
    "0x004a746b",
    "0x004a5e73",
    "0x004a5fd8",
    "0x004a5ff1",
    "0x004a75f1",
    "0x004a7df4",
    "0x004a7e21",
    "0x004a7e25",
    "0x0049eb8d",
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


def capture_pointer(child: pexpect.spawn, pointer_text: str, timeout: int, words: int = 16) -> None:
    issue_capture(child, f"x/{words}x {pointer_text}", timeout)


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


def run_xvfb(args: argparse.Namespace, log_path: Path) -> dict[str, Any]:
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
        "skip_caller_boundaries": args.skip_caller_boundaries,
        "caller_boundary_hits": 0,
        "skipped_caller_boundaries": [],
        "armed_after_event": None,
        "armed_caller_boundary_index": None,
        "target_coordinate": None,
        "target_cell": None,
        "object_record": None,
        "subsequent_object_records": [],
        "reached_after_selected_4a61bc": False,
        "payload_record_events": 0,
        "dispatch_events": 0,
        "event_count": 0,
    }
    armed = False
    selected_done = False
    payload_count_seen = False

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
                    boundary_index = int(metadata["caller_boundary_hits"])
                    metadata["caller_boundary_hits"] = boundary_index + 1
                    issue_capture(child, "x/16x $ebx+0xec4", args.debugger_timeout)
                    if boundary_index < args.skip_caller_boundaries:
                        metadata["skipped_caller_boundaries"].append(
                            {"boundary_index": boundary_index, "event_index": metadata["event_count"]}
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
                    generator_dump = issue_capture(child, "x/16x $ecx", args.debugger_timeout)
                    issue_capture(child, "x/16x $ecx+0xec4", args.debugger_timeout)
                    generator_memory = parse_memory_words(generator_dump)
                    if generator is not None and esp is not None:
                        x = memory_word(stack_memory, esp + 8)
                        y = memory_word(stack_memory, esp + 12)
                        level = memory_word(stack_memory, esp + 16)
                        if None not in {x, y, level}:
                            target_cell = generated_cell_pointer(generator_memory, generator, int(x), int(y), int(level))
                            metadata["target_cell"] = qhex(target_cell)
                            metadata["target_coordinate"] = {"x": x, "y": y, "level": level}
                            if target_cell is not None:
                                capture_pointer(child, qhex(target_cell) or "0", args.debugger_timeout)

                elif address == "0x004a5e55":
                    object_record = registers.get("eax")
                    if not selected_done and metadata.get("object_record") is None:
                        metadata["object_record"] = qhex(object_record)
                    elif object_record:
                        metadata["subsequent_object_records"].append(
                            {
                                "event_index": metadata["event_count"],
                                "object_record": qhex(object_record),
                            }
                        )
                    if object_record:
                        capture_pointer(child, "$eax", args.debugger_timeout)

                elif address in {"0x004a54a7", "0x004a5756", "0x004a5e6c", "0x004a657d"}:
                    issue_capture(child, "x/16x $ecx+0xec4", args.debugger_timeout)
                    issue_capture(child, "x/16x $ebx+0xec4", args.debugger_timeout)
                    if metadata.get("target_cell"):
                        capture_pointer(child, str(metadata["target_cell"]), args.debugger_timeout)
                    if address == "0x004a657d":
                        selected_done = True
                        metadata["reached_after_selected_4a61bc"] = True

                elif address == "0x004a79a3":
                    issue_capture(child, "x/16x $ecx+0xec4", args.debugger_timeout)
                    issue_capture(child, "x/16x $ecx+0xc8", args.debugger_timeout)
                    issue_capture(child, "x/16x $ecx+0xd8", args.debugger_timeout)

                elif address == "0x004a7d2c":
                    issue_capture(child, "x/32x $eax", args.debugger_timeout)

                elif address == "0x004a7d36":
                    metadata["payload_record_events"] = int(metadata["payload_record_events"]) + 1
                    issue_capture(child, "x/32x $eax", args.debugger_timeout)
                    capture_pointer(child, "$edx", args.debugger_timeout, words=16)

                elif address == "0x004a7d99":
                    payload_count_seen = True
                    issue_capture(child, "x/32x $eax", args.debugger_timeout)

                elif address in {"0x004a696b", "0x004a7605", "0x004a7df4", "0x004a7e21", "0x004a7e25"}:
                    metadata["dispatch_events"] = int(metadata["dispatch_events"]) + 1
                    capture_pointer(child, "$esi", args.debugger_timeout)
                    capture_pointer(child, "$ecx", args.debugger_timeout)
                    capture_pointer(child, "$edx", args.debugger_timeout)

                elif address in {
                    "0x004a7312",
                    "0x004a7447",
                    "0x004a744c",
                    "0x004a774a",
                    "0x004a7763",
                    "0x004a7773",
                    "0x004a783a",
                    "0x004a7853",
                    "0x004a7860",
                    "0x004a746b",
                    "0x004a5e73",
                    "0x004a5fd8",
                    "0x004a5ff1",
                    "0x004a75f1",
                }:
                    capture_pointer(child, "$esi", args.debugger_timeout)
                    capture_pointer(child, "$ecx", args.debugger_timeout)
                    capture_pointer(child, "$edx", args.debugger_timeout)

                elif address in {
                    "0x004a69bb",
                    "0x004a69c2",
                    "0x004a6a81",
                    "0x004a6a8f",
                    "0x004a6ac8",
                    "0x004a6ade",
                    "0x004a6ae2",
                    "0x004a6b10",
                    "0x004a6b27",
                    "0x004a6b2e",
                    "0x004a6b9b",
                    "0x004a6c13",
                    "0x004a6c2c",
                    "0x004a6c59",
                    "0x004a6c78",
                    "0x004a6cd3",
                    "0x004a6ce1",
                }:
                    issue_capture(child, "x/24x $ebp-0x58", args.debugger_timeout)
                    capture_pointer(child, "$esi", args.debugger_timeout)

                elif address == "0x0049eb8d":
                    issue_capture(child, "x/16x $ecx+0xec4", args.debugger_timeout)
                    if selected_done and payload_count_seen:
                        break

                if selected_done and payload_count_seen and int(metadata["dispatch_events"]) >= args.stop_after_dispatch_events:
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
    parser.add_argument(
        "--h3maped-exe",
        type=Path,
        default=DEFAULT_H3MAPED_EXE,
        help="Clean h3maped.exe used as the PE seed-patch source.",
    )
    parser.add_argument("--resource-dir", type=Path, default=None)
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR)
    parser.add_argument("--display-number", type=int, default=136)
    parser.add_argument("--screen-size", default="1024x768x24")
    parser.add_argument("--wineprefix", type=Path, default=Path(".artifacts/wine/h3maped"))
    parser.add_argument("--generate-wait-seconds", type=int, default=2)
    parser.add_argument("--debugger-timeout", type=int, default=180)
    parser.add_argument("--max-events", type=int, default=1800)
    parser.add_argument("--skip-caller-boundaries", type=int, default=0)
    parser.add_argument("--stop-after-dispatch-events", type=int, default=12)
    parser.add_argument("--map-size", choices=["small", "medium", "large", "xlarge"], default="small")
    parser.add_argument("--human-computer-down", type=int, default=-1)
    parser.add_argument("--computer-only-down", type=int, default=-1)
    parser.add_argument("--monster-strength-down", type=int, default=-1)
    parser.add_argument("--water-none", action="store_true", default=False)
    parser.add_argument("--seed", default="", help="Random-map seed to force when using --seed-control-mode=pe-patch.")
    parser.add_argument("--seed-control-mode", choices=["none", "pe-patch"], default="none")
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
    args.h3maped_exe = (
        (repo_root / args.h3maped_exe).resolve()
        if not args.h3maped_exe.is_absolute()
        else args.h3maped_exe.resolve()
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
    args.resource_dir = (
        (repo_root / args.resource_dir).resolve()
        if args.resource_dir and not args.resource_dir.is_absolute()
        else args.resource_dir
    )
    args.out_dir.mkdir(parents=True, exist_ok=True)
    seed_control = prepare_seed_patched_runtime(args) if not args.inside_xvfb else {"status": "inside_xvfb_inherited"}
    log_path = args.out_dir / "winedbg_4a61bc_payload_link_dynamic_trace.log"
    meta_path = args.out_dir / "dynamic_trace_meta.json"
    ledger_path = args.out_dir / "winedbg_4a61bc_payload_link_dynamic_trace_ledger.json"

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
            "--h3maped-exe",
            str(args.h3maped_exe),
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
            "--stop-after-dispatch-events",
            str(args.stop_after_dispatch_events),
            "--map-size",
            args.map_size,
            "--human-computer-down",
            str(args.human_computer_down),
            "--computer-only-down",
            str(args.computer_only_down),
            "--monster-strength-down",
            str(args.monster_strength_down),
            "--seed-control-mode",
            "none",
        ]
        if args.resource_dir:
            command.extend(["--resource-dir", str(args.resource_dir)])
        if args.water_none:
            command.append("--water-none")
        completed = subprocess.run(command, cwd=repo_root, text=True)
        if completed.returncode != 0:
            return completed.returncode
    else:
        metadata = run_xvfb(args, log_path)
        meta_path.write_text(json.dumps(metadata, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        return 0 if metadata["event_count"] else 1

    ledger = parse_winedbg_log(log_path)
    metadata = json.loads(meta_path.read_text(encoding="utf-8")) if meta_path.exists() else {}
    ledger["dynamic_trace_meta"] = metadata
    ledger["seed_control"] = seed_control
    ledger_path.write_text(json.dumps(ledger, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    status = "pass" if ledger.get("event_count") else "no_events"
    print(
        "RMG_H3MAPED_4A61BC_PAYLOAD_LINK_DYNAMIC_TRACE "
        f"status={status} events={ledger.get('event_count')} "
        f"object_record={metadata.get('object_record')} "
        f"payload_record_events={metadata.get('payload_record_events')} "
        f"dispatch_events={metadata.get('dispatch_events')} "
        f"ledger={ledger_path}"
    )
    return 0 if ledger.get("event_count") else 1


if __name__ == "__main__":
    raise SystemExit(main())
