#!/usr/bin/env python3
"""Builds the native libraries under src/gdextension into bin/, on Windows and on Linux.

    python tools/build_native.py windows                 # rules library, both flavours (MSVC)
    python tools/build_native.py windows --part map      # map persistence library
    python tools/build_native.py linux                   # rules library on the Linux build server
    python tools/build_native.py linux --part all        # rules and map persistence there

Parts: `rules` (src/gdextension/rules: aurelion_rules, rules_selftest, battle_sim_cli,
match_sim_cli) and `map` (src/gdextension: aurelion_map_persistence, the generator's CLI and
self-test).
Each flavour (template_debug, template_release) has its own build tree in .artifacts/.

`windows` runs CMake with Visual Studio 2022 on this machine at below-normal priority,
then runs bin/rules_selftest.exe.

`linux` copies the working tree's sources (tracked and new, not ignored) and the pinned
godot-cpp to a dated /tmp directory on the build server (HEROES_LINUX_BUILD_HOST,
default root@pleyc.com; never its stale /root/dev checkout), builds there with GCC at
nice 19, runs the self-tests (with --mingw, rules_selftest also as a MinGW build under Wine,
which must print the same sweep digest), splits the debug info off every ELF output and strips it,
copies bin/ back, checks every file's sha256 and deletes the remote directory.

Debug info never goes into git: PDBs and the Linux debug files are archived per build id
under the symbol store (HEROES_NATIVE_SYMBOLS, default heroes-like-native-symbols next to
the main checkout): windows/<pdb>/<GUID><age>/<pdb> as a Microsoft symbol store and
linux/.build-id/xx/<rest>.debug for gdb's debug-file-directory, with index.jsonl. Each
build prunes the store to the last five builds per binary.

Committed binaries conflict between branches: build and commit them one slice at a time.
Never build while an owner AI batch or a timing run is going (AGENTS.md).
"""
from __future__ import annotations

import argparse
import datetime
import hashlib
import io
import json
import os
import platform
import secrets
import shlex
import shutil
import struct
import subprocess
import sys
import tarfile
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BIN = ROOT / "bin"
DEFAULT_HOST = "root@pleyc.com"
RULES_DIR = "src/gdextension/rules"
SYMBOLS_KEPT = 5  # builds per binary kept in the symbol store

PARTS = {
	"rules": {
		"source": RULES_DIR,
		# The runner compiles the map library's generator core too (P8-8).
		"paths": [RULES_DIR, "src/gdextension/cmake", "src/gdextension/src/h3maped_rmg_core.cpp", "src/gdextension/src/h3maped_rmg_object_catalog.cpp",
			"src/gdextension/src/h3maped_rmg_template_catalog.cpp", "src/gdextension/include/h3maped_rmg_core.hpp",
			"src/gdextension/include/runtime_object_classification.hpp"],
		"trees": {
			"template_debug": ["aurelion_rules", "rules_selftest", "battle_sim_cli", "match_sim_cli"],
			"template_release": ["aurelion_rules"],
		},
		"outputs": {
			"windows": {
				"template_debug": ["aurelion_rules.windows.template_debug.x86_64.dll", "rules_selftest.exe", "battle_sim_cli.exe", "match_sim_cli.exe"],
				"template_release": ["aurelion_rules.windows.template_release.x86_64.dll"],
			},
			"linux": {
				"template_debug": ["libaurelion_rules.linux.template_debug.x86_64.so", "rules_selftest", "battle_sim_cli", "match_sim_cli"],
				"template_release": ["libaurelion_rules.linux.template_release.x86_64.so"],
			},
		},
	},
	"map": {
		"source": "src/gdextension",
		# MapPackageService compiles the rules core's package code (Phase 8, the fold).
		"paths": ["src/gdextension/CMakeLists.txt", "src/gdextension/src", "src/gdextension/include", "src/gdextension/cmake", RULES_DIR],
		"trees": {
			"template_debug": [],
			"template_release": [],
		},
		"outputs": {
			"windows": {
				"template_debug": ["aurelion_map_persistence.windows.template_debug.x86_64.dll", "h3maped_rmg_core_selftest.exe", "rmg_native_batch_export_cli.exe"],
				"template_release": ["aurelion_map_persistence.windows.template_release.x86_64.dll"],
			},
			"linux": {
				"template_debug": ["libaurelion_map_persistence.linux.template_debug.x86_64.so", "h3maped_rmg_core_selftest", "rmg_native_batch_export_cli"],
				"template_release": ["libaurelion_map_persistence.linux.template_release.x86_64.so"],
			},
		},
	},
}

# The map project names its trees by build type; the rules project builds both
# flavours as RelWithDebInfo (identical flags, debug info kept for the archive).
def build_type(part: str, flavour: str) -> str:
	if part == "map" and flavour == "template_release":
		return "Release"
	return "RelWithDebInfo"


def tree_name(part: str, flavour: str, system: str) -> str:
	base = "rules_native_build" if part == "rules" else "map_persistence_native_build"
	suffix = "" if flavour == "template_debug" else "_release"
	return f"{base}_{system}{suffix}"


def run(command: list[str], *, cwd: Path = ROOT, low_priority: bool = False, capture: bool = False, input_bytes: bytes | None = None) -> subprocess.CompletedProcess:
	print("> " + " ".join(shlex.quote(str(part)) for part in command), flush=True)
	flags = 0
	if low_priority and platform.system() == "Windows":
		flags = subprocess.BELOW_NORMAL_PRIORITY_CLASS
	result = subprocess.run(
		[str(part) for part in command],
		cwd=cwd,
		creationflags=flags,
		stdout=subprocess.PIPE if capture else None,
		stderr=subprocess.PIPE if capture else None,
		input=input_bytes,
		check=False,
	)
	if result.returncode != 0:
		detail = ""
		if capture:
			detail = (result.stderr or b"").decode("utf-8", "replace")[-4000:]
		raise SystemExit(f"build_native: command failed ({result.returncode}): {command[0]} {detail}")
	return result


def git(*args: str, cwd: Path = ROOT) -> str:
	return subprocess.run(["git", "-C", str(cwd), *args], check=True, capture_output=True, text=True).stdout.strip()


def main_checkout() -> Path:
	common = Path(git("rev-parse", "--path-format=absolute", "--git-common-dir"))
	return common.parent


def godot_cpp_root() -> Path:
	local = ROOT / "third_party" / "godot-cpp"
	if (local / "CMakeLists.txt").exists():
		return local
	pinned = git("ls-tree", "HEAD", "third_party/godot-cpp").split()[2]
	main = main_checkout() / "third_party" / "godot-cpp"
	if (main / "CMakeLists.txt").exists() and git("rev-parse", "HEAD", cwd=main) == pinned:
		return main
	raise SystemExit("build_native: godot-cpp is not checked out; run git submodule update --init --recursive")


def rules_source_tree() -> str:
	"""The git tree id of src/gdextension/rules as it is on disk (see rules/cmake/source_tree.cmake)."""
	with tempfile.TemporaryDirectory(prefix="heroes-rules-index-") as scratch:
		env = dict(os.environ, GIT_INDEX_FILE=str(Path(scratch) / "index"))
		subprocess.run(["git", "-C", str(ROOT), "add", "-A", "--", RULES_DIR], env=env, check=True, capture_output=True)
		return subprocess.run(["git", "-C", str(ROOT), "write-tree", f"--prefix={RULES_DIR}/"], env=env, check=True, capture_output=True, text=True).stdout.strip()


def symbol_store(explicit: str | None) -> Path:
	if explicit:
		return Path(explicit)
	if os.environ.get("HEROES_NATIVE_SYMBOLS"):
		return Path(os.environ["HEROES_NATIVE_SYMBOLS"])
	return main_checkout().parent / "heroes-like-native-symbols"


def sha256(path: Path) -> str:
	digest = hashlib.sha256()
	with path.open("rb") as handle:
		for chunk in iter(lambda: handle.read(1 << 20), b""):
			digest.update(chunk)
	return digest.hexdigest()


# --- build ids ------------------------------------------------------------------

def pe_codeview(path: Path) -> tuple[str, str] | None:
	"""(pdb file name, GUID+age key) of a PE image's CodeView record, or None."""
	data = path.read_bytes()
	if data[:2] != b"MZ":
		return None
	pe = struct.unpack_from("<I", data, 0x3C)[0]
	if data[pe:pe + 4] != b"PE\0\0":
		return None
	sections = struct.unpack_from("<H", data, pe + 6)[0]
	optional_size = struct.unpack_from("<H", data, pe + 20)[0]
	optional = pe + 24
	if struct.unpack_from("<H", data, optional)[0] != 0x20B:
		return None
	debug_rva, debug_size = struct.unpack_from("<II", data, optional + 112 + 6 * 8)
	section_table = optional + optional_size
	debug_offset = None
	for index in range(sections):
		entry = section_table + index * 40
		virtual_size, virtual_address, raw_size, raw_pointer = struct.unpack_from("<IIII", data, entry + 8)
		if virtual_address <= debug_rva < virtual_address + max(virtual_size, raw_size):
			debug_offset = raw_pointer + (debug_rva - virtual_address)
			break
	if debug_offset is None:
		return None
	for index in range(debug_size // 28):
		fields = struct.unpack_from("<IIHHIIII", data, debug_offset + index * 28)
		if fields[4] != 2:
			continue
		record = fields[7]
		if data[record:record + 4] != b"RSDS":
			continue
		d1, d2, d3 = struct.unpack_from("<IHH", data, record + 4)
		d4 = data[record + 12:record + 20]
		age = struct.unpack_from("<I", data, record + 20)[0]
		name_end = data.index(b"\0", record + 24)
		pdb_name = data[record + 24:name_end].decode("utf-8", "replace").replace("\\", "/").rsplit("/", 1)[-1]
		key = f"{d1:08X}{d2:04X}{d3:04X}{d4.hex().upper()}{age:X}"
		return pdb_name, key
	return None


def elf_build_id(path: Path) -> str | None:
	data = path.read_bytes()
	if data[:4] != b"\x7fELF" or data[4] != 2:
		return None
	phoff = struct.unpack_from("<Q", data, 32)[0]
	phentsize, phnum = struct.unpack_from("<HH", data, 54)
	for index in range(phnum):
		entry = phoff + index * phentsize
		p_type = struct.unpack_from("<I", data, entry)[0]
		if p_type != 4:  # PT_NOTE
			continue
		offset, _, _, size = struct.unpack_from("<QQQQ", data, entry + 8)
		cursor = offset
		while cursor + 12 <= offset + size:
			namesz, descsz, note_type = struct.unpack_from("<III", data, cursor)
			name = data[cursor + 12:cursor + 12 + namesz].rstrip(b"\0")
			desc_start = cursor + 12 + ((namesz + 3) & ~3)
			if note_type == 3 and name == b"GNU":
				return data[desc_start:desc_start + descsz].hex()
			cursor = desc_start + ((descsz + 3) & ~3)
	return None


def archive_symbol(store: Path, record: dict, debug_file: Path, relative: Path) -> None:
	target = store / relative
	target.parent.mkdir(parents=True, exist_ok=True)
	if not target.exists() or sha256(target) != sha256(debug_file):
		shutil.copy2(debug_file, target)
	record["debug_file"] = relative.as_posix()
	with (store / "index.jsonl").open("a", encoding="utf-8") as index:
		index.write(json.dumps(record, sort_keys=True) + "\n")
	print(f"symbols: {relative.as_posix()}")


def prune_symbols(store: Path, keep: int = SYMBOLS_KEPT) -> None:
	"""Keep the debug files of each binary's last `keep` builds; drop older ones and their index lines."""
	index = store / "index.jsonl"
	if not index.exists():
		return
	records = [json.loads(line) for line in index.read_text(encoding="utf-8").splitlines() if line.strip()]
	newest: dict[tuple[str, str], list[str]] = {}
	for record in sorted(records, key=lambda record: record["time"], reverse=True):
		files = newest.setdefault((record["platform"], record["binary"]), [])
		if record["debug_file"] not in files and len(files) < keep:
			files.append(record["debug_file"])
	kept = {name for files in newest.values() for name in files}
	freed = 0
	for name in {record["debug_file"] for record in records} - kept:
		target = store / name
		if target.exists():
			freed += target.stat().st_size
			target.unlink()
		parent = target.parent
		while parent != store and parent.exists() and not any(parent.iterdir()):
			parent.rmdir()
			parent = parent.parent
	index.write_text("".join(json.dumps(record, sort_keys=True) + "\n" for record in records if record["debug_file"] in kept), encoding="utf-8")
	if freed:
		print(f"symbols: pruned {freed // (1 << 20)} MB of builds older than the last {keep} per binary")


def archive_windows_symbols(store: Path, outputs: list[Path], source_tree: str) -> None:
	for binary in outputs:
		codeview = pe_codeview(binary)
		if codeview is None:
			continue
		pdb_name, key = codeview
		pdb = binary.with_name(pdb_name)
		if not pdb.exists():
			raise SystemExit(f"build_native: {binary.name} names {pdb_name}, which the build did not write")
		archive_symbol(store, {
			"time": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
			"platform": "windows",
			"binary": binary.name,
			"binary_sha256": sha256(binary),
			"build_id": key,
			"rules_source_tree": source_tree,
		}, pdb, Path("windows") / pdb_name / key / pdb_name)


# --- Windows ---------------------------------------------------------------------

def build_windows(parts: list[str], flavours: list[str], jobs: int, store: Path, run_selftest: bool) -> None:
	if platform.system() != "Windows":
		raise SystemExit("build_native: the windows command runs on Windows (MSVC)")
	cpp_root = godot_cpp_root()
	source_tree = rules_source_tree()
	built: list[Path] = []
	for part in parts:
		for flavour in flavours:
			tree = ROOT / ".artifacts" / tree_name(part, flavour, "windows_msvc")
			configure = ["cmake", "-S", ROOT / PARTS[part]["source"], "-B", tree, "-G", "Visual Studio 17 2022", "-A", "x64",
				f"-DAURELION_GODOTCPP_TARGET={flavour}", f"-DGODOT_CPP_ROOT={cpp_root.as_posix()}"]
			run(configure, low_priority=True)
			command = ["cmake", "--build", tree, "--config", build_type(part, flavour), "--parallel", str(jobs)]
			targets = PARTS[part]["trees"][flavour]
			if targets:
				command += ["--target", *targets]
			run(command, low_priority=True)
			for name in PARTS[part]["outputs"]["windows"][flavour]:
				output = BIN / name
				if not output.exists():
					raise SystemExit(f"build_native: the build did not write bin/{name}")
				built.append(output)
	if run_selftest and "rules" in parts and "template_debug" in flavours:
		run([BIN / "rules_selftest.exe"])
	archive_windows_symbols(store, built, source_tree)
	report(built)


# --- Linux, on the build server --------------------------------------------------

REMOTE_SCRIPT = r"""#!/bin/bash
# Written by tools/build_native.py; runs in its own directory on the build server.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
echo $$ > "$DIR/.pid"
trap 'echo $? > "$DIR/.exit"' EXIT
cd "$DIR"
JOBS="$(nproc)"
PREFIX_MAP="-ffile-prefix-map=$DIR/="
mkdir -p bin debug build
{commands}
# Split the debug info off every ELF output, archive it under debug/, strip.
for f in bin/*; do
	[ -f "$f" ] || continue
	head -c 4 "$f" | grep -q ELF || continue
	if readelf -S "$f" | grep -q '\.debug_info'; then
		name="$(basename "$f")"
		objcopy --only-keep-debug --compress-debug-sections "$f" "debug/$name.debug"
		strip --strip-unneeded --remove-section=.comment "$f"
		objcopy --add-gnu-debuglink="debug/$name.debug" "$f"
	fi
done
(cd "$DIR" && sha256sum bin/* debug/* > SHA256SUMS 2>/dev/null || sha256sum bin/* > SHA256SUMS)
"""


def remote_commands(parts: list[str], flavours: list[str], source_tree: str, cpp_commit: str, mingw_selftest: bool) -> str:
	lines = []
	common = f'-DGODOT_CPP_ROOT="$DIR/third_party/godot-cpp"'
	for part in parts:
		for flavour in flavours:
			tree = f"build/{part}-{flavour}"
			extra = ""
			if part == "rules":
				extra = f"-DAURELION_RULES_SOURCE_TREE={source_tree} -DAURELION_GODOT_CPP_COMMIT={cpp_commit}"
			else:
				extra = '-DCMAKE_CXX_FLAGS="$PREFIX_MAP"'
			lines.append(f'nice -n 19 cmake -S "$DIR/{PARTS[part]["source"]}" -B "$DIR/{tree}" -DCMAKE_BUILD_TYPE={build_type(part, flavour)} '
				f'-DAURELION_GODOTCPP_TARGET={flavour} {common} {extra} > "$DIR/{tree}.configure.log" 2>&1 || {{ tail -30 "$DIR/{tree}.configure.log"; exit 1; }}')
			targets = PARTS[part]["trees"][flavour]
			target_args = (" --target " + " ".join(targets)) if targets else ""
			lines.append(f'nice -n 19 cmake --build "$DIR/{tree}" --parallel "$JOBS"{target_args} > "$DIR/{tree}.log" 2>&1 || {{ tail -50 "$DIR/{tree}.log"; exit 1; }}')
	if "rules" in parts and "template_debug" in flavours:
		# Every self-test checks the pinned sweep digest itself, so two passes are
		# the same answers.
		lines.append('echo "== rules_selftest (gcc)"; ./bin/rules_selftest | tee selftest-gcc.txt; grep -q "RULES_SELFTEST ok" selftest-gcc.txt')
		if mingw_selftest:
			# The same self-test built with MinGW, under Wine.
			lines.append(f'nice -n 19 cmake -S "$DIR/{RULES_DIR}" -B "$DIR/build/rules-mingw" -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_SYSTEM_PROCESSOR=x86_64 '
				f'-DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc -DCMAKE_CXX_COMPILER=x86_64-w64-mingw32-g++ -DCMAKE_BUILD_TYPE=RelWithDebInfo '
				f'-DAURELION_PROJECT_ROOT="$DIR/mingw-root" {common} -DAURELION_RULES_SOURCE_TREE={source_tree} -DAURELION_GODOT_CPP_COMMIT={cpp_commit} '
				'> "$DIR/build/rules-mingw.configure.log" 2>&1 || { tail -30 "$DIR/build/rules-mingw.configure.log"; exit 1; }')
			lines.append('nice -n 19 cmake --build "$DIR/build/rules-mingw" --parallel "$JOBS" --target rules_selftest > "$DIR/build/rules-mingw.log" 2>&1 || { tail -50 "$DIR/build/rules-mingw.log"; exit 1; }')
			lines.append('echo "== rules_selftest (mingw, wine)"; WINEPREFIX="$DIR/wine" WINEDEBUG=-all wine "$DIR/mingw-root/bin/rules_selftest.exe" | tr -d "\\r" | tee selftest-mingw.txt; grep -q "RULES_SELFTEST ok" selftest-mingw.txt')
	if "map" in parts and "template_debug" in flavours:
		lines.append('echo "== h3maped_rmg_core_selftest"; ./bin/h3maped_rmg_core_selftest > selftest-map.txt 2>&1 || { tail -20 selftest-map.txt; exit 1; }; tail -3 selftest-map.txt')
	return "\n".join(lines)


def source_archive(paths: list[str]) -> bytes:
	listed = git("ls-files", "-co", "--exclude-standard", "--", *paths).splitlines()
	buffer = io.BytesIO()
	with tarfile.open(fileobj=buffer, mode="w") as archive:
		for relative in sorted(set(listed)):
			path = ROOT / relative
			if path.is_file():
				archive.add(path, arcname=relative)
	return buffer.getvalue()


def ssh(host: str, command: str, *, input_bytes: bytes | None = None, capture: bool = True) -> subprocess.CompletedProcess:
	return run(["ssh", "-o", "BatchMode=yes", host, command], capture=capture, input_bytes=input_bytes)


# One poll of a detached remote build: "exit <code>", "running", "dead" (no exit code
# and the process is gone: killed, OOM) or "gone" (the directory was removed).
REMOTE_STATE = (
	'if [ ! -d {remote} ]; then echo gone; '
	'elif [ -f {remote}/.exit ]; then echo "exit $(cat {remote}/.exit)"; '
	'elif kill -0 "$(cat {remote}/.pid 2>/dev/null)" 2>/dev/null; then echo running; '
	'elif [ -f {remote}/.exit ]; then echo "exit $(cat {remote}/.exit)"; '
	'else echo dead; fi'
)


# Polls must end on their own: a dropped connection is noticed within 30 s, and one
# call never takes more than a minute.
POLL_SSH = ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=20", "-o", "ServerAliveInterval=15", "-o", "ServerAliveCountMax=2"]


def poll_ssh(host: str, command: str) -> subprocess.CompletedProcess | None:
	"""One short ssh call; None when it did not finish within a minute."""
	try:
		return subprocess.run([*POLL_SSH, host, command], capture_output=True, check=False, timeout=60)
	except subprocess.TimeoutExpired:
		return None


def wait_for_remote_build(host: str, remote: str, deadline: float) -> int:
	"""Polls until the remote build writes its exit code. Stops at the deadline, when the
	build dies without one, or when the host stays unreachable for 2 minutes."""
	last_answer = time.time()
	while True:
		time.sleep(15)
		result = poll_ssh(host, REMOTE_STATE.format(remote=remote))
		state = result.stdout.decode("utf-8", "replace").strip() if result is not None else ""
		if result is None or result.returncode != 0 or not state:
			if time.time() - last_answer >= 120:
				raise SystemExit(f"build_native: {host} did not answer for 2 minutes; the build may still be running in {host}:{remote}")
			continue
		last_answer = time.time()
		if state.startswith("exit "):
			return int(state.split()[1])
		if state == "gone":
			raise SystemExit(f"build_native: {host}:{remote} was removed during the build")
		if state == "dead":
			raise SystemExit(f"build_native: the remote build stopped without an exit code (killed or out of memory); left {host}:{remote} for inspection")
		if time.time() > deadline:
			# build.sh leads its own session (setsid), so its pid is the process group.
			kill = poll_ssh(host, f'kill -TERM -- -"$(cat {remote}/.pid)"')
			if kill is not None and kill.returncode == 0:
				raise SystemExit(f"build_native: the remote build passed its deadline and was stopped; left {host}:{remote} for inspection")
			detail = "no answer" if kill is None else (kill.stderr or b"").decode("utf-8", "replace").strip() or f"exit {kill.returncode}"
			raise SystemExit(f"build_native: the remote build passed its deadline, but stopping it failed ({detail}); it may still be running in {host}:{remote}")


def build_linux(parts: list[str], flavours: list[str], host: str, store: Path, keep_remote: bool, mingw_selftest: bool, timeout_minutes: int) -> None:
	cpp_root = godot_cpp_root()
	cpp_commit = git("rev-parse", "HEAD", cwd=cpp_root)
	source_tree = rules_source_tree()
	stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
	remote = f"/tmp/heroes-native-build-{stamp}-{secrets.token_hex(3)}"
	paths = sorted({path for part in parts for path in PARTS[part]["paths"]})
	sources = source_archive(paths)
	godot_cpp = subprocess.run(["git", "-C", str(cpp_root), "archive", "--format=tar", "HEAD"], check=True, capture_output=True).stdout
	script = REMOTE_SCRIPT.replace("{commands}", remote_commands(parts, flavours, source_tree, cpp_commit, mingw_selftest))
	print(f"build_native: remote directory {host}:{remote}", flush=True)
	try:
		built = run_remote_build(host, remote, sources, godot_cpp, script, parts, flavours, store, source_tree, keep_remote, timeout_minutes)
	except SystemExit as error:
		# Every failure from here on names the remote directory.
		message = str(error.code).rstrip()
		if remote not in message:
			message += f"; left {host}:{remote} for inspection"
		raise SystemExit(message) from None
	except BaseException:
		print(f"build_native: left {host}:{remote} for inspection", file=sys.stderr, flush=True)
		raise
	report(built)


def run_remote_build(host: str, remote: str, sources: bytes, godot_cpp: bytes, script: str, parts: list[str], flavours: list[str], store: Path, source_tree: str, keep_remote: bool, timeout_minutes: int) -> list[Path]:
	"""Uploads, builds, fetches and checks; returns the binaries copied into bin/."""
	ssh(host, f"mkdir -p {remote}/third_party/godot-cpp && tar -x -C {remote}", input_bytes=sources)
	ssh(host, f"tar -x -C {remote}/third_party/godot-cpp", input_bytes=godot_cpp)
	ssh(host, f"cat > {remote}/build.sh && chmod +x {remote}/build.sh", input_bytes=script.replace("\r\n", "\n").encode("utf-8"))
	started = time.time()
	# Detached in its own session, so a long build never holds the ssh channel and the
	# deadline can stop all of it; build.sh writes its pid before it starts work.
	ssh(host, f"(setsid nohup {remote}/build.sh > {remote}/build.log 2>&1 < /dev/null &); "
		f"for i in $(seq 50); do [ -s {remote}/.pid ] && exit 0; sleep 0.2; done; echo 'build.sh did not start' >&2; exit 1")
	exit_code = wait_for_remote_build(host, remote, started + timeout_minutes * 60)
	log = ssh(host, f"cat {remote}/build.log").stdout.decode("utf-8", "replace")
	print(log[-6000:])
	print(f"build_native: remote build took {time.time() - started:.0f} s")
	if exit_code != 0:
		raise SystemExit(f"build_native: remote build failed ({exit_code}); left {host}:{remote} for inspection")
	fetched = ssh(host, f"tar -c -C {remote} bin debug SHA256SUMS").stdout
	wanted = {name for part in parts for flavour in flavours for name in PARTS[part]["outputs"]["linux"][flavour]}
	built: list[Path] = []
	with tempfile.TemporaryDirectory(prefix="heroes-native-fetch-") as scratch_name:
		scratch = Path(scratch_name)
		with tarfile.open(fileobj=io.BytesIO(fetched)) as archive:
			archive.extractall(scratch, filter="data")
		sums = {}
		for line in (scratch / "SHA256SUMS").read_text().splitlines():
			digest, name = line.split(maxsplit=1)
			sums[name.lstrip("*")] = digest
		for relative, digest in sums.items():
			if sha256(scratch / relative) != digest:
				raise SystemExit(f"build_native: sha256 mismatch for {relative} after the copy")
		for name in sorted(wanted):
			source = scratch / "bin" / name
			if not source.exists():
				raise SystemExit(f"build_native: the remote build did not write bin/{name}")
			shutil.copy2(source, BIN / name)
			if sha256(BIN / name) != sums[f"bin/{name}"]:
				raise SystemExit(f"build_native: sha256 mismatch for bin/{name}")
			built.append(BIN / name)
			debug = scratch / "debug" / f"{name}.debug"
			if debug.exists():
				build_id = elf_build_id(BIN / name)
				if build_id is None or elf_build_id(debug) != build_id:
					raise SystemExit(f"build_native: {name} and its debug file disagree on the build id")
				archive_symbol(store, {
					"time": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
					"platform": "linux",
					"binary": name,
					"binary_sha256": sums[f"bin/{name}"],
					"build_id": build_id,
					"rules_source_tree": source_tree,
				}, debug, Path("linux") / ".build-id" / build_id[:2] / f"{build_id[2:]}.debug")
	if keep_remote:
		print(f"build_native: kept {host}:{remote}")
	else:
		ssh(host, f"rm -rf -- {remote}")
	return built


def report(built: list[Path]) -> None:
	for path in built:
		print(f"built: bin/{path.name}  {path.stat().st_size} bytes  sha256 {sha256(path)}")


def main() -> int:
	parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	parser.add_argument("system", choices=["windows", "linux"])
	parser.add_argument("--part", choices=["rules", "map", "all"], default="rules")
	parser.add_argument("--flavour", choices=["debug", "release", "both"], default="both")
	parser.add_argument("--jobs", type=int, default=max(1, min(8, (os.cpu_count() or 2) // 2)))
	parser.add_argument("--host", default=os.environ.get("HEROES_LINUX_BUILD_HOST", DEFAULT_HOST))
	parser.add_argument("--symbols-dir", default=None, help="symbol store (default: HEROES_NATIVE_SYMBOLS or heroes-like-native-symbols next to the main checkout)")
	parser.add_argument("--keep-remote", action="store_true", help="leave the remote build directory")
	parser.add_argument("--mingw", action="store_true", help="also build rules_selftest with MinGW on Linux and run it under Wine")
	parser.add_argument("--remote-timeout", type=int, default=120, metavar="MINUTES", help="stop the remote Linux build after this long (default 120)")
	parser.add_argument("--no-selftest", action="store_true", help="skip bin/rules_selftest.exe on Windows")
	args = parser.parse_args()
	parts = ["rules", "map"] if args.part == "all" else [args.part]
	flavours = {"debug": ["template_debug"], "release": ["template_release"], "both": ["template_debug", "template_release"]}[args.flavour]
	store = symbol_store(args.symbols_dir)
	if args.system == "windows":
		build_windows(parts, flavours, args.jobs, store, not args.no_selftest)
	else:
		build_linux(parts, flavours, args.host, store, args.keep_remote, args.mingw, args.remote_timeout)
	prune_symbols(store)
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
