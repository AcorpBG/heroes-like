#!/usr/bin/env python3
"""Recover 54 route/arcane paintings with unchanged logical registration.

Original RGBA is retained, except two generated controlled edits and seven
reviewed foreground-only physical seal edits. Historical coarse state ink is
retained in the predecessor proof, not redrawn or exposed by the new variants.
No gameplay owner or state resolver is modified.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil

import numpy as np
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[1]
PACKET=ROOT/'art/overworld/source/generated/cutout_recovery_20260909/route_arcane'
RECIPE=PACKET/'recipe.json'
MANIFEST=ROOT/'art/overworld/manifest.json'
SHARED=ROOT/'tools/prepare_overworld_landmark_cutouts.py'
spec=importlib.util.spec_from_file_location('route_original_recovery',SHARED)
shared=importlib.util.module_from_spec(spec);spec.loader.exec_module(shared)
base=shared.base;owner=shared.owner;project=shared.project
FAMILIES={'coast_route_operational':(6,44,'center','LANCZOS'),
          'frontier_marker_landmarks':(3,42,'south','BILINEAR'),
          'elite_neutral_dwelling':(4,46,'center','BILINEAR'),
          'elder_wild_sanctuaries':(8,44,'center','LANCZOS'),
          'pactwright_waydesk_state':(2,43,'center','BILINEAR'),
          'mireglass_counterpoint_state':(12,40,'south','BILINEAR'),
          'sevenfold_high_arcanum':(7,44,'south','BILINEAR'),
          'horizon_company_field_musters':(12,44,'center','BILINEAR')}


def before_path(path):
    return PACKET/'before_runtime'/base.local(path).relative_to(ROOT/'art/overworld/runtime')


def original(path):
    archived=before_path(path)
    return Image.open(archived if archived.exists() else base.local(path)).convert('RGBA')


def expected_entry(row):
    old=row['original_manifest_entry']
    result=dict(old,atlas_region=[v*4 for v in old['atlas_region']],atlas_size=[v*4 for v in old['atlas_size']],
                source_trimmed=row['trimmed_path'],source_processing_manifest=base.resource(PACKET/'manifest.json'))
    if row.get('integrated_state_edit'):
        result.update(source_model='built_in_image_gen_original_with_localized_generated_physical_state_seal',
                      accessible_description=row['integrated_state_edit']['accessible_description'])
    return result


def state_patch_mask(size,edit):
    """Reviewed compositing support only; these masks never supply painted RGB."""
    from PIL import ImageFilter
    mask=Image.new('L',size)
    for patch in edit['patches']:
        support=Image.new('L',size);draw=ImageDraw.Draw(support)
        if 'rect' in patch:
            l,t,r,b=patch['rect'];draw.rectangle((l,t,r-1,b-1),fill=255)
        else:
            draw.polygon([tuple(p) for p in patch['polygon']],fill=255)
        # Feather inward, never sample an unreviewed pixel outside the support.
        blurred=support.filter(ImageFilter.GaussianBlur(patch['feather']))
        a=np.asarray(support);b=np.asarray(blurred)
        feathered=np.where(a==255,np.clip((b.astype(float)-127)*2,0,255),0).astype('uint8')
        mask=Image.fromarray(np.maximum(np.asarray(mask),feathered))
    return mask


def integrated_state_source(source,edit):
    raw=Image.open(base.local(edit['source'])).convert('RGB')
    if list(raw.size)!=edit['generated_size']:raise ValueError('Generated state canvas changed')
    raw=raw.resize(source.size,Image.Resampling.LANCZOS)
    mask=state_patch_mask(source.size,edit)
    original=np.asarray(source);paint=np.asarray(raw);weight=np.asarray(mask,dtype=float)[:,:,None]/255
    out=original.copy()
    out[:,:,:3]=np.rint(original[:,:,:3]*(1-weight)+paint*weight).astype('uint8')
    if edit.get('attached_silhouette_extension'):
        out[:,:,3]=np.maximum(original[:,:,3],np.asarray(mask))
    elif np.any(original[:,:,3][np.asarray(mask)>0]<240):
        raise ValueError('Foreground-only patch reached background')
    return Image.fromarray(out)


def recover_source(source,row):
    if row.get('integrated_state_edit'):
        return integrated_state_source(source,row['integrated_state_edit'])
    edit=row.get('generated_edit')
    if not edit:return source.copy()
    raw=Image.open(base.local(edit['source'])).convert('RGB')
    fixed=base.recover_cell(raw,radius=4,neutral_material=True,protected_rects=edit['protected_rects'])
    a=np.array(fixed)
    for x,y in edit['background_corner_points']:a[y,x]=0
    if edit.get('original_smoke_rects'):
        smoke=np.asarray(Image.open(base.local(edit['smoke_source'])).convert('RGBA'))
        for l,t,r,b in edit['original_smoke_rects']:a[t:b,l:r]=smoke[t:b,l:r]
        # Coordinates are the reviewed backing between rear wooden rails only.
        for x,y in edit['rail_backing_points']:a[y,x]=0
    return Image.fromarray(a)


def recover(source,row):
    fixed=project(recover_source(source,row),row)
    if row.get('state_ink') and not row.get('integrated_state_edit'):
        old=row['original_manifest_entry'];ink=owner.region(original(old['path']),old)
        # Preserve existing six wax marks / counterseal, not a new drawing.
        stamp=Image.new('RGBA',(48,48))
        for index in row['state_ink']['pixels']:
            point=(index%48,index//48);stamp.putpixel(point,ink.getpixel(point))
        mask=Image.new('L',(48,48));mask.putdata([255 if i in row['state_ink']['pixels'] else 0 for i in range(2304)])
        fixed.paste(stamp.resize((192,192),Image.Resampling.NEAREST),(0,0),mask.resize((192,192),Image.Resampling.NEAREST))
    return fixed


def registration(source,row):
    from PIL import ImageChops,ImageStat
    old=row['original_manifest_entry'];atlas=original(old['path']);x,y,w,h=old['atlas_region']
    expected=atlas.crop((x-48 if row.get('state_ink') else x,y,x if row.get('state_ink') else x+w,y+h))
    logical=dict(row,source_crop=row['historical_crop'],source_resize=row['historical_resize'],canvas_size=[48,48],pixel_scale=1)
    projected=project(source,logical);diff=ImageChops.difference(projected,expected)
    mask=ImageChops.multiply(expected.getchannel('A').point(lambda a:255 if a>200 else 0),projected.getchannel('A').point(lambda a:255 if a>200 else 0))
    return dict(alpha_mae=ImageStat.Stat(diff.getchannel('A')).mean[0],opaque_rgb_mae=sum(ImageStat.Stat(diff.convert('RGB'),mask).mean)/3)


def inputs():
    recipe=json.loads(RECIPE.read_text());manifest=json.loads(MANIFEST.read_text())
    proof=json.loads((PACKET/'manifest.json').read_text()) if (PACKET/'manifest.json').exists() else {}
    if recipe.get('schema_id')!='route_arcane_cutout_recipe_v1' or len(recipe['assets'])!=54:raise ValueError('Cohort changed')
    paths=set(recipe['atlases'])
    if {Path(p).stem.removesuffix('_atlas') for p in paths}!=set(FAMILIES):raise ValueError('Atlas families changed')
    if {k for k,v in manifest['object_assets'].items() if v['path'] in paths}!=set(recipe['assets']):raise ValueError('Incomplete atlas membership')
    if set(recipe['state_mappings'])!={v['site_id'] for v in recipe['assets'].values()}:raise ValueError('State coverage changed')
    if any(manifest['resource_site_sprites'][k]!=v for k,v in recipe['state_mappings'].items()):raise ValueError('State mapping changed')
    for path,info in recipe['atlases'].items():
        count,*_=FAMILIES[Path(path).stem.removesuffix('_atlas')]
        if info['before_size']!=[count*48,48] or list(original(path).size)!=info['before_size']:raise ValueError('Historical atlas geometry changed')
        if base.digest(before_path(path) if before_path(path).exists() else base.local(path))!=info['before_sha256']:raise ValueError('Historical atlas changed')
        if base.digest(base.local(path)) not in (info['before_sha256'],proof.get('files',{}).get(path,{}).get('after_sha256')):raise ValueError('Unrecognized runtime edit')
        if sorted(v['original_manifest_entry']['atlas_region'][0] for v in recipe['assets'].values() if v['runtime_path']==path)!=list(range(0,count*48,48)):raise ValueError('Atlas coverage changed')
    for path,sha in recipe['additional_sources'].items():
        if base.digest(base.local(path))!=sha:raise ValueError('Generated/reference source changed: '+path)
    sources={}
    for key,row in recipe['assets'].items():
        old=row['original_manifest_entry'];entry=manifest['object_assets'][key]
        clean=lambda v:{k:x for k,x in v.items() if k!='runtime_sha256'}
        previous_row={k:v for k,v in row.items() if k!='integrated_state_edit'}
        if clean(entry) not in (clean(old),clean(expected_entry(previous_row)),clean(expected_entry(row))):raise ValueError('Identity changed: '+key)
        if key not in recipe['state_mappings'][row['site_id']].values():raise ValueError('Exact site/art relation changed')
        if row['runtime_path']!=old['path'] or old['atlas_region'][1:]!=[0,48,48]:raise ValueError('Unscoped atlas change')
        path=base.local(old['source_generated'])
        if base.digest(path)!=row['source_sha256']:raise ValueError('Original painting changed: '+key)
        source=Image.open(path).convert('RGBA');sources[key]=source
        if len(set(source.getchannel('A').getdata()))!=row['source_alpha_levels'] or list(source.size)!=row['source_size'] or list(source.getbbox())!=row['historical_crop']:raise ValueError('Original alpha/registration changed')
        _,limit,anchor,filter_name=FAMILIES[Path(old['path']).stem.removesuffix('_atlas')]
        l,t,r,b=row['source_crop'];fit=[round((r-l)*limit/max(r-l,b-t)),round((b-t)*limit/max(r-l,b-t))]
        origin=[(48-fit[0])//2,48-fit[1] if anchor=='south' else (48-fit[1])//2]
        if row['source_resize']!=fit or row['canvas_origin']!=origin or row['fit_limit']!=limit or row['resampling']!=filter_name:raise ValueError('Logical fit/anchor/filter changed')
        if row['canvas_size']!=[192,192] or row['pixel_scale']!=4:raise ValueError('Density changed')
        if row['registration_evidence']!=registration(source,row):raise ValueError('Historical registration evidence changed')
        for field,sha in [('trimmed_path','trim_sha256'),('recovered_source_path','source_sha256')]:
            dest=base.local(row[field]);trim=ROOT/'art/overworld/source/trimmed/cutout_recovery_20260909/route_arcane'
            expected=trim/('sources' if field=='recovered_source_path' else '')/(key+'.png')
            if dest!=expected:raise ValueError('Unscoped derivative path')
            if dest.exists() and base.digest(dest)!=proof.get('assets',{}).get(key,{}).get(sha):raise ValueError('Unrecognized derived edit')
    return recipe,manifest,sources


def tool_hashes():
    return dict(processing_tool_sha256=base.digest(Path(__file__)),shared_tool_sha256=base.digest(SHARED),shared_dependencies=shared.tool_hashes(),generation_record_sha256=base.digest(PACKET/'generation.json'))


def prepare(output,install=False):
    output=output.resolve()
    if output==ROOT.resolve() or output.is_relative_to((ROOT/'art').resolve()):raise ValueError('Preview must be outside art')
    recipe,manifest,sources=inputs();output.mkdir(parents=True,exist_ok=False);(output/'sources').mkdir()
    atlases={p:Image.new('RGBA',tuple(v*4 for v in info['before_size'])) for p,info in recipe['atlases'].items()};rows={};files={};results={}
    for key,row in recipe['assets'].items():
        source=recover_source(sources[key],row);fixed=recover(sources[key],row);results[key]=fixed
        source.save(output/'sources'/(key+'.png'),optimize=True);fixed.save(output/(key+'.png'),optimize=True)
        rows[key]=dict(trim_sha256=base.digest(output/(key+'.png')),source_sha256=base.digest(output/'sources'/(key+'.png')),rgba_sha256=hashlib.sha256(fixed.tobytes()).hexdigest(),metrics=shared.shared.metrics(fixed))
        x,y,_,_=expected_entry(row)['atlas_region'];atlases[row['runtime_path']].paste(fixed,(x,y))
    for path,atlas in atlases.items():
        target=output/'runtime'/base.local(path).relative_to(ROOT/'art/overworld/runtime');target.parent.mkdir(parents=True,exist_ok=True);atlas.save(target,optimize=True)
        files[path]=dict(after_sha256=base.digest(target),prepared=str(target.relative_to(output)))
    for page,start in enumerate(range(0,54,4)):
        canvas=Image.new('RGB',(1440,650),'#334c3a');draw=ImageDraw.Draw(canvas)
        for j,(key,row) in enumerate(list(recipe['assets'].items())[start:start+4]):
            x,y=(j%2)*720,(j//2)*325;old=row['original_manifest_entry']
            for col,im in enumerate((owner.region(original(old['path']),old).resize((192,192),Image.Resampling.NEAREST),results[key],Image.open(output/'sources'/(key+'.png')))):
                im=im.copy();im.thumbnail((232,270),Image.Resampling.LANCZOS);canvas.paste(im,(x+col*240,y),im)
            draw.text((x+3,y+280),key,fill='white');draw.text((x+3,y+296),'OLD 48 / RECOVERED 192 / SOURCE MASTER',fill='white')
        canvas.save(output/f'comparison_{page:02}.png')
    proof=dict(schema_id='route_arcane_cutout_recovery_v1',recipe_sha256=base.digest(RECIPE),**tool_hashes(),assets=rows,files=files)
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
    (output/'report.json').write_text(json.dumps(proof,indent=2)+'\n');return dict(installed=install,assets=len(rows),atlases=len(files))


def validate_assets():
    recipe,manifest,sources=inputs();proof=json.loads((PACKET/'manifest.json').read_text());reports={}
    if proof['schema_id']!='route_arcane_cutout_recovery_v1' or proof['recipe_sha256']!=base.digest(RECIPE) or any(proof[k]!=v for k,v in tool_hashes().items()):raise ValueError('Preparation provenance changed')
    if set(proof['assets'])!=set(recipe['assets']) or set(proof['files'])!=set(recipe['atlases']):raise ValueError('Incomplete proof')
    atlases={p:Image.open(base.local(p)).convert('RGBA') for p in recipe['atlases']}
    for path,info in recipe['atlases'].items():
        if base.digest(before_path(path))!=info['before_sha256'] or list(atlases[path].size)!=[v*4 for v in info['before_size']] or base.digest(base.local(path))!=proof['files'][path]['after_sha256']:raise ValueError('Atlas provenance changed')
    for key,row in recipe['assets'].items():
        source=recover_source(sources[key],row);fixed=recover(sources[key],row);entry=manifest['object_assets'][key];trim=base.local(row['trimmed_path']);master=base.local(row['recovered_source_path'])
        if entry!=dict(expected_entry(row),runtime_sha256=proof['files'][entry['path']]['after_sha256']):raise ValueError('Runtime ownership changed')
        if owner.region(atlases[entry['path']],entry).tobytes()!=fixed.tobytes() or Image.open(trim).convert('RGBA').tobytes()!=fixed.tobytes() or Image.open(master).convert('RGBA').tobytes()!=source.tobytes():raise ValueError('Source reconstruction failed')
        expected=dict(trim_sha256=base.digest(trim),source_sha256=base.digest(master),rgba_sha256=hashlib.sha256(fixed.tobytes()).hexdigest(),metrics=shared.shared.metrics(fixed))
        if proof['assets'][key]!=expected:raise ValueError('Paint proof changed')
        reports[key]=dict(ok=True,errors=[])
    validate_integrated_predecessor(recipe,proof,atlases)
    return reports


def validate_integrated_predecessor(recipe,proof,atlases):
    packet=PACKET.parent/'integrated_seals'
    lock=json.loads((packet/'previous/lock.json').read_text())
    for path,sha in lock['files'].items():
        if base.digest(ROOT/path)!=sha:raise ValueError('Frozen predecessor changed')
    previous=json.loads((packet/'previous/manifest.json').read_text())
    old_recipe=json.loads((packet/'previous/recipe.json').read_text())
    selected={k for k,r in recipe['assets'].items() if r.get('integrated_state_edit')}
    if len(selected)!=7 or selected!=set(lock['selected_asset_ids']):raise ValueError('Integrated seal cohort changed')
    if {k:{f:v for f,v in r.items() if f!='integrated_state_edit'} for k,r in recipe['assets'].items()}!=old_recipe['assets']:raise ValueError('Historical source or registration changed')
    changed_paths={recipe['assets'][k]['runtime_path'] for k in selected}
    for path in recipe['atlases']:
        if path not in changed_paths and proof['files'][path]!=previous['files'][path]:raise ValueError('Unrelated atlas changed')
    for key,row in recipe['assets'].items():
        if key in selected:
            if proof['assets'][key]['rgba_sha256']==previous['assets'][key]['rgba_sha256']:raise ValueError('State edit not implemented')
        else:
            if proof['assets'][key]!=previous['assets'][key]:raise ValueError('Unrelated painting changed')
            if row['runtime_path'] in changed_paths:
                old_atlas=Image.open(packet/'previous'/Path(row['runtime_path']).name).convert('RGBA')
                entry=expected_entry(row)
                if owner.region(atlases[row['runtime_path']],entry).tobytes()!=owner.region(old_atlas,entry).tobytes():raise ValueError('Base neighbor changed')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path,required=True);parser.add_argument('--install',action='store_true');args=parser.parse_args();print(json.dumps(prepare(args.output,args.install)))
