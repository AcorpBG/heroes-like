#!/usr/bin/env python3
"""Battle AI arena: plays two weight sets of the battle AI against each other and scores them.

    python tools/battle_ai_arena/arena.py                      # HEAD's weights (A) vs the working tree's (B)
    python tools/battle_ai_arena/arena.py --b-weights tuned.json --suite holdout
    python tools/battle_ai_arena/arena.py --a git:main~3 --b current --suite quick --workers 8
    python tools/battle_ai_arena/arena.py --plain --suite standard   # the game's own weights on both sides

Evaluation tooling only, run on demand. It is not part of tools/core_suite.py, the game or
the export; see README.md here for the design, the scoring and its limits.

Every battle of the suite is played twice from the same start, with the variants swapping
sides, so the armies and the battlefield cancel out and only the weights differ. A variant is
a weight set of content/battle_ai_weights.json: the working tree's (current), a revision's
(git:<rev>) or a file, and --a-weights and --b-weights replace them. Both sides run the
working tree's battle AI, the native port (docs/native-rules-engine-transition.md: Phase 2d
deleted its GDScript copy). Results go to .artifacts/battle_ai_arena/<time>-<suite>/.

battle_sim_cli (bin/, built with the rules library by tools/build_native.py) plays the
battles outside Godot: Godot workers build each battle up to its payload once (worker.gd, a
setup job), and battle_sim_cli plays every order from there, each side with its variant's
weights, through the native router. --backend godot --plain plays every game in Godot
instead, the game's own weights on both sides, with the same records.
"""
from __future__ import annotations

import argparse
import json
import math
import os
import shutil
import statistics
import subprocess
import sys
import tempfile
import time
from datetime import datetime
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(ROOT / "tools"))

import scenarios  # noqa: E402
from core_suite import find_godot  # noqa: E402

WEIGHTS_FILE = ROOT / "content" / "battle_ai_weights.json"
MAPS_DIR = ROOT / "maps"
CLI = ROOT / "bin" / ("battle_sim_cli.exe" if os.name == "nt" else "battle_sim_cli")

# Suites of realistic battles (scenarios.py): generated maps, battles on each.
SUITES = {
    # For judging changes.
    "standard": {"seed": "standard", "groups": 48, "battles": 5},
    # Other maps, armies and heroes. Keep it out of any tuning loop.
    "holdout": {"seed": "holdout", "groups": 48, "battles": 5},
    # A smoke run.
    "quick": {"seed": "quick", "groups": 12, "battles": 3},
}
# The player's strength over the enemy's (AiHeroRules.army_power) in bands.
ODDS_BANDS = [(0.5, "odds <0.5"), (0.8, "odds 0.5-0.8"), (1.25, "odds 0.8-1.25"), (2.0, "odds 1.25-2"), (float("inf"), "odds >2")]

# Scoring (see README.md). A unit is worth its recruitment cost in gold, other resources at
# this gold rate. A hero is worth this share of its army's starting value.
RESOURCE_GOLD_VALUE = 250
HERO_VALUE_SHARE = 0.2
PLAYER_WINS = {"victory", "enemy_retreat", "enemy_surrender"}
PLAYER_LOSSES = {"defeat", "hero_defeat", "retreat", "surrender"}
PLAYER_HERO_LOST = {"defeat", "hero_defeat"}
ENEMY_HERO_LOST = {"victory"}


def load_items(name: str) -> list[dict]:
    data = json.loads((ROOT / "content" / name).read_text(encoding="utf-8"))
    return data.get("items", data) if isinstance(data, dict) else data


def load_weights(path: Path | str | None = None) -> dict[str, float]:
    """A weights file ({"weights": {...}} or a flat mapping); the game's own by default."""
    data = json.loads(Path(path or WEIGHTS_FILE).read_text(encoding="utf-8"))
    weights = data.get("weights", data) if isinstance(data, dict) else {}
    return {key: float(value) for key, value in weights.items()}


def full_weights(weights: dict[str, float]) -> dict[str, float]:
    """Every weight the game's file names, the given ones replacing its values."""
    full = load_weights()
    full.update(weights)
    return full


def weight_text(value: float) -> str:
    """A weight as battle_sim_cli's variants file holds it, which it reads as its nearest float
    while it has at most 15 significant digits."""
    if not abs(value) < 1e9:
        sys.exit(f"a weight of {value} is outside the variants' text format")
    return f"{value:.6f}"


def variant_weights(spec: str, weights_file: str | None = None) -> dict[str, float] | None:
    """The weights battle_sim_cli plays a variant with: weights_file over the game's file if
    given, else 'current' (None: the game's own file), 'git:<rev>' (that revision's file) or a
    weights file. Weights a file leaves out keep the working tree's values."""
    if weights_file:
        return full_weights(load_weights(weights_file))
    if spec == "current":
        return None
    if spec.startswith("git:"):
        proc = subprocess.run(
            ["git", "-C", str(ROOT), "show", f"{spec[4:]}:content/battle_ai_weights.json"],
            capture_output=True, text=True, encoding="utf-8",
        )
        if proc.returncode != 0:
            sys.exit(f"cannot read content/battle_ai_weights.json at {spec[4:]}: {proc.stderr.strip()}")
        data = json.loads(proc.stdout)
        return full_weights({key: float(value) for key, value in data.get("weights", data).items()})
    return full_weights(load_weights(spec))


def write_variants(path: Path, variants: dict[str, dict[str, float] | None]) -> None:
    """battle_sim_cli's variants file: label, weight and value per line; a label alone reads
    the game's weights file."""
    lines = []
    for label, weights in variants.items():
        if weights is None:
            lines.append(label)
        lines.extend(f"{label}\t{key}\t{weight_text(value)}" for key, value in sorted((weights or {}).items()))
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def parse_odds(text: str | None) -> tuple[float, float] | None:
    """"0.6,1.7" -> (0.6, 1.7); None or "" -> None."""
    if not text:
        return None
    low, high = (float(part) for part in text.split(","))
    return (low, high)


def build_suite(name: str, odds: tuple[float, float] | None = None) -> list[dict]:
    config = SUITES[name]
    # A contested run plays about half the battles: generate twice as many.
    battles = config["battles"] * (2 if odds else 1)
    return scenarios.build_suite(name, config["seed"], config["groups"], battles, odds)


def unit_values() -> dict[str, float]:
    values = {}
    for unit in load_items("units.json"):
        cost = unit.get("cost", {}) or {}
        values[unit["id"]] = float(cost.get("gold", 0)) + sum(float(v) * RESOURCE_GOLD_VALUE for k, v in cost.items() if k != "gold")
    return values


def side_value(ledger: dict, side: str, values: dict[str, float], key: str) -> float:
    rows = (ledger.get(side, {}) or {}).get("rows", [])
    return sum(float(row.get(key, 0)) * values.get(row.get("unit_id", ""), 0.0) for row in rows)


def score_game(game: dict, values: dict[str, float]) -> dict | None:
    """The player side's score in [0, 1]; the enemy side's is 1 minus it."""
    outcome = game.get("outcome", "")
    if outcome in PLAYER_WINS:
        result = 1.0
    elif outcome in PLAYER_LOSSES:
        result = 0.0
    elif outcome == "stalemate":
        result = 0.5
    else:
        return None
    kept = {}
    for side, had_hero, hero_lost in (
        ("player", game.get("player_hero", False), outcome in PLAYER_HERO_LOST),
        ("enemy", game.get("enemy_hero", False), outcome in ENEMY_HERO_LOST),
    ):
        start = side_value(game.get("start_ledger", {}), side, values, "starting")
        survived = side_value(game.get("end_ledger", {}), side, values, "surviving")
        hero = HERO_VALUE_SHARE * start if had_hero else 0.0
        total = start + hero
        kept[side] = (survived + (0.0 if hero_lost else hero)) / total if total > 0 else 0.0
    return {"result": result, "player_score": 0.5 * result + 0.25 * kept["player"] + 0.25 * (1.0 - kept["enemy"]), "kept": kept}


def run_workers(
    godot: str,
    run_dir: Path,
    groups: list[dict],
    workers: int,
    timeout: int,
    orders: list[list[str]] | None = None,
    setup: dict | None = None,
) -> tuple[list[dict], list[str]]:
    """Plays every battle of groups once per order ([player variant, enemy variant]), the game's own weights on
    both sides (--plain). With setup ({corpus_dir, content}) the workers play nothing and write the battles for
    battle_sim_cli instead (run_cli)."""
    chunks = [groups[i::workers] for i in range(workers)]
    procs = []
    profiles = []
    for index, chunk in enumerate(chunks):
        if not chunk:
            continue
        job = run_dir / f"job_{index}.json"
        job.write_text(json.dumps({
            "orders": orders or [["A", "B"], ["B", "A"]],
            "groups": chunk,
            # The first worker also writes the content snapshot.
            **({"setup": {"corpus_dir": setup["corpus_dir"], "content": setup["content"] if index == 0 else ""}} if setup else {}),
        }), encoding="utf-8")
        procs.append(start_worker(godot, run_dir, index, job, profiles))
    problems = []
    deadline = time.monotonic() + timeout
    for index, proc, _out, log in procs:
        try:
            proc.wait(timeout=max(1, deadline - time.monotonic()))
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
            problems.append(f"worker {index} timed out")
        log.close()
        if proc.returncode not in (0, None):
            problems.append(f"worker {index} exited with {proc.returncode}")
    for profile in profiles:
        shutil.rmtree(profile, ignore_errors=True)
    rows = []
    for index, _proc, out, _log in procs:
        if out.exists():
            rows.extend(json.loads(line) for line in out.read_text(encoding="utf-8").splitlines() if line.strip())
        log_text = (run_dir / f"worker_{index}.log").read_text(encoding="utf-8", errors="replace")
        errors = log_text.count("SCRIPT ERROR")
        if errors:
            problems.append(f"worker {index}: {errors} script errors (see worker_{index}.log)")
    return rows, problems


def start_worker(godot: str, run_dir: Path, index: int, job: Path, profiles: list[str]) -> tuple:
    """A Godot worker on its job, with a user profile of its own: (index, process, results path, log)."""
    profile = tempfile.mkdtemp(prefix="heroes-arena-")
    profiles.append(profile)
    env = dict(os.environ)
    env["APPDATA"] = profile  # Windows user data
    env["XDG_DATA_HOME"] = profile  # Linux user data
    env["XDG_CONFIG_HOME"] = profile
    out = run_dir / f"results_{index}.jsonl"
    log = (run_dir / f"worker_{index}.log").open("w", encoding="utf-8")
    cmd = [godot, "--headless", "--path", str(ROOT), "--audio-driver", "Dummy", "-s", str(HERE / "worker.gd"), "--", str(job), str(out)]
    return (index, subprocess.Popen(cmd, env=env, stdout=log, stderr=subprocess.STDOUT), out, log)


def run_cli(
    godot: str,
    run_dir: Path,
    groups: list[dict],
    workers: int,
    variants: dict[str, dict[str, float] | None] | None,
    timeout: int,
    orders: list[list[str]] | None = None,
    default_variant: str = "A",
    threads: int = 0,
) -> tuple[list[dict], list[str], dict]:
    """run_workers' games played by battle_sim_cli, with the same records: Godot workers build each battle up to
    its payload once (worker.gd, a setup job), and battle_sim_cli plays every order from there. variants: each
    label's weights (variant_weights), None for a plain run. Also returns battle_sim_cli's counts."""
    orders = orders or [["A", "B"], ["B", "A"]]
    corpus = run_dir / "corpus"
    shutil.rmtree(corpus, ignore_errors=True)
    corpus.mkdir(parents=True)
    content = run_dir / "content.snap"
    numbered = [dict(group, corpus_file=f"group_{index:05d}.snap") for index, group in enumerate(groups)]
    started = time.monotonic()
    rows, problems = run_workers(godot, run_dir, numbered, workers, timeout, orders,
                                 setup={"corpus_dir": str(corpus), "content": str(content)})
    games, cli_problems, stats = play_cli(run_dir, content, corpus, variants, orders, default_variant,
                                          max(1, int(timeout - (time.monotonic() - started))), threads)
    shutil.rmtree(corpus, ignore_errors=True)
    content.unlink(missing_ok=True)
    return rows + games, problems + cli_problems, stats


def play_cli(
    out_dir: Path,
    content: Path,
    corpus: Path,
    variants: dict[str, dict[str, float] | None] | None,
    orders: list[list[str]],
    default_variant: str,
    timeout: int,
    threads: int = 0,
) -> tuple[list[dict], list[str], dict]:
    """battle_sim_cli on a corpus of setup snapshots: its game records, problems and counts. Writes
    cli_games.jsonl (the records) and variants.txt into out_dir."""
    if not CLI.exists():
        sys.exit(f"{CLI} is missing: build it with python tools/build_native.py windows")
    games = out_dir / "cli_games.jsonl"
    cmd = [str(CLI), "--content", str(content), "--corpus-dir", str(corpus), "--out", str(games),
           "--orders", ",".join(f"{player}:{enemy}" for player, enemy in orders)]
    if variants is None:
        cmd.append("--plain")
    else:
        write_variants(out_dir / "variants.txt", variants)
        cmd += ["--variants", str(out_dir / "variants.txt"), "--default", default_variant]
    if threads:
        cmd += ["--threads", str(threads)]
    problems = []
    started = time.monotonic()
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", timeout=timeout)
    except subprocess.TimeoutExpired:
        return [], ["battle_sim_cli timed out"], {}
    lines = [line for line in proc.stdout.splitlines() if line.strip()]
    stats = json.loads(lines[-1]) if lines and lines[-1].startswith("{") else {}
    stats["wall_seconds"] = round(time.monotonic() - started, 1)
    if proc.returncode != 0:
        problems.append(f"battle_sim_cli exited with {proc.returncode}: {proc.stderr.strip()[-400:]}")
    problems.extend(f"battle_sim_cli: {error}" for error in stats.get("group_errors", []))
    rows = [json.loads(line) for line in games.read_text(encoding="utf-8").splitlines() if line.strip()] if games.exists() else []
    return rows, problems, stats


def mean_ci(values: list[float]) -> tuple[float, float]:
    if not values:
        return float("nan"), float("nan")
    if len(values) < 2:
        return values[0], float("nan")
    return statistics.fmean(values), 1.96 * statistics.stdev(values) / math.sqrt(len(values))


def battle_tags(game: dict) -> dict[str, str]:
    """The breakdowns a battle counts in (see scenarios.py for what they mean)."""
    kind = game.get("type", "")
    week = int(game.get("week", 0))
    ratio = float(game.get("player_power", 0)) / max(1.0, float(game.get("enemy_power", 0)))
    tags = {
        "type": kind,
        "weeks": "weeks 1-2" if week <= 2 else ("weeks 3-5" if week <= 5 else "weeks 6+"),
        "player_doctrine": f"player {game.get('player_doctrine', '')}",
        "odds": next(label for limit, label in ODDS_BANDS if ratio < limit),
    }
    if kind == "guard":
        tags["guard"] = f"{game.get('monster_strength', '')} guard"
        tags["guard_ratio"] = f"guard x{game.get('guard_ratio', '')}"
    else:
        tags["enemy_doctrine"] = f"{kind} {game.get('enemy_doctrine', '')}"
    return tags


def summarize(rows: list[dict], values: dict[str, float], plain: bool = False) -> tuple[dict, list[str]]:
    games = [row for row in rows if row.get("kind") == "game"]
    problems = [f"{row.get('battle_id', row.get('group_id'))}: {row.get('error')}" for row in rows if row.get("error")]
    by_battle: dict[str, dict] = {}
    for game in games:
        if game.get("error"):
            continue
        scored = score_game(game, values)
        if scored is None:
            problems.append(f"{game['battle_id']} ({game['player_variant']} as player): unscored outcome {game.get('outcome')!r} state {game.get('state')!r}")
            continue
        calls = game.get("ai_calls", {})
        if not plain and (not calls.get("player") or not calls.get("enemy")) and game.get("rounds", 0) > 1:
            problems.append(f"{game['battle_id']}: an AI side made no calls {calls}")
        entry = by_battle.setdefault(game["battle_id"], {"tags": battle_tags(game), "games": [], "reference": None})
        if game["player_variant"] == game["enemy_variant"]:
            entry["reference"] = scored["player_score"]  # A against A, for the role split
            continue
        b_is_player = game["player_variant"] == "B"
        entry["games"].append({
            "b_is_player": b_is_player,
            "player_score": scored["player_score"],
            "b_score": scored["player_score"] if b_is_player else 1.0 - scored["player_score"],
            "b_result": scored["result"] if b_is_player else 1.0 - scored["result"],
            "player_won": scored["result"],
            "rounds": game.get("rounds", 0),
            "ms": game.get("ms", 0.0),
        })
    battles = {key: value for key, value in by_battle.items() if len(value["games"]) == 2}
    for key in by_battle.keys() - battles.keys():
        problems.append(f"{key}: only {len(by_battle[key]['games'])} of 2 games scored")
    for battle in battles.values():
        battle["b_score"] = statistics.fmean(g["b_score"] for g in battle["games"])
    scores = [b["b_score"] for b in battles.values()]
    results = [g["b_result"] for b in battles.values() for g in b["games"]]
    mean, ci = mean_ci(scores)
    # A battle the same side wins in both orders is decided by the armies; one that
    # changes hands with the AI is where the AI decides.
    ai_decided = sum(1 for b in battles.values() if b["games"][0]["player_won"] != b["games"][1]["player_won"])

    def rounded(v: list[float]) -> dict:
        m, c = mean_ci(v)
        return {"mean": round(m, 4), "ci95": None if math.isnan(c) else round(c, 4), "battles": len(v)}

    def breakdown(field: str) -> dict:
        groups: dict[str, list[float]] = {}
        for battle in battles.values():
            if field in battle["tags"]:
                groups.setdefault(battle["tags"][field], []).append(battle["b_score"])
        return {key: rounded(v) for key, v in sorted(groups.items())}

    # With a reference game (A against A), B's gain splits into its play as the player
    # side (B against A over A against A) and as the enemy side (guards, defenders, AI heroes).
    roles: dict[str, dict[str, list[float]]] = {}
    for battle in battles.values():
        if battle["reference"] is None:
            continue
        b_player = next(g["player_score"] for g in battle["games"] if g["b_is_player"])
        a_player = next(g["player_score"] for g in battle["games"] if not g["b_is_player"])
        for key in ("all", battle["tags"]["type"], battle["tags"]["player_doctrine"]):
            entry = roles.setdefault(key, {"as_player": [], "as_enemy": []})
            entry["as_player"].append(b_player - battle["reference"])
            entry["as_enemy"].append(battle["reference"] - a_player)

    all_games = [g for b in battles.values() for g in b["games"]]
    summary = {
        "battles": len(battles),
        "games": len(all_games),
        "b_score": round(mean, 4) if scores else None,
        "b_score_ci95": round(ci, 4) if not math.isnan(ci) else None,
        "b_wins": sum(1 for r in results if r == 1.0),
        "b_losses": sum(1 for r in results if r == 0.0),
        "draws": sum(1 for r in results if r == 0.5),
        "ai_decided_battles": ai_decided,
        "mean_rounds": round(statistics.fmean(g["rounds"] for g in all_games), 2) if all_games else None,
        "mean_game_ms": round(statistics.fmean(g["ms"] for g in all_games), 1) if all_games else None,
        "breakdowns": {field: breakdown(field) for field in ("type", "guard", "guard_ratio", "enemy_doctrine", "player_doctrine", "weeks", "odds")},
        "roles": {key: {side: rounded(v) for side, v in entry.items()} for key, entry in roles.items()},
    }
    return summary, problems


def print_report(summary: dict, problems: list[str], args, wall: float, run_dir: Path) -> None:
    a_label = "the game's AI, no router" if args.plain else args.a + (f" with {args.a_weights}" if args.a_weights else "")
    b_label = "the game's AI, no router" if args.plain else args.b + (f" with {args.b_weights}" if args.b_weights else "")
    odds = f" odds {args.odds} ({summary.get('skipped', 0)} battles outside)" if args.odds else ""
    print(f"\nBattle AI arena | suite {args.suite}{odds} | A = {a_label} | B = {b_label}")
    print(f"{summary['battles']} battles, {summary['games']} games in {wall:.0f}s ({summary['games'] / wall:.1f} games/s), "
          f"{summary['mean_rounds']} rounds and {summary['mean_game_ms']} ms per game")
    if summary["b_score"] is not None:
        ci = summary["b_score_ci95"]
        verdict = "no measurable difference"
        if ci is not None and summary["b_score"] - ci > 0.5:
            verdict = "B is better"
        elif ci is not None and summary["b_score"] + ci < 0.5:
            verdict = "B is worse"
        print(f"B score {summary['b_score']:.4f} +/- {ci if ci is not None else float('nan'):.4f} (0.5 = equal): {verdict}")
        print(f"B games won {summary['b_wins']}, lost {summary['b_losses']}, drawn {summary['draws']}; "
              f"battles the AI decided (winner changes with the sides): {summary['ai_decided_battles']} of {summary['battles']}")
        for field, rows in summary["breakdowns"].items():
            if rows:
                print(f"  {field:16s} " + ", ".join(f"{k} {v['mean']:.3f} ({v['battles']})" for k, v in rows.items()))
        if summary["roles"]:
            print("B's gain over A as the player side / as the enemy side (guards, defenders, AI heroes):")
            for key, entry in summary["roles"].items():
                print(f"  {key:16s} {entry['as_player']['mean']:+.3f} / {entry['as_enemy']['mean']:+.3f} ({entry['as_player']['battles']})")
    if problems:
        print(f"\n{len(problems)} problems:")
        for line in problems[:20]:
            print(f"  {line}")
    print(f"\nResults: {run_dir}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--a", default="git:HEAD", help="baseline weights: current, git:<rev> or a weights file (default git:HEAD)")
    parser.add_argument("--b", default="current", help="candidate weights: current, git:<rev> or a weights file (default current)")
    parser.add_argument("--a-weights", help="weights file for A, over the game's content/battle_ai_weights.json")
    parser.add_argument("--b-weights", help="weights file for B, for example a tune.py result")
    parser.add_argument("--suite", choices=sorted(SUITES), default="standard")
    parser.add_argument("--workers", type=int, default=max(1, (os.cpu_count() or 2) * 3 // 4))
    parser.add_argument("--godot", help="Godot binary")
    parser.add_argument("--out", help="results directory (default .artifacts/battle_ai_arena/<time>-<suite>)")
    parser.add_argument("--timeout", type=int, default=3600, help="seconds before workers are stopped")
    parser.add_argument("--odds", help="contested battles only: LOW,HIGH band of the player's strength over the enemy's, e.g. 0.6,1.7")
    parser.add_argument("--roles", action="store_true", help="also play A against A, to split B's gain into its play as player and as enemy")
    parser.add_argument("--keep-logs", action="store_true", help="keep worker jobs, logs and raw results")
    parser.add_argument("--plain", action="store_true", help="the game's own weights on both sides, no router or variants (--a and --b unused)")
    parser.add_argument("--backend", choices=("cli", "godot"), default="cli", help="cli: battle_sim_cli plays the battles (default); godot: Godot workers play every game, with --plain only")
    parser.add_argument("--threads", type=int, default=0, help="battle_sim_cli's threads (default: one per core)")
    args = parser.parse_args()
    if args.plain and (args.a_weights or args.b_weights):
        parser.error("--plain plays the game's own weights")
    if args.backend == "godot" and not args.plain:
        parser.error("--backend godot plays the game's own weights only: add --plain")

    godot = find_godot(args.godot)
    run_dir = Path(args.out) if args.out else ROOT / ".artifacts" / "battle_ai_arena" / f"{datetime.now():%Y%m%d-%H%M%S}-{args.suite}"
    run_dir.mkdir(parents=True, exist_ok=True)
    cli_variants = None
    if not args.plain:
        cli_variants = {"A": variant_weights(args.a, args.a_weights), "B": variant_weights(args.b, args.b_weights)}

    groups = build_suite(args.suite, parse_odds(args.odds))
    orders = [["A", "B"], ["B", "A"]] + ([["A", "A"]] if args.roles else [])
    workers = max(1, min(args.workers, len(groups)))
    maps_before = set(MAPS_DIR.iterdir()) if MAPS_DIR.exists() else set()
    print(f"Arena: {sum(len(g['battles']) for g in groups)} battles x {len(orders)} games on {len(groups)} maps, {workers} workers ...")
    started = time.monotonic()
    cli_stats = None
    if args.backend == "cli":
        rows, problems, cli_stats = run_cli(godot, run_dir, groups, workers, cli_variants, args.timeout, orders, "A", args.threads)
    else:
        rows, problems = run_workers(godot, run_dir, groups, workers, args.timeout, orders)
    wall = time.monotonic() - started
    summary, game_problems = summarize(rows, unit_values(), args.plain)
    problems = problems + game_problems
    leftovers = sorted(p.name for p in (set(MAPS_DIR.iterdir()) if MAPS_DIR.exists() else set()) - maps_before)
    if leftovers:
        problems.append(f"maps/ gained {len(leftovers)} files during the run (workers remove their own): {leftovers[:6]}")
    summary.update({"suite": args.suite, "odds": args.odds, "skipped": sum(1 for row in rows if row.get("kind") == "skipped") // max(1, len(orders)), "a": args.a, "b": args.b, "plain": args.plain, "backend": args.backend, "workers": workers, "wall_seconds": round(wall, 1), "problems": problems})
    if cli_stats is not None:
        summary["battle_sim_cli"] = cli_stats
    (run_dir / "summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    values = unit_values()
    with (run_dir / "games.jsonl").open("w", encoding="utf-8", newline="\n") as handle:
        for row in rows:
            if row.get("kind") == "game":
                line = {k: v for k, v in row.items() if k not in ("start_ledger", "end_ledger")}
                scored = score_game(row, values)
                if scored is not None:
                    line["player_score"] = round(scored["player_score"], 6)
                    line["kept"] = {side: round(share, 6) for side, share in scored["kept"].items()}
                handle.write(json.dumps(line) + "\n")
    if not args.keep_logs and not problems:
        for path in list(run_dir.glob("job_*.json")) + list(run_dir.glob("results_*.jsonl")) + list(run_dir.glob("worker_*.log")) + list(run_dir.glob("cli_games.jsonl")) + list(run_dir.glob("variants.txt")):
            path.unlink()
    print_report(summary, problems, args, wall, run_dir)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
