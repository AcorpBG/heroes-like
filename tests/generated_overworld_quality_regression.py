#!/usr/bin/env python3
"""Owner quality goal: source identity through visible, playable destinations."""
import json
import os
import sys
from pathlib import Path

import battle_readability_regression as runner
import rmg_town_supply_removal_regression as boundary

ROOT = runner.ROOT
sys.path.insert(0, str(ROOT / 'tools'))
import rmg_guard_space_audit as audit

OUTPUT = ROOT / '.artifacts/overworld-quality-20260918'
run_probe = runner.run_probe
probe_environment = runner.probe_environment
COMPILED_OWNERS = boundary.COMPILED_OWNERS + ('scenes/overworld/OverworldMapView.gdc', 'scenes/overworld/OverworldGroundSurface.gdc', 'scripts/persistence/NativeSceneryRules.gdc')
SCRIPT = audit.SCRIPT.split('func reproduce_bypass(')[0] + r'''
func guarded_presence(session, view, label: String) -> Dictionary:
	var by_type := {}
	var artifact_sites := 0
	var contract_count := 0
	var exercised := {}
	for index in range(session.overworld.resource_nodes.size()):
		var node: Dictionary = session.overworld.resource_nodes[index]
		var site := ContentService.get_resource_site(String(node.site_id))
		var contract: Dictionary = site.get("guarded_reward_contract", {})
		if contract.is_empty():continue
		contract_count+=1
		var type_id := int(node.get("h3m_type_id",-1))
		by_type[str(type_id)]=int(by_type.get(str(type_id),0))+1
		var object := ContentService.get_map_object(String(node.object_id))
		check(node.kind=="resource_site",label+": guarded site demoted to loose pickup")
		check(object.get("resource_site_id","")==node.site_id,label+": guarded object/site contract mismatch")
		var expected_asset := String(view._map_object_asset_ids.get(String(node.object_id),""))
		check(expected_asset!="" and view._resource_asset_id(node)==expected_asset,label+": guarded site lost distinct original art")
		check(view._semantic_visual_scale_class(view._resource_object_profile(node))!="loose_pickup",label+": guarded site drawn as portable cache")
		var guard := OverworldRules.resource_site_blocking_guard(session,node,site)
		check(not guard.is_empty(),label+": live guarded reward has no defender "+String(node.placement_id))
		if guard.get("generated_package_guard_policy","")=="live_guarded_reward_contract":
			check(normalized(guard.package_guard_engagement_tiles)==normalized(node.package_visit_tiles),label+": internal defender steals surrounding road/guard control")
		if not String(contract.get("artifact_reward_table_id","")).is_empty():artifact_sites+=1
		# Exercise both previously-free fixed proxies, plus an artifact-bearing
		# pool candidate. This is a post-victory boundary fixture, not an auto-won battle.
		var test_key := str(type_id) if type_id in [6,84] else ("artifact" if contract.has("artifact_reward_table_id") else "")
		if test_key=="" or exercised.has(test_key):continue
		exercised[test_key]=true
		var clone=Store.new_session_data()
		clone.from_dict(session.to_dict().duplicate(true))
		var visit: Dictionary=node.get("visit_tile",node)
		OverworldRules._set_active_hero_position(clone,Vector2i(int(visit.x),int(visit.y)),int(visit.get("level",0)))
		var blocked := OverworldRules._collect_resource_node_result(clone,{"index":index,"node":clone.overworld.resource_nodes[index]})
		check(not bool(blocked.get("ok",false)),label+": guarded reward granted before battle")
		var battle := BattleRules.create_battle_payload(clone,guard)
		check(not battle.get("stacks",[]).filter(func(stack):return stack.side=="enemy").is_empty(),label+": defender cannot enter combat")
		clone.overworld.resolved_encounters.append(String(guard.placement_id))
		OverworldRules.normalize_overworld_state(clone)
		var before := ArtifactRules.owned_artifact_ids(clone.overworld.hero)
		var claim := OverworldRules._collect_resource_node_result(clone,{"index":index,"node":clone.overworld.resource_nodes[index]})
		check(bool(claim.get("ok",false)),label+": cleared site reward failed "+String(claim.get("message","")))
		if contract.has("artifact_reward_table_id"):
			check(ArtifactRules.owned_artifact_ids(clone.overworld.hero).size()==before.size()+1,label+": restored guarded artifact reward not granted")
		save_roundtrip(clone,label+"-guarded-"+test_key)
		var restored=SaveService.restore_manual_session(1)
		if restored!=null:check(ArtifactRules.owned_artifact_ids(restored.overworld.hero)==ArtifactRules.owned_artifact_ids(clone.overworld.hero),label+": artifact reward lost on save")
	return {"count":contract_count,"artifact_sites":artifact_sites,"by_type":by_type,"exercised":exercised.keys()}

func portable_resources(session, view, label: String) -> Dictionary:
	var exercised := {}
	var all_count := 0
	for index in range(session.overworld.resource_nodes.size()):
		var node: Dictionary = session.overworld.resource_nodes[index]
		if int(node.get("h3m_type_id", -1)) != 79:continue
		all_count += 1
		var site := ContentService.get_resource_site(String(node.site_id))
		var object := ContentService.get_map_object(String(node.object_id))
		var resource_id := String(node.get("resource_id", ""))
		check(not OverworldRules._resource_site_is_persistent(site),label+": portable resource became a production site")
		check(object.get("resource_site_id", "") == node.site_id and bool(object.get("visitable", false)),label+": loose pickup lacks live object/site contract")
		check(site.get("rewards", {}).size()==1 and int(site.get("rewards", {}).get(resource_id,0))>0,label+": wrong loose-resource reward")
		check(view._resource_asset_id(node)==view._map_object_asset_ids.get(node.object_id,"missing"),label+": loose resource lost its unique original art")
		if exercised.has(resource_id) or not OverworldRules.resource_site_blocking_guard(session,node,site).is_empty():continue
		var clone=Store.new_session_data()
		clone.from_dict(session.to_dict().duplicate(true))
		var visit: Dictionary=node.get("visit_tile",node)
		OverworldRules._set_active_hero_position(clone,Vector2i(int(visit.x),int(visit.y)),int(visit.get("level",0)))
		var before: Dictionary=clone.overworld.resources.duplicate(true)
		var income := OverworldRules.controlled_resource_site_income(clone,"player",clone.day+1)
		var expected := preload("res://scripts/core/DifficultyRules.gd").scale_reward_resources(clone,site.rewards)
		var claim := OverworldRules.collect_active_resource(clone)
		check(bool(claim.get("ok",false)),label+": loose resource cannot be collected "+resource_id)
		for key in before:
			check(int(clone.overworld.resources.get(key,0))-int(before[key])==int(expected.get(key,0)),label+": wrong one-time resource delta "+resource_id+"/"+String(key))
		check(not bool(OverworldRules.collect_active_resource(clone).get("ok",false)),label+": pickup granted twice")
		check(OverworldRules.controlled_resource_site_income(clone,"player",clone.day+1)==income,label+": pickup grants permanent income")
		save_roundtrip(clone,label+"-pickup-"+resource_id)
		var restored=SaveService.restore_manual_session(1)
		check(restored!=null and restored.overworld.resource_nodes[index].collected,label+": pickup collection lost on save")
		if restored!=null:check(not bool(OverworldRules.collect_active_resource(restored).get("ok",false)),label+": restored pickup grants twice")
		exercised[resource_id]=String(node.placement_id)
	check(exercised.size()==7,label+": all seven loose-resource kinds not playable "+JSON.stringify(exercised.keys()))
	return {"count":all_count,"exercised":exercised}

func presentation_contracts(view, session, label: String) -> void:
	var authority: Dictionary = normalized(session.to_dict())
	var scenery: Dictionary=view.validation_generated_object_visual_summary()
	for key in ["all_source_scenery_adopted","body_tile_keys_exact","all_body_assets_loaded","all_body_cells_visually_covered","all_body_assets_terrain_matched"]:
		check(bool(scenery.get(key,false)),label+": scenery "+key)
	var manifest := ContentService.load_json("res://art/overworld/native_scenery.json")
	for type_id in manifest.source_types:
		for biome_id in manifest.landscape_palettes.rock:
			var fixture := {"h3m_type_id":int(type_id),"native_scenery_art_version":2}
			var assets := Bridge.NativeScenery.asset_candidates(fixture,biome_id)
			check(not assets.is_empty(),label+": missing semantic scenery "+type_id+"/"+biome_id)
			for asset_id in assets:check(view._object_texture_for_asset(asset_id) is Texture2D,label+": missing semantic raster "+String(asset_id))
			fixture.native_scenery_art_version=1
			check(Bridge.NativeScenery.asset_candidates(fixture,biome_id)==manifest.source_types[type_id].get("asset_ids",[]),label+": old save semantic selection changed")
	var rect := Rect2(0,0,74,74)
	for horizontal in [Vector2i.LEFT,Vector2i.RIGHT]:
		for vertical in [Vector2i.UP,Vector2i.DOWN]:
			var curve: PackedVector2Array=view._road_land_corner_points(rect,[horizontal,vertical])
			check(curve.size()==13,label+": road corner lacks smooth join")
			check(curve[0].is_equal_approx(view._road_connector_end(rect,horizontal)) and curve[-1].is_equal_approx(view._road_connector_end(rect,vertical)),label+": road edge continuity changed")
	check(view._road_land_corner_points(rect,[Vector2i.LEFT,Vector2i.RIGHT]).is_empty(),label+": straight road turned into corner")
	for guard in session.overworld.encounters:
		var asset_id: String=view._encounter_identity_asset_id(guard)
		var texture=view._object_texture_for_asset(asset_id)
		check(texture is Texture2D,label+": neutral identity lost original raster")
		if not texture is Texture2D:continue
		var payload: Dictionary=view._object_painted_sprite_draw_payload(asset_id,texture,Vector2.ZERO,74*1.08)
		check(absf(payload.draw_aspect-payload.source_aspect)<0.001,label+": neutral art distorted")
		check(is_equal_approx(maxf(payload.draw_rect.size.x,payload.draw_rect.size.y),74*1.08),label+": transparent padding shrank neutral sprite")
	check(normalized(session.to_dict())==authority,label+": presentation modified gameplay/save state")
	write_json(label+"-scenery.json",scenery)

func encounter_entry(session, label: String) -> Array:
	var played := []
	var exercised := {}
	for guard in session.overworld.encounters:
		var kind := "internal" if guard.get("generated_package_guard_policy","")=="live_guarded_reward_contract" else "native"
		if exercised.has(kind):continue
		var tile := Vector2i(int(guard.x),int(guard.y))
		var clone=Store.new_session_data()
		clone.from_dict(session.to_dict().duplicate(true))
		var entered := false
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var start: Vector2i=tile+offset
			# Adjacent-position fixture may already be inside a native control
			# ring; that is exactly the entry we need to exercise, not exclude.
			if OverworldRules.tile_is_blocked(clone,start.x,start.y):continue
			OverworldRules._set_active_hero_position(clone,start,0)
			var moved := OverworldRules.try_move_along_route(clone,[start,tile])
			if not bool(moved.get("ok",false)):continue
			check(moved.get("route","")=="battle" and not clone.battle.is_empty(),label+": legal step onto neutral did not start a fight")
			entered=not clone.battle.is_empty()
			break
		if not entered:continue
		exercised[kind]=true
		clone.game_state="battle"
		var result := preload("res://scripts/core/BattleAutoResolveRules.gd").resolve_active_battle(clone)
		check(bool(result.get("ok",false)) and bool(result.get("completed",false)),label+": real neutral battle stalled "+String(result.get("stop_reason","")))
		played.append({"placement_id":guard.placement_id,"kind":kind,"state":result.get("state",""),"steps":result.get("steps",0),"fixture":"adjacent legal entry with unchanged starting army; shipped Quick Resolve, no forced victory"})
		if exercised.size()==2:break
	check(exercised.size()==2,label+": native and internal defender entry not both exercised")
	return played

func presence(view, session) -> Dictionary:
	var result := {"resources":[],"artifacts":[],"encounters":[]}
	for node in session.overworld.resource_nodes:
		var profile: Dictionary = view._resource_object_profile(node)
		var site := ContentService.get_resource_site(String(node.site_id))
		var tile := Vector2i(int(node.x),int(node.y))
		var rect: Rect2 = view._tile_rect(view._board_rect(),tile)
		var resource_rect: Rect2 = view._resource_draw_rect(node,rect,tile)
		var metrics: Dictionary = view._object_sprite_visual_metrics(resource_rect,profile)
		var art := String(view._resource_asset_id(node))
		result.resources.append({"id":node.placement_id,"type":node.get("h3m_type_id",-1),"kind":node.get("kind",""),"semantic_category":node.get("semantic_category",""),"object_id":node.get("object_id",""),"site_id":node.site_id,"site_family":site.get("family",""),"profile_family":profile.get("family",""),"scale_class":view._semantic_visual_scale_class(profile),"extent_tiles":metrics.sprite_extent_tiles,"asset":art,"x":tile.x,"y":tile.y,"indexed_id":view._resource_node_at(tile).get("placement_id",""),"visit_tiles":node.get("package_visit_tiles",[]),"block_tiles":node.get("package_block_tiles",[])})
		check(art!="" and view._object_texture_for_asset(art) is Texture2D,"resource raster "+String(node.placement_id))
	for node in session.overworld.artifact_nodes:
		var tile := Vector2i(int(node.x),int(node.y))
		var art := String(view._artifact_sprite_asset_id(node))
		check(art!="" and view._object_texture_for_asset(art) is Texture2D,"artifact raster "+String(node.placement_id))
		result.artifacts.append({"id":node.placement_id,"artifact_id":node.artifact_id,"asset":art,"x":tile.x,"y":tile.y,"indexed_id":view._artifact_node_at(tile).get("placement_id",""),"visit_tiles":node.get("package_visit_tiles",[])})
	for node in session.overworld.encounters:
		var tile := Vector2i(int(node.x),int(node.y))
		var art := String(view._encounter_identity_asset_id(node))
		result.encounters.append({"id":node.placement_id,"type":node.get("h3m_type_id",-1),"asset":art,"x":tile.x,"y":tile.y,"indexed_id":view._encounter_node_at(tile).get("placement_id",""),"army":node.get("enemy_army",{}),"target":node.get("target_placement_id",""),"presentation":view.validation_encounter_presentation_payload(node)})
	return result

func run() -> void:
	out=OS.get_environment("BATTLE_READABILITY_OUT")
	SettingsService.set_presentation_mode("windowed")
	var resolution := OS.get_environment("TOWN_OVERLAY_RESOLUTION")
	SettingsService.set_presentation_resolution(resolution)
	var parts := resolution.split("x")
	get_window().size=Vector2i(int(parts[0]),int(parts[1]))
	var service=ClassDB.instantiate("MapPackageService")
	var configs := [["medium","10","weak"],["medium","10","normal"],["large","11","normal"]]
	for index in range(configs.size()):
		var row: Array=configs[index]
		var label := "%s-%s-%s" % [row[0],row[1],row[2]]
		print("QUALITY_START "+label)
		var config := Select.build_random_map_player_config(row[1],"","",2,"land",false,"homm3_"+row[0],Select.RANDOM_MAP_TEMPLATE_SELECTION_MODE_CATALOG_AUTO,"faction_embercourt","")
		config.monster_strength=row[2]
		var generated: Dictionary=service.generate_random_map(config)
		check(bool(generated.get("ok",false)),label+": generation")
		if not generated.get("ok",false):continue
		var adoption: Dictionary=service.convert_generated_payload(generated,{"feature_gate":"overworld_quality","session_save_version":Store.SAVE_VERSION})
		check(bool(adoption.get("ok",false)),label+": adoption")
		if not adoption.get("ok",false):continue
		var session=persisted(service,adoption,generated,config,index)
		check(session!=null and session.scenario_id!="",label+": startup")
		if session==null or session.scenario_id=="":continue
		verify(session,adoption,label)
		var battles := encounter_entry(session,label)
		SessionState.set_active_session(session)
		var shell=load("res://scenes/overworld/OverworldShell.tscn").instantiate()
		add_child(shell)
		for frame in range(8):await get_tree().process_frame
		var view=shell.get_node("%Map")
		var guarded := guarded_presence(session,view,label)
		var pickups := portable_resources(session,view,label)
		presentation_contracts(view,session,label)
		var repeated=Bridge.build_session_from_adoption(adoption)
		for key in ["map_objects","resource_nodes","artifact_nodes","encounters"]:
			check(normalized(session.overworld[key])==normalized(repeated.overworld[key]),label+": nondeterministic adoption "+key)
		await capture(view,label+"-start",OverworldRules.hero_position(session))
		var inventory := presence(view,session)
		write_json(label+"-presence.json",inventory)
		write_json(label+"-authority.json",{"native_payload_hash":generated.get("final_payload_fnv1a32",""),"native_payload_bytes":generated.get("final_payload_byte_count",0),"source_objects":Bridge._document_objects(adoption.map_document),"spatial":spatial(session),"hero":session.overworld.hero_position,"towns":session.overworld.towns})
		var size := OverworldRules.derive_map_size(session)
		var tiles := []
		for y in range(size.y):
			var line := []
			for x in range(size.x):line.append(true)
			tiles.append(line)
		session.overworld.fog={"explored_tiles":tiles,"visible_tiles":tiles.duplicate(true),"explored_count":size.x*size.y,"visible_count":size.x*size.y,"total_tiles":size.x*size.y}
		view.set_map_state(session,session.overworld.map,size,OverworldRules.hero_position(session))
		await capture(view,label+"-inspection",Vector2i(18,12) if row[0]=="medium" else Vector2i(52,21))
		cases.append({"id":label,"resources":inventory.resources.size(),"artifacts":inventory.artifacts.size(),"encounters":inventory.encounters.size(),"guarded":guarded,"battles":battles,"pickups":pickups})
		shell.queue_free()
		for frame in range(4):await get_tree().process_frame
		print("QUALITY_COMPLETE "+label)
	print("BATTLE_READABILITY_REPORT "+JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases}))
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
