#!/usr/bin/env python3
"""Build the first static overworld terrain tile-art set.

This intentionally writes small checked-in PNG pieces for the Godot renderer.
The renderer consumes the generated images as art assets; it does not recreate
these marks procedurally at runtime.
"""

from __future__ import annotations

import math
import random
import struct
import zlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "art" / "overworld" / "runtime" / "terrain_tiles"
SIZE = 64


Color = tuple[int, int, int, int]


def clamp(value: int) -> int:
    return max(0, min(255, value))


def vary(color: Color, amount: int, rng: random.Random) -> Color:
    return (
        clamp(color[0] + rng.randint(-amount, amount)),
        clamp(color[1] + rng.randint(-amount, amount)),
        clamp(color[2] + rng.randint(-amount, amount)),
        color[3],
    )


class Canvas:
    def __init__(self, width: int = SIZE, height: int = SIZE, bg: Color = (0, 0, 0, 0)) -> None:
        self.width = width
        self.height = height
        self.pixels = [[list(bg) for _x in range(width)] for _y in range(height)]

    def blend(self, x: int, y: int, color: Color) -> None:
        if x < 0 or y < 0 or x >= self.width or y >= self.height:
            return
        src_a = color[3] / 255.0
        if src_a <= 0.0:
            return
        dst = self.pixels[y][x]
        dst_a = dst[3] / 255.0
        out_a = src_a + dst_a * (1.0 - src_a)
        if out_a <= 0.0:
            self.pixels[y][x] = [0, 0, 0, 0]
            return
        for channel in range(3):
            dst[channel] = clamp(int(((color[channel] * src_a) + (dst[channel] * dst_a * (1.0 - src_a))) / out_a))
        dst[3] = clamp(int(out_a * 255))

    def fill_noise(self, base: Color, rng: random.Random, amount: int = 5) -> None:
        for y in range(self.height):
            for x in range(self.width):
                self.pixels[y][x] = list(vary(base, amount, rng))

    def rect(self, x0: int, y0: int, x1: int, y1: int, color: Color) -> None:
        for y in range(max(0, y0), min(self.height, y1)):
            for x in range(max(0, x0), min(self.width, x1)):
                self.blend(x, y, color)

    def circle(self, cx: float, cy: float, radius: float, color: Color) -> None:
        r2 = radius * radius
        for y in range(max(0, int(cy - radius - 1)), min(self.height, int(cy + radius + 2))):
            for x in range(max(0, int(cx - radius - 1)), min(self.width, int(cx + radius + 2))):
                dx = (x + 0.5) - cx
                dy = (y + 0.5) - cy
                if dx * dx + dy * dy <= r2:
                    self.blend(x, y, color)

    def ellipse(self, cx: float, cy: float, rx: float, ry: float, color: Color) -> None:
        if rx <= 0 or ry <= 0:
            return
        for y in range(max(0, int(cy - ry - 1)), min(self.height, int(cy + ry + 2))):
            for x in range(max(0, int(cx - rx - 1)), min(self.width, int(cx + rx + 2))):
                dx = ((x + 0.5) - cx) / rx
                dy = ((y + 0.5) - cy) / ry
                if dx * dx + dy * dy <= 1.0:
                    self.blend(x, y, color)

    def line(self, x0: float, y0: float, x1: float, y1: float, color: Color, width: float = 1.0) -> None:
        min_x = max(0, int(min(x0, x1) - width - 1))
        max_x = min(self.width, int(max(x0, x1) + width + 2))
        min_y = max(0, int(min(y0, y1) - width - 1))
        max_y = min(self.height, int(max(y0, y1) + width + 2))
        dx = x1 - x0
        dy = y1 - y0
        length2 = (dx * dx) + (dy * dy)
        radius = width * 0.5
        for y in range(min_y, max_y):
            for x in range(min_x, max_x):
                px = x + 0.5
                py = y + 0.5
                if length2 <= 0.0:
                    dist = math.hypot(px - x0, py - y0)
                else:
                    t = max(0.0, min(1.0, ((px - x0) * dx + (py - y0) * dy) / length2))
                    nearest_x = x0 + t * dx
                    nearest_y = y0 + t * dy
                    dist = math.hypot(px - nearest_x, py - nearest_y)
                if dist <= radius:
                    self.blend(x, y, color)

    def write(self, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        write_png(path, self.width, self.height, self.pixels)


def png_chunk(kind: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)


def write_png(path: Path, width: int, height: int, pixels: list[list[list[int]]]) -> None:
    rows = []
    for row in pixels:
        rows.append(b"\x00" + bytes(channel for pixel in row for channel in pixel))
    raw = b"".join(rows)
    payload = [
        b"\x89PNG\r\n\x1a\n",
        png_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)),
        png_chunk(b"IDAT", zlib.compress(raw, 9)),
        png_chunk(b"IEND", b""),
    ]
    path.write_bytes(b"".join(payload))


def tuft(canvas: Canvas, x: float, y: float, color: Color, scale: float = 1.0) -> None:
    canvas.line(x, y, x - 3.0 * scale, y - 8.0 * scale, color, 1.5 * scale)
    canvas.line(x, y, x + 2.8 * scale, y - 7.0 * scale, color, 1.4 * scale)
    canvas.line(x, y, x + 6.0 * scale, y - 3.5 * scale, color, 1.2 * scale)


def pebble(canvas: Canvas, x: float, y: float, color: Color, scale: float = 1.0) -> None:
    canvas.ellipse(x, y, 2.8 * scale, 1.8 * scale, color)
    canvas.line(x - 2.0 * scale, y + 1.0 * scale, x + 2.2 * scale, y + 1.0 * scale, (28, 24, 21, 68), 1.0)


def make_base_tile(terrain_id: str, variant: str) -> Canvas:
    rng = random.Random(f"{terrain_id}:{variant}:10184")
    palettes: dict[str, Color] = {
        "grass": (98, 139, 69, 255),
        "plains": (126, 145, 77, 255),
        "forest": (43, 81, 46, 255),
        "mire": (63, 78, 58, 255),
        "swamp": (48, 66, 53, 255),
        "hills": (113, 104, 75, 255),
        "ridge": (96, 91, 66, 255),
        "highland": (113, 103, 72, 255),
    }
    canvas = Canvas()
    canvas.fill_noise(palettes[terrain_id], rng, 7)

    if terrain_id in ("grass", "plains"):
        highlight = (172, 194, 92, 96) if terrain_id == "grass" else (200, 181, 88, 105)
        shadow = (54, 95, 46, 82) if terrain_id == "grass" else (93, 99, 52, 78)
        for _i in range(18):
            tuft(canvas, rng.randint(5, 59), rng.randint(18, 61), vary(highlight, 12, rng), rng.uniform(0.45, 0.95))
        if variant == "worn":
            canvas.line(2, 42 + rng.randint(-3, 3), 62, 25 + rng.randint(-4, 4), (128, 113, 68, 88), 7.0)
            canvas.line(2, 43, 62, 26, (206, 178, 103, 58), 2.0)
        elif variant in ("field", "dry"):
            for y in [18, 32, 47]:
                canvas.line(0, y + rng.randint(-2, 2), 64, y + rng.randint(-2, 2), shadow, 1.4)

    elif terrain_id == "forest":
        for _i in range(14):
            cx = rng.randint(7, 58)
            cy = rng.randint(11, 54)
            canvas.circle(cx, cy, rng.uniform(6.0, 10.0), vary((24, 63, 31, 160), 10, rng))
            canvas.circle(cx - 2, cy - 3, rng.uniform(3.2, 5.5), vary((67, 116, 54, 96), 8, rng))
        for _i in range(9):
            canvas.line(rng.randint(6, 58), rng.randint(18, 58), rng.randint(6, 58), rng.randint(18, 58), (57, 38, 23, 94), 2.2)
        if variant == "edge":
            canvas.rect(0, 0, 64, 12, (105, 133, 66, 58))

    elif terrain_id in ("mire", "swamp"):
        water = (45, 89, 88, 126) if terrain_id == "mire" else (32, 74, 75, 145)
        reed = (139, 154, 75, 120)
        mud = (53, 45, 34, 94)
        pool_count = 4 if variant == "pool" else 3
        for _i in range(pool_count):
            canvas.ellipse(rng.randint(9, 56), rng.randint(12, 54), rng.uniform(6, 12), rng.uniform(3, 7), water)
        for _i in range(20):
            x = rng.randint(4, 60)
            y = rng.randint(24, 62)
            canvas.line(x, y, x + rng.uniform(-3, 3), y - rng.uniform(7, 17), vary(reed, 16, rng), rng.uniform(1.0, 1.8))
        for _i in range(8):
            canvas.ellipse(rng.randint(8, 58), rng.randint(11, 57), rng.uniform(3, 8), rng.uniform(1.8, 4.2), mud)
        if variant in ("deep", "mud"):
            canvas.line(4, 52, 58, 44, (30, 34, 29, 92), 5.0)

    elif terrain_id in ("hills", "ridge", "highland"):
        contour = (179, 158, 99, 96)
        shadow = (63, 56, 41, 86)
        for offset in [8, 22, 37, 51]:
            canvas.line(-4, offset + rng.randint(-2, 2), 22, offset - 7 + rng.randint(-2, 2), contour, 2.0)
            canvas.line(22, offset - 7, 68, offset + rng.randint(-2, 3), contour, 2.0)
        if terrain_id == "ridge" or variant in ("ridgelet", "ridge"):
            canvas.line(5, 55, 31, 15, shadow, 7.0)
            canvas.line(31, 15, 61, 50, (170, 152, 101, 104), 4.0)
            canvas.line(31, 15, 45, 49, (43, 38, 30, 82), 3.0)
        if variant in ("scrub", "plateau", "slope"):
            for _i in range(11):
                tuft(canvas, rng.randint(7, 59), rng.randint(20, 60), (114, 127, 65, 98), rng.uniform(0.35, 0.68))
        for _i in range(9):
            pebble(canvas, rng.randint(7, 58), rng.randint(12, 58), (70, 65, 52, 110), rng.uniform(0.65, 1.15))

    canvas.rect(0, 0, 64, 2, (255, 255, 255, 15))
    canvas.rect(0, 62, 64, 64, (0, 0, 0, 18))
    return canvas


def make_edge_tile(group: str, direction: str) -> Canvas:
    rng = random.Random(f"edge:{group}:{direction}:10184")
    colors = {
        "grasslands": (73, 103, 52, 150),
        "forest": (19, 45, 27, 180),
        "mire": (35, 48, 40, 170),
        "highland": (73, 68, 51, 165),
    }
    detail = {
        "grasslands": (162, 183, 86, 82),
        "forest": (51, 95, 42, 92),
        "mire": (122, 137, 72, 88),
        "highland": (169, 151, 98, 76),
    }
    canvas = Canvas()
    base = colors[group]
    horizontal = direction in ("n", "s")
    for i in range(14):
        alpha = max(0, base[3] - i * 9)
        strip_color = (base[0], base[1], base[2], alpha)
        if direction == "n":
            canvas.rect(0, i, 64, i + 1, strip_color)
        elif direction == "s":
            canvas.rect(0, 63 - i, 64, 64 - i, strip_color)
        elif direction == "w":
            canvas.rect(i, 0, i + 1, 64, strip_color)
        elif direction == "e":
            canvas.rect(63 - i, 0, 64 - i, 64, strip_color)
    for _i in range(12):
        if horizontal:
            x = rng.randint(0, 63)
            y = rng.randint(0, 14) if direction == "n" else rng.randint(49, 63)
        else:
            x = rng.randint(0, 14) if direction == "w" else rng.randint(49, 63)
            y = rng.randint(0, 63)
        if group == "forest":
            canvas.circle(x, y, rng.uniform(2.0, 4.0), vary(detail[group], 12, rng))
        elif group == "mire":
            canvas.line(x, y + 4, x + rng.uniform(-2, 2), y - 5, vary(detail[group], 14, rng), 1.5)
        elif group == "highland":
            canvas.line(x - 4, y, x + 4, y + rng.uniform(-2, 2), vary(detail[group], 10, rng), 1.4)
        else:
            tuft(canvas, x, y + 4, vary(detail[group], 10, rng), 0.45)
    return canvas


def make_road_piece(kind: str) -> Canvas:
    canvas = Canvas()
    shadow = (45, 32, 21, 135)
    edge = (113, 83, 49, 190)
    dirt = (180, 149, 88, 210)
    center = (219, 191, 121, 120)

    def draw_segment(x0: float, y0: float, x1: float, y1: float) -> None:
        canvas.line(x0, y0 + 1, x1, y1 + 1, shadow, 17.5)
        canvas.line(x0, y0, x1, y1, edge, 14.5)
        canvas.line(x0, y0, x1, y1, dirt, 11.5)
        canvas.line(x0, y0, x1, y1, center, 2.0)

    if kind == "center":
        canvas.circle(32, 32, 10.5, shadow)
        canvas.circle(32, 32, 8.5, edge)
        canvas.circle(32, 32, 6.8, dirt)
        canvas.circle(32, 32, 2.2, center)
    else:
        endpoints = {
            "n": (32, -2),
            "e": (66, 32),
            "s": (32, 66),
            "w": (-2, 32),
            "ne": (66, -2),
            "se": (66, 66),
            "sw": (-2, 66),
            "nw": (-2, -2),
        }
        draw_segment(32, 32, endpoints[kind][0], endpoints[kind][1])
    rng = random.Random(f"road:{kind}:10184")
    for _i in range(11):
        canvas.circle(rng.randint(10, 54), rng.randint(10, 54), rng.uniform(0.7, 1.4), (92, 62, 36, 75))
    return canvas


def build() -> None:
    base_variants = {
        "grass": ["open", "field", "worn"],
        "plains": ["open", "dry", "worn"],
        "forest": ["canopy", "copse", "edge"],
        "mire": ["reeds", "mud", "pool"],
        "swamp": ["deep", "mud", "pool"],
        "hills": ["slope", "scrub", "ridgelet"],
        "ridge": ["ridge", "scree", "pass"],
        "highland": ["plateau", "scrub", "pass"],
    }
    for terrain_id, variants in base_variants.items():
        for variant in variants:
            make_base_tile(terrain_id, variant).write(OUT / "base" / f"{terrain_id}_{variant}.png")

    for group in ["grasslands", "forest", "mire", "highland"]:
        for direction in ["n", "e", "s", "w"]:
            make_edge_tile(group, direction).write(OUT / "edges" / f"{group}_edge_{direction}.png")

    for kind in ["center", "n", "e", "s", "w", "ne", "se", "sw", "nw"]:
        make_road_piece(kind).write(OUT / "roads" / f"road_dirt_{kind}.png")


if __name__ == "__main__":
    build()
