#!/usr/bin/env python3
"""First-entry Town commands; isolated progression fixture, never match evidence."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

from generated_full_match_quality import ROOT, OUTPUT
from generated_town_order_profile import run_probe

SCRIPT = r'''
extends Node
const Heroes = preload("res://scripts/core/HeroCommandRules.gd")
const Progression = preload("res://scripts/core/HeroProgressionRules.gd")
var errors := []
var checks := 0
var rows := []
var session
var out := ""
func _ready() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: errors.append(message)
func normalized(value): return JSON.parse_string(JSON.stringify(value))
func settle() -> void:
	for frame in range(8): await get_tree().process_frame
	var started := Time.get_ticks_msec()
	while get_tree().current_scene._town_action_input_blocker.visible:
		if Time.get_ticks_msec()-started>30000:
			errors.append("Town command handoff timed out");break
		await get_tree().process_frame
func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(label+".png"))
func enter() -> void:
	AppRouter.go_to_town()
	await settle()
	var reference := OS.get_environment("TOWN_COMMAND_REFERENCE_SCENE")
	if reference!="":
		# Old PackedScene in the disposable control only; normal router/session
		# admission above still applies. Production files are never overwritten.
		get_tree().change_scene_to_file(reference)
		await settle()
	check(get_tree().current_scene._session==session,"probe does not observe the actual active Town session")
func buttons(lane: String) -> Array:
	return get_tree().current_scene.get_node("%"+lane).get_children().filter(func(c):return c is Button and not c.is_queued_for_deletion())
func inspect(label: String) -> void:
	var shell=get_tree().current_scene
	var before: Dictionary=normalized(session.to_dict())
	var expected_heroes: Array=TownRules.get_hero_actions(session)
	var expected_choices: Array=TownRules.get_specialty_actions(session)
	check(buttons("HeroActions").size()==(expected_heroes.size() if expected_heroes.size()>1 else 0),label+": stationed commander controls missing")
	check(buttons("SpecialtyActions").size()==expected_choices.size(),label+": earned specialty controls missing")
	var layout: Dictionary=shell.validation_owner_town_layout_snapshot()
	check(layout.sidebar_contained and not layout.sidebar_rect.intersects(layout.footer_rect),label+": command rail clips or overlaps navigation")
	check(layout.direct_action_dock_visible,label+": five-dialog dock disappeared")
	var stage=shell.get_node("%TownStage")
	var built: Array=TownRules.get_active_town(session).get("built_buildings",[])
	check(normalized(stage._town.get("built_buildings",[]))==normalized(built),label+": command refresh lost built buildings from scenic state")
	var entries: Array=stage._town_building_scene_entries(stage._town_scene_rect())
	for building_id in built:
		check(entries.any(func(entry):return building_id in entry.variant_ids and entry.visible_building_id!=""),label+": built building lost its scenic plot: "+String(building_id))
	for lane in ["HeroActions","SpecialtyActions"]:
		check(shell.get_node("%"+lane).get_child_count()>0,label+": command lane is completely absent: "+lane)
		var previous: Array=[]
		for button in buttons(lane):
			check(button.is_visible_in_tree() and layout.sidebar_rect.encloses(button.get_global_rect()),label+": button is not visible inside the rail")
			check(button.focus_mode==Control.FOCUS_ALL and button.tooltip_text!="",label+": keyboard focus or command explanation absent")
			for rect in previous:check(not button.get_global_rect().intersects(rect),label+": command buttons overlap")
			previous.append(button.get_global_rect())
	check(normalized(session.to_dict())==before,label+": command observation mutated the session")
	rows.append({"label":label,"day":session.day,"hero_id":session.overworld.active_hero_id,"pending":Progression.pending_choices_remaining(session.overworld.hero),"hero_buttons":buttons("HeroActions").size(),"specialty_buttons":buttons("SpecialtyActions").size(),"layout":layout})
	await capture(label)
func keyboard_press(button: Button) -> void:
	button.grab_focus()
	await get_tree().process_frame
	check(button.has_focus(),"command button could not take keyboard focus")
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode=KEY_ENTER
		event.pressed=pressed
		Input.parse_input_event(event)
		await get_tree().process_frame
	await settle()
func run() -> void:
	get_tree().current_scene=null
	out=OS.get_environment("TOWN_COMMAND_OUTPUT")
	SettingsService.set_presentation_mode("windowed")
	SettingsService.set_presentation_resolution(OS.get_environment("TOWN_COMMAND_RESOLUTION"))
	var payload: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("TOWN_COMMAND_SAVE")))
	check(SaveService.save_session(payload,1)!="","isolated opening save copy failed")
	session=SaveService.restore_manual_session(1)
	if session==null:
		push_error("production opening restore failed");get_tree().quit(1);return
	session=SessionState.set_active_session(session)
	check(not ContentService.get_scenario_readonly(session.scenario_id).is_empty(),"production load did not register the saved generated scenario")
	var town: Dictionary=session.overworld.towns.filter(func(t):return t.owner=="player")[0]
	check(OverworldRules.set_active_town_visit(session,town.placement_id).get("ok",false),"opening cannot enter its actual starting town")
	await enter()
	check(get_tree().current_scene._last_refresh_minimal,"opening did not exercise the minimal first-entry path")
	await inspect("opening")
	# Explicit isolated UI fixture: award XP through progression and pay normal
	# recruitment costs. Never alter any live full-match process or source save.
	session.overworld.hero=Progression.add_experience(session.overworld.hero,800).hero
	Heroes.commit_active_hero(session)
	var offered: Array=TownRules.get_tavern_actions(session).filter(func(a):return not a.get("disabled",true))
	check(not offered.is_empty(),"opening budget has no ordinary paid commander hire")
	if not offered.is_empty():
		var count_before: int=Heroes.player_hero_count(session)
		# The production handler also invalidates its presentation cache. Direct
		# out-of-band rule mutation is not a real UI refresh/entry contract.
		get_tree().current_scene._on_tavern_action_pressed(String(offered[0].id))
		await settle()
		check(Heroes.player_hero_count(session)==count_before+1,"ordinary paid hire failed")
	var primary_id: String=session.overworld.active_hero_id
	check(Progression.pending_choices_remaining(session.overworld.hero)>0 and TownRules.get_hero_actions(session).size()>1,"populated fixture did not establish earned choices and alternate command")
	await enter()
	check(get_tree().current_scene._last_refresh_minimal,"populated case did not exercise minimal first entry")
	check(get_tree().current_scene.get_node("%BuildActions").get_child_count()==0 and get_tree().current_scene.get_node("%RecruitActions").get_child_count()==0,"entry eagerly populated closed construction/recruitment dialogs")
	await inspect("pending_entry")
	var choices: Array=buttons("SpecialtyActions").filter(func(b):return not b.disabled)
	if not choices.is_empty():
		var pending_before: int=Progression.pending_choices_remaining(session.overworld.hero)
		var selected: String=String(TownRules.get_specialty_actions(session)[0].id).trim_prefix("choose_specialty:")
		var rank_before: int=Progression.specialty_rank(session.overworld.hero,selected)
		var resources_before: Dictionary=session.overworld.resources.duplicate(true)
		await keyboard_press(choices[0])
		check(Progression.pending_choices_remaining(session.overworld.hero)==pending_before-1,"keyboard specialty did not consume exactly one choice")
		check(Progression.specialty_rank(session.overworld.hero,selected)==rank_before+1,"keyboard specialty did not apply its authoritative rank")
		check(session.overworld.resources==resources_before,"specialty UI changed resources")
		await inspect("after_choice")
	var alternates: Array=buttons("HeroActions").filter(func(b):return not b.disabled)
	if not alternates.is_empty():
		await keyboard_press(alternates[0])
		check(session.overworld.active_hero_id!=primary_id,"keyboard alternate command failed")
		await inspect("alternate_command")
		var return_buttons: Array=buttons("HeroActions").filter(func(b):return not b.disabled)
		if not return_buttons.is_empty(): await keyboard_press(return_buttons[0])
		check(session.overworld.active_hero_id==primary_id,"return to primary command failed")
		await inspect("primary_return")
	var expected: Dictionary=normalized(session.to_dict())
	var path: String=SaveService.save_session(session.to_dict(),3)
	session=SessionState.restore_session(SaveService.load_session(3))
	check(path!="" and normalized(session.to_dict())==expected,"complete command save/resume changed session state")
	await enter()
	await inspect("resumed_entry")
	print("TOWN_COMMAND_ENTRY "+JSON.stringify({"ok":errors.is_empty(),"checks":checks,"errors":errors,"rows":rows,"fixture":"isolated progression-authority XP plus paid hire; not full-match evidence"}))
	get_tree().quit(0 if errors.is_empty() else 1)
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--label', required=True)
    parser.add_argument('--save', type=Path, required=True)
    parser.add_argument('--resolution', choices=['1280x720', '1920x1080'], required=True)
    parser.add_argument('--reference-town-revision', help='Exact old commit for a disposable original Town scene control.')
    args = parser.parse_args()
    if not args.label or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789_-' for c in args.label):
        parser.error('label must be a fresh lowercase slug')
    if args.reference_town_revision and not re.fullmatch('[0-9a-f]{8,40}', args.reference_town_revision):
        parser.error('reference must be an exact commit hash')
    save = args.save.resolve(strict=True)
    save_hash = hashlib.sha256(save.read_bytes()).hexdigest()
    out = OUTPUT / args.label
    out.mkdir(parents=True, exist_ok=False)
    owners = ['scenes/town/TownShell.gd', 'scenes/town/TownShell.tscn']
    hashes = {p: hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in owners}
    with tempfile.TemporaryDirectory(prefix='town-command-', dir=OUTPUT) as temporary:
        work = Path(temporary)
        reference_scene = ''
        if args.reference_town_revision:
            sources = {p: subprocess.check_output(['git', 'show', f'{args.reference_town_revision}:{p}'], cwd=ROOT) for p in owners}
            hashes = {p: hashlib.sha256(value).hexdigest() for p, value in sources.items()}
            (work/'reference.gd').write_bytes(sources[owners[0]])
            town_scene = sources[owners[1]].decode()
            anchor = 'path="res://scenes/town/TownShell.gd"'
            if town_scene.count(anchor) != 1:
                raise ValueError('reference Town script owner changed')
            town_scene = town_scene.replace(anchor, 'path="res://%s"' % (work/'reference.gd').relative_to(ROOT), 1)
            (work/'reference.tscn').write_text(town_scene)
            reference_scene = 'res://' + str((work/'reference.tscn').relative_to(ROOT))
        script = work / 'probe.gd'
        script.write_text(SCRIPT)
        scene = work / 'probe.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="TownCommand" type="Node"]\nscript = ExtResource("1")\n' % script.relative_to(ROOT))
        command = ['dbus-run-session', '--', 'xvfb-run', '-a', '-s', '-screen 0 2200x1200x24', 'godot4', '--path', str(ROOT), '--audio-driver', 'Dummy', '--accessibility', 'disabled', '--resolution', args.resolution, 'res://' + str(scene.relative_to(ROOT))]
        env = dict(os.environ, XDG_DATA_HOME=str(out/'data'), TOWN_COMMAND_OUTPUT=str(out), TOWN_COMMAND_SAVE=str(save), TOWN_COMMAND_RESOLUTION=args.resolution, TOWN_COMMAND_REFERENCE_SCENE=reference_scene)
        with (out/'runtime.log').open('w') as log:
            code = run_probe(command, env, log)
    lines = (out/'runtime.log').read_text().splitlines()
    marker = 'TOWN_COMMAND_ENTRY '
    reports = [json.loads(line[len(marker):]) for line in lines if line.startswith(marker)]
    report = reports[-1] if reports else {'ok': False, 'errors': ['missing report']}
    report.update(returncode=code, save_sha256=save_hash, input_save_unchanged=save_hash==hashlib.sha256(save.read_bytes()).hexdigest(), resolution=args.resolution, reference_town_revision=args.reference_town_revision, source_hashes=hashes, runtime_errors=[s for s in lines if s.startswith(('ERROR:', 'SCRIPT ERROR:')) or 'leaked' in s])
    report['ok'] = bool(report['ok']) and code==0 and report['input_save_unchanged'] and not report['runtime_errors']
    (out/'report.json').write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps(report))
    return 0 if report['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
