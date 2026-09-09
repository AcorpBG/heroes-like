#!/usr/bin/env python3
"""Restore original recurring-site paint at 4x density, not 4x world size.

The first five retain their south anchor; the 25 later originals retain the
two-pixel south inset proven by exact reconstruction of former visible paint
and alpha (invisible RGB under zero alpha is not a painted-pixel constraint).
No source colors or alpha are removed. Claimed-state routing is never changed.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil

from PIL import Image,ImageDraw,ImageChops,ImageStat

ROOT=Path(__file__).resolve().parents[1]
PACKET=ROOT/'art/overworld/source/generated/cutout_recovery_20260909/recurring_sites'
RECIPE=PACKET/'recipe.json'
MANIFEST=ROOT/'art/overworld/manifest.json'
RUNTIME='res://art/overworld/runtime/objects/resource_sites/recurring_resource_site_landmarks_atlas.png'
ORIGINAL_SHA='6c7a4e6a83a5e92d14087fcbc42f251057f24bc8ab3c3e5573451c4dcbf78898'
SHARED=ROOT/'tools/prepare_overworld_recurring_cutouts.py'
spec=importlib.util.spec_from_file_location('recurring_source_recovery',SHARED)
shared=importlib.util.module_from_spec(spec);spec.loader.exec_module(shared)
base=shared.base;owner=shared.owner;recover=shared.recover;metrics=shared.metrics
BEFORE=PACKET/'before_runtime/objects/resource_sites/recurring_resource_site_landmarks_atlas.png'


def expected_entry(row):
    return dict(row['original_manifest_entry'],atlas_region=[v*4 for v in row['original_manifest_entry']['atlas_region']],
                atlas_size=[5760,192],source_trimmed=row['trimmed_path'],source_processing_manifest=base.resource(PACKET/'manifest.json'))


def registration(source,row,old):
    projection=recover(source,dict(row,canvas_size=[48,48],pixel_scale=1))
    delta=ImageChops.difference(old,projection)
    mask=ImageChops.multiply(old.getchannel('A').point(lambda a:255 if a>200 else 0),projection.getchannel('A').point(lambda a:255 if a>200 else 0))
    result=dict(alpha_mae=ImageStat.Stat(delta.getchannel('A')).mean[0],opaque_rgb_mae=sum(ImageStat.Stat(delta.convert('RGB'),mask).mean)/3)
    if row['original_manifest_entry']['atlas_region'][0]>=240:
        if old.getchannel('A').tobytes()!=projection.getchannel('A').tobytes() or any(a!=b and a[3]>0 for a,b in zip(old.getdata(),projection.getdata())):raise ValueError('Original inset registration changed')
    elif result['alpha_mae']>=1 or result['opaque_rgb_mae']>=1.4:raise ValueError('Original south registration changed')
    return result


def inputs():
    recipe=json.loads(RECIPE.read_text());manifest=json.loads(MANIFEST.read_text())
    proof=json.loads((PACKET/'manifest.json').read_text()) if (PACKET/'manifest.json').exists() else {}
    if recipe['schema_id']!='recurring_site_cutout_recipe_v1' or len(recipe['assets'])!=30 or recipe['preserved_controls']:raise ValueError('Cohort changed')
    members={k for k,v in manifest['object_assets'].items() if v['path']==RUNTIME}
    if members!=set(recipe['assets']):raise ValueError('Missing/extra atlas owner')
    if sorted(r['original_manifest_entry']['atlas_region'][0] for r in recipe['assets'].values())!=list(range(0,1440,48)):raise ValueError('Original regions changed')
    if set(recipe['state_mappings'])!={r['original_manifest_entry']['assigned_resource_site_id'] for r in recipe['assets'].values()}:raise ValueError('Incomplete site/state mapping controls')
    if any(manifest['resource_site_sprites'][k]!=v for k,v in recipe['state_mappings'].items()):raise ValueError('Site/state mapping changed')
    if base.digest(BEFORE if BEFORE.exists() else base.local(RUNTIME))!=ORIGINAL_SHA:raise ValueError('Original atlas changed')
    if base.digest(base.local(RUNTIME)) not in (ORIGINAL_SHA,proof.get('runtime_sha256')):raise ValueError('Unrecognized runtime edit')
    original=Image.open(BEFORE if BEFORE.exists() else base.local(RUNTIME)).convert('RGBA')
    sources={}
    for key,row in recipe['assets'].items():
        entry=manifest['object_assets'][key];old=row['original_manifest_entry']
        if {k:v for k,v in entry.items() if k!='runtime_sha256'} not in (old,expected_entry(row)):raise ValueError('Asset identity changed: '+key)
        if old['path']!=RUNTIME or row['runtime_path']!=RUNTIME or old['atlas_region'][1:]!=[0,48,48] or old['atlas_size']!=[1440,48]:raise ValueError('Unscoped atlas transform')
        path=base.local(old['source_generated'])
        if base.digest(path)!=row['source_sha256'] or row['before_sha256']!=ORIGINAL_SHA:raise ValueError('Source hash changed: '+key)
        source=Image.open(path).convert('RGBA');sources[key]=source
        if list(source.getbbox())!=row['source_crop']:raise ValueError('Source crop changed')
        w,h=row['source_resize'];x,y=row['canvas_origin'];later=old['atlas_region'][0]>=240
        crop=source.getbbox();cw,ch=crop[2]-crop[0],crop[3]-crop[1]
        if [w,h]!=[round(cw*44/max(cw,ch)),round(ch*44/max(cw,ch))] or [x,y]!=[(48-w)//2,(46 if later else 48)-h]:raise ValueError('Source fit/anchor changed')
        if row['resampling']!=('LANCZOS' if later else 'BILINEAR') or row['pixel_scale']!=4 or row['canvas_size']!=[192,192]:raise ValueError('Source density/filter changed')
        if base.local(row['trimmed_path'])!=ROOT/'art/overworld/source/trimmed/cutout_recovery_20260909/recurring_sites'/(key+'.png'):raise ValueError('Unscoped trim path')
        trim=base.local(row['trimmed_path'])
        if trim.exists() and base.digest(trim)!=proof.get('assets',{}).get(key,{}).get('trim_sha256'):raise ValueError('Unrecognized trim edit')
        measured=registration(source,row,owner.region(original,old))
        if any(row['registration_evidence'][k]!=v for k,v in measured.items()):raise ValueError('Registration evidence changed')
    return recipe,manifest,sources


def prepare(output,install=False):
    output=output.resolve()
    if output==ROOT.resolve() or output.is_relative_to((ROOT/'art').resolve()):raise ValueError('Preview must be outside art')
    recipe,manifest,sources=inputs();output.mkdir(parents=True,exist_ok=False)
    atlas=Image.new('RGBA',(5760,192));results={};rows={}
    for key,row in recipe['assets'].items():
        fixed=recover(sources[key],row);results[key]=fixed
        fixed.save(output/(key+'.png'),optimize=True)
        rows[key]=dict(trim_sha256=base.digest(output/(key+'.png')),rgba_sha256=hashlib.sha256(fixed.tobytes()).hexdigest(),metrics=metrics(fixed))
        atlas.paste(fixed,(row['original_manifest_entry']['atlas_region'][0]*4,0))
    target=output/'runtime/objects/resource_sites/recurring_resource_site_landmarks_atlas.png'
    target.parent.mkdir(parents=True,exist_ok=True);atlas.save(target,optimize=True)
    original=Image.open(BEFORE if BEFORE.exists() else base.local(RUNTIME)).convert('RGBA')
    for page in range(8):
        canvas=Image.new('RGB',(1320,600),'#334c3a');draw=ImageDraw.Draw(canvas)
        for j,(key,row) in enumerate(list(recipe['assets'].items())[page*4:page*4+4]):
            x,y=(j%2)*660,(j//2)*300
            for i,im in enumerate((owner.region(original,row['original_manifest_entry']),results[key],sources[key])):
                thumb=im.copy();thumb.thumbnail((216,216),Image.Resampling.LANCZOS)
                if i==0:thumb=im.resize((192,192),Image.Resampling.NEAREST)
                canvas.paste(thumb,(x+i*220,y),thumb)
            draw.text((x+5,y+228),key,fill='white');draw.text((x+5,y+246),'BEFORE / ORIGINAL SOURCE 192px / SOURCE | SAME WORLD FIT',fill='white')
        canvas.save(output/f'comparison_{page:02}.png')
    proof=dict(schema_id='recurring_site_cutout_recovery_v1',recipe_sha256=base.digest(RECIPE),processing_tool_sha256=base.digest(Path(__file__)),shared_tool_sha256=base.digest(SHARED),runtime_sha256=base.digest(target),original_sha256=ORIGINAL_SHA,assets=rows,processing='Original RGBA only, exact source crop and logical fit at 4x raster density; preserve original distinct south anchors. No color/alpha removal or gameplay/state rerouting.')
    if install:
        BEFORE.parent.mkdir(parents=True,exist_ok=True)
        if not BEFORE.exists():shutil.copy2(base.local(RUNTIME),BEFORE)
        for key,row in recipe['assets'].items():
            trim=base.local(row['trimmed_path']);trim.parent.mkdir(parents=True,exist_ok=True)
            shutil.copyfile(output/(key+'.png'),trim)
            manifest['object_assets'][key]=dict(expected_entry(row),runtime_sha256=proof['runtime_sha256'])
        shutil.copyfile(target,base.local(RUNTIME))
        MANIFEST.write_text(owner.manifest_text(manifest,recipe['assets']))
        (PACKET/'manifest.json').write_text(json.dumps(proof,indent=2)+'\n')
    (output/'report.json').write_text(json.dumps(proof,indent=2)+'\n')
    return proof


def validate_assets():
    recipe,manifest,sources=inputs();proof=json.loads((PACKET/'manifest.json').read_text())
    if proof['schema_id']!='recurring_site_cutout_recovery_v1' or proof['recipe_sha256']!=base.digest(RECIPE) or proof['processing_tool_sha256']!=base.digest(Path(__file__)) or proof['shared_tool_sha256']!=base.digest(SHARED):raise ValueError('Preparation provenance changed')
    if set(proof['assets'])!=set(recipe['assets']) or proof['original_sha256']!=ORIGINAL_SHA or base.digest(BEFORE)!=ORIGINAL_SHA:raise ValueError('Source proof changed')
    atlas=Image.open(base.local(RUNTIME)).convert('RGBA')
    if atlas.size!=(5760,192) or proof['runtime_sha256']!=base.digest(base.local(RUNTIME)):raise ValueError('Runtime atlas changed')
    reports={}
    for key,row in recipe['assets'].items():
        expected=recover(sources[key],row);entry=manifest['object_assets'][key]
        if entry!=dict(expected_entry(row),runtime_sha256=proof['runtime_sha256']):raise ValueError('Runtime ownership changed: '+key)
        trim=base.local(row['trimmed_path']);paint=Image.open(trim).convert('RGBA')
        if paint.size!=(192,192) or paint.tobytes()!=expected.tobytes() or owner.region(atlas,entry).tobytes()!=expected.tobytes():raise ValueError('Original paint changed: '+key)
        if proof['assets'][key]!=dict(trim_sha256=base.digest(trim),rgba_sha256=hashlib.sha256(expected.tobytes()).hexdigest(),metrics=metrics(expected)):raise ValueError('Paint proof changed: '+key)
        reports[key]=dict(ok=True,errors=[])
    return reports


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True);parser.add_argument('--install',action='store_true')
    args=parser.parse_args();proof=prepare(args.output,args.install)
    print(json.dumps(dict(assets=len(proof['assets']),runtime_sha256=proof['runtime_sha256'],installed=args.install)))
