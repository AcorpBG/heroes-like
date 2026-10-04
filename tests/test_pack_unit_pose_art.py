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
    def test_registered_art_matches_visual_acceptance(self):
        manifest = json.loads((ROOT / 'content/unit_animation_manifest.json').read_text())['items']
        evidence = json.loads((ROOT / 'docs/battle-unit-animation-acceptance.json').read_text())
        accepted = {row['unit_id']: row for row in evidence['units']}
        self.assertEqual(set(accepted), {row['unit_id'] for row in manifest})
        self.assertEqual(evidence['reviewed_unit_count'], len(accepted))
        for row in manifest:
            with self.subTest(unit=row['unit_id']):
                self.assertEqual(row['pose_review_status'],
                                 accepted[row['unit_id']].get('review_status', evidence['status']))
                self.assertEqual(row['pose_review_evidence'], 'docs/battle-unit-animation-acceptance.json')
                atlas = ROOT / row['pose_sheet'].removeprefix('res://')
                self.assertEqual(hashlib.sha256(atlas.read_bytes()).hexdigest(), accepted[row['unit_id']]['atlas_sha256'])
                # Clip, ground-anchor or facing changes invalidate review even
                # when atlas pixels are unchanged. Never auto-certify new art.
                pose = {key: value for key, value in row.items()
                        if key.startswith('pose_') and not key.startswith('pose_review_')}
                digest = hashlib.sha256(json.dumps(pose, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
                self.assertEqual(digest, accepted[row['unit_id']]['pose_metadata_sha256'])

    def test_registered_clips_resolve_real_frames(self):
        manifest = json.loads((ROOT / "content/unit_animation_manifest.json").read_text())
        units = {row["id"]: row for row in json.loads((ROOT / "content/units.json").read_text())["items"]}
        self.assertEqual({row['unit_id'] for row in manifest['items']}, set(units))
        for unit in manifest["items"]:
            with self.subTest(unit=unit["unit_id"]):
                self.assertTrue(unit.get('pose_sheet'), 'every authored unit needs original poses')
                atlas = packer.Image.open(ROOT / unit["pose_sheet"].removeprefix("res://"))
                width, height = (unit["pose_frame_size"][key] for key in ("width", "height"))
                recipe = json.loads((ROOT / 'art/animation/source/poses' / unit['unit_id'] / 'packing.json').read_text())
                self.assertEqual(unit['pose_ground_margin'], recipe['ground_margin'],
                                 'runtime must anchor the authored ground line, not transparent canvas padding')
                self.assertTrue(0 <= unit['pose_ground_margin'] < height)
                self.assertEqual(atlas.width, unit["pose_columns"] * width)
                self.assertEqual(atlas.height % height, 0)
                count = len(recipe['frames'])  # Padding cells are never authored poses.
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
                    for index in clip["indices"]:
                        self.assertTrue(0 <= index < count)
                        x, y = index % unit["pose_columns"] * width, index // unit["pose_columns"] * height
                        frame = atlas.crop((x, y, x + width, y + height))
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
