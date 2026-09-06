#!/usr/bin/env python3
"""Replay exact artifact clicks obscured by adjacent resource scenic footprints."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import tempfile

from generated_full_match_quality import ROOT, OUTPUT, SCRIPT as MATCH_SCRIPT
from generated_town_order_profile import run_probe

BODY = r'''
var checks := 0
var selection_rows := []
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
func artifact(id: String) -> Dictionary:
	for node in session.overworld.artifact_nodes:
		if node.placement_id == id:
			return node
	return {}
func source_geometry() -> String:
	var result := {}
	for bucket in ["towns","resource_nodes","artifact_nodes","encounters","map_objects"]:
		var rows := []
		for node in session.overworld.get(bucket,[]):
			if String(node.get("spawned_by_faction_id","")) != "":
				continue
			var row := {}
			for key in ["placement_id","x","y","level","body_tiles","blocking_body","visit_tile","package_body_tiles","package_block_tiles","package_visit_tiles"]:
				if node.has(key):
					row[key] = node[key]
			rows.append(row)
		result[bucket] = rows
	result.map = session.overworld.map
	return JSON.stringify(result)
func pointer(tile: Vector2i) -> void:
	var map = get_tree().current_scene._map_view
	map.focus_on_tile(tile)
	await settle()
	var center: Vector2 = map._tile_rect(map._board_rect(),tile).get_center()
	check(map._tile_from_local(center) == tile,"pointer projection differs from requested tile")
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = center
		map._gui_input(event)
	await resolve_routes()
func capture(label: String) -> void:
	if DisplayServer.get_name() != "headless":
		# Allow the ordinary hero movement/collection presentation to settle.
		await get_tree().create_timer(1.2).timeout
		await screenshot(label)
func reset_probe(probe, fixture) -> void:
	OverworldRules.invalidate_spatial_lookup(fixture)
	probe._invalidate_refresh_cache()
func isolated_selection_controls() -> void:
	# Detached query fixtures only; never altered full-match resources or actors.
	var live_before: Dictionary = JSON.parse_string(JSON.stringify(session.to_dict()))
	var fixture = preload("res://scripts/core/SessionStateStore.gd").new_session_data()
	fixture.overworld = {"map":session.overworld.map.duplicate(true),"map_size":{"width":72,"height":72,"level_count":2},"hero_position":{"x":0,"y":0},"view_level":0,"towns":[],"resource_nodes":[],"artifact_nodes":[],"encounters":[],"resolved_encounters":[],"player_heroes":[]}
	var node: Dictionary = OverworldRules._find_resource_node_by_placement(session,"native_h3maped_93c0f05a_object_1289").get("node",{}).duplicate(true)
	fixture.overworld.resource_nodes = [node]
	var item := {"placement_id":"exact_selection_artifact_fixture","artifact_id":"artifact_waymark_compass","x":18,"y":55,"collected":false}
	fixture.overworld.artifact_nodes = [item]
	var probe = load("res://scenes/overworld/OverworldShell.gd").new()
	probe._session = fixture
	probe._map_size = Vector2i(72,72)
	var tile := Vector2i(18,55)
	var entrance := Vector2i(18,56)
	check(probe._selection_route_tile(tile)==tile,"fixture artifact must own exact selection")
	check(probe._resource_node_at(tile.x,tile.y).is_empty(),"artifact descriptor must exclude scenic resource")
	check(probe._selection_route_tile(entrance)==entrance,"actual resource entrance must retain identity")
	check(probe._resource_node_at(entrance.x,entrance.y).get("placement_id","")==node.placement_id,"actual resource descriptor must remain")
	item.collected = true
	reset_probe(probe,fixture)
	check(probe._selection_route_tile(tile)==entrance,"consumed artifact must release scenic-body shortcut")
	check(probe._resource_node_at(tile.x,tile.y).get("placement_id","")==node.placement_id,"consumed artifact cached no-resource result must clear")
	item.collected = false
	item.level = 1
	reset_probe(probe,fixture)
	check(probe._selection_route_tile(tile)==entrance,"underground artifact must not steal surface scenery")
	fixture.overworld.view_level = 1
	reset_probe(probe,fixture)
	check(probe._tile_has_exact_selection_target(tile),"underground artifact must own its viewed level")
	check(probe._resource_node_at(tile.x,tile.y).is_empty(),"surface resource must not leak into underground selection")
	fixture.overworld.view_level = 0
	fixture.overworld.artifact_nodes = []
	var enemy := {"placement_id":"exact_selection_encounter_fixture","encounter_id":session.overworld.encounters[0].get("encounter_id",""),"x":18,"y":55}
	fixture.overworld.encounters = [enemy]
	reset_probe(probe,fixture)
	check(probe._selection_route_tile(tile)==tile,"active encounter must own exact selection")
	check(probe._resource_node_at(tile.x,tile.y).is_empty(),"active encounter must exclude scenic resource descriptor")
	enemy.x = 17
	enemy.y = 54
	enemy.package_guard_engagement_tiles = [{"x":18,"y":55}]
	reset_probe(probe,fixture)
	check(OverworldRules.tile_has_route_interaction(fixture,18,55),"ordinary route rules must preserve guard control zones")
	check(not probe._tile_has_exact_selection_target(tile),"guard control zone must not impersonate exact guard position")
	check(probe._selection_route_tile(tile)==tile,"reachable guard approach must precede scenic shortcut")
	check(probe._resource_node_at(tile.x,tile.y).is_empty(),"scenery must not own guard approach descriptor")
	check(probe._selected_route_destination_execution_descriptor(tile).get("kind","")=="encounter","guard approach must resolve through encounter descriptor")
	fixture.overworld.view_level = 1
	reset_probe(probe,fixture)
	check(not probe._tile_has_guard_approach_selection(tile),"surface guard approach leaked onto other level")
	fixture.overworld.view_level = 0
	fixture.overworld.resolved_encounters = [enemy.placement_id]
	reset_probe(probe,fixture)
	check(probe._selection_route_tile(tile)==entrance,"resolved guard approach must release scenic shortcut")
	check(probe._resource_node_at(tile.x,tile.y).get("placement_id","")==node.placement_id,"resolved guard approach descriptor cache did not release scenery")
	fixture.overworld.resolved_encounters = []
	enemy.x = 18
	enemy.y = 55
	fixture.overworld.resolved_encounters = [enemy.placement_id]
	reset_probe(probe,fixture)
	check(probe._selection_route_tile(tile)==entrance,"resolved encounter must release scenic shortcut")
	fixture.overworld.player_heroes = [{"id":"reserve_selection_fixture","position":{"x":18,"y":55}}]
	reset_probe(probe,fixture)
	check(probe._selection_route_tile(tile)==tile,"reserve commander must own its exact tile")
	fixture.overworld.player_heroes = []
	fixture.overworld.hero_position = {"x":18,"y":55}
	reset_probe(probe,fixture)
	check(probe._selection_route_tile(tile)==tile,"active commander must retain current-tile selection after pickup")
	fixture.overworld.hero_position = {"x":0,"y":0}
	fixture.overworld.towns = [{"placement_id":"town_selection_fixture","x":20,"y":20,"visit_tile":{"x":18,"y":20}}]
	reset_probe(probe,fixture)
	check(OverworldRules.tile_has_route_interaction(fixture,20,20),"ordinary route rules must preserve legacy town anchor interaction")
	check(not probe._tile_has_exact_selection_target(Vector2i(20,20)),"town art anchor must not override its entrance shortcut")
	check(probe._tile_has_exact_selection_target(Vector2i(18,20)),"town entrance must retain exact ownership")
	var support := {"placement_id":"support_selection_fixture","site_id":"site_generated_town_required_source_cache","x":18,"y":55,"visit_tile":{"x":18,"y":55},"object_id":"","collected":false}
	fixture.overworld.resource_nodes = [support]
	reset_probe(probe,fixture)
	check(probe._resource_node_at(18,55).get("placement_id","")==support.placement_id,"generated support visit must not require an authored scenic descriptor")
	probe.free()
	check(live_before==JSON.parse_string(JSON.stringify(session.to_dict())),"isolated controls changed live fixture state")
func run_match() -> void:
	get_tree().current_scene = null
	out = OS.get_environment("EXACT_TARGET_OUTPUT")
	action_file = FileAccess.open(out.path_join("actions.jsonl"),FileAccess.WRITE)
	SettingsService.set_presentation_mode("windowed")
	SettingsService.set_presentation_resolution(OS.get_environment("EXACT_TARGET_RESOLUTION"))
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(out.path_join("input_save.json")))
	session = SessionState.restore_session(saved)
	for key in ["saved_at_unix","save_slot_type","saved_from_game_state","saved_from_scenario_status","saved_from_launch_mode"]:
		saved.erase(key)
	check(saved == JSON.parse_string(JSON.stringify(session.to_dict())),"restore changed complete gameplay state")
	var geometry := source_geometry()
	AppRouter.resume_active_session()
	await resolve_routes()
	for id in ["native_h3maped_93c0f05a_object_1285","native_h3maped_93c0f05a_object_1305"]:
		var node := artifact(id)
		check(not node.is_empty() and not bool(node.get("collected",true)),"missing real uncollected artifact "+id)
		if node.is_empty():
			break
		var tile := Vector2i(int(node.x),int(node.y))
		var shell = get_tree().current_scene
		var resolved: Vector2i = shell._selection_route_tile(tile)
		var site: Dictionary = shell._resource_node_at(tile.x,tile.y)
		selection_rows.append({"id":id,"tile":{ "x":tile.x,"y":tile.y},"resolved":{ "x":resolved.x,"y":resolved.y},"resource":site.get("placement_id","")})
		shell._map_view.focus_on_tile(tile)
		await settle()
		await capture(id+"_before")
		await pointer(tile)
		if scene_path().ends_with("OverworldShell.tscn"):
			check(get_tree().current_scene._selected_tile == tile,"pointer selected adjacent scenery instead of "+id)
		check(resolved == tile,"route redirected exact artifact tile "+id)
		check(site.is_empty(),"resource visual fallback owns artifact descriptor "+id)
		await capture(id+"_selected")
		if not failures.is_empty():
			break
		for attempt in range(8):
			if bool(artifact(id).get("collected",false)):
				break
			if not scene_path().ends_with("OverworldShell.tscn"):
				break
			if OverworldRules.hero_position(session) == tile:
				var action: Dictionary = get_tree().current_scene._current_primary_action()
				check(String(action.get("id","")) in ["collect_artifact","enter_battle"],"exact arrival lacks artifact/battle action")
				get_tree().current_scene.validation_perform_primary_action()
				await resolve_routes()
			else:
				await pointer(tile)
		check(bool(artifact(id).get("collected",false)),"ordinary pointer actions did not collect "+id)
		await capture(id+"_collected")
	var geometry_after := source_geometry()
	check(JSON.parse_string(geometry_after) == JSON.parse_string(geometry),"source terrain/placement geometry changed")
	if JSON.parse_string(geometry_after) != JSON.parse_string(geometry):
		for item in [["before",geometry],["after",geometry_after]]:
			var file := FileAccess.open(out.path_join("geometry_"+String(item[0])+".json"),FileAccess.WRITE)
			file.store_string(String(item[1]))
	if failures.is_empty():
		await checkpoint("exact_target_collection",2)
		check(checkpoint_labels.has("exact_target_collection"),"collected artifacts did not save/resume exactly")
		isolated_selection_controls()
	print("OVERWORLD_EXACT_TARGET_SELECTION_REGRESSION "+JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures,"selections":selection_rows,"counts":counts,"final":compact_state()}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--label', required=True)
    parser.add_argument('--save', type=Path, required=True)
    parser.add_argument('--rendered', action='store_true')
    parser.add_argument('--resolution', choices=['1280x720','1920x1080'], default='1280x720')
    args = parser.parse_args()
    if not args.label or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789_-' for c in args.label):
        parser.error('label must be a fresh lowercase slug')
    out = OUTPUT/args.label
    out.mkdir(parents=True, exist_ok=False)
    saved = args.save.read_bytes()
    json.loads(saved)
    (out/'input_save.json').write_bytes(saved)
    with tempfile.TemporaryDirectory(prefix='exact-target-',dir=OUTPUT) as temp:
        work = Path(temp)
        (work/'probe.gd').write_text(MATCH_SCRIPT[:MATCH_SCRIPT.index('func run_match()')]+BODY)
        scene = work/'probe.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="ExactTargets" type="Node"]\nscript = ExtResource("1")\n' % (work/'probe.gd').relative_to(ROOT))
        env = dict(os.environ,XDG_DATA_HOME=str(out/'data'),EXACT_TARGET_OUTPUT=str(out),EXACT_TARGET_RESOLUTION=args.resolution)
        command = ['godot4','--path',str(ROOT),'--audio-driver','Dummy','--accessibility','disabled','--resolution',args.resolution,'res://'+str(scene.relative_to(ROOT))]
        command = ['dbus-run-session','--','xvfb-run','-a','-s','-screen 0 2200x1200x24']+command if args.rendered else command+['--headless']
        with (out/'runtime.log').open('w') as log:
            code = run_probe(command,env,log)
    lines = (out/'runtime.log').read_text().splitlines()
    marker = 'OVERWORLD_EXACT_TARGET_SELECTION_REGRESSION '
    reports = [json.loads(line[len(marker):]) for line in lines if line.startswith(marker)]
    report = reports[-1] if reports else {'ok':False,'failures':['missing report']}
    report.update(returncode=code,save_sha256=hashlib.sha256(saved).hexdigest(),rendered=args.rendered,resolution=args.resolution,runtime_errors=[line for line in lines if line.startswith(('ERROR:','SCRIPT ERROR:')) or 'leaked' in line])
    report['ok'] = bool(report['ok']) and code==0 and not report['runtime_errors']
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k!='final'}))
    return 0 if report['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
