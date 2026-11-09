"""Building mattes for a faction's town scene: BiRefNet marks each painted building.

Every building in a town plot packet is a painting of the faction's empty backdrop with
the building added on its plot (see package_town_plot_layers.py). BiRefNet, a
segmentation network, marks the building in a window around it. The window covers the
plot and the paint that changed against the empty backdrop, and grows while the building
runs into its edge, because a building the window cuts off loses out to a smaller object
inside it. Each matte is saved as a greyscale PNG next to its painting (an untracked
source, like the painting) and recorded in the packet with its window;
package_town_plot_layers.py cuts the layers from it.

Runs in the matting environment of the unit pipeline (torch, transformers, safetensors,
timm, scipy, Pillow): the network code is the BiRefNet checkout under
HEROES_MATTING_ROOT, and the weights are BiRefNet's general model (MIT),
Comfy-Org/BiRefNet background_removal/birefnet.safetensors, from HEROES_BIREFNET_WEIGHTS.

usage: python tools/town_plot_mattes.py art/towns/source/generated/overhaul/faction_brasshollow/slag_canyon.json [building ids]
"""
import argparse
import hashlib
import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MATTING_ROOT = Path(os.environ.get('HEROES_MATTING_ROOT', 'H:/ai/minimax-h3/matting' if os.name == 'nt'
                                   else '~/.cache/heroes-like/matting')).expanduser()
WEIGHTS = Path(os.environ.get('HEROES_BIREFNET_WEIGHTS', 'H:/ai/trellis2/ComfyUI/models/background_removal/birefnet.safetensors'
                              if os.name == 'nt' else '~/.cache/heroes-like/matting/birefnet-general.safetensors')).expanduser()
WEIGHTS_SHA256 = '9ab37426bf4de0567af6b5d21b16151357149139362e6e8992021b8ce356a154'
os.environ.setdefault('HF_HOME', str(MATTING_ROOT / 'hf-cache'))
os.environ.setdefault('HF_MODULES_CACHE', str(MATTING_ROOT / 'hf-modules'))
os.environ['HF_HUB_OFFLINE'] = '1'
sys.path.insert(0, str(next((MATTING_ROOT / 'dependencies').glob('timm-*.whl'))))

import numpy as np  # noqa: E402
import torch  # noqa: E402
from PIL import Image  # noqa: E402
from safetensors.torch import load_file  # noqa: E402
from scipy import ndimage  # noqa: E402
from transformers import AutoModelForImageSegmentation  # noqa: E402

INPUT = 1024          # BiRefNet's input size
SCOUT = 0.4           # margin of the first, wide look, as a share of the larger side
MARGIN = 0.12         # window margin, as a share of the building's larger side
GROW = 0.25           # how far a window grows on a side the building touches
EDGE_SHARE = 0.02     # share of a window edge the building must cover to grow it
PASSES = 4            # at most this many windows per building
SEED_CHANGE = 70      # paint change that marks the building's extent


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def painting(master, item):
    """The building's painting over the whole scene: a close-up edit is scaled back."""
    with Image.open(ROOT / item['source_path']) as source:
        source = source.convert('RGB')
        crop = item.get('crop')
        if not crop:
            return source.resize(master.size, Image.Resampling.LANCZOS)
        x0, y0, w, h = crop
        scene = master.copy()
        scene.paste(source.resize((w, h), Image.Resampling.LANCZOS), (x0, y0))
        return scene


def extent(master, scene, box):
    """The plot box and the strong paint change that touches it."""
    change = ndimage.gaussian_filter(np.abs(np.asarray(scene, np.float32) - np.asarray(master, np.float32)).max(axis=2), 1.2)
    core = change > SEED_CHANGE
    x, y, w, h = box
    inside = np.zeros(core.shape, bool)
    inside[y:y + h, x:x + w] = True
    labels, count = ndimage.label(core)
    x0, y0, x1, y1 = x, y, x + w, y + h
    if count:
        sizes = ndimage.sum(core, labels, range(1, count + 1))
        for i in np.unique(labels[core & inside]):
            if sizes[i - 1] >= 0.02 * sizes.max():
                ys, xs = np.nonzero(labels == i)
                x0, y0, x1, y1 = min(x0, xs.min()), min(y0, ys.min()), max(x1, xs.max() + 1), max(y1, ys.max() + 1)
    return int(x0), int(y0), int(x1), int(y1)


def building_extent(solid, window, box):
    """The plot box and the parts of a window's mask that touch it, in scene pixels."""
    wx0, wy0 = window[0], window[1]
    x, y, w, h = box
    inside = np.zeros(solid.shape, bool)
    inside[max(0, y - wy0):max(0, y - wy0 + h), max(0, x - wx0):max(0, x - wx0 + w)] = True
    labels, _ = ndimage.label(solid)
    touching = np.unique(labels[solid & inside])
    if not len(touching):
        return None
    ys, xs = np.nonzero(np.isin(labels, touching))
    return (int(min(x, wx0 + xs.min())), int(min(y, wy0 + ys.min())),
            int(max(x + w, wx0 + xs.max() + 1)), int(max(y + h, wy0 + ys.max() + 1)))


def load_network(device):
    if digest(WEIGHTS) != WEIGHTS_SHA256:
        raise ValueError('Unexpected BiRefNet weights: ' + str(WEIGHTS))
    net = AutoModelForImageSegmentation.from_pretrained(MATTING_ROOT / 'BiRefNet-matting', trust_remote_code=True,
                                                        local_files_only=True, use_safetensors=True)
    net.load_state_dict({k: v.float() if v.is_floating_point() else v for k, v in load_file(str(WEIGHTS)).items()}, strict=True)
    return net.eval().to(device, dtype=torch.float16 if device == 'cuda' else torch.float32)


def predict(net, image, device):
    """BiRefNet's mask of the window, averaged with its mirror image."""
    tensor = torch.from_numpy(np.array(image.resize((INPUT, INPUT), Image.Resampling.BICUBIC))).permute(2, 0, 1).float().div(255)
    tensor = (tensor - torch.tensor([.485, .456, .406])[:, None, None]) / torch.tensor([.229, .224, .225])[:, None, None]
    batch = torch.stack([tensor, tensor.flip(-1)]).to(device, dtype=next(net.parameters()).dtype)
    with torch.inference_mode():
        pred = net(batch)[-1].sigmoid().float()
        pred = (pred[0:1] + pred[1:2].flip(-1)) / 2
        alpha = torch.nn.functional.interpolate(pred, size=(image.height, image.width), mode='bilinear', align_corners=False)
    return alpha[0, 0].cpu().numpy()


def main():
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    parser.add_argument('packet')
    parser.add_argument('ids', nargs='*', help='only these buildings')
    args = parser.parse_args()
    packet_path = (ROOT / args.packet).resolve()
    packet = json.loads(packet_path.read_text(encoding='utf-8'))
    master_path = ROOT / packet['backdrop']['source_path']
    if digest(master_path) != packet['backdrop']['source_sha256']:
        raise ValueError('Changed backdrop master: ' + str(master_path))
    master = Image.open(master_path).convert('RGB')
    width, height = master.size
    device = 'cuda' if torch.cuda.is_available() else 'cpu'
    net = load_network(device)
    for item in packet['buildings']:
        if args.ids and item['id'] not in args.ids:
            continue
        source = ROOT / item['source_path']
        if digest(source) != item['source_sha256']:
            raise ValueError('Changed painting: ' + str(source))
        scene = painting(master, item)
        # The painting differs from the empty backdrop only inside its crop.
        lx0, ly0, lw, lh = item.get('crop') or [0, 0, width, height]
        lx1, ly1 = lx0 + lw, ly0 + lh
        x0, y0, x1, y1 = extent(master, scene, item['box'])
        # A wide first look finds the building's own extent: dark walls on dark rock barely
        # change the paint, and a window that cuts the building off finds something smaller.
        scout = int(SCOUT * max(x1 - x0, y1 - y0))
        window = (max(lx0, x0 - scout), max(ly0, y0 - scout), min(lx1, x1 + scout), min(ly1, y1 + scout))
        found = building_extent(predict(net, scene.crop(window), device) > 0.5, window, item['box'])
        if found:
            x0, y0, x1, y1 = found
        margin = int(MARGIN * max(x1 - x0, y1 - y0))
        window = (max(lx0, x0 - margin), max(ly0, y0 - margin), min(lx1, x1 + margin), min(ly1, y1 + margin))
        for attempt in range(PASSES):
            alpha = predict(net, scene.crop(window), device)
            solid = alpha > 0.5
            wx0, wy0, wx1, wy1 = window
            step_x, step_y = int(GROW * (wx1 - wx0)), int(GROW * (wy1 - wy0))
            grown = (max(lx0, wx0 - step_x) if solid[:, :3].mean() > EDGE_SHARE else wx0,
                     max(ly0, wy0 - step_y) if solid[:3, :].mean() > EDGE_SHARE else wy0,
                     min(lx1, wx1 + step_x) if solid[:, -3:].mean() > EDGE_SHARE else wx1,
                     min(ly1, wy1 + step_y) if solid[-3:, :].mean() > EDGE_SHARE else wy1)
            if grown == window or attempt == PASSES - 1:
                break
            window = grown
        matte_path = source.with_name(source.stem + '_matte.png')
        Image.fromarray(np.clip(alpha * 255.0 + 0.5, 0, 255).astype(np.uint8), 'L').save(matte_path)
        item['matte'] = {'path': matte_path.relative_to(ROOT).as_posix(), 'sha256': digest(matte_path),
                         'window': [window[0], window[1], window[2] - window[0], window[3] - window[1]]}
        print(f"{item['id']}: window {item['matte']['window']}", flush=True)
    packet['matting'] = {
        'tool': 'tools/town_plot_mattes.py',
        'model': 'BiRefNet general (MIT): Comfy-Org/BiRefNet background_removal/birefnet.safetensors, '
                 'revision 25511f8787e51912e1480706b4e47b8f467fbf72',
        'weights_sha256': WEIGHTS_SHA256,
        'network_code': 'ZhengPeng7/BiRefNet-matting birefnet.py, revision eccde0a8cbdce7ac5fecfeb06340fe7b949e85d9',
        'input': f'{INPUT}x{INPUT}, ImageNet mean and std, averaged with the mirrored window',
        'window': f'the building BiRefNet finds touching the plot in a first look (plot box and paint change over '
                  f'{SEED_CHANGE}, margin {SCOUT}), then margin {MARGIN}, grown by {GROW} on a side the building '
                  f'covers over {EDGE_SHARE} of, at most {PASSES} windows',
    }
    packet_path.write_bytes((json.dumps(packet, indent=2) + '\n').encode('utf-8'))


if __name__ == '__main__':
    main()
