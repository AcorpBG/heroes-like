#!/usr/bin/env python3
"""Real generated-save regression plus explicitly detached ownership fixtures."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import tempfile

from generated_full_match_quality import ROOT, OUTPUT
from generated_town_order_profile import run_probe, stop_requested

MARKER = 'GENERATED_RIVAL_OBJECTIVE_REPORT '


def runtime_source_tree_sha256():
    paths = sorted(set(ROOT.glob('scripts/**/*.gd')) | set(ROOT.glob('scenes/**/*.gd')) | set(ROOT.glob('scenes/**/*.tscn')) | set(ROOT.glob('content/*.json')) | {ROOT/'project.godot'})
    hashes = {str(path.relative_to(ROOT)):hashlib.sha256(path.read_bytes()).hexdigest() for path in paths}
    return hashlib.sha256(json.dumps(hashes,sort_keys=True).encode()).hexdigest()


SCRIPT = r'''
extends Node
const Scenario = preload("res://scripts/core/ScenarioRules.gd")
const Generated = preload("res://scripts/core/GeneratedScenarioObjectiveRules.gd")
const Store = preload("res://scripts/core/SessionStateStore.gd")
const Setup = preload("res://scripts/core/ScenarioSelectRules.gd")
const Battle = preload("res://scripts/core/BattleRules.gd")
const Resolve = preload("res://scripts/core/BattleAutoResolveRules.gd")
var checks := 0
var failures := []
var observations := []
func _ready() -> void:
	call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures.append(message)
func state(session) -> String:
	return JSON.stringify(session.to_dict())
func restored(payload: Dictionary):
	var session = SessionState.restore_session(payload.duplicate(true))
	OverworldRules.normalize_overworld_state(session)
	return session
func presence_fixture():
	# Small detached rule fixtures, never counted as completed generated matches.
	var fixture = Store.new_session_data()
	fixture.day = 5
	fixture.overworld = {"players":[
		{"player_id":"player_1","faction_id":"faction_embercourt","team_id":"team_1","human":true},
		{"player_id":"player_2","faction_id":"faction_embercourt","team_id":"team_2","human":false},
		{"player_id":"player_3","faction_id":"faction_veilmourn","team_id":"team_1","human":false}],
		"active_player_id":"player_1","towns":[],"encounters":[],"resource_nodes":[],"resolved_encounters":[]}
	return fixture
func presence_check(fixture, label: String, known: bool, complete: bool) -> Dictionary:
	var before := state(fixture)
	var result: Dictionary = Generated.progress(fixture)
	check(bool(result.known)==known,label+": wrong ownership validity")
	check(bool(result.complete)==complete,label+": wrong conquest result")
	check(state(fixture)==before,label+": presence read mutated state")
	observations.append({"fixture":label,"progress":result})
	return result
func ownership_fixtures() -> void:
	var f = presence_fixture()
	var r := presence_check(f,"detached empty rival has no surviving forces",true,true)
	check(r.total==1 and r.defeated==1,"same faction rivals were pooled or ally counted")
	f.overworld.towns=[{"owner":"enemy","controlling_player_id":"player_2","faction_id":"faction_embercourt","level":1}]
	r=presence_check(f,"same faction rival town on another level",true,false)
	check(r.remaining[0].presence.towns==1,"rival town not counted")
	f.overworld.towns[0].controlling_player_id="player_3"
	presence_check(f,"different faction allied town",true,true)
	f.overworld.towns[0].owner="neutral"
	f.overworld.towns[0].controlling_player_id="player_2"
	presence_check(f,"neutral faction scenery is not ownership",true,true)
	f.overworld.towns[0].owner="player"
	presence_check(f,"contradictory human town owner",false,false)
	f.overworld.towns[0].owner="enemy"
	f.overworld.towns[0].controlling_player_id="unknown"
	presence_check(f,"unknown town controller",false,false)
	f.overworld.towns=[]
	var host := {"placement_id":"remaining_raid","spawned_by_player_id":"player_2","spawned_by_faction_id":"faction_embercourt","days_active":1,"level":1,"enemy_commander_state":{"player_id":"player_2","roster_hero_id":"fixture_commander"}}
	f.overworld.encounters=[host]
	r=presence_check(f,"hidden other-level host survives without a town",true,false)
	check(r.remaining[0].presence.field_hosts==1,"live pressure host not counted")
	f.overworld.resolved_encounters=["remaining_raid"]
	presence_check(f,"resolved host is not surviving",true,true)
	f.overworld.resolved_encounters=[]
	host.raid_retired_to_rebuild=true
	presence_check(f,"retired host is not surviving",true,true)
	host.erase("raid_retired_to_rebuild")
	host.spawned_by_player_id="player_3"
	presence_check(f,"allied host is not a rival",true,true)
	host.spawned_by_player_id="unknown"
	presence_check(f,"unknown field controller",false,false)
	host.erase("spawned_by_player_id");host.erase("spawned_by_faction_id")
	presence_check(f,"orphaned field commander ownership",false,false)
	f.overworld.encounters=[{"placement_id":"neutral_guard","encounter_id":"neutral_guard"}]
	f.overworld.enemy_states=[{"player_id":"player_2","commander_roster":[{"status":"available","roster_hero_id":"catalog_only","army_continuity":{"stacks":[]}}]}]
	presence_check(f,"neutral guards and undeployed hire catalog",true,true)
	var site_id := ""
	for site in ContentService._items_from_raw(ContentService.load_json(ContentService.RESOURCE_SITES_PATH)):
		if site is Dictionary and Generated.Adventure._resource_site_is_persistent(site):
			site_id=String(site.get("id",""));break
	check(site_id!="","persistent resource site fixture unavailable")
	var node := {"placement_id":"defended_site","site_id":site_id,"collected_by_player_id":"player_2","ai_defended_by_player_id":"player_2","ai_defense_until_day":5,"front":{"state":"defend"},"ai_defender_commander_state":{"player_id":"player_2","roster_hero_id":"fixture_commander"}}
	f.overworld.resource_nodes=[node]
	r=presence_check(f,"active persistent site defender on expiry day",true,false)
	if not r.remaining.is_empty():check(r.remaining[0].presence.defenders==1,"resource defender not counted")
	f.day=6
	presence_check(f,"expired site defender metadata",true,true)
	f.day=5;node.collected_by_player_id="player_1"
	presence_check(f,"lost site cannot retain a live defender",true,true)
	node.collected_by_player_id="unknown";node.ai_defended_by_player_id="unknown"
	presence_check(f,"unknown active site controller",false,false)
	f.overworld.resource_nodes=[42]
	presence_check(f,"malformed resource bucket",false,false)
	f=presence_fixture();f.overworld.players.append(f.overworld.players[1].duplicate())
	presence_check(f,"duplicate controller ids",false,false)
	f=presence_fixture();f.overworld.players[1].team_id=""
	presence_check(f,"missing team identity",false,false)
	f=presence_fixture();f.overworld.active_player_id="unknown"
	presence_check(f,"missing human controller",false,false)
	f=presence_fixture()
	for index in range(f.overworld.players.size()):f.overworld.players[index].slot=index+1
	f.flags.native_random_map_runtime_scenario_record={"player_slots":f.overworld.players.duplicate(true)}
	presence_check(f,"intact immutable package player identities",true,true)
	f.overworld.players.remove_at(1)
	presence_check(f,"dropped rival catalog row",false,false)
	f.overworld.players=f.flags.native_random_map_runtime_scenario_record.player_slots.duplicate(true)
	f.overworld.players[1].team_id="team_1"
	presence_check(f,"rival silently reassigned to allied team",false,false)
	f=presence_fixture();f.overworld.players=[]
	presence_check(f,"empty undeclared player catalog",false,false)
	f.overworld.player_identity_mode="legacy_generated_faction_v0"
	f.overworld.hero={"faction_id":"faction_embercourt"}
	f.flags.native_random_map_runtime_scenario_record={"enemy_factions":["faction_mireclaw"]}
	presence_check(f,"explicit legacy distinct faction controllers",true,true)
	f.overworld.towns=[{"owner":"enemy","controlling_faction_id":"faction_mireclaw"}]
	presence_check(f,"legacy surviving town",true,false)
	f.flags.native_random_map_runtime_scenario_record.enemy_factions=["faction_embercourt"]
	presence_check(f,"ambiguous legacy same faction ownership",false,false)
	var authored := {"objectives":{"kind":Generated.KIND,"victory":[{"id":"authored","type":"capture_town","town_id":"specific"}],"defeat":[]}}
	check(not Generated.uses_kind(authored) and Generated.definitions(authored)==authored.objectives,"explicit authored arrays were reinterpreted")
	check(Generated.definitions({"objectives":"bad"})=="bad","malformed objective container was silently replaced")
func fresh_opening() -> void:
	var config: Dictionary = Setup.build_random_map_player_config("10","translated_rmg_template_042_v1","translated_rmg_profile_042_v1",2,"land",false,"homm3_medium",Setup.RANDOM_MAP_TEMPLATE_SELECTION_MODE_SIZE_DEFAULT,"faction_embercourt","")
	var setup: Dictionary = Setup.build_random_map_skirmish_setup_with_retry(config,"normal",Setup.RANDOM_MAP_PLAYER_RETRY_POLICY)
	check(bool(setup.get("ok",false)),"fresh representative native generation failed")
	if not bool(setup.get("ok",false)):return
	var fresh = Setup.start_random_map_skirmish_session_from_setup(setup)
	check(fresh!=null,"fresh native session unavailable")
	if fresh==null:return
	OverworldRules.normalize_overworld_state(fresh)
	var presence := presence_check(fresh,"fresh native Medium day 1",true,false)
	var full: Dictionary = Scenario.evaluate_session(fresh)
	var event: Dictionary = Scenario.evaluate_session_for_event(fresh,{"action_kind":"move"})
	check(fresh.day==1 and full.status=="in_progress" and event.status=="in_progress","fresh native opening was awarded victory")
	check(int(Scenario._objective_progress_counts(fresh).victory_total)==1,"fresh objective absent")
	observations.append({"fresh_setup":config,"presence":presence,"event_profile":event.get("profile",{})})
func settle() -> void:
	for frame in range(8):await get_tree().process_frame
func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("RIVAL_OUTPUT").path_join(label+".png"))
func last_battle_fixture(payload: Dictionary) -> void:
	# Deliberately detached boundary fixture. Reactivate one retained real raid,
	# preserving both armies, then require the actual battle resolver to win.
	# This is NOT a generated-match completion or a replacement for that run.
	var f = restored(payload)
	var host := {}
	for value in f.overworld.encounters:
		if value is Dictionary and String(value.get("spawned_by_player_id",""))=="player_2" and not value.get("enemy_army",{}).is_empty():
			host=value;break
	check(not host.is_empty(),"retained rival raid unavailable for detached final battle")
	if host.is_empty():return
	f.overworld.resolved_encounters.erase(String(host.placement_id))
	host.erase("raid_retired_to_rebuild")
	check(not Generated.progress(f).complete,"reactivated last rival host did not prevent victory")
	f.battle=Battle.create_battle_payload(f,host)
	f.game_state="battle"
	f.battle[Battle.PRESENTATION_SPEED_KEY]=Battle.PRESENTATION_SPEED_INSTANT
	var resolved: Dictionary=Resolve.resolve_active_battle(f)
	check(bool(resolved.get("ok",false)) and resolved.get("state","")=="victory","real last-host battle did not win")
	check(f.scenario_status=="victory","last-host combat did not evaluate generated conquest")
	var report: Dictionary=Battle.pending_battle_report(f)
	check(not report.is_empty() and report.get("outcome","")=="victory","final battle casualty report missing")
	if report.is_empty():return
	check(int(report.get("casualties",{}).get("enemy",{}).get("totals",{}).get("lost",0))>0,"last battle has no actual casualties")
	f=SessionState.set_active_session(f)
	AppRouter.resume_active_session()
	await settle()
	var shell=get_tree().current_scene
	check(String(shell.scene_file_path).ends_with("BattleReportShell.tscn"),"victory bypassed the pending battle report")
	if not String(shell.scene_file_path).ends_with("BattleReportShell.tscn"):return
	await capture("detached_last_battle_report")
	check(bool(SaveService.save_runtime_autosave_session(f).get("ok",false)),"pending final battle autosave failed")
	var pending_loaded=SaveService.restore_autosave_session()
	check(pending_loaded!=null and Battle.pending_battle_report(pending_loaded)==report,"saved final casualty report changed")
	if pending_loaded==null:return
	f=SessionState.set_active_session(pending_loaded)
	AppRouter.resume_active_session()
	await settle()
	shell=get_tree().current_scene
	check(String(shell.scene_file_path).ends_with("BattleReportShell.tscn"),"resume bypassed saved final battle report")
	if not String(shell.scene_file_path).ends_with("BattleReportShell.tscn"):return
	shell.get_node("%Continue").pressed.emit()
	var continued: Dictionary=shell._last_continue_result.duplicate(true)
	await settle()
	check(bool(continued.get("ok",false)) and continued.get("target","")=="scenario_outcome","Continue did not acknowledge and route victory")
	check(Battle.pending_battle_report(f).is_empty(),"Continue left a duplicate pending final report")
	shell=get_tree().current_scene
	check(String(shell.scene_file_path).ends_with("ScenarioOutcomeShell.tscn"),"final battle did not reach actual outcome scene")
	if not String(shell.scene_file_path).ends_with("ScenarioOutcomeShell.tscn"):return
	var title: Label=shell.get_node("%Header")
	check(title.text.begins_with("Victory | "),"earned victory title missing")
	var viewport := Rect2(Vector2.ZERO,get_viewport().get_visible_rect().size)
	for control in [shell._banner,shell._command_column,shell._sidebar_shell,shell._save_button,shell._menu_button]:
		check(control.is_visible_in_tree() and viewport.encloses(control.get_global_rect()),"victory control clipped: "+str(control.name))
	check(not shell._command_column.get_global_rect().intersects(shell._sidebar_shell.get_global_rect()),"victory navigation overlaps")
	await capture("detached_last_battle_outcome")
	var saved: Dictionary=SaveService.save_runtime_autosave_session(f)
	var loaded=SaveService.restore_autosave_session()
	check(bool(saved.get("ok",false)) and loaded!=null,"acknowledged victory save/load failed")
	if loaded!=null:check(JSON.parse_string(state(loaded))==JSON.parse_string(state(f)),"complete acknowledged victory state changed on load")
	observations.append({"fixture":"detached reactivated real raid final battle","placement_id":host.placement_id,"battle":{"ok":resolved.get("ok",false),"state":resolved.get("state","")},"continue":{"ok":continued.get("ok",false),"target":continued.get("target","")},"title":title.text})
func _run() -> void:
	get_tree().current_scene=null
	SettingsService.set_presentation_mode("windowed")
	SettingsService.set_presentation_resolution(OS.get_environment("RIVAL_RESOLUTION"))
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("RIVAL_SAVE")))
	var session = restored(payload)
	var before: Dictionary = session.to_dict().duplicate(true)
	var raw: Dictionary = Scenario.scenario_record_for_session(session).get("objectives",{})
	check(String(raw.get("kind",""))=="defeat_generated_rivals","fixture lacks original generated objective kind")
	check(session.scenario_status=="in_progress","source save is already terminal")
	var counts: Dictionary = Scenario._objective_progress_counts(session)
	var board := Scenario.describe_objectives(session)
	check(int(counts.get("victory_total",0))==1,"generated victory is absent from live objective definitions")
	check(int(counts.get("victory_met",0))==1,"earned rival defeat is not recognized in progress")
	check(state(session)==JSON.stringify(before),"objective progress mutated complete session state")
	var result: Dictionary = Scenario.evaluate_session(session)
	check(String(result.get("status",""))=="victory" and session.scenario_status=="victory","real completed conquest remains nonterminal")
	check(session.flags.get("native_random_map_runtime_scenario_record",{})==before.flags.get("native_random_map_runtime_scenario_record",{}),"evaluation changed saved scenario source")
	var expected: Dictionary = before.duplicate(true)
	expected.scenario_status="victory";expected.scenario_summary=session.scenario_summary;expected.flags.scenario_result="victory"
	check(state(session)==JSON.stringify(expected),"completion changed fields beyond the existing outcome mutation")
	var terminal := state(session)
	Scenario.evaluate_session(session)
	check(state(session)==terminal,"terminal evaluation is not idempotent")
	observations.append({"day":session.day,"raw_objectives":raw,"counts":counts,"board":board,"result":result})
	var event_session = restored(payload)
	var event: Dictionary = Scenario.evaluate_session_for_event(event_session,{"action_kind":"move"})
	check(event.status=="victory" and event_session.scenario_status=="victory","event dependency silently skipped earned victory")
	check(int(event.get("profile",{}).get("objective_count",0))==1,"dependency metadata omitted generated objective")
	check(state(event_session)==terminal,"event and full evaluation differ in complete state")
	check(OverworldRules.describe_objective_board(event_session).contains("Victory 1/1"),"Overworld board uses different definitions")
	var saved := SaveService.save_session(event_session.to_dict(),1)
	check(saved!="","terminal save failed")
	var loaded = SaveService.restore_manual_session(1)
	check(loaded!=null,"terminal restore failed")
	if loaded!=null:
		# Compare every serialized field, not dictionary insertion order or the
		# parser's integer/float representation of identical JSON numbers.
		# Production restore stages a terminal, report-free save for Outcome.
		var expected_loaded: Dictionary = JSON.parse_string(state(event_session))
		expected_loaded.game_state="outcome"
		var round_trip_equal: bool = JSON.parse_string(state(loaded))==expected_loaded
		check(round_trip_equal,"complete generated terminal state changed on save/load")
		if not round_trip_equal:
			for item in [["expected",event_session],["restored",loaded]]:
				var evidence := FileAccess.open(OS.get_environment("RIVAL_OUTPUT").path_join("terminal_"+String(item[0])+".json"),FileAccess.WRITE)
				evidence.store_string(state(item[1]))
	ownership_fixtures()
	fresh_opening()
	await last_battle_fixture(payload)
	print("GENERATED_RIVAL_OBJECTIVE_REPORT "+JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''


def main():
    signal.signal(signal.SIGTERM, stop_requested)
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--label',required=True)
    parser.add_argument('--save',required=True,type=Path)
    parser.add_argument('--rendered',action='store_true')
    parser.add_argument('--resolution',choices=['1280x720','1920x1080'],default='1280x720')
    args=parser.parse_args()
    if not re.fullmatch('[a-z0-9_-]+',args.label):parser.error('fresh lowercase label required')
    source=args.save.resolve()
    source_hash=hashlib.sha256(source.read_bytes()).hexdigest()
    payload=json.loads(source.read_text())
    package_hashes={}
    for key in ['map_package_ref','scenario_package_ref']:
        reference=payload['flags'][key]['package_path']
        if not reference.startswith('res://'):parser.error('this regression requires retained project-map packages')
        package=(ROOT/reference.removeprefix('res://')).resolve()
        if not package.is_relative_to(ROOT) or not package.is_file():parser.error('retained package missing or outside project: '+reference)
        package_hashes[str(package)]=hashlib.sha256(package.read_bytes()).hexdigest()
    owner=ROOT/'scripts/core/ScenarioRules.gd'
    owner_hash=hashlib.sha256(owner.read_bytes()).hexdigest()
    production_hash=runtime_source_tree_sha256()
    out=OUTPUT/args.label;out.mkdir(exist_ok=False)
    with tempfile.TemporaryDirectory(prefix='rival-probe-',dir=OUTPUT) as temporary, tempfile.TemporaryDirectory(prefix='heroes-rival-',dir='/dev/shm') as data:
        work=Path(temporary);script=work/'probe.gd';script.write_text(SCRIPT)
        scene=work/'probe.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="RivalObjective" type="Node"]\nscript=ExtResource("1")\n' % script.relative_to(ROOT))
        env=dict(os.environ,XDG_DATA_HOME=data,RIVAL_SAVE=str(source),RIVAL_OUTPUT=str(out),RIVAL_RESOLUTION=args.resolution)
        command=['godot4','--path',str(ROOT),'--audio-driver','Dummy','--accessibility','disabled','--resolution',args.resolution,'res://'+str(scene.relative_to(ROOT))]
        command=['dbus-run-session','--','xvfb-run','-a','-s','-screen 0 2200x1200x24']+command if args.rendered else command+['--headless']
        with (out/'runtime.log').open('w') as log:code=run_probe(command,env,log)
    lines=(out/'runtime.log').read_text().splitlines()
    reports=[json.loads(line[len(MARKER):]) for line in lines if line.startswith(MARKER)]
    report=reports[-1] if reports else {'ok':False,'failures':['missing final report']}
    errors=[line for line in lines if line.startswith(('ERROR:','SCRIPT ERROR:')) or 'leaked' in line]
    report.update(returncode=code,runtime_errors=errors,source_save_sha256=source_hash,source_save_unchanged=source_hash==hashlib.sha256(source.read_bytes()).hexdigest(),scenario_owner_sha256=owner_hash,scenario_owner_unchanged=owner_hash==hashlib.sha256(owner.read_bytes()).hexdigest())
    report.update(runtime_source_tree_sha256=production_hash,runtime_sources_unchanged=production_hash==runtime_source_tree_sha256(),rendered=args.rendered,resolution=args.resolution)
    report.update(package_sha256=package_hashes,packages_unchanged=all(Path(path).is_file() and hashlib.sha256(Path(path).read_bytes()).hexdigest()==digest for path,digest in package_hashes.items()))
    report['ok']=bool(report['ok']) and code==0 and not errors and report['source_save_unchanged'] and report['scenario_owner_unchanged'] and report['runtime_sources_unchanged'] and report['packages_unchanged']
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({key:report.get(key) for key in ['ok','checks','failures','returncode','runtime_errors','source_save_unchanged','packages_unchanged','runtime_source_tree_sha256','runtime_sources_unchanged','resolution']}))
    return 0 if report['ok'] else 1


if __name__=='__main__':raise SystemExit(main())
