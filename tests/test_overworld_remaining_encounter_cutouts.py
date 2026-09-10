"""79 original-paint repairs, six clean controls and unchanged encounter routes."""
import copy
import importlib.util
import json
from pathlib import Path
import unittest
from unittest import mock

import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('remaining_art',ROOT/'tools/prepare_overworld_remaining_encounter_cutouts.py')
art=importlib.util.module_from_spec(spec);spec.loader.exec_module(art)


class RemainingEncounterCutoutTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.recipe,cls.manifest,cls.sources=art.inputs()

    def reject(self,path,value,pattern):
        read=Path.read_text
        with mock.patch.object(Path,'read_text',lambda p,*a,**kw:json.dumps(value) if p==path else read(p,*a,**kw)):
            with self.assertRaisesRegex(ValueError,pattern):art.inputs()

    def test_complete_cohort_and_clean_controls(self):
        self.assertEqual(len(self.sources),85)
        self.assertEqual(len(self.recipe['identity_mappings']),79)
        self.assertEqual(len(self.recipe['preserved_controls']),6)
        self.assertEqual(len(self.recipe['files']),23)
        for key,control in self.recipe['preserved_controls'].items():
            self.assertEqual(art.base.digest(art.base.local(control['path'])),control['sha256'])
            self.assertEqual(self.manifest['object_assets'][key],self.recipe['assets'][key]['original_manifest_entry'])

    def test_all_current_pixels_reconstruct(self):self.assertEqual(set(art.validate_assets()),set(self.sources))

    def test_frontier_uses_original_sheet_not_reduced_copies(self):
        cells=[]
        for key,row in self.recipe['assets'].items():
            if art.family(row['original_manifest_entry'])!='frontier_watch_contracts':continue
            with Image.open(art.base.local(row['original_manifest_entry']['source_generated'])) as nominal:
                self.assertEqual(nominal.size,(48,48))
            self.assertEqual(self.sources[key].size,(512,512));cells.append(row['master_region'])
            self.assertEqual(row['source_crop'],[0,0,512,512])
        self.assertEqual(cells,[[0,0,512,512],[512,0,1024,512],[1024,0,1536,512],[0,512,512,1024],[512,512,1024,1024],[1024,512,1536,1024]])

    def test_only_reviewed_low_alpha_rgb_changes(self):
        for key,row in self.recipe['assets'].items():
            if row['mode']=='preserved_faction':continue
            source=self.sources[key];before=np.asarray(source);after=np.asarray(art.shared.recover_source(source,row));mask=art.shared.noise_mask(source)
            self.assertTrue(np.array_equal(before[:,:,3],after[:,:,3]),key)
            self.assertTrue(np.array_equal(before[~mask],after[~mask]),key)
            fixed=art.project(Image.fromarray(after),row)
            old=art.owner.region(art.original(row['runtime_path']),row['original_manifest_entry'])
            self.assertNotEqual(fixed.tobytes(),old.resize(fixed.size,Image.Resampling.LANCZOS).tobytes())

    def test_legitimate_purple_preserved(self):
        source=Image.new('RGBA',(3,1));source.putdata([(255,0,255,255),(255,0,255,4),(255,0,255,5)])
        self.assertEqual(art.shared.recover_source(source,{'low_alpha_rgb_pixels':1}).tobytes(),source.tobytes())

    def test_history_routes_and_registration(self):
        self.assertEqual(self.manifest['encounter_faction_sprites'],self.recipe['faction_mappings'])
        for identity,asset in self.recipe['identity_mappings'].items():self.assertEqual(self.manifest['encounter_identity_sprites'][identity],asset)
        for path,info in self.recipe['files'].items():
            original=art.base.local(path) if info['preserved'] else art.before_path(path)
            self.assertEqual(art.base.digest(original),info['before_sha256'])
        for key,row in self.recipe['assets'].items():
            old=art.owner.region(art.original(row['runtime_path']),row['original_manifest_entry'])
            self.assertEqual(art.registration(self.sources[key],row,old),row['registration_evidence'])

    def test_bad_routes_regions_and_sources_fail_closed(self):
        key=next(k for k,r in self.recipe['assets'].items() if 'atlas_region' in r['original_manifest_entry'])
        identity=next(iter(self.recipe['identity_mappings']))
        m=copy.deepcopy(self.manifest);m['encounter_identity_sprites'][identity]='hostile_camp';self.reject(art.MANIFEST,m,'routing')
        m=copy.deepcopy(self.manifest);m['object_assets'][key]['atlas_region'][0]+=192;self.reject(art.MANIFEST,m,'metadata')
        r=copy.deepcopy(self.recipe);r['assets'][key]['source_sha256']='0'*64;self.reject(art.RECIPE,r,'painting')
        r=copy.deepcopy(self.recipe);r['assets'][key]['source_manifest_sha256']='0'*64;self.reject(art.RECIPE,r,'provenance')

    def test_crop_density_anchor_and_noise_fail_closed(self):
        key=next(k for k,r in self.recipe['assets'].items() if r['low_alpha_rgb_pixels']>0)
        for field,value,pattern in [('source_crop',[0,0,10,10],'registration'),('master_region',[0,0,10,10],'region'),('pixel_scale',1,'registration'),('canvas_origin',[6,3],'registration'),('low_alpha_rgb_pixels',-1,'RGB noise')]:
            r=copy.deepcopy(self.recipe);r['assets'][key][field]=value;self.reject(art.RECIPE,r,pattern)


if __name__=='__main__':unittest.main()
