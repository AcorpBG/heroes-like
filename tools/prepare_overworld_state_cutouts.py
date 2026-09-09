#!/usr/bin/env python3
"""Recover the original early post-interaction paintings, never gameplay state.

Retained RGB restores erased paint; only explicitly reviewed backing components
are removed. Genuine RGBA originals remain exact. Historical atlas registration
is measured independently and projected from the originals at fourfold density.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT=Path(__file__).resolve().parents[1]
PACKET=ROOT/'art/overworld/source/generated/cutout_recovery_20260909/early_states'
RECIPE=PACKET/'recipe.json'
MANIFEST=ROOT/'art/overworld/manifest.json'
SHARED=ROOT/'tools/prepare_overworld_claimed_cutouts.py'
spec=importlib.util.spec_from_file_location('state_source_recovery',SHARED)
shared=importlib.util.module_from_spec(spec);spec.loader.exec_module(shared)
base=shared.base;owner=shared.owner;project=shared.project
FAMILIES={'major_vault_unsealed':(6,42,'center'),
          'creature_bank_opened':(3,42,'center'),
          'guarded_route_opened':(8,44,'center'),
          'repeatable_service_visited':(6,46,'south'),
          'progression_shrine_awakened':(6,44,'center'),
          'scouting_structure_controlled':(5,44,'center')}


def recover_source(source,row):
    """Decontaminate only the inspected backing's immediate composite edge.

    The source composite supplies coverage; nearest intact source paint supplies
    color. Never classify all white/crystal/snow pixels as background. Pixels
    outside the small registered band and all genuine RGBA sources stay exact.
    """
    fixed,points=shared.recover_source(source,row)
    radius=row.get('matte_boundary_radius',0)
    if row['source_mode']=='genuine_rgba':
        if radius:raise ValueError('Genuine RGBA cannot be rematted')
        return fixed,points
    expected_radius=12 if row['original_manifest_entry']['assigned_resource_site_id']=='site_ashbarb_roadblock' else 2
    if radius!=expected_radius:raise ValueError('Unreviewed matte edge radius')
    rgb=source.convert('RGB');pixels=list(rgb.getdata());mask=Image.new('L',source.size)
    a=np.zeros((source.height,source.width),dtype='uint8');a.ravel()[list(points)]=255;mask=Image.fromarray(a)
    band=np.asarray(mask.filter(ImageFilter.MaxFilter(2*radius+1))).ravel()>0
    unknown=np.flatnonzero(band & (a.ravel()==0)).tolist()
    foreground=base.nearest_colors(pixels,(~band).tolist(),unknown,*source.size)
    background=base.nearest_colors(pixels,(a.ravel()>0).tolist(),unknown,*source.size)
    out=np.asarray(fixed).copy().reshape(-1,4)
    for i in unknown:
        p=np.array(pixels[i],dtype=float);fg=np.array(foreground[i],dtype=float);bg=np.array(background[i],dtype=float);delta=fg-bg;denom=delta@delta
        if denom<2500 or p.mean()<=fg.mean():continue
        coverage=float(np.clip(((p-bg)@delta)/denom,0,1))
        # Reject a bad local model instead of repainting original foreground.
        if coverage>=0.98 or np.max(np.abs(p-(bg+coverage*delta)))>20:continue
        out[i]=[*foreground[i],round(coverage*255)]
    return Image.fromarray(out.reshape(source.height,source.width,4)),points


def before_path(path):
    return PACKET/'before_runtime'/base.local(path).relative_to(ROOT/'art/overworld/runtime')


def original(path):
    archived=before_path(path)
    return Image.open(archived if archived.exists() else base.local(path)).convert('RGBA')


def expected_entry(row):
    old=row['original_manifest_entry']
    return dict(old,atlas_region=[v*4 for v in old['atlas_region']],
                atlas_size=[v*4 for v in old['atlas_size']],source_trimmed=row['trimmed_path'],
                source_processing_manifest=base.resource(PACKET/'manifest.json'))


def recover(source,row):
    return project(recover_source(source,row)[0],row)


def inputs():
    recipe=json.loads(RECIPE.read_text());manifest=json.loads(MANIFEST.read_text())
    proof=json.loads((PACKET/'manifest.json').read_text()) if (PACKET/'manifest.json').exists() else {}
    if recipe.get('schema_id')!='early_state_cutout_recipe_v1' or len(recipe['assets'])!=34:raise ValueError('Cohort changed')
    expected_paths={f'res://art/overworld/runtime/objects/resource_sites/{f}_atlas.png' for f in FAMILIES}
    if set(recipe['atlases'])!=expected_paths:raise ValueError('Atlas owners changed')
    if {k for k,v in manifest['object_assets'].items() if v['path'] in expected_paths}!=set(recipe['assets']):raise ValueError('Incomplete atlas membership')
    if set(recipe['state_mappings'])!={v['original_manifest_entry']['assigned_resource_site_id'] for v in recipe['assets'].values()}:raise ValueError('Incomplete state coverage')
    if any(manifest['resource_site_sprites'][k]!=v for k,v in recipe['state_mappings'].items()):raise ValueError('State mapping changed')
    for path,info in recipe['atlases'].items():
        count,_,_=FAMILIES[Path(path).stem.removesuffix('_atlas')]
        if info['before_size']!=[count*48,48] or list(original(path).size)!=info['before_size']:raise ValueError('Historical atlas geometry changed')
        if base.digest(before_path(path) if before_path(path).exists() else base.local(path))!=info['before_sha256']:raise ValueError('Historical atlas changed')
        if base.digest(base.local(path)) not in (info['before_sha256'],proof.get('files',{}).get(path,{}).get('after_sha256')):raise ValueError('Unrecognized runtime edit')
        if sorted(v['original_manifest_entry']['atlas_region'][0] for v in recipe['assets'].values() if v['runtime_path']==path)!=list(range(0,count*48,48)):raise ValueError('Atlas registration coverage changed')
    sources={}
    for key,row in recipe['assets'].items():
        old=row['original_manifest_entry'];entry=manifest['object_assets'][key]
        if {k:v for k,v in entry.items() if k!='runtime_sha256'} not in (old,expected_entry(row)):raise ValueError('Identity changed: '+key)
        if row['runtime_path']!=old['path'] or old['atlas_region'][1:]!=[0,48,48]:raise ValueError('Unscoped atlas change')
        path=base.local(old['source_generated'])
        if base.digest(path)!=row['source_sha256']:raise ValueError('Original painting changed: '+key)
        source=Image.open(path).convert('RGBA');sources[key]=source
        levels=len(set(source.getchannel('A').getdata()))
        if levels!=row['source_alpha_levels'] or (row['source_mode']=='genuine_rgba')!=(levels>2) or levels not in (2,255,256):raise ValueError('Alpha policy changed')
        if list(source.size)!=row['source_size'] or list(source.getbbox())!=row['source_crop']:raise ValueError('Source registration changed')
        count,limit,anchor=FAMILIES[Path(old['path']).stem.removesuffix('_atlas')]
        l,t,r,b=row['source_crop'];fit=[round((r-l)*limit/max(r-l,b-t)),round((b-t)*limit/max(r-l,b-t))]
        origin=[(48-fit[0])//2,48-fit[1] if anchor=='south' else (48-fit[1])//2]
        if row['source_resize']!=fit or row['canvas_origin']!=origin or row['fit_limit']!=limit:raise ValueError('Logical fit/anchor changed')
        if row['canvas_size']!=[192,192] or row['pixel_scale']!=4 or row['resampling']!='BILINEAR':raise ValueError('Density/filter changed')
        if row['registration_evidence']!=shared.registration(source,row,owner.region(original(old['path']),old)):raise ValueError('Historical registration proof changed')
        trim=ROOT/'art/overworld/source/trimmed/cutout_recovery_20260909/early_states'
        for field,dest,sha in [('trimmed_path',trim/(key+'.png'),'trim_sha256'),('recovered_source_path',trim/'sources'/(key+'.png'),'source_sha256')]:
            if base.local(row[field])!=dest:raise ValueError('Unscoped derived path')
            if dest.exists() and base.digest(dest)!=proof.get('assets',{}).get(key,{}).get(sha):raise ValueError('Unrecognized derived edit')
    return recipe,manifest,sources


def tool_hashes():
    return {name:base.digest(path) for name,path in [('processing_tool_sha256',Path(__file__)),('shared_tool_sha256',SHARED),('projection_tool_sha256',shared.SHARED),('component_tool_sha256',shared.PASSAGE)]}


def prepare(output,install=False):
    output=output.resolve()
    if output==ROOT.resolve() or output.is_relative_to((ROOT/'art').resolve()):raise ValueError('Preview must be outside art')
    recipe,manifest,sources=inputs();output.mkdir(parents=True,exist_ok=False);(output/'sources').mkdir()
    atlases={p:Image.new('RGBA',tuple(v*4 for v in i['before_size'])) for p,i in recipe['atlases'].items()};results={};rows={};files={}
    for key,row in recipe['assets'].items():
        source,points=recover_source(sources[key],row);fixed=project(source,row);results[key]=fixed
        fixed.save(output/(key+'.png'),optimize=True);source.save(output/'sources'/(key+'.png'),optimize=True)
        rows[key]=dict(trim_sha256=base.digest(output/(key+'.png')),source_sha256=base.digest(output/'sources'/(key+'.png')),rgba_sha256=hashlib.sha256(fixed.tobytes()).hexdigest(),removed_source_pixels=len(points),metrics=shared.metrics(fixed))
        x,y,_,_=expected_entry(row)['atlas_region'];atlases[row['runtime_path']].paste(fixed,(x,y))
    for path,atlas in atlases.items():
        target=output/'runtime'/base.local(path).relative_to(ROOT/'art/overworld/runtime');target.parent.mkdir(parents=True,exist_ok=True);atlas.save(target,optimize=True)
        files[path]=dict(after_sha256=base.digest(target),prepared=str(target.relative_to(output)))
    for page,start in enumerate(range(0,34,4)):
        canvas=Image.new('RGB',(1440,650),'#334c3a');d=ImageDraw.Draw(canvas)
        for j,(key,row) in enumerate(list(recipe['assets'].items())[start:start+4]):
            x,y=(j%2)*720,(j//2)*325;old=row['original_manifest_entry']
            for col,im in enumerate((owner.region(original(old['path']),old).resize((192,192),Image.Resampling.NEAREST),results[key],Image.open(output/'sources'/(key+'.png')))):
                thumb=im.copy();thumb.thumbnail((232,270),Image.Resampling.LANCZOS);canvas.paste(thumb,(x+240*col,y),thumb)
            d.text((x+3,y+280),key,fill='white');d.text((x+3,y+296),'OLD 48 / ORIGINAL-SOURCE 192 / RECOVERED MASTER',fill='white')
        canvas.save(output/f'comparison_{page:02}.png')
    proof=dict(schema_id='early_state_cutout_recovery_v1',recipe_sha256=base.digest(RECIPE),**tool_hashes(),assets=rows,files=files,processing='Reviewed original retained RGB backing components; genuine source RGBA unchanged. Original measured logical crop/fit/anchor projected at 4x raster density. All identities, state mappings and world draw owners unchanged.')
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
    recipe,manifest,sources=inputs();proof=json.loads((PACKET/'manifest.json').read_text());reports={}
    if proof['schema_id']!='early_state_cutout_recovery_v1' or proof['recipe_sha256']!=base.digest(RECIPE) or any(proof[k]!=v for k,v in tool_hashes().items()):raise ValueError('Preparation provenance changed')
    if set(proof['assets'])!=set(recipe['assets']) or set(proof['files'])!=set(recipe['atlases']):raise ValueError('Incomplete proof')
    atlases={p:Image.open(base.local(p)).convert('RGBA') for p in recipe['atlases']}
    for path,info in recipe['atlases'].items():
        if base.digest(before_path(path))!=info['before_sha256'] or list(atlases[path].size)!=[v*4 for v in info['before_size']] or base.digest(base.local(path))!=proof['files'][path]['after_sha256']:raise ValueError('Atlas provenance changed')
    for key,row in recipe['assets'].items():
        source,points=recover_source(sources[key],row);fixed=project(source,row);entry=manifest['object_assets'][key];trim=base.local(row['trimmed_path']);master=base.local(row['recovered_source_path'])
        if entry!=dict(expected_entry(row),runtime_sha256=proof['files'][entry['path']]['after_sha256']):raise ValueError('Runtime ownership changed')
        if owner.region(atlases[entry['path']],entry).tobytes()!=fixed.tobytes() or Image.open(trim).convert('RGBA').tobytes()!=fixed.tobytes() or Image.open(master).convert('RGBA').tobytes()!=source.tobytes():raise ValueError('Source reconstruction failed')
        expected=dict(trim_sha256=base.digest(trim),source_sha256=base.digest(master),rgba_sha256=hashlib.sha256(fixed.tobytes()).hexdigest(),removed_source_pixels=len(points),metrics=shared.metrics(fixed))
        if proof['assets'][key]!=expected:raise ValueError('Paint proof changed')
        reports[key]=dict(ok=True,errors=[])
    return reports


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path,required=True);parser.add_argument('--install',action='store_true')
    args=parser.parse_args();print(json.dumps(prepare(args.output,args.install)))
