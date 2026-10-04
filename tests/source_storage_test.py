"""Regression coverage for archive boundaries and slim release references."""
from contextlib import redirect_stdout
import hashlib
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from check_source_material_tracking import archived_media
import restore_archived_source_material as restore
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

    def test_restore_writes_only_verified_requested_sources_and_keeps_local_edits(self):
        payloads = {
            "art/units/source/curated/a.png": b"alpha",
            "art/units/source/curated/b.png": b"bravo",
            "art/heroes/source/curated/c.png": b"charlie",
        }
        with tempfile.TemporaryDirectory() as temp:
            archive_dir, root = Path(temp) / "archive", Path(temp) / "repo"
            archive_dir.mkdir()
            root.mkdir()
            with zipfile.ZipFile(archive_dir / "art.zip", "w") as archive:
                for name, data in payloads.items():
                    archive.writestr(name, data)
            rows = [{"path": n, "bytes": len(d), "sha256": hashlib.sha256(d).hexdigest()} for n, d in payloads.items()]
            (archive_dir / "art.zip.manifest.json").write_text(json.dumps({"files": rows}), encoding="utf-8")
            (archive_dir / "archive-index.json").write_text(
                json.dumps({"archives": [{"archive": "art.zip", "manifest": "art.zip.manifest.json"}]}), encoding="utf-8")
            args = ["--archive-dir", str(archive_dir), "--root", str(root), "--prefix", "art/units/source/curated/"]
            with redirect_stdout(io.StringIO()):
                self.assertEqual(restore.main(args), 0)
                self.assertFalse((root / "art/units/source/curated/a.png").exists(), "dry run must not write")
                self.assertEqual(restore.main(args + ["--apply"]), 0)
            self.assertEqual((root / "art/units/source/curated/a.png").read_bytes(), b"alpha")
            self.assertFalse((root / "art/heroes/source/curated/c.png").exists(), "only the selection is restored")
            (root / "art/units/source/curated/b.png").write_bytes(b"local edit")
            with redirect_stdout(io.StringIO()) as output:
                self.assertEqual(restore.main(args + ["--apply"]), 1)
            self.assertIn("CONFLICT", output.getvalue())
            self.assertEqual((root / "art/units/source/curated/b.png").read_bytes(), b"local edit")
            with redirect_stdout(io.StringIO()):
                self.assertEqual(restore.main(["--archive-dir", str(archive_dir), "--root", str(root), "--path", "art/units/source/curated/missing.png"]), 1)
            with self.assertRaises(ValueError):
                restore.safe_target(root, "art/units/source/../../escape.png")


if __name__ == "__main__":
    unittest.main()
