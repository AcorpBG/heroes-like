"""Cut a faction's town building layers from paintings made in its empty town scene.

Every building was painted into the faction's empty backdrop by a masked edit whose
mask is the building's plot box. For a small plot the edit was a close-up crop of the
backdrop, so the model painted the building at the plot's size; this step scales such
an edit back into the full scene. It then cuts the building out together with the
painted ground at its foundation and writes:

- the runtime layer (at most 512 px) and, beside it, a hit mask of the building alone,
  so clicks and the hover outline follow the building rather than its ground,
- the 256 px catalog icon, from the building alone,
- the 1600x900 runtime backdrop of the empty scene,
- the scene-art rows, the plot sites in the layout, and the backdrop record.

The packet (tracked JSON next to the prompts) lists the plots, and for each building
its box, painting, prompt and reference images. Paintings, references and the backdrop
master are untracked sources.

Needs numpy, scipy, Pillow and opencv-python (GrabCut).

usage: python tools/package_town_plot_layers.py art/towns/source/generated/overhaul/faction_brasshollow/slag_canyon.json
"""
import argparse
import hashlib
import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image
from scipy import ndimage

from prepare_town_overhaul_art import digest, read, uri

ROOT = Path(__file__).resolve().parents[1]
SCENE = ROOT / 'content/town_building_scene_art_manifest.json'
LAYOUT = ROOT / 'content/town_building_scene_layouts.json'
BACKDROPS = ROOT / 'content/town_development_scene_manifest.json'
LAYER_MAX = 512
ICON_SIZE, ICON_FIT = 256, 240
BACKDROP_SIZE = (1600, 900)
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
    # A stable uid from the path, in Godot's text form (base 36, a-z then 0-9).
    value = int(hashlib.sha256(res.encode()).hexdigest()[:16], 16) & 0x7FFFFFFFFFFFFFFF
    text = ''
    while value:
        value, digit = divmod(value, 36)
        text = (chr(97 + digit) if digit < 26 else str(digit - 26)) + text
    sidecar.write_bytes(IMPORT_TEMPLATE.format(uid='uid://' + text, name=path.name, hash=hashlib.md5(res.encode()).hexdigest(),
                                               res=res, mipmaps=str(mipmaps).lower()).encode('utf-8'))


def change(a, b):
    return ndimage.gaussian_filter(np.abs(a - b).max(axis=2), 1.2)


def cut(master, edit, box, others, pad, grow, band):
    """The layer and building alphas around one plot, in a window of the full scene.

    Returns the window origin, the tone-matched edit, the layer alpha (the building plus
    the painted ground in a band above its base) and the building's own mask.
    """
    height, width = master.shape[:2]
    x, y, w, h = box
    cx0, cy0 = max(0, x - pad), max(0, y - pad)
    cx1, cy1 = min(width, x + w + pad), min(height, y + h + pad)
    m = master[cy0:cy1, cx0:cx1]
    e = edit[cy0:cy1, cx0:cx1].copy()

    def rect(bx, by, bw, bh):
        r = np.zeros(m.shape[:2], bool)
        r[max(0, by - cy0):max(0, by - cy0 + bh), max(0, bx - cx0):max(0, bx - cx0 + bw)] = True
        return r

    inside = rect(x, y, w, h)
    # Match the edit's tone to the backdrop on the bare ground inside the box, as an
    # offset only: a gain would sharpen the building along with the ground.
    land = inside & ~ndimage.binary_dilation(change(e, m) > 30, iterations=20)
    if land.sum() < 3000:
        land = inside & ~ndimage.binary_dilation(change(e, m) > 50, iterations=6)
    for c in range(3):
        e[..., c] = np.clip(e[..., c] + np.clip(m[..., c][land].mean() - e[..., c][land].mean(), -25.0, 25.0), 0, 255)
    d = change(e, m)
    # The building: GrabCut on the edit and its change, seeded by the strongest change
    # that touches the box (the model paints a little past the mask: steps, cranes).
    core = d > 70
    labels, count = ndimage.label(core)
    if count:
        sizes = ndimage.sum(core, labels, range(1, count + 1))
        keep = np.zeros(count + 1, bool)
        for i in range(1, count + 1):
            keep[i] = sizes[i - 1] >= 0.02 * sizes.max() and bool(((labels == i) & inside).any())
        core = keep[labels]
    core = ndimage.binary_erosion(core, iterations=1)
    if not core.any():
        raise ValueError('no building painted in the box')
    near = ndimage.binary_dilation(core, iterations=36)
    trimap = np.full(d.shape, cv2.GC_PR_BGD, np.uint8)
    trimap[(d > 26) & near] = cv2.GC_PR_FGD
    trimap[~ndimage.binary_dilation(inside, iterations=70) | ((d < 9) & ~near)] = cv2.GC_BGD
    trimap[core] = cv2.GC_FGD
    cv2.setRNGSeed(0)
    cv2.grabCut(np.dstack([e[..., 2], e[..., 1], np.clip(d * 2.5, 0, 255)]).astype(np.uint8), trimap, None,
                np.zeros((1, 65)), np.zeros((1, 65)), 6, cv2.GC_INIT_WITH_MASK)
    solid = (trimap == cv2.GC_FGD) | (trimap == cv2.GC_PR_FGD)
    labels, _ = ndimage.label(solid)
    seeded = np.unique(labels[core])
    solid = ndimage.binary_fill_holes(ndimage.binary_closing(np.isin(labels, seeded[seeded > 0]), iterations=3))
    labels, count = ndimage.label(solid)
    if count > 1:  # stray patches of changed smoke or rock away from the building
        sizes = ndimage.sum(solid, labels, range(1, count + 1))
        solid = np.isin(labels, 1 + np.flatnonzero(sizes >= 0.15 * sizes.max()))
    building = ndimage.gaussian_filter(solid.astype(np.float32), 1.0)
    # The layer keeps the edit's painted ground (foundation, path, shadow) only in a
    # band above the building's base: higher up the edit repaints the scene softer
    # than the backdrop. Inside other plots' boxes it keeps the building alone.
    ground = ndimage.gaussian_filter(ndimage.binary_dilation(inside, iterations=grow).astype(np.float32), 6.0)
    rows = np.arange(ground.shape[0], dtype=np.float32)[:, None]
    base = np.nonzero(solid)[0].max()
    ground *= np.clip((rows - (base - band)) / (band * 0.5), 0.0, 1.0)
    alpha = np.maximum(ground, building)
    zone = np.zeros_like(inside)
    for other in others:
        zone |= rect(*other)
    if zone.any():
        zone_weight = ndimage.gaussian_filter(ndimage.binary_dilation(zone, iterations=grow).astype(np.float32), 6.0)
        alpha = alpha * (1.0 - zone_weight) + building * zone_weight
    return (cx0, cy0), e, alpha, building, solid


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
    master_image.resize(BACKDROP_SIZE, Image.Resampling.LANCZOS).save(runtime)
    write_import(runtime, mipmaps=False)
    prompt = ROOT / backdrop['prompt_path']
    write_backdrop_stage(BACKDROPS, faction, packet['stage'], {
        'source_path': uri(master_path), 'source_sha256': digest(master_path), 'source_size': [width, height],
        'prompt_path': uri(prompt), 'prompt_sha256': digest(prompt),
        'generation_date': generation['date'], 'generation_tool': generation['tool'],
        'reference_inputs': ['res://' + path for path in backdrop['reference_inputs']],
        'processing_tool': 'tools/package_town_plot_layers.py',
        'runtime_path': uri(runtime), 'runtime_sha256': digest(runtime),
    })

    rows = scene['factions'][faction]
    for item in packet['buildings']:
        bid = item['id']
        source = ROOT / item['source_path']
        if digest(source) != item['source_sha256']:
            raise ValueError('Changed painting: ' + str(source))
        others = [box for plot_id, box in packet['plots'].items() if plot_id != item['plot_id']]
        (cx0, cy0), edit, alpha, building, solid = cut(master, full_edit(master_image, item), item['box'], others,
                                                       settings['pad'], settings['grow'], settings['ground_band'])
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
    write_json(SCENE, scene)
    write_json(LAYOUT, layout)
    print(f"Packaged {len(packet['buildings'])} {faction} layers on the {packet['scene_id']} backdrop.")


if __name__ == '__main__':
    main()
