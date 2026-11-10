"""Says what each unit's small icon shows: a head-and-shoulders close-up for every unit.

    python tools/build_unit_bust_regions.py

Writes content/unit_bust_regions.json, which UnitPortraitTexture.bust_for_unit reads:

- "icons": units with a painted close-up in art/units/icon_busts (beasts, winged and plant
  creatures, war machines: tools/build_unit_icon_busts.py). The icon is that texture.
- "regions": every other unit, with the rectangle [x, y, width, height] of its portrait
  (res://art/units/portraits, 384x512) the icon shows.

The whole figure shrunk to an icon is unreadable, so a standing figure gets a square of
BUST_SIDE of its height: centred on the body's middle band and starting just above the head,
which is the first solid row in a narrow column over the body (a weapon raised beside the head
does not count).

A unit whose box is wider than WIDE times its height, or wide where a head would be, is no
standing figure and the rule cannot find its head. Such a unit needs a painted close-up; until
it has one it shows whole, and the tool names it. FORCE_BUST lists soldiers the two tests take
for creatures (a wide pose, a big shield); OVERRIDES keeps rectangles set by hand.
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "content/unit_art_manifest.json"
ICONS = ROOT / "art/units/icon_busts"
OUT = ROOT / "content/unit_bust_regions.json"
WIDE = 1.2
HEAD_WIDTH = 0.40
BUST_SIDE = 0.36
FORCE_BUST = {
    "unit_embercourt_cinderseal_bombardiers",
    "unit_mireclaw_bogplate_maulers_veteran",
    "unit_mirror_duelist",
    "unit_neutral_scrapbow_teams",
    "unit_neutral_tunnel_lanterns",
    "unit_sunvault_shard_wardens",
}
OVERRIDES: dict[str, list[int]] = {}


def region(path: Path, force_bust: bool) -> tuple[list[int], str]:
    image = Image.open(path).convert("RGBA")
    alpha = np.asarray(image.getchannel("A"), dtype=np.float32) / 255.0
    ys, xs = np.where(alpha > 0.3)
    x0, x1, y0, y1 = int(xs.min()), int(xs.max()) + 1, int(ys.min()), int(ys.max()) + 1
    width, height = x1 - x0, y1 - y0
    whole = [x0, y0, width, height]
    if width / height > WIDE and not force_bust:
        return whole, "whole"
    band = alpha[y0 + int(height * 0.30): y0 + int(height * 0.62), x0:x1]
    columns = band.sum(axis=0)
    centre = x0 + float((columns * np.arange(width)).sum() / max(float(columns.sum()), 1e-6))
    half = max(6, int(height * 0.07))
    low, high = int(max(x0, centre - half)), int(min(x1, centre + half))
    column = alpha[y0:y1, low:high].mean(axis=1)
    head_top = y0
    for index, value in enumerate(column):
        if value > 0.45:
            head_top = y0 + index
            break
    rows = alpha[head_top: head_top + max(4, int(height * 0.09)), x0:x1]
    if float((rows > 0.3).sum(axis=1).mean()) / height > HEAD_WIDTH and not force_bust:
        return whole, "whole"
    side = int(height * BUST_SIDE)
    top = int(max(0, head_top - height * 0.03))
    left = int(round(centre - side / 2))
    left = max(0, min(image.size[0] - side, left))
    top = max(0, min(image.size[1] - side, top))
    return [left, top, side, side], "bust"


def main() -> None:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    regions: dict[str, list[int]] = {}
    icons: dict[str, str] = {}
    shown_whole: list[str] = []
    for entry in manifest["items"]:
        portrait = str(entry.get("portrait", ""))
        if not portrait.startswith("res://"):
            continue
        unit_id = str(entry["unit_id"])
        if (ICONS / f"{unit_id}.png").exists():
            icons[unit_id] = f"res://art/units/icon_busts/{unit_id}.png"
            continue
        if unit_id in OVERRIDES:
            regions[unit_id] = OVERRIDES[unit_id]
            continue
        regions[unit_id], kind = region(ROOT / portrait.removeprefix("res://"), unit_id in FORCE_BUST)
        if kind == "whole":
            shown_whole.append(unit_id)
    # One unit a line, so a hand edit is one line of a diff.
    icon_lines = [f"  {json.dumps(unit_id)}: {json.dumps(path)}" for unit_id, path in sorted(icons.items())]
    region_lines = [f"  {json.dumps(unit_id)}: {json.dumps(box)}" for unit_id, box in sorted(regions.items())]
    head = [
        "{",
        ' "schema_version": 2,',
        ' "generator": "tools/build_unit_bust_regions.py",',
        ' "source": "content/unit_art_manifest.json portraits and art/units/icon_busts",',
    ]
    text = (
        "\n".join(head) + '\n "icons": {\n' + ",\n".join(icon_lines) + '\n },\n "regions": {\n' + ",\n".join(region_lines) + "\n }\n}\n"
    )
    json.loads(text)
    OUT.write_text(text, encoding="utf-8", newline="\n")
    print(f"{OUT.relative_to(ROOT)}: {len(icons)} painted close-ups, {len(regions)} portrait crops")
    if shown_whole:
        print(f"{len(shown_whole)} units still show whole and need a painted close-up: {', '.join(shown_whole)}")


if __name__ == "__main__":
    main()
