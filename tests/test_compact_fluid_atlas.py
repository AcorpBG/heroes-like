"""Original pixels and anatomical offsets survive non-grid atlas storage."""
import sys
import unittest
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from integrate_fluid_creature_animation import old_pose, pack_compact


class CompactAtlasTests(unittest.TestCase):
    def test_dense_mixed_actions_preserve_every_pixel_and_signed_origin(self):
        poses = []
        for i in range(180):
            image = Image.new('RGBA', (60+i % 97, 80+i % 149), (i, 71, 139, 255))
            image.putpixel((0, 0), (217, 103, 9, 23))
            # Some flight/weapon origins lie outside their painted rectangle.
            poses.append((image, (-190+i % 80, -310+i % 200)))
        atlas, rects, anchors = pack_compact(poses)
        self.assertLessEqual(max(atlas.size), 4096)
        self.assertLess(atlas.width*atlas.height, 180*600*400)
        row = {'pose_frame_rects': rects, 'pose_region_anchors': anchors}
        for i, (expected, origin) in enumerate(poses):
            actual, actual_origin = old_pose(atlas, row, i)
            self.assertEqual((actual.size, actual.tobytes(), actual_origin),
                             (expected.size, expected.tobytes(), origin))
            x, y, w, h = rects[i]
            self.assertEqual(atlas.crop((x, y, x+w, y+4)).getchannel('A').getextrema(), (0, 0))
            for bx, by, bw, bh in rects[:i]:
                self.assertTrue(x+w <= bx or bx+bw <= x or y+h <= by or by+bh <= y)
        again, again_rects, again_anchors = pack_compact(poses)
        self.assertEqual((atlas.tobytes(), rects, anchors),
                         (again.tobytes(), again_rects, again_anchors))

    def test_legacy_grid_keeps_its_original_anatomical_offset(self):
        atlas = Image.new('RGBA', (128, 64))
        source = Image.new('RGBA', (13, 21), (40, 80, 160, 217))
        atlas.paste(source, (75, 20))
        row = {'pose_frame_size': {'width': 64, 'height': 64},
               'pose_columns': 2, 'pose_anchor_x': 29, 'pose_ground_margin': 9}
        actual, origin = old_pose(atlas, row, 1)
        self.assertEqual(actual.tobytes(), source.tobytes())
        self.assertEqual(origin, (-18, -35))

    def test_oversized_original_is_rejected_without_resizing(self):
        source = Image.new('RGBA', (4096, 20), (20, 40, 60, 255))
        with self.assertRaisesRegex(ValueError, 'never shrink'):
            pack_compact([(source, (-100, -10))])


if __name__ == '__main__':
    unittest.main()
