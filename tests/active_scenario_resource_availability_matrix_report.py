#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any


LIVE_STOCKPILE_RESOURCE_IDS = (
    "gold",
    "wood",
    "ore",
    "aetherglass",
    "embergrain",
    "peatwax",
    "verdant_grafts",
    "brass_scrip",
    "memory_salt",
)
RARE_RESOURCE_IDS = LIVE_STOCKPILE_RESOURCE_IDS[3:]
COMMON_SOURCE_REQUIRED_IDS = ("wood", "ore")
MIN_ACTIVE_SCENARIO_COUNT = 16
MIN_CAMPAIGN_SCENARIO_COUNT = 15
MIN_SKIRMISH_SCENARIO_COUNT = 16
MIN_PLAYER_TOWN_CASE_COUNT = 18
MIN_ENEMY_TOWN_CASE_COUNT = 20
MIN_CAMPAIGN_PLAYER_TOWN_CASE_COUNT = 17
MIN_SKIRMISH_PLAYER_TOWN_CASE_COUNT = 18
MIN_CAMPAIGN_ENEMY_TOWN_CASE_COUNT = 19
MIN_SKIRMISH_ENEMY_TOWN_CASE_COUNT = 20


def load_items(root: Path, path: str) -> dict[str, dict[str, Any]]:
    payload = json.loads((root / path).read_text(encoding="utf-8"))
    return {
        str(item.get("id", "")): item
        for item in payload.get("items", [])
        if isinstance(item, dict) and str(item.get("id", ""))
    }


def positive_int(value: Any) -> int:
    try:
        amount = int(value)
    except (TypeError, ValueError):
        return 0
    return max(0, amount)


def is_active_scenario(scenario: dict[str, Any]) -> bool:
    selection = scenario.get("selection", {})
    availability = selection.get("availability", {}) if isinstance(selection, dict) else {}
    return bool(availability.get("campaign", False)) or bool(availability.get("skirmish", False))


def launch_surfaces(scenario: dict[str, Any]) -> list[str]:
    selection = scenario.get("selection", {})
    availability = selection.get("availability", {}) if isinstance(selection, dict) else {}
    surfaces: list[str] = []
    if bool(availability.get("campaign", False)):
        surfaces.append("campaign")
    if bool(availability.get("skirmish", False)):
        surfaces.append("skirmish")
    return surfaces


def resource_payload(site: dict[str, Any], field: str) -> dict[str, int]:
    payload = site.get(field, {})
    if not isinstance(payload, dict):
        return {}
    return {
        str(resource_id): positive_int(amount)
        for resource_id, amount in payload.items()
        if positive_int(amount) > 0
    }


def site_output_rows(site: dict[str, Any]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for field in ("rewards", "claim_rewards"):
        for resource_id, amount in resource_payload(site, field).items():
            if resource_id in LIVE_STOCKPILE_RESOURCE_IDS:
                rows.append(
                    {
                        "resource_id": resource_id,
                        "amount": amount,
                        "field": field,
                        "persistent": False,
                    }
                )
    for resource_id, amount in resource_payload(site, "control_income").items():
        if resource_id in LIVE_STOCKPILE_RESOURCE_IDS:
            rows.append(
                {
                    "resource_id": resource_id,
                    "amount": amount,
                    "field": "control_income",
                    "persistent": bool(site.get("persistent_control", False)),
                }
            )
    return rows


def town_required_resources(town: dict[str, Any], buildings: dict[str, dict[str, Any]]) -> list[str]:
    required: set[str] = set()
    for building_id in town.get("buildable_building_ids", []):
        building = buildings.get(str(building_id), {})
        cost = building.get("cost", {}) if isinstance(building, dict) else {}
        if not isinstance(cost, dict):
            continue
        for resource_id, amount in cost.items():
            if str(resource_id) in LIVE_STOCKPILE_RESOURCE_IDS and positive_int(amount) > 0:
                required.add(str(resource_id))
    return sorted(required)


def build_report(root: Path) -> dict[str, Any]:
    scenarios = load_items(root, "content/scenarios.json")
    towns = load_items(root, "content/towns.json")
    buildings = load_items(root, "content/buildings.json")
    resource_sites = load_items(root, "content/resource_sites.json")

    resource_rows: dict[str, dict[str, Any]] = {
        resource_id: {
            "resource_id": resource_id,
            "active_scenario_count": 0,
            "source_observation_count": 0,
            "claim_source_count": 0,
            "persistent_source_count": 0,
            "campaign_source_scenario_count": 0,
            "skirmish_source_scenario_count": 0,
            "source_scenario_ids": [],
            "campaign_source_scenario_ids": [],
            "skirmish_source_scenario_ids": [],
            "development_cost_town_ids": [],
            "development_rare_town_ids": [],
        }
        for resource_id in LIVE_STOCKPILE_RESOURCE_IDS
    }
    active_scenario_ids: list[str] = []
    campaign_scenario_ids: list[str] = []
    skirmish_scenario_ids: list[str] = []
    town_cases: list[dict[str, Any]] = []
    errors: list[str] = []

    for town_id, town_template in sorted(towns.items()):
        if not isinstance(town_template, dict):
            continue
        required_ids = town_required_resources(town_template, buildings)
        rare_id = str(town_template.get("development_balance", {}).get("rare_resource_id", ""))
        for resource_id in required_ids:
            if resource_id in resource_rows:
                resource_rows[resource_id]["development_cost_town_ids"].append(town_id)
        if rare_id in RARE_RESOURCE_IDS:
            resource_rows[rare_id]["development_rare_town_ids"].append(town_id)

    for scenario_id, scenario in sorted(scenarios.items()):
        if not isinstance(scenario, dict) or not is_active_scenario(scenario):
            continue
        active_scenario_ids.append(scenario_id)
        surfaces = launch_surfaces(scenario)
        if "campaign" in surfaces:
            campaign_scenario_ids.append(scenario_id)
        if "skirmish" in surfaces:
            skirmish_scenario_ids.append(scenario_id)
        scenario_resource_ids: set[str] = set()
        scenario_persistent_resource_ids: set[str] = set()
        scenario_matching_sources: dict[str, list[str]] = {resource_id: [] for resource_id in LIVE_STOCKPILE_RESOURCE_IDS}

        resource_nodes = scenario.get("resource_nodes", [])
        if not isinstance(resource_nodes, list):
            errors.append(f"{scenario_id} resource_nodes must be a list")
            resource_nodes = []
        for node in resource_nodes:
            if not isinstance(node, dict):
                errors.append(f"{scenario_id} resource node must be an object")
                continue
            placement_id = str(node.get("placement_id", "")).strip()
            site_id = str(node.get("site_id", "")).strip()
            site = resource_sites.get(site_id, {})
            if not placement_id:
                errors.append(f"{scenario_id} has a resource node without placement_id")
            if not site:
                errors.append(f"{scenario_id}.{placement_id} references unknown site {site_id}")
                continue
            for output in site_output_rows(site):
                resource_id = str(output["resource_id"])
                row = resource_rows[resource_id]
                row["source_observation_count"] += 1
                if scenario_id not in row["source_scenario_ids"]:
                    row["source_scenario_ids"].append(scenario_id)
                    row["active_scenario_count"] += 1
                if "campaign" in surfaces and scenario_id not in row["campaign_source_scenario_ids"]:
                    row["campaign_source_scenario_ids"].append(scenario_id)
                    row["campaign_source_scenario_count"] += 1
                if "skirmish" in surfaces and scenario_id not in row["skirmish_source_scenario_ids"]:
                    row["skirmish_source_scenario_ids"].append(scenario_id)
                    row["skirmish_source_scenario_count"] += 1
                if bool(output.get("persistent", False)):
                    row["persistent_source_count"] += 1
                    scenario_persistent_resource_ids.add(resource_id)
                else:
                    row["claim_source_count"] += 1
                scenario_resource_ids.add(resource_id)
                scenario_matching_sources[resource_id].append(placement_id)

        for town_node in scenario.get("towns", []):
            if not isinstance(town_node, dict) or str(town_node.get("owner", "")) not in {"player", "enemy"}:
                continue
            town_id = str(town_node.get("town_id", "")).strip()
            town_template = towns.get(town_id, {})
            if not town_template:
                errors.append(f"{scenario_id}.{town_node.get('placement_id', '')} references unknown town {town_id}")
                continue
            required_ids = town_required_resources(town_template, buildings)
            non_gold_required_ids = [resource_id for resource_id in required_ids if resource_id != "gold"]
            rare_id = str(town_template.get("development_balance", {}).get("rare_resource_id", ""))
            missing_persistent = [
                resource_id
                for resource_id in non_gold_required_ids
                if resource_id not in scenario_persistent_resource_ids
            ]
            if rare_id not in RARE_RESOURCE_IDS:
                errors.append(f"{scenario_id}.{town_id} must declare a live rare_resource_id")
            elif rare_id not in required_ids:
                errors.append(f"{scenario_id}.{town_id} development costs must use faction rare {rare_id}")
            if any(resource_id not in required_ids for resource_id in COMMON_SOURCE_REQUIRED_IDS):
                errors.append(f"{scenario_id}.{town_id} development costs must use wood and ore")
            if missing_persistent:
                errors.append(
                    f"{scenario_id}.{town_id} lacks persistent active-scenario sources for "
                    + ", ".join(missing_persistent)
                )
            town_cases.append(
                {
                    "scenario_id": scenario_id,
                    "placement_id": str(town_node.get("placement_id", "")).strip(),
                    "owner": str(town_node.get("owner", "")),
                    "launch_surfaces": surfaces,
                    "town_id": town_id,
                    "faction_id": str(town_template.get("faction_id", "")),
                    "rare_resource_id": rare_id,
                    "required_resource_ids": required_ids,
                    "scenario_source_resource_ids": sorted(scenario_resource_ids),
                    "scenario_persistent_source_resource_ids": sorted(scenario_persistent_resource_ids),
                    "matching_rare_source_placement_ids": sorted(scenario_matching_sources.get(rare_id, [])),
                    "missing_persistent_required_resource_ids": missing_persistent,
                }
            )

    active_scenario_count = len(active_scenario_ids)
    campaign_scenario_count = len(campaign_scenario_ids)
    skirmish_scenario_count = len(skirmish_scenario_ids)
    player_town_case_count = sum(1 for case in town_cases if case["owner"] == "player")
    enemy_town_case_count = sum(1 for case in town_cases if case["owner"] == "enemy")
    campaign_player_town_case_count = sum(
        1 for case in town_cases if case["owner"] == "player" and "campaign" in case["launch_surfaces"]
    )
    skirmish_player_town_case_count = sum(
        1 for case in town_cases if case["owner"] == "player" and "skirmish" in case["launch_surfaces"]
    )
    campaign_enemy_town_case_count = sum(
        1 for case in town_cases if case["owner"] == "enemy" and "campaign" in case["launch_surfaces"]
    )
    skirmish_enemy_town_case_count = sum(
        1 for case in town_cases if case["owner"] == "enemy" and "skirmish" in case["launch_surfaces"]
    )

    if active_scenario_count < MIN_ACTIVE_SCENARIO_COUNT:
        errors.append(f"expected at least {MIN_ACTIVE_SCENARIO_COUNT} active scenarios, found {active_scenario_count}")
    if campaign_scenario_count < MIN_CAMPAIGN_SCENARIO_COUNT:
        errors.append(f"expected at least {MIN_CAMPAIGN_SCENARIO_COUNT} campaign scenarios, found {campaign_scenario_count}")
    if skirmish_scenario_count < MIN_SKIRMISH_SCENARIO_COUNT:
        errors.append(f"expected at least {MIN_SKIRMISH_SCENARIO_COUNT} skirmish scenarios, found {skirmish_scenario_count}")
    if player_town_case_count < MIN_PLAYER_TOWN_CASE_COUNT:
        errors.append(f"expected at least {MIN_PLAYER_TOWN_CASE_COUNT} player town cases, found {player_town_case_count}")
    if enemy_town_case_count < MIN_ENEMY_TOWN_CASE_COUNT:
        errors.append(f"expected at least {MIN_ENEMY_TOWN_CASE_COUNT} enemy town cases, found {enemy_town_case_count}")
    if campaign_player_town_case_count < MIN_CAMPAIGN_PLAYER_TOWN_CASE_COUNT:
        errors.append(
            f"expected at least {MIN_CAMPAIGN_PLAYER_TOWN_CASE_COUNT} campaign player town cases, "
            f"found {campaign_player_town_case_count}"
        )
    if skirmish_player_town_case_count < MIN_SKIRMISH_PLAYER_TOWN_CASE_COUNT:
        errors.append(
            f"expected at least {MIN_SKIRMISH_PLAYER_TOWN_CASE_COUNT} skirmish player town cases, "
            f"found {skirmish_player_town_case_count}"
        )
    if campaign_enemy_town_case_count < MIN_CAMPAIGN_ENEMY_TOWN_CASE_COUNT:
        errors.append(
            f"expected at least {MIN_CAMPAIGN_ENEMY_TOWN_CASE_COUNT} campaign enemy town cases, "
            f"found {campaign_enemy_town_case_count}"
        )
    if skirmish_enemy_town_case_count < MIN_SKIRMISH_ENEMY_TOWN_CASE_COUNT:
        errors.append(
            f"expected at least {MIN_SKIRMISH_ENEMY_TOWN_CASE_COUNT} skirmish enemy town cases, "
            f"found {skirmish_enemy_town_case_count}"
        )
    for resource_id, row in resource_rows.items():
        if row["source_observation_count"] <= 0:
            errors.append(f"{resource_id} has no active-scenario source observations")
        if resource_id in {"gold", "wood", "ore"} and row["active_scenario_count"] < active_scenario_count:
            errors.append(f"{resource_id} must appear in every active scenario source ecology")
        if row["campaign_source_scenario_count"] <= 0:
            errors.append(f"{resource_id} has no campaign scenario source observations")
        if row["skirmish_source_scenario_count"] <= 0:
            errors.append(f"{resource_id} has no skirmish scenario source observations")
        if resource_id in RARE_RESOURCE_IDS:
            if row["persistent_source_count"] <= 0:
                errors.append(f"{resource_id} has no persistent active-scenario source")
            if not row["development_rare_town_ids"]:
                errors.append(f"{resource_id} is not assigned as any active town development rare")

    matrix_basis = {
        "active_scenario_ids": active_scenario_ids,
        "campaign_scenario_ids": campaign_scenario_ids,
        "skirmish_scenario_ids": skirmish_scenario_ids,
        "resources": {
            resource_id: {
                "source_observation_count": row["source_observation_count"],
                "persistent_source_count": row["persistent_source_count"],
                "active_scenario_count": row["active_scenario_count"],
                "campaign_source_scenario_count": row["campaign_source_scenario_count"],
                "skirmish_source_scenario_count": row["skirmish_source_scenario_count"],
                "development_rare_town_count": len(row["development_rare_town_ids"]),
            }
            for resource_id, row in resource_rows.items()
        },
        "town_case_count": len(town_cases),
    }
    matrix_signature = hashlib.sha256(json.dumps(matrix_basis, sort_keys=True).encode("utf-8")).hexdigest()[:12]
    return {
        "schema": "active_scenario_resource_availability_matrix_v1",
        "matrix_signature": matrix_signature,
        "live_stockpile_resource_ids": list(LIVE_STOCKPILE_RESOURCE_IDS),
        "rare_resource_ids": list(RARE_RESOURCE_IDS),
        "active_scenario_count": active_scenario_count,
        "active_scenario_ids": active_scenario_ids,
        "campaign_scenario_count": campaign_scenario_count,
        "campaign_scenario_ids": campaign_scenario_ids,
        "skirmish_scenario_count": skirmish_scenario_count,
        "skirmish_scenario_ids": skirmish_scenario_ids,
        "town_case_count": len(town_cases),
        "player_town_case_count": player_town_case_count,
        "enemy_town_case_count": enemy_town_case_count,
        "campaign_player_town_case_count": campaign_player_town_case_count,
        "skirmish_player_town_case_count": skirmish_player_town_case_count,
        "campaign_enemy_town_case_count": campaign_enemy_town_case_count,
        "skirmish_enemy_town_case_count": skirmish_enemy_town_case_count,
        "resource_rows": [resource_rows[resource_id] for resource_id in LIVE_STOCKPILE_RESOURCE_IDS],
        "town_cases": town_cases,
        "normal_market_policy": {
            "buy_resource_ids": ["wood", "ore"],
            "rare_resource_buying_enabled": False,
        },
        "errors": errors,
    }


def print_report(report: dict[str, Any]) -> None:
    print("ACTIVE SCENARIO RESOURCE AVAILABILITY MATRIX")
    print(f"- schema: {report['schema']}")
    print(f"- matrix_signature: {report['matrix_signature']}")
    print(
        "- coverage: "
        f"{report['active_scenario_count']} active scenarios, "
        f"{report['campaign_scenario_count']} campaign scenarios, "
        f"{report['skirmish_scenario_count']} skirmish scenarios, "
        f"{report['player_town_case_count']} player-town cases, "
        f"{report['enemy_town_case_count']} enemy-town cases"
    )
    print("- resources:")
    for row in report["resource_rows"]:
        print(
            f"  {row['resource_id']}: sources={row['source_observation_count']}, "
            f"persistent={row['persistent_source_count']}, "
            f"active_scenarios={row['active_scenario_count']}, "
            f"cost_towns={len(row['development_cost_town_ids'])}, "
            f"rare_towns={len(row['development_rare_town_ids'])}"
        )
    print(
        "- normal market: "
        f"buy={','.join(report['normal_market_policy']['buy_resource_ids'])}; "
        f"rare_buying={report['normal_market_policy']['rare_resource_buying_enabled']}"
    )
    if report["errors"]:
        print("Errors:")
        for error in report["errors"]:
            print(f"- {error}")
    else:
        print("Errors: 0")


def main() -> int:
    parser = argparse.ArgumentParser(description="Report active-scenario economy resource source coverage.")
    parser.add_argument("--json", action="store_true", help="Print the report as JSON.")
    parser.add_argument("--root", default=str(Path(__file__).resolve().parents[1]), help="Repository root.")
    args = parser.parse_args()
    report = build_report(Path(args.root).resolve())
    if args.json:
        print(json.dumps(report, indent=2, sort_keys=True))
    else:
        print_report(report)
    return 1 if report["errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
