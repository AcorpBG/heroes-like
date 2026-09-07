#!/usr/bin/env python3
"""Town caption fit and unchanged ledger/input/save behavior, at three sizes.

The authored mode borrows only the recorded stockpile for a detached small UI
fixture. It is not a generated match or paid-progression claim. The default mode
visits the actual owned starting Town from the supplied generated save.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import tempfile

import overworld_stockpile_text_fit_regression as stockpile
from generated_town_order_profile import ROOT, OUTPUT, run_probe

TOWN = r'''
func inspect_town(session, resolution: Vector2i) -> void:
	get_window().content_scale_size=resolution
	get_window().size=resolution
	await settle();await settle()
	var shell=get_tree().current_scene
	check(shell.scene_file_path.ends_with("TownShell.tscn"),"actual Town scene")
	check(shell._session==session and SessionState.ensure_active_session()==session,"input checks use the actual active Town model")
	var menu=shell.get_node("%Resources")
	var before: Dictionary=normalized(session.to_dict())
	var original_rect: Rect2=menu.get_global_rect()
	var original_tooltip: String=menu.tooltip_text
	var full_summary: String=menu.full_summary_text()
	var label: String="%dx%d" % [resolution.x,resolution.y]
	check(required_width(menu,menu.text)<=menu.size.x,label+": Town stockpile caption is clipped")
	check(original_tooltip==full_summary and not full_summary.is_empty(),label+": complete stockpile tooltip")
	menu_contract(menu,session.overworld.resources,label)
	var layout: Dictionary=shell.validation_owner_town_layout_snapshot()
	check(layout.header_single_row and layout.footer_contained and layout.scenic_reaches_viewport_edges,label+": compact scenic layout retained")
	check(shell.get_node("%Banner").get_global_rect().encloses(original_rect),label+": resource menu inside header")
	await capture(label+"_town")
	menu.grab_focus()
	await action("ui_accept")
	var popup: PopupMenu=menu.get_popup()
	check(popup.visible,label+": keyboard opens resource ledger")
	check(popup.get_theme_color("font_disabled_color").is_equal_approx(Color(0.94,0.9,0.81,1)),label+": read-only ledger amounts use opaque legible text")
	check(Rect2(get_viewport().get_visible_rect()).encloses(Rect2(popup.position,popup.size)),label+": ledger inside viewport")
	await capture(label+"_ledger")
	await action("ui_cancel")
	check(not popup.visible and menu.has_focus(),label+": Escape restores resource focus")
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new()
		event.position=get_viewport().get_final_transform()*menu.get_global_rect().get_center()
		event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
		Input.parse_input_event(event)
		await get_tree().process_frame
	await settle()
	check(popup.visible,label+": pointer opens same ledger")
	await action("ui_cancel")
	check(not popup.visible and menu.has_focus(),label+": pointer ledger dismiss/focus")
	var font_size: int=menu.get_theme_font_size("font_size")
	menu.add_theme_font_size_override("font_size",font_size+6)
	await settle()
	check(required_width(menu,menu.text)<=menu.size.x,label+": larger-font caption still fits")
	menu.add_theme_font_size_override("font_size",font_size)
	await settle()
	check(menu.get_global_rect()==original_rect,label+": caption does not expand header")
	check(menu.tooltip_text==original_tooltip,label+": input/theme retained complete tooltip")
	menu_contract(menu,session.overworld.resources,label+" after input")
	check(normalized(session.to_dict())==before,label+": complete state unchanged by menu/input/theme")
	observations.append({"resolution":label,"text":menu.text,"required_width":required_width(menu,menu.text),"available_width":menu.size.x,"full_summary_width":required_width(menu,full_summary),"ledger_items":popup.item_count})
func run() -> void:
	get_tree().current_scene=null
	out=OS.get_environment("TOWN_STOCKPILE_OUTPUT")
	SettingsService.set_presentation_mode("windowed")
	var payload: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("TOWN_STOCKPILE_SAVE")))
	var authored: bool=OS.get_environment("TOWN_STOCKPILE_AUTHORED")=="1"
	var session
	if authored:
		# Explicit UI-only projection, never a continuation of the generated match.
		session=ScenarioFactory.create_session("river-pass","normal",SessionState.LAUNCH_MODE_SKIRMISH)
		var town: Dictionary=_first_player_town(session)
		check(not town.is_empty(),"authored fixture owns a Town")
		if town.is_empty(): get_tree().quit(1);return
		_move_active_hero_to_town(session,town)
		session.overworld.resources=payload.overworld.resources.duplicate(true)
		SessionState.set_active_session(session)
	else:
		session=SessionState.restore_session(payload)
	var town: Dictionary=_first_player_town(session)
	check(not town.is_empty(),"owned Town exists")
	if town.is_empty(): get_tree().quit(1);return
	var visit: Dictionary=OverworldRules.set_active_town_visit(session,town.placement_id)
	check(visit.get("ok",false),"hero can visit its actual Town")
	AppRouter.go_to_town()
	await settle();await settle()
	# set_active_session copies the supplied authored model. Inspect/save the
	# actual UI authority, not that detached setup object.
	session=SessionState.ensure_active_session()
	check(normalized(session.overworld.resources)==normalized(payload.overworld.resources),"recorded nine-resource stockpile retained")
	for resolution in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2048,1079)]:
		await inspect_town(session,resolution)
	var before: Dictionary=normalized(session.to_dict())
	var saved: String=SaveService.save_session(session.to_dict(),3)
	session=SessionState.restore_session(SaveService.load_session(3))
	check(saved!="" and normalized(session.to_dict())==before,"complete Town save/resume equality")
	AppRouter.go_to_town()
	await settle();await settle()
	var menu=get_tree().current_scene.get_node("%Resources")
	menu_contract(menu,session.overworld.resources,"saved Town re-entry")
	check(required_width(menu,menu.text)<=menu.size.x,"saved Town caption fits")
	await capture("saved_town")
	var after_reentry: Dictionary=normalized(session.to_dict())
	check(after_reentry==before,"saved Town re-entry changed state: "+JSON.stringify(differences(before,after_reentry)))
	await component_controls(session.overworld.resources,menu.full_summary_text())
	check(normalized(session.to_dict())==after_reentry,"detached font/resize controls preserve live state: "+JSON.stringify(differences(after_reentry,normalized(session.to_dict()))))
	print("TOWN_STOCKPILE_TEXT_FIT "+JSON.stringify({"ok":errors.is_empty(),"checks":checks,"errors":errors,"observations":observations,"authored_stockpile_projection":authored}))
	get_tree().quit(0 if errors.is_empty() else 1)
'''


def script_text():
    # Reuse the strict nine-resource and font/input controls without changing
    # their shared-default/Overworld contract, or shipping another GDScript test.
    helpers = stockpile.SCRIPT[:stockpile.SCRIPT.index('func run() -> void:')]
    legacy = (ROOT/'tests/resource_stockpile_icon_popover_runtime_report.gd').read_text()
    start = legacy.index('func _first_player_town(')
    end = legacy.index('func _set_window_size(', start)
    return helpers + legacy[start:end] + TOWN


def legacy_town_script():
    """Run existing Town assertions in the actual requested logical viewport."""
    source = (ROOT/'tests/resource_stockpile_icon_popover_runtime_report.gd').read_text()
    anchor = '\tget_window().size = viewport_size\n'
    if source.count(anchor) != 1:
        raise ValueError('review legacy viewport setup')
    adapted = source.replace(anchor, anchor+'\tget_window().content_scale_size = viewport_size\n')
    # The current PanelContainer gives its child the frame's content width;
    # custom_minimum_size is still 80/210, not the actual allocated 92/222.
    # Keep exact frame/minimum bounds and every icon/input/state assertion.
    old_width = 'is_equal_approx(menu.size.x, 80.0 if compact_expected else 210.0)'
    if adapted.count(old_width) != 2:
        raise ValueError('review legacy Town/Overworld width assertions')
    adapted = adapted.replace(old_width, 'is_equal_approx(menu.size.x, resource_chip.size.x - chip_style.get_minimum_size().x)', 1)
    start = adapted.index('\t\tvar overworld_row: Dictionary = await _run_overworld_case(viewport_size)')
    end = adapted.index('\tget_window().size = original_window_size', start)
    return adapted[:start]+adapted[end:]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--save', type=Path, required=True)
    parser.add_argument('--label', required=True)
    parser.add_argument('--authored', action='store_true', help='Detached small Town using only the recorded stockpile; not a generated match')
    parser.add_argument('--legacy-town', action='store_true', help='Run existing authored Town stockpile cases separately from the generated-save regression')
    args = parser.parse_args()
    if args.authored and args.legacy_town:
        parser.error('choose one authored fixture mode')
    if not re.fullmatch('[a-z0-9_-]+',args.label):
        parser.error('fresh lowercase label required')
    save = args.save.resolve(strict=True)
    original = save.read_bytes()
    json.loads(original)
    owners = ['scenes/town/TownShell.gd','scenes/town/TownShell.tscn','scenes/town/TownStageView.gd',
              'scenes/shared/ResourceStockpileMenu.gd','content/town_building_scene_art_manifest.json',
              'tests/town_stockpile_text_fit_regression.py','tests/overworld_stockpile_text_fit_regression.py',
              'tests/resource_stockpile_icon_popover_runtime_report.gd']
    hashes = {p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in owners}
    out = OUTPUT/args.label
    out.mkdir(exist_ok=False)
    script = legacy_town_script() if args.legacy_town else script_text()
    with tempfile.TemporaryDirectory(prefix='town-stockpile-probe-',dir=OUTPUT) as temporary, tempfile.TemporaryDirectory(prefix='town-stockpile-data-',dir='/dev/shm') as data:
        work = Path(temporary)
        (work/'probe.gd').write_text(script)
        scene = work/'probe.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="TownStockpile" type="Node"]\nscript=ExtResource("1")\n' % (work/'probe.gd').relative_to(ROOT))
        env = dict(os.environ,XDG_DATA_HOME=data,TOWN_STOCKPILE_OUTPUT=str(out),TOWN_STOCKPILE_SAVE=str(save),TOWN_STOCKPILE_AUTHORED='1' if args.authored else '0')
        with (out/'runtime.log').open('w') as log:
            code = run_probe(['dbus-run-session','--','xvfb-run','-a','-s','-screen 0 2200x1200x24','godot4','--path',str(ROOT),'--audio-driver','Dummy','--accessibility','disabled','res://'+str(scene.relative_to(ROOT))],env,log,timeout_seconds=480)
    lines = (out/'runtime.log').read_text().splitlines()
    prefix = 'RESOURCE_STOCKPILE_ICON_POPOVER_RUNTIME_REPORT ' if args.legacy_town else 'TOWN_STOCKPILE_TEXT_FIT '
    reports = [json.loads(line[len(prefix):]) for line in lines if line.startswith(prefix)]
    report = reports[-1] if reports else {'ok':False,'errors':['missing completion report']}
    report.update(returncode=code,input_unchanged=save.read_bytes()==original,save_sha256=hashlib.sha256(original).hexdigest(),
                  source_hashes=hashes,source_unchanged=all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==v for p,v in hashes.items()),
                  executed_probe_sha256=hashlib.sha256(script.encode()).hexdigest(),
                  runtime_errors=[s for s in lines if s.startswith(('ERROR:','SCRIPT ERROR:')) or 'leaked' in s])
    report['mode'] = 'legacy_authored_town' if args.legacy_town else 'authored_stockpile_projection' if args.authored else 'actual_generated_save'
    if args.legacy_town:
        report['fixture_adaptation'] = 'Town cases only; actual requested logical viewport; actual menu allocation equals framed content width while original exact frame/minimum bounds and all resource/icon/input/state assertions remain'
    report['ok'] = bool(report['ok'] and code==0 and report['input_unchanged'] and report['source_unchanged'] and not report['runtime_errors'])
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k!='source_hashes'}),flush=True)
    return 0 if report['ok'] else 1


if __name__=='__main__':
    raise SystemExit(main())
