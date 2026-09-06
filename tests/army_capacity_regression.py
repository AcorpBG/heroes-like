#!/usr/bin/env python3
"""Seven-stack admissions and non-destructive display/recovery of a real save."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

from generated_full_match_quality import ROOT, OUTPUT, SCRIPT as MATCH_SCRIPT
from generated_town_order_profile import run_probe

BODY = r'''
var checks := 0
var original_stacks := []
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
func state(s) -> Dictionary:
	return JSON.parse_string(JSON.stringify(s.to_dict()))
func troop_total(stacks: Array) -> int:
	var total := 0
	for stack in stacks:
		total += int(stack.get("count",0))
	return total
func fixture() -> Dictionary:
	# Isolated admission controls, never substituted for full-match gameplay.
	var s = ScenarioFactory.create_session("river-pass","normal",SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(s)
	var town: Dictionary = s.overworld.towns.filter(func(t):return t.placement_id=="riverwatch_hold")[0]
	var hero: Dictionary = s.overworld.hero
	hero.position = preload("res://scripts/core/OverworldLevelRules.gd").town_entrance(town)
	s.overworld.hero_position = hero.position
	HeroCommandRules.commit_active_hero(s)
	OverworldRules.set_active_town_visit(s,town.placement_id)
	town = TownRules.get_active_town(s)
	for key in s.overworld.resources:
		s.overworld.resources[key] = 100000
	var unit_id: String = OverworldRules.get_town_recruit_options(town)[0]
	var stacks := []
	for source in original_stacks:
		if source.unit_id != unit_id and stacks.size()<7:
			stacks.append({"unit_id":source.unit_id,"count":10,"slot_index":stacks.size()})
	HeroCommandRules._set_holder_stacks(s,town,s.overworld.active_hero_id,stacks)
	town.available_recruits[unit_id] = 5
	HeroCommandRules.normalize_session(s)
	return {"session":s,"town":town,"unit":unit_id}
func admission_controls() -> void:
	var f := fixture()
	var s = f.session
	var before := state(s)
	var offer := {}
	for action in TownRules.get_recruit_actions(s):
		if action.id == "recruit:"+f.unit:
			offer = action
	check(not offer.is_empty() and bool(offer.get("disabled",false)),"full formation must disable new-unit recruitment offer")
	var result := OverworldRules.recruit_in_active_town(s,f.unit,1)
	check(not bool(result.get("ok",true)),"paid recruitment must reject an eighth stack")
	check(state(s)==before,"rejected recruitment changed complete gameplay state")
	f = fixture();s = f.session
	HeroCommandRules._set_holder_stacks(s,f.town,HeroCommandRules.HOLDER_GARRISON,[{"unit_id":f.unit,"count":5}])
	before = state(s)
	result = HeroCommandRules.transfer_town_stack(s,f.town,HeroCommandRules.HOLDER_GARRISON,s.overworld.active_hero_id,f.unit,"all")
	check(not bool(result.get("ok",true)),"Town transfer must reject an eighth destination stack")
	check(state(s)==before,"rejected Town transfer changed complete gameplay state")
	f = fixture();s = f.session
	var node := {"placement_id":"capacity_claim_fixture","site_id":"site_free_company_yard","x":s.overworld.hero_position.x,"y":s.overworld.hero_position.y,"collected":false}
	s.overworld.resource_nodes = [node]
	s.overworld.encounters = []
	OverworldRules.invalidate_spatial_lookup(s)
	before = state(s)
	result = OverworldRules._collect_resource_node_result(s,{"index":0,"node":node})
	check(not bool(result.get("ok",true)),"unit-bearing site must reject overflowing claim")
	check(state(s)==before,"rejected site claim spent rewards, cost or claim state")
	# Split stacks must not multiply a single incoming grant.
	var split := [{"unit_id":f.unit,"count":2,"slot_index":1},{"unit_id":f.unit,"count":3,"slot_index":5}]
	var joined: Array = OverworldRules._add_army_stack(split,f.unit,4)
	check(troop_total(joined)==9,"incoming grant was duplicated across matching split stacks")
	check(joined[0].get("slot_index",-1)==1 and joined[1].get("slot_index",-1)==5,"reinforcement discarded formation slots")
func recovery_and_delivery_controls() -> void:
	var f := fixture()
	var s = f.session
	var hero_id: String = s.overworld.active_hero_id
	var stacks: Array = s.overworld.army.stacks.duplicate(true)
	stacks.append({"unit_id":f.unit,"count":9})
	HeroCommandRules._set_holder_stacks(s,f.town,hero_id,stacks)
	HeroCommandRules._set_holder_stacks(s,f.town,HeroCommandRules.HOLDER_GARRISON,[])
	var result := HeroCommandRules.transfer_town_stack(s,f.town,hero_id,HeroCommandRules.HOLDER_GARRISON,f.unit,"all")
	check(result.get("ok",false),"legacy overflow cannot transfer excess through existing Town controls")
	check(HeroCommandRules.army_slot_snapshot(s,f.town,hero_id).get("capacity_valid",false),"reducing legacy overflow did not restore slot management")
	check(troop_total(s.overworld.army.stacks)+troop_total(f.town.garrison)==79,"legacy transfer lost or duplicated troops")
	var first_unit: String = s.overworld.army.stacks[0].unit_id
	result = TownRules.transfer_in_active_town(s,"transfer:"+hero_id+":"+HeroCommandRules.HOLDER_GARRISON+":"+first_unit+":all")
	check(result.get("ok",false),"normal transfer could not free a recruitment slot")
	var offers := TownRules.get_recruit_actions(s)
	check(offers.any(func(a):return a.id=="recruit:"+f.unit and not a.get("disabled",true)),"Town recruitment stayed stale after freeing a slot")
	var resources: Dictionary = s.overworld.resources.duplicate(true)
	var cost: Dictionary = OverworldRules.town_recruit_cost(s,f.town,f.unit)
	result = OverworldRules.recruit_in_active_town(s,f.unit,1)
	check(result.get("ok",false) and s.overworld.army.stacks.size()==7,"seventh-stack recruitment failed after freeing capacity")
	for key in cost:
		check(int(s.overworld.resources[key])==int(resources[key])-int(cost[key]),"accepted recruit charged incorrect "+String(key))
	check(int(TownRules.get_active_town(s).available_recruits[f.unit])==4,"accepted recruitment consumed incorrect town reserve")
	var slots := {}
	for stack in s.overworld.army.stacks:
		slots[int(stack.get("slot_index",-1))] = true
	check(slots.size()==7 and not slots.has(-1),"replacement recruitment produced duplicate or missing battle slots")
	# A dispatched convoy remains in existing saved node state until room exists.
	f = fixture();s = f.session;hero_id = s.overworld.active_hero_id
	var node := {"placement_id":"capacity_delivery_fixture","site_id":"site_free_company_yard","x":s.overworld.hero_position.x,"y":s.overworld.hero_position.y,"collected":true,"collected_by_faction_id":"player","delivery_controller_id":"player","delivery_origin_town_id":f.town.placement_id,"delivery_target_kind":"hero","delivery_target_id":hero_id,"delivery_target_label":"Test commander","delivery_arrival_day":1,"delivery_manifest":{f.unit:4}}
	s.overworld.resource_nodes = [node];s.overworld.encounters = []
	OverworldRules.invalidate_spatial_lookup(s)
	var before := state(s)
	var messages: Array = OverworldRules._advance_player_reserve_deliveries(s)
	check(not messages.is_empty() and String(messages[0]).contains("waits"),"full destination convoy did not explain waiting")
	check(state(s)==before,"waiting convoy changed troops, manifest or delivery receipt")
	var path: String = SaveService.save_session(s.to_dict(),3)
	var restored = SessionState.restore_session(SaveService.load_session(3))
	check(path!="" and state(restored)==state(s),"waiting convoy failed complete save/resume")
	s = restored
	var town: Dictionary = s.overworld.towns.filter(func(t):return t.placement_id=="riverwatch_hold")[0]
	HeroCommandRules._set_holder_stacks(s,town,HeroCommandRules.HOLDER_GARRISON,[])
	first_unit = s.overworld.army.stacks[0].unit_id
	result = HeroCommandRules.transfer_town_stack(s,town,hero_id,HeroCommandRules.HOLDER_GARRISON,first_unit,"all")
	check(result.get("ok",false),"could not free a slot for waiting convoy")
	messages = OverworldRules._advance_player_reserve_deliveries(s)
	check(troop_total(s.overworld.army.stacks)==64 and s.overworld.army.stacks.size()==7,"waiting convoy did not deliver exactly once into the free slot")
	check(s.overworld.resource_nodes[0].get("delivery_manifest",{}).is_empty(),"successful convoy did not consume its manifest")
	var delivered := state(s)
	OverworldRules._advance_player_reserve_deliveries(s)
	check(state(s)==delivered,"completed convoy delivered twice")
	# Town-bound convoys use the same atomic admission, without converting
	# capacity rejection into the missing/captured-destination return path.
	f = fixture();s = f.session
	town = f.town
	HeroCommandRules._set_holder_stacks(s,town,"garrison",s.overworld.army.stacks)
	node = {"placement_id":"capacity_town_delivery_fixture","site_id":"site_free_company_yard","x":s.overworld.hero_position.x,"y":s.overworld.hero_position.y,"collected":true,"collected_by_faction_id":"player","delivery_controller_id":"player","delivery_origin_town_id":town.placement_id,"delivery_target_kind":"town","delivery_target_id":town.placement_id,"delivery_target_label":"Riverwatch","delivery_arrival_day":1,"delivery_manifest":{f.unit:4}}
	s.overworld.resource_nodes = [node];s.overworld.encounters = []
	OverworldRules.invalidate_spatial_lookup(s)
	before = state(s)
	messages = OverworldRules._advance_player_reserve_deliveries(s)
	check(not messages.is_empty() and String(messages[0]).contains("waits") and state(s)==before,"full Town destination did not retain the complete convoy state")
	first_unit = town.garrison[0].unit_id
	result = HeroCommandRules.transfer_town_stack(s,town,"garrison",s.overworld.active_hero_id,first_unit,"all")
	check(result.get("ok",false),"matching transfer could not free a Town delivery slot")
	OverworldRules._advance_player_reserve_deliveries(s)
	town = TownRules.get_active_town(s)
	check(town.garrison.size()==7 and troop_total(town.garrison)==64,"Town convoy did not arrive exactly once into the free slot")
	check(troop_total(s.overworld.army.stacks)==80,"Town delivery changed the receiving commander's troops")
	delivered = state(s)
	OverworldRules._advance_player_reserve_deliveries(s)
	check(state(s)==delivered,"Town convoy delivered twice")
func positive_and_field_controls() -> void:
	var f := fixture()
	var s = f.session
	var matching: String = s.overworld.army.stacks[0].unit_id
	f.town.available_recruits[matching] = 5
	var result := OverworldRules.recruit_in_active_town(s,matching,3)
	check(result.get("ok",false) and s.overworld.army.stacks.size()==7 and troop_total(s.overworld.army.stacks)==73,"full formation must accept matching-unit paid reinforcement once")
	f = fixture();s = f.session
	var split := [{"unit_id":f.unit,"count":2,"slot_index":1},{"unit_id":f.unit,"count":3,"slot_index":5}]
	HeroCommandRules._set_holder_stacks(s,f.town,s.overworld.active_hero_id,split)
	OverworldRules._grant_site_claim_recruits(s,{f.unit:4})
	check(troop_total(s.overworld.army.stacks)==9 and s.overworld.army.stacks.size()==2,"actual site grant multiplied split-stack reinforcements")
	check(s.overworld.army.stacks[0].slot_index==1 and s.overworld.army.stacks[1].slot_index==5,"actual site grant erased formation positions")
	f = fixture();s = f.session
	HeroCommandRules._set_holder_stacks(s,f.town,s.overworld.active_hero_id,s.overworld.army.stacks.slice(0,5))
	var node := {"placement_id":"capacity_claim_success_fixture","site_id":"site_free_company_yard","x":s.overworld.hero_position.x,"y":s.overworld.hero_position.y,"collected":false}
	s.overworld.resource_nodes = [node];s.overworld.encounters = []
	OverworldRules.invalidate_spatial_lookup(s)
	result = OverworldRules._collect_resource_node_result(s,{"index":0,"node":node})
	check(result.get("ok",false) and s.overworld.army.stacks.size()==7 and troop_total(s.overworld.army.stacks)==53,"fitting two-unit site claim did not grant exactly its three troops")
	check(s.overworld.resource_nodes[0].get("collected",false),"accepted site claim did not retain collection state")
	f = fixture();s = f.session
	var reserve: Dictionary = s.overworld.hero.duplicate(true)
	reserve.id = "hero_sable";reserve.is_primary = false
	reserve.army = {"id":"capacity_reserve_army","name":"Reserve","stacks":[{"unit_id":f.unit,"count":5}]}
	s.overworld.player_heroes.append(reserve)
	HeroCommandRules.normalize_session(s)
	var before := state(s)
	result = HeroCommandRules.transfer_field_stack(s,"hero_sable",s.overworld.active_hero_id,f.unit,"all")
	check(not result.get("ok",true) and state(s)==before,"field transfer overflow did not reject atomically")
	matching = s.overworld.army.stacks[0].unit_id
	result = HeroCommandRules.transfer_field_stack(s,s.overworld.active_hero_id,"hero_sable",matching,"all")
	check(result.get("ok",false) and s.overworld.army.stacks.size()==6,"valid field transfer failed to free a slot")
	check(troop_total(s.overworld.army.stacks)+troop_total(HeroCommandRules.hero_by_id(s,"hero_sable").army.stacks)==75,"field transfer lost or duplicated troops")
func press_accept(button: Button) -> void:
	check(button.is_visible_in_tree() and not button.disabled,"keyboard target is hidden or disabled: "+button.text)
	button.grab_focus()
	await get_tree().process_frame
	var pressed := InputEventAction.new()
	pressed.action = &"ui_accept";pressed.pressed = true
	Input.parse_input_event(pressed)
	await get_tree().process_frame
	var released := InputEventAction.new()
	released.action = &"ui_accept";released.pressed = false
	Input.parse_input_event(released)
	await settle()
	# Town orders commit a replacement SessionData transactionally.
	session = SessionState.ensure_active_session()
func town_recovery_ui() -> void:
	# Synthetic excess fixture exercises actual visible recovery controls; the
	# recorded 18-stack army above remains completely unchanged.
	var f := fixture()
	session = f.session
	var stacks: Array = session.overworld.army.stacks.duplicate(true)
	stacks.append({"unit_id":f.unit,"count":9})
	HeroCommandRules._set_holder_stacks(session,f.town,session.overworld.active_hero_id,stacks)
	HeroCommandRules._set_holder_stacks(session,f.town,HeroCommandRules.HOLDER_GARRISON,[])
	SessionState.set_active_session(session)
	AppRouter.go_to_town()
	await settle()
	var shell = get_tree().current_scene
	check(scene_path().ends_with("TownShell.tscn"),"recovery Town route failed")
	await press_accept(shell.get_node("%LogAction"))
	check(shell._town_catalog_is_open() and shell._town_catalog_mode=="log","keyboard Log action failed to open recovery dialog")
	var bar = shell.get_node("%ArmyManagement")
	check(bar.is_visible_in_tree(),"recovery formation is not visible in Log")
	var warning = bar.find_child("ArmyOverflowWarning",true,false)
	check(warning!=null and warning.is_visible_in_tree() and "Town Log" in warning.text,"overflow instruction does not identify actual transfer dialog")
	check(get_viewport().get_visible_rect().encloses(bar.get_global_rect()),"Town recovery formation clips outside viewport")
	await screenshot("town_overflow_recovery")
	var label := ""
	var action_id: String = "transfer:%s:garrison:%s:all" % [session.overworld.active_hero_id,f.unit]
	for action in TownRules.get_transfer_actions(session):
		if action.id==action_id:
			label = action.label
	var target: Button
	for button in shell.get_node("%TransferActions").get_children():
		if button is Button and button.text==label and not button.disabled:
			target = button
	check(target!=null,"excess stack has no enabled Town transfer control")
	if target==null:
		return
	await press_accept(target)
	check(session.overworld.army.stacks.size()==7,"keyboard Town transfer did not recover legacy formation")
	check(troop_total(session.overworld.army.stacks)+troop_total(TownRules.get_active_town(session).garrison)==79,"Town recovery UI lost or duplicated troops")
	check(bool(HeroCommandRules.army_slot_snapshot(session,{},session.overworld.active_hero_id).capacity_valid),"recovered army did not enable seven-slot editing")
	shell._town_catalog_scroll.scroll_vertical = 0
	await settle()
	await screenshot("town_recovered")
	# Exercise the current dialog's normal positional split, not the retired
	# ManagementTabs surface used by the historical army-bar report.
	var half: Button
	var source: Button
	var destination: Button
	for button in bar.find_children("*","Button",true,false):
		if button.text=="Half":
			half = button
		if button.get_meta("holder_id","")==session.overworld.active_hero_id and button.get_meta("slot_index",-1)==0:
			source = button
		if button.get_meta("holder_id","")=="garrison" and button.get_meta("slot_index",-1)==1:
			destination = button
	check(half!=null and source!=null and destination!=null,"recovered formation is missing visible split controls")
	if half==null or source==null or destination==null:
		return
	await press_accept(half)
	await press_accept(source)
	await press_accept(destination)
	var recovered := HeroCommandRules.army_slot_snapshot(session,TownRules.get_active_town(session),session.overworld.active_hero_id)
	var garrison := HeroCommandRules.army_slot_snapshot(session,TownRules.get_active_town(session),"garrison")
	check(recovered.slots[0].count==5 and garrison.slots[1].count==5,"recovered keyboard Half transfer did not preserve exact source/destination slots")
	check(recovered.troop_count+garrison.troop_count==79,"positional split changed total troops")
func run_match() -> void:
	get_tree().current_scene = null
	out = OS.get_environment("ARMY_CAPACITY_OUTPUT")
	action_file = FileAccess.open(out.path_join("actions.jsonl"),FileAccess.WRITE)
	SettingsService.set_presentation_mode("windowed")
	SettingsService.set_presentation_resolution(OS.get_environment("ARMY_CAPACITY_RESOLUTION"))
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(out.path_join("input_save.json")))
	session = SessionState.restore_session(saved)
	for key in ["saved_at_unix","save_slot_type","saved_from_game_state","saved_from_scenario_status","saved_from_launch_mode"]:
		saved.erase(key)
	check(saved==state(session),"real legacy save was altered on restore")
	original_stacks = session.overworld.army.stacks.duplicate(true)
	check(original_stacks.size()==18 and troop_total(original_stacks)==970,"expected exact recorded 18-stack/970-troop case")
	var capacity := capacity_snapshot()
	check(not capacity.ok and capacity.violations.any(func(v):return v.id=="hero:"+String(session.overworld.active_hero_id) and v.stack_count==18),"match observer missed the real oversized commander")
	AppRouter.resume_active_session()
	await settle()
	var snapshot := HeroCommandRules.army_slot_snapshot(session,{},session.overworld.active_hero_id)
	check(int(snapshot.get("troop_count",0))==970,"legacy army display reports incorrect troop count")
	check(snapshot.get("slots",[]).size()==7 and snapshot.get("slots",[]).any(func(s):return s.get("occupied",false)),"legacy army display hides all occupied slots")
	check(not bool(snapshot.get("capacity_valid",true)) and int(snapshot.get("overflow_stack_count",0))==11,"legacy capacity warning lacks exact overflow count")
	await screenshot("legacy_overflow")
	check(state(session).overworld.army.stacks==JSON.parse_string(JSON.stringify(original_stacks)),"display truncated or changed saved troops")
	await checkpoint("legacy_overflow",2)
	check(checkpoint_labels.has("legacy_overflow"),"legacy overflow failed complete save/resume")
	admission_controls()
	recovery_and_delivery_controls()
	positive_and_field_controls()
	await town_recovery_ui()
	print("ARMY_CAPACITY_REGRESSION "+JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures,"legacy_snapshot":snapshot,"legacy_match_capacity":capacity,"counts":counts}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''

REFERENCE_BODY = r'''
func run_match() -> void:
	out = OS.get_environment("ARMY_CAPACITY_OUTPUT")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(out.path_join("input_save.json")))
	session = SessionState.restore_session(saved)
	original_stacks = session.overworld.army.stacks.duplicate(true)
	var snapshot: Dictionary = LegacyHeroes.army_slot_snapshot(session,{},session.overworld.active_hero_id)
	check(int(snapshot.get("troop_count",0))==970,"legacy army display reports incorrect troop count")
	check(snapshot.get("slots",[]).size()==7,"legacy army display hides all occupied slots")
	var f := fixture()
	var s = f.session
	var before := state(s)
	var result: Dictionary = LegacyOverworld.recruit_in_active_town(s,f.unit,1)
	check(not result.get("ok",true),"paid recruitment must reject an eighth stack")
	check(state(s)==before,"rejected recruitment changed complete gameplay state")
	f = fixture();s = f.session
	HeroCommandRules._set_holder_stacks(s,f.town,"garrison",[{"unit_id":f.unit,"count":5}])
	before = state(s)
	result = LegacyHeroes.transfer_town_stack(s,f.town,"garrison",s.overworld.active_hero_id,f.unit,"all")
	check(not result.get("ok",true),"Town transfer must reject an eighth destination stack")
	check(state(s)==before,"rejected Town transfer changed complete gameplay state")
	f = fixture();s = f.session
	var node := {"placement_id":"capacity_claim_fixture","site_id":"site_free_company_yard","x":s.overworld.hero_position.x,"y":s.overworld.hero_position.y,"collected":false}
	s.overworld.resource_nodes = [node];s.overworld.encounters = []
	OverworldRules.invalidate_spatial_lookup(s)
	before = state(s)
	result = LegacyOverworld._collect_resource_node_result(s,{"index":0,"node":node})
	check(not result.get("ok",true),"unit-bearing site must reject overflowing claim")
	check(state(s)==before,"rejected site claim spent rewards, cost or claim state")
	var split := [{"unit_id":f.unit,"count":2,"slot_index":1},{"unit_id":f.unit,"count":3,"slot_index":5}]
	var joined: Array = LegacyOverworld._add_army_stack(split,f.unit,4)
	check(troop_total(joined)==9,"incoming grant was duplicated across matching split stacks")
	check(joined[0].get("slot_index",-1)==1 and joined[1].get("slot_index",-1)==5,"reinforcement discarded formation slots")
	print("ARMY_CAPACITY_REGRESSION "+JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--label', required=True)
    parser.add_argument('--save', type=Path, required=True)
    parser.add_argument('--rendered', action='store_true')
    parser.add_argument('--resolution', choices=['1280x720','1920x1080'], default='1280x720')
    parser.add_argument('--reference-revision', help='Replay old production admission/display owners on the same isolated fixtures; a defective reference must fail.')
    args = parser.parse_args()
    if not args.label or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789_-' for c in args.label):
        parser.error('label must be a fresh lowercase slug')
    if args.reference_revision and not re.fullmatch('[0-9a-f]{8,40}',args.reference_revision):
        parser.error('reference revision must be an exact commit hash')
    out = OUTPUT/args.label
    out.mkdir(parents=True, exist_ok=False)
    saved = args.save.read_bytes()
    json.loads(saved)
    (out/'input_save.json').write_bytes(saved)
    with tempfile.TemporaryDirectory(prefix='army-capacity-',dir=OUTPUT) as temporary:
        work = Path(temporary)
        body = BODY
        references = {}
        if args.reference_revision:
            # Old static owners are copied into disposable probes, never over
            # the dirty worktree. Shared fixtures/dependencies remain current;
            # this is a targeted owner control, not an old-build playthrough.
            constants = ''
            for alias,name in [('LegacyHeroes','HeroCommandRules'),('LegacyOverworld','OverworldRules')]:
                source = subprocess.check_output(['git','show',f'{args.reference_revision}:scripts/core/{name}.gd'],cwd=ROOT)
                references[name] = hashlib.sha256(source).hexdigest()
                owner = work/(name+'.gd')
                owner.write_text(source.decode().replace(f'class_name {name}\n','',1))
                constants += 'const %s = preload("res://%s")\n' % (alias,owner.relative_to(ROOT))
            body = constants+BODY[:BODY.index('func run_match()')]+REFERENCE_BODY
        script = work/'probe.gd'
        script.write_text(MATCH_SCRIPT[:MATCH_SCRIPT.index('func run_match()')]+body)
        scene = work/'probe.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="ArmyCapacity" type="Node"]\nscript = ExtResource("1")\n' % script.relative_to(ROOT))
        env = dict(os.environ,XDG_DATA_HOME=str(out/'data'),ARMY_CAPACITY_OUTPUT=str(out),ARMY_CAPACITY_RESOLUTION=args.resolution)
        command = ['godot4','--path',str(ROOT),'--audio-driver','Dummy','--accessibility','disabled','res://'+str(scene.relative_to(ROOT))]
        command = ['dbus-run-session','--','xvfb-run','-a','-s','-screen 0 2200x1200x24']+command if args.rendered else command+['--headless']
        with (out/'runtime.log').open('w') as log:
            code = run_probe(command,env,log)
    lines = (out/'runtime.log').read_text().splitlines()
    marker = 'ARMY_CAPACITY_REGRESSION '
    reports = [json.loads(line[len(marker):]) for line in lines if line.startswith(marker)]
    report = reports[-1] if reports else {'ok':False,'failures':['missing report']}
    owners = ['scripts/core/HeroCommandRules.gd','scripts/core/OverworldRules.gd','scripts/core/TownRules.gd','scenes/shared/ArmyStackBar.gd']
    report.update(returncode=code,save_sha256=hashlib.sha256(saved).hexdigest(),rendered=args.rendered,resolution=args.resolution,reference_revision=args.reference_revision,reference_owner_hashes=references,source_hashes={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in owners},runtime_errors=[s for s in lines if s.startswith(('ERROR:','SCRIPT ERROR:')) or 'leaked' in s])
    report['ok'] = bool(report['ok']) and code==0 and not report['runtime_errors']
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k!='legacy_snapshot'}))
    return 0 if report['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
