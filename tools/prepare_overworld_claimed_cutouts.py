#!/usr/bin/env python3
"""Recover original claimed-dwelling paint and inspected backing, not new art.

Six genuine RGBA originals remain exact. Twenty-five historically keyed sources
retain their original RGB; explicit seed/area/bounds masks remove only reviewed
backing while restoring erased snow, salt, cloth and masonry. Original alpha
bounds determine the unchanged logical registration, never the recovered bounds.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil

import numpy as np
from PIL import Image,ImageDraw,ImageChops,ImageStat

ROOT=Path(__file__).resolve().parents[1]
PACKET=ROOT/'art/overworld/source/generated/cutout_recovery_20260909/claimed_dwellings'
RECIPE=PACKET/'recipe.json'
MANIFEST=ROOT/'art/overworld/manifest.json'
SHARED=ROOT/'tools/prepare_overworld_recurring_cutouts.py'
PASSAGE=ROOT/'tools/prepare_overworld_passage_cutouts.py'
spec=importlib.util.spec_from_file_location('claimed_projection',SHARED)
shared=importlib.util.module_from_spec(spec);spec.loader.exec_module(shared)
spec=importlib.util.spec_from_file_location('claimed_components',PASSAGE)
passage=importlib.util.module_from_spec(spec);spec.loader.exec_module(passage)
base=shared.base;owner=shared.owner;project=shared.recover;metrics=shared.metrics


def before_path(path):
    return PACKET/'before_runtime'/base.local(path).relative_to(ROOT/'art/overworld/runtime')


def original(path):
    archived=before_path(path)
    return Image.open(archived if archived.exists() else base.local(path)).convert('RGBA')


def expected_entry(row):
    old=row['original_manifest_entry']
    return dict(old,atlas_region=[v*4 for v in old['atlas_region']],atlas_size=[v*4 for v in old['atlas_size']],
                source_trimmed=row['trimmed_path'],source_processing_manifest=base.resource(PACKET/'manifest.json'))


def recover_source(source,row):
    if row['source_mode']=='genuine_rgba':
        if row['backing_components']:raise ValueError('Genuine alpha cannot be keyed')
        return source.copy(),set()
    if row['source_mode']!='retained_rgb':raise ValueError('Unknown source recovery policy')
    a=np.asarray(source).copy();rgb=a[:,:,:3].astype('int16');minimum=rgb.min(2);delta=np.ptp(rgb,axis=2);selected=set();policies={}
    for component in row['backing_components']:
        policy=tuple(component.get(k) for k in ('minimum','maximum_delta','lower_minimum','lower_start_y'))
        if policy not in policies:
            floor=component['minimum']
            if 'lower_minimum' in component:floor=np.where(np.arange(source.height)[:,None]>=component['lower_start_y'],component['lower_minimum'],floor)
            policies[policy]=((minimum>=floor)&(delta<=component['maximum_delta'])).ravel().tolist()
        points=passage.component(source,component,policies[policy])
        if selected&points:raise ValueError('Duplicate inspected backing')
        selected.update(points)
    a[:,:,3]=255;a.reshape(-1,4)[list(selected)]=0
    return Image.fromarray(a),selected


def recover(source,row):
    return project(recover_source(source,row)[0],row)


def registration(source,row,old):
    projected=project(source,dict(row,canvas_size=[48,48],pixel_scale=1))
    diff=ImageChops.difference(old,projected)
    mask=ImageChops.multiply(old.getchannel('A').point(lambda a:255 if a>200 else 0),projected.getchannel('A').point(lambda a:255 if a>200 else 0))
    result=dict(alpha_mae=ImageStat.Stat(diff.getchannel('A')).mean[0],opaque_rgb_mae=sum(ImageStat.Stat(diff.convert('RGB'),mask).mean)/3)
    if result['alpha_mae']>=1 or result['opaque_rgb_mae']>=1.6:raise ValueError('Original registration changed')
    return result


def inputs():
    recipe=json.loads(RECIPE.read_text());manifest=json.loads(MANIFEST.read_text());proof=json.loads((PACKET/'manifest.json').read_text()) if (PACKET/'manifest.json').exists() else {}
    if recipe.get('schema_id')!='claimed_dwelling_cutout_recipe_v1' or len(recipe['assets'])!=31 or len(recipe['atlases'])!=3:raise ValueError('Cohort changed')
    if {k for k,v in manifest['object_assets'].items() if v['path'] in recipe['atlases']}!=set(recipe['assets']):raise ValueError('Incomplete atlas ownership')
    if set(recipe['state_mappings'])!={r['original_manifest_entry']['assigned_resource_site_id'] for r in recipe['assets'].values()}:raise ValueError('Incomplete state controls')
    if any(manifest['resource_site_sprites'][k]!=v for k,v in recipe['state_mappings'].items()):raise ValueError('Site/state mapping changed')
    originals={};sources={}
    for path,info in recipe['atlases'].items():
        archived=before_path(path)
        if base.digest(archived if archived.exists() else base.local(path))!=info['before_sha256']:raise ValueError('Original atlas changed')
        if base.digest(base.local(path)) not in (info['before_sha256'],proof.get('files',{}).get(path,{}).get('after_sha256')):raise ValueError('Unrecognized atlas edit')
        originals[path]=original(path)
        if list(originals[path].size)!=info['before_size']:raise ValueError('Original atlas size changed')
        regions=sorted(r['original_manifest_entry']['atlas_region'][0] for r in recipe['assets'].values() if r['runtime_path']==path)
        if regions!=list(range(0,info['before_size'][0],48)):raise ValueError('Original regions changed')
    for key,row in recipe['assets'].items():
        old=row['original_manifest_entry'];entry=manifest['object_assets'][key]
        if {k:v for k,v in entry.items() if k!='runtime_sha256'} not in (old,expected_entry(row)):raise ValueError('Asset identity changed: '+key)
        if row['runtime_path']!=old['path'] or old['atlas_region'][1:]!=[0,48,48]:raise ValueError('Unscoped atlas transform')
        path=base.local(old['source_generated'])
        if base.digest(path)!=row['source_sha256']:raise ValueError('Source hash changed: '+key)
        source=Image.open(path).convert('RGBA');sources[key]=source
        levels=len(set(source.getchannel('A').getdata()))
        if (row['source_mode']=='genuine_rgba')!=(levels==256) or levels not in (2,256):raise ValueError('Source alpha policy changed')
        if list(source.getbbox())!=row['source_crop']:raise ValueError('Original alpha crop changed')
        l,t,r,b=row['source_crop'];w,h=round((r-l)*44/max(r-l,b-t)),round((b-t)*44/max(r-l,b-t))
        first=Path(old['path']).name=='neutral_dwelling_claimed_atlas.png'
        if row['source_resize']!=[w,h] or row['canvas_origin']!=[(48-w)//2,48-h if first else (48-h)//2]:raise ValueError('Original fit/anchor changed')
        if row['pixel_scale']!=4 or row['canvas_size']!=[192,192] or row['resampling']!='BILINEAR':raise ValueError('Source density/filter changed')
        if row['registration_evidence']!=registration(source,row,owner.region(originals[old['path']],old)):raise ValueError('Registration evidence changed')
        trim=ROOT/'art/overworld/source/trimmed/cutout_recovery_20260909/claimed_dwellings'
        for field,dest,sha in [('trimmed_path',trim/(key+'.png'),'trim_sha256'),('recovered_source_path',trim/'sources'/(key+'.png'),'source_sha256')]:
            if base.local(row[field])!=dest:raise ValueError('Unscoped prepared path')
            if dest.exists() and base.digest(dest)!=proof.get('assets',{}).get(key,{}).get(sha):raise ValueError('Unrecognized prepared edit')
    return recipe,manifest,sources


def prepare(output,install=False):
    output=output.resolve()
    if output==ROOT.resolve() or output.is_relative_to((ROOT/'art').resolve()):raise ValueError('Preview must be outside art')
    recipe,manifest,sources=inputs();output.mkdir(parents=True,exist_ok=False);(output/'sources').mkdir()
    atlases={p:Image.new('RGBA',tuple(v*4 for v in i['before_size'])) for p,i in recipe['atlases'].items()};results={};rows={};files={}
    for key,row in recipe['assets'].items():
        source,points=recover_source(sources[key],row);fixed=project(source,row);results[key]=fixed
        fixed.save(output/(key+'.png'),optimize=True);source.save(output/'sources'/(key+'.png'),optimize=True)
        rows[key]=dict(trim_sha256=base.digest(output/(key+'.png')),source_sha256=base.digest(output/'sources'/(key+'.png')),rgba_sha256=hashlib.sha256(fixed.tobytes()).hexdigest(),removed_source_pixels=len(points),metrics=metrics(fixed))
        x,y,_,_=expected_entry(row)['atlas_region'];atlases[row['runtime_path']].paste(fixed,(x,y))
    for path,atlas in atlases.items():
        target=output/'runtime'/base.local(path).relative_to(ROOT/'art/overworld/runtime');target.parent.mkdir(parents=True,exist_ok=True);atlas.save(target,optimize=True)
        files[path]=dict(after_sha256=base.digest(target),prepared=str(target.relative_to(output)))
    for page in range(8):
        canvas=Image.new('RGB',(1320,600),'#334c3a');d=ImageDraw.Draw(canvas)
        for j,(key,row) in enumerate(list(recipe['assets'].items())[page*4:page*4+4]):
            x,y=(j%2)*660,(j//2)*300;old=row['original_manifest_entry']
            for col,im in enumerate((owner.region(original(old['path']),old),results[key],Image.open(output/'sources'/(key+'.png')))):
                thumb=im.copy();thumb.thumbnail((216,216),Image.Resampling.LANCZOS)
                if col==0:thumb=im.resize((192,192),Image.Resampling.NEAREST)
                canvas.paste(thumb,(x+220*col,y),thumb)
            d.text((x+5,y+228),key,fill='white');d.text((x+5,y+246),'OLD 48px / SOURCE RECOVERY 192px / RECOVERED ORIGINAL',fill='white')
        canvas.save(output/f'comparison_{page:02}.png')
    proof=dict(schema_id='claimed_dwelling_cutout_recovery_v1',recipe_sha256=base.digest(RECIPE),processing_tool_sha256=base.digest(Path(__file__)),shared_tool_sha256=base.digest(SHARED),component_tool_sha256=base.digest(PASSAGE),assets=rows,files=files,processing='Original retained RGB with explicit inspected connected backing only; genuine RGBA unchanged. Original alpha crop/fit/anchor at 4x raster density, unchanged paths, world geometry and claimed/unclaimed routing.')
    if install:
        for path,info in files.items():
            archive=before_path(path);archive.parent.mkdir(parents=True,exist_ok=True)
            if not archive.exists():shutil.copy2(base.local(path),archive)
            shutil.copyfile(output/info['prepared'],base.local(path))
        for key,row in recipe['assets'].items():
            for field,relative in [('trimmed_path',Path(key+'.png')),('recovered_source_path',Path('sources')/(key+'.png'))]:
                dest=base.local(row[field]);dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(output/relative,dest)
            manifest['object_assets'][key]=dict(expected_entry(row),runtime_sha256=files[row['runtime_path']]['after_sha256'])
        MANIFEST.write_text(owner.manifest_text(manifest,recipe['assets']));(PACKET/'manifest.json').write_text(json.dumps(proof,indent=2)+'\n')
    (output/'report.json').write_text(json.dumps(proof,indent=2)+'\n')
    return dict(installed=install,assets=len(rows),atlases=len(files))


def validate_assets():
    recipe,manifest,sources=inputs();proof=json.loads((PACKET/'manifest.json').read_text())
    if proof['schema_id']!='claimed_dwelling_cutout_recovery_v1' or any(proof[k]!=base.digest(p) for k,p in [('recipe_sha256',RECIPE),('processing_tool_sha256',Path(__file__)),('shared_tool_sha256',SHARED),('component_tool_sha256',PASSAGE)]):raise ValueError('Preparation provenance changed')
    if set(proof['assets'])!=set(recipe['assets']) or set(proof['files'])!=set(recipe['atlases']):raise ValueError('Provenance membership changed')
    atlases={p:Image.open(base.local(p)).convert('RGBA') for p in recipe['atlases']};reports={}
    for path,info in recipe['atlases'].items():
        if base.digest(before_path(path))!=info['before_sha256'] or list(atlases[path].size)!=[v*4 for v in info['before_size']] or base.digest(base.local(path))!=proof['files'][path]['after_sha256']:raise ValueError('Atlas provenance mismatch')
    for key,row in recipe['assets'].items():
        source,points=recover_source(sources[key],row);fixed=project(source,row);entry=manifest['object_assets'][key];trim=base.local(row['trimmed_path']);master=base.local(row['recovered_source_path'])
        if entry!=dict(expected_entry(row),runtime_sha256=proof['files'][entry['path']]['after_sha256']):raise ValueError('Runtime ownership changed')
        if owner.region(atlases[entry['path']],entry).tobytes()!=fixed.tobytes() or Image.open(trim).convert('RGBA').tobytes()!=fixed.tobytes() or Image.open(master).convert('RGBA').tobytes()!=source.tobytes():raise ValueError('Original-source reconstruction failed')
        expected=dict(trim_sha256=base.digest(trim),source_sha256=base.digest(master),rgba_sha256=hashlib.sha256(fixed.tobytes()).hexdigest(),removed_source_pixels=len(points),metrics=metrics(fixed))
        if proof['assets'][key]!=expected:raise ValueError('Paint proof mismatch')
        reports[key]=dict(ok=True,errors=[])
    return reports


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path,required=True);parser.add_argument('--install',action='store_true')
    args=parser.parse_args();print(json.dumps(prepare(args.output,args.install)))
