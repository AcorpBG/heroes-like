"""Independent preservation and fail-closed checks for enclosed backing repairs."""
import copy
import importlib.util
import json
from pathlib import Path
import unittest
from unittest import mock

from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('passage_recovery',ROOT/'tools/prepare_overworld_passage_cutouts.py')
art=importlib.util.module_from_spec(spec);spec.loader.exec_module(art)


class PassageCutoutTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.recipe,cls.manifest,cls.sources=art.inputs()
        cls.proof=json.loads((art.PACKET/'manifest.json').read_text())
        cls.results={k:art.recover(cls.sources[k],r) for k,r in cls.recipe['assets'].items()}

    def test_exact_seven_states_three_atlases_sixteen_unchanged_neighbors(self):
        self.assertEqual(len(self.results),7);self.assertEqual(len(self.proof['files']),3)
        self.assertEqual(len(self.recipe['preserved_controls']),16)
        self.assertEqual(set(self.proof['assets']),set(self.results))

    def test_runtime_trim_and_source_are_reproducible(self):
        for key,row in self.recipe['assets'].items():
            result,source,_,metrics=self.results[key];entry=self.manifest['object_assets'][key]
            self.assertEqual(art.owner.region(Image.open(art.base.local(entry['path'])),entry).tobytes(),result.tobytes(),key)
            self.assertEqual(Image.open(art.base.local(row['trimmed_path'])).tobytes(),result.tobytes(),key)
            self.assertEqual(Image.open(art.base.local(row['recovered_source_path'])).tobytes(),source.tobytes(),key)
            self.assertEqual(self.proof['assets'][key]['metrics'],metrics)

    def test_only_original_neutral_backing_changes_in_source(self):
        for key,(_,fixed,_,_) in self.results.items():
            before=self.sources[key];changed=0
            for p,q in zip(before.getdata(),fixed.getdata()):
                if p==q:continue
                changed+=1
                self.assertEqual(q,(0,0,0,0),key)
                self.assertGreaterEqual(min(p[:3]),230,key)
                self.assertLessEqual(max(p[:3])-min(p[:3]),15,key)
            self.assertEqual(changed,sum(r['area'] for r in self.recipe['assets'][key]['backing_components']))
            self.assertEqual(before.getbbox(),fixed.getbbox())

    def test_every_runtime_pixel_outside_exact_repair_support_is_original(self):
        for key,(after,_,mask,_) in self.results.items():
            row=self.recipe['assets'][key];before=art.owner.region(art.original(row['original_manifest_entry']),row['original_manifest_entry'])
            untouched=0
            for p,q,support in zip(before.getdata(),after.getdata(),mask.getdata()):
                if not support:self.assertEqual(p,q,key);untouched+=1
            self.assertGreater(untouched,1000,key)
            self.assertEqual(after.size,(48,48));self.assertEqual(before.getbbox(),after.getbbox())

    def test_original_source_rgb_proves_scale_and_offset(self):
        for key,row in self.recipe['assets'].items():
            before=art.owner.region(art.original(row['original_manifest_entry']),row['original_manifest_entry'])
            reference=art.registered(self.sources[key],row)
            # Include Ash Sluice's neutral stone, not only saturated materials.
            # Exclude pale backing and translucent edges from registration proof.
            differences=[sum(abs(p[c]-q[c]) for c in range(3))/3 for p,q in zip(before.getdata(),reference.getdata()) if p[3]>245 and min(p[:3])<180]
            self.assertGreater(len(differences),100,key)
            self.assertLess(sum(differences)/len(differences),1.3,key)
        self.assertEqual(self.recipe['assets']['resource_site_minor_cache_toll_ruin_opened']['canvas_origin'],[2,4])

    def test_all_original_identity_and_placement_metadata_survives(self):
        for key,row in self.recipe['assets'].items():
            entry=self.manifest['object_assets'][key]
            self.assertEqual({k:v for k,v in entry.items() if k not in ('source_trimmed','source_processing_manifest','runtime_sha256')},row['original_manifest_entry'])
            self.assertEqual(entry['runtime_sha256'],art.base.digest(art.base.local(entry['path'])))
        for key,row in self.recipe['preserved_controls'].items():
            entry=self.manifest['object_assets'][key];self.assertEqual(entry,row['original_manifest_entry'])
            self.assertEqual(art.owner.region(art.original(entry),entry).tobytes(),art.owner.region(Image.open(art.base.local(entry['path'])),entry).tobytes())

    def test_backing_gap_is_transparent_and_old_paint_fails_acceptance(self):
        for key,(after,_,_,_) in self.results.items():
            row=self.recipe['assets'][key];before=art.owner.region(art.original(row['original_manifest_entry']),row['original_manifest_entry'])
            self.assertNotEqual(before.tobytes(),after.tobytes(),key)
            self.assertTrue(any(p[3]>245 and q[3]==0 for p,q in zip(before.getdata(),after.getdata())),key)

    def test_unselected_white_wind_and_crystals_are_preserved(self):
        for suffix,seeds in [('ridge_wind_chute_active',[(650,610),(570,750)]),('frost_toll_bar_opened',[(318,461),(945,470)])]:
            key=next(k for k in self.results if k.endswith(suffix));before=self.sources[key];after=self.results[key][1]
            for xy in seeds:self.assertEqual(before.getpixel(xy),after.getpixel(xy))

    def test_changed_component_area_or_seed_fails_closed(self):
        key=next(iter(self.results));row=self.recipe['assets'][key];source=self.sources[key]
        bad=copy.deepcopy(row['backing_components'][0]);bad['area']+=1
        with self.assertRaisesRegex(ValueError,'bounds/area'):art.component(source,bad)
        bad['seed']=[0,0]
        with self.assertRaisesRegex(ValueError,'not verified'):art.component(source,bad)

    def test_source_hash_or_identity_changes_fail_closed(self):
        with mock.patch.object(art.base,'digest',return_value='wrong'):
            with self.assertRaisesRegex(ValueError,'hash changed'):art.inputs()
        original=art.MANIFEST.read_text();manifest=json.loads(original)
        key=next(iter(self.results));manifest['object_assets'][key]['atlas_region'][0]+=48
        real=Path.read_text
        with mock.patch.object(Path,'read_text',lambda p,*a,**kw:json.dumps(manifest) if p==art.MANIFEST else real(p,*a,**kw)):
            with self.assertRaisesRegex(ValueError,'Identity/region'):art.inputs()

    def test_provenance_locks_originals_tool_and_recipe(self):
        self.assertEqual(self.proof['recipe_sha256'],art.base.digest(art.RECIPE))
        self.assertEqual(self.proof['processing_tool_sha256'],art.base.digest(Path(art.__file__)))
        for path,row in self.proof['files'].items():
            self.assertEqual(art.base.digest(art.before_path({'path':path})),row['before_sha256'])
            self.assertEqual(art.base.digest(art.base.local(path)),row['after_sha256'])


if __name__=='__main__':unittest.main()
