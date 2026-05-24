#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "content"

REPORT_SCHEMA = "town_development_cost_curve_report_v1"
COMMON_RESOURCES = {"gold", "wood", "ore"}
RARE_RESOURCES = {
    "aetherglass",
    "embergrain",
    "peatwax",
    "verdant_grafts",
    "brass_scrip",
    "memory_salt",
}
LIVE_RESOURCES = COMMON_RESOURCES | RARE_RESOURCES
MIN_COMMON_ONLY_TO_RARE_RATIO = 2
MIN_RARE_DEVELOPMENT_SPEND = 14
SIGNATURE_TIER_COUNT = 7
HIGH_TIER_START = 5


def load_items(filename: str) -> dict[str, dict[str, Any]]:
    with (CONTENT / filename).open(encoding="utf-8") as handle:
        payload = json.load(handle)
    return {str(item["id"]): item for item in payload.get("items", [])}


def cost_payload(building: dict[str, Any]) -> dict[str, int]:
    result: dict[str, int] = {}
    payload = building.get("cost", {})
    if not isinstance(payload, dict):
        return result
    for key, value in payload.items():
        try:
            result[str(key)] = int(value)
        except (TypeError, ValueError):
            result[str(key)] = 0
    return result


def prerequisite_closure(building_id: str, buildings: dict[str, dict[str, Any]], seen: set[str] | None = None) -> set[str]:
    seen = set() if seen is None else seen
    if building_id in seen:
        return seen
    seen.add(building_id)
    building = buildings.get(building_id, {})
    for field in ("requires",):
        values = building.get(field, [])
        if isinstance(values, list):
            for value in values:
                prerequisite_closure(str(value), buildings, seen)
    upgrade_from = str(building.get("upgrade_from", "")).strip()
    if upgrade_from:
        prerequisite_closure(upgrade_from, buildings, seen)
    return seen


def main() -> int:
    factions = load_items("factions.json")
    towns = load_items("towns.json")
    buildings = load_items("buildings.json")
    units = load_items("units.json")
    errors: list[str] = []
    faction_curves: dict[str, dict[str, Any]] = {}
    town_rows: dict[str, dict[str, Any]] = {}

    for faction_id, faction in sorted(factions.items()):
        signature_ids = [str(value) for value in faction.get("signature_building_ids", [])]
        ladder_ids = [str(value) for value in faction.get("unit_ladder_ids", [])]
        if len(signature_ids) != SIGNATURE_TIER_COUNT or len(set(signature_ids)) != SIGNATURE_TIER_COUNT:
            errors.append(f"{faction_id} must expose seven unique signature unit buildings")
            continue
        if len(ladder_ids) != SIGNATURE_TIER_COUNT or len(set(ladder_ids)) != SIGNATURE_TIER_COUNT:
            errors.append(f"{faction_id} must expose seven unique unit ids")
            continue
        seed_town = towns.get(str(faction.get("seed_town_id", "")), {})
        rare_id = str(seed_town.get("development_balance", {}).get("rare_resource_id", "")).strip()
        if rare_id not in RARE_RESOURCES:
            errors.append(f"{faction_id} seed town must declare a live rare resource")
        tier_costs: list[dict[str, Any]] = []
        for tier, building_id in enumerate(signature_ids, start=1):
            building = buildings.get(building_id, {})
            unit = units.get(ladder_ids[tier - 1], {})
            cost = cost_payload(building)
            cost_ids = set(cost)
            rare_ids = sorted(cost_ids & RARE_RESOURCES)
            if str(building.get("unlock_unit_id", "")) != ladder_ids[tier - 1]:
                errors.append(f"{faction_id} tier {tier} building {building_id} must unlock {ladder_ids[tier - 1]}")
            if int(unit.get("tier", 0)) != tier:
                errors.append(f"{faction_id} unit {ladder_ids[tier - 1]} must be authored as tier {tier}")
            if "gold" not in cost_ids:
                errors.append(f"{building_id} tier {tier} must include gold in its cost")
            if not cost_ids.issubset(LIVE_RESOURCES):
                errors.append(f"{building_id} tier {tier} uses unsupported cost ids {sorted(cost_ids - LIVE_RESOURCES)}")
            if tier < HIGH_TIER_START and rare_ids:
                errors.append(f"{building_id} tier {tier} must remain common-resource only")
            if tier >= HIGH_TIER_START:
                if rare_ids != [rare_id]:
                    errors.append(f"{building_id} tier {tier} must cost only faction rare {rare_id}, got {rare_ids}")
                if not {"wood", "ore"}.issubset(cost_ids):
                    errors.append(f"{building_id} tier {tier} must pair rare cost with wood and ore")
            tier_costs.append(
                {
                    "tier": tier,
                    "building_id": building_id,
                    "unit_id": ladder_ids[tier - 1],
                    "cost": cost,
                    "rare_cost_ids": rare_ids,
                }
            )
        faction_curves[faction_id] = {
            "rare_resource_id": rare_id,
            "signature_tier_costs": tier_costs,
            "curve_signature": "|".join(
                "%d:%s:%s" % (
                    row["tier"],
                    ",".join(sorted(row["cost"].keys())),
                    ",".join(row["rare_cost_ids"]),
                )
                for row in tier_costs
            ),
        }

    curve_signatures = [str(row.get("curve_signature", "")) for row in faction_curves.values()]
    if len(set(curve_signatures)) != len(curve_signatures):
        errors.append("Faction signature cost curves must stay distinct by tier resource shape and rare id")

    for town_id, town in sorted(towns.items()):
        faction_id = str(town.get("faction_id", ""))
        faction = factions.get(faction_id, {})
        profile = town.get("development_balance", {})
        profile = profile if isinstance(profile, dict) else {}
        town_rare_id = str(profile.get("rare_resource_id", "")).strip()
        signature_ids = [str(value) for value in faction.get("signature_building_ids", [])]
        high_tier_signature_ids = set(signature_ids[HIGH_TIER_START - 1:])
        high_tier_gate_ids: set[str] = set(high_tier_signature_ids)
        for building_id in high_tier_signature_ids:
            high_tier_gate_ids.update(prerequisite_closure(building_id, buildings))

        target_ids = [str(value) for value in town.get("buildable_building_ids", [])]
        common_only_count = 0
        rare_cost_count = 0
        gold_cost_count = 0
        total_costs: dict[str, int] = {resource_id: 0 for resource_id in sorted(LIVE_RESOURCES)}
        rare_buildings: list[dict[str, Any]] = []
        common_only_buildings: list[str] = []
        for building_id in target_ids:
            building = buildings.get(building_id, {})
            cost = cost_payload(building)
            cost_ids = set(cost)
            rare_ids = sorted(cost_ids & RARE_RESOURCES)
            if not cost:
                errors.append(f"{town_id}/{building_id} must have a non-empty cost")
            if "gold" in cost_ids:
                gold_cost_count += 1
            else:
                errors.append(f"{town_id}/{building_id} must include gold in its cost")
            if not cost_ids.issubset(LIVE_RESOURCES):
                errors.append(f"{town_id}/{building_id} uses unsupported cost ids {sorted(cost_ids - LIVE_RESOURCES)}")
            for resource_id, amount in cost.items():
                total_costs[resource_id] = int(total_costs.get(resource_id, 0)) + amount
            if rare_ids:
                rare_cost_count += 1
                if rare_ids != [town_rare_id]:
                    errors.append(f"{town_id}/{building_id} must cost only town rare {town_rare_id}, got {rare_ids}")
                if not {"gold", "wood", "ore"}.issubset(cost_ids):
                    errors.append(f"{town_id}/{building_id} rare cost must be paired with gold, wood, and ore")
                allowed_by_signature = building_id in high_tier_signature_ids
                allowed_by_late_gate = bool(set(prerequisite_closure(building_id, buildings)) & high_tier_signature_ids)
                if not (allowed_by_signature or allowed_by_late_gate):
                    errors.append(f"{town_id}/{building_id} rare cost must be gated behind tier {HIGH_TIER_START}+ development")
                rare_buildings.append({"building_id": building_id, "rare_ids": rare_ids, "cost": cost})
            else:
                common_only_count += 1
                common_only_buildings.append(building_id)

        if common_only_count < rare_cost_count * MIN_COMMON_ONLY_TO_RARE_RATIO:
            errors.append(
                f"{town_id} must keep common-only development at least {MIN_COMMON_ONLY_TO_RARE_RATIO}:1 over rare-cost buildings"
            )
        if rare_cost_count < 3:
            errors.append(f"{town_id} must include rare-resource pressure in at least three high-tier buildings")
        if gold_cost_count != len(target_ids):
            errors.append(f"{town_id} must keep gold as a cost on every development target")
        if int(total_costs.get(town_rare_id, 0)) <= 0:
            errors.append(f"{town_id} must spend its faction rare resource across development")
        if int(total_costs.get(town_rare_id, 0)) < MIN_RARE_DEVELOPMENT_SPEND:
            errors.append(f"{town_id} must spend at least {MIN_RARE_DEVELOPMENT_SPEND} faction rare resources across development")
        if int(total_costs.get("gold", 0)) <= int(total_costs.get("wood", 0)) + int(total_costs.get("ore", 0)):
            errors.append(f"{town_id} gold must remain the dominant numeric development cost")
        if int(total_costs.get("wood", 0)) <= 0 or int(total_costs.get("ore", 0)) <= 0:
            errors.append(f"{town_id} must spend both wood and ore across development")

        town_rows[town_id] = {
            "faction_id": faction_id,
            "rare_resource_id": town_rare_id,
            "target_building_count": len(target_ids),
            "gold_cost_building_count": gold_cost_count,
            "common_only_building_count": common_only_count,
            "rare_cost_building_count": rare_cost_count,
            "common_only_to_rare_ratio": round(common_only_count / max(1, rare_cost_count), 2),
            "total_costs": {key: value for key, value in sorted(total_costs.items()) if value},
            "rare_buildings": rare_buildings,
            "common_only_buildings": common_only_buildings,
        }

    report = {
        "schema": REPORT_SCHEMA,
        "ok": not errors,
        "authored_town_count": len(towns),
        "faction_count": len(factions),
        "signature_tier_count": SIGNATURE_TIER_COUNT,
        "high_tier_start": HIGH_TIER_START,
        "common_resources": sorted(COMMON_RESOURCES),
        "rare_resources": sorted(RARE_RESOURCES),
        "min_common_only_to_rare_ratio": MIN_COMMON_ONLY_TO_RARE_RATIO,
        "min_rare_development_spend": MIN_RARE_DEVELOPMENT_SPEND,
        "faction_curves": faction_curves,
        "towns": town_rows,
        "errors": errors,
    }
    print("TOWN_DEVELOPMENT_COST_CURVE_REPORT " + json.dumps(report, sort_keys=True))
    return 0 if not errors else 1


if __name__ == "__main__":
    sys.exit(main())
