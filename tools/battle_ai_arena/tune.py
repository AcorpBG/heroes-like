#!/usr/bin/env python3
"""Tunes the battle AI's weights (content/battle_ai_weights.json) with CMA-ES in the arena.

    python tools/battle_ai_arena/tune.py                        # 40 generations, about 2-3 hours
    python tools/battle_ai_arena/tune.py --generations 2 --population 4 --battles 1   # smoke run
    python tools/battle_ai_arena/tune.py --resume .artifacts/battle_ai_arena/tune-<time>

Evaluation tooling only, run on demand, like arena.py; see README.md here.

Each generation samples a population of weight sets around the current mean and plays every
one, and the mean itself, against the game's current weights (the baseline) on the same
battles, both sides each. Every generation plays fresh maps, sites and heroes, so the weights
cannot fit one set of battles; the arena's `standard` and `holdout` suites stay out of the
loop and judge the result. A weight is searched as a power-of-two multiple of its current
value, so it keeps its sign and scale. The search is separable CMA-ES (sep-CMA-ES, Ros and
Hansen 2008): a diagonal covariance, which learns fast enough in about fifty dimensions on a
few dozen generations. Ranking candidates that played the same battles cancels most of the
noise of the armies.

Results go to .artifacts/battle_ai_arena/tune-<time>/: state.json (resumable), history.jsonl
(one line per generation) and weights.json (the current mean, the run's recommendation).
Check it with `arena.py --b-weights <dir>/weights.json` on `standard` and `holdout`.
"""
from __future__ import annotations

import argparse
import json
import math
import os
import shutil
import statistics
import sys
import time
from datetime import datetime
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import arena  # noqa: E402
import router  # noqa: E402

SEARCH_LIMIT = 3.0  # a weight stays within 1/8 and 8 times its current value


class SepCMA:
    """Separable CMA-ES on a minimisation problem (Ros and Hansen 2008)."""

    def __init__(self, n: int, sigma: float, population: int, state: dict | None = None):
        self.n = n
        self.lam = population
        self.mu = population // 2
        raw = np.log(self.mu + 0.5) - np.log(np.arange(1, self.mu + 1))
        self.w = raw / raw.sum()
        self.mueff = 1.0 / float(np.sum(self.w ** 2))
        self.cs = (self.mueff + 2) / (n + self.mueff + 5)
        self.ds = 1 + 2 * max(0.0, math.sqrt((self.mueff - 1) / (n + 1)) - 1) + self.cs
        self.cc = (4 + self.mueff / n) / (n + 4 + 2 * self.mueff / n)
        scale = (n + 2) / 3.0  # sep-CMA's faster learning of a diagonal covariance
        self.c1 = min(1.0, scale * 2 / ((n + 1.3) ** 2 + self.mueff))
        self.cmu = min(1 - self.c1, scale * 2 * (self.mueff - 2 + 1 / self.mueff) / ((n + 2) ** 2 + self.mueff))
        self.chi = math.sqrt(n) * (1 - 1 / (4 * n) + 1 / (21 * n * n))
        if state:
            self.mean = np.array(state["mean"])
            self.sigma = float(state["sigma"])
            self.diag = np.array(state["diag"])
            self.ps = np.array(state["ps"])
            self.pc = np.array(state["pc"])
            self.gen = int(state["gen"])
        else:
            self.mean = np.zeros(n)
            self.sigma = sigma
            self.diag = np.ones(n)  # the covariance's diagonal
            self.ps = np.zeros(n)
            self.pc = np.zeros(n)
            self.gen = 0

    def ask(self, rng: np.random.Generator) -> np.ndarray:
        self._z = rng.standard_normal((self.lam, self.n))
        return self.mean + self.sigma * self._z * np.sqrt(self.diag)

    def tell(self, xs: np.ndarray, losses: list[float]) -> None:
        order = np.argsort(losses, kind="stable")[: self.mu]
        ys = (xs[order] - self.mean) / self.sigma
        yw = self.w @ ys
        self.mean = self.mean + self.sigma * yw
        self.ps = (1 - self.cs) * self.ps + math.sqrt(self.cs * (2 - self.cs) * self.mueff) * yw / np.sqrt(self.diag)
        norm = float(np.linalg.norm(self.ps))
        hs = norm / math.sqrt(1 - (1 - self.cs) ** (2 * (self.gen + 1))) < (1.4 + 2 / (self.n + 1)) * self.chi
        self.pc = (1 - self.cc) * self.pc + (math.sqrt(self.cc * (2 - self.cc) * self.mueff) * yw if hs else 0.0)
        rank_mu = self.w @ (ys ** 2)
        self.diag = (
            (1 - self.c1 - self.cmu) * self.diag
            + self.c1 * (self.pc ** 2 + (0.0 if hs else self.cc * (2 - self.cc)) * self.diag)
            + self.cmu * rank_mu
        )
        self.sigma *= math.exp((self.cs / self.ds) * (norm / self.chi - 1))
        self.gen += 1

    def state(self) -> dict:
        return {
            "mean": self.mean.tolist(), "sigma": self.sigma, "diag": self.diag.tolist(),
            "ps": self.ps.tolist(), "pc": self.pc.tolist(), "gen": self.gen,
        }


def training_groups(generation: int, battles: int) -> list[dict]:
    """Every faction at every stage on a map of its own, against `battles` rotating opponents."""
    factions = [f for f in arena.load_items("factions.json") if len(f.get("unit_ladder_ids", [])) >= 7 and f.get("hero_ids")]
    groups = []
    for p_index, player in enumerate(factions):
        for s_index, stage in enumerate(arena.STAGES):
            hero_ids = player["hero_ids"]
            group = {
                "group_id": f"tune:g{generation}:{player['id']}:{stage['id']}",
                "map_seed": f"battle-ai-tune-g{generation}-{player['id']}-{stage['id']}",
                "map_size": "homm3_small",
                "player_faction": player["id"],
                "player_hero_id": hero_ids[(generation + s_index) % len(hero_ids)],
                "stage": stage,
                "balance": True,
                "battles": [],
            }
            for b_index in range(battles):
                enemy = factions[(p_index + generation + b_index * 2 + s_index) % len(factions)]
                enemy_heroes = enemy["hero_ids"]
                group["battles"].append({
                    "battle_id": f"{group['group_id']}:{b_index}",
                    "site_index": generation * battles + b_index,
                    "enemy_faction": enemy["id"],
                    "enemy_hero_id": enemy_heroes[(generation + s_index + b_index + 1) % len(enemy_heroes)],
                })
            groups.append(group)
    return groups


def to_weights(x: np.ndarray, keys: list[str], base: dict[str, float]) -> dict[str, float]:
    clipped = np.clip(x, -SEARCH_LIMIT, SEARCH_LIMIT)
    return {key: base[key] * float(2.0 ** value) for key, value in zip(keys, clipped)}


def candidate_scores(rows: list[dict], names: list[str], values: dict[str, float]) -> dict[str, list[float]]:
    """Each candidate's score per battle against the baseline: its mean over both sides."""
    games: dict[tuple[str, str], dict[str, float]] = {}
    for row in rows:
        if row.get("kind") != "game" or row.get("error"):
            continue
        scored = arena.score_game(row, values)
        if scored is None:
            continue
        if row["enemy_variant"] == "base":
            games.setdefault((row["player_variant"], row["battle_id"]), {})["player"] = scored["player_score"]
        elif row["player_variant"] == "base":
            games.setdefault((row["enemy_variant"], row["battle_id"]), {})["enemy"] = 1.0 - scored["player_score"]
    scores: dict[str, list[float]] = {name: [] for name in names}
    for (name, _battle), sides in sorted(games.items()):
        if name in scores and len(sides) == 2:
            scores[name].append((sides["player"] + sides["enemy"]) / 2.0)
    return scores


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--generations", type=int, default=40)
    parser.add_argument("--population", type=int, default=16, help="weight sets per generation (default 16)")
    parser.add_argument("--sigma", type=float, default=0.5, help="initial step, in powers of two (default 0.5)")
    parser.add_argument("--battles", type=int, default=3, help="battles per faction and stage each generation (default 3)")
    parser.add_argument("--workers", type=int, default=max(1, (os.cpu_count() or 2) * 3 // 4))
    parser.add_argument("--godot", help="Godot binary")
    parser.add_argument("--out", help="run directory (default .artifacts/battle_ai_arena/tune-<time>)")
    parser.add_argument("--resume", help="a run directory to continue")
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--timeout", type=int, default=3600, help="seconds before a generation's workers are stopped")
    parser.add_argument("--keep-logs", action="store_true", help="keep each generation's jobs, logs and raw results")
    args = parser.parse_args()

    godot = arena.find_godot(args.godot)
    base = arena.load_weights()
    if args.resume:
        run_dir = Path(args.resume)
        saved = json.loads((run_dir / "state.json").read_text(encoding="utf-8"))
        keys, base, settings = saved["keys"], saved["base"], saved["settings"]
        cma = SepCMA(len(keys), settings["sigma"], settings["population"], saved["cma"])
        rng = np.random.default_rng([settings["seed"], cma.gen])
    else:
        run_dir = Path(args.out) if args.out else arena.ROOT / ".artifacts" / "battle_ai_arena" / f"tune-{datetime.now():%Y%m%d-%H%M%S}"
        run_dir.mkdir(parents=True, exist_ok=True)
        keys = sorted(base)
        settings = {"population": args.population, "sigma": args.sigma, "battles": args.battles, "seed": args.seed}
        cma = SepCMA(len(keys), args.sigma, args.population)
        rng = np.random.default_rng([args.seed, 0])
    values = arena.unit_values()
    source = arena.AI_SOURCE.read_text(encoding="utf-8")
    router_path = run_dir / "router.gd"
    router_path.write_text(router.build_router(source), encoding="utf-8")
    print(f"Tuning {len(keys)} weights, population {settings['population']}, {settings['battles'] * 24} battles a generation -> {run_dir}")

    while cma.gen < args.generations:
        gen = cma.gen
        started = time.monotonic()
        gen_dir = run_dir / f"gen_{gen:03d}"
        if gen_dir.exists():
            shutil.rmtree(gen_dir)
        variants_dir = gen_dir / "variants"
        variants_dir.mkdir(parents=True)
        xs = cma.ask(rng)
        names = [f"c{i}" for i in range(len(xs))] + ["mean"]
        points = list(xs) + [cma.mean]
        paths = {"base": variants_dir / "base.gd"}
        arena.resolve_variant("current", paths["base"], base)
        for name, x in zip(names, points):
            paths[name] = variants_dir / f"{name}.gd"
            arena.resolve_variant("current", paths[name], to_weights(x, keys, base))
        orders = [order for name in names for order in ([name, "base"], ["base", name])]
        groups = training_groups(gen, settings["battles"])
        rows, problems = arena.run_workers(godot, gen_dir, groups, min(args.workers, len(groups)), paths, router_path, args.timeout, orders, "base")
        scores = candidate_scores(rows, names, values)
        expected = settings["battles"] * len(groups)
        short = {name: len(s) for name, s in scores.items() if len(s) < expected * 0.9}
        if problems or short:
            print(f"generation {gen}: {len(problems)} problems, short candidates {short}")
            for line in problems[:10]:
                print(f"  {line}")
            print(f"Logs kept in {gen_dir}; resume with --resume {run_dir}")
            return 1
        means = {name: statistics.fmean(s) for name, s in scores.items()}
        cma.tell(xs, [-means[f"c{i}"] for i in range(len(xs))])
        mean_weights = to_weights(cma.mean, keys, base)
        record = {
            "generation": gen,
            "seconds": round(time.monotonic() - started, 1),
            "mean_score": round(means["mean"], 4),
            "best_score": round(max(means[f"c{i}"] for i in range(len(xs))), 4),
            "population_score": round(statistics.fmean(means[f"c{i}"] for i in range(len(xs))), 4),
            "sigma": round(cma.sigma, 4),
            "battles": len(scores["mean"]),
            "multipliers": {key: round(2.0 ** float(np.clip(v, -SEARCH_LIMIT, SEARCH_LIMIT)), 3) for key, v in zip(keys, cma.mean)},
        }
        with (run_dir / "history.jsonl").open("a", encoding="utf-8", newline="\n") as handle:
            handle.write(json.dumps(record) + "\n")
        (run_dir / "weights.json").write_text(json.dumps({"generation": cma.gen, "weights": {k: round(v, 6) for k, v in mean_weights.items()}}, indent=2) + "\n", encoding="utf-8")
        (run_dir / "state.json").write_text(json.dumps({"keys": keys, "base": base, "settings": settings, "cma": cma.state()}), encoding="utf-8")
        if not args.keep_logs:
            shutil.rmtree(gen_dir)
        moved = sorted(record["multipliers"].items(), key=lambda kv: -abs(math.log2(kv[1])))[:4]
        print(
            f"gen {gen:3d}  {record['seconds']:6.0f}s  mean {record['mean_score']:.4f}  best {record['best_score']:.4f}  "
            f"population {record['population_score']:.4f}  sigma {record['sigma']:.3f}  "
            + "  ".join(f"{k} x{v}" for k, v in moved),
            flush=True,
        )
    print(f"Done: {run_dir / 'weights.json'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
