"""The owner-approved native control is exact, durable and fail-closed."""
import json
import unittest
from unittest import mock

import overworld_cutout_batch_regression as cutouts


class EarnedCutoutSaveTests(unittest.TestCase):
    def test_verified_roundtrip_and_provenance(self):
        raw = cutouts.earned_save_bytes()
        provenance = json.loads((cutouts.SAVE.parent / 'provenance.json').read_text())
        session = json.loads(raw)
        self.assertEqual(provenance['fixture_sha256'], cutouts.SAVE_SHA)
        self.assertEqual(provenance['fixture'], cutouts.SAVE.name)
        self.assertEqual(provenance['fixture_bytes'], len(raw))
        self.assertEqual(provenance['owner_approved_at'], '2026-09-10')
        self.assertNotEqual(provenance['superseded_sha256'], cutouts.SAVE_SHA)
        for field in ('day', 'save_version', 'scenario_id'):
            self.assertEqual(session[field], provenance[field])

    def test_changed_save_rejected(self):
        with mock.patch.object(cutouts, 'SAVE') as path:
            path.read_bytes.return_value = b'{}'
            with self.assertRaisesRegex(ValueError, 'unchanged exact earned save'):
                cutouts.earned_save_bytes()

    def test_missing_save_does_not_substitute_another_control(self):
        with mock.patch.object(cutouts, 'SAVE') as path:
            path.read_bytes.side_effect = FileNotFoundError('missing pinned control')
            with self.assertRaises(FileNotFoundError):
                cutouts.earned_save_bytes()


if __name__ == '__main__':
    unittest.main()
