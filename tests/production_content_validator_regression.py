"""Focused positive/corruption controls for the production content contracts."""
import copy
import unittest
from unittest.mock import patch

import validate_repo as validator


class ProductionContentContracts(unittest.TestCase):
    def test_blocker_library_and_broken_provenance(self):
        assets = validator.load_json(validator.ROOT / 'art/overworld/manifest.json')['object_assets']
        errors = []
        self.assertEqual(len(validator.validate_generated_blocker_contracts(assets, errors)), 912)
        self.assertEqual(errors, [])
        altered = copy.deepcopy(assets)
        altered['cohesive_library_grasslands_000']['path'] = altered['cohesive_library_grasslands_001']['path']
        validator.validate_generated_blocker_contracts(altered, errors)
        self.assertTrue(errors, 'A substituted blocker must fail its recipe identity check')

    def test_missing_palette_entry(self):
        original_load = validator.load_json
        def missing(path):
            data = original_load(path)
            if path.name == 'decorative_object_sprites.json':
                data['generated_body_palette']['biome_grasslands'].remove('cohesive_library_grasslands_000')
            return data
        assets = original_load(validator.ROOT / 'art/overworld/manifest.json')['object_assets']
        errors = []
        with patch.object(validator, 'load_json', side_effect=missing):
            validator.validate_generated_blocker_contracts(assets, errors)
        self.assertTrue(errors, 'Unwired art must not count as a completed blocker')

    def test_audio_mapping_and_wrong_event_role(self):
        legacy = dict(path='res://art/audio/runtime/presentation/object_focus.wav', duration_msec=260,
                      volume_db=-14.5, role='overworld_object_selected')
        errors = []
        validator.validate_presentation_audio_mapping('audio_placeholder_object_focus', legacy, errors, 'focus')
        self.assertEqual(errors, [])
        legacy['role'] = 'incorrect_event'
        validator.validate_presentation_audio_mapping('audio_placeholder_object_focus', legacy, errors, 'focus')
        self.assertTrue(errors, 'Production paths must not relax event-role ownership')

    def test_signal_health_and_recorded_measurements(self):
        for samples, stats, valid in [
            ([4096, -4096], dict(peak=.125, rms=.125), True),
            ([0, 0], dict(peak=0, rms=0), False),
            ([32767, -32767], dict(peak=32767/32768, rms=32767/32768), False),
            ([4096, -4096], dict(peak=.2, rms=.2), False),
        ]:
            with self.subTest(samples=samples, stats=stats):
                errors = []
                validator.validate_production_pcm_signal(samples, stats, errors, 'control')
                self.assertEqual(not errors, valid)


if __name__ == '__main__':
    unittest.main()
