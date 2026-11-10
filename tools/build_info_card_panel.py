"""Cuts the map's information card frames from their painted source.

    python tools/build_info_card_panel.py

The source (art/ui/source/generated/info_card_20261110/info_card_panel_source.png, 1024 px,
see its provenance.json) is a dark lacquer panel with a thin gold border and four compass
corners. A nine-slice needs small corners, plain edges and an even middle, so the tool keeps the
four corners, takes one strip of each edge and one patch of the middle, and scales them down:

    art/ui/runtime/overworld/info_card.png        the right-click report (corners of 48 px)
    art/ui/runtime/overworld/info_card_small.png  the hover card (corners of 28 px)

FrontierVisualKit.info_card_style reads the corner size from INFO_CARD_CORNER_PX.
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art/ui/source/generated/info_card_20261110/info_card_panel_source.png"
OUT_DIR = ROOT / "art/ui/runtime/overworld"
SOURCE_CORNER = 168   # the ornament and its lines fit inside this square of the source
SOURCE_STRIP = 64     # the width of the edge strip and the side of the middle patch
OUTPUTS = (("info_card.png", 48, 18), ("info_card_small.png", 28, 12))


def nine_slice(source: Image.Image, corner: int, middle: int) -> Image.Image:
    size = source.size[0]
    c, s = SOURCE_CORNER, SOURCE_STRIP
    mid = (size - s) // 2
    total = corner * 2 + middle
    out = Image.new("RGBA", (total, total))

    def put(box, target, where):
        out.paste(source.crop(box).resize(target, Image.LANCZOS), where)

    put((0, 0, c, c), (corner, corner), (0, 0))
    put((size - c, 0, size, c), (corner, corner), (corner + middle, 0))
    put((0, size - c, c, size), (corner, corner), (0, corner + middle))
    put((size - c, size - c, size, size), (corner, corner), (corner + middle, corner + middle))
    put((mid, 0, mid + s, c), (middle, corner), (corner, 0))
    put((mid, size - c, mid + s, size), (middle, corner), (corner, corner + middle))
    put((0, mid, c, mid + s), (corner, middle), (0, corner))
    put((size - c, mid, size, mid + s), (corner, middle), (corner + middle, corner))
    put((mid, mid, mid + s, mid + s), (middle, middle), (corner, corner))
    return out


def main() -> None:
    source = Image.open(SOURCE).convert("RGBA")
    if source.size[0] != source.size[1]:
        raise SystemExit(f"{SOURCE} is not square: {source.size}")
    for name, corner, middle in OUTPUTS:
        card = nine_slice(source, corner, middle)
        card.save(OUT_DIR / name)
        print(f"{name}: {card.size[0]}x{card.size[1]}, corners of {corner} px")


if __name__ == "__main__":
    main()
