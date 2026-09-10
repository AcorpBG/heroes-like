#!/usr/bin/env python3
"""Original-source artifact field recovery; inventory icons stay untouched.

36 compact field paintings recover original detail on 192px atlas cells.
33 clean standalone field paintings remain byte-identical. Documented 42/48
logical fits and centered world registrations stay fixed; older two-stage
inventory filtering is historical evidence, not a source of replacement pixels.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil

from PIL import Image, ImageChops, ImageDraw, ImageOps, ImageStat

ROOT=Path(__file__).resolve().parents[1]
PACKET=ROOT/'art/overworld/source/generated/cutout_recovery_20260909/artifacts'
RECIPE=PACKET/'recipe.json'
MANIFEST=ROOT/'art/overworld/manifest.json'
spec=importlib.util.spec_from_file_location('artifact_original_projection',ROOT/'tools/prepare_overworld_contract_cutouts.py')
shared=importlib.util.module_from_spec(spec);spec.loader.exec_module(shared)
base=shared.base;owner=shared.owner;project=shared.project
FAMILIES={'three_relic_pilgrimages':18,'marchland_retinue_heirlooms':6,'command_relic_marches':12}


def local(path):
    if not path.startswith(('res://art/overworld/','res://art/artifacts/')) or '..' in Path(path).parts:
        raise ValueError('Expected scoped original or field art: '+path)
    return ROOT/path.removeprefix('res://')


def rgba(path):
    with Image.open(path) as opened:return opened.convert('RGBA')


def before_path(path):return PACKET/'before_runtime'/local(path).relative_to(ROOT/'art/overworld/runtime')


def original(path):
    archive=before_path(path)
    return rgba(archive if archive.exists() else local(path))


def members(manifest):
    return {k:v for k,v in manifest['object_assets'].items() if '/objects/artifacts/' in v['path']}


def transform(source):
    crop=list(source.getchannel('A').getbbox())
    fit=list(ImageOps.contain(source.crop(crop),(42,42),Image.Resampling.LANCZOS).size)
    return dict(source_crop=crop,source_resize=fit,canvas_origin=[(48-v)//2 for v in fit],
                canvas_size=[192,192],pixel_scale=4,resampling='LANCZOS')


def registration(source,row,old):
    projection=project(source,dict(row,canvas_size=[48,48],pixel_scale=1))
    diff=ImageChops.difference(old,projection)
    mask=ImageChops.multiply(old.getchannel('A').point(lambda a:255 if a>200 else 0),
                            projection.getchannel('A').point(lambda a:255 if a>200 else 0))
    return dict(alpha_mae=ImageStat.Stat(diff.getchannel('A')).mean[0],
                opaque_rgb_mae=sum(ImageStat.Stat(diff.convert('RGB'),mask).mean)/3)


def expected_entry(row):
    old=row['original_manifest_entry']
    if row['mode']=='preserved_artifact':return old
    return dict(old,atlas_region=[v*4 for v in old['atlas_region']],atlas_size=[v*4 for v in old['atlas_size']],
                source_generated=row['source_path'],source_trimmed=row['trimmed_path'],
                source_processing_manifest=base.resource(PACKET/'manifest.json'))


def initialize():
    if RECIPE.exists():raise ValueError('Never overwrite a frozen recipe')
    manifest=json.loads(MANIFEST.read_text());assets={};files={};controls={}
    for key,entry in members(manifest).items():
        path=entry['path'];clean='atlas_region' not in entry
        row=dict(original_manifest_entry=entry,runtime_path=path,mode='preserved_artifact' if clean else 'artifact',
                 icon_path=entry['source_icon'],icon_sha256=base.digest(local(entry['source_icon'])))
        if clean:
            row['canvas_size']=list(original(path).size)
            controls[key]=dict(path=path,sha256=base.digest(local(path)),original_manifest_entry=entry)
        else:
            candidates=list((ROOT/'art/artifacts/source/generated').glob('*/'+key.removeprefix('artifact_field_')+'_source.png'))
            if len(candidates)!=1:raise ValueError('Ambiguous original source: '+key)
            source_path=candidates[0];provenance=source_path.parent/'manifest.json'
            original_source=rgba(source_path)
            row.update(source_path=base.resource(source_path),source_sha256=base.digest(source_path),
                       source_manifest=base.resource(provenance),source_manifest_sha256=base.digest(provenance),
                       source_size=list(original_source.size),source_alpha_levels=len(set(original_source.getchannel('A').getdata())),
                       low_alpha_rgb_pixels=int(shared.noise_mask(original_source).sum()),
                       trimmed_path=base.resource(ROOT/'art/overworld/source/trimmed/cutout_recovery_20260909/artifacts'/(key+'.png')),
                       **transform(original_source))
            row['historical_registration']=registration(original_source,row,owner.region(original(path),entry))
        assets[key]=row
        files[path]=dict(before_size=list(original(path).size),before_sha256=base.digest(local(path)),preserved=clean)
    recipe=dict(schema_id='artifact_cutout_recipe_v1',assets=assets,files=files,preserved_controls=controls,
                identity_mappings=manifest['artifact_field_sprites'])
    PACKET.mkdir(parents=True,exist_ok=True);RECIPE.write_text(json.dumps(recipe,indent=2)+'\n')
    return dict(assets=len(assets),repairs=len(assets)-len(controls),controls=len(controls))


def inputs():
    recipe=json.loads(RECIPE.read_text());manifest=json.loads(MANIFEST.read_text())
    proof=json.loads((PACKET/'manifest.json').read_text()) if (PACKET/'manifest.json').exists() else {}
    current=members(manifest);sources={}
    if recipe['schema_id']!='artifact_cutout_recipe_v1' or len(current)!=69 or set(current)!=set(recipe['assets']):raise ValueError('Artifact cohort changed')
    if manifest['artifact_field_sprites']!=recipe['identity_mappings'] or set(recipe['identity_mappings'].values())!=set(current):raise ValueError('Artifact routes changed')
    controls={k for k,v in current.items() if 'atlas_region' not in v}
    if len(controls)!=33 or set(recipe['preserved_controls'])!=controls:raise ValueError('Clean controls changed')
    if {f:sum('/'+f+'/' in v['path'] for v in current.values()) for f in FAMILIES}!=FAMILIES:raise ValueError('Atlas family membership changed')
    if set(recipe['files'])!={v['path'] for v in current.values()}:raise ValueError('Incomplete runtime files')
    for path,info in recipe['files'].items():
        prior=before_path(path) if before_path(path).exists() else local(path)
        if base.digest(prior)!=info['before_sha256'] or list(original(path).size)!=info['before_size']:raise ValueError('Historical raster changed')
        if base.digest(local(path)) not in (info['before_sha256'],proof.get('files',{}).get(path,{}).get('after_sha256')):raise ValueError('Unrecognized raster edit')
    for key,row in recipe['assets'].items():
        old=row['original_manifest_entry'];entry=current[key];clean=key in controls
        strip=lambda v:{k:value for k,value in v.items() if k!='runtime_sha256'}
        if strip(entry) not in (strip(old),strip(expected_entry(row))):raise ValueError('Artifact identity metadata changed: '+key)
        if row['mode']!=('preserved_artifact' if clean else 'artifact') or row['runtime_path']!=old['path']:raise ValueError('Disposition changed')
        if row['icon_path']!=old['source_icon'] or base.digest(local(row['icon_path']))!=row['icon_sha256']:raise ValueError('Inventory icon changed')
        if clean:
            if entry!=old or row['canvas_size']!=[512,512] or base.digest(local(old['path']))!=recipe['preserved_controls'][key]['sha256']:raise ValueError('Clean painting changed')
            continue
        source_path=local(row['source_path']);provenance=local(row['source_manifest'])
        if source_path.name!=key.removeprefix('artifact_field_')+'_source.png' or not source_path.is_relative_to(ROOT/'art/artifacts/source/generated'):raise ValueError('Wrong original identity source')
        if base.digest(source_path)!=row['source_sha256'] or base.digest(provenance)!=row['source_manifest_sha256']:raise ValueError('Original source or provenance changed')
        source_rows=json.loads(provenance.read_text())['items']
        match=[v for v in source_rows if v['artifact_id']==old['assigned_artifact_id']]
        if len(match)!=1 or match[0]['source_path']!=row['source_path'] or match[0]['source_sha256']!=row['source_sha256'] or match[0]['runtime_path']!=row['icon_path'] or match[0]['runtime_sha256']!=row['icon_sha256']:raise ValueError('Original provenance identity mismatch')
        source=rgba(source_path);sources[key]=source
        if list(source.size)!=row['source_size'] or len(set(source.getchannel('A').getdata()))!=row['source_alpha_levels']:raise ValueError('Original alpha changed')
        if any(row[k]!=v for k,v in transform(source).items()):raise ValueError('Original fit or anchor changed')
        if int(shared.noise_mask(source).sum())!=row['low_alpha_rgb_pixels']:raise ValueError('Reviewed RGB noise changed')
        if registration(source,row,owner.region(original(old['path']),old))!=row['historical_registration']:raise ValueError('Historical registration changed')
        trim=ROOT/'art/overworld/source/trimmed/cutout_recovery_20260909/artifacts'/(key+'.png')
        if local(row['trimmed_path'])!=trim:raise ValueError('Unscoped trim path')
        if trim.exists() and base.digest(trim)!=proof.get('assets',{}).get(key,{}).get('trim_sha256'):raise ValueError('Unrecognized trimmed edit')
    return recipe,manifest,sources


def tool_hashes():return dict(shared.tool_hashes(),**{str(Path(__file__).relative_to(ROOT)):base.digest(Path(__file__))})


def prepare(output,install=False):
    output=output.resolve()
    if output==ROOT.resolve() or output.is_relative_to((ROOT/'art').resolve()):raise ValueError('Preview outside source art required')
    recipe,manifest,sources=inputs();output.mkdir(parents=True,exist_ok=False)
    canvases={p:original(p) if r['preserved'] else Image.new('RGBA',tuple(v*4 for v in r['before_size'])) for p,r in recipe['files'].items()}
    results={};rows={};files={}
    for key,row in recipe['assets'].items():
        clean=row['mode']=='preserved_artifact'
        fixed=original(row['runtime_path']) if clean else project(shared.recover_source(sources[key],row),row)
        results[key]=fixed;fixed.save(output/(key+'.png'),optimize=True)
        rows[key]=dict(rgba_sha256=hashlib.sha256(fixed.tobytes()).hexdigest(),trim_sha256=base.digest(output/(key+'.png')),preserved=clean)
        if not clean:
            entry=expected_entry(row);canvases[entry['path']].paste(fixed,tuple(entry['atlas_region'][:2]))
    for path,canvas in canvases.items():
        dest=output/'runtime'/local(path).relative_to(ROOT/'art/overworld/runtime');dest.parent.mkdir(parents=True,exist_ok=True)
        if recipe['files'][path]['preserved']:shutil.copyfile(local(path),dest)
        else:canvas.save(dest,optimize=True)
        files[path]=dict(after_sha256=base.digest(dest),prepared=str(dest.relative_to(output)))
    for page,start in enumerate(range(0,69,6)):
        canvas=Image.new('RGB',(1440,800),'#334c3a');draw=ImageDraw.Draw(canvas)
        for j,(key,row) in enumerate(list(recipe['assets'].items())[start:start+6]):
            x,y=j%3*480,j//3*400
            old=owner.region(original(row['runtime_path']),row['original_manifest_entry'])
            for col,im in enumerate((old,results[key])):
                im=im.resize((192,192),Image.Resampling.LANCZOS);canvas.paste(im,(x+col*225,y+30),im)
            draw.text((x+3,y+260),key.removeprefix('artifact_field_'),fill='white')
            draw.text((x+3,y+280),'BEFORE / ORIGINAL-SOURCE RECOVERY' if row['mode']=='artifact' else 'UNCHANGED CLEAN FIELD PAINTING',fill='white')
        canvas.save(output/f'comparison_{page:02}.png')
    proof=dict(schema_id='artifact_cutout_recovery_v1',recipe_sha256=base.digest(RECIPE),tools=tool_hashes(),assets=rows,files=files,
               processing='36 direct original-master artifact recoveries at fourfold density; 33 clean field paintings and all inventory icons unchanged. Original alpha and all non-noise paint retained. Reviewed alpha 1..4 saturated RGB alone borrows original foreground RGB. Documented 42px centered logical fit; historical two-stage quantization is recorded, not pixel-equality claimed.')
    if install:
        for path,info in files.items():
            if recipe['files'][path]['preserved']:continue
            archive=before_path(path);archive.parent.mkdir(parents=True,exist_ok=True)
            if not archive.exists():shutil.copy2(local(path),archive)
            shutil.copyfile(output/info['prepared'],local(path))
        for key,row in recipe['assets'].items():
            if row['mode']=='preserved_artifact':continue
            dest=local(row['trimmed_path']);dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(output/(key+'.png'),dest)
            manifest['object_assets'][key]=dict(expected_entry(row),runtime_sha256=files[row['runtime_path']]['after_sha256'])
        MANIFEST.write_text(owner.manifest_text(manifest,{k:r for k,r in recipe['assets'].items() if r['mode']=='artifact'}))
        (PACKET/'manifest.json').write_text(json.dumps(proof,indent=2)+'\n')
    (output/'report.json').write_text(json.dumps(proof,indent=2)+'\n')
    return dict(installed=install,repairs=36,controls=33,changed_runtime_files=3)


def validate_assets():
    recipe,manifest,sources=inputs();proof=json.loads((PACKET/'manifest.json').read_text())
    if proof['schema_id']!='artifact_cutout_recovery_v1' or proof['recipe_sha256']!=base.digest(RECIPE) or proof['tools']!=tool_hashes():raise ValueError('Preparation provenance changed')
    if set(proof['assets'])!=set(recipe['assets']) or set(proof['files'])!=set(recipe['files']):raise ValueError('Incomplete proof')
    for path,info in recipe['files'].items():
        if base.digest(local(path))!=proof['files'][path]['after_sha256']:raise ValueError('Runtime PNG changed')
    for key,row in recipe['assets'].items():
        clean=row['mode']=='preserved_artifact';entry=manifest['object_assets'][key]
        fixed=original(row['runtime_path']) if clean else project(shared.recover_source(sources[key],row),row)
        expected=expected_entry(row) if clean else dict(expected_entry(row),runtime_sha256=proof['files'][entry['path']]['after_sha256'])
        if entry!=expected:raise ValueError('Runtime ownership changed')
        actual=owner.region(rgba(local(entry['path'])),entry)
        if actual.tobytes()!=fixed.tobytes() or hashlib.sha256(fixed.tobytes()).hexdigest()!=proof['assets'][key]['rgba_sha256']:raise ValueError('Original reconstruction failed')
        if not clean:
            trim=local(row['trimmed_path'])
            if rgba(trim).tobytes()!=fixed.tobytes() or base.digest(trim)!=proof['assets'][key]['trim_sha256']:raise ValueError('Derived provenance changed')
    return {k:dict(ok=True,errors=[]) for k in recipe['assets']}


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--initialize',action='store_true');parser.add_argument('--output',type=Path);parser.add_argument('--install',action='store_true')
    args=parser.parse_args()
    if not args.initialize and not args.output:parser.error('--output required')
    print(json.dumps(initialize() if args.initialize else prepare(args.output,args.install)))
