"""Production cutout safeguards; run with the consolidated animation batch.

Tiny synthetic fixtures exercise pixel selection only, never produce game art.
"""
import importlib.util
from pathlib import Path
import unittest

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "battle_cutouts", ROOT / "tools/prepare_battle_pose_cutouts.py")
CUTOUTS = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CUTOUTS)


class BattlePoseCutoutPreparationTests(unittest.TestCase):
    def fixture(self):
        pixels = np.full((20, 20, 3), 128, dtype=np.uint8)
        pixels[5:15, 5:15] = (230, 180, 40)
        return pixels

    def key(self, **extra):
        return dict(minimum=100, maximum=185, tolerance=12,
                    edge_radius=0, **extra)

    def test_bright_edge_connected_paint_is_preserved(self):
        pixels = self.fixture()
        pixels[3:8, 8:11] = (244, 244, 244)
        result, _ = CUTOUTS.extract(Image.fromarray(pixels), self.key())
        self.assertEqual(result.getpixel((9, 4)), (244, 244, 244, 255))
        self.assertEqual(result.getpixel((0, 0)), (0, 0, 0, 0))
        self.assertEqual(result.getpixel((6, 10)), (230, 180, 40, 255))

    def test_tinted_gap_requires_explicit_bounded_region(self):
        pixels = self.fixture()
        pixels[7:13, 7:13] = (109, 122, 141)
        pixels[1:4, 1:4] = (109, 122, 141)
        source = Image.fromarray(pixels)
        before, _ = CUTOUTS.extract(source, self.key())
        self.assertEqual(before.getpixel((8, 8)), (109, 122, 141, 255))
        region = dict(polygon=[[7, 7], [12, 7], [12, 12], [7, 12]],
                      minimum=90, tolerance=42, seed=[8, 8])
        after, _ = CUTOUTS.extract(source, self.key(background_regions=[region]))
        self.assertEqual(after.getpixel((8, 8)), (0, 0, 0, 0))
        self.assertEqual(after.getpixel((2, 2)), (109, 122, 141, 255))
        self.assertEqual(after.getpixel((6, 10)), (230, 180, 40, 255))
        self.assertTrue(np.array_equal(np.array(source), pixels))

    def test_protection_overrides_background_selection(self):
        pixels = self.fixture()
        result, _ = CUTOUTS.extract(Image.fromarray(pixels), self.key(
            protected_polygons=[[[1, 1], [3, 1], [3, 3], [1, 3]]]))
        self.assertEqual(result.getpixel((2, 2)), (128, 128, 128, 255))
        self.assertEqual(result.getpixel((0, 0)), (0, 0, 0, 0))

    def test_existing_alpha_is_not_rekeyed(self):
        source = Image.fromarray(self.fixture()).convert("RGBA")
        source.putpixel((0, 0), (0, 0, 0, 0))
        with self.assertRaisesRegex(ValueError, "already has alpha"):
            CUTOUTS.extract(source, self.key())

    def test_invalid_global_bound_is_rejected(self):
        key = self.key()
        key["maximum"] = 90
        with self.assertRaisesRegex(ValueError, "bounded background key"):
            CUTOUTS.extract(Image.fromarray(self.fixture()), key)

    def test_regional_seed_must_be_in_region_and_match_key(self):
        region = dict(polygon=[[7, 7], [12, 7], [12, 12], [7, 12]],
                      minimum=90, tolerance=42, seed=[1, 1])
        with self.assertRaisesRegex(ValueError, "outside inspected region"):
            CUTOUTS.extract(Image.fromarray(self.fixture()),
                            self.key(background_regions=[region]))
        region["seed"] = [8, 8]
        with self.assertRaisesRegex(ValueError, "does not match background key"):
            CUTOUTS.extract(Image.fromarray(self.fixture()),
                            self.key(background_regions=[region]))

    def test_chroma_key_preserves_gray_ivory_and_opposite_saturated_paint(self):
        pixels = np.full((20, 20, 3), (0, 255, 0), dtype=np.uint8)
        pixels[5:15, 5:15] = (128, 128, 128)
        pixels[7:10, 7:10] = (255, 0, 255)
        pixels[10:13, 10:13] = (244, 244, 244)
        source = Image.fromarray(pixels)
        result, _ = CUTOUTS.extract(source, dict(mode='color_distance',
            color=[0, 255, 0], distance=75, edge_radius=0))
        self.assertEqual(result.getpixel((0, 0)), (0, 0, 0, 0))
        self.assertEqual(result.getpixel((6, 6)), (128, 128, 128, 255))
        self.assertEqual(result.getpixel((8, 8)), (255, 0, 255, 255))
        self.assertEqual(result.getpixel((11, 11)), (244, 244, 244, 255))
        self.assertTrue(np.array_equal(np.array(source), pixels))

    def test_invalid_chroma_spec_and_unknown_mode_fail_closed(self):
        for extra in (dict(color=[0, 255]), dict(color=[0, 256, 0]),
                      dict(color=[False, 255, 0]), dict(distance=129),
                      dict(distance=float('nan')), dict(mode='automatic')):
            key = dict(mode='color_distance', color=[0, 255, 0],
                       distance=75, edge_radius=0)
            key.update(extra)
            with self.subTest(extra=extra), self.assertRaises(ValueError):
                CUTOUTS.extract(Image.fromarray(self.fixture()), key)

    def test_enclosed_chroma_removal_requires_explicit_opt_in(self):
        pixels = np.full((20, 20, 3), (0, 255, 0), dtype=np.uint8)
        pixels[5:15, 5:15] = (128, 128, 128)
        pixels[8:11, 8:11] = (0, 255, 0)
        key = dict(mode='color_distance', color=[0, 255, 0],
                   distance=75, edge_radius=0)
        before, _ = CUTOUTS.extract(Image.fromarray(pixels), key)
        self.assertEqual(before.getpixel((9, 9)), (0, 255, 0, 255))
        after, _ = CUTOUTS.extract(Image.fromarray(pixels), dict(
            key, all_keyed_is_background=True,
            protected_polygons=[[[1, 1], [3, 1], [3, 3], [1, 3]]]))
        self.assertEqual(after.getpixel((9, 9)), (0, 0, 0, 0))
        self.assertEqual(after.getpixel((2, 2)), (0, 255, 0, 255))
        self.assertEqual(after.getpixel((6, 6)), (128, 128, 128, 255))


if __name__ == "__main__":
    unittest.main()
