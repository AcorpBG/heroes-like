"""Marks what stands in front of the buildings in the root ravine: root_ravine_foreground.png.

The crowns of the blossoming trees in the lower left corner are nearer to the viewer than any
building. White in the mask is those crowns, with their boughs; the packaging tool cuts every
building layer away under it, so the blossom stays in front. GrabCut finds the crowns' edge in
the backdrop master inside a hand-drawn zone: paint that is clearly pink or white blossom is
surely crown, the rest of the zone may be. Run from anywhere; then give the packet the mask's
new hash.
"""
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
MASTER = HERE / 'root_ravine.png'
OUT = HERE / 'root_ravine_foreground.png'

# All shapes in master pixels (2048x1152).
ZONE = [(0, 800), (130, 800), (270, 850), (340, 925), (450, 945), (530, 920), (710, 935), (810, 985), (910, 1005), (1010, 1075),
        (1040, 1152), (0, 1152)]
# Blossom: light, and redder than it is green.
BLOSSOM_LIGHT = 150
BLOSSOM_PINK = 14
SMALLEST = 1500    # stray specks below this area are dropped
EDGE_SOFT = 1.0    # blur of the mask's edge


def main():
    img = np.asarray(Image.open(MASTER).convert('RGB'))
    height, width = img.shape[:2]
    zone = np.zeros((height, width), np.uint8)
    cv2.fillPoly(zone, [np.array(ZONE, np.int32)], 1)
    zone = zone.astype(bool)
    r, g = img[..., 0].astype(np.int16), img[..., 1].astype(np.int16)
    blossom = zone & (r > BLOSSOM_LIGHT) & (r - g > BLOSSOM_PINK)
    blossom = cv2.erode(blossom.astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool)
    mask = np.full((height, width), cv2.GC_BGD, np.uint8)
    mask[zone] = cv2.GC_PR_FGD
    mask[blossom] = cv2.GC_FGD
    bgd, fgd = np.zeros((1, 65), np.float64), np.zeros((1, 65), np.float64)
    cv2.grabCut(cv2.cvtColor(img, cv2.COLOR_RGB2BGR), mask, None, bgd, fgd, 6, cv2.GC_INIT_WITH_MASK)
    crowns = np.isin(mask, (cv2.GC_FGD, cv2.GC_PR_FGD)).astype(np.uint8)
    crowns = cv2.morphologyEx(crowns, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
    n, labels, stats, _ = cv2.connectedComponentsWithStats(crowns, 8)
    kept = np.zeros((height, width), np.float32)
    for i in range(1, n):
        if stats[i, cv2.CC_STAT_AREA] > SMALLEST:
            kept[labels == i] = 1.0
    kept = cv2.GaussianBlur(kept, (0, 0), EDGE_SOFT)
    Image.fromarray(np.clip(kept * 255.0 + 0.5, 0, 255).astype(np.uint8), 'L').save(OUT, optimize=True)
    print('foreground %.1f%% of the picture' % (kept.mean() * 100))


if __name__ == '__main__':
    main()
