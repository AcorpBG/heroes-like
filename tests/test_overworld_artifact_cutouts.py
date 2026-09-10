"""Original artifact painting, identity and unchanged clean-control invariants."""
import copy
import importlib.util
import json
from pathlib import Path
import unittest
from unittest import mock

import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('artifact_art',ROOT/'tools/prepare_overworld_artifact_cutouts.py')
art=importlib.util.module_from_spec(spec);spec.loader.exec_module(art)


class ArtifactCutoutTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.recipe,cls.manifest,cls.sources=art.inputs()

    def reject(self,path,value,pattern):
        read=Path.read_text
        with mock.patch.object(Path,'read_text',lambda p,*a,**kw:json.dumps(value) if p==path else read(p,*a,**kw)):
            with self.assertRaisesRegex(ValueError,pattern):art.inputs()

    def test_complete_cohort_and_clean_controls(self):
        self.assertEqual(len(self.sources),36)
        self.assertEqual(len(self.recipe['assets']),69)
        self.assertEqual(len(self.recipe['preserved_controls']),33)
        self.assertEqual(len(self.recipe['files']),36)
        for key,control in self.recipe['preserved_controls'].items():
            self.assertEqual(art.base.digest(art.local(control['path'])),control['sha256'])
            self.assertEqual(self.manifest['object_assets'][key],control['original_manifest_entry'])

    def test_all_current_pixels_reconstruct(self):self.assertEqual(set(art.validate_assets()),set(self.recipe['assets']))

    def test_original_masters_not_inventory_upscales(self):
        for key,source in self.sources.items():
            row=self.recipe['assets'][key]
            self.assertGreaterEqual(min(source.size),1024)
            self.assertEqual(art.rgba(art.local(row['icon_path'])).size,(128,128))
            fixed=art.project(art.shared.recover_source(source,row),row)
            old=art.owner.region(art.original(row['runtime_path']),row['original_manifest_entry'])
            self.assertNotEqual(fixed.tobytes(),old.resize(fixed.size,Image.Resampling.LANCZOS).tobytes())

    def test_all_alpha_and_unselected_rgb_preserved(self):
        for key,source in self.sources.items():
            row=self.recipe['assets'][key];before=np.asarray(source)
            after=np.asarray(art.shared.recover_source(source,row));mask=art.shared.noise_mask(source)
            self.assertTrue(np.array_equal(before[:,:,3],after[:,:,3]),key)
            self.assertTrue(np.array_equal(before[~mask],after[~mask]),key)

    def test_inventory_icons_routes_and_history_unchanged(self):
        self.assertEqual(self.manifest['artifact_field_sprites'],self.recipe['identity_mappings'])
        for row in self.recipe['assets'].values():
            self.assertEqual(art.base.digest(art.local(row['icon_path'])),row['icon_sha256'])
        for path,info in self.recipe['files'].items():
            original=art.local(path) if info['preserved'] else art.before_path(path)
            self.assertEqual(art.base.digest(original),info['before_sha256'])

    def test_mapping_region_source_and_icon_fail_closed(self):
        key=next(iter(self.sources));identity=next(iter(self.recipe['identity_mappings']))
        value=copy.deepcopy(self.manifest);value['artifact_field_sprites'][identity]='hostile_camp';self.reject(art.MANIFEST,value,'routes')
        value=copy.deepcopy(self.manifest);value['object_assets'][key]['atlas_region'][0]+=192;self.reject(art.MANIFEST,value,'metadata')
        for field,pattern in [('source_sha256','source or provenance'),('source_manifest_sha256','source or provenance'),('icon_sha256','Inventory icon')]:
            value=copy.deepcopy(self.recipe);value['assets'][key][field]='0'*64;self.reject(art.RECIPE,value,pattern)

    def test_crop_density_anchor_and_noise_fail_closed(self):
        key=next(iter(self.sources))
        for field,value,pattern in [('source_crop',[0,0,10,10],'fit or anchor'),('canvas_origin',[0,0],'fit or anchor'),('pixel_scale',1,'fit or anchor'),('low_alpha_rgb_pixels',-1,'RGB noise')]:
            altered=copy.deepcopy(self.recipe);altered['assets'][key][field]=value;self.reject(art.RECIPE,altered,pattern)

    def test_scope_and_legitimate_purple(self):
        for path in ['res://content/artifacts.json','res://art/artifacts/../other.png']:
            with self.assertRaises(ValueError):art.local(path)
        source=Image.new('RGBA',(3,1));source.putdata([(255,0,255,255),(255,0,255,4),(255,0,255,5)])
        self.assertEqual(art.shared.recover_source(source,{'low_alpha_rgb_pixels':1}).tobytes(),source.tobytes())


if __name__=='__main__':unittest.main()
