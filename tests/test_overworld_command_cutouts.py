"""Original source pixels, exact identity and immutable logical registrations."""
import copy
import importlib.util
import json
from pathlib import Path
import unittest
from unittest import mock

from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('command_art',ROOT/'tools/prepare_overworld_command_cutouts.py')
art=importlib.util.module_from_spec(spec);spec.loader.exec_module(art)


class CommandCutoutTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.recipe,cls.manifest,cls.sources=art.inputs()

    def test_complete_three_atlas_cohort(self):
        self.assertEqual(len(self.sources),34)
        self.assertEqual(sorted(v['before_size'][0]//48 for v in self.recipe['atlases'].values()),[10,12,12])
        self.assertEqual(len(self.recipe['state_mappings']),34)

    def test_all_current_pixels_reconstruct_from_originals(self):
        self.assertEqual(set(art.validate_assets()),set(self.sources))
        for key,row in self.recipe['assets'].items():
            source=self.sources[key]
            original=Image.open(art.base.local(row['original_manifest_entry']['source_generated'])).convert('RGBA').tobytes()
            fixed=art.project(source,row)
            self.assertEqual(source.tobytes(),original)
            old=art.owner.region(art.original(row['runtime_path']),row['original_manifest_entry'])
            self.assertNotEqual(fixed.tobytes(),old.resize((192,192),Image.Resampling.LANCZOS).tobytes())

    def test_exact_historical_fit_and_centered_registration(self):
        for key,row in self.recipe['assets'].items():
            before=art.owner.region(art.original(row['runtime_path']),row['original_manifest_entry'])
            self.assertEqual(art.registration(self.sources[key],row,before),row['registration_evidence'])
            shifted=copy.deepcopy(row);shifted['canvas_origin'][0]+=1
            with self.assertRaisesRegex(ValueError,'Original registration'):art.registration(self.sources[key],shifted,before)

    def test_state_routes_and_original_archives_are_exact(self):
        for site,mapping in self.recipe['state_mappings'].items():
            self.assertEqual(self.manifest['resource_site_sprites'][site],mapping)
            self.assertEqual(mapping['asset_id'],mapping['unclaimed_asset_id'])
        for path,info in self.recipe['atlases'].items():self.assertEqual(art.base.digest(art.before_path(path)),info['before_sha256'])

    def assert_input_rejected(self,path,value,pattern):
        read=Path.read_text
        with mock.patch.object(Path,'read_text',lambda p,*a,**kw:json.dumps(value) if p==path else read(p,*a,**kw)):
            with self.assertRaisesRegex(ValueError,pattern):art.inputs()

    def test_wrong_mapping_region_and_source_fail_closed(self):
        key=next(iter(self.sources));m=copy.deepcopy(self.manifest);site=next(iter(self.recipe['state_mappings']))
        m['resource_site_sprites'][site]['asset_id']='hostile_camp';self.assert_input_rejected(art.MANIFEST,m,'State mapping')
        m=copy.deepcopy(self.manifest);m['object_assets'][key]['atlas_region'][0]+=192;self.assert_input_rejected(art.MANIFEST,m,'Identity changed')
        r=copy.deepcopy(self.recipe);r['assets'][key]['source_sha256']='0'*64;self.assert_input_rejected(art.RECIPE,r,'Original painting')

    def test_alpha_crop_density_and_fit_edits_fail_closed(self):
        key=next(iter(self.sources))
        for field,value,pattern in [('source_mode','color_key','Alpha policy'),('source_crop',[0,0,10,10],'Source crop'),('pixel_scale',1,'Density/filter'),('fit_limit',44,'fit/anchor')]:
            r=copy.deepcopy(self.recipe);r['assets'][key][field]=value;self.assert_input_rejected(art.RECIPE,r,pattern)


if __name__=='__main__':unittest.main()
