"""Realistic battles for the battle AI arena: the kinds of fights a game is made of.

A suite is a list of groups; a group is one generated map (size, players and monster strength
as the skirmish menu offers them) with one player faction and hero, and a handful of battles on
it. Every battle is one of:

- guard: the player's hero against a neutral guard exactly as the generator placed it, picked
  so the guard rates a sampled share of the hero's strength (an easy fight up to a hard one);
- hero: against a computer player's hero with an army of its own, a few weeks ahead or behind;
- siege: against an enemy town's garrison, behind the walls its fort level gives, with a
  defending hero or the town's captain.

Armies are recruited the way players build them, from the factions' town rosters
(content/town_development.json): a build plan picks one of the two dwellings of each tier
(ranged only, melee only, either, the top tiers, or the low tiers), dwellings open over the
weeks, upgrades come with time, a second town adds the other dwelling, now and then a neutral
stack joins, and gold limits what is bought, top tier first. Heroes are any of the faction's,
at a level, guild spells and mana for the week. Nothing is evened out: the arena plays every
battle from both sides, so the armies cancel and only the AI decides the score.
"""
from __future__ import annotations

import json
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

# How often each kind of battle comes up in a game.
TYPE_WEIGHTS = {"guard": 0.55, "hero": 0.30, "siege": 0.15}
# Weeks into the game: early fights are the most common.
WEEK_WEIGHTS = {1: 0.17, 2: 0.17, 3: 0.15, 4: 0.13, 5: 0.11, 6: 0.10, 8: 0.09, 10: 0.08}
# Build plans. "ranged" builds only ranged dwellings where the tier offers one.
DOCTRINE_WEIGHTS = {"balanced": 0.35, "ranged": 0.25, "melee": 0.15, "top_heavy": 0.13, "swarm": 0.12}
# The guard's strength over the hero's (AiHeroRules.army_power): an easy fight to a hard one.
GUARD_RATIOS = {0.3: 0.2, 0.6: 0.3, 0.9: 0.3, 1.3: 0.2}
MONSTER_STRENGTHS = ["weak", "normal", "strong"]
MAP_SIZES = {"homm3_small": 0.7, "homm3_medium": 0.3}
RESOURCE_GOLD_VALUE = 250
MAX_STACKS = 7


def _items(name: str) -> list[dict]:
    data = json.loads((ROOT / "content" / name).read_text(encoding="utf-8"))
    return data.get("items", data) if isinstance(data, dict) else data


def _pick(rng: random.Random, weights: dict):
    return rng.choices(list(weights), weights=list(weights.values()))[0]


class Content:
    def __init__(self) -> None:
        self.units = {u["id"]: u for u in _items("units.json")}
        self.factions = [f for f in _items("factions.json") if f.get("hero_ids")]
        self.rosters = json.loads((ROOT / "content" / "town_development.json").read_text(encoding="utf-8"))["rosters"]
        self.factions = [f for f in self.factions if f["id"] in self.rosters]
        towns = {t["id"]: t for t in _items("towns.json")}
        self.guild = {
            f["id"]: {int(tier["tier"]): list(tier.get("spell_ids", [])) for tier in towns.get(f.get("seed_town_id", ""), {}).get("spell_library", [])}
            for f in self.factions
        }
        self.neutral_units = sorted({uid for d in _items("neutral_dwellings.json") for uid in d.get("unit_ids", []) if uid in self.units})

    def value(self, unit_id: str) -> float:
        cost = self.units[unit_id].get("cost", {}) or {}
        return float(cost.get("gold", 0)) + sum(float(v) * RESOURCE_GOLD_VALUE for k, v in cost.items() if k != "gold")

    def ranged(self, unit_id: str) -> bool:
        return bool(self.units.get(unit_id, {}).get("ranged", False))


def _top_tier(week: int, rng: random.Random) -> int:
    if week <= 1:
        return 4 if rng.random() < 0.4 else 3
    if week == 2:
        return 4
    if week == 3:
        return 5
    if week == 4:
        return 6 if rng.random() < 0.5 else 5
    if week == 5:
        return 7 if rng.random() < 0.4 else 6
    return 7


# Weeks before a tier's dwelling usually stands.
TIER_DELAY = {1: 0.0, 2: 0.0, 3: 0.4, 4: 0.8, 5: 1.4, 6: 2.4, 7: 3.4}


def _gold_budget(week: int, rng: random.Random) -> float:
    earned = 4000 + 6500 * week + 2500 * max(0, week - 3)
    return earned * rng.uniform(0.55, 0.85)  # the rest went into buildings


def compose_army(content: Content, faction: str, week: int, doctrine: str, rng: random.Random, budget_scale: float = 1.0) -> list[dict]:
    rows = content.rosters[faction]
    top = _top_tier(week, rng)
    upgrade_chance = min(0.85, 0.1 + 0.15 * (week - 1))
    dwellings = []
    for tier in range(1, top + 1):
        options = [r for r in rows if int(r["tier"]) == tier]
        if not options:
            continue
        ranged = [r for r in options if content.ranged(r["unit_id"])]
        melee = [r for r in options if not content.ranged(r["unit_id"])]
        if doctrine == "ranged":
            chosen = ranged or ([rng.choice(melee)] if rng.random() < 0.25 else [])
            chosen = chosen[:1] if chosen else []
        elif doctrine == "melee":
            chosen = [rng.choice(melee or ranged)]
        elif doctrine == "top_heavy" and tier < top - 2 and rng.random() > 0.3:
            chosen = []
        elif doctrine == "swarm" and tier >= 5:
            chosen = []
        else:
            chosen = [rng.choice(options)]
        if chosen and week >= 4 and rng.random() < 0.3:
            others = [r for r in options if r is not chosen[0] and (doctrine != "ranged" or content.ranged(r["unit_id"]))]
            if others:
                chosen.append(rng.choice(others))
        for row in chosen:
            unit = row["unit_id"]
            if row.get("upgraded_unit_id") and rng.random() < upgrade_chance:
                unit = row["upgraded_unit_id"]
            weeks = max(0.5, min(float(week), week - TIER_DELAY[tier] + rng.uniform(-0.3, 0.3)))
            growth = float(content.units[row["unit_id"]].get("growth", 1))
            dwellings.append({"unit_id": unit, "tier": tier, "available": max(1, int(round(growth * weeks)))})
    if rng.random() < 0.15 and content.neutral_units:
        unit = rng.choice([u for u in content.neutral_units if int(content.units[u].get("tier", 1)) <= top] or content.neutral_units)
        dwellings.append({"unit_id": unit, "tier": int(content.units[unit].get("tier", 1)), "available": max(1, int(round(float(content.units[unit].get("growth", 4)) * rng.uniform(0.5, 1.5))))})
    budget = _gold_budget(week, rng) * budget_scale * (1.3 if doctrine == "swarm" else 1.0)
    stacks: dict[str, int] = {}
    for dwelling in sorted(dwellings, key=lambda d: -d["tier"]):
        price = max(1.0, content.value(dwelling["unit_id"]))
        count = min(dwelling["available"], int(budget // price))
        if count <= 0:
            continue
        budget -= count * price
        stacks[dwelling["unit_id"]] = stacks.get(dwelling["unit_id"], 0) + count
    if not stacks and dwellings:
        low = min(dwellings, key=lambda d: content.value(d["unit_id"]))
        stacks[low["unit_id"]] = max(1, low["available"] // 2)
    ordered = sorted(stacks.items(), key=lambda kv: -kv[1] * content.value(kv[0]))[:MAX_STACKS]
    return [{"unit_id": unit, "count": count} for unit, count in ordered]


def hero_spec(content: Content, faction: str, week: int, rng: random.Random, hero_id: str = "") -> dict:
    faction_row = next(f for f in content.factions if f["id"] == faction)
    spell_tier = 1 if week <= 1 else (2 if week <= 3 else 3)
    spells = [s for tier, ids in content.guild[faction].items() if tier <= spell_tier for s in ids if rng.random() < 0.85]
    return {
        "hero_id": hero_id or rng.choice(faction_row["hero_ids"]),
        "level": max(1, min(20, int(round(1 + 1.3 * week + rng.uniform(-1.0, 1.0))))),
        "spell_ids": spells,
        "mana": round(rng.uniform(0.35, 1.0), 2),
    }


def build_battle(content: Content, rng: random.Random, battle_id: str, faction: str, hero_id: str) -> dict:
    kind = _pick(rng, TYPE_WEIGHTS)
    week = _pick(rng, WEEK_WEIGHTS)
    doctrine = _pick(rng, DOCTRINE_WEIGHTS)
    battle = {
        "battle_id": battle_id,
        "type": kind,
        "week": week,
        "player_doctrine": doctrine,
        "player_army": compose_army(content, faction, week, doctrine, rng),
        "player_hero": hero_spec(content, faction, week, rng, hero_id),
        "site_index": rng.randrange(1000),
    }
    if kind == "guard":
        battle["guard_ratio"] = _pick(rng, GUARD_RATIOS)
    elif kind == "hero":
        enemy = rng.choice(content.factions)["id"]
        enemy_week = max(1, min(12, week + rng.randint(-2, 2)))
        enemy_doctrine = _pick(rng, DOCTRINE_WEIGHTS)
        battle.update({
            "enemy_faction": enemy,
            "enemy_week": enemy_week,
            "enemy_doctrine": enemy_doctrine,
            "enemy_army": compose_army(content, enemy, enemy_week, enemy_doctrine, rng),
            "enemy_hero": hero_spec(content, enemy, enemy_week, rng),
        })
    else:
        garrison_doctrine = _pick(rng, DOCTRINE_WEIGHTS)
        garrison_week = max(1, week + rng.randint(-1, 1))
        with_hero = rng.random() < 0.5
        battle.update({
            "enemy_doctrine": garrison_doctrine,
            "enemy_week": garrison_week,
            # The town's faction is known only on the map, so every faction's garrison is given.
            "garrison_by_faction": {
                f["id"]: compose_army(content, f["id"], garrison_week, garrison_doctrine, rng, budget_scale=0.7) for f in content.factions
            },
            "defender_by_faction": {
                f["id"]: hero_spec(content, f["id"], garrison_week, rng) for f in content.factions
            } if with_hero else {},
            "fort_level": 0 if week < 2 else (1 if week < 4 else (2 if week < 7 else 3)),
            "faction_defense": week >= 3 and rng.random() < 0.5,
        })
    return battle


def build_suite(name: str, seed: int | str, groups: int, battles_per_group: int) -> list[dict]:
    """groups maps of battles_per_group battles each, reproducible from (name, seed)."""
    content = Content()
    rng = random.Random(f"battle-ai-arena:{name}:{seed}")
    suite = []
    for index in range(groups):
        faction = content.factions[index % len(content.factions)]
        size = _pick(rng, MAP_SIZES)
        group = {
            "group_id": f"{name}:{seed}:{index}",
            "map_seed": f"battle-ai-arena-{name}-{seed}-{index}",
            "map_size": size,
            "player_count": rng.randint(2, 3) if size == "homm3_small" else rng.randint(2, 4),
            "monster_strength": MONSTER_STRENGTHS[index // len(content.factions) % len(MONSTER_STRENGTHS)],
            "player_faction": faction["id"],
            "player_hero_id": rng.choice(faction["hero_ids"]),
            "battles": [],
        }
        for b_index in range(battles_per_group):
            group["battles"].append(build_battle(content, rng, f"{group['group_id']}:{b_index}", faction["id"], group["player_hero_id"]))
        suite.append(group)
    return suite


if __name__ == "__main__":
    import collections
    import sys

    suite = build_suite("preview", sys.argv[1] if len(sys.argv) > 1 else 1, 6, 6)
    content = Content()
    kinds = collections.Counter(b["type"] for g in suite for b in g["battles"])
    print(kinds)
    for battle in suite[0]["battles"][:4]:
        army = ", ".join(f"{s['count']} {s['unit_id'].replace('unit_', '')}{'*' if content.ranged(s['unit_id']) else ''}" for s in battle["player_army"])
        print(f"{battle['type']:5s} week {battle['week']} {battle['player_doctrine']:9s} L{battle['player_hero']['level']} spells {len(battle['player_hero']['spell_ids'])}: {army}")
