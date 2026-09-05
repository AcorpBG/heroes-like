#!/usr/bin/env python3
"""Exercise real named-file storage and all four live Save buttons in isolated data."""
from __future__ import annotations

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / ".artifacts" / "visual_performance_file_saves_review"
SCRIPT = r'''
extends Node
var failures := []
var captures := []
var route_results := []

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	# Keep the observer alive if an input regression wrongly changes the scene.
	get_tree().current_scene = null
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state_for_runtime(session)
	session = SessionState.set_active_session(session)
	var original_day: int = session.day
	for i in range(5):
		var result := SaveService.save_runtime_file_session(session, "Expedition %d" % i)
		check(bool(result.get("ok", false)), "create file %d" % i)
	check(SaveService.list_save_files().size() == 5, "more than three files are independently browsable")
	for summary in SaveService.list_save_files():
		check(bool(summary.get("payload_deferred", false)) and summary.get("payload", {}).is_empty(), "unlimited library caches summaries, not entire worlds")
	for name in ["", "../escape", "a/b", "a\\b", "CON", "nul", "COM1", "LPT9", "trailing.", "bad:name", "bad\nname", "x".repeat(65)]:
		check(not bool(SaveService.save_file_identity(name).get("ok", true)), "reject unsafe name: " + name)
	check(bool(SaveService.save_runtime_file_session(session, "Étoile — Day 1").get("ok", false)), "Unicode name round trip")
	var action := SaveService.build_file_save_action("EXPEDITION 0")
	check(bool(action.get("requires_confirmation", false)) and String(action.get("name", "")) == "Expedition 0", "case-insensitive identity parity")
	var original_hash := String(action.get("expected_sha256", ""))
	var original_path := String(action.get("path", ""))
	session.day += 1
	check(not bool(SaveService.save_runtime_file_session(session, "Expedition 0").get("ok", true)), "implicit overwrite rejected")
	check(not bool(SaveService.save_runtime_file_session(session, "Expedition 0", true, "stale").get("ok", true)), "stale overwrite consent rejected")
	check(FileAccess.get_sha256(original_path) == original_hash, "rejected overwrites preserve bytes")
	for phase in ["precommit", "after_backup"]:
		OS.set_environment("HEROES_LIKE_SAVE_FAIL_PHASE", phase)
		var failed := SaveService.save_runtime_file_session(session, "Expedition 0", true, original_hash)
		OS.set_environment("HEROES_LIKE_SAVE_FAIL_PHASE", "")
		check(not bool(failed.get("ok", true)), "failure injected at " + phase)
		check(FileAccess.get_sha256(original_path) == original_hash, "prior file preserved at " + phase)
	check(bool(SaveService.save_runtime_file_session(session, "Expedition 0", true, original_hash).get("ok", false)), "explicit overwrite succeeds")
	var restored = SaveService.restore_session_from_summary(SaveService.inspect_save_file("Expedition 0"))
	check(restored != null and restored.day == original_day + 1 and restored.scenario_id == session.scenario_id, "named file restores actual session")
	var valid_bytes := FileAccess.get_file_as_string(original_path)
	var external_edit := FileAccess.open(original_path, FileAccess.WRITE)
	external_edit.store_string("[" + valid_bytes.substr(1))
	external_edit.close()
	check(not SaveService.can_load_summary(SaveService.inspect_save_file("Expedition 0")), "same-size external edit invalidates cached payload")
	external_edit = FileAccess.open(original_path, FileAccess.WRITE)
	external_edit.store_string(valid_bytes)
	external_edit.close()
	check(SaveService.can_load_summary(SaveService.inspect_save_file("Expedition 0")), "repaired external file loads current bytes")
	check(SaveService.save_runtime_manual_session(session, 2).get("ok", false), "legacy writer compatibility")
	check(SaveService.restore_manual_session(2) != null, "old slot files remain loadable")
	var legacy_hash := FileAccess.get_sha256("user://saves/slot2.json")
	check(bool(SaveService.delete_session_from_summary(SaveService.inspect_save_file("Expedition 4")).get("ok", false)), "named deletion")
	check(not FileAccess.file_exists("user://saves/Expedition 4.save.json") and FileAccess.get_sha256("user://saves/slot2.json") == legacy_hash, "deletion only removes selected named file")
	# Interrupted transaction from another process: backup is restored and the
	# uncommitted candidate is not silently adopted as the owner's save.
	var backup := original_path + ".backup"
	check(DirAccess.rename_absolute(ProjectSettings.globalize_path(original_path), ProjectSettings.globalize_path(backup)) == OK, "stage interrupted named backup")
	var broken := FileAccess.open(original_path + ".candidate", FileAccess.WRITE)
	broken.store_string("{broken")
	broken.close()
	SaveService.validation_clear_summary_cache()
	check(SaveService.can_load_summary(SaveService.inspect_save_file("Expedition 0")), "recover named transaction after restart")
	check(not FileAccess.file_exists(backup) and not FileAccess.file_exists(original_path + ".candidate"), "recovered transaction residue cleared")
	for route in ["overworld", "town", "battle", "outcome"]:
		print("NAMED_SAVE_ROUTE " + route)
		session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
		OverworldRules.normalize_overworld_state_for_runtime(session)
		if route == "town":
			for town in session.overworld.towns:
				if String(town.get("owner", "")) == "player":
					var position := {"x": int(town.x), "y": int(town.y)}
					session.overworld.hero_position = position.duplicate()
					session.overworld.hero.position = position.duplicate()
					for hero in session.overworld.get("player_heroes", []):
						if String(hero.get("id", "")) == String(session.overworld.get("active_hero_id", "")):
							hero.position = position.duplicate()
					OverworldRules.set_active_town_visit(session, String(town.placement_id))
					break
		elif route == "battle":
			session.battle = BattleRules.create_battle_payload(session, session.overworld.encounters[0])
			session.game_state = "battle"
		elif route == "outcome":
			session.scenario_status = "victory"
			session.scenario_summary = "Named-save regression fixture."
			session.game_state = "outcome"
		session = SessionState.set_active_session(session)
		var scene_path: String = {"overworld": "overworld/OverworldShell", "town": "town/TownShell", "battle": "battle/BattleShell", "outcome": "results/ScenarioOutcomeShell"}[route]
		var shell = load("res://scenes/%s.tscn" % scene_path).instantiate()
		add_child(shell)
		for frame in range(3):
			await get_tree().process_frame
		var button: Button = shell.get_node("%Save")
		check(not button.disabled, route + " Save action available")
		button.pressed.emit()
		await get_tree().process_frame
		var dialog = shell.get_node("ManualSaveOverwriteDialog")
		check(dialog.visible and bool(dialog.get("_file_mode")), route + " real Save button opens file browser")
		check(not shell.get_node("%SaveSlot").is_visible_in_tree(), route + " no fixed-slot picker")
		if route == "overworld":
			for viewport in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
				get_window().size = viewport
				get_window().content_scale_size = viewport
				dialog.popup_centered(Vector2i(600, 420))
				for frame in range(3):
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var path := "res://.artifacts/visual_performance_file_saves_review/save_files_%dx%d.png" % [viewport.x, viewport.y]
				check(get_viewport().get_texture().get_image().save_png(path) == OK, "save browser screenshot")
				captures.append(path)
		var name_field: LineEdit = dialog.get("_file_name")
		name_field.text = "UI " + route
		name_field.text_changed.emit(name_field.text)
		dialog.call("_confirm_file_save")
		check(not dialog.visible and SaveService.can_load_summary(SaveService.inspect_save_file("UI " + route)), route + " dialog commits actual file")
		var saved_hash := FileAccess.get_sha256(String(SaveService.save_file_identity("UI " + route).path))
		var before_cancel: Dictionary = session.to_dict().duplicate(true)
		button.pressed.emit()
		await get_tree().process_frame
		name_field.text = "UI " + route
		name_field.text_changed.emit(name_field.text)
		name_field.grab_focus()
		var submit := InputEventKey.new()
		submit.keycode = KEY_ENTER
		submit.physical_keycode = KEY_ENTER
		submit.pressed = true
		Input.parse_input_event(submit)
		for frame in range(3):
			await get_tree().process_frame
		submit.pressed = false
		Input.parse_input_event(submit)
		await get_tree().process_frame
		check(dialog.visible and dialog.get_ok_button().text == "Replace file", route + " overwrite needs second confirmation")
		check(FileAccess.get_sha256(String(SaveService.save_file_identity("UI " + route).path)) == saved_hash, route + " Enter cannot confirm and overwrite in one event")
		if not dialog.visible:
			print("NAMED_SAVE_FILES_REPORT " + JSON.stringify({"ok": false, "failures": failures, "routes": route_results, "captures": captures}))
			get_tree().quit(1)
			return
		var cancel_event: InputEvent
		if route in ["battle", "outcome"]:
			var joy := InputEventJoypadButton.new()
			joy.button_index = JOY_BUTTON_B
			joy.pressed = true
			cancel_event = joy
		else:
			var key := InputEventKey.new()
			key.keycode = KEY_ESCAPE
			key.physical_keycode = KEY_ESCAPE
			key.pressed = true
			cancel_event = key
		Input.parse_input_event(cancel_event)
		for frame in range(3):
			await get_tree().process_frame
		cancel_event.set("pressed", false)
		Input.parse_input_event(cancel_event)
		await get_tree().process_frame
		check(not dialog.visible, route + " physical Escape/controller B cancels file replacement")
		check(FileAccess.get_sha256(String(SaveService.save_file_identity("UI " + route).path)) == saved_hash, route + " cancel preserves file")
		check(session.to_dict() == before_cancel and get_tree().current_scene == null, route + " modal inputs preserve session and scene routing")
		route_results.append({"route": route, "saved_path": SaveService.save_file_identity("UI " + route).path})
		shell.queue_free()
		await get_tree().process_frame
	var menu = load("res://scenes/menus/MainMenu.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	menu.call("_on_open_saves_pressed")
	var menu_rows: Array = menu.get("_save_summaries")
	var load_index := -1
	var legacy_visible := false
	for index in range(menu_rows.size()):
		var row: Dictionary = menu_rows[index]
		check(FileAccess.file_exists(String(row.path)), "load browser excludes empty fixed slots")
		if String(row.slot_type) == SaveService.SLOT_TYPE_FILE and String(row.slot_id) == "UI overworld":
			load_index = index
		if String(row.slot_type) == SaveService.SLOT_TYPE_MANUAL and String(row.slot_id) == "2":
			legacy_visible = true
	check(load_index >= 0 and legacy_visible, "main menu browses both named and legacy files")
	if load_index >= 0:
		menu.call("_on_save_selected", load_index)
		# Preserve this test observer while exercising the real AppRouter scene load.
		get_tree().current_scene = null
		menu.call("_on_load_selected_pressed")
		for frame in range(5):
			await get_tree().process_frame
		check(SessionState.active_session.game_state == "overworld" and SessionState.active_session.scenario_id == "river-pass", "main menu loads named expedition through router")
		check(get_tree().current_scene != null and get_tree().current_scene.scene_file_path.ends_with("OverworldShell.tscn"), "named load enters actual Overworld scene")
	print("NAMED_SAVE_FILES_REPORT " + JSON.stringify({"ok": failures.is_empty(), "failures": failures, "routes": route_results, "captures": captures, "file_count": SaveService.list_save_files().size()}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''


def main() -> int:
    ARTIFACTS.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="save-files-", dir=ARTIFACTS) as temporary:
        work = Path(temporary)
        script = work / "report.gd"
        script.write_text(SCRIPT, encoding="utf-8")
        scene = work / "report.tscn"
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="Report" type="Node"]\nscript = ExtResource("1")\n' % script.relative_to(ROOT), encoding="utf-8")
        env = dict(os.environ, XDG_DATA_HOME=str(work / "data"))
        command = ["xvfb-run", "-a", "-s", "-screen 0 2200x1200x24", "timeout", "240s", shutil.which("godot4") or "godot", "--path", str(ROOT), "--audio-driver", "Dummy", "res://" + str(scene.relative_to(ROOT))]
        result = subprocess.run(command, cwd=ROOT, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=300)
        (ARTIFACTS / "named_save_files.log").write_text(result.stdout, encoding="utf-8")
        lines = [line for line in result.stdout.splitlines() if line.startswith("NAMED_SAVE_FILES_REPORT ")]
        if not lines:
            print(result.stdout[-6000:])
            return result.returncode or 1
        report = json.loads(lines[-1].split(" ", 1)[1])
        runtime_errors = [line for line in result.stdout.splitlines() if "SCRIPT ERROR" in line or 'Condition "index == -1"' in line]
        if runtime_errors:
            report["ok"] = False
            report["failures"].extend(runtime_errors)
        (ARTIFACTS / "named_save_files_report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(report))
        return result.returncode or (0 if report["ok"] else 1)


if __name__ == "__main__":
    raise SystemExit(main())
