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
# Owner-approved 2026-09-10: exact verified manual round-trip of the deleted
# Day97 control, not a newly generated/injected map. See adjacent provenance.
SAVE = ROOT/'tests/fixtures/overworld_cutout/native_day97_roundtrip.json'
SAVE_SHA = 'd4b6cac54c25fc42456bdb7fdd3d4a9d0ed37fda8115dd63afe29d05b18bb1c1'
RECIPE = ROOT/'art/overworld/source/generated/cutout_recovery_20260909/batch04/recipe.json'
POOL_RECIPE = ROOT/'art/overworld/source/generated/cutout_recovery_20260909/map_sheets/recipe.json'
DECORATION_RECIPE = ROOT/'art/overworld/source/generated/cutout_recovery_20260909/decorations/recipe.json'
LEGACY_RECIPE = ROOT/'art/overworld/source/generated/cutout_recovery_20260909/legacy_families/recipe.json'
PASSAGE_RECIPE = ROOT/'art/overworld/source/generated/cutout_recovery_20260909/passages/recipe.json'
RECURRING_RECIPE = ROOT/'art/overworld/source/generated/cutout_recovery_20260909/recurring_encounters/recipe.json'
RECURRING_SITE_RECIPE = ROOT/'art/overworld/source/generated/cutout_recovery_20260909/recurring_sites/recipe.json'
CLAIMED_RECIPE = ROOT/'art/overworld/source/generated/cutout_recovery_20260909/claimed_dwellings/recipe.json'
EARLY_STATE_RECIPE = ROOT/'art/overworld/source/generated/cutout_recovery_20260909/early_states/recipe.json'
LANDMARK_STATE_RECIPE = ROOT/'art/overworld/source/generated/cutout_recovery_20260909/landmark_states/recipe.json'
ROUTE_ARCANE_RECIPE = ROOT/'art/overworld/source/generated/cutout_recovery_20260909/route_arcane/recipe.json'
COMMAND_SITE_RECIPE = ROOT/'art/overworld/source/generated/cutout_recovery_20260909/command_sites/recipe.json'
REMAINING_SITE_RECIPE = ROOT/'art/overworld/source/generated/cutout_recovery_20260909/remaining_sites/recipe.json'
ARTIFACT_RECIPE = ROOT/'art/overworld/source/generated/cutout_recovery_20260909/artifacts/recipe.json'
REMAINING_ENCOUNTER_RECIPE = ROOT/'art/overworld/source/generated/cutout_recovery_20260909/remaining_encounters/recipe.json'
CONTRACT_RECIPE = ROOT/'art/overworld/source/generated/cutout_recovery_20260909/contract_encounters/recipe.json'
TRAINING_RECIPE = ROOT/'art/overworld/source/generated/cutout_recovery_20260909/training_sites/recipe.json'
RECRUITMENT_RECIPE = ROOT/'art/overworld/source/generated/cutout_recovery_20260909/recruitment_sites/recipe.json'
TOWN_RECIPE = ROOT/'art/overworld/source/generated/cutout_recovery_20260909/towns/recipe.json'
HERO_RECIPE = ROOT/'art/overworld/source/generated/cutout_recovery_20260909/heroes/recipe.json'
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
        if config.assets[asset_id].has("atlas_region"):
            var r: Array = config.assets[asset_id].atlas_region
            raster=raster.get_region(Rect2i(int(r[0]),int(r[1]),int(r[2]),int(r[3])))
        var hash := HashingContext.new()
        hash.start(HashingContext.HASH_SHA256)
        hash.update(raster.get_data())
        result[asset_id]=hash.finish().hex_encode()
    var file := FileAccess.open(config.output,FileAccess.WRITE)
    file.store_string(JSON.stringify(result))
    file.close()
    quit()
'''


def earned_save_bytes():
    original = SAVE.read_bytes()
    if hashlib.sha256(original).hexdigest() != SAVE_SHA:
        raise ValueError('unchanged exact earned save required')
    return original


def expected_assets(recipe, expected_dir, output):
    """Independent source-PNG oracle for the unchanged Godot import settings.

    No ResourceLoader, runtime cache or PCK is read. The oracle only applies
    Godot's existing source-image alpha-edge operation to the verified PNGs.
    Gameplay/package runs receive hashes, never loose texture overrides.
    """
    assets={}
    for key,row in recipe['assets'].items():
        entry=row['original_manifest_entry']
        recurring_site=recipe.get('schema_id')=='recurring_site_cutout_recipe_v1'
        route_arcane=recipe.get('schema_id') in ('route_arcane_cutout_recipe_v1','recruitment_site_cutout_recipe_v1')
        claimed=route_arcane or recipe.get('schema_id') in ('claimed_dwelling_cutout_recipe_v1','early_state_cutout_recipe_v1','landmark_state_cutout_recipe_v1','command_site_cutout_recipe_v1','training_site_cutout_recipe_v1','remaining_site_cutout_recipe_v1')
        recurring=recurring_site or recipe.get('schema_id')=='recurring_cutout_recipe_v3'
        if recurring:
            entry=dict(entry,path=row['runtime_path'],atlas_region=[v*row['pixel_scale'] for v in entry['atlas_region']],atlas_size=[5760 if recurring_site else 5952,192])
        contract=recipe.get('schema_id')=='contract_encounter_cutout_recipe_v1'
        remaining=recipe.get('schema_id') in ('remaining_encounter_cutout_recipe_v1','artifact_cutout_recipe_v1','hero_cutout_recipe_v1','town_cutout_recipe_v1')
        if (claimed or contract or remaining) and 'atlas_region' in entry:
            entry=dict(entry,atlas_region=[v*4 for v in entry['atlas_region']],atlas_size=[v*4 for v in entry['atlas_size']])
        legacy=remaining or contract or claimed or recurring or recipe.get('schema_id') in ('legacy_family_cutout_recipe_v1','passage_cutout_recipe_v1')
        # Atlas alpha-edge processing runs on the complete original atlas;
        # cropping before import would not be an independent runtime oracle.
        path=(expected_dir/'runtime'/Path(entry['path'].removeprefix('res://art/overworld/runtime/')) if legacy else expected_dir/(key+'.png')) if expected_dir else ROOT/entry['path'].removeprefix('res://')
        options=Path(str(ROOT/entry['path'].removeprefix('res://'))+'.import')
        text=options.read_text()
        for required in ['compress/mode=0','mipmaps/generate=false','process/fix_alpha_border=true','process/premult_alpha=false','process/size_limit=0']:
            if required not in text.splitlines():raise ValueError('Revalidate changed import processing: '+key+'/'+required)
        with Image.open(path) as im:
            logical_size=tuple(entry['atlas_region'][2:]) if 'atlas_region' in entry else im.size
            if im.mode!='RGBA' or logical_size!=tuple(row.get('canvas_size',[512,512])):raise ValueError('Expected original logical RGBA canvas: '+key)
        object_id=entry.get('assigned_map_object_id',entry.get('assigned_decorative_object_id',''))
        if not object_id and not legacy:raise ValueError('Missing exact authored identity: '+key)
        assets[key]=dict(object_id=object_id,path=entry['path'],source=str(path.resolve()),
                         source_group=row.get('source','batch04'),
                         source_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),import_options_sha256=hashlib.sha256(options.read_bytes()).hexdigest())
        if legacy:
            assets[key].update(mode='claimed_dwelling' if claimed else row['mode'],size=row['canvas_size'],entry=entry)
            if 'atlas_region' in entry:assets[key]['atlas_region']=entry['atlas_region']
        if recurring_site or claimed:
            site_id=row['site_id'] if route_arcane else entry['assigned_resource_site_id']
            assets[key]['state_mapping']=recipe['state_mappings'][site_id]
            if route_arcane:assets[key]['site_id']=site_id
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
    var spec_bytes := FileAccess.get_file_as_bytes(OS.get_environment("CUTOUT_ASSETS_FILE"))
    check(digest(spec_bytes)==OS.get_environment("CUTOUT_ASSETS_SHA256"),"complete independent asset expectations transferred unchanged")
    if not errors.is_empty():
        print("OVERWORLD_CUTOUT_BATCH "+JSON.stringify({"ok":false,"checks":checks,"errors":errors}))
        get_tree().quit(1)
        return
    var specs: Dictionary = JSON.parse_string(spec_bytes.get_string_from_utf8())
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
    var captured_sources := {}
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
        var source_group: String = str(specs[asset_id].get("source_group","batch04"))
        var capture_requested: bool = OS.get_environment("CUTOUT_CAPTURE_PER_SOURCE")!="1" or not captured_sources.has(source_group)
        if capture_requested and DisplayServer.get_name()!="headless":
            await RenderingServer.frame_post_draw
            get_viewport().get_texture().get_image().save_png(out.path_join(asset_id+".png"))
        captured_sources[source_group]=true
        captures.append({"asset_id":asset_id,"placement":exact_placement,"tile":tile,"screenshot_requested":capture_requested})
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
    parser.add_argument('--batch',choices=['batch04','map_sheets','decorations','legacy_families','passages','recurring_encounters','recurring_sites','claimed_dwellings','early_states','landmark_states','route_arcane','command_sites','recruitment_sites','training_sites','contract_encounters','remaining_encounters','artifacts','remaining_sites','heroes','towns'],default='batch04')
    parser.add_argument('--label',required=True)
    parser.add_argument('--resolution',choices=['1280x720','1920x1080'],default='1280x720')
    parser.add_argument('--expected-dir',type=Path,help='Preview acceptance candidate; permits an honest failing-before run')
    args=parser.parse_args()
    if not re.fullmatch(r'[a-z0-9_-]+',args.label):parser.error('label must be a fresh slug')
    original=earned_save_bytes()
    recipe=json.loads({'batch04':RECIPE,'map_sheets':POOL_RECIPE,'decorations':DECORATION_RECIPE,'legacy_families':LEGACY_RECIPE,'passages':PASSAGE_RECIPE,'recurring_encounters':RECURRING_RECIPE,'recurring_sites':RECURRING_SITE_RECIPE,'claimed_dwellings':CLAIMED_RECIPE,'early_states':EARLY_STATE_RECIPE,'landmark_states':LANDMARK_STATE_RECIPE,'route_arcane':ROUTE_ARCANE_RECIPE,'command_sites':COMMAND_SITE_RECIPE,'recruitment_sites':RECRUITMENT_RECIPE,'training_sites':TRAINING_RECIPE,'contract_encounters':CONTRACT_RECIPE,'remaining_encounters':REMAINING_ENCOUNTER_RECIPE,'artifacts':ARTIFACT_RECIPE,'remaining_sites':REMAINING_SITE_RECIPE,'heroes':HERO_RECIPE,'towns':TOWN_RECIPE}[args.batch].read_text())
    script=SCRIPT
    if args.batch=='decorations':
        from overworld_decoration_cutout_probe import SCRIPT as script
    if args.batch=='legacy_families':
        from overworld_legacy_cutout_probe import SCRIPT as script
    if args.batch=='passages':
        from overworld_passage_cutout_probe import SCRIPT as script
    if args.batch=='recurring_encounters':
        from overworld_recurring_cutout_probe import SCRIPT as script
    if args.batch=='recurring_sites':
        from overworld_recurring_site_cutout_probe import SCRIPT as script
    if args.batch=='claimed_dwellings':
        from overworld_claimed_cutout_probe import SCRIPT as script
    if args.batch=='early_states':
        from overworld_state_cutout_probe import SCRIPT as script
    if args.batch=='landmark_states':
        from overworld_landmark_cutout_probe import SCRIPT as script
    if args.batch=='route_arcane':
        from overworld_route_arcane_cutout_probe import SCRIPT as script
    if args.batch=='command_sites':
        from overworld_command_cutout_probe import SCRIPT as script
    if args.batch=='towns':
        from overworld_town_cutout_probe import SCRIPT as script
    if args.batch=='heroes':
        from overworld_hero_cutout_probe import SCRIPT as script
    if args.batch=='remaining_sites':
        from overworld_remaining_site_cutout_probe import SCRIPT as script
    if args.batch=='artifacts':
        from overworld_artifact_cutout_probe import SCRIPT as script
    if args.batch=='remaining_encounters':
        from overworld_remaining_encounter_cutout_probe import SCRIPT as script
    if args.batch=='contract_encounters':
        from overworld_contract_cutout_probe import SCRIPT as script
    if args.batch=='training_sites':
        from overworld_training_cutout_probe import SCRIPT as script
    if args.batch=='recruitment_sites':
        from overworld_recruitment_cutout_probe import SCRIPT as script
    output=OUTPUT/args.label
    output.mkdir(parents=True,exist_ok=False)
    assets=expected_assets(recipe,args.expected_dir,output)
    # A full cohort exceeds Windows' single environment-variable capacity.
    # Only expectations live in this file, never textures or world overrides.
    expectations=output/'expected-assets.json'
    expectations.write_text(json.dumps(assets,sort_keys=True)+'\n')
    with tempfile.TemporaryDirectory(prefix='cutout-probe-',dir=OUTPUT) as temp, tempfile.TemporaryDirectory(prefix='cutout-userdata-',dir='/dev/shm') as userdata:
        directory=Path(temp)
        (directory/'probe.gd').write_text(script)
        scene=directory/'probe.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://%s" id="1"]\n[node name="CutoutBatchProbe" type="Node"]\nscript = ExtResource("1")\n' % (directory/'probe.gd').relative_to(ROOT))
        env=dict(os.environ,XDG_DATA_HOME=userdata,CUTOUT_OUTPUT=str(output),CUTOUT_SAVE=str(SAVE),CUTOUT_RESOLUTION=args.resolution,CUTOUT_ASSETS_FILE=str(expectations),CUTOUT_ASSETS_SHA256=hashlib.sha256(expectations.read_bytes()).hexdigest(),CUTOUT_CAPTURE_PER_SOURCE='1' if args.batch=='map_sheets' else '0')
        with (output/'runtime.log').open('w') as log:
            code=run_probe(['dbus-run-session','--','xvfb-run','-a','-s','-screen 0 2200x1200x24','godot4','--path',str(ROOT),'--audio-driver','Dummy','--accessibility','disabled','res://'+str(scene.relative_to(ROOT))],probe_environment(env),log)
    lines=(output/'runtime.log').read_text().splitlines()
    found=[json.loads(s[len(MARKER):]) for s in lines if s.startswith(MARKER)]
    report=found[-1] if found else dict(ok=False,errors=['missing Godot report'])
    report.update(returncode=code,save_sha256=SAVE_SHA,input_unchanged=SAVE.read_bytes()==original,resolution=args.resolution,
                  expected_rasters=assets,runtime_errors=[s for s in lines if s.startswith(('ERROR:','SCRIPT ERROR:')) or 'leaked' in s])
    captures_ok=report.get('backend')=='headless' or all((output/(r.get('screenshot_id',r['asset_id'])+'.png')).exists() for r in report.get('captures',[]) if r.get('screenshot_requested',True))
    if args.batch=='legacy_families':
        captures_ok=captures_ok and len(report.get('galleries',[]))==3 and (report.get('backend')=='headless' or all((output/name).exists() for name in report['galleries']))
    if args.batch=='passages':
        captures_ok=captures_ok and len(report.get('galleries',[]))==1 and (report.get('backend')=='headless' or all((output/name).exists() for name in report['galleries']))
    if args.batch in ('recurring_encounters','recurring_sites','claimed_dwellings','early_states','command_sites','recruitment_sites'):
        captures_ok=captures_ok and len(report.get('galleries',[]))==3 and (report.get('backend')=='headless' or all((output/name).exists() for name in report['galleries']))
    if args.batch in ('landmark_states','training_sites','towns'):
        captures_ok=captures_ok and len(report.get('galleries',[]))==4 and (report.get('backend')=='headless' or all((output/name).exists() for name in report['galleries']))
    if args.batch in ('route_arcane','contract_encounters','remaining_sites','heroes'):
        captures_ok=captures_ok and len(report.get('galleries',[]))==5 and (report.get('backend')=='headless' or all((output/name).exists() for name in report['galleries']))
    if args.batch=='remaining_encounters':
        captures_ok=captures_ok and len(report.get('galleries',[]))==8 and (report.get('backend')=='headless' or all((output/name).exists() for name in report['galleries']))
    if args.batch=='artifacts':
        captures_ok=captures_ok and len(report.get('galleries',[]))==6 and (report.get('backend')=='headless' or all((output/name).exists() for name in report['galleries']))
    report['ok']=bool(report['ok']) and code==0 and report['input_unchanged'] and not report['runtime_errors'] and captures_ok
    (output/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k not in ('textures','captures','expected_rasters')}))
    return 0 if report['ok'] else 1


if __name__=='__main__':raise SystemExit(main())
