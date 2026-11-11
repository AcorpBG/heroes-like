"""Mends four mattes of the root ravine that BiRefNet cannot get right.

A moss roof looks like the mossy ground to it. It left the roof out between the domes and
the arcade of the hall's second and third stage, kept only the arch and the stag of the
first white-hart lodge and dropped the lodge itself, and took a piece of the ledge below
the root bastion's den for part of the den. Each building here names outlines in master
pixels (2048x1152): what lies inside an "add" outline joins the matte, what lies inside a
"remove" outline leaves it.

Run from anywhere, once, after tools/town_plot_mattes.py wrote these buildings' mattes; it
rewrites the matte files and puts their new hashes in the packet.
"""
import hashlib
import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image
from scipy import ndimage

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[5]
PACKET = HERE / 'root_ravine.json'
EDGE_SOFT = 1.0    # blur of an outline's edge
SEAL = 9           # seams up to this wide are closed, unless the building says otherwise

PATCHES = {
    # The moss roof and its wisteria, between the dome and the arches and over both wings.
    'building_dev_hall_2': {'add': [
        [(916, 382), (903, 362), (911, 351), (954, 337), (974, 341), (999, 334), (984, 347), (958, 374), (943, 365)],
        [(1024, 324), (1069, 337), (1099, 347), (1114, 348), (1126, 334), (1146, 332), (1164, 337), (1184, 349), (1201, 359),
         (1210, 377), (1209, 387), (1161, 387), (1139, 412), (1119, 387), (1099, 372), (1066, 369), (1059, 352)],
        [(955, 336), (1150, 330), (1150, 352), (955, 356)],
    ]},
    'building_dev_hall_3': {'add': [
        [(899, 315), (891, 342), (902, 379), (926, 354), (942, 359), (969, 332), (999, 305), (986, 294), (969, 302), (946, 324),
         (916, 320)],
        [(1009, 301), (1032, 292), (1049, 302), (1062, 305), (1072, 319), (1096, 330), (1152, 340), (1172, 349), (1182, 369),
         (1164, 404), (1139, 407), (1134, 422), (1119, 392), (1109, 369), (1092, 356), (1076, 362), (1052, 342), (1032, 315)],
        [(1217, 335), (1236, 339), (1251, 355), (1247, 389), (1232, 369), (1222, 349)],
        [(984, 290), (1012, 283), (1035, 290), (1035, 305), (1005, 308), (984, 300)],
    ]},
    # The lodge: its moss roof, its lit arcade and the hall behind the arch.
    'building_dev_thornwake_t5_1': {'seal': 3, 'add': [
        [(521, 399), (520, 361), (518, 357), (534, 340), (557, 331), (569, 326), (589, 320), (609, 313), (619, 309), (629, 309),
         (642, 318), (655, 335), (668, 360), (672, 398), (622, 401), (585, 400), (552, 399)],
    ]},
    # The ledge under the den is ground.
    'building_dev_thornwake_t7_1': {'remove': [
        [(640, 812), (900, 812), (922, 801), (1170, 801), (1170, 990), (640, 990)],
    ]},
}


def outline(shape, window, points):
    x, y, w, h = window
    mask = np.zeros(shape, np.uint8)
    cv2.fillPoly(mask, [np.array([(px - x, py - y) for px, py in points], np.int32)], 255)
    return cv2.GaussianBlur(mask.astype(np.float32) / 255.0, (0, 0), EDGE_SOFT)


def main():
    packet = json.loads(PACKET.read_text(encoding='utf-8'))
    for item in packet['buildings']:
        patch = PATCHES.get(item['id'])
        if not patch:
            continue
        path = ROOT / item['matte']['path']
        with Image.open(path) as image:
            matte = np.asarray(image.convert('L')).astype(np.float32) / 255.0
        before = matte.mean()
        for points in patch.get('add', []):
            matte = np.maximum(matte, outline(matte.shape, item['matte']['window'], points))
        if patch.get('add'):
            seal = patch.get('seal', SEAL)
            # Seams between an outline and what BiRefNet found, and what they enclose, belong too.
            sealed = cv2.morphologyEx((matte > 0.5).astype(np.uint8), cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (seal, seal)))
            sealed = ndimage.binary_fill_holes(sealed).astype(np.float32)
            matte = np.maximum(matte, cv2.GaussianBlur(sealed, (0, 0), EDGE_SOFT) * (sealed > 0))
        for points in patch.get('remove', []):
            matte = np.minimum(matte, 1.0 - outline(matte.shape, item['matte']['window'], points))
        Image.fromarray(np.clip(matte * 255.0 + 0.5, 0, 255).astype(np.uint8), 'L').save(path)
        item['matte']['sha256'] = hashlib.sha256(path.read_bytes()).hexdigest()
        item['matte']['tool'] = (HERE / Path(__file__).name).relative_to(ROOT).as_posix()
        print('%s: matte %.1f%% -> %.1f%% of its window' % (item['id'], before * 100, matte.mean() * 100))
    PACKET.write_bytes((json.dumps(packet, indent=2, ensure_ascii=False) + '\n').encode('utf-8'))


if __name__ == '__main__':
    main()
