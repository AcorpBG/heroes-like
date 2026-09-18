#!/usr/bin/env python3
"""Generated native portal arrivals engage defenders without bypassing geometry.

Endpoint/aftermath fixtures are explicit isolated controls, not a full playthrough.
"""
import json
import os
import sys
from pathlib import Path

import battle_readability_regression as runner
import rmg_town_supply_removal_regression as boundary

ROOT = runner.ROOT
OUTPUT = ROOT / '.artifacts/rmg_quality_continuation_20260918'
run_probe = runner.run_probe
probe_environment = runner.probe_environment
COMPILED_OWNERS = boundary.COMPILED_OWNERS + ('scripts/core/BattleRules.gdc',)
SCRIPT = boundary.SCRIPT.split('func run() -> void:')[0] + r'''
const Transit = preload("res://scripts/core/NativeTransitRules.gd")
const Heroes = preload("res://scripts/core/HeroCommandRules.gd")
const GATE := "native_h3maped_f8d41ec2_object_0967"
const DEFENDER := "native_h3maped_f8d41ec2_object_0966"
func clone(source):
	var result=Store.new_session_data()
	result.from_dict(source.to_dict().duplicate(true))
	return result
func gate(session) -> Dictionary:
	return OverworldRules._find_resource_node_by_placement(session,GATE).node
func place(session, point: Vector3i) -> void:
	OverworldRules._set_active_hero_position(session,Vector2i(point.x,point.y),point.z)
	session.overworld.view_level=point.z
	OverworldRules.clear_active_town_visit(session)
	Heroes.commit_active_hero(session)
	OverworldRules.invalidate_spatial_lookup(session)
	OverworldRules._refresh_blocked_tile_index(session)
	OverworldRules._reveal_current_fog_sources(session)
func prepare(source):
	var session=clone(source)
	# Only the source guard is cleared in this endpoint fixture. The real
	# native exit guard, terrain, coordinates, masks and all armies survive.
	session.overworld.resolved_encounters.append("native_h3maped_f8d41ec2_object_0968")
	place(session,Transit.point(gate(session).native_transit.entry))
	return session
func battle_case(source, cost: int, name: String):
	var session=prepare(source)
	var before: Dictionary=normalized(session.to_dict())
	var result:=OverworldRules.travel_native_passage(session,gate(session),cost)
	check(bool(result.get("ok",false)) and result.get("route")=="battle",name+": arrival did not route to combat")
	check(String(session.battle.get("resolved_key",""))==DEFENDER,name+": wrong defender")
	check(Transit.point(session.overworld.hero_position)==Vector3i(59,46,0),name+": wrong exit")
	check(Transit.point(session.battle.get("player_commander_state",{}).get("position",{}))==Vector3i(59,46,0),name+": battle aftermath would restore the source entrance")
	check(int(session.overworld.movement.current)==int(before.overworld.movement.current)-cost,name+": movement cost")
	check(normalized(session.overworld.encounters)==before.overworld.encounters,name+": arrival changed armies/masks")
	check(normalized(session.overworld.resource_nodes)==before.overworld.resource_nodes,name+": arrival changed portals/rewards")
	check(normalized(session.overworld.resources)==before.overworld.resources,name+": arrival granted resources")
	check(OverworldRules.is_tile_visible(session,59,46),name+": arrival did not reveal exit")
	check(BattleRules.battle_payload_can_resume(session),name+": battle cannot resume")
	session.game_state="battle"
	save_roundtrip(session,name)
	var restored=SaveService.restore_manual_session(1)
	check(restored!=null and String(restored.battle.get("resolved_key",""))==DEFENDER,name+": battle lost on restore")
	check(restored!=null and Transit.point(restored.battle.get("player_commander_state",{}).get("position",{}))==Vector3i(59,46,0),name+": restored battle has wrong commander position")
	check(restored!=null and int(restored.overworld.movement.current)==int(session.overworld.movement.current),name+": saved movement changed")
	if restored!=null:
		# Exercise the real aftermath write-back without manufacturing a victory
		# or clearing any defender in this detached state-sync control.
		var aftermath=clone(restored)
		BattleRules._sync_player_force_from_battle(aftermath)
		check(Transit.point(aftermath.overworld.hero_position)==Vector3i(59,46,0),name+": aftermath restored source position")
		check(int(aftermath.overworld.movement.current)==int(before.overworld.movement.current)-cost,name+": aftermath refunded travel cost")
	cases.append({"name":name,"result":result,"defender":DEFENDER,"enemy_stacks":session.battle.stacks.filter(func(s):return s.side=="enemy").map(func(s):return {"unit_id":s.unit_id,"count":s.base_count})})
	return session
func run() -> void:
	out=OS.get_environment("BATTLE_READABILITY_OUT")
	var requested_resolution:=OS.get_environment("TOWN_OVERLAY_RESOLUTION")
	SettingsService.set_presentation_resolution(requested_resolution)
	var service=ClassDB.instantiate("MapPackageService")
	var config:=Select.build_random_map_player_config("10","","",2,"land",false,"homm3_medium",Select.RANDOM_MAP_TEMPLATE_SELECTION_MODE_CATALOG_AUTO,"faction_embercourt","")
	config.monster_strength="normal"
	var generated: Dictionary=service.generate_random_map(config)
	check(bool(generated.get("ok",false)),"generation failed")
	if not generated.get("ok",false):finish();return
	var adoption: Dictionary=service.convert_generated_payload(generated,{"feature_gate":"guarded_portal_arrival","session_save_version":Store.SAVE_VERSION})
	check(bool(adoption.get("ok",false)),"adoption failed")
	if not adoption.get("ok",false):finish();return
	var source=persisted(service,adoption,generated,config,0)
	verify(source,adoption,"unchanged native source")
	check(not gate(source).is_empty(),"exact Medium portal identity changed")
	var session=clone(source)
	place(session,Transit.point(gate(session).native_transit.entry))
	var before: Dictionary=normalized(session.to_dict())
	var result:=OverworldRules.travel_native_passage(session,gate(session))
	check(not bool(result.get("ok",false)) and normalized(session.to_dict())==before,"source guard bypassed or refusal mutated state")
	var rendered=battle_case(source,1,"explicit-travel")
	battle_case(source,0,"paid-walking-arrival")
	session=prepare(source)
	session.overworld.movement.current=0
	before=normalized(session.to_dict())
	result=OverworldRules.travel_native_passage(session,gate(session))
	check(not bool(result.get("ok",false)) and normalized(session.to_dict())==before,"zero-movement explicit jump")
	result=OverworldRules.travel_native_passage(session,gate(session),0)
	check(result.get("route")=="battle" and int(session.overworld.movement.current)==0,"last paid step did not enter battle")
	for kind in ["body","army_and_body","hero","site","artifact","town","terrain"]:
		session=prepare(source)
		var exit: Dictionary=Levels.position(Transit.resolve(session.overworld.resource_nodes,gate(session)).exit)
		if kind in ["body","army_and_body"]:
			session.overworld.map_objects.append({"placement_id":"portal_body_control","kind":"decorative_obstacle","x":59,"y":46,"blocking_body":true,"package_block_tiles":[exit]})
			if kind=="army_and_body":session.overworld.encounters.append({"placement_id":"portal_blocking_raid_control","encounter_id":"encounter_mire_raid","x":59,"y":46,"level":0,"blocking_body":true})
		elif kind=="hero":
			var hero: Dictionary=session.overworld.player_heroes[0].duplicate(true)
			hero.id="portal_friendly_control"
			hero.position=exit
			session.overworld.player_heroes.append(hero)
		elif kind=="site":
			var site: Dictionary=session.overworld.resource_nodes[0].duplicate(true)
			site.merge({"placement_id":"portal_site_control","x":59,"y":46,"level":0,"visit_tile":exit,"package_visit_tiles":[exit],"package_block_tiles":[]},true)
			site.erase("native_transit")
			session.overworld.resource_nodes.append(site)
		elif kind=="artifact":session.overworld.artifact_nodes.append({"placement_id":"portal_artifact_control","artifact_id":"artifact_ashwood_bow","x":59,"y":46,"level":0,"collected":false})
		elif kind=="town":
			var town: Dictionary=session.overworld.towns[0].duplicate(true)
			town.merge({"placement_id":"portal_town_control","x":59,"y":46,"level":0,"visit_tile":exit,"package_block_tiles":[]},true)
			session.overworld.towns.append(town)
		else:
			session.overworld.map[46][59]="rock"
		OverworldRules.invalidate_spatial_lookup(session)
		OverworldRules._refresh_blocked_tile_index(session)
		before=normalized(session.to_dict())
		result=OverworldRules.travel_native_passage(session,gate(session))
		check(not bool(result.get("ok",false)),kind+": blocker was bypassed")
		check(normalized(session.to_dict())==before,kind+": refusal changed gameplay")
	session=prepare(source)
	var entry:=Transit.point(gate(session).native_transit.entry)
	result=OverworldRules.native_passage_travel_check(session,gate(session),entry,"enemy_probe")
	check(not bool(result.get("ok",false)),"AI received an unchecked hostile warp")
	before=normalized(session.to_dict())
	result=OverworldRules.native_passage_travel_check(session,gate(session),entry,String(session.overworld.active_hero_id))
	check(bool(result.get("ok",false)) and normalized(session.to_dict())==before,"player preview changed state or rejected combat")
	# A body-blocking army on the exit takes precedence over the site's guard.
	session.overworld.encounters.append({"placement_id":"portal_occupying_raid_control","encounter_id":"encounter_mire_raid","x":59,"y":46,"level":0,"blocking_body":true})
	OverworldRules.invalidate_spatial_lookup(session)
	OverworldRules._refresh_blocked_tile_index(session)
	var armies: Array=normalized(session.overworld.encounters)
	result=OverworldRules.travel_native_passage(session,gate(session))
	check(result.get("route")=="battle" and session.battle.get("resolved_key")=="portal_occupying_raid_control","occupying army not fought first")
	check(normalized(session.overworld.encounters)==armies,"arrival modified overlapping defenders")
	# Explicit isolated aftermath control, not a fabricated battle victory.
	session.overworld.resolved_encounters.append("portal_occupying_raid_control")
	session.battle={}
	OverworldRules.invalidate_spatial_lookup(session)
	OverworldRules._refresh_blocked_tile_index(session)
	var position:=OverworldRules.hero_position(session)
	var movement:=int(session.overworld.movement.current)
	result=OverworldRules.try_move_along_route(session,[position,position+Vector2i(1,0)])
	check(result.get("route")=="battle" and session.battle.get("resolved_key")==DEFENDER,"remaining native guard could be bypassed")
	check(OverworldRules.hero_position(session)==position and int(session.overworld.movement.current)==movement,"remaining guard charged or moved hero")
	# Invalid combat content cannot charge or strand an arriving hero.
	session=prepare(source)
	for encounter in session.overworld.encounters:
		if encounter.placement_id==DEFENDER:encounter.encounter_id="missing_portal_encounter_control"
	OverworldRules.invalidate_spatial_lookup(session)
	before=normalized(session.to_dict())
	result=OverworldRules.travel_native_passage(session,gate(session))
	check(not bool(result.get("ok",false)) and normalized(session.to_dict())==before,"failed battle setup moved/charged hero")
	if DisplayServer.get_name()!="headless":
		SessionState.set_active_session(rendered)
		var shell=load("res://scenes/battle/BattleShell.tscn").instantiate()
		add_child(shell)
		for frame in range(16):await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var dimensions:=requested_resolution.split("x")
		check(get_viewport().get_texture().get_image().get_size()==Vector2i(int(dimensions[0]),int(dimensions[1])),"screenshot resolution differs from request")
		check(get_viewport().get_texture().get_image().save_png(out.path_join("native-portal-exit-guard-battle.png"))==OK,"battle screenshot")
		shell.queue_free()
		for frame in range(3):await get_tree().process_frame
	finish()
func finish() -> void:
	print("BATTLE_READABILITY_REPORT "+JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,"scope":"real generated Medium endpoints with explicit placement/aftermath controls; not a completed match"}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''


def main():
    if '--platform' in sys.argv:
        import packaged_menu_and_turn_readability_regression as package
        package.ui = sys.modules[__name__]
        code = package.main()
        label = sys.argv[sys.argv.index('--label') + 1]
        receipt = json.loads((Path(os.environ.get('HEROES_BATTLE_READABILITY_ARTIFACT_DIR', str(OUTPUT))) / label / 'packaged-report.json').read_text())
        if not receipt.get('original_probe_sha256') or receipt['original_probe_sha256'] != receipt.get('packaged_probe_sha256'):
            raise RuntimeError('Exact probe did not execute through the release bootstrap')
        return code
    runner.OUTPUT, runner.SCRIPT = OUTPUT, SCRIPT
    runner.run_probe, runner.probe_environment = run_probe, probe_environment
    return runner.main()


if __name__ == '__main__':
    raise SystemExit(main())
