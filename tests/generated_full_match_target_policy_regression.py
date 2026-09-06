#!/usr/bin/env python3
"""Live stalled-Medium policy diagnostic; isolated save, never a full match."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import tempfile

from generated_full_match_quality import ROOT, OUTPUT, SCRIPT as MATCH_SCRIPT
from generated_town_order_profile import run_probe

CASES = r'''
var probe_errors := []
var observations := []
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: probe_errors.append(message)
func normalized(value): return JSON.parse_string(JSON.stringify(value))
func source_geometry() -> Dictionary:
	var result := {"map":session.overworld.map}
	for bucket in ["towns","resource_nodes","artifact_nodes","encounters","map_objects"]:
		var rows := []
		for node in session.overworld.get(bucket,[]):
			if String(node.get("spawned_by_faction_id",""))!="":continue
			var row := {}
			for key in ["placement_id","x","y","level","body_tiles","blocking_body","visit_tile","package_body_tiles","package_block_tiles","package_visit_tiles","package_guard_engagement_tiles"]:
				if node.has(key):row[key]=node[key]
			rows.append(row)
		result[bucket]=rows
	return normalized(result)
func pointer_select(tile: Vector2i) -> void:
	var map=get_tree().current_scene._map_view
	map.focus_on_tile(tile)
	await settle()
	var center: Vector2=map._tile_rect(map._board_rect(),tile).get_center()
	check(map._tile_from_local(center)==tile,"guard approach pointer projection differs")
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		event.position=center
		map._gui_input(event)
	await resolve_routes()
func run_match() -> void:
	get_tree().current_scene=null
	out=OS.get_environment("HEROES_FULL_MATCH_OUTPUT")
	action_file=FileAccess.open(out.path_join("actions.jsonl"),FileAccess.WRITE)
	SettingsService.set_presentation_mode("windowed")
	SettingsService.set_presentation_resolution("1280x720")
	var payload: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("MATCH_POLICY_SAVE")))
	check(SaveService.save_session(payload,1)!="","isolated save copy failed")
	session=SaveService.restore_manual_session(1)
	if session==null:
		push_error("production saved-generated restore failed");get_tree().quit(1);return
	session=SessionState.set_active_session(session)
	check(not ContentService.get_scenario_readonly(session.scenario_id).is_empty(),"saved generated scenario was not registered")
	for key in ["saved_at_unix","save_slot_type","saved_from_game_state","saved_from_scenario_status","saved_from_launch_mode"]: payload.erase(key)
	check(normalized(session.to_dict())==payload,"production restore changed saved gameplay state")
	AppRouter.go_to_overworld()
	await settle()
	check(get_tree().current_scene._session==session,"probe observes a detached session")
	var geometry := source_geometry()
	# Policy bookkeeping only: reproduce the recorded post-management choice.
	for town in session.overworld.towns:
		if town.owner=="player":last_town_day[town.placement_id]=session.day
	var shell=get_tree().current_scene
	var blocked_id := "native_h3maped_93c0f05a_object_1324"
	var node: Dictionary=shell._validation_targets("resource","",blocked_id)[0]
	var site: Dictionary=ContentService.get_resource_site(node.site_id)
	var before: Dictionary=normalized(session.to_dict())
	var admission: Dictionary=Heroes.army_addition_plan(session.overworld.army.stacks,OverworldRules._resource_site_claim_recruits(site))
	var selected := choose_target()
	check(normalized(session.to_dict())==before,"target selection mutated gameplay")
	var unseen: Array=shell._validation_targets("encounter").filter(func(row):return not known(row))
	check(not unseen.is_empty(),"saved map lacks hidden-target rejection control")
	if not unseen.is_empty():
		active_target={"id":unseen[0].placement_id,"kind":"encounter"}
		check(choose_target().get("id","")!=unseen[0].placement_id,"retained intent exposes an unexplored target")
		active_target.clear()
	# A stale position in bookkeeping cannot override the live visible record.
	var observed_raids: Array=shell._validation_targets("encounter").filter(func(row):return known(row) and String(row.get("spawned_by_faction_id",""))!="" and power(OverworldRules._encounter_army_payload(row).get("stacks",[]))<=player_power()*0.70)
	check(not observed_raids.is_empty(),"saved map lacks a visible moving-target control")
	if not observed_raids.is_empty():
		var raid: Dictionary=observed_raids[0]
		active_target={"id":raid.placement_id,"kind":"encounter","tile":Vector2i(-100,-100)}
		var refreshed := choose_target()
		check(refreshed.get("id","")==raid.placement_id and refreshed.get("tile",Vector2i(-1,-1))==guard_approach(raid),"retained raid intent does not refresh its live approach")
		active_target.clear()
	check(normalized(session.to_dict())==before,"hidden/moving target controls mutated gameplay")
	check(not admission.get("ok",true),"saved full army no longer reproduces unclaimable reward")
	check(selected.get("id","")!=blocked_id,"driver repeatedly selects an army-capacity-blocked reward")
	check(not resource_claim_feasible(node),"capacity admission policy disagrees with live claim")
	# Detached admission controls use copies, never discard saved soldiers.
	var live_session = session
	var live_state: Dictionary=normalized(session.to_dict())
	var fixture = preload("res://scripts/core/SessionStateStore.gd").new_session_data()
	fixture.overworld=session.overworld.duplicate(true)
	session=fixture
	var rewards: Dictionary=OverworldRules._resource_site_claim_recruits(site)
	fixture.overworld.army.stacks=fixture.overworld.army.stacks.slice(0,6)
	check(not resource_claim_feasible(node),"two-unit reward incorrectly fits only one vacant slot")
	fixture.overworld.army.stacks=fixture.overworld.army.stacks.slice(0,Heroes.ARMY_SLOT_COUNT-rewards.size())
	check(resource_claim_feasible(node),"fitting recruit reward incorrectly rejected")
	for unit_id in rewards:
		fixture.overworld.army.stacks.append({"unit_id":unit_id,"count":1,"slot":fixture.overworld.army.stacks.size()})
	check(resource_claim_feasible(node),"matching seventh stack incorrectly rejected")
	fixture.overworld.army.stacks=live_session.overworld.army.stacks.duplicate(true)
	check(not resource_claim_feasible(node),"admission retained stale fitting-army result")
	session=live_session
	check(normalized(session.to_dict())==live_state,"detached admission controls changed real saved state")
	observations.append({"case":"saved_policy","selected":selected,"admission":admission,"node":node,"hero":compact_state().hero})
	# Exercise the same real pointer path even after policy is corrected.
	await perform_target({"id":blocked_id,"kind":"resource","tile":Vector2i(15,50),"record":node})
	check(OverworldRules.hero_position(session)==Vector2i(15,50),"actual pointer could not reach saved blocked reward")
	check(not node.get("collected",false),"blocked reward was silently claimed")
	check(normalized(session.overworld.army)==before.overworld.army,"blocked reward changed troops")
	shell=get_tree().current_scene
	check(shell._current_primary_action().is_empty() or shell._current_primary_action().get("disabled",false),"full-army claim remains enabled")
	await screenshot("capacity_blocked_reward")
	# Check escape before spending the remaining movement on a long route.
	var origin := OverworldRules.hero_position(session)
	shell._try_move(0,-1)
	await settle()
	check(OverworldRules.hero_position(session)==origin+Vector2i.UP,"ordinary move cannot leave blocked reward")
	await screenshot("ordinary_movement_after_reward")
	var encounter_id := "generated_guarded_reward_native_h3maped_93c0f05a_object_1261"
	var encounter: Dictionary=shell._validation_targets("encounter","",encounter_id)[0]
	var approach := guard_approach(encounter)
	check(shell._selection_route_tile(approach)==approach,"scenic shortcut steals the reachable guard approach")
	check(shell._selected_route_destination_execution_descriptor(approach).get("kind","")=="encounter","guard approach descriptor is owned by unrelated scenery")
	observations.append({"case":"guard_route_from_reward","approach":approach,"path":shell._build_path(OverworldRules.hero_position(session),approach),"selection_route_tile":shell._selection_route_tile(approach)})
	await pointer_select(approach)
	check(get_tree().current_scene._selected_tile==approach,"actual projected guard click selects scenery")
	await screenshot("guard_approach_selected")
	origin=OverworldRules.hero_position(session)
	await perform_target({"id":encounter_id,"kind":"encounter","tile":approach,"record":encounter})
	observations.append({"case":"guard_pointer_result","origin":origin,"hero":compact_state().hero,"message":get_tree().current_scene.get("_last_message"),"failures":failures.duplicate()})
	check(OverworldRules.hero_position(session)!=origin,"guard click did not make actual route progress")
	check(active_target.get("id","")==encounter_id,"partial travel lost target intent")
	for attempt in range(3):
		if OverworldRules.is_encounter_resolved(session,encounter):break
		var turn: Dictionary=get_tree().current_scene._request_end_turn(false)
		if turn.get("confirmation_required",false):turn=get_tree().current_scene._on_end_turn_confirmation_confirmed()
		await resolve_routes()
		check(turn.get("ok",false),"ordinary End Turn failed during approach")
		for town in session.overworld.towns:
			if town.owner=="player":last_town_day[town.placement_id]=session.day
		selected=choose_target()
		check(selected.get("id","")==encounter_id,"nearer target displaced legal partial-route intent")
		if selected.get("id","")!=encounter_id:break
		check(known(selected.record),"retained target is not currently known")
		await perform_target(selected)
	check(OverworldRules.is_encounter_resolved(session,encounter),"normal pointer/turn actions did not resolve the actual guard")
	check(int(counts.get("battle",0))>0 and int(counts.get("battle_report",0))>0,"guard route skipped real battle/casualty handoff")
	await screenshot("guard_resolved")
	# Existing earned choices, no XP injection; use ordinary remote Town route.
	last_town_day.clear()
	selected=choose_target()
	check(selected.get("remote",false),"saved owned Town management is unavailable")
	if selected.get("remote",false):
		await perform_target(selected)
		var pending_before: int=preload("res://scripts/core/HeroProgressionRules.gd").pending_choices_remaining(session.overworld.hero)
		await town_orders()
		check(pending_before>0 and preload("res://scripts/core/HeroProgressionRules.gd").pending_choices_remaining(session.overworld.hero)==0,"ordinary Town driver did not spend existing earned specialties")
	check(capacity_snapshot().ok,"live diagnostic created an oversized army")
	check(source_geometry()==geometry,"guard interaction changed source terrain/placement/mask geometry")
	await checkpoint("diagnostic_guard_and_choices",2)
	check(checkpoint_labels.has("diagnostic_guard_and_choices"),"guard/earned-choice gameplay did not save and resume exactly")
	check(failures.is_empty(),"live route driver failed: "+str(failures))
	observations.append({"case":"guard_and_town_completed","hero":compact_state().hero,"capacity":capacity_snapshot(),"counts":counts.duplicate()})
	print("GENERATED_MATCH_POLICY_REGRESSION "+JSON.stringify({"ok":probe_errors.is_empty(),"checks":checks,"failures":probe_errors,"observations":observations}))
	get_tree().quit(0 if probe_errors.is_empty() else 1)
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--label', required=True)
    parser.add_argument('--save', required=True, type=Path)
    args = parser.parse_args()
    if not args.label or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789_-' for c in args.label):
        parser.error('label must be a fresh lowercase slug')
    source = args.save.resolve()
    saved_hash = hashlib.sha256(source.read_bytes()).hexdigest()
    out = OUTPUT / args.label
    out.mkdir(parents=True, exist_ok=False)
    # Compile the complete match entry too, with real project autoloads present.
    # Only the isolated diagnostic entry runs; the full-match loop stays unused.
    script_text = MATCH_SCRIPT.replace('func run_match() -> void:', 'func unused_full_match_entry() -> void:', 1) + CASES
    with tempfile.TemporaryDirectory(prefix='match-policy-', dir=OUTPUT) as temporary:
        work = Path(temporary)
        script = work / 'probe.gd'
        script.write_text(script_text)
        scene = work / 'probe.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="MatchPolicy" type="Node"]\nscript = ExtResource("1")\n' % script.relative_to(ROOT))
        command = ['dbus-run-session', '--', 'xvfb-run', '-a', 'godot4', '--path', str(ROOT), '--audio-driver', 'Dummy', '--accessibility', 'disabled', '--resolution', '1280x720', 'res://' + str(scene.relative_to(ROOT))]
        env = dict(os.environ, XDG_DATA_HOME=str(out / 'data'), HEROES_FULL_MATCH_OUTPUT=str(out), MATCH_POLICY_SAVE=str(source))
        with (out / 'runtime.log').open('w') as log:
            code = run_probe(command, env, log)
    lines = (out / 'runtime.log').read_text().splitlines()
    marker = 'GENERATED_MATCH_POLICY_REGRESSION '
    reports = [json.loads(line[len(marker):]) for line in lines if line.startswith(marker)]
    report = reports[-1] if reports else {'ok': False, 'failures': ['missing report']}
    report.update(returncode=code, source_save=str(source), source_save_sha256=saved_hash,
                  source_save_unchanged=hashlib.sha256(source.read_bytes()).hexdigest() == saved_hash,
                  driver_sha256=hashlib.sha256(MATCH_SCRIPT.encode()).hexdigest(),
                  runtime_errors=[s for s in lines if s.startswith(('ERROR:', 'SCRIPT ERROR:')) or 'leaked' in s])
    report['ok'] = bool(report['ok']) and code == 0 and report['source_save_unchanged'] and not report['runtime_errors']
    (out / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report))
    return 0 if report['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
