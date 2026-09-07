#!/usr/bin/env python3
"""Package approved scene-matched raster masters, never synthesize building art."""
import hashlib
import json
from pathlib import Path
import subprocess

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
FACTION = 'faction_veilmourn'
BRIEFS = {
    'building_veilmourn_bell_harbor': {
        'source_sha256':'8da88597e30bd95d3ae5d172e100ffd34c85c644cb002a1bded726a38cc0e97d',
        'scene_bounds':[690,390,320,300], 'ground_anchor':[850,650],
        'grounding':'Left gangway joins the existing main quay; wet pilings descend into the central harbor. Preserve the open navigation water.',
    },
    'building_wayfarers_hall': {
        'source_sha256':'a42efba0e557456853265365df4000c223df86c6b22085e4eab30d6c1394d5f5',
        'scene_bounds':[945,330,390,260], 'ground_anchor':[1140,552],
        'grounding':'Lodge occupies the middle-distance right shore, behind the foreground gate and quay. Its covered stair opens toward the bell docks.',
    },
}

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    layers = {}
    for building_id, brief in BRIEFS.items():
        source = ROOT / f'art/towns/source/generated/scene_layers/{FACTION}/{building_id}.png'
        trimmed = ROOT / f'art/towns/source/trimmed/scene_layers/{FACTION}/{building_id}.png'
        runtime = ROOT / f'art/towns/runtime/scene_layers/{FACTION}/{building_id}.png'
        assert digest(source) == brief['source_sha256'], f'Unapproved master: {source}'
        with Image.open(source) as image:
            assert image.mode == 'RGBA'
            source_size = image.size
            bounds = image.getchannel('A').getbbox()
            assert bounds is not None
        trimmed.parent.mkdir(parents=True, exist_ok=True)
        runtime.parent.mkdir(parents=True, exist_ok=True)
        x0,y0,x1,y1 = bounds
        subprocess.run(['convert',str(source),'-crop',f'{x1-x0}x{y1-y0}+{x0}+{y0}','+repage','-strip',str(trimmed)],check=True)
        subprocess.run(['convert',str(trimmed),'-filter','Lanczos','-resize','512x512','-strip','-define','png:color-type=6',str(runtime)],check=True)
        with Image.open(runtime) as image:
            runtime_size = list(image.size)
        x,y,w,h = brief['scene_bounds']
        sw,sh = source_size
        # Exact visible alpha crop in the original scenic coordinate system.
        rect = [(x+w*x0/sw)/1600, (y+h*y0/sh)/900, w*(x1-x0)/sw/1600, h*(y1-y0)/sh/900]
        layers[building_id] = {
            'asset_id':f'{FACTION}_{building_id}',
            'source_path':'res://'+str(source.relative_to(ROOT)), 'source_sha256':digest(source),
            'source_size':list(source_size), 'trim_box':list(bounds),
            'trimmed_path':'res://'+str(trimmed.relative_to(ROOT)), 'trimmed_sha256':digest(trimmed),
            'runtime_path':'res://'+str(runtime.relative_to(ROOT)), 'runtime_sha256':digest(runtime),
            'runtime_size':runtime_size, 'normalized_rect':rect,
            'ground_anchor':[brief['ground_anchor'][0]/1600,brief['ground_anchor'][1]/900],
            'modulate':[1,1,1,1], 'hit_alpha_threshold':0.25,
            'grounding':brief['grounding'],
            'prompt_path':f'res://art/towns/source/generated/scene_layers/{FACTION}/{building_id}.prompt.txt',
            'curation':'Inspected actual Large08 Bellwake Town composition at 1280x720 and 2048x1079; runtime/input/package validation required separately.',
        }
    payload = {
        'schema_id':'town_building_scene_art_v1', 'source_size':[1600,900],
        'source_docs':['docs/generated-full-match-quality-requirements.md','docs/town-integrated-building-progression-requirements.md','docs/generated-full-match-art-repair-report.md'],
        'owner_approval':'2026-09-07: owner approved scene-matched Town layers and resuming full-match quality.',
        'generation':{'tool':'built_in_image_gen','model':'not_exposed','date':'2026-09-07','references':'Original Veilmourn village panorama and exact original catalog icons; no copyrighted game references.'},
        'processing_tool':'tools/prepare_town_scene_layers.py',
        'processing':'Crop only fully transparent outer margins, preserve generated alpha and aspect, Lanczos downsample to maximum 512px, strip derivative metadata for reproducible bytes; no drawn geometry, recoloring, background replacement or generated panorama substitution.',
        'rights':'Original project-generated art. No copied game pixels, names, protected symbols or third-party source assets.',
        'catalog_icons':'Unchanged; these exact-faction scene layers are not shared catalog replacements.',
        'migration_scope':'Two Bellwake starting structures only; remaining catalog-based scene art is explicitly not accepted by this migration.',
        'missing_declared_layer_policy':'validation_failure_no_catalog_or_procedural_fallback',
        'factions':{FACTION:layers},
    }
    (ROOT/'content/town_building_scene_art_manifest.json').write_text(json.dumps(payload,indent=2)+'\n')
    print(json.dumps({k:{'runtime_size':v['runtime_size'],'normalized_rect':v['normalized_rect'],'runtime_sha256':v['runtime_sha256']} for k,v in layers.items()},indent=2))

if __name__ == '__main__':
    main()
