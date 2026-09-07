#!/usr/bin/env python3
"""Compare shared logistics reads with the exact pre-cache calculation."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile

from generated_town_order_profile import ROOT, OUTPUT, run_probe

REFERENCE = 'f7db06e8f0b08633c650db8134250f323fb63f74'
OWNER = 'scripts/core/OverworldRules.gd'


def reference_script():
    source = subprocess.check_output(['git', 'show', f'{REFERENCE}:{OWNER}'], cwd=ROOT).decode()
    body = source.split('static func _town_logistics_state(', 1)[1].split('\nstatic func ', 1)[0]
    return f'extends "res://{OWNER}"\nstatic func original_logistics('+body


SCRIPT = r'''
extends Node
var checks := 0
var errors := []
var rows := []
var original
func _ready() -> void:
	call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		errors.append(label)
func compare(session, town: Dictionary, label: String) -> void:
	var expected: Dictionary = original.original_logistics(session,town)
	check(OverworldRules._town_logistics_state(session,town) == expected,label+": private read differs")
	check(OverworldRules.town_logistics_state(session,town) == expected,label+": public read differs")
func scope_case(session, label: String) -> void:
	# Normalize before the read-only state comparison: production read scopes do
	# this at entry, and generated restore has already passed exact save checks.
	OverworldRules.normalize_overworld_state_for_runtime(session)
	var before := JSON.stringify(session.to_dict())
	for town in session.overworld.towns:
		compare(session,town,label+": unscoped")
	OverworldRules.begin_normalized_read_scope(session)
	OverworldRules.begin_normalized_read_scope(session)
	for town in session.overworld.towns:
		compare(session,town,label+": scoped")
		var first: Dictionary = OverworldRules._town_logistics_state(session,town)
		var returned := first.duplicate(true)
		first.summary = "caller-owned mutation"
		first.held_site_labels.append("caller-owned mutation")
		check(OverworldRules._town_logistics_state(session,town) == returned,label+": cached result aliases caller")
		# Build previews are separate town values inside the same read interval.
		var projected: Dictionary = town.duplicate(true)
		projected.placement_id = String(town.get("placement_id",""))+"_projection"
		projected.strategic_role = "capital"
		compare(session,projected,label+": projected town")
		compare(session,town,label+": original after projection")
	var profile := OverworldRules.validation_last_normalized_read_scope_cache_profile()
	check(int(profile.get("hits",0)) > 0,label+": shared entry never reused logistics")
	OverworldRules.end_normalized_read_scope(session)
	check(OverworldRules._normalized_read_scope_depth == 1,label+": nested close discarded outer scope")
	OverworldRules.end_normalized_read_scope(session)
	check(OverworldRules._normalized_read_scope_depth == 0 and OverworldRules._normalized_read_scope_cache.is_empty(),label+": cache survived synchronous read scope")
	check(before == JSON.stringify(session.to_dict()),label+": read changed complete session")
	rows.append({"case":label,"towns":session.overworld.towns.size(),"cache":profile})
func shared_entry_probe(session) -> void:
	var town: Dictionary = session.overworld.towns[0]
	OverworldRules.begin_normalized_read_scope(session)
	OverworldRules._town_logistics_state(session,town)
	var before := OverworldRules.validation_last_normalized_read_scope_cache_profile()
	OverworldRules._town_logistics_state(session,town)
	var after := OverworldRules.validation_last_normalized_read_scope_cache_profile()
	check(int(after.get("hits",0)) == int(before.get("hits",0))+1,"private read bypasses shared cache")
	check(int(after.get("misses",0)) == int(before.get("misses",0)),"repeated private read recomputes logistics")
	OverworldRules.end_normalized_read_scope(session)
func freshness(session, label: String) -> void:
	# Isolated mutation controls, never fed to a match or performance result.
	var town: Dictionary = session.overworld.towns[0]
	var node := {"placement_id":"logistics_scope_site","site_id":"site_brightwood_sawmill","x":town.x,"y":town.y,"level":int(town.get("level",0))}
	session.overworld.resource_nodes.append(node)
	for owner in ["neutral","enemy","player"]:
		town.owner = owner
		node.collected_by_player_id = OverworldRules._town_controller_id(town)
		node.collected_by_faction_id = node.collected_by_player_id
		session.day += 1
		OverworldRules.mark_runtime_normalized_transition_state(session)
		scope_case(session,label+": fresh owner/day "+owner)
	var held := int(original.original_logistics(session,town).get("held_site_count",0))
	node.collected_by_player_id = "logistics_scope_hostile"
	node.collected_by_faction_id = "logistics_scope_hostile"
	scope_case(session,label+": linked site changes controller")
	check(int(original.original_logistics(session,town).get("held_site_count",0)) == held-1,label+": site ownership fixture did not change held count")
	node.collected_by_player_id = "player"
	node.collected_by_faction_id = "player"
	node.response_until_day = session.day
	scope_case(session,label+": escort active")
	var escorts := int(original.original_logistics(session,town).get("response_count",0))
	check(escorts > 0,label+": escort fixture did not activate")
	session.day += 1
	OverworldRules.mark_runtime_normalized_transition_state(session)
	scope_case(session,label+": escort expired")
	check(int(original.original_logistics(session,town).get("response_count",0)) < escorts,label+": escort expiry did not change response count")
	# A stored save inspected inside a live read scope can have the same saved
	# session id and town record but different linked-site ownership.
	OverworldRules.begin_normalized_read_scope(session)
	compare(session,town,label+": outer live state")
	var historical = SessionStateStore.SessionData.new()
	historical.from_dict(session.to_dict())
	historical.overworld.resource_nodes[-1].collected_by_player_id = "logistics_scope_hostile"
	historical.overworld.resource_nodes[-1].collected_by_faction_id = "logistics_scope_hostile"
	OverworldRules.begin_normalized_read_scope(historical)
	compare(historical,historical.overworld.towns[0],label+": nested same-id historical state")
	OverworldRules.end_normalized_read_scope(historical)
	check(OverworldRules._normalized_read_scope_depth == 1,label+": historical close discarded outer scope")
	compare(session,town,label+": outer state after historical read")
	OverworldRules.end_normalized_read_scope(session)
	# A replacement after the outer scope ends also needs fresh results.
	var restored = SessionStateStore.SessionData.new()
	restored.from_dict(session.to_dict())
	restored.overworld.towns[0].placement_id = "restored_logistics_fixture"
	scope_case(restored,label+": same-id replacement")
func run() -> void:
	original = load(OS.get_environment("LOGISTICS_REFERENCE"))
	compare(null,{},"null empty")
	compare(null,{"owner":"player"},"null town")
	for id in ["three-hearth-auxiliary-charter","bogbound-oath","three-banner-field-commission","rootway-graftmarch","ashen-clausemarch","false-channel-pursuit"]:
		var session = ScenarioFactory.create_session(id,"normal",SessionState.LAUNCH_MODE_SKIRMISH)
		scope_case(session,id)
		shared_entry_probe(session)
		freshness(session,id)
	var path := OS.get_environment("LOGISTICS_SAVE")
	if path != "":
		var session = SessionState.restore_session(JSON.parse_string(FileAccess.get_file_as_string(path)))
		scope_case(session,"real generated day "+str(session.day))
		shared_entry_probe(session)
	print("TOWN_LOGISTICS_READ_SCOPE_REGRESSION "+JSON.stringify({"ok":errors.is_empty(),"checks":checks,"errors":errors,"rows":rows}))
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
    reference = reference_script()
    source_hash = hashlib.sha256((ROOT/OWNER).read_bytes()).hexdigest()
    with tempfile.TemporaryDirectory(prefix='logistics-scope-', dir=OUTPUT) as temp:
        work = Path(temp)
        (work/'reference.gd').write_text(reference)
        (work/'probe.gd').write_text(SCRIPT)
        scene = work/'probe.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="Logistics" type="Node"]\nscript = ExtResource("1")\n' % (work/'probe.gd').relative_to(ROOT))
        env = dict(os.environ, XDG_DATA_HOME=str(out/'data'), LOGISTICS_REFERENCE='res://'+str((work/'reference.gd').relative_to(ROOT)), LOGISTICS_SAVE=str(out/'input_save.json') if saved else '')
        with (out/'runtime.log').open('w') as log:
            code = run_probe(['godot4','--headless','--path',str(ROOT),'--audio-driver','Dummy','--accessibility','disabled','res://'+str(scene.relative_to(ROOT))],env,log)
    lines = (out/'runtime.log').read_text().splitlines()
    marker = 'TOWN_LOGISTICS_READ_SCOPE_REGRESSION '
    reports = [json.loads(line[len(marker):]) for line in lines if line.startswith(marker)]
    report = reports[-1] if reports else {'ok':False,'errors':['missing report']}
    report.update(returncode=code,reference_revision=REFERENCE,reference_sha256=hashlib.sha256(reference.encode()).hexdigest(),source_sha256=source_hash,save_sha256=hashlib.sha256(saved).hexdigest() if saved else None,runtime_errors=[line for line in lines if line.startswith(('ERROR:','SCRIPT ERROR:')) or 'leaked' in line])
    report['ok'] = bool(report['ok']) and code==0 and not report['runtime_errors']
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k!='rows'}))
    return 0 if report['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
