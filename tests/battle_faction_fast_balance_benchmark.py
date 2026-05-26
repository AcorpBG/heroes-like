#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import math
import random
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "content"

STATUS_HARRIED = "status_harried"
STATUS_STAGGERED = "status_staggered"
COHESION_MIN = 0
COHESION_MAX = 10
MOMENTUM_MAX = 4
SIMULATION_GUARD_MAX_ROUNDS = 200
DEFAULT_SEEDS = 100
DEFAULT_WEEKS = [1, 2, 3, 4]
WEEK_BOUNDARY_DAYS = {1: 7, 2: 14, 3: 21, 4: 28}
BATTLE_RECRUITMENT_TIER_CAPS = {
    1: [3],
    2: [4, 5],
    3: [4, 5, 7],
    4: [4, 5, 7, 7],
}
BALANCE_MIN_WIN_RATE = 45.0
BALANCE_MAX_WIN_RATE = 55.0
MAX_SIDE_BIAS_POINTS = 7.0
MIN_AVERAGE_ROUNDS = 3.0
MAX_AVERAGE_ROUNDS = 50.0
INTERNAL_SIDE_A = "side_a"
INTERNAL_SIDE_B = "side_b"
PUBLIC_SIDE_NAMES = {
    INTERNAL_SIDE_A: "side_a",
    INTERNAL_SIDE_B: "side_b",
}


def load_items(filename: str) -> dict[str, dict[str, Any]]:
    with (CONTENT / filename).open(encoding="utf-8") as handle:
        payload = json.load(handle)
    return {str(item["id"]): item for item in payload.get("items", [])}


def clamp(value: float, low: float, high: float) -> float:
    return min(high, max(low, value))


def stable_seed(*parts: Any) -> int:
    digest = hashlib.sha256("|".join(str(part) for part in parts).encode("utf-8")).hexdigest()
    return int(digest[:16], 16)


def upper_median(values: list[int]) -> int:
    if not values:
        return 999
    ordered = sorted(values)
    return ordered[len(ordered) // 2]


def import_town_balance_module():
    path = ROOT / "tests" / "town_development_balance_report.py"
    spec = importlib.util.spec_from_file_location("town_development_balance_report", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not import {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class FastBattleBenchmark:
    def __init__(self) -> None:
        self.units = load_items("units.json")
        self.buildings = load_items("buildings.json")
        self.towns = load_items("towns.json")
        self.factions = load_items("factions.json")
        self.heroes = load_items("heroes.json")
        self.spells = load_items("spells.json")
        self.town_balance = import_town_balance_module()
        self.town_reports = self._simulate_towns()
        self.faction_models = self._build_faction_models()

    def _simulate_towns(self) -> dict[str, dict[str, Any]]:
        reports: dict[str, dict[str, Any]] = {}
        for town_id, town in self.towns.items():
            faction = self.factions.get(str(town.get("faction_id", "")), {})
            if not faction:
                continue
            reports[town_id] = self.town_balance.simulate_town(town, faction, self.buildings)
        return reports

    def _unit_ladder(self, faction: dict[str, Any]) -> list[str]:
        ladder = [str(unit_id) for unit_id in faction.get("unit_ladder_ids", [])]
        if len(ladder) == 7:
            return ladder
        candidates: dict[int, str] = {}
        faction_id = str(faction.get("id", ""))
        for unit in self.units.values():
            if str(unit.get("faction_id", "")) != faction_id:
                continue
            tier = int(unit.get("tier", 0))
            if tier <= 0:
                continue
            if str(unit.get("content_status", "")) == "six_faction_scaffold":
                candidates[tier] = str(unit["id"])
            else:
                candidates.setdefault(tier, str(unit["id"]))
        return [candidates.get(tier, "") for tier in range(1, 8)]

    def _town_unlock_days(self, town_id: str, ladder: list[str]) -> dict[str, int]:
        town = self.towns[town_id]
        report = self.town_reports[town_id]
        starting = {str(value) for value in town.get("starting_building_ids", [])}
        build_day = {str(row["building_id"]): int(row["day"]) for row in report.get("build_log", [])}
        result: dict[str, int] = {}
        for unit_id in ladder:
            days: list[int] = []
            for building_id, building in self.buildings.items():
                if str(building.get("unlock_unit_id", "")) != unit_id:
                    continue
                if building_id in starting:
                    days.append(1)
                elif building_id in build_day:
                    days.append(build_day[building_id])
            result[unit_id] = min(days) if days else 999
        return result

    def _built_buildings_by_day(self, town_id: str, day: int) -> list[str]:
        town = self.towns[town_id]
        built = [str(value) for value in town.get("starting_building_ids", [])]
        for entry in self.town_reports[town_id].get("build_log", []):
            if int(entry.get("day", 0)) <= day:
                built.append(str(entry.get("building_id", "")))
        return [building_id for building_id in built if building_id]

    def _unit_growth(self, unit_id: str) -> int:
        return max(0, int(self.units.get(unit_id, {}).get("growth", 0)))

    def _growth_for_town_day(self, town_id: str, day: int) -> dict[str, int]:
        town = self.towns[town_id]
        recruits: dict[str, int] = {}
        growth_bonus: dict[str, int] = {}
        for building_id in self._built_buildings_by_day(town_id, day):
            building = self.buildings.get(building_id, {})
            unlock_unit_id = str(building.get("unlock_unit_id", ""))
            if unlock_unit_id:
                recruits[unlock_unit_id] = self._unit_growth(unlock_unit_id)
            bonus = building.get("growth_bonus", {})
            if isinstance(bonus, dict):
                for unit_id, amount in bonus.items():
                    growth_bonus[str(unit_id)] = int(growth_bonus.get(str(unit_id), 0)) + int(amount)
        for unit_id, amount in growth_bonus.items():
            recruits[unit_id] = int(recruits.get(unit_id, self._unit_growth(unit_id))) + amount
        for profile in [
            town.get("recruitment", {}),
            self.factions.get(str(town.get("faction_id", "")), {}).get("recruitment", {}),
        ]:
            bonus = profile.get("growth_bonus", {}) if isinstance(profile, dict) else {}
            if isinstance(bonus, dict):
                for unit_id, amount in bonus.items():
                    unit_key = str(unit_id)
                    if unit_key in recruits:
                        recruits[unit_key] += max(0, int(amount))
        return {unit_id: amount for unit_id, amount in sorted(recruits.items()) if amount > 0}

    def _select_hero(self, faction_id: str) -> dict[str, Any]:
        candidates = [
            hero for hero in self.heroes.values()
            if str(hero.get("faction_id", "")) == faction_id and str(hero.get("roster_state", "live")) == "live"
        ]
        if not candidates:
            candidates = [hero for hero in self.heroes.values() if str(hero.get("faction_id", "")) == faction_id]
        candidates.sort(key=lambda hero: str(hero.get("id", "")))
        return candidates[0] if candidates else {}

    def _build_faction_models(self) -> dict[str, dict[str, Any]]:
        models: dict[str, dict[str, Any]] = {}
        for faction_id, faction in sorted(self.factions.items()):
            ladder = self._unit_ladder(faction)
            if len(ladder) != 7 or any(unit_id not in self.units for unit_id in ladder):
                continue
            town_ids = sorted(
                town_id for town_id, town in self.towns.items()
                if str(town.get("faction_id", "")) == faction_id and town_id in self.town_reports
            )
            town_unlocks = {town_id: self._town_unlock_days(town_id, ladder) for town_id in town_ids}
            curve: dict[str, int] = {}
            for unit_id in ladder:
                curve[unit_id] = upper_median([town_unlocks[town_id].get(unit_id, 999) for town_id in town_ids])
            representative_town = ""
            best_score: tuple[int, str] | None = None
            for town_id in town_ids:
                score = sum(abs(town_unlocks[town_id].get(unit_id, 999) - curve[unit_id]) for unit_id in ladder)
                candidate = (score, town_id)
                if best_score is None or candidate < best_score:
                    best_score = candidate
                    representative_town = town_id
            hero = self._select_hero(faction_id)
            models[faction_id] = {
                "faction_id": faction_id,
                "faction_name": str(faction.get("name", faction_id)),
                "ladder": ladder,
                "representative_town_id": representative_town,
                "representative_town_name": str(self.towns.get(representative_town, {}).get("name", representative_town)),
                "unlock_curve": {self.units[unit_id]["id"]: curve[unit_id] for unit_id in ladder},
                "unlock_curve_by_tier": {
                    str(int(self.units[unit_id].get("tier", index + 1))): curve[unit_id]
                    for index, unit_id in enumerate(ladder)
                },
                "town_unlocks": town_unlocks,
                "hero": self._hero_payload(hero),
                "army_snapshots": {},
            }
            for week in DEFAULT_WEEKS:
                models[faction_id]["army_snapshots"][str(week)] = self._army_snapshot(faction_id, week, ladder)
        return models

    def _hero_payload(self, hero: dict[str, Any]) -> dict[str, Any]:
        command = hero.get("command", {}) if isinstance(hero.get("command", {}), dict) else {}
        knowledge = max(0, int(command.get("knowledge", 0)))
        mana = max(8, 8 + (knowledge * 4))
        return {
            "id": str(hero.get("id", "")),
            "name": str(hero.get("name", "Synthetic Commander")),
            "attack": int(command.get("attack", 0)),
            "defense": int(command.get("defense", 0)),
            "power": int(command.get("power", 0)),
            "knowledge": knowledge,
            "initiative": int(command.get("initiative", 0)),
            "damage_multiplier": 1.0,
            "battle_traits": [str(value) for value in hero.get("battle_traits", [])],
            "spell_ids": [str(value) for value in hero.get("starting_spell_ids", [])],
            "mana_current": mana,
            "mana_max": mana,
        }

    def _army_snapshot(self, faction_id: str, week: int, ladder: list[str]) -> list[dict[str, Any]]:
        counts: dict[str, int] = defaultdict(int)
        # Native-RMG balance surface: do not let authored representative-town build logs
        # shape faction-vs-faction benchmark armies.
        if ladder:
            counts[ladder[0]] += self._benchmark_unit_growth(faction_id, ladder[0], fully_developed=False)
        for tick_index, tier_cap in enumerate(BATTLE_RECRUITMENT_TIER_CAPS[week], start=1):
            fully_developed = bool(week >= 4 and tier_cap >= 7)
            for unit_id in ladder:
                unit = self.units[unit_id]
                if int(unit.get("tier", 0)) <= tier_cap:
                    counts[unit_id] += self._benchmark_unit_growth(faction_id, unit_id, fully_developed=fully_developed)
        return [
            {
                "unit_id": unit_id,
                "name": str(self.units[unit_id].get("name", unit_id)),
                "tier": int(self.units[unit_id].get("tier", 0)),
                "count": int(counts.get(unit_id, 0)),
            }
            for unit_id in ladder
            if int(counts.get(unit_id, 0)) > 0
        ]

    def _benchmark_unit_growth(self, faction_id: str, unit_id: str, fully_developed: bool) -> int:
        amount = self._unit_growth(unit_id)
        faction = self.factions.get(faction_id, {})
        recruitment = faction.get("recruitment", {}) if isinstance(faction.get("recruitment", {}), dict) else {}
        growth_bonus = recruitment.get("growth_bonus", {}) if isinstance(recruitment.get("growth_bonus", {}), dict) else {}
        amount += max(0, int(growth_bonus.get(unit_id, 0)))
        if fully_developed:
            amount += self._unit_building_growth_bonus(unit_id)
        return max(0, int(amount))

    def _unit_building_growth_bonus(self, unit_id: str) -> int:
        result = 0
        for building in self.buildings.values():
            if str(building.get("unlock_unit_id", "")) != unit_id:
                continue
            bonus = building.get("growth_bonus", {})
            if isinstance(bonus, dict):
                result += max(0, int(bonus.get(unit_id, 0)))
        return result

    def _effective_unit_growth_for_town_day(self, town_id: str, unit_id: str, day: int) -> int:
        amount = self._unit_growth(unit_id)
        town = self.towns[town_id]
        for building_id in self._built_buildings_by_day(town_id, day):
            building = self.buildings.get(building_id, {})
            bonus = building.get("growth_bonus", {})
            if isinstance(bonus, dict):
                amount += max(0, int(bonus.get(unit_id, 0)))
        for profile in [
            town.get("recruitment", {}),
            self.factions.get(str(town.get("faction_id", "")), {}).get("recruitment", {}),
        ]:
            bonus = profile.get("growth_bonus", {}) if isinstance(profile, dict) else {}
            if isinstance(bonus, dict):
                amount += max(0, int(bonus.get(unit_id, 0)))
        return max(0, int(amount))

    def run(self, weeks: list[int], seeds: int, include_contexts: bool = False) -> dict[str, Any]:
        contexts = [{"id": "neutral_plains", "terrain": "plains", "battlefield_tags": []}]
        if include_contexts:
            contexts.extend([
                {"id": "forest_ambush", "terrain": "forest", "battlefield_tags": ["ambush_cover"]},
                {"id": "mire_bog", "terrain": "mire", "battlefield_tags": ["bog_channels"]},
                {"id": "open_elevated", "terrain": "plains", "battlefield_tags": ["open_lane", "elevated_fire"]},
                {"id": "fortified_choke", "terrain": "plains", "battlefield_tags": ["chokepoint", "fortified_line"]},
            ])
        ordered_rows: list[dict[str, Any]] = []
        primary_rows: list[dict[str, Any]] = []
        faction_ids = sorted(self.faction_models)
        for week in weeks:
            for context in contexts:
                for side_a_faction in faction_ids:
                    for side_b_faction in faction_ids:
                        if side_a_faction == side_b_faction:
                            continue
                        row = self._run_ordered_matchup(side_a_faction, side_b_faction, week, seeds, context)
                        ordered_rows.append(row)
                        if context["id"] == "neutral_plains":
                            primary_rows.append(row)
        pair_summaries = self._pair_summaries(primary_rows)
        week_summaries = self._week_summaries(primary_rows)
        outliers = self._balance_outliers(pair_summaries, week_summaries)
        structural_failures = self._structural_failures(weeks, seeds, primary_rows)
        return {
            "schema": "battle_faction_fast_balance_benchmark_v2",
            "ok": not structural_failures,
            "balance_status": "needs_tuning" if outliers else "within_target",
            "policy": "python_fast_faction_battle_benchmark",
            "parity_scope": "ported BattleRules/BattleAiRules tactical math without Godot runtime",
            "army_snapshot_policy": {
                "initial": "one Native RMG-suitable faction/unit T1 growth tick",
                "week_1": "initial plus one recruited week capped at T1-T3",
                "week_2": "initial plus week-one T1-T4 and week-two T1-T5 recruitment",
                "week_3": "initial plus week-one T1-T4, week-two T1-T5, and week-three T1-T7 recruitment",
                "week_4": "initial plus week-one T1-T4, week-two T1-T5, and week-three/week-four T1-T7 recruitment using fully developed growth for final full-tier ticks",
            },
            "seeds_per_ordered_matchup": seeds,
            "weeks": weeks,
            "faction_count": len(faction_ids),
            "factions": self._public_faction_models(),
            "ordered_matchup_count": len(primary_rows),
            "ordered_matchups": primary_rows,
            "context_rows": [row for row in ordered_rows if row.get("context_id") != "neutral_plains"],
            "pair_summaries": pair_summaries,
            "week_summaries": week_summaries,
            "structural_failures": structural_failures,
            "balance_outlier_count": len(outliers),
            "top_balance_outliers": outliers[:24],
            "balance_outliers": outliers,
        }

    def _public_faction_models(self) -> dict[str, Any]:
        public: dict[str, Any] = {}
        for faction_id, model in self.faction_models.items():
            public[faction_id] = {
                "name": model["faction_name"],
                "representative_town_id": model["representative_town_id"],
                "representative_town_name": model["representative_town_name"],
                "hero_id": model["hero"]["id"],
                "hero_name": model["hero"]["name"],
                "unlock_curve_by_tier": model["unlock_curve_by_tier"],
                "army_snapshots": model["army_snapshots"],
            }
        return public

    def _run_ordered_matchup(
        self,
        side_a_faction: str,
        side_b_faction: str,
        week: int,
        seeds: int,
        context: dict[str, Any],
    ) -> dict[str, Any]:
        outcomes: Counter[str] = Counter()
        rounds: list[int] = []
        margins: list[int] = []
        action_mix: Counter[str] = Counter()
        casualties_by_tier: dict[str, Counter[str]] = {"side_a": Counter(), "side_b": Counter()}
        consequence_counts: Counter[str] = Counter()
        for seed_index in range(seeds):
            battle = self._create_battle(side_a_faction, side_b_faction, week, context)
            matchup_seed_parts = sorted([side_a_faction, side_b_faction])
            result = self._simulate_battle(
                battle,
                stable_seed(matchup_seed_parts[0], matchup_seed_parts[1], week, context["id"], seed_index),
            )
            outcomes[self._public_side(str(result["outcome"]))] += 1
            rounds.append(int(result["rounds"]))
            margins.append(int(result["terminal_health_margin_pct"]))
            action_mix.update(result["action_mix"])
            for internal_side in [INTERNAL_SIDE_A, INTERNAL_SIDE_B]:
                public_side = self._public_side(internal_side)
                casualties_by_tier[public_side].update(result["casualties_by_tier"].get(internal_side, {}))
            consequence_counts.update(result["consequence_counts"])
        side_a_win_rate = 100.0 * float(outcomes.get("side_a", 0)) / float(max(1, seeds))
        side_b_win_rate = 100.0 * float(outcomes.get("side_b", 0)) / float(max(1, seeds))
        return {
            "week": week,
            "context_id": context["id"],
            "side_a_faction_id": side_a_faction,
            "side_b_faction_id": side_b_faction,
            "sample_count": seeds,
            "side_a_win_rate": round(side_a_win_rate, 2),
            "side_b_win_rate": round(side_b_win_rate, 2),
            "outcomes": dict(sorted(outcomes.items())),
            "average_rounds": round(sum(rounds) / float(max(1, len(rounds))), 2),
            "average_terminal_health_margin_pct": round(sum(margins) / float(max(1, len(margins))), 2),
            "action_mix": dict(sorted(action_mix.items())),
            "casualties_by_tier": {
                side: dict(sorted(counter.items()))
                for side, counter in casualties_by_tier.items()
            },
            "consequence_counts": dict(sorted(consequence_counts.items())),
        }

    def _create_battle(self, side_a_faction: str, side_b_faction: str, week: int, context: dict[str, Any]) -> dict[str, Any]:
        side_a_model = self.faction_models[side_a_faction]
        side_b_model = self.faction_models[side_b_faction]
        return {
            "round": 1,
            "distance": 2,
            "terrain": context["terrain"],
            "battlefield_tags": list(context.get("battlefield_tags", [])),
            "side_a_hero": dict(side_a_model["hero"]),
            "side_b_hero": dict(side_b_model["hero"]),
            "commander_spell_cast_rounds": {},
            "stacks": (
                self._build_stacks(side_a_model["army_snapshots"][str(week)], INTERNAL_SIDE_A)
                + self._build_stacks(side_b_model["army_snapshots"][str(week)], INTERNAL_SIDE_B)
            ),
        }

    def _build_stacks(self, snapshot: list[dict[str, Any]], side: str) -> list[dict[str, Any]]:
        stacks: list[dict[str, Any]] = []
        for index, entry in enumerate(snapshot):
            unit = self.units[str(entry["unit_id"])]
            count = max(0, int(entry.get("count", 0)))
            if count <= 0:
                continue
            unit_hp = max(1, int(unit.get("hp", 1)))
            stack = {
                "battle_id": f"{side}_{index}_{unit['id']}",
                "side": side,
                "side_slot": index,
                "faction_id": str(unit.get("faction_id", "")),
                "unit_id": str(unit["id"]),
                "name": str(unit.get("name", unit["id"])),
                "tier": int(unit.get("tier", 1)),
                "unit_hp": unit_hp,
                "total_health": count * unit_hp,
                "base_count": count,
                "attack": int(unit.get("attack", 0)),
                "defense": int(unit.get("defense", 0)),
                "min_damage": int(unit.get("min_damage", 1)),
                "max_damage": int(unit.get("max_damage", 1)),
                "initiative": int(unit.get("initiative", 1)),
                "speed": int(unit.get("speed", 1)),
                "ranged": bool(unit.get("ranged", False)),
                "retaliations": max(0, int(unit.get("retaliations", 1))),
                "retaliations_left": max(0, int(unit.get("retaliations", 1))),
                "shots_remaining": int(unit.get("shots", 0)),
                "defending": False,
                "cohesion_base": self._cohesion_base_for_unit(unit),
                "cohesion": self._cohesion_base_for_unit(unit),
                "momentum": 0,
                "abilities": list(unit.get("abilities", [])),
                "effects": [],
            }
            stacks.append(stack)
        return stacks

    def _simulate_battle(self, battle: dict[str, Any], seed: int) -> dict[str, Any]:
        rng = random.Random(seed)
        battle["initiative_tie_side"] = INTERNAL_SIDE_A if rng.getrandbits(1) == 0 else INTERNAL_SIDE_B
        initial_health = self._side_healths(battle)
        action_mix: Counter[str] = Counter()
        consequence_counts: Counter[str] = Counter()
        self._prepare_round(battle, 1)
        while True:
            if int(battle["round"]) > SIMULATION_GUARD_MAX_ROUNDS:
                raise RuntimeError(
                    "simulation_guard_exceeded:"
                    f"round={int(battle['round'])}:"
                    f"side_a_alive={self._living_side_count(battle, INTERNAL_SIDE_A)}:"
                    f"side_b_alive={self._living_side_count(battle, INTERNAL_SIDE_B)}"
                )
            active = self._active_stack(battle)
            if not active:
                self._prepare_round(battle, int(battle["round"]) + 1)
                continue
            side = active["side"]
            if self._living_side_count(battle, INTERNAL_SIDE_A) <= 0 or self._living_side_count(battle, INTERNAL_SIDE_B) <= 0:
                break
            spell_action = self._choose_spell_action(battle, active)
            if spell_action:
                self._resolve_spell(battle, active, spell_action, consequence_counts)
                action_mix["cast_spell"] += 1
                self._advance_turn(battle)
                continue
            action = self._choose_stack_action(battle, active)
            action_mix[action["action"]] += 1
            self._resolve_action(battle, active, action, rng, consequence_counts)
            self._advance_turn(battle)
        outcome = self._outcome(battle)
        final_health = self._side_healths(battle)
        total_initial = max(1, initial_health[INTERNAL_SIDE_A] + initial_health[INTERNAL_SIDE_B])
        margin = int(round(((final_health[INTERNAL_SIDE_A] - final_health[INTERNAL_SIDE_B]) / float(total_initial)) * 100.0))
        casualties = self._casualties_by_tier(battle)
        return {
            "outcome": outcome,
            "rounds": int(battle["round"]),
            "terminal_health_margin_pct": margin,
            "action_mix": action_mix,
            "casualties_by_tier": casualties,
            "consequence_counts": consequence_counts,
        }

    def _prepare_round(self, battle: dict[str, Any], round_number: int) -> None:
        battle["round"] = round_number
        for stack in battle["stacks"]:
            stack["effects"] = [
                effect for effect in stack.get("effects", [])
                if int(effect.get("expires_after_round", 0)) >= round_number
            ]
            stack["defending"] = False
            stack["retaliations_left"] = int(stack.get("retaliations", 1))
            stack["momentum"] = max(0, int(stack.get("momentum", 0)) - 1)
        order = sorted(
            [stack["battle_id"] for stack in battle["stacks"] if self._alive_count(stack) > 0],
            key=lambda battle_id: self._turn_order_key(battle, battle_id),
        )
        battle["turn_order"] = order
        battle["turn_index"] = 0
        battle["active_stack_id"] = order[0] if order else ""

    def _turn_order_key(self, battle: dict[str, Any], battle_id: str) -> tuple[int, int, int, int]:
        stack = self._stack_by_id(battle, battle_id)
        initiative = self._stack_initiative_total(stack, battle)
        if str(battle.get("terrain", "")) == "mire":
            initiative -= 1
        side_bias = 1 if stack.get("side") == battle.get("initiative_tie_side", INTERNAL_SIDE_A) else 0
        return (-initiative, -int(stack.get("speed", 0)), -side_bias, int(stack.get("side_slot", 0)))

    def _advance_turn(self, battle: dict[str, Any]) -> None:
        order = battle.get("turn_order", [])
        index = int(battle.get("turn_index", 0)) + 1
        while index < len(order):
            stack = self._stack_by_id(battle, order[index])
            if stack and self._alive_count(stack) > 0:
                battle["turn_index"] = index
                battle["active_stack_id"] = order[index]
                return
            index += 1
        self._prepare_round(battle, int(battle.get("round", 1)) + 1)

    def _choose_stack_action(self, battle: dict[str, Any], active: dict[str, Any]) -> dict[str, Any]:
        targets = self._alive_stacks_for_side(battle, self._opposing_side(active["side"]))
        if not targets:
            return {"action": "defend"}
        candidates: list[dict[str, Any]] = []
        attack_candidates: list[dict[str, Any]] = []
        if bool(active.get("ranged", False)) and int(active.get("shots_remaining", 0)) > 0:
            for target in targets:
                score = self._attack_score(active, target, battle, True)
                candidate = {"action": "shoot", "target_battle_id": target["battle_id"], "score": score}
                candidates.append(candidate)
                attack_candidates.append(candidate)
        if self._can_make_melee_attack(active, battle):
            for target in targets:
                if self._can_make_melee_attack(active, battle, target):
                    score = self._attack_score(active, target, battle, False)
                    candidate = {"action": "strike", "target_battle_id": target["battle_id"], "score": score}
                    candidates.append(candidate)
                    attack_candidates.append(candidate)
        if int(battle.get("distance", 0)) > 0 and not bool(active.get("ranged", False)):
            candidates.append({"action": "advance", "score": self._advance_score(active, battle, targets)})
        if not self._must_force_engaged_attack(active, battle, targets, attack_candidates):
            candidates.append({"action": "defend", "score": self._defend_score(active, battle, targets)})
        candidates.sort(key=lambda item: self._candidate_sort_key(battle, item))
        return candidates[0]

    def _candidate_sort_key(self, battle: dict[str, Any], item: dict[str, Any]) -> tuple[float, str, int]:
        target = self._stack_by_id(battle, str(item.get("target_battle_id", "")))
        return (
            -float(item.get("score", 0.0)),
            str(item.get("action", "")),
            int(target.get("side_slot", -1)),
        )

    def _must_force_engaged_attack(
        self,
        active: dict[str, Any],
        battle: dict[str, Any],
        targets: list[dict[str, Any]],
        attack_candidates: list[dict[str, Any]],
    ) -> bool:
        if not attack_candidates or int(battle.get("distance", 1)) > 0:
            return False
        if bool(active.get("ranged", False)) and int(active.get("shots_remaining", 0)) > 0:
            return False
        if self._has_hostile_ranged_pressure(targets):
            return False
        return True

    def _choose_spell_action(self, battle: dict[str, Any], active: dict[str, Any]) -> dict[str, Any] | None:
        side = active["side"]
        cast_rounds = battle.setdefault("commander_spell_cast_rounds", {})
        if int(cast_rounds.get(side, 0)) >= int(battle.get("round", 1)):
            return None
        hero = self._hero_for_side(battle, side)
        if int(hero.get("mana_current", 0)) <= 0:
            return None
        spell_ids = [spell_id for spell_id in hero.get("spell_ids", []) if spell_id in self.spells]
        targets = self._alive_stacks_for_side(battle, self._opposing_side(side))
        allies = self._alive_stacks_for_side(battle, side)
        candidates: list[dict[str, Any]] = []
        for spell_id in spell_ids:
            spell = self.spells[spell_id]
            if str(spell.get("context", "")) != "battle":
                continue
            mana_cost = int(spell.get("mana_cost", 0))
            if int(hero.get("mana_current", 0)) < mana_cost:
                continue
            effect = spell.get("effect", {}) if isinstance(spell.get("effect", {}), dict) else {}
            effect_type = str(effect.get("type", ""))
            if effect_type in ["damage_enemy", "control_enemy"] and targets:
                for target in targets:
                    score = self._spell_score(hero, battle, active, target, spell)
                    candidates.append({"spell_id": spell_id, "target_battle_id": target["battle_id"], "score": score})
            elif effect_type in ["defense_buff", "initiative_buff", "attack_buff", "recover_ally", "cleanse_ally"] and allies:
                target = active
                score = self._spell_score(hero, battle, active, target, spell)
                candidates.append({"spell_id": spell_id, "target_battle_id": target["battle_id"], "score": score})
        if not candidates:
            return None
        best = sorted(candidates, key=lambda item: (-float(item.get("score", 0.0)), str(item.get("spell_id", ""))))[0]
        best_attack = self._choose_stack_action(battle, active)
        if float(best["score"]) < max(4.5, float(best_attack.get("score", 0.0)) + 0.8):
            return None
        return best

    def _spell_score(
        self,
        hero: dict[str, Any],
        battle: dict[str, Any],
        active: dict[str, Any],
        target: dict[str, Any],
        spell: dict[str, Any],
    ) -> float:
        effect = spell.get("effect", {})
        effect_type = str(effect.get("type", ""))
        mana_cost = int(spell.get("mana_cost", 0))
        if effect_type == "damage_enemy":
            damage = self._spell_damage(hero, target, effect)
            return (float(damage) / float(max(1, target.get("unit_hp", 1)))) + (1.0 - self._health_ratio(target)) * 3.0 - (mana_cost * 0.25)
        if effect_type == "control_enemy":
            return 5.0 + (1.0 - self._health_ratio(target)) * 2.0 - (mana_cost * 0.2)
        if effect_type in ["defense_buff", "initiative_buff", "attack_buff"]:
            if self._stack_has_positive_effect(active, battle):
                return 0.0
            modifiers = effect.get("modifiers", {}) if isinstance(effect.get("modifiers", {}), dict) else {}
            return 3.2 + sum(max(0, int(value)) for value in modifiers.values()) * 0.9 - (mana_cost * 0.2)
        if effect_type == "recover_ally":
            missing = max(0, int(active.get("base_count", 0)) * int(active.get("unit_hp", 1)) - int(active.get("total_health", 0)))
            return (float(missing) / float(max(1, active.get("unit_hp", 1)))) + 2.5 - (mana_cost * 0.2)
        if effect_type == "cleanse_ally":
            return (4.0 if active.get("effects") else 0.0) - (mana_cost * 0.2)
        return 0.0

    def _resolve_spell(self, battle: dict[str, Any], active: dict[str, Any], action: dict[str, Any], consequence_counts: Counter[str]) -> None:
        side = active["side"]
        hero = self._hero_for_side(battle, side)
        spell = self.spells[str(action["spell_id"])]
        target = self._stack_by_id(battle, str(action.get("target_battle_id", "")))
        effect = spell.get("effect", {}) if isinstance(spell.get("effect", {}), dict) else {}
        mana_cost = int(spell.get("mana_cost", 0))
        hero["mana_current"] = max(0, int(hero.get("mana_current", 0)) - mana_cost)
        battle.setdefault("commander_spell_cast_rounds", {})[side] = int(battle.get("round", 1))
        effect_type = str(effect.get("type", ""))
        if effect_type == "damage_enemy":
            before = dict(target)
            self._apply_damage(target, self._spell_damage(hero, target, effect))
            consequence_counts["spell_damage"] += 1
            if isinstance(effect.get("status_effect", {}), dict) and self._alive_count(target) > 0:
                self._apply_effect(target, effect["status_effect"], battle, "spell", str(spell["id"]))
                consequence_counts["status_applied"] += 1
            self._apply_damage_pressure(battle, active, before, target, True, "spell", consequence_counts)
        elif effect_type == "control_enemy" and isinstance(effect.get("status_effect", {}), dict):
            self._apply_effect(target, effect["status_effect"], battle, "spell", str(spell["id"]))
            consequence_counts["status_applied"] += 1
        elif effect_type in ["defense_buff", "initiative_buff", "attack_buff"]:
            self._apply_effect(target, effect, battle, "spell", str(spell["id"]))
            consequence_counts["buff_applied"] += 1
        elif effect_type == "recover_ally":
            restore = int(effect.get("base_restore", 0)) + int(hero.get("power", 0)) * int(effect.get("power_scale", 0))
            max_health = int(target.get("base_count", 0)) * int(target.get("unit_hp", 1))
            target["total_health"] = min(max_health, int(target.get("total_health", 0)) + max(0, restore))
            self._apply_effect(target, effect, battle, "spell", str(spell["id"]))
            consequence_counts["recovery"] += 1
        elif effect_type == "cleanse_ally":
            cleanse_ids = {str(value) for value in effect.get("cleanse_effect_ids", [])}
            target["effects"] = [fx for fx in target.get("effects", []) if str(fx.get("effect_id", "")) not in cleanse_ids]
            self._apply_effect(target, effect, battle, "spell", str(spell["id"]))
            consequence_counts["cleanse"] += 1

    def _spell_damage(self, hero: dict[str, Any], target: dict[str, Any], effect: dict[str, Any]) -> int:
        damage = int(effect.get("base_damage", 0)) + int(hero.get("power", 0)) * int(effect.get("power_scale", 0))
        if self._health_ratio(target) <= float(effect.get("wounded_threshold_ratio", -1.0)):
            damage += int(effect.get("wounded_bonus_damage", 0))
        return max(1, damage)

    def _resolve_action(
        self,
        battle: dict[str, Any],
        active: dict[str, Any],
        action: dict[str, Any],
        rng: random.Random,
        consequence_counts: Counter[str],
    ) -> None:
        action_id = str(action.get("action", "defend"))
        if action_id == "advance":
            battle["distance"] = max(0, int(battle.get("distance", 0)) - 1)
            self._adjust_momentum(active, 1)
            return
        if action_id == "defend":
            active["defending"] = True
            self._adjust_cohesion(active, 1)
            return
        if action_id not in ["shoot", "strike"]:
            active["defending"] = True
            return
        target = self._stack_by_id(battle, str(action.get("target_battle_id", "")))
        if not target or self._alive_count(target) <= 0:
            return
        is_ranged = action_id == "shoot"
        attack_distance = int(battle.get("distance", 1)) if is_ranged else (1 if int(battle.get("distance", 1)) == 1 and self._has_ability(active, "reach") else 0)
        before = dict(target)
        damage = self._calculate_damage(active, target, battle, rng, is_ranged, False, attack_distance)
        self._apply_damage(target, damage)
        if is_ranged:
            active["shots_remaining"] = max(0, int(active.get("shots_remaining", 0)) - 1)
        if self._alive_count(target) > 0:
            self._apply_attack_ability_effects(battle, active, target, is_ranged, attack_distance, consequence_counts)
        self._apply_damage_pressure(battle, active, before, target, is_ranged, "attack", consequence_counts)
        if (
            not is_ranged
            and self._alive_count(target) > 0
            and int(target.get("retaliations_left", 0)) > 0
            and self._can_make_retaliation(target, attack_distance)
        ):
            active_before = dict(active)
            retaliation_damage = self._calculate_damage(target, active, battle, rng, False, True, attack_distance)
            self._apply_damage(active, retaliation_damage)
            target["retaliations_left"] = max(0, int(target.get("retaliations_left", 0)) - 1)
            if self._alive_count(active) > 0:
                self._apply_retaliation_ability_effects(battle, target, active, consequence_counts)
            self._apply_damage_pressure(battle, target, active_before, active, False, "retaliation", consequence_counts)

    def _calculate_damage(
        self,
        attacker: dict[str, Any],
        defender: dict[str, Any],
        battle: dict[str, Any],
        rng: random.Random,
        is_ranged: bool,
        is_retaliation: bool,
        attack_distance: int,
    ) -> int:
        count = max(1, self._alive_count(attacker))
        min_damage = int(attacker.get("min_damage", 1))
        max_damage = max(min_damage, int(attacker.get("max_damage", 1)))
        base = count * rng.randint(min_damage, max_damage)
        return max(1, int(round(float(base) * self._damage_modifier(attacker, defender, battle, is_ranged, is_retaliation, attack_distance))))

    def _damage_modifier(
        self,
        attacker: dict[str, Any],
        defender: dict[str, Any],
        battle: dict[str, Any],
        is_ranged: bool,
        is_retaliation: bool,
        attack_distance: int,
    ) -> float:
        attack_stat = self._stack_attack_total(attacker, battle) + int(self._hero_for_side(battle, attacker["side"]).get("attack", 0))
        defense_stat = self._stack_defense_total(defender, battle) + int(self._hero_for_side(battle, defender["side"]).get("defense", 0))
        if bool(defender.get("defending", False)):
            defense_stat += 2
        modifier = 1.0 + (clamp(float(attack_stat - defense_stat), -8.0, 8.0) * 0.05)
        terrain = str(battle.get("terrain", "plains"))
        if is_ranged and terrain == "forest":
            modifier *= 0.8
        if is_ranged and attack_distance == 0:
            modifier *= 0.6
        if not is_ranged and terrain == "mire":
            modifier *= 0.9
        if is_retaliation:
            modifier *= 0.9
        modifier *= self._cohesion_damage_modifier(attacker, defender, battle, is_ranged, is_retaliation)
        modifier *= self._ability_damage_modifier(attacker, defender, battle, is_ranged, is_retaliation, attack_distance)
        modifier *= self._terrain_tag_damage_modifier(attacker, defender, battle, is_ranged, attack_distance)
        modifier *= self._faction_damage_modifier(attacker, defender, battle, is_ranged, attack_distance)
        modifier *= self._commander_damage_modifier(attacker, defender, battle, is_ranged)
        modifier *= float(self._hero_for_side(battle, attacker["side"]).get("damage_multiplier", 1.0))
        return modifier

    def _attack_score(self, attacker: dict[str, Any], target: dict[str, Any], battle: dict[str, Any], is_ranged: bool) -> float:
        attack_distance = int(battle.get("distance", 1)) if is_ranged else (1 if int(battle.get("distance", 1)) == 1 and self._has_ability(attacker, "reach") else 0)
        avg_roll = (int(attacker.get("min_damage", 1)) + int(attacker.get("max_damage", 1))) / 2.0
        avg_damage = max(1.0, float(max(1, self._alive_count(attacker))) * avg_roll * self._damage_modifier(attacker, target, battle, is_ranged, False, attack_distance))
        target_health = max(1, int(target.get("total_health", 0)))
        side = str(attacker.get("side", ""))
        round_number = int(battle.get("round", 1))
        score = avg_damage / float(max(1, int(target.get("unit_hp", 1))))
        score += min(1.0, avg_damage / float(target_health)) * 8.0
        if avg_damage >= target_health:
            score += 6.0
        if bool(target.get("ranged", False)):
            score += 2.5
        if int(target.get("shots_remaining", 0)) > 0:
            score += 1.0
        score += (1.0 - self._health_ratio(target)) * 3.0
        score += (1.0 - (float(self._stack_cohesion_total(target, battle)) / float(COHESION_MAX))) * 3.5
        score += float(self._stack_momentum_total(attacker, battle)) * 0.6
        if self._stack_cohesion_total(target, battle) <= 3:
            score += 2.5
        if self._stack_is_isolated(battle, target):
            score += 1.5
        if self._stack_cohesion_total(attacker, battle) <= 4:
            score -= 1.5
        if is_ranged and int(battle.get("distance", 1)) > 0:
            score += 2.0
        if is_ranged and int(battle.get("distance", 1)) == 0:
            score -= 1.5
        if self._battle_has_tag(battle, "elevated_fire") and is_ranged:
            score += 2.0
        if self._battle_has_tag(battle, "fog_bank") and is_ranged and int(battle.get("distance", 1)) > 0:
            score -= 2.0
        if self._battle_has_any_tags(battle, ["chokepoint", "fortified_line"]) and not is_ranged:
            score += 1.5
        if self._battle_has_tag(battle, "bog_channels") and any(self._has_ability(attacker, ability) for ability in ["harry", "backstab", "bloodrush"]):
            score += 1.5
        if self._has_ability(attacker, "harry") and is_ranged and not self._has_effect_id(target, battle, STATUS_HARRIED):
            score += 2.0
        if self._has_ability(attacker, "backstab") and self._has_any_effect_ids(target, battle, [STATUS_HARRIED, STATUS_STAGGERED]):
            score += 2.5
        if is_ranged and self._side_defending_count(battle, side) > 0 and self._side_has_ability(battle, side, "formation_guard"):
            score += 1.5
        if self._has_ability(attacker, "formation_guard") and self._has_effect_id(target, battle, STATUS_STAGGERED):
            score += 1.5
        bloodrush = self._ability_by_id(attacker, "bloodrush")
        if bloodrush and self._health_ratio(target) <= float(bloodrush.get("wounded_threshold_ratio", 0.0)):
            score += 2.0
        if bloodrush and self._has_any_effect_ids(target, battle, bloodrush.get("status_ids", [])):
            score += 1.5
        if bloodrush and round_number >= 3:
            score += 0.75
        if self._hero_has_trait(battle, side, "artillerist") and is_ranged and self._battle_has_any_tags(battle, ["elevated_fire", "open_lane"]):
            score += 1.5
        if self._hero_has_trait(battle, side, "packhunter") and (self._health_ratio(target) <= 0.75 or self._has_any_effect_ids(target, battle, [STATUS_HARRIED, STATUS_STAGGERED])):
            score += 1.25
        if self._hero_has_trait(battle, side, "vanguard") and not is_ranged and round_number <= 2:
            score += 1.0
        if self._hero_has_trait(battle, side, "ambusher") and not is_ranged and (str(battle.get("terrain", "")) == "forest" or self._battle_has_tag(battle, "ambush_cover")) and round_number <= 2:
            score += 1.0
        if not is_ranged and int(target.get("retaliations_left", 0)) > 0 and self._alive_count(target) > 0 and self._can_make_retaliation(target, attack_distance):
            retaliation_damage = self._estimated_damage(target, attacker, battle, False, True, attack_distance)
            score -= (float(retaliation_damage) / float(max(1, int(attacker.get("unit_hp", 1))))) * 0.45
        return score

    def _defend_score(self, active: dict[str, Any], battle: dict[str, Any], targets: list[dict[str, Any]]) -> float:
        score = 2.0 + ((1.0 - self._health_ratio(active)) * 5.0)
        score += (1.0 - (float(self._stack_cohesion_total(active, battle)) / float(COHESION_MAX))) * 5.0
        if bool(active.get("ranged", False)) and int(active.get("shots_remaining", 0)) > 0:
            score -= 3.0
        if int(battle.get("distance", 1)) > 0 and not bool(active.get("ranged", False)):
            score -= 2.0
        if self._has_ability(active, "brace") and int(battle.get("distance", 1)) <= 1:
            score += 3.0
        if self._has_ability(active, "formation_guard") and self._allied_ranged_count(battle, str(active.get("side", ""))) > 0:
            score += 2.5
        if self._battle_has_any_tags(battle, ["chokepoint", "fortified_line"]) and not bool(active.get("ranged", False)):
            score += 1.5
        if int(battle.get("distance", 1)) == 0 and self._has_hostile_ranged_pressure(targets):
            score += 1.0
        if self._stack_is_isolated(battle, active):
            score += 2.0
        if self._hero_has_trait(battle, str(active.get("side", "")), "linekeeper"):
            score += 1.0
        return score

    def _advance_score(self, active: dict[str, Any], battle: dict[str, Any], targets: list[dict[str, Any]]) -> float:
        current_distance = int(battle.get("distance", 1))
        side = str(active.get("side", ""))
        ranged = bool(active.get("ranged", False))
        if current_distance <= 0:
            return -9999.0
        score = -0.5
        if self._should_close_distance(active):
            score += 2.5
        if not ranged:
            score += 2.0
            if not self._can_make_melee_attack(active, battle):
                score += 4.0
                if self._has_hostile_ranged_pressure(targets):
                    score += 1.5
            if current_distance >= 2:
                score += 0.75
        elif int(active.get("shots_remaining", 0)) > 0:
            score -= 1.5
        if self._has_hostile_ranged_pressure(targets) and not ranged:
            score += 1.0
        score += 0.75
        if self._stack_cohesion_total(active, battle) <= 4:
            score -= 1.25
        if self._stack_is_isolated(battle, active):
            score -= 0.5
        round_number = int(battle.get("round", 1))
        if self._hero_has_trait(battle, side, "vanguard") and not ranged and round_number <= 2:
            score += 1.0
        if self._hero_has_trait(battle, side, "packhunter") and self._opposing_wounded_count(battle, side) > 0 and not ranged:
            score += 0.75
        return score

    def _estimated_damage(
        self,
        attacker: dict[str, Any],
        defender: dict[str, Any],
        battle: dict[str, Any],
        is_ranged: bool,
        is_retaliation: bool,
        attack_distance: int,
    ) -> int:
        avg_roll = (int(attacker.get("min_damage", 1)) + int(attacker.get("max_damage", 1))) / 2.0
        base = float(max(1, self._alive_count(attacker))) * avg_roll
        return max(1, int(round(base * self._damage_modifier(attacker, defender, battle, is_ranged, is_retaliation, attack_distance))))

    def _ability_damage_modifier(self, attacker: dict[str, Any], defender: dict[str, Any], battle: dict[str, Any], is_ranged: bool, is_retaliation: bool, attack_distance: int) -> float:
        modifier = 1.0
        reach = self._ability_by_id(attacker, "reach")
        if not is_ranged and attack_distance == 1 and reach:
            modifier *= float(reach.get("distance_one_multiplier", 1.0))
        brace = self._ability_by_id(attacker, "brace")
        if is_retaliation and bool(attacker.get("defending", False)) and brace:
            modifier *= float(brace.get("retaliation_multiplier", 1.0))
        backstab = self._ability_by_id(attacker, "backstab")
        if backstab and self._has_any_effect_ids(defender, battle, backstab.get("status_ids", [])):
            modifier *= float(backstab.get("damage_multiplier", 1.0))
        if backstab and self._health_ratio(defender) <= float(backstab.get("health_threshold_ratio", 0.0)):
            modifier *= float(backstab.get("threshold_damage_multiplier", 1.0))
        volley = self._ability_by_id(attacker, "volley")
        if is_ranged and volley and attack_distance >= int(volley.get("min_distance", 1)):
            modifier *= float(volley.get("damage_multiplier", 1.0))
        if is_ranged and volley and self._has_any_effect_ids(defender, battle, volley.get("status_ids", [])):
            modifier *= float(volley.get("status_damage_multiplier", 1.0))
        if is_ranged and volley and self._side_defending_count(battle, attacker["side"]) > 0:
            modifier *= float(volley.get("ally_defending_multiplier", 1.0))
        formation_guard = self._ability_by_id(attacker, "formation_guard")
        if formation_guard and self._has_effect_id(defender, battle, STATUS_STAGGERED):
            modifier *= float(formation_guard.get("staggered_damage_multiplier", 1.0))
        harry = self._ability_by_id(attacker, "harry")
        if is_ranged and harry and self._health_ratio(defender) <= float(harry.get("wounded_threshold_ratio", 0.0)):
            modifier *= float(harry.get("wounded_damage_multiplier", 1.0))
        bloodrush = self._ability_by_id(attacker, "bloodrush")
        if bloodrush and self._health_ratio(defender) <= float(bloodrush.get("wounded_threshold_ratio", 0.0)):
            modifier *= float(bloodrush.get("wounded_damage_multiplier", 1.0))
        if bloodrush and self._has_any_effect_ids(defender, battle, bloodrush.get("status_ids", [])):
            modifier *= float(bloodrush.get("status_damage_multiplier", 1.0))
        shielding = self._ability_by_id(defender, "shielding")
        if is_ranged and shielding:
            modifier *= float(shielding.get("ranged_damage_multiplier", 1.0))
        attacking_shielding = self._ability_by_id(attacker, "shielding")
        if not is_ranged and attacking_shielding and attack_distance <= 0:
            modifier *= float(attacking_shielding.get("engaged_damage_multiplier", 1.0))
        if not is_ranged and attacking_shielding and self._has_effect_id(defender, battle, STATUS_HARRIED):
            modifier *= float(attacking_shielding.get("harried_damage_multiplier", 1.0))
        return modifier

    def _faction_damage_modifier(self, attacker: dict[str, Any], defender: dict[str, Any], battle: dict[str, Any], is_ranged: bool, attack_distance: int) -> float:
        return 1.0

    def _terrain_tag_damage_modifier(self, attacker: dict[str, Any], defender: dict[str, Any], battle: dict[str, Any], is_ranged: bool, attack_distance: int) -> float:
        modifier = 1.0
        if self._battle_has_tag(battle, "elevated_fire") and is_ranged and attack_distance > 0:
            modifier *= 1.1
        if self._battle_has_tag(battle, "open_lane") and is_ranged and attack_distance > 0:
            modifier *= 1.06
        if self._battle_has_any_tags(battle, ["chokepoint", "fortified_line"]):
            if not is_ranged and attack_distance <= 1 and any(self._has_ability(attacker, ability) for ability in ["reach", "brace", "formation_guard"]):
                modifier *= 1.08
            elif is_ranged and attack_distance > 0:
                modifier *= 0.92
        if self._battle_has_tag(battle, "ambush_cover"):
            if not is_ranged and int(battle.get("round", 1)) <= 2:
                modifier *= 1.08
            elif is_ranged and attack_distance > 0:
                modifier *= 0.94
        if self._battle_has_tag(battle, "bog_channels") and (
            self._has_ability(attacker, "harry")
            or self._has_ability(attacker, "backstab")
            or self._has_ability(attacker, "bloodrush")
            or self._has_effect_id(defender, battle, STATUS_HARRIED)
        ):
            modifier *= 1.08
        if self._battle_has_tag(battle, "fog_bank") and is_ranged and attack_distance > 0:
            modifier *= 0.88
        return modifier

    def _commander_damage_modifier(self, attacker: dict[str, Any], defender: dict[str, Any], battle: dict[str, Any], is_ranged: bool) -> float:
        modifier = 1.0
        side = attacker["side"]
        if self._hero_has_trait(battle, side, "artillerist") and is_ranged and self._battle_has_any_tags(battle, ["elevated_fire", "open_lane"]):
            modifier *= 1.06
        if self._hero_has_trait(battle, side, "linekeeper") and is_ranged and self._side_defending_count(battle, side) > 0:
            modifier *= 1.05
        if self._hero_has_trait(battle, side, "packhunter") and (
            self._health_ratio(defender) <= 0.75
            or self._has_any_effect_ids(defender, battle, [STATUS_HARRIED, STATUS_STAGGERED])
        ):
            modifier *= 1.06
        if self._hero_has_trait(battle, side, "bogwise") and (self._battle_has_tag(battle, "bog_channels") or str(battle.get("terrain", "")) == "mire") and any(self._has_ability(attacker, ability) for ability in ["harry", "backstab", "bloodrush"]):
            modifier *= 1.06
        return modifier

    def _apply_attack_ability_effects(self, battle: dict[str, Any], attacker: dict[str, Any], defender: dict[str, Any], is_ranged: bool, attack_distance: int, counts: Counter[str]) -> None:
        if not is_ranged and attack_distance > 1:
            return
        harry = self._ability_by_id(attacker, "harry")
        if harry:
            self._apply_effect(defender, {
                "effect_id": str(harry.get("status_id", "")),
                "label": str(harry.get("status_label", "Harried")),
                "duration_rounds": int(harry.get("duration_rounds", 1)),
                "modifiers": harry.get("modifiers", {}),
            }, battle, "ability", "harry")
            counts["status_applied"] += 1

    def _apply_retaliation_ability_effects(self, battle: dict[str, Any], retaliator: dict[str, Any], attacker: dict[str, Any], counts: Counter[str]) -> None:
        brace = self._ability_by_id(retaliator, "brace")
        if brace and bool(retaliator.get("defending", False)):
            self._apply_effect(attacker, {
                "effect_id": str(brace.get("status_id", "")),
                "label": str(brace.get("status_label", "Staggered")),
                "duration_rounds": int(brace.get("duration_rounds", 1)),
                "modifiers": brace.get("modifiers", {}),
            }, battle, "ability", "brace")
            counts["status_applied"] += 1

    def _apply_damage_pressure(self, battle: dict[str, Any], attacker: dict[str, Any], before: dict[str, Any], after: dict[str, Any], is_ranged: bool, source_type: str, counts: Counter[str]) -> None:
        before_count = self._alive_count(before)
        after_count = self._alive_count(after)
        lost_count = max(0, before_count - after_count)
        before_health = max(1, int(before.get("total_health", 0)))
        after_health = max(0, int(after.get("total_health", 0)))
        lost_ratio = clamp(float(before_health - after_health) / float(before_health), 0.0, 1.0)
        cohesion_shift = 0
        if after_count <= 0:
            cohesion_shift = -3
        elif lost_ratio >= 0.45 or lost_count >= 2:
            cohesion_shift = -2
        elif lost_ratio >= 0.18 or lost_count >= 1:
            cohesion_shift = -1
        if after_count > 0 and self._stack_is_isolated(battle, after):
            cohesion_shift -= 1
        if after_count > 0 and self._has_any_effect_ids(after, battle, [STATUS_HARRIED, STATUS_STAGGERED]):
            cohesion_shift -= 1
        self._adjust_cohesion(after, cohesion_shift)
        momentum_gain = 0
        if after_count <= 0:
            momentum_gain += 2
        elif lost_ratio >= 0.25 or self._health_ratio(after) <= 0.75:
            momentum_gain += 1
        if after_count > 0 and self._has_any_effect_ids(after, battle, [STATUS_HARRIED, STATUS_STAGGERED]):
            momentum_gain += 1
        if self._stack_cohesion_total(before, battle) <= 4:
            momentum_gain += 1
        if self._has_ability(attacker, "harry") and is_ranged:
            momentum_gain += max(0, int(self._ability_by_id(attacker, "harry").get("momentum_gain", 0)))
        bloodrush = self._ability_by_id(attacker, "bloodrush")
        if bloodrush and (after_count <= 0 or self._health_ratio(after) <= float(bloodrush.get("wounded_threshold_ratio", 0.0))):
            momentum_gain += max(0, int(bloodrush.get("momentum_gain", 0)))
            if after_count <= 0:
                momentum_gain += max(0, int(bloodrush.get("kill_momentum_gain", 0)))
        if source_type == "spell":
            momentum_gain = max(1, momentum_gain)
        self._adjust_momentum(attacker, momentum_gain)
        if cohesion_shift != 0:
            counts["cohesion_shift"] += 1
        if momentum_gain > 0:
            counts["momentum_gain"] += 1

    def _apply_effect(self, stack: dict[str, Any], effect: dict[str, Any], battle: dict[str, Any], source_type: str, source_id: str) -> None:
        modifiers = effect.get("modifiers", {}) if isinstance(effect.get("modifiers", {}), dict) else {}
        stack.setdefault("effects", []).append({
            "effect_id": str(effect.get("effect_id", effect.get("type", source_id))),
            "source_type": source_type,
            "source_id": source_id,
            "label": str(effect.get("label", source_id)),
            "modifiers": {str(key): int(value) for key, value in modifiers.items()},
            "expires_after_round": max(1, int(battle.get("round", 1))) + max(1, int(effect.get("duration_rounds", 1))) - 1,
        })

    def _cohesion_base_for_unit(self, unit: dict[str, Any]) -> int:
        base = 5 + max(0, int(unit.get("tier", 1)) - 1)
        if not bool(unit.get("ranged", False)):
            base += 1
        for ability in unit.get("abilities", []):
            if isinstance(ability, dict) and str(ability.get("id", "")) in ["brace", "formation_guard", "shielding"]:
                base += 1
                break
        if bool(unit.get("ranged", False)) and int(unit.get("hp", 1)) <= 6:
            base -= 1
        return int(clamp(base, 4, 8))

    def _stack_attack_total(self, stack: dict[str, Any], battle: dict[str, Any]) -> int:
        return int(stack.get("attack", 0)) + self._effect_bonus(stack, battle, "attack") + self._contextual_attack_bonus(stack, battle) + self._cohesion_attack_bonus(self._stack_cohesion_total(stack, battle)) + self._momentum_attack_bonus(self._stack_momentum_total(stack, battle))

    def _stack_defense_total(self, stack: dict[str, Any], battle: dict[str, Any]) -> int:
        return int(stack.get("defense", 0)) + self._effect_bonus(stack, battle, "defense") + self._contextual_defense_bonus(stack, battle) + self._cohesion_defense_bonus(self._stack_cohesion_total(stack, battle))

    def _stack_initiative_total(self, stack: dict[str, Any], battle: dict[str, Any]) -> int:
        return int(stack.get("initiative", 0)) + self._effect_bonus(stack, battle, "initiative") + self._contextual_initiative_bonus(stack, battle) + self._cohesion_initiative_bonus(self._stack_cohesion_total(stack, battle)) + self._momentum_initiative_bonus(self._stack_momentum_total(stack, battle)) + int(self._hero_for_side(battle, stack.get("side", "")).get("initiative", 0))

    def _contextual_attack_bonus(self, stack: dict[str, Any], battle: dict[str, Any]) -> int:
        bonus = 0
        side = str(stack.get("side", ""))
        if self._battle_has_tag(battle, "elevated_fire") and bool(stack.get("ranged", False)):
            bonus += 1
        if self._battle_has_tag(battle, "bog_channels") and any(self._has_ability(stack, ability) for ability in ["harry", "backstab", "bloodrush"]):
            bonus += 1
        if self._hero_has_trait(battle, side, "artillerist") and bool(stack.get("ranged", False)) and self._battle_has_any_tags(battle, ["elevated_fire", "open_lane"]):
            bonus += 1
        if self._hero_has_trait(battle, side, "packhunter") and self._opposing_wounded_count(battle, side) > 0:
            bonus += 1
        if self._hero_has_trait(battle, side, "vanguard") and not bool(stack.get("ranged", False)) and int(battle.get("round", 1)) <= 2:
            bonus += 1
        if self._hero_has_trait(battle, side, "ambusher") and not bool(stack.get("ranged", False)) and self._battle_has_tag(battle, "ambush_cover") and int(battle.get("round", 1)) <= 2:
            bonus += 1
        return bonus

    def _contextual_defense_bonus(self, stack: dict[str, Any], battle: dict[str, Any]) -> int:
        bonus = 0
        side = str(stack.get("side", ""))
        if self._battle_has_any_tags(battle, ["chokepoint", "fortified_line"]) and not bool(stack.get("ranged", False)) and any(self._has_ability(stack, ability) for ability in ["reach", "brace", "formation_guard"]):
            bonus += 1
        if self._hero_has_trait(battle, side, "linekeeper") and (bool(stack.get("defending", False)) or self._has_ability(stack, "brace") or self._has_ability(stack, "formation_guard")):
            bonus += 1
        if self._hero_has_trait(battle, side, "bogwise") and str(battle.get("terrain", "")) == "mire" and not bool(stack.get("ranged", False)):
            bonus += 1
        return bonus

    def _contextual_initiative_bonus(self, stack: dict[str, Any], battle: dict[str, Any]) -> int:
        bonus = 0
        side = str(stack.get("side", ""))
        if self._battle_has_tag(battle, "elevated_fire") and bool(stack.get("ranged", False)):
            bonus += 1
        if self._battle_has_tag(battle, "open_lane") and bool(stack.get("ranged", False)) and int(battle.get("round", 1)) <= 2:
            bonus += 1
        if self._battle_has_any_tags(battle, ["chokepoint", "fortified_line"]) and not bool(stack.get("ranged", False)) and any(self._has_ability(stack, ability) for ability in ["reach", "brace", "formation_guard"]):
            bonus += 1
        if self._battle_has_tag(battle, "ambush_cover") and not bool(stack.get("ranged", False)) and int(battle.get("round", 1)) <= 2:
            bonus += 1
        if self._battle_has_tag(battle, "bog_channels") and any(self._has_ability(stack, ability) for ability in ["harry", "backstab", "bloodrush"]):
            bonus += 1
        if self._hero_has_trait(battle, side, "linekeeper") and (bool(stack.get("defending", False)) or self._battle_has_any_tags(battle, ["chokepoint", "fortified_line"])):
            bonus += 1
        if self._hero_has_trait(battle, side, "artillerist") and bool(stack.get("ranged", False)) and self._battle_has_any_tags(battle, ["elevated_fire", "open_lane"]):
            bonus += 1
        if self._hero_has_trait(battle, side, "ambusher") and not bool(stack.get("ranged", False)) and (str(battle.get("terrain", "")) == "forest" or self._battle_has_tag(battle, "ambush_cover")) and int(battle.get("round", 1)) <= 2:
            bonus += 1
        if self._hero_has_trait(battle, side, "packhunter") and self._opposing_wounded_count(battle, side) > 0 and not bool(stack.get("ranged", False)):
            bonus += 1
        return bonus

    def _cohesion_damage_modifier(self, attacker: dict[str, Any], defender: dict[str, Any], battle: dict[str, Any], is_ranged: bool, is_retaliation: bool) -> float:
        modifier = 1.0
        attacker_cohesion = self._stack_cohesion_total(attacker, battle)
        defender_cohesion = self._stack_cohesion_total(defender, battle)
        momentum = self._stack_momentum_total(attacker, battle)
        if attacker_cohesion >= 8:
            modifier *= 1.05
        elif attacker_cohesion <= 3:
            modifier *= 0.9
        if defender_cohesion <= 3:
            modifier *= 1.08
        elif defender_cohesion <= 5:
            modifier *= 1.03
        modifier *= 1.0 + (float(momentum) * 0.04)
        if is_retaliation and attacker_cohesion <= 4:
            modifier *= 0.92
        if is_ranged and self._stack_is_isolated(battle, attacker):
            modifier *= 0.94
        return modifier

    def _effect_bonus(self, stack: dict[str, Any], battle: dict[str, Any], kind: str) -> int:
        total = 0
        for effect in stack.get("effects", []):
            if int(effect.get("expires_after_round", 0)) >= int(battle.get("round", 1)):
                modifiers = effect.get("modifiers", {})
                if isinstance(modifiers, dict):
                    total += int(modifiers.get(kind, 0))
        return total

    def _has_effect_id(self, stack: dict[str, Any], battle: dict[str, Any], effect_id: str) -> bool:
        return any(
            int(effect.get("expires_after_round", 0)) >= int(battle.get("round", 1))
            and str(effect.get("effect_id", "")) == effect_id
            for effect in stack.get("effects", [])
        )

    def _has_any_effect_ids(self, stack: dict[str, Any], battle: dict[str, Any], effect_ids: Any) -> bool:
        ids = {str(value) for value in effect_ids} if isinstance(effect_ids, list) else set()
        return any(self._has_effect_id(stack, battle, effect_id) for effect_id in ids)

    def _stack_has_positive_effect(self, stack: dict[str, Any], battle: dict[str, Any]) -> bool:
        for effect in stack.get("effects", []):
            if int(effect.get("expires_after_round", 0)) < int(battle.get("round", 1)):
                continue
            modifiers = effect.get("modifiers", {})
            if isinstance(modifiers, dict) and any(int(value) > 0 for value in modifiers.values()):
                return True
        return False

    def _ability_by_id(self, stack: dict[str, Any], ability_id: str) -> dict[str, Any]:
        for ability in stack.get("abilities", []):
            if isinstance(ability, dict) and str(ability.get("id", "")) == ability_id:
                return ability
        return {}

    def _has_ability(self, stack: dict[str, Any], ability_id: str) -> bool:
        return bool(self._ability_by_id(stack, ability_id))

    def _can_make_melee_attack(self, stack: dict[str, Any], battle: dict[str, Any], target: dict[str, Any] | None = None) -> bool:
        if not stack or self._alive_count(stack) <= 0:
            return False
        if target is not None and target and self._alive_count(target) <= 0:
            return False
        distance = int(battle.get("distance", 1))
        return distance <= 0 or (distance == 1 and self._has_ability(stack, "reach"))

    def _can_make_retaliation(self, stack: dict[str, Any], attack_distance: int) -> bool:
        return attack_distance <= 0 or (attack_distance == 1 and self._has_ability(stack, "reach"))

    def _apply_damage(self, stack: dict[str, Any], damage: int) -> None:
        stack["total_health"] = max(0, int(stack.get("total_health", 0)) - max(0, int(damage)))

    def _alive_count(self, stack: dict[str, Any]) -> int:
        return int(math.ceil(float(max(0, int(stack.get("total_health", 0)))) / float(max(1, int(stack.get("unit_hp", 1))))))

    def _health_ratio(self, stack: dict[str, Any]) -> float:
        maximum = max(1, int(stack.get("base_count", 0)) * max(1, int(stack.get("unit_hp", 1))))
        return clamp(float(max(0, int(stack.get("total_health", 0)))) / float(maximum), 0.0, 1.0)

    def _stack_cohesion_total(self, stack: dict[str, Any], battle: dict[str, Any]) -> int:
        total = int(stack.get("cohesion", stack.get("cohesion_base", 5))) + self._effect_bonus(stack, battle, "cohesion")
        if self._stack_is_isolated(battle, stack):
            total -= 1
        if self._has_any_effect_ids(stack, battle, [STATUS_HARRIED, STATUS_STAGGERED]):
            total -= 1
        shielding = self._ability_by_id(stack, "shielding")
        if shielding:
            total += max(0, int(shielding.get("cohesion_hold_bonus", 0)))
        return int(clamp(total, COHESION_MIN, COHESION_MAX))

    def _stack_momentum_total(self, stack: dict[str, Any], battle: dict[str, Any] | None = None) -> int:
        return int(clamp(int(stack.get("momentum", 0)), 0, MOMENTUM_MAX))

    def _cohesion_attack_bonus(self, cohesion: int) -> int:
        if cohesion >= 9:
            return 2
        if cohesion >= 7:
            return 1
        if cohesion <= 2:
            return -2
        if cohesion <= 4:
            return -1
        return 0

    def _cohesion_defense_bonus(self, cohesion: int) -> int:
        if cohesion >= 8:
            return 1
        if cohesion <= 3:
            return -2
        if cohesion <= 5:
            return -1
        return 0

    def _cohesion_initiative_bonus(self, cohesion: int) -> int:
        if cohesion >= 8:
            return 1
        if cohesion <= 3:
            return -2
        if cohesion <= 5:
            return -1
        return 0

    def _momentum_attack_bonus(self, momentum: int) -> int:
        if momentum >= 3:
            return 2
        if momentum >= 1:
            return 1
        return 0

    def _momentum_initiative_bonus(self, momentum: int) -> int:
        if momentum >= 3:
            return 2
        if momentum >= 1:
            return 1
        return 0

    def _adjust_cohesion(self, stack: dict[str, Any], delta: int) -> None:
        if stack:
            stack["cohesion"] = int(clamp(int(stack.get("cohesion", 5)) + int(delta), COHESION_MIN, COHESION_MAX))

    def _adjust_momentum(self, stack: dict[str, Any], delta: int) -> None:
        if stack:
            stack["momentum"] = int(clamp(int(stack.get("momentum", 0)) + int(delta), 0, MOMENTUM_MAX))

    def _side_healths(self, battle: dict[str, Any]) -> dict[str, int]:
        return {
            side: sum(max(0, int(stack.get("total_health", 0))) for stack in battle["stacks"] if stack.get("side") == side)
            for side in [INTERNAL_SIDE_A, INTERNAL_SIDE_B]
        }

    def _casualties_by_tier(self, battle: dict[str, Any]) -> dict[str, dict[str, int]]:
        result: dict[str, dict[str, int]] = {INTERNAL_SIDE_A: defaultdict(int), INTERNAL_SIDE_B: defaultdict(int)}
        for stack in battle["stacks"]:
            lost = max(0, int(stack.get("base_count", 0)) - self._alive_count(stack))
            if lost > 0:
                result[str(stack.get("side", ""))][str(int(stack.get("tier", 0)))] += lost
        return {side: dict(sorted(values.items())) for side, values in result.items()}

    def _outcome(self, battle: dict[str, Any]) -> str:
        side_a_alive = self._living_side_count(battle, INTERNAL_SIDE_A) > 0
        side_b_alive = self._living_side_count(battle, INTERNAL_SIDE_B) > 0
        if side_a_alive and not side_b_alive:
            return INTERNAL_SIDE_A
        if side_b_alive and not side_a_alive:
            return INTERNAL_SIDE_B
        health = self._side_healths(battle)
        return INTERNAL_SIDE_A if int(health.get(INTERNAL_SIDE_A, 0)) >= int(health.get(INTERNAL_SIDE_B, 0)) else INTERNAL_SIDE_B

    def _living_side_count(self, battle: dict[str, Any], side: str) -> int:
        return len(self._alive_stacks_for_side(battle, side))

    def _alive_stacks_for_side(self, battle: dict[str, Any], side: str) -> list[dict[str, Any]]:
        return [stack for stack in battle.get("stacks", []) if stack.get("side") == side and self._alive_count(stack) > 0]

    def _stack_by_id(self, battle: dict[str, Any], battle_id: str) -> dict[str, Any]:
        for stack in battle.get("stacks", []):
            if str(stack.get("battle_id", "")) == battle_id:
                return stack
        return {}

    def _active_stack(self, battle: dict[str, Any]) -> dict[str, Any]:
        return self._stack_by_id(battle, str(battle.get("active_stack_id", "")))

    def _opposing_side(self, side: str) -> str:
        return INTERNAL_SIDE_B if side == INTERNAL_SIDE_A else INTERNAL_SIDE_A

    def _hero_for_side(self, battle: dict[str, Any], side: str) -> dict[str, Any]:
        return battle["side_a_hero"] if side == INTERNAL_SIDE_A else battle["side_b_hero"]

    def _hero_has_trait(self, battle: dict[str, Any], side: str, trait: str) -> bool:
        return trait in self._hero_for_side(battle, side).get("battle_traits", [])

    def _battle_has_tag(self, battle: dict[str, Any], tag: str) -> bool:
        return tag in battle.get("battlefield_tags", [])

    def _battle_has_any_tags(self, battle: dict[str, Any], tags: list[str]) -> bool:
        return any(self._battle_has_tag(battle, tag) for tag in tags)

    def _stack_is_isolated(self, battle: dict[str, Any], stack: dict[str, Any]) -> bool:
        side = str(stack.get("side", ""))
        allies = self._alive_stacks_for_side(battle, side)
        if len(allies) <= 1:
            return True
        if bool(stack.get("ranged", False)):
            return not any(not bool(ally.get("ranged", False)) for ally in allies)
        return False

    def _side_defending_count(self, battle: dict[str, Any], side: str) -> int:
        return sum(1 for stack in self._alive_stacks_for_side(battle, side) if bool(stack.get("defending", False)))

    def _allied_ranged_count(self, battle: dict[str, Any], side: str) -> int:
        return sum(1 for stack in self._alive_stacks_for_side(battle, side) if bool(stack.get("ranged", False)))

    def _has_hostile_ranged_pressure(self, targets: list[dict[str, Any]]) -> bool:
        return any(bool(target.get("ranged", False)) and int(target.get("shots_remaining", 0)) > 0 for target in targets)

    def _should_close_distance(self, stack: dict[str, Any]) -> bool:
        return not bool(stack.get("ranged", False))

    def _side_has_ability(self, battle: dict[str, Any], side: str, ability_id: str) -> bool:
        return any(self._has_ability(stack, ability_id) for stack in self._alive_stacks_for_side(battle, side))

    def _side_max_ability_float(self, battle: dict[str, Any], side: str, ability_id: str, key: str, default: float) -> float:
        result = default
        for stack in self._alive_stacks_for_side(battle, side):
            ability = self._ability_by_id(stack, ability_id)
            if ability:
                result = max(result, float(ability.get(key, default)))
        return result

    def _side_has_role_mix(self, battle: dict[str, Any], side: str) -> bool:
        allies = self._alive_stacks_for_side(battle, side)
        return any(bool(stack.get("ranged", False)) for stack in allies) and any(not bool(stack.get("ranged", False)) for stack in allies)

    def _opposing_wounded_count(self, battle: dict[str, Any], side: str) -> int:
        return sum(1 for stack in self._alive_stacks_for_side(battle, self._opposing_side(side)) if self._health_ratio(stack) <= 0.75)

    def _side_positive_effect_count(self, battle: dict[str, Any], side: str) -> int:
        return sum(1 for stack in self._alive_stacks_for_side(battle, side) if self._stack_has_positive_effect(stack, battle))

    def _pair_summaries(self, rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
        by_key: dict[tuple[int, str, str], list[dict[str, Any]]] = defaultdict(list)
        for row in rows:
            left, right = sorted([str(row["side_a_faction_id"]), str(row["side_b_faction_id"])])
            by_key[(int(row["week"]), left, right)].append(row)
        summaries: list[dict[str, Any]] = []
        for (week, left, right), pair_rows in sorted(by_key.items()):
            left_wins = 0.0
            right_wins = 0.0
            samples = 0
            rounds = []
            margins = []
            for row in pair_rows:
                count = int(row["sample_count"])
                samples += count
                if str(row["side_a_faction_id"]) == left:
                    left_wins += float(row["side_a_win_rate"]) * count / 100.0
                    right_wins += float(row["side_b_win_rate"]) * count / 100.0
                else:
                    right_wins += float(row["side_a_win_rate"]) * count / 100.0
                    left_wins += float(row["side_b_win_rate"]) * count / 100.0
                rounds.append(float(row["average_rounds"]))
                margins.append(float(row["average_terminal_health_margin_pct"]))
            left_rate = 100.0 * left_wins / float(max(1, samples))
            right_rate = 100.0 * right_wins / float(max(1, samples))
            summaries.append({
                "week": week,
                "faction_pair": [left, right],
                "sample_count": samples,
                "left_win_rate": round(left_rate, 2),
                "right_win_rate": round(right_rate, 2),
                "dominant_faction_id": left if left_rate >= right_rate else right,
                "dominant_win_rate": round(max(left_rate, right_rate), 2),
                "average_rounds": round(sum(rounds) / float(max(1, len(rounds))), 2),
                "average_abs_terminal_margin_pct": round(sum(abs(value) for value in margins) / float(max(1, len(margins))), 2),
            })
        return summaries

    def _week_summaries(self, rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
        by_week: dict[int, list[dict[str, Any]]] = defaultdict(list)
        for row in rows:
            by_week[int(row["week"])].append(row)
        result: list[dict[str, Any]] = []
        for week, week_rows in sorted(by_week.items()):
            side_a_wins = sum(float(row["side_a_win_rate"]) * int(row["sample_count"]) / 100.0 for row in week_rows)
            side_b_wins = sum(float(row["side_b_win_rate"]) * int(row["sample_count"]) / 100.0 for row in week_rows)
            samples = sum(int(row["sample_count"]) for row in week_rows)
            result.append({
                "week": week,
                "ordered_matchup_count": len(week_rows),
                "sample_count": samples,
                "side_a_win_rate": round(100.0 * side_a_wins / float(max(1, samples)), 2),
                "side_b_win_rate": round(100.0 * side_b_wins / float(max(1, samples)), 2),
                "side_bias_points": round(abs(side_a_wins - side_b_wins) * 100.0 / float(max(1, samples)), 2),
                "average_rounds": round(sum(float(row["average_rounds"]) for row in week_rows) / float(max(1, len(week_rows))), 2),
            })
        return result

    def _balance_outliers(self, pair_summaries: list[dict[str, Any]], week_summaries: list[dict[str, Any]]) -> list[dict[str, Any]]:
        outliers: list[dict[str, Any]] = []
        for pair in pair_summaries:
            dominant = float(pair["dominant_win_rate"])
            if dominant > BALANCE_MAX_WIN_RATE:
                outliers.append({
                    "kind": "pair_win_rate",
                    "week": int(pair["week"]),
                    "faction_pair": pair["faction_pair"],
                    "dominant_faction_id": pair["dominant_faction_id"],
                    "value": dominant,
                    "target": f"{BALANCE_MIN_WIN_RATE:.0f}-{BALANCE_MAX_WIN_RATE:.0f}",
                    "status": "tuning_outlier",
                })
            if not (MIN_AVERAGE_ROUNDS <= float(pair["average_rounds"]) <= MAX_AVERAGE_ROUNDS):
                outliers.append({
                    "kind": "pair_average_rounds",
                    "week": int(pair["week"]),
                    "faction_pair": pair["faction_pair"],
                    "value": float(pair["average_rounds"]),
                    "target": f"{MIN_AVERAGE_ROUNDS:.0f}-{MAX_AVERAGE_ROUNDS:.0f}",
                    "status": "tuning_outlier",
                })
        for week in week_summaries:
            if float(week["side_bias_points"]) > MAX_SIDE_BIAS_POINTS:
                outliers.append({
                    "kind": "week_side_bias",
                    "week": int(week["week"]),
                    "value": float(week["side_bias_points"]),
                    "target": f"<= {MAX_SIDE_BIAS_POINTS:.0f}",
                    "status": "tuning_outlier",
                })
        outliers.sort(key=lambda item: (str(item["kind"]), int(item.get("week", 0)), -float(item.get("value", 0.0))))
        return outliers

    def _structural_failures(self, weeks: list[int], seeds: int, rows: list[dict[str, Any]]) -> list[str]:
        failures: list[str] = []
        if len(self.faction_models) != 6:
            failures.append(f"expected_6_factions_got_{len(self.faction_models)}")
        for faction_id, model in self.faction_models.items():
            if len(model.get("ladder", [])) != 7:
                failures.append(f"{faction_id}_missing_seven_tier_ladder")
            for week in weeks:
                if not model.get("army_snapshots", {}).get(str(week)):
                    failures.append(f"{faction_id}_week_{week}_empty_army_snapshot")
        expected_rows = len(weeks) * len(self.faction_models) * max(0, len(self.faction_models) - 1)
        if len(rows) != expected_rows:
            failures.append(f"expected_{expected_rows}_ordered_rows_got_{len(rows)}")
        bad_seed_rows = [
            f"{row['week']}:{row['side_a_faction_id']}:{row['side_b_faction_id']}"
            for row in rows
            if int(row.get("sample_count", 0)) != seeds
        ]
        if bad_seed_rows:
            failures.append(f"rows_with_wrong_sample_count:{','.join(bad_seed_rows[:8])}")
        return failures

    def _public_side(self, internal_side: str) -> str:
        return PUBLIC_SIDE_NAMES.get(internal_side, internal_side)


def parse_weeks(value: str) -> list[int]:
    result = []
    for part in value.split(","):
        part = part.strip()
        if not part:
            continue
        week = int(part)
        if week not in WEEK_BOUNDARY_DAYS:
            raise argparse.ArgumentTypeError(f"Unsupported week {week}; expected 1-4.")
        result.append(week)
    return sorted(set(result))


def main() -> int:
    parser = argparse.ArgumentParser(description="Fast Python faction-vs-faction battle balance benchmark.")
    parser.add_argument("--quick", action="store_true", help="Run a small deterministic smoke benchmark.")
    parser.add_argument("--seeds", type=int, default=DEFAULT_SEEDS, help="Deterministic seeds per ordered matchup.")
    parser.add_argument("--weeks", type=parse_weeks, default=DEFAULT_WEEKS, help="Comma-separated weeks to run, e.g. 1,2,3,4.")
    parser.add_argument("--json", action="store_true", help="Emit raw JSON without the report prefix.")
    parser.add_argument("--gate", action="store_true", help="Return non-zero on structural benchmark failure.")
    parser.add_argument("--include-contexts", action="store_true", help="Add report-only terrain/tag context rows.")
    args = parser.parse_args()

    seeds = 10 if args.quick else max(1, int(args.seeds))
    weeks = [1] if args.quick else args.weeks
    report = FastBattleBenchmark().run(weeks=weeks, seeds=seeds, include_contexts=bool(args.include_contexts))
    payload = json.dumps(report, sort_keys=True)
    if args.json:
        print(payload)
    else:
        print("BATTLE_FACTION_FAST_BALANCE_BENCHMARK " + payload)
    if args.gate and report.get("structural_failures"):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
