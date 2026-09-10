#!/usr/bin/env python3
"""Recover 34 original command-site paintings without changing logical geometry.

All masters have genuine alpha. No color removal, generated token, painting or
alpha repair is needed. The retained 48px atlases prove original registration;
192px cells are projected directly from the original paintings, not upscaled.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil

from PIL import Image, ImageChops, ImageDraw, ImageOps, ImageStat

ROOT = Path(__file__).resolve().parents[1]
PACKET = ROOT/'art/overworld/source/generated/cutout_recovery_20260909/command_sites'
RECIPE = PACKET/'recipe.json'
MANIFEST = ROOT/'art/overworld/manifest.json'
SHARED = ROOT/'tools/prepare_overworld_recurring_cutouts.py'
spec = importlib.util.spec_from_file_location('command_original_projection', SHARED)
shared = importlib.util.module_from_spec(spec); spec.loader.exec_module(shared)
base = shared.base; owner = shared.owner; project = shared.recover
FAMILIES = {'marchland_warband_musters': 12, 'marchland_grand_route_operations': 12,
            'commander_dominion_sieges': 10}


def before_path(path):
    return PACKET/'before_runtime'/base.local(path).relative_to(ROOT/'art/overworld/runtime')


def original(path):
    archive = before_path(path)
    return Image.open(archive if archive.exists() else base.local(path)).convert('RGBA')


def expected_entry(row):
    old = row['original_manifest_entry']
    return dict(old, atlas_region=[v*4 for v in old['atlas_region']],
                atlas_size=[v*4 for v in old['atlas_size']], source_trimmed=row['trimmed_path'],
                source_processing_manifest=base.resource(PACKET/'manifest.json'))


def registration(source, row, old):
    projected = project(source, dict(row, canvas_size=[48, 48], pixel_scale=1))
    diff = ImageChops.difference(old, projected)
    mask = ImageChops.multiply(old.getchannel('A').point(lambda a: 255 if a>200 else 0),
                              projected.getchannel('A').point(lambda a: 255 if a>200 else 0))
    result = dict(alpha_mae=ImageStat.Stat(diff.getchannel('A')).mean[0],
                  opaque_rgb_mae=sum(ImageStat.Stat(diff.convert('RGB'), mask).mean)/3)
    visible = ImageChops.lighter(old.getchannel('A'), projected.getchannel('A')).point(lambda a: 255 if a else 0)
    if diff.getchannel('A').getbbox() or ImageChops.multiply(diff.convert('RGB'), visible.convert('RGB')).getbbox():
        raise ValueError('Original registration changed')
    return result


def inputs():
    recipe = json.loads(RECIPE.read_text()); manifest = json.loads(MANIFEST.read_text())
    proof = json.loads((PACKET/'manifest.json').read_text()) if (PACKET/'manifest.json').exists() else {}
    paths = {f'res://art/overworld/runtime/objects/resource_sites/{f}_atlas.png' for f in FAMILIES}
    if recipe.get('schema_id')!='command_site_cutout_recipe_v1' or len(recipe['assets'])!=34 or set(recipe['atlases'])!=paths or recipe['preserved_controls']:
        raise ValueError('Cohort changed')
    if {k for k,v in manifest['object_assets'].items() if v['path'] in paths}!=set(recipe['assets']):
        raise ValueError('Incomplete atlas membership')
    if set(recipe['state_mappings'])!={r['original_manifest_entry']['assigned_resource_site_id'] for r in recipe['assets'].values()}:
        raise ValueError('Incomplete site coverage')
    if any(manifest['resource_site_sprites'][k]!=v for k,v in recipe['state_mappings'].items()):
        raise ValueError('State mapping changed')
    for path, info in recipe['atlases'].items():
        count = FAMILIES[Path(path).stem.removesuffix('_atlas')]
        if info['before_size']!=[count*48,48] or list(original(path).size)!=info['before_size']:
            raise ValueError('Historical geometry changed')
        if base.digest(before_path(path) if before_path(path).exists() else base.local(path))!=info['before_sha256']:
            raise ValueError('Historical atlas changed')
        if base.digest(base.local(path)) not in (info['before_sha256'], proof.get('files',{}).get(path,{}).get('after_sha256')):
            raise ValueError('Unrecognized runtime edit')
        if sorted(r['original_manifest_entry']['atlas_region'][0] for r in recipe['assets'].values() if r['runtime_path']==path)!=list(range(0,count*48,48)):
            raise ValueError('Incomplete region coverage')
    sources = {}
    for key, row in recipe['assets'].items():
        old = row['original_manifest_entry']; entry = manifest['object_assets'][key]
        strip = lambda v: {k:x for k,x in v.items() if k!='runtime_sha256'}
        if strip(entry) not in (strip(old), strip(expected_entry(row))): raise ValueError('Identity changed: '+key)
        path = base.local(old['source_generated'])
        if base.digest(path)!=row['source_sha256']: raise ValueError('Original painting changed: '+key)
        source = Image.open(path).convert('RGBA'); sources[key] = source
        if row['source_mode']!='genuine_rgba' or len(set(source.getchannel('A').getdata()))!=row['source_alpha_levels'] or row['source_alpha_levels'] not in (255,256):
            raise ValueError('Alpha policy changed')
        if list(source.size)!=row['source_size'] or list(source.getchannel('A').getbbox())!=row['source_crop']:
            raise ValueError('Source crop changed')
        fit = ImageOps.contain(source.crop(row['source_crop']), (42,42), Image.Resampling.LANCZOS).size
        if row['source_resize']!=list(fit) or row['canvas_origin']!=[(48-v)//2 for v in fit] or row['fit_limit']!=42:
            raise ValueError('Logical fit/anchor changed')
        if row['canvas_size']!=[192,192] or row['pixel_scale']!=4 or row['resampling']!='LANCZOS' or row['runtime_path']!=old['path'] or old['atlas_region'][1:]!=[0,48,48]:
            raise ValueError('Density/filter changed')
        if row['registration_evidence']!=registration(source,row,owner.region(original(old['path']),old)):
            raise ValueError('Historical registration proof changed')
        trim = ROOT/'art/overworld/source/trimmed/cutout_recovery_20260909/command_sites'/(key+'.png')
        if base.local(row['trimmed_path'])!=trim: raise ValueError('Unscoped derived path')
        if trim.exists() and base.digest(trim)!=proof.get('assets',{}).get(key,{}).get('trim_sha256'):
            raise ValueError('Unrecognized derived edit')
    return recipe, manifest, sources


def tool_hashes():
    return {str(p.relative_to(ROOT)): base.digest(p) for p in [Path(__file__),SHARED,ROOT/'tools/prepare_overworld_cutout_art.py',ROOT/'tools/prepare_overworld_legacy_cutouts.py']}


def prepare(output, install=False):
    output = output.resolve()
    if output==ROOT or output.is_relative_to(ROOT/'art'): raise ValueError('Preview must be outside art')
    recipe, manifest, sources = inputs(); output.mkdir(parents=True, exist_ok=False)
    atlases = {p:Image.new('RGBA',tuple(v*4 for v in r['before_size'])) for p,r in recipe['atlases'].items()}
    rows = {}; files = {}; results = {}
    for key,row in recipe['assets'].items():
        fixed = project(sources[key],row); results[key] = fixed
        fixed.save(output/(key+'.png'),optimize=True)
        rows[key] = dict(trim_sha256=base.digest(output/(key+'.png')),rgba_sha256=hashlib.sha256(fixed.tobytes()).hexdigest())
        x,y,_,_ = expected_entry(row)['atlas_region']; atlases[row['runtime_path']].paste(fixed,(x,y))
    for path,atlas in atlases.items():
        target = output/'runtime'/base.local(path).relative_to(ROOT/'art/overworld/runtime')
        target.parent.mkdir(parents=True,exist_ok=True); atlas.save(target,optimize=True)
        files[path] = dict(after_sha256=base.digest(target),prepared=str(target.relative_to(output)))
    for page,start in enumerate(range(0,34,6)):
        canvas=Image.new('RGB',(1440,800),'#334c3a');draw=ImageDraw.Draw(canvas)
        for j,(key,row) in enumerate(list(recipe['assets'].items())[start:start+6]):
            x,y=j%3*480,j//3*400
            old=owner.region(original(row['runtime_path']),row['original_manifest_entry']).resize((192,192),Image.Resampling.NEAREST)
            for col,im in enumerate((old,results[key])):canvas.paste(im,(x+col*225,y+30),im)
            draw.text((x+3,y+260),key.removeprefix('resource_site_'),fill='white')
            draw.text((x+3,y+285),'OLD 48 / ORIGINAL-SOURCE 192 (same map size)',fill='white')
        canvas.save(output/f'comparison_{page:02}.png')
    proof=dict(schema_id='command_site_cutout_recovery_v1',recipe_sha256=base.digest(RECIPE),tools=tool_hashes(),assets=rows,files=files,
               processing='Genuine original RGBA unchanged; measured 42px centered logical fit projected directly at fourfold raster density. No color/alpha deletion, state tokens or gameplay changes.')
    if install:
        for path,info in files.items():
            archive=before_path(path);archive.parent.mkdir(parents=True,exist_ok=True)
            if not archive.exists():shutil.copy2(base.local(path),archive)
            shutil.copyfile(output/info['prepared'],base.local(path))
        for key,row in recipe['assets'].items():
            dest=base.local(row['trimmed_path']);dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(output/(key+'.png'),dest)
            manifest['object_assets'][key]=dict(expected_entry(row),runtime_sha256=files[row['runtime_path']]['after_sha256'])
        MANIFEST.write_text(owner.manifest_text(manifest,recipe['assets']))
        (PACKET/'manifest.json').write_text(json.dumps(proof,indent=2)+'\n')
    (output/'report.json').write_text(json.dumps(proof,indent=2)+'\n')
    return dict(installed=install,assets=len(rows),atlases=len(files))


def validate_assets():
    recipe,manifest,sources=inputs();proof=json.loads((PACKET/'manifest.json').read_text())
    if proof['schema_id']!='command_site_cutout_recovery_v1' or proof['recipe_sha256']!=base.digest(RECIPE) or proof['tools']!=tool_hashes():raise ValueError('Preparation provenance changed')
    if set(proof['assets'])!=set(recipe['assets']) or set(proof['files'])!=set(recipe['atlases']):raise ValueError('Incomplete proof')
    atlases={p:Image.open(base.local(p)).convert('RGBA') for p in recipe['atlases']}
    for path,info in recipe['atlases'].items():
        if base.digest(before_path(path))!=info['before_sha256'] or list(atlases[path].size)!=[v*4 for v in info['before_size']] or base.digest(base.local(path))!=proof['files'][path]['after_sha256']:raise ValueError('Atlas provenance changed')
    for key,row in recipe['assets'].items():
        fixed=project(sources[key],row);entry=manifest['object_assets'][key];trim=base.local(row['trimmed_path'])
        if entry!=dict(expected_entry(row),runtime_sha256=proof['files'][entry['path']]['after_sha256']):raise ValueError('Runtime ownership changed')
        if owner.region(atlases[entry['path']],entry).tobytes()!=fixed.tobytes() or Image.open(trim).convert('RGBA').tobytes()!=fixed.tobytes():raise ValueError('Source reconstruction failed')
        if proof['assets'][key]!=dict(trim_sha256=base.digest(trim),rgba_sha256=hashlib.sha256(fixed.tobytes()).hexdigest()):raise ValueError('Paint proof changed')
    return {k:dict(ok=True,errors=[]) for k in recipe['assets']}


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path,required=True);parser.add_argument('--install',action='store_true')
    args=parser.parse_args();print(json.dumps(prepare(args.output,args.install)))
