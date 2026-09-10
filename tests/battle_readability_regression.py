#!/usr/bin/env python3
"""Real rule and rendered-shell coverage for combined melee and action playback."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / '.artifacts/battle_readability_20260910'
SCRIPT = r'''extends Node
const Store = preload("res://scripts/core/SessionStateStore.gd")
const Playback = preload("res://scripts/core/BattleActionPlayback.gd")
var failures := []
var checks := 0
var out := ""
var rendered_events := []
var captured_resolution := Vector2i.ZERO
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func fixture():
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	session.battle = BattleRules.create_battle_payload(session, session.overworld.encounters[0])
	var players := []
	var enemies := []
	for stack in session.battle.stacks:
		if stack.side=="player": players.append(stack)
		else: enemies.append(stack)
	var stacks := [players[0], enemies[0], enemies[1]]
	for index in range(stacks.size()):
		stacks[index].total_health = 2000
		stacks[index].base_count = 20
		stacks[index].unit_hp = 100
		stacks[index].speed = 3
		stacks[index].ranged = false
		stacks[index].abilities = []
		stacks[index].hex = {"q":2+index*3,"r":3}
	session.battle.stacks=stacks
	session.battle.turn_order=stacks.map(func(s):return s.battle_id)
	session.battle.turn_index=0
	session.battle.active_stack_id=stacks[0].battle_id
	session.battle.selected_target_id=stacks[1].battle_id
	session.battle[BattleRules.FIELD_OBJECTIVES_KEY]=[]
	BattleRules._sync_occupied_hexes(session.battle)
	BattleRules._sync_distance_from_hexes(session.battle)
	session.game_state="battle"
	return session
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	out=OS.get_environment("BATTLE_READABILITY_OUT")
	var session=fixture()
	var active: Dictionary=BattleRules.get_active_stack(session.battle)
	var target: Dictionary=BattleRules.get_selected_target(session.battle)
	var before: Dictionary=session.to_dict().duplicate(true)
	var approach:=BattleRules.melee_approach_destination(session.battle,active,target)
	check(not approach.is_empty(),"reachable enemy has no melee approach")
	check(session.to_dict()==before,"approach query mutated state")
	check(not BattleRules._can_make_melee_attack(active,session.battle,target),"fixture already adjacent")
	var intent:=BattleRules.board_click_attack_intent_for_target(session.battle,target.battle_id)
	check(intent.action=="strike" and intent.label=="Move & strike","board intent missing combined action")
	check(BattleRules.action_availability(session.battle).strike,"strike button disabled for approach")
	var direct=Store.new_session_data()
	direct.from_dict(before.duplicate(true))
	var result:=BattleRules.perform_presented_action(session,"strike")
	var ordinary:=BattleRules.perform_player_action(direct,"strike")
	check(result.ok and ordinary.ok,"combined strike failed")
	check(session.to_dict()==direct.to_dict(),"presentation capture changed simulation/RNG/save state")
	check(not session.battle.has(Playback.CAPTURE_KEY),"transient capture leaked into save state")
	var frames: Array=result.get("playback_frames",[])
	check(frames.size()>=3,"missing intermediate action frames")
	var events:=[]
	var enemy_frames:=0
	for frame in frames:
		var event: Dictionary=frame.playback_event
		events.append(event.event_id)
		check(frame.battle_animation_events.size()==1,"frame contains overlapping events")
		check(not frame.has(Playback.CAPTURE_KEY),"recursive capture data leaked")
		var actor:=BattleRules._get_stack_by_id(frame,String(event.battle_id))
		if actor.get("side")=="enemy": enemy_frames+=1
	check(events[0]=="battle_unit_move" and "battle_unit_melee_attack" in events,"move then strike sequence missing")
	var path: Array=frames[0].playback_event.get("walk_path",[])
	check(path.size()>=2 and path.size()-1<=int(active.speed),"movement playback lacks a legal length path")
	for index in range(1,path.size()):
		check(BattleRules._hex_distance(path[index-1],path[index])==1,"movement animation skips hexes")
	check(enemy_frames>0,"enemy actions absent from playback")
	var moved:=BattleRules._get_stack_by_id(frames[0],String(active.battle_id))
	check(BattleRules._hex_distance(BattleRules._stack_hex(moved),BattleRules._stack_hex(target))==1,"strike approach did not land adjacent")
	var unreachable=fixture()
	unreachable.battle.stacks[0].speed=1
	var rejected_before: Dictionary=unreachable.to_dict().duplicate(true)
	var rejected:=BattleRules.perform_presented_action(unreachable,"strike")
	check(not rejected.ok and unreachable.to_dict()==rejected_before,"unreachable strike mutated/spent turn")
	var enclosed=fixture()
	var defender: Dictionary=enclosed.battle.stacks[1]
	for cell in BattleRules._hex_neighbors(BattleRules._stack_hex(defender)):
		var blocker: Dictionary=enclosed.battle.stacks[0].duplicate(true)
		blocker.battle_id="block_%d_%d"%[cell.q,cell.r]
		blocker.hex=cell
		enclosed.battle.stacks.append(blocker)
	check(BattleRules.melee_approach_destination(enclosed.battle,enclosed.battle.stacks[0],defender).is_empty(),"occupied adjacent hex accepted")
	var adjacent=fixture()
	adjacent.battle.stacks[0].hex={"q":4,"r":3}
	check(BattleRules.melee_approach_destination(adjacent.battle,adjacent.battle.stacks[0],adjacent.battle.stacks[1]).is_empty(),"already adjacent stack moved unnecessarily")
	var enemy=fixture()
	enemy.battle.enemy_hero={}
	enemy.battle.enemy_hero_payload={}
	enemy.battle.active_stack_id=enemy.battle.stacks[1].battle_id
	enemy.battle.turn_index=1
	var enemy_target: Dictionary=enemy.battle.stacks[0].duplicate(true)
	var enemy_result:=BattleRules._run_enemy_turn(enemy,enemy.battle.stacks[1])
	check(enemy_result.ok,"enemy approach action failed")
	check(int(enemy.battle.stacks[0].total_health)<int(enemy_target.total_health),"enemy did not move and strike reachable target")
	var opening=fixture()
	opening.battle.active_stack_id=opening.battle.stacks[1].battle_id
	opening.battle.turn_index=1
	var opening_result:=BattleRules.perform_presented_action(opening,"ready")
	check(opening_result.ok and not opening_result.get("playback_frames",[]).is_empty(),"initial enemy initiative has no playback")
	if DisplayServer.get_name()!="headless":
		SettingsService.set_battle_playback_speed_id(OS.get_environment("BATTLE_READABILITY_SPEED"))
		SettingsService.set_reduced_motion_enabled(OS.get_environment("BATTLE_READABILITY_REDUCED")=="1")
		var rendered=SessionState.set_active_session(fixture())
		var shell=load("res://scenes/battle/BattleShell.tscn").instantiate()
		add_child(shell)
		for i in range(8): await get_tree().process_frame
		# Settings applies its saved window size during entry; enforce and
		# measure the requested validation viewport after that application.
		var dimensions:=OS.get_environment("TOWN_OVERLAY_RESOLUTION").split("x")
		var requested:=Vector2i(int(dimensions[0]),int(dimensions[1]))
		DisplayServer.window_set_size(requested)
		get_tree().root.size=requested
		get_tree().root.content_scale_size=requested
		for i in range(4): await get_tree().process_frame
		var clicked: Dictionary=shell._on_board_stack_focus_requested(String(rendered.battle.selected_target_id))
		check(clicked.ok and shell._action_playback_in_progress,"live board click did not start queued playback")
		var committed: Dictionary=rendered.to_dict().duplicate(true)
		check(not shell._perform_action("defend").ok,"extra input accepted during playback")
		check(rendered.to_dict()==committed,"locked input changed state")
		var captured:=0
		var last_serial:=-1
		while shell._action_playback_in_progress:
			await get_tree().create_timer(0.2).timeout
			var displayed: Dictionary=shell._battle_board_view._battle
			var serial:=int(displayed.get("playback_event",{}).get("serial",-1))
			if captured<9 and serial!=last_serial and serial>=0:
				rendered_events.append(displayed.playback_event.event_id)
				check(not String(displayed.get("playback_caption","")).is_empty(),"action caption absent from visible board")
				await RenderingServer.frame_post_draw
				var capture:=get_viewport().get_texture().get_image()
				captured_resolution=capture.get_size()
				check(captured_resolution==requested,"capture resolution differs from requested viewport")
				capture.save_png(out.path_join("action-%d.png"%captured))
				captured+=1
				last_serial=serial
		check(shell._battle_board_view.focus_mode==Control.FOCUS_ALL,"board focus not restored")
		check(rendered.to_dict()==committed,"playback changed committed battle state")
		SettingsService.set_battle_playback_speed_id("instant")
		BattleRules.set_battle_presentation_speed(rendered,"instant")
		var skipped: Dictionary=shell._perform_action("defend")
		check(skipped.ok and not shell._action_playback_in_progress,"instant speed left pending playback")
		shell.queue_free()
		for i in range(3): await get_tree().process_frame
	print("BATTLE_READABILITY_REPORT "+JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures,"events":events,"rendered_events":rendered_events,"frames":frames.size(),"enemy_frames":enemy_frames,"captured_resolution":[captured_resolution.x,captured_resolution.y]}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''

def run_probe(command, env, log, timeout_seconds=300):
    return subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=timeout_seconds).returncode

def probe_environment(env):
    return env

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--label',required=True)
    parser.add_argument('--render',action='store_true')
    parser.add_argument('--resolution',default='1280x720')
    parser.add_argument('--speed',choices=['normal','fast'],default='normal')
    parser.add_argument('--reduced-motion',action='store_true')
    args=parser.parse_args()
    out=OUTPUT/args.label
    out.mkdir(parents=True,exist_ok=False)
    with tempfile.TemporaryDirectory(prefix='probe-',dir=OUTPUT) as work, tempfile.TemporaryDirectory(prefix='battle-readability-user-') as user:
        work=Path(work)
        (work/'probe.gd').write_text(SCRIPT)
        scene=work/'probe.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="probe.gd" id="1"]\n[node name="Probe" type="Node"]\nscript=ExtResource("1")\n')
        env=probe_environment(dict(os.environ,XDG_DATA_HOME=user,XDG_CONFIG_HOME=user,XDG_CACHE_HOME=user,BATTLE_READABILITY_OUT=str(out),BATTLE_READABILITY_SPEED=args.speed,BATTLE_READABILITY_REDUCED='1' if args.reduced_motion else '0',TOWN_OVERLAY_RESOLUTION=args.resolution))
        command=['godot','--path',str(ROOT),'--audio-driver','Dummy','--accessibility','disabled','--quit-after','1800','--resolution',args.resolution]
        if args.render: command=['xvfb-run','-a']+command+['--rendering-method','gl_compatibility']
        else: command+=['--headless']
        command+=['res://'+str(scene.relative_to(ROOT))]
        with (out/'runtime.log').open('w') as log: code=run_probe(command,env,log)
        text=(out/'runtime.log').read_text()
        rows=[line.partition('BATTLE_READABILITY_REPORT ')[2] for line in text.splitlines() if line.startswith('BATTLE_READABILITY_REPORT ')]
        report=json.loads(rows[-1]) if rows else {'ok':False,'failures':['no report']}
        report['ok']=report['ok'] and code==0 and 'ERROR:' not in text
        (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
        print(json.dumps(report))
        return 0 if report['ok'] else 1

if __name__=='__main__': raise SystemExit(main())
