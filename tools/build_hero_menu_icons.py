"""Cuts the hero menu's small icons out of their painted sheets.

    python tools/build_hero_menu_icons.py

Sources (art/ui/source/generated/hero_menu_20261110, archived; see its
provenance.json): glyphs.png, a 4 by 3 sheet of gold emblems (the four pages,
the four command stats, the three meters, a laurel); slots.png, a 5 by 2 sheet
of the outlines empty artifact slots show; body.png, the figure the artifact
slots stand on. Each icon is cut from its cell, trimmed to what is painted,
centred on a square and written to art/ui/runtime/hero_menu.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art" / "ui" / "source" / "generated" / "hero_menu_20261110"
RUNTIME = ROOT / "art" / "ui" / "runtime" / "hero_menu"

GLYPHS = [
    ["page_army", "page_artifacts", "page_specialties", "page_spells"],
    ["stat_attack", "stat_defense", "stat_power", "stat_knowledge"],
    ["meter_movement", "meter_mana", "meter_scouting", "level_laurel"],
]
SLOTS = [
    ["slot_head", "slot_neck", "slot_cloak", "slot_armor", "slot_hand"],
    ["slot_ring", "slot_boots", "slot_banner", "slot_trinket", "slot_backpack"],
]
GLYPH_EDGE = 96
SLOT_EDGE = 72
BODY_HEIGHT = 520
# Paint fainter than this is the sheet's haze, not the icon.
ALPHA_FLOOR = 24


def cut_sheet(path: Path, names: list[list[str]], edge: int) -> None:
    sheet = Image.open(path).convert("RGBA")
    rows = len(names)
    columns = len(names[0])
    cell_width = sheet.width / columns
    cell_height = sheet.height / rows
    for row, row_names in enumerate(names):
        for column, name in enumerate(row_names):
            cell = sheet.crop((
                round(column * cell_width), round(row * cell_height),
                round((column + 1) * cell_width), round((row + 1) * cell_height),
            ))
            write_icon(cell, name, edge)


def write_icon(cell: Image.Image, name: str, edge: int) -> None:
    box = cell.getchannel("A").point(lambda value: 255 if value >= ALPHA_FLOOR else 0).getbbox()
    if box is None:
        raise SystemExit(f"{name}: nothing painted in its cell")
    icon = cell.crop(box)
    side = max(icon.size)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.alpha_composite(icon, ((side - icon.width) // 2, (side - icon.height) // 2))
    # A little air round the icon, so a frame never touches it.
    inner = round(edge * 0.92)
    square = square.resize((inner, inner), Image.LANCZOS)
    out = Image.new("RGBA", (edge, edge), (0, 0, 0, 0))
    out.alpha_composite(square, ((edge - inner) // 2, (edge - inner) // 2))
    out.save(RUNTIME / f"{name}.png")


def cut_body(path: Path) -> None:
    body = Image.open(path).convert("RGBA")
    box = body.getchannel("A").point(lambda value: 255 if value >= ALPHA_FLOOR else 0).getbbox()
    body = body.crop(box)
    width = round(body.width * BODY_HEIGHT / body.height)
    body = body.resize((width, BODY_HEIGHT), Image.LANCZOS)
    # The painting is a bright orange; the menu wants a quiet bronze shape with
    # the lighter edge kept, so the brightness alone is carried over.
    light = body.convert("L")
    low, high = light.getextrema()
    span = max(1, high - low)
    dark, pale = (58, 46, 32), (206, 164, 96)
    bronze = Image.merge("RGB", [
        light.point(lambda value, a=dark[i], b=pale[i]: round(a + (b - a) * (value - low) / span))
        for i in range(3)
    ])
    bronze.putalpha(body.getchannel("A"))
    bronze.save(RUNTIME / "body.png")


def main() -> None:
    RUNTIME.mkdir(parents=True, exist_ok=True)
    cut_sheet(SOURCE / "glyphs.png", GLYPHS, GLYPH_EDGE)
    cut_sheet(SOURCE / "slots.png", SLOTS, SLOT_EDGE)
    cut_body(SOURCE / "body.png")
    print(f"wrote {sum(len(row) for row in GLYPHS) + sum(len(row) for row in SLOTS) + 1} icons to {RUNTIME}")


if __name__ == "__main__":
    main()
