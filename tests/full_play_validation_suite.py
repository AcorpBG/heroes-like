#!/usr/bin/env python3
"""Run affected existing runtime regressions serially with isolated save storage."""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
from time import monotonic

from full_play_runtime_profile import ROOT, OUTPUT

SCENES = [
    "overworld_end_turn_confirmation_runtime_report",
    "battle_quick_resolve_runtime_report",
    "battle_withdrawal_confirmation_runtime_report",
    "post_battle_report_runtime_report",
    "battle_deterministic_rng_state_report",
    "battle_controller_board_navigation_smoke",
    "overworld_gameplay_movement_input_ownership_regression",
    "overworld_full_route_movement_regression",
    "fog_of_war_homm_style_regression",
    "save_transactional_commit_regression",
    "save_summary_deferred_payload_report",
    "application_battle_entry_autosave_failure_regression",
    "battle_resolution_autosave_failure_route_safety_regression",
    "overworld_end_turn_autosave_failure_regression",
    "application_safe_close_autosave_regression",
    "campaign_completion_persistence_atomicity_regression",
    "campaign_replay_progress_preservation_regression",
    "campaign_progression_semantic_storage_fail_closed_regression",
    "town_development_save_resume_report",
    "runtime_audio_cache_fallback_report",
    "music_audio_runtime_report",
    "overworld_ambient_audio_runtime_report",
    "settings_transactional_persistence_regression",
    "generated_large_town_explicit_save_surface_regression",
    "town_screen_layout_and_dialog_controls_report",
]
RENDERED_SCENES = ["active_play_keyboard_focus_smoke", "custom_mouse_cursor_runtime_report"]
# These existing tests deliberately make the authoritative writer fail and
# assert rollback/retry/route safety. Only their exact domain issue is expected;
# a failed test marker, any script error or any other native error still fails.
EXPECTED_INJECTED_ISSUES = {
    "application_battle_entry_autosave_failure_regression": "ERROR: battle_entry_autosave_failed:",
    "battle_resolution_autosave_failure_route_safety_regression": "ERROR: battle_resolution_autosave_failed:",
    "overworld_end_turn_autosave_failure_regression": "ERROR: end_turn_autosave_failed:",
    "application_safe_close_autosave_regression": "ERROR: safe_quit_autosave_failed:",
    "settings_transactional_persistence_regression": "ERROR: ConfigFile parse error at user://config/settings.cfg:0: Unexpected EOF while parsing simple tag.",
}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--label", required=True)
    parser.add_argument("--only", nargs="+", choices=SCENES + RENDERED_SCENES)
    parser.add_argument("--rendered", action="store_true")
    parser.add_argument("--accessibility", choices=["auto", "disabled"], default="auto", help="Record explicitly if isolating an engine AT-SPI backend failure; production defaults never change.")
    parser.add_argument("--timeout", type=int, default=900, help="Per-case seconds; full catalog/scene matrices exceed four minutes.")
    args = parser.parse_args()
    if not args.label or any(c not in "abcdefghijklmnopqrstuvwxyz0123456789_-" for c in args.label):
        parser.error("invalid label")
    out = OUTPUT / args.label
    out.mkdir(parents=True, exist_ok=False)
    rows = []
    selected = args.only or (RENDERED_SCENES if args.rendered else SCENES)
    for name in selected:
        source = (ROOT / "tests" / (name + ".gd")).read_text()
        match = re.search(r'const REPORT_ID\s*:?=\s*"([^"]+)"', source)
        explicit_markers = {"town_development_save_resume_report": "TOWN_DEVELOPMENT_SAVE_RESUME_REPORT", "town_screen_layout_and_dialog_controls_report": "TOWN_SCREEN_LAYOUT_AND_DIALOG_CONTROLS_REPORT"}
        marker = match.group(1) if match else explicit_markers.get(name, "")
        if not marker or marker not in source:
            raise ValueError("No authoritative completion marker for " + name)
        env = dict(os.environ, XDG_DATA_HOME=str(out / (name + "_data")))
        started = monotonic()
        command = ["godot4", "--path", str(ROOT), "--audio-driver", "Dummy", "--accessibility", args.accessibility, "res://tests/" + name + ".tscn"]
        command = ["dbus-run-session", "--", "xvfb-run", "-a", "-s", "-screen 0 2200x1200x24"] + command if args.rendered else command + ["--headless"]
        with (out / (name + ".log")).open("w") as log:
            process = subprocess.run(["timeout", str(args.timeout) + "s"] + command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=args.timeout + 20)
        lines = (out / (name + ".log")).read_text().splitlines()
        errors = [line for line in lines if line.startswith(("ERROR:", "SCRIPT ERROR:")) or "leaked" in line]
        injected_prefix = EXPECTED_INJECTED_ISSUES.get(name)
        expected_issues = [line for line in errors if injected_prefix and line.startswith(injected_prefix)]
        errors = [line for line in errors if line not in expected_issues]
        completed = False
        for line in lines:
            if line == marker + " PASS":
                completed = True
            elif line.startswith(marker + " {"):
                completed = bool(json.loads(line[len(marker) + 1:]).get("ok", False))
        row = {"test": name, "ok": process.returncode == 0 and completed and not errors, "returncode": process.returncode, "completion_marker": completed, "runtime_errors": errors, "expected_injected_issues": expected_issues, "wall_s": round(monotonic() - started, 3)}
        rows.append(row)
        print(json.dumps(row), flush=True)
        (out / "report.json").write_text(json.dumps({"ok": len(rows) == len(selected) and all(r["ok"] for r in rows), "completed": len(rows), "requested": len(selected), "rendered": args.rendered, "accessibility": args.accessibility, "rows": rows}, indent=2) + "\n")
    return 0 if all(row["ok"] for row in rows) else 1


if __name__ == "__main__":
    raise SystemExit(main())
