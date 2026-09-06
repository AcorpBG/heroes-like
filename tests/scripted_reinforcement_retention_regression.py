#!/usr/bin/env python3
"""Capacity-safe authored rewards, saved eligibility and fixed recipients.

Python owns disposable Godot probes; fixtures are rule controls, not matches.
"""
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
const Scripts = preload("res://scripts/core/ScenarioScriptRules.gd")
const Heroes = preload("res://scripts/core/HeroCommandRules.gd")
const REWARD := "unit_river_guard"
const UNITS := ["unit_bog_brute","unit_ember_archer","unit_embercourt_fordhook_cadets","unit_embercourt_lantern_sappers","unit_embercourt_bargebow_crews","unit_embercourt_ash_oath_bailiffs","unit_embercourt_lockglass_writcasters"]
var checks := 0
var failures := []
func _ready() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
func state(s) -> Dictionary:
	return JSON.parse_string(JSON.stringify(s.to_dict()))
func full() -> Array:
	var value := []
	for unit in UNITS:
		value.append({"unit_id":unit,"count":10})
	return value
func count(stacks: Array, unit: String = REWARD) -> int:
	var value := 0
	for stack in stacks:
		if stack.unit_id == unit:
			value += int(stack.count)
	return value
func pending(s) -> Dictionary:
	return s.overworld.scenario_script_state.get("pending_reinforcements",{})
func fixture(scenario: String = "stonewake-watch"):
	var s = ScenarioFactory.create_session(scenario,"normal",SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(s)
	Scripts.normalize_script_state(s)
	return s
func earn(s) -> Dictionary:
	s.overworld.resolved_encounters.append("stonewake_reed_totemists")
	return Scripts.process_hooks(s)
func save_resume(s):
	var path: String = SaveService.save_session(s.to_dict(),3)
	var resumed = SessionState.restore_session(SaveService.load_session(3))
	check(path!="" and state(resumed)==state(s),"pending reward changed complete save/resume state")
	return resumed
func hero_cases() -> void:
	var s = fixture()
	var original: String = s.overworld.active_hero_id
	Heroes._set_holder_stacks(s,{},original,full())
	var before: Array = s.overworld.army.stacks.duplicate(true)
	var result := earn(s)
	check(s.overworld.army.stacks==before,"authored reward created an eighth stack")
	check(pending(s).size()==1,"earned authored reward was not retained")
	check("reed_totemist_survivors_rally" in result.fired_ids,"reward hook lost once/chain semantics")
	check(result.message.contains("wait") and Scripts.describe_recent_events(s).contains("wait"),"waiting reward has no existing event-surface explanation")
	var waiting := state(s)
	for attempt in range(3):
		Scripts.process_hooks(s)
	check(state(s)==waiting,"blocked retry changed pending grant or replayed narrative")
	s=save_resume(s)
	s.overworld.resolved_encounters.erase("stonewake_reed_totemists")
	# The earning condition may cease to be true; the earned grant remains.
	Heroes._set_holder_stacks(s,{},original,full().slice(0,6))
	result=Scripts.process_hooks(s)
	check(count(s.overworld.army.stacks)==16 and s.overworld.army.stacks.size()==7,"saved earned grant was lost when its condition ceased")
	check(pending(s).is_empty() and not s.overworld.scenario_script_state.has("pending_reinforcements"),"delivery left a reusable pending receipt")
	check(not result.messages.is_empty(),"successful deferred grant has no delivery event")
	var delivered := state(s)
	Scripts.process_hooks(s)
	check(state(s)==delivered,"earned grant delivered twice")
	# Recipient is the original roster identity, not whichever hero is selected.
	s=fixture();original=s.overworld.active_hero_id
	Heroes._set_holder_stacks(s,{},original,full());earn(s)
	var second: Dictionary = Heroes.active_hero(s).duplicate(true)
	second.id="reward_secondary";second.is_primary=false
	s.overworld.player_heroes.append(second)
	check(Heroes.set_active_hero(s,second.id).get("ok",false),"secondary test hero could not take command")
	var active_before: Dictionary=s.overworld.army.duplicate(true)
	Heroes._set_holder_stacks(s,{},original,full().slice(0,6))
	Scripts.process_hooks(s)
	check(count(Heroes.hero_by_id(s,original).army.stacks)==16 and s.overworld.army==active_before,"deferred grant retargeted the selected hero or corrupted mirrors")
	# Missing and temporarily foreign-controlled recipients must wait, not respawn.
	s=fixture();original=s.overworld.active_hero_id
	Heroes._set_holder_stacks(s,{},original,full());earn(s)
	var roster: Array=s.overworld.player_heroes.duplicate(true)
	s.overworld.player_heroes=[]
	var missing := state(s);Scripts.process_hooks(s)
	check(state(s)==missing,"pending grant recreated or retargeted a missing hero")
	s.overworld.player_heroes=roster
	Heroes._set_holder_stacks(s,{},original,full().slice(0,6))
	var hero: Dictionary=Heroes.hero_by_id(s,original)
	var controller: String=String(hero.get("player_id",""))
	hero.player_id="foreign_controller"
	var foreign := state(s);Scripts.process_hooks(s)
	check(state(s)==foreign,"pending hero grant delivered after control changed")
	if controller=="": hero.erase("player_id")
	else: hero.player_id=controller
	Scripts.process_hooks(s)
	check(count(Heroes.hero_by_id(s,original).army.stacks)==16 and pending(s).is_empty(),"restored original hero control did not release earned grant")
func town_cases() -> void:
	var s=fixture("causeway-stand")
	var town: Dictionary=s.overworld.towns.filter(func(t):return t.placement_id=="duskfen_staging")[0]
	town.garrison=full()
	var money: Dictionary=s.overworld.resources.duplicate(true)
	var recruits: int=int(town.available_recruits.get(REWARD,0))
	s.flags.carryover_pass_cleared=true
	var result: Dictionary=Scripts.process_hooks(s)
	check(town.garrison==full() and pending(s).size()==1,"authored town grant exceeded capacity or lost its manifest")
	check(int(s.overworld.resources.gold)==int(money.gold)+200 and int(town.available_recruits.get(REWARD,0))==recruits+10,"non-garrison effects did not apply exactly once")
	s=save_resume(s)
	town=s.overworld.towns.filter(func(t):return t.placement_id=="duskfen_staging")[0]
	s.flags.carryover_pass_cleared=false
	town.garrison=full().slice(0,6)
	var ownership: Dictionary=town.duplicate(true)
	town.owner="enemy";town.controlling_player_id="foreign_controller"
	var captured:=state(s);Scripts.process_hooks(s)
	check(state(s)==captured,"pending garrison troops delivered to a captor")
	town.owner=ownership.owner
	var foreign_controller:=state(s);Scripts.process_hooks(s)
	check(state(s)==foreign_controller,"pending garrison ignored its original controller when owner class matched")
	if ownership.has("controlling_player_id"): town.controlling_player_id=ownership.controlling_player_id
	else: town.erase("controlling_player_id")
	town.owner="neutral"
	var foreign_owner:=state(s);Scripts.process_hooks(s)
	check(state(s)==foreign_owner,"pending garrison ignored its original owner when controller matched")
	town.owner=ownership.owner
	var towns: Array=s.overworld.towns.duplicate(true)
	s.overworld.towns=[]
	var missing:=state(s);Scripts.process_hooks(s)
	check(state(s)==missing,"pending garrison recreated a missing town")
	s.overworld.towns=towns
	town=s.overworld.towns.filter(func(t):return t.placement_id=="duskfen_staging")[0]
	result=Scripts.process_hooks(s)
	check(count(town.garrison)==32 and town.garrison.size()==7 and pending(s).is_empty(),"original town control restoration did not deliver exactly 32")
	check(int(s.overworld.resources.gold)==int(money.gold)+200 and int(town.available_recruits.get(REWARD,0))==recruits+10,"deferred garrison replayed money or recruit effects")
	var delivered:=state(s);Scripts.process_hooks(s)
	check(state(s)==delivered,"town grant delivered twice")
func fitting_and_legacy_cases() -> void:
	var s=fixture()
	var id: String=s.overworld.active_hero_id
	var army:=full().slice(0,5)
	army.append_array([{"unit_id":REWARD,"count":2,"slot_index":5},{"unit_id":REWARD,"count":3,"slot_index":6}])
	Heroes._set_holder_stacks(s,{},id,army)
	earn(s)
	check(count(s.overworld.army.stacks)==21 and s.overworld.army.stacks.size()==7 and pending(s).is_empty(),"matching split reward lost or multiplied troops")
	s=fixture();id=s.overworld.active_hero_id
	Heroes._set_holder_stacks(s,{},id,full())
	var before:=state(s)
	Scripts._add_army_units(s,{REWARD:3,UNITS[0]:4})
	check(state(s)==before,"atomic multi-unit grant applied a fitting prefix before rejection")
	s.overworld.scenario_script_state.fired_hook_ids.append("reed_totemist_survivors_rally")
	Heroes._set_holder_stacks(s,{},id,full().slice(0,6))
	earn(s)
	check(count(s.overworld.army.stacks)==0 and pending(s).is_empty(),"old fired hook without pending record was retroactively regranted")
	# Matching town additions respect split stacks, with no synthetic pending key.
	var town: Dictionary=s.overworld.towns[0]
	town.garrison=[{"unit_id":REWARD,"count":2,"slot_index":0},{"unit_id":REWARD,"count":3,"slot_index":1}]
	Scripts._town_add_garrison(s,town.placement_id,{REWARD:4})
	check(count(town.garrison)==9 and town.garrison.size()==2 and not s.overworld.scenario_script_state.has("pending_reinforcements"),"fitting split garrison grant changed cardinality or receipt state")
func mixed_effect_case() -> void:
	# Exercise a complete two-type manifest and non-army side effects together,
	# including a chained hook observing the existing once-only fired identity.
	var scenario: Dictionary=ContentService.get_scenario("stonewake-watch").duplicate(true)
	scenario.id="scripted_reward_mixed_control"
	scenario.generated=true;scenario.selection={"availability":{"campaign":false,"skirmish":false}}
	scenario.script_hooks=[{"id":"mixed_reward","conditions":[{"type":"flag_true","flag":"earned_control"}],"effects":[{"type":"add_army_units","units":{REWARD:2,UNITS[0]:3}},{"type":"set_flag","flag":"mixed_once","value":true},{"type":"spawn_resource_node","placement":{"placement_id":"mixed_reward_cache","site_id":"site_waystone_cache","x":4,"y":0}},{"type":"message","text":"Mixed grant control."}]},{"id":"mixed_chain","conditions":[{"type":"hook_fired","hook_id":"mixed_reward"}],"effects":[{"type":"add_resources","resources":{"gold":5}}]}]
	check(ContentService.register_generated_scenario_draft(scenario,{}).get("ok",false),"mixed control registration failed")
	var s=fixture();s.scenario_id=scenario.id;s.flags.earned_control=true
	var id: String=s.overworld.active_hero_id
	Heroes._set_holder_stacks(s,{},id,full())
	var gold: int=s.overworld.resources.gold
	var before: Array=s.overworld.army.stacks.duplicate(true)
	Scripts.process_hooks(s)
	check(s.overworld.army.stacks==before and pending(s).size()==1,"mixed hook partially applied an earned manifest")
	check(s.flags.get("mixed_once",false) and int(s.overworld.resources.gold)==gold+5 and s.overworld.resource_nodes.filter(func(n):return n.placement_id=="mixed_reward_cache").size()==1,"mixed non-army/chain effects were not applied once")
	s=save_resume(s);s.flags.earned_control=false;s.flags.mixed_once=false
	# Unknown saved content suspends the whole grant instead of losing its part.
	var saved: Dictionary=pending(s).duplicate(true)
	pending(s).values()[0].units["missing_content_unit"]=1
	Heroes._set_holder_stacks(s,{},id,full().slice(1,6))
	var invalid:=state(s);Scripts.process_hooks(s)
	check(state(s)==invalid,"unknown saved unit caused partial grant or lost eligibility")
	s.overworld.scenario_script_state.pending_reinforcements=saved
	Scripts.process_hooks(s)
	check(count(s.overworld.army.stacks)==2 and count(s.overworld.army.stacks,UNITS[0])==3 and s.overworld.army.stacks.size()==7 and pending(s).is_empty(),"mixed saved grant did not deliver the complete earned manifest once")
	check(not s.flags.mixed_once and int(s.overworld.resources.gold)==gold+5 and s.overworld.resource_nodes.filter(func(n):return n.placement_id=="mixed_reward_cache").size()==1,"deferred delivery replayed flags, chain resources or spawned content")
	ContentService.unregister_generated_scenario_draft(scenario.id)
func repeatable_case() -> void:
	var scenario: Dictionary=ContentService.get_scenario("stonewake-watch").duplicate(true)
	scenario.id="scripted_reward_repeat_control"
	scenario.generated=true;scenario.selection={"availability":{"campaign":false,"skirmish":false}}
	scenario.script_hooks=[{"id":"repeat_reward","once":false,"conditions":[{"type":"day_at_least","day":1}],"effects":[{"type":"add_army_units","units":{REWARD:2}},{"type":"add_resources","resources":{"gold":3}},{"type":"message","text":"Repeat control."}]}]
	check(ContentService.register_generated_scenario_draft(scenario,{}).get("ok",false),"repeatable control registration failed")
	var s=fixture();s.scenario_id=scenario.id
	var id: String=s.overworld.active_hero_id
	Heroes._set_holder_stacks(s,{},id,full())
	var gold: int=s.overworld.resources.gold
	Scripts.process_hooks(s)
	var waiting:=state(s)
	for attempt in range(5): Scripts.process_hooks(s)
	check(pending(s).size()==1 and state(s)==waiting,"repeatable hook accumulated pending armies or repeated other effects while blocked")
	Heroes._set_holder_stacks(s,{},id,full().slice(0,6))
	Scripts.process_hooks(s)
	check(count(s.overworld.army.stacks)==2 and int(s.overworld.resources.gold)==gold+3 and pending(s).is_empty(),"repeatable hook refired in its pending delivery pass")
	Scripts.process_hooks(s)
	check(count(s.overworld.army.stacks)==4 and int(s.overworld.resources.gold)==gold+6,"repeatable hook could not earn its next ordinary invocation")
	ContentService.unregister_generated_scenario_draft(scenario.id)
func run() -> void:
	hero_cases()
	town_cases()
	fitting_and_legacy_cases()
	mixed_effect_case()
	repeatable_case()
	print("SCRIPTED_REINFORCEMENT_RETENTION "+JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--label', required=True)
    args = parser.parse_args()
    if not args.label or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789_-' for c in args.label):
        parser.error('label must be a fresh lowercase slug')
    out = OUTPUT / args.label
    out.mkdir(parents=True, exist_ok=False)
    with tempfile.TemporaryDirectory(prefix='scripted-reward-', dir=OUTPUT) as temporary:
        work = Path(temporary)
        script = work / 'probe.gd'
        script.write_text(SCRIPT)
        scene = work / 'probe.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="ScriptedRewards" type="Node"]\nscript = ExtResource("1")\n' % script.relative_to(ROOT))
        with (out / 'runtime.log').open('w') as log:
            code = run_probe(['godot4', '--path', str(ROOT), '--headless', '--audio-driver', 'Dummy', 'res://' + str(scene.relative_to(ROOT))], dict(os.environ, XDG_DATA_HOME=str(out / 'data')), log)
    lines = (out / 'runtime.log').read_text().splitlines()
    marker = 'SCRIPTED_REINFORCEMENT_RETENTION '
    reports = [json.loads(line[len(marker):]) for line in lines if line.startswith(marker)]
    report = reports[-1] if reports else {'ok': False, 'failures': ['missing report']}
    owners = ['scripts/core/ScenarioScriptRules.gd', 'scripts/core/HeroCommandRules.gd', 'tests/scripted_reinforcement_retention_regression.py']
    report.update(returncode=code, source_hashes={p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in owners}, runtime_errors=[s for s in lines if s.startswith(('ERROR:', 'SCRIPT ERROR:')) or 'leaked' in s])
    report['ok'] = bool(report['ok']) and code == 0 and not report['runtime_errors']
    (out / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report))
    return 0 if report['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
