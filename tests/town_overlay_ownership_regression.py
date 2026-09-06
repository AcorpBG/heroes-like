#!/usr/bin/env python3
"""Real generated Town overlay ownership, normal construction and save controls."""
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
	for frame in range(6): await get_tree().process_frame
	var started:=Time.get_ticks_msec()
	while get_tree().current_scene.get_node("%TownActionInputBlocker").visible:
		if Time.get_ticks_msec()-started>30000:
			errors.append("normal Town input handoff timed out");break
		await get_tree().process_frame
func inspect(label: String) -> void:
	var shell=get_tree().current_scene
	var stage=shell.get_node("%TownStage")
	var overlay: Dictionary=stage.validation_scenic_overlay_summary()
	var heading: Dictionary=stage.validation_header_action_count_summary()
	var layout: Dictionary=shell.validation_owner_town_layout_snapshot()
	check(not bool(overlay.get("district_strip_visible",true)),label+": standalone district strip still paints behind Town footer")
	check(not bool(heading.get("visible",true)),label+": duplicate standalone title/count header still covers the scenery")
	check(bool(layout.header_single_row) and bool(layout.footer_contained),label+": compact header or footer bounds regressed")
	check(shell.get_node("%Resources").is_visible_in_tree(),label+": resource ledger disappeared")
	var controls:=[]
	for name in ["Save","Leave","Guide","Settings","Menu"]:
		var button: Button=shell.get_node("%"+name)
		var rect:=button.get_global_rect()
		check(button.is_visible_in_tree() and layout.viewport_rect.encloses(rect),label+": footer control clipped or hidden: "+name)
		for prior in controls: check(not rect.intersects(prior),label+": footer controls overlap")
		controls.append(rect)
	var before: Dictionary=normalized(session.to_dict())
	shell._open_town_catalog("log")
	await get_tree().process_frame
	var copy: String=shell.get_node("%TownCatalogSubtitle").text
	check(copy.contains("Garrison") and copy.contains("Districts:"),label+": hidden stage summaries are not retained in Log")
	for district in overlay.district_payloads:
		check(copy.contains("%s %d" % [district.label,int(district.value)]),label+": district count missing from Log: "+String(district.label))
	check(normalized(session.to_dict())==before,label+": opening Log mutated gameplay")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(label+"_log.png"))
	shell._close_town_catalog(false)
	stage.set_external_command_overlay(false)
	var standalone: Dictionary=stage.validation_scenic_overlay_summary()
	check(bool(standalone.get("district_strip_visible",false)) and bool(stage.validation_header_action_count_summary().get("visible",false)),label+": standalone preview lost its own summaries")
	check(standalone.district_rects.size()==5 and standalone.status_rects.size()==4,label+": standalone preview lost real overlay geometry")
	check(standalone.scene_rect.encloses(standalone.district_strip_rect) and is_equal_approx(standalone.district_strip_rect.size.x,620.0),label+": standalone district ribbon changed size or clips")
	check(standalone.district_payloads==overlay.district_payloads and bool(standalone.status_district_nonoverlap),label+": standalone summary data changed or overlaps status")
	stage.set_external_command_overlay(true)
	await settle()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(label+".png"))
	rows.append({"label":label,"overlay":overlay,"header":heading,"layout":layout,"log_summary":copy})
func run() -> void:
	get_tree().current_scene=null
	out=OS.get_environment("TOWN_OVERLAY_OUTPUT")
	SettingsService.set_presentation_mode("windowed")
	SettingsService.set_presentation_resolution(OS.get_environment("TOWN_OVERLAY_RESOLUTION"))
	var payload: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("TOWN_OVERLAY_SAVE")))
	session=SessionState.restore_session(payload)
	var town: Dictionary=session.overworld.towns.filter(func(t):return t.owner=="player")[0]
	var visit: Dictionary=OverworldRules.set_active_town_visit(session,town.placement_id)
	check(visit.get("ok",false),"generated opening hero cannot enter its real starting town")
	AppRouter.go_to_town()
	await settle()
	await inspect("opening")
	var offered: Array=TownRules.get_build_actions(session).filter(func(a):return not a.get("disabled",true) and a.get("direct_affordable",true) and String(a.id).begins_with("build:"))
	check(not offered.is_empty(),"normal opening has no affordable construction control")
	if not offered.is_empty():
		var building_id: String=String(offered[0].id).trim_prefix("build:")
		get_tree().current_scene._commit_build_action(building_id)
		await settle()
		session=SessionState.ensure_active_session()
		check(building_id in TownRules.get_active_town(session).built_buildings,"normal construction did not commit its building")
		await inspect("after_build")
	var path: String=SaveService.save_session(session.to_dict(),3)
	var resumed=SessionState.restore_session(SaveService.load_session(3))
	check(path!="" and normalized(resumed.to_dict())==normalized(session.to_dict()),"complete Town save/resume changed gameplay state")
	print("TOWN_OVERLAY_OWNERSHIP "+JSON.stringify({"ok":errors.is_empty(),"checks":checks,"errors":errors,"rows":rows}))
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
    with tempfile.TemporaryDirectory(prefix='town-overlay-', dir=OUTPUT) as temporary:
        work = Path(temporary)
        script = work / 'probe.gd'
        script.write_text(SCRIPT)
        scene = work / 'probe.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="TownOverlay" type="Node"]\nscript = ExtResource("1")\n' % script.relative_to(ROOT))
        command = ['dbus-run-session', '--', 'xvfb-run', '-a', '-s', '-screen 0 2200x1200x24', 'godot4', '--path', str(ROOT), '--audio-driver', 'Dummy', '--accessibility', 'disabled', '--resolution', args.resolution, 'res://' + str(scene.relative_to(ROOT))]
        env = dict(os.environ, XDG_DATA_HOME=str(out / 'data'), TOWN_OVERLAY_OUTPUT=str(out), TOWN_OVERLAY_SAVE=str(save), TOWN_OVERLAY_RESOLUTION=args.resolution)
        with (out / 'runtime.log').open('w') as log:
            code = run_probe(command, env, log)
    lines = (out / 'runtime.log').read_text().splitlines()
    marker = 'TOWN_OVERLAY_OWNERSHIP '
    reports = [json.loads(line[len(marker):]) for line in lines if line.startswith(marker)]
    report = reports[-1] if reports else {'ok': False, 'errors': ['missing report']}
    owners = ['scenes/town/TownShell.gd', 'scenes/town/TownStageView.gd']
    report.update(returncode=code, save_sha256=hashlib.sha256(save.read_bytes()).hexdigest(), resolution=args.resolution, source_hashes={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in owners}, runtime_errors=[s for s in lines if s.startswith(('ERROR:', 'SCRIPT ERROR:')) or 'leaked' in s])
    report['ok'] = bool(report['ok']) and code == 0 and not report['runtime_errors']
    (out / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report))
    return 0 if report['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
