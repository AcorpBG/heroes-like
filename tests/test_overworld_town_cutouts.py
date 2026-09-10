"""Exact Town source paint, registrations, aliases and fail-closed contracts."""
import copy
import importlib.util
import json
from pathlib import Path
import unittest
from unittest import mock

import numpy as np

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('town_recovery',ROOT/'tools/prepare_overworld_town_cutouts.py')
art=importlib.util.module_from_spec(spec);spec.loader.exec_module(art)


class TownCutoutTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.recipe,cls.manifest,cls.sources=art.inputs()
        cls.proof=json.loads((art.PACKET/'manifest.json').read_text())

    def test_exact_eleven_originals_and_twenty_eight_controls(self):
        self.assertEqual(len(self.recipe['assets']),39);self.assertEqual(len(self.sources),11)
        self.assertEqual(self.recipe['mappings'],{k:self.manifest[k] for k in art.MAPPING_KEYS})
        self.assertEqual(len(self.recipe['files']),2)
        for key,row in self.recipe['assets'].items():
            if key in self.sources:continue
            self.assertEqual(self.manifest['object_assets'][key],row['original_manifest_entry'])
            self.assertEqual(art.base.digest(art.base.local(row['runtime_path'])),row['before_sha256'])

    def test_runtime_reconstructs_exactly_from_originals(self):
        self.assertEqual(len(art.validate_assets()),39)

    def test_all_source_alpha_and_non_noise_paint_preserved(self):
        for key,source in self.sources.items():
            recovered=art.shared.recover_source(source,self.recipe['assets'][key])
            a,b=np.asarray(source),np.asarray(recovered);noise=art.shared.noise_mask(source)
            self.assertTrue(np.array_equal(a[:,:,3],b[:,:,3]),key)
            self.assertTrue(np.array_equal(a[~noise],b[~noise]),key)
            # These generated masters have median interior alpha 251..253,
            # not solid 255. Preserve that original coverage, do not harden it.
            self.assertGreater(np.count_nonzero((a[:,:,3]>200)&~noise),600000,key)

    def test_exact_normalized_regions_and_original_canvas_registration(self):
        for key,source in self.sources.items():
            row=self.recipe['assets'][key];old=row['original_manifest_entry'];new=self.manifest['object_assets'][key]
            self.assertEqual(new['atlas_region'],[v*4 for v in old['atlas_region']])
            self.assertEqual(new['atlas_size'],[v*4 for v in old['atlas_size']])
            self.assertEqual(row['canvas_origin'],[(128-v)//2 for v in row['source_resize']])
            self.assertEqual(max(row['source_resize']),120 if 'third_hearths' in old['path'] else 112)
            self.assertEqual(art.registration(source,row,art.owner.region(art.original(old['path']),old)),row['historical_registration'])
            bad=dict(row,canvas_origin=[row['canvas_origin'][0]+2,row['canvas_origin'][1]])
            with self.assertRaisesRegex(ValueError,'registration'):art.registration(source,bad,art.owner.region(art.original(old['path']),old))

    def test_source_provenance_and_metadata_retained(self):
        for key,row in self.recipe['assets'].items():
            for path,sha in row['source_hashes'].items():self.assertEqual(art.base.digest(ROOT/path.removeprefix('res://')),sha)
            old=row['original_manifest_entry'];new=self.manifest['object_assets'][key]
            changed=('atlas_region','atlas_size','source_trimmed','source_processing_manifest','runtime_sha256') if key in self.sources else ()
            self.assertEqual({k:v for k,v in old.items() if k not in changed},{k:v for k,v in new.items() if k not in changed})

    def test_six_deliberate_faction_aliases_are_unchanged(self):
        entries=self.manifest['object_assets'];aliases=[]
        for tid,aid in self.manifest['town_identity_sprites'].items():
            for faction,fid in self.manifest['town_faction_sprites'].items():
                if entries[aid]['path']==entries[fid]['path']:
                    self.assertEqual(entries[aid]['assigned_faction_id'],faction);aliases.append(tid)
        self.assertEqual(len(aliases),6)

    def test_swapped_route_or_missing_hash_fails_closed(self):
        with mock.patch.object(art.base,'digest',return_value='changed'):
            with self.assertRaises(ValueError):art.inputs()
        m=copy.deepcopy(self.manifest);m['town_identity_sprites']['town_cinderlock_bastion']='town_faction_embercourt'
        read=Path.read_text
        with mock.patch.object(Path,'read_text',lambda p,*a,**kw:json.dumps(m) if p==art.MANIFEST else read(p,*a,**kw)):
            with self.assertRaisesRegex(ValueError,'cohort|routes'):art.inputs()

    def test_recipe_tool_and_historical_runtime_locked(self):
        self.assertEqual(self.proof['recipe_sha256'],art.base.digest(art.RECIPE))
        self.assertEqual(self.proof['tools'],art.tool_hashes())
        for path,row in self.recipe['files'].items():
            self.assertEqual(art.base.digest(art.before_path(path)),row['before_sha256'])
            self.assertEqual(art.base.digest(art.base.local(path)),self.proof['files'][path]['after_sha256'])


if __name__=='__main__':unittest.main()
