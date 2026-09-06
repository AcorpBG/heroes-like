#!/usr/bin/env python3
"""Profile complete End Turns and their AI phases from a real generated save."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import signal
import tempfile
from time import monotonic

from generated_full_match_quality import ROOT, OUTPUT, SCRIPT as MATCH_SCRIPT
from generated_town_order_profile import pause_drivers, resume_drivers, run_probe, stop_requested, latency_summary

BODY = r'''
func capture_state(label: String) -> void:
	var file := FileAccess.open(out.path_join(label+".json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(session.to_dict()))
func run_match() -> void:
	get_tree().current_scene = null
	out = OS.get_environment("TURN_PROFILE_OUTPUT")
	action_file = FileAccess.open(out.path_join("actions.jsonl"),FileAccess.WRITE)
	SettingsService.set_presentation_mode("windowed")
	SettingsService.set_presentation_resolution("1280x720")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(out.path_join("input_save.json")))
	session = SessionState.restore_session(saved)
	for key in ["saved_at_unix","save_slot_type","saved_from_game_state","saved_from_scenario_status","saved_from_launch_mode"]:
		saved.erase(key)
	if saved != JSON.parse_string(JSON.stringify(session.to_dict())):
		failures.append("restore changed full gameplay state")
	AppRouter.resume_active_session()
	await resolve_routes()
	capture_state("state_00")
	var rows := []
	for index in range(3):
		if not scene_path().ends_with("OverworldShell.tscn") or session.scenario_status != "in_progress":
			failures.append("three ordinary nonterminal turns required for matched timing")
			break
		var shell = get_tree().current_scene
		var day_before: int = session.day
		var started := Time.get_ticks_usec()
		var result: Dictionary = shell._request_end_turn(false)
		if bool(result.get("confirmation_required",false)):
			result = shell._on_end_turn_confirmation_confirmed()
		var enemy_profile: Dictionary = shell._last_end_turn_rule_result.get("enemy_turn_profile",{}).duplicate(true)
		var callback_ms := float(Time.get_ticks_usec()-started)/1000.0
		await resolve_routes()
		var usable_ms := float(Time.get_ticks_usec()-started)/1000.0
		if not bool(result.get("ok",false)) or session.day != day_before+1:
			failures.append("End Turn failed or did not advance one day")
		if enemy_profile.is_empty():
			failures.append("missing real AI phase profile")
		rows.append({"day_before":day_before,"day_after":session.day,"ok":result.get("ok",false),"callback_ms":callback_ms,"usable_ms":usable_ms,"enemy_turn_profile":enemy_profile})
		capture_state("state_%02d" % (index+1))
	print("GENERATED_END_TURN_PROFILE "+JSON.stringify({"ok":failures.is_empty() and rows.size()==3,"failures":failures,"rows":rows,"battle_counts":counts}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--label', required=True)
    parser.add_argument('--save', type=Path, required=True)
    parser.add_argument('--compare', type=Path)
    parser.add_argument('--require-improvement', action='store_true')
    parser.add_argument('--pause-driver', action='append', default=[])
    args = parser.parse_args()
    for label in [args.label]+args.pause_driver:
        if not label or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789_-' for c in label):
            parser.error('labels must be lowercase slugs')
    if args.require_improvement and not args.compare:
        parser.error('--require-improvement requires --compare')
    out = OUTPUT/args.label
    out.mkdir(parents=True, exist_ok=False)
    saved = args.save.read_bytes()
    json.loads(saved)
    (out/'input_save.json').write_bytes(saved)
    sources = {name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in ['scripts/core/EnemyAdventureRules.gd','scripts/core/EnemyTurnRules.gd','scripts/core/OverworldRules.gd','scenes/overworld/OverworldShell.gd','scripts/autoload/SaveService.gd']}
    signal.signal(signal.SIGTERM,stop_requested)
    paused = pause_drivers(args.pause_driver)
    started = monotonic()
    try:
        with tempfile.TemporaryDirectory(prefix='turn-profile-',dir=OUTPUT) as temporary:
            work = Path(temporary)
            (work/'probe.gd').write_text(MATCH_SCRIPT[:MATCH_SCRIPT.index('func run_match()')]+BODY)
            scene = work/'probe.tscn'
            scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="Turns" type="Node"]\nscript = ExtResource("1")\n' % (work/'probe.gd').relative_to(ROOT))
            env = dict(os.environ,XDG_DATA_HOME=str(out/'data'),TURN_PROFILE_OUTPUT=str(out),HEROES_PROFILE_LOG='1',HEROES_STRATEGIC_AI_PROFILE='1')
            with (out/'runtime.log').open('w') as log:
                code = run_probe(['godot4','--headless','--path',str(ROOT),'--audio-driver','Dummy','--accessibility','disabled','res://'+str(scene.relative_to(ROOT))],env,log)
    finally:
        resume_drivers(paused)
    lines = (out/'runtime.log').read_text().splitlines()
    marker = 'GENERATED_END_TURN_PROFILE '
    reports = [json.loads(line[len(marker):]) for line in lines if line.startswith(marker)]
    report = reports[-1] if reports else {'ok':False,'failures':['missing report']}
    report.update(returncode=code,save_sha256=hashlib.sha256(saved).hexdigest(),source_sha256=sources,paused_engine_pids=paused,wall_seconds=monotonic()-started,runtime_errors=[line for line in lines if line.startswith(('ERROR:','SCRIPT ERROR:')) or 'leaked' in line])
    report['latency'] = latency_summary(report.get('rows',[]))
    if args.compare:
        reference = json.loads((args.compare/'report.json').read_text())
        parity = {p.name:json.loads(p.read_text())==json.loads((args.compare/p.name).read_text()) for p in sorted(out.glob('state_*.json'))}
        days_equal = [(r['day_before'],r['day_after']) for r in report.get('rows',[])] == [(r['day_before'],r['day_after']) for r in reference.get('rows',[])]
        report['comparison'] = {'reference':str(args.compare),'states':parity,'same_days':days_equal,'same_save':report['save_sha256']==reference['save_sha256'],'usable_ratio':report['latency'].get('total_ms',1)/max(1,reference['latency'].get('total_ms',1))}
        report['ok'] = report['ok'] and reference.get('ok',False) and len(parity)==4 and all(parity.values()) and days_equal and report['comparison']['same_save']
        if args.require_improvement:
            report['ok'] = report['ok'] and report['comparison']['usable_ratio'] <= 0.85
    report['ok'] = bool(report['ok']) and code==0 and not report['runtime_errors']
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({key:value for key,value in report.items() if key!='rows'}))
    return 0 if report['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
