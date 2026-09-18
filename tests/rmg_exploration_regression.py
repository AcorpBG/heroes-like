#!/usr/bin/env python3
"""Source bodies, guarded routes and artifact translation through real packages."""
import json
import os
from pathlib import Path
import sys

import battle_readability_regression as runner
import rmg_town_supply_removal_regression as boundary

ROOT = runner.ROOT
sys.path.insert(0, str(ROOT / 'tools'))
import rmg_guard_space_audit as audit

OUTPUT = ROOT / '.artifacts/rmg-exploration-20260918'
run_probe = runner.run_probe
probe_environment = runner.probe_environment
COMPILED_OWNERS = boundary.COMPILED_OWNERS + (
    'scripts/persistence/NativeSceneryRules.gdc',
    'scripts/core/ScenarioSelectRules.gdc',
    'scenes/overworld/OverworldMapView.gdc',
)
# Reuse isolated real-disk startup and the audit's read-only spatial capture.
SCRIPT = audit.SCRIPT.split('func reproduce_bypass(')[0] + r'''
func corrected_bypass(session, label: String) -> void:
	var paths := {
		"medium-10-weak":[[9,58],[8,59],[9,60]],
		"large-11-weak":[[48,23],[47,22],[46,21],[47,20],[48,19],[49,18],[50,18],[51,18],[52,19],[53,20],[52,21],[52,22],[51,23]],
		"large-1-weak":[[30,37],[30,38],[30,39]],
	}
	if not paths.has(label): return
	var clone = Store.new_session_data()
	clone.from_dict(session.to_dict().duplicate(true))
	var path := []
	for tile in paths[label]:path.append(Vector2i(tile[0],tile[1]))
	OverworldRules._set_active_hero_position(clone,path[0],0)
	check(path.any(func(tile): return OverworldRules.tile_is_blocked(clone,tile.x,tile.y,0)),label+": source-body bypass remains open")
	var moved: Dictionary = OverworldRules.try_move_along_route(clone,path)
	check(not bool(moved.get("ok",false)),label+": production route still skirts guard through lost scenery")
	check(OverworldRules.hero_position(clone)==path[0],label+": rejected route moved hero")

func verify_exploration(session, adoption: Dictionary, label: String) -> Dictionary:
	var sources: Array = Bridge._document_objects(adoption.map_document)
	var live := {}
	for bucket in ["towns","encounters","map_objects","resource_nodes","artifact_nodes"]:
		for object in session.overworld.get(bucket,[]):live[String(object.placement_id)]=object
	var scenery_count := 0
	var source_artifacts := 0
	var artifact_ids := {}
	var artifact_anchors := 0
	var artifact_anchor_mismatches := 0
	var banks := 0
	var rarity_bands: Dictionary = ContentService.load_json("res://content/random_map_object_eligibility.json").artifact_rarities_by_source_type
	for source in sources:
		check(live.has(String(source.placement_id)),label+": dropped source "+String(source.placement_id))
		if Bridge.NativeScenery.is_scenery(source):
			scenery_count+=1
			if not live.has(String(source.placement_id)):continue
			var object: Dictionary = live[String(source.placement_id)]
			check(object.get("runtime_object_role","")=="decorative_blocker_sprite",label+": invisible scenery role")
			check(normalized(object.get("package_block_tiles"))==normalized(source.package_block_tiles),label+": scenery masks changed")
			for tile in source.package_block_tiles:
				check(OverworldRules.tile_is_blocked(session,int(tile.x),int(tile.y),int(tile.get("level",0))),label+": source body lost collision")
		if String(source.get("artifact_id",""))!="":
			source_artifacts+=1
			artifact_ids[String(source.artifact_id)]=true
			var rarity := String(rarity_bands.get(str(int(source.h3m_type_id)),""))
			if rarity!="":
				check(ContentService.get_artifact(source.artifact_id).rarity==rarity,label+": random artifact class lost rarity")
				check(source.native_authored_pool_selection_mode=="stable_source_ordinal_pool_index",label+": random artifact still fixed catalog item")
			for tile in source.package_visit_tiles:
				artifact_anchors+=1
				if int(tile.x)!=int(source.x) or int(tile.y)!=int(source.y):artifact_anchor_mismatches+=1
		if int(source.h3m_type_id)==16:
			banks+=1
			check(String(source.get("artifact_id",""))=="" and source.kind=="resource_site",label+": guarded bank translated into a free artifact")
			var linked: Array = session.overworld.encounters.filter(func(g):return String(g.get("target_placement_id",""))==String(source.placement_id))
			check(not linked.is_empty(),label+": guarded bank lost defenders")
	check(source_artifacts==session.overworld.artifact_nodes.size(),label+": artifact adoption count changed")
	corrected_bypass(session,label)
	var guard_rows := []
	var Neutral = preload("res://scripts/persistence/GeneratedNeutralEncounterRules.gd")
	for guard in session.overworld.encounters:
		if not guard.has("native_guard_quantity"):continue
		var headcount := 0
		for stack in guard.enemy_army.stacks:headcount+=int(stack.count)
		check(headcount==int(guard.native_guard_quantity),label+": source guard headcount changed")
		guard_rows.append({"id":guard.placement_id,"quantity":headcount,"source_level":guard.native_guard_level,"source_ai_value":guard.native_guard_ai_value,"army_strength":Neutral._army_strength(guard.enemy_army)})
	return {"scenery_records":scenery_count,"artifacts":source_artifacts,"distinct_artifacts":artifact_ids.size(),"artifact_visit_tiles":artifact_anchors,"artifact_anchor_mismatches":artifact_anchor_mismatches,"guarded_banks":banks,"guards":guard_rows,"starting_army_strength":Neutral._army_strength(session.overworld.army)}

func legacy_topology(session) -> void:
	var clone = Store.new_session_data()
	clone.from_dict(session.to_dict().duplicate(true))
	# Model a pre-correction save with omitted body families. Loading it must
	# preserve that established topology, not trap a hero in newly added walls.
	clone.overworld.map_objects=clone.overworld.map_objects.filter(func(row):return not int(row.get("h3m_type_id",-1)) in [116,121,126,127,128,130,131,132,133,151,153,158,206,208,209,211])
	for object in clone.overworld.map_objects:object.erase("native_scenery_art_version")
	OverworldRules.normalize_overworld_state(clone)
	var before: Array = normalized(clone.overworld.map_objects)
	check(SaveService.save_session(clone.to_dict(),1)!="","legacy topology save")
	var restored=SaveService.restore_manual_session(1)
	check(restored!=null,"legacy topology restore")
	if restored!=null:check(normalized(restored.overworld.map_objects)==before,"old save scenery was silently repopulated")

func exercise_rewards(session, label: String) -> void:
	var Artifacts = preload("res://scripts/core/ArtifactRules.gd")
	var Battle = preload("res://scripts/core/BattleRules.gd")
	var clone=Store.new_session_data()
	clone.from_dict(session.to_dict().duplicate(true))
	var collected := false
	for node in clone.overworld.artifact_nodes:
		var tile := Vector2i(int(node.x),int(node.y))
		if OverworldRules.tile_is_blocked(clone,tile.x,tile.y) or not OverworldRules.guard_engagement_encounter_at_tile(clone,tile.x,tile.y).is_empty():continue
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var start: Vector2i = tile+offset
			if OverworldRules.tile_is_blocked(clone,start.x,start.y) or OverworldRules.tile_has_route_interaction(clone,start.x,start.y):continue
			OverworldRules._set_active_hero_position(clone,start,0)
			var moved: Dictionary = OverworldRules.try_move_along_route(clone,[start,tile])
			check(bool(moved.get("ok",false)),label+": reachable artifact move failed")
			check(Artifacts.has_artifact(clone.overworld.hero,String(node.artifact_id)),label+": move did not grant actual artifact")
			check(not bool(OverworldRules.collect_active_artifact(clone).get("ok",false)),label+": artifact claimed twice")
			collected=true
			break
		if collected:break
	check(collected,label+": no real artifact pickup exercised")
	var tested_bank := false
	for index in range(session.overworld.resource_nodes.size()):
		var node: Dictionary = session.overworld.resource_nodes[index]
		if int(node.get("h3m_type_id",-1))!=16:continue
		clone=Store.new_session_data()
		clone.from_dict(session.to_dict().duplicate(true))
		var site := ContentService.get_resource_site(String(node.site_id))
		var visit: Dictionary = node.get("visit_tile",node)
		OverworldRules._set_active_hero_position(clone,Vector2i(int(visit.x),int(visit.y)),int(visit.get("level",0)))
		var guard := OverworldRules.resource_site_blocking_guard(clone,node,site)
		check(not guard.is_empty(),label+": no actual bank defender")
		var blocked: Dictionary = OverworldRules._collect_resource_node_result(clone,{"index":index,"node":clone.overworld.resource_nodes[index]})
		check(not bool(blocked.get("ok",false)),label+": bank loot granted before battle")
		var battle: Dictionary = Battle.create_battle_payload(clone,guard)
		check(not battle.get("stacks",[]).filter(func(stack):return stack.side=="enemy").is_empty(),label+": bank defender has no battle army")
		# Isolated post-victory boundary fixture, not an auto-won played battle.
		clone.overworld.resolved_encounters.append(String(guard.placement_id))
		OverworldRules.normalize_overworld_state(clone)
		check(OverworldRules.resource_site_blocking_guard(clone,node,site).is_empty(),label+": defeated bank guard still blocks loot")
		var claim: Dictionary = OverworldRules._collect_resource_node_result(clone,{"index":index,"node":clone.overworld.resource_nodes[index]})
		check(bool(claim.get("ok",false)),label+": cleared bank reward unusable "+String(claim.get("message","")))
		save_roundtrip(clone,label+"-reward")
		var restored=SaveService.restore_manual_session(1)
		if restored!=null:
			check(Artifacts.owned_artifact_ids(restored.overworld.hero)==Artifacts.owned_artifact_ids(clone.overworld.hero),label+": saved reward inventory drift")
		if restored!=null and normalized(restored.overworld.resource_nodes)!=normalized(clone.overworld.resource_nodes):
			var diffs := []
			for i in range(clone.overworld.resource_nodes.size()):
				var before: Dictionary = normalized(clone.overworld.resource_nodes[i])
				var after: Dictionary = normalized(restored.overworld.resource_nodes[i])
				if before==after:continue
				var keys := {}
				for key in before.keys()+after.keys():
					if before.get(key)!=after.get(key):keys[key]={"before":before.get(key),"after":after.get(key)}
				diffs.append({"id":before.placement_id,"diffs":keys})
			print("REWARD_SAVE_DIFFERENCES "+JSON.stringify(diffs))
		tested_bank=true
		break
	check(tested_bank,label+": no bank reward boundary exercised")

func run() -> void:
	out=OS.get_environment("BATTLE_READABILITY_OUT")
	SettingsService.set_presentation_mode("windowed")
	var resolution := OS.get_environment("TOWN_OVERLAY_RESOLUTION")
	SettingsService.set_presentation_resolution(resolution)
	var parts := resolution.split("x")
	get_window().size=Vector2i(int(parts[0]),int(parts[1]))
	var service=ClassDB.instantiate("MapPackageService")
	check(not Bridge.NativeScenery.validate([{"h3m_type_id":999,"kind":"h3m_object","package_visit_tiles":[]}]).ok,"unknown nonvisitable body silently accepted")
	var configs := [["medium","10","weak"],["large","11","weak"],["large","1","weak"],["medium","10","normal"],["large","11","normal"]]
	for index in range(configs.size()):
		var row: Array = configs[index]
		var label := "%s-%s-%s" % [row[0],row[1],row[2]]
		print("EXPLORATION_START "+label)
		var config := Select.build_random_map_player_config(row[1],"","",2,"land",false,"homm3_"+row[0],Select.RANDOM_MAP_TEMPLATE_SELECTION_MODE_CATALOG_AUTO,"faction_embercourt","")
		check(config.get("monster_strength","")=="normal",label+": default menu still secretly weak")
		config["monster_strength"]=row[2]
		var generated: Dictionary = service.generate_random_map(config)
		check(bool(generated.get("ok",false)),label+": generation failed "+String(generated.get("error_code","")))
		if not generated.get("ok",false):continue
		check(generated.normalized_config.monster_strength==row[2],label+": strength setting dropped")
		var replay := Select._random_map_replay_metadata({"input_config":config},{},{})
		check(replay.generator_config==config,label+": native replay lost explicit generator options")
		var adoption: Dictionary = service.convert_generated_payload(generated,{"feature_gate":"exploration_correction","session_save_version":Store.SAVE_VERSION})
		check(bool(adoption.get("ok",false)),label+": conversion failed")
		if not adoption.get("ok",false):continue
		var session=persisted(service,adoption,generated,config,index)
		check(session!=null and session.scenario_id!="",label+": disk startup failed")
		if session==null or session.scenario_id=="":continue
		verify(session,adoption,label)
		var repeated=Bridge.build_session_from_adoption(adoption)
		for key in ["map_objects","resource_nodes","artifact_nodes","encounters"]:
			check(normalized(session.overworld[key])==normalized(repeated.overworld[key]),label+": nondeterministic adoption "+key)
		var metrics := verify_exploration(session,adoption,label)
		exercise_rewards(session,label)
		save_roundtrip(session,label)
		if index==0:legacy_topology(session)
		var grid := spatial(session)
		write_json(label+"-state.json",{"config":config,"normalized_config":generated.normalized_config,"native_payload_hash":generated.get("final_payload_fnv1a32",""),"native_payload_bytes":generated.get("final_payload_byte_count",0),"native_objects":Bridge._document_objects(adoption.map_document),"overworld":session.to_dict().overworld,"grid":grid,"metrics":metrics})
		SessionState.set_active_session(session)
		var shell=load("res://scenes/overworld/OverworldShell.tscn").instantiate()
		add_child(shell)
		for frame in range(8):await get_tree().process_frame
		var view=shell.get_node("%Map")
		await capture(view,label+"-start",OverworldRules.hero_position(session))
		var size := OverworldRules.derive_map_size(session)
		var tiles := []
		for y in range(size.y):
			var line := []
			for x in range(size.x):line.append(true)
			tiles.append(line)
		session.overworld.fog={"explored_tiles":tiles,"visible_tiles":tiles.duplicate(true),"explored_count":size.x*size.y,"visible_count":size.x*size.y,"total_tiles":size.x*size.y}
		view.set_map_state(session,session.overworld.map,size,OverworldRules.hero_position(session))
		var inspection := Vector2i(8,59) if row[0]=="medium" else (Vector2i(52,21) if row[1]=="11" else Vector2i(30,38))
		await capture(view,label+"-scenery-and-routes",inspection)
		var scenery: Dictionary = view.validation_generated_object_visual_summary()
		for key in ["all_source_scenery_adopted","body_tile_keys_exact","all_body_assets_loaded","all_body_cells_visually_covered","all_body_assets_terrain_matched"]:check(bool(scenery.get(key,false)),label+": visual coverage "+key)
		write_json(label+"-scenery.json",scenery)
		for key in ["body_entries","resource_entries","legacy_primary_marker_candidates"]:scenery.erase(key)
		cases.append({"case":label,"metrics":metrics,"scenery":scenery})
		shell.queue_free()
		for frame in range(4):await get_tree().process_frame
		print("EXPLORATION_COMPLETE "+label)
	check(cases.size()==configs.size(),"not all exploration cases completed")
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
