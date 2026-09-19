#!/usr/bin/env python3
"""Bake original woodland/wetland masses and register habitat-aware palettes."""
import argparse
import hashlib
import os
from pathlib import Path
import subprocess
import tempfile
from build_biome_components import BAKER, ROOT, read, write, resource

SOURCE = ROOT/'art/overworld/source/generated/terrain/vegetation_masses_20260919'
RUNTIME = ROOT/'art/overworld/runtime/objects/decorations/vegetation_masses_20260919'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    args = parser.parse_args()
    production = read(SOURCE/'production.json')
    RUNTIME.mkdir(parents=True, exist_ok=True)
    entries = []
    for sheet in production['sheets']:
        for row, profile in enumerate(sheet['rows']):
            for column, shape in enumerate(production['columns']):
                aid = f'native_vegetation_{profile["family"]}_{profile["id"]}_{column:02d}'
                entries.append(dict(id=aid, name=profile['id'].replace('_',' ').title()+' '+shape,
                    profile=profile['id'], biome=profile['biome'], family=profile['family'], overhang=profile['overhang'],
                    kind='original_vegetation_mass', atlas=str(SOURCE/sheet['file']), cell=row*5+column, output=str(RUNTIME/(aid+'.png'))))
    baker = BAKER.replace('224.0/', '480.0/').replace('256', '512').replace('240-cutout', '496-cutout')
    with tempfile.TemporaryDirectory(prefix='vegetation-bake-') as temporary:
        work = Path(temporary)
        (work/'project.godot').write_text('config_version=5\n[application]\nconfig/name="VegetationBaker"\n', encoding='utf-8')
        (work/'bake.gd').write_text(baker, encoding='utf-8')
        write(work/'job.json', dict(components=entries, clusters=[]))
        env = dict(os.environ, APPDATA=str(work/'profile'), XDG_DATA_HOME=str(work/'profile'))
        result = subprocess.run([args.godot,'--headless','--path',str(work),'--log-file',str(work/'engine.log'),
            '--script',str(work/'bake.gd'),'--',str(work/'job.json')], capture_output=True,text=True,env=env,timeout=240)
        print(result.stdout)
        if result.returncode or 'SCRIPT ERROR' in result.stderr or 'BIOME_COMPONENT_BAKE' not in result.stdout: raise RuntimeError(result.stderr)
    manifest_path = ROOT/'art/overworld/manifest.json'
    decorative_path = ROOT/'art/overworld/decorative_object_sprites.json'
    native_path = ROOT/'art/overworld/native_scenery.json'
    manifest, decorative, native = map(read,[manifest_path,decorative_path,native_path])
    groups, hashes = {}, set()
    for entry in entries:
        path = Path(entry.pop('output'))
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        assert digest not in hashes, entry['id']
        hashes.add(digest)
        entry.update(sha256=digest, runtime_path=resource(path), atlas=resource(Path(entry['atlas'])))
        aid, biome = entry['id'], entry['biome']
        groups.setdefault(entry['profile'],[]).append(aid)
        manifest['object_assets'][aid] = dict(path=resource(path),source_generated=entry['atlas'],source_model=entry['kind'],
            source_manifest=resource(SOURCE/'recipes.json'),asset_policy='original_generated_no_copied_pixels')
        decorative['generated_body_appearances'][aid] = dict(name=entry['name'],description=entry['name']+' is an original multi-tile vegetation formation. Canopies and roots overlap nearby formations; native blocked cells remain authoritative. No interaction or reward.',
            biome_ids=[biome],runtime_path=resource(path),source_path=resource(SOURCE/'recipes.json'),
            availability='Live large vegetation palette; habitat routing is defined in native_scenery.json.',
            placement_authority='Native obstacle masks; visual overlap only.',production_kind=entry['kind'],contains_dead_tree=entry['family']=='deadwood')
        pool = decorative['generated_body_palette'][biome]
        if aid not in pool: pool.append(aid)
        settings = path.with_suffix('.png.import')
        if not settings.exists(): settings.write_text('[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n[deps]\nsource_file="'+resource(path)+'"\n[params]\ncompress/mode=0\nmipmaps/generate=true\nprocess/fix_alpha_border=true\nprocess/size_limit=512\n',encoding='utf-8')
    def pool(*names): return [aid for name in names for aid in groups[name]]
    woods = {'grasslands':'plains_grove','deep_forest':'deep_woods','mire_fen':'swamp_willow','highland_ridge':'highland_pines',
        'snow_frost_marches':'snow_pines','coast_archipelago':'coastal_woods','rough_badlands':'dry_thorns','ash_lava_wastes':'burned_grove','subterranean_underways':'fungal_colony'}
    palettes = {'woods':{'biome_'+b:pool(p) for b,p in woods.items()},'conifers':{},'deadwood':{},'wetland':{},'fungi':{},'scrub':{}}
    for b in woods:
        palettes['deadwood']['biome_'+b] = pool({'mire_fen':'drowned_grove','rough_badlands':'dry_thorns','ash_lava_wastes':'burned_grove'}.get(b,'temperate_deadwood'))
    for b in ['grasslands','deep_forest','highland_ridge']:
        palettes['conifers']['biome_'+b] = pool('highland_pines')
    palettes['conifers']['biome_snow_frost_marches'] = pool('snow_pines')
    for b in ['grasslands','deep_forest','mire_fen']:
        palettes['wetland']['biome_'+b] = pool('swamp_willow','mangrove_roots','reed_beds') if b=='mire_fen' else pool('swamp_willow','reed_beds')
        palettes['fungi']['biome_'+b] = pool('fungal_colony')
    palettes['wetland']['biome_coast_archipelago'] = pool('coastal_marsh','reed_beds')
    palettes['wetland']['biome_highland_ridge'] = pool('reed_beds')
    palettes['fungi']['biome_subterranean_underways'] = pool('fungal_colony')
    palettes['scrub']['biome_rough_badlands'] = pool('dry_thorns')
    native['vegetation_palettes'] = palettes
    native['terrain_vegetation_palettes'] = {'sand':{f:pool('sand_thicket') for f in ['woods','wetland','scrub']}}
    native['vegetation_mass_profiles'] = {e['id']:{'family':e['family'],'overhang':e['overhang'],'side_overlap':0.4} for e in entries}
    write(SOURCE/'recipes.json',dict(version=1,canvas=[512,512],production=resource(SOURCE/'production.json'),entries=entries))
    for path,data in [(manifest_path,manifest),(decorative_path,decorative),(native_path,native)]: write(path,data)
    print('Registered 75 original woodland, wetland, deadwood and fungal masses.')


if __name__=='__main__': main()
