"""Marks what stands in front of the buildings in the dusk fen: dusk_fen_foreground.png.

The great tree at the right edge, with its trunk, its roots and the thick of its branches, is
nearer to the viewer than any building. White in the mask is that tree; the packaging tool
cuts every building layer away under it, so the tree stays in front. GrabCut finds the tree's
edge in the backdrop master from hand-drawn seeds: a core that is surely trunk and root, and a
band around it that may be. Run from anywhere; then give the packet the mask's new hash.
"""
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
MASTER = HERE / 'dusk_fen_v2.png'
OUT = HERE / 'dusk_fen_foreground.png'

# All shapes in master pixels (2048x1152).
ZONE = [(1780, 0), (2048, 0), (2048, 1152), (1150, 1152), (1150, 1070), (1400, 990), (1560, 930), (1700, 850), (1790, 730),
        (1740, 560), (1700, 420), (1780, 300), (1760, 160)]
TRUNK = [(2048, 600), (2000, 640), (1950, 740), (1880, 870), (1800, 970), (1740, 1060), (1700, 1152), (2048, 1152)]
ROOT = [(1870, 890), (1740, 965), (1600, 1015), (1480, 1055), (1380, 1085), (1280, 1112)]
ROOT_WIDTH = 22
BRANCHES = [(1790, 150), (2048, 20), (2048, 720), (1960, 700), (1800, 560), (1740, 640), (1700, 520), (1900, 400), (1800, 330),
            (1840, 200)]
BAND = 40          # how far past the core the tree may reach
SMALLEST = 1500    # stray specks below this area are dropped
EDGE_SOFT = 1.0    # blur of the mask's edge


def main():
    img = np.asarray(Image.open(MASTER).convert('RGB'))
    height, width = img.shape[:2]

    def poly(points):
        m = np.zeros((height, width), np.uint8)
        cv2.fillPoly(m, [np.array(points, np.int32)], 1)
        return m.astype(bool)

    zone = poly(ZONE)
    core = poly(TRUNK)
    root = np.zeros((height, width), np.uint8)
    cv2.polylines(root, [np.array(ROOT, np.int32)], False, 1, ROOT_WIDTH)
    core |= root.astype(bool)
    mask = np.full((height, width), cv2.GC_BGD, np.uint8)
    mask[zone] = cv2.GC_PR_BGD
    band = cv2.dilate(core.astype(np.uint8), np.ones((3, 3), np.uint8), iterations=BAND).astype(bool)
    mask[zone & (band | poly(BRANCHES))] = cv2.GC_PR_FGD
    mask[core] = cv2.GC_FGD
    bgd, fgd = np.zeros((1, 65), np.float64), np.zeros((1, 65), np.float64)
    cv2.grabCut(cv2.cvtColor(img, cv2.COLOR_RGB2BGR), mask, None, bgd, fgd, 8, cv2.GC_INIT_WITH_MASK)
    tree = np.isin(mask, (cv2.GC_FGD, cv2.GC_PR_FGD)).astype(np.uint8)
    tree = cv2.morphologyEx(tree, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
    n, labels, stats, _ = cv2.connectedComponentsWithStats(tree, 8)
    kept = np.zeros((height, width), np.float32)
    for i in range(1, n):
        if stats[i, cv2.CC_STAT_AREA] > SMALLEST:
            kept[labels == i] = 1.0
    kept = cv2.GaussianBlur(kept, (0, 0), EDGE_SOFT)
    Image.fromarray(np.clip(kept * 255.0 + 0.5, 0, 255).astype(np.uint8), 'L').save(OUT, optimize=True)
    print('foreground %.1f%% of the picture' % (kept.mean() * 100))


if __name__ == '__main__':
    main()
