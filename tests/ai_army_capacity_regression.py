#!/usr/bin/env python3
"""AI army admission and source-preserving transfers through production rules."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import tempfile

from generated_full_match_quality import ROOT, OUTPUT, CASES, SCRIPT as MATCH_SCRIPT
from generated_town_order_profile import run_probe

SCRIPT = r'''
extends Node
const AI = preload("res://scripts/core/EnemyAdventureRules.gd")
const Turns = preload("res://scripts/core/EnemyTurnRules.gd")
const FACTION := "faction_mireclaw"
const NEW_UNIT := "unit_bog_brute"
const UNITS := ["unit_river_guard","unit_ember_archer","unit_embercourt_fordhook_cadets","unit_embercourt_lantern_sappers","unit_embercourt_bargebow_crews","unit_embercourt_ash_oath_bailiffs","unit_embercourt_lockglass_writcasters"]
var checks := 0
var failures := []
var findings := {}
func _ready() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
func normalized(value):
	return JSON.parse_string(JSON.stringify(value))
func state(s) -> Dictionary:
	return normalized(s.to_dict())
func stacks(count: int = 1) -> Array:
	var result := []
	for unit in UNITS:
		result.append({"unit_id":unit,"count":count})
	return result
func total(value: Array) -> int:
	var result := 0
	for stack in value:
		result += int(stack.get("count",0))
	return result
func manifest(value: Array) -> Dictionary:
	var result := {}
	for stack in value:
		var unit: String = stack.unit_id
		result[unit] = int(result.get(unit,0))+int(stack.count)
	return result
func commander(f: Dictionary, army: Array) -> Dictionary:
	var entry: Dictionary = f.enemy.commander_roster[0]
	var value := AI.build_roster_commander_state(entry.roster_hero_id,FACTION,entry.get("commander_state",{}),entry)
	return AI.sync_commander_army_continuity(value,{"stacks":army},"encounter_mire_raid")
func fixture() -> Dictionary:
	var s = ScenarioFactory.create_session("river-pass","normal",SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(s)
	Turns.normalize_enemy_states(s)
	AI.normalize_all_commander_rosters(s)
	var town: Dictionary = s.overworld.towns.filter(func(t):return t.placement_id=="duskfen_bastion")[0]
	var enemy: Dictionary = s.overworld.enemy_states.filter(func(e):return e.faction_id==FACTION)[0]
	var config: Dictionary = ContentService.get_scenario("river-pass").enemy_factions.filter(func(e):return e.faction_id==FACTION)[0].duplicate(true)
	var raid := {"placement_id":"capacity_raid","encounter_id":"encounter_mire_raid","spawned_by_faction_id":FACTION,"x":6,"y":2,"arrived":false,"target_kind":"town","target_placement_id":"riverwatch_hold","enemy_army":{"id":"capacity_host","name":"Capacity Host","stacks":stacks(10)},"commanderless_support_column":true}
	s.overworld.encounters = [raid]
	OverworldRules.invalidate_spatial_lookup(s)
	return {"session":s,"town":town,"enemy":enemy,"config":config,"raid":raid}
func claim_cases() -> void:
	# A computer hero claiming a recruit site through the shared claim owner
	# (EnemyAdventureRules._secure_resource_target, used by AiHeroRules) with a
	# full army must leave the site and the army untouched.
	var f := fixture();var s = f.session
	var node := {"placement_id":"capacity_claim","site_id":"site_free_company_yard","x":6,"y":2,"collected":false}
	s.overworld.resource_nodes = [node]
	f.raid.target_kind = "resource";f.raid.target_placement_id = node.placement_id
	OverworldRules.invalidate_spatial_lookup(s)
	var before := state(s)
	var raid_before: Dictionary = f.raid.duplicate(true)
	var result: Dictionary = AI._secure_resource_target(s,f.raid,f.enemy,FACTION,f.config)
	check(state(s)==before,"full army claim consumed site rewards/state")
	check(result.encounter==raid_before,"full army claim mutated the claiming army")
func fitting_controls() -> void:
	var f := fixture();var s = f.session
	f.raid.enemy_army.stacks = [{"unit_id":UNITS[0],"count":10}]
	var node := {"placement_id":"capacity_claim","site_id":"site_free_company_yard","x":6,"y":2,"collected":false}
	s.overworld.resource_nodes = [node]
	f.raid.target_kind = "resource";f.raid.target_placement_id = node.placement_id
	OverworldRules.invalidate_spatial_lookup(s)
	var site := ContentService.get_resource_site(node.site_id)
	var expected := AI._resource_site_claim_recruits(site)
	expected[UNITS[0]] = int(expected.get(UNITS[0],0))+10
	var result: Dictionary = AI._secure_resource_target(s,f.raid,f.enemy,FACTION,f.config)
	check(manifest(result.encounter.enemy_army.stacks)==expected,"fitting site claim lost or duplicated recruits")
	check(s.overworld.resource_nodes[0].collected,"fitting site claim did not record collection")
func continuity_controls() -> void:
	var f := fixture();var s = f.session
	f.raid.enemy_commander_state=commander(f,stacks(10))
	f.raid.commanderless_support_column=false
	f.raid.erase("enemy_army")
	check(manifest(AI._raid_reinforcement_army(f.raid).get("stacks",[]))==manifest(stacks(10)),"admission substituted starter troops for saved commander continuity")
	var node := {"placement_id":"continuity_claim","site_id":"site_free_company_yard","x":6,"y":2,"collected":false}
	s.overworld.resource_nodes=[node]
	f.raid.target_kind="resource";f.raid.target_placement_id=node.placement_id
	OverworldRules.invalidate_spatial_lookup(s)
	var before:=state(s);var raid_before:Dictionary=f.raid.duplicate(true)
	var result:=AI._secure_resource_target(s,f.raid,f.enemy,FACTION,f.config)
	check(state(s)==before and result.encounter==raid_before,"continuity-only claim consumed rewards or overwrote saved troops")
func run() -> void:
	claim_cases()
	fitting_controls()
	continuity_controls()
	if OS.has_environment("AI_CAPACITY_GENERATED_CONFIG"):
		generated_turn_cases()
	print("AI_ARMY_CAPACITY_REGRESSION "+JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures,"findings":findings}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''

GENERATED = r'''
const Setup = preload("res://scripts/core/ScenarioSelectRules.gd")
const Heroes = preload("res://scripts/core/HeroCommandRules.gd")
var session
func generated_turn_cases() -> void:
	# Normal generated starting state and ordinary rules; no injected armies,
	# controller removals, forced winners or altered economy. Not a full match.
	var cfg: Dictionary = JSON.parse_string(OS.get_environment("AI_CAPACITY_GENERATED_CONFIG"))
	var config := Setup.build_random_map_player_config(cfg.seed,"translated_rmg_template_042_v1","translated_rmg_profile_042_v1",cfg.players,"land",false,cfg.size,Setup.RANDOM_MAP_TEMPLATE_SELECTION_MODE_SIZE_DEFAULT,cfg.faction,cfg.hero)
	var setup := Setup.build_random_map_skirmish_setup_with_retry(config,"normal",Setup.RANDOM_MAP_PLAYER_RETRY_POLICY)
	check(bool(setup.get("ok",false)),"generated map setup failed")
	if not bool(setup.get("ok",false)):
		return
	var initial = Setup.start_random_map_skirmish_session_from_setup(setup)
	var payload := state(initial)
	var expected := []
	var rows := []
	for replay in range(2):
		session = SessionState.restore_session(payload.duplicate(true))
		check(state(session)==payload,"generated opening restore changed complete state")
		check(capacity_snapshot().ok,"generated opening exceeds army capacity")
		for turn in range(7):
			var day_before: int = session.day
			var started := Time.get_ticks_usec()
			var result := OverworldRules.end_turn(session)
			var elapsed := float(Time.get_ticks_usec()-started)/1000.0
			check(bool(result.get("ok",false)) and session.day==day_before+1,"generated ordinary End Turn failed")
			var capacity := capacity_snapshot()
			check(capacity.ok,"generated turn exceeds army capacity: "+JSON.stringify(capacity))
			var complete := state(session)
			if replay==0:
				expected.append(complete)
			else:
				check(complete==expected[turn],"generated replay diverged in complete state on turn "+str(turn))
			rows.append({"replay":replay,"day":session.day,"capacity":capacity,"rules_ms":elapsed,"state_sha256":JSON.stringify(complete).sha256_text()})
			print("AI_CAPACITY_GENERATED_TURN "+JSON.stringify(rows[-1]))
	findings.generated={"config":cfg,"rows":rows,"terminal_match_acceptance":false}
'''
# Share the match acceptance observer rather than introducing a narrower set
# of army holders for this rule-level generated-map regression.
SCRIPT += GENERATED + MATCH_SCRIPT[MATCH_SCRIPT.index('func capacity_snapshot()'):MATCH_SCRIPT.index('func compact_state()')]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--label', required=True)
    parser.add_argument('--generated-case', choices=CASES)
    args = parser.parse_args()
    if not args.label or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789_-' for c in args.label):
        parser.error('label must be a fresh lowercase slug')
    out = OUTPUT / args.label
    out.mkdir(parents=True, exist_ok=False)
    with tempfile.TemporaryDirectory(prefix='ai-capacity-',dir=OUTPUT) as temporary:
        work = Path(temporary)
        script = work/'probe.gd'
        script.write_text(SCRIPT)
        scene = work/'probe.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="AiCapacity" type="Node"]\nscript = ExtResource("1")\n' % script.relative_to(ROOT).as_posix())
        env = dict(os.environ,XDG_DATA_HOME=str(out/'data'))
        if args.generated_case:
            env['AI_CAPACITY_GENERATED_CONFIG'] = json.dumps(CASES[args.generated_case])
        command = ['godot4','--path',str(ROOT),'--headless','--audio-driver','Dummy','res://'+scene.relative_to(ROOT).as_posix()]
        with (out/'runtime.log').open('w') as log:
            code = run_probe(command,env,log)
    lines = (out/'runtime.log').read_text().splitlines()
    marker = 'AI_ARMY_CAPACITY_REGRESSION '
    reports = [json.loads(line[len(marker):]) for line in lines if line.startswith(marker)]
    report = reports[-1] if reports else {'ok':False,'failures':['missing report']}
    owners = ['scripts/core/HeroCommandRules.gd','scripts/core/EnemyTurnRules.gd','scripts/core/EnemyAdventureRules.gd']
    report.update(returncode=code,source_hashes={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in owners},runtime_errors=[s for s in lines if s.startswith(('ERROR:','SCRIPT ERROR:')) or 'leaked' in s])
    report['ok'] = bool(report['ok']) and code==0 and not report['runtime_errors']
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report))
    return 0 if report['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
