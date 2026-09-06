#!/usr/bin/env python3
"""Measure real Town recruit clicks from an unchanged recorded generated save."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import platform
from pathlib import Path
import re
import signal
import statistics
import subprocess
import tempfile
from time import monotonic

from generated_full_match_quality import OUTPUT, ROOT
from large_town_build_end_turn_profile import town_probe_script

MARKER = 'GENERATED_TOWN_ORDER_PROFILE '
SCRIPT = r'''
extends Node
var failures := []
var rows := []
var out := ""
func _ready() -> void:
	call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
func state(session, label: String) -> void:
	var file := FileAccess.open(out.path_join(label+".json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(session.to_dict()))
func run() -> void:
	get_tree().current_scene = null
	out = OS.get_environment("ORDER_PROFILE_OUTPUT")
	SettingsService.set_presentation_mode("windowed")
	SettingsService.set_presentation_resolution("1280x720")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(out.path_join("input_save.json")))
	var session = SessionState.restore_session(saved)
	var restored: Dictionary = JSON.parse_string(JSON.stringify(session.to_dict()))
	for key in ["saved_at_unix","save_slot_type","saved_from_game_state","saved_from_scenario_status","saved_from_launch_mode"]:
		saved.erase(key)
	check(saved == restored,"restore changed complete serialized gameplay state")
	var placement := OS.get_environment("ORDER_PROFILE_TOWN")
	var visit: Dictionary = OverworldRules.set_active_town_visit(session,placement)
	check(bool(visit.get("ok",false)),"normal owned-town management rejected")
	var shell = load("res://scenes/town/TownShell.tscn").instantiate()
	shell.set_script(load(OS.get_environment("ORDER_PROFILE_SCRIPT")))
	add_child(shell)
	for frame in range(6):
		await get_tree().process_frame
	state(session,"state_00")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("town_before.png"))
	for index in range(3):
		var action := {}
		for candidate in TownRules.get_recruit_actions(session):
			if not bool(candidate.get("disabled",true)):
				action = candidate
				break
		if action.is_empty():
			check(false,"three naturally available recruit orders required")
			break
		var id := String(action.id)
		shell.profile_calls.clear()
		var started := Time.get_ticks_usec()
		# Exact handler connected to the real recruitment button, without the
		# validation wrapper's extra catalog and progress-signature overhead.
		shell._on_recruit_action_pressed(id.trim_prefix("recruit:"))
		var callback_ms := float(Time.get_ticks_usec()-started)/1000.0
		for frame in range(6):
			await get_tree().process_frame
		while shell._town_action_input_blocker.visible:
			await get_tree().process_frame
		var usable_ms := float(Time.get_ticks_usec()-started)/1000.0
		var recap: Dictionary = shell._last_action_recap.duplicate(true)
		check(bool(recap.get("active",false)),"recruit action failed: "+id)
		rows.append({"id":id,"callback_ms":callback_ms,"usable_ms":usable_ms,"calls":shell.profile_calls.duplicate(true),"recap":recap})
		state(session,"state_%02d" % (index+1))
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("town_after.png"))
	print("GENERATED_TOWN_ORDER_PROFILE "+JSON.stringify({"ok":failures.is_empty() and rows.size()==3,"failures":failures,"day":session.day,"town":placement,"rows":rows}))
	shell.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
'''


def pause_drivers(labels: list[str]) -> list[int]:
    """Pause only verified, session-isolated Godot children for these test labels."""
    paused = []
    try:
        for label in labels:
            target = f'HEROES_FULL_MATCH_OUTPUT={OUTPUT / label}'.encode()
            matches = []
            for proc in Path('/proc').iterdir():
                if not proc.name.isdigit():
                    continue
                try:
                    command = (proc/'cmdline').read_bytes().split(b'\0')
                    if not command or Path(os.fsdecode(command[0])).name != 'godot4':
                        continue
                    if target in (proc/'environ').read_bytes().split(b'\0'):
                        pid = int(proc.name)
                        if os.getpgid(pid) != pid:
                            raise ValueError(f'{label}: engine is not session-isolated')
                        matches.append(pid)
                except (FileNotFoundError, ProcessLookupError, PermissionError):
                    continue
            if len(matches) != 1:
                raise ValueError(f'{label}: expected one live owned engine, found {matches}')
            os.killpg(matches[0], signal.SIGSTOP)
            paused.append(matches[0])
        return paused
    except BaseException:
        resume_drivers(paused)
        raise


def resume_drivers(pids: list[int]) -> None:
    for pid in pids:
        try:
            os.killpg(pid, signal.SIGCONT)
        except ProcessLookupError:
            pass


def stop_requested(_signum, _frame):
    # Let the protected finally blocks resume paused matches on normal TERM.
    raise SystemExit('profiling runner terminated')


def latency_summary(rows: list[dict]) -> dict:
    values = sorted(row['usable_ms'] for row in rows)
    return {'count':len(values),'p50_ms':statistics.median(values),'p95_ms':values[min(len(values)-1,int(len(values)*0.95))],'max_ms':max(values),'total_ms':sum(values)} if values else {}


def run_probe(command: list[str], env: dict, log) -> int:
    process = subprocess.Popen(command,env=env,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
    try:
        return process.wait(timeout=300)
    finally:
        if process.poll() is None:
            os.killpg(process.pid,signal.SIGTERM)
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid,signal.SIGKILL)
                process.wait(timeout=5)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--label', required=True)
    parser.add_argument('--save', type=Path, required=True)
    parser.add_argument('--town', default='native_h3maped_c2520619_object_2167')
    parser.add_argument('--compare', type=Path)
    parser.add_argument('--reference-town-revision', help='Exact commit hash for an unchanged old Town script in the disposable probe only')
    parser.add_argument('--rendered', action='store_true')
    parser.add_argument('--require-improvement', action='store_true')
    parser.add_argument('--pause-driver', action='append', default=[])
    args = parser.parse_args()
    if args.reference_town_revision and not re.fullmatch('[0-9a-f]{8,40}',args.reference_town_revision):
        parser.error('reference revision must be a commit hash')
    if args.require_improvement and not args.compare:
        parser.error('--require-improvement requires --compare')
    for slug in [args.label]+args.pause_driver:
        if not slug or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789_-' for c in slug):
            parser.error('labels must be lowercase slugs')
    out = OUTPUT/args.label
    out.mkdir(parents=True, exist_ok=False)
    saved = args.save.read_bytes()
    json.loads(saved)  # Fail before launching if a concurrently written file is incomplete.
    (out/'input_save.json').write_bytes(saved)
    signal.signal(signal.SIGTERM, stop_requested)
    paused = pause_drivers(args.pause_driver)
    started = monotonic()
    try:
        with tempfile.TemporaryDirectory(prefix='order-profile-',dir=OUTPUT) as temporary:
            work = Path(temporary)
            probe = town_probe_script()
            town_source = (ROOT/'scenes/town/TownShell.gd').read_bytes()
            if args.reference_town_revision:
                town_source = subprocess.check_output(['git','show',f'{args.reference_town_revision}:scenes/town/TownShell.gd'],cwd=ROOT)
                (work/'reference.gd').write_bytes(town_source)
                probe = probe.replace('res://scenes/town/TownShell.gd','res://'+str((work/'reference.gd').relative_to(ROOT)))
            (work/'town.gd').write_text(probe)
            (work/'probe.gd').write_text(SCRIPT)
            scene = work/'probe.tscn'
            scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="Orders" type="Node"]\nscript = ExtResource("1")\n' % (work/'probe.gd').relative_to(ROOT))
            env = dict(os.environ,XDG_DATA_HOME=str(out/'data'),ORDER_PROFILE_OUTPUT=str(out),ORDER_PROFILE_SCRIPT='res://'+str((work/'town.gd').relative_to(ROOT)),ORDER_PROFILE_TOWN=args.town,HEROES_PROFILE_LOG='1')
            with (out/'runtime.log').open('w') as log:
                command = ['godot4','--path',str(ROOT),'--audio-driver','Dummy','--accessibility','disabled','res://'+str(scene.relative_to(ROOT))]
                command = ['dbus-run-session','--','xvfb-run','-a','-s','-screen 0 2000x1200x24']+command if args.rendered else command+['--headless']
                returncode = run_probe(command,env,log)
    finally:
        resume_drivers(paused)
    lines = (out/'runtime.log').read_text().splitlines()
    reports = [json.loads(line[len(MARKER):]) for line in lines if line.startswith(MARKER)]
    report = reports[-1] if reports else {'ok':False,'failures':['missing report']}
    report.update(save_sha256=hashlib.sha256(saved).hexdigest(),town_source_sha256=hashlib.sha256(town_source).hexdigest(),reference_town_revision=args.reference_town_revision,rendered=args.rendered,host=platform.platform(),returncode=returncode,wall_seconds=monotonic()-started,paused_engine_pids=paused,runtime_errors=[line for line in lines if line.startswith(('ERROR:','SCRIPT ERROR:')) or 'leaked' in line])
    report['latency'] = latency_summary(report.get('rows',[]))
    if args.compare:
        reference = json.loads((args.compare/'report.json').read_text())
        states = sorted(out.glob('state_*.json'))
        parity = {p.name:json.loads(p.read_text())==json.loads((args.compare/p.name).read_text()) for p in states}
        identity = [row['id'] for row in report.get('rows',[])] == [row['id'] for row in reference.get('rows',[])]
        recaps = [row['recap'] for row in report.get('rows',[])] == [row['recap'] for row in reference.get('rows',[])]
        report['comparison'] = {'reference':str(args.compare),'states':parity,'actions_equal':identity,'recaps_equal':recaps,'same_save':report['save_sha256']==reference['save_sha256']}
        report['ok'] = report['ok'] and reference.get('ok',False) and len(parity)==4 and all(parity.values()) and identity and recaps and report['comparison']['same_save']
        reference_latency = latency_summary(reference.get('rows',[]))
        if report['latency'] and reference_latency:
            ratio = report['latency']['total_ms']/reference_latency['total_ms']
            report['comparison'].update(usable_ratio=ratio,reference_latency=reference_latency,same_backend=args.rendered==reference.get('rendered',False))
        if args.require_improvement:
            report['ok'] = report['ok'] and report['comparison'].get('same_backend',False) and report['comparison'].get('usable_ratio',1.0) <= 0.80
    report['ok'] = bool(report['ok']) and not report['runtime_errors'] and returncode==0
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report))
    return 0 if report['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
