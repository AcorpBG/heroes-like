"""No content-size budget; retain the actual export and payload integrity gates.

Synthetic sizes avoid allocating oversized files in unit tests. Official exports
and the packaged Town flow separately exercise the real >250 MB game package.
"""
import ast
import hashlib
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import lossless_texture_package_regression as lossless


ROOT = Path(__file__).resolve().parents[1]


def export_gate(platform, size):
    path = ROOT / f"tests/packaging_{platform}_export_smoke.py"
    tree = ast.parse(path.read_text())
    main = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == "main")
    gate = next(node.value for node in main.body if isinstance(node, ast.Assign)
                and any(isinstance(target, ast.Name) and target.id == "export_ok" for target in node.targets))
    payload_keys = {node.slice.value for node in ast.walk(gate)
                    if isinstance(node, ast.Subscript) and isinstance(node.value, ast.Name)
                    and node.value.id == "terrain_payload" and isinstance(node.slice, ast.Constant)}
    context = dict(export_result={"returncode": 0, "timed_out": False},
                   compaction={"ok": True}, export_fatal_matches=[], fatal_matches=[],
                   binary={"exists": True, "large_enough": True, "executable": True},
                   exe={"exists": True, "large_enough": True},
                   pck={"exists": True, "large_enough": True, "size_bytes": size},
                   header={"elf_header": True, "x86_64": True, "mz_header": True, "pe_header": True},
                   libraries={"all_exported": True}, dlls={"all_exported": True},
                   terrain_payload={key: [] if key.startswith("forbidden_") else True for key in payload_keys})
    return compile(ast.Expression(gate), str(path), "eval"), context, tree


class PackageSizePolicyTests(unittest.TestCase):
    def test_actual_export_decisions_have_no_upper_size_budget(self):
        for platform in ("linux", "windows"):
            for size in (250_000_001, 350_000_001, 1_000_000_000_000):
                with self.subTest(platform=platform, size=size):
                    code, context, _ = export_gate(platform, size)
                    self.assertTrue(eval(code, context))

    def test_every_payload_integrity_condition_still_rejects_invalid_content(self):
        for platform in ("linux", "windows"):
            code, context, _ = export_gate(platform, 350_000_001)
            payload = context["terrain_payload"]
            self.assertTrue({"source_art_excluded", "valid_directory", "required_entries_present",
                             "runtime_audio_entries_present", "town_scenic_backdrop_entries_present",
                             "forbidden_entries", "forbidden_development_entries"} <= payload.keys())
            for key, value in list(payload.items()):
                with self.subTest(platform=platform, invalid=key):
                    payload[key] = ["unexpected asset"] if key.startswith("forbidden_") else False
                    self.assertFalse(eval(code, context))
                    payload[key] = value

    def test_export_binary_and_compaction_failures_still_reject(self):
        for platform in ("linux", "windows"):
            for owner, key, value in (("export_result", "returncode", 1),
                                       ("export_result", "timed_out", True),
                                       ("compaction", "ok", False), ("pck", "exists", False),
                                       ("pck", "large_enough", False),
                                       ("header", "elf_header" if platform == "linux" else "pe_header", False),
                                       ("libraries" if platform == "linux" else "dlls", "all_exported", False)):
                with self.subTest(platform=platform, invalid=(owner, key)):
                    code, context, _ = export_gate(platform, 350_000_001)
                    context[owner][key] = value
                    self.assertFalse(eval(code, context))
            code, context, _ = export_gate(platform, 350_000_001)
            context["export_fatal_matches" if platform == "linux" else "fatal_matches"] = ["ERROR:"]
            self.assertFalse(eval(code, context))

    def test_size_reporting_remains_without_obsolete_boolean_gate(self):
        for platform in ("linux", "windows"):
            _, _, tree = export_gate(platform, 350_000_001)
            strings = {node.value for node in ast.walk(tree) if isinstance(node, ast.Constant) and isinstance(node.value, str)}
            self.assertIn("pck_size_bytes", strings)
            self.assertNotIn("pck_within_release_size_ceiling", strings)

    def test_packaged_town_preflight_retains_identity_without_size_guard(self):
        source = (ROOT / "tests/packaged_town_scene_layer_regression.py").read_text()
        tree = ast.parse(source)
        for node in ast.walk(tree):
            if isinstance(node, ast.If):
                self.assertNotIn("len(payload)", ast.unparse(node.test))
        for message in ("export directory contains non-package files or symlinks",
                        "release pack does not contain the current exact scene-art manifest",
                        "release pack is missing required compiled Town/bootstrap owners"):
            self.assertIn(message, source)
        self.assertIn("read_directory(payload)", source)
        self.assertIn("pack_bytes=pack.stat().st_size", source)


class SyntheticPack:
    def __init__(self, name, size):
        self.name, self.size = name, size

    def stat(self):
        return SimpleNamespace(st_size=self.size)

    def read_bytes(self):
        return self.name.encode()


class LosslessSizePolicyTests(unittest.TestCase):
    def setUp(self):
        self.before = SyntheticPack("before", 400_000_100)
        self.after = SyntheticPack("after", 400_000_000)
        self.windows = SyntheticPack("windows", 400_000_000)
        self.original = {"art.ctex": b"old", "content.json": b"same", "project.binary": b"linux"}
        self.result = dict(self.original, **{"art.ctex": b"new"})
        self.win = dict(self.result, **{"project.binary": b"windows"})
        self.proofs = {"art": {"proof": {"cache": "art.ctex",
                       "before_sha256": hashlib.sha256(b"old").hexdigest(),
                       "after_sha256": hashlib.sha256(b"new").hexdigest()}}}

    def verify(self):
        with patch.object(lossless, "members", side_effect=[self.original, self.result, self.win]):
            return lossless.verify(self.before, self.after, self.windows, self.proofs)

    def test_real_savings_accepted_above_old_budget(self):
        result = self.verify()
        self.assertTrue(result["ok"])
        self.assertEqual(result["saved_bytes"], 100)
        self.assertEqual(result["after_bytes"], 400_000_000)
        self.assertNotIn("headroom_bytes", result)

    def test_no_savings_still_fails(self):
        self.after.size = self.before.size
        with self.assertRaisesRegex(ValueError, "No measured lossless package saving"):
            self.verify()

    def test_changed_non_target_still_fails(self):
        self.result["content.json"] = b"different"
        with self.assertRaisesRegex(ValueError, "Non-target exported member changed"):
            self.verify()

    def test_wrong_texture_still_fails(self):
        self.result["art.ctex"] = b"unproven"
        with self.assertRaisesRegex(ValueError, "Export did not use verified texture"):
            self.verify()

    def test_missing_member_still_fails(self):
        del self.result["art.ctex"]
        with self.assertRaisesRegex(ValueError, "Exported member set changed"):
            self.verify()

    def test_platform_drift_still_fails(self):
        self.win["content.json"] = b"different"
        with self.assertRaisesRegex(ValueError, "Linux/Windows payload drift"):
            self.verify()


if __name__ == "__main__":
    unittest.main()
