#!/usr/bin/env python3
"""Bake the original pale sandstone atlas and register sand-only scenery."""
import argparse
import hashlib
import os
from pathlib import Path
import subprocess
import tempfile

from build_biome_components import BAKER, ROOT, read, write, resource

SOURCE = ROOT/'art/overworld/source/generated/terrain/sandstone_20260919'
RUNTIME = ROOT/'art/overworld/runtime/objects/decorations/sandstone_20260919'
BIOME = 'biome_coast_archipelago'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    args = parser.parse_args()
    production = read(SOURCE/'production.json')
    RUNTIME.mkdir(parents=True, exist_ok=True)
    components = []
    clusters = []
    for cell, name in enumerate(production['names']):
        aid = f'biome_component_v2_sandstone_rock_{cell:02d}'
        components.append(dict(id=aid, name=name.capitalize(), biome=BIOME, terrain_ids=['sand'], family='rock',
            kind='original_atlas_component', atlas=str(SOURCE/'rock.png'), cell=cell, output=str(RUNTIME/(aid+'.png'))))
    assert len(components) == 25
    for cell, component in enumerate(components):
        aid = f'biome_cluster_v2_sandstone_rock_{cell:02d}'
        clusters.append(dict(id=aid, name=component['name']+' outcrop', biome=BIOME, terrain_ids=['sand'], family='rock',
            kind='assembled_original_components', output=str(RUNTIME/(aid+'.png')),
            layers=[dict(component=component['id'], rect=[0,50,190,190]),
                    dict(component=components[(cell+7)%25]['id'], rect=[95,94,152,152])]))
    with tempfile.TemporaryDirectory(prefix='sandstone-bake-') as temporary:
        work = Path(temporary)
        (work/'project.godot').write_text('config_version=5\n[application]\nconfig/name="SandstoneBaker"\n', encoding='utf-8')
        (work/'bake.gd').write_text(BAKER, encoding='utf-8')
        write(work/'job.json', dict(components=components, clusters=clusters))
        env = dict(os.environ, APPDATA=str(work/'profile'), XDG_DATA_HOME=str(work/'profile'))
        result = subprocess.run([args.godot, '--headless', '--path', str(work), '--log-file', str(work/'engine.log'),
            '--script', str(work/'bake.gd'), '--', str(work/'job.json')], capture_output=True, text=True, env=env, timeout=240)
        print(result.stdout)
        if result.returncode or 'SCRIPT ERROR' in result.stderr or 'BIOME_COMPONENT_BAKE' not in result.stdout:
            raise RuntimeError(result.stderr)
    manifest_path = ROOT/'art/overworld/manifest.json'
    decorative_path = ROOT/'art/overworld/decorative_object_sprites.json'
    native_path = ROOT/'art/overworld/native_scenery.json'
    manifest, decorative, native = map(read, [manifest_path, decorative_path, native_path])
    hashes = set()
    for entry in components+clusters:
        path = Path(entry.pop('output'))
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        assert digest not in hashes, entry['id']
        hashes.add(digest)
        entry.update(sha256=digest, runtime_path=resource(path))
        if 'atlas' in entry: entry['atlas'] = resource(Path(entry['atlas']))
        aid = entry['id']
        manifest['object_assets'][aid] = dict(path=resource(path), source_generated=entry.get('atlas', resource(SOURCE/'recipes.json')),
            source_model=entry['kind'], source_manifest=resource(SOURCE/'recipes.json'), asset_policy='original_generated_no_copied_pixels')
        decorative['generated_body_appearances'][aid] = dict(name=entry['name'], description=entry['name']+' is impassable pale sandstone scenery. It has no interaction or reward; native body masks determine blocked cells.',
            biome_ids=[BIOME], terrain_ids=['sand'], runtime_path=resource(path), source_path=resource(SOURCE/'recipes.json'),
            availability='Live sand-only RMG rock palette.', placement_authority='Native generated obstacle body masks; art does not change footprint.',
            production_kind=entry['kind'], contains_dead_tree=False)
        pool = decorative['generated_body_palette'][BIOME]
        if aid not in pool: pool.append(aid)
        settings = path.with_suffix('.png.import')
        if not settings.exists():
            settings.write_text('[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n[deps]\nsource_file="'+resource(path)+'"\n[params]\ncompress/mode=0\nmipmaps/generate=true\nprocess/fix_alpha_border=true\nprocess/size_limit=256\n', encoding='utf-8')
    native.setdefault('terrain_component_palettes', {}).setdefault('sand', {})['rock'] = [r['id'] for r in components+clusters]
    native.setdefault('terrain_rock_contact_palettes', {})['sand'] = [components[i]['id'] for i in [8,13,18,21]]
    write(SOURCE/'recipes.json', dict(version=2, canvas=[256,256], production=resource(SOURCE/'production.json'), components=components, clusters=clusters))
    for path, data in [(manifest_path,manifest), (decorative_path,decorative), (native_path,native)]: write(path,data)
    print('Registered 25 original sand components and 25 distinct compositions.')


if __name__ == '__main__': main()
