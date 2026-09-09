#!/usr/bin/env python3
"""Exact earned native-map placements, decoded cutouts and full save preservation.

No fixture mutations: camera movement follows normal saved Overworld/Town entry.
The same Python-owned probe can run in an isolated official platform package.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import tempfile

from generated_town_order_profile import OUTPUT, ROOT, run_probe

CASES = {
    'large_cinder': dict(
        save_sha256='f30453a639d1bae75839292979f05a71b626fb952a20e6eacd0422a9a625545d',
        placement_id='native_h3maped_c2520619_object_2306',
        object_id='object_cinder_ore_face', site_id='site_aetherglass_lens_house',
        asset_id='mapobj_cinder_ore_face', x=40, y=73, day=8, claimed=False,
        body_window=[110, 112, 408, 399],
        block_tiles=[dict(x=x, y=y, level=0) for y in (72, 73) for x in (38, 39, 40)],
    ),
    'medium_moss_unclaimed': dict(
        save_sha256='82da9e8507a069a56b4ee114a38b017780f0a60d474400b2e249f4b19696b57f',
        placement_id='h3maped_small_town_source_support_native_h3maped_93c0f05a_object_0950_required_sources',
        object_id='', site_id='site_generated_town_required_source_cache',
        asset_id='mapobj_moss_oath_cache', x=41, y=41, day=19, claimed=False,
        body_window=[108, 130, 406, 394], block_tiles=[],
    ),
    'medium_moss_claimed': dict(
        save_sha256='a3c565cc299de08f2970be3456b07d97a8fba628c288162f12c5360e7c89d6fe',
        placement_id='h3maped_small_town_source_support_native_h3maped_93c0f05a_object_0950_required_sources',
        object_id='', site_id='site_generated_town_required_source_cache',
        asset_id='mapobj_moss_oath_cache', x=41, y=41, day=46, claimed=True,
        body_window=[108, 130, 406, 394], block_tiles=[],
    ),
}

SCRIPT = r'''
extends Node
var errors := []
var checks := 0
func _ready() -> void:
    call_deferred("run")
func check(value: bool, label: String) -> void:
    checks += 1
    if not value: errors.append(label)
func normalized(value: Dictionary) -> Dictionary:
    return JSON.parse_string(JSON.stringify(value))
func settle() -> void:
    for frame in range(8): await get_tree().process_frame
func run() -> void:
    get_tree().current_scene = null
    var out := OS.get_environment("ART_REPAIR_OUTPUT")
    var spec: Dictionary = JSON.parse_string(OS.get_environment("ART_REPAIR_CASE"))
    SettingsService.set_presentation_mode("windowed")
    SettingsService.set_presentation_resolution(OS.get_environment("ART_REPAIR_RESOLUTION"))
    var session = SessionState.restore_session(JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("ART_REPAIR_SAVE"))))
    AppRouter.resume_active_session()
    await settle()
    var left_town := false
    if get_tree().current_scene.scene_file_path.ends_with("TownShell.tscn"):
        check(get_tree().current_scene.validation_leave_town().get("ok",false), "normal saved Town exit")
        left_town = true
        await settle()
    check(get_tree().current_scene.scene_file_path.ends_with("OverworldShell.tscn"), "actual saved Overworld entered")
    var before: Dictionary = normalized(session.to_dict())
    var placement := {}
    for node in session.overworld.get("resource_nodes", []):
        if String(node.get("placement_id", "")) == spec.placement_id:
            placement = node
            break
    check(not placement.is_empty(), "exact native placement exists")
    check(int(session.day)==int(spec.day), "exact earned day")
    for key in ["object_id", "site_id"]:
        check(placement.get(key, "") == spec[key], "preserved placement " + key)
    for key in ["x", "y"]:
        check(int(placement.get(key,-1)) == int(spec[key]), "preserved native " + key)
    check(int(placement.get("level",-1))==0 and placement.get("kind","")=="mine", "preserved level and adopted kind")
    check(normalized({"tiles":placement.get("package_block_tiles",[])}) == normalized({"tiles":spec.block_tiles}), "exact native movement block mask")
    check(placement.get("runtime_footprint",null)==null, "no injected visual footprint")
    check(bool(placement.get("collected",false))==bool(spec.claimed), "earned collection state")
    check(OverworldRules._resource_node_matches_controller(placement,"player")==bool(spec.claimed), "canonical earned controller state")
    check(OverworldRules.is_tile_visible(session,int(spec.x),int(spec.y),0), "target legitimately explored without fog injection")
    var view = get_tree().current_scene._map_view
    view.focus_on_tile(Vector2i(int(spec.x),int(spec.y)))
    await settle()
    check(view._resource_asset_id(placement)==spec.asset_id, "actual resource resolver chooses exact original asset")
    var tile: Dictionary = view.validation_tile_presentation(Vector2i(int(spec.x),int(spec.y)))
    check(JSON.stringify(tile).contains(spec.asset_id), "exact asset visible at original native tile")
    check(not bool(tile.get("art_presentation",{}).get("fallback_procedural_marker",true)), "no procedural fallback at actual tile")
    var asset_path: String = "res://art/overworld/runtime/objects/map_objects/distinct/"+spec.asset_id+".png"
    check(view._object_asset_paths.get(spec.asset_id,"")==asset_path, "authoritative unique runtime path")
    var texture: Texture2D = view._object_textures.get(spec.asset_id)
    check(texture != null, "actual renderer texture loaded")
    var raster: Image = texture.get_image() if texture != null else Image.new()
    if raster.is_compressed(): check(raster.decompress()==OK,"decoded raster decompression")
    check(raster.get_size()==Vector2i(512,512), "unchanged 512x512 runtime canvas")
    var divider := 0
    var magenta := 0
    var painted := 0
    var bounds: Array = spec.body_window
    for y in range(raster.get_height()):
        for x in range(raster.get_width()):
            var pixel := raster.get_pixel(x,y)
            if pixel.a <= 0: continue
            painted += 1
            if x<bounds[0] or y<bounds[1] or x>=bounds[2] or y>=bounds[3]: divider += 1
            if minf(pixel.r,pixel.b)-pixel.g>8.01/255.0: magenta += 1
    check(divider==0,"decoded texture has no sheet debris")
    check(magenta==0,"decoded texture has no magenta matte")
    check(painted>20000,"complete original painted subject remains")
    check(normalized(session.to_dict())==before,"camera and rendering preserve complete session")
    if DisplayServer.get_name() != "headless":
        await RenderingServer.frame_post_draw
        get_viewport().get_texture().get_image().save_png(out.path_join("gameplay.png"))
    var saved_path: String = SaveService.save_session(session.to_dict(),3)
    check(saved_path!="", "normal complete manual save")
    if saved_path!="":
        var saved_file := FileAccess.open(out.path_join("saved_session.json"),FileAccess.WRITE)
        saved_file.store_buffer(FileAccess.get_file_as_bytes(saved_path))
        saved_file.close()
    session = SessionState.restore_session(SaveService.load_session(3))
    check(normalized(session.to_dict())==before,"complete session preserved through real save/load")
    AppRouter.resume_active_session()
    await settle()
    check(get_tree().current_scene.scene_file_path.ends_with("OverworldShell.tscn"),"saved Overworld route restored")
    check(normalized(session.to_dict())==before,"complete saved state preserved on re-entry")
    check(get_tree().current_scene._map_view._resource_asset_id(placement)==spec.asset_id,"same authoritative asset on saved re-entry")
    print("MAP_OBJECT_CUTOUT_REPAIR "+JSON.stringify({"ok":errors.is_empty(),"errors":errors,"checks":checks,"tile":tile,"placement":placement,"asset_path":asset_path,"divider_pixels":divider,"magenta_pixels":magenta,"painted_pixels":painted,"left_saved_town_normally":left_town,"backend":DisplayServer.get_name()}))
    get_tree().quit(0 if errors.is_empty() else 1)
'''


def probe_environment(environment):
    """Package adapter changes only host paths, never the probe or fixture."""
    return environment


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--case', choices=CASES, required=True)
    parser.add_argument('--save', type=Path, required=True)
    parser.add_argument('--label', required=True)
    parser.add_argument('--resolution', choices=('1280x720','1920x1080'), default='1280x720')
    args = parser.parse_args()
    if not re.fullmatch(r'[a-z0-9_-]+', args.label):
        parser.error('label must be a fresh lowercase slug')
    original = args.save.read_bytes()
    if hashlib.sha256(original).hexdigest() != CASES[args.case]['save_sha256']:
        parser.error('case requires its exact original earned save')
    output = OUTPUT / args.label
    output.mkdir(parents=True, exist_ok=False)
    with tempfile.TemporaryDirectory(prefix='map-cutout-probe-',dir=OUTPUT) as temp, tempfile.TemporaryDirectory(prefix='map-cutout-userdata-',dir='/dev/shm') as userdata:
        directory = Path(temp)
        script = directory/'probe.gd'
        script.write_text(SCRIPT)
        scene = directory/'probe.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="MapCutoutProbe" type="Node"]\nscript = ExtResource("1")\n' % script.relative_to(ROOT))
        env = dict(os.environ, XDG_DATA_HOME=userdata, ART_REPAIR_OUTPUT=str(output),
                   ART_REPAIR_SAVE=str(args.save.resolve()), ART_REPAIR_RESOLUTION=args.resolution,
                   ART_REPAIR_CASE=json.dumps(CASES[args.case]))
        with (output/'runtime.log').open('w') as log:
            code = run_probe(['dbus-run-session','--','xvfb-run','-a','-s','-screen 0 2200x1200x24','godot4','--path',str(ROOT),'--audio-driver','Dummy','--accessibility','disabled','res://'+str(scene.relative_to(ROOT))],probe_environment(env),log)
    lines = (output/'runtime.log').read_text().splitlines()
    marker = 'MAP_OBJECT_CUTOUT_REPAIR '
    reports = [json.loads(line[len(marker):]) for line in lines if line.startswith(marker)]
    report = reports[-1] if reports else dict(ok=False,errors=['missing report'])
    report.update(returncode=code, case=args.case, resolution=args.resolution,
                  save_sha256=hashlib.sha256(original).hexdigest(), input_unchanged=args.save.read_bytes()==original,
                  runtime_errors=[line for line in lines if line.startswith(('ERROR:','SCRIPT ERROR:')) or 'leaked' in line])
    capture_ok = report.get('backend')=='headless' or (output/'gameplay.png').is_file()
    report['ok'] = bool(report['ok']) and code==0 and report['input_unchanged'] and not report['runtime_errors'] and capture_ok
    (output/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({key:value for key,value in report.items() if key not in ('tile','placement')}))
    return 0 if report['ok'] else 1


if __name__=='__main__':
    raise SystemExit(main())
