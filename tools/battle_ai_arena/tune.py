#!/usr/bin/env python3
"""Tunes the battle AI's weights (content/battle_ai_weights.json) with CMA-ES in the arena.

    python tools/battle_ai_arena/tune.py                        # 30 generations, about two hours
    python tools/battle_ai_arena/tune.py --generations 2 --population 4 --maps 6 --battles 1   # smoke run
    python tools/battle_ai_arena/tune.py --resume .artifacts/battle_ai_arena/tune-<time>

Evaluation tooling only, run on demand, like arena.py; see README.md here.

Each generation samples a population of weight sets around the current mean and plays every
one, and the mean itself, against the baseline (the game's current weights, or --base-weights)
on the same battles, both sides each. The battles are the arena's realistic ones (scenarios.py: guards,
AI heroes and sieges, armies built the way players build them), and every generation plays
fresh maps, armies and heroes, so the weights cannot fit one set of battles; the arena's
`standard` and `holdout` suites stay out of the loop and judge the result. A weight is searched as a power-of-two multiple of its current
value, so it keeps its sign and scale. The search is separable CMA-ES (sep-CMA-ES, Ros and
Hansen 2008): a diagonal covariance, which learns fast enough in about fifty dimensions on a
few dozen generations. Ranking candidates that played the same battles cancels most of the
noise of the armies.

Results go to .artifacts/battle_ai_arena/tune-<time>/: state.json (resumable), history.jsonl
(one line per generation) and weights.json (the current mean, the run's recommendation).
Check it with `arena.py --b-weights <dir>/weights.json` on `standard` and `holdout`.

No Godot runs (arena.py's README): match_sim_cli --arena-setup builds each generation's
battles up to their payloads, one generation ahead of the one being played, since the battles
do not depend on the weights, and battle_sim_cli plays the games.
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
import time
from datetime import datetime
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import arena  # noqa: E402
import scenarios  # noqa: E402

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


def training_groups(seed: int, generation: int, groups: int, battles: int, odds: tuple[float, float] | None) -> list[dict]:
    """Fresh realistic battles (scenarios.py) for this run and generation: never the arena's
    suites. With odds, only the contested ones are played."""
    return scenarios.build_suite("tune", f"{seed}-{generation}", groups, battles, odds)


class SetupAhead:
    """The native setup (match_sim_cli --arena-setup) of the generations of a run: release(n) starts building
    generation n's battles into gen_<n>/corpus, while the generation before plays; wait(n) returns that
    generation's setup rows when it is done. The content snapshot is written once, for the whole run."""

    def __init__(self, run_dir: Path, schedule: list[tuple[int, list[dict]]], threads: int, orders: list[list[str]]):
        self.run_dir = run_dir
        self.dir = run_dir / "setup"
        shutil.rmtree(self.dir, ignore_errors=True)
        self.dir.mkdir(parents=True)
        self.content = self.dir / "content.snap"
        arena.write_content(self.content)
        self.groups = dict(schedule)
        self.threads = threads
        self.orders = orders
        self.procs: dict[int, tuple[subprocess.Popen, Path, object]] = {}

    def release(self, gen: int) -> None:
        if gen not in self.groups or gen in self.procs:
            return
        gen_dir = self.run_dir / f"gen_{gen:03d}"
        shutil.rmtree(gen_dir, ignore_errors=True)
        (gen_dir / "corpus").mkdir(parents=True)
        groups = [dict(group, tag=str(gen), corpus_file=f"group_{index:05d}.snap") for index, group in enumerate(self.groups[gen])]
        job = self.dir / f"job_{gen:03d}.json"
        arena.setup_job(job, groups, self.orders, self.content, gen_dir / "corpus")
        results = self.dir / f"results_{gen:03d}.jsonl"
        log = (self.dir / f"setup_{gen:03d}.log").open("w", encoding="utf-8")
        cmd = [str(arena.SETUP_CLI), "--arena-setup", str(job), str(results)] + (["--threads", str(self.threads)] if self.threads else [])
        self.procs[gen] = (subprocess.Popen(cmd, stdout=log, stderr=subprocess.STDOUT), results, log)

    def wait(self, gen: int, timeout: int) -> tuple[list[dict], list[str]]:
        """The generation's setup rows once all its maps are done, and problems."""
        self.release(gen)
        proc, results, log = self.procs.pop(gen)
        problems = []
        try:
            proc.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
            problems.append(f"generation {gen}'s setup timed out")
        log.close()
        if proc.returncode not in (0, None):
            problems.append(f"generation {gen}'s setup exited with {proc.returncode} (see {self.dir / f'setup_{gen:03d}.log'})")
        rows = [json.loads(line) for line in results.read_text(encoding="utf-8").splitlines() if line.strip()] if results.exists() else []
        done = sum(1 for row in rows if row.get("kind") == "group_done")
        if done < len(self.groups[gen]) and not problems:
            problems.append(f"generation {gen}'s setup ended with {done} of {len(self.groups[gen])} maps done")
        return rows, problems

    def close(self, keep: bool) -> None:
        for proc, _results, log in self.procs.values():
            if proc.poll() is None:
                proc.kill()
            proc.wait()
            log.close()
        self.procs.clear()
        if not keep:
            shutil.rmtree(self.dir, ignore_errors=True)


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
    parser.add_argument("--generations", type=int, default=30)
    parser.add_argument("--population", type=int, default=16, help="weight sets per generation (default 16)")
    parser.add_argument("--sigma", type=float, default=0.5, help="initial step, in powers of two (default 0.5)")
    parser.add_argument("--maps", type=int, default=48, help="generated maps each generation (default 48)")
    parser.add_argument("--battles", type=int, default=3, help="battles generated per map (default 3)")
    parser.add_argument("--odds", default="0.6,1.7", help="play only battles whose odds fall in LOW,HIGH (default 0.6,1.7, about half); '' plays all")
    parser.add_argument("--setup-threads", type=int, default=max(1, (os.cpu_count() or 2) // 4),
                        help="threads of the next generation's setup, which runs while battle_sim_cli plays (default: a quarter of the cores)")
    parser.add_argument("--out", help="run directory (default .artifacts/battle_ai_arena/tune-<time>)")
    parser.add_argument("--resume", help="a run directory to continue")
    parser.add_argument("--base-weights", help="weights to search around and play against, for example an earlier run's weights.json (default: the game's)")
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--timeout", type=int, default=3600, help="seconds before a generation's setup or games are stopped")
    parser.add_argument("--keep-logs", action="store_true", help="keep each generation's jobs, logs and raw results")
    parser.add_argument("--threads", type=int, default=0, help="battle_sim_cli's threads (default: one per core)")
    args = parser.parse_args()

    base = arena.load_weights(args.base_weights)
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
        settings = {"population": args.population, "sigma": args.sigma, "maps": args.maps, "battles": args.battles, "odds": args.odds, "seed": args.seed}
        cma = SepCMA(len(keys), args.sigma, args.population)
        rng = np.random.default_rng([args.seed, 0])
    values = arena.unit_values()
    names = [f"c{i}" for i in range(settings["population"])] + ["mean"]
    orders = [order for name in names for order in ([name, "base"], ["base", name])]
    odds = arena.parse_odds(settings.get("odds", ""))
    schedule = [(gen, training_groups(settings["seed"], gen, settings["maps"], settings["battles"], odds)) for gen in range(cma.gen, args.generations)]
    ahead = SetupAhead(run_dir, schedule, args.setup_threads, orders)
    ahead.release(cma.gen)
    print(f"Tuning {len(keys)} weights, population {settings['population']}, {settings['battles'] * settings['maps']} battles generated a generation (odds {settings.get('odds') or 'any'}) -> {run_dir}")
    code = 1
    try:
        code = tune(args, run_dir, cma, rng, keys, base, settings, values, names, orders, ahead)
        return code
    finally:
        # A failed run keeps the setup's jobs and logs.
        ahead.close(args.keep_logs or code != 0)


def tune(args, run_dir: Path, cma: SepCMA, rng, keys: list[str], base: dict[str, float], settings: dict, values: dict[str, float],
         names: list[str], orders: list[list[str]], ahead: SetupAhead) -> int:
    run_started = time.monotonic()
    run_games = 0
    while cma.gen < args.generations:
        gen = cma.gen
        started = time.monotonic()
        gen_dir = run_dir / f"gen_{gen:03d}"
        xs = cma.ask(rng)
        points = list(xs) + [cma.mean]
        weights = {"base": base, **{name: to_weights(x, keys, base) for name, x in zip(names, points)}}
        # The next generation's maps build while this one plays.
        ahead.release(gen + 1)
        waited = time.monotonic()
        rows, problems = ahead.wait(gen, args.timeout)
        split = {"setup_wait": round(time.monotonic() - waited, 1)}
        games, cli_problems, stats = arena.play_cli(gen_dir, ahead.content, gen_dir / "corpus", {name: arena.full_weights(w) for name, w in weights.items()},
                                                    orders, "base", args.timeout, args.threads)
        split["battle_sim_cli"] = round(float(stats.get("seconds", 0.0)), 1)
        split["battle_sim_cli_wall"] = stats.get("wall_seconds", 0.0)
        shutil.rmtree(gen_dir / "corpus", ignore_errors=True)
        rows, problems = rows + games, problems + cli_problems
        games_played = sum(1 for row in rows if row.get("kind") == "game")
        run_games += games_played
        scores = candidate_scores(rows, names, values)
        # Battles outside the odds band are skipped, the same ones for every candidate.
        expected = max(len(s) for s in scores.values())
        short = {name: len(s) for name, s in scores.items() if len(s) < expected * 0.9 or not s}
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
            "games": games_played,
            # The seconds spent waiting for the setup, and battle_sim_cli's own.
            **split,
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
            f"gen {gen:3d}  {record['seconds']:6.0f}s  {games_played} games  "
            + f"(setup wait {split['setup_wait']:.0f}s, battle_sim_cli {split['battle_sim_cli']:.0f}s)  "
            + f"mean {record['mean_score']:.4f}  best {record['best_score']:.4f}  "
            f"population {record['population_score']:.4f}  sigma {record['sigma']:.3f}  "
            + "  ".join(f"{k} x{v}" for k, v in moved),
            flush=True,
        )
    wall = time.monotonic() - run_started
    print(f"Done: {run_dir / 'weights.json'} ({run_games} games in {wall:.0f}s, {run_games / max(wall, 1e-9):.1f} games/s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
