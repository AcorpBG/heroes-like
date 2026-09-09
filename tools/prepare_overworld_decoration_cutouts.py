#!/usr/bin/env python3
"""Recover original decorative paintings without changing game mappings.

The recipe preserves the measured original cell-to-canvas scale and placement.
Only explicitly recorded translations may accommodate previously clipped art.
"""
import argparse
import importlib.util
import json
from pathlib import Path
import re
import shutil

from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
PACKET=ROOT/'art/overworld/source/generated/cutout_recovery_20260909/decorations'
RECIPE=PACKET/'recipe.json'
ART_MANIFEST=ROOT/'art/overworld/manifest.json'
MATERIAL_ENGINE=ROOT/'tools/prepare_overworld_cutout_pool.py'
_spec=importlib.util.spec_from_file_location('original_material_recovery',MATERIAL_ENGINE)
material=importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(material)
base=material.base


def source_cell(sheet,row,strict=False):
    l,t,r,b=row['source_rect']
    regions=row['chromatic_source_rects']
    result=material.material_cell(sheet.crop((l,t,r,b)),[(x-l,y-t,xx-l,yy-t) for x,y,xx,yy in regions])
    bounds=result.getbbox()
    if strict and (not bounds or bounds[0]<=0 or bounds[1]<=0 or bounds[2]>=result.width or bounds[3]>=result.height):
        raise ValueError('Source rectangle clips paint or retains a divider: '+str(row['source_rect']))
    return result


def before_image(row):
    path=base.local(row['original_manifest_entry']['path'])
    before=PACKET/(path.stem+'_before.png')
    return Image.open(before if before.exists() else path).convert('RGBA')


def remove_neighbor(row):
    source=before_image(row);result=Image.new('RGBA',(512,512))
    l,t,r,b=row['keep_canvas_rect'];result.paste(source.crop((l,t,r,b)),(l,t))
    return result


def trimmed(result,row):
    if 'trim_canvas_origin' not in row:return result
    x,y=row['trim_canvas_origin'];w,h=row['trim_size']
    return result.crop((x,y,x+w,y+h))


def replacement(row):
    spec=row['generated_replacement']
    source=Image.open(base.local(spec['path'])).convert('RGB')
    left,top,right,bottom=spec['source_rect']
    source=source.crop((left,top,right,bottom))
    extracted=material.material_cell(source,[(l-left,t-top,r-left,b-top) for l,t,r,b in spec['chromatic_source_rects']])
    bounds=extracted.getbbox()
    if not bounds or bounds[0]<=0 or bounds[1]<=0 or bounds[2]>=source.width or bounds[3]>=source.height:raise ValueError('Generated subject reaches source boundary')
    l,t,r,b=spec['fit_rect'];painting=extracted.crop(bounds)
    scale=min((r-l)/painting.width,(b-t)/painting.height)
    size=(round(painting.width*scale),round(painting.height*scale))
    painting=painting.resize(size,Image.Resampling.LANCZOS)
    canvas=Image.new('RGBA',(512,512));canvas.paste(painting,(l+(r-l-size[0])//2,t+(b-t-size[1])//2))
    return canvas


def expected_manifest_entry(row):
    entry=dict(row['original_manifest_entry'])
    if row.get('mode')=='generated_replacement':
        entry.pop('source_generated_atlas')
        entry['source_generated']=row['generated_replacement']['path']
        entry['source_model']='built_in_image_gen_original_heatglass_haze_replacement'
    return entry


def canvas_bounds(row):
    nw,nh=row['original_resize'];ox,oy=row['original_origin'];dx,dy=row['canvas_shift']
    return (nw-ox-dx,nh-oy-dy,nw-ox-dx+512,nh-oy-dy+512)


def clipped(extended,row):
    bounds=extended.getbbox();crop=canvas_bounds(row)
    if not bounds or not (crop[0]+3<=bounds[0] and crop[1]+3<=bounds[1] and bounds[2]<=crop[2]-3 and bounds[3]<=crop[3]-3):
        return {'painted_bounds':bounds,'crop':crop}
    return {}


def extended_canvas(sheet,row,strict=False):
    l,t,r,b=row['original_cell'];w,h=r-l,b-t
    x,y,_,_=row['source_rect']
    holder=Image.new('RGBA',(3*w,3*h))
    holder.paste(source_cell(sheet,row,strict),(w+x-l,h+y-t))
    nw,nh=row['original_resize']
    # Integer multiples retain the original bilinear pixel-center transform.
    return holder.resize((3*nw,3*nh),Image.Resampling.BILINEAR)


def recover(sheet,row):
    if row.get('mode')=='retain_canvas_remove_neighbor':return remove_neighbor(row)
    if row.get('mode')=='generated_replacement':return replacement(row)
    canvas=extended_canvas(sheet,row,strict=True)
    issue=clipped(canvas,row)
    if issue:raise ValueError('Refusing clipped painting: '+str(issue))
    return canvas.crop(canvas_bounds(row))


def load_inputs():
    recipe=json.loads(RECIPE.read_text())
    manifest=json.loads(ART_MANIFEST.read_text())
    proof_path=PACKET/'manifest.json'
    proof=json.loads(proof_path.read_text()) if proof_path.exists() else {}
    if recipe.get('schema_id')!='original_decoration_sheet_recipe_v1':raise ValueError('Unknown decoration recipe')
    sheets={};members=set()
    for key,row in recipe['sources'].items():
        path=base.local(row['path'])
        if base.digest(path)!=row['sha256']:raise ValueError('Original sheet hash changed: '+key)
        ids={k for k,v in manifest['object_assets'].items() if v.get('source_generated_atlas')==row['path']}
        ids.update(k for k,v in recipe['assets'].items() if v.get('mode')=='generated_replacement' and v['source']==key)
        if ids!=set(row['members']):raise ValueError('Source membership changed: '+key)
        members.update(ids);sheets[key]=Image.open(path).convert('RGB')
    if members!=set(recipe['assets'])|set(recipe['preserved_controls']):raise ValueError('Incomplete decoration sheet membership')
    if set(recipe['assets'])&set(recipe['preserved_controls']):raise ValueError('Asset cannot also be an unchanged control')
    for key,row in recipe['preserved_controls'].items():
        entry=manifest['object_assets'][key]
        if entry!=row['original_manifest_entry'] or base.digest(base.local(entry['path']))!=row['before_sha256']:raise ValueError('Previously clean archetype changed: '+key)
        if base.digest(base.local(entry['source_trimmed']))!=row['before_trim_sha256']:raise ValueError('Clean archetype trim changed: '+key)
    for key,row in recipe['assets'].items():
        entry=manifest['object_assets'][key]
        original={k:v for k,v in entry.items() if k not in ('source_processing_manifest','runtime_sha256')}
        if original not in (row['original_manifest_entry'],expected_manifest_entry(row)):raise ValueError('Identity/placement metadata changed: '+key)
        if row.get('mode')=='generated_replacement':
            spec=row['generated_replacement'];path=base.local(spec['path'])
            if base.digest(path)!=spec['sha256']:raise ValueError('Replacement source changed: '+key)
            generation=json.loads(base.local(spec['generation_manifest']).read_text())
            if generation['generated_source']!=spec['path'] or generation['generated_source_sha256']!=spec['sha256']:raise ValueError('Replacement generation provenance mismatch: '+key)
            if spec['fit_rect']!=[20,65,492,423] or key!='decor_ash_heatglass_haze_sheet':raise ValueError('Unreviewed replacement geometry: '+key)
        elif entry['source_generated_atlas']!=recipe['sources'][row['source']]['path']:raise ValueError('Wrong source: '+key)
        runtime=base.local(entry['path']);before=PACKET/(key+'_before.png')
        if base.digest(before if before.exists() else runtime)!=row['before_sha256']:raise ValueError('Before image changed: '+key)
        if base.digest(runtime) not in (row['before_sha256'],proof.get('assets',{}).get(key,{}).get('runtime_sha256')):raise ValueError('Unrecognized runtime edit: '+key)
        trim=base.local(entry['source_trimmed'])
        if base.digest(trim) not in (row['before_trim_sha256'],proof.get('assets',{}).get(key,{}).get('trim_sha256')):raise ValueError('Unrecognized trim edit: '+key)
        before_trim=PACKET/(key+'_before_trim.png')
        if before_trim.exists() and base.digest(before_trim)!=row['before_trim_sha256']:raise ValueError('Retained original trim changed: '+key)
        if row.get('mode','recover_original') not in ('recover_original','retain_canvas_remove_neighbor','generated_replacement'):raise ValueError('Unknown recovery mode: '+key)
        for field,count in [('original_cell',4),('original_resize',2),('original_origin',2),('canvas_shift',2)]:
            values=row[field]
            if len(values)!=count or any(type(v)!=int for v in values):raise ValueError('Invalid integer geometry: '+key+'/'+field)
        cl,ct,cr,cb=row['original_cell'];nw,nh=row['original_resize']
        if not (0<=cl<cr<=sheets[row['source']].width and 0<=ct<cb<=sheets[row['source']].height and 0<nw<=512 and 0<nh<=512):raise ValueError('Invalid original cell geometry: '+key)
        if row.get('mode')=='retain_canvas_remove_neighbor':
            if row['keep_canvas_rect']!=[0,70,512,512] or key!='decor_underway_brasspipe_cavern_wall':raise ValueError('Unreviewed neighbor removal: '+key)
        l,t,r,b=row['source_rect'];sw,sh=sheets[row['source']].size
        if not (0<=l<r<=sw and 0<=t<b<=sh):raise ValueError('Invalid source bounds: '+key)
        for x,y,xx,yy in row.get('chromatic_source_rects',[]):
            if not (l<=x<xx<=r and t<=y<yy<=b):raise ValueError('Material region outside painting: '+key)
    return recipe,manifest,sheets


def prepare(output,install=False,asset_ids=None):
    if install and asset_ids:raise ValueError('Only whole reviewed cohorts may be installed')
    destination=output.resolve()
    if destination==ROOT.resolve() or destination.is_relative_to((ROOT/'art').resolve()):raise ValueError('Preview must be outside registered art')
    recipe,manifest,sheets=load_inputs()
    if asset_ids and not set(asset_ids)<=set(recipe['assets']):raise ValueError('Unknown preview asset')
    output.mkdir(parents=True,exist_ok=True)
    results={};rows={};issues={}
    for key,row in recipe['assets'].items():
        if asset_ids and key not in asset_ids:continue
        if row.get('mode') in ('retain_canvas_remove_neighbor','generated_replacement'):
            result=recover(sheets[row['source']],row);results[key]=result
            path=output/(key+'.png');result.save(path,optimize=True)
            rows[key]={'runtime_sha256':base.digest(path),'before_sha256':row['before_sha256'],'runtime':manifest['object_assets'][key]['path'],'after':base.inspect(result)}
            continue
        extended=extended_canvas(sheets[row['source']],row,strict=install)
        issue=clipped(extended,row)
        if issue:issues[key]=issue
        result=extended.crop(canvas_bounds(row));results[key]=result
        path=output/(key+'.png');result.save(path,optimize=True)
        rows[key]={'runtime_sha256':base.digest(path),'before_sha256':row['before_sha256'],'runtime':manifest['object_assets'][key]['path'],'after':base.inspect(result)}
    for source in sheets:
        selected={k:v for k,v in results.items() if recipe['assets'][k]['source']==source}
        if selected:material.contact_sheet(selected,output/('sheet_'+source+'.png'))
    (output/'report.json').write_text(json.dumps({'installed':install and not issues,'assets':rows,'clipped_or_edge_subjects':issues},indent=2)+'\n')
    if issues and install:raise ValueError('Refusing clipped paintings: '+', '.join(issues))
    if install:
        for key in results:
            entry=manifest['object_assets'][key];before=PACKET/(key+'_before.png')
            if not before.exists():shutil.copy2(base.local(entry['path']),before)
            before_trim=PACKET/(key+'_before_trim.png')
            if not before_trim.exists() and recipe['assets'][key]['before_trim_sha256']!=recipe['assets'][key]['before_sha256']:shutil.copy2(base.local(entry['source_trimmed']),before_trim)
            shutil.copyfile(output/(key+'.png'),base.local(entry['path']))
            trimmed(results[key],recipe['assets'][key]).save(base.local(entry['source_trimmed']),optimize=True)
            rows[key]['trim_sha256']=base.digest(base.local(entry['source_trimmed']))
            rows[key]['before']=base.resource(before)
            if recipe['assets'][key].get('mode')=='generated_replacement':
                entry.clear();entry.update(expected_manifest_entry(recipe['assets'][key]))
            entry.update(source_processing_manifest=base.resource(PACKET/'manifest.json'),runtime_sha256=rows[key]['runtime_sha256'])
        proof={'schema_id':'original_decoration_recovery_v1','owner_approval':'2026-09-09 approved deterministic original-image recovery','recipe':base.resource(RECIPE),'recipe_sha256':base.digest(RECIPE),'processing_tool':'tools/prepare_overworld_decoration_cutouts.py','processing_tool_sha256':base.digest(Path(__file__)),'material_engine_sha256':base.digest(MATERIAL_ENGINE),'matte_engine_sha256':base.digest(material.ENGINE),'sources':recipe['sources'],'processing':'Original paintings, inspected source dividers, original proportional bilinear cell scale and placement. Explicit canvas translations recover clipped paintings; original painted material interiors retained. No game/content/mapping changes.','assets':rows}
        proof['preserved_controls']=recipe['preserved_controls']
        proof['processing']+=' One owner-approved original Heatglass replacement uses inspected generated source, source-derived alpha and proportional fit into its previous painted bounds. Fifteen already-clean archetypes are byte-preserved; Brasspipe only loses a detached neighboring cliff sliver, retaining its original trim dimensions and canvas placement.'
        proof['generated_replacements']={key:dict(row['generated_replacement'],generation_manifest_sha256=base.digest(base.local(row['generated_replacement']['generation_manifest']))) for key,row in recipe['assets'].items() if row.get('mode')=='generated_replacement'}
        (PACKET/'manifest.json').write_text(json.dumps(proof,indent=2)+'\n')
        text=ART_MANIFEST.read_text()
        for key in results:
            pattern=r'(?ms)^    "'+re.escape(key)+r'": \{\n.*?^    \}(?=,?\n)'
            replacement='    '+json.dumps(key)+': '+json.dumps(manifest['object_assets'][key],indent=2).replace('\n','\n    ')
            text,count=re.subn(pattern,lambda match:replacement,text)
            if count!=1:raise ValueError('Expected one manifest row: '+key)
        if json.loads(text)!=manifest:raise ValueError('Unrelated manifest change')
        ART_MANIFEST.write_text(text)
    return {'assets':len(rows),'clipped_or_edge_subjects':issues,'installed':install}


def validate_assets():
    recipe,manifest,sheets=load_inputs();proof=json.loads((PACKET/'manifest.json').read_text())
    for field,path in [('recipe_sha256',RECIPE),('processing_tool_sha256',Path(__file__)),('material_engine_sha256',MATERIAL_ENGINE),('matte_engine_sha256',material.ENGINE)]:
        if proof.get(field)!=base.digest(path):raise ValueError('Recovery provenance changed: '+field)
    if proof.get('sources')!=recipe['sources'] or set(proof.get('assets',{}))!=set(recipe['assets']):raise ValueError('Recovery membership changed')
    if proof.get('preserved_controls')!=recipe['preserved_controls']:raise ValueError('Preserved control provenance changed')
    generated={key:dict(row['generated_replacement'],generation_manifest_sha256=base.digest(base.local(row['generated_replacement']['generation_manifest']))) for key,row in recipe['assets'].items() if row.get('mode')=='generated_replacement'}
    if proof.get('generated_replacements')!=generated:raise ValueError('Generation provenance changed')
    reports={}
    for key,row in recipe['assets'].items():
        entry=manifest['object_assets'][key];errors=[];path=base.local(entry['path'])
        if {k:v for k,v in entry.items() if k not in ('source_processing_manifest','runtime_sha256')}!=expected_manifest_entry(row):errors.append('current source/identity provenance mismatch')
        if entry.get('source_processing_manifest')!=base.resource(PACKET/'manifest.json'):errors.append('processing manifest mismatch')
        if entry.get('runtime_sha256')!=base.digest(path) or proof['assets'][key]['runtime_sha256']!=base.digest(path):errors.append('runtime hash mismatch')
        with Image.open(path) as actual:
            expected=recover(sheets[row['source']],row)
            if actual.mode!='RGBA' or actual.size!=(512,512) or actual.tobytes()!=expected.tobytes():errors.append('pixels differ from original-sheet recovery')
        trim=base.local(entry['source_trimmed'])
        with Image.open(trim) as actual:
            if actual.tobytes()!=trimmed(expected,row).tobytes() or base.digest(trim)!=proof['assets'][key]['trim_sha256']:errors.append('trim does not reproduce original pipeline')
        reports[key]={'ok':not errors,'errors':errors}
    return reports


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path,required=True);parser.add_argument('--install',action='store_true');parser.add_argument('--asset',action='append',help='Inspect selected art only; cannot be combined with installation')
    args=parser.parse_args();print(json.dumps(prepare(args.output,args.install,args.asset)))
