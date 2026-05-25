#!/usr/bin/env python3
from __future__ import annotations

import json
import argparse
import os
import subprocess
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "content"

REPORT_SCHEMA = "economy_town_goal_scorecard_report_v1"
SLICE_ID = "economy-town-goal-scorecard-20260524-10184"
TARGET_TURNS = 30
MIN_AUTHORED_TOWNS = 15
MIN_FACTIONS = 6
SIGNATURE_TIER_COUNT = 7
HIGH_TIER_START = 5
MIN_UNIQUE_NON_UNIT_PER_FACTION = 5
MIN_UNIQUE_NON_UNIT_PER_TOWN = 5
MIN_RARE_DEVELOPMENT_SPEND = 24
MAX_ENDING_RARE_AFTER_COMPLETION = 13
MIN_COMMON_ONLY_TO_RARE_RATIO = 2.0
EXPECTED_SIGNATURE_RARE_CURVE = {5: 4, 6: 8, 7: 10}
MIN_HIGH_TIER_UNIT_BUILD_DAYS = {5: 4, 6: 12, 7: 22}
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
GODOT_RUNTIME_REPORTS = (
    {
        "scene": "res://tests/town_development_runtime_balance_report.tscn",
        "marker": "TOWN_DEVELOPMENT_RUNTIME_BALANCE_REPORT",
        "quit_after": 300,
        "log_file": "/tmp/heroes-like-scorecard-town-runtime.log",
    },
    {
        "scene": "res://tests/active_scenario_town_development_runway_report.tscn",
        "marker": "ACTIVE_SCENARIO_TOWN_DEVELOPMENT_RUNWAY_REPORT",
        "quit_after": 500,
        "log_file": "/tmp/heroes-like-scorecard-active-player-town.log",
    },
    {
        "scene": "res://tests/active_scenario_ai_town_development_runway_report.tscn",
        "marker": "ACTIVE_SCENARIO_AI_TOWN_DEVELOPMENT_RUNWAY_REPORT",
        "quit_after": 700,
        "log_file": "/tmp/heroes-like-scorecard-active-ai-town.log",
    },
)


def load_items(filename: str) -> dict[str, dict[str, Any]]:
    with (CONTENT / filename).open(encoding="utf-8") as handle:
        payload = json.load(handle)
    return {str(item["id"]): item for item in payload.get("items", [])}


def load_fixture_index(path: Path) -> dict[str, dict[str, Any]]:
    with path.open(encoding="utf-8") as handle:
        payload = json.load(handle)
    return {str(item["id"]): item for item in payload.get("items", [])}


def run_report(script: str, marker: str) -> dict[str, Any]:
    result = subprocess.run(
        [sys.executable, str(ROOT / "tests" / script)],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(
            "%s failed with code %d\nSTDOUT:\n%s\nSTDERR:\n%s"
            % (script, result.returncode, result.stdout.strip(), result.stderr.strip())
        )
    prefix = marker + " "
    for line in result.stdout.splitlines():
        if line.startswith(prefix):
            return json.loads(line[len(prefix):])
    raise RuntimeError("%s did not emit %s marker" % (script, marker))


def run_json_report(script: str, *args: str) -> dict[str, Any]:
    result = subprocess.run(
        [sys.executable, str(ROOT / "tests" / script), *args],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(
            "%s failed with code %d\nSTDOUT:\n%s\nSTDERR:\n%s"
            % (script, result.returncode, result.stdout.strip(), result.stderr.strip())
        )
    return json.loads(result.stdout)


def run_godot_report(scene: str, marker: str, quit_after: int, log_file: str) -> dict[str, Any]:
    env = dict(os.environ)
    env["GODOT_SILENCE_ROOT_WARNING"] = "1"
    result = subprocess.run(
        [
            "godot",
            "--headless",
            "--quit-after",
            str(quit_after),
            "--log-file",
            log_file,
            "--path",
            ".",
            "--scene",
            scene,
        ],
        cwd=ROOT,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(
            "%s failed with code %d\nSTDOUT tail:\n%s\nSTDERR tail:\n%s"
            % (scene, result.returncode, result.stdout[-4000:], result.stderr[-4000:])
        )
    prefix = marker + " "
    for line in result.stdout.splitlines():
        if line.startswith(prefix):
            return json.loads(line[len(prefix):])
    raise RuntimeError("%s did not emit %s marker" % (scene, marker))


def cost_payload(building: dict[str, Any]) -> dict[str, int]:
    payload = building.get("cost", {})
    if not isinstance(payload, dict):
        return {}
    result: dict[str, int] = {}
    for resource_id, amount in payload.items():
        result[str(resource_id)] = int(amount)
    return result


def unique_non_unit_buildings_for_faction(
    faction_id: str,
    buildings: dict[str, dict[str, Any]],
) -> list[str]:
    result = []
    for building_id, building in buildings.items():
        if str(building.get("faction_id", "")) != faction_id:
            continue
        if str(building.get("unlock_unit_id", "")).strip():
            continue
        result.append(building_id)
    return sorted(result)


def add_check(checks: list[dict[str, Any]], check_id: str, ok: bool, summary: str, evidence: dict[str, Any]) -> None:
    checks.append(
        {
            "id": check_id,
            "ok": bool(ok),
            "summary": summary,
            "evidence": evidence,
        }
    )


def add_runtime_checks(checks: list[dict[str, Any]]) -> dict[str, Any]:
    payloads: dict[str, dict[str, Any]] = {}
    for config in GODOT_RUNTIME_REPORTS:
        payloads[str(config["marker"])] = run_godot_report(
            str(config["scene"]),
            str(config["marker"]),
            int(config["quit_after"]),
            str(config["log_file"]),
        )

    town_runtime = payloads["TOWN_DEVELOPMENT_RUNTIME_BALANCE_REPORT"]
    runtime_completion_ok = (
        town_runtime.get("ok") is True
        and int(town_runtime.get("authored_town_count", 0)) >= MIN_AUTHORED_TOWNS
        and int(town_runtime.get("recruitment_end_to_end_town_count", 0)) >= MIN_AUTHORED_TOWNS
        and int(town_runtime.get("seven_tier_recruitment_case_count", 0)) >= MIN_AUTHORED_TOWNS * SIGNATURE_TIER_COUNT
        and int(town_runtime.get("recruited_unit_case_count", 0)) >= MIN_AUTHORED_TOWNS * SIGNATURE_TIER_COUNT
    )
    add_check(
        checks,
        "live_runtime_development_and_recruitment",
        runtime_completion_ok,
        "Live Godot town development must complete all authored towns and recruit all seven tiers after development.",
        {
            "authored_town_count": int(town_runtime.get("authored_town_count", 0)),
            "recruitment_end_to_end_town_count": int(town_runtime.get("recruitment_end_to_end_town_count", 0)),
            "seven_tier_recruitment_case_count": int(town_runtime.get("seven_tier_recruitment_case_count", 0)),
            "recruited_unit_case_count": int(town_runtime.get("recruited_unit_case_count", 0)),
        },
    )

    player_runtime = payloads["ACTIVE_SCENARIO_TOWN_DEVELOPMENT_RUNWAY_REPORT"]
    player_runtime_ok = (
        player_runtime.get("ok") is True
        and int(player_runtime.get("active_scenario_count", 0)) >= 16
        and int(player_runtime.get("player_town_case_count", 0)) >= 18
        and int(player_runtime.get("completed_case_count", 0)) == int(player_runtime.get("player_town_case_count", -1))
        and int(player_runtime.get("delayed_source_replay_completed_count", 0)) == int(player_runtime.get("player_town_case_count", -1))
        and int(player_runtime.get("delayed_source_save_resume_completed_count", 0)) == int(player_runtime.get("player_town_case_count", -1))
        and int(player_runtime.get("recruited_unit_case_count", 0)) >= 18 * SIGNATURE_TIER_COUNT
    )
    add_check(
        checks,
        "active_scenario_player_runway_runtime",
        player_runtime_ok,
        "Active player-town scenarios must complete development, delayed-source replay, save/resume, and seven-tier recruitment.",
        {
            "active_scenario_count": int(player_runtime.get("active_scenario_count", 0)),
            "player_town_case_count": int(player_runtime.get("player_town_case_count", 0)),
            "completed_case_count": int(player_runtime.get("completed_case_count", 0)),
            "delayed_source_replay_completed_count": int(player_runtime.get("delayed_source_replay_completed_count", 0)),
            "delayed_source_save_resume_completed_count": int(player_runtime.get("delayed_source_save_resume_completed_count", 0)),
            "recruited_unit_case_count": int(player_runtime.get("recruited_unit_case_count", 0)),
        },
    )

    ai_runtime = payloads["ACTIVE_SCENARIO_AI_TOWN_DEVELOPMENT_RUNWAY_REPORT"]
    ai_runtime_ok = (
        ai_runtime.get("ok") is True
        and int(ai_runtime.get("active_scenario_count", 0)) >= 16
        and int(ai_runtime.get("enemy_town_case_count", 0)) >= 20
        and int(ai_runtime.get("completed_case_count", 0)) == int(ai_runtime.get("enemy_town_case_count", -1))
        and int(ai_runtime.get("same_day_guard_case_count", 0)) == int(ai_runtime.get("enemy_town_case_count", -1))
        and int(ai_runtime.get("delayed_source_replay_completed_count", 0)) == int(ai_runtime.get("enemy_town_case_count", -1))
        and int(ai_runtime.get("delayed_source_save_resume_completed_count", 0)) == int(ai_runtime.get("enemy_town_case_count", -1))
    )
    add_check(
        checks,
        "active_scenario_ai_runway_runtime",
        ai_runtime_ok,
        "Active enemy-town scenarios must complete AI town development, delayed-source replay, save/resume, and same-day build guards.",
        {
            "active_scenario_count": int(ai_runtime.get("active_scenario_count", 0)),
            "enemy_town_case_count": int(ai_runtime.get("enemy_town_case_count", 0)),
            "completed_case_count": int(ai_runtime.get("completed_case_count", 0)),
            "same_day_guard_case_count": int(ai_runtime.get("same_day_guard_case_count", 0)),
            "delayed_source_replay_completed_count": int(ai_runtime.get("delayed_source_replay_completed_count", 0)),
            "delayed_source_save_resume_completed_count": int(ai_runtime.get("delayed_source_save_resume_completed_count", 0)),
        },
    )
    return {
        "town_development_runtime_balance_report_v1": {
            "authored_town_count": int(town_runtime.get("authored_town_count", 0)),
            "recruitment_end_to_end_town_count": int(town_runtime.get("recruitment_end_to_end_town_count", 0)),
        },
        "active_scenario_town_development_runway_report_v1": {
            "active_scenario_count": int(player_runtime.get("active_scenario_count", 0)),
            "player_town_case_count": int(player_runtime.get("player_town_case_count", 0)),
        },
        "active_scenario_ai_town_development_runway_report_v1": {
            "active_scenario_count": int(ai_runtime.get("active_scenario_count", 0)),
            "enemy_town_case_count": int(ai_runtime.get("enemy_town_case_count", 0)),
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Report the economy/town objective scorecard.")
    parser.add_argument(
        "--include-runtime",
        action="store_true",
        help="Run the long Godot town-development runtime and active-scenario runway reports as additional scorecard checks.",
    )
    args = parser.parse_args()

    factions = load_items("factions.json")
    towns = load_items("towns.json")
    buildings = load_items("buildings.json")
    units = load_items("units.json")
    registry = load_fixture_index(ROOT / "tests" / "fixtures" / "economy_resource_schema" / "resource_registry.json")

    balance = run_report("town_development_balance_report.py", "TOWN_DEVELOPMENT_BALANCE_REPORT")
    cost_curve = run_report("town_development_cost_curve_report.py", "TOWN_DEVELOPMENT_COST_CURVE_REPORT")
    asymmetry = run_report("faction_town_unit_asymmetry_report.py", "FACTION_TOWN_UNIT_ASYMMETRY_REPORT")
    source_matrix = run_json_report("active_scenario_resource_availability_matrix_report.py", "--json")

    checks: list[dict[str, Any]] = []

    live_registry_ok = all(
        resource_id in registry
        and registry[resource_id].get("stockpile") is True
        and (resource_id in COMMON_RESOURCES or registry[resource_id].get("activation_status") == "live_stockpile")
        for resource_id in LIVE_RESOURCES
    )
    resource_rows = source_matrix.get("resource_rows", []) if isinstance(source_matrix.get("resource_rows", []), list) else []
    matrix_resources = {
        str(row.get("resource_id", "")): row
        for row in resource_rows
        if isinstance(row, dict) and str(row.get("resource_id", ""))
    }
    matrix_ok = set(matrix_resources) == LIVE_RESOURCES and all(
        int(row.get("source_observation_count", 0)) > 0 for row in matrix_resources.values()
    )
    add_check(
        checks,
        "all_live_resources_wired",
        live_registry_ok and matrix_ok,
        "All nine resources must be live stockpile ids with active-scenario source coverage.",
        {
            "live_resources": sorted(LIVE_RESOURCES),
            "matrix_signature": source_matrix.get("matrix_signature", ""),
            "active_scenario_count": int(source_matrix.get("active_scenario_count", 0)),
        },
    )

    town_rows = balance.get("towns", {}) if isinstance(balance.get("towns", {}), dict) else {}
    completion_days = [int(row.get("completion_day", 0)) for row in town_rows.values() if isinstance(row, dict)]
    end_to_end_ok = (
        balance.get("ok") is True
        and int(balance.get("authored_town_count", 0)) >= MIN_AUTHORED_TOWNS
        and len(town_rows) >= MIN_AUTHORED_TOWNS
        and all(20 <= day <= TARGET_TURNS for day in completion_days)
        and all(
            isinstance(row, dict)
            and row.get("completed") is True
            and int(row.get("build_count", 0)) == int(row.get("target_building_count", -1))
            for row in town_rows.values()
        )
    )
    add_check(
        checks,
        "authored_town_development_end_to_end",
        end_to_end_ok,
        "Every authored town must fully develop end to end within the 30-turn target.",
        {
            "authored_town_count": int(balance.get("authored_town_count", 0)),
            "completion_day_min": min(completion_days) if completion_days else 0,
            "completion_day_max": max(completion_days) if completion_days else 0,
            "target_turns": TARGET_TURNS,
        },
    )

    one_build_ok = True
    for town_id, town in towns.items():
        profile = town.get("development_balance", {})
        if not isinstance(profile, dict) or profile.get("one_build_per_turn") is not True:
            one_build_ok = False
            break
        row = town_rows.get(town_id, {})
        log = row.get("build_log", []) if isinstance(row, dict) else []
        days = [int(entry.get("day", 0)) for entry in log if isinstance(entry, dict)]
        if len(days) != len(set(days)):
            one_build_ok = False
            break
    add_check(
        checks,
        "one_build_per_town_turn",
        one_build_ok,
        "Town development must enforce one build per town turn in profiles and deterministic build logs.",
        {"town_count": len(towns), "profile_key": "one_build_per_turn"},
    )

    cost_rows = cost_curve.get("towns", {}) if isinstance(cost_curve.get("towns", {}), dict) else {}
    common_cost_ok = cost_curve.get("ok") is True
    for town_id, row in cost_rows.items():
        if not isinstance(row, dict):
            common_cost_ok = False
            continue
        total_costs = row.get("total_costs", {})
        total_costs = total_costs if isinstance(total_costs, dict) else {}
        common_total = sum(int(total_costs.get(resource_id, 0)) for resource_id in COMMON_RESOURCES)
        rare_total = sum(int(total_costs.get(resource_id, 0)) for resource_id in RARE_RESOURCES)
        if common_total <= rare_total:
            common_cost_ok = False
        if not all(int(total_costs.get(resource_id, 0)) > 0 for resource_id in COMMON_RESOURCES):
            common_cost_ok = False
        if float(row.get("common_only_to_rare_ratio", 0.0)) < MIN_COMMON_ONLY_TO_RARE_RATIO:
            common_cost_ok = False
    add_check(
        checks,
        "common_resource_dominant_cost_shape",
        common_cost_ok,
        "Town development should mainly cost gold, wood, and ore while keeping common-only buildings dominant.",
        {
            "min_common_only_to_rare_ratio": MIN_COMMON_ONLY_TO_RARE_RATIO,
            "town_count": len(cost_rows),
            "common_resources": sorted(COMMON_RESOURCES),
        },
    )

    rare_pressure_ok = (
        int(balance.get("min_rare_development_spend", 0)) >= MIN_RARE_DEVELOPMENT_SPEND
        and int(balance.get("max_ending_rare_after_completion", 999)) <= MAX_ENDING_RARE_AFTER_COMPLETION
        and int(cost_curve.get("high_tier_start", 0)) == HIGH_TIER_START
    )
    faction_curves = cost_curve.get("faction_curves", {}) if isinstance(cost_curve.get("faction_curves", {}), dict) else {}
    for faction_id, row in faction_curves.items():
        if not isinstance(row, dict):
            rare_pressure_ok = False
            continue
        rare_id = str(row.get("rare_resource_id", ""))
        for tier_row in row.get("signature_tier_costs", []):
            if not isinstance(tier_row, dict):
                rare_pressure_ok = False
                continue
            tier = int(tier_row.get("tier", 0))
            cost = tier_row.get("cost", {})
            cost = cost if isinstance(cost, dict) else {}
            rare_costs = {resource_id: int(cost.get(resource_id, 0)) for resource_id in RARE_RESOURCES if int(cost.get(resource_id, 0)) > 0}
            if tier < HIGH_TIER_START and rare_costs:
                rare_pressure_ok = False
            if tier in EXPECTED_SIGNATURE_RARE_CURVE and rare_costs != {rare_id: EXPECTED_SIGNATURE_RARE_CURVE[tier]}:
                rare_pressure_ok = False
    add_check(
        checks,
        "high_tier_rare_resource_pressure",
        rare_pressure_ok,
        "High-tier unit buildings must use the faction rare resource on the 4/8/10 tier curve.",
        {
            "high_tier_start": HIGH_TIER_START,
            "expected_signature_rare_curve": EXPECTED_SIGNATURE_RARE_CURVE,
            "min_rare_development_spend": MIN_RARE_DEVELOPMENT_SPEND,
            "max_ending_rare_after_completion": MAX_ENDING_RARE_AFTER_COMPLETION,
        },
    )

    high_tier_pacing_ok = balance.get("min_high_tier_unit_build_days", {}) == {
        str(key): value for key, value in MIN_HIGH_TIER_UNIT_BUILD_DAYS.items()
    }
    high_tier_days_by_town: dict[str, dict[str, int]] = {}
    for town_id, row in town_rows.items():
        if not isinstance(row, dict):
            high_tier_pacing_ok = False
            continue
        days = row.get("signature_tier_build_days", {})
        days = days if isinstance(days, dict) else {}
        high_tier_days_by_town[town_id] = {str(tier): int(days.get(str(tier), 0)) for tier in MIN_HIGH_TIER_UNIT_BUILD_DAYS}
        for tier, minimum_day in MIN_HIGH_TIER_UNIT_BUILD_DAYS.items():
            build_day = int(days.get(str(tier), 0))
            if build_day < minimum_day:
                high_tier_pacing_ok = False
    add_check(
        checks,
        "high_tier_unit_build_pacing",
        high_tier_pacing_ok,
        "Tier 5-7 unit buildings must arrive late enough to preserve the 30-turn development pacing curve.",
        {
            "min_high_tier_unit_build_days": MIN_HIGH_TIER_UNIT_BUILD_DAYS,
            "town_count": len(high_tier_days_by_town),
            "tier_7_day_min": min((row.get("7", 0) for row in high_tier_days_by_town.values()), default=0),
            "tier_7_day_max": max((row.get("7", 0) for row in high_tier_days_by_town.values()), default=0),
        },
    )

    unique_ok = True
    unique_rows: dict[str, dict[str, Any]] = {}
    rare_ids_by_faction: dict[str, str] = {}
    for faction_id, faction in factions.items():
        seed_town = towns.get(str(faction.get("seed_town_id", "")), {})
        rare_id = str(seed_town.get("development_balance", {}).get("rare_resource_id", ""))
        rare_ids_by_faction[faction_id] = rare_id
        unique_ids = unique_non_unit_buildings_for_faction(faction_id, buildings)
        rare_unique_count = sum(1 for building_id in unique_ids if int(cost_payload(buildings[building_id]).get(rare_id, 0)) > 0)
        town_counts = {}
        for town_id in [str(value) for value in faction.get("town_ids", [])]:
            town = towns.get(town_id, {})
            buildable = {str(value) for value in town.get("buildable_building_ids", [])}
            town_counts[town_id] = len(set(unique_ids) & buildable)
        if len(unique_ids) < MIN_UNIQUE_NON_UNIT_PER_FACTION or rare_unique_count <= 0:
            unique_ok = False
        if any(count < MIN_UNIQUE_NON_UNIT_PER_TOWN for count in town_counts.values()):
            unique_ok = False
        unique_rows[faction_id] = {
            "unique_non_unit_building_count": len(unique_ids),
            "rare_unique_count": rare_unique_count,
            "town_unique_counts": town_counts,
        }
    asymmetry_ok = asymmetry.get("ok") is True and all(int(value) >= MIN_FACTIONS for value in asymmetry.get("unique_fingerprints", {}).values())
    add_check(
        checks,
        "faction_identity_and_unique_towns",
        unique_ok and asymmetry_ok and len(set(rare_ids_by_faction.values())) >= MIN_FACTIONS,
        "Each faction town line must have distinct economy identity and at least five unique non-unit buildings per authored town.",
        {
            "faction_count": len(factions),
            "unique_fingerprints": asymmetry.get("unique_fingerprints", {}),
            "rare_ids_by_faction": rare_ids_by_faction,
            "unique_buildings": unique_rows,
        },
    )

    seven_tier_ok = len(factions) >= MIN_FACTIONS
    tier_rows: dict[str, Any] = {}
    for faction_id, faction in factions.items():
        ladder_ids = [str(value) for value in faction.get("unit_ladder_ids", [])]
        signature_ids = [str(value) for value in faction.get("signature_building_ids", [])]
        faction_ok = len(ladder_ids) == SIGNATURE_TIER_COUNT and len(set(ladder_ids)) == SIGNATURE_TIER_COUNT
        faction_ok = faction_ok and len(signature_ids) == SIGNATURE_TIER_COUNT and len(set(signature_ids)) == SIGNATURE_TIER_COUNT
        tiers = []
        for expected_tier, unit_id in enumerate(ladder_ids, start=1):
            unit = units.get(unit_id, {})
            building = buildings.get(signature_ids[expected_tier - 1], {}) if expected_tier - 1 < len(signature_ids) else {}
            unit_tier = int(unit.get("tier", 0))
            unlock_id = str(building.get("unlock_unit_id", ""))
            tiers.append({"unit_id": unit_id, "unit_tier": unit_tier, "building_id": signature_ids[expected_tier - 1] if expected_tier - 1 < len(signature_ids) else "", "unlock_id": unlock_id})
            if unit_tier != expected_tier or unlock_id != unit_id:
                faction_ok = False
        if not faction_ok:
            seven_tier_ok = False
        tier_rows[faction_id] = tiers
    add_check(
        checks,
        "seven_tier_unit_buildings",
        seven_tier_ok,
        "Every faction must have seven unit tiers and seven matching unit-unlocking town buildings.",
        {"signature_tier_count": SIGNATURE_TIER_COUNT, "factions": tier_rows},
    )

    runtime_reports: dict[str, Any] = {}
    if args.include_runtime:
        runtime_reports = add_runtime_checks(checks)

    passed = [check for check in checks if check["ok"]]
    failed = [check for check in checks if not check["ok"]]
    report = {
        "schema": REPORT_SCHEMA,
        "slice_id": SLICE_ID,
        "ok": not failed,
        "requirement_count": len(checks),
        "passed_requirement_count": len(passed),
        "failed_requirement_count": len(failed),
        "checks": checks,
        "errors": [str(check["id"]) for check in failed],
        "source_reports": {
            "town_development_balance_report_v1": {
                "authored_town_count": int(balance.get("authored_town_count", 0)),
                "completion_day_min": min(completion_days) if completion_days else 0,
                "completion_day_max": max(completion_days) if completion_days else 0,
            },
            "town_development_cost_curve_report_v1": {
                "authored_town_count": int(cost_curve.get("authored_town_count", 0)),
                "faction_count": int(cost_curve.get("faction_count", 0)),
            },
            "active_scenario_resource_availability_matrix_v1": {
                "active_scenario_count": int(source_matrix.get("active_scenario_count", 0)),
                "player_town_case_count": int(source_matrix.get("player_town_case_count", 0)),
                "enemy_town_case_count": int(source_matrix.get("enemy_town_case_count", 0)),
            },
            "faction_town_unit_asymmetry_report": {
                "unique_fingerprints": asymmetry.get("unique_fingerprints", {}),
            },
        },
        "runtime_reports_included": bool(args.include_runtime),
        "runtime_reports": runtime_reports,
    }
    print("ECONOMY_TOWN_GOAL_SCORECARD_REPORT " + json.dumps(report, sort_keys=True))
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
