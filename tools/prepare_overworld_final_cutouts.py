#!/usr/bin/env python3
"""Recover original encounter silhouettes without altering shared unit UI art.

The final 71-row complement includes 29 framed-icon routes and 42 individually
reviewed controls. Original figure registration is retained at fourfold density;
no badge drawing, color key, new painting or gameplay change is used.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil

import numpy as np
from PIL import Image, ImageDraw, ImageStat, ImageChops

ROOT = Path(__file__).resolve().parents[1]
PACKET = ROOT / 'art/overworld/source/generated/cutout_recovery_20260909/final_families'
RECIPE = PACKET / 'recipe.json'
MANIFEST = ROOT / 'art/overworld/manifest.json'
TRIM = ROOT / 'art/overworld/source/trimmed/cutout_recovery_20260909/final_families'
RUNTIME = ROOT / 'art/overworld/runtime/objects/encounters/creature_silhouettes'
AUTHOR = ROOT / 'tools/generate_unit_art_assets.py'
spec = importlib.util.spec_from_file_location('final_cutout_owner', ROOT / 'tools/prepare_overworld_contract_cutouts.py')
shared = importlib.util.module_from_spec(spec)
spec.loader.exec_module(shared)
base, owner, project = shared.base, shared.owner, shared.project


def local(path):
    allowed = ('res://art/overworld/', 'res://art/units/', 'res://art/animation/runtime/units/')
    if '..' in Path(path).parts or not (path.startswith(allowed) or path == 'res://content/unit_art_manifest.json'):
        raise ValueError('Unscoped source or derivative path: ' + path)
    return ROOT / path.removeprefix('res://')


def rgba(path):
    with Image.open(path) as image:
        return image.convert('RGBA')


def prior_assets():
    accepted, hashes = set(), {}
    for path in sorted(PACKET.parent.glob('*/recipe.json')):
        if path == RECIPE:
            continue
        recipe = json.loads(path.read_text())
        accepted.update(recipe.get('assets', {}))
        accepted.update(recipe.get('preserved_controls', {}))
        hashes[str(path.relative_to(ROOT))] = base.digest(path)
    if len(accepted) != 1143:
        raise ValueError('Earlier accepted membership changed')
    return accepted, hashes


def registration(source):
    crop = list(source.getchannel('A').getbbox())
    w, h = crop[2] - crop[0], crop[3] - crop[1]
    scale = min(82 / w, 76 / h)
    fit = [max(1, round(w * scale)), max(1, round(h * scale))]
    return dict(source_crop=crop, source_resize=fit,
                canvas_origin=[(96 - fit[0]) // 2, 85 - fit[1]],
                canvas_size=[384, 384], pixel_scale=4, resampling='LANCZOS')


def historical_paint_error(source, row):
    projected = project(source, dict(row, canvas_size=[96, 96], pixel_scale=1))
    old = rgba(local(row['original_manifest_entry']['path']))
    mask = np.asarray(projected)[:, :, 3] >= 250
    # Existing tier pips are a later UI overlay, not part of the creature.
    mask[81:96, 10:63] = False
    diff = ImageChops.difference(projected.convert('RGB'), old.convert('RGB'))
    return sum(ImageStat.Stat(diff, Image.fromarray(mask.astype('uint8') * 255)).mean) / 3


def expected_entry(row):
    entry = row['original_manifest_entry']
    if row['mode'] == 'preserved_final':
        return entry
    return dict(entry, path=row['runtime_path'], source_generated=row['source_path'],
                source_trimmed=row['trimmed_path'],
                source_processing_manifest=base.resource(PACKET / 'manifest.json'))


def initialize():
    if RECIPE.exists():
        raise ValueError('Never overwrite a frozen recipe')
    manifest = json.loads(MANIFEST.read_text())
    accepted, recipes = prior_assets()
    entries = manifest['object_assets']
    if len(entries) != 1214 or not accepted <= entries.keys():
        raise ValueError('Authoritative pool changed')
    unit_manifest = ROOT / 'content/unit_art_manifest.json'
    units = {r['unit_id']: r for r in json.loads(unit_manifest.read_text())['items']}
    provenance = {p: p.read_text() for p in (ROOT / 'art/units/source/curated').glob('*manifest*.json')}
    rows = {}
    for key in sorted(entries.keys() - accepted):
        entry = entries[key]
        repair = '/art/units/overworld_icons/' in entry['path']
        paths = {v for k, v in entry.items() if k.startswith('source_') and isinstance(v, str) and v.startswith('res://') and local(v).is_file()}
        image = rgba(local(entry['path']))
        size = entry.get('atlas_region', [0, 0, *image.size])[2:]
        row = dict(original_manifest_entry=entry, runtime_path=entry['path'],
                   mode='creature_silhouette' if repair else 'preserved_final',
                   canvas_size=list(size), before_sha256=base.digest(local(entry['path'])))
        if repair:
            unit_id = Path(entry['path']).stem
            unit = units[unit_id]
            source_path = unit['curated_source']
            source = rgba(local(source_path))
            if source.size != (512, 512) or base.digest(local(source_path)) != unit['curated_source_sha256']:
                raise ValueError('Exact curated original required: ' + unit_id)
            paths.add(source_path)
            paths.add(base.resource(unit_manifest))
            paths.update(v for v in unit.values() if isinstance(v, str) and v.startswith('res://') and local(v).is_file())
            paths.add('res://art/animation/runtime/units/' + unit_id + '.png')
            paths.update(base.resource(p) for p, text in provenance.items() if unit_id in text)
            row.update(registration(source))
            row.update(unit_id=unit_id, source_path=source_path, unit_art_record=unit,
                       runtime_path=base.resource(RUNTIME / (unit_id + '.png')),
                       trimmed_path=base.resource(TRIM / (key + '.png')))
            row['historical_opaque_rgb_mae'] = historical_paint_error(source, row)
            # Fifteen old cards were palette-quantized; retain exact error and
            # source-code registration proof, not a false pixel-equality claim.
            if row['historical_opaque_rgb_mae'] > 17:
                raise ValueError('Original figure registration not established: ' + key)
        row['source_hashes'] = {p: base.digest(local(p)) for p in sorted(paths)}
        rows[key] = row
    if len(rows) != 71 or sum(r['mode'] == 'creature_silhouette' for r in rows.values()) != 29:
        raise ValueError('Final cohort changed')
    recipe = dict(schema_id='final_family_cutout_recipe_v1', baseline_commit='e98911c5c26ce1edf1f332d58c1be3c4cad89f61',
                  earlier_recipes=recipes, authoring_tool_sha256=base.digest(AUTHOR), assets=rows,
                  mapping_tables={k: v for k, v in manifest.items() if k != 'object_assets'})
    PACKET.mkdir(parents=True, exist_ok=True)
    RECIPE.write_text(json.dumps(recipe, indent=2) + '\n')
    return dict(dispositions=71, recoveries=29, controls=42)


def inputs():
    recipe = json.loads(RECIPE.read_text())
    manifest = json.loads(MANIFEST.read_text())
    accepted, hashes = prior_assets()
    if recipe['schema_id'] != 'final_family_cutout_recipe_v1' or recipe['earlier_recipes'] != hashes:
        raise ValueError('Accepted-pool provenance changed')
    if set(manifest['object_assets']) - accepted != recipe['assets'].keys() or len(recipe['assets']) != 71:
        raise ValueError('Final-pool membership changed')
    if recipe['mapping_tables'] != {k: v for k, v in manifest.items() if k != 'object_assets'}:
        raise ValueError('Gameplay identity mapping tables changed')
    if base.digest(AUTHOR) != recipe['authoring_tool_sha256']:
        raise ValueError('Historical figure registration owner changed')
    sources = {}
    for key, row in recipe['assets'].items():
        old = row['original_manifest_entry']
        entry = manifest['object_assets'][key]
        if base.digest(local(old['path'])) != row['before_sha256']:
            raise ValueError('Preserved control or original UI icon changed: ' + key)
        for path, sha in row['source_hashes'].items():
            if base.digest(local(path)) != sha:
                raise ValueError('Original painting/provenance/UI surface changed: ' + path)
        if row['mode'] == 'preserved_final':
            if entry != old:
                raise ValueError('Preserved control metadata changed: ' + key)
            continue
        if row['mode'] != 'creature_silhouette':
            raise ValueError('Unknown final-family mode')
        strip = lambda e: {k: v for k, v in e.items() if k != 'runtime_sha256'}
        if strip(entry) not in (strip(old), strip(expected_entry(row))):
            raise ValueError('Exact creature identity metadata changed')
        source = rgba(local(row['source_path']))
        if any(row[k] != v for k, v in registration(source).items()):
            raise ValueError('Historical figure crop/fit/origin changed')
        if historical_paint_error(source, row) != row['historical_opaque_rgb_mae']:
            raise ValueError('Historical registration evidence changed')
        if local(row['runtime_path']) != RUNTIME / (row['unit_id'] + '.png') or local(row['trimmed_path']) != TRIM / (key + '.png'):
            raise ValueError('Unscoped creature derivative')
        sources[key] = source
    if len(sources) != 29:
        raise ValueError('Incomplete creature restoration')
    return recipe, manifest, sources


def prepare(output, install=False):
    output = output.resolve()
    if output == ROOT or output.is_relative_to(ROOT / 'art'):
        raise ValueError('Preview outside source art required')
    recipe, manifest, sources = inputs()
    output.mkdir(parents=True, exist_ok=False)
    rows, files = {}, {}
    for key, source in sources.items():
        row = recipe['assets'][key]
        result = project(source, row)
        target = output / 'runtime' / local(row['runtime_path']).relative_to(ROOT / 'art/overworld/runtime')
        target.parent.mkdir(parents=True, exist_ok=True)
        result.save(target, optimize=True)
        rows[key] = dict(rgba_sha256=hashlib.sha256(result.tobytes()).hexdigest(), png_sha256=base.digest(target))
        files[row['runtime_path']] = dict(after_sha256=base.digest(target), prepared=str(target.relative_to(output)))
        canvas = Image.new('RGB', (1152, 410), '#334c3a')
        old = rgba(local(row['original_manifest_entry']['path']))
        for col, image in enumerate((old.resize((384, 384), Image.Resampling.NEAREST), old.resize((384, 384), Image.Resampling.LANCZOS), result)):
            canvas.paste(image, (col * 384, 24), image)
        ImageDraw.Draw(canvas).text((3, 4), key + ' | OLD nearest / OLD smooth / ORIGINAL without UI backing', fill='white')
        canvas.save(output / (key + '_comparison.png'))
    for key, row in recipe['assets'].items():
        if key in sources:
            continue
        target = output / 'runtime' / local(row['runtime_path']).relative_to(ROOT / 'art/overworld/runtime')
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(local(row['runtime_path']), target)
    proof = dict(schema_id='final_family_cutout_recovery_v1', recipe_sha256=base.digest(RECIPE),
                 tool_sha256=base.digest(Path(__file__)), projection_tools=shared.tool_hashes(),
                 processing='Exact curated original creature paint; historical 82x76 fit and bottom origin at fourfold density. No shield plate, ellipse, tier pips, color key or new paint. All shared unit UI and 42 reviewed control mappings unchanged.', assets=rows, files=files)
    if install:
        previous = json.loads((PACKET / 'manifest.json').read_text()) if (PACKET / 'manifest.json').exists() else {}
        for key in sources:
            row = recipe['assets'][key]
            for field in ('runtime_path', 'trimmed_path'):
                target = local(row[field])
                if target.exists() and base.digest(target) != previous.get('assets', {}).get(key, {}).get('png_sha256'):
                    raise ValueError('Unrecognized existing derivative: ' + str(target))
        for key in sources:
            row = recipe['assets'][key]
            for field in ('runtime_path', 'trimmed_path'):
                target = local(row[field]); target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(output / files[row['runtime_path']]['prepared'], target)
            manifest['object_assets'][key] = dict(expected_entry(row), runtime_sha256=rows[key]['png_sha256'])
        MANIFEST.write_text(owner.manifest_text(manifest, sources))
        (PACKET / 'manifest.json').write_text(json.dumps(proof, indent=2) + '\n')
    (output / 'report.json').write_text(json.dumps(proof, indent=2) + '\n')
    return dict(installed=install, dispositions=71, recoveries=29, controls=42)


def validate_assets():
    recipe, manifest, sources = inputs()
    proof = json.loads((PACKET / 'manifest.json').read_text())
    if proof['schema_id'] != 'final_family_cutout_recovery_v1' or proof['recipe_sha256'] != base.digest(RECIPE) or proof['tool_sha256'] != base.digest(Path(__file__)) or proof['projection_tools'] != shared.tool_hashes():
        raise ValueError('Final cutout preparation provenance changed')
    if set(proof['assets']) != sources.keys() or set(proof['files']) != {recipe['assets'][k]['runtime_path'] for k in sources}:
        raise ValueError('Incomplete creature provenance')
    for key, source in sources.items():
        row = recipe['assets'][key]; result = project(source, row)
        if manifest['object_assets'][key] != dict(expected_entry(row), runtime_sha256=proof['assets'][key]['png_sha256']):
            raise ValueError('Creature world asset ownership changed')
        if hashlib.sha256(result.tobytes()).hexdigest() != proof['assets'][key]['rgba_sha256']:
            raise ValueError('Original paint projection changed')
        for field in ('runtime_path', 'trimmed_path'):
            path = local(row[field])
            if rgba(path).tobytes() != result.tobytes() or base.digest(path) != proof['assets'][key]['png_sha256']:
                raise ValueError('Badge geometry or changed creature paint in world asset')
        if proof['files'][row['runtime_path']]['after_sha256'] != proof['assets'][key]['png_sha256']:
            raise ValueError('Creature runtime hash changed')
    return {k: dict(ok=True, errors=[]) for k in recipe['assets']}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--initialize', action='store_true')
    parser.add_argument('--output', type=Path)
    parser.add_argument('--install', action='store_true')
    args = parser.parse_args()
    if not args.initialize and not args.output:
        parser.error('--output required')
    print(json.dumps(initialize() if args.initialize else prepare(args.output, args.install)))
