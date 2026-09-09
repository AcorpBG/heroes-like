#!/usr/bin/env python3
"""Restore source-backed smooth coverage lost in the recurring encounter atlas.

Original painting/crop/canvas registration is explicit per identity. No color
key, binary-alpha threshold, shared replacement, or runtime geometry is used.
The first six and final seven retain their distinct bottom-aligned registrations;
the middle eighteen remain centered. A 192-pixel atlas supplies paint detail
without changing world draw rectangles. Historical and first-24 art stay exact.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil

from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[1]
PACKET=ROOT/'art/overworld/source/generated/cutout_recovery_20260909/recurring_encounters'
RECIPE=PACKET/'recipe.json'
MANIFEST=ROOT/'art/overworld/manifest.json'
RUNTIME='res://art/overworld/runtime/objects/encounters/recurring/recurring_encounter_recovered_atlas.png'
_spec=importlib.util.spec_from_file_location('recurring_manifest_owner',ROOT/'tools/prepare_overworld_legacy_cutouts.py')
owner=importlib.util.module_from_spec(_spec);_spec.loader.exec_module(owner)
base=owner.base


def before_path(entry):
    return PACKET/'before_runtime'/base.local(entry['path']).relative_to(ROOT/'art/overworld/runtime')


def original(entry):
    path=before_path(entry)
    return Image.open(path if path.exists() else base.local(entry['path'])).convert('RGBA')


def recover(source,row):
    """Reproject original RGBA; never infer transparency from its painted colors."""
    canvas=Image.new('RGBA',tuple(row['canvas_size']))
    scale=row['pixel_scale']
    thumb=source.crop(row['source_crop']).resize(tuple(v*scale for v in row['source_resize']),getattr(Image.Resampling,row['resampling']))
    canvas.paste(thumb,tuple(v*scale for v in row['canvas_origin']))
    return canvas


def expected_entry(row):
    x,y,w,h=row['original_manifest_entry']['atlas_region']
    return dict(row['original_manifest_entry'],path=RUNTIME,
                atlas_region=[v*4 for v in (x,y,w,h)],atlas_size=[5952,192],source_trimmed=row['trimmed_path'],
                source_processing_manifest=base.resource(PACKET/'manifest.json'))


def inputs():
    recipe=json.loads(RECIPE.read_text());manifest=json.loads(MANIFEST.read_text())
    proof=json.loads((PACKET/'manifest.json').read_text()) if (PACKET/'manifest.json').exists() else {}
    if recipe.get('schema_id')!='recurring_cutout_recipe_v3':raise ValueError('Unknown recurring recipe')
    if len(recipe['assets'])!=31 or recipe['preserved_controls']:raise ValueError('Cohort membership changed')
    sources={};paths=set()
    for key,row in recipe['assets'].items():
        entry=manifest['object_assets'][key];original_entry=row['original_manifest_entry'];paths.add(original_entry['path'])
        candidate={k:v for k,v in entry.items() if k!='runtime_sha256'}
        allowed=(original_entry,expected_entry(row))
        if proof.get('schema_id')=='recurring_cutout_recovery_v2' and original_entry['atlas_region'][0]<1152:
            allowed+=(dict(expected_entry(row),atlas_size=[4608,192]),)
        if candidate not in allowed:raise ValueError('Identity/region changed: '+key)
        source_path=base.local(row['original_manifest_entry']['source_generated'])
        if base.digest(source_path)!=row['source_sha256']:raise ValueError('Original painting hash changed: '+key)
        source=Image.open(source_path).convert('RGBA');sources[key]=source
        later=original_entry['atlas_region'][0]>=1152
        threshold=row.get('source_crop_alpha_threshold',0)
        if threshold not in ((4,8) if later else (0,)):raise ValueError('Unapproved crop support threshold')
        # Support threshold selects bounds only, never changes source pixels.
        bounds=source.getchannel('A').point(lambda a:255 if a>threshold else 0).getbbox()
        if list(bounds)!=row['source_crop']:raise ValueError('Original source crop changed: '+key)
        w,h=row['source_resize'];x,y=row['canvas_origin']
        fit=42 if later else 44
        if row.get('fit_limit',44)!=fit or not all(type(v) is int for v in (x,y,w,h)) or max(w,h)!=fit or not (0<=x<x+w<=48 and 0<=y<y+h<=48):raise ValueError('Unscoped canvas transform')
        if later and (x!=(48-w)//2 or y!=48-h):raise ValueError('Later-wave anchor changed')
        sx,sy,ex,ey=row['source_crop'];ratio=fit/max(ex-sx,ey-sy)
        if abs(w-(ex-sx)*ratio)>1 or abs(h-(ey-sy)*ratio)>1:raise ValueError('Distorted source fit')
        if row['resampling'] not in ('BICUBIC','BILINEAR'):raise ValueError('Unapproved resampling')
        if row['canvas_size']!=[192,192] or row['pixel_scale']!=4 or row['runtime_path']!=RUNTIME:raise ValueError('Unapproved raster resolution/path')
        if manifest['encounter_identity_sprites'][entry['assigned_encounter_id']]!=key:raise ValueError('Encounter route changed')
        old=before_path(original_entry)
        if base.digest(old if old.exists() else base.local(original_entry['path']))!=row['before_sha256']:raise ValueError('Original atlas hash changed')
        original_path=original_entry['path']
        if base.digest(base.local(original_path))!=row['before_sha256']:raise ValueError('Unrelated original atlas edit')
        if base.digest(base.local(entry['path'])) not in (row['before_sha256'],proof.get('files',{}).get(entry['path'],{}).get('after_sha256')):raise ValueError('Unrecognized runtime edit')
        trim=ROOT/'art/overworld/source/trimmed/cutout_recovery_20260909/recurring_encounters'/(key+'.png')
        if base.local(row['trimmed_path'])!=trim:raise ValueError('Unscoped trim path')
        if trim.exists() and base.digest(trim)!=proof.get('assets',{}).get(key,{}).get('trim_sha256'):raise ValueError('Unrecognized prepared art edit')
    if len(paths)!=1:raise ValueError('Atlas scope changed')
    members={k for k,v in manifest['object_assets'].items() if v['path'] in paths|{RUNTIME}}
    if members!=set(recipe['assets'])|set(recipe['preserved_controls']):raise ValueError('Incomplete atlas membership')
    prior=recipe['prior_checkpoint']
    for name in ('recipe','manifest'):
        expected=PACKET/'prior_24_checkpoint'/(name+'.json')
        if base.local(prior[name+'_path'])!=expected or base.digest(expected)!=prior[name+'_sha256']:raise ValueError('Prior checkpoint changed')
    old_recipe=json.loads(base.local(prior['recipe_path']).read_text())
    if len(old_recipe['assets'])!=24 or set(recipe['assets'])!=set(old_recipe['assets'])|set(old_recipe['preserved_controls']):raise ValueError('Prior membership changed')
    if any(recipe['assets'][k]!=v for k,v in old_recipe['assets'].items()):raise ValueError('Accepted source registration changed')
    retained=base.local(prior['runtime_path'])
    if retained!=before_path({'path':RUNTIME}):raise ValueError('Unscoped prior atlas path')
    if base.digest(retained if retained.exists() else base.local(RUNTIME))!=prior['runtime_sha256']:raise ValueError('Prior recovered atlas changed')
    return recipe,manifest,sources


def metrics(image):
    alpha=list(image.getchannel('A').getdata())
    return dict(alpha_levels=len(set(alpha)),partial_alpha_pixels=sum(0<a<255 for a in alpha),bounds=list(image.getbbox()))


def prepare(output,install=False):
    output=output.resolve()
    if output==ROOT.resolve() or output.is_relative_to((ROOT/'art').resolve()):raise ValueError('Preview must be outside art')
    recipe,manifest,sources=inputs();output.mkdir(parents=True,exist_ok=False)
    first=next(iter(recipe['assets'].values()))['original_manifest_entry']
    atlas=Image.new('RGBA',(5952,192));rows={};results={}
    for key,row in recipe['assets'].items():
        fixed=recover(sources[key],row);results[key]=fixed
        fixed.save(output/(key+'.png'),optimize=True)
        rows[key]=dict(trim_sha256=base.digest(output/(key+'.png')),rgba_sha256=hashlib.sha256(fixed.tobytes()).hexdigest(),metrics=metrics(fixed))
        x,y,_,_=expected_entry(row)['atlas_region'];atlas.paste(fixed,(x,y))
    path=RUNTIME;target=output/'runtime'/base.local(path).relative_to(ROOT/'art/overworld/runtime')
    target.parent.mkdir(parents=True,exist_ok=True);atlas.save(target,optimize=True)
    old=before_path(first)
    original_proof=dict(path=first['path'],sha256=base.digest(old if old.exists() else base.local(first['path'])))
    files={path:dict(after_sha256=base.digest(target),prepared=str(target.relative_to(output)))}
    for page in range(8):
        canvas=Image.new('RGB',(1320,600),'#334c3a');draw=ImageDraw.Draw(canvas)
        for j,(key,row) in enumerate(list(recipe['assets'].items())[page*4:page*4+4]):
            x,y=(j%2)*660,(j//2)*300
            before=owner.region(original(row['original_manifest_entry']),row['original_manifest_entry'])
            for col,image in enumerate((before,results[key])):
                thumb=image.resize((192,192),Image.Resampling.NEAREST);canvas.paste(thumb,(x+col*212,y+8),thumb)
            thumb=sources[key].copy();thumb.thumbnail((216,216),Image.Resampling.LANCZOS);canvas.paste(thumb,(x+430,y),thumb)
            draw.text((x+5,y+228),key,fill='white');draw.text((x+5,y+246),'BEFORE / 192px SOURCE RECOVERY / ORIGINAL | unchanged world fit',fill='white')
        canvas.save(output/f'comparison_{page:02}.png')
    prior=recipe['prior_checkpoint']
    prior_proof=json.loads(base.local(prior['manifest_path']).read_text())
    for key,value in prior_proof['assets'].items():
        if rows[key]!=value:raise ValueError('Accepted painting pixels changed: '+key)
    proof=dict(schema_id='recurring_cutout_recovery_v3',recipe_sha256=base.digest(RECIPE),
        processing_tool='tools/prepare_overworld_recurring_cutouts.py',processing_tool_sha256=base.digest(Path(__file__)),
        processing='Reproject original RGBA at 4x raster resolution through unchanged normalized source fit and canvas registration. Later-wave support thresholds select crop bounds only; all source pixels within remain intact. Entire original atlas and accepted first-24 painting pixels retained exactly; renderer world draw rectangles unchanged.',
        assets=rows,files=files,original_atlas=original_proof,preserved_controls={},prior_checkpoint=prior)
    if install:
        for key,row in recipe['assets'].items():manifest['object_assets'][key]=dict(expected_entry(row),runtime_sha256=files[path]['after_sha256'])
        text=owner.manifest_text(manifest,recipe['assets'])
        old.parent.mkdir(parents=True,exist_ok=True)
        if not old.exists():shutil.copy2(base.local(first['path']),old)
        retained=base.local(prior['runtime_path']);retained.parent.mkdir(parents=True,exist_ok=True)
        if not retained.exists():shutil.copy2(base.local(path),retained)
        shutil.copyfile(old,base.local(first['path']))
        shutil.copyfile(target,base.local(path))
        for key,row in recipe['assets'].items():
            trim=base.local(row['trimmed_path']);trim.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(output/(key+'.png'),trim)
        (PACKET/'manifest.json').write_text(json.dumps(proof,indent=2)+'\n');MANIFEST.write_text(text)
    (output/'report.json').write_text(json.dumps(dict(installed=install,**proof),indent=2)+'\n')
    return dict(installed=install,assets=len(rows),runtime_files=1)


def validate_assets():
    recipe,manifest,sources=inputs();proof=json.loads((PACKET/'manifest.json').read_text())
    if proof['schema_id']!='recurring_cutout_recovery_v3' or proof['recipe_sha256']!=base.digest(RECIPE) or proof['processing_tool_sha256']!=base.digest(Path(__file__)):raise ValueError('Preparation provenance changed')
    if set(proof['assets'])!=set(recipe['assets']) or proof['preserved_controls']!=recipe['preserved_controls']:raise ValueError('Cohort proof changed')
    reports={}
    for key,row in recipe['assets'].items():
        fixed=recover(sources[key],row);entry=manifest['object_assets'][key];trim=base.local(row['trimmed_path'])
        if entry!=dict(expected_entry(row),runtime_sha256=base.digest(base.local(entry['path']))):raise ValueError('Runtime provenance mismatch')
        if owner.region(Image.open(base.local(entry['path'])).convert('RGBA'),entry).tobytes()!=fixed.tobytes():raise ValueError('Reconstruction mismatch: '+key)
        if Image.open(trim).convert('RGBA').tobytes()!=fixed.tobytes() or base.digest(trim)!=proof['assets'][key]['trim_sha256']:raise ValueError('Prepared art mismatch')
        if proof['assets'][key]['metrics']!=metrics(fixed):raise ValueError('Source coverage proof mismatch')
        if proof['assets'][key]['rgba_sha256']!=hashlib.sha256(fixed.tobytes()).hexdigest():raise ValueError('Raster proof mismatch')
        if metrics(fixed)['alpha_levels']<64:raise ValueError('Smooth source coverage lost')
        reports[key]={'ok':True,'errors':[]}
    if set(proof['files'])!={RUNTIME}:raise ValueError('Unexpected atlas proof membership')
    for path,info in proof['files'].items():
        if base.digest(base.local(path))!=info['after_sha256']:raise ValueError('Atlas proof mismatch')
    old=proof['original_atlas']
    first=next(iter(recipe['assets'].values()))
    if old!={'path':first['original_manifest_entry']['path'],'sha256':first['before_sha256']}:raise ValueError('Original proof changed')
    if base.digest(base.local(old['path']))!=old['sha256']:raise ValueError('Original atlas changed')
    if proof['prior_checkpoint']!=recipe['prior_checkpoint']:raise ValueError('Prior checkpoint provenance changed')
    prior_proof=json.loads(base.local(recipe['prior_checkpoint']['manifest_path']).read_text())
    prior_atlas=Image.open(base.local(recipe['prior_checkpoint']['runtime_path'])).convert('RGBA')
    current=Image.open(base.local(RUNTIME)).convert('RGBA')
    if current.size!=(5952,192) or current.crop((0,0,4608,192)).tobytes()!=prior_atlas.tobytes():raise ValueError('Accepted atlas pixels changed')
    if any(proof['assets'][k]!=v for k,v in prior_proof['assets'].items()):raise ValueError('Accepted source derivatives changed')
    return reports


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path,required=True);parser.add_argument('--install',action='store_true')
    args=parser.parse_args();print(json.dumps(prepare(args.output,args.install)))
