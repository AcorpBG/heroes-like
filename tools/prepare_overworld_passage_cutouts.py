#!/usr/bin/env python3
"""Recover only inspected enclosed backing in original resource-state paintings.

Each source-connected component has an explicit seed, area and bounds. White
snow, canvas, wind, glints and flowers are NOT a global removal class. Existing
foreground pixels outside the projected repair support remain byte-identical.
"""
import argparse
import importlib.util
import json
from pathlib import Path
import shutil

from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[1]
PACKET=ROOT/'art/overworld/source/generated/cutout_recovery_20260909/passages'
RECIPE=PACKET/'recipe.json'
MANIFEST=ROOT/'art/overworld/manifest.json'
_spec=importlib.util.spec_from_file_location('passage_manifest_owner',ROOT/'tools/prepare_overworld_legacy_cutouts.py')
owner=importlib.util.module_from_spec(_spec);_spec.loader.exec_module(owner)
base=owner.base


def before_path(entry):
    return PACKET/'before_runtime'/base.local(entry['path']).relative_to(ROOT/'art/overworld/runtime')


def original(entry):
    path=before_path(entry)
    return Image.open(path if path.exists() else base.local(entry['path'])).convert('RGBA')


def component(source, spec, valid=None):
    """Four-connected neutral backing, selected by an inspected source seed."""
    w,h=source.size
    if valid is None:
        valid=[a>0 and min(r,g,b)>=230 and max(r,g,b)-min(r,g,b)<=15 for r,g,b,a in source.getdata()]
    x,y=spec['seed']
    if not (type(x) is int and type(y) is int and 0<=x<w and 0<=y<h and valid[y*w+x]):
        raise ValueError('Seed is not verified source backing')
    pending=[y*w+x];seen={y*w+x}
    while pending:
        i=pending.pop();x,y=i%w,i//w
        for j in (i-1 if x else -1,i+1 if x<w-1 else -1,i-w if y else -1,i+w if y<h-1 else -1):
            if j>=0 and valid[j] and j not in seen:seen.add(j);pending.append(j)
    xs=[i%w for i in seen];ys=[i//w for i in seen]
    if len(seen)!=spec['area'] or [min(xs),min(ys),max(xs)+1,max(ys)+1]!=spec['bounds']:
        raise ValueError('Backing component no longer matches inspected bounds/area')
    return seen


def recover_source(source,row):
    pixels=list(source.getdata());selected=set()
    valid=[a>0 and min(r,g,b)>=230 and max(r,g,b)-min(r,g,b)<=15 for r,g,b,a in pixels]
    for spec in row['backing_components']:
        points=component(source,spec,valid)
        if points & selected:raise ValueError('Duplicate source component')
        selected.update(points)
    for i in selected:pixels[i]=(0,0,0,0)
    fixed=Image.new('RGBA',source.size);fixed.putdata(pixels)
    if fixed.getbbox()!=source.getbbox():raise ValueError('Enclosed repair changed external source bounds')
    return fixed,selected


def registered(source,row):
    canvas=Image.new('RGBA',(48,48))
    canvas.paste(source.crop(row['source_crop']).resize(tuple(row['source_resize']),Image.Resampling.BILINEAR),tuple(row['canvas_origin']))
    return canvas


def recover(source,row):
    fixed,points=recover_source(source,row)
    a=registered(source,row);b=registered(fixed,row)
    mask=Image.new('L',(48,48));mask.putdata([255 if p!=q else 0 for p,q in zip(a.getdata(),b.getdata())])
    before=owner.region(original(row['original_manifest_entry']),row['original_manifest_entry'])
    result=before.copy();result.paste(b,(0,0),mask)
    if result.getbbox()!=before.getbbox():raise ValueError('Original canvas registration changed')
    return result,fixed,mask,dict(source_removed_pixels=len(points),runtime_affected_pixels=sum(bool(v) for v in mask.getdata()))


def expected_entry(row):
    return dict(row['original_manifest_entry'],source_trimmed=row['trimmed_path'],
                source_processing_manifest=base.resource(PACKET/'manifest.json'))


def inputs():
    recipe=json.loads(RECIPE.read_text());manifest=json.loads(MANIFEST.read_text())
    proof=json.loads((PACKET/'manifest.json').read_text()) if (PACKET/'manifest.json').exists() else {}
    if recipe.get('schema_id')!='passage_cutout_recipe_v1':raise ValueError('Unknown passage recipe')
    sources={};paths=set()
    for key,row in recipe['assets'].items():
        entry=manifest['object_assets'][key];paths.add(entry['path'])
        candidate={k:v for k,v in entry.items() if k!='runtime_sha256'}
        if candidate not in (row['original_manifest_entry'],expected_entry(row)):raise ValueError('Identity/region changed: '+key)
        path=base.local(row['original_manifest_entry']['source_generated'])
        if base.digest(path)!=row['source_sha256']:raise ValueError('Original source hash changed: '+key)
        source=Image.open(path).convert('RGBA');sources[key]=source
        if list(source.getbbox())!=row['source_crop']:raise ValueError('Original source crop changed: '+key)
        if row['canvas_size']!=[48,48] or len(row['source_resize'])!=2 or len(row['canvas_origin'])!=2:raise ValueError('Unsupported canvas')
        w,h=row['source_resize'];x,y=row['canvas_origin']
        if not all(type(v) is int for v in (x,y,w,h)) or not (0<=x<x+w<=48 and 0<=y<y+h<=48):raise ValueError('Clipped transform')
        old=before_path(entry)
        if base.digest(old if old.exists() else base.local(entry['path']))!=row['before_sha256']:raise ValueError('Original atlas hash changed')
        if base.digest(base.local(entry['path'])) not in (row['before_sha256'],proof.get('files',{}).get(entry['path'],{}).get('after_sha256')):raise ValueError('Unrecognized runtime edit')
        trim=ROOT/'art/overworld/source/trimmed/cutout_recovery_20260909/passages'
        if base.local(row['trimmed_path'])!=trim/(key+'.png') or base.local(row['recovered_source_path'])!=trim/'sources'/(key+'.png'):raise ValueError('Unscoped trim path')
        for field,proof_field in [('trimmed_path','trim_sha256'),('recovered_source_path','recovered_source_sha256')]:
            dest=base.local(row[field])
            if dest.exists() and base.digest(dest)!=proof.get('assets',{}).get(key,{}).get(proof_field):raise ValueError('Unrecognized prepared source edit')
    members={k for k,v in manifest['object_assets'].items() if v['path'] in paths}
    if members!=set(recipe['assets'])|set(recipe['preserved_controls']):raise ValueError('Incomplete atlas membership')
    for key,row in recipe['preserved_controls'].items():
        entry=manifest['object_assets'][key]
        if entry!=row['original_manifest_entry']:raise ValueError('Unrelated control metadata changed')
        if owner.region(original(entry),entry).tobytes()!=owner.region(Image.open(base.local(entry['path'])).convert('RGBA'),entry).tobytes():raise ValueError('Unrelated atlas neighbor changed')
    return recipe,manifest,sources


def prepare(output,install=False):
    output=output.resolve()
    if output==ROOT.resolve() or output.is_relative_to((ROOT/'art').resolve()):raise ValueError('Preview must be outside art')
    recipe,manifest,sources=inputs();output.mkdir(parents=True,exist_ok=False)
    rows={};atlases={};results={}
    for key,row in recipe['assets'].items():
        result,fixed,mask,metrics=recover(sources[key],row);results[key]=result
        result.save(output/(key+'.png'),optimize=True)
        fixed.save(output/(key+'_source.png'),optimize=True)
        mask.save(output/(key+'_support.png'),optimize=True)
        rows[key]=dict(metrics=metrics,trim_sha256=base.digest(output/(key+'.png')),
            recovered_source_sha256=base.digest(output/(key+'_source.png')),
            support_sha256=base.digest(output/(key+'_support.png')))
        entry=row['original_manifest_entry'];path=entry['path']
        if path not in atlases:atlases[path]=original(entry)
        x,y,_,_=entry['atlas_region'];atlases[path].paste(result,(x,y))
    files={}
    for path,atlas in atlases.items():
        target=output/'runtime'/base.local(path).relative_to(ROOT/'art/overworld/runtime')
        target.parent.mkdir(parents=True,exist_ok=True);atlas.save(target,optimize=True)
        entry={'path':path};old=before_path(entry)
        files[path]=dict(before_sha256=base.digest(old if old.exists() else base.local(path)),after_sha256=base.digest(target),prepared=str(target.relative_to(output)))
    canvas=Image.new('RGB',(1000,7*170),'#334c3a');d=ImageDraw.Draw(canvas)
    for i,(key,row) in enumerate(recipe['assets'].items()):
        before=owner.region(original(row['original_manifest_entry']),row['original_manifest_entry'])
        for j,im in enumerate((before,results[key])):
            t=im.resize((144,144),Image.Resampling.NEAREST);canvas.paste(t,(j*170,i*170),t)
        d.text((355,i*170+30),key,fill='white')
        d.text((355,i*170+50),'BEFORE / RECOVERED | original 48x48 canvas',fill='white')
    canvas.save(output/'comparison.png')
    proof=dict(schema_id='passage_cutout_recovery_v1',recipe_sha256=base.digest(RECIPE),
        processing_tool='tools/prepare_overworld_passage_cutouts.py',processing_tool_sha256=base.digest(Path(__file__)),
        processing='Only explicit source-connected backing components removed. Original registered bilinear projection patches only affected runtime pixels; all other original RGBA is preserved.',
        assets=rows,files=files,preserved_controls=recipe['preserved_controls'])
    if install:
        for key,row in recipe['assets'].items():
            manifest['object_assets'][key]=dict(expected_entry(row),runtime_sha256=files[row['original_manifest_entry']['path']]['after_sha256'])
        text=owner.manifest_text(manifest,recipe['assets'])
        for path,info in files.items():
            old=before_path({'path':path});old.parent.mkdir(parents=True,exist_ok=True)
            if not old.exists():shutil.copy2(base.local(path),old)
            shutil.copyfile(output/info['prepared'],base.local(path))
        for key,row in recipe['assets'].items():
            for field,suffix in [('trimmed_path','.png'),('recovered_source_path','_source.png')]:
                target=base.local(row[field]);target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(output/(key+suffix),target)
        (PACKET/'manifest.json').write_text(json.dumps(proof,indent=2)+'\n');MANIFEST.write_text(text)
    (output/'report.json').write_text(json.dumps(dict(installed=install,**proof),indent=2)+'\n')
    return dict(installed=install,assets=len(rows),runtime_files=len(files))


def validate_assets():
    recipe,manifest,sources=inputs();proof=json.loads((PACKET/'manifest.json').read_text())
    if proof['recipe_sha256']!=base.digest(RECIPE) or proof['processing_tool_sha256']!=base.digest(Path(__file__)):raise ValueError('Preparation provenance changed')
    if set(proof['assets'])!=set(recipe['assets']) or proof['preserved_controls']!=recipe['preserved_controls']:raise ValueError('Cohort proof changed')
    reports={}
    for key,row in recipe['assets'].items():
        result,fixed,mask,metrics=recover(sources[key],row);entry=manifest['object_assets'][key]
        if entry!=dict(expected_entry(row),runtime_sha256=base.digest(base.local(entry['path']))):raise ValueError('Runtime provenance mismatch')
        if owner.region(Image.open(base.local(entry['path'])).convert('RGBA'),entry).tobytes()!=result.tobytes():raise ValueError('Reconstruction mismatch: '+key)
        for field,pixels,proof_field in [('trimmed_path',result,'trim_sha256'),('recovered_source_path',fixed,'recovered_source_sha256')]:
            path=base.local(row[field])
            if Image.open(path).convert('RGBA').tobytes()!=pixels.tobytes() or base.digest(path)!=proof['assets'][key][proof_field]:raise ValueError('Prepared art mismatch')
        if proof['assets'][key]['metrics']!=metrics:raise ValueError('Source support proof mismatch')
        reports[key]={'ok':True,'errors':[]}
    for path,info in proof['files'].items():
        if base.digest(base.local(path))!=info['after_sha256'] or base.digest(before_path({'path':path}))!=info['before_sha256']:raise ValueError('Atlas proof mismatch')
    return reports


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path,required=True);parser.add_argument('--install',action='store_true')
    args=parser.parse_args();print(json.dumps(prepare(args.output,args.install)))
