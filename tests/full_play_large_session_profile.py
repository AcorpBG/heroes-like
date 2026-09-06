#!/usr/bin/env python3
"""Play a deterministic Large expedition through real scenes for ten days/outcome."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import resource
import subprocess
import tempfile

from full_play_runtime_profile import ROOT, OUTPUT, summarize

REFERENCE = "bd42b459102853f02d7b79174a0ccfc80b1dbf79"
MARKER = "FULL_PLAY_LARGE_REPORT "
SCRIPT = r'''
extends "res://tests/large_generated_map_runtime_profile_report.gd"
var actions := []
var failures := []
var visited := {}
var walked := {}
var movement_count := 0
var out := ""
var session

func settle() -> void:
	for frame in range(6):
		await get_tree().process_frame

func capture(id: String, screenshot: bool = false) -> void:
	var file := FileAccess.open(out.path_join(id + ".session.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(session.to_dict(), "", false))
	file.close()
	if screenshot and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join(id + ".png"))

func record(kind: String, started: int, result: Dictionary) -> void:
	var row := {"kind": kind, "day": session.day, "wall_ms": _elapsed_ms(started), "result": result}
	actions.append(row)
	print("FULL_PLAY_LARGE_ACTION " + JSON.stringify({"kind": kind, "day": session.day, "wall_ms": row.wall_ms, "ok": result.get("ok", false)}))

func resolve_routes() -> void:
	await settle()
	for attempt in range(8):
		var scene = get_tree().current_scene
		if scene == null:
			await settle()
			continue
		var path := String(scene.scene_file_path)
		if path.ends_with("BattleShell.tscn"):
			await capture("battle_%03d" % actions.size(), true)
			var started := Time.get_ticks_usec()
			var request: Dictionary = scene.validation_request_quick_resolve_confirmation()
			await settle()
			var result: Dictionary = scene.validation_confirm_quick_resolve_confirmation()
			await settle()
			record("quick_resolve", started, result)
			if not bool(request.get("ok", false)) or not bool(result.get("performed", false)):
				failures.append("legal Quick Resolve failed")
				return
		elif path.ends_with("BattleReportShell.tscn"):
			await capture("casualties_%03d" % actions.size(), true)
			var started := Time.get_ticks_usec()
			scene.get_node("%Continue").pressed.emit()
			var result: Dictionary = scene._last_continue_result.duplicate(true)
			await settle()
			record("report_continue", started, result)
			if not bool(result.get("ok", false)):
				failures.append("battle report required save failed")
				return
		else:
			return
	failures.append("scene routing did not settle")

func route_step(kind: String, placement: String) -> Dictionary:
	var scene = get_tree().current_scene
	var started := Time.get_ticks_usec()
	var result: Dictionary = scene.validation_route_step_to_target_placement(kind, placement)
	await resolve_routes()
	record("route_" + kind, started, result)
	return result

func town_orders() -> void:
	var scene = get_tree().current_scene
	await capture("town_entered", true)
	for lane in ["build", "recruit", "study"]:
		var catalog: Dictionary = scene.validation_action_catalog()
		for action in catalog.get(lane, []):
			if bool(action.get("disabled", true)):
				continue
			var started := Time.get_ticks_usec()
			var result := {}
			if lane == "build":
				scene._open_town_catalog("build")
				await settle()
				scene._select_build_action(String(action.id))
				await settle()
				scene._on_confirm_build_pressed()
				var building_id := String(action.id).trim_prefix("build:")
				result = {"ok": building_id in TownRules.get_active_town(session).get("built_buildings", []), "committed_action_id": action.id}
			else:
				result = scene.validation_perform_town_action(String(action.id))
			await settle()
			while scene._town_action_input_blocker.visible and _elapsed_ms(started) < 30000:
				await get_tree().process_frame
			record("town_" + lane, started, result)
			if not bool(result.get("ok", false)) or scene._town_action_input_blocker.visible:
				failures.append("town order failed: " + lane)
			break
	await capture("town_progressed", true)
	var started := Time.get_ticks_usec()
	var leave: Dictionary = scene.validation_leave_town()
	await resolve_routes()
	record("town_exit", started, leave)

func visible_resource() -> String:
	var scene = get_tree().current_scene
	var origin := OverworldRules.hero_position(session)
	var candidates: Array = scene._validation_targets("resource")
	candidates.sort_custom(func(a, b):
		var da: int = absi(int(a.x) - origin.x) + absi(int(a.y) - origin.y)
		var db: int = absi(int(b.x) - origin.x) + absi(int(b.y) - origin.y)
		return String(a.placement_id) < String(b.placement_id) if da == db else da < db)
	for candidate in candidates:
		var id := String(candidate.placement_id)
		if not visited.has(id) and OverworldRules.is_tile_visible(session, int(candidate.x), int(candidate.y)):
			return id
	return ""

func explore_step() -> void:
	var scene = get_tree().current_scene
	var origin := OverworldRules.hero_position(session)
	if int(session.overworld.movement.current) <= 0:
		return
	var chosen := origin
	var best_visits := 999999
	for direction in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP, Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		var target: Vector2i = origin + direction
		if OverworldRules.tile_is_blocked(session, target.x, target.y) or not scene._town_footprint_selection(target).is_empty():
			continue
		var visits := int(walked.get(target, 0))
		if visits < best_visits:
			best_visits = visits
			chosen = target
	if chosen == origin:
		return
	walked[origin] = int(walked.get(origin, 0)) + 1
	var started := Time.get_ticks_usec()
	scene._on_map_tile_pressed(chosen)
	await resolve_routes()
	var destination := OverworldRules.hero_position(session)
	var moved := destination != origin
	if moved:
		movement_count += 1
	record("explore_move", started, {"ok": moved, "from": {"x": origin.x, "y": origin.y}, "to": {"x": destination.x, "y": destination.y}})

func _run() -> void:
	get_tree().current_scene = null # Keep this disposable driver across real router transitions.
	SettingsService.set_presentation_mode("windowed")
	SettingsService.set_presentation_resolution(OS.get_environment("HEROES_LIVE_PROFILE_RESOLUTION"))
	out = OS.get_environment("HEROES_FULL_PLAY_LARGE_OUTPUT")
	var reference := OS.get_environment("HEROES_FULL_PLAY_REFERENCE_CONTENT")
	if reference != "":
		# Exact prior implementation, test-only; same native generation and gameplay.
		var reference_script = load(reference)
		if reference_script == null or not reference_script.can_instantiate():
			_fail("reference lookup owner did not load")
			return
		ContentService.set_script(reference_script)
	OS.set_environment("HEROES_PROFILE_LOG", "1")
	OS.set_environment("HEROES_STRATEGIC_AI_PROFILE", "1")
	var started := Time.get_ticks_usec()
	var config := ScenarioSelectRulesScript.build_random_map_player_config(SEED, "translated_rmg_template_042_v1", "translated_rmg_profile_042_v1", 4, "land", false, SIZE_CLASS_ID, ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_SIZE_DEFAULT, FACTION_ID, HERO_ID)
	var setup := ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(config, "normal", ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY)
	if not bool(setup.get("ok", false)):
		_fail("Large setup failed")
		return
	session = SessionState.set_active_session(ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup))
	var signature := String(session.flags.get("generated_random_map_materialization", {}).get("materialized_map_signature", setup.get("generated_identity", {}).get("materialized_map_signature", "")))
	var identity_error := _profile_identity_error(session, signature)
	if identity_error != "":
		_fail(identity_error)
		return
	AppRouter.go_to_overworld()
	await resolve_routes()
	record("generation_and_entry", started, {"ok": true, "signature": signature})
	await capture("day_01_entry", true)
	var player_town := {}
	for town in session.overworld.towns:
		if town.owner == "player":
			player_town = town
			break
	# The shipped owned-town body click opens remote management. Do not route
	# to a native object's blocked anchor or teleport a hero onto that anchor.
	started = Time.get_ticks_usec()
	var hero_before := OverworldRules.hero_position(session)
	var click_tile := Vector2i(int(player_town.x), int(player_town.y))
	var found_body := false
	for dy in range(-3, 1):
		for dx in range(-1, 2):
			var candidate := Vector2i(int(player_town.x) + dx, int(player_town.y) + dy)
			var selection: Dictionary = get_tree().current_scene._town_footprint_selection(candidate)
			if String(selection.get("town_placement_id", "")) == String(player_town.placement_id) and not bool(selection.get("is_entry_tile", true)):
				click_tile = candidate
				found_body = true
				break
		if found_body:
			break
	get_tree().current_scene._on_map_tile_pressed(click_tile)
	await resolve_routes()
	var opened := String(get_tree().current_scene.scene_file_path).ends_with("TownShell.tscn")
	record("town_body_click", started, {"ok": opened, "found_body": found_body, "click_tile": {"x": click_tile.x, "y": click_tile.y}, "hero_position_unchanged": hero_before == OverworldRules.hero_position(session)})
	if opened:
		await town_orders()
	else:
		failures.append("shipped owned-town body click did not open management")
	for iteration in range(10):
		if session.day >= 11 or session.scenario_status != "in_progress" or not failures.is_empty():
			break
		for move_index in range(3):
			var target := visible_resource()
			if target == "":
				await explore_step()
			else:
				var before_move := OverworldRules.hero_position(session)
				var result := await route_step("resource", target)
				if OverworldRules.hero_position(session) != before_move:
					movement_count += 1
				if not bool(result.get("ok", false)) or int(result.get("remaining_steps", 1)) == 0:
					visited[target] = true
			if session.scenario_status != "in_progress" or not failures.is_empty():
				break
		if session.scenario_status != "in_progress" or not failures.is_empty():
			break
		await capture("day_%02d_before_turn" % session.day, session.day in [1, 5, 10])
		started = Time.get_ticks_usec()
		var scene = get_tree().current_scene
		var turn: Dictionary = scene._request_end_turn(false)
		if bool(turn.get("confirmation_required", false)):
			turn = scene._on_end_turn_confirmation_confirmed()
		await resolve_routes()
		record("end_turn", started, turn)
		if not bool(turn.get("ok", false)):
			failures.append("full End Turn failed")
		await capture("day_%02d_after_turn" % session.day)
	await capture("final", true)
	var round_trip := _validate_generated_save_round_trip(session)
	if not bool(round_trip.get("ok", false)):
		failures.append("generated session save roundtrip failed")
	if session.day < 11 and session.scenario_status == "in_progress":
		failures.append("extended session ended before ten days or a natural outcome")
	if actions.filter(func(row): return row.kind == "town_build").is_empty():
		failures.append("no town purchase exercised")
	if movement_count < 3:
		failures.append("extended play did not exercise at least three actual legal movements")
	print("FULL_PLAY_LARGE_REPORT " + JSON.stringify({"ok": failures.is_empty(), "failures": failures, "seed": SEED, "signature": signature, "day": session.day, "movement_count": movement_count, "scenario_status": session.scenario_status, "actions": actions, "round_trip": round_trip}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--label", required=True)
    parser.add_argument("--reference-lookups", action="store_true")
    parser.add_argument("--compare", type=Path)
    parser.add_argument("--rendered", action="store_true")
    parser.add_argument("--accessibility", choices=["auto", "disabled"], default="auto", help="Test-only engine backend override; record upstream AccessKit failures, never change production settings")
    parser.add_argument("--resolution", choices=["1280x720", "1920x1080"], default="1280x720")
    args = parser.parse_args()
    if not args.label or any(c not in "abcdefghijklmnopqrstuvwxyz0123456789_-" for c in args.label):
        parser.error("invalid label")
    out = OUTPUT / args.label
    if args.compare:
        if args.reference_lookups or args.compare.resolve() == out.resolve():
            parser.error("compare a new current run against a distinct reference run")
        control_report = json.loads((args.compare / "report.json").read_text())
        if not control_report.get("ok") or not control_report.get("reference_lookups") or control_report.get("resolution") != args.resolution or control_report.get("rendered") != args.rendered or control_report.get("accessibility") != args.accessibility:
            parser.error("control must be a successful reference run with identical display configuration")
    out.mkdir(parents=True, exist_ok=False)
    with tempfile.TemporaryDirectory(prefix="large-driver-", dir=OUTPUT) as temporary:
        work = Path(temporary)
        script = work / "probe.gd"
        script.write_text(SCRIPT)
        scene = work / "probe.tscn"
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="Profile" type="Node"]\nscript = ExtResource("1")\n' % script.relative_to(ROOT))
        env = dict(os.environ, XDG_DATA_HOME=str(out / "data"), HEROES_FULL_PLAY_LARGE_OUTPUT=str(out), HEROES_LIVE_PROFILE_RESOLUTION=args.resolution)
        if args.reference_lookups:
            reference = work / "reference_content.gd"
            # Remove only the duplicate global class registration, not any method.
            source = subprocess.check_output(["git", "show", REFERENCE + ":scripts/autoload/ContentService.gd"], cwd=ROOT, text=True)
            reference.write_text(source.replace("class_name HeroesContentService\n", "", 1))
            env["HEROES_FULL_PLAY_REFERENCE_CONTENT"] = "res://" + str(reference.relative_to(ROOT))
        cmd = ["godot4", "--path", str(ROOT), "--audio-driver", "Dummy", "--accessibility", args.accessibility, "--resolution", args.resolution, "res://" + str(scene.relative_to(ROOT))]
        cmd = (["dbus-run-session", "--", "xvfb-run", "-a", "-s", "-screen 0 2200x1200x24"] + cmd) if args.rendered else cmd + ["--headless"]
        with (out / "runtime.log").open("w") as log:
            result = subprocess.run(["timeout", "1500s"] + cmd, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=1520)
    lines = (out / "runtime.log").read_text().splitlines()
    markers = [line[len(MARKER):] for line in lines if line.startswith(MARKER)]
    report = json.loads(markers[-1]) if markers else {"ok": False, "failures": [line[:1000] for line in lines[-20:]]}
    report["returncode"] = result.returncode
    report.update(reference_lookups=args.reference_lookups, reference_revision=REFERENCE, rendered=args.rendered, resolution=args.resolution, accessibility=args.accessibility, peak_child_rss_kib=resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss)
    report["runtime_errors"] = [line for line in lines if line.startswith(("ERROR:", "SCRIPT ERROR:")) or "leaked" in line]
    if report["runtime_errors"] or result.returncode:
        report["ok"] = False
    if args.compare:
        current = {p.name: json.loads(p.read_text()) for p in out.glob("*.session.json")}
        reference = {p.name: json.loads(p.read_text()) for p in args.compare.glob("*.session.json")}
        parity = {name: current.get(name) == reference.get(name) for name in current.keys() | reference.keys()}
        report["state_comparison"] = parity
        if not parity or not all(parity.values()):
            report["ok"] = False
            report["failures"].append("complete session parity failed")
    profile = out / "data/godot/app_userdata/heroes-like/debug/heroes_profile.jsonl"
    report["profile_summary"] = summarize([json.loads(line) for line in profile.read_text().splitlines() if line.strip()]) if profile.exists() else []
    (out / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({k: v for k, v in report.items() if k not in ["actions", "profile_summary"]}))
    return result.returncode or (0 if report["ok"] else 1)


if __name__ == "__main__":
    raise SystemExit(main())
