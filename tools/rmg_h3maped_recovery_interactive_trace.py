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
import shlex
import subprocess
import sys
import time
from pathlib import Path

import pexpect

from rmg_h3maped_recovery_trace import (
    DEFAULT_RUNTIME,
    parse_winedbg_log,
)


DEFAULT_OUT_DIR = Path(".artifacts/rmg_recovery/seed58_interactive_trace")
STOP_RE = r"Stopped on breakpoint\s+\d+\s+at\s+0x([0-9a-fA-F]+)"
PROMPT_RE = r"Wine-dbg>"


def q(value: str | Path) -> str:
    return shlex.quote(str(value))


def normalize_address(value: str) -> str:
    return "0x%08x" % int(value, 0)


def run_xdotool(args: list[str], *, timeout: float = 10.0) -> None:
    subprocess.run(["xdotool", *args], check=True, timeout=timeout)


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


def drive_h3maped_ui(generate_wait_seconds: int) -> None:
    wait_for_main_window()
    time.sleep(2)
    run_xdotool(["key", "Alt+f"])
    time.sleep(0.2)
    run_xdotool(["key", "n"])
    time.sleep(1)

    run_xdotool(["mousemove", "244", "318", "click", "1"])
    time.sleep(0.1)
    run_xdotool(["mousemove", "231", "369", "click", "1"])
    time.sleep(0.1)
    run_xdotool(["mousemove", "231", "388", "click", "1"])
    time.sleep(0.3)

    run_xdotool(["mousemove", "432", "441", "click", "1"])
    time.sleep(0.1)
    run_xdotool(["key", "Down"])
    run_xdotool(["key", "Down"])
    run_xdotool(["key", "Return"])
    time.sleep(0.1)
    run_xdotool(["mousemove", "648", "441", "click", "1"])
    time.sleep(0.1)
    run_xdotool(["key", "Down"])
    run_xdotool(["key", "Return"])
    time.sleep(0.1)
    run_xdotool(["mousemove", "351", "553", "click", "1"])
    time.sleep(0.1)
    run_xdotool(["mousemove", "494", "214", "click", "1"])
    time.sleep(generate_wait_seconds)


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

            child.send("cont\r")
            drive_h3maped_ui(args.generate_wait_seconds)

            events = 0
            stop_after = normalize_address(args.stop_after) if args.stop_after else ""
            while events < args.max_events:
                index = child.expect([STOP_RE, pexpect.EOF, pexpect.TIMEOUT], timeout=args.debugger_timeout)
                if index == 1:
                    break
                if index == 2:
                    raise TimeoutError("timed out waiting for next winedbg breakpoint")
                address = normalize_address("0x" + child.match.group(1))
                events += 1
                child.expect(PROMPT_RE, timeout=args.debugger_timeout)
                commands = ["info reg", "x/8x $esp"]
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
    parser.add_argument("--lite", action="store_true", help="Only dump registers and stack at each breakpoint.")
    parser.add_argument("--inside-xvfb", action="store_true")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    repo_root = args.repo_root.resolve()
    args.h3maped_runtime = (repo_root / args.h3maped_runtime).resolve() if not args.h3maped_runtime.is_absolute() else args.h3maped_runtime.resolve()
    args.out_dir = (repo_root / args.out_dir).resolve() if not args.out_dir.is_absolute() else args.out_dir.resolve()
    args.wineprefix = (repo_root / args.wineprefix).resolve() if not args.wineprefix.is_absolute() else args.wineprefix.resolve()
    args.out_dir.mkdir(parents=True, exist_ok=True)

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
            "--breakpoints",
            *args.breakpoints,
        ]
        if args.lite:
            command.append("--lite")
        if args.stop_after:
            command.extend(["--stop-after", args.stop_after])
        completed = subprocess.run(command, cwd=repo_root, text=True)
        if completed.returncode != 0:
            return completed.returncode
    else:
        run_inside_xvfb(args, repo_root, log_path)
        return 0

    generated_cell_base = int(args.generated_cell_base, 0) if args.generated_cell_base else None
    ledger = parse_winedbg_log(log_path, generated_cell_base=generated_cell_base, generated_cell_stride=args.generated_cell_stride)
    ledger["breakpoints"] = args.breakpoints
    ledger["stop_after"] = args.stop_after
    ledger["max_events"] = args.max_events
    ledger["dump_command"] = args.dump_command
    ledger_path.write_text(json.dumps(ledger, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    status = "pass" if ledger["event_count"] else "no_events"
    print(f"RMG_H3MAPED_INTERACTIVE_TRACE status={status} events={ledger['event_count']} ledger={ledger_path}")
    return 0 if ledger["event_count"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
