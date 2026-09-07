"""Lexical/container integrity and non-destructive export compaction controls."""
import hashlib
import json
from pathlib import Path
import random
import struct
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import compact_export_pck as packing
import package_release


def fixture(rows=None):
    rows = rows or [("content/example.json", b'{\n' + b' ' * 160 + b'"name": "fog  buoys", "n": -0.00e+1, "v": [true, null]}\n'),
                    (".godot/imported/paint.ctex", b"unchanged\x00raster\xff"),
                    ("maps/keep.json", b'{ "unchanged": true }'),
                    ("art/source/keep.json", b'{ "unchanged": true }')]
    data = bytearray(struct.pack("<4s5IQQ", b"GDPC", 3, 4, 6, 2, 2, 112, 0) + bytes(72))
    metadata = []
    for path, body in rows:
        offset = len(data) - 112
        data.extend(body)
        data.extend(bytes(-len(data) % 16))
        name = path.encode()
        name += bytes(-len(name) % 4)
        metadata.append(struct.pack("<I", len(name)) + name + struct.pack("<QQ16sI", offset, len(body), hashlib.md5(body).digest(), 0))
    struct.pack_into("<Q", data, 32, len(data))
    data.extend(struct.pack("<I", len(metadata)) + b"".join(metadata))
    return bytes(data)


def independent_strip(data):
    out = bytearray()
    quoted = escaped = False
    for value in data:
        if quoted:
            out.append(value)
            if escaped:
                escaped = False
            elif value == 92:
                escaped = True
            elif value == 34:
                quoted = False
        elif value == 34:
            quoted = True
            out.append(value)
        elif value not in (9, 10, 13, 32):
            out.append(value)
    return bytes(out)


class CompactPackTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.path = Path(self.directory.name) / "game.pck"
        self.original = fixture()
        self.path.write_bytes(self.original)

    def assert_preserved(self):
        self.assertEqual(self.path.read_bytes(), self.original)
        self.assertEqual(list(self.path.parent.glob("*.compact-*")), [])

    def test_only_formatting_changes_with_every_member_verified(self):
        report = packing.compact_export(self.path)
        result = self.path.read_bytes()
        self.assertGreater(report["saved_bytes"], 100)
        self.assertEqual(report["entries_verified"], 4)
        self.assertEqual(report["unchanged_non_json_entries"], 3)
        _, before = packing.read_directory(self.original)
        _, after = packing.read_directory(result)
        for old, new in zip(before, after):
            a = self.original[old.offset:old.offset + old.size]
            b = result[new.offset:new.offset + new.size]
            self.assertEqual(b, independent_strip(a) if old.path.startswith("content/") else a)
        self.assertEqual(packing.compact_export(self.path)["saved_bytes"], 0)
        self.assertEqual(self.path.read_bytes(), result)

    def test_preserves_number_spelling_escapes_duplicates_and_utf8(self):
        raw = b' { "n": -0.00e+1, "n": 9007199254740993, "u": "\\u4f60", "q": " a \\\" \\\\ b ", "s": "' + "雪".encode() + b'" } '
        self.assertEqual(packing.compact_json(raw), independent_strip(raw))

    def test_two_fresh_exports_compact_identically(self):
        other = self.path.parent / "other.pck"
        other.write_bytes(self.original)
        packing.compact_export(self.path)
        packing.compact_export(other)
        self.assertEqual(self.path.read_bytes(), other.read_bytes())

    def test_random_json_against_independent_scanner_and_parser(self):
        rng = random.Random(10236)
        for _ in range(100):
            obj = {"text": "a \t\n\\\" 雪", "v": [rng.random(), rng.randrange(10**20), None, True]}
            raw = json.dumps(obj, indent=rng.randrange(1, 8), ensure_ascii=rng.choice([True, False])).encode()
            result = packing.compact_json(raw)
            self.assertEqual(result, independent_strip(raw))
            self.assertEqual(json.loads(result), obj)

    def test_rejects_invalid_json_without_repairing_it(self):
        for raw in [b'{"a":NaN}', b'{"a":Infinity}', b'{"a":1 2}', b'"unterminated', b'{} {}', b'{/*comment*/}']:
            with self.subTest(raw=raw), self.assertRaises(ValueError):
                packing.compact_json(raw)

    def test_runtime_art_manifest_but_not_source_or_maps(self):
        self.assertTrue(packing.eligible("art/overworld/manifest.json"))
        for path in ["maps/save.json", "art/towns/source/generated/provenance.json", "scripts/example.json", "content/image.png"]:
            self.assertFalse(packing.eligible(path))

    def test_unsupported_headers_preserve_export(self):
        for offset, value in [(4, 2), (8, 5), (12, 7), (20, 3), (20, 6), (40, 1)]:
            with self.subTest(offset=offset, value=value):
                raw = bytearray(self.original)
                struct.pack_into("<I", raw, offset, value)
                self.path.write_bytes(raw)
                with self.assertRaises(ValueError): packing.compact_export(self.path)
                self.assertEqual(self.path.read_bytes(), raw)

    def test_corrupt_digest_preserves_export(self):
        raw = bytearray(self.original)
        raw[115] ^= 1
        self.original = bytes(raw)
        self.path.write_bytes(raw)
        with self.assertRaisesRegex(ValueError, "digest mismatch"): packing.compact_export(self.path)
        self.assert_preserved()

    def test_truncated_and_trailing_data_rejected(self):
        for raw in [self.original[:103], self.original[:-1], self.original + b"appended data not padding"]:
            with self.subTest(size=len(raw)), self.assertRaises(ValueError): packing.read_directory(raw)

    def test_duplicate_and_unsafe_names_rejected(self):
        for name in ["../escape", "/absolute", "res://file", "a//b", "a\\b", "a/./b"]:
            with self.subTest(name=name), self.assertRaises(ValueError):
                packing.read_directory(fixture([(name, b"data")]))
        with self.assertRaises(ValueError):
            packing.read_directory(fixture([("same", b"1"), ("same", b"2")]))

    def test_entry_flags_and_ranges_rejected(self):
        directory = struct.unpack_from("<Q", self.original, 32)[0]
        length = struct.unpack_from("<I", self.original, directory + 4)[0]
        metadata = directory + 8 + length
        for offset, fmt, value in [(metadata, "<Q", len(self.original)), (metadata + 8, "<Q", len(self.original)), (metadata + 32, "<I", 1), (metadata + 32, "<I", 2), (metadata + 32, "<I", 4)]:
            with self.subTest(offset=offset, value=value):
                raw = bytearray(self.original)
                struct.pack_into(fmt, raw, offset, value)
                with self.assertRaises(ValueError): packing.read_directory(raw)

    def test_overlapping_valid_payloads_rejected(self):
        raw = bytearray(fixture([("one", b"identical"), ("two", b"identical")]))
        directory = struct.unpack_from("<Q", raw, 32)[0]
        struct.pack_into("<Q", raw, directory + 4 + 44 + 8, 0)
        with self.assertRaisesRegex(ValueError, "Overlapping"): packing.read_directory(raw)

    def test_invalid_json_inside_valid_pack_preserves_export(self):
        self.original = fixture([("content/bad.json", b'{"v": bad}')])
        self.path.write_bytes(self.original)
        with self.assertRaises(ValueError): packing.compact_export(self.path)
        self.assert_preserved()

    def test_failed_verification_preserves_export(self):
        with mock.patch.object(packing, "verify_payloads", side_effect=ValueError("injected verification failure")):
            with self.assertRaises(ValueError): packing.compact_export(self.path)
        self.assert_preserved()

    def test_failed_replace_preserves_export(self):
        with mock.patch.object(packing.os, "replace", side_effect=OSError("injected replace failure")):
            with self.assertRaises(OSError): packing.compact_export(self.path)
        self.assert_preserved()

    def test_failed_write_preserves_export(self):
        with mock.patch.object(packing.os, "fsync", side_effect=OSError("injected flush failure")):
            with self.assertRaises(OSError): packing.compact_export(self.path)
        self.assert_preserved()

    def test_concurrent_change_is_not_overwritten(self):
        verify = packing.verify_payloads
        def concurrent(before, after):
            result = verify(before, after)
            self.path.write_bytes(b"new externally written export")
            return result
        with mock.patch.object(packing, "verify_payloads", side_effect=concurrent):
            with self.assertRaisesRegex(ValueError, "changed during"): packing.compact_export(self.path)
        self.assertEqual(self.path.read_bytes(), b"new externally written export")
        self.assertEqual(list(self.path.parent.glob("*.compact-*")), [])

    def test_link_and_non_pack_rejected(self):
        link = self.path.parent / "linked.pck"
        try:
            link.symlink_to(self.path)
        except OSError:
            # Windows without symlink privilege still covers the path guard below.
            pass
        for path in [link, self.path.parent, self.path.with_suffix(".exe")]:
            with self.subTest(path=path), self.assertRaises(ValueError): packing.compact_export(path)
        self.assert_preserved()

    def test_production_builder_compacts_both_platforms(self):
        for spec in package_release.PLATFORMS:
            out = self.path.parent / spec.platform_id
            def fake_export(command):
                (out / "heroes-like.pck").write_bytes(self.original)
            with self.subTest(platform=spec.platform_id), mock.patch.object(package_release, "prepare_lossless_imports") as prepare, mock.patch.object(package_release, "run", side_effect=fake_export):
                package_release.export_platform(spec, out, "test-godot")
                prepare.assert_called_once_with(package_release.ROOT, "test-godot")
                self.assertLess((out / "heroes-like.pck").stat().st_size, len(self.original))

    def test_production_builder_stops_on_invalid_pack(self):
        out = self.path.parent / "bad-export"
        def fake_export(command):
            (out / "heroes-like.pck").write_bytes(b"bad exported pack")
        with mock.patch.object(package_release, "prepare_lossless_imports"), mock.patch.object(package_release, "run", side_effect=fake_export):
            with self.assertRaises(ValueError):
                package_release.export_platform(package_release.PLATFORMS[0], out, "test-godot")
        self.assertEqual((out / "heroes-like.pck").read_bytes(), b"bad exported pack")


if __name__ == "__main__":
    unittest.main()
