"""Isolate explicitly selected sprite bodies using original alpha pixels.

This only changes source rectangles in a handoff. It never paints, resizes or
changes a source image, pose, anchor or scale. Use only after visually identifying
foreign neighboring fragments; detached effects need separate ownership review.
"""
import argparse
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def body_rectangles(path, seed, cutoff):
    image = Image.open(path)
    width, height = image.size
    alpha = image.getchannel('A').point(lambda value: 255 if value > cutoff else 0)
    pixels = bytearray(alpha.tobytes())
    x, y = seed
    if not (0 <= x < width and 0 <= y < height and pixels[y * width + x]):
        raise ValueError(f'Seed must identify an opaque point inside the reviewed body: {seed}')
    pending = [y * width + x]
    pixels[pending[0]] = 0
    spans = {}
    while pending:
        index = pending.pop()
        x, y = index % width, index // width
        left, right = spans.get(y, (x, x))
        spans[y] = (min(left, x), max(right, x))
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < width and 0 <= ny < height:
                neighbor = ny * width + nx
                if pixels[neighbor]:
                    pixels[neighbor] = 0
                    pending.append(neighbor)
    rectangles = []
    for y, (left, right) in sorted(spans.items()):
        if rectangles and rectangles[-1][0] == left and rectangles[-1][2] == right + 1 and rectangles[-1][3] == y:
            rectangles[-1][3] = y + 1
        else:
            rectangles.append([left, y, right + 1, y + 1])
    return rectangles


def refine_frame(unit, clip, number, seed):
    frame = unit['frames'][unit['clips'][clip]['indices'][number]]
    cutoff = max(8, frame.get('alpha_noise_cutoff', unit.get('alpha_noise_cutoff', 0)))
    frame['rects'] = body_rectangles(ROOT / frame['source'].removeprefix('res://'), seed, cutoff)
    frame['alpha_noise_cutoff'] = cutoff
    frame['crop_recipe'] = {'tool': 'tools/refine_fluid_frame_crops.py', 'seed': seed, 'cutoff': cutoff}


def apply_recipe(handoff, recipe):
    """Replay individually reviewed crop/anchor corrections after source extraction."""
    packet = json.loads(Path(handoff).read_text(encoding='utf-8'))
    selections = json.loads(Path(recipe).read_text(encoding='utf-8'))
    if len(packet['units']) != 1 or packet['units'][0]['unit_id'] != selections['unit_id']:
        raise ValueError('Crop recipe must identify exactly this unit')
    unit = packet['units'][0]
    for selection in selections['frames']:
        clip, number = selection['clip'], selection['frame']
        refine_frame(unit, clip, number, selection['seed'])
        frame = unit['frames'][unit['clips'][clip]['indices'][number]]
        # Some reviewed poses own detached effects; keep their explicit regions.
        frame['rects'].extend(selection.get('additional_rects', []))
        if 'anchor' in selection:
            frame['anchor'] = selection['anchor']
        frame['crop_recipe']['reason'] = selection['reason']
    Path(handoff).write_text(json.dumps(packet, indent=2) + '\n', encoding='utf-8')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('handoff', type=Path)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--frame', action='append', help='clip:zero_based_frame:source_seed_x:source_seed_y')
    mode.add_argument('--recipe', type=Path, help='Replay a reviewed per-unit crop_refinements.json')
    args = parser.parse_args()
    if args.recipe:
        apply_recipe(args.handoff, args.recipe)
        return
    packet = json.loads(args.handoff.read_text(encoding='utf-8'))
    if len(packet['units']) != 1:
        raise ValueError('Select one unit handoff')
    unit = packet['units'][0]
    for selection in args.frame:
        clip, number, sx, sy = selection.split(':')
        refine_frame(unit, clip, int(number), [int(sx), int(sy)])
        print(unit['unit_id'], clip, number, 'original-pixel body isolated')
    args.handoff.write_text(json.dumps(packet, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
