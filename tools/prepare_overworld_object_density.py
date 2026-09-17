#!/usr/bin/env python3
"""Repack existing original object paintings at useful raster density.

The historical 48px atlases/proofs stay intact. A hash-bound presentation-only
manifest selects the 192px derivatives. No painting, generation or game edits.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path

from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
PACKET = ROOT / 'art/overworld/source/generated/object_density_20260917'
RECIPE = PACKET / 'recipe.json'
PROOF = PACKET / 'manifest.json'
DENSITY = ROOT / 'art/overworld/object_raster_density.json'
ART = ROOT / 'art/overworld/manifest.json'
RUNTIME = ROOT / 'art/overworld/runtime/objects/density_20260917'
TRIMMED = ROOT / 'art/overworld/source/trimmed/object_density_20260917'


def digest(data):
    return hashlib.sha256(data).hexdigest()


def local(path):
    if not path.startswith('res://art/overworld/'):
        raise ValueError('Unscoped art path: ' + path)
    result = ROOT / path.removeprefix('res://')
    if not result.resolve().is_relative_to((ROOT / 'art/overworld').resolve()):
        raise ValueError('Art path escaped root')
    return result


def resource(path):
    return 'res://' + path.relative_to(ROOT).as_posix()


def encode(image):
    output = io.BytesIO()
    image.save(output, format='PNG', optimize=True)
    return output.getvalue()


def initialize():
    if RECIPE.exists():
        raise ValueError('Do not replace a frozen recipe')
    art = json.loads(ART.read_text())
    passages_path = ROOT / 'art/overworld/source/generated/cutout_recovery_20260909/passages/recipe.json'
    passages = json.loads(passages_path.read_text())['assets']
    rows = {}
    for key, entry in art['object_assets'].items():
        if entry.get('atlas_region', [0, 0, 1000])[2] != 48:
            continue
        source = entry['source_generated']
        mode = 'rgba'
        if key in passages:
            source = passages[key]['recovered_source_path']
        elif key == 'resource_site_neutral_miremoon_crownmere_controlled':
            mode = 'frozen_legacy_matte'
        row = {'original_entry': entry, 'source': source, 'source_sha256': digest(local(source).read_bytes()), 'mode': mode}
        rows[key] = row
    if len(rows) != 35:
        raise ValueError('Expected exactly the 35 reviewed low-density states')
    recipe = {'schema_id': 'overworld_object_density_recipe_v1', 'cell_size': 192, 'paint_limit': 176,
              'filter': 'LANCZOS', 'policy': 'Preserve original RGBA paint; tight aspect-fit with eight-pixel minimum clear margin; no generated or procedural substitute.',
              'assets': rows,
              'historical_proof_sha256': {resource(p): digest(p.read_bytes()) for p in [passages_path, passages_path.with_name('manifest.json'), ROOT / 'art/overworld/source/generated/cutout_recovery_20260909/legacy_families/recipe.json', ROOT / 'art/overworld/source/generated/cutout_recovery_20260909/legacy_families/manifest.json']}}
    PACKET.mkdir(parents=True, exist_ok=True)
    RECIPE.write_text(json.dumps(recipe, indent=2) + '\n')


def paint(row):
    path = local(row['source'])
    if digest(path.read_bytes()) != row['source_sha256']:
        raise ValueError('Original source changed: ' + row['source'])
    with Image.open(path) as opened:
        if row['mode'] == 'rgba':
            if opened.mode != 'RGBA':
                raise ValueError('Real alpha required')
            return opened.copy()
        if row['mode'] != 'frozen_legacy_matte':
            raise ValueError('Unreviewed source mode')
        import prepare_overworld_legacy_cutouts as legacy
        recipe = json.loads(legacy.RECIPE.read_text())
        spec = recipe['assets']['resource_site_neutral_miremoon_crownmere_controlled']
        return legacy.source_paint(opened.convert('RGB'), spec)


def build():
    recipe = json.loads(RECIPE.read_text())
    if recipe['schema_id'] != 'overworld_object_density_recipe_v1' or recipe['cell_size'] != 192 or recipe['paint_limit'] != 176 or len(recipe['assets']) != 35:
        raise ValueError('Unreviewed density recipe')
    art = json.loads(ART.read_text())
    for path, expected in recipe['historical_proof_sha256'].items():
        if digest(local(path).read_bytes()) != expected:
            raise ValueError('Historical repair proof changed')
    mapping = {'schema_id': 'overworld_object_raster_density_v1', 'source_manifest': resource(PROOF), 'assets': {}}
    outputs, rows = {}, {}
    groups = {}
    for key, row in recipe['assets'].items():
        if art['object_assets'].get(key) != row['original_entry']:
            raise ValueError('Original identity/state mapping changed: ' + key)
        groups.setdefault(row['original_entry']['path'], []).append(key)
    for old_path, keys in sorted(groups.items()):
        keys.sort(key=lambda key: recipe['assets'][key]['original_entry']['atlas_region'][0])
        atlas = Image.new('RGBA', (192 * len(keys), 192))
        runtime = RUNTIME / Path(old_path).name
        for slot, key in enumerate(keys):
            row = recipe['assets'][key]
            source = paint(row)
            bounds = source.getchannel('A').getbbox()
            if not bounds:
                raise ValueError('Empty painting: ' + key)
            fitted = ImageOps.contain(source.crop(bounds), (176, 176), Image.Resampling.LANCZOS)
            cell = Image.new('RGBA', (192, 192))
            cell.paste(fitted, ((192 - fitted.width) // 2, 184 - fitted.height))
            # Source alpha stays authoritative; never composite against a matte.
            atlas.paste(cell, (slot * 192, 0))
            outputs[TRIMMED / (key + '.png')] = encode(cell)
            mapping['assets'][key] = {'path': resource(runtime), 'atlas_region': [slot * 192, 0, 192, 192], 'atlas_size': [atlas.width, atlas.height], 'original_path': old_path, 'original_region': row['original_entry']['atlas_region']}
            rows[key] = {'source': row['source'], 'source_sha256': row['source_sha256'], 'source_size': list(source.size), 'source_bounds': list(bounds), 'trimmed_path': resource(TRIMMED / (key + '.png')), 'trimmed_sha256': digest(outputs[TRIMMED / (key + '.png')]), 'rgba_sha256': digest(cell.tobytes())}
        outputs[runtime] = encode(atlas)
    proof = {'schema_id': 'overworld_object_density_proof_v1', 'recipe_sha256': digest(RECIPE.read_bytes()), 'tool_sha256': digest(Path(__file__).read_bytes()), 'assets': rows, 'runtime': {resource(p): {'bytes': len(data), 'sha256': digest(data)} for p, data in outputs.items() if p.parent == RUNTIME}, 'policy': recipe['policy']}
    outputs[DENSITY] = (json.dumps(mapping, indent=2) + '\n').encode()
    outputs[PROOF] = (json.dumps(proof, indent=2) + '\n').encode()
    return outputs


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--initialize', action='store_true')
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    if args.initialize:
        initialize()
    outputs = build()
    for path, data in outputs.items():
        if args.check:
            if path.read_bytes() != data:
                raise ValueError('Derived art is not reproducible: ' + str(path))
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
    print(json.dumps({'ok': True, 'assets': 35, 'atlases': 4, 'bytes': sum(len(v) for p, v in outputs.items() if p.parent == RUNTIME)}))


if __name__ == '__main__':
    main()
