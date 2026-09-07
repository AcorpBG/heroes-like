#!/usr/bin/env python3
"""Real Bellwake scene assets, cover-crop input and normal construction/save."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import tempfile

from generated_full_match_quality import ROOT, OUTPUT
from generated_town_order_profile import run_probe
import town_overlay_ownership_regression as overlay

EXTRA = r'''
func layer_action(name: String) -> void:
	for pressed in [true,false]:
		var event := InputEventAction.new()
		event.action=name;event.pressed=pressed
		Input.parse_input_event(event)
		await get_tree().process_frame
	await settle()
func layer_click(point: Vector2) -> void:
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=get_viewport().get_final_transform()*point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
		Input.parse_input_event(event)
		await get_tree().process_frame
	await settle()
func layer_controller(button_index: int) -> void:
	for pressed in [true,false]:
		var event := InputEventJoypadButton.new()
		event.button_index=button_index;event.pressed=pressed
		Input.parse_input_event(event)
		await get_tree().process_frame
	await settle()
func inspect_scene_layers() -> void:
	var shell = get_tree().current_scene
	var stage = shell.get_node("%TownStage")
	var before: Dictionary = normalized(session.to_dict())
	var rows: Array = stage.validation_town_building_progression_summary().texture_rows
	for id in ["building_veilmourn_bell_harbor", "building_wayfarers_hall"]:
		var matches: Array = rows.filter(func(row): return row.building_id == id)
		var expected := "res://art/towns/runtime/scene_layers/faction_veilmourn/%s.png" % id
		check(matches.size()==1 and matches[0].texture_path==expected,"scenery still resolves catalog icon rather than exact Veilmourn layer: "+id)
		var summary: Dictionary = stage.validation_building_hotspot_summary(id)
		check(summary.aligned and summary.visible and summary.focus_mode==Control.FOCUS_ALL,"scene layer focus/crop alignment: "+id)
		check(summary.accessibility_name.contains(ContentService.get_building(id).name),"missing exact building accessible name: "+id)
		var button = stage._building_hotspots[id]
		var texture: Texture2D = stage._town_building_texture(id)
		var raster := texture.get_image()
		var entry: Dictionary = stage._town_building_scene_entries(stage._town_scene_rect()).filter(func(e):return e.visible_building_id==id)[0]
		var ratio: Rect2 = entry.texture_region_ratio
		check(absf((entry.normalized_rect.size.x*1600.0)/(entry.normalized_rect.size.y*900.0)-texture.get_width()/float(texture.get_height()))<0.005,"non-square layer aspect changed: "+id)
		var opaque := Vector2(-1,-1)
		var transparent := Vector2(-1,-1)
		for y in range(1,20):
			for x in range(1,20):
				# Sample source pixel centers, not exact pixel boundaries whose
				# float32 screen round-trip may legitimately choose either neighbor.
				var pixel := Vector2i(Vector2(x/20.0,y/20.0)*Vector2(raster.get_size()))
				var uv := ((Vector2(pixel)+Vector2(0.5,0.5))/Vector2(raster.get_size())-ratio.position)/ratio.size
				if not Rect2(Vector2.ZERO,Vector2.ONE).has_point(uv): continue
				var painted: bool = raster.get_pixelv(pixel).a>0.25
				var point: Vector2 = uv*button.size
				check(button._has_point(point)==painted,"painted-alpha/cover-crop pointer ownership: "+id)
				if painted and opaque.x<0: opaque=point
				if not painted and transparent.x<0: transparent=point
		check(opaque.x>=0 and transparent.x>=0,"layer must have both solid and transparent pixels: "+id)
		var presses := [0]
		var observe := func(): presses[0]+=1
		button.pressed.connect(observe)
		await layer_click(button.get_global_transform_with_canvas()*transparent)
		check(presses[0]==0,"transparent image margin intercepted click: "+id)
		if shell._town_catalog_is_open(): shell._close_town_catalog(false)
		# Use an opaque body point outside the main-building overlap for actual pointer input.
		var body := Vector2(0.62,0.36) if id=="building_veilmourn_bell_harbor" else Vector2(0.55,0.60)
		check(button._has_point(body*button.size),"authored pointer test point is not painted: "+id)
		await layer_click(button.get_global_transform_with_canvas()*(body*button.size))
		var info: Dictionary = shell.validation_building_information_snapshot(id)
		check(presses[0]==1 and info.open and info.mode=="building_info" and info.title==info.expected_title,"painted pointer did not open exact building info: "+id)
		check(shell._building_info_icon.texture!=null and shell._building_info_icon.texture.resource_path==TownRules.building_icon_path(id),"scene layer replaced separate catalog/info icon: "+id)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join(id+"_info.png"))
		await layer_action("ui_cancel")
		check(not shell._town_catalog_is_open(),"Escape did not dismiss info: "+id)
		button.grab_focus()
		await layer_action("ui_accept")
		check(shell.validation_building_information_snapshot(id).title==ContentService.get_building(id).name and shell._town_catalog_is_open(),"keyboard did not open exact info: "+id)
		await layer_action("ui_cancel")
		button.grab_focus()
		await layer_controller(JOY_BUTTON_A)
		check(shell.validation_building_information_snapshot(id).title==ContentService.get_building(id).name and shell._town_catalog_is_open(),"controller A did not open exact info: "+id)
		await layer_controller(JOY_BUTTON_B)
		check(not shell._town_catalog_is_open(),"controller B did not dismiss info: "+id)
		button.pressed.disconnect(observe)
	# The main building still owns the authoritative construction route.
	var build: Dictionary = shell.validation_activate_main_building_hotspot()
	check(build.same_authoritative_build_route,"main building no longer opens the construction ledger")
	shell._close_town_catalog(false)
	# Detached view-only cache/negative mapping boundaries, never authored content mutation.
	var template: Dictionary = stage._town_template
	stage._town_template=template.duplicate(true)
	stage._town_template.faction_id="faction_embercourt"
	check(stage._town_building_texture("building_wayfarers_hall").resource_path==TownRules.building_icon_path("building_wayfarers_hall"),"scenic texture leaked across faction cache keys")
	stage._town_template=template
	var manifest: Dictionary = stage._building_scene_art_manifest
	stage._building_scene_art_manifest=manifest.duplicate(true)
	stage._building_scene_art_manifest.factions.faction_veilmourn.building_wayfarers_hall.runtime_path="res://missing-declared-town-layer.png"
	check(stage._town_building_texture("building_wayfarers_hall")==null,"missing declared art fell back to catalog")
	stage._building_scene_art_manifest.factions.faction_veilmourn.building_wayfarers_hall={}
	check(stage._town_building_texture("building_wayfarers_hall")==null,"malformed declared art fell back to catalog")
	stage._building_scene_art_manifest=manifest
	check(stage._town_building_texture("building_wayfarers_hall").resource_path.contains("scene_layers/faction_veilmourn"),"negative asset cache poisoned restored exact mapping")
	check(normalized(session.to_dict())==before,"scene asset inspection mutated gameplay")
func layer_visibility_fixture() -> void:
	# These two structures are authored starting buildings, not purchasable orders.
	# Detached built-id visibility boundary only; normal paid construction is tested above.
	var fixture = SessionState.restore_session(normalized(session.to_dict()))
	var town: Dictionary = TownRules.get_active_town(fixture)
	town.built_buildings.erase("building_wayfarers_hall")
	town.last_build_day=0
	AppRouter.go_to_town()
	await settle()
	var shell = get_tree().current_scene
	var stage = shell.get_node("%TownStage")
	check(not stage.validation_building_hotspot_summary("building_wayfarers_hall").visible,"unbuilt scenic building is still visible/clickable")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("fixture_hall_unbuilt.png"))
	var offers: Array = TownRules.get_build_actions(fixture).filter(func(a):return a.id=="build:building_wayfarers_hall" and not a.get("disabled",true))
	check(offers.is_empty(),"starting-building art migration changed the authored construction catalog")
	town.built_buildings.append("building_wayfarers_hall")
	AppRouter.go_to_town()
	await settle()
	shell=get_tree().current_scene
	stage=shell.get_node("%TownStage")
	check(stage.validation_building_hotspot_summary("building_wayfarers_hall").visible,"restored built-id scenic layer/hotspot absent")
	var info: Dictionary = shell.validation_activate_building_information("building_wayfarers_hall")
	check(info.open and info.title=="Wayfarers Hall","restored built-id does not route exact info")
	shell._close_town_catalog(false)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("fixture_hall_built.png"))
	var path: String = SaveService.save_session(fixture.to_dict(),3)
	var restored = SessionState.restore_session(SaveService.load_session(3))
	check(path!="" and normalized(restored.to_dict())==normalized(fixture.to_dict()),"scene-layer built ids changed complete save/resume")
	rows.append({"label":"detached_starting_building_visibility_not_construction","built_ids":TownRules.get_active_town(fixture).built_buildings,"save_unchanged":normalized(restored.to_dict())==normalized(fixture.to_dict())})
'''

SCRIPT = overlay.SCRIPT.replace('await inspect("opening")', 'await inspect("opening")\n\tawait inspect_scene_layers()') + EXTRA
SCRIPT = SCRIPT.replace('print("TOWN_OVERLAY_OWNERSHIP "', 'await layer_visibility_fixture()\n\tprint("TOWN_OVERLAY_OWNERSHIP "')
SCRIPT = SCRIPT.replace('get_tree().current_scene._commit_build_action(building_id)', 'var paid_before: Dictionary = normalized(session.overworld.resources)\n\t\tvar cost: Dictionary = offered[0].cost\n\t\tget_tree().current_scene._commit_build_action(building_id)')
SCRIPT = SCRIPT.replace('await inspect("after_build")', 'for resource in cost:\n\t\t\tcheck(int(session.overworld.resources[resource])==int(paid_before[resource])-int(cost[resource]),"ordinary construction resource cost changed: "+resource)\n\t\tawait inspect("after_build")')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--label', required=True)
    parser.add_argument('--save', type=Path, required=True)
    parser.add_argument('--resolution', choices=['1280x720', '1920x1080', '2048x1079'], required=True)
    args = parser.parse_args()
    if not args.label or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789_-' for c in args.label):
        parser.error('fresh lowercase label required')
    save = args.save.resolve(strict=True)
    before_hash = hashlib.sha256(save.read_bytes()).hexdigest()
    owners = ('scenes/town/TownStageView.gd','scenes/town/TownBuildingHotspot.gd',
              'content/town_building_scene_art_manifest.json','tests/town_scene_layer_regression.py')
    source_hashes = {path:hashlib.sha256((ROOT/path).read_bytes()).hexdigest() for path in owners}
    out = OUTPUT / args.label
    out.mkdir(exist_ok=False)
    script_text = SCRIPT
    if args.resolution == '2048x1079':
        script_text = SCRIPT.replace('SettingsService.set_presentation_resolution(OS.get_environment("TOWN_OVERLAY_RESOLUTION"))', 'get_window().content_scale_size = Vector2i(2048,1079)\n\tget_window().size = Vector2i(2048,1079)')
    with tempfile.TemporaryDirectory(prefix='town-layer-probe-', dir=OUTPUT) as temporary, tempfile.TemporaryDirectory(prefix='town-layer-data-', dir='/dev/shm') as data:
        work = Path(temporary)
        script = work / 'probe.gd'
        script.write_text(script_text)
        scene = work / 'probe.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="TownLayer" type="Node"]\nscript = ExtResource("1")\n' % script.relative_to(ROOT))
        command = ['dbus-run-session','--','xvfb-run','-a','-s','-screen 0 2200x1200x24','godot4','--path',str(ROOT),'--audio-driver','Dummy','--accessibility','disabled','--resolution',args.resolution,'res://'+str(scene.relative_to(ROOT))]
        env = dict(os.environ, XDG_DATA_HOME=data, TOWN_OVERLAY_OUTPUT=str(out), TOWN_OVERLAY_SAVE=str(save), TOWN_OVERLAY_RESOLUTION=args.resolution)
        with (out / 'runtime.log').open('w') as log:
            code = run_probe(command, env, log)
    lines = (out / 'runtime.log').read_text().splitlines()
    marker = 'TOWN_OVERLAY_OWNERSHIP '
    reports = [json.loads(line[len(marker):]) for line in lines if line.startswith(marker)]
    report = reports[-1] if reports else {'ok':False,'errors':['missing report']}
    report.update(returncode=code, save_sha256=before_hash, input_unchanged=hashlib.sha256(save.read_bytes()).hexdigest()==before_hash, resolution=args.resolution,
                  runtime_errors=[s for s in lines if s.startswith(('ERROR:', 'SCRIPT ERROR:')) or 'leaked' in s])
    report['source_hashes'] = source_hashes
    report['executed_probe_sha256'] = hashlib.sha256(script_text.encode()).hexdigest()
    report['source_unchanged'] = all(hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==sha for path,sha in source_hashes.items())
    report['ok'] = bool(report['ok']) and code==0 and not report['runtime_errors'] and report['input_unchanged'] and report['source_unchanged']
    (out / 'report.json').write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k != 'rows'}))
    return 0 if report['ok'] else 1

if __name__ == '__main__':
    raise SystemExit(main())
