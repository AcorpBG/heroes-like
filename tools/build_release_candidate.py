#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import struct
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Sequence


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
	sys.path.insert(0, str(ROOT))

from tools.package_release import validate_windows_export_preset_version, windows_numeric_version

SCHEMA_ID = "heroes_like_release_candidate_v1"
DEFAULT_OUTPUT_DIR = ROOT / ".artifacts" / "release-candidate"
DEFAULT_BUILD_ROOT = ROOT / ".artifacts" / "release-candidate-native"
REVISION_PATTERN = re.compile(r"[0-9a-f]{40}|[0-9a-f]{64}")
ALLOWED_UNTRACKED_PREFIXES = (
	".artifacts/",
	".godot/",
	"build/",
	"tests/__pycache__/",
	"tools/__pycache__/",
)


@dataclass(frozen=True)
class NativeOutput:
	platform: str
	path: Path
	format: str


@dataclass(frozen=True)
class CommandStep:
	id: str
	command: tuple[str, ...]


NATIVE_OUTPUTS = (
	NativeOutput(
		"linux-x86_64",
		ROOT / "bin" / "libaurelion_map_persistence.linux.template_release.x86_64.so",
		"elf64-x86_64",
	),
	NativeOutput(
		"linux-x86_64",
		ROOT / "bin" / "h3maped_rmg_core_selftest",
		"elf64-x86_64",
	),
	NativeOutput(
		"windows-x86_64",
		ROOT / "bin" / "aurelion_map_persistence.windows.template_release.x86_64.dll",
		"pe32plus-x86_64",
	),
	NativeOutput(
		"windows-x86_64",
		ROOT / "bin" / "h3maped_rmg_core_selftest.exe",
		"pe32plus-x86_64",
	),
)


def safe_revision(value: str) -> str:
	normalized = value.strip()
	if REVISION_PATTERN.fullmatch(normalized) is None:
		raise ValueError("source revision must be a full lowercase Git object id")
	return normalized


def run_capture(command: Sequence[str]) -> subprocess.CompletedProcess[str]:
	return subprocess.run(
		list(command),
		cwd=ROOT,
		stdout=subprocess.PIPE,
		stderr=subprocess.PIPE,
		text=True,
		check=False,
	)


def git_head_revision() -> str:
	result = run_capture(("git", "rev-parse", "--verify", "HEAD"))
	if result.returncode != 0:
		raise RuntimeError(f"cannot resolve release source revision: {result.stderr.strip()}")
	return safe_revision(result.stdout)


def resolve_source_revision(explicit_revision: str) -> str:
	head = git_head_revision()
	if explicit_revision and safe_revision(explicit_revision) != head:
		raise RuntimeError("requested source revision does not match checked-out HEAD")
	status = run_capture(("git", "status", "--porcelain", "--untracked-files=all"))
	if status.returncode != 0:
		raise RuntimeError(f"cannot inspect release source worktree: {status.stderr.strip()}")
	tracked_changes = []
	unexpected_untracked = []
	for line in status.stdout.splitlines():
		if line.startswith("?? "):
			path = line[3:]
			if not path.startswith(ALLOWED_UNTRACKED_PREFIXES):
				unexpected_untracked.append(path)
		else:
			tracked_changes.append(line)
	if tracked_changes:
		raise RuntimeError("release candidate requires a clean tracked worktree")
	if unexpected_untracked:
		raise RuntimeError(f"release candidate found unexpected untracked source: {unexpected_untracked[0]}")
	return head


def source_date_epoch(revision: str) -> int:
	result = run_capture(("git", "show", "-s", "--format=%ct", revision))
	if result.returncode != 0 or not result.stdout.strip().isdigit():
		raise RuntimeError("cannot resolve source commit timestamp")
	return int(result.stdout.strip())


def executable(value: str, label: str) -> str:
	path = shutil.which(value)
	if path is None and Path(value).is_file():
		path = str(Path(value).resolve())
	if path is None:
		raise RuntimeError(f"required {label} executable not found: {value}")
	return path


def command_plan(
	build_root: Path,
	output_dir: Path,
	revision: str,
	version: str,
	jobs: int,
	tools: dict[str, str],
) -> list[CommandStep]:
	linux_build = build_root / "linux-release"
	windows_build = build_root / "windows-release"
	cmake = tools["cmake"]
	python = tools["python"]
	return [
		CommandStep(
			"configure_linux_release",
			(
				cmake,
				"-S",
				str(ROOT / "src" / "gdextension"),
				"-B",
				str(linux_build),
				"-DCMAKE_BUILD_TYPE=Release",
			),
		),
		CommandStep(
			"build_linux_release",
			(
				cmake,
				"--build",
				str(linux_build),
				"--target",
				"aurelion_map_persistence",
				"h3maped_rmg_core_selftest",
				"--parallel",
				str(jobs),
			),
		),
		CommandStep(
			"selftest_linux_release",
			(str(ROOT / "bin" / "h3maped_rmg_core_selftest"),),
		),
		CommandStep(
			"configure_windows_release",
			(
				cmake,
				"-S",
				str(ROOT / "src" / "gdextension"),
				"-B",
				str(windows_build),
				"-DCMAKE_SYSTEM_NAME=Windows",
				"-DCMAKE_SYSTEM_PROCESSOR=x86_64",
				f"-DCMAKE_C_COMPILER={tools['c_compiler']}",
				f"-DCMAKE_CXX_COMPILER={tools['cxx_compiler']}",
				"-DCMAKE_BUILD_TYPE=Release",
			),
		),
		CommandStep(
			"build_windows_release",
			(
				cmake,
				"--build",
				str(windows_build),
				"--target",
				"aurelion_map_persistence",
				"h3maped_rmg_core_selftest",
				"--parallel",
				str(jobs),
			),
		),
		CommandStep(
			"selftest_windows_release",
			(tools["wine"], str(ROOT / "bin" / "h3maped_rmg_core_selftest.exe")),
		),
		CommandStep(
			"parse_project",
			(tools["godot"], "--headless", "--path", str(ROOT), "--editor", "--quit"),
		),
		CommandStep(
			"validate_repository",
			(python, str(ROOT / "tests" / "validate_repo.py")),
		),
		CommandStep(
			"package_release",
			(
				python,
				str(ROOT / "tools" / "package_release.py"),
				"--version",
				version,
				"--output-dir",
				str(output_dir),
				"--godot",
				tools["godot"],
				"--makensis",
				tools["makensis"],
				"--source-revision",
				revision,
			),
		),
		CommandStep(
			"verify_release",
			(
				python,
				str(ROOT / "tools" / "package_release.py"),
				"--output-dir",
				str(output_dir),
				"--verify-only",
			),
		),
	]


def sha256(path: Path) -> str:
	digest = hashlib.sha256()
	with path.open("rb") as handle:
		for chunk in iter(lambda: handle.read(1024 * 1024), b""):
			digest.update(chunk)
	return digest.hexdigest()


def verify_elf_x86_64(head: bytes) -> None:
	if len(head) < 20 or head[:4] != b"\x7fELF" or head[4] != 2:
		raise RuntimeError("native Linux output is not ELF64")
	if int.from_bytes(head[18:20], "little") != 0x3E:
		raise RuntimeError("native Linux output is not x86_64")


def verify_pe_x86_64(head: bytes) -> None:
	if len(head) < 0x40 or head[:2] != b"MZ":
		raise RuntimeError("native Windows output is not PE")
	pe_offset = struct.unpack_from("<I", head, 0x3C)[0]
	if pe_offset + 6 > len(head) or head[pe_offset : pe_offset + 4] != b"PE\0\0":
		raise RuntimeError("native Windows output has an invalid PE header")
	if struct.unpack_from("<H", head, pe_offset + 4)[0] != 0x8664:
		raise RuntimeError("native Windows output is not x86_64")


def verify_native_output(output: NativeOutput, build_started_ns: int) -> dict[str, object]:
	if not output.path.is_file():
		raise RuntimeError(f"missing native release output: {output.path}")
	stat = output.path.stat()
	if stat.st_size < 4096:
		raise RuntimeError(f"native release output is too small: {output.path}")
	if stat.st_mtime_ns < build_started_ns:
		raise RuntimeError(f"native release output is stale: {output.path}")
	with output.path.open("rb") as handle:
		head = handle.read(4096)
	if output.format == "elf64-x86_64":
		verify_elf_x86_64(head)
	else:
		verify_pe_x86_64(head)
	try:
		reported_path = str(output.path.relative_to(ROOT))
	except ValueError:
		reported_path = str(output.path)
	return {
		"platform": output.platform,
		"path": reported_path,
		"format": output.format,
		"size_bytes": stat.st_size,
		"sha256": sha256(output.path),
	}


def clean_owned_build_outputs(build_root: Path) -> int:
	protect_owned_directory(build_root, "native build root")
	if build_root.exists():
		shutil.rmtree(build_root)
	build_root.mkdir(parents=True, exist_ok=True)
	for output in NATIVE_OUTPUTS:
		output.path.unlink(missing_ok=True)
	return time.time_ns()


def protect_owned_directory(path: Path, label: str) -> None:
	protected = {Path("/"), ROOT, ROOT.parent, Path.home()}
	if path in protected:
		raise RuntimeError(f"refusing to reset unsafe {label}: {path}")


def reset_release_output(output_dir: Path) -> None:
	protect_owned_directory(output_dir, "release output directory")
	if output_dir.exists():
		shutil.rmtree(output_dir)
	output_dir.mkdir(parents=True, exist_ok=True)


def run_step(step: CommandStep, env: dict[str, str], capture_json: bool = False) -> tuple[dict[str, object], dict | None]:
	print(f"release_candidate: {step.id}", file=sys.stderr, flush=True)
	started = time.monotonic()
	result = subprocess.run(
		list(step.command),
		cwd=ROOT,
		env=env,
		stdout=subprocess.PIPE if capture_json else None,
		stderr=subprocess.PIPE if capture_json else None,
		text=True,
		check=False,
	)
	duration = round(time.monotonic() - started, 3)
	if result.returncode != 0:
		detail = ""
		if capture_json:
			detail = (result.stderr or result.stdout or "").strip()
		raise RuntimeError(f"{step.id} failed with exit code {result.returncode}{': ' + detail if detail else ''}")
	payload = None
	if capture_json:
		payload = parse_final_json_line(result.stdout, step.id)
	return {
		"id": step.id,
		"command": list(step.command),
		"duration_seconds": duration,
		"ok": True,
	}, payload


def parse_final_json_line(output: str, step_id: str) -> dict:
	lines = output.rstrip().splitlines()
	if not lines:
		raise RuntimeError(f"{step_id} did not emit valid JSON")
	try:
		payload = json.loads(lines[-1])
	except json.JSONDecodeError as exc:
		raise RuntimeError(f"{step_id} did not emit valid JSON") from exc
	if not isinstance(payload, dict):
		raise RuntimeError(f"{step_id} did not emit a JSON object")
	return payload


def parse_args() -> argparse.Namespace:
	parser = argparse.ArgumentParser(description="Build and verify one Linux/Windows heroes-like release candidate.")
	parser.add_argument("--version", default="", help="Release version; defaults to project.godot.")
	parser.add_argument("--source-revision", default=os.environ.get("RELEASE_SOURCE_REVISION", ""))
	parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
	parser.add_argument("--build-root", type=Path, default=DEFAULT_BUILD_ROOT)
	parser.add_argument("--jobs", type=int, default=max(1, min(4, os.cpu_count() or 1)))
	parser.add_argument("--cmake", default=os.environ.get("CMAKE", "cmake"))
	parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
	parser.add_argument("--wine", default=os.environ.get("WINE", "wine"))
	parser.add_argument("--makensis", default=os.environ.get("MAKENSIS", "makensis"))
	parser.add_argument("--c-compiler", default=os.environ.get("MINGW_CC", "x86_64-w64-mingw32-gcc"))
	parser.add_argument("--cxx-compiler", default=os.environ.get("MINGW_CXX", "x86_64-w64-mingw32-g++"))
	parser.add_argument("--result-json", type=Path, default=None)
	parser.add_argument("--dry-run", action="store_true", help="Print the exact command plan without modifying files.")
	return parser.parse_args()


def project_version() -> str:
	text = (ROOT / "project.godot").read_text(encoding="utf-8")
	match = re.search(r'^config/version="([^"]+)"$', text, flags=re.MULTILINE)
	if match is None:
		raise RuntimeError("project.godot has no application version")
	return match.group(1)


def main() -> int:
	args = parse_args()
	if args.jobs < 1:
		raise ValueError("jobs must be positive")
	revision = safe_revision(args.source_revision) if args.source_revision else git_head_revision()
	configured_version = project_version()
	version = args.version.strip() or configured_version
	if not re.fullmatch(r"[0-9A-Za-z][0-9A-Za-z._+-]*", version):
		raise ValueError("release version is invalid")
	if version != configured_version:
		raise RuntimeError("requested release version must match project.godot config/version")
	windows_numeric_version(version)
	validate_windows_export_preset_version(version)
	output_dir = args.output_dir.resolve()
	build_root = args.build_root.resolve()

	requested_tools = {
		"python": sys.executable,
		"cmake": args.cmake,
		"godot": args.godot,
		"wine": args.wine,
		"makensis": args.makensis,
		"c_compiler": args.c_compiler,
		"cxx_compiler": args.cxx_compiler,
	}
	if args.dry_run:
		plan = command_plan(build_root, output_dir, revision, version, args.jobs, requested_tools)
		print(json.dumps({
			"schema_id": SCHEMA_ID,
			"dry_run": True,
			"source_revision": revision,
			"version": version,
			"steps": [{"id": step.id, "command": list(step.command)} for step in plan],
		}, sort_keys=True))
		return 0

	revision = resolve_source_revision(revision)
	tools = {
		name: executable(value, name.replace("_", " "))
		for name, value in requested_tools.items()
	}
	plan = command_plan(build_root, output_dir, revision, version, args.jobs, tools)
	reset_release_output(output_dir)
	build_started_ns = clean_owned_build_outputs(build_root)
	epoch = source_date_epoch(revision)
	env = os.environ.copy()
	env.update({
		"SOURCE_DATE_EPOCH": str(epoch),
		"RELEASE_SOURCE_REVISION": revision,
		"GODOT_SILENCE_ROOT_WARNING": "1",
		"WINEDEBUG": "-all",
		"WINEDLLOVERRIDES": "dinput8=",
		"WINEPREFIX": str(output_dir / "wine-prefix"),
	})

	step_results = []
	native_outputs = []
	package_payload = None
	verification_payload = None
	for step in plan:
		capture_json = step.id in {"package_release", "verify_release"}
		step_result, payload = run_step(step, env, capture_json)
		step_results.append(step_result)
		if step.id == "build_linux_release":
			native_outputs.extend(verify_native_output(output, build_started_ns) for output in NATIVE_OUTPUTS[:2])
		elif step.id == "build_windows_release":
			native_outputs.extend(verify_native_output(output, build_started_ns) for output in NATIVE_OUTPUTS[2:])
		elif step.id == "package_release":
			package_payload = payload
		elif step.id == "verify_release":
			verification_payload = payload

	if not isinstance(package_payload, dict) or not bool(package_payload.get("ok", False)):
		raise RuntimeError("release packaging did not report success")
	if not isinstance(verification_payload, dict) or not bool(verification_payload.get("ok", False)):
		raise RuntimeError("release verification did not report success")
	if str(verification_payload.get("source_revision", "")) != revision:
		raise RuntimeError("verified release revision does not match checked-out source")

	result_payload = {
		"schema_id": SCHEMA_ID,
		"ok": True,
		"source_revision": revision,
		"source_date_epoch": epoch,
		"version": version,
		"native_outputs": native_outputs,
		"steps": step_results,
		"release_verification": verification_payload,
	}
	result_path = (args.result_json or (output_dir / "release-candidate-result.json")).resolve()
	result_path.parent.mkdir(parents=True, exist_ok=True)
	result_path.write_text(json.dumps(result_payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
	print(json.dumps(result_payload, sort_keys=True))
	return 0


if __name__ == "__main__":
	try:
		raise SystemExit(main())
	except (OSError, RuntimeError, ValueError, subprocess.TimeoutExpired) as exc:
		print(f"build_release_candidate: {exc}", file=sys.stderr)
		raise SystemExit(1)
