"""Focused authored-frame timing, contact overlap and unchanged simulation checks.

Candidate patches may be tested before catalog publication. This does not confer
visual acceptance: the coordinator must inspect actual original clip motion.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile
import sys
import hashlib
import time

from battle_readability_regression import SCRIPT as BASE

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = BASE.split("func _ready()")[0] + r'''
const Pose=preload("res://scripts/ui/BattleUnitPose.gd")
const Board=preload("res://scenes/battle/BattleBoardView.gd")
const Idle=preload("res://scenes/overworld/OverworldCreatureIdle.gd")
const Batch=preload("res://scenes/overworld/OverworldSceneryBatch.gd")
func capture()->Image:
	for i in range(3):await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()
class ContactSheet extends Control:
	var row:Dictionary
	var clip_name:String
	var sheet:Texture2D
	func _draw():
		draw_rect(Rect2(0,0,1280,400),Color(.12,.16,.1))
		var spec:Dictionary=row.pose_clips[clip_name]
		var states:Dictionary={"idle":"idle_hold","attack":"melee_windup_release","move":"move_path_step","hit":"hit_stagger","death":"death_rout_remove","defend":"defend_brace","ranged":"ranged_aim_release","cast":"cast_support_anchor"}
		var elapsed:=0
		for i in range(spec.frames):
			var region:Rect2=Pose.region(row,states.get(clip_name,"idle_hold"),float(i)/spec.frames,elapsed,false,clip_name=="dead")
			for sample in range(2):
				var ground:=Vector2(75+i*155,195+sample*135)
				var rect:Rect2=Pose.grounded_rect(ground,128 if sample==0 else 64,region,row)
				draw_line(ground-Vector2(65,0),ground+Vector2(65,0),Color(.5,.5,.3))
				draw_texture_rect_region(sheet,rect,region)
				draw_string(ThemeDB.fallback_font,ground+Vector2(-30,23),str(i+1)+" / "+str(elapsed)+"ms",HORIZONTAL_ALIGNMENT_LEFT,-1,13)
			elapsed+=int(spec.frame_durations_msec[i]) if spec.has("frame_durations_msec") else int(spec.frame_msec)
		draw_string(ThemeDB.fallback_font,Vector2(10,22),row.unit_id+" / "+clip_name+" / battle128 and map64 ground scale",HORIZONTAL_ALIGNMENT_LEFT,-1,18)
class Overview extends Control:
	var row:Dictionary
	var names:Array
	var sheet:Texture2D
	var existing_idle:bool=false
	func cell_width()->int:return maxi(155,ceili(float(row.pose_frame_size.width)*128.0/float(row.get("pose_reference_height",row.pose_frame_size.height)))+20)
	func columns()->int:return 8 if cell_width()*8<=4096 else maxi(1,mini(4,4096/cell_width()))
	func canvas_size()->Vector2i:
		var rows:=0
		for name in names:rows+=ceili(float(row.pose_clips[name].frames)/columns())
		return Vector2i(cell_width()*columns(),190*rows+35)
	func _draw():
		draw_rect(Rect2(Vector2.ZERO,Vector2(canvas_size())),Color(.12,.16,.1))
		draw_string(ThemeDB.fallback_font,Vector2(10,22),row.unit_id+" / actual 128px reference height",HORIZONTAL_ALIGNMENT_LEFT,-1,18)
		var states:Dictionary={"idle":"idle_hold","attack":"melee_windup_release","move":"move_path_step","hit":"hit_stagger","death":"death_rout_remove","defend":"defend_brace","ranged":"ranged_aim_release","cast":"cast_support_anchor"}
		var used_rows:=0
		for r in range(names.size()):
			var name:String=names[r];var spec:Dictionary=row.pose_clips[name];var elapsed:=0
			draw_string(ThemeDB.fallback_font,Vector2(10,48+used_rows*190),"idle (existing; review retention)" if name=="idle" and existing_idle else name,HORIZONTAL_ALIGNMENT_LEFT,-1,15)
			for i in range(spec.frames):
				var ground:=Vector2(cell_width()*.5+(i%columns())*cell_width(),185+(used_rows+i/columns())*190)
				var region:Rect2=Pose.region(row,states.get(name,"idle_hold"),float(i)/spec.frames,elapsed,false,name=="dead")
				var rect:Rect2=Pose.grounded_rect(ground,128,region,row)
				draw_line(ground-Vector2(65,0),ground+Vector2(65,0),Color(.5,.5,.3))
				draw_texture_rect_region(sheet,rect,region)
				draw_string(ThemeDB.fallback_font,ground+Vector2(-25,17),str(i+1)+" / "+str(elapsed),HORIZONTAL_ALIGNMENT_LEFT,-1,12)
				elapsed+=int(spec.frame_durations_msec[i]) if spec.has("frame_durations_msec") else int(spec.frame_msec)
			used_rows+=ceili(float(spec.frames)/columns())
func _ready(): call_deferred("run")
func run():
	var patch:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("FLUID_PATCH")))
	var manifest:Dictionary=ContentService.load_json(ContentService.UNIT_ANIMATION_PATH).duplicate(true)
	for change in patch.units:
		for i in range(manifest.items.size()):
			if manifest.items[i].unit_id==change.unit_id:manifest.items[i]=change.animation
	ContentService.clear_cache();ContentService._cache[ContentService.UNIT_ANIMATION_PATH]=manifest
	if DisplayServer.get_name()!="headless":
		SettingsService.set_presentation_mode("windowed")
		DisplayServer.window_set_position(Vector2i(-16000,-16000));DisplayServer.window_set_size(Vector2i(1280,400))
		get_tree().root.size=Vector2i(1280,400);get_tree().root.content_scale_size=Vector2i(1280,400)
		for change in patch.units:
			var overview:=Overview.new();overview.row=change.animation;overview.names=change.replaced_clips.duplicate()
			if "idle" not in overview.names:
				overview.names.push_front("idle");overview.existing_idle=true
			var viewport:=SubViewport.new();viewport.size=overview.canvas_size();viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
			add_child(viewport)
			overview.sheet=load(change.animation.pose_sheet) if OS.get_environment("FLUID_LIVE")=="1" else ImageTexture.create_from_image(Image.load_from_file(change.animation.pose_sheet))
			viewport.add_child(overview)
			await RenderingServer.frame_post_draw
			viewport.get_texture().get_image().save_png(OS.get_environment("FLUID_OUTPUT").path_join(change.unit_id+"-overview.png"))
			viewport.queue_free();await get_tree().process_frame
			if OS.get_environment("FLUID_OVERVIEW_ONLY")=="1":continue
			for name in change.replaced_clips:
				var gallery:=ContactSheet.new();gallery.row=change.animation;gallery.clip_name=name
				gallery.sheet=load(change.animation.pose_sheet) if OS.get_environment("FLUID_LIVE")=="1" else ImageTexture.create_from_image(Image.load_from_file(change.animation.pose_sheet))
				add_child(gallery)
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(OS.get_environment("FLUID_OUTPUT").path_join(change.unit_id+"-"+name+".png"))
				gallery.queue_free();await get_tree().process_frame
		if OS.get_environment("FLUID_LIVE")=="1":
			var idle=Idle.new();idle.configure(ContentService.load_json("res://art/overworld/creature_idle.json"))
			for change in patch.units:
				var row:Dictionary=change.animation
				var imported:Texture2D=load(row.pose_sheet)
				check(imported.get_width()==row.pose_frame_size.width*row.pose_columns,"stale imported battle atlas "+change.unit_id)
				var canvas:=Control.new();canvas.size=Vector2(1280,400);add_child(canvas)
				var batch=Batch.new();batch.begin(canvas)
				batch.record(&"draw_rect",[Rect2(0,0,1280,400),Color(.12,.16,.1)])
				var pose:Dictionary=idle.payload(change.unit_id,Vector2(200,260),96)
				check(not pose.is_empty(),"published map sprite missing "+change.unit_id)
				if not pose.is_empty():
					var material=Idle.material(pose,change.unit_id,true)
					material.set_shader_parameter("phase",0.0);material.set_shader_parameter("clock_override",.001)
					batch.paint_material(pose.texture,pose.rect,Color.WHITE,material,{"kind":"creature_idle"});batch.finish()
					var first:Image=await capture()
					material.set_shader_parameter("clock_override",float(material.get_shader_parameter("frame_seconds"))*1.1)
					var second:Image=await capture()
					check(first.get_data()!=second.get_data(),"actual map shader has no frame motion "+change.unit_id)
					first.save_png(OS.get_environment("FLUID_OUTPUT").path_join(change.unit_id+"-map-idle-0.png"))
					second.save_png(OS.get_environment("FLUID_OUTPUT").path_join(change.unit_id+"-map-idle-1.png"))
					batch.set_motion_enabled(false)
					var still:Image=await capture()
					material.set_shader_parameter("clock_override",7.0)
					check(still.get_data()==(await capture()).get_data(),"map reduced motion changes pixels "+change.unit_id)
				canvas.queue_free();await get_tree().process_frame
	var board=Board.new();board.size=Vector2(1280,720);add_child(board)
	var attack_id:String=""
	var ranged_id:String=""
	for change in patch.units:
		var row:Dictionary=ContentService.get_unit_animation(change.unit_id)
		for name in change.replaced_clips:
			var spec:Dictionary=row.pose_clips[name]
			var time:=0
			var seen:=[]
			for i in range(spec.frames):
				check(Pose.timed_frame(spec,time)==i,"authored hold skipped pose "+change.unit_id+"/"+name+str(i))
				seen.append(i)
				time+=int(spec.frame_durations_msec[i]) if spec.has("frame_durations_msec") else int(spec.frame_msec)
			check(time==Pose.clip_duration_msec(spec),"clip duration differs from holds")
			check(Pose.timed_frame(spec,time)==(0 if spec.loop else spec.frames-1),"end frame/loop incorrect")
			if name=="attack":attack_id=change.unit_id
			if name=="ranged":ranged_id=change.unit_id
		var region:Rect2=Pose.region(row,"idle_hold",0,0,true)
		var rect:Rect2=Pose.grounded_rect(Vector2(500,400),128,region,row)
		check(is_equal_approx(rect.position.y+(region.size.y-row.pose_ground_margin)*128/row.pose_reference_height,400),"anatomical ground changed")
	if not ranged_id.is_empty():
		for mode in ["normal","fast"]:
			SettingsService.set_reduced_motion_enabled(false)
			var session=fixture();session.battle.stacks[0].unit_id=ranged_id;session.battle[BattleRules.PRESENTATION_SPEED_KEY]=mode
			var event:Dictionary={"event_id":"battle_unit_ranged_attack","state":"ranged_aim_release","battle_id":session.battle.stacks[0].battle_id,"target_battle_id":session.battle.stacks[1].battle_id,"serial":1000000}
			var snapshot:Dictionary=session.battle.duplicate(true);snapshot.playback_event=event;snapshot.battle_animation_events=[event];snapshot.stack_animation_states={event.battle_id:event}
			board.set_battle_presentation_snapshot(snapshot)
			var record:Dictionary=board._animation_playback_record_for_stack(event.battle_id)
			var cue:Dictionary=board._stack_animation_cue_playback_records[event.battle_id]
			var spec:Dictionary=ContentService.get_unit_animation(ranged_id).pose_clips.ranged
			var flight:int=board._presentation_duration_msec(int(spec.get("projectile_travel_msec",180)))
			check(record.impact_at_msec-cue.audio_started_at_msec==flight,"ranged hit not delayed until projectile arrival")
			check(cue.vfx_started_at_msec==cue.audio_started_at_msec and cue.vfx_duration_msec==flight,"projectile/audio release disagree")
			check(record.expires_at_msec>record.impact_at_msec,"projectile clock expired before impact")
			board.finish_action_playback(session)
	if not attack_id.is_empty():
		var row:Dictionary=ContentService.get_unit_animation(attack_id)
		for mode in ["normal","fast"]:
			for reduced in [false,true]:
				SettingsService.set_reduced_motion_enabled(reduced)
				var session=fixture()
				for i in range(2):session.battle.stacks[i].unit_id=attack_id
				session.battle[BattleRules.PRESENTATION_SPEED_KEY]=mode
				var initial:Dictionary=session.to_dict().duplicate(true)
				var attack:Dictionary={"event_id":"battle_unit_melee_attack","state":"melee_windup_release","battle_id":session.battle.stacks[0].battle_id,"target_battle_id":session.battle.stacks[1].battle_id,"serial":1000000}
				var hit:Dictionary={"event_id":"battle_unit_hit","state":"hit_stagger","battle_id":session.battle.stacks[1].battle_id,"source_battle_id":session.battle.stacks[0].battle_id,"serial":1000001}
				var snap:Dictionary=session.battle.duplicate(true)
				snap.playback_event=attack;snap.battle_animation_events=[attack];snap.stack_animation_states={attack.battle_id:attack}
				board.set_battle_presentation_snapshot(snap)
				var record:Dictionary=board._animation_playback_record_for_stack(attack.battle_id)
				var duration:int=mini(Pose.clip_duration_msec(row.pose_clips.attack),260) if reduced else Pose.clip_duration_msec(row.pose_clips.attack)
				check(record.base_duration_ms==duration,"board truncated authored clip")
				check(record.max_duration_ms==board._presentation_duration_msec(duration),"speed mismatch")
				# The shell waits for the remaining interval, not the original
				# duration. Bound its clock sample to avoid setup-time flakes.
				var wait_before:int=Time.get_ticks_msec()
				var remaining_wait:int=board.action_playback_wait_msec()
				var wait_after:int=Time.get_ticks_msec()
				var minimum_wait:int=maxi(1,int(record.expires_at_msec)-wait_after)+16
				var maximum_wait:int=maxi(1,int(record.expires_at_msec)-wait_before)+16
				check(remaining_wait>=minimum_wait and remaining_wait<=maximum_wait,"shell wait does not match remaining animation deadline")
				check(board.can_overlap_action_contact(hit)==not reduced,"contact overlap policy")
				if not reduced:
					var contact_wait:int=board.action_playback_wait_msec(true)
					check(contact_wait<=record.max_duration_ms and contact_wait>0,"contact not inside clip")
					var cue:Dictionary=board._stack_animation_cue_playback_records[attack.battle_id]
					check(cue.audio_started_at_msec==record.impact_at_msec and cue.vfx_started_at_msec==record.impact_at_msec,"audio/VFX not aligned to melee contact")
					snap.playback_event=hit;snap.battle_animation_events=[hit];snap.stack_animation_states={hit.battle_id:hit}
					board.set_battle_presentation_snapshot(snap,true)
					check(not board._animation_playback_record_for_stack(attack.battle_id).is_empty(),"reaction deleted attack recovery")
					check(board._animation_playback_record_for_stack(hit.battle_id).sequence_delay_msec==0,"contact reaction delayed twice")
					var death:Dictionary=hit.duplicate(true);death.event_id="battle_unit_death";death.state="death_rout_remove";death.serial+=1
					check(board.can_overlap_action_contact(death) and board.action_playback_wait_msec(true)==1,"hit/death contact group serialized unnecessarily")
					snap.playback_event=death;snap.battle_animation_events=[death];snap.stack_animation_states={death.battle_id:death}
					board.set_battle_presentation_snapshot(snap,true)
					check(not board._animation_playback_record_for_stack(attack.battle_id).is_empty(),"death cleared unfinished attacker recovery")
					var splash:Dictionary=hit.duplicate(true);splash.battle_id=session.battle.stacks[2].battle_id;splash.serial+=2
					check(board.can_overlap_action_contact(splash),"secondary AoE target not grouped at same contact")
					var self_status:Dictionary=hit.duplicate(true);self_status.battle_id=attack.battle_id;self_status.event_id="battle_status_applied";self_status.state="status_applied";self_status.serial+=3
					snap.playback_event=self_status;snap.battle_animation_events=[self_status];snap.stack_animation_states={self_status.battle_id:self_status}
					board.set_battle_presentation_snapshot(snap,true)
					check(board._animation_playback_record_for_stack(attack.battle_id).state==attack.state,"self status cut active action recovery poses")
					var self_death:Dictionary=self_status.duplicate(true);self_death.event_id="battle_unit_death";self_death.state="death_rout_remove";self_death.serial+=1
					snap.playback_event=self_death;snap.battle_animation_events=[self_death];snap.stack_animation_states={self_death.battle_id:self_death}
					board.set_battle_presentation_snapshot(snap,true)
					check(board._animation_playback_record_for_stack(attack.battle_id).state=="death_rout_remove","self death incorrectly retained action recovery")
					if row.pose_clips.get("cast",{}).get("authored_timing",false) and row.pose_clips.cast.has("contact_frame"):
						var cast_event:Dictionary=attack.duplicate(true);cast_event.event_id="battle_unit_cast";cast_event.state="cast_support_anchor";cast_event.serial=self_death.serial+1
						snap.playback_event=cast_event;snap.battle_animation_events=[cast_event];snap.stack_animation_states={cast_event.battle_id:cast_event}
						board.set_battle_presentation_snapshot(snap)
						self_status.serial=cast_event.serial+1
						snap.playback_event=self_status;snap.battle_animation_events=[self_status];snap.stack_animation_states={self_status.battle_id:self_status}
						board.set_battle_presentation_snapshot(snap,true)
						check(board._animation_playback_record_for_stack(attack.battle_id).state=="cast_support_anchor","self buff cut actual cast recovery")
				check(session.to_dict()==initial,"presentation modified session/save")
				var status:Dictionary=attack.duplicate(true);status.event_id="battle_status_applied";status.state="status_applied"
				snap.playback_event=status;snap.battle_animation_events=[status];snap.stack_animation_states={status.battle_id:status}
				board.set_battle_presentation_snapshot(snap)
				var status_cue:Dictionary=board._animation_cue_playback_record_for_event(status)
				check(board._animation_playback_record_for_stack(status.battle_id).base_duration_ms==int(status_cue.get("max_duration_ms",700)),"status fallback incorrectly inherited whole idle cycle duration")
				if row.pose_clips.get("move",{}).get("authored_timing",false):
					var movement:Dictionary=attack.duplicate(true);movement.event_id="battle_unit_move";movement.state="move_path_step";movement.walk_path=[{"q":1,"r":1},{"q":2,"r":1},{"q":3,"r":1},{"q":4,"r":1}]
					snap.playback_event=movement;snap.battle_animation_events=[movement];snap.stack_animation_states={movement.battle_id:movement}
					board.set_battle_presentation_snapshot(snap)
					var expected:int=Pose.clip_duration_msec(row.pose_clips.move)*3
					if reduced:expected=mini(expected,260)
					check(board._animation_playback_record_for_stack(movement.battle_id).base_duration_ms==expected,"multihex move does not loop one gait per step")
				board.finish_action_playback(session)
				check(board._stack_animation_playback_records.is_empty(),"finish left contact clock active")
		# Real committed actions remain exactly equivalent to nonpresented rules.
		var presented=fixture();presented.battle.stacks[0].unit_id=attack_id
		var direct=Store.new_session_data();direct.from_dict(presented.to_dict().duplicate(true))
		var result:Dictionary=BattleRules.perform_presented_action(presented,"strike")
		var plain:Dictionary=BattleRules.perform_player_action(direct,"strike")
		check(result.get("ok",false)==plain.get("ok",false) and presented.to_dict()==direct.to_dict(),"authored playback changed simulation")
	board.queue_free()
	if DisplayServer.get_name()!="headless" and not attack_id.is_empty() and OS.get_environment("FLUID_CONTACTS_ONLY")!="1":
		SettingsService.set_reduced_motion_enabled(false)
		SettingsService.set_battle_playback_speed_id("normal")
		var rendered=SessionState.set_active_session(fixture())
		for stack in rendered.battle.stacks:
			stack.unit_hp=100000;stack.total_health=2000000;stack.base_count=20
		rendered.battle.stacks[0].unit_id=attack_id
		rendered.battle.stacks[0].name=ContentService.get_unit(attack_id).name
		var shell=load("res://scenes/battle/BattleShell.tscn").instantiate()
		add_child(shell)
		for i in range(8):await get_tree().process_frame
		DisplayServer.window_set_position(Vector2i(-16000,-16000));DisplayServer.window_set_size(Vector2i(1280,720))
		get_tree().root.size=Vector2i(1280,720);get_tree().root.content_scale_size=Vector2i(1280,720)
		var action:Dictionary=shell._perform_action("strike")
		shell._validation_battle_resolution_routing_enabled=false
		check(action.get("ok",false) and shell._action_playback_in_progress,"actual shell did not schedule action")
		var committed:Dictionary=rendered.to_dict().duplicate(true)
		check(not shell._perform_action("defend").get("ok",false),"shell accepted input mid animation")
		var deadline:=Time.get_ticks_msec()+20000
		var capture_count:=0
		var seen_attack_frames:=[]
		while shell._action_playback_in_progress and Time.get_ticks_msec()<deadline:
			await get_tree().process_frame
			var current:Dictionary=shell._battle_board_view._battle
			if not shell._battle_board_view._animation_playback_record_for_stack(rendered.battle.stacks[0].battle_id).is_empty():
				var record:Dictionary=shell._battle_board_view._animation_playback_record_for_stack(rendered.battle.stacks[0].battle_id)
				if not record.is_empty() and record.get("event_id","")=="battle_unit_melee_attack":
					var pose_index:int=Pose.timed_frame(ContentService.get_unit_animation(attack_id).pose_clips.attack,Pose.elapsed_msec(record,Time.get_ticks_msec()))
					if pose_index not in seen_attack_frames:seen_attack_frames.append(pose_index)
					if capture_count<3 and pose_index in [0,2,4]:
						await RenderingServer.frame_post_draw
						get_viewport().get_texture().get_image().save_png(OS.get_environment("FLUID_OUTPUT").path_join("battle-phase-"+str(capture_count)+".png"))
						capture_count+=1
		check(not shell._action_playback_in_progress,"shell animation queue did not finish")
		check(rendered.to_dict()==committed,"shell presentation changed committed saved simulation")
		check(shell._battle_board_view.focus_mode==Control.FOCUS_ALL,"shell did not restore focus")
		check(seen_attack_frames.size()==int(ContentService.get_unit_animation(attack_id).pose_clips.attack.frames),"shell did not show every authored attack pose including recovery")
		var guard_session=fixture()
		var guard:Dictionary=BattleRules.perform_presented_action(guard_session,"defend")
		shell._session=guard_session
		shell._validation_battle_resolution_routing_enabled=true
		check(shell._begin_action_playback(guard),"interruption fixture did not start")
		shell._validation_battle_resolution_routing_enabled=false
		if shell._action_playback_in_progress:
			var switched:Dictionary=shell._set_battle_presentation_speed("instant")
			check(switched.get("ok",false),"instant interruption failed")
			deadline=Time.get_ticks_msec()+5000
			while shell._action_playback_in_progress and Time.get_ticks_msec()<deadline:await get_tree().process_frame
			check(not shell._action_playback_in_progress,"instant interruption left pending queue")
		shell.queue_free();await get_tree().process_frame
	print("FLUID_ANIMATION_REPORT "+JSON.stringify({"checks":checks,"failures":failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''


def render_fingerprint(packet):
    """Hash painted input and rendering instructions, never review bookkeeping."""
    units=[]
    sources={}
    for entry in packet['units']:
        unit={key:entry.get(key) for key in ('unit_id','reference_height','source_facing','alpha_noise_cutoff','clips')}
        unit['frames']=[{key:frame.get(key) for key in ('source','rects','anchor','scale','alpha_noise_cutoff')} for frame in entry['frames']]
        units.append(unit)
        for frame in entry['frames']:
            source=frame['source']
            if source not in sources:
                path=ROOT/source.removeprefix('res://')
                sources[source]=hashlib.sha256(path.read_bytes()).hexdigest()
    payload=json.dumps({'units':units,'sources':sources},sort_keys=True,separators=(',',':')).encode()
    return 'source-v2:'+hashlib.sha256(payload).hexdigest()


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot',required=True)
    source=parser.add_mutually_exclusive_group(required=True)
    source.add_argument('--patch',type=Path)
    source.add_argument('--handoff',type=Path,nargs='+',help='Pack submitted sources against preserved original baseline before review; batch multiple unit deliveries in one engine run')
    source.add_argument('--live',action='store_true',help='Check currently published catalog rows')
    source.add_argument('--scan',action='store_true',help='Render changed handoff packets in this bounded invocation; no publication or automatic acceptance')
    parser.add_argument('--scan-state',type=Path,default=ROOT/'.artifacts/fluid_runtime_20260923/rendered_handoffs.json')
    parser.add_argument('--unit',nargs='+',help='Only the listed unit IDs')
    parser.add_argument('--contacts-only',action='store_true',help='Render/check submitted clips without repeating the full shell action fixture')
    parser.add_argument('--overview-only',action='store_true',help='One native 128px phase overview per unit instead of individual clip images')
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--render',action='store_true',help='Off-screen Godot rendered phase contacts; does not operate the desktop')
    args=parser.parse_args()
    output=args.output.resolve();output.mkdir(parents=True,exist_ok=True)
    scanned={}
    pack_errors=[]
    if args.scan:
        state=json.loads(args.scan_state.read_text()) if args.scan_state.exists() else {}
        args.handoff=[]
        for path in sorted((ROOT/'art/units/source/generated/fluid_animation').glob('batch_*/unit_*/handoff.json')):
            for attempt in range(3):
                try:
                    raw=path.read_bytes();data=json.loads(raw.decode('utf-8-sig'));break
                except (OSError,ValueError):
                    if attempt==2:raise
                    time.sleep(.1)
            key=path.relative_to(ROOT).as_posix();digest=render_fingerprint(data)
            if state.get(key)!=digest and (not args.unit or any(e['unit_id'] in args.unit for e in data['units'])):
                args.handoff.append(path);scanned[key]=digest
        if not args.handoff:
            print('No new or changed handoff packets.');return 0
    if args.patch:
        patch=json.loads(args.patch.read_text(encoding='utf-8-sig'))
    else:
        sys.path.insert(0,str(ROOT/'tools'))
        from integrate_fluid_creature_animation import pack_unit,read
        rows={r['unit_id']:r for r in read(ROOT/'content/unit_animation_manifest.json')['items']}
        patch={'schema_version':1,'units':[]}
        if args.live:
            for uid,row in rows.items():
                if (args.unit and uid not in args.unit) or not row.get('pose_accepted_clips'):continue
                patch['units'].append({'unit_id':uid,'animation':row,'replaced_clips':row['pose_accepted_clips']})
        else:
            for handoff in args.handoff:
                for entry in read(handoff)['units']:
                    uid=entry['unit_id']
                    if args.unit and uid not in args.unit:continue
                    baseline=ROOT/'art/animation/source/fluid'/uid/'baseline.json'
                    try:
                        patch['units'].append(pack_unit(entry,read(baseline) if baseline.exists() else rows[uid],output/'candidate'))
                    except ValueError as error:
                        if not args.scan:raise
                        message=f'{uid}: {error}';pack_errors.append(message);print('PACKING_BLOCKED '+message)
                        scanned.pop(handoff.relative_to(ROOT).as_posix(),None)
    if args.unit:patch['units']=[p for p in patch['units'] if p['unit_id'] in args.unit]
    if not patch['units']:parser.error('No requested fluid unit clips found')
    patch_path=output/'candidate_patch.json'
    patch_path.write_text(json.dumps(patch),encoding='utf-8')
    with tempfile.TemporaryDirectory(prefix='probe-',dir=output) as directory:
        work=Path(directory)
        (work/'probe.gd').write_text(SCRIPT,encoding='utf-8')
        scene=work/'probe.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="probe.gd" id="1"]\n[node name="FluidProbe" type="Node"]\nscript=ExtResource("1")\n',encoding='utf-8')
        env=dict(os.environ,APPDATA=str(work/'profile'),XDG_DATA_HOME=str(work/'profile'),FLUID_PATCH=str(patch_path),FLUID_OUTPUT=str(output),FLUID_CONTACTS_ONLY='1' if args.contacts_only else '0',FLUID_LIVE='1' if args.live else '0',FLUID_OVERVIEW_ONLY='1' if args.overview_only else '0')
        display=['--rendering-method','gl_compatibility','--position','-16000,-16000','--resolution','1280x400'] if args.render else ['--headless']
        command=[args.godot,'--path',str(ROOT),*display,'--audio-driver','Dummy','--log-file',str(output/'engine.log'),'res://'+scene.relative_to(ROOT).as_posix()]
        if args.render and os.name!='nt':command=['xvfb-run','-a']+command
        with (output/'console.log').open('w',encoding='utf-8') as log:
            result=subprocess.run(command,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=90,creationflags=subprocess.CREATE_NO_WINDOW if os.name=='nt' else 0)
        text=(output/'console.log').read_text(encoding='utf-8')
        print(text)
        errors=[line for line in text.splitlines() if 'ERROR' in line and 'Failed to read the root certificate store.' not in line]
        code=result.returncode or int(bool(errors) or 'FLUID_ANIMATION_REPORT ' not in text)
        if not code and scanned:
            state.update(scanned);args.scan_state.parent.mkdir(parents=True,exist_ok=True)
            args.scan_state.write_text(json.dumps(state,indent=2)+'\n',encoding='utf-8')
        return code or int(bool(pack_errors))


if __name__=='__main__':raise SystemExit(main())
