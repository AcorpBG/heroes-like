#!/usr/bin/env python3
"""Recover approved original sheet paintings, with locked identities and alignment.

This is offline asset preparation, never a runtime shader or fallback drawing.
The recipe names inspected cells, original hashes and integer canvas alignment.
Do not apply this scoped matte model to arbitrary purple artwork.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
PACKET = ROOT / 'art/overworld/source/generated/cutout_recovery_20260909/batch04'
RECIPE = PACKET / 'recipe.json'
ART_MANIFEST = ROOT / 'art/overworld/manifest.json'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def local(path):
    if not path.startswith('res://art/overworld/') or '..' in Path(path).parts:
        raise ValueError('Expected a scoped overworld art path: ' + path)
    return ROOT / path.removeprefix('res://')


def resource(path):
    return 'res://' + path.relative_to(ROOT).as_posix()


def nearest_colors(pixels, seeds, needed, width, height):
    """Deterministic nearest known color for a small offline matting band."""
    from collections import deque
    colors = [p if known else None for p, known in zip(pixels, seeds)]
    queue = deque(i for i, known in enumerate(seeds) if known)
    missing = set(needed)
    while queue and missing:
        i = queue.popleft()
        x, y = i % width, i // width
        for j in (i-1 if x else -1, i+1 if x+1 < width else -1,
                  i-width if y else -1, i+width if y+1 < height else -1):
            if j < 0 or colors[j] is not None:
                continue
            colors[j] = colors[i]
            missing.discard(j)
            queue.append(j)
    if missing:
        raise ValueError('Source has no recoverable foreground/background color')
    return colors


def recover_cell(source, radius=4, neutral_material=False, protected_rects=()):
    """Recover original color/alpha against the sheet's nonuniform pink key.

    The original backing varies in brightness and R:B ratio. Subtracting a
    constant (255,0,255) can turn it into red fringes. Use nearest known source
    backing and foreground colors for the compositing equation instead. White
    is always paint. The recipe explicitly protects intentional coral pigment;
    the neutral-material mode is restricted to individually reviewed paintings.
    """
    source = source.convert('RGB')
    pixels = list(source.getdata())
    width, height = source.size
    keys = [g <= 24 and min(r, b) > 80 and min(r, b)-g > 64 for r,g,b in pixels]
    backing = Image.new('L', source.size)
    backing.putdata([255 if k else 0 for k in keys])
    band = list(backing.filter(ImageFilter.MaxFilter(radius*2+1)).getdata())
    unknown = []
    for i, ((r,g,b), key, near) in enumerate(zip(pixels, keys, band)):
        x,y = i % width, i // width
        protected = any(l <= x < rr and t <= y < bb for l,t,rr,bb in protected_rects)
        if not key and not protected and min(r,b)-g > 8 and (neutral_material or near):
            unknown.append(i)
    unknown_set = set(unknown)
    foreground = nearest_colors(pixels, [not k and i not in unknown_set and
        (not neutral_material or min(pixels[i][0],pixels[i][2])-pixels[i][1]<=8)
        for i,k in enumerate(keys)], unknown, width,height)
    background = nearest_colors(pixels, keys, unknown, width,height)
    output = [(0,0,0,0) if k else (*p,255) for p,k in zip(pixels,keys)]
    for i in unknown:
        p, fg, bg = pixels[i], foreground[i], background[i]
        delta = [f-b for f,b in zip(fg,bg)]
        denom = sum(d*d for d in delta)
        if not denom:
            raise ValueError('Ambiguous foreground/background color')
        coverage = max(0.0,min(1.0,sum((c-b)*d for c,b,d in zip(p,bg,delta))/denom))
        alpha = round(coverage*255)
        if alpha < 4:
            output[i] = (0,0,0,0)
        else:
            # With a nonuniform generated matte, inverse division amplifies
            # small color residuals into green/red pinholes. Decontaminate the
            # uncertain band with its nearest intact source-paint color while
            # retaining coverage measured from the original composite.
            output[i] = (*fg,alpha)
    result = Image.new('RGBA',source.size)
    result.putdata(output)
    return result


def recover_asset(sheet, spec):
    rect = spec['source_rect']
    protected = [(l-rect[0], t-rect[1], r-rect[0], b-rect[1])
                 for l, t, r, b in spec.get('protected_source_rects', [])]
    cell = recover_cell(sheet.crop(tuple(rect)), spec.get('matte_boundary_radius', 4),
                        spec.get('matte_policy') == 'inspected_neutral_materials', protected)
    result = Image.new('RGBA', (512, 512))
    # Paste, not mask-composite: applying alpha twice would thin the silhouette.
    result.paste(cell, tuple(spec['canvas_origin']))
    return result


def inspect(image):
    image = image.convert('RGBA')
    alpha = image.getchannel('A')
    pixels = list(image.getdata())
    return dict(size=list(image.size), alpha_extrema=list(alpha.getextrema()),
                painted_bounds=list(alpha.getbbox()) if alpha.getbbox() else None,
                opaque_pixels=sum(a == 255 for _, _, _, a in pixels),
                visible_pixels=sum(a > 0 for _, _, _, a in pixels),
                magenta_review_pixels=sum(a >= 32 and min(r, b) - g > 50
                                         and min(r, b) > 140 for r, g, b, a in pixels))


def load_inputs(recipe_path=RECIPE):
    recipe = json.loads(recipe_path.read_text())
    manifest = json.loads(ART_MANIFEST.read_text())
    atlas = local(recipe['source_atlas'])
    if digest(atlas) != recipe['source_sha256']:
        raise ValueError('Original sheet hash changed')
    sheet = Image.open(atlas).convert('RGB')
    selected = recipe['assets']
    members = {k for k, v in manifest['object_assets'].items()
               if v.get('source_generated_atlas') == recipe['source_atlas']}
    if set(selected) | set(recipe['preserved_controls']) != members:
        raise ValueError('Exact source-sheet membership changed')
    for asset_id, spec in selected.items():
        row = manifest['object_assets'][asset_id]
        for field in ('path', 'source_trimmed', 'source_generated_atlas', 'assigned_map_object_id'):
            if row.get(field) != spec['original_manifest_entry'].get(field):
                raise ValueError('Identity/mapping changed: ' + asset_id + '/' + field)
        before = recipe_path.parent / (asset_id + '_before.png')
        candidate = before if before.exists() else local(row['path'])
        if digest(candidate) != spec['before_sha256']:
            raise ValueError('Before raster changed: ' + asset_id)
        existing = local(row['path'])
        if digest(existing) != spec['before_sha256']:
            proof_path = recipe_path.parent / 'manifest.json'
            previous = json.loads(proof_path.read_text()) if proof_path.exists() else {}
            if digest(existing) != previous.get('assets', {}).get(asset_id, {}).get('runtime_sha256'):
                raise ValueError('Refusing to overwrite unrecognized runtime edit: ' + asset_id)
        if local(row['source_trimmed']).read_bytes() != existing.read_bytes():
            raise ValueError('Trim/runtime diverged: ' + asset_id)
        x, y = spec['canvas_origin']
        left, top, right, bottom = spec['source_rect']
        if not (0 <= left < right <= sheet.width and 0 <= top < bottom <= sheet.height
                and 0 <= x <= 512 - (right-left) and 0 <= y <= 512 - (bottom-top)):
            raise ValueError('Invalid source/canvas rectangle: ' + asset_id)
    for asset_id, expected in recipe['preserved_controls'].items():
        if digest(local(manifest['object_assets'][asset_id]['path'])) != expected:
            raise ValueError('Previously repaired control changed: ' + asset_id)
    return recipe, manifest, sheet


def prepare(output, install=False):
    # A preview directory must never overwrite source/runtime art before its
    # before-image is retained or overwrite this repository's top-level files.
    destination = output.resolve()
    if destination == ROOT.resolve() or destination.is_relative_to((ROOT/'art').resolve()):
        raise ValueError('Preview output must be outside the registered art tree')
    recipe, manifest, sheet = load_inputs()
    output.mkdir(parents=True, exist_ok=True)
    results = {key: recover_asset(sheet, spec) for key, spec in recipe['assets'].items()}
    rows = {}
    # Prepare and inspect the complete cohort before writing registered assets.
    for key, result in results.items():
        spec = recipe['assets'][key]
        path = output / (key + '.png')
        result.save(path, optimize=True)
        after = inspect(result)
        if after['alpha_extrema'] != [0, 255] or after['opaque_pixels'] < 18000:
            raise ValueError('Incomplete painted subject: ' + key)
        rows[key] = dict(runtime_sha256=digest(path), after=after,
                         source_rect=spec['source_rect'], canvas_origin=spec['canvas_origin'],
                         before_sha256=spec['before_sha256'],
                         runtime=spec['original_manifest_entry']['path'])
    contact = Image.new('RGB', (1024, 4 * 278), '#3d5140')
    draw = ImageDraw.Draw(contact)
    for index, (key, result) in enumerate(results.items()):
        x, y = (index % 4)*256, (index // 4)*278
        # Display the full original canvas; this image is review evidence only.
        thumb = result.resize((256, 256), Image.Resampling.LANCZOS)
        contact.paste(thumb, (x, y), thumb)
        draw.text((x+6, y+257), key.removeprefix('mapobj_'), fill='white')
    contact.save(output / 'contact.png')
    if install:
        for key, result in results.items():
            spec = recipe['assets'][key]
            entry = manifest['object_assets'][key]
            before = PACKET / (key + '_before.png')
            if not before.exists():
                shutil.copy2(local(entry['path']), before)
            for field in ('path', 'source_trimmed'):
                shutil.copyfile(output / (key + '.png'), local(entry[field]))
            rows[key]['before'] = resource(before)
            rows[key]['before_metrics'] = inspect(Image.open(before))
            entry.update(source_processing_manifest=resource(PACKET/'manifest.json'),
                         runtime_sha256=rows[key]['runtime_sha256'])
        proof = dict(schema_id='original_sheet_cutout_recovery_v1',
                     owner_approval='2026-09-09 explicit deterministic image-processing approval',
                     processing_tool='tools/prepare_overworld_cutout_art.py',
                     processing='Original RGB source cells; inspected gutter exclusion; coverage fitted against nearest source background/paint colors, contaminated color replaced by nearest intact source paint; explicit original coral-color protection; exact integer translation onto unchanged 512x512 canvases. No generated substitute or gameplay changes.',
                     processing_tool_sha256=digest(Path(__file__)),
                     recipe=resource(RECIPE), recipe_sha256=digest(RECIPE),
                     source_atlas=recipe['source_atlas'], source_sha256=recipe['source_sha256'],
                     assets=rows)
        (PACKET/'manifest.json').write_text(json.dumps(proof, indent=2)+'\n')
        text = ART_MANIFEST.read_text()
        for key in results:
            pattern = r'(?ms)^    "'+re.escape(key)+r'": \{\n.*?^    \}(?=,?\n)'
            replacement = '    '+json.dumps(key)+': '+json.dumps(manifest['object_assets'][key], indent=2).replace('\n','\n    ')
            text, count = re.subn(pattern, lambda match: replacement, text)
            if count != 1:
                raise ValueError('Expected one authoritative manifest row: '+key)
        if json.loads(text) != manifest:
            raise ValueError('Unrelated manifest content changed')
        ART_MANIFEST.write_text(text)
    (output/'report.json').write_text(json.dumps(dict(installed=install, assets=rows), indent=2)+'\n')
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--install', action='store_true')
    args = parser.parse_args()
    rows = prepare(args.output, args.install)
    print(json.dumps(dict(installed=args.install, assets=len(rows), output=str(args.output))))


def validate_batch_assets():
    """Fail closed on identity, source/provenance drift or damaged runtime art."""
    recipe, manifest, sheet = load_inputs()
    proof = json.loads((PACKET/'manifest.json').read_text())
    if proof.get('recipe_sha256') != digest(RECIPE) or proof.get('processing_tool_sha256') != digest(Path(__file__)):
        raise ValueError('Recovery recipe/tool provenance changed')
    if proof.get('source_sha256') != recipe['source_sha256'] or set(proof.get('assets',{})) != set(recipe['assets']):
        raise ValueError('Recovery source/membership provenance changed')
    reports = {}
    for key, spec in recipe['assets'].items():
        entry = manifest['object_assets'][key]
        row = proof['assets'][key]
        errors = []
        original = {k:v for k,v in entry.items() if k not in ('runtime_sha256','source_processing_manifest')}
        if original != spec['original_manifest_entry']:
            errors.append('original identity/placement metadata changed')
        if entry.get('source_processing_manifest') != resource(PACKET/'manifest.json'):
            errors.append('processing manifest missing/mismatched')
        if entry.get('runtime_sha256') != digest(local(entry['path'])) or entry.get('runtime_sha256') != row.get('runtime_sha256'):
            errors.append('runtime/provenance hash mismatch')
        expected = recover_asset(sheet,spec)
        with Image.open(local(entry['path'])) as actual:
            if actual.mode != 'RGBA' or actual.size != (512,512) or actual.tobytes() != expected.tobytes():
                errors.append('runtime pixels differ from exact original-source recovery')
        reports[key] = dict(ok=not errors,errors=errors)
    return reports


if __name__ == '__main__':
    main()
