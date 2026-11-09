"""Builds the bell fjord's stage-effect mask, faction_veilmourn_bell_fjord_fx_mask.png.

Red is the water, green the falls, blue the land and what stands on it, and alpha how thick
the drifting fog is (never below 1/255, so no import step treats the mask as see-through).
The shapes are drawn by hand for this painting. GrabCut finds the shores, and BiRefNet marks
the ships, the jetty, the sea stack and the islands standing in the water, which GrabCut
takes for water. The marks are kept beside this file (bell_fjord_fx_objects.png, not
tracked); without them the script makes them, which needs torch and the matting weights
(see tools/town_plot_mattes.py). Run from anywhere; it writes the runtime mask in place.
"""
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[5]
BACKDROP = ROOT / 'art/towns/runtime/backdrops/overhaul/faction_veilmourn_bell_fjord.png'
OUT = ROOT / 'art/towns/runtime/backdrops/overhaul/faction_veilmourn_bell_fjord_fx_mask.png'
MARKS = HERE / 'bell_fjord_fx_objects.png'

# Boxes (x0, y0, x1, y1) around each thing standing in the water; BiRefNet looks at the box with
# a margin and keeps what it finds inside the box.
OBJECT_BOXES = {
    'far_ship': (52, 188, 112, 252), 'upper_ship': (58, 248, 150, 348), 'left_ship': (0, 322, 104, 450),
    'stack_ship': (150, 476, 350, 650), 'big_ship': (0, 556, 245, 870), 'jetty': (276, 684, 710, 806),
    'stack': (80, 360, 402, 580), 'left_cliff': (0, 190, 56, 266), 'islands': (20, 160, 245, 200),
}
OBJECT_MARGIN = 24
FAR_SHIP = (56, 200, 106, 248)  # too faint in the haze for BiRefNet

# Water: a generous zone, things standing in it, and open water that is surely water.
WATER_ZONE = [(0, 194), (296, 194), (306, 215), (300, 298), (392, 300), (398, 460), (398, 600), (352, 640),
              (352, 688), (640, 694), (700, 668), (840, 664), (905, 662), (1085, 668), (1115, 700), (1152, 742),
              (1152, 792), (1100, 812), (900, 800), (860, 822), (700, 832), (640, 862), (560, 900), (0, 900)]
OBJECTS = [  # boxes of ships, the jetty, islands and the stack: probably not water
    (0, 560, 240, 866), (155, 578, 346, 646), (5, 328, 100, 446), (60, 252, 146, 346), (55, 192, 108, 250),
    (0, 194, 52, 262), (280, 688, 700, 802), (610, 690, 705, 790)]
STACK = [(150, 368), (330, 368), (392, 420), (398, 570), (300, 575), (170, 570), (84, 560), (100, 470), (120, 420)]
SURE_WATER = [(110, 205, 330, 290), (130, 290, 160, 340), (210, 300, 320, 360), (0, 460, 70, 555), (360, 815, 560, 880),
              (720, 690, 1060, 735), (700, 745, 1100, 785), (250, 650, 340, 685)]
# Where the zone, not a shore, ends the water (at the cliff foot, at the cove's foot), the water
# fades out over this many pixels; the frame's own edges do not count.
ZONE_FADE = 22.0

# The falls: centre line (x, y, half width) from the top of the ravine to the cove. The stone
# bridge across them stays still.
FALLS = [(986, 22, 4), (984, 60, 5), (982, 100, 5), (979, 140, 6), (976, 175, 7), (966, 200, 8), (955, 225, 9),
         (949, 250, 10), (944, 275, 11), (926, 300, 13), (911, 325, 13), (905, 350, 13), (893, 375, 13),
         (882, 400, 15), (875, 425, 16), (868, 450, 18), (868, 475, 26), (870, 500, 28), (862, 525, 32),
         (880, 550, 24), (885, 575, 22), (884, 600, 24), (878, 625, 26), (872, 650, 32), (870, 668, 40)]
BRIDGE = (848, 362, 932, 396)

# The fog bank the painting lays on the channel at the foot of the cliffs: fog drifts on over it.
FOG_ON_WATER = [(165, 206), (300, 194), (430, 196), (430, 365), (330, 368), (250, 305), (175, 262)]

# The sunset sky over the fjord mouth: neither water nor land.
SKY = [(0, 0), (430, 0), (430, 120), (360, 150), (335, 172), (300, 192), (0, 192)]

img = np.asarray(Image.open(BACKDROP).convert('RGB'))
H, W = img.shape[:2]


def poly(points):
    m = np.zeros((H, W), np.uint8)
    cv2.fillPoly(m, [np.array(points, np.int32)], 1)
    return m.astype(bool)


def soft(m, sigma):
    return cv2.GaussianBlur(m.astype(np.float32), (0, 0), sigma)


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def make_marks():
    sys.path.insert(0, str(ROOT / 'tools'))
    import torch
    import town_plot_mattes as tpm
    device = 'cuda' if torch.cuda.is_available() else 'cpu'
    net = tpm.load_network(device)
    source = Image.fromarray(img)
    marks = np.zeros((H, W), np.float32)
    for x0, y0, x1, y1 in OBJECT_BOXES.values():
        wx0, wy0 = max(0, x0 - OBJECT_MARGIN), max(0, y0 - OBJECT_MARGIN)
        wx1, wy1 = min(W, x1 + OBJECT_MARGIN), min(H, y1 + OBJECT_MARGIN)
        alpha = tpm.predict(net, source.crop((wx0, wy0, wx1, wy1)), device)
        keep = np.zeros_like(alpha)
        keep[y0 - wy0:y1 - wy0, x0 - wx0:x1 - wx0] = 1.0
        marks[wy0:wy1, wx0:wx1] = np.maximum(marks[wy0:wy1, wx0:wx1], alpha * keep)
    Image.fromarray(np.clip(marks * 255 + 0.5, 0, 255).astype(np.uint8), 'L').save(MARKS)


def standing_objects():
    if not MARKS.exists():
        make_marks()
    marked = np.asarray(Image.open(MARKS)).astype(np.float32) / 255.0 > 0.4
    x0, y0, x1, y1 = FAR_SHIP
    marked[y0:y1, x0:x1] = True
    return cv2.dilate(marked.astype(np.uint8), np.ones((3, 3), np.uint8), iterations=2).astype(bool)


def water_mask(standing):
    mask = np.full((H, W), cv2.GC_BGD, np.uint8)
    zone = poly(WATER_ZONE)
    mask[zone] = cv2.GC_PR_FGD
    for x0, y0, x1, y1 in OBJECTS:
        box = np.zeros_like(zone)
        box[y0:y1, x0:x1] = True
        mask[box & zone] = cv2.GC_PR_BGD
    mask[poly(STACK) & zone] = cv2.GC_PR_BGD
    for x0, y0, x1, y1 in SURE_WATER:
        mask[y0:y1, x0:x1] = cv2.GC_FGD
    bgd, fgd = np.zeros((1, 65), np.float64), np.zeros((1, 65), np.float64)
    cv2.grabCut(cv2.cvtColor(img, cv2.COLOR_RGB2BGR), mask, None, bgd, fgd, 6, cv2.GC_INIT_WITH_MASK)
    # GrabCut finds the shores; what stands in the water is taken out after, as GrabCut takes
    # its dark paint for water (given as background, it lost most of the channel instead).
    water = np.isin(mask, (cv2.GC_FGD, cv2.GC_PR_FGD)) & zone & ~standing
    # Specks and holes: open, then fill small holes (ripples on dark reflections are water too).
    water = cv2.morphologyEx(water.astype(np.uint8), cv2.MORPH_OPEN, np.ones((3, 3), np.uint8)).astype(bool)
    n, labels, stats, _ = cv2.connectedComponentsWithStats((~water).astype(np.uint8), 8)
    for i in range(1, n):
        if stats[i, cv2.CC_STAT_AREA] < 60:
            water[labels == i] = True
    n, labels, stats, _ = cv2.connectedComponentsWithStats(water.astype(np.uint8), 8)
    for i in range(1, n):
        if stats[i, cv2.CC_STAT_AREA] < 150:
            water[labels == i] = False
    return water


def falls_mask():
    corridor = np.zeros((H, W), np.float32)
    for (xa, ya, wa), (xb, yb, wb) in zip(FALLS, FALLS[1:]):
        steps = max(abs(yb - ya), abs(xb - xa))
        for s in range(steps + 1):
            f = s / max(steps, 1)
            cv2.circle(corridor, (int(round(xa + (xb - xa) * f)), int(round(ya + (yb - ya) * f))),
                       int(round(wa + (wb - wa) * f)), 1.0, -1)
    x0, y0, x1, y1 = BRIDGE
    corridor[y0:y1, x0:x1] = 0.0
    # Within the corridor, the falling water is the light, cool paint; the dark rock between streaks stays.
    c = img.astype(np.float32) / 255.0
    lum = c @ np.array([0.3, 0.59, 0.11], np.float32)
    cool = np.clip((c[..., 2] - c[..., 0] + 0.02) / 0.10, 0, 1)
    light = np.clip((lum - 0.30) / 0.20, 0, 1)
    return corridor * light * np.maximum(cool, 0.5)


def main():
    standing = standing_objects()
    water = water_mask(standing)
    falls = falls_mask()
    sky = poly(SKY)
    pad = 40
    zone = cv2.copyMakeBorder(poly(WATER_ZONE).astype(np.uint8), pad, pad, pad, pad, cv2.BORDER_REPLICATE)
    inside = cv2.distanceTransform(zone, cv2.DIST_L2, 5)[pad:-pad, pad:-pad]
    # The sway reaches a pixel or so: keep it two pixels off ships, the jetty and the shore,
    # so their edges never waver with the water.
    kept = cv2.erode(water.astype(np.uint8), np.ones((3, 3), np.uint8), iterations=2).astype(bool)
    r = soft(kept, 1.0) * np.clip(inside / ZONE_FADE, 0, 1)
    g = soft(falls, 0.8)
    # Land is what is neither water nor the sunset sky, so where the water fades out the land
    # fades in; the sky's edge is soft too. Lamps flicker only on land and what stands on it.
    b = (1.0 - r) * (1.0 - soft(sky, 24.0)) * (1.0 - np.clip(g * 1.5, 0, 1))
    # Alpha: how thick the drifting fog is, from the painting's own fog around each spot (the
    # shader's town_mist test): thicker where the painting is foggier, never gone on land. Not the
    # sunset sky, the falls, the open water or what stands in it, each faded out softly so the fog
    # never stops at a line.
    c = img.astype(np.float32) / 255.0
    lum = c @ np.array([0.3, 0.59, 0.11], np.float32)
    spread = c.max(axis=2) - c.min(axis=2)
    painted = smooth(0.26, 0.44, lum) * (1 - smooth(0.10, 0.22, spread)) * smooth(-0.06, 0.02, c[..., 2] - c[..., 0])
    near_standing = cv2.dilate(standing.astype(np.uint8), np.ones((3, 3), np.uint8), iterations=4)
    open_water = soft(water, 14.0) * (1.0 - soft(poly(FOG_ON_WATER), 24.0))
    keep_out = np.maximum.reduce([soft(sky, 24.0), np.clip(soft(falls, 6.0) * 1.5, 0, 1), open_water,
                                  soft(near_standing, 10.0)])
    foggy = soft(painted * (1.0 - keep_out), 30.0)
    a = np.clip(0.4 + foggy * 2.5, 0, 1) * (1.0 - keep_out)
    out = np.stack([r, g, b, (1.0 + 254.0 * a) / 255.0], axis=2)
    Image.fromarray(np.clip(out * 255.0 + 0.5, 0, 255).astype(np.uint8), 'RGBA').save(OUT, optimize=True)
    print('water %.1f%%, falls %.2f%%, fog over half %.1f%%' % (water.mean() * 100, (falls > 0.3).mean() * 100,
                                                             (a > 0.5).mean() * 100))


if __name__ == '__main__':
    main()
