#!/usr/bin/env python3
"""Interactively trace H3MapEd RMG breakpoints through winedbg.

The older recovery trace driver pipes a fixed command stream into winedbg.
That is good enough for small bounded probes, but it can exhaust input before
the next phase boundary when many breakpoints fire. This driver waits for each
breakpoint stop before issuing the next diagnostic commands.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shlex
import subprocess
import sys
import time
from pathlib import Path

import pexpect

from rmg_h3maped_controlled_reference import (
    DEFAULT_H3MAPED_EXE,
    REQUIRED_RESOURCE_LODS,
    find_lod,
    parse_requested_seed,
    patch_h3maped_seed,
    symlink_or_copy,
)
from rmg_h3maped_recovery_trace import (
    DEFAULT_RUNTIME,
    parse_winedbg_log,
)


DEFAULT_OUT_DIR = Path(".artifacts/rmg_recovery/seed58_interactive_trace")
STOP_RE = r"Stopped on [A-Za-z _-]*(?:breakpoint|watchpoint)\s+\d+\s+at\s+0x([0-9a-fA-F]+)"
PROMPT_RE = r"Wine-dbg>"


def q(value: str | Path) -> str:
    return shlex.quote(str(value))


def normalize_address(value: str) -> str:
    return "0x%08x" % int(value, 0)


def parse_address_commands(values: list[str]) -> dict[str, list[str]]:
    commands: dict[str, list[str]] = {}
    for value in values:
        if "=" not in value:
            raise ValueError(f"--address-command must be ADDRESS=COMMAND, got: {value}")
        address, command = value.split("=", 1)
        address = normalize_address(address.strip())
        command = command.strip()
        if not command:
            raise ValueError(f"--address-command has an empty command for {address}")
        commands.setdefault(address, []).append(command)
    return commands


def run_xdotool(args: list[str], *, timeout: float = 10.0) -> None:
    subprocess.run(["xdotool", *args], check=True, timeout=timeout)


def take_screenshot(screen_dir: Path, name: str) -> None:
    screen_dir.mkdir(parents=True, exist_ok=True)
    subprocess.run(["scrot", str(screen_dir / f"{name}.png")], check=False)


def prepare_seed_patched_runtime(args: argparse.Namespace) -> dict[str, object]:
    if args.seed_control_mode == "none":
        return {"status": "not_requested", "mode": "none"}
    if not args.seed:
        raise ValueError("--seed is required when --seed-control-mode=pe-patch")

    source_runtime = args.h3maped_runtime
    runtime_dir = args.out_dir / "runtime_seed_patched"
    data_dir = runtime_dir / "Data"
    runtime_dir.mkdir(parents=True, exist_ok=True)
    data_dir.mkdir(parents=True, exist_ok=True)

    source_exe = args.h3maped_exe
    if not source_exe.exists():
        raise FileNotFoundError(f"missing clean h3maped.exe: {source_exe}")
    runtime_exe = runtime_dir / "h3maped.exe"
    runtime_exe.write_bytes(source_exe.read_bytes())

    resource_source_dir = args.resource_dir or source_runtime
    resources: dict[str, str] = {}
    missing: list[str] = []
    for name in REQUIRED_RESOURCE_LODS:
        source = find_lod(resource_source_dir, name)
        if source is None:
            missing.append(name)
            continue
        symlink_or_copy(source.resolve(), data_dir / name)
        resources[name] = str(source.resolve())

    patch = patch_h3maped_seed(runtime_exe, parse_requested_seed(args.seed))
    if patch.get("status") != "patched":
        raise RuntimeError(f"failed to seed-patch clean h3maped.exe: {patch}")
    args.h3maped_runtime = runtime_dir
    return {
        "status": "prepared",
        "mode": args.seed_control_mode,
        "requested_seed": args.seed,
        "source_exe": str(source_exe),
        "runtime_dir": str(runtime_dir),
        "resource_source_dir": str(resource_source_dir),
        "resources": resources,
        "missing": missing,
        "patch": patch,
    }


def wait_for_main_window() -> None:
    for _ in range(80):
        completed = subprocess.run(
            ["xdotool", "search", "--onlyvisible", "--name", "Heroes of Might"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
        if completed.returncode == 0:
            return
        time.sleep(0.25)
    raise RuntimeError("H3MapEd main window did not appear")


def wait_for_named_window(name: str, attempts: int = 40) -> bool:
    for _ in range(attempts):
        completed = subprocess.run(
            ["xdotool", "search", "--onlyvisible", "--name", name],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
        if completed.returncode == 0:
            return True
        time.sleep(0.25)
    return False


def find_named_window_id(name: str, attempts: int = 40) -> str:
    for _ in range(attempts):
        completed = subprocess.run(
            ["xdotool", "search", "--onlyvisible", "--name", name],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            check=False,
        )
        ids = [line.strip() for line in completed.stdout.splitlines() if line.strip()]
        if ids:
            return ids[-1]
        time.sleep(0.25)
    raise RuntimeError(f"{name} window did not appear")


def window_geometry(window_id: str) -> tuple[int, int, int, int]:
    completed = subprocess.run(
        ["xdotool", "getwindowgeometry", "--shell", window_id],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=True,
    )
    values: dict[str, int] = {}
    for line in completed.stdout.splitlines():
        match = re.match(r"^(X|Y|WIDTH|HEIGHT)=(-?\d+)$", line)
        if match:
            values[match.group(1)] = int(match.group(2))
    return values["X"], values["Y"], values["WIDTH"], values["HEIGHT"]


def click_window_relative(window_id: str, rel_x: int, rel_y: int) -> None:
    x, y, _, _ = window_geometry(window_id)
    run_xdotool(["mousemove", str(x + rel_x), str(y + rel_y), "click", "1"])


def open_new_dialog() -> None:
    run_xdotool(["key", "Alt+f"])
    time.sleep(0.2)
    run_xdotool(["key", "n"])
    if wait_for_named_window("New Map"):
        return
    run_xdotool(["mousemove", "18", "41", "click", "1"])
    time.sleep(0.2)
    run_xdotool(["mousemove", "35", "61", "click", "1"])
    if not wait_for_named_window("New Map"):
        raise RuntimeError("H3MapEd New Map dialog did not appear")


def click_combo_option(window_id: str, rel_x: int, rel_y: int, down_count: int) -> None:
    if down_count < 0:
        return
    click_window_relative(window_id, rel_x, rel_y)
    time.sleep(0.1)
    for _ in range(down_count):
        run_xdotool(["key", "Down"])
        time.sleep(0.02)
    run_xdotool(["key", "Return"])
    time.sleep(0.1)


def drive_h3maped_ui(args: argparse.Namespace, screen_dir: Path) -> None:
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
    click_window_relative(new_map, 377, 118)
    time.sleep(0.2)
    if wait_for_named_window("New Map", attempts=2):
        run_xdotool(["mousemove", "497", "214", "click", "1"])
        time.sleep(0.1)
        run_xdotool(["key", "Return"])
    time.sleep(args.generate_wait_seconds)
    take_screenshot(screen_dir, "05_after_generate_click")


def issue_and_wait(child: pexpect.spawn, command: str, timeout: int) -> None:
    child.send(command + "\r")
    child.expect(PROMPT_RE, timeout=timeout)


def run_inside_xvfb(args: argparse.Namespace, repo_root: Path, log_path: Path) -> int:
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
    with log_path.open("w", encoding="utf-8") as log:
        child.logfile_read = log
        try:
            child.expect(PROMPT_RE, timeout=args.debugger_timeout)
            for address in args.breakpoints:
                issue_and_wait(child, f"break *{address}", args.debugger_timeout)
            for command in args.pre_cont_command:
                issue_and_wait(child, command, args.debugger_timeout)

            child.send("cont\r")
            drive_h3maped_ui(args, args.out_dir / "screenshots")

            events = 0
            stop_after = normalize_address(args.stop_after) if args.stop_after else ""
            address_commands = parse_address_commands(args.address_command)
            breakpoint_timeout = args.breakpoint_timeout or args.debugger_timeout
            while events < args.max_events:
                index = child.expect([STOP_RE, pexpect.EOF, pexpect.TIMEOUT], timeout=breakpoint_timeout)
                if index == 1:
                    break
                if index == 2:
                    take_screenshot(args.out_dir / "screenshots", f"timeout_after_{events:04d}_events")
                    raise TimeoutError("timed out waiting for next winedbg breakpoint")
                address = normalize_address("0x" + child.match.group(1))
                events += 1
                child.expect(PROMPT_RE, timeout=args.debugger_timeout)
                commands = []
                if not args.no_info_reg:
                    commands.append("info reg")
                commands.extend(["x/8x $esp", *args.extra_command])
                commands.extend(address_commands.get(address, []))
                if args.lite and args.lite_extra_command:
                    commands.append(args.lite_extra_command)
                if not args.lite:
                    commands.extend(["x/12x $ecx", "x/12x $esi", args.dump_command])
                for command in commands:
                    issue_and_wait(child, command, args.debugger_timeout)
                if stop_after and address == stop_after:
                    break
                child.send("cont\r")

            child.send("q\r")
            child.expect([pexpect.EOF, PROMPT_RE], timeout=5)
        finally:
            child.close(force=True)
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--h3maped-runtime", type=Path, default=DEFAULT_RUNTIME)
    parser.add_argument("--h3maped-exe", type=Path, default=DEFAULT_H3MAPED_EXE, help="Clean h3maped.exe used as the PE seed-patch source.")
    parser.add_argument("--resource-dir", type=Path, default=None)
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR)
    parser.add_argument("--breakpoints", nargs="+", required=True)
    parser.add_argument("--stop-after", default="")
    parser.add_argument("--max-events", type=int, default=2048)
    parser.add_argument("--dump-command", default="x/16x *(int*)($esi+0x14)")
    parser.add_argument("--generated-cell-base", default="")
    parser.add_argument("--generated-cell-stride", type=int, default=0x30)
    parser.add_argument("--display-number", type=int, default=115)
    parser.add_argument("--screen-size", default="1024x768x24")
    parser.add_argument("--wineprefix", type=Path, default=Path(".artifacts/wine/h3maped"))
    parser.add_argument("--generate-wait-seconds", type=int, default=2)
    parser.add_argument("--debugger-timeout", type=int, default=60)
    parser.add_argument(
        "--breakpoint-timeout",
        type=int,
        default=0,
        help="Seconds to wait for each breakpoint stop; defaults to --debugger-timeout when 0.",
    )
    parser.add_argument("--map-size", choices=["small", "medium", "large", "xlarge"], default="small")
    parser.add_argument("--human-computer-down", type=int, default=-1, help="Select the Human/Computer player-count combo by Down-key count; -1 leaves it unchanged.")
    parser.add_argument("--computer-only-down", type=int, default=-1, help="Select the Computer-only player-count combo by Down-key count; -1 leaves it unchanged.")
    parser.add_argument("--monster-strength-down", type=int, default=-1, help="Select the monster-strength combo by Down-key count; -1 leaves it unchanged.")
    parser.add_argument("--water-none", action="store_true", help="Click the Water content None radio button.")
    parser.add_argument("--seed", default="", help="Random-map seed to force when using --seed-control-mode=pe-patch.")
    parser.add_argument("--seed-control-mode", choices=["none", "pe-patch"], default="none")
    parser.add_argument("--lite", action="store_true", help="Only dump registers and stack at each breakpoint.")
    parser.add_argument("--no-info-reg", action="store_true", help="Skip `info reg` at each breakpoint; useful for high-volume stack-only traces.")
    parser.add_argument("--lite-extra-command", default="", help="Optional extra winedbg command to run in lite mode.")
    parser.add_argument(
        "--extra-command",
        action="append",
        default=[],
        help="Additional winedbg command to run at every breakpoint stop. May be repeated.",
    )
    parser.add_argument(
        "--pre-cont-command",
        action="append",
        default=[],
        help="Additional winedbg command to run after initial breakpoints are installed and before the first cont. May be repeated.",
    )
    parser.add_argument(
        "--address-command",
        action="append",
        default=[],
        help="Additional winedbg command to run only at ADDRESS. Format: ADDRESS=COMMAND. May be repeated.",
    )
    parser.add_argument("--inside-xvfb", action="store_true")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    repo_root = args.repo_root.resolve()
    args.h3maped_runtime = (repo_root / args.h3maped_runtime).resolve() if not args.h3maped_runtime.is_absolute() else args.h3maped_runtime.resolve()
    args.h3maped_exe = (repo_root / args.h3maped_exe).resolve() if not args.h3maped_exe.is_absolute() else args.h3maped_exe.resolve()
    args.out_dir = (repo_root / args.out_dir).resolve() if not args.out_dir.is_absolute() else args.out_dir.resolve()
    args.wineprefix = (repo_root / args.wineprefix).resolve() if not args.wineprefix.is_absolute() else args.wineprefix.resolve()
    args.resource_dir = (repo_root / args.resource_dir).resolve() if args.resource_dir and not args.resource_dir.is_absolute() else args.resource_dir
    args.out_dir.mkdir(parents=True, exist_ok=True)
    seed_control = prepare_seed_patched_runtime(args) if not args.inside_xvfb else {"status": "inside_xvfb_inherited"}

    log_path = args.out_dir / "winedbg_interactive_trace.log"
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
            "--max-events",
            str(args.max_events),
            "--dump-command",
            args.dump_command,
            "--generated-cell-base",
            args.generated_cell_base,
            "--generated-cell-stride",
            str(args.generated_cell_stride),
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
            "--seed-control-mode",
            "none",
            "--breakpoints",
            *args.breakpoints,
        ]
        if args.resource_dir:
            command.extend(["--resource-dir", str(args.resource_dir)])
        if args.water_none:
            command.append("--water-none")
        for extra_command in args.extra_command:
            command.extend(["--extra-command", extra_command])
        for pre_cont_command in args.pre_cont_command:
            command.extend(["--pre-cont-command", pre_cont_command])
        for address_command in args.address_command:
            command.extend(["--address-command", address_command])
        if args.lite:
            command.append("--lite")
        if args.no_info_reg:
            command.append("--no-info-reg")
        if args.lite_extra_command:
            command.extend(["--lite-extra-command", args.lite_extra_command])
        if args.stop_after:
            command.extend(["--stop-after", args.stop_after])
        completed = subprocess.run(command, cwd=repo_root, text=True)
        child_returncode = completed.returncode
    else:
        run_inside_xvfb(args, repo_root, log_path)
        return 0

    if not log_path.exists():
        return child_returncode
    generated_cell_base = int(args.generated_cell_base, 0) if args.generated_cell_base else None
    ledger = parse_winedbg_log(log_path, generated_cell_base=generated_cell_base, generated_cell_stride=args.generated_cell_stride)
    ledger["breakpoints"] = args.breakpoints
    ledger["stop_after"] = args.stop_after
    ledger["max_events"] = args.max_events
    ledger["child_returncode"] = child_returncode
    ledger["dump_command"] = args.dump_command
    ledger["extra_command"] = args.extra_command
    ledger["pre_cont_command"] = args.pre_cont_command
    ledger["address_command"] = args.address_command
    ledger["seed_control"] = seed_control
    ledger_path.write_text(json.dumps(ledger, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    if child_returncode != 0:
        status = "failed_with_events" if ledger["event_count"] else "failed_no_events"
    else:
        status = "pass" if ledger["event_count"] else "no_events"
    print(f"RMG_H3MAPED_INTERACTIVE_TRACE status={status} events={ledger['event_count']} ledger={ledger_path}")
    if child_returncode != 0:
        return child_returncode
    return 0 if ledger["event_count"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
