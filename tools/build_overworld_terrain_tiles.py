#!/usr/bin/env python3
"""Build checked-in overworld terrain tiles from generated source art.

The runtime renderer consumes 64x64 base, edge, and road overlay PNGs. This
builder keeps that contract, but derives the pixels from the generated
overworld terrain sheets created for task 10184 instead of drawing another
synthetic local tile style.
"""

from __future__ import annotations

from dataclasses import dataclass
import os
from pathlib import Path
from typing import Iterable

try:
    from PIL import Image, ImageDraw, ImageEnhance, ImageFilter
except ImportError as exc:  # pragma: no cover - tool dependency guard
    raise SystemExit("Pillow is required to rebuild overworld terrain tiles.") from exc


ROOT = Path(__file__).resolve().parents[1]
SOURCE_ROOT = Path(
    os.environ.get(
        "OVERWORLD_TERRAIN_SOURCE_ROOT",
        "/root/.openclaw/workspace/tasks/10184/artifacts/overworld-assets-20260419/processed/terrain",
    )
)
OUT = ROOT / "art" / "overworld" / "runtime" / "terrain_tiles"
SIZE = 64
SOURCE_TILE_SIZE = 64

SOURCE_IMAGES = {
    "grasslands": SOURCE_ROOT / "grasslands.png",
    "forest": SOURCE_ROOT / "forest.png",
    "mire": SOURCE_ROOT / "mire.png",
    "highland": SOURCE_ROOT / "highland.png",
}


@dataclass(frozen=True)
class Grade:
    brightness: float = 1.0
    contrast: float = 1.0
    saturation: float = 1.0
    tint: tuple[int, int, int] | None = None
    tint_strength: float = 0.0


@dataclass(frozen=True)
class BaseTileSpec:
    output: str
    source: str
    grid: tuple[int, int]
    crop_size: int = 92
    grade: Grade = Grade()


BASE_TILE_SPECS = (
    BaseTileSpec("grass_open", "grasslands", (5, 1), 88, Grade(1.04, 1.04, 1.08, (94, 137, 66), 0.08)),
    BaseTileSpec("grass_field", "grasslands", (12, 5), 92, Grade(1.03, 1.06, 1.10, (108, 151, 70), 0.08)),
    BaseTileSpec("grass_worn", "grasslands", (10, 5), 94, Grade(0.99, 1.06, 0.98, (128, 122, 76), 0.10)),
    BaseTileSpec("plains_open", "grasslands", (16, 4), 72, Grade(1.04, 1.04, 0.92, (138, 140, 77), 0.20)),
    BaseTileSpec("plains_dry", "grasslands", (14, 10), 72, Grade(1.05, 1.08, 0.84, (161, 144, 79), 0.26)),
    BaseTileSpec("plains_worn", "grasslands", (15, 6), 72, Grade(1.02, 1.07, 0.82, (145, 127, 80), 0.22)),
    BaseTileSpec("forest_canopy", "forest", (0, 8), 90, Grade(0.92, 1.10, 1.08, (42, 75, 45), 0.12)),
    BaseTileSpec("forest_copse", "forest", (15, 8), 92, Grade(0.96, 1.08, 1.06, (50, 87, 51), 0.10)),
    BaseTileSpec("forest_edge", "forest", (10, 6), 94, Grade(1.00, 1.06, 1.04, (71, 97, 55), 0.12)),
    BaseTileSpec("mire_reeds", "mire", (17, 5), 92, Grade(0.95, 1.10, 1.02, (69, 83, 55), 0.12)),
    BaseTileSpec("mire_mud", "mire", (14, 9), 84, Grade(0.92, 1.10, 0.88, (66, 57, 41), 0.16)),
    BaseTileSpec("mire_pool", "mire", (13, 7), 84, Grade(0.96, 1.08, 1.00, (56, 86, 83), 0.16)),
    BaseTileSpec("swamp_deep", "mire", (18, 8), 94, Grade(0.82, 1.14, 0.96, (38, 57, 43), 0.22)),
    BaseTileSpec("swamp_mud", "mire", (15, 9), 92, Grade(0.84, 1.12, 0.88, (48, 49, 36), 0.20)),
    BaseTileSpec("swamp_pool", "mire", (0, 8), 94, Grade(0.88, 1.12, 0.96, (42, 72, 67), 0.20)),
    BaseTileSpec("hills_slope", "highland", (6, 4), 94, Grade(1.02, 1.08, 0.96, (118, 104, 73), 0.12)),
    BaseTileSpec("hills_scrub", "highland", (17, 7), 76, Grade(1.00, 1.08, 0.98, (104, 99, 67), 0.14)),
    BaseTileSpec("hills_ridgelet", "highland", (19, 10), 76, Grade(0.98, 1.12, 0.92, (104, 93, 69), 0.12)),
    BaseTileSpec("ridge_ridge", "highland", (10, 1), 98, Grade(0.96, 1.16, 0.86, (95, 88, 78), 0.10)),
    BaseTileSpec("ridge_scree", "highland", (15, 8), 76, Grade(0.92, 1.16, 0.78, (92, 89, 83), 0.18)),
    BaseTileSpec("ridge_pass", "highland", (19, 11), 76, Grade(1.00, 1.08, 0.88, (123, 106, 70), 0.14)),
    BaseTileSpec("highland_plateau", "highland", (18, 9), 76, Grade(1.04, 1.08, 0.94, (128, 112, 72), 0.13)),
    BaseTileSpec("highland_scrub", "highland", (18, 8), 76, Grade(1.00, 1.10, 0.92, (105, 99, 66), 0.15)),
    BaseTileSpec("highland_pass", "highland", (15, 11), 76, Grade(1.04, 1.08, 0.88, (136, 116, 74), 0.16)),
)

EDGE_SPECS = {
    "grasslands": ("grasslands", (5, 1), Grade(1.03, 1.08, 1.04, (91, 126, 63), 0.12), 92),
    "forest": ("forest", (0, 8), Grade(0.90, 1.14, 1.08, (32, 65, 39), 0.16), 132),
    "mire": ("mire", (17, 7), Grade(0.86, 1.14, 0.96, (43, 65, 50), 0.16), 118),
    "highland": ("highland", (17, 3), Grade(0.98, 1.12, 0.88, (105, 93, 64), 0.14), 106),
}

ROAD_DIRECTIONS = {
    "n": (32.0, -2.0),
    "e": (66.0, 32.0),
    "s": (32.0, 66.0),
    "w": (-2.0, 32.0),
    "ne": (66.0, -2.0),
    "se": (66.0, 66.0),
    "sw": (-2.0, 66.0),
    "nw": (-2.0, -2.0),
}


def load_source(name: str) -> Image.Image:
    path = SOURCE_IMAGES[name]
    if not path.exists():
        raise SystemExit(f"Missing generated terrain source: {path}")
    return Image.open(path).convert("RGB")


def wrapped_crop(image: Image.Image, center: tuple[float, float], size: int) -> Image.Image:
    width, height = image.size
    left = int(round(center[0] - (size / 2)))
    top = int(round(center[1] - (size / 2)))
    tiled = Image.new("RGB", (width * 3, height * 3))
    for ty in range(3):
        for tx in range(3):
            tiled.paste(image, (tx * width, ty * height))
    return tiled.crop((left + width, top + height, left + width + size, top + height + size))


def crop_grid_tile(source_name: str, grid: tuple[int, int], crop_size: int) -> Image.Image:
    source = load_source(source_name)
    center = ((grid[0] * SOURCE_TILE_SIZE) + (SOURCE_TILE_SIZE / 2), (grid[1] * SOURCE_TILE_SIZE) + (SOURCE_TILE_SIZE / 2))
    crop = wrapped_crop(source, center, crop_size)
    return crop.resize((SIZE, SIZE), Image.Resampling.LANCZOS)


def blend_rgb(left: tuple[int, int, int], right: tuple[int, int, int], amount: float) -> tuple[int, int, int]:
    return tuple(int(round((left[index] * (1.0 - amount)) + (right[index] * amount))) for index in range(3))


def soften_tile_edges(image: Image.Image, width: int = 8) -> Image.Image:
    result = image.convert("RGB").copy()
    pixels = result.load()
    max_x = result.width - 1
    max_y = result.height - 1
    for offset in range(width):
        amount = ((width - offset) / float(width)) * 0.55
        for y in range(result.height):
            left = pixels[offset, y]
            right = pixels[max_x - offset, y]
            average = tuple((left[channel] + right[channel]) // 2 for channel in range(3))
            pixels[offset, y] = blend_rgb(left, average, amount)
            pixels[max_x - offset, y] = blend_rgb(right, average, amount)
        for x in range(result.width):
            top = pixels[x, offset]
            bottom = pixels[x, max_y - offset]
            average = tuple((top[channel] + bottom[channel]) // 2 for channel in range(3))
            pixels[x, offset] = blend_rgb(top, average, amount)
            pixels[x, max_y - offset] = blend_rgb(bottom, average, amount)
    return result


def apply_grade(image: Image.Image, grade: Grade) -> Image.Image:
    result = image.convert("RGB")
    if grade.saturation != 1.0:
        result = ImageEnhance.Color(result).enhance(grade.saturation)
    if grade.contrast != 1.0:
        result = ImageEnhance.Contrast(result).enhance(grade.contrast)
    if grade.brightness != 1.0:
        result = ImageEnhance.Brightness(result).enhance(grade.brightness)
    if grade.tint is not None and grade.tint_strength > 0.0:
        tint = Image.new("RGB", result.size, grade.tint)
        result = Image.blend(result, tint, grade.tint_strength)
    return result.filter(ImageFilter.UnsharpMask(radius=0.7, percent=55, threshold=3))


def save_rgba(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.convert("RGBA").save(path)


def build_base_tiles() -> None:
    for spec in BASE_TILE_SPECS:
        tile = crop_grid_tile(spec.source, spec.grid, spec.crop_size)
        tile = soften_tile_edges(tile)
        tile = apply_grade(tile, spec.grade)
        save_rgba(tile, OUT / "base" / f"{spec.output}.png")


def directional_distance(direction: str, x: int, y: int) -> int:
    if direction == "n":
        return y
    if direction == "s":
        return SIZE - 1 - y
    if direction == "w":
        return x
    if direction == "e":
        return SIZE - 1 - x
    raise ValueError(f"Unsupported edge direction: {direction}")


def edge_alpha(direction: str, x: int, y: int, max_alpha: int, width: int = 15) -> int:
    distance = directional_distance(direction, x, y)
    if distance >= width:
        return 0
    falloff = 1.0 - (distance / float(width))
    secondary = 1.0
    if direction in ("n", "s"):
        secondary = 0.88 + (0.12 * ((x * 37 + y * 11) % 7) / 6.0)
    else:
        secondary = 0.88 + (0.12 * ((x * 13 + y * 41) % 7) / 6.0)
    return int(round(max_alpha * (falloff**1.45) * secondary))


def build_edge_overlays() -> None:
    for group, (source_name, grid, grade, max_alpha) in EDGE_SPECS.items():
        texture = crop_grid_tile(source_name, grid, 92)
        texture = apply_grade(soften_tile_edges(texture), grade).convert("RGBA")
        pixels = texture.load()
        for direction in ("n", "e", "s", "w"):
            overlay = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
            overlay_pixels = overlay.load()
            for y in range(SIZE):
                for x in range(SIZE):
                    alpha = edge_alpha(direction, x, y, max_alpha)
                    if alpha <= 0:
                        continue
                    r, g, b, _a = pixels[x, y]
                    overlay_pixels[x, y] = (r, g, b, alpha)
            save_rgba(overlay, OUT / "edges" / f"{group}_edge_{direction}.png")


def make_mask_line(end: tuple[float, float], width: float, center_radius: float = 0.0, offset_y: float = 0.0) -> Image.Image:
    scale = 4
    mask = Image.new("L", (SIZE * scale, SIZE * scale), 0)
    draw = ImageDraw.Draw(mask)
    start = (32.0 * scale, (32.0 + offset_y) * scale)
    scaled_end = (end[0] * scale, (end[1] + offset_y) * scale)
    draw.line((start, scaled_end), fill=255, width=max(1, int(round(width * scale))))
    if center_radius > 0.0:
        radius = center_radius * scale
        draw.ellipse((start[0] - radius, start[1] - radius, start[0] + radius, start[1] + radius), fill=255)
    return mask.resize((SIZE, SIZE), Image.Resampling.LANCZOS)


def make_mask_circle(radius: float, offset_y: float = 0.0) -> Image.Image:
    scale = 4
    mask = Image.new("L", (SIZE * scale, SIZE * scale), 0)
    draw = ImageDraw.Draw(mask)
    center = (32.0 * scale, (32.0 + offset_y) * scale)
    scaled_radius = radius * scale
    draw.ellipse(
        (
            center[0] - scaled_radius,
            center[1] - scaled_radius,
            center[0] + scaled_radius,
            center[1] + scaled_radius,
        ),
        fill=255,
    )
    return mask.resize((SIZE, SIZE), Image.Resampling.LANCZOS)


def scaled_mask(mask: Image.Image, alpha: int) -> Image.Image:
    return mask.point(lambda value: int((value * alpha) / 255))


def composite_color(canvas: Image.Image, color: tuple[int, int, int], mask: Image.Image, alpha: int) -> None:
    layer = Image.new("RGBA", (SIZE, SIZE), (*color, 0))
    layer.putalpha(scaled_mask(mask, alpha))
    canvas.alpha_composite(layer)


def composite_texture(canvas: Image.Image, texture: Image.Image, mask: Image.Image, alpha: int) -> None:
    layer = texture.convert("RGBA")
    layer.putalpha(scaled_mask(mask, alpha))
    canvas.alpha_composite(layer)


def road_material() -> Image.Image:
    source = load_source("grasslands")
    road_centers = (
        (8 * SOURCE_TILE_SIZE + 32, 2 * SOURCE_TILE_SIZE + 32),
        (18 * SOURCE_TILE_SIZE + 32, 3 * SOURCE_TILE_SIZE + 32),
        (8 * SOURCE_TILE_SIZE + 32, 8 * SOURCE_TILE_SIZE + 32),
        (19 * SOURCE_TILE_SIZE + 32, 8 * SOURCE_TILE_SIZE + 32),
    )
    swatches = [wrapped_crop(source, center, 80).resize((SIZE, SIZE), Image.Resampling.LANCZOS) for center in road_centers]
    material = Image.blend(swatches[0], swatches[1], 0.35)
    material = Image.blend(material, swatches[2], 0.25)
    material = Image.blend(material, swatches[3], 0.20)
    material = apply_grade(material, Grade(1.06, 1.12, 0.72, (154, 118, 77), 0.36))
    return soften_tile_edges(material, 6)


def road_layer(kind: str, material: Image.Image) -> Image.Image:
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    if kind == "center":
        shadow = make_mask_circle(6.8, 1.0)
        edge = make_mask_circle(5.6)
        core = make_mask_circle(4.4)
        highlight = make_mask_circle(1.4)
    else:
        end = ROAD_DIRECTIONS[kind]
        shadow = make_mask_line(end, 10.5, 4.5, 0.9)
        edge = make_mask_line(end, 8.2, 3.8)
        core = make_mask_line(end, 5.9, 2.9)
        highlight = make_mask_line(end, 1.25, 0.8)
    composite_color(canvas, (46, 34, 24), shadow, 82)
    composite_color(canvas, (89, 64, 42), edge, 156)
    composite_texture(canvas, material, core, 202)
    composite_color(canvas, (218, 185, 122), highlight, 64)
    return canvas.filter(ImageFilter.UnsharpMask(radius=0.45, percent=35, threshold=2))


def build_road_overlays() -> None:
    material = road_material()
    save_rgba(road_layer("center", material), OUT / "roads" / "road_dirt_center.png")
    for kind in ROAD_DIRECTIONS:
        save_rgba(road_layer(kind, material), OUT / "roads" / f"road_dirt_{kind}.png")


def assert_sources_exist(paths: Iterable[Path]) -> None:
    missing = [path for path in paths if not path.exists()]
    if missing:
        formatted = "\n".join(str(path) for path in missing)
        raise SystemExit(f"Missing generated terrain source art:\n{formatted}")


def build() -> None:
    assert_sources_exist(SOURCE_IMAGES.values())
    build_base_tiles()
    build_edge_overlays()
    build_road_overlays()


if __name__ == "__main__":
    build()
