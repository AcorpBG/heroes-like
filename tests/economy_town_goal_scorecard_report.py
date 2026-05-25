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
MIN_DETERMINISTIC_COMPLETION_DAY = 24
MIN_AUTHORED_TOWNS = 15
MIN_FACTIONS = 6
MIN_CAMPAIGN_SCENARIOS = 15
MIN_SKIRMISH_SCENARIOS = 16
MIN_CAMPAIGN_PLAYER_TOWN_CASES = 17
MIN_SKIRMISH_PLAYER_TOWN_CASES = 18
MIN_CAMPAIGN_ENEMY_TOWN_CASES = 19
MIN_SKIRMISH_ENEMY_TOWN_CASES = 20
EXPECTED_FACTION_IDS = {
    "faction_brasshollow",
    "faction_embercourt",
    "faction_mireclaw",
    "faction_sunvault",
    "faction_thornwake",
    "faction_veilmourn",
}
SIGNATURE_TIER_COUNT = 7
HIGH_TIER_START = 5
MIN_UNIQUE_NON_UNIT_PER_FACTION = 5
MIN_UNIQUE_NON_UNIT_PER_TOWN = 5
MIN_RARE_DEVELOPMENT_SPEND = 24
MAX_ENDING_RARE_AFTER_COMPLETION = 13
MIN_COMMON_ONLY_TO_RARE_RATIO = 2.0
MIN_COMMON_MATERIAL_BOTTLENECK_DAYS_PER_TOWN = 1
MAX_ENDING_COMMON_AFTER_COMPLETION = {"gold": 10000, "wood": 12, "ore": 12}
MAX_ENDING_COMMON_SURPLUS_RATIO_AFTER_COMPLETION = {"gold": 0.30, "wood": 0.50, "ore": 0.50}
MIN_RARE_UPGRADE_BUILDINGS_PER_TOWN = 1
EXPECTED_SIGNATURE_RARE_CURVE = {5: 4, 6: 8, 7: 10}
MIN_HIGH_TIER_UNIT_BUILD_DAYS = {5: 4, 6: 12, 7: 22}
PHASE_WINDOWS = {
    "early": {"start": 1, "end": 10, "min_builds": 8},
    "mid": {"start": 11, "end": 20, "min_builds": 6},
    "late": {"start": 21, "end": 30, "min_builds": 2},
}
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
BALANCE_REGRESSION_RULES_PATH = ROOT / "scripts" / "core" / "BalanceRegressionReportRules.gd"
HEADLESS_SIMULATION_RULES_PATH = ROOT / "scripts" / "core" / "HeadlessSimulationHarnessRules.gd"
BALANCE_REGRESSION_REPORT_TEST_PATH = ROOT / "tests" / "balance_regression_report_suite.gd"
HEADLESS_SIMULATION_REPORT_TEST_PATH = ROOT / "tests" / "headless_simulation_harness_report.gd"
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
        "scene": "res://tests/active_scenario_town_economy_source_route_report.tscn",
        "marker": "ACTIVE_SCENARIO_TOWN_ECONOMY_SOURCE_ROUTE_REPORT",
        "quit_after": 300,
        "log_file": "/tmp/heroes-like-scorecard-active-source-route.log",
    },
    {
        "scene": "res://tests/native_random_map_package_session_adoption_report.tscn",
        "marker": "NATIVE_RANDOM_MAP_PACKAGE_SESSION_ADOPTION_REPORT",
        "quit_after": 300,
        "log_file": "/tmp/heroes-like-scorecard-generated-package-town-economy.log",
    },
    {
        "scene": "res://tests/active_scenario_ai_town_development_runway_report.tscn",
        "marker": "ACTIVE_SCENARIO_AI_TOWN_DEVELOPMENT_RUNWAY_REPORT",
        "quit_after": 700,
        "log_file": "/tmp/heroes-like-scorecard-active-ai-town.log",
    },
    {
        "scene": "res://tests/town_unique_building_runtime_payoff_report.tscn",
        "marker": "TOWN_UNIQUE_BUILDING_RUNTIME_PAYOFF_REPORT",
        "quit_after": 300,
        "log_file": "/tmp/heroes-like-scorecard-unique-town-payoff.log",
    },
    {
        "scene": "res://tests/town_economy_resource_ui_surface_report.tscn",
        "marker": "TOWN_ECONOMY_RESOURCE_UI_SURFACE_REPORT",
        "quit_after": 300,
        "log_file": "/tmp/heroes-like-scorecard-town-resource-ui.log",
    },
    {
        "scene": "res://tests/town_recruitment_ui_surface_report.tscn",
        "marker": "TOWN_RECRUITMENT_UI_SURFACE_REPORT",
        "quit_after": 300,
        "log_file": "/tmp/heroes-like-scorecard-town-recruitment-ui.log",
    },
    {
        "scene": "res://tests/runtime_market_cap_persistence_report.tscn",
        "marker": "RUNTIME_MARKET_CAP_PERSISTENCE_REPORT",
        "quit_after": 300,
        "log_file": "/tmp/heroes-like-scorecard-market-cap.log",
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


def market_action(snapshot: dict[str, Any], action_id: str) -> dict[str, Any]:
    actions = snapshot.get("actions", [])
    if not isinstance(actions, list):
        return {}
    for action in actions:
        if isinstance(action, dict) and str(action.get("id", "")) == action_id:
            return action
    return {}


def source_contract_row(path: Path, required_tokens: tuple[str, ...], require_resource_literals: bool = False) -> dict[str, Any]:
    text = path.read_text(encoding="utf-8") if path.exists() else ""
    missing_resources = sorted(resource_id for resource_id in LIVE_RESOURCES if require_resource_literals and f'"{resource_id}"' not in text)
    missing_tokens = [token for token in required_tokens if token not in text]
    common_only_regression = 'const LIVE_RESOURCE_IDS := ["gold", "wood", "ore"]' in text
    return {
        "path": str(path.relative_to(ROOT)),
        "exists": path.exists(),
        "missing_resource_ids": missing_resources,
        "missing_tokens": missing_tokens,
        "common_only_regression": common_only_regression,
        "ok": path.exists() and not missing_resources and not missing_tokens and not common_only_regression,
    }


def balance_harness_resource_accounting_report() -> dict[str, Any]:
    rows = [
        source_contract_row(
            BALANCE_REGRESSION_RULES_PATH,
            (
                "const LIVE_RESOURCE_IDS",
                "_economy_pressure_resource_viability",
                "live_resource_ids",
                "live_resource_count",
                "visible_live_resource_support",
                "missing_live_resource_support",
            ),
            True,
        ),
        source_contract_row(
            HEADLESS_SIMULATION_RULES_PATH,
            (
                "const LIVE_RESOURCE_IDS",
                "_economy_resource_delta",
                "live_resource_ids",
                "live_resource_count",
                "before_resources",
                "after_resources",
            ),
            True,
        ),
        source_contract_row(
            BALANCE_REGRESSION_REPORT_TEST_PATH,
            (
                "_assert_balance_economy_resource_coverage",
                "BalanceRegressionReportRulesScript.LIVE_RESOURCE_IDS",
                "live_resource_count",
                "visible_live_resource_support",
            ),
        ),
        source_contract_row(
            HEADLESS_SIMULATION_REPORT_TEST_PATH,
            (
                "_assert_economy_resource_delta",
                "HeadlessSimulationHarnessRulesScript.LIVE_RESOURCE_IDS",
                "live_resource_count",
                "before_resources",
                "after_resources",
            ),
        ),
    ]
    return {
        "schema": "balance_harness_resource_accounting_v1",
        "live_resource_ids": sorted(LIVE_RESOURCES),
        "file_count": len(rows),
        "passing_file_count": sum(1 for row in rows if row["ok"]),
        "rows": rows,
        "ok": all(row["ok"] for row in rows),
    }


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
        and int(player_runtime.get("campaign_scenario_count", 0)) >= MIN_CAMPAIGN_SCENARIOS
        and int(player_runtime.get("skirmish_scenario_count", 0)) >= MIN_SKIRMISH_SCENARIOS
        and int(player_runtime.get("player_town_case_count", 0)) >= 18
        and int(player_runtime.get("campaign_player_town_case_count", 0)) >= MIN_CAMPAIGN_PLAYER_TOWN_CASES
        and int(player_runtime.get("skirmish_player_town_case_count", 0)) >= MIN_SKIRMISH_PLAYER_TOWN_CASES
        and int(player_runtime.get("completed_case_count", 0)) == int(player_runtime.get("player_town_case_count", -1))
        and int(player_runtime.get("campaign_completed_case_count", 0)) == int(player_runtime.get("campaign_player_town_case_count", -1))
        and int(player_runtime.get("skirmish_completed_case_count", 0)) == int(player_runtime.get("skirmish_player_town_case_count", -1))
        and int(player_runtime.get("min_completion_day", 0)) >= MIN_DETERMINISTIC_COMPLETION_DAY
        and int(player_runtime.get("completion_day_min", 0)) >= MIN_DETERMINISTIC_COMPLETION_DAY
        and int(player_runtime.get("completion_day_max", 999)) <= TARGET_TURNS
        and int(player_runtime.get("pacing_floor_case_count", 0)) == int(player_runtime.get("player_town_case_count", -1))
        and int(player_runtime.get("campaign_pacing_floor_case_count", 0)) == int(player_runtime.get("campaign_player_town_case_count", -1))
        and int(player_runtime.get("skirmish_pacing_floor_case_count", 0)) == int(player_runtime.get("skirmish_player_town_case_count", -1))
        and int(player_runtime.get("source_adoption_policy_case_count", 0)) == int(player_runtime.get("player_town_case_count", -1))
        and int(player_runtime.get("rare_spend_case_count", 0)) == int(player_runtime.get("player_town_case_count", -1))
        and int(player_runtime.get("full_session_case_count", 0)) == int(player_runtime.get("player_town_case_count", -1))
        and int(player_runtime.get("delayed_source_replay_case_count", 0)) == int(player_runtime.get("player_town_case_count", -1))
        and int(player_runtime.get("delayed_source_replay_completed_count", 0)) == int(player_runtime.get("player_town_case_count", -1))
        and int(player_runtime.get("delayed_source_save_resume_case_count", 0)) == int(player_runtime.get("player_town_case_count", -1))
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
            "campaign_scenario_count": int(player_runtime.get("campaign_scenario_count", 0)),
            "skirmish_scenario_count": int(player_runtime.get("skirmish_scenario_count", 0)),
            "player_town_case_count": int(player_runtime.get("player_town_case_count", 0)),
            "campaign_player_town_case_count": int(player_runtime.get("campaign_player_town_case_count", 0)),
            "skirmish_player_town_case_count": int(player_runtime.get("skirmish_player_town_case_count", 0)),
            "completed_case_count": int(player_runtime.get("completed_case_count", 0)),
            "campaign_completed_case_count": int(player_runtime.get("campaign_completed_case_count", 0)),
            "skirmish_completed_case_count": int(player_runtime.get("skirmish_completed_case_count", 0)),
            "min_completion_day": int(player_runtime.get("min_completion_day", 0)),
            "completion_day_min": int(player_runtime.get("completion_day_min", 0)),
            "completion_day_max": int(player_runtime.get("completion_day_max", 0)),
            "pacing_floor_case_count": int(player_runtime.get("pacing_floor_case_count", 0)),
            "campaign_pacing_floor_case_count": int(player_runtime.get("campaign_pacing_floor_case_count", 0)),
            "skirmish_pacing_floor_case_count": int(player_runtime.get("skirmish_pacing_floor_case_count", 0)),
            "source_adoption_policy_case_count": int(player_runtime.get("source_adoption_policy_case_count", 0)),
            "rare_spend_case_count": int(player_runtime.get("rare_spend_case_count", 0)),
            "full_session_case_count": int(player_runtime.get("full_session_case_count", 0)),
            "delayed_source_replay_case_count": int(player_runtime.get("delayed_source_replay_case_count", 0)),
            "delayed_source_replay_completed_count": int(player_runtime.get("delayed_source_replay_completed_count", 0)),
            "delayed_source_save_resume_case_count": int(player_runtime.get("delayed_source_save_resume_case_count", 0)),
            "delayed_source_save_resume_completed_count": int(player_runtime.get("delayed_source_save_resume_completed_count", 0)),
            "recruited_unit_case_count": int(player_runtime.get("recruited_unit_case_count", 0)),
        },
    )
    source_route_runtime = payloads["ACTIVE_SCENARIO_TOWN_ECONOMY_SOURCE_ROUTE_REPORT"]
    source_route_runtime_ok = (
        source_route_runtime.get("ok") is True
        and source_route_runtime.get("schema") == "active_scenario_town_economy_source_route_report_v1"
        and int(source_route_runtime.get("active_scenario_count", 0)) >= 16
        and int(source_route_runtime.get("campaign_scenario_count", 0)) >= MIN_CAMPAIGN_SCENARIOS
        and int(source_route_runtime.get("skirmish_scenario_count", 0)) >= MIN_SKIRMISH_SCENARIOS
        and int(source_route_runtime.get("player_town_case_count", 0)) >= 18
        and int(source_route_runtime.get("campaign_player_town_case_count", 0)) >= MIN_CAMPAIGN_PLAYER_TOWN_CASES
        and int(source_route_runtime.get("skirmish_player_town_case_count", 0)) >= MIN_SKIRMISH_PLAYER_TOWN_CASES
        and int(source_route_runtime.get("resource_route_case_count", 0)) == int(source_route_runtime.get("player_town_case_count", -1)) * 3
        and int(source_route_runtime.get("reachable_route_case_count", 0)) == int(source_route_runtime.get("resource_route_case_count", -1))
        and int(source_route_runtime.get("max_common_route_steps", 999)) <= 24
        and int(source_route_runtime.get("max_rare_route_steps", 999)) <= 40
        and set(str(value) for value in source_route_runtime.get("required_common_resource_ids", [])) == {"wood", "ore"}
        and set(str(value) for value in source_route_runtime.get("rare_resource_ids", [])) == RARE_RESOURCES
    )
    add_check(
        checks,
        "active_scenario_source_route_runtime",
        source_route_runtime_ok,
        "Active player-town scenarios must expose reachable wood, ore, and faction-rare source routes through live overworld route rules.",
        {
            "schema": str(source_route_runtime.get("schema", "")),
            "active_scenario_count": int(source_route_runtime.get("active_scenario_count", 0)),
            "campaign_scenario_count": int(source_route_runtime.get("campaign_scenario_count", 0)),
            "skirmish_scenario_count": int(source_route_runtime.get("skirmish_scenario_count", 0)),
            "player_town_case_count": int(source_route_runtime.get("player_town_case_count", 0)),
            "campaign_player_town_case_count": int(source_route_runtime.get("campaign_player_town_case_count", 0)),
            "skirmish_player_town_case_count": int(source_route_runtime.get("skirmish_player_town_case_count", 0)),
            "resource_route_case_count": int(source_route_runtime.get("resource_route_case_count", 0)),
            "reachable_route_case_count": int(source_route_runtime.get("reachable_route_case_count", 0)),
            "required_common_resource_ids": sorted(str(value) for value in source_route_runtime.get("required_common_resource_ids", [])),
            "rare_resource_ids": sorted(str(value) for value in source_route_runtime.get("rare_resource_ids", [])),
            "max_common_route_steps": int(source_route_runtime.get("max_common_route_steps", 0)),
            "max_rare_route_steps": int(source_route_runtime.get("max_rare_route_steps", 0)),
        },
    )
    enemy_source_route_runtime_ok = (
        source_route_runtime.get("ok") is True
        and source_route_runtime.get("schema") == "active_scenario_town_economy_source_route_report_v1"
        and int(source_route_runtime.get("active_scenario_count", 0)) >= 16
        and int(source_route_runtime.get("campaign_scenario_count", 0)) >= MIN_CAMPAIGN_SCENARIOS
        and int(source_route_runtime.get("skirmish_scenario_count", 0)) >= MIN_SKIRMISH_SCENARIOS
        and int(source_route_runtime.get("enemy_town_case_count", 0)) >= 20
        and int(source_route_runtime.get("campaign_enemy_town_case_count", 0)) >= MIN_CAMPAIGN_ENEMY_TOWN_CASES
        and int(source_route_runtime.get("skirmish_enemy_town_case_count", 0)) >= MIN_SKIRMISH_ENEMY_TOWN_CASES
        and int(source_route_runtime.get("enemy_resource_route_case_count", 0)) == int(source_route_runtime.get("enemy_town_case_count", -1)) * 3
        and int(source_route_runtime.get("enemy_reachable_route_case_count", 0)) == int(source_route_runtime.get("enemy_resource_route_case_count", -1))
        and int(source_route_runtime.get("max_common_route_steps", 999)) <= 24
        and int(source_route_runtime.get("max_rare_route_steps", 999)) <= 40
        and set(str(value) for value in source_route_runtime.get("required_common_resource_ids", [])) == {"wood", "ore"}
        and set(str(value) for value in source_route_runtime.get("rare_resource_ids", [])) == RARE_RESOURCES
    )
    add_check(
        checks,
        "active_scenario_enemy_source_route_runtime",
        enemy_source_route_runtime_ok,
        "Active enemy-town scenarios must expose reachable wood, ore, and faction-rare source routes through live overworld route rules.",
        {
            "schema": str(source_route_runtime.get("schema", "")),
            "active_scenario_count": int(source_route_runtime.get("active_scenario_count", 0)),
            "campaign_scenario_count": int(source_route_runtime.get("campaign_scenario_count", 0)),
            "skirmish_scenario_count": int(source_route_runtime.get("skirmish_scenario_count", 0)),
            "enemy_town_case_count": int(source_route_runtime.get("enemy_town_case_count", 0)),
            "campaign_enemy_town_case_count": int(source_route_runtime.get("campaign_enemy_town_case_count", 0)),
            "skirmish_enemy_town_case_count": int(source_route_runtime.get("skirmish_enemy_town_case_count", 0)),
            "enemy_resource_route_case_count": int(source_route_runtime.get("enemy_resource_route_case_count", 0)),
            "enemy_reachable_route_case_count": int(source_route_runtime.get("enemy_reachable_route_case_count", 0)),
            "required_common_resource_ids": sorted(str(value) for value in source_route_runtime.get("required_common_resource_ids", [])),
            "rare_resource_ids": sorted(str(value) for value in source_route_runtime.get("rare_resource_ids", [])),
            "max_common_route_steps": int(source_route_runtime.get("max_common_route_steps", 0)),
            "max_rare_route_steps": int(source_route_runtime.get("max_rare_route_steps", 0)),
        },
    )

    generated_package_runtime = payloads["NATIVE_RANDOM_MAP_PACKAGE_SESSION_ADOPTION_REPORT"]
    generated_surface = generated_package_runtime.get("generated_town_economy_surface", {})
    generated_runway = generated_package_runtime.get("generated_player_town_development_runway", {})
    generated_enemy_runway = generated_package_runtime.get("generated_enemy_town_development_runway", {})
    generated_resource_source_ids = {str(value) for value in generated_surface.get("generated_resource_source_ids", [])}
    generated_player_required_ids = {str(value) for value in generated_surface.get("player_required_resource_ids", [])}
    generated_faction_ids = {str(value) for value in generated_surface.get("generated_faction_ids", [])}
    generated_town_ids = {str(value) for value in generated_surface.get("generated_town_ids", [])}
    generated_package_town_economy_ok = (
        generated_package_runtime.get("ok") is True
        and generated_package_runtime.get("schema_id") == "native_random_map_package_session_adoption_smoke_v1"
        and generated_package_runtime.get("active_disk_package_startup_ok") is True
        and generated_surface.get("schema") == "generated_package_town_economy_surface_v1"
        and generated_surface.get("status") == "pass"
        and generated_surface.get("package_session_scope") == "strict_small_36x36_one_level_land_only"
        and int(generated_surface.get("town_count", 0)) >= 3
        and int(generated_surface.get("player_town_count", 0)) >= 1
        and int(generated_surface.get("authored_town_template_count", 0)) == int(generated_surface.get("town_count", -1))
        and int(generated_surface.get("seven_tier_town_count", 0)) == int(generated_surface.get("town_count", -1))
        and int(generated_surface.get("rare_development_town_count", 0)) == int(generated_surface.get("town_count", -1))
        and int(generated_surface.get("unique_faction_count", 0)) >= 3
        and int(generated_surface.get("unique_town_template_count", 0)) >= 3
        and int(generated_surface.get("generated_resource_node_count", 0)) > 0
        and COMMON_RESOURCES.issubset(generated_resource_source_ids)
        and generated_player_required_ids.issubset(generated_resource_source_ids)
        and not generated_surface.get("missing_player_resource_sources", [])
    )
    add_check(
        checks,
        "generated_package_town_economy_runtime",
        generated_package_town_economy_ok,
        "Generated/native package sessions must expose authored town templates, seven-tier town ladders, rare-resource development identity, and live common plus player-faction rare resource sources.",
        {
            "schema": str(generated_surface.get("schema", "")),
            "package_session_scope": str(generated_surface.get("package_session_scope", "")),
            "town_count": int(generated_surface.get("town_count", 0)),
            "player_town_count": int(generated_surface.get("player_town_count", 0)),
            "authored_town_template_count": int(generated_surface.get("authored_town_template_count", 0)),
            "seven_tier_town_count": int(generated_surface.get("seven_tier_town_count", 0)),
            "rare_development_town_count": int(generated_surface.get("rare_development_town_count", 0)),
            "unique_faction_count": int(generated_surface.get("unique_faction_count", 0)),
            "unique_town_template_count": int(generated_surface.get("unique_town_template_count", 0)),
            "generated_faction_ids": sorted(generated_faction_ids),
            "generated_town_ids": sorted(generated_town_ids),
            "source_h3maped_faction_ids": sorted(str(value) for value in generated_surface.get("source_h3maped_faction_ids", [])),
            "generated_resource_node_count": int(generated_surface.get("generated_resource_node_count", 0)),
            "generated_resource_source_ids": sorted(generated_resource_source_ids),
            "player_required_resource_ids": sorted(generated_player_required_ids),
            "missing_player_resource_sources": [str(value) for value in generated_surface.get("missing_player_resource_sources", [])],
        },
    )
    generated_package_player_runway_ok = (
        generated_package_runtime.get("ok") is True
        and generated_runway.get("schema") == "generated_package_player_town_development_runway_v1"
        and generated_runway.get("status") == "pass"
        and generated_runway.get("package_session_scope") == "strict_small_36x36_one_level_land_only"
        and generated_runway.get("completed") is True
        and int(generated_runway.get("completion_day", 0)) >= MIN_DETERMINISTIC_COMPLETION_DAY
        and int(generated_runway.get("completion_day", 999)) <= TARGET_TURNS
        and int(generated_runway.get("min_completion_day", 0)) >= MIN_DETERMINISTIC_COMPLETION_DAY
        and generated_runway.get("pacing_floor_ok") is True
        and int(generated_runway.get("build_count", 0)) == int(generated_runway.get("initial_missing_building_count", -1))
        and generated_runway.get("same_day_reject_ok") is True
        and generated_runway.get("build_actions_after_build_blocked") is True
        and generated_runway.get("rare_spend_observed") is True
        and generated_runway.get("market_common_only") is True
        and generated_runway.get("source_evidence", {}).get("source_adoption_policy", "") == "minimal_required_resource_coverage"
        and int(generated_runway.get("focused_economy_day_advance_count", 0)) > 0
        and generated_runway.get("recruitment_end_to_end_ok") is True
        and int(generated_runway.get("recruited_unit_case_count", 0)) == SIGNATURE_TIER_COUNT
        and not generated_runway.get("missing_buildings", [])
    )
    add_check(
        checks,
        "generated_package_player_town_runway_runtime",
        generated_package_player_runway_ok,
        "Generated/native package sessions must run the player town through live 30-turn development, rare spend, one-build-per-day guard, and seven-tier recruitment.",
        {
            "schema": str(generated_runway.get("schema", "")),
            "package_session_scope": str(generated_runway.get("package_session_scope", "")),
            "town_id": str(generated_runway.get("town_id", "")),
            "faction_id": str(generated_runway.get("faction_id", "")),
            "completed": generated_runway.get("completed") is True,
            "completion_day": int(generated_runway.get("completion_day", 0)),
            "min_completion_day": int(generated_runway.get("min_completion_day", 0)),
            "pacing_floor_ok": generated_runway.get("pacing_floor_ok") is True,
            "build_count": int(generated_runway.get("build_count", 0)),
            "target_building_count": int(generated_runway.get("target_building_count", 0)),
            "initial_missing_building_count": int(generated_runway.get("initial_missing_building_count", 0)),
            "same_day_reject_ok": generated_runway.get("same_day_reject_ok") is True,
            "build_actions_after_build_blocked": generated_runway.get("build_actions_after_build_blocked") is True,
            "rare_spend_observed": generated_runway.get("rare_spend_observed") is True,
            "recruitment_end_to_end_ok": generated_runway.get("recruitment_end_to_end_ok") is True,
            "recruited_unit_case_count": int(generated_runway.get("recruited_unit_case_count", 0)),
            "source_adoption_policy": str(generated_runway.get("source_evidence", {}).get("source_adoption_policy", ""))
            if isinstance(generated_runway.get("source_evidence", {}), dict)
            else "",
            "secured_source_count": int(generated_runway.get("source_evidence", {}).get("secured_source_count", 0))
            if isinstance(generated_runway.get("source_evidence", {}), dict)
            else 0,
            "secured_resource_ids": sorted(
                str(value)
                for value in generated_runway.get("source_evidence", {}).get("secured_resource_ids", [])
            )
            if isinstance(generated_runway.get("source_evidence", {}), dict)
            else [],
        },
    )
    generated_enemy_case_count = int(generated_enemy_runway.get("enemy_town_case_count", 0))
    generated_package_enemy_runway_ok = (
        generated_package_runtime.get("ok") is True
        and generated_package_runtime.get("schema_id") == "native_random_map_package_session_adoption_smoke_v1"
        and generated_package_runtime.get("active_disk_package_startup_ok") is True
        and generated_enemy_runway.get("schema") == "generated_package_enemy_town_development_runway_v1"
        and generated_enemy_runway.get("status") == "pass"
        and generated_enemy_runway.get("package_session_scope") == "strict_small_36x36_one_level_land_only"
        and generated_enemy_case_count >= 2
        and int(generated_enemy_runway.get("completed_case_count", 0)) == generated_enemy_case_count
        and int(generated_enemy_runway.get("min_completion_day", 0)) >= MIN_DETERMINISTIC_COMPLETION_DAY
        and int(generated_enemy_runway.get("completion_day_min", 0)) >= MIN_DETERMINISTIC_COMPLETION_DAY
        and int(generated_enemy_runway.get("completion_day_max", 999)) <= TARGET_TURNS
        and int(generated_enemy_runway.get("pacing_floor_case_count", 0)) == generated_enemy_case_count
        and int(generated_enemy_runway.get("rare_spend_case_count", 0)) == generated_enemy_case_count
        and int(generated_enemy_runway.get("same_day_guard_case_count", 0)) == generated_enemy_case_count
        and int(generated_enemy_runway.get("rare_treasury_tracked_case_count", 0)) == generated_enemy_case_count
        and int(generated_enemy_runway.get("governor_report_case_count", 0)) == generated_enemy_case_count
        and int(generated_enemy_runway.get("source_covered_case_count", 0)) == generated_enemy_case_count
        and int(generated_enemy_runway.get("source_adoption_policy_case_count", 0)) == generated_enemy_case_count
        and int(generated_enemy_runway.get("full_session_case_count", 0)) == generated_enemy_case_count
        and int(generated_enemy_runway.get("seven_tier_recruitment_case_count", 0)) == generated_enemy_case_count
        and int(generated_enemy_runway.get("selected_recruitment_case_count", 0)) == generated_enemy_case_count
        and int(generated_enemy_runway.get("build_count_total", 0)) >= generated_enemy_case_count * 20
    )
    add_check(
        checks,
        "generated_package_enemy_town_runway_runtime",
        generated_package_enemy_runway_ok,
        "Generated/native package sessions must run enemy towns through live AI development inside the day-24-to-day-30 pacing window, rare spend, one-build-per-day guards, full treasury tracking, source coverage, and seven-tier recruitment selection.",
        {
            "schema": str(generated_enemy_runway.get("schema", "")),
            "package_session_scope": str(generated_enemy_runway.get("package_session_scope", "")),
            "enemy_town_case_count": generated_enemy_case_count,
            "completed_case_count": int(generated_enemy_runway.get("completed_case_count", 0)),
            "min_completion_day": int(generated_enemy_runway.get("min_completion_day", 0)),
            "completion_day_min": int(generated_enemy_runway.get("completion_day_min", 0)),
            "completion_day_max": int(generated_enemy_runway.get("completion_day_max", 0)),
            "pacing_floor_case_count": int(generated_enemy_runway.get("pacing_floor_case_count", 0)),
            "rare_spend_case_count": int(generated_enemy_runway.get("rare_spend_case_count", 0)),
            "same_day_guard_case_count": int(generated_enemy_runway.get("same_day_guard_case_count", 0)),
            "rare_treasury_tracked_case_count": int(generated_enemy_runway.get("rare_treasury_tracked_case_count", 0)),
            "governor_report_case_count": int(generated_enemy_runway.get("governor_report_case_count", 0)),
            "source_covered_case_count": int(generated_enemy_runway.get("source_covered_case_count", 0)),
            "source_adoption_policy_case_count": int(generated_enemy_runway.get("source_adoption_policy_case_count", 0)),
            "full_session_case_count": int(generated_enemy_runway.get("full_session_case_count", 0)),
            "seven_tier_recruitment_case_count": int(generated_enemy_runway.get("seven_tier_recruitment_case_count", 0)),
            "selected_recruitment_case_count": int(generated_enemy_runway.get("selected_recruitment_case_count", 0)),
            "build_count_total": int(generated_enemy_runway.get("build_count_total", 0)),
            "secured_source_count_total": int(generated_enemy_runway.get("secured_source_count_total", 0)),
        },
    )

    runtime_recruitment_market_coverage_ok = (
        town_runtime.get("ok") is True
        and player_runtime.get("ok") is True
        and int(town_runtime.get("recruitment_market_covered_town_count", 0)) > 0
        and int(town_runtime.get("recruitment_market_purchase_count", 0)) > 0
        and int(town_runtime.get("recruitment_market_reset_wait_count", 0)) > 0
        and "recruitment_market_covered_case_count" in player_runtime
        and "recruitment_market_purchase_count" in player_runtime
        and "recruitment_market_reset_wait_count" in player_runtime
    )
    add_check(
        checks,
        "runtime_recruitment_market_coverage",
        runtime_recruitment_market_coverage_ok,
        "Live recruitment after town development must prove common-only market coverage can recover from wood/ore shortfalls.",
        {
            "town_runtime_market_covered_town_count": int(town_runtime.get("recruitment_market_covered_town_count", 0)),
            "town_runtime_market_purchase_count": int(town_runtime.get("recruitment_market_purchase_count", 0)),
            "town_runtime_market_reset_wait_count": int(town_runtime.get("recruitment_market_reset_wait_count", 0)),
            "active_player_market_covered_case_count": int(player_runtime.get("recruitment_market_covered_case_count", 0)),
            "active_player_market_purchase_count": int(player_runtime.get("recruitment_market_purchase_count", 0)),
            "active_player_market_reset_wait_count": int(player_runtime.get("recruitment_market_reset_wait_count", 0)),
            "normal_market_resource_ids": player_runtime.get("common_market_resource_ids", []),
        },
    )

    ai_runtime = payloads["ACTIVE_SCENARIO_AI_TOWN_DEVELOPMENT_RUNWAY_REPORT"]
    ai_runtime_ok = (
        ai_runtime.get("ok") is True
        and int(ai_runtime.get("active_scenario_count", 0)) >= 16
        and int(ai_runtime.get("campaign_scenario_count", 0)) >= MIN_CAMPAIGN_SCENARIOS
        and int(ai_runtime.get("skirmish_scenario_count", 0)) >= MIN_SKIRMISH_SCENARIOS
        and int(ai_runtime.get("enemy_town_case_count", 0)) >= 20
        and int(ai_runtime.get("campaign_enemy_town_case_count", 0)) >= MIN_CAMPAIGN_ENEMY_TOWN_CASES
        and int(ai_runtime.get("skirmish_enemy_town_case_count", 0)) >= MIN_SKIRMISH_ENEMY_TOWN_CASES
        and int(ai_runtime.get("completed_case_count", 0)) == int(ai_runtime.get("enemy_town_case_count", -1))
        and int(ai_runtime.get("campaign_completed_case_count", 0)) == int(ai_runtime.get("campaign_enemy_town_case_count", -1))
        and int(ai_runtime.get("skirmish_completed_case_count", 0)) == int(ai_runtime.get("skirmish_enemy_town_case_count", -1))
        and int(ai_runtime.get("min_completion_day", 0)) >= MIN_DETERMINISTIC_COMPLETION_DAY
        and int(ai_runtime.get("completion_day_min", 0)) >= MIN_DETERMINISTIC_COMPLETION_DAY
        and int(ai_runtime.get("completion_day_max", 999)) <= TARGET_TURNS
        and int(ai_runtime.get("pacing_floor_case_count", 0)) == int(ai_runtime.get("enemy_town_case_count", -1))
        and int(ai_runtime.get("campaign_pacing_floor_case_count", 0)) == int(ai_runtime.get("campaign_enemy_town_case_count", -1))
        and int(ai_runtime.get("skirmish_pacing_floor_case_count", 0)) == int(ai_runtime.get("skirmish_enemy_town_case_count", -1))
        and int(ai_runtime.get("source_adoption_policy_case_count", 0)) == int(ai_runtime.get("enemy_town_case_count", -1))
        and int(ai_runtime.get("rare_spend_case_count", 0)) == int(ai_runtime.get("enemy_town_case_count", -1))
        and int(ai_runtime.get("same_day_guard_case_count", 0)) == int(ai_runtime.get("enemy_town_case_count", -1))
        and int(ai_runtime.get("full_session_case_count", 0)) == int(ai_runtime.get("enemy_town_case_count", -1))
        and int(ai_runtime.get("delayed_source_replay_case_count", 0)) == int(ai_runtime.get("enemy_town_case_count", -1))
        and int(ai_runtime.get("delayed_source_replay_completed_count", 0)) == int(ai_runtime.get("enemy_town_case_count", -1))
        and int(ai_runtime.get("delayed_source_save_resume_case_count", 0)) == int(ai_runtime.get("enemy_town_case_count", -1))
        and int(ai_runtime.get("delayed_source_save_resume_completed_count", 0)) == int(ai_runtime.get("enemy_town_case_count", -1))
        and int(ai_runtime.get("seven_tier_recruitment_case_count", 0)) == int(ai_runtime.get("enemy_town_case_count", -1))
        and int(ai_runtime.get("seven_tier_recruitment_candidate_count", 0)) >= int(ai_runtime.get("enemy_town_case_count", 0)) * SIGNATURE_TIER_COUNT
        and int(ai_runtime.get("affordable_recruitment_case_count", 0)) == int(ai_runtime.get("enemy_town_case_count", -1))
    )
    add_check(
        checks,
        "active_scenario_ai_runway_runtime",
        ai_runtime_ok,
        "Active enemy-town scenarios must complete AI town development, delayed-source replay, save/resume, and same-day build guards.",
        {
            "active_scenario_count": int(ai_runtime.get("active_scenario_count", 0)),
            "campaign_scenario_count": int(ai_runtime.get("campaign_scenario_count", 0)),
            "skirmish_scenario_count": int(ai_runtime.get("skirmish_scenario_count", 0)),
            "enemy_town_case_count": int(ai_runtime.get("enemy_town_case_count", 0)),
            "campaign_enemy_town_case_count": int(ai_runtime.get("campaign_enemy_town_case_count", 0)),
            "skirmish_enemy_town_case_count": int(ai_runtime.get("skirmish_enemy_town_case_count", 0)),
            "completed_case_count": int(ai_runtime.get("completed_case_count", 0)),
            "campaign_completed_case_count": int(ai_runtime.get("campaign_completed_case_count", 0)),
            "skirmish_completed_case_count": int(ai_runtime.get("skirmish_completed_case_count", 0)),
            "min_completion_day": int(ai_runtime.get("min_completion_day", 0)),
            "completion_day_min": int(ai_runtime.get("completion_day_min", 0)),
            "completion_day_max": int(ai_runtime.get("completion_day_max", 0)),
            "pacing_floor_case_count": int(ai_runtime.get("pacing_floor_case_count", 0)),
            "campaign_pacing_floor_case_count": int(ai_runtime.get("campaign_pacing_floor_case_count", 0)),
            "skirmish_pacing_floor_case_count": int(ai_runtime.get("skirmish_pacing_floor_case_count", 0)),
            "source_adoption_policy_case_count": int(ai_runtime.get("source_adoption_policy_case_count", 0)),
            "rare_spend_case_count": int(ai_runtime.get("rare_spend_case_count", 0)),
            "same_day_guard_case_count": int(ai_runtime.get("same_day_guard_case_count", 0)),
            "full_session_case_count": int(ai_runtime.get("full_session_case_count", 0)),
            "delayed_source_replay_case_count": int(ai_runtime.get("delayed_source_replay_case_count", 0)),
            "delayed_source_replay_completed_count": int(ai_runtime.get("delayed_source_replay_completed_count", 0)),
            "delayed_source_save_resume_case_count": int(ai_runtime.get("delayed_source_save_resume_case_count", 0)),
            "delayed_source_save_resume_completed_count": int(ai_runtime.get("delayed_source_save_resume_completed_count", 0)),
            "seven_tier_recruitment_case_count": int(ai_runtime.get("seven_tier_recruitment_case_count", 0)),
            "seven_tier_recruitment_candidate_count": int(ai_runtime.get("seven_tier_recruitment_candidate_count", 0)),
            "affordable_recruitment_case_count": int(ai_runtime.get("affordable_recruitment_case_count", 0)),
        },
    )
    covered_ai_factions = {str(value) for value in ai_runtime.get("covered_faction_ids", [])}
    covered_ai_ladder_factions = {str(value) for value in ai_runtime.get("covered_ladder_faction_ids", [])}
    ai_six_faction_coverage_ok = (
        ai_runtime.get("ok") is True
        and int(ai_runtime.get("unique_faction_count", 0)) >= MIN_FACTIONS
        and int(ai_runtime.get("unique_ladder_faction_count", 0)) >= MIN_FACTIONS
        and EXPECTED_FACTION_IDS.issubset(covered_ai_factions)
        and EXPECTED_FACTION_IDS.issubset(covered_ai_ladder_factions)
    )
    add_check(
        checks,
        "active_ai_six_faction_town_coverage",
        ai_six_faction_coverage_ok,
        "Active enemy-town runtime evidence must cover all six controller and native town-ladder factions.",
        {
            "unique_faction_count": int(ai_runtime.get("unique_faction_count", 0)),
            "covered_faction_ids": sorted(covered_ai_factions),
            "unique_ladder_faction_count": int(ai_runtime.get("unique_ladder_faction_count", 0)),
            "covered_ladder_faction_ids": sorted(covered_ai_ladder_factions),
            "expected_faction_ids": sorted(EXPECTED_FACTION_IDS),
        },
    )

    unique_payoff_runtime = payloads["TOWN_UNIQUE_BUILDING_RUNTIME_PAYOFF_REPORT"]
    unique_faction_rows = unique_payoff_runtime.get("factions", [])
    unique_faction_rows = unique_faction_rows if isinstance(unique_faction_rows, list) else []
    min_payoff_domains_per_faction = int(unique_payoff_runtime.get("min_payoff_domains_per_faction", 0))
    min_payoff_domains_per_town = int(unique_payoff_runtime.get("min_payoff_domains_per_town", 0))
    unique_payoff_runtime_ok = (
        unique_payoff_runtime.get("ok") is True
        and int(unique_payoff_runtime.get("faction_count", 0)) >= MIN_FACTIONS
        and int(unique_payoff_runtime.get("town_case_count", 0)) >= MIN_AUTHORED_TOWNS
        and int(unique_payoff_runtime.get("building_case_count", 0)) >= MIN_AUTHORED_TOWNS * MIN_UNIQUE_NON_UNIT_PER_TOWN
        and int(unique_payoff_runtime.get("runtime_payoff_case_count", 0)) == int(unique_payoff_runtime.get("building_case_count", -1))
        and int(unique_payoff_runtime.get("rare_unique_case_count", 0)) >= MIN_FACTIONS
        and all(
            isinstance(row, dict)
            and bool(row.get("ok", False))
            and int(row.get("payoff_domain_count", 0)) >= min_payoff_domains_per_faction
            for row in unique_faction_rows
        )
    )
    town_payoff_domain_min = 999
    for faction_row in unique_faction_rows:
        if not isinstance(faction_row, dict):
            town_payoff_domain_min = 0
            continue
        town_rows = faction_row.get("towns", [])
        town_rows = town_rows if isinstance(town_rows, list) else []
        for town_row in town_rows:
            if not isinstance(town_row, dict):
                town_payoff_domain_min = 0
                continue
            town_payoff_domain_min = min(town_payoff_domain_min, int(town_row.get("payoff_domain_count", 0)))
            if int(town_row.get("payoff_domain_count", 0)) < min_payoff_domains_per_town:
                unique_payoff_runtime_ok = False
    if town_payoff_domain_min == 999:
        town_payoff_domain_min = 0
        unique_payoff_runtime_ok = False
    add_check(
        checks,
        "live_unique_town_payoff_runtime",
        unique_payoff_runtime_ok,
        "Faction-unique non-unit town buildings must build through live rules and cover diverse payoff domains per faction and authored town.",
        {
            "faction_count": int(unique_payoff_runtime.get("faction_count", 0)),
            "town_case_count": int(unique_payoff_runtime.get("town_case_count", 0)),
            "building_case_count": int(unique_payoff_runtime.get("building_case_count", 0)),
            "runtime_payoff_case_count": int(unique_payoff_runtime.get("runtime_payoff_case_count", 0)),
            "rare_unique_case_count": int(unique_payoff_runtime.get("rare_unique_case_count", 0)),
            "min_payoff_domains_per_faction": min_payoff_domains_per_faction,
            "min_payoff_domains_per_town": min_payoff_domains_per_town,
            "observed_town_payoff_domain_min": town_payoff_domain_min,
        },
    )

    resource_ui_runtime = payloads["TOWN_ECONOMY_RESOURCE_UI_SURFACE_REPORT"]
    resource_ui_cases = resource_ui_runtime.get("cases", [])
    resource_ui_cases = resource_ui_cases if isinstance(resource_ui_cases, list) else []
    blocked_rare_action_case_count = 0
    ready_rare_action_case_count = 0
    common_only_market_case_count = 0
    same_day_build_lockout_case_count = 0
    for row in resource_ui_cases:
        if not isinstance(row, dict):
            continue
        rare_id = str(row.get("rare_resource_id", ""))
        blocked_action = row.get("blocked_action", {})
        blocked_action = blocked_action if isinstance(blocked_action, dict) else {}
        ready_action = row.get("ready_action", {})
        ready_action = ready_action if isinstance(ready_action, dict) else {}
        blocked_cost = blocked_action.get("cost", {})
        blocked_cost = blocked_cost if isinstance(blocked_cost, dict) else {}
        ready_cost = ready_action.get("cost", {})
        ready_cost = ready_cost if isinstance(ready_cost, dict) else {}
        if (
            rare_id in RARE_RESOURCES
            and int(blocked_cost.get(rare_id, 0)) > 0
            and bool(blocked_action.get("disabled", False))
            and not bool(blocked_action.get("direct_affordable", True))
            and not bool(blocked_action.get("market_coverable", True))
        ):
            blocked_rare_action_case_count += 1
        if (
            rare_id in RARE_RESOURCES
            and int(ready_cost.get(rare_id, 0)) > 0
            and not bool(ready_action.get("disabled", True))
            and bool(ready_action.get("direct_affordable", False))
            and not bool(ready_action.get("market_coverable", True))
        ):
            ready_rare_action_case_count += 1
        if int(row.get("market_action_count", 0)) > 0:
            common_only_market_case_count += 1
        if (
            bool(row.get("same_day_build_lockout_ok", False))
            and int(row.get("post_build_action_count", 999)) == 0
            and int(row.get("post_build_enabled_action_count", 999)) == 0
            and int(row.get("same_day_guarded_unbuilt_count", 0)) > 0
        ):
            same_day_build_lockout_case_count += 1
    resource_ui_runtime_ok = (
        resource_ui_runtime.get("ok") is True
        and int(resource_ui_runtime.get("faction_case_count", 0)) >= MIN_FACTIONS
        and set(str(value) for value in resource_ui_runtime.get("live_stockpile_resource_ids", [])) == LIVE_RESOURCES
        and set(str(value) for value in resource_ui_runtime.get("common_resource_ids", [])) == COMMON_RESOURCES
        and set(str(value) for value in resource_ui_runtime.get("rare_resource_ids", [])) == RARE_RESOURCES
        and blocked_rare_action_case_count >= MIN_FACTIONS
        and ready_rare_action_case_count >= MIN_FACTIONS
        and common_only_market_case_count >= MIN_FACTIONS
    )
    add_check(
        checks,
        "town_resource_ui_surface_runtime",
        resource_ui_runtime_ok,
        "Live TownShell resource/build UI must expose all nine resources, rare build bottlenecks, and common-only market boundaries.",
        {
            "faction_case_count": int(resource_ui_runtime.get("faction_case_count", 0)),
            "blocked_rare_action_case_count": blocked_rare_action_case_count,
            "ready_rare_action_case_count": ready_rare_action_case_count,
            "common_only_market_case_count": common_only_market_case_count,
            "same_day_build_lockout_case_count": same_day_build_lockout_case_count,
            "live_stockpile_resource_ids": sorted(str(value) for value in resource_ui_runtime.get("live_stockpile_resource_ids", [])),
        },
    )
    add_check(
        checks,
        "town_resource_ui_same_day_build_lockout_runtime",
        (
            resource_ui_runtime.get("ok") is True
            and same_day_build_lockout_case_count >= MIN_FACTIONS
            and int(resource_ui_runtime.get("same_day_build_lockout_case_count", 0)) >= MIN_FACTIONS
        ),
        "Live TownShell build UI must stop offering construction after one build order has completed for the current town day.",
        {
            "faction_case_count": int(resource_ui_runtime.get("faction_case_count", 0)),
            "same_day_build_lockout_case_count": same_day_build_lockout_case_count,
            "reported_same_day_build_lockout_case_count": int(resource_ui_runtime.get("same_day_build_lockout_case_count", 0)),
        },
    )

    recruitment_ui_runtime = payloads["TOWN_RECRUITMENT_UI_SURFACE_REPORT"]
    recruitment_ui_runtime_ok = (
        recruitment_ui_runtime.get("ok") is True
        and int(recruitment_ui_runtime.get("faction_case_count", 0)) >= MIN_FACTIONS
        and int(recruitment_ui_runtime.get("target_tier_count", 0)) == SIGNATURE_TIER_COUNT
        and int(recruitment_ui_runtime.get("recruitment_action_count", 0)) >= MIN_FACTIONS * SIGNATURE_TIER_COUNT
        and int(recruitment_ui_runtime.get("tier_button_case_count", 0)) >= MIN_FACTIONS * SIGNATURE_TIER_COUNT
        and int(recruitment_ui_runtime.get("portrait_loaded_count", 0)) >= MIN_FACTIONS * SIGNATURE_TIER_COUNT
        and set(str(value) for value in recruitment_ui_runtime.get("live_stockpile_resource_ids", [])) == LIVE_RESOURCES
    )
    add_check(
        checks,
        "town_recruitment_ui_surface_runtime",
        recruitment_ui_runtime_ok,
        "Live TownShell recruitment UI must expose seven-tier recruit actions, tier labels, affordability, and loaded unit portraits.",
        {
            "faction_case_count": int(recruitment_ui_runtime.get("faction_case_count", 0)),
            "target_tier_count": int(recruitment_ui_runtime.get("target_tier_count", 0)),
            "recruitment_action_count": int(recruitment_ui_runtime.get("recruitment_action_count", 0)),
            "tier_button_case_count": int(recruitment_ui_runtime.get("tier_button_case_count", 0)),
            "portrait_loaded_count": int(recruitment_ui_runtime.get("portrait_loaded_count", 0)),
        },
    )

    market_cap_runtime = payloads["RUNTIME_MARKET_CAP_PERSISTENCE_REPORT"]
    policy = market_cap_runtime.get("policy", {})
    policy = policy if isinstance(policy, dict) else {}
    initial_buy = market_action(market_cap_runtime.get("initial", {}), "market:buy:wood:1")
    initial_sell = market_action(market_cap_runtime.get("initial", {}), "market:sell:ore:1")
    after_buy = market_action(market_cap_runtime.get("after_buy_cap", {}), "market:buy:wood:1")
    after_sell = market_action(market_cap_runtime.get("after_sell_cap", {}), "market:sell:ore:1")
    restored_buy = market_action(market_cap_runtime.get("restored_same_week", {}), "market:buy:wood:1")
    restored_sell = market_action(market_cap_runtime.get("restored_same_week", {}), "market:sell:ore:1")
    next_week_buy = market_action(market_cap_runtime.get("next_week", {}), "market:buy:wood:1")
    next_week_sell = market_action(market_cap_runtime.get("next_week", {}), "market:sell:ore:1")
    market_cap_runtime_ok = (
        market_cap_runtime.get("ok") is True
        and market_cap_runtime.get("schema") == "runtime_market_cap_persistence_report_v1"
        and set(str(value) for value in policy.get("normal_market_resource_ids", [])) == {"wood", "ore"}
        and policy.get("rare_resource_buying_enabled") is False
        and str(policy.get("refresh_cadence", "")) == "weekly"
        and str(policy.get("usage_storage", "")) == "town.market_usage"
        and market_cap_runtime.get("save_resume", {}).get("ok") is True
        and not bool(initial_buy.get("disabled", True))
        and int(initial_buy.get("cap_remaining", 0)) == 6
        and not bool(initial_sell.get("disabled", True))
        and int(initial_sell.get("cap_remaining", 0)) == 8
        and bool(after_buy.get("disabled", False))
        and int(after_buy.get("cap_remaining", -1)) == 0
        and bool(after_sell.get("disabled", False))
        and int(after_sell.get("cap_remaining", -1)) == 0
        and bool(restored_buy.get("disabled", False))
        and int(restored_buy.get("cap_remaining", -1)) == 0
        and bool(restored_sell.get("disabled", False))
        and int(restored_sell.get("cap_remaining", -1)) == 0
        and not bool(next_week_buy.get("disabled", True))
        and int(next_week_buy.get("cap_remaining", 0)) == 6
        and not bool(next_week_sell.get("disabled", True))
        and int(next_week_sell.get("cap_remaining", 0)) == 8
    )
    add_check(
        checks,
        "runtime_market_cap_persistence",
        market_cap_runtime_ok,
        "Live town markets must enforce persisted weekly common-resource exchange caps and reset them on the next week.",
        {
            "schema": str(market_cap_runtime.get("schema", "")),
            "normal_market_resource_ids": sorted(str(value) for value in policy.get("normal_market_resource_ids", [])),
            "rare_resource_buying_enabled": bool(policy.get("rare_resource_buying_enabled", True)),
            "refresh_cadence": str(policy.get("refresh_cadence", "")),
            "usage_storage": str(policy.get("usage_storage", "")),
            "save_resume_ok": market_cap_runtime.get("save_resume", {}).get("ok") is True,
            "initial_buy_remaining": int(initial_buy.get("cap_remaining", 0)),
            "initial_sell_remaining": int(initial_sell.get("cap_remaining", 0)),
            "after_buy_remaining": int(after_buy.get("cap_remaining", -1)),
            "after_sell_remaining": int(after_sell.get("cap_remaining", -1)),
            "restored_buy_remaining": int(restored_buy.get("cap_remaining", -1)),
            "restored_sell_remaining": int(restored_sell.get("cap_remaining", -1)),
            "next_week_buy_remaining": int(next_week_buy.get("cap_remaining", 0)),
            "next_week_sell_remaining": int(next_week_sell.get("cap_remaining", 0)),
        },
    )
    return {
        "town_development_runtime_balance_report_v1": {
            "authored_town_count": int(town_runtime.get("authored_town_count", 0)),
            "recruitment_end_to_end_town_count": int(town_runtime.get("recruitment_end_to_end_town_count", 0)),
            "recruitment_market_covered_town_count": int(town_runtime.get("recruitment_market_covered_town_count", 0)),
            "recruitment_market_purchase_count": int(town_runtime.get("recruitment_market_purchase_count", 0)),
            "recruitment_market_reset_wait_count": int(town_runtime.get("recruitment_market_reset_wait_count", 0)),
        },
        "active_scenario_town_development_runway_report_v1": {
            "active_scenario_count": int(player_runtime.get("active_scenario_count", 0)),
            "campaign_scenario_count": int(player_runtime.get("campaign_scenario_count", 0)),
            "skirmish_scenario_count": int(player_runtime.get("skirmish_scenario_count", 0)),
            "player_town_case_count": int(player_runtime.get("player_town_case_count", 0)),
            "campaign_player_town_case_count": int(player_runtime.get("campaign_player_town_case_count", 0)),
            "skirmish_player_town_case_count": int(player_runtime.get("skirmish_player_town_case_count", 0)),
            "min_completion_day": int(player_runtime.get("min_completion_day", 0)),
            "completion_day_min": int(player_runtime.get("completion_day_min", 0)),
            "completion_day_max": int(player_runtime.get("completion_day_max", 0)),
            "pacing_floor_case_count": int(player_runtime.get("pacing_floor_case_count", 0)),
            "source_adoption_policy_case_count": int(player_runtime.get("source_adoption_policy_case_count", 0)),
            "rare_spend_case_count": int(player_runtime.get("rare_spend_case_count", 0)),
            "full_session_case_count": int(player_runtime.get("full_session_case_count", 0)),
            "recruitment_market_covered_case_count": int(player_runtime.get("recruitment_market_covered_case_count", 0)),
            "recruitment_market_purchase_count": int(player_runtime.get("recruitment_market_purchase_count", 0)),
            "recruitment_market_reset_wait_count": int(player_runtime.get("recruitment_market_reset_wait_count", 0)),
        },
        "active_scenario_town_economy_source_route_report_v1": {
            "active_scenario_count": int(source_route_runtime.get("active_scenario_count", 0)),
            "campaign_scenario_count": int(source_route_runtime.get("campaign_scenario_count", 0)),
            "skirmish_scenario_count": int(source_route_runtime.get("skirmish_scenario_count", 0)),
            "player_town_case_count": int(source_route_runtime.get("player_town_case_count", 0)),
            "campaign_player_town_case_count": int(source_route_runtime.get("campaign_player_town_case_count", 0)),
            "skirmish_player_town_case_count": int(source_route_runtime.get("skirmish_player_town_case_count", 0)),
            "resource_route_case_count": int(source_route_runtime.get("resource_route_case_count", 0)),
            "reachable_route_case_count": int(source_route_runtime.get("reachable_route_case_count", 0)),
            "enemy_town_case_count": int(source_route_runtime.get("enemy_town_case_count", 0)),
            "campaign_enemy_town_case_count": int(source_route_runtime.get("campaign_enemy_town_case_count", 0)),
            "skirmish_enemy_town_case_count": int(source_route_runtime.get("skirmish_enemy_town_case_count", 0)),
            "enemy_resource_route_case_count": int(source_route_runtime.get("enemy_resource_route_case_count", 0)),
            "enemy_reachable_route_case_count": int(source_route_runtime.get("enemy_reachable_route_case_count", 0)),
            "max_common_route_steps": int(source_route_runtime.get("max_common_route_steps", 0)),
            "max_rare_route_steps": int(source_route_runtime.get("max_rare_route_steps", 0)),
        },
        "generated_package_town_economy_surface_v1": {
            "town_count": int(generated_surface.get("town_count", 0)),
            "player_town_count": int(generated_surface.get("player_town_count", 0)),
            "authored_town_template_count": int(generated_surface.get("authored_town_template_count", 0)),
            "seven_tier_town_count": int(generated_surface.get("seven_tier_town_count", 0)),
            "rare_development_town_count": int(generated_surface.get("rare_development_town_count", 0)),
            "unique_faction_count": int(generated_surface.get("unique_faction_count", 0)),
            "unique_town_template_count": int(generated_surface.get("unique_town_template_count", 0)),
            "generated_faction_ids": sorted(generated_faction_ids),
            "generated_town_ids": sorted(generated_town_ids),
            "generated_resource_node_count": int(generated_surface.get("generated_resource_node_count", 0)),
            "generated_resource_source_ids": sorted(generated_resource_source_ids),
            "player_required_resource_ids": sorted(generated_player_required_ids),
        },
        "generated_package_player_town_development_runway_v1": {
            "town_id": str(generated_runway.get("town_id", "")),
            "faction_id": str(generated_runway.get("faction_id", "")),
            "completed": generated_runway.get("completed") is True,
            "completion_day": int(generated_runway.get("completion_day", 0)),
            "min_completion_day": int(generated_runway.get("min_completion_day", 0)),
            "pacing_floor_ok": generated_runway.get("pacing_floor_ok") is True,
            "build_count": int(generated_runway.get("build_count", 0)),
            "target_building_count": int(generated_runway.get("target_building_count", 0)),
            "initial_missing_building_count": int(generated_runway.get("initial_missing_building_count", 0)),
            "rare_spend_observed": generated_runway.get("rare_spend_observed") is True,
            "recruited_unit_case_count": int(generated_runway.get("recruited_unit_case_count", 0)),
            "source_adoption_policy": str(generated_runway.get("source_evidence", {}).get("source_adoption_policy", ""))
            if isinstance(generated_runway.get("source_evidence", {}), dict)
            else "",
            "secured_source_count": int(generated_runway.get("source_evidence", {}).get("secured_source_count", 0))
            if isinstance(generated_runway.get("source_evidence", {}), dict)
            else 0,
        },
        "generated_package_enemy_town_development_runway_v1": {
            "enemy_town_case_count": generated_enemy_case_count,
            "completed_case_count": int(generated_enemy_runway.get("completed_case_count", 0)),
            "min_completion_day": int(generated_enemy_runway.get("min_completion_day", 0)),
            "completion_day_min": int(generated_enemy_runway.get("completion_day_min", 0)),
            "completion_day_max": int(generated_enemy_runway.get("completion_day_max", 0)),
            "pacing_floor_case_count": int(generated_enemy_runway.get("pacing_floor_case_count", 0)),
            "rare_spend_case_count": int(generated_enemy_runway.get("rare_spend_case_count", 0)),
            "same_day_guard_case_count": int(generated_enemy_runway.get("same_day_guard_case_count", 0)),
            "rare_treasury_tracked_case_count": int(generated_enemy_runway.get("rare_treasury_tracked_case_count", 0)),
            "governor_report_case_count": int(generated_enemy_runway.get("governor_report_case_count", 0)),
            "source_covered_case_count": int(generated_enemy_runway.get("source_covered_case_count", 0)),
            "source_adoption_policy_case_count": int(generated_enemy_runway.get("source_adoption_policy_case_count", 0)),
            "full_session_case_count": int(generated_enemy_runway.get("full_session_case_count", 0)),
            "seven_tier_recruitment_case_count": int(generated_enemy_runway.get("seven_tier_recruitment_case_count", 0)),
            "selected_recruitment_case_count": int(generated_enemy_runway.get("selected_recruitment_case_count", 0)),
            "build_count_total": int(generated_enemy_runway.get("build_count_total", 0)),
            "secured_source_count_total": int(generated_enemy_runway.get("secured_source_count_total", 0)),
        },
        "active_scenario_ai_town_development_runway_report_v1": {
            "active_scenario_count": int(ai_runtime.get("active_scenario_count", 0)),
            "campaign_scenario_count": int(ai_runtime.get("campaign_scenario_count", 0)),
            "skirmish_scenario_count": int(ai_runtime.get("skirmish_scenario_count", 0)),
            "enemy_town_case_count": int(ai_runtime.get("enemy_town_case_count", 0)),
            "campaign_enemy_town_case_count": int(ai_runtime.get("campaign_enemy_town_case_count", 0)),
            "skirmish_enemy_town_case_count": int(ai_runtime.get("skirmish_enemy_town_case_count", 0)),
            "min_completion_day": int(ai_runtime.get("min_completion_day", 0)),
            "completion_day_min": int(ai_runtime.get("completion_day_min", 0)),
            "completion_day_max": int(ai_runtime.get("completion_day_max", 0)),
            "pacing_floor_case_count": int(ai_runtime.get("pacing_floor_case_count", 0)),
            "source_adoption_policy_case_count": int(ai_runtime.get("source_adoption_policy_case_count", 0)),
            "rare_spend_case_count": int(ai_runtime.get("rare_spend_case_count", 0)),
            "full_session_case_count": int(ai_runtime.get("full_session_case_count", 0)),
            "seven_tier_recruitment_case_count": int(ai_runtime.get("seven_tier_recruitment_case_count", 0)),
            "seven_tier_recruitment_candidate_count": int(ai_runtime.get("seven_tier_recruitment_candidate_count", 0)),
            "affordable_recruitment_case_count": int(ai_runtime.get("affordable_recruitment_case_count", 0)),
            "unique_faction_count": int(ai_runtime.get("unique_faction_count", 0)),
            "unique_ladder_faction_count": int(ai_runtime.get("unique_ladder_faction_count", 0)),
        },
        "town_unique_building_runtime_payoff_report_v1": {
            "faction_count": int(unique_payoff_runtime.get("faction_count", 0)),
            "town_case_count": int(unique_payoff_runtime.get("town_case_count", 0)),
            "runtime_payoff_case_count": int(unique_payoff_runtime.get("runtime_payoff_case_count", 0)),
            "observed_town_payoff_domain_min": town_payoff_domain_min,
        },
        "town_economy_resource_ui_surface_report_v1": {
            "faction_case_count": int(resource_ui_runtime.get("faction_case_count", 0)),
            "blocked_rare_action_case_count": blocked_rare_action_case_count,
            "ready_rare_action_case_count": ready_rare_action_case_count,
            "common_only_market_case_count": common_only_market_case_count,
            "same_day_build_lockout_case_count": same_day_build_lockout_case_count,
        },
        "town_recruitment_ui_surface_report_v1": {
            "faction_case_count": int(recruitment_ui_runtime.get("faction_case_count", 0)),
            "recruitment_action_count": int(recruitment_ui_runtime.get("recruitment_action_count", 0)),
            "tier_button_case_count": int(recruitment_ui_runtime.get("tier_button_case_count", 0)),
            "portrait_loaded_count": int(recruitment_ui_runtime.get("portrait_loaded_count", 0)),
        },
        "runtime_market_cap_persistence_report_v1": {
            "save_resume_ok": market_cap_runtime.get("save_resume", {}).get("ok") is True,
            "rare_resource_buying_enabled": bool(policy.get("rare_resource_buying_enabled", True)),
            "initial_buy_remaining": int(initial_buy.get("cap_remaining", 0)),
            "after_buy_remaining": int(after_buy.get("cap_remaining", -1)),
            "restored_buy_remaining": int(restored_buy.get("cap_remaining", -1)),
            "next_week_buy_remaining": int(next_week_buy.get("cap_remaining", 0)),
            "initial_sell_remaining": int(initial_sell.get("cap_remaining", 0)),
            "after_sell_remaining": int(after_sell.get("cap_remaining", -1)),
            "restored_sell_remaining": int(restored_sell.get("cap_remaining", -1)),
            "next_week_sell_remaining": int(next_week_sell.get("cap_remaining", 0)),
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
        live_registry_ok
        and matrix_ok
        and int(source_matrix.get("campaign_scenario_count", 0)) >= MIN_CAMPAIGN_SCENARIOS
        and int(source_matrix.get("skirmish_scenario_count", 0)) >= MIN_SKIRMISH_SCENARIOS
        and int(source_matrix.get("campaign_player_town_case_count", 0)) >= MIN_CAMPAIGN_PLAYER_TOWN_CASES
        and int(source_matrix.get("skirmish_player_town_case_count", 0)) >= MIN_SKIRMISH_PLAYER_TOWN_CASES
        and int(source_matrix.get("campaign_enemy_town_case_count", 0)) >= MIN_CAMPAIGN_ENEMY_TOWN_CASES
        and int(source_matrix.get("skirmish_enemy_town_case_count", 0)) >= MIN_SKIRMISH_ENEMY_TOWN_CASES
        and all(int(row.get("campaign_source_scenario_count", 0)) > 0 for row in matrix_resources.values())
        and all(int(row.get("skirmish_source_scenario_count", 0)) > 0 for row in matrix_resources.values()),
        "All nine resources must be live stockpile ids with active campaign and skirmish source coverage.",
        {
            "live_resources": sorted(LIVE_RESOURCES),
            "matrix_signature": source_matrix.get("matrix_signature", ""),
            "active_scenario_count": int(source_matrix.get("active_scenario_count", 0)),
            "campaign_scenario_count": int(source_matrix.get("campaign_scenario_count", 0)),
            "skirmish_scenario_count": int(source_matrix.get("skirmish_scenario_count", 0)),
            "player_town_case_count": int(source_matrix.get("player_town_case_count", 0)),
            "enemy_town_case_count": int(source_matrix.get("enemy_town_case_count", 0)),
            "campaign_player_town_case_count": int(source_matrix.get("campaign_player_town_case_count", 0)),
            "skirmish_player_town_case_count": int(source_matrix.get("skirmish_player_town_case_count", 0)),
            "campaign_enemy_town_case_count": int(source_matrix.get("campaign_enemy_town_case_count", 0)),
            "skirmish_enemy_town_case_count": int(source_matrix.get("skirmish_enemy_town_case_count", 0)),
        },
    )

    harness_accounting = balance_harness_resource_accounting_report()
    add_check(
        checks,
        "balance_harness_live_resource_accounting",
        harness_accounting["ok"],
        "Shared balance regression and headless simulation economy evidence must account for all nine live stockpile resources.",
        {
            "schema": harness_accounting["schema"],
            "live_resource_ids": harness_accounting["live_resource_ids"],
            "file_count": harness_accounting["file_count"],
            "passing_file_count": harness_accounting["passing_file_count"],
            "rows": harness_accounting["rows"],
        },
    )

    town_rows = balance.get("towns", {}) if isinstance(balance.get("towns", {}), dict) else {}
    completion_days = [int(row.get("completion_day", 0)) for row in town_rows.values() if isinstance(row, dict)]
    end_to_end_ok = (
        balance.get("ok") is True
        and int(balance.get("authored_town_count", 0)) >= MIN_AUTHORED_TOWNS
        and len(town_rows) >= MIN_AUTHORED_TOWNS
        and all(MIN_DETERMINISTIC_COMPLETION_DAY <= day <= TARGET_TURNS for day in completion_days)
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
            "min_completion_day": MIN_DETERMINISTIC_COMPLETION_DAY,
            "target_turns": TARGET_TURNS,
        },
    )

    balance_phase_windows = balance.get("phase_windows", {})
    balance_phase_windows = balance_phase_windows if isinstance(balance_phase_windows, dict) else {}
    phase_curve_ok = (
        balance.get("ok") is True
        and balance_phase_windows == PHASE_WINDOWS
        and all(
            isinstance(row, dict)
            and isinstance(row.get("phase_build_counts", {}), dict)
            and all(
                int(row.get("phase_build_counts", {}).get(phase_id, 0)) >= int(window["min_builds"])
                for phase_id, window in PHASE_WINDOWS.items()
            )
            for row in town_rows.values()
        )
    )
    phase_min_counts = {
        phase_id: min(
            [
                int(row.get("phase_build_counts", {}).get(phase_id, 0))
                for row in town_rows.values()
                if isinstance(row, dict) and isinstance(row.get("phase_build_counts", {}), dict)
            ]
            or [0]
        )
        for phase_id in PHASE_WINDOWS
    }
    add_check(
        checks,
        "town_development_phase_curve",
        phase_curve_ok,
        "Authored town development must preserve early, mid, and late construction work across the 30-turn balance curve.",
        {
            "phase_windows": PHASE_WINDOWS,
            "observed_phase_min_counts": phase_min_counts,
            "completion_day_min": min(completion_days) if completion_days else 0,
            "completion_day_max": max(completion_days) if completion_days else 0,
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
    price_band_ok = cost_curve.get("ok") is True
    price_band_limits = cost_curve.get("price_band_limits", {})
    price_band_limits = price_band_limits if isinstance(price_band_limits, dict) else {}
    price_band_rows: dict[str, Any] = {}
    for town_id, row in cost_rows.items():
        if not isinstance(row, dict):
            common_cost_ok = False
            price_band_ok = False
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
        price_band_values = row.get("price_band_values", {})
        price_band_values = price_band_values if isinstance(price_band_values, dict) else {}
        price_band_failures = row.get("price_band_failures", [])
        price_band_failures = price_band_failures if isinstance(price_band_failures, list) else []
        if price_band_failures:
            price_band_ok = False
        price_band_rows[town_id] = {
            "values": price_band_values,
            "failure_count": len(price_band_failures),
        }
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
    add_check(
        checks,
        "town_development_price_band_sanity",
        price_band_ok,
        "Authored town development totals must stay inside bounded price bands for gold, wood, ore, faction rare spend, target count, and rare-cost building count.",
        {
            "price_band_limits": price_band_limits,
            "town_count": len(price_band_rows),
            "failure_count": sum(int(row.get("failure_count", 0)) for row in price_band_rows.values()),
            "town_price_bands": price_band_rows,
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

    late_rare_bottleneck_ok = balance.get("ok") is True
    min_late_rare_bottleneck_day = int(balance.get("min_late_rare_bottleneck_day", 0))
    min_late_rare_bottleneck_days_per_town = int(balance.get("min_late_rare_bottleneck_days_per_town", 0))
    late_rare_bottleneck_rows: dict[str, int] = {}
    for town_id, row in town_rows.items():
        if not isinstance(row, dict):
            late_rare_bottleneck_ok = False
            continue
        count = int(row.get("late_rare_bottleneck_day_count", 0))
        late_rare_bottleneck_rows[town_id] = count
        if count < min_late_rare_bottleneck_days_per_town:
            late_rare_bottleneck_ok = False
    add_check(
        checks,
        "late_rare_resource_bottleneck",
        late_rare_bottleneck_ok,
        "Every authored town must hit at least one late-development bottleneck where an available high-tier/upgrade building is blocked by its faction rare resource.",
        {
            "min_late_rare_bottleneck_day": min_late_rare_bottleneck_day,
            "min_late_rare_bottleneck_days_per_town": min_late_rare_bottleneck_days_per_town,
            "town_count": len(late_rare_bottleneck_rows),
            "late_rare_bottleneck_day_count_min": min(late_rare_bottleneck_rows.values(), default=0),
            "late_rare_bottleneck_day_count_max": max(late_rare_bottleneck_rows.values(), default=0),
            "town_late_rare_bottleneck_day_counts": late_rare_bottleneck_rows,
        },
    )

    common_material_pressure_ok = (
        balance.get("ok") is True
        and int(balance.get("min_common_material_bottleneck_days_per_town", 0)) >= MIN_COMMON_MATERIAL_BOTTLENECK_DAYS_PER_TOWN
    )
    common_material_rows: dict[str, int] = {}
    common_material_ids_by_town: dict[str, list[str]] = {}
    for town_id, row in town_rows.items():
        if not isinstance(row, dict):
            common_material_pressure_ok = False
            continue
        bottleneck_days = row.get("common_material_bottleneck_days", [])
        bottleneck_days = bottleneck_days if isinstance(bottleneck_days, list) else []
        material_ids = {
            str(resource_id)
            for day_row in bottleneck_days
            if isinstance(day_row, dict)
            for resource_id in day_row.get("missing_material_ids", [])
        }
        count = int(row.get("common_material_bottleneck_day_count", 0))
        common_material_rows[town_id] = count
        common_material_ids_by_town[town_id] = sorted(material_ids)
        if count < MIN_COMMON_MATERIAL_BOTTLENECK_DAYS_PER_TOWN or not material_ids.intersection({"wood", "ore"}):
            common_material_pressure_ok = False
    add_check(
        checks,
        "common_material_development_pressure",
        common_material_pressure_ok,
        "Every authored town must hit at least one development bottleneck caused by wood or ore, not only gold or rare resources.",
        {
            "min_common_material_bottleneck_days_per_town": int(balance.get("min_common_material_bottleneck_days_per_town", 0)),
            "common_material_bottleneck_day_count_min": min(common_material_rows.values(), default=0),
            "common_material_bottleneck_day_count_max": max(common_material_rows.values(), default=0),
            "town_common_material_bottleneck_day_counts": common_material_rows,
            "town_common_material_bottleneck_ids": common_material_ids_by_town,
        },
    )

    report_common_surplus_limits = balance.get("max_ending_common_after_completion", {})
    report_common_surplus_limits = report_common_surplus_limits if isinstance(report_common_surplus_limits, dict) else {}
    report_common_surplus_ratio_limits = balance.get("max_ending_common_surplus_ratio_after_completion", {})
    report_common_surplus_ratio_limits = (
        report_common_surplus_ratio_limits if isinstance(report_common_surplus_ratio_limits, dict) else {}
    )
    common_surplus_pressure_ok = (
        balance.get("ok") is True
        and report_common_surplus_limits == MAX_ENDING_COMMON_AFTER_COMPLETION
        and report_common_surplus_ratio_limits == MAX_ENDING_COMMON_SURPLUS_RATIO_AFTER_COMPLETION
    )
    max_observed_common_surplus: dict[str, int] = {resource_id: 0 for resource_id in COMMON_RESOURCES}
    max_observed_common_surplus_ratios: dict[str, float] = {resource_id: 0.0 for resource_id in COMMON_RESOURCES}
    common_surplus_failure_count = 0
    for town_id, row in town_rows.items():
        if not isinstance(row, dict):
            common_surplus_pressure_ok = False
            continue
        ending_resources = row.get("ending_resources", {})
        ending_resources = ending_resources if isinstance(ending_resources, dict) else {}
        ratios = row.get("ending_common_surplus_ratios", {})
        ratios = ratios if isinstance(ratios, dict) else {}
        failures = row.get("ending_common_surplus_failures", [])
        failures = failures if isinstance(failures, list) else []
        common_surplus_failure_count += len(failures)
        if failures:
            common_surplus_pressure_ok = False
        for resource_id in COMMON_RESOURCES:
            amount = int(ending_resources.get(resource_id, 0))
            ratio = float(ratios.get(resource_id, 0.0))
            max_observed_common_surplus[resource_id] = max(max_observed_common_surplus[resource_id], amount)
            max_observed_common_surplus_ratios[resource_id] = max(max_observed_common_surplus_ratios[resource_id], ratio)
            if amount > int(MAX_ENDING_COMMON_AFTER_COMPLETION[resource_id]):
                common_surplus_pressure_ok = False
            if ratio > float(MAX_ENDING_COMMON_SURPLUS_RATIO_AFTER_COMPLETION[resource_id]):
                common_surplus_pressure_ok = False
    add_check(
        checks,
        "common_resource_surplus_pressure",
        common_surplus_pressure_ok,
        "Authored towns must finish deterministic development inside bounded post-completion gold, wood, and ore surplus envelopes.",
        {
            "max_ending_common_after_completion": MAX_ENDING_COMMON_AFTER_COMPLETION,
            "max_ending_common_surplus_ratio_after_completion": MAX_ENDING_COMMON_SURPLUS_RATIO_AFTER_COMPLETION,
            "observed_common_surplus_max": dict(sorted(max_observed_common_surplus.items())),
            "observed_common_surplus_ratio_max": {
                resource_id: round(value, 4)
                for resource_id, value in sorted(max_observed_common_surplus_ratios.items())
            },
            "failure_count": common_surplus_failure_count,
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

    rare_upgrade_ok = int(cost_curve.get("min_rare_upgrade_buildings_per_town", 0)) >= MIN_RARE_UPGRADE_BUILDINGS_PER_TOWN
    rare_upgrade_counts: dict[str, int] = {}
    rare_upgrade_total = 0
    for town_id, row in cost_rows.items():
        if not isinstance(row, dict):
            rare_upgrade_ok = False
            continue
        rare_upgrade_count = int(row.get("rare_upgrade_building_count", 0))
        rare_upgrade_counts[town_id] = rare_upgrade_count
        rare_upgrade_total += rare_upgrade_count
        if rare_upgrade_count < MIN_RARE_UPGRADE_BUILDINGS_PER_TOWN:
            rare_upgrade_ok = False
    add_check(
        checks,
        "rare_upgrade_chain_pressure",
        rare_upgrade_ok,
        "Every authored town must include at least one rare-cost upgrade chain behind high-tier development.",
        {
            "min_rare_upgrade_buildings_per_town": MIN_RARE_UPGRADE_BUILDINGS_PER_TOWN,
            "town_count": len(rare_upgrade_counts),
            "rare_upgrade_building_total": rare_upgrade_total,
            "rare_upgrade_count_min": min(rare_upgrade_counts.values(), default=0),
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
                "min_completion_day": int(balance.get("min_completion_day", 0)),
                "phase_windows": balance.get("phase_windows", {}),
                "phase_min_counts": phase_min_counts,
                "min_late_rare_bottleneck_day": int(balance.get("min_late_rare_bottleneck_day", 0)),
                "min_late_rare_bottleneck_days_per_town": int(balance.get("min_late_rare_bottleneck_days_per_town", 0)),
                "min_common_material_bottleneck_days_per_town": int(balance.get("min_common_material_bottleneck_days_per_town", 0)),
                "max_ending_common_after_completion": balance.get("max_ending_common_after_completion", {}),
                "max_ending_common_surplus_ratio_after_completion": balance.get(
                    "max_ending_common_surplus_ratio_after_completion",
                    {},
                ),
                "observed_common_surplus_max": dict(sorted(max_observed_common_surplus.items())),
                "observed_common_surplus_ratio_max": {
                    resource_id: round(value, 4)
                    for resource_id, value in sorted(max_observed_common_surplus_ratios.items())
                },
            },
            "town_development_cost_curve_report_v1": {
                "authored_town_count": int(cost_curve.get("authored_town_count", 0)),
                "faction_count": int(cost_curve.get("faction_count", 0)),
                "min_rare_upgrade_buildings_per_town": int(cost_curve.get("min_rare_upgrade_buildings_per_town", 0)),
                "price_band_limits": cost_curve.get("price_band_limits", {}),
            },
            "active_scenario_resource_availability_matrix_v1": {
                "active_scenario_count": int(source_matrix.get("active_scenario_count", 0)),
                "campaign_scenario_count": int(source_matrix.get("campaign_scenario_count", 0)),
                "skirmish_scenario_count": int(source_matrix.get("skirmish_scenario_count", 0)),
                "player_town_case_count": int(source_matrix.get("player_town_case_count", 0)),
                "enemy_town_case_count": int(source_matrix.get("enemy_town_case_count", 0)),
                "campaign_player_town_case_count": int(source_matrix.get("campaign_player_town_case_count", 0)),
                "skirmish_player_town_case_count": int(source_matrix.get("skirmish_player_town_case_count", 0)),
                "campaign_enemy_town_case_count": int(source_matrix.get("campaign_enemy_town_case_count", 0)),
                "skirmish_enemy_town_case_count": int(source_matrix.get("skirmish_enemy_town_case_count", 0)),
            },
            "faction_town_unit_asymmetry_report": {
                "unique_fingerprints": asymmetry.get("unique_fingerprints", {}),
            },
            "balance_harness_resource_accounting_v1": {
                "live_resource_ids": harness_accounting["live_resource_ids"],
                "passing_file_count": harness_accounting["passing_file_count"],
            },
        },
        "runtime_reports_included": bool(args.include_runtime),
        "runtime_reports": runtime_reports,
    }
    print("ECONOMY_TOWN_GOAL_SCORECARD_REPORT " + json.dumps(report, sort_keys=True))
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
