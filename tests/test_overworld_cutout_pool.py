"""Original-sheet cohort and chromatic-material preservation regressions."""
import importlib.util
import json
from pathlib import Path
import unittest
from unittest import mock

from PIL import Image, ImageFilter

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


class PoolTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.recipe,cls.manifest,cls.sheets=pool.load_inputs()
        cls.proof=json.loads((pool.PACKET/'manifest.json').read_text())
        cls.expected={k:pool.recover(cls.sheets[v['source']],v) for k,v in cls.recipe['assets'].items()}

    def test_all_159_original_members_and_preserved_controls_accounted_for(self):
        self.assertEqual(len(self.recipe['assets']),159)
        self.assertEqual(len(self.recipe['sources']),11)
        self.assertEqual(set(self.recipe['preserved_controls']),{'mapobj_marsh_listener_post','mapobj_wreck_quay','mapobj_moss_oath_cache'})
        self.assertEqual(set(self.proof['assets']),set(self.recipe['assets']))

    def test_exact_source_recipe_and_tool_provenance(self):
        self.assertEqual(self.proof['sources'],self.recipe['sources'])
        for field,path in [('recipe_sha256',pool.RECIPE),('processing_tool_sha256',Path(pool.__file__)),('matte_engine_sha256',pool.ENGINE)]:
            self.assertEqual(self.proof[field],pool.base.digest(path))

    def test_corrupt_source_and_swapped_identity_fail_before_writes(self):
        with mock.patch.object(pool.base,'digest',return_value='wrong'):
            with self.assertRaisesRegex(ValueError,'sheet hash changed'):pool.load_inputs()
        bad=json.loads(json.dumps(self.manifest))
        bad['object_assets']['mapobj_market_caravanserai']['assigned_map_object_id']='object_ember_signal_brazier'
        with mock.patch.object(pool,'ART_MANIFEST',mock.Mock(read_text=lambda:json.dumps(bad))):
            with self.assertRaisesRegex(ValueError,'identity/placement'):pool.load_inputs()

    def test_every_installed_original_cutout_reproduces_exactly(self):
        for key,expected in self.expected.items():
            with self.subTest(asset=key):
                entry=self.manifest['object_assets'][key]
                runtime=pool.base.local(entry['path'])
                self.assertEqual(entry['source_processing_manifest'],pool.base.resource(pool.PACKET/'manifest.json'))
                self.assertEqual(entry['runtime_sha256'],pool.base.digest(runtime))
                self.assertEqual(entry['runtime_sha256'],self.proof['assets'][key]['runtime_sha256'])
                with Image.open(runtime) as actual:
                    self.assertEqual(actual.mode,'RGBA')
                    self.assertEqual(actual.size,(512,512))
                    self.assertEqual(actual.tobytes(),expected.tobytes())

    def test_original_source_alignment_is_pixel_evidence_not_grid_assumption(self):
        for key,row in self.recipe['assets'].items():
            with self.subTest(asset=key):
                dx,dy=row['original_source_minus_canvas']
                before=Image.open(pool.PACKET/(key+'_before.png')).convert('RGBA')
                sheet=self.sheets[row['source']]
                matches=0
                for i,(r,g,b,a) in enumerate(before.getdata()):
                    x,y=i%512+dx,i//512+dy
                    if a==255 and i%17==0 and 0<=x<sheet.width and 0<=y<sheet.height:
                        matches+=sheet.getpixel((x,y))==(r,g,b)
                self.assertGreater(matches,100)

    def test_complete_neutral_opaque_paint_and_colored_interiors_are_preserved(self):
        restored=0
        colored=0
        for key,row in self.recipe['assets'].items():
            with self.subTest(asset=key):
                source=self.sheets[row['source']].crop(tuple(row['source_rect']))
                l,t,_,_=row['source_rect'];cx,cy=row['canvas_origin']
                mask=Image.new('L',source.size)
                mask.putdata([0 if g<=24 and min(r,b)>80 and min(r,b)-g>64 else 255 for r,g,b in source.getdata()])
                interior=list(mask.filter(ImageFilter.MinFilter(5)).getdata())
                before=Image.open(pool.PACKET/(key+'_before.png')).convert('RGBA')
                actual=self.expected[key]
                for i,(r,g,b) in enumerate(source.getdata()):
                    x,y=i%source.width,i//source.width
                    if min(r,b)-g<=8:
                        self.assertEqual(actual.getpixel((x+cx,y+cy)),(r,g,b,255))
                        if key not in ('mapobj_market_caravanserai','mapobj_ember_signal_brazier'):
                            restored+=before.getpixel((x+cx,y+cy))[3]==0
                    elif interior[i] and any(xx<=x+l<rr and yy<=y+t<bb for xx,yy,rr,bb in row.get('chromatic_source_rects',[])):
                        self.assertEqual(actual.getpixel((x+cx,y+cy)),(r,g,b,255))
                        colored+=1
        self.assertGreater(restored,1000)
        self.assertGreater(colored,1000)

    def test_no_unscoped_magenta_or_sheet_dividers(self):
        for key,row in self.recipe['assets'].items():
            with self.subTest(asset=key):
                l,t,r,b=row['source_rect'];cx,cy=row['canvas_origin']
                image=self.expected[key]
                # The inspected source rectangles must not end on a divider or
                # clip a painted subject; their outermost pixels are backing.
                bounds=image.getbbox()
                self.assertGreater(bounds[0],cx)
                self.assertGreater(bounds[1],cy)
                self.assertLess(bounds[2],cx+r-l)
                self.assertLess(bounds[3],cy+b-t)
                for i,(rr,g,bb,a) in enumerate(image.getdata()):
                    if a<32 or min(rr,bb)-g<=50 or min(rr,bb)<=140:continue
                    x,y=i%512-cx+l,i//512-cy+t
                    self.assertTrue(any(ll<=x<right and top<=y<bottom for ll,top,right,bottom in row.get('chromatic_source_rects',[])),(key,x,y))

    def test_irregular_caravanserai_and_brazier_keep_whole_separate_paintings(self):
        market=self.recipe['assets']['mapobj_market_caravanserai']
        brazier=self.recipe['assets']['mapobj_ember_signal_brazier']
        self.assertGreater(market['source_rect'][2]-market['source_rect'][0],400)
        self.assertGreater(brazier['source_rect'][0],market['source_rect'][2])
        self.assertGreater(self.expected['mapobj_market_caravanserai'].getbbox()[2]-self.expected['mapobj_market_caravanserai'].getbbox()[0],400)
        self.assertLess(self.expected['mapobj_ember_signal_brazier'].getbbox()[2]-self.expected['mapobj_ember_signal_brazier'].getbbox()[0],160)

    def test_every_retained_before_image_fails_visible_raster_acceptance(self):
        for key,expected in self.expected.items():
            with self.subTest(asset=key),Image.open(pool.PACKET/(key+'_before.png')) as before:
                opaque=Image.new('RGB',(512,512),'#334c3a')
                old=opaque.copy();old.paste(before,(0,0),before)
                new=opaque.copy();new.paste(expected,(0,0),expected)
                self.assertNotEqual(old.tobytes(),new.tobytes())


if __name__=='__main__':unittest.main()
