#!/usr/bin/env python3
"""Live Medium opening: roster and route arrival must retain current-tile orders."""
import argparse
import json
import os
import subprocess
import tempfile

from generated_full_match_quality import OUTPUT, ROOT

SCRIPT = r'''
extends Node
const Setup = preload("res://scripts/core/ScenarioSelectRules.gd")
var checks := {}
var evidence := {}
func _ready() -> void:
	call_deferred("run")
func settle() -> void:
	for frame in range(6):
		await get_tree().process_frame
func capture(label: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_environment("HEROES_ARRIVAL_OUT").path_join(label+".png"))
func inspect_action(shell, expected: String, label: String) -> bool:
	var action: Dictionary = shell._current_primary_action()
	var button = shell._primary_action_button
	var ok: bool = String(action.get("id","")) == expected and not bool(action.get("disabled",false)) and not button.disabled
	checks[label] = ok
	evidence[label] = {"expected":expected,"actual":action.get("id",""),"button":button.text,"disabled":button.disabled,"context":OverworldRules.get_active_context(SessionState.active_session).get("type","")}
	return ok
func run() -> void:
	get_tree().current_scene = null
	SettingsService.set_presentation_mode("windowed")
	SettingsService.set_presentation_resolution(OS.get_environment("HEROES_ARRIVAL_RESOLUTION"))
	var config: Dictionary = Setup.build_random_map_player_config("10","translated_rmg_template_042_v1","translated_rmg_profile_042_v1",2,"land",false,"homm3_medium",Setup.RANDOM_MAP_TEMPLATE_SELECTION_MODE_SIZE_DEFAULT,"faction_embercourt","")
	var setup: Dictionary = Setup.build_random_map_skirmish_setup_with_retry(config,"normal",Setup.RANDOM_MAP_PLAYER_RETRY_POLICY)
	checks["setup"] = setup.get("ok",false)
	if checks.setup:
		var session = SessionState.set_active_session(Setup.start_random_map_skirmish_session_from_setup(setup))
		AppRouter.go_to_overworld()
		await settle()
		var shell = get_tree().current_scene
		var origin := OverworldRules.hero_position(session)
		checks["native_start"] = origin == Vector2i(43,40)
		inspect_action(shell,"visit_town","opening_town_order")
		var before: Dictionary = session.to_dict()
		shell._on_town_rail_pressed(origin.x,origin.y,0)
		checks["roster_inspection_preserves_state"] = before == session.to_dict()
		var roster_ok := inspect_action(shell,"visit_town","roster_current_town_order")
		await capture("roster_current_town")
		if roster_ok:
			shell.validation_perform_primary_action()
			await settle()
			checks["town_routes"] = get_tree().current_scene.scene_file_path.ends_with("TownShell.tscn")
			if checks.town_routes:
				get_tree().current_scene.validation_leave_town()
				await settle()
				shell = get_tree().current_scene
				var roster: Dictionary = shell.validation_command_roster_snapshot()
				checks["town_return_owned_roster"] = int(roster.get("hero_count",0)) == 1 and int(roster.get("town_count",0)) == 1 and bool(roster.get("all_focusable",false))
				evidence["town_return_roster"] = {"heroes":roster.get("hero_count",0),"towns":roster.get("town_count",0)}
				await capture("town_return_roster")
		var target := Vector2i(41,41)
		var guard: Dictionary = OverworldRules.guard_engagement_encounter_at_tile(session,target.x,target.y)
		checks["exact_guard"] = String(guard.get("placement_id","")) == "h3maped_small_rare_source_guard_h3maped_small_town_source_support_native_h3maped_93c0f05a_object_0950_required_sources"
		var home_node := {}
		var other_guard := {}
		for node in session.overworld.resource_nodes:
			if String(node.get("placement_id","")) == String(guard.get("guard_link",{}).get("target_placement_id","")):
				home_node = node
		for enemy in session.overworld.encounters:
			if enemy.get("guard_link",{}).get("target_id","") == home_node.get("site_id","") and enemy.get("placement_id","") != guard.get("placement_id",""):
				other_guard = enemy
		var site: Dictionary = ContentService.get_resource_site(String(home_node.get("site_id","")))
		checks["guard_matches_own_placement"] = OverworldRules._resource_site_guard_targets_node(guard.get("guard_link",{}),home_node,site)
		checks["guard_rejects_other_placement"] = not OverworldRules._resource_site_guard_targets_node(other_guard.get("guard_link",{}),home_node,site)
		checks["legacy_site_id_link_supported"] = OverworldRules._resource_site_guard_targets_node({"target_id":home_node.get("site_id","")},home_node,site)
		var stores: Dictionary = session.overworld.resources.duplicate(true)
		shell._on_map_tile_pressed(target)
		await settle()
		if OverworldRules.hero_position(session) != target:
			shell._on_map_tile_pressed(target)
			await settle()
		checks["legal_arrival"] = OverworldRules.hero_position(session) == target
		checks["guard_not_bypassed"] = not OverworldRules.is_encounter_resolved(session,guard) and stores == session.overworld.resources
		var arrival_ok := inspect_action(shell,"enter_battle","guard_arrival_order")
		await capture("guard_arrival")
		# Repeated selection/hover refresh must not disable the order either.
		shell._refresh_selected_route_preview("repeat_current_guard")
		checks["repeat_guard_order"] = inspect_action(shell,"enter_battle","repeat_guard_action")
		if arrival_ok:
			var battle: Dictionary = shell.validation_perform_primary_action()
			await settle()
			checks["actual_battle_routes"] = bool(battle.get("battle_started",false)) and get_tree().current_scene.scene_file_path.ends_with("BattleShell.tscn")
			await capture("battle_entered")
			if checks.actual_battle_routes:
				var combat = get_tree().current_scene
				combat.validation_request_quick_resolve_confirmation()
				await settle()
				combat.validation_confirm_quick_resolve_confirmation()
				await settle()
				checks["battle_report_routes"] = get_tree().current_scene.scene_file_path.ends_with("BattleReportShell.tscn")
				if checks.battle_report_routes:
					get_tree().current_scene.get_node("%Continue").pressed.emit()
					await settle()
					checks["normal_guard_victory"] = OverworldRules.is_encounter_resolved(session,guard)
					checks["other_guard_still_present"] = not OverworldRules.is_encounter_resolved(session,other_guard)
					checks["cleared_site_not_remotely_guarded"] = OverworldRules.resource_site_blocking_guard(session,home_node,site).is_empty()
					shell = get_tree().current_scene
					if shell.scene_file_path.ends_with("OverworldShell.tscn"):
						var collect_ok := inspect_action(shell,"collect_resource","cleared_site_order")
						if collect_ok:
							var collect: Dictionary = shell.validation_perform_primary_action()
							await settle()
							checks["cleared_site_collects"] = bool(collect.get("ok",false))
						await capture("cleared_site")
	var ok: bool = checks.values().all(func(value):return bool(value))
	print("OVERWORLD_ARRIVAL_ACTION_REPORT "+JSON.stringify({"ok":ok,"checks":checks,"evidence":evidence,"seed":"10","size":"homm3_medium","policy":"normal generated opening, real roster and pointer/primary handlers; no state injections"}))
	get_tree().quit(0 if ok else 1)
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--label', required=True)
    parser.add_argument('--rendered', action='store_true')
    parser.add_argument('--resolution', choices=['1280x720', '1920x1080'], default='1280x720')
    args = parser.parse_args()
    if not args.label or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789_-' for c in args.label):
        parser.error('invalid label')
    out = OUTPUT / args.label
    out.mkdir(parents=True, exist_ok=False)
    with tempfile.TemporaryDirectory(prefix='arrival-', dir=OUTPUT) as temporary:
        from pathlib import Path
        work = Path(temporary)
        (work/'probe.gd').write_text(SCRIPT)
        scene = work/'probe.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="Arrival" type="Node"]\nscript = ExtResource("1")\n' % (work/'probe.gd').relative_to(ROOT))
        env = dict(os.environ, XDG_DATA_HOME=str(out/'data'), HEROES_ARRIVAL_OUT=str(out), HEROES_ARRIVAL_RESOLUTION=args.resolution)
        command = ['godot4','--path',str(ROOT),'--audio-driver','Dummy','--accessibility','disabled','res://'+str(scene.relative_to(ROOT))]
        command = ['dbus-run-session','--','xvfb-run','-a','-s','-screen 0 2200x1200x24']+command if args.rendered else command+['--headless']
        with (out/'runtime.log').open('w') as log:
            result = subprocess.run(['timeout','150s']+command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=170)
    lines = (out/'runtime.log').read_text().splitlines()
    records = [json.loads(line.split(' ',1)[1]) for line in lines if line.startswith('OVERWORLD_ARRIVAL_ACTION_REPORT ')]
    report = records[-1] if records else {'ok':False}
    report.update(returncode=result.returncode, rendered=args.rendered, resolution=args.resolution, runtime_errors=[line for line in lines if line.startswith(('ERROR:','SCRIPT ERROR:')) or 'leaked' in line])
    report['ok'] = bool(report['ok']) and not report['runtime_errors'] and result.returncode == 0
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report))
    return 0 if report['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
