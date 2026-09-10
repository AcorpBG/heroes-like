#!/usr/bin/env python3
"""Recover 54 retained resource-site paintings without moving their world anchors."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil

from PIL import Image, ImageChops, ImageDraw, ImageOps, ImageStat

ROOT=Path(__file__).resolve().parents[1]
PACKET=ROOT/'art/overworld/source/generated/cutout_recovery_20260909/remaining_sites'
RECIPE=PACKET/'recipe.json'
MANIFEST=ROOT/'art/overworld/manifest.json'
spec=importlib.util.spec_from_file_location('remaining_site_originals',ROOT/'tools/prepare_overworld_contract_cutouts.py')
shared=importlib.util.module_from_spec(spec);spec.loader.exec_module(shared)
base=shared.base;owner=shared.owner;project=shared.project
# Registration is frozen from original provenance and retained runtime rasters.
# Setbound's historical prose says center; the actual atlas is bottom-aligned.
FAMILIES={'triune_arcanum_trials':'bottom42','great_work_charter_races':'center42',
          'grand_muster_assemblies':'center42','relief_route_convoy_relays':'center44',
          'fogbreak_survey_instruments':'center44','frontier_treasury_offices':'center44',
          'setbound_regalia_reliquaries':'bottom42','grand_arcanum_convocations':'full_canvas',
          'uncrowned_sovereign_roads':'full_canvas'}


def paths():return {f'res://art/overworld/runtime/objects/resource_sites/{name}_atlas.png' for name in FAMILIES}


def rgba(path):
    with Image.open(path) as opened:return opened.convert('RGBA')


def before_path(path):return PACKET/'before_runtime'/base.local(path).relative_to(ROOT/'art/overworld/runtime')


def original(path):return rgba(before_path(path) if before_path(path).exists() else base.local(path))


def members(manifest):return {k:v for k,v in manifest['object_assets'].items() if v['path'] in paths()}


def transform(source,path):
    mode=FAMILIES[Path(path).stem.removesuffix('_atlas')]
    if mode=='full_canvas':
        if source.size!=(512,512):raise ValueError('Curated source canvas changed')
        crop=[0,0,512,512];fit=[48,48];origin=[0,0]
    else:
        crop=list(source.getchannel('A').getbbox());limit=int(mode[-2:])
        fit=list(ImageOps.contain(source.crop(crop),(limit,limit),Image.Resampling.LANCZOS).size)
        origin=[(48-fit[0])//2,48-fit[1] if mode.startswith('bottom') else (48-fit[1])//2]
    return dict(registration_mode=mode,source_crop=crop,source_resize=fit,canvas_origin=origin,
                canvas_size=[192,192],pixel_scale=4,resampling='LANCZOS')


def registration(source,row,old):
    projected=project(source,dict(row,canvas_size=[48,48],pixel_scale=1))
    diff=ImageChops.difference(old,projected)
    mask=ImageChops.multiply(old.getchannel('A').point(lambda a:255 if a>200 else 0),projected.getchannel('A').point(lambda a:255 if a>200 else 0))
    result=dict(alpha_mae=ImageStat.Stat(diff.getchannel('A')).mean[0],opaque_rgb_mae=sum(ImageStat.Stat(diff.convert('RGB'),mask).mean)/3)
    if row['registration_mode']=='full_canvas':
        if diff.getchannel('A').getbbox() or result['opaque_rgb_mae']!=0:raise ValueError('Curated source registration changed')
    elif result['alpha_mae']>5 or result['opaque_rgb_mae']>9:raise ValueError('Historical source registration changed')
    return result


def expected_entry(row):
    old=row['original_manifest_entry']
    return dict(old,atlas_region=[v*4 for v in old['atlas_region']],atlas_size=[1152,192],
                source_trimmed=row['trimmed_path'],source_processing_manifest=base.resource(PACKET/'manifest.json'))


def initialize():
    if RECIPE.exists():raise ValueError('Never overwrite a frozen recipe')
    manifest=json.loads(MANIFEST.read_text());selected=members(manifest)
    if len(selected)!=54:raise ValueError('Incomplete source cohort')
    assets={};files={}
    for key,entry in selected.items():
        path=entry['path'];source_path=base.local(entry['source_generated']);source=rgba(source_path)
        provenance=source_path.parent/'manifest.json'
        row=dict(original_manifest_entry=entry,runtime_path=path,source_sha256=base.digest(source_path),
                 source_size=list(source.size),source_alpha_levels=len(set(source.getchannel('A').getdata())),
                 source_manifest=base.resource(provenance),source_manifest_sha256=base.digest(provenance),
                 low_alpha_rgb_pixels=int(shared.noise_mask(source).sum()),
                 trimmed_path=base.resource(ROOT/'art/overworld/source/trimmed/cutout_recovery_20260909/remaining_sites'/(key+'.png')),
                 **transform(source,path))
        row['historical_registration']=registration(source,row,owner.region(original(path),entry));assets[key]=row
        files[path]=dict(before_size=list(original(path).size),before_sha256=base.digest(base.local(path)))
    recipe=dict(schema_id='remaining_site_cutout_recipe_v1',assets=assets,files=files,preserved_controls={},
                state_mappings={v['assigned_resource_site_id']:manifest['resource_site_sprites'][v['assigned_resource_site_id']] for v in selected.values()})
    PACKET.mkdir(parents=True,exist_ok=True);RECIPE.write_text(json.dumps(recipe,indent=2)+'\n')
    return dict(assets=len(assets),atlases=len(files))


def inputs():
    recipe=json.loads(RECIPE.read_text());manifest=json.loads(MANIFEST.read_text())
    proof=json.loads((PACKET/'manifest.json').read_text()) if (PACKET/'manifest.json').exists() else {}
    selected=members(manifest)
    if recipe['schema_id']!='remaining_site_cutout_recipe_v1' or len(selected)!=54 or set(selected)!=set(recipe['assets']) or set(recipe['files'])!=paths() or recipe['preserved_controls']:raise ValueError('Cohort membership changed')
    if set(recipe['state_mappings'])!={v['assigned_resource_site_id'] for v in selected.values()}:raise ValueError('Incomplete state routes')
    if any(manifest['resource_site_sprites'][k]!=v for k,v in recipe['state_mappings'].items()):raise ValueError('State route changed')
    for path,info in recipe['files'].items():
        prior=before_path(path) if before_path(path).exists() else base.local(path)
        if info['before_size']!=[288,48] or list(original(path).size)!=info['before_size'] or base.digest(prior)!=info['before_sha256']:raise ValueError('Historical atlas changed')
        if base.digest(base.local(path)) not in (info['before_sha256'],proof.get('files',{}).get(path,{}).get('after_sha256')):raise ValueError('Unrecognized runtime edit')
        if sorted(r['original_manifest_entry']['atlas_region'][0] for r in recipe['assets'].values() if r['runtime_path']==path)!=list(range(0,288,48)):raise ValueError('Incomplete region coverage')
    sources={}
    for key,row in recipe['assets'].items():
        old=row['original_manifest_entry'];entry=selected[key];source_path=base.local(old['source_generated']);provenance=base.local(row['source_manifest'])
        strip=lambda v:{k:value for k,value in v.items() if k!='runtime_sha256'}
        if strip(entry) not in (strip(old),strip(expected_entry(row))) or row['runtime_path']!=old['path']:raise ValueError('Identity metadata changed')
        if base.digest(source_path)!=row['source_sha256'] or base.digest(provenance)!=row['source_manifest_sha256']:raise ValueError('Original source or provenance changed')
        source_manifest=json.loads(provenance.read_text());matches=[v for v in source_manifest['items'] if v['asset_id']==key]
        if len(matches)!=1:raise ValueError('Missing source identity')
        match=matches[0];original_source=match.get('source_path',base.resource(provenance.parent/match.get('source_file','')))
        if original_source!=old['source_generated'] or match['source_sha256']!=row['source_sha256'] or match['site_id']!=old['assigned_resource_site_id'] or match['atlas_region']!=old['atlas_region']:raise ValueError('Source identity/region mismatch')
        if source_manifest['runtime_atlas']!=old['path'] or source_manifest['runtime_atlas_sha256']!=recipe['files'][old['path']]['before_sha256']:raise ValueError('Source atlas provenance changed')
        source=rgba(source_path);sources[key]=source
        if list(source.size)!=row['source_size'] or len(set(source.getchannel('A').getdata()))!=row['source_alpha_levels']:raise ValueError('Original alpha changed')
        if any(row[k]!=v for k,v in transform(source,old['path']).items()):raise ValueError('Original fit/anchor changed')
        if int(shared.noise_mask(source).sum())!=row['low_alpha_rgb_pixels']:raise ValueError('Reviewed RGB noise changed')
        if registration(source,row,owner.region(original(old['path']),old))!=row['historical_registration']:raise ValueError('Historical registration proof changed')
        trim=ROOT/'art/overworld/source/trimmed/cutout_recovery_20260909/remaining_sites'/(key+'.png')
        if base.local(row['trimmed_path'])!=trim:raise ValueError('Unscoped derived path')
        if trim.exists() and base.digest(trim)!=proof.get('assets',{}).get(key,{}).get('trim_sha256'):raise ValueError('Unrecognized derived edit')
    return recipe,manifest,sources


def tool_hashes():return dict(shared.tool_hashes(),**{str(Path(__file__).relative_to(ROOT)):base.digest(Path(__file__))})


def prepare(output,install=False):
    output=output.resolve()
    if output==ROOT.resolve() or output.is_relative_to((ROOT/'art').resolve()):raise ValueError('Preview outside source art required')
    recipe,manifest,sources=inputs();output.mkdir(parents=True,exist_ok=False)
    canvases={p:Image.new('RGBA',(1152,192)) for p in recipe['files']};results={};rows={};files={}
    for key,row in recipe['assets'].items():
        fixed=project(shared.recover_source(sources[key],row),row);results[key]=fixed
        fixed.save(output/(key+'.png'),optimize=True)
        rows[key]=dict(rgba_sha256=hashlib.sha256(fixed.tobytes()).hexdigest(),trim_sha256=base.digest(output/(key+'.png')))
        canvases[row['runtime_path']].paste(fixed,tuple(expected_entry(row)['atlas_region'][:2]))
    for path,canvas in canvases.items():
        dest=output/'runtime'/base.local(path).relative_to(ROOT/'art/overworld/runtime');dest.parent.mkdir(parents=True,exist_ok=True);canvas.save(dest,optimize=True)
        files[path]=dict(after_sha256=base.digest(dest),prepared=str(dest.relative_to(output)))
    for page,start in enumerate(range(0,54,6)):
        canvas=Image.new('RGB',(1440,800),'#334c3a');draw=ImageDraw.Draw(canvas)
        for j,(key,row) in enumerate(list(recipe['assets'].items())[start:start+6]):
            x,y=j%3*480,j//3*400;old=owner.region(original(row['runtime_path']),row['original_manifest_entry']).resize((192,192),Image.Resampling.NEAREST)
            for col,im in enumerate((old,results[key])):canvas.paste(im,(x+col*225,y+30),im)
            label=key.removeprefix('resource_site_')
            draw.text((x+3,y+260),label[:60],fill='white');draw.text((x+3,y+275),label[60:],fill='white')
            draw.text((x+3,y+300),'OLD 48 / ORIGINAL-SOURCE 192 (same world size)',fill='white')
        canvas.save(output/f'comparison_{page:02}.png')
    proof=dict(schema_id='remaining_site_cutout_recovery_v1',recipe_sha256=base.digest(RECIPE),tools=tool_hashes(),assets=rows,files=files,
               processing='54 original RGBA paintings at fourfold atlas density. Preserve historical centered/bottom 42/44px fits and complete curated 512px canvases. All source alpha and non-noise RGB unchanged; only reviewed saturated alpha 1..4 RGB borrows original foreground RGB. No procedural paint, state/identity/placement/gameplay change.')
    if install:
        for path,info in files.items():
            archive=before_path(path);archive.parent.mkdir(parents=True,exist_ok=True)
            if not archive.exists():shutil.copy2(base.local(path),archive)
            shutil.copyfile(output/info['prepared'],base.local(path))
        for key,row in recipe['assets'].items():
            dest=base.local(row['trimmed_path']);dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(output/(key+'.png'),dest)
            manifest['object_assets'][key]=dict(expected_entry(row),runtime_sha256=files[row['runtime_path']]['after_sha256'])
        MANIFEST.write_text(owner.manifest_text(manifest,recipe['assets']));(PACKET/'manifest.json').write_text(json.dumps(proof,indent=2)+'\n')
    (output/'report.json').write_text(json.dumps(proof,indent=2)+'\n')
    return dict(installed=install,assets=54,atlases=9)


def validate_assets():
    recipe,manifest,sources=inputs();proof=json.loads((PACKET/'manifest.json').read_text())
    if proof['schema_id']!='remaining_site_cutout_recovery_v1' or proof['recipe_sha256']!=base.digest(RECIPE) or proof['tools']!=tool_hashes():raise ValueError('Preparation provenance changed')
    if set(proof['assets'])!=set(recipe['assets']) or set(proof['files'])!=set(recipe['files']):raise ValueError('Incomplete proof')
    atlases={p:rgba(base.local(p)) for p in recipe['files']}
    for path,atlas in atlases.items():
        if atlas.size!=(1152,192) or base.digest(base.local(path))!=proof['files'][path]['after_sha256']:raise ValueError('Runtime atlas changed')
    for key,row in recipe['assets'].items():
        entry=manifest['object_assets'][key];fixed=project(shared.recover_source(sources[key],row),row);trim=base.local(row['trimmed_path'])
        if entry!=dict(expected_entry(row),runtime_sha256=proof['files'][entry['path']]['after_sha256']):raise ValueError('Runtime ownership changed')
        if owner.region(atlases[entry['path']],entry).tobytes()!=fixed.tobytes() or rgba(trim).tobytes()!=fixed.tobytes():raise ValueError('Original reconstruction failed')
        if proof['assets'][key]!=dict(trim_sha256=base.digest(trim),rgba_sha256=hashlib.sha256(fixed.tobytes()).hexdigest()):raise ValueError('Derived provenance changed')
    return {k:dict(ok=True,errors=[]) for k in recipe['assets']}


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--initialize',action='store_true');parser.add_argument('--output',type=Path);parser.add_argument('--install',action='store_true')
    args=parser.parse_args()
    if not args.initialize and not args.output:parser.error('--output required')
    print(json.dumps(initialize() if args.initialize else prepare(args.output,args.install)))
