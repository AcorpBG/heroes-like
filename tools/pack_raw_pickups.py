"""Pack the approved transparent raw piles without repainting generated pixels."""
import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path('art/overworld/source/generated/pickups/raw_piles_20260920')
OUTPUT = Path('art/overworld/runtime/objects/pickups')
PICKUPS = {'gold': 'road_writ_purse', 'ore': 'quarry_chip_hod', 'wood': 'split_wood_pile'}


def main():
    manifest_path = ROOT / 'art/overworld/manifest.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    (ROOT / OUTPUT).mkdir(parents=True, exist_ok=True)
    for resource, identity in PICKUPS.items():
        source = SOURCE / f'{resource}-source.png'
        image = Image.open(ROOT / source).convert('RGBA')
        bounds = image.getchannel('A').point(lambda a: 255 if a > 8 else 0).getbbox()
        image = image.crop(bounds)
        image.thumbnail((400, 400), Image.Resampling.LANCZOS)
        canvas = Image.new('RGBA', (512, 512))
        canvas.paste(image, ((512-image.width)//2, (512-image.height)//2))
        output = OUTPUT / f'raw_{resource}_pile.png'
        canvas.save(ROOT / output, optimize=True)
        asset_id = 'mapobj_' + identity
        manifest['object_assets'][asset_id] = {
            'path': 'res://' + output.as_posix(),
            'source_generated': 'res://' + source.as_posix(),
            'source_model': 'built_in_image_gen_transparent',
            'asset_policy': 'original_generated_runtime_sprite_no_homm3_art_import',
            'distinct_sprite_assignment': True,
            'assigned_map_object_id': 'object_' + identity,
            'assigned_map_object_family': 'pickup',
            'source_processing_manifest': 'res://' + (SOURCE/'provenance.json').as_posix(),
            'runtime_sha256': hashlib.sha256((ROOT/output).read_bytes()).hexdigest(),
        }
        manifest['resource_site_sprites']['site_'+identity] = {
            'asset_id': asset_id,
            'fit': f'Approved raw {resource} pile, one-time resource pickup.',
        }
        print(f'{resource}: {output.as_posix()} ({image.width}x{image.height} painted crop)')
    manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False)+'\n', encoding='utf-8', newline='\n')


if __name__ == '__main__':
    main()
