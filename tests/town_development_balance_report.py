#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "content"

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
TARGET_TURNS = 30


def load_items(filename: str) -> dict[str, dict[str, Any]]:
    with (CONTENT / filename).open(encoding="utf-8") as handle:
        payload = json.load(handle)
    return {str(item["id"]): item for item in payload.get("items", [])}


def add_resources(pool: dict[str, int], delta: dict[str, Any]) -> None:
    for key, value in delta.items():
        resource_id = str(key)
        if resource_id == "experience":
            continue
        pool[resource_id] = max(0, int(pool.get(resource_id, 0)) + int(value))


def can_afford(pool: dict[str, int], cost: dict[str, Any]) -> bool:
    return all(int(pool.get(str(key), 0)) >= int(value) for key, value in cost.items())


def spend(pool: dict[str, int], cost: dict[str, Any]) -> None:
    for key, value in cost.items():
        resource_id = str(key)
        pool[resource_id] = max(0, int(pool.get(resource_id, 0)) - int(value))


def requirements_met(building: dict[str, Any], built: set[str]) -> bool:
    upgrade_from = str(building.get("upgrade_from", ""))
    if upgrade_from and upgrade_from not in built:
        return False
    return all(str(requirement) in built for requirement in building.get("requires", []))


def simulate_town(
    town: dict[str, Any],
    faction: dict[str, Any],
    buildings: dict[str, dict[str, Any]],
) -> dict[str, Any]:
    profile = town.get("development_balance", {})
    resources = {str(key): int(value) for key, value in profile.get("starting_resources", {}).items()}
    daily_income = profile.get("daily_income", {})
    target_turns = int(profile.get("target_complete_turns", TARGET_TURNS))
    built = {str(value) for value in town.get("starting_building_ids", [])}
    target_buildings = [str(value) for value in town.get("buildable_building_ids", [])]
    build_log: list[dict[str, Any]] = []
    stalled_days: list[dict[str, Any]] = []

    signature_order = {
        str(building_id): index
        for index, building_id in enumerate(faction.get("signature_building_ids", []), start=1)
    }

    for day in range(1, target_turns + 1):
        add_resources(resources, daily_income)
        available: list[str] = []
        for building_id in target_buildings:
            if building_id in built:
                continue
            building = buildings.get(building_id, {})
            if building and requirements_met(building, built):
                available.append(building_id)
        affordable = [
            building_id
            for building_id in available
            if can_afford(resources, buildings.get(building_id, {}).get("cost", {}))
        ]
        if not affordable:
            if available:
                stalled_days.append(
                    {
                        "day": day,
                        "available": available,
                        "resources": dict(sorted(resources.items())),
                    }
                )
            continue
        affordable.sort(
            key=lambda building_id: (
                signature_order.get(building_id, 99),
                target_buildings.index(building_id),
                building_id,
            )
        )
        selected = affordable[0]
        spend(resources, buildings[selected].get("cost", {}))
        built.add(selected)
        build_log.append({"day": day, "building_id": selected})
        if set(target_buildings).issubset(built):
            break

    missing = sorted(set(target_buildings) - built)
    return {
        "town_id": str(town.get("id", "")),
        "faction_id": str(town.get("faction_id", "")),
        "target_turns": target_turns,
        "completed": not missing,
        "completion_day": build_log[-1]["day"] if not missing and build_log else 0,
        "build_count": len(build_log),
        "missing_buildings": missing,
        "ending_resources": dict(sorted(resources.items())),
        "stalled_days": stalled_days[:5],
        "build_log": build_log,
    }


def main() -> int:
    factions = load_items("factions.json")
    towns = load_items("towns.json")
    buildings = load_items("buildings.json")
    sites = load_items("resource_sites.json")
    registry = load_items("../tests/fixtures/economy_resource_schema/resource_registry.json")

    errors: list[str] = []
    rare_source_ids: set[str] = set()
    for site in sites.values():
        for field in ("claim_rewards", "control_income", "rewards"):
            payload = site.get(field, {})
            if isinstance(payload, dict):
                rare_source_ids.update(str(key) for key in payload.keys() if str(key) in RARE_RESOURCES)

    report: dict[str, Any] = {
        "schema": "town_development_balance_report_v1",
        "target_turns": TARGET_TURNS,
        "live_resources": sorted(LIVE_RESOURCES),
        "rare_sources": sorted(rare_source_ids),
        "towns": {},
        "errors": errors,
    }

    for resource_id in sorted(LIVE_RESOURCES):
        item = registry.get(resource_id, {})
        if not item:
            errors.append(f"{resource_id} missing from economy resource registry")
            continue
        if item.get("stockpile") is not True:
            errors.append(f"{resource_id} must be a stockpile resource")
        if resource_id in RARE_RESOURCES:
            if item.get("activation_status") != "live_stockpile":
                errors.append(f"{resource_id} must be activated as live_stockpile")
            if item.get("report_only") is True:
                errors.append(f"{resource_id} must not remain report_only")
            if resource_id not in rare_source_ids:
                errors.append(f"{resource_id} must have at least one live source")

    town_count = 0
    full_ladder_town_count = 0
    for town_id, town in towns.items():
        town_count += 1
        faction_id = str(town.get("faction_id", ""))
        faction = factions.get(faction_id, {})
        if not faction:
            errors.append(f"{town_id} references missing faction {faction_id}")
            continue
        profile = town.get("development_balance", {})
        if not isinstance(profile, dict) or not profile:
            errors.append(f"{town_id} must declare development_balance for authored-town breadth")
            continue
        if int(profile.get("target_complete_turns", TARGET_TURNS)) > TARGET_TURNS:
            errors.append(f"{town_id} target_complete_turns must stay within {TARGET_TURNS}")
        if profile.get("one_build_per_turn") is not True:
            errors.append(f"{town_id} development_balance must require one_build_per_turn")
        rare_id = str(profile.get("rare_resource_id", ""))
        if rare_id not in RARE_RESOURCES:
            errors.append(f"{town_id} must declare a live rare_resource_id")
        for profile_key in ("starting_resources", "daily_income"):
            payload = profile.get(profile_key, {})
            if not isinstance(payload, dict) or not payload:
                errors.append(f"{town_id} development_balance.{profile_key} must be non-empty")
                continue
            unsupported = {str(key) for key in payload.keys()} - LIVE_RESOURCES
            if unsupported:
                errors.append(f"{town_id} development_balance.{profile_key} uses unsupported resources {sorted(unsupported)}")
            if profile_key == "daily_income" and rare_id not in payload:
                errors.append(f"{town_id} daily_income must include faction rare resource {rare_id}")
        town_buildings = {
            str(value)
            for value in town.get("starting_building_ids", []) + town.get("buildable_building_ids", [])
        }
        signature_ids = [str(value) for value in faction.get("signature_building_ids", [])]
        missing_signature = sorted(set(signature_ids) - town_buildings)
        if missing_signature:
            errors.append(f"{town_id} must expose all seven faction signature buildings: {missing_signature}")
        else:
            full_ladder_town_count += 1
        for building_id in town.get("buildable_building_ids", []):
            building = buildings.get(str(building_id), {})
            cost_ids = {str(key) for key in building.get("cost", {}).keys()}
            if not cost_ids.issubset(LIVE_RESOURCES):
                errors.append(f"{town_id}/{building_id} uses unsupported resources {sorted(cost_ids - LIVE_RESOURCES)}")
        result = simulate_town(town, faction, buildings)
        report["towns"][town_id] = result
        if not result["completed"]:
            errors.append(f"{town_id} did not fully develop: {result['missing_buildings']}")
        if int(result["completion_day"]) > TARGET_TURNS:
            errors.append(f"{town_id} completed on day {result['completion_day']}, above target {TARGET_TURNS}")
        if int(result["build_count"]) > TARGET_TURNS:
            errors.append(f"{town_id} violates one-build-per-turn count")

    report["authored_town_count"] = town_count
    report["full_ladder_town_count"] = full_ladder_town_count

    for faction_id, faction in factions.items():
        seed_town_id = str(faction.get("seed_town_id", ""))
        town = towns.get(seed_town_id, {})
        if not town:
            errors.append(f"{faction_id} seed town {seed_town_id} missing")
            continue
        signature_ids = [str(value) for value in faction.get("signature_building_ids", [])]
        ladder_ids = [str(value) for value in faction.get("unit_ladder_ids", [])]
        if len(signature_ids) != 7 or len(set(signature_ids)) != 7:
            errors.append(f"{faction_id} must expose seven signature unit buildings")
        if len(ladder_ids) != 7 or len(set(ladder_ids)) != 7:
            errors.append(f"{faction_id} must expose seven unit tiers")
        rare_id = str(town.get("development_balance", {}).get("rare_resource_id", ""))
        if rare_id not in RARE_RESOURCES:
            errors.append(f"{seed_town_id} must declare a live rare_resource_id")
        for tier, building_id in enumerate(signature_ids, start=1):
            building = buildings.get(building_id, {})
            if not building:
                errors.append(f"{building_id} missing")
                continue
            cost = building.get("cost", {})
            cost_ids = {str(key) for key in cost.keys()}
            if not cost_ids.issubset(LIVE_RESOURCES):
                errors.append(f"{building_id} uses unsupported resources {sorted(cost_ids - LIVE_RESOURCES)}")
            if tier <= 4 and cost_ids.intersection(RARE_RESOURCES):
                errors.append(f"{building_id} tier {tier} must remain common-resource only")
            if tier >= 5 and rare_id not in cost_ids:
                errors.append(f"{building_id} tier {tier} must cost faction rare resource {rare_id}")

    report["ok"] = not errors
    print("TOWN_DEVELOPMENT_BALANCE_REPORT " + json.dumps(report, sort_keys=True))
    return 0 if not errors else 1


if __name__ == "__main__":
    sys.exit(main())
