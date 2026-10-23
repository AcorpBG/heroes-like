#!/usr/bin/env python3
"""Rules parity check: the six committed seed setups played by two copies of the game, compared day by day.

    python tools/rules_parity.py check A B                 # play both, compare, explain the first difference
    python tools/rules_parity.py check A B --seeds l1,s2 --env-b HEROES_NATIVE_DAY=shadow
    python tools/rules_parity.py run A --out DIR           # play one side only (for example on Linux)
    python tools/rules_parity.py check A A --one-process-b # every seed fresh against all in one process
    python tools/rules_parity.py compare DIR_A DIR_B       # compare two `run` outputs
    python tools/rules_parity.py prepare REV DEST          # a copy of another revision, outside the repo
    python tools/rules_parity.py remove DEST               # delete a prepared copy (junctions first)
    python tools/rules_parity.py seeds
    python tools/rules_parity.py check A B --human         # a human player on seat 1, through the screens
    python tools/rules_parity.py check A A --runner-b      # the game against the match runner outside Godot

A side is a project directory (run with the editor binary, --godot / --godot-a / --godot-b) or an
exported game binary of an AI batch preset (export_presets.cfg; it starts the match runner and
loads the .pck beside it). An exported build writes its map package to user://maps, the editor to
res://maps: compare the two with --portable, which blanks the fields that hold that location. Every match writes a
digest line per day (HEROES_AI_MATCH_DIGEST in tests/ai_versus_ai_match_report.gd: the Variant hash
of the whole session state, insertion order, int and float apart; a runner from before 2026-10-23
writes sha256 of its JSON instead) and its match record. `check` compares the digests and the
records (timing fields left out); for a seed that differs it plays both sides again to the first
differing day with a full state dump and reports the first differing JSON paths. Two sides whose
digests have different formats compare their records only and never count as identical.

--one-process (run) and --one-process-a/-b (check) play that side's seeds one after another in one
Godot process, in the order --seeds gives (HEROES_AI_MATCH_LIST), as tools/ai_match_batch.py plays
several matches per process; each seed still gets its own digest, record and log (the process's log
split at each match). A match must play the same there as in a process of its own. The replays with
a full state dump always run in a process of their own.

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

--runner-a/--runner-b (check) and --runner (run) play that side through the match runner outside Godot (Phase 8):
the side's Godot match runner sets each match up and writes it as a snapshot (HEROES_AI_MATCH_PREPARE), and the
side's bin/match_sim_cli plays its days and writes the digest, the record and the report line the scene would.
The prepare's own lines go into the log behind "PREPARE ". With --one-process one Godot process prepares the
seeds and one match_sim_cli process plays them, on threads. A runner side must be a project directory with a
built bin/match_sim_cli; it plays AI seeds only.

--human (Phase 7, owner decision D-a) plays HUMAN_SEEDS instead: tests/human_seat_report.tscn plays seat 1 by
fixed rules through the real main menu, overworld, town and battle screens, on generated maps or on the D9 copies
of the owner's saves (HEROES_SAVE_COPIES, default D:\\Games\\godot\\heroes-like-save-copies). It writes a digest
row per action, "day<TAB>step<TAB>action<TAB>session<TAB>panels", the last hash being that of the texts the
screen shows; `check` reports the first differing step and replays both sides to it with a dump of the state and
the panel texts. Both sides play this checkout's runner: it is copied into a side made by `prepare`, and any
other project side must already have the same one. A save run gets the save in its profile's user://saves and
the maps the save names in <side>/maps, copied with their times kept and removed after the runs unless they were
there. Each human seed runs in a process of its own (--one-process plays AI seeds only). `check` also prints each
action kind's time on both sides, the screens' speed.
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
from ai_match_batch import BEGIN_ID, SIZES, kill, remove_match_maps, split_match_log  # noqa: E402
from core_suite import find_godot  # noqa: E402

SCENE = "res://tests/ai_versus_ai_match_report.tscn"
REPORT_ID = "AI_VERSUS_AI_MATCH_REPORT"
HUMAN_SCENE = "res://tests/human_seat_report.tscn"
HUMAN_REPORT_ID = "HUMAN_SEAT_REPORT"
HUMAN_RUNNER = ("tests/human_seat_report.gd", "tests/human_seat_report.tscn")
SAVE_COPIES = Path(os.environ.get("HEROES_SAVE_COPIES", r"D:\Games\godot\heroes-like-save-copies"))
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
# --human (Phase 7, 2026-10-23): generated maps at fixed seeds, and the D9 save copies played on from where they
# were saved. The size, players and levels of a save only order the runs.
HUMAN_SEEDS: dict[str, dict] = {
    "h-s2": {"kind": "human", "seed": "human-s2", "players": 2, "size": "homm3_small", "days": 28, "water": "land", "levels": 1},
    "h-m3": {"kind": "human", "seed": "human-m3", "players": 3, "size": "homm3_medium", "days": 21, "water": "normal_water", "levels": 1},
    "h-l4": {"kind": "human", "seed": "human-l4", "players": 4, "size": "homm3_large", "days": 14, "water": "normal_water", "levels": 2},
    "sv-m1": {"kind": "human", "save": "Mireclaw Zhorra Fenwake \u2014 Day 1.save.json", "maps": ["medium-dusk-lantern-deep-64efd5b1"],
              "players": 2, "size": "homm3_medium", "days": 10, "levels": 1},
    "sv-m14": {"kind": "human", "save": "Mireclaw Zhorra Fenwake \u2014 Day 14.save.json", "maps": ["medium-dusk-lantern-deep-64efd5b1"],
               "players": 2, "size": "homm3_medium", "days": 10, "levels": 1},
    "sv-v5": {"kind": "human", "save": "Veilmourn Ivara Blacktide \u2014 Day 5.save.json", "maps": ["medium-fallow-field-spring-a9c4612b"],
              "players": 2, "size": "homm3_medium", "days": 10, "levels": 2},
    "sv-v10": {"kind": "human", "save": "Veilmourn Ivara Blacktide \u2014 Day 10.save.json", "maps": ["medium-fallow-field-spring-a9c4612b"],
               "players": 2, "size": "homm3_medium", "days": 10, "levels": 2},
    "sv-auto": {"kind": "human", "save": "autosave.json", "maps": ["medium-fallow-field-spring-a9c4612b"],
                "players": 2, "size": "homm3_medium", "days": 10, "levels": 2},
}
ALL_SEEDS = {**SEEDS, **EXTRA_SEEDS, **HUMAN_SEEDS}
# Record fields that hold wall-clock time, left out of the comparison.
TIMING_KEYS = ("ai_turn_ms_max", "turn_ms", "timing")
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
    # --runner: the Godot match runner prepares the matches, bin/match_sim_cli plays them.
    runner: bool = False

    @property
    def is_project(self) -> bool:
        return self.path.is_dir()

    @property
    def cli(self) -> Path:
        return self.path / "bin" / ("match_sim_cli.exe" if IS_WINDOWS else "match_sim_cli")

    def command(self, scene: str = SCENE) -> list[str]:
        if self.is_project:
            return [self.godot, "--headless", "--path", str(self.path), "--audio-driver", "Dummy", scene]
        # Release templates take no scene argument; the AI batch presets start the match runner.
        return [str(self.path), "--headless", "--audio-driver", "Dummy"]


@dataclass
class Job:
    side: Side
    key: str
    out: Path
    dump_day: int | None = None
    # --one-process: the seeds the same Godot process plays after key, in order.
    more: tuple[str, ...] = ()

    @property
    def keys(self) -> tuple[str, ...]:
        return (self.key, *self.more)

    def stem(self, key: str) -> str:
        return key if self.dump_day is None else f"{key}.dump{self.dump_day}"

    def locks(self) -> set[tuple[str, str]]:
        return {(str(self.side.path.resolve()), key) for key in self.keys}

    @property
    def human(self) -> bool:
        return is_human(self.key)


def is_human(key: str) -> bool:
    return ALL_SEEDS[key].get("kind") == "human"


def report_id(key: str) -> str:
    return HUMAN_REPORT_ID if is_human(key) else REPORT_ID


def user_dir(profile: Path) -> Path:
    """user:// of a run whose APPDATA (Windows) or XDG_DATA_HOME (Linux) is profile."""
    return profile / ("Godot" if IS_WINDOWS else "godot") / "app_userdata" / "heroes-like"


def human_settings(job: Job, profile: Path) -> dict[str, str]:
    """The human seat runner's setup; a save goes into the profile's user://saves."""
    setup = ALL_SEEDS[job.key]
    stem = job.stem(job.key)
    settings = {"HEROES_HUMAN_DAYS": str(setup["days"]),
                "HEROES_HUMAN_OUT": (job.out / f"{stem}.json").as_posix(),
                "HEROES_HUMAN_DIGEST": (job.out / f"{stem}.digest").as_posix()}
    if "save" in setup:
        saves = user_dir(profile) / "saves"
        saves.mkdir(parents=True)
        shutil.copy2(SAVE_COPIES / "saves" / setup["save"], saves / setup["save"])
        settings["HEROES_HUMAN_SAVE"] = "1"
    else:
        settings.update({"HEROES_HUMAN_SEED": setup["seed"], "HEROES_HUMAN_PLAYERS": str(setup["players"]),
                         "HEROES_HUMAN_SIZE": setup["size"], "HEROES_HUMAN_WATER": setup["water"],
                         "HEROES_HUMAN_LEVELS": str(setup["levels"])})
    if job.dump_day is not None:
        settings["HEROES_HUMAN_DUMP"] = (job.out / f"{stem}.state.json").as_posix()
        settings["HEROES_HUMAN_DUMP_STEP"] = str(job.dump_day)
    for suffix in (".json", ".digest", ".state.json"):
        (job.out / f"{stem}{suffix}").unlink(missing_ok=True)
    return settings


def place_save_maps(jobs: list[Job]) -> list[Path]:
    """The map packages the save runs name, copied into each side's maps folder with their times kept (so the
    match-map cleanup leaves them); returns the files placed, never one that was there."""
    placed: list[Path] = []
    for job in jobs:
        for stem in ALL_SEEDS[job.key].get("maps", []):
            for suffix in (".amap", ".ascenario"):
                source = SAVE_COPIES / "maps" / f"{stem}{suffix}"
                target = job.side.path / "maps" / source.name
                if not source.exists():
                    sys.exit(f"{job.key}: {source} is missing (HEROES_SAVE_COPIES)")
                if not target.exists():
                    target.parent.mkdir(exist_ok=True)
                    shutil.copy2(source, target)
                    placed.append(target)
    return placed


def install_human_runner(side: Side) -> None:
    """Both sides play this checkout's runner: copied into a `prepare` copy, required as is anywhere else."""
    if not side.is_project:
        sys.exit(f"{side.name}: --human needs a project directory, not {side.path}")
    if side.path.resolve() == ROOT.resolve():
        return
    for name in HUMAN_RUNNER:
        mine, theirs = ROOT / name, side.path / name
        if (side.path / COPY_MARKER).exists():
            shutil.copy2(mine, theirs)
        elif not theirs.exists() or theirs.read_bytes() != mine.read_bytes():
            sys.exit(f"{side.name}: {theirs} is not this checkout's {name}; use a `prepare` copy")


def parse_env(items: list[str] | None) -> dict[str, str]:
    env = {}
    for item in items or []:
        name, sep, value = item.partition("=")
        if not sep or not name:
            sys.exit(f"--env wants NAME=VALUE, got {item}")
        env[name] = value
    return env


def match_settings(job: Job, key: str) -> dict[str, str]:
    setup = ALL_SEEDS[key]
    stem = job.stem(key)
    settings = {
        "HEROES_AI_MATCH_SEED": setup["seed"],
        "HEROES_AI_MATCH_PLAYERS": str(setup["players"]),
        "HEROES_AI_MATCH_SIZE": setup["size"],
        "HEROES_AI_MATCH_GUARDS": setup.get("guards", "normal"),
        "HEROES_AI_MATCH_WATER": setup["water"],
        "HEROES_AI_MATCH_LEVELS": str(setup["levels"]),
        "HEROES_AI_MATCH_MAX_DAYS": str(setup["days"]),
        "HEROES_AI_MATCH_OUT": (job.out / f"{stem}.json").as_posix(),
        "HEROES_AI_MATCH_DIGEST": (job.out / f"{stem}.digest").as_posix(),
    }
    if job.dump_day is not None:
        settings["HEROES_AI_MATCH_DUMP"] = (job.out / f"{stem}.state.json").as_posix()
        settings["HEROES_AI_MATCH_DUMP_DAY"] = str(job.dump_day)
    for suffix in (".json", ".digest", ".state.json"):
        (job.out / f"{stem}{suffix}").unlink(missing_ok=True)
    return settings


def start(job: Job, profiles: Path) -> tuple[subprocess.Popen, Path, float]:
    profile = Path(tempfile.mkdtemp(prefix=f"{job.side.name}-{job.key}-", dir=profiles))
    env = {k: v for k, v in os.environ.items() if not k.startswith(("HEROES_AI_MATCH_", "HEROES_HUMAN_"))}
    env.update(job.side.env)
    env.update({"APPDATA": str(profile), "XDG_DATA_HOME": str(profile), "XDG_CONFIG_HOME": str(profile), "XDG_CACHE_HOME": str(profile)})
    scene = SCENE
    command = None
    if job.human:
        env.update(human_settings(job, profile))
        scene = HUMAN_SCENE
        log_path = job.out / f"{job.stem(job.key)}.log"
    elif job.side.runner:
        runner_job = profile / "runner.json"
        runner_job.write_text(json.dumps({"godot": job.side.command(scene), "cli": str(job.side.cli), "snapshots": str(profile / "snapshots"),
                                          "matches": [match_settings(job, key) for key in job.keys]}, indent=1), encoding="utf-8")
        command = [sys.executable, str(Path(__file__).resolve()), "runner-job", str(runner_job)]
        log_path = job.out / (f"{job.key}.process.log" if job.more else f"{job.stem(job.key)}.log")
    elif job.more:
        list_path = job.out / f"{job.key}.list.json"
        list_path.write_text(json.dumps([match_settings(job, key) for key in job.keys], indent=1), encoding="utf-8")
        env["HEROES_AI_MATCH_LIST"] = str(list_path)
        log_path = job.out / f"{job.key}.process.log"
    else:
        env.update(match_settings(job, job.key))
        log_path = job.out / f"{job.stem(job.key)}.log"
    log = open(log_path, "w", encoding="utf-8", errors="replace")
    extra = {} if IS_WINDOWS else {"start_new_session": True}
    proc = subprocess.Popen(command or job.side.command(scene), env=env, stdout=log, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL, **extra)
    log.close()
    return proc, profile, time.time()


def log_verdict(text: str, returncode: int | None = None, timed_out: bool = False,
                report_id: str = REPORT_ID) -> tuple[str, list[str], dict]:
    """A run's problem ("" when it is clean), its SCRIPT ERROR lines and its report, from its log."""
    report = {}
    for line in text.splitlines():
        if line.startswith(report_id + " "):
            try:
                report = json.loads(line[len(report_id) + 1:])
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


def finish(job: Job, proc: subprocess.Popen, profile: Path, started: float, timed_out: bool, keep_maps: dict[str, set[str]]) -> list[dict]:
    shutil.rmtree(profile, ignore_errors=True)
    if job.more:
        # Each seed's log: the lines before the first match and its own.
        process_log = job.out / f"{job.key}.process.log"
        preamble, sections = split_match_log(process_log.read_text(encoding="utf-8", errors="replace"))
        # By the record each match names: the match runner outside Godot ends them in any order.
        by_out = {out: lines for out, lines in sections}
        for index, key in enumerate(job.keys):
            out = (job.out / f"{job.stem(key)}.json").as_posix()
            lines = by_out[out] if out in by_out else sections[index][1] if index < len(sections) else ["(the process ended before this match began)"]
            (job.out / f"{key}.log").write_text("\n".join(preamble + lines) + "\n", encoding="utf-8")
        process_log.unlink(missing_ok=True)
        (job.out / f"{job.key}.list.json").unlink(missing_ok=True)
    rows = []
    for key in job.keys:
        stem = job.stem(key)
        text = (job.out / f"{stem}.log").read_text(encoding="utf-8", errors="replace")
        reported = any(line.startswith(report_id(key) + " ") for line in text.splitlines())
        problem, script_errors, report = log_verdict(text, proc.returncode, timed_out and not reported, report_id(key))
        record_path = job.out / f"{stem}.json"
        removed: list[str] = []
        if job.side.is_project and record_path.exists():
            try:
                scenario_id = str(json.loads(record_path.read_text(encoding="utf-8"))["setup"].get("scenario_id", ""))
                removed = remove_match_maps(scenario_id, started, keep_maps.get(str(job.side.path.resolve()), set()), job.side.path / "maps")
            except (ValueError, KeyError):
                pass
        rows.append({
            "side": job.side.name, "seed": key, "dump_day": job.dump_day, "ok": not problem, "problem": problem,
            "seconds": report.get("seconds") if job.more else round(time.time() - started, 1), "final_day": report.get("final_day"),
            "script_errors": script_errors,
            "maps_removed": removed,
        })
    return rows


def run_jobs(jobs: list[Job], parallel: int, timeout_min: float, work: Path, say) -> list[dict]:
    profiles = work / "profiles"
    profiles.mkdir(parents=True, exist_ok=True)
    placed = place_save_maps([j for j in jobs if j.human])
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
            locks = set().union(*(j.locks() for j, *_ in running))
            while len(running) < parallel:
                job = next((j for j in queue if not j.locks() & locks), None)
                if job is None:
                    break
                queue.remove(job)
                locks |= job.locks()
                running.append((job, *start(job, profiles)))
            time.sleep(1)
            for item in list(running):
                job, proc, profile, started = item
                timed_out = proc.poll() is None and time.time() - started > timeout_min * 60 * len(job.keys)
                if timed_out:
                    kill(proc)
                if proc.poll() is None:
                    continue
                running.remove(item)
                for row in finish(job, proc, profile, started, timed_out, keep_maps):
                    results.append(row)
                    say(f"  {job.side.name} {job.stem(row['seed'])}: {'ok' if row['ok'] else 'FAILED ' + row['problem'][:160]}, "
                        f"day {row['final_day']}, {row['seconds'] or 0:.0f} s"
                        f"{', %d script errors' % len(row['script_errors']) if row['script_errors'] else ''}")
    except KeyboardInterrupt:
        for job, proc, profile, _ in running:
            kill(proc)
            shutil.rmtree(profile, ignore_errors=True)
        raise
    finally:
        for path in placed:
            path.unlink(missing_ok=True)
    shutil.rmtree(profiles, ignore_errors=True)
    return results


# ---------------------------------------------------------------- comparison

def read_digest(path: Path) -> list[tuple]:
    """(day, digest) per line; a runner from before 2026-10-23 wrote (day, sha256 of the JSON, its length); the
    human seat runner writes (day, step, action, session digest, panel digest)."""
    if not path.exists():
        return []
    rows = []
    for line in path.read_text(encoding="utf-8").splitlines():
        day, *rest = line.split("\t")
        if len(rest) == 4:
            rows.append((int(day), int(rest[0]), *rest[1:]))
        else:
            rows.append((int(day), *rest))
    return rows


def digest_format(rows: list[tuple]) -> str:
    if not rows:
        return ""
    return {3: "sha256 of the JSON", 5: "human seat actions"}.get(len(rows[0]), "Variant hash")


def first_differing_row(a: list, b: list) -> tuple | None:
    for x, y in zip(a, b):
        if x != y:
            return x
    if len(a) != len(b):
        shorter = a if len(a) < len(b) else b
        longer = b if shorter is a else a
        return longer[len(shorter)]
    return None


def first_differing_day(a: list, b: list) -> int | None:
    row = first_differing_row(a, b)
    return None if row is None else row[0]


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
    first = first_differing_row(da, db)
    row = {"seed": key, "days_a": len(da), "days_b": len(db), "first_day": None if first is None else first[0], "record": [],
           "failed": failed, "formats": ""}
    if first is not None and is_human(key):
        row["first_step"] = first[1]
        row["first_action"] = first[2]
    if da and db and digest_format(da) != digest_format(db):
        row["formats"] = f"digest formats differ (A {digest_format(da)}, B {digest_format(db)}), records compared only"
        row["first_day"] = None
    ra, rb = dir_a / f"{key}.json", dir_b / f"{key}.json"
    if ra.exists() and rb.exists():
        row["record"] = differences(strip_timing(json.loads(ra.read_text(encoding="utf-8"))),
                                    strip_timing(json.loads(rb.read_text(encoding="utf-8"))), limit=6)
    else:
        row["record"] = [f"record missing: A {ra.exists()}, B {rb.exists()}"]
    row["identical"] = bool(da) and row["first_day"] is None and not row["record"] and not failed and not row["formats"]
    return row


def run_failures(folder: Path, key: str) -> list[str]:
    """Why the run of a seed in a `run` output folder failed: its runs.json entry and its log, read again
    (a runs.json from before a rule existed does not apply it). A seed with neither counts as failed."""
    runs = json.loads((folder / "runs.json").read_text(encoding="utf-8")) if (folder / "runs.json").exists() else []
    entry = next((r for r in runs if r.get("seed") == key and r.get("dump_day") is None), None)
    problems = [str(entry.get("problem") or "failed")] if entry and not entry.get("ok") else []
    log = folder / f"{key}.log"
    if log.exists():
        problem = log_verdict(log.read_text(encoding="utf-8", errors="replace"), report_id=report_id(key))[0]
        if problem and problem not in problems:
            problems.append(problem)
    elif entry is None:
        problems.append(f"no {key}.log and no runs.json entry")
    return problems


def dump_point(row: dict) -> int:
    """Where a differing seed is replayed to: its first differing day, or step for the human seat."""
    return row["first_step"] if is_human(row["seed"]) else row["first_day"]


def explain_dump(key: str, day: int, dir_a: Path, dir_b: Path, first_a: list, first_b: list) -> dict:
    """The first differing paths of the day's full state (the human seat's: of its step's state and panel texts),
    after checking each side replayed itself."""
    stem = f"{key}.dump{day}"
    human = is_human(key)
    info: dict = {"day": day, "label": f"step {day}" if human else f"day {day}", "paths": []}
    for name, folder, first in (("A", dir_a, first_a), ("B", dir_b, first_b)):
        again = read_digest(folder / f"{stem}.digest")
        expected = [r for r in first if (r[1] if human else r[0]) <= day]
        if again != expected:
            where = first_differing_row(expected, again)
            info.setdefault("not_reproducible", []).append(
                f"{name} replayed differently from {'step %s' % where[1] if human else 'day %s' % where[0]}")
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
            what = "action digests and the record" if is_human(row["seed"]) else "daily digests and the match record"
            say(f"{row['seed']:5} identical: {row['days_a']} {what}")
            continue
        where = (row["formats"] if row["formats"]
                 else f"first differing step {row['first_step']} ({row['first_action']}, day {row['first_day']})" if "first_step" in row
                 else f"first differing day {row['first_day']}" if row["first_day"] is not None
                 else "daily digests identical")
        if row["failed"]:
            say(f"{row['seed']:5} FAILED: {'; '.join(row['failed'])[:220]}")
            say(f"        {where} (A {row['days_a']} days, B {row['days_b']} days)")
        else:
            say(f"{row['seed']:5} DIFFERENT: {where} (A {row['days_a']} days, B {row['days_b']} days)")
        for text in row["record"][:3]:
            say(f"        record {text}")
        if row["formats"] and not row["record"]:
            say("        record identical")
        dump = row.get("dump")
        if dump:
            for note in dump.get("not_reproducible", []):
                say(f"        WARNING {note}")
            for text in dump["paths"]:
                say(f"        {dump.get('label', 'day %s' % dump['day'])} {text}")


# ---------------------------------------------------------------- commands

def pick_seeds(text: str | None, human: bool = False) -> list[str]:
    keys = [k.strip() for k in (text or ",".join(HUMAN_SEEDS if human else SEEDS)).split(",") if k.strip()]
    unknown = [k for k in keys if k not in ALL_SEEDS]
    if unknown:
        sys.exit(f"unknown seeds {unknown}; known: {', '.join(ALL_SEEDS)}")
    return keys


def make_side(name: str, path: str, godot: str | None, env: dict[str, str], runner: bool = False) -> Side:
    p = Path(path).resolve()
    if not p.exists():
        sys.exit(f"{name}: {p} does not exist")
    if p.is_dir() and not (p / "project.godot").exists():
        sys.exit(f"{name}: {p} has no project.godot")
    side = Side(name, p, find_godot(godot) if p.is_dir() else "", env, runner)
    if runner and not (side.is_project and side.cli.exists()):
        sys.exit(f"{name}: --runner needs a project directory with a built bin/match_sim_cli")
    return side


def side_text(side: Side) -> str:
    return f"{side.path}{' (match runner)' if side.runner else ''}{' ' + str(side.env) if side.env else ''}"


def portable(args, env: dict[str, str]) -> dict[str, str]:
    return {**env, "HEROES_AI_MATCH_DIGEST_BLANK": PORTABLE_BLANK} if args.portable else env


def make_work(text: str | None) -> Path:
    work = Path(text).resolve() if text else Path(tempfile.mkdtemp(prefix="heroes-rules-parity-"))
    work.mkdir(parents=True, exist_ok=True)
    return work


def print_screen_times(keys: list[str], dirs: dict[str, Path], say) -> None:
    """The human seat's time per action kind on both sides, summed over its seeds: the screens' speed."""
    totals: dict[str, dict[str, list[float]]] = {}
    for key in keys:
        for side, folder in dirs.items():
            path = folder / f"{key}.json"
            if not path.exists():
                continue
            for kind, entry in json.loads(path.read_text(encoding="utf-8")).get("timing", {}).items():
                total = totals.setdefault(kind, {}).setdefault(side, [0, 0.0, 0.0])
                total[0] += int(entry["n"])
                total[1] += float(entry["ms"])
                total[2] = max(total[2], float(entry["max_ms"]))
    if not totals:
        return
    say("SCREEN TIME per action kind, ms per action (max), A | B:")
    for kind in sorted(totals, key=lambda k: -sum(t[1] for t in totals[k].values())):
        cells = []
        for side in dirs:
            n, ms, top = totals[kind].get(side, [0, 0.0, 0.0])
            cells.append(f"{ms / n:8.1f} ({top:7.1f}) x{n}" if n else f"{'-':>8}")
        say(f"  {kind:16} " + " | ".join(cells))


def human_keys_ready(keys: list[str], sides: list[Side], one_process: bool) -> None:
    """Installs the human seat runner on each side when keys has a human seed."""
    if not any(is_human(k) for k in keys):
        return
    if one_process:
        sys.exit("--one-process and --runner play AI seeds only; the human seat runs one seed per process")
    for side in sides:
        install_human_runner(side)


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
    a = make_side("A", args.a, args.godot_a or args.godot, portable(args, parse_env(args.env_a)), args.runner_a)
    b = make_side("B", args.b, args.godot_b or args.godot, portable(args, parse_env(args.env_b)), args.runner_b)
    keys = pick_seeds(args.seeds, args.human)
    human_keys_ready(keys, [a, b], args.one_process_a or args.one_process_b or args.runner_a or args.runner_b)
    dirs = {"A": work / "A", "B": work / "B"}
    for d in dirs.values():
        d.mkdir(exist_ok=True)
    say(f"PARITY {', '.join(keys)}: A {side_text(a)} | B {side_text(b)}; "
        f"{args.jobs} at once; output {work}")
    started = time.time()
    jobs = []
    for side, one_process in ((a, args.one_process_a), (b, args.one_process_b)):
        jobs += [Job(side, keys[0], dirs[side.name], more=tuple(keys[1:]))] if one_process else [Job(side, k, dirs[side.name]) for k in keys]
    results = run_jobs(jobs, args.jobs, args.timeout_min, work, say)
    rows = [compare_seed(k, dirs["A"], dirs["B"], [f"{r['side']} {r['problem']}" for r in results if r["seed"] == k and not r["ok"]])
            for k in keys]
    differing = [r for r in rows if r["first_day"] is not None and r["days_a"] and r["days_b"]]
    if differing and not args.no_dump:
        say(f"REPLAY to the first differing day with a full state dump: {', '.join(r['seed'] for r in differing)}")
        dump_jobs = [Job(side, r["seed"], dirs[side.name], dump_point(r)) for r in differing for side in (a, b)]
        results += run_jobs(dump_jobs, args.jobs, args.timeout_min, work, say)
        for r in differing:
            r["dump"] = explain_dump(r["seed"], dump_point(r), dirs["A"], dirs["B"],
                                     read_digest(dirs["A"] / f"{r['seed']}.digest"), read_digest(dirs["B"] / f"{r['seed']}.digest"))
            for side in ("A", "B"):
                if not args.keep:
                    (dirs[side] / f"{r['seed']}.dump{dump_point(r)}.state.json").unlink(missing_ok=True)
    say(f"RESULT after {(time.time() - started) / 60:.1f} min:")
    print_rows(rows, say)
    print_screen_times([k for k in keys if is_human(k)], dirs, say)
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
    side = make_side("A", args.side, args.godot, portable(args, parse_env(args.env)), args.runner)
    keys = pick_seeds(args.seeds, args.human)
    human_keys_ready(keys, [side], args.one_process or args.runner)
    say(f"RUN {', '.join(keys)} on {side_text(side)}{' in one process' if args.one_process else ''}; output {out}")
    jobs = [Job(side, keys[0], out, args.dump_day, tuple(keys[1:]))] if args.one_process else [Job(side, k, out, args.dump_day) for k in keys]
    results = run_jobs(jobs, args.jobs, args.timeout_min, out, say)
    (out / "runs.json").write_text(json.dumps(results, indent=1), encoding="utf-8")
    return 0 if all(r["ok"] for r in results) else 2


def cmd_compare(args) -> int:
    da, db = Path(args.a).resolve(), Path(args.b).resolve()
    keys = [k for k in pick_seeds(args.seeds, args.human) if (da / f"{k}.digest").exists() or (db / f"{k}.digest").exists()]
    rows = [compare_seed(k, da, db, [f"{name} {problem}" for name, folder in (("A", da), ("B", db)) for problem in run_failures(folder, k)])
            for k in keys]
    for r in rows:
        if r["first_day"] is not None and (da / f"{r['seed']}.dump{dump_point(r)}.state.json").exists():
            r["dump"] = explain_dump(r["seed"], dump_point(r), da, db, read_digest(da / f"{r['seed']}.digest"), read_digest(db / f"{r['seed']}.digest"))
    print_rows(rows, print)
    print_screen_times([k for k in keys if is_human(k)], {"A": da, "B": db}, print)
    failed = [r["seed"] for r in rows if r["failed"]]
    if failed:
        print(f"{len(failed)} seeds FAILED: {', '.join(failed)}")
        return 2
    same = bool(rows) and all(r["identical"] for r in rows)
    print("IDENTICAL" if same else "DIFFERENT")
    return 0 if same else 1


def cmd_runner_job(args) -> int:
    """A runner side's run (start(), hidden): the Godot match runner prepares the job's matches, the side's
    bin/match_sim_cli plays them. The prepare's lines go to the log behind "PREPARE ", so only match_sim_cli's
    lines begin and report a match; a match the prepare did not write reports the prepare's failure."""
    job = json.loads(Path(args.job).read_text(encoding="utf-8"))
    snapshots = Path(job["snapshots"])
    snapshots.mkdir(parents=True, exist_ok=True)
    matches: list[dict] = job["matches"]
    listed = len(matches) > 1
    unprepared = ("HEROES_AI_MATCH_DIGEST", "HEROES_AI_MATCH_DUMP", "HEROES_AI_MATCH_DUMP_DAY")
    prepares = [{**{k: v for k, v in settings.items() if k not in unprepared},
                 "HEROES_AI_MATCH_PREPARE": (snapshots / f"match{index}.snap").as_posix()} for index, settings in enumerate(matches)]
    env = dict(os.environ)
    if listed:
        (snapshots / "prepare.json").write_text(json.dumps(prepares, indent=1), encoding="utf-8")
        env["HEROES_AI_MATCH_LIST"] = str(snapshots / "prepare.json")
    else:
        env.update(prepares[0])
    proc = subprocess.run(job["godot"], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL)
    prepared: set[str] = set()
    failures: dict[str, str] = {}
    for line in proc.stdout.decode("utf-8", errors="replace").splitlines():
        print("PREPARE " + line)
        if line.startswith(REPORT_ID + " "):
            try:
                report = json.loads(line[len(REPORT_ID) + 1:])
            except ValueError:
                continue
            if report.get("ok") and report.get("prepared"):
                prepared.add(Path(report["prepared"]).resolve().as_posix())
            elif not report.get("ok"):
                failures[str(report.get("out", ""))] = line
    play = []
    failed = False
    for settings, prepare in zip(matches, prepares):
        if Path(prepare["HEROES_AI_MATCH_PREPARE"]).resolve().as_posix() in prepared:
            play.append({**settings, "HEROES_AI_MATCH_SNAPSHOT": prepare["HEROES_AI_MATCH_PREPARE"]})
            continue
        failed = True
        out = settings["HEROES_AI_MATCH_OUT"]
        if listed:
            print(f"{BEGIN_ID} {json.dumps({'out': out})}")
        error = f"the match runner did not prepare the match (exit {proc.returncode})"
        print(failures.get(out) or f"{REPORT_ID} " + json.dumps({"ok": False, "out": out, "error": error}))
    sys.stdout.flush()
    if play:
        env = dict(os.environ)
        if listed:
            (snapshots / "play.json").write_text(json.dumps(play, indent=1), encoding="utf-8")
            env["HEROES_AI_MATCH_LIST"] = str(snapshots / "play.json")
        else:
            env.update(play[0])
        failed = subprocess.run([job["cli"]], env=env, stdin=subprocess.DEVNULL).returncode != 0 or failed
    return 1 if failed else 0


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
        p.add_argument("--timeout-min", type=float, default=60, help="per match (default 60)")
        p.add_argument("--godot", help="editor binary for project directories (default as tools/core_suite.py)")
        p.add_argument("--portable", action="store_true",
                       help="blank the map package's location in the digest (editor against an exported build)")
        p.add_argument("--human", action="store_true", help=f"default to the human seat's set: {', '.join(HUMAN_SEEDS)}")
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
    p.add_argument("--one-process-a", action="store_true", help="play side A's seeds in one Godot process, in --seeds order")
    p.add_argument("--one-process-b", action="store_true", help="play side B's seeds in one Godot process, in --seeds order")
    p.add_argument("--runner-a", action="store_true", help="play side A through the match runner outside Godot (bin/match_sim_cli)")
    p.add_argument("--runner-b", action="store_true", help="play side B through the match runner outside Godot (bin/match_sim_cli)")
    p.add_argument("--work", help="output folder (default a new temp folder)")
    p.add_argument("--no-dump", action="store_true", help="skip the replay with a full state dump")
    p.add_argument("--keep", action="store_true", help="keep the state dumps")
    p.set_defaults(func=cmd_check)

    p = sub.add_parser("run", help="play one side")
    p.add_argument("side")
    common(p, True)
    p.add_argument("--out", help="output folder (default a new temp folder)")
    p.add_argument("--dump-day", type=int, help="stop on this day (the human seat: step) with a full state dump")
    p.add_argument("--one-process", action="store_true", help="play the seeds in one Godot process, in --seeds order")
    p.add_argument("--runner", action="store_true", help="play through the match runner outside Godot (bin/match_sim_cli)")
    p.set_defaults(func=cmd_run)

    p = sub.add_parser("runner-job")
    p.add_argument("job")
    p.set_defaults(func=cmd_runner_job)

    p = sub.add_parser("compare", help="compare two `run` folders")
    p.add_argument("a")
    p.add_argument("b")
    p.add_argument("--seeds")
    p.add_argument("--human", action="store_true")
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
