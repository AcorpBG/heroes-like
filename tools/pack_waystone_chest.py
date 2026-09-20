"""Pack original chest art and register its measured animation regions."""
import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path('art/overworld/source/generated/pickups/waystone_chest_20260920')
OUTPUT = Path('art/overworld/runtime/objects/pickups/waystone_chest.png')


def main():
    source = SOURCE / 'chest-source.png'
    image = Image.open(ROOT / source).convert('RGBA')
    assert image.getchannel('A').getextrema()[0] == 0, 'Source must be transparent'
    bounds = image.getchannel('A').point(lambda a: 255 if a > 8 else 0).getbbox()
    image = image.crop(bounds)
    original_size = image.size
    image.thumbnail((400, 400), Image.Resampling.LANCZOS)
    offset = ((512-image.width)//2, (512-image.height)//2)
    canvas = Image.new('RGBA', (512, 512))
    canvas.paste(image, offset)
    canvas.save(ROOT / OUTPUT, optimize=True)

    def point(x, y):
        return [round((offset[i] + ([x, y][i]-bounds[i])*image.size[i]/original_size[i])/512, 6) for i in range(2)]

    def region(x, y, w, h):
        return point(x, y) + [round(w*image.width/original_size[0]/512, 6), round(h*image.height/original_size[1]/512, 6)]

    path = ROOT / 'art/overworld/manifest.json'
    manifest = json.loads(path.read_text(encoding='utf-8'))
    manifest['object_assets']['mapobj_waystone_cache'] = {
        'path': 'res://' + OUTPUT.as_posix(),
        'source_generated': 'res://' + source.as_posix(),
        'source_processing_manifest': 'res://' + (SOURCE/'provenance.json').as_posix(),
        'source_model': 'built_in_image_gen_transparent',
        'asset_policy': 'original_generated_runtime_sprite_no_homm3_art_import',
        'distinct_sprite_assignment': True,
        'assigned_map_object_id': 'object_waystone_cache',
        'assigned_map_object_family': 'pickup',
        'presentation_role': 'gold_and_scroll_treasure_chest',
        'accessible_description': 'An open oak-and-iron chest holds gold coins and rolled parchment scrolls.',
        'runtime_sha256': hashlib.sha256((ROOT/OUTPUT).read_bytes()).hexdigest(),
    }
    manifest['resource_site_sprites']['site_waystone_cache'] = {
        'asset_id': 'mapobj_waystone_cache',
        'fit': 'One-time chest offering a choice of gold or hero experience.',
    }
    path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False)+'\n', encoding='utf-8', newline='\n')
    path = ROOT / 'content/overworld_scenery_animation.json'
    animation = json.loads(path.read_text(encoding='utf-8'))
    animation['profiles']['treasure_chest'] = {
        'mode': 7, 'strength': 0.82, 'speed': 0.24,
        'shine_color': [1.0, 0.95, 0.69], 'sparkle_strength': 1.4,
        'glints': [point(495, 670), point(580, 618), point(754, 973)],
        'region': region(350, 554, 365, 220),
        'scroll_region': region(655, 449, 266, 285),
        'scroll_glow_strength': 0.52,
    }
    animation['assets']['mapobj_waystone_cache'] = 'treasure_chest'
    path.write_text(json.dumps(animation, indent=2, ensure_ascii=False)+'\n', encoding='utf-8', newline='\n')
    print(f'Packed {OUTPUT}: {image.width}x{image.height} painted extent; animation masks from source coordinates.')


if __name__ == '__main__':
    main()
