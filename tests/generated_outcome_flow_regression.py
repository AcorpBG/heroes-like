#!/usr/bin/env python3
"""Actual generated terminal save: readable outcome and confirmed fresh retry."""
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
const Heroes = preload("res://scripts/core/HeroCommandRules.gd")
const Store = preload("res://scripts/core/SessionStateStore.gd")
const Rules = preload("res://scripts/core/ScenarioRules.gd")
const Factory = preload("res://scripts/core/ScenarioFactory.gd")
var errors := []
var checks := 0
var observations := []
var session
var out := ""
func _ready() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:errors.append(message)
func normalized(value):return JSON.parse_string(JSON.stringify(value))
func settle() -> void:
	for frame in range(8):await get_tree().process_frame
func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(label+".png"))
func layout_checks(shell) -> void:
	var title: Label=shell.get_node("%Header")
	var viewport := Rect2(Vector2.ZERO,get_viewport().get_visible_rect().size)
	check(title.is_visible_in_tree() and title.size.y>=24 and title.size.x>100,"outcome title has no readable rendered area")
	check(shell._banner.get_global_rect().encloses(title.get_global_rect()),"outcome title escapes the compact banner")
	for control in [shell._banner,shell._command_column,shell._sidebar_shell]:
		check(viewport.encloses(control.get_global_rect()),"outcome edge controls exceed the viewport: "+str(control.name)+" "+str(control.get_global_rect()))
	check(not shell._banner.get_global_rect().intersects(shell._command_column.get_global_rect()),"outcome banner overlaps footer commands")
	check(not shell._command_column.get_global_rect().intersects(shell._sidebar_shell.get_global_rect()),"outcome footer commands overlap navigation")
	for button in [shell._save_button,shell._menu_button,shell._recap_details_button,shell._guide_button]:
		check(button.is_visible_in_tree() and viewport.encloses(button.get_global_rect()),"outcome navigation is clipped: "+str(button.name)+" "+str(button.get_global_rect()))
func unavailable_control(payload: Dictionary, label: String) -> void:
	# Deliberate isolated failure fixtures; never edit the owner's retained saves
	# or packages and never count these synthetic outcomes as completed matches.
	var fixture=Store.new_session_data()
	fixture.from_dict(payload.duplicate(true))
	if label=="missing_package":
		fixture.overworld.native_random_map_package_session_adoption.map_package_path=out.path_join("does-not-exist.amap")
	elif label=="changed_package":
		fixture.flags.map_package_ref.package_hash="deliberately_mismatched_hash"
	elif label=="changed_scenario":
		fixture.flags.scenario_package_ref.scenario_hash="deliberately_mismatched_hash"
	else:
		fixture.overworld.erase("native_random_map_package_session_adoption")
	fixture=SessionState.set_active_session(fixture)
	AppRouter.resume_active_session()
	await settle()
	var shell=get_tree().current_scene
	var before=normalized(fixture.to_dict())
	var action_id: String="skirmish_start:"+fixture.scenario_id
	shell.validation_request_outcome_new_session_confirmation(action_id)
	await settle()
	var result: Dictionary=shell.validation_confirm_outcome_new_session_confirmation()
	await settle()
	check(not result.get("ok",true) and not result.get("routed",true),label+": invalid packages started a replacement game")
	check(String(result.get("message","")).contains("original generated map packages"),label+": missing actionable failure message")
	check(SessionState.active_session==fixture and normalized(fixture.to_dict())==before,label+": failure mutated the completed game")
	check(get_tree().current_scene==shell and shell._action_status_label.is_visible_in_tree(),label+": failure left outcome or hid feedback")
	check(shell._action_status_label.tooltip_text.contains(String(result.get("message",""))),label+": complete failure explanation missing from tooltip")
	layout_checks(shell)
	observations.append({"case":label,"result":result})
	if label=="missing_package":await capture("retry_unavailable")
func title_controls(payload: Dictionary) -> void:
	var authored=Factory.create_session("river-pass","normal",Store.LAUNCH_MODE_SKIRMISH)
	var expected: String=ContentService.get_scenario_readonly("river-pass").name
	check(String(Rules.build_outcome_model(authored).header).ends_with(expected),"authored scenario display name changed")
	var fixture=Store.new_session_data()
	fixture.from_dict(payload.duplicate(true))
	var long_title="The Fallen Lanterns Beyond the Northern Marshes and the Far Shores of the Silent Sea"
	for owner in [fixture.flags,fixture.overworld]:
		owner.native_random_map_runtime_scenario_record.name=long_title
	fixture=SessionState.set_active_session(fixture)
	AppRouter.resume_active_session()
	await settle()
	var shell=get_tree().current_scene
	var title: Label=shell.get_node("%Header")
	check(title.text=="Defeat | "+long_title and title.tooltip_text==title.text,"custom long display name was altered or lost in tooltip")
	layout_checks(shell)
	await capture("long_title")
func run() -> void:
	get_tree().current_scene=null
	out=OS.get_environment("OUTCOME_PROBE_OUTPUT")
	SettingsService.set_presentation_mode("windowed")
	SettingsService.set_presentation_resolution(OS.get_environment("OUTCOME_PROBE_RESOLUTION"))
	var payload: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("OUTCOME_PROBE_SAVE")))
	var opening: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("OUTCOME_PROBE_OPENING")))
	check(payload.scenario_status=="defeat" and opening.day==1,"probe requires an actual loss and its recorded opening")
	check(SaveService.save_session(payload,1)!="","isolated terminal save copy failed")
	session=SaveService.restore_manual_session(1)
	if session==null:
		push_error("production terminal restore failed");get_tree().quit(1);return
	session=SessionState.set_active_session(session)
	for key in ["saved_at_unix","save_slot_type","saved_from_game_state","saved_from_scenario_status","saved_from_launch_mode"]:payload.erase(key)
	check(normalized(session.to_dict())==payload,"production load changed terminal gameplay state")
	AppRouter.resume_active_session()
	await settle()
	var shell=get_tree().current_scene
	check(String(shell.scene_file_path).ends_with("ScenarioOutcomeShell.tscn"),"actual saved loss did not route to outcome")
	check(shell._session==session,"probe observes a detached outcome session")
	var entry: Dictionary=shell.validation_outcome_focus_snapshot()
	check(not shell._recap_expanded and entry.get("focused_action_id","")==entry.get("primary_action_id","missing"),"collapsed outcome did not focus its primary action")
	var before: Dictionary=normalized(session.to_dict())
	var profile_before=normalized(CampaignProgression.profile)
	var manual_before=FileAccess.get_sha256("user://saves/slot1.json")
	var title: Label=shell.get_node("%Header")
	check(not title.text.contains(session.scenario_id) and not title.text.contains("native_h3maped"),"outcome title leaks the raw generated runtime id")
	check(title.tooltip_text==title.text and not title.text.is_empty(),"complete display title is unavailable in tooltip")
	check(title.text_overrun_behavior==TextServer.OVERRUN_TRIM_ELLIPSIS or title.autowrap_mode!=TextServer.AUTOWRAP_OFF,"outcome title silently clips instead of intentional wrapping/ellipsis")
	layout_checks(shell)
	observations.append({"title":title.text,"title_rect":str(title.get_global_rect())})
	await capture("terminal_outcome")
	shell._on_recap_details_pressed()
	await settle()
	check(shell._recap_tabs.is_visible_in_tree(),"Details control failed to open actual recap")
	layout_checks(shell)
	check(normalized(session.to_dict())==before,"reading outcome details changed gameplay")
	await capture("terminal_details")
	shell._on_recap_details_pressed()
	await settle()
	var action_id: String="skirmish_start:"+session.scenario_id
	var request: Dictionary=shell.validation_request_outcome_new_session_confirmation(action_id)
	check(request.get("confirmation_required",false) and shell._new_session_confirmation_dialog.visible,"Retry Skirmish did not open its existing confirmation")
	check(SessionState.active_session==session and normalized(session.to_dict())==before,"retry request started a game before confirmation")
	var cancel: Dictionary=shell.validation_cancel_outcome_new_session_confirmation()
	await settle()
	check(cancel.get("ok",false) and SessionState.active_session==session and normalized(session.to_dict())==before,"retry cancellation changed the completed game")
	request=shell.validation_request_outcome_new_session_confirmation(action_id)
	await settle()
	var result: Dictionary=shell.validation_confirm_outcome_new_session_confirmation()
	await settle()
	observations.append({"title":title.text if is_instance_valid(title) else "scene changed","request":request,"retry":result})
	check(result.get("ok",false) and result.get("routed",false),"confirmed generated Retry Skirmish did not start a real new game")
	var fresh=SessionState.active_session
	if result.get("ok",false) and result.get("routed",false):
		check(fresh!=session and fresh.day==1 and fresh.scenario_status=="in_progress","retry did not create a fresh nonterminal session")
		check(String(get_tree().current_scene.scene_file_path).ends_with("OverworldShell.tscn"),"confirmed retry did not enter actual Overworld")
		check(fresh.scenario_id==session.scenario_id and fresh.difficulty==session.difficulty,"retry changed scenario identity or difficulty")
		check(fresh.hero_id==opening.hero_id and normalized(fresh.overworld.players)==opening.overworld.players,"retry changed the original faction/hero/player choice")
		for key in ["map","hero_position","army","towns","resource_nodes","artifact_nodes"]:
			check(normalized(fresh.overworld.get(key))==opening.overworld.get(key),"fresh retry differs from recorded same-map opening: "+key)
		check(int(Heroes.active_hero(fresh).get("experience",0))==int(opening.overworld.hero.get("experience",0)),"retry retained defeated commander experience")
		await capture("fresh_retry_overworld")
	check(normalized(session.to_dict())==before,"retry mutated the source terminal session")
	for label in ["missing_package","changed_package","changed_scenario","legacy_missing_boundary"]:
		await unavailable_control(payload,label)
	await title_controls(payload)
	check(normalized(CampaignProgression.profile)==profile_before,"generated retry changed campaign progression")
	check(not manual_before.is_empty() and FileAccess.get_sha256("user://saves/slot1.json")==manual_before,"retry changed the protected terminal manual save")
	print("GENERATED_OUTCOME_FLOW_REGRESSION "+JSON.stringify({"ok":errors.is_empty(),"checks":checks,"failures":errors,"observations":observations}))
	get_tree().quit(0 if errors.is_empty() else 1)
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--label', required=True)
    parser.add_argument('--save', type=Path, required=True)
    parser.add_argument('--opening', type=Path, required=True)
    parser.add_argument('--resolution', choices=['1280x720', '1920x1080'], default='1280x720')
    args = parser.parse_args()
    if not args.label or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789_-' for c in args.label):
        parser.error('label must be a fresh lowercase slug')
    source, opening = args.save.resolve(), args.opening.resolve()
    hashes = {str(path): hashlib.sha256(path.read_bytes()).hexdigest() for path in [source, opening]}
    out = OUTPUT / args.label
    out.mkdir(parents=True, exist_ok=False)
    with tempfile.TemporaryDirectory(prefix='outcome-flow-', dir=OUTPUT) as temporary:
        work = Path(temporary)
        script = work / 'probe.gd'
        script.write_text(SCRIPT)
        scene = work / 'probe.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="OutcomeFlow" type="Node"]\nscript = ExtResource("1")\n' % script.relative_to(ROOT))
        command = ['dbus-run-session', '--', 'xvfb-run', '-a', '-s', '-screen 0 2200x1200x24', 'godot4', '--path', str(ROOT), '--audio-driver', 'Dummy', '--accessibility', 'disabled', '--resolution', args.resolution, 'res://' + str(scene.relative_to(ROOT))]
        env = dict(os.environ, XDG_DATA_HOME=str(out / 'data'), OUTCOME_PROBE_OUTPUT=str(out), OUTCOME_PROBE_SAVE=str(source), OUTCOME_PROBE_OPENING=str(opening), OUTCOME_PROBE_RESOLUTION=args.resolution)
        with (out / 'runtime.log').open('w') as log:
            code = run_probe(command, env, log)
    lines = (out / 'runtime.log').read_text().splitlines()
    marker = 'GENERATED_OUTCOME_FLOW_REGRESSION '
    reports = [json.loads(line[len(marker):]) for line in lines if line.startswith(marker)]
    report = reports[-1] if reports else {'ok': False, 'failures': ['missing report']}
    report.update(returncode=code, source_hashes=hashes, resolution=args.resolution,
                  source_files_unchanged=all(hashlib.sha256(Path(path).read_bytes()).hexdigest() == digest for path, digest in hashes.items()),
                  runtime_errors=[line for line in lines if line.startswith(('ERROR:', 'SCRIPT ERROR:')) or 'leaked' in line])
    report['ok'] = bool(report['ok']) and code == 0 and report['source_files_unchanged'] and not report['runtime_errors']
    (out / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report))
    return 0 if report['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
