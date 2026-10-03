"""Regression coverage for archive boundaries and slim release references."""
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from check_source_material_tracking import archived_media
import validate_release_inputs as release


class SourceStorageTest(unittest.TestCase):
    def test_media_boundary_preserves_runtime_editor_metadata_and_recovery(self):
        for path in (
            "art/units/source/generated/example.mkv",
            "art/units/source/generated/example.latent",
            "art/animation/source/pose.png.import",
        ):
            self.assertTrue(archived_media(path), path)
        for path in (
            "art/units/runtime/atlas.png",
            "art/towns/source/buildings/curated/keep.png",
            "art/campaigns/source/generated/emblems/keep.png",
            "art/campaigns/source/generated/chapter_seals/keep.png.import",
            "art/units/source/generated/recipe.json",
            "art/units/source/generated/rebuild.py.uid",
            "art/overworld/source/h3maped/reference.png",
            "art/units/source/backups/original.png",
            "art/units/source/__pycache__/cache.npy",
        ):
            self.assertFalse(archived_media(path), path)

    def test_release_accepts_archived_provenance_but_requires_runtime_and_editor_art(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            for prefix in release.EDITOR_SOURCE_PREFIXES:
                p = root / prefix / "keep.png"
                p.parent.mkdir(parents=True)
                p.write_bytes(b"fixture")
            runtime = root / "art/units/runtime/atlas.png"
            runtime.parent.mkdir(parents=True)
            runtime.write_bytes(b"fixture")
            source = "art/units/source/original.png"
            refs = {source: [{"key": "source_path"}], "art/units/runtime/atlas.png": [{"key": "atlas_path"}]}
            filters = {p: ["art/*/source/*"] for p in ("Linux Release", "Windows Release")}
            with patch.object(release, "references", return_value=(refs, {}, [])), patch.object(release, "export_filters", return_value=filters):
                self.assertEqual(release.check_referenced_art(root)[0], [])
                runtime.unlink()
                self.assertIn("Missing content art: art/units/runtime/atlas.png", release.check_referenced_art(root)[0])
                runtime.write_bytes(b"fixture")
                # A source used as a runtime texture must never be treated as optional provenance.
                refs[source] = [{"key": "atlas_path"}]
                self.assertIn("Missing content art: " + source, release.check_referenced_art(root)[0])


if __name__ == "__main__":
    unittest.main()
