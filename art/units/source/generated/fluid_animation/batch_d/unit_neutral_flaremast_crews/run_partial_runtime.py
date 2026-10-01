"""Exercise preserved attack and selected clean Flaremast actions together.

The shared fixture otherwise chooses a runtime unit only from replaced attack.
This wrapper tests each new authored action directly, with the unchanged legacy
attack used only for the actual shell input/focus/saved-state playback fixture.
"""
from pathlib import Path
import sys,json

ROOT = next(p for p in Path(__file__).resolve().parents if (p / 'project.godot').exists())
sys.path.insert(0, str(ROOT / 'tests'))
import fluid_creature_animation_regression as fixture

selected=json.loads((Path(__file__).resolve().parent/'handoff.json').read_bytes())['units'][0]['clips']
assert 'attack' not in selected,'Use the full shared fixture when replacing attack'
event_states={'hit':'hit_stagger','defend':'defend_brace','cast':'cast_support_anchor','death':'death_rout_remove'}
assert set(selected)<=set(event_states)
action_pairs='['+','.join('["'+clip+'","'+event_states[clip]+'"]' for clip in selected)+']'

needle = 'var attack_id:String=""'
assert fixture.SCRIPT.count(needle) == 1
fixture.SCRIPT = fixture.SCRIPT.replace(
    needle, 'var attack_id:String="unit_neutral_flaremast_crews"')
# The preserved legacy attack has three poses; capture each, not absent pose4.
fixture.SCRIPT = fixture.SCRIPT.replace('pose_index in [0,2,4]', 'pose_index in [0,1,2]')
# Omit the entire shared authored-attack block, which requires a new attack.
# The full unmodified fixture must still run when corrected attack is included.
start = fixture.SCRIPT.index('\tif not attack_id.is_empty():\n')
end = fixture.SCRIPT.index('\tboard.queue_free()', start)
fixture.SCRIPT = fixture.SCRIPT[:start] + fixture.SCRIPT[end:]
# The real shell paints the preserved legacy attack using normalized progress.
fixture.SCRIPT = fixture.SCRIPT.replace(
    'var pose_index:int=Pose.timed_frame(ContentService.get_unit_animation(attack_id).pose_clips.attack,Pose.elapsed_msec(record,Time.get_ticks_msec()))',
    'var pose_index:int=clampi(int(float(Pose.elapsed_msec(record,Time.get_ticks_msec()))/maxi(1,int(record.max_duration_ms))*3),0,2)')
new_actions = r'''
	# Explicitly exercise each actual new authored clip in all presentation modes.
	for mode in ["normal","fast"]:
		for reduced in [false,true]:
			SettingsService.set_reduced_motion_enabled(reduced)
			for pair in SELECTED_ACTION_PAIRS:
				var session=fixture();session.battle.stacks[0].unit_id=attack_id;session.battle[BattleRules.PRESENTATION_SPEED_KEY]=mode
				var initial:Dictionary=session.to_dict().duplicate(true)
				var event:Dictionary={"event_id":"battle_unit_"+pair[0],"state":pair[1],"battle_id":session.battle.stacks[0].battle_id,"serial":2000000}
				var snap:Dictionary=session.battle.duplicate(true);snap.playback_event=event;snap.battle_animation_events=[event];snap.stack_animation_states={event.battle_id:event}
				board.set_battle_presentation_snapshot(snap)
				var record:Dictionary=board._animation_playback_record_for_stack(event.battle_id)
				var row:Dictionary=ContentService.get_unit_animation(attack_id);var spec:Dictionary=row.pose_clips[pair[0]]
				var duration:int=mini(Pose.clip_duration_msec(spec),260) if reduced else Pose.clip_duration_msec(spec)
				check(record.base_duration_ms==duration,"new action duration "+pair[0]+"/"+mode+str(reduced))
				check(record.max_duration_ms==board._presentation_duration_msec(duration),"new action speed "+pair[0]+"/"+mode+str(reduced))
				if reduced:
					var expected:Rect2=Pose.region(row,pair[1],0.0,0,true)
					check(Pose.region(row,pair[1],1.0,99999,true)==expected,"reduced motion changes new action frame "+pair[0])
				else:
					var elapsed:=0
					for i in range(spec.frames):
						check(Pose.timed_frame(spec,elapsed)==i,"new runtime authored frame "+pair[0]+str(i))
						elapsed+=int(spec.get("frame_msec",35))
				if pair[0]=="death":
					check(Pose.region(row,pair[1],1.0,99999,false,true)==Pose.region(row,pair[1],1.0,Pose.clip_duration_msec(spec),false),"corpse differs from last death frame")
				if mode=="normal" and not reduced and DisplayServer.get_name()!="headless":
					DisplayServer.window_set_size(Vector2i(1280,720));get_tree().root.size=Vector2i(1280,720);get_tree().root.content_scale_size=Vector2i(1280,720)
					var now:=Time.get_ticks_msec()
					var elapsed:int=Pose.clip_duration_msec(spec)-1 if pair[0]=="death" else int(Pose.clip_duration_msec(spec)*.5)
					board._stack_animation_playback_records[event.battle_id].started_at_msec=now-elapsed
					board._stack_animation_playback_records[event.battle_id].expires_at_msec=now+1000
					board._stack_animation_playback_until_msec[event.battle_id]=now+1000
					board.queue_redraw()
					(await capture()).save_png(OS.get_environment("FLUID_OUTPUT").path_join("board-new-"+pair[0]+".png"))
				check(session.to_dict()==initial,"new action presentation changed save "+pair[0])
				board.finish_action_playback(session)
				check(board._stack_animation_playback_records.is_empty(),"new action finish retained clock "+pair[0])
'''
new_actions=new_actions.replace('SELECTED_ACTION_PAIRS',action_pairs)
fixture.SCRIPT = fixture.SCRIPT.replace('\tboard.queue_free()', new_actions + '\n\tboard.queue_free()')
raise SystemExit(fixture.main())
