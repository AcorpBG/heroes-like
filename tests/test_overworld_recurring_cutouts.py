"""Original encounter-paint recovery, registration and fail-closed invariants."""
import copy
import importlib.util
import json
from pathlib import Path
import unittest
from unittest import mock

from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('recurring_recovery',ROOT/'tools/prepare_overworld_recurring_cutouts.py')
art=importlib.util.module_from_spec(spec);spec.loader.exec_module(art)


class RecurringCutoutTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.recipe,cls.manifest,cls.sources=art.inputs()
        cls.results={k:art.recover(cls.sources[k],r) for k,r in cls.recipe['assets'].items()}

    def test_exact_twenty_four_regions_and_seven_clean_neighbors(self):
        self.assertEqual(len(self.results),24);self.assertEqual(len(self.recipe['preserved_controls']),7)
        offsets=sorted(r['original_manifest_entry']['atlas_region'][0] for r in self.recipe['assets'].values())
        self.assertEqual(offsets,list(range(0,1152,48)))
        self.assertEqual({r['original_manifest_entry']['path'] for r in self.recipe['assets'].values()},
                         {'res://art/overworld/runtime/objects/encounters/recurring/recurring_encounter_landmarks_atlas.png'})

    def test_every_original_painting_is_hash_locked_and_unchanged(self):
        for key,row in self.recipe['assets'].items():
            self.assertEqual(art.base.digest(art.base.local(row['original_manifest_entry']['source_generated'])),row['source_sha256'])
            self.assertGreater(len(set(self.sources[key].getchannel('A').getdata())),200)

    def test_original_crop_aspect_canvas_and_alignment(self):
        for key,row in self.recipe['assets'].items():
            self.assertEqual(list(self.sources[key].getbbox()),row['source_crop'])
            w,h=row['source_resize'];x,y=row['canvas_origin'];self.assertEqual(max(w,h),44)
            self.assertEqual(x,(48-w)//2)
            self.assertEqual(y,48-h if row['original_manifest_entry']['atlas_region'][0]<288 else (48-h)//2)
            self.assertEqual(self.results[key].size,(192,192))
            self.assertEqual(row['pixel_scale'],4)

    def test_registered_original_rgba_is_the_entire_new_sprite(self):
        for key,row in self.recipe['assets'].items():
            source=self.sources[key];canvas=Image.new('RGBA',(192,192))
            reference=source.crop(row['source_crop']).resize([v*4 for v in row['source_resize']],getattr(Image.Resampling,row['resampling']))
            canvas.paste(reference,[v*4 for v in row['canvas_origin']])
            self.assertEqual(canvas.tobytes(),self.results[key].tobytes())

    def test_broken_binary_alpha_fails_and_source_coverage_returns(self):
        for key,row in self.recipe['assets'].items():
            before=art.owner.region(art.original(row['original_manifest_entry']),row['original_manifest_entry'])
            self.assertEqual(set(before.getchannel('A').getdata()),{0,255})
            self.assertGreaterEqual(art.metrics(self.results[key])['alpha_levels'],64)
            self.assertGreater(art.metrics(self.results[key])['partial_alpha_pixels'],100)
            self.assertNotEqual(before.tobytes(),self.results[key].tobytes())

    def test_all_content_identity_and_visual_placement_metadata_survives(self):
        for key,row in self.recipe['assets'].items():
            entry=self.manifest['object_assets'][key]
            allowed=('source_trimmed','source_processing_manifest','runtime_sha256','path','atlas_region','atlas_size')
            stripped={k:v for k,v in entry.items() if k not in allowed}
            self.assertEqual(stripped,{k:v for k,v in row['original_manifest_entry'].items() if k not in allowed})
            self.assertEqual(entry['path'],art.RUNTIME)
            self.assertEqual(entry['atlas_region'],[v*4 for v in row['original_manifest_entry']['atlas_region']])
            self.assertEqual(entry['atlas_size'],[4608,192])
            self.assertEqual(self.manifest['encounter_identity_sprites'][entry['assigned_encounter_id']],key)

    def test_seven_other_cells_and_metadata_stay_exact(self):
        for key,row in self.recipe['preserved_controls'].items():
            entry=self.manifest['object_assets'][key];self.assertEqual(entry,row['original_manifest_entry'])
            self.assertEqual(art.owner.region(art.original(entry),entry).tobytes(),art.owner.region(Image.open(art.base.local(entry['path'])).convert('RGBA'),entry).tobytes())
            self.assertEqual(art.base.digest(art.base.local(entry['path'])),art.base.digest(art.before_path(entry)))

    def test_low_resolution_mapping_and_rescaled_world_fit_fail_closed(self):
        recipe=copy.deepcopy(self.recipe);key=next(iter(self.results));recipe['assets'][key]['pixel_scale']=3
        real=Path.read_text
        with mock.patch.object(Path,'read_text',lambda p,*a,**kw:json.dumps(recipe) if p==art.RECIPE else real(p,*a,**kw)):
            with self.assertRaisesRegex(ValueError,'raster resolution'):art.inputs()
        manifest=copy.deepcopy(self.manifest);manifest['object_assets'][key]=self.recipe['assets'][key]['original_manifest_entry']
        with mock.patch.object(Path,'read_text',lambda p,*a,**kw:json.dumps(manifest) if p==art.MANIFEST else real(p,*a,**kw)):
            with self.assertRaisesRegex(ValueError,'Runtime provenance'):art.validate_assets()

    def test_changed_source_hash_or_identity_fails_closed(self):
        with mock.patch.object(art.base,'digest',return_value='wrong'):
            with self.assertRaisesRegex(ValueError,'painting hash'):art.inputs()
        manifest=copy.deepcopy(self.manifest);key=next(iter(self.results));manifest['object_assets'][key]['atlas_region'][0]+=48
        real=Path.read_text
        with mock.patch.object(Path,'read_text',lambda p,*a,**kw:json.dumps(manifest) if p==art.MANIFEST else real(p,*a,**kw)):
            with self.assertRaisesRegex(ValueError,'Identity/region'):art.inputs()

    def test_runtime_and_trim_match_original_source_reconstruction(self):
        for key,row in self.recipe['assets'].items():
            entry=self.manifest['object_assets'][key]
            self.assertEqual(art.owner.region(Image.open(art.base.local(entry['path'])).convert('RGBA'),entry).tobytes(),self.results[key].tobytes())
            self.assertEqual(Image.open(art.base.local(row['trimmed_path'])).convert('RGBA').tobytes(),self.results[key].tobytes())

    def test_provenance_and_complete_reconstruction_pass(self):
        self.assertEqual(set(art.validate_assets()),set(self.results))


if __name__=='__main__':unittest.main()
