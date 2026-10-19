#!/usr/bin/env python3
"""AI-vs-AI match batches: plan, play in parallel, summarize. Owner-requested evaluation only.

    python tools/ai_match_batch.py OUT --players 4 --size large --matches 60 --guards weak,normal,strong --levels 1,2
    python tools/ai_match_batch.py OUT --group 3:medium:30 --group 4:large:30
    python tools/ai_match_batch.py OUT --resume       # finish an interrupted batch (same commit only)
    python tools/ai_match_batch.py OUT --summarize    # rewrite summary.md from results.jsonl

Before anything runs, OUT gets plan.json: the commit, and per match an explicit seed, the setup
and the line-up. Each finished match appends one line to results.jsonl and prints one line (also
kept in runner.log); its full record is OUT/<run>.json, and its log is kept only when it failed or
printed script errors. summary.md comes last: a per-faction table (finishing places 3-2-1-0 and
wins against a fair share, with the noise band) and the per-match table.

Matches run headless with tests/ai_versus_ai_match_report.tscn, --slots at a time (default 16;
lowered when other Godot processes are already running) from one refilling queue: two-level maps
first, then larger maps, then more players. Each match gets a throwaway user profile (APPDATA on
Windows, XDG_DATA_HOME on Linux) and a timeout. Two matches with the same seed never run at once,
because both would write the same map package under res://maps; the package each match writes is
deleted when it ends.

Line-ups (--lineups): balanced (default) plays sets of factions in every seat rotation, each set
once before any repeats, picked so every faction gets an even share; random draws distinct sets;
mirrors lets a faction appear twice; --lineup fixes them. Guards, levels and water are crossed over
the line-ups. Windows and Linux; Godot comes from --godot, $GODOT_BIN, PATH or the owner's install.
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
from typing import IO

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from core_suite import find_godot  # noqa: E402

SCENE = "res://tests/ai_versus_ai_match_report.tscn"
REPORT_ID = "AI_VERSUS_AI_MATCH_REPORT"
MAPS_DIR = ROOT / "maps"
SIZES = ["homm3_small", "homm3_medium", "homm3_large", "homm3_extra_large"]
# Player counts each size is played with (owner, 2026-10-18); never large maps with two.
FITTING_PLAYERS = {"homm3_small": (2,), "homm3_medium": (2, 3), "homm3_large": (3, 4), "homm3_extra_large": (5, 6)}
TIMEOUT_MIN = {"homm3_small": 30, "homm3_medium": 90, "homm3_large": 180, "homm3_extra_large": 360}
GUARDS = ("weak", "normal", "strong")
WATER = ("land", "normal_water", "islands")
SLOW_DAY_MS = 10000
IS_WINDOWS = platform.system() == "Windows"


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
    rng.shuffle(rows)
    seeds: set[str] = set()
    matches_out = []
    for i, row in enumerate(rows):
        seed = f"ai-match-{rng.randrange(1, 2**32)}"
        while seed in seeds:
            seed = f"ai-match-{rng.randrange(1, 2**32)}"
        seeds.add(seed)
        matches_out.append({"run": f"m{i + 1:03d}", "seed": seed, **row})
    return {
        "schema": "ai_match_batch_plan_v1",
        "created": time.strftime("%Y-%m-%d %H:%M:%S"),
        "commit": git("rev-parse", "HEAD"),
        "dirty": bool(git("status", "--porcelain", "--untracked-files=no")),
        "plan_seed": plan_seed,
        "days": args.days,
        "lineups": "fixed" if args.lineup else args.lineups,
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
            if len(row) > 1 and row[0].lower().startswith("godot") and row[1].isdigit():
                found[int(row[1])] = row[0]
    else:
        out = subprocess.run(["ps", "-eo", "pid=,comm="], capture_output=True, text=True, errors="replace").stdout
        for line in out.splitlines():
            pid, _, name = line.strip().partition(" ")
            if pid.isdigit() and "godot" in name.lower():
                found[int(pid)] = name.strip()
    return found


def count_games(processes: dict[int, str]) -> int:
    # The Windows console build runs each game as a wrapper plus the game process.
    return sum(1 for name in processes.values() if "_console" not in name.lower())


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
    match: dict
    proc: subprocess.Popen
    log: IO[str]
    profile: str
    started: float
    deadline: float


def launch(godot: str, out: Path, m: dict, days: int, timeout_min: float) -> Running:
    profile = tempfile.mkdtemp(prefix=f"heroes-ai-{m['run']}-")
    env = {k: v for k, v in os.environ.items() if not k.startswith("HEROES_AI_MATCH_")}
    env.update({
        "APPDATA": profile,  # Windows user data: never the owner's saves
        "XDG_DATA_HOME": profile,  # Linux user data
        "XDG_CONFIG_HOME": profile,
        "HEROES_AI_MATCH_SEED": m["seed"],
        "HEROES_AI_MATCH_PLAYERS": str(m["players"]),
        "HEROES_AI_MATCH_SIZE": m["size"],
        "HEROES_AI_MATCH_FACTIONS": ",".join(m["factions"]),
        "HEROES_AI_MATCH_GUARDS": m["guards"],
        "HEROES_AI_MATCH_WATER": m["water"],
        "HEROES_AI_MATCH_LEVELS": str(m["levels"]),
        "HEROES_AI_MATCH_MAX_DAYS": str(days),
        "HEROES_AI_MATCH_OUT": (out / f"{m['run']}.json").as_posix(),
    })
    (out / f"{m['run']}.json").unlink(missing_ok=True)
    log = open(out / f"{m['run']}.log", "w", encoding="utf-8", errors="replace")
    cmd = [godot, "--headless", "--path", str(ROOT), "--audio-driver", "Dummy", SCENE]
    extra = {} if IS_WINDOWS else {"start_new_session": True}
    proc = subprocess.Popen(cmd, env=env, stdout=log, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL, **extra)
    now = time.time()
    return Running(m, proc, log, profile, now, now + timeout_min * 60)


def remove_match_maps(scenario_id: str, since: float, keep: set[str]) -> list[str]:
    """Delete the package pair one match wrote under res://maps: the .ascenario naming its
    scenario, written since the match started, and its .amap. Files in `keep` stay."""
    removed: list[str] = []
    if not scenario_id or not MAPS_DIR.is_dir():
        return removed
    needle = re.compile(r'"scenario_id":\s*"%s"' % re.escape(scenario_id))
    for scenario in MAPS_DIR.glob("*.ascenario"):
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


def finish(out: Path, run: Running, timed_out: bool, keep_maps: set[str]) -> dict:
    run.log.close()
    m = run.match
    log_path = out / f"{m['run']}.log"
    record_path = out / f"{m['run']}.json"
    text = log_path.read_text(encoding="utf-8", errors="replace") if log_path.exists() else ""
    report: dict = {}
    for line in text.splitlines():
        if line.startswith(REPORT_ID + " "):
            try:
                report = json.loads(line[len(REPORT_ID) + 1:])
            except ValueError:
                pass
    errors = [line.strip() for line in text.splitlines() if "SCRIPT ERROR" in line][:5]
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
        problem = f"timed out after {(run.deadline - run.started) / 60:g} min"
    else:
        tail = " | ".join(line.strip() for line in text.splitlines()[-3:])
        problem = f"exit {run.proc.returncode}, no report line: {tail}"
    shutil.rmtree(run.profile, ignore_errors=True)
    keep_log = bool(errors) or summary is None
    if not keep_log:
        log_path.unlink(missing_ok=True)
    return {
        **m,
        "status": "ok" if summary else ("timeout" if timed_out else "failed"),
        "exit": run.proc.returncode,
        "minutes": round((time.time() - run.started) / 60, 1),
        "started": round(run.started),
        "ended": round(time.time()),
        "script_errors": errors,
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


def run_batch(out: Path, plan: dict, godot: str, slots: int, timeout_override: float | None) -> int:
    say = Output(out)
    done = {row["run"] for row in read_results(out)}
    queue = sorted((m for m in plan["matches"] if m["run"] not in done), key=expected_cost, reverse=True)
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
    say(f"START {len(queue)} of {total} matches on {plan['commit'][:9]}{' (dirty tree)' if plan.get('dirty') else ''}, "
        f"{slots} at a time, at {time.strftime('%H:%M:%S')}")

    def save_inflight() -> None:
        inflight_path.write_text(json.dumps({r: x.proc.pid for r, x in running.items()}), encoding="utf-8")

    def on_term(signum, frame):
        raise KeyboardInterrupt
    signal.signal(signal.SIGTERM, on_term)
    try:
        while queue or running:
            seeds = {x.match["seed"] for x in running.values()}
            while len(running) < slots:
                # Never two matches with one seed at once: they would share a map package.
                job = next((m for m in queue if m["seed"] not in seeds), None)
                if job is None:
                    break
                queue.remove(job)
                timeout_min = timeout_override or TIMEOUT_MIN[job["size"]]
                running[job["run"]] = launch(godot, out, job, plan["days"], timeout_min)
                seeds.add(job["seed"])
                save_inflight()
            time.sleep(2)
            for name, x in list(running.items()):
                timed_out = x.proc.poll() is None and time.time() > x.deadline
                if timed_out:
                    kill(x.proc)
                if x.proc.poll() is None:
                    continue
                del running[name]
                row = finish(out, x, timed_out, keep_maps)
                row["slots"] = slots
                with open(out / "results.jsonl", "a", encoding="utf-8") as f:
                    f.write(json.dumps(row) + "\n")
                finished += 1
                save_inflight()
                say(f"{match_text(x.match)} -> {result_text(row)} ({row['minutes']} min) [{finished}/{total}, {len(running)} running]")
    except KeyboardInterrupt:
        for x in running.values():
            kill(x.proc)
            x.log.close()
            shutil.rmtree(x.profile, ignore_errors=True)
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
        f"line-ups {plan['lineups']}, day cap {plan['days']}: {groups}.",
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
    parser.add_argument("--seed", type=int, help="plan seed (default random); the same seed and options give the same plan")
    parser.add_argument("--slots", type=int, default=16, help="matches at once (default 16)")
    parser.add_argument("--timeout-min", type=float, help="per-match timeout in minutes (default by size: %s)" % ", ".join(f"{short_size(k)} {v}" for k, v in TIMEOUT_MIN.items()))
    parser.add_argument("--godot", help="Godot binary")
    parser.add_argument("--resume", action="store_true", help="play the matches plan.json still lacks (same commit only)")
    parser.add_argument("--summarize", action="store_true", help="only rewrite summary.md")
    parser.add_argument("--plan-only", action="store_true", help="write plan.json and stop")
    args = parser.parse_args()
    args.levels = [int(x) for x in args.levels]

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
    return run_batch(out, plan, find_godot(args.godot), max(1, args.slots), args.timeout_min)


if __name__ == "__main__":
    sys.exit(main())
