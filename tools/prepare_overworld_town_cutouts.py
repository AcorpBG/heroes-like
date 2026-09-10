#!/usr/bin/env python3
"""Restore eleven original Town silhouettes, preserving 28 reviewed mappings.

Offline original-art packaging only. No new paint, alpha key or world resizing.
Historical 120/112px centered fits are frozen against the retained atlas pixels.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil

from PIL import Image, ImageChops, ImageDraw, ImageStat

ROOT=Path(__file__).resolve().parents[1]
PACKET=ROOT/'art/overworld/source/generated/cutout_recovery_20260909/towns'
RECIPE=PACKET/'recipe.json'
MANIFEST=ROOT/'art/overworld/manifest.json'
spec=importlib.util.spec_from_file_location('town_originals',ROOT/'tools/prepare_overworld_contract_cutouts.py')
shared=importlib.util.module_from_spec(spec);spec.loader.exec_module(shared)
base=shared.base;owner=shared.owner;project=shared.project
MAPPING_KEYS=('town_identity_sprites','town_faction_sprites','town_default_sprite')


def rgba(path):
    with Image.open(path) as opened:return opened.convert('RGBA')


def members(manifest):
    ids={manifest['town_default_sprite']['asset_id'],*manifest['town_faction_sprites'].values(),*manifest['town_identity_sprites'].values()}
    return {k:v for k,v in manifest['object_assets'].items() if k in ids}


def before_path(path):return PACKET/'before_runtime'/base.local(path).relative_to(ROOT/'art/overworld/runtime')


def original(path):return rgba(before_path(path) if before_path(path).exists() else base.local(path))


def transform(source,entry):
    limit=120 if Path(entry['path']).stem=='third_hearths_atlas' else 112
    crop=list(source.getchannel('A').getbbox());width,height=source.crop(crop).size
    ratio=limit/max(width,height);fit=[round(width*ratio),round(height*ratio)]
    return dict(source_crop=crop,source_resize=fit,canvas_origin=[(128-v)//2 for v in fit],
                canvas_size=[512,512],pixel_scale=4,resampling='LANCZOS')


def registration(source,row,old):
    # Bilinear comparison matches the old low-density image closely. The new
    # raster uses Lanczos at 4x density, not a nearest-neighbor enlargement.
    projected=project(source,dict(row,canvas_size=[128,128],pixel_scale=1,resampling='BILINEAR'))
    diff=ImageChops.difference(old,projected)
    mask=ImageChops.multiply(old.getchannel('A').point(lambda a:255 if a>200 else 0),projected.getchannel('A').point(lambda a:255 if a>200 else 0))
    result=dict(alpha_mae=ImageStat.Stat(diff.getchannel('A')).mean[0],opaque_rgb_mae=sum(ImageStat.Stat(diff.convert('RGB'),mask).mean)/3)
    if result['alpha_mae']>0.7 or result['opaque_rgb_mae']>1.5:raise ValueError('Historical Town registration changed')
    return result


def expected_entry(row):
    old=row['original_manifest_entry']
    if row['mode']=='preserved_town':return old
    return dict(old,atlas_region=[v*4 for v in old['atlas_region']],atlas_size=[v*4 for v in old['atlas_size']],
                source_trimmed=row['trimmed_path'],source_processing_manifest=base.resource(PACKET/'manifest.json'))


def initialize():
    if RECIPE.exists():raise ValueError('Never overwrite a frozen recipe')
    manifest=json.loads(MANIFEST.read_text());selected=members(manifest)
    if len(selected)!=39:raise ValueError('Incomplete Town cohort')
    assets={};files={}
    for key,entry in selected.items():
        path=entry['path'];repair='atlas_region' in entry
        sources={}
        for field in ('source_generated','source_atlas','source_trimmed','scenic_source'):
            if field in entry:
                source=ROOT/entry[field].removeprefix('res://');sources[entry[field]]=base.digest(source)
                if (source.parent/'manifest.json').exists():sources[base.resource(source.parent/'manifest.json')]=base.digest(source.parent/'manifest.json')
        row=dict(original_manifest_entry=entry,runtime_path=path,mode='town_atlas' if repair else 'preserved_town',
                 canvas_size=[512,512],source_hashes=sources,before_sha256=base.digest(base.local(path)))
        if repair:
            source=rgba(base.local(entry['source_generated']));row.update(transform(source,entry))
            row.update(source_size=list(source.size),source_alpha_sha256=hashlib.sha256(source.getchannel('A').tobytes()).hexdigest(),
                       low_alpha_rgb_pixels=int(shared.noise_mask(source).sum()),
                       trimmed_path=base.resource(ROOT/'art/overworld/source/trimmed/cutout_recovery_20260909/towns'/(key+'.png')))
            row['historical_registration']=registration(source,row,owner.region(original(path),entry))
            files[path]=dict(before_size=list(original(path).size),before_sha256=row['before_sha256'])
        assets[key]=row
    if len(files)!=2 or sum(r['mode']=='town_atlas' for r in assets.values())!=11:raise ValueError('Unexpected Town atlas scope')
    recipe=dict(schema_id='town_cutout_recipe_v1',baseline_commit='156145059de8b9ef127bfd88904db82e4a60358d',assets=assets,files=files,
                mappings={k:manifest[k] for k in MAPPING_KEYS})
    PACKET.mkdir(parents=True,exist_ok=True);RECIPE.write_text(json.dumps(recipe,indent=2)+'\n')
    return dict(dispositions=39,repairs=11,preserved=28,atlases=2)


def inputs():
    recipe=json.loads(RECIPE.read_text());manifest=json.loads(MANIFEST.read_text())
    proof=json.loads((PACKET/'manifest.json').read_text()) if (PACKET/'manifest.json').exists() else {}
    selected=members(manifest)
    if recipe['schema_id']!='town_cutout_recipe_v1' or len(selected)!=39 or set(selected)!=set(recipe['assets']):raise ValueError('Town cohort changed')
    if recipe['mappings']!={k:manifest[k] for k in MAPPING_KEYS}:raise ValueError('Town identity/faction/default routes changed')
    for path,info in recipe['files'].items():
        prior=before_path(path) if before_path(path).exists() else base.local(path)
        if base.digest(prior)!=info['before_sha256'] or list(original(path).size)!=info['before_size']:raise ValueError('Historical Town atlas changed')
        if base.digest(base.local(path)) not in (info['before_sha256'],proof.get('files',{}).get(path,{}).get('after_sha256')):raise ValueError('Unrecognized runtime edit')
        regions=sorted(r['original_manifest_entry']['atlas_region'] for r in recipe['assets'].values() if r['runtime_path']==path)
        if regions!=[[i,0,128,128] for i in range(0,info['before_size'][0],128)]:raise ValueError('Incomplete atlas coverage')
    sources={}
    for key,row in recipe['assets'].items():
        old=row['original_manifest_entry'];entry=selected[key]
        for path,sha in row['source_hashes'].items():
            if base.digest(ROOT/path.removeprefix('res://'))!=sha:raise ValueError('Original Town painting/provenance changed')
        if row['runtime_path']!=old['path']:raise ValueError('Town path changed')
        if row['mode']=='preserved_town':
            if entry!=old or base.digest(base.local(old['path']))!=row['before_sha256']:raise ValueError('Preserved Town changed')
            continue
        if row['mode']!='town_atlas' or old['path'] not in recipe['files']:raise ValueError('Unscoped Town repair')
        strip=lambda v:{k:value for k,value in v.items() if k!='runtime_sha256'}
        if strip(entry) not in (strip(old),strip(expected_entry(row))):raise ValueError('Town identity metadata changed')
        source=rgba(base.local(old['source_generated']));sources[key]=source
        if list(source.size)!=row['source_size'] or hashlib.sha256(source.getchannel('A').tobytes()).hexdigest()!=row['source_alpha_sha256']:raise ValueError('Original Town alpha changed')
        if any(row[k]!=v for k,v in transform(source,old).items()):raise ValueError('Town crop/scale/anchor changed')
        if int(shared.noise_mask(source).sum())!=row['low_alpha_rgb_pixels']:raise ValueError('Reviewed low-alpha RGB changed')
        if registration(source,row,owner.region(original(old['path']),old))!=row['historical_registration']:raise ValueError('Registration proof changed')
        trim=ROOT/'art/overworld/source/trimmed/cutout_recovery_20260909/towns'/(key+'.png')
        if base.local(row['trimmed_path'])!=trim:raise ValueError('Unscoped Town derivative')
        if trim.exists() and base.digest(trim)!=proof.get('assets',{}).get(key,{}).get('trim_sha256'):raise ValueError('Unrecognized Town derivative edit')
    return recipe,manifest,sources


def tool_hashes():return dict(shared.tool_hashes(),**{str(Path(__file__).relative_to(ROOT)):base.digest(Path(__file__))})


def prepare(output,install=False):
    output=output.resolve()
    if output==ROOT.resolve() or output.is_relative_to((ROOT/'art').resolve()):raise ValueError('Preview outside source art required')
    recipe,manifest,sources=inputs();output.mkdir(parents=True,exist_ok=False)
    canvases={p:Image.new('RGBA',tuple(v*4 for v in info['before_size'])) for p,info in recipe['files'].items()}
    results={};rows={};files={}
    for key,source in sources.items():
        row=recipe['assets'][key];fixed=project(shared.recover_source(source,row),row);results[key]=fixed
        fixed.save(output/(key+'.png'),optimize=True)
        rows[key]=dict(rgba_sha256=hashlib.sha256(fixed.tobytes()).hexdigest(),trim_sha256=base.digest(output/(key+'.png')))
        canvases[row['runtime_path']].paste(fixed,tuple(expected_entry(row)['atlas_region'][:2]))
    for path,canvas in canvases.items():
        dest=output/'runtime'/base.local(path).relative_to(ROOT/'art/overworld/runtime');dest.parent.mkdir(parents=True,exist_ok=True);canvas.save(dest,optimize=True)
        files[path]=dict(after_sha256=base.digest(dest),prepared=str(dest.relative_to(output)))
    for key,row in recipe['assets'].items():
        if row['mode']=='preserved_town':
            dest=output/'runtime'/base.local(row['runtime_path']).relative_to(ROOT/'art/overworld/runtime');dest.parent.mkdir(parents=True,exist_ok=True)
            shutil.copyfile(base.local(row['runtime_path']),dest)
    for page,(key,fixed) in enumerate(results.items()):
        row=recipe['assets'][key];canvas=Image.new('RGB',(1536,550),'#334c3a');draw=ImageDraw.Draw(canvas)
        old=owner.region(original(row['runtime_path']),row['original_manifest_entry'])
        for col,pic in enumerate((old.resize((512,512),Image.Resampling.NEAREST),old.resize((512,512),Image.Resampling.BILINEAR),fixed)):
            canvas.paste(pic,(col*512,30),pic)
        draw.text((4,4),key+' | OLD nearest / OLD bilinear / ORIGINAL 512 (same world registration)',fill='white')
        canvas.save(output/f'comparison_{page:02}.png')
    proof=dict(schema_id='town_cutout_recovery_v1',recipe_sha256=base.digest(RECIPE),tools=tool_hashes(),assets=rows,files=files,
               processing='Eleven original Town paintings at fourfold atlas density; historical centered 120/112px fits retained. Original alpha and all non-noise RGB preserved. Reviewed alpha 1..4 saturated RGB alone borrows original foreground RGB. Twenty-eight exact Town identity/faction/default controls unchanged. No generated paint or gameplay change.')
    if install:
        for path,info in files.items():
            archive=before_path(path);archive.parent.mkdir(parents=True,exist_ok=True)
            if not archive.exists():shutil.copy2(base.local(path),archive)
            shutil.copyfile(output/info['prepared'],base.local(path))
        for key in results:
            row=recipe['assets'][key];dest=base.local(row['trimmed_path']);dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(output/(key+'.png'),dest)
            manifest['object_assets'][key]=dict(expected_entry(row),runtime_sha256=files[row['runtime_path']]['after_sha256'])
        MANIFEST.write_text(owner.manifest_text(manifest,results));(PACKET/'manifest.json').write_text(json.dumps(proof,indent=2)+'\n')
    (output/'report.json').write_text(json.dumps(proof,indent=2)+'\n')
    return dict(installed=install,dispositions=39,repairs=11,preserved=28,atlases=2)


def validate_assets():
    recipe,manifest,sources=inputs();proof=json.loads((PACKET/'manifest.json').read_text())
    if proof['schema_id']!='town_cutout_recovery_v1' or proof['recipe_sha256']!=base.digest(RECIPE) or proof['tools']!=tool_hashes():raise ValueError('Town preparation provenance changed')
    if set(proof['assets'])!=set(sources) or set(proof['files'])!=set(recipe['files']):raise ValueError('Incomplete Town proof')
    atlases={p:rgba(base.local(p)) for p in recipe['files']}
    for path,atlas in atlases.items():
        if list(atlas.size)!=[v*4 for v in recipe['files'][path]['before_size']] or base.digest(base.local(path))!=proof['files'][path]['after_sha256']:raise ValueError('Town atlas changed')
    for key,source in sources.items():
        row=recipe['assets'][key];entry=manifest['object_assets'][key];fixed=project(shared.recover_source(source,row),row);trim=base.local(row['trimmed_path'])
        if entry!=dict(expected_entry(row),runtime_sha256=proof['files'][entry['path']]['after_sha256']):raise ValueError('Town runtime ownership changed')
        if owner.region(atlases[entry['path']],entry).tobytes()!=fixed.tobytes() or rgba(trim).tobytes()!=fixed.tobytes():raise ValueError('Town source reconstruction failed')
        if proof['assets'][key]!=dict(trim_sha256=base.digest(trim),rgba_sha256=hashlib.sha256(fixed.tobytes()).hexdigest()):raise ValueError('Town derived provenance changed')
    return {k:dict(ok=True,errors=[]) for k in recipe['assets']}


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--initialize',action='store_true');parser.add_argument('--output',type=Path);parser.add_argument('--install',action='store_true')
    args=parser.parse_args()
    if not args.initialize and not args.output:parser.error('--output required')
    print(json.dumps(initialize() if args.initialize else prepare(args.output,args.install)))
