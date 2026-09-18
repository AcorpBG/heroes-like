#!/usr/bin/env python3
"""Real generated guard-center selection, legal approach, battle and saved identity."""
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
COMPILED_OWNERS = boundary.COMPILED_OWNERS + ('scenes/overworld/OverworldShell.gdc',)
SCRIPT = boundary.SCRIPT.split('func run() -> void:')[0] + r'''
func clone(source):
	var result=Store.new_session_data()
	result.from_dict(source.to_dict().duplicate(true))
	return result
func settle() -> void:
	for frame in range(12):await get_tree().process_frame
func screenshot(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(out.path_join(name+".png"))==OK,"screenshot "+name)
func pointer(shell, tile: Vector2i) -> void:
	var map=shell.get_node("%Map")
	map.focus_on_tile(tile)
	await settle()
	var center: Vector2=map._tile_rect(map._board_rect(),tile).get_center()
	check(map._tile_from_local(center)==tile,"pointer projection changed")
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		event.position=center
		map._gui_input(event)
	await settle()
func guard_routes(session, label: String) -> Dictionary:
	var shell=load("res://scenes/overworld/OverworldShell.gd").new()
	shell._session=session
	shell._map_size=OverworldRules.derive_map_size(session)
	var before: Dictionary=normalized(session.to_dict())
	var routes:=[]
	var reachable:=0
	var committed:=0
	var maximum_usec:=0
	var known:=0
	var hidden:=0
	for guard in session.overworld.encounters:
		var started:=Time.get_ticks_usec()
		var path:=OverworldRules.guard_engagement_approach_route(session,guard)
		maximum_usec=maxi(maximum_usec,Time.get_ticks_usec()-started)
		var anchor:=Vector2i(int(guard.x),int(guard.y))
		if not OverworldRules.is_tile_explored(session,anchor.x,anchor.y):
			hidden+=1
			check(shell._selection_route_tile(anchor)==anchor,label+": hidden guard retarget leaks information")
		elif not path.is_empty():
			known+=1
			check(shell._selection_route_tile(anchor)==path[-1],label+": painted center not mapped to legal combat entry")
		if path.is_empty():continue
		reachable+=1
		check(path[0]==OverworldRules.hero_position(session),label+": approach starts away from hero")
		var entry: Vector2i=path[-1]
		check(OverworldRules.encounter_key(OverworldRules.guard_engagement_encounter_at_tile(session,entry.x,entry.y))==OverworldRules.encounter_key(guard),label+": another guard owns chosen entry")
		var ordinary: Array=shell._build_path(path[0],entry)
		check(not ordinary.is_empty() and ordinary.size()==path.size(),label+": approach differs from production path policy")
		for step in range(1,path.size()-1):
			check(not OverworldRules.tile_has_route_interaction(session,path[step].x,path[step].y),label+": route bypasses a terminal interaction")
		var full=clone(session)
		var cached=clone(session)
		var result:=OverworldRules.try_move_along_route(full,path)
		var descriptor: Dictionary=shell._selected_route_destination_execution_descriptor(entry)
		var fast:=OverworldRules.execute_prevalidated_route(cached,path,{},-1,descriptor)
		check(bool(result.get("ok",false)) and bool(fast.get("ok",false)),label+": legal guard route rejected "+String(guard.placement_id)+" full="+String(result.get("message",""))+" cached="+String(fast.get("message","")))
		check(normalized(full.to_dict())==normalized(cached.to_dict()),label+": cached/full guard commit disagree")
		var can_finish:=path.size()-1<=int(session.overworld.movement.current)
		if can_finish:
			committed+=1
			check(result.get("route","")=="battle" and full.battle.get("resolved_key","")==OverworldRules.encounter_key(guard),label+": wrong/missing battle after legal route")
			var node:=OverworldRules.resource_node_interaction_at_tile(session,entry.x,entry.y)
			if not node.is_empty():
				check(descriptor.kind=="encounter",label+": guarded-site descriptor tries collecting first")
				var legacy=clone(session)
				var legacy_result:=OverworldRules.execute_prevalidated_route(legacy,path,{},-1,{"kind":"resource","placement_id":node.placement_id,"level":OverworldRules.hero_level(session)})
				check(legacy_result.get("route","")=="battle" and normalized(legacy.to_dict())==normalized(full.to_dict()),label+": resource descriptor bypasses/strands defender")
				# Detached legacy-shape control, not a generated-map playthrough.
				var unplaced=clone(session)
				var saved_guard: Dictionary=guard.duplicate(true)
				saved_guard.erase("placement_id")
				unplaced.overworld.encounters=[saved_guard]
				OverworldRules._set_active_hero_position(unplaced,entry)
				OverworldRules.refresh_fog_of_war(unplaced)
				OverworldRules.invalidate_spatial_lookup(unplaced)
				var old_result:=OverworldRules._resolve_destination_descriptor_interaction(unplaced,{"kind":"resource","placement_id":node.placement_id})
				check(old_result.get("route","")=="battle" and unplaced.battle.get("resolved_key","")==OverworldRules.encounter_key(saved_guard),label+": legacy guard without placement identity lost battle")
				OverworldRules.invalidate_spatial_lookup(session)
		else:check(full.battle.is_empty(),label+": partial route attacks remotely")
		routes.append({"id":guard.placement_id,"anchor":str(anchor),"entry":str(entry),"steps":path.size()-1,"battle_key":full.battle.get("resolved_key","")})
	check(reachable>0 and committed>0,label+": no genuine start-to-guard battle exercised")
	check(hidden>0,label+": no hidden-guard control")
	check(normalized(session.to_dict())==before,label+": route selection changed authoritative session")
	# Separate negative fixtures: no change to the generated sessions above.
	var target: Dictionary=session.overworld.encounters[0]
	var resolved=clone(session)
	resolved.overworld.resolved_encounters.append(OverworldRules.encounter_key(target))
	OverworldRules.normalize_overworld_state(resolved)
	check(OverworldRules.guard_engagement_approach_route(resolved,target).is_empty(),label+": resolved army remains targetable")
	var other_level: Dictionary=target.duplicate(true)
	other_level.level=OverworldRules.hero_level(session)+1
	check(OverworldRules.guard_engagement_approach_route(session,other_level).is_empty(),label+": approach crosses map levels")
	shell.free()
	return {"id":label,"guards":session.overworld.encounters.size(),"direct_reachable_guards":reachable,"actual_battles":committed,"known":known,"hidden":hidden,"max_search_ms":maximum_usec/1000.0,"routes":routes}
func live_input(original, mode: String, guard: Dictionary={}) -> void:
	var session=SessionState.set_active_session(clone(original))
	AppRouter.go_to_overworld()
	await settle()
	var shell=get_tree().current_scene
	check(shell!=null and shell._session==session,mode+": not observing active overworld")
	# Shell startup can legitimately normalize the current view/hero state.
	var before: Dictionary=normalized(session.to_dict())
	var anchor:=Vector2i(24,26)
	var entry:=Vector2i(25,25)
	var identity:="native_h3maped_bc036d7a_object_0269"
	var steps:=1
	if not guard.is_empty():
		var path:=OverworldRules.guard_engagement_approach_route(session,guard)
		check(not path.is_empty(),mode+": site guard lacks legal approach")
		if path.is_empty():return
		anchor=Vector2i(int(guard.x),int(guard.y))
		entry=path[-1]
		steps=path.size()-1
		identity=OverworldRules.encounter_key(guard)
		check(OverworldRules.is_tile_explored(session,anchor.x,anchor.y),mode+": fixture requires normal-fog visible target")
	if mode=="controller":
		# Keep the existing free tile cursor: it must not snap across town art.
		shell._select_hero_tile()
		shell._move_controller_route_cursor(Vector2i.LEFT,false)
		shell._move_controller_route_cursor(Vector2i.DOWN,false)
	else:await pointer(shell,anchor)
	check(shell._selected_tile==entry,mode+": wrong selection")
	check(normalized(session.to_dict())==before,mode+": preview mutates gameplay")
	check(not shell._current_primary_action().is_empty() and not shell._current_primary_action().get("disabled",false),mode+": legal guard order disabled")
	await screenshot(mode+"-guard-selected")
	if mode.begins_with("pointer"):await pointer(shell,anchor)
	elif mode=="controller":
		var accept:=InputEventAction.new()
		accept.action="ui_accept"
		accept.pressed=true
		check(shell._handle_controller_route_action_input(accept),"controller accept not handled")
	else:
		# The selected primary button is the shared keyboard Enter/Space action.
		check(shell._activate_primary_action(),"keyboard primary action rejected")
	for frame in range(120):
		await get_tree().process_frame
		if session.game_state=="battle" and get_tree().current_scene!=shell:break
	check(session.game_state=="battle" and session.battle.get("resolved_key","")==identity,mode+": selected monster did not enter its exact battle")
	check(OverworldRules.hero_position(session)==entry,mode+": hero did not walk to real combat entry")
	check(int(session.overworld.movement.current)==int(before.overworld.movement.current)-steps,mode+": wrong movement cost")
	check(normalized(session.overworld.army)==before.overworld.army,mode+": test/targeting changed army")
	check(normalized(session.overworld.encounters)==before.overworld.encounters,mode+": source armies/coordinates/masks changed")
	check(normalized(session.overworld.resource_nodes)==before.overworld.resource_nodes,mode+": guarded reward changed before victory")
	await settle()
	await screenshot(mode+"-actual-battle")
	save_roundtrip(session,mode+"-battle")
	var restored=SaveService.restore_manual_session(1)
	if restored!=null:
		check(restored.game_state=="battle" and normalized(restored.battle)==normalized(session.battle),mode+": saved battle identity/state changed")
	cases.append({"input":mode,"battle_key":session.battle.get("resolved_key",""),"position":session.overworld.hero_position,"movement":session.overworld.movement})
func run() -> void:
	get_tree().current_scene=null
	out=OS.get_environment("BATTLE_READABILITY_OUT")
	SettingsService.set_presentation_mode("windowed")
	var resolution:=OS.get_environment("TOWN_OVERLAY_RESOLUTION")
	SettingsService.set_presentation_resolution(resolution)
	var parts:=resolution.split("x")
	get_window().size=Vector2i(int(parts[0]),int(parts[1]))
	var defaults:=Select.random_map_size_class_default("homm3_small")
	var config:=Select.build_random_map_player_config("generated-density-distribution-10184-homm3_small",defaults.template_id,defaults.profile_id,int(defaults.player_count),"land",false,"homm3_small")
	var setup:=Select.build_random_map_skirmish_setup_with_retry(config,"normal",Select.RANDOM_MAP_PLAYER_RETRY_POLICY)
	check(bool(setup.get("ok",false)),"original Small generation failed")
	if not setup.get("ok",false):finish();return
	var small=Select.start_random_map_skirmish_session_from_setup(setup)
	OverworldRules.normalize_overworld_state(small)
	check(OverworldRules.hero_position(small)==Vector2i(26,24),"original Small case changed")
	cases.append(guard_routes(small,"small-historical-weak"))
	var service=ClassDB.instantiate("MapPackageService")
	var large=null
	for row in [["medium","10"],["large","11"]]:
		config=Select.build_random_map_player_config(row[1],"","",2,"land",false,"homm3_"+row[0],Select.RANDOM_MAP_TEMPLATE_SELECTION_MODE_CATALOG_AUTO,"faction_embercourt","")
		config.monster_strength="normal"
		var generated: Dictionary=service.generate_random_map(config)
		check(bool(generated.get("ok",false)),row[0]+": generation")
		if not generated.get("ok",false):continue
		var adoption: Dictionary=service.convert_generated_payload(generated,{"feature_gate":"guard_approach","session_save_version":Store.SAVE_VERSION})
		check(bool(adoption.get("ok",false)),row[0]+": adoption")
		if not adoption.get("ok",false):continue
		var session=persisted(service,adoption,generated,config,1 if row[0]=="medium" else 2)
		verify(session,adoption,row[0])
		cases.append(guard_routes(session,row[0]+"-"+row[1]+"-normal"))
		if row[0]=="large":large=session
	for mode in ["pointer","keyboard","controller"]:await live_input(small,mode)
	if large!=null:
		var guards: Array=large.overworld.encounters.filter(func(guard):return guard.placement_id=="generated_guarded_reward_native_h3maped_c6ffff4f_object_2112")
		check(guards.size()==1,"Large guarded-site fixture changed")
		if guards.size()==1:await live_input(large,"pointer-guarded-site",guards[0])
	check(cases.size()==7,"incomplete case/input coverage")
	finish()
func finish() -> void:
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
