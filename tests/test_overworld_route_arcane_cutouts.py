"""Original-paint reconstruction, exact state ink and fail-closed ownership."""
import copy
import importlib.util
import json
from pathlib import Path
import unittest
from unittest import mock

import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('route_art',ROOT/'tools/prepare_overworld_route_arcane_cutouts.py')
art=importlib.util.module_from_spec(spec);spec.loader.exec_module(art)


class RouteArcaneCutoutTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.recipe,cls.manifest,cls.sources=art.inputs()

    def test_complete_54_paintings_eight_atlases(self):
        self.assertEqual(len(self.recipe['assets']),54)
        self.assertEqual(len(self.recipe['atlases']),8)
        self.assertEqual(sum('generated_edit' in r for r in self.recipe['assets'].values()),2)
        self.assertEqual(sum('state_ink' in r for r in self.recipe['assets'].values()),7)

    def test_fifty_two_genuine_source_masters_remain_byte_exact(self):
        for key,row in self.recipe['assets'].items():
            if 'generated_edit' in row:continue
            master=Image.open(art.base.local(row['recovered_source_path'])).convert('RGBA')
            self.assertEqual(master.tobytes(),self.sources[key].tobytes(),key)

    def test_original_state_ink_is_sampled_not_redrawn(self):
        for key,row in self.recipe['assets'].items():
            if 'state_ink' not in row:continue
            old=row['original_manifest_entry'];ink=art.owner.region(art.original(old['path']),old)
            fixed=Image.open(art.base.local(row['trimmed_path'])).convert('RGBA')
            for i in row['state_ink']['pixels']:
                for dy in range(4):
                    for dx in range(4):self.assertEqual(fixed.getpixel((4*(i%48)+dx,4*(i//48)+dy)),ink.getpixel((i%48,i//48)))

    def test_original_smoke_coral_and_inspected_backing(self):
        for key,row in self.recipe['assets'].items():
            if 'generated_edit' not in row:continue
            edit=row['generated_edit'];master=Image.open(art.base.local(row['recovered_source_path'])).convert('RGBA')
            raw=Image.open(art.base.local(edit['source'])).convert('RGBA')
            self.assertEqual(master.size,(1774,887));self.assertEqual(row['source_resize'],[46,23]);self.assertEqual(row['canvas_origin'],[1,12])
            self.assertEqual(art.base.inspect(master)['magenta_review_pixels'],0)
            for p in edit['background_corner_points']+edit.get('rail_backing_points',[]):self.assertEqual(master.getpixel(tuple(p)),(0,0,0,0))
            for rect in edit.get('original_smoke_rects',[]):
                smoke=Image.open(art.base.local(edit['smoke_source'])).convert('RGBA')
                self.assertEqual(master.crop(rect).tobytes(),smoke.crop(rect).tobytes())
            for rect in edit['protected_rects']:
                self.assertEqual(master.crop(rect).tobytes(),raw.crop(rect).tobytes())

    def test_runtime_is_original_detail_not_old_48_upscale(self):
        proof=json.loads((art.PACKET/'manifest.json').read_text())
        self.assertEqual(proof['recipe_sha256'],art.base.digest(art.RECIPE))
        for k,v in art.tool_hashes().items():self.assertEqual(proof[k],v)
        for key,row in self.recipe['assets'].items():
            entry=self.manifest['object_assets'][key];atlas=Image.open(art.base.local(entry['path'])).convert('RGBA')
            fixed=Image.open(art.base.local(row['trimmed_path'])).convert('RGBA')
            self.assertEqual(fixed.size,(192,192));self.assertEqual(art.owner.region(atlas,entry).tobytes(),fixed.tobytes())
            self.assertEqual(entry,dict(art.expected_entry(row),runtime_sha256=art.base.digest(art.base.local(entry['path']))))
            old=art.owner.region(art.original(row['runtime_path']),row['original_manifest_entry'])
            for filter in (Image.Resampling.NEAREST,Image.Resampling.BILINEAR,Image.Resampling.LANCZOS):self.assertNotEqual(fixed.tobytes(),old.resize((192,192),filter).tobytes())

    def test_historical_sources_state_routes_and_registration(self):
        for path,info in self.recipe['atlases'].items():self.assertEqual(art.base.digest(art.before_path(path)),info['before_sha256'])
        for site,mapping in self.recipe['state_mappings'].items():self.assertEqual(self.manifest['resource_site_sprites'][site],mapping)
        for key,row in self.recipe['assets'].items():
            self.assertEqual(art.registration(self.sources[key],row),row['registration_evidence'])
            # Recorded historical comparison, not invented exact pipeline parity.
            self.assertLess(row['registration_evidence']['alpha_mae'],1.3)
            self.assertLess(row['registration_evidence']['opaque_rgb_mae'],7)
            self.assertEqual(art.base.digest(art.base.local(row['original_manifest_entry']['source_generated'])),row['source_sha256'])

    def assert_rejected(self,path,value,pattern):
        read=Path.read_text
        with mock.patch.object(Path,'read_text',lambda p,*a,**kw:json.dumps(value) if p==path else read(p,*a,**kw)):
            with self.assertRaisesRegex(ValueError,pattern):art.inputs()

    def test_bad_identity_region_mapping_and_source_fail_closed(self):
        key=next(iter(self.sources));site=self.recipe['assets'][key]['site_id']
        m=copy.deepcopy(self.manifest);m['resource_site_sprites'][site]['asset_id']='hostile_camp';self.assert_rejected(art.MANIFEST,m,'State mapping')
        m=copy.deepcopy(self.manifest);m['object_assets'][key]['atlas_region'][0]+=192;self.assert_rejected(art.MANIFEST,m,'Identity changed')
        r=copy.deepcopy(self.recipe);r['assets'][key]['source_sha256']='0'*64;self.assert_rejected(art.RECIPE,r,'Original painting')

    def test_bad_density_anchor_generated_source_fail_closed(self):
        key=next(iter(self.sources))
        for field,value,pattern in [('pixel_scale',1,'Density'),('canvas_origin',[0,0],'fit/anchor')]:
            r=copy.deepcopy(self.recipe);r['assets'][key][field]=value;self.assert_rejected(art.RECIPE,r,pattern)
        r=copy.deepcopy(self.recipe);r['additional_sources'][next(iter(r['additional_sources']))]='0'*64;self.assert_rejected(art.RECIPE,r,'Generated/reference')


if __name__=='__main__':unittest.main()
