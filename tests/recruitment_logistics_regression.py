#!/usr/bin/env python3
"""Exercise local town holders and site-visit recruitment through live rules."""
import battle_readability_regression as base

OUTPUT = base.ROOT / '.artifacts/recruitment_logistics_20260912'
SCRIPT = base.SCRIPT.split('func _ready()')[0] + r'''
func _ready()->void:
	call_deferred("run_logistics")
func town_fixture():
	var s=ScenarioFactory.create_session("river-pass","normal",SessionState.LAUNCH_MODE_SKIRMISH)
	var town:Dictionary={}
	for row in s.overworld.towns:
		if row.owner=="player":town=row;break
	s.flags[OverworldRules.ACTIVE_TOWN_PLACEMENT_KEY]=town.placement_id
	town.garrison=[]
	for key in s.overworld.resources:s.overworld.resources[key]=100000
	return s
func run_logistics()->void:
	out=OS.get_environment("BATTLE_READABILITY_OUT")
	if not OS.has_feature("editor"):
		var setup_rules=preload("res://scripts/core/ScenarioSelectRules.gd")
		var config:=setup_rules.build_random_map_player_config("10","","",2,"land",false,"homm3_small",setup_rules.RANDOM_MAP_TEMPLATE_SELECTION_MODE_SIZE_DEFAULT,"faction_embercourt","")
		var setup:=setup_rules.build_random_map_skirmish_setup_with_retry(config,"normal",setup_rules.RANDOM_MAP_PLAYER_RETRY_POLICY)
		check(bool(setup.get("ok",false)),"native Small setup failed")
		if bool(setup.get("ok",false)):
			var generated=setup_rules.start_random_map_skirmish_session_from_setup(setup)
			for home in generated.overworld.towns:
				if home.owner!="player":continue
				var recipient:=HeroCommandRules.town_recruitment_destination(generated,home)
				check(recipient.holder_id==generated.overworld.active_hero_id,"native starting entrance fails local recruitment")
				break
	for mode in ["local","remote","other_local","wrong_level","full","merge","full_local","remote_full_army"]:
		var s=town_fixture()
		s.overworld.map_size.level_count=2
		var town:Dictionary=TownRules.get_active_town(s)
		var hero:Dictionary=s.overworld.player_heroes[0]
		var unit_id:String=hero.army.stacks[0].unit_id
		town.available_recruits={unit_id:5}
		var entrance:=preload("res://scripts/core/OverworldLevelRules.gd").town_entrance(town)
		hero.position=entrance.duplicate(true)
		if mode not in ["local","full_local"]:hero.position.x+=4
		if mode=="wrong_level":hero.position=entrance.duplicate(true);hero.position.level=int(entrance.get("level",0))+1
		s.overworld.player_heroes=[hero]
		var expected_holder:=HeroCommandRules.HOLDER_GARRISON
		if mode in ["local","full_local"]:expected_holder=hero.id
		if mode=="other_local":
			var other:Dictionary=hero.duplicate(true)
			other.id="test_local_commander"
			other.is_primary=false
			other.position=entrance.duplicate(true)
			other.army.stacks=[]
			s.overworld.player_heroes.append(other)
			expected_holder=other.id
		if mode in ["full","merge","full_local","remote_full_army"]:
			var filled:=[]
			for row in ContentService.load_json(ContentService.UNITS_PATH).items:
				if row.id==unit_id:continue
				filled.append({"unit_id":row.id,"count":1})
				if filled.size()==7:break
			if mode in ["full_local","remote_full_army"]:hero.army.stacks=filled
			else:town.garrison=filled
			if mode=="merge":town.garrison[0]={"unit_id":unit_id,"count":3}
		HeroCommandRules._sync_active_hero_mirror(s)
		OverworldRules.normalize_overworld_state(s)
		town=TownRules.get_active_town(s)
		var before_army:Dictionary=s.overworld.army.duplicate(true)
		var before_resources:Dictionary=s.overworld.resources.duplicate(true)
		var before_query:Dictionary=s.to_dict().duplicate(true)
		var destination:=HeroCommandRules.town_recruitment_destination(s,town)
		check(before_query==s.to_dict(),mode+": destination preview changed state")
		check(destination.holder_id==expected_holder,mode+": wrong destination")
		var actions:=TownRules.get_recruit_actions(s)
		check(not actions.is_empty(),mode+": missing recruitment action")
		if not actions.is_empty():
			check(String(actions[0].summary).contains(destination.label),mode+": missing destination disclosure")
			check(bool(actions[0].disabled)==(mode in ["full","full_local"]),mode+": capacity availability mismatch")
		var unit_cost:=OverworldRules.town_recruit_cost(s,town,unit_id)
		var result:=TownRules.recruit_active_town(s,unit_id,2)
		check(bool(result.ok)==(mode not in ["full","full_local"]),mode+": incorrect purchase result: "+String(result.get("message","")))
		town=TownRules.get_active_town(s)
		if mode in ["full","full_local"]:
			check(s.overworld.resources==before_resources,"full destination spent resources")
			check(int(town.available_recruits[unit_id])==5,"full destination consumed reserve")
		else:
			check(int(town.available_recruits[unit_id])==3,mode+": reserve not consumed once")
			for key in before_resources:
				check(int(s.overworld.resources[key])==int(before_resources[key])-2*int(unit_cost.get(key,0)),mode+": incorrect cost "+key)
			check(String(result.message).contains(destination.label),mode+": confirmation lacks actual destination")
			var stacks:=HeroCommandRules._holder_stacks(s,town,expected_holder)
			check(OverworldRules._army_unit_count(stacks,unit_id)==OverworldRules._army_unit_count(destination.stacks,unit_id)+2,mode+": incorrect recipient count")
		if mode!="local":check(s.overworld.army==before_army,mode+": distant active hero received troops")
		var restored=Store.new_session_data()
		restored.from_dict(s.to_dict().duplicate(true))
		check(HeroCommandRules._holder_stacks(restored,TownRules.get_active_town(restored),expected_holder)==HeroCommandRules._holder_stacks(s,town,expected_holder),mode+": save roundtrip lost recruits")
	for mode in ["poor","partial","lost","empty_reserve"]:
		var s=town_fixture()
		var town:=TownRules.get_active_town(s)
		var unit_id:String=s.overworld.army.stacks[0].unit_id
		town.available_recruits={unit_id:5 if mode!="empty_reserve" else 0}
		if mode in ["poor","partial"]:
			for key in s.overworld.resources:s.overworld.resources[key]=0
			if mode=="partial":s.overworld.resources=OverworldRules.town_recruit_cost(s,town,unit_id).duplicate(true)
		if mode=="lost":
			for row in s.overworld.towns:row.owner="enemy"
		var before_resources:Dictionary=s.overworld.resources.duplicate(true)
		var result:=TownRules.recruit_active_town(s,unit_id,99)
		check(bool(result.ok)==(mode=="partial"),mode+": wrong purchase result")
		if mode!="partial":check(s.overworld.resources==before_resources,mode+": invalid purchase spent resources")
		else:check(int(TownRules.get_active_town(s).available_recruits[unit_id])==4,"partial affordability did not clamp purchase")
	# A valid authored recruit site cannot be invoked remotely or on another level.
	var site_session=town_fixture()
	var site:Dictionary={}
	for row in ContentService.load_json(ContentService.RESOURCE_SITES_PATH).items:
		if not OverworldRules._resource_site_claim_recruits(row).is_empty():site=row;break
	check(not site.is_empty(),"no recruit site fixture")
	var node:Dictionary={"placement_id":"logistics_site","site_id":site.id,"x":3,"y":3,"collected":false}
	site_session.overworld.resource_nodes=[node]
	site_session.overworld.hero_position={"x":8,"y":8,"level":0}
	var before:Dictionary=site_session.to_dict().duplicate(true)
	var denied:=OverworldRules._collect_resource_node_result(site_session,{"index":0,"node":node})
	check(not denied.ok and String(denied.message).contains("visit"),"remote site recruitment allowed")
	check(site_session.to_dict()==before,"rejected site visit mutated state")
	site_session.overworld.hero_position={"x":3,"y":3,"level":1}
	check(not OverworldRules.hero_is_visiting_resource_site(site_session,node),"wrong-level site counted as visit")
	site_session.overworld.hero_position={"x":3,"y":3,"level":0}
	check(OverworldRules.hero_is_visiting_resource_site(site_session,node),"local site rejected")
	var offset_node:Dictionary=node.duplicate(true)
	offset_node.visit_tile={"x":4,"y":3,"level":0}
	check(not OverworldRules.hero_is_visiting_resource_site(site_session,offset_node),"native site body treated as its visit tile")
	site_session.overworld.hero_position.x=4
	check(OverworldRules.hero_is_visiting_resource_site(site_session,offset_node),"explicit native visit tile ignored")
	site_session.overworld.hero_position.x=3
	var collected:=OverworldRules._collect_resource_node_result(site_session,{"index":0,"node":node})
	check(bool(collected.ok),"local site claim failed: "+String(collected.get("message","")))
	# Display identity changes must not alias the six separate authored units.
	var names:=[]
	for unit_id in ["unit_shard_guard","unit_prism_adept","unit_mirror_duelist","unit_sunvault_shard_wardens","unit_sunvault_prism_adepts","unit_sunvault_mirror_duelists"]:
		var unit:=ContentService.get_unit(unit_id)
		check(not unit.is_empty() and not unit.name in names,"missing/duplicate unit identity "+unit_id)
		names.append(unit.name)
	check(ContentService.get_building("building_shard_yard").name!=ContentService.get_building("building_sunvault_shard_yard").name,"ambiguous Shard Yard labels remain")
	check(ContentService.get_building("building_prism_range").requires==["building_shard_yard"],"display fix changed dwelling prerequisites")
	# Real Muster modal: explicit local destination, total price, and a live purchase.
	var ui_session=town_fixture()
	var ui_town:Dictionary=TownRules.get_active_town(ui_session)
	var ui_hero:Dictionary=ui_session.overworld.player_heroes[0]
	ui_hero.position={"x":int(ui_town.x)+4,"y":int(ui_town.y)}
	HeroCommandRules._sync_active_hero_mirror(ui_session)
	var ui_unit:String=ui_hero.army.stacks[0].unit_id
	ui_town.available_recruits={ui_unit:5}
	ui_session.game_state="town"
	ui_session=SessionState.set_active_session(ui_session)
	var holder=Node.new()
	get_tree().root.add_child(holder)
	get_tree().current_scene=holder
	get_tree().change_scene_to_file("res://scenes/town/TownShell.tscn")
	await get_tree().scene_changed
	for i in range(4):await get_tree().process_frame
	var dimensions:=OS.get_environment("TOWN_OVERLAY_RESOLUTION").split("x")
	var requested:=Vector2i(int(dimensions[0]),int(dimensions[1]))
	if DisplayServer.get_name()!="headless":DisplayServer.window_set_size(requested)
	get_tree().root.size=requested
	get_tree().root.content_scale_size=requested
	var shell=get_tree().current_scene
	var stage_town:Dictionary=shell._town_stage_town_payload(TownRules.get_active_town(ui_session))
	check(stage_town.visit_tile==preload("res://scripts/core/OverworldLevelRules.gd").town_entrance(TownRules.get_active_town(ui_session)),"scenic payload dropped the town entrance")
	var staged:Dictionary=shell._build_town_stage_view_state()
	var signature:String=shell._town_stage_signature(staged)
	staged.stationed=[ui_hero.duplicate(true)]
	var before_army_signature:String=shell._town_stage_signature(staged)
	staged.stationed[0].army.stacks[0].count+=1
	check(shell._town_stage_signature(staged)!=before_army_signature,"stationed reinforcement left scenic defense cached")
	check(signature!=shell._town_stage_signature(staged),"stationed roster did not invalidate scenic defense")
	shell._open_town_catalog("muster")
	for i in range(5):await get_tree().process_frame
	check(shell._town_catalog_subtitle_label.text.contains("garrison"),"modal hides destination")
	check(shell._town_catalog_subtitle_label.text.contains("immediately"),"modal hides arrival time")
	if DisplayServer.get_name()!="headless":
		check(Rect2(Vector2.ZERO,Vector2(requested)).encloses(shell._town_catalog_subtitle_label.get_global_rect()),"destination subtitle clips")
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out+"/garrison-muster-before.png")
	var army_before:Dictionary=ui_session.overworld.army.duplicate(true)
	var button:Button=null
	for row in shell._recruit_actions.get_children():
		for child in row.get_child(0).get_children():
			if child is Button and child.get_meta("catalog_entry_id","")=="recruit:"+ui_unit:button=child
	check(button!=null and not button.disabled,"live recruit button unavailable")
	if button!=null and not button.disabled:button.pressed.emit()
	for i in range(6):await get_tree().process_frame
	ui_session=SessionState.ensure_active_session()
	check(ui_session.overworld.army==army_before,"UI purchase reached remote hero")
	check(OverworldRules._army_unit_count(TownRules.get_active_town(ui_session).garrison,ui_unit)==5,"UI purchase did not reach garrison")
	check(shell._town_catalog_subtitle_label.text.contains("1/7 stacks"),"destination capacity stayed stale after purchase")
	check(int(shell._town_stage_view.validation_town_action_presentation_snapshot().get("recruited_count",0))==5,"garrison purchase lost recruitment animation")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out+"/garrison-muster-after.png")
	# Native town anchors can differ from their actual entrances. The scenic
	# defense plaque must use that same entrance as recruitment and combat.
	ui_town=TownRules.get_active_town(ui_session)
	ui_town.visit_tile={"x":int(ui_town.x)-2,"y":int(ui_town.y),"level":0}
	ui_session.overworld.player_heroes[0].position=ui_town.visit_tile.duplicate(true)
	HeroCommandRules._sync_active_hero_mirror(ui_session)
	shell._close_town_catalog()
	shell._refresh()
	for i in range(4):await get_tree().process_frame
	var expected_force:=HeroCommandRules.town_defense_force(ui_session,TownRules.get_active_town(ui_session))
	var plaques:Dictionary=shell._town_stage_view.validation_status_plaques_summary()
	check(plaques.plaques[0].value=="%d / %d stacks" % [expected_force.troops,expected_force.stack_count],"scenic defense omitted visiting hero at offset entrance")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out+"/offset-entrance-defense.png")
	get_tree().current_scene.queue_free()
	for i in range(4):await get_tree().process_frame
	print("BATTLE_READABILITY_REPORT "+JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''

if __name__ == '__main__':
    base.OUTPUT = OUTPUT
    base.SCRIPT = SCRIPT
    raise SystemExit(base.main())
