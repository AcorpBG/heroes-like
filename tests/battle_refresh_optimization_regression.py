#!/usr/bin/env python3
"""Check battle save-copy parity/freshness, modal focus and renderer teardown."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile

from full_play_large_session_profile import REFERENCE
from full_play_runtime_profile import ROOT, OUTPUT

MARKER = "BATTLE_REFRESH_OPTIMIZATION_REPORT "
SCRIPT = r'''
extends Node
const VisualKit = preload("res://scripts/ui/FrontierVisualKit.gd")
var errors := []
var rows := []

func check(ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)

func _ready() -> void:
	call_deferred("run")

func settle() -> void:
	for frame in range(4):
		await get_tree().process_frame

func surface(battle) -> Dictionary:
	return {"status": battle._system_body_label.text, "status_tooltip": battle._system_body_label.tooltip_text, "slot_tooltip": battle._save_slot_picker.tooltip_text, "save": battle._save_button.text, "save_tooltip": battle._save_button.tooltip_text, "menu": battle._menu_button.text, "menu_tooltip": battle._menu_button.tooltip_text, "slot": battle._save_slot_picker.get_selected_id()}

func run() -> void:
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	session.session_id = "battle_refresh_regression"
	for encounter in session.overworld.encounters:
		if String(encounter.placement_id) == "river_pass_hollow_mire":
			session.battle = BattleRules.create_battle_payload(session, encounter)
			break
	session.game_state = "battle"
	session = SessionState.set_active_session(session)
	var battle = load("res://scenes/battle/BattleShell.tscn").instantiate()
	battle.set_script(load(OS.get_environment("HEROES_BATTLE_REFERENCE_SCRIPT")))
	add_child(battle)
	battle.validation_set_battle_resolution_routing_enabled(false)
	await settle()
	SaveService.set_selected_manual_slot(2)
	for fixture in ["empty", "saved", "replaced"]:
		if fixture != "empty":
			if fixture == "replaced":
				session.overworld.resources.gold += 1 # Explicit invalidation fixture, not playthrough.
			check(bool(SaveService.save_runtime_manual_session(session, 2).get("ok", false)), "fixture save failed")
		var summary := SaveService.inspect_manual_slot(2)
		check(String(summary.get("detail", "")) == SaveService.describe_slot_details(summary), "verified summary detail differs from direct construction")
		var before := session.to_dict()
		var full := AppRouter.active_save_surface()
		var compact := AppRouter.active_save_surface({}, false)
		full.erase("slot_resume_recap")
		full.erase("latest_resume_recap")
		compact.erase("slot_resume_recap")
		compact.erase("latest_resume_recap")
		check(full == compact, "request projection changed a consumed surface field")
		for repeat in range(3):
			SaveService.validation_begin_summary_inspection_trace()
			var started := Time.get_ticks_usec()
			battle.legacy_refresh_save_slot_picker()
			var reference_ms := float(Time.get_ticks_usec() - started) / 1000.0
			var reference_trace := SaveService.validation_end_summary_inspection_trace()
			var expected := surface(battle)
			SaveService.validation_begin_summary_inspection_trace()
			started = Time.get_ticks_usec()
			battle._refresh_save_slot_picker()
			var current_ms := float(Time.get_ticks_usec() - started) / 1000.0
			var current_trace := SaveService.validation_end_summary_inspection_trace()
			check(expected == surface(battle), "battle text/tooltip/selection changed for " + fixture)
			check(reference_trace.inspect_manual_slot == current_trace.inspect_manual_slot + 1, "eager fallback inspection not eliminated")
			rows.append({"fixture": fixture, "reference_ms": reference_ms, "current_ms": current_ms, "reference_trace": reference_trace, "current_trace": current_trace})
		check(before == session.to_dict(), "save-copy refresh mutated battle/world")
	var battle_before := session.to_dict()
	for repeat in range(3):
		check(bool(battle.validation_request_quick_resolve_confirmation().get("pending", false)), "confirmation failed to open")
		await settle()
		check(battle._quick_resolve_confirmation_dialog.exclusive, "opened confirmation is not modal")
		battle._quick_resolve_confirmation_dialog.get_cancel_button().pressed.emit()
		await settle()
		check(not battle._quick_resolve_confirmation_dialog.visible, "cancel left dialog visible")
		check(battle._quick_resolve_confirmation_dialog.exclusive, "cancel lost future modality")
		check(battle_before == session.to_dict(), "cancel changed gameplay")
	check(bool(battle.validation_request_quick_resolve_confirmation().get("pending", false)), "final confirmation failed")
	await settle()
	battle._quick_resolve_confirmation_dialog.get_ok_button().pressed.emit()
	await settle()
	check(bool(battle._last_quick_resolve_confirmation_result.get("performed", false)), "real OK button did not resolve battle")
	check(battle._validation_quick_resolve_confirmation_perform_count == 1, "confirmation performed more than once")
	check(not battle._quick_resolve_confirmation_dialog.visible and battle._quick_resolve_confirmation_dialog.exclusive, "confirmation close/future modality wrong")
	battle.queue_free()
	await settle()
	# Explicit staged withdrawal fixtures, separate from the measured save UI and
	# legal full-play run. Exercise the real OK/Cancel signals, not convenience
	# calls which would bypass AcceptDialog's automatic-hide behavior.
	for action in ["retreat", "surrender"]:
		var withdrawal = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
		withdrawal.battle = BattleRules.create_battle_payload(withdrawal, withdrawal.overworld.encounters[0])
		withdrawal.battle.retreat_allowed = true
		withdrawal.battle.surrender_allowed = true
		withdrawal.game_state = "battle"
		for turn in range(12):
			if String(BattleRules.get_active_stack(withdrawal.battle).get("side", "")) == "player":
				break
			BattleRules.advance_turn(withdrawal.battle)
		withdrawal = SessionState.set_active_session(withdrawal)
		var shell = load("res://scenes/battle/BattleShell.tscn").instantiate()
		add_child(shell)
		shell.validation_set_battle_resolution_routing_enabled(false)
		await settle()
		var before: Dictionary = withdrawal.to_dict()
		check(bool(shell.validation_request_withdrawal(action).get("pending", false)), action + " modal request failed")
		await settle()
		shell._withdrawal_confirmation_dialog.get_cancel_button().pressed.emit()
		await settle()
		check(before == withdrawal.to_dict(), action + " cancel changed session")
		check(not shell._withdrawal_confirmation_dialog.visible and shell._withdrawal_confirmation_dialog.exclusive, action + " cancel/future modality wrong")
		check(bool(shell.validation_request_withdrawal(action).get("pending", false)), action + " second request failed")
		await settle()
		shell._withdrawal_confirmation_dialog.get_ok_button().pressed.emit()
		await settle()
		check(bool(shell._last_withdrawal_confirmation_result.get("performed", false)), action + " actual OK failed")
		check(int(shell._last_withdrawal_confirmation_result.get("routing_attempt_delta", 0)) == 1, action + " must route once")
		check(not shell._withdrawal_confirmation_dialog.visible and shell._withdrawal_confirmation_dialog.exclusive, action + " confirm/future modality wrong")
		shell.queue_free()
		await settle()
	VisualKit.release_runtime_resources()
	check(not VisualKit.validation_pointer_cursor_snapshot().texture_loaded, "static cursor texture survived release")
	VisualKit._sync_pointer_cursor()
	check(VisualKit.validation_pointer_cursor_snapshot().texture_loaded, "cursor failed to reload after release")
	print("BATTLE_REFRESH_OPTIMIZATION_REPORT " + JSON.stringify({"ok": errors.is_empty(), "errors": errors, "rows": rows, "actual_ok_and_cancel_buttons": true, "cursor_release_reload": true}))
	get_tree().quit(0 if errors.is_empty() else 1)
'''


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--label", default="battle_regression")
    args = parser.parse_args()
    if not args.label or any(c not in "abcdefghijklmnopqrstuvwxyz0123456789_-" for c in args.label):
        parser.error("invalid label")
    out = OUTPUT / args.label
    out.mkdir(parents=True, exist_ok=False)
    source = subprocess.check_output(["git", "show", REFERENCE + ":scenes/battle/BattleShell.gd"], cwd=ROOT, text=True)
    body = source.split("func _refresh_save_slot_picker()", 1)[1].split("\nfunc ", 1)[0]
    assert body.count("SaveService.describe_slot_details(summary)") == 2, "reference must retain both original detail reconstructions"
    with tempfile.TemporaryDirectory(prefix="battle-driver-", dir=OUTPUT) as temporary:
        work = Path(temporary)
        legacy = work / "legacy_battle.gd"
        legacy.write_text('extends "res://scenes/battle/BattleShell.gd"\nfunc legacy_refresh_save_slot_picker()' + body)
        script = work / "probe.gd"
        script.write_text(SCRIPT)
        scene = work / "probe.tscn"
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="Probe" type="Node"]\nscript = ExtResource("1")\n' % script.relative_to(ROOT))
        env = dict(os.environ, XDG_DATA_HOME=str(work / "data"), HEROES_BATTLE_REFERENCE_SCRIPT="res://" + str(legacy.relative_to(ROOT)))
        with (out / "runtime.log").open("w") as log:
            result = subprocess.run(["timeout", "180s", "dbus-run-session", "--", "xvfb-run", "-a", "godot4", "--path", str(ROOT), "--audio-driver", "Dummy", "--resolution", "1280x720", "res://" + str(scene.relative_to(ROOT))], cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=200)
    lines = (out / "runtime.log").read_text().splitlines()
    markers = [line[len(MARKER):] for line in lines if line.startswith(MARKER)]
    report = json.loads(markers[-1]) if markers else {"ok": False, "errors": lines[-20:]}
    report["runtime_errors"] = [line for line in lines if line.startswith(("SCRIPT ERROR:", "ERROR:")) or "leaked" in line]
    if report["runtime_errors"]:
        report["ok"] = False
    measured = [row for row in report.get("rows", []) if row["fixture"] != "empty"]
    if len(measured) != 6 or sum(r["current_ms"] for r in measured) >= .8 * sum(r["reference_ms"] for r in measured):
        report["ok"] = False
        report["errors"].append("matched stored-save refresh improvement budget failed")
    (out / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report))
    return result.returncode or (0 if report["ok"] else 1)


if __name__ == "__main__":
    raise SystemExit(main())
