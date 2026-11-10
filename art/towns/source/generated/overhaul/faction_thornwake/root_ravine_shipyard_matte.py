"""Cuts the root ravine's shipyard by hand: building_dev_shipyard_ravine_matte.png.

BiRefNet marks only the barge of this painting, one, two or three looks alike: the boat shed
grows out of the mossy bank and the deck lies flat on the water, so it takes neither for part of
the object. This matte is what the painting changed against the empty ravine, inside an outline
drawn round the shed, the barge, the deck and its piles. Run from anywhere after the packet
names the shipyard's painting; it writes the matte and puts its hash and window in the packet.
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
BUILDING = 'building_dev_shipyard'

# All shapes in master pixels (2048x1152).
WINDOW = (1268, 773, 544, 354)     # x, y, w, h
OUTLINE = [(1288, 992), (1296, 912), (1345, 852), (1418, 830), (1500, 838), (1545, 878), (1552, 915), (1608, 822), (1702, 832),
           (1702, 950), (1716, 975), (1768, 1030), (1752, 1068), (1570, 1078), (1390, 1072), (1362, 1032), (1308, 1018)]
CHANGE = 12.0      # mean colour change (0..255) that counts as painted
CHANGE_SOFT = 2.5  # blur of the change before the test
SMALLEST = 400     # stray specks below this area are dropped
EDGE_SOFT = 1.2    # blur of the matte's edge


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    packet = json.loads(PACKET.read_text(encoding='utf-8'))
    item = next(b for b in packet['buildings'] if b['id'] == BUILDING)
    master = Image.open(ROOT / packet['backdrop']['source_path']).convert('RGB')
    cx, cy, cw, ch = item['crop']
    scene = master.copy()
    scene.paste(Image.open(ROOT / item['source_path']).convert('RGB').resize((cw, ch), Image.LANCZOS), (cx, cy))
    change = np.abs(np.asarray(scene).astype(np.float32) - np.asarray(master).astype(np.float32)).mean(axis=2)
    change = cv2.GaussianBlur(change, (0, 0), CHANGE_SOFT)
    outline = np.zeros(change.shape, np.uint8)
    cv2.fillPoly(outline, [np.array(OUTLINE, np.int32)], 1)
    yard = (outline > 0) & (change > CHANGE)
    yard = cv2.morphologyEx(yard.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((7, 7), np.uint8))
    yard = ndimage.binary_fill_holes(yard)
    n, labels, stats, _ = cv2.connectedComponentsWithStats(yard.astype(np.uint8), 8)
    kept = np.zeros(change.shape, np.float32)
    for i in range(1, n):
        if stats[i, cv2.CC_STAT_AREA] > SMALLEST:
            kept[labels == i] = 1.0
    kept = cv2.GaussianBlur(kept, (0, 0), EDGE_SOFT)
    x, y, w, h = WINDOW
    out = (ROOT / item['source_path']).with_name(Path(item['source_path']).stem + '_matte.png')
    Image.fromarray(np.clip(kept[y:y + h, x:x + w] * 255.0 + 0.5, 0, 255).astype(np.uint8), 'L').save(out)
    item['matte'] = {'path': out.relative_to(ROOT).as_posix(), 'sha256': digest(out), 'window': list(WINDOW),
                     'tool': (HERE / Path(__file__).name).relative_to(ROOT).as_posix()}
    PACKET.write_bytes((json.dumps(packet, indent=2) + '\n').encode('utf-8'))
    print('shipyard matte: %.1f%% of its window' % (kept[y:y + h, x:x + w].mean() * 100))


if __name__ == '__main__':
    main()
