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

With --backend cli (the default) battle_sim_cli plays the games (arena.py's README): Godot
setup workers, booted once for the whole run, build each generation's battles up to their
payloads, one generation ahead of the one being played, since the battles do not depend on
the weights; --backend godot plays every game in Godot workers, a generation at a time.
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
    """Godot setup workers (worker.gd setup jobs) for the generations of a run, booted once: each
    builds its share of every generation's battles into gen_<n>/corpus, a generation's maps
    starting once release(n) is called. wait(n) returns that generation's setup rows when all its
    maps are done."""

    def __init__(self, godot: str, run_dir: Path, schedule: list[tuple[int, list[dict]]], workers: int, orders: list[list[str]]):
        self.dir = run_dir / "setup"
        shutil.rmtree(self.dir, ignore_errors=True)
        self.dir.mkdir(parents=True)
        self.content = self.dir / "content.snap"
        self.expected: dict[str, int] = {}
        self.done: dict[str, list[dict]] = {}
        self.profiles: list[str] = []
        self.procs = []
        self.read = {}
        jobs: list[list[dict]] = [[] for _ in range(workers)]
        for gen, groups in schedule:
            gen_dir = run_dir / f"gen_{gen:03d}"
            shutil.rmtree(gen_dir, ignore_errors=True)
            (gen_dir / "corpus").mkdir(parents=True)
            self.expected[str(gen)] = len(groups)
            self.done[str(gen)] = []
            for index, group in enumerate(groups):
                jobs[index % workers].append(dict(
                    group, tag=str(gen), corpus_dir=str(gen_dir / "corpus"), corpus_file=f"group_{index:05d}.snap",
                    wait_for=str(gen_dir / "go"),
                ))
        for index, chunk in enumerate(jobs):
            if not chunk:
                continue
            job = self.dir / f"job_{index}.json"
            job.write_text(json.dumps({
                "plain": True, "orders": orders, "groups": chunk,
                # The first worker writes the content snapshot as it boots.
                "setup": {"content": str(self.content) if index == 0 else ""},
            }), encoding="utf-8")
            self.procs.append(arena.start_worker(godot, self.dir, index, job, False, self.profiles))
            self.read[index] = (0, [])  # bytes read, rows of the map in progress

    def release(self, gen: int) -> None:
        if str(gen) in self.expected:
            (self.dir.parent / f"gen_{gen:03d}" / "go").write_text("", encoding="utf-8")

    def _poll(self) -> None:
        """Takes the workers' new rows: a map's rows end with its group_done."""
        for index, _proc, out, _log in self.procs:
            offset, group_rows = self.read[index]
            if not out.exists():
                continue
            with out.open("rb") as handle:
                handle.seek(offset)
                data = handle.read()
            end = data.rfind(b"\n") + 1
            for line in data[:end].decode("utf-8").splitlines():
                if not line.strip():
                    continue
                row = json.loads(line)
                if row.get("kind") == "worker_ready":
                    continue
                if row.get("kind") == "group_done":
                    self.done.setdefault(str(row.get("tag", "")), []).extend(group_rows + [row])
                    group_rows = []
                else:
                    group_rows.append(row)
            self.read[index] = (offset + end, group_rows)

    def wait(self, gen: int, timeout: int) -> tuple[list[dict], list[str]]:
        """The generation's setup rows once all its maps are done, and problems."""
        deadline = time.monotonic() + timeout
        tag = str(gen)
        while True:
            # Whether any worker is still going, before reading: a worker that ends has written all its rows.
            failed = any(proc.poll() not in (None, 0) for _index, proc, _out, _log in self.procs)
            alive = any(proc.poll() is None for _index, proc, _out, _log in self.procs)
            timed_out = time.monotonic() > deadline
            self._poll()
            finished = sum(1 for row in self.done[tag] if row.get("kind") == "group_done")
            if finished >= self.expected[tag]:
                return self.done[tag], self.problems()
            if failed or not alive or timed_out:
                problems = self.problems()
                if not failed:
                    problems.append(f"generation {gen}'s setup {'timed out' if timed_out else 'ended'} with {finished} of {self.expected[tag]} maps done")
                return self.done[tag], problems
            time.sleep(0.2)

    def problems(self) -> list[str]:
        found = []
        for index, proc, _out, _log in self.procs:
            log = self.dir / f"worker_{index}.log"
            errors = log.read_text(encoding="utf-8", errors="replace").count("SCRIPT ERROR") if log.exists() else 0
            if errors:
                found.append(f"setup worker {index}: {errors} script errors (see {log})")
            if proc.poll() not in (None, 0):
                found.append(f"setup worker {index} exited with {proc.returncode}")
        return found

    def close(self, keep: bool) -> None:
        for _index, proc, _out, log in self.procs:
            if proc.poll() is None:
                proc.kill()
            proc.wait()
            log.close()
        for profile in self.profiles:
            shutil.rmtree(profile, ignore_errors=True)
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
    parser.add_argument("--maps", type=int, default=48, help="generated maps each generation (default 48; several per worker even out the load)")
    parser.add_argument("--battles", type=int, default=3, help="battles generated per map (default 3)")
    parser.add_argument("--odds", default="0.6,1.7", help="play only battles whose odds fall in LOW,HIGH (default 0.6,1.7, about half); '' plays all")
    parser.add_argument("--workers", type=int, default=max(1, (os.cpu_count() or 2) * 3 // 4))
    parser.add_argument("--godot", help="Godot binary")
    parser.add_argument("--out", help="run directory (default .artifacts/battle_ai_arena/tune-<time>)")
    parser.add_argument("--resume", help="a run directory to continue")
    parser.add_argument("--base-weights", help="weights to search around and play against, for example an earlier run's weights.json (default: the game's)")
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--timeout", type=int, default=3600, help="seconds before a generation's workers are stopped")
    parser.add_argument("--keep-logs", action="store_true", help="keep each generation's jobs, logs and raw results")
    parser.add_argument("--backend", choices=("cli", "godot"), default="cli", help="cli: battle_sim_cli plays the games (default); godot: Godot workers play every game")
    parser.add_argument("--threads", type=int, default=0, help="battle_sim_cli's threads (default: one per core)")
    args = parser.parse_args()

    godot = arena.find_godot(args.godot)
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
    router_path = run_dir / "router.gd"
    ahead = None
    if args.backend == "cli":
        schedule = [(gen, training_groups(settings["seed"], gen, settings["maps"], settings["battles"], odds)) for gen in range(cma.gen, args.generations)]
        ahead = SetupAhead(godot, run_dir, schedule, max(1, min(args.workers, settings["maps"])), orders)
        ahead.release(cma.gen)
    else:
        router_path.write_text(router.build_router(arena.AI_SOURCE.read_text(encoding="utf-8")), encoding="utf-8")
    print(f"Tuning {len(keys)} weights, population {settings['population']}, {settings['battles'] * settings['maps']} battles generated a generation (odds {settings.get('odds') or 'any'}), backend {args.backend} -> {run_dir}")
    code = 1
    try:
        code = tune(args, run_dir, cma, rng, keys, base, settings, values, names, orders, odds, godot, router_path, ahead)
        return code
    finally:
        if ahead is not None:
            # A failed run keeps the setup workers' logs.
            ahead.close(args.keep_logs or code != 0)


def tune(args, run_dir: Path, cma: SepCMA, rng, keys: list[str], base: dict[str, float], settings: dict, values: dict[str, float],
         names: list[str], orders: list[list[str]], odds, godot: str, router_path: Path, ahead: SetupAhead | None) -> int:
    run_started = time.monotonic()
    run_games = 0
    while cma.gen < args.generations:
        gen = cma.gen
        started = time.monotonic()
        gen_dir = run_dir / f"gen_{gen:03d}"
        xs = cma.ask(rng)
        points = list(xs) + [cma.mean]
        weights = {"base": base, **{name: to_weights(x, keys, base) for name, x in zip(names, points)}}
        split = {}
        if ahead is not None:
            # The next generation's maps build while this one plays.
            ahead.release(gen + 1)
            waited = time.monotonic()
            rows, problems = ahead.wait(gen, args.timeout)
            split["setup_wait"] = round(time.monotonic() - waited, 1)
            games, cli_problems, stats = arena.play_cli(gen_dir, ahead.content, gen_dir / "corpus", {name: arena.full_weights(w) for name, w in weights.items()},
                                                        orders, "base", args.timeout, args.threads)
            split["battle_sim_cli"] = round(float(stats.get("seconds", 0.0)), 1)
            split["battle_sim_cli_wall"] = stats.get("wall_seconds", 0.0)
            shutil.rmtree(gen_dir / "corpus", ignore_errors=True)
            rows, problems = rows + games, problems + cli_problems
        else:
            if gen_dir.exists():
                shutil.rmtree(gen_dir)
            variants_dir = gen_dir / "variants"
            variants_dir.mkdir(parents=True)
            paths = {}
            for name, variant_weights in weights.items():
                paths[name] = variants_dir / f"{name}.gd"
                arena.resolve_variant("current", paths[name], variant_weights)
            groups = training_groups(settings["seed"], gen, settings["maps"], settings["battles"], odds)
            rows, problems = arena.run_workers(godot, gen_dir, groups, min(args.workers, len(groups)), paths, router_path, args.timeout, orders, "base")
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
            # cli backend: the seconds spent waiting for the Godot setup workers, and battle_sim_cli's own.
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
            + (f"(setup wait {split['setup_wait']:.0f}s, battle_sim_cli {split['battle_sim_cli']:.0f}s)  " if split else "")
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
