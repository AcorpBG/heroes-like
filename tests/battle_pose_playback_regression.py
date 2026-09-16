#!/usr/bin/env python3
"""Play real combat snapshots through authored poses, including lethal actions.

Python owns this driver. The embedded probe exercises live GDScript owners and
captures their rendering; no synthetic character drawing or animation fixtures.
"""
import os
import sys
import battle_readability_regression as runner

ROOT = runner.ROOT
OUTPUT = ROOT / '.artifacts/battle-unit-animation-size-20260913'
run_probe = runner.run_probe
probe_environment = runner.probe_environment
COMPILED_OWNERS = ('scenes/battle/BattleBoardView.gdc', 'scripts/ui/BattleUnitPose.gdc',
                  'scripts/core/BattleRules.gdc', 'scripts/core/BattleFootprint.gdc',
                  'scripts/ui/CombatVfxMotion.gdc')
SCRIPT = runner.SCRIPT.split('func _ready()')[0] + r'''
const Pose=preload("res://scripts/ui/BattleUnitPose.gd")
var evidence:=[]
var requested:=Vector2i(1280,720)
func pose_fixture(unit_id:String,lethal:bool=false,ranged:bool=false):
	var session=fixture()
	var other:="unit_embercourt_sluicefire_lindworms" if unit_id=="unit_river_guard" else "unit_river_guard"
	if lethal:other=unit_id
	for index in range(3):
		var old:Dictionary=session.battle.stacks[index]
		var unit:=unit_id if index==0 else other
		var stack:=BattleRules._build_battle_stack(unit,10,"player" if index==0 else "enemy",index)
		stack.battle_id=old.battle_id
		stack.hex={"q":3 if index==0 else (7 if index==1 else 9),"r":3 if index<2 else 5}
		stack.abilities=[]
		stack.speed=5
		stack.total_health=1 if lethal and index==1 else 4000
		stack.unit_hp=100
		stack.base_count=40
		stack.ranged=ranged and index==0
		session.battle.stacks[index]=stack
	BattleRules._sync_occupied_hexes(session.battle)
	BattleRules._sync_distance_from_hexes(session.battle)
	BattleRules.set_battle_presentation_speed(session,"fast" if OS.get_environment("BATTLE_POSE_SPEED")=="fast" else "normal")
	return session
func capture(name:String, deferred_images:Array=[])->void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	var image:=get_viewport().get_texture().get_image()
	check(image.get_size()==requested,"capture size mismatch")
	if deferred_images.is_empty():
		image.save_png(out.path_join(name+".png"))
	else:
		deferred_images.append({"name":name,"image":image})
func set_headless_clock(board:Control,actor_id:String,record:Dictionary,started:int)->void:
	if record.is_empty():return
	var duration:=maxi(1,int(record.get("max_duration_ms",1)))
	record.started_at_msec=started
	record.expires_at_msec=started+duration
	for records in [board._stack_animation_playback_records,board._stack_animation_cue_playback_records,board._stack_animation_audio_playback_records]:
		if records.has(actor_id):
			records[actor_id].started_at_msec=started
			records[actor_id].expires_at_msec=started+duration
	board._stack_animation_playback_until_msec[actor_id]=started+duration
func sample_headless_clock(board:Control,actor_id:String,record:Dictionary,progress:float)->void:
	# Headless Wine has no displayed frames. Sampling its 109ms Fast cues with
	# OS timers tests scheduler contention, not reduced-motion frame selection.
	# Rebase only the existing presentation clocks, preserving real durations,
	# state, source event and saved simulation. Rendered runs keep wall time.
	if record.is_empty():return
	var duration:=maxi(1,int(record.get("max_duration_ms",1)))
	var elapsed:=clampi(int(duration*progress),0,duration-1)
	set_headless_clock(board,actor_id,record,Time.get_ticks_msec()-elapsed)
func _ready()->void:call_deferred("run")
func run()->void:
	out=OS.get_environment("BATTLE_READABILITY_OUT")
	var dims:=OS.get_environment("TOWN_OVERLAY_RESOLUTION").split("x")
	requested=Vector2i(int(dims[0]),int(dims[1]))
	SettingsService.set_reduced_motion_enabled(OS.get_environment("BATTLE_READABILITY_REDUCED")=="1")
	SettingsService.set_battle_playback_speed_id("fast" if OS.get_environment("BATTLE_POSE_SPEED")=="fast" else "normal")
	var live=SessionState.set_active_session(pose_fixture("unit_river_guard"))
	var shell=load("res://scenes/battle/BattleShell.tscn").instantiate()
	add_child(shell)
	for i in range(8):await get_tree().process_frame
	if DisplayServer.get_name()!="headless":DisplayServer.window_set_size(requested)
	get_tree().root.size=requested
	get_tree().root.content_scale_size=requested
	for i in range(4):await get_tree().process_frame
	var board:Control=shell._battle_board_view
	var candidates:=[]
	var manifest:Dictionary=ContentService.load_json("res://content/unit_animation_manifest.json")
	for animation in manifest.get("items",[]):
		if Pose.has_authored_poses(animation):
			check(String(animation.get("pose_source_facing","right")) in ["left","right"],"invalid pose source facing: "+String(animation.unit_id))
			candidates.append(String(animation.unit_id))
	check(not candidates.is_empty(),"no authored pose candidates exercised")
	var selected:=OS.get_environment("BATTLE_POSE_UNIT")
	check(selected.is_empty() or selected in candidates,"unknown selected pose candidate: "+selected)
	for unit_id in candidates:
		if not selected.is_empty() and unit_id!=selected:continue
		var checks_before:int=checks
		var failures_before:int=failures.size()
		var events_before:int=evidence.size()
		var actions:=["strike","defend","lethal"]
		# Authored spellcasters can route ranged to a dedicated cast clip.
		# Test every ranged gameplay identity, not only direct manifest keys.
		if bool(ContentService.get_unit(unit_id).get("ranged",false)):actions.append("ranged")
		for action in actions:
			var session=pose_fixture(unit_id,action=="lethal",action=="ranged")
			var reference=Store.new_session_data()
			reference.from_dict(session.to_dict().duplicate(true))
			var intent:="defend" if action=="defend" else ("shoot" if action=="ranged" else "strike")
			var result:=BattleRules.perform_presented_action(session,intent)
			var direct:=BattleRules.perform_player_action(reference,intent)
			check(result.ok and direct.ok,"pose fixture action failed: "+unit_id+" "+action)
			check(session.to_dict()==reference.to_dict(),"pose presentation changed deterministic action")
			var committed:Dictionary=session.to_dict().duplicate(true)
			var display_session=Store.new_session_data()
			display_session.from_dict(committed.duplicate(true))
			shell._session=display_session
			shell._refresh()
			var seen:={}
			for frame in result.get("playback_frames",[]):
				board.set_battle_presentation_snapshot(frame)
				var event:Dictionary=frame.get("playback_event",{})
				var actor_id:=String(event.get("battle_id",""))
				var actor:=BattleRules._get_stack_by_id(frame,actor_id)
				if actor.is_empty():continue
				var record:Dictionary
				if DisplayServer.get_name()=="headless":
					# Control time before calling the expiring getter, not only
					# before the midpoint. Preserve queued-reaction delays for
					# the pre-start assertions below; never invent a lost event.
					record=board._stack_animation_playback_records.get(actor_id,{}).duplicate(true)
					set_headless_clock(board,actor_id,record,Time.get_ticks_msec()+int(record.get("sequence_delay_msec",0)))
				else:
					record=board._animation_playback_record_for_stack(actor_id)
				var state:String=String(record.get("state",board._animation_state_for_stack(actor)))
				var animation:=ContentService.get_unit_animation(actor.unit_id)
				check(Pose.has_authored_poses(animation),"unmapped pose actor in fixture")
				check(board._animation_frame_region_for_stack(actor).has_area(),"event resolves empty pose: "+state)
				if Pose.waiting_for_start(record,Time.get_ticks_msec()):
					check(board._animation_state_for_stack(actor)==board._fallback_animation_state_for_stack(actor),"queued event changes pose before reaction starts: "+state)
					if state=="death_rout_remove":
						for corpse in board._battle_corpse_entries(board._current_hex_layout()):
							check(corpse.battle_id!=actor_id,"queued death already exposes final corpse")
				var identity:String=String(actor.unit_id)+"_"+state
				if not seen.has(identity):
					seen[identity]=true
					if OS.get_environment("BATTLE_POSE_SPEED")=="fast" and not record.is_empty():
						check(int(record.get("max_duration_ms",0))==maxi(1,int(round(float(record.get("base_duration_ms",0))*0.42))),"live Fast action did not retain original/scaled pose clock: "+identity)
					var sample_points:=[0.5]
					if OS.get_environment("BATTLE_POSE_MOTION_SAMPLES")=="1" and actor.unit_id==unit_id and state=="move_path_step" and action=="strike":
						sample_points=[0.1,0.3,0.5,0.7,0.9]
					var sampled_region:String=""
					var motion_samples:=[]
					# PNG compression must not consume the next pose's capture window.
					var deferred_images:Array=[null] if sample_points.size()>1 else []
					for sample_progress in sample_points:
						if DisplayServer.get_name()=="headless":
							sample_headless_clock(board,actor_id,record,sample_progress)
						else:
							var sample_at:float=int(record.get("started_at_msec",Time.get_ticks_msec()))+int(record.get("max_duration_ms",1))*float(sample_progress)
							var delay:=maxf(0.001,(sample_at-Time.get_ticks_msec())/1000.0)
							await get_tree().create_timer(delay).timeout
						check(board._animation_state_for_stack(actor)==state,"pose expired before live capture: "+state)
						var current_region:String=str(board._animation_frame_region_for_stack(actor))
						if sample_progress==0.5:sampled_region=current_region
						if SettingsService.reduced_motion_enabled():
							check(current_region==str(Pose.region(animation,state,sample_progress,0,true)),"live reduced-motion pose ignored SettingsService: "+identity)
						var suffix:="" if sample_progress==0.5 else "_motion_%02d"%int(sample_progress*100)
						var captured_actor:bool=actor.unit_id==unit_id and DisplayServer.get_name()!="headless"
						motion_samples.append({"progress":sample_progress,"elapsed_ms":Time.get_ticks_msec()-int(record.get("started_at_msec",0)),"region":current_region,"capture_suffix":suffix,"captured":captured_actor})
						# Every actor still receives identical timing/routing checks.
						# Do not write thousands of duplicate River Guard opponent
						# PNGs; its own fixture covers that identity on both sides.
						if actor.unit_id==unit_id:
							await capture(unit_id+"_"+action+"_"+identity+suffix,deferred_images)
					for captured in deferred_images:
						if captured!=null:captured.image.save_png(out.path_join(captured.name+".png"))
					var regions:=[]
					for progress in [0.0,0.5,1.0]:
						var tick:=int(record.get("started_at_msec",0))+int(progress*int(record.get("max_duration_ms",1)))
						regions.append(str(Pose.region(animation,state,progress,Pose.elapsed_msec(record,tick),false)))
					evidence.append({"fixture":unit_id,"action":action,"actor":actor.unit_id,"side":actor.side,"state":state,"regions":regions,"sampled_region":sampled_region,"motion_samples":motion_samples,"duration_ms":record.get("max_duration_ms",0)})
			if action=="ranged":
				check(seen.has(unit_id+"_ranged_aim_release"),unit_id+" never used dedicated ranged pose")
				var archer_animation:=ContentService.get_unit_animation(unit_id)
				check(Pose.clip(archer_animation,"ranged_aim_release")!=Pose.clip(archer_animation,"melee_windup_release"),"archer ranged and melee clips were aliased")
			board.finish_action_playback(session)
			if action=="lethal":
				check(seen.has(unit_id+"_death_rout_remove"),"candidate's own death clip was not played: "+unit_id)
				var casualty_id:String=session.battle.stacks[1].battle_id
				var corpse_found:=false
				for corpse in board._battle_corpse_entries(board._current_hex_layout()):
					if corpse.battle_id!=casualty_id:continue
					corpse_found=true
					var animation:=ContentService.get_unit_animation(unit_id)
					check(corpse.texture.resource_path==animation.pose_sheet,"casualty uses another unit's art")
					check(corpse.region==Pose.region(animation,"death_rout_remove",1.0,0,false,true),"casualty not using final dead frame")
					var casualty:=BattleRules._get_stack_by_id(session.battle,casualty_id)
					var layout:Dictionary=board._current_hex_layout()
					var cell:Vector2i=board._stack_hex_cell(casualty)
					var center:Vector2=board._hex_center(cell,layout)+board._body_center_offset(casualty,cell,layout)
					var expected_ground:float=center.y+float(layout.radius)*board.STACK_STANDEE_GROUND_OFFSET_FACTOR
					var authored_line:float=corpse.rect.position.y+corpse.rect.size.y*(1.0-float(animation.get("pose_ground_margin",0))/float(animation.pose_frame_size.height))
					check(is_equal_approx(authored_line,expected_ground),"corpse uses transparent canvas padding instead of authored ground line")
					check(corpse.flip==(String(animation.get("pose_source_facing","right"))!="left"),"enemy corpse source-facing transform lost")
				check(corpse_found,"candidate's own persistent corpse missing: "+unit_id)
				await capture(unit_id+"_persistent-corpse")
				var resumed=Store.new_session_data()
				resumed.from_dict(session.to_dict().duplicate(true))
				board.finish_action_playback(resumed)
				var restored_ids:=[]
				for corpse in board._battle_corpse_entries(board._current_hex_layout()):restored_ids.append(corpse.battle_id)
				check(casualty_id in restored_ids,"exact casualty lost on save/resume")
			check(session.to_dict()==committed,"pose playback mutated committed state")
		# Emit only after every action, own corpse and save/resume assertion.
		# An interrupted roster retains exact completed-unit outcomes; screenshots
		# alone and a partial checkpoint stream never constitute a passing run.
		print("BATTLE_POSE_UNIT_REPORT "+JSON.stringify({"unit_id":unit_id,"ok":failures.size()==failures_before,"checks":checks-checks_before,"failures":failures.slice(failures_before),"pose_events":evidence.slice(events_before)}))
	shell.queue_free()
	for i in range(4):await get_tree().process_frame
	MusicAudio.stop_stinger()
	MusicAudio.stop_music("pose_probe_teardown")
	await get_tree().create_timer(0.15).timeout
	print("BATTLE_READABILITY_REPORT "+JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures,"selected_unit":selected,"pose_events":evidence,"clock_mode":"controlled_headless" if DisplayServer.get_name()=="headless" else "realtime_rendered","scope":"selected or all original-art candidates, real move/melee/ranged/defend/death snapshots; not full roster acceptance"}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''


def main():
    if '--motion-samples' in sys.argv:
        os.environ['BATTLE_POSE_MOTION_SAMPLES'] = '1'
        sys.argv.remove('--motion-samples')
    if '--pose-speed' in sys.argv:
        index = sys.argv.index('--pose-speed')
        if index + 1 >= len(sys.argv) or sys.argv[index + 1] not in ('normal', 'fast'):
            raise SystemExit('--pose-speed requires normal or fast')
        os.environ['BATTLE_POSE_SPEED'] = sys.argv[index + 1]
        del sys.argv[index:index + 2]
    if '--unit' in sys.argv:
        index = sys.argv.index('--unit')
        if index + 1 >= len(sys.argv):
            raise SystemExit('--unit requires an exact candidate unit_id')
        os.environ['BATTLE_POSE_UNIT'] = sys.argv[index + 1]
        del sys.argv[index:index + 2]
    if '--platform' in sys.argv:
        import packaged_menu_and_turn_readability_regression as package
        package.ui = sys.modules[__name__]
        return package.main()
    runner.ROOT, runner.OUTPUT, runner.SCRIPT = ROOT, OUTPUT, SCRIPT
    runner.run_probe, runner.probe_environment = run_probe, probe_environment
    return runner.main()


if __name__ == '__main__':
    raise SystemExit(main())
