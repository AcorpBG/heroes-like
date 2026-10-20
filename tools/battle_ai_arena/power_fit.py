#!/usr/bin/env python3
"""Fits the strength estimate (AiHeroRules.army_power) to battle outcomes.

Plays realistic battles (scenarios.py) once each with the current battle AI on both sides,
fits army_power's terms to who won (a logistic fit on the log strength ratio, the battle
type as an offset), and prints the fitted terms and how often each estimate calls the
winner on battles the fit never saw. Copy the terms into content/ai_hero_weights.json
("army_power": power_*, ranged_power, hero_*), then rebuild the generated company catalog
with tools/build_generated_neutral_companies.py, which reads them from there.

    python tools/battle_ai_arena/power_fit.py                    # 30 maps of battles, ~25 min
    python tools/battle_ai_arena/power_fit.py --games <run>/games.jsonl   # refit played battles
    python tools/battle_ai_arena/power_fit.py --ceiling 3        # also: how much is luck

Evaluation tooling, as the rest of the arena: not part of the game or the core suite.
"""
from __future__ import annotations

import argparse
import json
import math
import sys
import time
from collections import defaultdict
from pathlib import Path

import numpy as np
from scipy.optimize import minimize

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent))
import arena  # noqa: E402
import router  # noqa: E402
import scenarios  # noqa: E402

TYPES = ["guard", "hero", "siege"]
# Fitted terms, their starting values (the game's, content/ai_hero_weights.json "army_power")
# and how they enter army_power.
ARMY_POWER = json.loads((arena.ROOT / "content" / "ai_hero_weights.json").read_text(encoding="utf-8"))["army_power"]
TERMS = {"health": ARMY_POWER["power_health"], "damage": ARMY_POWER["power_damage"],
         "ranged": math.log(ARMY_POWER["ranged_power"]), "defense": ARMY_POWER["power_per_defense"],
         "speed": ARMY_POWER["power_per_speed"], "initiative": ARMY_POWER["power_per_initiative"],
         "hero_command": ARMY_POWER["hero_command_power"], "hero_spell": ARMY_POWER["hero_spell_power"]}


def play(out: Path, first: int, seeds: int, dice: list[int], workers: int) -> Path:
    """Plays the battles of seeds first.. once each (and once per dice value), current AI on both sides."""
    out.mkdir(parents=True, exist_ok=True)
    variant = out / "A.gd"
    arena.resolve_variant("current", variant)
    router_path = out / "router.gd"
    router_path.write_text(router.build_router(arena.AI_SOURCE.read_text(encoding="utf-8")), encoding="utf-8")
    godot = arena.find_godot(None)
    games = out / "games.jsonl"
    for seed in range(first, first + seeds):
        groups = [dict(group, dice=d) for d in dice for group in scenarios.build_suite("power", f"power-{seed}", 48, 5, None)]
        run = out / f"seed_{seed}"
        run.mkdir(exist_ok=True)
        rows, problems = arena.run_workers(godot, run, groups, workers, {"A": variant}, router_path, 7200, [["A", "A"]], "A")
        with games.open("a", encoding="utf-8") as f:
            for row in rows:
                if row.get("kind") == "game":
                    row.pop("ai_calls", None)
                    f.write(json.dumps(row) + "\n")
        print(f"  seed {seed}: {sum(1 for r in rows if r.get('kind') == 'game')} games{', problems ' + str(problems[:3]) if problems else ''}", flush=True)
    return games


class Battles:
    """Played games as arrays: creature counts per side and unit, the heroes, type, winner."""

    def __init__(self, games: list[dict], units: list[dict]):
        index = {u["id"]: i for i, u in enumerate(units)}
        self.games = games
        self.C = np.zeros((len(games), 2, len(units)))
        self.hero = np.zeros((len(games), 2, 4))  # has hero, attack, defense, spell damage a round
        for i, g in enumerate(games):
            for s, side in enumerate(("player", "enemy")):
                for row in (g["start_ledger"].get(side, {}) or {}).get("rows", []):
                    if row.get("unit_id") in index:
                        self.C[i, s, index[row["unit_id"]]] += float(row.get("starting", 0))
                c = g.get(side + "_commander") or {}
                if c:
                    self.hero[i, s] = [1.0, c.get("attack", 0), c.get("defense", 0), c.get("spell_damage", 0.0)]
        self.T = np.array([[1.0 if g["type"] == t else 0.0 for t in TYPES] for g in games])
        self.y = np.array([g["_win"] for g in games])
        self.logged = np.log(np.array([g["player_power"] / max(1.0, g["enemy_power"]) for g in games]))
        self.close = np.abs(self.logged) <= math.log(1.5)


def unit_arrays(units: list[dict]) -> dict:
    get = lambda key, default=0.0: np.array([float(u.get(key, default) or default) for u in units])  # noqa: E731
    damage = np.maximum(0.5, (get("min_damage", 1) + get("max_damage", 1)) / 2)
    return {"log_hp": np.log(np.maximum(1.0, get("hp", 1))), "log_dmg": np.log(damage), "dmg": damage,
            "defense": get("defense"), "speed": get("speed"), "initiative": get("initiative"),
            "ranged": np.array([1.0 if u.get("ranged") else 0.0 for u in units])}


def log_power(terms: dict, b: Battles, ua: dict) -> np.ndarray:
    """log army_power of both sides, up to a constant, as AiHeroRules computes it."""
    v = np.exp(terms["health"] * ua["log_hp"] + terms["damage"] * ua["log_dmg"] + terms["defense"] * ua["defense"]
               + terms["speed"] * ua["speed"] + terms["initiative"] * ua["initiative"] + terms["ranged"] * ua["ranged"])
    total = b.C @ v
    per_round = b.C @ ua["dmg"]
    has, attack, defense, spell = (b.hero[..., k] for k in range(4))
    dealt = 1 + np.minimum(attack * 0.05, 3.0)
    taken = 1 - np.minimum(defense * 0.025, 0.7)
    hero = terms["hero_command"] * np.log(dealt / taken) + terms["hero_spell"] * np.log1p(spell / np.maximum(per_round, 1e-6))
    return np.log(np.maximum(total, 1e-9)) + has * hero


def logistic(x: np.ndarray, b: Battles) -> np.ndarray:
    """Slope and type offsets of P(win) = sigmoid(slope * x + offset[type])."""
    X = np.concatenate([x[:, None], b.T], 1)
    w = minimize(lambda w: nll(X @ w, b.y), np.array([5.0, 0, 0, 0]), method="L-BFGS-B").x
    return w


def nll(z: np.ndarray, y: np.ndarray) -> float:
    p = np.clip(1 / (1 + np.exp(-z)), 1e-9, 1 - 1e-9)
    return float(-np.sum(y * np.log(p) + (1 - y) * np.log(1 - p)))


def fit_terms(b: Battles, ua: dict) -> tuple[dict, np.ndarray]:
    keys = list(TERMS)
    x0 = np.array([TERMS[k] for k in keys] + [7.0, 0, 0, 0])

    def f(x):
        terms = dict(zip(keys, x[:len(keys)]))
        lp = log_power(terms, b, ua)
        return nll(x[len(keys)] * (lp[:, 0] - lp[:, 1]) + b.T @ x[len(keys) + 1:], b.y)
    x = minimize(f, x0, method="L-BFGS-B", options={"maxiter": 3000, "maxfun": 100000}).x
    return dict(zip(keys, x[:len(keys)])), x[len(keys):]


def report(label: str, z: np.ndarray, b: Battles) -> None:
    called = (z > 0) == (b.y > 0.5)
    print(f"  {label:34s} winner called {called.mean():.3f}, near-even battles (within 1.5x, {int(b.close.sum())}) "
          f"{called[b.close].mean():.3f}, log loss {nll(z, b.y) / len(b.y):.4f}")


CEILING_FIRST_SEED = 1001


def seed_number(game: dict) -> int:
    return int(game["battle_id"].split(":")[1].rsplit("-", 1)[1])


def load(path: Path, values: dict) -> tuple[list[dict], list[dict]]:
    """The battles to fit, and the battles replayed with other dice (seeds from CEILING_FIRST_SEED)."""
    plain, replays = [], []
    for line in path.read_text(encoding="utf-8").splitlines():
        g = json.loads(line)
        scored = arena.score_game(g, values)
        if g.get("error") or scored is None or scored["result"] == 0.5:
            continue
        g["_win"] = scored["result"]
        if seed_number(g) >= CEILING_FIRST_SEED:
            replays.append(g)
        elif not g.get("dice", 0):
            plain.append(g)
    return plain, replays


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--games", help="games.jsonl of an earlier run: refit without playing")
    parser.add_argument("--seeds", type=int, default=30, help="maps of 5 battles to play (default 30)")
    parser.add_argument("--ceiling", type=int, default=0, help="also replay this many maps with 8 other dice")
    parser.add_argument("--workers", type=int, default=24)
    args = parser.parse_args()
    started = time.monotonic()
    out = arena.ROOT / ".artifacts" / "battle_ai_arena" / (time.strftime("%Y%m%d-%H%M%S") + "-power")
    if args.games:
        games_path = Path(args.games)
    else:
        print(f"Playing {args.seeds * 240} battles (current battle AI on both sides) -> {out}")
        games_path = play(out, 1, args.seeds, [0], args.workers)
        if args.ceiling:
            play(out, CEILING_FIRST_SEED, args.ceiling, list(range(9)), args.workers)
    units = arena.load_items("units.json")
    ua = unit_arrays(units)
    plain, replays = load(games_path, arena.unit_values())
    seeds = sorted({seed_number(g) for g in plain})
    held = set(seeds[len(seeds) * 2 // 3:])
    train = Battles([g for g in plain if seed_number(g) not in held], units)
    test = Battles([g for g in plain if seed_number(g) in held], units)
    print(f"{len(train.games)} battles to fit, {len(test.games)} to test")
    w = logistic(train.logged, train)
    report("the game's estimate now", np.concatenate([test.logged[:, None], test.T], 1) @ w, test)
    terms, w = fit_terms(train, ua)
    lp = log_power(terms, test, ua)
    report("refitted terms", w[0] * (lp[:, 0] - lp[:, 1]) + test.T @ w[1:], test)
    print("Fitted terms (content/ai_hero_weights.json army_power): power_health %.3f, power_damage %.3f, "
          "power_per_defense %.3f, power_per_speed %.3f, power_per_initiative %.3f, ranged_power %.3f, "
          "hero_command_power %.3f, hero_spell_power %.3f" % (
              terms["health"], terms["damage"], terms["defense"], terms["speed"], terms["initiative"],
              math.exp(terms["ranged"]), terms["hero_command"], terms["hero_spell"]))
    print("Battle type against the estimate (x strength): guard %.3f, siege %.3f" % (
        math.exp((w[1] - w[2]) / w[0]), math.exp((w[3] - w[2]) / w[0])))
    if replays:
        by = defaultdict(list)
        for g in replays:
            by[g["battle_id"]].append(g["_win"])
        chances = [np.mean(v) for v in by.values() if len(v) >= 8]
        print(f"Luck: a predictor knowing each battle's true odds would call {np.mean([max(p, 1 - p) for p in chances]):.3f} "
              f"of {len(chances)} replayed battles")
    print(f"Done in {time.monotonic() - started:.0f}s")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
