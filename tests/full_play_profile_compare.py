#!/usr/bin/env python3
"""Compare complete state captures and identity-matched profile event prefixes."""
from __future__ import annotations

import argparse
import json
from pathlib import Path


def event_identity(row: dict) -> dict:
    """Select action identity, not nested timers/cache diagnostics, for timing pairs.

    Complete saved session trees are checked separately without this projection.
    In particular move.raw_profile can retain the initial uptime-ID launch save;
    it is diagnostic history, not the identity of the current movement command.
    """
    metadata = row["metadata"]
    event = row["event"]
    if event in ["battle_refresh", "battle_ready"]:
        identity = metadata
    elif event == "town_refresh":
        identity = {key: metadata[key] for key in ["active_tab", "first_render", "town_id", "town_owner", "town_placement_id"]}
    elif event == "end_turn":
        identity = {key: metadata[key] for key in ["resolved", "result_ok", "scenario_status"]}
    elif event == "move":
        movement = metadata["overworld_profile"]
        identity = {key: movement[key] for key in ["command_type", "hero_before", "hero_after", "raw_target", "selected_before", "selected_target"]}
        identity["execution"] = movement["route_execution"].get("last_execution", {})
        identity["result"] = movement["movement_rules"].get("details", {})
    else:
        raise ValueError("unhandled identity: " + event)
    return {"session": row["session"], "action": identity}


def compare(control: Path, current: Path, expected_states: int) -> dict:
    references = sorted((control / "live").glob("*.session.json"))
    states = {p.name: (current / "live" / p.name).exists() and json.loads(p.read_text()) == json.loads((current / "live" / p.name).read_text()) for p in references}
    profile_suffix = "data/godot/app_userdata/heroes-like/debug/heroes_profile.jsonl"
    before = [json.loads(line) for line in (control / profile_suffix).read_text().splitlines() if line.strip()]
    after = [json.loads(line) for line in (current / profile_suffix).read_text().splitlines() if line.strip()]
    timings = []
    for event in ["battle_refresh", "battle_ready", "town_refresh", "end_turn", "move"]:
        a = [r for r in before if r.get("event") == event]
        b = [r for r in after if r.get("event") == event][:len(a)]
        matched = bool(a) and len(a) == len(b) and all(event_identity(x) == event_identity(y) for x, y in zip(a, b))
        old = sum(r["total_ms"] for r in a)
        new = sum(r["total_ms"] for r in b)
        timings.append({"event": event, "matched_event_identity": matched, "count": len(a), "control_ms": old, "current_ms": new, "ratio": new / old if old else None})
    control_live = json.loads((control / "live/live_validation_report.json").read_text())
    current_live = json.loads((current / "live/live_validation_report.json").read_text())
    errors = [line for line in (current / "runtime.log").read_text().splitlines() if line.startswith(("ERROR:", "SCRIPT ERROR:")) or "leaked" in line]
    return {"ok": len(states) == expected_states and expected_states > 0 and all(states.values()) and all(row["matched_event_identity"] for row in timings) and bool(current_live.get("ok")) and not errors,
            "control": str(control), "current": str(current), "control_completed": bool(control_live.get("ok")), "control_errors": control_live.get("errors", []), "current_completed": bool(current_live.get("ok")), "current_runtime_errors": errors, "states": states, "timings": timings,
            "boundary": "All reference session trees are compared without omitted fields. Timings cover only equal ordered event identities; a partial control is not a completed playthrough and its total duration is not compared."}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("control", type=Path)
    parser.add_argument("current", type=Path)
    parser.add_argument("--expected-states", required=True, type=int)
    args = parser.parse_args()
    if args.control.resolve() == args.current.resolve():
        parser.error("a run cannot be its own control")
    report = compare(args.control, args.current, args.expected_states)
    output = args.current / "matched_control_report.json"
    if output.exists():
        parser.error("comparison evidence already exists")
    output.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({k: v for k, v in report.items() if k != "control_errors"}))
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
