#!/usr/bin/env python3
from __future__ import annotations

import json
import argparse
import re
import struct
import sys
from datetime import datetime, timezone
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
MAP_EDITOR_SCENE_PATH = ROOT / "scenes" / "editor" / "MapEditorShell.tscn"
MAP_EDITOR_SCRIPT_PATH = ROOT / "scenes" / "editor" / "MapEditorShell.gd"
MAP_EDITOR_SMOKE_SCENE_PATH = ROOT / "tests" / "map_editor_smoke.tscn"
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
ECONOMY_RESOURCE_FIXTURE_DIR = ROOT / "tests" / "fixtures" / "economy_resource_schema"
ECONOMY_RESOURCE_REGISTRY_FIXTURE_PATH = ECONOMY_RESOURCE_FIXTURE_DIR / "resource_registry.json"
ECONOMY_RESOURCE_STRICT_CASES_PATH = ECONOMY_RESOURCE_FIXTURE_DIR / "strict_cases.json"
ECONOMY_CAPTURE_INCOME_REPORT_SCRIPT_PATH = ROOT / "tests" / "economy_capture_income_expansion_report.gd"
ECONOMY_CAPTURE_INCOME_REPORT_SCENE_PATH = ROOT / "tests" / "economy_capture_income_expansion_report.tscn"
ECONOMY_CAPTURE_INCOME_REPORT_DOC_PATH = ROOT / "docs" / "economy-capture-income-loop-expansion-report.md"
OVERWORLD_OBJECT_FIXTURE_DIR = ROOT / "tests" / "fixtures" / "overworld_object_schema"
OVERWORLD_OBJECT_STRICT_CASES_PATH = OVERWORLD_OBJECT_FIXTURE_DIR / "strict_cases.json"
NEUTRAL_ENCOUNTER_FIXTURE_DIR = ROOT / "tests" / "fixtures" / "neutral_encounter_schema"
NEUTRAL_ENCOUNTER_STRICT_CASES_PATH = NEUTRAL_ENCOUNTER_FIXTURE_DIR / "strict_cases.json"

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
SUPPORTED_SPELL_SCHOOLS = {"beacon", "mire", "lens", "root", "furnace", "veil", "old_measure"}
REQUIRED_MAJOR_SPELL_SCHOOLS = {"beacon", "mire", "lens", "root", "furnace", "veil"}
SUPPORTED_SPELL_ROLE_CATEGORIES = {"damage", "buff", "debuff", "control", "recovery", "summon_terrain", "economy_map_utility", "countermagic"}
SUPPORTED_SPELL_PRIMARY_ROLES = {
    "movement_support",
    "priority_damage",
    "harry_damage",
    "control_damage",
    "isolation_damage",
    "ally_defense",
    "tempo_buff",
    "assault_buff",
}
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
SUPPORTED_RESOURCE_SITE_FAMILIES = LOGISTICS_SITE_FAMILIES | OVERWORLD_FOUNDATION_SITE_FAMILIES | {
    "one_shot_pickup",
    "staged_resource_front",
    "support_producer",
    "shrine",
    "sign_waypoint",
    "scenario_objective",
}
SUPPORTED_MAP_OBJECT_FAMILIES = {
    "pickup",
    "mine",
    "neutral_dwelling",
    "neutral_encounter",
    "shrine",
    "guarded_reward_site",
    "scouting_structure",
    "transit_object",
    "repeatable_service",
    "blocker",
    "decoration",
    "faction_landmark",
    "staged_resource_front",
    "support_producer",
    "sign_waypoint",
    "scenario_objective",
}
SIX_FACTION_BIOME_BREADTH_SCENARIO_ID = "ninefold-confluence"
SIX_FACTION_BIOME_BREADTH_REQUIRED_SITE_FAMILIES = LOGISTICS_SITE_FAMILIES | OVERWORLD_FOUNDATION_SITE_FAMILIES | {"one_shot_pickup"}
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
EDITOR_BASE_TERRAIN_OPTIONS = [
    ("water", "Water", "water", "watrtl"),
    ("snow", "Snow", "snow", "snowtl"),
    ("grass", "Grass", "grass", "grastl"),
    ("wastes", "Sand", "sand", "sandtl"),
    ("badlands", "Dirt", "dirt", "dirttl"),
    ("lava", "Lava", "lava", "lavatl"),
    ("swamp", "Swamp", "swamp", "swmptl"),
    ("highland", "Rock/None", "rock", "rocktl"),
]
EDITOR_BASE_TERRAIN_OPTION_IDS = {option[0] for option in EDITOR_BASE_TERRAIN_OPTIONS}
EDITOR_HIDDEN_LOGICAL_TERRAIN_IDS = {
    "plains",
    "forest",
    "mire",
    "hills",
    "ridge",
    "coast",
    "shore",
    "ash",
    "cavern",
    "underway",
    "frost",
}
HOMM3_LOCAL_PROTOTYPE_FAMILIES = {"grass", "rough", "dirt", "rock", "sand", "snow", "swamp", "lava", "subterranean", "water"}
HOMM3_FULL_RECEIVER_LAND_FAMILIES = {"grass", "rough", "snow", "swamp", "lava", "subterranean"}
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
    "site_wood_wagon": "lumber_wagon",
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
    "resource_value_weights": {"gold", "wood", "ore", "experience"},
    "site_family_weights": LOGISTICS_SITE_FAMILIES,
    "reinforcement": {"garrison_bias", "raid_bias", "ranged_weight", "melee_weight", "low_tier_weight", "high_tier_weight"},
    "raid": {"threshold_scale", "max_active_bonus", "pressure_commitment_scale", "objective_weight", "town_siege_weight", "site_denial_weight", "hero_hunt_weight"},
}
ECONOMY_REPORT_SCHEMA = "economy_resource_report_v1"
MARKET_FACTION_COST_REPORT_SCHEMA = "market_faction_cost_report_v1"
ECONOMY_RESOURCE_REGISTRY_POLICY_ID = "wood_canonical_v1"
ECONOMY_STAGED_RARE_RESOURCE_IDS = ("aetherglass", "embergrain", "peatwax", "verdant_grafts", "brass_scrip", "memory_salt")
ECONOMY_REPORT_RESOURCE_IDS = ("gold", "wood", "ore", *ECONOMY_STAGED_RARE_RESOURCE_IDS, "experience")
ECONOMY_STOCKPILE_RESOURCE_IDS = {"gold", "wood", "ore"}
ECONOMY_LIVE_STOCKPILE_RESOURCE_IDS = ("gold", "wood", "ore")
ECONOMY_NORMAL_MARKET_RESOURCE_IDS = ("wood", "ore")
ECONOMY_TARGET_ONLY_RESOURCE_IDS: set[str] = set()
ECONOMY_NON_STOCKPILE_REWARD_IDS = {"experience"}
ECONOMY_RARE_RESOURCE_IDS = set(ECONOMY_STAGED_RARE_RESOURCE_IDS)
ECONOMY_USAGE_BUCKETS = (
    "unit_costs",
    "building_costs",
    "building_income",
    "hero_costs",
    "faction_income",
    "town_income",
    "site_rewards",
    "site_income",
    "service_cost",
    "scenario_starting_resources",
    "scenario_script_grants",
    "campaign_rewards",
    "market_rules",
)
ECONOMY_SOURCE_BUCKETS = (
    "town_income",
    "building_income",
    "persistent_sites",
    "pickups",
    "repeatable_services",
    "market_profiles",
    "scenario_grants",
)
OVERWORLD_OBJECT_REPORT_SCHEMA = "overworld_object_report_v1"
NEUTRAL_ENCOUNTER_REPORT_SCHEMA = "neutral_encounter_report_v1"
NEUTRAL_ENCOUNTER_CANDIDATE_BUNDLE_ID = "neutral_encounter_representation_bundle_001"
NEUTRAL_ENCOUNTER_FIRST_CLASS_OBJECT_BUNDLE_ID = "neutral_encounter_first_class_object_bundle_001"
NEUTRAL_ENCOUNTER_FIRST_CLASS_OBJECT_BUNDLE_002_ID = "neutral_encounter_first_class_object_bundle_002"
NEUTRAL_ENCOUNTER_CANDIDATE_PLACEMENTS = {
    "river_pass_ghoul_grove": {
        "scenario_id": "river-pass",
        "encounter_id": "encounter_ghoul_grove",
        "proposed_mode": "visible_stack",
        "proposed_guard_role": "none",
        "expectation": "Candidate independent visible stack.",
    },
    "river_pass_hollow_mire": {
        "scenario_id": "river-pass",
        "encounter_id": "encounter_hollow_mire",
        "proposed_mode": "visible_stack",
        "proposed_guard_role": "route_block",
        "expectation": "Candidate route-block summary without runtime pathing adoption.",
    },
    "ninefold_basalt_gatehouse_watch": {
        "scenario_id": "ninefold-confluence",
        "encounter_id": "encounter_basalt_gatehouse_watch",
        "proposed_mode": "guard_linked_stack",
        "proposed_guard_role": "guards_resource_node",
        "target_id": "site_basalt_gatehouse",
        "target_placement_id": "dwelling_basalt_gatehouse",
        "expectation": "Candidate guard-link planning case for site_basalt_gatehouse.",
    },
}
NEUTRAL_ENCOUNTER_FIRST_CLASS_OBJECT_BUNDLE_001 = {
    "river_pass_ghoul_grove": {
        "scenario_id": "river-pass",
        "object_id": "object_neutral_encounter_river_pass_ghoul_grove_stack",
        "object_placement_id": "object_placement_river_pass_ghoul_grove",
    },
    "river_pass_hollow_mire": {
        "scenario_id": "river-pass",
        "object_id": "object_neutral_encounter_river_pass_hollow_mire_stack",
        "object_placement_id": "object_placement_river_pass_hollow_mire",
    },
    "ninefold_basalt_gatehouse_watch": {
        "scenario_id": "ninefold-confluence",
        "object_id": "object_neutral_encounter_ninefold_basalt_gatehouse_watch_stack",
        "object_placement_id": "object_placement_ninefold_basalt_gatehouse_watch",
    },
}
NEUTRAL_ENCOUNTER_FIRST_CLASS_OBJECT_BUNDLE_002 = {
    "river_pass_reed_totemists": {
        "scenario_id": "river-pass",
        "object_id": "object_neutral_encounter_river_pass_reed_totemists_stack",
        "object_placement_id": "object_placement_river_pass_reed_totemists",
    },
    "causeway_levee_cutters": {
        "scenario_id": "causeway-stand",
        "object_id": "object_neutral_encounter_causeway_levee_cutters_stack",
        "object_placement_id": "object_placement_causeway_levee_cutters",
    },
    "stonewake_reed_totemists": {
        "scenario_id": "stonewake-watch",
        "object_id": "object_neutral_encounter_stonewake_reed_totemists_stack",
        "object_placement_id": "object_placement_stonewake_reed_totemists",
    },
}
NEUTRAL_ENCOUNTER_BUNDLE_001_EXPECTED = {
    "river_pass_ghoul_grove": {
        "scenario_id": "river-pass",
        "base": {
            "placement_id": "river_pass_ghoul_grove",
            "encounter_id": "encounter_ghoul_grove",
            "x": 3,
            "y": 1,
            "difficulty": "low",
            "combat_seed": 1201,
        },
        "metadata": {
            "schema_version": 1,
            "bundle_id": NEUTRAL_ENCOUNTER_CANDIDATE_BUNDLE_ID,
            "primary_class": "neutral_encounter",
            "secondary_tags": ["visible_army", "route_pressure"],
            "encounter": {
                "primary_encounter_id": "encounter_ghoul_grove",
                "encounter_ids": ["encounter_ghoul_grove"],
                "difficulty_source": "scenario_placement",
                "combat_seed_source": "scenario_placement",
                "field_objectives_source": "encounter_definition",
                "preserve_placement_field_objectives": True,
            },
            "representation": {
                "mode": "visible_stack",
                "footprint_tier": "micro",
                "readability_family": "bramble_grove_raiders",
                "danger_cue_id": "neutral_warning_light",
                "visible_before_interaction": True,
                "uncertainty_policy": "exact_encounter_known",
            },
            "guard_link": {
                "guard_role": "none",
                "target_kind": "none",
                "target_id": "",
                "target_placement_id": "",
                "blocks_approach": True,
                "clear_required_for_target": False,
            },
            "state_model": {
                "initial_state": "idle",
                "state_after_victory": "cleared",
                "state_after_defeat": "active",
                "remove_on_clear": True,
                "remember_after_clear": True,
            },
            "placement_ownership": {
                "ownership_model": "neutral_ecology",
                "allowed_owner_kinds": ["neutral"],
                "spawner_kind": "scenario",
                "placement_authority": "scenario",
            },
            "reward_guard_summary": {
                "risk_tier": "light",
                "reward_categories": ["gold", "small_resource", "experience"],
                "resource_reward_ids": ["gold"],
                "guards_reward_tier": "none",
            },
            "passability": {
                "passability_class": "neutral_stack_blocking",
                "interaction_mode": "enter",
                "blocks_route_until_cleared": True,
            },
            "ai_hints": {
                "path_blocking": True,
                "avoid_until_strength": "light_guard",
                "neutral_clearance_value": 2,
                "guard_target_value_hint": 0,
            },
            "editor_placement": {
                "placement_mode": "scenario_encounter_overlay",
                "requires_clear_adjacent_target": False,
                "warn_if_hiding_target": True,
                "density_bucket": "guard_or_encounter",
            },
        },
    },
    "river_pass_hollow_mire": {
        "scenario_id": "river-pass",
        "base": {
            "placement_id": "river_pass_hollow_mire",
            "encounter_id": "encounter_hollow_mire",
            "x": 6,
            "y": 4,
            "difficulty": "medium",
            "combat_seed": 1202,
        },
        "metadata": {
            "schema_version": 1,
            "bundle_id": NEUTRAL_ENCOUNTER_CANDIDATE_BUNDLE_ID,
            "primary_class": "neutral_encounter",
            "secondary_tags": ["visible_army", "route_block", "mire_pressure"],
            "encounter": {
                "primary_encounter_id": "encounter_hollow_mire",
                "encounter_ids": ["encounter_hollow_mire"],
                "difficulty_source": "scenario_placement",
                "combat_seed_source": "scenario_placement",
                "field_objectives_source": "none",
                "preserve_placement_field_objectives": True,
            },
            "representation": {
                "mode": "visible_stack",
                "footprint_tier": "micro",
                "readability_family": "hollow_mire_pack",
                "danger_cue_id": "neutral_warning_standard",
                "visible_before_interaction": True,
                "uncertainty_policy": "exact_encounter_known",
            },
            "guard_link": {
                "guard_role": "route_block",
                "target_kind": "route",
                "target_id": "river_pass_mire_lane",
                "target_placement_id": "",
                "blocks_approach": True,
                "clear_required_for_target": False,
            },
            "state_model": {
                "initial_state": "idle",
                "state_after_victory": "cleared",
                "state_after_defeat": "active",
                "remove_on_clear": True,
                "remember_after_clear": True,
            },
            "placement_ownership": {
                "ownership_model": "neutral_ecology",
                "allowed_owner_kinds": ["neutral"],
                "spawner_kind": "scenario",
                "placement_authority": "scenario",
            },
            "reward_guard_summary": {
                "risk_tier": "standard",
                "reward_categories": ["gold", "small_resource", "resource", "experience", "route_opening"],
                "resource_reward_ids": ["gold", "ore"],
                "guards_reward_tier": "route",
            },
            "passability": {
                "passability_class": "neutral_stack_blocking",
                "interaction_mode": "enter",
                "blocks_route_until_cleared": True,
            },
            "ai_hints": {
                "path_blocking": True,
                "avoid_until_strength": "standard_guard",
                "neutral_clearance_value": 4,
                "guard_target_value_hint": 1,
            },
            "editor_placement": {
                "placement_mode": "scenario_encounter_overlay",
                "requires_clear_adjacent_target": False,
                "warn_if_hiding_target": True,
                "density_bucket": "guard_or_encounter",
            },
        },
    },
    "ninefold_basalt_gatehouse_watch": {
        "scenario_id": "ninefold-confluence",
        "base": {
            "placement_id": "ninefold_basalt_gatehouse_watch",
            "encounter_id": "encounter_basalt_gatehouse_watch",
            "x": 60,
            "y": 52,
            "difficulty": "high",
            "combat_seed": 16406,
        },
        "metadata": {
            "schema_version": 1,
            "bundle_id": NEUTRAL_ENCOUNTER_CANDIDATE_BUNDLE_ID,
            "primary_class": "neutral_encounter",
            "secondary_tags": ["visible_army", "guarded_reward", "neutral_dwelling_watch", "scenario_objective_guard"],
            "encounter": {
                "primary_encounter_id": "encounter_basalt_gatehouse_watch",
                "encounter_ids": ["encounter_basalt_gatehouse_watch"],
                "difficulty_source": "scenario_placement",
                "combat_seed_source": "scenario_placement",
                "field_objectives_source": "encounter_definition",
                "preserve_placement_field_objectives": True,
            },
            "representation": {
                "mode": "guard_linked_stack",
                "footprint_tier": "micro",
                "readability_family": "basalt_gatehouse_custodians",
                "danger_cue_id": "neutral_warning_heavy",
                "visible_before_interaction": True,
                "uncertainty_policy": "exact_encounter_known",
            },
            "guard_link": {
                "guard_role": "guards_resource_node",
                "target_kind": "resource_node",
                "target_id": "site_basalt_gatehouse",
                "target_placement_id": "dwelling_basalt_gatehouse",
                "blocks_approach": True,
                "clear_required_for_target": True,
            },
            "state_model": {
                "initial_state": "idle",
                "state_after_victory": "cleared",
                "state_after_defeat": "active",
                "remove_on_clear": True,
                "remember_after_clear": True,
            },
            "placement_ownership": {
                "ownership_model": "neutral_ecology",
                "allowed_owner_kinds": ["neutral"],
                "spawner_kind": "scenario",
                "placement_authority": "scenario",
            },
            "reward_guard_summary": {
                "risk_tier": "heavy",
                "reward_categories": ["gold", "small_resource", "resource", "experience", "recruitment", "scenario_progress"],
                "resource_reward_ids": ["gold", "ore"],
                "guards_reward_tier": "major",
            },
            "passability": {
                "passability_class": "neutral_stack_blocking",
                "interaction_mode": "enter",
                "blocks_route_until_cleared": True,
            },
            "ai_hints": {
                "path_blocking": True,
                "avoid_until_strength": "heavy_guard",
                "neutral_clearance_value": 7,
                "guard_target_value_hint": 5,
            },
            "editor_placement": {
                "placement_mode": "scenario_encounter_overlay",
                "requires_clear_adjacent_target": False,
                "warn_if_hiding_target": True,
                "density_bucket": "guard_or_encounter",
            },
        },
    },
}
NEUTRAL_ENCOUNTER_BUNDLE_002_EXPECTED = {
    "river_pass_reed_totemists": {
        "scenario_id": "river-pass",
        "base": {"placement_id": "river_pass_reed_totemists", "encounter_id": "encounter_reed_totemists", "x": 4, "y": 0, "difficulty": "medium", "combat_seed": 1203},
        "objective_id": "break_reed_totemists",
    },
    "causeway_levee_cutters": {
        "scenario_id": "causeway-stand",
        "base": {"placement_id": "causeway_levee_cutters", "encounter_id": "encounter_reed_totemists", "x": 6, "y": 5, "difficulty": "medium", "combat_seed": 2203},
        "objective_id": "clear_levee_cutters",
    },
    "stonewake_reed_totemists": {
        "scenario_id": "stonewake-watch",
        "base": {"placement_id": "stonewake_reed_totemists", "encounter_id": "encounter_reed_totemists", "x": 6, "y": 5, "difficulty": "medium", "combat_seed": 4203},
        "objective_id": "clear_reed_totemists",
    },
}
for _placement_id, _expected in NEUTRAL_ENCOUNTER_BUNDLE_002_EXPECTED.items():
    _objective_id = str(_expected["objective_id"])
    _expected["metadata"] = {
        "schema_version": 1,
        "bundle_id": NEUTRAL_ENCOUNTER_FIRST_CLASS_OBJECT_BUNDLE_002_ID,
        "primary_class": "neutral_encounter",
        "secondary_tags": ["visible_army", "mire_pressure", "scenario_objective_guard"],
        "encounter": {
            "primary_encounter_id": "encounter_reed_totemists",
            "encounter_ids": ["encounter_reed_totemists"],
            "difficulty_source": "scenario_placement",
            "combat_seed_source": "scenario_placement",
            "field_objectives_source": "encounter_definition",
            "preserve_placement_field_objectives": True,
        },
        "representation": {
            "mode": "guard_linked_stack",
            "footprint_tier": "micro",
            "readability_family": "reed_totemist_ring",
            "danger_cue_id": "neutral_warning_standard",
            "visible_before_interaction": True,
            "uncertainty_policy": "exact_encounter_known",
        },
        "guard_link": {
            "guard_role": "guards_scenario_objective",
            "target_kind": "scenario_objective",
            "target_id": _objective_id,
            "target_placement_id": _placement_id,
            "blocks_approach": True,
            "clear_required_for_target": True,
        },
        "state_model": {
            "initial_state": "idle",
            "state_after_victory": "cleared",
            "state_after_defeat": "active",
            "remove_on_clear": True,
            "remember_after_clear": True,
        },
        "placement_ownership": {
            "ownership_model": "neutral_ecology",
            "allowed_owner_kinds": ["neutral"],
            "spawner_kind": "scenario",
            "placement_authority": "scenario",
        },
        "reward_guard_summary": {
            "risk_tier": "standard",
            "reward_categories": ["gold", "small_resource", "resource", "experience", "scenario_progress"],
            "resource_reward_ids": ["gold", "wood"],
            "guards_reward_tier": "objective",
        },
        "passability": {
            "passability_class": "neutral_stack_blocking",
            "interaction_mode": "adjacent",
            "blocks_route_until_cleared": True,
        },
        "ai_hints": {
            "path_blocking": True,
            "avoid_until_strength": "standard_guard",
            "neutral_clearance_value": 4,
            "guard_target_value_hint": 3,
        },
        "editor_placement": {
            "placement_mode": "scenario_encounter_overlay",
            "requires_clear_adjacent_target": True,
            "warn_if_hiding_target": True,
            "density_bucket": "guard_or_encounter",
        },
    }
del _placement_id, _expected, _objective_id
NEUTRAL_ENCOUNTER_REPRESENTATION_MODES = {"visible_stack", "camp_anchor", "guard_linked_stack", "guard_linked_camp"}
NEUTRAL_ENCOUNTER_GUARD_ROLES = {
    "none",
    "route_block",
    "guards_object",
    "guards_resource_node",
    "guards_artifact_node",
    "guards_town_approach",
    "guards_scenario_objective",
    "patrol_zone",
}
NEUTRAL_ENCOUNTER_TARGET_KINDS = {"none", "map_object", "resource_node", "artifact_node", "town", "scenario_objective", "route"}
NEUTRAL_ENCOUNTER_PASSABILITY_CLASSES = {"neutral_stack_blocking", "blocking_visitable"}
NEUTRAL_ENCOUNTER_OWNERSHIP_MODELS = {"neutral_ecology", "scenario_fixed", "faction_influenced_neutral"}
NEUTRAL_ENCOUNTER_STATES = {"idle", "active", "cleared", "depleted"}
NEUTRAL_ENCOUNTER_RISK_TIERS = {"light", "standard", "heavy", "elite", "ambush_uncertain"}
NEUTRAL_ENCOUNTER_OBJECT_SCHEMA_FIELDS = (
    "schema_version",
    "primary_class",
    "secondary_tags",
    "footprint",
    "passability_class",
    "interaction",
    "neutral_encounter",
)
OVERWORLD_OBJECT_PRIMARY_CLASSES = {
    "decoration",
    "pickup",
    "interactable_site",
    "persistent_economy_site",
    "transit_route_object",
    "neutral_dwelling",
    "neutral_encounter",
    "guarded_reward_site",
    "faction_landmark",
    "scenario_objective",
}
OVERWORLD_OBJECT_SECONDARY_TAGS = {
    "road_control",
    "sightline",
    "ambush_lane",
    "resource_front",
    "recovery",
    "spell_access",
    "market",
    "blocked_route",
    "conditional_route",
    "world_lore",
    "guarded_reward",
    "neutral_recruit_source",
    "faction_pressure",
    "scenario_objective",
    "counter_capture_target",
    "town_support",
    "weekly_muster",
    "small_reward",
    "route_pacing",
    "build_resource",
    "visible_army",
    "route_pressure",
    "route_block",
    "mire_pressure",
    "common_resource_front",
    "rare_resource_front",
    "staged_report_only",
    "support_producer",
    "neutral_dwelling_watch",
    "scenario_objective_guard",
    "neutral_encounter",
}
OVERWORLD_OBJECT_FAMILY_PRIMARY_CLASS = {
    "pickup": "pickup",
    "mine": "persistent_economy_site",
    "neutral_dwelling": "neutral_dwelling",
    "shrine": "interactable_site",
    "guarded_reward_site": "guarded_reward_site",
    "scouting_structure": "interactable_site",
    "transit_object": "transit_route_object",
    "repeatable_service": "interactable_site",
    "blocker": "decoration",
    "decoration": "decoration",
    "faction_landmark": "faction_landmark",
    "neutral_encounter": "neutral_encounter",
    "staged_resource_front": "persistent_economy_site",
    "support_producer": "persistent_economy_site",
    "sign_waypoint": "interactable_site",
    "scenario_objective": "scenario_objective",
}
OVERWORLD_OBJECT_FAMILY_TAGS = {
    "pickup": {"small_reward", "route_pacing"},
    "mine": {"resource_front", "counter_capture_target"},
    "neutral_dwelling": {"neutral_recruit_source", "weekly_muster", "counter_capture_target"},
    "shrine": {"spell_access", "recovery"},
    "guarded_reward_site": {"guarded_reward"},
    "scouting_structure": {"sightline", "counter_capture_target"},
    "transit_object": {"road_control", "conditional_route"},
    "repeatable_service": {"recovery"},
    "blocker": {"blocked_route"},
    "decoration": {"world_lore"},
    "faction_landmark": {"faction_pressure", "world_lore"},
    "neutral_encounter": {"neutral_encounter"},
    "staged_resource_front": {"resource_front", "rare_resource_front", "counter_capture_target"},
    "support_producer": {"support_producer", "town_support", "counter_capture_target"},
    "sign_waypoint": {"world_lore", "road_control"},
    "scenario_objective": {"scenario_objective", "world_lore"},
}
OVERWORLD_OBJECT_CONTENT_BATCH_001_ID = "overworld-object-content-batch-001-core-density-pickups-10184"
OVERWORLD_OBJECT_CONTENT_BATCH_001B_ID = "overworld-object-content-batch-001b-biome-scenic-decoration-10184"
OVERWORLD_OBJECT_CONTENT_BATCH_001C_ID = "overworld-object-content-batch-001c-biome-blockers-edge-10184"
OVERWORLD_OBJECT_CONTENT_BATCH_001D_ID = "overworld-object-content-batch-001d-large-footprint-coverage-10184"
OVERWORLD_OBJECT_CONTENT_BATCH_002_ID = "overworld-object-content-batch-002-mines-resource-fronts-10184"
OVERWORLD_OBJECT_CONTENT_BATCH_003_ID = "overworld-object-content-batch-003-services-shrines-signs-events-10184"
OVERWORLD_OBJECT_CONTENT_BATCH_004_ID = "overworld-object-content-batch-004-transit-coast-route-control-10184"
OVERWORLD_OBJECT_CONTENT_BATCH_005_ID = "overworld-object-content-batch-005-dwellings-guarded-dwellings-10184"
OVERWORLD_OBJECT_PASSABILITY_CLASSES = {
    "passable_visit_on_enter",
    "passable_scenic",
    "blocking_visitable",
    "blocking_non_visitable",
    "edge_blocker",
    "conditional_pass",
    "town_blocking",
    "neutral_stack_blocking",
}
OVERWORLD_OBJECT_EDITOR_DENSITY_REGION_SIZE = 16
OVERWORLD_OBJECT_EDITOR_DENSITY_BANDS = {
    "sparse_wild",
    "standard_adventure",
    "contested_economy",
    "ruin_reward_pocket",
    "town_influence",
    "guard_or_encounter",
}
OVERWORLD_OBJECT_EDITOR_PLACEMENT_MODES = {
    "palette_object",
    "resource_site_object",
    "scenario_encounter_overlay",
    "scenario_objective",
}
OVERWORLD_OBJECT_EDITOR_BOOL_KEYS = {
    "allows_adjacent_visitable",
    "requires_road_adjacency",
    "requires_approach_clearance",
    "requires_guard_space",
    "requires_clear_adjacent_target",
    "warn_if_hiding_target",
}
OVERWORLD_OBJECT_APPROACH_MODES = {"enter", "adjacent", "pass_through", "linked_endpoint", "none"}
OVERWORLD_OBJECT_APPROACH_SIDES = {"north", "east", "south", "west"}
OVERWORLD_OBJECT_FOOTPRINT_ANCHORS = {"bottom_center", "center", "top_left", "bottom_left", "bottom_right"}
OVERWORLD_OBJECT_FOOTPRINT_TIERS = {"micro", "small", "medium", "large", "region_feature"}
OVERWORLD_OBJECT_INTERACTION_CADENCES = {
    "none",
    "one_time",
    "repeatable_daily",
    "repeatable_weekly",
    "cooldown_days",
    "persistent_control",
    "conditional",
    "scenario_scripted",
}
OVERWORLD_OBJECT_ROUTE_EFFECT_TYPES = {
    "open_route",
    "close_route",
    "linked_endpoint",
    "movement_discount",
    "movement_tax",
    "toll",
    "conditional_pass",
    "scouting_sightline",
    "fog_bypass",
    "repair_unlock",
    "faction_favored_pass",
    "scenario_gate",
}
OVERWORLD_OBJECT_ROUTE_EFFECT_REQUIRED_KEYS = {
    "effect_id",
    "effect_type",
    "requires_visit",
    "requires_owner",
    "movement_cost_delta",
    "toll_resources",
    "blocked_state_ids",
}
OVERWORLD_OBJECT_PUBLIC_ROUTE_LEAK_TOKENS = {
    "base_value",
    "route_pressure_value",
    "object_metadata_value",
    "object_route_pressure_value",
    "priority_without_object_metadata",
    "priority_with_object_metadata",
    "final_priority",
    "final_score",
    "debug_reason",
    "ai_score",
    "weight",
}
OVERWORLD_OBJECT_SAFE_METADATA_BUNDLE_001 = {
    "object_waystone_cache",
    "object_wood_wagon",
    "object_watchtower_beacon",
    "object_wayfarer_infirmary",
    "object_market_caravanserai",
    "object_brightwood_sawmill",
    "object_bramble_wall",
    "object_ember_signal_brazier",
}
OVERWORLD_OBJECT_SAFE_INTERACTION_KEYS = {
    "cadence",
    "remains_after_visit",
    "state_after_visit",
    "requires_ownership",
    "requires_guard_clear",
    "supports_revisit",
    "cooldown_days",
    "refresh_rule",
}
OVERWORLD_OBJECT_SAFE_STATE_AFTER_VISIT = {"collected", "visited", "claimed", "opened", "cleared", "unchanged"}
OVERWORLD_OBJECT_SAFE_REFRESH_RULES = {"none", "daily_income", "weekly_growth", "cooldown", "route_state", "scenario", "persistent_state"}


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


def append_unique_dict(values: list[dict], item: dict) -> None:
    if item not in values:
        values.append(item)


def resource_display_name(resource_id: str, registry_items: dict[str, dict] | None = None) -> str:
    registry_items = registry_items or {}
    if resource_id in registry_items:
        return str(registry_items[resource_id].get("display_name", resource_id))
    fallback = {
        "gold": "Gold",
        "wood": "Wood",
        "ore": "Ore",
        "experience": "Experience",
    }
    return fallback.get(resource_id, resource_id.replace("_", " ").title())


def resource_is_stockpile(resource_id: str, registry_items: dict[str, dict] | None = None) -> bool:
    registry_items = registry_items or {}
    if resource_id in registry_items:
        return bool(registry_items[resource_id].get("stockpile", False))
    return resource_id in ECONOMY_STOCKPILE_RESOURCE_IDS


def resource_is_non_stockpile_reward(resource_id: str, registry_items: dict[str, dict] | None = None) -> bool:
    registry_items = registry_items or {}
    if resource_id in registry_items:
        return not bool(registry_items[resource_id].get("stockpile", False))
    return resource_id in ECONOMY_NON_STOCKPILE_REWARD_IDS


def positive_resource_amount(resources: dict, resource_id: str) -> bool:
    try:
        return int(resources.get(resource_id, 0)) > 0
    except (TypeError, ValueError):
        return False


def detect_alias_collisions(resources: object) -> list[str]:
    return []


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


def load_economy_resource_registry() -> dict:
    if ECONOMY_RESOURCE_REGISTRY_FIXTURE_PATH.exists():
        return load_json(ECONOMY_RESOURCE_REGISTRY_FIXTURE_PATH)
    return {
        "schema": "economy_resource_registry_fixture_v1",
        "items": [
            {"id": "gold", "display_name": "Gold", "category": "liquidity", "market_tier": "common", "default_visible": True, "legacy_aliases": [], "ui_sort": 10, "stockpile": True},
            {"id": "wood", "display_name": "Wood", "category": "construction_staple", "market_tier": "common", "default_visible": True, "legacy_aliases": [], "canonical_status": "canonical_live_id", "ui_sort": 20, "stockpile": True, "report_only": True},
            {"id": "ore", "display_name": "Ore", "category": "construction_staple", "market_tier": "common", "default_visible": True, "legacy_aliases": [], "ui_sort": 30, "stockpile": True},
            {"id": "aetherglass", "display_name": "Aetherglass", "category": "arcane_material", "market_tier": "restricted_rare", "default_visible": False, "legacy_aliases": [], "canonical_status": "staged_limited", "ui_sort": 100, "stockpile": True, "report_only": True, "activation_status": "staged_report_only", "source_readiness": "planned_source_family", "source_site_family": "aetherglass_orchard"},
            {"id": "embergrain", "display_name": "Embergrain", "category": "supply", "market_tier": "restricted_rare", "default_visible": False, "legacy_aliases": [], "canonical_status": "staged_limited", "ui_sort": 110, "stockpile": True, "report_only": True, "activation_status": "staged_report_only", "source_readiness": "planned_source_family", "source_site_family": "embergrain_yard"},
            {"id": "peatwax", "display_name": "Peatwax", "category": "local_fuel_rite", "market_tier": "restricted_rare", "default_visible": False, "legacy_aliases": [], "canonical_status": "staged_limited", "ui_sort": 120, "stockpile": True, "report_only": True, "activation_status": "staged_report_only", "source_readiness": "planned_source_family", "source_site_family": "peatwax_cut"},
            {"id": "verdant_grafts", "display_name": "Verdant grafts", "category": "living_material", "market_tier": "restricted_rare", "default_visible": False, "legacy_aliases": [], "canonical_status": "staged_limited", "ui_sort": 130, "stockpile": True, "report_only": True, "activation_status": "staged_report_only", "source_readiness": "planned_source_family", "source_site_family": "graft_nursery"},
            {"id": "brass_scrip", "display_name": "Brass scrip", "category": "contract_credit", "market_tier": "restricted_rare", "default_visible": False, "legacy_aliases": [], "canonical_status": "staged_limited", "ui_sort": 140, "stockpile": True, "report_only": True, "activation_status": "staged_report_only", "source_readiness": "planned_source_family", "source_site_family": "contract_foundry"},
            {"id": "memory_salt", "display_name": "Memory salt", "category": "salvage_memory", "market_tier": "restricted_rare", "default_visible": False, "legacy_aliases": [], "canonical_status": "staged_limited", "ui_sort": 150, "stockpile": True, "report_only": True, "activation_status": "staged_report_only", "source_readiness": "planned_source_family", "source_site_family": "memory_salt_salvage"},
            {"id": "experience", "display_name": "Experience", "category": "progression_reward", "market_tier": "none", "default_visible": False, "legacy_aliases": [], "canonical_status": "non_stockpile_reward", "ui_sort": 900, "stockpile": False},
        ],
    }


def economy_registry_items(registry: dict) -> dict[str, dict]:
    return items_index(registry)


def economy_report_resource_entry(resource_id: str, registry_items: dict[str, dict]) -> dict:
    return {
        "resource_id": resource_id,
        "display_name": resource_display_name(resource_id, registry_items),
        "stockpile": resource_is_stockpile(resource_id, registry_items),
        "used_by": {bucket: 0 for bucket in ECONOMY_USAGE_BUCKETS},
        "source_paths": {bucket: [] for bucket in ECONOMY_SOURCE_BUCKETS},
        "occurrences": [],
        "availability": "registry_only",
        "warnings": [],
    }


def economy_rare_resource_report_entry(resource_id: str, registry_items: dict[str, dict], usage_entry: dict) -> dict:
    item = registry_items.get(resource_id, {})
    return {
        "resource_id": resource_id,
        "display_name": resource_display_name(resource_id, registry_items),
        "category": str(item.get("category", "")),
        "market_tier": str(item.get("market_tier", "")),
        "default_visible": bool(item.get("default_visible", False)),
        "report_visible": bool(item.get("report_visible", item.get("report_only", False))),
        "activation_status": str(item.get("activation_status", "")),
        "source_readiness": str(item.get("source_readiness", "registry_only")),
        "source_site_family": str(item.get("source_site_family", "")),
        "intended_source_paths": [str(value) for value in item.get("intended_source_paths", [])] if isinstance(item.get("intended_source_paths", []), list) else [],
        "source_evidence_docs": [str(value) for value in item.get("source_evidence_docs", [])] if isinstance(item.get("source_evidence_docs", []), list) else [],
        "faction_affinity": item.get("faction_affinity", {}) if isinstance(item.get("faction_affinity", {}), dict) else {},
        "ui_sort": int(item.get("ui_sort", 0)),
        "icon_hint_id": str(item.get("icon_hint_id", "")),
        "material_cue": str(item.get("material_cue", "")),
        "production_occurrences": len(usage_entry.get("occurrences", [])),
        "availability": str(usage_entry.get("availability", "")),
        "live_costs_enabled": False,
        "live_sources_enabled": False,
        "normal_market_buying_enabled": False,
        "save_version_bump_required": False,
    }


def add_economy_report_warning(report: dict, warning: str) -> None:
    if warning not in report["warnings"]:
        report["warnings"].append(warning)


def record_economy_resource_dict(report: dict, registry_items: dict[str, dict], resources: object, domain: str, owner_id: str, field: str, usage_bucket: str, source_bucket: str = "") -> None:
    if not isinstance(resources, dict) or not resources:
        return
    for raw_resource_id, raw_amount in resources.items():
        resource_id = str(raw_resource_id)
        try:
            amount = int(raw_amount)
        except (TypeError, ValueError):
            amount = 0
        if resource_id not in report["usage"]:
            report["usage"][resource_id] = economy_report_resource_entry(resource_id, registry_items)
        entry = report["usage"][resource_id]
        if usage_bucket in entry["used_by"]:
            entry["used_by"][usage_bucket] += 1
        append_unique_dict(entry["occurrences"], {"domain": domain, "id": owner_id, "field": field, "amount": amount})
        if source_bucket and source_bucket in entry["source_paths"]:
            append_unique(entry["source_paths"][source_bucket], f"{domain}:{owner_id}:{field}")
        if resource_id not in registry_items and resource_id not in ECONOMY_STOCKPILE_RESOURCE_IDS and resource_id not in ECONOMY_NON_STOCKPILE_REWARD_IDS:
            warning = f"{domain} {owner_id} references unregistered resource id {resource_id}"
            append_unique(entry["warnings"], warning)
            add_economy_report_warning(report, warning)


def infer_economy_site_cadence(report: dict, registry_items: dict[str, dict], site_id: str, site: dict) -> None:
    family = str(site.get("family", "one_shot_pickup"))
    site_report = {
        "site_id": site_id,
        "family": family,
        "persistent_control": bool(site.get("persistent_control", False)),
        "repeatable": bool(site.get("repeatable", False)),
        "inferred_outputs": [],
        "warnings": [],
    }
    for field in ("rewards", "claim_rewards"):
        resources = site.get(field, {})
        if isinstance(resources, dict) and resources:
            cadence = "battle_cleanup" if bool(site.get("guarded", False)) else "instant_claim"
            for resource_id, amount in resources.items():
                site_report["inferred_outputs"].append({"resource_id": str(resource_id), "display_name": resource_display_name(str(resource_id), registry_items), "cadence": cadence, "amount": int(amount)})
    if bool(site.get("persistent_control", False)) and isinstance(site.get("control_income", {}), dict) and site.get("control_income", {}):
        for resource_id, amount in site.get("control_income", {}).items():
            site_report["inferred_outputs"].append({"resource_id": str(resource_id), "display_name": resource_display_name(str(resource_id), registry_items), "cadence": "daily", "amount": int(amount)})
        if "resource_outputs" not in site:
            site_report["warnings"].append("persistent site has inferred daily control_income but no explicit future resource_outputs cadence")
    if bool(site.get("repeatable", False)) and int(site.get("visit_cooldown_days", 0)) > 0:
        site_report["inferred_outputs"].append({"resource_id": "", "display_name": "", "cadence": "service_refresh", "amount": 0, "cooldown_days": int(site.get("visit_cooldown_days", 0))})
        if isinstance(site.get("rewards", {}), dict) and site.get("rewards", {}):
            site_report["warnings"].append("repeatable service grants resources without future cap or refresh profile metadata")
    if isinstance(site.get("weekly_recruits", {}), dict) and site.get("weekly_recruits", {}):
        site_report["inferred_outputs"].append({"resource_id": "", "display_name": "", "cadence": "weekly_recruit_refresh", "amount": 0})
    if isinstance(site.get("transit_profile", {}), dict) and site.get("transit_profile", {}):
        site_report["inferred_outputs"].append({"resource_id": "", "display_name": "", "cadence": "route_effect", "amount": 0})
        if any(key in site for key in ("rewards", "claim_rewards", "control_income")):
            site_report["warnings"].append("transit object has resource payloads but no route-linked output metadata")
    for warning in site_report["warnings"]:
        add_economy_report_warning(report, f"{site_id}: {warning}")
    report["cadence"][site_id] = site_report


def infer_economy_capture_report(report: dict, registry_items: dict[str, dict], site_id: str, site: dict) -> None:
    if not bool(site.get("persistent_control", False)):
        return
    family = str(site.get("family", "one_shot_pickup"))
    capture_profile = site.get("capture_profile", {})
    capture_report = {
        "site_id": site_id,
        "family": family,
        "persistent_control": True,
        "inferred_outputs": [],
        "capture_profile_present": isinstance(capture_profile, dict) and bool(capture_profile),
        "recommended_capture_model": "capturable" if family in {"mine", "neutral_dwelling", "faction_outpost", "frontier_shrine"} else "claim_once",
        "recommended_counter_capture_value": 5 if family == "mine" else 3,
        "warnings": [],
    }
    if isinstance(site.get("control_income", {}), dict):
        for resource_id, amount in site.get("control_income", {}).items():
            capture_report["inferred_outputs"].append({"resource_id": str(resource_id), "display_name": resource_display_name(str(resource_id), registry_items), "cadence": "daily", "amount": int(amount)})
    if not capture_report["capture_profile_present"]:
        capture_report["warnings"].append("persistent site lacks capture_profile")
        capture_report["warnings"].append("persistent site lacks counter_capture_value")
        capture_report["warnings"].append("persistent site lacks retake/damaged-state policy")
    elif "counter_capture_value" not in capture_profile:
        capture_report["warnings"].append("persistent site lacks counter_capture_value")
    if not any(bool(site.get(key)) for key in ("control_income", "town_support", "claim_recruits", "weekly_recruits", "transit_profile", "vision_radius", "response_profile")):
        capture_report["warnings"].append("site has persistent_control but no clear income, support, recruit, route, scouting, or response reason")
    for output in capture_report["inferred_outputs"]:
        if str(output.get("resource_id", "")) in ECONOMY_RARE_RESOURCE_IDS and not bool(site.get("guarded", False)):
            capture_report["warnings"].append("persistent rare-resource output lacks guard/counter-capture metadata")
    for warning in capture_report["warnings"]:
        add_economy_report_warning(report, f"{site_id}: {warning}")
    report["capture"][site_id] = capture_report


def finalize_economy_resource_availability(report: dict, registry_items: dict[str, dict]) -> None:
    for resource_id, entry in report["usage"].items():
        if resource_is_non_stockpile_reward(resource_id, registry_items):
            entry["availability"] = "non_stockpile_reward"
            continue
        used_by = entry["used_by"]
        source_count = used_by.get("building_income", 0) + used_by.get("faction_income", 0) + used_by.get("town_income", 0) + used_by.get("site_rewards", 0) + used_by.get("site_income", 0) + used_by.get("scenario_starting_resources", 0) + used_by.get("scenario_script_grants", 0)
        cost_count = used_by.get("unit_costs", 0) + used_by.get("building_costs", 0) + used_by.get("hero_costs", 0) + used_by.get("service_cost", 0)
        if resource_id not in registry_items:
            entry["availability"] = "unknown_unregistered"
        elif source_count > 0 and cost_count > 0:
            entry["availability"] = "available"
        elif source_count > 0:
            entry["availability"] = "reward_only"
        elif cost_count > 0:
            entry["availability"] = "cost_only"
        elif used_by.get("scenario_script_grants", 0) > 0:
            entry["availability"] = "script_only"
        else:
            entry["availability"] = "registry_only"


def economy_old_save_compatibility_summary(registry_items: dict[str, dict]) -> dict:
    summary = {
        "resource_schema_version_required": False,
        "save_version_bump_required": False,
        "live_resource_id": "wood",
        "target_only_resource_ids": [],
        "accepted_without_resource_schema_version": False,
        "wood_preserved_in_old_save_fixture": False,
        "fixture_ids": [],
        "warnings": [],
    }
    fixture_path = ECONOMY_RESOURCE_STRICT_CASES_PATH
    if not fixture_path.exists():
        summary["warnings"].append(f"missing strict economy save fixture file: {fixture_path.relative_to(ROOT)}")
        return summary
    cases = load_json(fixture_path)
    for payload in cases.get("valid", {}).get("save_payloads", []):
        if not isinstance(payload, dict):
            continue
        payload_id = str(payload.get("id", "valid_save_payload"))
        resources = payload.get("resources", {})
        summary["fixture_ids"].append(payload_id)
        if "resource_schema_version" not in payload:
            summary["accepted_without_resource_schema_version"] = True
        if isinstance(resources, dict):
            if "wood" in resources and str("wood") in registry_items:
                summary["wood_preserved_in_old_save_fixture"] = True
    if not summary["accepted_without_resource_schema_version"]:
        summary["warnings"].append("no valid old-save fixture omits resource_schema_version")
    if not summary["wood_preserved_in_old_save_fixture"]:
        summary["warnings"].append("no valid old-save fixture preserves wood")
    return summary


def build_economy_resource_report() -> dict:
    registry = load_economy_resource_registry()
    registry_items = economy_registry_items(registry)
    old_save_compatibility = economy_old_save_compatibility_summary(registry_items)
    report = {
        "schema": ECONOMY_REPORT_SCHEMA,
        "generated_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        "mode": "registry_policy_report",
        "registry": {
            "resource_count": len(registry_items),
            "stockpile_resource_ids": sorted([resource_id for resource_id, item in registry_items.items() if bool(item.get("stockpile", False)) and str(item.get("canonical_status", "canonical")) != "alias_only"]),
            "live_stockpile_resource_ids": list(ECONOMY_LIVE_STOCKPILE_RESOURCE_IDS),
            "staged_limited_resource_ids": list(ECONOMY_STAGED_RARE_RESOURCE_IDS),
            "non_stockpile_reward_ids": sorted([resource_id for resource_id, item in registry_items.items() if not bool(item.get("stockpile", False))]),
            "report_visible_resource_ids": sorted([resource_id for resource_id, item in registry_items.items() if bool(item.get("default_visible", False)) or bool(item.get("report_only", False))]),
            "alias_pairs": [],
            "missing_metadata": [],
        },
        "usage": {},
        "sources": {},
        "cadence": {},
        "capture": {},
        "market_caps": {},
        "rare_resources": {},
        "staged_resource_fronts": {},
        "ui_report": {},
        "activation_gates": {
            "rules": "staged_report_only",
            "ui_report": "registry_rows_visible_in_economy_resource_report",
            "content_sources": "planned_source_families_only",
            "save_compatibility": "old_saves_accept_absent_rare_resources_without_version_bump",
            "market": "normal_market_rare_buying_disabled",
            "broad_costs": "not_enabled",
        },
        "registry_policy": {
            "policy_id": ECONOMY_RESOURCE_REGISTRY_POLICY_ID,
            "mode": "report_only_registry_policy",
            "decision": "keep_wood_as_live_authored_and_save_id",
            "live_stockpile_resource_ids": list(ECONOMY_LIVE_STOCKPILE_RESOURCE_IDS),
            "staged_limited_resource_ids": list(ECONOMY_STAGED_RARE_RESOURCE_IDS),
            "target_only_resource_ids": [],
            "non_stockpile_reward_ids": ["experience"],
            "wood_policy": "wood is the canonical live authored/save id with no alternate target id or alias path",
            "production_content_migration": False,
            "runtime_adoption": "not_active",
            "save_rewrite": False,
            "save_version_bump": False,
            "rare_resource_activation": "staged_report_only",
            "live_rare_resource_activation": False,
        },
        "compatibility_adapters": {"runtime_adoption": "not_needed", "report_normalization": "none", "wood_live_id": "wood", "target_resource_ids": [], "save_rewrite": False},
        "old_save_compatibility": old_save_compatibility,
        "warnings": [],
        "errors": [],
    }
    for resource_id in ECONOMY_REPORT_RESOURCE_IDS:
        report["usage"][resource_id] = economy_report_resource_entry(resource_id, registry_items)

    payloads = {key: load_json(CONTENT_DIR / f"{key}.json") for key in ("factions", "heroes", "units", "towns", "buildings", "resource_sites", "scenarios", "campaigns")}
    factions = items_index(payloads["factions"])
    heroes = items_index(payloads["heroes"])
    units = items_index(payloads["units"])
    towns = items_index(payloads["towns"])
    buildings = items_index(payloads["buildings"])
    resource_sites = items_index(payloads["resource_sites"])
    scenarios = items_index(payloads["scenarios"])
    campaigns = items_index(payloads["campaigns"])

    for unit_id, unit in units.items():
        record_economy_resource_dict(report, registry_items, unit.get("cost", {}), "units", unit_id, "cost", "unit_costs")
    for building_id, building in buildings.items():
        record_economy_resource_dict(report, registry_items, building.get("cost", {}), "buildings", building_id, "cost", "building_costs")
        record_economy_resource_dict(report, registry_items, building.get("income", {}), "buildings", building_id, "income", "building_income", "building_income")
    for hero_id, hero in heroes.items():
        record_economy_resource_dict(report, registry_items, hero.get("recruit_cost", {}), "heroes", hero_id, "recruit_cost", "hero_costs")
    for faction_id, faction in factions.items():
        economy = faction.get("economy", {})
        if isinstance(economy, dict):
            record_economy_resource_dict(report, registry_items, economy.get("base_income", {}), "factions", faction_id, "economy.base_income", "faction_income")
            for category, resources in economy.get("per_category_income", {}).items() if isinstance(economy.get("per_category_income", {}), dict) else []:
                record_economy_resource_dict(report, registry_items, resources, "factions", faction_id, f"economy.per_category_income.{category}", "faction_income")
    for town_id, town in towns.items():
        economy = town.get("economy", {})
        if isinstance(economy, dict):
            record_economy_resource_dict(report, registry_items, economy.get("base_income", {}), "towns", town_id, "economy.base_income", "town_income", "town_income")
            for category, resources in economy.get("per_category_income", {}).items() if isinstance(economy.get("per_category_income", {}), dict) else []:
                record_economy_resource_dict(report, registry_items, resources, "towns", town_id, f"economy.per_category_income.{category}", "town_income", "town_income")
    for site_id, site in resource_sites.items():
        record_economy_resource_dict(report, registry_items, site.get("rewards", {}), "resource_sites", site_id, "rewards", "site_rewards", "pickups" if not bool(site.get("persistent_control", False)) else "persistent_sites")
        record_economy_resource_dict(report, registry_items, site.get("claim_rewards", {}), "resource_sites", site_id, "claim_rewards", "site_rewards", "persistent_sites" if bool(site.get("persistent_control", False)) else "pickups")
        record_economy_resource_dict(report, registry_items, site.get("control_income", {}), "resource_sites", site_id, "control_income", "site_income", "persistent_sites")
        record_economy_resource_dict(report, registry_items, site.get("service_cost", {}), "resource_sites", site_id, "service_cost", "service_cost", "repeatable_services")
        staged_outputs = site.get("staged_resource_outputs", [])
        if isinstance(staged_outputs, list) and staged_outputs:
            front_entry = {
                "site_id": site_id,
                "family": str(site.get("family", "")),
                "content_batch_id": str(site.get("content_batch_id", "")),
                "outputs": [],
                "live_reward_fields_clear": not any(
                    isinstance(site.get(field, {}), dict)
                    and set(str(resource_id) for resource_id in site.get(field, {}).keys()).intersection(ECONOMY_RARE_RESOURCE_IDS)
                    for field in ("rewards", "claim_rewards", "control_income", "service_cost")
                ),
                "response_cost_clear": True,
                "warnings": [],
            }
            response_cost = site.get("response_profile", {}).get("resource_cost", {}) if isinstance(site.get("response_profile", {}), dict) else {}
            if isinstance(response_cost, dict) and set(str(resource_id) for resource_id in response_cost.keys()).intersection(ECONOMY_RARE_RESOURCE_IDS):
                front_entry["response_cost_clear"] = False
                front_entry["warnings"].append("staged rare-resource front uses a rare id in response_profile.resource_cost")
            for output in staged_outputs:
                if not isinstance(output, dict):
                    front_entry["warnings"].append("staged_resource_outputs contains a non-dict output")
                    continue
                resource_id = str(output.get("resource_id", ""))
                front_entry["outputs"].append(
                    {
                        "resource_id": resource_id,
                        "activation_status": str(output.get("activation_status", "")),
                        "report_only": bool(output.get("report_only", False)),
                        "live_reward": bool(output.get("live_reward", True)),
                        "planned_amount": int(output.get("planned_amount", 0)),
                    }
                )
                if resource_id not in ECONOMY_RARE_RESOURCE_IDS:
                    front_entry["warnings"].append(f"staged_resource_outputs uses unsupported rare resource {resource_id}")
                if str(output.get("activation_status", "")) != "staged_report_only" or not bool(output.get("report_only", False)) or bool(output.get("live_reward", True)):
                    front_entry["warnings"].append(f"staged output {resource_id} is not report-only")
            for warning in front_entry["warnings"]:
                add_economy_report_warning(report, f"{site_id}: {warning}")
            report["staged_resource_fronts"][site_id] = front_entry
        if isinstance(site.get("response_profile", {}), dict):
            record_economy_resource_dict(report, registry_items, site.get("response_profile", {}).get("resource_cost", {}), "resource_sites", site_id, "response_profile.resource_cost", "service_cost", "repeatable_services")
        infer_economy_site_cadence(report, registry_items, site_id, site)
        infer_economy_capture_report(report, registry_items, site_id, site)
    for scenario_id, scenario in scenarios.items():
        record_economy_resource_dict(report, registry_items, scenario.get("starting_resources", {}), "scenarios", scenario_id, "starting_resources", "scenario_starting_resources", "scenario_grants")
        for hook in scenario.get("script_hooks", []):
            if isinstance(hook, dict):
                hook_id = str(hook.get("id", "unknown_hook"))
                for effect in hook.get("effects", []):
                    if isinstance(effect, dict) and str(effect.get("type", "")) == "add_resources":
                        record_economy_resource_dict(report, registry_items, effect.get("resources", {}), "scenarios", scenario_id, f"script_hooks.{hook_id}.add_resources", "scenario_script_grants", "scenario_grants")
    for campaign_id, campaign in campaigns.items():
        for scenario_entry in campaign.get("scenarios", []):
            if isinstance(scenario_entry, dict) and bool(scenario_entry.get("carryover_export", {}).get("resources", False)):
                report["usage"]["gold"]["used_by"]["campaign_rewards"] += 1
                append_unique(report["usage"]["gold"]["source_paths"]["scenario_grants"], f"campaigns:{campaign_id}:carryover_export.resources")
    for market_resource_id in ("wood", "ore"):
        report["usage"][market_resource_id]["used_by"]["market_rules"] += 1
        append_unique(report["usage"][market_resource_id]["source_paths"]["market_profiles"], "legacy_common_exchange")
    report["market_caps"]["legacy_common_exchange"] = {"market_profile_id": "legacy_common_exchange", "source": "inferred_from_current_town_market_code", "buy_resources": ["wood", "ore"], "sell_resources": ["wood", "ore"], "buy_caps_present": False, "sell_caps_present": False, "refresh_cadence_present": False, "rare_resource_buying_enabled": False, "warnings": ["legacy market has no serialized weekly caps", "legacy market is common-resource only", "legacy market code is hardcoded to wood/ore"]}
    legacy_market_resources = set(report["market_caps"]["legacy_common_exchange"]["buy_resources"]) | set(report["market_caps"]["legacy_common_exchange"]["sell_resources"])
    if legacy_market_resources.intersection(ECONOMY_RARE_RESOURCE_IDS):
        warning = "legacy normal market exposes rare-resource exchange before caps and save state"
        report["market_caps"]["legacy_common_exchange"]["warnings"].append(warning)
        report["errors"].append(warning)
    for warning in report["market_caps"]["legacy_common_exchange"]["warnings"]:
        add_economy_report_warning(report, warning)
    if report["usage"]["experience"]["occurrences"]:
        append_unique(report["usage"]["experience"]["warnings"], "experience is a non-stockpile progression reward and must stay outside normal markets")
    finalize_economy_resource_availability(report, registry_items)
    report["sources"] = {resource_id: {"resource_id": resource_id, "display_name": entry["display_name"], "stockpile": entry["stockpile"], "used_by": entry["used_by"], "source_paths": entry["source_paths"], "availability": entry["availability"], "warnings": entry["warnings"]} for resource_id, entry in sorted(report["usage"].items())}
    for resource_id in ECONOMY_STAGED_RARE_RESOURCE_IDS:
        report["rare_resources"][resource_id] = economy_rare_resource_report_entry(resource_id, registry_items, report["usage"].get(resource_id, economy_report_resource_entry(resource_id, registry_items)))
    report["ui_report"] = {
        "resource_rows": [
            {
                "resource_id": resource_id,
                "display_name": resource_display_name(resource_id, registry_items),
                "category": str(registry_items.get(resource_id, {}).get("category", "")),
                "ui_sort": int(registry_items.get(resource_id, {}).get("ui_sort", 0)),
                "default_visible": bool(registry_items.get(resource_id, {}).get("default_visible", False)),
                "report_visible": bool(registry_items.get(resource_id, {}).get("report_only", False)) or bool(registry_items.get(resource_id, {}).get("default_visible", False)),
                "icon_hint_id": str(registry_items.get(resource_id, {}).get("icon_hint_id", "")),
                "material_cue": str(registry_items.get(resource_id, {}).get("material_cue", "")),
                "activation_status": str(registry_items.get(resource_id, {}).get("activation_status", "live" if resource_id in ECONOMY_LIVE_STOCKPILE_RESOURCE_IDS else "")),
            }
            for resource_id in sorted(ECONOMY_REPORT_RESOURCE_IDS, key=lambda rid: int(registry_items.get(rid, {}).get("ui_sort", 999)))
            if resource_id in registry_items
        ],
        "scenic_screen_rule": "report_only_no_runtime_screen_expansion",
    }
    return report


def validate_economy_wood_canonical_policy(errors: list[str]) -> None:
    report = build_economy_resource_report()
    policy = report.get("registry_policy", {})
    adapters = report.get("compatibility_adapters", {})
    old_save = report.get("old_save_compatibility", {})
    alias_pairs = report.get("registry", {}).get("alias_pairs", [])
    session_store_text = (ROOT / "scripts/core/SessionStateStore.gd").read_text(encoding="utf-8")
    autoload_session_text = (ROOT / "scripts/autoload/SessionState.gd").read_text(encoding="utf-8")

    ensure(str(policy.get("decision", "")) == "keep_wood_as_live_authored_and_save_id", errors, "Economy resource policy must keep wood as the live authored/save id")
    ensure(policy.get("live_stockpile_resource_ids", []) == list(ECONOMY_LIVE_STOCKPILE_RESOURCE_IDS), errors, "Economy resource policy must keep live stockpile ids as gold, wood, and ore")
    ensure(policy.get("target_only_resource_ids", []) == [], errors, "Economy resource policy must not define target-only resource ids")
    ensure(bool(policy.get("production_content_migration", True)) is False, errors, "Economy resource policy must not enable production content migration")
    ensure(bool(policy.get("save_rewrite", True)) is False, errors, "Economy resource policy must not rewrite saves")
    ensure(bool(policy.get("save_version_bump", True)) is False, errors, "Economy resource policy must not require a save-version bump")
    ensure(str(policy.get("rare_resource_activation", "")) == "staged_report_only", errors, "Economy resource policy must stage rare resources as report-only")
    ensure(bool(policy.get("live_rare_resource_activation", True)) is False, errors, "Economy resource policy must not activate rare resources in live rules")
    ensure(str(adapters.get("runtime_adoption", "")) == "not_needed", errors, "Economy resource policy must not require a compatibility adapter")
    ensure(adapters.get("target_resource_ids", []) == [], errors, "Economy resource policy must not expose target resource ids")
    ensure(bool(adapters.get("save_rewrite", True)) is False, errors, "Economy compatibility adapter must not rewrite saves")
    ensure(alias_pairs == [], errors, "Economy resource policy must not report resource alias pairs")
    ensure(report.get("usage", {}).get("wood", {}).get("availability", "") == "available", errors, "Economy resource report must keep wood available")
    ensure(report.get("usage", {}).get("experience", {}).get("availability", "") == "non_stockpile_reward", errors, "Economy compatibility report must keep experience outside stockpiles")
    ensure(bool(old_save.get("resource_schema_version_required", True)) is False, errors, "Old-save resource compatibility must not require resource_schema_version")
    ensure(bool(old_save.get("accepted_without_resource_schema_version", False)), errors, "Old-save resource fixture must prove saves without resource_schema_version are accepted")
    ensure(bool(old_save.get("wood_preserved_in_old_save_fixture", False)), errors, "Old-save resource fixture must preserve wood")
    ensure(old_save.get("target_only_resource_ids", []) == [], errors, "Old-save resource fixture must not report target-only resource ids")
    ensure("const SAVE_VERSION := 9" in session_store_text, errors, "Wood canonical cleanup must preserve SessionStateStore SAVE_VERSION 9")
    ensure("const SAVE_VERSION := 9" in autoload_session_text, errors, "Wood canonical cleanup must preserve autoload SessionState SAVE_VERSION 9")


def validate_economy_rare_resource_activation_policy(errors: list[str]) -> None:
    report = build_economy_resource_report()
    registry_items = economy_registry_items(load_economy_resource_registry())
    policy = report.get("registry_policy", {})
    rare_resources = report.get("rare_resources", {})
    ui_rows = {
        str(row.get("resource_id", "")): row
        for row in report.get("ui_report", {}).get("resource_rows", [])
        if isinstance(row, dict)
    }
    session_store_text = SESSION_STATE_STORE_PATH.read_text(encoding="utf-8")
    autoload_session_text = SESSION_STATE_PATH.read_text(encoding="utf-8")

    ensure(policy.get("staged_limited_resource_ids", []) == list(ECONOMY_STAGED_RARE_RESOURCE_IDS), errors, "Rare-resource policy must expose the selected staged rare ids in order")
    ensure(str(policy.get("rare_resource_activation", "")) == "staged_report_only", errors, "Rare-resource activation must stay staged/report-only")
    ensure(bool(policy.get("live_rare_resource_activation", True)) is False, errors, "Rare resources must not be activated in live rules")
    ensure(report.get("activation_gates", {}).get("market", "") == "normal_market_rare_buying_disabled", errors, "Rare-resource gates must keep normal market buying disabled")
    ensure(report.get("activation_gates", {}).get("save_compatibility", "") == "old_saves_accept_absent_rare_resources_without_version_bump", errors, "Rare-resource gates must preserve old-save compatibility")
    ensure(report.get("market_caps", {}).get("legacy_common_exchange", {}).get("rare_resource_buying_enabled", True) is False, errors, "Legacy normal market must not buy rare resources")
    ensure(not set(report.get("market_caps", {}).get("legacy_common_exchange", {}).get("buy_resources", [])).intersection(ECONOMY_RARE_RESOURCE_IDS), errors, "Legacy normal market buy list must not contain rare resources")
    ensure(not set(report.get("market_caps", {}).get("legacy_common_exchange", {}).get("sell_resources", [])).intersection(ECONOMY_RARE_RESOURCE_IDS), errors, "Legacy normal market sell list must not contain rare resources")
    ensure("const SAVE_VERSION := 9" in session_store_text, errors, "Rare-resource staging must preserve SessionStateStore SAVE_VERSION 9")
    ensure("const SAVE_VERSION := 9" in autoload_session_text, errors, "Rare-resource staging must preserve autoload SessionState SAVE_VERSION 9")

    for resource_id in ECONOMY_STAGED_RARE_RESOURCE_IDS:
        item = registry_items.get(resource_id, {})
        usage = report.get("usage", {}).get(resource_id, {})
        rare = rare_resources.get(resource_id, {})
        row = ui_rows.get(resource_id, {})
        ensure(bool(item), errors, f"Rare resource {resource_id} must be present in the report registry")
        ensure(bool(item.get("stockpile", False)), errors, f"Rare resource {resource_id} must be staged as a future stockpile resource")
        ensure(str(item.get("canonical_status", "")) == "staged_limited", errors, f"Rare resource {resource_id} must use staged_limited canonical status")
        ensure(str(item.get("activation_status", "")) == "staged_report_only", errors, f"Rare resource {resource_id} must stay report-only")
        ensure(bool(item.get("report_only", False)), errors, f"Rare resource {resource_id} must be marked report_only")
        ensure(bool(item.get("source_site_family", "")), errors, f"Rare resource {resource_id} must name a planned source-site family")
        ensure(bool(item.get("icon_hint_id", "")), errors, f"Rare resource {resource_id} must expose an icon hint for future UI work")
        ensure(bool(item.get("material_cue", "")), errors, f"Rare resource {resource_id} must expose a material cue")
        ensure(str(usage.get("availability", "")) == "registry_only", errors, f"Rare resource {resource_id} must not have live production usage yet")
        ensure(len(usage.get("occurrences", [])) == 0, errors, f"Rare resource {resource_id} must not appear in live costs, rewards, starts, grants, or income yet")
        ensure(rare.get("production_occurrences", -1) == 0, errors, f"Rare resource {resource_id} report must show zero production occurrences")
        ensure(rare.get("normal_market_buying_enabled", True) is False, errors, f"Rare resource {resource_id} must not be normal-market buyable")
        ensure(row.get("report_visible", False) is True, errors, f"Rare resource {resource_id} must be visible in report/UI rows")


def print_economy_resource_report(report: dict) -> None:
    print("ECONOMY RESOURCE REPORT")
    print(f"- schema: {report['schema']}")
    print(f"- mode: {report['mode']}")
    print(f"- stockpile resources: {', '.join(report['registry']['stockpile_resource_ids'])}")
    print(f"- non-stockpile rewards: {', '.join(report['registry']['non_stockpile_reward_ids'])}")
    policy = report.get("registry_policy", {})
    print("Registry policy:")
    print(f"- policy: {policy.get('policy_id', '')}; mode={policy.get('mode', '')}")
    print(f"- decision: {policy.get('decision', '')}")
    print(f"- live ids: {', '.join(policy.get('live_stockpile_resource_ids', []))}; target-only ids: {', '.join(policy.get('target_only_resource_ids', []))}")
    print(f"- migration={policy.get('production_content_migration', False)}; save_version_bump={policy.get('save_version_bump', False)}; rare_activation={policy.get('rare_resource_activation', False)}")
    old_save = report.get("old_save_compatibility", {})
    print("Old-save compatibility:")
    print(f"- resource_schema_version_required={old_save.get('resource_schema_version_required', True)}; accepted_without_schema={old_save.get('accepted_without_resource_schema_version', False)}; wood_preserved={old_save.get('wood_preserved_in_old_save_fixture', False)}")
    print("Resource usage:")
    for resource_id in sorted(report["usage"].keys()):
        entry = report["usage"][resource_id]
        total = len(entry.get("occurrences", []))
        if total == 0 and resource_id not in ECONOMY_REPORT_RESOURCE_IDS:
            continue
        print(f"- {resource_id} ({entry['display_name']}): {entry['availability']}, occurrences={total}, stockpile={entry['stockpile']}")
    print("Cadence inference:")
    cadence_counts: dict[str, int] = {}
    for site in report["cadence"].values():
        for output in site.get("inferred_outputs", []):
            cadence = str(output.get("cadence", "unknown"))
            cadence_counts[cadence] = cadence_counts.get(cadence, 0) + 1
    for cadence, count in sorted(cadence_counts.items()):
        print(f"- {cadence}: {count}")
    capture_warning_count = sum(len(item.get("warnings", [])) for item in report["capture"].values())
    print("Capture warnings:")
    print(f"- persistent sites reviewed: {len(report['capture'])}; warnings={capture_warning_count}")
    print("Market cap stance:")
    for market in report["market_caps"].values():
        print(f"- {market['market_profile_id']}: common={','.join(market['buy_resources'])}; rare_buying={market['rare_resource_buying_enabled']}; caps={market['buy_caps_present']}")
    print("Staged rare resources:")
    for resource_id in ECONOMY_STAGED_RARE_RESOURCE_IDS:
        rare = report.get("rare_resources", {}).get(resource_id, {})
        print(
            f"- {resource_id} ({rare.get('display_name', resource_display_name(resource_id))}): "
            f"category={rare.get('category', '')}; source={rare.get('source_site_family', '')}; "
            f"activation={rare.get('activation_status', '')}; production_occurrences={rare.get('production_occurrences', 0)}; "
            f"normal_market_buying={rare.get('normal_market_buying_enabled', False)}"
        )
    staged_fronts = report.get("staged_resource_fronts", {})
    staged_front_resource_ids = sorted(
        {
            str(output.get("resource_id", ""))
            for front in staged_fronts.values()
            for output in front.get("outputs", [])
            if str(output.get("resource_id", ""))
        }
    )
    print("Staged rare-resource fronts:")
    print(f"- fronts={len(staged_fronts)}; resources={','.join(staged_front_resource_ids)}")
    print("Compatibility adapters:")
    print(f"- runtime adoption: {report['compatibility_adapters']['runtime_adoption']}; save rewrite={report['compatibility_adapters']['save_rewrite']}")
    print(f"Warnings: {len(report['warnings'])}; Errors: {len(report['errors'])}")


def validate_strict_economy_resource_fixtures() -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    ensure(ECONOMY_RESOURCE_REGISTRY_FIXTURE_PATH.exists(), errors, f"Missing strict economy fixture: {ECONOMY_RESOURCE_REGISTRY_FIXTURE_PATH.relative_to(ROOT)}")
    ensure(ECONOMY_RESOURCE_STRICT_CASES_PATH.exists(), errors, f"Missing strict economy fixture: {ECONOMY_RESOURCE_STRICT_CASES_PATH.relative_to(ROOT)}")
    if errors:
        return errors, warnings
    registry = load_json(ECONOMY_RESOURCE_REGISTRY_FIXTURE_PATH)
    cases = load_json(ECONOMY_RESOURCE_STRICT_CASES_PATH)
    registry_items = economy_registry_items(registry)
    required_registry_fields = {"id", "display_name", "category", "market_tier", "default_visible", "legacy_aliases", "ui_sort", "stockpile"}
    for resource_id, item in registry_items.items():
        missing = sorted([field for field in required_registry_fields if field not in item])
        if missing:
            fail(errors, f"Strict registry resource {resource_id} is missing required fields: {', '.join(missing)}")
        if resource_id == "experience" and bool(item.get("stockpile", True)):
            fail(errors, "Strict registry must keep experience as a non-stockpile reward")
        if resource_id == "wood":
            ensure(str(item.get("canonical_status", "")) == "canonical_live_id", errors, "Strict registry must mark wood as the canonical live id")
            ensure("canonical_target_id" not in item, errors, "Strict registry must not define a target id for wood")
            ensure("target_aliases" not in item or item.get("target_aliases", []) == [], errors, "Strict registry must not define target aliases for wood")
        if resource_id in ECONOMY_RARE_RESOURCE_IDS:
            ensure(str(item.get("canonical_status", "")) == "staged_limited", errors, f"Strict registry must mark rare resource {resource_id} as staged_limited")
            ensure(str(item.get("activation_status", "")) == "staged_report_only", errors, f"Strict registry must keep rare resource {resource_id} report-only")
            ensure(bool(item.get("report_only", False)), errors, f"Strict registry must mark rare resource {resource_id} report_only")
            ensure(str(item.get("market_tier", "")) == "restricted_rare", errors, f"Strict registry must keep rare resource {resource_id} out of normal common markets")
            ensure(bool(item.get("source_site_family", "")), errors, f"Strict registry rare resource {resource_id} must name source_site_family")

    def strict_resource_dict_errors(label: str, resources: object, stockpile_payload: bool = True) -> list[str]:
        local_errors: list[str] = []
        if not isinstance(resources, dict) or not resources:
            local_errors.append(f"{label} must define a non-empty resource dictionary")
            return local_errors
        for resource_id, amount in resources.items():
            rid = str(resource_id)
            try:
                parsed_amount = int(amount)
            except (TypeError, ValueError):
                parsed_amount = 0
            if rid not in registry_items:
                local_errors.append(f"{label} uses unknown resource id {rid}")
            if stockpile_payload and rid == "experience" and parsed_amount > 0:
                local_errors.append(f"{label} treats experience as a stockpile resource")
            if stockpile_payload and rid in ECONOMY_TARGET_ONLY_RESOURCE_IDS and parsed_amount > 0:
                local_errors.append(f"{label} uses target-only resource id {rid} before a save-aware migration")
            if parsed_amount < 0:
                local_errors.append(f"{label} has negative amount for {rid}")
        return local_errors

    valid = cases.get("valid", {})
    for entry in valid.get("resource_dicts", []):
        errors.extend(strict_resource_dict_errors(str(entry.get("id", "valid_resource_dict")), entry.get("resources", {}), bool(entry.get("stockpile", True))))
    for site in valid.get("sites", []):
        site_id = str(site.get("id", "valid_site"))
        for field in ("rewards", "claim_rewards", "control_income", "service_cost"):
            if field in site:
                errors.extend(strict_resource_dict_errors(f"{site_id}.{field}", site.get(field, {}), True))
        for output in site.get("resource_outputs", []):
            if not isinstance(output, dict):
                fail(errors, f"{site_id}.resource_outputs contains a non-dict output")
                continue
            output_resource_id = str(output.get("resource_id", ""))
            ensure(output_resource_id in registry_items, errors, f"{site_id}.resource_outputs references unknown resource {output_resource_id}")
            if output_resource_id in ECONOMY_RARE_RESOURCE_IDS:
                ensure(bool(site.get("guarded", False)) or isinstance(site.get("guard_profile", {}), dict) and bool(site.get("guard_profile", {})), errors, f"{site_id} rare-resource source fixture must be guarded or guard-profiled")
                ensure(isinstance(site.get("capture_profile", {}), dict) and bool(site.get("capture_profile", {})), errors, f"{site_id} rare-resource source fixture must define capture_profile")
        if bool(site.get("persistent_control", False)) and isinstance(site.get("control_income", {}), dict) and site.get("control_income", {}):
            if bool(site.get("expect_capture_warning", False)):
                if "capture_profile" in site:
                    fail(errors, f"{site_id} expected capture warning but defines capture_profile")
                warnings.append(f"{site_id}: persistent fixture intentionally lacks capture_profile")
            else:
                ensure(isinstance(site.get("resource_outputs", []), list) and bool(site.get("resource_outputs", [])), errors, f"{site_id} must define resource_outputs in strict fixture mode")
                ensure(isinstance(site.get("capture_profile", {}), dict) and bool(site.get("capture_profile", {})), errors, f"{site_id} must define capture_profile in strict fixture mode")
                ensure("counter_capture_value" in site.get("capture_profile", {}), errors, f"{site_id} capture_profile must define counter_capture_value")
        if bool(site.get("repeatable", False)):
            ensure(int(site.get("visit_cooldown_days", 0)) > 0, errors, f"{site_id} repeatable service must define visit_cooldown_days > 0")
            ensure(not bool(site.get("control_income", {})), errors, f"{site_id} repeatable service must not masquerade as passive income")
    for profile in valid.get("market_profiles", []):
        profile_id = str(profile.get("id", "valid_market_profile"))
        for field in ("buy_caps", "sell_caps"):
            errors.extend(strict_resource_dict_errors(f"{profile_id}.{field}", profile.get(field, {}), True))
        ensure(str(profile.get("refresh_cadence", "")) == "weekly", errors, f"{profile_id} must declare weekly refresh cadence")
        if bool(profile.get("normal_market", True)):
            rare_buying = any(str(resource_id) in ECONOMY_RARE_RESOURCE_IDS and int(amount) > 0 for resource_id, amount in profile.get("buy_caps", {}).items()) if isinstance(profile.get("buy_caps", {}), dict) else False
            ensure(not rare_buying, errors, f"{profile_id} normal market must not buy rare resources")
        restricted = {str(value) for value in profile.get("restricted_buy_resource_ids", [])} if isinstance(profile.get("restricted_buy_resource_ids", []), list) else set()
        ensure(ECONOMY_RARE_RESOURCE_IDS.issubset(restricted), errors, f"{profile_id} must explicitly restrict all staged rare-resource buys")
    for profile in valid.get("faction_preferences", []):
        profile_id = str(profile.get("id", "valid_faction_preference"))
        ensure(str(profile.get("policy", "")) == "advisory", errors, f"{profile_id} must keep faction preferences advisory")
        for bucket in ("primary", "secondary", "awkward"):
            for resource_id in profile.get(bucket, []):
                ensure(str(resource_id) in registry_items, errors, f"{profile_id} references unknown preference resource {resource_id}")
    for payload in valid.get("save_payloads", []):
        payload_id = str(payload.get("id", "valid_save_payload"))
        resources = payload.get("resources", {})
        errors.extend(strict_resource_dict_errors(f"{payload_id}.resources", resources, True))
        ensure("resource_schema_version" not in payload or int(payload.get("resource_schema_version", 0)) >= 0, errors, f"{payload_id} resource_schema_version must remain optional and nonnegative")
        ensure("wood" in resources, errors, f"{payload_id} must preserve wood in old-save compatibility fixture")

    invalid = cases.get("invalid", {})
    for entry in invalid.get("resource_dicts", []):
        local_errors = strict_resource_dict_errors(str(entry.get("id", "invalid_resource_dict")), entry.get("resources", {}), bool(entry.get("stockpile", True)))
        if not local_errors:
            fail(errors, f"Strict invalid fixture {entry.get('id')} unexpectedly passed")
    for item in invalid.get("registry_items", []):
        missing = sorted([field for field in required_registry_fields if field not in item])
        if not missing:
            fail(errors, f"Strict invalid registry fixture {item.get('id')} unexpectedly passed")
    for profile in invalid.get("market_profiles", []):
        profile_id = str(profile.get("id", "invalid_market_profile"))
        buy_caps = profile.get("buy_caps", {})
        rare_buying = any(str(resource_id) in ECONOMY_RARE_RESOURCE_IDS and int(amount) > 0 for resource_id, amount in buy_caps.items()) if isinstance(buy_caps, dict) else False
        if not (bool(profile.get("normal_market", False)) and rare_buying):
            fail(errors, f"Strict invalid market fixture {profile_id} unexpectedly passed")
    return errors, warnings


def market_faction_cost_apply_discount(cost: object, discount_percent: int) -> dict[str, int]:
    discounted: dict[str, int] = {}
    if not isinstance(cost, dict):
        return discounted
    clamped_discount = max(0, min(75, int(discount_percent)))
    for resource_id, amount in cost.items():
        base_amount = max(0, int(amount))
        discounted[str(resource_id)] = ((base_amount * (100 - clamped_discount)) + 99) // 100
    return discounted


def market_faction_cost_discount_from_profile(profile: object, unit_id: str) -> int:
    if not isinstance(profile, dict):
        return 0
    discounts = profile.get("cost_discount_percent", {})
    if not isinstance(discounts, dict):
        return 0
    return max(0, int(discounts.get(unit_id, 0)))


def market_faction_cost_case(
    case_id: str,
    source: str,
    town_id: str,
    town: dict,
    faction_id: str,
    faction: dict,
    unit_id: str,
    unit: dict,
    building: dict | None = None,
) -> dict:
    town_discount = market_faction_cost_discount_from_profile(town.get("recruitment", {}), unit_id)
    faction_discount = market_faction_cost_discount_from_profile(faction.get("recruitment", {}), unit_id)
    building_discount = 0
    building_id = ""
    if isinstance(building, dict):
        building_id = str(building.get("id", ""))
        building_discount = market_faction_cost_discount_from_profile({"cost_discount_percent": building.get("recruitment_discount_percent", {})}, unit_id)
    total_discount = town_discount + faction_discount + building_discount
    base_cost = {str(key): max(0, int(value)) for key, value in unit.get("cost", {}).items()} if isinstance(unit.get("cost", {}), dict) else {}
    adjusted_cost = market_faction_cost_apply_discount(base_cost, total_discount)
    return {
        "case_id": case_id,
        "source": source,
        "town_id": town_id,
        "faction_id": faction_id,
        "unit_id": unit_id,
        "building_id": building_id,
        "discount_components": {
            "town": town_discount,
            "faction": faction_discount,
            "building": building_discount,
        },
        "total_discount_percent": total_discount,
        "base_cost": base_cost,
        "adjusted_cost": adjusted_cost,
        "resource_ids_preserved": sorted(base_cost.keys()) == sorted(adjusted_cost.keys()),
        "live_resource_ids_only": set(base_cost.keys()).issubset(ECONOMY_STOCKPILE_RESOURCE_IDS) and set(adjusted_cost.keys()).issubset(ECONOMY_STOCKPILE_RESOURCE_IDS),
        "rare_resource_ids_used": sorted((set(base_cost.keys()) | set(adjusted_cost.keys())).intersection(ECONOMY_RARE_RESOURCE_IDS)),
        "cost_reduced": sum(adjusted_cost.values()) < sum(base_cost.values()),
    }


def market_resource_abundance_score(faction_economy: object, town_economy: object, resource_id: str) -> int:
    score = 0
    faction_base = faction_economy.get("base_income", {}) if isinstance(faction_economy, dict) else {}
    town_base = town_economy.get("base_income", {}) if isinstance(town_economy, dict) else {}
    faction_categories = faction_economy.get("per_category_income", {}) if isinstance(faction_economy, dict) else {}
    town_categories = town_economy.get("per_category_income", {}) if isinstance(town_economy, dict) else {}
    faction_economy_bucket = faction_categories.get("economy", {}) if isinstance(faction_categories, dict) else {}
    town_economy_bucket = town_categories.get("economy", {}) if isinstance(town_categories, dict) else {}
    score += 1 if isinstance(faction_base, dict) and int(faction_base.get(resource_id, 0)) > 0 else 0
    score += 1 if isinstance(town_base, dict) and int(town_base.get(resource_id, 0)) > 0 else 0
    score += 1 if isinstance(faction_economy_bucket, dict) and int(faction_economy_bucket.get(resource_id, 0)) > 0 else 0
    score += 1 if isinstance(town_economy_bucket, dict) and int(town_economy_bucket.get(resource_id, 0)) > 0 else 0
    return score


def market_profile_for_building(building_id: str) -> tuple[str, int, str]:
    if building_id == "building_resonant_exchange":
        return "resonant", 2, "ore"
    if building_id == "building_river_granary_exchange":
        return "river", 2, "wood"
    if building_id == "building_market_square":
        return "square", 1, ""
    return "none", 0, ""


def market_faction_cost_market_case(town_id: str, town: dict, faction: dict, building_id: str) -> dict:
    profile_id, tier, bulk_resource = market_profile_for_building(building_id)
    buy_rates: dict[str, int] = {}
    sell_rates: dict[str, int] = {}
    for resource_id in ECONOMY_NORMAL_MARKET_RESOURCE_IDS:
        abundance = market_resource_abundance_score(faction.get("economy", {}), town.get("economy", {}), resource_id)
        buy_rate = 740 - (abundance * 35)
        sell_rate = 280 + (abundance * 30)
        if profile_id == "river":
            if resource_id == "wood":
                buy_rate -= 80
                sell_rate += 90
            else:
                buy_rate -= 25
                sell_rate += 25
        elif profile_id == "resonant":
            if resource_id == "ore":
                buy_rate -= 80
                sell_rate += 90
            else:
                buy_rate -= 25
                sell_rate += 25
        else:
            buy_rate -= 20
            sell_rate += 10
        buy_rate = max(500, min(760, buy_rate))
        sell_rate = max(260, min(max(260, buy_rate - 120), sell_rate))
        buy_rates[resource_id] = buy_rate
        sell_rates[resource_id] = sell_rate
    exchange_resources = sorted(set(buy_rates.keys()) | set(sell_rates.keys()))
    return {
        "town_id": town_id,
        "faction_id": str(town.get("faction_id", "")),
        "market_building_id": building_id,
        "profile": profile_id,
        "tier": tier,
        "buy_rates": buy_rates,
        "sell_rates": sell_rates,
        "bulk_resource": bulk_resource,
        "exchange_resources": exchange_resources,
        "rare_resource_buying_enabled": bool(set(buy_rates.keys()).intersection(ECONOMY_RARE_RESOURCE_IDS)),
        "normal_market_resource_ids_only": set(exchange_resources) == set(ECONOMY_NORMAL_MARKET_RESOURCE_IDS),
    }


def build_market_faction_cost_report() -> dict:
    payloads = {key: load_json(CONTENT_DIR / f"{key}.json") for key in ("factions", "towns", "buildings", "units")}
    factions = items_index(payloads["factions"])
    towns = items_index(payloads["towns"])
    buildings = items_index(payloads["buildings"])
    units = items_index(payloads["units"])
    strict_cases = load_json(ECONOMY_RESOURCE_STRICT_CASES_PATH) if ECONOMY_RESOURCE_STRICT_CASES_PATH.exists() else {}
    report = {
        "schema": MARKET_FACTION_COST_REPORT_SCHEMA,
        "generated_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        "mode": "bounded_live_hook_report",
        "policy": {
            "live_stockpile_resource_ids": list(ECONOMY_LIVE_STOCKPILE_RESOURCE_IDS),
            "normal_market_resource_ids": list(ECONOMY_NORMAL_MARKET_RESOURCE_IDS),
            "rare_resource_activation": "staged_report_only",
            "normal_market_rare_buying_enabled": False,
            "runtime_market_cap_adoption": False,
            "market_cap_support": "strict_fixture_and_report_only_until weekly state, UI, AI, and save semantics are selected",
            "faction_cost_hook": "live recruitment discounts from faction, town, and building profiles",
            "save_version_bump": False,
            "broad_rebalance": False,
        },
        "market_cases": [],
        "market_cap_fixtures": [],
        "faction_cost_cases": [],
        "warnings": [],
        "errors": [],
    }
    seen_market_profiles: set[str] = set()
    for town_id, town in towns.items():
        faction_id = str(town.get("faction_id", ""))
        faction = factions.get(faction_id, {})
        buildable_ids = [str(value) for value in town.get("buildable_building_ids", []) if str(value) in buildings]
        for building_id in ("building_market_square", "building_river_granary_exchange", "building_resonant_exchange"):
            if building_id not in buildable_ids or building_id in seen_market_profiles:
                continue
            profile_id, _, _ = market_profile_for_building(building_id)
            if profile_id == "none":
                continue
            report["market_cases"].append(market_faction_cost_market_case(town_id, town, faction, building_id))
            seen_market_profiles.add(building_id)
    valid_cases = strict_cases.get("valid", {}) if isinstance(strict_cases, dict) else {}
    for profile in valid_cases.get("market_profiles", []) if isinstance(valid_cases.get("market_profiles", []), list) else []:
        if not isinstance(profile, dict):
            continue
        buy_caps = profile.get("buy_caps", {}) if isinstance(profile.get("buy_caps", {}), dict) else {}
        sell_caps = profile.get("sell_caps", {}) if isinstance(profile.get("sell_caps", {}), dict) else {}
        restricted = [str(value) for value in profile.get("restricted_buy_resource_ids", [])] if isinstance(profile.get("restricted_buy_resource_ids", []), list) else []
        report["market_cap_fixtures"].append(
            {
                "profile_id": str(profile.get("id", "")),
                "normal_market": bool(profile.get("normal_market", True)),
                "refresh_cadence": str(profile.get("refresh_cadence", "")),
                "buy_caps": {str(key): int(value) for key, value in buy_caps.items()},
                "sell_caps": {str(key): int(value) for key, value in sell_caps.items()},
                "restricted_buy_resource_ids": restricted,
                "rare_resource_buying_enabled": bool(set(buy_caps.keys()).intersection(ECONOMY_RARE_RESOURCE_IDS)),
            }
        )
    for town_id, town in towns.items():
        faction_id = str(town.get("faction_id", ""))
        faction = factions.get(faction_id, {})
        faction_discounts = faction.get("recruitment", {}).get("cost_discount_percent", {}) if isinstance(faction.get("recruitment", {}), dict) else {}
        town_discounts = town.get("recruitment", {}).get("cost_discount_percent", {}) if isinstance(town.get("recruitment", {}), dict) else {}
        for unit_id in sorted(faction_discounts.keys()):
            unit = units.get(str(unit_id), {})
            if unit:
                report["faction_cost_cases"].append(market_faction_cost_case(f"{town_id}_{unit_id}_faction", "faction_profile", town_id, town, faction_id, faction, str(unit_id), unit))
                break
        for unit_id in sorted(town_discounts.keys()):
            unit = units.get(str(unit_id), {})
            if unit:
                report["faction_cost_cases"].append(market_faction_cost_case(f"{town_id}_{unit_id}_town", "town_profile", town_id, town, faction_id, faction, str(unit_id), unit))
                break
        for building_id in town.get("buildable_building_ids", []):
            building = buildings.get(str(building_id), {})
            discounts = building.get("recruitment_discount_percent", {}) if isinstance(building, dict) else {}
            if not isinstance(discounts, dict) or not discounts:
                continue
            unit_id = sorted(discounts.keys())[0]
            unit = units.get(str(unit_id), {})
            if unit:
                report["faction_cost_cases"].append(market_faction_cost_case(f"{town_id}_{building_id}_{unit_id}_building", "building_profile", town_id, town, faction_id, faction, str(unit_id), unit, building))
                break
    return report


def validate_market_faction_cost_policy(errors: list[str]) -> None:
    report = build_market_faction_cost_report()
    policy = report.get("policy", {})
    session_store_text = SESSION_STATE_STORE_PATH.read_text(encoding="utf-8")
    autoload_session_text = SESSION_STATE_PATH.read_text(encoding="utf-8")
    overworld_rules_text = OVERWORLD_RULES_PATH.read_text(encoding="utf-8")

    ensure(report.get("schema", "") == MARKET_FACTION_COST_REPORT_SCHEMA, errors, "Market/faction-cost report must use the selected schema")
    ensure(policy.get("live_stockpile_resource_ids", []) == list(ECONOMY_LIVE_STOCKPILE_RESOURCE_IDS), errors, "Market/faction-cost policy must keep live stockpile ids as gold, wood, and ore")
    ensure(policy.get("normal_market_resource_ids", []) == list(ECONOMY_NORMAL_MARKET_RESOURCE_IDS), errors, "Normal market must remain bounded to wood and ore")
    ensure(bool(policy.get("normal_market_rare_buying_enabled", True)) is False, errors, "Normal market must not buy staged rare resources")
    ensure(str(policy.get("rare_resource_activation", "")) == "staged_report_only", errors, "Market/faction-cost slice must keep rare resources report-only")
    ensure(bool(policy.get("save_version_bump", True)) is False, errors, "Market/faction-cost slice must not require a save-version bump")
    ensure(bool(policy.get("broad_rebalance", True)) is False, errors, "Market/faction-cost slice must not perform a broad rebalance")
    ensure("const SAVE_VERSION := 9" in session_store_text, errors, "Market/faction-cost slice must preserve SessionStateStore SAVE_VERSION 9")
    ensure("const SAVE_VERSION := 9" in autoload_session_text, errors, "Market/faction-cost slice must preserve autoload SessionState SAVE_VERSION 9")
    ensure('for resource_key in ["wood", "ore"]' in overworld_rules_text, errors, "Town market rules must stay visibly bounded to wood and ore")
    ensure("static func town_recruit_cost" in overworld_rules_text and "_recruitment_discount_percent" in overworld_rules_text, errors, "Town recruit costs must still apply faction/town/building discount hooks")

    market_cases = report.get("market_cases", [])
    ensure(bool(market_cases), errors, "Market/faction-cost report must include at least one live market case")
    for case in market_cases:
        case_id = f"{case.get('town_id', '')}:{case.get('market_building_id', '')}"
        ensure(case.get("normal_market_resource_ids_only", False) is True, errors, f"{case_id} market case must exchange only wood and ore")
        ensure(case.get("rare_resource_buying_enabled", True) is False, errors, f"{case_id} market case must not buy rare resources")
    cap_fixtures = report.get("market_cap_fixtures", [])
    ensure(bool(cap_fixtures), errors, "Market/faction-cost report must include a bounded common-market cap fixture")
    for fixture in cap_fixtures:
        fixture_id = str(fixture.get("profile_id", "market_cap_fixture"))
        ensure(str(fixture.get("refresh_cadence", "")) == "weekly", errors, f"{fixture_id} must keep weekly market cap cadence")
        ensure(set(fixture.get("buy_caps", {}).keys()).issubset(set(ECONOMY_NORMAL_MARKET_RESOURCE_IDS)), errors, f"{fixture_id} buy caps must stay common-only")
        ensure(set(fixture.get("sell_caps", {}).keys()).issubset(set(ECONOMY_NORMAL_MARKET_RESOURCE_IDS)), errors, f"{fixture_id} sell caps must stay common-only")
        ensure(fixture.get("rare_resource_buying_enabled", True) is False, errors, f"{fixture_id} must not enable rare-resource buying")
        ensure(ECONOMY_RARE_RESOURCE_IDS.issubset(set(fixture.get("restricted_buy_resource_ids", []))), errors, f"{fixture_id} must explicitly restrict all staged rare-resource buys")

    cost_cases = report.get("faction_cost_cases", [])
    ensure(len(cost_cases) >= 2, errors, "Market/faction-cost report must include multiple faction-biased cost cases")
    ensure(any(str(case.get("source", "")) == "faction_profile" and int(case.get("discount_components", {}).get("faction", 0)) > 0 for case in cost_cases), errors, "Faction cost report must prove an authored faction discount affects a live cost")
    ensure(any(str(case.get("source", "")) == "town_profile" and int(case.get("discount_components", {}).get("town", 0)) > 0 for case in cost_cases), errors, "Faction cost report must prove an authored town discount affects a live cost")
    ensure(any(str(case.get("source", "")) == "building_profile" and int(case.get("discount_components", {}).get("building", 0)) > 0 for case in cost_cases), errors, "Faction cost report must prove an authored building discount affects a live cost")
    for case in cost_cases:
        case_id = str(case.get("case_id", "cost_case"))
        ensure(case.get("cost_reduced", False) is True, errors, f"{case_id} must reduce the base cost")
        ensure(case.get("resource_ids_preserved", False) is True, errors, f"{case_id} must preserve resource ids rather than creating hidden grants")
        ensure(case.get("live_resource_ids_only", False) is True, errors, f"{case_id} must use only live stockpile resources")
        ensure(case.get("rare_resource_ids_used", []) == [], errors, f"{case_id} must not use staged rare resources")


def validate_economy_capture_income_loop_expansion(errors: list[str]) -> None:
    ensure(ECONOMY_CAPTURE_INCOME_REPORT_SCRIPT_PATH.exists(), errors, "Economy capture/income expansion report script is missing")
    ensure(ECONOMY_CAPTURE_INCOME_REPORT_SCENE_PATH.exists(), errors, "Economy capture/income expansion report scene is missing")
    ensure(ECONOMY_CAPTURE_INCOME_REPORT_DOC_PATH.exists(), errors, "Economy capture/income expansion report doc is missing")
    if not ECONOMY_CAPTURE_INCOME_REPORT_SCRIPT_PATH.exists():
        return

    script_text = ECONOMY_CAPTURE_INCOME_REPORT_SCRIPT_PATH.read_text(encoding="utf-8")
    scene_text = ECONOMY_CAPTURE_INCOME_REPORT_SCENE_PATH.read_text(encoding="utf-8") if ECONOMY_CAPTURE_INCOME_REPORT_SCENE_PATH.exists() else ""
    doc_text = ECONOMY_CAPTURE_INCOME_REPORT_DOC_PATH.read_text(encoding="utf-8") if ECONOMY_CAPTURE_INCOME_REPORT_DOC_PATH.exists() else ""
    resource_sites = items_index(load_json(CONTENT_DIR / "resource_sites.json"))
    scenarios = items_index(load_json(CONTENT_DIR / "scenarios.json"))
    scenario = scenarios.get("glassroad-sundering", {})

    for required_token in (
        'const SCENARIO_ID := "glassroad-sundering"',
        'const RELAY_SITE := "glassroad_watch_relay"',
        'const LENS_HOUSE_SITE := "glassroad_lens_house"',
        'const STOCKPILE_KEYS := ["gold", "wood", "ore"]',
        "OverworldRules.collect_active_resource",
        "OverworldRules.end_turn",
        "OverworldRules.build_in_active_town",
        "OverworldRules.recruit_in_active_town",
        "SaveService.save_runtime_manual_session",
        "SaveService.restore_manual_session",
        "ECONOMY_CAPTURE_INCOME_EXPANSION_REPORT",
    ):
        ensure(required_token in script_text, errors, f"Economy capture/income expansion report is missing token {required_token}")
    ensure("res://tests/economy_capture_income_expansion_report.gd" in scene_text, errors, "Economy capture/income expansion scene must load its report script")
    ensure("rare resources remain staged/report-only" in doc_text.lower(), errors, "Economy capture/income expansion report must keep rare resources staged/report-only")
    ensure("`wood` remains canonical" in doc_text, errors, "Economy capture/income expansion report must record wood as canonical")
    ensure("No `SAVE_VERSION` bump" in doc_text, errors, "Economy capture/income expansion report must reject save-version bump scope")

    placement_ids = {
        str(node.get("placement_id", "")): str(node.get("site_id", ""))
        for node in scenario.get("resource_nodes", [])
        if isinstance(node, dict)
    }
    ensure(placement_ids.get("glassroad_watch_relay", "") == "site_prism_watch_relay", errors, "Glassroad relay proof must remain tied to site_prism_watch_relay")
    ensure(placement_ids.get("glassroad_lens_house", "") == "site_lens_house", errors, "Glassroad lens-house proof must remain tied to site_lens_house")
    ensure(placement_ids.get("glassroad_wood", "") == "site_wood_wagon", errors, "Glassroad proof must keep the current wood pickup")
    ensure(placement_ids.get("glassroad_ore", "") == "site_ore_crates", errors, "Glassroad proof must keep the current ore pickup")
    ensure(placement_ids.get("market_cache", "") == "site_waystone_cache", errors, "Glassroad proof must keep the current gold cache")

    relay = resource_sites.get("site_prism_watch_relay", {})
    lens_house = resource_sites.get("site_lens_house", {})
    ensure(relay.get("control_income", {}).get("gold", 0) == 25, errors, "Prism Watch Relay must keep 25 gold daily control income for the expansion proof")
    ensure(lens_house.get("control_income", {}).get("gold", 0) == 45, errors, "Lens House must keep 45 gold daily control income for the expansion proof")
    for site_id in ("site_prism_watch_relay", "site_lens_house", "site_wood_wagon", "site_ore_crates", "site_waystone_cache"):
        site = resource_sites.get(site_id, {})
        for field_name in ("rewards", "claim_rewards", "control_income", "service_cost"):
            payload = site.get(field_name, {})
            if isinstance(payload, dict):
                ensure(set(payload.keys()).issubset(set(ECONOMY_LIVE_STOCKPILE_RESOURCE_IDS) | {"experience"}), errors, f"{site_id}.{field_name} must stay within current resources for the expansion proof")


def print_market_faction_cost_report(report: dict) -> None:
    print("MARKET FACTION COST REPORT")
    print(f"- schema: {report['schema']}")
    print(f"- mode: {report['mode']}")
    policy = report.get("policy", {})
    print("Policy:")
    print(f"- live ids: {', '.join(policy.get('live_stockpile_resource_ids', []))}; normal market: {', '.join(policy.get('normal_market_resource_ids', []))}")
    print(f"- rare_activation={policy.get('rare_resource_activation', '')}; rare_market_buying={policy.get('normal_market_rare_buying_enabled', True)}; save_version_bump={policy.get('save_version_bump', True)}")
    print("Market cases:")
    for case in report.get("market_cases", []):
        print(
            f"- {case.get('town_id', '')}:{case.get('profile', '')} "
            f"buy={case.get('buy_rates', {})} sell={case.get('sell_rates', {})} "
            f"rare_buying={case.get('rare_resource_buying_enabled', True)}"
        )
    print("Market cap fixtures:")
    for fixture in report.get("market_cap_fixtures", []):
        print(f"- {fixture.get('profile_id', '')}: cadence={fixture.get('refresh_cadence', '')}; buy_caps={fixture.get('buy_caps', {})}; rare_buying={fixture.get('rare_resource_buying_enabled', True)}")
    print("Faction cost cases:")
    for case in report.get("faction_cost_cases", [])[:12]:
        print(
            f"- {case.get('case_id', '')}: source={case.get('source', '')}; "
            f"discount={case.get('total_discount_percent', 0)}%; "
            f"base={case.get('base_cost', {})}; adjusted={case.get('adjusted_cost', {})}; "
            f"rare={case.get('rare_resource_ids_used', [])}"
        )
    print(f"Warnings: {len(report['warnings'])}; Errors: {len(report['errors'])}")


def add_overworld_object_report_warning(report: dict, warning: str) -> None:
    if warning not in report["warnings"]:
        report["warnings"].append(warning)


def increment_count(bucket: dict, key: str, amount: int = 1) -> None:
    bucket[key] = int(bucket.get(key, 0)) + amount


def sorted_counts(bucket: dict) -> dict:
    return {key: bucket[key] for key in sorted(bucket.keys())}


def infer_overworld_object_primary_class(obj: dict, site: dict | None = None) -> str:
    family = str(obj.get("family", ""))
    if family in OVERWORLD_OBJECT_FAMILY_PRIMARY_CLASS:
        return OVERWORLD_OBJECT_FAMILY_PRIMARY_CLASS[family]
    if site:
        site_family = str(site.get("family", "one_shot_pickup"))
        if site_family == "one_shot_pickup":
            return "pickup"
        if site_family in OVERWORLD_OBJECT_FAMILY_PRIMARY_CLASS:
            return OVERWORLD_OBJECT_FAMILY_PRIMARY_CLASS[site_family]
    return "interactable_site" if bool(obj.get("visitable", False)) else "decoration"


def infer_overworld_object_secondary_tags(obj: dict, site: dict | None = None) -> list[str]:
    tags: set[str] = set()
    family = str(obj.get("family", ""))
    tags.update(OVERWORLD_OBJECT_FAMILY_TAGS.get(family, set()))
    roles = obj.get("map_roles", [])
    if isinstance(roles, list):
        for role in roles:
            role_key = str(role)
            if role_key:
                tags.add(role_key)
    if site:
        if bool(site.get("persistent_control", False)):
            tags.add("counter_capture_target")
        if bool(site.get("guarded", False)) or isinstance(site.get("guard_profile", {}), dict) and bool(site.get("guard_profile", {})):
            tags.add("guarded_reward")
        if isinstance(site.get("transit_profile", {}), dict) and bool(site.get("transit_profile", {})):
            tags.add("conditional_route")
            tags.add("road_control")
        if int(site.get("vision_radius", 0)) > 0:
            tags.add("sightline")
        if isinstance(site.get("neutral_roster", {}), dict) and bool(site.get("neutral_roster", {})):
            tags.add("neutral_recruit_source")
        if isinstance(site.get("town_support", {}), dict) and bool(site.get("town_support", {})):
            tags.add("town_support")
        if str(site.get("learn_spell_id", "")):
            tags.add("spell_access")
    return sorted(tags)


def infer_overworld_object_footprint_tier(footprint: dict) -> str:
    width = int(footprint.get("width", 0)) if isinstance(footprint, dict) else 0
    height = int(footprint.get("height", 0)) if isinstance(footprint, dict) else 0
    area = width * height
    if area <= 1:
        return "micro"
    if area <= 2:
        return "small"
    if area <= 4:
        return "medium"
    if area <= 6:
        return "large"
    return "region_feature"


def infer_overworld_object_passability_class(obj: dict) -> str:
    family = str(obj.get("family", ""))
    passable = bool(obj.get("passable", False))
    visitable = bool(obj.get("visitable", False))
    if family == "transit_object" and not passable and visitable:
        return "conditional_pass"
    if family == "blocker" and not passable:
        return "blocking_non_visitable" if not visitable else "edge_blocker"
    if passable and visitable:
        return "passable_visit_on_enter"
    if passable and not visitable:
        return "passable_scenic"
    if not passable and visitable:
        return "blocking_visitable"
    return "blocking_non_visitable"


def infer_overworld_object_interaction_cadence(obj: dict, site: dict | None = None) -> str:
    if not bool(obj.get("visitable", False)):
        return "none"
    if site is None:
        return "one_time" if bool(obj.get("visitable", False)) else "none"
    if isinstance(site.get("transit_profile", {}), dict) and bool(site.get("transit_profile", {})):
        return "conditional"
    if bool(site.get("persistent_control", False)):
        return "persistent_control"
    if bool(site.get("repeatable", False)):
        return "cooldown_days" if int(site.get("visit_cooldown_days", 0)) > 0 else "repeatable_weekly"
    if isinstance(site.get("weekly_recruits", {}), dict) and site.get("weekly_recruits", {}):
        return "repeatable_weekly"
    return "one_time"


def overworld_object_tile_key(tile: object) -> str:
    if not isinstance(tile, dict):
        return ""
    return f"{int(tile.get('x', -999))},{int(tile.get('y', -999))}"


def validate_overworld_object_route_effect_authoring_entry(object_id: str, obj: dict, site: dict | None) -> dict:
    footprint = obj.get("footprint", {}) if isinstance(obj.get("footprint", {}), dict) else {}
    body_tiles = obj.get("body_tiles", []) if isinstance(obj.get("body_tiles", []), list) else []
    approach = obj.get("approach", {}) if isinstance(obj.get("approach", {}), dict) else {}
    visit_offsets = approach.get("visit_offsets", []) if isinstance(approach.get("visit_offsets", []), list) else []
    linked_exit_offsets = approach.get("linked_exit_offsets", []) if isinstance(approach.get("linked_exit_offsets", []), list) else []
    route_effect = obj.get("route_effect", {}) if isinstance(obj.get("route_effect", {}), dict) else {}
    secondary_tags = [str(tag) for tag in obj.get("secondary_tags", [])] if isinstance(obj.get("secondary_tags", []), list) else []
    map_roles = [str(role) for role in obj.get("map_roles", [])] if isinstance(obj.get("map_roles", []), list) else []
    transit_profile = site.get("transit_profile", {}) if isinstance(site, dict) and isinstance(site.get("transit_profile", {}), dict) else {}
    entry = {
        "object_id": object_id,
        "resource_site_id": str(obj.get("resource_site_id", "")),
        "site_has_transit_profile": bool(transit_profile),
        "route_effect_present": bool(route_effect),
        "effect_id": str(route_effect.get("effect_id", "")) if route_effect else "",
        "effect_type": str(route_effect.get("effect_type", "")) if route_effect else "",
        "route_tags_present": "conditional_route" in secondary_tags and "road_control" in secondary_tags,
        "route_map_roles": [role for role in map_roles if "route" in role or "transit" in role or "shortcut" in role],
        "shape_mask_contract": {
            "visual_footprint": {
                "width": int(footprint.get("width", 0)),
                "height": int(footprint.get("height", 0)),
                "anchor": str(footprint.get("anchor", "")),
            },
            "body_tile_count": len(body_tiles),
            "approach_visit_offset_count": len(visit_offsets),
            "linked_exit_offset_count": len(linked_exit_offsets),
            "body_tiles_separate_from_approach": bool(body_tiles) and bool(visit_offsets) and not set(overworld_object_tile_key(tile) for tile in body_tiles).intersection(set(overworld_object_tile_key(tile) for tile in visit_offsets)),
        },
        "runtime_adoption": "metadata_only_reported_not_pathing_or_save_state",
        "warnings": [],
        "errors": [],
    }

    def add_error(message: str) -> None:
        if message not in entry["errors"]:
            entry["errors"].append(message)

    def add_warning(message: str) -> None:
        if message not in entry["warnings"]:
            entry["warnings"].append(message)

    if str(obj.get("primary_class", infer_overworld_object_primary_class(obj, site))) != "transit_route_object" and str(obj.get("family", "")) != "transit_object":
        add_warning("route-effect validation was invoked for a non-transit object")
    if not transit_profile:
        add_error("transit object must link to a resource site with transit_profile")
    if not entry["route_tags_present"]:
        add_error("transit object must author road_control and conditional_route secondary tags")
    if not entry["route_map_roles"]:
        add_error("transit object must keep a route/transit/shortcut map role")
    if str(obj.get("passability_class", "")) != "conditional_pass":
        add_error("transit object must author passability_class conditional_pass for route-effect validation")
    interaction = obj.get("interaction", {}) if isinstance(obj.get("interaction", {}), dict) else {}
    if str(interaction.get("cadence", "")) != "conditional":
        add_error("transit object interaction.cadence must be conditional")
    if str(approach.get("mode", "")) != "linked_endpoint":
        add_error("transit object approach.mode must be linked_endpoint")
    if not body_tiles:
        add_error("transit object must author body_tiles separately from approach tiles")
    if len(visit_offsets) < 2:
        add_error("transit object must author at least two approach.visit_offsets")
    if len(linked_exit_offsets) != len(visit_offsets):
        add_error("transit object linked_exit_offsets must match approach.visit_offsets count")
    if set(overworld_object_tile_key(tile) for tile in body_tiles).intersection(set(overworld_object_tile_key(tile) for tile in visit_offsets)):
        add_error("transit object body_tiles must not overlap approach.visit_offsets")
    if not route_effect:
        add_error("transit object must define route_effect metadata")
    else:
        missing_keys = sorted(OVERWORLD_OBJECT_ROUTE_EFFECT_REQUIRED_KEYS.difference(route_effect.keys()))
        if missing_keys:
            add_error(f"route_effect is missing required keys: {', '.join(missing_keys)}")
        effect_type = str(route_effect.get("effect_type", ""))
        if effect_type not in OVERWORLD_OBJECT_ROUTE_EFFECT_TYPES:
            add_error(f"route_effect effect_type is unsupported: {effect_type}")
        if not str(route_effect.get("effect_id", "")):
            add_error("route_effect.effect_id must be non-empty")
        for bool_key in ("requires_visit", "requires_owner"):
            if bool_key in route_effect and type(route_effect.get(bool_key)) is not bool:
                add_error(f"route_effect.{bool_key} must be boolean")
        if "movement_cost_delta" in route_effect and type(route_effect.get("movement_cost_delta")) is not int:
            add_error("route_effect.movement_cost_delta must be an integer")
        toll_resources = route_effect.get("toll_resources", {})
        if not isinstance(toll_resources, dict):
            add_error("route_effect.toll_resources must be a dictionary")
        else:
            for resource_id, amount in toll_resources.items():
                rid = str(resource_id)
                if rid not in ECONOMY_STOCKPILE_RESOURCE_IDS:
                    add_error(f"route_effect.toll_resources uses unsupported live resource id {rid}")
                if rid in ECONOMY_RARE_RESOURCE_IDS:
                    add_error(f"route_effect.toll_resources must not activate staged rare resource {rid}")
                if type(amount) is not int or int(amount) < 0:
                    add_error(f"route_effect.toll_resources.{rid} must be a non-negative integer")
        blocked_state_ids = route_effect.get("blocked_state_ids", [])
        if not isinstance(blocked_state_ids, list):
            add_error("route_effect.blocked_state_ids must be a list")
        elif any(not str(state_id) for state_id in blocked_state_ids):
            add_error("route_effect.blocked_state_ids must contain non-empty state ids")
        if effect_type == "linked_endpoint" and not str(route_effect.get("linked_endpoint_group_id", "")):
            add_error("linked_endpoint route_effect must define linked_endpoint_group_id")
        for public_key in ("public_reason", "public_summary", "display_name"):
            if public_key in route_effect:
                public_text = str(route_effect.get(public_key, ""))
                for token in OVERWORLD_OBJECT_PUBLIC_ROUTE_LEAK_TOKENS:
                    if token in public_text:
                        add_error(f"route_effect.{public_key} leaks internal token {token}")
    if not entry["errors"] and int(route_effect.get("movement_cost_delta", 0)) == 0 and not route_effect.get("toll_resources", {}):
        add_warning("route_effect has no movement delta or toll payload; confirm the selected effect is intentionally state-only")
    return entry


def validate_overworld_object_safe_metadata_bundle(errors: list[str], map_objects: dict[str, dict], resource_sites: dict[str, dict]) -> None:
    for object_id in sorted(OVERWORLD_OBJECT_SAFE_METADATA_BUNDLE_001):
        ensure(object_id in map_objects, errors, f"Safe metadata bundle safe_metadata_bundle_001 is missing map object {object_id}")
    for object_id in sorted(OVERWORLD_OBJECT_SAFE_METADATA_BUNDLE_001.intersection(map_objects.keys())):
        obj = map_objects[object_id]
        site_id = str(obj.get("resource_site_id", ""))
        site = resource_sites.get(site_id) if site_id else None
        expected_primary_class = infer_overworld_object_primary_class(obj, site)
        expected_passability_class = infer_overworld_object_passability_class(obj)
        expected_cadence = infer_overworld_object_interaction_cadence(obj, site)
        expected_tier = infer_overworld_object_footprint_tier(obj.get("footprint", {}) if isinstance(obj.get("footprint", {}), dict) else {})
        inferred_allowed_tags = [tag for tag in infer_overworld_object_secondary_tags(obj, site) if tag in OVERWORLD_OBJECT_SECONDARY_TAGS]

        ensure(obj.get("schema_version") == 1, errors, f"Map object {object_id} must declare schema_version 1 for safe_metadata_bundle_001")
        primary_class = str(obj.get("primary_class", ""))
        ensure(primary_class in OVERWORLD_OBJECT_PRIMARY_CLASSES, errors, f"Map object {object_id} safe metadata uses unsupported primary_class {primary_class}")
        ensure(primary_class == expected_primary_class, errors, f"Map object {object_id} primary_class must match legacy-compatible inference {expected_primary_class}")

        secondary_tags = obj.get("secondary_tags", [])
        ensure(isinstance(secondary_tags, list), errors, f"Map object {object_id} secondary_tags must be a list for safe_metadata_bundle_001")
        if isinstance(secondary_tags, list):
            authored_tags = {str(tag) for tag in secondary_tags}
            for tag in authored_tags:
                ensure(tag in OVERWORLD_OBJECT_SECONDARY_TAGS, errors, f"Map object {object_id} uses unsupported secondary tag {tag}")
            for tag in inferred_allowed_tags:
                ensure(tag in authored_tags, errors, f"Map object {object_id} secondary_tags must include inferred safe tag {tag}")

        footprint = obj.get("footprint", {})
        ensure(isinstance(footprint, dict), errors, f"Map object {object_id} footprint must remain a dictionary for safe_metadata_bundle_001")
        if isinstance(footprint, dict):
            anchor = str(footprint.get("anchor", ""))
            tier = str(footprint.get("tier", ""))
            ensure(anchor in OVERWORLD_OBJECT_FOOTPRINT_ANCHORS, errors, f"Map object {object_id} footprint.anchor is missing or unsupported")
            ensure(anchor == "bottom_center", errors, f"Map object {object_id} footprint.anchor must stay bottom_center in safe_metadata_bundle_001")
            ensure(tier in OVERWORLD_OBJECT_FOOTPRINT_TIERS, errors, f"Map object {object_id} footprint.tier is missing or unsupported")
            ensure(tier == expected_tier, errors, f"Map object {object_id} footprint.tier must match legacy dimensions as {expected_tier}")

        passability_class = str(obj.get("passability_class", ""))
        ensure(passability_class in OVERWORLD_OBJECT_PASSABILITY_CLASSES, errors, f"Map object {object_id} passability_class is missing or unsupported")
        ensure(passability_class == expected_passability_class, errors, f"Map object {object_id} passability_class must match legacy passable/visitable inference {expected_passability_class}")

        interaction = obj.get("interaction", {})
        ensure(isinstance(interaction, dict), errors, f"Map object {object_id} interaction must be a dictionary for safe_metadata_bundle_001")
        if isinstance(interaction, dict):
            missing_interaction_keys = sorted(OVERWORLD_OBJECT_SAFE_INTERACTION_KEYS.difference(interaction.keys()))
            ensure(not missing_interaction_keys, errors, f"Map object {object_id} interaction is missing safe metadata keys: {', '.join(missing_interaction_keys)}")
            cadence = str(interaction.get("cadence", ""))
            ensure(cadence in OVERWORLD_OBJECT_INTERACTION_CADENCES, errors, f"Map object {object_id} interaction cadence is missing or unsupported")
            ensure(cadence == expected_cadence, errors, f"Map object {object_id} interaction cadence must match linked-site inference {expected_cadence}")
            for bool_key in ("remains_after_visit", "requires_ownership", "requires_guard_clear", "supports_revisit"):
                ensure(type(interaction.get(bool_key)) is bool, errors, f"Map object {object_id} interaction.{bool_key} must be boolean")
            ensure(str(interaction.get("state_after_visit", "")) in OVERWORLD_OBJECT_SAFE_STATE_AFTER_VISIT, errors, f"Map object {object_id} interaction.state_after_visit is unsupported")
            cooldown_days = interaction.get("cooldown_days")
            ensure(type(cooldown_days) is int and cooldown_days >= 0, errors, f"Map object {object_id} interaction.cooldown_days must be a non-negative integer")
            ensure(str(interaction.get("refresh_rule", "")) in OVERWORLD_OBJECT_SAFE_REFRESH_RULES, errors, f"Map object {object_id} interaction.refresh_rule is unsupported")
            if cadence == "none":
                ensure(bool(interaction.get("remains_after_visit", False)), errors, f"Map object {object_id} non-interaction metadata must remain after visit")
                ensure(not bool(interaction.get("supports_revisit", True)), errors, f"Map object {object_id} non-interaction metadata must not support revisit")
            elif cadence == "one_time":
                ensure(not bool(interaction.get("remains_after_visit", True)), errors, f"Map object {object_id} one-time metadata must not remain after visit")
                ensure(not bool(interaction.get("supports_revisit", True)), errors, f"Map object {object_id} one-time metadata must not support revisit")
            else:
                ensure(bool(interaction.get("remains_after_visit", False)), errors, f"Map object {object_id} repeatable/persistent metadata must remain after visit")
                ensure(bool(interaction.get("supports_revisit", False)), errors, f"Map object {object_id} repeatable/persistent metadata must support revisit")
            if cadence == "cooldown_days" and site:
                ensure(int(interaction.get("cooldown_days", 0)) == int(site.get("visit_cooldown_days", 0)), errors, f"Map object {object_id} interaction.cooldown_days must match linked site cooldown")


def infer_overworld_object_reward_categories(site: dict | None) -> list[str]:
    if site is None:
        return []
    categories: list[str] = []
    if isinstance(site.get("rewards", {}), dict) and site.get("rewards", {}):
        append_unique(categories, "small_resource_reward")
    if isinstance(site.get("claim_rewards", {}), dict) and site.get("claim_rewards", {}):
        append_unique(categories, "claim_reward")
    if isinstance(site.get("control_income", {}), dict) and site.get("control_income", {}):
        append_unique(categories, "persistent_income")
    if isinstance(site.get("weekly_recruits", {}), dict) and site.get("weekly_recruits", {}):
        append_unique(categories, "recruitment")
    if str(site.get("learn_spell_id", "")):
        append_unique(categories, "spell_access")
    if int(site.get("vision_radius", 0)) > 0:
        append_unique(categories, "scouting_reveal")
    if isinstance(site.get("transit_profile", {}), dict) and bool(site.get("transit_profile", {})):
        append_unique(categories, "route_opening")
    if isinstance(site.get("town_support", {}), dict) and bool(site.get("town_support", {})):
        append_unique(categories, "town_support")
    if bool(site.get("repeatable", False)):
        append_unique(categories, "repeatable_service")
    return categories


def collect_overworld_object_scenario_site_placements(scenarios: dict[str, dict]) -> dict[str, dict]:
    placements: dict[str, dict] = {}
    for scenario_id, scenario in scenarios.items():
        for node in scenario.get("resource_nodes", []):
            if not isinstance(node, dict):
                continue
            site_id = str(node.get("site_id", ""))
            if not site_id:
                continue
            entry = placements.setdefault(site_id, {"count": 0, "scenarios": [], "placements": []})
            entry["count"] += 1
            append_unique(entry["scenarios"], scenario_id)
            append_unique_dict(
                entry["placements"],
                {
                    "scenario_id": scenario_id,
                    "placement_id": str(node.get("placement_id", "")),
                    "x": int(node.get("x", 0)),
                    "y": int(node.get("y", 0)),
                    "collected_by_faction_id": str(node.get("collected_by_faction_id", "")),
                },
            )
    return placements


def collect_overworld_object_scenario_encounter_placements(scenarios: dict[str, dict]) -> dict[str, dict]:
    placements: dict[str, dict] = {}
    for scenario_id, scenario in scenarios.items():
        for node in scenario.get("encounters", []):
            if not isinstance(node, dict):
                continue
            encounter_id = str(node.get("encounter_id", ""))
            if not encounter_id:
                continue
            entry = placements.setdefault(encounter_id, {"count": 0, "scenarios": [], "placements": []})
            entry["count"] += 1
            append_unique(entry["scenarios"], scenario_id)
            append_unique_dict(
                entry["placements"],
                {
                    "scenario_id": scenario_id,
                    "placement_id": str(node.get("placement_id", "")),
                    "x": int(node.get("x", 0)),
                    "y": int(node.get("y", 0)),
                    "difficulty": str(node.get("difficulty", "")),
                },
            )
    return placements


def scenario_map_dimensions(scenario: dict) -> tuple[int, int]:
    raw_map = scenario.get("map", {})
    if isinstance(raw_map, dict):
        return int(raw_map.get("width", 0)), int(raw_map.get("height", 0))
    if isinstance(raw_map, list):
        height = len(raw_map)
        width = len(raw_map[0]) if height > 0 and isinstance(raw_map[0], list) else 0
        return width, height
    return 0, 0


def object_editor_metadata(obj: dict) -> dict:
    editor_placement = obj.get("editor_placement", {})
    if isinstance(editor_placement, dict) and editor_placement:
        return {"source": "map_object.editor_placement", "metadata": editor_placement}
    neutral_metadata = obj.get("neutral_encounter", {})
    if isinstance(neutral_metadata, dict):
        nested_editor_placement = neutral_metadata.get("editor_placement", {})
        if isinstance(nested_editor_placement, dict) and nested_editor_placement:
            return {"source": "neutral_encounter.editor_placement", "metadata": nested_editor_placement}
    return {"source": "", "metadata": {}}


def object_missing_editor_authoring_fields(obj: dict) -> list[str]:
    missing: list[str] = []
    footprint = obj.get("footprint", {}) if isinstance(obj.get("footprint", {}), dict) else {}
    for key in ("schema_version", "primary_class", "secondary_tags", "passability_class", "interaction"):
        if key not in obj:
            missing.append(key)
    if "anchor" not in footprint:
        missing.append("footprint.anchor")
    if "tier" not in footprint:
        missing.append("footprint.tier")
    if not object_editor_metadata(obj)["metadata"]:
        missing.append("editor_placement")
    return missing


def editor_authoring_primary_class_bucket(primary_class: str) -> str:
    if primary_class in {"neutral_encounter", "guarded_reward_site"}:
        return "guard_or_encounter"
    if primary_class in {"persistent_economy_site", "transit_route_object", "faction_landmark"}:
        return "strategic_site"
    if primary_class in {"interactable_site", "neutral_dwelling"}:
        return "visitable_site"
    return primary_class


def build_overworld_object_editor_authoring_section(
    map_objects: dict[str, dict],
    resource_sites: dict[str, dict],
    scenarios: dict[str, dict],
    site_placements: dict[str, dict],
    encounter_placements: dict[str, dict],
    object_ids_by_site_id: dict[str, str],
) -> dict:
    section = {
        "schema": "overworld_object_editor_authoring_report_v1",
        "mode": "report_only_no_runtime_effect",
        "region_size": OVERWORLD_OBJECT_EDITOR_DENSITY_REGION_SIZE,
        "palette_groups": {},
        "metadata_readiness": {
            "taxonomy_ready_count": 0,
            "editor_metadata_present_count": 0,
            "top_level_editor_placement_count": 0,
            "nested_neutral_editor_placement_count": 0,
            "objects_missing_editor_authoring_fields": {},
            "missing_field_counts": {},
            "role_mismatches": [],
            "unsupported_map_role_tags": [],
        },
        "density_diagnostics": {
            "scenario_regions": {},
            "regions_requiring_review": [],
            "empty_regions": [],
            "unlinked_placed_resource_sites": [],
        },
    }

    object_scenario_counts: dict[str, int] = {object_id: 0 for object_id in map_objects.keys()}
    for site_id, placement_entry in site_placements.items():
        object_id = object_ids_by_site_id.get(site_id, "")
        if object_id:
            object_scenario_counts[object_id] = int(object_scenario_counts.get(object_id, 0)) + int(placement_entry.get("count", 0))
    for scenario in scenarios.values():
        for encounter in scenario.get("encounters", []):
            if not isinstance(encounter, dict):
                continue
            object_id = str(encounter.get("object_id", ""))
            if object_id:
                object_scenario_counts[object_id] = int(object_scenario_counts.get(object_id, 0)) + 1

    for object_id, obj in sorted(map_objects.items()):
        site_id = str(obj.get("resource_site_id", ""))
        site = resource_sites.get(site_id) if site_id else None
        primary_class = infer_overworld_object_primary_class(obj, site)
        family = str(obj.get("family", ""))
        group = section["palette_groups"].setdefault(
            primary_class,
            {
                "primary_class": primary_class,
                "count": 0,
                "families": {},
                "object_ids": [],
                "scenario_placement_count": 0,
                "editor_metadata_present_count": 0,
            },
        )
        group["count"] += 1
        append_unique(group["object_ids"], object_id)
        increment_count(group["families"], family)
        group["scenario_placement_count"] += int(object_scenario_counts.get(object_id, 0))
        editor_metadata = object_editor_metadata(obj)
        if editor_metadata["metadata"]:
            group["editor_metadata_present_count"] += 1

        missing_fields = object_missing_editor_authoring_fields(obj)
        if not missing_fields:
            section["metadata_readiness"]["taxonomy_ready_count"] += 1
        else:
            section["metadata_readiness"]["objects_missing_editor_authoring_fields"][object_id] = missing_fields
            for field in missing_fields:
                increment_count(section["metadata_readiness"]["missing_field_counts"], field)
        if editor_metadata["source"] == "map_object.editor_placement":
            section["metadata_readiness"]["top_level_editor_placement_count"] += 1
            section["metadata_readiness"]["editor_metadata_present_count"] += 1
        elif editor_metadata["source"] == "neutral_encounter.editor_placement":
            section["metadata_readiness"]["nested_neutral_editor_placement_count"] += 1
            section["metadata_readiness"]["editor_metadata_present_count"] += 1

        authored_primary_class = str(obj.get("primary_class", ""))
        if authored_primary_class and authored_primary_class != primary_class:
            section["metadata_readiness"]["role_mismatches"].append(
                {"object_id": object_id, "authored_primary_class": authored_primary_class, "inferred_primary_class": primary_class}
            )
        for role in obj.get("map_roles", []) if isinstance(obj.get("map_roles", []), list) else []:
            role_key = str(role)
            if role_key and role_key not in OVERWORLD_OBJECT_SECONDARY_TAGS:
                section["metadata_readiness"]["unsupported_map_role_tags"].append({"object_id": object_id, "role": role_key})

    for primary_class, group in section["palette_groups"].items():
        group["families"] = sorted_counts(group["families"])
        group["object_ids"] = sorted(group["object_ids"])
    section["palette_groups"] = {key: section["palette_groups"][key] for key in sorted(section["palette_groups"].keys())}
    section["metadata_readiness"]["missing_field_counts"] = sorted_counts(section["metadata_readiness"]["missing_field_counts"])
    section["metadata_readiness"]["role_mismatches"] = sorted(section["metadata_readiness"]["role_mismatches"], key=lambda item: item["object_id"])
    section["metadata_readiness"]["unsupported_map_role_tags"] = sorted(section["metadata_readiness"]["unsupported_map_role_tags"], key=lambda item: (item["object_id"], item["role"]))

    def add_density_placement(region: dict, placement: dict, primary_class: str, source: str, object_id: str = "", site_id: str = "") -> None:
        region["placement_count"] += 1
        increment_count(region["primary_class_counts"], primary_class)
        increment_count(region["authoring_bucket_counts"], editor_authoring_primary_class_bucket(primary_class))
        if not object_id and source == "resource_site":
            region["placed_without_map_object_count"] += 1
        region["placements"].append(
            {
                "placement_id": str(placement.get("placement_id", "")),
                "source": source,
                "object_id": object_id,
                "site_id": site_id,
                "primary_class": primary_class,
                "x": int(placement.get("x", 0)),
                "y": int(placement.get("y", 0)),
            }
        )

    for scenario_id, scenario in sorted(scenarios.items()):
        width, height = scenario_map_dimensions(scenario)
        regions_x = max(1, (width + OVERWORLD_OBJECT_EDITOR_DENSITY_REGION_SIZE - 1) // OVERWORLD_OBJECT_EDITOR_DENSITY_REGION_SIZE)
        regions_y = max(1, (height + OVERWORLD_OBJECT_EDITOR_DENSITY_REGION_SIZE - 1) // OVERWORLD_OBJECT_EDITOR_DENSITY_REGION_SIZE)
        scenario_entry = {
            "scenario_id": scenario_id,
            "map_width": width,
            "map_height": height,
            "regions_x": regions_x,
            "regions_y": regions_y,
            "regions": {},
        }
        for ry in range(regions_y):
            for rx in range(regions_x):
                key = f"{rx},{ry}"
                scenario_entry["regions"][key] = {
                    "region": {"x": rx, "y": ry},
                    "placement_count": 0,
                    "primary_class_counts": {},
                    "authoring_bucket_counts": {},
                    "placed_without_map_object_count": 0,
                    "placements": [],
                    "warnings": [],
                }

        for node in scenario.get("resource_nodes", []):
            if not isinstance(node, dict):
                continue
            site_id = str(node.get("site_id", ""))
            object_id = object_ids_by_site_id.get(site_id, "")
            obj = map_objects.get(object_id, {}) if object_id else {}
            site = resource_sites.get(site_id)
            primary_class = infer_overworld_object_primary_class(obj, site)
            rx = max(0, min(regions_x - 1, int(node.get("x", 0)) // OVERWORLD_OBJECT_EDITOR_DENSITY_REGION_SIZE))
            ry = max(0, min(regions_y - 1, int(node.get("y", 0)) // OVERWORLD_OBJECT_EDITOR_DENSITY_REGION_SIZE))
            add_density_placement(scenario_entry["regions"][f"{rx},{ry}"], node, primary_class, "resource_site", object_id, site_id)
            if not object_id:
                append_unique_dict(
                    section["density_diagnostics"]["unlinked_placed_resource_sites"],
                    {"scenario_id": scenario_id, "placement_id": str(node.get("placement_id", "")), "site_id": site_id},
                )

        for node in scenario.get("encounters", []):
            if not isinstance(node, dict):
                continue
            object_id = str(node.get("object_id", ""))
            obj = map_objects.get(object_id, {}) if object_id else {}
            primary_class = str(node.get("primary_class", ""))
            if not primary_class:
                primary_class = infer_overworld_object_primary_class(obj, None) if obj else "neutral_encounter"
            rx = max(0, min(regions_x - 1, int(node.get("x", 0)) // OVERWORLD_OBJECT_EDITOR_DENSITY_REGION_SIZE))
            ry = max(0, min(regions_y - 1, int(node.get("y", 0)) // OVERWORLD_OBJECT_EDITOR_DENSITY_REGION_SIZE))
            add_density_placement(scenario_entry["regions"][f"{rx},{ry}"], node, primary_class, "encounter", object_id, "")

        for key, region in scenario_entry["regions"].items():
            bucket_counts = region["authoring_bucket_counts"]
            if region["placement_count"] == 0:
                section["density_diagnostics"]["empty_regions"].append({"scenario_id": scenario_id, "region": region["region"]})
            if region["placement_count"] > 16:
                region["warnings"].append("authoring density review: more than 16 non-decoration placements in one 16x16 region")
            if int(bucket_counts.get("pickup", 0)) > 7:
                region["warnings"].append("authoring density review: pickup count exceeds the standard adventure band")
            if int(bucket_counts.get("guard_or_encounter", 0)) > 6:
                region["warnings"].append("authoring density review: guard/encounter count exceeds the ruin/reward pocket band")
            if int(bucket_counts.get("strategic_site", 0)) + int(bucket_counts.get("visitable_site", 0)) > 10:
                region["warnings"].append("authoring density review: strategic/visitable object count may crowd approach reads")
            if region["placed_without_map_object_count"] > 0:
                region["warnings"].append("authoring metadata gap: placed resource sites in this region lack map_object links")
            if region["warnings"]:
                section["density_diagnostics"]["regions_requiring_review"].append(
                    {
                        "scenario_id": scenario_id,
                        "region": region["region"],
                        "placement_count": region["placement_count"],
                        "primary_class_counts": sorted_counts(region["primary_class_counts"]),
                        "warnings": region["warnings"],
                    }
                )
            region["primary_class_counts"] = sorted_counts(region["primary_class_counts"])
            region["authoring_bucket_counts"] = sorted_counts(region["authoring_bucket_counts"])
            region["placements"] = sorted(region["placements"], key=lambda item: (item["y"], item["x"], item["placement_id"]))
        section["density_diagnostics"]["scenario_regions"][scenario_id] = scenario_entry

    section["density_diagnostics"]["empty_regions"] = sorted(
        section["density_diagnostics"]["empty_regions"],
        key=lambda item: (item["scenario_id"], item["region"]["y"], item["region"]["x"]),
    )
    section["density_diagnostics"]["regions_requiring_review"] = sorted(
        section["density_diagnostics"]["regions_requiring_review"],
        key=lambda item: (item["scenario_id"], item["region"]["y"], item["region"]["x"]),
    )
    section["density_diagnostics"]["unlinked_placed_resource_sites"] = sorted(
        section["density_diagnostics"]["unlinked_placed_resource_sites"],
        key=lambda item: (item["scenario_id"], item["placement_id"], item["site_id"]),
    )
    return section


def build_overworld_object_content_batch_001_section(map_objects: dict[str, dict], resource_sites: dict[str, dict]) -> dict:
    batch_objects = {
        object_id: obj
        for object_id, obj in map_objects.items()
        if str(obj.get("content_batch_id", "")) == OVERWORLD_OBJECT_CONTENT_BATCH_001_ID
    }
    section = {
        "batch_id": OVERWORLD_OBJECT_CONTENT_BATCH_001_ID,
        "object_count": len(batch_objects),
        "passable_scenic_decoration_count": 0,
        "blocking_or_edge_decoration_count": 0,
        "common_live_pickup_count": 0,
        "staged_rare_pickup_count": 0,
        "footprints": {},
        "biome_ids": [],
        "staged_rare_resource_ids": [],
        "common_live_resource_ids": [],
        "errors": [],
        "warnings": [],
    }

    def add_error(message: str) -> None:
        if message not in section["errors"]:
            section["errors"].append(message)

    def add_warning(message: str) -> None:
        if message not in section["warnings"]:
            section["warnings"].append(message)

    for object_id, obj in sorted(batch_objects.items()):
        primary_class = str(obj.get("primary_class", infer_overworld_object_primary_class(obj, resource_sites.get(str(obj.get("resource_site_id", ""))))))
        passability_class = str(obj.get("passability_class", infer_overworld_object_passability_class(obj)))
        family = str(obj.get("family", ""))
        footprint = obj.get("footprint", {}) if isinstance(obj.get("footprint", {}), dict) else {}
        footprint_key = f"{int(footprint.get('width', 0))}x{int(footprint.get('height', 0))}"
        increment_count(section["footprints"], footprint_key)
        for biome_id in obj.get("biome_ids", []) if isinstance(obj.get("biome_ids", []), list) else []:
            append_unique(section["biome_ids"], str(biome_id))
        forbidden_wood_alias = "tim" + "ber"
        if forbidden_wood_alias in str(obj.get("name", "")).lower() or forbidden_wood_alias in object_id.lower():
            add_error(f"{object_id}: Batch 001 must keep wood canonical and avoid non-canonical wood aliases")
        if primary_class == "decoration":
            if bool(obj.get("visitable", False)):
                add_error(f"{object_id}: decoration objects must remain non-interactable")
            if passability_class == "passable_scenic":
                section["passable_scenic_decoration_count"] += 1
                body_tiles = obj.get("body_tiles", [])
                if body_tiles not in ([], None):
                    add_warning(f"{object_id}: passable scenic decoration authors non-empty body_tiles")
            elif passability_class in {"blocking_non_visitable", "edge_blocker"}:
                section["blocking_or_edge_decoration_count"] += 1
                body_tiles = obj.get("body_tiles", [])
                if not isinstance(body_tiles, list) or not body_tiles:
                    add_error(f"{object_id}: blocking/edge decoration must author explicit body_tiles")
        if primary_class == "pickup":
            staged = obj.get("staged_resource_pickup", {})
            site_id = str(obj.get("resource_site_id", ""))
            if isinstance(staged, dict) and staged:
                section["staged_rare_pickup_count"] += 1
                resource_id = str(staged.get("resource_id", ""))
                append_unique(section["staged_rare_resource_ids"], resource_id)
                if resource_id not in ECONOMY_RARE_RESOURCE_IDS:
                    add_error(f"{object_id}: staged rare pickup uses unsupported rare resource {resource_id}")
                if bool(staged.get("live_reward", True)):
                    add_error(f"{object_id}: staged rare pickup must not be a live reward")
                if not bool(staged.get("report_only", False)) or str(staged.get("activation_status", "")) != "staged_report_only":
                    add_error(f"{object_id}: staged rare pickup must remain report-only/staged")
                if site_id:
                    add_error(f"{object_id}: staged rare pickup must not link to live resource_sites rewards")
                if bool(obj.get("visitable", False)):
                    add_error(f"{object_id}: staged rare pickup must not be live visitable")
            elif site_id:
                site = resource_sites.get(site_id, {})
                rewards = site.get("rewards", {}) if isinstance(site.get("rewards", {}), dict) else {}
                reward_ids = {str(resource_id) for resource_id, amount in rewards.items() if int(amount) > 0}
                if reward_ids and reward_ids.issubset(ECONOMY_STOCKPILE_RESOURCE_IDS):
                    section["common_live_pickup_count"] += 1
                    for resource_id in sorted(reward_ids):
                        append_unique(section["common_live_resource_ids"], resource_id)
                elif reward_ids.intersection(ECONOMY_RARE_RESOURCE_IDS):
                    add_error(f"{object_id}: live pickup must not grant staged rare resources")
    section["footprints"] = sorted_counts(section["footprints"])
    section["biome_ids"] = sorted(section["biome_ids"])
    section["common_live_resource_ids"] = sorted(section["common_live_resource_ids"])
    section["staged_rare_resource_ids"] = sorted(section["staged_rare_resource_ids"])
    if batch_objects:
        if len(batch_objects) < 30:
            add_error("Batch 001 must author about 30 object definitions")
        if section["passable_scenic_decoration_count"] < 12:
            add_error("Batch 001 must include at least 12 passable scenic decorations")
        if section["blocking_or_edge_decoration_count"] < 8:
            add_error("Batch 001 must include at least 8 blocking or edge-blocker decorations")
        if section["common_live_pickup_count"] < 6:
            add_error("Batch 001 must include at least 6 live common pickups")
        if section["staged_rare_pickup_count"] < 4:
            add_error("Batch 001 must include at least 4 staged rare-resource pickups")
        for resource_id in ("gold", "wood", "ore"):
            if resource_id not in section["common_live_resource_ids"]:
                add_error(f"Batch 001 live common pickups must include {resource_id}")
    return section


def build_overworld_object_content_batch_001b_section(map_objects: dict[str, dict], biomes: dict[str, dict]) -> dict:
    batch_objects = {
        object_id: obj
        for object_id, obj in map_objects.items()
        if str(obj.get("content_batch_id", "")) == OVERWORLD_OBJECT_CONTENT_BATCH_001B_ID
    }
    section = {
        "batch_id": OVERWORLD_OBJECT_CONTENT_BATCH_001B_ID,
        "object_count": len(batch_objects),
        "passable_scenic_decoration_count": 0,
        "footprints": {},
        "biome_counts": {},
        "errors": [],
        "warnings": [],
    }

    def add_error(message: str) -> None:
        if message not in section["errors"]:
            section["errors"].append(message)

    for object_id, obj in sorted(batch_objects.items()):
        primary_class = str(obj.get("primary_class", infer_overworld_object_primary_class(obj, None)))
        passability_class = str(obj.get("passability_class", infer_overworld_object_passability_class(obj)))
        footprint = obj.get("footprint", {}) if isinstance(obj.get("footprint", {}), dict) else {}
        footprint_key = f"{int(footprint.get('width', 0))}x{int(footprint.get('height', 0))}"
        increment_count(section["footprints"], footprint_key)
        for biome_id in obj.get("biome_ids", []) if isinstance(obj.get("biome_ids", []), list) else []:
            increment_count(section["biome_counts"], str(biome_id))
        forbidden_wood_alias = "tim" + "ber"
        if forbidden_wood_alias in str(obj.get("name", "")).lower() or forbidden_wood_alias in object_id.lower():
            add_error(f"{object_id}: Batch 001b must keep wood canonical and avoid non-canonical wood aliases")
        if primary_class != "decoration":
            add_error(f"{object_id}: Batch 001b objects must be decorations")
        if passability_class != "passable_scenic":
            add_error(f"{object_id}: Batch 001b objects must use passable_scenic")
        else:
            section["passable_scenic_decoration_count"] += 1
        if bool(obj.get("passable", False)) is not True:
            add_error(f"{object_id}: Batch 001b passable scenic objects must set passable=true")
        if bool(obj.get("visitable", False)):
            add_error(f"{object_id}: Batch 001b passable scenic objects must set visitable=false")
        body_tiles = obj.get("body_tiles", [])
        if body_tiles not in ([], None):
            add_error(f"{object_id}: Batch 001b passable scenic objects must keep empty body_tiles")
        if str(obj.get("resource_site_id", "")):
            add_error(f"{object_id}: Batch 001b scenic objects must not link resource_site_id")
        if isinstance(obj.get("staged_resource_pickup", {}), dict) and obj.get("staged_resource_pickup", {}):
            add_error(f"{object_id}: Batch 001b scenic objects must not author staged_resource_pickup")
        if isinstance(obj.get("rewards", {}), dict) and obj.get("rewards", {}):
            add_error(f"{object_id}: Batch 001b scenic objects must not author rewards")

    section["footprints"] = sorted_counts(section["footprints"])
    section["biome_counts"] = dict(sorted(section["biome_counts"].items()))
    if batch_objects:
        if not (58 <= len(batch_objects) <= 64):
            add_error("Batch 001b must author about 60 object definitions")
        if section["passable_scenic_decoration_count"] != len(batch_objects):
            add_error("Batch 001b must be scenic-only")
        required_footprints = {"1x1", "1x2", "2x1", "1x3", "3x1", "2x2", "2x3"}
        for footprint_key in sorted(required_footprints):
            if footprint_key not in section["footprints"]:
                add_error(f"Batch 001b must cover footprint {footprint_key}")
        for biome_id in sorted(biomes.keys()):
            if int(section["biome_counts"].get(biome_id, 0)) < 5:
                add_error(f"Batch 001b must include at least 5 passable scenic definitions for {biome_id}")
    return section


def build_overworld_object_content_batch_001c_section(map_objects: dict[str, dict], biomes: dict[str, dict]) -> dict:
    batch_objects = {
        object_id: obj
        for object_id, obj in map_objects.items()
        if str(obj.get("content_batch_id", "")) == OVERWORLD_OBJECT_CONTENT_BATCH_001C_ID
    }
    section = {
        "batch_id": OVERWORLD_OBJECT_CONTENT_BATCH_001C_ID,
        "object_count": len(batch_objects),
        "blocking_non_visitable_count": 0,
        "edge_blocker_count": 0,
        "partial_body_mask_count": 0,
        "footprints": {},
        "biome_counts": {},
        "edge_intents": [],
        "content_token_coverage": {},
        "errors": [],
        "warnings": [],
    }

    def add_error(message: str) -> None:
        if message not in section["errors"]:
            section["errors"].append(message)

    required_content_tokens = {
        "rock": ("rock", "stone", "boulder", "talus", "scree"),
        "tree_or_root": ("tree", "trunk", "root", "stump", "bough", "cypress", "whitewood"),
        "cliff_lip": ("cliff", "ledge", "shelf", "escarpment", "ravine"),
        "reed_island": ("reed",),
        "reef_shelf": ("reef", "shoal"),
        "wreck_ribs": ("wreck", "rib", "keel"),
        "slag_berm": ("slag", "clinker"),
        "ice_block": ("ice", "rime", "frost"),
        "quarry_chunk": ("quarry", "spoil"),
        "ruin_debris": ("ruin", "rubble", "debris", "block"),
    }
    token_hits = {key: False for key in required_content_tokens.keys()}

    for object_id, obj in sorted(batch_objects.items()):
        primary_class = str(obj.get("primary_class", infer_overworld_object_primary_class(obj, None)))
        passability_class = str(obj.get("passability_class", infer_overworld_object_passability_class(obj)))
        footprint = obj.get("footprint", {}) if isinstance(obj.get("footprint", {}), dict) else {}
        width = int(footprint.get("width", 0))
        height = int(footprint.get("height", 0))
        footprint_key = f"{width}x{height}"
        increment_count(section["footprints"], footprint_key)
        for biome_id in obj.get("biome_ids", []) if isinstance(obj.get("biome_ids", []), list) else []:
            increment_count(section["biome_counts"], str(biome_id))
        forbidden_wood_alias = "tim" + "ber"
        text_key = f"{object_id} {obj.get('name', '')}".lower()
        if forbidden_wood_alias in text_key:
            add_error(f"{object_id}: Batch 001c must keep wood canonical and avoid non-canonical wood aliases")
        for token_key, token_options in required_content_tokens.items():
            if any(token in text_key for token in token_options):
                token_hits[token_key] = True
        if primary_class != "decoration":
            add_error(f"{object_id}: Batch 001c objects must be decorations")
        if passability_class not in {"blocking_non_visitable", "edge_blocker"}:
            add_error(f"{object_id}: Batch 001c objects must be blocking_non_visitable or edge_blocker")
        elif passability_class == "blocking_non_visitable":
            section["blocking_non_visitable_count"] += 1
        else:
            section["edge_blocker_count"] += 1
        if bool(obj.get("passable", True)):
            add_error(f"{object_id}: Batch 001c blocking and edge-blocker objects must set passable=false")
        if bool(obj.get("visitable", False)):
            add_error(f"{object_id}: Batch 001c objects must set visitable=false")
        body_tiles = obj.get("body_tiles", [])
        if not isinstance(body_tiles, list) or not body_tiles:
            add_error(f"{object_id}: Batch 001c objects must author non-empty explicit body_tiles")
        else:
            seen_body_tiles: set[str] = set()
            for tile in body_tiles:
                if not isinstance(tile, dict):
                    add_error(f"{object_id}: body_tiles entries must be dictionaries")
                    continue
                x = int(tile.get("x", -999))
                y = int(tile.get("y", -999))
                if x < 0 or y < 0 or x >= width or y >= height:
                    add_error(f"{object_id}: body tile {x},{y} is outside footprint")
                tile_key = f"{x},{y}"
                if tile_key in seen_body_tiles:
                    add_error(f"{object_id}: body tile {tile_key} is duplicated")
                seen_body_tiles.add(tile_key)
            if width > 0 and height > 0 and len(seen_body_tiles) < width * height:
                section["partial_body_mask_count"] += 1
        if passability_class == "edge_blocker":
            edge = obj.get("edge_blocker", {})
            if not isinstance(edge, dict) or not edge:
                add_error(f"{object_id}: edge_blocker objects must define edge_blocker metadata")
            else:
                edge_intent = str(edge.get("edge_intent", ""))
                if not edge_intent:
                    add_error(f"{object_id}: edge_blocker metadata must define edge_intent")
                else:
                    append_unique(section["edge_intents"], edge_intent)
                protected_sides = edge.get("protected_sides", [])
                if not isinstance(protected_sides, list) or not protected_sides:
                    add_error(f"{object_id}: edge_blocker metadata must define protected_sides")
        if str(obj.get("resource_site_id", "")):
            add_error(f"{object_id}: Batch 001c objects must not link resource_site_id")
        if isinstance(obj.get("staged_resource_pickup", {}), dict) and obj.get("staged_resource_pickup", {}):
            add_error(f"{object_id}: Batch 001c objects must not author staged_resource_pickup")
        if isinstance(obj.get("rewards", {}), dict) and obj.get("rewards", {}):
            add_error(f"{object_id}: Batch 001c objects must not author rewards")

    section["footprints"] = sorted_counts(section["footprints"])
    section["biome_counts"] = dict(sorted(section["biome_counts"].items()))
    section["edge_intents"] = sorted(section["edge_intents"])
    section["content_token_coverage"] = dict(sorted(token_hits.items()))
    if batch_objects:
        if not (68 <= len(batch_objects) <= 72):
            add_error("Batch 001c must author about 70 object definitions")
        if section["blocking_non_visitable_count"] + section["edge_blocker_count"] != len(batch_objects):
            add_error("Batch 001c must be blocking/edge-only")
        if section["blocking_non_visitable_count"] < 36:
            add_error("Batch 001c must include a substantial blocking_non_visitable blocker set")
        if section["edge_blocker_count"] < 24:
            add_error("Batch 001c must include a substantial edge_blocker set")
        if section["partial_body_mask_count"] < 35:
            add_error("Batch 001c must include broad partial/non-rectangular body-mask coverage")
        required_footprints = {"1x2", "2x1", "1x3", "3x1", "1x4", "4x1", "2x2", "2x3", "3x2", "2x4", "4x2", "3x3", "3x4", "4x3", "4x4"}
        for footprint_key in sorted(required_footprints):
            if footprint_key not in section["footprints"]:
                add_error(f"Batch 001c must cover footprint {footprint_key}")
        for biome_id in sorted(biomes.keys()):
            if int(section["biome_counts"].get(biome_id, 0)) < 7:
                add_error(f"Batch 001c must include at least 7 blocker/edge definitions for {biome_id}")
        required_intent_tokens = {
            "route shoulder": "route_shoulder",
            "water edge": "water_edge",
            "forest boundary": "forest_boundary",
            "cliff edge": "cliff_edge",
            "rail embankment": "rail_embankment",
            "reef": "reef",
            "biome transition": "transition",
        }
        joined_edge_intents = " ".join(section["edge_intents"])
        for label, token in required_intent_tokens.items():
            if token not in joined_edge_intents:
                add_error(f"Batch 001c must include edge-blocker intent for {label}")
        for token_key, covered in section["content_token_coverage"].items():
            if not covered:
                add_error(f"Batch 001c must include blocker vocabulary for {token_key}")
    return section


def build_overworld_object_content_batch_001d_section(map_objects: dict[str, dict], biomes: dict[str, dict]) -> dict:
    batch_objects = {
        object_id: obj
        for object_id, obj in map_objects.items()
        if str(obj.get("content_batch_id", "")) == OVERWORLD_OBJECT_CONTENT_BATCH_001D_ID
    }
    decoration_or_blocker_count = sum(
        1
        for obj in map_objects.values()
        if str(obj.get("primary_class", infer_overworld_object_primary_class(obj, None))) == "decoration"
        and str(obj.get("passability_class", infer_overworld_object_passability_class(obj)))
        in {"passable_scenic", "blocking_non_visitable", "edge_blocker"}
    )
    section = {
        "batch_id": OVERWORLD_OBJECT_CONTENT_BATCH_001D_ID,
        "object_count": len(batch_objects),
        "decoration_or_blocker_total_count": decoration_or_blocker_count,
        "passable_scenic_count": 0,
        "blocking_non_visitable_count": 0,
        "edge_blocker_count": 0,
        "partial_body_mask_count": 0,
        "large_footprint_count": 0,
        "footprints": {},
        "biome_counts": {},
        "edge_intents": [],
        "content_token_coverage": {},
        "errors": [],
        "warnings": [],
    }

    def add_error(message: str) -> None:
        if message not in section["errors"]:
            section["errors"].append(message)

    required_content_tokens = {
        "cliff_band": ("cliff",),
        "elder_root": ("elder root", "root"),
        "wreck_field": ("wreck", "quay"),
        "cavern_wall": ("cavern", "underway"),
        "icefall": ("icefall",),
        "slag_wall": ("slag", "clinker"),
        "shoreline_shelf": ("shore", "reef", "coast"),
        "transition": ("transition", "grass-ridge", "forest-highland", "mire-coast", "ash-badland"),
    }
    token_hits = {key: False for key in required_content_tokens.keys()}

    for object_id, obj in sorted(batch_objects.items()):
        primary_class = str(obj.get("primary_class", infer_overworld_object_primary_class(obj, None)))
        passability_class = str(obj.get("passability_class", infer_overworld_object_passability_class(obj)))
        footprint = obj.get("footprint", {}) if isinstance(obj.get("footprint", {}), dict) else {}
        width = int(footprint.get("width", 0))
        height = int(footprint.get("height", 0))
        footprint_key = f"{width}x{height}"
        increment_count(section["footprints"], footprint_key)
        if width >= 5 or height >= 5:
            section["large_footprint_count"] += 1
        for biome_id in obj.get("biome_ids", []) if isinstance(obj.get("biome_ids", []), list) else []:
            increment_count(section["biome_counts"], str(biome_id))
        forbidden_wood_alias = "tim" + "ber"
        text_key = f"{object_id} {obj.get('name', '')}".lower()
        if forbidden_wood_alias in text_key:
            add_error(f"{object_id}: Batch 001d must keep wood canonical and avoid non-canonical wood aliases")
        for token_key, token_options in required_content_tokens.items():
            if any(token in text_key for token in token_options):
                token_hits[token_key] = True
        if primary_class != "decoration":
            add_error(f"{object_id}: Batch 001d objects must be decorations")
        if bool(obj.get("visitable", False)):
            add_error(f"{object_id}: Batch 001d objects must set visitable=false")
        if passability_class == "passable_scenic":
            section["passable_scenic_count"] += 1
            if bool(obj.get("passable", False)) is not True:
                add_error(f"{object_id}: Batch 001d passable scenic objects must set passable=true")
            body_tiles = obj.get("body_tiles", [])
            if body_tiles not in ([], None):
                add_error(f"{object_id}: Batch 001d passable scenic objects must keep empty body_tiles")
        elif passability_class in {"blocking_non_visitable", "edge_blocker"}:
            if passability_class == "blocking_non_visitable":
                section["blocking_non_visitable_count"] += 1
            else:
                section["edge_blocker_count"] += 1
            if bool(obj.get("passable", True)):
                add_error(f"{object_id}: Batch 001d blocking and edge-blocker objects must set passable=false")
            body_tiles = obj.get("body_tiles", [])
            if not isinstance(body_tiles, list) or not body_tiles:
                add_error(f"{object_id}: Batch 001d blocking and edge-blocker objects must author non-empty body_tiles")
            else:
                seen_body_tiles: set[str] = set()
                for tile in body_tiles:
                    if not isinstance(tile, dict):
                        add_error(f"{object_id}: body_tiles entries must be dictionaries")
                        continue
                    x = int(tile.get("x", -999))
                    y = int(tile.get("y", -999))
                    if x < 0 or y < 0 or x >= width or y >= height:
                        add_error(f"{object_id}: body tile {x},{y} is outside footprint")
                    tile_key = f"{x},{y}"
                    if tile_key in seen_body_tiles:
                        add_error(f"{object_id}: body tile {tile_key} is duplicated")
                    seen_body_tiles.add(tile_key)
                if width > 0 and height > 0 and len(seen_body_tiles) < width * height:
                    section["partial_body_mask_count"] += 1
        else:
            add_error(f"{object_id}: Batch 001d objects must use passable_scenic, blocking_non_visitable, or edge_blocker")
        if passability_class == "edge_blocker":
            edge = obj.get("edge_blocker", {})
            if not isinstance(edge, dict) or not edge:
                add_error(f"{object_id}: edge_blocker objects must define edge_blocker metadata")
            else:
                edge_intent = str(edge.get("edge_intent", ""))
                if not edge_intent:
                    add_error(f"{object_id}: edge_blocker metadata must define edge_intent")
                else:
                    append_unique(section["edge_intents"], edge_intent)
                protected_sides = edge.get("protected_sides", [])
                if not isinstance(protected_sides, list) or not protected_sides:
                    add_error(f"{object_id}: edge_blocker metadata must define protected_sides")
        if str(obj.get("resource_site_id", "")):
            add_error(f"{object_id}: Batch 001d objects must not link resource_site_id")
        if isinstance(obj.get("staged_resource_pickup", {}), dict) and obj.get("staged_resource_pickup", {}):
            add_error(f"{object_id}: Batch 001d objects must not author staged_resource_pickup")
        if isinstance(obj.get("rewards", {}), dict) and obj.get("rewards", {}):
            add_error(f"{object_id}: Batch 001d objects must not author rewards")

    section["footprints"] = sorted_counts(section["footprints"])
    section["biome_counts"] = dict(sorted(section["biome_counts"].items()))
    section["edge_intents"] = sorted(section["edge_intents"])
    section["content_token_coverage"] = dict(sorted(token_hits.items()))
    if batch_objects:
        if not (46 <= len(batch_objects) <= 50):
            add_error("Batch 001d must author about 48 object definitions")
        if section["passable_scenic_count"] + section["blocking_non_visitable_count"] + section["edge_blocker_count"] != len(batch_objects):
            add_error("Batch 001d must be non-interactable decoration/blocker-only")
        if section["decoration_or_blocker_total_count"] < 199:
            add_error("Batch 001d must bring decoration/blocker coverage near the 200-object foundation target")
        if section["large_footprint_count"] != len(batch_objects):
            add_error("Batch 001d objects must all use large-footprint silhouettes")
        if section["partial_body_mask_count"] < 32:
            add_error("Batch 001d must include broad partial/non-rectangular body-mask coverage")
        required_footprints = {"5x2", "5x3", "6x3", "6x4", "6x6"}
        for footprint_key in sorted(required_footprints):
            if footprint_key not in section["footprints"]:
                add_error(f"Batch 001d must cover footprint {footprint_key}")
        for biome_id in sorted(biomes.keys()):
            if int(section["biome_counts"].get(biome_id, 0)) < 5:
                add_error(f"Batch 001d must include at least 5 large-footprint definitions for {biome_id}")
        if section["passable_scenic_count"] < 6:
            add_error("Batch 001d must include large passable scenic overhang/shadow variants")
        if section["blocking_non_visitable_count"] < 12:
            add_error("Batch 001d must include substantial large blocking_non_visitable coverage")
        if section["edge_blocker_count"] < 18:
            add_error("Batch 001d must include substantial large edge_blocker coverage")
        if len(section["edge_intents"]) < 12:
            add_error("Batch 001d must include varied large edge-blocker intents")
        for token_key, covered in section["content_token_coverage"].items():
            if not covered:
                add_error(f"Batch 001d must include large-footprint vocabulary for {token_key}")
    return section


def build_overworld_object_content_batch_002_section(map_objects: dict[str, dict], resource_sites: dict[str, dict], biomes: dict[str, dict]) -> dict:
    batch_objects = {
        object_id: obj
        for object_id, obj in map_objects.items()
        if str(obj.get("content_batch_id", "")) == OVERWORLD_OBJECT_CONTENT_BATCH_002_ID
        or str(obj.get("normalized_content_batch_id", "")) == OVERWORLD_OBJECT_CONTENT_BATCH_002_ID
    }
    section = {
        "batch_id": OVERWORLD_OBJECT_CONTENT_BATCH_002_ID,
        "object_count": len(batch_objects),
        "common_mine_count": 0,
        "rare_resource_front_count": 0,
        "support_producer_count": 0,
        "normalized_resource_object_count": 0,
        "footprints": {},
        "biome_counts": {},
        "common_live_resource_ids": [],
        "staged_rare_resource_ids": [],
        "shape_contract_ready_count": 0,
        "linked_resource_site_count": 0,
        "staged_front_report_only_count": 0,
        "errors": [],
        "warnings": [],
    }

    def add_error(message: str) -> None:
        if message not in section["errors"]:
            section["errors"].append(message)

    def add_warning(message: str) -> None:
        if message not in section["warnings"]:
            section["warnings"].append(message)

    def live_resource_ids(site: dict) -> set[str]:
        ids: set[str] = set()
        for field in ("rewards", "claim_rewards", "control_income", "service_cost"):
            values = site.get(field, {})
            if isinstance(values, dict):
                ids.update(str(resource_id) for resource_id in values.keys())
        response_cost = site.get("response_profile", {}).get("resource_cost", {}) if isinstance(site.get("response_profile", {}), dict) else {}
        if isinstance(response_cost, dict):
            ids.update(str(resource_id) for resource_id in response_cost.keys())
        return ids

    def check_body_and_approach(object_id: str, obj: dict, width: int, height: int) -> bool:
        body_tiles = obj.get("body_tiles", [])
        approach = obj.get("approach", {}) if isinstance(obj.get("approach", {}), dict) else {}
        visit_offsets = approach.get("visit_offsets", []) if isinstance(approach.get("visit_offsets", []), list) else []
        ready = True
        if not isinstance(body_tiles, list) or not body_tiles:
            add_error(f"{object_id}: Batch 002 objects must author non-empty body_tiles")
            ready = False
        if not isinstance(obj.get("approach", {}), dict) or not visit_offsets:
            add_error(f"{object_id}: Batch 002 objects must author approach.visit_offsets")
            ready = False
        seen_body_tiles: set[str] = set()
        for tile in body_tiles if isinstance(body_tiles, list) else []:
            if not isinstance(tile, dict):
                add_error(f"{object_id}: body_tiles entries must be dictionaries")
                ready = False
                continue
            x = int(tile.get("x", -999))
            y = int(tile.get("y", -999))
            if x < 0 or y < 0 or x >= width or y >= height:
                add_error(f"{object_id}: body tile {x},{y} is outside footprint")
                ready = False
            tile_key = f"{x},{y}"
            if tile_key in seen_body_tiles:
                add_error(f"{object_id}: body tile {tile_key} is duplicated")
                ready = False
            seen_body_tiles.add(tile_key)
        seen_visit_offsets: set[str] = set()
        for tile in visit_offsets:
            if not isinstance(tile, dict):
                add_error(f"{object_id}: approach.visit_offsets entries must be dictionaries")
                ready = False
                continue
            x = int(tile.get("x", -999))
            y = int(tile.get("y", -999))
            adjacent = (x == -1 and 0 <= y < height) or (x == width and 0 <= y < height) or (y == -1 and 0 <= x < width) or (y == height and 0 <= x < width)
            inside = 0 <= x < width and 0 <= y < height
            if not adjacent and not inside:
                add_error(f"{object_id}: approach tile {x},{y} must be inside or adjacent to footprint")
                ready = False
            tile_key = f"{x},{y}"
            if tile_key in seen_visit_offsets:
                add_error(f"{object_id}: approach tile {tile_key} is duplicated")
                ready = False
            seen_visit_offsets.add(tile_key)
        if seen_body_tiles.intersection(seen_visit_offsets):
            add_error(f"{object_id}: body_tiles must not overlap approach.visit_offsets")
            ready = False
        if str(approach.get("mode", "")) not in {"adjacent", "enter"}:
            add_error(f"{object_id}: approach.mode must be adjacent or enter")
            ready = False
        return ready

    for object_id, obj in sorted(batch_objects.items()):
        role = str(obj.get("batch002_role", ""))
        site_id = str(obj.get("resource_site_id", ""))
        site = resource_sites.get(site_id, {}) if site_id else {}
        footprint = obj.get("footprint", {}) if isinstance(obj.get("footprint", {}), dict) else {}
        width = int(footprint.get("width", 0))
        height = int(footprint.get("height", 0))
        footprint_key = f"{width}x{height}"
        increment_count(section["footprints"], footprint_key)
        for biome_id in obj.get("biome_ids", []) if isinstance(obj.get("biome_ids", []), list) else []:
            increment_count(section["biome_counts"], str(biome_id))
        forbidden_wood_alias = "tim" + "ber"
        text_key = f"{object_id} {obj.get('name', '')} {site_id} {site.get('name', '')}".lower()
        if forbidden_wood_alias in text_key:
            add_error(f"{object_id}: Batch 002 must keep wood canonical and avoid non-canonical wood aliases")
        if role == "common_mine":
            section["common_mine_count"] += 1
        elif role == "rare_resource_front":
            section["rare_resource_front_count"] += 1
        elif role == "support_producer":
            section["support_producer_count"] += 1
        elif role == "normalized_resource_object":
            section["normalized_resource_object_count"] += 1
        else:
            add_error(f"{object_id}: Batch 002 object must author a supported batch002_role")
        if not site_id or site_id not in resource_sites:
            add_error(f"{object_id}: Batch 002 object must link an existing resource_site_id")
        else:
            section["linked_resource_site_count"] += 1
            if str(site.get("content_batch_id", "")) != OVERWORLD_OBJECT_CONTENT_BATCH_002_ID and str(site.get("normalized_content_batch_id", "")) != OVERWORLD_OBJECT_CONTENT_BATCH_002_ID:
                add_error(f"{object_id}: linked site {site_id} must carry Batch 002 content metadata")
        if width <= 0 or height <= 0:
            add_error(f"{object_id}: Batch 002 footprint dimensions must be positive")
        if str(footprint.get("anchor", "")) not in OVERWORLD_OBJECT_FOOTPRINT_ANCHORS:
            add_error(f"{object_id}: Batch 002 footprint.anchor is missing or unsupported")
        if str(footprint.get("tier", "")) not in OVERWORLD_OBJECT_FOOTPRINT_TIERS:
            add_error(f"{object_id}: Batch 002 footprint.tier is missing or unsupported")
        if str(obj.get("passability_class", "")) != "blocking_visitable":
            add_error(f"{object_id}: Batch 002 objects must use blocking_visitable")
        if bool(obj.get("passable", True)):
            add_error(f"{object_id}: Batch 002 objects must set passable=false")
        if not bool(obj.get("visitable", False)):
            add_error(f"{object_id}: Batch 002 objects must set visitable=true")
        if check_body_and_approach(object_id, obj, width, height):
            section["shape_contract_ready_count"] += 1
        if not isinstance(obj.get("ai_hints", {}), dict) or not obj.get("ai_hints", {}):
            add_error(f"{object_id}: Batch 002 objects must author ai_hints")
        if not isinstance(obj.get("editor_placement", {}), dict) or not obj.get("editor_placement", {}):
            add_error(f"{object_id}: Batch 002 objects must author editor_placement")
        if not isinstance(obj.get("interaction", {}), dict) or str(obj.get("interaction", {}).get("cadence", "")) not in {"persistent_control", "cooldown_days"}:
            add_error(f"{object_id}: Batch 002 objects must author persistent/control or cooldown interaction metadata")

        live_ids = live_resource_ids(site)
        if live_ids.intersection(ECONOMY_RARE_RESOURCE_IDS):
            add_error(f"{object_id}: staged rare resources must not appear in live reward, income, service, or response-cost fields")
        for resource_id in sorted(live_ids.intersection(ECONOMY_STOCKPILE_RESOURCE_IDS)):
            append_unique(section["common_live_resource_ids"], resource_id)
        if role in {"common_mine", "support_producer"}:
            resource_outputs = site.get("resource_outputs", [])
            if not isinstance(resource_outputs, list) or not resource_outputs:
                add_error(f"{object_id}: live mine/support producer site must author resource_outputs")
            if not isinstance(site.get("capture_profile", {}), dict) or not site.get("capture_profile", {}):
                add_error(f"{object_id}: live mine/support producer site must author capture_profile")
        if role == "rare_resource_front":
            staged_object = obj.get("staged_resource_front", {}) if isinstance(obj.get("staged_resource_front", {}), dict) else {}
            staged_outputs = site.get("staged_resource_outputs", []) if isinstance(site.get("staged_resource_outputs", []), list) else []
            if not staged_object:
                add_error(f"{object_id}: rare-resource front must author staged_resource_front metadata")
            resource_id = str(staged_object.get("resource_id", ""))
            if resource_id:
                append_unique(section["staged_rare_resource_ids"], resource_id)
            if resource_id not in ECONOMY_RARE_RESOURCE_IDS:
                add_error(f"{object_id}: rare-resource front uses unsupported rare resource {resource_id}")
            if str(staged_object.get("activation_status", "")) != "staged_report_only" or not bool(staged_object.get("report_only", False)) or bool(staged_object.get("live_reward", True)):
                add_error(f"{object_id}: rare-resource front object metadata must remain staged/report-only")
            if not staged_outputs:
                add_error(f"{object_id}: rare-resource front site must author staged_resource_outputs")
            else:
                for output in staged_outputs:
                    output_resource_id = str(output.get("resource_id", "")) if isinstance(output, dict) else ""
                    if output_resource_id:
                        append_unique(section["staged_rare_resource_ids"], output_resource_id)
                    if output_resource_id not in ECONOMY_RARE_RESOURCE_IDS:
                        add_error(f"{object_id}: staged_resource_outputs uses unsupported rare resource {output_resource_id}")
                    if not isinstance(output, dict) or str(output.get("activation_status", "")) != "staged_report_only" or not bool(output.get("report_only", False)) or bool(output.get("live_reward", True)):
                        add_error(f"{object_id}: staged_resource_outputs must remain report-only and non-live")
                section["staged_front_report_only_count"] += 1
            if not isinstance(site.get("guard_profile", {}), dict) or not site.get("guard_profile", {}):
                add_error(f"{object_id}: rare-resource front must author guard_profile expectation metadata")

    section["footprints"] = sorted_counts(section["footprints"])
    section["biome_counts"] = dict(sorted(section["biome_counts"].items()))
    section["common_live_resource_ids"] = sorted(section["common_live_resource_ids"])
    section["staged_rare_resource_ids"] = sorted(section["staged_rare_resource_ids"])
    if batch_objects:
        if len(batch_objects) != 28:
            add_error("Batch 002 must contain exactly 28 new or normalized object definitions")
        if section["common_mine_count"] < 9:
            add_error("Batch 002 must include at least 9 common live-resource mines/fronts")
        if section["rare_resource_front_count"] != 9:
            add_error("Batch 002 must include 9 staged rare-resource fronts")
        if section["support_producer_count"] != 6:
            add_error("Batch 002 must include 6 support producer buildings")
        if section["normalized_resource_object_count"] < 1:
            add_error("Batch 002 must include selected existing resource-object normalization")
        if section["linked_resource_site_count"] != len(batch_objects):
            add_error("Batch 002 objects must all link resource-site records")
        if section["shape_contract_ready_count"] != len(batch_objects):
            add_error("Batch 002 objects must all pass footprint/body/approach contract checks")
        for resource_id in ("gold", "wood", "ore"):
            if resource_id not in section["common_live_resource_ids"]:
                add_error(f"Batch 002 common live resources must include {resource_id}")
        for resource_id in ECONOMY_STAGED_RARE_RESOURCE_IDS:
            if resource_id not in section["staged_rare_resource_ids"]:
                add_error(f"Batch 002 staged rare fronts must include {resource_id}")
        for footprint_key in ("2x2", "2x3", "3x2", "3x3"):
            if footprint_key not in section["footprints"]:
                add_error(f"Batch 002 must cover footprint {footprint_key}")
        for biome_id in sorted(biomes.keys()):
            if int(section["biome_counts"].get(biome_id, 0)) < 2:
                add_error(f"Batch 002 must include at least 2 mine/resource-front/support definitions for {biome_id}")
    return section


def build_overworld_object_content_batch_003_section(map_objects: dict[str, dict], resource_sites: dict[str, dict], biomes: dict[str, dict]) -> dict:
    batch_objects = {
        object_id: obj
        for object_id, obj in map_objects.items()
        if str(obj.get("content_batch_id", "")) == OVERWORLD_OBJECT_CONTENT_BATCH_003_ID
        or str(obj.get("normalized_content_batch_id", "")) == OVERWORLD_OBJECT_CONTENT_BATCH_003_ID
    }
    role_contract_keys = {
        "repeatable_service": "service_contract",
        "shrine_progression": "shrine_contract",
        "scouting_info": "scouting_contract",
        "sign_waypoint": "sign_contract",
        "route_lock": "route_lock_contract",
        "objective_event": "objective_event_contract",
    }
    expected_role_counts = {
        "repeatable_service": 6,
        "shrine_progression": 6,
        "scouting_info": 5,
        "sign_waypoint": 5,
        "route_lock": 3,
        "objective_event": 3,
    }
    section = {
        "batch_id": OVERWORLD_OBJECT_CONTENT_BATCH_003_ID,
        "object_count": len(batch_objects),
        "role_counts": {},
        "cadence_counts": {},
        "footprints": {},
        "biome_counts": {},
        "shape_contract_ready_count": 0,
        "linked_resource_site_count": 0,
        "metadata_only_boundary_count": 0,
        "route_lock_metadata_count": 0,
        "no_live_reward_activation_count": 0,
        "errors": [],
        "warnings": [],
    }

    def add_error(message: str) -> None:
        if message not in section["errors"]:
            section["errors"].append(message)

    def live_resource_ids(site: dict) -> set[str]:
        ids: set[str] = set()
        for field in ("rewards", "claim_rewards", "control_income", "service_cost"):
            values = site.get(field, {})
            if isinstance(values, dict):
                ids.update(str(resource_id) for resource_id in values.keys())
        outputs = site.get("resource_outputs", [])
        if isinstance(outputs, list):
            for output in outputs:
                if isinstance(output, dict) and str(output.get("resource_id", "")):
                    ids.add(str(output.get("resource_id", "")))
        response_cost = site.get("response_profile", {}).get("resource_cost", {}) if isinstance(site.get("response_profile", {}), dict) else {}
        if isinstance(response_cost, dict):
            ids.update(str(resource_id) for resource_id in response_cost.keys())
        route_toll = site.get("route_effect", {}).get("toll_resources", {}) if isinstance(site.get("route_effect", {}), dict) else {}
        if isinstance(route_toll, dict):
            ids.update(str(resource_id) for resource_id in route_toll.keys())
        return ids

    def metadata_boundary_is_safe(payload: dict) -> bool:
        boundary = payload.get("runtime_boundary", {}) if isinstance(payload.get("runtime_boundary", {}), dict) else {}
        return (
            str(boundary.get("status", "")) == "metadata_only"
            and not bool(boundary.get("live_reward_grants", True))
            and not bool(boundary.get("save_payload_required", True))
            and not bool(boundary.get("renderer_sprite_required", True))
            and not bool(boundary.get("pathing_runtime_adopted", True))
            and not bool(boundary.get("route_effect_runtime_adopted", True))
            and not bool(boundary.get("rare_resource_activation", True))
        )

    def check_body_and_approach(object_id: str, obj: dict, width: int, height: int) -> bool:
        body_tiles = obj.get("body_tiles", [])
        approach = obj.get("approach", {}) if isinstance(obj.get("approach", {}), dict) else {}
        visit_offsets = approach.get("visit_offsets", []) if isinstance(approach.get("visit_offsets", []), list) else []
        ready = True
        if not isinstance(body_tiles, list) or not body_tiles:
            add_error(f"{object_id}: Batch 003 objects must author non-empty body_tiles")
            ready = False
        if not isinstance(obj.get("approach", {}), dict) or not visit_offsets:
            add_error(f"{object_id}: Batch 003 objects must author approach.visit_offsets")
            ready = False
        seen_body_tiles: set[str] = set()
        for tile in body_tiles if isinstance(body_tiles, list) else []:
            if not isinstance(tile, dict):
                add_error(f"{object_id}: body_tiles entries must be dictionaries")
                ready = False
                continue
            x = int(tile.get("x", -999))
            y = int(tile.get("y", -999))
            if x < 0 or y < 0 or x >= width or y >= height:
                add_error(f"{object_id}: body tile {x},{y} is outside footprint")
                ready = False
            tile_key = f"{x},{y}"
            if tile_key in seen_body_tiles:
                add_error(f"{object_id}: body tile {tile_key} is duplicated")
                ready = False
            seen_body_tiles.add(tile_key)
        seen_visit_offsets: set[str] = set()
        for tile in visit_offsets:
            if not isinstance(tile, dict):
                add_error(f"{object_id}: approach.visit_offsets entries must be dictionaries")
                ready = False
                continue
            x = int(tile.get("x", -999))
            y = int(tile.get("y", -999))
            adjacent = (x == -1 and 0 <= y < height) or (x == width and 0 <= y < height) or (y == -1 and 0 <= x < width) or (y == height and 0 <= x < width)
            inside = 0 <= x < width and 0 <= y < height
            if not adjacent and not inside:
                add_error(f"{object_id}: approach tile {x},{y} must be inside or adjacent to footprint")
                ready = False
            tile_key = f"{x},{y}"
            if tile_key in seen_visit_offsets:
                add_error(f"{object_id}: approach tile {tile_key} is duplicated")
                ready = False
            seen_visit_offsets.add(tile_key)
        if seen_body_tiles.intersection(seen_visit_offsets) and str(approach.get("mode", "")) != "enter":
            add_error(f"{object_id}: body_tiles must not overlap approach.visit_offsets for adjacent visits")
            ready = False
        if str(approach.get("mode", "")) not in {"adjacent", "enter", "linked_endpoint"}:
            add_error(f"{object_id}: approach.mode must be adjacent, enter, or linked_endpoint")
            ready = False
        return ready

    for object_id, obj in sorted(batch_objects.items()):
        role = str(obj.get("batch003_role", ""))
        site_id = str(obj.get("resource_site_id", ""))
        site = resource_sites.get(site_id, {}) if site_id else {}
        footprint = obj.get("footprint", {}) if isinstance(obj.get("footprint", {}), dict) else {}
        width = int(footprint.get("width", 0))
        height = int(footprint.get("height", 0))
        footprint_key = f"{width}x{height}"
        increment_count(section["role_counts"], role)
        increment_count(section["footprints"], footprint_key)
        interaction = obj.get("interaction", {}) if isinstance(obj.get("interaction", {}), dict) else {}
        increment_count(section["cadence_counts"], str(interaction.get("cadence", "")))
        for biome_id in obj.get("biome_ids", []) if isinstance(obj.get("biome_ids", []), list) else []:
            increment_count(section["biome_counts"], str(biome_id))

        forbidden_wood_alias = "tim" + "ber"
        text_key = json.dumps({"object": obj, "site": site}, sort_keys=True).lower()
        if forbidden_wood_alias in text_key:
            add_error(f"{object_id}: Batch 003 must keep wood canonical and avoid non-canonical wood aliases")
        if role not in role_contract_keys:
            add_error(f"{object_id}: Batch 003 object must author a supported batch003_role")
        if not site_id or site_id not in resource_sites:
            add_error(f"{object_id}: Batch 003 object must link an existing resource_site_id")
        else:
            section["linked_resource_site_count"] += 1
            if str(site.get("content_batch_id", "")) != OVERWORLD_OBJECT_CONTENT_BATCH_003_ID and str(site.get("normalized_content_batch_id", "")) != OVERWORLD_OBJECT_CONTENT_BATCH_003_ID:
                add_error(f"{object_id}: linked site {site_id} must carry Batch 003 content metadata")
            contract_key = role_contract_keys.get(role, "")
            if contract_key and (not isinstance(obj.get(contract_key, {}), dict) or not isinstance(site.get(contract_key, {}), dict)):
                add_error(f"{object_id}: Batch 003 {role} must author {contract_key} on object and linked site")
        if width <= 0 or height <= 0:
            add_error(f"{object_id}: Batch 003 footprint dimensions must be positive")
        if str(footprint.get("anchor", "")) not in OVERWORLD_OBJECT_FOOTPRINT_ANCHORS:
            add_error(f"{object_id}: Batch 003 footprint.anchor is missing or unsupported")
        if str(footprint.get("tier", "")) not in OVERWORLD_OBJECT_FOOTPRINT_TIERS:
            add_error(f"{object_id}: Batch 003 footprint.tier is missing or unsupported")
        if str(obj.get("passability_class", "")) not in {"blocking_visitable", "conditional_pass", "passable_visit_on_enter"}:
            add_error(f"{object_id}: Batch 003 passability must be visitable or conditional-pass metadata")
        if not bool(obj.get("visitable", False)):
            add_error(f"{object_id}: Batch 003 objects must set visitable=true")
        if check_body_and_approach(object_id, obj, width, height):
            section["shape_contract_ready_count"] += 1
        if not isinstance(obj.get("guard_expectation", {}), dict) or not obj.get("guard_expectation", {}):
            add_error(f"{object_id}: Batch 003 objects must author guard_expectation metadata")
        if not isinstance(obj.get("ai_hints", {}), dict) or not obj.get("ai_hints", {}):
            add_error(f"{object_id}: Batch 003 objects must author ai_hints")
        if not isinstance(obj.get("editor_placement", {}), dict) or not obj.get("editor_placement", {}):
            add_error(f"{object_id}: Batch 003 objects must author editor_placement")
        if str(interaction.get("cadence", "")) not in {"one_time", "repeatable_daily", "repeatable_weekly", "cooldown_days", "persistent_control", "conditional", "scenario_scripted"}:
            add_error(f"{object_id}: Batch 003 interaction cadence is missing or unsupported")
        if metadata_boundary_is_safe(obj) and metadata_boundary_is_safe(site):
            section["metadata_only_boundary_count"] += 1
        else:
            add_error(f"{object_id}: Batch 003 object and site must keep explicit metadata-only runtime boundaries")

        live_ids = live_resource_ids(site)
        if live_ids.intersection(ECONOMY_RARE_RESOURCE_IDS):
            add_error(f"{object_id}: Batch 003 must not activate rare resources in live site fields")
        if any(field in site for field in ("rewards", "claim_rewards", "control_income", "resource_outputs")):
            add_error(f"{object_id}: Batch 003 service/shrine/sign/event sites must not add live reward or income fields")
        else:
            section["no_live_reward_activation_count"] += 1
        if "market_profile" in site or "exchange_rates" in site:
            add_error(f"{object_id}: Batch 003 must not activate market profiles or exchange rates")

        if role == "route_lock":
            route_effect = obj.get("route_effect", {}) if isinstance(obj.get("route_effect", {}), dict) else {}
            boundary = obj.get("route_effect_boundary", {}) if isinstance(obj.get("route_effect_boundary", {}), dict) else {}
            if not route_effect:
                add_error(f"{object_id}: route locks must author route_effect metadata")
            if str(boundary.get("status", "")) != "metadata_only" or bool(boundary.get("runtime_behavior_adopted", True)):
                add_error(f"{object_id}: route locks must keep route_effect runtime adoption disabled")
            if str(route_effect.get("effect_type", "")) not in {"scenario_gate", "repair_unlock", "conditional_pass"}:
                add_error(f"{object_id}: route lock route_effect type must stay a metadata-safe lock type")
            if not isinstance(route_effect.get("blocked_state_ids", []), list) or not route_effect.get("blocked_state_ids", []):
                add_error(f"{object_id}: route locks must define blocked_state_ids")
            toll_resources = route_effect.get("toll_resources", {})
            if not isinstance(toll_resources, dict) or set(str(resource_id) for resource_id in toll_resources.keys()).intersection(ECONOMY_RARE_RESOURCE_IDS):
                add_error(f"{object_id}: route locks must not use rare-resource toll metadata")
            for public_key in ("public_reason", "public_summary", "display_name"):
                if public_key in route_effect:
                    public_text = str(route_effect.get(public_key, ""))
                    for token in OVERWORLD_OBJECT_PUBLIC_ROUTE_LEAK_TOKENS:
                        if token in public_text:
                            add_error(f"{object_id}: route_effect.{public_key} leaks internal token {token}")
            section["route_lock_metadata_count"] += 1
        if role == "repeatable_service" and (not bool(site.get("repeatable", False)) or int(site.get("visit_cooldown_days", 0)) <= 0):
            add_error(f"{object_id}: repeatable services must define repeatable site cooldown metadata")
        if role == "scouting_info" and int(site.get("vision_radius", 0)) <= 0:
            add_error(f"{object_id}: scouting/info objects must define vision_radius metadata")

    section["role_counts"] = sorted_counts(section["role_counts"])
    section["cadence_counts"] = sorted_counts(section["cadence_counts"])
    section["footprints"] = sorted_counts(section["footprints"])
    section["biome_counts"] = dict(sorted(section["biome_counts"].items()))
    if batch_objects:
        if len(batch_objects) != 28:
            add_error("Batch 003 must contain exactly 28 service/shrine/sign/event object definitions")
        for role, expected_count in expected_role_counts.items():
            if int(section["role_counts"].get(role, 0)) != expected_count:
                add_error(f"Batch 003 must include {expected_count} {role} objects")
        if section["linked_resource_site_count"] != len(batch_objects):
            add_error("Batch 003 objects must all link resource-site records")
        if section["shape_contract_ready_count"] != len(batch_objects):
            add_error("Batch 003 objects must all pass footprint/body/approach contract checks")
        if section["metadata_only_boundary_count"] != len(batch_objects):
            add_error("Batch 003 objects and sites must all remain metadata-only runtime contracts")
        if section["no_live_reward_activation_count"] != len(batch_objects):
            add_error("Batch 003 must not add live reward, income, or production fields")
        if section["route_lock_metadata_count"] != expected_role_counts["route_lock"]:
            add_error("Batch 003 route locks must all carry safe route-effect metadata")
        for cadence in ("cooldown_days", "one_time", "repeatable_weekly", "persistent_control", "repeatable_daily", "conditional", "scenario_scripted"):
            if cadence not in section["cadence_counts"]:
                add_error(f"Batch 003 must cover interaction cadence {cadence}")
        for biome_id in sorted(biomes.keys()):
            if int(section["biome_counts"].get(biome_id, 0)) < 2:
                add_error(f"Batch 003 must include at least 2 service/shrine/sign/event definitions for {biome_id}")
        for footprint_key in ("1x1", "1x2", "2x1", "2x2"):
            if footprint_key not in section["footprints"]:
                add_error(f"Batch 003 must cover footprint {footprint_key}")
    return section


def build_overworld_object_content_batch_004_section(map_objects: dict[str, dict], resource_sites: dict[str, dict], biomes: dict[str, dict]) -> dict:
    batch_objects = {
        object_id: obj
        for object_id, obj in map_objects.items()
        if str(obj.get("content_batch_id", "")) == OVERWORLD_OBJECT_CONTENT_BATCH_004_ID
        or str(obj.get("normalized_content_batch_id", "")) == OVERWORLD_OBJECT_CONTENT_BATCH_004_ID
    }
    expected_role_counts = {
        "two_way_transit": 6,
        "one_way_transit": 4,
        "route_lock": 6,
        "coast_harbor": 6,
        "route_waypoint": 2,
    }
    section = {
        "batch_id": OVERWORLD_OBJECT_CONTENT_BATCH_004_ID,
        "object_count": len(batch_objects),
        "role_counts": {},
        "directionality_counts": {},
        "footprints": {},
        "biome_counts": {},
        "shape_contract_ready_count": 0,
        "linked_resource_site_count": 0,
        "linked_endpoint_contract_count": 0,
        "route_effect_metadata_count": 0,
        "route_lock_contract_count": 0,
        "coast_applicability_count": 0,
        "metadata_only_boundary_count": 0,
        "no_rare_resource_activation_count": 0,
        "no_live_ship_system_count": 0,
        "normalized_existing_count": 0,
        "errors": [],
        "warnings": [],
    }

    def add_error(message: str) -> None:
        if message not in section["errors"]:
            section["errors"].append(message)

    def metadata_boundary_is_safe(payload: dict) -> bool:
        boundary = payload.get("runtime_boundary", {}) if isinstance(payload.get("runtime_boundary", {}), dict) else {}
        return (
            str(boundary.get("status", "")) == "metadata_only"
            and not bool(boundary.get("live_reward_grants", True))
            and not bool(boundary.get("save_payload_required", True))
            and not bool(boundary.get("renderer_sprite_required", True))
            and not bool(boundary.get("pathing_runtime_adopted", True))
            and not bool(boundary.get("route_effect_runtime_adopted", True))
            and not bool(boundary.get("rare_resource_activation", True))
            and not bool(boundary.get("ship_movement_runtime_adopted", True))
        )

    def live_resource_ids(site: dict, obj: dict) -> set[str]:
        ids: set[str] = set()
        for payload in (site, obj):
            for field in ("rewards", "claim_rewards", "control_income", "service_cost"):
                values = payload.get(field, {})
                if isinstance(values, dict):
                    ids.update(str(resource_id) for resource_id in values.keys())
            route_toll = payload.get("route_effect", {}).get("toll_resources", {}) if isinstance(payload.get("route_effect", {}), dict) else {}
            if isinstance(route_toll, dict):
                ids.update(str(resource_id) for resource_id in route_toll.keys())
        response_cost = site.get("response_profile", {}).get("resource_cost", {}) if isinstance(site.get("response_profile", {}), dict) else {}
        if isinstance(response_cost, dict):
            ids.update(str(resource_id) for resource_id in response_cost.keys())
        return ids

    def check_body_and_approach(object_id: str, obj: dict, width: int, height: int) -> bool:
        body_tiles = obj.get("body_tiles", [])
        approach = obj.get("approach", {}) if isinstance(obj.get("approach", {}), dict) else {}
        visit_offsets = approach.get("visit_offsets", []) if isinstance(approach.get("visit_offsets", []), list) else []
        linked_exit_offsets = approach.get("linked_exit_offsets", []) if isinstance(approach.get("linked_exit_offsets", []), list) else []
        ready = True
        if not isinstance(body_tiles, list) or not body_tiles:
            add_error(f"{object_id}: Batch 004 transit objects must author non-empty body_tiles")
            ready = False
        if not isinstance(obj.get("approach", {}), dict) or len(visit_offsets) < 2:
            add_error(f"{object_id}: Batch 004 transit objects must author at least two approach.visit_offsets")
            ready = False
        if len(linked_exit_offsets) != len(visit_offsets):
            add_error(f"{object_id}: linked_exit_offsets must match approach.visit_offsets")
            ready = False
        seen_body_tiles: set[str] = set()
        for tile in body_tiles if isinstance(body_tiles, list) else []:
            if not isinstance(tile, dict):
                add_error(f"{object_id}: body_tiles entries must be dictionaries")
                ready = False
                continue
            x = int(tile.get("x", -999))
            y = int(tile.get("y", -999))
            if x < 0 or y < 0 or x >= width or y >= height:
                add_error(f"{object_id}: body tile {x},{y} is outside footprint")
                ready = False
            tile_key = f"{x},{y}"
            if tile_key in seen_body_tiles:
                add_error(f"{object_id}: body tile {tile_key} is duplicated")
                ready = False
            seen_body_tiles.add(tile_key)
        seen_visit_offsets: set[str] = set()
        for tile in visit_offsets:
            if not isinstance(tile, dict):
                add_error(f"{object_id}: approach.visit_offsets entries must be dictionaries")
                ready = False
                continue
            x = int(tile.get("x", -999))
            y = int(tile.get("y", -999))
            adjacent = (x == -1 and 0 <= y < height) or (x == width and 0 <= y < height) or (y == -1 and 0 <= x < width) or (y == height and 0 <= x < width)
            if not adjacent:
                add_error(f"{object_id}: approach tile {x},{y} must be adjacent to footprint")
                ready = False
            tile_key = f"{x},{y}"
            if tile_key in seen_visit_offsets:
                add_error(f"{object_id}: approach tile {tile_key} is duplicated")
                ready = False
            seen_visit_offsets.add(tile_key)
        if seen_body_tiles.intersection(seen_visit_offsets):
            add_error(f"{object_id}: body_tiles must not overlap approach.visit_offsets")
            ready = False
        if str(approach.get("mode", "")) != "linked_endpoint":
            add_error(f"{object_id}: Batch 004 approach.mode must be linked_endpoint")
            ready = False
        return ready

    for object_id, obj in sorted(batch_objects.items()):
        role = str(obj.get("batch004_role", ""))
        site_id = str(obj.get("resource_site_id", ""))
        site = resource_sites.get(site_id, {}) if site_id else {}
        footprint = obj.get("footprint", {}) if isinstance(obj.get("footprint", {}), dict) else {}
        width = int(footprint.get("width", 0))
        height = int(footprint.get("height", 0))
        increment_count(section["role_counts"], role)
        increment_count(section["footprints"], f"{width}x{height}")
        for biome_id in obj.get("biome_ids", []) if isinstance(obj.get("biome_ids", []), list) else []:
            increment_count(section["biome_counts"], str(biome_id))
        if str(obj.get("normalized_content_batch_id", "")) == OVERWORLD_OBJECT_CONTENT_BATCH_004_ID:
            section["normalized_existing_count"] += 1

        forbidden_wood_alias = "tim" + "ber"
        text_key = json.dumps({"object": obj, "site": site}, sort_keys=True).lower()
        if forbidden_wood_alias in text_key:
            add_error(f"{object_id}: Batch 004 must keep wood canonical and avoid non-canonical wood aliases")
        if role not in expected_role_counts:
            add_error(f"{object_id}: Batch 004 object must author a supported batch004_role")
        if str(obj.get("family", "")) != "transit_object" or str(obj.get("primary_class", "")) != "transit_route_object":
            add_error(f"{object_id}: Batch 004 objects must remain transit_route_object map objects")
        if not site_id or site_id not in resource_sites:
            add_error(f"{object_id}: Batch 004 object must link an existing resource_site_id")
        else:
            section["linked_resource_site_count"] += 1
            if str(site.get("content_batch_id", "")) != OVERWORLD_OBJECT_CONTENT_BATCH_004_ID and str(site.get("normalized_content_batch_id", "")) != OVERWORLD_OBJECT_CONTENT_BATCH_004_ID:
                add_error(f"{object_id}: linked site {site_id} must carry Batch 004 content metadata")
            if not isinstance(site.get("transit_profile", {}), dict) or not site.get("transit_profile", {}):
                add_error(f"{object_id}: linked site {site_id} must author transit_profile metadata")
        if width <= 0 or height <= 0:
            add_error(f"{object_id}: Batch 004 footprint dimensions must be positive")
        if str(footprint.get("anchor", "")) not in OVERWORLD_OBJECT_FOOTPRINT_ANCHORS:
            add_error(f"{object_id}: Batch 004 footprint.anchor is missing or unsupported")
        if str(footprint.get("tier", "")) not in OVERWORLD_OBJECT_FOOTPRINT_TIERS:
            add_error(f"{object_id}: Batch 004 footprint.tier is missing or unsupported")
        if str(obj.get("passability_class", "")) != "conditional_pass":
            add_error(f"{object_id}: Batch 004 objects must use conditional_pass")
        interaction = obj.get("interaction", {}) if isinstance(obj.get("interaction", {}), dict) else {}
        if str(interaction.get("cadence", "")) != "conditional":
            add_error(f"{object_id}: Batch 004 interaction cadence must be conditional")
        if check_body_and_approach(object_id, obj, width, height):
            section["shape_contract_ready_count"] += 1
        if not isinstance(obj.get("guard_expectation", {}), dict) or not obj.get("guard_expectation", {}):
            add_error(f"{object_id}: Batch 004 objects must author guard_expectation metadata")
        if not isinstance(obj.get("ai_hints", {}), dict) or not obj.get("ai_hints", {}):
            add_error(f"{object_id}: Batch 004 objects must author ai_hints")
        if not isinstance(obj.get("editor_placement", {}), dict) or not obj.get("editor_placement", {}):
            add_error(f"{object_id}: Batch 004 objects must author editor_placement")

        endpoint_contract = obj.get("linked_endpoint_contract", {}) if isinstance(obj.get("linked_endpoint_contract", {}), dict) else {}
        site_endpoint_contract = site.get("linked_endpoint_contract", {}) if isinstance(site.get("linked_endpoint_contract", {}), dict) else {}
        directionality = str(endpoint_contract.get("directionality", ""))
        if directionality:
            increment_count(section["directionality_counts"], directionality)
        if endpoint_contract and site_endpoint_contract and bool(endpoint_contract.get("metadata_only", False)) and not bool(endpoint_contract.get("runtime_route_effect_adopted", True)):
            section["linked_endpoint_contract_count"] += 1
        else:
            add_error(f"{object_id}: Batch 004 objects and sites must author metadata-only linked_endpoint_contract")

        route_effect = obj.get("route_effect", {}) if isinstance(obj.get("route_effect", {}), dict) else {}
        route_boundary = obj.get("route_effect_boundary", {}) if isinstance(obj.get("route_effect_boundary", {}), dict) else {}
        if route_effect and str(route_boundary.get("status", "")) == "metadata_only" and not bool(route_boundary.get("runtime_behavior_adopted", True)):
            section["route_effect_metadata_count"] += 1
        else:
            add_error(f"{object_id}: Batch 004 must author route_effect metadata with runtime adoption disabled")
        if role == "route_lock":
            lock_contract = obj.get("route_lock_contract", {}) if isinstance(obj.get("route_lock_contract", {}), dict) else {}
            site_lock_contract = site.get("route_lock_contract", {}) if isinstance(site.get("route_lock_contract", {}), dict) else {}
            if lock_contract and site_lock_contract and bool(lock_contract.get("metadata_only", False)) and not bool(lock_contract.get("runtime_route_effect_adopted", True)):
                section["route_lock_contract_count"] += 1
            else:
                add_error(f"{object_id}: route locks must author route_lock_contract on object and site")
        if role == "coast_harbor" or bool(obj.get("coast_applicability", {})):
            coast_contract = obj.get("coast_applicability", {}) if isinstance(obj.get("coast_applicability", {}), dict) else {}
            site_coast_contract = site.get("coast_applicability", {}) if isinstance(site.get("coast_applicability", {}), dict) else {}
            if coast_contract and site_coast_contract and bool(coast_contract.get("requires_coast_adjacency", False)) and not bool(coast_contract.get("full_ship_movement_system_adopted", True)):
                section["coast_applicability_count"] += 1
            else:
                add_error(f"{object_id}: coast route objects must author coast_applicability without live ship movement adoption")

        if metadata_boundary_is_safe(obj) and metadata_boundary_is_safe(site):
            section["metadata_only_boundary_count"] += 1
        else:
            add_error(f"{object_id}: Batch 004 object and site must keep explicit metadata-only runtime boundaries")
        if live_resource_ids(site, obj).intersection(ECONOMY_RARE_RESOURCE_IDS):
            add_error(f"{object_id}: Batch 004 must not activate rare resources in live site or route-effect fields")
        else:
            section["no_rare_resource_activation_count"] += 1
        if not bool(obj.get("runtime_boundary", {}).get("ship_movement_runtime_adopted", True)):
            section["no_live_ship_system_count"] += 1

    section["role_counts"] = sorted_counts(section["role_counts"])
    section["directionality_counts"] = sorted_counts(section["directionality_counts"])
    section["footprints"] = sorted_counts(section["footprints"])
    section["biome_counts"] = dict(sorted(section["biome_counts"].items()))
    if batch_objects:
        if len(batch_objects) != 24:
            add_error("Batch 004 must contain exactly 24 new or normalized transit/coast/route-control object definitions")
        for role, expected_count in expected_role_counts.items():
            if int(section["role_counts"].get(role, 0)) != expected_count:
                add_error(f"Batch 004 must include {expected_count} {role} objects")
        if section["normalized_existing_count"] != 2:
            add_error("Batch 004 must normalize the existing ferry stage and rope lift objects")
        for counter_key in ("linked_resource_site_count", "shape_contract_ready_count", "linked_endpoint_contract_count", "route_effect_metadata_count", "metadata_only_boundary_count", "no_rare_resource_activation_count", "no_live_ship_system_count"):
            if int(section[counter_key]) != len(batch_objects):
                add_error(f"Batch 004 {counter_key} must match object count")
        if section["route_lock_contract_count"] != expected_role_counts["route_lock"]:
            add_error("Batch 004 route locks must all carry route_lock_contract metadata")
        if section["coast_applicability_count"] < expected_role_counts["coast_harbor"]:
            add_error("Batch 004 must author coast applicability for every coast/harbor object")
        for directionality in ("two_way", "one_way", "conditional_lock", "coast_route"):
            if directionality not in section["directionality_counts"]:
                add_error(f"Batch 004 must cover linked endpoint directionality {directionality}")
        for biome_id in sorted(biomes.keys()):
            if int(section["biome_counts"].get(biome_id, 0)) < 1:
                add_error(f"Batch 004 must include transit/coast/route-control coverage for {biome_id}")
        for footprint_key in ("1x1", "1x2", "2x1", "2x2", "2x3", "3x1", "3x2"):
            if footprint_key not in section["footprints"]:
                add_error(f"Batch 004 must cover footprint {footprint_key}")
    return section


def build_overworld_object_content_batch_005_section(
    map_objects: dict[str, dict],
    resource_sites: dict[str, dict],
    biomes: dict[str, dict],
    neutral_dwellings: dict[str, dict],
    army_groups: dict[str, dict],
    encounters: dict[str, dict],
) -> dict:
    batch_objects = {
        object_id: obj
        for object_id, obj in map_objects.items()
        if str(obj.get("content_batch_id", "")) == OVERWORLD_OBJECT_CONTENT_BATCH_005_ID
        or str(obj.get("normalized_content_batch_id", "")) == OVERWORLD_OBJECT_CONTENT_BATCH_005_ID
    }
    batch_sites = {
        site_id: site
        for site_id, site in resource_sites.items()
        if str(site.get("content_batch_id", "")) == OVERWORLD_OBJECT_CONTENT_BATCH_005_ID
        or str(site.get("normalized_content_batch_id", "")) == OVERWORLD_OBJECT_CONTENT_BATCH_005_ID
    }
    expected_role_counts = {
        "existing_dwelling_normalization": 25,
        "new_basic_dwelling": 4,
        "guarded_high_value_dwelling": 4,
    }
    section = {
        "batch_id": OVERWORLD_OBJECT_CONTENT_BATCH_005_ID,
        "object_count": len(batch_objects),
        "site_count": len(batch_sites),
        "role_counts": {},
        "footprints": {},
        "biome_counts": {},
        "shape_contract_ready_count": 0,
        "linked_resource_site_count": 0,
        "linked_site_contract_count": 0,
        "roster_contract_ready_count": 0,
        "guard_contract_ready_count": 0,
        "guarded_variant_count": 0,
        "metadata_only_boundary_count": 0,
        "no_rare_resource_activation_count": 0,
        "normalized_existing_count": 0,
        "new_basic_count": 0,
        "errors": [],
        "warnings": [],
    }

    def add_error(message: str) -> None:
        if message not in section["errors"]:
            section["errors"].append(message)

    def live_resource_ids(site: dict, obj: dict) -> set[str]:
        ids: set[str] = set()
        for payload in (site, obj):
            for field in ("rewards", "claim_rewards", "control_income", "service_cost"):
                values = payload.get(field, {})
                if isinstance(values, dict):
                    ids.update(str(resource_id) for resource_id in values.keys())
            response_cost = payload.get("response_profile", {}).get("resource_cost", {}) if isinstance(payload.get("response_profile", {}), dict) else {}
            if isinstance(response_cost, dict):
                ids.update(str(resource_id) for resource_id in response_cost.keys())
        return ids

    def metadata_boundary_is_safe(payload: dict, guarded: bool) -> bool:
        boundary = payload.get("runtime_boundary", {}) if isinstance(payload.get("runtime_boundary", {}), dict) else {}
        safe = (
            str(boundary.get("status", "")) == "metadata_only"
            and bool(boundary.get("neutral_dwelling_site_runtime_supported", False))
            and not bool(boundary.get("guarded_variant_runtime_migration", True))
            and not bool(boundary.get("recruitment_ui_overhaul", True))
            and not bool(boundary.get("save_payload_required", True))
            and not bool(boundary.get("renderer_sprite_required", True))
            and not bool(boundary.get("pathing_runtime_adopted", True))
            and not bool(boundary.get("rare_resource_activation", True))
            and not bool(boundary.get("scenario_placement_migration", True))
        )
        if guarded:
            safe = safe and not bool(boundary.get("guard_resolution_runtime_adopted", True))
        return safe

    def check_public_text(object_id: str, obj: dict, site: dict) -> None:
        public_text_values = [
            str(obj.get("name", "")),
            str(site.get("name", "")),
            str(site.get("response_profile", {}).get("summary", "")) if isinstance(site.get("response_profile", {}), dict) else "",
            str(obj.get("guard_expectation", {}).get("visible_cue", "")) if isinstance(obj.get("guard_expectation", {}), dict) else "",
        ]
        for text in public_text_values:
            lowered = text.lower()
            for token in ("debug", "internal", "score", "fixture"):
                if token in lowered:
                    add_error(f"{object_id}: Batch 005 public text must not leak internal/debug/score fields")

    def check_body_and_approach(object_id: str, obj: dict, width: int, height: int) -> bool:
        body_tiles = obj.get("body_tiles", [])
        approach = obj.get("approach", {}) if isinstance(obj.get("approach", {}), dict) else {}
        visit_offsets = approach.get("visit_offsets", []) if isinstance(approach.get("visit_offsets", []), list) else []
        ready = True
        if not isinstance(body_tiles, list) or not body_tiles:
            add_error(f"{object_id}: Batch 005 dwellings must author non-empty body_tiles")
            ready = False
        if not isinstance(obj.get("approach", {}), dict) or not visit_offsets:
            add_error(f"{object_id}: Batch 005 dwellings must author approach.visit_offsets")
            ready = False
        seen_body_tiles: set[str] = set()
        for tile in body_tiles if isinstance(body_tiles, list) else []:
            if not isinstance(tile, dict):
                add_error(f"{object_id}: body_tiles entries must be dictionaries")
                ready = False
                continue
            x = int(tile.get("x", -999))
            y = int(tile.get("y", -999))
            if x < 0 or y < 0 or x >= width or y >= height:
                add_error(f"{object_id}: body tile {x},{y} is outside footprint")
                ready = False
            tile_key = f"{x},{y}"
            if tile_key in seen_body_tiles:
                add_error(f"{object_id}: body tile {tile_key} is duplicated")
                ready = False
            seen_body_tiles.add(tile_key)
        seen_visit_offsets: set[str] = set()
        for tile in visit_offsets:
            if not isinstance(tile, dict):
                add_error(f"{object_id}: approach.visit_offsets entries must be dictionaries")
                ready = False
                continue
            x = int(tile.get("x", -999))
            y = int(tile.get("y", -999))
            adjacent = (x == -1 and 0 <= y < height) or (x == width and 0 <= y < height) or (y == -1 and 0 <= x < width) or (y == height and 0 <= x < width)
            if not adjacent:
                add_error(f"{object_id}: approach tile {x},{y} must be adjacent to footprint")
                ready = False
            tile_key = f"{x},{y}"
            if tile_key in seen_visit_offsets:
                add_error(f"{object_id}: approach tile {tile_key} is duplicated")
                ready = False
            seen_visit_offsets.add(tile_key)
        if seen_body_tiles.intersection(seen_visit_offsets):
            add_error(f"{object_id}: body_tiles must not overlap approach.visit_offsets")
            ready = False
        if str(approach.get("mode", "")) != "adjacent":
            add_error(f"{object_id}: Batch 005 approach.mode must be adjacent")
            ready = False
        return ready

    def recruit_units(site: dict) -> set[str]:
        ids: set[str] = set()
        for key in ("claim_recruits", "weekly_recruits"):
            recruits = site.get(key, {})
            if isinstance(recruits, dict):
                ids.update(str(unit_id) for unit_id in recruits.keys())
        roster = site.get("neutral_roster", {}) if isinstance(site.get("neutral_roster", {}), dict) else {}
        for key in ("claim_recruits", "weekly_recruits"):
            recruits = roster.get(key, {})
            if isinstance(recruits, dict):
                ids.update(str(unit_id) for unit_id in recruits.keys())
        return ids

    def roster_contract_ready(object_id: str, site: dict, contract: dict) -> bool:
        dwelling_id = str(contract.get("neutral_dwelling_family_id", ""))
        if dwelling_id not in neutral_dwellings:
            add_error(f"{object_id}: Batch 005 dwelling_contract references missing neutral dwelling family {dwelling_id}")
            return False
        dwelling_units = {str(unit_id) for unit_id in neutral_dwellings[dwelling_id].get("unit_ids", [])}
        site_units = recruit_units(site)
        contract_units = {str(unit_id) for unit_id in contract.get("roster_unit_ids", [])}
        ready = True
        if not site_units:
            add_error(f"{object_id}: Batch 005 linked site must define recruit payloads")
            ready = False
        if not contract_units:
            add_error(f"{object_id}: Batch 005 dwelling_contract must list roster_unit_ids")
            ready = False
        if not site_units.issubset(dwelling_units):
            add_error(f"{object_id}: Batch 005 site recruits must belong to linked neutral dwelling family")
            ready = False
        if not contract_units.issubset(dwelling_units):
            add_error(f"{object_id}: Batch 005 contract roster_unit_ids must belong to linked neutral dwelling family")
            ready = False
        if str(contract.get("recruit_policy", "")) != "weekly_muster" or not bool(contract.get("recurring_recruit_access", False)):
            add_error(f"{object_id}: Batch 005 dwelling_contract must define recurring weekly muster access")
            ready = False
        return ready

    def guard_contract_ready(object_id: str, site: dict, guard: dict, guarded: bool) -> bool:
        ready = True
        guard_group_id = str(guard.get("guard_army_group_id", ""))
        guard_encounter_id = str(guard.get("guard_encounter_id", ""))
        if guard_group_id not in army_groups:
            add_error(f"{object_id}: Batch 005 guard army group {guard_group_id} is missing")
            ready = False
        if guard_encounter_id not in encounters:
            add_error(f"{object_id}: Batch 005 guard encounter {guard_encounter_id} is missing")
            ready = False
        if guard_encounter_id in encounters and str(encounters[guard_encounter_id].get("affiliation", "")) != "neutral":
            add_error(f"{object_id}: Batch 005 guard encounter must remain neutral")
            ready = False
        roster = site.get("neutral_roster", {}) if isinstance(site.get("neutral_roster", {}), dict) else {}
        if guard_group_id and str(roster.get("guard_army_group_id", "")) != guard_group_id:
            add_error(f"{object_id}: Batch 005 site neutral_roster guard army must match object guard expectation")
            ready = False
        if guard_encounter_id and str(roster.get("guard_encounter_id", "")) != guard_encounter_id:
            add_error(f"{object_id}: Batch 005 site neutral_roster guard encounter must match object guard expectation")
            ready = False
        if guarded:
            guard_profile = site.get("guard_profile", {}) if isinstance(site.get("guard_profile", {}), dict) else {}
            if not bool(site.get("guarded", False)) or not guard_profile:
                add_error(f"{object_id}: guarded Batch 005 dwellings must set guarded=true and author guard_profile")
                ready = False
            if not bool(guard.get("clear_required_for_recruitment", False)) or not bool(guard.get("blocks_approach", False)):
                add_error(f"{object_id}: guarded Batch 005 dwellings must require guard clearance and block approach in metadata")
                ready = False
            if guard_profile and (not bool(guard_profile.get("metadata_only", False)) or bool(guard_profile.get("runtime_guard_resolution_adopted", True))):
                add_error(f"{object_id}: guarded Batch 005 guard_profile must remain metadata-only")
                ready = False
        return ready

    for object_id, obj in sorted(batch_objects.items()):
        role = str(obj.get("batch005_role", ""))
        site_id = str(obj.get("resource_site_id", ""))
        site = resource_sites.get(site_id, {}) if site_id else {}
        footprint = obj.get("footprint", {}) if isinstance(obj.get("footprint", {}), dict) else {}
        width = int(footprint.get("width", 0))
        height = int(footprint.get("height", 0))
        footprint_key = f"{width}x{height}"
        guarded = role == "guarded_high_value_dwelling"
        increment_count(section["role_counts"], role)
        increment_count(section["footprints"], footprint_key)
        for biome_id in obj.get("biome_ids", []) if isinstance(obj.get("biome_ids", []), list) else []:
            increment_count(section["biome_counts"], str(biome_id))
        if role == "existing_dwelling_normalization":
            section["normalized_existing_count"] += 1
        if role == "new_basic_dwelling":
            section["new_basic_count"] += 1
        if guarded:
            section["guarded_variant_count"] += 1

        forbidden_wood_alias = "tim" + "ber"
        text_key = json.dumps({"object": obj, "site": site}, sort_keys=True).lower()
        if forbidden_wood_alias in text_key:
            add_error(f"{object_id}: Batch 005 must keep wood canonical and avoid non-canonical wood aliases")
        if role not in expected_role_counts:
            add_error(f"{object_id}: Batch 005 object must author a supported batch005_role")
        if str(obj.get("family", "")) != "neutral_dwelling" or str(obj.get("primary_class", "")) != "neutral_dwelling":
            add_error(f"{object_id}: Batch 005 objects must remain neutral_dwelling map objects")
        if not site_id or site_id not in resource_sites:
            add_error(f"{object_id}: Batch 005 object must link an existing resource_site_id")
        else:
            section["linked_resource_site_count"] += 1
            if str(site.get("family", "")) != "neutral_dwelling":
                add_error(f"{object_id}: linked site {site_id} must use neutral_dwelling family")
            if str(site.get("content_batch_id", "")) != OVERWORLD_OBJECT_CONTENT_BATCH_005_ID and str(site.get("normalized_content_batch_id", "")) != OVERWORLD_OBJECT_CONTENT_BATCH_005_ID:
                add_error(f"{object_id}: linked site {site_id} must carry Batch 005 content metadata")
        if width <= 0 or height <= 0:
            add_error(f"{object_id}: Batch 005 footprint dimensions must be positive")
        if str(footprint.get("anchor", "")) not in OVERWORLD_OBJECT_FOOTPRINT_ANCHORS:
            add_error(f"{object_id}: Batch 005 footprint.anchor is missing or unsupported")
        if str(footprint.get("tier", "")) not in OVERWORLD_OBJECT_FOOTPRINT_TIERS:
            add_error(f"{object_id}: Batch 005 footprint.tier is missing or unsupported")
        if str(obj.get("passability_class", "")) != "blocking_visitable":
            add_error(f"{object_id}: Batch 005 dwelling objects must use blocking_visitable")
        interaction = obj.get("interaction", {}) if isinstance(obj.get("interaction", {}), dict) else {}
        if str(interaction.get("cadence", "")) != "persistent_control" or str(interaction.get("refresh_rule", "")) != "weekly_muster":
            add_error(f"{object_id}: Batch 005 dwelling interaction must remain persistent weekly muster")
        if guarded and not bool(interaction.get("requires_guard_clear", False)):
            add_error(f"{object_id}: guarded Batch 005 dwellings must require guard clear in interaction metadata")
        if check_body_and_approach(object_id, obj, width, height):
            section["shape_contract_ready_count"] += 1
        contract = obj.get("dwelling_contract", {}) if isinstance(obj.get("dwelling_contract", {}), dict) else {}
        site_contract = site.get("dwelling_contract", {}) if isinstance(site.get("dwelling_contract", {}), dict) else {}
        if contract and site_contract and str(contract.get("resource_site_id", "")) == site_id and str(site_contract.get("resource_site_id", "")) == site_id:
            section["linked_site_contract_count"] += 1
        else:
            add_error(f"{object_id}: Batch 005 object and site must author matching dwelling_contract metadata")
        if site and roster_contract_ready(object_id, site, contract):
            section["roster_contract_ready_count"] += 1
        guard = obj.get("guard_expectation", {}) if isinstance(obj.get("guard_expectation", {}), dict) else {}
        if site and guard and guard_contract_ready(object_id, site, guard, guarded):
            section["guard_contract_ready_count"] += 1
        if not isinstance(obj.get("ai_hints", {}), dict) or not obj.get("ai_hints", {}):
            add_error(f"{object_id}: Batch 005 objects must author ai_hints")
        if not isinstance(obj.get("editor_placement", {}), dict) or not obj.get("editor_placement", {}):
            add_error(f"{object_id}: Batch 005 objects must author editor_placement")
        if metadata_boundary_is_safe(obj, guarded) and metadata_boundary_is_safe(site, guarded):
            section["metadata_only_boundary_count"] += 1
        else:
            add_error(f"{object_id}: Batch 005 object and site must keep explicit metadata-only runtime boundaries")
        if live_resource_ids(site, obj).intersection(ECONOMY_RARE_RESOURCE_IDS):
            add_error(f"{object_id}: Batch 005 must not activate rare resources in live site fields")
        else:
            section["no_rare_resource_activation_count"] += 1
        check_public_text(object_id, obj, site)

    section["role_counts"] = sorted_counts(section["role_counts"])
    section["footprints"] = sorted_counts(section["footprints"])
    section["biome_counts"] = dict(sorted(section["biome_counts"].items()))
    if batch_objects:
        if len(batch_objects) != 33:
            add_error("Batch 005 must contain exactly 33 dwelling object definitions: 25 current normalizations plus 8 new variants")
        if len(batch_sites) != 33:
            add_error("Batch 005 must carry matching metadata on exactly 33 linked dwelling resource-site records")
        for role, expected_count in expected_role_counts.items():
            if int(section["role_counts"].get(role, 0)) != expected_count:
                add_error(f"Batch 005 must include {expected_count} {role} objects")
        for counter_key in ("linked_resource_site_count", "shape_contract_ready_count", "linked_site_contract_count", "roster_contract_ready_count", "guard_contract_ready_count", "metadata_only_boundary_count", "no_rare_resource_activation_count"):
            if int(section[counter_key]) != len(batch_objects):
                add_error(f"Batch 005 {counter_key} must match object count")
        if section["guarded_variant_count"] != 4:
            add_error("Batch 005 must include exactly 4 guarded high-value dwelling variants")
        for biome_id in sorted(biomes.keys()):
            if int(section["biome_counts"].get(biome_id, 0)) < 2:
                add_error(f"Batch 005 must include at least 2 dwelling definitions for {biome_id}")
        for footprint_key in ("2x1", "2x2", "3x2", "3x3"):
            if footprint_key not in section["footprints"]:
                add_error(f"Batch 005 must cover footprint {footprint_key}")
    return section


def build_overworld_object_report() -> dict:
    payloads = {key: load_json(CONTENT_DIR / f"{key}.json") for key in ("map_objects", "resource_sites", "scenarios", "encounters", "army_groups", "factions", "biomes", "neutral_dwellings")}
    map_objects = items_index(payloads["map_objects"])
    resource_sites = items_index(payloads["resource_sites"])
    scenarios = items_index(payloads["scenarios"])
    encounters = items_index(payloads["encounters"])
    army_groups = items_index(payloads["army_groups"])
    factions = items_index(payloads["factions"])
    biomes = items_index(payloads["biomes"])
    neutral_dwellings = items_index(payloads["neutral_dwellings"])
    site_placements = collect_overworld_object_scenario_site_placements(scenarios)
    encounter_placements = collect_overworld_object_scenario_encounter_placements(scenarios)
    object_ids_by_site_id = {str(obj.get("resource_site_id", "")): object_id for object_id, obj in map_objects.items() if str(obj.get("resource_site_id", ""))}
    report = {
        "schema": OVERWORLD_OBJECT_REPORT_SCHEMA,
        "generated_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        "mode": "compatibility_report",
        "compatibility_adapters": {
            "runtime_adoption": "classification_reporting_safe_metadata_and_bounded_shape_masks",
            "runtime_adopted_safe_fields": ["primary_class", "secondary_tags", "interaction.cadence", "body_tiles", "approach.visit_offsets", "passability_class"],
            "runtime_deferred_fields": ["route_effect_runtime_behavior", "renderer_hint_id", "ai_hints", "save_state"],
            "production_json_migration": "safe_metadata_bundle_001_plus_one_representative_shape_mask",
            "pathing_occupancy_adoption": "bounded_resource_object_body_and_interaction_masks",
            "route_effect_authoring": "selected_transit_metadata_validated_report_only",
            "renderer_sprite_ingestion": False,
            "ai_behavior_switch": False,
            "report_normalization": "authored_safe_fields_when_present_else_inferred",
        },
        "summary": {
            "map_object_count": len(map_objects),
            "safe_metadata_bundle_001_count": sum(1 for object_id in OVERWORLD_OBJECT_SAFE_METADATA_BUNDLE_001 if object_id in map_objects),
            "resource_site_count": len(resource_sites),
            "scenario_site_placement_count": sum(int(entry.get("count", 0)) for entry in site_placements.values()),
            "scenario_encounter_placement_count": sum(int(entry.get("count", 0)) for entry in encounter_placements.values()),
            "family_counts": {},
            "inferred_primary_class_counts": {},
            "passability_class_counts": {},
            "footprint_tier_counts": {},
            "missing_future_metadata_counts": {
                "schema_version": 0,
                "primary_class": 0,
                "secondary_tags": 0,
                "footprint_anchor": 0,
                "footprint_tier": 0,
                "body_tiles": 0,
                "approach": 0,
                "passability_class": 0,
                "interaction": 0,
                "animation_cues": 0,
                "editor_placement": 0,
                "ai_hints": 0,
            },
        },
        "families": {},
        "objects": {},
        "resource_site_links": {"linked_object_count": 0, "unlinked_resource_site_ids": [], "linked_resource_site_ids": [], "family_mismatches": []},
        "scenario_reality": {
            "resource_site_placements": site_placements,
            "encounter_placements": encounter_placements,
            "placed_site_ids_without_map_object": [],
            "placed_guard_encounters": [],
        },
        "route_transit": {},
        "route_effect_authoring": {
            "mode": "metadata_validation_only",
            "runtime_behavior_adopted": False,
            "public_boundary": "route-effect authoring values are tooling-only unless a later UI/runtime slice explicitly adopts compact public text",
            "selected_transit_object_ids": [],
            "validated_count": 0,
            "warning_count": 0,
            "error_count": 0,
            "entries": {},
        },
        "guard_reward": {},
        "ownership_capture": {},
        "content_batches": {},
        "ai_editor_implications": {
            "requires_future_body_tile_validation": [],
            "requires_future_approach_validation": [],
            "requires_future_density_review": [],
            "requires_future_ai_valuation": [],
            "visible_neutral_encounter_records_present": False,
        },
        "warnings": [],
        "errors": [],
    }
    report["editor_authoring"] = build_overworld_object_editor_authoring_section(
        map_objects,
        resource_sites,
        scenarios,
        site_placements,
        encounter_placements,
        object_ids_by_site_id,
    )
    report["content_batches"]["batch_001_core_density_pickups"] = build_overworld_object_content_batch_001_section(map_objects, resource_sites)
    report["content_batches"]["batch_001b_biome_scenic_decoration"] = build_overworld_object_content_batch_001b_section(map_objects, biomes)
    report["content_batches"]["batch_001c_biome_blockers_edge"] = build_overworld_object_content_batch_001c_section(map_objects, biomes)
    report["content_batches"]["batch_001d_large_footprint_coverage"] = build_overworld_object_content_batch_001d_section(map_objects, biomes)
    report["content_batches"]["batch_002_mines_resource_fronts"] = build_overworld_object_content_batch_002_section(map_objects, resource_sites, biomes)
    report["content_batches"]["batch_003_services_shrines_signs_events"] = build_overworld_object_content_batch_003_section(map_objects, resource_sites, biomes)
    report["content_batches"]["batch_004_transit_coast_route_control"] = build_overworld_object_content_batch_004_section(map_objects, resource_sites, biomes)
    report["content_batches"]["batch_005_dwellings_guarded_dwellings"] = build_overworld_object_content_batch_005_section(map_objects, resource_sites, biomes, neutral_dwellings, army_groups, encounters)
    report["ai_editor_implications"]["visible_neutral_encounter_records_present"] = any(
        infer_overworld_object_primary_class(obj, resource_sites.get(str(obj.get("resource_site_id", "")))) == "neutral_encounter"
        for obj in map_objects.values()
    )

    for object_id, obj in map_objects.items():
        family = str(obj.get("family", ""))
        site_id = str(obj.get("resource_site_id", ""))
        site = resource_sites.get(site_id) if site_id else None
        schema_version = obj.get("schema_version", 0)
        authored_primary_class = str(obj.get("primary_class", ""))
        authored_secondary_tags = obj.get("secondary_tags", []) if isinstance(obj.get("secondary_tags", []), list) else []
        primary_class = infer_overworld_object_primary_class(obj, site)
        secondary_tags = infer_overworld_object_secondary_tags(obj, site)
        footprint = obj.get("footprint", {}) if isinstance(obj.get("footprint", {}), dict) else {}
        footprint_tier = infer_overworld_object_footprint_tier(footprint)
        authored_footprint_tier = str(footprint.get("tier", ""))
        passability_class = infer_overworld_object_passability_class(obj)
        authored_passability_class = str(obj.get("passability_class", ""))
        interaction = obj.get("interaction", {}) if isinstance(obj.get("interaction", {}), dict) else {}
        authored_interaction_cadence = str(interaction.get("cadence", ""))
        cadence = infer_overworld_object_interaction_cadence(obj, site)
        reward_categories = infer_overworld_object_reward_categories(site)
        object_warnings: list[str] = []
        object_hints: list[str] = []
        increment_count(report["summary"]["family_counts"], family)
        increment_count(report["summary"]["inferred_primary_class_counts"], primary_class)
        increment_count(report["summary"]["passability_class_counts"], passability_class)
        increment_count(report["summary"]["footprint_tier_counts"], footprint_tier)
        if family not in report["families"]:
            report["families"][family] = {"family": family, "count": 0, "inferred_primary_classes": {}, "secondary_tags": [], "resource_site_links": 0, "scenario_placements": 0}
        report["families"][family]["count"] += 1
        increment_count(report["families"][family]["inferred_primary_classes"], primary_class)
        for tag in secondary_tags:
            append_unique(report["families"][family]["secondary_tags"], tag)
        if site_id:
            report["families"][family]["resource_site_links"] += 1
            report["resource_site_links"]["linked_object_count"] += 1
            append_unique(report["resource_site_links"]["linked_resource_site_ids"], site_id)
            if site is not None:
                report["families"][family]["scenario_placements"] += int(site_placements.get(site_id, {}).get("count", 0))
                site_family = str(site.get("family", "one_shot_pickup"))
                if family in OVERWORLD_FOUNDATION_SITE_FAMILIES and site_family != family:
                    report["resource_site_links"]["family_mismatches"].append({"object_id": object_id, "family": family, "resource_site_id": site_id, "site_family": site_family})
        if "schema_version" not in obj:
            report["summary"]["missing_future_metadata_counts"]["schema_version"] += 1
        if "primary_class" not in obj:
            report["summary"]["missing_future_metadata_counts"]["primary_class"] += 1
        if "secondary_tags" not in obj:
            report["summary"]["missing_future_metadata_counts"]["secondary_tags"] += 1
        if "anchor" not in footprint:
            report["summary"]["missing_future_metadata_counts"]["footprint_anchor"] += 1
        if "tier" not in footprint:
            report["summary"]["missing_future_metadata_counts"]["footprint_tier"] += 1
        if "body_tiles" not in obj:
            report["summary"]["missing_future_metadata_counts"]["body_tiles"] += 1
            object_warnings.append("future schema warning: missing body_tiles; rectangular footprint is inferred for report only")
            append_unique(report["ai_editor_implications"]["requires_future_body_tile_validation"], object_id)
        if bool(obj.get("visitable", False)) and "approach" not in obj:
            report["summary"]["missing_future_metadata_counts"]["approach"] += 1
            object_warnings.append("future schema warning: visitable object lacks approach metadata")
            append_unique(report["ai_editor_implications"]["requires_future_approach_validation"], object_id)
        if "passability_class" not in obj:
            report["summary"]["missing_future_metadata_counts"]["passability_class"] += 1
        if "interaction" not in obj:
            report["summary"]["missing_future_metadata_counts"]["interaction"] += 1
        if "animation_cues" not in obj:
            report["summary"]["missing_future_metadata_counts"]["animation_cues"] += 1
            if primary_class != "decoration":
                object_warnings.append("future schema warning: animation cue ids are not authored yet")
        if "editor_placement" not in obj:
            report["summary"]["missing_future_metadata_counts"]["editor_placement"] += 1
            append_unique(report["ai_editor_implications"]["requires_future_density_review"], object_id)
        if "ai_hints" not in obj and primary_class != "decoration":
            report["summary"]["missing_future_metadata_counts"]["ai_hints"] += 1
            append_unique(report["ai_editor_implications"]["requires_future_ai_valuation"], object_id)
        if site is None and site_id:
            object_warnings.append(f"linked resource_site_id {site_id} is missing")
        if primary_class == "transit_route_object":
            route_authoring_entry = validate_overworld_object_route_effect_authoring_entry(object_id, obj, site)
            report["route_effect_authoring"]["entries"][object_id] = route_authoring_entry
            append_unique(report["route_effect_authoring"]["selected_transit_object_ids"], object_id)
            report["route_effect_authoring"]["validated_count"] += 1
            report["route_effect_authoring"]["warning_count"] += len(route_authoring_entry.get("warnings", []))
            report["route_effect_authoring"]["error_count"] += len(route_authoring_entry.get("errors", []))
            for route_error in route_authoring_entry.get("errors", []):
                if route_error not in report["errors"]:
                    report["errors"].append(f"{object_id}: {route_error}")
            route_entry = {
                "object_id": object_id,
                "resource_site_id": site_id,
                "site_has_transit_profile": isinstance(site.get("transit_profile", {}) if site else {}, dict) and bool(site.get("transit_profile", {}) if site else {}),
                "future_route_effect_present": "route_effect" in obj or "route_effect_id" in obj,
                "route_effect_authoring_status": "valid" if not route_authoring_entry.get("errors", []) else "invalid",
                "route_effect_id": str(route_authoring_entry.get("effect_id", "")),
                "route_effect_type": str(route_authoring_entry.get("effect_type", "")),
                "shape_mask_contract": route_authoring_entry.get("shape_mask_contract", {}),
                "warnings": [],
            }
            if not route_entry["future_route_effect_present"]:
                route_entry["warnings"].append("future route_effect metadata is missing; report keeps transit runtime behavior unchanged")
                object_warnings.append("future schema warning: transit object lacks route_effect metadata")
            for route_warning in route_authoring_entry.get("warnings", []):
                route_entry["warnings"].append(route_warning)
            report["route_transit"][object_id] = route_entry
        if site and (bool(site.get("guarded", False)) or isinstance(site.get("guard_profile", {}), dict) and bool(site.get("guard_profile", {})) or isinstance(site.get("neutral_roster", {}), dict) and bool(site.get("neutral_roster", {}))):
            neutral_roster = site.get("neutral_roster", {}) if isinstance(site.get("neutral_roster", {}), dict) else {}
            guard_encounter_id = str(neutral_roster.get("guard_encounter_id", ""))
            guard_army_group_id = str(neutral_roster.get("guard_army_group_id", ""))
            report["guard_reward"][object_id] = {
                "object_id": object_id,
                "resource_site_id": site_id,
                "guarded": bool(site.get("guarded", False)),
                "guard_profile_present": isinstance(site.get("guard_profile", {}), dict) and bool(site.get("guard_profile", {})),
                "neutral_guard_encounter_id": guard_encounter_id,
                "neutral_guard_encounter_exists": guard_encounter_id in encounters if guard_encounter_id else False,
                "neutral_guard_army_group_id": guard_army_group_id,
                "neutral_guard_army_group_exists": guard_army_group_id in army_groups if guard_army_group_id else False,
                "reward_categories": reward_categories,
            }
            if guard_encounter_id and guard_encounter_id in encounter_placements:
                append_unique(report["scenario_reality"]["placed_guard_encounters"], guard_encounter_id)
        if site and (bool(site.get("persistent_control", False)) or str(obj.get("faction_id", ""))):
            capture_profile = site.get("capture_profile", {}) if isinstance(site.get("capture_profile", {}), dict) else {}
            ownership_entry = {
                "object_id": object_id,
                "resource_site_id": site_id,
                "persistent_control": bool(site.get("persistent_control", False)),
                "faction_id": str(obj.get("faction_id", "")),
                "faction_exists": str(obj.get("faction_id", "")) in factions if str(obj.get("faction_id", "")) else False,
                "scenario_placement_count": int(site_placements.get(site_id, {}).get("count", 0)),
                "capture_profile_present": bool(capture_profile),
                "collected_by_faction_placement_count": sum(1 for placement in site_placements.get(site_id, {}).get("placements", []) if str(placement.get("collected_by_faction_id", ""))),
                "warnings": [],
            }
            if bool(site.get("persistent_control", False)) and not capture_profile:
                ownership_entry["warnings"].append("future capture_profile metadata is missing")
                object_warnings.append("future schema warning: persistent/capturable object lacks capture_profile metadata")
            report["ownership_capture"][object_id] = ownership_entry
        if primary_class == "neutral_dwelling":
            object_hints.append("AI/editor hint: future placement should reserve approach, guard, weekly recruit, and counter-capture context")
        if primary_class in {"persistent_economy_site", "guarded_reward_site", "transit_route_object", "faction_landmark"}:
            object_hints.append("AI/editor hint: future AI valuation and density rules should treat this as a strategic object")
        for warning in object_warnings:
            add_overworld_object_report_warning(report, f"{object_id}: {warning}")
        report["objects"][object_id] = {
            "object_id": object_id,
            "name": str(obj.get("name", object_id)),
            "family": family,
            "schema_version": schema_version if isinstance(schema_version, int) else 0,
            "safe_metadata_status": "safe_metadata_bundle_001" if object_id in OVERWORLD_OBJECT_SAFE_METADATA_BUNDLE_001 else "legacy_compatibility",
            "authored_primary_class": authored_primary_class,
            "inferred_primary_class": primary_class,
            "authored_secondary_tags": [str(tag) for tag in authored_secondary_tags],
            "inferred_secondary_tags": secondary_tags,
            "resource_site_id": site_id,
            "resource_site_family": str(site.get("family", "one_shot_pickup")) if site else "",
            "scenario_placement_count": int(site_placements.get(site_id, {}).get("count", 0)) if site_id else 0,
            "footprint": {"width": int(footprint.get("width", 0)), "height": int(footprint.get("height", 0)), "authored_tier": authored_footprint_tier, "inferred_tier": footprint_tier, "anchor": str(footprint.get("anchor", ""))},
            "passable": bool(obj.get("passable", False)),
            "visitable": bool(obj.get("visitable", False)),
            "authored_passability_class": authored_passability_class,
            "inferred_passability_class": passability_class,
            "authored_interaction_cadence": authored_interaction_cadence,
            "inferred_interaction_cadence": cadence,
            "reward_categories": reward_categories,
            "warnings": object_warnings,
            "hints": object_hints,
        }

    for site_id, site in resource_sites.items():
        if site_id not in object_ids_by_site_id:
            report["resource_site_links"]["unlinked_resource_site_ids"].append(site_id)
            if site_id in site_placements:
                report["scenario_reality"]["placed_site_ids_without_map_object"].append(site_id)
                add_overworld_object_report_warning(report, f"{site_id}: placed resource site has no current map_object link")
        if str(site.get("family", "one_shot_pickup")) == "transit_object" and site_id not in object_ids_by_site_id:
            add_overworld_object_report_warning(report, f"{site_id}: transit resource site has no linked object metadata")

    for key in ("family_counts", "inferred_primary_class_counts", "passability_class_counts", "footprint_tier_counts"):
        report["summary"][key] = sorted_counts(report["summary"][key])
    for family_entry in report["families"].values():
        family_entry["inferred_primary_classes"] = sorted_counts(family_entry["inferred_primary_classes"])
        family_entry["secondary_tags"] = sorted(family_entry["secondary_tags"])
    report["families"] = {family: report["families"][family] for family in sorted(report["families"].keys())}
    report["resource_site_links"]["unlinked_resource_site_ids"] = sorted(report["resource_site_links"]["unlinked_resource_site_ids"])
    report["resource_site_links"]["linked_resource_site_ids"] = sorted(report["resource_site_links"]["linked_resource_site_ids"])
    report["scenario_reality"]["placed_site_ids_without_map_object"] = sorted(report["scenario_reality"]["placed_site_ids_without_map_object"])
    report["scenario_reality"]["placed_guard_encounters"] = sorted(report["scenario_reality"]["placed_guard_encounters"])
    report["route_effect_authoring"]["selected_transit_object_ids"] = sorted(report["route_effect_authoring"]["selected_transit_object_ids"])
    if not report["ai_editor_implications"]["visible_neutral_encounter_records_present"]:
        add_overworld_object_report_warning(report, "no first-class neutral_encounter map object records exist yet; visible encounter placement remains scenario encounter data")
    for batch_error in report.get("content_batches", {}).get("batch_001_core_density_pickups", {}).get("errors", []):
        if batch_error not in report["errors"]:
            report["errors"].append(batch_error)
    for batch_error in report.get("content_batches", {}).get("batch_001b_biome_scenic_decoration", {}).get("errors", []):
        if batch_error not in report["errors"]:
            report["errors"].append(batch_error)
    for batch_error in report.get("content_batches", {}).get("batch_001c_biome_blockers_edge", {}).get("errors", []):
        if batch_error not in report["errors"]:
            report["errors"].append(batch_error)
    for batch_error in report.get("content_batches", {}).get("batch_001d_large_footprint_coverage", {}).get("errors", []):
        if batch_error not in report["errors"]:
            report["errors"].append(batch_error)
    for batch_error in report.get("content_batches", {}).get("batch_002_mines_resource_fronts", {}).get("errors", []):
        if batch_error not in report["errors"]:
            report["errors"].append(batch_error)
    for batch_error in report.get("content_batches", {}).get("batch_003_services_shrines_signs_events", {}).get("errors", []):
        if batch_error not in report["errors"]:
            report["errors"].append(batch_error)
    for batch_error in report.get("content_batches", {}).get("batch_004_transit_coast_route_control", {}).get("errors", []):
        if batch_error not in report["errors"]:
            report["errors"].append(batch_error)
    for batch_error in report.get("content_batches", {}).get("batch_005_dwellings_guarded_dwellings", {}).get("errors", []):
        if batch_error not in report["errors"]:
            report["errors"].append(batch_error)
    add_overworld_object_report_warning(report, "unmigrated production map_objects.json records remain legacy-compatible; inferred primary_class and tags are report-only outside declared migrated bundles")
    add_overworld_object_report_warning(report, "body_tiles and approach metadata remain warnings for unmigrated objects; pathing adoption is bounded to authored representative masks")
    return report


def print_overworld_object_report(report: dict) -> None:
    print("OVERWORLD OBJECT REPORT")
    print(f"- schema: {report['schema']}")
    print(f"- mode: {report['mode']}")
    print(f"- map objects: {report['summary']['map_object_count']}; resource sites: {report['summary']['resource_site_count']}")
    print(f"- safe_metadata_bundle_001 objects: {report['summary']['safe_metadata_bundle_001_count']}")
    print(f"- scenario site placements: {report['summary']['scenario_site_placement_count']}; encounter placements: {report['summary']['scenario_encounter_placement_count']}")
    print("Families:")
    for family, count in report["summary"]["family_counts"].items():
        primary = ",".join(report["families"].get(family, {}).get("inferred_primary_classes", {}).keys())
        print(f"- {family}: {count}; inferred={primary}")
    print("Primary classes:")
    for primary_class, count in report["summary"]["inferred_primary_class_counts"].items():
        print(f"- {primary_class}: {count}")
    print("Footprints and passability:")
    for tier, count in report["summary"]["footprint_tier_counts"].items():
        print(f"- footprint {tier}: {count}")
    for passability_class, count in report["summary"]["passability_class_counts"].items():
        print(f"- passability {passability_class}: {count}")
    missing = report["summary"]["missing_future_metadata_counts"]
    print("Future metadata warnings:")
    print(f"- body_tiles missing: {missing['body_tiles']}; approach missing: {missing['approach']}; animation cues missing: {missing['animation_cues']}")
    print(f"- ai hints missing: {missing['ai_hints']}; editor placement missing: {missing['editor_placement']}")
    print("Links and implications:")
    print(f"- linked resource sites: {report['resource_site_links']['linked_object_count']}; placed sites without object link: {len(report['scenario_reality']['placed_site_ids_without_map_object'])}")
    print(f"- guarded/reward links: {len(report['guard_reward'])}; ownership/capture hints: {len(report['ownership_capture'])}; transit warnings: {sum(len(item.get('warnings', [])) for item in report['route_transit'].values())}")
    print(f"- first-class neutral encounter objects: {report['ai_editor_implications']['visible_neutral_encounter_records_present']}")
    editor_authoring = report.get("editor_authoring", {})
    readiness = editor_authoring.get("metadata_readiness", {})
    density = editor_authoring.get("density_diagnostics", {})
    print("Editor authoring:")
    print(f"- palette groups: {len(editor_authoring.get('palette_groups', {}))}; taxonomy ready objects: {readiness.get('taxonomy_ready_count', 0)}; editor metadata present: {readiness.get('editor_metadata_present_count', 0)}")
    print(f"- top-level editor placement: {readiness.get('top_level_editor_placement_count', 0)}; nested neutral editor placement: {readiness.get('nested_neutral_editor_placement_count', 0)}")
    print(f"- role mismatches: {len(readiness.get('role_mismatches', []))}; unsupported map-role tags: {len(readiness.get('unsupported_map_role_tags', []))}")
    print(f"- density regions requiring review: {len(density.get('regions_requiring_review', []))}; unlinked placed resource sites: {len(density.get('unlinked_placed_resource_sites', []))}")
    route_effect_authoring = report.get("route_effect_authoring", {})
    print("Route effect authoring:")
    print(f"- selected transit objects: {route_effect_authoring.get('validated_count', 0)}; errors: {route_effect_authoring.get('error_count', 0)}; warnings: {route_effect_authoring.get('warning_count', 0)}")
    print(f"- runtime behavior adopted: {route_effect_authoring.get('runtime_behavior_adopted', False)}")
    print(f"- runtime adoption: {report['compatibility_adapters']['runtime_adoption']}; pathing occupancy adoption={report['compatibility_adapters']['pathing_occupancy_adoption']}")
    print(f"- runtime adopted safe fields: {', '.join(report['compatibility_adapters'].get('runtime_adopted_safe_fields', []))}")
    batch = report.get("content_batches", {}).get("batch_001_core_density_pickups", {})
    if batch:
        print("Content Batch 001:")
        print(f"- objects: {batch.get('object_count', 0)}; scenic={batch.get('passable_scenic_decoration_count', 0)}; blocking_or_edge={batch.get('blocking_or_edge_decoration_count', 0)}")
        print(f"- live common pickups={batch.get('common_live_pickup_count', 0)} resources={','.join(batch.get('common_live_resource_ids', []))}; staged rare pickups={batch.get('staged_rare_pickup_count', 0)}")
        print(f"- staged rare resources: {','.join(batch.get('staged_rare_resource_ids', []))}; errors={len(batch.get('errors', []))}; warnings={len(batch.get('warnings', []))}")
    batch_001b = report.get("content_batches", {}).get("batch_001b_biome_scenic_decoration", {})
    if batch_001b:
        print("Content Batch 001b:")
        print(f"- objects: {batch_001b.get('object_count', 0)}; scenic={batch_001b.get('passable_scenic_decoration_count', 0)}")
        print(f"- biomes covered={len(batch_001b.get('biome_counts', {}))}; footprints={','.join(batch_001b.get('footprints', {}).keys())}")
        print(f"- errors={len(batch_001b.get('errors', []))}; warnings={len(batch_001b.get('warnings', []))}")
    batch_001c = report.get("content_batches", {}).get("batch_001c_biome_blockers_edge", {})
    if batch_001c:
        print("Content Batch 001c:")
        print(f"- objects: {batch_001c.get('object_count', 0)}; blocking={batch_001c.get('blocking_non_visitable_count', 0)}; edge={batch_001c.get('edge_blocker_count', 0)}; partial_masks={batch_001c.get('partial_body_mask_count', 0)}")
        print(f"- biomes covered={len(batch_001c.get('biome_counts', {}))}; footprints={','.join(batch_001c.get('footprints', {}).keys())}")
        print(f"- edge intents={len(batch_001c.get('edge_intents', []))}; errors={len(batch_001c.get('errors', []))}; warnings={len(batch_001c.get('warnings', []))}")
    batch_001d = report.get("content_batches", {}).get("batch_001d_large_footprint_coverage", {})
    if batch_001d:
        print("Content Batch 001d:")
        print(f"- objects: {batch_001d.get('object_count', 0)}; scenic={batch_001d.get('passable_scenic_count', 0)}; blocking={batch_001d.get('blocking_non_visitable_count', 0)}; edge={batch_001d.get('edge_blocker_count', 0)}; partial_masks={batch_001d.get('partial_body_mask_count', 0)}")
        print(f"- decoration/blocker total={batch_001d.get('decoration_or_blocker_total_count', 0)}; biomes covered={len(batch_001d.get('biome_counts', {}))}; footprints={','.join(batch_001d.get('footprints', {}).keys())}")
        print(f"- edge intents={len(batch_001d.get('edge_intents', []))}; errors={len(batch_001d.get('errors', []))}; warnings={len(batch_001d.get('warnings', []))}")
    batch_002 = report.get("content_batches", {}).get("batch_002_mines_resource_fronts", {})
    if batch_002:
        print("Content Batch 002:")
        print(f"- objects: {batch_002.get('object_count', 0)}; common={batch_002.get('common_mine_count', 0)}; rare={batch_002.get('rare_resource_front_count', 0)}; support={batch_002.get('support_producer_count', 0)}; normalized={batch_002.get('normalized_resource_object_count', 0)}")
        print(f"- live common resources={','.join(batch_002.get('common_live_resource_ids', []))}; staged rare resources={','.join(batch_002.get('staged_rare_resource_ids', []))}")
        print(f"- shape contracts={batch_002.get('shape_contract_ready_count', 0)}; biomes covered={len(batch_002.get('biome_counts', {}))}; footprints={','.join(batch_002.get('footprints', {}).keys())}")
        print(f"- errors={len(batch_002.get('errors', []))}; warnings={len(batch_002.get('warnings', []))}")
    batch_003 = report.get("content_batches", {}).get("batch_003_services_shrines_signs_events", {})
    if batch_003:
        print("Content Batch 003:")
        role_counts = batch_003.get("role_counts", {})
        print(f"- objects: {batch_003.get('object_count', 0)}; services={role_counts.get('repeatable_service', 0)}; shrines={role_counts.get('shrine_progression', 0)}; scouting={role_counts.get('scouting_info', 0)}; signs={role_counts.get('sign_waypoint', 0)}; locks={role_counts.get('route_lock', 0)}; events={role_counts.get('objective_event', 0)}")
        print(f"- shape contracts={batch_003.get('shape_contract_ready_count', 0)}; metadata-only boundaries={batch_003.get('metadata_only_boundary_count', 0)}; route locks={batch_003.get('route_lock_metadata_count', 0)}")
        print(f"- cadences={','.join(batch_003.get('cadence_counts', {}).keys())}; biomes covered={len(batch_003.get('biome_counts', {}))}; footprints={','.join(batch_003.get('footprints', {}).keys())}")
        print(f"- errors={len(batch_003.get('errors', []))}; warnings={len(batch_003.get('warnings', []))}")
    batch_004 = report.get("content_batches", {}).get("batch_004_transit_coast_route_control", {})
    if batch_004:
        print("Content Batch 004:")
        role_counts = batch_004.get("role_counts", {})
        print(f"- objects: {batch_004.get('object_count', 0)}; two_way={role_counts.get('two_way_transit', 0)}; one_way={role_counts.get('one_way_transit', 0)}; locks={role_counts.get('route_lock', 0)}; coast_harbor={role_counts.get('coast_harbor', 0)}; waypoints={role_counts.get('route_waypoint', 0)}")
        print(f"- shape contracts={batch_004.get('shape_contract_ready_count', 0)}; linked endpoints={batch_004.get('linked_endpoint_contract_count', 0)}; route effects={batch_004.get('route_effect_metadata_count', 0)}; coast applicability={batch_004.get('coast_applicability_count', 0)}")
        print(f"- directionality={','.join(batch_004.get('directionality_counts', {}).keys())}; biomes covered={len(batch_004.get('biome_counts', {}))}; footprints={','.join(batch_004.get('footprints', {}).keys())}; normalized={batch_004.get('normalized_existing_count', 0)}")
        print(f"- metadata-only boundaries={batch_004.get('metadata_only_boundary_count', 0)}; no live ship system={batch_004.get('no_live_ship_system_count', 0)}; errors={len(batch_004.get('errors', []))}; warnings={len(batch_004.get('warnings', []))}")
    batch_005 = report.get("content_batches", {}).get("batch_005_dwellings_guarded_dwellings", {})
    if batch_005:
        print("Content Batch 005:")
        role_counts = batch_005.get("role_counts", {})
        print(f"- objects: {batch_005.get('object_count', 0)}; sites={batch_005.get('site_count', 0)}; normalized={role_counts.get('existing_dwelling_normalization', 0)}; new_basic={role_counts.get('new_basic_dwelling', 0)}; guarded_high_value={role_counts.get('guarded_high_value_dwelling', 0)}")
        print(f"- shape contracts={batch_005.get('shape_contract_ready_count', 0)}; linked site contracts={batch_005.get('linked_site_contract_count', 0)}; roster contracts={batch_005.get('roster_contract_ready_count', 0)}; guard contracts={batch_005.get('guard_contract_ready_count', 0)}")
        print(f"- biomes covered={len(batch_005.get('biome_counts', {}))}; footprints={','.join(batch_005.get('footprints', {}).keys())}; guarded variants={batch_005.get('guarded_variant_count', 0)}")
        print(f"- metadata-only boundaries={batch_005.get('metadata_only_boundary_count', 0)}; no rare-resource activation={batch_005.get('no_rare_resource_activation_count', 0)}; errors={len(batch_005.get('errors', []))}; warnings={len(batch_005.get('warnings', []))}")
    print(f"Warnings: {len(report['warnings'])}; Errors: {len(report['errors'])}")


def validate_strict_overworld_object_fixtures() -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    ensure(OVERWORLD_OBJECT_STRICT_CASES_PATH.exists(), errors, f"Missing strict overworld object fixture: {OVERWORLD_OBJECT_STRICT_CASES_PATH.relative_to(ROOT)}")
    if errors:
        return errors, warnings
    cases = load_json(OVERWORLD_OBJECT_STRICT_CASES_PATH)

    def strict_object_errors(obj: dict, label: str) -> list[str]:
        local_errors: list[str] = []
        object_id = str(obj.get("id", label))
        primary_class = str(obj.get("primary_class", ""))
        if primary_class not in OVERWORLD_OBJECT_PRIMARY_CLASSES:
            local_errors.append(f"{object_id} uses unsupported primary_class {primary_class}")
        tags = obj.get("secondary_tags", [])
        if not isinstance(tags, list):
            local_errors.append(f"{object_id} secondary_tags must be a list")
        else:
            for tag in tags:
                if str(tag) not in OVERWORLD_OBJECT_SECONDARY_TAGS:
                    local_errors.append(f"{object_id} uses unsupported secondary tag {tag}")
        family = str(obj.get("family", ""))
        if family and family not in SUPPORTED_MAP_OBJECT_FAMILIES:
            local_errors.append(f"{object_id} uses unsupported legacy family {family}")
        footprint = obj.get("footprint", {})
        if not isinstance(footprint, dict):
            local_errors.append(f"{object_id} footprint must be a dictionary")
            footprint = {}
        width = int(footprint.get("width", 0))
        height = int(footprint.get("height", 0))
        if width <= 0 or height <= 0:
            local_errors.append(f"{object_id} footprint dimensions must be positive")
        if str(footprint.get("anchor", "")) not in OVERWORLD_OBJECT_FOOTPRINT_ANCHORS:
            local_errors.append(f"{object_id} footprint anchor is missing or unsupported")
        if str(footprint.get("tier", "")) not in OVERWORLD_OBJECT_FOOTPRINT_TIERS:
            local_errors.append(f"{object_id} footprint tier is missing or unsupported")
        body_tiles = obj.get("body_tiles", [])
        if not isinstance(body_tiles, list) or not body_tiles:
            local_errors.append(f"{object_id} body_tiles must be a non-empty list")
        elif width > 0 and height > 0:
            for tile in body_tiles:
                if not isinstance(tile, dict):
                    local_errors.append(f"{object_id} body_tiles entries must be dictionaries")
                    continue
                x = int(tile.get("x", -999))
                y = int(tile.get("y", -999))
                if x < 0 or y < 0 or x >= width or y >= height:
                    local_errors.append(f"{object_id} body tile {x},{y} is outside footprint")
        passability_class = str(obj.get("passability_class", ""))
        if passability_class not in OVERWORLD_OBJECT_PASSABILITY_CLASSES:
            local_errors.append(f"{object_id} passability_class is missing or unsupported")
        interaction = obj.get("interaction", {})
        if not isinstance(interaction, dict):
            local_errors.append(f"{object_id} interaction must be a dictionary")
            interaction = {}
        cadence = str(interaction.get("cadence", ""))
        if cadence not in OVERWORLD_OBJECT_INTERACTION_CADENCES:
            local_errors.append(f"{object_id} interaction cadence is missing or unsupported")
        approach = obj.get("approach", {})
        visit_offsets = []
        if primary_class != "decoration" and cadence != "none":
            if not isinstance(approach, dict) or not approach:
                local_errors.append(f"{object_id} visitable/interactable object must define approach")
            else:
                mode = str(approach.get("mode", ""))
                if mode not in OVERWORLD_OBJECT_APPROACH_MODES:
                    local_errors.append(f"{object_id} approach mode is unsupported")
                sides = approach.get("primary_sides", [])
                if not isinstance(sides, list):
                    local_errors.append(f"{object_id} approach primary_sides must be a list")
                elif mode != "none":
                    for side in sides:
                        if str(side) not in OVERWORLD_OBJECT_APPROACH_SIDES:
                            local_errors.append(f"{object_id} approach side {side} is unsupported")
                visit_offsets = approach.get("visit_offsets", [])
                if mode in {"adjacent", "linked_endpoint"} and (not isinstance(visit_offsets, list) or not visit_offsets):
                    local_errors.append(f"{object_id} approach mode {mode} must define visit_offsets")
        if primary_class == "transit_route_object":
            route_effect = obj.get("route_effect", {})
            if not isinstance(route_effect, dict) or not route_effect:
                local_errors.append(f"{object_id} transit object must define route_effect in strict fixtures")
            else:
                missing_keys = sorted(OVERWORLD_OBJECT_ROUTE_EFFECT_REQUIRED_KEYS.difference(route_effect.keys()))
                if missing_keys:
                    local_errors.append(f"{object_id} route_effect is missing keys: {', '.join(missing_keys)}")
                if str(route_effect.get("effect_type", "")) not in OVERWORLD_OBJECT_ROUTE_EFFECT_TYPES:
                    local_errors.append(f"{object_id} route_effect effect_type is unsupported")
                if str(route_effect.get("effect_type", "")) == "linked_endpoint" and not str(route_effect.get("linked_endpoint_group_id", "")):
                    local_errors.append(f"{object_id} linked_endpoint route_effect must define linked_endpoint_group_id")
                if "movement_cost_delta" in route_effect and type(route_effect.get("movement_cost_delta")) is not int:
                    local_errors.append(f"{object_id} route_effect.movement_cost_delta must be an integer")
                toll_resources = route_effect.get("toll_resources", {})
                if not isinstance(toll_resources, dict):
                    local_errors.append(f"{object_id} route_effect.toll_resources must be a dictionary")
                else:
                    for resource_id, amount in toll_resources.items():
                        if str(resource_id) not in ECONOMY_STOCKPILE_RESOURCE_IDS:
                            local_errors.append(f"{object_id} route_effect toll resource {resource_id} is unsupported")
                        if type(amount) is not int or int(amount) < 0:
                            local_errors.append(f"{object_id} route_effect toll resource {resource_id} must be a non-negative integer")
                if set(overworld_object_tile_key(tile) for tile in body_tiles).intersection(set(overworld_object_tile_key(tile) for tile in visit_offsets)):
                    local_errors.append(f"{object_id} route-effect approach tiles must remain separate from body_tiles")
                if str(approach.get("mode", "")) == "linked_endpoint" and len(linked_exit_offsets := approach.get("linked_exit_offsets", []) if isinstance(approach.get("linked_exit_offsets", []), list) else []) != len(visit_offsets):
                    local_errors.append(f"{object_id} linked_endpoint linked_exit_offsets must match visit_offsets")
                for public_key in ("public_reason", "public_summary", "display_name"):
                    if public_key in route_effect:
                        public_text = str(route_effect.get(public_key, ""))
                        for token in OVERWORLD_OBJECT_PUBLIC_ROUTE_LEAK_TOKENS:
                            if token in public_text:
                                local_errors.append(f"{object_id} route_effect.{public_key} leaks internal token {token}")
        if primary_class == "guarded_reward_site":
            guard = obj.get("guard", {})
            reward_summary = obj.get("reward_summary", {})
            if not isinstance(guard, dict) or not guard:
                local_errors.append(f"{object_id} guarded reward object must define guard")
            if not isinstance(reward_summary, dict) or not reward_summary.get("reward_categories", []):
                local_errors.append(f"{object_id} guarded reward object must define reward_summary.reward_categories")
        if primary_class in {"persistent_economy_site", "neutral_dwelling", "faction_landmark"}:
            ownership = obj.get("ownership", {})
            if not isinstance(ownership, dict) or not ownership:
                local_errors.append(f"{object_id} persistent/capturable object must define ownership metadata")
            elif str(ownership.get("capture_model", "")) not in {"none", "claim_once", "capturable", "owned_static", "scenario_controlled"}:
                local_errors.append(f"{object_id} ownership capture_model is unsupported")
        animation_cues = obj.get("animation_cues", [])
        if primary_class != "decoration" and (not isinstance(animation_cues, list) or not animation_cues):
            local_errors.append(f"{object_id} non-decoration object must define placeholder animation_cues")
        editor_placement = obj.get("editor_placement", {})
        if not isinstance(editor_placement, dict) or not editor_placement:
            local_errors.append(f"{object_id} must define editor_placement metadata in strict fixtures")
        else:
            density_band = str(editor_placement.get("density_band", editor_placement.get("density_bucket", "")))
            if density_band not in OVERWORLD_OBJECT_EDITOR_DENSITY_BANDS:
                local_errors.append(f"{object_id} editor_placement must define a supported density_band or density_bucket")
            if "minimum_lane_clearance" in editor_placement:
                minimum_lane_clearance = editor_placement.get("minimum_lane_clearance")
                if type(minimum_lane_clearance) is not int or minimum_lane_clearance < 0:
                    local_errors.append(f"{object_id} editor_placement.minimum_lane_clearance must be a non-negative integer")
            placement_mode = str(editor_placement.get("placement_mode", ""))
            if placement_mode and placement_mode not in OVERWORLD_OBJECT_EDITOR_PLACEMENT_MODES:
                local_errors.append(f"{object_id} editor_placement.placement_mode is unsupported")
            for bool_key in OVERWORLD_OBJECT_EDITOR_BOOL_KEYS:
                if bool_key in editor_placement and type(editor_placement.get(bool_key)) is not bool:
                    local_errors.append(f"{object_id} editor_placement.{bool_key} must be boolean")
        ai_hints = obj.get("ai_hints", {})
        if primary_class != "decoration" and (not isinstance(ai_hints, dict) or not ai_hints):
            local_errors.append(f"{object_id} non-decoration object must define ai_hints in strict fixtures")
        return local_errors

    valid = cases.get("valid", {})
    for obj in valid.get("objects", []):
        errors.extend(strict_object_errors(obj, str(obj.get("id", "valid_object"))))
        if bool(obj.get("expect_animation_placeholder_warning", False)):
            warnings.append(f"{obj.get('id')}: animation cue ids are placeholder fixture ids")

    invalid = cases.get("invalid", {})
    for obj in invalid.get("objects", []):
        local_errors = strict_object_errors(obj, str(obj.get("id", "invalid_object")))
        if not local_errors:
            fail(errors, f"Strict invalid overworld object fixture {obj.get('id')} unexpectedly passed")
    return errors, warnings


def add_neutral_encounter_report_warning(report: dict, warning: str) -> None:
    if warning not in report["warnings"]:
        report["warnings"].append(warning)


def collect_neutral_encounter_script_spawns(scenarios: dict[str, dict]) -> dict[str, dict]:
    spawns: dict[str, dict] = {}
    for scenario_id, scenario in scenarios.items():
        scenario_spawns: list[dict] = []
        for hook in scenario.get("script_hooks", []):
            if not isinstance(hook, dict):
                continue
            hook_id = str(hook.get("id", "unknown_hook"))
            for effect in hook.get("effects", []):
                if not isinstance(effect, dict) or str(effect.get("type", "")) != "spawn_encounter":
                    continue
                placement = effect.get("placement", {})
                placement_id = str(placement.get("placement_id", "")) if isinstance(placement, dict) else ""
                encounter_id = str(placement.get("encounter_id", "")) if isinstance(placement, dict) else ""
                scenario_spawns.append({"hook_id": hook_id, "placement_id": placement_id, "encounter_id": encounter_id})
        if scenario_spawns:
            spawns[scenario_id] = {"scenario_id": scenario_id, "count": len(scenario_spawns), "spawns": scenario_spawns}
    return spawns


def neutral_encounter_reward_categories(encounter: dict) -> list[str]:
    rewards = encounter.get("rewards", {}) if isinstance(encounter, dict) else {}
    categories: list[str] = []
    if not isinstance(rewards, dict):
        return categories
    if int(rewards.get("gold", 0)) > 0:
        append_unique(categories, "gold")
        append_unique(categories, "small_resource")
    if int(rewards.get("experience", 0)) > 0:
        append_unique(categories, "experience")
    for reward_id, amount in rewards.items():
        if str(reward_id) not in {"gold", "experience"} and int(amount) > 0:
            append_unique(categories, "resource")
    return categories


def find_scenario_encounter_placement(scenarios: dict[str, dict], scenario_id: str, placement_id: str) -> dict | None:
    scenario = scenarios.get(scenario_id, {})
    for placement in scenario.get("encounters", []):
        if isinstance(placement, dict) and str(placement.get("placement_id", "")) == placement_id:
            return placement
    return None


def compare_expected_neutral_metadata(errors: list[str], label: str, actual, expected, path: str = "") -> None:
    current_path = path or label
    if isinstance(expected, dict):
        if not isinstance(actual, dict):
            fail(errors, f"{current_path} must be a dictionary")
            return
        actual_keys = set(actual.keys())
        expected_keys = set(expected.keys())
        for key in sorted(expected_keys - actual_keys):
            fail(errors, f"{current_path} is missing required key {key}")
        for key in sorted(actual_keys - expected_keys):
            fail(errors, f"{current_path} has out-of-scope key {key}")
        for key in sorted(expected_keys.intersection(actual_keys)):
            compare_expected_neutral_metadata(errors, label, actual.get(key), expected.get(key), f"{current_path}.{key}")
        return
    if actual != expected:
        fail(errors, f"{current_path} must equal {expected!r}; found {actual!r}")


def validate_neutral_encounter_representation_bundle(errors: list[str], scenarios: dict[str, dict]) -> None:
    bundle_placements = set(NEUTRAL_ENCOUNTER_BUNDLE_001_EXPECTED.keys())
    allowed_object_backed_metadata_placements = set(NEUTRAL_ENCOUNTER_BUNDLE_002_EXPECTED.keys())
    authored_bundle_ids: set[str] = set()
    for scenario_id, scenario in scenarios.items():
        for placement in scenario.get("encounters", []):
            if not isinstance(placement, dict):
                continue
            metadata = placement.get("neutral_encounter")
            if not isinstance(metadata, dict):
                continue
            placement_id = str(placement.get("placement_id", ""))
            if placement_id in bundle_placements:
                authored_bundle_ids.add(placement_id)
            else:
                ensure(placement_id in allowed_object_backed_metadata_placements, errors, f"Only declared neutral encounter metadata bundles may declare neutral_encounter metadata; found {scenario_id}:{placement_id}")

    for placement_id, expected in NEUTRAL_ENCOUNTER_BUNDLE_001_EXPECTED.items():
        scenario_id = str(expected["scenario_id"])
        placement = find_scenario_encounter_placement(scenarios, scenario_id, placement_id)
        ensure(isinstance(placement, dict), errors, f"neutral_encounter_representation_bundle_001 is missing placement {scenario_id}:{placement_id}")
        if not isinstance(placement, dict):
            continue
        for key, expected_value in expected["base"].items():
            ensure(placement.get(key) == expected_value, errors, f"{scenario_id}:{placement_id} must preserve {key}={expected_value!r}")
        metadata = placement.get("neutral_encounter")
        ensure(isinstance(metadata, dict), errors, f"{scenario_id}:{placement_id} must declare neutral_encounter metadata")
        if not isinstance(metadata, dict):
            continue
        compare_expected_neutral_metadata(errors, f"{scenario_id}:{placement_id}.neutral_encounter", metadata, expected["metadata"])

        guard_link = metadata.get("guard_link", {}) if isinstance(metadata, dict) else {}
        if placement_id == "ninefold_basalt_gatehouse_watch" and isinstance(guard_link, dict):
            scenario = scenarios.get(scenario_id, {})
            target_placement_id = str(guard_link.get("target_placement_id", ""))
            target_id = str(guard_link.get("target_id", ""))
            target = next(
                (
                    node
                    for node in scenario.get("resource_nodes", [])
                    if isinstance(node, dict) and str(node.get("placement_id", "")) == target_placement_id
                ),
                None,
            )
            ensure(isinstance(target, dict), errors, f"{scenario_id}:{placement_id} guard_link target_placement_id {target_placement_id} must reference a scenario resource node")
            if isinstance(target, dict):
                ensure(str(target.get("site_id", "")) == target_id, errors, f"{scenario_id}:{placement_id} guard_link target_id must match resource node site_id {target_id}")

    missing_authored = bundle_placements - authored_bundle_ids
    ensure(not missing_authored, errors, f"neutral_encounter_representation_bundle_001 missing authored metadata for: {', '.join(sorted(missing_authored))}")


def validate_neutral_encounter_first_class_object_bundle(errors: list[str], scenarios: dict[str, dict], map_objects: dict[str, dict]) -> None:
    bundle_placements = set(NEUTRAL_ENCOUNTER_FIRST_CLASS_OBJECT_BUNDLE_001.keys()) | set(NEUTRAL_ENCOUNTER_FIRST_CLASS_OBJECT_BUNDLE_002.keys())
    bundle_object_ids = {
        str(entry.get("object_id", ""))
        for entry in list(NEUTRAL_ENCOUNTER_FIRST_CLASS_OBJECT_BUNDLE_001.values()) + list(NEUTRAL_ENCOUNTER_FIRST_CLASS_OBJECT_BUNDLE_002.values())
    }
    authored_object_backed_placements: set[str] = set()

    for object_id, obj in map_objects.items():
        if str(obj.get("primary_class", "")) == "neutral_encounter":
            ensure(object_id in bundle_object_ids, errors, f"Only declared neutral encounter first-class bundles may declare primary_class neutral_encounter; found {object_id}")

    object_backing_keys = {"object_id", "object_placement_id", "encounter_ref", "legacy_scenario_encounter_ref", "authored_metadata"}
    for scenario_id, scenario in scenarios.items():
        for placement in scenario.get("encounters", []):
            if not isinstance(placement, dict):
                continue
            placement_id = str(placement.get("placement_id", ""))
            has_object_backing = any(key in placement for key in object_backing_keys) or str(placement.get("primary_class", "")) == "neutral_encounter"
            if not has_object_backing:
                continue
            authored_object_backed_placements.add(placement_id)
            ensure(placement_id in bundle_placements, errors, f"Only declared neutral encounter first-class bundles may declare object-backed neutral encounter metadata; found {scenario_id}:{placement_id}")

    for placement_id, object_expected in NEUTRAL_ENCOUNTER_FIRST_CLASS_OBJECT_BUNDLE_001.items():
        scenario_id = str(object_expected["scenario_id"])
        expected = NEUTRAL_ENCOUNTER_BUNDLE_001_EXPECTED[placement_id]
        placement = find_scenario_encounter_placement(scenarios, scenario_id, placement_id)
        ensure(isinstance(placement, dict), errors, f"{NEUTRAL_ENCOUNTER_FIRST_CLASS_OBJECT_BUNDLE_ID} is missing scenario placement {scenario_id}:{placement_id}")
        if not isinstance(placement, dict):
            continue

        for key, expected_value in expected["base"].items():
            ensure(placement.get(key) == expected_value, errors, f"{scenario_id}:{placement_id} object-backed bundle must preserve {key}={expected_value!r}")
        ensure(str(placement.get("object_id", "")) == object_expected["object_id"], errors, f"{scenario_id}:{placement_id} object_id must match {object_expected['object_id']}")
        ensure(str(placement.get("object_placement_id", "")) == object_expected["object_placement_id"], errors, f"{scenario_id}:{placement_id} object_placement_id must match {object_expected['object_placement_id']}")
        ensure(str(placement.get("primary_class", "")) == "neutral_encounter", errors, f"{scenario_id}:{placement_id} primary_class must be neutral_encounter")

        metadata = placement.get("neutral_encounter", {})
        ensure(isinstance(metadata, dict) and bool(metadata), errors, f"{scenario_id}:{placement_id} must keep source neutral_encounter metadata for lifted agreement")
        if isinstance(metadata, dict) and metadata:
            compare_expected_neutral_metadata(errors, f"{scenario_id}:{placement_id}.neutral_encounter", metadata, expected["metadata"])

        encounter_metadata = expected["metadata"]["encounter"]
        encounter_ref_expected = {
            "encounter_id": expected["base"]["encounter_id"],
            "primary_encounter_id": encounter_metadata["primary_encounter_id"],
            "encounter_ids": encounter_metadata["encounter_ids"],
            "difficulty": expected["base"]["difficulty"],
            "difficulty_source": encounter_metadata["difficulty_source"],
            "combat_seed": expected["base"]["combat_seed"],
            "combat_seed_source": encounter_metadata["combat_seed_source"],
            "field_objectives_source": encounter_metadata["field_objectives_source"],
            "preserve_placement_field_objectives": encounter_metadata["preserve_placement_field_objectives"],
        }
        compare_expected_neutral_metadata(errors, f"{scenario_id}:{placement_id}.encounter_ref", placement.get("encounter_ref", {}), encounter_ref_expected)

        legacy_ref_expected = {
            "placement_id": placement_id,
            "encounter_id": expected["base"]["encounter_id"],
            "source_list": "scenarios.encounters",
        }
        compare_expected_neutral_metadata(errors, f"{scenario_id}:{placement_id}.legacy_scenario_encounter_ref", placement.get("legacy_scenario_encounter_ref", {}), legacy_ref_expected)
        compare_expected_neutral_metadata(errors, f"{scenario_id}:{placement_id}.guard_link", placement.get("guard_link", {}), expected["metadata"]["guard_link"])
        compare_expected_neutral_metadata(
            errors,
            f"{scenario_id}:{placement_id}.authored_metadata",
            placement.get("authored_metadata", {}),
            {
                "bundle_id": NEUTRAL_ENCOUNTER_FIRST_CLASS_OBJECT_BUNDLE_ID,
                "lifted_from_bundle_id": NEUTRAL_ENCOUNTER_CANDIDATE_BUNDLE_ID,
            },
        )

        object_id = str(object_expected["object_id"])
        object_record = map_objects.get(object_id, {})
        ensure(isinstance(object_record, dict) and bool(object_record), errors, f"{NEUTRAL_ENCOUNTER_FIRST_CLASS_OBJECT_BUNDLE_ID} is missing map object {object_id}")
        if not isinstance(object_record, dict) or not object_record:
            continue
        missing_schema_fields = neutral_encounter_object_schema_missing_fields(object_record)
        ensure(not missing_schema_fields, errors, f"Map object {object_id} is missing first-class neutral encounter schema fields: {', '.join(missing_schema_fields)}")
        ensure(object_record.get("schema_version") == 1, errors, f"Map object {object_id} must declare schema_version 1")
        ensure(str(object_record.get("primary_class", "")) == "neutral_encounter", errors, f"Map object {object_id} primary_class must be neutral_encounter")
        ensure(str(object_record.get("family", "")) == "neutral_encounter", errors, f"Map object {object_id} family must be neutral_encounter")
        ensure(str(object_record.get("subtype", "")) == expected["metadata"]["representation"]["mode"], errors, f"Map object {object_id} subtype must match lifted representation mode")
        compare_expected_neutral_metadata(errors, f"{object_id}.secondary_tags", object_record.get("secondary_tags", []), expected["metadata"]["secondary_tags"])
        compare_expected_neutral_metadata(errors, f"{object_id}.footprint", object_record.get("footprint", {}), {"width": 1, "height": 1, "anchor": "bottom_center", "tier": "micro"})
        ensure(object_record.get("passable") is False, errors, f"Map object {object_id} passable must be false")
        ensure(object_record.get("visitable") is True, errors, f"Map object {object_id} visitable must be true")
        ensure(str(object_record.get("passability_class", "")) == expected["metadata"]["passability"]["passability_class"], errors, f"Map object {object_id} passability_class must match lifted passability")
        compare_expected_neutral_metadata(
            errors,
            f"{object_id}.interaction",
            object_record.get("interaction", {}),
            {
                "cadence": "one_time",
                "remains_after_visit": False,
                "state_after_visit": "cleared",
                "requires_ownership": False,
                "requires_guard_clear": False,
                "supports_revisit": False,
                "cooldown_days": 0,
                "refresh_rule": "none",
            },
        )
        compare_expected_neutral_metadata(errors, f"{object_id}.neutral_encounter", object_record.get("neutral_encounter", {}), expected["metadata"])

        guard_link = placement.get("guard_link", {})
        if isinstance(guard_link, dict):
            guard_target_resolution = neutral_encounter_guard_target_resolution(scenarios.get(scenario_id, {}), guard_link, map_objects)
            ensure(not guard_target_resolution["required"] or bool(guard_target_resolution["resolved"]), errors, f"{scenario_id}:{placement_id} guard target must resolve for {NEUTRAL_ENCOUNTER_FIRST_CLASS_OBJECT_BUNDLE_ID}")

    missing_object_backed = bundle_placements - authored_object_backed_placements
    ensure(not missing_object_backed, errors, f"Declared neutral encounter first-class bundles missing object-backed placements for: {', '.join(sorted(missing_object_backed))}")

    for placement_id, object_expected in NEUTRAL_ENCOUNTER_FIRST_CLASS_OBJECT_BUNDLE_002.items():
        scenario_id = str(object_expected["scenario_id"])
        expected = NEUTRAL_ENCOUNTER_BUNDLE_002_EXPECTED[placement_id]
        placement = find_scenario_encounter_placement(scenarios, scenario_id, placement_id)
        ensure(isinstance(placement, dict), errors, f"{NEUTRAL_ENCOUNTER_FIRST_CLASS_OBJECT_BUNDLE_002_ID} is missing scenario placement {scenario_id}:{placement_id}")
        if not isinstance(placement, dict):
            continue

        for key, expected_value in expected["base"].items():
            ensure(placement.get(key) == expected_value, errors, f"{scenario_id}:{placement_id} object-backed bundle 002 must preserve {key}={expected_value!r}")
        ensure(str(placement.get("object_id", "")) == object_expected["object_id"], errors, f"{scenario_id}:{placement_id} object_id must match {object_expected['object_id']}")
        ensure(str(placement.get("object_placement_id", "")) == object_expected["object_placement_id"], errors, f"{scenario_id}:{placement_id} object_placement_id must match {object_expected['object_placement_id']}")
        ensure(str(placement.get("primary_class", "")) == "neutral_encounter", errors, f"{scenario_id}:{placement_id} primary_class must be neutral_encounter")

        metadata = placement.get("neutral_encounter", {})
        ensure(isinstance(metadata, dict) and bool(metadata), errors, f"{scenario_id}:{placement_id} must declare bundle 002 neutral_encounter metadata")
        if isinstance(metadata, dict) and metadata:
            compare_expected_neutral_metadata(errors, f"{scenario_id}:{placement_id}.neutral_encounter", metadata, expected["metadata"])

        encounter_metadata = expected["metadata"]["encounter"]
        encounter_ref_expected = {
            "encounter_id": expected["base"]["encounter_id"],
            "primary_encounter_id": encounter_metadata["primary_encounter_id"],
            "encounter_ids": encounter_metadata["encounter_ids"],
            "difficulty": expected["base"]["difficulty"],
            "difficulty_source": encounter_metadata["difficulty_source"],
            "combat_seed": expected["base"]["combat_seed"],
            "combat_seed_source": encounter_metadata["combat_seed_source"],
            "field_objectives_source": encounter_metadata["field_objectives_source"],
            "preserve_placement_field_objectives": encounter_metadata["preserve_placement_field_objectives"],
        }
        compare_expected_neutral_metadata(errors, f"{scenario_id}:{placement_id}.encounter_ref", placement.get("encounter_ref", {}), encounter_ref_expected)

        legacy_ref_expected = {
            "placement_id": placement_id,
            "encounter_id": expected["base"]["encounter_id"],
            "source_list": "scenarios.encounters",
        }
        compare_expected_neutral_metadata(errors, f"{scenario_id}:{placement_id}.legacy_scenario_encounter_ref", placement.get("legacy_scenario_encounter_ref", {}), legacy_ref_expected)
        compare_expected_neutral_metadata(errors, f"{scenario_id}:{placement_id}.guard_link", placement.get("guard_link", {}), expected["metadata"]["guard_link"])
        compare_expected_neutral_metadata(errors, f"{scenario_id}:{placement_id}.authored_metadata", placement.get("authored_metadata", {}), {"bundle_id": NEUTRAL_ENCOUNTER_FIRST_CLASS_OBJECT_BUNDLE_002_ID})

        object_id = str(object_expected["object_id"])
        object_record = map_objects.get(object_id, {})
        ensure(isinstance(object_record, dict) and bool(object_record), errors, f"{NEUTRAL_ENCOUNTER_FIRST_CLASS_OBJECT_BUNDLE_002_ID} is missing map object {object_id}")
        if not isinstance(object_record, dict) or not object_record:
            continue
        missing_schema_fields = neutral_encounter_object_schema_missing_fields(object_record)
        ensure(not missing_schema_fields, errors, f"Map object {object_id} is missing first-class neutral encounter schema fields: {', '.join(missing_schema_fields)}")
        ensure(object_record.get("schema_version") == 1, errors, f"Map object {object_id} must declare schema_version 1")
        ensure(str(object_record.get("primary_class", "")) == "neutral_encounter", errors, f"Map object {object_id} primary_class must be neutral_encounter")
        ensure(str(object_record.get("family", "")) == "neutral_encounter", errors, f"Map object {object_id} family must be neutral_encounter")
        ensure(str(object_record.get("subtype", "")) == expected["metadata"]["representation"]["mode"], errors, f"Map object {object_id} subtype must match bundle 002 representation mode")
        compare_expected_neutral_metadata(errors, f"{object_id}.secondary_tags", object_record.get("secondary_tags", []), expected["metadata"]["secondary_tags"])
        compare_expected_neutral_metadata(errors, f"{object_id}.footprint", object_record.get("footprint", {}), {"width": 1, "height": 1, "anchor": "bottom_center", "tier": "micro"})
        compare_expected_neutral_metadata(errors, f"{object_id}.body_tiles", object_record.get("body_tiles", []), [{"x": 0, "y": 0, "role": "body"}])
        compare_expected_neutral_metadata(errors, f"{object_id}.approach", object_record.get("approach", {}), {"mode": "adjacent", "primary_sides": ["south"], "visit_offsets": [{"x": 0, "y": 1}], "stop_before_interaction": True, "requires_clear_tile": True, "linked_exit_offsets": []})
        ensure(object_record.get("passable") is False, errors, f"Map object {object_id} passable must be false")
        ensure(object_record.get("visitable") is True, errors, f"Map object {object_id} visitable must be true")
        ensure(str(object_record.get("passability_class", "")) == expected["metadata"]["passability"]["passability_class"], errors, f"Map object {object_id} passability_class must match bundle 002 passability")
        compare_expected_neutral_metadata(errors, f"{object_id}.interaction", object_record.get("interaction", {}), {"cadence": "one_time", "remains_after_visit": False, "state_after_visit": "cleared", "requires_ownership": False, "requires_guard_clear": False, "supports_revisit": False, "cooldown_days": 0, "refresh_rule": "none"})
        compare_expected_neutral_metadata(errors, f"{object_id}.neutral_encounter", object_record.get("neutral_encounter", {}), expected["metadata"])
        compare_expected_neutral_metadata(errors, f"{object_id}.editor_placement", object_record.get("editor_placement", {}), {"placement_mode": "scenario_encounter_overlay", "requires_approach_clearance": True, "requires_clear_adjacent_target": True, "warn_if_hiding_target": True, "density_bucket": "guard_or_encounter"})

        guard_link = placement.get("guard_link", {})
        if isinstance(guard_link, dict):
            guard_target_resolution = neutral_encounter_guard_target_resolution(scenarios.get(scenario_id, {}), guard_link, map_objects)
            ensure(not guard_target_resolution["required"] or bool(guard_target_resolution["resolved"]), errors, f"{scenario_id}:{placement_id} guard target must resolve for {NEUTRAL_ENCOUNTER_FIRST_CLASS_OBJECT_BUNDLE_002_ID}")


def neutral_encounter_metadata_presence(metadata: dict) -> dict[str, bool]:
    representation = metadata.get("representation", {}) if isinstance(metadata, dict) else {}
    return {
        "representation": isinstance(representation, dict) and bool(str(representation.get("mode", ""))),
        "danger": isinstance(representation, dict) and bool(str(representation.get("danger_cue_id", ""))),
        "guard": isinstance(metadata.get("guard_link", {}), dict) and bool(metadata.get("guard_link", {})),
        "state": isinstance(metadata.get("state_model", {}), dict) and bool(metadata.get("state_model", {})),
        "ownership": isinstance(metadata.get("placement_ownership", {}), dict) and bool(metadata.get("placement_ownership", {})),
        "reward": isinstance(metadata.get("reward_guard_summary", {}), dict) and bool(metadata.get("reward_guard_summary", {})),
        "passability": isinstance(metadata.get("passability", {}), dict) and bool(metadata.get("passability", {})),
        "ai": isinstance(metadata.get("ai_hints", {}), dict) and bool(metadata.get("ai_hints", {})),
        "editor": isinstance(metadata.get("editor_placement", {}), dict) and bool(metadata.get("editor_placement", {})),
    }


def neutral_encounter_object_schema_missing_fields(obj: dict) -> list[str]:
    if not isinstance(obj, dict) or not obj:
        return list(NEUTRAL_ENCOUNTER_OBJECT_SCHEMA_FIELDS)
    missing = [field for field in NEUTRAL_ENCOUNTER_OBJECT_SCHEMA_FIELDS if field not in obj]
    if str(obj.get("primary_class", "")) != "neutral_encounter" and "primary_class" not in missing:
        missing.append("primary_class")
    return sorted(set(missing))


def neutral_encounter_guard_target_resolution(scenario: dict, guard_link: dict, map_objects: dict[str, dict]) -> dict:
    if not isinstance(guard_link, dict) or not guard_link:
        return {"required": False, "resolved": False, "status": "missing_guard_link", "target_kind": "", "target_id": "", "target_placement_id": ""}
    target_kind = str(guard_link.get("target_kind", ""))
    target_id = str(guard_link.get("target_id", ""))
    target_placement_id = str(guard_link.get("target_placement_id", ""))
    result = {
        "required": target_kind not in {"", "none"},
        "resolved": target_kind in {"", "none"},
        "status": "not_required" if target_kind in {"", "none"} else "unresolved",
        "target_kind": target_kind,
        "target_id": target_id,
        "target_placement_id": target_placement_id,
    }
    if target_kind in {"", "none"}:
        return result
    if target_kind == "resource_node":
        target = next((node for node in scenario.get("resource_nodes", []) if isinstance(node, dict) and str(node.get("placement_id", "")) == target_placement_id), None)
        if isinstance(target, dict) and (not target_id or str(target.get("site_id", "")) == target_id):
            result.update({"resolved": True, "status": "resolved_resource_node"})
        elif isinstance(target, dict):
            result["status"] = "resource_node_target_id_mismatch"
        return result
    if target_kind == "artifact_node":
        target = next((node for node in scenario.get("artifact_nodes", []) if isinstance(node, dict) and str(node.get("placement_id", "")) == target_placement_id), None)
        if isinstance(target, dict) and (not target_id or str(target.get("artifact_id", "")) == target_id):
            result.update({"resolved": True, "status": "resolved_artifact_node"})
        elif isinstance(target, dict):
            result["status"] = "artifact_node_target_id_mismatch"
        return result
    if target_kind == "town":
        target = next((node for node in scenario.get("towns", []) if isinstance(node, dict) and str(node.get("placement_id", "")) == target_placement_id), None)
        if isinstance(target, dict) and (not target_id or str(target.get("town_id", "")) == target_id):
            result.update({"resolved": True, "status": "resolved_town"})
        elif isinstance(target, dict):
            result["status"] = "town_target_id_mismatch"
        return result
    if target_kind == "map_object":
        object_placements = [node for node in scenario.get("object_placements", []) if isinstance(node, dict)]
        placement_match = next((node for node in object_placements if str(node.get("object_placement_id", node.get("placement_id", ""))) == target_placement_id), None)
        if target_id in map_objects or isinstance(placement_match, dict):
            result.update({"resolved": True, "status": "resolved_map_object"})
        return result
    if target_kind == "scenario_objective":
        objective_ids = {
            str(objective.get("id", ""))
            for bucket in ("victory", "defeat")
            for objective in scenario.get("objectives", {}).get(bucket, [])
            if isinstance(objective, dict)
        }
        objective_placement_ids = {
            str(objective.get("placement_id", ""))
            for bucket in ("victory", "defeat")
            for objective in scenario.get("objectives", {}).get(bucket, [])
            if isinstance(objective, dict) and str(objective.get("placement_id", ""))
        }
        if target_id in objective_ids or target_placement_id in objective_placement_ids:
            result.update({"resolved": True, "status": "resolved_scenario_objective"})
        return result
    if target_kind == "route" and target_id:
        result.update({"resolved": True, "status": "route_advisory_id_present"})
    return result


def neutral_encounter_object_backing_info(placement: dict, neutral_metadata: dict, map_objects: dict[str, dict]) -> dict:
    authored_metadata = placement.get("authored_metadata", {}) if isinstance(placement, dict) else {}
    if not isinstance(authored_metadata, dict):
        authored_metadata = {}
    object_id = str(placement.get("object_id", ""))
    object_placement_id = str(placement.get("object_placement_id", ""))
    encounter_ref = placement.get("encounter_ref", {})
    legacy_ref = placement.get("legacy_scenario_encounter_ref", {})
    object_backed = bool(object_id or object_placement_id or (isinstance(encounter_ref, dict) and encounter_ref) or (isinstance(legacy_ref, dict) and legacy_ref))
    object_record = map_objects.get(object_id, {}) if object_id else {}
    missing_schema_fields = neutral_encounter_object_schema_missing_fields(object_record)
    authored_bundle_id = str(authored_metadata.get("bundle_id", ""))
    lifted_from_bundle_id = str(authored_metadata.get("lifted_from_bundle_id", ""))
    object_metadata = object_record.get("neutral_encounter", {}) if isinstance(object_record, dict) else {}
    lifted_metadata_agreement = "not_applicable"
    if object_backed:
        if authored_bundle_id == NEUTRAL_ENCOUNTER_FIRST_CLASS_OBJECT_BUNDLE_002_ID and not lifted_from_bundle_id:
            lifted_metadata_agreement = "not_lifted_declared_bundle"
        elif not lifted_from_bundle_id:
            lifted_metadata_agreement = "missing_lifted_from_bundle_id"
        elif not isinstance(neutral_metadata, dict) or not neutral_metadata:
            lifted_metadata_agreement = "missing_source_scenario_metadata"
        elif not isinstance(object_metadata, dict) or not object_metadata:
            lifted_metadata_agreement = "missing_object_neutral_encounter_metadata"
        else:
            lifted_metadata_agreement = "present_for_review"
    return {
        "object_backed": object_backed,
        "object_id": object_id,
        "object_placement_id": object_placement_id,
        "object_exists": bool(object_id and object_id in map_objects),
        "object_schema_fields_present": bool(object_id and object_id in map_objects and not missing_schema_fields),
        "authored_bundle_id": authored_bundle_id,
        "missing_object_schema_fields": missing_schema_fields,
        "lifted_from_bundle_id": lifted_from_bundle_id,
        "lifted_metadata_agreement": lifted_metadata_agreement,
        "encounter_ref_present": isinstance(encounter_ref, dict) and bool(encounter_ref),
        "legacy_placement_bridge_present": isinstance(legacy_ref, dict) and bool(legacy_ref),
    }


def build_neutral_encounter_report() -> dict:
    payloads = {key: load_json(CONTENT_DIR / f"{key}.json") for key in ("scenarios", "encounters", "map_objects")}
    scenarios = items_index(payloads["scenarios"])
    encounters = items_index(payloads["encounters"])
    map_objects = items_index(payloads["map_objects"])
    script_spawns = collect_neutral_encounter_script_spawns(scenarios)
    first_class_count = sum(1 for obj in map_objects.values() if str(obj.get("primary_class", "")) == "neutral_encounter")
    missing_metadata_keys = (
        "representation",
        "danger",
        "guard",
        "state",
        "ownership",
        "reward",
        "passability",
        "ai",
        "editor",
    )
    report = {
        "schema": NEUTRAL_ENCOUNTER_REPORT_SCHEMA,
        "generated_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        "mode": "compatibility_report",
        "compatibility_adapters": {
            "runtime_adoption": "not_active",
            "production_json_migration": False,
            "pathing_occupancy_adoption": False,
            "renderer_adoption": False,
            "ai_behavior_switch": False,
            "editor_behavior_switch": False,
            "save_migration": False,
            "report_normalization": "direct_scenario_encounters_as_inferred_visible_stacks",
        },
        "summary": {
            "scenario_count": len(scenarios),
            "encounter_definition_count": len(encounters),
            "direct_placement_count": 0,
            "script_spawn_encounter_count": sum(int(entry.get("count", 0)) for entry in script_spawns.values()),
            "first_class_neutral_encounter_object_count": first_class_count,
            "authored_bundle_metadata_count": 0,
            "difficulty_counts": {},
            "representation_mode_counts": {},
            "representation_mode_source_counts": {"authored": {}, "inferred": {}},
            "missing_future_metadata_counts": {key: 0 for key in missing_metadata_keys},
            "placement_authority_counts": {"direct_only": 0, "scenario_metadata": 0, "object_backed": 0, "object_backed_lifted": 0},
            "object_backed_placement_count": 0,
            "lifted_object_backed_placement_count": 0,
        },
        "first_class_object_migration": {
            "object_backed_placement_count": 0,
            "lifted_record_count": 0,
            "missing_object_id_count": 0,
            "missing_object_placement_id_count": 0,
            "missing_lifted_metadata_agreement_count": 0,
            "missing_guard_target_resolution_count": 0,
            "missing_object_schema_fields_count": 0,
            "object_schema_missing_field_counts": {},
            "authority_counts": {"direct_only": 0, "scenario_metadata": 0, "object_backed": 0, "object_backed_lifted": 0},
        },
        "scenarios": {},
        "placements": [],
        "repeated_encounter_ids": {},
        "field_objectives": {
            "placement_override_count": 0,
            "definition_backed_count": 0,
            "placement_overrides": [],
            "definition_backed": [],
        },
        "script_spawns": script_spawns,
        "guard_links": {"present_count": 0, "missing_count": 0, "inferred_none_count": 0, "role_counts": {"authored": {}, "inferred": {}}, "placements": []},
        "candidate_bundles": {},
        "warnings": [],
        "errors": [],
    }
    encounter_counts: dict[str, int] = {}
    candidate_lookup = NEUTRAL_ENCOUNTER_CANDIDATE_PLACEMENTS
    object_bundle_lookup = NEUTRAL_ENCOUNTER_FIRST_CLASS_OBJECT_BUNDLE_001

    for scenario_id, scenario in sorted(scenarios.items()):
        scenario_entry = {
            "scenario_id": scenario_id,
            "direct_encounter_count": 0,
            "difficulty_counts": {},
            "repeated_encounter_ids": {},
            "placement_field_objective_count": 0,
            "definition_field_objective_count": 0,
            "missing_representation_metadata_count": 0,
            "missing_guard_link_count": 0,
            "missing_danger_cue_count": 0,
            "placement_authority_counts": {"direct_only": 0, "scenario_metadata": 0, "object_backed": 0, "object_backed_lifted": 0},
            "object_backed_placement_count": 0,
            "candidate_bundle_placements": [],
            "script_spawn_encounter_count": int(script_spawns.get(scenario_id, {}).get("count", 0)),
        }
        local_encounter_counts: dict[str, int] = {}
        for placement in scenario.get("encounters", []):
            if not isinstance(placement, dict):
                continue
            placement_id = str(placement.get("placement_id", ""))
            encounter_id = str(placement.get("encounter_id", ""))
            difficulty = str(placement.get("difficulty", ""))
            encounter = encounters.get(encounter_id, {})
            encounter_exists = encounter_id in encounters
            candidate = candidate_lookup.get(placement_id, {})
            neutral_metadata = placement.get("neutral_encounter", {})
            metadata_authored = isinstance(neutral_metadata, dict) and bool(neutral_metadata)
            metadata_presence = neutral_encounter_metadata_presence(neutral_metadata if isinstance(neutral_metadata, dict) else {})
            authored_bundle_id = str(neutral_metadata.get("bundle_id", "")) if isinstance(neutral_metadata, dict) else ""
            candidate_bundle_id = authored_bundle_id if authored_bundle_id else (NEUTRAL_ENCOUNTER_CANDIDATE_BUNDLE_ID if candidate else "")
            representation = neutral_metadata.get("representation", {}) if isinstance(neutral_metadata, dict) else {}
            representation_mode = str(representation.get("mode", "")) if metadata_presence["representation"] else "visible_stack"
            representation_source = "authored" if metadata_presence["representation"] else "inferred"
            guard_link = neutral_metadata.get("guard_link", {}) if isinstance(neutral_metadata, dict) else {}
            guard_role = str(guard_link.get("guard_role", "")) if metadata_presence["guard"] else "none_inferred"
            guard_source = "authored" if metadata_presence["guard"] else "inferred"
            object_backing = neutral_encounter_object_backing_info(placement, neutral_metadata if isinstance(neutral_metadata, dict) else {}, map_objects)
            guard_target_resolution = neutral_encounter_guard_target_resolution(scenario, guard_link if isinstance(guard_link, dict) else {}, map_objects)
            if object_backing["object_backed"]:
                placement_authority = "object_backed_lifted" if object_backing["lifted_from_bundle_id"] else "object_backed"
            elif metadata_authored:
                placement_authority = "scenario_metadata"
            else:
                placement_authority = "direct_only"
            field_objective_source = "none"
            field_objective_count = 0
            placement_field_objectives = placement.get("field_objectives", [])
            definition_field_objectives = encounter.get("field_objectives", []) if isinstance(encounter, dict) else []
            if isinstance(placement_field_objectives, list) and placement_field_objectives:
                field_objective_source = "placement_override"
                field_objective_count = len(placement_field_objectives)
                scenario_entry["placement_field_objective_count"] += 1
                report["field_objectives"]["placement_override_count"] += 1
                report["field_objectives"]["placement_overrides"].append({"scenario_id": scenario_id, "placement_id": placement_id, "encounter_id": encounter_id, "field_objective_count": field_objective_count})
            if isinstance(definition_field_objectives, list) and definition_field_objectives:
                scenario_entry["definition_field_objective_count"] += 1
                report["field_objectives"]["definition_backed_count"] += 1
                report["field_objectives"]["definition_backed"].append({"scenario_id": scenario_id, "placement_id": placement_id, "encounter_id": encounter_id, "field_objective_count": len(definition_field_objectives)})
            if field_objective_source == "none" and isinstance(definition_field_objectives, list) and definition_field_objectives:
                field_objective_source = "encounter_definition"
                field_objective_count = len(definition_field_objectives)

            warning_by_metadata_key = {
                "representation": "future schema warning: missing neutral encounter representation metadata",
                "danger": "future schema warning: missing danger/readability cue",
                "guard": "future schema warning: missing guard_link metadata",
                "state": "future schema warning: missing state model metadata",
                "ownership": "future schema warning: missing placement ownership metadata",
                "reward": "future schema warning: missing reward/guard summary metadata",
                "passability": "future schema warning: missing passability metadata",
                "ai": "future schema warning: missing AI hint metadata",
                "editor": "future schema warning: missing editor placement metadata",
            }
            placement_warnings = [
                warning
                for key, warning in warning_by_metadata_key.items()
                if not metadata_presence.get(key, False)
            ]
            if not encounter_exists:
                report["errors"].append(f"{scenario_id}:{placement_id} references missing encounter_id {encounter_id}")
                placement_warnings.append("linked encounter definition is missing")
            if not object_backing["object_id"]:
                placement_warnings.append("first-class object warning: missing object_id")
                report["first_class_object_migration"]["missing_object_id_count"] += 1
            if not object_backing["object_placement_id"]:
                placement_warnings.append("first-class object warning: missing object_placement_id")
                report["first_class_object_migration"]["missing_object_placement_id_count"] += 1
            if object_backing["object_backed"] and object_backing["lifted_metadata_agreement"] not in {"present_for_review", "not_lifted_declared_bundle"}:
                placement_warnings.append(f"first-class object warning: missing lifted metadata agreement ({object_backing['lifted_metadata_agreement']})")
                report["first_class_object_migration"]["missing_lifted_metadata_agreement_count"] += 1
            if guard_target_resolution["required"] and not guard_target_resolution["resolved"]:
                placement_warnings.append(f"first-class object warning: missing guard target resolution ({guard_target_resolution['status']})")
                report["first_class_object_migration"]["missing_guard_target_resolution_count"] += 1
            if object_backing["missing_object_schema_fields"]:
                placement_warnings.append("first-class object warning: missing object schema fields")
                report["first_class_object_migration"]["missing_object_schema_fields_count"] += 1
                for missing_field in object_backing["missing_object_schema_fields"]:
                    increment_count(report["first_class_object_migration"]["object_schema_missing_field_counts"], missing_field)
            for key in missing_metadata_keys:
                if not metadata_presence.get(key, False):
                    report["summary"]["missing_future_metadata_counts"][key] += 1
            scenario_entry["direct_encounter_count"] += 1
            increment_count(report["summary"]["placement_authority_counts"], placement_authority)
            increment_count(report["first_class_object_migration"]["authority_counts"], placement_authority)
            increment_count(scenario_entry["placement_authority_counts"], placement_authority)
            if object_backing["object_backed"]:
                report["summary"]["object_backed_placement_count"] += 1
                report["first_class_object_migration"]["object_backed_placement_count"] += 1
                scenario_entry["object_backed_placement_count"] += 1
            if placement_authority == "object_backed_lifted":
                report["summary"]["lifted_object_backed_placement_count"] += 1
                report["first_class_object_migration"]["lifted_record_count"] += 1
            if metadata_authored:
                report["summary"]["authored_bundle_metadata_count"] += 1
            if not metadata_presence["representation"]:
                scenario_entry["missing_representation_metadata_count"] += 1
            if not metadata_presence["guard"]:
                scenario_entry["missing_guard_link_count"] += 1
            if not metadata_presence["danger"]:
                scenario_entry["missing_danger_cue_count"] += 1
            increment_count(report["summary"]["difficulty_counts"], difficulty)
            increment_count(report["summary"]["representation_mode_counts"], f"{representation_source}:{representation_mode}")
            increment_count(report["summary"]["representation_mode_source_counts"][representation_source], representation_mode)
            increment_count(scenario_entry["difficulty_counts"], difficulty)
            increment_count(encounter_counts, encounter_id)
            increment_count(local_encounter_counts, encounter_id)
            report["summary"]["direct_placement_count"] += 1
            if metadata_presence["guard"]:
                report["guard_links"]["present_count"] += 1
            else:
                report["guard_links"]["missing_count"] += 1
            if guard_source == "inferred":
                report["guard_links"]["inferred_none_count"] += 1
            increment_count(report["guard_links"]["role_counts"][guard_source], guard_role)
            report["guard_links"]["placements"].append(
                {
                    "scenario_id": scenario_id,
                    "placement_id": placement_id,
                    "encounter_id": encounter_id,
                    "guard_role": guard_role,
                    "guard_role_source": guard_source,
                    "guard_link_present": metadata_presence["guard"],
                    "target_kind": str(guard_link.get("target_kind", "")) if isinstance(guard_link, dict) else "",
                    "target_id": str(guard_link.get("target_id", "")) if isinstance(guard_link, dict) else "",
                    "target_placement_id": str(guard_link.get("target_placement_id", "")) if isinstance(guard_link, dict) else "",
                    "target_resolution_required": guard_target_resolution["required"],
                    "target_resolved": guard_target_resolution["resolved"],
                    "target_resolution_status": guard_target_resolution["status"],
                }
            )
            if candidate_bundle_id:
                scenario_entry["candidate_bundle_placements"].append(placement_id)
            for warning in placement_warnings:
                add_neutral_encounter_report_warning(report, f"{scenario_id}:{placement_id}: {warning}")
            report["placements"].append(
                {
                    "scenario_id": scenario_id,
                    "placement_id": placement_id,
                    "encounter_id": encounter_id,
                    "encounter_exists": encounter_exists,
                    "x": int(placement.get("x", 0)),
                    "y": int(placement.get("y", 0)),
                    "difficulty": difficulty,
                    "combat_seed": int(placement.get("combat_seed", 0)),
                    "inferred_primary_class": "neutral_encounter",
                    "representation_mode": representation_mode,
                    "representation_mode_source": representation_source,
                    "inferred_representation_mode": "visible_stack" if representation_source == "inferred" else "",
                    "authored_representation_mode": representation_mode if representation_source == "authored" else "",
                    "representation_metadata_present": metadata_presence["representation"],
                    "danger_cue_present": metadata_presence["danger"],
                    "guard_link_present": metadata_presence["guard"],
                    "guard_role": guard_role,
                    "guard_role_source": guard_source,
                    "inferred_guard_role": "none_inferred" if guard_source == "inferred" else "",
                    "authored_guard_role": guard_role if guard_source == "authored" else "",
                    "authored_bundle_id": authored_bundle_id,
                    "field_objectives_source": field_objective_source,
                    "field_objective_count": field_objective_count,
                    "reward_categories": neutral_encounter_reward_categories(encounter),
                    "candidate_bundle_id": candidate_bundle_id,
                    "placement_authority": placement_authority,
                    "object_backing": object_backing,
                    "guard_target_resolution": guard_target_resolution,
                    "warnings": placement_warnings,
                }
            )
        scenario_entry["difficulty_counts"] = sorted_counts(scenario_entry["difficulty_counts"])
        scenario_entry["placement_authority_counts"] = sorted_counts(scenario_entry["placement_authority_counts"])
        scenario_entry["repeated_encounter_ids"] = sorted_counts({encounter_id: count for encounter_id, count in local_encounter_counts.items() if count > 1})
        report["scenarios"][scenario_id] = scenario_entry

    report["summary"]["difficulty_counts"] = sorted_counts(report["summary"]["difficulty_counts"])
    report["summary"]["representation_mode_counts"] = sorted_counts(report["summary"]["representation_mode_counts"])
    report["summary"]["placement_authority_counts"] = sorted_counts(report["summary"]["placement_authority_counts"])
    report["first_class_object_migration"]["authority_counts"] = sorted_counts(report["first_class_object_migration"]["authority_counts"])
    report["first_class_object_migration"]["object_schema_missing_field_counts"] = sorted_counts(report["first_class_object_migration"]["object_schema_missing_field_counts"])
    report["summary"]["representation_mode_source_counts"]["authored"] = sorted_counts(report["summary"]["representation_mode_source_counts"]["authored"])
    report["summary"]["representation_mode_source_counts"]["inferred"] = sorted_counts(report["summary"]["representation_mode_source_counts"]["inferred"])
    report["guard_links"]["role_counts"]["authored"] = sorted_counts(report["guard_links"]["role_counts"]["authored"])
    report["guard_links"]["role_counts"]["inferred"] = sorted_counts(report["guard_links"]["role_counts"]["inferred"])
    report["repeated_encounter_ids"] = sorted_counts({encounter_id: count for encounter_id, count in encounter_counts.items() if count > 1})
    candidate_placements = []
    candidate_warnings = []
    for placement_id, candidate in sorted(candidate_lookup.items()):
        match = next((placement for placement in report["placements"] if placement.get("placement_id") == placement_id and placement.get("scenario_id") == candidate.get("scenario_id")), None)
        exists = match is not None and bool(match.get("encounter_exists", False))
        metadata_authored = match is not None and str(match.get("authored_bundle_id", "")) == NEUTRAL_ENCOUNTER_CANDIDATE_BUNDLE_ID
        candidate_placements.append({**candidate, "placement_id": placement_id, "placement_exists": match is not None, "encounter_exists": exists, "metadata_authored": metadata_authored})
        if match is None:
            candidate_warnings.append(f"candidate placement {placement_id} is not present in current scenario encounters")
        elif not metadata_authored:
            candidate_warnings.append(f"candidate placement {placement_id} has no authored {NEUTRAL_ENCOUNTER_CANDIDATE_BUNDLE_ID} metadata")
    bundle_metadata_authored = all(bool(placement.get("metadata_authored", False)) for placement in candidate_placements)
    report["candidate_bundles"][NEUTRAL_ENCOUNTER_CANDIDATE_BUNDLE_ID] = {
        "bundle_id": NEUTRAL_ENCOUNTER_CANDIDATE_BUNDLE_ID,
        "status": "metadata_authored" if bundle_metadata_authored else "planning_only",
        "production_json_migration": bundle_metadata_authored,
        "production_json_migration_scope": "scenario_placement_metadata_only" if bundle_metadata_authored else "none",
        "placement_count": len(candidate_placements),
        "placements": candidate_placements,
        "required_before_migration": [] if bundle_metadata_authored else [
            "review opt-in neutral encounter report output",
            "approve a production metadata bundle explicitly",
            "keep runtime/pathing/AI/editor/renderer adoption in later slices",
        ],
        "warnings": candidate_warnings,
    }
    object_bundle_placements = []
    object_bundle_warnings = []
    for placement_id, object_expected in sorted(object_bundle_lookup.items()):
        match = next((placement for placement in report["placements"] if placement.get("placement_id") == placement_id and placement.get("scenario_id") == object_expected.get("scenario_id")), None)
        object_backing = match.get("object_backing", {}) if isinstance(match, dict) else {}
        object_backed = match is not None and bool(object_backing.get("object_backed", False))
        lifted = match is not None and str(match.get("placement_authority", "")) == "object_backed_lifted"
        object_id_matches = bool(object_backing.get("object_id", "") == object_expected.get("object_id", ""))
        object_placement_id_matches = bool(object_backing.get("object_placement_id", "") == object_expected.get("object_placement_id", ""))
        schema_present = bool(object_backing.get("object_schema_fields_present", False))
        object_bundle_placements.append({
            **object_expected,
            "placement_id": placement_id,
            "placement_exists": match is not None,
            "object_backed": object_backed,
            "lifted_from_bundle_id": str(object_backing.get("lifted_from_bundle_id", "")) if isinstance(object_backing, dict) else "",
            "lifted": lifted,
            "object_id_matches": object_id_matches,
            "object_placement_id_matches": object_placement_id_matches,
            "object_schema_fields_present": schema_present,
        })
        if match is None:
            object_bundle_warnings.append(f"object-backed bundle placement {placement_id} is not present in current scenario encounters")
        elif not object_backed:
            object_bundle_warnings.append(f"object-backed bundle placement {placement_id} has no object backing")
        elif not lifted:
            object_bundle_warnings.append(f"object-backed bundle placement {placement_id} is not marked lifted from {NEUTRAL_ENCOUNTER_CANDIDATE_BUNDLE_ID}")
        elif not object_id_matches:
            object_bundle_warnings.append(f"object-backed bundle placement {placement_id} object_id does not match planned id")
        elif not object_placement_id_matches:
            object_bundle_warnings.append(f"object-backed bundle placement {placement_id} object_placement_id does not match planned id")
        elif not schema_present:
            object_bundle_warnings.append(f"object-backed bundle placement {placement_id} object schema fields are incomplete")
    object_bundle_authored = all(
        bool(placement.get("object_backed", False))
        and bool(placement.get("lifted", False))
        and bool(placement.get("object_id_matches", False))
        and bool(placement.get("object_placement_id_matches", False))
        and bool(placement.get("object_schema_fields_present", False))
        for placement in object_bundle_placements
    )
    report["candidate_bundles"][NEUTRAL_ENCOUNTER_FIRST_CLASS_OBJECT_BUNDLE_ID] = {
        "bundle_id": NEUTRAL_ENCOUNTER_FIRST_CLASS_OBJECT_BUNDLE_ID,
        "status": "metadata_authored" if object_bundle_authored else "planning_only",
        "production_json_migration": object_bundle_authored,
        "production_json_migration_scope": "metadata_only_first_class_object_records" if object_bundle_authored else "none",
        "placement_count": len(object_bundle_placements),
        "placements": object_bundle_placements,
        "runtime_adoption": "not_active",
        "pathing_occupancy_adoption": False,
        "renderer_adoption": False,
        "ai_behavior_switch": False,
        "editor_behavior_switch": False,
        "save_migration": False,
        "warnings": object_bundle_warnings,
    }
    object_bundle_002_placements = []
    object_bundle_002_warnings = []
    for placement_id, object_expected in sorted(NEUTRAL_ENCOUNTER_FIRST_CLASS_OBJECT_BUNDLE_002.items()):
        match = next((placement for placement in report["placements"] if placement.get("placement_id") == placement_id and placement.get("scenario_id") == object_expected.get("scenario_id")), None)
        object_backing = match.get("object_backing", {}) if isinstance(match, dict) else {}
        guard_resolution = match.get("guard_target_resolution", {}) if isinstance(match, dict) else {}
        object_backed = match is not None and bool(object_backing.get("object_backed", False))
        object_id_matches = bool(object_backing.get("object_id", "") == object_expected.get("object_id", ""))
        object_placement_id_matches = bool(object_backing.get("object_placement_id", "") == object_expected.get("object_placement_id", ""))
        schema_present = bool(object_backing.get("object_schema_fields_present", False))
        guard_resolved = bool(guard_resolution.get("resolved", False))
        declared_new_bundle = str(object_backing.get("authored_bundle_id", "")) == NEUTRAL_ENCOUNTER_FIRST_CLASS_OBJECT_BUNDLE_002_ID
        object_bundle_002_placements.append({
            **object_expected,
            "placement_id": placement_id,
            "placement_exists": match is not None,
            "object_backed": object_backed,
            "bundle_id_matches": declared_new_bundle,
            "object_id_matches": object_id_matches,
            "object_placement_id_matches": object_placement_id_matches,
            "object_schema_fields_present": schema_present,
            "guard_target_resolved": guard_resolved,
            "lifted": False,
        })
        if match is None:
            object_bundle_002_warnings.append(f"object-backed bundle 002 placement {placement_id} is not present in current scenario encounters")
        elif not object_backed:
            object_bundle_002_warnings.append(f"object-backed bundle 002 placement {placement_id} has no object backing")
        elif not declared_new_bundle:
            object_bundle_002_warnings.append(f"object-backed bundle 002 placement {placement_id} is not marked as {NEUTRAL_ENCOUNTER_FIRST_CLASS_OBJECT_BUNDLE_002_ID}")
        elif not object_id_matches:
            object_bundle_002_warnings.append(f"object-backed bundle 002 placement {placement_id} object_id does not match planned id")
        elif not object_placement_id_matches:
            object_bundle_002_warnings.append(f"object-backed bundle 002 placement {placement_id} object_placement_id does not match planned id")
        elif not schema_present:
            object_bundle_002_warnings.append(f"object-backed bundle 002 placement {placement_id} object schema fields are incomplete")
        elif not guard_resolved:
            object_bundle_002_warnings.append(f"object-backed bundle 002 placement {placement_id} scenario objective guard target does not resolve")
    object_bundle_002_authored = all(
        bool(placement.get("object_backed", False))
        and bool(placement.get("bundle_id_matches", False))
        and bool(placement.get("object_id_matches", False))
        and bool(placement.get("object_placement_id_matches", False))
        and bool(placement.get("object_schema_fields_present", False))
        and bool(placement.get("guard_target_resolved", False))
        for placement in object_bundle_002_placements
    )
    report["candidate_bundles"][NEUTRAL_ENCOUNTER_FIRST_CLASS_OBJECT_BUNDLE_002_ID] = {
        "bundle_id": NEUTRAL_ENCOUNTER_FIRST_CLASS_OBJECT_BUNDLE_002_ID,
        "status": "metadata_authored" if object_bundle_002_authored else "planning_only",
        "production_json_migration": object_bundle_002_authored,
        "production_json_migration_scope": "metadata_only_first_class_object_records_with_shape_mask_metadata" if object_bundle_002_authored else "none",
        "placement_count": len(object_bundle_002_placements),
        "placements": object_bundle_002_placements,
        "runtime_adoption": "not_active",
        "pathing_occupancy_adoption": False,
        "renderer_adoption": False,
        "ai_behavior_switch": False,
        "editor_behavior_switch": False,
        "save_migration": False,
        "warnings": object_bundle_002_warnings,
    }
    if first_class_count == 0:
        add_neutral_encounter_report_warning(report, "no first-class neutral_encounter map object records exist yet; direct scenario encounter placements remain compatibility source")
    if report["first_class_object_migration"]["object_backed_placement_count"] == 0:
        add_neutral_encounter_report_warning(report, "no object-backed neutral encounter placements exist yet; direct-only and scenario-metadata placements remain report authority")
    add_neutral_encounter_report_warning(report, "unmigrated production direct encounter placements remain legacy-compatible outside declared neutral encounter metadata bundles")
    add_neutral_encounter_report_warning(report, f"strict neutral encounter fixture checks remain isolated; migrated production bundle checks cover only {NEUTRAL_ENCOUNTER_CANDIDATE_BUNDLE_ID}, {NEUTRAL_ENCOUNTER_FIRST_CLASS_OBJECT_BUNDLE_ID}, and {NEUTRAL_ENCOUNTER_FIRST_CLASS_OBJECT_BUNDLE_002_ID}")
    return report


def print_neutral_encounter_report(report: dict) -> None:
    print("NEUTRAL ENCOUNTER REPORT")
    print(f"- schema: {report['schema']}")
    print(f"- mode: {report['mode']}")
    print(f"- scenarios: {report['summary']['scenario_count']}; encounter definitions: {report['summary']['encounter_definition_count']}")
    print(f"- direct placements: {report['summary']['direct_placement_count']}; script-spawn advisory count: {report['summary']['script_spawn_encounter_count']}")
    print(f"- first-class neutral encounter objects: {report['summary']['first_class_neutral_encounter_object_count']}")
    print("Placement authority:")
    for authority, count in report["summary"]["placement_authority_counts"].items():
        print(f"- {authority}: {count}")
    object_migration = report["first_class_object_migration"]
    print("First-class object migration warnings:")
    print(f"- object-backed placements={object_migration['object_backed_placement_count']}; lifted records={object_migration['lifted_record_count']}")
    print(f"- missing object_id={object_migration['missing_object_id_count']}; missing object_placement_id={object_migration['missing_object_placement_id_count']}")
    print(f"- missing lifted agreement={object_migration['missing_lifted_metadata_agreement_count']}; missing guard target resolution={object_migration['missing_guard_target_resolution_count']}; missing object schema fields={object_migration['missing_object_schema_fields_count']}")
    print("Difficulty counts:")
    for difficulty, count in report["summary"]["difficulty_counts"].items():
        print(f"- {difficulty}: {count}")
    print("Scenario counts:")
    for scenario_id, scenario in report["scenarios"].items():
        print(f"- {scenario_id}: direct={scenario['direct_encounter_count']}; scripts={scenario['script_spawn_encounter_count']}; candidates={len(scenario['candidate_bundle_placements'])}")
    print("Repeated encounter ids:")
    for encounter_id, count in report["repeated_encounter_ids"].items():
        print(f"- {encounter_id}: {count}")
    print("Field objectives:")
    print(f"- placement overrides: {report['field_objectives']['placement_override_count']}; definition-backed: {report['field_objectives']['definition_backed_count']}")
    missing = report["summary"]["missing_future_metadata_counts"]
    print("Future metadata warnings:")
    print(f"- representation={missing['representation']}; danger={missing['danger']}; guard={missing['guard']}; state={missing['state']}; ownership={missing['ownership']}")
    print(f"- reward={missing['reward']}; passability={missing['passability']}; ai={missing['ai']}; editor={missing['editor']}")
    print("Representation modes:")
    for source, counts in report["summary"]["representation_mode_source_counts"].items():
        for mode, count in counts.items():
            print(f"- {source}:{mode}: {count}")
    print("Guard link roles:")
    for source, counts in report["guard_links"]["role_counts"].items():
        for role, count in counts.items():
            print(f"- {source}:{role}: {count}")
    print("Candidate bundles:")
    for bundle in report["candidate_bundles"].values():
        print(f"- {bundle['bundle_id']}: {bundle['status']}; placements={bundle['placement_count']}; production_json_migration={bundle['production_json_migration']}")
        if bundle.get("runtime_adoption", ""):
            print(f"- {bundle['bundle_id']} runtime adoption: {bundle['runtime_adoption']}; pathing occupancy adoption={bundle.get('pathing_occupancy_adoption', False)}")
    print(f"- runtime adoption: {report['compatibility_adapters']['runtime_adoption']}; pathing occupancy adoption={report['compatibility_adapters']['pathing_occupancy_adoption']}")
    print(f"Warnings: {len(report['warnings'])}; Errors: {len(report['errors'])}")


def validate_strict_neutral_encounter_fixtures() -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    ensure(NEUTRAL_ENCOUNTER_STRICT_CASES_PATH.exists(), errors, f"Missing strict neutral encounter fixture: {NEUTRAL_ENCOUNTER_STRICT_CASES_PATH.relative_to(ROOT)}")
    if errors:
        return errors, warnings
    cases = load_json(NEUTRAL_ENCOUNTER_STRICT_CASES_PATH)
    fixture_encounters = {str(item.get("id", "")): item for item in cases.get("encounter_definitions", []) if isinstance(item, dict) and str(item.get("id", ""))}
    fixture_neutral_encounters = {
        str(item.get("id", "")): item
        for item in cases.get("valid", {}).get("neutral_encounters", [])
        if isinstance(item, dict) and str(item.get("id", ""))
    }

    def strict_neutral_encounter_errors(obj: dict, label: str) -> list[str]:
        local_errors: list[str] = []
        object_id = str(obj.get("id", label))
        encounter = obj.get("encounter", {})
        if not isinstance(encounter, dict) or not encounter:
            local_errors.append(f"{object_id} must define encounter metadata")
            encounter = {}
        primary_encounter_id = str(encounter.get("primary_encounter_id", ""))
        encounter_ids = encounter.get("encounter_ids", [])
        if not primary_encounter_id:
            local_errors.append(f"{object_id} must define primary_encounter_id")
        elif primary_encounter_id not in fixture_encounters:
            local_errors.append(f"{object_id} references unknown primary_encounter_id {primary_encounter_id}")
        if not isinstance(encounter_ids, list) or primary_encounter_id not in [str(value) for value in encounter_ids]:
            local_errors.append(f"{object_id} encounter_ids must include primary_encounter_id")

        representation = obj.get("representation", {})
        if not isinstance(representation, dict) or not representation:
            local_errors.append(f"{object_id} must define representation metadata")
            representation = {}
        mode = str(representation.get("mode", ""))
        if mode not in NEUTRAL_ENCOUNTER_REPRESENTATION_MODES:
            local_errors.append(f"{object_id} uses unsupported representation mode {mode}")
        if not str(representation.get("readability_family", "")):
            local_errors.append(f"{object_id} representation must define readability_family")
        if not str(representation.get("danger_cue_id", "")):
            local_errors.append(f"{object_id} representation must define danger_cue_id")
        if type(representation.get("visible_before_interaction", None)) is not bool:
            local_errors.append(f"{object_id} representation.visible_before_interaction must be boolean")

        guard_link = obj.get("guard_link", {})
        if not isinstance(guard_link, dict) or not guard_link:
            local_errors.append(f"{object_id} must define guard_link metadata")
            guard_link = {}
        guard_role = str(guard_link.get("guard_role", ""))
        target_kind = str(guard_link.get("target_kind", ""))
        if guard_role not in NEUTRAL_ENCOUNTER_GUARD_ROLES:
            local_errors.append(f"{object_id} guard_link.guard_role is missing or unsupported")
        if target_kind not in NEUTRAL_ENCOUNTER_TARGET_KINDS:
            local_errors.append(f"{object_id} guard_link.target_kind is missing or unsupported")
        guard_linked = mode in {"guard_linked_stack", "guard_linked_camp"}
        if guard_linked:
            if guard_role == "none":
                local_errors.append(f"{object_id} guard-linked encounter cannot use guard_role none")
            if target_kind == "none":
                local_errors.append(f"{object_id} guard-linked encounter must define target_kind")
            if not str(guard_link.get("target_id", "")) and not str(guard_link.get("target_placement_id", "")):
                local_errors.append(f"{object_id} guard-linked encounter must define target_id or target_placement_id")
            if type(guard_link.get("clear_required_for_target", None)) is not bool:
                local_errors.append(f"{object_id} guard-linked encounter must define clear_required_for_target as boolean")
        elif guard_role != "none" and target_kind == "none":
            local_errors.append(f"{object_id} non-linked guard role must still define a target kind")

        state_model = obj.get("state_model", {})
        if not isinstance(state_model, dict) or not state_model:
            local_errors.append(f"{object_id} must define state_model")
            state_model = {}
        if str(state_model.get("initial_state", "")) not in NEUTRAL_ENCOUNTER_STATES:
            local_errors.append(f"{object_id} state_model.initial_state is missing or unsupported")
        if str(state_model.get("state_after_victory", "")) not in NEUTRAL_ENCOUNTER_STATES:
            local_errors.append(f"{object_id} state_model.state_after_victory is missing or unsupported")
        for bool_key in ("remove_on_clear", "remember_after_clear"):
            if type(state_model.get(bool_key, None)) is not bool:
                local_errors.append(f"{object_id} state_model.{bool_key} must be boolean")
        if mode in {"camp_anchor", "guard_linked_camp"} and bool(state_model.get("remove_on_clear", True)):
            local_errors.append(f"{object_id} camp representation should keep depleted/cleared state instead of remove_on_clear")

        placement_ownership = obj.get("placement_ownership", {})
        if not isinstance(placement_ownership, dict) or not placement_ownership:
            local_errors.append(f"{object_id} must define placement_ownership")
            placement_ownership = {}
        if str(placement_ownership.get("ownership_model", "")) not in NEUTRAL_ENCOUNTER_OWNERSHIP_MODELS:
            local_errors.append(f"{object_id} placement_ownership.ownership_model is missing or unsupported")

        reward_guard_summary = obj.get("reward_guard_summary", {})
        if not isinstance(reward_guard_summary, dict) or not reward_guard_summary:
            local_errors.append(f"{object_id} must define reward_guard_summary")
            reward_guard_summary = {}
        if str(reward_guard_summary.get("risk_tier", "")) not in NEUTRAL_ENCOUNTER_RISK_TIERS:
            local_errors.append(f"{object_id} reward_guard_summary.risk_tier is missing or unsupported")
        reward_categories = reward_guard_summary.get("reward_categories", [])
        if (guard_linked or target_kind != "none") and (not isinstance(reward_categories, list) or not reward_categories):
            local_errors.append(f"{object_id} guard-target encounter must define reward_guard_summary.reward_categories")

        passability = obj.get("passability", {})
        if not isinstance(passability, dict) or not passability:
            local_errors.append(f"{object_id} must define passability metadata")
            passability = {}
        if str(passability.get("passability_class", "")) not in NEUTRAL_ENCOUNTER_PASSABILITY_CLASSES:
            local_errors.append(f"{object_id} passability.passability_class is missing or unsupported")
        if str(passability.get("interaction_mode", "")) not in {"enter", "adjacent"}:
            local_errors.append(f"{object_id} passability.interaction_mode is missing or unsupported")

        ai_hints = obj.get("ai_hints", {})
        if not isinstance(ai_hints, dict) or not ai_hints:
            local_errors.append(f"{object_id} must define ai_hints")
        editor_placement = obj.get("editor_placement", {})
        if not isinstance(editor_placement, dict) or not editor_placement:
            local_errors.append(f"{object_id} must define editor_placement")
        return local_errors

    def resolve_fixture_neutral_metadata(value) -> dict | None:
        if isinstance(value, dict) and "fixture_ref" in value:
            return fixture_neutral_encounters.get(str(value.get("fixture_ref", "")))
        if isinstance(value, str):
            return fixture_neutral_encounters.get(value)
        if isinstance(value, dict):
            return value
        return None

    def strict_object_backed_neutral_encounter_errors(record: dict, label: str) -> list[str]:
        local_errors: list[str] = []
        record_id = str(record.get("id", label))
        scenario_placement = record.get("scenario_placement", {})
        object_record = record.get("object", {})
        lifted_metadata = resolve_fixture_neutral_metadata(record.get("lifted_scenario_metadata", {}))
        if not isinstance(scenario_placement, dict) or not scenario_placement:
            local_errors.append(f"{record_id} must define scenario_placement")
            scenario_placement = {}
        if not isinstance(object_record, dict) or not object_record:
            local_errors.append(f"{record_id} must define object")
            object_record = {}

        placement_id = str(scenario_placement.get("placement_id", ""))
        object_id = str(scenario_placement.get("object_id", ""))
        object_placement_id = str(scenario_placement.get("object_placement_id", ""))
        if not object_id:
            local_errors.append(f"{record_id} scenario_placement must define object_id")
        if object_id and str(object_record.get("id", "")) != object_id:
            local_errors.append(f"{record_id} object.id must match scenario_placement.object_id")
        if not object_placement_id:
            local_errors.append(f"{record_id} scenario_placement must define object_placement_id")
        if str(scenario_placement.get("primary_class", "")) != "neutral_encounter":
            local_errors.append(f"{record_id} scenario_placement.primary_class must be neutral_encounter")

        missing_schema_fields = neutral_encounter_object_schema_missing_fields(object_record)
        if missing_schema_fields:
            local_errors.append(f"{record_id} object is missing first-class schema fields: {', '.join(missing_schema_fields)}")
        if str(object_record.get("primary_class", "")) != "neutral_encounter":
            local_errors.append(f"{record_id} object.primary_class must be neutral_encounter")
        object_metadata = resolve_fixture_neutral_metadata(object_record.get("neutral_encounter", {}))
        if not isinstance(object_metadata, dict):
            local_errors.append(f"{record_id} object.neutral_encounter must resolve to fixture metadata")
            object_metadata = {}
        else:
            local_errors.extend(strict_neutral_encounter_errors({**object_metadata, "id": f"{record_id}.object.neutral_encounter"}, f"{record_id}.object.neutral_encounter"))

        encounter_ref = scenario_placement.get("encounter_ref", {})
        if not isinstance(encounter_ref, dict) or not encounter_ref:
            local_errors.append(f"{record_id} scenario_placement must define encounter_ref")
            encounter_ref = {}
        primary_encounter_id = str(encounter_ref.get("primary_encounter_id", encounter_ref.get("encounter_id", "")))
        encounter_ids = encounter_ref.get("encounter_ids", [])
        if primary_encounter_id not in fixture_encounters:
            local_errors.append(f"{record_id} encounter_ref references unknown primary encounter {primary_encounter_id}")
        if isinstance(encounter_ids, list) and primary_encounter_id and primary_encounter_id not in [str(value) for value in encounter_ids]:
            local_errors.append(f"{record_id} encounter_ref.encounter_ids must include primary_encounter_id")

        legacy_ref = scenario_placement.get("legacy_scenario_encounter_ref", {})
        if not isinstance(legacy_ref, dict) or not legacy_ref:
            local_errors.append(f"{record_id} scenario_placement must define legacy_scenario_encounter_ref")
            legacy_ref = {}
        if placement_id and str(legacy_ref.get("placement_id", "")) != placement_id:
            local_errors.append(f"{record_id} legacy_scenario_encounter_ref.placement_id must match scenario placement_id")
        if primary_encounter_id and str(legacy_ref.get("encounter_id", "")) != primary_encounter_id:
            local_errors.append(f"{record_id} legacy_scenario_encounter_ref.encounter_id must match primary encounter")

        object_encounter = object_metadata.get("encounter", {}) if isinstance(object_metadata, dict) else {}
        object_field_source = str(object_encounter.get("field_objectives_source", ""))
        placement_field_source = str(encounter_ref.get("field_objectives_source", ""))
        if object_field_source and placement_field_source and object_field_source != placement_field_source:
            local_errors.append(f"{record_id} field_objectives_source must agree between object metadata and encounter_ref")
        if isinstance(lifted_metadata, dict):
            lifted_encounter = lifted_metadata.get("encounter", {})
            lifted_field_source = str(lifted_encounter.get("field_objectives_source", "")) if isinstance(lifted_encounter, dict) else ""
            if lifted_field_source and placement_field_source and lifted_field_source != placement_field_source:
                local_errors.append(f"{record_id} lifted field_objectives_source must agree with encounter_ref")

        placement_guard = scenario_placement.get("guard_link", {})
        object_guard = object_metadata.get("guard_link", {}) if isinstance(object_metadata, dict) else {}
        if isinstance(placement_guard, dict) and isinstance(object_guard, dict):
            for guard_key in ("guard_role", "target_kind", "target_id", "target_placement_id"):
                if str(placement_guard.get(guard_key, "")) != str(object_guard.get(guard_key, "")):
                    local_errors.append(f"{record_id} guard_link.{guard_key} must agree between object and scenario placement")
        if isinstance(lifted_metadata, dict):
            lifted_guard = lifted_metadata.get("guard_link", {})
            if isinstance(placement_guard, dict) and isinstance(lifted_guard, dict):
                for guard_key in ("guard_role", "target_kind", "target_id", "target_placement_id"):
                    if str(placement_guard.get(guard_key, "")) != str(lifted_guard.get(guard_key, "")):
                        local_errors.append(f"{record_id} lifted guard_link.{guard_key} must agree with scenario placement")
            lifted_representation = lifted_metadata.get("representation", {})
            object_representation = object_metadata.get("representation", {}) if isinstance(object_metadata, dict) else {}
            if isinstance(lifted_representation, dict) and isinstance(object_representation, dict):
                if str(lifted_representation.get("mode", "")) != str(object_representation.get("mode", "")):
                    local_errors.append(f"{record_id} lifted representation mode must agree with object metadata")
        authored_metadata = scenario_placement.get("authored_metadata", {})
        if isinstance(authored_metadata, dict) and str(authored_metadata.get("lifted_from_bundle_id", "")) and not isinstance(lifted_metadata, dict):
            local_errors.append(f"{record_id} declares lifted_from_bundle_id but has no lifted_scenario_metadata fixture")
        return local_errors

    valid = cases.get("valid", {})
    for obj in valid.get("neutral_encounters", []):
        errors.extend(strict_neutral_encounter_errors(obj, str(obj.get("id", "valid_neutral_encounter"))))
        if bool(obj.get("expect_placeholder_cue_warning", False)):
            warnings.append(f"{obj.get('id')}: danger cue id is a placeholder fixture id")
    for obj in valid.get("object_backed_neutral_encounters", []):
        errors.extend(strict_object_backed_neutral_encounter_errors(obj, str(obj.get("id", "valid_object_backed_neutral_encounter"))))

    invalid = cases.get("invalid", {})
    for obj in invalid.get("neutral_encounters", []):
        local_errors = strict_neutral_encounter_errors(obj, str(obj.get("id", "invalid_neutral_encounter")))
        if not local_errors:
            fail(errors, f"Strict invalid neutral encounter fixture {obj.get('id')} unexpectedly passed")
    for obj in invalid.get("object_backed_neutral_encounters", []):
        local_errors = strict_object_backed_neutral_encounter_errors(obj, str(obj.get("id", "invalid_object_backed_neutral_encounter")))
        if not local_errors:
            fail(errors, f"Strict invalid object-backed neutral encounter fixture {obj.get('id')} unexpectedly passed")
    return errors, warnings


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
            library_tier = int(entry.get("tier", 0))
            ensure(library_tier > 0, errors, f"Town {town_id} spell library entries must define tier > 0")
            for spell_id in entry.get("spell_ids", []):
                ensure(str(spell_id) in spells, errors, f"Town {town_id} references missing spell library spell {spell_id}")
                if str(spell_id) in spells:
                    ensure(
                        int(spells[str(spell_id)].get("tier", 0)) <= library_tier,
                        errors,
                        f"Town {town_id} tier {library_tier} spell library cannot offer higher-tier spell {spell_id}",
                    )
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

    spell_school_counts: dict[str, int] = {}
    spell_context_counts: dict[str, int] = {}
    spell_role_category_counts: dict[str, int] = {}
    for spell_id, spell in spells.items():
        school_id = str(spell.get("school_id", ""))
        ensure(school_id in SUPPORTED_SPELL_SCHOOLS, errors, f"Spell {spell_id} uses unsupported school_id {school_id}")
        spell_school_counts[school_id] = spell_school_counts.get(school_id, 0) + 1
        tier = int(spell.get("tier", 0))
        ensure(1 <= tier <= 5, errors, f"Spell {spell_id} tier must be between 1 and 5")
        ensure(bool(str(spell.get("accord_family", ""))), errors, f"Spell {spell_id} must define accord_family")
        primary_role = str(spell.get("primary_role", ""))
        ensure(primary_role in SUPPORTED_SPELL_PRIMARY_ROLES, errors, f"Spell {spell_id} uses unsupported primary_role {primary_role}")
        role_categories = spell.get("role_categories", [])
        ensure(isinstance(role_categories, list) and bool(role_categories), errors, f"Spell {spell_id} must define role_categories")
        normalized_role_categories = [str(category) for category in role_categories] if isinstance(role_categories, list) else []
        ensure(len(normalized_role_categories) == len(set(normalized_role_categories)), errors, f"Spell {spell_id} role_categories must not contain duplicates")
        for category in normalized_role_categories:
            ensure(category in SUPPORTED_SPELL_ROLE_CATEGORIES, errors, f"Spell {spell_id} uses unsupported role category {category}")
            spell_role_category_counts[category] = spell_role_category_counts.get(category, 0) + 1
        context = str(spell.get("context", ""))
        ensure(context in {"overworld", "battle"}, errors, f"Spell {spell_id} uses unsupported context {context}")
        spell_context_counts[context] = spell_context_counts.get(context, 0) + 1
        ensure(int(spell.get("mana_cost", 0)) > 0, errors, f"Spell {spell_id} must define mana_cost > 0")
        effect = spell.get("effect", {})
        ensure(isinstance(effect, dict), errors, f"Spell {spell_id} must define an effect payload")
        if not isinstance(effect, dict):
            continue
        effect_type = str(effect.get("type", ""))
        if effect_type == "restore_movement":
            ensure(context == "overworld", errors, f"Spell {spell_id} restore_movement effect must use overworld context")
            ensure(primary_role == "movement_support", errors, f"Spell {spell_id} restore_movement effect must use movement_support primary_role")
            ensure("economy_map_utility" in normalized_role_categories, errors, f"Spell {spell_id} restore_movement effect must include economy_map_utility role category")
            ensure(int(effect.get("amount", 0)) > 0, errors, f"Spell {spell_id} must define restore movement amount > 0")
        elif effect_type == "damage_enemy":
            ensure(context == "battle", errors, f"Spell {spell_id} damage_enemy effect must use battle context")
            ensure("damage" in normalized_role_categories, errors, f"Spell {spell_id} damage_enemy effect must include damage role category")
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
            ensure(context == "battle", errors, f"Spell {spell_id} buff effect must use battle context")
            ensure("buff" in normalized_role_categories or "recovery" in normalized_role_categories, errors, f"Spell {spell_id} buff effect must include buff or recovery role category")
            ensure(int(effect.get("amount", 0)) > 0, errors, f"Spell {spell_id} must define buff amount > 0")
            ensure(int(effect.get("duration_rounds", 0)) > 0, errors, f"Spell {spell_id} must define duration_rounds > 0")
            modifiers = effect.get("modifiers", {})
            if "modifiers" in effect:
                ensure(isinstance(modifiers, dict) and bool(modifiers), errors, f"Spell {spell_id} modifiers must be a non-empty dictionary when present")
        else:
            fail(errors, f"Spell {spell_id} uses unsupported effect type {effect_type}")

    ensure(REQUIRED_MAJOR_SPELL_SCHOOLS.issubset(set(spell_school_counts.keys())), errors, "Spell catalog must classify at least one spell in each major accord school")
    ensure(int(spell_context_counts.get("overworld", 0)) > 0, errors, "Spell catalog must keep at least one overworld spell for adventure-map magic")
    ensure(int(spell_context_counts.get("battle", 0)) > 0, errors, "Spell catalog must keep at least one battle spell")
    ensure("damage" in spell_role_category_counts and "buff" in spell_role_category_counts and "economy_map_utility" in spell_role_category_counts, errors, "Spell catalog must keep damage, buff, and economy/map role category coverage")

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

    validate_neutral_encounter_representation_bundle(errors, scenarios)
    validate_neutral_encounter_first_class_object_bundle(errors, scenarios, map_objects)
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


def validate_map_editor_shell_slice(errors: list[str]) -> None:
    required_paths = (
        APP_ROUTER_PATH,
        MAIN_MENU_SCENE_PATH,
        MAIN_MENU_SCRIPT_PATH,
        MAP_EDITOR_SCENE_PATH,
        MAP_EDITOR_SCRIPT_PATH,
        MAP_EDITOR_SMOKE_SCENE_PATH,
        OVERWORLD_MAP_VIEW_SCRIPT_PATH,
    )
    for path in required_paths:
        ensure(path.exists(), errors, f"Missing map-editor shell file: {path.relative_to(ROOT)}")
    if not all(path.exists() for path in required_paths):
        return

    app_router_text = APP_ROUTER_PATH.read_text(encoding="utf-8")
    for required_token in (
        "const MAP_EDITOR_SCENE",
        "func go_to_map_editor",
        'res://scenes/editor/MapEditorShell.tscn',
    ):
        ensure(required_token in app_router_text, errors, f"AppRouter.gd is missing required map-editor route token: {required_token}")

    main_menu_scene_text = MAIN_MENU_SCENE_PATH.read_text(encoding="utf-8")
    ensure(scene_has_node(main_menu_scene_text, "OpenEditor", "Button"), errors, "MainMenu.tscn must expose a clear dev editor entry button")
    ensure('method="_on_open_editor_pressed"' in main_menu_scene_text, errors, "MainMenu.tscn must wire the editor entry button")

    main_menu_script_text = MAIN_MENU_SCRIPT_PATH.read_text(encoding="utf-8")
    for required_token in (
        "_open_editor_button",
        "func _on_open_editor_pressed",
        "AppRouter.go_to_map_editor()",
    ):
        ensure(required_token in main_menu_script_text, errors, f"MainMenu.gd is missing required map-editor menu token: {required_token}")

    editor_scene_text = MAP_EDITOR_SCENE_PATH.read_text(encoding="utf-8")
    ensure_scene_nodes(
        editor_scene_text,
        errors,
        "MapEditorShell.tscn",
        [
            ("ScenarioPicker", "OptionButton"),
            ("TerrainPicker", "OptionButton"),
            ("InspectTool", "Button"),
            ("TerrainTool", "Button"),
            ("TerrainLineTool", "Button"),
            ("RoadTool", "Button"),
            ("RoadPathTool", "Button"),
            ("HeroStartTool", "Button"),
            ("PlaceObjectTool", "Button"),
            ("RemoveObjectTool", "Button"),
            ("TileInfo", "Label"),
            ("ObjectFamilyPicker", "OptionButton"),
            ("ObjectContentPicker", "OptionButton"),
            ("SelectedObjectPicker", "OptionButton"),
            ("PropertyOwnerPicker", "OptionButton"),
            ("PropertyDifficultyPicker", "OptionButton"),
            ("PropertyCollectedFlag", "CheckBox"),
            ("ApplyObjectProperties", "Button"),
            ("PlayWorkingCopy", "Button"),
            ("Map", "Control"),
        ],
    )
    ensure("res://scenes/overworld/OverworldMapView.gd" in editor_scene_text, errors, "MapEditorShell.tscn must reuse the live OverworldMapView renderer")

    editor_script_text = MAP_EDITOR_SCRIPT_PATH.read_text(encoding="utf-8")
    ensure_script_functions(
        editor_script_text,
        errors,
        "MapEditorShell.gd",
        [
            "_load_scenario_working_copy",
            "_paint_terrain",
            "_terrain_line_tool_click",
            "_apply_terrain_line",
            "_terrain_line_tiles",
            "_toggle_road",
            "_road_path_tool_click",
            "_apply_road_path",
            "_road_path_tiles",
            "_set_hero_start",
            "_place_object",
            "_remove_object",
            "_apply_selected_object_properties",
            "_set_town_owner_property",
            "_set_encounter_difficulty_property",
            "_set_collected_property",
            "_build_runtime_placement",
            "_generate_editor_placement_id",
            "_artifact_content_id_exists",
            "_tile_inspection_text",
            "_prepare_working_copy_for_play",
            "validation_snapshot",
            "validation_paint_terrain",
            "validation_seed_terrain_direct",
            "validation_set_terrain_line_start",
            "validation_apply_terrain_line",
            "validation_toggle_road",
            "validation_set_road_path_start",
            "validation_apply_road_path",
            "validation_set_hero_start",
            "validation_place_object",
            "validation_remove_object",
            "validation_edit_object_property",
            "validation_tile_presentation",
            "validation_editor_restamp_payload",
        ],
    )
    for required_token in (
        "ScenarioFactoryScript.create_session",
        "TerrainPlacementRulesScript.apply_paint",
        "OverworldRules.normalize_overworld_state",
        "_make_all_tiles_visible",
        "set_map_state",
        "TERRAIN_LINE_RULE_ID",
        "EDITOR_ROAD_LAYER_ID",
        "ROAD_PATH_RULE_ID",
        "editor_restamp",
        "homm3_owner_queue_rewrite_final_normalization.v1",
        "terrain_paint_order",
        "manhattan_l_horizontal_then_vertical",
        "OBJECT_FAMILY_TOWN",
        "OBJECT_FAMILY_RESOURCE",
        "OBJECT_FAMILY_ARTIFACT",
        "OBJECT_FAMILY_ENCOUNTER",
        "PROPERTY_TOWN_OWNER",
        "PROPERTY_ENCOUNTER_DIFFICULTY",
        "PROPERTY_COLLECTED",
        "object_details",
        "selected_property_object",
        "SessionState.set_active_session",
        "AppRouter.go_to_overworld()",
    ):
        ensure(required_token in editor_script_text, errors, f"MapEditorShell.gd is missing required map-editor token: {required_token}")


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

    validate_overworld_object_safe_metadata_bundle(errors, map_objects, resource_sites)

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
        "func describe_resource_site_interaction_surface",
        'map_object.get("primary_class"',
        'map_object.get("secondary_tags"',
        'map_object.get("interaction"',
        '"mine"',
        '"scouting_structure"',
        '"guarded_reward_site"',
        '"transit_object"',
        '"repeatable_service"',
    ):
        ensure(required_token in overworld_text, errors, f"OverworldRules.gd is missing overworld-content-foundation token: {required_token}")

    scenario_rules_text = SCENARIO_RULES_PATH.read_text(encoding="utf-8")
    ensure("ContentService.get_biome_for_terrain" in scenario_rules_text, errors, "ScenarioRules.gd must label scenario terrain through authored biomes")
    runtime_metadata_report_scene = ROOT / "tests" / "overworld_object_runtime_metadata_report.tscn"
    runtime_metadata_report_script = ROOT / "tests" / "overworld_object_runtime_metadata_report.gd"
    ensure(runtime_metadata_report_scene.exists(), errors, "Missing overworld object runtime metadata report scene")
    ensure(runtime_metadata_report_script.exists(), errors, "Missing overworld object runtime metadata report script")


def validate_overworld_object_ai_valuation_route_effects(errors: list[str]) -> None:
    required_paths = (
        ENEMY_ADVENTURE_RULES_PATH,
        ROOT / "tests" / "ai_overworld_object_valuation_route_effects_report.gd",
        ROOT / "tests" / "ai_overworld_object_valuation_route_effects_report.tscn",
        ROOT / "docs" / "overworld-object-ai-valuation-route-effects-report.md",
    )
    for path in required_paths:
        ensure(path.exists(), errors, f"Missing overworld object AI valuation route-effects file: {path.relative_to(ROOT)}")
    if not all(path.exists() for path in required_paths):
        return

    enemy_adventure_text = ENEMY_ADVENTURE_RULES_PATH.read_text(encoding="utf-8")
    for required_token in (
        "func neutral_encounter_object_route_pressure_report",
        "func neutral_encounter_object_valuation_breakdown",
        '"object_metadata_value"',
        '"priority_without_object_metadata"',
        '"priority_with_object_metadata"',
        '"route_effect_status"',
        '"shape_mask_contract"',
        '"body_tiles_separate_from_approach"',
        "target_public_reason",
        "commander_role_public_leak_check",
    ):
        ensure(required_token in enemy_adventure_text, errors, f"EnemyAdventureRules.gd is missing overworld object AI valuation token: {required_token}")

    report_text = (ROOT / "tests" / "ai_overworld_object_valuation_route_effects_report.gd").read_text(encoding="utf-8")
    for required_token in (
        "AI_OVERWORLD_OBJECT_VALUATION_ROUTE_EFFECTS_REPORT",
        "river_pass_reed_totemists",
        "river_pass_hollow_mire",
        "commander_role_public_leak_check",
        "body_tiles_separate_from_approach",
        "SCORE_LEAK_TOKENS",
    ):
        ensure(required_token in report_text, errors, f"AI overworld object valuation report is missing token: {required_token}")

    doc_text = (ROOT / "docs" / "overworld-object-ai-valuation-route-effects-report.md").read_text(encoding="utf-8")
    for required_text in (
        "Status: implementation evidence.",
        "No renderer import",
        "No save migration",
        "`wood` remains canonical",
        "Internal scores stay report/tooling-only",
    ):
        ensure(required_text in doc_text, errors, f"Overworld object AI valuation report doc is missing required boundary text: {required_text}")


def validate_overworld_object_route_effect_authoring(errors: list[str]) -> None:
    docs_path = ROOT / "docs" / "overworld-object-route-effect-authoring-validation-report.md"
    ensure(docs_path.exists(), errors, "Missing overworld object route-effect authoring validation report doc")
    map_objects = items_index(load_json(CONTENT_DIR / "map_objects.json"))
    resource_sites = items_index(load_json(CONTENT_DIR / "resource_sites.json"))
    transit_object_ids = sorted(
        object_id
        for object_id, obj in map_objects.items()
        if infer_overworld_object_primary_class(obj, resource_sites.get(str(obj.get("resource_site_id", "")))) == "transit_route_object"
    )
    ensure(bool(transit_object_ids), errors, "Route-effect authoring validation must have selected transit object metadata")
    for object_id in transit_object_ids:
        obj = map_objects[object_id]
        site_id = str(obj.get("resource_site_id", ""))
        entry = validate_overworld_object_route_effect_authoring_entry(object_id, obj, resource_sites.get(site_id) if site_id else None)
        for route_error in entry.get("errors", []):
            fail(errors, f"{object_id}: {route_error}")
    if docs_path.exists():
        doc_text = docs_path.read_text(encoding="utf-8")
        for required_text in (
            "Status: implementation evidence.",
            "metadata-only",
            "No route-effect runtime adoption",
            "`wood` remains canonical",
            "No public/internal score leaks",
        ):
            ensure(required_text in doc_text, errors, f"Route-effect authoring report doc is missing required boundary text: {required_text}")


def validate_overworld_object_content_batch_001(errors: list[str]) -> None:
    report = build_overworld_object_report()
    batch = report.get("content_batches", {}).get("batch_001_core_density_pickups", {})
    if not batch or int(batch.get("object_count", 0)) <= 0:
        return
    for batch_error in batch.get("errors", []):
        fail(errors, f"Overworld object Batch 001: {batch_error}")
    batch_001b = report.get("content_batches", {}).get("batch_001b_biome_scenic_decoration", {})
    if batch_001b and int(batch_001b.get("object_count", 0)) > 0:
        for batch_error in batch_001b.get("errors", []):
            fail(errors, f"Overworld object Batch 001b: {batch_error}")
        docs_path = ROOT / "docs" / "overworld-object-content-batch-001b-biome-scenic-decoration-report.md"
        ensure(docs_path.exists(), errors, "Missing overworld object Batch 001b implementation report doc")
        if docs_path.exists():
            doc_text = docs_path.read_text(encoding="utf-8")
            for required_text in (
                "Status: implementation evidence.",
                "No interactable objects.",
                "No rewards, resource grants",
                "No blocking or edge-blocker expansion",
                "`wood` remains canonical",
            ):
                ensure(required_text in doc_text, errors, f"Overworld object Batch 001b report doc is missing required boundary text: {required_text}")
    batch_001c = report.get("content_batches", {}).get("batch_001c_biome_blockers_edge", {})
    if batch_001c and int(batch_001c.get("object_count", 0)) > 0:
        for batch_error in batch_001c.get("errors", []):
            fail(errors, f"Overworld object Batch 001c: {batch_error}")
        docs_path = ROOT / "docs" / "overworld-object-content-batch-001c-biome-blockers-edge-report.md"
        ensure(docs_path.exists(), errors, "Missing overworld object Batch 001c implementation report doc")
        if docs_path.exists():
            doc_text = docs_path.read_text(encoding="utf-8")
            for required_text in (
                "Status: implementation evidence.",
                "No interactable objects.",
                "No rewards, resource grants",
                "No passable scenic expansion",
                "No route-effect runtime adoption",
                "`wood` remains canonical",
            ):
                ensure(required_text in doc_text, errors, f"Overworld object Batch 001c report doc is missing required boundary text: {required_text}")
    batch_001d = report.get("content_batches", {}).get("batch_001d_large_footprint_coverage", {})
    if batch_001d and int(batch_001d.get("object_count", 0)) > 0:
        for batch_error in batch_001d.get("errors", []):
            fail(errors, f"Overworld object Batch 001d: {batch_error}")
        docs_path = ROOT / "docs" / "overworld-object-content-batch-001d-large-footprint-coverage-report.md"
        ensure(docs_path.exists(), errors, "Missing overworld object Batch 001d implementation report doc")
        if docs_path.exists():
            doc_text = docs_path.read_text(encoding="utf-8")
            for required_text in (
                "Status: implementation evidence.",
                "No interactable objects.",
                "No rewards, resource grants",
                "No route-effect runtime adoption",
                "No pathing runtime adoption",
                "`wood` remains canonical",
            ):
                ensure(required_text in doc_text, errors, f"Overworld object Batch 001d report doc is missing required boundary text: {required_text}")
    batch_003 = report.get("content_batches", {}).get("batch_003_services_shrines_signs_events", {})
    if batch_003 and int(batch_003.get("object_count", 0)) > 0:
        for batch_error in batch_003.get("errors", []):
            fail(errors, f"Overworld object Batch 003: {batch_error}")
        docs_path = ROOT / "docs" / "overworld-object-content-batch-003-services-shrines-signs-events-report.md"
        ensure(docs_path.exists(), errors, "Missing overworld object Batch 003 implementation report doc")
        if docs_path.exists():
            doc_text = docs_path.read_text(encoding="utf-8")
            for required_text in (
                "Status: implementation evidence.",
                "28 Batch 003 map objects",
                "metadata-only",
                "No route-effect runtime adoption",
                "No renderer sprite import",
                "No save migration",
                "No rare-resource activation",
                "`wood` remains canonical",
            ):
                ensure(required_text in doc_text, errors, f"Overworld object Batch 003 report doc is missing required boundary text: {required_text}")
    batch_004 = report.get("content_batches", {}).get("batch_004_transit_coast_route_control", {})
    if batch_004 and int(batch_004.get("object_count", 0)) > 0:
        for batch_error in batch_004.get("errors", []):
            fail(errors, f"Overworld object Batch 004: {batch_error}")
        docs_path = ROOT / "docs" / "overworld-object-content-batch-004-transit-coast-route-control-report.md"
        ensure(docs_path.exists(), errors, "Missing overworld object Batch 004 implementation report doc")
        if docs_path.exists():
            doc_text = docs_path.read_text(encoding="utf-8")
            for required_text in (
                "Status: implementation evidence.",
                "24 Batch 004 map objects",
                "331 map objects",
                "127 resource sites",
                "metadata-only",
                "No route-effect runtime adoption",
                "No full ship movement system",
                "No renderer sprite import",
                "No save migration",
                "No rare-resource activation",
                "`wood` remains canonical",
            ):
                ensure(required_text in doc_text, errors, f"Overworld object Batch 004 report doc is missing required boundary text: {required_text}")
    batch_005 = report.get("content_batches", {}).get("batch_005_dwellings_guarded_dwellings", {})
    if batch_005 and int(batch_005.get("object_count", 0)) > 0:
        for batch_error in batch_005.get("errors", []):
            fail(errors, f"Overworld object Batch 005: {batch_error}")
        docs_path = ROOT / "docs" / "overworld-object-content-batch-005-dwellings-guarded-dwellings-report.md"
        ensure(docs_path.exists(), errors, "Missing overworld object Batch 005 implementation report doc")
        if docs_path.exists():
            doc_text = docs_path.read_text(encoding="utf-8")
            for required_text in (
                "Status: implementation evidence.",
                "33 Batch 005 map objects",
                "339 map objects",
                "135 resource sites",
                "metadata-only",
                "4 guarded high-value dwelling variants",
                "No broad dwelling runtime migration",
                "No recruitment UI overhaul",
                "No renderer sprite import",
                "No save migration",
                "No rare-resource activation",
                "`wood` remains canonical",
            ):
                ensure(required_text in doc_text, errors, f"Overworld object Batch 005 report doc is missing required boundary text: {required_text}")


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
        ensure(str(terrain_rendering.get("tile_art_root", "")) == "res://art/overworld/runtime/homm3_local_prototype", errors, "Overworld terrain rendering must point at the HoMM3 local prototype tile-art root")
        ensure(str(terrain_rendering.get("tile_art_status", "")) == "homm3_local_reference_prototype", errors, "Overworld terrain rendering must record the HoMM3 local-reference prototype status")
        ensure(str(terrain_rendering.get("tile_art_source_basis", "")) == "homm3_extracted_local_reference_prototype", errors, "Overworld terrain rendering must record the HoMM3 extracted local-reference source basis")
        ensure(str(terrain_rendering.get("terrain_transition_selection", "")) == "accepted_web_prototype_relation_class_row_lookup", errors, "Overworld terrain rendering must document HoMM3 accepted web-prototype relation-class terrain selection")
        ensure(str(terrain_rendering.get("terrain_transition_rule", "")) == "settled_owner_relation_classes_select_recovered_row_buckets", errors, "Overworld terrain rendering must document settled-owner relation-class row selection")
        ensure(str(terrain_rendering.get("editor_terrain_placement_model", "")) == "homm3_owner_queue_rewrite_final_normalization.v1", errors, "Overworld terrain rendering must document the HoMM3 editor terrain placement model")
        ensure(str(terrain_rendering.get("editor_restamp_model", "")) == "source_paint_known_receiver_offsets_shared_overworld_reprojection.v1", errors, "Overworld terrain rendering must document the editor restamp behavior model")
        ensure(str(terrain_rendering.get("editor_restamp_scope", "")) == "map_editor_terrain_paint_update_and_shared_preview", errors, "Overworld terrain rendering must keep editor restamp scope tied to terrain paint update and shared preview")
        ensure(str(terrain_rendering.get("interior_frame_selection", "")) == "accepted_web_full_row_bucket_selection", errors, "Overworld terrain rendering must document accepted web-prototype full-row interior selection")
        ensure(str(terrain_rendering.get("primary_base_model", "")) == "homm3_local_reference_prototype", errors, "Overworld terrain rendering must make the HoMM3 local prototype the primary base model")
        ensure(str(terrain_rendering.get("generated_source_policy", "")) == "deprecated_not_used_by_homm3_local_prototype", errors, "Overworld terrain rendering must document generated terrain sources as unused by the HoMM3 local prototype")
        ensure(bool(terrain_rendering.get("local_reference_only", False)), errors, "Overworld terrain rendering must mark HoMM3 extracted assets as local_reference_only")
        ensure(str(terrain_rendering.get("prototype_asset_policy", "")) == "not_shippable_or_redistributable", errors, "Overworld terrain rendering must mark HoMM3 extracted assets as not shippable or redistributable")
        authored_tile_sets = terrain_rendering.get("authored_tile_sets", [])
        ensure(isinstance(authored_tile_sets, list) and HOMM3_LOCAL_PROTOTYPE_FAMILIES.issubset(set(map(str, authored_tile_sets))) and "road_dirt" in set(map(str, authored_tile_sets)), errors, "Overworld terrain rendering must list the HoMM3 local prototype terrain families and road tile set")
        ensure(str(terrain_rendering.get("sampled_texture_status", "")) == "deprecated_not_primary", errors, "Overworld sampled terrain textures must be marked deprecated_not_primary")
    if not isinstance(object_assets, dict) or not isinstance(site_sprites, dict):
        return

    terrain_classes = terrain_grammar.get("terrain_classes", [])
    overlay_classes = terrain_grammar.get("overlay_classes", [])
    ensure(str(terrain_grammar.get("rendering_model", "")) == "authored_autotile_layers", errors, "Terrain grammar must declare authored_autotile_layers")
    ensure(str(terrain_grammar.get("authoring_status", "")) == "homm3_local_reference_prototype", errors, "Terrain grammar must record the HoMM3 local-reference prototype status")
    ensure(str(terrain_grammar.get("primary_base_model", "")) == "homm3_local_reference_prototype", errors, "Terrain grammar must make the HoMM3 local prototype primary")
    ensure(str(terrain_grammar.get("generated_source_policy", "")) == "deprecated_not_used_by_homm3_local_prototype", errors, "Terrain grammar must deprecate generated terrain sheets for this local prototype")
    transition_rules = terrain_grammar.get("transition_rules", {})
    ensure(isinstance(transition_rules, dict), errors, "Terrain grammar must define transition_rules")
    if isinstance(transition_rules, dict):
        ensure(str(transition_rules.get("selection_model", "")) == "accepted_web_prototype_relation_class_row_lookup", errors, "Terrain grammar must document HoMM3 accepted web-prototype relation-class terrain selection")
        ensure(str(transition_rules.get("edge_model", "")) == "bridge_or_shoreline_atlas_frame_lookup", errors, "Terrain grammar must document bridge/shoreline atlas-frame lookup")
        ensure(str(transition_rules.get("corner_model", "")) == "diagonal_context_in_atlas_lookup", errors, "Terrain grammar must document diagonal context in atlas lookup")
        ensure(str(transition_rules.get("receiver_rule", "")) == "settled_owner_relation_classes_select_recovered_row_buckets", errors, "Terrain grammar must document settled-owner relation-class row selection")
        ensure(str(transition_rules.get("editor_restamp_model", "")) == "source_paint_known_receiver_offsets_shared_overworld_reprojection.v1", errors, "Terrain grammar must document the editor restamp behavior model")
        ensure(str(transition_rules.get("editor_terrain_placement_model", "")) == "homm3_owner_queue_rewrite_final_normalization.v1", errors, "Terrain grammar must document the HoMM3 editor terrain placement model")
        ensure(str(transition_rules.get("same_group_policy", "")) == "suppress_same_homm3_family_edges", errors, "Terrain grammar must suppress same HoMM3-family transition seams")
        ensure(str(transition_rules.get("bridge_base_model", "")) == "direct_pair_overrides_dirt_or_sand_bridge_base", errors, "Terrain grammar must document direct-pair overrides before generic dirt/sand bridge-base resolution")
        ensure(str(transition_rules.get("propagation_model", "")) == "full_receiver_land_transitions_are_cardinal_boundary_only", errors, "Terrain grammar must document cardinal-boundary-only full receiver land transitions")
        ensure(str(transition_rules.get("single_sand_model", "")) == "grass_sand_diagonal_and_second_ring_sources_remain_solid_interiors", errors, "Terrain grammar must document that grass/sand diagonal and second-ring contacts stay solid interiors")
        ensure(str(transition_rules.get("diagonal_policy", "")) == "full_receiver_land_diagonal_only_sources_remain_solid_interiors", errors, "Terrain grammar must document that full-receiver diagonal-only sources stay solid interiors")
        ensure("neighbor_radius" not in transition_rules, errors, "Terrain grammar must not hard-cap HoMM3 terrain propagation with a fake neighbor_radius")
        ensure(str(transition_rules.get("water_model", "")) == "shoreline_specific_lookup", errors, "Terrain grammar must document shoreline-specific water lookup")
        ensure(str(transition_rules.get("unsupported_policy", "")) == "explicit_grammar_fallback", errors, "Terrain grammar must document explicit unsupported-case fallback")
    homm3_prototype = terrain_grammar.get("homm3_local_prototype", {})
    ensure(isinstance(homm3_prototype, dict), errors, "Terrain grammar must define homm3_local_prototype")
    if isinstance(homm3_prototype, dict):
        ensure(bool(homm3_prototype.get("enabled", False)), errors, "HoMM3 local prototype must be enabled")
        ensure(bool(homm3_prototype.get("local_reference_only", False)), errors, "HoMM3 local prototype must be marked local_reference_only")
        ensure(str(homm3_prototype.get("terrain_lookup_model", "")) == "accepted_web_prototype_relation_class_row_lookup", errors, "HoMM3 local prototype must use accepted web-prototype relation-class row lookup")
        ensure(str(homm3_prototype.get("road_lookup_model", "")) == "table_driven_4_neighbor_overlay", errors, "HoMM3 local prototype must use table-driven 4-neighbor road lookup")
        ensure(str(homm3_prototype.get("interior_frame_selection_model", "")) == "accepted_web_full_row_bucket_selection", errors, "HoMM3 local prototype must use accepted web-prototype full-row interior selection")
        ensure(str(homm3_prototype.get("unsupported_policy", "")) == "explicit_grammar_fallback", errors, "HoMM3 local prototype must use explicit fallback for unsupported cases")
        asset_root = res_path_to_disk(str(homm3_prototype.get("asset_root", "")))
        ensure(asset_root.exists(), errors, f"HoMM3 local prototype asset root is missing: {homm3_prototype.get('asset_root')}")
        terrain_families = homm3_prototype.get("terrain_families", {})
        terrain_id_map = homm3_prototype.get("terrain_id_map", {})
        bridge_material_resolver = homm3_prototype.get("bridge_material_resolver", {})
        land_receiver_stamp_lookup = homm3_prototype.get("land_receiver_stamp_lookup", {})
        direct_bridge_pairs = homm3_prototype.get("direct_bridge_pairs", [])
        routed_bridge_rules = homm3_prototype.get("routed_bridge_rules", [])
        road_overlays = homm3_prototype.get("road_overlays", {})
        ensure(isinstance(terrain_families, dict) and HOMM3_LOCAL_PROTOTYPE_FAMILIES.issubset(set(map(str, terrain_families.keys()))), errors, "HoMM3 local prototype must define the extracted terrain family tables")
        ensure(isinstance(terrain_id_map, dict) and TERRAIN_GRAMMAR_REQUIRED_TERRAIN_IDS.issubset(set(map(str, terrain_id_map.keys()))), errors, "HoMM3 local prototype must map the existing authored logical terrain ids")
        ensure(isinstance(bridge_material_resolver, dict), errors, "HoMM3 local prototype must define a bridge_material_resolver contract")
        ensure(isinstance(land_receiver_stamp_lookup, dict), errors, "HoMM3 local prototype must define a full receiver land stamp lookup contract")
        if isinstance(bridge_material_resolver, dict):
            ensure(str(bridge_material_resolver.get("resolver_model", "")) == "data_driven_bridge_material_resolver.v1", errors, "HoMM3 bridge material resolver must expose the data-driven resolver model")
            ensure(bridge_material_resolver.get("rule_order", []) == ["explicit_direct_bridge_pairs", "direct_bridge_material_contacts", "routed_bridge_rules", "unresolved_fallbacks", "preferred_bridge_class_routes"], errors, "HoMM3 bridge material resolver must preserve the source-driven rule order")
            direct_contact_rules = bridge_material_resolver.get("direct_bridge_material_contacts", [])
            preferred_rules = bridge_material_resolver.get("preferred_bridge_class_routes", [])
            unresolved_rules = bridge_material_resolver.get("unresolved_fallbacks", [])
            ensure(isinstance(direct_contact_rules, list), errors, "HoMM3 bridge material resolver must define direct material-contact rules")
            if isinstance(direct_contact_rules, list):
                direct_by_id = {str(rule.get("id", "")): rule for rule in direct_contact_rules if isinstance(rule, dict)}
                ensure({"full_receiver_direct_dirt_contact", "full_receiver_direct_sand_contact", "dirt_receiver_direct_sand_contact"}.issubset(direct_by_id.keys()), errors, "HoMM3 bridge material resolver must explicitly cover direct full-receiver dirt/sand contacts and dirt receiving sand")
                dirt_contact = direct_by_id.get("full_receiver_direct_dirt_contact", {})
                ensure(str(dirt_contact.get("bridge_source_kind", "")) == "direct_bridge_material" and str(dirt_contact.get("target_frame_block", "")) == "native_to_dirt_transition", errors, "Direct dirt bridge material contact must target the receiver native-to-dirt block")
                sand_contact = direct_by_id.get("full_receiver_direct_sand_contact", {})
                ensure(str(sand_contact.get("bridge_source_kind", "")) == "direct_bridge_material" and str(sand_contact.get("target_frame_block", "")) == "native_to_sand_transition", errors, "Direct sand bridge material contact must target the receiver native-to-sand block")
                dirt_sand_contact = direct_by_id.get("dirt_receiver_direct_sand_contact", {})
                ensure(str(dirt_sand_contact.get("bridge_family", "")) == "sand" and str(dirt_sand_contact.get("target_frame_block", "")) == "dirt_to_sand_transition", errors, "Direct dirt/sand contact must keep dirt receivers on dirttl dirt-to-sand frames")
            ensure(isinstance(preferred_rules, list), errors, "HoMM3 bridge material resolver must define preferred bridge-class routes")
            if isinstance(preferred_rules, list):
                preferred_by_id = {str(rule.get("id", "")): rule for rule in preferred_rules if isinstance(rule, dict)}
                ensure({"water_prefers_sand_bridge_class", "rock_prefers_sand_bridge_class", "full_receiver_prefers_dirt_bridge_class"}.issubset(preferred_by_id.keys()), errors, "HoMM3 bridge material resolver must define water/rock sand preference and full-receiver dirt preference")
                ensure(str(preferred_by_id.get("water_prefers_sand_bridge_class", {}).get("bridge_family", "")) == "sand", errors, "Water preferred bridge-class route must resolve to sand before shoreline lookup")
                ensure(str(preferred_by_id.get("rock_prefers_sand_bridge_class", {}).get("bridge_family", "")) == "sand", errors, "Rock preferred bridge-class route must resolve to sand before rock-system lookup")
                ensure(str(preferred_by_id.get("full_receiver_prefers_dirt_bridge_class", {}).get("bridge_family", "")) == "dirt", errors, "Full receiver preferred bridge-class route must resolve to dirt/earth")
            ensure(isinstance(unresolved_rules, list), errors, "HoMM3 bridge material resolver must define unresolved fallback routes")
            if isinstance(unresolved_rules, list):
                unresolved_by_id = {str(rule.get("id", "")): rule for rule in unresolved_rules if isinstance(rule, dict)}
                subterranean_rule = unresolved_by_id.get("subterranean_preferred_bridge_class_provisional", {})
                ensure(str(subterranean_rule.get("bridge_source_kind", "")) == "unresolved_fallback" and str(subterranean_rule.get("source_level", "")) == "provisional" and bool(subterranean_rule.get("provisional", False)), errors, "Subterranean bridge policy must remain an explicit provisional unresolved fallback")
        ensure(isinstance(direct_bridge_pairs, list), errors, "HoMM3 local prototype must define direct bridge-pair overrides")
        if isinstance(direct_bridge_pairs, list):
            found_dirt_swamp_pair = False
            for pair in direct_bridge_pairs:
                if not isinstance(pair, dict):
                    continue
                families = pair.get("families", [])
                if isinstance(families, list) and set(map(str, families)) == {"dirt", "swamp"} and str(pair.get("bridge_family", "")) == "dirt" and str(pair.get("selection_model", "")) == "direct_family_pair_lookup":
                    found_dirt_swamp_pair = True
                    break
            ensure(found_dirt_swamp_pair, errors, "HoMM3 local prototype must keep dirt<->swamp on a direct dirt bridge-pair lookup instead of sand")
            found_grass_sand_pair = False
            for pair in direct_bridge_pairs:
                if not isinstance(pair, dict):
                    continue
                families = pair.get("families", [])
                if isinstance(families, list) and set(map(str, families)) == {"grass", "sand"} and str(pair.get("bridge_family", "")) == "sand" and str(pair.get("selection_model", "")) == "direct_grass_sand_native_to_sand_lookup":
                    found_grass_sand_pair = True
                    break
            ensure(found_grass_sand_pair, errors, "HoMM3 local prototype must route grass<->sand through the grastl native-to-sand transition lookup")
        ensure(isinstance(routed_bridge_rules, list), errors, "HoMM3 local prototype must define routed bridge rules")
        if isinstance(routed_bridge_rules, list):
            found_grass_swamp_route = False
            for rule in routed_bridge_rules:
                if not isinstance(rule, dict):
                    continue
                families = rule.get("families", [])
                if isinstance(families, list) and set(map(str, families)) == {"grass", "swamp"} and str(rule.get("bridge_family", "")) == "dirt" and str(rule.get("bridge_source_kind", "")) == "routed_bridge" and str(rule.get("target_frame_block", "")) == "native_to_dirt_transition":
                    found_grass_swamp_route = True
                    break
            ensure(found_grass_swamp_route, errors, "HoMM3 local prototype must route grass/swamp through dirt bridge behavior, not a direct all-to-all blend")
        if isinstance(land_receiver_stamp_lookup, dict):
            ensure(str(land_receiver_stamp_lookup.get("resolver_model", "")) == "data_driven_full_receiver_land_stamp_lookup.v1", errors, "HoMM3 full receiver stamp lookup must expose the data-driven resolver model")
            ensure(str(land_receiver_stamp_lookup.get("applies_to_atlas_role", "")) == "full_receiver_land", errors, "HoMM3 full receiver stamp lookup must apply only to full receiver land atlases")
            ensure(str(land_receiver_stamp_lookup.get("mapping_source_level", "")) == "provisional", errors, "HoMM3 full receiver stamp offset/frame mapping must remain explicitly provisional")
            ensure(str(land_receiver_stamp_lookup.get("mixed_junction_policy", "")) == "reserved_unresolved_do_not_select_for_full_receiver_stamp_lookup", errors, "HoMM3 full receiver stamp lookup must keep mixed junction blocks reserved")
            reserved_ranges = set(map(str, land_receiver_stamp_lookup.get("reserved_mixed_junction_frame_ranges", [])))
            ensure({"00_40-00_48", "00_77-00_78"}.issubset(reserved_ranges), errors, "HoMM3 full receiver stamp lookup must reserve the source-visible mixed junction frame ranges")
            restamp_behavior = land_receiver_stamp_lookup.get("editor_restamp_behavior", {})
            ensure(isinstance(restamp_behavior, dict), errors, "HoMM3 full receiver stamp lookup must define editor_restamp_behavior metadata")
            if isinstance(restamp_behavior, dict):
                ensure(str(restamp_behavior.get("model", "")) == "source_paint_known_receiver_offsets_shared_overworld_reprojection.v1", errors, "HoMM3 editor restamp behavior model id must be stable")
                ensure(str(restamp_behavior.get("logical_map_write_model", "")) == "homm3_owner_queue_rewrite_final_normalization.v1", errors, "HoMM3 editor restamp must identify the owner queue/rewrite logical map write model")
                ensure(str(restamp_behavior.get("renderer_evaluation_model", "")) == "shared_overworld_map_view_final_state_reprojection", errors, "HoMM3 editor restamp must route through shared OverworldMapView presentation evaluation")
                ensure(str(restamp_behavior.get("scope", "")) == "map_editor_terrain_paint_update_and_shared_preview", errors, "HoMM3 editor restamp metadata must be tied to the terrain paint update and shared preview")
                offsets = restamp_behavior.get("known_receiver_offsets_from_single_paint", [])
                ensure(isinstance(offsets, list) and [str(item.get("direction", "")) for item in offsets if isinstance(item, dict)] == ["N", "NW", "W"], errors, "HoMM3 editor restamp behavior must preserve the source-observed N/NW/W receiver offsets")
            stamp_tables = land_receiver_stamp_lookup.get("stamp_tables", {})
            ensure(isinstance(stamp_tables, dict), errors, "HoMM3 full receiver stamp lookup must define stamp_tables")
            if isinstance(stamp_tables, dict):
                expected_stamp_ranges = {
                    "dirt": ("full_receiver_native_to_dirt_5x4_provisional_stamp_table", "native_to_dirt_transition", [f"00_{index:02d}" for index in range(0, 20)]),
                    "sand": ("full_receiver_native_to_sand_5x4_provisional_stamp_table", "native_to_sand_transition", [f"00_{index:02d}" for index in range(20, 40)]),
                }
                for bridge_family, expected in expected_stamp_ranges.items():
                    table = stamp_tables.get(bridge_family, {})
                    ensure(isinstance(table, dict), errors, f"HoMM3 full receiver stamp lookup must define the {bridge_family} stamp table")
                    if not isinstance(table, dict):
                        continue
                    expected_id, expected_block, expected_frames = expected
                    ensure(str(table.get("id", "")) == expected_id, errors, f"HoMM3 {bridge_family} stamp table id must be stable and explicit")
                    ensure(str(table.get("target_frame_block", "")) == expected_block, errors, f"HoMM3 {bridge_family} stamp table must target the expected full receiver frame block")
                    ensure(str(table.get("frame_range_source_level", "")) == "fact", errors, f"HoMM3 {bridge_family} stamp table frame range must be fact-level")
                    ensure(str(table.get("source_level", "")) == "provisional", errors, f"HoMM3 {bridge_family} stamp table mapping must remain provisional")
                    cardinal_entries = table.get("cardinal_entries", {})
                    ensure(isinstance(cardinal_entries, dict) and {"N", "E", "S", "W"}.issubset(set(map(str, cardinal_entries.keys()))), errors, f"HoMM3 {bridge_family} stamp table must define source-direction cardinal entries")
                    frame_grid = table.get("frame_grid", [])
                    ensure(isinstance(frame_grid, list) and len(frame_grid) == 5 and all(isinstance(row, list) and len(row) == 4 for row in frame_grid), errors, f"HoMM3 {bridge_family} stamp table must expose a provisional 5x4 source-visible frame grid")
                    if isinstance(frame_grid, list):
                        flattened = [str(frame) for row in frame_grid if isinstance(row, list) for frame in row]
                        ensure(flattened == expected_frames, errors, f"HoMM3 {bridge_family} stamp table must map exactly to its source-visible 20-frame range")
                        forbidden_mixed = {f"00_{index:02d}" for index in range(40, 49)} | {"00_77", "00_78"}
                        ensure(not bool(forbidden_mixed.intersection(flattened)), errors, f"HoMM3 {bridge_family} stamp table must not select reserved mixed junction frames")
                        for family_id in HOMM3_FULL_RECEIVER_LAND_FAMILIES:
                            atlas = str(terrain_families.get(family_id, {}).get("atlas", ""))
                            for frame_id in flattened[:1] + flattened[-1:]:
                                frame_path = asset_root / "terrain" / atlas / f"{frame_id}.png"
                                ensure(frame_path.exists(), errors, f"HoMM3 full receiver stamp table {bridge_family} references missing {family_id} frame {frame_path}")
        if isinstance(terrain_id_map, dict):
            forest_mapping = terrain_id_map.get("forest", {})
            ensure(isinstance(forest_mapping, dict) and str(forest_mapping.get("logical_degrade_note", "")) != "", errors, "HoMM3 local prototype must explicitly document the logical forest terrain atlas limitation")
        if isinstance(terrain_families, dict):
            for family_id in HOMM3_LOCAL_PROTOTYPE_FAMILIES:
                family = terrain_families.get(family_id, {})
                ensure(isinstance(family, dict), errors, f"HoMM3 local prototype family {family_id} must be a dictionary")
                if not isinstance(family, dict):
                    continue
                atlas = str(family.get("atlas", ""))
                ensure(atlas != "", errors, f"HoMM3 local prototype family {family_id} must define atlas")
                interior_frames = family.get("interior_frames", [])
                ensure(isinstance(interior_frames, list) and bool(interior_frames), errors, f"HoMM3 local prototype family {family_id} must define interior frames")
                renderer_family = str(family.get("renderer_family", ""))
                atlas_role = str(family.get("atlas_role", ""))
                uses_generic_land_edges = bool(family.get("uses_generic_land_edge_masks", False))
                ensure(renderer_family == family_id, errors, f"HoMM3 local prototype family {family_id} must report its renderer_family separately")
                ensure(atlas_role != "", errors, f"HoMM3 local prototype family {family_id} must define an atlas_role")
                ensure(isinstance(family.get("frame_blocks", {}), dict) and bool(family.get("frame_blocks", {})), errors, f"HoMM3 local prototype family {family_id} must define source-level frame_blocks")
                if atlas in {"sandtl", "watrtl", "rocktl"}:
                    ensure(not uses_generic_land_edges, errors, f"HoMM3 {atlas} must not be marked as a generic land edge-mask source")
                    ensure("bridge_mask_lookup" not in family, errors, f"HoMM3 {atlas} must not define bridge_mask_lookup as a normal land edge-mask source")
                if family_id == "water":
                    ensure(atlas_role == "shoreline_system" and str(family.get("special_system", "")) == "water_shoreline", errors, "HoMM3 water must be a special shoreline system")
                    ensure(str(family.get("preferred_bridge_class", "")) == "sand_bridge", errors, "HoMM3 water must keep sand_bridge as preferred bridge-class metadata")
                    lookup_key = "shoreline_lookup"
                elif family_id == "rock":
                    ensure(atlas_role == "special_rock_void" and str(family.get("special_system", "")) == "rock_void_cliff", errors, "HoMM3 rock must be a special rock/void system")
                    ensure(str(family.get("preferred_bridge_class", "")) == "sand_bridge", errors, "HoMM3 rock must keep sand_bridge as preferred bridge-class metadata")
                    lookup_key = "rock_system_lookup"
                elif family_id == "sand":
                    ensure(atlas_role == "base_decor_bridge_material", errors, "HoMM3 sand must be base/decor bridge material, not a receiver edge-mask atlas")
                    lookup_key = "base_context_lookup"
                elif family_id in HOMM3_FULL_RECEIVER_LAND_FAMILIES:
                    ensure(atlas_role == "full_receiver_land", errors, f"HoMM3 full receiver family {family_id} must keep the full_receiver_land atlas role")
                    ensure(not uses_generic_land_edges, errors, f"HoMM3 full receiver family {family_id} must not use receiver-centered bridge_mask_lookup shortcuts")
                    ensure(bool(family.get("uses_land_receiver_stamp_tables", False)), errors, f"HoMM3 full receiver family {family_id} must opt into the shared land receiver stamp tables")
                    ensure("bridge_mask_lookup" not in family, errors, f"HoMM3 full receiver family {family_id} must not define receiver-centered bridge_mask_lookup")
                    ensure("bridge_family_mask_lookups" not in family, errors, f"HoMM3 full receiver family {family_id} must not define bridge-family mask override shortcuts")
                    ensure("propagated_transition_stamps" not in family, errors, f"HoMM3 full receiver family {family_id} must use the shared stamp lookup rather than per-family propagated stamp shortcuts")
                    lookup_key = ""
                else:
                    ensure(family_id == "dirt" and atlas_role == "reduced_bridge_receiver", errors, f"HoMM3 non-special receiver family {family_id} must be the reduced dirt bridge receiver")
                    ensure(uses_generic_land_edges, errors, f"HoMM3 reduced receiver family {family_id} must explicitly keep its dirt/sand bridge mask lookup")
                    lookup_key = "bridge_mask_lookup"
                lookup = family.get(lookup_key, {}) if lookup_key else {}
                if lookup_key:
                    ensure(isinstance(lookup, dict) and "N" in lookup and "N+E+S+W" in lookup, errors, f"HoMM3 local prototype family {family_id} must define {lookup_key} masks")
                if lookup_key == "bridge_mask_lookup" and isinstance(lookup, dict):
                    ensure(str(lookup.get("E", "")) == "00_15", errors, f"HoMM3 local prototype family {family_id} east bridge mask must use the right-side source frame")
                    ensure(str(lookup.get("W", "")) == "00_04", errors, f"HoMM3 local prototype family {family_id} west bridge mask must use the left-side source frame")
                if family_id == "sand":
                    ensure("receiver_transition_policy" not in family, errors, "HoMM3 sand family must not carry the discarded self-contained one-ring receiver policy")
                    ensure(str(family.get("provisional_fallback_policy", "")) != "", errors, "HoMM3 sand base-context lookup must expose provisional fallback metadata")
                if family_id == "subterranean":
                    ensure(str(family.get("preferred_bridge_class", "")) == "unresolved", errors, "HoMM3 subbtl preferred bridge class must remain unresolved")
                    ensure(str(family.get("preferred_bridge_source_level", "")) == "provisional", errors, "HoMM3 subbtl bridge-family fallback must remain explicitly provisional")
                sample_frames = []
                if isinstance(interior_frames, list):
                    sample_frames.extend(map(str, interior_frames[:2]))
                if isinstance(lookup, dict):
                    sample_frames.extend(str(value) for value in list(lookup.values())[:4])
                for frame_id in sample_frames:
                    frame_path = asset_root / "terrain" / atlas / f"{frame_id}.png"
                    ensure(frame_path.exists(), errors, f"HoMM3 local prototype family {family_id} references missing frame {frame_path}")
                    if frame_path.exists():
                        ensure(png_size(frame_path) == (64, 64), errors, f"HoMM3 local prototype frame {frame_path} must be 64x64 PNG")
        ensure(isinstance(road_overlays, dict) and "road_dirt" in road_overlays, errors, "HoMM3 local prototype must define road_dirt road overlay lookup")
        if isinstance(road_overlays, dict):
            road_dirt = road_overlays.get("road_dirt", {})
            mask_lookup = road_dirt.get("mask_lookup", {}) if isinstance(road_dirt, dict) else {}
            ensure(isinstance(road_dirt, dict) and str(road_dirt.get("atlas", "")) == "dirtrd", errors, "HoMM3 road_dirt prototype must use the dirtrd atlas")
            ensure(isinstance(mask_lookup, dict) and {"", "N", "E+W", "N+E+S+W"}.issubset(set(map(str, mask_lookup.keys()))), errors, "HoMM3 road_dirt prototype must define 4-neighbor road masks")
            if isinstance(mask_lookup, dict) and asset_root.exists():
                for frame_id in {str(mask_lookup.get(key, "")) for key in ["", "N", "E+W", "N+E+S+W"]}:
                    frame_path = asset_root / "roads" / "dirtrd" / f"{frame_id}.png"
                    ensure(frame_path.exists(), errors, f"HoMM3 road_dirt prototype references missing frame {frame_path}")
                    if frame_path.exists():
                        ensure(png_size(frame_path) == (64, 64), errors, f"HoMM3 road_dirt frame {frame_path} must be 64x64 PNG")
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
                    ensure(str(tile_art.get("source_basis", "")).startswith("homm3_local_reference_prototype"), errors, f"Terrain grammar {terrain_id} must identify that fallback tile_art paths are superseded by the HoMM3 local prototype")
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
    editor_options = terrain_grammar.get("editor_base_terrain_options", [])
    ensure(isinstance(editor_options, list), errors, "Terrain grammar must define editor_base_terrain_options for the map editor base terrain picker")
    if isinstance(editor_options, list):
        actual_options = [
            (
                str(option.get("id", "")),
                str(option.get("label", "")),
                str(option.get("homm3_family", "")),
                str(option.get("homm3_atlas", "")),
            )
            for option in editor_options
            if isinstance(option, dict)
        ]
        ensure(actual_options == EDITOR_BASE_TERRAIN_OPTIONS, errors, "Editor base terrain options must be the HoMM3-style family set in order: Water, Snow, Grass, Sand, Dirt, Lava, Swamp, Rock/None")
        option_ids = {option[0] for option in actual_options}
        ensure(option_ids == EDITOR_BASE_TERRAIN_OPTION_IDS, errors, "Editor base terrain option ids must be the curated HoMM3-style representatives")
        ensure(option_ids.issubset(terrain_class_ids), errors, "Editor base terrain options must reference existing authored terrain ids")
        ensure(EDITOR_HIDDEN_LOGICAL_TERRAIN_IDS.isdisjoint(option_ids), errors, "Editor base terrain options must not expose hidden logical terrain variants such as forest, mire, hills, ridge, ash, frost, coast, or shore")
        terrain_id_map = homm3_prototype.get("terrain_id_map", {}) if isinstance(homm3_prototype, dict) else {}
        terrain_families = homm3_prototype.get("terrain_families", {}) if isinstance(homm3_prototype, dict) else {}
        if isinstance(terrain_id_map, dict) and isinstance(terrain_families, dict):
            for terrain_id, _label, expected_family, expected_atlas in EDITOR_BASE_TERRAIN_OPTIONS:
                mapping = terrain_id_map.get(terrain_id, {})
                ensure(isinstance(mapping, dict) and str(mapping.get("family", "")) == expected_family, errors, f"Editor base terrain option {terrain_id} must map to HoMM3 family {expected_family}")
                family = terrain_families.get(expected_family, {})
                ensure(isinstance(family, dict) and str(family.get("atlas", "")) == expected_atlas, errors, f"Editor base terrain option {terrain_id} must resolve to HoMM3 atlas {expected_atlas}")
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
                ensure(isinstance(supports, list) and "same_type_adjacency" in supports, errors, "Terrain overlay road_dirt must mark same_type_adjacency support")
                ensure(isinstance(supports, list) and "orthogonal_4_neighbor_masks" in supports, errors, "Terrain overlay road_dirt must mark orthogonal_4_neighbor_masks support")
                ensure(isinstance(supports, list) and "transparent_overlay_frames" in supports, errors, "Terrain overlay road_dirt must mark transparent_overlay_frames support")
                ensure(isinstance(supports, list) and "no_diagonal_connectors" in supports, errors, "Terrain overlay road_dirt must mark no_diagonal_connectors support")
                ensure(str(overlay.get("piece_selection_model", "")) == "homm3_4_neighbor_mask_lookup", errors, "Terrain overlay road_dirt must document HoMM3 4-neighbor mask lookup")
                ensure(str(overlay.get("vertical_lane", "")) == "orthogonal_mask_frame", errors, "Terrain overlay road_dirt must document orthogonal vertical road mask frames")
                ensure(str(overlay.get("horizontal_lane", "")) == "orthogonal_mask_frame", errors, "Terrain overlay road_dirt must document orthogonal horizontal road mask frames")
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
                    connection_pieces = tile_art.get("connection_pieces", {})
                    ensure(isinstance(connection_pieces, dict), errors, "Terrain overlay road_dirt must define diagonal connection-piece art")
                    if isinstance(connection_pieces, dict):
                        for connection_key in ("NE+SW", "NW+SE"):
                            piece_path = res_path_to_disk(str(connection_pieces.get(connection_key, "")))
                            ensure(piece_path.exists(), errors, f"Terrain overlay road_dirt connection piece {connection_key} references missing texture {connection_pieces.get(connection_key)}")
                            if piece_path.exists():
                                ensure(png_size(piece_path) == (64, 64), errors, f"Terrain overlay road_dirt connection piece {connection_key} must be a 64x64 PNG")
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
        ensure(str(object_rendering.get("mapped_sprite_settlement", "")) == "mapped_sprite_contact_grounding_no_support_stack", errors, "Overworld object rendering must document mapped sprite no-support-stack grounding")
        ensure(str(object_rendering.get("mapped_sprite_grounding", "")) == "localized_sprite_contact_scuffs", errors, "Overworld object rendering must document mapped sprite localized contact scuffs")
        ensure(str(object_rendering.get("mapped_sprite_contact_shadow", "")) == "localized_sprite_contact_shadow", errors, "Overworld object rendering must document mapped sprite localized contact shadows")
        ensure(str(object_rendering.get("mapped_sprite_contact_disturbance", "")) == "thin_sprite_contact_disturbance", errors, "Overworld object rendering must document mapped sprite thin contact disturbance")
        ensure(str(object_rendering.get("mapped_sprite_placement_bed", "")) == "removed_for_resource_artifact_encounter_mapped_sprites", errors, "Overworld object rendering must document removal of mapped sprite placement beds")
        ensure(str(object_rendering.get("mapped_sprite_upper_mass_backdrop", "")) == "removed_for_resource_artifact_encounter_mapped_sprites", errors, "Overworld object rendering must document removal of mapped sprite upper-mass backdrops")
        ensure(str(object_rendering.get("mapped_sprite_vertical_mass_shadow", "")) == "removed_for_resource_artifact_encounter_mapped_sprites", errors, "Overworld object rendering must document removal of mapped sprite vertical mass shadows")
        ensure(str(object_rendering.get("mapped_sprite_foreground_lip", "")) == "removed_for_resource_artifact_encounter_mapped_sprites", errors, "Overworld object rendering must document removal of mapped sprite foreground lips")
        ensure(str(object_rendering.get("fallback_silhouette", "")) == "family_specific_procedural_world_object", errors, "Overworld object rendering must document family-specific procedural fallback silhouettes")
        ensure(str(object_rendering.get("town_footprint", "")) == "town_3x2_footprint_bottom_middle_entry", errors, "Overworld object rendering must document the 3x2 town footprint and bottom-middle entry model")
        ensure(str(object_rendering.get("town_entry_role", "")) == "bottom_middle_visit_approach", errors, "Overworld object rendering must document the town bottom-middle visit approach role")
        ensure(str(object_rendering.get("town_non_entry_tiles", "")) == "blocked_non_entry_footprint", errors, "Overworld object rendering must document non-entry town footprint cells as blocked")
        ensure(str(object_rendering.get("town_grounding", "")) == "town_sprite_settled_without_base_ellipse", errors, "Overworld object rendering must document the town-specific no-ellipse grounding model")
        ensure(str(object_rendering.get("town_footprint_cues", "")) == "no_visible_helper_cues_3x2_contract", errors, "Overworld object rendering must document that town footprint/helper cues are not visible")
        ensure(str(object_rendering.get("town_entry_apron", "")) == "removed", errors, "Overworld object rendering must document that town entry aprons are removed")
        ensure(str(object_rendering.get("town_gate_helper", "")) == "removed", errors, "Overworld object rendering must document that town gate helper cues are removed")
        ensure(str(object_rendering.get("town_helper_glyphs", "")) == "removed", errors, "Overworld object rendering must document that town helper glyphs are removed")
        ensure(str(object_rendering.get("town_shadow_policy", "")) == "no_town_cast_shadow_or_vertical_mass_shadow", errors, "Overworld object rendering must document that town cast shadows and vertical mass shadows are removed")
        ensure(str(object_rendering.get("town_base_ellipse", "")) == "removed", errors, "Overworld object rendering must document that town base ellipses are removed")

    map_view_text = OVERWORLD_MAP_VIEW_SCRIPT_PATH.read_text(encoding="utf-8")
    for required_token in (
        "OVERWORLD_ART_MANIFEST_PATH",
        "TERRAIN_GRAMMAR_PATH",
	        "TERRAIN_GRAMMAR_RENDERING_MODE",
	        "TERRAIN_HOMM3_LOCAL_PROTOTYPE_RENDERING_MODE",
	        "TERRAIN_TILE_ART_RENDERING_MODE",
	        "TERRAIN_HOMM3_SOURCE_BASIS",
	        "TERRAIN_HOMM3_UNSUPPORTED_POLICY",
	        "TERRAIN_TRANSITION_SELECTION_MODEL",
	        "TERRAIN_TRANSITION_EDGE_MODEL",
	        "TERRAIN_TRANSITION_CORNER_MODEL",
	        "func _load_terrain_grammar",
	        "func _load_homm3_prototype",
	        "func _homm3_bridge_material_resolution",
	        "func _homm3_bridge_material_rule_for",
	        "func _homm3_editor_restamp_payload",
	        "func validation_editor_restamp_payload",
	        "func _homm3_selection_kind_from_visual_selection",
	        "func _homm3_terrain_selection_payload",
	        "func _homm3_terrain_relation_payload",
	        "func _homm3_road_art_path",
	        "func _draw_terrain_tile_art",
        "func _load_overworld_art_manifest",
        "func _draw_authored_terrain_pattern",
        "func _draw_terrain_transitions",
        "func _terrain_transition_payload",
        "func _draw_road_overlay",
        "func _draw_road_overlay_art",
        "func _draw_object_sprite",
        "func _draw_town_sprite",
        "func _draw_town_entry_approach",
        "func _draw_town_footprint_underlay",
        "func _draw_town_grounding_anchor",
        "func _draw_town_front_contact",
        "func validation_town_presentation_profiles",
        "func _draw_encounter_sprite",
        "func _resource_asset_id",
        "town_default_sprite",
        "encounter_default_sprite",
        "OBJECT_PRESENCE_MODEL",
        "OBJECT_SPRITE_SETTLEMENT_MODEL",
        "OBJECT_MAPPED_SPRITE_GROUNDING_MODEL",
        "OBJECT_MAPPED_SPRITE_ANCHOR_STYLE",
        "OBJECT_MAPPED_SPRITE_OCCLUSION_MODEL",
        "OBJECT_MAPPED_SPRITE_DEPTH_CUE_MODEL",
        "OBJECT_MAPPED_SPRITE_CONTACT_MODEL",
        "OBJECT_MAPPED_SPRITE_DISTURBANCE_MODEL",
        "OBJECT_PROCEDURAL_FALLBACK_MODEL",
        "func _load_map_object_profiles",
        "func _draw_mapped_sprite_grounding_anchor",
        "func _draw_mapped_sprite_contact_disturbance",
        "func _draw_mapped_sprite_contact_shadow",
        "func _mapped_sprite_grounding_fraction_metrics",
        '"footprint_scaled_world_object"',
        '"mapped_sprite_contact_grounding_no_support_stack"',
        '"localized_sprite_contact_scuffs"',
        '"sprite_contact_without_foreground_lip"',
        '"localized_sprite_contact_shadow_without_backdrop"',
        '"localized_sprite_contact_shadow"',
        '"thin_sprite_contact_disturbance"',
	        '"family_specific_procedural_world_object"',
	        '"authored_autotile_layers"',
	        '"homm3_local_reference_prototype"',
	        '"homm3_extracted_local_reference_prototype"',
	        '"uses_sampled_texture"',
	        '"uses_authored_tile_art"',
	        '"uses_homm3_local_prototype"',
	        '"generated_source_primary"',
	        '"primary_base_model"',
	        '"edge_transition_art_loaded"',
	        '"neighbor_aware_transitions"',
	        '"transition_calculation_model"',
	        '"transition_cardinal_sources"',
	        '"transition_corner_sources"',
	        '"accepted_web_prototype_relation_class_row_lookup"',
	        '"bridge_or_shoreline_atlas_frame_lookup"',
	        '"diagonal_context_in_atlas_lookup"',
	        '"homm3_terrain_lookup_model"',
	        '"homm3_bridge_family"',
	        '"homm3_bridge_class"',
	        '"homm3_bridge_resolution_model"',
	        '"homm3_bridge_resolver_model"',
	        '"homm3_bridge_rule_id"',
	        '"homm3_bridge_target_frame_block"',
	        '"homm3_stamp_table_id"',
	        '"homm3_stamp_source_direction"',
	        '"homm3_stamp_selected_frame"',
	        '"homm3_editor_restamp_model"',
	        '"source_paint_known_receiver_offsets_shared_overworld_reprojection.v1"',
	        '"homm3_interior_frame_selection"',
	        '"homm3_uses_interior_variant_cycle"',
	        '"homm3_shoreline_specific"',
	        '"transition_shape_model"',
	        '"road_overlay"',
	        '"road_overlay_art"',
	        '"road_shape_model"',
	        '"road_same_type_adjacency"',
	        '"road_orthogonal_mask_only"',
	        '"orthogonal_same_type_road_tiles"',
	        "ROAD_LANE_MODEL",
	        "ROAD_PIECE_SELECTION_MODEL",
	        "ROAD_CARDINAL_DIRECTIONS",
        '"fallback_procedural_marker"',
        "ghosted_sprite_with_ground_anchor",
        "TOWN_PRESENTATION_FOOTPRINT := Vector2i(3, 2)",
        "TOWN_ENTRY_OFFSET := Vector2i(1, 1)",
        "TOWN_GROUNDING_MODEL",
        "TOWN_ANCHOR_STYLE",
        "TOWN_DEPTH_CUE_MODEL",
        "TOWN_FOOTPRINT_CUE_MODEL",
        "town_3x2_footprint_bottom_middle_entry",
        "bottom_middle_visit_approach",
        "blocked_non_entry_footprint",
        "town_sprite_settled_without_base_ellipse",
        "town_contact_cues_no_base_ellipse",
        "town_contact_line_without_cast_shadow",
        "no_visible_helper_cues_3x2_contract",
        "ghosted_sprite_without_echo_plate",
    ):
        ensure(required_token in map_view_text, errors, f"OverworldMapView.gd is missing overworld art token {required_token}")

    overworld_script_text = OVERWORLD_SCRIPT_PATH.read_text(encoding="utf-8")
    for required_token in (
        '"town_presentation_profiles"',
        "func validation_town_presentation_profiles",
    ):
        ensure(required_token in overworld_script_text, errors, f"OverworldShell.gd is missing town-footprint validation token {required_token}")


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
    parser = argparse.ArgumentParser(description="Validate repository content and scaffolding.")
    parser.add_argument("--economy-resource-report", action="store_true", help="Print the opt-in economy/resource compatibility report.")
    parser.add_argument("--economy-resource-report-json", type=str, default="", help="Write the opt-in economy/resource compatibility report as JSON.")
    parser.add_argument("--market-faction-cost-report", action="store_true", help="Print the opt-in bounded market/faction-cost hook report.")
    parser.add_argument("--market-faction-cost-report-json", type=str, default="", help="Write the opt-in bounded market/faction-cost hook report as JSON.")
    parser.add_argument("--strict-economy-resource-fixtures", action="store_true", help="Validate isolated strict economy/resource schema fixtures.")
    parser.add_argument("--overworld-object-report", action="store_true", help="Print the opt-in overworld object compatibility report.")
    parser.add_argument("--overworld-object-report-json", type=str, default="", help="Write the opt-in overworld object compatibility report as JSON.")
    parser.add_argument("--strict-overworld-object-fixtures", action="store_true", help="Validate isolated strict overworld object schema fixtures.")
    parser.add_argument("--neutral-encounter-report", action="store_true", help="Print the opt-in neutral encounter compatibility report.")
    parser.add_argument("--neutral-encounter-report-json", type=str, default="", help="Write the opt-in neutral encounter compatibility report as JSON.")
    parser.add_argument("--strict-neutral-encounter-fixtures", action="store_true", help="Validate isolated strict neutral encounter schema fixtures.")
    args = parser.parse_args()

    errors: list[str] = []
    validate_content(errors)
    validate_project_and_scenes(errors)
    validate_save_management(errors)
    validate_skirmish_setup(errors)
    validate_campaign_browser(errors)
    validate_settings_and_onboarding(errors)
    validate_main_menu_first_view(errors)
    validate_map_editor_shell_slice(errors)
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
    validate_overworld_object_ai_valuation_route_effects(errors)
    validate_overworld_object_route_effect_authoring(errors)
    validate_overworld_object_content_batch_001(errors)
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
    validate_economy_wood_canonical_policy(errors)
    validate_economy_rare_resource_activation_policy(errors)
    validate_market_faction_cost_policy(errors)
    validate_economy_capture_income_loop_expansion(errors)
    strict_fixture_warnings: list[str] = []
    if args.strict_economy_resource_fixtures:
        strict_fixture_errors, strict_fixture_warnings = validate_strict_economy_resource_fixtures()
        errors.extend(strict_fixture_errors)
    strict_overworld_object_warnings: list[str] = []
    if args.strict_overworld_object_fixtures:
        strict_object_errors, strict_overworld_object_warnings = validate_strict_overworld_object_fixtures()
        errors.extend(strict_object_errors)
    strict_neutral_encounter_warnings: list[str] = []
    if args.strict_neutral_encounter_fixtures:
        strict_neutral_encounter_errors, strict_neutral_encounter_warnings = validate_strict_neutral_encounter_fixtures()
        errors.extend(strict_neutral_encounter_errors)

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
    print("- economy/resource policy keeps wood as the canonical live save id, rejects target aliases, and preserves old-save wood payloads without a save-version bump")
    print("- staged rare-resource registry/report gates expose original rare resources without live costs, market buying, save migration, or production grants")
    print("- market/faction-cost gates keep normal exchanges common-only and prove live faction, town, and building recruitment cost hooks without rare-resource activation")
    print("- Glassroad capture/income expansion has focused live-rule report coverage for relay control, lens-house income/recruits, market build, recruitment, and save/resume")
    if args.strict_economy_resource_fixtures:
        print(f"- strict economy/resource fixtures passed with {len(strict_fixture_warnings)} intentional warning case(s)")
    if args.strict_overworld_object_fixtures:
        print(f"- strict overworld object fixtures passed with {len(strict_overworld_object_warnings)} intentional warning case(s)")
    if args.strict_neutral_encounter_fixtures:
        print(f"- strict neutral encounter fixtures passed with {len(strict_neutral_encounter_warnings)} intentional warning case(s)")
    if args.economy_resource_report or args.economy_resource_report_json:
        report = build_economy_resource_report()
        if args.economy_resource_report_json:
            report_path = Path(args.economy_resource_report_json)
            report_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
            print(f"- economy/resource report JSON written to {report_path}")
        if args.economy_resource_report:
            print_economy_resource_report(report)
    if args.market_faction_cost_report or args.market_faction_cost_report_json:
        report = build_market_faction_cost_report()
        if args.market_faction_cost_report_json:
            report_path = Path(args.market_faction_cost_report_json)
            report_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
            print(f"- market/faction-cost report JSON written to {report_path}")
        if args.market_faction_cost_report:
            print_market_faction_cost_report(report)
    if args.overworld_object_report or args.overworld_object_report_json:
        report = build_overworld_object_report()
        if args.overworld_object_report_json:
            report_path = Path(args.overworld_object_report_json)
            report_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
            print(f"- overworld object report JSON written to {report_path}")
        if args.overworld_object_report:
            print_overworld_object_report(report)
    if args.neutral_encounter_report or args.neutral_encounter_report_json:
        report = build_neutral_encounter_report()
        if args.neutral_encounter_report_json:
            report_path = Path(args.neutral_encounter_report_json)
            report_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
            print(f"- neutral encounter report JSON written to {report_path}")
        if args.neutral_encounter_report:
            print_neutral_encounter_report(report)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
