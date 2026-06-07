#!/usr/bin/env python3
"""Drive and parse H3MapEd RMG recovery traces.

The trace target is an event ledger: breakpoint address, registers, caller
context, and generated-cell words. This tool intentionally does not compare
final maps or mutate native RMG behavior.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shlex
import subprocess
import textwrap
from pathlib import Path
from typing import Any


DEFAULT_RUNTIME = Path(".artifacts/rmg_20seed_2p_small_h3maped_20260605/small_2p_seed_58_manual20/runtime")
DEFAULT_OUT_DIR = Path(".artifacts/rmg_recovery/seed58_trace")
DEFAULT_BREAKPOINTS = ["0x499ea3", "0x49a932", "0x49aa63", "0x49abd6", "0x4aa3e9", "0x4a4c8e"]
DWORD_LINE_RE = re.compile(r"(?:^|>)\s*(?:0x)?([0-9a-fA-F]+)(?:\s+[^:]+)?:\s+(.+)$")
STOP_RE = re.compile(
    r"Stopped on (?P<kind>[A-Za-z _-]*(?:breakpoint|watchpoint))\s+"
    r"(?P<index>\d+)\s+at\s+0x(?P<address>[0-9a-fA-F]+)",
    re.IGNORECASE,
)
REGISTER_RE = re.compile(r"\b(eax|ebx|ecx|edx|esi|edi|ebp|esp|eip)[:=]([0-9a-fA-F]{8})\b", re.IGNORECASE)
HEX_WORD_RE = re.compile(r"\b[0-9a-fA-F]{1,8}\b")
ANSI_RE = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]|\x1b\][^\a]*(?:\a|\x1b\\)")


def q(value: str | Path) -> str:
    return shlex.quote(str(value))


def parse_winedbg_log(path: Path, generated_cell_base: int | None = None, generated_cell_stride: int = 0x30) -> dict[str, Any]:
    text = path.read_text(errors="replace") if path.exists() else ""
    events: list[dict[str, Any]] = []
    current: dict[str, Any] | None = None
    for line in text.splitlines():
        line = ANSI_RE.sub("", line).replace("\r", "")
        stop = STOP_RE.search(line)
        if stop:
            current = {
                "breakpoint_index": int(stop.group("index")),
                "stop_kind": " ".join(stop.group("kind").lower().split()),
                "address": "0x" + stop.group("address").lower(),
                "registers": {},
                "memory_lines": [],
            }
            events.append(current)
            continue
        if current is None:
            continue
        for reg, value in REGISTER_RE.findall(line):
            current["registers"][reg.lower()] = int(value, 16)
        mem = DWORD_LINE_RE.search(line)
        if mem:
            words = [int(token, 16) & 0xFFFFFFFF for token in HEX_WORD_RE.findall(mem.group(2))]
            current["memory_lines"].append({"address": int(mem.group(1), 16), "words": words})
    for event in events:
        memory_lines = event.get("memory_lines", [])
        registers = event.get("registers", {})
        derived: dict[str, Any] = {}
        if memory_lines and memory_lines[0].get("words"):
            derived["return_address"] = "0x%08x" % int(memory_lines[0]["words"][0])
        if generated_cell_base is not None and generated_cell_stride > 0:
            for register in ("ecx", "esi", "edi", "ebx"):
                value = registers.get(register)
                if not isinstance(value, int):
                    continue
                delta = value - generated_cell_base
                if delta >= 0 and delta % generated_cell_stride == 0:
                    derived[f"{register}_generated_cell_flat"] = delta // generated_cell_stride
        event["derived"] = derived
    return {
        "schema_id": "h3maped_winedbg_trace_ledger_v1",
        "log_path": str(path),
        "generated_cell_base": generated_cell_base,
        "generated_cell_stride": generated_cell_stride,
        "event_count": len(events),
        "events": events,
    }


def build_debugger_input(args: argparse.Namespace) -> str:
    lines: list[str] = []
    for address in args.breakpoints:
        lines.append(f"break *{address}")
    for _ in range(args.max_events):
        lines.extend(["cont", "info reg", "x/8x $esp"])
        if args.lite and args.lite_extra_command:
            lines.append(args.lite_extra_command)
        if not args.lite:
            lines.extend(["x/12x $ecx", "x/12x $esi", args.dump_command])
    lines.append("q")
    return "".join(f"  printf {q(line + chr(10))}\n" for line in lines)


def build_driver(args: argparse.Namespace, repo_root: Path, log_path: Path, screen_dir: Path) -> str:
    debugger_input = build_debugger_input(args)
    return textwrap.dedent(
        f"""\
        #!/usr/bin/env bash
        set -euo pipefail

        ROOT={q(repo_root)}
        RUNTIME={q(args.h3maped_runtime)}
        LOG={q(log_path)}
        SCREEN_DIR={q(screen_dir)}
        OUTPUT_MAP_NAME={q(args.output_map_name)}

        export WINEPREFIX={q(args.wineprefix)}
        export WINEARCH=win32
        mkdir -p "$SCREEN_DIR"
        rm -f "$LOG" "$RUNTIME/$OUTPUT_MAP_NAME" "/$OUTPUT_MAP_NAME"
        cd "$RUNTIME"

        screen() {{
          scrot "$SCREEN_DIR/$1.png" || true
        }}

        wait_for_main() {{
          for _ in $(seq 1 80); do
            if xdotool search --onlyvisible --name 'Heroes of Might' >/tmp/h3maped_recovery_window_ids 2>/dev/null && [[ -s /tmp/h3maped_recovery_window_ids ]]; then
              return 0
            fi
            sleep 0.25
          done
          return 1
        }}

        wineboot -u >/dev/null 2>&1 || true
        (
        {debugger_input.rstrip()}
        ) | winedbg ./h3maped.exe > "$LOG" 2>&1 &
        H3MAPED_PID=$!
        cleanup() {{
          kill "$H3MAPED_PID" >/dev/null 2>&1 || true
          wineserver -k >/dev/null 2>&1 || true
        }}
        trap cleanup EXIT

        wait_for_main
        sleep 2
        screen 01_main
        xdotool key Alt+f
        sleep 0.2
        xdotool key n
        sleep 1
        screen 02_new_map

        xdotool mousemove 244 318 click 1
        sleep 0.1
        xdotool mousemove 231 369 click 1
        sleep 0.1
        xdotool mousemove 231 388 click 1
        sleep 0.3
        screen 03_random_expanded

        xdotool mousemove 432 441 click 1
        sleep 0.1
        xdotool key Down
        xdotool key Down
        xdotool key Return
        sleep 0.1
        xdotool mousemove 648 441 click 1
        sleep 0.1
        xdotool key Down
        xdotool key Return
        sleep 0.1
        xdotool mousemove 351 553 click 1
        sleep 0.1
        screen 04_configured
        xdotool mousemove 494 214 click 1
        sleep {int(args.generate_wait_seconds)}
        screen 05_after_generate
        grep -q 'Stopped on breakpoint' "$LOG"
        """
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--h3maped-runtime", type=Path, default=DEFAULT_RUNTIME)
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR)
    parser.add_argument("--breakpoints", nargs="+", default=DEFAULT_BREAKPOINTS)
    parser.add_argument("--max-events", type=int, default=64)
    parser.add_argument("--dump-command", default="x/16x *(int*)($esi+0x14)")
    parser.add_argument("--lite", action="store_true", help="Only dump registers and stack at each breakpoint.")
    parser.add_argument("--lite-extra-command", default="", help="Optional extra winedbg command to run in lite mode.")
    parser.add_argument("--generated-cell-base", default="", help="Optional hex generated-cell base pointer for flat-index derivation.")
    parser.add_argument("--generated-cell-stride", type=int, default=0x30)
    parser.add_argument("--display-number", type=int, default=107)
    parser.add_argument("--screen-size", default="1024x768x24")
    parser.add_argument("--wineprefix", type=Path, default=Path(".artifacts/wine/h3maped"))
    parser.add_argument("--output-map-name", default="h3maped_recovery_trace_seed58.h3m")
    parser.add_argument("--generate-wait-seconds", type=int, default=12)
    parser.add_argument("--parse-only", type=Path, default=None)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    repo_root = args.repo_root.resolve()
    args.h3maped_runtime = (repo_root / args.h3maped_runtime).resolve() if not args.h3maped_runtime.is_absolute() else args.h3maped_runtime.resolve()
    args.out_dir = (repo_root / args.out_dir).resolve() if not args.out_dir.is_absolute() else args.out_dir.resolve()
    args.wineprefix = (repo_root / args.wineprefix).resolve() if not args.wineprefix.is_absolute() else args.wineprefix.resolve()
    args.out_dir.mkdir(parents=True, exist_ok=True)
    log_path = args.parse_only.resolve() if args.parse_only else args.out_dir / "winedbg_recovery_trace.log"
    ledger_path = args.out_dir / "winedbg_recovery_trace_ledger.json"

    if not args.parse_only:
        if not (args.h3maped_runtime / "h3maped.exe").exists():
            raise SystemExit(f"missing h3maped.exe runtime: {args.h3maped_runtime}")
        screen_dir = args.out_dir / "screenshots"
        driver_path = args.out_dir / "drive_h3maped_recovery_trace.sh"
        driver_path.write_text(build_driver(args, repo_root, log_path, screen_dir), encoding="utf-8")
        driver_path.chmod(0o755)
        command = [
            "xvfb-run",
            "-n",
            str(args.display_number),
            "-s",
            f"-screen 0 {args.screen_size} -ac +extension GLX +render -noreset",
            "bash",
            "--noprofile",
            "--norc",
            str(driver_path),
        ]
        completed = subprocess.run(command, cwd=repo_root, env=os.environ.copy(), text=True)
        if completed.returncode != 0:
            print(f"RMG_H3MAPED_RECOVERY_TRACE status=trace_failed returncode={completed.returncode} log={log_path}")
            return completed.returncode

    generated_cell_base = int(args.generated_cell_base, 0) if args.generated_cell_base else None
    ledger = parse_winedbg_log(log_path, generated_cell_base=generated_cell_base, generated_cell_stride=args.generated_cell_stride)
    ledger["breakpoints"] = args.breakpoints
    ledger["max_events"] = args.max_events
    ledger["dump_command"] = args.dump_command
    ledger["lite"] = bool(args.lite)
    ledger["lite_extra_command"] = args.lite_extra_command
    ledger_path.write_text(json.dumps(ledger, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    status = "pass" if ledger["event_count"] else "no_events"
    print(f"RMG_H3MAPED_RECOVERY_TRACE status={status} events={ledger['event_count']} ledger={ledger_path}")
    return 0 if ledger["event_count"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
