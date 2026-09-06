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
func reinforcement_cases() -> void:
	var f := fixture();var s = f.session
	var before := state(s)
	var accepted := Turns._apply_reinforcement_to_raid(s,0,NEW_UNIT,5)
	check(accepted==0,"raid reinforcement accepted an eighth stack")
	check(state(s)==before,"rejected raid reinforcement changed gameplay state")
	f = fixture();s = f.session
	accepted = Turns._apply_reinforcement_to_raid(s,0,UNITS[0],5)
	check(accepted==5 and s.overworld.encounters[0].enemy_army.stacks.size()==7 and total(s.overworld.encounters[0].enemy_army.stacks)==75,"matching raid reinforcement did not add exactly five")
	f = fixture();s = f.session
	var entry: Dictionary = f.enemy.commander_roster[0]
	var hero_id: String = entry.roster_hero_id
	var commander: Dictionary = AI.build_roster_commander_state(hero_id,FACTION,entry.get("commander_state",{}),entry)
	commander = AI.sync_commander_army_continuity(commander,{"stacks":stacks(10)},"encounter_mire_raid")
	AI.sync_commander_state_to_roster(s,FACTION,commander,AI.COMMANDER_STATUS_AVAILABLE,"",-1,"")
	before = state(s)
	accepted = AI.reinforce_commander_roster_army(s,FACTION,hero_id,NEW_UNIT,5,"encounter_mire_raid",100000)
	check(accepted==0,"roster reinforcement accepted an eighth stack")
	check(state(s)==before,"rejected roster reinforcement changed gameplay state")
	# The complete paid recruit owner must not consume money or reserves.
	f = fixture();s = f.session
	s.overworld.encounters = []
	f.town.garrison = stacks()
	f.town.available_recruits = {NEW_UNIT:5}
	var treasury := {"gold":100000,"wood":1000,"ore":1000,"peatwax":1000}
	var treasury_before: Dictionary = treasury.duplicate(true)
	var reserves: Dictionary = f.town.available_recruits.duplicate(true)
	var result: Dictionary = Turns._recruit_town_forces(s,f.config,f.town,treasury,FACTION)
	findings.paid = {"garrisoned":result.garrisoned,"raid_batches":result.raid_batches,"planned_batches":result.planned_batches,"mobilized_batches":result.mobilized_batches}
	check(not result.garrisoned,"paid garrison recruitment accepted an eighth stack")
	check(treasury==treasury_before and result.town.available_recruits==reserves,"rejected paid recruitment consumed treasury or reserves")
func claim_cases() -> void:
	for opportunistic in [false,true]:
		var f := fixture();var s = f.session
		var node := {"placement_id":"capacity_claim","site_id":"site_free_company_yard","x":6,"y":2,"collected":false}
		s.overworld.resource_nodes = [node]
		f.raid.target_kind = "resource";f.raid.target_placement_id = node.placement_id
		OverworldRules.invalidate_spatial_lookup(s)
		var before := state(s)
		var raid_before: Dictionary = f.raid.duplicate(true)
		var result: Dictionary
		if opportunistic:
			result = AI._secure_opportunistic_route_resource(s,f.config,f.raid,f.enemy,FACTION,0,node,ContentService.get_resource_site(node.site_id))
		else:
			result = AI._secure_resource_target(s,f.raid,f.enemy,FACTION,f.config)
		check(state(s)==before,"full army claim consumed site rewards/state; opportunistic="+str(opportunistic))
		check(result.encounter==raid_before,"full army claim mutated raiding army; opportunistic="+str(opportunistic))
func handoff_cases() -> void:
	var f := fixture();var s = f.session
	f.town.garrison = [{"unit_id":NEW_UNIT,"count":5}]
	var town_index: int = s.overworld.towns.find(f.town)
	var before := state(s)
	var raid_before: Dictionary = f.raid.duplicate(true)
	var result: Dictionary = AI._transfer_town_garrison_to_raid(s,town_index,f.raid,100000)
	check(result.transferred_count==0,"resupply accepted an eighth raid stack")
	check(state(s)==before and result.raid==raid_before,"rejected resupply lost or changed source troops")
	f = fixture();s = f.session
	f.town.garrison = stacks()
	f.raid.enemy_army.stacks = [{"unit_id":NEW_UNIT,"count":5}]
	f.raid.target_placement_id = f.town.placement_id
	before = state(s);raid_before = f.raid.duplicate(true)
	result = AI._defend_town_target(s,f.raid,f.enemy,FACTION)
	check(state(s)==before and result.encounter==raid_before,"full Town handoff retired its commander or consumed troops")
	check(f.town.garrison.size()==7,"Town defense handoff exceeded capacity")
	f = fixture();s = f.session
	var donor: Dictionary = f.raid.duplicate(true)
	donor.placement_id = "capacity_support"
	donor.enemy_army.stacks = [{"unit_id":NEW_UNIT,"count":5}]
	s.overworld.encounters.append(donor)
	before = state(s);raid_before = f.raid.duplicate(true)
	result = AI.group_nearby_raids_for_town_assault(s,f.config,s.overworld.encounters,0,f.raid,FACTION,s.overworld.resolved_encounters)
	check(not result.grouped,"army consolidation accepted an eighth stack")
	check(state(s)==before and result.encounter==raid_before,"rejected consolidation consumed donor or changed commanders")
func fitting_controls() -> void:
	var f := fixture();var s = f.session
	f.town.garrison = [{"unit_id":NEW_UNIT,"count":5,"slot_index":3},{"unit_id":UNITS[0],"count":4,"slot_index":5}]
	var result := AI._transfer_town_garrison_to_raid(s,s.overworld.towns.find(f.town),f.raid,100000)
	check(result.transferred_count==4 and total(result.raid.enemy_army.stacks)==74,"partial resupply did not accept the matching stack exactly")
	check(f.town.garrison==[{"unit_id":NEW_UNIT,"count":5,"slot_index":3}],"partial resupply did not retain rejected source stack and slot")
	f = fixture();s = f.session
	f.town.garrison = stacks();f.raid.enemy_army.stacks = [{"unit_id":UNITS[0],"count":5}]
	f.raid.target_placement_id = f.town.placement_id
	f.raid.enemy_commander_state = commander(f,f.raid.enemy_army.stacks)
	f.raid.commanderless_support_column = false
	var hero_id: String = f.raid.enemy_commander_state.roster_hero_id
	result = AI._defend_town_target(s,f.raid,f.enemy,FACTION)
	check(f.town.garrison.size()==7 and total(f.town.garrison)==12,"fitting defense did not transfer exactly five troops")
	check(result.encounter.enemy_army.stacks.is_empty() and f.raid.placement_id in s.overworld.resolved_encounters,"successful defense did not resolve the donated field host")
	check(String(f.town.get("ai_defender_roster_hero_id",""))==hero_id,"fitting defense did not station the actual commander")
	f = fixture();s = f.session
	f.town.garrison = stacks();f.raid.enemy_army.stacks = [{"unit_id":UNITS[0],"count":3},{"unit_id":NEW_UNIT,"count":5}]
	f.raid.target_placement_id = f.town.placement_id
	f.raid.enemy_commander_state = commander(f,f.raid.enemy_army.stacks)
	f.raid.commanderless_support_column = false
	var before := state(s);var raid_before: Dictionary = f.raid.duplicate(true)
	result = AI._defend_town_target(s,f.raid,f.enemy,FACTION)
	check(state(s)==before and result.encounter==raid_before,"atomic defense lost a real commander or applied a fitting prefix before rejection")
	f = fixture();s = f.session
	var donor: Dictionary = f.raid.duplicate(true)
	donor.placement_id = "compatible_support";donor.enemy_army.stacks = [{"unit_id":UNITS[0],"count":5}]
	var blocked: Dictionary = donor.duplicate(true)
	blocked.placement_id = "incompatible_support";blocked.enemy_army.stacks = [{"unit_id":NEW_UNIT,"count":50}]
	s.overworld.encounters.append_array([blocked,donor])
	result = AI.group_nearby_raids_for_town_assault(s,f.config,s.overworld.encounters,0,f.raid,FACTION,s.overworld.resolved_encounters)
	check(result.grouped and result.get("donor_placement_id","")==donor.placement_id and total(result.encounter.enemy_army.stacks)==75,"grouping did not select the fitting donor past an incompatible donor")
	check(blocked.placement_id not in s.overworld.resolved_encounters and blocked.enemy_army.stacks[0].count==50,"grouping consumed the rejected donor")
	for opportunistic in [false,true]:
		f = fixture();s = f.session
		f.raid.enemy_army.stacks = [{"unit_id":UNITS[0],"count":10}]
		var node := {"placement_id":"capacity_claim","site_id":"site_free_company_yard","x":6,"y":2,"collected":false}
		s.overworld.resource_nodes = [node]
		f.raid.target_kind = "resource";f.raid.target_placement_id = node.placement_id
		OverworldRules.invalidate_spatial_lookup(s)
		var site := ContentService.get_resource_site(node.site_id)
		var expected := AI._resource_site_claim_recruits(site)
		expected[UNITS[0]] = int(expected.get(UNITS[0],0))+10
		if opportunistic:
			result = AI._secure_opportunistic_route_resource(s,f.config,f.raid,f.enemy,FACTION,0,node,site)
		else:
			result = AI._secure_resource_target(s,f.raid,f.enemy,FACTION,f.config)
		check(manifest(result.encounter.enemy_army.stacks)==expected,"fitting site claim lost or duplicated recruits; opportunistic="+str(opportunistic))
		check(s.overworld.resource_nodes[0].collected,"fitting site claim did not record collection")
	f = fixture();s = f.session
	f.town.owner = "neutral";f.town.garrison = []
	f.town.erase("controller_id");f.town.erase("player_id")
	f.raid.target_placement_id = f.town.placement_id
	result = AI._secure_neutral_town_target(s,f.raid,f.enemy,FACTION)
	var captured: Dictionary = s.overworld.towns.filter(func(t):return t.placement_id==f.town.placement_id)[0]
	check(captured.owner=="enemy" and total(captured.garrison)==70 and captured.garrison.size()==7,"neutral Town capture did not preserve all seven stacks")
	check(result.encounter.enemy_army.stacks.is_empty(),"neutral Town capture retained a duplicate field army")
	f = fixture();s = f.session
	var c := commander(f,stacks(10))
	AI.sync_commander_state_to_roster(s,FACTION,c,AI.COMMANDER_STATUS_AVAILABLE,"",-1,"")
	check(AI.reinforce_commander_roster_army(s,FACTION,c.roster_hero_id,UNITS[0],5,"encounter_mire_raid",100000)==5,"matching roster reinforcement was incorrectly blocked")
	f = fixture();s = f.session
	s.overworld.encounters=[];f.town.garrison=stacks();f.town.available_recruits={UNITS[0]:5}
	var treasury := {"gold":100000,"wood":1000,"ore":1000,"peatwax":1000}
	result = Turns._recruit_town_forces(s,f.config,f.town,treasury,FACTION)
	check(result.garrisoned and total(result.town.garrison)==12 and result.town.garrison.size()==7,"matching paid garrison reinforcement did not add exactly five")
	check(int(treasury.gold)<100000 and int(result.town.available_recruits.get(UNITS[0],0))==0,"successful paid recruitment did not charge or consume reserve")
func selection_cases() -> void:
	var f := fixture();var s = f.session
	var node := {"placement_id":"capacity_claim","site_id":"site_free_company_yard","x":6,"y":2,"collected":false}
	s.overworld.resource_nodes=[node]
	f.config.priority_target_placement_ids=[node.placement_id];f.config.siege_target_placement_id=""
	f.raid.target_kind="resource";f.raid.target_placement_id=node.placement_id
	OverworldRules.invalidate_spatial_lookup(s)
	check(not AI._raid_target_valid(s,f.raid),"full-army recruit site target remains valid")
	check(AI._current_tile_resource_target_selection_plan(s,f.config,f.raid,FACTION).is_empty(),"full-army current-tile recruit target still selected")
	check(AI._current_tile_contestable_resource_id(s,f.raid,FACTION)=="","full-army site incorrectly prevents regroup")
	check(AI._explicit_objective_fallback_target_selection_plan(s,f.config,f.raid,FACTION).is_empty(),"explicit fallback reselects infeasible recruit site")
	var task := {"target_kind":"resource","target_id":node.placement_id,"actor_id":"capacity_actor","task_class":"contest_site"}
	check(AI._ai_hero_task_plan_from_saved_task(s,f.config,f.raid,task,Vector2i(6,2),f.raid.placement_id).is_empty(),"saved task reselects infeasible recruit site")
	check(AI._ai_hero_task_live_plan_from_task(s,f.raid,task,{},Vector2i(6,2)).is_empty(),"live task reselects infeasible recruit site")
	var selected := AI.choose_target(s,f.config,{"x":6,"y":2},f.raid)
	check(selected.get("target_placement_id","")!=node.placement_id,"ordinary chooser reselects infeasible recruit site")
	selected = AI.assign_target(s,f.config,f.raid.duplicate(true))
	check(selected.get("target_placement_id","")!=node.placement_id,"assignment retains blocked recruit site")
	f.raid.enemy_army.stacks=[{"unit_id":UNITS[0],"count":70}]
	check(AI._raid_target_valid(s,f.raid),"fitting recruit site target invalid")
	check(not AI._current_tile_resource_target_selection_plan(s,f.config,f.raid,FACTION).is_empty(),"fitting current-tile recruit target disappeared")
	f = fixture();s = f.session
	f.town.garrison=stacks();f.raid.enemy_army.stacks=[{"unit_id":NEW_UNIT,"count":50}]
	f.raid.target_placement_id=f.town.placement_id;f.raid.target_reason_codes=["town_defense"]
	check(not AI._raid_target_valid(s,f.raid),"full Town defense target remains valid")
	f.raid.enemy_army.stacks=[{"unit_id":UNITS[0],"count":50}]
	check(AI._raid_target_valid(s,f.raid),"fitting Town defense target invalid")
func continuity_controls() -> void:
	var f := fixture();var s = f.session
	f.raid.enemy_commander_state=commander(f,stacks(10))
	f.raid.commanderless_support_column=false
	f.raid.erase("enemy_army")
	check(manifest(AI._raid_reinforcement_army(f.raid).get("stacks",[]))==manifest(stacks(10)),"admission substituted starter troops for saved commander continuity")
	var donor: Dictionary=f.raid.duplicate(true)
	donor.enemy_army={"stacks":[{"unit_id":NEW_UNIT,"count":5}]}
	check(AI._merged_raid_army_payload(f.raid,donor).is_empty(),"continuity-only leader admitted an incompatible donor")
	donor.enemy_army.stacks=[{"unit_id":UNITS[0],"count":5}]
	check(total(AI._merged_raid_army_payload(f.raid,donor).get("stacks",[]))==75,"continuity-only leader lost saved troops during fitting merge")
	var node := {"placement_id":"continuity_claim","site_id":"site_free_company_yard","x":6,"y":2,"collected":false}
	s.overworld.resource_nodes=[node]
	f.raid.target_kind="resource";f.raid.target_placement_id=node.placement_id
	OverworldRules.invalidate_spatial_lookup(s)
	var before:=state(s);var raid_before:Dictionary=f.raid.duplicate(true)
	var result:=AI._secure_resource_target(s,f.raid,f.enemy,FACTION,f.config)
	check(state(s)==before and result.encounter==raid_before,"continuity-only claim consumed rewards or overwrote saved troops")
	f.config.priority_target_placement_ids=[node.placement_id];f.config.siege_target_placement_id=""
	check(AI.choose_target(s,f.config,{"x":6,"y":2},f.raid).get("target_placement_id","")!=node.placement_id,"continuity-only chooser reselects an infeasible site")
	check(AI.assign_target(s,f.config,f.raid.duplicate(true)).get("target_placement_id","")!=node.placement_id,"continuity-only assignment retains an infeasible site")
	f.town.garrison=[{"unit_id":NEW_UNIT,"count":5}]
	before=state(s)
	result=AI._transfer_town_garrison_to_raid(s,s.overworld.towns.find(f.town),f.raid,100000)
	check(result.transferred_count==0 and state(s)==before and result.raid==raid_before,"continuity-only resupply overwrote saved troops or consumed rejected source")
	for neutral in [false,true]:
		f=fixture();s=f.session
		f.raid.enemy_commander_state=commander(f,stacks(10))
		f.raid.commanderless_support_column=false;f.raid.erase("enemy_army")
		f.raid.target_placement_id=f.town.placement_id
		f.town.garrison=[]
		if neutral:
			f.town.owner="neutral";f.town.erase("controller_id");f.town.erase("player_id")
			result=AI._secure_neutral_town_target(s,f.raid,f.enemy,FACTION)
		else:
			result=AI._defend_town_target(s,f.raid,f.enemy,FACTION)
		var town:Dictionary=s.overworld.towns.filter(func(t):return t.placement_id==f.town.placement_id)[0]
		check(total(town.garrison)==70 and town.garrison.size()==7 and result.encounter.enemy_army.stacks.is_empty(),"continuity-only Town handoff lost or duplicated saved troops; neutral="+str(neutral))
func run() -> void:
	reinforcement_cases()
	claim_cases()
	handoff_cases()
	fitting_controls()
	selection_cases()
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
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="AiCapacity" type="Node"]\nscript = ExtResource("1")\n' % script.relative_to(ROOT))
        env = dict(os.environ,XDG_DATA_HOME=str(out/'data'))
        if args.generated_case:
            env['AI_CAPACITY_GENERATED_CONFIG'] = json.dumps(CASES[args.generated_case])
        command = ['godot4','--path',str(ROOT),'--headless','--audio-driver','Dummy','res://'+str(scene.relative_to(ROOT))]
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
