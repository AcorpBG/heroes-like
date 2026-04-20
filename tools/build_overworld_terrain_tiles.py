#!/usr/bin/env python3
"""Build original, quiet overworld terrain tiles.

The runtime renderer consumes 64x64 base, edge, and road overlay PNGs. This
builder intentionally does not sample the generated terrain source sheets:
those proved too painterly and seam-prone as a per-cell base. The assets here
are local procedural placeholders shaped around the terrain grammar:
restrained biome palettes, quiet multi-scale base variants, jagged transition
pieces, and softened rutted structural road connector overlays.
"""

from __future__ import annotations

from dataclasses import dataclass
import math
import random
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFilter
except ImportError as exc:  # pragma: no cover - tool dependency guard
    raise SystemExit("Pillow is required to rebuild overworld terrain tiles.") from exc


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "art" / "overworld" / "runtime" / "terrain_tiles"
SIZE = 64
SCALE = 4


@dataclass(frozen=True)
class BaseTileSpec:
    output: str
    terrain_family: str
    pattern: str
    base: str
    secondary: str
    detail: str
    accent: str
    seed: int


@dataclass(frozen=True)
class EdgeSpec:
    output: str
    fill: str
    dark: str
    light: str
    width: int
    alpha: int
    seed: int


BASE_TILE_SPECS = (
    BaseTileSpec("grass_open", "grasslands", "field_tufts", "#6d8a47", "#789650", "#58713c", "#a7b765", 101),
    BaseTileSpec("grass_field", "grasslands", "field_tufts", "#748d4a", "#819b52", "#5d7440", "#bec06c", 102),
    BaseTileSpec("grass_worn", "grasslands", "worn_field", "#76854a", "#8a8956", "#665f3d", "#b6a568", 103),
    BaseTileSpec("plains_open", "grasslands", "dry_grass", "#7f914f", "#929758", "#686d3d", "#c7b76b", 111),
    BaseTileSpec("plains_dry", "grasslands", "dry_grass", "#8c8f55", "#a0905c", "#736846", "#d1b06d", 112),
    BaseTileSpec("plains_worn", "grasslands", "worn_field", "#837f4e", "#9a8655", "#695d43", "#c4a56a", 113),
    BaseTileSpec("forest_canopy", "forest", "tree_clusters", "#2f5734", "#38653d", "#19341f", "#5c7944", 201),
    BaseTileSpec("forest_copse", "forest", "tree_clusters", "#345f39", "#3f6c43", "#1f3a24", "#67834e", 202),
    BaseTileSpec("forest_edge", "forest", "tree_edge", "#3e653d", "#507147", "#263e27", "#7a8a54", 203),
    BaseTileSpec("mire_reeds", "mire", "reed_pools", "#42513a", "#56613f", "#28332b", "#76814b", 301),
    BaseTileSpec("mire_mud", "mire", "mud_reeds", "#4c4938", "#5b5540", "#302d27", "#7b704c", 302),
    BaseTileSpec("mire_pool", "mire", "reed_pools", "#3e5547", "#45635b", "#273936", "#6f8450", 303),
    BaseTileSpec("swamp_deep", "mire", "deep_swamp", "#344235", "#41533e", "#1f2b25", "#65734b", 311),
    BaseTileSpec("swamp_mud", "mire", "mud_reeds", "#3e3f31", "#4d4b38", "#272820", "#68664a", 312),
    BaseTileSpec("swamp_pool", "mire", "deep_swamp", "#334a40", "#3f5b55", "#1e302f", "#61704e", 313),
    BaseTileSpec("hills_slope", "highland", "contours", "#716947", "#827752", "#504933", "#aa9762", 401),
    BaseTileSpec("hills_scrub", "highland", "scrub_contours", "#6a6545", "#79724d", "#484633", "#9d9160", 402),
    BaseTileSpec("hills_ridgelet", "highland", "ridge_contours", "#665f42", "#766b4c", "#45402f", "#a09262", 403),
    BaseTileSpec("ridge_ridge", "highland", "ridge_contours", "#625c42", "#706a4f", "#403d32", "#9f9366", 411),
    BaseTileSpec("ridge_scree", "highland", "scree", "#5f5c4b", "#6d6855", "#403f38", "#978c6a", 412),
    BaseTileSpec("ridge_pass", "highland", "worn_contours", "#74694a", "#887952", "#504631", "#b39a64", 413),
    BaseTileSpec("highland_plateau", "highland", "contours", "#756c49", "#867a53", "#504936", "#af9e68", 421),
    BaseTileSpec("highland_scrub", "highland", "scrub_contours", "#6b6747", "#7c7450", "#474636", "#a09566", 422),
    BaseTileSpec("highland_pass", "highland", "worn_contours", "#7b704c", "#907f56", "#554a34", "#baa06a", 423),
)

EDGE_SPECS = {
    "grasslands": EdgeSpec("grasslands", "#526d39", "#354b2a", "#91a75a", 15, 124, 501),
    "forest": EdgeSpec("forest", "#1d3a23", "#102218", "#4d6942", 18, 158, 601),
    "mire": EdgeSpec("mire", "#28392e", "#182720", "#657449", 17, 146, 701),
    "highland": EdgeSpec("highland", "#514a35", "#342f24", "#8f8055", 16, 136, 801),
}

ROAD_DIRECTIONS = {
    "n": (32.0, -3.0),
    "e": (67.0, 32.0),
    "s": (32.0, 67.0),
    "w": (-3.0, 32.0),
    "ne": (67.0, -3.0),
    "se": (67.0, 67.0),
    "sw": (-3.0, 67.0),
    "nw": (-3.0, -3.0),
}


def hex_rgb(value: str) -> tuple[int, int, int]:
    text = value.strip().lstrip("#")
    return int(text[0:2], 16), int(text[2:4], 16), int(text[4:6], 16)


def clamp_channel(value: int) -> int:
    return max(0, min(255, value))


def mix(left: tuple[int, int, int], right: tuple[int, int, int], amount: float) -> tuple[int, int, int]:
    return tuple(clamp_channel(int(round((left[i] * (1.0 - amount)) + (right[i] * amount)))) for i in range(3))


def jitter(color: tuple[int, int, int], amount: int, rng: random.Random) -> tuple[int, int, int]:
    return tuple(clamp_channel(channel + rng.randint(-amount, amount)) for channel in color)


def add_rgb(color: tuple[int, int, int], delta: float) -> tuple[int, int, int]:
    return tuple(clamp_channel(int(round(channel + delta))) for channel in color)


def smoothstep(value: float) -> float:
    clamped = max(0.0, min(1.0, value))
    return clamped * clamped * (3.0 - (2.0 * clamped))


def tileable_noise(size: int, cells: int, seed: int) -> list[float]:
    rng = random.Random(seed)
    grid = [[rng.random() for _x in range(cells)] for _y in range(cells)]
    values: list[float] = []
    for y in range(size):
        fy = (float(y) / float(size)) * float(cells)
        y0 = int(math.floor(fy)) % cells
        y1 = (y0 + 1) % cells
        ty = smoothstep(fy - math.floor(fy))
        for x in range(size):
            fx = (float(x) / float(size)) * float(cells)
            x0 = int(math.floor(fx)) % cells
            x1 = (x0 + 1) % cells
            tx = smoothstep(fx - math.floor(fx))
            top = (grid[y0][x0] * (1.0 - tx)) + (grid[y0][x1] * tx)
            bottom = (grid[y1][x0] * (1.0 - tx)) + (grid[y1][x1] * tx)
            values.append((top * (1.0 - ty)) + (bottom * ty))
    return values


def terrain_noise_profile(spec: BaseTileSpec) -> list[float]:
    wide = tileable_noise(SIZE, 4, spec.seed + 17003)
    mid = tileable_noise(SIZE, 8, spec.seed + 23009)
    fine = tileable_noise(SIZE, 16, spec.seed + 31013)
    values: list[float] = []
    for index in range(SIZE * SIZE):
        values.append((wide[index] * 0.58) + (mid[index] * 0.30) + (fine[index] * 0.12))
    return values


def save_rgba(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.convert("RGBA").save(path)


def draw_low_noise_ground(spec: BaseTileSpec) -> Image.Image:
    base = hex_rgb(spec.base)
    secondary = hex_rgb(spec.secondary)
    rng = random.Random(spec.seed)
    macro = terrain_noise_profile(spec)
    pixels: list[tuple[int, int, int, int]] = []
    for y in range(SIZE):
        for x in range(SIZE):
            index = (y * SIZE) + x
            local = random.Random((spec.seed * 1000003) + (x * 9176) + (y * 6113))
            value = macro[index]
            amount = 0.08 + (value * 0.34)
            shade = mix(base, secondary, amount)
            if value < 0.34:
                shade = mix(shade, hex_rgb(spec.detail), (0.34 - value) * 0.24)
            elif value > 0.68:
                shade = mix(shade, hex_rgb(spec.accent), (value - 0.68) * 0.22)
            shade = add_rgb(shade, (value - 0.50) * 13.0)
            pixels.append((*jitter(shade, 2, local), 255))
    image = Image.new("RGBA", (SIZE, SIZE))
    image.putdata(pixels)
    overlay = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay, "RGBA")

    for _index in range(7):
        cx = rng.randint(8, 56)
        cy = rng.randint(8, 56)
        rx = rng.randint(12, 30)
        ry = rng.randint(8, 22)
        color = mix(hex_rgb(spec.secondary), base, rng.random() * 0.35)
        alpha = rng.randint(10, 28)
        draw.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=(*color, alpha))
    image.alpha_composite(overlay)
    return image


def draw_tufts(draw: ImageDraw.ImageDraw, rng: random.Random, spec: BaseTileSpec, count: int) -> None:
    detail = hex_rgb(spec.detail)
    accent = hex_rgb(spec.accent)
    for _index in range(count):
        x = rng.randint(7, 57)
        y = rng.randint(7, 57)
        length = rng.randint(4, 9)
        color = mix(detail, accent, rng.random() * 0.35)
        alpha = rng.randint(36, 64)
        draw.line((x, y, x + rng.randint(2, 6), y - length), fill=(*color, alpha), width=1)
        if rng.random() < 0.42:
            draw.line((x + 1, y, x - rng.randint(2, 4), y - max(2, length - 2)), fill=(*color, alpha - 8), width=1)


def draw_tree_clusters(draw: ImageDraw.ImageDraw, rng: random.Random, spec: BaseTileSpec, count: int) -> None:
    detail = hex_rgb(spec.detail)
    accent = hex_rgb(spec.accent)
    for _index in range(count):
        x = rng.randint(8, 56)
        y = rng.randint(8, 56)
        radius = rng.randint(4, 9)
        color = mix(detail, accent, rng.random() * 0.20)
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=(*color, rng.randint(44, 72)))
        if rng.random() < 0.55:
            highlight = mix(color, accent, 0.32)
            draw.arc((x - radius, y - radius, x + radius, y + radius), 210, 330, fill=(*highlight, 40), width=1)


def draw_reed_pools(draw: ImageDraw.ImageDraw, rng: random.Random, spec: BaseTileSpec, count: int) -> None:
    detail = hex_rgb(spec.detail)
    accent = hex_rgb(spec.accent)
    water = mix(hex_rgb(spec.secondary), (80, 112, 112), 0.34)
    for _index in range(max(2, count // 5)):
        x = rng.randint(10, 54)
        y = rng.randint(10, 54)
        rx = rng.randint(5, 11)
        ry = rng.randint(2, 5)
        draw.ellipse((x - rx, y - ry, x + rx, y + ry), fill=(*water, rng.randint(42, 68)))
    for _index in range(count):
        x = rng.randint(7, 57)
        y = rng.randint(10, 57)
        height = rng.randint(5, 12)
        color = mix(detail, accent, rng.random() * 0.42)
        draw.line((x, y, x + rng.randint(-2, 2), y - height), fill=(*color, rng.randint(38, 62)), width=1)


def draw_contours(draw: ImageDraw.ImageDraw, rng: random.Random, spec: BaseTileSpec, count: int) -> None:
    detail = hex_rgb(spec.detail)
    accent = hex_rgb(spec.accent)
    for _index in range(count):
        y = rng.randint(11, 53)
        x = rng.randint(5, 20)
        points = []
        for step in range(5):
            points.append((x + step * rng.randint(8, 12), y + rng.randint(-6, 6)))
        color = mix(detail, accent, rng.random() * 0.35)
        draw.line(points, fill=(*color, rng.randint(42, 66)), width=1)


def draw_scree(draw: ImageDraw.ImageDraw, rng: random.Random, spec: BaseTileSpec, count: int) -> None:
    detail = hex_rgb(spec.detail)
    accent = hex_rgb(spec.accent)
    for _index in range(count):
        x = rng.randint(7, 57)
        y = rng.randint(7, 57)
        radius = rng.randint(1, 3)
        color = mix(detail, accent, rng.random() * 0.30)
        draw.rectangle((x - radius, y - radius, x + radius, y + radius), fill=(*color, rng.randint(28, 48)))


def draw_worn_ground_streaks(draw: ImageDraw.ImageDraw, rng: random.Random, spec: BaseTileSpec, count: int) -> None:
    detail = hex_rgb(spec.detail)
    secondary = hex_rgb(spec.secondary)
    for _index in range(count):
        start_x = rng.randint(-8, 36)
        start_y = rng.randint(12, 58)
        points = []
        for step in range(5):
            points.append((start_x + (step * rng.randint(10, 15)), start_y + rng.randint(-5, 5)))
        color = mix(detail, secondary, 0.28 + (rng.random() * 0.30))
        draw.line(points, fill=(*color, rng.randint(26, 46)), width=1)


def draw_terrain_details(image: Image.Image, spec: BaseTileSpec) -> Image.Image:
    rng = random.Random(spec.seed + 9049)
    overlay = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay, "RGBA")
    match spec.pattern:
        case "field_tufts":
            draw_tufts(draw, rng, spec, 24)
        case "dry_grass":
            draw_tufts(draw, rng, spec, 18)
            draw_worn_ground_streaks(draw, rng, spec, 2)
        case "worn_field":
            draw_tufts(draw, rng, spec, 12)
            draw_contours(draw, rng, spec, 2)
            draw_worn_ground_streaks(draw, rng, spec, 4)
        case "tree_clusters":
            draw_tree_clusters(draw, rng, spec, 16)
        case "tree_edge":
            draw_tree_clusters(draw, rng, spec, 10)
            draw_tufts(draw, rng, spec, 10)
        case "reed_pools":
            draw_reed_pools(draw, rng, spec, 19)
        case "mud_reeds":
            draw_reed_pools(draw, rng, spec, 12)
            draw_contours(draw, rng, spec, 2)
            draw_worn_ground_streaks(draw, rng, spec, 2)
        case "deep_swamp":
            draw_reed_pools(draw, rng, spec, 15)
            draw_tree_clusters(draw, rng, spec, 5)
        case "contours" | "scrub_contours" | "ridge_contours" | "worn_contours":
            draw_contours(draw, rng, spec, 7)
            if "scrub" in spec.pattern or "worn" in spec.pattern:
                draw_tufts(draw, rng, spec, 8)
            if "worn" in spec.pattern:
                draw_worn_ground_streaks(draw, rng, spec, 3)
        case "scree":
            draw_scree(draw, rng, spec, 28)
            draw_contours(draw, rng, spec, 4)
        case _:
            draw_tufts(draw, rng, spec, 10)
    image.alpha_composite(overlay)
    return image.filter(ImageFilter.UnsharpMask(radius=0.35, percent=18, threshold=4))


def build_base_tiles() -> None:
    for spec in BASE_TILE_SPECS:
        image = draw_low_noise_ground(spec)
        image = draw_terrain_details(image, spec)
        save_rgba(image, OUT / "base" / f"{spec.output}.png")


def jagged_profile(length: int, base_width: int, rng: random.Random) -> list[int]:
    points: list[int] = []
    current = base_width
    for _index in range(length + 1):
        current += rng.randint(-2, 2)
        current = max(7, min(base_width + 7, current))
        points.append(current)
    return points


def edge_polygon(direction: str, profile: list[int]) -> list[tuple[int, int]]:
    max_coord = SIZE * SCALE
    if direction == "n":
        points = [(0, 0), (max_coord, 0)]
        points.extend((x * SCALE, profile[x] * SCALE) for x in range(SIZE, -1, -1))
        return points
    if direction == "s":
        points = [(0, max_coord), (max_coord, max_coord)]
        points.extend((x * SCALE, max_coord - (profile[x] * SCALE)) for x in range(SIZE, -1, -1))
        return points
    if direction == "w":
        points = [(0, 0), (0, max_coord)]
        points.extend((profile[y] * SCALE, y * SCALE) for y in range(SIZE, -1, -1))
        return points
    points = [(max_coord, 0), (max_coord, max_coord)]
    points.extend((max_coord - (profile[y] * SCALE), y * SCALE) for y in range(SIZE, -1, -1))
    return points


def profile_line(direction: str, profile: list[int]) -> list[tuple[int, int]]:
    max_coord = SIZE * SCALE
    if direction == "n":
        return [(x * SCALE, profile[x] * SCALE) for x in range(SIZE + 1)]
    if direction == "s":
        return [(x * SCALE, max_coord - (profile[x] * SCALE)) for x in range(SIZE + 1)]
    if direction == "w":
        return [(profile[y] * SCALE, y * SCALE) for y in range(SIZE + 1)]
    return [(max_coord - (profile[y] * SCALE), y * SCALE) for y in range(SIZE + 1)]


def build_edge_overlay(spec: EdgeSpec, direction: str) -> Image.Image:
    rng = random.Random(spec.seed + sum(ord(char) for char in direction))
    profile = jagged_profile(SIZE, spec.width, rng)
    canvas = Image.new("RGBA", (SIZE * SCALE, SIZE * SCALE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas, "RGBA")
    draw.polygon(edge_polygon(direction, profile), fill=(*hex_rgb(spec.fill), spec.alpha))
    draw.line(profile_line(direction, profile), fill=(*hex_rgb(spec.dark), max(80, spec.alpha - 34)), width=2 * SCALE)
    for _index in range(12):
        x = rng.randint(4, 60) * SCALE
        y = rng.randint(4, 60) * SCALE
        if direction == "n" and y > (spec.width + 5) * SCALE:
            continue
        if direction == "s" and y < (SIZE - spec.width - 5) * SCALE:
            continue
        if direction == "w" and x > (spec.width + 5) * SCALE:
            continue
        if direction == "e" and x < (SIZE - spec.width - 5) * SCALE:
            continue
        radius = rng.randint(1, 2) * SCALE
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=(*hex_rgb(spec.light), rng.randint(22, 42)))
    return canvas.resize((SIZE, SIZE), Image.Resampling.LANCZOS)


def build_edge_overlays() -> None:
    for group, spec in EDGE_SPECS.items():
        for direction in ("n", "e", "s", "w"):
            save_rgba(build_edge_overlay(spec, direction), OUT / "edges" / f"{group}_edge_{direction}.png")


def line_geometry(end: tuple[float, float], lateral_offset: float = 0.0) -> tuple[tuple[float, float], tuple[float, float]]:
    start = (32.0, 32.0)
    dx = end[0] - start[0]
    dy = end[1] - start[1]
    length = max(0.001, math.sqrt((dx * dx) + (dy * dy)))
    normal = (-dy / length, dx / length)
    return (
        (start[0] + (normal[0] * lateral_offset), start[1] + (normal[1] * lateral_offset)),
        (end[0] + (normal[0] * lateral_offset), end[1] + (normal[1] * lateral_offset)),
    )


def jittered_line_points(kind: str, end: tuple[float, float], lateral_offset: float, wobble: float, seed: int) -> list[tuple[float, float]]:
    start, finish = line_geometry(end, lateral_offset)
    dx = finish[0] - start[0]
    dy = finish[1] - start[1]
    length = max(0.001, math.sqrt((dx * dx) + (dy * dy)))
    normal = (-dy / length, dx / length)
    rng = random.Random(seed + sum(ord(char) for char in kind))
    points: list[tuple[float, float]] = []
    for step in range(7):
        t = float(step) / 6.0
        offset = 0.0 if step in (0, 6) else rng.uniform(-wobble, wobble)
        points.append((
            start[0] + (dx * t) + (normal[0] * offset),
            start[1] + (dy * t) + (normal[1] * offset),
        ))
    return points


def make_mask_line(kind: str, end: tuple[float, float], width: float, center_radius: float = 0.0, lateral_offset: float = 0.0, wobble: float = 1.2) -> Image.Image:
    mask = Image.new("L", (SIZE * SCALE, SIZE * SCALE), 0)
    draw = ImageDraw.Draw(mask)
    points = jittered_line_points(kind, end, lateral_offset, wobble, int(width * 211))
    scaled_points = [(point[0] * SCALE, point[1] * SCALE) for point in points]
    draw.line(scaled_points, fill=255, width=max(1, int(round(width * SCALE))), joint="curve")
    if center_radius > 0.0:
        start = scaled_points[0]
        radius = center_radius * SCALE
        draw.ellipse((start[0] - radius, start[1] - radius, start[0] + radius, start[1] + radius), fill=255)
    return mask.resize((SIZE, SIZE), Image.Resampling.LANCZOS)


def make_mask_circle(radius: float, offset_y: float = 0.0) -> Image.Image:
    mask = Image.new("L", (SIZE * SCALE, SIZE * SCALE), 0)
    draw = ImageDraw.Draw(mask)
    center = (32.0 * SCALE, (32.0 + offset_y) * SCALE)
    scaled_radius = radius * SCALE
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


def make_organic_center_mask(radius: float, seed: int, offset_y: float = 0.0) -> Image.Image:
    rng = random.Random(seed)
    center = (32.0 * SCALE, (32.0 + offset_y) * SCALE)
    points: list[tuple[float, float]] = []
    for step in range(24):
        angle = (math.tau * float(step)) / 24.0
        local_radius = radius * SCALE * rng.uniform(0.72, 1.16)
        x = center[0] + (math.cos(angle) * local_radius * rng.uniform(0.88, 1.08))
        y = center[1] + (math.sin(angle) * local_radius * rng.uniform(0.64, 0.92))
        points.append((x, y))
    mask = Image.new("L", (SIZE * SCALE, SIZE * SCALE), 0)
    draw = ImageDraw.Draw(mask)
    draw.polygon(points, fill=255)
    return mask.filter(ImageFilter.GaussianBlur(radius=0.55 * SCALE)).resize((SIZE, SIZE), Image.Resampling.LANCZOS)


def scaled_mask(mask: Image.Image, alpha: int) -> Image.Image:
    return mask.point(lambda value: int((value * alpha) / 255))


def composite_color(canvas: Image.Image, color: tuple[int, int, int], mask: Image.Image, alpha: int) -> None:
    layer = Image.new("RGBA", (SIZE, SIZE), (*color, 0))
    layer.putalpha(scaled_mask(mask, alpha))
    canvas.alpha_composite(layer)


def sprinkle_road_grit(canvas: Image.Image, mask: Image.Image, seed: int) -> None:
    rng = random.Random(seed)
    draw = ImageDraw.Draw(canvas, "RGBA")
    for _index in range(34):
        x = rng.randint(8, 56)
        y = rng.randint(8, 56)
        if mask.getpixel((x, y)) < 58:
            continue
        color = (132, 103, 70) if rng.random() < 0.62 else (70, 51, 34)
        alpha = rng.randint(26, 58)
        draw.point((x, y), fill=(*color, alpha))


def draw_road_ruts(canvas: Image.Image, kind: str, end: tuple[float, float], seed: int) -> None:
    layer = Image.new("RGBA", (SIZE * SCALE, SIZE * SCALE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer, "RGBA")
    for lateral_offset in (-2.0, 2.0):
        points = jittered_line_points(kind, end, lateral_offset, 0.55, seed + int(lateral_offset * 97))
        scaled_points = [(point[0] * SCALE, point[1] * SCALE) for point in points]
        draw.line(scaled_points, fill=(67, 47, 31, 72), width=max(1, int(round(0.9 * SCALE))))
    canvas.alpha_composite(layer.resize((SIZE, SIZE), Image.Resampling.LANCZOS))


def road_layer(kind: str) -> Image.Image:
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    if kind == "center":
        shadow = make_organic_center_mask(7.3, 9101, 1.0)
        edge = make_organic_center_mask(6.2, 9102, 0.2)
        core = make_organic_center_mask(4.9, 9103, 0.0)
        highlight = make_organic_center_mask(1.8, 9104, -0.2)
        grit_mask = core
        seed = 910
    else:
        end = ROAD_DIRECTIONS[kind]
        shadow = make_mask_line(kind, end, 11.6, 4.4, 0.8, 1.7)
        edge = make_mask_line(kind, end, 9.6, 3.6, 0.1, 1.35)
        core = make_mask_line(kind, end, 7.1, 2.6, 0.0, 1.05)
        highlight = make_mask_line(kind, end, 1.0, 0.6, -0.8, 0.55)
        grit_mask = core
        seed = 920 + sum(ord(char) for char in kind)
    composite_color(canvas, (32, 24, 18), shadow, 68)
    composite_color(canvas, (75, 55, 36), edge, 122)
    composite_color(canvas, (139, 104, 63), core, 174)
    composite_color(canvas, (187, 151, 91), highlight, 42)
    if kind != "center":
        draw_road_ruts(canvas, kind, ROAD_DIRECTIONS[kind], seed + 401)
    sprinkle_road_grit(canvas, grit_mask, seed)
    return canvas.filter(ImageFilter.UnsharpMask(radius=0.28, percent=16, threshold=4))


def build_road_overlays() -> None:
    save_rgba(road_layer("center"), OUT / "roads" / "road_dirt_center.png")
    for direction in ROAD_DIRECTIONS:
        save_rgba(road_layer(direction), OUT / "roads" / f"road_dirt_{direction}.png")


def build() -> None:
    build_base_tiles()
    build_edge_overlays()
    build_road_overlays()


if __name__ == "__main__":
    build()
