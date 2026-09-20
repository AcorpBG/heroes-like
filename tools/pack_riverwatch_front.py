"""Pack the front-facing Riverwatch sprite and update its stable terrain aliases."""
import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = 'art/overworld/source/generated/towns/front_facing_20260920/riverwatch-source.png'
OUTPUT = 'art/overworld/runtime/objects/towns/front_facing/riverwatch.png'
IDS = ('town_identity_riverwatch', 'town_biome_riverwatch_land', 'town_biome_riverwatch_ash')


def main():
    image = Image.open(ROOT / SOURCE).convert('RGBA')
    bounds = image.getchannel('A').point(lambda a: 255 if a > 8 else 0).getbbox()
    if not bounds or image.getchannel('A').getextrema()[0] != 0:
        raise ValueError('Expected an isolated sprite with transparent background')
    image = image.crop(bounds)
    image.thumbnail((480, 480), Image.Resampling.LANCZOS)
    canvas = Image.new('RGBA', (512, 512))
    canvas.paste(image, ((512-image.width)//2, (512-image.height)//2))
    (ROOT / OUTPUT).parent.mkdir(parents=True, exist_ok=True)
    canvas.save(ROOT / OUTPUT, optimize=True)
    path = ROOT / 'art/overworld/manifest.json'
    manifest = json.loads(path.read_text(encoding='utf-8'))
    for asset_id in IDS:
        manifest['object_assets'][asset_id] = {
            'path': 'res://' + OUTPUT,
            'source_generated': 'res://' + SOURCE,
            'source_processing_manifest': 'res://art/overworld/source/generated/towns/front_facing_20260920/provenance.json',
            'source_model': 'built_in_image_gen_original_front_facing_town',
            'asset_policy': 'original_generated_runtime_sprite_no_homm3_art_import',
            'assigned_town_id': 'town_riverwatch',
            'runtime_sha256': hashlib.sha256((ROOT / OUTPUT).read_bytes()).hexdigest(),
            'accessible_description': 'Front-facing grey-stone Riverwatch fortress with a centered gate, red roofs, and a central fire beacon. Neutral stone foundations fit every biome. No painted flags or banners; ownership uses the two runtime entrance flags.',
        }
        if asset_id != IDS[0]:
            manifest['object_assets'][asset_id]['base_asset_id'] = IDS[0]
    path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False)+'\n', encoding='utf-8', newline='\n')
    print(f'Packed {OUTPUT}: {image.width}x{image.height} painted crop, {len(IDS)} stable appearance IDs.')


if __name__ == '__main__':
    main()
