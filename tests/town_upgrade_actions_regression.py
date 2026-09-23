"""Play committed attacks, hits and deaths through all 72 original upgrade sets."""
import argparse
import json
from pathlib import Path

from PIL import Image
from battle_readability_regression import SCRIPT as BATTLE_SCRIPT
from unified_mines_regression import ROOT, run_probe


def inspect_actions(selected=()):
    rows=json.loads((ROOT/'content/unit_animation_manifest.json').read_text())['items']
    checked=0
    for row in (r for r in rows if r['unit_id'].endswith('_veteran')):
        if selected and row['unit_id'] not in selected:continue
        uid=row['unit_id'];clips=row['pose_clips']
        assert all(k in clips for k in ('attack','hit','death','dead')),uid
        assert clips['attack']['frames']>=2 and clips['dead']['frames']==1,uid
        assert all(k not in row['pose_aliases'] for k in ('attack','hit','death','dead')),uid
        w,h=row['pose_frame_size']['width'],row['pose_frame_size']['height'];cols=row['pose_columns']
        ids=clips['attack']['indices']+clips['hit']['indices']+clips['dead']['indices']
        with Image.open(ROOT/row['pose_sheet'].removeprefix('res://')) as atlas:
            data=[atlas.crop((i%cols*w,i//cols*h,(i%cols+1)*w,(i//cols+1)*h)).tobytes() for i in ids]
            assert len(set(data))==len(ids),uid
        checked+=1
    print(f'{checked} original attack/recoil/fallen clip sets pass pixel and route checks.')


SCRIPT=BATTLE_SCRIPT.split('func _ready()')[0]+r'''
const Pose=preload("res://scripts/ui/BattleUnitPose.gd")
const Board=preload("res://scenes/battle/BattleBoardView.gd")
func action_fixture(uid:String,lethal:bool):
	var s=fixture()
	var ranged:bool=ContentService.get_unit(uid).get("ranged",false)
	for i in range(3):
		var old:Dictionary=s.battle.stacks[i]
		var unit:String=uid if i<2 else "unit_river_guard"
		var stack:Dictionary=BattleRules._build_battle_stack(unit,50,"player" if i==0 else "enemy",i)
		stack.battle_id=old.battle_id;stack.hex={"q":3 if i==0 else (7 if i==1 else 10),"r":3 if i<2 else 5}
		stack.abilities=[];stack.speed=6;stack.battle_footprint=1
		stack.unit_hp=100;stack.base_count=50;stack.total_health=1 if lethal and i==1 else 5000
		stack.attack=10;stack.defense=10;stack.min_damage=2;stack.max_damage=2
		stack.ranged=ranged if i==0 else false;stack.shots_remaining=20
		s.battle.stacks[i]=stack
	BattleRules._sync_occupied_hexes(s.battle);BattleRules._sync_distance_from_hexes(s.battle)
	return s
func _ready():call_deferred("run")
func run():
	var requested:Array=[]
	SettingsService.set_presentation_mode("windowed")
	SettingsService.set_presentation_resolution("1280x720")
	DisplayServer.window_set_position(Vector2i(-16000,-16000));DisplayServer.window_set_size(Vector2i(1280,720))
	get_tree().root.size=Vector2i(1280,720);get_tree().root.content_scale_size=Vector2i(1280,720)
	SettingsService.set_reduced_motion_enabled(false)
	var board=Board.new();board.size=Vector2(1280,720);add_child(board)
	var seen:=0
	for unit in ContentService.load_json(ContentService.UNITS_PATH).items:
		if not unit.has("upgrade_from"):continue
		var uid:String=unit.id
		if not requested.is_empty() and uid not in requested:continue
		var layout:Dictionary=ContentService.get_unit_animation(uid)
		var idle_region:Rect2=Pose.region(layout,"idle_hold",0,0,true)
		var drawn:Rect2=Pose.grounded_rect(Vector2(400,300),128,idle_region,layout)
		check(is_equal_approx(drawn.size.y/idle_region.size.y,0.5),"expanded envelope changed body scale "+uid)
		var ground_y:float=drawn.position.y+(idle_region.size.y-float(layout.pose_ground_margin))*0.5
		check(is_equal_approx(ground_y,300),"expanded envelope changed anatomical ground "+uid)
		if DisplayServer.get_name()!="headless":
			var imported:Texture2D=load(layout.pose_sheet)
			check(imported.get_width()==int(layout.pose_frame_size.width)*int(layout.pose_columns),"stale imported action atlas "+uid)
		for lethal in [false,true]:
			var s=action_fixture(uid,lethal)
			var direct=Store.new_session_data();direct.from_dict(s.to_dict().duplicate(true))
			var intent:String="shoot" if unit.get("ranged",false) else "strike"
			var result:Dictionary=BattleRules.perform_presented_action(s,intent)
			var plain:Dictionary=BattleRules.perform_player_action(direct,intent)
			check(result.get("ok",false) and plain.get("ok",false),"committed upgrade action "+uid+"/"+str(lethal))
			check(s.to_dict()==direct.to_dict(),"action art changed simulation/save "+uid)
			var found:=[]
			board.set_battle_state(s)
			for frame in result.get("playback_frames",[]):
				var event:Dictionary=frame.get("playback_event",{})
				var actor:Dictionary=BattleRules._get_stack_by_id(frame,String(event.get("battle_id","")))
				if actor.get("unit_id","")!=uid:continue
				board.set_battle_presentation_snapshot(frame)
				var record:Dictionary=board._animation_playback_record_for_stack(actor.battle_id)
				var state:String=String(record.get("state",board._animation_state_for_stack(actor)))
				var animation:Dictionary=ContentService.get_unit_animation(uid)
				var clip:String=Pose.clip_name(state)
				if clip in ["attack","ranged","hit","death"]:
					found.append(clip)
					check(Pose.region(animation,state,.05,0,false).has_area(),"empty action paint "+uid+"/"+clip)
					if clip in ["attack","ranged","death"]:check(Pose.region(animation,state,.05,0,false)!=Pose.region(animation,state,.95,0,false),"action does not change pose "+uid+"/"+clip)
					if not lethal and int(unit.tier)==7 and DisplayServer.get_name()!="headless" and clip in ["attack","ranged","hit"]:
						for phase in [0.1,0.9] if clip!="hit" else [0.5]:
							var now:int=Time.get_ticks_msec()
							record.started_at_msec=now-int(60000*phase);record.max_duration_ms=60000
							board._stack_animation_playback_records[actor.battle_id]=record
							board._stack_animation_playback_until_msec[actor.battle_id]=now+60000
							var cue:Dictionary=board._stack_animation_cue_playback_records.get(actor.battle_id,{}).duplicate(true)
							cue.started_at_msec=record.started_at_msec;cue.max_duration_ms=60000
							board._stack_animation_cue_playback_records[actor.battle_id]=cue
							board.queue_redraw()
							for render_frame in range(3):await get_tree().process_frame
							await RenderingServer.frame_post_draw
							check(board._animation_frame_region_for_stack(actor)==Pose.region(animation,state,phase,0,false),"GPU action selected wrong frame "+uid+"/"+clip)
							get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0]+"/"+unit.faction_id+"-"+clip+"-"+str(phase)+".png")
			check("attack" in found or "ranged" in found,"attack event never used authored art "+uid)
			check(("death" if lethal else "hit") in found,"target reaction event missing "+uid+"/"+str(lethal))
			board.finish_action_playback(s)
			if lethal:
				var dead:Dictionary=BattleRules._get_stack_by_id(s.battle,s.battle.stacks[1].battle_id)
				var corpses:Array=board._battle_corpse_entries(board._current_hex_layout())
				check(corpses.any(func(c):return c.battle_id==dead.battle_id),"fallen body absent after death "+uid)
				if int(unit.tier)==7 and DisplayServer.get_name()!="headless":
					for frame in range(3):await get_tree().process_frame
					await RenderingServer.frame_post_draw
					get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0]+"/"+unit.faction_id+"-corpse.png")
		seen+=1
	board.queue_free();await get_tree().process_frame
	check(seen==(72 if requested.is_empty() else requested.size()),"complete upgraded action roster")
	print("TOWN_UPGRADE_ACTIONS_REPORT "+JSON.stringify({"checks":checks,"failures":failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot',required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--units',nargs='*',default=[])
    parser.add_argument('--headless',action='store_true')
    args=parser.parse_args()
    inspect_actions(args.units)
    script=SCRIPT.replace('var requested:Array=[]','var requested:Array='+json.dumps(args.units))
    if args.headless:
        import subprocess
        from unittest.mock import patch
        original=subprocess.run
        def headless(command,**kwargs):
            if command[:2]==['xvfb-run','-a']:command=command[2:]
            return original([command[0],'--headless',*command[1:]],**kwargs)
        with patch('unified_mines_regression.subprocess.run',headless):
            raise SystemExit(run_probe(script,args.godot,args.output,'TOWN_UPGRADE_ACTIONS_REPORT'))
    raise SystemExit(run_probe(script,args.godot,args.output,'TOWN_UPGRADE_ACTIONS_REPORT'))
