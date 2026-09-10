"""Source-locked paint recovery, state isolation and unchanged logical geometry."""
import copy
import importlib.util
import json
from pathlib import Path
import unittest
from unittest import mock
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('recruitment_art',ROOT/'tools/prepare_overworld_recruitment_cutouts.py')
art=importlib.util.module_from_spec(spec);spec.loader.exec_module(art)


class RecruitmentCutoutTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.recipe,cls.manifest,cls.sources=art.inputs()

    def test_complete_eighteen_pairs_and_three_atlases(self):
        self.assertEqual(len(self.sources),36)
        self.assertEqual(len(self.recipe['state_mappings']),18)
        self.assertEqual([v['before_size'] for v in self.recipe['atlases'].values()],[[576,48]]*3)
        self.assertEqual(sum(bool(r.get('integrated_state_edit')) for r in self.recipe['assets'].values()),6)
        for site,mapping in self.recipe['state_mappings'].items():
            self.assertEqual(self.manifest['resource_site_sprites'][site],mapping)
            self.assertNotEqual(mapping['asset_id'],mapping['unclaimed_asset_id'])

    def test_every_runtime_and_master_reconstructs(self):
        self.assertEqual(set(art.validate_assets()),set(self.sources))

    def test_unchanged_paint_outside_explicit_repairs(self):
        for key,row in self.recipe['assets'].items():
            source=self.sources[key];a=np.asarray(source);b=np.asarray(art.recover_source(source,row))
            allowed=np.zeros(a.shape[:2],dtype=bool)
            alpha_allowed=allowed.copy()
            if row.get('low_alpha_rgb_repair'):
                allowed|=(a[:,:,3]>0)&(a[:,:,3]<=4)&(a[:,:,:3].max(2)>235)&(a[:,:,:3].min(2)<20)
            if row.get('fragments'):
                fragment=art.fragment_mask(source,row['fragments']);allowed|=fragment;alpha_allowed|=fragment
                self.assertFalse(b[:,:,3][fragment].any())
            if row.get('integrated_state_edit'):
                edit=row['integrated_state_edit'];patch=np.asarray(art.state.state_patch_mask(source.size,edit))>0
                allowed|=patch
                if edit.get('attached_silhouette_extension'):alpha_allowed|=patch
                self.assertTrue(np.any(a[:,:,:3][patch]!=b[:,:,:3][patch]))
                base_row=copy.deepcopy(row);del base_row['integrated_state_edit']
                self.assertNotEqual(art.recover(source,base_row).tobytes(),art.recover(source,row).tobytes())
            self.assertTrue(np.array_equal(a[~allowed],b[~allowed]),key)
            self.assertTrue(np.array_equal(a[:,:,3][~alpha_allowed],b[:,:,3][~alpha_allowed]),key)
            self.assertEqual(art.base.digest(art.base.local(row['original_manifest_entry']['source_generated'])),row['source_sha256'])

    def test_historical_registration_and_runtime_density(self):
        for key,row in self.recipe['assets'].items():
            old=art.owner.region(art.original(row['runtime_path']),row['original_manifest_entry'])
            self.assertEqual(art.registration(self.sources[key],row,old),row['registration_evidence'])
            shifted=copy.deepcopy(row);shifted['canvas_origin'][0]+=1
            with self.assertRaisesRegex(ValueError,'registration'):art.registration(self.sources[key],shifted,old)
            self.assertNotEqual(art.recover(self.sources[key],row).tobytes(),old.resize((192,192),Image.Resampling.LANCZOS).tobytes())

    def rejected(self,path,value,pattern):
        read=Path.read_text
        with mock.patch.object(Path,'read_text',lambda p,*a,**kw:json.dumps(value) if p==path else read(p,*a,**kw)):
            with self.assertRaisesRegex(ValueError,pattern):art.inputs()

    def test_wrong_routes_sources_and_regions_fail_closed(self):
        key=next(iter(self.sources));site=next(iter(self.recipe['state_mappings']))
        m=copy.deepcopy(self.manifest);m['resource_site_sprites'][site]['asset_id']='hostile_camp';self.rejected(art.MANIFEST,m,'State mapping')
        m=copy.deepcopy(self.manifest);m['object_assets'][key]['atlas_region'][0]+=192;self.rejected(art.MANIFEST,m,'Identity changed')
        r=copy.deepcopy(self.recipe);r['assets'][key]['source_sha256']='0'*64;self.rejected(art.RECIPE,r,'Original painting')

    def test_density_alpha_and_generated_identity_fail_closed(self):
        key=next(iter(self.sources))
        for field,value,pattern in [('source_mode','color_key','Alpha policy'),('source_crop',[0,0,10,10],'Source crop'),('pixel_scale',1,'Density/filter'),('fit_limit',40,'fit/anchor')]:
            r=copy.deepcopy(self.recipe);r['assets'][key][field]=value;self.rejected(art.RECIPE,r,pattern)
        key='resource_site_neutral_cindervane_updraft_roost_controlled'
        r=copy.deepcopy(self.recipe);r['assets'][key]['integrated_state_edit']['source']=r['assets']['resource_site_neutral_fenmirror_shell_basin_controlled']['integrated_state_edit']['source'];self.rejected(art.RECIPE,r,'identity mismatch')

    def test_generated_backing_cannot_enter_foreground_patch(self):
        key='resource_site_neutral_gaugecoil_pressure_burrow_controlled';row=copy.deepcopy(self.recipe['assets'][key])
        row['integrated_state_edit']['patches']=[{'rect':[0,0,100,100],'feather':3}]
        with self.assertRaisesRegex(ValueError,'reached background'):art.recover_source(self.sources[key],row)


if __name__=='__main__':unittest.main()
