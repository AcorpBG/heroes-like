#!/usr/bin/env python3
"""Replay a normal Medium cache/waypost visit and require a legal return path."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile

from generated_full_match_quality import OUTPUT, ROOT, SCRIPT

BODY = r'''
func walk_to(tile: Vector2i) -> bool:
	for attempt in range(12):
		if not scene_path().ends_with("OverworldShell.tscn"):
			return false
		if OverworldRules.hero_position(session) == tile:
			return true
		if int(session.overworld.movement.current) <= 0:
			var turn: Dictionary = get_tree().current_scene._request_end_turn(false)
			if bool(turn.get("confirmation_required",false)):
				get_tree().current_scene._on_end_turn_confirmation_confirmed()
			await resolve_routes()
			continue
		var before := OverworldRules.hero_position(session)
		get_tree().current_scene._on_map_tile_pressed(tile)
		await resolve_routes()
		if OverworldRules.hero_position(session) == before:
			get_tree().current_scene._on_map_tile_pressed(tile)
			await resolve_routes()
			if OverworldRules.hero_position(session) == before:
				print("CONSUMED_ROUTE_FAILURE "+JSON.stringify({"from":before,"target":tile,"message":get_tree().current_scene.get("_last_message")}))
				return false
	return false

func run_match() -> void:
	get_tree().current_scene = null
	out = OS.get_environment("CONSUMED_OUTPUT")
	action_file = FileAccess.open(out.path_join("actions.jsonl"),FileAccess.WRITE)
	SettingsService.set_presentation_mode("windowed")
	SettingsService.set_presentation_resolution(OS.get_environment("CONSUMED_RESOLUTION"))
	var config: Dictionary = Setup.build_random_map_player_config("10","translated_rmg_template_042_v1","translated_rmg_profile_042_v1",2,"land",false,"homm3_medium",Setup.RANDOM_MAP_TEMPLATE_SELECTION_MODE_SIZE_DEFAULT,"faction_embercourt","")
	var opening_save := OS.get_environment("CONSUMED_OPENING_SAVE")
	var setup: Dictionary = Setup.build_random_map_skirmish_setup_with_retry(config,"normal",Setup.RANDOM_MAP_PLAYER_RETRY_POLICY) if opening_save == "" else {"ok":true}
	var checks := {"setup":bool(setup.get("ok",false))}
	if checks.setup:
		if opening_save == "":
			session = SessionState.set_active_session(Setup.start_random_map_skirmish_session_from_setup(setup))
		else:
			session = SessionState.restore_session(JSON.parse_string(FileAccess.get_file_as_string(opening_save)))
		checks["normal_opening"] = session.day == 1 and OverworldRules.hero_position(session) == Vector2i(43,40)
		AppRouter.go_to_overworld()
		await settle()
		var node: Dictionary = OverworldRules._find_resource_node_by_placement(session,"native_h3maped_93c0f05a_object_1055").get("node",{})
		var original_mask: Array = node.get("package_block_tiles",[]).duplicate(true)
		var terrain_hash := hash(session.overworld.map)
		checks["exact_cache"] = node.get("site_id","") == "site_waystone_cache" and node.get("visit_tile",{}).get("x",0) == 49
		checks["uncollected_body_blocks"] = OverworldRules.tile_is_blocked(session,49,49)
		# Pure lifecycle controls do not modify the live session or source masks.
		var repeatable := {"site_id":"site_reedboat_supply_stand","collected":true,"package_block_tiles":[{"x":1,"y":1}]}
		checks["repeatable_body_retained"] = OverworldRules._resource_node_blocks_body_tiles(repeatable,{})
		var passage := {"site_id":"site_waystone_cache","collected":true,"h3m_type_id":45,"package_block_tiles":[{"x":1,"y":1}]}
		checks["native_transit_body_retained"] = OverworldRules._resource_node_blocks_body_tiles(passage,{})
		var overlap = preload("res://scripts/core/SessionStateStore.gd").new_session_data()
		overlap.overworld = {"resource_nodes":[{"site_id":"site_waystone_cache","collected":true,"package_block_tiles":[{"x":1,"y":1}]}],"map_objects":[{"kind":"decorative_obstacle","package_block_tiles":[{"x":1,"y":1}]}]}
		checks["overlapping_scenery_retained"] = OverworldRules._build_blocked_tile_index(overlap).has(OverworldRules._tile_key(Vector2i(1,1)))
		overlap.overworld.map_objects = []
		checks["isolated_consumed_mask_absent"] = not OverworldRules._build_blocked_tile_index(overlap).has(OverworldRules._tile_key(Vector2i(1,1)))
		var path_ok := true
		for tile in [Vector2i(44,44),Vector2i(44,43),Vector2i(47,46),Vector2i(47,45),Vector2i(48,47),Vector2i(46,49)]:
			if not await walk_to(tile):
				path_ok = false
				break
		checks["legal_approach"] = path_ok
		if path_ok:
			var stores_before: int = session.overworld.resources.gold
			checks["cache_arrival"] = await walk_to(Vector2i(49,49))
			node = OverworldRules._find_resource_node_by_placement(session,"native_h3maped_93c0f05a_object_1055").get("node",{})
			checks["cache_claimed"] = bool(node.get("collected",false))
			checks["exact_reward"] = int(session.overworld.resources.gold) == stores_before + 400
			checks["source_mask_preserved"] = original_mask == node.get("package_block_tiles",[])
			checks["terrain_preserved"] = terrain_hash == hash(session.overworld.map)
			checks["consumed_body_unblocked"] = not OverworldRules.tile_is_blocked(session,49,49)
			checks["consumed_action_removed"] = not OverworldRules.tile_has_route_interaction(session,49,49)
			checks["consumed_body_feedback_removed"] = OverworldRules.blocking_object_feedback_surface_at_tile(session,49,49).is_empty()
			await screenshot("cache_collected")
			checks["waypost_arrival"] = await walk_to(Vector2i(50,48))
			await screenshot("waypost")
			var back_path: Array = get_tree().current_scene._build_path(OverworldRules.hero_position(session),Vector2i(49,49))
			checks["backtrack_path_exists"] = not back_path.is_empty()
			checks["backtrack_moves"] = await walk_to(Vector2i(49,49))
			checks["no_second_reward"] = int(session.overworld.resources.gold) == stores_before + 400
			checks["permanent_sawmill_body_retained"] = OverworldRules.tile_is_blocked(session,47,49)
			checks["adjacent_waypost_body_retained"] = OverworldRules.tile_is_blocked(session,49,48)
			await checkpoint("post_collection",1)
			checks["save_roundtrip_exact"] = checkpoint_labels.has("post_collection") and failures.is_empty()
			checks["restored_cache_unblocked"] = not OverworldRules.tile_is_blocked(session,49,49)
			await screenshot("backtrack_restored")
	var ok: bool = checks.size() == 25 and checks.values().all(func(value):return bool(value)) and failures.is_empty()
	print("CONSUMED_SITE_COLLISION_REPORT "+JSON.stringify({"ok":ok,"checks":checks,"failures":failures,"day":session.day if session != null else 0,"policy":"normal seeded map, real pointer movement/collection/turn/save; no injected gameplay state"}))
	get_tree().quit(0 if ok else 1)
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--label', required=True)
    parser.add_argument('--rendered', action='store_true')
    parser.add_argument('--opening-save', type=Path, help='Replay an unmodified Day-1 generated opening save; generation is covered by the default mode')
    parser.add_argument('--resolution', choices=['1280x720', '1920x1080'], default='1280x720')
    args = parser.parse_args()
    if not args.label or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789_-' for c in args.label):
        parser.error('label must be a fresh lowercase slug')
    out = OUTPUT / args.label
    out.mkdir(parents=True, exist_ok=False)
    with tempfile.TemporaryDirectory(prefix='consumed-', dir=OUTPUT) as temporary:
        work = Path(temporary)
        (work/'probe.gd').write_text(SCRIPT[:SCRIPT.index('func run_match()')] + BODY)
        scene = work/'probe.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="ConsumedSite" type="Node"]\nscript = ExtResource("1")\n' % (work/'probe.gd').relative_to(ROOT))
        env = dict(os.environ, XDG_DATA_HOME=str(out/'data'), CONSUMED_OUTPUT=str(out), CONSUMED_RESOLUTION=args.resolution, CONSUMED_OPENING_SAVE=str(args.opening_save.resolve()) if args.opening_save else '')
        command = ['godot4','--path',str(ROOT),'--audio-driver','Dummy','--accessibility','disabled','res://'+str(scene.relative_to(ROOT))]
        command = ['dbus-run-session','--','xvfb-run','-a','-s','-screen 0 2200x1200x24']+command if args.rendered else command+['--headless']
        with (out/'runtime.log').open('w') as log:
            result = subprocess.run(['timeout','240s']+command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=260)
    lines = (out/'runtime.log').read_text().splitlines()
    reports = [json.loads(line.split(' ',1)[1]) for line in lines if line.startswith('CONSUMED_SITE_COLLISION_REPORT ')]
    report = reports[-1] if reports else {'ok':False}
    report.update(returncode=result.returncode, rendered=args.rendered, resolution=args.resolution, runtime_errors=[line for line in lines if line.startswith(('ERROR:','SCRIPT ERROR:')) or 'leaked' in line])
    if args.opening_save:
        report['opening_save_sha256'] = hashlib.sha256(args.opening_save.read_bytes()).hexdigest()
    report['ok'] = bool(report['ok']) and not report['runtime_errors'] and result.returncode == 0
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report))
    return 0 if report['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
