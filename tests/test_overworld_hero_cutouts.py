"""Original-paint, bounded-matte and unchanged identity/control checks."""
import copy
import importlib.util
import json
from pathlib import Path
import unittest
from unittest import mock

import numpy as np
from PIL import Image,ImageFilter

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('hero_recovery',ROOT/'tools/prepare_overworld_hero_cutouts.py')
art=importlib.util.module_from_spec(spec);spec.loader.exec_module(art)


class HeroCutoutTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.recipe,cls.manifest,cls.sources=art.inputs()
        cls.proof=json.loads((art.PACKET/'manifest.json').read_text())
        cls.results={k:art.recover(v,cls.recipe['assets'][k]) for k,v in cls.sources.items()}

    def test_exact_three_repairs_and_fifty_seven_clean_controls(self):
        self.assertEqual(len(self.recipe['assets']),60);self.assertEqual(len(self.results),3)
        self.assertEqual(set(self.results),{'hero_strategic_thalen','hero_strategic_thornwake_nara_graftsibyl','hero_strategic_veilmourn_orso_nightchart'})
        self.assertEqual(self.recipe['identity_mappings'],self.manifest['hero_identity_sprites'])
        for key,row in self.recipe['assets'].items():
            if key in self.results:continue
            self.assertEqual(self.manifest['object_assets'][key],row['original_manifest_entry'])
            self.assertEqual(art.base.digest(art.base.local(row['original_manifest_entry']['path'])),row['before_sha256'])

    def test_runtime_and_prepared_source_reconstruct_exactly(self):
        for key,(result,fixed,mask,metrics) in self.results.items():
            row=self.recipe['assets'][key]
            self.assertEqual(Image.open(art.base.local(row['original_manifest_entry']['path'])).tobytes(),result.tobytes())
            self.assertEqual(Image.open(art.base.local(row['trimmed_path'])).tobytes(),result.tobytes())
            self.assertEqual(Image.open(art.base.local(row['recovered_source_path'])).tobytes(),fixed.tobytes())
            self.assertEqual(self.proof['assets'][key]['metrics'],metrics)

    def test_no_runtime_pixel_changes_outside_projected_repair(self):
        for key,(after,_,mask,_) in self.results.items():
            before=art.original(self.recipe['assets'][key]['original_manifest_entry'])
            a,b,s=np.array(before),np.array(after),np.array(mask)>0
            self.assertTrue(np.array_equal(a[~s],b[~s]),key)
            self.assertGreater(np.count_nonzero(~s),240000,key)
            self.assertEqual(after.size,(512,512))
            self.assertLess(np.max(np.abs(np.array(after.getbbox())-np.array(before.getbbox()))),3,key)

    def test_source_changes_only_inspected_backing_and_three_pixel_band(self):
        for key,(_,after,_,_) in self.results.items():
            before=self.sources[key];row=self.recipe['assets'][key];p=np.array(before);q=np.array(after)
            valid=[min(r,g,b)>=230 and max(r,g,b)-min(r,g,b)<=20 for r,g,b,a in before.getdata()]
            mask=Image.new('L',before.size);raw=np.zeros(before.width*before.height,np.uint8)
            for component in row['backing_components']:
                points=art.source_owner.component(before,component,valid);raw[list(points)]=255
            mask=Image.fromarray(raw.reshape(before.height,before.width))
            permitted=(np.array(mask.filter(ImageFilter.MaxFilter(7)))>0)&(p[:,:,3]>0)
            self.assertTrue(np.array_equal(p[~permitted],q[~permitted]),key)
            self.assertTrue(np.all(q[:,:,3]<=p[:,:,3]),key)
            interior=(p[:,:,3]==255)&~permitted
            self.assertGreater(np.count_nonzero(interior),200000,key)
            self.assertTrue(np.array_equal(p[interior],q[interior]),key)

    def test_enclosed_checkerboard_is_gone_and_real_glints_remain(self):
        for key,(_,fixed,_,_) in self.results.items():
            before=self.sources[key];row=self.recipe['assets'][key]
            for component in row['backing_components']:
                xy=tuple(component['seed'])
                if component['visible']:self.assertEqual(fixed.getpixel(xy)[3],0,key)
            self.assertNotEqual(before.tobytes(),fixed.tobytes(),key)
        # Visually inspected pale staff crystal and sun-medallion highlights
        # are deliberately NOT treated as the neighbouring backing gaps.
        for xy in [(216,40),(230,180),(540,145),(680,360),(580,800)]:
            self.assertEqual(self.sources['hero_strategic_thalen'].getpixel(xy),self.results['hero_strategic_thalen'][1].getpixel(xy))

    def test_old_rgb_proves_historical_registration(self):
        for key,row in self.recipe['assets'].items():
            if key not in self.sources:continue
            a=np.array(art.original(row['original_manifest_entry'])).astype(int)
            b=np.array(art.registered(self.sources[key],row)).astype(int)
            interior=(a[:,:,3]>245)&(a[:,:,:3].min(2)<180)
            self.assertGreater(np.count_nonzero(interior),40000)
            self.assertLess(np.abs(a[:,:,:3]-b[:,:,:3])[interior].mean(),3,key)

    def test_every_source_portrait_and_identity_field_remains_original(self):
        for key,row in self.recipe['assets'].items():
            e=self.manifest['object_assets'][key]
            self.assertEqual({k:v for k,v in e.items() if k not in ('source_trimmed','source_processing_manifest','runtime_sha256')},row['original_manifest_entry'])
            self.assertEqual(art.base.digest(art.base.local(e['source_generated'])),row['source_sha256'])
            self.assertEqual(art.base.digest(art.portrait_path(e)),row['portrait_sha256'])

    def test_seed_area_source_or_identity_drift_fails_closed(self):
        row=copy.deepcopy(self.recipe['assets']['hero_strategic_thalen']);row['backing_components'][0]['area']+=1
        with self.assertRaisesRegex(ValueError,'bounds/area'):art.recover_source(self.sources['hero_strategic_thalen'],row)
        with mock.patch.object(art.base,'digest',return_value='changed'):
            with self.assertRaisesRegex(ValueError,'hash changed'):art.inputs()
        m=copy.deepcopy(self.manifest);m['hero_identity_sprites']['hero_thalen']='hero_signature_lyra'
        read=Path.read_text
        with mock.patch.object(Path,'read_text',lambda p,*a,**kw:json.dumps(m) if p==art.MANIFEST else read(p,*a,**kw)):
            with self.assertRaisesRegex(ValueError,'identity mapping'):art.inputs()

    def test_provenance_locks_recipe_tool_and_old_runtime(self):
        self.assertEqual(self.proof['recipe_sha256'],art.base.digest(art.RECIPE))
        self.assertEqual(self.proof['processing_tool_sha256'],art.base.digest(Path(art.__file__)))
        for path,row in self.proof['files'].items():
            self.assertEqual(art.base.digest(art.before_path({'path':path})),row['before_sha256'])
            self.assertEqual(art.base.digest(art.base.local(path)),row['after_sha256'])


if __name__=='__main__':unittest.main()
