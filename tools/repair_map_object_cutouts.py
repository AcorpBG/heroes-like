#!/usr/bin/env python3
"""Approved alpha extraction repair of two original, hash-locked paintings.

No replacement shapes or new painted pixels. Reuse the analytical magenta
unmatting approach accepted for Wreck Quay, with independently inspected bounds.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PROVENANCE_DIR = ROOT / 'art/overworld/source/generated/full_match_art_repairs/cinder_moss_cutouts'
PROVENANCE_PATH = PROVENANCE_DIR / 'manifest.json'
ART_MANIFEST = ROOT / 'art/overworld/manifest.json'
SPECS = {
    'mapobj_cinder_ore_face': {
        'input_sha256': 'cdb0b47286ca8efd019c4eded10ff9ffa7299d9d1b61a0c236ebc9bc151e6e3b',
        'body_window': (110, 112, 408, 399),
        'atlas_batch': '04',
        'atlas_sha256': '8b5091ec6a85380c799672fce7ef97320fe933e286a4acb931bf08ad0e64508f',
        'reason': 'Exclude the inspected left and bottom white/magenta cell dividers; retain the entire mine, scaffolding, ladders, tracks and rock base.',
    },
    'mapobj_moss_oath_cache': {
        'input_sha256': '061c5d022fc03fba0ecccc0b786c3d95b603036c5f9b0aab89f2f9305ed2262c',
        'body_window': (108, 130, 406, 394),
        'atlas_batch': '09',
        'atlas_sha256': '316451178feadfb669d8125c9164af99e41185d8f62852ffd083179a9ddff7e2',
        'reason': 'Exclude isolated cell debris above/left of the subject; retain the complete chest, three stones, flowers, plants and ground edge.',
    },
}


def paths(asset_id):
    if asset_id not in SPECS:
        raise ValueError('Unsupported cutout identity: ' + asset_id)
    return {
        'input': PROVENANCE_DIR / (asset_id + '_before.png'),
        'runtime': ROOT / ('art/overworld/runtime/objects/map_objects/distinct/' + asset_id + '.png'),
        'trimmed': ROOT / ('art/overworld/source/trimmed/map_objects/distinct/' + asset_id + '-trimmed.png'),
        'atlas': ROOT / ('art/overworld/source/generated/map_objects/distinct/map_object_distinct_atlas_20260504_batch_' + SPECS[asset_id]['atlas_batch'] + '.png'),
    }


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def repair_image(asset_id, source):
    if asset_id not in SPECS:
        raise ValueError('Unsupported cutout identity: ' + asset_id)
    if source.mode != 'RGBA' or source.size != (512, 512):
        raise ValueError('Expected original 512x512 RGBA cutout')
    result = source.copy()
    pixels = result.load()
    left, top, right, bottom = SPECS[asset_id]['body_window']
    for y in range(512):
        for x in range(512):
            r, g, b, a = pixels[x, y]
            if not (left <= x < right and top <= y < bottom):
                pixels[x, y] = (0, 0, 0, 0)
                continue
            spill = max(0, min(r, b) - g)
            if a == 0 or spill <= 8:
                continue
            coverage = 1.0 - spill / 255.0
            if coverage <= 0:
                pixels[x, y] = (0, 0, 0, 0)
            else:
                pixels[x, y] = (
                    min(255, round((r - spill) / coverage)),
                    min(255, round(g / coverage)),
                    min(255, round((b - spill) / coverage)),
                    round(a * coverage),
                )
    return result


def inspect_image(asset_id, path):
    if asset_id not in SPECS:
        raise ValueError('Unsupported cutout identity: ' + asset_id)
    with Image.open(path) as source:
        if source.mode != 'RGBA' or source.size != (512, 512):
            return dict(ok=False, errors=['not original 512x512 RGBA canvas'])
        left, top, right, bottom = SPECS[asset_id]['body_window']
        pixels = source.load()
        divider = magenta = painted = 0
        for y in range(512):
            for x in range(512):
                r, g, b, a = pixels[x, y]
                if not a:
                    continue
                painted += 1
                divider += not (left <= x < right and top <= y < bottom)
                magenta += min(r, b) - g > 8
        errors = []
        if divider:
            errors.append('sheet debris outside complete painted body')
        if magenta:
            errors.append('magenta-key contamination')
        if painted < 20000 or source.getchannel('A').getextrema() != (0, 255):
            errors.append('missing complete painted subject or genuine alpha')
        return dict(ok=not errors, errors=errors, divider_pixels=divider,
                    magenta_pixels=magenta, painted_pixels=painted,
                    alpha_bounds=source.getchannel('A').getbbox())


def preserve_inputs():
    # Validate the whole pair before copying either input; never overwrite a master.
    for asset_id, spec in SPECS.items():
        files = paths(asset_id)
        candidate = files['input'] if files['input'].exists() else files['runtime']
        if digest(candidate) != spec['input_sha256']:
            raise ValueError('Original cutout hash changed: ' + asset_id)
        if not files['atlas'].is_file() or digest(files['atlas']) != spec['atlas_sha256']:
            raise ValueError('Original generated atlas missing or changed: ' + asset_id)
    PROVENANCE_DIR.mkdir(parents=True, exist_ok=True)
    for asset_id in SPECS:
        files = paths(asset_id)
        if not files['input'].exists():
            files['input'].write_bytes(files['runtime'].read_bytes())


def prepare():
    preserve_inputs()
    manifest_text = ART_MANIFEST.read_text()
    manifest = json.loads(manifest_text)
    prepared = {}
    # Check every identity before altering either registered runtime path.
    for asset_id in SPECS:
        files = paths(asset_id)
        row = manifest['object_assets'][asset_id]
        for field, expected in [('assigned_map_object_id', asset_id.replace('mapobj_', 'object_', 1)),
                                ('path', 'res://' + str(files['runtime'].relative_to(ROOT))),
                                ('source_trimmed', 'res://' + str(files['trimmed'].relative_to(ROOT))),
                                ('source_generated_atlas', 'res://' + str(files['atlas'].relative_to(ROOT)))]:
            if row.get(field) != expected:
                raise ValueError('Identity/provenance mismatch: ' + asset_id + '/' + field)
        with Image.open(files['input']) as source:
            prepared[asset_id] = repair_image(asset_id, source)
    rows = {}
    for asset_id, result in prepared.items():
        files = paths(asset_id)
        for output in (files['trimmed'], files['runtime']):
            result.save(output, optimize=True)
        proof = inspect_image(asset_id, files['runtime'])
        if not proof['ok']:
            raise ValueError('Prepared image failed validation: ' + asset_id)
        rows[asset_id] = dict(
            input='res://' + str(files['input'].relative_to(ROOT)),
            input_sha256=SPECS[asset_id]['input_sha256'],
            original_generated_atlas='res://' + str(files['atlas'].relative_to(ROOT)),
            original_generated_atlas_sha256=digest(files['atlas']),
            runtime='res://' + str(files['runtime'].relative_to(ROOT)),
            trimmed='res://' + str(files['trimmed'].relative_to(ROOT)),
            runtime_sha256=digest(files['runtime']),
            body_window=SPECS[asset_id]['body_window'],
            inspected_boundary=SPECS[asset_id]['reason'],
            before=inspect_image(asset_id, files['input']), after=proof,
        )
        manifest['object_assets'][asset_id].update(
            source_processing_manifest='res://' + str(PROVENANCE_PATH.relative_to(ROOT)),
            runtime_sha256=rows[asset_id]['runtime_sha256'],
        )
    provenance = dict(
        schema_id='original_map_object_cutout_repair_v1',
        owner_approval='2026-09-07 approved Overworld cutout repairs; Cinder/Moss continuation selected in PLAN.md.',
        processing_tool='tools/repair_map_object_cutouts.py',
        processing='Original 512x512 RGBA canvases; remove inspected sheet debris outside each complete subject; analytically unmatte magenta and recover partial alpha. No replacement geometry or new painted pixels.',
        source_docs=['docs/generated-full-match-quality-requirements.md', 'docs/generated-full-match-art-repair-report.md'],
        generation='No new generation. Original built-in image-generated batch04/batch09 paintings and exact extracted before rasters are retained.',
        assets=rows,
    )
    PROVENANCE_PATH.write_text(json.dumps(provenance, indent=2) + '\n')
    # Retain all unrelated whitespace/rows as well as their semantic content.
    for asset_id in SPECS:
        pattern = r'(?ms)^    "' + re.escape(asset_id) + r'": \{\n.*?^    \}(?=,?\n)'
        replacement = '    ' + json.dumps(asset_id) + ': ' + json.dumps(manifest['object_assets'][asset_id], indent=2).replace('\n','\n    ')
        manifest_text, count = re.subn(pattern, lambda match: replacement, manifest_text)
        if count != 1:
            raise ValueError('Expected one exact manifest row: ' + asset_id)
    if json.loads(manifest_text) != manifest:
        raise ValueError('Scoped manifest update changed unrelated content')
    ART_MANIFEST.write_text(manifest_text)
    return rows


def validate_asset(asset_id, entry):
    """Fail closed for damaged pixels, mismatched provenance or replaced art."""
    files = paths(asset_id)
    report = inspect_image(asset_id, files['runtime'])
    errors = list(report['errors'])
    try:
        spec = SPECS[asset_id]
        provenance = json.loads(PROVENANCE_PATH.read_text())
        row = provenance['assets'][asset_id]
        expected_paths = {
            'path': files['runtime'], 'source_trimmed': files['trimmed'],
            'source_generated_atlas': files['atlas'], 'source_processing_manifest': PROVENANCE_PATH,
        }
        for key, path in expected_paths.items():
            if entry.get(key) != 'res://' + str(path.relative_to(ROOT)):
                errors.append('manifest path mismatch: ' + key)
        if entry.get('assigned_map_object_id') != asset_id.replace('mapobj_', 'object_', 1):
            errors.append('assigned map-object identity mismatch')
        for key, path, expected in (
            ('input_sha256', files['input'], spec['input_sha256']),
            ('original_generated_atlas_sha256', files['atlas'], spec['atlas_sha256']),
            ('runtime_sha256', files['runtime'], entry.get('runtime_sha256')),
        ):
            if digest(path) != expected or row.get(key) != expected:
                errors.append('provenance hash mismatch: ' + key)
        for key, path in [('input',files['input']), ('runtime',files['runtime']),
                          ('trimmed',files['trimmed']), ('original_generated_atlas',files['atlas'])]:
            if row.get(key) != 'res://' + str(path.relative_to(ROOT)):
                errors.append('processing path mismatch: ' + key)
        if row.get('body_window') != list(spec['body_window']):
            errors.append('processing body bounds mismatch')
        if files['trimmed'].read_bytes() != files['runtime'].read_bytes():
            errors.append('trimmed/runtime mismatch')
        with Image.open(files['input']) as original, Image.open(files['runtime']) as runtime:
            if repair_image(asset_id, original).tobytes() != runtime.tobytes():
                errors.append('runtime differs from approved original-raster processing')
    except (OSError, KeyError, ValueError) as error:
        errors.append('missing or invalid processing provenance: ' + str(error))
    return dict(report, ok=not errors, errors=errors)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument('--preserve-inputs', action='store_true')
    modes.add_argument('--write', action='store_true')
    modes.add_argument('--check', action='store_true')
    args = parser.parse_args()
    if args.preserve_inputs:
        preserve_inputs()
        print('Preserved both exact original extracted rasters; runtime unchanged')
        return 0
    if args.write:
        rows = prepare()
        print(json.dumps({asset: row['after'] for asset, row in rows.items()}))
        return 0
    manifest = json.loads(ART_MANIFEST.read_text())
    result = {asset: validate_asset(asset, manifest['object_assets'][asset]) for asset in SPECS}
    print(json.dumps(result))
    return 0 if all(row['ok'] for row in result.values()) else 1


if __name__ == '__main__':
    raise SystemExit(main())
