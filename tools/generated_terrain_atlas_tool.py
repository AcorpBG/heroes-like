#!/usr/bin/env python3
"""Prepare and validate generated runtime terrain replacement atlases.

This tool is deterministic file tooling only. It does not call image generation
services. It packs existing 64x64 local reference frames into 1024x1024
16x16 atlases, and it validates/cuts later generated 1024x1024 atlases back
into exact 64x64 runtime frames.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

try:
    from PIL import Image, ImageDraw
except ImportError as exc:  # pragma: no cover - tool dependency guard
    raise SystemExit("Pillow is required for generated terrain atlas tooling.") from exc


ROOT = Path(__file__).resolve().parents[1]
REFERENCE_ROOT = ROOT / "art" / "overworld" / "runtime" / "homm3_local_prototype" / "terrain"
GENERATED_ROOT = ROOT / "art" / "overworld" / "runtime" / "terrain_tiles" / "generated"
TILE_SIZE = 64
GRID_SIZE = 16
ATLAS_SIZE = TILE_SIZE * GRID_SIZE
MAGENTA = (255, 0, 255, 255)

TERRAIN_CLASS_COUNTS = {
    "dirttl": 46,
    "lavatl": 79,
    "rocktl": 48,
    "rougtl": 79,
    "sandtl": 24,
    "snowtl": 79,
    "subbtl": 79,
    "swmptl": 79,
    "watrtl": 33,
}


@dataclass(frozen=True)
class ClassSpec:
    class_id: str
    count: int


def repo_path(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


def ensure(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def class_specs(args: argparse.Namespace) -> list[ClassSpec]:
    if args.all:
        ensure(not args.class_id, "--all cannot be combined with --class")
        ensure(args.count is None, "--all cannot be combined with --count")
        return [ClassSpec(class_id, count) for class_id, count in TERRAIN_CLASS_COUNTS.items()]

    ensure(args.class_id, "Choose --class or --all.")
    count = args.count if args.count is not None else TERRAIN_CLASS_COUNTS.get(args.class_id)
    ensure(count is not None, f"Unknown class count for {args.class_id}; pass --count.")
    ensure(0 < count <= GRID_SIZE * GRID_SIZE, f"Invalid frame count for {args.class_id}: {count}")
    return [ClassSpec(args.class_id, count)]


def sorted_frame_paths(source_dir: Path) -> list[Path]:
    return sorted(path for path in source_dir.glob("*.png") if not path.name.endswith(".import.png"))


def cell_box(index: int) -> tuple[int, int, int, int]:
    x = (index % GRID_SIZE) * TILE_SIZE
    y = (index // GRID_SIZE) * TILE_SIZE
    return (x, y, x + TILE_SIZE, y + TILE_SIZE)


def magenta_tile() -> Image.Image:
    return Image.new("RGBA", (TILE_SIZE, TILE_SIZE), MAGENTA)


def is_all_magenta(image: Image.Image) -> bool:
    return all(pixel == MAGENTA for pixel in image.convert("RGBA").getdata())


def has_magenta_pixels(image: Image.Image) -> bool:
    data = image.convert("RGBA").getdata()
    return any(pixel == MAGENTA for pixel in data)


def edge_line_is_suspicious(crop: Image.Image, edge: str) -> bool:
    rgba = crop.convert("RGBA")
    if edge == "left":
        line = [rgba.getpixel((0, y)) for y in range(TILE_SIZE)]
        neighbor = [rgba.getpixel((1, y)) for y in range(TILE_SIZE)]
    elif edge == "right":
        line = [rgba.getpixel((TILE_SIZE - 1, y)) for y in range(TILE_SIZE)]
        neighbor = [rgba.getpixel((TILE_SIZE - 2, y)) for y in range(TILE_SIZE)]
    elif edge == "top":
        line = [rgba.getpixel((x, 0)) for x in range(TILE_SIZE)]
        neighbor = [rgba.getpixel((x, 1)) for x in range(TILE_SIZE)]
    else:
        line = [rgba.getpixel((x, TILE_SIZE - 1)) for x in range(TILE_SIZE)]
        neighbor = [rgba.getpixel((x, TILE_SIZE - 2)) for x in range(TILE_SIZE)]

    dominant = max(line.count(pixel) for pixel in set(line))
    if dominant < int(TILE_SIZE * 0.94):
        return False
    different = sum(1 for a, b in zip(line, neighbor) if color_distance(a, b) > 96)
    return different >= int(TILE_SIZE * 0.75)


def color_distance(left: tuple[int, int, int, int], right: tuple[int, int, int, int]) -> int:
    return sum(abs(left[index] - right[index]) for index in range(4))


def validate_tile_crop(crop: Image.Image, label: str, *, strict_grid: bool) -> None:
    ensure(crop.size == (TILE_SIZE, TILE_SIZE), f"{label} is not 64x64.")
    ensure(not is_all_magenta(crop), f"{label} is an unused magenta cell.")
    ensure(not has_magenta_pixels(crop), f"{label} contains magenta padding/grid pixels.")
    if strict_grid:
        for edge in ("left", "right", "top", "bottom"):
            ensure(
                not edge_line_is_suspicious(crop, edge),
                f"{label} has a suspicious solid {edge} edge that may be a gridline.",
            )


def make_contact_sheet(frames: Iterable[Image.Image], count: int, out_path: Path) -> None:
    sheet = Image.new("RGBA", (ATLAS_SIZE, ATLAS_SIZE), MAGENTA)
    draw = ImageDraw.Draw(sheet)
    for index, frame in enumerate(frames):
        sheet.paste(frame.convert("RGBA"), cell_box(index))
    for x in range(0, ATLAS_SIZE + 1, TILE_SIZE):
        draw.line((x, 0, x, ATLAS_SIZE), fill=(0, 0, 0, 80))
    for y in range(0, ATLAS_SIZE + 1, TILE_SIZE):
        draw.line((0, y, ATLAS_SIZE, y), fill=(0, 0, 0, 80))
    draw.text((8, 8), f"{count} frames", fill=(255, 255, 255, 255))
    out_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out_path)


def pack_reference(spec: ClassSpec, args: argparse.Namespace) -> None:
    source_dir = args.source_root / spec.class_id
    ensure(source_dir.exists(), f"Missing source directory: {repo_path(source_dir)}")
    frame_paths = sorted_frame_paths(source_dir)
    ensure(
        len(frame_paths) == spec.count,
        f"{spec.class_id} expected {spec.count} PNG frames, found {len(frame_paths)} in {repo_path(source_dir)}.",
    )

    frames: list[Image.Image] = []
    atlas = Image.new("RGBA", (ATLAS_SIZE, ATLAS_SIZE), MAGENTA)
    for index, frame_path in enumerate(frame_paths):
        frame = Image.open(frame_path).convert("RGBA")
        ensure(frame.size == (TILE_SIZE, TILE_SIZE), f"{repo_path(frame_path)} is not 64x64.")
        frames.append(frame)
        atlas.paste(frame, cell_box(index))

    out_dir = args.out_root / spec.class_id / "source_sheets"
    preview_dir = args.out_root / spec.class_id / "previews"
    atlas_path = out_dir / f"{spec.class_id}-original-reference-16x16-magenta-1024.png"
    preview_path = preview_dir / f"{spec.class_id}-original-reference-16x16-preview.png"
    if args.dry_run:
        print(f"DRY-RUN pack {spec.class_id}: {spec.count} frames -> {repo_path(atlas_path)}")
        return
    ensure(args.force or not atlas_path.exists(), f"Refusing to overwrite {repo_path(atlas_path)} without --force.")
    out_dir.mkdir(parents=True, exist_ok=True)
    atlas.save(atlas_path)
    if args.preview:
        make_contact_sheet(frames, spec.count, preview_path)
    print(f"packed {spec.class_id}: {spec.count} frames -> {repo_path(atlas_path)}")


def validate_atlas(image: Image.Image, spec: ClassSpec, *, strict_grid: bool, require_unused_magenta: bool) -> list[Image.Image]:
    ensure(image.size == (ATLAS_SIZE, ATLAS_SIZE), f"Atlas must be 1024x1024, found {image.size}.")
    frames: list[Image.Image] = []
    for index in range(GRID_SIZE * GRID_SIZE):
        crop = image.crop(cell_box(index)).convert("RGBA")
        if index < spec.count:
            validate_tile_crop(crop, f"{spec.class_id} cell {index:02d}", strict_grid=strict_grid)
            frames.append(crop)
        elif require_unused_magenta:
            ensure(is_all_magenta(crop), f"{spec.class_id} unused cell {index:02d} is not magenta.")
    return frames


def normalized_unused_cells(image: Image.Image, spec: ClassSpec) -> Image.Image:
    normalized = image.convert("RGBA").copy()
    blank = magenta_tile()
    for index in range(spec.count, GRID_SIZE * GRID_SIZE):
        normalized.paste(blank, cell_box(index))
    return normalized


def cut_generated(spec: ClassSpec, args: argparse.Namespace) -> None:
    ensure(not args.all, "cut-generated requires one --class; --all is only for pack-reference.")
    atlas_path = args.atlas
    ensure(atlas_path is not None, "--atlas is required.")
    ensure(atlas_path.exists(), f"Missing generated atlas: {repo_path(atlas_path)}")
    ensure(
        bool(args.runtime_output) != bool(args.out_dir),
        "Choose exactly one output target: --runtime-output or --out-dir.",
    )

    atlas = Image.open(atlas_path).convert("RGBA")
    if args.force_unused_magenta:
        atlas = normalized_unused_cells(atlas, spec)
        require_unused_magenta = True
    else:
        require_unused_magenta = args.require_unused_magenta

    frames = validate_atlas(
        atlas,
        spec,
        strict_grid=not args.allow_suspicious_grid_edges,
        require_unused_magenta=require_unused_magenta,
    )
    if args.normalized_atlas:
        if args.dry_run:
            print(f"DRY-RUN normalize {spec.class_id}: {repo_path(args.normalized_atlas)}")
        else:
            args.normalized_atlas.parent.mkdir(parents=True, exist_ok=True)
            atlas.save(args.normalized_atlas)

    out_dir = args.out_dir
    if args.runtime_output:
        out_dir = args.out_root / spec.class_id / "frames_64"
    ensure(out_dir is not None, "Missing output directory.")
    preview_path = args.out_root / spec.class_id / "previews" / f"{spec.class_id}-generated-cut-preview.png"

    if args.dry_run:
        print(f"DRY-RUN cut {spec.class_id}: {len(frames)} frames from {repo_path(atlas_path)} -> {repo_path(out_dir)}")
        return
    ensure(args.force or not out_dir.exists(), f"Refusing to write existing directory {repo_path(out_dir)} without --force.")
    out_dir.mkdir(parents=True, exist_ok=True)
    for index, frame in enumerate(frames):
        frame.save(out_dir / f"00_{index:02d}.png")
    if args.preview:
        make_contact_sheet(frames, spec.count, preview_path)
    print(f"cut {spec.class_id}: {len(frames)} frames -> {repo_path(out_dir)}")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out-root", type=Path, default=GENERATED_ROOT)
    subparsers = parser.add_subparsers(dest="command", required=True)

    list_parser = subparsers.add_parser("list-classes", help="List known remaining terrain classes.")
    list_parser.set_defaults(func=lambda args: print("\n".join(f"{key} {value}" for key, value in TERRAIN_CLASS_COUNTS.items())))

    pack_parser = subparsers.add_parser("pack-reference", help="Pack local reference frames into magenta-padded 1024 atlases.")
    add_class_arguments(pack_parser)
    pack_parser.add_argument("--source-root", type=Path, default=REFERENCE_ROOT)
    pack_parser.add_argument("--preview", action=argparse.BooleanOptionalAction, default=True)
    pack_parser.add_argument("--force", action="store_true")
    pack_parser.add_argument("--dry-run", action="store_true")
    pack_parser.set_defaults(func=lambda args: [pack_reference(spec, args) for spec in class_specs(args)])

    cut_parser = subparsers.add_parser("cut-generated", help="Validate and cut a generated 1024 atlas into 64x64 frames.")
    add_class_arguments(cut_parser)
    cut_parser.add_argument("--atlas", type=Path)
    cut_parser.add_argument("--out-dir", type=Path)
    cut_parser.add_argument("--runtime-output", action="store_true", help="Write to art/.../generated/<class>/frames_64.")
    cut_parser.add_argument("--normalized-atlas", type=Path, help="Optional path for an atlas copy with unused cells magenta-filled.")
    cut_parser.add_argument("--force-unused-magenta", action="store_true", help="Fill unused cells with magenta before validation/cutting.")
    cut_parser.add_argument("--require-unused-magenta", action=argparse.BooleanOptionalAction, default=True)
    cut_parser.add_argument("--allow-suspicious-grid-edges", action="store_true")
    cut_parser.add_argument("--preview", action=argparse.BooleanOptionalAction, default=True)
    cut_parser.add_argument("--force", action="store_true")
    cut_parser.add_argument("--dry-run", action="store_true")
    cut_parser.set_defaults(func=lambda args: [cut_generated(spec, args) for spec in class_specs(args)])
    return parser


def add_class_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--class", dest="class_id", choices=sorted(TERRAIN_CLASS_COUNTS.keys()))
    parser.add_argument("--count", type=int)
    parser.add_argument("--all", action="store_true")


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()
    args.out_root = args.out_root.resolve()
    if hasattr(args, "source_root"):
        args.source_root = args.source_root.resolve()
    if getattr(args, "atlas", None):
        args.atlas = args.atlas.resolve()
    if getattr(args, "out_dir", None):
        args.out_dir = args.out_dir.resolve()
    if getattr(args, "normalized_atlas", None):
        args.normalized_atlas = args.normalized_atlas.resolve()
    args.func(args)


if __name__ == "__main__":
    main()
