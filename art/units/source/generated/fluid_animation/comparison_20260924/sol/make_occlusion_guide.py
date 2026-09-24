"""Mark the intended thigh-over-apron depth on a disposable generator reference."""
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
im = Image.open(HERE / "move_near_v8.png").convert("RGBA")
mark = Image.new("RGBA", im.size, (0, 0, 0, 0))
d = ImageDraw.Draw(mark)
for path in (
    ((335, 284), (372, 313), (428, 340)),
    ((1015, 286), (1062, 331), (1128, 386)),
    ((350, 835), (400, 883), (461, 955)),
    ((1035, 835), (1080, 909), (1108, 1006)),
):
    d.line(path, fill=(232, 35, 33, 220), width=19, joint="curve")
    x, y = path[-1]
    d.ellipse((x - 14, y - 14, x + 14, y + 14), fill=(232, 35, 33, 220))
Image.alpha_composite(im, mark).save(HERE / "move_near_v8_occlusion_guide.png")
