"""Pack the portal network sprites (docs/portal-networks.md).

Each source painting keeps its magic in one key colour (pure magenta). The
runtime sprite, mapobj_<name>.png on the shared 512px object canvas, keeps
only the solid stonework: the keyed magic inside a Wayring's ring or a
Waygate's arch becomes a dark empty opening, a Wayfall's beam becomes open
air, and light the painter spilled on stone becomes plain stone.

The painted magic itself becomes white-light effect layers on the same
canvas (mapobj_<name>_vortex/_spill, mapobj_wayfall_beam/_splash), which the
overworld tints with the network colour and animates
(scenes/overworld/OverworldPortalFx.gd). The tool also measures where the
magic was painted and writes art/overworld/portal_network_fx.json, which
places and names those layers.

Packing matches the other generated object sprites: alpha above 60 sets the
crop box, then an aspect-preserving resize, centred and bottom-aligned.
"""

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "art/overworld/source/generated/resource_sites/portal_networks_20261008"
RUNTIME_DIR = ROOT / "art/overworld/runtime/objects/map_objects/distinct"
FX_PATH = ROOT / "art/overworld/portal_network_fx.json"
NAMES = ("wayring", "waygate", "wayfall")
CANVAS = 512
MAX_EXTENT = 300
BOTTOM = 390
# Packed canvas rows where the painted magic stops being the portal itself:
# below them is light spilled on the plinth (Wayring, Waygate) or the splash
# on the landing dais (Wayfall).
VORTEX_FLOOR = 310
BEAM_FLOOR = 255


def key_weight(rgb: np.ndarray) -> np.ndarray:
    """How magenta each pixel is: red and blue alike and well above green."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    lift = np.clip((np.minimum(r, b) - g - 0.04) / 0.25, 0.0, 1.0)
    balance = np.clip(1.0 - (np.abs(r - b) - 0.08) / 0.25, 0.0, 1.0)
    return lift * balance


def pack(image: Image.Image, box: tuple[int, int, int, int]) -> Image.Image:
    cropped = image.crop(box)
    scale = MAX_EXTENT / max(cropped.size)
    size = (max(1, round(cropped.width * scale)), max(1, round(cropped.height * scale)))
    resized = cropped.resize(size, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    canvas.paste(resized, ((CANVAS - size[0]) // 2, BOTTOM - size[1]))
    return canvas


def to_image(array: np.ndarray) -> Image.Image:
    return Image.fromarray(np.clip(array * 255.0 + 0.5, 0, 255).astype(np.uint8), "RGBA")


def near(mask: np.ndarray, radius: int) -> np.ndarray:
    image = Image.fromarray((mask * 255).astype(np.uint8), "L").filter(ImageFilter.MaxFilter(radius * 2 + 1))
    return np.asarray(image) > 0


def opening_of(mask: np.ndarray, floor: int) -> np.ndarray:
    """The magic region joined to the opening's centre, with its gaps filled.

    Light the painter spilled on the plinth or pillars is not joined to it, so
    it stays stone."""
    rows, cols = np.nonzero(mask[:floor])
    seed = (int(np.median(rows)), int(np.median(cols)))
    region = np.zeros_like(mask)
    stack = [seed]
    while stack:
        y, x = stack.pop()
        if y < 0 or y >= floor or x < 0 or x >= CANVAS or region[y, x] or not mask[y, x]:
            continue
        region[y, x] = True
        stack.extend(((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)))
    filled = np.zeros_like(region)
    for row in range(floor):
        xs = np.nonzero(region[row])[0]
        if xs.size:
            filled[row, xs.min():xs.max() + 1] = True
    return filled


def stonework(name: str, packed: Image.Image) -> tuple[Image.Image, np.ndarray, dict]:
    """The solid sprite, the packed magic weight and the magic's effect layers."""
    pixels = np.asarray(packed, dtype=np.float32) / 255.0
    rgb, alpha = pixels[..., :3], pixels[..., 3]
    painted = alpha > 0.0
    keyed = key_weight(rgb) * painted
    brightness = rgb.mean(axis=2)
    # The magic as white light: the painted shading survives the network tint.
    light = np.clip(brightness * 1.35, 0.0, 1.0)
    # White-hot cores and sparks were painted without the key hue; near the
    # magic, anything that bright is magic too. Stone highlights stay darker.
    hot = np.clip((brightness - 0.62) / 0.18, 0.0, 1.0) * near(keyed > 0.2, 12) * painted
    weight = np.maximum(keyed, hot)
    floor = BEAM_FLOOR if name == "wayfall" else VORTEX_FLOOR
    opening = np.zeros_like(painted) if name == "wayfall" else opening_of(weight > 0.35, floor)
    weight = np.where(opening, 1.0, weight)
    # Light the painter spilled on the stone leaves a magenta cast: neutral grey.
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    cast = np.clip((np.minimum(r, b) - g - 0.015) / 0.1, 0.0, 1.0) * np.clip(1.0 - (np.abs(r - b) - 0.08) / 0.2, 0.0, 1.0)
    grey = brightness[..., None].repeat(3, axis=2)
    rgb = rgb * (1.0 - cast[..., None]) + grey * cast[..., None]
    stone = grey * 0.6
    if name == "wayfall":
        # Where the beam stood in front of the dais and the splash lit it,
        # plain flat stone: the particles paint the light there.
        stone = grey * 0.18 + np.array([0.3, 0.3, 0.31])
    void = brightness[..., None].repeat(3, axis=2) * 0.06 + np.array([0.03, 0.028, 0.045])
    fill = np.where(opening[..., None], void, stone)
    out = np.empty_like(pixels)
    out[..., :3] = rgb * (1.0 - weight[..., None]) + fill * weight[..., None]
    rows = np.arange(CANVAS)[:, None]
    # A Wayfall's beam is open air, haze included (stone is opaque); everything
    # else keeps its painted shape.
    if name == "wayfall":
        haze = (alpha < 0.95) & near(keyed > 0.1, 10)
        air = np.where(rows < BEAM_FLOOR, np.where(haze, 1.0, weight), haze.astype(np.float32))
        out[..., 3] = alpha * (1.0 - air)
        layers = {
            "beam": light_layer(light, alpha * air),
            "splash": light_layer(light, alpha * weight * (rows >= BEAM_FLOOR) * (1.0 - haze)),
        }
    else:
        out[..., 3] = alpha
        soft_opening = np.asarray(Image.fromarray((opening * 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(1.2)), dtype=np.float32) / 255.0
        layers = {
            "vortex": light_layer(light, alpha * soft_opening),
            "spill": light_layer(light, alpha * weight * (1.0 - opening)),
        }
    return to_image(out), keyed * alpha, layers


def light_layer(light: np.ndarray, coverage: np.ndarray) -> Image.Image:
    layer = np.empty(light.shape + (4,), dtype=np.float32)
    layer[..., 3] = np.clip(coverage, 0.0, 1.0)
    layer[..., :3] = (light * (layer[..., 3] > 0.0))[..., None]
    return to_image(layer)


def band_box(weight: np.ndarray, top: int, bottom: int, threshold: float = 0.35) -> tuple[float, float, float, float]:
    band = np.zeros_like(weight)
    band[top:bottom] = weight[top:bottom]
    ys, xs = np.nonzero(band > threshold)
    return float(xs.min()), float(ys.min()), float(xs.max()), float(ys.max())


def normalized_ellipse(bounds: tuple[float, float, float, float]) -> dict:
    left, top, right, bottom = bounds
    return {
        "center": [round((left + right) / 2 / CANVAS, 4), round((top + bottom) / 2 / CANVAS, 4)],
        "radius": [round((right - left) / 2 / CANVAS, 4), round((bottom - top) / 2 / CANVAS, 4)],
    }


def layer_ids(name: str, roles: tuple) -> dict:
    return {role: f"mapobj_{name}_{role}" for role in roles}


def fx_geometry(magic: dict) -> dict:
    ring = normalized_ellipse(band_box(magic["wayring"], 0, VORTEX_FLOOR))
    gate = normalized_ellipse(band_box(magic["waygate"], 0, VORTEX_FLOOR))
    fall = magic["wayfall"]
    beam_left, beam_top, beam_right, _ = band_box(fall, 0, BEAM_FLOOR)
    core_widths = [np.ptp(np.nonzero(fall[row] > 0.6)[0]) for row in range(int(beam_top) + 20, BEAM_FLOOR - 10) if np.count_nonzero(fall[row] > 0.6) > 1]
    splash = normalized_ellipse(band_box(fall, BEAM_FLOOR, CANVAS))
    return {
        "mapobj_wayring": {"effect": "swirl_disc", "layers": layer_ids("wayring", ("vortex", "spill")), **ring},
        "mapobj_waygate": {"effect": "inward_vortex", "layers": layer_ids("waygate", ("vortex", "spill")), **gate},
        "mapobj_wayfall": {
            "effect": "falling_beam",
            "layers": layer_ids("wayfall", ("beam", "splash")),
            "beam_x": round((beam_left + beam_right) / 2 / CANVAS, 4),
            "beam_half_width": round(float(np.median(core_widths)) / 2 / CANVAS, 4),
            "beam_top": round(beam_top / CANVAS, 4),
            "beam_bottom": splash["center"][1],
            "splash_center": splash["center"],
            "splash_radius": splash["radius"],
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", type=Path, default=RUNTIME_DIR)
    args = parser.parse_args()
    magic = {}
    for name in NAMES:
        source = Image.open(SOURCE_DIR / f"{name}-source.png").convert("RGBA")
        crop = source.getchannel("A").point(lambda v: 255 if v > 60 else 0).getbbox()
        sprite, magic[name], layers = stonework(name, pack(source, crop))
        sprite.save(args.out / f"mapobj_{name}.png", optimize=True)
        for role, layer in layers.items():
            layer.save(args.out / f"mapobj_{name}_{role}.png", optimize=True)
        print(f"{name}: crop {crop} -> {args.out / f'mapobj_{name}.png'}")
    fx = {
        "schema_id": "aurelion_portal_network_fx_v1",
        "source": "tools/pack_portal_network_sprites.py measures the keyed magic of the packed paintings; coordinates are fractions of the 512px object canvas",
        "assets": fx_geometry(magic),
    }
    with FX_PATH.open("w", encoding="utf-8", newline="\n") as handle:
        handle.write(json.dumps(fx, indent=2) + "\n")
    print(f"particle geometry -> {FX_PATH}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
