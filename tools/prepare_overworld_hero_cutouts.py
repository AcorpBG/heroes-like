#!/usr/bin/env python3
"""Recover inspected white-matte remnants in three original hero paintings.

The other 57 identity sprites, every portrait and all identity/placement data
are frozen controls. No global white key, silhouette erosion or new painting.
Only explicitly seeded source backing and its three-pixel mixed edge may change.
"""
import argparse
import importlib.util
import json
from pathlib import Path
import shutil

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
PACKET = ROOT/'art/overworld/source/generated/cutout_recovery_20260909/heroes'
RECIPE = PACKET/'recipe.json'
MANIFEST = ROOT/'art/overworld/manifest.json'
_spec = importlib.util.spec_from_file_location('hero_source_owner', ROOT/'tools/prepare_overworld_passage_cutouts.py')
source_owner = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(source_owner)
owner = source_owner.owner
base = owner.base


def before_path(entry):
    return PACKET/'before_runtime'/base.local(entry['path']).relative_to(ROOT/'art/overworld/runtime')


def original(entry):
    path = before_path(entry)
    return Image.open(path if path.exists() else base.local(entry['path'])).convert('RGBA')


def portrait_path(entry):
    path = ROOT/entry['identity_reference'].removeprefix('res://')
    if not path.resolve().is_relative_to(ROOT/'art/heroes/portraits'):
        raise ValueError('Unscoped original portrait')
    return path


def recover_source(source, row):
    pixels = list(source.getdata()); w, h = source.size
    # The original binary-alpha key left the painted checkerboard RGB in
    # transparent pixels. This is measured background, not invented white.
    valid = [min(r,g,b)>=230 and max(r,g,b)-min(r,g,b)<=20 for r,g,b,a in pixels]
    selected = set()
    for spec in row['backing_components']:
        points = source_owner.component(source, spec, valid)
        if selected & points: raise ValueError('Duplicate source backing component')
        if sum(pixels[i][3]>0 for i in points)!=spec['visible']:
            raise ValueError('Inspected visible backing changed')
        selected.update(points)
    keys = [i in selected for i in range(len(pixels))]
    backing = Image.new('L', source.size); backing.putdata([255 if k else 0 for k in keys])
    near = list(backing.filter(ImageFilter.MaxFilter(7)).getdata())
    unknown = [i for i,p in enumerate(pixels) if p[3]>0 and not keys[i] and near[i]]
    unknown_set = set(unknown)
    rgb = [p[:3] for p in pixels]
    fg = base.nearest_colors(rgb, [p[3]>0 and not keys[i] and i not in unknown_set for i,p in enumerate(pixels)], unknown, w,h)
    bg = base.nearest_colors(rgb, keys, unknown, w,h)
    output = pixels.copy(); removed = 0; recovered = 0
    for i in selected:
        # Leave the original invisible RGB untouched too.
        if pixels[i][3]: output[i]=(0,0,0,0); removed+=1
    for i in unknown:
        delta = [f-b for f,b in zip(fg[i],bg[i])]
        denom = sum(d*d for d in delta)
        # White hair, ivory, crystals and gold highlights are paint. If the
        # local pair cannot distinguish that paint from backing, preserve it.
        if denom<400: continue
        coverage = max(0.,min(1.,sum((p-b)*d for p,b,d in zip(rgb[i],bg[i],delta))/denom))
        residual = max(abs(p-(b+coverage*d)) for p,b,d in zip(rgb[i],bg[i],delta))
        if coverage>=0.95 or residual>24: continue
        alpha = round(coverage*255)
        output[i] = (*fg[i],alpha) if alpha>=4 else (0,0,0,0)
        recovered+=1
    fixed = Image.new('RGBA',source.size); fixed.putdata(output)
    return fixed, dict(source_removed_pixels=removed,edge_candidate_pixels=len(unknown),source_edge_recovered_pixels=recovered)


def registered(source,row):
    canvas = Image.new('RGBA',(512,512))
    canvas.paste(source.crop(row['source_crop']).resize(tuple(row['source_resize']),Image.Resampling.BILINEAR),tuple(row['canvas_origin']))
    return canvas


def recover(source,row):
    fixed,metrics = recover_source(source,row)
    a = registered(source,row); b = registered(fixed,row)
    mask = Image.new('L',(512,512)); mask.putdata([255 if p!=q else 0 for p,q in zip(a.getdata(),b.getdata())])
    before = original(row['original_manifest_entry'])
    result = before.copy(); result.paste(b,(0,0),mask)
    metrics['runtime_affected_pixels'] = sum(bool(v) for v in mask.getdata())
    return result,fixed,mask,metrics


def expected_entry(row):
    entry = row['original_manifest_entry']
    return dict(entry,source_trimmed=row['trimmed_path'],source_processing_manifest=base.resource(PACKET/'manifest.json')) if row['mode']=='hero' else entry


def inputs():
    recipe = json.loads(RECIPE.read_text()); manifest = json.loads(MANIFEST.read_text())
    proof = json.loads((PACKET/'manifest.json').read_text()) if (PACKET/'manifest.json').exists() else {}
    if recipe.get('schema_id')!='hero_cutout_recipe_v1': raise ValueError('Unknown hero recipe')
    if recipe['identity_mappings']!=manifest['hero_identity_sprites'] or set(recipe['assets'])!=set(manifest['hero_identity_sprites'].values()):
        raise ValueError('Exact hero cohort/identity mapping changed')
    sources = {}
    for key,row in recipe['assets'].items():
        entry = manifest['object_assets'][key]
        if {k:v for k,v in entry.items() if k!='runtime_sha256'} not in (row['original_manifest_entry'],expected_entry(row)):
            raise ValueError('Original hero metadata changed: '+key)
        if row['mode'] not in ('hero','preserved_hero') or row['canvas_size']!=[512,512]: raise ValueError('Unsupported hero mode/canvas')
        path = base.local(entry['source_generated'])
        if base.digest(path)!=row['source_sha256'] or base.digest(portrait_path(entry))!=row['portrait_sha256']:
            raise ValueError('Original source/portrait hash changed: '+key)
        current = base.local(entry['path']); old = before_path(entry)
        if base.digest(old if old.exists() else current)!=row['before_sha256']: raise ValueError('Original runtime hash changed: '+key)
        accepted = proof.get('files',{}).get(entry['path'],{}).get('after_sha256') if row['mode']=='hero' else None
        if base.digest(current) not in (row['before_sha256'],accepted): raise ValueError('Unrecognized runtime edit: '+key)
        if row['mode']=='preserved_hero':
            if entry!=row['original_manifest_entry']: raise ValueError('Clean control metadata changed: '+key)
            continue
        source = Image.open(path).convert('RGBA'); sources[key]=source
        if list(source.getbbox())!=row['source_crop']: raise ValueError('Original source crop changed')
        w,h = row['source_resize']; x,y = row['canvas_origin']
        crop = row['source_crop']; scale = min(460/(crop[2]-crop[0]),490/(crop[3]-crop[1]))
        expected_size = [round((crop[2]-crop[0])*scale),round((crop[3]-crop[1])*scale)]
        if [w,h]!=expected_size or [x,y]!=[(512-w)//2,512-h]: raise ValueError('Original registration changed')
        trim = ROOT/'art/overworld/source/trimmed/cutout_recovery_20260909/heroes'
        for field,relative,proof_field in [('trimmed_path',key+'.png','trim_sha256'),('recovered_source_path','sources/'+key+'.png','recovered_source_sha256')]:
            dest = base.local(row[field])
            if dest!=trim/relative: raise ValueError('Unscoped prepared art')
            if dest.exists() and base.digest(dest)!=proof.get('assets',{}).get(key,{}).get(proof_field): raise ValueError('Unrecognized prepared art edit')
    if len(sources)!=3 or len(recipe['assets'])!=60: raise ValueError('Expected three repairs and 57 controls')
    return recipe,manifest,sources


def prepare(output,install=False):
    output = output.resolve()
    if output==ROOT or output.is_relative_to(ROOT/'art'): raise ValueError('Preview must be outside art')
    recipe,manifest,sources = inputs(); output.mkdir(parents=True,exist_ok=False)
    rows = {}; files = {}; sheet = Image.new('RGB',(1024,3*544),'#334c3a'); draw = ImageDraw.Draw(sheet)
    for index,(key,source) in enumerate(sources.items()):
        row = recipe['assets'][key]; entry=row['original_manifest_entry']
        result,fixed,mask,metrics = recover(source,row)
        result.save(output/(key+'.png'),optimize=True); fixed.save(output/(key+'_source.png'),optimize=True); mask.save(output/(key+'_support.png'),optimize=True)
        rows[key]=dict(metrics=metrics,trim_sha256=base.digest(output/(key+'.png')),recovered_source_sha256=base.digest(output/(key+'_source.png')),support_sha256=base.digest(output/(key+'_support.png')))
        target=output/'runtime'/base.local(entry['path']).relative_to(ROOT/'art/overworld/runtime'); target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(output/(key+'.png'),target)
        files[entry['path']]=dict(before_sha256=row['before_sha256'],after_sha256=base.digest(target),prepared=str(target.relative_to(output)))
        for col,im in enumerate((original(entry),result)): sheet.paste(im,(col*512,index*544+32),im)
        draw.text((12,index*544+8),key+' | ORIGINAL / RECOVERED',fill='white')
    sheet.save(output/'comparison.png')
    proof=dict(schema_id='hero_cutout_recovery_v1',recipe_sha256=base.digest(RECIPE),processing_tool='tools/prepare_overworld_hero_cutouts.py',processing_tool_sha256=base.digest(Path(__file__)),
               processing='Explicit retained-source neutral backing components; bounded three-pixel source composite recovery. Historical registered projection patches only changed runtime support; every other runtime pixel and 57 clean controls remain exact.',assets=rows,files=files)
    if install:
        for path,info in files.items():
            old=before_path({'path':path});old.parent.mkdir(parents=True,exist_ok=True)
            if not old.exists(): shutil.copy2(base.local(path),old)
            shutil.copyfile(output/info['prepared'],base.local(path))
        for key in sources:
            row=recipe['assets'][key]
            for field,suffix in [('trimmed_path','.png'),('recovered_source_path','_source.png')]:
                dest=base.local(row[field]);dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(output/(key+suffix),dest)
            manifest['object_assets'][key]=dict(expected_entry(row),runtime_sha256=files[row['original_manifest_entry']['path']]['after_sha256'])
        (PACKET/'manifest.json').write_text(json.dumps(proof,indent=2)+'\n'); MANIFEST.write_text(owner.manifest_text(manifest,sources))
    (output/'report.json').write_text(json.dumps(dict(installed=install,**proof),indent=2)+'\n')
    return dict(installed=install,repairs=len(rows),preserved_controls=len(recipe['assets'])-len(rows))


def validate_assets():
    recipe,manifest,sources=inputs();proof=json.loads((PACKET/'manifest.json').read_text())
    if proof['recipe_sha256']!=base.digest(RECIPE) or proof['processing_tool_sha256']!=base.digest(Path(__file__)): raise ValueError('Preparation provenance changed')
    if set(proof['assets'])!=set(sources) or set(proof['files'])!={recipe['assets'][k]['original_manifest_entry']['path'] for k in sources}: raise ValueError('Repair proof membership changed')
    for key,source in sources.items():
        row=recipe['assets'][key];result,fixed,mask,metrics=recover(source,row);entry=manifest['object_assets'][key]
        if entry!=dict(expected_entry(row),runtime_sha256=base.digest(base.local(entry['path']))): raise ValueError('Runtime provenance mismatch')
        if Image.open(base.local(entry['path'])).convert('RGBA').tobytes()!=result.tobytes(): raise ValueError('Runtime reconstruction mismatch')
        for field,pixels,proof_field in [('trimmed_path',result,'trim_sha256'),('recovered_source_path',fixed,'recovered_source_sha256')]:
            path=base.local(row[field])
            if Image.open(path).convert('RGBA').tobytes()!=pixels.tobytes() or base.digest(path)!=proof['assets'][key][proof_field]: raise ValueError('Prepared source reconstruction mismatch')
        import io
        blob=io.BytesIO();mask.save(blob,format='PNG',optimize=True)
        import hashlib
        if hashlib.sha256(blob.getvalue()).hexdigest()!=proof['assets'][key]['support_sha256'] or metrics!=proof['assets'][key]['metrics']: raise ValueError('Repair support proof changed')
    for path,info in proof['files'].items():
        if base.digest(base.local(path))!=info['after_sha256'] or base.digest(before_path({'path':path}))!=info['before_sha256']: raise ValueError('Runtime file proof mismatch')
    return {key:dict(ok=True,errors=[]) for key in recipe['assets']}


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path,required=True);parser.add_argument('--install',action='store_true')
    args=parser.parse_args();print(json.dumps(prepare(args.output,args.install)))
