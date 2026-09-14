#!/usr/bin/env python3
"""Layered raster VFX: pure motion, actual actions, accessibility and release packs."""
import sys
import battle_readability_regression as runner

ROOT = runner.ROOT
OUTPUT = ROOT / '.artifacts/combat-vfx-20260913'
run_probe = runner.run_probe
probe_environment = runner.probe_environment
COMPILED_OWNERS = ('scenes/battle/BattleBoardView.gdc', 'scenes/battle/BattleShell.gdc',
                  'scripts/ui/CombatVfxMotion.gdc', 'scripts/core/BattleActionPlayback.gdc')
SCRIPT = runner.SCRIPT.split('func _ready()')[0] + r'''
const Motion = preload("res://scripts/ui/CombatVfxMotion.gd")
var roles_seen:=[]
var runtime_cues:=[]
var runtime_roles:=[]
var max_layers:=0
var motion_usec:=0
func _ready()->void: call_deferred("run")
func pure_checks()->void:
	var entry:Dictionary={"progress":0.4,"hex_radius":32.0,"start_x":100.0,"start_y":100.0,"end_x":300.0,"end_y":100.0,"center_x":300.0,"center_y":100.0,"serial":3}
	var manifest:Dictionary=ContentService.load_json("res://content/battle_vfx_manifest.json")
	for cue in manifest.cues:
		var spec:Dictionary=manifest.cues[cue]
		entry.kind="stack_fade" if cue=="vfx_placeholder_stack_fade" else ""
		if not Motion.owns(spec,entry): continue
		entry.progress=0.4
		var original:Dictionary=entry.duplicate(true)
		var normal:Array=Motion.layers(spec,entry,{})
		check(normal.size()>0 and normal.size()<=Motion.MAX_LAYERS_PER_CUE,"unbounded/empty layers: "+cue)
		check(Motion.layers(spec,entry,{})==normal and original==entry,"nondeterministic/mutating layers: "+cue)
		for layer in normal:
			check(layer.alpha>0.0 and layer.alpha<=0.88 and layer.extent>0 and is_finite(layer.rotation),"invalid layer: "+cue)
			if layer.role not in roles_seen: roles_seen.append(layer.role)
		var reduced:Array=Motion.layers(spec,entry,{"reduced_motion":true})
		check(reduced.size()==1 and reduced[0].role=="reduced_static","reduced motion not stationary: "+cue)
		entry.progress=0.7
		var later:Array=Motion.layers(spec,entry,{"reduced_motion":true})
		check(reduced[0].center==later[0].center and reduced[0].extent==later[0].extent and reduced[0].rotation==later[0].rotation,"reduced geometry animates: "+cue)
		entry.progress=0.4
		var quiet:Array=Motion.layers(spec,entry,{"reduced_flashes":true})
		check(quiet.size()==normal.size() and quiet[0].alpha<normal[0].alpha,"reduced flashes not attenuated: "+cue)
		for phase in [0.0,1.0,-0.5,1.5]:
			entry.progress=phase
			check(Motion.layers(spec,entry,{}).is_empty(),"expired cue still draws: "+cue)
	entry.kind=""
	# Adjacent-cell attacks and retaliations must leave the attacker's body
	# readable, including reduced motion and oversized authored cue scales.
	for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2(0.5,0.866),Vector2(-0.5,-0.866)]:
		for radius in [16.0,32.0,64.0]:
			var origin:=Vector2(150,150)
			var target:Vector2=origin+direction*radius*sqrt(3.0)
			var contact:Dictionary={"progress":0.5,"hex_radius":radius,"start_x":origin.x,"start_y":origin.y,"end_x":target.x,"end_y":target.y,"center_x":origin.x,"center_y":origin.y}
			for preferences in [{},{"reduced_motion":true},{"reduced_flashes":true}]:
				var slashes:=Motion.layers({"render_mode":"slash","scale":3.5},contact,preferences)
				for layer in slashes:
					check(layer.extent<=radius*1.15+0.001,"slash still blankets a full unit body")
					check(layer.alpha<=0.55,"slash overwhelms articulated pose")
					var expected_center:=origin.lerp(target,0.86)+Vector2(0,-radius*0.62)
					check(layer.center.distance_to(expected_center)<0.001,"slash detached from directional contact")
	entry.progress=0.25
	var projectile:Dictionary=manifest.cues.vfx_placeholder_projectile_path
	var first:Array=Motion.layers(projectile,entry,{})
	entry.progress=0.75
	var last:Array=Motion.layers(projectile,entry,{})
	check(first[-1].center.x<last[-1].center.x and first[-1].center.y==last[-1].center.y,"projectile does not follow actual path")
	check(first[0].center.x<=first[-1].center.x,"trail ahead of projectile")
	var started:=Time.get_ticks_usec()
	for i in range(10000): Motion.layers(projectile,entry,{})
	motion_usec=Time.get_ticks_usec()-started
	check(motion_usec<3000000,"pure layers unexpectedly slow (>3s/10000 cues)")
func case_session(action:String):
	var session=fixture()
	if action=="shoot":
		var stack:Dictionary=BattleRules._build_battle_stack("unit_mire_slinger",20,"player",0,{"source_type":"combat_vfx_probe"})
		stack.battle_id=session.battle.stacks[0].battle_id
		stack.hex={"q":2,"r":3}
		session.battle.stacks[0]=stack
	if action.begins_with("cast_spell:"):
		session.battle.player_commander_state={"name":"VFX caster","command":{"power":2,"knowledge":8},"spellbook":{"known_spell_ids":["spell_cinder_burst"],"mana":{"current":40,"max":40}}}
	BattleRules._sync_occupied_hexes(session.battle)
	BattleRules._sync_distance_from_hexes(session.battle)
	return session
func sample(board:Control,frame:Dictionary,phase:float)->Array:
	board.set_battle_presentation_snapshot(frame)
	# Freeze only presentation clocks for deterministic phase inspection. No
	# session writes or fabricated gameplay events: frame came from real rules.
	for key in board._stack_animation_cue_playback_records:
		var record:Dictionary=board._stack_animation_cue_playback_records[key]
		record.max_duration_ms=1000000
		record.started_at_msec=Time.get_ticks_msec()-int(phase*1000000)
		record.expires_at_msec=Time.get_ticks_msec()+1000000
		board._stack_animation_playback_until_msec[key]=record.expires_at_msec
	board.queue_redraw()
	var layers:Array=board._combat_vfx_layers(board._current_hex_layout(),board._stack_cells())
	max_layers=maxi(max_layers,layers.size())
	check(layers.size()<=Motion.MAX_LAYERS_PER_FRAME,"frame layer budget exceeded")
	for layer in layers:
		check(board._battle_vfx_texture_for_path(layer.asset_path)!=null,"layer texture not imported")
		if layer.cue_id not in runtime_cues: runtime_cues.append(layer.cue_id)
		if layer.role not in runtime_roles: runtime_roles.append(layer.role)
	return layers
func capture(name:String,requested:Vector2i)->void:
	if DisplayServer.get_name()=="headless": return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image:=get_viewport().get_texture().get_image()
	check(image.get_size()==requested,"wrong capture resolution")
	image.save_png(out.path_join(name+".png"))
func run()->void:
	out=OS.get_environment("BATTLE_READABILITY_OUT")
	pure_checks()
	SettingsService.set_battle_playback_speed_id(OS.get_environment("BATTLE_READABILITY_SPEED"))
	SettingsService.set_reduced_motion_enabled(false)
	SettingsService.set_reduced_flashes_enabled(false)
	var session=SessionState.set_active_session(fixture())
	var shell=load("res://scenes/battle/BattleShell.tscn").instantiate()
	add_child(shell)
	for i in range(8): await get_tree().process_frame
	var dimensions:=OS.get_environment("TOWN_OVERLAY_RESOLUTION").split("x")
	var requested:=Vector2i(int(dimensions[0]),int(dimensions[1]))
	if DisplayServer.get_name()!="headless": DisplayServer.window_set_size(requested)
	get_tree().root.size=requested
	get_tree().root.content_scale_size=requested
	for i in range(4): await get_tree().process_frame
	var board:Control=shell._battle_board_view
	var expected:Dictionary={"strike":"slash_sweep","shoot":"projectile_head","cast_spell:spell_cinder_burst":"spell_bloom"}
	for action in expected:
		var live=case_session(action)
		var direct=Store.new_session_data()
		direct.from_dict(live.to_dict().duplicate(true))
		var result:Dictionary=BattleRules.perform_presented_action(live,action)
		var ordinary:Dictionary=BattleRules.cast_player_spell(direct,"spell_cinder_burst") if action.begins_with("cast_spell:") else BattleRules.perform_player_action(direct,action)
		check(result.ok and ordinary.ok,"real action failed: "+action+" "+str(result.get("message","")))
		check(live.to_dict()==direct.to_dict(),"presentation changes simulation: "+action)
		var committed:Dictionary=live.to_dict().duplicate(true)
		var matched:=false
		for frame in result.get("playback_frames",[]):
			var layers:=sample(board,frame,0.45)
			if not matched and layers.any(func(layer):return layer.role==expected[action]):
				matched=true
				for phase in [0.2,0.5,0.8]:
					sample(board,frame,phase)
					await capture(action.replace(":","-")+"-"+str(int(phase*100)),requested)
				SettingsService.set_reduced_motion_enabled(true)
				var quiet:=sample(board,frame,0.5)
				check(quiet.all(func(layer):return layer.role=="reduced_static"),"runtime reduced motion has animated layers")
				await capture(action.replace(":","-")+"-reduced",requested)
				SettingsService.set_reduced_motion_enabled(false)
			elif action=="strike" and layers.any(func(layer):return layer.role=="impact_bloom"):
				await capture("impact-"+str(frame.playback_event.serial),requested)
		check(matched,"real action did not route to "+expected[action])
		check(live.to_dict()==committed,"phase sampling mutated authoritative state")
	check("impact_bloom" in runtime_roles and "ward_turn" in runtime_roles,"real hit/status layers missing")
	# Stress the same runtime resolver, not merely the pure per-cue cap.
	for key in board._stack_animation_cue_playback_records:
		var record:Dictionary=board._stack_animation_cue_playback_records[key]
		record.selected_vfx_cue_ids=[]
		for i in range(100): record.selected_vfx_cue_ids.append("vfx_placeholder_damage_tick")
	var crowded:Array=board._combat_vfx_layers(board._current_hex_layout(),board._stack_cells())
	check(crowded.size()==Motion.MAX_LAYERS_PER_FRAME,"runtime global layer cap not exercised")
	board.finish_action_playback(session)
	check(board._combat_vfx_layers(board._current_hex_layout(),board._stack_cells()).is_empty(),"effects survive playback completion")
	SettingsService.set_battle_playback_speed_id("instant")
	BattleRules.set_battle_presentation_speed(session,"instant")
	var skipped:Dictionary=shell._perform_action("defend")
	check(skipped.ok and not shell._action_playback_in_progress,"instant playback delayed")
	check(board._combat_vfx_layers(board._current_hex_layout(),board._stack_cells()).is_empty(),"instant playback leaves VFX")
	shell.queue_free()
	for i in range(3): await get_tree().process_frame
	print("BATTLE_READABILITY_REPORT "+JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures,"roles":roles_seen,"runtime_roles":runtime_roles,"runtime_cues":runtime_cues,"max_layers":max_layers,"stress_layers":crowded.size(),"pure_10000_cues_usec":motion_usec,"resolution":[requested.x,requested.y]}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''

def main():
    if '--platform' in sys.argv:
        import packaged_menu_and_turn_readability_regression as package
        package.ui = sys.modules[__name__]
        return package.main()
    runner.ROOT, runner.OUTPUT, runner.SCRIPT = ROOT, OUTPUT, SCRIPT
    runner.run_probe, runner.probe_environment = run_probe, probe_environment
    return runner.main()

if __name__ == '__main__':
    raise SystemExit(main())
