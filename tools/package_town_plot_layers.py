"""Cut a faction's town building layers from paintings made in its empty town scene.

Every building was painted into the faction's empty backdrop by a masked edit whose
mask is the building's plot box. For a small plot the edit was a close-up crop of the
backdrop, so the model painted the building at the plot's size; this step scales such
an edit back into the full scene. It cuts the building along its matte, which
tools/town_plot_mattes.py made with BiRefNet: the parts that touch the plot, holes such
as arches filled, with a short soft skirt of the painted ground at its foot. It writes:

- the runtime layer (at most 512 px) and, beside it, a hit mask of the building alone,
  so clicks and the hover outline follow the building rather than its ground,
- the 256 px catalog icon, from the building alone,
- the 1600x900 runtime backdrop of the empty scene,
- the town fully built (the last stage of each line, the first dwelling of each tier),
  drawn as the town screen draws it; the town's own picture in content/towns.json,
  which the town list, the town switcher and the build screen show,
- the scene-art rows, the plot sites in the layout, and the backdrop record.

The packet (tracked JSON next to the prompts) lists the plots, and for each building
its box, painting, matte, prompt and reference images. Paintings, mattes, references and
the backdrop master are untracked sources.

Needs numpy, scipy and Pillow.

usage: python tools/package_town_plot_layers.py art/towns/source/generated/overhaul/faction_brasshollow/slag_canyon.json
"""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

from prepare_town_overhaul_art import digest, read, uri

ROOT = Path(__file__).resolve().parents[1]
SCENE = ROOT / 'content/town_building_scene_art_manifest.json'
LAYOUT = ROOT / 'content/town_building_scene_layouts.json'
BACKDROPS = ROOT / 'content/town_development_scene_manifest.json'
DEVELOPMENT = ROOT / 'content/town_development.json'
LAYER_MAX = 512
ICON_SIZE, ICON_FIT = 256, 240
BACKDROP_SIZE = (1600, 900)
STAGE_TINT = ((5, 8, 10), 0.08)  # TownStageView draws this over the layers
IMPORT_TEMPLATE = '''[remap]

importer="texture"
type="CompressedTexture2D"
uid="{uid}"
path="res://.godot/imported/{name}-{hash}.ctex"
metadata={{
"vram_texture": false
}}

[deps]

source_file="{res}"
dest_files=["res://.godot/imported/{name}-{hash}.ctex"]

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate={mipmaps}
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
'''


def write_json(path, payload):
    path.write_bytes((json.dumps(payload, indent=2) + '\n').encode('utf-8'))


def write_backdrop_stage(path, faction, stage, record):
    """The backdrop manifest keeps each stage record on one line: replace that one."""
    text = path.read_bytes().decode('utf-8')
    start = text.index('{', text.index('"' + stage + '":', text.index('"' + faction + '":')))
    _, length = json.JSONDecoder().raw_decode(text[start:])
    path.write_bytes((text[:start] + json.dumps(record) + text[start + length:]).encode('utf-8'))


def write_import(path, mipmaps):
    """Godot's texture import sidecar, kept if it exists (its uid stays the same)."""
    sidecar = path.with_name(path.name + '.import')
    if sidecar.is_file():
        return
    res = uri(path)
    # A stable uid from the path, spelled as Godot spells it: base 34, letters
    # a-y then digits 0-8. Godot re-spells anything else ('z', '9') on import.
    value = int(hashlib.sha256(res.encode()).hexdigest()[:16], 16) & 0x7FFFFFFFFFFFFFFF
    text = ''
    while value:
        value, digit = divmod(value, 34)
        text = (chr(97 + digit) if digit < 25 else str(digit - 25)) + text
    sidecar.write_bytes(IMPORT_TEMPLATE.format(uid='uid://' + text, name=path.name, hash=hashlib.md5(res.encode()).hexdigest(),
                                               res=res, mipmaps=str(mipmaps).lower()).encode('utf-8'))


def change(a, b):
    return ndimage.gaussian_filter(np.abs(a - b).max(axis=2), 1.2)


def smoothstep(low, high, x):
    t = np.clip((x - low) / (high - low), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def skirt(solid, radius, rise):
    """A soft band of painted ground at the building's foot, fading out over radius pixels."""
    height = solid.shape[0]
    has = solid.any(axis=0)
    low = np.where(has, height - 1 - np.argmax(solid[::-1], axis=0), -1)
    foot = np.zeros_like(solid)
    for x in np.flatnonzero(has):
        foot[max(0, low[x] - rise):low[x] + 1, x] = True
    band = np.clip(1.0 - ndimage.distance_transform_edt(~foot) / radius, 0.0, 1.0)
    band = band * band * (3.0 - 2.0 * band)
    # Only at and below the foot: never a halo up the building's sides.
    top = ndimage.minimum_filter1d(np.where(has, low - rise, height), size=2 * radius + 1)
    return np.where(np.arange(height)[:, None] >= top[None, :], band, 0.0) * ~solid


def cut(master, edit, item, matte, settings):
    """The layer around one building, from its matte, in a window of the full scene.

    Returns the window origin, the layer colours (the tone-matched painting, edge colours
    un-mixed from the backdrop), the layer alpha (the building and a short skirt of its
    painted foundation), the building's own alpha and its solid mask.
    """
    height, width = master.shape[:2]
    x, y, w, h = item['box']
    wx, wy, ww, wh = item['matte']['window']
    if matte.shape != (wh, ww):
        raise ValueError('matte does not fit its window: ' + item['id'])
    a = np.zeros((height, width), np.float32)
    a[wy:wy + wh, wx:wx + ww] = matte
    reach = settings['plot_reach']
    near_plot = np.zeros((height, width), bool)
    near_plot[max(0, y - reach):y + h + reach, max(0, x - reach):x + w + reach] = True
    # The building: the matte's parts that touch its plot, holes (arches, lattices) filled.
    solid = a > 0.5
    labels, _ = ndimage.label(solid)
    touching = np.unique(labels[solid & near_plot])
    touching = touching[touching > 0]
    if not len(touching):
        raise ValueError('no building in the matte: ' + item['id'])
    sizes = ndimage.sum(solid, labels, touching)
    solid = ndimage.binary_fill_holes(np.isin(labels, touching[sizes >= 0.02 * sizes.max()]))
    building = smoothstep(settings['alpha_low'], settings['alpha_high'], a) * ndimage.binary_dilation(solid, iterations=3)
    building = np.maximum(building, ndimage.binary_erosion(solid, iterations=2).astype(np.float32))
    ys, xs = np.nonzero(building > 0.004)
    pad = settings['skirt_radius'] + 4
    cy0, cy1 = max(0, ys.min() - pad), min(height, ys.max() + pad + 1)
    cx0, cx1 = max(0, xs.min() - pad), min(width, xs.max() + pad + 1)
    m = master[cy0:cy1, cx0:cx1]
    e = edit[cy0:cy1, cx0:cx1].copy()
    solid, building = solid[cy0:cy1, cx0:cx1], building[cy0:cy1, cx0:cx1]
    # Match the painting's tone to the backdrop on the bare ground inside the box, as an
    # offset only: a gain would sharpen the building along with the ground.
    inside = np.zeros(solid.shape, bool)
    inside[max(0, y - cy0):max(0, y - cy0 + h), max(0, x - cx0):max(0, x - cx0 + w)] = True
    land = inside & ~ndimage.binary_dilation(change(e, m) > 30, iterations=20)
    if land.sum() < 3000:
        land = inside & ~ndimage.binary_dilation(change(e, m) > 50, iterations=6)
    if land.any():
        for c in range(3):
            e[..., c] = np.clip(e[..., c] + np.clip(m[..., c][land].mean() - e[..., c][land].mean(), -25.0, 25.0), 0, 255)
    alpha = np.maximum(building, settings['skirt_strength'] * skirt(solid, settings['skirt_radius'], settings['skirt_rise']))
    # Edge colours un-mixed from the backdrop, so the layer over the backdrop gives the
    # painting back instead of a fringe of the painting's own background.
    soft = (alpha > 0.02) & (alpha < 0.98)
    e[soft] = np.clip((e[soft] - (1.0 - alpha[soft, None]) * m[soft]) / alpha[soft, None], 0, 255)
    return (cx0, cy0), e, alpha, building, solid


def built_town(backdrop, plots, rows, roster):
    """The town fully built, as the town screen draws it: on each plot its last stage, of
    the first dwelling where a tier offers two, stacked by ground line, under the stage tint."""
    later = {entry[key] for entry in roster if entry['branch'] > 1 for key in ('building_id', 'upgrade_building_id')}
    picks = [ids[-1] for ids in ([bid for bid in plot['building_ids'] if bid in rows and bid not in later] for plot in plots) if ids]
    picks.sort(key=lambda bid: rows[bid]['ground_anchor'][1])
    town = backdrop.copy()
    width, height = town.size
    for bid in picks:
        x, y, w, h = rows[bid]['normalized_rect']
        x0, y0 = round(x * width), round(y * height)
        with Image.open(ROOT / rows[bid]['runtime_path'].removeprefix('res://')) as layer:
            layer = layer.convert('RGBA').resize((round((x + w) * width) - x0, round((y + h) * height) - y0), Image.Resampling.LANCZOS)
        town.paste(layer.convert('RGB'), (x0, y0), layer.getchannel('A'))
    colour, strength = STAGE_TINT
    return Image.blend(town, Image.new('RGB', town.size, colour), strength), picks


def full_edit(master, item):
    """The building's painting over the whole scene: a close-up edit is scaled back."""
    with Image.open(ROOT / item['source_path']) as painting:
        painting = painting.convert('RGB')
        crop = item.get('crop')
        if not crop:
            return np.asarray(painting.resize(master.size, Image.Resampling.LANCZOS)).astype(np.float32)
        x0, y0, w, h = crop
        scene = master.copy()
        scene.paste(painting.resize((w, h), Image.Resampling.LANCZOS), (x0, y0))
        return np.asarray(scene).astype(np.float32)


def main():
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    parser.add_argument('packet')
    args = parser.parse_args()
    packet_path = (ROOT / args.packet).resolve()
    packet = read(packet_path)
    faction = packet['faction_id']
    settings = packet['cut']
    backdrop = packet['backdrop']
    master_path = ROOT / backdrop['source_path']
    if digest(master_path) != backdrop['source_sha256']:
        raise ValueError('Changed backdrop master: ' + str(master_path))
    master_image = Image.open(master_path).convert('RGB')
    master = np.asarray(master_image).astype(np.float32)
    width, height = master_image.size
    scene, layout = read(SCENE), read(LAYOUT)
    generation = packet['generation']

    runtime = ROOT / f"art/towns/runtime/backdrops/overhaul/{faction}_{packet['scene_id']}.png"
    runtime.parent.mkdir(parents=True, exist_ok=True)
    backdrop_image = master_image.resize(BACKDROP_SIZE, Image.Resampling.LANCZOS)
    backdrop_image.save(runtime)
    write_import(runtime, mipmaps=False)

    rows = scene['factions'][faction]
    for item in packet['buildings']:
        bid = item['id']
        source = ROOT / item['source_path']
        if digest(source) != item['source_sha256']:
            raise ValueError('Changed painting: ' + str(source))
        matte_path = ROOT / item['matte']['path']
        if digest(matte_path) != item['matte']['sha256']:
            raise ValueError('Changed matte: ' + str(matte_path))
        with Image.open(matte_path) as matte_image:
            matte = np.asarray(matte_image.convert('L')).astype(np.float32) / 255.0
        (cx0, cy0), edit, alpha, building, solid = cut(master, full_edit(master_image, item), item, matte, settings)
        ys, xs = np.nonzero(alpha > 0.004)
        ly0, ly1, lx0, lx1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
        layer = Image.fromarray(np.dstack([edit, alpha * 255.0])[ly0:ly1, lx0:lx1].round().astype(np.uint8), 'RGBA')
        hit = Image.fromarray((building * 255.0)[ly0:ly1, lx0:lx1].round().astype(np.uint8), 'L')
        layer_path = ROOT / f'art/towns/runtime/scene_layers/overhaul/{faction}/{bid}.png'
        hit_path = layer_path.with_name(bid + '_hit.png')
        icon_path = ROOT / f'art/towns/runtime/buildings/overhaul/{faction}/{bid}.png'
        for path in (layer_path, icon_path):
            path.parent.mkdir(parents=True, exist_ok=True)
        rendered = layer.copy()
        rendered.thumbnail((LAYER_MAX, LAYER_MAX), Image.Resampling.LANCZOS)
        rendered.save(layer_path)
        write_import(layer_path, mipmaps=True)
        mask = hit.resize(rendered.size, Image.Resampling.LANCZOS)
        Image.merge('LA', (Image.new('L', mask.size, 255), mask)).save(hit_path)
        write_import(hit_path, mipmaps=False)
        # The icon shows the building alone.
        tys, txs = np.nonzero(solid)
        bounds = (txs.min(), tys.min(), txs.max() + 1, tys.max() + 1)
        cutout = Image.fromarray(np.dstack([edit, building * 255.0]).round().astype(np.uint8), 'RGBA').crop(bounds)
        cutout.thumbnail((ICON_FIT, ICON_FIT), Image.Resampling.LANCZOS)
        icon = Image.new('RGBA', (ICON_SIZE, ICON_SIZE))
        icon.paste(cutout, ((ICON_SIZE - cutout.width) // 2, (ICON_SIZE - cutout.height) // 2))
        icon.save(icon_path)
        write_import(icon_path, mipmaps=False)
        prompt = ROOT / item['prompt_path']
        rows[bid] = {
            'source_path': uri(source), 'source_sha256': digest(source), 'source_size': list(Image.open(source).size),
            'prompt_path': uri(prompt), 'prompt_sha256': digest(prompt),
            'generation_date': generation['date'], 'generation_tool': generation['tool'],
            'reference_inputs': ['res://' + path for path in item['reference_inputs']],
            'processing_tool': 'tools/package_town_plot_layers.py',
            'asset_id': faction + '_' + bid,
            'runtime_path': uri(layer_path), 'runtime_sha256': digest(layer_path), 'runtime_size': list(rendered.size),
            'hit_mask_path': uri(hit_path),
            'icon_path': uri(icon_path), 'icon_sha256': digest(icon_path),
            'normalized_rect': [round(float(v), 6) for v in ((cx0 + lx0) / width, (cy0 + ly0) / height, (lx1 - lx0) / width, (ly1 - ly0) / height)],
            'ground_anchor': [round(float(v), 6) for v in ((cx0 + (txs.min() + txs.max()) / 2) / width, (cy0 + tys.max()) / height)],
            'modulate': [1, 1, 1, 1], 'hit_alpha_threshold': 0.25,
            'grounding': packet['grounding'],
            'curation': packet['curation'],
        }
        print(f'{bid}: layer {rendered.size[0]}x{rendered.size[1]}')

    faction_layout = layout['factions'][faction]
    faction_layout['layers_under_stage_light'] = True
    for plot in faction_layout['plots']:
        x, y, w, h = packet['plots'][plot['plot_id']]
        plot['anchor'] = [round((x + w / 2) / width, 6), round((y + h) / height, 6)]
        plot['height_ratio'] = round(h / height, 6)
        plot['embedded_in_base'] = False

    built = runtime.with_name(runtime.stem + '_built.png')
    town, picks = built_town(backdrop_image, faction_layout['plots'], rows, read(DEVELOPMENT)['rosters'][faction])
    town.save(built)
    write_import(built, mipmaps=False)
    prompt = ROOT / backdrop['prompt_path']
    write_backdrop_stage(BACKDROPS, faction, packet['stage'], {
        'source_path': uri(master_path), 'source_sha256': digest(master_path), 'source_size': [width, height],
        'prompt_path': uri(prompt), 'prompt_sha256': digest(prompt),
        'generation_date': generation['date'], 'generation_tool': generation['tool'],
        'reference_inputs': ['res://' + path for path in backdrop['reference_inputs']],
        'processing_tool': 'tools/package_town_plot_layers.py',
        'runtime_path': uri(runtime), 'runtime_sha256': digest(runtime),
        'built_town_path': uri(built), 'built_town_sha256': digest(built), 'built_town_buildings': picks,
    })
    write_json(SCENE, scene)
    write_json(LAYOUT, layout)
    print(f"Packaged {len(packet['buildings'])} {faction} layers on the {packet['scene_id']} backdrop.")


if __name__ == '__main__':
    main()
