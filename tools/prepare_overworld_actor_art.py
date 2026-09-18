#!/usr/bin/env python3
"""Register built-in generated actor art and reproducibly trim/package its alpha.

No image API, synthesis, color key, repainting or source-art replacement. Each
generated original is preserved; runtime derivatives are a crop/fit only.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PACKET = ROOT / 'art/overworld/source/generated/actor_readability_20260918'
RECIPE = PACKET / 'generation.json'
MANIFEST = ROOT / 'art/overworld/actor_sprites.json'
SIDE = 384


def read(path):
    return json.loads(path.read_text())


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def resource(path):
    return 'res://' + path.relative_to(ROOT).as_posix()


def local(path):
    if not path.startswith('res://'):
        raise ValueError('Expected a project resource')
    result = (ROOT / path[6:]).resolve()
    if not result.is_relative_to(ROOT / 'art'):
        raise ValueError('Art path escaped its owner')
    return result


def inventory():
    original = read(ROOT / 'art/overworld/manifest.json')
    heroes = read(ROOT / 'content/heroes.json')['items']
    units = {row['id']: row for row in read(ROOT / 'content/units.json')['items']}
    armies = {row['id']: row for row in read(ROOT / 'content/army_groups.json')['items']}
    assets = {}
    for hero in heroes:
        asset = original['hero_identity_sprites'].get(hero['id'], original['hero_faction_sprites'][hero['faction_id']])
        if asset in assets:
            raise ValueError('Distinct heroes unexpectedly share an actor: ' + asset)
        assets[asset] = dict(kind='hero', identity_id=hero['id'], name=hero['name'],
                             reference=original['object_assets'][asset]['path'])
    for profile in read(ROOT / 'content/generated_neutral_encounter_profiles.json')['profiles']:
        asset = profile['asset_id']
        unit = units[armies[profile['army_group_id']]['stacks'][0]['unit_id']]
        if asset in assets:
            if assets[asset]['kind'] != 'neutral' or assets[asset]['identity_id'] != unit['id']:
                raise ValueError('Different live actors share an asset: ' + asset)
            assets[asset]['encounter_ids'].append(profile['encounter_id'])
            continue
        assets[asset] = dict(kind='neutral', identity_id=unit['id'], encounter_ids=[profile['encounter_id']],
                             name=unit['name'], reference='res://art/units/source/curated/' + unit['id'] + '.png')
    for asset, row in assets.items():
        row.update(asset_id=asset, original_path=original['object_assets'][asset]['path'],
                   original_region=original['object_assets'][asset].get('atlas_region', []))
        row['reference_sha256'] = digest(local(row['reference']))
        row['prompt'] = (
            'Use case: identity-preserve. Asset type: finished original fantasy strategy OVERWORLD MAP SPRITE. '
            'Input image 1 is the exact character/creature identity reference for ' + row['name'] + '. '
            'Preserve its species, adult character identity, signature equipment, clothing and faction colors. '
            'Redraw this ONE figure as a strong readable painterly game miniature, not a character concept portrait. '
            'Three-quarter orthographic view looking down about 30 degrees; full body and feet visible, '
            'compact broad silhouette, slightly foreshortened legs and clear head/shoulders, natural proportions, '
            'recognizable at 70 pixels tall. For a beast keep its correct anatomy, horns, wings or limbs. '
            'Use broad light/mid/dark painted masses, clear warm highlights and cool dark recesses; crisp clean edges '
            'and consistent soft overhead light. No muddy all-dark figure or hair-thin limbs. '
            'Keep weapons close enough to form a coherent silhouette, with every part entirely inside the image. '
            'Fill the square canvas with 5 percent safety padding. GENUINELY TRANSPARENT alpha background. '
            'No scenery, building, ground tile, pedestal, border, checkerboard, white matte, detached shadow, '
            'text, label, logo or watermark. No cartoon/chibi/plastic look. No copied game characters. '
            'Output only this single original production sprite.'
        )
    return assets


def initialize():
    if RECIPE.exists():
        raise ValueError('Existing generation packet must not be overwritten')
    PACKET.mkdir(parents=True, exist_ok=True)
    RECIPE.write_text(json.dumps(dict(schema_id='overworld_actor_generation_v1',
        generator='built_in_image_gen', assets=inventory()), indent=2) + '\n')


def register(asset, source, prompt_file=None):
    recipe = read(RECIPE)
    row = recipe['assets'][asset]
    if row.get('source_generated'):
        raise ValueError('Already registered; preserve the selected original')
    source = source.resolve(strict=True)
    if source.suffix.lower() != '.png':
        raise ValueError('A real generated PNG is required')
    with Image.open(source) as image:
        if image.mode != 'RGBA' or image.getchannel('A').getextrema() != (0, 255):
            raise ValueError('Generated original requires genuine transparent alpha')
        if not image.getchannel('A').getbbox():
            raise ValueError('Empty generated sprite')
    destination = PACKET / (asset + '.png')
    if destination.exists():
        raise ValueError('Refuse an unregistered source overwrite')
    shutil.copy2(source, destination)
    row.update(source_generated=resource(destination), source_sha256=digest(destination),
               generation_tool='built_in_image_gen', generated_file=source.name)
    if prompt_file:
        row['prompt'] = prompt_file.read_text().strip()
    RECIPE.write_text(json.dumps(recipe, indent=2) + '\n')
    return {'registered': asset, 'completed': sum('source_generated' in r for r in recipe['assets'].values()),
            'total': len(recipe['assets'])}


def derived(source):
    alpha = source.getchannel('A')
    bounds = alpha.getbbox()
    if not bounds:
        raise ValueError('Empty source alpha')
    trim = source.crop(bounds)
    fitted = trim.copy()
    fitted.thumbnail((SIDE - 24, SIDE - 24), Image.Resampling.LANCZOS)
    canvas = Image.new('RGBA', (SIDE, SIDE))
    canvas.paste(fitted, ((SIDE - fitted.width) // 2, SIDE - 12 - fitted.height))
    return trim, canvas, list(bounds)


def prepare():
    recipe = read(RECIPE)
    current = inventory()
    if set(current) != set(recipe['assets']):
        raise ValueError('Actor roster changed during generation')
    missing = [key for key, row in recipe['assets'].items() if 'source_generated' not in row]
    if missing:
        raise ValueError('Finish generation before integration: ' + str(len(missing)) + ' remaining')
    rows = {}
    for asset, row in recipe['assets'].items():
        if row['reference_sha256'] != current[asset]['reference_sha256']:
            raise ValueError('Identity reference changed: ' + asset)
        source = local(row['source_generated'])
        if digest(source) != row['source_sha256']:
            raise ValueError('Generated original changed: ' + asset)
        with Image.open(source) as original:
            trim, runtime, bounds = derived(original.convert('RGBA'))
        trimmed = ROOT / 'art/overworld/source/trimmed/actor_readability_20260918' / (asset + '.png')
        target = ROOT / 'art/overworld/runtime/actors_20260918' / (asset + '.png')
        for path, image in ((trimmed, trim), (target, runtime)):
            path.parent.mkdir(parents=True, exist_ok=True)
            image.save(path, optimize=True)
        rows[asset] = dict(kind=row['kind'], identity_id=row['identity_id'], original_path=row['original_path'],
            original_region=row['original_region'], path=resource(target), runtime_sha256=digest(target),
            source_generated=row['source_generated'], source_sha256=row['source_sha256'], source_bounds=bounds,
            source_trimmed=resource(trimmed), trimmed_sha256=digest(trimmed), runtime_canvas=[SIDE, SIDE],
            accessible_description=row['name'], generation_manifest=resource(RECIPE))
    MANIFEST.write_text(json.dumps(dict(schema_id='overworld_actor_sprites_v1',
        preparation_tool='tools/prepare_overworld_actor_art.py',
        policy='original generated actor art; crop and aspect-fit only; immutable gameplay identity', assets=rows), indent=2) + '\n')
    return {'prepared': len(rows), 'heroes': sum(r['kind'] == 'hero' for r in rows.values())}


def validate_assets():
    recipe, manifest, current = read(RECIPE), read(MANIFEST), inventory()
    assert manifest['schema_id'] == 'overworld_actor_sprites_v1'
    assert set(recipe['assets']) == set(manifest['assets']) == set(current)
    assert len({row['source_sha256'] for row in manifest['assets'].values()}) == len(current), 'Distinct actors share a generated original'
    for asset, entry in manifest['assets'].items():
        row = recipe['assets'][asset]
        assert entry['kind'] == current[asset]['kind'], asset
        assert entry['identity_id'] == current[asset]['identity_id'], asset
        assert entry['path'] == 'res://art/overworld/runtime/actors_20260918/' + asset + '.png', asset
        assert entry['source_generated'] == row['source_generated'], asset
        assert entry['generation_manifest'] == resource(RECIPE), asset
        assert entry['runtime_canvas'] == [SIDE, SIDE], asset
        assert entry['accessible_description'] == current[asset]['name'], asset
        assert row['reference_sha256'] == current[asset]['reference_sha256']
        assert row['generation_tool'] == 'built_in_image_gen' and row['prompt']
        for field, hash_field in [('path','runtime_sha256'), ('source_generated','source_sha256'), ('source_trimmed','trimmed_sha256')]:
            assert digest(local(entry[field])) == entry[hash_field], asset
        with Image.open(local(entry['source_generated'])) as original:
            trim, runtime, bounds = derived(original.convert('RGBA'))
        with Image.open(local(entry['path'])) as actual:
            assert actual.mode == 'RGBA' and actual.size == (SIDE, SIDE)
            assert actual.tobytes() == runtime.tobytes(), asset
        with Image.open(local(entry['source_trimmed'])) as actual_trim:
            assert actual_trim.mode == 'RGBA' and actual_trim.size == trim.size, asset
            assert actual_trim.tobytes() == trim.tobytes(), asset
        assert entry['source_sha256'] == row['source_sha256'], asset
        assert bounds == entry['source_bounds']
        assert entry['original_path'] == current[asset]['original_path']
        assert entry['original_region'] == current[asset]['original_region']
    return {'ok':True, 'original_actors':len(current), 'pixel_operations':['alpha_bbox_crop','aspect_fit']}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument('--init', action='store_true')
    action.add_argument('--register', metavar='ASSET')
    action.add_argument('--pending', action='store_true')
    action.add_argument('--prepare', action='store_true')
    action.add_argument('--validate', action='store_true')
    parser.add_argument('--source', type=Path)
    parser.add_argument('--prompt-file', type=Path)
    args = parser.parse_args()
    if args.init:
        initialize()
        result = {'planned':len(read(RECIPE)['assets'])}
    elif args.register:
        if not args.source:
            parser.error('--register requires --source')
        result = register(args.register, args.source, args.prompt_file)
    elif args.pending:
        result = [row for row in read(RECIPE)['assets'].values() if 'source_generated' not in row]
    else:
        result = prepare() if args.prepare else validate_assets()
    print(json.dumps(result))


if __name__ == '__main__':
    main()
