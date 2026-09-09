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
spec=importlib.util.spec_from_file_location('state_art',ROOT/'tools/prepare_overworld_state_cutouts.py')
art=importlib.util.module_from_spec(spec);spec.loader.exec_module(art)


class StateCutoutTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.recipe,cls.manifest,cls.sources=art.inputs()
        cls.recovered={k:art.recover_source(cls.sources[k],v) for k,v in cls.recipe['assets'].items()}

    def test_complete_six_atlas_34_painting_cohort(self):
        self.assertEqual(len(self.recovered),34)
        self.assertEqual(sorted(v['before_size'][0]//48 for v in self.recipe['atlases'].values()),[3,5,6,6,6,8])
        self.assertEqual(sum(v['source_mode']=='genuine_rgba' for v in self.recipe['assets'].values()),17)

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

    def test_pale_foreground_is_not_classified_as_backing(self):
        # Explicit interior source coordinates: crystal faces, snow, canvas.
        for stem,point in [('major_vault_prism_ossuary_unsealed',(586,242)),('guarded_route_frostford_hold_opened',(701,368)),('repeatable_service_wayfarer_menders_tent_visited',(625,680))]:
            key='resource_site_'+stem;source=self.sources[key];fixed,points=self.recovered[key]
            self.assertNotIn(point[1]*source.width+point[0],points)
            self.assertEqual(fixed.getpixel(point),(*source.getpixel(point)[:3],255),key)

    def test_known_enclosed_gate_and_rope_backing_removed(self):
        for stem,point in [('guarded_route_bridge_bastion_opened',(640,570)),('guarded_route_frostford_hold_opened',(660,580)),('repeatable_service_wayfarer_menders_tent_visited',(460,550)),('repeatable_service_courier_change_post_visited',(430,570))]:
            key='resource_site_'+stem
            self.assertGreater(self.sources[key].getpixel(point)[3],0,key)
            self.assertEqual(self.recovered[key][0].getpixel(point)[3],0,key)

    def test_measured_three_original_fit_and_anchor_policies(self):
        policies=set()
        for key,row in self.recipe['assets'].items():
            old=row['original_manifest_entry'];policies.add((row['fit_limit'],'south' if 'repeatable_service' in key else 'center'))
            result=art.shared.registration(self.sources[key],row,art.owner.region(art.original(old['path']),old))
            self.assertLess(result['alpha_mae'],1);self.assertLess(result['opaque_rgb_mae'],1.6)
            self.assertEqual(row['source_crop'],list(self.sources[key].getbbox()))
        self.assertEqual(policies,{(42,'center'),(44,'center'),(46,'south')})

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
        for field,value,pattern in [('pixel_scale',1,'Density/filter'),('fit_limit',46,'fit/anchor'),('source_mode','genuine_rgba','Alpha policy')]:
            r=copy.deepcopy(self.recipe);r['assets'][key][field]=value;self.assert_input_rejected(art.RECIPE,r,pattern)

    def test_expanded_backing_and_genuine_rematting_rejected(self):
        key=next(iter(self.recovered));row=copy.deepcopy(self.recipe['assets'][key]);row['backing_components'][0]['area']+=1
        with self.assertRaisesRegex(ValueError,'bounds/area'):art.recover_source(self.sources[key],row)
        key='resource_site_scouting_hilltop_signal_nest_controlled';row=copy.deepcopy(self.recipe['assets'][key]);row['matte_boundary_radius']=2
        with self.assertRaisesRegex(ValueError,'Genuine RGBA'):art.recover_source(self.sources[key],row)


if __name__=='__main__':unittest.main()
