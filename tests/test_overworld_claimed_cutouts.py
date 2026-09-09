"""Original claimed paint, explicit backing, exact registration and state routes."""
import copy
import importlib.util
import json
from pathlib import Path
import unittest
from unittest import mock

import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('claimed_art',ROOT/'tools/prepare_overworld_claimed_cutouts.py')
art=importlib.util.module_from_spec(spec);spec.loader.exec_module(art)


class ClaimedCutoutTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.recipe,cls.manifest,cls.sources=art.inputs()
        cls.recovered={k:art.recover_source(cls.sources[k],r) for k,r in cls.recipe['assets'].items()}

    def test_all_thirty_one_paintings_and_three_atlases(self):
        self.assertEqual(len(self.recovered),31)
        self.assertEqual(sorted(i['before_size'][0]//48 for i in self.recipe['atlases'].values()),[7,8,16])
        self.assertEqual(sum(r['source_mode']=='genuine_rgba' for r in self.recipe['assets'].values()),6)

    def test_immutable_original_paint_and_exact_backing_only(self):
        for key,row in self.recipe['assets'].items():
            source=self.sources[key];fixed,points=self.recovered[key]
            self.assertEqual(art.base.digest(art.base.local(row['original_manifest_entry']['source_generated'])),row['source_sha256'])
            if row['source_mode']=='genuine_rgba':
                self.assertEqual(fixed.tobytes(),source.tobytes());self.assertFalse(points);continue
            before=np.asarray(source).reshape(-1,4);after=np.asarray(fixed).reshape(-1,4);mask=np.ones(len(before),bool);mask[list(points)]=False
            self.assertTrue(np.array_equal(before[mask,:3],after[mask,:3]))
            self.assertTrue(np.all(after[mask,3]==255));self.assertTrue(np.all(after[~mask]==0))

    def test_erased_salt_snow_and_canvas_are_restored(self):
        for stem,point in [('saltpan_camp',(636,480)),('saltpan_camp',(947,564)),('icehook_trapper_lodge',(770,182)),('kite_signal_eyrie',(655,44))]:
            key='resource_site_neutral_'+stem+'_claimed';source=self.sources[key];fixed,_=self.recovered[key]
            self.assertEqual(source.getpixel(point)[3],0)
            self.assertEqual(fixed.getpixel(point),(*source.getpixel(point)[:3],255))

    def test_snow_cap_at_canvas_edge_not_exterior_backing(self):
        key='resource_site_neutral_icehook_trapper_lodge_claimed';fixed,_=self.recovered[key]
        self.assertEqual(fixed.getpixel((934,0))[3],255)

    def test_original_normalized_source_registration(self):
        for key,row in self.recipe['assets'].items():
            old=row['original_manifest_entry'];w,h=row['source_resize'];first=Path(old['path']).name=='neutral_dwelling_claimed_atlas.png'
            self.assertEqual(row['canvas_origin'],[(48-w)//2,48-h if first else (48-h)//2])
            self.assertEqual(row['source_crop'],list(self.sources[key].getbbox()))
            result=art.registration(self.sources[key],row,art.owner.region(art.original(old['path']),old))
            self.assertLess(result['alpha_mae'],1);self.assertLess(result['opaque_rgb_mae'],1.6)

    def test_all_explicit_backing_components_are_transparent(self):
        for key,row in self.recipe['assets'].items():
            fixed,_=self.recovered[key]
            for c in row['backing_components']:self.assertEqual(fixed.getpixel(tuple(c['seed']))[3],0)

    def test_not_old_48_pixel_upscales(self):
        for key,row in self.recipe['assets'].items():
            fixed=art.project(self.recovered[key][0],row);old=art.owner.region(art.original(row['runtime_path']),row['original_manifest_entry'])
            self.assertEqual(fixed.size,(192,192))
            for resampling in (Image.Resampling.NEAREST,Image.Resampling.BILINEAR,Image.Resampling.LANCZOS):self.assertNotEqual(fixed.tobytes(),old.resize((192,192),resampling).tobytes())

    def test_all_state_routes_and_original_atlases_preserved(self):
        for site,mapping in self.recipe['state_mappings'].items():self.assertEqual(mapping,self.manifest['resource_site_sprites'][site])
        for path,info in self.recipe['atlases'].items():self.assertEqual(art.base.digest(art.before_path(path)),info['before_sha256'])

    def assert_input_change_rejected(self,path,value,pattern):
        read=Path.read_text
        with mock.patch.object(Path,'read_text',lambda p,*a,**kw:json.dumps(value) if p==path else read(p,*a,**kw)):
            with self.assertRaisesRegex(ValueError,pattern):art.inputs()

    def test_wrong_state_and_swapped_region_fail_closed(self):
        m=copy.deepcopy(self.manifest);site=next(iter(self.recipe['state_mappings']));m['resource_site_sprites'][site]['asset_id']='hostile_camp'
        self.assert_input_change_rejected(art.MANIFEST,m,'state mapping')
        m=copy.deepcopy(self.manifest);key=next(iter(self.recovered));m['object_assets'][key]['atlas_region'][0]+=192
        self.assert_input_change_rejected(art.MANIFEST,m,'identity changed')

    def test_source_hash_and_density_fail_closed(self):
        key=next(iter(self.recovered));r=copy.deepcopy(self.recipe);r['assets'][key]['source_sha256']='0'*64
        self.assert_input_change_rejected(art.RECIPE,r,'Source hash')
        r=copy.deepcopy(self.recipe);r['assets'][key]['pixel_scale']=1
        self.assert_input_change_rejected(art.RECIPE,r,'density/filter')

    def test_changed_backing_area_and_genuine_alpha_keying_rejected(self):
        key='resource_site_neutral_fenhound_kennels_claimed';r=copy.deepcopy(self.recipe['assets'][key]);r['backing_components'][0]['area']+=1
        with self.assertRaisesRegex(ValueError,'bounds/area'):art.recover_source(self.sources[key],r)
        key='resource_site_neutral_roadward_lodge_claimed';r=copy.deepcopy(self.recipe['assets'][key]);r['backing_components']=[{}]
        with self.assertRaisesRegex(ValueError,'Genuine alpha'):art.recover_source(self.sources[key],r)

    def test_full_source_trim_runtime_provenance(self):
        self.assertEqual(len(art.validate_assets()),31)


if __name__=='__main__':unittest.main()
