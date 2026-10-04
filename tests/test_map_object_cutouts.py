"""Original-master extraction, fail-closed provenance and deterministic outputs."""
import importlib.util
import json
from pathlib import Path
import unittest
from unittest.mock import patch

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('map_cutouts', ROOT/'tools/repair_map_object_cutouts.py')
cutouts = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cutouts)


class MapObjectCutoutsTest(unittest.TestCase):
    def test_rejects_unknown_identity_and_wrong_canvases(self):
        with self.assertRaises(ValueError):
            cutouts.paths('generic_fallback')
        with self.assertRaises(ValueError):
            cutouts.repair_image('generic_fallback',Image.new('RGBA',(512,512)))
        for mode,size in [('RGB',(512,512)),('RGBA',(256,256))]:
            with self.assertRaises(ValueError):
                cutouts.repair_image('mapobj_cinder_ore_face',Image.new(mode,size))

    def test_identity_or_provenance_mismatch_fails_closed(self):
        manifest = json.loads(cutouts.ART_MANIFEST.read_text())
        for asset in cutouts.SPECS:
            for key in ('path','assigned_map_object_id','runtime_sha256','source_processing_manifest'):
                with self.subTest(asset=asset,key=key):
                    entry = dict(manifest['object_assets'][asset],**{key:'wrong'})
                    self.assertFalse(cutouts.validate_asset(asset,entry)['ok'])

    def test_selection_rejects_empty_unknown_or_duplicate_before_writing(self):
        for assets in ([],['fallback'],['mapobj_marsh_listener_post']*2):
            with self.subTest(assets=assets), patch.object(cutouts,'digest') as digest:
                with self.assertRaises(ValueError):
                    cutouts.prepare(assets)
                digest.assert_not_called()


if __name__=='__main__':
    unittest.main()
