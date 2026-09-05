#!/usr/bin/env python3
"""Verify End Turn warning reads preserve tied AI memory and stale-state safety."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile

from full_play_runtime_profile import ROOT, OUTPUT

SCRIPT = r'''
extends Node
const SessionStore = preload("res://scripts/core/SessionStateStore.gd")
func _ready() -> void:
	call_deferred("run")
func write(id: String, session) -> void:
	var f := FileAccess.open(OS.get_environment("HEROES_END_TURN_PROBE_OUT").path_join(id + ".json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(session.to_dict(), "", false))
	f.close()
func run() -> void:
	var session
	var fixture := OS.get_environment("HEROES_END_TURN_PROBE_FIXTURE")
	if fixture != "":
		var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fixture))
		session = SessionStore.SessionData.new()
		session.from_dict(payload)
	else:
		session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
		var records := []
		for index in range(20):
			records.append({"target_kind": "resource", "target_id": "scouting_tie_%02d" % index, "target_label": "Wood Wagon", "scouted_day": session.day, "expires_day": session.day + 3, "x": index % 9, "y": index % 5})
		session.overworld.enemy_states[0]["known_world_memory"] = {"scouted_targets": records}
	session = SessionState.set_active_session(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	for frame in range(6):
		await get_tree().process_frame
	write("before", session)
	var before: Dictionary = session.to_dict()
	var signature_before: String = shell._end_turn_session_state_signature()
	var first: Dictionary = shell._request_end_turn(false)
	write("requested", session)
	var pending: Dictionary = shell._pending_end_turn_confirmation
	var signature_after: String = shell._end_turn_session_state_signature()
	var stale: Array = shell._stale_end_turn_request_fields(pending)
	var fields := {}
	for key in session.overworld:
		fields[key] = hash(session.overworld[key])
	var warning: Dictionary = shell._current_end_turn_warning()
	var changed_hashes := []
	for key in session.overworld:
		if fields.get(key) != hash(session.overworld[key]):
			changed_hashes.append(key)
	write("inspected", session)
	var unchanged: bool = before == session.to_dict()
	session.overworld.resources.gold += 1
	var mutation_rejected: bool = not shell._stale_end_turn_request_fields(pending).is_empty()
	var ok: bool = bool(first.get("ok", false)) and stale.is_empty() and changed_hashes.is_empty() and unchanged and mutation_rejected
	print("END_TURN_SNAPSHOT_PROBE " + JSON.stringify({"ok": ok, "signature_before": signature_before, "pending": pending.get("session_payload_signature"), "signature_after": signature_after, "stale": stale, "changed_hashes_on_repeat": changed_hashes, "request_ok": first.get("ok"), "unchanged_session": unchanged, "actual_mutation_rejected": mutation_rejected, "warning": warning.get("signature")}))
	get_tree().quit(0 if ok else 1)
'''


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("fixture", type=Path, nargs="?")
    p.add_argument("--label", required=True)
    args = p.parse_args()
    if not args.label or any(c not in "abcdefghijklmnopqrstuvwxyz0123456789_-" for c in args.label):
        p.error("invalid label")
    out = OUTPUT / args.label
    out.mkdir(parents=True, exist_ok=False)
    with tempfile.TemporaryDirectory(prefix="turn-probe-", dir=OUTPUT) as temporary:
        work = Path(temporary)
        script = work / "probe.gd"
        script.write_text(SCRIPT)
        scene = work / "probe.tscn"
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="Probe" type="Node"]\nscript = ExtResource("1")\n' % script.relative_to(ROOT))
        env = dict(os.environ, XDG_DATA_HOME=str(work / "data"), HEROES_END_TURN_PROBE_FIXTURE=str(args.fixture.resolve()) if args.fixture else "", HEROES_END_TURN_PROBE_OUT=str(out))
        with (out / "runtime.log").open("w") as log:
            result = subprocess.run(["timeout", "120s", "godot4", "--headless", "--path", str(ROOT), "--audio-driver", "Dummy", "res://" + str(scene.relative_to(ROOT))], cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=140)
        log_text = (out / "runtime.log").read_text()
        print(log_text[-6000:])
    rows = [json.loads(line.split(" ", 1)[1]) for line in log_text.splitlines() if line.startswith("END_TURN_SNAPSHOT_PROBE ")]
    report = rows[-1] if rows else {"ok": False}
    report["runtime_errors"] = [line for line in log_text.splitlines() if line.startswith(("ERROR:", "SCRIPT ERROR:"))]
    report["ok"] = bool(report.get("ok")) and not report["runtime_errors"]
    (out / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    return result.returncode or (0 if report["ok"] else 1)


if __name__ == "__main__":
    raise SystemExit(main())
