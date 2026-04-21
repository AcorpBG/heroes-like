#!/usr/bin/env python3
"""Stage local-only HoMM3 terrain and road frames for renderer prototyping.

This builder is intentionally a prototype support tool. It reads locally
extracted HoMM3 DEF frames from the task artifact and creates 64x64 PNGs under
``art/overworld/runtime/homm3_local_prototype/`` for the Godot renderer to load.
Those staged assets are local reference/prototype material only; they are not
treated as shippable or redistributable game assets.

The gameplay map, editor data model, save format, and pathing remain square-grid
and unchanged. The renderer selects these frames through explicit lookup tables
declared in ``content/terrain_grammar.json``.
"""

from __future__ import annotations

from pathlib import Path
import shutil

try:
    from PIL import Image
except ImportError as exc:  # pragma: no cover - tool dependency guard
    raise SystemExit("Pillow is required to stage HoMM3 prototype terrain frames.") from exc


ROOT = Path(__file__).resolve().parents[1]
SOURCE_ROOT = Path(
    "/root/.openclaw/workspace/tasks/10184/artifacts/"
    "homm3-lod-extract/output/h3sprite/defs"
)
OUT_ROOT = ROOT / "art" / "overworld" / "runtime" / "homm3_local_prototype"
SIZE = 64

TERRAIN_ATLASES = (
    "grastl",
    "dirttl",
    "rocktl",
    "sandtl",
    "snowtl",
    "swmptl",
    "lavatl",
    "subbtl",
    "watrtl",
)

ROAD_ATLASES = (
    "dirtrd",
    "gravrd",
)


def stage_atlas(atlas_id: str, output_group: str) -> int:
    source_dir = SOURCE_ROOT / f"{atlas_id}.dir"
    if not source_dir.exists():
        raise SystemExit(f"Missing extracted HoMM3 atlas directory: {source_dir}")

    output_dir = OUT_ROOT / output_group / atlas_id
    output_dir.mkdir(parents=True, exist_ok=True)

    count = 0
    for source_path in sorted(source_dir.glob("*.png")):
        image = Image.open(source_path).convert("RGBA")
        image = image.resize((SIZE, SIZE), Image.Resampling.NEAREST)
        image.save(output_dir / source_path.name)
        count += 1
    return count


def main() -> None:
    if OUT_ROOT.exists():
        shutil.rmtree(OUT_ROOT)
    total = 0
    for atlas_id in TERRAIN_ATLASES:
        total += stage_atlas(atlas_id, "terrain")
    for atlas_id in ROAD_ATLASES:
        total += stage_atlas(atlas_id, "roads")

    print(
        "Staged %d local-only HoMM3 prototype terrain/road frames under %s"
        % (total, OUT_ROOT.relative_to(ROOT))
    )


if __name__ == "__main__":
    main()
