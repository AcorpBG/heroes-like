"""Builds the dusk fen's stage-effect mask, faction_mireclaw_dusk_fen_fx_mask.png.

Red is the still water of the pools and the open mere, green and blue are empty (the swamp has
no falls, and no lamps are painted on the backdrop), and alpha is how thick the drifting mist is:
thickest in the far swamp, thinner toward the viewer, none on the sky or on the great tree in
the foreground (never below 1/255, so no import step treats the mask as see-through).
GrabCut separates the dark water of the mere from the reeds inside a hand-drawn zone, taught by
boxes that are surely water and boxes that are surely reeds or moss; the far pools under the
glow are picked by their light. Run from anywhere; it writes the
runtime mask.
"""
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[5]
BACKDROP = ROOT / 'art/towns/runtime/backdrops/overhaul/faction_mireclaw_dusk_fen.png'
OUT = ROOT / 'art/towns/runtime/backdrops/overhaul/faction_mireclaw_dusk_fen_fx_mask.png'

# All shapes in backdrop pixels (1600x900).
# The swamp floor, where pools may lie: below the far tree line, left of the foreground tree.
ZONE = [(0, 250), (1380, 250), (1400, 420), (1380, 560), (1300, 700), (1180, 790), (1060, 860), (980, 900), (0, 900)]
SURE_WATER = [(30, 470, 230, 560), (300, 560, 560, 610), (620, 650, 800, 700), (240, 740, 520, 860), (700, 440, 860, 465),
              (880, 395, 960, 425)]
SURE_LAND = [(120, 270, 620, 420), (420, 480, 960, 555), (290, 632, 590, 700), (20, 395, 120, 455), (0, 690, 200, 900),
             (560, 790, 1100, 900), (940, 380, 1340, 455), (830, 330, 1100, 390), (1000, 540, 1400, 780), (660, 240, 980, 300)]
# Far pools under the dusk glow shine paler than the reeds around them: inside this box, water is
# the paint lighter than FAR_LIGHT.
FAR_POOLS = (900, 130, 1410, 330)
FAR_LIGHT = 0.44
# The great tree, its branch and its roots in the foreground, and the sky above the far tree line.
TREE = [(1400, 0), (1600, 0), (1600, 900), (1110, 900), (1220, 812), (1368, 726), (1468, 546), (1406, 376), (1438, 156)]
SKY_LINE = 96
# Mist thickness by depth: full in the far swamp, thin near the viewer.
MIST_FAR = (120, 1.0)
MIST_MID = (420, 0.55)
MIST_NEAR = (760, 0.28)

img = np.asarray(Image.open(BACKDROP).convert('RGB'))
H, W = img.shape[:2]


def poly(points):
    m = np.zeros((H, W), np.uint8)
    cv2.fillPoly(m, [np.array(points, np.int32)], 1)
    return m.astype(bool)


def soft(m, sigma):
    return cv2.GaussianBlur(m.astype(np.float32), (0, 0), sigma)


def water_mask():
    zone = poly(ZONE) & ~poly(TREE)
    mask = np.full((H, W), cv2.GC_BGD, np.uint8)
    mask[zone] = cv2.GC_PR_BGD
    for x0, y0, x1, y1 in SURE_LAND:
        mask[y0:y1, x0:x1] = cv2.GC_BGD
    for x0, y0, x1, y1 in SURE_WATER:
        mask[y0:y1, x0:x1] = cv2.GC_FGD
    bgd, fgd = np.zeros((1, 65), np.float64), np.zeros((1, 65), np.float64)
    cv2.grabCut(cv2.cvtColor(img, cv2.COLOR_RGB2BGR), mask, None, bgd, fgd, 6, cv2.GC_INIT_WITH_MASK)
    water = np.isin(mask, (cv2.GC_FGD, cv2.GC_PR_FGD)) & zone
    x0, y0, x1, y1 = FAR_POOLS
    lum = (img.astype(np.float32) / 255.0) @ np.array([0.3, 0.59, 0.11], np.float32)
    far = np.zeros((H, W), bool)
    far[y0:y1, x0:x1] = lum[y0:y1, x0:x1] > FAR_LIGHT
    water |= far & ~poly(TREE)
    water = cv2.morphologyEx(water.astype(np.uint8), cv2.MORPH_OPEN, np.ones((5, 5), np.uint8)).astype(bool)
    n, labels, stats, _ = cv2.connectedComponentsWithStats(water.astype(np.uint8), 8)
    for i in range(1, n):
        if stats[i, cv2.CC_STAT_AREA] < 60:
            water[labels == i] = False
    # Three pixels off the reeds and banks, so their edges never waver with the water.
    kept = cv2.erode(water.astype(np.uint8), np.ones((3, 3), np.uint8), iterations=3).astype(bool)
    return water, soft(kept, 1.5)


def mist_mask():
    ys = np.arange(H, dtype=np.float32)
    depth = np.interp(ys, [SKY_LINE, MIST_FAR[0], MIST_MID[0], MIST_NEAR[0], H], [0.0, MIST_FAR[1], MIST_MID[1], MIST_NEAR[1], MIST_NEAR[1]])
    a = np.repeat(depth[:, None], W, axis=1)
    return a * (1.0 - np.clip(soft(poly(TREE), 26.0) * 1.3, 0, 1))


def main():
    water, r = water_mask()
    a = mist_mask()
    zero = np.zeros((H, W), np.float32)
    out = np.stack([r, zero, zero, (1.0 + 254.0 * a) / 255.0], axis=2)
    Image.fromarray(np.clip(out * 255.0 + 0.5, 0, 255).astype(np.uint8), 'RGBA').save(OUT, optimize=True)
    print('water %.1f%%, mist over a third %.1f%%' % (water.mean() * 100, (a > 0.33).mean() * 100))


if __name__ == '__main__':
    main()
