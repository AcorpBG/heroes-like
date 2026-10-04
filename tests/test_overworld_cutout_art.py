"""Original-sheet recovery, art identity, foreground retention and matte controls."""
import importlib.util
from pathlib import Path
import unittest

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('cutout_prepare', ROOT/'tools/prepare_overworld_cutout_art.py')
art = importlib.util.module_from_spec(spec)
spec.loader.exec_module(art)


class MatteTests(unittest.TestCase):
    def test_preview_cannot_overwrite_registered_art_or_repository_root(self):
        for path in [ROOT,ROOT/'art/overworld/runtime/objects/map_objects/distinct',art.PACKET]:
            with self.subTest(path=path),self.assertRaisesRegex(ValueError,'outside the registered art'):
                art.prepare(path,install=True)

    def test_nonuniform_backing_is_transparent_not_red_or_green(self):
        im = Image.new('RGB',(9,9),(250,0,185))
        for y in range(3,6):
            for x in range(3,6): im.putpixel((x,y),(140,100,60))
        im.putpixel((2,4),(195,50,122))
        out = art.recover_cell(im, neutral_material=True)
        self.assertEqual(out.getpixel((0,0)),(0,0,0,0))
        self.assertEqual(out.getpixel((4,4)),(140,100,60,255))
        self.assertEqual(out.getpixel((2,4))[:3],(140,100,60))
        self.assertAlmostEqual(out.getpixel((2,4))[3],128,delta=2)

    def test_white_paint_is_never_keyed_out(self):
        im = Image.new('RGB',(9,9),(255,0,255))
        im.putpixel((4,4),(255,255,255))
        self.assertEqual(art.recover_cell(im).getpixel((4,4)),(255,255,255,255))

    def test_explicit_coral_pigment_protected_without_keeping_backing(self):
        im = Image.new('RGB',(9,9),(255,0,210))
        im.putpixel((4,4),(190,80,160))
        out = art.recover_cell(im,neutral_material=True,protected_rects=[(2,2,7,7)])
        self.assertEqual(out.getpixel((4,4)),(190,80,160,255))
        self.assertEqual(out.getpixel((3,4)),(0,0,0,0))

    def test_unscoped_purple_interior_is_unchanged(self):
        im = Image.new('RGB',(21,21),(255,0,255))
        for y in range(2,19):
            for x in range(2,19): im.putpixel((x,y),(155,70,180))
        out = art.recover_cell(im,radius=2)
        self.assertEqual(out.getpixel((10,10)),(155,70,180,255))

    def test_refuse_ambiguous_all_backing(self):
        im = Image.new('RGB',(9,9),(255,0,255))
        im.putpixel((4,4),(220,50,220))
        with self.assertRaisesRegex(ValueError,'recoverable foreground'):
            art.recover_cell(im,neutral_material=True)


if __name__=='__main__':unittest.main()
