#!/usr/bin/env python3
"""Compare lightweight AI town-radius reads against the original full reports."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile

from generated_town_order_profile import ROOT, OUTPUT, run_probe

REFERENCE_REVISION = 'e82ba449d15529d32b9173614c93de73530de23a'
METHODS = ['_linked_player_town_bonus', 'resource_target_score_breakdown',
           '_project_resource_target_descriptor', '_target_candidates_from_descriptors']


def reference_queries():
    source = subprocess.check_output(
        ['git', 'show', f'{REFERENCE_REVISION}:scripts/core/EnemyAdventureRules.gd'], cwd=ROOT).decode()
    result = 'extends "res://scripts/core/EnemyAdventureRules.gd"\n'
    for name in METHODS:
        body = source.split('static func '+name+'(', 1)[1].split('\nstatic func ', 1)[0]
        result += '\nstatic func '+name+'('+body
    for name in METHODS:
        result = result.replace(name+'(', 'legacy_'+name+'(')
    return result


SCRIPT = r'''
extends Node
var errors := []
var checks := 0
var rows := []
var legacy
func _ready() -> void:
	call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		errors.append(label)
func radius(session, town: Dictionary, label: String) -> void:
	var original: Dictionary = OverworldRules.town_logistics_state(session,town)
	check(OverworldRules.town_logistics_support_radius(session,town) == int(original.get("support_radius",0)),label)
func bonus(session, node: Dictionary, label: String) -> void:
	check(legacy.legacy__linked_player_town_bonus(session,node) == EnemyAdventureRules._linked_player_town_bonus(session,node),label)
func check_session(session, label: String) -> void:
	var before: String = JSON.stringify(session.to_dict())
	for town in session.overworld.towns:
		radius(session,town,label+": complete logistics radius")
		if town.get("owner","") != "player":
			continue
		var r := OverworldRules.town_logistics_support_radius(session,town)
		for distance in [0,maxi(0,r-1),r,r+1]:
			bonus(session,{"x":int(town.x)+distance,"y":int(town.y)},label+": radius boundary "+str(distance))
	for config in EnemyTurnRules._enemy_faction_configs_for_session(session):
		var controller := String(config.get("player_id",config.get("faction_id","")))
		var descriptors := EnemyAdventureRules._target_candidate_descriptors(session,config,false)
		for origin in EnemyAdventureRules._ai_hero_task_planner_origins(session,config,controller):
			var pos := Vector2i(int(origin.x),int(origin.y))
			var context := EnemyAdventureRules._path_distance_surface_context(session,"",controller,int(origin.get("level",0)))
			var started := Time.get_ticks_usec()
			var old: Array = legacy.legacy__target_candidates_from_descriptors(session,config,pos,descriptors,context)
			var old_ms := float(Time.get_ticks_usec()-started)/1000.0
			started = Time.get_ticks_usec()
			var current := EnemyAdventureRules._target_candidates_from_descriptors(session,config,pos,descriptors,context)
			var current_ms := float(Time.get_ticks_usec()-started)/1000.0
			check(current == old,label+": exact candidate fields/order "+controller)
			rows.append({"scenario":label,"controller":controller,"origin":origin,"candidates":current.size(),"original_ms":old_ms,"current_ms":current_ms})
	check(before == JSON.stringify(session.to_dict()),label+": read changed complete gameplay state")
func freshness(session) -> void:
	var town: Dictionary = session.overworld.towns[0]
	# Deliberately altered isolated unit fixture, never a full-match outcome.
	for owner in ["player","enemy","neutral",""]:
		town.owner = owner
		for role in ["capital","stronghold",""]:
			town.strategic_role = role
			radius(session,town,"fresh ownership/role projection")
			bonus(session,{"x":town.x,"y":town.y},"fresh ownership/role linked bonus")
	# Unknown templates exercise role defaults without editing ContentService.
	for template in ["", "missing_radius_unit_fixture"]:
		town.town_id = template
		for role in ["capital","stronghold",""]:
			town.strategic_role = role
			town.owner = "player"
			radius(session,town,"fresh unknown-template default radius")
	# Equal-distance selection retains the first original town and its pressure.
	town.strategic_role = "capital"
	var twin := town.duplicate(true)
	twin.placement_id = "radius_tie_unit_fixture"
	twin.strategic_role = "stronghold"
	session.overworld.towns.append(twin)
	bonus(session,{"x":town.x,"y":town.y},"first-town equal-distance tie")
	session.overworld.towns.reverse()
	bonus(session,{"x":town.x,"y":town.y},"reversed equal-distance tie")
func run() -> void:
	legacy = load(OS.get_environment("RADIUS_REFERENCE"))
	radius(null,{},"null/empty input")
	radius(null,{"owner":"player"},"null session input")
	for id in ["three-hearth-auxiliary-charter","bogbound-oath","three-banner-field-commission","rootway-graftmarch","ashen-clausemarch","false-channel-pursuit"]:
		var session = ScenarioFactory.create_session(id,"normal",SessionState.LAUNCH_MODE_SKIRMISH)
		OverworldRules.normalize_overworld_state(session)
		EnemyTurnRules.normalize_enemy_states(session)
		radius(session,{},"empty town input")
		check_session(session,id)
		freshness(session)
	var saved_path := OS.get_environment("RADIUS_REAL_SAVE")
	if saved_path != "":
		var session = SessionState.restore_session(JSON.parse_string(FileAccess.get_file_as_string(saved_path)))
		check_session(session,"recorded_large_day_"+str(session.day))
	print("AI_TOWN_SUPPORT_RADIUS_REGRESSION "+JSON.stringify({"ok":errors.is_empty() and checks>100,"checks":checks,"errors":errors,"rows":rows}))
	get_tree().quit(0 if errors.is_empty() else 1)
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--label', required=True)
    parser.add_argument('--save', type=Path)
    args = parser.parse_args()
    if not args.label or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789_-' for c in args.label):
        parser.error('label must be a fresh lowercase slug')
    out = OUTPUT/args.label
    out.mkdir(parents=True, exist_ok=False)
    saved = args.save.read_bytes() if args.save else None
    if saved:
        json.loads(saved)
        (out/'input_save.json').write_bytes(saved)
    with tempfile.TemporaryDirectory(prefix='radius-regression-', dir=OUTPUT) as temp:
        work = Path(temp)
        reference = reference_queries()
        (work/'reference.gd').write_text(reference)
        (work/'probe.gd').write_text(SCRIPT)
        scene = work/'probe.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="Radius" type="Node"]\nscript = ExtResource("1")\n' % (work/'probe.gd').relative_to(ROOT))
        env = dict(os.environ, XDG_DATA_HOME=str(out/'data'), RADIUS_REFERENCE='res://'+str((work/'reference.gd').relative_to(ROOT)), RADIUS_REAL_SAVE=str(out/'input_save.json') if saved else '')
        with (out/'runtime.log').open('w') as log:
            code = run_probe(['godot4','--headless','--path',str(ROOT),'--audio-driver','Dummy','--accessibility','disabled','res://'+str(scene.relative_to(ROOT))],env,log)
    lines = (out/'runtime.log').read_text().splitlines()
    marker = 'AI_TOWN_SUPPORT_RADIUS_REGRESSION '
    reports = [json.loads(line[len(marker):]) for line in lines if line.startswith(marker)]
    report = reports[-1] if reports else {'ok':False,'errors':['missing report']}
    report.update(returncode=code,reference_revision=REFERENCE_REVISION,reference_sha256=hashlib.sha256(reference.encode()).hexdigest(),save_sha256=hashlib.sha256(saved).hexdigest() if saved else None,runtime_errors=[line for line in lines if line.startswith(('ERROR:','SCRIPT ERROR:')) or 'leaked' in line])
    report['ok'] = bool(report['ok']) and code==0 and not report['runtime_errors']
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k!='rows'}))
    return 0 if report['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
