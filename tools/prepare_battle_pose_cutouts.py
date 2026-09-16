#!/usr/bin/env python3
"""Owner-approved, deterministic inspected-matte extraction of original poses.

No pose generation, warping, rescaling, runtime registration or paid service.
Recipes pin immutable sources and inspected background/protected regions.
Only background and a narrow compositing-edge band may change. Original
interior paint and pixel coordinates remain intact. Prepared is not accepted.
"""
from __future__ import annotations

import argparse
from collections import deque
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SOURCE_ROOT = ROOT / 'art/animation/source'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def scoped(path):
    result = (ROOT / path).resolve()
    if not result.is_relative_to(SOURCE_ROOT.resolve()):
        raise ValueError('Expected original/derived animation source path')
    return result


def connected(mask, seeds):
    """Four-connected scanline fill, without crossing protected pale paint."""
    h, w = mask.shape
    remaining = mask.copy()
    out = np.zeros_like(mask)
    queue = deque(seeds)
    while queue:
        x, y = queue.popleft()
        if not (0 <= x < w and 0 <= y < h):
            raise ValueError('Background seed outside source region')
        if not remaining[y, x]:
            continue
        left, right = x, x + 1
        while left and remaining[y, left - 1]:
            left -= 1
        while right < w and remaining[y, right]:
            right += 1
        remaining[y, left:right] = False
        out[y, left:right] = True
        for ny in (y - 1, y + 1):
            if not 0 <= ny < h:
                continue
            strip = remaining[ny, left:right]
            starts = strip & ~np.r_[False, strip[:-1]]
            queue.extend((int(nx + left), ny) for nx in np.flatnonzero(starts))
    return out


def nearby_colors(rgb, known, radius):
    """Propagate nearest source colors into a bounded edge band, no new paint."""
    colors, reached = rgb.copy(), known.copy()
    for _ in range(radius):
        previous = reached.copy()
        for dy, dx in ((0, -1), (0, 1), (-1, 0), (1, 0)):
            neighbor = np.roll(previous, (dy, dx), (0, 1))
            if dy == 1: neighbor[0, :] = False
            if dy == -1: neighbor[-1, :] = False
            if dx == 1: neighbor[:, 0] = False
            if dx == -1: neighbor[:, -1] = False
            take = neighbor & ~reached
            shifted = np.roll(colors, (dy, dx), (0, 1))
            colors[take] = shifted[take]
            reached[take] = True
    return colors, reached


def extract(image, spec):
    if 'A' in image.getbands() and image.getchannel('A').getextrema()[0] < 255:
        raise ValueError('Source already has alpha: inspect a real composite and reuse it; do not rekey it')
    data = np.array(image.convert('RGBA'))
    original = data.copy()
    rgb = data[:, :, :3].astype(np.int16)
    h, w = rgb.shape[:2]
    mode = spec.get('mode', 'neutral')
    if mode == 'neutral':
        minimum, tolerance = spec['minimum'], spec['tolerance']
        maximum = spec.get('maximum', 255)
        if not (0 <= minimum <= maximum <= 255 and 0 <= tolerance <= 255):
            raise ValueError('Invalid bounded background key')
        eligible = ((rgb.min(2) >= minimum) & (rgb.max(2) <= maximum)
                    & (np.ptp(rgb, axis=2) <= tolerance))
    elif mode == 'color_distance':
        color, distance = spec.get('color'), spec.get('distance')
        if (not isinstance(color, list) or len(color) != 3
                or any(type(c) is not int or not 0 <= c <= 255 for c in color)
                or type(distance) not in (int, float) or not 0 <= distance <= 128):
            raise ValueError('Invalid bounded color-distance background key')
        # int32 avoids signed-int16 overflow at saturated opposite colors.
        difference = rgb.astype(np.int32) - np.array(color, dtype=np.int32)
        eligible = (difference * difference).sum(2) <= distance * distance
    else:
        raise ValueError('Unknown background key mode')
    # Some enclosed gaps inherit a slight colored cast from the painting.
    # Broaden the key only inside an explicitly inspected source-pixel region;
    # never broaden the whole image and risk pale armor or cloth elsewhere.
    region_seeds = []
    for region in spec.get('background_regions', []):
        points = region['polygon']
        if len(points) < 3 or any(len(p) != 2 or not (0 <= p[0] < w and 0 <= p[1] < h) for p in points):
            raise ValueError('Invalid inspected background region')
        low, spread = region['minimum'], region['tolerance']
        if not (0 <= low <= 255 and 0 <= spread <= 255):
            raise ValueError('Invalid regional background key')
        region_image = Image.new('L', (w, h))
        ImageDraw.Draw(region_image).polygon([tuple(p) for p in points], fill=255)
        region_mask = np.array(region_image) != 0
        sx, sy = region['seed']
        if not (0 <= sx < w and 0 <= sy < h and region_mask[sy, sx]):
            raise ValueError('Background seed outside inspected region')
        regional_key = region_mask & (rgb.min(2) >= low) & (np.ptp(rgb, axis=2) <= spread)
        if not regional_key[sy, sx]:
            raise ValueError('Regional seed does not match background key')
        eligible |= regional_key
        region_seeds.append((sx, sy))
    protected_image = Image.new('L', (w, h))
    painter = ImageDraw.Draw(protected_image)
    for polygon in spec.get('protected_polygons', []):
        painter.polygon([tuple(p) for p in polygon], fill=255)
    protected = np.array(protected_image) != 0
    eligible &= ~protected
    seeds = ([(x, 0) for x in range(w)] + [(x, h - 1) for x in range(w)]
             + [(0, y) for y in range(h)] + [(w - 1, y) for y in range(h)]
             + [tuple(p) for p in spec.get('background_seeds', [])]
             + region_seeds)
    if spec.get('all_neutral_is_background', False) and mode != 'neutral':
        raise ValueError('all_neutral_is_background requires neutral mode')
    # Explicit inspected opt-in, useful for backing seen through dozens of
    # cage/mirror apertures. Never infer it from a color or the source palette.
    if (spec.get('all_keyed_is_background', False)
            or spec.get('all_neutral_is_background', False)):
        background = eligible
    else:
        background = connected(eligible, seeds)
    if not .05 < background.mean() < .98:
        raise ValueError('Implausible matte coverage: inspect the source recipe')
    radius = spec.get('edge_radius', 2)
    if not 0 <= radius <= 4:
        raise ValueError('Only a narrow 0..4 source-pixel edge band is permitted')
    foreground = ~background
    if radius:
        solid = np.array(Image.fromarray(foreground).filter(ImageFilter.MinFilter(2 * radius + 1)))
        band = foreground & ~solid & ~protected
        fg, fg_known = nearby_colors(rgb, solid, radius * 2 + 2)
        bg, bg_known = nearby_colors(rgb, background, radius * 2 + 2)
        # Do not estimate ambiguous nearly-identical pale foreground/backing.
        # Such regions need inspected protection/seeds, not aggressive erosion.
        delta = fg.astype(float) - bg
        denom = (delta * delta).sum(2)
        use = band & fg_known & bg_known & (denom >= 900)
        alpha = np.ones((h, w), dtype=float)
        alpha[use] = np.clip((((rgb - bg) * delta).sum(2)[use]) / denom[use], 0, 1)
        residual = np.linalg.norm(rgb - (bg + alpha[:, :, None] * delta), axis=2)
        use &= residual <= spec.get('max_edge_residual', 40)
        # Only genuinely mixed edges are decontaminated. Fully opaque paint,
        # including neutral armor/cloth, remains byte-for-byte original.
        use &= alpha < .97
        data[use, :3] = fg[use].clip(0, 255).astype(np.uint8)
        data[use, 3] = np.minimum(original[use, 3], np.rint(alpha[use] * 255)).astype(np.uint8)
    else:
        use = np.zeros((h, w), dtype=bool)
    data[background] = 0
    data[data[:, :, 3] == 0] = 0
    untouched = ~background & ~use
    if not np.array_equal(data[untouched], original[untouched]):
        raise ValueError('Unapproved interior-paint change')
    return Image.fromarray(data), {
        'removed_background_pixels': int(background.sum()),
        'edge_pixels': int(use.sum()),
        'unchanged_paint_pixels': int(untouched.sum()),
        'protected_pixels': int(protected.sum()),
        'alpha_extrema': list(Image.fromarray(data[:, :, 3]).getextrema()),
    }


def review_composites(image, directory, name):
    """Use actual alpha blending; raw RGB previews can expose invisible noise."""
    directory.mkdir(parents=True, exist_ok=True)
    for color, label in (('#354b38', 'green'), ('#eee7df', 'light')):
        canvas = Image.new('RGBA', image.size, color)
        canvas.alpha_composite(image.convert('RGBA'))
        canvas.thumbnail((1600, 1400), Image.Resampling.LANCZOS)
        canvas.convert('RGB').save(directory / (name + '-' + label + '.png'))


def prepare(recipe_path, selected=(), review_dir=None):
    recipe = json.loads(recipe_path.read_text())
    if recipe.get('schema_id') != 'original_battle_cutout_recipe_v1':
        raise ValueError('Unknown cutout recipe')
    jobs = recipe['jobs']
    if selected and set(selected) - {j['id'] for j in jobs}:
        raise ValueError('Unknown selected cutout job')
    outputs = []
    for job in jobs:
        if selected and job['id'] not in selected:
            continue
        source, output = scoped(job['source']), scoped(job['output'])
        if source == output or digest(source) != job['source_sha256']:
            raise ValueError('Source mismatch or attempted source overwrite')
        proof_path = output.with_suffix('.processing.json')
        if output.exists():
            if not proof_path.exists() or json.loads(proof_path.read_text()).get('output_sha256') != digest(output):
                raise ValueError('Refusing to overwrite unrecognized derived artwork')
        with Image.open(source) as original:
            region = job.get('source_rect', [0, 0, original.width, original.height])
            l, t, r, b = region
            if not (0 <= l < r <= original.width and 0 <= t < b <= original.height):
                raise ValueError('Invalid source region')
            cropped = original.crop(region)
            result, stats = extract(cropped, job['matte'])
        output.parent.mkdir(parents=True, exist_ok=True)
        result.save(output, optimize=True)
        proof = dict(schema_id='original_battle_cutout_processing_v1',
            owner_approval=recipe['owner_approval'], id=job['id'],
            source=job['source'], source_sha256=job['source_sha256'], source_rect=region,
            output=job['output'], output_sha256=digest(output),
            tool=str(Path(__file__).relative_to(ROOT)), tool_sha256=digest(Path(__file__)),
            recipe=str(recipe_path.resolve().relative_to(ROOT)), recipe_sha256=digest(recipe_path),
            parameters=job['matte'], measurements=stats,
            status='prepared_requires_visual_and_motion_review')
        proof_path.write_text(json.dumps(proof, indent=2) + '\n')
        if review_dir:
            review_composites(result, review_dir, job['id'])
        outputs.append(dict(id=job['id'], output=job['output'], **stats))
    return outputs


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('recipe', type=Path, nargs='?')
    parser.add_argument('--job', action='append', default=[])
    parser.add_argument('--review-dir', type=Path)
    parser.add_argument('--inspect-source', type=Path, help='Composite an existing source; no extraction or source edit')
    parser.add_argument('--inspect-rect', type=int, nargs=4, metavar=('LEFT', 'TOP', 'RIGHT', 'BOTTOM'),
                        help='Inspect a source-pixel crop without editing the source; requires --inspect-source')
    args = parser.parse_args()
    if args.inspect_source:
        if args.recipe or args.job or not args.review_dir:
            parser.error('--inspect-source requires --review-dir and no recipe/jobs')
        source = scoped(args.inspect_source)
        with Image.open(source) as original:
            name = source.parent.parent.name + '-' + source.stem
            if args.inspect_rect:
                left, top, right, bottom = args.inspect_rect
                if not (0 <= left < right <= original.width and 0 <= top < bottom <= original.height):
                    parser.error('Inspection rectangle outside source')
                original = original.crop((left, top, right, bottom))
                name += '-rect-' + '-'.join(map(str, args.inspect_rect))
                # Magnify only the disposable inspection composite, never the
                # source/derived artwork or its recorded pixel coordinates.
                original = original.resize((original.width * 4, original.height * 4), Image.Resampling.NEAREST)
            review_composites(original, args.review_dir, name)
        print(f'Original source composited without modification: {source}')
        return
    if not args.recipe:
        parser.error('Provide a recipe or --inspect-source')
    if args.inspect_rect:
        parser.error('--inspect-rect requires --inspect-source')
    print(json.dumps(prepare(args.recipe, args.job, args.review_dir), indent=2))


if __name__ == '__main__':
    main()
