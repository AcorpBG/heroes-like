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
MEMORY_WORDS_RE = re.compile(r"0x[0-9a-fA-F]+:\s+((?:[0-9a-fA-F]{1,8}\s*)+)")


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


def click_radio_option(window_id: str, coordinates: list[tuple[int, int]], selected_index: int) -> None:
    if selected_index < 0:
        return
    if selected_index >= len(coordinates):
        raise ValueError(f"radio option index {selected_index} outside 0..{len(coordinates) - 1}")
    rel_x, rel_y = coordinates[selected_index]
    click_window_relative(window_id, rel_x, rel_y)
    time.sleep(0.1)


def configure_h3maped_new_map_dialog(args: argparse.Namespace, screen_dir: Path) -> None:
    wait_for_main_window()
    time.sleep(args.startup_settle_seconds)
    take_screenshot(screen_dir, "01_main")
    open_new_dialog()
    time.sleep(0.2)
    take_screenshot(screen_dir, "02_new_dialog")

    new_map = find_named_window_id("New Map")
    click_window_relative(new_map, 29, 125)
    time.sleep(0.1)
    if args.level_count == 1:
        # The H3MapEd New Map dialog opens with "Two level map" checked.
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
    if args.human_computer_teams_down >= 0:
        click_combo_option(new_map, 220, 302, args.human_computer_teams_down)
    if args.computer_only_teams_down >= 0:
        click_combo_option(new_map, 436, 302, args.computer_only_teams_down)
    water_mode = "none" if args.water_none else args.water_mode
    if water_mode != "leave":
        click_radio_option(
            new_map,
            [(29, 356), (138, 356), (246, 356), (354, 356)],
            ["random", "none", "normal", "islands"].index(water_mode),
        )
    if args.monster_strength_down >= 0:
        # Monster strength is a radio row, not a combo. The option order is
        # Random, Weak, Normal, Strong.
        click_radio_option(new_map, [(29, 405), (138, 405), (246, 405), (354, 405)], args.monster_strength_down)
    click_window_relative(new_map, 234, 454)
    click_window_relative(new_map, 125, 502)
    time.sleep(0.2)
    take_screenshot(screen_dir, "04_configured")
    args.configured_new_map_window_id = new_map


def trigger_h3maped_generate(args: argparse.Namespace, screen_dir: Path) -> None:
    new_map = getattr(args, "configured_new_map_window_id", "") or find_named_window_id("New Map")
    click_window_relative(new_map, 377, 118)
    time.sleep(0.2)
    if wait_for_named_window("New Map", attempts=2):
        run_xdotool(["mousemove", "497", "214", "click", "1"])
        time.sleep(0.1)
        run_xdotool(["key", "Return"])
    time.sleep(args.generate_wait_seconds)
    take_screenshot(screen_dir, "05_after_generate_click")


def drive_h3maped_ui(args: argparse.Namespace, screen_dir: Path) -> None:
    configure_h3maped_new_map_dialog(args, screen_dir)
    trigger_h3maped_generate(args, screen_dir)


def issue_and_wait(child: pexpect.spawn, command: str, timeout: int) -> str:
    child.send(command + "\r")
    child.expect(PROMPT_RE, timeout=timeout)
    return child.before


def install_breakpoint_and_wait(child: pexpect.spawn, address: str, timeout: int) -> None:
    output = issue_and_wait(child, f"break *{address}", timeout)
    rejected_markers = (
        "Too many bp.",
        "Invalid address, can't set breakpoint",
        "Cannot insert breakpoint",
    )
    if any(marker in output for marker in rejected_markers):
        raise RuntimeError(f"winedbg rejected breakpoint {address}: {output.strip()}")


def delete_breakpoints_and_wait(child: pexpect.spawn, breakpoint_ids: range, timeout: int) -> None:
    for breakpoint_id in breakpoint_ids:
        issue_and_wait(child, f"delete {breakpoint_id}", timeout)


def parse_winedbg_memory_words(output: str) -> list[int]:
    words: list[int] = []
    for match in MEMORY_WORDS_RE.finditer(output):
        for word in match.group(1).split():
            words.append(int(word, 16))
    return words


def interrupt_debuggee(child: pexpect.spawn, timeout: int) -> None:
    child.sendcontrol("c")
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
            if args.defer_breakpoints_until_generate:
                child.send("cont\r")
                configure_h3maped_new_map_dialog(args, args.out_dir / "screenshots")
                interrupt_debuggee(child, args.debugger_timeout)
                for address in args.breakpoints:
                    install_breakpoint_and_wait(child, address, args.debugger_timeout)
                for command in args.pre_cont_command:
                    issue_and_wait(child, command, args.debugger_timeout)
                child.send("cont\r")
                trigger_h3maped_generate(args, args.out_dir / "screenshots")
            else:
                for address in args.breakpoints:
                    install_breakpoint_and_wait(child, address, args.debugger_timeout)
                for command in args.pre_cont_command:
                    issue_and_wait(child, command, args.debugger_timeout)
                child.send("cont\r")
                drive_h3maped_ui(args, args.out_dir / "screenshots")

            events = 0
            stop_after = normalize_address(args.stop_after) if args.stop_after else ""
            address_commands = parse_address_commands(args.address_command)
            address_command_after_event_count = args.address_command_after_event_count
            armed_after_event_breakpoints = False
            second_armed_after_event_breakpoints = False
            breakpoint_timeout = args.breakpoint_timeout or args.debugger_timeout
            arm_after_event_address = normalize_address(args.arm_after_event_address) if args.arm_after_event_address else ""
            arm_after_event_return_address = normalize_address(args.arm_after_event_return_address) if args.arm_after_event_return_address else ""
            arm_after_event_rng_state = int(args.arm_after_event_rng_state, 0) if args.arm_after_event_rng_state else None
            arm_after_event_has_filter = bool(
                arm_after_event_address
                or arm_after_event_return_address
                or arm_after_event_rng_state is not None
            )
            second_arm_after_event_address = normalize_address(args.second_arm_after_event_address) if args.second_arm_after_event_address else ""
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
                if not args.no_info_reg and (
                    not args.info_reg_after_first_arm or armed_after_event_breakpoints
                ):
                    commands.append("info reg")
                commands.extend(["x/8x $esp", *args.extra_command])
                if address_command_after_event_count < 0 or events >= address_command_after_event_count:
                    commands.extend(address_commands.get(address, []))
                if args.lite and args.lite_extra_command:
                    commands.append(args.lite_extra_command)
                if not args.lite:
                    commands.extend(["x/12x $ecx", "x/12x $esi", args.dump_command])
                event_return_address = ""
                event_rng_state: int | None = None
                for command in commands:
                    output = issue_and_wait(child, command, args.debugger_timeout)
                    stripped_command = command.strip()
                    if stripped_command == "x/8x $esp":
                        words = parse_winedbg_memory_words(output)
                        if words:
                            event_return_address = normalize_address(hex(words[0]))
                        if args.dump_stack_arg0_words > 0 and len(words) > 1 and words[1] != 0:
                            issue_and_wait(
                                child,
                                f"x/{args.dump_stack_arg0_words}x 0x{words[1]:08x}",
                                args.debugger_timeout,
                            )
                    elif stripped_command == "x/4x $eax+0x14":
                        words = parse_winedbg_memory_words(output)
                        if words:
                            event_rng_state = words[0]
                arm_trigger_enabled = args.arm_after_event_count >= 0 or arm_after_event_has_filter
                arm_count_ready = args.arm_after_event_count < 0 or events >= args.arm_after_event_count
                arm_filter_ready = True
                if arm_after_event_address and address != arm_after_event_address:
                    arm_filter_ready = False
                if arm_after_event_return_address and event_return_address != arm_after_event_return_address:
                    arm_filter_ready = False
                if arm_after_event_rng_state is not None and event_rng_state != arm_after_event_rng_state:
                    arm_filter_ready = False
                if (
                    not armed_after_event_breakpoints
                    and args.arm_after_event_breakpoint
                    and arm_trigger_enabled
                    and arm_count_ready
                    and arm_filter_ready
                ):
                    if args.arm_after_event_delete_initial_breakpoints:
                        delete_breakpoints_and_wait(
                            child,
                            range(1, len(args.breakpoints) + 1),
                            args.debugger_timeout,
                        )
                    for breakpoint in args.arm_after_event_breakpoint:
                        install_breakpoint_and_wait(child, breakpoint, args.debugger_timeout)
                    for command in args.arm_after_event_command:
                        issue_and_wait(child, command, args.debugger_timeout)
                    armed_after_event_breakpoints = True
                second_arm_count_ready = (
                    args.second_arm_after_event_count >= 0
                    and events >= args.second_arm_after_event_count
                )
                second_arm_address_ready = (
                    not second_arm_after_event_address
                    or address == second_arm_after_event_address
                )
                if (
                    not second_armed_after_event_breakpoints
                    and args.second_arm_after_event_breakpoint
                    and second_arm_count_ready
                    and second_arm_address_ready
                ):
                    for breakpoint in args.second_arm_after_event_breakpoint:
                        install_breakpoint_and_wait(child, breakpoint, args.debugger_timeout)
                    for command in args.second_arm_after_event_command:
                        issue_and_wait(child, command, args.debugger_timeout)
                    second_armed_after_event_breakpoints = True
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
    parser.add_argument("--startup-settle-seconds", type=float, default=3.0, help="Seconds to wait after the first visible H3MapEd window before clicking menus.")
    parser.add_argument("--defer-breakpoints-until-generate", action="store_true", help="Configure the New Map dialog before installing breakpoints; useful for startup-hot addresses.")
    parser.add_argument("--generate-wait-seconds", type=int, default=2)
    parser.add_argument("--debugger-timeout", type=int, default=60)
    parser.add_argument(
        "--breakpoint-timeout",
        type=int,
        default=0,
        help="Seconds to wait for each breakpoint stop; defaults to --debugger-timeout when 0.",
    )
    parser.add_argument("--map-size", choices=["small", "medium", "large", "xlarge"], default="small")
    parser.add_argument(
        "--level-count",
        type=int,
        choices=[1, 2],
        default=1,
        help="Select one or two map levels; H3MapEd defaults to two and the recovery driver defaults to one.",
    )
    parser.add_argument("--human-computer-down", type=int, default=-1, help="Select the Human/Computer player-count combo by Down-key count; -1 leaves it unchanged.")
    parser.add_argument("--computer-only-down", type=int, default=-1, help="Select the Computer-only player-count combo by Down-key count; -1 leaves it unchanged.")
    parser.add_argument("--human-computer-teams-down", type=int, default=-1, help="Select the Human/Computer team-count combo by Down-key count; -1 leaves it unchanged.")
    parser.add_argument("--computer-only-teams-down", type=int, default=-1, help="Select the Computer-only team-count combo by Down-key count; -1 leaves it unchanged.")
    parser.add_argument(
        "--monster-strength-down",
        type=int,
        default=-1,
        help="Select monster-strength radio option by index: 0 random, 1 weak, 2 normal, 3 strong; -1 leaves it unchanged.",
    )
    parser.add_argument(
        "--water-mode",
        choices=["leave", "random", "none", "normal", "islands"],
        default="leave",
        help="Select the Water content radio option; leave preserves the dialog default.",
    )
    parser.add_argument("--water-none", action="store_true", help="Compatibility alias for --water-mode none.")
    parser.add_argument("--seed", default="", help="Random-map seed to force when using --seed-control-mode=pe-patch.")
    parser.add_argument("--seed-control-mode", choices=["none", "pe-patch"], default="none")
    parser.add_argument("--lite", action="store_true", help="Only dump registers and stack at each breakpoint.")
    parser.add_argument("--no-info-reg", action="store_true", help="Skip `info reg` at each breakpoint; useful for high-volume stack-only traces.")
    parser.add_argument(
        "--info-reg-after-first-arm",
        action="store_true",
        help="Start `info reg` dumps only after the first delayed breakpoint set is armed.",
    )
    parser.add_argument("--lite-extra-command", default="", help="Optional extra winedbg command to run in lite mode.")
    parser.add_argument(
        "--dump-stack-arg0-words",
        type=int,
        default=0,
        help="Dump this many words from the pointer in the first stack argument at each stop.",
    )
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
    parser.add_argument(
        "--address-command-after-event-count",
        type=int,
        default=-1,
        help="Only run --address-command dumps after this many captured events; -1 runs them whenever the address matches.",
    )
    parser.add_argument(
        "--arm-after-event-count",
        type=int,
        default=-1,
        help="Install --arm-after-event-breakpoint breakpoints after this many captured events; -1 disables.",
    )
    parser.add_argument(
        "--arm-after-event-address",
        default="",
        help="Only arm after a captured event at this address. Can be combined with return/RNG filters.",
    )
    parser.add_argument(
        "--arm-after-event-return-address",
        default="",
        help="Only arm after the captured event stack return address matches this address.",
    )
    parser.add_argument(
        "--arm-after-event-rng-state",
        default="",
        help="Only arm after an address-command dump of $eax+0x14 yields this RNG state word.",
    )
    parser.add_argument(
        "--arm-after-event-breakpoint",
        action="append",
        default=[],
        help="Breakpoint address to install after --arm-after-event-count captured events. May be repeated.",
    )
    parser.add_argument(
        "--arm-after-event-delete-initial-breakpoints",
        action="store_true",
        help="Delete all initially installed breakpoints before installing the first delayed-arm set.",
    )
    parser.add_argument(
        "--arm-after-event-command",
        action="append",
        default=[],
        help="Additional winedbg command to run after the first delayed-arm breakpoints are installed. May be repeated.",
    )
    parser.add_argument(
        "--second-arm-after-event-count",
        type=int,
        default=-1,
        help="Install --second-arm-after-event-breakpoint breakpoints after this many captured events; -1 disables.",
    )
    parser.add_argument(
        "--second-arm-after-event-address",
        default="",
        help="Only perform the second arm when the captured event is at this address.",
    )
    parser.add_argument(
        "--second-arm-after-event-breakpoint",
        action="append",
        default=[],
        help="Breakpoint address to install for the second delayed arm. May be repeated.",
    )
    parser.add_argument(
        "--second-arm-after-event-command",
        action="append",
        default=[],
        help="Additional winedbg command to run after the second delayed-arm breakpoints are installed. May be repeated.",
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
            "--startup-settle-seconds",
            str(args.startup_settle_seconds),
            "--generate-wait-seconds",
            str(args.generate_wait_seconds),
            "--debugger-timeout",
            str(args.debugger_timeout),
            "--breakpoint-timeout",
            str(args.breakpoint_timeout),
            "--map-size",
            args.map_size,
            "--level-count",
            str(args.level_count),
            "--human-computer-down",
            str(args.human_computer_down),
            "--computer-only-down",
            str(args.computer_only_down),
            "--human-computer-teams-down",
            str(args.human_computer_teams_down),
            "--computer-only-teams-down",
            str(args.computer_only_teams_down),
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
        elif args.water_mode != "leave":
            command.extend(["--water-mode", args.water_mode])
        if args.defer_breakpoints_until_generate:
            command.append("--defer-breakpoints-until-generate")
        for extra_command in args.extra_command:
            command.extend(["--extra-command", extra_command])
        for pre_cont_command in args.pre_cont_command:
            command.extend(["--pre-cont-command", pre_cont_command])
        for address_command in args.address_command:
            command.extend(["--address-command", address_command])
        if args.address_command_after_event_count >= 0:
            command.extend(["--address-command-after-event-count", str(args.address_command_after_event_count)])
        if args.arm_after_event_count >= 0:
            command.extend(["--arm-after-event-count", str(args.arm_after_event_count)])
        if args.arm_after_event_address:
            command.extend(["--arm-after-event-address", args.arm_after_event_address])
        if args.arm_after_event_return_address:
            command.extend(["--arm-after-event-return-address", args.arm_after_event_return_address])
        if args.arm_after_event_rng_state:
            command.extend(["--arm-after-event-rng-state", args.arm_after_event_rng_state])
        for breakpoint in args.arm_after_event_breakpoint:
            command.extend(["--arm-after-event-breakpoint", breakpoint])
        if args.arm_after_event_delete_initial_breakpoints:
            command.append("--arm-after-event-delete-initial-breakpoints")
        for arm_command in args.arm_after_event_command:
            command.extend(["--arm-after-event-command", arm_command])
        if args.second_arm_after_event_count >= 0:
            command.extend(["--second-arm-after-event-count", str(args.second_arm_after_event_count)])
        if args.second_arm_after_event_address:
            command.extend(["--second-arm-after-event-address", args.second_arm_after_event_address])
        for breakpoint in args.second_arm_after_event_breakpoint:
            command.extend(["--second-arm-after-event-breakpoint", breakpoint])
        for arm_command in args.second_arm_after_event_command:
            command.extend(["--second-arm-after-event-command", arm_command])
        if args.lite:
            command.append("--lite")
        if args.no_info_reg:
            command.append("--no-info-reg")
        if args.info_reg_after_first_arm:
            command.append("--info-reg-after-first-arm")
        if args.lite_extra_command:
            command.extend(["--lite-extra-command", args.lite_extra_command])
        if args.dump_stack_arg0_words > 0:
            command.extend(["--dump-stack-arg0-words", str(args.dump_stack_arg0_words)])
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
    ledger["dump_stack_arg0_words"] = args.dump_stack_arg0_words
    ledger["pre_cont_command"] = args.pre_cont_command
    ledger["address_command"] = args.address_command
    ledger["address_command_after_event_count"] = args.address_command_after_event_count
    ledger["arm_after_event_count"] = args.arm_after_event_count
    ledger["arm_after_event_address"] = args.arm_after_event_address
    ledger["arm_after_event_return_address"] = args.arm_after_event_return_address
    ledger["arm_after_event_rng_state"] = args.arm_after_event_rng_state
    ledger["arm_after_event_breakpoint"] = args.arm_after_event_breakpoint
    ledger["arm_after_event_delete_initial_breakpoints"] = bool(
        args.arm_after_event_delete_initial_breakpoints
    )
    ledger["info_reg_after_first_arm"] = bool(args.info_reg_after_first_arm)
    ledger["arm_after_event_command"] = args.arm_after_event_command
    ledger["second_arm_after_event_count"] = args.second_arm_after_event_count
    ledger["second_arm_after_event_address"] = args.second_arm_after_event_address
    ledger["second_arm_after_event_breakpoint"] = args.second_arm_after_event_breakpoint
    ledger["second_arm_after_event_command"] = args.second_arm_after_event_command
    ledger["ui_options"] = {
        "map_size": args.map_size,
        "level_count": args.level_count,
        "human_computer_down": args.human_computer_down,
        "computer_only_down": args.computer_only_down,
        "human_computer_teams_down": args.human_computer_teams_down,
        "computer_only_teams_down": args.computer_only_teams_down,
        "water_none": bool(args.water_none),
        "water_mode": "none" if args.water_none else args.water_mode,
        "monster_strength_down": args.monster_strength_down,
        "monster_strength_order": ["random", "weak", "normal", "strong"],
        "startup_settle_seconds": args.startup_settle_seconds,
        "generate_wait_seconds": args.generate_wait_seconds,
        "defer_breakpoints_until_generate": bool(args.defer_breakpoints_until_generate),
    }
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
