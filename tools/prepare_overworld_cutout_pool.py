#!/usr/bin/env python3
"""Approved original-sheet recovery for explicitly reviewed runtime cohorts.

No runtime drawing or generated substitutes. Source rectangles, original raster
hashes, alignment and intentional chromatic materials are locked in the recipe.
"""
import argparse
import importlib.util
import json
from pathlib import Path
import re
import shutil

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
PACKET = ROOT/'art/overworld/source/generated/cutout_recovery_20260909/map_sheets'
RECIPE = PACKET/'recipe.json'
ART_MANIFEST = ROOT/'art/overworld/manifest.json'
ENGINE = ROOT/'tools/prepare_overworld_cutout_art.py'
_spec = importlib.util.spec_from_file_location('original_cutout_engine', ENGINE)
base = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(base)


def material_cell(source, chromatic_rects):
    """Neutral matte recovery with explicit source-colored material trimaps.

    Opaque chromatic interiors retain exact source RGB. Only a two-pixel band
    adjacent to verified backing has uncertain coverage; its foreground colors
    come from the same original painted material. This keeps violet crystals
    violet without using their color as a global exemption for magenta fringes.
    """
    if not chromatic_rects:
        return base.recover_cell(source, neutral_material=True)
    pixels = list(source.convert('RGB').getdata())
    width,height = source.size
    keys = [g<=24 and min(r,b)>80 and min(r,b)-g>64 for r,g,b in pixels]
    mask = Image.new('L',source.size)
    mask.putdata([0 if key else 255 for key in keys])
    interior = list(mask.filter(ImageFilter.MinFilter(5)).getdata())
    protected = [any(l<=i%width<r and t<=i//width<b for l,t,r,b in chromatic_rects)
                 for i in range(len(pixels))]
    unknown = [i for i,(r,g,b) in enumerate(pixels)
               if not keys[i] and min(r,b)-g>8 and not (protected[i] and interior[i])]
    unknown_set = set(unknown)
    foreground = base.nearest_colors(pixels,[not k and i not in unknown_set for i,k in enumerate(keys)],unknown,width,height)
    neutral_foreground = base.nearest_colors(pixels,
        [not k and min(pixels[i][0],pixels[i][2])-pixels[i][1]<=8 for i,k in enumerate(keys)],
        [i for i in unknown if not protected[i]],width,height)
    background = base.nearest_colors(pixels,keys,unknown,width,height)
    output = [(0,0,0,0) if k else (*p,255) for p,k in zip(pixels,keys)]
    for i in unknown:
        p,fg,bg = pixels[i],foreground[i] if protected[i] else neutral_foreground[i],background[i]
        delta = [f-b for f,b in zip(fg,bg)]
        denom = sum(d*d for d in delta)
        if not denom: raise ValueError('Ambiguous material/background color')
        coverage = max(0.,min(1.,sum((c-b)*d for c,b,d in zip(p,bg,delta))/denom))
        alpha = round(coverage*255)
        output[i] = (*fg,alpha) if alpha>=4 else (0,0,0,0)
    result = Image.new('RGBA',source.size)
    result.putdata(output)
    return result


def recover(sheet, spec):
    l,t,r,b = spec['source_rect']
    regions = [(x-l,y-t,xx-l,yy-t) for x,y,xx,yy in spec.get('chromatic_source_rects',[])]
    cell = material_cell(sheet.crop((l,t,r,b)),regions)
    result = Image.new('RGBA',(512,512))
    result.paste(cell,tuple(spec['canvas_origin']))
    return result


def load_inputs(recipe_path=RECIPE):
    recipe = json.loads(recipe_path.read_text())
    manifest = json.loads(ART_MANIFEST.read_text())
    previous_path = recipe_path.parent/'manifest.json'
    previous = json.loads(previous_path.read_text()) if previous_path.exists() else {}
    sheets = {}
    if recipe.get('schema_id')!='original_sheet_pool_recipe_v1':
        raise ValueError('Unknown original-sheet recipe schema')
    all_members = set()
    for key,spec in recipe['sources'].items():
        path = base.local(spec['path'])
        if base.digest(path)!=spec['sha256']:raise ValueError('Original sheet hash changed: '+key)
        sheets[key] = Image.open(path).convert('RGB')
        members = {k for k,v in manifest['object_assets'].items() if v.get('source_generated_atlas')==spec['path']}
        if members!=set(spec['members']):raise ValueError('Exact source-sheet membership changed: '+key)
        all_members.update(members)
    if all_members != set(recipe['assets']) | set(recipe['preserved_controls']):
        raise ValueError('Incomplete source-sheet dispositions')
    for key,spec in recipe['assets'].items():
        entry = manifest['object_assets'][key]
        stripped = {k:v for k,v in entry.items() if k not in ('runtime_sha256','source_processing_manifest')}
        if stripped != spec['original_manifest_entry']:
            raise ValueError('Original identity/placement metadata changed: '+key)
        if entry['source_generated_atlas']!=recipe['sources'][spec['source']]['path']:
            raise ValueError('Wrong source painting: '+key)
        runtime = base.local(entry['path'])
        before = recipe_path.parent/(key+'_before.png')
        if base.digest(before if before.exists() else runtime)!=spec['before_sha256']:
            raise ValueError('Before raster changed: '+key)
        current = base.digest(runtime)
        if current not in (spec['before_sha256'],previous.get('assets',{}).get(key,{}).get('runtime_sha256')):
            raise ValueError('Refusing to overwrite unrecognized runtime edit: '+key)
        if base.local(entry['source_trimmed']).read_bytes()!=runtime.read_bytes():
            raise ValueError('Trim/runtime diverged: '+key)
        l,t,r,b = spec['source_rect']
        x,y = spec['canvas_origin']
        w,h = sheets[spec['source']].size
        if not (0<=l<r<=w and 0<=t<b<=h and 0<=x<=512-(r-l) and 0<=y<=512-(b-t)):
            raise ValueError('Invalid source/canvas bounds: '+key)
        for xx,yy,rr,bb in spec.get('chromatic_source_rects',[]):
            if not (l<=xx<rr<=r and t<=yy<bb<=b):
                raise ValueError('Chromatic material outside its painting: '+key)
    for key,spec in recipe['preserved_controls'].items():
        if manifest['object_assets'][key]['path']!=spec['path'] or base.digest(base.local(spec['path']))!=spec['sha256']:
            raise ValueError('Previously repaired control changed: '+key)
    return recipe,manifest,sheets


def contact_sheet(results,path):
    canvas = Image.new('RGB',(1024,((len(results)+3)//4)*284),'#334c3a')
    draw = ImageDraw.Draw(canvas)
    for i,(key,result) in enumerate(results.items()):
        x,y = i%4*256,i//4*284
        thumb = result.resize((256,256),Image.Resampling.LANCZOS)
        canvas.paste(thumb,(x,y),thumb)
        label = key.removeprefix('mapobj_')
        draw.text((x+3,y+258),label[:38],fill='white')
        draw.text((x+3,y+271),label[38:],fill='white')
    canvas.save(path)


def prepare(output, install=False):
    destination = output.resolve()
    if destination==ROOT.resolve() or destination.is_relative_to((ROOT/'art').resolve()):
        raise ValueError('Preview output must be outside the registered art tree')
    recipe,manifest,sheets = load_inputs()
    output.mkdir(parents=True,exist_ok=True)
    results = {k:recover(sheets[v['source']],v) for k,v in recipe['assets'].items()}
    rows = {}
    for key,result in results.items():
        path = output/(key+'.png')
        result.save(path,optimize=True)
        metrics = base.inspect(result)
        if metrics['alpha_extrema']!=[0,255] or metrics['opaque_pixels']<2500:
            raise ValueError('Incomplete original painted subject: '+key)
        rows[key] = dict(runtime_sha256=base.digest(path),after=metrics,
                         before_sha256=recipe['assets'][key]['before_sha256'],
                         runtime=manifest['object_assets'][key]['path'])
    for source in sheets:
        contact_sheet({k:v for k,v in results.items() if recipe['assets'][k]['source']==source},output/('sheet_'+source+'.png'))
    if install:
        # Entire cohort has passed input identity, raster and bounds checks.
        for key in results:
            entry = manifest['object_assets'][key]
            before = PACKET/(key+'_before.png')
            if not before.exists():shutil.copy2(base.local(entry['path']),before)
            for field in ('path','source_trimmed'):
                shutil.copyfile(output/(key+'.png'),base.local(entry[field]))
            rows[key]['before'] = base.resource(before)
            rows[key]['before_metrics'] = base.inspect(Image.open(before))
            entry.update(source_processing_manifest=base.resource(PACKET/'manifest.json'),runtime_sha256=rows[key]['runtime_sha256'])
        proof = dict(schema_id='original_sheet_pool_recovery_v1',
            owner_approval='2026-09-09 explicit deterministic original-image recovery approval',
            recipe=base.resource(RECIPE),recipe_sha256=base.digest(RECIPE),
            processing_tool=base.resource(Path(__file__)).removeprefix('res://'),
            processing_tool_sha256=base.digest(Path(__file__)),
            matte_engine='tools/prepare_overworld_cutout_art.py',matte_engine_sha256=base.digest(ENGINE),
            processing='Original RGB source paintings, inspected irregular cells and chromatic material regions; nearest original paint/background coverage; integer translation on unchanged 512 canvases, no resampling. No generated substitutes or gameplay changes.',
            sources=recipe['sources'],assets=rows)
        (PACKET/'manifest.json').write_text(json.dumps(proof,indent=2)+'\n')
        text = ART_MANIFEST.read_text()
        for key in results:
            pattern = r'(?ms)^    "'+re.escape(key)+r'": \{\n.*?^    \}(?=,?\n)'
            replacement = '    '+json.dumps(key)+': '+json.dumps(manifest['object_assets'][key],indent=2).replace('\n','\n    ')
            text,count = re.subn(pattern,lambda match:replacement,text)
            if count!=1:raise ValueError('Expected one authoritative manifest row: '+key)
        if json.loads(text)!=manifest:raise ValueError('Unrelated manifest content changed')
        ART_MANIFEST.write_text(text)
    (output/'report.json').write_text(json.dumps(dict(installed=install,assets=rows),indent=2)+'\n')
    return rows


def validate_pool_assets():
    recipe,manifest,sheets = load_inputs()
    proof = json.loads((PACKET/'manifest.json').read_text())
    for field,path in [('recipe_sha256',RECIPE),('processing_tool_sha256',Path(__file__)),('matte_engine_sha256',ENGINE)]:
        if proof.get(field)!=base.digest(path):raise ValueError('Source recovery provenance changed: '+field)
    if proof.get('sources')!=recipe['sources'] or set(proof.get('assets',{}))!=set(recipe['assets']):
        raise ValueError('Source recovery membership/provenance changed')
    reports = {}
    for key,spec in recipe['assets'].items():
        entry = manifest['object_assets'][key]
        errors = []
        if entry.get('source_processing_manifest')!=base.resource(PACKET/'manifest.json'):
            errors.append('missing/mismatched processing manifest')
        sha = base.digest(base.local(entry['path']))
        if entry.get('runtime_sha256')!=sha or proof['assets'][key].get('runtime_sha256')!=sha:
            errors.append('runtime/provenance hash mismatch')
        expected = recover(sheets[spec['source']],spec)
        with Image.open(base.local(entry['path'])) as actual:
            if actual.mode!='RGBA' or actual.size!=(512,512) or actual.tobytes()!=expected.tobytes():
                errors.append('pixels differ from source-backed original painting')
        reports[key] = dict(ok=not errors,errors=errors)
    return reports


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--install',action='store_true')
    args = parser.parse_args()
    rows = prepare(args.output,args.install)
    print(json.dumps(dict(installed=args.install,assets=len(rows),output=str(args.output))))


if __name__=='__main__':main()
