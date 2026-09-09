"""Original resource-site paint, distinct anchors and unchanged state routes."""
import copy
import importlib.util
import json
from pathlib import Path
import unittest
from unittest import mock
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('recurring_site_recovery',ROOT/'tools/prepare_overworld_recurring_site_cutouts.py')
art=importlib.util.module_from_spec(spec);spec.loader.exec_module(art)


class RecurringSiteCutoutTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.recipe,cls.manifest,cls.sources=art.inputs()
        cls.results={k:art.recover(cls.sources[k],r) for k,r in cls.recipe['assets'].items()}

    def test_exact_thirty_original_regions(self):
        self.assertEqual(len(self.results),30)
        self.assertEqual(sorted(r['original_manifest_entry']['atlas_region'][0] for r in self.recipe['assets'].values()),list(range(0,1440,48)))
        self.assertEqual({r['runtime_path'] for r in self.recipe['assets'].values()},{art.RUNTIME})

    def test_original_source_bytes_and_full_alpha_crop(self):
        for key,row in self.recipe['assets'].items():
            self.assertEqual(art.base.digest(art.base.local(row['original_manifest_entry']['source_generated'])),row['source_sha256'])
            self.assertEqual(list(self.sources[key].getbbox()),row['source_crop'])
            self.assertGreater(len(set(self.sources[key].getchannel('A').getdata())),200)

    def test_exact_distinct_normalized_anchors(self):
        for row in self.recipe['assets'].values():
            later=row['original_manifest_entry']['atlas_region'][0]>=240
            w,h=row['source_resize'];x,y=row['canvas_origin']
            self.assertEqual(max(w,h),44);self.assertEqual(x,(48-w)//2)
            self.assertEqual(y,(46 if later else 48)-h)
            self.assertEqual(row['resampling'],'LANCZOS' if later else 'BILINEAR')

    def test_original_registration_reproduces_visible_paint_and_all_alpha(self):
        atlas=Image.open(art.BEFORE).convert('RGBA')
        for key,row in self.recipe['assets'].items():
            result=art.registration(self.sources[key],row,art.owner.region(atlas,row['original_manifest_entry']))
            self.assertLess(result['alpha_mae'],1)
            self.assertLess(result['opaque_rgb_mae'],1.4)
            if row['original_manifest_entry']['atlas_region'][0]>=240:self.assertEqual(result,dict(alpha_mae=0.0,opaque_rgb_mae=0.0))

    def test_registered_source_rgba_is_entire_new_sprite(self):
        for key,row in self.recipe['assets'].items():
            canvas=Image.new('RGBA',(192,192))
            painted=self.sources[key].crop(row['source_crop']).resize(tuple(v*4 for v in row['source_resize']),getattr(Image.Resampling,row['resampling']))
            canvas.paste(painted,tuple(v*4 for v in row['canvas_origin']))
            self.assertEqual(canvas.tobytes(),self.results[key].tobytes())
            self.assertGreater(art.metrics(canvas)['partial_alpha_pixels'],100)

    def test_not_upscaled_from_blurry_48_pixel_cells(self):
        atlas=Image.open(art.BEFORE).convert('RGBA')
        for key,row in self.recipe['assets'].items():
            old=art.owner.region(atlas,row['original_manifest_entry'])
            for mode in (Image.Resampling.NEAREST,Image.Resampling.BILINEAR,Image.Resampling.LANCZOS):
                self.assertNotEqual(self.results[key].tobytes(),old.resize((192,192),mode).tobytes())

    def test_all_site_and_state_routes_unchanged(self):
        for site,mapping in self.recipe['state_mappings'].items():self.assertEqual(mapping,self.manifest['resource_site_sprites'][site])
        for key,row in self.recipe['assets'].items():
            entry=self.manifest['object_assets'][key]
            self.assertEqual(entry['assigned_resource_site_id'],row['original_manifest_entry']['assigned_resource_site_id'])
            self.assertEqual(entry['accessible_description'],row['original_manifest_entry']['accessible_description'])
            self.assertEqual(entry['atlas_region'],[v*4 for v in row['original_manifest_entry']['atlas_region']])
            self.assertEqual(entry['atlas_size'],[5760,192])

    def test_crystal_and_mushroom_colors_not_matte_classes(self):
        for key in ('resource_site_neutral_crystal_sump','resource_site_neutral_glowcap_croft'):
            self.assertTrue(any(a>128 and min(r,b)>g+35 for r,g,b,a in self.results[key].getdata()))

    def test_original_atlas_preserved_exactly(self):
        self.assertEqual(art.base.digest(art.BEFORE),art.ORIGINAL_SHA)
        with Image.open(art.BEFORE) as image:self.assertEqual(image.size,(1440,48))

    def assert_changed_json_fails(self,path,value,pattern):
        read=Path.read_text
        with mock.patch.object(Path,'read_text',lambda p,*a,**kw:json.dumps(value) if p==path else read(p,*a,**kw)):
            with self.assertRaisesRegex(ValueError,pattern):art.inputs()

    def test_wrong_state_route_and_swapped_identity_fail_closed(self):
        manifest=copy.deepcopy(self.manifest);site=next(iter(self.recipe['state_mappings']))
        manifest['resource_site_sprites'][site]['asset_id']='hostile_camp'
        self.assert_changed_json_fails(art.MANIFEST,manifest,'state mapping')
        manifest=copy.deepcopy(self.manifest);key=next(iter(self.results));manifest['object_assets'][key]['atlas_region'][0]+=192
        self.assert_changed_json_fails(art.MANIFEST,manifest,'identity changed')

    def test_wrong_source_or_density_fails_closed(self):
        recipe=copy.deepcopy(self.recipe);key=next(iter(self.results));recipe['assets'][key]['source_sha256']='0'*64
        self.assert_changed_json_fails(art.RECIPE,recipe,'Source hash')
        recipe=copy.deepcopy(self.recipe);recipe['assets'][key]['pixel_scale']=1
        self.assert_changed_json_fails(art.RECIPE,recipe,'density/filter')

    def test_runtime_and_trim_provenance_reconstructs(self):
        self.assertEqual(len(art.validate_assets()),30)


if __name__=='__main__':unittest.main()
