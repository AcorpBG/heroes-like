#!/usr/bin/env python3
"""Exercise packing against real generated pixels, not procedural pose fixtures."""
import importlib.util
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("packer", ROOT / "tools/pack_unit_pose_art.py")
packer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(packer)
RECIPE = ROOT / "art/animation/source/poses/unit_river_guard/packing.json"
RECIPES = sorted((ROOT / "art/animation/source/poses").glob("*/packing.json"))


def source_path(base, value):
    """Provenance supports explicit repo-relative and unit-local paths."""
    value = value.removeprefix('res://')
    return (ROOT / value if value.startswith('art/') else base / value).resolve()


def resolved_clip(unit, name):
    # Match BattleUnitPose.clip's explicit, single-hop alias contract.
    return unit['pose_clips'][unit.get('pose_aliases', {}).get(name, name)]


def frame_boxes(unit, clip):
    # Match BattleUnitPose.region: a clip's own sheet, a compact atlas's rects or the grid.
    own_sheet = 'sheet' in clip
    size = clip['frame_size'] if own_sheet else unit['pose_frame_size']
    columns = clip['columns'] if own_sheet else unit['pose_columns']
    packed = [] if own_sheet else unit.get('pose_frame_rects', [])
    boxes = []
    for index in clip['indices']:
        if packed:
            x, y, width, height = packed[index]
        else:
            width, height = size['width'], size['height']
            x, y = index % columns * width, index // columns * height
        boxes.append((x, y, x + width, y + height))
    return clip['sheet'] if own_sheet else unit['pose_sheet'], boxes


def runtime_proof(provenance):
    # A new packing block supersedes historical continuity/candidate records.
    record = provenance.get('packing') or provenance.get('continuity_production') or provenance.get('runtime_candidate')
    if not isinstance(record, dict):
        raise ValueError('Missing current runtime packing provenance')
    path = next((record[k] for k in ('runtime', 'runtime_sheet', 'runtime_atlas', 'runtime_path', 'runtime_candidate', 'path') if k in record), None)
    digest = next((record[k] for k in ('runtime_sha256', 'runtime_atlas_sha256', 'sha256') if k in record), None)
    if not isinstance(path, str) or not isinstance(digest, str):
        raise ValueError('Incomplete runtime packing provenance')
    return path, digest


class PosePackingTests(unittest.TestCase):
    def test_registered_clips_resolve_real_frames(self):
        manifest = json.loads((ROOT / "content/unit_animation_manifest.json").read_text())
        units = {row["id"]: row for row in json.loads((ROOT / "content/units.json").read_text())["items"]}
        self.assertEqual({row['unit_id'] for row in manifest['items']}, set(units))
        for unit in manifest["items"]:
            with self.subTest(unit=unit["unit_id"]):
                self.assertTrue(unit.get('pose_sheet'), 'every authored unit needs original poses')
                sheets = {}
                def sheet(path):
                    if path not in sheets:
                        sheets[path] = packer.Image.open(ROOT / path.removeprefix("res://")).convert("RGBA")
                    return sheets[path]
                width, height = (unit["pose_frame_size"][key] for key in ("width", "height"))
                self.assertTrue(0 <= unit['pose_ground_margin'] < height)
                if not unit.get("pose_frame_rects"):
                    self.assertEqual(sheet(unit["pose_sheet"]).width, unit["pose_columns"] * width)
                    self.assertEqual(sheet(unit["pose_sheet"]).height % height, 0)
                for name in ("idle", "move", "attack", "defend", "death", "dead"):
                    self.assertIn(name, unit["pose_clips"])
                if units[unit["unit_id"]].get("ranged", False):
                    self.assertNotEqual(resolved_clip(unit, 'ranged')['indices'],
                                        resolved_clip(unit, 'attack')['indices'],
                                        "ranged attack silently reuses the melee poses")
                for name, clip in unit["pose_clips"].items():
                    self.assertEqual(clip["frames"], len(clip["indices"]))
                    self.assertGreaterEqual(clip["frames"], 1 if name == "dead" else 2)
                    pixels = set()
                    self.assertTrue(all(index >= 0 for index in clip["indices"]))
                    path, boxes = frame_boxes(unit, clip)
                    atlas = sheet(path)
                    for box in boxes:
                        self.assertTrue(0 <= box[0] < box[2] <= atlas.width and 0 <= box[1] < box[3] <= atlas.height)
                        frame = atlas.crop(box)
                        # Padding cells are never authored poses.
                        self.assertIsNotNone(frame.getchannel("A").getbbox())
                        pixels.add(hashlib.sha256(frame.tobytes()).digest())
                    self.assertGreaterEqual(len(pixels), 1 if name == 'dead' else 2,
                                            'repeated identical pixels are not articulated animation')
                    self.assertTrue(0 <= clip.get('static_frame', 0) < clip['frames'])
                for alias in unit.get("pose_aliases", {}).values():
                    self.assertIn(alias, unit["pose_clips"])
                self.assertTrue((ROOT / unit["pose_provenance"].removeprefix("res://")).is_file())

    def rejection(self, mutate, message):
        recipe = json.loads(RECIPE.read_text())
        for frame in recipe["frames"]:
            frame["source"] = str(RECIPE.parent / frame["source"])
        mutate(recipe)
        with tempfile.TemporaryDirectory(prefix="heroes-pose-pack-test-") as directory:
            path = Path(directory) / "recipe.json"
            path.write_text(json.dumps(recipe))
            with self.assertRaisesRegex(ValueError, message):
                packer.pack(path, Path(directory) / "atlas.png")

if __name__ == "__main__":
    unittest.main()
