#!/usr/bin/env python3
"""Real scene selection must stage an order before commitment."""
import battle_readability_regression as base

OUTPUT = base.ROOT / '.artifacts/targeting_commit_20260912'
SCRIPT = base.SCRIPT.split('func _ready()')[0] + r'''
func _ready()->void:call_deferred("run_selection")
func run_selection()->void:
	out=OS.get_environment("BATTLE_READABILITY_OUT")
	var session=SessionState.set_active_session(fixture())
	var shell=load("res://scenes/battle/BattleShell.tscn").instantiate()
	get_tree().root.add_child(shell)
	get_tree().current_scene=shell
	for i in range(4):await get_tree().process_frame
	var dimensions:=OS.get_environment("TOWN_OVERLAY_RESOLUTION").split("x")
	var requested:=Vector2i(int(dimensions[0]),int(dimensions[1]))
	if DisplayServer.get_name()!="headless": DisplayServer.window_set_size(requested)
	get_tree().root.size=requested
	get_tree().root.content_scale_size=requested
	for i in range(4):await get_tree().process_frame
	var target_id:String=session.battle.selected_target_id
	var before:Dictionary=session.battle.duplicate(true)
	# A second ally proves support spells retain an explicitly chosen recipient.
	var ally:Dictionary=session.battle.stacks[0].duplicate(true)
	ally.battle_id="explicit_spell_ally"
	ally.hex={"q":0,"r":2}
	session.battle.stacks.append(ally)
	BattleRules._sync_occupied_hexes(session.battle)
	shell._refresh()
	var selected:Dictionary=shell._on_board_stack_focus_requested(target_id)
	check(selected.get("state","")=="selected","first attack click did not stage")
	check(not shell._action_playback_in_progress,"first click started combat playback")
	check(BattleRules.get_active_stack(session.battle).total_health==BattleRules.get_active_stack(before).total_health,"selection took damage")
	check(shell._confirm_order_button.visible,"selected order lacks confirm control")
	shell._battle_board_view.set_consequence_preview({})
	check(not shell._battle_board_view._consequence_preview.is_empty(),"pointer departure erased staged preview")
	shell._cancel_board_order()
	check(shell._pending_board_order.is_empty() and not shell._confirm_order_button.visible,"cancel did not clear intent")
	check(not shell._confirm_board_order().get("ok",false),"empty confirm committed")
	var spell_checks:=0
	for action in BattleRules.get_spell_actions(session):
		if action.get("disabled",false):continue
		var spell_id:String=String(action.id).trim_prefix("cast_spell:")
		var untouched:Dictionary=session.to_dict().duplicate(true)
		var ids:Array=BattleRules.spell_target_ids(session,spell_id)
		check(session.to_dict()==untouched,"legal spell target query mutated state")
		if ids.is_empty():continue
		shell._on_spell_action_pressed(action.id)
		check(session.to_dict()==untouched and not shell._action_playback_in_progress,"spell button cast immediately")
		check(shell._spell_targeting_id==spell_id,"spell button did not enter targeting mode")
		check(shell._battle_board_view._spell_target_candidates==ids,"spell highlights disagree with legal targets")
		var candidate:Dictionary=BattleRules._get_stack_by_id(session.battle,ids[0])
		var hex:Dictionary=BattleRules._stack_hex(candidate)
		var point:Vector2=shell._battle_board_view._hex_center(Vector2i(int(hex.q),int(hex.r)),shell._battle_board_view._current_hex_layout())
		shell._battle_board_view._preview_position(point)
		check(shell._battle_board_view._consequence_preview.get("action","")==action.id,"spell hover displayed a movement/attack forecast")
		var invalid:Dictionary=shell._on_board_stack_focus_requested("missing_stack")
		check(not invalid.ok and shell._pending_board_order.is_empty(),"invalid spell target retained a committable order")
		var spell_selected:Dictionary=shell._on_board_stack_focus_requested(ids[0])
		check(spell_selected.get("state","")=="selected" and session.to_dict()==untouched,"spell target selection cast or changed state")
		check(String(shell._pending_board_order.target_id)==String(ids[0]),"spell silently retargeted")
		shell._on_next_target_pressed()
		check(not shell._action_playback_in_progress,"spell cycling cast")
		check(shell._pending_board_order.target_id==ids[1 % ids.size()],"spell next target did not match living candidates")
		var intended:String=shell._pending_board_order.target_id
		var preview:Dictionary=BattleRules.spell_consequence_preview(session,spell_id,intended)
		check(preview.ok and preview.target_id==intended,"explicit spell preview changed recipient")
		var copied=Store.new_session_data()
		copied.from_dict(session.to_dict().duplicate(true))
		var cast:Dictionary=BattleRules.cast_player_spell(copied,spell_id,intended)
		check(cast.ok,"explicit previewed spell could not cast")
		var invalid_copy=Store.new_session_data()
		invalid_copy.from_dict(session.to_dict().duplicate(true))
		var invalid_before:Dictionary=invalid_copy.to_dict().duplicate(true)
		check(not BattleRules.cast_player_spell(invalid_copy,spell_id,"gone").ok and invalid_copy.to_dict()==invalid_before,"invalid explicit spell spent mana or silently retargeted")
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(out+"/selected-spell-"+spell_id+".png")
		shell._cancel_board_order()
		check(shell._spell_targeting_id=="" and shell._battle_board_view._spell_target_candidates.is_empty(),"spell cancel left stale targeting")
		spell_checks+=1
	check(spell_checks>0,"no spell mode coverage")
	# Confirm an actual spell through the scene, not only the pure rules API.
	var available:Array=BattleRules.get_spell_actions(session)
	for action in available:
		if action.get("disabled",false):continue
		var spell_id:String=String(action.id).trim_prefix("cast_spell:")
		var ids:Array=BattleRules.spell_target_ids(session,spell_id)
		if ids.is_empty():continue
		shell._on_spell_action_pressed(action.id)
		shell._on_board_stack_focus_requested(ids[0])
		shell._validation_battle_resolution_routing_enabled=false
		var cast:Dictionary=shell._on_board_stack_focus_requested(ids[0])
		check(cast.ok and shell._pending_board_order.is_empty() and shell._spell_targeting_id=="","second explicit spell activation did not commit and consume selection")
		check(not shell._confirm_board_order().ok,"spell confirmed twice")
		shell._validation_battle_resolution_routing_enabled=true
		break
	session.battle=before.duplicate(true)
	shell._refresh()
	# Both enemies are shootable; cycling is selection-only and excludes corpses.
	session.battle.stacks[0].ranged=true
	session.battle.stacks[0].shots_remaining=8
	shell._refresh()
	var candidates:Array=BattleRules.target_cycle_ids(session.battle)
	check(candidates.size()==2,"cycle fixture lacks two live legal targets")
	var cycle_before:String=session.battle.selected_target_id
	shell._on_next_target_pressed()
	check(session.battle.selected_target_id!=cycle_before and not shell._action_playback_in_progress,"Next did not change live target or spent an action")
	shell._on_prev_target_pressed()
	check(session.battle.selected_target_id==cycle_before,"Prev did not reverse target cycle")
	session.battle.stacks[2].total_health=0
	shell._refresh()
	check(BattleRules.target_cycle_ids(session.battle).size()==1 and shell._next_target_button.disabled,"dead target remains in cycle/button count")
	session.battle=before.duplicate(true)
	shell._refresh()
	# Real controller dispatch stages the same order; Escape cancels it.
	var board=shell._battle_board_view
	board.grab_focus()
	board._controller_cursor_cell=Vector2i(5,3)
	var key:=InputEventKey.new()
	key.keycode=KEY_ENTER
	key.pressed=true
	board._gui_input(key)
	check(not shell._pending_board_order.is_empty() and not shell._action_playback_in_progress,"keyboard board activation did not preview")
	key.echo=true
	board._gui_input(key)
	check(not shell._action_playback_in_progress and not shell._pending_board_order.is_empty(),"held Enter auto-confirmed selection")
	var cancel:=InputEventJoypadButton.new()
	cancel.button_index=JOY_BUTTON_B
	cancel.pressed=true
	shell._on_root_window_input(cancel)
	check(shell._pending_board_order.is_empty(),"controller cancel did not dismiss staged order")
	# Handoff cannot accept another order even after ordinary playback ends.
	shell._battle_exit_handoff_in_progress=true
	check(not shell._on_board_stack_focus_requested(target_id).ok,"handoff accepted target input")
	shell._battle_exit_handoff_in_progress=false
	shell._on_board_stack_focus_requested(target_id)
	session.battle.round=int(session.battle.round)+1
	check(not shell._confirm_board_order().get("ok",false),"changed battlefield accepted stale order")
	session.battle=before.duplicate(true)
	shell._refresh()
	var destination:Dictionary=BattleRules.legal_destinations_for_active_stack(session.battle)[0]
	var move_before:Dictionary=session.battle.duplicate(true)
	var move:Dictionary=shell._on_board_hex_destination_requested(int(destination.q),int(destination.r))
	check(move.get("state","")=="selected","first move click did not stage")
	check(session.battle==move_before,"move selection spent an action")
	var move_copy=Store.new_session_data()
	move_copy.from_dict(session.to_dict().duplicate(true))
	var expected_move:Dictionary=BattleRules.perform_presented_action(move_copy,"move",destination)
	shell._validation_battle_resolution_routing_enabled=false
	var moved:Dictionary=shell._confirm_board_order()
	check(moved.ok and expected_move.ok,"confirmed tactical movement rejected")
	check(session.battle.stacks==move_copy.battle.stacks,"confirmed tactical movement differs from authoritative order")
	shell._validation_battle_resolution_routing_enabled=true
	session.battle=before.duplicate(true)
	shell._refresh()
	shell._cancel_board_order()
	shell._on_board_stack_focus_requested(target_id)
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		for control in [shell._confirm_order_button,shell._cancel_order_button,shell._prev_target_button,shell._next_target_button]:
			check(control.is_visible_in_tree(),"targeting control hidden at supported resolution")
			check(Rect2(Vector2.ZERO,Vector2(requested)).encloses(control.get_global_rect()),"targeting control clips viewport")
		get_viewport().get_texture().get_image().save_png(out+"/selected-attack.png")
	var committed:Dictionary=shell._confirm_board_order()
	check(committed.get("ok",false),"confirmed attack rejected")
	check(shell._pending_board_order.is_empty(),"committed order not consumed")
	check(not shell._confirm_board_order().get("ok",false),"order executed twice")
	while shell._action_playback_in_progress:await get_tree().process_frame
	for i in range(4):await get_tree().process_frame
	shell.queue_free()
	for i in range(4):await get_tree().process_frame
	await run_map_selection()
	await run_guard_selection()
	print("BATTLE_READABILITY_REPORT "+JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures}))
	get_tree().quit(0 if failures.is_empty() else 1)

func run_map_selection()->void:
	var session=ScenarioFactory.create_session("river-pass","normal",SessionState.LAUNCH_MODE_SKIRMISH)
	if not OS.has_feature("editor"):
		var setup_rules=preload("res://scripts/core/ScenarioSelectRules.gd")
		var config:=setup_rules.build_random_map_player_config("10","","",2,"land",false,"homm3_small",setup_rules.RANDOM_MAP_TEMPLATE_SELECTION_MODE_SIZE_DEFAULT,"faction_embercourt","")
		var setup:=setup_rules.build_random_map_skirmish_setup_with_retry(config,"normal",setup_rules.RANDOM_MAP_PLAYER_RETRY_POLICY)
		check(bool(setup.get("ok",false)),"native Small setup failed")
		if not bool(setup.get("ok",false)):return
		session=setup_rules.start_random_map_skirmish_session_from_setup(setup)
	session=SessionState.set_active_session(session)
	var shell=load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	get_tree().root.add_child(shell)
	get_tree().current_scene=shell
	for i in range(8):await get_tree().process_frame
	var hero:=OverworldRules.hero_position(session)
	var tested:=0
	for delta in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT,Vector2i(4,4)]:
		var tile:Vector2i=hero+delta
		if not shell._tile_in_bounds(tile) or not shell._town_footprint_selection(tile).is_empty():continue
		var state:Dictionary=session.to_dict().duplicate(true)
		shell._on_map_tile_pressed(tile)
		check(session.to_dict()==state,"first map selection moved or entered battle")
		check(shell._pointer_order_tile==shell._selected_tile,"map selection did not arm preview")
		shell._cancel_pointer_order()
		check(session.to_dict()==state and shell._selected_tile==hero,"map cancel spent movement or retained destination")
		tested+=1
	check(tested>0,"no adjacent/distant map selection fixture")
	for encounter in session.overworld.encounters.slice(0,3):
		var tile:=Vector2i(int(encounter.x),int(encounter.y))
		var state:Dictionary=session.to_dict().duplicate(true)
		shell._on_map_tile_pressed(tile)
		check(session.to_dict()==state and session.game_state=="overworld","hostile selection entered combat")
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(out+"/selected-hostile-route.png")
		shell._cancel_pointer_order()
	# Compare one deliberate adjacent commit with the authoritative movement rule.
	var committed_move:=false
	for delta in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
		var tile:Vector2i=hero+delta
		if not shell._tile_in_bounds(tile) or not shell._town_footprint_selection(tile).is_empty():continue
		var copied=Store.new_session_data()
		copied.from_dict(session.to_dict().duplicate(true))
		var expected:Dictionary=OverworldRules.try_move(copied,delta.x,delta.y)
		if not expected.get("ok",false) or not copied.battle.is_empty() or copied.game_state!="overworld":continue
		shell._on_map_tile_pressed(tile)
		check(OverworldRules.hero_position(session)==hero,"adjacent first click already moved")
		shell._on_map_tile_pressed(tile)
		check(OverworldRules.hero_position(session)==OverworldRules.hero_position(copied),"confirmed map order destination differs from movement rule")
		check(session.overworld.movement.current==copied.overworld.movement.current,"confirmed map order spent unexpected movement")
		committed_move=true
		break
	check(committed_move,"no actual adjacent map commit coverage")
	shell.queue_free()
	for i in range(4):await get_tree().process_frame

func run_guard_selection()->void:
	# Keep the authored encounter/pathing identity; place only the test hero at
	# a neighboring legal approach to exercise the actual interception route.
	var session=ScenarioFactory.create_session("river-pass","normal",SessionState.LAUNCH_MODE_SKIRMISH)
	var start:Dictionary=session.to_dict().duplicate(true)
	var destination:=Vector2i.ZERO
	var expected_id:=""
	for encounter in session.overworld.encounters:
		for delta in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var probe=Store.new_session_data()
			probe.from_dict(start.duplicate(true))
			destination=Vector2i(int(encounter.x),int(encounter.y))
			probe.overworld.player_heroes[0].position={"x":destination.x-delta.x,"y":destination.y-delta.y}
			HeroCommandRules._sync_active_hero_mirror(probe)
			var before:Dictionary=probe.to_dict().duplicate(true)
			var result:Dictionary=OverworldRules.try_move(probe,delta.x,delta.y)
			if result.get("route","")=="battle" and not probe.battle.is_empty():
				expected_id=String(probe.battle.encounter_id)
				session.from_dict(before)
				break
		if expected_id!="":break
	check(expected_id!="","no legitimate guarded approach fixture")
	if expected_id=="":return
	session=SessionState.set_active_session(session)
	var shell=load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	get_tree().root.add_child(shell)
	get_tree().current_scene=shell
	shell._validation_end_turn_resolution_routing_enabled=false
	for i in range(4):await get_tree().process_frame
	var before:Dictionary=session.to_dict().duplicate(true)
	shell._on_map_tile_pressed(destination)
	check(session.to_dict()==before and session.battle.is_empty(),"first adjacent hostile click entered combat")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out+"/guard-selected.png")
	shell._on_map_tile_pressed(destination)
	check(not session.battle.is_empty() and session.battle.get("encounter_id","")==expected_id,"confirmed guarded order lost authoritative interception")
	check(shell._validation_battle_entry_request_count==1,"guarded order requested duplicate battle entry")
	shell._on_map_tile_pressed(destination)
	check(shell._validation_battle_entry_request_count==1,"scene handoff accepted another map order")
	shell.queue_free()
	for i in range(4):await get_tree().process_frame
'''

if __name__ == '__main__':
    base.OUTPUT = OUTPUT
    base.SCRIPT = SCRIPT
    raise SystemExit(base.main())
