#!/usr/bin/env python3
"""Exact original commander entries/raid state and single-entry work controls."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

from ai_path_context_read_regression import instrument
from generated_town_order_profile import ROOT, OUTPUT, run_probe

REFERENCE = '597ea8503c42ca59ad2954c4748bc8a48ac06b1e'
OWNER = 'scripts/core/EnemyAdventureRules.gd'
METHODS = ['normalize_commander_roster', 'build_roster_commander_state', 'build_raid_commander_state']
SCRIPT = r'''
extends Node
var original
var current
var checks := 0
var errors := []
var rows := []
var require_projection := false
func _ready() -> void:
	call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		errors.append(label)
func projected(session, faction: String, roster, hero: String) -> Dictionary:
	if current.has_method("_normalize_commander_roster_entry"):
		return current._normalize_commander_roster_entry(session,faction,roster,hero)
	return current._commander_roster_entry(current.normalize_commander_roster(session,faction,roster),hero)
func compare(session, faction: String, roster, hero: String, encounter: Dictionary, label: String) -> Dictionary:
	# to_dict deeply detaches all mutable fields; compare every value without
	# repeatedly stringifying a complete Large world solely for this assertion.
	var before: Dictionary = session.to_dict() if session!=null else {}
	var inputs := JSON.stringify([roster,encounter])
	var old_roster: Array = original.normalize_commander_roster(session,faction,roster)
	check(old_roster==current.normalize_commander_roster(session,faction,roster),label+": complete full roster")
	var old_entry: Dictionary = original._commander_roster_entry(old_roster,hero)
	check(old_entry==projected(session,faction,roster,hero),label+": exact projected entry")
	original.measured_reads.clear()
	current.measured_reads.clear()
	var old: Dictionary = original.build_raid_commander_state(encounter,hero,faction,session,{},roster)
	var now: Dictionary = current.build_raid_commander_state(encounter,hero,faction,session,{},roster)
	check(old==now,label+": complete raid commander state")
	if require_projection and not encounter.is_empty() and hero!="":
		check(int(current.measured_reads.get("normalize_commander_roster",{}).get("count",0))==0,label+": explicit commander does not normalize unrelated entries")
		check(int(current.measured_reads.get("build_roster_commander_state",{}).get("count",0))<=2,label+": at most selected entry plus raid seed")
	check(inputs==JSON.stringify([roster,encounter]),label+": caller inputs unchanged")
	check(before==(session.to_dict() if session!=null else {}),label+": complete session unchanged")
	rows.append({"label":label,"original":original.measured_reads.duplicate(true),"current":current.measured_reads.duplicate(true)})
	return old_entry
func raid(faction: String, hero: String) -> Dictionary:
	return {"placement_id":"projection_raid","encounter_id":"missing_projection_encounter","spawned_by_faction_id":faction,"enemy_commander_state":{"roster_hero_id":hero}}
func empty_session():
	var session = ScenarioFactory.create_session("three-hearth-auxiliary-charter","normal",SessionState.LAUNCH_MODE_SKIRMISH)
	for key in ["encounters","towns","resource_nodes","enemy_states","resolved_encounters","players"]:
		session.overworld[key] = []
	return session
func catalog() -> void:
	var session = empty_session()
	for faction in ContentService.get_content_ids(ContentService.FACTIONS_PATH):
		var roster: Array = original.normalize_commander_roster(session,faction,[])
		for hero in original._faction_commander_ids(faction):
			compare(session,faction,roster,hero,raid(faction,hero),"catalog "+hero)
			compare(null,faction,roster,hero,raid(faction,hero),"null session "+hero)
		compare(session,faction,roster,"",raid(faction,""),"automatic selection "+faction)
		compare(session,faction,roster,"missing_projection_hero",raid(faction,"missing_projection_hero"),"unknown hero "+faction)
func boundaries() -> void:
	var session = empty_session()
	var faction := "faction_embercourt"
	var hero := String(original._faction_commander_ids(faction)[0])
	var first := {"roster_hero_id":hero,"status":"recovering","recovery_day":session.day+3,"commander_state":{"name":"First record","experience":749,"level":2,"spellbook":{"known_spell_ids":[],"mana":{"current":1,"max":8}}}}
	var last := first.duplicate(true)
	last.commander_state.name = "Last record"
	last.commander_state.experience = 1250
	var duplicate := [null,1,{},first,{"roster_hero_id":""},last]
	var selected := compare(session,faction,duplicate,hero,raid(faction,hero),"last duplicate wins")
	check(selected.commander_state.name=="Last record","positive last-duplicate input precedence")
	check(selected.status=="recovering","future recovery preserved")
	for value in [[],null,"invalid",{},[null,1,{}]]:
		compare(session,faction,value,hero,raid(faction,hero),"malformed/empty roster "+JSON.stringify(value))
	compare(session,"",duplicate,hero,raid("",hero),"empty faction")
	compare(session,"missing_faction",duplicate,hero,raid("missing_faction",hero),"unknown faction")
	compare(session,faction,duplicate,hero,{},"empty encounter")
	var fallback_raid := raid(faction,hero)
	fallback_raid.enemy_commander_state = "invalid"
	compare(session,faction,duplicate,hero,fallback_raid,"malformed encounter commander")
	session.overworld.enemy_states = [{"faction_id":faction,"commander_roster":duplicate}]
	compare(session,faction,null,hero,raid(faction,hero),"nonarray roster uses live fallback in raid builder")
	last.commander_state.name = "Changed record"
	check(compare(session,faction,duplicate,hero,raid(faction,hero),"fresh changed input").commander_state.name=="Changed record","no stale entry retained")
	session.day += 4
	check(compare(session,faction,duplicate,hero,raid(faction,hero),"recovery deadline").status=="available","recovery expiry immediately reflected")
	ContentService.clear_cache()
	compare(session,faction,duplicate,hero,raid(faction,hero),"content reload")
func defenders() -> void:
	var session = empty_session()
	var faction := "faction_embercourt"
	var hero := String(original._faction_commander_ids(faction)[0])
	var roster: Array = original.normalize_commander_roster(session,faction,[])
	var active := raid(faction,hero)
	active.enemy_commander_state.name = "Field commander"
	session.overworld.enemy_states = [{"faction_id":faction,"commander_roster":roster}]
	session.overworld.encounters = [active]
	check(compare(session,faction,roster,hero,active,"active raid").active_placement_id=="projection_raid","positive field commander presence")
	var town := {"placement_id":"projection_town","town_id":"town_embercourt_ashford","owner":"enemy","faction_id":faction,"x":1,"y":1,"front":{"state":"defend","faction_id":faction,"defense_until_day":session.day+3},"ai_defended_by_faction_id":faction,"ai_defense_until_day":session.day+3,"ai_defender_commander_state":{"roster_hero_id":hero,"name":"Town commander"}}
	session.overworld.towns = [town]
	check(compare(session,faction,roster,hero,active,"town overrides field").active_placement_id=="town_defense:projection_town","positive town precedence")
	var node := {"placement_id":"projection_resource","site_id":"site_brightwood_sawmill","collected_by_faction_id":faction,"ai_defended_by_faction_id":faction,"ai_defense_until_day":session.day+3,"ai_defender_commander_state":{"roster_hero_id":hero,"name":"Resource commander"}}
	session.overworld.resource_nodes = [node]
	check(compare(session,faction,roster,hero,active,"resource overrides town and field").active_placement_id=="resource_defense:projection_resource","positive resource precedence")
	var replacement := node.duplicate(true)
	replacement.placement_id = "projection_last_resource"
	session.overworld.resource_nodes.append(replacement)
	check(compare(session,faction,roster,hero,active,"last resource wins").active_placement_id=="resource_defense:projection_last_resource","last active-map duplicate wins")
	session.day += 4
	check(compare(session,faction,roster,hero,active,"expired defenders").active_placement_id=="projection_raid","expired defenders no longer override field")
	session.overworld.resolved_encounters = ["projection_raid"]
	check(compare(session,faction,roster,hero,active,"resolved field").status=="available","resolved field commander not active")
	session.overworld.resolved_encounters = []
	session.overworld.players = [{"player_id":"p1","faction_id":faction,"team_id":"one"},{"player_id":"p2","faction_id":faction,"team_id":"two"}]
	active.spawned_by_player_id = "p1"
	var other := active.duplicate(true)
	other.placement_id = "other_controller_raid"
	other.spawned_by_player_id = "p2"
	other.enemy_commander_state.name = "Other controller"
	session.overworld.encounters.append(other)
	check(compare(session,"p1",roster,hero,active,"same faction first controller").active_placement_id=="projection_raid","same faction does not share first active commander")
	check(compare(session,"p2",roster,hero,other,"same faction second controller").active_placement_id=="other_controller_raid","same faction does not share second active commander")
func actual_saved_case() -> void:
	var path := OS.get_environment("COMMANDER_ENTRY_SAVE")
	if path=="":
		return
	var session = SessionState.restore_session(JSON.parse_string(FileAccess.get_file_as_string(path)))
	for config in EnemyTurnRules._enemy_faction_configs_for_session(session):
		var faction := String(original.PlayerRules.controller_id(config))
		var roster: Array = original.commander_roster_for_faction(session,faction)
		for hero in original._faction_commander_ids(original.PlayerRules.faction_id(session,faction)):
			compare(session,faction,roster,hero,raid(faction,hero),"actual saved "+faction+" "+hero)
	for encounter in session.overworld.get("encounters",[]):
		if encounter is Dictionary and original.PlayerRules.raid_controller_id(encounter)!="":
			var faction: String = original.PlayerRules.raid_controller_id(encounter)
			var hero := String(encounter.get("enemy_commander_state",{}).get("roster_hero_id",""))
			compare(session,faction,null,hero,encounter,"actual raid "+String(encounter.get("placement_id","")))
func run() -> void:
	original = load(OS.get_environment("COMMANDER_ENTRY_ORIGINAL"))
	current = load(OS.get_environment("COMMANDER_ENTRY_CURRENT"))
	require_projection = OS.get_environment("COMMANDER_ENTRY_REQUIRE_PROJECTION")=="1"
	catalog()
	boundaries()
	defenders()
	actual_saved_case()
	print("AI_COMMANDER_ENTRY_PROJECTION "+JSON.stringify({"ok":errors.is_empty(),"checks":checks,"errors":errors,"rows":rows}))
	get_tree().quit(0 if errors.is_empty() else 1)
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--label', required=True)
    parser.add_argument('--save', type=Path)
    parser.add_argument('--require-projection', action='store_true')
    args = parser.parse_args()
    if not re.fullmatch('[a-z0-9_-]+', args.label):
        parser.error('label must be a fresh lowercase slug')
    out = OUTPUT/args.label
    out.mkdir(parents=True, exist_ok=False)
    original = subprocess.check_output(['git','show',f'{REFERENCE}:{OWNER}'],cwd=ROOT).decode()
    current = (ROOT/OWNER).read_text()
    saved = args.save.read_bytes() if args.save else None
    if saved:
        json.loads(saved)
        (out/'input_save.json').write_bytes(saved)
    with tempfile.TemporaryDirectory(prefix='commander-entry-',dir=OUTPUT) as temp:
        work = Path(temp)
        for name, source in [('original',original),('current',current)]:
            (work/(name+'.gd')).write_text(instrument(source,methods=METHODS,terrain=False))
        (work/'probe.gd').write_text(SCRIPT)
        scene = work/'probe.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="CommanderEntry" type="Node"]\nscript = ExtResource("1")\n' % (work/'probe.gd').relative_to(ROOT))
        env = dict(os.environ,XDG_DATA_HOME=str(out/'data'),COMMANDER_ENTRY_ORIGINAL='res://'+str((work/'original.gd').relative_to(ROOT)),COMMANDER_ENTRY_CURRENT='res://'+str((work/'current.gd').relative_to(ROOT)),COMMANDER_ENTRY_SAVE=str(out/'input_save.json') if saved else '',COMMANDER_ENTRY_REQUIRE_PROJECTION='1' if args.require_projection else '0')
        with (out/'runtime.log').open('w') as log:
            code = run_probe(['godot4','--headless','--path',str(ROOT),'--audio-driver','Dummy','--accessibility','disabled','res://'+str(scene.relative_to(ROOT))],env,log)
    lines = (out/'runtime.log').read_text().splitlines()
    marker = 'AI_COMMANDER_ENTRY_PROJECTION '
    reports = [json.loads(line[len(marker):]) for line in lines if line.startswith(marker)]
    report = reports[-1] if reports else {'ok':False,'errors':['missing report']}
    report.update(returncode=code,reference_revision=REFERENCE,reference_sha256=hashlib.sha256(original.encode()).hexdigest(),current_sha256=hashlib.sha256(current.encode()).hexdigest(),save_sha256=hashlib.sha256(saved).hexdigest() if saved else None,runtime_errors=[line for line in lines if line.startswith(('ERROR:','SCRIPT ERROR:')) or 'leaked' in line])
    report['ok'] = bool(report['ok']) and code==0 and not report['runtime_errors']
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k!='rows'}))
    return 0 if report['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
