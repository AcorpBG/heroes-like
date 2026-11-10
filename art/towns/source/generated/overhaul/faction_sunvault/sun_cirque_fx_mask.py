"""Builds the sun cirque's stage-effect mask, faction_sunvault_sun_cirque_fx_mask.png.

Red is the glacial lake, green is the meltwater fall, blue is empty (no lamps are painted on the
backdrop), and alpha is how thick the drifting vapour is: thickest in the spray at the foot of
the fall, a thin veil along the cirque wall and over the cold lake, none on the sky or on the
rocks in the foreground (never below 1/255, so no import step treats the mask as see-through).
GrabCut separates the lake from its shores, floes and boulders inside a hand-drawn zone, taught
by boxes that are surely water; the fall is the pale paint inside the fall's own strip. Run from anywhere; it writes the runtime mask.
"""
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[5]
BACKDROP = ROOT / 'art/towns/runtime/backdrops/overhaul/faction_sunvault_sun_cirque.png'
OUT = ROOT / 'art/towns/runtime/backdrops/overhaul/faction_sunvault_sun_cirque_fx_mask.png'

# All shapes in backdrop pixels (1600x900).
# The lake may lie inside this zone: below the far shore, left of the near right shore.
LAKE = [(0, 580), (705, 580), (760, 640), (800, 700), (880, 760), (930, 830), (960, 900), (0, 900)]
SURE_WATER = [(40, 610, 660, 640), (200, 660, 640, 720), (420, 740, 760, 800), (520, 820, 800, 880)]
# The rocks and pines of the lower left corner, in front of the lake.
NEAR_BANK = [(0, 715), (45, 735), (115, 800), (235, 845), (335, 880), (365, 900), (0, 900)]
# Ice floes drift only in the lake's lower left; their paint is pale and nearly colourless.
FLOES = [(0, 660), (420, 660), (420, 830), (0, 830)]
FLOE_LIGHT = 185
FLOE_SAT = 75
# The fall's strip, from its lip to the lake, and how pale its paint is.
FALL = [(704, 220), (728, 220), (708, 430), (700, 585), (652, 585), (668, 430)]
FALL_LIGHT = 0.62
FALL_SAT = 110
# Vapour: the spray at the fall's foot, and thin bands by depth.
SPRAY = (672, 575, 120, 70)    # centre x, centre y, half width, half height
SKY_LINE = 105                 # no vapour above the peaks
VEIL_FAR = (190, 0.85)         # row, thickness
VEIL_MID = (430, 0.60)
VEIL_NEAR = (700, 0.35)
# The boulders in the foreground, lower right: nearer than the vapour.
FOREGROUND = [(1000, 900), (1040, 840), (1130, 800), (1290, 770), (1420, 760), (1600, 770), (1600, 900)]

img = np.asarray(Image.open(BACKDROP).convert('RGB'))
H, W = img.shape[:2]


def poly(points):
    m = np.zeros((H, W), np.uint8)
    cv2.fillPoly(m, [np.array(points, np.int32)], 1)
    return m.astype(bool)


def soft(m, sigma):
    return cv2.GaussianBlur(m.astype(np.float32), (0, 0), sigma)


def clean(m, smallest):
    m = cv2.morphologyEx(m.astype(np.uint8), cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
    n, labels, stats, _ = cv2.connectedComponentsWithStats(m, 8)
    for i in range(1, n):
        if stats[i, cv2.CC_STAT_AREA] < smallest:
            m[labels == i] = 0
    return m.astype(bool)


def water_mask():
    zone = poly(LAKE) & ~poly(NEAR_BANK)
    mask = np.full((H, W), cv2.GC_BGD, np.uint8)
    mask[zone] = cv2.GC_PR_FGD
    for x0, y0, x1, y1 in SURE_WATER:
        mask[y0:y1, x0:x1] = cv2.GC_FGD
    bgd, fgd = np.zeros((1, 65), np.float64), np.zeros((1, 65), np.float64)
    cv2.grabCut(cv2.cvtColor(img, cv2.COLOR_RGB2BGR), mask, None, bgd, fgd, 6, cv2.GC_INIT_WITH_MASK)
    water = clean(np.isin(mask, (cv2.GC_FGD, cv2.GC_PR_FGD)) & zone, 200)
    # The ice floes are pale and nearly colourless; they lie still on the moving water.
    hsv = cv2.cvtColor(img, cv2.COLOR_RGB2HSV)
    cool = img[..., 2].astype(np.int16) >= img[..., 0]  # the sun's gold glints on the water are warm
    floes = clean((hsv[..., 2] > FLOE_LIGHT) & (hsv[..., 1] < FLOE_SAT) & cool & poly(FLOES), 80)
    water &= ~cv2.dilate(floes.astype(np.uint8), np.ones((3, 3), np.uint8), iterations=3).astype(bool)
    # Three pixels off the shores and the floes, so their edges never waver with the water.
    kept = cv2.erode(water.astype(np.uint8), np.ones((3, 3), np.uint8), iterations=3).astype(bool)
    return water, soft(kept, 1.5)


def fall_mask():
    hsv = cv2.cvtColor(img, cv2.COLOR_RGB2HSV)
    lum = (img.astype(np.float32) / 255.0) @ np.array([0.3, 0.59, 0.11], np.float32)
    fall = poly(FALL) & (lum > FALL_LIGHT) & (hsv[..., 1] < FALL_SAT)
    fall = clean(fall, 60)
    return fall, soft(fall, 1.2)


def vapour_mask():
    ys = np.arange(H, dtype=np.float32)
    depth = np.interp(ys, [SKY_LINE, VEIL_FAR[0], VEIL_MID[0], VEIL_NEAR[0], H], [0.0, VEIL_FAR[1], VEIL_MID[1], VEIL_NEAR[1], VEIL_NEAR[1]])
    a = np.repeat(depth[:, None], W, axis=1)
    cx, cy, rx, ry = SPRAY
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    spray = np.clip(1.0 - np.sqrt(((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2), 0.0, 1.0)
    a = np.maximum(a, spray ** 0.7)
    return a * (1.0 - np.clip(soft(poly(FOREGROUND), 22.0) * 1.3, 0, 1))


def main():
    water, r = water_mask()
    fall, g = fall_mask()
    a = vapour_mask()
    zero = np.zeros((H, W), np.float32)
    out = np.stack([r, g, zero, (1.0 + 254.0 * a) / 255.0], axis=2)
    Image.fromarray(np.clip(out * 255.0 + 0.5, 0, 255).astype(np.uint8), 'RGBA').save(OUT, optimize=True)
    print('water %.1f%%, fall %.2f%%, vapour over a third %.1f%%' % (water.mean() * 100, fall.mean() * 100, (a > 0.33).mean() * 100))


if __name__ == '__main__':
    main()
