"""Fail closed on roster drift, missing originals, altered alpha or fitted pixels."""
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('actor_art', ROOT / 'tools/prepare_overworld_actor_art.py')
art = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(art)


class ActorArtTests(unittest.TestCase):
    def test_complete_original_pipeline(self):
        report = art.validate_assets()
        self.assertTrue(report['ok'])
        self.assertEqual(report['original_actors'], 112)

    def test_identity_coverage_not_generic_tokens(self):
        rows = art.inventory()
        heroes = [r for r in rows.values() if r['kind'] == 'hero']
        neutrals = [r for r in rows.values() if r['kind'] == 'neutral']
        self.assertEqual(len(heroes), 66)
        self.assertEqual(len({r['identity_id'] for r in heroes}), 66)
        self.assertEqual(len(neutrals), 46)
        self.assertEqual(sum(len(r['encounter_ids']) for r in neutrals), 51)

    def test_transparency_is_not_applied_twice(self):
        # Synthetic pixels test only alpha handling, never create game artwork.
        source = Image.new('RGBA', (80, 100))
        source.putpixel((10, 20), (100, 120, 140, 128))
        source.putpixel((29, 59), (40, 60, 80, 255))
        trimmed, runtime, bounds = art.derived(source)
        self.assertEqual(bounds, [10, 20, 30, 60])
        self.assertEqual(trimmed.size, (20, 40))
        left = (art.SIDE - 20) // 2
        top = art.SIDE - 12 - 40
        self.assertEqual(runtime.getpixel((left, top)), (100, 120, 140, 128))
        self.assertEqual(runtime.getchannel('A').getbbox(), (left, top, left + 20, top + 40))

    def test_no_stretch_when_fitting(self):
        source = Image.new('RGBA', (1000, 2000), (20, 30, 40, 255))
        _, runtime, _ = art.derived(source)
        box = runtime.getchannel('A').getbbox()
        self.assertEqual((box[2] - box[0]) * 2, box[3] - box[1])
        self.assertEqual(box[3], art.SIDE - 12)

    def test_no_empty_sprite(self):
        with self.assertRaises(ValueError):
            art.derived(Image.new('RGBA', (20, 20)))

    def test_paths_are_confined_to_original_art(self):
        for path in ('/tmp/unrelated.png', 'res://../outside.png', 'res://scripts/core/test.gd'):
            with self.assertRaises(ValueError):
                art.local(path)

    def test_missing_roster_mapping_fails_validation(self):
        with patch.object(art, 'inventory', return_value={}):
            with self.assertRaises(AssertionError):
                art.validate_assets()

    def test_wrong_identity_and_generic_asset_mapping_fail_validation(self):
        original_read = art.read
        for field, value in [('identity_id', 'wrong_hero'), ('path', 'res://art/overworld/runtime/generic.png')]:
            manifest = original_read(art.MANIFEST)
            next(iter(manifest['assets'].values()))[field] = value
            with patch.object(art, 'read', side_effect=lambda path: manifest if path == art.MANIFEST else original_read(path)):
                with self.assertRaises(AssertionError):
                    art.validate_assets()


if __name__ == '__main__':
    unittest.main()
