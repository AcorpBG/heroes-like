#!/usr/bin/env python3
"""Town biome art provenance, resolver and unchanged generated-map authority.

Python owns the disposable Godot driver and profile on both platforms. Coverage
is intentionally reported separately from acceptance: a first valid skin is not
proof that every town/terrain combination has been artistically completed.
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PACKET = ROOT / 'art/overworld/source/generated/towns/biome_fit/manifest.json'
MARKER = 'OVERWORLD_RASTER_TERRAIN_BLOCKER_MASS_REPORT '


def validate_assets(art=None, skins=None):
    art = json.loads((ROOT/'art/overworld/manifest.json').read_text()) if art is None else art
    proof = json.loads(PACKET.read_text())
    errors = []
    if '!art/overworld/runtime/objects/towns/biome_fit/*.png.import' not in (ROOT/'.gitignore').read_text().splitlines():
        errors.append('bounded town import settings are not retained for clean checkouts')
    skins = json.loads((ROOT/'art/overworld/town_biome_sprites.json').read_text()) if skins is None else skins
    frozen = json.loads((ROOT/'art/overworld/source/generated/cutout_recovery_20260909/final_families/recipe.json').read_text())['mapping_tables']
    if {key:value for key,value in art.items() if key != 'object_assets'} != frozen:
        errors.append('historical gameplay identity tables changed')
    known = set(art['town_identity_sprites'].values()) | set(art['town_faction_sprites'].values()) | {art['town_default_sprite']['asset_id']}
    biomes = set(skins.get('terrain_aliases', {}).values())
    terrain_names = set(art['terrain_rendering']['raster_base_v2']['terrain_assets']) | {'subterranean'}
    if not terrain_names.issubset(skins.get('terrain_aliases', {})):
        errors.append('runtime terrain names missing town biome aliases')
    if set(skins.get('appearances', {})) != known:
        errors.append('explicit town appearance coverage is incomplete')
    variants = set()
    for base, row in skins.get('appearances', {}).items():
        if base not in known:
            errors.append('unknown base identity: '+base)
        if set(row.get('biome_asset_ids', {})) != biomes or not row.get('environment_policy'):
            errors.append('missing explicit biome/environment policy: '+base)
        architecture = row.get('shares_architecture_with',base)
        if architecture != base:
            first, second = art['object_assets'].get(base,{}), art['object_assets'].get(architecture,{})
            if architecture not in art['town_faction_sprites'].values() or first.get('path') != second.get('path') or first.get('atlas_region') != second.get('atlas_region'):
                errors.append('unproven shared town architecture: '+base)
        for biome, asset_id in row.get('biome_asset_ids', {}).items():
            if asset_id != base: variants.add(asset_id)
            if biome not in skins.get('terrain_aliases', {}).values():
                errors.append('unknown biome: '+biome)
            if asset_id not in art['object_assets'] or (asset_id != base and asset_id not in proof['assets']):
                errors.append('missing manifest-backed variant: '+asset_id)
            elif asset_id != base and art['object_assets'][asset_id].get('base_asset_id') != architecture:
                errors.append('variant substitutes a different town: '+asset_id)
    if variants != set(proof['assets']):
        errors.append('provenance and live variant membership differ')
    declared = {key for key, entry in art['object_assets'].items() if entry.get('source_model') == 'built_in_image_gen_original_biome_town_variant'}
    if declared != set(proof['assets']):
        errors.append('town biome canvas family has unproven or missing members')
    for asset_id, row in proof['assets'].items():
        entry = art['object_assets'].get(asset_id, {})
        for field in ('input', 'draft', 'source', 'trimmed', 'runtime'):
            path = ROOT / row[field].removeprefix('res://')
            if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != row['sha256'][field]:
                errors.append(asset_id+': missing or modified '+field)
        if entry.get('path') != row['runtime'] or entry.get('source_generated') != row['source'] or entry.get('source_trimmed') != row['trimmed']:
            errors.append(asset_id+': provenance path mismatch')
        if entry.get('runtime_sha256') != row['sha256']['runtime']:
            errors.append(asset_id+': runtime hash mismatch')
        path = ROOT/row['runtime'].removeprefix('res://')
        if not path.is_file():
            continue
        with Image.open(path) as image:
            if image.mode != 'RGBA' or list(image.size) != row['canvas']:
                errors.append(asset_id+': wrong canvas or missing real alpha')
            else:
                alpha = image.getchannel('A')
                if alpha.histogram()[0] < image.width*image.height*.1:
                    errors.append(asset_id+': opaque background')
                # Generated antialiasing can contain alpha=1 black pixels; an
                # opaque matte/checkerboard remains a hard failure.
                if any(alpha.getpixel(p) > 1 for p in [(0,0),(image.width-1,0),(0,image.height-1),(image.width-1,image.height-1)]):
                    errors.append(asset_id+': opaque corner')
        imp = path.with_suffix('.png.import')
        if not imp.is_file() or 'process/size_limit=512' not in imp.read_text():
            errors.append(asset_id+': texture import is not bounded')
        if not row.get('prompt') or not (row.get('extraction_prompt') or row.get('offline_recipe')):
            errors.append(asset_id+': missing original generation prompts')
        if row.get('offline_recipe'):
            recipe = json.loads((ROOT/row['offline_recipe'].removeprefix('res://')).read_text())
            job = recipe['jobs'].get(row.get('recipe_job'), {})
            if job.get('draft_sha256') != row['sha256']['draft'] or job.get('base_asset_id') != row['base_asset_id'] or row['canvas'] != [512,512]:
                errors.append(asset_id+': offline recipe/provenance mismatch')
            if 'intermediate' in job:
                intermediate = job['intermediate']
                p = ROOT/intermediate['path'].removeprefix('res://')
                if not p.is_file() or hashlib.sha256(p.read_bytes()).hexdigest() != intermediate['sha256']:
                    errors.append(asset_id+': missing intermediate edit provenance')
    return errors


def validate_processing():
    """Reproduce alpha and packing from immutable generated masters."""
    spec = importlib.util.spec_from_file_location('town_matte', ROOT/'tools/prepare_town_biome_art.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    recipe = json.loads((PACKET.parent/'offline_recipe.json').read_text())
    proof = json.loads(PACKET.read_text())
    errors = []
    for name, job in recipe['jobs'].items():
        row = proof['assets']['town_biome_'+name]
        white = job.get('flat_white',False)
        with Image.open(ROOT/job['draft'].removeprefix('res://')) as image:
            cutout,matte = module.extract(image,job.get('seeds',()),minimum=230 if white else 155,tolerance=20 if white else 35,flat_white=white)
            runtime,transform = module.fit(cutout)
        with Image.open(ROOT/row['source'].removeprefix('res://')) as image:
            if cutout.tobytes() != image.tobytes(): errors.append(name+': source alpha is not reproducible')
        with Image.open(ROOT/row['runtime'].removeprefix('res://')) as image:
            if runtime.tobytes() != image.tobytes(): errors.append(name+': runtime fit is not reproducible')
        if matte != row['matte'] or transform != row['transform']:
            errors.append(name+': recorded processing differs')
    return errors


def validate_clean_import(godot, output):
    """Prove a clean checkout does not depend on this workspace's import cache."""
    proof=json.loads(PACKET.read_text())
    output.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='town-biome-clean-import-') as temporary:
        work=Path(temporary)
        (work/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Town biome clean import"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        paths=[]
        for row in proof['assets'].values():
            relative=row['runtime'].removeprefix('res://')
            target=work/relative
            target.parent.mkdir(parents=True,exist_ok=True)
            shutil.copyfile(ROOT/relative,target)
            shutil.copyfile(ROOT/(relative+'.import'),work/(relative+'.import'))
            paths.append(row['runtime'])
        source='extends SceneTree\nfunc _init():\n\tvar failed := false\n\tfor path in '+json.dumps(paths)+':\n\t\tvar texture=load(path)\n\t\tif not texture is Texture2D or texture.get_size()!=Vector2(512,512):\n\t\t\tfailed=true\n\tprint("TOWN_CLEAN_IMPORT_OK "+str(not failed))\n\tquit(1 if failed else 0)\n'
        (work/'probe.gd').write_text(source)
        env=dict(os.environ,XDG_DATA_HOME=str(work/'profile'),XDG_CONFIG_HOME=str(work/'profile'),APPDATA=str(work/'profile'))
        codes=[]
        with (output/'clean-import.log').open('w') as log:
            for command in ([godot,'--headless','--editor','--import','--path',str(work)], [godot,'--headless','--path',str(work),'--script','res://probe.gd']):
                result=subprocess.run(command,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=120)
                codes.append(result.returncode)
                if result.returncode: break
        log=(output/'clean-import.log').read_text()
        return [] if codes==[0,0] and 'TOWN_CLEAN_IMPORT_OK true' in log and 'ERROR:' not in log else ['clean-cache town texture import failed; see clean-import.log']


PROBE = r'''
func _check_town_biomes(view, session) -> void:
	var before: Dictionary = session.to_dict()
	var resolver = load("res://scripts/core/TownBiomeArtRules.gd")
	var manifest: Dictionary = ContentService.load_json("res://art/overworld/manifest.json")
	var skins: Dictionary = ContentService.load_json("res://art/overworld/town_biome_sprites.json")
	var all_bases: Array = manifest.town_identity_sprites.values() + manifest.town_faction_sprites.values() + [manifest.town_default_sprite.asset_id]
	var rows := []
	var checked_scale := {}
	for base in all_bases:
		for terrain in skins.terrain_aliases:
			var resolved: Dictionary = resolver.resolve(base, terrain, skins)
			var asset_id: String = resolved.render_asset_id
			if resolved != resolver.resolve(base, terrain, skins): _failures.append("unstable biome selection")
			var loaded = view._object_texture_for_asset(asset_id)
			if not loaded is Texture2D: _failures.append("missing town art " + asset_id)
			elif asset_id.begins_with("town_biome_") and loaded.get_size() != Vector2(512,512): _failures.append("unbounded biome art " + asset_id)
			if not checked_scale.has(asset_id):
				var scale: Dictionary = view.validation_town_sprite_scale_payload(asset_id)
				if not bool(scale.get("town_aspect_preserved", false)) or not bool(scale.get("painted_bottom_grounded_exact", false)) or not bool(scale.get("sprite_silhouette_contained_in_footprint", false)):
					_failures.append("biome sprite changed aspect/grounding/envelope " + asset_id)
				checked_scale[asset_id] = true
			rows.append(resolved)
	var isolated = load("res://scenes/overworld/OverworldMapView.gd").new()
	isolated._load_overworld_art_manifest()
	isolated._map_data = [["grass", "snow"], ["forest", "lava"]]
	var town := {"town_id":"town_riverwatch", "x":0, "y":0, "visit_tile":{"x":1,"y":1}, "owner":"player"}
	var town_before: Dictionary = town.duplicate(true)
	var actual: Dictionary = isolated._town_biome_appearance(town)
	if actual.render_asset_id != "town_biome_riverwatch_ash": _failures.append("native entrance terrain not used on a mixed edge")
	town.owner = "enemy"
	if isolated._town_biome_appearance(town) != actual: _failures.append("ownership changed architecture")
	town.owner = "player"
	if town != town_before: _failures.append("resolver changed the Town record")
	isolated._map_data[1][1] = "ash"
	if isolated._town_biome_appearance(town).render_asset_id != actual.render_asset_id: _failures.append("ash/lava alias mismatch")
	isolated._map_data[1][1] = "snow"
	if isolated._town_biome_appearance(town).render_asset_id != "town_biome_riverwatch_land": _failures.append("stale appearance after terrain edit")
	var texture = isolated._object_texture_for_asset("town_biome_riverwatch_ash")
	if texture == null or texture.get_size() != Vector2(512,512): _failures.append("unbounded or missing biome texture")
	town.town_id = "town_duskfen"
	if isolated._town_biome_appearance(town).render_asset_id != "town_biome_duskfen_land": _failures.append("Duskfen land variant not selected")
	isolated._map_data[1][1] = "mire"
	if isolated._town_biome_appearance(town).render_asset_id != "town_identity_duskfen": _failures.append("Duskfen original marsh art not preserved")
	isolated.free()
	var generated := []
	for live_town in view._towns_by_tile.values():
		generated.append(view._town_biome_appearance(live_town))
	if not generated.any(func(row): return row.render_asset_id == "town_biome_riverwatch_ash"):
		_failures.append("representative native seed did not select the Riverwatch ash correction")
	if session.to_dict() != before: _failures.append("biome resolution changed session state")
	print("TOWN_BIOME_RESOLUTION " + JSON.stringify({"rows":rows,"generated_towns":generated,"coverage_status":skins.coverage_status}))

func _capture_town_biome_review(shell, session) -> void:
	var before: Dictionary = session.to_dict()
	var fog: Dictionary = session.overworld.get("fog", {}).duplicate(true)
	_reveal_all_for_art_review(session)
	shell.call("_refresh_map_view")
	get_window().size = Vector2i(1920,1080)
	await get_tree().process_frame
	for town in session.overworld.get("towns", []):
		if String(town.get("town_id", "")) != "town_duskfen": continue
		var tile: Vector2i = shell.get_node("%Map")._town_entry_tile(town)
		shell.validation_minimap_recenter(tile.x,tile.y)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var raster := get_viewport().get_texture().get_image()
		var path := ProjectSettings.globalize_path(CAPTURE_DIR).path_join("duskfen_land_art_review_reveal_all_1920x1080.png")
		if raster == null or raster.save_png(path) != OK: _failures.append("Duskfen capture failed")
		break
	session.overworld["fog"] = fog
	shell.call("_refresh_map_view")
	await get_tree().process_frame
	if session.to_dict() != before: _failures.append("Town art review did not restore normal fog")
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--assets-only', action='store_true')
    parser.add_argument('--reproduce-processing', action='store_true')
    parser.add_argument('--clean-import', action='store_true')
    parser.add_argument('--proportion', action='store_true', help='Run the existing town proportion/environs probe with isolated evidence/profile')
    parser.add_argument('--godot', default=shutil.which('godot4') or shutil.which('godot'))
    parser.add_argument('--output', type=Path, default=ROOT/'.artifacts/town-biome-fit-20260913')
    args = parser.parse_args()
    failures = validate_assets()
    if args.reproduce_processing: failures += validate_processing()
    if args.clean_import:
        if not args.godot: parser.error('Godot is required for clean import')
        failures += validate_clean_import(args.godot,args.output.resolve())
    corrupt = json.loads((ROOT/'art/overworld/town_biome_sprites.json').read_text())
    corrupt['appearances']['town_identity_riverwatch']['biome_asset_ids']['biome_ash_lava_wastes'] = 'missing_skin'
    if not validate_assets(skins=corrupt): failures.append('missing variant corruption escaped validation')
    incomplete = json.loads((ROOT/'art/overworld/town_biome_sprites.json').read_text())
    del incomplete['appearances']['town_identity_riverwatch']['biome_asset_ids']['biome_snow_frost_marches']
    if not validate_assets(skins=incomplete): failures.append('missing biome mapping escaped validation')
    wrong_identity = json.loads((ROOT/'art/overworld/town_biome_sprites.json').read_text())
    wrong_identity['appearances']['town_identity_riverwatch']['shares_architecture_with'] = 'town_faction_mireclaw'
    if not validate_assets(skins=wrong_identity): failures.append('unproven architecture sharing escaped validation')
    if failures or args.assets_only:
        print(json.dumps({'ok':not failures, 'failures':failures})); return int(bool(failures))
    if not args.godot: parser.error('Godot is required')
    out = args.output.resolve()
    if args.proportion:
        out = out/'proportion'
    out.mkdir(parents=True, exist_ok=True)
    resource = 'res://'+out.relative_to(ROOT).as_posix()
    source = (ROOT/'tests/overworld_raster_terrain_blocker_mass_report.gd').read_text()
    source = source.replace('res://.artifacts/overworld_cohesive_biome_blocker_mass_10232', resource)
    source = source.replace('\t_validate_body_summary(first_summary)', '\t_validate_body_summary(first_summary)\n\t_check_town_biomes(map_view, session)') + PROBE
    source = source.replace('\tvar redraw_summary:', '\tawait _capture_town_biome_review(shell, session)\n\tvar redraw_summary:')
    marker = MARKER
    if args.proportion:
        source = (ROOT/'tests/overworld_town_proportion_environs_report.gd').read_text()
        source = source.replace('res://.artifacts/overworld_town_proportion_environs_10236', resource)
        marker = 'OVERWORLD_TOWN_PROPORTION_ENVIRONS_REPORT '
    with tempfile.TemporaryDirectory(prefix='town-biome-driver-', dir=out) as temporary:
        work = Path(temporary)
        script = work/'probe.gd'
        script.write_text(source, encoding='utf-8')
        scene = work/'probe.tscn'
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://'+script.relative_to(ROOT).as_posix()+'" id="1"]\n[node name="TownBiome" type="Node"]\nscript=ExtResource("1")\n', encoding='utf-8')
        command = [args.godot,'--path',str(ROOT),'--audio-driver','Dummy','--accessibility','disabled','--rendering-method','gl_compatibility','--resolution','1920x1080','--position','-10000,-10000','res://'+scene.relative_to(ROOT).as_posix()]
        env = dict(os.environ, APPDATA=str(work/'profile'), XDG_DATA_HOME=str(work/'profile'))
        options = {}
        if os.name == 'nt':
            startup = subprocess.STARTUPINFO(); startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW; startup.wShowWindow = subprocess.SW_HIDE
            options['startupinfo'] = startup
        else:
            command = ['xvfb-run','-a','-s','-screen 0 1920x1080x24'] + command
            options['start_new_session'] = True
        with (out/'runtime.log').open('w', encoding='utf-8') as log:
            process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT, **options)
            try: code = process.wait(timeout=360)
            except subprocess.TimeoutExpired:
                code = 124
            finally:
                if process.poll() is None:
                    if os.name == 'nt':
                        subprocess.run(['taskkill','/PID',str(process.pid),'/T','/F'], capture_output=True, timeout=15)
                    else:
                        os.killpg(process.pid, signal.SIGKILL)
                    process.wait(timeout=10)
    lines = (out/'runtime.log').read_text().splitlines()
    reports = [json.loads(line[len(marker):]) for line in lines if line.startswith(marker)]
    resolutions = [json.loads(line.split(' ',1)[1]) for line in lines if line.startswith('TOWN_BIOME_RESOLUTION ')]
    report = reports[-1] if reports else {'ok':False,'failures':['missing generated-map report']}
    report['town_biome_resolution'] = resolutions[-1] if resolutions else {}
    report['process_exit_code'] = code
    report['ok'] = bool(report.get('ok')) and (args.proportion or bool(resolutions)) and code == 0
    report['errors_in_log'] = [line for line in lines if 'SCRIPT ERROR:' in line or line.startswith('ERROR:')]
    report['ok'] = report['ok'] and not report['errors_in_log']
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({'ok':report['ok'],'report':str(out/'report.json'),'failures':report.get('failures',[]),'errors':report['errors_in_log']}))
    return 0 if report['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
