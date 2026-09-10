"""Exact original paint, source registration and site-route preservation."""
import copy
import importlib.util
import json
from pathlib import Path
import unittest
from unittest import mock

import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('remaining_sites',ROOT/'tools/prepare_overworld_remaining_site_cutouts.py')
art=importlib.util.module_from_spec(spec);spec.loader.exec_module(art)


class RemainingSiteCutoutTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.recipe,cls.manifest,cls.sources=art.inputs()

    def reject(self,path,value,pattern):
        read=Path.read_text
        with mock.patch.object(Path,'read_text',lambda p,*a,**kw:json.dumps(value) if p==path else read(p,*a,**kw)):
            with self.assertRaisesRegex(ValueError,pattern):art.inputs()

    def test_complete_membership_and_source_history(self):
        self.assertEqual(len(self.sources),54);self.assertEqual(len(self.recipe['files']),9)
        for row in self.recipe['assets'].values():
            self.assertEqual(art.base.digest(art.base.local(row['source_manifest'])),row['source_manifest_sha256'])
        for path,info in self.recipe['files'].items():self.assertEqual(art.base.digest(art.before_path(path)),info['before_sha256'])

    def test_all_current_pixels_reconstruct(self):self.assertEqual(set(art.validate_assets()),set(self.recipe['assets']))

    def test_original_alpha_and_unselected_rgb_retained(self):
        for key,source in self.sources.items():
            before=np.asarray(source);after=np.asarray(art.shared.recover_source(source,self.recipe['assets'][key]));mask=art.shared.noise_mask(source)
            self.assertTrue(np.array_equal(before[:,:,3],after[:,:,3]),key)
            self.assertTrue(np.array_equal(before[~mask],after[~mask]),key)

    def test_native_source_not_old_cell_upscale(self):
        for key,source in self.sources.items():
            self.assertGreaterEqual(min(source.size),512)
            row=self.recipe['assets'][key];fixed=art.project(art.shared.recover_source(source,row),row)
            old=art.owner.region(art.original(row['runtime_path']),row['original_manifest_entry'])
            self.assertNotEqual(fixed.tobytes(),old.resize((192,192),Image.Resampling.LANCZOS).tobytes())

    def test_curated_canvases_and_real_setbound_anchor(self):
        curated=[r for r in self.recipe['assets'].values() if r['registration_mode']=='full_canvas']
        self.assertEqual(len(curated),12)
        for row in curated:
            self.assertEqual(row['source_crop'],[0,0,512,512]);self.assertEqual(row['canvas_origin'],[0,0])
            self.assertEqual(row['historical_registration'],dict(alpha_mae=0,opaque_rgb_mae=0))
        for row in self.recipe['assets'].values():
            if 'setbound_regalia' in row['runtime_path']:
                self.assertEqual(row['registration_mode'],'bottom42')
                self.assertEqual(row['canvas_origin'][1],48-row['source_resize'][1])

    def test_identity_region_and_state_fail_closed(self):
        key=next(iter(self.sources));site=next(iter(self.recipe['state_mappings']))
        value=copy.deepcopy(self.manifest);value['resource_site_sprites'][site]['asset_id']='hostile_camp';self.reject(art.MANIFEST,value,'State route')
        value=copy.deepcopy(self.manifest);value['object_assets'][key]['atlas_region'][0]+=192;self.reject(art.MANIFEST,value,'metadata')

    def test_source_crop_anchor_noise_fail_closed(self):
        key=next(iter(self.sources))
        for field,value,pattern in [('source_sha256','0'*64,'source or provenance'),('source_manifest_sha256','0'*64,'source or provenance'),('source_crop',[0,0,10,10],'fit/anchor'),('canvas_origin',[0,0],'fit/anchor'),('pixel_scale',1,'fit/anchor'),('low_alpha_rgb_pixels',-1,'RGB noise')]:
            altered=copy.deepcopy(self.recipe);altered['assets'][key][field]=value;self.reject(art.RECIPE,altered,pattern)

    def test_genuine_purple_opaque_paint_is_not_removed(self):
        source=Image.new('RGBA',(3,1));source.putdata([(255,0,255,255),(255,0,255,4),(255,0,255,5)])
        self.assertEqual(art.shared.recover_source(source,{'low_alpha_rgb_pixels':1}).tobytes(),source.tobytes())


if __name__=='__main__':unittest.main()
