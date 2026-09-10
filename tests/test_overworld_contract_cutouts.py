"""Fifty-two exact paintings, scoped RGB repair and immutable logical placement."""
import copy
import importlib.util
import json
from pathlib import Path
import unittest
from unittest import mock

import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('contract_art',ROOT/'tools/prepare_overworld_contract_cutouts.py')
art=importlib.util.module_from_spec(spec);spec.loader.exec_module(art)


class ContractCutoutTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.recipe,cls.manifest,cls.sources=art.inputs()

    def reject(self,path,value,pattern):
        read=Path.read_text
        with mock.patch.object(Path,'read_text',lambda p,*a,**kw:json.dumps(value) if p==path else read(p,*a,**kw)):
            with self.assertRaisesRegex(ValueError,pattern):art.inputs()

    def test_complete_nine_atlas_cohort(self):
        self.assertEqual(len(self.sources),52)
        self.assertEqual(sorted(v['before_size'][0]//48 for v in self.recipe['atlases'].values()),[4,6,6,6,6,6,6,6,6])
        self.assertEqual(len(self.recipe['identity_mappings']),52)
        self.assertEqual(len({r['source_sha256'] for r in self.recipe['assets'].values()}),52)

    def test_all_current_pixels_reconstruct_from_originals(self):
        self.assertEqual(set(art.validate_assets()),set(self.sources))

    def test_only_reviewed_near_transparent_rgb_can_change(self):
        for key,row in self.recipe['assets'].items():
            source=self.sources[key];before=np.asarray(source);after=np.asarray(art.recover_source(source,row));mask=art.noise_mask(source)
            self.assertTrue(np.array_equal(before[:,:,3],after[:,:,3]),key)
            self.assertTrue(np.array_equal(before[~mask],after[~mask]),key)
            self.assertEqual(source.tobytes(),Image.open(art.base.local(row['original_manifest_entry']['source_generated'])).convert('RGBA').tobytes())
            fixed=art.project(Image.fromarray(after),row)
            old=art.owner.region(art.original(row['runtime_path']),row['original_manifest_entry'])
            self.assertNotEqual(fixed.tobytes(),old.resize((192,192),Image.Resampling.LANCZOS).tobytes())

    def test_saturated_opaque_purple_is_never_a_color_key(self):
        source=Image.new('RGBA',(3,1));source.putdata([(255,0,255,255),(255,0,255,4),(255,0,255,5)])
        result=art.recover_source(source,{'low_alpha_rgb_pixels':1})
        self.assertEqual(result.tobytes(),source.tobytes())

    def test_exact_vs_cross_filter_history_is_honest(self):
        exact=0
        for key,row in self.recipe['assets'].items():
            before=art.owner.region(art.original(row['runtime_path']),row['original_manifest_entry'])
            evidence=art.registration(self.sources[key],row,before)
            self.assertEqual(evidence,row['registration_evidence'])
            if row['historical_registration']=='exact_lanczos':
                exact+=1;self.assertEqual(evidence,dict(alpha_mae=0.0,opaque_rgb_mae=0.0))
        self.assertEqual(exact,0)

    def test_all_identity_routes_and_original_archives_preserved(self):
        for site,mapping in self.recipe['identity_mappings'].items():
            self.assertEqual(self.manifest['encounter_identity_sprites'][site],mapping)
        for path,info in self.recipe['atlases'].items():self.assertEqual(art.base.digest(art.before_path(path)),info['before_sha256'])

    def test_bad_mapping_region_and_source_fail_closed(self):
        key=next(iter(self.sources));site=next(iter(self.recipe['identity_mappings']))
        m=copy.deepcopy(self.manifest);m['encounter_identity_sprites'][site]='hostile_camp';self.reject(art.MANIFEST,m,'Identity mapping')
        m=copy.deepcopy(self.manifest);m['object_assets'][key]['atlas_region'][0]+=192;self.reject(art.MANIFEST,m,'Identity changed')
        r=copy.deepcopy(self.recipe);r['assets'][key]['source_sha256']='0'*64;self.reject(art.RECIPE,r,'Original painting')

    def test_alpha_crop_density_anchor_and_noise_fail_closed(self):
        key=next(iter(self.sources))
        for field,value,pattern in [('source_mode','color_key','Alpha policy'),('source_crop',[0,0,10,10],'Source crop'),('pixel_scale',1,'Density/filter'),('fit_limit',42,'fit/anchor'),('canvas_origin',[6,3],'fit/anchor'),('alignment','center','fit/anchor'),('low_alpha_rgb_pixels',0,'RGB noise'),('source_manifest_sha256','0'*64,'Source provenance')]:
            r=copy.deepcopy(self.recipe);r['assets'][key][field]=value;self.reject(art.RECIPE,r,pattern)


if __name__=='__main__':unittest.main()
