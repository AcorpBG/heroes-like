#!/usr/bin/env python3
"""Exact old-owner scenery indexes, with recorded saves and explicit mutations."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import tempfile

from generated_full_match_quality import ROOT, OUTPUT, SCRIPT as MATCH_SCRIPT
from generated_town_order_profile import run_probe, stop_requested

MARKER = 'OVERWORLD_SCENERY_INDEX_REPORT '
VIEW = '''extends "%s"
var body_calls := 0
func _index_generated_decorative_body_cells(object: Dictionary) -> void:
\tbody_calls += 1
\tsuper._index_generated_decorative_body_cells(object)
'''
SCRIPT = r'''
extends Node
const Levels = preload("res://scripts/core/OverworldLevelRules.gd")
var session
var reference
var current
var checks := 0
var failures := []
var observations := []
var original_payload := {}
var dimensions_override := Vector2i.ZERO
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func indexes(view) -> Dictionary:
	var result := {}
	for name in ["_towns_by_tile","_town_footprints_by_tile","_resources_by_tile","_artifacts_by_tile","_encounters_by_tile","_rememberable_encounters_by_tile","_decorative_objects_by_tile","_generated_decorative_bodies_by_tile","_standalone_map_objects_by_tile","_heroes_by_tile"]:
		result[name] = view.get(name).duplicate(true)
	return result
func state() -> String:
	return JSON.stringify(session.to_dict()) if session != null else "null"
func apply(view) -> float:
	view.body_calls = 0
	view.validation_reset_profile()
	var started := Time.get_ticks_usec()
	var dimensions: Vector2i = dimensions_override if dimensions_override.x>0 else (OverworldRules.derive_map_size(session) if session != null else Vector2i.ONE)
	view.set_map_state(session, session.overworld.map if session != null else [], dimensions, OverworldRules.hero_position(session) if session != null else Vector2i.ZERO)
	return float(Time.get_ticks_usec()-started)/1000.0
func compare_case(label: String, body_expectation: String, forced_reference: bool = false) -> void:
	var before := state()
	reference.validation_set_force_index_rebuild(forced_reference)
	var reference_ms := apply(reference)
	var reference_indexes := indexes(reference)
	var previous_generation: int = current._state_cache_generation
	var current_ms := apply(current)
	var current_indexes := indexes(current)
	check(current_indexes == reference_indexes, label+" complete indexed payloads differ")
	check(state() == before, label+" view changed complete gameplay state")
	if body_expectation == "reused": check(current.body_calls == 0,label+" rebuilt unchanged decorative bodies")
	if body_expectation == "rebuilt": check(current.body_calls > 0,label+" did not rebuild changed decorative bodies")
	if label in ["complete_object_metadata","body_mask_added","body_mask_removed","overlapping_source_added","placement_order","manifest_candidate_order","manifest_reload"]:
		check(current._state_cache_generation>previous_generation,label+" did not redraw changed scenery")
	observations.append({"case":label,"reference_ms":reference_ms,"current_ms":current_ms,"reference_forced":forced_reference,"reference_body_calls":reference.body_calls,"current_body_calls":current.body_calls,"body_cells":current._generated_decorative_bodies_by_tile.size(),"current_profile":current.validation_profile_snapshot()})
func restore_source() -> void:
	session = SessionState.restore_session(original_payload.duplicate(true))
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	original_payload = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("SCENERY_SAVE")))
	restore_source()
	if session == null:
		push_error("recorded session restore failed");get_tree().quit(1);return
	var expected := original_payload.duplicate(true)
	for key in ["saved_at_unix","save_slot_type","saved_from_game_state","saved_from_scenario_status","saved_from_launch_mode"]:expected.erase(key)
	check(JSON.parse_string(state()) == expected,"restore changed recorded gameplay state")
	reference = load(OS.get_environment("SCENERY_REFERENCE")).new()
	current = load(OS.get_environment("SCENERY_CURRENT")).new()
	for view in [reference,current]:
		view.size = Vector2(1000,600)
		add_child(view)
		view.set_route_preview_enabled(false)
	compare_case("recorded_cold", "rebuilt")
	check(current._generated_decorative_bodies_by_tile.size()>100,"recorded case has insufficient generated scenery")
	compare_case("unchanged", "reused")
	# Separate renderer invalidation fixtures, not actions in an accepted match.
	var resource: Dictionary = session.overworld.resource_nodes[0]
	resource.collected = not bool(resource.get("collected",false))
	resource.collected_by_faction_id = "player" if resource.collected else ""
	compare_case("resource_claim_state", "reused")
	session.overworld.towns[0].owner = "enemy" if session.overworld.towns[0].owner == "player" else "player"
	compare_case("town_control", "reused")
	var encounter: Dictionary = session.overworld.encounters[0]
	encounter.resolved = true
	session.overworld.resolved_encounters.append(encounter.placement_id)
	compare_case("encounter_resolved", "reused")
	if not session.overworld.artifact_nodes.is_empty():
		session.overworld.artifact_nodes[0].collected = not bool(session.overworld.artifact_nodes[0].get("collected",false))
		compare_case("artifact_claim_state", "reused")
	var bodies: Array = session.overworld.map_objects.filter(func(row):return String(row.get("runtime_object_role",""))=="decorative_blocker_sprite" and not row.get("package_block_tiles",[]).is_empty())
	check(not bodies.is_empty(),"no generated body fixture")
	if not bodies.is_empty():
		var body: Dictionary = bodies[0]
		body["scenery_metadata_control"] = "exact payload freshness"
		compare_case("complete_object_metadata", "rebuilt",true)
		var tile: Dictionary = body.package_block_tiles[0]
		session.overworld.map[int(tile.y)][int(tile.x)] = "lava" if session.overworld.map[int(tile.y)][int(tile.x)] != "lava" else "snow"
		compare_case("terrain_asset_choice", "rebuilt",true)
		body.package_block_tiles.append({"x":0,"y":0,"level":0})
		compare_case("body_mask_added", "rebuilt",true)
		body.package_block_tiles.pop_back()
		compare_case("body_mask_removed", "rebuilt",true)
		var overlap: Dictionary = body.duplicate(true)
		overlap.placement_id = "scenery_overlap_control"
		session.overworld.map_objects.append(overlap)
		compare_case("overlapping_source_added", "rebuilt",true)
		session.overworld.map_objects.reverse()
		compare_case("placement_order", "rebuilt",true)
		for view in [reference,current]:
			for biome in view._generated_decorative_blocker_asset_ids_by_biome:
				view._generated_decorative_blocker_asset_ids_by_biome[biome].reverse()
		compare_case("manifest_candidate_order", "rebuilt",true)
		for view in [reference,current]:view._load_overworld_art_manifest()
		compare_case("manifest_reload", "rebuilt",true)
		var before_reload: int = current._state_cache_generation
		for view in [reference,current]:view._load_overworld_art_manifest()
		check(current._state_cache_generation>before_reload,"same-id manifest reload did not invalidate drawn textures")
		compare_case("same_id_manifest_reload", "rebuilt",true)
		var standalone_id: String = current._map_object_asset_ids.keys()[0]
		session.overworld.map_objects.append({"placement_id":"scenery_standalone_control","object_id":standalone_id,"kind":"map_object","x":1,"y":1,"level":0})
		compare_case("standalone_added", "rebuilt",true)
		check(current._standalone_map_objects_by_tile.has("1,1"),"standalone manifest-backed object was not indexed")
		for view in [reference,current]:view._map_object_asset_ids.erase(standalone_id)
		compare_case("standalone_manifest_removed", "rebuilt",true)
		check(not current._standalone_map_objects_by_tile.has("1,1"),"standalone classification retained a removed mapping")
		for view in [reference,current]:view._load_overworld_art_manifest()
		compare_case("standalone_manifest_restored", "rebuilt",true)
		dimensions_override = OverworldRules.derive_map_size(session)/2
		compare_case("changed_dimensions", "rebuilt",true)
		dimensions_override = Vector2i.ZERO
		compare_case("restored_dimensions", "rebuilt",true)
		var underground: Dictionary = body.duplicate(true)
		underground.placement_id = "scenery_level_control"
		underground.level = 1
		if underground.has("position"):underground.position.level=1
		for key in ["primary_tile","visit_tile"]:
			if underground.has(key):underground[key].level=1
		session.overworld.map_objects.append(underground)
		session.overworld.map_size.level_count=2
		var layers: Dictionary = session.overworld.terrain_layers
		layers.terrain.levels.append(layers.terrain.levels[0].duplicate())
		session.overworld.view_level=1
		compare_case("view_level_changed", "rebuilt",true)
		session.overworld.view_level=0
		compare_case("view_level_return", "rebuilt",true)
	current.validation_set_force_index_rebuild(true)
	compare_case("forced_rebuild", "rebuilt",true)
	current.validation_set_force_index_rebuild(false)
	restore_source()
	compare_case("session_replacement", "rebuilt",true)
	restore_source()
	compare_case("identical_session_replacement", "rebuilt",true)
	session = null
	compare_case("null_reset", "reused",true)
	check(indexes(current).values().all(func(value):return value.is_empty()),"null reset retained object references")
	restore_source()
	compare_case("after_reset", "rebuilt",true)
	print("OVERWORLD_SCENERY_INDEX_REPORT "+JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"scope":"exact view-index controls; explicit isolated mutations are not full-match actions"}))
	reference.queue_free();current.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
'''

MOVEMENT = r'''
func run_match() -> void:
	get_tree().current_scene = null
	out = OS.get_environment("SCENERY_OUTPUT")
	SettingsService.set_presentation_mode("windowed")
	SettingsService.set_presentation_resolution("1280x720")
	SettingsService.set_reduced_motion_enabled(true)
	get_window().content_scale_size = Vector2i(1280,720)
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("SCENERY_SAVE")))
	var observations := []
	var reference_state := ""
	var reference_indexes := {}
	var reference_target := ""
	for variant in ["reference","current"]:
		session = SessionState.restore_session(payload.duplicate(true))
		var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
		var view = shell.get_node("%Map")
		view.set_script(load(OS.get_environment("SCENERY_REFERENCE" if variant=="reference" else "SCENERY_CURRENT")))
		get_tree().root.add_child(shell)
		get_tree().current_scene = shell
		await settle()
		var origin := OverworldRules.hero_position(session)
		var candidates := []
		for target in shell._validation_targets("resource"):
			if not known(target) or String(target.get("site_id","")) not in ["site_waystone_cache","site_ore_crates","site_aetherglass_lens_house"] or bool(target.get("collected",false)) or Transit.is_native(target) or not resource_claim_feasible(target):continue
			var entry: Dictionary = target.get("visit_tile",target)
			var tile := Vector2i(int(entry.x),int(entry.y))
			if not OverworldRules.guard_engagement_encounter_at_tile(session,tile.x,tile.y).is_empty():continue
			candidates.append({"id":String(target.placement_id),"tile":tile,"distance":origin.distance_to(tile)})
		candidates.sort_custom(func(a,b):return a.id<b.id if is_equal_approx(a.distance,b.distance) else a.distance<b.distance)
		var selected := {}
		for candidate in candidates:
			var path: Array = shell._build_path(origin,candidate.tile)
			if path.size()<2 or not path.all(func(tile):return OverworldRules.is_tile_visible(session,tile.x,tile.y)):continue
			var preview: Dictionary = OverworldRules.route_movement_preview(session,path,int(session.overworld.movement.current))
			if not bool(preview.get("destination_reachable",false)):continue
			selected=candidate;break
		if selected.is_empty():failures.append(variant+" no fully reachable visible unguarded resource claim");break
		if variant=="reference":reference_target=selected.id
		elif selected.id!=reference_target:failures.append("matched movement selected a different target")
		if OS.get_environment("SCENERY_CAPTURE")!="0":await screenshot(variant+"_before")
		view.body_calls=0
		var started := Time.get_ticks_usec()
		shell._on_map_tile_pressed(selected.tile)
		await settle()
		if OverworldRules.hero_position(session)==origin:
			shell._on_map_tile_pressed(selected.tile)
			await settle()
		var wait_started := Time.get_ticks_msec()
		while view._hero_movement_active or view._object_resolution_active or view._object_resolution_queued:
			if Time.get_ticks_msec()-wait_started>30000:failures.append("movement presentation did not settle");break
			await get_tree().process_frame
		var usable_ms := float(Time.get_ticks_usec()-started)/1000.0
		var claimed: Dictionary = OverworldRules._find_resource_node_by_placement(session,selected.id).get("node",{})
		if OverworldRules.hero_position(session)!=selected.tile or not bool(claimed.get("collected",false)) or String(claimed.get("collected_by_faction_id",""))!="player":failures.append(variant+" ordinary pointer movement did not claim the resource")
		var final_state := JSON.stringify(session.to_dict())
		var indexed := {}
		for name in ["_towns_by_tile","_town_footprints_by_tile","_resources_by_tile","_artifacts_by_tile","_encounters_by_tile","_rememberable_encounters_by_tile","_decorative_objects_by_tile","_generated_decorative_bodies_by_tile","_standalone_map_objects_by_tile","_heroes_by_tile"]:indexed[name]=view.get(name).duplicate(true)
		if variant=="reference":reference_state=final_state;reference_indexes=indexed
		else:
			if final_state!=reference_state:failures.append("pointer collection complete gameplay state differs")
			if indexed!=reference_indexes:failures.append("pointer collection complete view indexes differ")
			if view.body_calls!=0:failures.append("ordinary collection rebuilt unchanged scenery")
		observations.append({"variant":variant,"target":selected.id,"from":origin,"to":OverworldRules.hero_position(session),"movement":session.overworld.movement.duplicate(true),"usable_ms":usable_ms,"body_calls":view.body_calls,"state_sha256":final_state.sha256_text(),"map_profile":view.validation_profile_snapshot()})
		if OS.get_environment("SCENERY_CAPTURE")!="0":await screenshot(variant+"_collected")
		get_tree().current_scene=null
		shell.queue_free()
		await get_tree().process_frame
	print("OVERWORLD_SCENERY_INDEX_REPORT "+JSON.stringify({"ok":failures.is_empty() and observations.size()==2,"failures":failures,"observations":observations,"scope":"real pointer collection on unchanged recorded save; complete old/current state and indexes; reduced-motion rendered 1280x720"}))
	get_tree().quit(0 if failures.is_empty() and observations.size()==2 else 1)
'''


def main():
    signal.signal(signal.SIGTERM, stop_requested)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--label', required=True)
    parser.add_argument('--save', required=True, type=Path)
    parser.add_argument('--reference-revision', default='ddd8d6ad')
    parser.add_argument('--rendered-movement', action='store_true')
    parser.add_argument('--no-capture', action='store_true', help='Repeat timings without duplicate screenshots')
    args = parser.parse_args()
    if not re.fullmatch('[a-z0-9_-]+', args.label):
        parser.error('fresh lowercase label required')
    if not re.fullmatch('[0-9a-f]{8,40}', args.reference_revision):
        parser.error('exact reference revision required')
    source = args.save.resolve()
    source_hash = hashlib.sha256(source.read_bytes()).hexdigest()
    owner = 'scenes/overworld/OverworldMapView.gd'
    old_source = subprocess.check_output(['git','show',f'{args.reference_revision}:{owner}'], cwd=ROOT, text=True)
    current_hash = hashlib.sha256((ROOT/owner).read_bytes()).hexdigest()
    out = OUTPUT/args.label
    out.mkdir(parents=True, exist_ok=False)
    temporary_root = '/dev/shm' if Path('/dev/shm').is_dir() else None
    with tempfile.TemporaryDirectory(prefix='scenery-index-',dir=OUTPUT) as temporary, tempfile.TemporaryDirectory(prefix='heroes-scenery-data-',dir=temporary_root) as data:
        work = Path(temporary)
        def resource(path): return 'res://'+str(path.relative_to(ROOT))
        (work/'old_view.gd').write_text(old_source)
        (work/'reference.gd').write_text(VIEW % resource(work/'old_view.gd'))
        (work/'current.gd').write_text(VIEW % ('res://'+owner))
        (work/'probe.gd').write_text(MATCH_SCRIPT[:MATCH_SCRIPT.index('func run_match()')]+MOVEMENT if args.rendered_movement else SCRIPT)
        scene = work/'probe.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="%s" id="1"]\n[node name="SceneryIndex" type="Node"]\nscript = ExtResource("1")\n' % resource(work/'probe.gd'))
        env = dict(os.environ,XDG_DATA_HOME=data,SCENERY_SAVE=str(source),SCENERY_REFERENCE=resource(work/'reference.gd'),SCENERY_CURRENT=resource(work/'current.gd'),SCENERY_OUTPUT=str(out),SCENERY_CAPTURE='0' if args.no_capture else '1')
        command = ['godot4','--path',str(ROOT),'--audio-driver','Dummy','--accessibility','disabled',resource(scene)]
        command = ['dbus-run-session','--','xvfb-run','-a','-s','-screen 0 2200x1200x24']+command+['--resolution','1280x720'] if args.rendered_movement else command+['--headless']
        with (out/'runtime.log').open('w') as log:
            code = run_probe(command,env,log)
    lines = (out/'runtime.log').read_text().splitlines()
    reports = [json.loads(line[len(MARKER):]) for line in lines if line.startswith(MARKER)]
    report = reports[-1] if reports else {'ok':False,'failures':['missing final report']}
    errors = [line for line in lines if line.startswith(('ERROR:','SCRIPT ERROR:')) or 'leaked' in line]
    report.update(returncode=code,runtime_errors=errors,source_save_sha256=source_hash,source_save_unchanged=source_hash==hashlib.sha256(source.read_bytes()).hexdigest(),reference_revision=args.reference_revision,reference_owner_sha256=hashlib.sha256(old_source.encode()).hexdigest(),current_owner_sha256=current_hash)
    report['ok'] = bool(report['ok']) and code==0 and not errors and report['source_save_unchanged']
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({key:value for key,value in report.items() if key!='observations'}))
    return 0 if report['ok'] else 1


if __name__=='__main__':raise SystemExit(main())
