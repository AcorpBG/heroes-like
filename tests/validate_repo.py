#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import struct
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CONTENT_DIR = ROOT / "content"
CONTENT_SERVICE_PATH = ROOT / "scripts" / "autoload" / "ContentService.gd"
NEUTRAL_DWELLINGS_PATH = CONTENT_DIR / "neutral_dwellings.json"
SAVE_SERVICE_PATH = ROOT / "scripts" / "autoload" / "SaveService.gd"
CAMPAIGN_PROGRESSION_PATH = ROOT / "scripts" / "autoload" / "CampaignProgression.gd"
SETTINGS_SERVICE_PATH = ROOT / "scripts" / "autoload" / "SettingsService.gd"
LIVE_VALIDATION_HARNESS_PATH = ROOT / "scripts" / "autoload" / "LiveValidationHarness.gd"
APP_ROUTER_PATH = ROOT / "scripts" / "autoload" / "AppRouter.gd"
SESSION_STATE_PATH = ROOT / "scripts" / "autoload" / "SessionState.gd"
SESSION_STATE_STORE_PATH = ROOT / "scripts" / "core" / "SessionStateStore.gd"
GLOBAL_SCRIPT_CLASS_CACHE_PATH = ROOT / ".godot" / "global_script_class_cache.cfg"
DIFFICULTY_RULES_PATH = ROOT / "scripts" / "core" / "DifficultyRules.gd"
HERO_PROGRESSION_RULES_PATH = ROOT / "scripts" / "core" / "HeroProgressionRules.gd"
HERO_COMMAND_RULES_PATH = ROOT / "scripts" / "core" / "HeroCommandRules.gd"
SCENARIO_FACTORY_PATH = ROOT / "scripts" / "core" / "ScenarioFactory.gd"
SCENARIO_SELECT_RULES_PATH = ROOT / "scripts" / "core" / "ScenarioSelectRules.gd"
SCENARIO_RULES_PATH = ROOT / "scripts" / "core" / "ScenarioRules.gd"
SCENARIO_SCRIPT_RULES_PATH = ROOT / "scripts" / "core" / "ScenarioScriptRules.gd"
OVERWORLD_RULES_PATH = ROOT / "scripts" / "core" / "OverworldRules.gd"
BATTLE_RULES_PATH = ROOT / "scripts" / "core" / "BattleRules.gd"
BATTLE_AI_RULES_PATH = ROOT / "scripts" / "core" / "BattleAiRules.gd"
TOWN_RULES_PATH = ROOT / "scripts" / "core" / "TownRules.gd"
CAMPAIGN_RULES_PATH = ROOT / "scripts" / "core" / "CampaignRules.gd"
ARTIFACT_RULES_PATH = ROOT / "scripts" / "core" / "ArtifactRules.gd"
SPELL_RULES_PATH = ROOT / "scripts" / "core" / "SpellRules.gd"
ENEMY_TURN_RULES_PATH = ROOT / "scripts" / "core" / "EnemyTurnRules.gd"
ENEMY_ADVENTURE_RULES_PATH = ROOT / "scripts" / "core" / "EnemyAdventureRules.gd"
MAIN_MENU_SCENE_PATH = ROOT / "scenes" / "menus" / "MainMenu.tscn"
MAIN_MENU_SCRIPT_PATH = ROOT / "scenes" / "menus" / "MainMenu.gd"
OVERWORLD_SCENE_PATH = ROOT / "scenes" / "overworld" / "OverworldShell.tscn"
OVERWORLD_SCRIPT_PATH = ROOT / "scenes" / "overworld" / "OverworldShell.gd"
OVERWORLD_MAP_VIEW_SCRIPT_PATH = ROOT / "scenes" / "overworld" / "OverworldMapView.gd"
OVERWORLD_ART_MANIFEST_PATH = ROOT / "art" / "overworld" / "manifest.json"
TERRAIN_GRAMMAR_PATH = CONTENT_DIR / "terrain_grammar.json"
TERRAIN_LAYERS_PATH = CONTENT_DIR / "terrain_layers.json"
TOWN_SCENE_PATH = ROOT / "scenes" / "town" / "TownShell.tscn"
TOWN_SCRIPT_PATH = ROOT / "scenes" / "town" / "TownShell.gd"
BATTLE_SCENE_PATH = ROOT / "scenes" / "battle" / "BattleShell.tscn"
BATTLE_SCRIPT_PATH = ROOT / "scenes" / "battle" / "BattleShell.gd"
OUTCOME_SCENE_PATH = ROOT / "scenes" / "results" / "ScenarioOutcomeShell.tscn"
OUTCOME_SCRIPT_PATH = ROOT / "scenes" / "results" / "ScenarioOutcomeShell.gd"
RUN_LIVE_FLOW_HARNESS_PATH = ROOT / "tests" / "run_live_flow_harness.py"

VALID_DIFFICULTIES = {"story", "normal", "hard"}
WAYFARERS_HALL_BUILDING_ID = "building_wayfarers_hall"
SUPPORTED_UNIT_ABILITY_IDS = {"reach", "brace", "harry", "backstab", "shielding", "volley", "formation_guard", "bloodrush"}
VALID_BATTLE_TRAIT_IDS = {"linekeeper", "artillerist", "ambusher", "bogwise", "packhunter", "vanguard"}
SUPPORTED_BATTLEFIELD_TAGS = {
    "chokepoint",
    "elevated_fire",
    "bog_channels",
    "ambush_cover",
    "open_lane",
    "fog_bank",
    "fortified_line",
    "fortress_lane",
    "reserve_wave",
    "battery_nest",
    "wall_pressure",
}
SUPPORTED_FIELD_OBJECTIVE_TYPES = {
    "lane_battery",
    "cover_line",
    "obstruction_line",
    "ritual_pylon",
    "supply_post",
    "signal_beacon",
    "breach_point",
    "hazard_zone",
}
SUPPORTED_FIELD_OBJECTIVE_PRESSURE_TAGS = {
    "ranged",
    "initiative",
    "cohesion",
    "reinforcement",
    "commander",
    "momentum",
    "urgency",
}
SUPPORTED_BUILDING_CATEGORIES = {"civic", "dwelling", "economy", "support", "magic"}
VALID_SPECIALTY_IDS = {"wayfinder", "ledgerkeeper", "spellwright", "drillmaster", "armsmaster", "mustercaptain", "borderwarden"}
RELEASE_PLAYER_FACTIONS = {"faction_embercourt", "faction_mireclaw", "faction_sunvault"}
SIX_FACTION_BIBLE_IDS = {
    "faction_embercourt",
    "faction_mireclaw",
    "faction_sunvault",
    "faction_thornwake",
    "faction_brasshollow",
    "faction_veilmourn",
}
NEW_SIX_FACTION_SCAFFOLD_IDS = {"faction_thornwake", "faction_brasshollow", "faction_veilmourn"}
SIX_FACTION_COMMON_WORDS = {
    "militia",
    "archer",
    "pikeman",
    "goblin",
    "ogre",
    "skeleton",
    "zombie",
    "elf",
    "dwarf",
    "angel",
    "dragon",
}
ADVANCED_EMBERCOURT_BUILDING_IDS = {
    "building_river_granary_exchange",
    "building_quartermasters_depot",
    "building_signal_citadel",
}
ADVANCED_MIRECLAW_BUILDING_IDS = {
    "building_war_drum_circle",
    "building_smugglers_flotilla",
    "building_floodtide_forge",
}
ADVANCED_SUNVAULT_BUILDING_IDS = {
    "building_resonant_exchange",
    "building_harmonic_cloister",
    "building_aurora_spire",
}
MARKET_BUILDING_IDS = {
    "building_market_square",
    "building_river_granary_exchange",
    "building_resonant_exchange",
}
LOGISTICS_SITE_FAMILIES = {"neutral_dwelling", "faction_outpost", "frontier_shrine"}
OVERWORLD_FOUNDATION_SITE_FAMILIES = {
    "mine",
    "scouting_structure",
    "guarded_reward_site",
    "transit_object",
    "repeatable_service",
}
SUPPORTED_RESOURCE_SITE_FAMILIES = LOGISTICS_SITE_FAMILIES | OVERWORLD_FOUNDATION_SITE_FAMILIES | {"one_shot_pickup"}
SUPPORTED_MAP_OBJECT_FAMILIES = {
    "pickup",
    "mine",
    "neutral_dwelling",
    "shrine",
    "guarded_reward_site",
    "scouting_structure",
    "transit_object",
    "repeatable_service",
    "blocker",
    "decoration",
    "faction_landmark",
}
SIX_FACTION_BIOME_BREADTH_SCENARIO_ID = "ninefold-confluence"
SIX_FACTION_BIOME_BREADTH_REQUIRED_SITE_FAMILIES = SUPPORTED_RESOURCE_SITE_FAMILIES
OVERWORLD_FOUNDATION_RESOURCE_SITE_IDS = {
    "site_brightwood_sawmill",
    "site_ridge_quarry",
    "site_marsh_peat_yard",
    "site_watchtower_beacon",
    "site_mist_lighthouse",
    "site_barrow_vault",
    "site_drowned_reliquary",
    "site_repaired_ferry_stage",
    "site_rope_lift",
    "site_wayfarer_infirmary",
    "site_market_caravanserai",
}
LOGISTICS_SITE_IDS = {
    "site_free_company_yard",
    "site_fenhound_kennels",
    "site_lens_house",
    "site_ember_signal_post",
    "site_bog_drum_outpost",
    "site_prism_watch_relay",
    "site_roadside_sanctum",
    "site_reedscript_shrine",
    "site_starlens_sanctum",
}
TERRAIN_GRAMMAR_REQUIRED_TERRAIN_IDS = {"grass", "plains", "forest", "mire", "swamp", "hills", "ridge", "highland"}
OVERWORLD_ART_REQUIRED_ASSET_IDS = {
    "frontier_town",
    "hostile_camp",
    "ruined_obelisk",
    "lumber_wagon",
    "ore_crates",
    "adventurers_bundle",
    "guarded_farmhouse",
    "kennel",
    "falconers_nest",
    "alchemists_hut",
    "shrine",
    "watchtower",
    "sawmill",
    "stone_quarry",
}
OVERWORLD_ART_REQUIRED_SITE_MAPPINGS = {
    "site_timber_wagon": "lumber_wagon",
    "site_ore_crates": "ore_crates",
    "site_waystone_cache": "ruined_obelisk",
    "site_fenhound_kennels": "kennel",
    "site_cliffhawk_roost": "falconers_nest",
    "site_watchtower_beacon": "watchtower",
    "site_brightwood_sawmill": "sawmill",
    "site_ridge_quarry": "stone_quarry",
    "site_roadside_sanctum": "shrine",
}
RELEASE_LOGISTICS_SCENARIO_IDS = {"river-pass", "reedbarrow-ferry", "prismhearth-watch", "glassfen-breakers"}
STRATEGIC_RESPONSE_SCENARIO_IDS = {"river-pass", "reedbarrow-ferry", "prismhearth-watch", "glassfen-breakers", "lockmarsh-surge"}
CAPITAL_PROJECT_BUILDING_IDS = {
    "building_charter_bastion",
    "building_nightglass_dominion",
    "building_daybreak_matrix",
}
CAPITAL_PROJECT_TOWN_BUILDINGS = {
    "town_highwater_keep": "building_charter_bastion",
    "town_nightglass_redoubt": "building_nightglass_dominion",
    "town_prismhearth": "building_daybreak_matrix",
}
STRATEGIC_STRONGHOLD_IDS = {
    "town_riverwatch",
    "town_duskfen",
    "town_reedbarrow_ferry",
    "town_halo_spire",
}
STRATEGIC_LOGISTICS_TOWN_IDS = set(CAPITAL_PROJECT_TOWN_BUILDINGS.keys()) | STRATEGIC_STRONGHOLD_IDS
LATE_GAME_CAPITAL_SCENARIO_EXPECTATIONS = {
    "nightglass-redoubt": {
        "placement_id": "nightglass_redoubt",
        "building_id": "building_nightglass_dominion",
        "objective_id": "claim_nightglass",
    },
    "lockmarsh-surge": {
        "placement_id": "highwater_keep",
        "building_id": "building_charter_bastion",
        "objective_id": "claim_highwater_final",
    },
    "daybreak-spire": {
        "placement_id": "nightglass_redoubt",
        "building_id": "building_nightglass_dominion",
        "objective_id": "claim_nightglass",
    },
    "glassfen-breakers": {
        "placement_id": "prismhearth_array",
        "building_id": "building_daybreak_matrix",
        "objective_id": "claim_prismhearth",
    },
}
CAPITAL_FRONT_SIGNATURE_ARMIES = {
    "army_charter_bastion_reserve",
    "army_nightglass_dominion",
    "army_daybreak_matrix",
}
CAPITAL_FRONT_ENCOUNTER_EXPECTATIONS = {
    "encounter_charter_guard": {"enemy_group_id": "army_charter_bastion_reserve", "required_tags": {"fortress_lane", "reserve_wave"}},
    "encounter_archive_wardens": {"enemy_group_id": "army_archive_wardens", "required_tags": {"fortress_lane"}},
    "encounter_drum_circle": {"enemy_group_id": "army_nightglass_dominion", "required_tags": {"wall_pressure", "reserve_wave"}},
    "encounter_bone_ferry_watch": {"enemy_group_id": "army_ripper_vanguard", "required_tags": {"wall_pressure"}},
    "encounter_relay_pickets": {"enemy_group_id": "army_relay_pickets", "required_tags": {"battery_nest"}},
    "encounter_aurora_battery": {"enemy_group_id": "army_aurora_battery", "required_tags": {"battery_nest", "reserve_wave"}},
    "encounter_halo_reserve": {"enemy_group_id": "army_halo_reserve", "required_tags": {"battery_nest", "reserve_wave"}},
    "encounter_daybreak_array": {"enemy_group_id": "army_daybreak_matrix", "required_tags": {"battery_nest", "reserve_wave"}},
    "encounter_charter_bastion_reserve": {"enemy_group_id": "army_charter_bastion_reserve", "required_tags": {"fortress_lane", "reserve_wave"}},
    "encounter_nightglass_dominion": {"enemy_group_id": "army_nightglass_dominion", "required_tags": {"wall_pressure", "reserve_wave"}},
    "encounter_daybreak_matrix": {"enemy_group_id": "army_daybreak_matrix", "required_tags": {"battery_nest", "reserve_wave"}},
}
CAPITAL_FRONT_SCENARIO_EXPECTATIONS = {
    "nightglass-redoubt": {
        "front_encounter_ids": {"encounter_drum_circle", "encounter_bone_ferry_watch"},
        "raid_encounter_ids": {"encounter_bone_ferry_watch", "encounter_nightglass_dominion"},
        "hook_id": "nightglass_dominion_rises",
        "spawn_encounter_id": "encounter_nightglass_dominion",
    },
    "lockmarsh-surge": {
        "front_encounter_ids": {"encounter_charter_guard", "encounter_archive_wardens"},
        "raid_encounter_ids": {"encounter_charter_bastion_reserve", "encounter_road_chaplains"},
        "hook_id": "charter_bastion_ignites",
        "spawn_encounter_id": "encounter_charter_bastion_reserve",
    },
    "daybreak-spire": {
        "front_encounter_ids": {"encounter_daybreak_array", "encounter_bone_ferry_watch"},
        "raid_encounter_ids": {"encounter_bone_ferry_watch", "encounter_nightglass_dominion"},
        "hook_id": "nightglass_dominion_holds",
        "spawn_encounter_id": "encounter_nightglass_dominion",
    },
    "glassfen-breakers": {
        "front_encounter_ids": {"encounter_relay_pickets", "encounter_aurora_battery"},
        "raid_encounter_ids": {"encounter_aurora_battery", "encounter_daybreak_matrix"},
        "hook_id": "daybreak_matrix_locks",
        "spawn_encounter_id": "encounter_daybreak_matrix",
    },
}
RELEASE_FIELD_OBJECTIVE_ENCOUNTER_IDS = {
    "encounter_reedbarrow_chain",
    "encounter_drum_circle",
    "encounter_lantern_patrol",
    "encounter_charter_guard",
    "encounter_reed_totemists",
    "encounter_relay_pickets",
    "encounter_daybreak_matrix",
}
RELEASE_FIELD_OBJECTIVE_SCENARIO_PLACEMENTS = {
    "reedbarrow_chain",
    "nightglass_drum_circle",
    "prismhearth_relay_pickets",
    "glassfen_relay_pickets",
}
RELEASE_BATTLEFIELD_IDENTITY_OBJECTIVES = {
    "encounter_ghoul_grove": {"cover_line"},
    "encounter_reedbarrow_chain": {"obstruction_line", "lane_battery"},
    "encounter_charter_guard": {"obstruction_line", "signal_beacon"},
    "encounter_bone_ferry_watch": {"cover_line", "obstruction_line"},
    "encounter_bridgeward_levies": {"obstruction_line"},
    "encounter_relay_pickets": {"cover_line", "lane_battery"},
    "encounter_daybreak_matrix": {"cover_line", "lane_battery"},
}
ENEMY_STRATEGY_KEYS = {
    "build_category_weights": {"civic", "dwelling", "economy", "support", "magic"},
    "build_value_weights": {"income", "growth", "quality", "readiness", "pressure"},
    "raid_target_weights": {"town", "resource", "artifact", "encounter", "hero"},
    "site_family_weights": LOGISTICS_SITE_FAMILIES,
    "reinforcement": {"garrison_bias", "raid_bias", "ranged_weight", "melee_weight", "low_tier_weight", "high_tier_weight"},
    "raid": {"threshold_scale", "max_active_bonus", "pressure_commitment_scale", "objective_weight", "town_siege_weight", "site_denial_weight", "hero_hunt_weight"},
}


def load_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def res_path_to_disk(path: str) -> Path:
    if path.startswith("res://"):
        return ROOT / path.removeprefix("res://")
    return Path(path)


def png_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as handle:
        header = handle.read(24)
    if len(header) < 24 or header[:8] != b"\x89PNG\r\n\x1a\n":
        return (0, 0)
    width, height = struct.unpack(">II", header[16:24])
    return (int(width), int(height))


def items_index(payload: dict) -> dict[str, dict]:
    return {str(item["id"]): item for item in payload.get("items", []) if isinstance(item, dict) and "id" in item}


def is_neutral_unit(unit: dict) -> bool:
    return bool(unit.get("neutral", False)) or str(unit.get("affiliation", "")) == "neutral"


def is_neutral_army_group(group: dict) -> bool:
    return str(group.get("affiliation", "")) == "neutral"


def fail(errors: list[str], message: str) -> None:
    errors.append(message)


def ensure(condition: bool, errors: list[str], message: str) -> None:
    if not condition:
        fail(errors, message)


def append_unique(values: list[str], value: str) -> None:
    if value and value not in values:
        values.append(value)


def scene_has_node(scene_text: str, node_name: str, node_type: str) -> bool:
    pattern = rf'\[node name="{re.escape(node_name)}" type="{re.escape(node_type)}"'
    return re.search(pattern, scene_text) is not None


def scene_node_parent(scene_text: str, node_name: str, node_type: str) -> str:
    pattern = rf'\[node name="{re.escape(node_name)}" type="{re.escape(node_type)}" parent="([^"]*)"'
    match = re.search(pattern, scene_text)
    return match.group(1) if match else ""


def scene_node_block(scene_text: str, node_name: str, node_type: str) -> str:
    pattern = rf'(\[node name="{re.escape(node_name)}" type="{re.escape(node_type)}"[^\n]*\](?:\n(?!\[node ).*)*)'
    match = re.search(pattern, scene_text)
    return match.group(1) if match else ""


def script_has_function(script_text: str, function_name: str) -> bool:
    pattern = rf"^\s*(?:static\s+)?func\s+{re.escape(function_name)}\s*\("
    return re.search(pattern, script_text, flags=re.MULTILINE) is not None


def ensure_script_functions(script_text: str, errors: list[str], label: str, function_names: list[str]) -> None:
    for function_name in function_names:
        ensure(script_has_function(script_text, function_name), errors, f"{label} is missing required function: {function_name}")


def ensure_scene_nodes(scene_text: str, errors: list[str], label: str, nodes: list[tuple[str, str]]) -> None:
    for node_name, node_type in nodes:
        ensure(scene_has_node(scene_text, node_name, node_type), errors, f"{label} must define {node_name} ({node_type})")


def extract_settings_resolution_options(settings_text: str, errors: list[str]) -> dict[str, tuple[int, int]]:
    default_match = re.search(r'const\s+PRESENTATION_RESOLUTION_DEFAULT\s*:=\s*"([^"]+)"', settings_text)
    ensure(default_match is not None, errors, "SettingsService.gd must declare PRESENTATION_RESOLUTION_DEFAULT")
    default_id = default_match.group(1) if default_match else "1920x1080"
    parse_text = settings_text.replace("PRESENTATION_RESOLUTION_DEFAULT", f'"{default_id}"')
    block_match = re.search(r"const\s+RESOLUTION_OPTIONS\s*:=\s*\[(.*?)\]\s*\n\s*const\s+HELP_TOPICS", parse_text, flags=re.DOTALL)
    ensure(block_match is not None, errors, "SettingsService.gd must declare RESOLUTION_OPTIONS before HELP_TOPICS")
    if block_match is None:
        return {}

    options: dict[str, tuple[int, int]] = {}
    for match in re.finditer(
        r'\{\s*"id":\s*"(?P<id>\d+x\d+)"\s*,\s*"label":\s*"[^"]+"\s*,\s*"width":\s*(?P<width>\d+)\s*,\s*"height":\s*(?P<height>\d+)',
        block_match.group(1),
        flags=re.DOTALL,
    ):
        option_id = match.group("id")
        width = int(match.group("width"))
        height = int(match.group("height"))
        ensure(option_id not in options, errors, f"SettingsService.gd repeats resolution option {option_id}")
        options[option_id] = (width, height)
    ensure(bool(options), errors, "SettingsService.gd must expose parseable resolution options")
    return options


def validate_field_objectives(errors: list[str], owner_label: str, objectives: object, allow_partial: bool = False) -> list[str]:
    objective_ids: list[str] = []
    ensure(isinstance(objectives, list) and bool(objectives), errors, f"{owner_label} must define a non-empty field_objectives list")
    if not isinstance(objectives, list):
        return objective_ids
    for objective in objectives:
        ensure(isinstance(objective, dict), errors, f"{owner_label} contains a non-dict field objective")
        if not isinstance(objective, dict):
            continue
        objective_id = str(objective.get("id", ""))
        objective_type = str(objective.get("type", ""))
        ensure(bool(objective_id), errors, f"{owner_label} field objectives must define id")
        ensure(objective_id not in objective_ids, errors, f"{owner_label} repeats field objective id {objective_id}")
        append_unique(objective_ids, objective_id)
        if allow_partial:
            if "type" in objective:
                ensure(objective_type in SUPPORTED_FIELD_OBJECTIVE_TYPES, errors, f"{owner_label} uses unsupported field objective type {objective_type}")
            if "label" in objective:
                ensure(bool(str(objective.get("label", ""))), errors, f"{owner_label} field objective {objective_id} must define label when label is present")
            if "summary" in objective:
                ensure(bool(str(objective.get("summary", ""))), errors, f"{owner_label} field objective {objective_id} must define summary when summary is present")
            if "starting_side" in objective:
                ensure(str(objective.get("starting_side", "neutral")) in {"player", "enemy", "neutral"}, errors, f"{owner_label} field objective {objective_id} must use a supported starting_side")
            if "capture_threshold" in objective:
                ensure(int(objective.get("capture_threshold", 0)) > 0, errors, f"{owner_label} field objective {objective_id} must define capture_threshold > 0 when present")
            if "urgency_round" in objective:
                ensure(int(objective.get("urgency_round", 0)) > 0, errors, f"{owner_label} field objective {objective_id} must define urgency_round > 0 when present")
            if "pressure_tags" in objective:
                pressure_tags = objective.get("pressure_tags", [])
                ensure(isinstance(pressure_tags, list) and bool(pressure_tags), errors, f"{owner_label} field objective {objective_id} must define non-empty pressure_tags when present")
                if isinstance(pressure_tags, list):
                    for pressure_tag in pressure_tags:
                        ensure(str(pressure_tag) in SUPPORTED_FIELD_OBJECTIVE_PRESSURE_TAGS, errors, f"{owner_label} field objective {objective_id} uses unsupported pressure tag {pressure_tag}")
        else:
            ensure(objective_type in SUPPORTED_FIELD_OBJECTIVE_TYPES, errors, f"{owner_label} uses unsupported field objective type {objective_type}")
            ensure(bool(str(objective.get("label", ""))), errors, f"{owner_label} field objective {objective_id} must define label")
            ensure(bool(str(objective.get("summary", ""))), errors, f"{owner_label} field objective {objective_id} must define summary")
            ensure(str(objective.get("starting_side", "neutral")) in {"player", "enemy", "neutral"}, errors, f"{owner_label} field objective {objective_id} must use a supported starting_side")
            ensure(int(objective.get("capture_threshold", 0)) > 0, errors, f"{owner_label} field objective {objective_id} must define capture_threshold > 0")
            ensure(int(objective.get("urgency_round", 0)) > 0, errors, f"{owner_label} field objective {objective_id} must define urgency_round > 0")
            pressure_tags = objective.get("pressure_tags", [])
            ensure(isinstance(pressure_tags, list) and bool(pressure_tags), errors, f"{owner_label} field objective {objective_id} must define non-empty pressure_tags")
            if isinstance(pressure_tags, list):
                for pressure_tag in pressure_tags:
                    ensure(str(pressure_tag) in SUPPORTED_FIELD_OBJECTIVE_PRESSURE_TAGS, errors, f"{owner_label} field objective {objective_id} uses unsupported pressure tag {pressure_tag}")
    return objective_ids


def discover_content_files(errors: list[str]) -> dict[str, Path]:
    ensure(CONTENT_SERVICE_PATH.exists(), errors, f"Missing content service script: {CONTENT_SERVICE_PATH.relative_to(ROOT)}")
    if not CONTENT_SERVICE_PATH.exists():
        return {}

    script_text = CONTENT_SERVICE_PATH.read_text(encoding="utf-8")
    matches = re.findall(r'const\s+[A-Z_]+_PATH\s*:=\s*"%s/([^"]+\.json)"\s*%\s*CONTENT_DIR', script_text)
    ensure(bool(matches), errors, "ContentService.gd does not declare any JSON content paths")
    return {Path(filename).stem: CONTENT_DIR / filename for filename in matches}


def validate_script_condition(
    errors: list[str],
    scenario_id: str,
    hook_id: str,
    condition: dict,
    factions: dict[str, dict],
    town_placement_ids: list[str],
    encounter_placement_ids: list[str],
    objective_ids: list[str],
) -> None:
    condition_type = str(condition.get("type", ""))
    if condition_type == "day_at_least":
        ensure(int(condition.get("day", 0)) > 0, errors, f"Scenario {scenario_id} hook {hook_id} must define day > 0")
    elif condition_type in {"town_owned_by_player", "town_not_owned_by_player"}:
        ensure(str(condition.get("placement_id", "")) in town_placement_ids, errors, f"Scenario {scenario_id} hook {hook_id} references missing town placement {condition.get('placement_id')}")
    elif condition_type in {"flag_true", "session_flag_equals"}:
        ensure(bool(str(condition.get("flag", ""))), errors, f"Scenario {scenario_id} hook {hook_id} must define a flag for {condition_type}")
    elif condition_type == "enemy_pressure_at_least":
        ensure(str(condition.get("faction_id", "")) in factions, errors, f"Scenario {scenario_id} hook {hook_id} references missing faction {condition.get('faction_id')}")
        ensure(int(condition.get("threshold", 0)) > 0, errors, f"Scenario {scenario_id} hook {hook_id} must define threshold > 0")
    elif condition_type == "encounter_resolved":
        ensure(str(condition.get("placement_id", "")) in encounter_placement_ids, errors, f"Scenario {scenario_id} hook {hook_id} references missing encounter placement {condition.get('placement_id')}")
    elif condition_type == "objective_met":
        ensure(str(condition.get("objective_id", "")) in objective_ids, errors, f"Scenario {scenario_id} hook {hook_id} references missing objective {condition.get('objective_id')}")
    elif condition_type == "objective_not_met":
        ensure(str(condition.get("objective_id", "")) in objective_ids, errors, f"Scenario {scenario_id} hook {hook_id} references missing objective {condition.get('objective_id')}")
    elif condition_type in {"active_raid_count_at_least", "active_raid_count_at_most"}:
        ensure(str(condition.get("faction_id", "")) in factions, errors, f"Scenario {scenario_id} hook {hook_id} references missing faction {condition.get('faction_id')}")
        ensure(int(condition.get("threshold", 0)) >= 0, errors, f"Scenario {scenario_id} hook {hook_id} must define threshold >= 0")
    elif condition_type in {"hook_fired", "hook_not_fired"}:
        ensure(bool(str(condition.get("hook_id", ""))), errors, f"Scenario {scenario_id} hook {hook_id} must define hook_id for {condition_type}")
    else:
        fail(errors, f"Scenario {scenario_id} hook {hook_id} has unsupported condition type {condition_type}")


def validate_script_placement(
    errors: list[str],
    scenario_id: str,
    hook_id: str,
    placement: object,
    reference_key: str,
    reference_index: dict[str, dict],
    width: int,
    height: int,
) -> None:
    ensure(isinstance(placement, dict), errors, f"Scenario {scenario_id} hook {hook_id} must define a placement dictionary")
    if not isinstance(placement, dict):
        return
    ensure(bool(str(placement.get("placement_id", ""))), errors, f"Scenario {scenario_id} hook {hook_id} scripted placements must define placement_id")
    ensure(str(placement.get(reference_key, "")) in reference_index, errors, f"Scenario {scenario_id} hook {hook_id} references missing {reference_key} {placement.get(reference_key)}")
    x = int(placement.get("x", -1))
    y = int(placement.get("y", -1))
    ensure(0 <= x < width and 0 <= y < height, errors, f"Scenario {scenario_id} hook {hook_id} placement {placement.get('placement_id')} is out of bounds")


def validate_script_effect(
    errors: list[str],
    scenario_id: str,
    hook_id: str,
    effect: dict,
    factions: dict[str, dict],
    units: dict[str, dict],
    buildings: dict[str, dict],
    resource_sites: dict[str, dict],
    artifacts: dict[str, dict],
    encounters: dict[str, dict],
    town_placement_ids: list[str],
    width: int,
    height: int,
) -> None:
    effect_type = str(effect.get("type", ""))
    if effect_type == "message":
        ensure(bool(str(effect.get("text", ""))), errors, f"Scenario {scenario_id} hook {hook_id} message effects must define text")
    elif effect_type == "set_flag":
        ensure(bool(str(effect.get("flag", ""))), errors, f"Scenario {scenario_id} hook {hook_id} set_flag effects must define flag")
    elif effect_type == "add_resources":
        resources = effect.get("resources", {})
        ensure(isinstance(resources, dict) and bool(resources), errors, f"Scenario {scenario_id} hook {hook_id} add_resources effects must define resources")
    elif effect_type == "award_experience":
        ensure(int(effect.get("amount", 0)) > 0, errors, f"Scenario {scenario_id} hook {hook_id} award_experience effects must define amount > 0")
    elif effect_type == "award_artifact":
        ensure(str(effect.get("artifact_id", "")) in artifacts, errors, f"Scenario {scenario_id} hook {hook_id} references missing artifact {effect.get('artifact_id')}")
    elif effect_type == "spawn_resource_node":
        validate_script_placement(errors, scenario_id, hook_id, effect.get("placement", {}), "site_id", resource_sites, width, height)
    elif effect_type == "spawn_artifact_node":
        validate_script_placement(errors, scenario_id, hook_id, effect.get("placement", {}), "artifact_id", artifacts, width, height)
    elif effect_type == "spawn_encounter":
        validate_script_placement(errors, scenario_id, hook_id, effect.get("placement", {}), "encounter_id", encounters, width, height)
    elif effect_type == "town_add_building":
        ensure(str(effect.get("placement_id", "")) in town_placement_ids, errors, f"Scenario {scenario_id} hook {hook_id} references missing town placement {effect.get('placement_id')}")
        ensure(str(effect.get("building_id", "")) in buildings, errors, f"Scenario {scenario_id} hook {hook_id} references missing building {effect.get('building_id')}")
    elif effect_type == "town_add_recruits":
        ensure(str(effect.get("placement_id", "")) in town_placement_ids, errors, f"Scenario {scenario_id} hook {hook_id} references missing town placement {effect.get('placement_id')}")
        recruits = effect.get("recruits", {})
        ensure(isinstance(recruits, dict) and bool(recruits), errors, f"Scenario {scenario_id} hook {hook_id} town_add_recruits effects must define recruits")
        if isinstance(recruits, dict):
            for unit_id, amount in recruits.items():
                ensure(str(unit_id) in units, errors, f"Scenario {scenario_id} hook {hook_id} references missing recruit unit {unit_id}")
                ensure(int(amount) > 0, errors, f"Scenario {scenario_id} hook {hook_id} recruit count must be > 0 for {unit_id}")
    elif effect_type == "add_enemy_pressure":
        ensure(str(effect.get("faction_id", "")) in factions, errors, f"Scenario {scenario_id} hook {hook_id} references missing faction {effect.get('faction_id')}")
        ensure(int(effect.get("amount", 0)) > 0 or int(effect.get("minimum", 0)) > 0, errors, f"Scenario {scenario_id} hook {hook_id} add_enemy_pressure must define amount > 0 or minimum > 0")
    else:
        fail(errors, f"Scenario {scenario_id} hook {hook_id} has unsupported effect type {effect_type}")


def validate_campaigns(errors: list[str], campaigns: dict[str, dict], scenarios: dict[str, dict]) -> None:
    ensure(bool(campaigns), errors, "No campaigns are authored in content/campaigns.json")
    ensure(len(campaigns) >= 3, errors, "Release-facing campaign content must author at least three campaign arcs")
    total_campaign_chapters = 0
    campaign_starting_factions: set[str] = set()
    for campaign_id, campaign in campaigns.items():
        ensure(bool(str(campaign.get("summary", ""))), errors, f"Campaign {campaign_id} must define summary")
        ensure(bool(str(campaign.get("region", ""))), errors, f"Campaign {campaign_id} must define region")
        ensure(bool(str(campaign.get("arc_goal", ""))), errors, f"Campaign {campaign_id} must define arc_goal")
        ensure(bool(str(campaign.get("completion_title", ""))), errors, f"Campaign {campaign_id} must define completion_title")
        ensure(bool(str(campaign.get("completion_summary", ""))), errors, f"Campaign {campaign_id} must define completion_summary")
        scenario_entries = campaign.get("scenarios", [])
        ensure(isinstance(scenario_entries, list) and bool(scenario_entries), errors, f"Campaign {campaign_id} must define at least one scenario entry")
        if not isinstance(scenario_entries, list):
            continue
        ensure(len(scenario_entries) >= 3, errors, f"Campaign {campaign_id} must define at least three authored chapters for release-facing breadth")
        total_campaign_chapters += len(scenario_entries)

        listed_scenario_ids: list[str] = []
        entry_by_scenario_id: dict[str, dict] = {}
        chapter_indices: list[int] = []
        for scenario_entry in scenario_entries:
            ensure(isinstance(scenario_entry, dict), errors, f"Campaign {campaign_id} contains a non-dict scenario entry")
            if not isinstance(scenario_entry, dict):
                continue
            scenario_id = str(scenario_entry.get("scenario_id", ""))
            ensure(scenario_id in scenarios, errors, f"Campaign {campaign_id} references missing scenario {scenario_id}")
            ensure(scenario_id not in listed_scenario_ids, errors, f"Campaign {campaign_id} repeats scenario {scenario_id}")
            chapter_index = int(scenario_entry.get("chapter_index", 0))
            ensure(chapter_index > 0, errors, f"Campaign {campaign_id} scenario {scenario_id} must define chapter_index > 0")
            ensure(chapter_index not in chapter_indices, errors, f"Campaign {campaign_id} repeats chapter_index {chapter_index}")
            ensure(bool(str(scenario_entry.get("chapter_title", ""))), errors, f"Campaign {campaign_id} scenario {scenario_id} must define chapter_title")
            ensure(bool(str(scenario_entry.get("status_hint", ""))), errors, f"Campaign {campaign_id} scenario {scenario_id} must define status_hint")
            ensure(bool(str(scenario_entry.get("carryover_summary", ""))), errors, f"Campaign {campaign_id} scenario {scenario_id} must define carryover_summary")
            ensure(bool(str(scenario_entry.get("briefing", ""))), errors, f"Campaign {campaign_id} scenario {scenario_id} must define briefing")
            ensure(bool(str(scenario_entry.get("intel", ""))), errors, f"Campaign {campaign_id} scenario {scenario_id} must define intel")
            ensure(bool(str(scenario_entry.get("stakes", ""))), errors, f"Campaign {campaign_id} scenario {scenario_id} must define stakes")
            ensure(bool(str(scenario_entry.get("aftermath_victory", ""))), errors, f"Campaign {campaign_id} scenario {scenario_id} must define aftermath_victory")
            ensure(bool(str(scenario_entry.get("aftermath_defeat", ""))), errors, f"Campaign {campaign_id} scenario {scenario_id} must define aftermath_defeat")
            ensure(bool(str(scenario_entry.get("journal_victory", ""))), errors, f"Campaign {campaign_id} scenario {scenario_id} must define journal_victory")
            ensure(bool(str(scenario_entry.get("journal_defeat", ""))), errors, f"Campaign {campaign_id} scenario {scenario_id} must define journal_defeat")
            if scenario_id and scenario_id in scenarios and scenario_id not in listed_scenario_ids:
                listed_scenario_ids.append(scenario_id)
                entry_by_scenario_id[scenario_id] = scenario_entry
            if chapter_index > 0 and chapter_index not in chapter_indices:
                chapter_indices.append(chapter_index)

        starting_scenario_id = str(campaign.get("starting_scenario_id", ""))
        ensure(starting_scenario_id in listed_scenario_ids, errors, f"Campaign {campaign_id} starting_scenario_id {starting_scenario_id} is not listed in campaign scenarios")
        if starting_scenario_id in scenarios:
            campaign_starting_factions.add(str(scenarios[starting_scenario_id].get("player_faction_id", "")))
        starting_entry = entry_by_scenario_id.get(starting_scenario_id, {})
        if starting_entry:
            ensure(bool(starting_entry.get("starts_unlocked", False)), errors, f"Campaign {campaign_id} starting scenario {starting_scenario_id} must start unlocked")
        ensure(
            sorted(chapter_indices) == list(range(1, len(chapter_indices) + 1)),
            errors,
            f"Campaign {campaign_id} chapter_index values must form a contiguous sequence starting at 1",
        )

        for scenario_entry in scenario_entries:
            if not isinstance(scenario_entry, dict):
                continue
            scenario_id = str(scenario_entry.get("scenario_id", "<unknown>"))

            unlock_requirements = scenario_entry.get("unlock_requirements", [])
            if "unlock_requirements" in scenario_entry:
                ensure(isinstance(unlock_requirements, list), errors, f"Campaign {campaign_id} scenario {scenario_id} unlock_requirements must be a list")
            if isinstance(unlock_requirements, list):
                for requirement in unlock_requirements:
                    ensure(isinstance(requirement, dict), errors, f"Campaign {campaign_id} scenario {scenario_id} contains a non-dict unlock requirement")
                    if not isinstance(requirement, dict):
                        continue
                    requirement_type = str(requirement.get("type", ""))
                    dependency_id = str(requirement.get("scenario_id", ""))
                    if requirement_type == "scenario_status":
                        ensure(dependency_id in listed_scenario_ids, errors, f"Campaign {campaign_id} scenario {scenario_id} references missing unlock dependency {dependency_id}")
                        ensure(str(requirement.get("status", "")) in {"victory", "defeat"}, errors, f"Campaign {campaign_id} scenario {scenario_id} uses unsupported unlock status {requirement.get('status')}")
                    elif requirement_type == "scenario_flag_true":
                        ensure(dependency_id in listed_scenario_ids, errors, f"Campaign {campaign_id} scenario {scenario_id} references missing flag dependency scenario {dependency_id}")
                        ensure(bool(str(requirement.get("flag", ""))), errors, f"Campaign {campaign_id} scenario {scenario_id} scenario_flag_true requirements must define a flag")
                    else:
                        fail(errors, f"Campaign {campaign_id} scenario {scenario_id} uses unsupported unlock requirement type {requirement_type}")

            carryover_export = scenario_entry.get("carryover_export", {})
            if "carryover_export" in scenario_entry:
                ensure(isinstance(carryover_export, dict), errors, f"Campaign {campaign_id} scenario {scenario_id} carryover_export must be a dictionary")
            if isinstance(carryover_export, dict):
                resource_fraction = float(carryover_export.get("resource_fraction", 0.0))
                ensure(0.0 <= resource_fraction <= 1.0, errors, f"Campaign {campaign_id} scenario {scenario_id} carryover_export resource_fraction must be between 0 and 1")
                resource_caps = carryover_export.get("resource_caps", {})
                if "resource_caps" in carryover_export:
                    ensure(isinstance(resource_caps, dict), errors, f"Campaign {campaign_id} scenario {scenario_id} carryover_export resource_caps must be a dictionary")
                if isinstance(resource_caps, dict):
                    for resource_key, amount in resource_caps.items():
                        ensure(int(amount) >= 0, errors, f"Campaign {campaign_id} scenario {scenario_id} carryover_export resource cap must be >= 0 for {resource_key}")
                flag_ids = carryover_export.get("flag_ids", [])
                if "flag_ids" in carryover_export:
                    ensure(isinstance(flag_ids, list), errors, f"Campaign {campaign_id} scenario {scenario_id} carryover_export flag_ids must be a list")
                if isinstance(flag_ids, list):
                    for flag_id in flag_ids:
                        ensure(bool(str(flag_id)), errors, f"Campaign {campaign_id} scenario {scenario_id} carryover_export cannot contain empty flag ids")

            carryover_import = scenario_entry.get("carryover_import", {})
            if "carryover_import" in scenario_entry:
                ensure(isinstance(carryover_import, dict), errors, f"Campaign {campaign_id} scenario {scenario_id} carryover_import must be a dictionary")
            if isinstance(carryover_import, dict) and carryover_import:
                from_scenario_id = str(carryover_import.get("from_scenario_id", ""))
                ensure(from_scenario_id in listed_scenario_ids, errors, f"Campaign {campaign_id} scenario {scenario_id} carryover_import references missing from_scenario_id {from_scenario_id}")
                ensure(from_scenario_id != scenario_id, errors, f"Campaign {campaign_id} scenario {scenario_id} cannot import carryover from itself")
                if "flags_prefix" in carryover_import:
                    ensure(bool(str(carryover_import.get("flags_prefix", ""))), errors, f"Campaign {campaign_id} scenario {scenario_id} carryover_import flags_prefix cannot be empty")
    ensure(total_campaign_chapters >= 9, errors, "Campaign content should author at least nine chapters across the available campaign arcs")
    ensure(RELEASE_PLAYER_FACTIONS.issubset(campaign_starting_factions), errors, "Campaign starts must cover all release player factions")


def validate_content(errors: list[str]) -> None:
    required = discover_content_files(errors)
    expected_domains = {
        "factions",
        "heroes",
        "units",
        "army_groups",
        "towns",
        "buildings",
        "resource_sites",
        "biomes",
        "terrain_grammar",
        "terrain_layers",
        "map_objects",
        "neutral_dwellings",
        "artifacts",
        "spells",
        "encounters",
        "scenarios",
        "campaigns",
    }
    for domain in sorted(expected_domains):
        ensure(domain in required, errors, f"ContentService.gd is missing expected content path for {domain}")

    payloads = {}
    for key, path in required.items():
        ensure(path.exists(), errors, f"Missing content file: {path.relative_to(ROOT)}")
        if path.exists():
            payloads[key] = load_json(path)

    if errors:
        return

    factions = items_index(payloads["factions"])
    heroes = items_index(payloads["heroes"])
    units = items_index(payloads["units"])
    army_groups = items_index(payloads["army_groups"])
    towns = items_index(payloads["towns"])
    buildings = items_index(payloads["buildings"])
    resource_sites = items_index(payloads["resource_sites"])
    biomes = items_index(payloads["biomes"])
    map_objects = items_index(payloads["map_objects"])
    neutral_dwellings = items_index(payloads["neutral_dwellings"])
    artifacts = items_index(payloads["artifacts"])
    spells = items_index(payloads["spells"])
    encounters = items_index(payloads["encounters"])
    scenarios = items_index(payloads["scenarios"])
    campaigns = items_index(payloads["campaigns"])
    ensure(len(heroes) >= 9, errors, "Release hero content must author at least nine commanders")
    ensure(len(scenarios) >= 10, errors, "Release scenario content must author at least ten distinct fronts")
    campaign_scenario_ids = {
        str(scenario_entry.get("scenario_id", ""))
        for campaign in campaigns.values()
        for scenario_entry in campaign.get("scenarios", [])
        if isinstance(scenario_entry, dict) and str(scenario_entry.get("scenario_id", ""))
    }
    skirmish_scenario_ids: list[str] = []
    skirmish_only_scenario_ids: list[str] = []
    scenario_player_factions: set[str] = set()
    scenario_hero_ids: set[str] = set()
    authored_unit_ability_ids: set[str] = set()

    for faction_id, faction in factions.items():
        ensure(bool(str(faction.get("identity_summary", ""))), errors, f"Faction {faction_id} must define identity_summary")
        for town_id in faction.get("town_ids", []):
            ensure(str(town_id) in towns, errors, f"Faction {faction_id} references missing town {town_id}")
        for hero_id in faction.get("hero_ids", []):
            ensure(str(hero_id) in heroes, errors, f"Faction {faction_id} references missing hero {hero_id}")
        economy = faction.get("economy", {})
        ensure(isinstance(economy, dict) and bool(economy), errors, f"Faction {faction_id} must define an economy profile")
        if isinstance(economy, dict):
            base_income = economy.get("base_income", {})
            ensure(isinstance(base_income, dict), errors, f"Faction {faction_id} economy base_income must be a dictionary")
            if "pressure_bonus" in economy:
                ensure(int(economy.get("pressure_bonus", 0)) >= 0, errors, f"Faction {faction_id} economy pressure_bonus must be >= 0")
            per_category_income = economy.get("per_category_income", {})
            ensure(isinstance(per_category_income, dict) and bool(per_category_income), errors, f"Faction {faction_id} economy must define per_category_income")
            if isinstance(per_category_income, dict):
                for category, resources in per_category_income.items():
                    ensure(str(category) in SUPPORTED_BUILDING_CATEGORIES, errors, f"Faction {faction_id} economy uses unsupported building category {category}")
                    ensure(isinstance(resources, dict) and bool(resources), errors, f"Faction {faction_id} economy category {category} must define resource income")
        recruitment = faction.get("recruitment", {})
        ensure(isinstance(recruitment, dict) and bool(recruitment), errors, f"Faction {faction_id} must define a recruitment profile")
        if isinstance(recruitment, dict):
            if "readiness_bonus" in recruitment:
                ensure(int(recruitment.get("readiness_bonus", 0)) >= 0, errors, f"Faction {faction_id} recruitment readiness_bonus must be >= 0")
            growth_bonus = recruitment.get("growth_bonus", {})
            ensure(isinstance(growth_bonus, dict) and bool(growth_bonus), errors, f"Faction {faction_id} recruitment must define growth_bonus")
            if isinstance(growth_bonus, dict):
                for unit_id, amount in growth_bonus.items():
                    ensure(str(unit_id) in units, errors, f"Faction {faction_id} recruitment references missing growth unit {unit_id}")
                    ensure(int(amount) > 0, errors, f"Faction {faction_id} recruitment growth bonus must be > 0 for {unit_id}")
            discounts = recruitment.get("cost_discount_percent", {})
            ensure(isinstance(discounts, dict) and bool(discounts), errors, f"Faction {faction_id} recruitment must define cost_discount_percent")
            if isinstance(discounts, dict):
                for unit_id, amount in discounts.items():
                    ensure(str(unit_id) in units, errors, f"Faction {faction_id} recruitment references missing discount unit {unit_id}")
                    ensure(0 < int(amount) < 100, errors, f"Faction {faction_id} recruitment discount must be between 1 and 99 for {unit_id}")
        if faction_id in RELEASE_PLAYER_FACTIONS:
            ensure(len([str(value) for value in faction.get("hero_ids", [])]) >= 4, errors, f"Faction {faction_id} must author at least four playable heroes for release-facing roster depth")
            enemy_strategy = faction.get("enemy_strategy", {})
            ensure(isinstance(enemy_strategy, dict) and bool(enemy_strategy), errors, f"Faction {faction_id} must define enemy_strategy for hostile-empire personality")
            if isinstance(enemy_strategy, dict):
                for section, required_keys in ENEMY_STRATEGY_KEYS.items():
                    bucket = enemy_strategy.get(section, {})
                    ensure(isinstance(bucket, dict) and bool(bucket), errors, f"Faction {faction_id} enemy_strategy must define non-empty {section}")
                    if isinstance(bucket, dict):
                        for key in required_keys:
                            ensure(key in bucket, errors, f"Faction {faction_id} enemy_strategy {section} is missing {key}")

    for hero_id, hero in heroes.items():
        faction_id = str(hero.get("faction_id", ""))
        ensure(faction_id in factions, errors, f"Hero {hero_id} references missing faction")
        if faction_id in factions:
            ensure(hero_id in [str(value) for value in factions[faction_id].get("hero_ids", [])], errors, f"Hero {hero_id} must be listed in faction {faction_id} hero_ids")
        ensure(bool(str(hero.get("roster_summary", ""))), errors, f"Hero {hero_id} must define roster_summary")
        ensure(bool(str(hero.get("identity_summary", ""))), errors, f"Hero {hero_id} must define identity_summary")
        ensure(int(hero.get("base_movement", 0)) > 0, errors, f"Hero {hero_id} must define base_movement > 0")
        recruit_cost = hero.get("recruit_cost", {})
        if "recruit_cost" in hero:
            ensure(isinstance(recruit_cost, dict), errors, f"Hero {hero_id} recruit_cost must be a dictionary")
        if isinstance(recruit_cost, dict):
            for resource_key, amount in recruit_cost.items():
                ensure(bool(str(resource_key)), errors, f"Hero {hero_id} recruit_cost cannot contain an empty resource key")
                ensure(int(amount) >= 0, errors, f"Hero {hero_id} recruit_cost must be >= 0 for {resource_key}")
        starting_specialties = hero.get("starting_specialties", [])
        ensure(isinstance(starting_specialties, list) and bool(starting_specialties), errors, f"Hero {hero_id} must define non-empty starting_specialties")
        if isinstance(starting_specialties, list):
            for specialty_id in starting_specialties:
                ensure(str(specialty_id) in VALID_SPECIALTY_IDS, errors, f"Hero {hero_id} uses unsupported starting specialty {specialty_id}")
        specialty_focus_ids = hero.get("specialty_focus_ids", [])
        ensure(isinstance(specialty_focus_ids, list) and len(specialty_focus_ids) >= 2, errors, f"Hero {hero_id} must define at least two specialty_focus_ids")
        if isinstance(specialty_focus_ids, list):
            for specialty_id in specialty_focus_ids:
                ensure(str(specialty_id) in VALID_SPECIALTY_IDS, errors, f"Hero {hero_id} uses unsupported specialty focus {specialty_id}")
        battle_traits = hero.get("battle_traits", [])
        ensure(isinstance(battle_traits, list) and bool(battle_traits), errors, f"Hero {hero_id} must define non-empty battle_traits")
        if isinstance(battle_traits, list):
            for trait_id in battle_traits:
                ensure(str(trait_id) in VALID_BATTLE_TRAIT_IDS, errors, f"Hero {hero_id} uses unsupported battle trait {trait_id}")
        for spell_id in hero.get("starting_spell_ids", []):
            ensure(str(spell_id) in spells, errors, f"Hero {hero_id} references missing starting spell {spell_id}")

    for unit_id, unit in units.items():
        if is_neutral_unit(unit):
            ensure(str(unit.get("faction_id", "")) == "", errors, f"Neutral unit {unit_id} must not belong to a faction ladder")
            ensure(str(unit.get("content_status", "")) == "neutral_dwelling_slice", errors, f"Neutral unit {unit_id} must be marked as neutral_dwelling_slice")
        else:
            ensure(str(unit.get("faction_id", "")) in factions, errors, f"Unit {unit_id} references missing faction")
        ensure(int(unit.get("hp", 0)) > 0, errors, f"Unit {unit_id} must define hp > 0")
        ensure(int(unit.get("max_damage", 0)) >= int(unit.get("min_damage", 0)) > 0, errors, f"Unit {unit_id} has invalid damage range")
        role = str(unit.get("role", ""))
        ensure(role in {"melee", "ranged"}, errors, f"Unit {unit_id} uses unsupported role {role}")
        if bool(unit.get("ranged", False)):
            ensure(int(unit.get("shots", 0)) > 0, errors, f"Ranged unit {unit_id} must define shots > 0")

        abilities = unit.get("abilities", [])
        if "abilities" in unit:
            ensure(isinstance(abilities, list) and bool(abilities), errors, f"Unit {unit_id} abilities must be a non-empty list when present")
        if isinstance(abilities, list):
            seen_ability_ids: set[str] = set()
            for ability in abilities:
                ensure(isinstance(ability, dict), errors, f"Unit {unit_id} contains a non-dict ability entry")
                if not isinstance(ability, dict):
                    continue
                ability_id = str(ability.get("id", ""))
                ensure(ability_id in SUPPORTED_UNIT_ABILITY_IDS, errors, f"Unit {unit_id} uses unsupported ability {ability_id}")
                ensure(ability_id not in seen_ability_ids, errors, f"Unit {unit_id} repeats ability {ability_id}")
                ensure(bool(str(ability.get("name", ""))), errors, f"Unit {unit_id} ability {ability_id} must define name")
                ensure(bool(str(ability.get("description", ""))), errors, f"Unit {unit_id} ability {ability_id} must define description")
                if ability_id:
                    seen_ability_ids.add(ability_id)
                    authored_unit_ability_ids.add(ability_id)
                if ability_id == "reach":
                    ensure(float(ability.get("distance_one_multiplier", 0.0)) > 0.0, errors, f"Unit {unit_id} reach must define distance_one_multiplier > 0")
                elif ability_id == "brace":
                    ensure(float(ability.get("retaliation_multiplier", 0.0)) >= 1.0, errors, f"Unit {unit_id} brace must define retaliation_multiplier >= 1")
                    ensure(int(ability.get("defending_cohesion_bonus", 0)) > 0, errors, f"Unit {unit_id} brace must define defending_cohesion_bonus > 0")
                    ensure(bool(str(ability.get("status_id", ""))), errors, f"Unit {unit_id} brace must define status_id")
                    ensure(int(ability.get("duration_rounds", 0)) > 0, errors, f"Unit {unit_id} brace must define duration_rounds > 0")
                    modifiers = ability.get("modifiers", {})
                    ensure(isinstance(modifiers, dict) and bool(modifiers), errors, f"Unit {unit_id} brace must define modifiers")
                elif ability_id == "harry":
                    ensure(bool(str(ability.get("status_id", ""))), errors, f"Unit {unit_id} harry must define status_id")
                    ensure(int(ability.get("duration_rounds", 0)) > 0, errors, f"Unit {unit_id} harry must define duration_rounds > 0")
                    modifiers = ability.get("modifiers", {})
                    ensure(isinstance(modifiers, dict) and bool(modifiers), errors, f"Unit {unit_id} harry must define modifiers")
                    ensure(int(ability.get("momentum_gain", 0)) > 0, errors, f"Unit {unit_id} harry must define momentum_gain > 0")
                    if "wounded_threshold_ratio" in ability:
                        ensure(0.0 < float(ability.get("wounded_threshold_ratio", 0.0)) <= 1.0, errors, f"Unit {unit_id} harry wounded_threshold_ratio must be between 0 and 1")
                    if "wounded_damage_multiplier" in ability:
                        ensure(float(ability.get("wounded_damage_multiplier", 0.0)) > 1.0, errors, f"Unit {unit_id} harry wounded_damage_multiplier must be > 1")
                elif ability_id == "backstab":
                    ensure(float(ability.get("damage_multiplier", 0.0)) >= 1.0, errors, f"Unit {unit_id} backstab must define damage_multiplier >= 1")
                    ensure(int(ability.get("momentum_gain", 0)) > 0, errors, f"Unit {unit_id} backstab must define momentum_gain > 0")
                    status_ids = ability.get("status_ids", [])
                    ensure(isinstance(status_ids, list) and bool(status_ids), errors, f"Unit {unit_id} backstab must define status_ids")
                    if "health_threshold_ratio" in ability:
                        ensure(0.0 < float(ability.get("health_threshold_ratio", 0.0)) <= 1.0, errors, f"Unit {unit_id} backstab health_threshold_ratio must be between 0 and 1")
                    if "threshold_damage_multiplier" in ability:
                        ensure(float(ability.get("threshold_damage_multiplier", 0.0)) > 1.0, errors, f"Unit {unit_id} backstab threshold_damage_multiplier must be > 1")
                elif ability_id == "shielding":
                    multiplier = float(ability.get("ranged_damage_multiplier", 0.0))
                    ensure(0.0 < multiplier <= 1.0, errors, f"Unit {unit_id} shielding must define ranged_damage_multiplier between 0 and 1")
                    ensure(int(ability.get("cohesion_hold_bonus", 0)) > 0, errors, f"Unit {unit_id} shielding must define cohesion_hold_bonus > 0")
                    if "engaged_damage_multiplier" in ability:
                        ensure(float(ability.get("engaged_damage_multiplier", 0.0)) > 1.0, errors, f"Unit {unit_id} shielding engaged_damage_multiplier must be > 1")
                    if "harried_damage_multiplier" in ability:
                        ensure(float(ability.get("harried_damage_multiplier", 0.0)) > 1.0, errors, f"Unit {unit_id} shielding harried_damage_multiplier must be > 1")
                elif ability_id == "volley":
                    ensure(float(ability.get("damage_multiplier", 0.0)) > 1.0, errors, f"Unit {unit_id} volley must define damage_multiplier > 1")
                    ensure(int(ability.get("min_distance", 0)) > 0, errors, f"Unit {unit_id} volley must define min_distance > 0")
                    if "status_ids" in ability:
                        ensure(isinstance(ability.get("status_ids", []), list) and bool(ability.get("status_ids", [])), errors, f"Unit {unit_id} volley status_ids must be a non-empty list when present")
                    if "status_damage_multiplier" in ability:
                        ensure(float(ability.get("status_damage_multiplier", 0.0)) > 1.0, errors, f"Unit {unit_id} volley status_damage_multiplier must be > 1")
                    if "ally_defending_multiplier" in ability:
                        ensure(float(ability.get("ally_defending_multiplier", 0.0)) > 1.0, errors, f"Unit {unit_id} volley ally_defending_multiplier must be > 1")
                elif ability_id == "formation_guard":
                    ensure(float(ability.get("ally_ranged_damage_multiplier", 0.0)) > 1.0, errors, f"Unit {unit_id} formation_guard must define ally_ranged_damage_multiplier > 1")
                    ensure(int(ability.get("ally_ranged_initiative_bonus", 0)) > 0, errors, f"Unit {unit_id} formation_guard must define ally_ranged_initiative_bonus > 0")
                    ensure(int(ability.get("ally_cohesion_bonus", 0)) > 0, errors, f"Unit {unit_id} formation_guard must define ally_cohesion_bonus > 0")
                    ensure(int(ability.get("defending_cohesion_bonus", 0)) > 0, errors, f"Unit {unit_id} formation_guard must define defending_cohesion_bonus > 0")
                    ensure(int(ability.get("defending_initiative_bonus", 0)) > 0, errors, f"Unit {unit_id} formation_guard must define defending_initiative_bonus > 0")
                    ensure(float(ability.get("staggered_damage_multiplier", 0.0)) > 1.0, errors, f"Unit {unit_id} formation_guard must define staggered_damage_multiplier > 1")
                elif ability_id == "bloodrush":
                    ensure(0.0 < float(ability.get("wounded_threshold_ratio", 0.0)) <= 1.0, errors, f"Unit {unit_id} bloodrush wounded_threshold_ratio must be between 0 and 1")
                    ensure(float(ability.get("wounded_damage_multiplier", 0.0)) > 1.0, errors, f"Unit {unit_id} bloodrush wounded_damage_multiplier must be > 1")
                    ensure(isinstance(ability.get("status_ids", []), list) and bool(ability.get("status_ids", [])), errors, f"Unit {unit_id} bloodrush must define status_ids")
                    ensure(float(ability.get("status_damage_multiplier", 0.0)) > 1.0, errors, f"Unit {unit_id} bloodrush status_damage_multiplier must be > 1")
                    ensure(int(ability.get("wounded_initiative_bonus", 0)) > 0, errors, f"Unit {unit_id} bloodrush wounded_initiative_bonus must be > 0")
                    ensure(int(ability.get("max_initiative_bonus", 0)) > 0, errors, f"Unit {unit_id} bloodrush max_initiative_bonus must be > 0")
                    ensure(int(ability.get("momentum_gain", 0)) > 0, errors, f"Unit {unit_id} bloodrush momentum_gain must be > 0")
                    ensure(int(ability.get("kill_momentum_gain", 0)) > 0, errors, f"Unit {unit_id} bloodrush kill_momentum_gain must be > 0")
                    ensure(int(ability.get("late_round_initiative_bonus", 0)) > 0, errors, f"Unit {unit_id} bloodrush late_round_initiative_bonus must be > 0")

    ensure(
        {"reach", "brace", "harry", "backstab", "shielding", "volley", "formation_guard", "bloodrush"}.issubset(authored_unit_ability_ids),
        errors,
        "Authored units must cover the combat-depth ability set: reach, brace, harry, backstab, shielding, volley, formation_guard, and bloodrush",
    )

    ember_archer = units.get("unit_ember_archer", {})
    ember_archer_volley = next((ability for ability in ember_archer.get("abilities", []) if isinstance(ability, dict) and str(ability.get("id", "")) == "volley"), {})
    ensure("status_staggered" in [str(value) for value in ember_archer_volley.get("status_ids", [])], errors, "Ember Archer volley must keep its stagger payoff authored")
    ensure(float(ember_archer_volley.get("ally_defending_multiplier", 0.0)) > 1.0, errors, "Ember Archer volley must keep its allied-defender payoff authored")
    ember_archer_harry = next((ability for ability in ember_archer.get("abilities", []) if isinstance(ability, dict) and str(ability.get("id", "")) == "harry"), {})
    ensure(int(ember_archer_harry.get("modifiers", {}).get("cohesion", 0)) < 0, errors, "Ember Archer harry must keep a cohesion-pressure rider authored")
    ensure(int(ember_archer_harry.get("momentum_gain", 0)) > 0, errors, "Ember Archer harry must keep its tempo-gain rider authored")

    cutthroat = units.get("unit_blackbranch_cutthroat", {})
    cutthroat_backstab = next((ability for ability in cutthroat.get("abilities", []) if isinstance(ability, dict) and str(ability.get("id", "")) == "backstab"), {})
    ensure(float(cutthroat_backstab.get("health_threshold_ratio", 0.0)) > 0.0, errors, "Blackbranch Cutthroat backstab must keep a wounded-threshold payoff authored")
    ensure(float(cutthroat_backstab.get("threshold_damage_multiplier", 0.0)) > 1.0, errors, "Blackbranch Cutthroat backstab must keep a wounded-threshold damage multiplier authored")
    ensure(int(cutthroat_backstab.get("momentum_gain", 0)) > 0, errors, "Blackbranch Cutthroat backstab must keep its momentum-gain payoff authored")

    mire_slinger = units.get("unit_mire_slinger", {})
    mire_slinger_harry = next((ability for ability in mire_slinger.get("abilities", []) if isinstance(ability, dict) and str(ability.get("id", "")) == "harry"), {})
    ensure(float(mire_slinger_harry.get("wounded_threshold_ratio", 0.0)) > 0.0, errors, "Mire Slinger harry must keep a wounded-threshold payoff authored")
    ensure(float(mire_slinger_harry.get("wounded_damage_multiplier", 0.0)) > 1.0, errors, "Mire Slinger harry must keep a wounded-target damage multiplier authored")
    ensure(int(mire_slinger_harry.get("modifiers", {}).get("cohesion", 0)) < 0, errors, "Mire Slinger harry must keep a cohesion-pressure rider authored")

    bog_brute = units.get("unit_bog_brute", {})
    bog_brute_shielding = next((ability for ability in bog_brute.get("abilities", []) if isinstance(ability, dict) and str(ability.get("id", "")) == "shielding"), {})
    ensure(float(bog_brute_shielding.get("engaged_damage_multiplier", 0.0)) > 1.0, errors, "Bog Brute shielding must keep its engaged damage payoff authored")
    ensure(float(bog_brute_shielding.get("harried_damage_multiplier", 0.0)) > 1.0, errors, "Bog Brute shielding must keep its harried-target payoff authored")
    ensure(int(bog_brute_shielding.get("cohesion_hold_bonus", 0)) > 0, errors, "Bog Brute shielding must keep its cohesion-hold payoff authored")

    citadel_pikeward = units.get("unit_citadel_pikeward", {})
    pikeward_screen = next((ability for ability in citadel_pikeward.get("abilities", []) if isinstance(ability, dict) and str(ability.get("id", "")) == "formation_guard"), {})
    ensure(float(pikeward_screen.get("ally_ranged_damage_multiplier", 0.0)) > 1.0, errors, "Citadel Pikeward must keep its formation_guard ranged-support payoff authored")
    ensure(int(pikeward_screen.get("ally_ranged_initiative_bonus", 0)) > 0, errors, "Citadel Pikeward must keep its formation_guard initiative payoff authored")
    ensure(int(pikeward_screen.get("ally_cohesion_bonus", 0)) > 0, errors, "Citadel Pikeward must keep its formation_guard cohesion payoff authored")

    gorefen_ripper = units.get("unit_gorefen_ripper", {})
    ripper_bloodrush = next((ability for ability in gorefen_ripper.get("abilities", []) if isinstance(ability, dict) and str(ability.get("id", "")) == "bloodrush"), {})
    ensure(float(ripper_bloodrush.get("wounded_damage_multiplier", 0.0)) > 1.0, errors, "Gorefen Ripper must keep its bloodrush wounded-target payoff authored")
    ensure(int(ripper_bloodrush.get("max_initiative_bonus", 0)) > 0, errors, "Gorefen Ripper must keep its bloodrush initiative payoff authored")
    ensure(int(ripper_bloodrush.get("momentum_gain", 0)) > 0, errors, "Gorefen Ripper must keep its bloodrush momentum payoff authored")

    for group_id, group in army_groups.items():
        if is_neutral_army_group(group):
            ensure(str(group.get("faction_id", "")) == "", errors, f"Neutral army group {group_id} must not declare faction_id")
        else:
            ensure(str(group.get("faction_id", "")) in factions, errors, f"Army group {group_id} references missing faction")
        stacks = group.get("stacks", [])
        ensure(bool(stacks), errors, f"Army group {group_id} must define at least one stack")
        for stack in stacks:
            if not isinstance(stack, dict):
                fail(errors, f"Army group {group_id} contains a non-dict stack entry")
                continue
            unit_id = str(stack.get("unit_id", ""))
            ensure(unit_id in units, errors, f"Army group {group_id} references missing unit {unit_id}")
            if is_neutral_army_group(group) and unit_id in units:
                ensure(is_neutral_unit(units[unit_id]), errors, f"Neutral army group {group_id} stack {unit_id} must use a neutral unit")
            ensure(int(stack.get("count", 0)) > 0, errors, f"Army group {group_id} has non-positive stack count for {unit_id}")

    embercourt_elite_groups = sum(
        1
        for group in army_groups.values()
        if any(isinstance(stack, dict) and str(stack.get("unit_id", "")) == "unit_citadel_pikeward" for stack in group.get("stacks", []))
    )
    ensure(embercourt_elite_groups >= 5, errors, "Release battle identity must keep Citadel Pikewards present across at least five authored army groups")
    mireclaw_elite_groups = sum(
        1
        for group in army_groups.values()
        if any(isinstance(stack, dict) and str(stack.get("unit_id", "")) == "unit_gorefen_ripper" for stack in group.get("stacks", []))
    )
    ensure(mireclaw_elite_groups >= 5, errors, "Release battle identity must keep Gorefen Rippers present across at least five authored army groups")
    ensure("army_lantern_battery" in army_groups, errors, "Release battle variety must keep Lantern Battery authored")
    ensure("army_causeway_phalanx" in army_groups, errors, "Release battle variety must keep Causeway Phalanx authored")
    ensure("army_muckveil_harriers" in army_groups, errors, "Release battle variety must keep Muckveil Harriers authored")
    ensure("army_ripper_vanguard" in army_groups, errors, "Release battle variety must keep Ripper Vanguard authored")

    for building_id, building in buildings.items():
        ensure(str(building.get("category", "")) in SUPPORTED_BUILDING_CATEGORIES, errors, f"Building {building_id} must define a supported category")
        ensure(bool(str(building.get("description", ""))), errors, f"Building {building_id} must define description")
        if "readiness_bonus" in building:
            ensure(int(building.get("readiness_bonus", 0)) > 0, errors, f"Building {building_id} readiness_bonus must be > 0 when present")
        if "pressure_bonus" in building:
            ensure(int(building.get("pressure_bonus", 0)) > 0, errors, f"Building {building_id} pressure_bonus must be > 0 when present")
        unlock_unit_id = str(building.get("unlock_unit_id", ""))
        if unlock_unit_id:
            ensure(unlock_unit_id in units, errors, f"Building {building_id} references missing unlock_unit_id {unlock_unit_id}")
        if "spell_tier" in building:
            ensure(int(building.get("spell_tier", 0)) > 0, errors, f"Building {building_id} must define spell_tier > 0 when present")
        for required_building in building.get("requires", []):
            ensure(str(required_building) in buildings, errors, f"Building {building_id} references missing prerequisite {required_building}")
        upgrade_from = str(building.get("upgrade_from", ""))
        if upgrade_from:
            ensure(upgrade_from in buildings, errors, f"Building {building_id} references missing upgrade_from building {upgrade_from}")
            ensure(upgrade_from != building_id, errors, f"Building {building_id} cannot upgrade from itself")
        growth_bonus = building.get("growth_bonus", {})
        if "growth_bonus" in building:
            ensure(isinstance(growth_bonus, dict), errors, f"Building {building_id} growth_bonus must be a dictionary")
        if isinstance(growth_bonus, dict):
            for unit_id, amount in growth_bonus.items():
                ensure(str(unit_id) in units, errors, f"Building {building_id} growth_bonus references missing unit {unit_id}")
                ensure(int(amount) > 0, errors, f"Building {building_id} growth_bonus must be > 0 for {unit_id}")
        recruit_discount = building.get("recruitment_discount_percent", {})
        if "recruitment_discount_percent" in building:
            ensure(isinstance(recruit_discount, dict) and bool(recruit_discount), errors, f"Building {building_id} recruitment_discount_percent must be a non-empty dictionary")
        if isinstance(recruit_discount, dict):
            for unit_id, amount in recruit_discount.items():
                ensure(str(unit_id) in units, errors, f"Building {building_id} recruitment_discount_percent references missing unit {unit_id}")
                ensure(0 < int(amount) < 100, errors, f"Building {building_id} recruitment discount must be between 1 and 99 for {unit_id}")
    ensure(WAYFARERS_HALL_BUILDING_ID in buildings, errors, f"Missing required hero-command building {WAYFARERS_HALL_BUILDING_ID}")

    for town_id, town in towns.items():
        ensure(str(town.get("faction_id", "")) in factions, errors, f"Town {town_id} references missing faction")
        if str(town.get("faction_id", "")) in factions:
            ensure(town_id in [str(value) for value in factions[str(town.get("faction_id", ""))].get("town_ids", [])], errors, f"Town {town_id} must be listed in faction {town.get('faction_id')} town_ids")
        ensure(bool(str(town.get("identity_summary", ""))), errors, f"Town {town_id} must define identity_summary")
        economy = town.get("economy", {})
        ensure(isinstance(economy, dict) and bool(economy), errors, f"Town {town_id} must define an economy profile")
        if isinstance(economy, dict):
            base_income = economy.get("base_income", {})
            ensure(isinstance(base_income, dict) and bool(base_income), errors, f"Town {town_id} economy must define base_income")
            if "pressure_bonus" in economy:
                ensure(int(economy.get("pressure_bonus", 0)) >= 0, errors, f"Town {town_id} economy pressure_bonus must be >= 0")
            per_category_income = economy.get("per_category_income", {})
            ensure(isinstance(per_category_income, dict), errors, f"Town {town_id} economy per_category_income must be a dictionary")
            if isinstance(per_category_income, dict):
                for category, resources in per_category_income.items():
                    ensure(str(category) in SUPPORTED_BUILDING_CATEGORIES, errors, f"Town {town_id} economy uses unsupported building category {category}")
                    ensure(isinstance(resources, dict) and bool(resources), errors, f"Town {town_id} economy category {category} must define resource income")
        recruitment = town.get("recruitment", {})
        ensure(isinstance(recruitment, dict) and bool(recruitment), errors, f"Town {town_id} must define a recruitment profile")
        if isinstance(recruitment, dict):
            if "readiness_bonus" in recruitment:
                ensure(int(recruitment.get("readiness_bonus", 0)) >= 0, errors, f"Town {town_id} recruitment readiness_bonus must be >= 0")
            growth_bonus = recruitment.get("growth_bonus", {})
            ensure(isinstance(growth_bonus, dict) and bool(growth_bonus), errors, f"Town {town_id} recruitment must define growth_bonus")
            if isinstance(growth_bonus, dict):
                for unit_id, amount in growth_bonus.items():
                    ensure(str(unit_id) in units, errors, f"Town {town_id} recruitment references missing growth unit {unit_id}")
                    ensure(int(amount) > 0, errors, f"Town {town_id} recruitment growth bonus must be > 0 for {unit_id}")
            discounts = recruitment.get("cost_discount_percent", {})
            ensure(isinstance(discounts, dict) and bool(discounts), errors, f"Town {town_id} recruitment must define cost_discount_percent")
            if isinstance(discounts, dict):
                for unit_id, amount in discounts.items():
                    ensure(str(unit_id) in units, errors, f"Town {town_id} recruitment references missing discount unit {unit_id}")
                    ensure(0 < int(amount) < 100, errors, f"Town {town_id} recruitment discount must be between 1 and 99 for {unit_id}")
        town_building_ids = [str(value) for value in town.get("starting_building_ids", [])] + [str(value) for value in town.get("buildable_building_ids", [])]
        for building_id in town.get("starting_building_ids", []):
            ensure(str(building_id) in buildings, errors, f"Town {town_id} references missing starting building {building_id}")
        for building_id in town.get("buildable_building_ids", []):
            ensure(str(building_id) in buildings, errors, f"Town {town_id} references missing buildable building {building_id}")
        unlockable_unit_ids: list[str] = []
        for building_id in town_building_ids:
            building = buildings.get(building_id, {})
            unlock_unit_id = str(building.get("unlock_unit_id", ""))
            if unlock_unit_id:
                append_unique(unlockable_unit_ids, unlock_unit_id)
                ensure(str(units.get(unlock_unit_id, {}).get("faction_id", "")) == str(town.get("faction_id", "")), errors, f"Town {town_id} unlocks unit {unlock_unit_id} from a different faction")
            upgrade_from = str(building.get("upgrade_from", ""))
            if upgrade_from:
                ensure(upgrade_from in town_building_ids, errors, f"Town {town_id} cannot progress into {building_id} because upgrade_from {upgrade_from} is missing from its build tree")
            for requirement in building.get("requires", []):
                ensure(str(requirement) in town_building_ids, errors, f"Town {town_id} cannot satisfy {building_id} prerequisite {requirement} within its authored build tree")
        ensure(bool(unlockable_unit_ids), errors, f"Town {town_id} must offer at least one authored dwelling unit")
        for stack in town.get("garrison", []):
            if not isinstance(stack, dict):
                fail(errors, f"Town {town_id} contains a non-dict garrison entry")
                continue
            ensure(str(stack.get("unit_id", "")) in units, errors, f"Town {town_id} references missing garrison unit {stack.get('unit_id')}")
            ensure(int(stack.get("count", 0)) > 0, errors, f"Town {town_id} garrison stack must have count > 0 for {stack.get('unit_id')}")
        for entry in town.get("spell_library", []):
            ensure(isinstance(entry, dict), errors, f"Town {town_id} contains a non-dict spell library entry")
            if not isinstance(entry, dict):
                continue
            ensure(int(entry.get("tier", 0)) > 0, errors, f"Town {town_id} spell library entries must define tier > 0")
            for spell_id in entry.get("spell_ids", []):
                ensure(str(spell_id) in spells, errors, f"Town {town_id} references missing spell library spell {spell_id}")
        advanced_embercourt_ids = [building_id for building_id in town.get("buildable_building_ids", []) if str(building_id) in ADVANCED_EMBERCOURT_BUILDING_IDS]
        advanced_mireclaw_ids = [building_id for building_id in town.get("buildable_building_ids", []) if str(building_id) in ADVANCED_MIRECLAW_BUILDING_IDS]
        advanced_sunvault_ids = [building_id for building_id in town.get("buildable_building_ids", []) if str(building_id) in ADVANCED_SUNVAULT_BUILDING_IDS]
        ensure("building_market_square" in town_building_ids, errors, f"Town {town_id} must keep Market Square in its build tree for the exchange-economy slice")
        if str(town.get("faction_id", "")) == "faction_embercourt":
            ensure(bool(advanced_embercourt_ids), errors, f"Town {town_id} must expose at least one advanced Embercourt building for release-facing town asymmetry")
            ensure("building_citadel_pikehall" in town_building_ids, errors, f"Town {town_id} must keep Citadel Pikehall in its build tree for Embercourt battle identity")
        if str(town.get("faction_id", "")) == "faction_mireclaw":
            ensure(bool(advanced_mireclaw_ids), errors, f"Town {town_id} must expose at least one advanced Mireclaw building for release-facing town asymmetry")
            ensure("building_gorefen_ring" in town_building_ids, errors, f"Town {town_id} must keep Gorefen Ring in its build tree for Mireclaw battle identity")
        if str(town.get("faction_id", "")) == "faction_sunvault":
            ensure(bool(advanced_sunvault_ids), errors, f"Town {town_id} must expose at least one advanced Sunvault building for release-facing town asymmetry")
            ensure("building_aurora_spire" in town_building_ids, errors, f"Town {town_id} must keep Aurora Spire in its build tree for Sunvault battle identity")

    for artifact_id, artifact in artifacts.items():
        slot = str(artifact.get("slot", ""))
        ensure(slot in {"boots", "banner", "armor", "trinket"}, errors, f"Artifact {artifact_id} uses unsupported slot {slot}")
        bonuses = artifact.get("bonuses", {})
        ensure(isinstance(bonuses, dict) and bool(bonuses), errors, f"Artifact {artifact_id} must define at least one bonus")
    ensure(
        any(int((artifact.get("bonuses", {}) if isinstance(artifact.get("bonuses", {}), dict) else {}).get("scouting_radius", 0)) > 0 for artifact in artifacts.values()),
        errors,
        "At least one authored artifact must provide a scouting_radius bonus for the fog-of-war slice",
    )
    ensure(ADVANCED_EMBERCOURT_BUILDING_IDS.issubset(buildings.keys()), errors, "Release town depth must keep the advanced Embercourt building set authored")
    ensure(ADVANCED_MIRECLAW_BUILDING_IDS.issubset(buildings.keys()), errors, "Release town depth must keep the advanced Mireclaw building set authored")
    ensure(ADVANCED_SUNVAULT_BUILDING_IDS.issubset(buildings.keys()), errors, "Release town depth must keep the advanced Sunvault building set authored")
    ensure(MARKET_BUILDING_IDS.issubset(buildings.keys()), errors, "Release economy gameplay must keep the core market and exchange building set authored")
    ensure(sum(1 for building in buildings.values() if int(building.get("readiness_bonus", 0)) > 0) >= 6, errors, "Release town depth must author at least six readiness-boosting buildings")
    ensure(sum(1 for building in buildings.values() if int(building.get("pressure_bonus", 0)) > 0) >= 4, errors, "Release town depth must author at least four pressure-boosting buildings")
    ensure(int(factions.get("faction_embercourt", {}).get("recruitment", {}).get("readiness_bonus", 0)) > int(factions.get("faction_mireclaw", {}).get("recruitment", {}).get("readiness_bonus", 0)), errors, "Embercourt must keep the stronger faction-wide readiness bonus")
    ensure(int(factions.get("faction_mireclaw", {}).get("economy", {}).get("pressure_bonus", 0)) > int(factions.get("faction_embercourt", {}).get("economy", {}).get("pressure_bonus", 0)), errors, "Mireclaw must keep the stronger faction-wide pressure bonus")
    ensure(int(factions.get("faction_sunvault", {}).get("economy", {}).get("per_category_income", {}).get("magic", {}).get("gold", 0)) >= 30, errors, "Sunvault must keep a strong faction-wide magic income identity")
    ensure(int(factions.get("faction_sunvault", {}).get("economy", {}).get("per_category_income", {}).get("support", {}).get("gold", 0)) >= 30, errors, "Sunvault must keep a strong faction-wide support income identity")

    for spell_id, spell in spells.items():
        context = str(spell.get("context", ""))
        ensure(context in {"overworld", "battle"}, errors, f"Spell {spell_id} uses unsupported context {context}")
        ensure(int(spell.get("mana_cost", 0)) > 0, errors, f"Spell {spell_id} must define mana_cost > 0")
        effect = spell.get("effect", {})
        ensure(isinstance(effect, dict), errors, f"Spell {spell_id} must define an effect payload")
        if not isinstance(effect, dict):
            continue
        effect_type = str(effect.get("type", ""))
        if effect_type == "restore_movement":
            ensure(int(effect.get("amount", 0)) > 0, errors, f"Spell {spell_id} must define restore movement amount > 0")
        elif effect_type == "damage_enemy":
            ensure(int(effect.get("base_damage", 0)) > 0, errors, f"Spell {spell_id} must define base_damage > 0")
            ensure(int(effect.get("power_scale", -1)) >= 0, errors, f"Spell {spell_id} must define power_scale >= 0")
            status_effect = effect.get("status_effect", {})
            if "status_effect" in effect:
                ensure(isinstance(status_effect, dict) and bool(status_effect), errors, f"Spell {spell_id} status_effect must be a non-empty dictionary when present")
            if isinstance(status_effect, dict) and status_effect:
                ensure(bool(str(status_effect.get("effect_id", status_effect.get("status_id", "")))), errors, f"Spell {spell_id} status_effect must define effect_id")
                ensure(int(status_effect.get("duration_rounds", 0)) > 0, errors, f"Spell {spell_id} status_effect must define duration_rounds > 0")
                modifiers = status_effect.get("modifiers", {})
                ensure(isinstance(modifiers, dict) and bool(modifiers), errors, f"Spell {spell_id} status_effect must define modifiers")
        elif effect_type in {"defense_buff", "initiative_buff", "attack_buff"}:
            ensure(int(effect.get("amount", 0)) > 0, errors, f"Spell {spell_id} must define buff amount > 0")
            ensure(int(effect.get("duration_rounds", 0)) > 0, errors, f"Spell {spell_id} must define duration_rounds > 0")
            modifiers = effect.get("modifiers", {})
            if "modifiers" in effect:
                ensure(isinstance(modifiers, dict) and bool(modifiers), errors, f"Spell {spell_id} modifiers must be a non-empty dictionary when present")
        else:
            fail(errors, f"Spell {spell_id} uses unsupported effect type {effect_type}")

    cinder_burst = spells.get("spell_cinder_burst", {}).get("effect", {})
    ensure(str(cinder_burst.get("status_effect", {}).get("effect_id", "")) == "status_staggered", errors, "Cinder Burst must keep its staggered spell payoff authored")
    ensure(int(cinder_burst.get("status_effect", {}).get("modifiers", {}).get("cohesion", 0)) < 0, errors, "Cinder Burst must keep a cohesion-pressure rider on stagger")
    coal_rain = spells.get("spell_coal_rain", {}).get("effect", {})
    ensure(str(coal_rain.get("status_effect", {}).get("effect_id", "")) == "status_harried", errors, "Coal Rain must keep its harried spell payoff authored")
    ensure(int(coal_rain.get("status_effect", {}).get("modifiers", {}).get("cohesion", 0)) < 0, errors, "Coal Rain must keep a cohesion-break rider on harried targets")
    ensure(int(spells.get("spell_quickmarch_hymn", {}).get("effect", {}).get("modifiers", {}).get("attack", 0)) > 0, errors, "Quickmarch Hymn must keep an attack modifier for Embercourt battle tempo")
    ensure(int(spells.get("spell_quickmarch_hymn", {}).get("effect", {}).get("modifiers", {}).get("momentum", 0)) > 0, errors, "Quickmarch Hymn must keep a momentum rider for battle tempo")
    ensure(int(spells.get("spell_relay_drum", {}).get("effect", {}).get("modifiers", {}).get("attack", 0)) > 0, errors, "Relay Drum must keep an attack modifier for Mireclaw battle tempo")
    ensure(int(spells.get("spell_relay_drum", {}).get("effect", {}).get("modifiers", {}).get("momentum", 0)) > 0, errors, "Relay Drum must keep a momentum rider for Mireclaw battle tempo")
    ensure(int(spells.get("spell_stone_veil", {}).get("effect", {}).get("modifiers", {}).get("initiative", 0)) > 0, errors, "Stone Veil must keep an initiative rider for formation recovery")
    ensure(int(spells.get("spell_stone_veil", {}).get("effect", {}).get("modifiers", {}).get("cohesion", 0)) > 0, errors, "Stone Veil must keep a cohesion rider for line recovery")
    ensure(int(spells.get("spell_bulwark_litany", {}).get("effect", {}).get("modifiers", {}).get("attack", 0)) > 0, errors, "Bulwark Litany must keep an attack rider for brute-line payoff")
    ensure(int(spells.get("spell_bulwark_litany", {}).get("effect", {}).get("modifiers", {}).get("cohesion", 0)) > 0, errors, "Bulwark Litany must keep a cohesion rider for holdfast payoff")
    ensure(str(spells.get("spell_lantern_phalanx", {}).get("effect", {}).get("type", "")) == "attack_buff", errors, "Lantern Phalanx must keep its attack_buff identity authored")
    ensure(int(spells.get("spell_lantern_phalanx", {}).get("effect", {}).get("modifiers", {}).get("defense", 0)) > 0, errors, "Lantern Phalanx must keep a defense rider for Embercourt line play")
    ensure(int(spells.get("spell_lantern_phalanx", {}).get("effect", {}).get("modifiers", {}).get("cohesion", 0)) > 0, errors, "Lantern Phalanx must keep a cohesion rider for Embercourt line play")
    ensure(str(spells.get("spell_bloodwake_drum", {}).get("effect", {}).get("type", "")) == "attack_buff", errors, "Bloodwake Drum must keep its attack_buff identity authored")
    ensure(int(spells.get("spell_bloodwake_drum", {}).get("effect", {}).get("modifiers", {}).get("initiative", 0)) > 0, errors, "Bloodwake Drum must keep an initiative rider for Mireclaw collapse tempo")
    ensure(int(spells.get("spell_bloodwake_drum", {}).get("effect", {}).get("modifiers", {}).get("momentum", 0)) > 0, errors, "Bloodwake Drum must keep a momentum rider for Mireclaw collapse tempo")
    ensure(str(spells.get("spell_prism_bastion", {}).get("effect", {}).get("type", "")) == "defense_buff", errors, "Prism Bastion must keep its defense_buff identity authored")
    ensure(int(spells.get("spell_prism_bastion", {}).get("effect", {}).get("modifiers", {}).get("cohesion", 0)) > 0, errors, "Prism Bastion must keep a cohesion rider for Sunvault array support")
    ensure(str(spells.get("spell_resonant_chorus", {}).get("effect", {}).get("type", "")) == "initiative_buff", errors, "Resonant Chorus must keep its initiative_buff identity authored")
    ensure(int(spells.get("spell_resonant_chorus", {}).get("effect", {}).get("modifiers", {}).get("momentum", 0)) > 0, errors, "Resonant Chorus must keep a momentum rider for Sunvault tempo")
    ensure(str(spells.get("spell_sunlance_arc", {}).get("effect", {}).get("type", "")) == "damage_enemy", errors, "Sunlance Arc must keep its damage spell identity authored")
    ensure(int(spells.get("spell_sunlance_arc", {}).get("effect", {}).get("status_effect", {}).get("modifiers", {}).get("cohesion", 0)) < 0, errors, "Sunlance Arc must keep a cohesion-break rider for Sunvault battle identity")

    ensure("spell_lantern_phalanx" in [str(spell_id) for spell_id in heroes.get("hero_caelen", {}).get("starting_spell_ids", [])], errors, "Caelen must keep Lantern Phalanx for line-cohesion commander identity")
    ensure("spell_quickmarch_hymn" in [str(spell_id) for spell_id in heroes.get("hero_seren", {}).get("starting_spell_ids", [])], errors, "Seren must keep Quickmarch Hymn for artillery-tempo commander identity")
    ensure("spell_coal_rain" in [str(spell_id) for spell_id in heroes.get("hero_tarn", {}).get("starting_spell_ids", [])], errors, "Tarn must keep Coal Rain for ambush-pressure commander identity")
    ensure("spell_stone_veil" in [str(spell_id) for spell_id in heroes.get("hero_orrik", {}).get("starting_spell_ids", [])], errors, "Orrik must keep Stone Veil for dense-pack commander identity")
    ensure("spell_prism_bastion" in [str(spell_id) for spell_id in heroes.get("hero_solera", {}).get("starting_spell_ids", [])], errors, "Solera must keep Prism Bastion for Sunvault line-support commander identity")
    ensure("spell_sunlance_arc" in [str(spell_id) for spell_id in heroes.get("hero_neral", {}).get("starting_spell_ids", [])], errors, "Neral must keep Sunlance Arc for Sunvault artillery identity")
    ensure("spell_resonant_chorus" in [str(spell_id) for spell_id in heroes.get("hero_varis", {}).get("starting_spell_ids", [])], errors, "Varis must keep Resonant Chorus for Sunvault tempo identity")
    ensure("spell_resonant_chorus" in [str(spell_id) for spell_id in heroes.get("hero_thalen", {}).get("starting_spell_ids", [])], errors, "Thalen must keep Resonant Chorus for Sunvault cloister identity")

    objective_authored_encounter_ids: set[str] = set()
    for encounter_id, encounter in encounters.items():
        ensure(str(encounter.get("enemy_group_id", "")) in army_groups, errors, f"Encounter {encounter_id} references missing enemy group")
        ensure(int(encounter.get("max_rounds", 0)) > 0, errors, f"Encounter {encounter_id} must define max_rounds > 0")
        battlefield_tags = encounter.get("battlefield_tags", [])
        ensure(isinstance(battlefield_tags, list) and bool(battlefield_tags), errors, f"Encounter {encounter_id} must define non-empty battlefield_tags")
        if isinstance(battlefield_tags, list):
            for tag_id in battlefield_tags:
                ensure(str(tag_id) in SUPPORTED_BATTLEFIELD_TAGS, errors, f"Encounter {encounter_id} uses unsupported battlefield tag {tag_id}")
        commander = encounter.get("enemy_commander", {})
        if commander:
            ensure(isinstance(commander, dict), errors, f"Encounter {encounter_id} enemy_commander must be a dictionary")
        if isinstance(commander, dict) and commander:
            ensure(isinstance(commander.get("command", {}), dict), errors, f"Encounter {encounter_id} enemy_commander must define a command dictionary")
            commander_traits = commander.get("battle_traits", [])
            ensure(isinstance(commander_traits, list) and bool(commander_traits), errors, f"Encounter {encounter_id} enemy_commander must define non-empty battle_traits")
            if isinstance(commander_traits, list):
                for trait_id in commander_traits:
                    ensure(str(trait_id) in VALID_BATTLE_TRAIT_IDS, errors, f"Encounter {encounter_id} enemy_commander uses unsupported battle trait {trait_id}")
            for spell_id in commander.get("starting_spell_ids", []):
                spell_key = str(spell_id)
                ensure(spell_key in spells, errors, f"Encounter {encounter_id} references missing enemy commander spell {spell_key}")
                if spell_key in spells:
                    ensure(str(spells[spell_key].get("context", "")) == "battle", errors, f"Encounter {encounter_id} enemy commander spell {spell_key} must be a battle spell")
        if "field_objectives" in encounter:
            validate_field_objectives(errors, f"Encounter {encounter_id}", encounter.get("field_objectives", []))
            if isinstance(encounter.get("field_objectives", []), list) and encounter.get("field_objectives", []):
                objective_authored_encounter_ids.add(encounter_id)

    encounter_tag_count = sum(1 for encounter in encounters.values() if isinstance(encounter.get("battlefield_tags", []), list) and bool(encounter.get("battlefield_tags", [])))
    ensure(encounter_tag_count >= 20, errors, "Release battle variety must keep battlefield tags on at least twenty authored encounters")
    ensure(RELEASE_FIELD_OBJECTIVE_ENCOUNTER_IDS.issubset(objective_authored_encounter_ids), errors, "Release battle-objective slice must keep authored field_objectives on the signature encounter set")
    ensure(str(encounters.get("encounter_lantern_patrol", {}).get("enemy_group_id", "")) == "army_lantern_battery", errors, "Lantern Patrol must keep its ranged-battery encounter puzzle authored")
    ensure(str(encounters.get("encounter_bridgeward_levies", {}).get("enemy_group_id", "")) == "army_causeway_phalanx", errors, "Bridgeward Levies must keep its chokepoint phalanx encounter puzzle authored")
    ensure(str(encounters.get("encounter_sluice_raiders", {}).get("enemy_group_id", "")) == "army_muckveil_harriers", errors, "Sluice Raiders must keep its harrier-heavy encounter puzzle authored")
    ensure(str(encounters.get("encounter_bone_ferry_watch", {}).get("enemy_group_id", "")) == "army_ripper_vanguard", errors, "Bone Ferry Watch must keep its ripper-vanguard encounter puzzle authored")
    ensure(str(encounters.get("encounter_relay_pickets", {}).get("enemy_group_id", "")) == "army_relay_pickets", errors, "Relay Pickets must keep their fortified Sunvault screen encounter puzzle authored")
    ensure(str(encounters.get("encounter_aurora_battery", {}).get("enemy_group_id", "")) == "army_aurora_battery", errors, "Aurora Battery must keep its elevated-fire Sunvault battery encounter puzzle authored")
    ensure(any(str(objective.get("type", "")) == "lane_battery" for objective in encounters.get("encounter_lantern_patrol", {}).get("field_objectives", []) if isinstance(objective, dict)), errors, "Lantern Patrol must keep a lane_battery battlefield objective authored")
    ensure(any(str(objective.get("type", "")) == "supply_post" for objective in encounters.get("encounter_charter_guard", {}).get("field_objectives", []) if isinstance(objective, dict)), errors, "Charter Guard must keep a supply_post battlefield objective authored")
    ensure(any(str(objective.get("type", "")) == "ritual_pylon" for objective in encounters.get("encounter_drum_circle", {}).get("field_objectives", []) if isinstance(objective, dict)), errors, "Nightglass Drum Circle must keep a ritual_pylon battlefield objective authored")
    ensure(any(str(objective.get("type", "")) == "signal_beacon" for objective in encounters.get("encounter_relay_pickets", {}).get("field_objectives", []) if isinstance(objective, dict)), errors, "Relay Pickets must keep a signal_beacon battlefield objective authored")
    for encounter_id, required_objectives in RELEASE_BATTLEFIELD_IDENTITY_OBJECTIVES.items():
        authored_types = {
            str(objective.get("type", ""))
            for objective in encounters.get(encounter_id, {}).get("field_objectives", [])
            if isinstance(objective, dict)
        }
        ensure(required_objectives.issubset(authored_types), errors, f"Encounter {encounter_id} must keep battlefield identity objectives {sorted(required_objectives)}")

    objective_override_placements: set[str] = set()
    for scenario_id, scenario in scenarios.items():
        game_map = scenario.get("map", [])
        ensure(isinstance(game_map, list) and bool(game_map), errors, f"Scenario {scenario_id} must define a non-empty map")
        if not isinstance(game_map, list) or not game_map:
            continue

        width = len(game_map[0])
        height = len(game_map)
        ensure(all(isinstance(row, list) and len(row) == width for row in game_map), errors, f"Scenario {scenario_id} has inconsistent row widths")
        declared_size = scenario.get("map_size", {})
        ensure(int(declared_size.get("width", 0)) == width, errors, f"Scenario {scenario_id} width does not match map_size")
        ensure(int(declared_size.get("height", 0)) == height, errors, f"Scenario {scenario_id} height does not match map_size")
        ensure(str(scenario.get("player_faction_id", "")) in factions, errors, f"Scenario {scenario_id} references missing player faction")
        ensure(str(scenario.get("hero_id", "")) in heroes, errors, f"Scenario {scenario_id} references missing hero")
        ensure(str(scenario.get("player_army_id", "")) in army_groups, errors, f"Scenario {scenario_id} references missing player army")
        player_faction_id = str(scenario.get("player_faction_id", ""))
        primary_hero_id = str(scenario.get("hero_id", ""))
        scenario_player_factions.add(player_faction_id)
        scenario_hero_ids.add(primary_hero_id)
        if player_faction_id in factions and primary_hero_id in heroes:
            ensure(primary_hero_id in [str(value) for value in factions[player_faction_id].get("hero_ids", [])], errors, f"Scenario {scenario_id} hero_id {primary_hero_id} must belong to player faction {player_faction_id}")
        hero_starts = scenario.get("hero_starts", [])
        if "hero_starts" in scenario:
            ensure(isinstance(hero_starts, list) and bool(hero_starts), errors, f"Scenario {scenario_id} hero_starts must be a non-empty list when present")
        if isinstance(hero_starts, list) and hero_starts:
            normalized_hero_starts: list[str] = []
            for hero_id in hero_starts:
                hero_key = str(hero_id)
                ensure(hero_key in heroes, errors, f"Scenario {scenario_id} hero_starts references missing hero {hero_key}")
                if player_faction_id in factions:
                    ensure(hero_key in [str(value) for value in factions[player_faction_id].get("hero_ids", [])], errors, f"Scenario {scenario_id} hero_starts hero {hero_key} must belong to player faction {player_faction_id}")
                ensure(hero_key not in normalized_hero_starts, errors, f"Scenario {scenario_id} hero_starts repeats hero {hero_key}")
                if hero_key not in normalized_hero_starts:
                    normalized_hero_starts.append(hero_key)
            ensure(primary_hero_id in normalized_hero_starts, errors, f"Scenario {scenario_id} hero_starts must include primary hero_id {primary_hero_id}")
        if player_faction_id in factions and len([str(value) for value in factions[player_faction_id].get("hero_ids", [])]) > 1:
            hall_capable_town_exists = False
            for placement in scenario.get("towns", []):
                if not isinstance(placement, dict):
                    continue
                town_id = str(placement.get("town_id", ""))
                town = towns.get(town_id, {})
                available_buildings = [str(value) for value in town.get("starting_building_ids", [])] + [str(value) for value in town.get("buildable_building_ids", [])]
                if WAYFARERS_HALL_BUILDING_ID in available_buildings:
                    hall_capable_town_exists = True
                    break
            ensure(hall_capable_town_exists, errors, f"Scenario {scenario_id} must include at least one town that can host a Wayfarers Hall for multi-hero recruitment")
        selection = scenario.get("selection", {})
        ensure(isinstance(selection, dict) and bool(selection), errors, f"Scenario {scenario_id} must define selection metadata for skirmish/setup UX")
        if isinstance(selection, dict):
            ensure(bool(str(selection.get("summary", ""))), errors, f"Scenario {scenario_id} selection metadata must define summary")
            ensure(str(selection.get("recommended_difficulty", "")) in VALID_DIFFICULTIES, errors, f"Scenario {scenario_id} selection metadata must define a supported recommended_difficulty")
            ensure(bool(str(selection.get("map_size_label", ""))), errors, f"Scenario {scenario_id} selection metadata must define map_size_label")
            ensure(bool(str(selection.get("player_summary", ""))), errors, f"Scenario {scenario_id} selection metadata must define player_summary")
            ensure(bool(str(selection.get("enemy_summary", ""))), errors, f"Scenario {scenario_id} selection metadata must define enemy_summary")
            availability = selection.get("availability", {})
            ensure(isinstance(availability, dict), errors, f"Scenario {scenario_id} selection metadata must define an availability dictionary")
            if isinstance(availability, dict):
                ensure("campaign" in availability, errors, f"Scenario {scenario_id} selection availability must declare campaign")
                ensure("skirmish" in availability, errors, f"Scenario {scenario_id} selection availability must declare skirmish")
                campaign_enabled = bool(availability.get("campaign", False))
                skirmish_enabled = bool(availability.get("skirmish", False))
                ensure(campaign_enabled or skirmish_enabled, errors, f"Scenario {scenario_id} must be available to at least one launch mode")
                ensure(campaign_enabled == (scenario_id in campaign_scenario_ids), errors, f"Scenario {scenario_id} campaign availability must match campaign content wiring")
                if skirmish_enabled:
                    skirmish_scenario_ids.append(scenario_id)
                if skirmish_enabled and not campaign_enabled:
                    skirmish_only_scenario_ids.append(scenario_id)

        start = scenario.get("start", {})
        start_x = int(start.get("x", -1))
        start_y = int(start.get("y", -1))
        ensure(0 <= start_x < width and 0 <= start_y < height, errors, f"Scenario {scenario_id} start is out of bounds")

        for placement in scenario.get("towns", []):
            if not isinstance(placement, dict):
                fail(errors, f"Scenario {scenario_id} contains a non-dict town placement")
                continue
            ensure(str(placement.get("town_id", "")) in towns, errors, f"Scenario {scenario_id} references missing town {placement.get('town_id')}")
            x = int(placement.get("x", -1))
            y = int(placement.get("y", -1))
            ensure(0 <= x < width and 0 <= y < height, errors, f"Scenario {scenario_id} town placement {placement.get('placement_id')} is out of bounds")

        for placement in scenario.get("resource_nodes", []):
            if not isinstance(placement, dict):
                fail(errors, f"Scenario {scenario_id} contains a non-dict resource placement")
                continue
            ensure(str(placement.get("site_id", "")) in resource_sites, errors, f"Scenario {scenario_id} references missing resource site {placement.get('site_id')}")
            x = int(placement.get("x", -1))
            y = int(placement.get("y", -1))
            ensure(0 <= x < width and 0 <= y < height, errors, f"Scenario {scenario_id} resource placement {placement.get('placement_id')} is out of bounds")
        resource_placement_ids = {
            str(placement.get("placement_id", ""))
            for placement in scenario.get("resource_nodes", [])
            if isinstance(placement, dict) and str(placement.get("placement_id", ""))
        }

        artifact_placement_ids: list[str] = []
        artifact_ids_in_scenario: list[str] = []
        for placement in scenario.get("artifact_nodes", []):
            if not isinstance(placement, dict):
                fail(errors, f"Scenario {scenario_id} contains a non-dict artifact placement")
                continue
            artifact_id = str(placement.get("artifact_id", ""))
            placement_id = str(placement.get("placement_id", ""))
            ensure(artifact_id in artifacts, errors, f"Scenario {scenario_id} references missing artifact {placement.get('artifact_id')}")
            ensure(bool(placement_id), errors, f"Scenario {scenario_id} artifact placements must define placement_id")
            ensure(placement_id not in artifact_placement_ids, errors, f"Scenario {scenario_id} repeats artifact placement_id {placement_id}")
            ensure(artifact_id not in artifact_ids_in_scenario, errors, f"Scenario {scenario_id} repeats artifact {artifact_id} in authored artifact nodes")
            append_unique(artifact_placement_ids, placement_id)
            append_unique(artifact_ids_in_scenario, artifact_id)
            x = int(placement.get("x", -1))
            y = int(placement.get("y", -1))
            ensure(0 <= x < width and 0 <= y < height, errors, f"Scenario {scenario_id} artifact placement {placement.get('placement_id')} is out of bounds")

        for placement in scenario.get("encounters", []):
            if not isinstance(placement, dict):
                fail(errors, f"Scenario {scenario_id} contains a non-dict encounter placement")
                continue
            ensure(str(placement.get("encounter_id", placement.get("id", ""))) in encounters, errors, f"Scenario {scenario_id} references missing encounter {placement.get('encounter_id')}")
            if "field_objectives" in placement:
                placement_id = str(placement.get("placement_id", ""))
                validate_field_objectives(errors, f"Scenario {scenario_id} encounter placement {placement_id}", placement.get("field_objectives", []), allow_partial=True)
                if isinstance(placement.get("field_objectives", []), list) and placement.get("field_objectives", []):
                    objective_override_placements.add(placement_id)
            x = int(placement.get("x", -1))
            y = int(placement.get("y", -1))
            ensure(0 <= x < width and 0 <= y < height, errors, f"Scenario {scenario_id} encounter placement {placement.get('placement_id')} is out of bounds")

        town_placement_ids = {
            str(placement.get("placement_id", ""))
            for placement in scenario.get("towns", [])
            if isinstance(placement, dict)
        }
        encounter_placement_ids = [
            str(placement.get("placement_id", ""))
            for placement in scenario.get("encounters", [])
            if isinstance(placement, dict) and str(placement.get("placement_id", ""))
        ]

        objectives = scenario.get("objectives", {})
        objective_ids: list[str] = []
        if objectives:
            ensure(isinstance(objectives, dict), errors, f"Scenario {scenario_id} objectives must be a dictionary")
        if isinstance(objectives, dict):
            for objective_bucket in ("victory", "defeat"):
                bucket = objectives.get(objective_bucket, [])
                ensure(isinstance(bucket, list), errors, f"Scenario {scenario_id} objective bucket {objective_bucket} must be a list")
                if not isinstance(bucket, list):
                    continue
                for objective in bucket:
                    if not isinstance(objective, dict):
                        fail(errors, f"Scenario {scenario_id} contains a non-dict objective in {objective_bucket}")
                        continue
                    objective_type = str(objective.get("type", ""))
                    objective_id = str(objective.get("id", "<unknown>"))
                    append_unique(objective_ids, objective_id)
                    if objective_type in {"town_owned_by_player", "town_not_owned_by_player"}:
                        ensure(str(objective.get("placement_id", "")) in town_placement_ids, errors, f"Scenario {scenario_id} objective {objective_id} references missing placement_id")
                    elif objective_type == "flag_true":
                        ensure(bool(str(objective.get("flag", ""))), errors, f"Scenario {scenario_id} objective {objective_id} must define a flag")
                    elif objective_type == "session_flag_equals":
                        ensure(bool(str(objective.get("flag", ""))), errors, f"Scenario {scenario_id} objective {objective_id} must define a flag")
                    elif objective_type == "encounter_resolved":
                        ensure(str(objective.get("placement_id", "")) in encounter_placement_ids, errors, f"Scenario {scenario_id} objective {objective_id} references missing encounter placement_id")
                    elif objective_type == "hook_fired":
                        ensure(bool(str(objective.get("hook_id", ""))), errors, f"Scenario {scenario_id} objective {objective_id} must define hook_id")
                    elif objective_type == "enemy_pressure_at_least":
                        ensure(str(objective.get("faction_id", "")) in factions, errors, f"Scenario {scenario_id} objective {objective_id} references missing faction")
                        ensure(int(objective.get("threshold", 0)) > 0, errors, f"Scenario {scenario_id} objective {objective_id} must define threshold > 0")
                    elif objective_type == "day_at_least":
                        ensure(int(objective.get("day", 0)) > 0, errors, f"Scenario {scenario_id} objective {objective_id} must define day > 0")
                    else:
                        fail(errors, f"Scenario {scenario_id} objective {objective_id} has unsupported type {objective_type}")

        script_hooks = scenario.get("script_hooks", [])
        if script_hooks:
            ensure(isinstance(script_hooks, list), errors, f"Scenario {scenario_id} script_hooks must be a list")
        if isinstance(script_hooks, list):
            for hook in script_hooks:
                if not isinstance(hook, dict):
                    fail(errors, f"Scenario {scenario_id} contains a non-dict script hook")
                    continue
                for effect in hook.get("effects", []):
                    if not isinstance(effect, dict):
                        continue
                    if str(effect.get("type", "")) != "spawn_encounter":
                        continue
                    placement = effect.get("placement", {})
                    if isinstance(placement, dict):
                        append_unique(encounter_placement_ids, str(placement.get("placement_id", "")))

            for hook in script_hooks:
                if not isinstance(hook, dict):
                    continue
                hook_id = str(hook.get("id", "<unknown>"))
                conditions = hook.get("conditions", [])
                effects = hook.get("effects", [])
                ensure(bool(str(hook.get("id", ""))), errors, f"Scenario {scenario_id} contains a script hook without an id")
                ensure(isinstance(conditions, list) and bool(conditions), errors, f"Scenario {scenario_id} hook {hook_id} must define conditions")
                ensure(isinstance(effects, list) and bool(effects), errors, f"Scenario {scenario_id} hook {hook_id} must define effects")
                if isinstance(conditions, list):
                    for condition in conditions:
                        ensure(isinstance(condition, dict), errors, f"Scenario {scenario_id} hook {hook_id} contains a non-dict condition")
                        if isinstance(condition, dict):
                            validate_script_condition(
                                errors,
                                scenario_id,
                                hook_id,
                                condition,
                                factions,
                                list(town_placement_ids),
                                encounter_placement_ids,
                                objective_ids,
                            )
                if isinstance(effects, list):
                    for effect in effects:
                        ensure(isinstance(effect, dict), errors, f"Scenario {scenario_id} hook {hook_id} contains a non-dict effect")
                        if isinstance(effect, dict):
                            validate_script_effect(
                                errors,
                                scenario_id,
                                hook_id,
                                effect,
                                factions,
                                units,
                                buildings,
                                resource_sites,
                                artifacts,
                                encounters,
                                list(town_placement_ids),
                                width,
                                height,
                            )

        encounter_count = len(
            [placement for placement in scenario.get("encounters", []) if isinstance(placement, dict)]
        )
        ensure(encounter_count >= 3, errors, f"Scenario {scenario_id} must author at least three encounter placements for release-facing neutral-front variety")

        encounter_objective_count = 0
        reactive_hook_present = False
        pressure_hook_present = False
        scripted_spawn_present = False
        town_relief_present = False
        effectful_hook_count = 0
        if isinstance(objectives, dict):
            for objective in objectives.get("victory", []):
                if isinstance(objective, dict) and str(objective.get("type", "")) == "encounter_resolved":
                    encounter_objective_count += 1
        if isinstance(script_hooks, list):
            for hook in script_hooks:
                if not isinstance(hook, dict):
                    continue
                conditions = hook.get("conditions", [])
                effects = hook.get("effects", [])
                if isinstance(effects, list) and effects:
                    effectful_hook_count += 1
                if isinstance(conditions, list):
                    for condition in conditions:
                        if not isinstance(condition, dict):
                            continue
                        if str(condition.get("type", "")) in {"objective_not_met", "active_raid_count_at_least", "hook_fired", "hook_not_fired"}:
                            reactive_hook_present = True
                if isinstance(effects, list):
                    for effect in effects:
                        if not isinstance(effect, dict):
                            continue
                        effect_type = str(effect.get("type", ""))
                        if effect_type == "add_enemy_pressure":
                            pressure_hook_present = True
                        elif effect_type == "spawn_encounter":
                            scripted_spawn_present = True
                        elif effect_type == "town_add_recruits":
                            town_relief_present = True

        ensure(encounter_objective_count >= 1, errors, f"Scenario {scenario_id} must author at least one encounter-clearing objective for distinct side-pressure identity")
        ensure(effectful_hook_count >= 5, errors, f"Scenario {scenario_id} must author at least five script hooks for release-facing chapter/event density")
        ensure(reactive_hook_present, errors, f"Scenario {scenario_id} must include reactive script conditions such as objective_not_met, raid-count checks, or hook dependencies")
        ensure(pressure_hook_present, errors, f"Scenario {scenario_id} must include at least one add_enemy_pressure hook effect")
        ensure(scripted_spawn_present, errors, f"Scenario {scenario_id} must include at least one scripted spawn_encounter effect")
        ensure(town_relief_present, errors, f"Scenario {scenario_id} must include at least one town relief or reinforcement hook")

        for enemy_faction in scenario.get("enemy_factions", []):
            if not isinstance(enemy_faction, dict):
                fail(errors, f"Scenario {scenario_id} contains a non-dict enemy faction entry")
                continue
            faction_id = str(enemy_faction.get("faction_id", ""))
            ensure(faction_id in factions, errors, f"Scenario {scenario_id} references missing enemy faction {faction_id}")
            ensure(int(enemy_faction.get("raid_threshold", 0)) > 0, errors, f"Scenario {scenario_id} enemy faction {faction_id} must define raid_threshold > 0")
            for encounter_id in enemy_faction.get("raid_encounter_ids", []):
                ensure(str(encounter_id) in encounters, errors, f"Scenario {scenario_id} enemy faction {faction_id} references missing raid encounter {encounter_id}")
            for spawn_point in enemy_faction.get("spawn_points", []):
                if not isinstance(spawn_point, dict):
                    fail(errors, f"Scenario {scenario_id} enemy faction {faction_id} contains a non-dict spawn point")
                    continue
                x = int(spawn_point.get("x", -1))
                y = int(spawn_point.get("y", -1))
                ensure(0 <= x < width and 0 <= y < height, errors, f"Scenario {scenario_id} enemy faction {faction_id} has out-of-bounds spawn point")
            siege_target = str(enemy_faction.get("siege_target_placement_id", ""))
            if siege_target:
                ensure(siege_target in town_placement_ids, errors, f"Scenario {scenario_id} enemy faction {faction_id} references missing siege target {siege_target}")
            priority_targets = enemy_faction.get("priority_target_placement_ids", [])
            if "priority_target_placement_ids" in enemy_faction:
                ensure(isinstance(priority_targets, list) and bool(priority_targets), errors, f"Scenario {scenario_id} enemy faction {faction_id} must define non-empty priority_target_placement_ids when present")
            if isinstance(priority_targets, list):
                all_priority_targets = town_placement_ids | resource_placement_ids | set(artifact_placement_ids) | set(encounter_placement_ids)
                for placement_id in priority_targets:
                    ensure(str(placement_id) in all_priority_targets, errors, f"Scenario {scenario_id} enemy faction {faction_id} priority target {placement_id} is not an authored placement")
            if "priority_target_bonus" in enemy_faction:
                ensure(int(enemy_faction.get("priority_target_bonus", 0)) > 0, errors, f"Scenario {scenario_id} enemy faction {faction_id} priority_target_bonus must be > 0")
            strategy_overrides = enemy_faction.get("strategy_overrides", {})
            if "strategy_overrides" in enemy_faction:
                ensure(isinstance(strategy_overrides, dict) and bool(strategy_overrides), errors, f"Scenario {scenario_id} enemy faction {faction_id} strategy_overrides must be a non-empty dictionary")
            if isinstance(strategy_overrides, dict):
                for section, bucket in strategy_overrides.items():
                    ensure(section in ENEMY_STRATEGY_KEYS, errors, f"Scenario {scenario_id} enemy faction {faction_id} uses unsupported strategy_overrides section {section}")
                    ensure(isinstance(bucket, dict) and bool(bucket), errors, f"Scenario {scenario_id} enemy faction {faction_id} strategy_overrides {section} must be a non-empty dictionary")
                    if section in ENEMY_STRATEGY_KEYS and isinstance(bucket, dict):
                        for key in bucket.keys():
                            ensure(str(key) in ENEMY_STRATEGY_KEYS[section], errors, f"Scenario {scenario_id} enemy faction {faction_id} strategy_overrides {section} uses unsupported key {key}")

    validate_campaigns(errors, campaigns, scenarios)
    ensure(RELEASE_FIELD_OBJECTIVE_SCENARIO_PLACEMENTS.issubset(objective_override_placements), errors, "Release battle-objective slice must keep authored scenario encounter overrides for the signature field-objective fronts")
    ensure(bool(skirmish_scenario_ids), errors, "At least one scenario must be marked skirmish-available")
    ensure(bool(skirmish_only_scenario_ids), errors, "Scenario roster should include at least one authored skirmish-only front")
    ensure(RELEASE_PLAYER_FACTIONS.issubset(scenario_player_factions), errors, "Scenario starts must cover all release player factions")
    ensure(len(scenario_hero_ids) >= 4, errors, "Scenario roster must expose at least four distinct lead heroes")


def validate_six_faction_content_scaffold(errors: list[str]) -> None:
    payloads = {
        "factions": load_json(CONTENT_DIR / "factions.json"),
        "heroes": load_json(CONTENT_DIR / "heroes.json"),
        "units": load_json(CONTENT_DIR / "units.json"),
        "towns": load_json(CONTENT_DIR / "towns.json"),
        "buildings": load_json(CONTENT_DIR / "buildings.json"),
    }
    factions = items_index(payloads["factions"])
    heroes = items_index(payloads["heroes"])
    units = items_index(payloads["units"])
    towns = items_index(payloads["towns"])
    buildings = items_index(payloads["buildings"])

    ensure(SIX_FACTION_BIBLE_IDS.issubset(factions.keys()), errors, "Six-faction implementation loop must author all bible faction records")

    ladder_fingerprints: set[str] = set()
    for faction_id in sorted(SIX_FACTION_BIBLE_IDS):
        faction = factions.get(faction_id, {})
        design = faction.get("design_pillars", {})
        ensure(isinstance(design, dict) and bool(design), errors, f"Faction {faction_id} must define six-faction design_pillars")
        if isinstance(design, dict):
            for key in ("theme", "economy_style", "map_pressure", "battle_style", "ladder_fingerprint"):
                ensure(bool(str(design.get(key, ""))), errors, f"Faction {faction_id} design_pillars must define {key}")
            fingerprint = str(design.get("ladder_fingerprint", ""))
            ensure(fingerprint not in ladder_fingerprints, errors, f"Faction {faction_id} must not share a ladder_fingerprint with another bible faction")
            if fingerprint:
                ladder_fingerprints.add(fingerprint)

        status = faction.get("content_status", {})
        ensure(isinstance(status, dict) and bool(status), errors, f"Faction {faction_id} must define content_status for six-faction implementation truthfulness")
        if isinstance(status, dict):
            ensure(str(status.get("six_faction_loop", "")) == "scaffold_started", errors, f"Faction {faction_id} must be marked scaffold_started in the six-faction loop")
            ensure(str(status.get("manual_play", "")) == "not_verified_for_six_faction_bundle", errors, f"Faction {faction_id} must not claim six-faction manual play verification")
            ensure(str(status.get("playability", "")) != "fully_playable", errors, f"Faction {faction_id} must not claim fully_playable during the scaffold slice")

        ladder_ids = [str(value) for value in faction.get("unit_ladder_ids", [])]
        ensure(len(ladder_ids) == 7 and len(set(ladder_ids)) == 7, errors, f"Faction {faction_id} must define exactly seven unique unit_ladder_ids")
        tiers: set[int] = set()
        unit_roles: list[str] = []
        for unit_id in ladder_ids:
            unit = units.get(unit_id, {})
            ensure(bool(unit), errors, f"Faction {faction_id} ladder references missing unit {unit_id}")
            if not unit:
                continue
            ensure(str(unit.get("faction_id", "")) == faction_id, errors, f"Faction {faction_id} ladder unit {unit_id} belongs to another faction")
            tiers.add(int(unit.get("tier", 0)))
            unit_roles.append(str(unit.get("role", "")))
            name_words = {word.lower() for word in re.findall(r"[A-Za-z]+", str(unit.get("name", "")))}
            common_words = sorted(name_words & SIX_FACTION_COMMON_WORDS)
            ensure(not common_words, errors, f"Faction {faction_id} ladder unit {unit_id} uses banned common identity word(s): {', '.join(common_words)}")
            ensure(str(unit.get("content_status", "")) == "six_faction_scaffold", errors, f"Faction {faction_id} ladder unit {unit_id} must be marked as six_faction_scaffold")
        ensure(tiers == set(range(1, 8)), errors, f"Faction {faction_id} ladder must cover tiers 1 through 7")
        ensure("melee" in unit_roles and "ranged" in unit_roles, errors, f"Faction {faction_id} ladder must include both melee and ranged pressure")

        bible_hero_ids = [str(value) for value in faction.get("bible_hero_ids", [])]
        ensure(len(bible_hero_ids) >= 10 and len(set(bible_hero_ids)) == len(bible_hero_ids), errors, f"Faction {faction_id} must define at least ten unique bible_hero_ids")
        command_path_counts = {"might": 0, "magic": 0}
        for hero_id in bible_hero_ids:
            hero = heroes.get(hero_id, {})
            ensure(bool(hero), errors, f"Faction {faction_id} bible_hero_ids references missing hero {hero_id}")
            if not hero:
                continue
            ensure(str(hero.get("faction_id", "")) == faction_id, errors, f"Faction {faction_id} bible hero {hero_id} belongs to another faction")
            command_path = str(hero.get("command_path", ""))
            ensure(command_path in command_path_counts, errors, f"Faction {faction_id} bible hero {hero_id} must declare command_path might or magic")
            if command_path in command_path_counts:
                command_path_counts[command_path] += 1
        ensure(command_path_counts["might"] >= 5, errors, f"Faction {faction_id} must scaffold at least five might hero concepts")
        ensure(command_path_counts["magic"] >= 5, errors, f"Faction {faction_id} must scaffold at least five magic hero concepts")

        signature_building_ids = [str(value) for value in faction.get("signature_building_ids", [])]
        ensure(len(signature_building_ids) >= 7 and len(set(signature_building_ids)) == len(signature_building_ids), errors, f"Faction {faction_id} must define at least seven unique signature_building_ids")
        for building_id in signature_building_ids:
            building = buildings.get(building_id, {})
            ensure(bool(building), errors, f"Faction {faction_id} signature building {building_id} is missing")
            if building:
                ensure(str(building.get("content_status", "")) == "six_faction_scaffold", errors, f"Faction {faction_id} signature building {building_id} must be marked as six_faction_scaffold")

        seed_town_id = str(faction.get("seed_town_id", ""))
        ensure(bool(seed_town_id), errors, f"Faction {faction_id} must declare a seed_town_id")
        if faction_id in NEW_SIX_FACTION_SCAFFOLD_IDS:
            seed_town = towns.get(seed_town_id, {})
            ensure(bool(seed_town), errors, f"New bible faction {faction_id} seed town {seed_town_id} must be authored")
            if seed_town:
                ensure(str(seed_town.get("content_status", "")) == "six_faction_seed_town_not_scenario_integrated", errors, f"New bible faction {faction_id} seed town must be marked not scenario integrated")
                town_buildings = [str(value) for value in seed_town.get("starting_building_ids", [])] + [str(value) for value in seed_town.get("buildable_building_ids", [])]
                ensure(set(signature_building_ids).issubset(set(town_buildings)), errors, f"New bible faction {faction_id} seed town must carry all signature buildings")

    scaffold_heroes = [hero_id for hero_id, hero in heroes.items() if str(hero.get("roster_state", "")) == "scaffold"]
    ensure(bool(scaffold_heroes), errors, "Six-faction scaffold heroes must be marked with roster_state=scaffold")
    hero_command_text = HERO_COMMAND_RULES_PATH.read_text(encoding="utf-8")
    ensure("func _hero_recruitable_for_scenario" in hero_command_text, errors, "HeroCommandRules.gd must gate scaffold heroes before tavern recruitment")
    ensure('"allow_scaffold_roster"' in hero_command_text, errors, "HeroCommandRules.gd must support explicit scenario opt-in for scaffold hero rosters")


def validate_project_and_scenes(errors: list[str]) -> None:
    project_path = ROOT / "project.godot"
    ensure(project_path.exists(), errors, "Missing project.godot")
    if not project_path.exists():
        return

    project_text = project_path.read_text(encoding="utf-8")
    main_scene_match = re.search(r'run/main_scene="([^"]+)"', project_text)
    ensure(main_scene_match is not None, errors, "project.godot is missing run/main_scene")
    if main_scene_match:
        main_scene = ROOT / main_scene_match.group(1).replace("res://", "")
        ensure(main_scene.exists(), errors, f"Main scene is missing: {main_scene.relative_to(ROOT)}")

    viewport_width_match = re.search(r"^window/size/viewport_width=(\d+)", project_text, flags=re.MULTILINE)
    viewport_height_match = re.search(r"^window/size/viewport_height=(\d+)", project_text, flags=re.MULTILINE)
    ensure(viewport_width_match is not None, errors, "project.godot is missing display/window/size/viewport_width")
    ensure(viewport_height_match is not None, errors, "project.godot is missing display/window/size/viewport_height")
    if viewport_width_match is not None:
        ensure(int(viewport_width_match.group(1)) == 1920, errors, "project.godot must target a 1920 viewport width")
    if viewport_height_match is not None:
        ensure(int(viewport_height_match.group(1)) == 1080, errors, "project.godot must target a 1080 viewport height")
    ensure(
        'window/stretch/mode="canvas_items"' in project_text,
        errors,
        "project.godot must use canvas_items stretch for the 1080p presentation baseline",
    )
    ensure(
        'window/stretch/aspect="expand"' in project_text,
        errors,
        "project.godot must expand the 1080p presentation baseline instead of letterboxing UI surfaces",
    )

    autoload_entries = re.findall(r'^([A-Za-z0-9_]+)="[*]?(res://[^"]+)"', project_text, flags=re.MULTILINE)
    for autoload_name, autoload_path in autoload_entries:
        file_path = ROOT / autoload_path.replace("res://", "")
        ensure(file_path.exists(), errors, f"Autoload target is missing: {file_path.relative_to(ROOT)}")
        if file_path.exists():
            script_text = file_path.read_text(encoding="utf-8")
            class_name_match = re.search(r"^\s*class_name\s+([A-Za-z_][A-Za-z0-9_]*)", script_text, flags=re.MULTILINE)
            ensure(
                class_name_match is None or class_name_match.group(1) != autoload_name,
                errors,
                f"Autoload {autoload_name} must not share its name with class_name in {file_path.relative_to(ROOT)}",
            )

    for scene_path in sorted((ROOT / "scenes").rglob("*.tscn")):
        text = scene_path.read_text(encoding="utf-8")
        for ext_path in re.findall(r'path="(res://[^"]+)"', text):
            file_path = ROOT / ext_path.replace("res://", "")
            ensure(file_path.exists(), errors, f"Scene {scene_path.relative_to(ROOT)} references missing resource {file_path.relative_to(ROOT)}")

        script_match = re.search(r'\[ext_resource type="Script" path="(res://[^"]+)"', text)
        if not script_match:
            continue
        script_path = ROOT / script_match.group(1).replace("res://", "")
        if not script_path.exists():
            continue
        script_text = script_path.read_text(encoding="utf-8")
        for method in re.findall(r'method="([^"]+)"', text):
            ensure(
                re.search(rf"func\s+{re.escape(method)}\s*\(", script_text) is not None,
                errors,
                f"Scene {scene_path.relative_to(ROOT)} connects missing method {method} in {script_path.relative_to(ROOT)}",
            )


def validate_save_management(errors: list[str]) -> None:
    ensure(SAVE_SERVICE_PATH.exists(), errors, f"Missing save service script: {SAVE_SERVICE_PATH.relative_to(ROOT)}")
    if not SAVE_SERVICE_PATH.exists():
        return

    save_text = SAVE_SERVICE_PATH.read_text(encoding="utf-8")
    manual_slots_match = re.search(r"const\s+MANUAL_SLOT_IDS\s*:=\s*\[([^\]]+)\]", save_text)
    ensure(manual_slots_match is not None, errors, "SaveService.gd must declare MANUAL_SLOT_IDS")
    if manual_slots_match is not None:
        slot_ids = [part.strip() for part in manual_slots_match.group(1).split(",") if part.strip()]
        ensure(len(slot_ids) >= 2, errors, "SaveService.gd must expose at least two manual save slots")

    for required_token in (
        "const AUTOSAVE_FILE",
        "const SAVE_METADATA_TIMESTAMP_KEY",
        "func save_autosave_session",
        "func save_runtime_manual_session",
        "func save_runtime_autosave_session",
        "func save_runtime_selected_manual_session",
        "func build_in_session_save_surface",
        "func inspect_autosave",
        "func list_session_summaries",
        "func restore_session_from_summary",
        "func refresh_summary",
        "func load_action_label",
        "func continue_action_label",
        "func _save_runtime_session",
        "func _runtime_save_message",
        "func _latest_context_line",
        "func _return_to_menu_tooltip",
        "func _payload_structure_report",
        "func _has_core_overworld_state",
        '"resume_target"',
    ):
        ensure(required_token in save_text, errors, f"SaveService.gd is missing required save-management API token: {required_token}")

    main_menu_script_text = MAIN_MENU_SCRIPT_PATH.read_text(encoding="utf-8")
    for required_token in (
        "SaveService.continue_action_label",
        "SaveService.load_action_label",
        "SaveService.load_action_tooltip",
        "AppRouter.resume_latest_session",
        "AppRouter.resume_summary",
        "AppRouter.consume_menu_notice",
    ):
        ensure(required_token in main_menu_script_text, errors, f"MainMenu.gd is missing required save-browser state token: {required_token}")

    ensure(MAIN_MENU_SCENE_PATH.exists(), errors, "Missing main menu scene for save browser validation")
    if MAIN_MENU_SCENE_PATH.exists():
        main_menu_text = MAIN_MENU_SCENE_PATH.read_text(encoding="utf-8")
        ensure(scene_has_node(main_menu_text, "MenuTabs", "TabContainer"), errors, "MainMenu.tscn must define a MenuTabs container")
        ensure(scene_has_node(main_menu_text, "Saves", "VBoxContainer"), errors, "MainMenu.tscn must define a Saves tab")
        ensure(scene_has_node(main_menu_text, "SaveList", "ItemList"), errors, "MainMenu.tscn must define a SaveList item browser")
        ensure(scene_has_node(main_menu_text, "SaveDetails", "Label"), errors, "MainMenu.tscn must define a SaveDetails label")
        ensure(scene_has_node(main_menu_text, "LoadSelected", "Button"), errors, "MainMenu.tscn must define a LoadSelected button")


def validate_skirmish_setup(errors: list[str]) -> None:
    ensure(SESSION_STATE_PATH.exists(), errors, f"Missing session state script: {SESSION_STATE_PATH.relative_to(ROOT)}")
    ensure(SCENARIO_SELECT_RULES_PATH.exists(), errors, f"Missing scenario select rules script: {SCENARIO_SELECT_RULES_PATH.relative_to(ROOT)}")
    ensure(SCENARIO_RULES_PATH.exists(), errors, f"Missing scenario rules script: {SCENARIO_RULES_PATH.relative_to(ROOT)}")
    ensure(MAIN_MENU_SCRIPT_PATH.exists(), errors, f"Missing main menu script: {MAIN_MENU_SCRIPT_PATH.relative_to(ROOT)}")
    ensure(MAIN_MENU_SCENE_PATH.exists(), errors, f"Missing main menu scene: {MAIN_MENU_SCENE_PATH.relative_to(ROOT)}")
    if not all(
        path.exists()
        for path in (
            SESSION_STATE_PATH,
            SCENARIO_SELECT_RULES_PATH,
            SCENARIO_RULES_PATH,
            MAIN_MENU_SCRIPT_PATH,
            MAIN_MENU_SCENE_PATH,
        )
    ):
        return

    session_text = SESSION_STATE_PATH.read_text(encoding="utf-8")
    for required_token in (
        "const SAVE_VERSION := 9",
        "const LAUNCH_MODE_CAMPAIGN",
        "const LAUNCH_MODE_SKIRMISH",
        '"launch_mode"',
    ):
        ensure(required_token in session_text, errors, f"SessionState.gd is missing required skirmish/session token: {required_token}")

    save_text = SAVE_SERVICE_PATH.read_text(encoding="utf-8")
    for required_token in ('"launch_mode"', '"difficulty"', "ScenarioSelectRules.launch_mode_label", "ScenarioSelectRules.difficulty_label"):
        ensure(required_token in save_text, errors, f"SaveService.gd is missing required skirmish summary token: {required_token}")

    scenario_select_text = SCENARIO_SELECT_RULES_PATH.read_text(encoding="utf-8")
    ensure_script_functions(
        scenario_select_text,
        errors,
        "ScenarioSelectRules.gd",
        [
            "default_difficulty_id",
            "normalize_difficulty",
            "build_difficulty_options",
            "build_current_session_summary",
            "build_skirmish_browser_entries",
            "build_skirmish_setup",
            "start_skirmish_session",
            "describe_scenario_commander_preview",
            "describe_session_commander_preview",
        ],
    )
    for required_token in (
        '"operational_board"',
        '"commander_preview"',
        "SpellRulesScript.describe_spellbook",
        "ArtifactRulesScript.describe_loadout",
        "ScenarioRulesScript.describe_scenario_operational_board",
        "ScenarioFactoryScript.create_session",
        "SessionStateStoreScript.LAUNCH_MODE_SKIRMISH",
    ):
        ensure(required_token in scenario_select_text, errors, f"ScenarioSelectRules.gd is missing required skirmish token: {required_token}")

    scenario_rules_text = SCENARIO_RULES_PATH.read_text(encoding="utf-8")
    ensure_script_functions(
        scenario_rules_text,
        errors,
        "ScenarioRules.gd",
        [
            "describe_scenario_briefing",
            "describe_scenario_operational_board",
            "describe_session_operational_board",
        ],
    )
    for required_token in (
        "SessionStateStoreScript.normalize_launch_mode(session.launch_mode)",
        "EnemyAdventureRulesScript.public_strategy_summary",
        "Reinforcement risk:",
        "Likely first contact:",
        "Operational Board",
    ):
        ensure(required_token in scenario_rules_text, errors, f"ScenarioRules.gd is missing required skirmish/session token: {required_token}")

    main_menu_scene_text = MAIN_MENU_SCENE_PATH.read_text(encoding="utf-8")
    for node_name, node_type in (
        ("ModeSplit", "HBoxContainer"),
        ("CampaignPanel", "VBoxContainer"),
        ("SkirmishPanel", "VBoxContainer"),
        ("SkirmishScroll", "ScrollContainer"),
        ("SkirmishList", "ItemList"),
        ("DifficultyPicker", "OptionButton"),
        ("SetupSummary", "Label"),
        ("SkirmishCommanderPreviewTitle", "Label"),
        ("SkirmishCommanderPreview", "Label"),
        ("SkirmishOperationalBoardTitle", "Label"),
        ("SkirmishOperationalBoard", "Label"),
        ("StartSkirmish", "Button"),
    ):
        ensure(scene_has_node(main_menu_scene_text, node_name, node_type), errors, f"MainMenu.tscn must define {node_name} ({node_type}) for skirmish setup")

    main_menu_script_text = MAIN_MENU_SCRIPT_PATH.read_text(encoding="utf-8")
    for required_token in (
        "ScenarioSelectRulesScript.build_skirmish_browser_entries",
        "ScenarioSelectRulesScript.build_skirmish_setup",
        "ScenarioSelectRulesScript.start_skirmish_session",
        "_skirmish_commander_preview_label",
        "_skirmish_operational_board_label",
        "func _on_start_skirmish_pressed",
        "func _on_difficulty_selected",
    ):
        ensure(required_token in main_menu_script_text, errors, f"MainMenu.gd is missing required skirmish setup token: {required_token}")

    for scene_name in ("overworld/OverworldShell.tscn", "town/TownShell.tscn"):
        scene_path = ROOT / "scenes" / scene_name
        ensure(scene_path.exists(), errors, f"Missing scene required for save-slot selection: {scene_name}")
        if not scene_path.exists():
            continue
        scene_text = scene_path.read_text(encoding="utf-8")
        ensure(scene_has_node(scene_text, "SaveSlot", "OptionButton"), errors, f"{scene_name} must define a SaveSlot option button")


def validate_campaign_browser(errors: list[str]) -> None:
    required_paths = (
        CAMPAIGN_RULES_PATH,
        CAMPAIGN_PROGRESSION_PATH,
        SAVE_SERVICE_PATH,
        MAIN_MENU_SCENE_PATH,
        MAIN_MENU_SCRIPT_PATH,
    )
    for path in required_paths:
        ensure(path.exists(), errors, f"Missing campaign-browser integration file: {path.relative_to(ROOT)}")
    if not all(path.exists() for path in required_paths):
        return

    campaign_rules_text = CAMPAIGN_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        "func campaign_ids",
        "func selected_campaign_id",
        "func build_campaign_browser_entries",
        "func build_campaign_chapter_entries",
        "func describe_campaign_details",
        "func describe_campaign_arc_status",
        "func describe_campaign_chapter",
        "func describe_campaign_commander_preview",
        "func describe_campaign_operational_board",
        "func describe_campaign_journal",
        "func build_chapter_action",
        "func mark_selected_campaign",
        "_campaign_arc_status_lines",
        "_campaign_completion_title",
        "_final_scenario_entry",
        "_chapter_briefing_lines",
        "_campaign_journal_lines",
        '"campaign_chapter_label"',
    ):
        ensure(required_token in campaign_rules_text, errors, f"CampaignRules.gd is missing required campaign-browser token: {required_token}")

    campaign_progression_text = CAMPAIGN_PROGRESSION_PATH.read_text(encoding="utf-8")
    for required_token in (
        "func selected_campaign_id",
        "func selected_scenario_id",
        "func select_campaign",
        "func select_scenario",
        "func campaign_browser_entries",
        "func campaign_details",
        "func campaign_arc_status",
        "func chapter_commander_preview",
        "func chapter_operational_board",
        "func campaign_journal",
        "func campaign_chapter_entries",
        "func chapter_details",
        "func primary_campaign_action",
        "func chapter_action",
        "func start_primary_campaign_scenario",
    ):
        ensure(required_token in campaign_progression_text, errors, f"CampaignProgression.gd is missing required campaign-browser token: {required_token}")

    save_text = SAVE_SERVICE_PATH.read_text(encoding="utf-8")
    for required_token in ('"campaign_id"', '"campaign_name"', '"chapter_label"', '"campaign_chapter_label"'):
        ensure(required_token in save_text, errors, f"SaveService.gd is missing required campaign-summary token: {required_token}")

    main_menu_scene_text = MAIN_MENU_SCENE_PATH.read_text(encoding="utf-8")
    for node_name, node_type in (
        ("CampaignPanel", "VBoxContainer"),
        ("CampaignScroll", "ScrollContainer"),
        ("CampaignBrowser", "HBoxContainer"),
        ("CampaignList", "ItemList"),
        ("CampaignDetails", "Label"),
        ("CampaignArcTitle", "Label"),
        ("CampaignArcStatus", "Label"),
        ("ChapterBrowser", "HBoxContainer"),
        ("ChapterList", "ItemList"),
        ("ChapterDetails", "Label"),
        ("CommanderPreviewTitle", "Label"),
        ("CampaignCommanderPreview", "Label"),
        ("OperationalBoardTitle", "Label"),
        ("CampaignOperationalBoard", "Label"),
        ("JournalTitle", "Label"),
        ("CampaignJournal", "Label"),
        ("CampaignActions", "HBoxContainer"),
        ("CampaignPrimaryAction", "Button"),
        ("StartChapter", "Button"),
    ):
        ensure(scene_has_node(main_menu_scene_text, node_name, node_type), errors, f"MainMenu.tscn must define {node_name} ({node_type}) for the campaign browser")

    main_menu_script_text = MAIN_MENU_SCRIPT_PATH.read_text(encoding="utf-8")
    for required_token in (
        "CampaignProgression.campaign_browser_entries",
        "CampaignProgression.campaign_details",
        "CampaignProgression.campaign_arc_status",
        "CampaignProgression.chapter_commander_preview",
        "CampaignProgression.chapter_operational_board",
        "CampaignProgression.campaign_journal",
        "CampaignProgression.campaign_chapter_entries",
        "CampaignProgression.chapter_details",
        "CampaignProgression.primary_campaign_action",
        "CampaignProgression.chapter_action",
        "CampaignProgression.select_campaign",
        "CampaignProgression.select_scenario",
        "_campaign_arc_status_label",
        "_campaign_commander_preview_label",
        "_campaign_operational_board_label",
        "_campaign_journal_label",
        "func _on_campaign_selected",
        "func _on_chapter_selected",
        "func _on_campaign_primary_pressed",
        "func _on_start_chapter_pressed",
        "func _launch_campaign_action",
    ):
        ensure(required_token in main_menu_script_text, errors, f"MainMenu.gd is missing required campaign-browser token: {required_token}")


def validate_settings_and_onboarding(errors: list[str]) -> None:
    project_path = ROOT / "project.godot"
    required_paths = (
        project_path,
        SETTINGS_SERVICE_PATH,
        MAIN_MENU_SCENE_PATH,
        MAIN_MENU_SCRIPT_PATH,
    )
    for path in required_paths:
        ensure(path.exists(), errors, f"Missing settings/onboarding integration file: {path.relative_to(ROOT)}")
    if not all(path.exists() for path in required_paths):
        return

    project_text = project_path.read_text(encoding="utf-8")
    ensure(
        'SettingsService="*res://scripts/autoload/SettingsService.gd"' in project_text,
        errors,
        "project.godot must register SettingsService as an autoload",
    )

    settings_text = SETTINGS_SERVICE_PATH.read_text(encoding="utf-8")
    for required_token in (
        "const SETTINGS_FILE",
        "ConfigFile",
        "func load_settings",
        "func save_settings",
        "func build_presentation_options",
        "func build_resolution_options",
        "func describe_settings",
        "func build_help_topics",
        "func help_browser_summary",
        "func describe_help_topic",
        "func set_master_volume_percent",
        "func set_music_volume_percent",
        "func set_presentation_mode",
        "func set_presentation_resolution",
        "func set_large_ui_text_enabled",
        "func set_reduced_motion_enabled",
        '"resolution"',
        "DisplayServer.window_set_mode",
        "DisplayServer.window_set_size",
        "AudioServer.set_bus_volume_db",
        "content_scale_factor",
    ):
        ensure(required_token in settings_text, errors, f"SettingsService.gd is missing required settings/onboarding token: {required_token}")

    resolution_options = extract_settings_resolution_options(settings_text, errors)
    expected_resolutions = {"1280x720", "1600x900", "1920x1080", "2560x1440"}
    missing_resolutions = sorted(expected_resolutions - set(resolution_options.keys()))
    ensure(not missing_resolutions, errors, f"SettingsService.gd is missing expected 16:9 desktop resolutions: {', '.join(missing_resolutions)}")
    for option_id, (width, height) in resolution_options.items():
        ensure(f"{width}x{height}" == option_id, errors, f"Resolution option {option_id} must match its width/height payload")
        ensure(width * 9 == height * 16, errors, f"Resolution option {option_id} must be exactly 16:9")
        ensure(width <= 2560 and height <= 1440, errors, f"Resolution option {option_id} must not exceed the 1440p runtime cap")
    ensure(resolution_options.get("1920x1080") == (1920, 1080), errors, "SettingsService.gd must keep 1920x1080 as a selectable runtime resolution")

    main_menu_scene_text = MAIN_MENU_SCENE_PATH.read_text(encoding="utf-8")
    for node_name, node_type in (
        ("ActionRow", "HBoxContainer"),
        ("MenuTabs", "TabContainer"),
        ("Guide", "VBoxContainer"),
        ("HelpList", "ItemList"),
        ("HelpDetails", "Label"),
        ("Settings", "VBoxContainer"),
        ("SettingsSummary", "Label"),
        ("PresentationModePicker", "OptionButton"),
        ("ResolutionPicker", "OptionButton"),
        ("MasterVolumeSlider", "HSlider"),
        ("MusicVolumeSlider", "HSlider"),
        ("LargeTextToggle", "CheckButton"),
        ("ReduceMotionToggle", "CheckButton"),
    ):
        ensure(scene_has_node(main_menu_scene_text, node_name, node_type), errors, f"MainMenu.tscn must define {node_name} ({node_type}) for settings/onboarding")

    main_menu_script_text = MAIN_MENU_SCRIPT_PATH.read_text(encoding="utf-8")
    for required_token in (
        "SettingsService.ensure_settings",
        "SettingsService.help_browser_summary",
        "SettingsService.build_help_topics",
        "SettingsService.describe_help_topic",
        "SettingsService.describe_settings",
        "SettingsService.build_presentation_options",
        "SettingsService.build_resolution_options",
        "SettingsService.set_master_volume_percent",
        "SettingsService.set_music_volume_percent",
        "SettingsService.set_presentation_mode",
        "SettingsService.set_presentation_resolution",
        "SettingsService.set_large_ui_text_enabled",
        "SettingsService.set_reduced_motion_enabled",
        "func _on_help_selected",
        "func _on_presentation_mode_selected",
        "func _on_resolution_selected",
        "func _on_master_volume_changed",
        "func _on_music_volume_changed",
        "func _on_large_text_toggled",
        "func _on_reduce_motion_toggled",
        "func _refresh_settings_panel",
        "func _rebuild_help_browser",
        "func validation_open_settings_stage",
        "func validation_select_resolution",
    ):
        ensure(required_token in main_menu_script_text, errors, f"MainMenu.gd is missing required settings/onboarding token: {required_token}")


def validate_main_menu_first_view(errors: list[str]) -> None:
    ensure(MAIN_MENU_SCENE_PATH.exists(), errors, "Missing main menu scene for first-view composition validation")
    ensure(MAIN_MENU_SCRIPT_PATH.exists(), errors, "Missing main menu script for first-view composition validation")
    if not MAIN_MENU_SCENE_PATH.exists() or not MAIN_MENU_SCRIPT_PATH.exists():
        return

    main_menu_scene_text = MAIN_MENU_SCENE_PATH.read_text(encoding="utf-8")
    ensure(
        scene_has_node(main_menu_scene_text, "BackdropCommandHotspots", "Control"),
        errors,
        "MainMenu.tscn must map first-view commands onto BackdropCommandHotspots instead of a command panel",
    )
    expected_plaque_buttons = {
        "OpenCampaign": "Campaign",
        "OpenSkirmish": "Skirmish",
        "OpenSaves": "Load",
        "OpenSettings": "Settings",
        "Quit": "Quit",
    }
    for node_name, label in expected_plaque_buttons.items():
        pattern = (
            rf'\[node name="{re.escape(node_name)}" type="Button" parent="BackdropCommandHotspots"\]'
            rf'(?:(?!\n\[node ).)*?\ntext = "{re.escape(label)}"'
        )
        ensure(
            re.search(pattern, main_menu_scene_text, flags=re.DOTALL) is not None,
            errors,
            f"MainMenu.tscn must expose first-view {label} as a painted backdrop hotspot",
        )
    lower_plaque_bounds = {
        "OpenSaves": ("0.473", "0.523"),
        "OpenSettings": ("0.611", "0.66"),
        "Quit": ("0.749", "0.798"),
    }
    for node_name, (anchor_top, anchor_bottom) in lower_plaque_bounds.items():
        block_match = re.search(
            rf'\[node name="{re.escape(node_name)}" type="Button" parent="BackdropCommandHotspots"\]'
            rf'(?P<body>(?:(?!\n\[node ).)*)',
            main_menu_scene_text,
            flags=re.DOTALL,
        )
        block = block_match.group("body") if block_match else ""
        ensure(
            re.search(rf"anchor_top\s*=\s*{re.escape(anchor_top)}(?:\s|$)", block) is not None
            and re.search(rf"anchor_bottom\s*=\s*{re.escape(anchor_bottom)}(?:\s|$)", block) is not None,
            errors,
            f"MainMenu.tscn must keep {node_name} centered on its painted lower plaque",
        )

    for removed_node, node_type in (
        ("CommandSpinePanel", "PanelContainer"),
        ("SpineStatusPanel", "PanelContainer"),
        ("CommandBlockPanel", "PanelContainer"),
        ("RightShade", "ColorRect"),
        ("Continue", "Button"),
        ("OpenGuide", "Button"),
        ("Menu", "Button"),
    ):
        ensure(
            not scene_has_node(main_menu_scene_text, removed_node, node_type),
            errors,
            f"MainMenu.tscn must not restore first-view {removed_node} ({node_type})",
        )

    main_menu_script_text = MAIN_MENU_SCRIPT_PATH.read_text(encoding="utf-8")
    for required_token in (
        '"painted_backdrop_hotspots"',
        '"first_view_commands"',
        "func _apply_backdrop_plaque_button",
        "func _latest_continue_surface",
        'button.add_theme_color_override("font_color", highlight_color if active else normal_color)',
        'button.add_theme_stylebox_override("hover", transparent_style.duplicate())',
    ):
        ensure(required_token in main_menu_script_text, errors, f"MainMenu.gd is missing required first-view menu token: {required_token}")
    ensure("_open_guide_button" not in main_menu_script_text, errors, "MainMenu.gd must not keep a first-view Guide button binding")
    ensure("active_style" not in main_menu_script_text, errors, "MainMenu.gd must not draw an active rounded plaque box")
    ensure('"hover", hover' not in main_menu_script_text, errors, "MainMenu.gd must not draw a hover rounded plaque box")
    ensure('"pressed", pressed' not in main_menu_script_text, errors, "MainMenu.gd must not draw a pressed rounded plaque box")


def validate_scenario_outcome_shell(errors: list[str]) -> None:
    required_paths = (
        APP_ROUTER_PATH,
        SCENARIO_RULES_PATH,
        CAMPAIGN_RULES_PATH,
        CAMPAIGN_PROGRESSION_PATH,
        SCENARIO_SELECT_RULES_PATH,
        OUTCOME_SCENE_PATH,
        OUTCOME_SCRIPT_PATH,
        OVERWORLD_SCRIPT_PATH,
        TOWN_SCRIPT_PATH,
        BATTLE_SCRIPT_PATH,
    )
    for path in required_paths:
        ensure(path.exists(), errors, f"Missing scenario-outcome integration file: {path.relative_to(ROOT)}")
    if not all(path.exists() for path in required_paths):
        return

    session_text = SESSION_STATE_PATH.read_text(encoding="utf-8")
    ensure("const SAVE_VERSION := 9" in session_text, errors, "Scenario outcome shell must preserve save version 9")

    app_router_text = APP_ROUTER_PATH.read_text(encoding="utf-8")
    for required_token in (
        "const SCENARIO_OUTCOME_SCENE",
        "func go_to_scenario_outcome",
        "SaveService.save_runtime_autosave_session(session)",
        "func save_active_session_to_selected_manual_slot",
        "func resume_summary",
        "func resume_latest_session",
        "func consume_menu_notice",
        "go_to_scenario_outcome()",
    ):
        ensure(required_token in app_router_text, errors, f"AppRouter.gd is missing required scenario-outcome token: {required_token}")

    scenario_rules_text = SCENARIO_RULES_PATH.read_text(encoding="utf-8")
    ensure_script_functions(
        scenario_rules_text,
        errors,
        "ScenarioRules.gd",
        [
            "build_outcome_model",
            "perform_outcome_action",
            "describe_scenario_briefing",
        ],
    )
    for required_token in (
        "CampaignProgression.outcome_recap",
        "CampaignProgression.outcome_actions",
        "ScenarioSelectRules.start_skirmish_session",
        '"campaign_arc_summary"',
        '"aftermath_summary"',
        '"journal_summary"',
        "OverworldRules.describe_hero",
        "OverworldRules.describe_army",
        "OverworldRules.describe_resources",
    ):
        ensure(required_token in scenario_rules_text, errors, f"ScenarioRules.gd is missing required scenario-outcome token: {required_token}")

    campaign_rules_text = CAMPAIGN_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        "func campaign_id_for_session",
        "func build_outcome_recap",
        "func build_outcome_actions",
        "func describe_campaign_arc_status",
        "func describe_campaign_journal",
        "_campaign_arc_outcome_lines",
        "_chapter_aftermath_text",
        "Latest chronicle:",
        "Operational aftermath:",
        "Next chapter unlocked",
        "Carryover export is only banked on victory.",
    ):
        ensure(required_token in campaign_rules_text, errors, f"CampaignRules.gd is missing required outcome-recap token: {required_token}")

    campaign_progression_text = CAMPAIGN_PROGRESSION_PATH.read_text(encoding="utf-8")
    for required_token in ("func campaign_id_for_session", "func outcome_recap", "func outcome_actions"):
        ensure(required_token in campaign_progression_text, errors, f"CampaignProgression.gd is missing required outcome-recap token: {required_token}")

    outcome_scene_text = OUTCOME_SCENE_PATH.read_text(encoding="utf-8")
    ensure_scene_nodes(
        outcome_scene_text,
        errors,
        "ScenarioOutcomeShell.tscn",
        [
            ("Header", "Label"),
            ("Summary", "Label"),
            ("Mode", "Label"),
            ("ForceCards", "HBoxContainer"),
            ("Hero", "Label"),
            ("Army", "Label"),
            ("Resources", "Label"),
            ("Progression", "Label"),
            ("CampaignArc", "Label"),
            ("Carryover", "Label"),
            ("Aftermath", "Label"),
            ("Journal", "Label"),
            ("ActionStatus", "Label"),
            ("Actions", "HFlowContainer"),
            ("SaveBar", "HFlowContainer"),
        ],
    )

    outcome_script_text = OUTCOME_SCRIPT_PATH.read_text(encoding="utf-8")
    for required_token in (
        "ScenarioRules.build_outcome_model",
        "ScenarioRules.perform_outcome_action",
        "func _rebuild_actions",
        "func _on_action_pressed",
        "_campaign_arc_label",
        "_aftermath_label",
        "_journal_label",
        '"campaign_arc_summary"',
        '"aftermath_summary"',
        '"journal_summary"',
        "AppRouter.go_to_overworld()",
        "AppRouter.return_to_main_menu_from_active_play()",
    ):
        ensure(required_token in outcome_script_text, errors, f"ScenarioOutcomeShell.gd is missing required outcome-shell token: {required_token}")

    scenario_select_text = SCENARIO_SELECT_RULES_PATH.read_text(encoding="utf-8")
    for required_token in ("ScenarioRulesScript.describe_scenario_briefing", "setup_summary"):
        ensure(required_token in scenario_select_text, errors, f"ScenarioSelectRules.gd is missing required briefing token: {required_token}")

    for script_path in (OVERWORLD_SCRIPT_PATH, TOWN_SCRIPT_PATH, BATTLE_SCRIPT_PATH):
        script_text = script_path.read_text(encoding="utf-8")
        ensure("AppRouter.go_to_scenario_outcome()" in script_text, errors, f"{script_path.relative_to(ROOT)} must route resolved sessions into the outcome shell")


def validate_difficulty_integration(errors: list[str]) -> None:
    required_paths = (
        DIFFICULTY_RULES_PATH,
        HERO_COMMAND_RULES_PATH,
        SCENARIO_FACTORY_PATH,
        OVERWORLD_RULES_PATH,
        BATTLE_RULES_PATH,
        BATTLE_AI_RULES_PATH,
        ENEMY_TURN_RULES_PATH,
        ENEMY_ADVENTURE_RULES_PATH,
    )
    for path in required_paths:
        ensure(path.exists(), errors, f"Missing difficulty integration script: {path.relative_to(ROOT)}")
    if not all(path.exists() for path in required_paths):
        return

    difficulty_text = DIFFICULTY_RULES_PATH.read_text(encoding="utf-8")
    ensure_script_functions(
        difficulty_text,
        errors,
        "DifficultyRules.gd",
        [
            "normalize_difficulty",
            "profile_for_difficulty",
            "profile_for_session",
            "normalize_session",
            "movement_bonus",
            "scale_income_resources",
            "scale_reward_resources",
            "adjust_enemy_pressure_gain",
            "adjust_raid_threshold",
            "scale_raid_pillage",
            "initiative_bonus_for_side",
            "damage_multiplier_for_side",
        ],
    )
    for required_token in ("const DIFFICULTY_PROFILES", '"story"', '"normal"', '"hard"'):
        ensure(required_token in difficulty_text, errors, f"DifficultyRules.gd is missing required token: {required_token}")

    scenario_factory_text = SCENARIO_FACTORY_PATH.read_text(encoding="utf-8")
    for required_token in ("DifficultyRulesScript.normalize_difficulty", "HeroCommandRulesScript.build_hero_from_template"):
        ensure(required_token in scenario_factory_text, errors, f"ScenarioFactory.gd is missing required difficulty bootstrap token: {required_token}")

    overworld_text = OVERWORLD_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        "DifficultyRulesScript.normalize_session",
        "DifficultyRulesScript.scale_income_resources",
        "DifficultyRulesScript.scale_reward_resources",
        "DifficultyRulesScript.adjust_enemy_pressure_gain",
    ):
        ensure(required_token in overworld_text, errors, f"OverworldRules.gd is missing required difficulty token: {required_token}")

    hero_command_text = HERO_COMMAND_RULES_PATH.read_text(encoding="utf-8")
    for required_token in ("DifficultyRulesScript.movement_bonus", "DifficultyRulesScript.profile_for_difficulty"):
        ensure(required_token in hero_command_text, errors, f"HeroCommandRules.gd is missing required difficulty token: {required_token}")

    enemy_turn_text = ENEMY_TURN_RULES_PATH.read_text(encoding="utf-8")
    for required_token in ("DifficultyRulesScript.adjust_enemy_pressure_gain", "DifficultyRulesScript.adjust_raid_threshold"):
        ensure(required_token in enemy_turn_text, errors, f"EnemyTurnRules.gd is missing required difficulty token: {required_token}")

    enemy_adventure_text = ENEMY_ADVENTURE_RULES_PATH.read_text(encoding="utf-8")
    for required_token in ("DifficultyRulesScript.normalize_session", "DifficultyRulesScript.scale_raid_pillage"):
        ensure(required_token in enemy_adventure_text, errors, f"EnemyAdventureRules.gd is missing required difficulty token: {required_token}")

    battle_text = BATTLE_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        '"damage_multiplier"',
        '"initiative"',
        "DifficultyRulesScript.normalize_session",
        "DifficultyRulesScript.scale_reward_resources",
        "DifficultyRulesScript.initiative_bonus_for_side",
        "DifficultyRulesScript.damage_multiplier_for_side",
    ):
        ensure(required_token in battle_text, errors, f"BattleRules.gd is missing required difficulty token: {required_token}")

    battle_ai_text = BATTLE_AI_RULES_PATH.read_text(encoding="utf-8")
    for required_token in ("func _damage_multiplier_for_side", '_damage_multiplier_for_side(battle, String(attacker.get("side", "")))', '"damage_multiplier"'):
        ensure(required_token in battle_ai_text, errors, f"BattleAiRules.gd is missing required difficulty token: {required_token}")


def validate_hero_progression(errors: list[str]) -> None:
    required_paths = (
        HERO_PROGRESSION_RULES_PATH,
        HERO_COMMAND_RULES_PATH,
        SCENARIO_FACTORY_PATH,
        OVERWORLD_RULES_PATH,
        TOWN_RULES_PATH,
        CAMPAIGN_RULES_PATH,
        SPELL_RULES_PATH,
        BATTLE_RULES_PATH,
        ENEMY_ADVENTURE_RULES_PATH,
        SAVE_SERVICE_PATH,
        SCENARIO_SELECT_RULES_PATH,
        OVERWORLD_SCENE_PATH,
        OVERWORLD_SCRIPT_PATH,
        TOWN_SCENE_PATH,
        TOWN_SCRIPT_PATH,
    )
    for path in required_paths:
        ensure(path.exists(), errors, f"Missing hero progression integration file: {path.relative_to(ROOT)}")
    if not all(path.exists() for path in required_paths):
        return

    progression_text = HERO_PROGRESSION_RULES_PATH.read_text(encoding="utf-8")
    ensure_script_functions(
        progression_text,
        errors,
        "HeroProgressionRules.gd",
        [
            "ensure_hero_progression",
            "add_experience",
            "choose_specialty",
            "get_choice_actions",
            "describe_specialties",
            "brief_summary",
            "aggregate_bonuses",
            "summarize_specialty_ids",
            "scale_recruit_growth",
            "scale_recruit_cost",
            "mana_max_bonus",
            "adjusted_mana_cost",
            "scale_raid_pillage",
        ],
    )
    for required_token in (
        "const SPECIALTIES",
        '"wayfinder"',
        '"ledgerkeeper"',
        '"spellwright"',
        '"drillmaster"',
        '"armsmaster"',
        '"mustercaptain"',
        '"borderwarden"',
        '"specialty_focus_ids"',
        '"pending_specialty_choices"',
    ):
        ensure(required_token in progression_text, errors, f"HeroProgressionRules.gd is missing required token: {required_token}")

    scenario_factory_text = SCENARIO_FACTORY_PATH.read_text(encoding="utf-8")
    ensure("HeroProgressionRulesScript.ensure_hero_progression" in scenario_factory_text, errors, "ScenarioFactory.gd must initialize hero progression state")

    hero_command_text = HERO_COMMAND_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        "HeroProgressionRulesScript.ensure_hero_progression",
        "HeroProgressionRulesScript.aggregate_bonuses",
        "HeroProgressionRulesScript.summarize_specialty_ids",
    ):
        ensure(required_token in hero_command_text, errors, f"HeroCommandRules.gd is missing required hero progression token: {required_token}")
    ensure_script_functions(hero_command_text, errors, "HeroCommandRules.gd", ["hero_profile_summary", "hero_identity_summary"])

    overworld_text = OVERWORLD_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        "HeroProgressionRulesScript.add_experience",
        "HeroProgressionRulesScript.daily_income_bonus",
        "HeroProgressionRulesScript.scale_recruit_growth",
        "HeroProgressionRulesScript.scale_recruit_cost",
        "HeroProgressionRulesScript.describe_specialties",
        "HeroProgressionRulesScript.get_choice_actions",
        "HeroProgressionRulesScript.choose_specialty",
    ):
        ensure(required_token in overworld_text, errors, f"OverworldRules.gd is missing required hero progression token: {required_token}")

    town_rules_text = TOWN_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        "HeroProgressionRulesScript.describe_specialties",
        "HeroProgressionRulesScript.get_choice_actions",
        "OverworldRulesScript.town_recruit_cost",
    ):
        ensure(required_token in town_rules_text, errors, f"TownRules.gd is missing required hero progression token: {required_token}")
    ensure_script_functions(town_rules_text, errors, "TownRules.gd", ["choose_specialty_at_active_town"])

    spell_text = SPELL_RULES_PATH.read_text(encoding="utf-8")
    for required_token in ("HeroProgressionRulesScript.mana_max_bonus", "HeroProgressionRulesScript.adjusted_mana_cost"):
        ensure(required_token in spell_text, errors, f"SpellRules.gd is missing required hero progression token: {required_token}")

    battle_text = BATTLE_RULES_PATH.read_text(encoding="utf-8")
    ensure("HeroProgressionRulesScript.aggregate_bonuses" in battle_text, errors, "BattleRules.gd must merge specialty bonuses into battle hero payloads")

    enemy_adventure_text = ENEMY_ADVENTURE_RULES_PATH.read_text(encoding="utf-8")
    ensure("HeroProgressionRulesScript.scale_raid_pillage" in enemy_adventure_text, errors, "EnemyAdventureRules.gd must apply raid-resistance specialties")

    campaign_text = CAMPAIGN_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        '"specialties"',
        '"pending_specialty_choices"',
        "HeroProgressionRulesScript.ensure_hero_progression",
        "HeroProgressionRulesScript.brief_summary",
        "HeroProgressionRulesScript.summarize_specialty_ids",
    ):
        ensure(required_token in campaign_text, errors, f"CampaignRules.gd is missing required hero progression token: {required_token}")

    save_text = SAVE_SERVICE_PATH.read_text(encoding="utf-8")
    ensure("hero_specialties_summary" in save_text, errors, "SaveService.gd must surface hero specialties in save summaries")

    scenario_select_text = SCENARIO_SELECT_RULES_PATH.read_text(encoding="utf-8")
    for required_token in ("HeroProgressionRulesScript.brief_summary", "HeroCommandRulesScript.hero_profile_summary", "HeroCommandRulesScript.hero_identity_summary"):
        ensure(required_token in scenario_select_text, errors, f"ScenarioSelectRules.gd is missing authored-hero summary token: {required_token}")

    overworld_scene_text = OVERWORLD_SCENE_PATH.read_text(encoding="utf-8")
    ensure_scene_nodes(
        overworld_scene_text,
        errors,
        "OverworldShell.tscn",
        [("Specialties", "Label"), ("SpecialtyActions", "VBoxContainer")],
    )

    town_scene_text = TOWN_SCENE_PATH.read_text(encoding="utf-8")
    ensure_scene_nodes(
        town_scene_text,
        errors,
        "TownShell.tscn",
        [("Specialties", "Label"), ("SpecialtyActions", "HFlowContainer")],
    )

    overworld_script_text = OVERWORLD_SCRIPT_PATH.read_text(encoding="utf-8")
    for required_token in ("func _on_specialty_action_pressed", "func _rebuild_specialty_actions", "OverworldRules.describe_specialties", "OverworldRules.get_specialty_actions"):
        ensure(required_token in overworld_script_text, errors, f"OverworldShell.gd is missing required hero progression token: {required_token}")

    town_script_text = TOWN_SCRIPT_PATH.read_text(encoding="utf-8")
    for required_token in ("func _on_specialty_action_pressed", "func _rebuild_specialty_actions", "TownRules.describe_specialties", "TownRules.get_specialty_actions"):
        ensure(required_token in town_script_text, errors, f"TownShell.gd is missing required hero progression token: {required_token}")


def validate_hero_command(errors: list[str]) -> None:
    required_paths = (
        HERO_COMMAND_RULES_PATH,
        SCENARIO_FACTORY_PATH,
        OVERWORLD_RULES_PATH,
        TOWN_RULES_PATH,
        BATTLE_RULES_PATH,
        CAMPAIGN_RULES_PATH,
        OVERWORLD_SCENE_PATH,
        OVERWORLD_SCRIPT_PATH,
        TOWN_SCENE_PATH,
        TOWN_SCRIPT_PATH,
    )
    for path in required_paths:
        ensure(path.exists(), errors, f"Missing hero-command integration file: {path.relative_to(ROOT)}")
    if not all(path.exists() for path in required_paths):
        return

    hero_command_text = HERO_COMMAND_RULES_PATH.read_text(encoding="utf-8")
    ensure_script_functions(
        hero_command_text,
        errors,
        "HeroCommandRules.gd",
        [
            "normalize_session",
            "build_hero_from_template",
            "hero_template",
            "hero_profile_summary",
            "hero_identity_summary",
            "set_active_hero",
            "get_overworld_switch_actions",
            "get_town_switch_actions",
            "get_tavern_actions",
            "recruit_hero_at_town",
            "get_town_transfer_actions",
            "transfer_town_stack",
            "remove_active_hero_after_defeat",
            "stationed_heroes",
            "describe_tavern",
            "describe_town_transfer",
        ],
    )
    for required_token in ("const HALL_BUILDING_ID", "const HERO_LIMIT", '"player_heroes"', '"active_hero_id"', '"is_primary"'):
        ensure(required_token in hero_command_text, errors, f"HeroCommandRules.gd is missing required hero-command token: {required_token}")

    scenario_factory_text = SCENARIO_FACTORY_PATH.read_text(encoding="utf-8")
    for required_token in ('"active_hero_id"', '"player_heroes"', "HeroCommandRulesScript.build_hero_from_template"):
        ensure(required_token in scenario_factory_text, errors, f"ScenarioFactory.gd is missing required hero-command bootstrap token: {required_token}")

    overworld_text = OVERWORLD_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        "HeroCommandRulesScript.normalize_session",
        "func describe_heroes",
        "func get_hero_actions",
        "func switch_active_hero",
    ):
        ensure(required_token in overworld_text, errors, f"OverworldRules.gd is missing required hero-command token: {required_token}")

    town_rules_text = TOWN_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        "func describe_heroes",
        "func describe_tavern",
        "func describe_transfer",
        "func get_hero_actions",
        "func get_tavern_actions",
        "func get_transfer_actions",
        "func switch_active_hero_at_town",
        "func hire_hero_at_active_town",
        "func transfer_in_active_town",
    ):
        ensure(required_token in town_rules_text, errors, f"TownRules.gd is missing required hero-command token: {required_token}")

    battle_text = BATTLE_RULES_PATH.read_text(encoding="utf-8")
    for required_token in ("HeroCommandRulesScript.active_hero_is_primary", "HeroCommandRulesScript.remove_active_hero_after_defeat"):
        ensure(required_token in battle_text, errors, f"BattleRules.gd is missing required hero-command token: {required_token}")

    campaign_text = CAMPAIGN_RULES_PATH.read_text(encoding="utf-8")
    for required_token in ("HeroCommandRulesScript.primary_hero", "HeroCommandRulesScript.normalize_session", '"spell_ids"', '"artifacts"', '"specialties"'):
        ensure(required_token in campaign_text, errors, f"CampaignRules.gd is missing required hero-command token: {required_token}")

    overworld_scene_text = OVERWORLD_SCENE_PATH.read_text(encoding="utf-8")
    ensure_scene_nodes(
        overworld_scene_text,
        errors,
        "OverworldShell.tscn",
        [("Heroes", "Label"), ("HeroActions", "VBoxContainer")],
    )

    town_scene_text = TOWN_SCENE_PATH.read_text(encoding="utf-8")
    ensure_scene_nodes(
        town_scene_text,
        errors,
        "TownShell.tscn",
        [
            ("Heroes", "Label"),
            ("HeroActions", "HFlowContainer"),
            ("Tavern", "Label"),
            ("TavernActions", "HFlowContainer"),
            ("Transfer", "Label"),
            ("TransferActions", "HFlowContainer"),
        ],
    )

    overworld_script_text = OVERWORLD_SCRIPT_PATH.read_text(encoding="utf-8")
    for required_token in (
        "func _on_hero_action_pressed",
        "func _rebuild_hero_actions",
        "OverworldRules.describe_heroes",
        "OverworldRules.get_hero_actions",
        "OverworldRules.switch_active_hero",
        "_hero_actions",
        "_heroes_label",
    ):
        ensure(required_token in overworld_script_text, errors, f"OverworldShell.gd is missing required hero-command token: {required_token}")

    town_script_text = TOWN_SCRIPT_PATH.read_text(encoding="utf-8")
    for required_token in (
        "func _on_hero_action_pressed",
        "func _on_tavern_action_pressed",
        "func _on_transfer_action_pressed",
        "func _rebuild_hero_actions",
        "func _rebuild_tavern_actions",
        "func _rebuild_transfer_actions",
        "TownRules.describe_heroes",
        "TownRules.describe_tavern",
        "TownRules.describe_transfer",
        "TownRules.get_hero_actions",
        "TownRules.get_tavern_actions",
        "TownRules.get_transfer_actions",
    ):
        ensure(required_token in town_script_text, errors, f"TownShell.gd is missing required hero-command token: {required_token}")


def validate_overworld_fog(errors: list[str]) -> None:
    required_paths = (
        SESSION_STATE_PATH,
        HERO_PROGRESSION_RULES_PATH,
        HERO_COMMAND_RULES_PATH,
        SCENARIO_FACTORY_PATH,
        SCENARIO_SELECT_RULES_PATH,
        SCENARIO_SCRIPT_RULES_PATH,
        OVERWORLD_RULES_PATH,
        BATTLE_RULES_PATH,
        CAMPAIGN_RULES_PATH,
        OVERWORLD_SCRIPT_PATH,
    )
    for path in required_paths:
        ensure(path.exists(), errors, f"Missing fog/scouting integration file: {path.relative_to(ROOT)}")
    if not all(path.exists() for path in required_paths):
        return

    session_text = SESSION_STATE_PATH.read_text(encoding="utf-8")
    ensure("const SAVE_VERSION := 9" in session_text, errors, "Fog/scouting normalization should preserve save version 9 without a destructive bump")

    progression_text = HERO_PROGRESSION_RULES_PATH.read_text(encoding="utf-8")
    ensure('"scouting_radius"' in progression_text, errors, "HeroProgressionRules.gd must expose scouting_radius bonuses")

    hero_command_text = HERO_COMMAND_RULES_PATH.read_text(encoding="utf-8")
    for required_token in ("const BASE_SCOUT_RADIUS", "func scouting_radius_for_hero", 'Scout %d | %s'):
        ensure(required_token in hero_command_text, errors, f"HeroCommandRules.gd is missing required fog/scouting token: {required_token}")
    ensure("const BASE_SCOUT_RADIUS := 3" in hero_command_text, errors, "HeroCommandRules.gd must keep the raised base scout radius at 3")

    scenario_factory_text = SCENARIO_FACTORY_PATH.read_text(encoding="utf-8")
    ensure('"fog"' in scenario_factory_text, errors, "ScenarioFactory.gd must seed fog state in new overworld sessions")

    overworld_text = OVERWORLD_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        "const FOG_KEY",
        '"visible_tiles"',
        '"explored_tiles"',
        "func refresh_fog_of_war",
        "func is_tile_visible",
        "func is_tile_explored",
        "func describe_visibility",
        "HeroCommandRulesScript.scouting_radius_for_hero",
    ):
        ensure(required_token in overworld_text, errors, f"OverworldRules.gd is missing required fog/scouting token: {required_token}")

    battle_text = BATTLE_RULES_PATH.read_text(encoding="utf-8")
    ensure("OverworldRulesScript.refresh_fog_of_war" in battle_text, errors, "BattleRules.gd must refresh fog after overworld-facing battle outcomes")

    campaign_text = CAMPAIGN_RULES_PATH.read_text(encoding="utf-8")
    ensure("normalize_overworld_state(session)" in campaign_text, errors, "CampaignRules.gd must normalize fog/scouting state when building campaign sessions")

    scenario_select_text = SCENARIO_SELECT_RULES_PATH.read_text(encoding="utf-8")
    ensure("OverworldRulesScript.normalize_overworld_state" in scenario_select_text, errors, "ScenarioSelectRules.gd must normalize fog/scouting state for new skirmish sessions")

    scenario_script_text = SCENARIO_SCRIPT_RULES_PATH.read_text(encoding="utf-8")
    ensure("is_tile_visible" in scenario_script_text, errors, "ScenarioScriptRules.gd must hide scripted map-reveal details behind visibility checks")

    overworld_script_text = OVERWORLD_SCRIPT_PATH.read_text(encoding="utf-8")
    for required_token in (
        "OverworldRules.is_tile_visible",
        "OverworldRules.is_tile_explored",
        "OverworldRules.describe_visibility",
        "func _terrain_memory_label",
        "func _memory_cell_color",
    ):
        ensure(required_token in overworld_script_text, errors, f"OverworldShell.gd is missing required fog/scouting token: {required_token}")


def validate_battle_ability_layer(errors: list[str]) -> None:
    required_paths = (
        BATTLE_RULES_PATH,
        BATTLE_AI_RULES_PATH,
        SPELL_RULES_PATH,
        BATTLE_SCRIPT_PATH,
        BATTLE_SCENE_PATH,
    )
    for path in required_paths:
        ensure(path.exists(), errors, f"Missing battle-ability integration file: {path.relative_to(ROOT)}")
    if not all(path.exists() for path in required_paths):
        return

    battle_text = BATTLE_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        "STATUS_HARRIED",
        "STATUS_STAGGERED",
        '"abilities"',
        "func _normalize_unit_abilities",
        "func _can_make_melee_attack",
        "func _apply_attack_ability_effects",
        "func _apply_retaliation_ability_effects",
        "func _ability_damage_modifier",
        "SpellRulesScript.build_battle_effect",
        "SpellRulesScript.has_any_effect_ids",
    ):
        ensure(required_token in battle_text, errors, f"BattleRules.gd is missing required battle-ability token: {required_token}")

    battle_ai_text = BATTLE_AI_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        "STATUS_HARRIED",
        "STATUS_STAGGERED",
        "func _can_make_melee_attack",
        "func _ability_damage_modifier",
        "SpellRulesScript.has_effect_id",
        "SpellRulesScript.has_any_effect_ids",
    ):
        ensure(required_token in battle_ai_text, errors, f"BattleAiRules.gd is missing required battle-ability token: {required_token}")

    spell_text = SPELL_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        '\"modifiers\"',
        "func build_battle_effect",
        "func has_effect_id",
        "func has_any_effect_ids",
    ):
        ensure(required_token in spell_text, errors, f"SpellRules.gd is missing required battle-status token: {required_token}")

    battle_shell_text = BATTLE_SCRIPT_PATH.read_text(encoding="utf-8")
    for required_token in (
        "BattleRules.roster_lines",
        "BattleRules.get_action_surface",
        "_player_roster",
        "_enemy_roster",
        "_set_compact_label(_player_roster",
        "_set_compact_label(_enemy_roster",
    ):
        ensure(required_token in battle_shell_text, errors, f"BattleShell.gd is missing required battle-ability UI token: {required_token}")

    battle_scene_text = BATTLE_SCENE_PATH.read_text(encoding="utf-8")
    for node_name in ("PlayerRoster", "EnemyRoster", "Strike", "Shoot", "Defend"):
        ensure(
            f'[node name="{node_name}"' in battle_scene_text,
            errors,
            f"BattleShell.tscn is missing required battle UI node {node_name}",
        )


def validate_battle_shell_release_polish(errors: list[str]) -> None:
    required_paths = (BATTLE_SCENE_PATH, BATTLE_SCRIPT_PATH, BATTLE_RULES_PATH, SPELL_RULES_PATH)
    for path in required_paths:
        ensure(path.exists(), errors, f"Missing battle-shell polish file: {path.relative_to(ROOT)}")
    if not all(path.exists() for path in required_paths):
        return

    battle_scene_text = BATTLE_SCENE_PATH.read_text(encoding="utf-8")
    ensure_scene_nodes(
        battle_scene_text,
        errors,
        "BattleShell.tscn",
        [
            ("Banner", "PanelContainer"),
            ("BriefingPanel", "PanelContainer"),
            ("RiskPanel", "PanelContainer"),
            ("ConsequencePanel", "PanelContainer"),
            ("BattlefieldPanel", "PanelContainer"),
            ("PlayerPanel", "PanelContainer"),
            ("EnemyPanel", "PanelContainer"),
            ("CommandPanel", "PanelContainer"),
            ("InitiativePanel", "PanelContainer"),
            ("ContextPanel", "PanelContainer"),
            ("SpellPanel", "PanelContainer"),
            ("TimingPanel", "PanelContainer"),
            ("BattleBoard", "Control"),
            ("ActionGuide", "Label"),
            ("Footer", "PanelContainer"),
            ("SaveSlot", "OptionButton"),
        ],
    )

    battle_rules_text = BATTLE_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        '"recent_events"',
        "const RECENT_EVENT_LIMIT := 6",
        "const TACTICAL_BRIEFING_KEY := \"tactical_briefing\"",
        "func describe_status",
        "func describe_pressure",
        "func describe_risk_readiness_board",
        "func describe_tactical_briefing",
        "func consume_tactical_briefing",
        "func describe_commander_summary",
        "func describe_initiative_track",
        "func describe_active_context",
        "func describe_target_context",
        "func describe_effect_board",
        "func describe_dispatch",
        "func describe_action_surface",
        "func get_action_surface",
        "func _risk_readiness_grade",
        "func _risk_board_initiative_line",
        "func _risk_board_commander_line",
        "func _risk_board_line_integrity_line",
        "func _risk_board_ranged_pressure_line",
        "func _risk_board_priority_line",
        "func _risk_board_objective_line",
        "func _risk_board_dispatch_line",
        "func _should_surface_tactical_briefing",
        "func _tactical_briefing_lines",
        "func _tactical_enemy_doctrine_line",
        "func _tactical_decisive_target_line",
        "func _priority_enemy_stack_for_briefing",
        "Battlefield:",
        "Opening pressure:",
        "Decisive target:",
        "Strong stabilization posture.",
        "Initiative swing:",
        "Objective urgency:",
        "Latest shift:",
        "func _record_event",
        "func _army_totals",
        "func _stack_focus_summary",
        "func _pressure_brief",
    ):
        ensure(required_token in battle_rules_text, errors, f"BattleRules.gd is missing required battle-shell polish token: {required_token}")

    spell_rules_text = SPELL_RULES_PATH.read_text(encoding="utf-8")
    for required_token in ("func _battle_spell_action_summary", '"summary": summary.strip_edges()'):
        ensure(required_token in spell_rules_text, errors, f"SpellRules.gd is missing required battle-shell polish token: {required_token}")

    battle_script_text = BATTLE_SCRIPT_PATH.read_text(encoding="utf-8")
    for required_token in (
        "_briefing_panel",
        "_briefing_label",
        "_tactical_briefing_text",
        "BattleRules.consume_tactical_briefing",
        "_pressure_label",
        "_player_command_label",
        "_initiative_label",
        "_active_label",
        "_effect_label",
        "_action_guide",
        "_save_slot_picker",
        "_risk_label",
        "BattleRules.describe_pressure",
        "BattleRules.describe_risk_readiness_board",
        "BattleRules.describe_commander_summary",
        "BattleRules.describe_initiative_track",
        "BattleRules.describe_effect_board",
        "BattleRules.describe_action_surface",
        "AppRouter.save_active_session_to_selected_manual_slot",
        "_style_action_button",
    ):
        ensure(required_token in battle_script_text, errors, f"BattleShell.gd is missing required battle-shell polish token: {required_token}")


def validate_battle_objective_pressure_slice(errors: list[str]) -> None:
    required_paths = (BATTLE_RULES_PATH, BATTLE_AI_RULES_PATH, BATTLE_SCENE_PATH)
    for path in required_paths:
        ensure(path.exists(), errors, f"Missing battle-objective pressure file: {path.relative_to(ROOT)}")
    if not all(path.exists() for path in required_paths):
        return

    battle_rules_text = BATTLE_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        'const FIELD_OBJECTIVES_KEY := "field_objectives"',
        "func _normalize_field_objectives",
        "func _authored_field_objectives",
        "func _field_objective_pressure_summary",
        "func _field_objective_focus_line",
        "func _field_objective_action_influence",
        "func _apply_field_objective_action_pressure",
        "func _apply_field_objective_round_effects",
        "func _reserve_wave_ready_round",
        "func _reserve_wave_is_active_for_side",
        "func _field_objective_commander_modifier",
        "cover_line",
        "obstruction_line",
        "func _weakest_stack_by_role",
    ):
        ensure(required_token in battle_rules_text, errors, f"BattleRules.gd is missing required battle-objective token: {required_token}")

    battle_ai_text = BATTLE_AI_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        'const FIELD_OBJECTIVES_KEY := "field_objectives"',
        "func _advance_score",
        "func _objective_action_score",
        "func _field_objective_action_influence",
        "func _reserve_wave_ready_round",
        "func _reserve_wave_is_active_for_side",
        "func _field_objective_attack_bonus",
        "func _field_objective_defense_bonus",
        "func _field_objective_cohesion_bonus",
        "func _field_objective_momentum_bonus",
        "func _field_objective_commander_modifier",
        "cover_line",
        "obstruction_line",
    ):
        ensure(required_token in battle_ai_text, errors, f"BattleAiRules.gd is missing required battle-objective token: {required_token}")

    battle_scene_text = BATTLE_SCENE_PATH.read_text(encoding="utf-8")
    ensure("objective" in battle_scene_text.lower() or "hazard" in battle_scene_text.lower(), errors, "BattleShell.tscn should reference objective or hazard pressure in its release-facing battle copy")


def validate_battle_order_consequence_board(errors: list[str]) -> None:
    required_paths = (SESSION_STATE_PATH, BATTLE_SCENE_PATH, BATTLE_SCRIPT_PATH, BATTLE_RULES_PATH, BATTLE_AI_RULES_PATH)
    for path in required_paths:
        ensure(path.exists(), errors, f"Missing battle order-consequence file: {path.relative_to(ROOT)}")
    if not all(path.exists() for path in required_paths):
        return

    session_text = SESSION_STATE_PATH.read_text(encoding="utf-8")
    ensure("const SAVE_VERSION := 9" in session_text, errors, "Battle order consequence board must preserve save version 9")

    battle_scene_text = BATTLE_SCENE_PATH.read_text(encoding="utf-8")
    for node_name, node_type in (
        ("ConsequencePanel", "PanelContainer"),
        ("ConsequenceTitle", "Label"),
        ("Consequence", "Label"),
    ):
        ensure(scene_has_node(battle_scene_text, node_name, node_type), errors, f"BattleShell.tscn must define {node_name} ({node_type}) for the battle order consequence board")

    battle_rules_text = BATTLE_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        "func describe_order_consequence_board",
        "func _preferred_player_action_id",
        "func _focused_order_line",
        "func _trade_window_line",
        "func _command_tools_line",
        "func _objective_pull_line",
        "func _enemy_reply_line",
        "func _enemy_action_preview_summary",
        "func _attack_action_summary",
        "func _advance_action_summary",
        "func _defend_action_summary",
        "func _damage_modifier",
        "func _damage_range_preview",
        "func _retaliation_range_preview",
        "func _field_objective_action_preview",
        "func _project_field_objective_state",
        "Order Consequences",
        "Focused order:",
        "Trade window:",
        "Command tools:",
        "Enemy reply:",
        "BattleAiRulesScript.choose_enemy_action",
    ):
        ensure(required_token in battle_rules_text, errors, f"BattleRules.gd is missing required battle order-consequence token: {required_token}")

    battle_script_text = BATTLE_SCRIPT_PATH.read_text(encoding="utf-8")
    for required_token in (
        "_consequence_label",
        "BattleRules.describe_order_consequence_board",
    ):
        ensure(required_token in battle_script_text, errors, f"BattleShell.gd is missing required battle order-consequence token: {required_token}")

    battle_ai_text = BATTLE_AI_RULES_PATH.read_text(encoding="utf-8")
    ensure("func choose_enemy_action" in battle_ai_text, errors, "BattleAiRules.gd must keep choose_enemy_action for battle order consequence surfacing")


def validate_battle_spell_timing_board(errors: list[str]) -> None:
    required_paths = (SESSION_STATE_PATH, BATTLE_SCENE_PATH, BATTLE_SCRIPT_PATH, BATTLE_RULES_PATH, SPELL_RULES_PATH, BATTLE_AI_RULES_PATH)
    for path in required_paths:
        ensure(path.exists(), errors, f"Missing battle spell-timing file: {path.relative_to(ROOT)}")
    if not all(path.exists() for path in required_paths):
        return

    session_text = SESSION_STATE_PATH.read_text(encoding="utf-8")
    ensure("const SAVE_VERSION := 9" in session_text, errors, "Battle spell timing board must preserve save version 9")

    battle_scene_text = BATTLE_SCENE_PATH.read_text(encoding="utf-8")
    for node_name, node_type in (
        ("TimingPanel", "PanelContainer"),
        ("TimingTitle", "Label"),
        ("Timing", "Label"),
    ):
        ensure(scene_has_node(battle_scene_text, node_name, node_type), errors, f"BattleShell.tscn must define {node_name} ({node_type}) for the battle spell timing board")

    battle_rules_text = BATTLE_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        "func describe_spell_timing_board",
        "func _spell_window_line",
        "func _preferred_spell_timing_action",
        "func _spell_timing_action_score",
        "func _support_payoff_line",
        "func _support_followup_line",
        "func _protection_need_line",
        "func _priority_friendly_protection_stack",
        "func _best_ready_support_spell_action",
        "func _burst_risk_line",
        "func _enemy_spell_threat_line",
        "Spell and Ability Timing",
        "Spell window:",
        "Support payoff:",
        "Protection need:",
        "Burst risk:",
        "there is no authored cleanse in the current spellbook",
        "SpellRulesScript.battle_spell_timing_summary",
        "BattleAiRulesScript.choose_enemy_action",
    ):
        ensure(required_token in battle_rules_text, errors, f"BattleRules.gd is missing required battle spell-timing token: {required_token}")

    spell_rules_text = SPELL_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        "func battle_spell_timing_summary",
        "Timing: ",
        "Best before the next volley or before the lane closes.",
    ):
        ensure(required_token in spell_rules_text, errors, f"SpellRules.gd is missing required battle spell-timing token: {required_token}")

    battle_script_text = BATTLE_SCRIPT_PATH.read_text(encoding="utf-8")
    for required_token in (
        "_timing_label",
        "BattleRules.describe_spell_timing_board",
    ):
        ensure(required_token in battle_script_text, errors, f"BattleShell.gd is missing required battle spell-timing token: {required_token}")

    battle_ai_text = BATTLE_AI_RULES_PATH.read_text(encoding="utf-8")
    ensure("func choose_enemy_action" in battle_ai_text, errors, "BattleAiRules.gd must keep choose_enemy_action for battle spell timing surfacing")


def validate_battle_faction_identity(errors: list[str]) -> None:
    required_paths = (BATTLE_RULES_PATH, BATTLE_AI_RULES_PATH, SPELL_RULES_PATH)
    for path in required_paths:
        ensure(path.exists(), errors, f"Missing battle-faction identity file: {path.relative_to(ROOT)}")
    if not all(path.exists() for path in required_paths):
        return

    battle_rules_text = BATTLE_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        "func _faction_damage_modifier",
        "func _faction_initiative_bonus",
        "func _contextual_attack_bonus",
        "func _contextual_cohesion_bonus",
        "func _contextual_momentum_bonus",
        "func _terrain_tag_damage_modifier",
        "func _commander_damage_modifier",
        "func _cohesion_damage_modifier",
        "func _stack_cohesion_total",
        "func _stack_momentum_total",
        "func _apply_round_pressure_shifts",
        "func _apply_damage_pressure",
        "func _stack_is_isolated",
        "func _normalized_battlefield_tags",
        "func _normalized_battle_traits",
        "func _hero_has_trait",
        "func _starting_distance_for_encounter",
        "func _side_has_ability",
        "func _stack_has_positive_effect",
        "func _side_positive_effect_count",
        "func _side_doctrine_summary",
        '"battlefield_tags"',
        '"fortified_line"',
        '"formation_guard"',
        '"bloodrush"',
        '"faction_sunvault"',
        '"cohesion"',
        '"momentum"',
        '"post_damage_effect"',
        '"Doctrine: %s"',
    ):
        ensure(required_token in battle_rules_text, errors, f"BattleRules.gd is missing required faction-battle token: {required_token}")

    battle_ai_text = BATTLE_AI_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        "func _faction_damage_modifier",
        "func _contextual_attack_bonus",
        "func _contextual_cohesion_bonus",
        "func _contextual_momentum_bonus",
        "func _terrain_tag_damage_modifier",
        "func _commander_damage_modifier",
        "func _cohesion_damage_modifier",
        "func _stack_cohesion_total",
        "func _stack_momentum_total",
        "func _stack_is_isolated",
        "func _battle_has_tag",
        "func _hero_has_trait",
        "func _spell_buff_already_active",
        "func _allied_status_synergy_score",
        "func _side_has_ability",
        "func _stack_has_positive_effect",
        "func _side_positive_effect_count",
        '"battlefield_tags"',
        '"attack_buff"',
        '"faction_sunvault"',
        '"cohesion"',
        '"momentum"',
        "SpellRulesScript.battle_spell_modifiers",
    ):
        ensure(required_token in battle_ai_text, errors, f"BattleAiRules.gd is missing required faction-battle token: {required_token}")

    scenario_factory_text = SCENARIO_FACTORY_PATH.read_text(encoding="utf-8")
    for required_token in ('"battle_traits"',):
        ensure(required_token in scenario_factory_text, errors, f"ScenarioFactory.gd is missing required battle-variety token: {required_token}")

    spell_rules_text = SPELL_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        "func battle_spell_modifiers",
        "func _status_effect_from_spell_effect",
        "func _modifier_summary",
        '"attack_buff"',
        '"cohesion"',
        '"momentum"',
        '"post_damage_effect"',
        '"status_effect"',
    ):
        ensure(required_token in spell_rules_text, errors, f"SpellRules.gd is missing required faction-battle token: {required_token}")


def validate_in_session_save_controls(errors: list[str]) -> None:
    required_paths = (
        SAVE_SERVICE_PATH,
        APP_ROUTER_PATH,
        MAIN_MENU_SCRIPT_PATH,
        OVERWORLD_SCRIPT_PATH,
        TOWN_SCRIPT_PATH,
        BATTLE_SCRIPT_PATH,
        OUTCOME_SCRIPT_PATH,
        OVERWORLD_SCENE_PATH,
        TOWN_SCENE_PATH,
        BATTLE_SCENE_PATH,
        OUTCOME_SCENE_PATH,
    )
    for path in required_paths:
        ensure(path.exists(), errors, f"Missing in-session save-control file: {path.relative_to(ROOT)}")
    if not all(path.exists() for path in required_paths):
        return

    session_text = SESSION_STATE_PATH.read_text(encoding="utf-8")
    ensure("const SAVE_VERSION := 9" in session_text, errors, "In-session save controls must preserve save version 9")

    save_text = SAVE_SERVICE_PATH.read_text(encoding="utf-8")
    for required_token in (
        "func save_runtime_selected_manual_session",
        "func save_runtime_manual_session",
        "func save_runtime_autosave_session",
        "func build_in_session_save_surface",
        "func _in_session_save_label",
        "func _in_session_save_tooltip",
        "func _latest_context_line",
        "func _return_to_menu_tooltip",
    ):
        ensure(required_token in save_text, errors, f"SaveService.gd is missing required in-session save token: {required_token}")

    app_router_text = APP_ROUTER_PATH.read_text(encoding="utf-8")
    for required_token in (
        "func return_to_main_menu_from_active_play",
        "func save_active_session_to_selected_manual_slot",
        "func active_save_surface",
        "func resume_summary",
        "func resume_latest_session",
        "func consume_menu_notice",
        "SaveService.save_runtime_selected_manual_session",
        "SaveService.save_runtime_autosave_session",
    ):
        ensure(required_token in app_router_text, errors, f"AppRouter.gd is missing required in-session save-routing token: {required_token}")

    overworld_script_text = OVERWORLD_SCRIPT_PATH.read_text(encoding="utf-8")
    for required_token in (
        "_save_status_label",
        "_menu_button",
        "AppRouter.save_active_session_to_selected_manual_slot",
        "AppRouter.active_save_surface",
        "AppRouter.return_to_main_menu_from_active_play",
        "SaveService.save_runtime_autosave_session(_session)",
    ):
        ensure(required_token in overworld_script_text, errors, f"OverworldShell.gd is missing required in-session save token: {required_token}")

    town_script_text = TOWN_SCRIPT_PATH.read_text(encoding="utf-8")
    for required_token in (
        "_save_status_label",
        "_menu_button",
        "AppRouter.save_active_session_to_selected_manual_slot",
        "AppRouter.active_save_surface",
        "AppRouter.return_to_main_menu_from_active_play",
    ):
        ensure(required_token in town_script_text, errors, f"TownShell.gd is missing required in-session save token: {required_token}")

    battle_script_text = BATTLE_SCRIPT_PATH.read_text(encoding="utf-8")
    for required_token in (
        "_system_body_label",
        "_menu_button",
        "AppRouter.save_active_session_to_selected_manual_slot",
        "AppRouter.active_save_surface",
        "AppRouter.return_to_main_menu_from_active_play",
    ):
        ensure(required_token in battle_script_text, errors, f"BattleShell.gd is missing required in-session save token: {required_token}")

    outcome_script_text = OUTCOME_SCRIPT_PATH.read_text(encoding="utf-8")
    for required_token in (
        "_save_status_label",
        "_save_slot_picker",
        "_save_button",
        "_menu_button",
        "func _configure_save_slot_picker",
        "func _refresh_save_surface",
        "AppRouter.save_active_session_to_selected_manual_slot",
        "AppRouter.return_to_main_menu_from_active_play",
    ):
        ensure(required_token in outcome_script_text, errors, f"ScenarioOutcomeShell.gd is missing required in-session save token: {required_token}")

    overworld_scene_text = OVERWORLD_SCENE_PATH.read_text(encoding="utf-8")
    for node_name, node_type in (
        ("SaveStatus", "Label"),
        ("SaveSlot", "OptionButton"),
        ("Save", "Button"),
        ("Menu", "Button"),
    ):
        ensure(scene_has_node(overworld_scene_text, node_name, node_type), errors, f"OverworldShell.tscn must define {node_name} ({node_type}) for in-session save controls")

    town_scene_text = TOWN_SCENE_PATH.read_text(encoding="utf-8")
    for node_name, node_type in (
        ("SaveStatus", "Label"),
        ("SaveSlot", "OptionButton"),
        ("Save", "Button"),
        ("Menu", "Button"),
    ):
        ensure(scene_has_node(town_scene_text, node_name, node_type), errors, f"TownShell.tscn must define {node_name} ({node_type}) for in-session save controls")

    battle_scene_text = BATTLE_SCENE_PATH.read_text(encoding="utf-8")
    for node_name, node_type in (
        ("SystemPanel", "PanelContainer"),
        ("SystemBody", "Label"),
        ("SaveSlot", "OptionButton"),
        ("Save", "Button"),
        ("Menu", "Button"),
    ):
        ensure(scene_has_node(battle_scene_text, node_name, node_type), errors, f"BattleShell.tscn must define {node_name} ({node_type}) for in-session save controls")

    outcome_scene_text = OUTCOME_SCENE_PATH.read_text(encoding="utf-8")
    for node_name, node_type in (
        ("SaveStatus", "Label"),
        ("SaveBar", "HFlowContainer"),
        ("SaveSlot", "OptionButton"),
        ("Save", "Button"),
        ("Menu", "Button"),
    ):
        ensure(scene_has_node(outcome_scene_text, node_name, node_type), errors, f"ScenarioOutcomeShell.tscn must define {node_name} ({node_type}) for in-session save controls")


def validate_town_faction_progression(errors: list[str]) -> None:
    required_paths = (
        SESSION_STATE_PATH,
        SCENARIO_FACTORY_PATH,
        OVERWORLD_RULES_PATH,
        TOWN_RULES_PATH,
        SCENARIO_SCRIPT_RULES_PATH,
        TOWN_SCRIPT_PATH,
    )
    for path in required_paths:
        ensure(path.exists(), errors, f"Missing town/faction progression file: {path.relative_to(ROOT)}")
    if not all(path.exists() for path in required_paths):
        return

    session_text = SESSION_STATE_PATH.read_text(encoding="utf-8")
    ensure("const SAVE_VERSION := 9" in session_text, errors, "Town/faction progression must preserve save version 9")

    scenario_factory_text = SCENARIO_FACTORY_PATH.read_text(encoding="utf-8")
    for required_token in ("func _seed_recruits_for_town_state", "func _apply_growth_profile"):
        ensure(required_token in scenario_factory_text, errors, f"ScenarioFactory.gd is missing required town progression token: {required_token}")

    overworld_text = OVERWORLD_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        "const WEEKLY_GROWTH_INTERVAL := 7",
        "func is_weekly_growth_day",
        "func days_until_next_weekly_growth",
        "func next_weekly_growth_day",
        "func describe_town_context",
        "func town_weekly_growth",
        "func town_income",
        "func town_reinforcement_quality",
        "func town_battle_readiness",
        "func town_pressure_output",
        "func town_recruit_cost",
        "func get_town_build_status",
        "func _normalize_built_buildings_for_town_state",
        "func _economy_profile_income",
        "func _weighted_recruit_value",
        "func _pressure_bonus_from_profile",
        "func _readiness_bonus_from_profile",
        "func _recruitment_discount_percent",
        "Weekly musters",
    ):
        ensure(required_token in overworld_text, errors, f"OverworldRules.gd is missing required town progression token: {required_token}")

    town_rules_text = TOWN_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        "func describe_status",
        "OverworldRulesScript.town_income",
        "OverworldRulesScript.town_weekly_growth",
        "OverworldRulesScript.town_reinforcement_quality",
        "OverworldRulesScript.town_battle_readiness",
        "OverworldRulesScript.town_pressure_output",
        "OverworldRulesScript.town_market_state",
        "OverworldRulesScript.town_recruit_cost",
        "OverworldRulesScript.get_town_build_status",
        "func _town_identity_summary",
        "func _town_unit_ids",
    ):
        ensure(required_token in town_rules_text, errors, f"TownRules.gd is missing required town progression token: {required_token}")

    scenario_script_text = SCENARIO_SCRIPT_RULES_PATH.read_text(encoding="utf-8")
    ensure("OverworldRules._normalize_built_buildings_for_town_state" in scenario_script_text, errors, "ScenarioScriptRules.gd must normalize scripted town buildings through the shared prerequisite graph")

    town_script_text = TOWN_SCRIPT_PATH.read_text(encoding="utf-8")
    for required_token in ("TownRules.describe_status", "TownRules.describe_summary", "TownRules.describe_buildings", "TownRules.describe_market", "TownRules.describe_recruitment", "TownRules.describe_responses"):
        ensure(required_token in town_script_text, errors, f"TownShell.gd is missing required town progression token: {required_token}")


def validate_town_shell_release_polish(errors: list[str]) -> None:
    required_paths = (TOWN_SCENE_PATH, TOWN_SCRIPT_PATH, TOWN_RULES_PATH, OVERWORLD_RULES_PATH)
    for path in required_paths:
        ensure(path.exists(), errors, f"Missing town-shell polish file: {path.relative_to(ROOT)}")
    if not all(path.exists() for path in required_paths):
        return

    town_scene_text = TOWN_SCENE_PATH.read_text(encoding="utf-8")
    ensure_scene_nodes(
        town_scene_text,
        errors,
        "TownShell.tscn",
        [
            ("Banner", "PanelContainer"),
            ("TownStagePanel", "PanelContainer"),
            ("TownPanel", "PanelContainer"),
            ("OutlookPanel", "PanelContainer"),
            ("CommandLedgerPanel", "PanelContainer"),
            ("CommandPanel", "PanelContainer"),
            ("ManagementTabs", "TabContainer"),
            ("BuildPanel", "PanelContainer"),
            ("RecruitPanel", "PanelContainer"),
            ("StudyPanel", "PanelContainer"),
            ("MarketPanel", "PanelContainer"),
            ("LogisticsPanel", "PanelContainer"),
            ("Defense", "Label"),
            ("Pressure", "Label"),
            ("Market", "Label"),
            ("Responses", "Label"),
            ("Event", "Label"),
            ("FooterPanel", "PanelContainer"),
        ],
    )

    town_rules_text = TOWN_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        "func describe_defense",
        "func describe_threats",
        "func describe_event_feed",
        "func _town_threat_lines",
        "func _pressure_brief",
        "func _describe_building_category_counts",
        "func _growth_source_summary",
        "func _reinforcement_grade",
        "func _town_pressure_label",
        "func _pressure_noun_for_building",
        "func describe_market",
        "func get_market_actions",
        "func perform_market_action",
        "func describe_responses",
        "func get_response_actions",
        "func perform_response_action",
    ):
        ensure(required_token in town_rules_text, errors, f"TownRules.gd is missing required town-shell polish token: {required_token}")
    ensure("faction_sunvault" in town_rules_text, errors, "TownRules.gd must surface Sunvault pressure terminology for the third playable faction")

    overworld_text = OVERWORLD_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        "func is_tile_visible",
        "func describe_enemy_threats",
        "func town_public_threat_state",
        "func town_market_state",
        "func describe_town_market",
        "func get_town_market_actions",
        "func perform_town_market_action",
        "func can_afford_cost_with_town_market",
        "func apply_market_cost_coverage",
    ):
        ensure(required_token in overworld_text, errors, f"OverworldRules.gd is missing required town-shell support token: {required_token}")
    ensure("faction_sunvault" in overworld_text, errors, "OverworldRules.gd must surface Sunvault pressure terminology for the third playable faction")

    town_script_text = TOWN_SCRIPT_PATH.read_text(encoding="utf-8")
    for required_token in (
        "TownRules.describe_defense",
        "TownRules.describe_threats",
        "TownRules.describe_event_feed",
        "TownRules.describe_market",
        "TownRules.get_market_actions",
        "TownRules.perform_market_action",
        "TownRules.describe_responses",
        "TownRules.get_response_actions",
        "TownRules.perform_response_action",
        "_defense_label",
        "_pressure_label",
        "_market_label",
        "_market_actions",
        "_response_label",
        "_response_actions",
        "_style_action_button",
    ):
        ensure(required_token in town_script_text, errors, f"TownShell.gd is missing required town-shell polish token: {required_token}")


def validate_town_defense_outlook_board(errors: list[str]) -> None:
    required_paths = (TOWN_SCENE_PATH, TOWN_SCRIPT_PATH, TOWN_RULES_PATH, OVERWORLD_RULES_PATH)
    for path in required_paths:
        ensure(path.exists(), errors, f"Missing town defense-outlook file: {path.relative_to(ROOT)}")
    if not all(path.exists() for path in required_paths):
        return

    town_scene_text = TOWN_SCENE_PATH.read_text(encoding="utf-8")
    for node_name, node_type in (
        ("OutlookPanel", "PanelContainer"),
        ("OutlookTitle", "Label"),
        ("Outlook", "Label"),
    ):
        ensure(scene_has_node(town_scene_text, node_name, node_type), errors, f"TownShell.tscn must define {node_name} ({node_type}) for the town defense outlook board")

    town_rules_text = TOWN_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        "func describe_outlook_board",
        "func _town_outlook_grade",
        "func _town_frontier_outlook_line",
        "func _town_dispatch_readiness_line",
        "func _town_support_watch_line",
        "func _active_hero_movement_state",
        "func _count_ready_actions",
        "func _stationed_reserve_count",
        "Strong defensive posture",
        "Capital chain exposed",
        "No reserve commander covers the walls if the field hero rides out",
    ):
        ensure(required_token in town_rules_text, errors, f"TownRules.gd is missing required town defense-outlook token: {required_token}")

    overworld_text = OVERWORLD_RULES_PATH.read_text(encoding="utf-8")
    ensure("func town_public_threat_state" in overworld_text, errors, "OverworldRules.gd must expose a visibility-safe public town-threat helper for the town outlook board")

    town_script_text = TOWN_SCRIPT_PATH.read_text(encoding="utf-8")
    for required_token in (
        "_outlook_label",
        "TownRules.describe_outlook_board",
    ):
        ensure(required_token in town_script_text, errors, f"TownShell.gd is missing required town defense-outlook token: {required_token}")


def validate_town_order_readiness_ledger(errors: list[str]) -> None:
    required_paths = (TOWN_SCENE_PATH, TOWN_SCRIPT_PATH, TOWN_RULES_PATH, OVERWORLD_RULES_PATH)
    for path in required_paths:
        ensure(path.exists(), errors, f"Missing town order-readiness file: {path.relative_to(ROOT)}")
    if not all(path.exists() for path in required_paths):
        return

    town_scene_text = TOWN_SCENE_PATH.read_text(encoding="utf-8")
    for node_name, node_type in (
        ("CommandLedgerPanel", "PanelContainer"),
        ("CommandLedgerTitle", "Label"),
        ("CommandLedger", "Label"),
    ):
        ensure(scene_has_node(town_scene_text, node_name, node_type), errors, f"TownShell.tscn must define {node_name} ({node_type}) for the town order-readiness ledger")

    town_rules_text = TOWN_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        "func describe_command_ledger",
        "func _build_order_ledger_line",
        "func _recruit_order_ledger_line",
        "func _response_order_ledger_line",
        "func _coverage_order_ledger_line",
        "func _market_coverage_line",
        "func _cost_shortfall_line",
        "func _max_market_affordable_count",
        "Exchange can unlock",
        "Order Ledger",
    ):
        ensure(required_token in town_rules_text, errors, f"TownRules.gd is missing required town order-readiness token: {required_token}")

    overworld_text = OVERWORLD_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        "func town_cost_readiness",
        "market_affordable",
        "direct_shortfall",
    ):
        ensure(required_token in overworld_text, errors, f"OverworldRules.gd is missing required town order-readiness token: {required_token}")

    town_script_text = TOWN_SCRIPT_PATH.read_text(encoding="utf-8")
    for required_token in (
        "_command_ledger_label",
        "TownRules.describe_command_ledger",
    ):
        ensure(required_token in town_script_text, errors, f"TownShell.gd is missing required town order-readiness token: {required_token}")


def validate_overworld_shell_release_polish(errors: list[str]) -> None:
    required_paths = (OVERWORLD_SCENE_PATH, OVERWORLD_SCRIPT_PATH, OVERWORLD_RULES_PATH)
    for path in required_paths:
        ensure(path.exists(), errors, f"Missing overworld-shell polish file: {path.relative_to(ROOT)}")
    if not all(path.exists() for path in required_paths):
        return

    overworld_scene_text = OVERWORLD_SCENE_PATH.read_text(encoding="utf-8")
    ensure_scene_nodes(
        overworld_scene_text,
        errors,
        "OverworldShell.tscn",
        [
            ("TopStrip", "PanelContainer"),
            ("EventPanel", "PanelContainer"),
            ("CommitmentPanel", "PanelContainer"),
            ("BriefingPanel", "PanelContainer"),
            ("MapPanel", "PanelContainer"),
            ("CommandBand", "PanelContainer"),
            ("ActionPanel", "PanelContainer"),
            ("OpenCommand", "Button"),
            ("OpenFrontier", "Button"),
            ("FrontierIndicator", "Label"),
            ("CommandSpine", "VBoxContainer"),
            ("ContextPanel", "PanelContainer"),
            ("CommandPanel", "PanelContainer"),
            ("FrontierPanel", "PanelContainer"),
            ("CloseCommand", "Button"),
            ("CloseFrontier", "Button"),
            ("HeroActions", "VBoxContainer"),
            ("ContextActions", "VBoxContainer"),
            ("SpecialtyActions", "VBoxContainer"),
            ("SpellActions", "VBoxContainer"),
            ("ArtifactActions", "VBoxContainer"),
            ("BriefingTitle", "Label"),
            ("Briefing", "Label"),
            ("Visibility", "Label"),
            ("Objectives", "Label"),
            ("Threats", "Label"),
            ("Forecast", "Label"),
            ("Event", "Label"),
            ("SaveSlot", "OptionButton"),
        ],
    )
    ensure(
        'name="MapColumn"' not in overworld_scene_text,
        errors,
        "OverworldShell.tscn must not keep the old map-column dashboard wrapper",
    )
    ensure(
        'name="SummaryStrip"' not in overworld_scene_text,
        errors,
        "OverworldShell.tscn must not keep contextual report panels embedded above the adventure map",
    )
    ensure(
        'type="TabContainer"' not in overworld_scene_text and 'name="SidebarTabs"' not in overworld_scene_text,
        errors,
        "OverworldShell.tscn must not reintroduce the cramped right-rail tab strip",
    )
    for removed_node in ("MapHint", "MarchPanel", "MoveNorth", "MoveSouth", "MoveWest", "MoveEast", "MoveState"):
        ensure(
            f'name="{removed_node}"' not in overworld_scene_text,
            errors,
            f"OverworldShell.tscn must not reintroduce permanent movement hint/control node {removed_node}",
        )
    for hidden_node, hidden_type in (
        ("CommitmentPanel", "PanelContainer"),
        ("CommandSpine", "VBoxContainer"),
        ("ContextPanel", "PanelContainer"),
        ("CommandPanel", "PanelContainer"),
        ("FrontierPanel", "PanelContainer"),
    ):
        ensure(
            "visible = false" in scene_node_block(overworld_scene_text, hidden_node, hidden_type),
            errors,
            f"OverworldShell.tscn must keep {hidden_node} hidden by default so it cannot reserve permanent map-side space",
        )
    ensure(
        scene_node_parent(overworld_scene_text, "MapPanel", "PanelContainer")
        == "ShellMargin/Shell/ShellPad/Content/BodyRow",
        errors,
        "OverworldShell.tscn must make MapPanel the direct dominant BodyRow surface",
    )
    ensure(
        scene_node_parent(overworld_scene_text, "SidebarShell", "PanelContainer")
        == "ShellMargin/Shell/ShellPad/Content/BodyRow",
        errors,
        "OverworldShell.tscn must keep one fixed right-side command spine beside the map",
    )
    ensure(
        scene_node_parent(overworld_scene_text, "CommandBand", "PanelContainer")
        == "ShellMargin/Shell/ShellPad/Content",
        errors,
        "OverworldShell.tscn must keep CommandBand as a footer ribbon below the map stage",
    )
    ensure(
        "custom_minimum_size = Vector2(0, 74)" in overworld_scene_text,
        errors,
        "OverworldShell.tscn must keep the overworld command footer slim",
    )
    sidebar_prefix = "ShellMargin/Shell/ShellPad/Content/BodyRow/SidebarShell/"
    for node_name in ("TopStrip", "EventPanel", "CommitmentPanel", "BriefingPanel", "HeroPanel", "ActionPanel", "CommandSpine"):
        ensure(
            scene_node_parent(overworld_scene_text, node_name, "PanelContainer" if node_name != "CommandSpine" else "VBoxContainer").startswith(sidebar_prefix),
            errors,
            f"OverworldShell.tscn must keep {node_name} inside the light right-side status shell",
        )
    command_spine_prefix = "ShellMargin/Shell/ShellPad/Content/BodyRow/SidebarShell/SidebarPad/SidebarBox/CommandSpine"
    for node_name in ("ContextPanel", "CommandPanel", "FrontierPanel"):
        ensure(
            scene_node_parent(overworld_scene_text, node_name, "PanelContainer").startswith(command_spine_prefix),
            errors,
            f"OverworldShell.tscn must keep {node_name} as a hidden drawer section opened by explicit context/buttons",
        )
    footer_prefix = "ShellMargin/Shell/ShellPad/Content/CommandBand/"
    for node_name in ("ResourceChip", "StatusChip", "CueChip", "OrdersPanel", "SystemPanel"):
        ensure(
            scene_node_parent(overworld_scene_text, node_name, "PanelContainer").startswith(footer_prefix),
            errors,
            f"OverworldShell.tscn must keep {node_name} inside the slim footer ribbon",
        )
    for forbidden_text in ("Click route | WASD march", "Click adjacent tiles to march", "WASD march"):
        ensure(
            forbidden_text not in overworld_scene_text,
            errors,
            f"OverworldShell.tscn must not keep permanent movement explainer text: {forbidden_text}",
        )

    overworld_rules_text = OVERWORLD_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        "const COMMAND_BRIEFING_KEY := \"command_briefing\"",
        "const COMMAND_RISK_FORECAST_KEY := \"command_risk_forecast\"",
        "func describe_status",
        "func describe_visibility_panel",
        "func describe_objective_board",
        "func describe_frontier_threats",
        "func describe_command_briefing",
        "func consume_command_briefing",
        "func describe_command_risk",
        "func describe_command_risk_forecast",
        "func consume_command_risk_forecast",
        "func describe_dispatch",
        "func _normalize_command_briefing",
        "func _normalize_command_risk_forecast",
        "func _command_briefing_lines",
        "func _command_briefing_orders_line",
        "func _command_risk_forecast",
        "func _command_risk_town_items",
        "func _command_risk_logistics_items",
        "func _command_risk_objective_items",
        "func _command_risk_posture_items",
        "func _command_risk_field_item",
        "Immediate orders:",
        "Logistics watch:",
        "Next-day posture:",
        "func _local_visible_threat_summary",
        "func _dispatch_context_brief",
        "func _terrain_name_at",
    ):
        ensure(required_token in overworld_rules_text, errors, f"OverworldRules.gd is missing required overworld-shell polish token: {required_token}")

    overworld_script_text = OVERWORLD_SCRIPT_PATH.read_text(encoding="utf-8")
    for required_token in (
        "_briefing_panel",
        "_briefing_title_label",
        "_briefing_label",
        "_briefing_title_text",
        "_command_briefing_text",
        "OverworldRules.consume_command_briefing",
        "OverworldRules.consume_command_risk_forecast",
        "_visibility_label",
        "_forecast_label",
        "OverworldRules.describe_status",
        "OverworldRules.describe_visibility_panel",
        "OverworldRules.describe_command_risk",
        "OverworldRules.describe_dispatch",
        "OverworldRules.describe_enemy_threats",
        "OverworldRules.describe_context",
        "_set_command_briefing",
        "_set_rail_text",
        "_set_rail_label",
        "_compact_rail_text",
        "_rail_log_text",
        "_rail_order_text",
        "_rail_tile_text",
        "_active_drawer",
        "_sync_context_drawers",
        "_should_show_tile_context",
        "_frontier_indicator_text",
        "_update_map_tooltip",
        "validation_open_command_drawer",
        "validation_open_frontier_drawer",
        "_validation_chrome_state",
        "TextServer.AUTOWRAP_OFF",
        "label.clip_text = true",
        "_style_action_button",
        "_style_rail_action_button",
        "RAIL_ACTION_WIDTH",
    ):
        ensure(required_token in overworld_script_text, errors, f"OverworldShell.gd is missing required overworld-shell polish token: {required_token}")
    ensure(
        "_sidebar_tabs" not in overworld_script_text and "apply_tab_container(_sidebar_tabs)" not in overworld_script_text,
        errors,
        "OverworldShell.gd must not drive the removed right-rail tab strip",
    )
    ensure(
        "_set_compact_label(_context_label, _describe_focus_tile(), 5, 74)" not in overworld_script_text,
        errors,
        "OverworldShell.gd must not expose long wrapped Tile reports in the right rail",
    )
    ensure(
        "_set_compact_label(_event_label, OverworldRules.describe_dispatch" not in overworld_script_text,
        errors,
        "OverworldShell.gd must not expose multi-line Field Dispatch reports in the Log rail",
    )
    ensure(
        "_move_north_button" not in overworld_script_text
        and "_move_south_button" not in overworld_script_text
        and "_move_west_button" not in overworld_script_text
        and "_move_east_button" not in overworld_script_text,
        errors,
        "OverworldShell.gd must not drive permanent footer march direction buttons",
    )
    for forbidden_text in ("Click route | WASD march", "Click adjacent tiles to march", "WASD march"):
        ensure(
            forbidden_text not in overworld_script_text,
            errors,
            f"OverworldShell.gd must not keep permanent movement explainer text: {forbidden_text}",
        )


def validate_overworld_command_commitment_board(errors: list[str]) -> None:
    required_paths = (SESSION_STATE_PATH, OVERWORLD_SCENE_PATH, OVERWORLD_SCRIPT_PATH, OVERWORLD_RULES_PATH)
    for path in required_paths:
        ensure(path.exists(), errors, f"Missing overworld command-commitment file: {path.relative_to(ROOT)}")
    if not all(path.exists() for path in required_paths):
        return

    session_text = SESSION_STATE_PATH.read_text(encoding="utf-8")
    ensure("const SAVE_VERSION := 9" in session_text, errors, "Overworld command commitment board must preserve save version 9")

    overworld_scene_text = OVERWORLD_SCENE_PATH.read_text(encoding="utf-8")
    for node_name, node_type in (
        ("CommitmentPanel", "PanelContainer"),
        ("CommitmentTitle", "Label"),
        ("Commitment", "Label"),
    ):
        ensure(scene_has_node(overworld_scene_text, node_name, node_type), errors, f"OverworldShell.tscn must define {node_name} ({node_type}) for the command commitment board")
    ensure(
        "visible = false" in scene_node_block(overworld_scene_text, "CommitmentPanel", "PanelContainer"),
        errors,
        "OverworldShell.tscn must keep the order/commitment board hidden by default and use current-action feedback instead of permanent real estate",
    )

    overworld_rules_text = OVERWORLD_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        'func describe_commitment_board',
        'func _context_action_summary',
        'func _command_commitment_action_line',
        'func _command_commitment_route_line',
        'func _command_commitment_coverage_line',
        'func _command_commitment_hold_line',
        'func _nearest_reserve_hero_support',
        '"summary": _context_action_summary',
        'Command Commitment',
        'Immediate order:',
        'Route pressure:',
        'Coverage:',
        'If you hold:',
    ):
        ensure(required_token in overworld_rules_text, errors, f"OverworldRules.gd is missing required command-commitment token: {required_token}")

    overworld_script_text = OVERWORLD_SCRIPT_PATH.read_text(encoding="utf-8")
    for required_token in (
        "_commitment_label",
        "OverworldRules.describe_commitment_board",
    ):
        ensure(required_token in overworld_script_text, errors, f"OverworldShell.gd is missing required command-commitment token: {required_token}")


def validate_enemy_empire_management(errors: list[str]) -> None:
    required_paths = (
        SESSION_STATE_PATH,
        OVERWORLD_RULES_PATH,
        ENEMY_TURN_RULES_PATH,
        ENEMY_ADVENTURE_RULES_PATH,
        BATTLE_RULES_PATH,
    )
    for path in required_paths:
        ensure(path.exists(), errors, f"Missing enemy empire-management file: {path.relative_to(ROOT)}")
    if not all(path.exists() for path in required_paths):
        return

    session_text = SESSION_STATE_PATH.read_text(encoding="utf-8")
    ensure("const SAVE_VERSION := 9" in session_text, errors, "Enemy empire management must preserve save version 9")

    overworld_text = OVERWORLD_RULES_PATH.read_text(encoding="utf-8")
    for required_token in ("func describe_enemy_threats", "func _town_defense_summary", "Defense %s"):
        ensure(required_token in overworld_text, errors, f"OverworldRules.gd is missing required enemy-surfacing token: {required_token}")

    enemy_turn_text = ENEMY_TURN_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        '"treasury": _blank_resource_pool()',
        '"posture": "probing"',
        '"captured_artifact_ids": []',
        "EnemyAdventureRulesScript.normalize_raid_armies",
        "OverworldRulesScript.town_income",
        "OverworldRulesScript.town_weekly_growth",
        "OverworldRulesScript.town_reinforcement_quality",
        "OverworldRulesScript.town_battle_readiness",
        "OverworldRulesScript.town_pressure_output",
        "OverworldRulesScript.can_afford_cost_with_town_market",
        "OverworldRulesScript.apply_market_cost_coverage",
        "OverworldRulesScript.get_town_build_options",
        "func _run_empire_cycle",
        "func _build_in_enemy_towns",
        "func _reinforce_enemy_forces",
        "func _apply_reinforcement_to_raid",
        "func _desired_town_strength",
        "func _empire_town_pressure_bonus",
        "func _public_posture_label",
        "func _captured_artifact_income",
        "func _captured_artifact_pressure_bonus",
    ):
        ensure(required_token in enemy_turn_text, errors, f"EnemyTurnRules.gd is missing required empire-management token: {required_token}")

    enemy_adventure_text = ENEMY_ADVENTURE_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        "func normalize_raid_armies",
        "func ensure_raid_army",
        "func visible_raid_count",
        "func raid_strength",
        "func desired_raid_strength",
        "func raid_pillage_weight",
        "func describe_contestation",
    ):
        ensure(required_token in enemy_adventure_text, errors, f"EnemyAdventureRules.gd is missing required empire-management token: {required_token}")

    battle_text = BATTLE_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        'encounter_placement.get("enemy_army"',
        "func _resolved_encounter_placement",
    ):
        ensure(required_token in battle_text, errors, f"BattleRules.gd is missing required enemy-army token: {required_token}")


def validate_enemy_strategic_contestation(errors: list[str]) -> None:
    required_paths = (
        SESSION_STATE_PATH,
        SCENARIO_FACTORY_PATH,
        OVERWORLD_RULES_PATH,
        ARTIFACT_RULES_PATH,
        ENEMY_TURN_RULES_PATH,
        ENEMY_ADVENTURE_RULES_PATH,
    )
    for path in required_paths:
        ensure(path.exists(), errors, f"Missing enemy strategic-contestation file: {path.relative_to(ROOT)}")
    if not all(path.exists() for path in required_paths):
        return

    session_text = SESSION_STATE_PATH.read_text(encoding="utf-8")
    ensure("const SAVE_VERSION := 9" in session_text, errors, "Strategic enemy contestation must preserve save version 9")

    scenario_factory_text = SCENARIO_FACTORY_PATH.read_text(encoding="utf-8")
    for required_token in ("collected_by_faction_id", "collected_day"):
        ensure(required_token in scenario_factory_text, errors, f"ScenarioFactory.gd is missing strategic-node token: {required_token}")

    artifact_rules_text = ARTIFACT_RULES_PATH.read_text(encoding="utf-8")
    for required_token in ("collected_by_faction_id", "collected_day"):
        ensure(required_token in artifact_rules_text, errors, f"ArtifactRules.gd is missing strategic-node token: {required_token}")

    overworld_text = OVERWORLD_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        "collected_by_faction_id",
        "contested_by_faction_id",
        "frontier site%s already denied by hostile forces",
        "neutral front%s under hostile contest",
    ):
        ensure(required_token in overworld_text, errors, f"OverworldRules.gd is missing strategic-surfacing token: {required_token}")

    enemy_turn_text = ENEMY_TURN_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        "EnemyAdventureRulesScript.advance_raids(session, config, faction_id, state)",
        "EnemyAdventureRulesScript.describe_contestation",
        '"captured_artifact_ids": _normalize_string_array',
    ):
        ensure(required_token in enemy_turn_text, errors, f"EnemyTurnRules.gd is missing strategic-turn token: {required_token}")

    enemy_adventure_text = ENEMY_ADVENTURE_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        '"target_kind": "resource"',
        '"target_kind": "artifact"',
        '"target_kind": "encounter"',
        "func _resolve_arrived_target",
        "func _secure_resource_target",
        "func _secure_artifact_target",
        "func _contest_encounter_target",
        "func _append_resource_candidate",
        "func _append_artifact_candidate",
        "func _append_encounter_candidate",
        "func _hero_target_candidate",
        "func _encounter_staging_tiles",
        "func _resource_target_priority",
        "func _artifact_target_priority",
        "func _encounter_target_priority",
        "contested_by_faction_id",
        "collected_by_faction_id",
    ):
        ensure(required_token in enemy_adventure_text, errors, f"EnemyAdventureRules.gd is missing strategic-targeting token: {required_token}")

    scenarios = items_index(load_json(CONTENT_DIR / "scenarios.json"))
    for scenario_id, scenario in scenarios.items():
        enemy_factions = scenario.get("enemy_factions", [])
        if not isinstance(enemy_factions, list) or not enemy_factions:
            continue
        contestable_count = len(scenario.get("resource_nodes", [])) + len(scenario.get("artifact_nodes", [])) + len(scenario.get("encounters", []))
        ensure(contestable_count > 0, errors, f"Scenario {scenario_id} must author at least one non-town strategic contest target for enemy factions")

        objectives = scenario.get("objectives", {})
        objective_pressure_present = False
        if isinstance(objectives, dict):
            for bucket in ("victory", "defeat"):
                for objective in objectives.get(bucket, []):
                    if not isinstance(objective, dict):
                        continue
                    objective_type = str(objective.get("type", ""))
                    if objective_type in {"town_owned_by_player", "town_not_owned_by_player", "enemy_pressure_at_least", "flag_true"}:
                        objective_pressure_present = True
                        break
                if objective_pressure_present:
                    break
        ensure(objective_pressure_present, errors, f"Scenario {scenario_id} must author at least one objective that strategic enemy contestation can pressure")


def validate_overworld_logistics_sites(errors: list[str]) -> None:
    payloads = {
        "resource_sites": load_json(CONTENT_DIR / "resource_sites.json"),
        "spells": load_json(CONTENT_DIR / "spells.json"),
        "units": load_json(CONTENT_DIR / "units.json"),
        "scenarios": load_json(CONTENT_DIR / "scenarios.json"),
    }
    resource_sites = items_index(payloads["resource_sites"])
    spells = items_index(payloads["spells"])
    units = items_index(payloads["units"])
    scenarios = items_index(payloads["scenarios"])

    ensure(LOGISTICS_SITE_IDS.issubset(resource_sites.keys()), errors, "Release overworld logistics slice must keep all authored logistics-site ids present")
    families_present = {
        str(site.get("family", ""))
        for site in resource_sites.values()
        if str(site.get("family", "")) in LOGISTICS_SITE_FAMILIES
    }
    ensure(LOGISTICS_SITE_FAMILIES.issubset(families_present), errors, "Release overworld logistics slice must keep neutral dwellings, faction outposts, and frontier shrines authored")

    for site_id in LOGISTICS_SITE_IDS:
        site = resource_sites.get(site_id, {})
        family = str(site.get("family", ""))
        ensure(bool(site.get("persistent_control", False)), errors, f"Logistics site {site_id} must remain persistent-control content")
        response_profile = site.get("response_profile", {})
        ensure(isinstance(response_profile, dict) and bool(response_profile), errors, f"Logistics site {site_id} must define response_profile")
        if isinstance(response_profile, dict):
            ensure(bool(str(response_profile.get("action_label", ""))), errors, f"Logistics site {site_id} response_profile must define action_label")
            ensure(bool(str(response_profile.get("summary", ""))), errors, f"Logistics site {site_id} response_profile must define summary")
            ensure(int(response_profile.get("movement_cost", 0)) > 0, errors, f"Logistics site {site_id} response_profile must define movement_cost > 0")
            ensure(int(response_profile.get("watch_days", 0)) > 0, errors, f"Logistics site {site_id} response_profile must define watch_days > 0")
            resource_cost = response_profile.get("resource_cost", {})
            ensure(isinstance(resource_cost, dict) and bool(resource_cost), errors, f"Logistics site {site_id} response_profile must define non-empty resource_cost")
            ensure(
                sum(
                    int(response_profile.get(key, 0))
                    for key in ("quality_bonus", "readiness_bonus", "pressure_bonus", "recovery_relief")
                ) > 0,
                errors,
                f"Logistics site {site_id} response_profile must define at least one strategic payoff bonus",
            )
        if family == "neutral_dwelling":
            claim_recruits = site.get("claim_recruits", {})
            weekly_recruits = site.get("weekly_recruits", {})
            ensure(isinstance(claim_recruits, dict) and bool(claim_recruits), errors, f"Neutral dwelling {site_id} must define claim_recruits")
            ensure(isinstance(weekly_recruits, dict) and bool(weekly_recruits), errors, f"Neutral dwelling {site_id} must define weekly_recruits")
            for recruit_payload in (claim_recruits, weekly_recruits):
                if not isinstance(recruit_payload, dict):
                    continue
                for unit_id, amount in recruit_payload.items():
                    ensure(str(unit_id) in units, errors, f"Logistics site {site_id} references missing unit {unit_id}")
                    ensure(int(amount) > 0, errors, f"Logistics site {site_id} must define positive recruit counts for {unit_id}")
        elif family == "faction_outpost":
            ensure(int(site.get("vision_radius", 0)) > 0, errors, f"Faction outpost {site_id} must keep a scouting radius payoff")
            ensure(int(site.get("pressure_guard", 0)) > 0, errors, f"Faction outpost {site_id} must keep a pressure_guard payoff")
        elif family == "frontier_shrine":
            spell_id = str(site.get("learn_spell_id", ""))
            ensure(spell_id in spells, errors, f"Frontier shrine {site_id} references missing spell {spell_id}")
            ensure(str(spells.get(spell_id, {}).get("context", "")) == "overworld", errors, f"Frontier shrine {site_id} must teach an overworld spell")

    beacon_path = spells.get("spell_beacon_path", {})
    ensure(bool(beacon_path), errors, "Release overworld logistics slice must keep Beacon Path authored")
    ensure(str(beacon_path.get("context", "")) == "overworld", errors, "Beacon Path must remain an overworld spell")
    ensure(str(beacon_path.get("effect", {}).get("type", "")) == "restore_movement", errors, "Beacon Path must remain a restore_movement spell")
    ensure(int(beacon_path.get("effect", {}).get("amount", 0)) >= 5, errors, "Beacon Path must keep a strong movement-restoration payload")

    total_logistics_placements = 0
    for scenario_id, scenario in scenarios.items():
        logistics_families = set()
        logistics_count = 0
        for placement in scenario.get("resource_nodes", []):
            if not isinstance(placement, dict):
                continue
            site = resource_sites.get(str(placement.get("site_id", "")), {})
            family = str(site.get("family", ""))
            if family in LOGISTICS_SITE_FAMILIES:
                logistics_families.add(family)
                logistics_count += 1
        total_logistics_placements += logistics_count
        if scenario_id in RELEASE_LOGISTICS_SCENARIO_IDS:
            ensure(LOGISTICS_SITE_FAMILIES.issubset(logistics_families), errors, f"Scenario {scenario_id} must place at least one neutral dwelling, faction outpost, and frontier shrine")
        if scenario_id in STRATEGIC_RESPONSE_SCENARIO_IDS:
            player_recovery_present = any(
                isinstance(placement, dict)
                and str(placement.get("owner", "")) == "player"
                and int((placement.get("recovery", {}) if isinstance(placement.get("recovery", {}), dict) else {}).get("pressure", 0)) > 0
                for placement in scenario.get("towns", [])
            )
            ensure(player_recovery_present, errors, f"Scenario {scenario_id} must surface at least one player-town recovery pressure point for response gameplay")
        if scenario_id == "glassfen-breakers":
            ensure(logistics_count >= 3, errors, "Glassfen Breakers must keep multiple logistics sites for skirmish-facing overworld variety")
        if scenario_id == "lockmarsh-surge":
            ensure(LOGISTICS_SITE_FAMILIES.issubset(logistics_families), errors, "Lockmarsh Surge must place dwelling, outpost, and shrine logistics sites around Highwater's capital front")
    ensure(total_logistics_placements >= 18, errors, "Release overworld logistics slice must keep broad authored placement coverage across current scenarios")

    overworld_text = OVERWORLD_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        "func controlled_resource_site_income",
        "func apply_controlled_resource_site_musters",
        "func controlled_resource_site_count",
        "func _resource_site_context_summary",
        "func _resource_site_is_persistent",
        "func _find_context_resource_node",
        "func _grant_site_claim_recruits",
        "func _learn_site_spell",
        "func _apply_site_reveal",
        "func describe_town_response_panel",
        "func get_town_response_actions",
        "func perform_town_response_action",
        "func relieve_town_recovery_pressure",
        "func _issue_resource_site_response",
        "func _resource_site_response_profile",
        "func _resource_site_response_state",
    ):
        ensure(required_token in overworld_text, errors, f"OverworldRules.gd is missing overworld-logistics token: {required_token}")

    hero_command_text = HERO_COMMAND_RULES_PATH.read_text(encoding="utf-8")
    ensure("func spend_active_hero_movement" in hero_command_text, errors, "HeroCommandRules.gd must expose spend_active_hero_movement for strategic response orders")

    enemy_turn_text = ENEMY_TURN_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        "OverworldRulesScript.controlled_resource_site_income",
        "OverworldRulesScript.controlled_resource_site_pressure_bonus",
        "OverworldRulesScript.player_resource_site_pressure_guard",
        "OverworldRulesScript.apply_controlled_resource_site_musters",
    ):
        ensure(required_token in enemy_turn_text, errors, f"EnemyTurnRules.gd is missing logistics-site turn token: {required_token}")

    enemy_adventure_text = ENEMY_ADVENTURE_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        "func _resource_node_contestable_by_faction",
        "func _resource_site_strategic_value",
        "func _resource_site_pressure_value",
        "func _recruit_payload_value",
        "_resource_node_contestable_by_faction(node, site, faction_id)",
        "_resource_site_claim_rewards(site)",
        '"response_until_day"',
    ):
        ensure(required_token in enemy_adventure_text, errors, f"EnemyAdventureRules.gd is missing logistics-site contestation token: {required_token}")


def validate_overworld_route_security_escort(errors: list[str]) -> None:
    required_paths = (OVERWORLD_RULES_PATH, ENEMY_ADVENTURE_RULES_PATH, ENEMY_TURN_RULES_PATH)
    for path in required_paths:
        ensure(path.exists(), errors, f"Missing overworld escort-route file: {path.relative_to(ROOT)}")
    if not all(path.exists() for path in required_paths):
        return

    overworld_text = OVERWORLD_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        '"response_commander_id"',
        '"response_security_rating"',
        "func _route_security_rating_for_hero",
        "HeroCommandRulesScript.active_hero(session)",
        "HeroCommandRulesScript.hero_by_id(session, commander_id)",
        '"pressure_guard_bonus"',
        '"growth_bonus_percent"',
        '"break_pressure"',
        '"response_growth_bonus_percent"',
        '"response_pressure_guard_bonus"',
        "Route escort strength",
    ):
        ensure(required_token in overworld_text, errors, f"OverworldRules.gd is missing escort-route token: {required_token}")

    enemy_adventure_text = ENEMY_ADVENTURE_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        '"response_security_rating"',
        '"response_commander_id"',
        "breaks its escorted logistics route",
        "escort_strength",
    ):
        ensure(required_token in enemy_adventure_text, errors, f"EnemyAdventureRules.gd is missing escort-route contest token: {required_token}")

    enemy_turn_text = ENEMY_TURN_RULES_PATH.read_text(encoding="utf-8")
    ensure(
        "OverworldRulesScript.player_resource_site_pressure_guard" in enemy_turn_text,
        errors,
        "EnemyTurnRules.gd must continue routing escorted site pressure guard through the shared overworld boundary",
    )


def validate_overworld_content_foundation(errors: list[str]) -> None:
    payloads = {
        "biomes": load_json(CONTENT_DIR / "biomes.json"),
        "map_objects": load_json(CONTENT_DIR / "map_objects.json"),
        "resource_sites": load_json(CONTENT_DIR / "resource_sites.json"),
        "factions": load_json(CONTENT_DIR / "factions.json"),
        "spells": load_json(CONTENT_DIR / "spells.json"),
        "units": load_json(CONTENT_DIR / "units.json"),
        "army_groups": load_json(CONTENT_DIR / "army_groups.json"),
        "encounters": load_json(CONTENT_DIR / "encounters.json"),
    }
    biomes = items_index(payloads["biomes"])
    map_objects = items_index(payloads["map_objects"])
    resource_sites = items_index(payloads["resource_sites"])
    factions = items_index(payloads["factions"])
    spells = items_index(payloads["spells"])
    units = items_index(payloads["units"])
    army_groups = items_index(payloads["army_groups"])
    encounters = items_index(payloads["encounters"])

    ensure(len(biomes) >= 9, errors, "Overworld content foundation must author at least the nine bible biome families")
    terrain_to_biome: dict[str, str] = {}
    site_families_allowed_by_biomes: set[str] = set()
    for biome_id, biome in biomes.items():
        ensure(bool(str(biome.get("name", ""))), errors, f"Biome {biome_id} must define name")
        tile_ids = biome.get("map_tile_ids", [])
        ensure(isinstance(tile_ids, list) and bool(tile_ids), errors, f"Biome {biome_id} must define map_tile_ids")
        if isinstance(tile_ids, list):
            for tile_id in tile_ids:
                tile_key = str(tile_id)
                ensure(bool(tile_key), errors, f"Biome {biome_id} contains an empty map tile id")
                ensure(tile_key not in terrain_to_biome, errors, f"Map tile id {tile_key} is assigned to more than one biome")
                terrain_to_biome[tile_key] = biome_id
        ensure(int(biome.get("movement_cost", 0)) > 0, errors, f"Biome {biome_id} must define movement_cost > 0")
        ensure("passable" in biome, errors, f"Biome {biome_id} must explicitly define passable")
        ensure(bool(str(biome.get("battle_terrain", ""))), errors, f"Biome {biome_id} must define battle_terrain")
        for list_key in ("encounter_palette_tags", "decoration_palette", "blocker_palette", "route_roles"):
            values = biome.get(list_key, [])
            ensure(isinstance(values, list) and bool(values), errors, f"Biome {biome_id} must define non-empty {list_key}")
        allowed_families = biome.get("allowed_site_families", [])
        ensure(isinstance(allowed_families, list) and bool(allowed_families), errors, f"Biome {biome_id} must define allowed_site_families")
        if isinstance(allowed_families, list):
            for family_id in allowed_families:
                family_key = str(family_id)
                ensure(family_key in SUPPORTED_RESOURCE_SITE_FAMILIES, errors, f"Biome {biome_id} allows unsupported site family {family_key}")
                site_families_allowed_by_biomes.add(family_key)

    ensure({"grass", "forest", "water"}.issubset(terrain_to_biome.keys()), errors, "Biomes must map the terrain ids used by current scenarios: grass, forest, and water")
    if "water" in terrain_to_biome:
        ensure(not bool(biomes.get(terrain_to_biome["water"], {}).get("passable", True)), errors, "The biome mapped from water must remain impassable for current overworld pathing")
    ensure(OVERWORLD_FOUNDATION_SITE_FAMILIES.issubset(site_families_allowed_by_biomes), errors, "Biome palettes must allow mines, scouting structures, guarded reward sites, transit objects, and repeatable services")

    ensure(OVERWORLD_FOUNDATION_RESOURCE_SITE_IDS.issubset(resource_sites.keys()), errors, "Overworld content foundation must keep the first new resource-site family set authored")
    families_present = {str(site.get("family", "one_shot_pickup")) for site in resource_sites.values()}
    ensure(OVERWORLD_FOUNDATION_SITE_FAMILIES.issubset(families_present), errors, "Resource sites must include mines, scouting structures, guarded reward sites, transit objects, and repeatable services")

    for site_id, site in resource_sites.items():
        family = str(site.get("family", "one_shot_pickup")) or "one_shot_pickup"
        ensure(family in SUPPORTED_RESOURCE_SITE_FAMILIES, errors, f"Resource site {site_id} uses unsupported family {family}")
        for resource_key in ("rewards", "claim_rewards", "control_income", "service_cost"):
            resources = site.get(resource_key, {})
            if resource_key in site:
                ensure(isinstance(resources, dict), errors, f"Resource site {site_id} {resource_key} must be a dictionary")
            if isinstance(resources, dict):
                for key, amount in resources.items():
                    ensure(bool(str(key)), errors, f"Resource site {site_id} {resource_key} cannot contain empty resource keys")
                    ensure(int(amount) >= 0, errors, f"Resource site {site_id} {resource_key} must be >= 0 for {key}")
        for recruit_key in ("claim_recruits", "weekly_recruits"):
            recruits = site.get(recruit_key, {})
            if recruit_key in site:
                ensure(isinstance(recruits, dict), errors, f"Resource site {site_id} {recruit_key} must be a dictionary")
            if isinstance(recruits, dict):
                for unit_id, amount in recruits.items():
                    ensure(str(unit_id) in units, errors, f"Resource site {site_id} references missing unit {unit_id}")
                    ensure(int(amount) > 0, errors, f"Resource site {site_id} {recruit_key} must define positive counts for {unit_id}")
        neutral_roster = site.get("neutral_roster", {})
        if "neutral_roster" in site:
            ensure(isinstance(neutral_roster, dict) and bool(neutral_roster), errors, f"Resource site {site_id} neutral_roster must be a non-empty dictionary")
            if isinstance(neutral_roster, dict):
                for recruit_key in ("claim_recruits", "weekly_recruits"):
                    roster_recruits = neutral_roster.get(recruit_key, {})
                    ensure(isinstance(roster_recruits, dict) and bool(roster_recruits), errors, f"Resource site {site_id} neutral_roster must define {recruit_key}")
                    if isinstance(roster_recruits, dict):
                        for unit_id, amount in roster_recruits.items():
                            ensure(str(unit_id) in units, errors, f"Resource site {site_id} neutral_roster references missing unit {unit_id}")
                            if str(unit_id) in units:
                                ensure(is_neutral_unit(units[str(unit_id)]), errors, f"Resource site {site_id} neutral_roster unit {unit_id} must be neutral")
                            ensure(int(amount) > 0, errors, f"Resource site {site_id} neutral_roster {recruit_key} must define positive counts for {unit_id}")
                guard_army_group_id = str(neutral_roster.get("guard_army_group_id", ""))
                if guard_army_group_id:
                    ensure(guard_army_group_id in army_groups, errors, f"Resource site {site_id} neutral_roster references missing guard army group {guard_army_group_id}")
                    if guard_army_group_id in army_groups:
                        ensure(is_neutral_army_group(army_groups[guard_army_group_id]), errors, f"Resource site {site_id} guard army group must be neutral")
                guard_encounter_id = str(neutral_roster.get("guard_encounter_id", ""))
                if guard_encounter_id:
                    ensure(guard_encounter_id in encounters, errors, f"Resource site {site_id} neutral_roster references missing guard encounter {guard_encounter_id}")
        spell_id = str(site.get("learn_spell_id", ""))
        if spell_id:
            ensure(spell_id in spells, errors, f"Resource site {site_id} references missing learn_spell_id {spell_id}")
            ensure(str(spells.get(spell_id, {}).get("context", "")) == "overworld", errors, f"Resource site {site_id} learn_spell_id must be an overworld spell")
        if family == "mine":
            ensure(bool(site.get("persistent_control", False)), errors, f"Mine {site_id} must be persistent-control content")
            ensure(isinstance(site.get("control_income", {}), dict) and bool(site.get("control_income", {})), errors, f"Mine {site_id} must define control_income")
        elif family == "scouting_structure":
            ensure(bool(site.get("persistent_control", False)), errors, f"Scouting structure {site_id} must be persistent-control content")
            ensure(int(site.get("vision_radius", 0)) > 0, errors, f"Scouting structure {site_id} must define vision_radius > 0")
        elif family == "guarded_reward_site":
            ensure(bool(site.get("guarded", False)), errors, f"Guarded reward site {site_id} must set guarded=true")
            guard_profile = site.get("guard_profile", {})
            ensure(isinstance(guard_profile, dict) and bool(guard_profile), errors, f"Guarded reward site {site_id} must define guard_profile")
            ensure(isinstance(site.get("rewards", site.get("claim_rewards", {})), dict) and bool(site.get("rewards", site.get("claim_rewards", {}))), errors, f"Guarded reward site {site_id} must define a reward payload")
        elif family == "transit_object":
            ensure(isinstance(site.get("transit_profile", {}), dict) and bool(site.get("transit_profile", {})), errors, f"Transit site {site_id} must define transit_profile")
        elif family == "repeatable_service":
            ensure(bool(site.get("repeatable", False)), errors, f"Repeatable service {site_id} must set repeatable=true")
            ensure(int(site.get("visit_cooldown_days", 0)) > 0, errors, f"Repeatable service {site_id} must define visit_cooldown_days > 0")

    ensure(len(map_objects) >= 15, errors, "Overworld content foundation must author a meaningful first map-object vocabulary")
    object_families = {str(obj.get("family", "")) for obj in map_objects.values()}
    ensure(
        {"mine", "scouting_structure", "guarded_reward_site", "transit_object", "repeatable_service", "blocker", "faction_landmark"}.issubset(object_families),
        errors,
        "Map objects must cover economy, scouting, guarded reward, transit, service, blocker, and faction-landmark families",
    )
    for object_id, obj in map_objects.items():
        family = str(obj.get("family", ""))
        ensure(family in SUPPORTED_MAP_OBJECT_FAMILIES, errors, f"Map object {object_id} uses unsupported family {family}")
        biome_ids = obj.get("biome_ids", [])
        ensure(isinstance(biome_ids, list) and bool(biome_ids), errors, f"Map object {object_id} must define biome_ids")
        if isinstance(biome_ids, list):
            for biome_id in biome_ids:
                ensure(str(biome_id) in biomes, errors, f"Map object {object_id} references missing biome {biome_id}")
        resource_site_id = str(obj.get("resource_site_id", ""))
        if resource_site_id:
            ensure(resource_site_id in resource_sites, errors, f"Map object {object_id} references missing resource site {resource_site_id}")
            if resource_site_id in resource_sites and family in OVERWORLD_FOUNDATION_SITE_FAMILIES:
                ensure(str(resource_sites[resource_site_id].get("family", "")) == family, errors, f"Map object {object_id} family must match linked resource site {resource_site_id}")
        faction_id = str(obj.get("faction_id", ""))
        if faction_id:
            ensure(faction_id in factions, errors, f"Map object {object_id} references missing faction {faction_id}")
        footprint = obj.get("footprint", {})
        ensure(isinstance(footprint, dict), errors, f"Map object {object_id} must define footprint")
        if isinstance(footprint, dict):
            ensure(int(footprint.get("width", 0)) > 0 and int(footprint.get("height", 0)) > 0, errors, f"Map object {object_id} footprint dimensions must be > 0")
        ensure("passable" in obj and "visitable" in obj, errors, f"Map object {object_id} must explicitly define passable and visitable")
        map_roles = obj.get("map_roles", [])
        ensure(isinstance(map_roles, list) and bool(map_roles), errors, f"Map object {object_id} must define map_roles")

    content_service_text = CONTENT_SERVICE_PATH.read_text(encoding="utf-8")
    for required_token in (
        "const BIOMES_PATH",
        "const MAP_OBJECTS_PATH",
        "func get_biome",
        "func get_biome_for_terrain",
        "func get_map_object",
        "func _validate_biome",
        "func _validate_map_object",
        "func _validate_resource_site",
    ):
        ensure(required_token in content_service_text, errors, f"ContentService.gd is missing overworld-content-foundation token: {required_token}")

    overworld_text = OVERWORLD_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        "func terrain_profile_at",
        "ContentService.get_biome_for_terrain",
        "func _resource_site_is_repeatable",
        "func _resource_site_visit_cost",
        '"mine"',
        '"scouting_structure"',
        '"guarded_reward_site"',
        '"transit_object"',
        '"repeatable_service"',
    ):
        ensure(required_token in overworld_text, errors, f"OverworldRules.gd is missing overworld-content-foundation token: {required_token}")

    scenario_rules_text = SCENARIO_RULES_PATH.read_text(encoding="utf-8")
    ensure("ContentService.get_biome_for_terrain" in scenario_rules_text, errors, "ScenarioRules.gd must label scenario terrain through authored biomes")


def validate_overworld_art_asset_slice(errors: list[str]) -> None:
    required_paths = (
        OVERWORLD_ART_MANIFEST_PATH,
        TERRAIN_GRAMMAR_PATH,
        TERRAIN_LAYERS_PATH,
        OVERWORLD_MAP_VIEW_SCRIPT_PATH,
        ROOT / "tools" / "build_overworld_terrain_tiles.py",
        ROOT / "art" / "overworld" / "source" / "manifest" / "generated-overworld-assets-20260419.json",
    )
    for path in required_paths:
        ensure(path.exists(), errors, f"Missing overworld art slice file: {path.relative_to(ROOT)}")
    if not all(path.exists() for path in required_paths):
        return

    manifest = load_json(OVERWORLD_ART_MANIFEST_PATH)
    terrain_rendering = manifest.get("terrain_rendering", {})
    terrain_grammar = load_json(TERRAIN_GRAMMAR_PATH)
    terrain_layers = items_index(load_json(TERRAIN_LAYERS_PATH))
    object_assets = manifest.get("object_assets", {})
    site_sprites = manifest.get("resource_site_sprites", {})
    artifact_default = manifest.get("artifact_default_sprite", {})
    town_default = manifest.get("town_default_sprite", {})
    encounter_default = manifest.get("encounter_default_sprite", {})
    ensure(isinstance(terrain_rendering, dict), errors, "Overworld art manifest must define terrain_rendering")
    ensure(isinstance(object_assets, dict), errors, "Overworld art manifest must define object_assets")
    ensure(isinstance(site_sprites, dict), errors, "Overworld art manifest must define resource_site_sprites")
    ensure(isinstance(artifact_default, dict), errors, "Overworld art manifest must define artifact_default_sprite")
    ensure(isinstance(town_default, dict), errors, "Overworld art manifest must define town_default_sprite")
    ensure(isinstance(encounter_default, dict), errors, "Overworld art manifest must define encounter_default_sprite")
    ensure("terrain_textures" not in manifest, errors, "Overworld art manifest must not keep sampled terrain textures as the active terrain model")
    if isinstance(terrain_rendering, dict):
        ensure(str(terrain_rendering.get("model", "")) == "authored_autotile_layers", errors, "Overworld terrain rendering must use the authored autotile layer model")
        ensure(str(terrain_rendering.get("grammar", "")) == "res://content/terrain_grammar.json", errors, "Overworld terrain rendering must point at content/terrain_grammar.json")
        ensure(str(terrain_rendering.get("terrain_layers", "")) == "res://content/terrain_layers.json", errors, "Overworld terrain rendering must point at content/terrain_layers.json")
        ensure(str(terrain_rendering.get("tile_art_root", "")) == "res://art/overworld/runtime/terrain_tiles", errors, "Overworld terrain rendering must point at the authored terrain tile-art root")
        ensure(str(terrain_rendering.get("tile_art_status", "")) == "original_quiet_terrain_correction", errors, "Overworld terrain rendering must record the original quiet terrain correction status")
        ensure(str(terrain_rendering.get("tile_art_source_basis", "")) == "original_procedural_reference_informed", errors, "Overworld terrain rendering must use original procedural terrain art as its source basis")
        ensure(str(terrain_rendering.get("primary_base_model", "")) == "original_quiet_tile_bank", errors, "Overworld terrain rendering must make the original quiet tile bank the primary base model")
        ensure(str(terrain_rendering.get("generated_source_policy", "")) == "deprecated_for_primary_base_color_reference_or_limited_decal_only", errors, "Overworld terrain rendering must document generated terrain sources as deprecated for primary bases")
        authored_tile_sets = terrain_rendering.get("authored_tile_sets", [])
        ensure(isinstance(authored_tile_sets, list) and TERRAIN_GRAMMAR_REQUIRED_TERRAIN_IDS.issubset(set(map(str, authored_tile_sets))) and "road_dirt" in set(map(str, authored_tile_sets)), errors, "Overworld terrain rendering must list the first authored terrain and road tile sets")
        ensure(str(terrain_rendering.get("sampled_texture_status", "")) == "deprecated_not_primary", errors, "Overworld sampled terrain textures must be marked deprecated_not_primary")
    if not isinstance(object_assets, dict) or not isinstance(site_sprites, dict):
        return

    terrain_classes = terrain_grammar.get("terrain_classes", [])
    overlay_classes = terrain_grammar.get("overlay_classes", [])
    ensure(str(terrain_grammar.get("rendering_model", "")) == "authored_autotile_layers", errors, "Terrain grammar must declare authored_autotile_layers")
    ensure(str(terrain_grammar.get("authoring_status", "")) == "original_quiet_terrain_correction", errors, "Terrain grammar must record the original quiet terrain correction status")
    ensure(str(terrain_grammar.get("primary_base_model", "")) == "original_quiet_tile_bank", errors, "Terrain grammar must make the original quiet tile bank primary")
    ensure(str(terrain_grammar.get("generated_source_policy", "")) == "deprecated_for_primary_base_color_reference_or_limited_decal_only", errors, "Terrain grammar must deprecate generated terrain sheets for primary bases")
    ensure(isinstance(terrain_classes, list) and bool(terrain_classes), errors, "Terrain grammar must define terrain_classes")
    ensure(isinstance(overlay_classes, list) and bool(overlay_classes), errors, "Terrain grammar must define overlay_classes")
    terrain_class_ids: set[str] = set()
    road_enabled_terrain_ids: set[str] = set()
    if isinstance(terrain_classes, list):
        for terrain_class in terrain_classes:
            ensure(isinstance(terrain_class, dict), errors, "Terrain grammar contains a non-dictionary terrain class")
            if not isinstance(terrain_class, dict):
                continue
            terrain_id = str(terrain_class.get("id", ""))
            terrain_class_ids.add(terrain_id)
            for key in ("biome_id", "terrain_group", "autotile_family", "style_id", "base_color", "detail_color", "edge_color", "pattern", "readability_role"):
                ensure(bool(str(terrain_class.get(key, ""))), errors, f"Terrain grammar {terrain_id} must define {key}")
            ensure(int(terrain_class.get("transition_priority", -1)) >= 0, errors, f"Terrain grammar {terrain_id} must define transition_priority >= 0")
            supports = terrain_class.get("supports", [])
            ensure(isinstance(supports, list) and "edge_transitions" in supports, errors, f"Terrain grammar {terrain_id} must support edge_transitions")
            if isinstance(supports, list) and "road_overlay" in supports:
                road_enabled_terrain_ids.add(terrain_id)
            if terrain_id in TERRAIN_GRAMMAR_REQUIRED_TERRAIN_IDS:
                ensure(isinstance(supports, list) and "authored_tile_art" in supports, errors, f"Terrain grammar {terrain_id} must mark authored_tile_art support")
                tile_art = terrain_class.get("tile_art", {})
                ensure(isinstance(tile_art, dict), errors, f"Terrain grammar {terrain_id} must define tile_art")
                if isinstance(tile_art, dict):
                    base_tiles = tile_art.get("base_tiles", [])
                    ensure(isinstance(base_tiles, list) and len(base_tiles) >= 3, errors, f"Terrain grammar {terrain_id} must define at least three authored base tile variants")
                    if isinstance(base_tiles, list):
                        for entry in base_tiles:
                            ensure(isinstance(entry, dict), errors, f"Terrain grammar {terrain_id} contains a non-dictionary base tile art entry")
                            if not isinstance(entry, dict):
                                continue
                            ensure(str(entry.get("variant_key", "")) != "", errors, f"Terrain grammar {terrain_id} base tile art must define variant_key")
                            art_path = res_path_to_disk(str(entry.get("path", "")))
                            ensure(art_path.exists(), errors, f"Terrain grammar {terrain_id} base tile art references missing texture {entry.get('path')}")
                            if art_path.exists():
                                ensure(png_size(art_path) == (64, 64), errors, f"Terrain grammar {terrain_id} base tile art must be 64x64 PNG, found {png_size(art_path)} at {entry.get('path')}")
                    edge_overlays = tile_art.get("edge_overlays", {})
                    ensure(isinstance(edge_overlays, dict), errors, f"Terrain grammar {terrain_id} must define edge_overlays")
                    if isinstance(edge_overlays, dict):
                        for direction in ("N", "E", "S", "W"):
                            art_path = res_path_to_disk(str(edge_overlays.get(direction, "")))
                            ensure(art_path.exists(), errors, f"Terrain grammar {terrain_id} edge overlay {direction} references missing texture {edge_overlays.get(direction)}")
                            if art_path.exists():
                                ensure(png_size(art_path) == (64, 64), errors, f"Terrain grammar {terrain_id} edge overlay {direction} must be 64x64 PNG, found {png_size(art_path)}")
    ensure(TERRAIN_GRAMMAR_REQUIRED_TERRAIN_IDS.issubset(terrain_class_ids), errors, "Terrain grammar must author the first readable terrain slice: grass/plains, forest, mire/swamp, and hills/ridge/highland")
    ensure(TERRAIN_GRAMMAR_REQUIRED_TERRAIN_IDS.issubset(road_enabled_terrain_ids), errors, "First terrain slice ids must support structural road overlays")
    overlay_ids: set[str] = set()
    if isinstance(overlay_classes, list):
        for overlay in overlay_classes:
            ensure(isinstance(overlay, dict), errors, "Terrain grammar contains a non-dictionary overlay class")
            if not isinstance(overlay, dict):
                continue
            overlay_id = str(overlay.get("id", ""))
            overlay_ids.add(overlay_id)
            ensure(str(overlay.get("layer", "")) == "road", errors, f"Terrain overlay {overlay_id} must use the road layer")
            ensure(float(overlay.get("width_fraction", 0.0)) > 0.0, errors, f"Terrain overlay {overlay_id} must define width_fraction > 0")
            if overlay_id == "road_dirt":
                supports = overlay.get("supports", [])
                ensure(isinstance(supports, list) and "authored_tile_art" in supports, errors, "Terrain overlay road_dirt must mark authored_tile_art support")
                tile_art = overlay.get("tile_art", {})
                ensure(isinstance(tile_art, dict), errors, "Terrain overlay road_dirt must define tile_art")
                if isinstance(tile_art, dict):
                    center_path = res_path_to_disk(str(tile_art.get("center", "")))
                    ensure(center_path.exists(), errors, f"Terrain overlay road_dirt center art references missing texture {tile_art.get('center')}")
                    if center_path.exists():
                        ensure(png_size(center_path) == (64, 64), errors, "Terrain overlay road_dirt center art must be a 64x64 PNG")
                    connectors = tile_art.get("connectors", {})
                    ensure(isinstance(connectors, dict), errors, "Terrain overlay road_dirt must define connector art")
                    if isinstance(connectors, dict):
                        for direction in ("N", "E", "S", "W", "NE", "SE", "SW", "NW"):
                            art_path = res_path_to_disk(str(connectors.get(direction, "")))
                            ensure(art_path.exists(), errors, f"Terrain overlay road_dirt connector {direction} references missing texture {connectors.get(direction)}")
                            if art_path.exists():
                                ensure(png_size(art_path) == (64, 64), errors, f"Terrain overlay road_dirt connector {direction} must be a 64x64 PNG")
    ensure("road_dirt" in overlay_ids, errors, "Terrain grammar must define the road_dirt structural road overlay")

    scenarios = items_index(load_json(CONTENT_DIR / "scenarios.json"))
    ensure({"river-pass", SIX_FACTION_BIOME_BREADTH_SCENARIO_ID}.issubset(terrain_layers.keys()), errors, "Terrain layers must author roads for River Pass and Ninefold Confluence")
    for scenario_id in ("river-pass", SIX_FACTION_BIOME_BREADTH_SCENARIO_ID):
        layer = terrain_layers.get(scenario_id, {})
        roads = layer.get("roads", [])
        scenario = scenarios.get(scenario_id, {})
        game_map = scenario.get("map", [])
        ensure(isinstance(roads, list) and bool(roads), errors, f"Terrain layer {scenario_id} must define non-empty roads")
        if not isinstance(roads, list):
            continue
        road_tile_count = 0
        for road in roads:
            ensure(isinstance(road, dict), errors, f"Terrain layer {scenario_id} contains a non-dictionary road")
            if not isinstance(road, dict):
                continue
            ensure(str(road.get("overlay_id", "")) in overlay_ids, errors, f"Terrain layer {scenario_id} road {road.get('id')} references missing overlay {road.get('overlay_id')}")
            tiles = road.get("tiles", [])
            ensure(isinstance(tiles, list) and bool(tiles), errors, f"Terrain layer {scenario_id} road {road.get('id')} must define tiles")
            if not isinstance(tiles, list):
                continue
            road_tile_count += len(tiles)
            for tile in tiles:
                ensure(isinstance(tile, dict), errors, f"Terrain layer {scenario_id} road {road.get('id')} contains a non-dictionary tile")
                if not isinstance(tile, dict):
                    continue
                x = int(tile.get("x", -1))
                y = int(tile.get("y", -1))
                ensure(0 <= y < len(game_map) and isinstance(game_map[y], list) and 0 <= x < len(game_map[y]), errors, f"Terrain layer {scenario_id} road {road.get('id')} tile {x},{y} is out of bounds")
                if 0 <= y < len(game_map) and isinstance(game_map[y], list) and 0 <= x < len(game_map[y]):
                    terrain_id = str(game_map[y][x])
                    ensure(terrain_id in road_enabled_terrain_ids, errors, f"Terrain layer {scenario_id} road {road.get('id')} tile {x},{y} uses non-road terrain {terrain_id}")
        ensure(road_tile_count >= 8, errors, f"Terrain layer {scenario_id} must include enough road tiles to prove structural overlays")

    ensure(OVERWORLD_ART_REQUIRED_ASSET_IDS.issubset(set(object_assets.keys())), errors, "Overworld art manifest must preserve all required prepared object asset ids")
    for asset_id, entry in object_assets.items():
        ensure(isinstance(entry, dict), errors, f"Overworld object art asset {asset_id} must be a dictionary")
        if not isinstance(entry, dict):
            continue
        runtime_path = res_path_to_disk(str(entry.get("path", "")))
        source_trimmed_path = res_path_to_disk(str(entry.get("source_trimmed", "")))
        ensure(runtime_path.exists(), errors, f"Overworld object art asset {asset_id} references missing runtime texture {entry.get('path')}")
        ensure(source_trimmed_path.exists(), errors, f"Overworld object art asset {asset_id} references missing trimmed source texture {entry.get('source_trimmed')}")
        if runtime_path.exists():
            width, height = png_size(runtime_path)
            ensure((width, height) == (512, 512), errors, f"Overworld runtime object asset {asset_id} must use the 512 canvas, found {width}x{height}")

    resource_sites = items_index(load_json(CONTENT_DIR / "resource_sites.json"))
    for site_id, expected_asset_id in OVERWORLD_ART_REQUIRED_SITE_MAPPINGS.items():
        ensure(site_id in resource_sites, errors, f"Overworld art required mapping references missing resource site {site_id}")
        entry = site_sprites.get(site_id, {})
        ensure(isinstance(entry, dict), errors, f"Overworld art required mapping {site_id} must be a dictionary")
        if isinstance(entry, dict):
            ensure(str(entry.get("asset_id", "")) == expected_asset_id, errors, f"Overworld art mapping {site_id} must use {expected_asset_id}")
            ensure(str(entry.get("fit", "")) != "", errors, f"Overworld art mapping {site_id} must record its semantic-fit note")
    for site_id, entry in site_sprites.items():
        ensure(str(site_id) in resource_sites, errors, f"Overworld art mapping references missing resource site {site_id}")
        if isinstance(entry, dict):
            ensure(str(entry.get("asset_id", "")) in object_assets, errors, f"Overworld art mapping {site_id} references missing object asset {entry.get('asset_id')}")

    ensure(str(artifact_default.get("asset_id", "")) == "adventurers_bundle", errors, "Overworld artifact default sprite must use the adventurers_bundle pickup asset")
    if isinstance(town_default, dict):
        ensure(str(town_default.get("asset_id", "")) == "frontier_town", errors, "Overworld town default sprite must use the approved frontier_town placeholder asset")
        ensure(str(town_default.get("fit", "")) != "", errors, "Overworld town default sprite must record its semantic-fit note")
    if isinstance(encounter_default, dict):
        ensure(str(encounter_default.get("asset_id", "")) == "hostile_camp", errors, "Overworld encounter default sprite must use the approved hostile_camp placeholder asset")
        ensure(str(encounter_default.get("fit", "")) != "", errors, "Overworld encounter default sprite must record its semantic-fit note")
    ensure(str(manifest.get("unmapped_object_fallback", "")) == "procedural_marker", errors, "Overworld art manifest must keep procedural marker fallback for unmapped object types")
    ensure(str(manifest.get("remembered_object_rendering", "")) == "ghosted_sprite_with_ground_anchor", errors, "Overworld art manifest must document the remembered-object sprite treatment")
    object_rendering = manifest.get("object_rendering", {})
    ensure(isinstance(object_rendering, dict), errors, "Overworld art manifest must document object-first rendering metadata")
    if isinstance(object_rendering, dict):
        ensure(str(object_rendering.get("presence_model", "")) == "footprint_scaled_world_object", errors, "Overworld object rendering must document footprint-scaled object presence")
        ensure(str(object_rendering.get("depth_cues", "")) == "footprint_cast_shadow_with_base_occlusion", errors, "Overworld object rendering must document footprint cast-shadow/base-occlusion depth cues")
        ensure(str(object_rendering.get("contact_shadow", "")) == "directional_footprint_cast_shadow", errors, "Overworld object rendering must document directional footprint contact shadows")
        ensure(str(object_rendering.get("base_occlusion", "")) == "foreground_base_occlusion_pads", errors, "Overworld object rendering must document foreground base occlusion pads")
        ensure(str(object_rendering.get("mapped_sprite_settlement", "")) == "footprint_scaled_sprite_with_ground_lip", errors, "Overworld object rendering must document settled sprite grounding")
        ensure(str(object_rendering.get("fallback_silhouette", "")) == "family_specific_procedural_world_object", errors, "Overworld object rendering must document family-specific procedural fallback silhouettes")

    map_view_text = OVERWORLD_MAP_VIEW_SCRIPT_PATH.read_text(encoding="utf-8")
    for required_token in (
        "OVERWORLD_ART_MANIFEST_PATH",
        "TERRAIN_GRAMMAR_PATH",
        "TERRAIN_GRAMMAR_RENDERING_MODE",
        "TERRAIN_ORIGINAL_TILE_BANK_RENDERING_MODE",
        "TERRAIN_TILE_ART_RENDERING_MODE",
        "func _load_terrain_grammar",
        "func _draw_terrain_tile_art",
        "func _load_overworld_art_manifest",
        "func _draw_authored_terrain_pattern",
        "func _draw_terrain_transitions",
        "func _draw_road_overlay",
        "func _draw_road_overlay_art",
        "func _draw_object_sprite",
        "func _draw_town_sprite",
        "func _draw_encounter_sprite",
        "func _resource_asset_id",
        "town_default_sprite",
        "encounter_default_sprite",
        "OBJECT_PRESENCE_MODEL",
        "OBJECT_OCCLUSION_MODEL",
        "OBJECT_SPRITE_SETTLEMENT_MODEL",
        "OBJECT_PROCEDURAL_FALLBACK_MODEL",
        "OBJECT_DEPTH_CUE_MODEL",
        "OBJECT_CONTACT_SHADOW_MODEL",
        "OBJECT_BASE_OCCLUSION_MODEL",
        "func _load_map_object_profiles",
        "func _draw_foreground_occlusion_lip",
        "func _draw_directional_contact_shadow",
        "func _draw_base_occlusion_pads",
        '"footprint_scaled_world_object"',
        '"foreground_ground_lip"',
        '"footprint_cast_shadow_with_base_occlusion"',
        '"directional_footprint_cast_shadow"',
        '"foreground_base_occlusion_pads"',
        '"family_specific_procedural_world_object"',
        '"authored_autotile_layers"',
        '"original_quiet_tile_bank"',
        '"uses_sampled_texture"',
        '"uses_authored_tile_art"',
        '"uses_original_tile_bank"',
        '"generated_source_primary"',
        '"primary_base_model"',
        '"edge_transition_art_loaded"',
        '"transition_shape_model"',
        '"road_overlay"',
        '"road_overlay_art"',
        '"road_shape_model"',
        '"fallback_procedural_marker"',
        "ghosted_sprite_with_ground_anchor",
    ):
        ensure(required_token in map_view_text, errors, f"OverworldMapView.gd is missing overworld art token {required_token}")


def validate_neutral_dwelling_unit_slice(errors: list[str]) -> None:
    required_paths = (
        NEUTRAL_DWELLINGS_PATH,
        CONTENT_SERVICE_PATH,
        OVERWORLD_RULES_PATH,
        BATTLE_RULES_PATH,
        CONTENT_DIR / "units.json",
        CONTENT_DIR / "army_groups.json",
        CONTENT_DIR / "resource_sites.json",
        CONTENT_DIR / "map_objects.json",
        CONTENT_DIR / "encounters.json",
        CONTENT_DIR / "factions.json",
        CONTENT_DIR / "biomes.json",
    )
    for path in required_paths:
        ensure(path.exists(), errors, f"Missing neutral dwelling/unit slice file: {path.relative_to(ROOT)}")
    if not all(path.exists() for path in required_paths):
        return

    payloads = {
        "neutral_dwellings": load_json(NEUTRAL_DWELLINGS_PATH),
        "units": load_json(CONTENT_DIR / "units.json"),
        "army_groups": load_json(CONTENT_DIR / "army_groups.json"),
        "resource_sites": load_json(CONTENT_DIR / "resource_sites.json"),
        "map_objects": load_json(CONTENT_DIR / "map_objects.json"),
        "encounters": load_json(CONTENT_DIR / "encounters.json"),
        "factions": load_json(CONTENT_DIR / "factions.json"),
        "biomes": load_json(CONTENT_DIR / "biomes.json"),
    }
    neutral_dwellings = items_index(payloads["neutral_dwellings"])
    units = items_index(payloads["units"])
    army_groups = items_index(payloads["army_groups"])
    resource_sites = items_index(payloads["resource_sites"])
    map_objects = items_index(payloads["map_objects"])
    encounters = items_index(payloads["encounters"])
    factions = items_index(payloads["factions"])
    biomes = items_index(payloads["biomes"])

    neutral_units = {unit_id: unit for unit_id, unit in units.items() if is_neutral_unit(unit)}
    ensure(len(neutral_units) >= 50, errors, "Neutral dwelling breadth slice must author at least fifty neutral units outside faction ladders")
    faction_ladder_unit_ids = {
        str(unit_id)
        for faction in factions.values()
        for unit_id in faction.get("unit_ladder_ids", [])
    }
    for unit_id, unit in neutral_units.items():
        ensure(unit_id not in faction_ladder_unit_ids, errors, f"Neutral unit {unit_id} must not be listed in a faction ladder")
        ensure(str(unit.get("faction_id", "")) == "", errors, f"Neutral unit {unit_id} must not declare faction_id")
        ensure(str(unit.get("content_status", "")) == "neutral_dwelling_slice", errors, f"Neutral unit {unit_id} must be marked neutral_dwelling_slice")

    ensure(len(neutral_dwellings) >= 25, errors, "Neutral dwelling breadth slice must author at least twenty-five neutral dwelling families")
    for dwelling_id, dwelling in neutral_dwellings.items():
        ensure(bool(str(dwelling.get("summary", ""))), errors, f"Neutral dwelling {dwelling_id} must define summary")
        biome_ids = [str(biome_id) for biome_id in dwelling.get("biome_ids", [])]
        ensure(bool(biome_ids), errors, f"Neutral dwelling {dwelling_id} must reference at least one biome")
        for biome_id in biome_ids:
            ensure(biome_id in biomes, errors, f"Neutral dwelling {dwelling_id} references missing biome {biome_id}")
        unit_ids = [str(unit_id) for unit_id in dwelling.get("unit_ids", [])]
        ensure(len(unit_ids) >= 2, errors, f"Neutral dwelling {dwelling_id} must reference at least two neutral units")
        for unit_id in unit_ids:
            ensure(unit_id in neutral_units, errors, f"Neutral dwelling {dwelling_id} references missing neutral unit {unit_id}")
        site_ids = [str(site_id) for site_id in dwelling.get("site_ids", [])]
        ensure(bool(site_ids), errors, f"Neutral dwelling {dwelling_id} must reference at least one neutral dwelling site")
        object_ids = [str(object_id) for object_id in dwelling.get("map_object_ids", [])]
        ensure(bool(object_ids), errors, f"Neutral dwelling {dwelling_id} must reference at least one neutral dwelling map object")
        group_ids = [str(group_id) for group_id in dwelling.get("army_group_ids", [])]
        ensure(bool(group_ids), errors, f"Neutral dwelling {dwelling_id} must reference at least one neutral guard army")
        encounter_ids = [str(encounter_id) for encounter_id in dwelling.get("encounter_ids", [])]
        ensure(bool(encounter_ids), errors, f"Neutral dwelling {dwelling_id} must reference at least one neutral guard encounter")
        for site_id in site_ids:
            site = resource_sites.get(site_id, {})
            ensure(bool(site), errors, f"Neutral dwelling {dwelling_id} references missing site {site_id}")
            if not site:
                continue
            ensure(str(site.get("family", "")) == "neutral_dwelling", errors, f"Neutral dwelling site {site_id} must use neutral_dwelling family")
            ensure(str(site.get("dwelling_scope", "")) == "neutral", errors, f"Neutral dwelling site {site_id} must be marked dwelling_scope neutral")
            ensure(str(site.get("neutral_dwelling_family_id", "")) == dwelling_id, errors, f"Neutral dwelling site {site_id} must reference family {dwelling_id}")
            for recruit_key in ("claim_recruits", "weekly_recruits"):
                recruits = site.get(recruit_key, {})
                ensure(isinstance(recruits, dict) and bool(recruits), errors, f"Neutral dwelling site {site_id} must define {recruit_key}")
                if isinstance(recruits, dict):
                    for unit_id, amount in recruits.items():
                        ensure(str(unit_id) in neutral_units, errors, f"Neutral dwelling site {site_id} {recruit_key} must use neutral unit {unit_id}")
                        ensure(int(amount) > 0, errors, f"Neutral dwelling site {site_id} {recruit_key} must define positive count for {unit_id}")
            roster = site.get("neutral_roster", {})
            ensure(isinstance(roster, dict) and bool(roster), errors, f"Neutral dwelling site {site_id} must define neutral_roster")
            if isinstance(roster, dict):
                guard_group_id = str(roster.get("guard_army_group_id", ""))
                guard_encounter_id = str(roster.get("guard_encounter_id", ""))
                ensure(guard_group_id in army_groups, errors, f"Neutral dwelling site {site_id} guard army group {guard_group_id} is missing")
                ensure(guard_group_id in group_ids, errors, f"Neutral dwelling site {site_id} guard army group {guard_group_id} must be listed by family {dwelling_id}")
                ensure(guard_encounter_id in encounters, errors, f"Neutral dwelling site {site_id} guard encounter {guard_encounter_id} is missing")
                ensure(guard_encounter_id in encounter_ids, errors, f"Neutral dwelling site {site_id} guard encounter {guard_encounter_id} must be listed by family {dwelling_id}")
        for object_id in object_ids:
            obj = map_objects.get(object_id, {})
            ensure(bool(obj), errors, f"Neutral dwelling {dwelling_id} references missing map object {object_id}")
            if obj:
                ensure(str(obj.get("family", "")) == "neutral_dwelling", errors, f"Neutral dwelling map object {object_id} must use neutral_dwelling family")
                ensure(str(obj.get("resource_site_id", "")) in site_ids, errors, f"Neutral dwelling map object {object_id} must link to one of its family sites")
        for group_id in group_ids:
            group = army_groups.get(group_id, {})
            ensure(is_neutral_army_group(group), errors, f"Neutral dwelling {dwelling_id} army group {group_id} must be neutral")
            for stack in group.get("stacks", []) if isinstance(group, dict) else []:
                if isinstance(stack, dict):
                    ensure(str(stack.get("unit_id", "")) in neutral_units, errors, f"Neutral army group {group_id} stack must use neutral units")
        for encounter_id in encounter_ids:
            encounter = encounters.get(encounter_id, {})
            ensure(str(encounter.get("affiliation", "")) == "neutral", errors, f"Neutral dwelling encounter {encounter_id} must be marked neutral")
            group_id = str(encounter.get("enemy_group_id", ""))
            ensure(group_id in army_groups and is_neutral_army_group(army_groups[group_id]), errors, f"Neutral dwelling encounter {encounter_id} must use a neutral army group")

    content_service_text = CONTENT_SERVICE_PATH.read_text(encoding="utf-8")
    for required_token in (
        "NEUTRAL_DWELLINGS_PATH",
        "func get_neutral_dwelling",
        "func _validate_neutral_dwelling",
        "func _unit_is_neutral",
    ):
        ensure(required_token in content_service_text, errors, f"ContentService.gd is missing neutral dwelling token {required_token}")

    overworld_text = OVERWORLD_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        "func _resource_site_claim_recruits",
        "func _resource_site_weekly_recruits",
        "func _resource_site_neutral_dwelling_label",
        "Neutral family",
    ):
        ensure(required_token in overworld_text, errors, f"OverworldRules.gd is missing neutral dwelling token {required_token}")

    battle_text = BATTLE_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        '"enemy_army_affiliation"',
        '"affiliation"',
        "func _army_affiliation",
    ):
        ensure(required_token in battle_text, errors, f"BattleRules.gd is missing neutral battle token {required_token}")


def validate_six_faction_biome_scenario_breadth(errors: list[str]) -> None:
    payloads = {
        "scenarios": load_json(CONTENT_DIR / "scenarios.json"),
        "factions": load_json(CONTENT_DIR / "factions.json"),
        "towns": load_json(CONTENT_DIR / "towns.json"),
        "resource_sites": load_json(CONTENT_DIR / "resource_sites.json"),
        "neutral_dwellings": load_json(NEUTRAL_DWELLINGS_PATH),
        "biomes": load_json(CONTENT_DIR / "biomes.json"),
        "army_groups": load_json(CONTENT_DIR / "army_groups.json"),
        "encounters": load_json(CONTENT_DIR / "encounters.json"),
    }
    scenarios = items_index(payloads["scenarios"])
    factions = items_index(payloads["factions"])
    towns = items_index(payloads["towns"])
    resource_sites = items_index(payloads["resource_sites"])
    neutral_dwellings = items_index(payloads["neutral_dwellings"])
    biomes = items_index(payloads["biomes"])
    army_groups = items_index(payloads["army_groups"])
    encounters = items_index(payloads["encounters"])

    scenario = scenarios.get(SIX_FACTION_BIOME_BREADTH_SCENARIO_ID, {})
    ensure(bool(scenario), errors, "Ninefold Confluence scenario must stay authored for the six-faction biome breadth slice")
    if not scenario:
        return

    game_map = scenario.get("map", [])
    declared_size = scenario.get("map_size", {})
    ensure(int(declared_size.get("width", 0)) == 64, errors, "Ninefold Confluence must declare width 64")
    ensure(int(declared_size.get("height", 0)) == 64, errors, "Ninefold Confluence must declare height 64")
    ensure(isinstance(game_map, list) and len(game_map) == 64, errors, "Ninefold Confluence must author 64 map rows")
    if isinstance(game_map, list) and game_map:
        ensure(all(isinstance(row, list) and len(row) == 64 for row in game_map), errors, "Ninefold Confluence must author 64 columns in every row")

    terrain_to_biome: dict[str, str] = {}
    for biome_id, biome in biomes.items():
        for terrain_id in biome.get("map_tile_ids", []):
            terrain_to_biome[str(terrain_id)] = biome_id
    authored_biome_ids: set[str] = set()
    if isinstance(game_map, list):
        for row in game_map:
            if not isinstance(row, list):
                continue
            for terrain_id in row:
                biome_id = terrain_to_biome.get(str(terrain_id), "")
                if biome_id:
                    authored_biome_ids.add(biome_id)
    ensure(set(biomes.keys()).issubset(authored_biome_ids), errors, "Ninefold Confluence map must represent every authored biome family")

    scenario_faction_ids = {str(scenario.get("player_faction_id", ""))}
    for placement in scenario.get("towns", []):
        if not isinstance(placement, dict):
            continue
        town = towns.get(str(placement.get("town_id", "")), {})
        if town:
            scenario_faction_ids.add(str(town.get("faction_id", "")))
    for enemy_faction in scenario.get("enemy_factions", []):
        if isinstance(enemy_faction, dict):
            scenario_faction_ids.add(str(enemy_faction.get("faction_id", "")))
    for node in scenario.get("resource_nodes", []):
        if isinstance(node, dict) and str(node.get("collected_by_faction_id", "")):
            scenario_faction_ids.add(str(node.get("collected_by_faction_id", "")))
    for hook in scenario.get("script_hooks", []):
        if not isinstance(hook, dict):
            continue
        for effect in hook.get("effects", []):
            if not isinstance(effect, dict):
                continue
            if str(effect.get("faction_id", "")):
                scenario_faction_ids.add(str(effect.get("faction_id", "")))
            placement = effect.get("placement", {})
            if isinstance(placement, dict) and str(placement.get("spawned_by_faction_id", "")):
                scenario_faction_ids.add(str(placement.get("spawned_by_faction_id", "")))
    ensure(SIX_FACTION_BIBLE_IDS.issubset(scenario_faction_ids), errors, "Ninefold Confluence must give every six-faction scaffold id direct scenario presence")
    for faction_id in SIX_FACTION_BIBLE_IDS:
        ensure(faction_id in factions, errors, f"Ninefold Confluence references missing faction {faction_id}")

    required_new_groups = {
        "army_graftroot_wardens",
        "army_orevein_exactors",
        "army_bellwake_privateers",
    }
    ensure(required_new_groups.issubset(army_groups.keys()), errors, "Ninefold Confluence must keep narrow army groups for the new scaffold faction fronts")
    required_new_encounters = {
        "encounter_graftroot_wardens",
        "encounter_orevein_exactors",
        "encounter_bellwake_privateers",
    }
    ensure(required_new_encounters.issubset(encounters.keys()), errors, "Ninefold Confluence must keep narrow encounters for the new scaffold faction fronts")

    placed_site_families: set[str] = set()
    placed_dwelling_family_ids: set[str] = set()
    mismatched_dwelling_placements: list[str] = []
    for node in scenario.get("resource_nodes", []):
        if not isinstance(node, dict):
            continue
        site = resource_sites.get(str(node.get("site_id", "")), {})
        if not site:
            continue
        family = str(site.get("family", "one_shot_pickup")) or "one_shot_pickup"
        placed_site_families.add(family)
        if family != "neutral_dwelling":
            continue
        dwelling_id = str(site.get("neutral_dwelling_family_id", ""))
        if dwelling_id:
            placed_dwelling_family_ids.add(dwelling_id)
        x = int(node.get("x", -1))
        y = int(node.get("y", -1))
        terrain_id = ""
        if isinstance(game_map, list) and 0 <= y < len(game_map) and isinstance(game_map[y], list) and 0 <= x < len(game_map[y]):
            terrain_id = str(game_map[y][x])
        biome_id = terrain_to_biome.get(terrain_id, "")
        dwelling = neutral_dwellings.get(dwelling_id, {})
        if dwelling and biome_id not in [str(value) for value in dwelling.get("biome_ids", [])]:
            mismatched_dwelling_placements.append(f"{dwelling_id}@{x},{y}:{biome_id or terrain_id}")

    ensure(
        SIX_FACTION_BIOME_BREADTH_REQUIRED_SITE_FAMILIES.issubset(placed_site_families),
        errors,
        "Ninefold Confluence must place every supported resource-site family including dwellings, mines, scouting, guarded rewards, transit, services, pickups, shrines, and outposts",
    )
    ensure(
        set(neutral_dwellings.keys()).issubset(placed_dwelling_family_ids),
        errors,
        "Ninefold Confluence must place all authored neutral dwelling families",
    )
    ensure(
        not mismatched_dwelling_placements,
        errors,
        "Ninefold Confluence neutral dwelling placements must stay in one of their authored biome families: "
        + ", ".join(mismatched_dwelling_placements[:8]),
    )


def validate_town_frontline_reinforcement_delivery(errors: list[str]) -> None:
    required_paths = (SESSION_STATE_PATH, OVERWORLD_RULES_PATH, TOWN_RULES_PATH, ENEMY_ADVENTURE_RULES_PATH, ENEMY_TURN_RULES_PATH)
    for path in required_paths:
        ensure(path.exists(), errors, f"Missing town-frontline-reinforcement file: {path.relative_to(ROOT)}")
    if not all(path.exists() for path in required_paths):
        return

    session_text = SESSION_STATE_PATH.read_text(encoding="utf-8")
    ensure("const SAVE_VERSION := 9" in session_text, errors, "Town-frontline reinforcement delivery must preserve save version 9")

    overworld_text = OVERWORLD_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        '"delivery_controller_id"',
        '"delivery_origin_town_id"',
        '"delivery_target_kind"',
        '"delivery_target_id"',
        '"delivery_target_label"',
        '"delivery_arrival_day"',
        '"delivery_manifest"',
        "func _player_reserve_delivery_plan",
        "func _advance_player_reserve_deliveries",
        "func _deliver_reinforcements_to_hero",
        "func _deliver_reinforcements_to_town",
        "func _return_reinforcements_to_source",
        "Reserve deliveries",
        "Load %s for %s",
        "Next convoy %s for %s in %d day%s.",
        "convoy reaches %s",
    ):
        ensure(required_token in overworld_text, errors, f"OverworldRules.gd is missing reserve-delivery token: {required_token}")

    town_text = TOWN_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        "func _convoy_watch_summary",
        '"Convoys %s"',
        '"delivery_summary"',
        "_convoy_watch_summary(logistics)",
    ):
        ensure(required_token in town_text, errors, f"TownRules.gd is missing reserve-delivery surfacing token: {required_token}")

    enemy_adventure_text = ENEMY_ADVENTURE_RULES_PATH.read_text(encoding="utf-8")
    for required_token in ('"delivery_manifest"', "The convoy bound for %s is scattered."):
        ensure(required_token in enemy_adventure_text, errors, f"EnemyAdventureRules.gd is missing convoy-disruption token: {required_token}")

    enemy_turn_text = ENEMY_TURN_RULES_PATH.read_text(encoding="utf-8")
    for required_token in ("OverworldRulesScript.town_logistics_state(session, town)", '"delivery_count"'):
        ensure(required_token in enemy_turn_text, errors, f"EnemyTurnRules.gd is missing reinforcement-line AI token: {required_token}")


def validate_convoy_interception_clash_slice(errors: list[str]) -> None:
    required_paths = (SESSION_STATE_PATH, OVERWORLD_RULES_PATH, ENEMY_ADVENTURE_RULES_PATH, BATTLE_RULES_PATH)
    for path in required_paths:
        ensure(path.exists(), errors, f"Missing convoy-interception file: {path.relative_to(ROOT)}")
    if not all(path.exists() for path in required_paths):
        return

    session_text = SESSION_STATE_PATH.read_text(encoding="utf-8")
    ensure("const SAVE_VERSION := 9" in session_text, errors, "Convoy interception clash slice must preserve save version 9")

    overworld_text = OVERWORLD_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        "func _resource_site_delivery_interception",
        "func delivery_interception_context_for_encounter",
        "func apply_delivery_interception_outcome",
        '"blocks_delivery"',
        '"holding under interception"',
        "route holds. %s keeps marching toward %s.",
        "convoy turns back to %s after the lane stalls",
        "is intercepted before it reaches",
    ):
        ensure(required_token in overworld_text, errors, f"OverworldRules.gd is missing convoy-interception token: {required_token}")

    enemy_adventure_text = ENEMY_ADVENTURE_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        "func _append_delivery_interception_candidates",
        "func _delivery_town_candidate",
        "func _delivery_hero_candidate",
        '"delivery_intercept_node_placement_id"',
        '"delivery_intercept_target_kind"',
        "OverworldRulesScript.delivery_interception_context_for_encounter",
    ):
        ensure(required_token in enemy_adventure_text, errors, f"EnemyAdventureRules.gd is missing convoy-hunt token: {required_token}")

    battle_text = BATTLE_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        "OverworldRulesScript.delivery_interception_context_for_encounter",
        '"delivery_node_placement_id"',
        '"delivery_route_label"',
        '"delivery_pressure_label"',
        "func _has_delivery_context",
        "func _apply_delivery_route_aftermath",
        "OverworldRulesScript.apply_delivery_interception_outcome",
        '"Relief defense at %s"',
        '"Convoy clash near %s"',
    ):
        ensure(required_token in battle_text, errors, f"BattleRules.gd is missing convoy-clash routing token: {required_token}")


def validate_hostile_empire_personality(errors: list[str]) -> None:
    required_paths = (ENEMY_TURN_RULES_PATH, ENEMY_ADVENTURE_RULES_PATH, CONTENT_DIR / "factions.json", CONTENT_DIR / "scenarios.json", CONTENT_DIR / "resource_sites.json")
    for path in required_paths:
        ensure(path.exists(), errors, f"Missing hostile-empire personality file: {path.relative_to(ROOT)}")
    if not all(path.exists() for path in required_paths):
        return

    enemy_turn_text = ENEMY_TURN_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        "EnemyAdventureRulesScript.enemy_strategy",
        "EnemyAdventureRulesScript.public_strategy_summary",
        "func _raid_threshold_for_strategy",
        "func _max_active_raids_for_strategy",
        "func _recruit_priority",
        "Charter columns are pushing measured raids down the lanes",
        "Warbands are spilling forward in staggered packs",
        "Compact sorties are testing the frontier behind relay screens",
    ):
        ensure(required_token in enemy_turn_text, errors, f"EnemyTurnRules.gd is missing hostile-personality token: {required_token}")

    enemy_adventure_text = ENEMY_ADVENTURE_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        "func enemy_strategy",
        "func strategy_target_weight",
        "func priority_target_bonus",
        "func public_strategy_summary",
        "func target_site_family",
        "func target_is_objective_anchor",
        "func _weighted_priority",
        '"priority_target_placement_ids"',
        '"strategy_overrides"',
    ):
        ensure(required_token in enemy_adventure_text, errors, f"EnemyAdventureRules.gd is missing hostile-personality token: {required_token}")

    factions = items_index(load_json(CONTENT_DIR / "factions.json"))
    scenarios = items_index(load_json(CONTENT_DIR / "scenarios.json"))
    resource_sites = items_index(load_json(CONTENT_DIR / "resource_sites.json"))
    hostile_priority_counts = {faction_id: 0 for faction_id in RELEASE_PLAYER_FACTIONS}
    hostile_logistics_focus: set[str] = set()
    authored_priority_fronts = 0

    for scenario in scenarios.values():
        resource_family_by_placement = {}
        for placement in scenario.get("resource_nodes", []):
            if not isinstance(placement, dict):
                continue
            placement_id = str(placement.get("placement_id", ""))
            site = resource_sites.get(str(placement.get("site_id", "")), {})
            resource_family_by_placement[placement_id] = str(site.get("family", ""))
        for enemy_faction in scenario.get("enemy_factions", []):
            if not isinstance(enemy_faction, dict):
                continue
            faction_id = str(enemy_faction.get("faction_id", ""))
            if faction_id not in RELEASE_PLAYER_FACTIONS:
                continue
            if enemy_faction.get("priority_target_placement_ids", []) or enemy_faction.get("strategy_overrides", {}):
                hostile_priority_counts[faction_id] += 1
                authored_priority_fronts += 1
            for placement_id in enemy_faction.get("priority_target_placement_ids", []):
                if resource_family_by_placement.get(str(placement_id), "") in LOGISTICS_SITE_FAMILIES:
                    hostile_logistics_focus.add(faction_id)

    ensure(authored_priority_fronts >= 8, errors, "Release hostile empire personality must keep at least eight authored fronts with explicit priority targets or strategy overrides")
    for faction_id in RELEASE_PLAYER_FACTIONS:
        ensure(hostile_priority_counts[faction_id] >= 1, errors, f"Hostile faction {faction_id} must keep at least one authored priority front")
        ensure(faction_id in hostile_logistics_focus, errors, f"Hostile faction {faction_id} must keep at least one priority front aimed at a logistics-site family")
        strategy = factions.get(faction_id, {}).get("enemy_strategy", {})
        ensure(isinstance(strategy, dict) and bool(strategy), errors, f"Faction {faction_id} must keep enemy_strategy authored")

    glassfen = scenarios.get("glassfen-breakers", {})
    glassfen_site_ids = {
        str(placement.get("site_id", ""))
        for placement in glassfen.get("resource_nodes", [])
        if isinstance(placement, dict)
    }
    ensure("site_prism_watch_relay" in glassfen_site_ids, errors, "Glassfen Breakers must keep a Sunvault relay outpost authored")
    ensure("site_starlens_sanctum" in glassfen_site_ids, errors, "Glassfen Breakers must keep a Sunvault sanctum authored")


def validate_late_game_capital_escalation(errors: list[str]) -> None:
    required_paths = (
        SESSION_STATE_PATH,
        OVERWORLD_RULES_PATH,
        TOWN_RULES_PATH,
        ENEMY_TURN_RULES_PATH,
        ENEMY_ADVENTURE_RULES_PATH,
        CONTENT_DIR / "towns.json",
        CONTENT_DIR / "buildings.json",
        CONTENT_DIR / "scenarios.json",
    )
    for path in required_paths:
        ensure(path.exists(), errors, f"Missing late-game capital escalation file: {path.relative_to(ROOT)}")
    if not all(path.exists() for path in required_paths):
        return

    session_text = SESSION_STATE_PATH.read_text(encoding="utf-8")
    ensure("const SAVE_VERSION := 9" in session_text, errors, "Late-game capital escalation must preserve save version 9")

    overworld_text = OVERWORLD_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        "func town_strategic_role",
        "func town_strategic_summary",
        "func town_capital_project_state",
        "func _town_capital_project_state",
        "func _town_capital_project_ids",
        '"Capital Anchor"',
        '"Project online"',
    ):
        ensure(required_token in overworld_text, errors, f"OverworldRules.gd is missing late-game capital token: {required_token}")

    town_rules_text = TOWN_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        "OverworldRulesScript.town_strategic_summary",
        "OverworldRulesScript.town_capital_project_state",
        "Capital project online",
        "Capital watch:",
        "Capital Anchor",
    ):
        ensure(required_token in town_rules_text, errors, f"TownRules.gd is missing late-game capital surfacing token: {required_token}")

    enemy_turn_text = ENEMY_TURN_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        "func _faction_capital_state",
        "func _faction_capital_state_from_towns",
        "func _capital_watch_summary",
        "func _empire_capital_pressure_bonus",
        "OverworldRulesScript.town_capital_project_state",
        "OverworldRulesScript.town_strategic_role",
        "raid_threshold_reduction",
        "max_active_raids_bonus",
        "Capital watch:",
        "Anchor watch:",
    ):
        ensure(required_token in enemy_turn_text, errors, f"EnemyTurnRules.gd is missing late-game capital-pressure token: {required_token}")

    enemy_adventure_text = ENEMY_ADVENTURE_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        "func _town_strategic_priority_bonus",
        "OverworldRulesScript.town_strategic_role",
        "OverworldRulesScript.town_capital_project_state",
    ):
        ensure(required_token in enemy_adventure_text, errors, f"EnemyAdventureRules.gd is missing capital-targeting token: {required_token}")

    towns = items_index(load_json(CONTENT_DIR / "towns.json"))
    buildings = items_index(load_json(CONTENT_DIR / "buildings.json"))
    scenarios = items_index(load_json(CONTENT_DIR / "scenarios.json"))

    ensure(CAPITAL_PROJECT_BUILDING_IDS.issubset(buildings.keys()), errors, "Late-game capital escalation must keep all authored capital-project buildings present")
    for building_id in CAPITAL_PROJECT_BUILDING_IDS:
        project = buildings.get(building_id, {}).get("capital_project", {})
        ensure(isinstance(project, dict) and bool(project), errors, f"Capital-project building {building_id} must define capital_project")
        if isinstance(project, dict):
            ensure(int(project.get("pressure_bonus", 0)) > 0, errors, f"Capital-project building {building_id} must define pressure_bonus > 0")
            ensure(int(project.get("raid_threshold_reduction", 0)) > 0, errors, f"Capital-project building {building_id} must define raid_threshold_reduction > 0")
            ensure(int(project.get("max_active_raids_bonus", 0)) > 0, errors, f"Capital-project building {building_id} must define max_active_raids_bonus > 0")
            ensure(int(project.get("defense_bonus", 0)) > 0, errors, f"Capital-project building {building_id} must define defense_bonus > 0")
            ensure(int(project.get("recovery_guard", 0)) > 0, errors, f"Capital-project building {building_id} must define recovery_guard > 0")
            ensure(bool(str(project.get("summary", ""))), errors, f"Capital-project building {building_id} must define summary")
            support_requirements = project.get("support_requirements", {})
            ensure(isinstance(support_requirements, dict) and bool(support_requirements), errors, f"Capital-project building {building_id} must define support_requirements")
            if isinstance(support_requirements, dict):
                for family_id in LOGISTICS_SITE_FAMILIES:
                    ensure(int(support_requirements.get(family_id, 0)) > 0, errors, f"Capital-project building {building_id} must require logistics family {family_id}")
            vulnerability_penalties = project.get("vulnerability_penalties", {})
            ensure(isinstance(vulnerability_penalties, dict) and bool(vulnerability_penalties), errors, f"Capital-project building {building_id} must define vulnerability_penalties")
            if isinstance(vulnerability_penalties, dict):
                ensure(int(vulnerability_penalties.get("quality_penalty", 0)) > 0, errors, f"Capital-project building {building_id} must define vulnerability quality_penalty > 0")
                ensure(int(vulnerability_penalties.get("readiness_penalty", 0)) > 0, errors, f"Capital-project building {building_id} must define vulnerability readiness_penalty > 0")
                ensure(int(vulnerability_penalties.get("pressure_penalty", 0)) > 0, errors, f"Capital-project building {building_id} must define vulnerability pressure_penalty > 0")
                ensure(int(vulnerability_penalties.get("growth_penalty_percent", 0)) > 0, errors, f"Capital-project building {building_id} must define vulnerability growth_penalty_percent > 0")

    for town_id in STRATEGIC_LOGISTICS_TOWN_IDS:
        logistics_plan = towns.get(town_id, {}).get("logistics_plan", {})
        ensure(isinstance(logistics_plan, dict) and bool(logistics_plan), errors, f"Strategic town {town_id} must define logistics_plan")
        if isinstance(logistics_plan, dict):
            ensure(int(logistics_plan.get("support_radius", 0)) >= 6, errors, f"Strategic town {town_id} must define logistics support_radius >= 6")
            ensure(int(logistics_plan.get("recovery_relief", 0)) > 0, errors, f"Strategic town {town_id} must define logistics recovery_relief > 0")
            ensure(bool(str(logistics_plan.get("vulnerability_summary", ""))), errors, f"Strategic town {town_id} must define logistics vulnerability_summary")
            support_requirements = logistics_plan.get("support_requirements", {})
            ensure(isinstance(support_requirements, dict) and bool(support_requirements), errors, f"Strategic town {town_id} must define logistics support_requirements")
            if isinstance(support_requirements, dict):
                for family_id in LOGISTICS_SITE_FAMILIES:
                    ensure(int(support_requirements.get(family_id, 0)) > 0, errors, f"Strategic town {town_id} must require logistics family {family_id}")

    for town_id, building_id in CAPITAL_PROJECT_TOWN_BUILDINGS.items():
        town = towns.get(town_id, {})
        ensure(bool(town), errors, f"Late-game capital escalation must keep town {town_id} authored")
        ensure(str(town.get("strategic_role", "")) == "capital", errors, f"Town {town_id} must keep strategic_role capital")
        ensure(bool(str(town.get("strategic_summary", ""))), errors, f"Town {town_id} must define strategic_summary")
        ensure(building_id in [str(value) for value in town.get("buildable_building_ids", [])], errors, f"Town {town_id} must keep capital-project building {building_id} in its build tree")

    for town_id in STRATEGIC_STRONGHOLD_IDS:
        town = towns.get(town_id, {})
        ensure(bool(town), errors, f"Late-game capital escalation must keep stronghold town {town_id} authored")
        ensure(str(town.get("strategic_role", "")) == "stronghold", errors, f"Town {town_id} must keep strategic_role stronghold")
        ensure(bool(str(town.get("strategic_summary", ""))), errors, f"Stronghold town {town_id} must define strategic_summary")

    for scenario_id, expectation in LATE_GAME_CAPITAL_SCENARIO_EXPECTATIONS.items():
        scenario = scenarios.get(scenario_id, {})
        ensure(bool(scenario), errors, f"Late-game capital escalation must keep scenario {scenario_id} authored")
        if not scenario:
            continue
        found_capital_hook = False
        for hook in scenario.get("script_hooks", []):
            if not isinstance(hook, dict):
                continue
            objective_not_met = any(
                isinstance(condition, dict)
                and str(condition.get("type", "")) == "objective_not_met"
                and str(condition.get("objective_id", "")) == str(expectation["objective_id"])
                for condition in hook.get("conditions", [])
            )
            if not objective_not_met:
                continue
            effect_types = {str(effect.get("type", "")) for effect in hook.get("effects", []) if isinstance(effect, dict)}
            building_match = any(
                isinstance(effect, dict)
                and str(effect.get("type", "")) == "town_add_building"
                and str(effect.get("placement_id", "")) == str(expectation["placement_id"])
                and str(effect.get("building_id", "")) == str(expectation["building_id"])
                for effect in hook.get("effects", [])
            )
            if building_match:
                found_capital_hook = True
                ensure("add_enemy_pressure" in effect_types, errors, f"Scenario {scenario_id} capital escalation hook must add enemy pressure")
                ensure("spawn_encounter" in effect_types, errors, f"Scenario {scenario_id} capital escalation hook must spawn a fresh encounter")
                break
        ensure(found_capital_hook, errors, f"Scenario {scenario_id} must keep a late-game capital escalation hook for {expectation['building_id']}")


def validate_capital_front_battle_identity(errors: list[str]) -> None:
    required_paths = (
        SESSION_STATE_PATH,
        BATTLE_RULES_PATH,
        BATTLE_AI_RULES_PATH,
        OVERWORLD_RULES_PATH,
        TOWN_RULES_PATH,
        CONTENT_DIR / "army_groups.json",
        CONTENT_DIR / "encounters.json",
        CONTENT_DIR / "scenarios.json",
    )
    for path in required_paths:
        ensure(path.exists(), errors, f"Missing capital-front battle-identity file: {path.relative_to(ROOT)}")
    if not all(path.exists() for path in required_paths):
        return

    session_text = SESSION_STATE_PATH.read_text(encoding="utf-8")
    ensure("const SAVE_VERSION := 9" in session_text, errors, "Capital-front battle identity must preserve save version 9")

    battle_text = BATTLE_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        "func _capital_front_anchor_side",
        "func _capital_front_assault_side",
        "func _battlefield_identity_summary",
        "Battlefront:",
        "Capital defense at",
        "Stronghold defense at",
        "fortress_lane",
        "reserve_wave",
        "battery_nest",
        "wall_pressure",
    ):
        ensure(required_token in battle_text, errors, f"BattleRules.gd is missing capital-front battle token: {required_token}")

    battle_ai_text = BATTLE_AI_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        "func _capital_front_anchor_side",
        "func _capital_front_assault_side",
        "fortress_lane",
        "reserve_wave",
        "battery_nest",
        "wall_pressure",
    ):
        ensure(required_token in battle_ai_text, errors, f"BattleAiRules.gd is missing capital-front AI token: {required_token}")

    overworld_text = OVERWORLD_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        "func town_battlefront_profile",
        "func _town_battlefront_profile",
        "Fortress lanes",
        "Wall pressure",
        "Battery nests",
        "reserve_wave",
    ):
        ensure(required_token in overworld_text, errors, f"OverworldRules.gd is missing capital-front summary token: {required_token}")

    town_text = TOWN_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        "OverworldRulesScript.town_battlefront_profile",
        "Battlefront ",
        "Siege profile:",
    ):
        ensure(required_token in town_text, errors, f"TownRules.gd is missing capital-front surfacing token: {required_token}")

    army_groups = items_index(load_json(CONTENT_DIR / "army_groups.json"))
    encounters = items_index(load_json(CONTENT_DIR / "encounters.json"))
    scenarios = items_index(load_json(CONTENT_DIR / "scenarios.json"))

    ensure(CAPITAL_FRONT_SIGNATURE_ARMIES.issubset(army_groups.keys()), errors, "Capital-front battle identity must keep all signature reserve or finale army groups authored")

    signature_tagged_encounters = 0
    for encounter_id, expectation in CAPITAL_FRONT_ENCOUNTER_EXPECTATIONS.items():
        encounter = encounters.get(encounter_id, {})
        ensure(bool(encounter), errors, f"Capital-front battle identity must keep encounter {encounter_id} authored")
        if not encounter:
            continue
        ensure(str(encounter.get("enemy_group_id", "")) == str(expectation["enemy_group_id"]), errors, f"Encounter {encounter_id} must keep enemy_group_id {expectation['enemy_group_id']}")
        battlefield_tags = {str(tag_id) for tag_id in encounter.get("battlefield_tags", [])}
        ensure(set(expectation["required_tags"]).issubset(battlefield_tags), errors, f"Encounter {encounter_id} must keep tags {sorted(expectation['required_tags'])}")
        if battlefield_tags & {"fortress_lane", "reserve_wave", "battery_nest", "wall_pressure"}:
            signature_tagged_encounters += 1

    ensure(signature_tagged_encounters >= 10, errors, "Capital-front battle identity must keep at least ten authored encounters using the new siege-lane or finale-front tags")

    for scenario_id, expectation in CAPITAL_FRONT_SCENARIO_EXPECTATIONS.items():
        scenario = scenarios.get(scenario_id, {})
        ensure(bool(scenario), errors, f"Capital-front battle identity must keep scenario {scenario_id} authored")
        if not scenario:
            continue

        placed_encounter_ids = {
            str(placement.get("encounter_id", ""))
            for placement in scenario.get("encounters", [])
            if isinstance(placement, dict)
        }
        ensure(set(expectation["front_encounter_ids"]).issubset(placed_encounter_ids), errors, f"Scenario {scenario_id} must keep its capital-front encounter identity authored")

        raid_encounter_ids = {
            str(encounter_id)
            for enemy_faction in scenario.get("enemy_factions", [])
            if isinstance(enemy_faction, dict)
            for encounter_id in enemy_faction.get("raid_encounter_ids", [])
        }
        ensure(set(expectation["raid_encounter_ids"]).issubset(raid_encounter_ids), errors, f"Scenario {scenario_id} must keep signature raid encounter ids for its late-front pressure")

        hook = next((candidate for candidate in scenario.get("script_hooks", []) if isinstance(candidate, dict) and str(candidate.get("id", "")) == str(expectation["hook_id"])), None)
        ensure(hook is not None, errors, f"Scenario {scenario_id} must keep script hook {expectation['hook_id']}")
        if not isinstance(hook, dict):
            continue
        spawned_encounter_ids = {
            str(effect.get("placement", {}).get("encounter_id", ""))
            for effect in hook.get("effects", [])
            if isinstance(effect, dict) and str(effect.get("type", "")) == "spawn_encounter" and isinstance(effect.get("placement", {}), dict)
        }
        ensure(str(expectation["spawn_encounter_id"]) in spawned_encounter_ids, errors, f"Scenario {scenario_id} hook {expectation['hook_id']} must spawn {expectation['spawn_encounter_id']}")


def validate_authored_scenario_identity(errors: list[str]) -> None:
    required_paths = (CONTENT_SERVICE_PATH, SCENARIO_SCRIPT_RULES_PATH, SCENARIO_RULES_PATH, OVERWORLD_RULES_PATH)
    for path in required_paths:
        ensure(path.exists(), errors, f"Missing authored-scenario identity file: {path.relative_to(ROOT)}")
    if not all(path.exists() for path in required_paths):
        return

    content_service_text = CONTENT_SERVICE_PATH.read_text(encoding="utf-8")
    for required_token in (
        '"attack_buff"',
        '"encounter_resolved"',
        '"objective_not_met"',
        '"active_raid_count_at_least"',
        '"active_raid_count_at_most"',
        '"add_enemy_pressure"',
        '"hook_fired"',
        '"hook_not_fired"',
    ):
        ensure(required_token in content_service_text, errors, f"ContentService.gd is missing required content-pipeline token: {required_token}")

    scenario_script_text = SCENARIO_SCRIPT_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        '"objective_not_met"',
        '"active_raid_count_at_least"',
        '"active_raid_count_at_most"',
        '"hook_fired"',
        '"hook_not_fired"',
        '"add_enemy_pressure"',
        "func describe_recent_events",
        "func _add_enemy_pressure",
    ):
        ensure(required_token in scenario_script_text, errors, f"ScenarioScriptRules.gd is missing required authored-scenario token: {required_token}")

    scenario_rules_text = SCENARIO_RULES_PATH.read_text(encoding="utf-8")
    for required_token in ('"encounter_resolved"', '"hook_fired"'):
        ensure(required_token in scenario_rules_text, errors, f"ScenarioRules.gd is missing required authored-scenario token: {required_token}")

    overworld_text = OVERWORLD_RULES_PATH.read_text(encoding="utf-8")
    for required_token in ("ScenarioScriptRules.describe_recent_events", "Scenario pulse:"):
        ensure(required_token in overworld_text, errors, f"OverworldRules.gd is missing required authored-scenario surfacing token: {required_token}")


def validate_battle_surrender_pursuit_aftermath(errors: list[str]) -> None:
    required_paths = (
        SESSION_STATE_PATH,
        BATTLE_RULES_PATH,
        BATTLE_SCRIPT_PATH,
        BATTLE_SCENE_PATH,
        SCENARIO_RULES_PATH,
        CAMPAIGN_RULES_PATH,
    )
    for path in required_paths:
        ensure(path.exists(), errors, f"Missing battle surrender or aftermath file: {path.relative_to(ROOT)}")
    if not all(path.exists() for path in required_paths):
        return

    session_text = SESSION_STATE_PATH.read_text(encoding="utf-8")
    ensure("const SAVE_VERSION := 9" in session_text, errors, "Battle surrender and pursuit aftermath must preserve save version 9")

    battle_rules_text = BATTLE_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        'surface["surrender"]',
        '"surrender_allowed"',
        "func _surrender_action_summary",
        "func _build_withdrawal_aftermath_preview",
        "func _apply_victory_front_aftermath",
        "func _apply_withdrawal_aftermath",
        "func _add_enemy_treasury_resources",
        "func _apply_withdrawal_recovery_pressure",
        "func _record_battle_aftermath",
        'session.flags["last_battle_outcome"] = "surrender"',
        '"last_battle_aftermath"',
        "Town defenders cannot surrender the walls mid-assault.",
        "apply_town_recovery_pressure",
    ):
        ensure(required_token in battle_rules_text, errors, f"BattleRules.gd is missing required surrender-aftermath token: {required_token}")

    battle_scene_text = BATTLE_SCENE_PATH.read_text(encoding="utf-8")
    ensure(scene_has_node(battle_scene_text, "Surrender", "Button"), errors, "BattleShell.tscn must define a Surrender button on the battle action surface")

    battle_script_text = BATTLE_SCRIPT_PATH.read_text(encoding="utf-8")
    for required_token in (
        "@onready var _surrender_button: Button",
        "func _on_surrender_pressed",
        '_perform_action("surrender")',
        "_apply_action_surface(_surrender_button",
        '"surrender"',
    ):
        ensure(required_token in battle_script_text, errors, f"BattleShell.gd is missing required surrender UI token: {required_token}")

    scenario_rules_text = SCENARIO_RULES_PATH.read_text(encoding="utf-8")
    for required_token in ("func _last_battle_aftermath_text", '"last_battle_aftermath"'):
        ensure(required_token in scenario_rules_text, errors, f"ScenarioRules.gd is missing required surrender-aftermath recap token: {required_token}")

    campaign_rules_text = CAMPAIGN_RULES_PATH.read_text(encoding="utf-8")
    for required_token in ("func _last_battle_aftermath_text", '"last_battle_aftermath"'):
        ensure(required_token in campaign_rules_text, errors, f"CampaignRules.gd is missing required surrender-aftermath recap token: {required_token}")


def validate_town_defense_battle_flow(errors: list[str]) -> None:
    required_paths = (
        SESSION_STATE_PATH,
        ENEMY_TURN_RULES_PATH,
        BATTLE_RULES_PATH,
        OVERWORLD_SCRIPT_PATH,
        BATTLE_SCRIPT_PATH,
    )
    for path in required_paths:
        ensure(path.exists(), errors, f"Missing town-defense battle file: {path.relative_to(ROOT)}")
    if not all(path.exists() for path in required_paths):
        return

    session_text = SESSION_STATE_PATH.read_text(encoding="utf-8")
    ensure("const SAVE_VERSION := 9" in session_text, errors, "Town-defense battle flow must preserve save version 9")

    enemy_turn_text = ENEMY_TURN_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        "func _queue_town_defense_battle",
        '"type": "town_defense"',
        "BattleRulesScript.create_battle_payload",
        "session.game_state = \"battle\"",
        "func _town_defense_candidate",
    ):
        ensure(required_token in enemy_turn_text, errors, f"EnemyTurnRules.gd is missing required town-defense token: {required_token}")

    battle_text = BATTLE_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        '"player_commander_state"',
        '"player_commander_source"',
        '"retreat_allowed"',
        "func _player_setup_for_battle",
        "func _finalize_town_defense_loss",
        "func _sync_player_force_from_battle",
        "func _sync_enemy_force_from_battle",
        "func _capture_town_after_assault",
        "func _apply_battle_context_victory",
        "func _apply_battle_context_stalemate",
        '"state": "defeat" if session.scenario_status != "in_progress" else "town_lost"',
    ):
        ensure(required_token in battle_text, errors, f"BattleRules.gd is missing required town-defense token: {required_token}")

    overworld_script_text = OVERWORLD_SCRIPT_PATH.read_text(encoding="utf-8")
    ensure("AppRouter.go_to_battle()" in overworld_script_text, errors, "OverworldShell.gd must route queued town-defense battles into the battle scene")

    battle_script_text = BATTLE_SCRIPT_PATH.read_text(encoding="utf-8")
    for required_token in ("BattleRules.resolve_if_battle_ready", '"town_lost"', "AppRouter.go_to_overworld()"):
        ensure(required_token in battle_script_text, errors, f"BattleShell.gd is missing required town-defense routing token: {required_token}")


def validate_live_client_harness(errors: list[str]) -> None:
    required_paths = (
        LIVE_VALIDATION_HARNESS_PATH,
        RUN_LIVE_FLOW_HARNESS_PATH,
        MAIN_MENU_SCRIPT_PATH,
        OVERWORLD_SCRIPT_PATH,
        TOWN_SCRIPT_PATH,
        BATTLE_SCRIPT_PATH,
    )
    for path in required_paths:
        ensure(path.exists(), errors, f"Missing live-validation harness file: {path.relative_to(ROOT)}")
    if not all(path.exists() for path in required_paths):
        return

    harness_text = LIVE_VALIDATION_HARNESS_PATH.read_text(encoding="utf-8")
    for required_token in (
        'const FLOW_BOOT_TO_SKIRMISH_OVERWORLD := "boot_to_skirmish_overworld"',
        'const FLOW_BOOT_TO_SKIRMISH_TOWN_BATTLE := "boot_to_skirmish_town_battle"',
        'const FLOW_BOOT_TO_SKIRMISH_DEFEAT_OUTCOME := "boot_to_skirmish_defeat_outcome"',
        'const FLOW_BOOT_TO_CAMPAIGN_RESOLVED_OUTCOME := "boot_to_campaign_resolved_outcome"',
        'const FLOW_BOOT_TO_CAMPAIGN_DEFEAT_OUTCOME := "boot_to_campaign_defeat_outcome"',
        'const FLOW_BOOT_TO_CAMPAIGN_FULL_ARC := "boot_to_campaign_full_arc"',
        "const TOWN_SCENE :=",
        "const BATTLE_SCENE :=",
        "const SCENARIO_OUTCOME_SCENE :=",
        "FLOW_BOOT_TO_SKIRMISH_RESOLVED_OUTCOME",
        "func _execute_boot_to_skirmish_defeat_outcome_flow",
        "func _execute_boot_to_campaign_resolved_outcome_flow",
        "func _execute_boot_to_campaign_defeat_outcome_flow",
        "func _execute_boot_to_campaign_full_arc_flow",
        "func _enter_live_skirmish_overworld",
        "func _enter_live_campaign_overworld",
        "func _drive_campaign_chapter_to_victory_outcome",
        "func _verify_campaign_outcome_route_and_followups",
        "func _verify_campaign_defeat_outcome_route_and_followups",
        "func _save_and_resume_campaign_overworld_from_main_menu",
        "func _launch_skirmish_baseline_from_campaign_overworld",
        "func _assert_campaign_downstream_overworld_snapshot",
        "func _assert_downstream_carryover_differs_from_skirmish",
        "func _assert_campaign_outcome_snapshot",
        "func _assert_campaign_finale_outcome_snapshot",
        "func _assert_campaign_completed_browser_snapshot",
        "func _assert_campaign_save_summary",
        "func _drive_overworld_to_defeat_outcome",
        "func _defeat_pressure_step_id",
        "func _campaign_aftermath_text",
        "func _scenario_resolution_text",
        "func _resolve_defeat_pressure_battle_interrupt",
        "func _route_from_overworld_to_scene",
        "func _save_and_resume_battle_from_main_menu",
        "func _save_and_resume_outcome_from_main_menu",
        "func _clear_required_encounters_to_outcome",
        "func _clear_required_encounters_to_overworld",
        "func _required_encounter_placements_for_resolution",
        "func _direct_required_encounter_placements_for_resolution",
        "func _prepare_required_encounter_battle_validation",
        "func _play_battle_to_scene",
        'town_entered',
        'town_progressed',
        'town_saved',
        'main_menu_after_town_return',
        'town_resumed',
        'battle_entered',
        'battle_saved',
        'main_menu_after_battle_return',
        'battle_resumed',
        'overworld_after_battle',
        'captured_town_entered',
        'support_site_claimed_river_free_company',
        'support_artifact_claimed_bastion_vault',
        'pre_outcome_objective_battle_entered_',
        'overworld_after_pre_outcome_objective_',
        'outcome_entered',
        'outcome_saved',
        'main_menu_after_outcome_return',
        'outcome_resumed',
        'main_menu_after_outcome_action',
        'defeat_pressure_watch_started',
        'defeat_pressure_day_',
        'defeat_outcome_entered',
        'defeat_outcome_saved',
        'main_menu_after_defeat_outcome_return',
        'defeat_outcome_resumed',
        'main_menu_after_defeat_outcome_action',
        'main_menu_campaign',
        'campaign_overworld_entered',
        'campaign_support_site_claimed_river_free_company',
        'campaign_support_artifact_claimed_bastion_vault',
        'campaign_battle_entered',
        'campaign_outcome_entered',
        'campaign_outcome_saved',
        'campaign_outcome_resumed',
        'campaign_next_chapter_overworld_entered',
        'campaign_next_chapter_saved',
        'main_menu_after_campaign_next_chapter_return',
        'campaign_next_chapter_resumed',
        'main_menu_after_campaign_next_chapter_resume_return',
        'main_menu_downstream_skirmish_selected',
        'campaign_next_chapter_skirmish_baseline',
        'campaign_defeat_pressure_watch_started',
        'campaign_defeat_pressure_day_',
        'campaign_defeat_outcome_entered',
        'campaign_defeat_outcome_saved',
        'main_menu_after_campaign_defeat_outcome_return',
        'campaign_defeat_outcome_resumed',
        'main_menu_after_campaign_defeat_outcome_action',
        'Next chapter unlocked',
        'This victory exports',
        'Next chapter import ready',
        'Downstream chapter remains blocked',
        'Carryover export is only banked on victory',
        'Setback',
        'saved_from_launch_mode',
        'validation_end_turn',
        'validation_perform_action',
        'expected_status',
        'pre_action_town_owner',
        'battle_context_town_placement_id',
        'Occupation watch:',
        'Review Outcome',
        'func _town_resume_signature',
        'func _battle_resume_signature',
        'func _outcome_resume_signature',
        'func _campaign_carryover_signature',
        'func _campaign_next_scenario_id',
        'func _campaign_scenario_ids',
        'func _set_current_validation_scenario',
        'validation_route_step_to_nearest_target',
        'validation_route_step_to_target_placement',
        'validation_try_progress_action',
        'campaign_arc_completed_browser',
    ):
        ensure(required_token in harness_text, errors, f"LiveValidationHarness.gd is missing required routed-harness token: {required_token}")

    runner_text = RUN_LIVE_FLOW_HARNESS_PATH.read_text(encoding="utf-8")
    ensure(
        'DEFAULT_FLOW = "boot_to_skirmish_resolved_outcome"' in runner_text,
        errors,
        "run_live_flow_harness.py must default to the resolved-outcome live flow",
    )
    ensure(
        'DEFEAT_OUTCOME_FLOW = "boot_to_skirmish_defeat_outcome"' in runner_text,
        errors,
        "run_live_flow_harness.py must expose the routed defeat outcome flow id",
    )
    ensure(
        'CAMPAIGN_OUTCOME_FLOW = "boot_to_campaign_resolved_outcome"' in runner_text,
        errors,
        "run_live_flow_harness.py must expose the routed campaign outcome flow id",
    )
    ensure(
        'CAMPAIGN_DEFEAT_OUTCOME_FLOW = "boot_to_campaign_defeat_outcome"' in runner_text,
        errors,
        "run_live_flow_harness.py must expose the routed campaign defeat outcome flow id",
    )
    ensure(
        'CAMPAIGN_FULL_ARC_FLOW = "boot_to_campaign_full_arc"' in runner_text,
        errors,
        "run_live_flow_harness.py must expose the routed full campaign arc flow id",
    )
    ensure(
        'parser.add_argument("--campaign"' in runner_text and "--live-validation-campaign=" in runner_text,
        errors,
        "run_live_flow_harness.py must pass the selected campaign id into the live validation harness",
    )

    main_menu_script_text = MAIN_MENU_SCRIPT_PATH.read_text(encoding="utf-8")
    for required_token in (
        "func validation_snapshot",
        "func validation_open_campaign_stage",
        "func validation_open_skirmish_stage",
        "func validation_open_saves_stage",
        "func validation_select_campaign",
        "func validation_select_campaign_chapter",
        "func validation_select_save_summary",
        "func validation_resume_selected_save",
        "func validation_start_selected_campaign_chapter",
        "func validation_start_selected_skirmish",
        '"chapter_details_full"',
        '"campaign_details_full"',
        '"campaign_arc_status_full"',
        '"primary_campaign_action"',
        '"selected_chapter_action"',
    ):
        ensure(required_token in main_menu_script_text, errors, f"MainMenu.gd is missing required live-harness token: {required_token}")

    overworld_script_text = OVERWORLD_SCRIPT_PATH.read_text(encoding="utf-8")
    for required_token in (
        "func validation_snapshot",
        "func validation_end_turn",
        "func validation_try_progress_action",
        "func validation_select_save_slot",
        "func validation_save_to_selected_slot",
        "func validation_return_to_menu",
        "func validation_cast_overworld_spell",
        "func validation_route_step_to_nearest_target",
        "func validation_route_step_to_target_placement",
        '"context_action_ids"',
        '"active_town"',
        '"campaign_id"',
        '"campaign_previous_scenario_id"',
        '"resources"',
        '"commander_state"',
        '"carryover_flags"',
        '"enemy_pressure_states"',
        '"capture_town"',
        '"resource"',
        '"artifact"',
    ):
        ensure(required_token in overworld_script_text, errors, f"OverworldShell.gd is missing required live-harness token: {required_token}")

    town_script_text = TOWN_SCRIPT_PATH.read_text(encoding="utf-8")
    for required_token in (
        "func validation_snapshot",
        "func validation_try_progress_action",
        "func validation_select_save_slot",
        "func validation_save_to_selected_slot",
        "func validation_return_to_menu",
        "func validation_leave_town",
        '"summary"',
        '"front"',
        '"occupation"',
    ):
        ensure(required_token in town_script_text, errors, f"TownShell.gd is missing required live-harness token: {required_token}")

    battle_script_text = BATTLE_SCRIPT_PATH.read_text(encoding="utf-8")
    for required_token in (
        "func validation_snapshot",
        "func validation_try_progress_action",
        "func validation_select_save_slot",
        "func validation_save_to_selected_slot",
        "func validation_return_to_menu",
        "func validation_perform_action",
        "func validation_set_support_spell_priority",
        "func validation_set_spell_casting_enabled",
        "func validation_set_max_spell_casts",
        "func _preferred_validation_action_id",
        '"battle_context_town_placement_id"',
        "func _align_validation_target",
        "func _preferred_validation_target_id",
    ):
        ensure(required_token in battle_script_text, errors, f"BattleShell.gd is missing required live-harness token: {required_token}")

    outcome_script_text = OUTCOME_SCRIPT_PATH.read_text(encoding="utf-8")
    for required_token in (
        "func validation_snapshot",
        "func validation_select_save_slot",
        "func validation_save_to_selected_slot",
        "func validation_perform_action",
        "func validation_return_to_menu",
        '"resume_target"',
        '"action_ids"',
        '"actions"',
    ):
        ensure(required_token in outcome_script_text, errors, f"ScenarioOutcomeShell.gd is missing required live-harness token: {required_token}")


def main() -> int:
    errors: list[str] = []
    validate_content(errors)
    validate_project_and_scenes(errors)
    validate_save_management(errors)
    validate_skirmish_setup(errors)
    validate_campaign_browser(errors)
    validate_settings_and_onboarding(errors)
    validate_main_menu_first_view(errors)
    validate_scenario_outcome_shell(errors)
    validate_difficulty_integration(errors)
    validate_hero_progression(errors)
    validate_hero_command(errors)
    validate_overworld_fog(errors)
    validate_battle_ability_layer(errors)
    validate_battle_shell_release_polish(errors)
    validate_battle_objective_pressure_slice(errors)
    validate_battle_order_consequence_board(errors)
    validate_battle_spell_timing_board(errors)
    validate_battle_faction_identity(errors)
    validate_town_faction_progression(errors)
    validate_town_shell_release_polish(errors)
    validate_town_defense_outlook_board(errors)
    validate_town_order_readiness_ledger(errors)
    validate_overworld_shell_release_polish(errors)
    validate_overworld_command_commitment_board(errors)
    validate_enemy_empire_management(errors)
    validate_enemy_strategic_contestation(errors)
    validate_overworld_logistics_sites(errors)
    validate_overworld_route_security_escort(errors)
    validate_overworld_content_foundation(errors)
    validate_overworld_art_asset_slice(errors)
    validate_neutral_dwelling_unit_slice(errors)
    validate_six_faction_biome_scenario_breadth(errors)
    validate_town_frontline_reinforcement_delivery(errors)
    validate_convoy_interception_clash_slice(errors)
    validate_hostile_empire_personality(errors)
    validate_late_game_capital_escalation(errors)
    validate_capital_front_battle_identity(errors)
    validate_authored_scenario_identity(errors)
    validate_battle_surrender_pursuit_aftermath(errors)
    validate_town_defense_battle_flow(errors)
    validate_live_client_harness(errors)
    validate_in_session_save_controls(errors)
    validate_six_faction_content_scaffold(errors)

    if errors:
        print("VALIDATION FAILED")
        for error in errors:
            print(f"- {error}")
        return 1

    print("VALIDATION PASSED")
    print("- content graph is internally consistent")
    print("- campaign content files, chapter wiring, and multi-arc breadth are present")
    print("- project and scene resource paths exist")
    print("- connected scene methods exist on their scripts")
    print("- save-service APIs and save-browser scene wiring are present")
    print("- save summaries now expose integrity/load-state guardrails, and restore flow re-reads live slot state before loading")
    print("- campaign chapter wiring, browser/detail APIs, and menu browser hooks are present")
    print("- campaign chapters now require authored briefing, aftermath, and chronicle text surfaced through the menu browser and outcome shell")
    print("- campaign and skirmish selection now surface commander, spellbook, artifact, army, and front-posture previews from core rules")
    print("- overworld logistics orders now bind hero-led escort state, route pressure guard, and hostile route-break contestation on shared core boundaries")
    print("- campaign and skirmish launch flow now surfaces terrain, enemy posture, first-contact, objective, and reinforcement intel through a shared operational board")
    print("- settings persistence, 16:9 runtime resolution guardrails, onboarding topics, and main-menu settings/help hooks are present")
    print("- main-menu first-view commands are mapped onto painted backdrop hotspots without the generated command spine")
    print("- authored scenarios now require reactive hooks, encounter-clearing side objectives, pressure spikes, and dispatch-visible event identity")
    print("- post-scenario outcome routing, recap builders, and dedicated outcome-shell hooks are present")
    print("- fog-of-war, scouting, legacy-save normalization, and overworld UI wiring are present")
    print("- skirmish metadata, launch-mode session wiring, and setup UI hooks are present")
    print("- difficulty profiles are wired through core overworld and battle rules without a save-version bump")
    print("- hero specialties are normalized, surfaced, and carried through overworld/town/runtime progression")
    print("- hero-command roster, tavern recruitment, transfer flow, and thin UI wiring are present")
    print("- authored hero metadata, multi-faction campaign starts, skirmish-only fronts, and lead-hero variety are present")
    print("- authored unit abilities, battle statuses, ability-aware tactical AI, and thin battle UI wiring are present")
    print("- the battle shell now surfaces commanders, initiative, active context, effect pressure, action guidance, and dispatch feed from core rules")
    print("- fresh battle entry now surfaces a one-shot tactical briefing in the battle shell using runtime encounter, doctrine, terrain-tag, target, and objective context")
    print("- the battle shell now also surfaces a live tactical risk and readiness board using current initiative, commander cover, cohesion, ranged pressure, decisive targets, objective urgency, and dispatch state")
    print("- battle encounters now also author cover lines, obstruction lines, and firing-lane control points that drive movement pressure, ranged threat, commander safety, AI scoring, and shell summaries")
    print("- battle withdrawal now exposes a real surrender action, distinct retreat versus surrender consequences, and persisted aftermath recap across battle, outcome, and campaign flow")
    print("- battle content now keeps distinct battlefield tags, commander traits, specialized army groups, terrain-payoff rules, and doctrine-aware AI scoring")
    print("- faction identity, town build trees, weekly musters, and thin town-shell progression wiring are present")
    print("- advanced town works now drive asymmetric pressure, reinforcement quality, and battle-readiness payoffs across Embercourt and Mireclaw")
    print("- the town shell now surfaces a release-facing overview, exchange hall, defense watch, frontier watch, and dispatch flow from core rules")
    print("- the town shell now also surfaces a defense outlook and dispatch-readiness board using live wall strength, public raid pressure, logistics, recovery, and hero-coverage data")
    print("- the town shell now also surfaces an order-readiness ledger using live costs, market coverage, levy bottlenecks, response strain, and wall-coverage consequences")
    print("- the overworld shell now surfaces objective boards, scouting coverage, frontier watch, dispatch context, and command actions from core rules")
    print("- fresh scenario launches now surface a one-shot first-turn command briefing in the overworld shell using runtime objective, logistics, scouting, and threat data")
    print("- the overworld shell now surfaces a live next-day command-risk forecast and a one-shot end-turn warning using runtime pressure, logistics, scouting, town-readiness, objective, and frontier-watch data")
    print("- towns now project reserve production toward pressured towns and field heroes through existing logistics-site convoy state, while hostile raids can scatter those deliveries and current town or overworld summaries expose the live line status")
    print("- live convoy routes now also attract real raid-hunt pressure and route-block battles, with existing battle routing deciding whether reinforcements arrive, turn back, or are intercepted")
    print("- enemy towns now build, recruit, reinforce raid armies, and surface public threat posture without a save-version bump")
    print("- enemy raids now contest sites, relics, neutral fronts, retake priorities, and objective anchors through save-backed core rules")
    print("- neutral dwellings, faction outposts, and frontier shrines now drive recurring logistics, scouting, spell access, and raid-value contestation across authored scenarios")
    print("- overworld biomes and map-object families now have authored content domains, validation, and runtime family hooks")
    print("- overworld terrain now uses authored autotile-ready grammar, structural road layers, renderer hooks, selected object assets, and procedural object fallbacks")
    print("- Ninefold Confluence keeps a 64x64 six-faction, nine-biome, all-neutral-dwelling breadth scenario under validation")
    print("- hostile empires now keep faction-specific build, raid, reinforcement, and priority-front personalities across authored scenarios")
    print("- capitals and strongholds now surface strategic summaries, power late-game project escalation, and drive hostile pressure/targeting on finale fronts")
    print("- capital and stronghold fronts now drive fortress-lane, reserve-wave, battery-nest, and wall-pressure battles across finale encounters")
    print("- town assaults now route into real defense battles with garrison sync, raid-survivor sync, and town-loss consequences")
    print("- the live routed-client harness now drives the real menu into overworld, owned-town orders, required encounter objectives, hostile-town assault, resolved outcome routing, outcome save/load review semantics, and post-outcome menu return artifacts")
    print("- active-play shells now use router-driven save controls, latest-save context, and safe return-or-resume flow without a save-version bump")
    print("- six-faction bible content now has real scaffold records, seed towns for new factions, and tavern gating for non-integrated heroes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
