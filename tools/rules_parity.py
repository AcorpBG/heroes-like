#!/usr/bin/env python3
"""Rules parity check: the six committed seed setups played by two copies of the game, compared day by day.

    python tools/rules_parity.py check A B                 # play both, compare, explain the first difference
    python tools/rules_parity.py check A B --seeds l1,s2 --env-b HEROES_NATIVE_BATTLE=native
    python tools/rules_parity.py run A --out DIR           # play one side only (for example on Linux)
    python tools/rules_parity.py compare DIR_A DIR_B       # compare two `run` outputs
    python tools/rules_parity.py prepare REV DEST          # a copy of another revision, outside the repo
    python tools/rules_parity.py remove DEST               # delete a prepared copy (junctions first)
    python tools/rules_parity.py seeds

A side is a project directory (run with the editor binary, --godot / --godot-a / --godot-b) or an
exported game binary of an AI batch preset (export_presets.cfg; it starts the match runner and
loads the .pck beside it). An exported build writes its map package to user://maps, the editor to
res://maps: compare the two with --portable, which blanks the fields that hold that location. Every match writes a
digest line per day (HEROES_AI_MATCH_DIGEST in tests/ai_versus_ai_match_report.gd: sha256 of the
whole session state as JSON with insertion order, int and float apart and full precision) and its
match record. `check` compares the digests and the records (timing fields left out); for a seed
that differs it plays both sides again to the first differing day with a full state dump and
reports the first differing JSON paths.

Each Godot run gets its own throwaway user profile (APPDATA, XDG_DATA_HOME/CONFIG/CACHE) and its
package under <project>/maps is deleted after it (matched by scenario id and time, never a file
that was there before). The same seed never runs twice at once from one directory, because both
would write the same map package. Runs default to 6 at once; never run this while an owner AI
batch is running (AGENTS.md "Validation budget").

`prepare` extracts `git archive REV` without art/ into DEST, links DEST/art to this checkout's art
and DEST/.godot/imported to its import cache, copies the small .godot files and registers the
revision's own native libraries (src/gdextension/*.gdextension). A revision that adds or renames a
class_name needs a headless --import in DEST first.

A run fails when the match fails, times out or prints a SCRIPT ERROR line (the runner itself fails
when the native rules library is not loaded). `check` and `compare` report a seed with a failed run
on either side as FAILED, never identical; `compare` reads each folder's runs.json and its logs
again. Only debug builds print SCRIPT ERROR lines: on an editor side a script error fails the run,
on a release export (template_release) it goes unseen and only the runner's own failures count.
Exit codes: 0 identical, 1 different, 2 a run failed.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import os
import platform
import shutil
import subprocess
import sys
import tarfile
import tempfile
import time
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from ai_match_batch import SIZES, kill, remove_match_maps  # noqa: E402
from core_suite import find_godot  # noqa: E402

SCENE = "res://tests/ai_versus_ai_match_report.tscn"
REPORT_ID = "AI_VERSUS_AI_MATCH_REPORT"
IS_WINDOWS = platform.system() == "Windows"
COPY_MARKER = ".rules_parity_copy"
GODOT_SMALL_FILES = (".gdignore", "global_script_class_cache.cfg", "uid_cache.bin",
                     "lossless-imports.json", "scene_groups_cache.cfg")

# The committed seed set (2026-10-20). Guards normal everywhere; factions come from the seed.
SEEDS: dict[str, dict] = {
    "l1": {"seed": "oracle-l1", "players": 4, "size": "homm3_large", "days": 90, "water": "land", "levels": 1},
    "l2": {"seed": "oracle-l2", "players": 4, "size": "homm3_large", "days": 70, "water": "land", "levels": 2},
    "mw": {"seed": "oracle-mw", "players": 3, "size": "homm3_medium", "days": 100, "water": "normal_water", "levels": 1},
    "s2": {"seed": "oracle-s2", "players": 2, "size": "homm3_small", "days": 150, "water": "land", "levels": 1},
    "mg-a": {"seed": "mg-a", "players": 4, "size": "homm3_large", "days": 80, "water": "normal_water", "levels": 2},
    "mg-b": {"seed": "mg-b", "players": 3, "size": "homm3_medium", "days": 100, "water": "land", "levels": 2},
}
# Seeds a port adds for paths the committed set never runs; they run only when --seeds names them.
# Phase 4 (2026-10-22): isl-b has an army saving for a boat (AiHeroRules._hold_back), pt-f one-way portals whose
# random exits the computer heroes take (OverworldRules.native_random_exit_check).
EXTRA_SEEDS: dict[str, dict] = {
    "isl-b": {"seed": "isl-b", "players": 2, "size": "homm3_small", "days": 100, "water": "islands", "levels": 1},
    "pt-f": {"seed": "pt-f", "players": 4, "size": "homm3_large", "days": 80, "water": "land", "levels": 2},
}
ALL_SEEDS = {**SEEDS, **EXTRA_SEEDS}
# Record fields that hold wall-clock time, left out of the comparison.
TIMING_KEYS = ("ai_turn_ms_max", "turn_ms")
# --portable: where the map package was written (res://maps under the editor, user://maps in an
# exported build) shows up in these session keys, as the paths and the package signatures that include
# them. The runner sets those fields to "" in the digest (HEROES_AI_MATCH_DIGEST_BLANK, nested
# dictionaries only); the rest of each key, such as the runtime scenario record's objectives, player
# slots and starting resources, is compared like everything else.
PACKAGE_LOCATION_KEYS = ("map_package_ref", "scenario_package_ref", "native_random_map_runtime_scenario_record",
                         "generated_random_map_provenance", "generated_random_map_replay_metadata")
PACKAGE_LOCATION_FIELDS = ("active_dir", "active_dir_kind", "map_package_path", "scenario_package_path", "package_path",
                           "package_hash", "full_output_signature", "materialized_map_signature", "stable_signature")
PORTABLE_BLANK = ",".join([f"overworld.{k}" for k in PACKAGE_LOCATION_KEYS + ("native_random_map_package_session_adoption",)]
                          + [f"flags.{k}" for k in PACKAGE_LOCATION_KEYS] + list(PACKAGE_LOCATION_FIELDS))


# ---------------------------------------------------------------- sides and runs

@dataclass
class Side:
    name: str
    path: Path
    godot: str
    env: dict[str, str] = field(default_factory=dict)

    @property
    def is_project(self) -> bool:
        return self.path.is_dir()

    def command(self) -> list[str]:
        if self.is_project:
            return [self.godot, "--headless", "--path", str(self.path), "--audio-driver", "Dummy", SCENE]
        # Release templates take no scene argument; the AI batch presets start the match runner.
        return [str(self.path), "--headless", "--audio-driver", "Dummy"]


@dataclass
class Job:
    side: Side
    key: str
    out: Path
    dump_day: int | None = None

    @property
    def stem(self) -> str:
        return self.key if self.dump_day is None else f"{self.key}.dump{self.dump_day}"

    def lock(self) -> tuple[str, str]:
        return (str(self.side.path.resolve()), self.key)


def parse_env(items: list[str] | None) -> dict[str, str]:
    env = {}
    for item in items or []:
        name, sep, value = item.partition("=")
        if not sep or not name:
            sys.exit(f"--env wants NAME=VALUE, got {item}")
        env[name] = value
    return env


def start(job: Job, profiles: Path) -> tuple[subprocess.Popen, Path, float]:
    setup = ALL_SEEDS[job.key]
    profile = Path(tempfile.mkdtemp(prefix=f"{job.side.name}-{job.key}-", dir=profiles))
    env = {k: v for k, v in os.environ.items() if not k.startswith("HEROES_AI_MATCH_")}
    env.update(job.side.env)
    env.update({
        "APPDATA": str(profile), "XDG_DATA_HOME": str(profile), "XDG_CONFIG_HOME": str(profile), "XDG_CACHE_HOME": str(profile),
        "HEROES_AI_MATCH_SEED": setup["seed"],
        "HEROES_AI_MATCH_PLAYERS": str(setup["players"]),
        "HEROES_AI_MATCH_SIZE": setup["size"],
        "HEROES_AI_MATCH_GUARDS": setup.get("guards", "normal"),
        "HEROES_AI_MATCH_WATER": setup["water"],
        "HEROES_AI_MATCH_LEVELS": str(setup["levels"]),
        "HEROES_AI_MATCH_MAX_DAYS": str(setup["days"]),
        "HEROES_AI_MATCH_OUT": (job.out / f"{job.stem}.json").as_posix(),
        "HEROES_AI_MATCH_DIGEST": (job.out / f"{job.stem}.digest").as_posix(),
    })
    if job.dump_day is not None:
        env["HEROES_AI_MATCH_DUMP"] = (job.out / f"{job.stem}.state.json").as_posix()
        env["HEROES_AI_MATCH_DUMP_DAY"] = str(job.dump_day)
    for suffix in (".json", ".digest", ".state.json"):
        (job.out / f"{job.stem}{suffix}").unlink(missing_ok=True)
    log = open(job.out / f"{job.stem}.log", "w", encoding="utf-8", errors="replace")
    extra = {} if IS_WINDOWS else {"start_new_session": True}
    proc = subprocess.Popen(job.side.command(), env=env, stdout=log, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL, **extra)
    log.close()
    return proc, profile, time.time()


def log_verdict(text: str, returncode: int | None = None, timed_out: bool = False) -> tuple[str, list[str], dict]:
    """A run's problem ("" when it is clean), its SCRIPT ERROR lines and its report, from its log."""
    report = {}
    for line in text.splitlines():
        if line.startswith(REPORT_ID + " "):
            try:
                report = json.loads(line[len(REPORT_ID) + 1:])
            except ValueError:
                pass
    # A script error means the game ran a different path than intended (a missing class, a failed call),
    # even when the match finished: such a run fails, so two sides with the same error never compare equal.
    # Only debug builds (the editor binary) print them; a release export's log has none.
    script_errors = [line.strip() for line in text.splitlines() if "SCRIPT ERROR" in line]
    problem = ""
    if timed_out:
        problem = "timed out"
    elif not report.get("ok"):
        problem = str(report.get("error") or ("no report line" if returncode is None else f"exit {returncode}, no report line"))
    elif script_errors:
        problem = f"{len(script_errors)} SCRIPT ERROR lines, first: {script_errors[0]}"
    return problem, script_errors, report


def finish(job: Job, proc: subprocess.Popen, profile: Path, started: float, timed_out: bool, keep_maps: dict[str, set[str]]) -> dict:
    shutil.rmtree(profile, ignore_errors=True)
    text = (job.out / f"{job.stem}.log").read_text(encoding="utf-8", errors="replace")
    problem, script_errors, report = log_verdict(text, proc.returncode, timed_out)
    record_path = job.out / f"{job.stem}.json"
    removed: list[str] = []
    if job.side.is_project and record_path.exists():
        try:
            scenario_id = str(json.loads(record_path.read_text(encoding="utf-8"))["setup"].get("scenario_id", ""))
            removed = remove_match_maps(scenario_id, started, keep_maps.get(str(job.side.path.resolve()), set()), job.side.path / "maps")
        except (ValueError, KeyError):
            pass
    return {
        "side": job.side.name, "seed": job.key, "dump_day": job.dump_day, "ok": not problem, "problem": problem,
        "seconds": round(time.time() - started, 1), "final_day": report.get("final_day"),
        "script_errors": script_errors,
        "maps_removed": removed,
    }


def run_jobs(jobs: list[Job], parallel: int, timeout_min: float, work: Path, say) -> list[dict]:
    profiles = work / "profiles"
    profiles.mkdir(parents=True, exist_ok=True)
    keep_maps: dict[str, set[str]] = {}
    for job in jobs:
        maps = job.side.path / "maps"
        if job.side.is_project and maps.is_dir():
            keep_maps.setdefault(str(job.side.path.resolve()), {p.name for p in maps.iterdir()})
    # Biggest maps first, so the small ones fill in at the end.
    queue = sorted(jobs, key=lambda j: (ALL_SEEDS[j.key]["levels"], SIZES.index(ALL_SEEDS[j.key]["size"]), ALL_SEEDS[j.key]["players"]), reverse=True)
    running: list[tuple[Job, subprocess.Popen, Path, float]] = []
    results = []
    try:
        while queue or running:
            locks = {j.lock() for j, *_ in running}
            while len(running) < parallel:
                job = next((j for j in queue if j.lock() not in locks), None)
                if job is None:
                    break
                queue.remove(job)
                locks.add(job.lock())
                running.append((job, *start(job, profiles)))
            time.sleep(1)
            for item in list(running):
                job, proc, profile, started = item
                timed_out = proc.poll() is None and time.time() - started > timeout_min * 60
                if timed_out:
                    kill(proc)
                if proc.poll() is None:
                    continue
                running.remove(item)
                row = finish(job, proc, profile, started, timed_out, keep_maps)
                results.append(row)
                say(f"  {job.side.name} {job.stem}: {'ok' if row['ok'] else 'FAILED ' + row['problem'][:160]}, day {row['final_day']}, "
                    f"{row['seconds']:.0f} s{', %d script errors' % len(row['script_errors']) if row['script_errors'] else ''}")
    except KeyboardInterrupt:
        for job, proc, profile, _ in running:
            kill(proc)
            shutil.rmtree(profile, ignore_errors=True)
        raise
    shutil.rmtree(profiles, ignore_errors=True)
    return results


# ---------------------------------------------------------------- comparison

def read_digest(path: Path) -> list[tuple[int, str, int]]:
    if not path.exists():
        return []
    rows = []
    for line in path.read_text(encoding="utf-8").splitlines():
        day, sha, length = line.split("\t")
        rows.append((int(day), sha, int(length)))
    return rows


def first_differing_day(a: list, b: list) -> int | None:
    for x, y in zip(a, b):
        if x != y:
            return x[0]
    if len(a) != len(b):
        shorter = a if len(a) < len(b) else b
        longer = b if shorter is a else a
        return longer[len(shorter)][0]
    return None


def strip_timing(value):
    if isinstance(value, dict):
        return {k: strip_timing(v) for k, v in value.items() if k not in TIMING_KEYS}
    if isinstance(value, list):
        return [strip_timing(v) for v in value]
    return value


def short_repr(value, limit: int = 160) -> str:
    text = json.dumps(value, separators=(",", ":")) if not isinstance(value, str) else json.dumps(value)
    return text if len(text) <= limit else text[:limit] + "..."


def differences(a, b, path: str = "", out: list | None = None, limit: int = 12) -> list[str]:
    """Differing paths in document order, int and float apart, key order checked."""
    out = [] if out is None else out
    if len(out) >= limit:
        return out
    if type(a) is not type(b):
        out.append(f"{path or '$'}: {type(a).__name__} {short_repr(a)} vs {type(b).__name__} {short_repr(b)}")
    elif isinstance(a, dict):
        missing_b = [k for k in a if k not in b]
        missing_a = [k for k in b if k not in a]
        if missing_a or missing_b:
            out.append(f"{path or '$'}: keys only in A {missing_b[:8]}, only in B {missing_a[:8]}")
        elif list(a) != list(b):
            first = next(i for i, (x, y) in enumerate(zip(a, b)) if x != y)
            out.append(f"{path or '$'}: key order differs from #{first}: A {list(a)[first:first + 4]} vs B {list(b)[first:first + 4]}")
        for k in a:
            if k in b:
                differences(a[k], b[k], f"{path}.{k}" if path else k, out, limit)
    elif isinstance(a, list):
        if len(a) != len(b):
            out.append(f"{path or '$'}: length {len(a)} vs {len(b)}")
        for i, (x, y) in enumerate(zip(a, b)):
            differences(x, y, f"{path}[{i}]", out, limit)
    elif a != b:
        out.append(f"{path or '$'}: {short_repr(a)} vs {short_repr(b)}")
    return out


def compare_seed(key: str, dir_a: Path, dir_b: Path, failed: list[str]) -> dict:
    """failed: why a run of this seed on either side failed; such a seed is never identical."""
    da, db = read_digest(dir_a / f"{key}.digest"), read_digest(dir_b / f"{key}.digest")
    row = {"seed": key, "days_a": len(da), "days_b": len(db), "first_day": first_differing_day(da, db), "record": [],
           "failed": failed}
    ra, rb = dir_a / f"{key}.json", dir_b / f"{key}.json"
    if ra.exists() and rb.exists():
        row["record"] = differences(strip_timing(json.loads(ra.read_text(encoding="utf-8"))),
                                    strip_timing(json.loads(rb.read_text(encoding="utf-8"))), limit=6)
    else:
        row["record"] = [f"record missing: A {ra.exists()}, B {rb.exists()}"]
    row["identical"] = bool(da) and row["first_day"] is None and not row["record"] and not failed
    return row


def run_failures(folder: Path, key: str) -> list[str]:
    """Why the run of a seed in a `run` output folder failed: its runs.json entry and its log, read again
    (a runs.json from before a rule existed does not apply it). A seed with neither counts as failed."""
    runs = json.loads((folder / "runs.json").read_text(encoding="utf-8")) if (folder / "runs.json").exists() else []
    entry = next((r for r in runs if r.get("seed") == key and r.get("dump_day") is None), None)
    problems = [str(entry.get("problem") or "failed")] if entry and not entry.get("ok") else []
    log = folder / f"{key}.log"
    if log.exists():
        problem = log_verdict(log.read_text(encoding="utf-8", errors="replace"))[0]
        if problem and problem not in problems:
            problems.append(problem)
    elif entry is None:
        problems.append(f"no {key}.log and no runs.json entry")
    return problems


def explain_dump(key: str, day: int, dir_a: Path, dir_b: Path, first_a: list, first_b: list) -> dict:
    """The first differing paths of the day's full state, after checking each side replayed itself."""
    stem = f"{key}.dump{day}"
    info: dict = {"day": day, "paths": []}
    for name, folder, first in (("A", dir_a, first_a), ("B", dir_b, first_b)):
        again = read_digest(folder / f"{stem}.digest")
        expected = [r for r in first if r[0] <= day]
        if again != expected:
            info.setdefault("not_reproducible", []).append(f"{name} replayed differently from day {first_differing_day(expected, again)}")
    sa, sb = dir_a / f"{stem}.state.json", dir_b / f"{stem}.state.json"
    if not (sa.exists() and sb.exists()):
        info["paths"] = [f"state dump missing: A {sa.exists()}, B {sb.exists()}"]
        return info
    ta, tb = sa.read_bytes(), sb.read_bytes()
    try:
        info["paths"] = differences(json.loads(ta), json.loads(tb))
    except ValueError as exc:
        at = next((i for i, (x, y) in enumerate(zip(ta, tb)) if x != y), min(len(ta), len(tb)))
        info["paths"] = [f"not JSON ({exc}); first differing byte {at}: A {ta[max(0, at - 60):at + 60]!r} vs B {tb[max(0, at - 60):at + 60]!r}"]
    if not info["paths"]:
        info["paths"] = ["the dumps are equal although the digests differ (sha256 A %s, B %s)"
                         % (hashlib.sha256(ta).hexdigest()[:12], hashlib.sha256(tb).hexdigest()[:12])]
    return info


def print_rows(rows: list[dict], say) -> None:
    for row in rows:
        if row["identical"]:
            say(f"{row['seed']:5} identical: {row['days_a']} daily digests and the match record")
            continue
        where = f"first differing day {row['first_day']}" if row["first_day"] is not None else "daily digests identical"
        if row["failed"]:
            say(f"{row['seed']:5} FAILED: {'; '.join(row['failed'])[:220]}")
            say(f"        {where} (A {row['days_a']} days, B {row['days_b']} days)")
        else:
            say(f"{row['seed']:5} DIFFERENT: {where} (A {row['days_a']} days, B {row['days_b']} days)")
        for text in row["record"][:3]:
            say(f"        record {text}")
        dump = row.get("dump")
        if dump:
            for note in dump.get("not_reproducible", []):
                say(f"        WARNING {note}")
            for text in dump["paths"]:
                say(f"        day {dump['day']} {text}")


# ---------------------------------------------------------------- commands

def pick_seeds(text: str | None) -> list[str]:
    keys = [k.strip() for k in (text or ",".join(SEEDS)).split(",") if k.strip()]
    unknown = [k for k in keys if k not in ALL_SEEDS]
    if unknown:
        sys.exit(f"unknown seeds {unknown}; known: {', '.join(ALL_SEEDS)}")
    return keys


def make_side(name: str, path: str, godot: str | None, env: dict[str, str]) -> Side:
    p = Path(path).resolve()
    if not p.exists():
        sys.exit(f"{name}: {p} does not exist")
    if p.is_dir() and not (p / "project.godot").exists():
        sys.exit(f"{name}: {p} has no project.godot")
    return Side(name, p, find_godot(godot) if p.is_dir() else "", env)


def portable(args, env: dict[str, str]) -> dict[str, str]:
    return {**env, "HEROES_AI_MATCH_DIGEST_BLANK": PORTABLE_BLANK} if args.portable else env


def make_work(text: str | None) -> Path:
    work = Path(text).resolve() if text else Path(tempfile.mkdtemp(prefix="heroes-rules-parity-"))
    work.mkdir(parents=True, exist_ok=True)
    return work


class Say:
    def __init__(self, path: Path):
        self.file = open(path, "a", encoding="utf-8")

    def __call__(self, text: str) -> None:
        print(text, flush=True)
        self.file.write(text + "\n")
        self.file.flush()


def cmd_check(args) -> int:
    work = make_work(args.work)
    say = Say(work / "parity.log")
    a = make_side("A", args.a, args.godot_a or args.godot, portable(args, parse_env(args.env_a)))
    b = make_side("B", args.b, args.godot_b or args.godot, portable(args, parse_env(args.env_b)))
    keys = pick_seeds(args.seeds)
    dirs = {"A": work / "A", "B": work / "B"}
    for d in dirs.values():
        d.mkdir(exist_ok=True)
    say(f"PARITY {', '.join(keys)}: A {a.path}{' ' + str(a.env) if a.env else ''} | B {b.path}{' ' + str(b.env) if b.env else ''}; "
        f"{args.jobs} at once; output {work}")
    started = time.time()
    jobs = [Job(side, k, dirs[side.name]) for k in keys for side in (a, b)]
    results = run_jobs(jobs, args.jobs, args.timeout_min, work, say)
    rows = [compare_seed(k, dirs["A"], dirs["B"], [f"{r['side']} {r['problem']}" for r in results if r["seed"] == k and not r["ok"]])
            for k in keys]
    differing = [r for r in rows if r["first_day"] is not None and r["days_a"] and r["days_b"]]
    if differing and not args.no_dump:
        say(f"REPLAY to the first differing day with a full state dump: {', '.join(r['seed'] for r in differing)}")
        dump_jobs = [Job(side, r["seed"], dirs[side.name], r["first_day"]) for r in differing for side in (a, b)]
        results += run_jobs(dump_jobs, args.jobs, args.timeout_min, work, say)
        for r in differing:
            r["dump"] = explain_dump(r["seed"], r["first_day"], dirs["A"], dirs["B"],
                                     read_digest(dirs["A"] / f"{r['seed']}.digest"), read_digest(dirs["B"] / f"{r['seed']}.digest"))
            for side in ("A", "B"):
                if not args.keep:
                    (dirs[side] / f"{r['seed']}.dump{r['first_day']}.state.json").unlink(missing_ok=True)
    say(f"RESULT after {(time.time() - started) / 60:.1f} min:")
    print_rows(rows, say)
    errors = sorted({e for r in results for e in r["script_errors"]})
    if errors:
        say(f"{len(errors)} distinct SCRIPT ERROR lines (both sides; see the logs in {work}):")
        for e in errors[:10]:
            say(f"  {e[:220]}")
    (work / "parity.json").write_text(json.dumps({"seeds": keys, "a": str(a.path), "b": str(b.path), "rows": rows, "runs": results}, indent=1), encoding="utf-8")
    failed = [r for r in results if not r["ok"]]
    if failed:
        say(f"{len(failed)} runs FAILED: " + ", ".join(f"{r['side']} {r['seed']}: {r['problem'][:100]}" for r in failed))
        return 2
    same = all(r["identical"] for r in rows)
    say("IDENTICAL" if same else "DIFFERENT")
    return 0 if same else 1


def cmd_run(args) -> int:
    out = make_work(args.out)
    say = Say(out / "parity.log")
    side = make_side("A", args.side, args.godot, portable(args, parse_env(args.env)))
    keys = pick_seeds(args.seeds)
    say(f"RUN {', '.join(keys)} on {side.path}; output {out}")
    results = run_jobs([Job(side, k, out, args.dump_day) for k in keys], args.jobs, args.timeout_min, out, say)
    (out / "runs.json").write_text(json.dumps(results, indent=1), encoding="utf-8")
    return 0 if all(r["ok"] for r in results) else 2


def cmd_compare(args) -> int:
    da, db = Path(args.a).resolve(), Path(args.b).resolve()
    keys = [k for k in pick_seeds(args.seeds) if (da / f"{k}.digest").exists() or (db / f"{k}.digest").exists()]
    rows = [compare_seed(k, da, db, [f"{name} {problem}" for name, folder in (("A", da), ("B", db)) for problem in run_failures(folder, k)])
            for k in keys]
    for r in rows:
        if r["first_day"] is not None and (da / f"{r['seed']}.dump{r['first_day']}.state.json").exists():
            r["dump"] = explain_dump(r["seed"], r["first_day"], da, db, read_digest(da / f"{r['seed']}.digest"), read_digest(db / f"{r['seed']}.digest"))
    print_rows(rows, print)
    failed = [r["seed"] for r in rows if r["failed"]]
    if failed:
        print(f"{len(failed)} seeds FAILED: {', '.join(failed)}")
        return 2
    same = bool(rows) and all(r["identical"] for r in rows)
    print("IDENTICAL" if same else "DIFFERENT")
    return 0 if same else 1


def link_dir(link: Path, target: Path) -> None:
    if IS_WINDOWS:
        subprocess.run(["cmd", "/c", "mklink", "/J", str(link), str(target)], check=True, capture_output=True)
    else:
        link.symlink_to(target, target_is_directory=True)


def is_link(path: Path) -> bool:
    return path.is_symlink() or (hasattr(path, "is_junction") and path.is_junction())


def cmd_prepare(args) -> int:
    dest = Path(args.dest).resolve()
    if dest.exists() and any(dest.iterdir()):
        sys.exit(f"{dest} exists and is not empty")
    if dest == ROOT or ROOT in dest.parents:
        sys.exit("the copy must be outside the repository")
    rev = subprocess.run(["git", "-C", str(ROOT), "rev-parse", args.rev], capture_output=True, text=True, check=True).stdout.strip()
    tar = subprocess.run(["git", "-C", str(ROOT), "archive", "--format=tar", rev, "--", ".", ":(exclude)art"], capture_output=True, check=True).stdout
    dest.mkdir(parents=True, exist_ok=True)
    (dest / COPY_MARKER).write_text(f"{rev}\n{ROOT}\n", encoding="utf-8")
    with tarfile.open(fileobj=io.BytesIO(tar)) as archive:
        if sys.version_info >= (3, 12):
            archive.extractall(dest, filter="data")
        else:
            archive.extractall(dest)
    link_dir(dest / "art", (ROOT / "art").resolve())
    (dest / ".godot").mkdir(exist_ok=True)
    for name in GODOT_SMALL_FILES:
        if (ROOT / ".godot" / name).exists():
            shutil.copy2(ROOT / ".godot" / name, dest / ".godot" / name)
    # The native libraries registered are the revision's own, not this checkout's (which may lack one).
    extensions = sorted(f"res://{path.relative_to(dest).as_posix()}" for path in (dest / "src" / "gdextension").glob("*.gdextension"))
    (dest / ".godot" / "extension_list.cfg").write_text("".join(f"{line}\n" for line in extensions), encoding="utf-8", newline="\n")
    link_dir(dest / ".godot" / "imported", (ROOT / ".godot" / "imported").resolve())
    (dest / "maps").mkdir(exist_ok=True)
    print(f"{dest}: {rev[:9]} without art/; art and .godot/imported linked to {ROOT}")
    return 0


def cmd_remove(args) -> int:
    dest = Path(args.dest).absolute()
    if not (dest / COPY_MARKER).exists():
        sys.exit(f"{dest} is not a copy made by `prepare` (no {COPY_MARKER})")
    for link in (dest / "art", dest / ".godot" / "imported"):
        if is_link(link):
            os.rmdir(link) if IS_WINDOWS else link.unlink()
        elif link.exists():
            sys.exit(f"{link} is not a link; not removing {dest}")
    shutil.rmtree(dest)
    print(f"removed {dest}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)

    def common(p, with_side_env: bool) -> None:
        p.add_argument("--seeds", help=f"comma-separated, from {', '.join(ALL_SEEDS)} (default the committed set: {', '.join(SEEDS)})")
        p.add_argument("--jobs", type=int, default=6, help="Godot runs at once (default 6)")
        p.add_argument("--timeout-min", type=float, default=60, help="per run (default 60)")
        p.add_argument("--godot", help="editor binary for project directories (default as tools/core_suite.py)")
        p.add_argument("--portable", action="store_true",
                       help="blank the map package's location in the digest (editor against an exported build)")
        if with_side_env:
            p.add_argument("--env", action="append", metavar="NAME=VALUE", help="extra environment for the runs")

    p = sub.add_parser("check", help="play both sides, compare, explain the first difference")
    p.add_argument("a")
    p.add_argument("b")
    common(p, False)
    p.add_argument("--godot-a")
    p.add_argument("--godot-b")
    p.add_argument("--env-a", action="append", metavar="NAME=VALUE")
    p.add_argument("--env-b", action="append", metavar="NAME=VALUE")
    p.add_argument("--work", help="output folder (default a new temp folder)")
    p.add_argument("--no-dump", action="store_true", help="skip the replay with a full state dump")
    p.add_argument("--keep", action="store_true", help="keep the state dumps")
    p.set_defaults(func=cmd_check)

    p = sub.add_parser("run", help="play one side")
    p.add_argument("side")
    common(p, True)
    p.add_argument("--out", help="output folder (default a new temp folder)")
    p.add_argument("--dump-day", type=int, help="stop on this day with a full state dump")
    p.set_defaults(func=cmd_run)

    p = sub.add_parser("compare", help="compare two `run` folders")
    p.add_argument("a")
    p.add_argument("b")
    p.add_argument("--seeds")
    p.set_defaults(func=cmd_compare)

    p = sub.add_parser("prepare", help="copy a revision outside the repo")
    p.add_argument("rev")
    p.add_argument("dest")
    p.set_defaults(func=cmd_prepare)

    p = sub.add_parser("remove", help="delete a prepared copy")
    p.add_argument("dest")
    p.set_defaults(func=cmd_remove)

    p = sub.add_parser("seeds", help="list the seed set")
    p.set_defaults(func=lambda a: print("\n".join(f"{k:5} {json.dumps(v)}" for k, v in ALL_SEEDS.items())) or 0)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
