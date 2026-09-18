#!/usr/bin/env python3
"""Extract original mountain masses and register them for broad rock bodies."""
import argparse
import hashlib
import os
from pathlib import Path
import subprocess
import tempfile
from build_biome_components import BAKER, ROOT, read, write, resource

SOURCE = ROOT/'art/overworld/source/generated/terrain/mountain_masses_20260919'
RUNTIME = ROOT/'art/overworld/runtime/objects/decorations/mountain_masses_20260919'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    args = parser.parse_args()
    production = read(SOURCE/'production.json')
    RUNTIME.mkdir(parents=True, exist_ok=True)
    entries = []
    for sheet in production['sheets']:
        for row, palette in enumerate(sheet['rows']):
            for column, shape in enumerate(production['columns']):
                aid = f'native_mountain_{palette.removeprefix("biome_")}_{column:02d}'
                entries.append(dict(id=aid, name=palette.removeprefix('biome_').replace('_',' ').title()+' '+shape,
                    palette=palette, biome='biome_coast_archipelago' if palette=='sand' else palette,
                    kind='original_mountain_mass', atlas=str(SOURCE/sheet['file']), cell=row*5+column,
                    output=str(RUNTIME/(aid+'.png'))))
    # Same alpha-island extraction as the component pipeline, with 512px
    # canvases for art spanning several tiles. No pixel painting in Python.
    baker = BAKER.replace('224.0/', '480.0/').replace('256', '512').replace('240-cutout', '496-cutout')
    with tempfile.TemporaryDirectory(prefix='mountain-bake-') as temporary:
        work = Path(temporary)
        (work/'project.godot').write_text('config_version=5\n[application]\nconfig/name="MountainBaker"\n', encoding='utf-8')
        (work/'bake.gd').write_text(baker, encoding='utf-8')
        write(work/'job.json', dict(components=entries, clusters=[]))
        env = dict(os.environ, APPDATA=str(work/'profile'), XDG_DATA_HOME=str(work/'profile'))
        result = subprocess.run([args.godot,'--headless','--path',str(work),'--log-file',str(work/'engine.log'),
            '--script',str(work/'bake.gd'),'--',str(work/'job.json')], capture_output=True,text=True,env=env,timeout=240)
        print(result.stdout)
        if result.returncode or 'SCRIPT ERROR' in result.stderr or 'BIOME_COMPONENT_BAKE' not in result.stdout:
            raise RuntimeError(result.stderr)
    manifest_path = ROOT/'art/overworld/manifest.json'
    decorative_path = ROOT/'art/overworld/decorative_object_sprites.json'
    native_path = ROOT/'art/overworld/native_scenery.json'
    manifest, decorative, native = map(read,[manifest_path,decorative_path,native_path])
    palettes, hashes = {}, set()
    for entry in entries:
        path = Path(entry.pop('output'))
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        assert digest not in hashes, entry['id']
        hashes.add(digest)
        entry.update(sha256=digest, runtime_path=resource(path), atlas=resource(Path(entry['atlas'])))
        aid, biome = entry['id'], entry['biome']
        palettes.setdefault(entry['palette'],[]).append(aid)
        manifest['object_assets'][aid] = dict(path=resource(path), source_generated=entry['atlas'], source_model=entry['kind'],
            source_manifest=resource(SOURCE/'recipes.json'), asset_policy='original_generated_no_copied_pixels')
        decorative['generated_body_appearances'][aid] = dict(name=entry['name'], description=entry['name']+' is an original multi-tile mountain. Neighboring mountain artwork overlaps into connected ranges. Native blocked cells remain authoritative; no interaction or reward.',
            biome_ids=[biome], runtime_path=resource(path), source_path=resource(SOURCE/'recipes.json'),
            availability='Live broad rock-footprint mountain palette'+(' on sand only.' if entry['palette']=='sand' else '.'),
            placement_authority='Original native obstacle mask; overlapping artwork is presentation only.',
            production_kind=entry['kind'], contains_dead_tree=False)
        pool = decorative['generated_body_palette'][biome]
        if aid not in pool: pool.append(aid)
        settings = path.with_suffix('.png.import')
        if not settings.exists():
            settings.write_text('[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n[deps]\nsource_file="'+resource(path)+'"\n[params]\ncompress/mode=0\nmipmaps/generate=true\nprocess/fix_alpha_border=true\nprocess/size_limit=512\n',encoding='utf-8')
    native['terrain_mountain_palettes'] = {'sand':palettes.pop('sand')}
    native['mountain_palettes'] = palettes
    write(SOURCE/'recipes.json',dict(version=1,canvas=[512,512],production=resource(SOURCE/'production.json'),entries=entries))
    for path,data in [(manifest_path,manifest),(decorative_path,decorative),(native_path,native)]: write(path,data)
    print('Registered 50 original mountain masses across ten terrain palettes.')


if __name__=='__main__': main()
