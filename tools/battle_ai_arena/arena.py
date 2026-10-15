#!/usr/bin/env python3
"""Battle AI arena: plays two BattleAiRules.gd variants against each other and scores them.

    python tools/battle_ai_arena/arena.py                      # HEAD's AI (A) vs the working tree's (B)
    python tools/battle_ai_arena/arena.py --b path/to/BattleAiRules.gd --suite holdout
    python tools/battle_ai_arena/arena.py --a git:main~3 --b current --suite quick --workers 8

Evaluation tooling only, run on demand. It is not part of tools/core_suite.py, the game or
the export; see README.md here for the design, the scoring and its limits.

Every battle of the suite is played twice from the same start, with the variants swapping
sides, so the armies and the battlefield cancel out and only the AI differs. Each side's
stacks and hero are commanded by its own variant, swapped in memory inside the Godot worker
(router.py); the repo's files are never written. Results go to
.artifacts/battle_ai_arena/<time>-<suite>/.
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

import router  # noqa: E402
import scenarios  # noqa: E402
from core_suite import find_godot  # noqa: E402

AI_SOURCE = ROOT / "scripts" / "core" / "BattleAiRules.gd"
WEIGHTS_FILE = ROOT / "content" / "battle_ai_weights.json"
WEIGHTS_DECLARATION = "static var _weights: Dictionary = {}"
MAPS_DIR = ROOT / "maps"

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


def weighted_source(source: str, weights: dict[str, float]) -> str:
    """The variant's source with its weights built in, in place of reading the game's file.
    Every weight the game's file names must be given (missing ones keep the file's values)."""
    if WEIGHTS_DECLARATION not in source:
        sys.exit("this BattleAiRules.gd reads no weights file, so it cannot take weights")
    full = load_weights()
    full.update(weights)
    literal = "{" + ", ".join(f'"{key}": {value:.6f}' for key, value in sorted(full.items())) + "}"
    return source.replace(WEIGHTS_DECLARATION, f"static var _weights: Dictionary = {literal}", 1)


def resolve_variant(spec: str, dest: Path, weights: dict[str, float] | None = None) -> str:
    """'current' (the working tree), 'git:<rev>', or a path to a BattleAiRules.gd copy,
    optionally with its weights replaced."""
    if spec == "current":
        source = AI_SOURCE.read_text(encoding="utf-8")
    elif spec.startswith("git:"):
        rev = spec[4:]
        proc = subprocess.run(
            ["git", "-C", str(ROOT), "show", f"{rev}:scripts/core/BattleAiRules.gd"],
            capture_output=True, text=True, encoding="utf-8",
        )
        if proc.returncode != 0:
            sys.exit(f"cannot read BattleAiRules.gd at {rev}: {proc.stderr.strip()}")
        source = proc.stdout
    else:
        source = Path(spec).read_text(encoding="utf-8")
    if weights is None and spec.startswith("git:") and WEIGHTS_DECLARATION in source:
        # The revision's own weights, not the working tree's file the game would read.
        proc = subprocess.run(
            ["git", "-C", str(ROOT), "show", f"{spec[4:]}:content/battle_ai_weights.json"],
            capture_output=True, text=True, encoding="utf-8",
        )
        if proc.returncode == 0:
            data = json.loads(proc.stdout)
            weights = {key: float(value) for key, value in data.get("weights", data).items()}
    if weights is not None:
        source = weighted_source(source, weights)
    dest.write_text(router.strip_class_name(source), encoding="utf-8")
    return source


def build_suite(name: str) -> list[dict]:
    config = SUITES[name]
    return scenarios.build_suite(name, config["seed"], config["groups"], config["battles"])


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
    variant_paths: dict,
    router_path: Path,
    timeout: int,
    orders: list[list[str]] | None = None,
    default_variant: str = "A",
) -> tuple[list[dict], list[str]]:
    """Plays every battle of groups once per order ([player variant, enemy variant])."""
    chunks = [groups[i::workers] for i in range(workers)]
    procs = []
    profiles = []
    for index, chunk in enumerate(chunks):
        if not chunk:
            continue
        job = run_dir / f"job_{index}.json"
        job.write_text(json.dumps({
            "variants": {label: str(path) for label, path in variant_paths.items()},
            "default_variant": default_variant,
            "router": str(router_path),
            "orders": orders or [["A", "B"], ["B", "A"]],
            "groups": chunk,
        }), encoding="utf-8")
        profile = tempfile.mkdtemp(prefix="heroes-arena-")
        profiles.append(profile)
        env = dict(os.environ)
        env["APPDATA"] = profile  # Windows user data
        env["XDG_DATA_HOME"] = profile  # Linux user data
        env["XDG_CONFIG_HOME"] = profile
        out = run_dir / f"results_{index}.jsonl"
        log = (run_dir / f"worker_{index}.log").open("w", encoding="utf-8")
        cmd = [godot, "--headless", "--path", str(ROOT), "--audio-driver", "Dummy", "-s", str(HERE / "worker.gd"), "--", str(job), str(out)]
        procs.append((index, subprocess.Popen(cmd, env=env, stdout=log, stderr=subprocess.STDOUT), out, log))
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


def summarize(rows: list[dict], values: dict[str, float]) -> tuple[dict, list[str]]:
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
        if (not calls.get("player") or not calls.get("enemy")) and game.get("rounds", 0) > 1:
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
    a_label = args.a + (f" with {args.a_weights}" if args.a_weights else "")
    b_label = args.b + (f" with {args.b_weights}" if args.b_weights else "")
    print(f"\nBattle AI arena | suite {args.suite} | A = {a_label} | B = {b_label}")
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
    parser.add_argument("--a", default="git:HEAD", help="baseline variant: current, git:<rev> or a file (default git:HEAD)")
    parser.add_argument("--b", default="current", help="candidate variant: current, git:<rev> or a file (default current)")
    parser.add_argument("--a-weights", help="weights file for A, over the game's content/battle_ai_weights.json")
    parser.add_argument("--b-weights", help="weights file for B, for example a tune.py result")
    parser.add_argument("--suite", choices=sorted(SUITES), default="standard")
    parser.add_argument("--workers", type=int, default=max(1, (os.cpu_count() or 2) * 3 // 4))
    parser.add_argument("--godot", help="Godot binary")
    parser.add_argument("--out", help="results directory (default .artifacts/battle_ai_arena/<time>-<suite>)")
    parser.add_argument("--timeout", type=int, default=3600, help="seconds before workers are stopped")
    parser.add_argument("--roles", action="store_true", help="also play A against A, to split B's gain into its play as player and as enemy")
    parser.add_argument("--keep-logs", action="store_true", help="keep worker jobs, logs and raw results")
    args = parser.parse_args()

    godot = find_godot(args.godot)
    run_dir = Path(args.out) if args.out else ROOT / ".artifacts" / "battle_ai_arena" / f"{datetime.now():%Y%m%d-%H%M%S}-{args.suite}"
    run_dir.mkdir(parents=True, exist_ok=True)
    variants_dir = run_dir / "variants"
    variants_dir.mkdir(exist_ok=True)
    variant_paths = {"A": variants_dir / "A.gd", "B": variants_dir / "B.gd"}
    resolve_variant(args.a, variant_paths["A"], load_weights(args.a_weights) if args.a_weights else None)
    resolve_variant(args.b, variant_paths["B"], load_weights(args.b_weights) if args.b_weights else None)
    # The router keeps the signatures the game was compiled against: the working tree's.
    router_path = run_dir / "router.gd"
    router_path.write_text(router.build_router(AI_SOURCE.read_text(encoding="utf-8")), encoding="utf-8")

    groups = build_suite(args.suite)
    orders = [["A", "B"], ["B", "A"]] + ([["A", "A"]] if args.roles else [])
    workers = max(1, min(args.workers, len(groups)))
    maps_before = set(MAPS_DIR.iterdir()) if MAPS_DIR.exists() else set()
    print(f"Arena: {sum(len(g['battles']) for g in groups)} battles x {len(orders)} games on {len(groups)} maps, {workers} workers ...")
    started = time.monotonic()
    rows, problems = run_workers(godot, run_dir, groups, workers, variant_paths, router_path, args.timeout, orders)
    wall = time.monotonic() - started
    summary, game_problems = summarize(rows, unit_values())
    problems = problems + game_problems
    leftovers = sorted(p.name for p in (set(MAPS_DIR.iterdir()) if MAPS_DIR.exists() else set()) - maps_before)
    if leftovers:
        problems.append(f"maps/ gained {len(leftovers)} files during the run (workers remove their own): {leftovers[:6]}")
    summary.update({"suite": args.suite, "a": args.a, "b": args.b, "workers": workers, "wall_seconds": round(wall, 1), "problems": problems})
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
        for path in list(run_dir.glob("job_*.json")) + list(run_dir.glob("results_*.jsonl")) + list(run_dir.glob("worker_*.log")):
            path.unlink()
    print_report(summary, problems, args, wall, run_dir)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
