#!/usr/bin/env python3
"""Compare real Overworld/Town save bars to the exact prior consumer methods."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile

from full_play_runtime_profile import ROOT, OUTPUT
from full_play_large_session_profile import REFERENCE

SCRIPT = r'''
extends Node
var failures := []
var rows := []
func _ready() -> void:
	call_deferred("run")
func check(ok: bool, reason: String) -> void:
	if not ok:
		failures.append(reason)
func surface(shell) -> Dictionary:
	var copy := {}
	for field in ["_save_status_label", "_save_slot_picker", "_save_button", "_menu_button"]:
		var node = shell.get(field)
		copy[field] = {"text": node.text, "tooltip": node.tooltip_text, "visible": node.visible}
	copy["selected_slot"] = shell._save_slot_picker.get_selected_id()
	if shell.get("_leave_button") != null:
		copy["leave"] = {"text": shell._leave_button.text, "tooltip": shell._leave_button.tooltip_text}
	return copy
func run() -> void:
	for domain in ["overworld", "town"]:
		var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
		OverworldRules.normalize_overworld_state_for_runtime(session)
		if domain == "town":
			# Explicit presentation fixture; not counted as a legal-play visit.
			OverworldRules.set_active_town_visit(session, "riverwatch_hold")
			session.game_state = "town"
		session = SessionState.set_active_session(session)
		var path := "res://scenes/%s/%sShell.tscn" % [domain, domain.capitalize()]
		var shell = load(path).instantiate()
		shell.set_script(load(OS.get_environment("HEROES_SAVE_PROJECTION_" + domain.to_upper())))
		add_child(shell)
		for frame in range(6):
			await get_tree().process_frame
		SaveService.set_selected_manual_slot(1 if domain == "overworld" else 2)
		for fixture in ["empty", "saved", "replaced"]:
			if fixture != "empty":
				if fixture == "replaced":
					session.overworld.resources.gold += 1
				check(bool(SaveService.save_runtime_manual_session(session, SaveService.get_selected_manual_slot()).get("ok", false)), "fixture save failed")
			var before := session.to_dict()
			for repeat in range(3):
				var start := Time.get_ticks_usec()
				if domain == "town":
					shell.legacy_refresh_save_slot_picker(true)
				else:
					shell.legacy_refresh_save_slot_picker()
				var control_ms := float(Time.get_ticks_usec() - start) / 1000.0
				var expected := surface(shell)
				start = Time.get_ticks_usec()
				if domain == "town":
					shell._refresh_save_slot_picker(true)
				else:
					shell._refresh_save_slot_picker()
				var current_ms := float(Time.get_ticks_usec() - start) / 1000.0
				check(expected == surface(shell), domain + "/" + fixture + " text, tooltip or visibility changed")
				check(before == session.to_dict(), domain + " refresh mutated gameplay")
				rows.append({"domain": domain, "fixture": fixture, "control_ms": control_ms, "current_ms": current_ms})
		shell.queue_free()
		await get_tree().process_frame
	print("SAVE_REFRESH_PROJECTION " + JSON.stringify({"ok": failures.is_empty(), "failures": failures, "rows": rows}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--label", required=True)
    args = parser.parse_args()
    if not args.label or any(c not in "abcdefghijklmnopqrstuvwxyz0123456789_-" for c in args.label):
        parser.error("invalid label")
    out = OUTPUT / args.label
    out.mkdir(parents=True, exist_ok=False)
    with tempfile.TemporaryDirectory(prefix="save-projection-", dir=OUTPUT) as temporary:
        work = Path(temporary)
        env = dict(os.environ, XDG_DATA_HOME=str(work / "data"))
        for domain in ["overworld", "town"]:
            path = f"scenes/{domain}/{domain.capitalize()}Shell.gd"
            source = subprocess.check_output(["git", "show", REFERENCE + ":" + path], cwd=ROOT, text=True)
            body = source.split("func _refresh_save_slot_picker(", 1)[1].split("\nfunc ", 1)[0]
            legacy = work / (domain + ".gd")
            legacy.write_text('extends "res://' + path + '"\nfunc legacy_refresh_save_slot_picker(' + body)
            env["HEROES_SAVE_PROJECTION_" + domain.upper()] = "res://" + str(legacy.relative_to(ROOT))
        probe = work / "probe.gd"
        probe.write_text(SCRIPT)
        scene = work / "probe.tscn"
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="Probe" type="Node"]\nscript = ExtResource("1")\n' % probe.relative_to(ROOT))
        with (out / "runtime.log").open("w") as log:
            result = subprocess.run(["timeout", "180s", "godot4", "--headless", "--path", str(ROOT), "--audio-driver", "Dummy", "res://" + str(scene.relative_to(ROOT))], cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=200)
    lines = (out / "runtime.log").read_text().splitlines()
    reports = [json.loads(line.split(" ", 1)[1]) for line in lines if line.startswith("SAVE_REFRESH_PROJECTION ")]
    report = reports[-1] if reports else {"ok": False, "failures": [line[:1000] for line in lines[-15:]]}
    report["runtime_errors"] = [line for line in lines if line.startswith(("ERROR:", "SCRIPT ERROR:")) or "leaked" in line]
    for domain in ["overworld", "town"]:
        measured = [row for row in report.get("rows", []) if row["domain"] == domain and row["fixture"] != "empty"]
        if len(measured) != 6 or sum(row["current_ms"] for row in measured) >= .8 * sum(row["control_ms"] for row in measured):
            report["failures"].append(domain + " matched improvement budget failed")
    report["ok"] = bool(report["ok"]) and not report["failures"] and not report["runtime_errors"] and result.returncode == 0
    (out / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report))
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
