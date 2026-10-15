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
from core_suite import find_godot  # noqa: E402

AI_SOURCE = ROOT / "scripts" / "core" / "BattleAiRules.gd"
MAPS_DIR = ROOT / "maps"

# Army stages: weeks of creature growth from a fully built town, the top tier
# recruited by then, the hero's level and the guild spell tiers it knows.
STAGES = [
    {"id": "week1", "weeks": 1, "tier_max": 4, "hero_level": 2, "spell_tier_max": 1},
    {"id": "week3", "weeks": 3, "tier_max": 6, "hero_level": 5, "spell_tier_max": 2},
    {"id": "week5", "weeks": 5, "tier_max": 7, "hero_level": 8, "spell_tier_max": 3},
    {"id": "week8", "weeks": 8, "tier_max": 7, "hero_level": 11, "spell_tier_max": 3},
]
SUITES = {
    # Training set: every player faction at every stage against every faction (mirror included).
    "standard": {"stages": ["week1", "week3", "week5", "week8"], "enemies": 6, "hero_offset": 0},
    # Holdout: the same coverage on other maps, sites and heroes. Keep it out of any tuning loop.
    "holdout": {"stages": ["week1", "week3", "week5", "week8"], "enemies": 6, "hero_offset": 5},
    # A minute-long smoke run.
    "quick": {"stages": ["week5"], "enemies": 3, "hero_offset": 0},
}

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


def resolve_variant(spec: str, dest: Path) -> str:
    """'current' (the working tree), 'git:<rev>', or a path to a BattleAiRules.gd copy."""
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
    dest.write_text(router.strip_class_name(source), encoding="utf-8")
    return source


def build_suite(name: str, balance: bool = True) -> list[dict]:
    config = SUITES[name]
    factions = [f for f in load_items("factions.json") if len(f.get("unit_ladder_ids", [])) >= 7 and f.get("hero_ids")]
    stages = [s for s in STAGES if s["id"] in config["stages"]]
    groups = []
    for p_index, player in enumerate(factions):
        for s_index, stage in enumerate(stages):
            hero_ids = player["hero_ids"]
            group = {
                "group_id": f"{name}:{player['id']}:{stage['id']}",
                "map_seed": f"battle-ai-arena-{name}-{player['id']}-{stage['id']}",
                "map_size": "homm3_small",
                "player_faction": player["id"],
                "player_hero_id": hero_ids[(config["hero_offset"] + s_index) % len(hero_ids)],
                "stage": stage,
                "balance": balance,
                "battles": [],
            }
            for e_index in range(config["enemies"]):
                enemy = factions[(p_index + e_index) % len(factions)]
                enemy_heroes = enemy["hero_ids"]
                group["battles"].append({
                    "battle_id": f"{group['group_id']}:{e_index}",
                    "site_index": config["hero_offset"] + e_index,
                    "enemy_faction": enemy["id"],
                    "enemy_hero_id": enemy_heroes[(config["hero_offset"] + s_index + e_index + 1) % len(enemy_heroes)],
                })
            groups.append(group)
    return groups


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


def run_workers(godot: str, run_dir: Path, groups: list[dict], workers: int, variant_paths: dict, router_path: Path, timeout: int) -> tuple[list[dict], list[str]]:
    chunks = [groups[i::workers] for i in range(workers)]
    procs = []
    profiles = []
    for index, chunk in enumerate(chunks):
        if not chunk:
            continue
        job = run_dir / f"job_{index}.json"
        job.write_text(json.dumps({
            "variants": {label: str(path) for label, path in variant_paths.items()},
            "default_variant": "A",
            "router": str(router_path),
            "orders": [["A", "B"], ["B", "A"]],
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


def summarize(rows: list[dict], values: dict[str, float]) -> tuple[dict, list[str]]:
    games = [row for row in rows if row.get("kind") == "game"]
    problems = [f"{row.get('battle_id')}: {row.get('error')}" for row in rows if row.get("error")]
    by_battle: dict[str, dict] = {}
    for game in games:
        if game.get("error"):
            continue
        scored = score_game(game, values)
        if scored is None:
            problems.append(f"{game['battle_id']} ({game['player_variant']} as player): unscored outcome {game.get('outcome')!r} state {game.get('state')!r}")
            continue
        calls = game.get("ai_calls", {})
        if not calls.get("player") or not calls.get("enemy"):
            problems.append(f"{game['battle_id']}: an AI side made no calls {calls}")
        b_is_player = game["player_variant"] == "B"
        entry = by_battle.setdefault(game["battle_id"], {"stage": game["stage"], "matchup": f"{game['player_faction']} v {game['enemy_faction']}", "games": []})
        entry["games"].append({
            "b_score": scored["player_score"] if b_is_player else 1.0 - scored["player_score"],
            "b_result": scored["result"] if b_is_player else 1.0 - scored["result"],
            "player_won": scored["result"],
            "rounds": game.get("rounds", 0),
            "ms": game.get("ms", 0.0),
        })
    battles = {key: value for key, value in by_battle.items() if len(value["games"]) == 2}
    for key in by_battle.keys() - battles.keys():
        problems.append(f"{key}: only {len(by_battle[key]['games'])} of 2 games scored")
    scores = [statistics.fmean(g["b_score"] for g in b["games"]) for b in battles.values()]
    results = [g["b_result"] for b in battles.values() for g in b["games"]]
    mean, ci = mean_ci(scores)
    # A battle the same side wins in both orders is decided by the armies; one that
    # changes hands with the AI is where the AI decides.
    ai_decided = sum(1 for b in battles.values() if b["games"][0]["player_won"] != b["games"][1]["player_won"])

    def breakdown(field: str) -> dict:
        groups: dict[str, list[float]] = {}
        for battle in battles.values():
            groups.setdefault(battle[field], []).append(statistics.fmean(g["b_score"] for g in battle["games"]))
        return {key: {"b_score": round(statistics.fmean(v), 4), "battles": len(v)} for key, v in sorted(groups.items())}

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
        "by_stage": breakdown("stage"),
        "by_matchup": breakdown("matchup"),
    }
    return summary, problems


def print_report(summary: dict, problems: list[str], args, wall: float, run_dir: Path) -> None:
    print(f"\nBattle AI arena | suite {args.suite} | A = {args.a} | B = {args.b}")
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
        print("By stage: " + ", ".join(f"{k} {v['b_score']:.3f}" for k, v in summary["by_stage"].items()))
        worst = sorted(summary["by_matchup"].items(), key=lambda item: item[1]["b_score"])[:5]
        print("Weakest matchups for B: " + ", ".join(f"{k} {v['b_score']:.3f}" for k, v in worst))
    if problems:
        print(f"\n{len(problems)} problems:")
        for line in problems[:20]:
            print(f"  {line}")
    print(f"\nResults: {run_dir}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--a", default="git:HEAD", help="baseline variant: current, git:<rev> or a file (default git:HEAD)")
    parser.add_argument("--b", default="current", help="candidate variant: current, git:<rev> or a file (default current)")
    parser.add_argument("--suite", choices=sorted(SUITES), default="standard")
    parser.add_argument("--workers", type=int, default=max(1, (os.cpu_count() or 2) * 3 // 4))
    parser.add_argument("--godot", help="Godot binary")
    parser.add_argument("--out", help="results directory (default .artifacts/battle_ai_arena/<time>-<suite>)")
    parser.add_argument("--timeout", type=int, default=3600, help="seconds before workers are stopped")
    parser.add_argument("--no-balance", action="store_true", help="keep each faction's raw stage army instead of evening the strength")
    parser.add_argument("--keep-logs", action="store_true", help="keep worker jobs, logs and raw results")
    args = parser.parse_args()

    godot = find_godot(args.godot)
    run_dir = Path(args.out) if args.out else ROOT / ".artifacts" / "battle_ai_arena" / f"{datetime.now():%Y%m%d-%H%M%S}-{args.suite}"
    run_dir.mkdir(parents=True, exist_ok=True)
    variants_dir = run_dir / "variants"
    variants_dir.mkdir(exist_ok=True)
    variant_paths = {"A": variants_dir / "A.gd", "B": variants_dir / "B.gd"}
    resolve_variant(args.a, variant_paths["A"])
    resolve_variant(args.b, variant_paths["B"])
    # The router keeps the signatures the game was compiled against: the working tree's.
    router_path = run_dir / "router.gd"
    router_path.write_text(router.build_router(AI_SOURCE.read_text(encoding="utf-8")), encoding="utf-8")

    groups = build_suite(args.suite, not args.no_balance)
    workers = max(1, min(args.workers, len(groups)))
    maps_before = set(MAPS_DIR.iterdir()) if MAPS_DIR.exists() else set()
    print(f"Arena: {sum(len(g['battles']) for g in groups)} battles x 2 sides on {len(groups)} maps, {workers} workers ...")
    started = time.monotonic()
    rows, problems = run_workers(godot, run_dir, groups, workers, variant_paths, router_path, args.timeout)
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
