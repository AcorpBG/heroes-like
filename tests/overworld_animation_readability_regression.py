#!/usr/bin/env python3
"""Motion curve controls plus actual AI, fog, skip and save/handoff regression."""
import menu_and_turn_readability_regression as town
import os
from contextlib import nullcontext

ROOT = town.ROOT
OUTPUT = ROOT / '.artifacts/overworld_animation_20260912'
run_probe = town.run_probe
probe_environment = town.probe_environment
CONTROLS = r'''
	var motion=load("res://scenes/overworld/OverworldMotion.gd")
	check(is_equal_approx(motion.travel(0.0),0.0) and is_equal_approx(motion.travel(1.0),1.0),"travel endpoints drift")
	var last:=0.0
	for i in range(101):
		var t:=float(i)/100.0
		var value:float=motion.travel(t)
		check(value>=last and value>=0.0 and value<=1.0,"travel reverses or overshoots")
		check(is_equal_approx(value,1.0-motion.travel(1.0-t)),"asymmetric travel ramps")
		last=value
	check(motion.travel(.05)<.05 and motion.travel(.95)>.95,"acceleration/settling missing")
	check(is_zero_approx(motion.emphasis(0.0)) and is_zero_approx(motion.emphasis(1.0)),"interaction pops at lifetime boundaries")
	check(motion.emphasis(.3)>.99,"interaction has no readable hold")
	check(motion.stride_offset(0.0,100.0).is_zero_approx() and motion.stride_offset(1.0,100.0).is_zero_approx(),"stride moves resting feet")
	check(motion.stride_offset(.5,100.0).y>=-1.5,"stride floats above terrain")
'''
SEQUENCE = r'''
func player_route_sequence(shell,out:String)->void:
	var view=shell._map_view
	var original:Dictionary=shell._session.to_dict().duplicate(true)
	var start:Vector2i=OverworldRules.hero_position(shell._session)
	var found:=false
	for offset in [Vector2i(2,0),Vector2i(-2,0),Vector2i(0,2),Vector2i(0,-2),Vector2i(2,2),Vector2i(-2,-2)]:
		var target:Vector2i=start+offset
		if not shell._tile_in_bounds(target):continue
		shell._set_selected_tile(target)
		var state:Dictionary=shell._ensure_selected_route_state("animation_probe")
		var path:Array=state.get("route_tiles",[])
		if path.size()<3 or path.size()>6:continue
		var clear:=true
		for point in path.slice(1):
			var tile:Vector2i=point if point is Vector2i else Vector2i(int(point.x),int(point.y))
			if OverworldRules.tile_has_route_interaction(shell._session,tile.x,tile.y):clear=false
		if not clear:continue
		var before_position:Vector2i=OverworldRules.hero_position(shell._session)
		shell._move_toward_selected_tile()
		if before_position==OverworldRules.hero_position(shell._session):continue
		found=true
		break
	check(found,"no legal multi-step player route exercised")
	if not found:return
	var committed:Dictionary=shell._session.to_dict().duplicate(true)
	check(view._hero_movement_path.size()>1,"player move missing route presentation")
	check(view._hero_movement_path[-1]==OverworldRules.hero_position(shell._session),"painted endpoint differs from committed hero")
	print("OVERWORLD_PLAYER_MOTION_PROFILE "+JSON.stringify({"steps":view._hero_movement_path.size()-1,"duration_sec":view._hero_movement_duration_sec,"reduced_motion":SettingsService.reduced_motion_enabled()}))
	if SettingsService.reduced_motion_enabled():
		check(not view._hero_movement_active,"reduced motion still interpolates player travel")
		shell._session.from_dict(original)
		shell._refresh()
		return
	view.set_process(false)
	for index in range(9):
		view._hero_movement_elapsed_sec=view._hero_movement_duration_sec*float(index)/8.0
		var state:Dictionary=view._hero_movement_draw_state(view._board_rect())
		check(not state.is_empty(),"player route draw state missing")
		var from_rect:Rect2=view._tile_rect(view._board_rect(),state.from_tile)
		var to_rect:Rect2=view._tile_rect(view._board_rect(),state.to_tile)
		check(state.center.is_equal_approx(from_rect.get_center().lerp(to_rect.get_center(),state.segment_progress)),"player cuts a route corner")
		if OS.get_environment("OVERWORLD_ANIMATION_BASELINE")!="1":
			var from_layout:Rect2=view._hero_draw_rect(from_rect,state.from_tile,true)
			var to_layout:Rect2=view._hero_draw_rect(to_rect,state.to_tile,true)
			check(state.hero_rect.position.is_equal_approx(from_layout.position.lerp(to_layout.position,state.segment_progress)),"town departure/arrival anchor pops")
			check(state.hero_rect.size.is_equal_approx(from_layout.size.lerp(to_layout.size,state.segment_progress)),"town departure/arrival size pops")
		view._invalidate_dynamic_layer("animation_probe")
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("sequence-player-%02d.png"%index))
	check(committed==shell._session.to_dict(),"player animation changes committed state")
	view._process(0.0)
	view._sync_presentation_processing()
	# The real player order was an isolated fixture; restore the exact AI-test
	# start so moving closer to a defender cannot change the handoff control.
	shell._session.from_dict(original)
	shell._refresh()

func capture_motion_sequence(shell,kind:String,out:String)->void:
	if kind not in ["move","action"]: return
	var presenter=shell._turn_presenter
	presenter.set_process(false)
	var view=shell._map_view
	var was_processing:bool=view.is_processing()
	view.set_process(false)
	var before:Dictionary=shell._session.to_dict().duplicate(true)
	var static_generation:int=view._session_static_cache_generation
	var ambient_generation:int=view._terrain_ambient_generation
	var tick_start:=Time.get_ticks_usec()
	for tick in range(120): view._process(1.0/120.0)
	var tick_usec:=Time.get_ticks_usec()-tick_start
	var redraws:int=view._terrain_ambient_generation-ambient_generation
	if OS.get_environment("OVERWORLD_ANIMATION_BASELINE")!="1":
		check(redraws<=31,"ambient work scales with display refresh")
	var board:Rect2=view._board_rect()
	var bounds:Rect2i=view._visible_tile_bounds(board,view._map_viewport_rect())
	var ambient_start:=Time.get_ticks_usec()
	var entries:Array=[]
	for tick in range(120): entries=view._overworld_terrain_ambient_entries(board,bounds,float(tick)/30.0)
	var ambient_usec:=Time.get_ticks_usec()-ambient_start
	for entry in entries:
		check(entry.explored and entry.contained,"ambient escapes explored tile")
	print("OVERWORLD_MOTION_PROFILE "+JSON.stringify({"kind":kind,"duration_sec":presenter._duration,"map_size":OverworldRules.derive_map_size(shell._session),"tick_120_usec":tick_usec,"ambient_120_usec":ambient_usec,"ambient_redraws":redraws,"viewport_entries":entries.size()}))
	var original_reduced:bool=SettingsService.reduced_motion_enabled()
	var original_contrast:bool=SettingsService.high_contrast_ui_enabled()
	SettingsService.set_reduced_motion_enabled(true)
	view._process(.1)
	var still_phase:float=view._terrain_ambient_phase
	view._process(.1)
	check(is_equal_approx(still_phase,view._terrain_ambient_phase),"reduced-motion scenery keeps moving")
	SettingsService.set_high_contrast_ui_enabled(true)
	check(view._overworld_terrain_ambient_entries(board,bounds,1.0).is_empty(),"high contrast still draws ambient clutter")
	SettingsService.set_high_contrast_ui_enabled(original_contrast)
	SettingsService.set_reduced_motion_enabled(original_reduced)
	# Accessibility changes may legitimately reflow the shell/camera. Measure
	# the animation-only frames after that layout work settles.
	for settle in range(3):await get_tree().process_frame
	static_generation=view._session_static_cache_generation
	for index in range(9):
		view.advance_turn_playback(float(index)/8.0)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("sequence-%s-%02d.png"%[kind,index]))
	check(before==shell._session.to_dict(),"animation sequence changed committed session")
	check(static_generation==view._session_static_cache_generation,"animation rebuilt static terrain")
	view.advance_turn_playback(presenter._elapsed/maxf(.01,presenter._duration))
	view.set_process(was_processing)
	presenter.set_process(true)

func headless_presenter_control(candidate,events:Array,out:String)->void:
	var live=SessionState.set_active_session(candidate)
	var shell=load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	for i in range(10):await get_tree().process_frame
	await player_route_sequence(shell,out)
	var before:Dictionary=live.to_dict().duplicate(true)
	# Production intentionally skips the automatic presenter when headless.
	# Exercise the shipped presenter directly with real fog-filtered records;
	# do not change the runtime headless policy just to enable a test.
	var presenter=load("res://scenes/overworld/OverworldTurnPresenter.gd").new()
	shell._turn_presenter=presenter
	shell.add_child(presenter)
	presenter.start(shell._map_view,live.overworld.encounters,events)
	presenter.set_process(false)
	for kind in ["move","action"]:
		var matching:Array=events.filter(func(e):return e.kind==kind)
		check(not matching.is_empty(),"headless presenter lacks actual "+kind+" records")
		if matching.is_empty():continue
		presenter.current_event=matching[0]
		shell._map_view.show_turn_playback_event(matching[0])
		await capture_motion_sequence(shell,kind,out)
		presenter.set_process(false)
	presenter.skip_playback()
	presenter.set_process(true)
	for i in range(4):await get_tree().process_frame
	check(not is_instance_valid(presenter) and not shell._map_view._turn_playback_active,"headless skip failed to restore map")
	check(before==live.to_dict(),"headless presentation changed committed state")
	shell.queue_free()
	for i in range(3):await get_tree().process_frame
'''
SCRIPT = town.SCRIPT.replace('var out:=OS.get_environment("BATTLE_READABILITY_OUT")',
                           'var out:=OS.get_environment("BATTLE_READABILITY_OUT")' +
                           ('' if os.environ.get('OVERWORLD_ANIMATION_BASELINE') == '1' else CONTROLS))
SCRIPT = SCRIPT.replace('func run()->void:', SEQUENCE + '\nfunc run()->void:')
SCRIPT = SCRIPT.replace('captures.append(kind)', 'captures.append(kind)\n\t\t\t\tawait capture_motion_sequence(shell,kind,out)')
SCRIPT = SCRIPT.replace('var order:Dictionary=shell._commit_end_turn()',
                        'await player_route_sequence(shell,out)\n\t\tvar order:Dictionary=shell._commit_end_turn()')
if os.environ.get('OVERWORLD_ANIMATION_BASELINE') != '1':
    SCRIPT = SCRIPT.replace('if event.kind=="action": check(event.has("actor"),"visible interaction lacks its actor art")',
                            'if event.kind=="action":\n\t\t\tcheck(event.has("actor"),"visible interaction lacks its actor art")\n\t\t\tcheck(event.get("vfx_cue_id","") in ["vfx_placeholder_capture_flag","vfx_placeholder_guard_warning"],"visible action missing authoritative art cue")')
# Preserve production's headless end-turn policy; exercise its player route and
# presenter explicitly, retaining the normal rendered handoff regression too.
SCRIPT = SCRIPT.replace('var menu_events:=events.map',
                        'if DisplayServer.get_name()=="headless":\n\t\tawait headless_presenter_control(candidate,events,out)\n\tvar menu_events:=events.map')
_lines = []
for _line in SCRIPT.splitlines():
    if ('await RenderingServer.frame_post_draw' in _line or
            'get_viewport().get_texture().get_image().save_png' in _line):
        _indent = _line[:len(_line) - len(_line.lstrip())]
        _lines.extend([_indent + 'if DisplayServer.get_name()!="headless":', '\t' + _line])
    else:
        _lines.append(_line)
SCRIPT = '\n'.join(_lines) + '\n'
if os.environ.get('OVERWORLD_ANIMATION_MAP_SIZE') == 'large':
    SCRIPT = SCRIPT.replace('"homm3_medium"', '"homm3_large"')


def main():
    town.OUTPUT = OUTPUT
    town.SCRIPT = SCRIPT
    town.run_probe = run_probe
    town.probe_environment = probe_environment
    from generated_neutral_map_regression import preserve_generated_map_files
    with preserve_generated_map_files('large') if os.environ.get('OVERWORLD_ANIMATION_MAP_SIZE') == 'large' else nullcontext():
        return town.main()


if __name__ == '__main__':
    raise SystemExit(main())
