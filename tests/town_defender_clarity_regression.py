#!/usr/bin/env python3
"""Compare town defense presentation with battle setup and real warning routing."""
import battle_readability_regression as base

OUTPUT = base.ROOT / '.artifacts/town_defender_clarity_20260912'
SCRIPT = base.SCRIPT.split('func _ready()')[0] + r'''
func _ready()->void:
	call_deferred("run_defenders")
func run_defenders()->void:
	out=OS.get_environment("BATTLE_READABILITY_OUT")
	# Release probes use isolated user:// map storage, never the owner's maps.
	if not OS.has_feature("editor"):
		var setup_rules=preload("res://scripts/core/ScenarioSelectRules.gd")
		var config:=setup_rules.build_random_map_player_config("10","","",2,"land",false,"homm3_small",setup_rules.RANDOM_MAP_TEMPLATE_SELECTION_MODE_SIZE_DEFAULT,"faction_embercourt","")
		var generated_setup:=setup_rules.build_random_map_skirmish_setup_with_retry(config,"normal",setup_rules.RANDOM_MAP_PLAYER_RETRY_POLICY)
		check(bool(generated_setup.get("ok",false)),"native Small setup failed")
		if not bool(generated_setup.get("ok",false)):
			print("BATTLE_READABILITY_REPORT "+JSON.stringify({"ok":false,"checks":checks,"failures":failures}))
			get_tree().quit(1)
			return
		var generated=setup_rules.start_random_map_skirmish_session_from_setup(generated_setup)
		var home:Dictionary={}
		for row in generated.overworld.towns:
			if row.owner=="player":home=row;break
		var native_force:=HeroCommandRules.town_defense_force(generated,home)
		check(not native_force.hero.is_empty(),"generated starting hero not eligible at home entrance")
		check(int(native_force.hero_troops)>0,"generated visiting army missing")
		var raid:Dictionary=generated.overworld.encounters[0]
		raid.battle_context={"type":"town_defense","town_placement_id":home.placement_id}
		var native_battle:=BattleRules.create_battle_payload(generated,raid)
		var actual:=0
		for stack in native_battle.get("stacks",[]):
			if stack.side=="player":actual+=BattleRules._alive_count(stack)
		check(actual==int(native_force.troops),"native Small assault differs from displayed defense")
	var session=ScenarioFactory.create_session("river-pass","normal",SessionState.LAUNCH_MODE_SKIRMISH)
	session.overworld.map_size.level_count=2
	var town:Dictionary={}
	for candidate in session.overworld.towns:
		if candidate.owner=="player": town=candidate;break
	check(not town.is_empty(),"fixture has no owned town")
	var hero:Dictionary=session.overworld.player_heroes[0]
	var original_hero:Dictionary=hero.duplicate(true)
	var unit_id:String=hero.army.stacks[0].unit_id
	var entrance:Dictionary=preload("res://scripts/core/OverworldLevelRules.gd").town_entrance(town)
	for mode in ["empty","garrison","visiting","remote","wrong_level","entrance","multiple"]:
		town.erase("visit_tile")
		town.erase("level")
		town.garrison=[]
		hero.position={"x":int(entrance.x)+3,"y":int(entrance.y)+2}
		hero.army={"stacks":[{"unit_id":unit_id,"count":13}]}
		session.overworld.player_heroes=[hero]
		var expected:=0
		if mode!="empty": town.garrison=[{"unit_id":unit_id,"count":7}];expected=7
		if mode in ["visiting","wrong_level","multiple"]: hero.position=entrance.duplicate(true)
		if mode=="wrong_level": hero.position.level=1
		if mode=="entrance":
			town.visit_tile={"x":int(town.x)+1,"y":int(town.y)+1,"level":1}
			town.level=1
			hero.position=town.visit_tile.duplicate(true)
		if mode in ["visiting","entrance","multiple"]: expected+=13
		if mode=="multiple":
			var reserve:Dictionary=hero.duplicate(true)
			reserve.id="test_reserve"
			reserve.is_primary=false
			reserve.army.stacks[0].count=99
			session.overworld.player_heroes.append(reserve)
		HeroCommandRules._sync_active_hero_mirror(session)
		var before:Dictionary=session.to_dict().duplicate(true)
		var force:=HeroCommandRules.town_defense_force(session,town)
		check(int(force.troops)==expected,mode+": incorrect troop count")
		var context:Dictionary={"type":"town_defense","town_placement_id":town.placement_id}
		var setup:=BattleRules._player_setup_for_battle(session,{},context)
		check(setup.stacks==force.stacks,mode+": UI force differs from battle setup")
		check(session.to_dict()==before,mode+": defense inspection mutates state")
		check(HeroCommandRules.empty_owned_towns(session).any(func(t):return t.placement_id==town.placement_id)==(expected==0),mode+": empty warning mismatches troops")
		if mode=="multiple":
			check(int(HeroCommandRules.town_defense_force(session,town,"test_reserve").troops)==106,"preferred stationed defender ignored")
		var restored=Store.new_session_data()
		restored.from_dict(before)
		var restored_town:Dictionary={}
		for row in restored.overworld.towns:
			if row.placement_id==town.placement_id: restored_town=row;break
		check(int(HeroCommandRules.town_defense_force(restored,restored_town).troops)==expected,mode+": save roundtrip changed defense")
		# Full battle creation, including normalization, must field the advertised army.
		var placement:Dictionary=restored.overworld.encounters[0]
		placement.battle_context=context
		var battle:=BattleRules.create_battle_payload(restored,placement)
		var actual:=0
		for stack in battle.get("stacks",[]):
			if stack.side=="player":actual+=BattleRules._alive_count(stack)
		check(actual==expected,mode+": full battle troop count differs")
	# Real transfer preserves the total defending force, then departure removes
	# only the visiting army. No remote management shortcut counts as presence.
	var transfer_session=ScenarioFactory.create_session("river-pass","normal",SessionState.LAUNCH_MODE_SKIRMISH)
	var transfer_town:Dictionary={}
	for candidate in transfer_session.overworld.towns:
		if candidate.owner=="player":transfer_town=candidate;break
	var transfer_hero:Dictionary=transfer_session.overworld.player_heroes[0]
	transfer_hero.position=preload("res://scripts/core/OverworldLevelRules.gd").town_entrance(transfer_town)
	transfer_town.garrison=[]
	HeroCommandRules._sync_active_hero_mirror(transfer_session)
	var prior_force:=HeroCommandRules.town_defense_force(transfer_session,transfer_town)
	var transfer_unit:String=transfer_hero.army.stacks[0].unit_id
	var transferred:=HeroCommandRules.transfer_town_stack(transfer_session,transfer_town,transfer_hero.id,HeroCommandRules.HOLDER_GARRISON,transfer_unit,"1")
	check(transferred.ok,"stationed transfer rejected")
	var after_force:=HeroCommandRules.town_defense_force(transfer_session,transfer_town)
	check(after_force.troops==prior_force.troops and after_force.garrison_troops==1,"transfer changed defending total or failed garrison count")
	transfer_session.overworld.player_heroes[0].position={"x":int(entrance.x)+3,"y":int(entrance.y)+2}
	HeroCommandRules._sync_active_hero_mirror(transfer_session)
	check(int(HeroCommandRules.town_defense_force(transfer_session,transfer_town).troops)==1,"departure retained remote hero troops")
	transfer_town.garrison=[]
	check(not HeroCommandRules.empty_owned_towns(transfer_session).is_empty(),"empty owned town omitted")
	transfer_town.owner="enemy"
	check(not HeroCommandRules.empty_owned_towns(transfer_session).any(func(t):return t.placement_id==transfer_town.placement_id),"lost town warned as owned")
	# Real UI uses ordinary scenario coordinates and an empty remotely managed town.
	session.overworld.map_size.level_count=1
	town.erase("visit_tile")
	town.erase("level")
	town.garrison=[]
	hero=original_hero
	hero.position={"x":int(entrance.x)+3,"y":int(entrance.y)+2}
	session.overworld.player_heroes=[hero]
	session.overworld.hero=hero
	session.overworld.army=hero.army
	session=SessionState.set_active_session(session)
	var holder=Node.new()
	get_tree().root.add_child(holder)
	get_tree().current_scene=holder
	get_tree().change_scene_to_file("res://scenes/overworld/OverworldShell.tscn")
	await get_tree().scene_changed
	for i in range(3): await get_tree().process_frame
	var dimensions=OS.get_environment("TOWN_OVERLAY_RESOLUTION").split("x")
	var requested:=Vector2i(int(dimensions[0]),int(dimensions[1]))
	if DisplayServer.get_name()!="headless": DisplayServer.window_set_size(requested)
	get_tree().root.size=requested
	get_tree().root.content_scale_size=requested
	var field=get_tree().current_scene
	var warning:Dictionary=field._current_end_turn_warning()
	check("empty_town_defense" in warning.reasons,"empty defense does not warn")
	check(field._end_turn_confirmation_copy(warning).text.contains("No defending troops"),"warning lacks actual defense explanation")
	var original_day:int=session.day
	field._on_end_turn_pressed()
	var signature:String=field._pending_end_turn_confirmation.session_payload_signature
	for live_town in session.overworld.towns:
		if live_town.placement_id==town.placement_id:live_town.garrison=[{"unit_id":unit_id,"count":1}]
	check(not field._stale_end_turn_request_fields(field._pending_end_turn_confirmation).is_empty(),"reinforcement failed to invalidate confirmation")
	check(not ("empty_town_defense" in field._current_end_turn_warning().reasons),"warning did not update after reinforcement")
	field._cancel_end_turn_confirmation()
	for live_town in session.overworld.towns:
		if live_town.placement_id==town.placement_id:live_town.garrison=[]
	check(session.day==original_day,"warning/cancel advanced the day")
	field._on_end_turn_pressed()
	check(field._empty_town_inspect_button.visible,"warning lacks inspect action")
	for i in range(3): await get_tree().process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out+"/empty-town-warning.png")
	field._on_end_turn_custom_action("inspect_empty_town")
	await get_tree().scene_changed
	for i in range(3): await get_tree().process_frame
	check(get_tree().current_scene.scene_file_path.ends_with("TownShell.tscn"),"inspect did not open Town")
	var description:=TownRules.describe_defense(SessionState.ensure_active_session())
	check(description.contains("Garrison: 0 troops / 0 stacks (empty)"),"empty garrison not explicit")
	check(not description.contains("- Defending commander"),"remote active hero implied defender")
	var stage=get_tree().current_scene._town_stage_view
	var plaques:Dictionary=stage.validation_status_plaques_summary()
	check(plaques.contained,"town status plaques clip the scenery bounds")
	check(plaques.plaques[0].title=="Defending troops" and plaques.plaques[0].value=="0 / 0 stacks","scene plaque still exposes readiness as troop count")
	check(plaques.plaques[1].title=="Garrison troops" and plaques.plaques[1].value=="Empty","scene garrison not explicitly empty")
	check(plaques.plaques[2].title=="Readiness" and plaques.plaques[2].value.contains("not troops"),"readiness not distinguished")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		var capture=get_viewport().get_texture().get_image()
		check(capture.get_size()==requested,"capture resolution mismatch")
		capture.save_png(out+"/empty-town.png")
	var town_shell=get_tree().current_scene
	var live_session=SessionState.ensure_active_session()
	var live_town:=TownRules.get_active_town(live_session)
	var visiting:Dictionary=live_session.overworld.player_heroes[0]
	visiting.position=preload("res://scripts/core/OverworldLevelRules.gd").town_entrance(live_town)
	HeroCommandRules._sync_active_hero_mirror(live_session)
	var moved:=HeroCommandRules.transfer_town_stack(live_session,live_town,visiting.id,HeroCommandRules.HOLDER_GARRISON,unit_id,"1")
	check(moved.ok,"live town reinforcement failed")
	town_shell._refresh()
	for i in range(3):await get_tree().process_frame
	var reinforced:Dictionary=stage.validation_status_plaques_summary()
	var live_force:=HeroCommandRules.town_defense_force(live_session,TownRules.get_active_town(live_session))
	check(reinforced.plaques[0].value=="%d / %d stacks" % [live_force.troops,live_force.stack_count],"live town refresh shows stale defender counts")
	check(reinforced.plaques[1].value=="1 / 1 stacks","live town refresh shows stale garrison")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out+"/reinforced-town.png")
	get_tree().current_scene.queue_free()
	for i in range(3):await get_tree().process_frame
	print("BATTLE_READABILITY_REPORT "+JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''

if __name__ == '__main__':
    base.OUTPUT = OUTPUT
    base.SCRIPT = SCRIPT
    raise SystemExit(base.main())
