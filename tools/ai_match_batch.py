#!/usr/bin/env python3
"""AI-vs-AI match batches: plan, play in parallel, summarize. Owner-requested evaluation only.

    python tools/ai_match_batch.py OUT --players 4 --size large --matches 60 --guards weak,normal,strong --levels 1,2
    python tools/ai_match_batch.py OUT --group 3:medium:30 --group 4:large:30
    python tools/ai_match_batch.py OUT --size small --players 2 --matches 24 --runner   # days outside Godot
    python tools/ai_match_batch.py OUT --resume       # finish an interrupted batch (same commit only)
    python tools/ai_match_batch.py OUT --summarize    # rewrite summary.md from results.jsonl

Before anything runs, OUT gets plan.json: the commit, and per match an explicit seed, the setup
and the line-up. Each finished match appends one line to results.jsonl and prints one line (also
kept in runner.log); its full record is OUT/<run>.json, and its log is kept only when it failed or
printed script errors. summary.md comes last: a per-faction table (finishing places 3-2-1-0 and
wins against a fair share, with the noise band) and the per-match table.

Matches run headless with tests/ai_versus_ai_match_report.tscn, --slots Godot processes at a time
(default 16; lowered when other Godot processes are already running) from one refilling queue:
two-level maps first, then larger maps, then more players. Each process plays up to --per-process
matches in a row (default 4, HEROES_AI_MATCH_LIST), fewer when the queue is short enough that more
would leave slots idle at the end; a match plays as it would in a process of its own, and only the
first one pays Godot's start-up. Each process gets a throwaway user profile (APPDATA on Windows,
XDG_DATA_HOME on Linux) and a timeout, the sum of its matches'. A match the process never began
because an earlier one crashed or timed out goes back into the queue. Two matches with the same
seed never run at once, because both would write the same map package under res://maps; the
package each match writes is deleted when it ends.

Line-ups (--lineups): balanced (default) plays sets of factions in every seat rotation, each set
once before any repeats, picked so every faction gets an even share; random draws distinct sets;
mirrors lets a faction appear twice; --lineup fixes them. Guards, levels and water are crossed over
the line-ups. A map comes from its seed and setup alone: the generator gives each seat the faction
the match names. --rotate plays each line-up on one map in every seat rotation (seat 1 first, then
seat 2 first, ...), so a map's starts are compared with the factions moved round; --matches is
rounded up to a multiple of the players. A process plays all the matches of a seed it takes, and
generates the map once: the matches after the first stamp their factions on the generator's map. Windows and Linux; Godot comes from --godot, $GODOT_BIN, PATH or the owner's install.

--release exports the "<Windows|Linux> AI Batch" preset (the release template, tests/ included) into
OUT/game first and plays every match on that build instead of the editor binary. It needs the Godot
export templates of the editor's version (Editor > Manage Export Templates, or --templates DIR);
the export runs with a throwaway profile holding a copy of them. The release build writes its map
packages into each match's throwaway user profile, not res://maps. OUT/game (about 5 GB) is deleted
when the batch completes.

The computer players' day runs native (docs/native-rules-engine-transition.md, Phase 4). A day
processing path the native day port leaves to GDScript runs in GDScript and prints a NATIVE FALLBACK
line per native call it replaced: each match row counts them by entry and path (native_fallbacks),
and summary.md totals them.

--map-corpus DIR keeps every generated map package there (HEROES_AI_MATCH_MAP_CORPUS: its package pair
and setup, one per map and line-up), and a match whose package is there already starts from it instead
of generating it, with the same game. Another batch on the same plan (--seed and options) then skips
map generation, for example one that compares weight sets. The folder is for one commit: corpus.json
names it, and a batch on another commit refuses the folder. The matches of one seed that a process
plays run one after another, and one on the map and line-up of the match before it (the same seed,
setup and seat factions) starts from a copy of the session that match adopted.

--runner plays the matches outside Godot (docs/native-rules-engine-transition.md, Phase 8): one Godot process
writes the content snapshot into OUT/snapshots (HEROES_AI_MATCH_CONTENT_SNAPSHOT), then one bin/match_sim_cli
process generates each match's map from it as the scene does and plays the match, biggest first, on --slots
threads, and writes the record and report line the scene would; each row is written as its match ends. A
match with a --map-corpus or a .json weight set is set up in Godot instead (map, adoption, handover) and
written as a snapshot there (HEROES_AI_MATCH_PREPARE), which the same process plays and then deletes. The
games are the same as without --runner (tools/rules_parity.py --runner-b checks it). --runner needs a built
bin/match_sim_cli and no --release.

--weights W1,W2,... gives each seat its overworld AI weight set in every match (seat order, one per
player): "default", the name of a set in content/ai_hero_weights.json, or a .json file holding one
set (only the values it changes). Each match record names its seats' sets (setup.seats[].weights);
without --weights every seat plays the default set.
"""
from __future__ import annotations

import argparse
import csv
import io
import itertools
import json
import math
import os
import platform
import random
import re
import shutil
import signal
import statistics
import subprocess
import sys
import tempfile
import time
from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path
import threading
from typing import IO

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from core_suite import find_godot  # noqa: E402

SCENE = "res://tests/ai_versus_ai_match_report.tscn"
REPORT_ID = "AI_VERSUS_AI_MATCH_REPORT"
BEGIN_ID = "AI_VERSUS_AI_MATCH_BEGIN"
MAPS_DIR = ROOT / "maps"
SIZES = ["homm3_small", "homm3_medium", "homm3_large", "homm3_extra_large"]
# Player counts each size is played with (owner, 2026-10-18); never large maps with two.
FITTING_PLAYERS = {"homm3_small": (2,), "homm3_medium": (2, 3), "homm3_large": (3, 4), "homm3_extra_large": (5, 6)}
TIMEOUT_MIN = {"homm3_small": 30, "homm3_medium": 90, "homm3_large": 180, "homm3_extra_large": 360}
GUARDS = ("weak", "normal", "strong")
WATER = ("land", "normal_water", "islands")
SLOW_DAY_MS = 10000
FALLBACK_MARK = "NATIVE FALLBACK: "
IS_WINDOWS = platform.system() == "Windows"
BATCH_PRESET = "Windows AI Batch" if IS_WINDOWS else "Linux AI Batch"
# The exported batch build in OUT/game: the Windows console wrapper keeps stdout, Linux runs the binary.
GAME_BINARY = "heroes-like.console.exe" if IS_WINDOWS else "heroes-like.x86_64"
# --runner: the days of every prepared match, outside Godot.
MATCH_CLI = ROOT / "bin" / ("match_sim_cli.exe" if IS_WINDOWS else "match_sim_cli")


def short(faction_id: str) -> str:
    return faction_id[len("faction_"):] if faction_id.startswith("faction_") else faction_id


def short_size(size: str) -> str:
    return size.replace("homm3_", "").replace("extra_large", "xl")


def size_class(text: str) -> str:
    name = {"xl": "extra_large"}.get(text, text)
    name = name if name.startswith("homm3_") else "homm3_" + name
    if name not in SIZES:
        raise argparse.ArgumentTypeError(f"size must be one of {', '.join(map(short_size, SIZES))}")
    return name


def faction_ids() -> list[str]:
    data = json.loads((ROOT / "content" / "factions.json").read_text(encoding="utf-8"))
    items = data["items"] if isinstance(data, dict) else data
    return sorted(item["id"] for item in items)


def git(*args: str) -> str:
    return subprocess.run(["git", "-C", str(ROOT), *args], capture_output=True, text=True).stdout.strip()


# ---------------------------------------------------------------- one match record

def summarize_record(r: dict) -> dict:
    """The fixed summary of one ai_versus_ai_match_report record. last_day_standing is the last
    day a player held a town or a hero; for the winner it is the final day. Battles are logged
    from the attacker's side, so few lost battles is normal."""
    st = r["setup"]
    ledger = r["ledger"]
    captures = [e for e in r["timeline"] if e["type"] == "town_captured"]
    battles = r["battles"]
    return {
        "match_seed": st["match_seed"],
        "map_seed": st["map_seed"],
        "map_size": "%dx%d" % (st["map_size"].get("x", 0), st["map_size"].get("y", 0)),
        "guards": st.get("guards", "weak (runner had no option)"),
        "water": st.get("water", "land"),
        "levels": st.get("levels", 1),
        "towns_on_map": len(r.get("town_weeks", [{"towns": []}])[0]["towns"]),
        "factions": {s["player_id"]: s["faction"] for s in st["seats"]},
        "faction_ids": {s["player_id"]: s["faction_id"] for s in st["seats"]},
        "winner": r["winner"] or "none (day cap)",
        "winner_faction": next((s["faction"] for s in st["seats"] if s["player_id"] == r["winner"]), ""),
        "final_day": r["final_day"],
        "slowest_ai_day_ms": r["ai_turn_ms_max"],
        "battles": len(battles),
        "battles_lost": sum(1 for b in battles if b["result"] != "won"),
        "battle_kinds": dict(Counter(b["defender_kind"] for b in battles)),
        "town_captures": len(captures),
        "captures_of_neutral_towns": sum(1 for e in captures if e["from"] == "neutral"),
        "captures_without_defender": sum(1 for e in captures if e["from"] != "neutral" and e["garrison_power"] <= 0),
        "last_day_standing": {p: max([row["day"] for row in ledger if row["sides"][p]["towns"] > 0 or row["sides"][p]["heroes"]] + [0]) for p in ledger[0]["sides"]},
        "final_sides": {p: {"towns": s["towns"], "heroes": len(s["heroes"]), "hero_strength": round(s["hero_power"]), "garrison_strength": round(s["garrison_power"]), "gold": s["treasury"].get("gold", 0), "sites": s["sites"]} for p, s in ledger[-1]["sides"].items()},
    }


# ---------------------------------------------------------------- plan

def balanced_lineups(ids: list[str], players: int, matches: int, rng: random.Random) -> list[list[str]]:
    if players > len(ids):
        sys.exit(f"{players} players need repeated factions; use --lineups mirrors")
    sets = list(itertools.combinations(ids, players))
    rng.shuffle(sets)
    uses: Counter = Counter()
    seats: Counter = Counter()
    lineups: list[list[str]] = []
    while len(lineups) < matches:
        # Every set once before any repeats; among those, the one whose factions have played least.
        pick = min(sets, key=lambda s: (uses[s], sum(seats[f] for f in s)))
        uses[pick] += 1
        order = list(pick)
        rng.shuffle(order)
        for i in range(min(players, matches - len(lineups))):
            lineup = order[i:] + order[:i]
            lineups.append(lineup)
            seats.update(lineup)
    return lineups


def random_lineups(ids: list[str], players: int, matches: int, rng: random.Random, mirrors: bool) -> list[list[str]]:
    if mirrors or players > len(ids):
        return [[rng.choice(ids) for _ in range(players)] for _ in range(matches)]
    sets = list(itertools.combinations(ids, players))
    rng.shuffle(sets)
    lineups = [list(sets[i % len(sets)]) for i in range(matches)]
    for lineup in lineups:
        rng.shuffle(lineup)
    return lineups


def fixed_lineups(texts: list[str], ids: list[str], players: int, matches: int) -> list[list[str]]:
    lineups = []
    for text in texts:
        lineup = [f if f.startswith("faction_") else "faction_" + f for f in (x.strip() for x in text.split(",")) if f]
        unknown = [f for f in lineup if f not in ids]
        if unknown:
            sys.exit(f"unknown factions {', '.join(unknown)}; known: {', '.join(map(short, ids))}")
        if len(lineup) == players:
            lineups.append(lineup)
    if not lineups:
        sys.exit(f"no --lineup has {players} factions")
    return [lineups[i % len(lineups)] for i in range(matches)]


def make_plan(args: argparse.Namespace, groups: list[tuple[int, str, int]]) -> dict:
    ids = faction_ids()
    plan_seed = args.seed if args.seed is not None else random.SystemRandom().randrange(1, 2**31)
    rng = random.Random(plan_seed)
    combos = list(itertools.product(args.guards, args.levels, args.water))
    if args.rotate:
        return rotated_plan(args, groups, ids, plan_seed, rng, combos)
    rows = []
    for players, size, matches in groups:
        if args.lineup:
            lineups = fixed_lineups(args.lineup, ids, players, matches)
        elif args.lineups == "balanced":
            lineups = balanced_lineups(ids, players, matches, rng)
        else:
            lineups = random_lineups(ids, players, matches, rng, args.lineups == "mirrors")
        # Consecutive line-ups are one set's rotations, so they get different setups.
        offset = rng.randrange(len(combos))
        for k, lineup in enumerate(lineups):
            guards, levels, water = combos[(k + offset) % len(combos)]
            rows.append({"players": players, "size": size, "guards": guards, "levels": levels, "water": water, "factions": lineup})
            if args.weights:
                rows[-1]["weights"] = args.weights
    rng.shuffle(rows)
    seeds: set[str] = set()
    matches_out = []
    for i, row in enumerate(rows):
        seed = f"ai-match-{rng.randrange(1, 2**32)}"
        while seed in seeds:
            seed = f"ai-match-{rng.randrange(1, 2**32)}"
        seeds.add(seed)
        matches_out.append({"run": f"m{i + 1:03d}", "seed": seed, **row})
    return plan_record(args, groups, plan_seed, matches_out)


def rotated_plan(args: argparse.Namespace, groups: list[tuple[int, str, int]], ids: list[str], plan_seed: int,
                 rng: random.Random, combos: list[tuple]) -> dict:
    """--rotate: one map per line-up, played once with the line-up in every seat rotation (seat 1
    first, then seat 2 first, ...): the matches of a map share its seed and setup, and the generator
    gives each seat its faction on the same terrain and objects."""
    maps = []
    for players, size, matches in groups:
        count = math.ceil(matches / players)
        if args.lineup:
            lineups = fixed_lineups(args.lineup, ids, players, count)
        elif args.lineups == "balanced":
            # Consecutive line-ups of balanced_lineups are one set's rotations: keep each set's first.
            lineups = balanced_lineups(ids, players, count * players, rng)[::players]
        else:
            lineups = random_lineups(ids, players, count, rng, args.lineups == "mirrors")
        offset = rng.randrange(len(combos))
        for k, lineup in enumerate(lineups):
            guards, levels, water = combos[(k + offset) % len(combos)]
            row = {"players": players, "size": size, "guards": guards, "levels": levels, "water": water}
            if args.weights:
                row["weights"] = args.weights
            maps.append([dict(row, factions=lineup[r:] + lineup[:r], rotation=r) for r in range(players)])
    rng.shuffle(maps)
    seeds: set[str] = set()
    matches_out = []
    for rows in maps:
        seed = f"ai-match-{rng.randrange(1, 2**32)}"
        while seed in seeds:
            seed = f"ai-match-{rng.randrange(1, 2**32)}"
        seeds.add(seed)
        for row in rows:
            matches_out.append({"run": f"m{len(matches_out) + 1:03d}", "seed": seed, **row})
    return plan_record(args, groups, plan_seed, matches_out)


def plan_record(args: argparse.Namespace, groups: list[tuple[int, str, int]], plan_seed: int, matches_out: list[dict]) -> dict:
    return {
        "schema": "ai_match_batch_plan_v1",
        "created": time.strftime("%Y-%m-%d %H:%M:%S"),
        "commit": git("rev-parse", "HEAD"),
        "dirty": bool(git("status", "--porcelain", "--untracked-files=no")),
        "plan_seed": plan_seed,
        "days": args.days,
        "build": "release" if args.release else "runner" if args.runner else "editor",
        "lineups": "fixed" if args.lineup else args.lineups,
        "rotate": bool(args.rotate),
        "groups": [{"players": p, "size": s, "matches": n} for p, s, n in groups],
        # Map packages already there are never deleted, even if a match writes the same name.
        "maps_before": sorted(p.name for p in MAPS_DIR.iterdir()) if MAPS_DIR.is_dir() else [],
        "matches": matches_out,
    }


def plan_digest(plan: dict) -> str:
    matches = plan["matches"]
    seats = Counter(short(f) for m in matches for f in m["factions"])
    first = Counter(short(m["factions"][0]) for m in matches)
    setups = Counter(f"{m['players']}P {short_size(m['size'])} {m['guards']} {m['water']} L{m['levels']}" for m in matches)
    return (f"games per faction {dict(sorted(seats.items()))}; first seat {dict(sorted(first.items()))}; "
            f"setups {dict(sorted(setups.items()))}")


# ---------------------------------------------------------------- processes

def godot_processes() -> dict[int, str]:
    """Running Godot processes, pid -> image name."""
    found: dict[int, str] = {}
    if IS_WINDOWS:
        out = subprocess.run(["tasklist", "/FO", "CSV", "/NH"], capture_output=True, text=True, errors="replace").stdout
        for row in csv.reader(io.StringIO(out)):
            if len(row) > 1 and row[0].lower().startswith(("godot", "heroes-like")) and row[1].isdigit():
                found[int(row[1])] = row[0]
    else:
        out = subprocess.run(["ps", "-eo", "pid=,comm="], capture_output=True, text=True, errors="replace").stdout
        for line in out.splitlines():
            pid, _, name = line.strip().partition(" ")
            if pid.isdigit() and ("godot" in name.lower() or name.lower().startswith("heroes-like")):
                found[int(pid)] = name.strip()
    return found


def count_games(processes: dict[int, str]) -> int:
    # The Windows console builds run each game as a wrapper plus the game process.
    return sum(1 for name in processes.values() if "_console" not in name.lower() and ".console" not in name.lower())


def kill(proc: subprocess.Popen) -> None:
    if proc.poll() is None:
        if IS_WINDOWS:
            subprocess.run(["taskkill", "/PID", str(proc.pid), "/T", "/F"], capture_output=True)
        else:
            try:
                os.killpg(proc.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
    try:
        proc.wait(30)
    except subprocess.TimeoutExpired:
        pass


@dataclass
class Running:
    matches: list[dict]
    proc: subprocess.Popen
    log: IO[str]
    log_path: Path
    profile: str
    started: float
    deadline: float


def export_batch_game(godot: str, dest: Path, templates: str | None) -> str:
    """Export the AI batch preset with the release template into dest; returns the binary to run."""
    version = ".".join(subprocess.run([godot, "--version"], capture_output=True, text=True).stdout.strip().split(".")[:4])  # "4.6.2.stable"
    if templates:
        source = Path(templates)
    elif IS_WINDOWS:
        source = Path(os.environ.get("APPDATA", "")) / "Godot" / "export_templates" / version
    else:
        source = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local" / "share")) / "godot" / "export_templates" / version
    needed = "windows_release_x86_64.exe" if IS_WINDOWS else "linux_release.x86_64"
    if not (source / needed).exists():
        sys.exit(f"--release needs the Godot {version} export templates: no {needed} in {source} "
                 "(install them in the editor, Manage Export Templates, or pass --templates DIR)")
    # A copy, so deleting the throwaway profile can never reach the real templates.
    profile = Path(tempfile.mkdtemp(prefix="heroes-ai-export-"))
    shutil.copytree(source, profile / ("Godot" if IS_WINDOWS else "godot") / "export_templates" / version)
    shutil.rmtree(dest, ignore_errors=True)
    dest.mkdir(parents=True)
    binary = dest / ("heroes-like.exe" if IS_WINDOWS else "heroes-like.x86_64")
    env = {**os.environ, "APPDATA": str(profile), "XDG_DATA_HOME": str(profile), "XDG_CONFIG_HOME": str(profile)}
    started = time.time()
    done = subprocess.run([godot, "--headless", "--path", str(ROOT), "--export-release", BATCH_PRESET, str(binary)],
                          env=env, capture_output=True, text=True, errors="replace")
    shutil.rmtree(profile, ignore_errors=True)
    if done.returncode != 0 or not (dest / GAME_BINARY).exists():
        sys.exit(f"export of {BATCH_PRESET} failed (exit {done.returncode}): {(done.stdout + done.stderr)[-1500:]}")
    print(f"EXPORTED {BATCH_PRESET} to {dest} in {time.time() - started:.0f} s", flush=True)
    return str(dest / GAME_BINARY)


def match_settings(out: Path, m: dict, days: int) -> dict[str, str]:
    settings = {
        "HEROES_AI_MATCH_SEED": m["seed"],
        "HEROES_AI_MATCH_PLAYERS": str(m["players"]),
        "HEROES_AI_MATCH_SIZE": m["size"],
        "HEROES_AI_MATCH_FACTIONS": ",".join(m["factions"]),
        "HEROES_AI_MATCH_GUARDS": m["guards"],
        "HEROES_AI_MATCH_WATER": m["water"],
        "HEROES_AI_MATCH_LEVELS": str(m["levels"]),
        "HEROES_AI_MATCH_MAX_DAYS": str(days),
        "HEROES_AI_MATCH_OUT": (out / f"{m['run']}.json").as_posix(),
    }
    if m.get("weights"):
        settings["HEROES_AI_MATCH_WEIGHTS"] = ",".join(m["weights"])
    return settings


def launch(godot: str, out: Path, matches: list[dict], days: int, timeout_min: float, game: str | None = None,
           corpus: Path | None = None, prepare: Path | None = None) -> Running:
    """One Godot process for the matches, played in order (one match: its settings in the environment;
    more: a match list, HEROES_AI_MATCH_LIST); with prepare (--runner), set up and written there instead."""
    first = matches[0]["run"]
    profile = tempfile.mkdtemp(prefix=f"heroes-ai-{first}-")
    env = {k: v for k, v in os.environ.items() if not k.startswith("HEROES_AI_MATCH_")}
    env.update({
        "APPDATA": profile,  # Windows user data: never the owner's saves
        "XDG_DATA_HOME": profile,  # Linux user data
        "XDG_CONFIG_HOME": profile,
    })
    if corpus:
        env["HEROES_AI_MATCH_MAP_CORPUS"] = corpus.as_posix()
    for m in matches:
        (out / f"{m['run']}.json").unlink(missing_ok=True)
    settings = [match_settings(out, m, days) for m in matches]
    if prepare:
        for s, m in zip(settings, matches):
            s["HEROES_AI_MATCH_PREPARE"] = (prepare / f"{m['run']}.snap").as_posix()
    if len(matches) == 1:
        env.update(settings[0])
        log_path = out / f"{first}.log"
    else:
        list_path = out / f"{first}.list.json"
        list_path.write_text(json.dumps(settings, indent=1), encoding="utf-8")
        env["HEROES_AI_MATCH_LIST"] = str(list_path)
        log_path = out / f"{first}.process.log"
    log = open(log_path, "w", encoding="utf-8", errors="replace")
    if game:
        cmd = [game, "--headless", "--audio-driver", "Dummy"]  # the batch preset starts the match runner
    else:
        cmd = [godot, "--headless", "--path", str(ROOT), "--audio-driver", "Dummy", SCENE]
    extra = {} if IS_WINDOWS else {"start_new_session": True}
    proc = subprocess.Popen(cmd, env=env, stdout=log, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL, **extra)
    now = time.time()
    return Running(matches, proc, log, log_path, profile, now, now + timeout_min * 60)


def remove_match_maps(scenario_id: str, since: float, keep: set[str], maps_dir: Path = MAPS_DIR) -> list[str]:
    """Delete the package pair one match wrote under res://maps: the .ascenario naming its
    scenario, written since the match started, and its .amap. Files in `keep` stay."""
    removed: list[str] = []
    if not scenario_id or not maps_dir.is_dir():
        return removed
    needle = re.compile(r'"scenario_id":\s*"%s"' % re.escape(scenario_id))
    for scenario in maps_dir.glob("*.ascenario"):
        try:
            if scenario.name in keep or scenario.stat().st_mtime < since - 2:
                continue
            if not needle.search(scenario.read_text(encoding="utf-8", errors="replace")):
                continue
        except OSError:
            continue
        for path in (scenario, scenario.with_suffix(".amap")):
            if path.exists() and path.name not in keep and path.stat().st_mtime >= since - 2:
                path.unlink()
                removed.append(path.name)
    return removed


def split_match_log(text: str) -> tuple[list[str], list[tuple[str, list[str]]]]:
    """A match list's log (HEROES_AI_MATCH_LIST): the lines before the first match, and per match in
    the order played, its record path (from its BEGIN line) and its lines."""
    preamble: list[str] = []
    sections: list[tuple[str, list[str]]] = []
    for line in text.splitlines():
        if line.startswith(BEGIN_ID + " "):
            try:
                out = str(json.loads(line[len(BEGIN_ID) + 1:]).get("out", ""))
            except ValueError:
                out = ""
            sections.append((out, [line]))
        elif sections:
            sections[-1][1].append(line)
        else:
            preamble.append(line)
    return preamble, sections


def finish(out: Path, run: Running, timed_out: bool, keep_maps: set[str]) -> tuple[list[dict], list[dict]]:
    """A row per match the process began, and the matches it never began (an earlier one crashed or
    timed out), which go back into the queue. A process that began none fails its first match."""
    parts, clocks = process_parts(out, run)
    rows = [match_row(out, m, part, run, timed_out and index == len(parts) - 1, *clocks[index], keep_maps)
            for index, (m, part) in enumerate(parts)]
    return rows, run.matches[len(parts):]


def finish_prepare(out: Path, run: Running, timed_out: bool, keep_maps: set[str]) -> tuple[list[dict], list[dict], list[dict]]:
    """A prepare process (--runner): the matches it wrote, each with its log and setup time; a failed row per
    match it began and did not write; and the matches it never began. The map packages it wrote go now."""
    parts, clocks = process_parts(out, run)
    prepared, rows = [], []
    for index, (m, part) in enumerate(parts):
        report = report_of(part)
        if report.get("ok") and report.get("prepared"):
            remove_match_maps(str(report.get("scenario_id", "")), run.started, keep_maps)
            (out / f"{m['run']}.log").unlink(missing_ok=True)
            prepared.append({"m": m, "snapshot": Path(report["prepared"]), "text": part, "seconds": clocks[index][1] - clocks[index][0],
                             "process": run.matches[0]["run"]})
        else:
            rows.append(match_row(out, m, part, run, timed_out and index == len(parts) - 1, *clocks[index], keep_maps))
    return rows, prepared, run.matches[len(parts):]


def process_parts(out: Path, run: Running) -> tuple[list[tuple[dict, str]], list[tuple[float, float]]]:
    """Each match the process began with its part of the log (written to OUT/<run>.log), and when it started
    and ended."""
    run.log.close()
    text = run.log_path.read_text(encoding="utf-8", errors="replace") if run.log_path.exists() else ""
    if len(run.matches) == 1:
        parts = [(run.matches[0], text)]
    else:
        preamble, sections = split_match_log(text)
        parts = []
        for index, m in enumerate(run.matches[:max(1, len(sections))]):
            part = "\n".join(preamble + (sections[index][1] if index < len(sections) else [])) + "\n"
            (out / f"{m['run']}.log").write_text(part, encoding="utf-8")
            parts.append((m, part))
        run.log_path.unlink(missing_ok=True)
        (out / f"{run.matches[0]['run']}.list.json").unlink(missing_ok=True)
    shutil.rmtree(run.profile, ignore_errors=True)
    # The runner times each match; the first one also gets the process's start-up and exit, and a
    # match with no report ran until the process ended.
    seconds = [report_of(part).get("seconds") for _, part in parts]
    if None not in seconds:
        seconds[0] += time.time() - run.started - sum(seconds)
    clocks = []
    clock = run.started
    for index in range(len(parts)):
        ended = clock + seconds[index] if seconds[index] is not None else time.time()
        clocks.append((clock, ended))
        clock = ended
    return parts, clocks


def report_of(text: str) -> dict:
    report: dict = {}
    for line in text.splitlines():
        if line.startswith(REPORT_ID + " "):
            try:
                report = json.loads(line[len(REPORT_ID) + 1:])
            except ValueError:
                pass
    return report


def match_row(out: Path, m: dict, text: str, run: Running, timed_out: bool, started: float, ended: float, keep_maps: set[str]) -> dict:
    log_path = out / f"{m['run']}.log"
    record_path = out / f"{m['run']}.json"
    report = report_of(text)
    errors = [line.strip() for line in text.splitlines() if "SCRIPT ERROR" in line][:5]
    # "NATIVE FALLBACK: <entry> ran in GDScript, not ported: <path>", one line per native call
    # (one a day for EnemyTurnRules.run_enemy_turn).
    fallbacks: Counter = Counter()
    for line in text.splitlines():
        if line.startswith(FALLBACK_MARK):
            entry, _, path = line[len(FALLBACK_MARK):].partition(" ran in GDScript, not ported: ")
            fallbacks[f"{entry} <- {path.strip()[:120]}"] += 1
    summary = None
    problem = ""
    removed: list[str] = []
    if report.get("ok") and record_path.exists():
        try:
            record = json.loads(record_path.read_text(encoding="utf-8"))
            summary = summarize_record(record)
            removed = remove_match_maps(str(record["setup"].get("scenario_id", "")), run.started, keep_maps)
        except (ValueError, KeyError, IndexError) as exc:
            problem = f"record unreadable: {exc!r}"
    elif report.get("error"):
        problem = str(report["error"])
    elif timed_out:
        problem = f"timed out after {(run.deadline - run.started) / 60:g} min" + (f" (a process of {len(run.matches)} matches)" if len(run.matches) > 1 else "")
    else:
        tail = " | ".join(line.strip() for line in text.splitlines()[-3:])
        problem = f"exit {run.proc.returncode}, no report line: {tail}"
    keep_log = bool(errors) or summary is None
    if not keep_log:
        log_path.unlink(missing_ok=True)
    return {
        **m,
        "status": "ok" if summary else ("timeout" if timed_out else "failed"),
        "exit": run.proc.returncode,
        "minutes": round((ended - started) / 60, 1),
        "started": round(started),
        "ended": round(ended),
        "process": run.matches[0]["run"],
        "map": report.get("map", ""),  # generated, reused, corpus or kept
        "script_errors": errors,
        "native_fallbacks": dict(fallbacks),
        "problem": problem,
        "log": log_path.name if keep_log else "",
        "maps_removed": removed,
        "summary": summary,
    }


# ---------------------------------------------------------------- run

def expected_cost(m: dict) -> tuple[int, int, int]:
    return (m["levels"], SIZES.index(m["size"]), m["players"])


def match_text(m: dict) -> str:
    return (f"{m['run']} {m['players']}P {short_size(m['size'])} L{m['levels']} {m['guards']} {m['water']} "
            f"{','.join(short(f) for f in m['factions'])}")


def result_text(row: dict) -> str:
    s = row["summary"]
    if not s:
        return f"{row['status'].upper()}: {row['problem'][:120]}"
    winner = s["faction_ids"].get(s["winner"])
    outcome = f"{short(winner)} day {s['final_day']}" if winner else f"no winner by day {s['final_day']}"
    return outcome + (f", {len(row['script_errors'])} script errors" if row["script_errors"] else "")


def read_results(out: Path) -> list[dict]:
    path = out / "results.jsonl"
    if not path.exists():
        return []
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


class Output:
    def __init__(self, out: Path):
        self.file = open(out / "runner.log", "a", encoding="utf-8")

    def __call__(self, text: str) -> None:
        print(text, flush=True)
        self.file.write(text + "\n")
        self.file.flush()


def run_batch(out: Path, plan: dict, godot: str, slots: int, timeout_override: float | None, game: str | None = None,
              per_process: int = 4, corpus: Path | None = None, runner: bool = False) -> int:
    say = Output(out)
    done = {row["run"] for row in read_results(out)}
    queue = sorted((m for m in plan["matches"] if m["run"] not in done), key=expected_cost, reverse=True)
    # --runner: match_sim_cli generates the matches' maps and plays them; the Godot processes prepare only
    # the matches it cannot generate (snapshots written whole, so one there from an interrupted batch is
    # ready), and it plays all of them once those are prepared.
    snapshots = out / "snapshots" if runner else None
    prepared: list[dict] = []
    if snapshots:
        snapshots.mkdir(exist_ok=True)
        for m in list(queue):
            if (snapshots / f"{m['run']}.snap").exists():
                queue.remove(m)
                prepared.append({"m": m, "snapshot": snapshots / f"{m['run']}.snap", "text": "", "seconds": 0.0, "process": ""})
            elif not corpus and not any(w.endswith(".json") for w in m.get("weights", [])):
                queue.remove(m)
                prepared.append({"m": m, "snapshot": None, "text": "", "seconds": 0.0, "process": ""})
    total = len(plan["matches"])
    finished = len(done)
    others = count_games(godot_processes())
    if others:
        lowered = max(1, slots - others)
        say(f"WARNING: {others} other Godot games or editors are running; using {lowered} slots instead of {slots}")
        slots = lowered
    keep_maps = set(plan.get("maps_before", []))
    running: dict[str, Running] = {}
    inflight_path = out / "inflight.json"
    started = time.time()
    say(f"START {len(queue) + len(prepared)} of {total} matches on {plan['commit'][:9]}{' (dirty tree)' if plan.get('dirty') else ''}, "
        f"{slots} processes at a time, up to {per_process} matches each{' on the release build' if game else ''}"
        f"{f', played in bin/match_sim_cli on {slots} threads ({len(queue)} set up in Godot first)' if runner else ''}, "
        f"at {time.strftime('%H:%M:%S')}")

    def save_inflight() -> None:
        inflight_path.write_text(json.dumps({m["run"]: x.proc.pid for x in running.values() for m in x.matches}), encoding="utf-8")

    def on_term(signum, frame):
        raise KeyboardInterrupt
    signal.signal(signal.SIGTERM, on_term)
    try:
        while queue or running:
            seeds = {m["seed"] for x in running.values() for m in x.matches}
            while len(running) < slots:
                # Never two processes with one seed at once: they would share a map package. A process
                # takes as many matches as spread what is left evenly over the slots, up to per_process,
                # in whole seeds (all the queued matches of a seed, one after another, so a rotated map
                # is generated once), and always at least one seed.
                want = min(per_process, max(1, math.ceil(len(queue) / slots)))
                by_seed: dict[str, list[dict]] = {}
                for m in queue:
                    if m["seed"] not in seeds:
                        by_seed.setdefault(m["seed"], []).append(m)
                chain: list[dict] = []
                for group in by_seed.values():
                    if chain and len(chain) + len(group) > want:
                        continue
                    chain += group
                    if len(chain) >= want:
                        break
                if not chain:
                    break
                for m in chain:
                    queue.remove(m)
                seeds |= {m["seed"] for m in chain}
                timeout_min = sum(timeout_override or TIMEOUT_MIN[m["size"]] for m in chain)
                running[chain[0]["run"]] = launch(godot, out, chain, plan["days"], timeout_min, game, corpus, snapshots)
                save_inflight()
            time.sleep(2)
            for name, x in list(running.items()):
                timed_out = x.proc.poll() is None and time.time() > x.deadline
                if timed_out:
                    kill(x.proc)
                if x.proc.poll() is None:
                    continue
                del running[name]
                if snapshots:
                    rows, ready, unplayed = finish_prepare(out, x, timed_out, keep_maps)
                    prepared += ready
                else:
                    rows, unplayed = finish(out, x, timed_out, keep_maps)
                queue = sorted(queue + unplayed, key=expected_cost, reverse=True)
                for row in rows:
                    finished += 1
                    write_row(out, row, slots, say, f"{finished}/{total}, {len(running)} running")
                if snapshots and not rows:
                    say(f"  set up {', '.join(m['run'] for m in x.matches[:len(x.matches) - len(unplayed)])} [{len(prepared)} ready, {len(running)} running]")
                if unplayed:
                    say(f"  {len(unplayed)} matches of that process were never begun, back in the queue: {', '.join(m['run'] for m in unplayed)}")
                save_inflight()
        if snapshots and prepared:
            finished = play_prepared(out, plan, godot, prepared, slots, timeout_override, keep_maps, say, finished, total)
            shutil.rmtree(snapshots, ignore_errors=True)
    except KeyboardInterrupt:
        for x in running.values():
            kill(x.proc)
            x.log.close()
            shutil.rmtree(x.profile, ignore_errors=True)
            (out / f"{x.matches[0]['run']}.list.json").unlink(missing_ok=True)
        save_inflight()
        say(f"INTERRUPTED with {len(running)} matches in flight; finish with --resume (same commit)")
        write_summary(out, plan)
        return 130
    inflight_path.unlink(missing_ok=True)
    # A match that failed after generating its map leaves the package; no record names it.
    left = sorted(p.name for p in MAPS_DIR.iterdir() if p.suffix in (".amap", ".ascenario") and p.name not in keep_maps
                  and p.stat().st_mtime >= started - 2) if MAPS_DIR.is_dir() else []
    if left:
        say(f"WARNING: maps/ holds {len(left)} files written during the batch that no finished match names "
            f"(a failed match, or someone else's game): {', '.join(left)}")
    write_summary(out, plan)
    say(f"DONE {finished}/{total} in {(time.time() - started) / 60:.1f} min at {time.strftime('%H:%M:%S')}; read {out / 'summary.md'}")
    return 0


def write_row(out: Path, row: dict, slots: int, say, progress: str) -> None:
    row["slots"] = slots
    with open(out / "results.jsonl", "a", encoding="utf-8") as f:
        f.write(json.dumps(row) + "\n")
    say(f"{match_text(row)} -> {result_text(row)} ({row['minutes']} min) [{progress}]")


def write_content_snapshot(godot: str, path: Path) -> str:
    """--runner: the Godot match runner writes the content snapshot match_sim_cli generates the maps from
    (HEROES_AI_MATCH_CONTENT_SNAPSHOT); "" when written, else the end of its output."""
    profile = tempfile.mkdtemp(prefix="heroes-ai-content-")
    env = {k: v for k, v in os.environ.items() if not k.startswith("HEROES_AI_MATCH_")}
    env.update({"APPDATA": profile, "XDG_DATA_HOME": profile, "XDG_CONFIG_HOME": profile,
                "HEROES_AI_MATCH_CONTENT_SNAPSHOT": path.as_posix()})
    proc = subprocess.run([godot, "--headless", "--path", str(ROOT), "--audio-driver", "Dummy", SCENE], env=env,
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL, text=True, encoding="utf-8", errors="replace")
    shutil.rmtree(profile, ignore_errors=True)
    if proc.returncode == 0 and path.exists() and report_of(proc.stdout).get("ok"):
        return ""
    return f"the content snapshot was not written (exit {proc.returncode}): " + " | ".join(proc.stdout.splitlines()[-3:])


def play_prepared(out: Path, plan: dict, godot: str, prepared: list[dict], threads: int, timeout_override: float | None,
                  keep_maps: set[str], say, finished: int, total: int) -> int:
    """--runner: one bin/match_sim_cli process generates the matches without a snapshot from the content
    snapshot and plays them and the prepared ones, biggest first, on threads threads; each match's row is
    written as it ends (its log: the prepare's part and the play's). Returns the finished count."""
    order = sorted(prepared, key=lambda p: expected_cost(p["m"]), reverse=True)
    env = {k: v for k, v in os.environ.items() if not k.startswith("HEROES_AI_MATCH_")}
    if any(p["snapshot"] is None for p in order):
        content = out / "snapshots" / "content.snap"
        say(f"CONTENT snapshot for bin/match_sim_cli at {time.strftime('%H:%M:%S')}")
        error = write_content_snapshot(godot, content)
        if error:
            say(f"ERROR: {error}")
            for p in order:
                if p["snapshot"] is None:
                    m = p["m"]
                    text = f"{REPORT_ID} " + json.dumps({"ok": False, "out": (out / f"{m['run']}.json").as_posix(), "error": error}) + "\n"
                    (out / f"{m['run']}.log").write_text(text, encoding="utf-8")
                    now = time.time()
                    row = match_row(out, m, text, Running([m], subprocess.CompletedProcess([], 1), None, out / f"{m['run']}.log", "", now, now), False, now, now, keep_maps)
                    row["process"] = m["run"]
                    finished += 1
                    write_row(out, row, threads, say, f"{finished}/{total}")
            order = [p for p in order if p["snapshot"] is not None]
            if not order:
                return finished
        else:
            env["HEROES_AI_MATCH_CONTENT"] = content.as_posix()
    by_out = {(out / f"{p['m']['run']}.json").as_posix(): p for p in order}
    list_path = out / "play.list.json"
    list_path.write_text(json.dumps([{**match_settings(out, p["m"], plan["days"]),
                                      **({"HEROES_AI_MATCH_SNAPSHOT": p["snapshot"].as_posix()} if p["snapshot"] else {})}
                                     for p in order], indent=1), encoding="utf-8")
    for p in order:
        (out / f"{p['m']['run']}.json").unlink(missing_ok=True)
    env["HEROES_AI_MATCH_LIST"] = str(list_path)
    threads = max(1, min(threads, len(order)))
    say(f"PLAY {len(order)} matches in bin/match_sim_cli on {threads} threads at {time.strftime('%H:%M:%S')}")
    timeouts = [timeout_override or TIMEOUT_MIN[p["m"]["size"]] for p in order]
    limit = (sum(timeouts) / threads + max(timeouts)) * 60
    extra = {} if IS_WINDOWS else {"start_new_session": True}
    proc = subprocess.Popen([str(MATCH_CLI), "--threads", str(threads)], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            stdin=subprocess.DEVNULL, text=True, encoding="utf-8", errors="replace", **extra)
    fired = threading.Event()
    timer = threading.Timer(limit, lambda: (fired.set(), kill(proc)))
    timer.start()
    reported: set[str] = set()
    block: list[str] = []
    current = None
    tail: list[str] = []
    try:
        for line in proc.stdout:
            line = line.rstrip("\n")
            if line.startswith(BEGIN_ID + " "):
                try:
                    current = by_out.get(str(json.loads(line[len(BEGIN_ID) + 1:]).get("out", "")))
                except ValueError:
                    current = None
                block = [line]
                continue
            block.append(line)
            if current is None:
                tail.append(line)
                continue
            if line.startswith(REPORT_ID + " "):
                m = current["m"]
                text = current["text"] + "\n".join(block) + "\n"
                (out / f"{m['run']}.log").write_text(text, encoding="utf-8")
                ended = time.time()
                started = ended - current["seconds"] - float(report_of(line).get("seconds") or 0.0)
                run = Running([m], proc, None, out / f"{m['run']}.log", "", started, ended)
                row = match_row(out, m, text, run, False, started, ended, keep_maps)
                row["process"] = current["process"] or m["run"]
                finished += 1
                reported.add(m["run"])
                write_row(out, row, threads, say, f"{finished}/{total}, {len(order) - len(reported)} playing")
                if current["snapshot"]:
                    current["snapshot"].unlink(missing_ok=True)
                current = None
    finally:
        timer.cancel()
        proc.wait()
        list_path.unlink(missing_ok=True)
    timed_out = fired.is_set()
    for p in order:
        m = p["m"]
        if m["run"] in reported:
            continue
        text = p["text"] + "\n".join(tail[-3:]) + "\n"
        (out / f"{m['run']}.log").write_text(text, encoding="utf-8")
        run = Running([m], proc, None, out / f"{m['run']}.log", "", time.time() - limit, time.time())
        row = match_row(out, m, text, run, timed_out, run.started, run.deadline, keep_maps)
        row["process"] = p["process"] or m["run"]
        finished += 1
        write_row(out, row, threads, say, f"{finished}/{total}")
    say(f"PLAYED in bin/match_sim_cli: {' '.join(line for line in tail if line.startswith('MATCH_SIM_CLI '))[:400]}")
    return finished


# ---------------------------------------------------------------- summary

def place_points(s: dict) -> dict[str, float]:
    """Points by finishing place, 3-2-1-0 for four players (players - 1 down to 0): later
    elimination places higher, the winner first; players out on the same day, or standing at
    the day cap, share their places' points."""
    standing = s["last_day_standing"]
    key = {p: (p == s["winner"], day) for p, day in standing.items()}
    order = sorted(standing, key=lambda p: key[p], reverse=True)
    n = len(order)
    points: dict[str, float] = {}
    i = 0
    while i < n:
        j = i
        while j < n and key[order[j]] == key[order[i]]:
            j += 1
        share = sum(n - 1 - k for k in range(i, j)) / (j - i)
        for p in order[i:j]:
            points[p] = share
        i = j
    return points


def ratio(observed: float, expected: float, variance: float) -> tuple[float, float]:
    return (observed / expected, math.sqrt(variance) / expected) if expected else (0.0, 0.0)


def band(r: float, sd: float) -> str:
    flag = " *" if sd and abs(r - 1) > 2 * sd else ""
    return f"{r:.2f} ±{sd:.2f}{flag}"


def faction_table(rows: list[dict]) -> list[str]:
    stats: dict[str, list[float]] = defaultdict(lambda: [0, 0.0, 0.0, 0.0, 0, 0.0, 0.0])
    for row in rows:
        s = row["summary"]
        n = len(s["faction_ids"])
        decided = s["winner"] in s["faction_ids"]
        points = place_points(s)
        for pid, fid in s["faction_ids"].items():
            st = stats[short(fid)]
            st[0] += 1  # games
            st[1] += points[pid]  # place points
            st[2] += (n - 1) / 2  # fair share of points
            st[3] += (n * n - 1) / 12  # their variance if all factions were equal
            if decided:
                st[4] += pid == s["winner"]  # wins
                st[5] += 1 / n  # fair share of wins
                st[6] += (1 / n) * (1 - 1 / n)
    lines = ["| Faction | Games | Place points (fair) | Places / fair | Wins (fair) | Wins / fair |", "|---|---|---|---|---|---|"]
    for faction, (games, pts, fair, var, wins, fair_wins, var_wins) in sorted(stats.items(), key=lambda kv: -kv[1][1] / max(kv[1][2], 1e-9)):
        lines.append(f"| {faction} | {games} | {pts:g} ({fair:g}) | {band(*ratio(pts, fair, var))} | "
                     f"{wins} ({fair_wins:.1f}) | {band(*ratio(wins, fair_wins, var_wins))} |")
    return lines


def duration(minutes: float) -> str:
    return f"{minutes:.0f} min" if minutes < 90 else f"{minutes / 60:.1f} h"


def write_summary(out: Path, plan: dict) -> None:
    rows = read_results(out)
    by_run = {row["run"]: row for row in rows}
    ok = [row for row in rows if row["summary"]]
    decided = [row for row in ok if row["summary"]["winner"] in row["summary"]["faction_ids"]]
    capped = [row for row in ok if row not in decided]
    failed = [row for row in rows if not row["summary"]]
    groups = ", ".join(f"{g['players']}P {short_size(g['size'])} x{g['matches']}" for g in plan["groups"])
    lines = [
        f"# AI match batch {out.name}",
        "",
        f"Commit {plan['commit'][:9]}{' (dirty tree)' if plan.get('dirty') else ''}, plan seed {plan['plan_seed']}, "
        f"line-ups {plan['lineups']}, day cap {plan['days']}{', release build' if plan.get('build') == 'release' else ''}"
        f"{', days in bin/match_sim_cli' if plan.get('build') == 'runner' else ''}: "
        f"{groups}.",
        f"{len(rows)} of {len(plan['matches'])} matches played: {len(decided)} decided, {len(capped)} at the day cap, "
        f"{len(failed)} failed or timed out.",
    ]
    if rows:
        wall = (max(r["ended"] for r in rows) - min(r["started"] for r in rows)) / 60
        lines.append(f"Wall {duration(wall)} (from the first start to the last end) at {rows[-1].get('slots', '?')} slots; "
                     f"{duration(sum(r['minutes'] for r in rows))} of match time.")
    lines += ["", "## Factions", "",
              "Place points by elimination order (3-2-1-0 with four players; ties share) and wins in decided games, "
              "each against a fair share, ±1 sd if all factions were equal; * marks a gap beyond 2 sd. "
              "Call a shift between batches real only beyond about 2 sd or when it repeats.", ""]
    lines += faction_table(ok) if ok else ["No finished matches."]
    if len(plan["groups"]) > 1:
        for g in plan["groups"]:
            part = [r for r in ok if r["players"] == g["players"] and r["size"] == g["size"]]
            if part:
                lines += ["", f"{g['players']}P {short_size(g['size'])}:", ""] + faction_table(part)

    lines += ["", "## Look closer", ""]
    if decided:
        days = sorted(r["summary"]["final_day"] for r in decided)
        lines.append(f"- Decided games end on days {days[0]}-{days[-1]} (median {statistics.median(days):g}).")
    for row in capped:
        lines.append(f"- Day cap: {row['run']} `{row['seed']}` {match_text(row)[len(row['run']) + 1:]}")
    for row in failed:
        lines.append(f"- {row['status'].upper()}: {row['run']} `{row['seed']}`: {row['problem'][:200]} (log {row['log'] or 'deleted'})")
    for row in rows:
        if row["script_errors"]:
            lines.append(f"- Script errors in {row['run']} `{row['seed']}` (log {row['log']}): {row['script_errors'][0][:200]}")
    fallbacks: Counter = Counter()
    for row in rows:
        fallbacks.update(row.get("native_fallbacks", {}))
    if fallbacks:
        games = sum(1 for row in rows if row.get("native_fallbacks"))
        lines.append(f"- Native calls run in GDScript instead (NATIVE FALLBACK): {sum(fallbacks.values())} in {games} games: "
                     + ", ".join(f"{key} {count}" for key, count in fallbacks.most_common()))
    elif rows:
        lines.append("- Native calls run in GDScript instead (NATIVE FALLBACK): none.")
    slow = sorted((r for r in ok if r["summary"]["slowest_ai_day_ms"] > SLOW_DAY_MS), key=lambda r: -r["summary"]["slowest_ai_day_ms"])
    if slow:
        worst = ", ".join(f"{r['run']} {r['summary']['slowest_ai_day_ms'] / 1000:.0f} s" for r in slow[:5])
        lines.append(f"- AI days over {SLOW_DAY_MS // 1000} s in {len(slow)} games: {worst}")
    if ok:
        undefended = sorted(ok, key=lambda r: -r["summary"]["captures_without_defender"])
        total = sum(r["summary"]["captures_without_defender"] for r in ok)
        lines.append(f"- Captures without a defender: {total} in {sum(1 for r in ok if r['summary']['captures_without_defender'])} games; most "
                     + ", ".join(f"{r['run']} {r['summary']['captures_without_defender']}" for r in undefended[:3]))
    if decided:
        gold = sorted(decided, key=lambda r: -r["summary"]["final_sides"][r["summary"]["winner"]]["gold"])
        golds = [r["summary"]["final_sides"][r["summary"]["winner"]]["gold"] for r in decided]
        lines.append(f"- Winner's gold at the end: median {statistics.median(golds):,.0f}; most "
                     + ", ".join(f"{r['run']} {r['summary']['final_sides'][r['summary']['winner']]['gold']:,}" for r in gold[:3]))
    if rows:
        times: dict[str, list[float]] = defaultdict(list)
        for r in rows:
            times[f"{r['players']}P {short_size(r['size'])} L{r['levels']}"].append(r["minutes"])
        lines.append("- Minutes per match: " + "; ".join(f"{k} mean {statistics.mean(v):.1f}, max {max(v):.1f} (n {len(v)})" for k, v in sorted(times.items())))

    lines += ["", "## Matches", "",
              "| # | Setup | Factions | Towns on map | Winner | Day | Captures (no defender) | Winner's gold at end |",
              "|---|---|---|---|---|---|---|---|"]
    for m in plan["matches"]:
        row = by_run.get(m["run"])
        if not row:
            continue
        setup = f"{m['players']}P {short_size(m['size'])} {m['guards']} {m['water']} L{m['levels']}"
        factions = ", ".join(short(f) for f in m["factions"])
        s = row["summary"]
        if not s:
            lines.append(f"| {m['run']} | {setup} | {factions} | | {row['status'].upper()} | | | |")
            continue
        winner = s["faction_ids"].get(s["winner"])
        gold = f"{s['final_sides'][s['winner']]['gold']:,}" if winner else ""
        lines.append(f"| {m['run']} | {setup} {s['map_size']} | {factions} | {s['towns_on_map']} | {short(winner) if winner else 'none (cap)'} | "
                     f"{s['final_day']} | {s['town_captures']} ({s['captures_without_defender']}) | {gold} |")
    (out / "summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


# ---------------------------------------------------------------- main

def map_corpus(folder: Path, plan: dict) -> Path:
    """The --map-corpus folder, made for the plan's commit or checked against it: the generator of
    another commit may make other maps from the same setup."""
    folder.mkdir(parents=True, exist_ok=True)
    stamp = folder / "corpus.json"
    if stamp.exists():
        made = json.loads(stamp.read_text(encoding="utf-8"))
        if made.get("commit") != plan["commit"]:
            sys.exit(f"--map-corpus {folder} holds maps of {str(made.get('commit'))[:9]}, not {plan['commit'][:9]}; use a new folder")
        if made.get("dirty") or plan.get("dirty"):
            print(f"WARNING: --map-corpus {folder} or this batch is from a tree with uncommitted changes; its maps may not match")
    else:
        stamp.write_text(json.dumps({"commit": plan["commit"], "dirty": plan.get("dirty", False),
                                     "created": time.strftime("%Y-%m-%d %H:%M:%S")}, indent=1), encoding="utf-8")
    return folder


def parse_groups(args: argparse.Namespace) -> list[tuple[int, str, int]]:
    if not args.group:
        return [(args.players, args.size, args.matches)]
    groups = []
    for text in args.group:
        try:
            players, size, matches = text.split(":")
            groups.append((int(players), size_class(size), int(matches)))
        except (ValueError, argparse.ArgumentTypeError):
            sys.exit(f"--group wants PLAYERS:SIZE:MATCHES, e.g. 4:large:60, got {text}")
    return groups


def csv_choice(values: tuple[str, ...]):
    def parse(text: str) -> list[str]:
        items = [x.strip() for x in text.split(",") if x.strip()]
        if not items or any(x not in values for x in items):
            raise argparse.ArgumentTypeError(f"comma-separated list of {', '.join(values)}")
        return items
    return parse


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("out", type=Path, help="batch folder (plan.json, results.jsonl, records, summary.md)")
    parser.add_argument("--players", type=int, default=3, help="computer players (default 3)")
    parser.add_argument("--size", type=size_class, default="homm3_medium", help="small, medium (default), large, xl")
    parser.add_argument("--matches", type=int, default=5, help="matches (default 5)")
    parser.add_argument("--group", action="append", metavar="PLAYERS:SIZE:MATCHES", help="several setups in one queue, e.g. --group 3:medium:30 --group 4:large:30")
    parser.add_argument("--guards", type=csv_choice(GUARDS), default=["normal"], help="weak,normal,strong (default normal)")
    parser.add_argument("--levels", type=csv_choice(("1", "2")), default=["1"], help="1,2 (default 1)")
    parser.add_argument("--water", type=csv_choice(WATER), default=["land"], help="land,normal_water,islands (default land)")
    parser.add_argument("--days", type=int, default=320, help="day cap (default 320)")
    parser.add_argument("--lineups", choices=("balanced", "random", "mirrors"), default="balanced")
    parser.add_argument("--lineup", action="append", metavar="F1,F2,...", help="fixed line-up, seat order; repeat for several (cycled)")
    parser.add_argument("--rotate", action="store_true", help="play each map with its line-up rotated through every seat (matches rounded up to a multiple of players)")
    parser.add_argument("--seed", type=int, help="plan seed (default random); the same seed and options give the same plan")
    parser.add_argument("--weights", metavar="W1,W2,...", help="overworld AI weight set per seat: default, a set name or a .json file")
    parser.add_argument("--slots", type=int, default=16, help="Godot processes at once (default 16)")
    parser.add_argument("--per-process", type=int, default=4, help="most matches one Godot process plays in a row (default 4)")
    parser.add_argument("--map-corpus", type=Path, help="folder of generated map packages kept for batches on the same plan (one commit)")
    parser.add_argument("--timeout-min", type=float, help="per-match timeout in minutes (default by size: %s)" % ", ".join(f"{short_size(k)} {v}" for k, v in TIMEOUT_MIN.items()))
    parser.add_argument("--godot", help="Godot editor binary")
    parser.add_argument("--release", action="store_true", help="export the AI batch preset with the release template into OUT/game and play on it")
    parser.add_argument("--templates", help="export templates folder for --release (default: the editor's own)")
    parser.add_argument("--runner", action="store_true", help="generate and play the matches in bin/match_sim_cli")
    parser.add_argument("--resume", action="store_true", help="play the matches plan.json still lacks (same commit only)")
    parser.add_argument("--summarize", action="store_true", help="only rewrite summary.md")
    parser.add_argument("--plan-only", action="store_true", help="write plan.json and stop")
    args = parser.parse_args()
    args.levels = [int(x) for x in args.levels]
    if args.runner and args.release:
        sys.exit("--runner takes its content from the editor's match runner; it takes no --release")

    out = args.out.resolve()
    plan_path = out / "plan.json"
    if args.summarize or args.resume:
        if not plan_path.exists():
            sys.exit(f"no plan.json in {out}")
        plan = json.loads(plan_path.read_text(encoding="utf-8"))
        if args.summarize:
            write_summary(out, plan)
            print(out / "summary.md")
            return 0
        head = git("rev-parse", "HEAD")
        if plan["commit"] != head:
            sys.exit(f"plan.json was made on {plan['commit'][:9]} but HEAD is {head[:9]}; a resumed batch must run on the same commit")
        inflight_path = out / "inflight.json"
        alive = godot_processes()
        if inflight_path.exists():
            leftover = {r: p for r, p in json.loads(inflight_path.read_text(encoding="utf-8")).items() if p in alive}
            if leftover:
                sys.exit(f"matches from the interrupted run are still running ({leftover}); stop them first")
    else:
        if plan_path.exists():
            sys.exit(f"{plan_path} exists; use --resume, --summarize or a new folder")
        groups = parse_groups(args)
        if args.weights:
            args.weights = [w.strip() or "default" for w in args.weights.split(",")]
            args.weights = [Path(w).resolve().as_posix() if w.endswith(".json") else w for w in args.weights]
            for w in args.weights:
                if w.endswith(".json") and not Path(w).is_file():
                    sys.exit(f"--weights: no file {w}")
            if any(players != len(args.weights) for players, _, _ in groups):
                sys.exit(f"--weights names {len(args.weights)} seats; every group needs that many players")
        for players, size, _ in groups:
            if players not in FITTING_PLAYERS[size]:
                print(f"WARNING: {short_size(size)} maps are played with {' or '.join(map(str, FITTING_PLAYERS[size]))} players, not {players}")
        out.mkdir(parents=True, exist_ok=True)
        plan = make_plan(args, groups)
        plan_path.write_text(json.dumps(plan, indent=1), encoding="utf-8")
        print(f"PLAN {len(plan['matches'])} matches, plan seed {plan['plan_seed']}: {plan_digest(plan)}", flush=True)
        if plan["dirty"]:
            print("WARNING: tracked files have uncommitted changes; the batch does not exactly match the commit")
        if args.plan_only:
            return 0
    godot = find_godot(args.godot)
    game = None
    if plan.get("build") == "release":
        game = str(out / "game" / GAME_BINARY)
        if not args.resume or not Path(game).exists():
            game = export_batch_game(godot, out / "game", args.templates)
    corpus = map_corpus(args.map_corpus.resolve(), plan) if args.map_corpus else None
    runner = plan.get("build") == "runner"
    if runner and not MATCH_CLI.exists():
        sys.exit(f"--runner needs {MATCH_CLI} (python tools/build_native.py windows --part rules)")
    code = run_batch(out, plan, godot, max(1, args.slots), args.timeout_min, game, max(1, args.per_process), corpus, runner)
    if game and code == 0:
        shutil.rmtree(out / "game", ignore_errors=True)  # about 5 GB; an interrupted batch keeps it for --resume
    return code


if __name__ == "__main__":
    sys.exit(main())
