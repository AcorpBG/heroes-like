#!/usr/bin/env python3
"""Legal generated-match scene driver; terminal outcomes, not turn limits, pass."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import resource
import signal
import subprocess
import sys
import tempfile
from time import monotonic

from full_play_runtime_profile import ROOT, summarize

OUTPUT = ROOT / '.artifacts/generated_full_match_quality_20260906'
CASES = {
    'medium': {'seed': '10', 'size': 'homm3_medium', 'players': 2, 'faction': 'faction_embercourt', 'hero': ''},
    'large': {'seed': 'large-runtime-profile-10225', 'size': 'homm3_large', 'players': 4, 'faction': 'faction_veilmourn', 'hero': 'hero_veilmourn_orso_nightchart'},
}
MARKER = 'GENERATED_FULL_MATCH_REPORT '

SCRIPT = r'''
extends Node
const Setup = preload("res://scripts/core/ScenarioSelectRules.gd")
const Heroes = preload("res://scripts/core/HeroCommandRules.gd")
const Levels = preload("res://scripts/core/OverworldLevelRules.gd")
const Transit = preload("res://scripts/core/NativeTransitRules.gd")
var session
var out := ""
var cfg := {}
var failures := []
var counts := {}
var failed_targets := {}
var last_town_day := {}
var read_signs := {}
var waypoint_visits := {}
var active_target := {}
var action_file: FileAccess
var checkpoint_count := 0
var checkpoint_labels := []
var serial := 0
var last_progress_day := 1

func _ready() -> void:
	call_deferred("run_match")

func scene_path() -> String:
	var scene = get_tree().current_scene
	return String(scene.scene_file_path) if scene != null else ""

func settle() -> void:
	for frame in range(6):
		await get_tree().process_frame
	var started := Time.get_ticks_msec()
	while true:
		var scene = get_tree().current_scene
		var town_busy: bool = scene != null and scene_path().ends_with("TownShell.tscn") and scene._town_action_input_blocker.visible
		var battle_busy: bool = scene != null and scene_path().ends_with("BattleShell.tscn") and scene._battle_exit_handoff_in_progress
		if not town_busy and not battle_busy:
			break
		if Time.get_ticks_msec() - started > 30000:
			failures.append("battle exit handoff did not finish" if battle_busy else "town action input blocker did not clear")
			break
		await get_tree().process_frame

func power(stacks: Variant) -> int:
	return OverworldRules._army_strength_value(stacks)

func player_power() -> int:
	return power(Heroes.active_hero(session).get("army", {}).get("stacks", []))

func capacity_snapshot() -> Dictionary:
	# Observation only: never truncate or normalize an oversized match army.
	var holders := []
	for hero in session.overworld.get("player_heroes", []):
		holders.append({"id":"hero:"+String(hero.get("id","")),"stacks":hero.get("army",{}).get("stacks",[])})
	for town in session.overworld.get("towns", []):
		holders.append({"id":"town:"+String(town.get("placement_id","")),"stacks":town.get("garrison",[])})
	for encounter in session.overworld.get("encounters", []):
		if not bool(encounter.get("resolved",false)) and encounter.has("enemy_army"):
			holders.append({"id":"encounter:"+String(encounter.get("placement_id","")),"stacks":encounter.enemy_army.get("stacks",[])})
	for enemy in session.overworld.get("enemy_states", []):
		for commander in enemy.get("commander_roster", []):
			holders.append({"id":"commander:%s:%s" % [String(enemy.get("player_id",enemy.get("faction_id",""))),String(commander.get("roster_hero_id",""))],"stacks":commander.get("army_continuity",{}).get("stacks",[])})
	var violations := []
	for holder in holders:
		var occupied := 0
		for stack in holder.stacks:
			if stack is Dictionary and String(stack.get("unit_id",""))!="" and int(stack.get("count",0))>0:
				occupied += 1
		if occupied>Heroes.ARMY_SLOT_COUNT:
			violations.append({"id":holder.id,"stack_count":occupied})
	return {"ok":violations.is_empty(),"holders_checked":holders.size(),"violations":violations}

func compact_state() -> Dictionary:
	var pos := OverworldRules.hero_position(session)
	var towns := []
	for town in session.overworld.get("towns", []):
		# Report may inspect full state; the action policy below uses explored targets only.
		towns.append({"id": town.get("placement_id", ""), "owner": town.get("owner", ""), "built": town.get("built_buildings", [])})
	return {"day": session.day, "status": session.scenario_status, "scene": scene_path(), "hero": {"x":pos.x,"y":pos.y,"level":Levels.hero_level(session)}, "movement":session.overworld.get("movement", {}), "army_power":player_power(), "army_capacity":capacity_snapshot(), "resources":session.overworld.get("resources", {}), "towns":towns}

func record(kind: String, started: int, result: Dictionary = {}) -> void:
	serial += 1
	counts[kind] = int(counts.get(kind, 0)) + 1
	var row := {"serial":serial,"kind":kind,"wall_ms":float(Time.get_ticks_usec()-started)/1000.0,"result":result,"state":compact_state()}
	if kind in ["save_resume", "end_turn"]:
		row["driver_state"] = {"version":1,"last_progress_day":last_progress_day,"failed_targets":failed_targets,"last_town_day":last_town_day,"read_signs":read_signs,"waypoint_visits":waypoint_visits,"active_target":active_target}
	action_file.store_line(JSON.stringify(row))
	action_file.flush()
	print("GENERATED_FULL_MATCH_ACTION " + JSON.stringify({"serial":serial,"kind":kind,"day":session.day,"wall_ms":row.wall_ms,"result":result}))

func screenshot(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(label + ".png"))

func resolve_routes() -> void:
	await settle()
	for attempt in range(12):
		var scene = get_tree().current_scene
		if scene == null:
			await settle()
			continue
		if scene_path().ends_with("BattleShell.tscn"):
			if int(counts.get("battle", 0)) < 2:
				await screenshot("battle_%02d" % int(counts.get("battle", 0)))
			var started := Time.get_ticks_usec()
			var request: Dictionary = scene.validation_request_quick_resolve_confirmation()
			await settle()
			var result: Dictionary = scene.validation_confirm_quick_resolve_confirmation()
			await settle()
			record("battle",started,{"request_ok":request.get("ok",false),"performed":result.get("performed",false)})
			if not bool(request.get("ok",false)) or not bool(result.get("performed",false)):
				failures.append("shipped Quick Resolve failed")
				return
		elif scene_path().ends_with("BattleReportShell.tscn"):
			if int(counts.get("battle_report",0)) < 2:
				await screenshot("casualties_%02d" % int(counts.get("battle_report",0)))
			var started := Time.get_ticks_usec()
			scene.get_node("%Continue").pressed.emit()
			var result: Dictionary = scene._last_continue_result.duplicate(true)
			await settle()
			record("battle_report",started,{"ok":result.get("ok",false)})
			if not bool(result.get("ok",false)):
				failures.append("required battle report save failed")
				return
		else:
			return
	failures.append("battle/outcome routing did not settle")

func checkpoint(label: String, slot: int) -> void:
	var started := Time.get_ticks_usec()
	var payload: Dictionary = session.to_dict()
	var path := SaveService.save_session(payload, slot)
	var loaded: Dictionary = SaveService.load_session(slot)
	var restored = SessionState.restore_session(loaded)
	# JSON is the save contract. Native Variants include typed/packed containers;
	# compare every serialized field without dropping gameplay or metadata keys.
	var equal: bool = restored != null and JSON.parse_string(JSON.stringify(restored.to_dict())) == JSON.parse_string(JSON.stringify(payload))
	if path == "" or not equal:
		for item in [["expected",payload],["loaded",loaded],["restored",restored.to_dict() if restored != null else {}]]:
			var evidence := FileAccess.open(out.path_join(label + "_save_" + String(item[0]) + ".json"),FileAccess.WRITE)
			evidence.store_string(JSON.stringify(item[1]))
			evidence.close()
		failures.append("complete save/restore state mismatch: " + label)
		return
	session = restored
	AppRouter.resume_active_session()
	await resolve_routes()
	checkpoint_count += 1
	checkpoint_labels.append(label)
	record("save_resume",started,{"label":label,"complete_state_equal":equal,"slot":slot,"save_sha256":FileAccess.get_sha256(path)})

func town_orders() -> void:
	var scene = get_tree().current_scene
	var town: Dictionary = TownRules.get_active_town(session)
	var id := String(town.get("placement_id", ""))
	last_town_day[id] = session.day
	if session.day == 1 or session.day >= 14 and int(counts.get("developed_town_capture",0)) == 0:
		await screenshot("town_day_%03d" % session.day)
		if session.day >= 14:
			counts["developed_town_capture"] = 1
	# The shipped catalog determines eligibility and normal costs. Never inject stock.
	for lane in ["specialty", "build", "recruit", "study"]:
		var used := {}
		for attempt in range(12 if lane in ["recruit", "specialty"] else 1):
			var catalog: Dictionary = scene.validation_action_catalog()
			var selected := ""
			var choices: Array = catalog.get(lane, []).duplicate()
			if lane == "build":
				# Invest in ordinary recruitment access before optional services.
				choices.sort_custom(func(a,b):return String(a.id) < String(b.id) if build_priority(a) == build_priority(b) else build_priority(a) < build_priority(b))
			for action in choices:
				if not bool(action.get("disabled",true)) and not used.has(String(action.id)):
					selected = String(action.id)
					break
			if selected == "":
				break
			if lane != "specialty":
				used[selected] = true
			var started := Time.get_ticks_usec()
			var result: Dictionary = scene.validation_perform_town_action(selected)
			await settle()
			record("town_"+lane,started,{"id":selected,"ok":result.get("ok",false),"message":result.get("message","")})
			if not bool(result.get("ok",false)):
				failures.append("enabled town action failed: " + selected)
				break
	var started := Time.get_ticks_usec()
	var leave: Dictionary = scene.validation_leave_town()
	await resolve_routes()
	record("town_exit",started,{"ok":leave.get("ok",false)})

func build_priority(action: Dictionary) -> int:
	var id := String(action.get("id","")).trim_prefix("build:")
	var building: Dictionary = ContentService.get_building(id)
	if String(building.get("unlock_unit_id","")) != "":
		return 0
	if id == "building_market_square":
		return 1
	return 2

func known(row: Dictionary) -> bool:
	if not Levels.on_level(row,Levels.hero_level(session)):
		return false
	if OverworldRules.is_tile_visible(session,int(row.get("x",-1)),int(row.get("y",-1))):
		return true
	if row.has("encounter_id"):
		return OverworldRules._guard_engagement_world_tiles(row).any(func(tile):return OverworldRules.is_tile_visible(session,tile.x,tile.y))
	return false

func guard_approach(encounter: Dictionary) -> Vector2i:
	# The planner stops on the first combat square; the center of a 3x3 guard
	# zone is not directly routable through its other interaction squares.
	var origin := OverworldRules.hero_position(session)
	var best := Vector2i(-1,-1)
	var best_distance := 1000000
	var tiles: Array = OverworldRules._guard_engagement_world_tiles(encounter)
	if tiles.is_empty():
		tiles = [Vector2i(int(encounter.x),int(encounter.y))]
	for tile in tiles:
		if not OverworldRules.is_tile_visible(session,tile.x,tile.y):
			continue
		var path: Array = get_tree().current_scene._build_path(origin,tile)
		if not path.is_empty() and path.size() < best_distance and path.all(func(point):return OverworldRules.is_tile_visible(session,point.x,point.y)):
			best = tile
			best_distance = path.size()
	return best

func resource_claim_feasible(node: Dictionary) -> bool:
	# The same admission/cost authority as the live claim control. Re-read every
	# selection: a later merge, transfer or reward can change eligibility.
	if Transit.is_native(node):
		return true
	var site: Dictionary = ContentService.get_resource_site(String(node.get("site_id","")))
	return bool(Heroes.army_addition_plan(session.overworld.get("army",{}).get("stacks",[]),OverworldRules._resource_site_claim_recruits(site)).get("ok",false)) and OverworldRules._can_afford(session,OverworldRules._resource_site_visit_cost(site))

func target_precedes(a: Dictionary, b: Dictionary) -> bool:
	# Intent is only an id, never a stale position or a bypass of today's
	# visibility, availability, risk, admission and legal-path checks.
	var a_current: bool = a.id == active_target.get("id","")
	var b_current: bool = b.id == active_target.get("id","")
	if a_current != b_current:
		return a_current
	return a.id < b.id if is_equal_approx(a.score,b.score) else a.score < b.score

func choose_target() -> Dictionary:
	var scene = get_tree().current_scene
	var origin := OverworldRules.hero_position(session)
	var candidates := []
	for kind in ["resource","artifact","encounter","town"]:
		for target in scene._validation_targets(kind):
			if not known(target):
				continue
			var id := String(target.get("placement_id",""))
			if int(failed_targets.get(id,0)) >= session.day:
				continue
			# Native town x/y is the art anchor, not its legal visit square.
			var entry: Dictionary = target.get("visit_tile", target)
			var tile := Vector2i(int(entry.x),int(entry.y))
			if kind == "encounter":
				tile = guard_approach(target)
				if tile.x < 0:
					continue
			# A resource/portal can occupy a visible guard's engagement square.
			# Apply the same risk check as for clicking the guard itself.
			var guard: Dictionary = OverworldRules.guard_engagement_encounter_at_tile(session,tile.x,tile.y)
			if not guard.is_empty() and known(guard) and power(OverworldRules._encounter_army_payload(guard).get("stacks",[])) > player_power() * 0.70:
				continue
			var distance := origin.distance_to(tile)
			var score := distance
			if kind == "encounter":
				var enemy := power(OverworldRules._encounter_army_payload(target).get("stacks",[]))
				if enemy > player_power() * 0.70:
					continue
				score += 8.0
			elif kind == "town":
				if String(target.get("owner","")) == "player":
					if int(last_town_day.get(id,0)) >= session.day:
						continue
					# The live owned-town roster supports remote management.
					return {"id":id,"kind":"town","tile":tile,"remote":true}
				else:
					if session.day < 8 or power(target.get("garrison",[])) > player_power() * 0.70:
						continue
					score -= 10.0
			elif kind == "resource":
				var site: Dictionary = ContentService.get_resource_site(String(target.get("site_id","")))
				if read_signs.has(id) or not resource_claim_feasible(target):
					continue
				if bool(site.get("persistent_control",false)):
					score -= 4.0
			candidates.append({"id":id,"kind":kind,"tile":tile,"score":score,"record":target})
	candidates.sort_custom(target_precedes)
	for candidate in candidates:
		if candidate.tile == origin:
			return candidate
		var path: Array = scene._build_path(origin,candidate.tile)
		if path.is_empty():
			failed_targets[candidate.id] = session.day
			continue
		var explored := true
		for tile in path:
			if not OverworldRules.is_tile_visible(session,tile.x,tile.y):
				explored = false
				break
		if explored:
			return candidate
	# Explore only currently revealed tiles bordering unknown territory.
	var map_size: Vector2i = OverworldRules.derive_map_size(session)
	var frontier := []
	for y in range(map_size.y):
		for x in range(map_size.x):
			var tile := Vector2i(x,y)
			if tile == origin or not OverworldRules.is_tile_visible(session,x,y) or OverworldRules.tile_is_blocked(session,x,y) or OverworldRules.tile_has_route_interaction(session,x,y):
				continue
			var unknown := 0
			for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var near: Vector2i = tile + direction
				if near.x >= 0 and near.y >= 0 and near.x < map_size.x and near.y < map_size.y and not OverworldRules.is_tile_visible(session,near.x,near.y):
					unknown += 1
			if unknown > 0:
				frontier.append({"id":"explore:%d:%d"%[x,y],"kind":"explore","tile":tile,"score":origin.distance_to(tile)-float(unknown)})
	frontier.sort_custom(target_precedes)
	for target in frontier:
		if int(failed_targets.get(target.id,0)) >= session.day:
			continue
		var path: Array = scene._build_path(origin,target.tile)
		if not path.is_empty() and path.all(func(tile):return OverworldRules.is_tile_visible(session,tile.x,tile.y)):
			return target
	# The live planner stops at interactions, including owned mines and signs.
	# Backtrack through any reachable visited entrance, not only adjacent ones:
	# a depleted pocket can have its exit several open tiles away.
	var waypoints := []
	for node in session.overworld.get("resource_nodes",[]):
		if not known(node) or (String(node.get("collected_by_faction_id","")) != "player" and not read_signs.has(String(node.get("placement_id","")))):
			continue
		var entry: Dictionary = node.get("visit_tile",node)
		var tile := Vector2i(int(entry.x),int(entry.y))
		var id := "waypoint:" + String(node.get("placement_id",""))
		if tile == origin or int(failed_targets.get(id,0)) >= session.day:
			continue
		var path: Array = scene._build_path(origin,tile)
		if not path.is_empty() and path.all(func(point):return OverworldRules.is_tile_visible(session,point.x,point.y)):
			waypoints.append({"id":id,"kind":"waypoint","tile":tile,"score":int(waypoint_visits.get(id,0))})
	waypoints.sort_custom(func(a,b):return a.id < b.id if a.score == b.score else a.score < b.score)
	if not waypoints.is_empty():
		return waypoints[0]
	return {}

func perform_target(target: Dictionary) -> void:
	var scene = get_tree().current_scene
	var origin := OverworldRules.hero_position(session)
	var explored_before := int(session.overworld.get("fog",{}).get("explored_count",0))
	var resolved_before: int = session.overworld.get("resolved_encounters",[]).size()
	var started := Time.get_ticks_usec()
	if bool(target.get("remote",false)):
		scene._on_town_rail_pressed(target.tile.x,target.tile.y,Levels.hero_level(session))
		# At the entrance use the primary order. Away from town use the same
		# management handler as a click on the owned town's scenic body.
		var result: Dictionary = scene.validation_perform_primary_action() if origin == target.tile else {"ok":scene._visit_selected_town(),"input":"owned town body management handler"}
		await resolve_routes()
		record("target_town",started,{"id":target.id,"remote":true,"routed":scene_path().ends_with("TownShell.tscn"),"action":result})
		if not scene_path().ends_with("TownShell.tscn"):
			failures.append("owned-town roster/primary order did not open Town")
		return
	# Actual pointer selection/activation path, not the omniscient validation BFS.
	active_target = {"id":target.id,"kind":target.kind}
	scene._on_map_tile_pressed(target.tile)
	await resolve_routes()
	if scene_path().ends_with("OverworldShell.tscn") and OverworldRules.hero_position(session) == origin:
		get_tree().current_scene._on_map_tile_pressed(target.tile)
		await resolve_routes()
	# Arrival can reveal a guard or an interaction rather than auto-executing it.
	# Activate the same enabled primary order a player sees; do not mark arrival
	# as collection or victory, and do not bypass the guarded-site context.
	if scene_path().ends_with("OverworldShell.tscn") and OverworldRules.hero_position(session) == target.tile:
		var current = get_tree().current_scene
		var primary: Dictionary = current._current_primary_action()
		if String(primary.get("id","")) in ["enter_battle","visit_town","capture_town","collect_resource","collect_artifact"] and not bool(primary.get("disabled",false)):
			current.validation_perform_primary_action()
			await resolve_routes()
	var moved := OverworldRules.hero_position(session) != origin
	if target.kind == "waypoint":
		waypoint_visits[target.id] = serial
	var routed := not scene_path().ends_with("OverworldShell.tscn")
	if int(session.overworld.get("fog",{}).get("explored_count",0)) > explored_before or session.overworld.get("resolved_encounters",[]).size() > resolved_before or routed:
		last_progress_day = session.day
	if not moved and not routed:
		failed_targets[target.id] = session.day
	if not moved or routed or OverworldRules.hero_position(session) == target.tile:
		active_target.clear()
	if target.kind == "resource":
		var node: Dictionary = target.get("record",{})
		if Transit.is_native(node) and moved:
			# Do not spend every turn shuttling between an already explored pair.
			failed_targets[target.id] = session.day + 7
			for destination in Transit.destinations(node):
				failed_targets[String(destination.get("target_placement_id",""))] = session.day + 7
		elif OverworldRules.hero_position(session) == target.tile:
			var site: Dictionary = ContentService.get_resource_site(String(node.get("site_id","")))
			if String(site.get("batch003_role","")) == "sign_waypoint" or String(site.get("batch004_role","")) == "route_waypoint":
				read_signs[target.id] = true
	var context := {}
	if scene_path().ends_with("OverworldShell.tscn"):
		context = {"primary":get_tree().current_scene._current_primary_action(),"active_type":OverworldRules.get_active_context(session).get("type","")}
	record("target_"+String(target.kind),started,{"id":target.id,"moved":moved,"routed":routed,"context":context,"message":get_tree().current_scene.get("_last_message") if scene_path().ends_with("OverworldShell.tscn") else ""})

func run_match() -> void:
	get_tree().current_scene = null
	out = OS.get_environment("HEROES_FULL_MATCH_OUTPUT")
	cfg = JSON.parse_string(OS.get_environment("HEROES_FULL_MATCH_CONFIG"))
	var action_path := out.path_join("actions.jsonl")
	action_file = FileAccess.open(action_path,FileAccess.READ_WRITE if FileAccess.file_exists(action_path) else FileAccess.WRITE)
	action_file.seek_end()
	SettingsService.set_presentation_mode("windowed")
	SettingsService.set_presentation_resolution(OS.get_environment("HEROES_FULL_MATCH_RESOLUTION"))
	var started := Time.get_ticks_usec()
	if cfg.has("resume"):
		var resume: Dictionary = cfg.resume
		var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(out.path_join("resume.json")))
		# Use production load admission, including saved generated-scenario
		# registration, then observe the actual active instance returned by it.
		var copy_path := SaveService.save_session(payload,1)
		session = SaveService.restore_manual_session(1) if copy_path != "" else null
		if session != null:
			session = SessionState.set_active_session(session)
		for key in ["saved_at_unix","save_slot_type","saved_from_game_state","saved_from_scenario_status","saved_from_launch_mode"]:
			payload.erase(key)
		if session == null or JSON.parse_string(JSON.stringify(session.to_dict())) != payload:
			print("GENERATED_FULL_MATCH_REPORT "+JSON.stringify({"ok":false,"failures":["resume checkpoint gameplay state mismatch"]}))
			get_tree().quit(1)
			return
		counts = resume.counts
		checkpoint_labels = resume.checkpoint_labels
		checkpoint_count = checkpoint_labels.size()
		serial = int(resume.serial)
		last_progress_day = int(resume.last_progress_day)
		read_signs = resume.read_signs
		last_town_day = resume.last_town_day
		failed_targets = resume.failed_targets
		waypoint_visits = resume.waypoint_visits
		active_target = resume.active_target
		AppRouter.resume_active_session()
		await resolve_routes()
		record("resume_segment",started,{"source":resume.source,"save_sha256":resume.save_sha256})
	else:
		var config: Dictionary = Setup.build_random_map_player_config(cfg.seed,"translated_rmg_template_042_v1","translated_rmg_profile_042_v1",cfg.players,"land",false,cfg.size,Setup.RANDOM_MAP_TEMPLATE_SELECTION_MODE_SIZE_DEFAULT,cfg.faction,cfg.hero)
		var setup: Dictionary = Setup.build_random_map_skirmish_setup_with_retry(config,"normal",Setup.RANDOM_MAP_PLAYER_RETRY_POLICY)
		if not bool(setup.get("ok",false)):
			print("GENERATED_FULL_MATCH_REPORT " + JSON.stringify({"ok":false,"failures":["setup failed"],"setup":setup}))
			get_tree().quit(1)
			return
		session = SessionState.set_active_session(Setup.start_random_map_skirmish_session_from_setup(setup))
		AppRouter.go_to_overworld()
		await resolve_routes()
		record("setup",started,{"seed":cfg.seed,"size":cfg.size,"players":cfg.players,"retry_status":setup.get("retry_status",{}),"retry_attempts":setup.get("retry_attempts",[])})
		await screenshot("opening")
		await checkpoint("opening",1)
	while session.scenario_status == "in_progress" and failures.is_empty() and session.day <= int(cfg.max_days):
		var day_start: int = session.day
		for order in range(24):
			var capacity := capacity_snapshot()
			if not capacity.ok:
				failures.append("army capacity violated: "+JSON.stringify(capacity.violations))
				break
			if not failures.is_empty() or session.scenario_status != "in_progress":
				break
			if scene_path().ends_with("TownShell.tscn"):
				await town_orders()
				continue
			if not scene_path().ends_with("OverworldShell.tscn"):
				failures.append("unexpected nonterminal scene: " + scene_path())
				break
			var target := choose_target()
			if target.is_empty() or int(session.overworld.get("movement",{}).get("current",0)) <= 0:
				break
			await perform_target(target)
		if session.scenario_status != "in_progress" or not failures.is_empty():
			break
		if scene_path().ends_with("TownShell.tscn"):
			await town_orders()
		started = Time.get_ticks_usec()
		var turn: Dictionary = get_tree().current_scene._request_end_turn(false)
		if bool(turn.get("confirmation_required",false)):
			turn = get_tree().current_scene._on_end_turn_confirmation_confirmed()
		await resolve_routes()
		record("end_turn",started,{"ok":turn.get("ok",false),"save_sha256":FileAccess.get_sha256(SaveService._autosave_path())})
		if not bool(turn.get("ok",false)) or session.day == day_start and session.scenario_status == "in_progress":
			failures.append("End Turn failed to advance")
		if session.day in [8,22,43] and session.scenario_status == "in_progress":
			await screenshot("day_%03d" % session.day)
			await checkpoint("mid_match",2)
		if session.day - last_progress_day > 14:
			failures.append("win-seeking driver made no exploration/interaction progress for fourteen days")
	await screenshot("final")
	if session.scenario_status != "in_progress":
		await checkpoint("terminal",3)
	else:
		failures.append("no legitimate terminal outcome before diagnostic limit")
	var report := {"ok":failures.is_empty() and session.scenario_status in ["victory","defeat"],"failures":failures,"config":cfg,"final":compact_state(),"counts":counts,"checkpoint_count":checkpoint_count,"checkpoint_labels":checkpoint_labels,"input_method":"scene pointer/actions; shipped Quick Resolve; production save API and router resume"}
	var report_file := FileAccess.open(out.path_join("engine_report.json"),FileAccess.WRITE)
	report_file.store_string(JSON.stringify(report,"\t"))
	report_file.close()
	action_file.close()
	print("GENERATED_FULL_MATCH_REPORT " + JSON.stringify(report))
	get_tree().quit(0 if report.ok else 1)
'''


def acceptance_failures(report: dict) -> list[str]:
    """Keep early loss/diagnostic limits distinct from complete-match coverage."""
    failures = list(report.get('failures', []))
    if not report.get('ok'):
        failures.append('engine did not accept the run')
    if report.get('returncode') != 0 or report.get('runtime_errors'):
        failures.append('runtime process or error gate failed')
    final = report.get('final', {})
    if final.get('status') not in {'victory', 'defeat'}:
        failures.append('no legitimate terminal outcome')
    if not str(final.get('scene', '')).endswith('/ScenarioOutcomeShell.tscn'):
        failures.append('real outcome scene not reached')
    if not {'opening', 'mid_match', 'terminal'} <= set(report.get('checkpoint_labels', [])):
        failures.append('opening/mid-match/terminal save-resume coverage missing')
    counts = report.get('counts', {})
    for kind in ['town_build', 'town_recruit', 'battle', 'battle_report', 'end_turn']:
        if counts.get(kind, 0) <= 0:
            failures.append(f'{kind} coverage missing')
    if not any(counts.get(kind, 0) > 0 for kind in ['target_resource', 'target_artifact', 'target_explore']):
        failures.append('exploration/collection coverage missing')
    capacity = report.get('army_capacity_trace', {})
    if not capacity.get('complete'):
        failures.append('complete-match army capacity observations missing')
    if capacity.get('violation_count', 0) > 0 or final.get('army_capacity', {}).get('ok') is not True:
        failures.append('oversized army invalidates full-match acceptance')
    return failures


def army_capacity_trace(rows: list[dict]) -> dict:
    observed = 0
    violations = []
    for row in rows:
        capacity = row.get('state', {}).get('army_capacity', {})
        if (capacity.get('holders_checked', 0) > 0 and isinstance(capacity.get('violations'), list)
                and capacity.get('ok') is (not capacity['violations'])):
            observed += 1
            violations.extend({'serial': row.get('serial'), **item} for item in capacity['violations'])
    return {'complete': bool(rows) and observed == len(rows), 'observed_actions': observed,
            'total_actions': len(rows), 'violation_count': len(violations), 'examples': violations[:10]}


def resume_prefix(source: Path, case: dict, autosave: bool = False) -> tuple[bytes, list[dict], dict]:
    """Continue a recorded real checkpoint, never splice in synthetic progress."""
    saved = (source/'data/godot/app_userdata/heroes-like/saves'/('autosave.json' if autosave else 'slot2.json')).read_bytes()
    state = json.loads(saved)
    rows = [json.loads(line) for line in (source/'actions.jsonl').read_text().splitlines()]
    setup = next(row['result'] for row in rows if row['kind'] == 'setup')
    if any(setup.get(key) != case[key] for key in ['seed', 'size', 'players']):
        raise ValueError('resume setup does not match selected case')
    if state.get('difficulty') != 'normal' or case.get('hero') and state.get('hero_id') != case['hero']:
        raise ValueError('resume difficulty or hero does not match selected case')
    players = [p for p in state['overworld'].get('players', []) if p.get('human')]
    if len(players) != 1 or players[0].get('faction_id') != case['faction']:
        raise ValueError('resume player faction does not match selected case')
    if autosave:
        matches = [i for i, row in enumerate(rows) if row['kind'] == 'end_turn' and row['result'].get('ok') and row['state']['day'] == state['day'] and row['state']['status'] == state['scenario_status'] and row['state']['resources'] == state['overworld']['resources'] and row['state']['hero']['x'] == state['overworld']['hero_position']['x'] and row['state']['hero']['y'] == state['overworld']['hero_position']['y']]
    else:
        matches = [i for i, row in enumerate(rows) if row['kind'] == 'save_resume' and row['result'].get('label') == 'mid_match' and row['state']['day'] == state['day'] and row['result'].get('complete_state_equal')]
    if not matches or state['scenario_status'] != 'in_progress':
        raise ValueError('no recorded exact nonterminal checkpoint for this save')
    rows = rows[:matches[-1]+1]
    saved_hash = hashlib.sha256(saved).hexdigest()
    driver_state = rows[-1].get('driver_state', {})
    if rows[-1]['result'].get('save_sha256') != saved_hash:
        raise ValueError('checkpoint lacks exact saved-file hash; start a fresh match')
    if (driver_state.get('version') != 1
            or type(driver_state.get('last_progress_day')) is not int
            or not 1 <= driver_state['last_progress_day'] <= state['day']
            or any(not isinstance(driver_state.get(key), dict) for key in
                   ['failed_targets', 'last_town_day', 'read_signs', 'waypoint_visits', 'active_target'])):
        raise ValueError('checkpoint lacks complete driver/no-progress state; start a fresh match')
    boundary = f'"serial":{rows[-1]["serial"]}'
    prefix_log = []
    for line in (source/'runtime.log').read_text().splitlines():
        prefix_log.append(line)
        if line.startswith('GENERATED_FULL_MATCH_ACTION ') and boundary in line.replace(' ', ''):
            break
    else:
        raise ValueError('checkpoint lacks a matching runtime log record')
    if any(line.startswith(('ERROR:', 'SCRIPT ERROR:')) or 'leaked' in line for line in prefix_log):
        raise ValueError('resume prefix contains runtime errors')
    counts, labels = {}, []
    for row in rows:
        kind, result = row['kind'], row['result']
        counts[kind] = counts.get(kind, 0)+1
        if kind == 'save_resume':
            labels.append(result['label'])
    metadata = {'source':source.name, 'source_checkpoint':'end_turn_autosave' if autosave else 'mid_match_save', 'save_sha256':saved_hash, 'counts':counts, 'checkpoint_labels':labels, 'serial':rows[-1]['serial'], **driver_state}
    return saved, rows, metadata


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--case', choices=CASES, required=True)
    parser.add_argument('--label', required=True)
    parser.add_argument('--max-days', type=int, default=120, help='Diagnostic failure limit, never a passing outcome')
    parser.add_argument('--timeout', type=int, default=10800)
    parser.add_argument('--rendered', action='store_true')
    parser.add_argument('--resolution', choices=['1280x720', '1920x1080'], default='1280x720')
    parser.add_argument('--accessibility', choices=['auto', 'disabled'], default='disabled')
    parser.add_argument('--resume-run', help='Continue the latest recorded mid-match save from an existing output label')
    parser.add_argument('--resume-autosave', action='store_true', help='Resume an exact recorded End Turn autosave instead of the selected mid-match slot')
    parser.add_argument('--background', action='store_true', help='Launch a supervised test runner outside the execution tool session lifetime; prints its PID and output location')
    args = parser.parse_args()
    if not args.label or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789_-' for c in args.label):
        parser.error('label must be a fresh lowercase slug')
    if args.resume_autosave and not args.resume_run:
        parser.error('--resume-autosave requires --resume-run')
    out = OUTPUT / args.label
    if args.background:
        if out.exists():
            parser.error('output label already exists')
        OUTPUT.mkdir(parents=True, exist_ok=True)
        launcher_log = OUTPUT/(args.label+'.launcher.log')
        with launcher_log.open('x') as log:
            process = subprocess.Popen([sys.executable,'-B',str(Path(__file__).resolve())]+[arg for arg in sys.argv[1:] if arg != '--background'],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
        print(json.dumps({'pid':process.pid,'output':str(out),'launcher_log':str(launcher_log)}),flush=True)
        return 0
    out.mkdir(parents=True, exist_ok=False)
    cfg = dict(CASES[args.case], max_days=args.max_days)
    if args.resume_run:
        if any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789_-' for c in args.resume_run):
            parser.error('resume label must be a lowercase slug')
        saved, prefix, metadata = resume_prefix(OUTPUT/args.resume_run, cfg, args.resume_autosave)
        (out/'resume.json').write_bytes(saved)
        (out/'actions.jsonl').write_text(''.join(json.dumps(row)+'\n' for row in prefix))
        cfg['resume'] = metadata
    env = dict(os.environ, XDG_DATA_HOME=str(out/'data'), HEROES_FULL_MATCH_OUTPUT=str(out), HEROES_FULL_MATCH_CONFIG=json.dumps(cfg), HEROES_FULL_MATCH_RESOLUTION=args.resolution, HEROES_PROFILE_LOG='1', HEROES_STRATEGIC_AI_PROFILE='1')
    # Capture launch provenance now, not after hours of play while the working
    # tree may have changed. This is evidence only, never game-state injection.
    revision = subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
    source_paths = sorted(set(ROOT.glob('scripts/**/*.gd')) | set(ROOT.glob('scenes/**/*.gd')) | set(ROOT.glob('scenes/**/*.tscn')) | set(ROOT.glob('content/*.json')) | {ROOT/'project.godot'})
    source_hashes = {str(path.relative_to(ROOT)):hashlib.sha256(path.read_bytes()).hexdigest() for path in source_paths}
    source_digest = hashlib.sha256(json.dumps(source_hashes,sort_keys=True).encode()).hexdigest()
    provenance = {'revision':revision,'driver_sha256':hashlib.sha256(SCRIPT.encode()).hexdigest(),'runtime_source_tree_sha256':source_digest,'runtime_source_sha256':source_hashes}
    (out/'launch_provenance.json').write_text(json.dumps(provenance,indent=2)+'\n')
    started = monotonic()
    with tempfile.TemporaryDirectory(prefix='driver-', dir=OUTPUT) as temporary:
        work = Path(temporary)
        (work/'driver.gd').write_text(SCRIPT)
        scene = work/'driver.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="GeneratedFullMatch" type="Node"]\nscript = ExtResource("1")\n' % (work/'driver.gd').relative_to(ROOT))
        cmd = ['godot4', '--path', str(ROOT), '--audio-driver', 'Dummy', '--accessibility', args.accessibility, '--resolution', args.resolution, 'res://'+str(scene.relative_to(ROOT))]
        cmd = ['dbus-run-session','--','xvfb-run','-a','-s','-screen 0 2200x1200x24']+cmd if args.rendered else cmd+['--headless']
        with (out/'runtime.log').open('w') as log:
            process = subprocess.Popen(cmd, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
            try:
                returncode = process.wait(timeout=args.timeout)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait()
                returncode = 124
    lines = (out/'runtime.log').read_text().splitlines()
    markers = [line[len(MARKER):] for line in lines if line.startswith(MARKER)]
    report = json.loads(markers[-1]) if markers else {'ok':False, 'failures':['engine did not produce a terminal report']}
    errors = [line for line in lines if line.startswith(('ERROR:','SCRIPT ERROR:')) or 'leaked' in line]
    profile = out/'data/godot/app_userdata/heroes-like/debug/heroes_profile.jsonl'
    records = [json.loads(line) for line in profile.read_text().splitlines() if line.strip()] if profile.exists() else []
    report.update(returncode=returncode, runtime_errors=errors, wall_s=monotonic()-started, peak_child_rss_kib=resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss, config=cfg, rendered=args.rendered, resolution=args.resolution, accessibility=args.accessibility, revision=revision, driver_sha256=provenance['driver_sha256'], runtime_source_tree_sha256=source_digest, launch_provenance=str(out/'launch_provenance.json'), profile_summary=summarize(records))
    actions = out/'actions.jsonl'
    report['army_capacity_trace'] = army_capacity_trace([json.loads(line) for line in actions.read_text().splitlines() if line.strip()] if actions.exists() else [])
    report['acceptance_failures'] = acceptance_failures(report)
    report['ok'] = not report['acceptance_failures']
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k!='profile_summary'}),flush=True)
    return 0 if report['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
