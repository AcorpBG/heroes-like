#!/usr/bin/env python3
"""Observe saved-scene sprite edges; success is not visual-correction acceptance.

This diagnostic toggles AtlasTexture.filter_clip only in its isolated process.
Inspect both captures and the exact asset before selecting a production fix.
The original Medium case retains Wreck Quay's baked-in border after the toggle.
"""
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
var rows := []
var session
var view
var out := ""
func _ready() -> void:
	call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		errors.append(label)
func redraw() -> void:
	view._invalidate_session_static_cache("atlas_sampling_probe")
	view._invalidate_state_cache("atlas_sampling_probe")
	view._invalidate_dynamic_layer("atlas_sampling_probe")
	for frame in range(3):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
func capture(label: String) -> void:
	await redraw()
	check(get_viewport().get_texture().get_image().save_png(out.path_join(label+".png"))==OK,"capture "+label)
func run() -> void:
	out = OS.get_environment("ATLAS_PROBE_OUTPUT")
	get_tree().current_scene = null
	SettingsService.set_presentation_mode("windowed")
	SettingsService.set_presentation_resolution(OS.get_environment("ATLAS_PROBE_RESOLUTION"))
	session = SessionState.restore_session(JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("ATLAS_PROBE_SAVE"))))
	AppRouter.resume_active_session()
	for frame in range(8):
		await get_tree().process_frame
	check(get_tree().current_scene.scene_file_path.ends_with("OverworldShell.tscn"),"actual overworld scene")
	view = get_tree().current_scene._map_view
	var before: Dictionary = session.to_dict()
	await capture("gameplay_original")
	var focus := []
	var focus_tile: Vector2i = view._tile_from_local(Vector2(690,210)-view.global_position)
	for y in range(focus_tile.y-1,focus_tile.y+3):
		for x in range(focus_tile.x-1,focus_tile.x+2):
			var presentation: Dictionary = view.validation_tile_presentation(Vector2i(x,y))
			focus.append({"x":x,"y":y,"art":presentation.art_presentation})
	for id in view._object_textures:
		var texture: Texture2D = view._object_textures[id]
		var painted: Dictionary = view._object_texture_visible_region(id,texture)
		var row := {"asset_id":id,"path":view._object_asset_paths[id],"painted_bounds":painted.uses_painted_bounds,"source_rect":str(painted.source_rect),"draw_is_atlas":painted.draw_texture is AtlasTexture}
		if texture is AtlasTexture:
			row.region = str(texture.region)
			row.filter_clip = texture.filter_clip
			texture.filter_clip = true
		rows.append(row)
	await capture("gameplay_clipped")
	check(session.to_dict()==before,"complete world unchanged by sampling")
	check(not rows.is_empty(),"actual manifest object textures observed")
	print("OVERWORLD_ATLAS_SAMPLING "+JSON.stringify({"ok":errors.is_empty(),"checks":checks,"errors":errors,"rows":rows,"focus":focus}))
	get_tree().quit(0 if errors.is_empty() else 1)
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--label', required=True)
    parser.add_argument('--save', type=Path, required=True)
    parser.add_argument('--resolution', choices=['1280x720', '1920x1080'], default='1280x720')
    args = parser.parse_args()
    if not re.fullmatch('[a-z0-9_-]+', args.label):
        parser.error('label must be a fresh lowercase slug')
    out = OUTPUT / args.label
    out.mkdir(parents=True, exist_ok=False)
    saved = args.save.read_bytes()
    json.loads(saved)
    with tempfile.TemporaryDirectory(prefix='atlas-sampling-', dir=OUTPUT) as temporary:
        work = Path(temporary)
        script = work / 'probe.gd'
        script.write_text(SCRIPT)
        scene = work / 'probe.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="AtlasSampling" type="Node"]\nscript = ExtResource("1")\n' % script.relative_to(ROOT))
        env = dict(os.environ, XDG_DATA_HOME=str(out/'data'), ATLAS_PROBE_OUTPUT=str(out), ATLAS_PROBE_SAVE=str(args.save.resolve()), ATLAS_PROBE_RESOLUTION=args.resolution)
        with (out/'runtime.log').open('w') as log:
            code = run_probe(['dbus-run-session','--','xvfb-run','-a','-s','-screen 0 2200x1200x24','godot4','--path',str(ROOT),'--audio-driver','Dummy','--accessibility','disabled','res://'+str(scene.relative_to(ROOT))], env, log)
    lines = (out/'runtime.log').read_text().splitlines()
    marker = 'OVERWORLD_ATLAS_SAMPLING '
    reports = [json.loads(line[len(marker):]) for line in lines if line.startswith(marker)]
    report = reports[-1] if reports else {'ok':False,'errors':['missing report']}
    report.update(classification='diagnostic_only_not_visual_acceptance',returncode=code,save_sha256=hashlib.sha256(saved).hexdigest(),source_unchanged=args.save.read_bytes()==saved,runtime_errors=[line for line in lines if line.startswith(('ERROR:','SCRIPT ERROR:')) or 'leaked' in line])
    report['ok'] = bool(report['ok']) and code==0 and report['source_unchanged'] and not report['runtime_errors']
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({key:value for key,value in report.items() if key not in ('rows', 'focus')}))
    return 0 if report['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
