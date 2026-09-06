#!/usr/bin/env python3
"""Real saved movement, current HUD and exact previous-shell gameplay controls."""
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

MARKER = 'OVERWORLD_LIVE_COMMANDER_REPORT '
OWNER = 'scenes/overworld/OverworldShell.gd'
SHELL = '''extends "%s"
var roster_rebuilds := 0
var compact_full_refreshes := 0
var full_status_refreshes := 0
var route_scope_expansions := 0
func _refresh_with_request(request: Dictionary) -> void:
\tvar phases: Array = request.get("phases", [])
\tvar route_only := phases.has("route_preview") and not phases.has("status_surfaces") and not phases.has("hero_actions") and not phases.has("action_rails")
\tvar before := compact_full_refreshes + roster_rebuilds + full_status_refreshes
\tsuper._refresh_with_request(request)
\tif route_only and compact_full_refreshes + roster_rebuilds + full_status_refreshes != before:route_scope_expansions += 1
func _refresh_status_surfaces(started: int, context: Dictionary = {}) -> bool:
\tfull_status_refreshes += 1
\treturn super._refresh_status_surfaces(started, context)
func _rebuild_hero_actions() -> void:
\troster_rebuilds += 1
\tsuper._rebuild_hero_actions()
func _refresh_generated_opening_surfaces() -> void:
\tcompact_full_refreshes += 1
\tsuper._refresh_generated_opening_surfaces()
'''
PROBE = r'''
var checks := 0
var observations := []
var expected_states := {}
var variant := ""
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:failures.append(variant+": "+message)
func complete_state() -> String:
	return JSON.stringify(session.to_dict())
func line_fits(label: Label, line: String) -> bool:
	var font := label.get_theme_font("font")
	return font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x<=label.size.x
func control_state(label: String) -> void:
	if variant=="reference":expected_states[label]=complete_state()
	else:check(expected_states.get(label,"")==complete_state(),label+" complete gameplay state differs")
func hud(shell, label: String) -> void:
	var before := complete_state()
	var movement: Dictionary = session.overworld.movement
	var move := "Move %d/%d" % [int(movement.current),int(movement.max)]
	var pos := OverworldRules.hero_position(session)
	var compact: bool = shell._use_generated_compact_refresh() or shell._generated_initial_open_pending()
	var hero_text := String(shell._hero_label.text)
	var hero_tooltip := String(shell._hero_label.tooltip_text)
	var hero_fresh := move in hero_text if compact else move in hero_tooltip
	var status_fresh := move in String(shell._status_label.text)
	if compact:status_fresh = status_fresh and ("Pos %d,%d" % [pos.x,pos.y]) in String(shell._status_label.text)
	var resources: Dictionary = shell._resource_label.validation_snapshot().resources
	var resource_fresh := true
	for key in OverworldRules.LIVE_STOCKPILE_RESOURCE_KEYS:
		resource_fresh = resource_fresh and int(resources.get(key,0))==int(session.overworld.resources.get(key,0))
	var expected_holder := Heroes.army_slot_snapshot(session,{},String(session.overworld.active_hero_id))
	var army_fresh: bool = shell._army_management.validation_snapshot().holders == [expected_holder]
	var roster_fresh := true
	var actions := OverworldRules.get_hero_actions(session)
	for button in shell._hero_actions.get_children():
		for action in actions:
			if String(action.id)=="switch_hero:"+String(button.get_meta("hero_id","")):
				roster_fresh = roster_fresh and String(action.summary) in String(button.tooltip_text)
	var bounds_ok := true
	var viewport := Rect2(Vector2.ZERO,Vector2(get_window().size))
	for node in [shell._hero_label,shell._status_label,shell._resource_label,shell._hero_actions,shell._town_actions,shell._end_turn_button,shell._save_button]:
		bounds_ok = bounds_ok and viewport.encloses(node.get_global_rect())
	if variant=="current":
		check(hero_fresh,label+" stale hero movement")
		check(status_fresh,label+" stale status movement/position")
		check(resource_fresh,label+" stale stockpile")
		check(army_fresh,label+" stale army")
		check(roster_fresh,label+" stale roster tooltip")
		check(bounds_ok,label+" primary control outside viewport")
		if compact:
			check(hero_text.split("\n").size()==2 and hero_text.split("\n")[1]==move and line_fits(shell._hero_label,move),label+" movement hidden behind hero name ellipsis")
			for line in String(shell._status_label.text).split("\n"):
				check(line_fits(shell._status_label,line),label+" clipped primary status line")
			for primary in [shell._hero_label,shell._status_label]:
				check(primary.get_line_count()*primary.get_line_height()<=primary.size.y,label+" primary text height clipped")
	check(before==complete_state(),label+" HUD observation changed gameplay")
	observations.append({"variant":variant,"stage":label,"movement":movement.duplicate(true),"hero_text":hero_text,"hero_tooltip":hero_tooltip,"status_text":shell._status_label.text,"hero_fresh":hero_fresh,"status_fresh":status_fresh,"resources_fresh":resource_fresh,"army_fresh":army_fresh,"roster_fresh":roster_fresh,"bounds_ok":bounds_ok})
func wait_movement(shell) -> void:
	await settle()
	var started := Time.get_ticks_msec()
	while shell._map_view._hero_movement_active or shell._map_view._object_resolution_active or shell._map_view._object_resolution_queued:
		if Time.get_ticks_msec()-started>30000:check(false,"movement did not settle");return
		await get_tree().process_frame
func legal_step(shell) -> Vector2i:
	var origin := OverworldRules.hero_position(session)
	for delta in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
		var tile: Vector2i = origin+delta
		if not OverworldRules.is_tile_visible(session,tile.x,tile.y):continue
		if shell._tile_has_guard_approach_selection(tile):continue
		if shell._tile_has_exact_selection_target(tile):
			var resource: Dictionary = OverworldRules.resource_node_interaction_at_tile(session,tile.x,tile.y)
			if not bool(resource.get("collected",false)) or String(resource.get("collected_by_faction_id",""))!="player":continue
		var path: Array = shell._build_path(origin,tile)
		if path.size()!=2:continue
		var preview: Dictionary = OverworldRules.route_movement_preview(session,path,int(session.overworld.movement.current))
		if bool(preview.get("destination_reachable",false)):return delta
	return Vector2i.ZERO
func key_step(delta: Vector2i) -> void:
	var action: StringName = {Vector2i.LEFT:&"hero_move_left",Vector2i.RIGHT:&"hero_move_right",Vector2i.UP:&"hero_move_up",Vector2i.DOWN:&"hero_move_down"}[delta]
	var code: Key = SettingsService.hero_movement_keycode(action)
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode=code;event.physical_keycode=code;event.pressed=pressed
		Input.parse_input_event(event)
		await get_tree().process_frame
func controller_step(delta: Vector2i) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis=JOY_AXIS_LEFT_X if delta.x!=0 else JOY_AXIS_LEFT_Y
	event.axis_value=float(delta.x if delta.x!=0 else delta.y)
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = InputEventJoypadMotion.new()
	event.axis=JOY_AXIS_LEFT_X if delta.x!=0 else JOY_AXIS_LEFT_Y
	event.axis_value=0.0
	Input.parse_input_event(event)
	await get_tree().process_frame
func find_claim(shell) -> Dictionary:
	var origin := OverworldRules.hero_position(session)
	if OS.get_environment("COMMANDER_AUTHORED")=="1":
		var delta := legal_step(shell)
		return {"id":"","tile":origin+delta} if delta!=Vector2i.ZERO else {}
	var candidates := []
	for target in shell._validation_targets("resource"):
		if not known(target) or String(target.get("site_id","")) not in ["site_waystone_cache","site_ore_crates","site_aetherglass_lens_house"] or bool(target.get("collected",false)) or Transit.is_native(target) or not resource_claim_feasible(target):continue
		var entry: Dictionary = target.get("visit_tile",target)
		var tile := Vector2i(int(entry.x),int(entry.y))
		if not OverworldRules.guard_engagement_encounter_at_tile(session,tile.x,tile.y).is_empty():continue
		candidates.append({"id":String(target.placement_id),"tile":tile,"distance":origin.distance_to(tile)})
	candidates.sort_custom(func(a,b):return a.id<b.id if is_equal_approx(a.distance,b.distance) else a.distance<b.distance)
	for candidate in candidates:
		var path: Array = shell._build_path(origin,candidate.tile)
		if path.size()<2 or not path.all(func(tile):return OverworldRules.is_tile_visible(session,tile.x,tile.y)):continue
		if bool(OverworldRules.route_movement_preview(session,path,int(session.overworld.movement.current)).get("destination_reachable",false)):return candidate
	return {}
func rebuild_rosters_read_only(shell, label: String) -> void:
	var before := complete_state()
	shell._rebuild_hero_actions();shell._rebuild_town_actions()
	check(before==complete_state(),label+" roster rendering changed gameplay")
func roster_edges(shell) -> void:
	# Explicit detached UI boundary fixtures AFTER real actions/save validation.
	# They are never captured as gameplay, saved, or counted as match progress.
	var original: Dictionary = session.to_dict().duplicate(true)
	var active_id := String(session.overworld.active_hero_id)
	var active = shell._existing_roster_button(shell._hero_actions,"hero_id",active_id)
	var active_node_id: int = active.get_instance_id()
	active.grab_focus()
	for attempt in range(3):rebuild_rosters_read_only(shell,"unchanged")
	check(shell._existing_roster_button(shell._hero_actions,"hero_id",active_id).get_instance_id()==active_node_id,"unchanged hero node recreated")
	check(get_viewport().gui_get_focus_owner()==active,"unchanged roster lost focus")
	var extra: Dictionary = session.overworld.player_heroes[0].duplicate(true)
	extra.id="hero_veilmourn_orso_nightchart" if active_id=="hero_lyra" else "hero_lyra"
	extra.name="Detached roster control"
	extra.is_primary=false
	session.overworld.player_heroes.append(extra)
	OverworldRules.normalize_overworld_state(session)
	rebuild_rosters_read_only(shell,"member added")
	check(shell._hero_actions.get_child_count()==2,"new owned hero missing")
	check(shell._existing_roster_button(shell._hero_actions,"hero_id",active_id).get_instance_id()==active_node_id,"adding a hero replaced existing node")
	session.overworld.player_heroes.reverse()
	rebuild_rosters_read_only(shell,"member reorder")
	check(String(shell._hero_actions.get_child(0).get_meta("hero_id",""))==String(extra.id),"hero order not refreshed")
	session.overworld.player_heroes=session.overworld.player_heroes.filter(func(hero):return String(hero.id)==active_id)
	rebuild_rosters_read_only(shell,"member removed")
	check(shell._hero_actions.get_child_count()==1 and shell._hero_actions.get_child(0).get_instance_id()==active_node_id,"removed hero retained or active node replaced")
	var town: Dictionary = session.overworld.towns.filter(func(row):return String(row.get("owner",""))=="player")[0]
	var town_id := String(town.placement_id)
	var town_button = shell._existing_roster_button(shell._town_actions,"town_placement_id",town_id)
	var town_node_id: int = town_button.get_instance_id()
	var town_count: int = shell._town_actions.get_child_count()
	town_button.grab_focus()
	rebuild_rosters_read_only(shell,"town unchanged")
	check(town_button.get_instance_id()==town_node_id and get_viewport().gui_get_focus_owner()==town_button,"Town refresh lost node/focus")
	# Movement is now naturally exhausted; an adjacent non-source entrance is
	# only an explicit coordinate-refresh fixture, not a movement attempt.
	var destination := OverworldRules.hero_position(session)+Vector2i.RIGHT
	town.visit_tile={"x":destination.x,"y":destination.y,"level":0}
	rebuild_rosters_read_only(shell,"town entrance changed")
	check(shell._existing_roster_button(shell._town_actions,"town_placement_id",town_id).get_instance_id()==town_node_id,"entrance update recreated Town button")
	var expected: Vector2i = shell._selection_route_tile(destination)
	var before := complete_state()
	town_button.pressed.emit()
	check(shell._selected_tile==expected,"Town button retained stale bound entrance")
	check(before==complete_state(),"Town focus/selection changed gameplay")
	var callbacks := 0
	for connection in town_button.pressed.get_connections():
		if connection.callable.get_method()=="_on_town_roster_pressed":callbacks+=1
	check(callbacks==1,"Town refresh duplicated its action callback")
	town.owner="neutral"
	rebuild_rosters_read_only(shell,"town ownership removed")
	check(shell._town_actions.get_child_count()==town_count-1 and shell._existing_roster_button(shell._town_actions,"town_placement_id",town_id)==null,"foreign Town retained in owned roster")
	town.owner="player"
	rebuild_rosters_read_only(shell,"town ownership restored")
	check(shell._town_actions.get_child_count()==town_count and shell._existing_roster_button(shell._town_actions,"town_placement_id",town_id)!=null,"restored owned Town missing")
	session=SessionState.restore_session(original)
func run_match() -> void:
	get_tree().current_scene=null
	out=OS.get_environment("COMMANDER_OUTPUT")
	SettingsService.set_presentation_mode("windowed")
	SettingsService.set_presentation_resolution(OS.get_environment("COMMANDER_RESOLUTION"))
	SettingsService.set_reduced_motion_enabled(true)
	var resolution := OS.get_environment("COMMANDER_RESOLUTION").split("x")
	get_window().content_scale_size=Vector2i(int(resolution[0]),int(resolution[1]))
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("COMMANDER_SAVE")))
	if OS.get_environment("COMMANDER_AUTHORED")=="1":
		payload=ScenarioFactory.create_session("river-pass","normal",SessionState.LAUNCH_MODE_SKIRMISH).to_dict()
	for owner in ["reference","current"]:
		variant=owner
		session=SessionState.restore_session(payload.duplicate(true))
		var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
		shell.set_script(load(OS.get_environment("COMMANDER_"+variant.to_upper())))
		get_tree().root.add_child(shell);get_tree().current_scene=shell
		await settle()
		control_state("entry");hud(shell,"entry")
		var selected := find_claim(shell)
		check(not selected.is_empty(),"no real feasible claim")
		if selected.is_empty():break
		var roster_ids: Array = shell._hero_actions.get_children().map(func(button):return button.get_instance_id())
		var origin := OverworldRules.hero_position(session)
		var before := complete_state()
		shell._set_selected_tile(origin)
		shell._refresh_selected_route_preview("commander_initial_selection")
		await settle()
		check(before==complete_state(),"read-only route selection changed gameplay state")
		var focus = shell._hero_actions.get_child(0)
		var focus_name: String = focus.name
		focus.grab_focus()
		shell.roster_rebuilds=0;shell.compact_full_refreshes=0
		control_state("selection");hud(shell,"selection")
		shell._on_map_tile_pressed(selected.tile)
		await wait_movement(shell)
		if OverworldRules.hero_position(session)==origin:
			check(before==complete_state(),"destination selection spent gameplay state")
			check(get_viewport().gui_get_focus_owner()==focus,"selection lost roster focus")
			shell._on_map_tile_pressed(selected.tile)
			await wait_movement(shell)
		check(OverworldRules.hero_position(session)==selected.tile,"ordinary pointer route did not arrive")
		if selected.id!="":
			var claimed: Dictionary = OverworldRules._find_resource_node_by_placement(session,selected.id).get("node",{})
			check(bool(claimed.get("collected",false)),"ordinary pointer route did not claim selected resource")
		if variant=="current":check(get_viewport().gui_get_focus_owner()==focus,"collection lost roster focus")
		control_state("collected");hud(shell,"collected")
		if shell.compact_full_refreshes==0:
			check(shell.roster_rebuilds==0,"route-only refresh recreated roster buttons")
		if variant=="current":check(roster_ids==shell._hero_actions.get_children().map(func(button):return button.get_instance_id()),"collection changed roster node identity")
		await screenshot(variant+"_collected")
		for input_kind in ["keyboard","controller"]:
			var delta := legal_step(shell)
			check(delta!=Vector2i.ZERO,input_kind+" no legal empty step")
			if delta==Vector2i.ZERO:continue
			origin=OverworldRules.hero_position(session)
			if input_kind=="keyboard":await key_step(delta)
			else:await controller_step(delta)
			await wait_movement(shell)
			check(OverworldRules.hero_position(session)==origin+delta,input_kind+" did not perform a legal step")
			var focused = get_viewport().gui_get_focus_owner()
			var focus_retained: bool = focused!=null and String(focused.name)==focus_name
			if variant=="current":check(focus_retained,input_kind+" lost logical roster focus")
			observations.append({"variant":variant,"stage":input_kind+"_focus","focus_retained":focus_retained})
			control_state(input_kind);hud(shell,input_kind)
		check(shell._active_drawer=="" and not shell._command_panel.visible and not shell._frontier_panel.visible,"movement opened a drawer")
		check(shell.route_scope_expansions==0,"route-only request rebuilt full status or roster")
		var steps := 0
		while int(session.overworld.movement.current)>0 and steps<64:
			var delta := legal_step(shell)
			if delta==Vector2i.ZERO:break
			await key_step(delta)
			await wait_movement(shell)
			steps+=1
		check(int(session.overworld.movement.current)==0,"fixture did not naturally exhaust movement")
		control_state("exhausted");hud(shell,"exhausted")
		origin=OverworldRules.hero_position(session)
		await key_step(Vector2i.LEFT)
		await wait_movement(shell)
		check(OverworldRules.hero_position(session)==origin and int(session.overworld.movement.current)==0,"no-movement command changed position/budget")
		control_state("no_movement");hud(shell,"no_movement")
		before=complete_state()
		var path := SaveService.save_session(session.to_dict(),1)
		var restored = SessionState.restore_session(SaveService.load_session(1))
		check(path!="" and restored!=null and JSON.parse_string(JSON.stringify(restored.to_dict()))==JSON.parse_string(before),"complete save/restore state differs")
		control_state("saved")
		if variant=="current":roster_edges(shell)
		get_tree().current_scene=null;shell.queue_free()
		await get_tree().process_frame
	print("OVERWORLD_LIVE_COMMANDER_REPORT "+JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"authored_control":OS.get_environment("COMMANDER_AUTHORED")=="1","scope":"real saved claim or authored empty route, keyboard/controller and natural movement exhaustion; exact prior shell states; isolated user data"}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''


def main():
    signal.signal(signal.SIGTERM, stop_requested)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--label', required=True)
    parser.add_argument('--save', required=True, type=Path)
    parser.add_argument('--resolution', choices=['1280x720','1920x1080'], default='1280x720')
    parser.add_argument('--authored-control', action='store_true', help='Use an ordinary River Pass start instead of the supplied generated save')
    args = parser.parse_args()
    if not re.fullmatch('[a-z0-9_-]+', args.label):parser.error('fresh lowercase label required')
    source = args.save.resolve()
    source_hash = hashlib.sha256(source.read_bytes()).hexdigest()
    old = subprocess.check_output(['git','show',f'e17a4480:{OWNER}'],cwd=ROOT,text=True)
    current_hash = hashlib.sha256((ROOT/OWNER).read_bytes()).hexdigest()
    out = OUTPUT/args.label
    out.mkdir(parents=True,exist_ok=False)
    with tempfile.TemporaryDirectory(prefix='commander-probe-',dir=OUTPUT) as scripts, tempfile.TemporaryDirectory(prefix='heroes-commander-',dir='/dev/shm') as data:
        work=Path(scripts)
        def resource(path):return 'res://'+str(path.relative_to(ROOT))
        (work/'old.gd').write_text(old)
        (work/'reference.gd').write_text(SHELL % resource(work/'old.gd'))
        (work/'current.gd').write_text(SHELL % ('res://'+OWNER))
        (work/'probe.gd').write_text(MATCH_SCRIPT[:MATCH_SCRIPT.index('func run_match()')]+PROBE)
        scene=work/'probe.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="%s" id="1"]\n[node name="CommanderRefresh" type="Node"]\nscript=ExtResource("1")\n' % resource(work/'probe.gd'))
        env=dict(os.environ,XDG_DATA_HOME=data,COMMANDER_SAVE=str(source),COMMANDER_OUTPUT=str(out),COMMANDER_RESOLUTION=args.resolution,COMMANDER_AUTHORED='1' if args.authored_control else '0',COMMANDER_REFERENCE=resource(work/'reference.gd'),COMMANDER_CURRENT=resource(work/'current.gd'))
        command=['dbus-run-session','--','xvfb-run','-a','-s','-screen 0 2200x1200x24','godot4','--path',str(ROOT),'--audio-driver','Dummy','--accessibility','disabled','--resolution',args.resolution,resource(scene)]
        with (out/'runtime.log').open('w') as log:code=run_probe(command,env,log)
    lines=(out/'runtime.log').read_text().splitlines()
    reports=[json.loads(x[len(MARKER):]) for x in lines if x.startswith(MARKER)]
    report=reports[-1] if reports else {'ok':False,'failures':['missing final report']}
    errors=[x for x in lines if x.startswith(('ERROR:','SCRIPT ERROR:')) or 'leaked' in x]
    report.update(returncode=code,runtime_errors=errors,resolution=args.resolution,source_save_sha256=source_hash,source_save_unchanged=source_hash==hashlib.sha256(source.read_bytes()).hexdigest(),reference_revision='e17a4480',reference_owner_sha256=hashlib.sha256(old.encode()).hexdigest(),current_owner_sha256=current_hash,current_owner_unchanged=current_hash==hashlib.sha256((ROOT/OWNER).read_bytes()).hexdigest())
    report['ok']=bool(report['ok']) and code==0 and not errors and report['source_save_unchanged'] and report['current_owner_unchanged']
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k!='observations'}))
    return 0 if report['ok'] else 1


if __name__=='__main__':raise SystemExit(main())
