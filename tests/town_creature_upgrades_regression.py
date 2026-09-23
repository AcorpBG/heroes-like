"""Focused stable upgrade save/recruitment and original multi-pose routing checks."""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image
from unified_mines_regression import ROOT, run_probe
from town_development_regression import SCRIPT as TOWN_SCRIPT


def inspect_art():
    read = lambda path: json.loads((ROOT/path).read_text(encoding='utf-8'))
    units = {u['id']:u for u in read('content/units.json')['items']}
    arts = {u['unit_id']:u for u in read('content/unit_art_manifest.json')['items']}
    anims = {u['unit_id']:u for u in read('content/unit_animation_manifest.json')['items']}
    idles = read('art/overworld/creature_idle.json')['units']
    checked = 0
    for unit in units.values():
        if not unit.get('upgrade_from'): continue
        uid, base = unit['id'], unit['upgrade_from']
        assert not unit['name'].startswith('Veteran ') and unit['abilities'] != units[base]['abilities'],uid
        assert not unit.get('art_source_unit_id'),uid
        art, anim, idle = arts[uid], anims[uid], idles[uid]
        assert not art.get('shared_art_from') and not anim.get('shared_art_from'),uid
        assert 'dead' not in anim.get('pose_aliases',{}),f'{uid}: standing paint cannot be a corpse'
        for key in ('portrait','battle_icon','battle_standee','overworld_icon'):
            p=ROOT/art[key].removeprefix('res://')
            bp=ROOT/arts[base][key].removeprefix('res://')
            assert p.is_file() and hashlib.sha256(p.read_bytes()).digest()!=hashlib.sha256(bp.read_bytes()).digest(),(uid,key)
        indices=anim['pose_clips']['idle']['indices']
        assert len(indices)>=3 and idle['frames']==len(indices),uid
        assert idle['source_sheet']==anim['pose_sheet'] and idle['source_indices']==indices,uid
        width,height=anim['pose_frame_size']['width'],anim['pose_frame_size']['height']
        columns=anim['pose_columns']
        with Image.open(ROOT/anim['pose_sheet'].removeprefix('res://')) as sheet:
            frames=[sheet.crop((i%columns*width,i//columns*height,(i%columns+1)*width,(i//columns+1)*height)) for i in indices]
            assert len({f.tobytes() for f in frames})>=3,uid
            assert all(f.getchannel('A').getextrema()[0]==0 for f in frames),uid
        checked+=1
    assert checked==72,checked
    print(f'Original upgraded static surfaces and articulated battle/map poses: {checked} units pass.')


SCRIPT = TOWN_SCRIPT.split('func run():')[0] + r'''
const Pose=preload("res://scripts/ui/BattleUnitPose.gd")
const View=preload("res://scenes/overworld/OverworldMapView.gd")
const Batch=preload("res://scenes/overworld/OverworldSceneryBatch.gd")
const Idle=preload("res://scenes/overworld/OverworldCreatureIdle.gd")
const Board=preload("res://scenes/battle/BattleBoardView.gd")
func capture()->Image:
	for frame in range(3):await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()
func inspect_rendered_roster():
	var idle=Idle.new();idle.configure(ContentService.load_json("res://art/overworld/creature_idle.json"))
	var batch=Batch.new()
	var canvas=Control.new();canvas.size=Vector2(1280,720);add_child(canvas)
	for fid in Dev.data().rosters:
		batch.begin(canvas)
		var boxes:=[]
		var rows:Array=Dev.data().rosters[fid]
		for i in range(rows.size()):
			var uid:String=rows[i].upgraded_unit_id
			var x:float=(i%4)*320
			var y:float=int(i/4)*240
			var box:=Rect2(x,y,320,240);boxes.append(Rect2i(box))
			batch.record(&"draw_rect",[box,Color(.19,.23,.18)])
			batch.record(&"draw_string",[ThemeDB.fallback_font,Vector2(x+6,y+20),ContentService.get_unit(uid).name,HORIZONTAL_ALIGNMENT_LEFT,308,14])
			var pose:Dictionary=idle.payload(uid,Vector2(x+160,y+228),190)
			check(not pose.is_empty(),"GPU map sprite load "+uid)
			if pose.is_empty():continue
			var material=Idle.material(pose,uid,true)
			material.set_shader_parameter("phase",0.0)
			material.set_shader_parameter("clock_override",.01)
			batch.paint_material(pose.texture,pose.rect,Color.WHITE,material,{"kind":"creature_idle"})
		batch.finish()
		var first:Image=await capture()
		for entry in batch.entries:
			entry.batch.material.set_shader_parameter("clock_override",float(entry.batch.material.get_shader_parameter("frame_seconds"))*1.1)
		var second:Image=await capture()
		for i in range(rows.size()):check(first.get_region(boxes[i]).get_data()!=second.get_region(boxes[i]).get_data(),"GPU painted limb motion "+rows[i].upgraded_unit_id)
		first.save_png(OS.get_cmdline_user_args()[0]+"/"+fid+"-idle-0.png")
		second.save_png(OS.get_cmdline_user_args()[0]+"/"+fid+"-idle-1.png")
		batch.set_motion_enabled(false)
		var still:Image=await capture()
		for entry in batch.entries:entry.batch.material.set_shader_parameter("clock_override",9.0)
		check(still.get_data()==(await capture()).get_data(),"GPU reduced motion "+fid)
		canvas.hide()
		var s=Factory.create_session("river-pass","normal",SessionState.LAUNCH_MODE_SKIRMISH)
		s.battle=Battle.create_battle_payload(s,s.overworld.encounters[0])
		var stacks:=[]
		for i in range(rows.size()):
			var stack:Dictionary=Battle._build_battle_stack(rows[i].upgraded_unit_id,10,"player" if i%2==0 else "enemy",i)
			stack.battle_id="upgrade_render_"+str(i)
			stack.hex={"q":1+(i%4)*3,"r":1+int(i/4)*2}
			stacks.append(stack)
		s.battle.stacks=stacks;s.battle.active_stack_id=stacks[0].battle_id
		s.battle.turn_order=stacks.map(func(stack):return stack.battle_id)
		Battle._sync_occupied_hexes(s.battle);Battle._sync_distance_from_hexes(s.battle)
		var saved:Dictionary=s.to_dict().duplicate(true)
		var board=Board.new();board.size=Vector2(1280,720);add_child(board);board.set_battle_state(s)
		var seen:Dictionary={}
		for stack in stacks:seen[stack.battle_id]={}
		var start:int=Time.get_ticks_msec()
		while Time.get_ticks_msec()-start<1600:
			await get_tree().process_frame
			for stack in stacks:seen[stack.battle_id][str(board._animation_frame_region_for_stack(stack))]=true
		for stack in stacks:check(seen[stack.battle_id].size()>=3,"live battle articulated playback "+stack.unit_id)
		(await capture()).save_png(OS.get_cmdline_user_args()[0]+"/"+fid+"-battle.png")
		SettingsService.set_reduced_motion_enabled(true)
		await capture()
		for stack in stacks:
			check(board._animation_frame_region_for_stack(stack)==Pose.region(ContentService.get_unit_animation(stack.unit_id),"idle_hold",0,0,true),"live battle reduced motion "+stack.unit_id)
		check(s.to_dict()==saved,"animation changed saved battle "+fid)
		SettingsService.set_reduced_motion_enabled(false)
		board.queue_free();await get_tree().process_frame;canvas.show()
	canvas.queue_free()
	await get_tree().process_frame
func run():
	SettingsService.set_presentation_mode("windowed")
	SettingsService.set_presentation_resolution("1280x720")
	DisplayServer.window_set_position(Vector2i(-16000,-16000))
	DisplayServer.window_set_size(Vector2i(1280,720))
	get_tree().root.size=Vector2i(1280,720)
	get_tree().root.content_scale_size=Vector2i(1280,720)
	var art_required:bool=OS.get_cmdline_user_args().has("--art")
	var view=View.new()
	add_child(view);view.hide()
	var count:=0
	for template in ContentService.load_json(ContentService.TOWNS_PATH).items:
		for row in Dev.data().rosters[template.faction_id]:
			var s=fixture(template.id)
			var uid:String=row.upgraded_unit_id
			var u:Dictionary=ContentService.get_unit(uid)
			var base:Dictionary=ContentService.get_unit(row.unit_id)
			check(u.upgrade_from==base.id and not u.name.begins_with("Veteran "),"upgrade identity "+uid)
			var t:Dictionary=s.overworld.towns[0]
			t.built_buildings=["building_town_hall",row.upgrade_building_id]
			t.available_recruits={uid:4};t.garrison=[{"unit_id":uid,"count":7}]
			Dev.migrate_town(t)
			check(t.available_recruits.get(uid,0)==4 and t.garrison[0].unit_id==uid,"existing veteran migrated away "+uid)
			var before:Dictionary=s.overworld.resources.duplicate(true)
			check(Rules.recruit_in_active_town(s,uid,1).get("ok",false),"recruit new named upgrade "+uid)
			check(s.overworld.towns[0].available_recruits.get(uid,0)==3,"reserve count "+uid)
			for resource in u.cost:
				check(s.overworld.resources[resource]==int(before[resource])-int(u.cost[resource]),"recruit cost "+uid+"/"+resource)
			var loaded=Store.SessionData.new();loaded.from_dict(s.to_dict());Rules.normalize_overworld_state(loaded)
			check(loaded.overworld.towns[0].garrison[0].unit_id==uid and loaded.overworld.towns[0].garrison[0].count==7,"save veteran stack "+uid)
			check(loaded.overworld.towns[0].available_recruits.get(uid,0)==3,"save reserves "+uid)
			var stack:Dictionary=Battle._build_battle_stack(uid,7,"player",0)
			check(stack.unit_id==uid and stack.name==u.name,"battle named identity "+uid)
			check(stack.abilities==Battle._normalize_unit_abilities(u.abilities),"battle authored mechanics "+uid)
			if art_required:
				var animation:Dictionary=ContentService.get_unit_animation(uid)
				var first:Rect2=Pose.region(animation,"idle_hold",0,0,false)
				var next:Rect2=Pose.region(animation,"idle_hold",0,int(animation.pose_clips.idle.frame_msec),false)
				check(first!=next,"battle idle does not advance "+uid)
				check(Pose.region(animation,"idle_hold",0,0,true)==Pose.region(animation,"idle_hold",0,9999,true),"reduced battle motion "+uid)
				check(view._encounter_idle_unit_id({"unit_id":uid})==uid and view._creature_idle.units.has(uid),"map idle routing "+uid)
			count+=1
	view.free()
	if art_required:await inspect_rendered_roster()
	check(count==72,"complete stable roster")
	print("TOWN_CREATURE_UPGRADES_REPORT "+JSON.stringify({"checks":checks,"failures":failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot',required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--art',action='store_true')
    args=parser.parse_args()
    if args.art: inspect_art()
    script=SCRIPT.replace('OS.get_cmdline_user_args().has("--art")','true' if args.art else 'false')
    raise SystemExit(run_probe(script,args.godot,args.output,'TOWN_CREATURE_UPGRADES_REPORT'))
