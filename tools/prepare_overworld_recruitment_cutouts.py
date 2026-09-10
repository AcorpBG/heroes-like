#!/usr/bin/env python3
"""Recover 36 recruitment paintings and six physically integrated state edits.

Original sources and historical atlases remain immutable. Only reviewed stray
sheet fragments, quantization-noise RGB at alpha 1..4 and six generated physical
details change. No RGB is drawn procedurally and no gameplay owner is modified.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
from functools import lru_cache
from collections import deque
import numpy as np

from PIL import Image, ImageChops, ImageDraw, ImageOps, ImageStat

ROOT = Path(__file__).resolve().parents[1]
PACKET = ROOT/'art/overworld/source/generated/cutout_recovery_20260909/recruitment_sites'
RECIPE = PACKET/'recipe.json'
MANIFEST = ROOT/'art/overworld/manifest.json'
SHARED = ROOT/'tools/prepare_overworld_recurring_cutouts.py'
spec = importlib.util.spec_from_file_location('recruitment_original_projection', SHARED)
shared = importlib.util.module_from_spec(spec); spec.loader.exec_module(shared)
base = shared.base; owner = shared.owner; project = shared.recover
FAMILIES = {'unbound_wild_concords': (12,44,48,'BILINEAR'),
            'veteran_company_musters': (12,42,'center','BILINEAR'),
            'frontier_mythic_habitats': (12,43,46,'LANCZOS')}
STATE_TOOL = ROOT/'tools/prepare_overworld_route_arcane_cutouts.py'
state_spec=importlib.util.spec_from_file_location('recruitment_physical_composite',STATE_TOOL)
state=importlib.util.module_from_spec(state_spec);state_spec.loader.exec_module(state)


def fragment_mask(source, fragments):
    """Remove only explicitly reviewed, independently connected sheet debris."""
    from PIL import ImageFilter
    a=np.asarray(source)[:,:,3];h,w=a.shape;mask=np.zeros((h,w),dtype='uint8')
    for item in fragments:
        x,y=item['seed'];q=deque([(x,y)]);points={(x,y)}
        if a[y,x]<=16:raise ValueError('Fragment seed changed')
        while q:
            x,y=q.popleft()
            for yy in range(max(0,y-1),min(h,y+2)):
                for xx in range(max(0,x-1),min(w,x+2)):
                    if a[yy,xx]>16 and (xx,yy) not in points:points.add((xx,yy));q.append((xx,yy))
        box=[min(x for x,y in points),min(y for x,y in points),max(x for x,y in points)+1,max(y for x,y in points)+1]
        if len(points)!=item['pixels'] or box!=item['bbox']:raise ValueError('Reviewed fragment component changed')
        for x,y in points:mask[y,x]=255
    # Include only low-alpha fringe within two pixels; never another opaque body.
    dilated=np.asarray(Image.fromarray(mask).filter(ImageFilter.MaxFilter(5)))
    return (mask>0)|((dilated>0)&(a<=16))


def recover_source(source,row):
    a=np.asarray(source).copy()
    if row.get('low_alpha_rgb_repair'):
        rgb=a[:,:,:3];needed=(a[:,:,3]>0)&(a[:,:,3]<=4)&(rgb.max(2)>235)&(rgb.min(2)<20)
        pixels=list(source.convert('RGB').getdata())
        colors=base.nearest_colors(pixels,(a[:,:,3]>=128).ravel().tolist(),np.flatnonzero(needed).tolist(),source.width,source.height)
        indices=np.flatnonzero(needed)
        a[:,:,:3].reshape(-1,3)[indices]=np.asarray([colors[i] for i in indices],dtype='uint8')
    if row.get('fragments'):a[fragment_mask(source,row['fragments'])]=0
    recovered=Image.fromarray(a)
    if row.get('integrated_state_edit'):recovered=state.integrated_state_source(recovered,row['integrated_state_edit'])
    return recovered


def recover(source,row):
    body = recover_source(source,row)
    fixed = project(body,row)
    if row.get('mast_extension'):
        extended = mast_source(source,row)
        edit = row['mast_extension']
        x0,y0,x1,y1 = row['source_crop']
        density = row['pixel_scale']
        width,height = (v*density for v in row['source_resize'])
        left,top = (v*density for v in row['canvas_origin'])
        ratio = height/(y1-y0)
        # Sample only the missing northern paint plus the first bilinear seam
        # row. The original body below this seam is byte-for-byte unchanged.
        seam = top+1
        box = (x0,edit['padding_top']+y0-top/ratio,x1,
               edit['padding_top']+y0+(seam-top)/ratio)
        strip = extended.resize((width,seam),Image.Resampling.BILINEAR,box=box)
        fixed.paste(strip,(left,0))
    return fixed


@lru_cache(maxsize=2)
def mast_sheet_component(path,sha,component_json):
    if base.digest(base.local(path))!=sha:raise ValueError('Mast identity sheet changed')
    sheet=Image.open(base.local(path)).convert('RGBA')
    mask=fragment_mask(sheet,[json.loads(component_json)])
    return sheet,mask


def mast_source(source,row):
    """Restore only connected original paint north of the immutable grid crop."""
    edit=row['mast_extension']
    # Hash is checked before cached component access, including same-process tests.
    if base.digest(base.local(edit['sheet']))!=edit['sheet_sha256']:
        raise ValueError('Mast identity sheet changed')
    sheet,mask=mast_sheet_component(edit['sheet'],edit['sheet_sha256'],json.dumps(edit['component'],sort_keys=True))
    crop=edit['original_grid_crop'];x,y,right,bottom=crop
    if sheet.crop(crop).tobytes()!=source.tobytes():raise ValueError('Mast master is not the exact identity-sheet crop')
    pad=edit['padding_top']
    if pad!=y-edit['component']['bbox'][1]+2 or pad<=0:
        raise ValueError('Mast extension bounds changed')
    pixels=np.asarray(sheet)[y-pad:y,x:right].copy()
    pixels[~mask[y-pad:y,x:right]]=0
    extended=Image.new('RGBA',(source.width,source.height+pad))
    extended.paste(Image.fromarray(pixels),(0,0))
    extended.paste(source,(0,pad))
    # The same explicit near-transparent RGB repair, never a new alpha key.
    extended=recover_source(extended,{'low_alpha_rgb_repair':row.get('low_alpha_rgb_repair',False)})
    extended.paste(recover_source(source,row),(0,pad))
    return extended


def before_path(path):
    return PACKET/'before_runtime'/base.local(path).relative_to(ROOT/'art/overworld/runtime')


def original(path):
    archive = before_path(path)
    return Image.open(archive if archive.exists() else base.local(path)).convert('RGBA')


def expected_entry(row):
    old = row['original_manifest_entry']
    result = dict(old, atlas_region=[v*4 for v in old['atlas_region']],
                atlas_size=[v*4 for v in old['atlas_size']], source_trimmed=row['trimmed_path'],
                source_processing_manifest=base.resource(PACKET/'manifest.json'))
    if row.get('integrated_state_edit'):
        result.update(source_model='built_in_image_gen_original_with_integrated_physical_recruitment_state',
                      accessible_description=row['integrated_state_edit']['accessible_description'])
    return result


def registration(source, row, old):
    # Frontier's previous controlled copy included a procedural ring/pennant.
    # Measure its base geometry against the immediately preceding unclaimed cell.
    if row.get('integrated_state_edit'):
        entry=row['original_manifest_entry'];x,y,w,h=entry['atlas_region']
        old=original(entry['path']).crop((x-w,y,x,y+h))
    projected = project(source, dict(row, canvas_size=[48, 48], pixel_scale=1))
    diff = ImageChops.difference(old, projected)
    mask = ImageChops.multiply(old.getchannel('A').point(lambda a: 255 if a>200 else 0),
                              projected.getchannel('A').point(lambda a: 255 if a>200 else 0))
    result = dict(alpha_mae=ImageStat.Stat(diff.getchannel('A')).mean[0],
                  opaque_rgb_mae=sum(ImageStat.Stat(diff.convert('RGB'), mask).mean)/3)
    visible = ImageChops.lighter(old.getchannel('A'), projected.getchannel('A')).point(lambda a: 255 if a else 0)
    # Archived small atlases have quantization/filter differences for the older
    # two families. Report them honestly, never claim exact historical pixels.
    if result['alpha_mae']>1.0 or result['opaque_rgb_mae']>8.0:
        raise ValueError('Original registration changed')
    if 'frontier_mythic' in row['runtime_path'] and (diff.getchannel('A').getbbox() or ImageChops.multiply(diff.convert('RGB'),visible.convert('RGB')).getbbox()):
        raise ValueError('Original frontier registration changed')
    return result


def inputs():
    recipe = json.loads(RECIPE.read_text()); manifest = json.loads(MANIFEST.read_text())
    proof = json.loads((PACKET/'manifest.json').read_text()) if (PACKET/'manifest.json').exists() else {}
    paths = set(recipe['atlases'])
    if {Path(p).stem.removesuffix('_atlas') for p in paths}!=set(FAMILIES): raise ValueError('Atlas families changed')
    if recipe.get('schema_id')!='recruitment_site_cutout_recipe_v1' or len(recipe['assets'])!=36 or set(recipe['atlases'])!=paths or recipe['preserved_controls']:
        raise ValueError('Cohort changed')
    if {k for k,v in manifest['object_assets'].items() if v['path'] in paths}!=set(recipe['assets']):
        raise ValueError('Incomplete atlas membership')
    if set(recipe['state_mappings'])!={r['site_id'] for r in recipe['assets'].values()}:
        raise ValueError('Incomplete site coverage')
    if any(manifest['resource_site_sprites'][k]!=v for k,v in recipe['state_mappings'].items()):
        raise ValueError('State mapping changed')
    if len(recipe['state_mappings'])!=18 or sum(bool(r.get('integrated_state_edit')) for r in recipe['assets'].values())!=6:
        raise ValueError('Paired state coverage changed')
    for path, info in recipe['atlases'].items():
        count,*_ = FAMILIES[Path(path).stem.removesuffix('_atlas')]
        if info['before_size']!=[count*48,48] or list(original(path).size)!=info['before_size']:
            raise ValueError('Historical geometry changed')
        if base.digest(before_path(path) if before_path(path).exists() else base.local(path))!=info['before_sha256']:
            raise ValueError('Historical atlas changed')
        if base.digest(base.local(path)) not in (info['before_sha256'], proof.get('files',{}).get(path,{}).get('after_sha256')):
            raise ValueError('Unrecognized runtime edit')
        if sorted(r['original_manifest_entry']['atlas_region'][0] for r in recipe['assets'].values() if r['runtime_path']==path)!=list(range(0,count*48,48)):
            raise ValueError('Incomplete region coverage')
    sources = {}
    for path,sha in recipe['additional_sources'].items():
        if base.digest(base.local(path))!=sha:raise ValueError('Generated/provenance source changed')
    prior=recipe.get('mast_predecessor')
    if not prior:raise ValueError('Missing mast predecessor')
    if prior:
        for name in ('recipe','manifest'):
            path=base.local(prior[name+'_path'])
            if path!=PACKET/'before_mast_completion'/(name+'.json') or base.digest(path)!=prior[name+'_sha256']:
                raise ValueError('Mast predecessor changed')
        previous=json.loads(base.local(prior['recipe_path']).read_text())
        previous_proof=json.loads(base.local(prior['manifest_path']).read_text())
        if set(previous['assets'])!=set(recipe['assets']):raise ValueError('Mast cohort changed')
        modified={key for key,row in recipe['assets'].items() if row.get('mast_extension')}
        if modified!={'resource_site_veteran_three_gauge_chapter_foundry_controlled','resource_site_veteran_fog_keel_lastwatch_mooring_controlled'}:
            raise ValueError('Mast identity scope changed')
    for key, row in recipe['assets'].items():
        old = row['original_manifest_entry']; entry = manifest['object_assets'][key]
        if key not in recipe['state_mappings'][row['site_id']].values():raise ValueError('Exact state identity changed')
        strip = lambda v: {k:x for k,x in v.items() if k!='runtime_sha256'}
        if strip(entry) not in (strip(old), strip(expected_entry(row))): raise ValueError('Identity changed: '+key)
        path = base.local(old['source_generated'])
        if base.digest(path)!=row['source_sha256']: raise ValueError('Original painting changed: '+key)
        source = Image.open(path).convert('RGBA'); sources[key] = source
        if row['source_mode']!='genuine_rgba' or len(set(source.getchannel('A').getdata()))!=row['source_alpha_levels'] or row['source_alpha_levels'] not in (255,256):
            raise ValueError('Alpha policy changed')
        if list(source.size)!=row['source_size'] or list(source.getchannel('A').getbbox())!=row['source_crop']:
            raise ValueError('Source crop changed')
        _,limit,anchor,filt = FAMILIES[Path(old['path']).stem.removesuffix('_atlas')]
        fit = ImageOps.contain(source.crop(row['source_crop']), (limit,limit), getattr(Image.Resampling,filt)).size
        origin = [(48-fit[0])//2,(48-fit[1])//2 if anchor=='center' else anchor-fit[1]]
        if row['source_resize']!=list(fit) or row['canvas_origin']!=origin or row['fit_limit']!=limit or row['resampling']!=filt:
            raise ValueError('Logical fit/anchor changed')
        if row['canvas_size']!=[192,192] or row['pixel_scale']!=4 or row['runtime_path']!=old['path'] or old['atlas_region'][1:]!=[0,48,48]:
            raise ValueError('Density/filter changed')
        if row['registration_evidence']!=registration(source,row,owner.region(original(old['path']),old)):
            raise ValueError('Historical registration proof changed')
        trim = ROOT/'art/overworld/source/trimmed/cutout_recovery_20260909/recruitment_sites'/(key+'.png')
        if base.local(row['trimmed_path'])!=trim: raise ValueError('Unscoped derived path')
        if trim.exists() and base.digest(trim)!=proof.get('assets',{}).get(key,{}).get('trim_sha256'):
            raise ValueError('Unrecognized derived edit')
        if row.get('recovered_source_path'):
            master=base.local(row['recovered_source_path'])
            if master!=trim.parent/'sources'/(key+'.png'):raise ValueError('Unscoped master path')
            if master.exists() and base.digest(master)!=proof.get('assets',{}).get(key,{}).get('source_sha256'):
                raise ValueError('Unrecognized recovered master edit')
        if row.get('integrated_state_edit'):
            edit=row['integrated_state_edit']
            if 'frontier_mythic_habitats' not in old['path'] or not key.endswith('_controlled'):
                raise ValueError('Generated detail applied to wrong state')
            if base.local(edit['source'])!=PACKET/'edits'/(row['site_id'].removeprefix('site_')+'.png'):
                raise ValueError('Generated detail identity mismatch')
            if edit['source'] not in recipe['additional_sources']:raise ValueError('Untracked generated detail')
        if row.get('mast_extension'):
            edit=row['mast_extension']
            if edit['sheet'] not in recipe['additional_sources'] or recipe['additional_sources'][edit['sheet']]!=edit['sheet_sha256']:
                raise ValueError('Untracked mast sheet')
            master=base.local(row['recovered_extension_path'])
            if master!=trim.parent/'sources'/(key+'_complete.png'):raise ValueError('Unscoped extended master path')
            if master.exists() and base.digest(master)!=proof.get('assets',{}).get(key,{}).get('extension_sha256'):
                raise ValueError('Unrecognized extended master edit')
            mast_source(source,row)
            retained=PACKET/'before_mast_completion'/(key+'.png')
            if base.digest(retained)!=previous_proof['assets'][key]['trim_sha256']:
                raise ValueError('Mast predecessor paint changed')
    if prior:
        for key,row in recipe['assets'].items():
            if {k:v for k,v in row.items() if k not in ('mast_extension','recovered_extension_path')}!=previous['assets'][key]:
                raise ValueError('Accepted recruitment registration changed')
    return recipe, manifest, sources


def tool_hashes():
    return {str(p.relative_to(ROOT)): base.digest(p) for p in [Path(__file__),SHARED,STATE_TOOL,ROOT/'tools/prepare_overworld_cutout_art.py',ROOT/'tools/prepare_overworld_legacy_cutouts.py',PACKET/'generation.json']}


def prepare(output, install=False):
    output = output.resolve()
    if output==ROOT or output.is_relative_to(ROOT/'art'): raise ValueError('Preview must be outside art')
    recipe, manifest, sources = inputs(); output.mkdir(parents=True, exist_ok=False);(output/'sources').mkdir()
    atlases = {p:Image.new('RGBA',tuple(v*4 for v in r['before_size'])) for p,r in recipe['atlases'].items()}
    rows = {}; files = {}; results = {}
    for key,row in recipe['assets'].items():
        recovered=recover_source(sources[key],row)
        fixed = recover(sources[key],row); results[key] = fixed
        if row.get('recovered_source_path'):recovered.save(output/'sources'/(key+'.png'),optimize=True)
        if row.get('mast_extension'):mast_source(sources[key],row).save(output/'sources'/(key+'_complete.png'),optimize=True)
        fixed.save(output/(key+'.png'),optimize=True)
        rows[key] = dict(trim_sha256=base.digest(output/(key+'.png')),rgba_sha256=hashlib.sha256(fixed.tobytes()).hexdigest())
        if row.get('recovered_source_path'):rows[key]['source_sha256']=base.digest(output/'sources'/(key+'.png'))
        if row.get('mast_extension'):rows[key]['extension_sha256']=base.digest(output/'sources'/(key+'_complete.png'))
        x,y,_,_ = expected_entry(row)['atlas_region']; atlases[row['runtime_path']].paste(fixed,(x,y))
    previous=json.loads(base.local(recipe['mast_predecessor']['manifest_path']).read_text())
    if any(rows[key]!=previous['assets'][key] for key,row in recipe['assets'].items() if not row.get('mast_extension')):
        raise ValueError('Accepted neighbouring paint changed')
    for path,atlas in atlases.items():
        target = output/'runtime'/base.local(path).relative_to(ROOT/'art/overworld/runtime')
        target.parent.mkdir(parents=True,exist_ok=True); atlas.save(target,optimize=True)
        files[path] = dict(after_sha256=base.digest(target),prepared=str(target.relative_to(output)))
    for page,start in enumerate(range(0,36,6)):
        canvas=Image.new('RGB',(1440,800),'#336c3a');draw=ImageDraw.Draw(canvas)
        for j,(key,row) in enumerate(list(recipe['assets'].items())[start:start+6]):
            x,y=j%3*480,j//3*400
            old=owner.region(original(row['runtime_path']),row['original_manifest_entry']).resize((192,192),Image.Resampling.NEAREST)
            for col,im in enumerate((old,results[key])):canvas.paste(im,(x+col*225,y+30),im)
            draw.text((x+3,y+260),key.removeprefix('resource_site_'),fill='white')
            draw.text((x+3,y+285),'OLD 48 / ORIGINAL-SOURCE 192 (same map size)',fill='white')
        canvas.save(output/f'comparison_{page:02}.png')
    proof=dict(schema_id='recruitment_site_cutout_recovery_v1',recipe_sha256=base.digest(RECIPE),tools=tool_hashes(),assets=rows,files=files,
               processing='Original paint projected at fourfold density through measured historical logical fit; reviewed sheet-fragment removal, alpha 1..4 RGB decontamination, six foreground-only generated physical state details and two connected mast-top extensions from the exact original identity sheet. Body paint below the single-row sampling seam and all 34 neighbours stay exact. Original sources, state routes and gameplay unchanged. No procedural RGB or generated backing in runtime.')
    if install:
        for path,info in files.items():
            archive=before_path(path);archive.parent.mkdir(parents=True,exist_ok=True)
            if not archive.exists():shutil.copy2(base.local(path),archive)
            shutil.copyfile(output/info['prepared'],base.local(path))
        for key,row in recipe['assets'].items():
            dest=base.local(row['trimmed_path']);dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(output/(key+'.png'),dest)
            if row.get('recovered_source_path'):
                dest=base.local(row['recovered_source_path']);dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(output/'sources'/(key+'.png'),dest)
            if row.get('mast_extension'):
                shutil.copyfile(output/'sources'/(key+'_complete.png'),base.local(row['recovered_extension_path']))
            manifest['object_assets'][key]=dict(expected_entry(row),runtime_sha256=files[row['runtime_path']]['after_sha256'])
        MANIFEST.write_text(owner.manifest_text(manifest,recipe['assets']))
        (PACKET/'manifest.json').write_text(json.dumps(proof,indent=2)+'\n')
    (output/'report.json').write_text(json.dumps(proof,indent=2)+'\n')
    return dict(installed=install,assets=len(rows),atlases=len(files))


def validate_assets():
    recipe,manifest,sources=inputs();proof=json.loads((PACKET/'manifest.json').read_text())
    if proof['schema_id']!='recruitment_site_cutout_recovery_v1' or proof['recipe_sha256']!=base.digest(RECIPE) or proof['tools']!=tool_hashes():raise ValueError('Preparation provenance changed')
    if set(proof['assets'])!=set(recipe['assets']) or set(proof['files'])!=set(recipe['atlases']):raise ValueError('Incomplete proof')
    atlases={p:Image.open(base.local(p)).convert('RGBA') for p in recipe['atlases']}
    for path,info in recipe['atlases'].items():
        if base.digest(before_path(path))!=info['before_sha256'] or list(atlases[path].size)!=[v*4 for v in info['before_size']] or base.digest(base.local(path))!=proof['files'][path]['after_sha256']:raise ValueError('Atlas provenance changed')
    for key,row in recipe['assets'].items():
        fixed=recover(sources[key],row);entry=manifest['object_assets'][key];trim=base.local(row['trimmed_path'])
        if entry!=dict(expected_entry(row),runtime_sha256=proof['files'][entry['path']]['after_sha256']):raise ValueError('Runtime ownership changed')
        if owner.region(atlases[entry['path']],entry).tobytes()!=fixed.tobytes() or Image.open(trim).convert('RGBA').tobytes()!=fixed.tobytes():raise ValueError('Source reconstruction failed')
        expected=dict(trim_sha256=base.digest(trim),rgba_sha256=hashlib.sha256(fixed.tobytes()).hexdigest())
        if row.get('recovered_source_path'):
            source_path=base.local(row['recovered_source_path'])
            if Image.open(source_path).convert('RGBA').tobytes()!=recover_source(sources[key],row).tobytes():raise ValueError('Recovered master changed')
            expected['source_sha256']=base.digest(source_path)
        if row.get('mast_extension'):
            path=base.local(row['recovered_extension_path'])
            if Image.open(path).convert('RGBA').tobytes()!=mast_source(sources[key],row).tobytes():raise ValueError('Extended master changed')
            expected['extension_sha256']=base.digest(path)
        if proof['assets'][key]!=expected:raise ValueError('Paint proof changed')
    previous=json.loads(base.local(recipe['mast_predecessor']['manifest_path']).read_text())
    if any(proof['assets'][key]!=previous['assets'][key] for key,row in recipe['assets'].items() if not row.get('mast_extension')):
        raise ValueError('Accepted neighbouring paint changed')
    return {k:dict(ok=True,errors=[]) for k in recipe['assets']}


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path,required=True);parser.add_argument('--install',action='store_true')
    args=parser.parse_args();print(json.dumps(prepare(args.output,args.install)))
