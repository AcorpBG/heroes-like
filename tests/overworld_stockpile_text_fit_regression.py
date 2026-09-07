#!/usr/bin/env python3
"""Real generated stockpile font fit, popup input, complete state and saves."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import tempfile

from generated_town_order_profile import ROOT, OUTPUT, run_probe

SCRIPT = r'''
extends Node
var errors := []
var checks := 0
var observations := []
var out := ""
func _ready() -> void:
	call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: errors.append(label)
func settle() -> void:
	for frame in range(4): await get_tree().process_frame
func normalized(value):
	return JSON.parse_string(JSON.stringify(value))
func differences(a, b, path: String = "", result: Array = []) -> Array:
	if result.size()>=12 or a==b: return result
	if a is Dictionary and b is Dictionary:
		for key in a:
			if not b.has(key): result.append({"path":path+"/"+str(key),"missing_after":true})
			else: differences(a[key],b[key],path+"/"+str(key),result)
		for key in b:
			if not a.has(key): result.append({"path":path+"/"+str(key),"added_after":str(b[key]).left(180)})
	elif a is Array and b is Array and a.size()==b.size():
		for index in range(a.size()): differences(a[index],b[index],path+"/"+str(index),result)
	else: result.append({"path":path,"before":str(a).left(180),"after":str(b).left(180)})
	return result
func required_width(button: Button, value: String) -> float:
	var width := button.get_theme_font("font").get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,button.get_theme_font_size("font_size")).x
	width += button.get_theme_stylebox("normal").get_minimum_size().x
	if button.icon != null:
		width += 20.0 + button.get_theme_constant("h_separation")
	return width
func menu_contract(button, resources: Dictionary, label: String) -> void:
	var snapshot: Dictionary = button.validation_snapshot()
	check(snapshot.popup_item_count==9,label+": all nine resources")
	for index in range(snapshot.popup_items.size()):
		var row: Dictionary = snapshot.popup_items[index]
		var id: String = OverworldRules.LIVE_STOCKPILE_RESOURCE_KEYS[index]
		check(row.resource_id==id and row.amount==int(resources.get(id,0)),label+": exact ordered value "+id)
		check(row.icon_loaded and row.icon_resource_path==OverworldRules.resource_icon_path(id),label+": exact icon "+id)
		check(row.disabled and row.tooltip=="%s: %d" % [row.display_name,row.amount],label+": read-only tooltip "+id)
func action(name: String) -> void:
	for pressed in [true,false]:
		var event := InputEventAction.new()
		event.action=name
		event.pressed=pressed
		Input.parse_input_event(event)
		await get_tree().process_frame
	await settle()
func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(out.path_join(label+".png"))==OK,"capture "+label)
func component_controls(resources: Dictionary, summary: String) -> void:
	var button = load("res://scenes/shared/ResourceStockpileMenu.gd").new()
	add_child(button)
	button.size=Vector2(80,40)
	button.sync_stockpile(resources,summary,summary)
	await settle()
	check(button.text==summary,"Town/default opt-out keeps existing summary")
	var supported := false
	for property in button.get_property_list():
		if property.name=="fit_summary_to_width": supported=true
	check(supported,"opt-in fit capability exists")
	if not supported:
		button.queue_free();await settle();return
	button.fit_summary_to_width=true
	for font_size in [12,18]:
		button.add_theme_font_size_override("font_size",font_size)
		for width in [80,210,1600]:
			button.size=Vector2(width,50)
			await settle()
			for value in ["Gold 3",summary,"Gold 123456789 | Wood 987654321 | Ore 456789123"]:
				button.sync_stockpile(resources,value,summary)
				await settle()
				var expected: String = value if required_width(button,value)<=button.size.x else "Stores"
				check(button.text==expected,"exact fit choice %d/%d/%s" % [font_size,width,value])
				check(required_width(button,button.text)<=button.size.x,"component text fits actual width")
				check(button.tooltip_text==summary,"full tooltip unchanged by fit")
				menu_contract(button,resources,"component")
	button.size=Vector2(1600,50)
	button.sync_stockpile(resources,"Gold 3",summary)
	button.set_compact_mode(true)
	await settle()
	check(button.text=="Stores","explicit compact mode wins when summary fits")
	button.set_compact_mode(false)
	check(button.text=="Gold 3","leaving compact restores fitting summary")
	button.add_theme_font_size_override("font_size",12)
	button.sync_stockpile(resources,"Gold 888888",summary)
	button.size.x=required_width(button,"Gold 888888")-1.0
	await settle()
	check(button.text=="Stores","resize alone crosses non-fitting boundary")
	button.size.x=required_width(button,"Gold 888888")+1.0
	await settle()
	check(button.text=="Gold 888888","resize alone restores fitting summary")
	button.add_theme_font_size_override("font_size",24)
	await settle()
	check(button.text=="Stores","font change alone re-evaluates fit")
	button.add_theme_font_size_override("font_size",12)
	await settle()
	check(button.text=="Gold 888888","font reset alone restores full summary")
	button.icon=load(OverworldRules.resource_icon_path("gold"))
	button.sync_stockpile(resources,"Gold 888888",summary)
	await settle()
	check(button.text=="Stores","icon and separation consume available width")
	button.size.x=required_width(button,"Gold 888888")+1.0
	await settle()
	check(button.text=="Gold 888888","icon-bearing summary fits after resize")
	button.icon=null
	var changed := resources.duplicate(true)
	changed["memory_salt"]=int(changed.get("memory_salt",0))+12345
	button.sync_stockpile(changed,"Gold 3",summary)
	menu_contract(button,changed,"changed stockpile")
	button.fit_summary_to_width=false
	button.size=Vector2(80,50)
	button.sync_stockpile(resources,summary,summary)
	await settle()
	check(button.text==summary,"opt-out restores legacy presentation")
	button.queue_free()
	await settle()
func run() -> void:
	get_tree().current_scene=null
	out=OS.get_environment("STOCKPILE_FIT_OUTPUT")
	SettingsService.set_presentation_mode("windowed")
	SettingsService.set_presentation_resolution(OS.get_environment("STOCKPILE_FIT_RESOLUTION"))
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("STOCKPILE_FIT_SAVE")))
	# Match the player's load path: register the generated scenario before the
	# UI derives forecasts. A raw SessionState restore lacks that registration.
	check(SaveService.save_session(payload,1)!="","isolated production save copy")
	var session = SaveService.restore_manual_session(1)
	check(session!=null,"production load succeeds")
	if session==null:
		get_tree().quit(1);return
	SessionState.set_active_session(session)
	AppRouter.resume_active_session()
	await settle();await settle()
	var shell = get_tree().current_scene
	check(shell.scene_file_path.ends_with("OverworldShell.tscn"),"actual Overworld")
	var menu = shell._resource_label
	var before: Dictionary = normalized(session.to_dict())
	var original_rect: Rect2 = menu.get_global_rect()
	var original_text: String = menu.text
	check(required_width(menu,menu.text)<=menu.size.x,"real saved Overworld stockpile text is clipped")
	check(menu.tooltip_text==OverworldRules.describe_resources(session),"actual complete resource tooltip")
	menu_contract(menu,session.overworld.resources,"actual")
	await capture("overworld")
	menu.grab_focus()
	await action("ui_accept")
	check(menu.get_popup().visible,"keyboard opens existing Stores menu")
	var popup: PopupMenu = menu.get_popup()
	check(popup.get_theme_color("font_disabled_color").is_equal_approx(Color(0.94,0.9,0.81,1)),"Overworld read-only amounts use opaque legible text")
	check(Rect2(get_viewport().get_visible_rect()).encloses(Rect2(popup.position,popup.size)),"popup stays inside viewport")
	await capture("stores_open")
	await action("ui_cancel")
	check(not popup.visible and menu.has_focus(),"Escape closes and returns keyboard focus")
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=menu.get_global_rect().get_center()
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		Input.parse_input_event(event)
		await get_tree().process_frame
	await settle()
	check(popup.visible,"pointer opens same Stores menu")
	await action("ui_cancel")
	check(not popup.visible,"pointer-opened menu dismisses")
	check(normalized(session.to_dict())==before,"menu input preserves complete gameplay")
	check(menu.get_global_rect()==original_rect,"menu does not widen or move footer")
	observations.append({"text":original_text,"width":menu.size.x,"required_width":required_width(menu,original_text),"summary_width":required_width(menu,menu.full_summary_text()),"viewport":str(get_viewport().get_visible_rect().size)})
	var saved: Dictionary = SaveService.save_runtime_autosave_session(session,false)
	check(bool(saved.get("ok",false)),"real full autosave")
	var restored = SaveService.restore_autosave_session()
	check(restored!=null and normalized(restored.to_dict())==before,"complete save/resume unchanged")
	if restored!=null: observations.append({"save_differences":differences(before,normalized(restored.to_dict()))})
	await component_controls(session.overworld.resources,menu.full_summary_text())
	check(normalized(session.to_dict())==before,"detached component tests preserve live state")
	print("OVERWORLD_STOCKPILE_TEXT_FIT "+JSON.stringify({"ok":errors.is_empty(),"checks":checks,"errors":errors,"observations":observations}))
	get_tree().quit(0 if errors.is_empty() else 1)
'''


def legacy_script():
    source = (ROOT/'tests/resource_stockpile_icon_popover_runtime_report.gd').read_text()
    anchor = '\tget_window().size = viewport_size\n'
    if source.count(anchor)!=1:
        raise ValueError('review legacy viewport setup')
    adapted = source.replace(anchor,anchor+'\tget_window().content_scale_size = viewport_size\n')
    start = adapted.index('\t\tvar town_row: Dictionary = await _run_town_case(viewport_size)')
    end = adapted.index('\t\tvar overworld_row:',start)
    adapted = adapted[:start]+adapted[end:]
    anchor = '\tvar visible_summary_exact: bool = String(menu_before.get("visible_text", "")) == (ResourceStockpileMenu.COMPACT_LABEL if compact_expected else OverworldRules.describe_resources(live_session))'
    if adapted.count(anchor)!=1:
        raise ValueError('review legacy wide-summary expectation')
    replacement = '''\tvar summary_width: float = menu.get_theme_font("font").get_string_size(OverworldRules.describe_resources(live_session), HORIZONTAL_ALIGNMENT_LEFT, -1, menu.get_theme_font_size("font_size")).x + menu.get_theme_stylebox("normal").get_minimum_size().x
\tvar visible_width: float = menu.get_theme_font("font").get_string_size(menu.text, HORIZONTAL_ALIGNMENT_LEFT, -1, menu.get_theme_font_size("font_size")).x + menu.get_theme_stylebox("normal").get_minimum_size().x
\tvar visible_summary_exact: bool = visible_width <= menu.size.x and String(menu_before.get("visible_text", "")) == (ResourceStockpileMenu.COMPACT_LABEL if compact_expected or summary_width > menu.size.x else OverworldRules.describe_resources(live_session))'''
    return adapted.replace(anchor,replacement), hashlib.sha256(source.encode()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--label', required=True)
    parser.add_argument('--save', type=Path, required=True)
    parser.add_argument('--resolution', choices=('1280x720','1920x1080'), required=True)
    parser.add_argument('--legacy-overworld', action='store_true', help='Run both existing authored Overworld cases; preserve all assertions except the obsolete clipped-summary expectation')
    args = parser.parse_args()
    if not re.fullmatch('[a-z0-9_-]+',args.label):
        parser.error('fresh lowercase label required')
    out = OUTPUT/args.label
    out.mkdir(exist_ok=False)
    saved = args.save.read_bytes()
    json.loads(saved)
    script, legacy_sha = legacy_script() if args.legacy_overworld else (SCRIPT, '')
    with tempfile.TemporaryDirectory(prefix='stockpile-fit-',dir=OUTPUT) as scripts, tempfile.TemporaryDirectory(prefix='heroes-stockpile-fit-',dir='/dev/shm') as temporary:
        work = Path(scripts)
        (work/'probe.gd').write_text(script)
        scene = work/'probe.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="StockpileFit" type="Node"]\nscript=ExtResource("1")\n' % (work/'probe.gd').relative_to(ROOT))
        env = dict(os.environ,XDG_DATA_HOME=temporary,STOCKPILE_FIT_OUTPUT=str(out),STOCKPILE_FIT_RESOLUTION=args.resolution,STOCKPILE_FIT_SAVE=str(args.save.resolve()))
        with (out/'runtime.log').open('w') as log:
            code = run_probe(['dbus-run-session','--','xvfb-run','-a','-s','-screen 0 2200x1200x24','godot4','--path',str(ROOT),'--audio-driver','Dummy','--accessibility','disabled','res://'+str(scene.relative_to(ROOT))],env,log)
    lines = (out/'runtime.log').read_text().splitlines()
    marker = 'RESOURCE_STOCKPILE_ICON_POPOVER_RUNTIME_REPORT ' if args.legacy_overworld else 'OVERWORLD_STOCKPILE_TEXT_FIT '
    reports = [json.loads(line[len(marker):]) for line in lines if line.startswith(marker)]
    report = reports[-1] if reports else {'ok':False,'errors':['missing completion marker']}
    report.update(returncode=code,source_save_unchanged=args.save.read_bytes()==saved,save_sha256=hashlib.sha256(saved).hexdigest(),runtime_errors=[line for line in lines if line.startswith(('ERROR:','SCRIPT ERROR:')) or 'leaked' in line])
    report['mode'] = 'legacy_authored_overworld' if args.legacy_overworld else 'real_generated_save'
    if args.legacy_overworld:
        report['legacy_source_sha256'] = legacy_sha
        report['fixture_adaptation'] = 'actual requested logical viewport; Overworld cases only; wide copy must fit measured font width; all nine-resource, icon, tooltip, geometry, input/focus and state assertions preserved; unrelated existing Town geometry failure remains separate'
    report['ok'] = bool(report['ok']) and code==0 and report['source_save_unchanged'] and not report['runtime_errors']
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report),flush=True)
    return 0 if report['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
