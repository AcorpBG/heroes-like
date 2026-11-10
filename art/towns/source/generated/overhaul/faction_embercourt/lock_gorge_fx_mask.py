"""Builds the lock gorge's stage-effect mask, faction_embercourt_lock_gorge_fx_mask.png.

Red is the water (the harbour basin and the river above the locks), green the water falling
over the four lock gates, blue the fire baskets on the lock piers with their glow, and alpha is
1/255 everywhere: no drifting fog, and no import step treats the mask as see-through.
The shapes are drawn by hand for this painting; GrabCut finds the shores inside them, and the
falls and the fires are picked by their paint. Run from anywhere; it writes the runtime mask.
"""
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[5]
BACKDROP = ROOT / 'art/towns/runtime/backdrops/overhaul/faction_embercourt_lock_gorge.png'
OUT = ROOT / 'art/towns/runtime/backdrops/overhaul/faction_embercourt_lock_gorge_fx_mask.png'

# All shapes in backdrop pixels (1600x900).
# Water: generous zones, open water that is surely water, and the moored barges.
BASIN = [(0, 650), (215, 606), (405, 588), (590, 576), (750, 578), (1045, 584), (1110, 615), (1220, 662), (1252, 705),
         (1160, 760), (1035, 792), (910, 830), (790, 868), (690, 900), (0, 900)]
RIVER = [(330, 150), (395, 140), (450, 165), (470, 195), (540, 225), (585, 250), (600, 300), (585, 340), (545, 340),
         (520, 300), (480, 290), (450, 250), (420, 225), (370, 205), (335, 180)]
SURE_WATER = [(260, 660, 760, 860), (560, 610, 1000, 700), (1010, 640, 1150, 700)]
BARGES = [(64, 640, 196, 700), (24, 700, 186, 812)]
# The river's water is lighter than this; its banks are darker.
RIVER_LIGHT = 0.46
# Where the zone, not a shore, ends the water, it fades out over this many pixels.
ZONE_FADE = 14.0

# The falls: a box around the white water under each lock gate, from the top lock down.
FALLS = [(650, 288, 740, 324), (704, 354, 820, 396), (768, 440, 900, 498), (828, 546, 1004, 606)]
# The fire baskets stand on the lock piers: look for their flames inside this box.
FIRES = (590, 230, 1030, 520)

img = np.asarray(Image.open(BACKDROP).convert('RGB'))
H, W = img.shape[:2]
c = img.astype(np.float32) / 255.0
lum = c @ np.array([0.3, 0.59, 0.11], np.float32)
spread = c.max(axis=2) - c.min(axis=2)


def poly(points):
    m = np.zeros((H, W), np.uint8)
    cv2.fillPoly(m, [np.array(points, np.int32)], 1)
    return m.astype(bool)


def soft(m, sigma):
    return cv2.GaussianBlur(m.astype(np.float32), (0, 0), sigma)


def falls_mask():
    """The falling water is the light, nearly grey paint under each gate; the dark timber and
    the stone between the streams stay still."""
    boxes = np.zeros((H, W), np.float32)
    for x0, y0, x1, y1 in FALLS:
        boxes[y0:y1, x0:x1] = 1.0
    white = np.clip((lum - 0.36) / 0.18, 0, 1) * np.clip((0.30 - spread) / 0.12, 0, 1)
    return soft(boxes, 3.0) * white


def water_mask(falls):
    zone = poly(BASIN)
    mask = np.full((H, W), cv2.GC_BGD, np.uint8)
    mask[zone] = cv2.GC_PR_FGD
    for x0, y0, x1, y1 in BARGES:
        mask[y0:y1, x0:x1][zone[y0:y1, x0:x1]] = cv2.GC_PR_BGD
    for x0, y0, x1, y1 in SURE_WATER:
        mask[y0:y1, x0:x1] = cv2.GC_FGD
    bgd, fgd = np.zeros((1, 65), np.float64), np.zeros((1, 65), np.float64)
    cv2.grabCut(cv2.cvtColor(img, cv2.COLOR_RGB2BGR), mask, None, bgd, fgd, 6, cv2.GC_INIT_WITH_MASK)
    water = np.isin(mask, (cv2.GC_FGD, cv2.GC_PR_FGD)) & zone & (falls < 0.3)
    # The river above the locks glows gold against its darker banks: GrabCut, taught by the dark
    # basin, takes it for land, so it is picked by its light.
    river = poly(RIVER)
    water |= river & (lum > RIVER_LIGHT)
    zone |= river
    water = cv2.morphologyEx(water.astype(np.uint8), cv2.MORPH_OPEN, np.ones((3, 3), np.uint8)).astype(bool)
    n, labels, stats, _ = cv2.connectedComponentsWithStats((~water).astype(np.uint8), 8)
    for i in range(1, n):
        if stats[i, cv2.CC_STAT_AREA] < 80:
            water[labels == i] = True
    n, labels, stats, _ = cv2.connectedComponentsWithStats(water.astype(np.uint8), 8)
    for i in range(1, n):
        if stats[i, cv2.CC_STAT_AREA] < 200:
            water[labels == i] = False
    pad = 40
    padded = cv2.copyMakeBorder(zone.astype(np.uint8), pad, pad, pad, pad, cv2.BORDER_REPLICATE)
    inside = cv2.distanceTransform(padded, cv2.DIST_L2, 5)[pad:-pad, pad:-pad]
    # Two pixels off the shores, the quay and the barges, so their edges never waver with the water.
    kept = cv2.erode(water.astype(np.uint8), np.ones((3, 3), np.uint8), iterations=2).astype(bool)
    return water, soft(kept, 1.0) * np.clip(inside / ZONE_FADE, 0, 1)


def fires_mask():
    """The flames of the baskets on the lock piers, with the glow around each."""
    x0, y0, x1, y1 = FIRES
    flame = np.zeros((H, W), bool)
    flame[y0:y1, x0:x1] = ((c[..., 0] > 0.92) & (c[..., 1] > 0.55) & (c[..., 0] - c[..., 2] > 0.45))[y0:y1, x0:x1]
    n, labels, stats, _ = cv2.connectedComponentsWithStats(flame.astype(np.uint8), 8)
    for i in range(1, n):
        if stats[i, cv2.CC_STAT_AREA] < 12:
            flame[labels == i] = False
    glow = cv2.dilate(flame.astype(np.uint8), cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (37, 37)))
    return flame, np.clip(soft(glow, 6.0) * 1.2, 0, 1)


def main():
    falls = falls_mask()
    water, r = water_mask(falls)
    g = soft(falls, 0.8)
    flame, fires = fires_mask()
    b = fires * (1.0 - r) * (1.0 - np.clip(g * 1.5, 0, 1))
    a = np.full((H, W), 1.0 / 255.0, np.float32)
    out = np.stack([r, g, b, a], axis=2)
    Image.fromarray(np.clip(out * 255.0 + 0.5, 0, 255).astype(np.uint8), 'RGBA').save(OUT, optimize=True)
    n = cv2.connectedComponents(flame.astype(np.uint8), connectivity=8)[0] - 1
    print('water %.1f%%, falls %.2f%%, fires %d' % (water.mean() * 100, (falls > 0.3).mean() * 100, n))


if __name__ == '__main__':
    main()
