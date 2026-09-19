"""Pack the approved layered mine paintings; no painted pixels are synthesized.

Source sheets retain the building and detached machinery. This tool only crops,
resizes and registers those layers for runtime animation and a static fallback.
"""
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'art/overworld/source/generated/mines/stonework_20260920'
OUTPUT = ROOT / 'art/overworld/runtime/objects/mines'
SPECS = {
    'wood': {
        'chimney': [290, 131], 'lights': [[500, 805]],
        'parts': [
            {'crop': [1100, 0, 1536, 620], 'center': [356, 510], 'size': [145, 218], 'mode': 1, 'speed': 1.3},
            {'crop': [1100, 620, 1536, 1024], 'center': [648, 529], 'size': [105, 142], 'mode': 1, 'speed': -3.0},
        ],
    },
    'ore': {
        'chimney': [380, 100], 'lights': [[554, 580]],
        'parts': [
            {'crop': [1100, 0, 1536, 415], 'center': [962, 401], 'size': [107, 149], 'mode': 2, 'speed': .8, 'travel': [0, 70], 'rope': [948, 169]},
            {'crop': [1100, 415, 1536, 715], 'center': [458, 785], 'size': [230, 197], 'mode': 3, 'speed': .65, 'travel': [48, -45]},
            {'crop': [1100, 715, 1536, 1024], 'center': [787, 325], 'size': [116, 75], 'mode': 4, 'speed': 1.1},
        ],
    },
    'gold': {
        'chimney': [782, 89], 'lights': [[107, 631], [248, 760], [491, 774], [416, 714]],
        'parts': [
            {'crop': [1100, 0, 1536, 580], 'center': [499, 433], 'size': [106, 122], 'mode': 2, 'speed': .7, 'travel': [0, 53], 'rope': [501, 294]},
            {'crop': [1100, 580, 1536, 1024], 'center': [503, 282], 'size': [245, 135], 'mode': 4, 'speed': 1.0},
        ],
    },
}


def trimmed(image):
    box = image.getchannel('A').point(lambda a: 255 if a > 8 else 0).getbbox()
    if not box:
        raise ValueError('Empty painted layer')
    return image.crop(box), box


def pack_mines(specs, source, manifest_path, schema_id, asset_prefix):
    OUTPUT.mkdir(parents=True, exist_ok=True)
    manifest = {'schema_id': schema_id, 'canvas_size': [512, 640],
                'ground_anchor': [256, 604], 'painted_width': 448, 'mines': {}}
    for resource, spec in specs.items():
        sheet = Image.open(source / spec.get('file', f'{resource}-layers.png')).convert('RGBA')
        assert sheet.getchannel('A').getextrema()[0] == 0, 'Source must have real transparency'
        crop = spec.get('building_crop', [0, 0, 1100, 1024])
        building, bounds = trimmed(sheet.crop(crop))
        scale = min(448 / building.width, 470 / building.height)
        size = (round(building.width * scale), round(building.height * scale))
        offset = (round(256 - size[0] / 2), 604 - size[1])
        def point(p):
            return [round(offset[i] + (p[i] - crop[i] - bounds[i]) * scale, 3) for i in range(2)]
        base = Image.new('RGBA', (512, 640))
        base.alpha_composite(building.resize(size, Image.Resampling.LANCZOS), offset)
        base.save(OUTPUT / f'{resource}-base.png')
        atlas = Image.new('RGBA', (384, 128))
        fallback = base.copy()
        parts = []
        for index, part in enumerate(spec['parts']):
            layer, _ = trimmed(sheet.crop(part['crop']))
            # A small transparent gutter prevents neighboring atlas cells bleeding.
            packed = layer.copy()
            packed.thumbnail((124, 124), Image.Resampling.LANCZOS)
            atlas.alpha_composite(packed, (index * 128 + (128 - packed.width) // 2, (128 - packed.height) // 2))
            center = point(part['center'])
            target_size = [round(v * scale, 3) for v in part['size']]
            rect = [round(center[i] - target_size[i] / 2, 3) for i in range(2)] + target_size
            entry = {'rect': rect, 'source': [index * 128 + (128 - packed.width) // 2, (128 - packed.height) // 2, packed.width, packed.height],
                     'mode': part['mode'], 'speed': part['speed'],
                     'travel': [round(v * scale, 3) for v in part.get('travel', [0, 0])],
                     'rope': point(part['rope']) if 'rope' in part else [-1, -1]}
            parts.append(entry)
            fallback.alpha_composite(layer.resize(tuple(max(1, round(v)) for v in target_size), Image.Resampling.LANCZOS), tuple(round(v) for v in rect[:2]))
        atlas.save(OUTPUT / f'{resource}-parts.png')
        fallback.save(OUTPUT / f'{resource}.png')
        manifest['mines'][resource] = {
            'asset_id': f'{asset_prefix}_{resource}_mine',
            'base': f'res://art/overworld/runtime/objects/mines/{resource}-base.png',
            'parts_texture': f'res://art/overworld/runtime/objects/mines/{resource}-parts.png',
            'static': f'res://art/overworld/runtime/objects/mines/{resource}.png',
            'chimney': point(spec['chimney']), 'lights': [point(p) for p in spec['lights']], 'parts': parts,
        }
    manifest_path.write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print(f'Packed {len(specs)} mines and {sum(len(s["parts"]) for s in specs.values())} moving layers.')


def main():
    pack_mines(SPECS, SOURCE, ROOT / 'art/overworld/common_mines.json',
               'unified_common_mines_v1', 'mapobj_common')


if __name__ == '__main__':
    main()
