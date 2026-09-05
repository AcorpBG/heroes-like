#!/usr/bin/env python3
"""Generated-start audit and entrance regressions, with Python orchestration.

The temporary Godot adapter invokes production generation/adoption and dumps
facts. Graph measurements below are diagnostics, never generation authority.
Success means evidence was collected, not that RMG has no defects or full parity.
"""
from __future__ import annotations

import argparse
from collections import Counter, deque
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / ".artifacts/rmg_start_audit_20260905"
PROBE = r'''
extends Node
const Bridge = preload("res://scripts/persistence/NativeRandomMapPackageSessionBridge.gd")
const Rules = preload("res://scripts/core/OverworldRules.gd")
const Selection = preload("res://scripts/core/ScenarioSelectRules.gd")
const Store = preload("res://scripts/core/SessionStateStore.gd")
const MapView = preload("res://scenes/overworld/OverworldMapView.gd")
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	var out := OS.get_environment("HEROES_RMG_AUDIT_OUTPUT")
	var cases: Array = JSON.parse_string(FileAccess.get_file_as_string(out.path_join("cases.json")))
	var service = ClassDB.instantiate("MapPackageService")
	for case in cases:
		var started := Time.get_ticks_msec()
		var config: Dictionary = case.config
		var generated: Dictionary = service.generate_random_map(config, {"startup_path": "start_placement_audit"})
		var result := {"id": case.id, "config": config, "ok": generated.get("ok", false), "error_code": generated.get("error_code", ""), "normalized_config": generated.get("normalized_config", {})}
		if bool(result.ok):
			var map = generated.map_document
			var scenario = generated.scenario_document
			var objects := []
			for i in range(map.get_object_count()):
				objects.append(map.get_object_by_index(i))
			result.merge({"start_contract": scenario.get_start_contract(), "player_slots": scenario.get_player_slots(), "objects": objects, "terrain": map.get_terrain_layers(), "payload_fnv1a32": generated.get("final_payload_fnv1a32", ""), "payload_bytes": generated.get("final_payload_byte_count", 0), "metadata": map.get_metadata(), "map_size": {"width": map.get_width(), "height": map.get_height(), "levels": map.get_level_count()}})
			var adoption: Dictionary = service.convert_generated_payload(generated, {"feature_gate": "rmg_start_audit"})
			var session = Bridge.build_session_from_adoption(adoption)
			result["adoption_ok"] = adoption.get("ok", false)
			result["hero_position"] = session.overworld.get("hero_position", {})
			result["hero_id"] = session.hero_id
			result["enemy_states_before_normalization"] = session.overworld.get("enemy_states", []).duplicate(true)
			Rules.normalize_overworld_state(session)
			result["enemy_states"] = session.overworld.get("enemy_states", []).duplicate(true)
			result["towns"] = session.overworld.get("towns", []).duplicate(true)
			var pos := Rules.hero_position(session)
			var body_owners := []
			for family in ["towns", "map_objects", "encounters", "resource_nodes"]:
				for obj in session.overworld.get(family, []):
					var tiles: Array = Rules._generated_body_tiles_for_placement(obj, bool(obj.get("blocking_body", true)))
					if family == "resource_nodes":
						var content: Dictionary = Rules._map_object_for_resource_node(obj)
						tiles = Rules._map_object_world_body_tiles(content, obj) if Rules._resource_node_blocks_body_tiles(obj, content) else []
					if pos in tiles:
						body_owners.append({"family": family, "placement_id": obj.get("placement_id", ""), "object_id": obj.get("object_id", ""), "level": obj.get("level", null), "package_block_tiles": obj.get("package_block_tiles", null), "body_tiles": obj.get("body_tiles", [])})
			result["hero_blocking_body_owners"] = body_owners
			var moves := []
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					var tile := pos + Vector2i(dx, dy)
					if tile.x < 0 or tile.y < 0 or tile.x >= map.get_width() or tile.y >= map.get_height():
						continue
					if not Rules.tile_is_blocked(session, tile.x, tile.y) and not Rules.tile_step_cuts_blocked_corner(session, pos, tile):
						moves.append({"x": tile.x, "y": tile.y})
			result["unblocked_first_steps"] = moves
			var runtime_blocked := []
			for y in range(map.get_height()):
				for x in range(map.get_width()):
					if Rules.tile_is_blocked(session, x, y):
						runtime_blocked.append({"x": x, "y": y})
			result["runtime_blocked"] = runtime_blocked
			result["hero_tile_blocked"] = Rules.tile_is_blocked(session, pos.x, pos.y)
			if OS.get_environment("HEROES_RMG_AUDIT_ENTRANCE") == "1":
				result["entrance_actions"] = exercise_entrance(session, out.path_join(String(case.id) + "_session.json"))
			if OS.get_environment("HEROES_RMG_AUDIT_RENDER") == "1":
				var map_path := "user://audit_" + String(case.id) + ".amap"
				var scenario_path := "user://audit_" + String(case.id) + ".ascenario"
				var map_save: Dictionary = service.save_map_package(map, map_path)
				var map_load: Dictionary = service.load_map_package(map_path)
				scenario.configure({"scenario_id": scenario.get_scenario_id(), "scenario_hash": scenario.get_scenario_hash(), "map_ref": map_load.map_ref, "selection": scenario.get_selection(), "player_slots": scenario.get_player_slots(), "objectives": scenario.get_objectives(), "script_hooks": scenario.get_script_hooks(), "enemy_factions": scenario.get_enemy_factions(), "start_contract": scenario.get_start_contract()})
				var scenario_save: Dictionary = service.save_scenario_package(scenario, scenario_path)
				var scenario_load: Dictionary = service.load_scenario_package(scenario_path)
				var boundary: Dictionary = adoption.session_boundary_record.duplicate(true)
				boundary["map_package_path"] = map_path
				boundary["scenario_package_path"] = scenario_path
				boundary["map_package_ref"] = map_load.map_ref
				boundary["scenario_package_ref"] = scenario_load.scenario_ref
				session = Bridge.build_session_from_loaded_packages(map_load, scenario_load, boundary)
				var persisted := {"map_ref": map_load.map_ref, "scenario_ref": scenario_load.scenario_ref, "map_path": map_path, "scenario_path": scenario_path}
				session.flags["generated_random_map_provenance"] = Selection._native_random_map_provenance(config, generated, adoption, persisted, {"attempt_count": 1})
				session.flags["generated_random_map_package_paths"] = {"map_path": map_path, "scenario_path": scenario_path}
				result["disk_roundtrip"] = {"ok": bool(map_save.get("ok", false)) and bool(scenario_save.get("ok", false)), "position_preserved": session.overworld.hero_position == result.hero_position}
				SessionState.active_session = session
				var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
				add_child(shell)
				for frame in range(12):
					await get_tree().process_frame
				result["briefing_autosave"] = shell._last_briefing_consumption_autosave_result.duplicate(true)
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(out.path_join(String(case.id) + ".png"))
				shell.queue_free()
				await get_tree().process_frame
		result["elapsed_ms"] = Time.get_ticks_msec() - started
		var file := FileAccess.open(out.path_join(String(case.id) + ".json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(result))
		file.close()
		print("RMG_AUDIT_CASE " + JSON.stringify({"id": case.id, "ok": result.ok, "elapsed_ms": result.elapsed_ms, "error_code": result.error_code}))
	get_tree().quit(0)

func exercise_entrance(session, save_path: String) -> Dictionary:
	var start := Rules.hero_position(session)
	var entered: Dictionary = Rules._resolve_post_move_interaction(session)
	Rules.clear_active_town_visit(session)
	var away := {}
	var returned := {}
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var target := start + Vector2i(dx, dy)
			if (dx == 0 and dy == 0) or Rules.tile_is_blocked(session, target.x, target.y) or Rules.tile_has_route_interaction(session, target.x, target.y) or Rules.tile_step_cuts_blocked_corner(session, start, target):
				continue
			away = Rules.try_move(session, dx, dy)
			if bool(away.get("ok", false)) and Rules.hero_position(session) != start:
				returned = Rules.try_move(session, -dx, -dy)
				break
		if not returned.is_empty():
			break
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(session.to_dict()))
	file.close()
	var restored = Store.new_session_data()
	restored.from_dict(JSON.parse_string(FileAccess.get_file_as_string(save_path)))
	Rules.normalize_overworld_state(restored)
	var restored_entry: Dictionary = Rules._resolve_post_move_interaction(restored)
	var view = MapView.new()
	var town_anchor_matches := true
	for town in session.overworld.get("towns", []):
		var visit: Dictionary = town.get("visit_tile", town)
		town_anchor_matches = town_anchor_matches and view._town_entry_tile(town) == Vector2i(int(visit.x), int(visit.y))
	view.free()
	return {"initial_town_route": entered.get("route", ""), "exit_ok": bool(away.get("ok", false)) and not returned.is_empty(), "return_ok": bool(returned.get("ok", false)) and returned.get("route", "") == "town" and Rules.hero_position(session) == start, "restored_position": restored.overworld.hero_position, "restored_town_route": restored_entry.get("route", ""), "initial_result": entered, "exit_message": away.get("message", ""), "return_message": returned.get("message", ""), "town_visual_anchors_match": town_anchor_matches, "corner_controls": exercise_corner_contract()}

func exercise_corner_contract() -> Dictionary:
	var town := {"placement_id": "corner_town", "x": 1, "y": 1, "visit_tile": {"x": 1, "y": 1}, "package_block_tiles": [{"x": 1, "y": 1}, {"x": 2, "y": 1}]}
	var obstacle := {"placement_id": "corner_rock", "kind": "decorative_obstacle", "package_block_tiles": [{"x": 1, "y": 2}]}
	var fixture = Store.new_session_data("entrance_corner_controls", "", "", 1, {"map": [["grass", "grass", "grass"], ["grass", "grass", "grass"], ["grass", "grass", "grass"]], "map_size": {"width": 3, "height": 3}, "towns": [town], "map_objects": [obstacle]})
	Rules.invalidate_spatial_lookup(fixture)
	Rules._refresh_blocked_tile_index(fixture)
	var opens: bool = not Rules.tile_step_cuts_blocked_corner(fixture, Vector2i(1, 1), Vector2i(2, 2))
	var ingress: bool = not Rules.tile_step_cuts_blocked_corner(fixture, Vector2i(2, 2), Vector2i(1, 1))
	var bodies_preserved: bool = Rules.tile_is_blocked(fixture, 1, 1) and Rules.tile_is_blocked(fixture, 2, 1) and Rules.tile_is_blocked(fixture, 1, 2)
	fixture.overworld.map_objects.append({"placement_id": "overlapping_rock", "kind": "decorative_obstacle", "package_block_tiles": [{"x": 2, "y": 1}]})
	Rules._refresh_blocked_tile_index(fixture)
	var overlap_blocks: bool = Rules.tile_step_cuts_blocked_corner(fixture, Vector2i(1, 1), Vector2i(2, 2))
	fixture.overworld.map_objects.pop_back()
	fixture.overworld.towns[0].erase("visit_tile")
	Rules.invalidate_spatial_lookup(fixture)
	Rules._refresh_blocked_tile_index(fixture)
	var ordinary_blocks: bool = Rules.tile_step_cuts_blocked_corner(fixture, Vector2i(1, 1), Vector2i(2, 2))
	return {"doorway_egress": opens, "doorway_ingress": ingress, "bodies_preserved": bodies_preserved, "unrelated_overlap_blocks": overlap_blocks, "ordinary_corner_blocks": ordinary_blocks}
'''


def point(value: dict) -> tuple[int, int, int]:
    return int(value["x"]), int(value["y"]), int(value.get("level", 0))


def distances(start, width, height, blocked):
    """Fixed-body eight-way diagnostic; does not model town doorway passages."""
    result = {start: 0}
    queue = deque([start])
    while queue:
        x, y, z = queue.popleft()
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                target = x + dx, y + dy, z
                if not (dx or dy) or target in result or target in blocked:
                    continue
                if not (0 <= target[0] < width and 0 <= target[1] < height):
                    continue
                if dx and dy and (x + dx, y, z) in blocked and (x, y + dy, z) in blocked:
                    continue
                result[target] = result[x, y, z] + 1
                queue.append(target)
    return result


def analyze(raw):
    row = {k: raw.get(k) for k in ("id", "ok", "error_code", "payload_fnv1a32", "elapsed_ms", "hero_position", "hero_id", "hero_tile_blocked", "hero_blocking_body_owners", "entrance_actions")}
    if not raw.get("ok"):
        return row
    size = raw["map_size"]
    width, height = size["width"], size["height"]
    objects = raw["objects"]
    by_id = {o["placement_id"]: o for o in objects}
    blocked = set()
    for z, codes in enumerate(raw["terrain"]["terrain"]["levels"]):
        blocked.update((i % width, i // width, z) for i, code in enumerate(codes) if (code & 63) in (8, 9))
    for obj in objects:
        blocked.update(point(p) for p in obj.get("package_body_tiles", []))
    starts = []
    for start in raw["start_contract"]["player_starts"]:
        town = point(start)
        hero = point(start["hero_start_tile"])
        routes = distances(hero, width, height, blocked - {town})
        starts.append({"owner": start["owner"], "slot": start["player_slot"], "town": town, "hero": hero, "manhattan_displacement": abs(hero[0]-town[0])+abs(hero[1]-town[1]), "selection_source": start["hero_start_tile"]["selection_source"], "town_entrance_route_steps": routes.get(town), "town_binding_exists": start["town_placement_id"] in by_id, "town_entrance_body_owners": [o["placement_id"] for o in objects if town in {point(p) for p in o.get("package_body_tiles", [])}], "reachable_cells_with_town_destination_open": len(routes)})
    row.update(starts=starts, object_count=len(objects), object_levels=dict(Counter(o.get("level", 0) for o in objects)), first_step_count=len(raw["unblocked_first_steps"]), runtime_enemy_state_count=len(raw["enemy_states"]), runtime_enemy_factions=[e.get("faction_id") for e in raw["enemy_states"]], expected_enemy_slots=sum(s["owner"] == "enemy" for s in starts), runtime_town_count=len(raw["towns"]))
    hero = point(raw["hero_position"])
    live_routes = distances(hero, width, height, {point(p) for p in raw["runtime_blocked"]})
    row["runtime_reachable_cells"] = len(live_routes)
    row["player_town_routes"] = []
    for town in raw["towns"]:
        if town.get("owner") != "player":
            continue
        entrance = point(town.get("visit_tile") or town)
        flattened = (entrance[0], entrance[1], 0)
        routes = distances(hero, width, height, {point(p) for p in raw["runtime_blocked"]} - {flattened})
        row["player_town_routes"].append({"placement_id": town["placement_id"], "town_level_field": town.get("level"), "entrance": entrance, "steps_with_destination_open": routes.get(flattened)})
    return row


def case(case_id, size, levels, water, seed, players=2, strength="weak"):
    names = {36: "small", 72: "medium", 108: "large", 144: "homm3_extra_large"}
    return {"id": case_id, "config": {"seed": str(seed), "size": {"width": size, "height": size, "level_count": levels, "water_mode": water, "size_class_id": names[size]}, "monster_strength": strength, "player_constraints": {"human_count": 1, "computer_count": players-1, "player_count": players, "human_team_count": 1, "computer_team_count": 0}}}


def matrix():
    rows = [case(f"matrix_{size}_{levels}_{water}", size, levels, water, 1) for size in (36, 72, 108, 144) for levels in (1, 2) for water in ("land", "normal_water", "islands")]
    rows += [case("ordinal95", 72, 1, "land", 165429308, 4), case("medium_seed10", 72, 1, "land", 10), case("small_seed68", 36, 2, "land", 68), case("xlarge_seed77", 144, 2, "normal_water", 77)]
    rows += [case(f"players_{n}", 72, 1, "land", 10, n) for n in (3, 6, 8)]
    rows += [case(f"strength_{s}", 36, 1, "land", 1, 2, s) for s in ("normal", "strong", "random", "impossible")]
    rows.append(case("medium_seed10_repeat", 72, 1, "land", 10))
    return rows


def entrance_failures(rows):
    failures = []
    for row in rows:
        if not row["ok"]:
            if row.get("error_code") != "native_rmg_monster_strength_unsupported":
                failures.append({"id": row["id"], "reason": "generation_failed"})
            continue
        starts = row["starts"]
        if not starts or any(tuple(s["town"]) != tuple(s["hero"]) or not s["town_binding_exists"] for s in starts):
            failures.append({"id": row["id"], "reason": "native_entrance_contract"})
        primary = next((s for s in starts if s["owner"] == "player"), None)
        if primary is None:
            failures.append({"id": row["id"], "reason": "primary_start_missing"})
            continue
        if point(row["hero_position"]) != tuple(primary["town"]):
            failures.append({"id": row["id"], "reason": "live_entrance_or_level_lost"})
        if any(o["family"] != "towns" for o in row["hero_blocking_body_owners"]):
            failures.append({"id": row["id"], "reason": "non_town_body_on_start"})
        actions = row.get("entrance_actions") or {}
        if not actions.get("town_visual_anchors_match"):
            failures.append({"id": row["id"], "reason": "town_visual_entrance_mismatch"})
        if not (actions.get("initial_town_route") == "town" and actions.get("exit_ok") and actions.get("return_ok") and actions.get("restored_town_route") == "town" and point(actions["restored_position"]) == tuple(primary["town"])):
            failures.append({"id": row["id"], "reason": "live_move_town_save_roundtrip", "actions": actions})
        controls = actions.get("corner_controls", {})
        if not all(controls.get(k) for k in ("doorway_egress", "doorway_ingress", "bodies_preserved", "unrelated_overlap_blocks", "ordinary_corner_blocks")):
            failures.append({"id": row["id"], "reason": "town_corner_contract", "controls": controls})
    return failures


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--label", default="matrix")
    parser.add_argument("--case", help="Comma-separated case IDs; default all sampled cases")
    parser.add_argument("--render", action="store_true")
    parser.add_argument("--require-entrance-starts", action="store_true", help="Exercise live entry/exit/return/save and fail on any entrance/layer violation")
    parser.add_argument("--analyze-only", action="store_true")
    args = parser.parse_args()
    if not args.label or any(c not in "abcdefghijklmnopqrstuvwxyz0123456789_-" for c in args.label):
        parser.error("label must be a safe single path component")
    out = OUTPUT / args.label
    cases = [r for r in matrix() if not args.case or r["id"] in args.case.split(",")]
    if not cases:
        parser.error("no matching cases")
    revision = "unrecorded_retained_run"
    if not args.analyze_only:
        revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    elif (out / "summary.json").exists():
        revision = json.loads((out / "summary.json").read_text()).get("revision", revision)
    if not args.analyze_only:
        out.mkdir(parents=True, exist_ok=False)
        (out / "cases.json").write_text(json.dumps(cases, indent=2) + "\n")
        with tempfile.TemporaryDirectory(prefix="adapter-", dir=OUTPUT) as temp:
            work = Path(temp)
            script = work / "probe.gd"
            script.write_text(PROBE)
            scene = work / "probe.tscn"
            scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="Audit" type="Node"]\nscript = ExtResource("1")\n' % script.relative_to(ROOT))
            env = dict(os.environ, XDG_DATA_HOME=str(out / "data"), HEROES_RMG_AUDIT_OUTPUT=str(out), HEROES_RMG_AUDIT_RENDER="1" if args.render else "0", HEROES_RMG_AUDIT_ENTRANCE="1" if args.require_entrance_starts else "0", HEROES_PROFILE_LOG="0")
            cmd = [shutil.which("godot4") or "godot", "--path", str(ROOT), "--audio-driver", "Dummy", "--accessibility", "disabled", "--resolution", "1280x720", "res://" + str(scene.relative_to(ROOT))]
            cmd = ["dbus-run-session", "--", "xvfb-run", "-a"] + cmd if args.render else cmd + ["--headless"]
            with (out / "runtime.log").open("w") as log:
                run = subprocess.run(["timeout", "2400s"] + cmd, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=2420)
            if run.returncode:
                print(f"adapter failed ({run.returncode}); see {out / 'runtime.log'}")
                return 1
    rows = [analyze(json.loads((out / (c["id"] + ".json")).read_text())) for c in cases]
    errors = [line for line in (out / "runtime.log").read_text().splitlines() if line.startswith(("ERROR:", "SCRIPT ERROR:")) or "leaked" in line]
    report = {"audit_collected": not errors, "runtime_errors": errors, "revision": revision, "note": "Diagnostic graphs hold body masks fixed and open the town destination. They do not simulate guard battles, removable objects, transit or legal interaction approach. Not H3MapEd parity or a full town-access proof.", "cases": rows}
    if args.require_entrance_starts:
        report["entrance_failures"] = entrance_failures(rows)
        report["entrance_regression_ok"] = not report["entrance_failures"]
    (out / "summary.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"audit_collected": report["audit_collected"], "cases": len(rows), "generated": sum(bool(r["ok"]) for r in rows), "output": str(out)}))
    return 0 if report["audit_collected"] and report.get("entrance_regression_ok", True) else 1


if __name__ == "__main__":
    raise SystemExit(main())
