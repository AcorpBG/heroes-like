#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import struct
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "tools" / "build_release_candidate.py"
SPEC = importlib.util.spec_from_file_location("build_release_candidate", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
release_candidate = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = release_candidate
SPEC.loader.exec_module(release_candidate)


REVISION = "a" * 40


class ReleaseCandidatePipelineTest(unittest.TestCase):
	def test_command_plan_rebuilds_and_tests_both_platforms_before_packaging(self) -> None:
		tools = {
			"python": "/tools/python3",
			"cmake": "/tools/cmake",
			"godot": "/tools/godot",
			"wine": "/tools/wine",
			"makensis": "/tools/makensis",
			"c_compiler": "/tools/x86_64-w64-mingw32-gcc",
			"cxx_compiler": "/tools/x86_64-w64-mingw32-g++",
		}
		plan = release_candidate.command_plan(
			Path("/build"), Path("/release"), REVISION, "0.1.0-rc1", 3, tools
		)
		ids = [step.id for step in plan]
		self.assertEqual(
			ids,
			[
				"configure_linux_release",
				"build_linux_release",
				"selftest_linux_release",
				"configure_windows_release",
				"build_windows_release",
				"selftest_windows_release",
				"parse_project",
				"validate_repository",
				"package_release",
				"verify_release",
			],
		)
		windows_configure = plan[3].command
		self.assertIn("-DCMAKE_SYSTEM_NAME=Windows", windows_configure)
		self.assertIn("-DCMAKE_SYSTEM_PROCESSOR=x86_64", windows_configure)
		self.assertEqual(plan[5].command[0], tools["wine"])
		package = plan[8].command
		self.assertIn("--source-revision", package)
		self.assertEqual(package[package.index("--source-revision") + 1], REVISION)
		self.assertIn("--godot", package)
		self.assertIn("--makensis", package)

	def test_revision_must_be_full_lowercase_git_object_id(self) -> None:
		self.assertEqual(release_candidate.safe_revision(REVISION), REVISION)
		for value in ("abc", "A" * 40, "g" * 40, "a" * 39):
			with self.assertRaises(ValueError):
				release_candidate.safe_revision(value)

	def test_source_revision_rejects_mismatched_head_and_dirty_checkout(self) -> None:
		clean = subprocess.CompletedProcess([], 0, "", "")
		head = subprocess.CompletedProcess([], 0, REVISION + "\n", "")
		with mock.patch.object(release_candidate, "run_capture", side_effect=[head]):
			with self.assertRaisesRegex(RuntimeError, "does not match"):
				release_candidate.resolve_source_revision("b" * 40)
		dirty = subprocess.CompletedProcess([], 0, " M tracked.file\n", "")
		with mock.patch.object(release_candidate, "run_capture", side_effect=[head, dirty]):
			with self.assertRaisesRegex(RuntimeError, "clean tracked worktree"):
				release_candidate.resolve_source_revision(REVISION)
		with mock.patch.object(release_candidate, "run_capture", side_effect=[head, clean]):
			self.assertEqual(release_candidate.resolve_source_revision(REVISION), REVISION)
		allowed = subprocess.CompletedProcess([], 0, "?? build/cache.bin\n?? tools/__pycache__/tool.pyc\n", "")
		with mock.patch.object(release_candidate, "run_capture", side_effect=[head, allowed]):
			self.assertEqual(release_candidate.resolve_source_revision(REVISION), REVISION)
		unexpected = subprocess.CompletedProcess([], 0, "?? scripts/core/untracked_rule.gd\n", "")
		with mock.patch.object(release_candidate, "run_capture", side_effect=[head, unexpected]):
			with self.assertRaisesRegex(RuntimeError, "unexpected untracked source"):
				release_candidate.resolve_source_revision(REVISION)

	def test_release_output_reset_refuses_repository_paths(self) -> None:
		for path in (release_candidate.ROOT, release_candidate.ROOT.parent, Path.home(), Path("/")):
			with self.assertRaisesRegex(RuntimeError, "unsafe release output"):
				release_candidate.reset_release_output(path)
			with self.assertRaisesRegex(RuntimeError, "unsafe native build root"):
				release_candidate.clean_owned_build_outputs(path)

	def test_native_output_rejects_stale_and_wrong_architecture_payloads(self) -> None:
		with tempfile.TemporaryDirectory() as temp_value:
			temp = Path(temp_value)
			elf_path = temp / "release.so"
			elf = bytearray(4096)
			elf[:4] = b"\x7fELF"
			elf[4] = 2
			elf[18:20] = (0x3E).to_bytes(2, "little")
			elf_path.write_bytes(elf)
			started_ns = time.time_ns() - 1_000_000_000
			output = release_candidate.NativeOutput("linux-x86_64", elf_path, "elf64-x86_64")
			summary = release_candidate.verify_native_output(output, started_ns)
			self.assertEqual(summary["format"], "elf64-x86_64")

			future_ns = time.time_ns() + 1_000_000_000
			with self.assertRaisesRegex(RuntimeError, "stale"):
				release_candidate.verify_native_output(output, future_ns)

			elf[18:20] = (0xB7).to_bytes(2, "little")
			elf_path.write_bytes(elf)
			with self.assertRaisesRegex(RuntimeError, "not x86_64"):
				release_candidate.verify_native_output(output, started_ns)

	def test_pe_validation_accepts_only_x86_64(self) -> None:
		head = bytearray(4096)
		head[:2] = b"MZ"
		struct.pack_into("<I", head, 0x3C, 0x80)
		head[0x80:0x84] = b"PE\0\0"
		struct.pack_into("<H", head, 0x84, 0x8664)
		release_candidate.verify_pe_x86_64(bytes(head))
		struct.pack_into("<H", head, 0x84, 0x014C)
		with self.assertRaisesRegex(RuntimeError, "not x86_64"):
			release_candidate.verify_pe_x86_64(bytes(head))

	def test_captured_step_accepts_tool_output_before_final_json_object(self) -> None:
		payload = release_candidate.parse_final_json_line(
			"Processing installer payload\n{\"ok\": true, \"version\": \"0.1.0-rc1\"}\n",
			"package_release",
		)
		self.assertEqual(payload, {"ok": True, "version": "0.1.0-rc1"})
		with self.assertRaisesRegex(RuntimeError, "did not emit valid JSON"):
			release_candidate.parse_final_json_line("{\"ok\": true}\ntrailing noise\n", "package_release")
		with self.assertRaisesRegex(RuntimeError, "JSON object"):
			release_candidate.parse_final_json_line("[]\n", "package_release")

	def test_workflow_uses_clean_recursive_checkout_and_single_driver(self) -> None:
		workflow = (ROOT / ".github" / "workflows" / "release-candidate.yml").read_text(encoding="utf-8")
		for token in (
			"actions/checkout@v6",
			"submodules: recursive",
			"actions/setup-python@v5",
			"tools/build_release_candidate.py",
			"--source-revision \"$RELEASE_SOURCE_REVISION\"",
			"actions/upload-artifact@v7",
			"if-no-files-found: error",
			"config\\/version=",
		):
			self.assertIn(token, workflow)
		self.assertNotIn("gh release create", workflow)


if __name__ == "__main__":
	unittest.main()
