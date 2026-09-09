#!/usr/bin/env python3
"""Exact cohort texture/resolver checks plus unchanged earned native-map views.

Resolver dictionaries below are labeled coverage inputs, never inserted into
the world. Screenshots use only already-explored, original saved placements.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

from PIL import Image
from generated_town_order_profile import ROOT, run_probe

OUTPUT = ROOT/'.artifacts/overworld_cutout_quality_20260909'
SAVE = ROOT/'.artifacts/generated_full_match_quality_20260906/medium_match_11_continuation_01/data/godot/app_userdata/heroes-like/saves/autosave.json'
SAVE_SHA = '1734cf2274e00eb763b94db4f814f4ffc73e30bb9377a9225b36bcc3780e0fcc'
RECIPE = ROOT/'art/overworld/source/generated/cutout_recovery_20260909/batch04/recipe.json'
MARKER = 'OVERWORLD_CUTOUT_BATCH '

IMPORT_ORACLE = r'''
extends SceneTree
func _initialize() -> void:
    var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("CUTOUT_ORACLE_CONFIG")))
    var result := {}
    for asset_id in config.assets:
        var raster := Image.load_from_file(config.assets[asset_id].source)
        raster.convert(Image.FORMAT_RGBA8)
        raster.fix_alpha_edges()
        var hash := HashingContext.new()
        hash.start(HashingContext.HASH_SHA256)
        hash.update(raster.get_data())
        result[asset_id]=hash.finish().hex_encode()
    var file := FileAccess.open(config.output,FileAccess.WRITE)
    file.store_string(JSON.stringify(result))
    file.close()
    quit()
'''


def expected_assets(recipe, expected_dir, output):
    """Independent source-PNG oracle for the unchanged Godot import settings.

    No ResourceLoader, runtime cache or PCK is read. The oracle only applies
    Godot's existing source-image alpha-edge operation to the verified PNGs.
    Gameplay/package runs receive hashes, never loose texture overrides.
    """
    assets={}
    for key,row in recipe['assets'].items():
        entry=row['original_manifest_entry']
        path=expected_dir/(key+'.png') if expected_dir else ROOT/entry['path'].removeprefix('res://')
        options=Path(str(ROOT/entry['path'].removeprefix('res://'))+'.import')
        text=options.read_text()
        for required in ['compress/mode=0','mipmaps/generate=false','process/fix_alpha_border=true','process/premult_alpha=false','process/size_limit=0']:
            if required not in text.splitlines():raise ValueError('Revalidate changed import processing: '+key+'/'+required)
        with Image.open(path) as im:
            if im.mode!='RGBA' or im.size!=(512,512):raise ValueError('Expected original logical RGBA canvas: '+key)
        assets[key]=dict(object_id=entry['assigned_map_object_id'],path=entry['path'],source=str(path.resolve()),
                         source_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),import_options_sha256=hashlib.sha256(options.read_bytes()).hexdigest())
    with tempfile.TemporaryDirectory(prefix='cutout-source-oracle-',dir=OUTPUT) as temporary:
        work=Path(temporary)
        (work/'project.godot').write_text('config_version=5\n')
        (work/'oracle.gd').write_text(IMPORT_ORACLE)
        config=work/'config.json'
        result=work/'result.json'
        config.write_text(json.dumps(dict(assets=assets,output=str(result))))
        with (output/'source-oracle.log').open('w') as log:
            run=subprocess.run(['godot4','--headless','--path',str(work),'--script',str(work/'oracle.gd')],
                env=dict(os.environ,CUTOUT_ORACLE_CONFIG=str(config)),stdout=log,stderr=subprocess.STDOUT,timeout=60)
        errors=[s for s in (output/'source-oracle.log').read_text().splitlines() if s.startswith(('ERROR:','SCRIPT ERROR:')) or 'leaked' in s]
        if run.returncode or errors:raise ValueError('Independent source-image oracle failed: '+str(errors))
        hashes=json.loads(result.read_text())
    if set(hashes)!=set(assets):raise ValueError('Incomplete source-image oracle')
    for key,sha in hashes.items():assets[key]['rgba_sha256']=sha
    (output/'source-oracle.json').write_text(json.dumps(dict(algorithm='Godot Image.fix_alpha_edges for unchanged lossless import options',
        oracle_script_sha256=hashlib.sha256(IMPORT_ORACLE.encode()).hexdigest(),assets=assets),indent=2)+'\n')
    return {key:{field:value for field,value in row.items() if field!='source'} for key,row in assets.items()}

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
func digest(data: PackedByteArray) -> String:
    var hash := HashingContext.new()
    hash.start(HashingContext.HASH_SHA256)
    hash.update(data)
    return hash.finish().hex_encode()
func settle() -> void:
    for frame in range(8): await get_tree().process_frame
func run() -> void:
    get_tree().current_scene = null
    var out := OS.get_environment("CUTOUT_OUTPUT")
    var specs: Dictionary = JSON.parse_string(OS.get_environment("CUTOUT_ASSETS"))
    SettingsService.set_presentation_mode("windowed")
    SettingsService.set_presentation_resolution(OS.get_environment("CUTOUT_RESOLUTION"))
    var session = SessionState.restore_session(JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("CUTOUT_SAVE"))))
    AppRouter.resume_active_session()
    await settle()
    if get_tree().current_scene.scene_file_path.ends_with("TownShell.tscn"):
        check(get_tree().current_scene.validation_leave_town().get("ok",false),"normal saved Town exit")
        await settle()
    check(get_tree().current_scene.scene_file_path.ends_with("OverworldShell.tscn"),"actual saved Overworld entry")
    check(int(session.day)==97,"exact earned Medium Day97 pre-outcome checkpoint")
    var before: Dictionary = normalized(session.to_dict())
    var view = get_tree().current_scene._map_view
    var textures := {}
    for asset_id in specs:
        var spec: Dictionary = specs[asset_id]
        # Resolver coverage only; never mutate a world placement or fog state.
        var authored := {"object_id":spec.object_id}
        check(view._standalone_map_object_asset_id(authored)==asset_id,asset_id+" authored object resolver")
        check(view._resource_asset_id(authored)==asset_id,asset_id+" native/adopted object resolver")
        check(view._object_asset_paths.get(asset_id,"")==spec.path,asset_id+" exact manifest path")
        var texture = view._object_texture_for_asset(asset_id)
        check(texture is Texture2D,asset_id+" real texture, no fallback")
        if not texture is Texture2D: continue
        var raster: Image = texture.get_image()
        if raster.is_compressed(): check(raster.decompress()==OK,asset_id+" decompress")
        raster.convert(Image.FORMAT_RGBA8)
        var sha := digest(raster.get_data())
        check(raster.get_size()==Vector2i(512,512),asset_id+" unchanged logical canvas")
        check(sha==spec.rgba_sha256,asset_id+" exact decoded RGBA matches independent source-image oracle")
        var draw: Dictionary = view._object_painted_sprite_draw_payload(asset_id,texture,Vector2(400,300),96.0)
        check(bool(draw.get("uses_painted_bounds",false)),asset_id+" real painted bounds")
        textures[asset_id] = {"rgba_sha256":sha,"bounds":raster.get_used_rect(),"draw":draw.get("canvas_draw_rect")}
    var captures := []
    var seen := {}
    for node in session.overworld.get("resource_nodes",[]):
        if node.get("kind","") not in ["mine","resource_site"]:continue
        var asset_id: String = view._resource_asset_id(node)
        if not specs.has(asset_id) or seen.has(asset_id):continue
        var x := int(node.x)
        var y := int(node.y)
        if not OverworldRules.is_tile_visible(session,x,y,int(node.get("level",0))):continue
        seen[asset_id]=true
        var exact_placement: Dictionary = normalized(node)
        check(int(node.get("level",0))==0,"original surface placement")
        view.focus_on_tile(Vector2i(x,y))
        await settle()
        var tile: Dictionary = view.validation_tile_presentation(Vector2i(x,y))
        check(JSON.stringify(tile).contains(asset_id),asset_id+" visible at original native coordinates")
        check(not bool(tile.get("art_presentation",{}).get("fallback_procedural_marker",true)),asset_id+" no normal-play procedural fallback")
        check(normalized(node)==exact_placement,asset_id+" full native record including footprint/masks unchanged")
        if DisplayServer.get_name()!="headless":
            await RenderingServer.frame_post_draw
            get_viewport().get_texture().get_image().save_png(out.path_join(asset_id+".png"))
        captures.append({"asset_id":asset_id,"placement":exact_placement,"tile":tile})
    check(captures.size()>=1,"earned explored affected native placement captured without fog injection")
    check(normalized(session.to_dict())==before,"all resolver/render/camera work preserves complete session")
    var save_path: String = SaveService.save_session(session.to_dict(),3)
    check(save_path!="","real complete manual save")
    if save_path!="":
        var file := FileAccess.open(out.path_join("saved_session.json"),FileAccess.WRITE)
        file.store_buffer(FileAccess.get_file_as_bytes(save_path))
        file.close()
    session=SessionState.restore_session(SaveService.load_session(3))
    check(normalized(session.to_dict())==before,"complete state survives actual save/load")
    AppRouter.resume_active_session()
    await settle()
    check(normalized(session.to_dict())==before,"normal saved re-entry preserves complete state")
    print("OVERWORLD_CUTOUT_BATCH "+JSON.stringify({"ok":errors.is_empty(),"errors":errors,"checks":checks,"textures":textures,"captures":captures,"backend":DisplayServer.get_name()}))
    get_tree().quit(0 if errors.is_empty() else 1)
'''


def probe_environment(environment):
    return environment


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--batch',choices=['batch04'],default='batch04')
    parser.add_argument('--label',required=True)
    parser.add_argument('--resolution',choices=['1280x720','1920x1080'],default='1280x720')
    parser.add_argument('--expected-dir',type=Path,help='Preview acceptance candidate; permits an honest failing-before run')
    args=parser.parse_args()
    if not re.fullmatch(r'[a-z0-9_-]+',args.label):parser.error('label must be a fresh slug')
    original=SAVE.read_bytes()
    if hashlib.sha256(original).hexdigest()!=SAVE_SHA:parser.error('unchanged exact earned save required')
    recipe=json.loads(RECIPE.read_text())
    output=OUTPUT/args.label
    output.mkdir(parents=True,exist_ok=False)
    assets=expected_assets(recipe,args.expected_dir,output)
    with tempfile.TemporaryDirectory(prefix='cutout-probe-',dir=OUTPUT) as temp, tempfile.TemporaryDirectory(prefix='cutout-userdata-',dir='/dev/shm') as userdata:
        directory=Path(temp)
        (directory/'probe.gd').write_text(SCRIPT)
        scene=directory/'probe.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="CutoutBatchProbe" type="Node"]\nscript = ExtResource("1")\n' % (directory/'probe.gd').relative_to(ROOT))
        env=dict(os.environ,XDG_DATA_HOME=userdata,CUTOUT_OUTPUT=str(output),CUTOUT_SAVE=str(SAVE),CUTOUT_RESOLUTION=args.resolution,CUTOUT_ASSETS=json.dumps(assets))
        with (output/'runtime.log').open('w') as log:
            code=run_probe(['dbus-run-session','--','xvfb-run','-a','-s','-screen 0 2200x1200x24','godot4','--path',str(ROOT),'--audio-driver','Dummy','--accessibility','disabled','res://'+str(scene.relative_to(ROOT))],probe_environment(env),log)
    lines=(output/'runtime.log').read_text().splitlines()
    found=[json.loads(s[len(MARKER):]) for s in lines if s.startswith(MARKER)]
    report=found[-1] if found else dict(ok=False,errors=['missing Godot report'])
    report.update(returncode=code,save_sha256=SAVE_SHA,input_unchanged=SAVE.read_bytes()==original,resolution=args.resolution,
                  expected_rasters=assets,runtime_errors=[s for s in lines if s.startswith(('ERROR:','SCRIPT ERROR:')) or 'leaked' in s])
    captures_ok=report.get('backend')=='headless' or all((output/(r['asset_id']+'.png')).exists() for r in report.get('captures',[]))
    report['ok']=bool(report['ok']) and code==0 and report['input_unchanged'] and not report['runtime_errors'] and captures_ok
    (output/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k not in ('textures','captures','expected_rasters')}))
    return 0 if report['ok'] else 1


if __name__=='__main__':raise SystemExit(main())
