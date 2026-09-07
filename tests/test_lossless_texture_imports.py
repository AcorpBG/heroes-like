"""Lossless-import selection, freshness, exact preservation and publication controls."""
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import prepare_lossless_texture_imports as subject
import package_release
from test_compact_export_pck import fixture as pack_fixture
import lossless_texture_package_regression as package_probe

HEADER = b"GST2\x01\0\0\0" + bytes(44)
VERSION = "4.6.2.stable.official.test"


class LosslessImportsTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        (self.root / "project.godot").write_text("[rendering]\n" + subject.FACTOR + "=100.0\n")
        (self.root / "export_presets.cfg").write_text(''.join(
            f'[preset.{i}]\nexport_filter="all_resources"\nexclude_filter="art/*/source/*"\n' for i in (0, 1)))
        self.source = "art/towns/runtime/paint.png"
        self.texture = ".godot/imported/paint.png-hash.ctex"
        self.add_texture(self.source, self.texture)

    def add_texture(self, source, texture, mode=0):
        path = self.root / source
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(b"original source fixture, not a rendered image")
        (self.root / (source + ".import")).write_text(
            f'[remap]\nimporter="texture"\npath="res://{texture}"\n[deps]\nsource_file="res://{source}"\n[params]\ncompress/mode={mode}\n')
        cache = self.root / texture
        cache.parent.mkdir(parents=True, exist_ok=True)
        cache.write_bytes(HEADER + b"old lossless bytes")
        (self.root / (texture[:-5] + ".md5")).write_text(
            'source_md5="' + hashlib.md5(path.read_bytes()).hexdigest() + '"\n')

    def candidate(self, root, rows, work, factor, godot, log):
        work.mkdir()
        (work / "project.godot").write_text("fixture")
        for row in rows:
            for relative in (row["cache"], row["cache"][:-5] + ".md5"):
                path = work / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(HEADER + b"new" if relative.endswith(".ctex") else b'metadata\n')

    def decoded(self, paths, *unused):
        return {str(p): {"width": 10, "height": 9, "format": 5, "mipmaps": 3, "decoded_bytes": 400, "sha256": "a" * 64} for p in paths}

    def prepare(self):
        with mock.patch.object(subject.subprocess, "check_output", return_value=VERSION), mock.patch.object(subject, "import_candidate", side_effect=self.candidate), mock.patch.object(subject, "decode", side_effect=self.decoded):
            return subject.prepare(self.root)

    def test_excludes_source_and_leaves_lossy_untouched(self):
        self.add_texture("art/towns/source/keep.png", ".godot/imported/source.ctex")
        self.add_texture("art/towns/runtime/lossy.png", ".godot/imported/lossy.ctex", mode=1)
        self.assertEqual([r["source"] for r in subject.discover(self.root)], [self.source])

    def test_rejects_mismatched_platform_resource_pools(self):
        path = self.root / "export_presets.cfg"
        path.write_text(path.read_text().replace('preset.1]\nexport_filter="all_resources"', 'preset.1]\nexport_filter="selected_resources"'))
        with self.assertRaises(ValueError): subject.discover(self.root)

    def test_unsafe_remap_and_wrong_source_fail(self):
        path = self.root / (self.source + ".import")
        original = path.read_text()
        for text in (original.replace(self.texture, "../escape.ctex"), original.replace('source_file="res://', 'source_file="else://')):
            path.write_text(text)
            with self.assertRaises(ValueError): subject.discover(self.root)

    def test_rejects_symlink_cache(self):
        path = self.root / self.texture
        target = self.root / "outside.ctex"
        target.write_bytes(path.read_bytes())
        path.unlink()
        try: path.symlink_to(target)
        except OSError: self.skipTest("Symlink privilege unavailable")
        with self.assertRaises(ValueError): subject.discover(self.root)

    def test_stronger_lossless_setting_only(self):
        path = self.root / "project.godot"
        initial = path.read_text()
        for text in (initial.replace("100.0", "25"), initial + "textures/webp_compression/compression_method=6\n", initial + "textures/lossless_compression/force_png=true\n"):
            path.write_text(text)
            with self.assertRaises(ValueError): subject.prepare(self.root)

    def test_exact_verified_cache_skips_reimport(self):
        before_source = (self.root / self.source).read_bytes()
        before_options = (self.root / (self.source + ".import")).read_bytes()
        first, second = self.prepare(), self.prepare()
        self.assertEqual(first["reimported"], 1)
        self.assertGreater(first["saved_bytes"], 0)
        self.assertEqual(second["reimported"], 0)
        self.assertEqual(second["cache_hits"], 1)
        self.assertEqual((self.root / self.source).read_bytes(), before_source)
        self.assertEqual((self.root / (self.source + ".import")).read_bytes(), before_options)

    def test_changed_inputs_use_fresh_default_baseline(self):
        for relative in (self.source, self.source + ".import"):
            self.prepare()
            path = self.root / relative
            path.write_bytes(path.read_bytes() + b"\n")
            result = self.prepare()
            self.assertEqual(result["reimported"], 1)
            self.assertEqual(result["rows"][0]["baseline"], "fresh_default_import")

    def test_missing_or_changed_cache_metadata_is_not_a_hit(self):
        self.prepare()
        path = self.root / (self.texture[:-5] + ".md5")
        path.write_text('source_md5="invalid"\n')
        self.assertEqual(self.prepare()["reimported"], 1)

    def test_changed_output_is_not_a_hit(self):
        self.prepare()
        path = self.root / self.texture
        path.write_bytes(HEADER + b"different encoding")
        self.assertEqual(self.prepare()["reimported"], 1)

    def test_absent_cache_is_rebuilt_and_verified_from_default_import(self):
        (self.root / self.texture).unlink()
        (self.root / (self.texture[:-5] + ".md5")).unlink()
        result = self.prepare()
        self.assertTrue(result["ok"])
        self.assertEqual(result["rows"][0]["baseline"], "fresh_default_import")
        self.assertTrue((self.root / self.texture).exists())

    def test_missing_import_metadata_fails_discovery_instead_of_omitting_asset(self):
        (self.root / (self.source + ".import")).unlink()
        with self.assertRaisesRegex(ValueError, "new raster"): subject.discover(self.root)

    def test_matching_stamp_without_decoded_proof_is_not_a_hit(self):
        self.prepare()
        path = self.root / ".godot/lossless-imports.json"
        memo = json.loads(path.read_text())
        del memo[self.source]["proof"]
        path.write_text(json.dumps(memo))
        self.assertEqual(self.prepare()["reimported"], 1)

    def test_every_decoded_field_and_header_is_authoritative(self):
        original = (self.root / self.texture).read_bytes()
        for key in ("width", "height", "format", "mipmaps", "decoded_bytes", "sha256"):
            def unequal(paths, *unused):
                result = self.decoded(paths)
                result[str(paths[-1])][key] = "changed"
                return result
            with mock.patch.object(subject.subprocess, "check_output", return_value=VERSION), mock.patch.object(subject, "import_candidate", side_effect=self.candidate), mock.patch.object(subject, "decode", side_effect=unequal):
                with self.assertRaisesRegex(ValueError, "pixels/mipmaps changed"):
                    subject.prepare(self.root)
            self.assertEqual((self.root / self.texture).read_bytes(), original)
            self.assertFalse((self.root / ".godot/lossless-imports.json").exists())

    def test_import_failure_preserves_original(self):
        original = (self.root / self.texture).read_bytes()
        with mock.patch.object(subject.subprocess, "check_output", return_value=VERSION), mock.patch.object(subject, "import_candidate", side_effect=ValueError("import failed")):
            with self.assertRaisesRegex(ValueError, "import failed"): subject.prepare(self.root)
        self.assertEqual((self.root / self.texture).read_bytes(), original)
        self.assertFalse((self.root / ".godot/lossless-import.lock").exists())

    def test_unknown_engine_and_live_writer_fail_closed(self):
        with mock.patch.object(subject.subprocess, "check_output", return_value="4.7.stable"):
            with self.assertRaisesRegex(ValueError, "Revalidate"): subject.prepare(self.root)
        (self.root / ".godot/lossless-import.lock").mkdir()
        with mock.patch.object(subject.subprocess, "check_output", return_value=VERSION):
            with self.assertRaises(FileExistsError): subject.prepare(self.root)
        self.assertTrue((self.root / ".godot/lossless-import.lock").is_dir())

    def test_failed_publication_rolls_back_prior_outputs(self):
        paths = [self.texture, self.texture[:-5] + ".md5"]
        originals = {p: (self.root / p).read_bytes() for p in paths}
        atomic = subject.atomic_write
        calls = 0
        def fail_second(path, data):
            nonlocal calls
            calls += 1
            if calls == 2: raise OSError("injected write failure")
            atomic(path, data)
        with mock.patch.object(subject, "atomic_write", side_effect=fail_second):
            with self.assertRaises(OSError):
                subject.publish(self.root, {p: b"replacement" for p in paths}, {p: subject.sha(self.root / p) for p in paths})
        self.assertEqual({p: (self.root / p).read_bytes() for p in paths}, originals)

    def test_concurrent_cache_change_is_not_overwritten(self):
        path = self.root / self.texture
        original = path.read_bytes()
        with self.assertRaisesRegex(ValueError, "changed during verification"):
            subject.publish(self.root, {self.texture: b"candidate"}, {self.texture: "stale hash"})
        self.assertEqual(path.read_bytes(), original)

    def test_release_stops_before_export_on_failed_preparation(self):
        for spec in package_release.PLATFORMS:
            with mock.patch.object(package_release, "prepare_lossless_imports", side_effect=ValueError("pixels changed")), mock.patch.object(package_release, "run") as run:
                with self.assertRaises(ValueError): package_release.export_platform(spec, self.root / "export", "godot")
                run.assert_not_called()

    def test_complete_package_transfer_and_platform_only_exception(self):
        before, after, windows = [self.root / name for name in ("before.pck", "after.pck", "windows.pck")]
        rows = [(self.texture, b"old" * 100), ("scripts/same.gdc", b"gameplay"), ("project.binary", b"linux")]
        before.write_bytes(pack_fixture(rows))
        updated = [(self.texture, b"new"), *rows[1:]]
        after.write_bytes(pack_fixture(updated))
        windows.write_bytes(pack_fixture([*updated[:-1], ("project.binary", b"windows")]))
        proofs = {self.source: {"proof": {"cache": self.texture, "before_sha256": hashlib.sha256(b"old" * 100).hexdigest(), "after_sha256": hashlib.sha256(b"new").hexdigest()}}}
        report = package_probe.verify(before, after, windows, proofs)
        self.assertEqual(report["members"], 3)
        self.assertEqual(report["changed_texture_members"], 1)
        for bad in ([*updated, ("extra", b"unexpected")], [updated[0], ("scripts/same.gdc", b"changed"), updated[2]], [(self.texture, b"wrong"), *updated[1:]]):
            after.write_bytes(pack_fixture(bad))
            with self.assertRaises(ValueError): package_probe.verify(before, after, windows, proofs)


if __name__ == "__main__":
    unittest.main()
