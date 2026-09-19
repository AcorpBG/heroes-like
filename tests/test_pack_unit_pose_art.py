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

    def test_real_254_alpha_cutout_preserves_source_pixels(self):
        source = ROOT / "art/animation/source/poses/unit_gorefen_ripper/alpha/poses.png"
        original_hash = hashlib.sha256(source.read_bytes()).hexdigest()
        original = packer.Image.open(source)
        self.assertEqual(original.getchannel("A").getextrema(), (0, 254))
        # Pack the whole real sheet at native scale to prove alpha is copied,
        # not normalized or reconstructed. This is not runtime registration.
        recipe = {"unit_id": "unit_gorefen_ripper", "frame_size": [1536, 1024],
                  "columns": 1, "ground_margin": 0,
                  "frames": [{"name": "source_alpha", "source": str(source),
                              "rects": [[0, 0, 1536, 1024]],
                              "anchor": [768, 1024], "scale": 1}]}
        with tempfile.TemporaryDirectory(prefix="heroes-pose-alpha-test-") as directory:
            path = Path(directory) / "recipe.json"
            path.write_text(json.dumps(recipe))
            output = Path(directory) / "atlas.png"
            packer.pack(path, output)
            self.assertEqual(packer.Image.open(output).tobytes(), original.tobytes())
        self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), original_hash)

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

    def test_generated_provenance_matches_pixels(self):
        for recipe in RECIPES:
            with self.subTest(recipe=recipe):
                provenance = json.loads((recipe.parent / "provenance.json").read_text())
                for intermediate in provenance.get("intermediates", []):
                    self.assertEqual(hashlib.sha256(source_path(recipe.parent, intermediate["source"]).read_bytes()).hexdigest(), intermediate["sha256"])
                for row in provenance["outputs"]:
                    for path_key, hash_key in (("source", "source_sha256"), ("alpha_source", "alpha_sha256")):
                        # Rejected originals need no alpha derivative; an explicitly
                        # declared derivative still requires its exact hash/file.
                        if path_key == 'alpha_source' and not row.get(path_key):
                            self.assertFalse(row.get(hash_key))
                            continue
                        self.assertEqual(hashlib.sha256(source_path(recipe.parent, row[path_key]).read_bytes()).hexdigest(), row[hash_key])
                runtime, expected = runtime_proof(provenance)
                self.assertEqual(hashlib.sha256(source_path(recipe.parent, runtime).read_bytes()).hexdigest(), expected)

    def test_real_atlas_is_reproducible_and_complete(self):
        manifest = {row['unit_id']: row for row in json.loads((ROOT / 'content/unit_animation_manifest.json').read_text())['items']}
        for recipe in RECIPES:
            with self.subTest(recipe=recipe), tempfile.TemporaryDirectory(prefix="heroes-pose-pack-test-") as directory:
                output = Path(directory) / "atlas.png"
                report = packer.pack(recipe, output)
                shipped = ROOT / "art/animation/runtime/poses" / (report["unit_id"] + ".png")
                self.assertEqual(output.read_bytes(), shipped.read_bytes())
                self.assertEqual(len(report["frames"]), len(json.loads(recipe.read_text())["frames"]))
                self.assertEqual(report["frame_size"], [512, 256])
                clips = manifest[report['unit_id']]['pose_clips']
                self.assertIn(clips['death']['indices'][-1], clips['dead']['indices'],
                              'death must settle into the persistent corpse')
                for index in clips['dead']['indices']:
                    self.assertRegex(report['frames'][index]['name'], r'dead|corpse')

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

    def test_rejects_rgb_backdrop(self):
        self.rejection(lambda r: r["frames"][0].update(source=str(RECIPE.parent / "idle.png")), "transparent alpha")

    def test_rejects_clipped_pose(self):
        self.rejection(lambda r: r["frames"][0].update(anchor=[-1000, 0]), "would clip")

    def test_rejects_out_of_source_crop(self):
        self.rejection(lambda r: r["frames"][0].update(rects=[[0, 0, 9999, 9999]]), "out-of-source")

    def test_rejects_invalid_scale(self):
        self.rejection(lambda r: r["frames"][0].update(scale=0), "positive downsampling")


if __name__ == "__main__":
    unittest.main()
