#!/usr/bin/env python3
"""Connect original blocker recipes to semantic families; no art or map changes."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / 'art/overworld/native_scenery.json'
RECIPES = ROOT / 'art/overworld/source/generated/terrain/biome_blocker_library_20260913/recipes.json'


def library_palettes(manifest, recipes):
    seeds = manifest['landscape_palettes']
    # Components retain the family of their original art. A cluster follows
    # its largest painted layer, so a small shrub does not turn a ridge into woods.
    families = {}
    for family, biomes in seeds.items():
        for assets in biomes.values():
            for asset in assets:
                if not asset.startswith('cohesive_library_'):
                    families.setdefault(asset, set()).add(family)
    # These original harsh-atlas rock variants were absent from the small
    # semantic palettes, but are already used by the approved biome recipes.
    for index in (0, 1, 2, 3, 5, 7, 9, 10, 12, 14):
        families.setdefault(f'cohesive_harsh_{index:02}', set()).add('rock')
    result = {family: {biome: [] for biome in biomes} for family, biomes in seeds.items()}
    for recipe in recipes:
        layer = max(recipe['layers'], key=lambda item: item['rect'][2] * item['rect'][3])
        component = layer['component']
        matched = {'deadwood'} if component.startswith('deadwood_') else families.get(component, set())
        if not matched:
            raise ValueError(f"Unclassified dominant component: {recipe['id']} / {component}")
        for family in sorted(matched):
            result[family][recipe['biome']].append(recipe['id'])
    return result


def main():
    manifest = json.loads(MANIFEST.read_text(encoding='utf-8'))
    recipes = json.loads(RECIPES.read_text(encoding='utf-8'))['entries']
    manifest['library_palettes'] = library_palettes(manifest, recipes)
    manifest['library_palette_source'] = 'Largest-layer semantic classification of the 900 approved biome blocker recipes; tools/build_native_scenery_palettes.py'
    MANIFEST.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    print(f'Connected {len(recipes)} blocker appearances across nine biomes.')


if __name__ == '__main__':
    main()
