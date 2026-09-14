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
	return session
func capture(name:String)->void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	var image:=get_viewport().get_texture().get_image()
	check(image.get_size()==requested,"capture size mismatch")
	image.save_png(out.path_join(name+".png"))
func _ready()->void:call_deferred("run")
func run()->void:
	out=OS.get_environment("BATTLE_READABILITY_OUT")
	var dims:=OS.get_environment("TOWN_OVERLAY_RESOLUTION").split("x")
	requested=Vector2i(int(dims[0]),int(dims[1]))
	SettingsService.set_reduced_motion_enabled(OS.get_environment("BATTLE_READABILITY_REDUCED")=="1")
	SettingsService.set_battle_playback_speed_id("normal")
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
		if Pose.has_authored_poses(animation):candidates.append(String(animation.unit_id))
	check(not candidates.is_empty(),"no authored pose candidates exercised")
	var selected:=OS.get_environment("BATTLE_POSE_UNIT")
	check(selected.is_empty() or selected in candidates,"unknown selected pose candidate: "+selected)
	for unit_id in candidates:
		if not selected.is_empty() and unit_id!=selected:continue
		var actions:=["strike","defend","lethal"]
		if ContentService.get_unit_animation(unit_id).get("pose_clips",{}).has("ranged"):actions.append("ranged")
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
				var state:String=board._animation_state_for_stack(actor)
				var animation:=ContentService.get_unit_animation(actor.unit_id)
				check(Pose.has_authored_poses(animation),"unmapped pose actor in fixture")
				check(board._animation_frame_region_for_stack(actor).has_area(),"event resolves empty pose: "+state)
				var identity:String=String(actor.unit_id)+"_"+state
				if not seen.has(identity):
					seen[identity]=true
					var record:Dictionary=board._animation_playback_record_for_stack(actor_id)
					var sample_at:=int(record.get("started_at_msec",Time.get_ticks_msec()))+int(record.get("max_duration_ms",1))*0.5
					var delay:=maxf(0.001,(sample_at-Time.get_ticks_msec())/1000.0)
					await get_tree().create_timer(delay).timeout
					check(board._animation_state_for_stack(actor)==state,"pose expired before midpoint capture: "+state)
					var sampled_region:String=str(board._animation_frame_region_for_stack(actor))
					if SettingsService.reduced_motion_enabled():
						check(sampled_region==str(Pose.region(animation,state,0.5,0,true)),"live reduced-motion pose ignored SettingsService: "+identity)
					await capture(unit_id+"_"+action+"_"+identity)
					var regions:=[]
					for progress in [0.0,0.5,1.0]:
						regions.append(str(Pose.region(animation,state,progress,300,false)))
					evidence.append({"fixture":unit_id,"action":action,"actor":actor.unit_id,"side":actor.side,"state":state,"regions":regions,"sampled_region":sampled_region,"duration_ms":record.get("max_duration_ms",0)})
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
					check(corpse.flip,"enemy corpse facing lost")
				check(corpse_found,"candidate's own persistent corpse missing: "+unit_id)
				await capture(unit_id+"_persistent-corpse")
				var resumed=Store.new_session_data()
				resumed.from_dict(session.to_dict().duplicate(true))
				board.finish_action_playback(resumed)
				var restored_ids:=[]
				for corpse in board._battle_corpse_entries(board._current_hex_layout()):restored_ids.append(corpse.battle_id)
				check(casualty_id in restored_ids,"exact casualty lost on save/resume")
			check(session.to_dict()==committed,"pose playback mutated committed state")
	shell.queue_free()
	for i in range(4):await get_tree().process_frame
	MusicAudio.stop_stinger()
	MusicAudio.stop_music("pose_probe_teardown")
	await get_tree().create_timer(0.15).timeout
	print("BATTLE_READABILITY_REPORT "+JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures,"selected_unit":selected,"pose_events":evidence,"scope":"selected or all original-art candidates, real move/melee/ranged/defend/death snapshots; not full roster acceptance"}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''


def main():
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
