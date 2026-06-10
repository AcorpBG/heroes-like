#!/usr/bin/env python3
"""Trace same-run descriptor builds and selected descriptor commits.

The generic interactive trace driver cannot capture loader-time descriptor
builder stops because those stops pause H3MapEd before the UI can be driven.
This focused driver drains ``0x4903e8`` build events first, interrupts the live
process once the main window is visible, arms the generation-time commit
breakpoints, then drives the New Map dialog in the same process.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path
from typing import Any

import pexpect

from rmg_h3maped_controlled_reference import DEFAULT_H3MAPED_EXE
from rmg_h3maped_recovery_interactive_trace import (
    PROMPT_RE,
    STOP_RE,
    click_combo_option,
    click_window_relative,
    find_named_window_id,
    issue_and_wait,
    normalize_address,
    open_new_dialog,
    prepare_seed_patched_runtime,
    run_xdotool,
    take_screenshot,
    wait_for_main_window,
    wait_for_named_window,
)
from rmg_h3maped_recovery_trace import DEFAULT_RUNTIME, parse_winedbg_log


DEFAULT_OUT_DIR = Path(".artifacts/rmg_recovery/medium_seed10_descriptor_build_selected_join_trace_20260610")
BUILD_STORE = "0x0049041f"
COMMIT_ENTRY = "0x004a54a7"
SELECTED_DESCRIPTOR = "0x004a5501"


def window_visible(name: str) -> bool:
    completed = subprocess.run(
        ["xdotool", "search", "--onlyvisible", "--name", name],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return completed.returncode == 0


def issue_capture(child: pexpect.spawn, command: str, timeout: int) -> None:
    child.send(command + "\r")
    child.expect(PROMPT_RE, timeout=timeout)


def capture_stop(child: pexpect.spawn, address: str, timeout: int) -> None:
    issue_capture(child, "info reg", timeout)
    if address == BUILD_STORE:
        return
    issue_capture(child, "x/8x $esp", timeout)
    if address == SELECTED_DESCRIPTOR:
        issue_capture(child, "x/24x $eax", timeout)
    elif address == COMMIT_ENTRY:
        issue_capture(child, "x/20x $esp", timeout)


def drive_h3maped_ui_to_configured(args: argparse.Namespace, screen_dir: Path) -> None:
    wait_for_main_window()
    time.sleep(3)
    take_screenshot(screen_dir, "01_main")
    open_new_dialog()
    time.sleep(0.2)
    take_screenshot(screen_dir, "02_new_dialog")

    new_map = find_named_window_id("New Map")
    click_window_relative(new_map, 29, 125)
    time.sleep(0.1)
    click_window_relative(new_map, 16, 176)
    time.sleep(0.1)
    click_window_relative(new_map, 16, 195)
    time.sleep(0.1)
    take_screenshot(screen_dir, "03_random_expanded")

    new_map = find_named_window_id("New Map")
    if args.map_size == "medium":
        click_window_relative(new_map, 29, 145)
        time.sleep(0.1)
    elif args.map_size == "large":
        click_window_relative(new_map, 128, 125)
        time.sleep(0.1)
    elif args.map_size == "xlarge":
        click_window_relative(new_map, 128, 145)
        time.sleep(0.1)
    if args.human_computer_down >= 0:
        click_combo_option(new_map, 220, 245, args.human_computer_down)
    if args.computer_only_down >= 0:
        click_combo_option(new_map, 436, 245, args.computer_only_down)
    if args.water_none:
        click_window_relative(new_map, 138, 356)
        time.sleep(0.1)
    if args.monster_strength_down >= 0:
        click_combo_option(new_map, 436, 405, args.monster_strength_down)
    click_window_relative(new_map, 234, 454)
    click_window_relative(new_map, 125, 502)
    time.sleep(0.2)
    take_screenshot(screen_dir, "04_configured")


def click_generate_configured_map(args: argparse.Namespace, screen_dir: Path) -> None:
    new_map = find_named_window_id("New Map")
    click_window_relative(new_map, 377, 118)
    time.sleep(0.2)
    if wait_for_named_window("New Map", attempts=2):
        run_xdotool(["mousemove", "497", "214", "click", "1"])
        time.sleep(0.1)
        run_xdotool(["key", "Return"])
    time.sleep(args.generate_wait_seconds)
    take_screenshot(screen_dir, "05_after_generate_click")


def run_inside_xvfb(args: argparse.Namespace, repo_root: Path, log_path: Path) -> dict[str, Any]:
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
    meta: dict[str, Any] = {
        "build_breakpoint": BUILD_STORE,
        "generation_breakpoints": [COMMIT_ENTRY, SELECTED_DESCRIPTOR],
        "startup_build_events": 0,
        "generation_events": 0,
        "main_window_seen": False,
        "interrupted_to_arm_generation_breakpoints": False,
        "interrupted_to_reenable_build_breakpoint_before_generate": False,
        "startup_idle_polls_before_arm": 0,
        "event_count": 0,
    }

    with log_path.open("w", encoding="utf-8") as log:
        child.logfile_read = log
        try:
            child.expect(PROMPT_RE, timeout=args.debugger_timeout)
            issue_and_wait(child, f"break *{BUILD_STORE}", args.debugger_timeout)
            child.send("cont\r")

            startup_deadline = time.monotonic() + args.startup_timeout
            idle_polls = 0
            while time.monotonic() < startup_deadline and meta["event_count"] < args.max_startup_events:
                index = child.expect([STOP_RE, pexpect.EOF, pexpect.TIMEOUT], timeout=args.startup_poll_timeout)
                if index == 0:
                    idle_polls = 0
                    address = normalize_address("0x" + child.match.group(1))
                    meta["event_count"] += 1
                    if address == BUILD_STORE:
                        meta["startup_build_events"] += 1
                    child.expect(PROMPT_RE, timeout=args.debugger_timeout)
                    capture_stop(child, address, args.debugger_timeout)
                    child.send("cont\r")
                    continue
                if index == 1:
                    break
                idle_polls += 1
                meta["startup_idle_polls_before_arm"] = idle_polls
                if idle_polls >= args.startup_idle_polls and window_visible("Heroes of Might"):
                    meta["main_window_seen"] = True
                    break

            if not meta["main_window_seen"]:
                meta["main_window_seen"] = window_visible("Heroes of Might")
            if not meta["main_window_seen"]:
                raise RuntimeError("H3MapEd main window did not appear while draining descriptor builds")

            child.sendcontrol("c")
            child.expect(PROMPT_RE, timeout=args.debugger_timeout)
            meta["interrupted_to_arm_generation_breakpoints"] = True
            issue_and_wait(child, "disable 1", args.debugger_timeout)
            meta["build_breakpoint_disabled_before_ui_drive"] = True
            issue_and_wait(child, f"break *{COMMIT_ENTRY}", args.debugger_timeout)
            issue_and_wait(child, f"break *{SELECTED_DESCRIPTOR}", args.debugger_timeout)
            child.send("cont\r")

            drive_h3maped_ui_to_configured(args, args.out_dir / "screenshots")

            child.sendcontrol("c")
            child.expect(PROMPT_RE, timeout=args.debugger_timeout)
            meta["interrupted_to_reenable_build_breakpoint_before_generate"] = True
            issue_and_wait(child, "enable 1", args.debugger_timeout)
            meta["build_breakpoint_reenabled_before_generate"] = True
            child.send("cont\r")
            click_generate_configured_map(args, args.out_dir / "screenshots")

            while meta["event_count"] < args.max_events:
                index = child.expect([STOP_RE, pexpect.EOF, pexpect.TIMEOUT], timeout=args.generation_timeout)
                if index != 0:
                    break
                address = normalize_address("0x" + child.match.group(1))
                meta["event_count"] += 1
                if address in {COMMIT_ENTRY, SELECTED_DESCRIPTOR}:
                    meta["generation_events"] += 1
                elif address == BUILD_STORE:
                    meta["startup_build_events"] += 1
                child.expect(PROMPT_RE, timeout=args.debugger_timeout)
                capture_stop(child, address, args.debugger_timeout)
                child.send("cont\r")

            child.send("q\r")
            child.expect([pexpect.EOF, PROMPT_RE], timeout=5)
        finally:
            child.close(force=True)
    return meta


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--h3maped-runtime", type=Path, default=DEFAULT_RUNTIME)
    parser.add_argument("--h3maped-exe", type=Path, default=DEFAULT_H3MAPED_EXE)
    parser.add_argument("--resource-dir", type=Path, default=None)
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR)
    parser.add_argument("--display-number", type=int, default=212)
    parser.add_argument("--screen-size", default="1024x768x24")
    parser.add_argument("--wineprefix", type=Path, default=Path(".artifacts/wine/h3maped"))
    parser.add_argument("--debugger-timeout", type=int, default=180)
    parser.add_argument("--startup-timeout", type=int, default=180)
    parser.add_argument("--startup-poll-timeout", type=int, default=2)
    parser.add_argument("--startup-idle-polls", type=int, default=10)
    parser.add_argument("--generation-timeout", type=int, default=180)
    parser.add_argument("--max-startup-events", type=int, default=2500)
    parser.add_argument("--max-events", type=int, default=5000)
    parser.add_argument("--generate-wait-seconds", type=int, default=8)
    parser.add_argument("--map-size", choices=["small", "medium", "large", "xlarge"], default="medium")
    parser.add_argument("--human-computer-down", type=int, default=-1)
    parser.add_argument("--computer-only-down", type=int, default=-1)
    parser.add_argument("--monster-strength-down", type=int, default=-1)
    parser.add_argument("--water-none", action="store_true", default=True)
    parser.add_argument("--seed", default="10")
    parser.add_argument("--seed-control-mode", choices=["none", "pe-patch"], default="pe-patch")
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
    args.resource_dir = (
        (repo_root / args.resource_dir).resolve()
        if args.resource_dir and not args.resource_dir.is_absolute()
        else args.resource_dir
    )
    args.out_dir = (repo_root / args.out_dir).resolve() if not args.out_dir.is_absolute() else args.out_dir.resolve()
    args.wineprefix = (
        (repo_root / args.wineprefix).resolve()
        if not args.wineprefix.is_absolute()
        else args.wineprefix.resolve()
    )
    args.out_dir.mkdir(parents=True, exist_ok=True)
    seed_control = prepare_seed_patched_runtime(args) if not args.inside_xvfb else {"status": "inside_xvfb_inherited"}

    log_path = args.out_dir / "winedbg_descriptor_build_selected_join_trace.log"
    meta_path = args.out_dir / "descriptor_build_selected_join_trace_meta.json"
    ledger_path = args.out_dir / "winedbg_interactive_trace_ledger.json"

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
            "--debugger-timeout",
            str(args.debugger_timeout),
            "--startup-timeout",
            str(args.startup_timeout),
            "--startup-poll-timeout",
            str(args.startup_poll_timeout),
            "--startup-idle-polls",
            str(args.startup_idle_polls),
            "--generation-timeout",
            str(args.generation_timeout),
            "--max-startup-events",
            str(args.max_startup_events),
            "--max-events",
            str(args.max_events),
            "--generate-wait-seconds",
            str(args.generate_wait_seconds),
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
        if args.water_none:
            command.append("--water-none")
        completed = subprocess.run(command, cwd=repo_root, text=True)
        child_returncode = completed.returncode
    else:
        meta = run_inside_xvfb(args, repo_root, log_path)
        meta_path.write_text(json.dumps(meta, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        return 0 if meta.get("event_count") else 1

    if not log_path.exists():
        return child_returncode
    ledger = parse_winedbg_log(log_path)
    metadata = json.loads(meta_path.read_text(encoding="utf-8")) if meta_path.exists() else {}
    ledger["trace_meta"] = metadata
    ledger["breakpoints"] = [BUILD_STORE, COMMIT_ENTRY, SELECTED_DESCRIPTOR]
    ledger["seed_control"] = seed_control
    ledger["child_returncode"] = child_returncode
    ledger_path.write_text(json.dumps(ledger, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    status = "pass" if ledger.get("event_count") and metadata.get("generation_events") else "no_generation_events"
    print(
        "RMG_H3MAPED_DESCRIPTOR_BUILD_SELECTED_JOIN_TRACE "
        f"status={status} events={ledger.get('event_count')} "
        f"build_events={metadata.get('startup_build_events')} "
        f"generation_events={metadata.get('generation_events')} ledger={ledger_path}"
    )
    if child_returncode != 0:
        return child_returncode
    return 0 if status == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
