#!/usr/bin/env python3
"""Approved, source-locked repair of hero, tree, legacy and state cutouts.

This is offline raster preparation. Atlas regions and gameplay identities never
change; intact atlas neighbors and original processed sources are preserved.
"""
import argparse
import importlib.util
import json
from pathlib import Path
import re
import shutil

from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
PACKET=ROOT/'art/overworld/source/generated/cutout_recovery_20260909/legacy_families'
RECIPE=PACKET/'recipe.json'
ART_MANIFEST=ROOT/'art/overworld/manifest.json'
ENGINE=ROOT/'tools/prepare_overworld_cutout_pool.py'
_spec=importlib.util.spec_from_file_location('legacy_original_material_engine',ENGINE)
material=importlib.util.module_from_spec(_spec);_spec.loader.exec_module(material)
base=material.base
MODES={'original_hero','generated_tree','generated_state','generated_prop','remove_neighbor'}


def before_path(entry):
    path=base.local(entry['path'])
    return PACKET/'before_runtime'/path.relative_to(ROOT/'art/overworld/runtime')


def original_image(entry):
    before=before_path(entry)
    return Image.open(before if before.exists() else base.local(entry['path'])).convert('RGBA')


def region(image,entry):
    if 'atlas_region' not in entry:return image
    x,y,w,h=entry['atlas_region']
    return image.crop((x,y,x+w,y+h))


def expected_entry(row,recipe):
    entry=dict(row['original_manifest_entry'])
    entry['source_trimmed']=row['trimmed_path']
    if row['mode'].startswith('generated_'):
        entry['source_generated']=recipe['sources'][row['source']]['path']
        entry['source_model']='built_in_image_gen_precise_legacy_family_repair'
        if row['mode']=='generated_tree':entry['source_manifest']=base.resource(PACKET/'manifest.json')
    return entry


def manifest_text(manifest,selected):
    """Preflight every exact row replacement before installing any raster."""
    text=ART_MANIFEST.read_text()
    for key in selected:
        pattern=r'(?ms)^    "'+re.escape(key)+r'": \{\n.*?^    \}(?=,?\n)'
        replacement='    '+json.dumps(key)+': '+json.dumps(manifest['object_assets'][key],indent=2).replace('\n','\n    ')
        text,count=re.subn(pattern,lambda match:replacement,text)
        if count!=1:raise ValueError('Expected one manifest row: '+key)
    if json.loads(text)!=manifest:raise ValueError('Unrelated manifest changes')
    return text


def inputs():
    recipe=json.loads(RECIPE.read_text());manifest=json.loads(ART_MANIFEST.read_text())
    if recipe.get('schema_id')!='legacy_family_cutout_recipe_v1':raise ValueError('Unknown repair recipe')
    proof=json.loads((PACKET/'manifest.json').read_text()) if (PACKET/'manifest.json').exists() else {}
    if base.digest(base.local(recipe['generation_manifest']))!=recipe['generation_sha256']:raise ValueError('Generation provenance changed')
    sources={}
    for key,row in recipe['sources'].items():
        path=base.local(row['path'])
        if base.digest(path)!=row['sha256']:raise ValueError('Source hash changed: '+key)
        sources[key]=Image.open(path).convert('RGB')
    expected_heroes=set(manifest['hero_faction_sprites'].values())
    if expected_heroes!={k for k,v in recipe['assets'].items() if v['mode']=='original_hero'}:raise ValueError('Incomplete hero-family membership')
    tree_path='res://art/overworld/runtime/objects/decorations/generated_blocker_tree_clusters_atlas.png'
    if {k for k,v in manifest['object_assets'].items() if v['path']==tree_path}!={k for k,v in recipe['assets'].items() if v['mode']=='generated_tree'}:raise ValueError('Incomplete tree-atlas membership')
    for key,row in recipe['assets'].items():
        if row['mode'] not in MODES:raise ValueError('Unknown repair mode: '+key)
        entry=manifest['object_assets'][key]
        plain={k:v for k,v in entry.items() if k not in ('source_processing_manifest','runtime_sha256')}
        if plain not in (row['original_manifest_entry'],expected_entry(row,recipe)):raise ValueError('Identity or placement metadata changed: '+key)
        path=base.local(entry['path']);before=before_path(entry)
        if base.digest(before if before.exists() else path)!=row['before_sha256']:raise ValueError('Original raster changed: '+key)
        current=base.digest(path)
        if current not in (row['before_sha256'],proof.get('files',{}).get(entry['path'],{}).get('after_sha256')):raise ValueError('Unrecognized runtime edit: '+key)
        if 'before_trim_sha256' in row and base.digest(base.local(row['original_manifest_entry']['source_trimmed']))!=row['before_trim_sha256']:raise ValueError('Original processed source changed: '+key)
        size=row['canvas_size']
        if tuple(size)!=region(original_image(entry),entry).size:raise ValueError('Logical canvas changed: '+key)
        if row['mode']!='remove_neighbor':
            l,t,r,b=row['source_rect'];w,h=sources[row['source']].size
            if not (0<=l<r<=w and 0<=t<b<=h):raise ValueError('Invalid source rectangle: '+key)
            for x,y,xx,yy in row.get('chromatic_source_rects',[])+row.get('excluded_source_rects',[]):
                if not (l<=x<xx<=r and t<=y<yy<=b):raise ValueError('Region outside source crop: '+key)
        trim=base.local(row['trimmed_path'])
        trim_root=ROOT/'art/overworld/source/trimmed/cutout_recovery_20260909/legacy_families'
        if trim!=trim_root/(key+'.png'):raise ValueError('Unscoped prepared trim: '+key)
        for rect in ([row['keep_canvas_rect']]+row['excluded_canvas_rects'] if row['mode']=='remove_neighbor' else [row['fit_rect']] if row['mode']!='generated_state' else []):
            l,t,r,b=rect;w,h=size
            if not all(type(v) is int for v in rect) or not (0<=l<r<=w and 0<=t<b<=h):raise ValueError('Invalid canvas geometry: '+key)
        if trim.exists() and base.digest(trim)!=proof.get('assets',{}).get(key,{}).get('trim_sha256'):raise ValueError('Unrecognized prepared trim: '+key)
    for key,row in recipe['preserved_controls'].items():
        entry=manifest['object_assets'][key]
        if entry!=row['original_manifest_entry']:raise ValueError('Control metadata changed: '+key)
        original=original_image(entry)
        path=before_path(entry)
        if base.digest(path if path.exists() else base.local(entry['path']))!=row['sha256']:raise ValueError('Original control source changed: '+key)
        if region(original,entry).tobytes()!=region(Image.open(base.local(entry['path'])).convert('RGBA'),entry).tobytes():raise ValueError('Clean control pixels changed: '+key)
    return recipe,manifest,sources


def source_paint(source,row):
    l,t,r,b=row['source_rect']
    protected=[(x-l,y-t,xx-l,yy-t) for x,y,xx,yy in row.get('chromatic_source_rects',[])]
    result=material.material_cell(source.crop((l,t,r,b)),protected)
    for x,y,xx,yy in row.get('excluded_source_rects',[]):
        result.paste((0,0,0,0),(x-l,y-t,xx-l,yy-t))
    bounds=result.getbbox()
    if not bounds or bounds[0]<=0 or bounds[1]<=0 or bounds[2]>=result.width or bounds[3]>=result.height:raise ValueError('Source crop clips paint or retains backing: '+str({'crop':row['source_rect'],'paint':bounds,'size':result.size}))
    return result


def recover(row,sources):
    canvas=Image.new('RGBA',tuple(row['canvas_size']))
    if row['mode']=='remove_neighbor':
        before=original_image(row['original_manifest_entry'])
        l,t,r,b=row['keep_canvas_rect'];canvas.paste(before.crop((l,t,r,b)),(l,t))
        for rect in row['excluded_canvas_rects']:canvas.paste((0,0,0,0),tuple(rect))
        return canvas,{'keep_canvas_rect':row['keep_canvas_rect'],'excluded_canvas_rects':row['excluded_canvas_rects']}
    paint=source_paint(sources[row['source']],row)
    if row['mode']=='generated_state':
        # Independent old-source RGB matches establish this complete-source
        # bilinear resize and pad, not a newly tightened/recentered silhouette.
        if paint.size!=(1254,1254) or row['source_resize']!=[44,44] or row['canvas_origin']!=[2,2]:raise ValueError('Unreviewed state transform')
        canvas.paste(paint.resize((44,44),Image.Resampling.BILINEAR),(2,2))
        return canvas,{'source_resize':[44,44],'canvas_origin':[2,2]}
    bounds=paint.getbbox();painting=paint.crop(bounds)
    l,t,r,b=row['fit_rect']
    scale=min((r-l)/painting.width,(b-t)/painting.height)
    if row['mode']=='original_hero':
        # Preserve the original boot baseline. Only cross-row source paintings
        # that did not fit their old cell need proportional containment.
        ox,oy=row['original_cell_origin'];sx,sy,_,_=row['source_rect']
        original_bounds=[sx+bounds[0]-ox,sy+bounds[1]-oy,sx+bounds[2]-ox,sy+bounds[3]-oy]
        bottom=min(b,original_bounds[3])
        scale=min(1.,(r-l)/painting.width,(bottom-t)/painting.height)
        size=(round(painting.width*scale),round(painting.height*scale))
        x=max(l,min(r-size[0],round((original_bounds[0]+original_bounds[2]-size[0])/2)))
        y=bottom-size[1]
    else:
        size=(round(painting.width*scale),round(painting.height*scale))
        x=l+(r-l-size[0])//2;y=b-size[1]
        original_bounds=None
    if size!=painting.size:painting=painting.resize(size,Image.Resampling.LANCZOS)
    canvas.paste(painting,(x,y))
    if not (l<=x and t<=y and x+size[0]<=r and y+size[1]<=b):raise ValueError('Painting clipped by logical canvas')
    return canvas,{'source_painted_bounds':list(bounds),'original_canvas_bounds':original_bounds,'scale':scale,'painted_size':list(size),'canvas_origin':[x,y]}


def prepare(output,install=False):
    output=output.resolve()
    if output==ROOT.resolve() or output.is_relative_to((ROOT/'art').resolve()):raise ValueError('Preview must be outside registered art')
    output.mkdir(parents=True,exist_ok=False)
    recipe,manifest,sources=inputs()
    results={};rows={};files={};issues={}
    for key,row in recipe['assets'].items():
        try:result,geometry=recover(row,sources)
        except ValueError as exc:
            issues[key]=str(exc)
            continue
        results[key]=result
        result.save(output/(key+'.png'),optimize=True)
        metrics=base.inspect(result)
        if metrics['alpha_extrema']!=[0,255]:raise ValueError('Missing opaque paint or transparent margin: '+key)
        rows[key]={'trim_sha256':base.digest(output/(key+'.png')),'geometry':geometry,'metrics':metrics}
        entry=row['original_manifest_entry'];path=entry['path']
        if path not in files:files[path]=original_image(entry)
        if 'atlas_region' in entry:
            x,y,w,h=entry['atlas_region'];files[path].paste(result,(x,y))
        else:files[path]=result
    for mode in MODES:
        selected={k:v for k,v in results.items() if recipe['assets'][k]['mode']==mode}
        if selected:material.contact_sheet(selected,output/(mode+'_contact.png'))
    if issues:
        (output/'problems.json').write_text(json.dumps(issues,indent=2)+'\n')
        raise ValueError('Refusing incomplete cohort: '+json.dumps(issues))
    file_proofs={}
    for path,result in files.items():
        target=output/'runtime'/base.local(path).relative_to(ROOT/'art/overworld/runtime')
        target.parent.mkdir(parents=True,exist_ok=True);result.save(target,optimize=True)
        file_proofs[path]={'before_sha256':base.digest(before_path({'path':path}) if before_path({'path':path}).exists() else base.local(path)),
                          'after_sha256':base.digest(target),'prepared':str(target.relative_to(output))}
    report={'installed':False,'assets':rows,'files':file_proofs}
    (output/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    if install:
        for key,row in recipe['assets'].items():
            entry=expected_entry(row,recipe)
            entry.update(source_processing_manifest=base.resource(PACKET/'manifest.json'),runtime_sha256=file_proofs[entry['path']]['after_sha256'])
            manifest['object_assets'][key]=entry
        text=manifest_text(manifest,results)
        for path,info in file_proofs.items():
            target=base.local(path);before=before_path({'path':path})
            before.parent.mkdir(parents=True,exist_ok=True)
            if not before.exists():shutil.copy2(target,before)
            shutil.copyfile(output/info['prepared'],target)
        for key,row in recipe['assets'].items():
            trim=base.local(row['trimmed_path']);trim.parent.mkdir(parents=True,exist_ok=True)
            shutil.copyfile(output/(key+'.png'),trim)
        proof={'schema_id':'legacy_family_cutout_recovery_v1','recipe_sha256':base.digest(RECIPE),
               'processing_tool':'tools/prepare_overworld_legacy_cutouts.py','processing_tool_sha256':base.digest(Path(__file__)),
               'material_engine_sha256':base.digest(ENGINE),'matte_engine_sha256':base.digest(material.ENGINE),
               'generation_sha256':recipe['generation_sha256'],'sources':recipe['sources'],
               'assets':rows,'files':file_proofs,'preserved_controls':recipe['preserved_controls']}
        (PACKET/'manifest.json').write_text(json.dumps(proof,indent=2)+'\n')
        ART_MANIFEST.write_text(text)
        report['installed']=True;(output/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    return {'installed':install,'assets':len(rows),'runtime_files':len(files)}


def validate_assets():
    recipe,manifest,sources=inputs();proof=json.loads((PACKET/'manifest.json').read_text())
    for field,path in [('recipe_sha256',RECIPE),('processing_tool_sha256',Path(__file__)),('material_engine_sha256',ENGINE),('matte_engine_sha256',material.ENGINE)]:
        if proof.get(field)!=base.digest(path):raise ValueError('Preparation provenance changed: '+field)
    if proof.get('sources')!=recipe['sources'] or proof.get('generation_sha256')!=recipe['generation_sha256']:raise ValueError('Source/generation provenance changed')
    if set(proof.get('assets',{}))!=set(recipe['assets']) or proof.get('preserved_controls')!=recipe['preserved_controls']:raise ValueError('Cohort membership changed')
    reports={}
    for key,row in recipe['assets'].items():
        entry=manifest['object_assets'][key];errors=[]
        if {k:v for k,v in entry.items() if k not in ('source_processing_manifest','runtime_sha256')}!=expected_entry(row,recipe):errors.append('source/identity mismatch')
        if entry.get('source_processing_manifest')!=base.resource(PACKET/'manifest.json'):errors.append('processing manifest mismatch')
        if entry.get('runtime_sha256')!=base.digest(base.local(entry['path'])):errors.append('runtime hash mismatch')
        expected,geometry=recover(row,sources)
        actual=region(Image.open(base.local(entry['path'])).convert('RGBA'),entry)
        if actual.size!=expected.size or actual.tobytes()!=expected.tobytes():errors.append('runtime pixels do not match source repair')
        trim=base.local(row['trimmed_path'])
        with Image.open(trim) as image:
            if image.mode!='RGBA' or image.size!=expected.size or image.tobytes()!=expected.tobytes():errors.append('trim mismatch')
        if base.digest(trim)!=proof['assets'][key]['trim_sha256'] or geometry!=proof['assets'][key]['geometry']:errors.append('pixel/geometry proof mismatch')
        reports[key]={'ok':not errors,'errors':errors}
    return reports


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True);parser.add_argument('--install',action='store_true')
    args=parser.parse_args();print(json.dumps(prepare(args.output,args.install)))
