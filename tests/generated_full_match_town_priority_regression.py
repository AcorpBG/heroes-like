#!/usr/bin/env python3
"""Same driver Town priority without constructing discarded encounter paths."""
import argparse
import ast
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import tempfile

from generated_full_match_quality import ROOT, OUTPUT, SCRIPT as MATCH_SCRIPT
from generated_town_order_profile import run_probe, stop_requested

MARKER = 'GENERATED_TOWN_PRIORITY_REPORT '
SHELL = '''extends "res://scenes/overworld/OverworldShell.gd"
var probe_targets := {}
func _validation_targets(kind: String, owner: String = "", placement: String = "") -> Array:
\tif probe_targets.has(kind): return probe_targets[kind].duplicate(true)
\treturn super._validation_targets(kind, owner, placement)
'''
CASES = r'''
var checks := 0
var probe_failures := []
var observations := []
var guard_calls := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: probe_failures.append(message)
func normalized(value): return JSON.parse_string(JSON.stringify(value))
func guard_approach(encounter: Dictionary) -> Vector2i:
	guard_calls += 1
	return measured_guard_approach(encounter)
func bookkeeping() -> Dictionary:
	return {"failed":failed_targets.duplicate(true),"towns":last_town_day.duplicate(true),"intent":active_target.duplicate(true),"progress":last_progress_day,"signs":read_signs.duplicate(true),"waypoints":waypoint_visits.duplicate(true)}
func restore_bookkeeping(value: Dictionary) -> void:
	failed_targets=value.failed.duplicate(true)
	last_town_day=value.towns.duplicate(true)
	active_target=value.intent.duplicate(true)
	last_progress_day=value.progress
	read_signs=value.signs.duplicate(true)
	waypoint_visits=value.waypoints.duplicate(true)
func compare_case(label: String, expect_remote: bool, expect_reference_work: bool = false) -> Dictionary:
	var before: Dictionary=normalized(session.to_dict())
	var history:=bookkeeping()
	guard_calls=0
	var started:=Time.get_ticks_usec()
	var reference:=reference_choose_target()
	var reference_ms:=float(Time.get_ticks_usec()-started)/1000.0
	var reference_calls:=guard_calls
	var reference_history:=bookkeeping()
	check(normalized(session.to_dict())==before,label+" reference changed complete gameplay state")
	restore_bookkeeping(history)
	guard_calls=0
	started=Time.get_ticks_usec()
	var current:=choose_target()
	var current_ms:=float(Time.get_ticks_usec()-started)/1000.0
	check(normalized(current)==normalized(reference),label+" complete selected target differs")
	check(bookkeeping()==reference_history,label+" intent or failure/cooldown history differs")
	check(normalized(session.to_dict())==before,label+" optimized selection changed complete gameplay state")
	check(bool(current.get("remote",false))==expect_remote,label+" unexpected target category")
	if expect_reference_work:
		check(reference_calls>0,label+" fixture did not exercise discarded encounter approaches")
		check(guard_calls==0,label+" ready Town management computed unrelated encounter approaches")
	observations.append({"case":label,"reference_ms":reference_ms,"current_ms":current_ms,"reference_guard_calls":reference_calls,"current_guard_calls":guard_calls,"selected":normalized(current)})
	return current
func run_match() -> void:
	get_tree().current_scene=null
	var payload: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("TOWN_PRIORITY_SAVE")))
	check(SaveService.save_session(payload,1)!="","isolated saved-game copy failed")
	session=SaveService.restore_manual_session(1)
	if session==null:
		push_error("saved generated session restore failed");get_tree().quit(1);return
	session=SessionState.set_active_session(session)
	for key in ["saved_at_unix","save_slot_type","saved_from_game_state","saved_from_scenario_status","saved_from_launch_mode"]:payload.erase(key)
	check(normalized(session.to_dict())==payload,"production restore changed complete saved gameplay state")
	var shell=load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	shell.set_script(load(OS.get_environment("TOWN_PRIORITY_SHELL")))
	get_tree().root.add_child(shell)
	get_tree().current_scene=shell
	await settle()
	check(shell._session==session,"probe uses a detached session")
	active_target={"id":"retained_field_intent","kind":"resource"}
	last_progress_day=38
	var selected:=compare_case("recorded_medium_day43",true,true)
	var towns: Array=shell._validation_targets("town").filter(func(row):return String(row.get("owner",""))=="player" and known(row))
	check(towns.size()>=2,"recorded save needs two visible owned towns")
	if towns.size()>=2:
		check(selected.get("id","")==towns[0].placement_id,"recorded catalog-first town was not selected")
		# Keep the complete real field catalog for the no-management branch.
		for town in towns:last_town_day[town.placement_id]=session.day
		var real_field:=compare_case("recorded_medium_day43_field",false)
		check(not real_field.is_empty(),"recorded field selection was not exercised")
		last_town_day.clear()
		# Detached catalog controls exercise the same scene method and domain
		# predicates, but are not accepted match actions or gameplay injections.
		var pos:=OverworldRules.hero_position(session)
		var safe_resource: Dictionary={"placement_id":"priority_fixture_safe","site_id":"site_waystone_cache","x":pos.x,"y":pos.y,"level":Levels.hero_level(session),"collected":false}
		shell.probe_targets={"town":towns.duplicate(true),"resource":[safe_resource],"artifact":[],"encounter":[]}
		var first_id:=String(towns[0].placement_id)
		var second_id:=String(towns[1].placement_id)
		last_town_day[first_id]=session.day
		check(compare_case("already_managed_first",true).get("id","")==second_id,"managed-day cooldown was bypassed")
		last_town_day.clear()
		failed_targets[first_id]=session.day
		check(compare_case("failed_first",true).get("id","")==second_id,"failed-target cooldown was bypassed")
		failed_targets.clear()
		shell.probe_targets.town[0].owner="enemy"
		check(compare_case("enemy_first",true).get("id","")==second_id,"foreign town entered remote management")
		shell.probe_targets.town=towns.duplicate(true)
		shell.probe_targets.town[0].level=Levels.hero_level(session)+1
		if shell.probe_targets.town[0].has("position"):shell.probe_targets.town[0].position.level=Levels.hero_level(session)+1
		check(not known(shell.probe_targets.town[0]),"wrong-level control is still known")
		check(compare_case("wrong_level_first",true).get("id","")==second_id,"level rejection was bypassed")
		shell.probe_targets.town=towns.duplicate(true)
		var hidden:=Vector2i(-1,-1)
		var dimensions: Vector2i=OverworldRules.derive_map_size(session)
		for y in range(dimensions.y):
			for x in range(dimensions.x):
				if not OverworldRules.is_tile_visible(session,x,y):hidden=Vector2i(x,y);break
			if hidden.x>=0:break
		check(hidden.x>=0,"recorded save has no hidden tile control")
		shell.probe_targets.town[0].x=hidden.x
		shell.probe_targets.town[0].y=hidden.y
		shell.probe_targets.town[0].visit_tile={"x":hidden.x,"y":hidden.y,"level":Levels.hero_level(session)}
		check(compare_case("unseen_first",true).get("id","")==second_id,"unexplored town became a management target")
		shell.probe_targets.town=towns.duplicate(true)
		var entry: Dictionary=towns[0].get("visit_tile",towns[0])
		var encounters: Array=session.overworld.encounters.duplicate(true)
		session.overworld.encounters.append({"placement_id":"priority_guard_control","kind":"guard","encounter_id":"encounter_mire_raid","x":entry.x,"y":entry.y,"level":Levels.hero_level(session),"enemy_army":{"stacks":[{"unit_id":"unit_bog_brute","count":100000}]},"resolved":false})
		var guard: Dictionary=OverworldRules.guard_engagement_encounter_at_tile(session,int(entry.x),int(entry.y))
		check(not guard.is_empty() and power(OverworldRules._encounter_army_payload(guard).get("stacks",[]))>player_power()*0.70,"strong-guard control did not reach the real risk predicate")
		check(compare_case("strong_guard_first",true).get("id","")==second_id,"remote town guard-risk predicate was bypassed")
		session.overworld.encounters=encounters
		for town in towns:last_town_day[town.placement_id]=session.day
		var field:=compare_case("no_ready_town",false)
		check(field.get("id","")=="priority_fixture_safe","ordinary field fallback changed")
		active_target={"id":field.get("id",""),"kind":field.get("kind","")}
		check(compare_case("retained_field_intent",false).get("id","")==active_target.id,"eligible retained intent was not preserved")
	print("GENERATED_TOWN_PRIORITY_REPORT "+JSON.stringify({"ok":probe_failures.is_empty(),"checks":checks,"failures":probe_failures,"observations":observations,"scope":"driver method equivalence and discarded-work removal; not game latency or a complete match"}))
	shell.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if probe_failures.is_empty() else 1)
'''


def main():
    signal.signal(signal.SIGTERM, stop_requested)
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--label',required=True)
    parser.add_argument('--save',required=True,type=Path)
    parser.add_argument('--reference-revision',default='db66974e')
    args=parser.parse_args()
    if not args.label or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789_-' for c in args.label):parser.error('fresh lowercase label required')
    if not re.fullmatch('[0-9a-f]{8,40}',args.reference_revision):parser.error('exact reference commit required')
    source=args.save.resolve()
    source_hash=hashlib.sha256(source.read_bytes()).hexdigest()
    old_source=subprocess.check_output(['git','show',f'{args.reference_revision}:tests/generated_full_match_quality.py'],cwd=ROOT,text=True)
    old_script=next(ast.literal_eval(node.value) for node in ast.parse(old_source).body if isinstance(node,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='SCRIPT' for t in node.targets))
    start=old_script.index('func choose_target() -> Dictionary:')
    end=old_script.index('\nfunc ',start+5)
    reference=old_script[start:end].replace('func choose_target()', 'func reference_choose_target()',1)
    script=MATCH_SCRIPT.replace('func run_match() -> void:','func unused_full_match() -> void:',1).replace('func guard_approach(', 'func measured_guard_approach(',1)+'\n'+reference+'\n'+CASES
    out=OUTPUT/args.label
    out.mkdir(parents=True,exist_ok=False)
    temporary_root='/dev/shm' if Path('/dev/shm').is_dir() else None
    with tempfile.TemporaryDirectory(prefix='town-priority-',dir=OUTPUT) as temporary,tempfile.TemporaryDirectory(prefix='heroes-town-priority-data-',dir=temporary_root) as data:
        work=Path(temporary)
        (work/'probe.gd').write_text(script)
        (work/'shell.gd').write_text(SHELL)
        scene=work/'probe.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="TownPriority" type="Node"]\nscript = ExtResource("1")\n' % (work/'probe.gd').relative_to(ROOT))
        env=dict(os.environ,XDG_DATA_HOME=data,TOWN_PRIORITY_SAVE=str(source),TOWN_PRIORITY_SHELL='res://'+str((work/'shell.gd').relative_to(ROOT)))
        with (out/'runtime.log').open('w') as log:
            code=run_probe(['godot4','--headless','--path',str(ROOT),'--audio-driver','Dummy','--accessibility','disabled','res://'+str(scene.relative_to(ROOT))],env,log)
    lines=(out/'runtime.log').read_text().splitlines()
    reports=[json.loads(line[len(MARKER):]) for line in lines if line.startswith(MARKER)]
    report=reports[-1] if reports else {'ok':False,'failures':['missing report']}
    errors=[line for line in lines if line.startswith(('ERROR:','SCRIPT ERROR:')) or 'leaked' in line]
    report.update(returncode=code,runtime_errors=errors,source_save=str(source),source_save_sha256=source_hash,source_save_unchanged=hashlib.sha256(source.read_bytes()).hexdigest()==source_hash,reference_revision=args.reference_revision,reference_driver_sha256=hashlib.sha256(old_script.encode()).hexdigest(),driver_sha256=hashlib.sha256(MATCH_SCRIPT.encode()).hexdigest())
    report['ok']=bool(report['ok']) and code==0 and not errors and report['source_save_unchanged']
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report))
    return 0 if report['ok'] else 1


if __name__=='__main__':raise SystemExit(main())
