"""Original-sheet cohort and chromatic-material preservation regressions."""
import importlib.util
from pathlib import Path
import unittest

from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('cutout_pool',ROOT/'tools/prepare_overworld_cutout_pool.py')
pool=importlib.util.module_from_spec(spec)
spec.loader.exec_module(pool)


class MaterialTests(unittest.TestCase):
    def test_chromatic_interior_and_neutral_materials_retain_original_rgb(self):
        im=Image.new('RGB',(25,25),(250,0,220))
        for y in range(5,20):
            for x in range(5,20):im.putpixel((x,y),(170,75,190))
        im.putpixel((12,12),(255,255,255))
        out=pool.material_cell(im,[(5,5,20,20)])
        self.assertEqual(out.getpixel((10,10)),(170,75,190,255))
        self.assertEqual(out.getpixel((12,12)),(255,255,255,255))
        self.assertEqual(out.getpixel((0,0)),(0,0,0,0))

    def test_purple_foreground_cannot_recolor_unprotected_matte(self):
        im=Image.new('RGB',(25,25),(250,0,220))
        for y in range(5,20):
            for x in range(5,20):im.putpixel((x,y),(170,75,190))
        im.putpixel((20,10),(210,38,205))
        im.putpixel((22,10),(140,110,60))
        out=pool.material_cell(im,[(5,5,20,20)])
        r,g,b,a=out.getpixel((20,10))
        self.assertLessEqual(min(r,b)-g,8)
        self.assertGreater(a,0)

    def test_no_material_regions_reuses_accepted_neutral_engine_exactly(self):
        im=Image.new('RGB',(9,9),(248,0,197))
        for y in range(3,6):
            for x in range(3,6):im.putpixel((x,y),(130,100,60))
        im.putpixel((2,4),(189,50,128))
        self.assertEqual(pool.material_cell(im,[]).tobytes(),pool.base.recover_cell(im,neutral_material=True).tobytes())

    def test_preview_refuses_source_runtime_and_root_overwrites(self):
        for path in (ROOT,ROOT/'art',pool.PACKET,ROOT/'art/overworld/runtime'):
            with self.subTest(path=path),self.assertRaisesRegex(ValueError,'outside the registered art'):
                pool.prepare(path,True)


if __name__=='__main__':unittest.main()
