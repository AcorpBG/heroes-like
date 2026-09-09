#!/usr/bin/env python3
"""Retain a real deterministic Mireclaw opening for scene-art purchase tests."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import tempfile

from generated_full_match_quality import ROOT, OUTPUT
from generated_town_order_profile import run_probe

SCRIPT = r'''
extends Node
const Setup = preload("res://scripts/core/ScenarioSelectRules.gd")
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	get_tree().current_scene=null
	var out := OS.get_environment("MIRECLAW_OPENING_OUTPUT")
	var config: Dictionary=Setup.build_random_map_player_config("10","translated_rmg_template_042_v1","translated_rmg_profile_042_v1",2,"land",false,"homm3_medium",Setup.RANDOM_MAP_TEMPLATE_SELECTION_MODE_SIZE_DEFAULT,"faction_mireclaw","hero_vaska")
	var setup: Dictionary=Setup.build_random_map_skirmish_setup_with_retry(config,"normal",Setup.RANDOM_MAP_PLAYER_RETRY_POLICY)
	var errors := []
	var report := {"config":config,"retry_status":setup.get("retry_status",{}),"retry_attempts":setup.get("retry_attempts",[])}
	if not setup.get("ok",false):
		errors.append("normal generated setup failed")
		report["setup"]=setup
	else:
		var session=SessionState.set_active_session(Setup.start_random_map_skirmish_session_from_setup(setup))
		var towns: Array=session.overworld.towns.filter(func(t):return t.get("owner","")=="player")
		if towns.size()!=1 or towns[0].town_id!="town_duskfen": errors.append("selected faction did not produce Duskfen")
		if session.day!=1 or session.scenario_status!="in_progress" or session.hero_id!="hero_vaska": errors.append("invalid normal opening identity")
		if not errors.is_empty():
			report["towns"]=towns
		else:
			var visit: Dictionary=OverworldRules.set_active_town_visit(session,towns[0].placement_id)
			if not visit.get("ok",false): errors.append("generated hero cannot enter its starting town")
			AppRouter.go_to_town()
			for frame in range(10): await get_tree().process_frame
			var shell=get_tree().current_scene
			while shell.get_node("%TownActionInputBlocker").visible: await get_tree().process_frame
			var before: Dictionary=JSON.parse_string(JSON.stringify(session.to_dict()))
			var path: String=SaveService.save_session(session.to_dict(),1)
			if path=="" or DirAccess.copy_absolute(path,out.path_join("opening_save.json"))!=OK: errors.append("normal opening save failed")
			var restored=SessionState.restore_session(SaveService.load_session(1))
			if JSON.parse_string(JSON.stringify(restored.to_dict()))!=before: errors.append("complete opening save/resume changed state")
			report["town"]=towns[0]
			report["day"]=session.day
			report["hero_position"]=session.overworld.hero_position
			report["resources"]=session.overworld.resources
			report["complete_save_equal"]=errors.is_empty()
			report["save_sha256"]=FileAccess.get_sha256(out.path_join("opening_save.json"))
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(out.path_join("opening_town.png"))
	report["errors"]=errors
	report["ok"]=errors.is_empty()
	print("MIRECLAW_OPENING "+JSON.stringify(report))
	get_tree().quit(0 if errors.is_empty() else 1)
'''

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--label',required=True)
    args=parser.parse_args()
    if not args.label or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789_-' for c in args.label):
        parser.error('fresh lowercase label required')
    out=OUTPUT/args.label
    out.mkdir(exist_ok=False)
    with tempfile.TemporaryDirectory(prefix='mireclaw-start-',dir=OUTPUT) as work, tempfile.TemporaryDirectory(prefix='mireclaw-start-data-',dir='/dev/shm') as data:
        script=Path(work)/'probe.gd'
        script.write_text(SCRIPT)
        scene=Path(work)/'probe.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="MireclawOpening" type="Node"]\nscript=ExtResource("1")\n'%script.relative_to(ROOT))
        env=dict(os.environ,XDG_DATA_HOME=data,MIRECLAW_OPENING_OUTPUT=str(out))
        command=['dbus-run-session','--','xvfb-run','-a','-s','-screen 0 2200x1200x24','godot4','--path',str(ROOT),'--audio-driver','Dummy','--accessibility','disabled','--resolution','1280x720','res://'+str(scene.relative_to(ROOT))]
        with (out/'runtime.log').open('w') as log:
            code=run_probe(command,env,log,timeout_seconds=600)
    lines=(out/'runtime.log').read_text().splitlines()
    reports=[json.loads(line.removeprefix('MIRECLAW_OPENING ')) for line in lines if line.startswith('MIRECLAW_OPENING ')]
    report=reports[-1] if reports else {'ok':False,'errors':['missing report']}
    report.update(returncode=code,probe_sha256=hashlib.sha256(SCRIPT.encode()).hexdigest(),runtime_errors=[line for line in lines if line.startswith(('ERROR:','SCRIPT ERROR:')) or 'leaked' in line])
    report['ok']=report['ok'] and code==0 and not report['runtime_errors']
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({key:report.get(key) for key in ('ok','errors','runtime_errors','save_sha256','complete_save_equal')}))
    return 0 if report['ok'] else 1

if __name__=='__main__':
    raise SystemExit(main())
