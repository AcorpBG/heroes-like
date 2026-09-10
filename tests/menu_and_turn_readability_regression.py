#!/usr/bin/env python3
"""Python-owned real menu and fog-filtered turn presentation regression."""
from pathlib import Path
from contextlib import nullcontext
import os
import battle_readability_regression as runner

ROOT = runner.ROOT
OUTPUT = ROOT / '.artifacts/menu_and_turn_readability_20260910'
run_probe = runner.run_probe
probe_environment = runner.probe_environment
SCRIPT = r'''extends Node
const Capture = preload("res://scripts/core/OverworldTurnPlayback.gd")
const Store = preload("res://scripts/core/SessionStateStore.gd")
const Setup = preload("res://scripts/core/ScenarioSelectRules.gd")
var failures:=[]
var checks:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures.append(message)
func _ready()->void:
	call_deferred("run")
func run()->void:
	var out:=OS.get_environment("BATTLE_READABILITY_OUT")
	SettingsService.set_reduced_motion_enabled(OS.get_environment("BATTLE_READABILITY_REDUCED")=="1")
	var menu=load("res://scenes/menus/MainMenu.tscn").instantiate()
	add_child(menu)
	for i in range(8): await get_tree().process_frame
	var dimensions:=OS.get_environment("TOWN_OVERLAY_RESOLUTION").split("x")
	var requested:=Vector2i(int(dimensions[0]),int(dimensions[1]))
	DisplayServer.window_set_size(requested)
	get_tree().root.size=requested
	get_tree().root.content_scale_size=requested
	for i in range(5): await get_tree().process_frame
	check(not menu._stage_dock_panel.visible,"main menu opens with a detail dashboard")
	check(menu._title_label.text=="AURELION\nREACH","new wordmark hierarchy missing")
	var viewport:=Rect2(Vector2.ZERO,Vector2(requested))
	var previous:=Rect2()
	menu._open_campaign_button.grab_focus()
	var navigation:Array=menu._first_view_buttons()
	for index in range(1,navigation.size()):
		var down:=InputEventAction.new()
		down.action="ui_down"
		down.pressed=true
		get_viewport().push_input(down)
		down=InputEventAction.new()
		down.action="ui_down"
		down.pressed=false
		get_viewport().push_input(down)
		for i in range(2): await get_tree().process_frame
		check(get_viewport().gui_get_focus_owner()==navigation[index],"keyboard navigation failed at "+navigation[index].name)
	menu._open_campaign_button.grab_focus()
	for button in menu._first_view_buttons():
		var rect:Rect2=button.get_global_rect()
		check(button.is_visible_in_tree() and viewport.encloses(rect),"first view command clips: "+button.name)
		check(not rect.intersects(previous),"first view commands overlap")
		previous=rect
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		var capture:=get_viewport().get_texture().get_image()
		check(capture.get_size()==requested,"wrong captured resolution")
		capture.save_png(out.path_join("main-menu.png"))
	menu._menu_notice="The last save could not be loaded. Choose another saved expedition or begin a new adventure."
	menu._refresh_summary()
	menu._apply_stage_dock_layout()
	for i in range(3): await get_tree().process_frame
	check(not menu._logo_pocket_panel.get_global_rect().intersects(menu._open_campaign_button.get_global_rect()),"menu notice overlaps primary navigation")
	check(viewport.encloses(menu._logo_pocket_panel.get_global_rect()),"menu notice container clips viewport")
	check(viewport.encloses(menu._quit_button.get_global_rect()),"menu notice pushes commands outside viewport: "+str(menu._logo_pocket_panel.get_global_rect())+" / "+str(menu._logo_pocket_panel.get_combined_minimum_size())+" / "+str(menu._quit_button.get_global_rect()))
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("menu-notice.png"))
	menu._menu_notice=""
	menu._refresh_summary()
	menu._apply_stage_dock_layout()
	for tab in [0,1,2,3,4]:
		menu._toggle_stage_dock(tab)
		for i in range(5): await get_tree().process_frame
		check(menu._stage_dock_panel.visible,"secondary menu failed to open")
		menu._hide_stage_dock()
		for i in range(3): await get_tree().process_frame
		check(menu._open_campaign_button.is_visible_in_tree(),"primary navigation not restored")
	menu.queue_free()
	for i in range(4): await get_tree().process_frame
	var session=ScenarioFactory.create_session("river-pass","normal",SessionState.LAUNCH_MODE_SKIRMISH)
	if OS.get_environment("MENU_TURN_GENERATED")=="1":
		var config:=Setup.build_random_map_player_config("10","translated_rmg_template_042_v1","translated_rmg_profile_042_v1",2,"land",false,"homm3_medium",Setup.RANDOM_MAP_TEMPLATE_SELECTION_MODE_SIZE_DEFAULT,"faction_embercourt","")
		var setup:=Setup.build_random_map_skirmish_setup_with_retry(config,"normal",Setup.RANDOM_MAP_PLAYER_RETRY_POLICY)
		check(bool(setup.get("ok",false)),"representative native map setup failed")
		if not bool(setup.get("ok",false)):
			print("BATTLE_READABILITY_REPORT "+JSON.stringify({"ok":false,"checks":checks,"failures":failures}))
			get_tree().quit(1)
			return
		session=Setup.start_random_map_skirmish_session_from_setup(setup)
	OverworldRules._normalize_fog_of_war(session)
	# Expose a controlled authored battlefield for the real AI executor probe.
	for row in session.overworld.fog.explored_tiles: row.fill(true)
	for row in session.overworld.fog.visible_tiles: row.fill(true)
	var events:=[]
	var candidate=Store.new_session_data()
	var terminal_candidate=Store.new_session_data()
	for day in range(4):
		if not session.battle.is_empty(): break
		var before:Dictionary=session.to_dict().duplicate(true)
		var control=Store.new_session_data()
		control.from_dict(session.to_dict().duplicate(true))
		Capture.begin(session)
		OverworldRules.end_turn(session)
		events.append_array(Capture.finish(session))
		OverworldRules.end_turn(control)
		check(session.to_dict()==control.to_dict(),"turn capture changed authoritative state")
		if session.battle.is_empty(): candidate.from_dict(before)
		else: terminal_candidate.from_dict(before)
	check(not events.is_empty(),"actual AI turns produced no presentation")
	var moves:=events.filter(func(e):return e.kind=="move")
	check(not moves.is_empty(),"actual AI execution produced no visible movement records")
	for event in events:
		if event.kind=="action": check(event.has("actor"),"visible interaction lacks its actor art")
	var fog_case=Store.new_session_data()
	fog_case.from_dict(session.to_dict().duplicate(true))
	for row in fog_case.overworld.fog.explored_tiles: row.fill(false)
	for row in fog_case.overworld.fog.visible_tiles: row.fill(false)
	for x in [1,2]:
		fog_case.overworld.fog.explored_tiles[1][x]=true
		fog_case.overworld.fog.visible_tiles[1][x]=true
	var actor:Dictionary={"placement_id":"fog_probe","x":1,"y":1,"target_x":8,"target_y":8,"target_debug_reason":"hidden objective"}
	Capture.begin(fog_case)
	Capture.move(fog_case,actor,{"x":0,"y":1})
	actor.x=2
	Capture.move(fog_case,actor,{"x":1,"y":1})
	actor.x=3
	Capture.move(fog_case,actor,{"x":2,"y":1})
	actor.x=8
	Capture.move(fog_case,actor,{"x":7,"y":1})
	Capture.action(fog_case,actor,"does something hidden")
	var filtered:=Capture.finish(fog_case)
	check(filtered.size()==3,"fog filtering leaked or lost boundary events")
	check(filtered.map(func(e):return e.kind)==["appear","move","disappear"],"fog entry/exit does not use safe transitions")
	for record in filtered:
		check(int(record.from.x) in [1,2] and int(record.to.x) in [1,2],"hidden coordinates leaked into presentation")
		check(not record.actor.has("target_x") and not record.actor.has("target_debug_reason"),"AI plan leaked into art snapshot")
	Capture.begin(fog_case)
	actor.x=1
	actor.level=1
	Capture.move(fog_case,actor,{"x":2,"y":1,"level":1})
	check(Capture.finish(fog_case).is_empty(),"other map level leaked into playback")
	fog_case.overworld.players=[{"player_id":"player_2","faction_id":"faction_mireclaw"},{"player_id":"player_3","faction_id":"faction_mireclaw"}]
	Capture.begin(fog_case)
	for player in fog_case.overworld.players: Capture.player_turn(fog_case,player)
	var identities:=Capture.finish(fog_case)
	check(identities.size()==2 and identities[0].player_id!=identities[1].player_id and identities[0].caption!=identities[1].caption,"same-faction players lost turn identity")
	if DisplayServer.get_name()!="headless":
		if OS.get_environment("MENU_TURN_GENERATED")=="1":
			# A diagnostic scouted corridor, not a default full-map reveal.
			for row in candidate.overworld.fog.explored_tiles: row.fill(false)
			for row in candidate.overworld.fog.visible_tiles: row.fill(false)
			OverworldRules._reveal_current_fog_sources(candidate)
			var dimensions_map:=OverworldRules.derive_map_size(candidate)
			for record in events:
				if not record.has("to"): continue
				for y in range(maxi(0,int(record.to.y)-2),mini(dimensions_map.y,int(record.to.y)+3)):
					for x in range(maxi(0,int(record.to.x)-2),mini(dimensions_map.x,int(record.to.x)+3)):
						candidate.overworld.fog.explored_tiles[y][x]=true
						candidate.overworld.fog.visible_tiles[y][x]=true
		var live=SessionState.set_active_session(candidate)
		var shell=load("res://scenes/overworld/OverworldShell.tscn").instantiate()
		add_child(shell)
		for i in range(10): await get_tree().process_frame
		var order:Dictionary=shell._commit_end_turn()
		check(order.ok and is_instance_valid(shell._turn_presenter),"actual end turn did not start presentation")
		var committed_day:int=live.day
		check(not shell._commit_end_turn().ok and live.day==committed_day,"double End Turn bypassed playback lock")
		var captures:=[]
		while is_instance_valid(shell._turn_presenter):
			await get_tree().create_timer(0.12).timeout
			if not is_instance_valid(shell._turn_presenter): break
			var kind:=String(shell._turn_presenter.current_event.get("kind",""))
			if kind not in captures:
				check(viewport.encloses(shell._turn_presenter._banner.get_global_rect()),"turn banner clips viewport")
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(out.path_join("ai-"+kind+".png"))
				captures.append(kind)
		check("turn" in captures and "move" in captures,"live visible turn/movement evidence missing")
		check(not shell._end_turn_commit_in_progress,"turn input lock not released")
		var unchanged:Dictionary=live.to_dict().duplicate(true)
		var skipping=load("res://scenes/overworld/OverworldTurnPresenter.gd").new()
		shell.add_child(skipping)
		skipping.start(shell._map_view,live.overworld.encounters,[{"kind":"turn","caption":"Skip control probe"},{"kind":"turn","caption":"Must be skipped"}])
		skipping.skip_playback()
		for i in range(3): await get_tree().process_frame
		check(not is_instance_valid(skipping) and not shell._map_view._turn_playback_active,"skip did not restore the live map")
		check(live.to_dict()==unchanged,"skipping presentation changed simulation")
		shell.queue_free()
		for i in range(4): await get_tree().process_frame
		if not terminal_candidate.overworld.is_empty():
			SessionState.set_active_session(terminal_candidate)
			AppRouter.validation_set_battle_entry_routing_suppressed(true)
			AppRouter.validation_reset_battle_entry_state()
			var terminal=load("res://scenes/overworld/OverworldShell.tscn").instantiate()
			add_child(terminal)
			for i in range(8): await get_tree().process_frame
			var terminal_order:Dictionary=terminal._commit_end_turn()
			check(terminal_order.ok and is_instance_valid(terminal._turn_presenter),"battle-causing end turn skipped playback")
			check(AppRouter.validation_battle_entry_snapshot().route_attempt_count==0,"battle routed before turn playback")
			terminal._turn_presenter.skip_playback()
			for i in range(10): await get_tree().process_frame
			check(not is_instance_valid(terminal._turn_presenter) and AppRouter.validation_battle_entry_snapshot().route_attempt_count==1,"playback did not hand off to battle exactly once")
			AppRouter.validation_set_battle_entry_routing_suppressed(false)
			terminal.queue_free()
			for i in range(3): await get_tree().process_frame
	var menu_events:=events.map(func(e):return e.get("caption",""))
	print("BATTLE_READABILITY_REPORT "+JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures,"turn_events":menu_events}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''

def main():
    runner.ROOT = ROOT
    runner.OUTPUT = OUTPUT
    runner.SCRIPT = SCRIPT
    runner.run_probe = run_probe
    runner.probe_environment = probe_environment
    from generated_neutral_map_regression import preserve_generated_map_files
    with preserve_generated_map_files('medium') if os.environ.get('MENU_TURN_GENERATED') == '1' else nullcontext():
        return runner.main()

if __name__ == '__main__':
    raise SystemExit(main())
