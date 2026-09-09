"""Original-master extraction, fail-closed provenance and deterministic outputs."""
import importlib.util
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('map_cutouts', ROOT/'tools/repair_map_object_cutouts.py')
cutouts = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cutouts)


class MapObjectCutoutsTest(unittest.TestCase):
    def test_exact_originals_reproduce_defects(self):
        expected = {'mapobj_cinder_ore_face':(282,2941,47476),
                    'mapobj_moss_oath_cache':(5,2056,42800),
                    'mapobj_marsh_listener_post':(356,4580,34974)}
        for asset_id, counts in expected.items():
            with self.subTest(asset=asset_id):
                paths = cutouts.paths(asset_id)
                self.assertEqual(cutouts.digest(paths['input']),cutouts.SPECS[asset_id]['input_sha256'])
                self.assertEqual(cutouts.digest(paths['atlas']),cutouts.SPECS[asset_id]['atlas_sha256'])
                report = cutouts.inspect_image(asset_id,paths['input'])
                self.assertFalse(report['ok'])
                self.assertEqual(tuple(report[k] for k in ('divider_pixels','magenta_pixels','painted_pixels')),counts)

    def test_live_assets_are_clean_and_authoritatively_registered(self):
        manifest = json.loads(cutouts.ART_MANIFEST.read_text())
        for asset in cutouts.SPECS:
            with self.subTest(asset=asset):
                proof = cutouts.validate_asset(asset,manifest['object_assets'][asset])
                self.assertTrue(proof['ok'],proof)

    def test_preserves_every_uncontaminated_painted_pixel(self):
        for asset, spec in cutouts.SPECS.items():
            with self.subTest(asset=asset), Image.open(cutouts.paths(asset)['input']) as original:
                repaired = cutouts.repair_image(asset,original)
                left,top,right,bottom = spec['body_window']
                preserved = 0
                for y in range(top,bottom):
                    for x in range(left,right):
                        r,g,b,a = original.getpixel((x,y))
                        if a and min(r,b)-g<=8:
                            self.assertEqual(repaired.getpixel((x,y)),(r,g,b,a))
                            preserved += 1
                self.assertGreater(preserved,30000 if asset=='mapobj_marsh_listener_post' else 40000)
                if asset=='mapobj_marsh_listener_post':
                    self.assertEqual(preserved,30385)
                self.assertEqual(repaired.size,original.size)
                self.assertEqual(cutouts.repair_image(asset,repaired).tobytes(),repaired.tobytes())

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

    def test_preparation_is_idempotent_and_preserves_other_manifest_rows(self):
        with tempfile.TemporaryDirectory(prefix='cutout-preparation-') as temporary:
            root = Path(temporary)
            for asset in cutouts.SPECS:
                for original in cutouts.paths(asset).values():
                    destination = root/original.relative_to(ROOT)
                    destination.parent.mkdir(parents=True,exist_ok=True)
                    shutil.copyfile(original,destination)
            manifest = root/cutouts.ART_MANIFEST.relative_to(ROOT)
            shutil.copyfile(cutouts.ART_MANIFEST,manifest)
            provenance = root/cutouts.PROVENANCE_DIR.relative_to(ROOT)
            before = json.loads(manifest.read_text())
            with patch.multiple(cutouts,ROOT=root,ART_MANIFEST=manifest,
                                PROVENANCE_DIR=provenance,PROVENANCE_PATH=provenance/'manifest.json'):
                unselected = {str(p):cutouts.digest(p) for asset in cutouts.SPECS
                              if asset!='mapobj_marsh_listener_post' for p in cutouts.paths(asset).values()}
                cutouts.prepare(['mapobj_marsh_listener_post'])
                self.assertEqual(unselected,{name:cutouts.digest(Path(name)) for name in unselected})
                cutouts.prepare()
                hashes = {str(p):cutouts.digest(p) for p in root.rglob('*') if p.is_file()}
                cutouts.prepare()
                self.assertEqual(hashes,{str(p):cutouts.digest(p) for p in root.rglob('*') if p.is_file()})
                after = json.loads(manifest.read_text())
                for data in (before,after):
                    for asset in cutouts.SPECS:
                        for key in ('runtime_sha256','source_processing_manifest'):
                            data['object_assets'][asset].pop(key,None)
                self.assertEqual(after,before)
                # A changed generated master is rejected before output writes.
                cutouts.paths('mapobj_moss_oath_cache')['atlas'].write_bytes(b'corrupt master')
                before_reject = {str(p):cutouts.digest(p) for p in root.rglob('*') if p.is_file()}
                with self.assertRaises(ValueError):
                    cutouts.prepare()
                self.assertEqual(before_reject,{str(p):cutouts.digest(p) for p in root.rglob('*') if p.is_file()})

    def test_selection_rejects_empty_unknown_or_duplicate_before_writing(self):
        for assets in ([],['fallback'],['mapobj_marsh_listener_post']*2):
            with self.subTest(assets=assets), patch.object(cutouts,'digest') as digest:
                with self.assertRaises(ValueError):
                    cutouts.prepare(assets)
                digest.assert_not_called()


if __name__=='__main__':
    unittest.main()
