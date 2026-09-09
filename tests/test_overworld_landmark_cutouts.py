"""Original state paint, inspected matte boundaries and immutable gameplay routes."""
import copy
import importlib.util
import json
from pathlib import Path
import unittest
from unittest import mock

import numpy as np
from PIL import Image,ImageFilter

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('state_art',ROOT/'tools/prepare_overworld_landmark_cutouts.py')
art=importlib.util.module_from_spec(spec);spec.loader.exec_module(art)


class LandmarkCutoutTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.recipe,cls.manifest,cls.sources=art.inputs()
        cls.recovered={k:art.recover_source(cls.sources[k],v) for k,v in cls.recipe['assets'].items()}

    def test_complete_five_atlas_40_painting_cohort(self):
        self.assertEqual(len(self.recovered),40)
        self.assertEqual(sorted(v['before_size'][0]//48 for v in self.recipe['atlases'].values()),[6,6,6,8,14])
        self.assertEqual(sum(v['source_mode']=='genuine_rgba' for v in self.recipe['assets'].values()),39)

    def test_original_source_and_interior_paint_are_exact(self):
        for key,row in self.recipe['assets'].items():
            source=self.sources[key];fixed,points=self.recovered[key]
            self.assertEqual(art.base.digest(art.base.local(row['original_manifest_entry']['source_generated'])),row['source_sha256'])
            if row['source_mode']=='genuine_rgba':
                self.assertEqual(source.tobytes(),fixed.tobytes());self.assertFalse(points);continue
            mask=np.zeros((source.height,source.width),dtype='uint8');mask.ravel()[list(points)]=255
            band=np.asarray(Image.fromarray(mask).filter(ImageFilter.MaxFilter(row['matte_boundary_radius']*2+1)))>0
            before=np.asarray(source);after=np.asarray(fixed)
            self.assertTrue(np.array_equal(before[~band,:3],after[~band,:3]),key)
            self.assertTrue(np.all(after[~band,3]==255),key)
            self.assertTrue(np.all(after[mask>0]==0),key)

    def test_every_explicit_backing_seed_is_transparent(self):
        for key,row in self.recipe['assets'].items():
            for c in row['backing_components']:self.assertEqual(self.recovered[key][0].getpixel(tuple(c['seed']))[3],0,key)

    def test_witness_stone_pale_eye_and_candles_are_preserved(self):
        key='resource_site_roads_objectives_witness_stone_activated'
        source=self.sources[key];fixed,points=self.recovered[key]
        for point in [(621,541),(625,560),(629,635),(567,699)]:
            self.assertEqual(source.getpixel(point)[3],255)
            self.assertNotIn(point[1]*source.width+point[0],points)
            self.assertEqual(fixed.getpixel(point),(*source.getpixel(point)[:3],255))

    def test_only_inspected_exterior_is_removed(self):
        key='resource_site_roads_objectives_witness_stone_activated'
        row=self.recipe['assets'][key];fixed,points=self.recovered[key]
        self.assertEqual(len(row['backing_components']),1)
        self.assertEqual(len(points),1437420)
        self.assertEqual(row['backing_components'][0]['seed'],[0,0])
        self.assertEqual(fixed.getpixel((0,0)),(0,0,0,0))

    def test_measured_original_fit_and_anchors(self):
        policies=set()
        for key,row in self.recipe['assets'].items():
            old=row['original_manifest_entry']
            _,limit,anchor=art.FAMILIES[Path(old['path']).stem.removesuffix('_atlas')]
            policies.add((limit,anchor))
            result=art.registration(self.sources[key],row,art.owner.region(art.original(old['path']),old))
            self.assertEqual(result,row['registration_evidence'])
            self.assertLess(result['alpha_mae'],1.1 if key=='resource_site_live_thornwake_graft_arch' else 1)
            self.assertLess(result['opaque_rgb_mae'],1.6)
            shifted=copy.deepcopy(row);shifted['canvas_origin'][0]+=1
            with self.assertRaisesRegex(ValueError,'Original registration'):art.registration(self.sources[key],shifted,art.owner.region(art.original(old['path']),old))
        self.assertEqual(policies,{(44,'center'),(44,'south')})

    def test_current_rasters_reconstruct_from_originals_not_48_upscales(self):
        proof=json.loads((art.PACKET/'manifest.json').read_text())
        self.assertEqual(proof['recipe_sha256'],art.base.digest(art.RECIPE))
        for k,v in art.tool_hashes().items():self.assertEqual(proof[k],v)
        for key,row in self.recipe['assets'].items():
            source,points=self.recovered[key];fixed=art.project(source,row);old=art.owner.region(art.original(row['runtime_path']),row['original_manifest_entry'])
            entry=self.manifest['object_assets'][key];atlas=Image.open(art.base.local(entry['path'])).convert('RGBA')
            self.assertEqual(fixed.size,(192,192));self.assertEqual(art.owner.region(atlas,entry).tobytes(),fixed.tobytes())
            for field,im,sha in [('trimmed_path',fixed,'trim_sha256'),('recovered_source_path',source,'source_sha256')]:
                p=art.base.local(row[field]);self.assertEqual(Image.open(p).convert('RGBA').tobytes(),im.tobytes());self.assertEqual(art.base.digest(p),proof['assets'][key][sha])
            self.assertEqual(entry,dict(art.expected_entry(row),runtime_sha256=art.base.digest(art.base.local(entry['path']))))
            for filter in (Image.Resampling.NEAREST,Image.Resampling.BILINEAR,Image.Resampling.LANCZOS):self.assertNotEqual(old.resize((192,192),filter).tobytes(),fixed.tobytes())

    def test_exact_historical_atlases_and_state_routes(self):
        for path,info in self.recipe['atlases'].items():self.assertEqual(art.base.digest(art.before_path(path)),info['before_sha256'])
        for site,mapping in self.recipe['state_mappings'].items():self.assertEqual(self.manifest['resource_site_sprites'][site],mapping)

    def assert_input_rejected(self,path,value,pattern):
        read=Path.read_text
        with mock.patch.object(Path,'read_text',lambda p,*a,**kw:json.dumps(value) if p==path else read(p,*a,**kw)):
            with self.assertRaisesRegex(ValueError,pattern):art.inputs()

    def test_wrong_mapping_region_and_source_fail_closed(self):
        key=next(iter(self.recovered));m=copy.deepcopy(self.manifest);site=next(iter(self.recipe['state_mappings']));m['resource_site_sprites'][site]['asset_id']='hostile_camp'
        self.assert_input_rejected(art.MANIFEST,m,'State mapping')
        m=copy.deepcopy(self.manifest);m['object_assets'][key]['atlas_region'][0]+=192
        self.assert_input_rejected(art.MANIFEST,m,'Identity changed')
        r=copy.deepcopy(self.recipe);r['assets'][key]['source_sha256']='0'*64
        self.assert_input_rejected(art.RECIPE,r,'Original painting')

    def test_wrong_density_fit_and_alpha_policies_fail_closed(self):
        key=next(iter(self.recovered))
        for field,value,pattern in [('pixel_scale',1,'Density/filter'),('fit_limit',46,'fit/anchor'),('source_mode','retained_rgb','Alpha policy')]:
            r=copy.deepcopy(self.recipe);r['assets'][key][field]=value;self.assert_input_rejected(art.RECIPE,r,pattern)

    def test_expanded_backing_and_genuine_rematting_rejected(self):
        key='resource_site_roads_objectives_witness_stone_activated';row=copy.deepcopy(self.recipe['assets'][key]);row['backing_components'][0]['area']+=1
        with self.assertRaisesRegex(ValueError,'bounds/area'):art.recover_source(self.sources[key],row)
        key='resource_site_live_ember_signal_brazier';row=copy.deepcopy(self.recipe['assets'][key]);row['matte_boundary_radius']=2
        with self.assertRaisesRegex(ValueError,'Genuine RGBA'):art.recover_source(self.sources[key],row)


if __name__=='__main__':unittest.main()
