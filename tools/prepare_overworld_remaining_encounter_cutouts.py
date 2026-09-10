#!/usr/bin/env python3
"""Recover 79 original encounter rasters; preserve six clean faction controls.

Historical frame registration is frozen, including untrimmed Horizon/Frontier
cells. Frontier's nominal source PNGs are 48px derivatives, not masters: use the
original 1536x1024 sheet. Alpha and opaque paint remain original. Near-transparent
saturated RGB noise alone may borrow original foreground RGB. No runtime logic.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil

from PIL import Image, ImageChops, ImageDraw, ImageOps, ImageStat

ROOT=Path(__file__).resolve().parents[1]
PACKET=ROOT/'art/overworld/source/generated/cutout_recovery_20260909/remaining_encounters'
RECIPE=PACKET/'recipe.json'
MANIFEST=ROOT/'art/overworld/manifest.json'
SHARED=ROOT/'tools/prepare_overworld_contract_cutouts.py'
spec=importlib.util.spec_from_file_location('remaining_encounter_originals',SHARED)
shared=importlib.util.module_from_spec(spec);spec.loader.exec_module(shared)
base=shared.base;owner=shared.owner;project=shared.project
FAMILIES={'systemic':4,'horizon_compact':6,'horizon_courts':5,'frontier_watch_contracts':6,
          'dormant_roster_field_companies':4,'grand_convergence_rival_commanders':6,
          'campaign_finale_nemeses':18,'field_muster_commissions':6,
          'twin_hold_defense_vigils':6,'three_relic_pilgrimages':6,'border_oath_cordons':6,
          'signatures':6,'factions':6}
SOURCE_DIRS={'systemic':'systemic_encounters','horizon_compact':'horizon_compact_wave1',
             'horizon_courts':'horizon_courts_wave1','border_oath_cordons':'border_oath_cordons_wave1'}
SMALL_FIT={'dormant_roster_field_companies','grand_convergence_rival_commanders',
           'campaign_finale_nemeses','twin_hold_defense_vigils'}


def family(entry):return entry['path'].split('/encounters/')[1].split('/')[0]


def before_path(path):return PACKET/'before_runtime'/base.local(path).relative_to(ROOT/'art/overworld/runtime')


def original(path):
    p=before_path(path)
    return Image.open(p if p.exists() else base.local(path)).convert('RGBA')


def source(row):
    im=Image.open(base.local(row['master_path'])).convert('RGBA')
    return im.crop(row['master_region'])


def transform(im,f):
    if f=='factions':return dict(source_crop=[0,0,*im.size],source_resize=list(im.size),canvas_origin=[0,0],canvas_size=[512,512],pixel_scale=1,resampling='LANCZOS')
    whole=f in ('horizon_compact','frontier_watch_contracts')
    crop=[0,0,*im.size] if whole else list(im.getchannel('A').getbbox())
    limit=48 if whole else 56 if f=='signatures' else 42 if f in SMALL_FIT else 44
    size=list(ImageOps.contain(im.crop(crop),(limit,limit),Image.Resampling.LANCZOS).size)
    n=64 if f=='signatures' else 48
    return dict(source_crop=crop,source_resize=size,canvas_origin=[(n-v)//2 for v in size],canvas_size=[n*4,n*4],pixel_scale=4,resampling='LANCZOS')


def registration(im,row,old):
    if row['mode']=='preserved_faction':return {}
    n=64 if family(row['original_manifest_entry'])=='signatures' else 48
    p=project(im,dict(row,canvas_size=[n,n],pixel_scale=1))
    d=ImageChops.difference(old,p)
    mask=ImageChops.multiply(old.getchannel('A').point(lambda a:255 if a>200 else 0),p.getchannel('A').point(lambda a:255 if a>200 else 0))
    result=dict(alpha_mae=ImageStat.Stat(d.getchannel('A')).mean[0],opaque_rgb_mae=sum(ImageStat.Stat(d.convert('RGB'),mask).mean)/3)
    # Bounded evidence of the same source transform, NOT byte equality with
    # historical filtering/micro-sharpening. Current reconstruction is exact.
    if result['alpha_mae']>5 or result['opaque_rgb_mae']>12:raise ValueError('Historical source registration changed: '+str(result))
    return result


def expected_entry(row):
    old=row['original_manifest_entry']
    if row['mode']=='preserved_faction':return old
    extra=dict(source_trimmed=row['trimmed_path'],source_processing_manifest=base.resource(PACKET/'manifest.json'))
    if 'atlas_region' in old:extra.update(atlas_region=[v*4 for v in old['atlas_region']],atlas_size=[v*4 for v in old['atlas_size']])
    return dict(old,**extra)


def initialize():
    if RECIPE.exists():raise ValueError('Never overwrite frozen recipe')
    manifest=json.loads(MANIFEST.read_text())
    members={k:v for k,v in manifest['object_assets'].items() if '/encounters/' in v['path'] and family(v) in FAMILIES}
    assets={};files={};controls={}
    for key,entry in members.items():
        f=family(entry);path=entry['path'];master=entry['source_generated']
        with Image.open(base.local(master)) as im:region=[0,0,*im.size]
        if f=='frontier_watch_contracts':
            master='res://art/overworld/source/generated/encounters/frontier_watch_contracts/frontier_watch_contracts_source_sheet.png'
            i=entry['atlas_region'][0]//48;x,y=i%3*512,i//3*512;region=[x,y,x+512,y+512]
        directory=ROOT/'art/overworld/source/generated/encounters'/SOURCE_DIRS.get(f,f)
        provenance=next(directory.glob('*manifest.json'),None)
        row=dict(original_manifest_entry=entry,runtime_path=path,master_path=master,master_region=region,
                 source_sha256=base.digest(base.local(master)),nominal_source_sha256=base.digest(base.local(entry['source_generated'])),
                 source_manifest=base.resource(provenance) if provenance else '',source_manifest_sha256=base.digest(provenance) if provenance else '',
                 mode='preserved_faction' if f=='factions' else 'encounter',
                 trimmed_path=base.resource(ROOT/'art/overworld/source/trimmed/cutout_recovery_20260909/remaining_encounters'/(key+'.png')))
        im=source(row);row.update(transform(im,f));row['source_size']=list(im.size)
        row['source_alpha_levels']=len(set(im.getchannel('A').getdata()))
        row['low_alpha_rgb_pixels']=int(shared.noise_mask(im).sum()) if f!='factions' else 0
        row['registration_evidence']=registration(im,row,owner.region(original(path),entry))
        assets[key]=row
        if f=='factions':controls[key]=dict(path=path,sha256=base.digest(base.local(path)))
        files[path]=dict(before_size=list(original(path).size),before_sha256=base.digest(base.local(path)),preserved=f=='factions')
    recipe=dict(schema_id='remaining_encounter_cutout_recipe_v1',assets=assets,files=files,preserved_controls=controls,
                identity_mappings={k:v for k,v in manifest['encounter_identity_sprites'].items() if v in assets},
                faction_mappings=manifest['encounter_faction_sprites'])
    PACKET.mkdir(parents=True,exist_ok=True);RECIPE.write_text(json.dumps(recipe,indent=2)+'\n')
    return dict(assets=len(assets),repairs=len(assets)-len(controls),controls=len(controls))


def inputs():
    recipe=json.loads(RECIPE.read_text());manifest=json.loads(MANIFEST.read_text())
    proof=json.loads((PACKET/'manifest.json').read_text()) if (PACKET/'manifest.json').exists() else {}
    members={k:v for k,v in manifest['object_assets'].items() if '/encounters/' in v['path'] and family(v) in FAMILIES}
    if recipe['schema_id']!='remaining_encounter_cutout_recipe_v1' or set(members)!=set(recipe['assets']) or len(members)!=85:raise ValueError('Cohort membership changed')
    if {f:sum(family(v)==f for v in members.values()) for f in FAMILIES}!=FAMILIES:raise ValueError('Family membership changed')
    if set(recipe['preserved_controls'])!={k for k,v in members.items() if family(v)=='factions'}:raise ValueError('Clean controls changed')
    if set(recipe['files'])!={v['path'] for v in members.values()}:raise ValueError('Incomplete runtime files')
    if {k:v for k,v in manifest['encounter_identity_sprites'].items() if v in members}!=recipe['identity_mappings'] or manifest['encounter_faction_sprites']!=recipe['faction_mappings']:raise ValueError('Encounter routing changed')
    images={}
    for path,info in recipe['files'].items():
        prior=before_path(path) if before_path(path).exists() else base.local(path)
        if base.digest(prior)!=info['before_sha256'] or list(original(path).size)!=info['before_size']:raise ValueError('Historical raster changed')
        if base.digest(base.local(path)) not in (info['before_sha256'],proof.get('files',{}).get(path,{}).get('after_sha256')):raise ValueError('Unrecognized raster edit')
    for key,row in recipe['assets'].items():
        old=row['original_manifest_entry'];f=family(old);entry=members[key]
        clean=lambda e:{k:v for k,v in e.items() if k!='runtime_sha256'}
        if clean(entry) not in (clean(old),clean(expected_entry(row))):raise ValueError('Identity metadata changed: '+key)
        if base.digest(base.local(row['master_path']))!=row['source_sha256'] or base.digest(base.local(old['source_generated']))!=row['nominal_source_sha256']:raise ValueError('Source painting changed')
        if row['source_manifest'] and base.digest(base.local(row['source_manifest']))!=row['source_manifest_sha256']:raise ValueError('Source provenance changed')
        with Image.open(base.local(row['master_path'])) as master:master_size=master.size
        region=[0,0,*master_size]
        if f=='frontier_watch_contracts':
            i=old['atlas_region'][0]//48;x,y=i%3*512,i//3*512;region=[x,y,x+512,y+512]
            if master_size!=(1536,1024) or not row['master_path'].endswith('/frontier_watch_contracts_source_sheet.png'):raise ValueError('Wrong original sheet')
        elif row['master_path']!=old['source_generated']:raise ValueError('Wrong original master')
        if row['master_region']!=region:raise ValueError('Original source region changed')
        im=source(row);images[key]=im
        if list(im.size)!=row['source_size'] or len(set(im.getchannel('A').getdata()))!=row['source_alpha_levels']:raise ValueError('Source alpha changed')
        if any(row[k]!=v for k,v in transform(im,f).items()):raise ValueError('Logical source registration changed')
        if row['mode']!=('preserved_faction' if f=='factions' else 'encounter') or row['runtime_path']!=old['path']:raise ValueError('Disposition changed')
        if row['low_alpha_rgb_pixels']!=(int(shared.noise_mask(im).sum()) if f!='factions' else 0):raise ValueError('Reviewed RGB noise changed')
        if registration(im,row,owner.region(original(old['path']),old))!=row['registration_evidence']:raise ValueError('Historical registration evidence changed')
        if f=='factions':
            if entry!=old or base.digest(base.local(old['path']))!=recipe['preserved_controls'][key]['sha256']:raise ValueError('Clean faction control changed')
        else:
            trim=ROOT/'art/overworld/source/trimmed/cutout_recovery_20260909/remaining_encounters'/(key+'.png')
            if base.local(row['trimmed_path'])!=trim:raise ValueError('Unscoped trim path')
            if trim.exists() and base.digest(trim)!=proof.get('assets',{}).get(key,{}).get('trim_sha256'):raise ValueError('Unrecognized derived edit')
    return recipe,manifest,images


def tool_hashes():return dict(shared.tool_hashes(),**{str(Path(__file__).relative_to(ROOT)):base.digest(Path(__file__))})


def prepare(output,install=False):
    output=output.resolve()
    if output==ROOT.resolve() or output.is_relative_to((ROOT/'art').resolve()):raise ValueError('Preview outside source art required')
    recipe,manifest,sources=inputs();output.mkdir(parents=True,exist_ok=False)
    canvases={p:original(p) if r['preserved'] else Image.new('RGBA',tuple(v*4 for v in r['before_size'])) for p,r in recipe['files'].items()}
    results={};rows={};files={}
    for key,row in recipe['assets'].items():
        clean=row['mode']=='preserved_faction'
        fixed=original(row['runtime_path']) if clean else project(shared.recover_source(sources[key],row),row)
        results[key]=fixed;fixed.save(output/(key+'.png'),optimize=True)
        rows[key]=dict(rgba_sha256=hashlib.sha256(fixed.tobytes()).hexdigest(),trim_sha256=base.digest(output/(key+'.png')),preserved=clean)
        if not clean:
            entry=expected_entry(row)
            if 'atlas_region' in entry:canvases[entry['path']].paste(fixed,tuple(entry['atlas_region'][:2]))
            else:canvases[entry['path']]=fixed
    for path,canvas in canvases.items():
        dest=output/'runtime'/base.local(path).relative_to(ROOT/'art/overworld/runtime');dest.parent.mkdir(parents=True,exist_ok=True)
        if recipe['files'][path]['preserved']:shutil.copyfile(base.local(path),dest)
        else:canvas.save(dest,optimize=True)
        files[path]=dict(after_sha256=base.digest(dest),prepared=str(dest.relative_to(output)))
    for page,start in enumerate(range(0,85,6)):
        canvas=Image.new('RGB',(1440,800),'#334c3a');draw=ImageDraw.Draw(canvas)
        for j,(key,row) in enumerate(list(recipe['assets'].items())[start:start+6]):
            x,y=j%3*480,j//3*400
            old=owner.region(original(row['runtime_path']),row['original_manifest_entry'])
            for col,im in enumerate((old,results[key])):
                im=im.resize((192,192),Image.Resampling.LANCZOS);canvas.paste(im,(x+col*225,y+30),im)
            draw.text((x+3,y+260),key.removeprefix('encounter_'),fill='white')
            draw.text((x+3,y+280),'BEFORE / ORIGINAL-SOURCE RECOVERY' if row['mode']!='preserved_faction' else 'UNCHANGED CLEAN FACTION CONTROL',fill='white')
        canvas.save(output/f'comparison_{page:02}.png')
    proof=dict(schema_id='remaining_encounter_cutout_recovery_v1',recipe_sha256=base.digest(RECIPE),tools=tool_hashes(),assets=rows,files=files,
               processing='79 direct original-master recoveries at fourfold density; six clean faction controls byte-preserved. Original alpha and all non-noise paint retained. Reviewed alpha 1..4 saturated RGB only borrows original foreground RGB. Full Horizon/Frontier cells and other family-specific centered logical fits retained; no gameplay mutation.')
    if install:
        for path,info in files.items():
            if recipe['files'][path]['preserved']:continue
            archive=before_path(path);archive.parent.mkdir(parents=True,exist_ok=True)
            if not archive.exists():shutil.copy2(base.local(path),archive)
            shutil.copyfile(output/info['prepared'],base.local(path))
        for key,row in recipe['assets'].items():
            if row['mode']=='preserved_faction':continue
            dest=base.local(row['trimmed_path']);dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(output/(key+'.png'),dest)
            manifest['object_assets'][key]=dict(expected_entry(row),runtime_sha256=files[row['runtime_path']]['after_sha256'])
        MANIFEST.write_text(owner.manifest_text(manifest,recipe['assets']))
        (PACKET/'manifest.json').write_text(json.dumps(proof,indent=2)+'\n')
    (output/'report.json').write_text(json.dumps(proof,indent=2)+'\n')
    return dict(installed=install,repairs=79,controls=6,files=len(files))


def validate_assets():
    recipe,manifest,sources=inputs();proof=json.loads((PACKET/'manifest.json').read_text())
    if proof['schema_id']!='remaining_encounter_cutout_recovery_v1' or proof['recipe_sha256']!=base.digest(RECIPE) or proof['tools']!=tool_hashes():raise ValueError('Preparation provenance changed')
    if set(proof['assets'])!=set(recipe['assets']) or set(proof['files'])!=set(recipe['files']):raise ValueError('Incomplete proof')
    for path,info in recipe['files'].items():
        if base.digest(base.local(path))!=proof['files'][path]['after_sha256']:raise ValueError('Runtime PNG changed')
    for key,row in recipe['assets'].items():
        clean=row['mode']=='preserved_faction';entry=manifest['object_assets'][key]
        fixed=original(row['runtime_path']) if clean else project(shared.recover_source(sources[key],row),row)
        expected=expected_entry(row) if clean else dict(expected_entry(row),runtime_sha256=proof['files'][entry['path']]['after_sha256'])
        if entry!=expected:raise ValueError('Runtime ownership changed')
        actual=owner.region(Image.open(base.local(entry['path'])).convert('RGBA'),entry)
        if actual.tobytes()!=fixed.tobytes() or hashlib.sha256(fixed.tobytes()).hexdigest()!=proof['assets'][key]['rgba_sha256']:raise ValueError('Exact original reconstruction failed')
        if not clean:
            trim=base.local(row['trimmed_path'])
            if Image.open(trim).convert('RGBA').tobytes()!=fixed.tobytes() or base.digest(trim)!=proof['assets'][key]['trim_sha256']:raise ValueError('Derived provenance changed')
    return {k:dict(ok=True,errors=[]) for k in recipe['assets']}


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--initialize',action='store_true');parser.add_argument('--output',type=Path);parser.add_argument('--install',action='store_true')
    args=parser.parse_args()
    if not args.initialize and not args.output:parser.error('--output required')
    print(json.dumps(initialize() if args.initialize else prepare(args.output,args.install)))
