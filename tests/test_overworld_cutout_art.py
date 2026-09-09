"""Original-sheet recovery, art identity, foreground retention and matte controls."""
import importlib.util
import json
from pathlib import Path
import unittest
from unittest import mock

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


class CohortTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.recipe, cls.manifest, cls.sheet = art.load_inputs()
        cls.proof = json.loads((art.PACKET/'manifest.json').read_text())

    def test_exact_membership_and_original_cinder_control(self):
        self.assertEqual(len(self.recipe['assets']),15)
        self.assertEqual(set(self.recipe['preserved_controls']),{'mapobj_cinder_ore_face'})
        self.assertEqual(set(self.proof['assets']),set(self.recipe['assets']))

    def test_recipe_and_preparation_provenance(self):
        self.assertEqual(self.proof['recipe_sha256'],art.digest(art.RECIPE))
        self.assertEqual(self.proof['processing_tool_sha256'],art.digest(Path(art.__file__)))
        self.assertEqual(self.proof['source_sha256'],self.recipe['source_sha256'])

    def test_source_corruption_fails_closed_before_writes(self):
        with mock.patch.object(art,'digest',return_value='not-the-source-hash'):
            with self.assertRaisesRegex(ValueError,'sheet hash changed'):art.load_inputs()

    def test_swapped_content_identity_fails_before_writes(self):
        bad=json.loads(json.dumps(self.manifest))
        bad['object_assets']['mapobj_frostwood_cutting_yard']['assigned_map_object_id']='object_memory_salt_pan'
        with mock.patch.object(art,'ART_MANIFEST',mock.Mock(read_text=lambda:json.dumps(bad))):
            with self.assertRaisesRegex(ValueError,'Identity/mapping changed'):art.load_inputs()

    def test_every_retained_before_cutout_fails_current_visible_pixel_acceptance(self):
        def visible_bytes(im):
            return bytes(c for r,g,b,a in im.convert('RGBA').getdata()
                         for c in ((r,g,b,a) if a else (0,0,0,0)))
        for key,row in self.recipe['assets'].items():
            with self.subTest(asset=key):
                with Image.open(art.PACKET/(key+'_before.png')) as before, Image.open(art.local(row['original_manifest_entry']['path'])) as after:
                    self.assertNotEqual(visible_bytes(before),visible_bytes(after))

    def test_scoped_art_paths_only(self):
        for path in ['res://content/scenarios/foo.json','res://art/overworld/../towns/foo.png','/tmp/foo.png']:
            with self.subTest(path=path),self.assertRaises(ValueError): art.local(path)

    def test_all_outputs_reproduce_exactly_and_only_selected_metadata_changes(self):
        for key, row in self.recipe['assets'].items():
            with self.subTest(asset=key):
                entry=self.manifest['object_assets'][key]
                self.assertEqual({k:v for k,v in entry.items() if k not in ('source_processing_manifest','runtime_sha256')},row['original_manifest_entry'])
                self.assertEqual(entry['runtime_sha256'],art.digest(art.local(entry['path'])))
                self.assertEqual(entry['runtime_sha256'],self.proof['assets'][key]['runtime_sha256'])
                self.assertEqual(entry['source_processing_manifest'],art.resource(art.PACKET/'manifest.json'))
                expected=art.recover_asset(self.sheet,row)
                with Image.open(art.local(entry['path'])) as actual:
                    self.assertEqual(actual.mode,'RGBA')
                    self.assertEqual(actual.size,(512,512))
                    self.assertEqual(actual.tobytes(),expected.tobytes())
                    self.assertEqual(actual.getchannel('A').getextrema(),(0,255))

    def test_exact_source_alignment_opaque_detail_and_no_dividers(self):
        restored=0
        for key,row in self.recipe['assets'].items():
            with self.subTest(asset=key):
                actual=Image.open(art.local(row['original_manifest_entry']['path'])).convert('RGBA')
                before=Image.open(art.PACKET/(key+'_before.png')).convert('RGBA')
                left,top,right,bottom=row['source_rect'];cx,cy=row['canvas_origin']
                source=self.sheet.crop((left,top,right,bottom));retained=0
                for y in range(source.height):
                    for x in range(source.width):
                        r,g,b=source.getpixel((x,y));px,py=cx+x,cy+y
                        if min(r,b)-g<=8:
                            self.assertEqual(actual.getpixel((px,py)),(r,g,b,255))
                            retained+=1
                            restored+=before.getpixel((px,py))[3]==0
                self.assertGreater(retained,18000)
                bounds=actual.getchannel('A').getbbox()
                self.assertGreater(bounds[0],cx)
                self.assertGreater(bounds[1],cy)
                self.assertLess(bounds[2],cx+source.width)
                self.assertLess(bounds[3],cy+source.height)
        self.assertGreater(restored,1000,'must restore real opaque source detail, not merely trim borders')

    def test_no_magenta_outside_explicit_original_coral(self):
        for key,row in self.recipe['assets'].items():
            with self.subTest(asset=key):
                im=Image.open(art.local(row['original_manifest_entry']['path'])).convert('RGBA')
                left,top,_,_=row['source_rect'];cx,cy=row['canvas_origin']
                for i,(r,g,b,a) in enumerate(im.getdata()):
                    if a<32 or min(r,b)-g<=50 or min(r,b)<=140:continue
                    x,y=i%512-cx+left,i//512-cy+top
                    self.assertTrue(any(l<=x<rr and t<=y<bb for l,t,rr,bb in row.get('protected_source_rects',[])),(key,x,y))


if __name__=='__main__':unittest.main()
