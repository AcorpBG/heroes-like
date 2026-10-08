"""Pack the portal network sprites (docs/portal-networks.md).

Each source painting keeps its magic in one key colour (pure magenta). This
splits it into two runtime layers on the shared 512px object canvas:

- mapobj_<name>.png: the stonework, with the keyed energy removed;
- mapobj_<name>_glow.png: the energy as white light, which the overworld tints
  with the portal's network colour.

It also measures where the energy sits on the packed canvas and writes
art/overworld/portal_network_fx.json, which places the animated particles.

Packing matches the other generated object sprites: alpha above 60 sets the
crop box, then an aspect-preserving resize, centred and bottom-aligned.
"""

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "art/overworld/source/generated/resource_sites/portal_networks_20261008"
RUNTIME_DIR = ROOT / "art/overworld/runtime/objects/map_objects/distinct"
NAMES = ("wayring", "waygate", "wayfall")
CANVAS = 512
MAX_EXTENT = 300
BOTTOM = 390
FX_PATH = ROOT / "art/overworld/portal_network_fx.json"
# Canvas rows where the painted energy stops being the portal itself: below
# them is the light spilled on the plinth (Wayring, Waygate) or the splash on
# the landing dais (Wayfall).
VORTEX_FLOOR = 310
BEAM_FLOOR = 255


def key_weight(rgb: np.ndarray) -> np.ndarray:
    """How magenta each pixel is: red and blue alike and well above green."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    lift = np.clip((np.minimum(r, b) - g - 0.04) / 0.25, 0.0, 1.0)
    balance = np.clip(1.0 - (np.abs(r - b) - 0.08) / 0.25, 0.0, 1.0)
    return lift * balance


def split(source: Image.Image) -> tuple[Image.Image, Image.Image]:
    pixels = np.asarray(source.convert("RGBA"), dtype=np.float32) / 255.0
    rgb, alpha = pixels[..., :3], pixels[..., 3]
    weight = key_weight(rgb)
    # Mean brightness keeps the painted spiral and falloff in the white light.
    value = np.clip(rgb.mean(axis=2) * 1.35, 0.0, 1.0)
    base = np.empty_like(pixels)
    # Keyed light leaves the base: what it covers is drawn by the glow layer.
    neutral = (rgb.mean(axis=2, keepdims=True) * 0.6).repeat(3, axis=2)
    base[..., :3] = rgb * (1.0 - weight[..., None]) + neutral * weight[..., None]
    base[..., 3] = alpha * (1.0 - weight)
    glow = np.empty_like(pixels)
    glow[..., :3] = value[..., None].repeat(3, axis=2)
    glow[..., 3] = alpha * weight
    to_image = lambda array: Image.fromarray(np.clip(array * 255.0 + 0.5, 0, 255).astype(np.uint8), "RGBA")
    return to_image(base), to_image(glow)


def pack(image: Image.Image, box: tuple[int, int, int, int]) -> Image.Image:
    cropped = image.crop(box)
    scale = MAX_EXTENT / max(cropped.size)
    size = (max(1, round(cropped.width * scale)), max(1, round(cropped.height * scale)))
    resized = cropped.resize(size, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    canvas.paste(resized, ((CANVAS - size[0]) // 2, BOTTOM - size[1]))
    return canvas


def energy(glow: Image.Image) -> np.ndarray:
    pixels = np.asarray(glow, dtype=np.float32) / 255.0
    return pixels[..., 3] * pixels[..., 0]


def box(weight: np.ndarray, top: int, bottom: int, threshold: float = 0.35) -> tuple[float, float, float, float]:
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


def fx_geometry(glows: dict) -> dict:
    ring = normalized_ellipse(box(energy(glows["wayring"]), 0, VORTEX_FLOOR))
    gate = normalized_ellipse(box(energy(glows["waygate"]), 0, VORTEX_FLOOR))
    fall = energy(glows["wayfall"])
    beam_left, beam_top, beam_right, _ = box(fall, 0, BEAM_FLOOR)
    core_widths = [np.ptp(np.nonzero(fall[row] > 0.6)[0]) for row in range(int(beam_top) + 20, BEAM_FLOOR - 10) if np.count_nonzero(fall[row] > 0.6) > 1]
    splash = normalized_ellipse(box(fall, BEAM_FLOOR, CANVAS))
    return {
        "mapobj_wayring": {"effect": "orbit", **ring},
        "mapobj_waygate": {"effect": "inward_spiral", **gate},
        "mapobj_wayfall": {
            "effect": "falling_beam",
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
    glows = {}
    for name in NAMES:
        source = Image.open(SOURCE_DIR / f"{name}-source.png").convert("RGBA")
        crop = source.getchannel("A").point(lambda v: 255 if v > 60 else 0).getbbox()
        base, glow = split(source)
        pack(base, crop).save(args.out / f"mapobj_{name}.png", optimize=True)
        glows[name] = pack(glow, crop)
        glows[name].save(args.out / f"mapobj_{name}_glow.png", optimize=True)
        print(f"{name}: crop {crop} -> {args.out / f'mapobj_{name}.png'} (+ _glow)")
    fx = {
        "schema_id": "aurelion_portal_network_fx_v1",
        "source": "tools/pack_portal_network_sprites.py measures the packed glow layers; coordinates are fractions of the 512px object canvas",
        "assets": fx_geometry(glows),
    }
    with FX_PATH.open("w", encoding="utf-8", newline="\n") as handle:
        handle.write(json.dumps(fx, indent=2) + "\n")
    print(f"particle geometry -> {FX_PATH}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
