#!/usr/bin/env python3
"""Real generated Town command / Overworld footer layout and save-flow controls."""
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
var errors := []
var checks := 0
var rows := []
var out := ""
var session
func _ready() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: errors.append(message)
func normalized(value):
	return JSON.parse_string(JSON.stringify(value))
func settle() -> void:
	for frame in range(8): await get_tree().process_frame
	var started:=Time.get_ticks_msec()
	while get_tree().current_scene.scene_file_path.ends_with("TownShell.tscn") and get_tree().current_scene._town_action_input_blocker.visible:
		if Time.get_ticks_msec()-started>30000:
			errors.append("Town construction handoff timed out");break
		await get_tree().process_frame
func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(label+".png"))
func footer(shell, label: String) -> void:
	var panel: Control=shell.get_node("%SystemPanel")
	var status: Label=shell.get_node("%SaveStatus")
	# The raster frame's inner chevrons extend beyond its old 18px content inset.
	var safe:=panel.get_global_rect().grow_individual(-28,0,-28,0)
	check(status.is_visible_in_tree() and safe.encloses(status.get_global_rect()),label+": save status overlaps the scenic frame")
	check(status.get_theme_font("font").get_string_size(status.text,HORIZONTAL_ALIGNMENT_LEFT,-1,status.get_theme_font_size("font_size")).x<=status.size.x,label+": save status text does not fit")
	var rects: Array=[status.get_global_rect()]
	for name in ["EndTurn","Save","Settings","Menu"]:
		var button: Button=shell.get_node("%"+name)
		var rect:=button.get_global_rect()
		check(button.is_visible_in_tree() and safe.encloses(rect),label+": footer button clips: "+name)
		for previous in rects:check(not rect.intersects(previous),label+": footer controls overlap: "+name)
		rects.append(rect)
	check(shell.get_viewport_rect().encloses(panel.get_global_rect()),label+": system footer leaves viewport")
	rows.append({"label":label,"safe_rect":safe,"panel_rect":panel.get_global_rect(),"status_rect":status.get_global_rect(),"text":status.text,"tooltip":status.tooltip_text})
func run() -> void:
	get_tree().current_scene=null
	out=OS.get_environment("COMMAND_LAYOUT_OUTPUT")
	SettingsService.set_presentation_mode("windowed")
	SettingsService.set_presentation_resolution(OS.get_environment("COMMAND_LAYOUT_RESOLUTION"))
	var payload: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("COMMAND_LAYOUT_SAVE")))
	check(SaveService.save_session(payload,1)!="","isolated opening save copy failed")
	session=SaveService.restore_manual_session(1)
	if session==null:
		push_error("production opening restore failed");get_tree().quit(1);return
	session=SessionState.set_active_session(session)
	check(not ContentService.get_scenario_readonly(session.scenario_id).is_empty(),"production load did not register the generated scenario")
	AppRouter.go_to_overworld()
	await settle()
	var shell=get_tree().current_scene
	var before: Dictionary=normalized(session.to_dict())
	footer(shell,"ordinary")
	await capture("overworld")
	var opened: Dictionary=shell._on_save_pressed()
	await settle()
	var dialog=shell.get_node("ManualSaveOverwriteDialog")
	check(bool(opened.get("ok",false)) and dialog.visible and dialog._file_name.is_visible_in_tree(),"normal Save did not open the real named-file browser")
	check(normalized(session.to_dict())==before,"opening named-file browser mutated gameplay")
	dialog.hide()
	await settle()
	# Presentation-only control: the actual failure surface retains its action.
	# Real transactional failures are covered by the separate named-save suite.
	shell._set_generated_opening_autosave_failure_surface()
	await settle()
	footer(shell,"save_failure")
	check(shell.get_node("%SaveStatus").text.to_lower().contains("failed"),"save failure disappeared from the footer")
	check(shell.get_node("%Save").tooltip_text==shell.GENERATED_OPENING_AUTOSAVE_FAILURE_MESSAGE,"save failure lost its explanation/retry instructions")
	check(normalized(session.to_dict())==before,"save failure presentation mutated gameplay")
	await capture("save_failure")
	var town: Dictionary=session.overworld.towns.filter(func(t):return t.owner=="player")[0]
	check(OverworldRules.set_active_town_visit(session,town.placement_id).get("ok",false),"opening hero cannot enter its own town")
	AppRouter.go_to_town()
	await settle()
	shell=get_tree().current_scene
	var offered: Array=TownRules.get_build_actions(session).filter(func(a):return not a.get("disabled",true) and a.get("direct_affordable",true) and String(a.id).begins_with("build:"))
	check(not offered.is_empty(),"opening has no ordinary affordable construction control")
	if not offered.is_empty():
		var building_id: String=String(offered[0].id).trim_prefix("build:")
		shell._commit_build_action(building_id)
		await settle()
		session=SessionState.ensure_active_session()
		check(building_id in TownRules.get_active_town(session).built_buildings,"ordinary construction failed")
	before=normalized(session.to_dict())
	var hero: Label=shell.get_node("%Hero")
	check(hero.get_line_count()<=2 and hero.size.y<=52,"commander prose crowds the scenic command rail")
	check(hero.text.contains(session.overworld.hero.name) and hero.text.contains("XP"),"compact identity lost hero name or progression")
	check(hero.tooltip_text==OverworldRules.describe_hero(session),"compact identity lost complete authoritative details")
	var panel: Control=shell.get_node("%CommandPanel")
	check(panel.get_global_rect().encloses(hero.get_global_rect()),"hero identity leaves command panel")
	var placeholders:=0
	for lane in ["HeroActions","SpecialtyActions"]:
		for child in shell.get_node("%"+lane).get_children():
			if child is Label:
				placeholders+=1
				check(child.autowrap_mode!=TextServer.AUTOWRAP_OFF and child.text_overrun_behavior!=TextServer.OVERRUN_NO_TRIMMING,"empty command state clips without wrapping or ellipsis: "+lane)
				check(child.get_parent().get_global_rect().encloses(child.get_global_rect()),"empty command state leaves its lane: "+lane)
				check(child.tooltip_text!="","empty command state lost complete details: "+lane)
	check(placeholders>0,"opening does not exercise empty-state labels")
	var layout: Dictionary=shell.validation_owner_town_layout_snapshot()
	check(layout.sidebar_contained and layout.direct_action_dock_visible,"Town command rail or five-dialog dock clips")
	check(not layout.sidebar_rect.intersects(layout.footer_rect),"Town command rail overlaps navigation")
	check(normalized(session.to_dict())==before,"command layout observation mutated gameplay")
	await capture("town")
	rows.append({"label":"town","hero_text":hero.text,"hero_tooltip":hero.tooltip_text,"hero_lines":hero.get_line_count(),"hero_rect":hero.get_global_rect(),"layout":layout})
	print("GENERATED_COMMAND_LAYOUT "+JSON.stringify({"ok":errors.is_empty(),"checks":checks,"errors":errors,"rows":rows}))
	get_tree().quit(0 if errors.is_empty() else 1)
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--label', required=True)
    parser.add_argument('--save', type=Path, required=True)
    parser.add_argument('--resolution', choices=['1280x720', '1920x1080'], required=True)
    args = parser.parse_args()
    if not args.label or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789_-' for c in args.label):
        parser.error('label must be a fresh lowercase slug')
    save = args.save.resolve(strict=True)
    out = OUTPUT / args.label
    out.mkdir(parents=True, exist_ok=False)
    owners = ['scenes/town/TownShell.gd', 'scenes/town/TownShell.tscn', 'scenes/overworld/OverworldShell.gd', 'scenes/overworld/OverworldShell.tscn']
    hashes = {p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in owners}
    with tempfile.TemporaryDirectory(prefix='command-layout-', dir=OUTPUT) as temporary:
        work = Path(temporary)
        script = work / 'probe.gd'
        script.write_text(SCRIPT)
        scene = work / 'probe.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="CommandLayout" type="Node"]\nscript = ExtResource("1")\n' % script.relative_to(ROOT))
        command = ['dbus-run-session', '--', 'xvfb-run', '-a', '-s', '-screen 0 2200x1200x24', 'godot4', '--path', str(ROOT), '--audio-driver', 'Dummy', '--accessibility', 'disabled', '--resolution', args.resolution, 'res://' + str(scene.relative_to(ROOT))]
        env = dict(os.environ, XDG_DATA_HOME=str(out/'data'), COMMAND_LAYOUT_OUTPUT=str(out), COMMAND_LAYOUT_SAVE=str(save), COMMAND_LAYOUT_RESOLUTION=args.resolution)
        with (out/'runtime.log').open('w') as log:
            code = run_probe(command, env, log)
    lines = (out/'runtime.log').read_text().splitlines()
    marker = 'GENERATED_COMMAND_LAYOUT '
    reports = [json.loads(line[len(marker):]) for line in lines if line.startswith(marker)]
    report = reports[-1] if reports else {'ok':False,'errors':['missing report']}
    report.update(returncode=code, save_sha256=hashlib.sha256(save.read_bytes()).hexdigest(), resolution=args.resolution, source_hashes=hashes, runtime_errors=[s for s in lines if s.startswith(('ERROR:', 'SCRIPT ERROR:')) or 'leaked' in s])
    report['ok'] = bool(report['ok']) and code==0 and not report['runtime_errors']
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report))
    return 0 if report['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
