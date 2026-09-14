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


class PosePackingTests(unittest.TestCase):
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
        for unit in manifest["items"]:
            if not unit.get("pose_sheet"):
                continue  # Pending migration, not falsely counted as accepted.
            with self.subTest(unit=unit["unit_id"]):
                atlas = packer.Image.open(ROOT / unit["pose_sheet"].removeprefix("res://"))
                width, height = (unit["pose_frame_size"][key] for key in ("width", "height"))
                self.assertEqual(atlas.width, unit["pose_columns"] * width)
                self.assertEqual(atlas.height % height, 0)
                count = (atlas.width // width) * (atlas.height // height)
                for name in ("idle", "move", "attack", "defend", "death", "dead"):
                    self.assertIn(name, unit["pose_clips"])
                if units[unit["unit_id"]].get("ranged", False):
                    self.assertIn("ranged", unit["pose_clips"], "ranged unit has no original firing sequence")
                    self.assertNotEqual(unit["pose_clips"]["ranged"]["indices"],
                                        unit["pose_clips"]["attack"]["indices"],
                                        "ranged attack silently reuses the melee poses")
                for name, clip in unit["pose_clips"].items():
                    self.assertEqual(clip["frames"], len(clip["indices"]))
                    self.assertGreaterEqual(clip["frames"], 1 if name == "dead" else 2)
                    for index in clip["indices"]:
                        self.assertTrue(0 <= index < count)
                        x, y = index % unit["pose_columns"] * width, index // unit["pose_columns"] * height
                        self.assertIsNotNone(atlas.crop((x, y, x + width, y + height)).getchannel("A").getbbox())
                for alias in unit.get("pose_aliases", {}).values():
                    self.assertIn(alias, unit["pose_clips"])
                self.assertTrue((ROOT / unit["pose_provenance"].removeprefix("res://")).is_file())

    def test_generated_provenance_matches_pixels(self):
        for recipe in RECIPES:
            with self.subTest(recipe=recipe):
                provenance = json.loads((recipe.parent / "provenance.json").read_text())
                for intermediate in provenance.get("intermediates", []):
                    self.assertEqual(hashlib.sha256((recipe.parent / intermediate["source"]).read_bytes()).hexdigest(), intermediate["sha256"])
                for row in provenance["outputs"]:
                    for path_key, hash_key in (("source", "source_sha256"), ("alpha_source", "alpha_sha256")):
                        self.assertEqual(hashlib.sha256((recipe.parent / row[path_key]).read_bytes()).hexdigest(), row[hash_key])
                runtime = ROOT / provenance["packing"]["runtime"]
                self.assertEqual(hashlib.sha256(runtime.read_bytes()).hexdigest(), provenance["packing"]["runtime_sha256"])

    def test_real_atlas_is_reproducible_and_complete(self):
        for recipe in RECIPES:
            with self.subTest(recipe=recipe), tempfile.TemporaryDirectory(prefix="heroes-pose-pack-test-") as directory:
                output = Path(directory) / "atlas.png"
                report = packer.pack(recipe, output)
                shipped = ROOT / "art/animation/runtime/poses" / (report["unit_id"] + ".png")
                self.assertEqual(output.read_bytes(), shipped.read_bytes())
                self.assertEqual(len(report["frames"]), len(json.loads(recipe.read_text())["frames"]))
                self.assertEqual(report["frame_size"], [512, 256])
                self.assertEqual(report["frames"][-1]["name"], "dead")

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
