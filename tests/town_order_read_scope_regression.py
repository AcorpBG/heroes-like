#!/usr/bin/env python3
"""Prove Town order read equivalence, freshness and mutation-scope boundaries."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile

from generated_full_match_quality import ROOT, OUTPUT

SCRIPT = r'''
extends Node
var errors := []
var rows := []
func _ready() -> void:
	call_deferred("run")
func check(value: bool, label: String) -> void:
	if not value:
		errors.append(label)
func closed() -> bool:
	return TownRules._read_scope_depth == 0 and OverworldRules._normalized_read_scope_depth == 0
func run() -> void:
	get_tree().current_scene = null
	for scenario in ["three-hearth-auxiliary-charter","bogbound-oath","three-banner-field-commission","rootway-graftmarch","ashen-clausemarch","false-channel-pursuit"]:
		var session = SessionState.set_active_session(ScenarioFactory.create_session(scenario,"normal",SessionState.LAUNCH_MODE_SKIRMISH))
		for town in session.overworld.towns:
			if String(town.get("owner","")) == "player":
				OverworldRules.set_active_town_visit(session,String(town.placement_id))
				break
		var shell = load("res://scenes/town/TownShell.tscn").instantiate()
		add_child(shell)
		await get_tree().process_frame
		var before := JSON.stringify(session.to_dict())
		var old_signature := TownRules.town_action_consequence_signature(session)
		var catalog: Dictionary = shell.validation_action_catalog()
		check(before == JSON.stringify(session.to_dict()),scenario+": original read path mutated state")
		var samples := 0
		for lane in catalog:
			var tested := {}
			for action in catalog[lane]:
				var disabled := bool(action.get("disabled",false))
				# Each populated lane covers its first enabled and disabled item.
				if tested.has(disabled):
					continue
				tested[disabled] = true
				var expected: Dictionary = shell._validation_action_for_id(String(action.id))
				var actual: Dictionary = shell._prepare_order_read_context(String(action.id))
				check(actual.before == old_signature and actual.action == expected,scenario+": context differs for "+String(action.id))
				check(closed(),scenario+": preflight leaked scope")
				samples += 1
		check(shell._prepare_order_read_context("unknown:order").action.is_empty(),scenario+": unknown action enabled")
		check(shell._read_action_consequence_signature() == old_signature,scenario+": presentation signature differs")
		check(before == JSON.stringify(session.to_dict()),scenario+": new reads mutated state")
		check(closed(),scenario+": signature leaked scope")
		OverworldRules.begin_normalized_read_scope(session)
		TownRules.begin_read_scope(session)
		shell._prepare_order_read_context("unknown:order")
		check(TownRules._read_scope_depth == 1 and OverworldRules._normalized_read_scope_depth == 1,scenario+": nested scope ownership changed")
		TownRules.end_read_scope(session)
		OverworldRules.end_normalized_read_scope(session)
		var selected := ""
		for action in TownRules.get_recruit_actions(session):
			if not bool(action.get("disabled",true)):
				selected = String(action.id)
				break
		check(selected != "",scenario+": no recruit freshness fixture")
		if selected != "":
			var stores: Dictionary = session.overworld.resources.duplicate(true)
			var context: Dictionary = shell._prepare_order_read_context(selected)
			context.before.resources.gold = -999
			check(session.overworld.resources == stores,scenario+": detached context aliases live resources")
			# Isolated stale-input unit fixture, never used by the full-match driver.
			for key in session.overworld.resources:
				session.overworld.resources[key] = 0
			check(shell._prepare_order_read_context(selected).action.is_empty(),scenario+": stale affordability remained enabled")
			var denied_before := JSON.stringify(session.to_dict())
			shell._on_recruit_action_pressed(selected.trim_prefix("recruit:"))
			check(denied_before == JSON.stringify(session.to_dict()),scenario+": rejected recruit mutated gameplay")
			check(closed(),scenario+": rejected order leaked scope")
			session.overworld.resources = stores
			check(not shell._prepare_order_read_context(selected).action.is_empty(),scenario+": fresh stores failed to re-enable order")
			shell._on_recruit_action_pressed(selected.trim_prefix("recruit:"))
			check(bool(shell._last_action_recap.get("active",false)),scenario+": real recruit failed")
			check(closed(),scenario+": successful order retained scope across rules/refresh/presentation")
		rows.append({"scenario":scenario,"catalog_samples":samples,"recruit_id":selected})
		shell.queue_free()
		await get_tree().process_frame
	print("TOWN_ORDER_READ_SCOPE_REGRESSION "+JSON.stringify({"ok":errors.is_empty() and rows.size()==6,"errors":errors,"rows":rows}))
	get_tree().quit(0 if errors.is_empty() else 1)
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--label', required=True)
    args = parser.parse_args()
    if not args.label or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789_-' for c in args.label):
        parser.error('label must be a fresh lowercase slug')
    out = OUTPUT/args.label
    out.mkdir(parents=True, exist_ok=False)
    with tempfile.TemporaryDirectory(prefix='order-scope-',dir=OUTPUT) as temporary:
        work = Path(temporary)
        (work/'probe.gd').write_text(SCRIPT)
        scene = work/'probe.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="Scopes" type="Node"]\nscript = ExtResource("1")\n' % (work/'probe.gd').relative_to(ROOT))
        env = dict(os.environ,XDG_DATA_HOME=str(out/'data'),HEROES_PROFILE_LOG='0')
        with (out/'runtime.log').open('w') as log:
            result = subprocess.run(['timeout','300s','godot4','--headless','--path',str(ROOT),'--audio-driver','Dummy','--accessibility','disabled','res://'+str(scene.relative_to(ROOT))],env=env,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,timeout=320)
    lines = (out/'runtime.log').read_text().splitlines()
    marker = 'TOWN_ORDER_READ_SCOPE_REGRESSION '
    reports = [json.loads(line[len(marker):]) for line in lines if line.startswith(marker)]
    report = reports[-1] if reports else {'ok':False,'errors':['missing report']}
    report.update(returncode=result.returncode,runtime_errors=[line for line in lines if line.startswith(('ERROR:','SCRIPT ERROR:')) or 'leaked' in line])
    report['ok'] = bool(report['ok']) and not report['runtime_errors'] and result.returncode==0
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report))
    return 0 if report['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
