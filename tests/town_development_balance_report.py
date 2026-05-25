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
MIN_BUILDABLE_TARGETS = 20
MIN_NON_UNIT_BUILDABLE_TARGETS = 12
MIN_BREADTH_PARITY_BUILDINGS = 5
MIN_COMPLETION_DAY = 20
MIN_RARE_DEVELOPMENT_SPEND = 24
MAX_ENDING_RARE_AFTER_COMPLETION = 13
MIN_LATE_RARE_BOTTLENECK_DAY = 18
MIN_LATE_RARE_BOTTLENECK_DAYS_PER_TOWN = 1
MIN_HIGH_TIER_UNIT_BUILD_DAYS = {5: 4, 6: 12, 7: 22}
SIX_FACTION_BREADTH_PARITY_STATUS = "six_faction_town_breadth_parity"
SIX_FACTION_BREADTH_PARITY_FACTIONS = {
    "faction_thornwake",
    "faction_brasshollow",
    "faction_veilmourn",
}


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


def missing_costs(pool: dict[str, int], cost: dict[str, Any]) -> dict[str, int]:
    result: dict[str, int] = {}
    for key, value in cost.items():
        resource_id = str(key)
        missing = int(value) - int(pool.get(resource_id, 0))
        if missing > 0:
            result[resource_id] = missing
    return result


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
    rare_id = str(profile.get("rare_resource_id", ""))
    total_development_costs: dict[str, int] = {}
    for building_id in target_buildings:
        cost = buildings.get(building_id, {}).get("cost", {})
        if not isinstance(cost, dict):
            continue
        for resource_id, amount in cost.items():
            total_development_costs[str(resource_id)] = int(total_development_costs.get(str(resource_id), 0)) + int(amount)
    non_unit_buildings = [
        building_id
        for building_id in target_buildings
        if not str(buildings.get(building_id, {}).get("unlock_unit_id", "")).strip()
    ]
    breadth_parity_buildings = [
        building_id
        for building_id in target_buildings
        if str(buildings.get(building_id, {}).get("content_status", "")) == SIX_FACTION_BREADTH_PARITY_STATUS
    ]
    build_log: list[dict[str, Any]] = []
    stalled_days: list[dict[str, Any]] = []
    late_rare_bottleneck_days: list[dict[str, Any]] = []

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
                blocked_by = []
                for building_id in available:
                    cost = buildings.get(building_id, {}).get("cost", {})
                    missing = missing_costs(resources, cost if isinstance(cost, dict) else {})
                    if not missing:
                        continue
                    blocked_by.append(
                        {
                            "building_id": building_id,
                            "missing": dict(sorted(missing.items())),
                        }
                    )
                    if (
                        day >= MIN_LATE_RARE_BOTTLENECK_DAY
                        and rare_id in missing
                        and int(cost.get(rare_id, 0)) > 0
                    ):
                        late_rare_bottleneck_days.append(
                            {
                                "day": day,
                                "building_id": building_id,
                                "rare_resource_id": rare_id,
                                "available_rare": int(resources.get(rare_id, 0)),
                                "required_rare": int(cost.get(rare_id, 0)),
                                "missing_rare": int(missing.get(rare_id, 0)),
                            }
                        )
                stalled_days.append(
                    {
                        "day": day,
                        "available": available,
                        "resources": dict(sorted(resources.items())),
                        "blocked_by": blocked_by,
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
    build_days_by_id = {str(entry["building_id"]): int(entry["day"]) for entry in build_log}
    signature_tier_build_days = {
        str(tier): build_days_by_id.get(building_id, 0)
        for building_id, tier in signature_order.items()
        if int(tier) >= 5
    }
    return {
        "town_id": str(town.get("id", "")),
        "faction_id": str(town.get("faction_id", "")),
        "target_turns": target_turns,
        "target_building_count": len(target_buildings),
        "non_unit_building_count": len(non_unit_buildings),
        "breadth_parity_building_count": len(breadth_parity_buildings),
        "completed": not missing,
        "completion_day": build_log[-1]["day"] if not missing and build_log else 0,
        "build_count": len(build_log),
        "missing_buildings": missing,
        "ending_resources": dict(sorted(resources.items())),
        "total_development_costs": dict(sorted(total_development_costs.items())),
        "rare_development_spend": int(total_development_costs.get(rare_id, 0)),
        "ending_rare_resource": int(resources.get(rare_id, 0)),
        "late_rare_bottleneck_days": late_rare_bottleneck_days,
        "late_rare_bottleneck_day_count": len({int(row["day"]) for row in late_rare_bottleneck_days}),
        "min_late_rare_bottleneck_day": MIN_LATE_RARE_BOTTLENECK_DAY,
        "min_late_rare_bottleneck_days_per_town": MIN_LATE_RARE_BOTTLENECK_DAYS_PER_TOWN,
        "signature_tier_build_days": signature_tier_build_days,
        "min_high_tier_unit_build_days": {str(key): value for key, value in MIN_HIGH_TIER_UNIT_BUILD_DAYS.items()},
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
        "min_completion_day": MIN_COMPLETION_DAY,
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
    breadth_parity_town_count = 0
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
        target_building_ids = [str(value) for value in town.get("buildable_building_ids", [])]
        non_unit_building_ids = [
            building_id
            for building_id in target_building_ids
            if not str(buildings.get(building_id, {}).get("unlock_unit_id", "")).strip()
        ]
        if len(target_building_ids) < MIN_BUILDABLE_TARGETS:
            errors.append(f"{town_id} must expose at least {MIN_BUILDABLE_TARGETS} buildable development targets")
        if len(non_unit_building_ids) < MIN_NON_UNIT_BUILDABLE_TARGETS:
            errors.append(f"{town_id} must expose at least {MIN_NON_UNIT_BUILDABLE_TARGETS} non-unit development targets")
        breadth_parity_ids = [
            building_id
            for building_id in target_building_ids
            if str(buildings.get(building_id, {}).get("content_status", "")) == SIX_FACTION_BREADTH_PARITY_STATUS
        ]
        if faction_id in SIX_FACTION_BREADTH_PARITY_FACTIONS:
            if len(breadth_parity_ids) < MIN_BREADTH_PARITY_BUILDINGS:
                errors.append(f"{town_id} must include at least {MIN_BREADTH_PARITY_BUILDINGS} six-faction breadth-parity buildings")
            else:
                breadth_parity_town_count += 1
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
        if int(result["completion_day"]) < MIN_COMPLETION_DAY:
            errors.append(f"{town_id} completed on day {result['completion_day']}, below production pacing floor {MIN_COMPLETION_DAY}")
        if int(result["build_count"]) > TARGET_TURNS:
            errors.append(f"{town_id} violates one-build-per-turn count")
        if int(result.get("rare_development_spend", 0)) < MIN_RARE_DEVELOPMENT_SPEND:
            errors.append(f"{town_id} must spend at least {MIN_RARE_DEVELOPMENT_SPEND} faction rare resources across development")
        if int(result.get("ending_rare_resource", 0)) > MAX_ENDING_RARE_AFTER_COMPLETION:
            errors.append(f"{town_id} ends development with too much unspent faction rare resource")
        if int(result.get("late_rare_bottleneck_day_count", 0)) < MIN_LATE_RARE_BOTTLENECK_DAYS_PER_TOWN:
            errors.append(
                f"{town_id} must have at least {MIN_LATE_RARE_BOTTLENECK_DAYS_PER_TOWN} late rare-resource bottleneck days"
            )
        signature_tier_days = result.get("signature_tier_build_days", {})
        for tier, minimum_day in MIN_HIGH_TIER_UNIT_BUILD_DAYS.items():
            build_day = int(signature_tier_days.get(str(tier), 0))
            if build_day <= 0:
                errors.append(f"{town_id} must build tier {tier} signature unit building during development")
            elif build_day < minimum_day:
                errors.append(f"{town_id} builds tier {tier} signature unit building on day {build_day}, before pacing floor {minimum_day}")

    report["authored_town_count"] = town_count
    report["full_ladder_town_count"] = full_ladder_town_count
    report["breadth_parity_town_count"] = breadth_parity_town_count
    report["min_buildable_targets"] = MIN_BUILDABLE_TARGETS
    report["min_non_unit_buildable_targets"] = MIN_NON_UNIT_BUILDABLE_TARGETS
    report["min_breadth_parity_buildings"] = MIN_BREADTH_PARITY_BUILDINGS
    report["min_rare_development_spend"] = MIN_RARE_DEVELOPMENT_SPEND
    report["max_ending_rare_after_completion"] = MAX_ENDING_RARE_AFTER_COMPLETION
    report["min_late_rare_bottleneck_day"] = MIN_LATE_RARE_BOTTLENECK_DAY
    report["min_late_rare_bottleneck_days_per_town"] = MIN_LATE_RARE_BOTTLENECK_DAYS_PER_TOWN
    report["min_high_tier_unit_build_days"] = {str(key): value for key, value in MIN_HIGH_TIER_UNIT_BUILD_DAYS.items()}

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
