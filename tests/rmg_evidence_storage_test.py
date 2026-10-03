"""Integrity and containment checks for the local RMG evidence verifier."""
import hashlib
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from verify_rmg_evidence import evidence_path, verify


class EvidenceStorageTest(unittest.TestCase):
    def test_detects_same_size_content_change(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            relative = '.artifacts/rmg_recovery/fixture.bin'
            path = root / relative
            path.parent.mkdir(parents=True)
            original = b'original'
            path.write_bytes(original)
            manifest = {'schema_version': 1, 'files': [{
                'path': relative, 'size': len(original),
                'sha256': hashlib.sha256(original).hexdigest(),
            }]}
            self.assertEqual(verify(root, manifest)['verified_files'], 1)
            path.write_bytes(b'modified')
            result = verify(root, manifest)
            self.assertEqual(result['verified_files'], 0)
            self.assertEqual(result['failures'][0]['error'], 'SHA-256 differs')

    def test_rejects_external_paths_on_both_platforms(self):
        with tempfile.TemporaryDirectory() as directory:
            for relative in ('../secret', '/etc/passwd', 'C:/secret',
                             '.artifacts/rmg_recovery/../../secret',
                             '.artifacts/rmg_recovery/sub\\..\\secret',
                             'art/units/runtime/atlas.png'):
                with self.subTest(path=relative), self.assertRaises(ValueError):
                    evidence_path(Path(directory), relative)

    def test_reports_missing_evidence(self):
        with tempfile.TemporaryDirectory() as directory:
            result = verify(Path(directory), {'schema_version': 1, 'files': [{
                'path': '.artifacts/rmg_recovery/missing.bin',
                'size': 0, 'sha256': hashlib.sha256(b'').hexdigest(),
            }]})
            self.assertEqual(result['verified_files'], 0)
            self.assertEqual(len(result['failures']), 1)


if __name__ == '__main__':
    unittest.main()
