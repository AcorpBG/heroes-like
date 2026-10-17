#!/usr/bin/env python3
"""Core regression suite: the few durable checks every change must keep green.

Run before pushing to main:

    python tools/core_suite.py            # content check, then all core tests in parallel
    python tools/core_suite.py --only battle_deterministic_rng_state_report
    python tools/core_suite.py --list

Windows and Linux. Godot comes from --godot, $GODOT_BIN, `godot4`/`godot` on PATH,
or the owner's Windows install. Every test gets a throwaway user profile (APPDATA on
Windows, XDG_DATA_HOME on Linux), so the real saves and settings are never touched.

The content check (tests/validate_repo.py, a few seconds) runs first and needs no Godot.
A failing test listed in tests/known_failures.txt is reported as KNOWN and does not fail
the run. See AGENTS.md "Validation budget" for what belongs here and what does not.
"""
from __future__ import annotations

import argparse
import concurrent.futures
import os
import platform
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
KNOWN_FAILURES_PATH = ROOT / "tests" / "known_failures.txt"
MAPS_DIR = ROOT / "maps"
WINDOWS_DEFAULT_GODOT = Path("D:/Games/godot/Godot_v4.6.2-stable_win64_console.exe")

# (scene under res://tests/, timeout seconds, what it protects)
CORE_TESTS: list[tuple[str, int, str]] = [
    ("core_script_compile_check", 300, "every game script compiles"),
    ("map_package_api_skeleton_report", 180, "native extension loads; map package saves and loads"),
    ("random_map_seeded_generator_core_report", 180, "same seed gives the same generated map"),
    ("random_map_small_2p_launch_report", 300, "a small generated game launches"),
    ("random_map_final_writeout_export_save_schema_report", 300, "generated map package save schema"),
    ("generated_start_hero_growth_seed_report", 300, "session state is deterministic per seed"),
    ("battle_deterministic_rng_state_report", 180, "battles are deterministic"),
    ("battle_ai_flow_report", 300, "the battle AI acts and battles end"),
    ("player_elimination_rules_report", 180, "players are eliminated and games end"),
    ("ai_town_knowledge_report", 180, "computer players find and reach rival towns and plan their towns"),
    ("pickups_income_rules_report", 180, "pickups and daily income"),
    ("town_build_per_town_turn_limit_report", 180, "town building rules"),
    ("save_summary_deferred_payload_report", 180, "save summaries and payloads"),
    ("settings_transactional_persistence_regression", 180, "settings save safely"),
    ("magic_spell_schema_report", 180, "spell content schema"),
]
# Keep this list short and durable. Rejected on 2026-10-10 because they pin values that change
# with content or still assume authored scenarios: artifact_taxonomy_schema_report (exact
# artifact count), unit_runtime_asset_resolution_report (exact sheet sizes),
# hero_specialty_catalog_report (exact specialty count), random_map_scenario_load_smoke and
# main_menu_lean_boot_save_guard (authored domain / pre-existing saves).

CONTENT_CHECK = "validate_repo"

FAILURE_TEXT = re.compile(r"^(SCRIPT ERROR|Parse Error|ERROR: Failed to load script)", re.M)


def find_godot(explicit: str | None) -> str:
    for candidate in (explicit, os.environ.get("GODOT_BIN"), shutil.which("godot4"), shutil.which("godot")):
        if candidate:
            return candidate
    if platform.system() == "Windows" and WINDOWS_DEFAULT_GODOT.exists():
        return str(WINDOWS_DEFAULT_GODOT)
    sys.exit("Godot not found: pass --godot or set GODOT_BIN")


def load_known_failures() -> dict[str, str]:
    known: dict[str, str] = {}
    if KNOWN_FAILURES_PATH.exists():
        for line in KNOWN_FAILURES_PATH.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            name, _, reason = line.partition("#")
            known[name.strip()] = reason.strip()
    return known


def run_content_check() -> tuple[str, bool, float, str]:
    started = time.monotonic()
    cmd = [sys.executable, str(ROOT / "tests" / "validate_repo.py")]
    proc = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=300)
    return CONTENT_CHECK, proc.returncode == 0, time.monotonic() - started, proc.stdout + proc.stderr


def run_test(godot: str, name: str, timeout: int) -> tuple[str, bool, float, str]:
    started = time.monotonic()
    with tempfile.TemporaryDirectory(prefix="heroes-core-") as profile:
        env = dict(os.environ)
        env["APPDATA"] = profile  # Windows user data
        env["XDG_DATA_HOME"] = profile  # Linux user data
        env["XDG_CONFIG_HOME"] = profile
        cmd = [godot, "--headless", "--path", str(ROOT), "--audio-driver", "Dummy", f"res://tests/{name}.tscn"]
        try:
            proc = subprocess.run(cmd, env=env, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=timeout)
            output = proc.stdout + proc.stderr
            ok = proc.returncode == 0 and not FAILURE_TEXT.search(output)
            if proc.returncode != 0:
                output += f"\n[exit code {proc.returncode}]"
        except subprocess.TimeoutExpired as exc:
            output = (exc.stdout or "") if isinstance(exc.stdout, str) else ""
            output += f"\n[timed out after {timeout}s]"
            ok = False
    return name, ok, time.monotonic() - started, output


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--godot", help="Godot binary")
    parser.add_argument("--only", nargs="+", metavar="TEST", help="run only these core tests")
    parser.add_argument("--jobs", type=int, default=max(1, min(4, (os.cpu_count() or 2) // 2)), help="tests run in parallel")
    parser.add_argument("--list", action="store_true", help="list the core tests and exit")
    args = parser.parse_args()

    if args.list:
        print(f"{CONTENT_CHECK:55s} content parses, ids and references resolve, runtime files exist")
        for name, timeout, why in CORE_TESTS:
            print(f"{name:55s} {why}")
        return 0
    tests = CORE_TESTS
    content_check = True
    if args.only:
        unknown = set(args.only) - {t[0] for t in CORE_TESTS} - {CONTENT_CHECK}
        if unknown:
            sys.exit(f"Not core tests: {', '.join(sorted(unknown))}")
        tests = [t for t in CORE_TESTS if t[0] in args.only]
        content_check = CONTENT_CHECK in args.only

    known = load_known_failures()
    started = time.monotonic()
    failed: list[str] = []
    if content_check:
        failed += report(*run_content_check(), known)
    note = ""
    if tests:
        godot = find_godot(args.godot)
        maps_before = set(MAPS_DIR.iterdir()) if MAPS_DIR.is_dir() else set()
        run_started_at = time.time()
        try:
            failed += run_all(godot, tests, known, args.jobs)
        finally:
            removed = remove_new_maps(maps_before, run_started_at)
        note = f"; removed {removed} generated map files the tests wrote" if removed else ""
    total = len(tests) + (1 if content_check else 0)
    print(f"\n{total - len(failed)}/{total} core tests passed in {time.monotonic() - started:.0f}s{note}")
    return 1 if failed else 0


def remove_new_maps(before: set[Path], since: float) -> int:
    """Generated-map tests write packages to res://maps, which also holds the owner's maps.
    Delete only files that did not exist before this run and were written during it."""
    if not MAPS_DIR.is_dir():
        return 0
    removed = 0
    for path in MAPS_DIR.iterdir():
        if path in before or not path.is_file() or path.suffix not in (".amap", ".ascenario"):
            continue
        if path.stat().st_mtime >= since - 1:
            path.unlink()
            removed += 1
    return removed


def run_all(godot: str, tests: list[tuple[str, int, str]], known: dict[str, str], jobs: int) -> list[str]:
    failed: list[str] = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=jobs) as pool:
        futures = [pool.submit(run_test, godot, name, timeout) for name, timeout, _ in tests]
        for future in concurrent.futures.as_completed(futures):
            failed += report(*future.result(), known)
    return failed


def report(name: str, ok: bool, seconds: float, output: str, known: dict[str, str]) -> list[str]:
    if ok:
        status = "PASS (listed as known failure: remove it)" if name in known else "PASS"
    elif name in known:
        status = f"KNOWN ({known[name]})"
    else:
        status = "FAIL"
    print(f"{status:6s} {seconds:6.1f}s  {name}", flush=True)
    if status != "FAIL":
        return []
    tail = "\n".join(output.strip().splitlines()[-30:])
    print("    " + tail.replace("\n", "\n    "), flush=True)
    return [name]


if __name__ == "__main__":
    sys.exit(main())
