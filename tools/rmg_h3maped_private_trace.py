#!/usr/bin/env python3
"""Capture H3MapEd private generated-cell state through a GUI-driven winedbg trace.

This is a Python-owned wrapper around the known-working window-relative H3MapEd
driver. It exists to make the private-state capture reproducible without moving
RMG reporting/export logic into GDScript.
"""

from __future__ import annotations

import argparse
import json
import os
import shlex
import subprocess
import sys
import textwrap
from pathlib import Path


DEFAULT_RUNTIME = Path(".artifacts/rmg_20seed_2p_small_h3maped_20260605/small_2p_seed_58_manual20/runtime")
DEFAULT_OUTPUT_MAP = "h3maped_small_2p_seed_58_manual20.h3m"
DEFAULT_DUMP_COMMAND = "x/15552x *(int*)($esi+0x14)"


def q(value: str | Path) -> str:
    return shlex.quote(str(value))


def build_driver_script(args: argparse.Namespace, repo_root: Path, log_path: Path, screen_dir: Path, output_map_path: Path) -> str:
    dump_lines = [
        f"break *{args.breakpoint}",
        "cont",
        "info reg",
        "x/32x $esi",
        "x/32x $esi+0x14",
        args.dump_command,
        "q",
    ]
    debugger_input = "".join(f"  printf {q(line + chr(10))}\n" for line in dump_lines)
    runtime_output = args.h3maped_runtime / args.output_map_name
    root_output = Path("/") / args.output_map_name
    return textwrap.dedent(
        f"""\
        #!/usr/bin/env bash
        set -euo pipefail

        ROOT={q(repo_root)}
        RUNTIME={q(args.h3maped_runtime)}
        OUT={q(output_map_path)}
        LOG={q(log_path)}
        SCREEN_DIR={q(screen_dir)}
        OUTPUT_MAP_NAME={q(args.output_map_name)}

        export WINEPREFIX={q(args.wineprefix)}
        export WINEARCH=win32
        mkdir -p "$SCREEN_DIR"
        rm -f "$LOG" "$OUT" {q(runtime_output)} {q(root_output)}
        cd "$RUNTIME"

        screen() {{
          scrot "$SCREEN_DIR/$1.png" || true
        }}

        wait_for_main() {{
          for _ in $(seq 1 80); do
            if xdotool search --onlyvisible --name 'Heroes of Might' >/tmp/h3maped_window_ids 2>/dev/null && [[ -s /tmp/h3maped_window_ids ]]; then
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
        screen 03b_player_counts

        xdotool mousemove 351 553 click 1
        sleep 0.1
        screen 04_water_none
        xdotool mousemove 494 214 click 1
        sleep 12
        screen 05_generated

        xdotool key Alt+f
        sleep 0.2
        xdotool key a
        sleep 0.8
        screen 06_save_as
        xdotool mousemove 469 466 click 1
        xdotool key End
        for _ in $(seq 1 80); do
          xdotool key BackSpace
        done
        xdotool type --clearmodifiers "$OUTPUT_MAP_NAME"
        screen 07_filename
        xdotool mousemove 545 371 click 1
        sleep 2
        xdotool key Alt+y || true
        sleep 0.5
        screen 08_after_save

        if [[ ! -f "$OUT" ]]; then
          candidate="$(find "$ROOT/.artifacts" "$WINEPREFIX" -type f -name "$OUTPUT_MAP_NAME" 2>/dev/null | head -n 1 || true)"
          if [[ -f {q(runtime_output)} ]]; then
            cp {q(runtime_output)} "$OUT"
          elif [[ -f {q(root_output)} ]]; then
            mv {q(root_output)} "$OUT"
          elif [[ -n "$candidate" && -f "$candidate" ]]; then
            cp "$candidate" "$OUT"
          fi
        fi

        grep -q 'Stopped on breakpoint' "$LOG"
        grep -q "$OUTPUT_MAP_NAME" "$LOG" || true
        test -f "$OUT"
        """
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd(), help="Repository root.")
    parser.add_argument("--h3maped-runtime", type=Path, default=DEFAULT_RUNTIME, help="Directory containing h3maped.exe and runtime files.")
    parser.add_argument("--out-dir", type=Path, default=Path(".artifacts/rmg_private_trace_seed58_20260606"), help="Artifact output directory.")
    parser.add_argument("--output-map-name", default=DEFAULT_OUTPUT_MAP, help="Saved H3M filename typed into H3MapEd.")
    parser.add_argument("--breakpoint", default="0x4a4c8e", help="winedbg breakpoint address.")
    parser.add_argument("--dump-command", default=DEFAULT_DUMP_COMMAND, help="winedbg memory dump command.")
    parser.add_argument("--display-number", type=int, default=106, help="Xvfb display number.")
    parser.add_argument("--screen-size", default="1024x768x24", help="Xvfb screen geometry.")
    parser.add_argument("--wineprefix", type=Path, default=Path(".artifacts/wine/h3maped"), help="Wine prefix path.")
    parser.add_argument("--skip-existing", action="store_true", help="Only validate existing log/map artifacts.")
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    repo_root = args.repo_root.resolve()
    args.h3maped_runtime = (repo_root / args.h3maped_runtime).resolve() if not args.h3maped_runtime.is_absolute() else args.h3maped_runtime.resolve()
    args.out_dir = (repo_root / args.out_dir).resolve() if not args.out_dir.is_absolute() else args.out_dir.resolve()
    args.wineprefix = (repo_root / args.wineprefix).resolve() if not args.wineprefix.is_absolute() else args.wineprefix.resolve()

    args.out_dir.mkdir(parents=True, exist_ok=True)
    screen_dir = args.out_dir / "winedbg_window_relative_screenshots"
    log_path = args.out_dir / f"winedbg_{args.breakpoint}_full_cell_dump_window_relative.log"
    output_map_path = args.out_dir / args.output_map_name
    driver_path = args.out_dir / f"drive_h3maped_winedbg_{args.breakpoint}.sh"
    manifest_path = args.out_dir / f"trace_manifest_{args.breakpoint}.json"

    if args.skip_existing:
        runtime_output_path = args.h3maped_runtime.parent / args.output_map_name
        runtime_local_output_path = args.h3maped_runtime / args.output_map_name
        fallback_output_path = next((path for path in (output_map_path, runtime_output_path, runtime_local_output_path) if path.exists()), output_map_path)
        ok = log_path.exists() and "Stopped on breakpoint" in log_path.read_text(errors="replace") and fallback_output_path.exists()
        manifest = {
            "schema_id": "rmg_h3maped_private_trace_v1",
            "status": "existing_trace_valid" if ok else "existing_trace_missing_or_invalid",
            "log_path": str(log_path),
            "output_map_path": str(fallback_output_path),
            "driver_path": str(driver_path),
        }
        manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        print(f"RMG_H3MAPED_PRIVATE_TRACE status={manifest['status']} log={log_path} map={fallback_output_path}")
        return 0 if ok else 1

    if not (args.h3maped_runtime / "h3maped.exe").exists():
        print(f"RMG_H3MAPED_PRIVATE_TRACE status=fail missing_h3maped_runtime={args.h3maped_runtime}", file=sys.stderr)
        return 1

    driver_path.write_text(build_driver_script(args, repo_root, log_path, screen_dir, output_map_path), encoding="utf-8")
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
    log_text = log_path.read_text(errors="replace") if log_path.exists() else ""
    ok = completed.returncode == 0 and "Stopped on breakpoint" in log_text and output_map_path.exists()
    manifest = {
        "schema_id": "rmg_h3maped_private_trace_v1",
        "status": "trace_captured" if ok else "trace_failed",
        "returncode": completed.returncode,
        "breakpoint": args.breakpoint,
        "dump_command": args.dump_command,
        "driver_path": str(driver_path),
        "log_path": str(log_path),
        "output_map_path": str(output_map_path),
        "screen_dir": str(screen_dir),
        "runtime": str(args.h3maped_runtime),
        "wineprefix": str(args.wineprefix),
    }
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_PRIVATE_TRACE status={manifest['status']} log={log_path} map={output_map_path}")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
