#!/usr/bin/env python3
"""Translate extracted RMG template structure into original catalog records.

The source catalog is reverse-engineering evidence. This importer keeps only
functional structure and deterministic provenance hashes, then emits original
template/profile ids and labels for this project.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
SOURCE_CATALOG = Path(
    "/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/rmg-template-catalog.json"
)
OUTPUT_CATALOG = ROOT / "content" / "random_map_template_catalog.json"
OUTPUT_SUMMARY = ROOT / "content" / "random_map_template_import_summary.json"

SCHEMA_ID = "aurelion_random_map_template_catalog_v2"
SOURCE_MODEL = "original_catalog_preserving_extracted_rmg_template_grammar_only"
RESOURCE_CATEGORY_IDS = (
    "timber",
    "ore",
    "gold",
    "quicksilver",
    "ember_salt",
    "lens_crystal",
    "cut_gems",
)
SOURCE_RESOURCE_TO_ORIGINAL = {
    "wood": "timber",
    "ore": "ore",
    "gold": "gold",
    "mercury": "quicksilver",
    "sulfur": "ember_salt",
    "crystal": "lens_crystal",
    "gems": "cut_gems",
}
SOURCE_TERRAIN_TO_ORIGINAL = {
    "dirt": "plains",
    "grass": "grass",
    "sand": "plains",
    "snow": "highland",
    "swamp": "swamp",
    "rough": "highland",
    "cave": "highland",
    "lava": "highland",
}
SOURCE_TOWN_TO_ORIGINAL_FACTION = {
    "castle": "faction_embercourt",
    "rampart": "faction_thornwake",
    "tower": "faction_sunvault",
    "inferno": "faction_brasshollow",
    "necropolis": "faction_veilmourn",
    "dungeon": "faction_mireclaw",
    "stronghold": "faction_embercourt",
    "fortress": "faction_mireclaw",
    "elemental": "faction_sunvault",
    "forge": "faction_brasshollow",
    "neutral": "neutral",
}
DEFAULT_TERRAINS = ["grass", "plains", "forest", "swamp", "highland"]
DEFAULT_FACTIONS = [
    "faction_embercourt",
    "faction_mireclaw",
    "faction_sunvault",
    "faction_thornwake",
]
UNCONSUMED_ZONE_FIELDS = [
    "player_filter",
    "ownership.fixed_player_slot",
    "player_towns",
    "neutral_towns",
    "same_town_type",
    "town_policy.allowed_faction_ids",
    "mine_requirements",
    "resource_category_requirements",
    "treasure_bands",
    "monster_policy",
]
UNCONSUMED_LINK_FIELDS = [
    "player_filter",
    "guard.scaling_policy",
    "wide",
    "border_guard",
    "special_payload",
]


def stable_hash(value: Any) -> str:
    payload = json.dumps(value, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()[:16]


def map_resource_dict(source: dict[str, Any]) -> dict[str, int]:
    result = {category: 0 for category in RESOURCE_CATEGORY_IDS}
    for source_key, value in sorted(source.items()):
        mapped = SOURCE_RESOURCE_TO_ORIGINAL.get(source_key)
        if mapped:
            result[mapped] = int(value)
    return result


def unique(items: list[str]) -> list[str]:
    result: list[str] = []
    for item in items:
        if item and item not in result:
            result.append(item)
    return result


def map_terrains(source_items: list[str]) -> list[str]:
    return unique([SOURCE_TERRAIN_TO_ORIGINAL.get(item, "") for item in source_items])


def map_factions(source_items: list[str]) -> list[str]:
    return unique([SOURCE_TOWN_TO_ORIGINAL_FACTION.get(item, "") for item in source_items])


def player_range_from_supported(template: dict[str, Any], key: str, fallback: tuple[int, int]) -> dict[str, int]:
    values = [int(config[key]) for config in template.get("supported_configs", []) if key in config]
    if not values:
        return {"min": fallback[0], "max": fallback[1]}
    return {"min": min(values), "max": max(values)}


def source_name_hash(name: str) -> str:
    return "source_name_sha256_%s" % hashlib.sha256(name.encode("utf-8")).hexdigest()[:12]


def translate_zone(zone: dict[str, Any], template_index: int) -> dict[str, Any]:
    source_id = int(zone["id"])
    owner_index = int(zone.get("ownership", -1))
    owner_slot = owner_index + 1 if owner_index >= 0 else None
    minimum_by_category = map_resource_dict(zone.get("minimum_mines", {}))
    density_by_category = map_resource_dict(zone.get("mine_density", {}))
    allowed_terrain = map_terrains(zone.get("allowed_terrains", []))
    allowed_factions = map_factions(zone.get("allowed_towns", []))
    allowed_monster_factions = map_factions(zone.get("allowed_monster_towns", []))
    return {
        "id": "zone_%03d" % source_id,
        "source_zone_id": source_id,
        "role": str(zone.get("type", "treasure")),
        "type": str(zone.get("type", "treasure")),
        "base_size": int(zone.get("base_size", 1)),
        "owner_slot": owner_slot,
        "player_filter": zone.get("player_filter", {}),
        "ownership": {
            "fixed_player_slot": owner_slot,
            "source_owner_index": owner_index,
            "semantics": "fixed_player_when_non_negative_else_unowned",
        },
        "player_towns": zone.get("player_towns", {}),
        "neutral_towns": zone.get("neutral_towns", {}),
        "same_town_type": bool(zone.get("same_town_type", False)),
        "town_policy": {
            "same_type": bool(zone.get("same_town_type", False)),
            "allowed_faction_ids": allowed_factions,
            "source_mask_count": len(zone.get("allowed_towns", [])),
        },
        "mine_requirements": {
            "minimum_by_category": minimum_by_category,
            "density_by_category": density_by_category,
            "resource_category_ids": list(RESOURCE_CATEGORY_IDS),
        },
        "resource_category_requirements": {
            "minimum_by_category": minimum_by_category,
            "density_by_category": density_by_category,
        },
        "treasure_bands": zone.get("treasure_bands", []),
        "monster_policy": {
            "strength": str(zone.get("monster_strength", "avg")),
            "match_to_town": bool(zone.get("monster_match_to_town", False)),
            "allowed_faction_ids": allowed_monster_factions,
            "source_mask_count": len(zone.get("allowed_monster_towns", [])),
        },
        "terrain": {
            "match_to_faction": bool(zone.get("terrain_match_to_town", False)),
            "allowed": allowed_terrain,
            "source_mask_count": len(zone.get("allowed_terrains", [])),
        },
        "grammar_source": {
            "template_index": template_index,
            "source_row": int(zone.get("row", 0)),
            "source_bucket": int(zone.get("bucket", 0)),
        },
        "unsupported_runtime_fields": list(UNCONSUMED_ZONE_FIELDS),
    }


def translate_connection(connection: dict[str, Any]) -> dict[str, Any]:
    zone1 = int(connection["zone1"])
    zone2 = int(connection["zone2"])
    wide = bool(connection.get("wide", False))
    border_guard = bool(connection.get("border_guard", False))
    return {
        "from": "zone_%03d" % zone1,
        "to": "zone_%03d" % zone2,
        "source_endpoints": {"zone1": zone1, "zone2": zone2},
        "role": "template_connection",
        "guard_value": int(connection.get("value", 0)),
        "guard": {
            "value": int(connection.get("value", 0)),
            "scaling_policy": "preserve_value_downstream_guard_materialization_pending",
        },
        "wide": wide,
        "border_guard": border_guard,
        "player_filter": connection.get("player_filter", {}),
        "special_payload": {
            "mode": "border_guard" if border_guard else ("wide" if wide else "normal"),
            "wide_suppresses_normal_guard": wide,
            "border_guard_special_mode": border_guard,
        },
        "grammar_source": {"source_row": int(connection.get("row", 0))},
        "unsupported_runtime_fields": list(UNCONSUMED_LINK_FIELDS),
    }


def translate_template(source_template: dict[str, Any], index: int) -> dict[str, Any]:
    template_id = "translated_rmg_template_%03d_v1" % index
    human_range = player_range_from_supported(source_template, "humans", (1, 8))
    total_range = player_range_from_supported(source_template, "total", (2, 8))
    graph = source_template.get("graph_all_rows", {})
    return {
        "id": template_id,
        "label": "Translated RMG Template %03d" % index,
        "family": "translated_topology_%02d_zones_%02d_links"
        % (int(source_template.get("zone_count", 0)), int(source_template.get("connection_count", 0))),
        "size_score": {
            "min": int(source_template.get("min_size", 1)),
            "max": int(source_template.get("max_size", 32)),
        },
        "map_support": {
            "size_score_formula": "width_height_levels_div_0x510",
            "water_modes": ["land", "islands_size_score_halved"],
            "levels": {
                "supported_counts": [1, 2],
                "surface": True,
                "underground": "preserved_for_downstream_layout_slice",
            },
        },
        "players": {
            "humans": human_range,
            "total": total_range,
            "supported_config_count": int(source_template.get("supported_config_count", 0)),
            "team_mode": "free_for_all_until_assignment_slice",
        },
        "terrain_constraints": {
            "allowed": list(DEFAULT_TERRAINS),
            "match_start_to_faction": True,
        },
        "faction_constraints": {"allowed": list(DEFAULT_FACTIONS)},
        "zones": [translate_zone(zone, index) for zone in source_template.get("zones", [])],
        "links": [translate_connection(link) for link in source_template.get("connections", [])],
        "graph_summary": {
            "connected": bool(graph.get("connected", False)),
            "components": int(graph.get("components", 0)),
            "cyclomatic": int(graph.get("cyclomatic", 0)),
            "wide_edges": int(graph.get("wide_edges", 0)),
            "border_guard_edges": int(graph.get("border_guard_edges", 0)),
        },
        "error_policy": {
            "disconnected_source_graph": not bool(graph.get("connected", False)),
            "policy": "preserve_and_report_until_filtering_or_repair_slice",
        },
        "import_provenance": {
            "source_template_index": index,
            "source_rows": source_template.get("source_rows", []),
            "source_name_hash": source_name_hash(str(source_template.get("name", ""))),
            "source_name_retained": False,
        },
        "grammar_metadata": {
            "source_columns_consumed": 85,
            "preserved_field_groups": [
                "size_score",
                "water_modes",
                "levels",
                "player_filters",
                "zone_owner_type_town_mine_treasure_monster_masks",
                "connection_guard_wide_border_payloads",
                "disconnected_error_policy",
            ],
            "runtime_consumption_state": "preserved_not_fully_consumed",
        },
        "unsupported_runtime_fields": sorted(set(UNCONSUMED_ZONE_FIELDS + UNCONSUMED_LINK_FIELDS)),
    }


def manual_zone(
    zone_id: str,
    role: str,
    base_size: int,
    owner_slot: int | None,
    terrain: dict[str, Any],
    *,
    same_type: bool = False,
    mines: dict[str, int] | None = None,
    treasure: list[dict[str, int]] | None = None,
) -> dict[str, Any]:
    minimum_by_category = {category: 0 for category in RESOURCE_CATEGORY_IDS}
    for key, value in (mines or {}).items():
        minimum_by_category[key] = value
    density_by_category = {category: 0 for category in RESOURCE_CATEGORY_IDS}
    return {
        "id": zone_id,
        "role": role,
        "type": role,
        "base_size": base_size,
        "owner_slot": owner_slot,
        "player_filter": {"min_human": 1, "max_human": 4, "min_total": 2, "max_total": 4},
        "ownership": {
            "fixed_player_slot": owner_slot,
            "semantics": "fixed_player_when_present_else_unowned",
        },
        "player_towns": {"min_towns": 0, "min_castles": 1 if owner_slot else 0, "town_density": 0, "castle_density": 0},
        "neutral_towns": {"min_towns": 0, "min_castles": 0, "town_density": 0, "castle_density": 0},
        "same_town_type": same_type,
        "town_policy": {
            "same_type": same_type,
            "allowed_faction_ids": list(DEFAULT_FACTIONS),
            "source": "original_catalog_profile",
        },
        "mine_requirements": {
            "minimum_by_category": minimum_by_category,
            "density_by_category": density_by_category,
            "resource_category_ids": list(RESOURCE_CATEGORY_IDS),
        },
        "resource_category_requirements": {
            "minimum_by_category": minimum_by_category,
            "density_by_category": density_by_category,
        },
        "treasure_bands": treasure or [
            {"low": 300, "high": 900, "density": 4},
            {"low": 900, "high": 1800, "density": 2},
            {"low": 0, "high": 0, "density": 0},
        ],
        "monster_policy": {
            "strength": "avg",
            "match_to_town": role.endswith("start"),
            "allowed_faction_ids": ["neutral"] + list(DEFAULT_FACTIONS),
        },
        "terrain": terrain,
        "unsupported_runtime_fields": list(UNCONSUMED_ZONE_FIELDS),
    }


def manual_link(
    source: str,
    target: str,
    role: str,
    guard_value: int,
    *,
    wide: bool = False,
    border_guard: bool = False,
) -> dict[str, Any]:
    return {
        "from": source,
        "to": target,
        "role": role,
        "guard_value": guard_value,
        "guard": {"value": guard_value, "scaling_policy": "core_low_until_guard_materialization"},
        "wide": wide,
        "border_guard": border_guard,
        "player_filter": {"min_human": 1, "max_human": 4, "min_total": 2, "max_total": 4},
        "special_payload": {
            "mode": "border_guard" if border_guard else ("wide" if wide else "normal"),
            "wide_suppresses_normal_guard": wide,
            "border_guard_special_mode": border_guard,
        },
        "unsupported_runtime_fields": list(UNCONSUMED_LINK_FIELDS),
    }


def original_runtime_templates() -> list[dict[str, Any]]:
    base = {
        "size_score": {"min": 1, "max": 32},
        "map_support": {
            "size_score_formula": "width_height_levels_div_0x510",
            "water_modes": ["land"],
            "levels": {"supported_counts": [1], "surface": True, "underground": False},
        },
        "terrain_constraints": {"allowed": list(DEFAULT_TERRAINS), "match_start_to_faction": True},
        "faction_constraints": {"allowed": list(DEFAULT_FACTIONS)},
        "error_policy": {"disconnected_source_graph": False, "policy": "reject_invalid_links"},
        "grammar_metadata": {
            "runtime_consumption_state": "partially_consumed_preserves_expanded_fields",
            "preserved_field_groups": [
                "size_water_levels",
                "player_ranges",
                "zone_owner_town_mine_treasure_monster_fields",
                "link_guard_wide_border_payloads",
            ],
        },
        "unsupported_runtime_fields": sorted(set(UNCONSUMED_ZONE_FIELDS + UNCONSUMED_LINK_FIELDS)),
    }
    templates: list[dict[str, Any]] = []
    templates.append(
        {
            **base,
            "id": "frontier_spokes_v1",
            "label": "Frontier Spokes",
            "family": "zone_connection_spoke",
            "players": {"humans": {"min": 1, "max": 1}, "total": {"min": 3, "max": 3}},
            "zones": [
                manual_zone("start_1", "human_start", 18, 1, {"match_to_faction": True}, mines={"timber": 1, "ore": 1}),
                manual_zone("start_2", "computer_start", 18, 2, {"match_to_faction": True}, mines={"timber": 1, "ore": 1}),
                manual_zone("start_3", "computer_start", 18, 3, {"match_to_faction": True}, mines={"timber": 1, "ore": 1}),
                manual_zone("junction_1", "junction", 10, None, {"allowed": ["plains", "grass"]}),
                manual_zone("reward_1", "treasure", 8, None, {"allowed": ["forest", "grass"]}, same_type=True),
                manual_zone("reward_2", "treasure", 8, None, {"allowed": ["highland", "plains"]}),
                manual_zone("reward_3", "treasure", 8, None, {"allowed": ["swamp", "forest"]}),
            ],
            "links": [
                manual_link("start_1", "junction_1", "contest_route", 600),
                manual_link("start_2", "junction_1", "contest_route", 600),
                manual_link("start_3", "junction_1", "contest_route", 600),
                manual_link("start_1", "reward_1", "early_reward_route", 150),
                manual_link("start_2", "reward_2", "early_reward_route", 150),
                manual_link("start_3", "reward_3", "early_reward_route", 150),
                manual_link("reward_1", "junction_1", "reward_to_junction", 300, wide=True),
                manual_link("reward_2", "junction_1", "reward_to_junction", 300),
                manual_link("reward_3", "junction_1", "reward_to_junction", 300),
            ],
        }
    )
    templates.append(
        {
            **base,
            "id": "border_gate_compact_v1",
            "label": "Border Gate Compact",
            "family": "zone_connection_border_gate",
            "players": {"humans": {"min": 1, "max": 1}, "total": {"min": 3, "max": 3}},
            "zones": [
                manual_zone("start_1", "human_start", 20, 1, {"match_to_faction": True}, mines={"timber": 1, "ore": 1, "quicksilver": 1}),
                manual_zone("start_2", "computer_start", 20, 2, {"match_to_faction": True}, mines={"timber": 1, "ore": 1, "ember_salt": 1}),
                manual_zone("start_3", "computer_start", 20, 3, {"match_to_faction": True}, mines={"timber": 1, "ore": 1, "lens_crystal": 1}),
                manual_zone("gate_1", "junction", 9, None, {"allowed": ["highland", "plains"]}),
                manual_zone("relic_1", "treasure", 7, None, {"allowed": ["forest", "grass"]}),
                manual_zone("relic_2", "treasure", 7, None, {"allowed": ["swamp", "forest"]}),
                manual_zone("relic_3", "treasure", 7, None, {"allowed": ["highland", "grass"]}),
            ],
            "links": [
                manual_link("start_1", "gate_1", "contest_route", 500, border_guard=True),
                manual_link("start_2", "gate_1", "contest_route", 500),
                manual_link("start_3", "gate_1", "contest_route", 500),
                manual_link("start_1", "relic_1", "early_reward_route", 150),
                manual_link("start_2", "relic_2", "early_reward_route", 150),
                manual_link("start_3", "relic_3", "early_reward_route", 150),
                manual_link("relic_1", "gate_1", "reward_to_junction", 0, wide=True),
                manual_link("relic_2", "gate_1", "reward_to_junction", 300),
                manual_link("relic_3", "gate_1", "reward_to_junction", 300),
            ],
        }
    )
    templates.append(
        {
            **base,
            "id": "four_corners_ring_v1",
            "label": "Four Corners Ring",
            "family": "zone_connection_ring",
            "players": {"humans": {"min": 1, "max": 1}, "total": {"min": 4, "max": 4}},
            "zones": [
                manual_zone("start_1", "human_start", 17, 1, {"match_to_faction": True}),
                manual_zone("start_2", "computer_start", 17, 2, {"match_to_faction": True}),
                manual_zone("start_3", "computer_start", 17, 3, {"match_to_faction": True}),
                manual_zone("start_4", "computer_start", 17, 4, {"match_to_faction": True}),
                manual_zone("north_cache", "treasure", 8, None, {"allowed": ["forest", "grass"]}),
                manual_zone("south_cache", "treasure", 8, None, {"allowed": ["highland", "plains"]}),
                manual_zone("east_cache", "treasure", 8, None, {"allowed": ["swamp", "forest"]}),
                manual_zone("west_cache", "treasure", 8, None, {"allowed": ["grass", "plains"]}),
            ],
            "links": [
                manual_link("start_1", "north_cache", "contest_route", 450),
                manual_link("start_2", "east_cache", "contest_route", 450),
                manual_link("start_3", "south_cache", "contest_route", 450),
                manual_link("start_4", "west_cache", "contest_route", 450),
                manual_link("start_1", "west_cache", "early_reward_route", 150),
                manual_link("start_2", "north_cache", "early_reward_route", 150),
                manual_link("start_3", "east_cache", "early_reward_route", 150),
                manual_link("start_4", "south_cache", "early_reward_route", 150),
                manual_link("north_cache", "east_cache", "reward_to_junction", 0, wide=True),
                manual_link("south_cache", "west_cache", "reward_to_junction", 300, border_guard=True),
            ],
        }
    )
    return templates


def original_profiles(imported_templates: list[dict[str, Any]]) -> list[dict[str, Any]]:
    profiles: list[dict[str, Any]] = [
        {
            "id": "frontier_spokes_profile_v1",
            "label": "Frontier Spokes",
            "template_id": "frontier_spokes_v1",
            "guard_strength_profile": "core_low",
            "terrain_ids": list(DEFAULT_TERRAINS),
            "faction_ids": list(DEFAULT_FACTIONS),
            "encounter_id": "encounter_mire_raid",
        },
        {
            "id": "border_gate_compact_profile_v1",
            "label": "Border Gate Compact",
            "template_id": "border_gate_compact_v1",
            "guard_strength_profile": "core_low",
            "terrain_ids": ["grass", "forest", "swamp", "highland"],
            "faction_ids": DEFAULT_FACTIONS[:3],
            "encounter_id": "encounter_mire_raid",
        },
        {
            "id": "four_corners_ring_profile_v1",
            "label": "Four Corners Ring",
            "template_id": "four_corners_ring_v1",
            "guard_strength_profile": "core_low",
            "terrain_ids": list(DEFAULT_TERRAINS),
            "faction_ids": list(DEFAULT_FACTIONS),
            "encounter_id": "encounter_mire_raid",
        },
    ]
    for index, template in enumerate(imported_templates, 1):
        profiles.append(
            {
                "id": "translated_rmg_profile_%03d_v1" % index,
                "label": "Translated RMG Profile %03d" % index,
                "template_id": template["id"],
                "guard_strength_profile": "preserve_source_guard_values",
                "terrain_ids": list(DEFAULT_TERRAINS),
                "faction_ids": list(DEFAULT_FACTIONS),
                "encounter_id": "encounter_mire_raid",
                "imported_profile": True,
            }
        )
    return profiles


def collect_field_coverage(source_templates: list[dict[str, Any]]) -> dict[str, Any]:
    zone_fields: set[str] = set()
    link_fields: set[str] = set()
    resources: set[str] = set()
    terrains: set[str] = set()
    for template in source_templates:
        for zone in template.get("zones", []):
            zone_fields.update(zone.keys())
            resources.update(zone.get("minimum_mines", {}).keys())
            resources.update(zone.get("mine_density", {}).keys())
            terrains.update(zone.get("allowed_terrains", []))
        for link in template.get("connections", []):
            link_fields.update(link.keys())
    return {
        "zone_fields": sorted(zone_fields),
        "link_fields": sorted(link_fields),
        "resource_categories": sorted(SOURCE_RESOURCE_TO_ORIGINAL.get(key, key) for key in resources),
        "terrain_source_mask_count": len(terrains),
    }


def build_catalog(source: dict[str, Any]) -> dict[str, Any]:
    source_templates = source.get("templates", [])
    imported_templates = [translate_template(template, index) for index, template in enumerate(source_templates, 1)]
    runtime_templates = original_runtime_templates()
    aggregate = source.get("aggregate", {})
    source_summary = {
        "template_count": int(aggregate.get("template_count", len(source_templates))),
        "zone_count": int(aggregate.get("zone_count", 0)),
        "connection_count": int(aggregate.get("connection_count", 0)),
        "wide_link_count": sum(1 for t in source_templates for link in t.get("connections", []) if link.get("wide")),
        "border_guard_link_count": sum(1 for t in source_templates for link in t.get("connections", []) if link.get("border_guard")),
        "supported_config_total": int(aggregate.get("supported_config_total", 0)),
        "zone_type_counts": aggregate.get("zone_type_counts", {}),
        "disconnected_template_indexes": [
            index
            for index, template in enumerate(source_templates, 1)
            if not bool(template.get("graph_all_rows", {}).get("connected", False))
        ],
        "field_coverage": collect_field_coverage(source_templates),
        "creative_name_policy": "source_names_are_not_retained_in_original_catalog_labels",
    }
    return {
        "schema_id": SCHEMA_ID,
        "source_model": SOURCE_MODEL,
        "generated_by": "scripts/tools/import_random_map_template_catalog.py",
        "import_provenance": {
            "task_id": "10184",
            "source_catalog_path": str(SOURCE_CATALOG),
            "source_catalog_sha256": stable_hash(source),
            "source_creative_names_retained": False,
        },
        "source_catalog_summary": source_summary,
        "runtime_consumption_policy": {
            "fully_consumed_now": [
                "template_id",
                "size_score",
                "players",
                "zones.id",
                "zones.role",
                "zones.base_size",
                "zones.owner_slot",
                "zones.terrain.allowed",
                "zones.terrain.match_to_faction",
                "links.from",
                "links.to",
                "links.role",
                "links.guard_value",
                "links.wide",
                "links.border_guard",
            ],
            "preserved_not_consumed": sorted(set(UNCONSUMED_ZONE_FIELDS + UNCONSUMED_LINK_FIELDS)),
            "reporting_policy": "metadata_and_staging_must_expose_unconsumed_fields_explicitly",
        },
        "resource_category_ids": list(RESOURCE_CATEGORY_IDS),
        "profiles": original_profiles(imported_templates),
        "templates": runtime_templates + imported_templates,
    }


def build_summary(catalog: dict[str, Any], source: dict[str, Any]) -> dict[str, Any]:
    summary = catalog["source_catalog_summary"]
    return {
        "schema_id": "aurelion_random_map_template_import_summary_v1",
        "source_catalog_summary": summary,
        "catalog_record_counts": {
            "profiles": len(catalog["profiles"]),
            "templates": len(catalog["templates"]),
            "translated_source_templates": summary["template_count"],
            "original_runtime_templates": 3,
        },
        "label_policy": {
            "source_creative_names_retained": False,
            "source_name_hashes": sorted(
                source_name_hash(str(template.get("name", "")))
                for template in source.get("templates", [])
                if str(template.get("name", "")).strip()
            ),
        },
    }


def main() -> None:
    source = json.loads(SOURCE_CATALOG.read_text())
    catalog = build_catalog(source)
    summary = build_summary(catalog, source)
    OUTPUT_CATALOG.write_text(json.dumps(catalog, indent=2, sort_keys=False) + "\n")
    OUTPUT_SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=False) + "\n")
    print(
        "wrote %s and %s from %d source templates"
        % (OUTPUT_CATALOG, OUTPUT_SUMMARY, summary["source_catalog_summary"]["template_count"])
    )


if __name__ == "__main__":
    main()
