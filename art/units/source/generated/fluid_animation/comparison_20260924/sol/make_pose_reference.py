"""Draw pose-only geometry for the image generator, never a shipped sprite."""
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).with_name("near_leg_geometry_reference.png")
im = Image.new("RGBA", (768, 768), "white")
d = ImageDraw.Draw(im)
# Far leg is behind the body. It stays at image-left while near leg strides right.
d.line([(360, 322), (254, 472), (186, 642)], fill=(42, 88, 205), width=64, joint="curve")
d.ellipse((145, 625, 236, 681), fill=(42, 88, 205))
# Torso and cream central tabard establish the overlap plane.
d.polygon([(320, 125), (433, 125), (453, 340), (290, 340)], fill=(66, 125, 78))
d.polygon([(340, 322), (429, 322), (455, 493), (305, 493)], fill=(229, 217, 178))
d.ellipse((316, 303, 407, 385), fill=(48, 90, 63))
# Near leg begins at the image-left hip and is IN FRONT of the tabard.
d.line([(342, 344), (465, 448), (561, 563)], fill=(199, 67, 42), width=77, joint="curve")
d.ellipse((523, 548, 660, 610), fill=(199, 67, 42))
# Small orange arrow indicates the forward direction only.
d.line([(535, 687), (656, 687)], fill=(234, 158, 37), width=19)
d.polygon([(670, 687), (630, 662), (630, 712)], fill=(234, 158, 37))
im.save(OUT)
print(OUT)
