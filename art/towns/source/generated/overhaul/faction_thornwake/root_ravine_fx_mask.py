"""Builds the root ravine's stage-effect mask, faction_thornwake_root_ravine_fx_mask.png.

Red is the river at the lower right, green is the small waterfalls of the ravine wall, blue is
empty (no lamps are painted on the backdrop), and alpha is how thick the drifting pollen haze
is: thickest among the far trunks, thinner toward the viewer, none on the blossoming crowns in
the foreground (never below 1/255, so no import step treats the mask as see-through).
GrabCut separates the river from its banks, its pebbles and the fallen trunk inside a
hand-drawn zone, taught by boxes that are surely water; each fall is the pale paint inside its
own strip. Run from anywhere; it writes the runtime mask.
"""
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[5]
BACKDROP = ROOT / 'art/towns/runtime/backdrops/overhaul/faction_thornwake_root_ravine.png'
OUT = ROOT / 'art/towns/runtime/backdrops/overhaul/faction_thornwake_root_ravine_fx_mask.png'

# All shapes in backdrop pixels (1600x900).
# The river may lie inside this zone: right of the near bank, below the fallen trunk.
RIVER = [(1375, 575), (1600, 560), (1600, 900), (766, 900), (977, 844), (1172, 773), (1312, 727), (1359, 625)]
SURE_WATER = [(1445, 660, 1530, 781), (1289, 781, 1540, 883), (1016, 867, 1250, 898)]
# The pebbled bank at the right edge and the rocks of the lower right corner.
SURE_LAND = [(1548, 640, 1600, 708), (1568, 838, 1600, 900)]
# The waterfalls' strips, and how pale and colourless falling water is against the moss.
FALLS = [
    [(182, 150), (214, 150), (220, 262), (186, 262)],
    [(310, 300), (345, 300), (345, 398), (312, 398)],
    [(295, 622), (350, 622), (352, 758), (295, 758)],
    [(1025, 205), (1060, 205), (1060, 272), (1025, 272)],
]
FALL_LIGHT = 0.36
FALL_SAT = 120
# The blossoming crowns of the lower left corner: nearer than the haze.
CROWNS = [(0, 625), (100, 625), (210, 664), (265, 722), (350, 738), (415, 719), (555, 730), (633, 770), (711, 785), (790, 840), (812, 900), (0, 900)]
# Haze thickness by depth: full among the far trunks, thin near the viewer.
HAZE_TOP = 40
HAZE_FAR = (150, 0.70)     # row, thickness
HAZE_MID = (430, 0.40)
HAZE_NEAR = (760, 0.20)

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
    zone = poly(RIVER) & ~poly(CROWNS)
    mask = np.full((H, W), cv2.GC_BGD, np.uint8)
    mask[zone] = cv2.GC_PR_FGD
    for x0, y0, x1, y1 in SURE_LAND:
        mask[y0:y1, x0:x1] = cv2.GC_BGD
    for x0, y0, x1, y1 in SURE_WATER:
        mask[y0:y1, x0:x1] = cv2.GC_FGD
    bgd, fgd = np.zeros((1, 65), np.float64), np.zeros((1, 65), np.float64)
    cv2.grabCut(cv2.cvtColor(img, cv2.COLOR_RGB2BGR), mask, None, bgd, fgd, 6, cv2.GC_INIT_WITH_MASK)
    water = clean(np.isin(mask, (cv2.GC_FGD, cv2.GC_PR_FGD)) & zone, 200)
    # Three pixels off the banks and pebbles, so their edges never waver with the water.
    kept = cv2.erode(water.astype(np.uint8), np.ones((3, 3), np.uint8), iterations=3).astype(bool)
    return water, soft(kept, 1.5)


def fall_mask():
    hsv = cv2.cvtColor(img, cv2.COLOR_RGB2HSV)
    lum = (img.astype(np.float32) / 255.0) @ np.array([0.3, 0.59, 0.11], np.float32)
    strips = np.zeros((H, W), bool)
    for strip in FALLS:
        strips |= poly(strip)
    cool = img[..., 2].astype(np.int16) >= img[..., 0]  # falling water is blue-white, moss and roots are not
    fall = clean(strips & cool & (lum > FALL_LIGHT) & (hsv[..., 1] < FALL_SAT), 30)
    return fall, soft(fall, 1.2)


def haze_mask():
    ys = np.arange(H, dtype=np.float32)
    depth = np.interp(ys, [HAZE_TOP, HAZE_FAR[0], HAZE_MID[0], HAZE_NEAR[0], H], [0.0, HAZE_FAR[1], HAZE_MID[1], HAZE_NEAR[1], HAZE_NEAR[1]])
    a = np.repeat(depth[:, None], W, axis=1)
    return a * (1.0 - np.clip(soft(poly(CROWNS), 22.0) * 1.3, 0, 1))


def main():
    water, r = water_mask()
    fall, g = fall_mask()
    a = haze_mask()
    zero = np.zeros((H, W), np.float32)
    out = np.stack([r, g, zero, (1.0 + 254.0 * a) / 255.0], axis=2)
    Image.fromarray(np.clip(out * 255.0 + 0.5, 0, 255).astype(np.uint8), 'RGBA').save(OUT, optimize=True)
    print('water %.1f%%, falls %.2f%%, haze over a third %.1f%%' % (water.mean() * 100, fall.mean() * 100, (a > 0.33).mean() * 100))


if __name__ == '__main__':
    main()
