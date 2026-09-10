"""Original creature paint, no UI backing, exact registration and 42 controls."""
import copy
import importlib.util
import json
from pathlib import Path
import unittest
from unittest import mock

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('final_cutouts', ROOT / 'tools/prepare_overworld_final_cutouts.py')
art = importlib.util.module_from_spec(spec)
spec.loader.exec_module(art)


class FinalCutoutTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.recipe, cls.manifest, cls.sources = art.inputs()
        cls.proof = json.loads((art.PACKET / 'manifest.json').read_text())

    def test_exact_final_complement_and_all_original_routes(self):
        previous, hashes = art.prior_assets()
        self.assertEqual(len(previous), 1143)
        self.assertEqual(len(self.recipe['assets']), 71)
        self.assertEqual(len(self.sources), 29)
        historical = previous | self.recipe['assets'].keys()
        self.assertTrue(historical <= self.manifest['object_assets'].keys())
        # New neutral troop paintings have their own source/identity validator;
        # they are not additions to the frozen historical 71-asset cohort.
        extras = self.manifest['object_assets'].keys() - historical
        self.assertTrue(all(self.manifest['object_assets'][key].get('presentation_role') == 'generated_neutral_primary_unit' for key in extras))
        self.assertEqual(previous & self.recipe['assets'].keys(), set())
        self.assertEqual(hashes, self.recipe['earlier_recipes'])
        self.assertEqual(self.recipe['mapping_tables'], {k: v for k, v in self.manifest.items() if k != 'object_assets'})

    def test_exact_original_paint_reconstruction(self):
        self.assertEqual(len(art.validate_assets()), 71)
        for key, source in self.sources.items():
            row = self.recipe['assets'][key]
            target = art.rgba(art.local(row['runtime_path']))
            self.assertEqual(target.size, (384, 384))
            self.assertEqual(target.tobytes(), art.project(source, row).tobytes())

    def test_historical_figure_fit_origin_and_original_author(self):
        spec = importlib.util.spec_from_file_location('original_unit_author', art.AUTHOR)
        original = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(original)
        for key, source in self.sources.items():
            row = self.recipe['assets'][key]
            fit = original._fit_curated_source(source, (82, 76))
            self.assertEqual(list(fit.size), row['source_resize'])
            old_projection = Image.new('RGBA', (96, 96))
            old_projection.paste(fit, ((96 - fit.width) // 2, 85 - fit.height))
            self.assertEqual(old_projection.tobytes(), art.project(source, dict(row, canvas_size=[96, 96], pixel_scale=1)).tobytes())
            self.assertEqual(row['historical_opaque_rgb_mae'], art.historical_paint_error(source, row))
            self.assertLess(row['historical_opaque_rgb_mae'], 17)

    def test_ui_badge_support_is_not_world_paint(self):
        for key in self.sources:
            row = self.recipe['assets'][key]
            old = art.rgba(art.local(row['original_manifest_entry']['path']))
            new = art.rgba(art.local(row['runtime_path']))
            # Deliberate card corners are outside the original figure, even
            # for the widest 82px creature. No color threshold deletes paint.
            for x, y in [(48, 3), (6, 27), (13, 89), (83, 89)]:
                self.assertGreater(old.getpixel((x, y))[3], 100, key)
                self.assertEqual(new.getpixel((x * 4, y * 4))[3], 0, key)

    def test_all_shared_unit_surfaces_and_sources_unchanged(self):
        for key, row in self.recipe['assets'].items():
            self.assertEqual(art.base.digest(art.local(row['original_manifest_entry']['path'])), row['before_sha256'], key)
            for path, sha in row['source_hashes'].items():
                self.assertEqual(art.base.digest(art.local(path)), sha, path)
            if key in self.sources:
                unit = row['unit_art_record']
                for field in ('portrait', 'battle_icon', 'battle_standee', 'overworld_icon', 'curated_source'):
                    self.assertIn(unit[field], row['source_hashes'])

    def test_forty_two_controls_preserved_without_palette_or_alpha_changes(self):
        controls = {k: r for k, r in self.recipe['assets'].items() if k not in self.sources}
        self.assertEqual(len(controls), 42)
        self.assertEqual(sum(k.startswith('cohesive_') for k in controls), 24)
        self.assertEqual(sum(k.startswith('mapobj_') for k in controls), 8)
        for key, row in controls.items():
            self.assertEqual(self.manifest['object_assets'][key], row['original_manifest_entry'])
            self.assertEqual(art.base.digest(art.local(row['runtime_path'])), row['before_sha256'])

    def test_unit_identity_and_description_metadata_retained(self):
        changed = {'path', 'source_generated', 'source_trimmed', 'source_processing_manifest', 'runtime_sha256'}
        paths = set()
        for key in self.sources:
            row = self.recipe['assets'][key]
            old = row['original_manifest_entry']; new = self.manifest['object_assets'][key]
            self.assertEqual({k: v for k, v in old.items() if k not in changed}, {k: v for k, v in new.items() if k not in changed})
            self.assertEqual(Path(new['path']).stem, row['unit_id'])
            paths.add(new['path'])
        self.assertEqual(len(paths), 29)

    def test_hash_drift_or_swapped_route_fails_closed(self):
        with mock.patch.object(art.base, 'digest', return_value='changed'):
            with self.assertRaises(ValueError):
                art.inputs()
        manifest = copy.deepcopy(self.manifest)
        key = next(iter(manifest['encounter_identity_sprites']))
        manifest['encounter_identity_sprites'][key] = 'hostile_camp'
        read = Path.read_text
        with mock.patch.object(Path, 'read_text', lambda p, *a, **kw: json.dumps(manifest) if p == art.MANIFEST else read(p, *a, **kw)):
            with self.assertRaisesRegex(ValueError, 'mapping'):
                art.inputs()

    def test_shifted_registration_and_unscoped_derivatives_rejected(self):
        recipe = copy.deepcopy(self.recipe)
        recipe['assets'][next(iter(self.sources))]['canvas_origin'][0] += 1
        read = Path.read_text
        with mock.patch.object(Path, 'read_text', lambda p, *a, **kw: json.dumps(recipe) if p == art.RECIPE else read(p, *a, **kw)):
            with self.assertRaisesRegex(ValueError, 'crop/fit/origin'):
                art.inputs()
        for path in ('res://art/units/../../project.godot', 'res://scripts/autoload/ContentService.gd', '/tmp/random.png'):
            with self.assertRaises(ValueError):
                art.local(path)


if __name__ == '__main__':
    unittest.main()
