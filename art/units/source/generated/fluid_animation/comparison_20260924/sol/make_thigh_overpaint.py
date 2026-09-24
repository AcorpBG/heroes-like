"""Pose-only paintover guide; generated output, never this guide, is shippable."""
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
target = Image.open(HERE / "move_near_v9.png").convert("RGBA")
guide = target.copy()
d = ImageDraw.Draw(guide)
# The thigh must originate from the pouch-side/image-left hip and occlude the
# central green-and-cream cloth. This rough brown mass shows the missing plane.
for polygon in (
    [(314, 293), (360, 283), (418, 299), (453, 320), (461, 358), (419, 362), (370, 338), (330, 329)],
    [(1005, 294), (1053, 283), (1111, 319), (1150, 351), (1164, 389), (1125, 394), (1061, 348), (1017, 332)],
    [(327, 855), (378, 843), (432, 872), (468, 920), (484, 965), (447, 969), (389, 911), (340, 896)],
    [(1016, 851), (1063, 840), (1115, 887), (1140, 945), (1139, 999), (1101, 996), (1061, 927), (1024, 891)],
):
    d.polygon(polygon, fill=(92, 67, 48, 255))
    d.line(polygon + [polygon[0]], fill=(131, 96, 64, 255), width=4)
guide.save(HERE / "move_near_v9_overpaint_guide.png")
