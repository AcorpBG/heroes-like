"""Display-name authorization must not weaken frozen art/provenance checks."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('cutout_identity_guard', ROOT / 'tools/prepare_overworld_final_cutouts.py')
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)


class RecruitmentIdentityCompatibility(unittest.TestCase):
    def test_only_approved_display_labels_can_differ(self):
        resource = 'res://content/unit_art_manifest.json'
        recipe = json.loads(guard.RECIPE.read_text())
        expected = {row['source_hashes'][resource] for row in recipe['assets'].values()
                    if resource in row.get('source_hashes', {})}
        self.assertEqual({guard.protected_source_digest(resource)}, expected)
        data = (ROOT / resource.removeprefix('res://')).read_bytes()
        with tempfile.TemporaryDirectory(prefix='recruitment-identity-') as work:
            source = Path(work) / 'manifest.json'
            source.write_bytes(data.replace(b'unit_shard_guard.png', b'wrong_creature.png', 1))
            self.assertNotEqual(source.read_bytes(), data)
            with patch.object(guard, 'local', return_value=source):
                self.assertNotIn(guard.protected_source_digest(resource), expected)
                self.assertEqual(guard.protected_source_digest('res://art/units/anything.json'),
                                 hashlib.sha256(source.read_bytes()).hexdigest())


if __name__ == '__main__':
    unittest.main()
