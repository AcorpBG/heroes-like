class_name RandomMapGeneratorRules
extends RefCounted

const GENERATOR_VERSION := "random_map_seeded_core_v1"
const PAYLOAD_SCHEMA_ID := "generated_random_map_payload_v1"
const REPORT_SCHEMA_ID := "random_map_seed_determinism_report_v1"
const TEMPLATE_ID := "aurelion_seeded_spoke_profile_v1"
const TEMPLATE_CATALOG_PATH := "res://content/random_map_template_catalog.json"
const TEMPLATE_CATALOG_SCHEMA_ID := "aurelion_random_map_template_catalog_v2"
const TEMPLATE_CATALOG_REPORT_SCHEMA_ID := "random_map_template_catalog_grammar_report_v2"
const TEMPLATE_SELECTION_REJECTION_SCHEMA_ID := "random_map_template_selection_rejection_v1"
const ZONE_LAYOUT_SCHEMA_ID := "random_map_zone_layout_v1"
const ZONE_LAYOUT_REPORT_SCHEMA_ID := "random_map_zone_layout_water_underground_report_v1"
const TERRAIN_TRANSIT_SCHEMA_ID := "random_map_terrain_transit_semantics_v1"
const TERRAIN_TRANSIT_REPORT_SCHEMA_ID := "random_map_terrain_transit_semantics_report_v1"
const CONNECTION_GUARD_MATERIALIZATION_SCHEMA_ID := "random_map_connection_guard_materialization_v1"
const CONNECTION_GUARD_MATERIALIZATION_REPORT_SCHEMA_ID := "random_map_connection_guard_materialization_report_v1"
const MONSTER_REWARD_BANDS_SCHEMA_ID := "random_map_monster_reward_bands_v1"
const MONSTER_REWARD_BANDS_REPORT_SCHEMA_ID := "random_map_monster_reward_bands_report_v1"
const DECORATION_DENSITY_PASS_SCHEMA_ID := "random_map_decoration_density_pass_v1"
const DECORATION_DENSITY_PASS_REPORT_SCHEMA_ID := "random_map_decoration_density_pass_report_v1"
const OBJECT_FOOTPRINT_CATALOG_SCHEMA_ID := "random_map_object_footprint_catalog_v1"
const OBJECT_FOOTPRINT_REPORT_SCHEMA_ID := "random_map_object_footprint_catalog_report_v1"
const ROADS_RIVERS_WRITEOUT_SCHEMA_ID := "random_map_roads_rivers_writeout_v1"
const ROADS_RIVERS_WRITEOUT_REPORT_SCHEMA_ID := "random_map_roads_rivers_writeout_report_v1"
const TOWN_MINE_DWELLING_PLACEMENT_SCHEMA_ID := "random_map_town_mine_dwelling_placement_v1"
const TOWN_MINE_DWELLING_PLACEMENT_REPORT_SCHEMA_ID := "random_map_town_mine_dwelling_placement_report_v1"
const GENERATED_MAP_SERIALIZATION_SCHEMA_ID := "generated_random_map_serialization_record_v1"
const RNG_MODULUS := 2147483647
const RNG_MULTIPLIER := 48271
const HASH_MODULUS := 4294967296
const HEX_DIGITS := "0123456789abcdef"

const DEFAULT_FACTIONS := [
	"faction_embercourt",
	"faction_mireclaw",
	"faction_sunvault",
	"faction_thornwake",
]
const DEFAULT_TOWN_BY_FACTION := {
	"faction_embercourt": "town_riverwatch",
	"faction_mireclaw": "town_duskfen",
	"faction_sunvault": "town_prismhearth",
	"faction_thornwake": "town_thornwake_graftroot_caravan",
	"faction_brasshollow": "town_brasshollow_orevein_gantry",
	"faction_veilmourn": "town_veilmourn_bellwake_harbor",
}
const TERRAIN_BY_FACTION := {
	"faction_embercourt": "grass",
	"faction_mireclaw": "swamp",
	"faction_sunvault": "plains",
	"faction_thornwake": "forest",
	"faction_brasshollow": "highland",
	"faction_veilmourn": "water",
}
const CORE_TERRAIN_POOL := ["grass", "plains", "forest", "swamp", "highland"]
const ORIGINAL_TERRAIN_IDS := [
	"grass",
	"plains",
	"forest",
	"swamp",
	"mire",
	"highland",
	"hills",
	"ridge",
	"badlands",
	"wastes",
	"ash",
	"lava",
	"snow",
	"frost",
	"water",
	"coast",
	"shore",
	"cavern",
	"underway",
]
const SURFACE_SCENARIO_TERRAIN_IDS := ["grass", "plains", "forest", "swamp", "highland", "water"]
const UNDERGROUND_TERRAIN_ID := "cavern"
const SUPPORT_RESOURCE_SITES := [
	{"purpose": "start_support_wood", "site_id": "site_wood_wagon", "offset": Vector2i(2, 0)},
	{"purpose": "start_support_ore", "site_id": "site_ore_crates", "offset": Vector2i(0, 2)},
	{"purpose": "start_support_cache", "site_id": "site_waystone_cache", "offset": Vector2i(-2, 0)},
]
const DEFAULT_ENCOUNTER_ID := "encounter_mire_raid"
const ROAD_OVERLAY_ID := "generated_dirt_road"
const BLOCKED_TERRAIN_IDS := ["water", "coast", "shore"]
const BIOME_BY_TERRAIN := {
	"grass": "biome_grasslands",
	"plains": "biome_grasslands",
	"forest": "biome_deep_forest",
	"swamp": "biome_mire_fen",
	"mire": "biome_mire_fen",
	"highland": "biome_highland_ridge",
	"hills": "biome_highland_ridge",
	"ridge": "biome_highland_ridge",
	"badlands": "biome_rough_badlands",
	"wastes": "biome_rough_badlands",
	"ash": "biome_ash_lava_wastes",
	"lava": "biome_ash_lava_wastes",
	"snow": "biome_snow_frost_marches",
	"frost": "biome_snow_frost_marches",
	"water": "biome_coast_archipelago",
	"coast": "biome_coast_archipelago",
	"shore": "biome_coast_archipelago",
	"cavern": "biome_subterranean_underways",
	"underway": "biome_subterranean_underways",
}
const TERRAIN_MOVEMENT_COST := {
	"grass": 1,
	"plains": 1,
	"forest": 2,
	"swamp": 2,
	"mire": 2,
	"highland": 2,
	"hills": 2,
	"ridge": 2,
	"badlands": 2,
	"wastes": 2,
	"ash": 3,
	"lava": 3,
	"snow": 2,
	"frost": 2,
	"water": 999,
	"coast": 999,
	"shore": 999,
	"cavern": 2,
	"underway": 2,
}
const SUPPORT_RESOURCE_VALUE_BY_SITE := {
	"site_wood_wagon": {"gold": 0, "wood": 4, "ore": 0},
	"site_ore_crates": {"gold": 0, "wood": 0, "ore": 4},
	"site_waystone_cache": {"gold": 900, "wood": 0, "ore": 0},
}
const EARLY_RESOURCE_MINIMUMS := {"gold": 600, "wood": 4, "ore": 4}
const ROUTE_DISTANCE_WARNING_SPREAD := 10
const ROUTE_DISTANCE_FAIL_SPREAD := 20
const PRESSURE_WARNING_SPREAD := 900
const PRESSURE_FAIL_SPREAD := 1800
const MONSTER_STRENGTH_PROFILE_MODE := {
	"core_low": 2,
	"core_normal": 3,
	"core_high": 4,
	"weak": 2,
	"normal": 3,
	"strong": 4,
}
const MONSTER_UNIT_POOL_BY_FACTION := {
	"neutral": [
		{"unit_id": "unit_neutral_roadwardens", "tier": 1, "role": "road_guard"},
		{"unit_id": "unit_neutral_hearthbow_carriers", "tier": 2, "role": "ranged_guard"},
		{"unit_id": "unit_neutral_mossglass_sentinels", "tier": 3, "role": "sentinel_guard"},
	],
	"faction_embercourt": [
		{"unit_id": "unit_river_guard", "tier": 1, "role": "line_guard"},
		{"unit_id": "unit_ember_archer", "tier": 2, "role": "ranged_guard"},
		{"unit_id": "unit_citadel_pikeward", "tier": 3, "role": "elite_guard"},
	],
	"faction_mireclaw": [
		{"unit_id": "unit_blackbranch_cutthroat", "tier": 1, "role": "raider_guard"},
		{"unit_id": "unit_bog_brute", "tier": 2, "role": "brute_guard"},
		{"unit_id": "unit_gorefen_ripper", "tier": 3, "role": "elite_guard"},
	],
	"faction_sunvault": [
		{"unit_id": "unit_shard_guard", "tier": 1, "role": "line_guard"},
		{"unit_id": "unit_prism_adept", "tier": 2, "role": "caster_guard"},
		{"unit_id": "unit_aurora_ballista", "tier": 3, "role": "siege_guard"},
	],
	"faction_thornwake": [
		{"unit_id": "unit_thornwake_seedcutters", "tier": 1, "role": "skirmish_guard"},
		{"unit_id": "unit_thornwake_thornwhip_carriers", "tier": 2, "role": "control_guard"},
		{"unit_id": "unit_thornwake_sporeglass_menders", "tier": 3, "role": "support_guard"},
	],
}
const ORIGINAL_RESOURCE_CATEGORY_ORDER := [
	{"index": 0, "original_category_id": "timber", "source_equivalent": "wood", "mine_family_id": "sawmill", "guard_base_value": 1500},
	{"index": 1, "original_category_id": "quicksilver", "source_equivalent": "mercury", "mine_family_id": "alchemist_lab", "guard_base_value": 3500},
	{"index": 2, "original_category_id": "ore", "source_equivalent": "ore", "mine_family_id": "ore_pit", "guard_base_value": 1500},
	{"index": 3, "original_category_id": "ember_salt", "source_equivalent": "sulfur", "mine_family_id": "sulfur_dune_equivalent", "guard_base_value": 3500},
	{"index": 4, "original_category_id": "lens_crystal", "source_equivalent": "crystal", "mine_family_id": "crystal_cavern_equivalent", "guard_base_value": 3500},
	{"index": 5, "original_category_id": "cut_gems", "source_equivalent": "gems", "mine_family_id": "gem_pond_equivalent", "guard_base_value": 3500},
	{"index": 6, "original_category_id": "gold", "source_equivalent": "gold", "mine_family_id": "gold_mine", "guard_base_value": 7000},
]
const MINE_SITE_BY_ORIGINAL_CATEGORY := {
	"timber": {"site_id": "site_brightwood_sawmill", "object_id": "object_brightwood_sawmill", "resource_id": "wood", "family_id": "sawmill", "resource_object_id": "object_wood_wagon"},
	"quicksilver": {"site_id": "site_marsh_peat_yard", "object_id": "object_marsh_peat_yard", "resource_id": "gold", "family_id": "alchemist_lab", "resource_object_id": "object_waystone_cache"},
	"ore": {"site_id": "site_ridge_quarry", "object_id": "object_ridge_quarry", "resource_id": "ore", "family_id": "ore_pit", "resource_object_id": "object_wood_wagon"},
	"ember_salt": {"site_id": "site_floodplain_sluice_camp", "object_id": "object_floodplain_sluice_camp", "resource_id": "gold", "family_id": "sulfur_dune_equivalent", "resource_object_id": "object_waystone_cache"},
	"lens_crystal": {"site_id": "site_reef_coin_assay", "object_id": "object_reef_coin_assay", "resource_id": "gold", "family_id": "crystal_cavern_equivalent", "resource_object_id": "object_waystone_cache"},
	"cut_gems": {"site_id": "site_badlands_coin_sluice", "object_id": "object_badlands_coin_sluice", "resource_id": "gold", "family_id": "gem_pond_equivalent", "resource_object_id": "object_waystone_cache"},
	"gold": {"site_id": "site_reef_coin_assay", "object_id": "object_reef_coin_assay", "resource_id": "gold", "family_id": "gold_mine", "resource_object_id": "object_waystone_cache"},
}
const DWELLING_SITE_CANDIDATES := [
	{"site_id": "site_bogbell_croft", "object_id": "object_bogbell_croft", "neutral_dwelling_family_id": "neutral_dwelling_bogbell_croft", "biome_ids": ["biome_mire_fen", "biome_deep_forest"], "guard_pressure": "low"},
	{"site_id": "site_greenbranch_copse", "object_id": "object_greenbranch_copse", "neutral_dwelling_family_id": "neutral_dwelling_greenbranch_copse", "biome_ids": ["biome_deep_forest", "biome_grasslands"], "guard_pressure": "medium"},
	{"site_id": "site_crystal_sump", "object_id": "object_crystal_sump", "neutral_dwelling_family_id": "neutral_dwelling_crystal_sump", "biome_ids": ["biome_subterranean_underways", "biome_highland_ridge"], "guard_pressure": "medium"},
	{"site_id": "site_kite_signal_eyrie", "object_id": "object_kite_signal_eyrie", "neutral_dwelling_family_id": "neutral_dwelling_kite_signal_eyrie", "biome_ids": ["biome_highland_ridge", "biome_coast_archipelago"], "guard_pressure": "medium"},
	{"site_id": "site_saltpan_camp", "object_id": "object_saltpan_camp", "neutral_dwelling_family_id": "neutral_dwelling_saltpan_camp", "biome_ids": ["biome_rough_badlands", "biome_coast_archipelago"], "guard_pressure": "high"},
	{"site_id": "site_cliffhawk_roost", "object_id": "object_cliffhawk_roost", "neutral_dwelling_family_id": "neutral_dwelling_cliffhawk_roost", "biome_ids": ["biome_highland_ridge", "biome_grasslands"], "guard_pressure": "low"},
]
const REWARD_BAND_CANDIDATES := [
	{"reward_category": "resource_cache", "object_family_id": "reward_cache_small", "object_id": "object_waystone_cache", "value": 450, "weight": 5, "categories": ["timber", "ore", "gold"]},
	{"reward_category": "guarded_cache", "object_family_id": "guarded_reward_cache", "object_id": "object_wood_wagon", "value": 800, "weight": 4, "categories": ["timber", "ore"]},
	{"reward_category": "artifact", "object_family_id": "artifact_cache", "object_id": "artifact_waymark_compass", "value": 1400, "weight": 2, "categories": ["gold", "lens_crystal", "cut_gems"]},
	{"reward_category": "spell_access", "object_family_id": "spell_shrine", "object_id": "spell_beacon_path", "value": 1700, "weight": 1, "categories": ["quicksilver", "ember_salt", "lens_crystal"]},
]
const DECORATION_OBJECT_FAMILIES := [
	{"family_id": "decor_grass_windgrass_tufts", "display_name": "Windgrass Tufts", "role": "decor", "terrain_ids": ["grass", "plains"], "biome_ids": ["biome_grasslands"], "weight": 5, "blocks_movement": true},
	{"family_id": "decor_grass_saffron_bloom_patch", "display_name": "Saffron Bloom Patch", "role": "decor", "terrain_ids": ["grass", "plains"], "biome_ids": ["biome_grasslands"], "weight": 3, "blocks_movement": true},
	{"family_id": "obstacle_forest_fallen_silverlog", "display_name": "Fallen Silverlog", "role": "obstacle", "terrain_ids": ["forest"], "biome_ids": ["biome_deep_forest"], "weight": 5, "blocks_movement": true},
	{"family_id": "decor_forest_moonfern_bank", "display_name": "Moonfern Bank", "role": "decor", "terrain_ids": ["forest"], "biome_ids": ["biome_deep_forest"], "weight": 3, "blocks_movement": true},
	{"family_id": "obstacle_mire_sinkroot_cluster", "display_name": "Sinkroot Cluster", "role": "obstacle", "terrain_ids": ["swamp", "mire"], "biome_ids": ["biome_mire_fen"], "weight": 5, "blocks_movement": true},
	{"family_id": "decor_mire_glowmoss_hummock", "display_name": "Glowmoss Hummock", "role": "decor", "terrain_ids": ["swamp", "mire"], "biome_ids": ["biome_mire_fen"], "weight": 3, "blocks_movement": true},
	{"family_id": "obstacle_highland_slate_outcrop", "display_name": "Slate Outcrop", "role": "obstacle", "terrain_ids": ["highland", "hills", "ridge"], "biome_ids": ["biome_highland_ridge"], "weight": 5, "blocks_movement": true},
	{"family_id": "decor_highland_heather_cairn", "display_name": "Heather Cairn", "role": "decor", "terrain_ids": ["highland", "hills", "ridge"], "biome_ids": ["biome_highland_ridge"], "weight": 3, "blocks_movement": true},
	{"family_id": "obstacle_rough_suncracked_stone", "display_name": "Suncracked Stone", "role": "obstacle", "terrain_ids": ["badlands", "wastes", "ash", "lava"], "biome_ids": ["biome_rough_badlands", "biome_ash_lava_wastes"], "weight": 4, "blocks_movement": true},
	{"family_id": "decor_snow_icegrass_ridge", "display_name": "Icegrass Ridge", "role": "decor", "terrain_ids": ["snow", "frost"], "biome_ids": ["biome_snow_frost_marches"], "weight": 4, "blocks_movement": true},
	{"family_id": "obstacle_cavern_glasscap_stalagmites", "display_name": "Glasscap Stalagmites", "role": "obstacle", "terrain_ids": ["cavern", "underway"], "biome_ids": ["biome_subterranean_underways"], "weight": 4, "blocks_movement": true},
]
const OBJECT_FOOTPRINT_CATALOG := [
	{
		"id": "rmg_primary_town_anchor",
		"family_id": "town_primary",
		"display_name": "Generated Primary Town",
		"placement_kinds": ["town"],
		"object_ids": ["town_riverwatch", "town_duskfen", "town_prismhearth", "town_thornwake_graftroot_caravan", "town_brasshollow_orevein_gantry", "town_veilmourn_bellwake_harbor"],
		"footprint": {"width": 3, "height": 2, "anchor": "bottom_center", "tier": "large"},
		"runtime_footprint": {"width": 1, "height": 1, "anchor": "center", "tier": "anchor_tile"},
		"body_mask": [{"x": -1, "y": -1}, {"x": 0, "y": -1}, {"x": 1, "y": -1}, {"x": -1, "y": 0}, {"x": 0, "y": 0}, {"x": 1, "y": 0}],
		"runtime_body_mask": [{"x": 0, "y": 0}],
		"visit_mask": [{"x": 1, "y": 0}],
		"approach_mask": [{"x": 1, "y": 0}, {"x": 0, "y": 1}, {"x": -1, "y": 0}, {"x": 0, "y": -1}, {"x": 2, "y": 0}],
		"passability_mask": {"body_blocks_movement": true, "visit_tiles_passable": true, "approach_tiles_passable": true, "road_may_cross_body": false},
		"action_mask": {"visitable": true, "trigger": "town_entry", "visit_tile_required": true, "interaction_cadence": "repeatable"},
		"terrain_restrictions": {"allowed_terrain_ids": ["grass", "plains", "forest", "swamp", "mire", "highland", "hills", "ridge", "badlands", "wastes", "ash", "lava", "snow", "frost", "cavern", "underway"], "blocked_terrain_ids": ["water", "coast", "shore"]},
		"placement_predicates": ["in_bounds", "terrain_allowed", "runtime_body_unoccupied", "visit_or_approach_passable", "zone_preferred"],
		"object_limit": {"per_zone": 1, "global": 8},
		"deferred_runtime_application": "full_3x2_town_body_reserved_for_later_multitile_placement_slice",
	},
	{
		"id": "rmg_start_resource_site",
		"family_id": "resource_pickup_site",
		"display_name": "Generated Start Resource Site",
		"placement_kinds": ["resource_site"],
		"object_ids": ["site_wood_wagon", "site_ore_crates", "site_waystone_cache", "object_wood_wagon", "object_waystone_cache"],
		"footprint": {"width": 1, "height": 1, "anchor": "center", "tier": "micro"},
		"body_mask": [{"x": 0, "y": 0}],
		"runtime_body_mask": [{"x": 0, "y": 0}],
		"visit_mask": [{"x": 1, "y": 0}, {"x": 0, "y": 1}, {"x": -1, "y": 0}, {"x": 0, "y": -1}],
		"approach_mask": [{"x": 1, "y": 0}, {"x": 0, "y": 1}, {"x": -1, "y": 0}, {"x": 0, "y": -1}],
		"passability_mask": {"body_blocks_movement": true, "visit_tiles_passable": true, "approach_tiles_passable": true, "road_may_cross_body": false},
		"action_mask": {"visitable": true, "trigger": "resource_collect", "visit_tile_required": true, "interaction_cadence": "one_time"},
		"terrain_restrictions": {"allowed_terrain_ids": ["grass", "plains", "forest", "swamp", "mire", "highland", "hills", "ridge", "badlands", "wastes", "ash", "lava", "snow", "frost", "cavern", "underway"], "blocked_terrain_ids": ["water", "coast", "shore"]},
		"placement_predicates": ["in_bounds", "terrain_allowed", "runtime_body_unoccupied", "visit_or_approach_passable", "start_support_radius"],
		"object_limit": {"per_zone": 6, "global": 64},
	},
	{
		"id": "rmg_route_guard_stack",
		"family_id": "route_guard",
		"display_name": "Generated Route Guard",
		"placement_kinds": ["route_guard"],
		"object_ids": ["encounter_mire_raid"],
		"footprint": {"width": 1, "height": 1, "anchor": "center", "tier": "micro"},
		"body_mask": [{"x": 0, "y": 0}],
		"runtime_body_mask": [{"x": 0, "y": 0}],
		"visit_mask": [{"x": 1, "y": 0}, {"x": 0, "y": 1}, {"x": -1, "y": 0}, {"x": 0, "y": -1}],
		"approach_mask": [{"x": 1, "y": 0}, {"x": 0, "y": 1}, {"x": -1, "y": 0}, {"x": 0, "y": -1}],
		"passability_mask": {"body_blocks_movement": true, "visit_tiles_passable": true, "approach_tiles_passable": true, "road_may_cross_body": false},
		"action_mask": {"visitable": true, "trigger": "neutral_guard_battle", "visit_tile_required": true, "interaction_cadence": "one_time"},
		"terrain_restrictions": {"allowed_terrain_ids": ["grass", "plains", "forest", "swamp", "mire", "highland", "hills", "ridge", "badlands", "wastes", "ash", "lava", "snow", "frost", "cavern", "underway"], "blocked_terrain_ids": ["water", "coast", "shore"]},
		"placement_predicates": ["in_bounds", "terrain_allowed", "runtime_body_unoccupied", "route_anchor_adjacent", "visit_or_approach_passable"],
		"object_limit": {"per_zone": 16, "global": 128},
	},
	{
		"id": "rmg_special_border_gate",
		"family_id": "special_guard_gate",
		"display_name": "Generated Special Guard Gate",
		"placement_kinds": ["special_guard_gate"],
		"object_ids": ["border_guard_gate_placeholder"],
		"footprint": {"width": 1, "height": 1, "anchor": "center", "tier": "micro"},
		"body_mask": [{"x": 0, "y": 0}],
		"runtime_body_mask": [{"x": 0, "y": 0}],
		"visit_mask": [{"x": 1, "y": 0}, {"x": 0, "y": 1}, {"x": -1, "y": 0}, {"x": 0, "y": -1}],
		"approach_mask": [{"x": 1, "y": 0}, {"x": 0, "y": 1}, {"x": -1, "y": 0}, {"x": 0, "y": -1}],
		"passability_mask": {"body_blocks_movement": true, "visit_tiles_passable": true, "approach_tiles_passable": true, "road_may_cross_body": false},
		"action_mask": {"visitable": true, "trigger": "special_guard_unlock_then_battle", "visit_tile_required": true, "interaction_cadence": "gated"},
		"terrain_restrictions": {"allowed_terrain_ids": ["grass", "plains", "forest", "swamp", "mire", "highland", "hills", "ridge", "badlands", "wastes", "ash", "lava", "snow", "frost", "cavern", "underway"], "blocked_terrain_ids": ["water", "coast", "shore"]},
		"placement_predicates": ["in_bounds", "terrain_allowed", "runtime_body_unoccupied", "route_anchor_adjacent", "special_unlock_metadata_present"],
		"object_limit": {"per_zone": 8, "global": 64},
		"deferred_runtime_application": "final_key_gate_object_writeout_deferred",
	},
	{
		"id": "rmg_reward_object_placeholder",
		"family_id": "reward_object",
		"display_name": "Generated Reward Object",
		"placement_kinds": ["reward_reference"],
		"family_ids": ["reward_cache_small", "guarded_reward_cache", "artifact_cache", "spell_shrine"],
		"object_ids": ["object_waystone_cache", "object_wood_wagon", "artifact_waymark_compass", "spell_beacon_path"],
		"footprint": {"width": 1, "height": 1, "anchor": "center", "tier": "micro"},
		"body_mask": [{"x": 0, "y": 0}],
		"runtime_body_mask": [{"x": 0, "y": 0}],
		"visit_mask": [{"x": 1, "y": 0}, {"x": 0, "y": 1}, {"x": -1, "y": 0}, {"x": 0, "y": -1}],
		"approach_mask": [{"x": 1, "y": 0}, {"x": 0, "y": 1}, {"x": -1, "y": 0}, {"x": 0, "y": -1}],
		"passability_mask": {"body_blocks_movement": true, "visit_tiles_passable": true, "approach_tiles_passable": true, "road_may_cross_body": false},
		"action_mask": {"visitable": true, "trigger": "reward_claim", "visit_tile_required": true, "interaction_cadence": "one_time"},
		"terrain_restrictions": {"allowed_terrain_ids": ["grass", "plains", "forest", "swamp", "mire", "highland", "hills", "ridge", "badlands", "wastes", "ash", "lava", "snow", "frost", "cavern", "underway"], "blocked_terrain_ids": ["water", "coast", "shore"]},
		"placement_predicates": ["catalog_reference_present", "terrain_allowed_at_route_context", "deferred_reward_body_no_overlap_pending"],
		"object_limit": {"per_zone": 16, "global": 128},
		"deferred_runtime_application": "reward_object_body_placement_deferred_to_reward_materialization_slice",
	},
	{
		"id": "rmg_mine_placeholder",
		"family_id": "resource_mine_placeholder",
		"display_name": "Generated Mine Placeholder",
		"placement_kinds": ["mine_placeholder", "mine"],
		"family_ids": ["sawmill", "ore_pit", "gold_mine", "alchemist_lab", "sulfur_dune_equivalent", "crystal_cavern_equivalent", "gem_pond_equivalent"],
		"object_ids": ["mine_sawmill_placeholder", "mine_ore_pit_placeholder", "mine_gold_mine_placeholder", "mine_alchemist_lab_placeholder", "mine_ember_salt_placeholder", "mine_lens_crystal_placeholder", "mine_cut_gems_placeholder", "object_brightwood_sawmill", "object_ridge_quarry", "object_marsh_peat_yard", "object_floodplain_sluice_camp", "object_reef_coin_assay", "object_badlands_coin_sluice"],
		"footprint": {"width": 2, "height": 2, "anchor": "bottom_center", "tier": "medium"},
		"runtime_footprint": {"width": 1, "height": 1, "anchor": "center", "tier": "anchor_tile"},
		"body_mask": [{"x": -1, "y": -1}, {"x": 0, "y": -1}, {"x": -1, "y": 0}, {"x": 0, "y": 0}],
		"runtime_body_mask": [{"x": 0, "y": 0}],
		"visit_mask": [{"x": 0, "y": 1}, {"x": 1, "y": 0}],
		"approach_mask": [{"x": 0, "y": 1}, {"x": 1, "y": 0}, {"x": -1, "y": 1}],
		"passability_mask": {"body_blocks_movement": true, "visit_tiles_passable": true, "approach_tiles_passable": true, "road_may_cross_body": false},
		"action_mask": {"visitable": true, "trigger": "mine_capture", "visit_tile_required": true, "interaction_cadence": "capture_then_daily"},
		"terrain_restrictions": {"allowed_terrain_ids": ["grass", "plains", "forest", "swamp", "mire", "highland", "hills", "ridge", "badlands", "wastes", "ash", "lava", "snow", "frost", "cavern", "underway"], "blocked_terrain_ids": ["water", "coast", "shore"]},
		"placement_predicates": ["in_bounds", "terrain_allowed", "runtime_body_unoccupied", "adjacent_resource_staging_space"],
		"object_limit": {"per_zone": 7, "global": 128},
		"deferred_runtime_application": "template_driven_mine_placement_deferred_to_town_mine_dwelling_slice",
	},
	{
		"id": "rmg_neutral_dwelling_site",
		"family_id": "neutral_dwelling",
		"display_name": "Generated Neutral Dwelling",
		"placement_kinds": ["neutral_dwelling"],
		"family_ids": ["neutral_dwelling"],
		"object_ids": ["object_bogbell_croft", "object_greenbranch_copse", "object_crystal_sump", "object_kite_signal_eyrie", "object_saltpan_camp", "object_cliffhawk_roost"],
		"footprint": {"width": 2, "height": 2, "anchor": "bottom_center", "tier": "medium"},
		"runtime_footprint": {"width": 1, "height": 1, "anchor": "center", "tier": "anchor_tile"},
		"body_mask": [{"x": -1, "y": -1}, {"x": 0, "y": -1}, {"x": -1, "y": 0}, {"x": 0, "y": 0}],
		"runtime_body_mask": [{"x": 0, "y": 0}],
		"visit_mask": [{"x": 0, "y": 1}, {"x": 1, "y": 0}],
		"approach_mask": [{"x": 0, "y": 1}, {"x": 1, "y": 0}, {"x": -1, "y": 1}],
		"passability_mask": {"body_blocks_movement": true, "visit_tiles_passable": true, "approach_tiles_passable": true, "road_may_cross_body": false},
		"action_mask": {"visitable": true, "trigger": "neutral_dwelling_recruitment", "visit_tile_required": true, "interaction_cadence": "persistent_weekly"},
		"terrain_restrictions": {"allowed_terrain_ids": ["grass", "plains", "forest", "swamp", "mire", "highland", "hills", "ridge", "badlands", "wastes", "ash", "lava", "snow", "frost", "cavern", "underway"], "blocked_terrain_ids": ["water", "coast", "shore"]},
		"placement_predicates": ["in_bounds", "terrain_allowed", "runtime_body_unoccupied", "visit_or_approach_passable", "zone_role_and_reward_context"],
		"object_limit": {"per_zone": 2, "global": 32},
		"deferred_runtime_application": "neutral_dwelling_site_is_staged_as_resource_node_until_final_object_writeout",
	},
	{
		"id": "rmg_decorative_obstacle_anchor",
		"family_id": "decorative_obstacle",
		"display_name": "Generated Decorative Obstacle",
		"placement_kinds": ["decorative_obstacle"],
		"family_ids": ["decor_grass_windgrass_tufts", "decor_grass_saffron_bloom_patch", "obstacle_forest_fallen_silverlog", "decor_forest_moonfern_bank", "obstacle_mire_sinkroot_cluster", "decor_mire_glowmoss_hummock", "obstacle_highland_slate_outcrop", "decor_highland_heather_cairn", "obstacle_rough_suncracked_stone", "decor_snow_icegrass_ridge", "obstacle_cavern_glasscap_stalagmites"],
		"footprint": {"width": 1, "height": 1, "anchor": "center", "tier": "micro"},
		"body_mask": [{"x": 0, "y": 0}],
		"runtime_body_mask": [{"x": 0, "y": 0}],
		"visit_mask": [],
		"approach_mask": [],
		"passability_mask": {"body_blocks_movement": true, "visit_tiles_passable": false, "approach_tiles_passable": false, "road_may_cross_body": false},
		"action_mask": {"visitable": false, "trigger": "none", "visit_tile_required": false, "interaction_cadence": "none"},
		"terrain_restrictions": {"allowed_terrain_ids": ["grass", "plains", "forest", "swamp", "mire", "highland", "hills", "ridge", "badlands", "wastes", "ash", "lava", "snow", "frost", "cavern", "underway"], "blocked_terrain_ids": ["water", "coast", "shore"]},
		"placement_predicates": ["in_bounds", "terrain_allowed", "runtime_body_unoccupied", "not_on_required_route", "not_on_approach"],
		"object_limit": {"per_zone": 64, "global": 512},
		"links_to_decoration_family_catalog": true,
	},
]

class DeterministicRng:
	var _state := 1

	func _init(seed_value: int) -> void:
		_state = max(1, seed_value)

	func next_float() -> float:
		_state = int((_state * RandomMapGeneratorRules.RNG_MULTIPLIER) % RandomMapGeneratorRules.RNG_MODULUS)
		return float(_state) / float(RandomMapGeneratorRules.RNG_MODULUS)

	func next_index(size: int) -> int:
		if size <= 0:
			return 0
		return min(size - 1, int(floor(next_float() * float(size))))

	func jitter(amount: float) -> float:
		return (next_float() * 2.0 - 1.0) * amount

static func generate(input_config: Dictionary) -> Dictionary:
	var normalized := normalize_config(input_config)
	if bool(normalized.get("template_selection", {}).get("rejected", false)):
		return _template_selection_rejection_result(normalized)
	var rng := DeterministicRng.new(_positive_seed(_stable_stringify(_generation_seed_payload(normalized))))
	var phases := []

	var template := _build_runtime_template(normalized)
	phases.append(_phase_record("template_profile", {
		"template_id": String(template.get("id", "")),
		"profile_id": String(normalized.get("profile", {}).get("id", "")),
		"source": String(template.get("source", "")),
		"zone_count": template.get("zones", []).size(),
		"link_count": template.get("links", []).size(),
		"selection": normalized.get("template_selection", {}),
		"player_assignment": normalized.get("player_assignment", {}),
		"grammar_metadata": template.get("grammar_metadata", {}),
		"unsupported_runtime_fields": template.get("unsupported_runtime_fields", []),
		"unconsumed_field_policy": String(template.get("unconsumed_field_policy", "")),
	}))

	var zones := _build_runtime_zones(template, normalized, rng)
	phases.append(_phase_record("runtime_zone_graph", {"zone_count": zones.size(), "link_count": template.get("links", []).size()}))

	var seeds := _place_zone_seeds(zones, normalized, rng)
	phases.append(_phase_record("zone_seed_layout", {"seed_count": seeds.size()}))

	var zone_layout := _build_zone_layout(template, zones, template.get("links", []), seeds, normalized, rng)
	phases.append(_phase_record("zone_footprint_layout", _zone_layout_phase_summary(zone_layout)))

	var zone_grid: Array = zone_layout.get("surface_owner_grid", [])
	_update_zone_geometry(zones, zone_grid)
	phases.append(_phase_record("terrain_owner_grid", {"width": int(normalized.get("size", {}).get("width", 0)), "height": int(normalized.get("size", {}).get("height", 0)), "source": "zone_layout_surface_owner_grid"}))

	var terrain_rows := _terrain_rows_from_zone_layout(zone_layout, zones)
	var terrain_transit := _build_terrain_transit_semantics(zone_layout, zones, template.get("links", []), terrain_rows, normalized)
	phases.append(_phase_record("terrain_biome_coherence", _terrain_phase_summary(terrain_rows, zones)))
	phases.append(_phase_record("terrain_transit_semantics", _terrain_transit_phase_summary(terrain_transit)))

	var placements := _place_generated_objects(zones, template.get("links", []), seeds, zone_grid, terrain_rows, normalized, rng)
	phases.append(_phase_record("object_placement_staging", _placement_counts(placements.get("object_placements", []))))

	var constraints := _build_constraint_payload(normalized, zones, template.get("links", []), seeds, zone_grid, terrain_rows, placements, zone_layout, terrain_transit)
	phases.append(_phase_record("connection_guard_materialization", _connection_guard_materialization_phase_summary(constraints.get("connection_guard_materialization", {}))))
	phases.append(_phase_record("monster_reward_bands", _monster_reward_bands_phase_summary(constraints.get("monster_reward_bands", {}))))
	phases.append(_phase_record("town_mine_dwelling_placement", _town_mine_dwelling_phase_summary(constraints.get("town_mine_dwelling_placement", {}))))
	phases.append(_phase_record("decoration_density_pass", _decoration_density_phase_summary(constraints.get("decoration_density_pass", {}))))
	phases.append(_phase_record("object_footprint_catalog", _object_footprint_phase_summary(constraints.get("object_footprint_catalog", {}))))
	phases.append(_phase_record("route_road_constraint_writeout", {
		"road_segment_count": int(constraints.get("road_network", {}).get("road_segments", []).size()),
		"required_reachability": String(constraints.get("route_reachability_proof", {}).get("status", "unknown")),
	}))
	phases.append(_phase_record("roads_rivers_writeout", _roads_rivers_writeout_phase_summary(constraints.get("roads_rivers_writeout", {}))))
	phases.append(_phase_record("resource_encounter_fairness_report", {
		"status": String(constraints.get("fairness_report", {}).get("status", "unknown")),
		"start_count": int(constraints.get("fairness_report", {}).get("early_resource_support", {}).get("per_start", []).size()),
		"guard_route_count": int(constraints.get("fairness_report", {}).get("guard_pressure", {}).get("route_guards", []).size()),
		"materialized_connection_guard_count": int(constraints.get("connection_guard_materialization", {}).get("summary", {}).get("materialized_record_count", 0)),
		"monster_reward_record_count": int(constraints.get("monster_reward_bands", {}).get("summary", {}).get("record_count", 0)),
		"mine_count": int(constraints.get("town_mine_dwelling_placement", {}).get("summary", {}).get("mine_count", 0)),
		"dwelling_count": int(constraints.get("town_mine_dwelling_placement", {}).get("summary", {}).get("dwelling_count", 0)),
		"decoration_record_count": int(constraints.get("decoration_density_pass", {}).get("summary", {}).get("record_count", 0)),
	}))

	var scenario_record := _build_scenario_record(normalized, terrain_rows, placements, constraints)
	var terrain_layers_record := _build_terrain_layers_record(normalized, constraints)
	var staging := _build_staging_payload(normalized, template, zones, seeds, zone_grid, placements, constraints, zone_layout)

	var generated_map := {
		"schema_id": PAYLOAD_SCHEMA_ID,
		"source": "generated_random_map",
		"write_policy": "staged_payload_only_no_authored_content_write",
		"metadata": _metadata(normalized),
		"phase_pipeline": phases,
		"staging": staging,
		"scenario_record": scenario_record,
		"terrain_layers_record": terrain_layers_record,
	}
	generated_map["stable_signature"] = _hash32_hex(_stable_stringify(generated_map))

	var report := validate_generated_payload(generated_map)
	return {
		"ok": bool(report.get("ok", false)),
		"generated_map": generated_map,
		"report": report,
	}

static func seed_determinism_report(input_config: Dictionary) -> Dictionary:
	var first := generate(input_config)
	var second := generate(input_config)
	var changed_config := input_config.duplicate(true)
	changed_config["seed"] = "%s:changed" % String(input_config.get("seed", "0"))
	var third := generate(changed_config)
	var first_payload: Dictionary = first.get("generated_map", {})
	var second_payload: Dictionary = second.get("generated_map", {})
	var third_payload: Dictionary = third.get("generated_map", {})
	var same_payload := _stable_stringify(first_payload) == _stable_stringify(second_payload)
	var same_signature := String(first_payload.get("stable_signature", "")) == String(second_payload.get("stable_signature", ""))
	var changed_seed_changes_payload := String(first_payload.get("stable_signature", "")) != String(third_payload.get("stable_signature", ""))
	var first_validation: Dictionary = first.get("report", {})
	var second_validation: Dictionary = second.get("report", {})
	var third_validation: Dictionary = third.get("report", {})
	var ok := bool(first.get("ok", false)) and bool(second.get("ok", false)) and same_payload and same_signature and changed_seed_changes_payload
	return {
		"ok": ok,
		"schema_id": REPORT_SCHEMA_ID,
		"generator_version": String(first_payload.get("metadata", {}).get("generator_version", "")),
		"normalized_seed": String(first_payload.get("metadata", {}).get("normalized_seed", "")),
		"profile_id": String(first_payload.get("metadata", {}).get("profile", {}).get("id", "")),
		"same_input_payload_equivalent": same_payload,
		"same_input_signature_equivalent": same_signature,
		"changed_seed_changes_payload": changed_seed_changes_payload,
		"stable_signature": String(first_payload.get("stable_signature", "")),
		"changed_seed_signature": String(third_payload.get("stable_signature", "")),
		"first_validation": first_validation,
		"second_validation": second_validation,
		"changed_seed_validation": third_validation,
		"determinism_sources_excluded": [
			"runtime_clock",
			"filesystem_order",
			"renderer_state",
			"editor_state",
			"unordered_dictionary_iteration",
		],
	}

static func template_catalog_report(input_config: Dictionary = {}) -> Dictionary:
	var normalized := normalize_config(input_config)
	var catalog := _load_template_catalog()
	var templates: Array = catalog.get("templates", [])
	var profiles: Array = catalog.get("profiles", [])
	var source_summary: Dictionary = catalog.get("source_catalog_summary", {}) if catalog.get("source_catalog_summary", {}) is Dictionary else {}
	var runtime_policy: Dictionary = catalog.get("runtime_consumption_policy", {}) if catalog.get("runtime_consumption_policy", {}) is Dictionary else {}
	var selected_template: Dictionary = normalized.get("template", {})
	var template_summaries := []
	var profile_summaries := []
	var failures := []
	var imported_template_count := 0
	var imported_zone_count := 0
	var imported_link_count := 0
	var imported_wide_link_count := 0
	var imported_border_guard_link_count := 0
	var templates_with_expanded_fields := 0
	for template in templates:
		if not (template is Dictionary):
			failures.append("catalog contains a non-dictionary template")
			continue
		var zone_ids := {}
		var wide_count := 0
		var border_count := 0
		var expanded_zone_field_count := 0
		var expanded_link_field_count := 0
		for zone in template.get("zones", []):
			if not (zone is Dictionary):
				failures.append("template %s contains a non-dictionary zone" % String(template.get("id", "")))
				continue
			var zone_id := String(zone.get("id", ""))
			if zone_id == "" or zone_ids.has(zone_id):
				failures.append("template %s has missing or duplicate zone id %s" % [String(template.get("id", "")), zone_id])
			zone_ids[zone_id] = true
			if _zone_has_expanded_grammar_fields(zone):
				expanded_zone_field_count += 1
		for link in template.get("links", []):
			if not (link is Dictionary):
				failures.append("template %s contains a non-dictionary link" % String(template.get("id", "")))
				continue
			if not zone_ids.has(String(link.get("from", ""))) or not zone_ids.has(String(link.get("to", ""))):
				failures.append("template %s has a link with invalid endpoints" % String(template.get("id", "")))
			if bool(link.get("wide", false)):
				wide_count += 1
			if bool(link.get("border_guard", false)):
				border_count += 1
			if _link_has_expanded_grammar_fields(link):
				expanded_link_field_count += 1
		var import_provenance: Dictionary = template.get("import_provenance", {}) if template.get("import_provenance", {}) is Dictionary else {}
		if bool(import_provenance.get("source_name_retained", true)) == false:
			imported_template_count += 1
			imported_zone_count += template.get("zones", []).size()
			imported_link_count += template.get("links", []).size()
			imported_wide_link_count += wide_count
			imported_border_guard_link_count += border_count
		if expanded_zone_field_count > 0 and expanded_link_field_count > 0:
			templates_with_expanded_fields += 1
		template_summaries.append({
			"id": String(template.get("id", "")),
			"label": String(template.get("label", "")),
			"family": String(template.get("family", "")),
			"zone_count": template.get("zones", []).size(),
			"link_count": template.get("links", []).size(),
			"wide_link_count": wide_count,
			"border_guard_link_count": border_count,
			"expanded_zone_field_count": expanded_zone_field_count,
			"expanded_link_field_count": expanded_link_field_count,
			"unsupported_runtime_fields": template.get("unsupported_runtime_fields", []),
			"grammar_metadata": template.get("grammar_metadata", {}),
			"supports_requested_constraints": _template_matches_constraints(template, normalized.get("size", {}), normalized.get("player_constraints", {})),
		})
	for profile in profiles:
		if not (profile is Dictionary):
			failures.append("catalog contains a non-dictionary profile")
			continue
		profile_summaries.append({
			"id": String(profile.get("id", "")),
			"template_id": String(profile.get("template_id", "")),
			"terrain_ids": profile.get("terrain_ids", []),
			"faction_ids": profile.get("faction_ids", []),
		})
	if templates.size() < 2:
		failures.append("template catalog must contain multiple templates")
	if profiles.size() < 2:
		failures.append("template catalog must contain multiple profiles")
	if String(catalog.get("schema_id", "")) != TEMPLATE_CATALOG_SCHEMA_ID:
		failures.append("template catalog schema mismatch")
	if selected_template.is_empty():
		failures.append("no template selected for requested constraints")
	if int(source_summary.get("template_count", 0)) != 53:
		failures.append("source catalog summary must preserve 53 extracted templates")
	if int(source_summary.get("zone_count", 0)) != 646:
		failures.append("source catalog summary must preserve 646 extracted zones")
	if int(source_summary.get("connection_count", 0)) != 869:
		failures.append("source catalog summary must preserve 869 extracted links")
	if int(source_summary.get("wide_link_count", 0)) != 21:
		failures.append("source catalog summary must preserve 21 wide links")
	if int(source_summary.get("border_guard_link_count", 0)) != 8:
		failures.append("source catalog summary must preserve 8 border-guard links")
	if imported_template_count != int(source_summary.get("template_count", 0)):
		failures.append("translated import record count does not match source summary")
	if imported_zone_count != int(source_summary.get("zone_count", 0)):
		failures.append("translated import zone count does not match source summary")
	if imported_link_count != int(source_summary.get("connection_count", 0)):
		failures.append("translated import link count does not match source summary")
	if templates_with_expanded_fields < 4:
		failures.append("catalog must expose expanded grammar fields across original and imported templates")
	return {
		"ok": failures.is_empty(),
		"schema_id": TEMPLATE_CATALOG_REPORT_SCHEMA_ID,
		"catalog_schema_id": String(catalog.get("schema_id", "")),
		"catalog_path": TEMPLATE_CATALOG_PATH,
		"template_count": templates.size(),
		"profile_count": profiles.size(),
		"source_catalog_summary": source_summary,
		"translated_import_counts": {
			"template_count": imported_template_count,
			"zone_count": imported_zone_count,
			"link_count": imported_link_count,
			"wide_link_count": imported_wide_link_count,
			"border_guard_link_count": imported_border_guard_link_count,
		},
		"runtime_consumption_policy": runtime_policy,
		"templates_with_expanded_fields": templates_with_expanded_fields,
		"selected_template_id": String(normalized.get("template_id", "")),
		"selected_profile_id": String(normalized.get("profile", {}).get("id", "")),
		"selection_source": String(normalized.get("template_selection", {}).get("source", "")),
		"template_summaries": template_summaries,
		"profile_summaries": profile_summaries,
		"failures": failures,
	}

static func zone_layout_report(input_config: Dictionary) -> Dictionary:
	var first := generate(input_config)
	var second := generate(input_config)
	var changed_seed_config := input_config.duplicate(true)
	changed_seed_config["seed"] = "%s:changed" % String(input_config.get("seed", "0"))
	var changed_seed := generate(changed_seed_config)
	var first_payload: Dictionary = first.get("generated_map", {})
	var second_payload: Dictionary = second.get("generated_map", {})
	var changed_payload: Dictionary = changed_seed.get("generated_map", {})
	var first_layout: Dictionary = first_payload.get("staging", {}).get("zone_layout", {})
	var second_layout: Dictionary = second_payload.get("staging", {}).get("zone_layout", {})
	var changed_layout: Dictionary = changed_payload.get("staging", {}).get("zone_layout", {})
	var same_signature := String(first_payload.get("stable_signature", "")) == String(second_payload.get("stable_signature", ""))
	var changed_seed_changes_signature := String(first_payload.get("stable_signature", "")) != String(changed_payload.get("stable_signature", ""))
	var same_layout_signature := String(first_layout.get("layout_signature", "")) == String(second_layout.get("layout_signature", ""))
	var changed_seed_changes_layout_signature := String(first_layout.get("layout_signature", "")) != String(changed_layout.get("layout_signature", ""))
	var layout_validation := _zone_layout_validation(first_layout, first_payload)
	var ok := not first_payload.is_empty() and not second_payload.is_empty() and same_signature and changed_seed_changes_signature and same_layout_signature and changed_seed_changes_layout_signature and bool(layout_validation.get("ok", false))
	return {
		"ok": ok,
		"schema_id": ZONE_LAYOUT_REPORT_SCHEMA_ID,
		"stable_signature": String(first_payload.get("stable_signature", "")),
		"changed_seed_signature": String(changed_payload.get("stable_signature", "")),
		"same_input_signature_equivalent": same_signature,
		"changed_seed_changes_signature": changed_seed_changes_signature,
		"layout_signature": String(first_layout.get("layout_signature", "")),
		"changed_seed_layout_signature": String(changed_layout.get("layout_signature", "")),
		"same_input_layout_signature_equivalent": same_layout_signature,
		"changed_seed_changes_layout_signature": changed_seed_changes_layout_signature,
		"zone_layout": first_layout,
		"layout_validation": layout_validation,
		"payload_validation": first.get("report", {}),
		"no_ui_save_writeback_claim": {
			"campaign_available": bool(first_payload.get("scenario_record", {}).get("selection", {}).get("availability", {}).get("campaign", true)),
			"skirmish_available": bool(first_payload.get("scenario_record", {}).get("selection", {}).get("availability", {}).get("skirmish", true)),
			"write_policy": String(first_payload.get("write_policy", "")),
		},
	}

static func terrain_transit_report(input_config: Dictionary) -> Dictionary:
	var first := generate(input_config)
	var second := generate(input_config)
	var changed_seed_config := input_config.duplicate(true)
	changed_seed_config["seed"] = "%s:changed" % String(input_config.get("seed", "0"))
	var changed_seed := generate(changed_seed_config)
	var first_payload: Dictionary = first.get("generated_map", {})
	var second_payload: Dictionary = second.get("generated_map", {})
	var changed_payload: Dictionary = changed_seed.get("generated_map", {})
	var first_semantics: Dictionary = first_payload.get("staging", {}).get("terrain_transit_semantics", {})
	var second_semantics: Dictionary = second_payload.get("staging", {}).get("terrain_transit_semantics", {})
	var changed_semantics: Dictionary = changed_payload.get("staging", {}).get("terrain_transit_semantics", {})
	var same_signature := String(first_semantics.get("terrain_transit_signature", "")) == String(second_semantics.get("terrain_transit_signature", ""))
	var changed_seed_changes_signature := String(first_semantics.get("terrain_transit_signature", "")) != String(changed_semantics.get("terrain_transit_signature", ""))
	var validation := _terrain_transit_validation(first_semantics, first_payload)
	var ok := not first_payload.is_empty() and not second_payload.is_empty() and same_signature and changed_seed_changes_signature and bool(validation.get("ok", false))
	return {
		"ok": ok,
		"schema_id": TERRAIN_TRANSIT_REPORT_SCHEMA_ID,
		"stable_signature": String(first_payload.get("stable_signature", "")),
		"changed_seed_signature": String(changed_payload.get("stable_signature", "")),
		"terrain_transit_signature": String(first_semantics.get("terrain_transit_signature", "")),
		"changed_seed_terrain_transit_signature": String(changed_semantics.get("terrain_transit_signature", "")),
		"same_input_terrain_transit_signature_equivalent": same_signature,
		"changed_seed_changes_terrain_transit_signature": changed_seed_changes_signature,
		"terrain_transit_semantics": first_semantics,
		"terrain_transit_validation": validation,
		"payload_validation": first.get("report", {}),
		"no_ui_save_writeback_claim": {
			"campaign_available": bool(first_payload.get("scenario_record", {}).get("selection", {}).get("availability", {}).get("campaign", true)),
			"skirmish_available": bool(first_payload.get("scenario_record", {}).get("selection", {}).get("availability", {}).get("skirmish", true)),
			"write_policy": String(first_payload.get("write_policy", "")),
		},
	}

static func connection_guard_materialization_report(input_config: Dictionary) -> Dictionary:
	var first := generate(input_config)
	var second := generate(input_config)
	var changed_seed_config := input_config.duplicate(true)
	changed_seed_config["seed"] = "%s:changed" % String(input_config.get("seed", "0"))
	var changed_seed := generate(changed_seed_config)
	var first_payload: Dictionary = first.get("generated_map", {})
	var second_payload: Dictionary = second.get("generated_map", {})
	var changed_payload: Dictionary = changed_seed.get("generated_map", {})
	var first_guards: Dictionary = first_payload.get("staging", {}).get("connection_guard_materialization", {})
	var second_guards: Dictionary = second_payload.get("staging", {}).get("connection_guard_materialization", {})
	var changed_guards: Dictionary = changed_payload.get("staging", {}).get("connection_guard_materialization", {})
	var same_signature := String(first_guards.get("connection_guard_materialization_signature", "")) == String(second_guards.get("connection_guard_materialization_signature", ""))
	var changed_seed_changes_signature := String(first_guards.get("connection_guard_materialization_signature", "")) != String(changed_guards.get("connection_guard_materialization_signature", ""))
	var validation := _connection_guard_materialization_validation(first_guards, first_payload)
	var ok := not first_payload.is_empty() and not second_payload.is_empty() and same_signature and bool(validation.get("ok", false))
	return {
		"ok": ok,
		"schema_id": CONNECTION_GUARD_MATERIALIZATION_REPORT_SCHEMA_ID,
		"stable_signature": String(first_payload.get("stable_signature", "")),
		"changed_seed_signature": String(changed_payload.get("stable_signature", "")),
		"connection_guard_materialization_signature": String(first_guards.get("connection_guard_materialization_signature", "")),
		"changed_seed_connection_guard_materialization_signature": String(changed_guards.get("connection_guard_materialization_signature", "")),
		"same_input_connection_guard_materialization_signature_equivalent": same_signature,
		"changed_seed_changes_connection_guard_materialization_signature": changed_seed_changes_signature,
		"connection_guard_materialization": first_guards,
		"changed_seed_connection_guard_materialization": changed_guards,
		"connection_guard_materialization_validation": validation,
		"payload_validation": first.get("report", {}),
		"no_ui_save_writeback_claim": {
			"campaign_available": bool(first_payload.get("scenario_record", {}).get("selection", {}).get("availability", {}).get("campaign", true)),
			"skirmish_available": bool(first_payload.get("scenario_record", {}).get("selection", {}).get("availability", {}).get("skirmish", true)),
			"write_policy": String(first_payload.get("write_policy", "")),
		},
	}

static func monster_reward_bands_report(input_config: Dictionary) -> Dictionary:
	var first := generate(input_config)
	var second := generate(input_config)
	var changed_seed_config := input_config.duplicate(true)
	changed_seed_config["seed"] = "%s:changed" % String(input_config.get("seed", "0"))
	var changed_seed := generate(changed_seed_config)
	var first_payload: Dictionary = first.get("generated_map", {})
	var second_payload: Dictionary = second.get("generated_map", {})
	var changed_payload: Dictionary = changed_seed.get("generated_map", {})
	var first_bands: Dictionary = first_payload.get("staging", {}).get("monster_reward_bands", {})
	var second_bands: Dictionary = second_payload.get("staging", {}).get("monster_reward_bands", {})
	var changed_bands: Dictionary = changed_payload.get("staging", {}).get("monster_reward_bands", {})
	var same_signature := String(first_bands.get("monster_reward_bands_signature", "")) == String(second_bands.get("monster_reward_bands_signature", ""))
	var changed_seed_changes_signature := String(first_bands.get("monster_reward_bands_signature", "")) != String(changed_bands.get("monster_reward_bands_signature", ""))
	var validation := _monster_reward_bands_validation(first_bands, first_payload)
	var ok := not first_payload.is_empty() and not second_payload.is_empty() and same_signature and changed_seed_changes_signature and bool(validation.get("ok", false))
	return {
		"ok": ok,
		"schema_id": MONSTER_REWARD_BANDS_REPORT_SCHEMA_ID,
		"stable_signature": String(first_payload.get("stable_signature", "")),
		"changed_seed_signature": String(changed_payload.get("stable_signature", "")),
		"monster_reward_bands_signature": String(first_bands.get("monster_reward_bands_signature", "")),
		"changed_seed_monster_reward_bands_signature": String(changed_bands.get("monster_reward_bands_signature", "")),
		"same_input_monster_reward_bands_signature_equivalent": same_signature,
		"changed_seed_changes_monster_reward_bands_signature": changed_seed_changes_signature,
		"monster_reward_bands": first_bands,
		"changed_seed_monster_reward_bands": changed_bands,
		"monster_reward_bands_validation": validation,
		"payload_validation": first.get("report", {}),
		"no_ui_save_writeback_claim": {
			"campaign_available": bool(first_payload.get("scenario_record", {}).get("selection", {}).get("availability", {}).get("campaign", true)),
			"skirmish_available": bool(first_payload.get("scenario_record", {}).get("selection", {}).get("availability", {}).get("skirmish", true)),
			"write_policy": String(first_payload.get("write_policy", "")),
		},
	}

static func decoration_density_report(input_config: Dictionary) -> Dictionary:
	var first := generate(input_config)
	var second := generate(input_config)
	var changed_seed_config := input_config.duplicate(true)
	changed_seed_config["seed"] = "%s:changed" % String(input_config.get("seed", "0"))
	var changed_seed := generate(changed_seed_config)
	var first_payload: Dictionary = first.get("generated_map", {})
	var second_payload: Dictionary = second.get("generated_map", {})
	var changed_payload: Dictionary = changed_seed.get("generated_map", {})
	var first_density: Dictionary = first_payload.get("staging", {}).get("decoration_density_pass", {})
	var second_density: Dictionary = second_payload.get("staging", {}).get("decoration_density_pass", {})
	var changed_density: Dictionary = changed_payload.get("staging", {}).get("decoration_density_pass", {})
	var same_signature := String(first_density.get("decoration_density_signature", "")) == String(second_density.get("decoration_density_signature", ""))
	var changed_seed_changes_signature := String(first_density.get("decoration_density_signature", "")) != String(changed_density.get("decoration_density_signature", ""))
	var validation := _decoration_density_validation(first_density, first_payload)
	var can_change := int(first_density.get("summary", {}).get("effective_target_total", 0)) > 0
	var ok := not first_payload.is_empty() and not second_payload.is_empty() and same_signature and (changed_seed_changes_signature or not can_change) and bool(validation.get("ok", false))
	return {
		"ok": ok,
		"schema_id": DECORATION_DENSITY_PASS_REPORT_SCHEMA_ID,
		"stable_signature": String(first_payload.get("stable_signature", "")),
		"changed_seed_signature": String(changed_payload.get("stable_signature", "")),
		"decoration_density_signature": String(first_density.get("decoration_density_signature", "")),
		"changed_seed_decoration_density_signature": String(changed_density.get("decoration_density_signature", "")),
		"same_input_decoration_density_signature_equivalent": same_signature,
		"changed_seed_changes_decoration_density_signature": changed_seed_changes_signature,
		"changed_seed_change_required": can_change,
		"decoration_density_pass": first_density,
		"changed_seed_decoration_density_pass": changed_density,
		"decoration_density_validation": validation,
		"payload_validation": first.get("report", {}),
		"no_ui_save_writeback_claim": {
			"campaign_available": bool(first_payload.get("scenario_record", {}).get("selection", {}).get("availability", {}).get("campaign", true)),
			"skirmish_available": bool(first_payload.get("scenario_record", {}).get("selection", {}).get("availability", {}).get("skirmish", true)),
			"write_policy": String(first_payload.get("write_policy", "")),
		},
	}

static func object_footprint_report(input_config: Dictionary) -> Dictionary:
	var first := generate(input_config)
	var second := generate(input_config)
	var changed_seed_config := input_config.duplicate(true)
	changed_seed_config["seed"] = "%s:changed" % String(input_config.get("seed", "0"))
	var changed_seed := generate(changed_seed_config)
	var first_payload: Dictionary = first.get("generated_map", {})
	var second_payload: Dictionary = second.get("generated_map", {})
	var changed_payload: Dictionary = changed_seed.get("generated_map", {})
	var first_footprints: Dictionary = first_payload.get("staging", {}).get("object_footprint_catalog", {})
	var second_footprints: Dictionary = second_payload.get("staging", {}).get("object_footprint_catalog", {})
	var changed_footprints: Dictionary = changed_payload.get("staging", {}).get("object_footprint_catalog", {})
	var same_signature := String(first_footprints.get("object_footprint_signature", "")) == String(second_footprints.get("object_footprint_signature", ""))
	var changed_seed_changes_signature := String(first_footprints.get("object_footprint_signature", "")) != String(changed_footprints.get("object_footprint_signature", ""))
	var validation := _object_footprint_validation(first_footprints, first_payload)
	var ok := bool(first.get("ok", false)) and bool(second.get("ok", false)) and bool(changed_seed.get("ok", false)) and not first_payload.is_empty() and not second_payload.is_empty() and same_signature and changed_seed_changes_signature and bool(validation.get("ok", false))
	return {
		"ok": ok,
		"schema_id": OBJECT_FOOTPRINT_REPORT_SCHEMA_ID,
		"stable_signature": String(first_payload.get("stable_signature", "")),
		"changed_seed_signature": String(changed_payload.get("stable_signature", "")),
		"object_footprint_signature": String(first_footprints.get("object_footprint_signature", "")),
		"changed_seed_object_footprint_signature": String(changed_footprints.get("object_footprint_signature", "")),
		"same_input_object_footprint_signature_equivalent": same_signature,
		"changed_seed_changes_object_footprint_signature": changed_seed_changes_signature,
		"object_footprint_catalog": first_footprints,
		"changed_seed_object_footprint_catalog": changed_footprints,
		"object_footprint_validation": validation,
		"payload_validation": first.get("report", {}),
		"no_ui_save_writeback_claim": {
			"campaign_available": bool(first_payload.get("scenario_record", {}).get("selection", {}).get("availability", {}).get("campaign", true)),
			"skirmish_available": bool(first_payload.get("scenario_record", {}).get("selection", {}).get("availability", {}).get("skirmish", true)),
			"write_policy": String(first_payload.get("write_policy", "")),
		},
	}

static func town_mine_dwelling_placement_report(input_config: Dictionary) -> Dictionary:
	var first := generate(input_config)
	var second := generate(input_config)
	var changed_seed_config := input_config.duplicate(true)
	changed_seed_config["seed"] = "%s:changed" % String(input_config.get("seed", "0"))
	var changed_seed := generate(changed_seed_config)
	var first_payload: Dictionary = first.get("generated_map", {})
	var second_payload: Dictionary = second.get("generated_map", {})
	var changed_payload: Dictionary = changed_seed.get("generated_map", {})
	var first_records: Dictionary = first_payload.get("staging", {}).get("town_mine_dwelling_placement", {})
	var second_records: Dictionary = second_payload.get("staging", {}).get("town_mine_dwelling_placement", {})
	var changed_records: Dictionary = changed_payload.get("staging", {}).get("town_mine_dwelling_placement", {})
	var same_signature := String(first_records.get("town_mine_dwelling_signature", "")) == String(second_records.get("town_mine_dwelling_signature", ""))
	var changed_seed_changes_signature := String(first_records.get("town_mine_dwelling_signature", "")) != String(changed_records.get("town_mine_dwelling_signature", ""))
	var validation := _town_mine_dwelling_validation(first_records, first_payload)
	var ok := bool(first.get("ok", false)) and bool(second.get("ok", false)) and bool(changed_seed.get("ok", false)) and not first_payload.is_empty() and not second_payload.is_empty() and same_signature and changed_seed_changes_signature and bool(validation.get("ok", false))
	return {
		"ok": ok,
		"schema_id": TOWN_MINE_DWELLING_PLACEMENT_REPORT_SCHEMA_ID,
		"stable_signature": String(first_payload.get("stable_signature", "")),
		"changed_seed_signature": String(changed_payload.get("stable_signature", "")),
		"town_mine_dwelling_signature": String(first_records.get("town_mine_dwelling_signature", "")),
		"changed_seed_town_mine_dwelling_signature": String(changed_records.get("town_mine_dwelling_signature", "")),
		"same_input_town_mine_dwelling_signature_equivalent": same_signature,
		"changed_seed_changes_town_mine_dwelling_signature": changed_seed_changes_signature,
		"town_mine_dwelling_placement": first_records,
		"changed_seed_town_mine_dwelling_placement": changed_records,
		"town_mine_dwelling_validation": validation,
		"fairness": first_payload.get("staging", {}).get("fairness_report", {}),
		"payload_validation": first.get("report", {}),
		"no_ui_save_writeback_claim": {
			"campaign_available": bool(first_payload.get("scenario_record", {}).get("selection", {}).get("availability", {}).get("campaign", true)),
			"skirmish_available": bool(first_payload.get("scenario_record", {}).get("selection", {}).get("availability", {}).get("skirmish", true)),
			"write_policy": String(first_payload.get("write_policy", "")),
		},
	}

static func roads_rivers_writeout_report(input_config: Dictionary) -> Dictionary:
	var first := generate(input_config)
	var second := generate(input_config)
	var changed_seed_config := input_config.duplicate(true)
	changed_seed_config["seed"] = "%s:changed" % String(input_config.get("seed", "0"))
	var changed_seed := generate(changed_seed_config)
	var first_payload: Dictionary = first.get("generated_map", {})
	var second_payload: Dictionary = second.get("generated_map", {})
	var changed_payload: Dictionary = changed_seed.get("generated_map", {})
	var first_writeout: Dictionary = first_payload.get("staging", {}).get("roads_rivers_writeout", {})
	var second_writeout: Dictionary = second_payload.get("staging", {}).get("roads_rivers_writeout", {})
	var changed_writeout: Dictionary = changed_payload.get("staging", {}).get("roads_rivers_writeout", {})
	var same_signature := String(first_writeout.get("roads_rivers_writeout_signature", "")) == String(second_writeout.get("roads_rivers_writeout_signature", ""))
	var changed_seed_changes_signature := String(first_writeout.get("roads_rivers_writeout_signature", "")) != String(changed_writeout.get("roads_rivers_writeout_signature", ""))
	var validation := _roads_rivers_writeout_validation(first_writeout, first_payload)
	var ok := bool(first.get("ok", false)) and bool(second.get("ok", false)) and bool(changed_seed.get("ok", false)) and not first_payload.is_empty() and not second_payload.is_empty() and same_signature and changed_seed_changes_signature and bool(validation.get("ok", false))
	return {
		"ok": ok,
		"schema_id": ROADS_RIVERS_WRITEOUT_REPORT_SCHEMA_ID,
		"stable_signature": String(first_payload.get("stable_signature", "")),
		"changed_seed_signature": String(changed_payload.get("stable_signature", "")),
		"roads_rivers_writeout_signature": String(first_writeout.get("roads_rivers_writeout_signature", "")),
		"changed_seed_roads_rivers_writeout_signature": String(changed_writeout.get("roads_rivers_writeout_signature", "")),
		"same_input_roads_rivers_writeout_signature_equivalent": same_signature,
		"changed_seed_changes_roads_rivers_writeout_signature": changed_seed_changes_signature,
		"roads_rivers_writeout": first_writeout,
		"changed_seed_roads_rivers_writeout": changed_writeout,
		"roads_rivers_writeout_validation": validation,
		"payload_validation": first.get("report", {}),
		"no_ui_save_writeback_claim": {
			"campaign_available": bool(first_payload.get("scenario_record", {}).get("selection", {}).get("availability", {}).get("campaign", true)),
			"skirmish_available": bool(first_payload.get("scenario_record", {}).get("selection", {}).get("availability", {}).get("skirmish", true)),
			"write_policy": String(first_payload.get("write_policy", "")),
		},
	}

static func resource_encounter_fairness_report(generated_map: Dictionary) -> Dictionary:
	var staging: Dictionary = generated_map.get("staging", {})
	var scenario: Dictionary = generated_map.get("scenario_record", {})
	var placements := {
		"object_placements": staging.get("object_placements", []),
		"towns": scenario.get("towns", []),
		"resource_nodes": scenario.get("resource_nodes", []),
		"encounters": scenario.get("encounters", []),
	}
	return _fairness_report_payload(
		generated_map.get("metadata", {}),
		staging.get("zones", []),
		placements,
		staging.get("route_graph", {}),
		staging.get("route_reachability_proof", {}),
		scenario.get("objectives", {}),
		staging.get("town_mine_dwelling_placement", {})
	)

static func normalize_config(input_config: Dictionary) -> Dictionary:
	var generator_version := String(input_config.get("generator_version", GENERATOR_VERSION)).strip_edges()
	if generator_version == "":
		generator_version = GENERATOR_VERSION
	var normalized_seed := String(input_config.get("seed", "0")).strip_edges()
	if normalized_seed == "":
		normalized_seed = "0"
	var size := _normalize_size(input_config.get("size", input_config.get("map_size", "small")))
	if input_config.has("water_mode"):
		size["water_mode"] = _normalize_water_mode(input_config.get("water_mode", "land"))
	if input_config.has("level_count"):
		size["level_count"] = clampi(int(input_config.get("level_count", 1)), 1, 2)
		size["underground"] = int(size.get("level_count", 1)) > 1
	var player_constraints := _normalize_player_constraints(input_config.get("player_constraints", input_config.get("players", {})))
	var profile := _normalize_profile(input_config.get("profile", {}), player_constraints)
	var template_selection := _select_template_profile(input_config, size, player_constraints, normalized_seed, profile)
	var template: Dictionary = template_selection.get("template", {})
	profile = _merge_profile_with_catalog(profile, template_selection.get("profile", {}), player_constraints)
	var player_assignment := _build_player_assignment(template, profile, player_constraints, normalized_seed)
	if not player_assignment.is_empty():
		if String(player_assignment.get("assignment_policy", "")) == "fixed_owner_slots_first_n_players_seeded_factions":
			profile["faction_ids"] = player_assignment.get("assigned_faction_ids", profile.get("faction_ids", []))
			profile["town_ids"] = player_assignment.get("assigned_town_ids", profile.get("town_ids", []))
	var content_manifest := {
		"template_id": String(template.get("id", TEMPLATE_ID)),
		"template_source": String(template_selection.get("source", "")),
		"faction_ids": profile.get("faction_ids", []),
		"town_ids": profile.get("town_ids", []),
		"resource_site_ids": profile.get("resource_site_ids", []),
		"encounter_ids": [String(profile.get("encounter_id", DEFAULT_ENCOUNTER_ID))],
		"terrain_ids": profile.get("terrain_ids", []),
	}
	return {
		"generator_version": generator_version,
		"seed": normalized_seed,
		"size": size,
		"player_constraints": player_constraints,
		"profile": profile,
		"player_assignment": player_assignment,
		"template_id": String(template.get("id", TEMPLATE_ID)),
		"template": template,
		"template_selection": template_selection,
		"content_manifest_fingerprint": _hash32_hex(_stable_stringify(content_manifest)),
	}

static func validate_generated_payload(generated_map: Dictionary) -> Dictionary:
	var failures := []
	var warnings := []
	var metadata: Dictionary = generated_map.get("metadata", {})
	var scenario: Dictionary = generated_map.get("scenario_record", {})
	var staging: Dictionary = generated_map.get("staging", {})
	var terrain_rows: Array = scenario.get("map", [])
	var map_size: Dictionary = scenario.get("map_size", {})
	var width := int(map_size.get("width", 0))
	var height := int(map_size.get("height", 0))
	if String(generated_map.get("schema_id", "")) != PAYLOAD_SCHEMA_ID:
		failures.append("payload schema_id mismatch")
	if String(generated_map.get("write_policy", "")) != "staged_payload_only_no_authored_content_write":
		failures.append("generated payload lost no-write boundary")
	if String(metadata.get("generator_version", "")) == "" or String(metadata.get("normalized_seed", "")) == "":
		failures.append("metadata must include normalized seed and generator version")
	if terrain_rows.size() != height:
		failures.append("terrain row count %d did not match height %d" % [terrain_rows.size(), height])
	for y in range(terrain_rows.size()):
		var row = terrain_rows[y]
		if not (row is Array) or row.size() != width:
			failures.append("terrain row %d width mismatch" % y)
	var placement_ids := {}
	for placement in staging.get("object_placements", []):
		if not (placement is Dictionary):
			failures.append("non-dictionary object placement")
			continue
		var placement_id := String(placement.get("placement_id", ""))
		if placement_id == "":
			failures.append("object placement missing placement_id")
		if placement_ids.has(placement_id):
			failures.append("duplicate placement_id %s" % placement_id)
		placement_ids[placement_id] = true
		var x := int(placement.get("x", -1))
		var y := int(placement.get("y", -1))
		if x < 0 or y < 0 or x >= width or y >= height:
			failures.append("placement %s is out of bounds" % placement_id)
	var route_graph: Dictionary = staging.get("route_graph", {})
	var zone_layout: Dictionary = staging.get("zone_layout", {})
	if route_graph.get("edges", []).is_empty():
		failures.append("route graph must expose at least one generated edge")
	var zone_layout_validation := _zone_layout_validation(zone_layout, generated_map)
	if not bool(zone_layout_validation.get("ok", false)):
		for failure in zone_layout_validation.get("failures", []):
			failures.append("zone layout: %s" % String(failure))
	var terrain_constraints: Dictionary = staging.get("terrain_constraints", {})
	var terrain_transit: Dictionary = staging.get("terrain_transit_semantics", {})
	var town_start_constraints: Dictionary = staging.get("town_start_constraints", {})
	var road_network: Dictionary = staging.get("road_network", {})
	var reachability: Dictionary = staging.get("route_reachability_proof", {})
	var fairness_report: Dictionary = staging.get("fairness_report", {})
	var connection_guard_materialization: Dictionary = staging.get("connection_guard_materialization", {})
	var monster_reward_bands: Dictionary = staging.get("monster_reward_bands", {})
	var town_mine_dwelling: Dictionary = staging.get("town_mine_dwelling_placement", {})
	var decoration_density: Dictionary = staging.get("decoration_density_pass", {})
	var object_footprints: Dictionary = staging.get("object_footprint_catalog", {})
	var roads_rivers_writeout: Dictionary = staging.get("roads_rivers_writeout", {})
	if terrain_constraints.is_empty():
		failures.append("terrain constraints payload missing")
	if String(terrain_constraints.get("coherence_model", "")) == "":
		failures.append("terrain constraints must expose coherence model")
	if terrain_constraints.get("passability_grid", []).is_empty():
		failures.append("terrain constraints must expose passability grid")
	for zone_summary in terrain_constraints.get("zone_biome_summary", []):
		if zone_summary is Dictionary and String(zone_summary.get("role", "")).contains("start") and not bool(zone_summary.get("passable", false)):
			failures.append("start zone %s uses impassable terrain" % String(zone_summary.get("zone_id", "")))
	if String(terrain_transit.get("schema_id", "")) != TERRAIN_TRANSIT_SCHEMA_ID:
		failures.append("terrain transit semantics payload missing")
	else:
		if String(terrain_transit.get("terrain_transit_signature", "")) == "":
			failures.append("terrain transit semantics must expose deterministic signature")
		var normalization: Dictionary = terrain_transit.get("terrain_normalization", {})
		for zone_palette in normalization.get("zone_palettes", []):
			if not (zone_palette is Dictionary):
				failures.append("terrain normalization contains non-dictionary zone palette")
				continue
			var terrain_id := String(zone_palette.get("normalized_terrain_id", ""))
			var explicit_issue: bool = not zone_palette.get("unsupported_terrain_ids", []).is_empty() or not zone_palette.get("deferred_terrain_ids", []).is_empty()
			if not _terrain_is_known_original(terrain_id) and not explicit_issue:
				failures.append("terrain normalization for zone %s produced unknown terrain %s without explicit unsupported/deferred metadata" % [String(zone_palette.get("zone_id", "")), terrain_id])
		if terrain_transit.get("terrain_layers", []).is_empty():
			failures.append("terrain transit semantics must expose terrain layer metadata")
		if terrain_transit.get("transit_routes", {}).get("corridor_routes", []).is_empty():
			failures.append("terrain transit semantics must expose corridor route semantics")
	if String(town_start_constraints.get("schema_id", "")) != "random_map_town_start_constraints_v1":
		failures.append("town/start constraints payload missing")
	for start_constraint in town_start_constraints.get("player_starts", []):
		if not (start_constraint is Dictionary):
			failures.append("non-dictionary start constraint")
			continue
		if String(start_constraint.get("viability", "")) != "pass":
			failures.append("start constraint %s is not viable" % String(start_constraint.get("primary_town_placement_id", "")))
		if int(start_constraint.get("contest_route_count", 0)) < 1 or int(start_constraint.get("expansion_route_count", 0)) < 1:
			failures.append("start constraint %s lacks expansion or contest route" % String(start_constraint.get("primary_town_placement_id", "")))
	if String(road_network.get("writeout_policy", "")) != "staged_overlay_payload_only_no_authored_tile_write":
		failures.append("road network must keep staged no-write overlay boundary")
	if road_network.get("road_segments", []).is_empty():
		failures.append("road network must expose staged road segments")
	if String(reachability.get("status", "")) != "pass":
		failures.append("required route reachability proof failed")
	_validate_road_paths(road_network, terrain_rows, staging.get("object_placements", []), failures)
	var guard_materialization_validation := _connection_guard_materialization_validation(connection_guard_materialization, generated_map)
	if not bool(guard_materialization_validation.get("ok", false)):
		for failure in guard_materialization_validation.get("failures", []):
			failures.append("connection guard materialization: %s" % String(failure))
	for warning in guard_materialization_validation.get("warnings", []):
		warnings.append("connection guard materialization: %s" % String(warning))
	var monster_reward_validation := _monster_reward_bands_validation(monster_reward_bands, generated_map)
	if not bool(monster_reward_validation.get("ok", false)):
		for failure in monster_reward_validation.get("failures", []):
			failures.append("monster reward bands: %s" % String(failure))
	for warning in monster_reward_validation.get("warnings", []):
		warnings.append("monster reward bands: %s" % String(warning))
	var town_mine_dwelling_validation := _town_mine_dwelling_validation(town_mine_dwelling, generated_map)
	if not bool(town_mine_dwelling_validation.get("ok", false)):
		for failure in town_mine_dwelling_validation.get("failures", []):
			failures.append("town mine dwelling placement: %s" % String(failure))
	for warning in town_mine_dwelling_validation.get("warnings", []):
		warnings.append("town mine dwelling placement: %s" % String(warning))
	var decoration_validation := _decoration_density_validation(decoration_density, generated_map)
	if not bool(decoration_validation.get("ok", false)):
		for failure in decoration_validation.get("failures", []):
			failures.append("decoration density pass: %s" % String(failure))
	for warning in decoration_validation.get("warnings", []):
		warnings.append("decoration density pass: %s" % String(warning))
	var object_footprint_validation := _object_footprint_validation(object_footprints, generated_map)
	if not bool(object_footprint_validation.get("ok", false)):
		for failure in object_footprint_validation.get("failures", []):
			failures.append("object footprint catalog: %s" % String(failure))
	for warning in object_footprint_validation.get("warnings", []):
		warnings.append("object footprint catalog: %s" % String(warning))
	var roads_rivers_validation := _roads_rivers_writeout_validation(roads_rivers_writeout, generated_map)
	if not bool(roads_rivers_validation.get("ok", false)):
		for failure in roads_rivers_validation.get("failures", []):
			failures.append("roads rivers writeout: %s" % String(failure))
	for warning in roads_rivers_validation.get("warnings", []):
		warnings.append("roads rivers writeout: %s" % String(warning))
	if String(fairness_report.get("schema_id", "")) != "random_map_resource_encounter_fairness_report_v1":
		failures.append("resource/encounter fairness report missing")
	else:
		if String(fairness_report.get("status", "")) == "fail":
			failures.append("resource/encounter fairness report failed")
		for fairness_warning in fairness_report.get("warnings", []):
			warnings.append(String(fairness_warning))
	var phase_names := []
	for phase in generated_map.get("phase_pipeline", []):
		if phase is Dictionary:
			phase_names.append(String(phase.get("phase", "")))
	for required_phase in ["template_profile", "runtime_zone_graph", "zone_seed_layout", "terrain_owner_grid", "terrain_biome_coherence", "terrain_transit_semantics", "object_placement_staging", "connection_guard_materialization", "monster_reward_bands", "town_mine_dwelling_placement", "decoration_density_pass", "object_footprint_catalog", "route_road_constraint_writeout", "roads_rivers_writeout", "resource_encounter_fairness_report"]:
		if required_phase not in phase_names:
			failures.append("missing generation phase %s" % required_phase)
	if scenario.get("towns", []).is_empty():
		warnings.append("minimal core payload has no town placements")
	if scenario.get("resource_nodes", []).is_empty():
		warnings.append("minimal core payload has no resource nodes")
	return {
		"ok": failures.is_empty(),
		"status": "pass" if failures.is_empty() else "fail",
		"failure_count": failures.size(),
		"warning_count": warnings.size(),
		"failures": failures,
		"warnings": warnings,
		"map_size": {"width": width, "height": height},
		"placement_counts": _placement_counts(staging.get("object_placements", [])),
		"route_edge_count": int(route_graph.get("edges", []).size()),
		"road_segment_count": int(road_network.get("road_segments", []).size()),
		"connection_guard_materialization_status": String(connection_guard_materialization.get("status", "")),
		"connection_guard_materialization_summary": connection_guard_materialization.get("summary", {}),
		"monster_reward_bands_status": String(monster_reward_bands.get("status", "")),
		"monster_reward_bands_summary": monster_reward_bands.get("summary", {}),
		"town_mine_dwelling_status": String(town_mine_dwelling.get("status", "")),
		"town_mine_dwelling_summary": town_mine_dwelling.get("summary", {}),
		"decoration_density_status": String(decoration_density.get("status", "")),
		"decoration_density_summary": decoration_density.get("summary", {}),
		"object_footprint_status": String(object_footprints.get("status", "")),
		"object_footprint_summary": object_footprints.get("summary", {}),
		"roads_rivers_writeout_status": String(roads_rivers_writeout.get("status", "")),
		"roads_rivers_writeout_summary": roads_rivers_writeout.get("summary", {}),
		"required_reachability_status": String(reachability.get("status", "")),
		"fairness_status": String(fairness_report.get("status", "")),
		"fairness_summary": fairness_report.get("summary", {}),
		"zone_layout_status": String(zone_layout_validation.get("status", "")),
	}

static func _build_runtime_template(normalized: Dictionary) -> Dictionary:
	var selected_template: Dictionary = normalized.get("template", {})
	if not selected_template.is_empty():
		return _runtime_template_from_catalog(selected_template)
	return _fallback_runtime_template(normalized)

static func _fallback_runtime_template(normalized: Dictionary) -> Dictionary:
	var player_count := int(normalized.get("player_constraints", {}).get("player_count", 2))
	var zones := []
	for index in range(player_count):
		zones.append({
			"id": "start_%d" % (index + 1),
			"role": "human_start" if index == 0 else "computer_start",
			"base_size": 18,
			"owner_slot": index + 1,
			"terrain_match_to_faction": true,
		})
	zones.append({"id": "junction_1", "role": "junction", "base_size": 10, "owner_slot": null, "terrain_match_to_faction": false})
	for index in range(max(2, player_count)):
		zones.append({"id": "reward_%d" % (index + 1), "role": "treasure", "base_size": 8, "owner_slot": null, "terrain_match_to_faction": false})
	var links := []
	for index in range(player_count):
		var start_id := "start_%d" % (index + 1)
		var reward_id := "reward_%d" % ((index % max(2, player_count)) + 1)
		links.append({"from": start_id, "to": "junction_1", "role": "contest_route", "guard_value": 600, "wide": false, "border_guard": false})
		links.append({"from": start_id, "to": reward_id, "role": "early_reward_route", "guard_value": 150, "wide": false, "border_guard": false})
	for index in range(max(2, player_count)):
		links.append({"from": "reward_%d" % (index + 1), "to": "junction_1", "role": "reward_to_junction", "guard_value": 300, "wide": index == 0, "border_guard": false})
	return {
		"id": TEMPLATE_ID,
		"label": "Aurelion Seeded Spoke Fallback",
		"source": "built_in_fallback",
		"model": "staged_template_profile_graph",
		"zones": zones,
		"links": links,
	}

static func _runtime_template_from_catalog(template: Dictionary) -> Dictionary:
	var zones := []
	for zone in template.get("zones", []):
		if not (zone is Dictionary):
			continue
		var terrain: Dictionary = zone.get("terrain", {}) if zone.get("terrain", {}) is Dictionary else {}
		var catalog_metadata := {
			"role": String(zone.get("role", "treasure")),
			"type": String(zone.get("type", zone.get("role", "treasure"))),
			"owner_slot": zone.get("owner_slot", null),
			"ownership": zone.get("ownership", {}),
			"player_filter": zone.get("player_filter", {}),
			"player_towns": zone.get("player_towns", {}),
			"neutral_towns": zone.get("neutral_towns", {}),
			"same_town_type": bool(zone.get("same_town_type", false)),
			"town_policy": zone.get("town_policy", {}),
			"mine_requirements": zone.get("mine_requirements", {}),
			"resource_category_requirements": zone.get("resource_category_requirements", {}),
			"treasure_bands": zone.get("treasure_bands", []),
			"monster_policy": zone.get("monster_policy", {}),
			"terrain": terrain,
			"unsupported_runtime_fields": zone.get("unsupported_runtime_fields", []),
			"start_contract": "primary_town_anchor" if zone.get("owner_slot", null) != null else "neutral_zone",
		}
		zones.append({
			"id": String(zone.get("id", "")),
			"role": String(zone.get("role", "treasure")),
			"base_size": int(zone.get("base_size", 1)),
			"owner_slot": zone.get("owner_slot", null),
			"terrain_match_to_faction": bool(terrain.get("match_to_faction", zone.get("terrain_match_to_faction", false))),
			"allowed_terrain_ids": _normalized_string_array(terrain.get("allowed", []), []),
			"allowed_faction_ids": _normalized_string_array(zone.get("allowed_faction_ids", []), []),
			"catalog_metadata": catalog_metadata,
		})
	var links := []
	for link in template.get("links", []):
		if not (link is Dictionary):
			continue
		links.append({
			"from": String(link.get("from", "")),
			"to": String(link.get("to", "")),
			"role": String(link.get("role", "route")),
			"guard_value": int(link.get("guard_value", link.get("value", 0))),
			"guard": link.get("guard", {}),
			"wide": bool(link.get("wide", false)),
			"border_guard": bool(link.get("border_guard", false)),
			"special_connection": bool(link.get("wide", false)) or bool(link.get("border_guard", false)),
			"player_filter": link.get("player_filter", {}),
			"special_payload": link.get("special_payload", {}),
			"unsupported_runtime_fields": link.get("unsupported_runtime_fields", []),
		})
	return {
		"id": String(template.get("id", TEMPLATE_ID)),
		"label": String(template.get("label", "")),
		"source": "content_catalog",
		"model": "staged_template_profile_graph",
		"family": String(template.get("family", "")),
		"size_score": template.get("size_score", {}),
		"map_support": template.get("map_support", {}),
		"players": template.get("players", {}),
		"terrain_constraints": template.get("terrain_constraints", {}),
		"faction_constraints": template.get("faction_constraints", {}),
		"graph_summary": template.get("graph_summary", {}),
		"error_policy": template.get("error_policy", {}),
		"import_provenance": template.get("import_provenance", {}),
		"grammar_metadata": template.get("grammar_metadata", {}),
		"unsupported_runtime_fields": template.get("unsupported_runtime_fields", []),
		"unconsumed_field_policy": "preserved_in_runtime_template_and_report_metadata",
		"zones": zones,
		"links": links,
	}

static func _build_runtime_zones(template: Dictionary, normalized: Dictionary, rng: DeterministicRng) -> Array:
	var profile: Dictionary = normalized.get("profile", {})
	var faction_ids: Array = profile.get("faction_ids", [])
	var terrain_ids: Array = profile.get("terrain_ids", [])
	var assignment_by_slot: Dictionary = normalized.get("player_assignment", {}).get("player_slot_by_owner_slot", {})
	var player_constraints: Dictionary = normalized.get("player_constraints", {})
	var zones := []
	for zone_record in template.get("zones", []):
		if not (zone_record is Dictionary):
			continue
		var owner_slot = zone_record.get("owner_slot", null)
		var faction_id := ""
		var player_slot = null
		var player_type := "neutral"
		var team_id := ""
		if owner_slot != null and assignment_by_slot.has(str(int(owner_slot))):
			var assignment: Dictionary = assignment_by_slot[str(int(owner_slot))]
			player_slot = int(assignment.get("player_slot", 0))
			faction_id = String(assignment.get("faction_id", ""))
			player_type = String(assignment.get("player_type", "neutral"))
			team_id = String(assignment.get("team_id", ""))
		elif owner_slot != null and assignment_by_slot.is_empty() and int(owner_slot) <= int(player_constraints.get("player_count", 2)):
			player_slot = int(owner_slot)
			player_type = "human" if int(player_slot) <= int(player_constraints.get("human_count", 1)) else "computer"
			team_id = "team_%02d" % int(player_slot)
			if not faction_ids.is_empty():
				faction_id = String(faction_ids[(int(owner_slot) - 1) % faction_ids.size()])
		var terrain_palette := _zone_terrain_palette_record(zone_record, faction_id, terrain_ids, rng)
		zones.append({
			"id": String(zone_record.get("id", "")),
			"source_id": String(zone_record.get("id", "")),
			"role": String(zone_record.get("role", "treasure")),
			"owner_slot": owner_slot,
			"player_slot": player_slot,
			"player_type": player_type,
			"team_id": team_id,
			"faction_id": faction_id,
			"terrain_id": String(terrain_palette.get("normalized_terrain_id", "grass")),
			"terrain_palette": terrain_palette,
			"base_size": int(zone_record.get("base_size", 1)),
			"anchor": {},
			"bounds": {},
			"cell_count": 0,
			"catalog_metadata": zone_record.get("catalog_metadata", {}),
		})
	return zones

static func _zone_terrain(zone_record: Dictionary, faction_id: String, terrain_ids: Array, rng: DeterministicRng) -> String:
	return String(_zone_terrain_palette_record(zone_record, faction_id, terrain_ids, rng).get("normalized_terrain_id", "grass"))

static func _zone_terrain_palette_record(zone_record: Dictionary, faction_id: String, terrain_ids: Array, rng: DeterministicRng) -> Dictionary:
	var zone_id := String(zone_record.get("id", ""))
	var profile_terrain_ids := _normalized_string_array(terrain_ids, CORE_TERRAIN_POOL)
	var zone_allowed: Array = zone_record.get("allowed_terrain_ids", [])
	var unsupported := _unsupported_terrain_ids(profile_terrain_ids)
	unsupported.append_array(_unsupported_terrain_ids(zone_allowed))
	var faction_terrain := ""
	if bool(zone_record.get("terrain_match_to_faction", false)) and TERRAIN_BY_FACTION.has(faction_id):
		faction_terrain = String(TERRAIN_BY_FACTION.get(faction_id))
		if not _terrain_is_known_original(faction_terrain) and faction_terrain not in unsupported:
			unsupported.append(faction_terrain)
	var selected := ""
	var source := ""
	if faction_terrain != "" and faction_terrain in profile_terrain_ids and _terrain_is_passable(faction_terrain):
		selected = faction_terrain
		source = "faction_match_profile_palette"
	var filtered_allowed := []
	for zone_terrain_id in zone_allowed:
		var candidate := String(zone_terrain_id)
		if candidate in terrain_ids and _terrain_is_passable(candidate):
			filtered_allowed.append(candidate)
	if selected == "" and not filtered_allowed.is_empty():
		selected = String(filtered_allowed[rng.next_index(filtered_allowed.size())])
		source = "catalog_allowed_profile_intersection"
	if selected == "":
		var catalog_passable := _passable_known_terrain_ids(zone_allowed)
		if not catalog_passable.is_empty():
			selected = String(catalog_passable[rng.next_index(catalog_passable.size())])
			source = "catalog_allowed_known_fallback"
	if selected == "":
		var passable_choices := _passable_known_terrain_ids(profile_terrain_ids)
		if not passable_choices.is_empty():
			selected = String(passable_choices[rng.next_index(passable_choices.size())])
			source = "profile_palette_known_fallback"
	if selected == "":
		var fallback_pool := CORE_TERRAIN_POOL.duplicate()
		selected = String(fallback_pool[_stable_choice_index(fallback_pool.size(), "%s:%s:%s" % [zone_id, faction_id, _stable_stringify(profile_terrain_ids)])])
		source = "deterministic_core_fallback"
	var normalized := _normalize_terrain_id_for_generated_rows(selected)
	var deferred := []
	if selected != normalized:
		deferred.append(selected)
	unsupported = _unique_sorted_strings(unsupported)
	return {
		"zone_id": zone_id,
		"faction_id": faction_id,
		"terrain_match_to_faction": bool(zone_record.get("terrain_match_to_faction", false)),
		"profile_terrain_ids": profile_terrain_ids,
		"catalog_allowed_terrain_ids": _normalized_string_array(zone_allowed, []),
		"faction_terrain_id": faction_terrain,
		"selected_terrain_id": selected,
		"normalized_terrain_id": normalized,
		"original_terrain_id": normalized,
		"biome_id": _biome_for_terrain(normalized),
		"passable": _terrain_is_passable(normalized),
		"selection_source": source,
		"fallback_used": source.ends_with("_fallback") or source == "deterministic_core_fallback",
		"unsupported_terrain_ids": unsupported,
		"deferred_terrain_ids": _unique_sorted_strings(deferred),
		"deferred_reason": "terrain_row_writeout_uses_surface_supported_equivalent" if not deferred.is_empty() else "",
	}

static func _place_zone_seeds(zones: Array, normalized: Dictionary, rng: DeterministicRng) -> Dictionary:
	var size: Dictionary = normalized.get("size", {})
	var width := int(size.get("width", 16))
	var height := int(size.get("height", 12))
	var center: Vector2 = Vector2((float(width) - 1.0) * 0.5, (float(height) - 1.0) * 0.5)
	var radius_x: float = max(3.0, float(width) * 0.36)
	var radius_y: float = max(2.0, float(height) * 0.32)
	var starts: Array = _zones_with_owner(zones)
	var others: Array = _zones_without_owner(zones)
	var angle_offset: float = rng.next_float() * TAU
	var seeds: Dictionary = {}
	for index in range(starts.size()):
		var zone: Dictionary = starts[index]
		var angle := angle_offset + TAU * float(index) / float(max(1, starts.size()))
		seeds[String(zone.get("id", ""))] = _point_dict(
			clampi(int(round(center.x + cos(angle) * radius_x + rng.jitter(1.0))), 1, max(1, width - 2)),
			clampi(int(round(center.y + sin(angle) * radius_y + rng.jitter(1.0))), 1, max(1, height - 2))
		)
	for index in range(others.size()):
		var zone: Dictionary = others[index]
		var role := String(zone.get("role", "treasure"))
		var angle := angle_offset + TAU * (float(index) + 0.5) / float(max(1, others.size()))
		var radius_scale := 0.18 if role == "junction" else 0.58
		seeds[String(zone.get("id", ""))] = _point_dict(
			clampi(int(round(center.x + cos(angle) * radius_x * radius_scale + rng.jitter(1.4))), 1, max(1, width - 2)),
			clampi(int(round(center.y + sin(angle) * radius_y * radius_scale + rng.jitter(1.2))), 1, max(1, height - 2))
		)
	return _resolve_seed_collisions(seeds, width, height)

static func _assign_cells_to_zones(zones: Array, seeds: Dictionary, normalized: Dictionary) -> Array:
	var size: Dictionary = normalized.get("size", {})
	var width := int(size.get("width", 16))
	var height := int(size.get("height", 12))
	var zone_grid := []
	for y in range(height):
		var row := []
		for x in range(width):
			row.append(_nearest_zone_id(x, y, zones, seeds))
		zone_grid.append(row)
	for zone in zones:
		if not (zone is Dictionary):
			continue
		var seed: Dictionary = seeds.get(String(zone.get("id", "")), {})
		if not seed.is_empty():
			zone_grid[int(seed.get("y", 0))][int(seed.get("x", 0))] = String(zone.get("id", ""))
	_update_zone_geometry(zones, zone_grid)
	return zone_grid

static func _build_zone_layout(template: Dictionary, zones: Array, links: Array, seeds: Dictionary, normalized: Dictionary, rng: DeterministicRng) -> Dictionary:
	var size: Dictionary = normalized.get("size", {})
	var width := int(size.get("width", 16))
	var height := int(size.get("height", 12))
	var level_count := int(size.get("level_count", 1))
	var water_mode := String(size.get("water_mode", "land"))
	var template_support: Dictionary = template.get("map_support", {}) if template.get("map_support", {}) is Dictionary else {}
	var levels := []
	var unsupported := []
	if water_mode == "islands":
		unsupported.append("water_transit_object_placement_deferred")
		unsupported.append("boat_shipyard_ferry_placement_deferred")
	if level_count > 1:
		unsupported.append("underground_transit_object_placement_deferred")
		unsupported.append("subterranean_gate_placement_deferred")
	var total_water_cells := 0
	for level_index in range(level_count):
		var level_kind := "surface" if level_index == 0 else "underground"
		var level_seeds := _seeds_for_layout_level(seeds, width, height, level_index)
		var water_cells := _water_cells_for_level(width, height, water_mode, level_index)
		total_water_cells += water_cells.size()
		var allocation := _allocate_zone_level_cells(zones, level_seeds, water_cells, width, height)
		levels.append({
			"level_index": level_index,
			"kind": level_kind,
			"owner_grid": allocation.get("owner_grid", []),
			"zone_footprints": allocation.get("zone_footprints", []),
			"anchor_points": allocation.get("anchor_points", {}),
			"water_cells": water_cells,
			"water_cell_count": water_cells.size(),
			"water_mode": water_mode,
			"allocation_model": "base_size_weighted_quota_fill_from_deterministic_zone_seeds",
		})
	var layout := {
		"schema_id": ZONE_LAYOUT_SCHEMA_ID,
		"template_id": String(template.get("id", TEMPLATE_ID)),
		"dimensions": {"width": width, "height": height, "level_count": level_count},
		"policy": {
			"zone_area_model": "template_base_size_proportional_targets",
			"water_mode": water_mode,
			"water_policy": _water_policy_payload(water_mode, total_water_cells),
			"underground_policy": _underground_policy_payload(level_count, template_support),
			"object_and_transit_writeout": "deferred_to_later_rmg_parity_slices",
		},
		"levels": levels,
		"surface_owner_grid": levels[0].get("owner_grid", []) if not levels.is_empty() else [],
		"surface_water_cells": levels[0].get("water_cells", []) if not levels.is_empty() else [],
		"corridor_candidates": _corridor_candidates_from_links(links, levels, water_mode),
		"template_link_count": links.size(),
		"unsupported_runtime_features": unsupported,
		"next_slice_metadata": {
			"terrain_transit": "random-map-terrain-transit-semantics-10184",
			"object_footprints": "random-map-object-footprint-catalog-10184",
			"guard_materialization": "random-map-connection-guard-materialization-10184",
		},
	}
	layout["layout_signature"] = _hash32_hex(_stable_stringify({
		"template_id": layout.get("template_id", ""),
		"dimensions": layout.get("dimensions", {}),
		"policy": layout.get("policy", {}),
		"levels": layout.get("levels", []),
		"corridor_candidates": layout.get("corridor_candidates", []),
	}))
	return layout

static func _allocate_zone_level_cells(zones: Array, seeds: Dictionary, water_cells: Array, width: int, height: int) -> Dictionary:
	var zone_ids := []
	var base_sizes := {}
	for zone in zones:
		if not (zone is Dictionary):
			continue
		var zone_id := String(zone.get("id", ""))
		if zone_id == "":
			continue
		zone_ids.append(zone_id)
		base_sizes[zone_id] = max(1, int(zone.get("base_size", 1)))
	zone_ids.sort()
	var targets := _zone_area_targets(zone_ids, base_sizes, width * height)
	var assigned := {}
	var counts := {}
	for zone_id in zone_ids:
		counts[zone_id] = 0
		var seed: Dictionary = seeds.get(zone_id, {})
		var sx := clampi(int(seed.get("x", 0)), 0, max(0, width - 1))
		var sy := clampi(int(seed.get("y", 0)), 0, max(0, height - 1))
		var seed_key := _point_key(sx, sy)
		if not assigned.has(seed_key):
			assigned[seed_key] = zone_id
			counts[zone_id] = int(counts.get(zone_id, 0)) + 1
	for zone_id in zone_ids:
		var candidates := []
		var seed: Dictionary = seeds.get(zone_id, {})
		for y in range(height):
			for x in range(width):
				var key := _point_key(x, y)
				if assigned.has(key):
					continue
				candidates.append({
					"x": x,
					"y": y,
					"sort_key": _layout_candidate_sort_key(x, y, seed, water_cells),
				})
		candidates.sort_custom(Callable(RandomMapGeneratorRules, "_compare_layout_candidate"))
		var cursor := 0
		while int(counts.get(zone_id, 0)) < int(targets.get(zone_id, 0)) and cursor < candidates.size():
			var candidate: Dictionary = candidates[cursor]
			cursor += 1
			var candidate_key := _point_key(int(candidate.get("x", 0)), int(candidate.get("y", 0)))
			if assigned.has(candidate_key):
				continue
			assigned[candidate_key] = zone_id
			counts[zone_id] = int(counts.get(zone_id, 0)) + 1
	for y in range(height):
		for x in range(width):
			var key := _point_key(x, y)
			if assigned.has(key):
				continue
			var nearest := _nearest_zone_id(x, y, _zones_by_sorted_ids(zones, zone_ids), seeds)
			assigned[key] = nearest
			counts[nearest] = int(counts.get(nearest, 0)) + 1
	var owner_grid := []
	var water_lookup := _point_lookup(water_cells)
	var cells_by_zone := {}
	for zone_id in zone_ids:
		cells_by_zone[zone_id] = []
	for y in range(height):
		var row := []
		for x in range(width):
			var zone_id := String(assigned.get(_point_key(x, y), zone_ids[0] if not zone_ids.is_empty() else ""))
			row.append(zone_id)
			if cells_by_zone.has(zone_id):
				cells_by_zone[zone_id].append({
					"x": x,
					"y": y,
					"surface": "water" if water_lookup.has(_point_key(x, y)) else "land",
				})
		owner_grid.append(row)
	var footprints := []
	for zone_id in zone_ids:
		var cells: Array = cells_by_zone.get(zone_id, [])
		footprints.append({
			"zone_id": zone_id,
			"base_size": int(base_sizes.get(zone_id, 1)),
			"target_cell_count": int(targets.get(zone_id, 0)),
			"cell_count": cells.size(),
			"bounds": _bounds_for_cells(cells),
			"anchor": seeds.get(zone_id, {}),
			"cells": cells,
		})
	return {
		"owner_grid": owner_grid,
		"zone_footprints": footprints,
		"anchor_points": _sorted_point_dict(seeds),
	}

static func _place_generated_objects(zones: Array, links: Array, seeds: Dictionary, zone_grid: Array, terrain_rows: Array, normalized: Dictionary, rng: DeterministicRng) -> Dictionary:
	var profile: Dictionary = normalized.get("profile", {})
	var town_ids: Array = profile.get("town_ids", [])
	var placements := []
	var towns := []
	var resource_nodes := []
	var encounters := []
	var occupied := {}
	var player_index := 0
	for zone in zones:
		if not (zone is Dictionary) or zone.get("player_slot", null) == null:
			continue
		var seed: Dictionary = seeds.get(String(zone.get("id", "")), {})
		var point := _nearest_free_cell(int(seed.get("x", 0)), int(seed.get("y", 0)), String(zone.get("id", "")), zone_grid, terrain_rows, occupied, rng)
		if point.is_empty():
			continue
		var player_slot := int(zone.get("player_slot", 0))
		var player_type := String(zone.get("player_type", "computer"))
		var owner := "player" if player_type == "human" and player_slot == 1 else "enemy"
		var faction_id := String(zone.get("faction_id", ""))
		var town_id := String(town_ids[player_index % town_ids.size()]) if not town_ids.is_empty() else String(DEFAULT_TOWN_BY_FACTION.get(faction_id, "town_riverwatch"))
		var placement_id := "rmg_town_p%d" % (player_index + 1)
		var town := {"placement_id": placement_id, "town_id": town_id, "faction_id": faction_id, "player_slot": player_slot, "player_type": player_type, "team_id": String(zone.get("team_id", "")), "zone_id": String(zone.get("id", "")), "zone_role": String(zone.get("role", "")), "x": int(point.get("x", 0)), "y": int(point.get("y", 0)), "owner": owner, "town_assignment_semantics": "owned_start_uses_player_assignment_town"}
		towns.append(town)
		placements.append(_object_placement(placement_id, "town", faction_id, String(zone.get("id", "")), point, {"town_id": town_id, "owner": owner, "player_slot": player_slot, "player_type": player_type, "team_id": String(zone.get("team_id", "")), "purpose": "player_start", "zone_role": String(zone.get("role", "")), "town_assignment_semantics": "owned_start_uses_player_assignment_town", "same_type_semantics": "owned_zone_player_assignment_not_neutral_same_type"}))
		_mark_occupied(occupied, point)
		for resource_index in range(SUPPORT_RESOURCE_SITES.size()):
			var resource: Dictionary = SUPPORT_RESOURCE_SITES[resource_index]
			var support_point := _nearest_free_cell(
				int(point.get("x", 0)) + resource.get("offset", Vector2i.ZERO).x,
				int(point.get("y", 0)) + resource.get("offset", Vector2i.ZERO).y,
				String(zone.get("id", "")),
				zone_grid,
				terrain_rows,
				occupied,
				rng
			)
			if support_point.is_empty():
				continue
			var resource_placement_id := "rmg_%s_p%d" % [String(resource.get("purpose", "resource")), player_index + 1]
			resource_nodes.append({"placement_id": resource_placement_id, "site_id": String(resource.get("site_id", "")), "x": int(support_point.get("x", 0)), "y": int(support_point.get("y", 0))})
			placements.append(_object_placement(resource_placement_id, "resource_site", faction_id, String(zone.get("id", "")), support_point, {"site_id": String(resource.get("site_id", "")), "purpose": String(resource.get("purpose", ""))}))
			_mark_occupied(occupied, support_point)
		player_index += 1
	var route_reserved := _reserved_route_corridor_lookup(links, seeds, zone_grid, terrain_rows)
	for zone in zones:
		if not (zone is Dictionary):
			continue
		_place_neutral_town_for_zone(zone, zones, seeds, zone_grid, terrain_rows, occupied, route_reserved, towns, placements, rng)
		_place_mines_for_zone(zone, seeds, zone_grid, terrain_rows, occupied, route_reserved, resource_nodes, placements, rng)
		_place_dwelling_for_zone(zone, seeds, zone_grid, terrain_rows, occupied, route_reserved, resource_nodes, placements, rng)
	for index in range(links.size()):
		var link: Dictionary = links[index]
		if bool(link.get("wide", false)):
			continue
		if int(link.get("guard_value", 0)) <= 0 and not bool(link.get("border_guard", false)):
			continue
		var from_seed: Dictionary = seeds.get(String(link.get("from", "")), {})
		var to_seed: Dictionary = seeds.get(String(link.get("to", "")), {})
		if from_seed.is_empty() or to_seed.is_empty():
			continue
		var guard_point := _nearest_free_cell(
			int(round((int(from_seed.get("x", 0)) + int(to_seed.get("x", 0))) * 0.5)),
			int(round((int(from_seed.get("y", 0)) + int(to_seed.get("y", 0))) * 0.5)),
			null,
			zone_grid,
			terrain_rows,
			occupied,
			rng
		)
		if guard_point.is_empty():
			continue
		var edge_id := _route_edge_id(index + 1, String(link.get("from", "")), String(link.get("to", "")))
		if bool(link.get("border_guard", false)):
			var special_placement_id := "rmg_special_gate_%02d" % (index + 1)
			placements.append(_object_placement(special_placement_id, "special_guard_gate", "", _zone_at_point(zone_grid, guard_point), guard_point, {
				"purpose": String(link.get("role", "route")),
				"route_edge_id": edge_id,
				"guard_value": int(link.get("guard_value", 0)),
				"special_guard_type": "border_guard_gate_placeholder",
				"special_payload": link.get("special_payload", {}),
				"wide": false,
				"border_guard": true,
			}))
		else:
			var encounter_placement_id := "rmg_link_guard_%02d" % (index + 1)
			encounters.append({"placement_id": encounter_placement_id, "encounter_id": String(profile.get("encounter_id", DEFAULT_ENCOUNTER_ID)), "x": int(guard_point.get("x", 0)), "y": int(guard_point.get("y", 0)), "difficulty": "generated_core", "route_edge_id": edge_id})
			placements.append(_object_placement(encounter_placement_id, "route_guard", "", _zone_at_point(zone_grid, guard_point), guard_point, {
				"encounter_id": String(profile.get("encounter_id", DEFAULT_ENCOUNTER_ID)),
				"purpose": String(link.get("role", "route")),
				"route_edge_id": edge_id,
				"guard_value": int(link.get("guard_value", 0)),
				"wide": false,
				"border_guard": false,
			}))
		_mark_occupied(occupied, guard_point)
	_annotate_pathing_metadata(placements, towns, resource_nodes, encounters, zone_grid, terrain_rows, occupied)
	return {
		"object_placements": placements,
		"towns": towns,
		"resource_nodes": resource_nodes,
		"encounters": encounters,
	}

static func _reserved_route_corridor_lookup(links: Array, seeds: Dictionary, zone_grid: Array, terrain_rows: Array) -> Dictionary:
	var reserved := {}
	for link in links:
		if not (link is Dictionary):
			continue
		var from_seed: Dictionary = seeds.get(String(link.get("from", "")), {})
		var to_seed: Dictionary = seeds.get(String(link.get("to", "")), {})
		if from_seed.is_empty() or to_seed.is_empty():
			continue
		var x0 := int(from_seed.get("x", 0))
		var y0 := int(from_seed.get("y", 0))
		var x1 := int(to_seed.get("x", 0))
		var y1 := int(to_seed.get("y", 0))
		var steps: int = max(abs(x1 - x0), abs(y1 - y0))
		if steps <= 0:
			continue
		for step in range(steps + 1):
			var t := float(step) / float(steps)
			var x := int(round(lerpf(float(x0), float(x1), t)))
			var y := int(round(lerpf(float(y0), float(y1), t)))
			if not _point_in_rows(terrain_rows, x, y):
				continue
			if not _terrain_cell_is_passable(terrain_rows, x, y):
				continue
			if String(_zone_at_point(zone_grid, _point_dict(x, y))) == "":
				continue
			reserved[_point_key(x, y)] = true
	return reserved

static func _place_neutral_town_for_zone(zone: Dictionary, zones: Array, seeds: Dictionary, zone_grid: Array, terrain_rows: Array, occupied: Dictionary, reserved: Dictionary, towns: Array, placements: Array, rng: DeterministicRng) -> void:
	if zone.get("player_slot", null) != null:
		return
	var target_count := _neutral_town_target_count(zone)
	if target_count <= 0:
		return
	var zone_id := String(zone.get("id", ""))
	var seed: Dictionary = seeds.get(zone_id, {})
	var town_choice := _neutral_town_choice_for_zone(zone, zones, seeds)
	for index in range(target_count):
		var point := _nearest_free_cell_for_catalog("town", String(town_choice.get("faction_id", "")), String(town_choice.get("town_id", "")), int(seed.get("x", 0)) + index, int(seed.get("y", 0)) + index, zone_id, zone_grid, terrain_rows, occupied, rng, reserved)
		if point.is_empty():
			continue
		var placement_id := "rmg_neutral_town_%s_%02d" % [zone_id, index + 1]
		var faction_id := String(town_choice.get("faction_id", ""))
		var town_id := String(town_choice.get("town_id", ""))
		towns.append({
			"placement_id": placement_id,
			"town_id": town_id,
			"faction_id": faction_id,
			"player_slot": 0,
			"player_type": "neutral",
			"team_id": "",
			"zone_id": zone_id,
			"zone_role": String(zone.get("role", "")),
			"x": int(point.get("x", 0)),
			"y": int(point.get("y", 0)),
			"owner": "neutral",
			"town_assignment_semantics": String(town_choice.get("town_assignment_semantics", "")),
			"same_type_source_zone_id": String(town_choice.get("same_type_source_zone_id", "")),
		})
		placements.append(_object_placement(placement_id, "town", faction_id, zone_id, point, {
			"town_id": town_id,
			"owner": "neutral",
			"player_slot": 0,
			"player_type": "neutral",
			"team_id": "",
			"purpose": "neutral_same_type_town" if bool(town_choice.get("same_type", false)) else "neutral_town",
			"zone_role": String(zone.get("role", "")),
			"town_assignment_semantics": String(town_choice.get("town_assignment_semantics", "")),
			"same_type_semantics": String(town_choice.get("same_type_semantics", "")),
			"same_type_source_zone_id": String(town_choice.get("same_type_source_zone_id", "")),
		}))
		_mark_occupied(occupied, point)

static func _place_mines_for_zone(zone: Dictionary, seeds: Dictionary, zone_grid: Array, terrain_rows: Array, occupied: Dictionary, reserved: Dictionary, resource_nodes: Array, placements: Array, rng: DeterministicRng) -> void:
	var zone_id := String(zone.get("id", ""))
	var seed: Dictionary = seeds.get(zone_id, {})
	var requirements: Dictionary = _zone_resource_requirements(zone)
	var minimums: Dictionary = requirements.get("minimum_by_category", {})
	var densities: Dictionary = requirements.get("density_by_category", {})
	var ordinal := 0
	for category_record in ORIGINAL_RESOURCE_CATEGORY_ORDER:
		if not (category_record is Dictionary):
			continue
		var category_id := String(category_record.get("original_category_id", ""))
		var target_count := int(minimums.get(category_id, 0)) + _density_extra_count(zone, category_id, int(densities.get(category_id, 0)))
		for category_index in range(target_count):
			var mine_record: Dictionary = MINE_SITE_BY_ORIGINAL_CATEGORY.get(category_id, {})
			if mine_record.is_empty():
				continue
			var anchor_offset := _mine_anchor_offset(category_id, ordinal, bool(zone.get("player_slot", null) != null))
			var point := _nearest_free_cell_for_catalog("mine", String(mine_record.get("family_id", "")), String(mine_record.get("object_id", "")), int(seed.get("x", 0)) + int(anchor_offset.x), int(seed.get("y", 0)) + int(anchor_offset.y), zone_id, zone_grid, terrain_rows, occupied, rng, reserved)
			if point.is_empty():
				continue
			var placement_id := "rmg_mine_%s_%s_%02d" % [zone_id, category_id, category_index + 1]
			var owner := _zone_owner_label(zone)
			var mine_payload := {
				"site_id": String(mine_record.get("site_id", "")),
				"object_id": String(mine_record.get("object_id", "")),
				"family_id": String(mine_record.get("family_id", "")),
				"purpose": _mine_purpose_for_zone(zone, category_id, category_index),
				"owner": owner,
				"player_slot": int(zone.get("player_slot", 0)) if zone.get("player_slot", null) != null else 0,
				"player_type": String(zone.get("player_type", "neutral")),
				"team_id": String(zone.get("team_id", "")),
				"zone_role": String(zone.get("role", "")),
				"original_resource_category_id": category_id,
				"source_equivalent": String(category_record.get("source_equivalent", "")),
				"resource_id": String(mine_record.get("resource_id", "")),
				"mine_family_id": String(category_record.get("mine_family_id", mine_record.get("family_id", ""))),
				"guard_base_value": int(category_record.get("guard_base_value", 0)),
				"guard_pressure": _mine_guard_pressure(zone, category_record),
				"frontier_metadata": _mine_frontier_metadata(zone, category_id),
				"adjacent_resource_metadata": _adjacent_resource_metadata(mine_record, category_id),
				"seven_category_index": int(category_record.get("index", 0)),
				"minimum_requirement": int(minimums.get(category_id, 0)),
				"density_requirement": int(densities.get(category_id, 0)),
				"writeout_state": "staged_mine_resource_node_no_authored_content_writeback",
			}
			placements.append(_object_placement(placement_id, "mine", String(zone.get("faction_id", "")), zone_id, point, mine_payload))
			resource_nodes.append(_resource_node_from_placement(placement_id, mine_payload, point, zone_id))
			_mark_occupied(occupied, point)
			ordinal += 1

static func _place_dwelling_for_zone(zone: Dictionary, seeds: Dictionary, zone_grid: Array, terrain_rows: Array, occupied: Dictionary, reserved: Dictionary, resource_nodes: Array, placements: Array, rng: DeterministicRng) -> void:
	if not _zone_should_place_dwelling(zone):
		return
	var zone_id := String(zone.get("id", ""))
	var seed: Dictionary = seeds.get(zone_id, {})
	var dwelling := _dwelling_candidate_for_zone(zone)
	if dwelling.is_empty():
		return
	var point := _nearest_free_cell_for_catalog("neutral_dwelling", "neutral_dwelling", String(dwelling.get("object_id", "")), int(seed.get("x", 0)) - 2, int(seed.get("y", 0)) + 2, zone_id, zone_grid, terrain_rows, occupied, rng, reserved)
	if point.is_empty():
		return
	var placement_id := "rmg_dwelling_%s" % zone_id
	var owner := _zone_owner_label(zone)
	var payload := {
		"site_id": String(dwelling.get("site_id", "")),
		"object_id": String(dwelling.get("object_id", "")),
		"family_id": "neutral_dwelling",
		"neutral_dwelling_family_id": String(dwelling.get("neutral_dwelling_family_id", "")),
		"purpose": "start_recruitment_support" if String(zone.get("role", "")).contains("start") else "frontier_recruitment_site",
		"owner": owner,
		"player_slot": int(zone.get("player_slot", 0)) if zone.get("player_slot", null) != null else 0,
		"player_type": String(zone.get("player_type", "neutral")),
		"team_id": String(zone.get("team_id", "")),
		"zone_role": String(zone.get("role", "")),
		"guard_pressure": String(dwelling.get("guard_pressure", "medium")),
		"reward_context": _zone_reward_band_context(zone),
		"monster_band_context": _zone_monster_band_context(zone),
		"recruitment_site_category": "neutral_weekly_muster",
		"writeout_state": "staged_neutral_dwelling_resource_node_no_authored_content_writeback",
	}
	placements.append(_object_placement(placement_id, "neutral_dwelling", String(zone.get("faction_id", "")), zone_id, point, payload))
	resource_nodes.append(_resource_node_from_placement(placement_id, payload, point, zone_id))
	_mark_occupied(occupied, point)

static func _nearest_free_cell_for_catalog(kind: String, family_id: String, object_id: String, x: int, y: int, preferred_zone_id: Variant, zone_grid: Array, terrain_rows: Array, occupied: Dictionary, rng: DeterministicRng, reserved: Dictionary = {}) -> Dictionary:
	var height := zone_grid.size()
	var width: int = zone_grid[0].size() if height > 0 and zone_grid[0] is Array else 0
	x = clampi(x, 0, max(0, width - 1))
	y = clampi(y, 0, max(0, height - 1))
	var probe := {"kind": kind, "family_id": family_id, "object_id": object_id, "x": x, "y": y}
	var catalog := _object_footprint_catalog_record_for_placement(probe)
	for radius in range(max(width, height) + 1):
		var candidates := []
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if max(abs(dx), abs(dy)) != radius:
					continue
				var cx := x + dx
				var cy := y + dy
				if not _placement_candidate_satisfies_catalog(cx, cy, preferred_zone_id, zone_grid, terrain_rows, occupied, catalog, reserved):
					continue
				candidates.append({"x": cx, "y": cy})
		if not candidates.is_empty():
			return candidates[rng.next_index(candidates.size())]
	return {}

static func _placement_candidate_satisfies_catalog(x: int, y: int, preferred_zone_id: Variant, zone_grid: Array, terrain_rows: Array, occupied: Dictionary, catalog: Dictionary, reserved: Dictionary = {}) -> bool:
	if not _point_in_rows(terrain_rows, x, y):
		return false
	if not _terrain_cell_is_passable(terrain_rows, x, y):
		return false
	if preferred_zone_id != null and String(_zone_at_point(zone_grid, _point_dict(x, y))) != String(preferred_zone_id):
		return false
	var point := _point_dict(x, y)
	var runtime_body := _runtime_body_tiles_for_catalog(point, catalog)
	for body in runtime_body:
		if not (body is Dictionary):
			return false
		var bx := int(body.get("x", 0))
		var by := int(body.get("y", 0))
		if not _point_in_rows(terrain_rows, bx, by):
			return false
		if occupied.has(_point_key(bx, by)) or reserved.has(_point_key(bx, by)):
			return false
		if not _terrain_cell_is_passable(terrain_rows, bx, by):
			return false
	var terrain_id := String(terrain_rows[y][x])
	if not catalog.is_empty() and not _object_catalog_allows_terrain(catalog, terrain_id):
		return false
	var approaches := _approach_tiles_for_catalog(point, String(preferred_zone_id) if preferred_zone_id != null else "", zone_grid, terrain_rows, occupied, catalog, runtime_body)
	if bool(catalog.get("action_mask", {}).get("visit_tile_required", false)) and approaches.is_empty():
		return false
	return true

static func _neutral_town_target_count(zone: Dictionary) -> int:
	if _zone_role_is_route_connector(zone):
		return 0
	var metadata: Dictionary = zone.get("catalog_metadata", {}) if zone.get("catalog_metadata", {}) is Dictionary else {}
	var neutral_towns: Dictionary = metadata.get("neutral_towns", {}) if metadata.get("neutral_towns", {}) is Dictionary else {}
	var explicit_count := int(neutral_towns.get("min_towns", 0)) + int(neutral_towns.get("min_castles", 0))
	var density_count := 1 if int(neutral_towns.get("town_density", 0)) + int(neutral_towns.get("castle_density", 0)) >= 5 else 0
	if explicit_count + density_count > 0:
		return min(2, explicit_count + density_count)
	if bool(metadata.get("same_town_type", false)) and String(zone.get("role", "")) == "treasure":
		return 1
	return 0

static func _neutral_town_choice_for_zone(zone: Dictionary, zones: Array, seeds: Dictionary) -> Dictionary:
	var metadata: Dictionary = zone.get("catalog_metadata", {}) if zone.get("catalog_metadata", {}) is Dictionary else {}
	var same_type := bool(metadata.get("same_town_type", false)) or bool(metadata.get("town_policy", {}).get("same_type", false))
	if same_type:
		var source_zone := _nearest_owned_zone(zone, zones, seeds)
		var source_faction := String(source_zone.get("faction_id", "faction_embercourt"))
		return {
			"same_type": true,
			"faction_id": source_faction,
			"town_id": String(DEFAULT_TOWN_BY_FACTION.get(source_faction, "town_riverwatch")),
			"same_type_source_zone_id": String(source_zone.get("id", "")),
			"town_assignment_semantics": "neutral_same_type_reuses_nearest_runtime_zone_faction_choice",
			"same_type_semantics": "source_zone_choice_reused_for_neutral_town_when_same_type_flag_is_present",
		}
	var allowed: Array = metadata.get("town_policy", {}).get("allowed_faction_ids", []) if metadata.get("town_policy", {}) is Dictionary else []
	var faction_id := String(allowed[0]) if not allowed.is_empty() else "faction_embercourt"
	return {
		"same_type": false,
		"faction_id": faction_id,
		"town_id": String(DEFAULT_TOWN_BY_FACTION.get(faction_id, "town_riverwatch")),
		"same_type_source_zone_id": "",
		"town_assignment_semantics": "neutral_town_uses_allowed_original_faction_pool",
		"same_type_semantics": "same_type_flag_not_requested",
	}

static func _nearest_owned_zone(zone: Dictionary, zones: Array, seeds: Dictionary) -> Dictionary:
	var zone_seed: Dictionary = seeds.get(String(zone.get("id", "")), {})
	var best := {}
	var best_distance := 999999
	for candidate in zones:
		if not (candidate is Dictionary) or candidate.get("player_slot", null) == null:
			continue
		var candidate_seed: Dictionary = seeds.get(String(candidate.get("id", "")), {})
		var distance: int = abs(int(zone_seed.get("x", 0)) - int(candidate_seed.get("x", 0))) + abs(int(zone_seed.get("y", 0)) - int(candidate_seed.get("y", 0)))
		if best.is_empty() or distance < best_distance or (distance == best_distance and String(candidate.get("id", "")) < String(best.get("id", ""))):
			best = candidate
			best_distance = distance
	return best if not best.is_empty() else {"id": "", "faction_id": "faction_embercourt"}

static func _zone_resource_requirements(zone: Dictionary) -> Dictionary:
	if _zone_role_is_route_connector(zone):
		return {"minimum_by_category": {}, "density_by_category": {}}
	var metadata: Dictionary = zone.get("catalog_metadata", {}) if zone.get("catalog_metadata", {}) is Dictionary else {}
	var requirements: Dictionary = metadata.get("mine_requirements", {}) if metadata.get("mine_requirements", {}) is Dictionary else {}
	if requirements.is_empty():
		requirements = metadata.get("resource_category_requirements", {}) if metadata.get("resource_category_requirements", {}) is Dictionary else {}
	if requirements.is_empty():
		if String(zone.get("role", "")).contains("start"):
			requirements = {"minimum_by_category": {"timber": 1, "ore": 1}, "density_by_category": {}}
		else:
			requirements = {"minimum_by_category": {}, "density_by_category": {}}
	return requirements

static func _density_extra_count(zone: Dictionary, category_id: String, density: int) -> int:
	if density <= 0:
		return 0
	var role := String(zone.get("role", ""))
	var threshold := 4 if role.contains("start") else 3
	return clampi(int(floor(float(density) / float(threshold))), 0, 2)

static func _mine_anchor_offset(category_id: String, ordinal: int, owned_zone: bool) -> Vector2i:
	var near_bias := category_id in ["timber", "ore"] and owned_zone
	var radius := 3 if near_bias else 5
	var offsets := [Vector2i(radius, 0), Vector2i(0, radius), Vector2i(-radius, 0), Vector2i(0, -radius), Vector2i(radius, radius), Vector2i(-radius, radius), Vector2i(radius, -radius)]
	return offsets[ordinal % offsets.size()]

static func _zone_owner_label(zone: Dictionary) -> String:
	if zone.get("player_slot", null) == null:
		return "neutral"
	var player_type := String(zone.get("player_type", "computer"))
	if player_type == "human" and int(zone.get("player_slot", 0)) == 1:
		return "player"
	return "enemy"

static func _mine_purpose_for_zone(zone: Dictionary, category_id: String, index: int) -> String:
	if String(zone.get("role", "")).contains("start") and category_id in ["timber", "ore"]:
		return "near_start_core_economy_producer"
	if String(zone.get("role", "")).contains("start"):
		return "starting_zone_resource_producer"
	if index == 0:
		return "zone_minimum_resource_producer"
	return "density_resource_producer"

static func _mine_guard_pressure(zone: Dictionary, category_record: Dictionary) -> Dictionary:
	var role := String(zone.get("role", ""))
	var base_value := int(category_record.get("guard_base_value", 0))
	var guarded := not role.contains("start") or base_value >= 3500
	return {
		"guarded": guarded,
		"pressure_class": "unguarded_start_core" if not guarded else _guard_strength_class_from_value(base_value),
		"base_value": base_value,
		"profile_reason": "near_start_wood_ore_bias" if role.contains("start") and String(category_record.get("original_category_id", "")) in ["timber", "ore"] else "category_base_guard_value",
	}

static func _mine_frontier_metadata(zone: Dictionary, category_id: String) -> Dictionary:
	var role := String(zone.get("role", ""))
	var classification := "owned_start_support" if role.contains("start") else "contested_frontier" if role == "treasure" else "neutral_frontier"
	return {
		"classification": classification,
		"contested": role == "treasure",
		"frontier": not role.contains("start"),
		"core_economy": category_id in ["timber", "ore", "gold"],
	}

static func _adjacent_resource_metadata(mine_record: Dictionary, category_id: String) -> Dictionary:
	return {
		"staged": true,
		"resource_object_id": String(mine_record.get("resource_object_id", "")),
		"resource_id": String(mine_record.get("resource_id", "")),
		"original_category_id": category_id,
		"placement_state": "adjacent_resource_metadata_only_until_final_object_writeout",
	}

static func _zone_should_place_dwelling(zone: Dictionary) -> bool:
	if _zone_role_is_route_connector(zone):
		return false
	var role := String(zone.get("role", ""))
	if role == "treasure":
		return true
	return role.contains("start")

static func _zone_role_is_route_connector(zone: Dictionary) -> bool:
	var role := String(zone.get("role", ""))
	return role == "junction" or role.contains("gate") or role.contains("border") or role.contains("connector") or role.contains("crossing")

static func _dwelling_candidate_for_zone(zone: Dictionary) -> Dictionary:
	var biome_id := _biome_for_terrain(String(zone.get("terrain_id", "grass")))
	var fallback := {}
	for candidate in DWELLING_SITE_CANDIDATES:
		if not (candidate is Dictionary):
			continue
		if fallback.is_empty():
			fallback = candidate
		if biome_id in candidate.get("biome_ids", []):
			return candidate
	return fallback

static func _zone_reward_band_context(zone: Dictionary) -> Dictionary:
	var metadata: Dictionary = zone.get("catalog_metadata", {}) if zone.get("catalog_metadata", {}) is Dictionary else {}
	var bands: Array = metadata.get("treasure_bands", [])
	return {
		"band_count": bands.size(),
		"bands": bands,
		"zone_role": String(zone.get("role", "")),
	}

static func _zone_monster_band_context(zone: Dictionary) -> Dictionary:
	var metadata: Dictionary = zone.get("catalog_metadata", {}) if zone.get("catalog_metadata", {}) is Dictionary else {}
	var monster_policy: Dictionary = metadata.get("monster_policy", {}) if metadata.get("monster_policy", {}) is Dictionary else {}
	return {
		"strength": String(monster_policy.get("strength", "avg")),
		"match_to_town": bool(monster_policy.get("match_to_town", false)),
		"allowed_faction_ids": monster_policy.get("allowed_faction_ids", []),
	}

static func _resource_node_from_placement(placement_id: String, payload: Dictionary, point: Dictionary, zone_id: String) -> Dictionary:
	return {
		"placement_id": placement_id,
		"site_id": String(payload.get("site_id", "")),
		"object_id": String(payload.get("object_id", "")),
		"x": int(point.get("x", 0)),
		"y": int(point.get("y", 0)),
		"zone_id": zone_id,
		"owner": String(payload.get("owner", "neutral")),
		"player_slot": int(payload.get("player_slot", 0)),
		"kind": String(payload.get("purpose", "")),
		"generated_kind": String(payload.get("recruitment_site_category", "mine")),
		"original_resource_category_id": String(payload.get("original_resource_category_id", "")),
		"resource_id": String(payload.get("resource_id", "")),
		"neutral_dwelling_family_id": String(payload.get("neutral_dwelling_family_id", "")),
		"guard_pressure": payload.get("guard_pressure", {}),
	}

static func _build_scenario_record(normalized: Dictionary, terrain_rows: Array, placements: Dictionary, constraints: Dictionary) -> Dictionary:
	var metadata := _metadata(normalized)
	var size: Dictionary = normalized.get("size", {})
	var player_constraints: Dictionary = normalized.get("player_constraints", {})
	var profile: Dictionary = normalized.get("profile", {})
	var towns: Array = placements.get("towns", [])
	var start := {"x": 0, "y": 0}
	if not towns.is_empty() and towns[0] is Dictionary:
		start = {"x": int(towns[0].get("x", 0)), "y": int(towns[0].get("y", 0))}
	var scenario_id := "generated_%s_%s" % [String(profile.get("id", "seeded_core")), _hash32_hex(_stable_stringify(metadata))]
	var faction_ids: Array = profile.get("faction_ids", [])
	var victory_objectives := []
	if not towns.is_empty() and towns[0] is Dictionary:
		victory_objectives.append({
			"id": "generated_primary_town_held",
			"type": "town_owned_by_player",
			"placement_id": String(towns[0].get("placement_id", "")),
			"label": "Hold the generated starting town",
			"generated_support": "ScenarioRules.town_owned_by_player",
		})
	return {
		"id": scenario_id,
		"name": "Generated Prototype %s" % String(profile.get("label", "Seeded Core")),
		"generated": true,
		"generated_metadata": metadata,
		"players": normalized.get("player_assignment", {}).get("player_slots", []),
		"team_metadata": normalized.get("player_assignment", {}).get("team_metadata", {}),
		"selection": {
			"summary": "Generated deterministic prototype map for tooling inspection.",
			"recommended_difficulty": "normal",
			"map_size_label": "%dx%d generated" % [int(size.get("width", 0)), int(size.get("height", 0))],
			"player_summary": "%d generated player slots." % int(player_constraints.get("player_count", 0)),
			"enemy_summary": "Generated opponents are staged only; runtime adoption is deferred.",
			"availability": {"campaign": false, "skirmish": false},
		},
		"map_size": {"width": int(size.get("width", 0)), "height": int(size.get("height", 0))},
		"player_faction_id": String(faction_ids[0]) if not faction_ids.is_empty() else "faction_embercourt",
		"player_army_id": "",
		"hero_id": "",
		"starting_resources": {"gold": 1500, "wood": 4, "ore": 3},
		"map": terrain_rows,
		"start": start,
		"hero_starts": [],
		"towns": placements.get("towns", []),
		"resource_nodes": placements.get("resource_nodes", []),
		"artifact_nodes": [],
		"encounters": placements.get("encounters", []),
		"objectives": {
			"victory_text": "Generated prototype objective completed.",
			"defeat_text": "Generated prototype objective failed.",
			"victory": victory_objectives,
			"defeat": [],
		},
		"script_hooks": [],
		"enemy_factions": [],
		"generated_player_assignment": normalized.get("player_assignment", {}),
		"generated_constraints": {
			"zone_layout": constraints.get("zone_layout", {}),
			"terrain": constraints.get("terrain_constraints", {}),
			"terrain_transit": constraints.get("terrain_transit_semantics", {}),
			"connection_guard_materialization": constraints.get("connection_guard_materialization", {}),
			"monster_reward_bands": constraints.get("monster_reward_bands", {}),
			"town_mine_dwelling_placement": constraints.get("town_mine_dwelling_placement", {}),
			"decoration_density_pass": constraints.get("decoration_density_pass", {}),
			"object_footprint_catalog": constraints.get("object_footprint_catalog", {}),
			"roads_rivers_writeout": constraints.get("roads_rivers_writeout", {}),
			"town_starts": constraints.get("town_start_constraints", {}),
			"roads": constraints.get("road_network", {}),
			"reachability": constraints.get("route_reachability_proof", {}),
			"fairness": constraints.get("fairness_report", {}),
		},
	}

static func _build_terrain_layers_record(normalized: Dictionary, constraints: Dictionary) -> Dictionary:
	var profile: Dictionary = normalized.get("profile", {})
	var metadata := _metadata(normalized)
	var road_network: Dictionary = constraints.get("road_network", {})
	var terrain_transit: Dictionary = constraints.get("terrain_transit_semantics", {})
	return {
		"id": "generated_layers_%s_%s" % [String(profile.get("id", "seeded_core")), _hash32_hex(_stable_stringify(metadata))],
		"terrain_layer_status": "generated_staged_draft",
		"generated_metadata": metadata,
		"terrain_semantics": terrain_transit,
		"terrain_layers": terrain_transit.get("terrain_layers", []),
		"water_coast_passability": terrain_transit.get("water_coast_passability", {}),
		"transit_routes": terrain_transit.get("transit_routes", {}),
		"roads": road_network.get("road_segments", []),
		"road_stubs": road_network.get("road_stubs", []),
		"overlay_layers": constraints.get("roads_rivers_writeout", {}).get("generated_map_serialization", {}).get("overlay_layers", []),
		"route_graph_stub": constraints.get("route_graph", {}),
		"deferred": _unique_sorted_strings(["authored_terrain_json_writeback", "campaign_skirmish_save_adoption"] + constraints.get("roads_rivers_writeout", {}).get("deferred", []) + terrain_transit.get("unsupported_deferred", [])),
	}

static func _build_staging_payload(normalized: Dictionary, template: Dictionary, zones: Array, seeds: Dictionary, zone_grid: Array, placements: Dictionary, constraints: Dictionary, zone_layout: Dictionary) -> Dictionary:
	return {
		"staging_schema": "random_map_generation_staging_v1",
		"template": template,
		"zones": _zones_for_payload(zones),
		"zone_layout": zone_layout,
		"player_assignment": normalized.get("player_assignment", {}),
		"zone_seed_points": _sorted_point_dict(seeds),
		"terrain_owner_grid": zone_grid,
		"terrain_constraints": constraints.get("terrain_constraints", {}),
		"terrain_transit_semantics": constraints.get("terrain_transit_semantics", {}),
		"connection_guard_materialization": constraints.get("connection_guard_materialization", {}),
		"monster_reward_bands": constraints.get("monster_reward_bands", {}),
		"town_mine_dwelling_placement": constraints.get("town_mine_dwelling_placement", {}),
		"decoration_density_pass": constraints.get("decoration_density_pass", {}),
		"object_footprint_catalog": constraints.get("object_footprint_catalog", {}),
		"decorative_object_staging": constraints.get("decoration_density_pass", {}).get("decoration_records", []),
		"roads_rivers_writeout": constraints.get("roads_rivers_writeout", {}),
		"town_start_constraints": constraints.get("town_start_constraints", {}),
		"road_network": constraints.get("road_network", {}),
		"route_reachability_proof": constraints.get("route_reachability_proof", {}),
		"route_graph": constraints.get("route_graph", _route_graph_payload(template.get("links", []), seeds)),
		"fairness_report": constraints.get("fairness_report", {}),
		"object_placements": placements.get("object_placements", []),
		"metadata": _metadata(normalized),
		"editable_grid_model": "terrain_owner_grid_rows_plus_separate_object_placement_arrays",
		"terrain_owner_grid_source": "zone_layout_surface_owner_grid",
	}

static func _build_constraint_payload(normalized: Dictionary, zones: Array, links: Array, seeds: Dictionary, zone_grid: Array, terrain_rows: Array, placements: Dictionary, zone_layout: Dictionary, terrain_transit: Dictionary) -> Dictionary:
	var terrain_constraints := _terrain_constraints_payload(terrain_rows, zone_grid, zones, terrain_transit)
	var occupied := _occupied_body_lookup(placements.get("object_placements", []))
	var route_build := _build_route_and_road_payload(links, seeds, placements, terrain_rows, occupied, terrain_transit)
	var route_graph: Dictionary = route_build.get("route_graph", _route_graph_payload(links, seeds))
	var connection_guard_materialization := _build_connection_guard_materialization(
		links,
		route_graph,
		route_build.get("road_network", {}),
		placements,
		terrain_transit
	)
	route_graph["connection_guard_materialization"] = connection_guard_materialization
	route_graph["connection_guard_materialization_summary"] = connection_guard_materialization.get("summary", {})
	var monster_reward_bands := _build_monster_reward_bands(normalized, zones, connection_guard_materialization, route_graph, placements, terrain_transit)
	route_graph["monster_reward_bands"] = monster_reward_bands
	route_graph["monster_reward_bands_summary"] = monster_reward_bands.get("summary", {})
	var town_mine_dwelling := _build_town_mine_dwelling_placement_payload(
		normalized,
		zones,
		placements,
		terrain_rows,
		route_graph,
		route_build.get("road_network", {}),
		{}
	)
	var decoration_density := _build_decoration_density_pass(
		normalized,
		zones,
		zone_layout,
		terrain_rows,
		placements,
		terrain_transit,
		route_graph,
		route_build.get("road_network", {}),
		route_build.get("route_reachability_proof", {}),
		monster_reward_bands
	)
	var object_footprints := _build_object_footprint_payload(normalized, placements, decoration_density, monster_reward_bands, terrain_rows, route_graph, route_build.get("road_network", {}), route_build.get("route_reachability_proof", {}))
	var roads_rivers_writeout := _build_roads_rivers_writeout_payload(
		normalized,
		terrain_rows,
		zone_layout,
		terrain_transit,
		route_build.get("road_network", {}),
		route_graph,
		object_footprints,
		placements
	)
	var town_start_constraints := _town_start_constraints_payload(zones, placements, route_graph, route_build.get("route_reachability_proof", {}))
	town_mine_dwelling = _build_town_mine_dwelling_placement_payload(
		normalized,
		zones,
		placements,
		terrain_rows,
		route_graph,
		route_build.get("road_network", {}),
		decoration_density
	)
	var fairness_report := _fairness_report_payload(normalized, zones, placements, route_graph, route_build.get("route_reachability_proof", {}), {}, town_mine_dwelling)
	return {
		"zone_layout": zone_layout,
		"terrain_constraints": terrain_constraints,
		"terrain_transit_semantics": terrain_transit,
		"connection_guard_materialization": connection_guard_materialization,
		"monster_reward_bands": monster_reward_bands,
		"town_mine_dwelling_placement": town_mine_dwelling,
		"decoration_density_pass": decoration_density,
		"object_footprint_catalog": object_footprints,
		"roads_rivers_writeout": roads_rivers_writeout,
		"town_start_constraints": town_start_constraints,
		"road_network": route_build.get("road_network", {}),
		"route_graph": route_graph,
		"route_reachability_proof": route_build.get("route_reachability_proof", {}),
		"fairness_report": fairness_report,
		"metadata": _metadata(normalized),
	}

static func _build_connection_guard_materialization(links: Array, route_graph: Dictionary, road_network: Dictionary, placements: Dictionary, terrain_transit: Dictionary) -> Dictionary:
	var edges_by_id := {}
	for edge in route_graph.get("edges", []):
		if edge is Dictionary:
			edges_by_id[String(edge.get("id", ""))] = edge
	var placements_by_route := _placements_by_route_edge(placements.get("object_placements", []))
	var road_cells_by_route := _road_cells_by_route_edge(road_network.get("road_segments", []))
	var normal_route_guards := []
	var wide_suppressions := []
	var special_guards := []
	var diagnostics := []
	var expected_normal_guard_count := 0
	var expected_wide_suppression_count := 0
	var expected_special_guard_count := 0
	for index in range(links.size()):
		var link = links[index]
		if not (link is Dictionary):
			diagnostics.append(_connection_guard_diagnostic("link_%02d" % (index + 1), "", "", "invalid_link_payload", true, "template link is not a dictionary"))
			continue
		var from_zone := String(link.get("from", ""))
		var to_zone := String(link.get("to", ""))
		var edge_id := _route_edge_id(index + 1, from_zone, to_zone)
		var edge: Dictionary = edges_by_id.get(edge_id, {})
		var source_link := _connection_guard_source_link(edge_id, index + 1, link, edge)
		if edge.is_empty():
			diagnostics.append(_connection_guard_diagnostic(edge_id, from_zone, to_zone, "route_edge_missing", false, "template link did not produce a route graph edge"))
			continue
		var transit_semantics: Dictionary = edge.get("transit_semantics", _transit_semantics_for_surface_link(link, terrain_transit))
		var anchor_candidate: Dictionary = edge.get("route_cell_anchor_candidate", {})
		if anchor_candidate.is_empty():
			anchor_candidate = _route_anchor_candidate(road_cells_by_route.get(edge_id, []), edge.get("from_anchor", {}), edge.get("to_anchor", {}))
		if not bool(edge.get("path_found", false)):
			diagnostics.append(_connection_guard_diagnostic(edge_id, from_zone, to_zone, "route_path_missing", true, "route graph edge has no passable path for guard placement"))
		if bool(link.get("wide", false)):
			expected_wide_suppression_count += 1
			var suppression_id := "conn_guard_%02d_wide_suppression" % (index + 1)
			var suppression := {
				"id": suppression_id,
				"record_type": "wide_normal_guard_suppression",
				"source_link": source_link,
				"route_edge_id": edge_id,
				"from": from_zone,
				"to": to_zone,
				"role": String(link.get("role", "")),
				"guard_value": int(link.get("guard_value", 0)),
				"normal_guard_materialized": false,
				"suppression_reason": "wide_link_suppresses_normal_guard_materialization",
				"wide_semantics": link.get("special_payload", {}),
				"route_classification": String(edge.get("connectivity_classification", "")),
				"route_cell_anchor_candidate": anchor_candidate,
				"transit_semantics": transit_semantics,
				"materialization_state": "wide_connection_preserved_normal_guard_not_materialized",
			}
			_attach_materialization_id_to_edge(edge, suppression_id)
			wide_suppressions.append(suppression)
			continue
		if bool(link.get("border_guard", false)):
			expected_special_guard_count += 1
			var special_id := "conn_guard_%02d_special_gate" % (index + 1)
			var special_placement := _placement_candidate_for_route(placements_by_route.get(edge_id, []), "special_guard_gate")
			var special_record := {
				"id": special_id,
				"record_type": "special_guard_gate",
				"source_link": source_link,
				"route_edge_id": edge_id,
				"from": from_zone,
				"to": to_zone,
				"role": String(link.get("role", "")),
				"guard_value": int(link.get("guard_value", 0)),
				"normal_guard_materialized": false,
				"special_guard_materialized": true,
				"special_guard_type": "border_guard_gate_placeholder",
				"payload_semantics": link.get("special_payload", {}),
				"required_unlock_metadata": {
					"unlock_required": true,
					"unlock_model": "border_guard_gate_or_key_placeholder",
					"subtype_placeholder": index % 8,
					"key_or_unlock_object_materialization": "deferred_to_monster_reward_bands_or_transit_slice",
				},
				"route_classification": String(edge.get("connectivity_classification", "")),
				"route_cell_anchor_candidate": anchor_candidate,
				"placement_candidate": special_placement,
				"transit_semantics": transit_semantics,
				"materialization_state": "staged_special_gate_placeholder_no_final_object_writeout",
				"downstream_consumer": "random-map-monster-reward-bands-10184",
			}
			_attach_materialization_id_to_edge(edge, special_id)
			special_guards.append(special_record)
			if anchor_candidate.is_empty():
				diagnostics.append(_connection_guard_diagnostic(edge_id, from_zone, to_zone, "special_guard_anchor_missing", true, "border/special guard could not resolve a route anchor candidate"))
			continue
		var guard_value := int(link.get("guard_value", 0))
		if guard_value <= 0:
			continue
		expected_normal_guard_count += 1
		var normal_id := "conn_guard_%02d_normal" % (index + 1)
		var normal_placement := _placement_candidate_for_route(placements_by_route.get(edge_id, []), "route_guard")
		var normal_record := {
			"id": normal_id,
			"record_type": "normal_route_guard",
			"source_link": source_link,
			"route_edge_id": edge_id,
			"from": from_zone,
			"to": to_zone,
			"role": String(link.get("role", "")),
			"guard_value": guard_value,
			"effective_guard_pressure": _effective_guard_pressure(edge),
			"normal_guard_materialized": true,
			"route_classification": String(edge.get("connectivity_classification", "")),
			"route_cell_anchor_candidate": anchor_candidate,
			"placement_candidate": normal_placement,
			"monster_category_placeholder": {
				"state": "downstream_monster_selection_pending",
				"category": "connection_route_guard",
				"strength_source": "template_link_guard_value",
			},
			"reward_category_placeholder": {
				"state": "downstream_reward_selection_pending",
				"category": "guarded_route_reward_context",
			},
			"transit_semantics": transit_semantics,
			"materialization_state": "staged_normal_guard_placeholder",
			"downstream_consumer": "random-map-monster-reward-bands-10184",
		}
		_attach_materialization_id_to_edge(edge, normal_id)
		normal_route_guards.append(normal_record)
		if anchor_candidate.is_empty():
			diagnostics.append(_connection_guard_diagnostic(edge_id, from_zone, to_zone, "normal_guard_anchor_missing", true, "normal guard could not resolve a route anchor candidate"))
	var materialized_records := normal_route_guards + special_guards
	var payload := {
		"schema_id": CONNECTION_GUARD_MATERIALIZATION_SCHEMA_ID,
		"status": "warning" if not diagnostics.is_empty() else "pass",
		"materialization_policy": "normal_guards_and_special_gate_placeholders_staged_no_final_monster_reward_selection",
		"connection_payload_semantics": route_graph.get("connection_payload_semantics", {}),
		"normal_route_guards": normal_route_guards,
		"special_guard_gates": special_guards,
		"wide_suppressions": wide_suppressions,
		"materialized_records": materialized_records,
		"diagnostics": diagnostics,
		"summary": {
			"expected_normal_guard_count": expected_normal_guard_count,
			"expected_special_guard_gate_count": expected_special_guard_count,
			"expected_wide_suppression_count": expected_wide_suppression_count,
			"normal_guard_count": normal_route_guards.size(),
			"special_guard_gate_count": special_guards.size(),
			"wide_suppression_count": wide_suppressions.size(),
			"materialized_record_count": materialized_records.size(),
			"diagnostic_count": diagnostics.size(),
		},
		"deferred": [
			"final_monster_stack_selection",
			"reward_band_selection",
			"durable_object_writeout",
			"skirmish_ui_save_replay_adoption",
		],
	}
	payload["connection_guard_materialization_signature"] = _hash32_hex(_stable_stringify({
		"normal_route_guards": normal_route_guards,
		"special_guard_gates": special_guards,
		"wide_suppressions": wide_suppressions,
		"diagnostics": diagnostics,
	}))
	return payload

static func _build_monster_reward_bands(normalized: Dictionary, zones: Array, materialization: Dictionary, route_graph: Dictionary, placements: Dictionary, terrain_transit: Dictionary) -> Dictionary:
	var zones_by_id := _zones_by_id(zones)
	var edges_by_id := _route_edges_by_id(route_graph.get("edges", []))
	var diagnostics := []
	var guard_stack_records := []
	var reward_band_records := []
	var records := []
	for guard_record in materialization.get("materialized_records", []):
		if not (guard_record is Dictionary):
			diagnostics.append(_monster_reward_diagnostic("", "", "invalid_materialized_guard_record", "connection guard materialization record is not a dictionary"))
			continue
		var route_edge_id := String(guard_record.get("route_edge_id", ""))
		var edge: Dictionary = edges_by_id.get(route_edge_id, {})
		if edge.is_empty():
			diagnostics.append(_monster_reward_diagnostic(String(guard_record.get("id", "")), route_edge_id, "missing_route_edge", "guard record could not be matched to a route edge"))
		var zone_context := _monster_reward_zone_context(guard_record, edge, zones_by_id)
		var guard_stack := _guard_stack_record_for_materialized_guard(normalized, guard_record, edge, zone_context, diagnostics)
		var reward_band := _reward_band_record_for_materialized_guard(normalized, guard_record, edge, zone_context, guard_stack, diagnostics)
		var category_links := _guard_reward_category_links(zone_context, guard_stack, reward_band)
		var record_id := "monster_reward_%s" % String(guard_record.get("id", "record"))
		var record := {
			"id": record_id,
			"connection_guard_materialization_id": String(guard_record.get("id", "")),
			"route_edge_id": route_edge_id,
			"record_type": "monster_reward_band",
			"guard_record_type": String(guard_record.get("record_type", "")),
			"source_materialization_state": String(guard_record.get("materialization_state", "")),
			"zone_context": zone_context,
			"guard_stack_record": guard_stack,
			"reward_band_record": reward_band,
			"seven_category_links": category_links,
			"special_unlock_semantics": _special_unlock_semantics_for_guard(guard_record, reward_band),
			"terrain_context": _monster_reward_terrain_context(edge, terrain_transit, zone_context),
			"scenario_reference_policy": "records_are_referenced_by_route_edges_object_placements_encounters_and_generated_constraints",
			"writeout_state": "structured_staged_records_no_final_object_or_save_writeout",
		}
		guard_stack_records.append(guard_stack)
		reward_band_records.append(reward_band)
		records.append(record)
		_attach_monster_reward_id_to_edge(edge, record_id)
		guard_record["monster_reward_band_ids"] = [record_id]
		guard_record["guard_stack_record_id"] = String(guard_stack.get("id", ""))
		guard_record["reward_band_record_id"] = String(reward_band.get("id", ""))
	_annotate_monster_reward_references(records, placements)
	var seven_categories := _seven_category_semantics_payload(zones, records)
	var status := "pass"
	if records.is_empty() and int(materialization.get("summary", {}).get("materialized_record_count", 0)) > 0:
		status = "fail"
	elif not diagnostics.is_empty():
		status = "warning"
	var payload := {
		"schema_id": MONSTER_REWARD_BANDS_SCHEMA_ID,
		"status": status,
		"selection_policy": "deterministic_original_guard_stack_and_reward_band_records_from_connection_materialization",
		"strength_policy": "route_guard_value_plus_local_and_global_monster_strength_modes_preserved_as_explicit_fields",
		"reward_policy": "eligible_template_treasure_bands_first_route_context_fallback_when_unavailable",
		"monster_reward_records": records,
		"guard_stack_records": guard_stack_records,
		"reward_band_records": reward_band_records,
		"seven_category_semantics": seven_categories,
		"wide_suppression_context": {
			"wide_suppression_count": materialization.get("wide_suppressions", []).size(),
			"wide_suppressions": materialization.get("wide_suppressions", []),
			"policy": "wide_connections_preserve_category_context_but_do_not_create_normal_guard_stack_records",
		},
		"diagnostics": diagnostics,
		"summary": {
			"record_count": records.size(),
			"guard_stack_count": guard_stack_records.size(),
			"reward_band_count": reward_band_records.size(),
			"normal_guard_record_count": _count_monster_reward_records_by_guard_type(records, "normal_route_guard"),
			"special_guard_record_count": _count_monster_reward_records_by_guard_type(records, "special_guard_gate"),
			"seven_category_zone_count": seven_categories.get("zones", []).size(),
			"diagnostic_count": diagnostics.size(),
		},
		"deferred": [
			"final_guard_object_stack_writeout",
			"final_reward_object_placement",
			"artifact_spell_skill_reward_pool_finalization",
			"mine_placement_from_seven_category_requirements",
			"skirmish_ui_save_replay_adoption",
		],
	}
	payload["monster_reward_bands_signature"] = _hash32_hex(_stable_stringify({
		"monster_reward_records": records,
		"seven_category_semantics": seven_categories,
		"diagnostics": diagnostics,
	}))
	return payload

static func _build_decoration_density_pass(normalized: Dictionary, zones: Array, zone_layout: Dictionary, terrain_rows: Array, placements: Dictionary, terrain_transit: Dictionary, route_graph: Dictionary, road_network: Dictionary, reachability: Dictionary, monster_reward_bands: Dictionary) -> Dictionary:
	var occupied := _occupied_body_lookup(placements.get("object_placements", []))
	var exclusion := _decoration_exclusion_lookup(placements, route_graph, road_network, zone_layout, monster_reward_bands)
	var footprints_by_zone := _surface_footprints_by_zone(zone_layout)
	var reward_context_by_zone := _monster_reward_context_by_zone(monster_reward_bands)
	var zone_targets := []
	var records := []
	var diagnostics := []
	var staged_occupied := occupied.duplicate()
	var seed_text := String(normalized.get("seed", ""))
	for zone in zones:
		if not (zone is Dictionary):
			continue
		var zone_id := String(zone.get("id", ""))
		var footprint: Dictionary = footprints_by_zone.get(zone_id, {})
		var cells: Array = footprint.get("cells", [])
		var terrain_id := String(zone.get("terrain_id", "grass"))
		var biome_id := _biome_for_terrain(terrain_id)
		var reward_context: Dictionary = reward_context_by_zone.get(zone_id, {})
		var raw_target := _decoration_density_target(zone, cells.size(), terrain_id, reward_context)
		var candidates := _decoration_candidates_for_zone(zone_id, cells, terrain_rows, occupied, exclusion, terrain_id, biome_id, seed_text)
		var effective_target: int = min(raw_target, candidates.size())
		var tolerance: int = _decoration_density_tolerance(raw_target)
		var selected := []
		var cursor := 0
		while selected.size() < effective_target and cursor < candidates.size():
			var candidate: Dictionary = candidates[cursor]
			cursor += 1
			var key := _point_key(int(candidate.get("x", 0)), int(candidate.get("y", 0)))
			if staged_occupied.has(key):
				continue
			var family: Dictionary = _decoration_family_for_cell(terrain_id, biome_id, seed_text, zone_id, int(candidate.get("x", 0)), int(candidate.get("y", 0)), selected.size())
			if family.is_empty():
				diagnostics.append(_decoration_diagnostic(zone_id, "missing_family", "no terrain-biased original decoration family resolved for %s" % terrain_id, true))
				continue
			var record_id := "decor_%s_%03d" % [zone_id, records.size() + 1]
			var point := _point_dict(int(candidate.get("x", 0)), int(candidate.get("y", 0)))
			var record := {
				"id": record_id,
				"placement_id": record_id,
				"kind": "decorative_obstacle",
				"zone_id": zone_id,
				"x": int(point.get("x", 0)),
				"y": int(point.get("y", 0)),
				"body_tiles": [point],
				"blocking_body": bool(family.get("blocks_movement", true)),
				"visit_tile": {},
				"approach_tiles": [],
				"family_id": String(family.get("family_id", "")),
				"display_name": String(family.get("display_name", "")),
				"family_role": String(family.get("role", "")),
				"terrain_id": terrain_id,
				"biome_id": biome_id,
				"terrain_bias": {
					"terrain_ids": family.get("terrain_ids", []),
					"biome_ids": family.get("biome_ids", []),
					"selected_from_known_original_family_ids": true,
				},
				"density_context": {
					"zone_base_size": int(zone.get("base_size", 0)),
					"zone_role": String(zone.get("role", "")),
					"target": raw_target,
					"effective_target": effective_target,
					"reward_context": reward_context,
				},
				"placement_scores": candidate.get("scores", {}),
				"exclusion_policy": "excluded_from_towns_resources_guards_rewards_roads_corridor_required_cells_and_existing_object_bodies",
				"path_safety_state": "validated_after_staging",
				"writeout_state": "staged_decoration_record_no_final_object_sprite_or_map_writeout",
			}
			_apply_object_footprint_metadata(record, terrain_rows, staged_occupied)
			records.append(record)
			selected.append(record)
			if bool(family.get("blocks_movement", true)):
				staged_occupied[key] = record_id
		if selected.size() < effective_target:
			diagnostics.append(_decoration_diagnostic(zone_id, "density_target_underfilled", "zone selected %d of effective target %d" % [selected.size(), effective_target], true))
		zone_targets.append({
			"zone_id": zone_id,
			"role": String(zone.get("role", "")),
			"terrain_id": terrain_id,
			"biome_id": biome_id,
			"base_size": int(zone.get("base_size", 0)),
			"footprint_cell_count": cells.size(),
			"eligible_cell_count": candidates.size(),
			"raw_target": raw_target,
			"effective_target": effective_target,
			"placed_count": selected.size(),
			"tolerance": tolerance,
			"within_tolerance": abs(selected.size() - effective_target) <= tolerance,
			"capacity_limited": raw_target > candidates.size(),
			"monster_reward_context": reward_context,
			"family_ids_selected": _decoration_family_ids(selected),
		})
	var path_validation := _decoration_path_safety_validation(records, route_graph, terrain_rows, occupied, reachability)
	var density_validation := _decoration_density_target_validation(zone_targets)
	var status := "pass"
	if not bool(path_validation.get("ok", false)) or not bool(density_validation.get("ok", false)):
		status = "fail"
	elif not diagnostics.is_empty():
		status = "warning"
	var payload := {
		"schema_id": DECORATION_DENSITY_PASS_SCHEMA_ID,
		"status": status,
		"placement_policy": "terrain_biome_biased_obstacle_filler_after_major_objects_guards_rewards_and_roads",
		"density_policy": "zone_base_size_role_terrain_and_monster_reward_context_targets_with_capacity_adjustment",
		"known_original_family_ids": _decoration_known_family_ids(),
		"family_catalog": DECORATION_OBJECT_FAMILIES,
		"zone_density_targets": zone_targets,
		"decoration_records": records,
		"exclusion_summary": {
			"excluded_cell_count": exclusion.size(),
			"excluded_sources": ["existing_object_bodies", "existing_object_approaches", "towns", "resources", "route_guards", "special_guards", "reward_route_anchors", "roads", "corridor_required_cells"],
		},
		"path_safety_validation": path_validation,
		"density_validation": density_validation,
		"terrain_transit_signature": String(terrain_transit.get("terrain_transit_signature", "")),
		"route_reachability_status_before_decoration": String(reachability.get("status", "")),
		"monster_reward_bands_signature": String(monster_reward_bands.get("monster_reward_bands_signature", "")),
		"diagnostics": diagnostics,
		"summary": {
			"zone_count": zone_targets.size(),
			"record_count": records.size(),
			"raw_target_total": _decoration_sum_zone_targets(zone_targets, "raw_target"),
			"effective_target_total": _decoration_sum_zone_targets(zone_targets, "effective_target"),
			"placed_total": _decoration_sum_zone_targets(zone_targets, "placed_count"),
			"density_target_failures": density_validation.get("failures", []).size(),
			"path_safety_status": String(path_validation.get("status", "")),
			"diagnostic_count": diagnostics.size(),
		},
		"deferred": [
			"final_object_footprint_catalog_writeout",
			"renderer_art_asset_selection",
			"terrain_adjacency_overlap_score_tables",
			"durable_map_serialization",
			"skirmish_ui_save_replay_adoption",
		],
	}
	payload["decoration_density_signature"] = _hash32_hex(_stable_stringify({
		"zone_density_targets": zone_targets,
		"decoration_records": records,
		"path_safety_validation": path_validation,
		"density_validation": density_validation,
		"diagnostics": diagnostics,
	}))
	return payload

static func _build_object_footprint_payload(normalized: Dictionary, placements: Dictionary, decoration_density: Dictionary, monster_reward_bands: Dictionary, terrain_rows: Array, route_graph: Dictionary, road_network: Dictionary, reachability: Dictionary) -> Dictionary:
	var object_records := []
	for placement in placements.get("object_placements", []):
		if placement is Dictionary:
			object_records.append(placement)
	for record in decoration_density.get("decoration_records", []):
		if record is Dictionary:
			object_records.append(record)
	var reward_reference_records := []
	for reward in monster_reward_bands.get("reward_band_records", []):
		if not (reward is Dictionary):
			continue
		var catalog_ref: Dictionary = reward.get("object_footprint_catalog_ref", {}) if reward.get("object_footprint_catalog_ref", {}) is Dictionary else _object_footprint_ref_for_reward_candidate({
			"object_id": String(reward.get("selected_reward_object_id", "")),
			"object_family_id": String(reward.get("selected_reward_family_id", "")),
		})
		reward["object_footprint_catalog_ref"] = catalog_ref
		reward_reference_records.append({
			"id": String(reward.get("id", "")),
			"route_edge_id": String(reward.get("route_edge_id", "")),
			"selected_reward_object_id": String(reward.get("selected_reward_object_id", "")),
			"selected_reward_family_id": String(reward.get("selected_reward_family_id", "")),
			"object_footprint_catalog_ref": catalog_ref,
			"placement_state": "reward_reference_only_body_placement_deferred",
			"deferred_reason": String(catalog_ref.get("deferred_runtime_application", "reward_object_body_placement_deferred_to_reward_materialization_slice")),
		})
	var validation := _object_footprint_validation_core(object_records, reward_reference_records, terrain_rows, route_graph, road_network, reachability)
	var status := "pass" if bool(validation.get("ok", false)) else "fail"
	var catalog_payload := _object_footprint_catalog_payload()
	var payload := {
		"schema_id": OBJECT_FOOTPRINT_CATALOG_SCHEMA_ID,
		"status": status,
		"identity_context": {
			"generator_version": String(normalized.get("generator_version", GENERATOR_VERSION)),
			"seed": String(normalized.get("seed", "")),
			"template_id": String(normalized.get("template_id", "")),
		},
		"catalog": catalog_payload,
		"object_records": object_records,
		"reward_reference_records": reward_reference_records,
		"validation": validation,
		"coverage": {
			"object_placement_count": placements.get("object_placements", []).size(),
			"decoration_record_count": decoration_density.get("decoration_records", []).size(),
			"reward_reference_count": reward_reference_records.size(),
			"catalog_record_count": catalog_payload.get("records", []).size(),
			"deferred_multitile_record_count": _object_footprint_deferred_record_count(object_records),
		},
		"writeout_state": "structured_footprint_action_passability_metadata_only_no_final_object_definition_or_map_writeout",
		"deferred": [
			"full_multitile_body_stamping_for_large_towns_and_mines",
			"final_object_definition_instance_serialization",
			"renderer_art_asset_selection",
			"skirmish_ui_save_replay_adoption",
		],
		"summary": {
			"object_record_count": object_records.size(),
			"reward_reference_count": reward_reference_records.size(),
			"catalog_record_count": catalog_payload.get("records", []).size(),
			"missing_catalog_count": validation.get("missing_catalog_ids", []).size(),
			"body_overlap_count": validation.get("body_overlap_failures", []).size(),
			"required_route_check_status": String(validation.get("required_route_check_status", "")),
			"terrain_restriction_failure_count": validation.get("terrain_restriction_failures", []).size(),
			"deferred_multitile_record_count": _object_footprint_deferred_record_count(object_records),
		},
	}
	payload["object_footprint_signature"] = _hash32_hex(_stable_stringify({
		"identity_context": payload.get("identity_context", {}),
		"object_records": object_records,
		"reward_reference_records": reward_reference_records,
		"validation": validation,
	}))
	return payload

static func _object_footprint_catalog_payload() -> Dictionary:
	return {
		"schema_id": OBJECT_FOOTPRINT_CATALOG_SCHEMA_ID,
		"source_model": "original_rmg_object_metadata_translated_from_footprint_action_passability_evidence",
		"records": OBJECT_FOOTPRINT_CATALOG,
		"generated_placement_kinds": _object_footprint_generated_placement_kinds(),
		"decoration_family_ids": _decoration_known_family_ids(),
		"resource_category_placeholders": ORIGINAL_RESOURCE_CATEGORY_ORDER,
		"runtime_policy": {
			"current_body_application": "catalog_runtime_body_mask_used_for_collision_and_pathing",
			"large_multitile_bodies": "catalog_body_mask_preserved_intended_body_runtime_application_deferred_where_not_safe_to_stamp_yet",
			"writeout": "no_final_object_definition_or_instance_serialization_in_this_slice",
		},
	}

static func _object_footprint_generated_placement_kinds() -> Array:
	var result := []
	for record in OBJECT_FOOTPRINT_CATALOG:
		if not (record is Dictionary):
			continue
		for kind in record.get("placement_kinds", []):
			if String(kind) not in result:
				result.append(String(kind))
	result.sort()
	return result

static func _apply_object_footprint_metadata(record: Dictionary, terrain_rows: Array, occupied: Dictionary = {}) -> void:
	var catalog := _object_footprint_catalog_record_for_placement(record)
	var point := _point_dict(int(record.get("x", 0)), int(record.get("y", 0)))
	if catalog.is_empty():
		record["object_footprint_catalog_ref"] = {
			"status": "deferred_missing_catalog_record",
			"reason": "no_catalog_match_for_generated_object_record",
			"placement_kind": String(record.get("kind", "")),
			"family_id": String(record.get("family_id", "")),
			"object_id": _object_record_content_id(record),
		}
		record["footprint_deferred"] = {"reason": "missing_catalog_record", "structured_deferred_reason": true}
		return
	var body_tiles := _runtime_body_tiles_for_catalog(point, catalog)
	var terrain_id := String(record.get("terrain_id", ""))
	if terrain_id == "" and _point_in_rows(terrain_rows, int(point.get("x", 0)), int(point.get("y", 0))):
		terrain_id = String(terrain_rows[int(point.get("y", 0))][int(point.get("x", 0))])
	var deferred_reason := String(catalog.get("deferred_runtime_application", ""))
	record["object_footprint_catalog_ref"] = {
		"catalog_id": String(catalog.get("id", "")),
		"family_id": String(catalog.get("family_id", "")),
		"status": "catalog_record_applied",
		"deferred_runtime_application": deferred_reason,
	}
	record["footprint"] = catalog.get("footprint", {})
	record["runtime_footprint"] = catalog.get("runtime_footprint", catalog.get("footprint", {}))
	record["body_mask"] = catalog.get("body_mask", [])
	record["runtime_body_mask"] = catalog.get("runtime_body_mask", catalog.get("body_mask", []))
	record["catalog_body_tiles"] = _relative_mask_to_tiles(point, catalog.get("body_mask", []))
	record["body_tiles"] = body_tiles
	record["visit_mask"] = catalog.get("visit_mask", [])
	record["approach_mask"] = catalog.get("approach_mask", [])
	record["passability_mask"] = catalog.get("passability_mask", {})
	record["action_mask"] = catalog.get("action_mask", {})
	record["terrain_restrictions"] = catalog.get("terrain_restrictions", {})
	record["placement_predicates"] = catalog.get("placement_predicates", [])
	record["placement_predicate_results"] = _placement_predicate_results(record, catalog, terrain_rows, occupied)
	if deferred_reason != "":
		record["footprint_deferred"] = {
			"reason": deferred_reason,
			"catalog_body_tile_count": record.get("catalog_body_tiles", []).size(),
			"runtime_body_tile_count": body_tiles.size(),
			"structured_deferred_reason": true,
		}

static func _object_footprint_catalog_record_for_placement(record: Dictionary) -> Dictionary:
	var kind := String(record.get("kind", ""))
	var object_id := _object_record_content_id(record)
	var family_id := String(record.get("family_id", record.get("selected_reward_family_id", "")))
	for catalog in OBJECT_FOOTPRINT_CATALOG:
		if not (catalog is Dictionary):
			continue
		if kind != "" and kind in catalog.get("placement_kinds", []):
			if _catalog_matches_object_or_family(catalog, object_id, family_id):
				return catalog
			if object_id == "" and family_id == "":
				return catalog
	for catalog in OBJECT_FOOTPRINT_CATALOG:
		if not (catalog is Dictionary):
			continue
		if family_id != "" and family_id in catalog.get("family_ids", []):
			return catalog
		if object_id != "" and object_id in catalog.get("object_ids", []):
			return catalog
	return {}

static func _catalog_matches_object_or_family(catalog: Dictionary, object_id: String, family_id: String) -> bool:
	if object_id == "" and family_id == "":
		return true
	if object_id != "" and object_id in catalog.get("object_ids", []):
		return true
	if family_id != "" and (family_id == String(catalog.get("family_id", "")) or family_id in catalog.get("family_ids", [])):
		return true
	return false

static func _object_record_content_id(record: Dictionary) -> String:
	for key in ["town_id", "site_id", "encounter_id", "special_guard_type", "selected_reward_object_id", "object_id"]:
		if String(record.get(key, "")) != "":
			return String(record.get(key, ""))
	return ""

static func _object_footprint_ref_for_reward_candidate(candidate: Dictionary) -> Dictionary:
	var probe := {
		"kind": "reward_reference",
		"selected_reward_object_id": String(candidate.get("object_id", "")),
		"selected_reward_family_id": String(candidate.get("object_family_id", "")),
	}
	var catalog := _object_footprint_catalog_record_for_placement(probe)
	if catalog.is_empty():
		return {
			"status": "deferred_missing_catalog_record",
			"reason": "reward_candidate_has_no_catalog_match",
			"object_id": String(candidate.get("object_id", "")),
			"family_id": String(candidate.get("object_family_id", "")),
		}
	return {
		"catalog_id": String(catalog.get("id", "")),
		"family_id": String(catalog.get("family_id", "")),
		"status": "catalog_record_applied",
		"deferred_runtime_application": String(catalog.get("deferred_runtime_application", "")),
	}

static func _runtime_body_tiles_for_catalog(point: Dictionary, catalog: Dictionary) -> Array:
	if catalog.is_empty():
		return [point]
	return _relative_mask_to_tiles(point, catalog.get("runtime_body_mask", catalog.get("body_mask", [{"x": 0, "y": 0}])))

static func _relative_mask_to_tiles(point: Dictionary, mask: Array) -> Array:
	var result := []
	var anchor_x := int(point.get("x", 0))
	var anchor_y := int(point.get("y", 0))
	for offset in mask:
		if offset is Dictionary:
			result.append(_point_dict(anchor_x + int(offset.get("x", 0)), anchor_y + int(offset.get("y", 0))))
	if result.is_empty():
		result.append(point)
	return result

static func _placement_predicate_results(record: Dictionary, catalog: Dictionary, terrain_rows: Array, occupied: Dictionary) -> Dictionary:
	var point := _point_dict(int(record.get("x", 0)), int(record.get("y", 0)))
	var body_tiles := _runtime_body_tiles_for_catalog(point, catalog)
	var in_bounds := true
	for body in body_tiles:
		if body is Dictionary and not _point_in_rows(terrain_rows, int(body.get("x", 0)), int(body.get("y", 0))):
			in_bounds = false
	var terrain_id := String(record.get("terrain_id", ""))
	if terrain_id == "" and _point_in_rows(terrain_rows, int(point.get("x", 0)), int(point.get("y", 0))):
		terrain_id = String(terrain_rows[int(point.get("y", 0))][int(point.get("x", 0))])
	var terrain_ok := _object_catalog_allows_terrain(catalog, terrain_id)
	var has_visit_or_not_required: bool = not bool(catalog.get("action_mask", {}).get("visit_tile_required", false)) or not record.get("approach_tiles", []).is_empty() or not catalog.get("visit_mask", []).is_empty()
	return {
		"in_bounds": in_bounds,
		"terrain_allowed": terrain_ok,
		"runtime_body_mask_present": not catalog.get("runtime_body_mask", catalog.get("body_mask", [])).is_empty(),
		"body_mask_present": not catalog.get("body_mask", []).is_empty(),
		"passability_mask_present": not catalog.get("passability_mask", {}).is_empty(),
		"action_mask_present": not catalog.get("action_mask", {}).is_empty(),
		"visit_or_approach_passable": has_visit_or_not_required,
		"terrain_id": terrain_id,
	}

static func _object_catalog_allows_terrain(catalog: Dictionary, terrain_id: String) -> bool:
	if terrain_id == "":
		return false
	var restrictions: Dictionary = catalog.get("terrain_restrictions", {}) if catalog.get("terrain_restrictions", {}) is Dictionary else {}
	if terrain_id in restrictions.get("blocked_terrain_ids", []):
		return false
	var allowed: Array = restrictions.get("allowed_terrain_ids", [])
	return allowed.is_empty() or terrain_id in allowed

static func _object_footprint_validation_core(object_records: Array, reward_reference_records: Array, terrain_rows: Array, route_graph: Dictionary, road_network: Dictionary, reachability: Dictionary) -> Dictionary:
	var failures := []
	var warnings := []
	var missing_catalog_ids := []
	var terrain_failures := []
	var mask_failures := []
	var body_overlap_failures := []
	var occupied := {}
	for record in object_records:
		if not (record is Dictionary):
			failures.append("non-dictionary object footprint record")
			continue
		var placement_id := String(record.get("placement_id", record.get("id", "")))
		var ref: Dictionary = record.get("object_footprint_catalog_ref", {}) if record.get("object_footprint_catalog_ref", {}) is Dictionary else {}
		if String(ref.get("status", "")) != "catalog_record_applied":
			missing_catalog_ids.append(placement_id)
			continue
		for key in ["body_mask", "runtime_body_mask", "visit_mask", "approach_mask", "passability_mask", "action_mask", "terrain_restrictions", "placement_predicates"]:
			if not record.has(key):
				mask_failures.append("%s missing %s" % [placement_id, key])
				continue
			var value = record.get(key, [] if key.ends_with("mask") or key == "placement_predicates" else {})
			if key not in ["visit_mask", "approach_mask"] and ((value is Array and value.is_empty()) or (value is Dictionary and value.is_empty())):
				mask_failures.append("%s missing %s" % [placement_id, key])
		var predicates: Dictionary = record.get("placement_predicate_results", {}) if record.get("placement_predicate_results", {}) is Dictionary else {}
		if not bool(predicates.get("in_bounds", false)):
			failures.append("%s footprint body leaves map bounds" % placement_id)
		if not bool(predicates.get("terrain_allowed", false)):
			terrain_failures.append("%s terrain %s violates catalog restrictions" % [placement_id, String(predicates.get("terrain_id", ""))])
		for body in record.get("body_tiles", []):
			if not (body is Dictionary):
				failures.append("%s has non-dictionary body tile" % placement_id)
				continue
			var key := _point_key(int(body.get("x", 0)), int(body.get("y", 0)))
			if occupied.has(key):
				body_overlap_failures.append("%s overlaps %s at %s" % [placement_id, String(occupied[key]), key])
			occupied[key] = placement_id
	for reward_ref in reward_reference_records:
		if not (reward_ref is Dictionary):
			failures.append("non-dictionary reward footprint reference")
			continue
		var ref: Dictionary = reward_ref.get("object_footprint_catalog_ref", {}) if reward_ref.get("object_footprint_catalog_ref", {}) is Dictionary else {}
		if String(ref.get("status", "")) != "catalog_record_applied":
			missing_catalog_ids.append(String(reward_ref.get("id", "")))
	var route_failures := _object_footprint_route_failures(route_graph, terrain_rows, occupied, reachability)
	failures.append_array(mask_failures)
	failures.append_array(terrain_failures)
	failures.append_array(body_overlap_failures)
	failures.append_array(route_failures)
	for segment in road_network.get("road_segments", []):
		if not (segment is Dictionary):
			continue
		for cell in segment.get("cells", []):
			if cell is Dictionary:
				var key := _point_key(int(cell.get("x", 0)), int(cell.get("y", 0)))
				if occupied.has(key):
					failures.append("road segment %s crosses footprint body %s at %s" % [String(segment.get("route_edge_id", "")), String(occupied[key]), key])
	if not missing_catalog_ids.is_empty():
		failures.append("missing catalog records for %s" % ", ".join(missing_catalog_ids))
	var required_route_status := "pass" if route_failures.is_empty() and String(reachability.get("status", "")) == "pass" else "fail"
	return {
		"ok": failures.is_empty(),
		"status": "pass" if failures.is_empty() else "fail",
		"failures": failures,
		"warnings": warnings,
		"missing_catalog_ids": missing_catalog_ids,
		"mask_failures": mask_failures,
		"terrain_restriction_failures": terrain_failures,
		"body_overlap_failures": body_overlap_failures,
		"route_failures": route_failures,
		"required_route_check_status": required_route_status,
		"checked_object_record_count": object_records.size(),
		"checked_reward_reference_count": reward_reference_records.size(),
	}

static func _object_footprint_route_failures(route_graph: Dictionary, terrain_rows: Array, occupied: Dictionary, reachability: Dictionary) -> Array:
	var failures := []
	if String(reachability.get("status", "")) != "pass":
		failures.append("required route reachability was not pass before footprint validation")
	for edge in route_graph.get("edges", []):
		if not (edge is Dictionary) or not bool(edge.get("required", false)):
			continue
		var from_anchor: Dictionary = edge.get("from_anchor", {}) if edge.get("from_anchor", {}) is Dictionary else {}
		var to_anchor: Dictionary = edge.get("to_anchor", {}) if edge.get("to_anchor", {}) is Dictionary else {}
		var path := _find_passable_path(from_anchor, to_anchor, terrain_rows, occupied)
		if path.is_empty():
			failures.append("required route %s is blocked under footprint body occupancy" % String(edge.get("id", "")))
	return failures

static func _object_footprint_deferred_record_count(records: Array) -> int:
	var count := 0
	for record in records:
		if record is Dictionary and not record.get("footprint_deferred", {}).is_empty():
			count += 1
	return count

static func _object_footprint_phase_summary(payload: Dictionary) -> Dictionary:
	return {
		"schema_id": String(payload.get("schema_id", "")),
		"status": String(payload.get("status", "")),
		"signature": String(payload.get("object_footprint_signature", "")),
		"object_record_count": int(payload.get("summary", {}).get("object_record_count", 0)),
		"reward_reference_count": int(payload.get("summary", {}).get("reward_reference_count", 0)),
		"missing_catalog_count": int(payload.get("summary", {}).get("missing_catalog_count", 0)),
		"body_overlap_count": int(payload.get("summary", {}).get("body_overlap_count", 0)),
		"required_route_check_status": String(payload.get("summary", {}).get("required_route_check_status", "")),
		"deferred_multitile_record_count": int(payload.get("summary", {}).get("deferred_multitile_record_count", 0)),
	}

static func _object_footprint_validation(payload: Dictionary, generated_map: Dictionary = {}) -> Dictionary:
	var failures := []
	var warnings := []
	if String(payload.get("schema_id", "")) != OBJECT_FOOTPRINT_CATALOG_SCHEMA_ID:
		failures.append("object footprint catalog schema mismatch")
	if String(payload.get("object_footprint_signature", "")) == "":
		failures.append("object footprint signature missing")
	var catalog: Dictionary = payload.get("catalog", {}) if payload.get("catalog", {}) is Dictionary else {}
	if String(catalog.get("schema_id", "")) != OBJECT_FOOTPRINT_CATALOG_SCHEMA_ID:
		failures.append("object footprint embedded catalog schema mismatch")
	if catalog.get("records", []).is_empty():
		failures.append("object footprint catalog has no records")
	for catalog_record in catalog.get("records", []):
		if not (catalog_record is Dictionary):
			failures.append("catalog contains non-dictionary record")
			continue
		for key in ["footprint", "body_mask", "runtime_body_mask", "visit_mask", "approach_mask", "passability_mask", "action_mask", "terrain_restrictions", "placement_predicates"]:
			if not catalog_record.has(key):
				failures.append("catalog record %s missing %s" % [String(catalog_record.get("id", "")), key])
				continue
			var value = catalog_record.get(key, [] if key in ["body_mask", "runtime_body_mask", "placement_predicates"] else {})
			if key not in ["visit_mask", "approach_mask"] and ((value is Array and value.is_empty()) or (value is Dictionary and value.is_empty())):
				failures.append("catalog record %s missing %s" % [String(catalog_record.get("id", "")), key])
	var core_validation: Dictionary = payload.get("validation", {}) if payload.get("validation", {}) is Dictionary else {}
	if not bool(core_validation.get("ok", false)):
		failures.append_array(core_validation.get("failures", []))
	warnings.append_array(core_validation.get("warnings", []))
	if int(payload.get("summary", {}).get("object_record_count", 0)) <= 0:
		failures.append("object footprint payload has no object records")
	if int(payload.get("summary", {}).get("reward_reference_count", 0)) <= 0:
		failures.append("object footprint payload has no reward references")
	if not generated_map.is_empty():
		var generated_constraints: Dictionary = generated_map.get("scenario_record", {}).get("generated_constraints", {}) if generated_map.get("scenario_record", {}).get("generated_constraints", {}) is Dictionary else {}
		if generated_constraints.get("object_footprint_catalog", {}).is_empty():
			failures.append("scenario generated_constraints missed object footprint catalog")
		if generated_map.get("staging", {}).get("object_footprint_catalog", {}).is_empty():
			failures.append("staging missed object footprint catalog")
		var scenario: Dictionary = generated_map.get("scenario_record", {}) if generated_map.get("scenario_record", {}) is Dictionary else {}
		if bool(scenario.get("selection", {}).get("availability", {}).get("campaign", false)) or bool(scenario.get("selection", {}).get("availability", {}).get("skirmish", false)):
			failures.append("object footprint catalog adopted generated map into campaign/skirmish")
		if generated_map.has("save_adoption") or scenario.has("save_adoption") or scenario.has("alpha_parity_claim") or String(generated_map.get("write_policy", "")) != "staged_payload_only_no_authored_content_write":
			failures.append("object footprint catalog exposed save/writeback/parity claim")
	return {
		"ok": failures.is_empty(),
		"status": "pass" if failures.is_empty() else "fail",
		"failures": failures,
		"warnings": warnings,
	}

static func _build_town_mine_dwelling_placement_payload(normalized: Dictionary, zones: Array, placements: Dictionary, terrain_rows: Array, route_graph: Dictionary, road_network: Dictionary, decoration_density: Dictionary) -> Dictionary:
	var town_records := []
	var mine_records := []
	var dwelling_records := []
	var attempts := []
	var placement_by_id := {}
	for placement in placements.get("object_placements", []):
		if placement is Dictionary:
			placement_by_id[String(placement.get("placement_id", ""))] = placement
	for zone in zones:
		if not (zone is Dictionary):
			continue
		attempts.append(_town_mine_dwelling_attempt_record(zone, placements.get("object_placements", [])))
	for town in placements.get("towns", []):
		if not (town is Dictionary):
			continue
		var source: Dictionary = placement_by_id.get(String(town.get("placement_id", "")), {})
		town_records.append(_town_placement_record(town, source))
	for resource in placements.get("resource_nodes", []):
		if not (resource is Dictionary):
			continue
		var source: Dictionary = placement_by_id.get(String(resource.get("placement_id", "")), {})
		match String(source.get("kind", "")):
			"mine":
				mine_records.append(_mine_placement_record(resource, source))
			"neutral_dwelling":
				dwelling_records.append(_dwelling_placement_record(resource, source))
	var validation := _town_mine_dwelling_validation_core(town_records, mine_records, dwelling_records, route_graph, road_network, decoration_density, terrain_rows)
	var status := "pass" if bool(validation.get("ok", false)) else "fail"
	var payload := {
		"schema_id": TOWN_MINE_DWELLING_PLACEMENT_SCHEMA_ID,
		"status": status,
		"placement_policy": "template_zone_rules_place_owned_towns_neutral_same_type_towns_seven_category_mines_and_neutral_dwellings",
		"source_model": "HoMM3_RMG_structure_translated_to_original_content_ids_and_categories",
		"town_start_records": town_records,
		"mine_resource_producer_records": mine_records,
		"dwelling_recruitment_site_records": dwelling_records,
		"zone_rule_attempts": attempts,
		"validation": validation,
		"fairness_inputs": {
			"core_resource_categories": ["timber", "ore", "gold"],
			"seven_category_order": ORIGINAL_RESOURCE_CATEGORY_ORDER,
			"start_support_contract": "owned_start_zones_require_primary_town_and_core_economy_producer_access",
		},
		"writeout_state": "structured_placement_payload_no_authored_content_writeback_no_parity_claim",
		"summary": {
			"town_count": town_records.size(),
			"mine_count": mine_records.size(),
			"dwelling_count": dwelling_records.size(),
			"zone_attempt_count": attempts.size(),
			"same_type_neutral_town_count": _count_records_with_value(town_records, "same_type_semantics", "source_zone_choice_reused_for_neutral_town_when_same_type_flag_is_present"),
			"core_category_mine_count": _count_core_category_mines(mine_records),
			"validation_status": String(validation.get("status", "")),
			"conflict_count": validation.get("conflicts", []).size(),
		},
		"deferred": [
			"final_multitile_body_stamping",
			"final_mine_adjacent_resource_object_writeout",
			"neutral_dwelling_runtime_recruitment_ui_adoption",
			"campaign_authored_writeback",
			"parity_or_alpha_completion_claim",
		],
	}
	payload["town_mine_dwelling_signature"] = _hash32_hex(_stable_stringify({
		"town_start_records": town_records,
		"mine_resource_producer_records": mine_records,
		"dwelling_recruitment_site_records": dwelling_records,
		"zone_rule_attempts": attempts,
		"validation": validation,
	}))
	return payload

static func _town_mine_dwelling_attempt_record(zone: Dictionary, object_placements: Array) -> Dictionary:
	var zone_id := String(zone.get("id", ""))
	var metadata: Dictionary = zone.get("catalog_metadata", {}) if zone.get("catalog_metadata", {}) is Dictionary else {}
	var player_towns: Dictionary = metadata.get("player_towns", {}) if metadata.get("player_towns", {}) is Dictionary else {}
	var neutral_towns: Dictionary = metadata.get("neutral_towns", {}) if metadata.get("neutral_towns", {}) is Dictionary else {}
	var requirements := _zone_resource_requirements(zone)
	var placed_counts := {"town": 0, "mine": 0, "neutral_dwelling": 0}
	for placement in object_placements:
		if placement is Dictionary and String(placement.get("zone_id", "")) == zone_id:
			var kind := String(placement.get("kind", ""))
			if placed_counts.has(kind):
				placed_counts[kind] = int(placed_counts.get(kind, 0)) + 1
	return {
		"zone_id": zone_id,
		"zone_role": String(zone.get("role", "")),
		"owner_slot": zone.get("owner_slot", null),
		"player_slot": zone.get("player_slot", null),
		"player_type": String(zone.get("player_type", "neutral")),
		"same_town_type": bool(metadata.get("same_town_type", false)),
		"player_town_rule": player_towns,
		"neutral_town_rule": neutral_towns,
		"mine_requirements": requirements,
		"dwelling_rule": {"attempted": _zone_should_place_dwelling(zone), "policy": "one_original_neutral_recruitment_site_per_zone_role_when_capacity_allows"},
		"placed_counts": placed_counts,
	}

static func _town_placement_record(town: Dictionary, source: Dictionary) -> Dictionary:
	return {
		"placement_id": String(town.get("placement_id", "")),
		"town_id": String(town.get("town_id", "")),
		"faction_id": String(town.get("faction_id", "")),
		"owner": String(town.get("owner", "")),
		"player_slot": int(town.get("player_slot", 0)),
		"player_type": String(town.get("player_type", "neutral")),
		"team_id": String(town.get("team_id", "")),
		"zone_id": String(town.get("zone_id", "")),
		"zone_role": String(town.get("zone_role", "")),
		"x": int(town.get("x", 0)),
		"y": int(town.get("y", 0)),
		"body_tiles": town.get("body_tiles", []),
		"approach_tiles": town.get("approach_tiles", []),
		"visit_tile": town.get("visit_tile", {}),
		"pathing_status": String(town.get("pathing_status", "")),
		"footprint_action_metadata": _placement_footprint_action_metadata(town),
		"town_assignment_semantics": String(town.get("town_assignment_semantics", source.get("town_assignment_semantics", ""))),
		"same_type_semantics": String(source.get("same_type_semantics", "")),
		"same_type_source_zone_id": String(town.get("same_type_source_zone_id", source.get("same_type_source_zone_id", ""))),
		"start_contract": "primary_town_start_support" if int(town.get("player_slot", 0)) > 0 else "neutral_town_objective_or_expansion",
		"writeout_state": "staged_town_record_no_authored_content_writeback",
	}

static func _mine_placement_record(resource: Dictionary, source: Dictionary) -> Dictionary:
	return {
		"placement_id": String(resource.get("placement_id", "")),
		"site_id": String(resource.get("site_id", "")),
		"object_id": String(source.get("object_id", "")),
		"family_id": String(source.get("family_id", "")),
		"owner": String(source.get("owner", "neutral")),
		"player_slot": int(source.get("player_slot", 0)),
		"player_type": String(source.get("player_type", "neutral")),
		"team_id": String(source.get("team_id", "")),
		"zone_id": String(resource.get("zone_id", "")),
		"zone_role": String(source.get("zone_role", "")),
		"x": int(resource.get("x", 0)),
		"y": int(resource.get("y", 0)),
		"body_tiles": resource.get("body_tiles", []),
		"approach_tiles": resource.get("approach_tiles", []),
		"visit_tile": resource.get("visit_tile", {}),
		"pathing_status": String(resource.get("pathing_status", "")),
		"footprint_action_metadata": _placement_footprint_action_metadata(resource),
		"original_resource_category_id": String(source.get("original_resource_category_id", "")),
		"source_equivalent": String(source.get("source_equivalent", "")),
		"resource_id": String(source.get("resource_id", "")),
		"mine_family_id": String(source.get("mine_family_id", "")),
		"seven_category_index": int(source.get("seven_category_index", 0)),
		"minimum_requirement": int(source.get("minimum_requirement", 0)),
		"density_requirement": int(source.get("density_requirement", 0)),
		"guard_pressure": source.get("guard_pressure", {}),
		"frontier_metadata": source.get("frontier_metadata", {}),
		"adjacent_resource_metadata": source.get("adjacent_resource_metadata", {}),
		"writeout_state": String(source.get("writeout_state", "")),
	}

static func _dwelling_placement_record(resource: Dictionary, source: Dictionary) -> Dictionary:
	return {
		"placement_id": String(resource.get("placement_id", "")),
		"site_id": String(resource.get("site_id", "")),
		"object_id": String(source.get("object_id", "")),
		"family_id": String(source.get("family_id", "")),
		"neutral_dwelling_family_id": String(source.get("neutral_dwelling_family_id", "")),
		"owner": String(source.get("owner", "neutral")),
		"player_slot": int(source.get("player_slot", 0)),
		"player_type": String(source.get("player_type", "neutral")),
		"team_id": String(source.get("team_id", "")),
		"zone_id": String(resource.get("zone_id", "")),
		"zone_role": String(source.get("zone_role", "")),
		"x": int(resource.get("x", 0)),
		"y": int(resource.get("y", 0)),
		"body_tiles": resource.get("body_tiles", []),
		"approach_tiles": resource.get("approach_tiles", []),
		"visit_tile": resource.get("visit_tile", {}),
		"pathing_status": String(resource.get("pathing_status", "")),
		"footprint_action_metadata": _placement_footprint_action_metadata(resource),
		"recruitment_site_category": String(source.get("recruitment_site_category", "")),
		"guard_pressure": String(source.get("guard_pressure", "")),
		"reward_context": source.get("reward_context", {}),
		"monster_band_context": source.get("monster_band_context", {}),
		"writeout_state": String(source.get("writeout_state", "")),
	}

static func _placement_footprint_action_metadata(record: Dictionary) -> Dictionary:
	return {
		"object_footprint_catalog_ref": record.get("object_footprint_catalog_ref", {}),
		"footprint": record.get("footprint", {}),
		"runtime_footprint": record.get("runtime_footprint", {}),
		"body_mask": record.get("body_mask", []),
		"runtime_body_mask": record.get("runtime_body_mask", []),
		"visit_mask": record.get("visit_mask", []),
		"approach_mask": record.get("approach_mask", []),
		"passability_mask": record.get("passability_mask", {}),
		"action_mask": record.get("action_mask", {}),
		"terrain_restrictions": record.get("terrain_restrictions", {}),
		"placement_predicates": record.get("placement_predicates", []),
		"placement_predicate_results": record.get("placement_predicate_results", {}),
	}

static func _town_mine_dwelling_validation_core(town_records: Array, mine_records: Array, dwelling_records: Array, route_graph: Dictionary, road_network: Dictionary, decoration_density: Dictionary, terrain_rows: Array) -> Dictionary:
	var failures := []
	var warnings := []
	var conflicts := []
	if town_records.is_empty():
		failures.append("no town/start placement records")
	if mine_records.is_empty():
		failures.append("no mine/resource producer placement records")
	if dwelling_records.is_empty():
		failures.append("no dwelling/recruitment site placement records")
	var body_lookup := {}
	for bucket in [town_records, mine_records, dwelling_records]:
		for record in bucket:
			if not (record is Dictionary):
				failures.append("non-dictionary town/mine/dwelling record")
				continue
			var placement_id := String(record.get("placement_id", ""))
			if String(record.get("pathing_status", "")) != "pass":
				failures.append("%s does not have pass pathing metadata" % placement_id)
			var meta: Dictionary = record.get("footprint_action_metadata", {}) if record.get("footprint_action_metadata", {}) is Dictionary else {}
			if String(meta.get("object_footprint_catalog_ref", {}).get("status", "")) != "catalog_record_applied":
				failures.append("%s missing applied object footprint catalog metadata" % placement_id)
			var predicates: Dictionary = meta.get("placement_predicate_results", {}) if meta.get("placement_predicate_results", {}) is Dictionary else {}
			for key in ["in_bounds", "terrain_allowed", "visit_or_approach_passable"]:
				if not bool(predicates.get(key, false)):
					failures.append("%s failed placement predicate %s" % [placement_id, key])
			for body in record.get("body_tiles", []):
				if not (body is Dictionary):
					failures.append("%s has invalid body tile" % placement_id)
					continue
				var x := int(body.get("x", 0))
				var y := int(body.get("y", 0))
				var key := _point_key(x, y)
				if body_lookup.has(key):
					conflicts.append("%s overlaps %s at %s" % [placement_id, String(body_lookup[key]), key])
				body_lookup[key] = placement_id
				if not _point_in_rows(terrain_rows, x, y) or not _terrain_cell_is_passable(terrain_rows, x, y):
					failures.append("%s body is on blocked terrain at %s" % [placement_id, key])
	for segment in road_network.get("road_segments", []):
		if not (segment is Dictionary):
			continue
		for cell in segment.get("cells", []):
			if cell is Dictionary:
				var key := _point_key(int(cell.get("x", 0)), int(cell.get("y", 0)))
				if body_lookup.has(key):
					conflicts.append("road segment %s crosses %s at %s" % [String(segment.get("route_edge_id", "")), String(body_lookup[key]), key])
	for decor in decoration_density.get("decoration_records", []):
		if not (decor is Dictionary):
			continue
		for body in decor.get("body_tiles", []):
			if body is Dictionary:
				var key := _point_key(int(body.get("x", 0)), int(body.get("y", 0)))
				if body_lookup.has(key):
					conflicts.append("decoration %s overlaps %s at %s" % [String(decor.get("placement_id", decor.get("id", ""))), String(body_lookup[key]), key])
	if conflicts.size() > 0:
		failures.append_array(conflicts)
	var same_type_count := _count_records_with_value(town_records, "same_type_semantics", "source_zone_choice_reused_for_neutral_town_when_same_type_flag_is_present")
	if same_type_count <= 0:
		warnings.append("no neutral same-type town was placed for this seed/template")
	var seven_categories := {}
	for mine in mine_records:
		if mine is Dictionary:
			seven_categories[String(mine.get("original_resource_category_id", ""))] = true
	for required_category in ["timber", "ore"]:
		if not seven_categories.has(required_category):
			failures.append("core mine category %s was not placed" % required_category)
	var status := "pass"
	if not failures.is_empty():
		status = "fail"
	elif not warnings.is_empty():
		status = "warning"
	return {
		"ok": failures.is_empty(),
		"status": status,
		"failures": failures,
		"warnings": warnings,
		"conflicts": conflicts,
		"route_edge_count": route_graph.get("edges", []).size(),
		"road_segment_count": road_network.get("road_segments", []).size(),
		"decoration_record_count": decoration_density.get("decoration_records", []).size(),
		"placed_resource_categories": _sorted_keys(seven_categories),
	}

static func _town_mine_dwelling_validation(payload: Dictionary, generated_map: Dictionary = {}) -> Dictionary:
	var failures := []
	var warnings := []
	if String(payload.get("schema_id", "")) != TOWN_MINE_DWELLING_PLACEMENT_SCHEMA_ID:
		failures.append("town/mine/dwelling placement schema mismatch")
	if String(payload.get("town_mine_dwelling_signature", "")) == "":
		failures.append("town/mine/dwelling placement signature missing")
	var core: Dictionary = payload.get("validation", {}) if payload.get("validation", {}) is Dictionary else {}
	if not bool(core.get("ok", false)):
		failures.append_array(core.get("failures", []))
	warnings.append_array(core.get("warnings", []))
	if int(payload.get("summary", {}).get("town_count", 0)) <= 0:
		failures.append("town/mine/dwelling payload has no towns")
	if int(payload.get("summary", {}).get("mine_count", 0)) <= 0:
		failures.append("town/mine/dwelling payload has no mines")
	if int(payload.get("summary", {}).get("dwelling_count", 0)) <= 0:
		failures.append("town/mine/dwelling payload has no dwellings")
	if generated_map.get("scenario_record", {}).get("generated_constraints", {}).get("town_mine_dwelling_placement", {}).is_empty() and not generated_map.is_empty():
		failures.append("scenario generated_constraints missed town/mine/dwelling placement")
	if not generated_map.is_empty():
		var scenario: Dictionary = generated_map.get("scenario_record", {}) if generated_map.get("scenario_record", {}) is Dictionary else {}
		if bool(scenario.get("selection", {}).get("availability", {}).get("campaign", false)):
			failures.append("town/mine/dwelling placement adopted generated map into campaign")
		if generated_map.has("authored_content_writeback") or scenario.has("alpha_parity_claim"):
			failures.append("town/mine/dwelling placement exposed authored writeback or parity claim")
	return {
		"ok": failures.is_empty(),
		"status": "pass" if failures.is_empty() else "fail",
		"failures": failures,
		"warnings": warnings,
	}

static func _town_mine_dwelling_phase_summary(payload: Dictionary) -> Dictionary:
	return {
		"schema_id": String(payload.get("schema_id", "")),
		"status": String(payload.get("status", "")),
		"signature": String(payload.get("town_mine_dwelling_signature", "")),
		"town_count": int(payload.get("summary", {}).get("town_count", 0)),
		"mine_count": int(payload.get("summary", {}).get("mine_count", 0)),
		"dwelling_count": int(payload.get("summary", {}).get("dwelling_count", 0)),
		"same_type_neutral_town_count": int(payload.get("summary", {}).get("same_type_neutral_town_count", 0)),
		"core_category_mine_count": int(payload.get("summary", {}).get("core_category_mine_count", 0)),
	}

static func _count_records_with_value(records: Array, key: String, expected: String) -> int:
	var count := 0
	for record in records:
		if record is Dictionary and String(record.get(key, "")) == expected:
			count += 1
	return count

static func _count_core_category_mines(records: Array) -> int:
	var count := 0
	for record in records:
		if record is Dictionary and String(record.get("original_resource_category_id", "")) in ["timber", "ore", "gold"]:
			count += 1
	return count

static func _build_roads_rivers_writeout_payload(normalized: Dictionary, terrain_rows: Array, zone_layout: Dictionary, terrain_transit: Dictionary, road_network: Dictionary, route_graph: Dictionary, object_footprints: Dictionary, placements: Dictionary) -> Dictionary:
	var road_overlay := _road_overlay_writeout_payload(road_network, route_graph, terrain_rows, object_footprints)
	var river_overlay := _river_water_coast_overlay_payload(zone_layout, terrain_transit)
	var serialization_record := _generated_map_serialization_record(normalized, terrain_rows, terrain_transit, road_overlay, river_overlay, object_footprints, placements, route_graph)
	var round_trip := _round_trip_serialization_record(serialization_record)
	var validation := _roads_rivers_writeout_validation_core(road_overlay, river_overlay, serialization_record, round_trip, route_graph, object_footprints)
	var status := "pass" if bool(validation.get("ok", false)) else "fail"
	var payload := {
		"schema_id": ROADS_RIVERS_WRITEOUT_SCHEMA_ID,
		"status": status,
		"writeout_policy": "generated_serialization_metadata_only_no_authored_content_writeback",
		"road_overlay": road_overlay,
		"river_water_coast_overlay": river_overlay,
		"generated_map_serialization": serialization_record,
		"round_trip_validation": round_trip,
		"validation": validation,
		"summary": {
			"road_tile_count": int(road_overlay.get("summary", {}).get("tile_count", 0)),
			"road_segment_count": int(road_overlay.get("summary", {}).get("segment_count", 0)),
			"required_route_road_count": int(road_overlay.get("summary", {}).get("required_route_count", 0)),
			"water_overlay_tile_count": int(river_overlay.get("summary", {}).get("water_tile_count", 0)),
			"coast_overlay_tile_count": int(river_overlay.get("summary", {}).get("coast_tile_count", 0)),
			"river_candidate_count": int(river_overlay.get("summary", {}).get("river_candidate_count", 0)),
			"object_instance_count": int(serialization_record.get("object_instances", []).size()),
			"overlay_layer_count": int(serialization_record.get("overlay_layers", []).size()),
			"round_trip_status": String(round_trip.get("status", "")),
			"validation_status": String(validation.get("status", "")),
		},
		"deferred": [
			"authored_json_file_export",
			"terrain_overlay_byte_packing",
			"final_road_river_autotile_art_selection",
			"final_multitile_object_body_stamping",
			"campaign_skirmish_ui_save_replay_adoption",
		],
	}
	payload["roads_rivers_writeout_signature"] = _hash32_hex(_stable_stringify({
		"road_overlay": road_overlay,
		"river_water_coast_overlay": river_overlay,
		"generated_map_serialization": serialization_record,
		"round_trip_validation": round_trip,
	}))
	return payload

static func _road_overlay_writeout_payload(road_network: Dictionary, route_graph: Dictionary, terrain_rows: Array, object_footprints: Dictionary) -> Dictionary:
	var edges_by_id := _route_edges_by_id(route_graph.get("edges", []))
	var occupied := _body_lookup_from_footprint_records(object_footprints.get("object_records", []))
	var overlay_tiles := []
	var segment_records := []
	var route_ids := []
	var required_route_ids := []
	var diagnostics := []
	for segment in road_network.get("road_segments", []):
		if not (segment is Dictionary):
			diagnostics.append({"reason": "invalid_road_segment", "message": "road segment is not a dictionary", "retryable": true})
			continue
		var route_edge_id := String(segment.get("route_edge_id", ""))
		var edge: Dictionary = edges_by_id.get(route_edge_id, {})
		var road_class := _road_class_for_edge(edge, segment)
		var road_type_id := _road_type_for_class(road_class, edge)
		var segment_tiles := []
		for index in range(segment.get("cells", []).size()):
			var cell = segment.get("cells", [])[index]
			if not (cell is Dictionary):
				diagnostics.append({"route_edge_id": route_edge_id, "reason": "invalid_road_cell", "message": "road cell is not a dictionary", "retryable": true})
				continue
			var x := int(cell.get("x", -1))
			var y := int(cell.get("y", -1))
			var key := _point_key(x, y)
			var terrain_id := String(terrain_rows[y][x]) if _point_in_rows(terrain_rows, x, y) else ""
			var body_blocked := occupied.has(key)
			var tile := {
				"id": "road_tile_%s_%03d" % [route_edge_id, index + 1],
				"route_edge_id": route_edge_id,
				"level_index": 0,
				"x": x,
				"y": y,
				"terrain_id": terrain_id,
				"overlay_id": ROAD_OVERLAY_ID,
				"road_class": road_class,
				"road_type_id": road_type_id,
				"road_art_index": int(_hash32_int("%s:%d,%d:road_art" % [route_edge_id, x, y]) % 16),
				"neighbor_mask": _road_neighbor_mask(segment.get("cells", []), x, y),
				"passability": "passable" if _terrain_cell_is_passable(terrain_rows, x, y) and not body_blocked else "blocked",
				"body_conflict": body_blocked,
				"writeout_state": "staged_overlay_tile_metadata_no_authored_tile_bytes_written",
			}
			overlay_tiles.append(tile)
			segment_tiles.append(tile)
		if route_edge_id not in route_ids:
			route_ids.append(route_edge_id)
		if bool(edge.get("required", false)) and route_edge_id not in required_route_ids:
			required_route_ids.append(route_edge_id)
		segment_records.append({
			"id": String(segment.get("id", "road_%s" % route_edge_id)),
			"route_edge_id": route_edge_id,
			"role": String(edge.get("role", segment.get("role", ""))),
			"required": bool(edge.get("required", false)),
			"connectivity_classification": String(segment.get("connectivity_classification", edge.get("connectivity_classification", ""))),
			"road_class": road_class,
			"road_type_id": road_type_id,
			"tile_count": segment_tiles.size(),
			"tiles": segment_tiles,
			"transit_semantics": edge.get("transit_semantics", {}),
			"writeout_state": "staged_segment_overlay_tiles_no_final_autotile_write",
		})
	route_ids.sort()
	required_route_ids.sort()
	var payload := {
		"schema_id": "random_map_road_overlay_writeout_v1",
		"overlay_id": ROAD_OVERLAY_ID,
		"writeout_policy": "structured_overlay_tiles_no_authored_tile_bytes_written",
		"road_class_policy": "required_routes_primary_guarded_routes_fortified_resource_routes_service",
		"segments": segment_records,
		"tiles": overlay_tiles,
		"route_edge_ids": route_ids,
		"required_route_edge_ids": required_route_ids,
		"diagnostics": diagnostics,
		"blocked_body_policy": "road_tiles_must_not_overlap_object_footprint_body_tiles",
		"summary": {
			"segment_count": segment_records.size(),
			"tile_count": overlay_tiles.size(),
			"route_edge_count": route_ids.size(),
			"required_route_count": required_route_ids.size(),
			"body_conflict_count": _count_overlay_body_conflicts(overlay_tiles),
			"diagnostic_count": diagnostics.size(),
		},
	}
	payload["road_overlay_signature"] = _hash32_hex(_stable_stringify({"segments": segment_records, "tiles": overlay_tiles, "diagnostics": diagnostics}))
	return payload

static func _river_water_coast_overlay_payload(zone_layout: Dictionary, terrain_transit: Dictionary) -> Dictionary:
	var water: Dictionary = terrain_transit.get("water_coast_passability", {}) if terrain_transit.get("water_coast_passability", {}) is Dictionary else {}
	var water_tiles := []
	for index in range(water.get("water_cells", []).size()):
		var cell = water.get("water_cells", [])[index]
		if cell is Dictionary:
			water_tiles.append({
				"id": "water_overlay_%03d" % (index + 1),
				"level_index": 0,
				"x": int(cell.get("x", 0)),
				"y": int(cell.get("y", 0)),
				"overlay_type": "water",
				"water_mode": String(water.get("water_mode", "land")),
				"passability": String(water.get("water_passability", "")),
				"writeout_state": "terrain_water_cell_metadata_no_river_tile_bytes_written",
			})
	var coast_tiles := []
	for index in range(water.get("coast_cells", []).size()):
		var cell = water.get("coast_cells", [])[index]
		if cell is Dictionary:
			coast_tiles.append({
				"id": "coast_overlay_%03d" % (index + 1),
				"level_index": 0,
				"x": int(cell.get("x", 0)),
				"y": int(cell.get("y", 0)),
				"overlay_type": "coast",
				"water_mode": String(water.get("water_mode", "land")),
				"passability": String(water.get("coast_passability", "")),
				"writeout_state": "coast_adjacency_metadata_no_final_coast_autotile_write",
			})
	var river_candidates := []
	var water_access: Array = terrain_transit.get("transit_routes", {}).get("water_access_candidates", [])
	for index in range(water_access.size()):
		var candidate = water_access[index]
		if not (candidate is Dictionary):
			continue
		var from_anchor: Dictionary = candidate.get("from_anchor", {}) if candidate.get("from_anchor", {}) is Dictionary else {}
		var to_coast: Dictionary = candidate.get("to_coast", {}) if candidate.get("to_coast", {}) is Dictionary else {}
		river_candidates.append({
			"id": "river_candidate_%03d" % (index + 1),
			"zone_id": String(candidate.get("zone_id", "")),
			"level_index": int(candidate.get("level_index", 0)),
			"candidate_cells": _straight_corridor_cells(from_anchor, to_coast),
			"from_anchor": from_anchor,
			"to_coast": to_coast,
			"overlay_type": "river_or_ferry_channel_candidate",
			"transit_semantics": candidate.get("transit_semantics", {}),
			"materialization_state": "candidate_only_river_ferry_bridge_writeout_deferred",
			"writeout_state": "deferred_overlay_metadata_no_final_river_tile_bytes_written",
		})
	var explicit_state := {}
	if water_tiles.is_empty() and coast_tiles.is_empty() and river_candidates.is_empty():
		explicit_state = {
			"state": "explicit_land_no_river_overlay_candidates",
			"water_mode": String(water.get("water_mode", zone_layout.get("policy", {}).get("water_mode", "land"))),
			"reason": "selected_template_and_profile_have_no_surface_water_or_river_transit_request",
		}
	var payload := {
		"schema_id": "random_map_river_water_coast_overlay_writeout_v1",
		"writeout_policy": "water_coast_and_river_candidates_are_metadata_only_until_transit_writeout_slice",
		"water_mode": String(water.get("water_mode", zone_layout.get("policy", {}).get("water_mode", "land"))),
		"water_overlay_tiles": water_tiles,
		"coast_overlay_tiles": coast_tiles,
		"river_candidates": river_candidates,
		"explicit_no_river_state": explicit_state,
		"deferred_transit_writeout": _unique_sorted_strings(["boat_shipyard_ferry_placement_deferred", "bridge_placement_deferred", "river_autotile_byte_packing_deferred"] + terrain_transit.get("transit_routes", {}).get("deferred", [])),
		"summary": {
			"water_tile_count": water_tiles.size(),
			"coast_tile_count": coast_tiles.size(),
			"river_candidate_count": river_candidates.size(),
			"explicit_no_river": not explicit_state.is_empty(),
		},
	}
	payload["river_water_coast_signature"] = _hash32_hex(_stable_stringify({"water_overlay_tiles": water_tiles, "coast_overlay_tiles": coast_tiles, "river_candidates": river_candidates, "explicit_no_river_state": explicit_state}))
	return payload

static func _generated_map_serialization_record(normalized: Dictionary, terrain_rows: Array, terrain_transit: Dictionary, road_overlay: Dictionary, river_overlay: Dictionary, object_footprints: Dictionary, placements: Dictionary, route_graph: Dictionary) -> Dictionary:
	var metadata := _metadata(normalized)
	var overlay_layers := [
		{
			"id": "generated_roads",
			"layer_type": "road_overlay",
			"schema_id": String(road_overlay.get("schema_id", "")),
			"tiles": road_overlay.get("tiles", []),
			"segments": road_overlay.get("segments", []),
			"writeout_state": "staged_overlay_layer_no_authored_tile_bytes_written",
		},
		{
			"id": "generated_water_coast_river_candidates",
			"layer_type": "river_water_coast_overlay",
			"schema_id": String(river_overlay.get("schema_id", "")),
			"water_overlay_tiles": river_overlay.get("water_overlay_tiles", []),
			"coast_overlay_tiles": river_overlay.get("coast_overlay_tiles", []),
			"river_candidates": river_overlay.get("river_candidates", []),
			"explicit_no_river_state": river_overlay.get("explicit_no_river_state", {}),
			"writeout_state": "staged_overlay_layer_transit_writeout_deferred",
		},
	]
	var object_instances := _serialization_object_instances(object_footprints, placements)
	var record := {
		"schema_id": GENERATED_MAP_SERIALIZATION_SCHEMA_ID,
		"serialization_policy": "pure_dictionary_json_safe_metadata_no_authored_content_writeback",
		"generator_version": String(metadata.get("generator_version", "")),
		"provenance": {
			"source": "generated_random_map",
			"template_id": String(metadata.get("template_id", "")),
			"profile_id": String(metadata.get("profile", {}).get("id", "")),
			"normalized_seed": String(metadata.get("normalized_seed", "")),
			"content_manifest_fingerprint": String(metadata.get("content_manifest_fingerprint", "")),
			"task_id": "10184",
			"slice_id": "random-map-roads-rivers-writeout-10184",
		},
		"map_size": normalized.get("size", {}),
		"terrain_rows": terrain_rows,
		"terrain_layers": terrain_transit.get("terrain_layers", []),
		"overlay_layers": overlay_layers,
		"object_definitions": object_footprints.get("catalog", {}).get("records", []),
		"object_instances": object_instances,
		"route_graph_summary": {
			"edge_count": route_graph.get("edges", []).size(),
			"required_edge_count": _required_route_count(route_graph.get("edges", [])),
		},
		"validation_status": {
			"object_footprint_status": String(object_footprints.get("status", "")),
			"road_overlay_status": "pass" if int(road_overlay.get("summary", {}).get("body_conflict_count", 0)) == 0 else "fail",
			"round_trip_required": true,
		},
		"deferred_boundary_metadata": {
			"authored_json_writeback": "deferred",
			"campaign_adoption": "deferred",
			"skirmish_ui_adoption": "deferred",
			"save_schema_adoption": "deferred",
			"final_multitile_object_body_stamping": "deferred",
			"final_road_river_tile_byte_packing": "deferred",
		},
	}
	record = _json_safe_value(record)
	record["round_trip_signature"] = _serialization_record_signature(record)
	return record

static func _serialization_object_instances(object_footprints: Dictionary, placements: Dictionary) -> Array:
	var instances := []
	for record in object_footprints.get("object_records", []):
		if not (record is Dictionary):
			continue
		var instance := {
			"instance_id": String(record.get("placement_id", record.get("id", ""))),
			"kind": String(record.get("kind", "")),
			"content_id": _object_record_content_id(record),
			"x": int(record.get("x", 0)),
			"y": int(record.get("y", 0)),
			"level_index": int(record.get("level_index", 0)),
			"zone_id": String(record.get("zone_id", "")),
			"body_tiles": record.get("body_tiles", []),
			"catalog_body_tiles": record.get("catalog_body_tiles", []),
			"visit_tile": record.get("visit_tile", {}),
			"approach_tiles": record.get("approach_tiles", []),
			"object_footprint_catalog_ref": record.get("object_footprint_catalog_ref", {}),
			"footprint": record.get("footprint", {}),
			"runtime_footprint": record.get("runtime_footprint", {}),
			"passability_mask": record.get("passability_mask", {}),
			"action_mask": record.get("action_mask", {}),
			"terrain_restrictions": record.get("terrain_restrictions", {}),
			"placement_predicate_results": record.get("placement_predicate_results", {}),
			"deferred_multitile_state": record.get("footprint_deferred", {}),
			"writeout_state": String(record.get("writeout_state", record.get("object_footprint_catalog_ref", {}).get("deferred_runtime_application", "staged_object_instance_no_final_writeout"))),
		}
		instances.append(_json_safe_value(instance))
	for reward in object_footprints.get("reward_reference_records", []):
		if not (reward is Dictionary):
			continue
		instances.append(_json_safe_value({
			"instance_id": String(reward.get("id", "")),
			"kind": "reward_reference",
			"content_id": String(reward.get("selected_reward_object_id", "")),
			"route_edge_id": String(reward.get("route_edge_id", "")),
			"object_footprint_catalog_ref": reward.get("object_footprint_catalog_ref", {}),
			"deferred_multitile_state": {"reason": String(reward.get("deferred_reason", "")), "structured_deferred_reason": true},
			"writeout_state": String(reward.get("placement_state", "reward_reference_only_body_placement_deferred")),
		}))
	return instances

static func _round_trip_serialization_record(record: Dictionary) -> Dictionary:
	var json_safe_record: Dictionary = _json_safe_value(record)
	var json_text := JSON.stringify(json_safe_record)
	var parsed = JSON.parse_string(json_text)
	var failures := []
	if not (parsed is Dictionary):
		failures.append("serialized record did not parse back to dictionary")
		parsed = {}
	var original_signature := _serialization_record_signature(json_safe_record)
	var parsed_signature := _serialization_record_signature(parsed)
	var original_counts := _serialization_key_counts(json_safe_record)
	var parsed_counts := _serialization_key_counts(parsed)
	if original_signature != parsed_signature:
		failures.append("round-trip signature changed")
	if _stable_stringify(original_counts) != _stable_stringify(parsed_counts):
		failures.append("round-trip key counts changed")
	return {
		"ok": failures.is_empty(),
		"status": "pass" if failures.is_empty() else "fail",
		"original_signature": original_signature,
		"parsed_signature": parsed_signature,
		"signature_stable": original_signature == parsed_signature,
		"original_key_counts": original_counts,
		"parsed_key_counts": parsed_counts,
		"key_counts_stable": _stable_stringify(original_counts) == _stable_stringify(parsed_counts),
		"json_byte_length": json_text.length(),
		"failures": failures,
	}

static func _roads_rivers_writeout_validation_core(road_overlay: Dictionary, river_overlay: Dictionary, serialization_record: Dictionary, round_trip: Dictionary, route_graph: Dictionary, object_footprints: Dictionary) -> Dictionary:
	var failures := []
	var warnings := []
	if String(road_overlay.get("schema_id", "")) != "random_map_road_overlay_writeout_v1":
		failures.append("road overlay schema mismatch")
	if String(river_overlay.get("schema_id", "")) != "random_map_river_water_coast_overlay_writeout_v1":
		failures.append("river/water/coast overlay schema mismatch")
	if String(serialization_record.get("schema_id", "")) != GENERATED_MAP_SERIALIZATION_SCHEMA_ID:
		failures.append("generated map serialization schema mismatch")
	if int(road_overlay.get("summary", {}).get("tile_count", 0)) <= 0:
		failures.append("road overlay produced no tiles")
	if int(road_overlay.get("summary", {}).get("body_conflict_count", 0)) > 0:
		failures.append("road overlay crosses object footprint body tiles")
	var road_route_ids: Array = road_overlay.get("route_edge_ids", [])
	for edge in route_graph.get("edges", []):
		if not (edge is Dictionary) or not bool(edge.get("required", false)) or not bool(edge.get("path_found", false)):
			continue
		if String(edge.get("id", "")) not in road_route_ids:
			failures.append("required route %s has no road overlay tiles" % String(edge.get("id", "")))
	var water_mode := String(river_overlay.get("water_mode", "land"))
	if water_mode == "islands":
		if int(river_overlay.get("summary", {}).get("water_tile_count", 0)) <= 0 or int(river_overlay.get("summary", {}).get("coast_tile_count", 0)) <= 0:
			failures.append("island/water config missed water or coast overlay metadata")
		if int(river_overlay.get("summary", {}).get("river_candidate_count", 0)) <= 0:
			failures.append("island/water config missed deferred river/water transit candidates")
	elif river_overlay.get("explicit_no_river_state", {}).is_empty():
		warnings.append("land config has no explicit no-river state because water/coast overlay metadata exists")
	if serialization_record.get("terrain_layers", []).is_empty():
		failures.append("serialization record missed terrain layers")
	if serialization_record.get("overlay_layers", []).is_empty():
		failures.append("serialization record missed overlay layers")
	if serialization_record.get("object_instances", []).is_empty():
		failures.append("serialization record missed object instances")
	if serialization_record.get("provenance", {}).get("template_id", "") == "" or serialization_record.get("provenance", {}).get("profile_id", "") == "" or serialization_record.get("provenance", {}).get("normalized_seed", "") == "":
		failures.append("serialization record missed template/profile/seed provenance")
	if String(serialization_record.get("generator_version", "")) == "":
		failures.append("serialization record missed generator version")
	if serialization_record.get("deferred_boundary_metadata", {}).is_empty():
		failures.append("serialization record missed deferred boundary metadata")
	if String(round_trip.get("status", "")) != "pass" or not bool(round_trip.get("signature_stable", false)) or not bool(round_trip.get("key_counts_stable", false)):
		failures.append("serialization round-trip was not stable")
	if int(object_footprints.get("summary", {}).get("deferred_multitile_record_count", 0)) > 0:
		var preserved_deferred := false
		for instance in serialization_record.get("object_instances", []):
			if instance is Dictionary and not instance.get("deferred_multitile_state", {}).is_empty():
				preserved_deferred = true
				break
		if not preserved_deferred:
			failures.append("object instance serialization did not preserve deferred multitile state")
	return {
		"ok": failures.is_empty(),
		"status": "pass" if failures.is_empty() else "fail",
		"failures": failures,
		"warnings": warnings,
	}

static func _roads_rivers_writeout_validation(payload: Dictionary, generated_map: Dictionary = {}) -> Dictionary:
	var failures := []
	var warnings := []
	if String(payload.get("schema_id", "")) != ROADS_RIVERS_WRITEOUT_SCHEMA_ID:
		failures.append("roads/rivers/writeout schema mismatch")
	if String(payload.get("roads_rivers_writeout_signature", "")) == "":
		failures.append("roads/rivers/writeout signature missing")
	var core_validation: Dictionary = payload.get("validation", {}) if payload.get("validation", {}) is Dictionary else {}
	if not bool(core_validation.get("ok", false)):
		failures.append_array(core_validation.get("failures", []))
	warnings.append_array(core_validation.get("warnings", []))
	if String(payload.get("round_trip_validation", {}).get("status", "")) != "pass":
		failures.append("round-trip validation failed")
	if not generated_map.is_empty():
		var generated_constraints: Dictionary = generated_map.get("scenario_record", {}).get("generated_constraints", {}) if generated_map.get("scenario_record", {}).get("generated_constraints", {}) is Dictionary else {}
		if generated_constraints.get("roads_rivers_writeout", {}).is_empty():
			failures.append("scenario generated_constraints missed roads/rivers/writeout")
		if generated_map.get("staging", {}).get("roads_rivers_writeout", {}).is_empty():
			failures.append("staging missed roads/rivers/writeout")
		var scenario: Dictionary = generated_map.get("scenario_record", {}) if generated_map.get("scenario_record", {}) is Dictionary else {}
		if bool(scenario.get("selection", {}).get("availability", {}).get("campaign", false)) or bool(scenario.get("selection", {}).get("availability", {}).get("skirmish", false)):
			failures.append("roads/rivers/writeout adopted generated map into campaign/skirmish")
		if generated_map.has("save_adoption") or scenario.has("save_adoption") or scenario.has("alpha_parity_claim"):
			failures.append("roads/rivers/writeout exposed save/writeback/parity claim")
	return {
		"ok": failures.is_empty(),
		"status": "pass" if failures.is_empty() else "fail",
		"failures": failures,
		"warnings": warnings,
	}

static func _roads_rivers_writeout_phase_summary(payload: Dictionary) -> Dictionary:
	return {
		"schema_id": String(payload.get("schema_id", "")),
		"status": String(payload.get("status", "")),
		"signature": String(payload.get("roads_rivers_writeout_signature", "")),
		"road_tile_count": int(payload.get("summary", {}).get("road_tile_count", 0)),
		"water_overlay_tile_count": int(payload.get("summary", {}).get("water_overlay_tile_count", 0)),
		"coast_overlay_tile_count": int(payload.get("summary", {}).get("coast_overlay_tile_count", 0)),
		"river_candidate_count": int(payload.get("summary", {}).get("river_candidate_count", 0)),
		"object_instance_count": int(payload.get("summary", {}).get("object_instance_count", 0)),
		"round_trip_status": String(payload.get("summary", {}).get("round_trip_status", "")),
	}

static func _road_class_for_edge(edge: Dictionary, segment: Dictionary) -> String:
	if bool(edge.get("border_guard", false)):
		return "special_guard_gate_road"
	if int(edge.get("guard_value", 0)) > 0:
		return "guarded_route_road"
	if bool(edge.get("required", false)) and String(edge.get("role", "")) == "required_start_economy_route":
		return "start_economy_service_road"
	if bool(edge.get("required", false)):
		return "required_primary_road"
	if String(segment.get("connectivity_classification", "")) == "guarded_connectivity":
		return "guarded_route_road"
	return "connector_road"

static func _road_type_for_class(road_class: String, edge: Dictionary) -> String:
	match road_class:
		"special_guard_gate_road":
			return "generated_dirt_gate_road"
		"guarded_route_road":
			return "generated_dirt_guarded_road"
		"start_economy_service_road":
			return "generated_dirt_service_road"
		"required_primary_road":
			return "generated_dirt_primary_road"
		_:
			return "generated_dirt_connector_road"

static func _road_neighbor_mask(cells: Array, x: int, y: int) -> Dictionary:
	var lookup := _point_lookup(cells)
	return {
		"n": lookup.has(_point_key(x, y - 1)),
		"e": lookup.has(_point_key(x + 1, y)),
		"s": lookup.has(_point_key(x, y + 1)),
		"w": lookup.has(_point_key(x - 1, y)),
	}

static func _count_overlay_body_conflicts(tiles: Array) -> int:
	var count := 0
	for tile in tiles:
		if tile is Dictionary and bool(tile.get("body_conflict", false)):
			count += 1
	return count

static func _body_lookup_from_footprint_records(records: Array) -> Dictionary:
	var result := {}
	for record in records:
		if not (record is Dictionary):
			continue
		for body in record.get("body_tiles", []):
			if body is Dictionary:
				result[_point_key(int(body.get("x", 0)), int(body.get("y", 0)))] = String(record.get("placement_id", record.get("id", "")))
	return result

static func _serialization_record_signature(record: Dictionary) -> String:
	var copy: Dictionary = _json_safe_value(record)
	copy.erase("round_trip_signature")
	var parsed = JSON.parse_string(JSON.stringify(copy))
	if parsed is Dictionary:
		return _hash32_hex(_stable_stringify(parsed))
	return _hash32_hex(_stable_stringify(copy))

static func _serialization_key_counts(record: Dictionary) -> Dictionary:
	return {
		"top_level_key_count": record.keys().size(),
		"terrain_layer_count": record.get("terrain_layers", []).size(),
		"overlay_layer_count": record.get("overlay_layers", []).size(),
		"object_definition_count": record.get("object_definitions", []).size(),
		"object_instance_count": record.get("object_instances", []).size(),
		"deferred_boundary_key_count": record.get("deferred_boundary_metadata", {}).keys().size() if record.get("deferred_boundary_metadata", {}) is Dictionary else 0,
	}

static func _json_safe_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var dict_result := {}
			var dictionary: Dictionary = value
			for key in dictionary.keys():
				dict_result[String(key)] = _json_safe_value(dictionary[key])
			return dict_result
		TYPE_ARRAY:
			var array_result := []
			var array: Array = value
			for item in array:
				array_result.append(_json_safe_value(item))
			return array_result
		TYPE_VECTOR2I:
			var point: Vector2i = value
			return {"x": point.x, "y": point.y}
		TYPE_VECTOR2:
			var point: Vector2 = value
			return {"x": point.x, "y": point.y}
		_:
			return value

static func _zones_by_id(zones: Array) -> Dictionary:
	var result := {}
	for zone in zones:
		if zone is Dictionary:
			result[String(zone.get("id", ""))] = zone
	return result

static func _surface_footprints_by_zone(zone_layout: Dictionary) -> Dictionary:
	var result := {}
	var levels: Array = zone_layout.get("levels", [])
	for level in levels:
		if not (level is Dictionary) or int(level.get("level_index", 0)) != 0:
			continue
		for footprint in level.get("zone_footprints", []):
			if footprint is Dictionary:
				result[String(footprint.get("zone_id", ""))] = footprint
		break
	return result

static func _decoration_exclusion_lookup(placements: Dictionary, route_graph: Dictionary, road_network: Dictionary, zone_layout: Dictionary, monster_reward_bands: Dictionary) -> Dictionary:
	var exclusion := {}
	for placement in placements.get("object_placements", []):
		if not (placement is Dictionary):
			continue
		for body in placement.get("body_tiles", []):
			if body is Dictionary:
				exclusion[_point_key(int(body.get("x", 0)), int(body.get("y", 0)))] = "existing_object_body"
		for approach in placement.get("approach_tiles", []):
			if approach is Dictionary:
				exclusion[_point_key(int(approach.get("x", 0)), int(approach.get("y", 0)))] = "existing_object_approach"
	for segment in road_network.get("road_segments", []):
		if not (segment is Dictionary):
			continue
		for cell in segment.get("cells", []):
			if cell is Dictionary:
				exclusion[_point_key(int(cell.get("x", 0)), int(cell.get("y", 0)))] = "road_segment"
	for candidate in zone_layout.get("corridor_candidates", []):
		if not (candidate is Dictionary) or int(candidate.get("level_index", 0)) != 0:
			continue
		for cell in candidate.get("candidate_cells", []):
			if cell is Dictionary:
				exclusion[_point_key(int(cell.get("x", 0)), int(cell.get("y", 0)))] = "corridor_required_cell"
	for edge in route_graph.get("edges", []):
		if not (edge is Dictionary):
			continue
		for point_key in ["from_anchor", "to_anchor", "route_cell_anchor_candidate"]:
			var point: Dictionary = edge.get(point_key, {}) if edge.get(point_key, {}) is Dictionary else {}
			if not point.is_empty():
				exclusion[_point_key(int(point.get("x", 0)), int(point.get("y", 0)))] = "route_anchor"
	for record in monster_reward_bands.get("monster_reward_records", []):
		if record is Dictionary:
			var reward_route_id := String(record.get("route_edge_id", ""))
			for edge in route_graph.get("edges", []):
				if edge is Dictionary and String(edge.get("id", "")) == reward_route_id:
					var anchor: Dictionary = edge.get("route_cell_anchor_candidate", {}) if edge.get("route_cell_anchor_candidate", {}) is Dictionary else {}
					if not anchor.is_empty():
						exclusion[_point_key(int(anchor.get("x", 0)), int(anchor.get("y", 0)))] = "monster_reward_route_anchor"
					break
	return exclusion

static func _monster_reward_context_by_zone(monster_reward_bands: Dictionary) -> Dictionary:
	var result := {}
	for record in monster_reward_bands.get("monster_reward_records", []):
		if not (record is Dictionary):
			continue
		var zone_context: Dictionary = record.get("zone_context", {}) if record.get("zone_context", {}) is Dictionary else {}
		var zone_id := String(zone_context.get("primary_zone_id", ""))
		if zone_id == "":
			continue
		if not result.has(zone_id):
			result[zone_id] = {"record_count": 0, "normal_guard_count": 0, "special_guard_count": 0, "reward_value_total": 0, "reward_categories": []}
		var context: Dictionary = result[zone_id]
		context["record_count"] = int(context.get("record_count", 0)) + 1
		if String(record.get("guard_record_type", "")) == "normal_route_guard":
			context["normal_guard_count"] = int(context.get("normal_guard_count", 0)) + 1
		if String(record.get("guard_record_type", "")) == "special_guard_gate":
			context["special_guard_count"] = int(context.get("special_guard_count", 0)) + 1
		var reward: Dictionary = record.get("reward_band_record", {}) if record.get("reward_band_record", {}) is Dictionary else {}
		context["reward_value_total"] = int(context.get("reward_value_total", 0)) + int(reward.get("candidate_value", 0))
		var reward_category := String(reward.get("selected_reward_category_id", ""))
		var categories: Array = context.get("reward_categories", [])
		if reward_category != "" and reward_category not in categories:
			categories.append(reward_category)
			categories.sort()
		context["reward_categories"] = categories
	return result

static func _decoration_density_target(zone: Dictionary, cell_count: int, terrain_id: String, reward_context: Dictionary) -> int:
	if cell_count <= 0 or not _terrain_is_passable(terrain_id):
		return 0
	var role := String(zone.get("role", "treasure"))
	var ratio := 0.055
	if role.contains("start"):
		ratio = 0.04
	elif role == "treasure":
		ratio = 0.085
	elif role == "junction":
		ratio = 0.06
	match terrain_id:
		"forest", "swamp", "mire", "highland", "hills", "ridge":
			ratio += 0.015
		"plains":
			ratio -= 0.005
	var reward_bonus: int = min(2, int(reward_context.get("record_count", 0)))
	var target: int = int(round(float(cell_count) * ratio)) + reward_bonus
	return clampi(target, 0, max(0, int(ceil(float(cell_count) * 0.16))))

static func _decoration_density_tolerance(target: int) -> int:
	return max(1, int(ceil(float(max(1, target)) * 0.25)))

static func _decoration_candidates_for_zone(zone_id: String, cells: Array, terrain_rows: Array, occupied: Dictionary, exclusion: Dictionary, terrain_id: String, biome_id: String, seed_text: String) -> Array:
	var candidates := []
	if not _terrain_is_passable(terrain_id):
		return candidates
	for cell in cells:
		if not (cell is Dictionary):
			continue
		var x := int(cell.get("x", -1))
		var y := int(cell.get("y", -1))
		var key := _point_key(x, y)
		if occupied.has(key) or exclusion.has(key):
			continue
		if not _point_in_rows(terrain_rows, x, y) or not _terrain_cell_is_passable(terrain_rows, x, y):
			continue
		var scores := _decoration_candidate_scores(x, y, terrain_rows, occupied, exclusion, terrain_id, biome_id, seed_text, zone_id)
		if int(scores.get("hard_reject_score", 0)) <= -5000:
			continue
		candidates.append({"x": x, "y": y, "scores": scores, "sort_key": _decoration_candidate_sort_key(scores, seed_text, zone_id, x, y)})
	candidates.sort_custom(Callable(RandomMapGeneratorRules, "_compare_decoration_candidate"))
	return candidates

static func _decoration_candidate_scores(x: int, y: int, terrain_rows: Array, occupied: Dictionary, exclusion: Dictionary, terrain_id: String, biome_id: String, seed_text: String, zone_id: String) -> Dictionary:
	var hard_reject := 0
	if not _terrain_is_passable(terrain_id):
		hard_reject = -5000
	var adjacent_object_count := 0
	var adjacent_reserved_count := 0
	var adjacent_same_terrain_count := 0
	for offset in _cardinal_offsets():
		var nx := x + int(offset.x)
		var ny := y + int(offset.y)
		var key := _point_key(nx, ny)
		if occupied.has(key):
			adjacent_object_count += 1
		if exclusion.has(key):
			adjacent_reserved_count += 1
		if _point_in_rows(terrain_rows, nx, ny) and String(terrain_rows[ny][nx]) == terrain_id:
			adjacent_same_terrain_count += 1
	var terrain_score := 20 if not _decoration_families_for_terrain(terrain_id, biome_id).is_empty() else -5000
	var adjacency_score := adjacent_same_terrain_count * 3 - adjacent_object_count * 2 - adjacent_reserved_count
	var overlap_score := 12 if not occupied.has(_point_key(x, y)) and not exclusion.has(_point_key(x, y)) else -5000
	var jitter := int(_hash32_int("%s:%s:%d,%d:decor_jitter" % [seed_text, zone_id, x, y]) % 17)
	return {
		"hard_reject_score": min(hard_reject, terrain_score, overlap_score),
		"terrain_score": terrain_score,
		"adjacency_score": adjacency_score,
		"overlap_score": overlap_score,
		"seed_jitter_score": jitter,
		"total": terrain_score + adjacency_score + overlap_score + jitter,
	}

static func _decoration_candidate_sort_key(scores: Dictionary, seed_text: String, zone_id: String, x: int, y: int) -> String:
	var total := int(scores.get("total", 0))
	var jitter := int(_hash32_int("%s:%s:%d,%d:decor_order" % [seed_text, zone_id, x, y]) % 100000)
	return "%09d:%05d:%03d:%03d" % [999999999 - total, jitter, y, x]

static func _compare_decoration_candidate(a: Dictionary, b: Dictionary) -> bool:
	return String(a.get("sort_key", "")) < String(b.get("sort_key", ""))

static func _decoration_family_for_cell(terrain_id: String, biome_id: String, seed_text: String, zone_id: String, x: int, y: int, ordinal: int) -> Dictionary:
	var families := _decoration_families_for_terrain(terrain_id, biome_id)
	if families.is_empty():
		return {}
	var total := 0
	for family in families:
		total += max(1, int(family.get("weight", 1)))
	var cursor := int(_hash32_int("%s:%s:%d,%d:%d:decor_family" % [seed_text, zone_id, x, y, ordinal]) % max(1, total))
	for family in families:
		cursor -= max(1, int(family.get("weight", 1)))
		if cursor < 0:
			return family
	return families[0]

static func _decoration_families_for_terrain(terrain_id: String, biome_id: String) -> Array:
	var result := []
	for family in DECORATION_OBJECT_FAMILIES:
		if not (family is Dictionary):
			continue
		if terrain_id in family.get("terrain_ids", []) or biome_id in family.get("biome_ids", []):
			result.append(family)
	if result.is_empty() and terrain_id in ["grass", "plains"]:
		for family in DECORATION_OBJECT_FAMILIES:
			if family is Dictionary and "biome_grasslands" in family.get("biome_ids", []):
				result.append(family)
	return result

static func _decoration_known_family_ids() -> Array:
	var result := []
	for family in DECORATION_OBJECT_FAMILIES:
		if family is Dictionary:
			result.append(String(family.get("family_id", "")))
	result.sort()
	return result

static func _decoration_family_ids(records: Array) -> Array:
	var result := []
	for record in records:
		if record is Dictionary:
			var family_id := String(record.get("family_id", ""))
			if family_id != "" and family_id not in result:
				result.append(family_id)
	result.sort()
	return result

static func _decoration_sum_zone_targets(zone_targets: Array, key: String) -> int:
	var total := 0
	for target in zone_targets:
		if target is Dictionary:
			total += int(target.get(key, 0))
	return total

static func _decoration_density_target_validation(zone_targets: Array) -> Dictionary:
	var failures := []
	var warnings := []
	for target in zone_targets:
		if not (target is Dictionary):
			failures.append("non-dictionary zone density target")
			continue
		var zone_id := String(target.get("zone_id", ""))
		var effective_target := int(target.get("effective_target", 0))
		var placed := int(target.get("placed_count", 0))
		var tolerance := int(target.get("tolerance", 0))
		if abs(placed - effective_target) > tolerance:
			failures.append("zone %s placed %d outside effective target %d tolerance %d" % [zone_id, placed, effective_target, tolerance])
		if bool(target.get("capacity_limited", false)):
			warnings.append("zone %s decoration target was capacity limited by exclusions" % zone_id)
	return {
		"ok": failures.is_empty(),
		"status": "pass" if failures.is_empty() else "fail",
		"failures": failures,
		"warnings": warnings,
	}

static func _decoration_path_safety_validation(records: Array, route_graph: Dictionary, terrain_rows: Array, occupied: Dictionary, reachability: Dictionary) -> Dictionary:
	var failures := []
	var warnings := []
	var decorated_occupied := occupied.duplicate()
	for record in records:
		if not (record is Dictionary):
			failures.append("non-dictionary decoration record")
			continue
		for body in record.get("body_tiles", []):
			if body is Dictionary:
				decorated_occupied[_point_key(int(body.get("x", 0)), int(body.get("y", 0)))] = String(record.get("id", ""))
	if String(reachability.get("status", "")) != "pass":
		failures.append("required route reachability was not pass before decoration")
	for edge in route_graph.get("edges", []):
		if not (edge is Dictionary) or not bool(edge.get("required", false)):
			continue
		var from_anchor: Dictionary = edge.get("from_anchor", {}) if edge.get("from_anchor", {}) is Dictionary else {}
		var to_anchor: Dictionary = edge.get("to_anchor", {}) if edge.get("to_anchor", {}) is Dictionary else {}
		var path := _find_passable_path(from_anchor, to_anchor, terrain_rows, decorated_occupied)
		if path.is_empty():
			failures.append("required route %s became blocked by staged decoration" % String(edge.get("id", "")))
	for record in records:
		if not (record is Dictionary):
			continue
		if String(record.get("family_id", "")) not in _decoration_known_family_ids():
			failures.append("decoration %s used unknown family id %s" % [String(record.get("id", "")), String(record.get("family_id", ""))])
	return {
		"ok": failures.is_empty(),
		"status": "pass" if failures.is_empty() else "fail",
		"failures": failures,
		"warnings": warnings,
		"checked_required_route_count": _required_route_count(route_graph.get("edges", [])),
		"checked_decoration_record_count": records.size(),
	}

static func _required_route_count(edges: Array) -> int:
	var count := 0
	for edge in edges:
		if edge is Dictionary and bool(edge.get("required", false)):
			count += 1
	return count

static func _decoration_diagnostic(zone_id: String, reason: String, message: String, retryable: bool) -> Dictionary:
	return {
		"zone_id": zone_id,
		"reason": reason,
		"message": message,
		"retryable": retryable,
	}

static func _decoration_density_phase_summary(payload: Dictionary) -> Dictionary:
	return {
		"schema_id": String(payload.get("schema_id", "")),
		"status": String(payload.get("status", "")),
		"signature": String(payload.get("decoration_density_signature", "")),
		"record_count": int(payload.get("summary", {}).get("record_count", 0)),
		"effective_target_total": int(payload.get("summary", {}).get("effective_target_total", 0)),
		"path_safety_status": String(payload.get("summary", {}).get("path_safety_status", "")),
		"diagnostic_count": int(payload.get("summary", {}).get("diagnostic_count", 0)),
	}

static func _decoration_density_validation(payload: Dictionary, generated_map: Dictionary = {}) -> Dictionary:
	var failures := []
	var warnings := []
	if String(payload.get("schema_id", "")) != DECORATION_DENSITY_PASS_SCHEMA_ID:
		failures.append("decoration density schema mismatch")
	if String(payload.get("decoration_density_signature", "")) == "":
		failures.append("decoration density signature missing")
	var known_ids: Array = payload.get("known_original_family_ids", [])
	if known_ids.is_empty():
		failures.append("known original decoration family ids missing")
	for record in payload.get("decoration_records", []):
		if not (record is Dictionary):
			failures.append("decoration record is not a dictionary")
			continue
		if String(record.get("family_id", "")) not in known_ids:
			failures.append("decoration record %s used unknown original family id %s" % [String(record.get("id", "")), String(record.get("family_id", ""))])
		if record.get("body_tiles", []).is_empty():
			failures.append("decoration record %s missed body tile" % String(record.get("id", "")))
	var density_validation: Dictionary = payload.get("density_validation", {}) if payload.get("density_validation", {}) is Dictionary else {}
	if not bool(density_validation.get("ok", false)):
		failures.append_array(density_validation.get("failures", []))
	warnings.append_array(density_validation.get("warnings", []))
	var path_validation: Dictionary = payload.get("path_safety_validation", {}) if payload.get("path_safety_validation", {}) is Dictionary else {}
	if not bool(path_validation.get("ok", false)):
		failures.append_array(path_validation.get("failures", []))
	warnings.append_array(path_validation.get("warnings", []))
	if int(payload.get("summary", {}).get("record_count", 0)) <= 0:
		failures.append("no decoration records were produced")
	if not generated_map.is_empty():
		var generated_constraints: Dictionary = generated_map.get("scenario_record", {}).get("generated_constraints", {}) if generated_map.get("scenario_record", {}).get("generated_constraints", {}) is Dictionary else {}
		if generated_constraints.get("decoration_density_pass", {}).is_empty():
			failures.append("scenario generated_constraints missed decoration density pass")
		if generated_map.get("staging", {}).get("decorative_object_staging", []).is_empty():
			failures.append("staging missed decorative object records for downstream consumers")
		var scenario: Dictionary = generated_map.get("scenario_record", {}) if generated_map.get("scenario_record", {}) is Dictionary else {}
		if bool(scenario.get("selection", {}).get("availability", {}).get("campaign", false)) or bool(scenario.get("selection", {}).get("availability", {}).get("skirmish", false)):
			failures.append("decoration density adopted generated map into campaign/skirmish")
		if generated_map.has("save_adoption") or scenario.has("save_adoption") or scenario.has("alpha_parity_claim"):
			failures.append("decoration density exposed save/writeback/parity claim")
	return {
		"ok": failures.is_empty(),
		"status": "pass" if failures.is_empty() else "fail",
		"failures": failures,
		"warnings": warnings,
	}

static func _route_edges_by_id(edges: Array) -> Dictionary:
	var result := {}
	for edge in edges:
		if edge is Dictionary:
			result[String(edge.get("id", ""))] = edge
	return result

static func _monster_reward_zone_context(guard_record: Dictionary, edge: Dictionary, zones_by_id: Dictionary) -> Dictionary:
	var from_zone_id := String(guard_record.get("from", edge.get("from", "")))
	var to_zone_id := String(guard_record.get("to", edge.get("to", "")))
	var from_zone: Dictionary = zones_by_id.get(from_zone_id, {})
	var to_zone: Dictionary = zones_by_id.get(to_zone_id, {})
	var primary_zone := from_zone
	var primary_zone_id := from_zone_id
	if String(edge.get("role", "")) in ["early_reward_route", "reward_to_junction"] and not to_zone.is_empty():
		primary_zone = to_zone
		primary_zone_id = to_zone_id
	if primary_zone.is_empty() and not to_zone.is_empty():
		primary_zone = to_zone
		primary_zone_id = to_zone_id
	return {
		"primary_zone_id": primary_zone_id,
		"from_zone_id": from_zone_id,
		"to_zone_id": to_zone_id,
		"from_faction_id": String(from_zone.get("faction_id", "")),
		"to_faction_id": String(to_zone.get("faction_id", "")),
		"primary_faction_id": String(primary_zone.get("faction_id", "")),
		"primary_player_slot": primary_zone.get("player_slot", null),
		"primary_player_type": String(primary_zone.get("player_type", "neutral")),
		"terrain_id": String(primary_zone.get("terrain_id", "")),
		"biome_id": _biome_for_terrain(String(primary_zone.get("terrain_id", "grass"))),
		"monster_policy": primary_zone.get("catalog_metadata", {}).get("monster_policy", {}),
		"treasure_bands": primary_zone.get("catalog_metadata", {}).get("treasure_bands", []),
		"mine_requirements": primary_zone.get("catalog_metadata", {}).get("mine_requirements", {}),
		"resource_category_requirements": primary_zone.get("catalog_metadata", {}).get("resource_category_requirements", {}),
	}

static func _guard_stack_record_for_materialized_guard(normalized: Dictionary, guard_record: Dictionary, edge: Dictionary, zone_context: Dictionary, diagnostics: Array) -> Dictionary:
	var materialization_id := String(guard_record.get("id", ""))
	var policy: Dictionary = zone_context.get("monster_policy", {}) if zone_context.get("monster_policy", {}) is Dictionary else {}
	if policy.is_empty():
		diagnostics.append(_monster_reward_diagnostic(materialization_id, String(guard_record.get("route_edge_id", "")), "missing_monster_policy", "zone did not expose monster_policy; default neutral pool used"))
	var local_mode := _local_monster_strength_mode(String(policy.get("strength", "avg")))
	var global_mode := _global_monster_strength_mode(String(normalized.get("profile", {}).get("guard_strength_profile", "core_low")))
	var effective_mode := clampi(local_mode + global_mode - 3, 0, 5) if local_mode > 0 else 0
	var raw_guard_value := int(guard_record.get("guard_value", edge.get("guard_value", 0)))
	var base_value := raw_guard_value
	if String(guard_record.get("record_type", "")) == "special_guard_gate":
		base_value = max(500, raw_guard_value)
	var scaled_value := _scaled_monster_guard_value(base_value, effective_mode)
	var effective_value: int = max(raw_guard_value, scaled_value)
	if String(guard_record.get("record_type", "")) == "special_guard_gate":
		effective_value = max(effective_value, 500)
	var faction_pool := _monster_faction_pool(policy, zone_context, diagnostics, materialization_id, String(guard_record.get("route_edge_id", "")))
	var faction_index := _stable_choice_index(faction_pool.size(), "%s:%s:monster_faction" % [String(normalized.get("seed", "")), materialization_id])
	var selected_faction := String(faction_pool[faction_index]) if not faction_pool.is_empty() else "neutral"
	var candidates: Array = MONSTER_UNIT_POOL_BY_FACTION.get(selected_faction, MONSTER_UNIT_POOL_BY_FACTION.get("neutral", []))
	if candidates.is_empty():
		diagnostics.append(_monster_reward_diagnostic(materialization_id, String(guard_record.get("route_edge_id", "")), "missing_monster_content_pool", "selected faction %s has no guard unit pool; neutral fallback used" % selected_faction))
		candidates = MONSTER_UNIT_POOL_BY_FACTION.get("neutral", [])
	var strength_class := _guard_strength_class_from_value(effective_value)
	var tier_min := _minimum_tier_for_strength_class(strength_class)
	var tier_candidates := []
	for candidate in candidates:
		if candidate is Dictionary and int(candidate.get("tier", 1)) >= tier_min:
			tier_candidates.append(candidate)
	if tier_candidates.is_empty():
		tier_candidates = candidates
	var selected_candidate: Dictionary = tier_candidates[_stable_choice_index(tier_candidates.size(), "%s:%s:monster_unit" % [String(normalized.get("seed", "")), materialization_id])] if not tier_candidates.is_empty() else {}
	var quantity_range := _guard_quantity_range(effective_value, int(selected_candidate.get("tier", 1)))
	return {
		"id": "guard_stack_%s" % materialization_id,
		"source_materialization_id": materialization_id,
		"route_edge_id": String(guard_record.get("route_edge_id", "")),
		"monster_category_id": "%s_%s" % [selected_faction, strength_class],
		"selected_faction_id": selected_faction,
		"candidate_faction_ids": faction_pool,
		"match_to_town_applied": bool(policy.get("match_to_town", false)) and String(zone_context.get("primary_faction_id", "")) != "",
		"local_strength_mode": local_mode,
		"global_strength_mode": global_mode,
		"effective_strength_mode": effective_mode,
		"raw_guard_value": raw_guard_value,
		"scaled_guard_value": scaled_value,
		"effective_guard_value": effective_value,
		"strength_class": strength_class,
		"selected_unit_id": String(selected_candidate.get("unit_id", "")),
		"selected_unit_tier": int(selected_candidate.get("tier", 1)),
		"selected_unit_role": String(selected_candidate.get("role", "")),
		"quantity_range": quantity_range,
		"stack_value_range": {"min": max(0, int(floor(float(effective_value) * 0.8))), "max": max(effective_value, int(ceil(float(effective_value) * 1.2)))},
		"selection_signature": _hash32_hex(_stable_stringify({"seed": String(normalized.get("seed", "")), "materialization_id": materialization_id, "faction": selected_faction, "unit": selected_candidate})),
		"content_ref_state": "original_unit_id_selected" if String(selected_candidate.get("unit_id", "")) != "" else "deferred_missing_unit_ref",
	}

static func _monster_faction_pool(policy: Dictionary, zone_context: Dictionary, diagnostics: Array, materialization_id: String, route_edge_id: String) -> Array:
	var primary_faction := String(zone_context.get("primary_faction_id", ""))
	if bool(policy.get("match_to_town", false)) and primary_faction != "":
		return [primary_faction]
	var allowed := _normalized_string_array(policy.get("allowed_faction_ids", []), ["neutral"])
	var result := []
	for faction_id in allowed:
		var text := String(faction_id)
		if text == "":
			continue
		if text == "neutral" or MONSTER_UNIT_POOL_BY_FACTION.has(text):
			if text not in result:
				result.append(text)
		else:
			diagnostics.append(_monster_reward_diagnostic(materialization_id, route_edge_id, "unsupported_monster_faction_ref", "monster faction %s has no current original guard pool" % text))
	if result.is_empty():
		result.append("neutral")
	return result

static func _reward_band_record_for_materialized_guard(normalized: Dictionary, guard_record: Dictionary, edge: Dictionary, zone_context: Dictionary, guard_stack: Dictionary, diagnostics: Array) -> Dictionary:
	var materialization_id := String(guard_record.get("id", ""))
	var eligible_bands := _eligible_treasure_bands(zone_context.get("treasure_bands", []))
	var source := "template_treasure_band"
	if eligible_bands.is_empty():
		source = "route_context_fallback"
		eligible_bands = [_fallback_reward_band_for_guard(guard_record, edge)]
		diagnostics.append(_monster_reward_diagnostic(materialization_id, String(guard_record.get("route_edge_id", "")), "missing_eligible_treasure_band", "zone had no eligible treasure band; route context fallback used"))
	var band := _weighted_band_choice(eligible_bands, "%s:%s:reward_band" % [String(normalized.get("seed", "")), materialization_id])
	var category_link := _select_reward_resource_category(zone_context, band, guard_stack, normalized, materialization_id)
	var candidate := _reward_candidate_for_band(band, category_link, normalized, materialization_id, diagnostics, String(guard_record.get("route_edge_id", "")))
	var low := int(band.get("low", 0))
	var high := int(band.get("high", low))
	return {
		"id": "reward_band_%s" % materialization_id,
		"source_materialization_id": materialization_id,
		"route_edge_id": String(guard_record.get("route_edge_id", "")),
		"source": source,
		"selected_band": {"low": low, "high": high, "density": int(band.get("density", 0))},
		"risk_class": String(guard_stack.get("strength_class", "")),
		"value_range": {"min": low, "max": high},
		"selected_reward_category_id": String(candidate.get("reward_category", "resource_cache")),
		"selected_reward_object_id": String(candidate.get("object_id", "")),
		"selected_reward_family_id": String(candidate.get("object_family_id", "")),
		"selected_resource_category_id": String(category_link.get("original_category_id", "")),
		"category_link": category_link,
		"candidate_value": int(candidate.get("value", 0)),
		"selection_signature": _hash32_hex(_stable_stringify({"seed": String(normalized.get("seed", "")), "materialization_id": materialization_id, "band": band, "candidate": candidate, "category": category_link})),
		"content_ref_state": "original_reward_ref_selected" if String(candidate.get("object_id", "")) != "" else "deferred_missing_reward_ref",
		"object_footprint_catalog_ref": _object_footprint_ref_for_reward_candidate(candidate),
		"deferred_reward_materialization": [
			"final_reward_object_placement",
			"artifact_spell_skill_reward_pool_finalization" if String(candidate.get("reward_category", "")) in ["artifact", "spell_access"] else "none",
		],
	}

static func _eligible_treasure_bands(bands: Variant) -> Array:
	var result := []
	if not (bands is Array):
		return result
	for band in bands:
		if not (band is Dictionary):
			continue
		if int(band.get("low", 0)) >= 100 and int(band.get("density", 0)) > 0:
			result.append({"low": int(band.get("low", 0)), "high": int(band.get("high", band.get("low", 0))), "density": int(band.get("density", 0))})
	return result

static func _fallback_reward_band_for_guard(guard_record: Dictionary, edge: Dictionary) -> Dictionary:
	var pressure: int = max(int(guard_record.get("guard_value", 0)), _effective_guard_pressure(edge))
	if pressure <= 200:
		return {"low": 100, "high": 450, "density": 1}
	if pressure <= 700:
		return {"low": 450, "high": 1100, "density": 1}
	return {"low": 900, "high": 2200, "density": 1}

static func _weighted_band_choice(bands: Array, seed_text: String) -> Dictionary:
	if bands.is_empty():
		return {"low": 100, "high": 450, "density": 1}
	var total := 0
	for band in bands:
		if band is Dictionary:
			total += max(1, int(band.get("density", 1)))
	var cursor := int(_hash32_int(seed_text) % max(1, total))
	for band in bands:
		if not (band is Dictionary):
			continue
		cursor -= max(1, int(band.get("density", 1)))
		if cursor < 0:
			return band
	return bands[0]

static func _select_reward_resource_category(zone_context: Dictionary, band: Dictionary, guard_stack: Dictionary, normalized: Dictionary, materialization_id: String) -> Dictionary:
	var weighted := []
	var requirements: Dictionary = zone_context.get("resource_category_requirements", {}) if zone_context.get("resource_category_requirements", {}) is Dictionary else {}
	var minimums: Dictionary = requirements.get("minimum_by_category", {}) if requirements.get("minimum_by_category", {}) is Dictionary else {}
	var densities: Dictionary = requirements.get("density_by_category", {}) if requirements.get("density_by_category", {}) is Dictionary else {}
	for category in ORIGINAL_RESOURCE_CATEGORY_ORDER:
		var category_id := String(category.get("original_category_id", ""))
		var weight := int(minimums.get(category_id, 0)) * 3 + int(densities.get(category_id, 0))
		if weight > 0:
			weighted.append({"category": category, "weight": weight})
	if weighted.is_empty():
		for category in ORIGINAL_RESOURCE_CATEGORY_ORDER:
			weighted.append({"category": category, "weight": 1})
	var total := 0
	for item in weighted:
		total += max(1, int(item.get("weight", 1)))
	var cursor := int(_hash32_int("%s:%s:%s:%s" % [String(normalized.get("seed", "")), materialization_id, _stable_stringify(band), String(guard_stack.get("selected_faction_id", ""))]) % max(1, total))
	var selected: Dictionary = weighted[0].get("category", {})
	for item in weighted:
		cursor -= max(1, int(item.get("weight", 1)))
		if cursor < 0:
			selected = item.get("category", {})
			break
	return selected.duplicate(true)

static func _reward_candidate_for_band(band: Dictionary, category_link: Dictionary, normalized: Dictionary, materialization_id: String, diagnostics: Array, route_edge_id: String) -> Dictionary:
	var low := int(band.get("low", 0))
	var high := int(band.get("high", low))
	var category_id := String(category_link.get("original_category_id", ""))
	var candidates := []
	for candidate in REWARD_BAND_CANDIDATES:
		if not (candidate is Dictionary):
			continue
		if int(candidate.get("value", 0)) < low or int(candidate.get("value", 0)) > high:
			continue
		if category_id not in candidate.get("categories", []):
			continue
		candidates.append(candidate)
	if candidates.is_empty():
		for candidate in REWARD_BAND_CANDIDATES:
			if candidate is Dictionary and int(candidate.get("value", 0)) >= low and int(candidate.get("value", 0)) <= high:
				candidates.append(candidate)
	if candidates.is_empty():
		diagnostics.append(_monster_reward_diagnostic(materialization_id, route_edge_id, "reward_candidate_range_exhausted", "no reward candidate matched value range %d..%d; nearest staged placeholder used" % [low, high]))
		return REWARD_BAND_CANDIDATES[0]
	var total := 0
	for candidate in candidates:
		total += max(1, int(candidate.get("weight", 1)))
	var cursor := int(_hash32_int("%s:%s:reward_candidate" % [String(normalized.get("seed", "")), materialization_id]) % max(1, total))
	for candidate in candidates:
		cursor -= max(1, int(candidate.get("weight", 1)))
		if cursor < 0:
			return candidate
	return candidates[0]

static func _guard_reward_category_links(zone_context: Dictionary, guard_stack: Dictionary, reward_band: Dictionary) -> Dictionary:
	var category_id := String(reward_band.get("selected_resource_category_id", ""))
	var category_record := _resource_category_record(category_id)
	return {
		"primary_resource_category_id": category_id,
		"source_equivalent": String(category_record.get("source_equivalent", "")),
		"category_index": int(category_record.get("index", -1)),
		"mine_family_id": String(category_record.get("mine_family_id", "")),
		"mine_requirement_context": _zone_category_requirement_record(zone_context, category_id),
		"guard_category_id": String(guard_stack.get("monster_category_id", "")),
		"reward_category_id": String(reward_band.get("selected_reward_category_id", "")),
		"link_state": "guard_reward_category_link_staged_mine_placement_downstream",
	}

static func _resource_category_record(category_id: String) -> Dictionary:
	for category in ORIGINAL_RESOURCE_CATEGORY_ORDER:
		if String(category.get("original_category_id", "")) == category_id:
			return category
	return {}

static func _zone_category_requirement_record(zone_context: Dictionary, category_id: String) -> Dictionary:
	var requirements: Dictionary = zone_context.get("resource_category_requirements", {}) if zone_context.get("resource_category_requirements", {}) is Dictionary else {}
	var mine_requirements: Dictionary = zone_context.get("mine_requirements", {}) if zone_context.get("mine_requirements", {}) is Dictionary else {}
	var minimums: Dictionary = requirements.get("minimum_by_category", {}) if requirements.get("minimum_by_category", {}) is Dictionary else {}
	var densities: Dictionary = requirements.get("density_by_category", {}) if requirements.get("density_by_category", {}) is Dictionary else {}
	var mine_minimums: Dictionary = mine_requirements.get("minimum_by_category", {}) if mine_requirements.get("minimum_by_category", {}) is Dictionary else {}
	var mine_densities: Dictionary = mine_requirements.get("density_by_category", {}) if mine_requirements.get("density_by_category", {}) is Dictionary else {}
	return {
		"resource_minimum": int(minimums.get(category_id, 0)),
		"resource_density": int(densities.get(category_id, 0)),
		"mine_minimum": int(mine_minimums.get(category_id, 0)),
		"mine_density": int(mine_densities.get(category_id, 0)),
	}

static func _special_unlock_semantics_for_guard(guard_record: Dictionary, reward_band: Dictionary) -> Dictionary:
	if String(guard_record.get("record_type", "")) != "special_guard_gate":
		return {"unlock_required": false, "state": "normal_guard_no_special_unlock"}
	var unlock: Dictionary = guard_record.get("required_unlock_metadata", {}) if guard_record.get("required_unlock_metadata", {}) is Dictionary else {}
	return {
		"unlock_required": bool(unlock.get("unlock_required", true)),
		"unlock_model": String(unlock.get("unlock_model", "border_guard_gate_or_key_placeholder")),
		"subtype_placeholder": int(unlock.get("subtype_placeholder", 0)),
		"key_reward_placeholder": {
			"reward_band_record_id": String(reward_band.get("id", "")),
			"reward_category_id": String(reward_band.get("selected_reward_category_id", "")),
			"materialization_state": "key_or_unlock_reward_placeholder_deferred",
		},
	}

static func _monster_reward_terrain_context(edge: Dictionary, terrain_transit: Dictionary, zone_context: Dictionary) -> Dictionary:
	return {
		"terrain_id": String(zone_context.get("terrain_id", "")),
		"biome_id": String(zone_context.get("biome_id", "")),
		"route_transit_semantics": edge.get("transit_semantics", {}),
		"terrain_transit_signature": String(terrain_transit.get("terrain_transit_signature", "")),
	}

static func _seven_category_semantics_payload(zones: Array, records: Array) -> Dictionary:
	var zones_payload := []
	for zone in zones:
		if not (zone is Dictionary):
			continue
		var context := {
			"resource_category_requirements": zone.get("catalog_metadata", {}).get("resource_category_requirements", {}),
			"mine_requirements": zone.get("catalog_metadata", {}).get("mine_requirements", {}),
		}
		var categories := []
		for category in ORIGINAL_RESOURCE_CATEGORY_ORDER:
			var category_id := String(category.get("original_category_id", ""))
			var category_payload: Dictionary = category.duplicate(true)
			category_payload["requirements"] = _zone_category_requirement_record(context, category_id)
			categories.append(category_payload)
		zones_payload.append({
			"zone_id": String(zone.get("id", "")),
			"role": String(zone.get("role", "")),
			"owner_slot": zone.get("owner_slot", null),
			"player_slot": zone.get("player_slot", null),
			"faction_id": String(zone.get("faction_id", "")),
			"categories": categories,
		})
	var record_links := []
	for record in records:
		if record is Dictionary:
			record_links.append({
				"monster_reward_record_id": String(record.get("id", "")),
				"route_edge_id": String(record.get("route_edge_id", "")),
				"primary_resource_category_id": String(record.get("seven_category_links", {}).get("primary_resource_category_id", "")),
				"guard_category_id": String(record.get("seven_category_links", {}).get("guard_category_id", "")),
				"reward_category_id": String(record.get("seven_category_links", {}).get("reward_category_id", "")),
			})
	return {
		"schema_id": "random_map_original_seven_resource_categories_v1",
		"category_order": ORIGINAL_RESOURCE_CATEGORY_ORDER,
		"zones": zones_payload,
		"guard_reward_category_links": record_links,
		"downstream_state": "mine_resource_placement_consumes_categories_in_later_slice",
	}

static func _annotate_monster_reward_references(records: Array, placements: Dictionary) -> void:
	var by_route := {}
	for record in records:
		if record is Dictionary:
			var route_edge_id := String(record.get("route_edge_id", ""))
			if not by_route.has(route_edge_id):
				by_route[route_edge_id] = []
			by_route[route_edge_id].append(record)
	for placement in placements.get("object_placements", []):
		if not (placement is Dictionary):
			continue
		var route_id := String(placement.get("route_edge_id", ""))
		if route_id == "" or not by_route.has(route_id):
			continue
		placement["monster_reward_band_ids"] = _monster_reward_ids(by_route[route_id])
		placement["guard_stack_record_ids"] = _guard_stack_ids(by_route[route_id])
		placement["reward_band_record_ids"] = _reward_band_ids(by_route[route_id])
	for encounter in placements.get("encounters", []):
		if not (encounter is Dictionary):
			continue
		var route_id := String(encounter.get("route_edge_id", ""))
		if route_id == "" or not by_route.has(route_id):
			continue
		encounter["monster_reward_band_ids"] = _monster_reward_ids(by_route[route_id])
		encounter["guard_stack_record_ids"] = _guard_stack_ids(by_route[route_id])
		encounter["reward_band_record_ids"] = _reward_band_ids(by_route[route_id])
		var first_record: Dictionary = by_route[route_id][0]
		encounter["generated_guard_stack"] = first_record.get("guard_stack_record", {})
		encounter["generated_reward_band"] = first_record.get("reward_band_record", {})

static func _monster_reward_ids(records: Array) -> Array:
	var result := []
	for record in records:
		if record is Dictionary:
			result.append(String(record.get("id", "")))
	return result

static func _guard_stack_ids(records: Array) -> Array:
	var result := []
	for record in records:
		if record is Dictionary:
			result.append(String(record.get("guard_stack_record", {}).get("id", "")))
	return result

static func _reward_band_ids(records: Array) -> Array:
	var result := []
	for record in records:
		if record is Dictionary:
			result.append(String(record.get("reward_band_record", {}).get("id", "")))
	return result

static func _attach_monster_reward_id_to_edge(edge: Dictionary, record_id: String) -> void:
	var ids: Array = edge.get("monster_reward_band_ids", [])
	if record_id not in ids:
		ids.append(record_id)
	edge["monster_reward_band_ids"] = ids

static func _count_monster_reward_records_by_guard_type(records: Array, guard_type: String) -> int:
	var count := 0
	for record in records:
		if record is Dictionary and String(record.get("guard_record_type", "")) == guard_type:
			count += 1
	return count

static func _monster_reward_diagnostic(materialization_id: String, route_edge_id: String, reason: String, message: String) -> Dictionary:
	return {
		"source_materialization_id": materialization_id,
		"route_edge_id": route_edge_id,
		"reason": reason,
		"message": message,
		"retryable": false,
	}

static func _local_monster_strength_mode(value: String) -> int:
	match value.strip_edges().to_lower():
		"n", "none", "0":
			return 0
		"w", "weak", "2":
			return 2
		"s", "strong", "4":
			return 4
		"a", "avg", "average", "normal", "3":
			return 3
		_:
			return 3

static func _global_monster_strength_mode(value: String) -> int:
	var key := value.strip_edges().to_lower()
	if key == "random":
		return 3
	return int(MONSTER_STRENGTH_PROFILE_MODE.get(key, 3))

static func _scaled_monster_guard_value(base_value: int, mode: int) -> int:
	var thresholds_1 := [50000, 2500, 1500, 1000, 500, 0]
	var thresholds_2 := [50000, 7500, 7500, 7500, 5000, 5000]
	var slopes_1 := [0, 2, 3, 4, 6, 6]
	var slopes_2 := [0, 2, 3, 4, 4, 6]
	var clamped_mode := clampi(mode, 0, 5)
	var value := 0
	if base_value > int(thresholds_1[clamped_mode]):
		value += int((base_value - int(thresholds_1[clamped_mode])) * int(slopes_1[clamped_mode]) / 4)
	if base_value > int(thresholds_2[clamped_mode]):
		value += int((base_value - int(thresholds_2[clamped_mode])) * int(slopes_2[clamped_mode]) / 4)
	if value < 2000:
		return 0
	return value

static func _guard_strength_class_from_value(value: int) -> String:
	if value <= 0:
		return "none"
	if value <= 200:
		return "low"
	if value <= 700:
		return "medium"
	if value <= 1800:
		return "high"
	return "elite"

static func _minimum_tier_for_strength_class(strength_class: String) -> int:
	match strength_class:
		"medium":
			return 2
		"high", "elite":
			return 3
		_:
			return 1

static func _guard_quantity_range(value: int, tier: int) -> Dictionary:
	var divisor: int = max(60, tier * 90)
	var base: int = max(1, int(ceil(float(max(1, value)) / float(divisor))))
	return {"min": max(1, int(floor(float(base) * 0.75))), "max": max(1, int(ceil(float(base) * 1.25)))}

static func _monster_reward_bands_phase_summary(payload: Dictionary) -> Dictionary:
	return {
		"schema_id": String(payload.get("schema_id", "")),
		"status": String(payload.get("status", "")),
		"signature": String(payload.get("monster_reward_bands_signature", "")),
		"record_count": int(payload.get("summary", {}).get("record_count", 0)),
		"guard_stack_count": int(payload.get("summary", {}).get("guard_stack_count", 0)),
		"reward_band_count": int(payload.get("summary", {}).get("reward_band_count", 0)),
		"special_guard_record_count": int(payload.get("summary", {}).get("special_guard_record_count", 0)),
		"diagnostic_count": int(payload.get("summary", {}).get("diagnostic_count", 0)),
	}

static func _monster_reward_bands_validation(payload: Dictionary, generated_map: Dictionary = {}) -> Dictionary:
	var failures := []
	var warnings := []
	if String(payload.get("schema_id", "")) != MONSTER_REWARD_BANDS_SCHEMA_ID:
		failures.append("monster reward bands schema mismatch")
	if String(payload.get("monster_reward_bands_signature", "")) == "":
		failures.append("monster reward bands signature missing")
	if int(payload.get("summary", {}).get("record_count", 0)) <= 0:
		failures.append("no monster reward records were produced")
	var has_normal := false
	var has_special := false
	for record in payload.get("monster_reward_records", []):
		if not (record is Dictionary):
			failures.append("monster reward record is not a dictionary")
			continue
		var guard_stack: Dictionary = record.get("guard_stack_record", {}) if record.get("guard_stack_record", {}) is Dictionary else {}
		var reward_band: Dictionary = record.get("reward_band_record", {}) if record.get("reward_band_record", {}) is Dictionary else {}
		if String(record.get("guard_record_type", "")) == "normal_route_guard":
			has_normal = true
		if String(record.get("guard_record_type", "")) == "special_guard_gate":
			has_special = true
		if String(guard_stack.get("selected_unit_id", "")) == "" or String(guard_stack.get("strength_class", "")) == "":
			failures.append("guard stack %s missed selected unit or strength class" % String(guard_stack.get("id", "")))
		if String(reward_band.get("selected_reward_category_id", "")) == "" or int(reward_band.get("value_range", {}).get("max", 0)) < int(reward_band.get("value_range", {}).get("min", 0)):
			failures.append("reward band %s missed category or valid value range" % String(reward_band.get("id", "")))
		if record.get("seven_category_links", {}).is_empty():
			failures.append("monster reward record %s missed seven-category link metadata" % String(record.get("id", "")))
		if String(record.get("guard_record_type", "")) == "special_guard_gate" and not bool(record.get("special_unlock_semantics", {}).get("unlock_required", false)):
			failures.append("special guard record %s missed unlock semantics" % String(record.get("id", "")))
	if not has_normal:
		failures.append("normal route guards did not produce monster reward records")
	var expected_special_count := 0
	if not generated_map.is_empty():
		expected_special_count = int(generated_map.get("staging", {}).get("connection_guard_materialization", {}).get("summary", {}).get("expected_special_guard_gate_count", 0))
	else:
		expected_special_count = int(payload.get("summary", {}).get("special_guard_record_count", 0))
	if expected_special_count > 0 and not has_special:
		failures.append("special guard gates did not produce monster reward records")
	if payload.get("seven_category_semantics", {}).get("zones", []).is_empty():
		failures.append("seven-category zone semantics missing")
	for diagnostic in payload.get("diagnostics", []):
		if diagnostic is Dictionary:
			warnings.append("%s:%s" % [String(diagnostic.get("route_edge_id", "")), String(diagnostic.get("reason", ""))])
	if not generated_map.is_empty():
		var ids := {}
		for record in payload.get("monster_reward_records", []):
			if record is Dictionary:
				ids[String(record.get("id", ""))] = true
		var route_ref_count := 0
		for edge in generated_map.get("staging", {}).get("route_graph", {}).get("edges", []):
			if not (edge is Dictionary):
				continue
			for id_value in edge.get("monster_reward_band_ids", []):
				if not ids.has(String(id_value)):
					failures.append("route edge %s referenced unknown monster reward id %s" % [String(edge.get("id", "")), String(id_value)])
				route_ref_count += 1
		if route_ref_count <= 0:
			failures.append("route graph did not reference monster reward records")
		var placement_ref_count := 0
		for placement in generated_map.get("staging", {}).get("object_placements", []):
			if placement is Dictionary:
				placement_ref_count += placement.get("monster_reward_band_ids", []).size()
		for encounter in generated_map.get("scenario_record", {}).get("encounters", []):
			if encounter is Dictionary:
				placement_ref_count += encounter.get("monster_reward_band_ids", []).size()
		if placement_ref_count <= 0:
			failures.append("object placements or encounters did not reference monster reward records")
		if generated_map.get("scenario_record", {}).get("generated_constraints", {}).get("monster_reward_bands", {}).is_empty():
			failures.append("scenario generated_constraints missed monster reward bands")
		var scenario: Dictionary = generated_map.get("scenario_record", {}) if generated_map.get("scenario_record", {}) is Dictionary else {}
		if bool(scenario.get("selection", {}).get("availability", {}).get("campaign", false)) or bool(scenario.get("selection", {}).get("availability", {}).get("skirmish", false)):
			failures.append("monster reward bands adopted generated map into campaign/skirmish")
		if generated_map.has("save_adoption") or scenario.has("alpha_parity_claim"):
			failures.append("monster reward bands exposed save/writeback/parity claim")
	return {
		"ok": failures.is_empty(),
		"status": "pass" if failures.is_empty() else "fail",
		"failures": failures,
		"warnings": warnings,
	}

static func _connection_guard_source_link(edge_id: String, index: int, link: Dictionary, edge: Dictionary) -> Dictionary:
	return {
		"id": edge_id,
		"index": index,
		"from": String(link.get("from", "")),
		"to": String(link.get("to", "")),
		"role": String(link.get("role", "")),
		"guard_value": int(link.get("guard_value", 0)),
		"wide": bool(link.get("wide", false)),
		"border_guard": bool(link.get("border_guard", false)),
		"route_classification": String(edge.get("connectivity_classification", "")),
		"source_endpoints": link.get("source_endpoints", {}),
		"grammar_source": link.get("grammar_source", {}),
	}

static func _connection_guard_diagnostic(edge_id: String, from_zone: String, to_zone: String, reason: String, retryable: bool, message: String) -> Dictionary:
	return {
		"route_edge_id": edge_id,
		"from": from_zone,
		"to": to_zone,
		"reason": reason,
		"retryable": retryable,
		"message": message,
	}

static func _attach_materialization_id_to_edge(edge: Dictionary, record_id: String) -> void:
	var ids: Array = edge.get("connection_guard_materialization_ids", [])
	if record_id not in ids:
		ids.append(record_id)
	edge["connection_guard_materialization_ids"] = ids

static func _placements_by_route_edge(object_placements: Array) -> Dictionary:
	var result := {}
	for placement in object_placements:
		if not (placement is Dictionary):
			continue
		var route_edge_id := String(placement.get("route_edge_id", ""))
		if route_edge_id == "":
			continue
		if not result.has(route_edge_id):
			result[route_edge_id] = []
		result[route_edge_id].append(placement)
	return result

static func _road_cells_by_route_edge(road_segments: Array) -> Dictionary:
	var result := {}
	for segment in road_segments:
		if not (segment is Dictionary):
			continue
		var route_edge_id := String(segment.get("route_edge_id", ""))
		if route_edge_id == "":
			continue
		result[route_edge_id] = segment.get("cells", [])
	return result

static func _placement_candidate_for_route(candidates: Array, expected_kind: String) -> Dictionary:
	for placement in candidates:
		if not (placement is Dictionary):
			continue
		if expected_kind != "" and String(placement.get("kind", "")) != expected_kind:
			continue
		return {
			"placement_id": String(placement.get("placement_id", "")),
			"kind": String(placement.get("kind", "")),
			"zone_id": String(placement.get("zone_id", "")),
			"x": int(placement.get("x", 0)),
			"y": int(placement.get("y", 0)),
			"body_tiles": placement.get("body_tiles", []),
			"approach_tiles": placement.get("approach_tiles", []),
			"pathing_status": String(placement.get("pathing_status", "")),
			"object_footprint_catalog_ref": placement.get("object_footprint_catalog_ref", {}),
			"passability_mask": placement.get("passability_mask", {}),
			"action_mask": placement.get("action_mask", {}),
		}
	return {}

static func _connection_guard_materialization_phase_summary(materialization: Dictionary) -> Dictionary:
	return {
		"schema_id": String(materialization.get("schema_id", "")),
		"status": String(materialization.get("status", "")),
		"signature": String(materialization.get("connection_guard_materialization_signature", "")),
		"normal_guard_count": int(materialization.get("summary", {}).get("normal_guard_count", 0)),
		"special_guard_gate_count": int(materialization.get("summary", {}).get("special_guard_gate_count", 0)),
		"wide_suppression_count": int(materialization.get("summary", {}).get("wide_suppression_count", 0)),
		"diagnostic_count": int(materialization.get("summary", {}).get("diagnostic_count", 0)),
	}

static func _connection_guard_materialization_validation(materialization: Dictionary, generated_map: Dictionary = {}) -> Dictionary:
	var failures := []
	var warnings := []
	if String(materialization.get("schema_id", "")) != CONNECTION_GUARD_MATERIALIZATION_SCHEMA_ID:
		failures.append("connection guard materialization schema mismatch")
	if String(materialization.get("connection_guard_materialization_signature", "")) == "":
		failures.append("connection guard materialization signature missing")
	var summary: Dictionary = materialization.get("summary", {})
	if int(summary.get("expected_normal_guard_count", 0)) + int(summary.get("expected_special_guard_gate_count", 0)) > 0 and materialization.get("materialized_records", []).is_empty():
		failures.append("no materialized normal or special connection guard records")
	if int(summary.get("expected_normal_guard_count", 0)) > 0 and materialization.get("normal_route_guards", []).is_empty():
		failures.append("normal guarded links produced no materialized records")
	if int(summary.get("expected_wide_suppression_count", 0)) > 0 and materialization.get("wide_suppressions", []).is_empty():
		failures.append("wide links produced no suppression records")
	if int(summary.get("expected_special_guard_gate_count", 0)) > 0 and materialization.get("special_guard_gates", []).is_empty():
		failures.append("border/special links produced no special gate records")
	for record in materialization.get("normal_route_guards", []):
		if not (record is Dictionary):
			failures.append("normal guard record is not a dictionary")
			continue
		if int(record.get("guard_value", 0)) <= 0:
			failures.append("normal guard %s has no positive guard value" % String(record.get("id", "")))
		if bool(record.get("source_link", {}).get("wide", false)) or bool(record.get("source_link", {}).get("border_guard", false)):
			failures.append("normal guard %s was materialized from wide or border link" % String(record.get("id", "")))
		if record.get("route_cell_anchor_candidate", {}).is_empty():
			failures.append("normal guard %s missing route anchor candidate" % String(record.get("id", "")))
		if record.get("monster_category_placeholder", {}).is_empty() or record.get("reward_category_placeholder", {}).is_empty():
			failures.append("normal guard %s missed downstream monster/reward placeholders" % String(record.get("id", "")))
	for record in materialization.get("wide_suppressions", []):
		if not (record is Dictionary):
			failures.append("wide suppression record is not a dictionary")
			continue
		if bool(record.get("normal_guard_materialized", true)):
			failures.append("wide suppression %s still materialized a normal guard" % String(record.get("id", "")))
		if String(record.get("suppression_reason", "")) == "":
			failures.append("wide suppression %s missed reason" % String(record.get("id", "")))
	for record in materialization.get("special_guard_gates", []):
		if not (record is Dictionary):
			failures.append("special guard record is not a dictionary")
			continue
		if String(record.get("special_guard_type", "")) == "":
			failures.append("special guard %s missed special type" % String(record.get("id", "")))
		if not bool(record.get("required_unlock_metadata", {}).get("unlock_required", false)):
			failures.append("special guard %s missed required unlock metadata" % String(record.get("id", "")))
		if record.get("route_cell_anchor_candidate", {}).is_empty():
			failures.append("special guard %s missing route anchor candidate" % String(record.get("id", "")))
	for diagnostic in materialization.get("diagnostics", []):
		if diagnostic is Dictionary:
			warnings.append("%s:%s" % [String(diagnostic.get("route_edge_id", "")), String(diagnostic.get("reason", ""))])
	var scenario: Dictionary = generated_map.get("scenario_record", {}) if generated_map.get("scenario_record", {}) is Dictionary else {}
	if bool(scenario.get("selection", {}).get("availability", {}).get("campaign", false)) or bool(scenario.get("selection", {}).get("availability", {}).get("skirmish", false)):
		failures.append("connection guard materialization adopted generated map into campaign/skirmish")
	if generated_map.has("save_adoption") or scenario.has("alpha_parity_claim"):
		failures.append("connection guard materialization exposed save/writeback/parity claim")
	return {
		"ok": failures.is_empty(),
		"status": "pass" if failures.is_empty() else "fail",
		"failures": failures,
		"warnings": warnings,
	}

static func _terrain_constraints_payload(terrain_rows: Array, zone_grid: Array, zones: Array, terrain_transit: Dictionary = {}) -> Dictionary:
	var passability_rows := []
	var biome_rows := []
	var movement_cost_rows := []
	var terrain_counts := {}
	var blocked_cells := []
	for y in range(terrain_rows.size()):
		var terrain_row: Array = terrain_rows[y]
		var pass_row := []
		var biome_row := []
		var cost_row := []
		for x in range(terrain_row.size()):
			var terrain_id := String(terrain_row[x])
			var passable := _terrain_is_passable(terrain_id)
			pass_row.append(passable)
			biome_row.append(_biome_for_terrain(terrain_id))
			cost_row.append(_terrain_movement_cost(terrain_id))
			terrain_counts[terrain_id] = int(terrain_counts.get(terrain_id, 0)) + 1
			if not passable:
				blocked_cells.append(_point_dict(x, y))
		passability_rows.append(pass_row)
		biome_rows.append(biome_row)
		movement_cost_rows.append(cost_row)
	var zone_summaries := []
	for zone in zones:
		if not (zone is Dictionary):
			continue
		var terrain_id := String(zone.get("terrain_id", "grass"))
		zone_summaries.append({
			"zone_id": String(zone.get("id", "")),
			"role": String(zone.get("role", "")),
			"biome_id": _biome_for_terrain(terrain_id),
			"terrain_id": terrain_id,
			"terrain_palette": zone.get("terrain_palette", {}),
			"passable": _terrain_is_passable(terrain_id),
			"cell_count": int(zone.get("cell_count", 0)),
			"bounds": zone.get("bounds", {}),
		})
	return {
		"coherence_model": "zone_biome_fill_with_deterministic_island_smoothing_and_passability_grid",
		"biome_by_terrain": _sorted_dict(BIOME_BY_TERRAIN),
		"passability_source": "content_biome_passable_semantics_collapsed_for_generated_payload",
		"passability_grid": passability_rows,
		"biome_grid": biome_rows,
		"movement_cost_grid": movement_cost_rows,
		"blocked_cells": blocked_cells,
		"terrain_counts": _sorted_dict(terrain_counts),
		"region_count_by_terrain": _terrain_region_counts(terrain_rows),
		"zone_biome_summary": zone_summaries,
		"terrain_transit_signature": String(terrain_transit.get("terrain_transit_signature", "")),
		"water_coast_passability": terrain_transit.get("water_coast_passability", {}),
	}

static func _build_route_and_road_payload(links: Array, seeds: Dictionary, placements: Dictionary, terrain_rows: Array, occupied: Dictionary, terrain_transit: Dictionary = {}) -> Dictionary:
	var object_by_zone := _object_placements_by_zone_and_kind(placements.get("object_placements", []))
	var route_nodes := _route_nodes_payload(seeds, placements)
	var road_segments := []
	var road_stubs := []
	var edges := []
	var adjacency := {}
	var edge_index := 1
	for link in links:
		if not (link is Dictionary):
			continue
		var from_zone := String(link.get("from", ""))
		var to_zone := String(link.get("to", ""))
		var from_node := _preferred_route_node_for_zone(from_zone, object_by_zone, route_nodes)
		var to_node := _preferred_route_node_for_zone(to_zone, object_by_zone, route_nodes)
		var from_point: Dictionary = from_node.get("point", seeds.get(from_zone, {}))
		var to_point: Dictionary = to_node.get("point", seeds.get(to_zone, {}))
		var path := _find_passable_path(from_point, to_point, terrain_rows, occupied)
		var classification := _route_classification(link, not path.is_empty())
		var transit_semantics := _transit_semantics_for_surface_link(link, terrain_transit)
		var edge_id := _route_edge_id(edge_index, from_zone, to_zone)
		var role := String(link.get("role", ""))
		var required := role in ["contest_route", "early_reward_route", "reward_to_junction", "template_connection"]
		var route_anchor_candidate := _route_anchor_candidate(path, from_point, to_point)
		var edge := {
			"id": edge_id,
			"from": from_zone,
			"to": to_zone,
			"from_node": String(from_node.get("id", from_zone)),
			"to_node": String(to_node.get("id", to_zone)),
			"role": role,
			"layout_contract_roles": _layout_contract_roles_for_route(role),
			"guard_value": int(link.get("guard_value", 0)),
			"guard": link.get("guard", {}),
			"wide": bool(link.get("wide", false)),
			"border_guard": bool(link.get("border_guard", false)),
			"player_filter": link.get("player_filter", {}),
			"special_payload": link.get("special_payload", {}),
			"unsupported_runtime_fields": link.get("unsupported_runtime_fields", []),
			"connectivity_classification": classification,
			"transit_semantics": transit_semantics,
			"required": required,
			"path_found": not path.is_empty(),
			"path_length": path.size(),
			"from_anchor": from_point,
			"to_anchor": to_point,
			"route_cell_anchor_candidate": route_anchor_candidate,
			"connection_guard_materialization_ids": [],
			"writeout_state": "staged_road_overlay_payload_no_tile_write",
		}
		edges.append(edge)
		if not path.is_empty():
			road_segments.append(_road_segment_payload(edge_id, path, classification, edge))
			road_stubs.append({"edge_id": edge_id, "node_id": String(from_node.get("id", "")), "point": from_point, "role": "from_stub"})
			road_stubs.append({"edge_id": edge_id, "node_id": String(to_node.get("id", "")), "point": to_point, "role": "to_stub"})
			_connect_adjacency(adjacency, String(from_node.get("id", from_zone)), String(to_node.get("id", to_zone)))
		edge_index += 1
	for town in placements.get("towns", []):
		if not (town is Dictionary):
			continue
		var town_placement_id := String(town.get("placement_id", ""))
		var town_node_id := "node_%s" % town_placement_id
		var town_point := _first_approach_or_body(town)
		for resource in placements.get("resource_nodes", []):
			if not (resource is Dictionary) or String(resource.get("zone_id", "")) != String(town.get("zone_id", "")):
				continue
			var resource_node_id := "node_%s" % String(resource.get("placement_id", ""))
			var resource_point := _first_approach_or_body(resource)
			var resource_path := _find_passable_path(town_point, resource_point, terrain_rows, occupied)
			var resource_edge_id := "edge_%02d_%s_%s" % [edge_index, town_placement_id, String(resource.get("placement_id", ""))]
			var resource_classification := "full_connectivity" if not resource_path.is_empty() else "blocked_connectivity"
			var resource_edge := {
				"id": resource_edge_id,
				"from": town_placement_id,
				"to": String(resource.get("placement_id", "")),
				"from_node": town_node_id,
				"to_node": resource_node_id,
				"role": "required_start_economy_route",
				"guard_value": 0,
				"wide": false,
				"border_guard": false,
				"connectivity_classification": resource_classification,
				"transit_semantics": {"kind": "land_road", "materialization_state": "road_overlay_staged", "required_unlock": false},
				"required": true,
				"path_found": not resource_path.is_empty(),
				"path_length": resource_path.size(),
				"from_anchor": town_point,
				"to_anchor": resource_point,
				"writeout_state": "staged_road_overlay_payload_no_tile_write",
			}
			edges.append(resource_edge)
			if not resource_path.is_empty():
				road_segments.append(_road_segment_payload(resource_edge_id, resource_path, resource_classification, resource_edge))
				road_stubs.append({"edge_id": resource_edge_id, "node_id": town_node_id, "point": town_point, "role": "town_stub"})
				road_stubs.append({"edge_id": resource_edge_id, "node_id": resource_node_id, "point": resource_point, "role": "resource_stub"})
				_connect_adjacency(adjacency, town_node_id, resource_node_id)
			edge_index += 1
	var route_graph := {
		"nodes": route_nodes,
		"edges": edges,
		"connection_payload_semantics": {
			"value": "normal_guard_value",
			"wide": "suppresses_normal_guard",
			"border_guard": "special_guarded_connection_mode",
			"materialized_guards": "explicit_connection_guard_materialization_payload_records",
			"transit": "land_roads_now_water_underground_and_cross_level_routes_report_deferred_materialization",
		},
		"transit_route_semantics": terrain_transit.get("transit_routes", {}),
	}
	var proof := _reachability_proof(route_nodes, edges, adjacency)
	return {
		"route_graph": route_graph,
		"road_network": {
			"schema_id": "random_map_road_overlay_staging_v1",
			"writeout_policy": "staged_overlay_payload_only_no_authored_tile_write",
			"overlay_id": ROAD_OVERLAY_ID,
			"road_segments": road_segments,
			"road_stubs": road_stubs,
			"blocked_body_policy": "paths_exclude_object_body_tiles_and_impassable_terrain",
			"transit_writeout_policy": "land_road_overlays_staged_transit_objects_deferred",
		},
		"route_reachability_proof": proof,
	}

static func _town_start_constraints_payload(zones: Array, placements: Dictionary, route_graph: Dictionary, proof: Dictionary) -> Dictionary:
	var route_counts := _route_counts_by_zone(route_graph.get("edges", []))
	var starts := []
	var player_town_count := 0
	var towns: Array = placements.get("towns", [])
	for town in towns:
		if not (town is Dictionary):
			continue
		if int(town.get("player_slot", 0)) <= 0:
			continue
		player_town_count += 1
		var zone_id := String(town.get("zone_id", ""))
		var counts: Dictionary = route_counts.get(zone_id, {})
		var approach_tiles: Array = town.get("approach_tiles", [])
		var support_count := _support_resource_count_for_zone(placements.get("resource_nodes", []), zone_id)
		var viable := approach_tiles.size() >= 2 and support_count >= SUPPORT_RESOURCE_SITES.size() and int(counts.get("contest_route", 0)) >= 1 and int(counts.get("early_reward_route", 0)) >= 1 and String(proof.get("status", "")) == "pass"
		starts.append({
			"player_slot": int(town.get("player_slot", 0)),
			"owner": String(town.get("owner", "")),
			"zone_id": zone_id,
			"primary_town_placement_id": String(town.get("placement_id", "")),
			"town_id": String(town.get("town_id", "")),
			"faction_id": String(town.get("faction_id", "")),
			"body_tiles": town.get("body_tiles", []),
			"approach_tiles": approach_tiles,
			"minimum_approach_tiles_required": 2,
			"support_resource_count": support_count,
			"expansion_route_count": int(counts.get("early_reward_route", 0)),
			"contest_route_count": int(counts.get("contest_route", 0)),
			"viability": "pass" if viable else "fail",
		})
	return {
		"schema_id": "random_map_town_start_constraints_v1",
		"townless_start_profile": false,
		"player_starts": starts,
		"required_primary_town_count": player_town_count,
		"reachability_status": String(proof.get("status", "")),
	}

static func _fairness_report_payload(normalized: Dictionary, zones: Array, placements: Dictionary, route_graph: Dictionary, proof: Dictionary, objectives: Dictionary = {}, town_mine_dwelling: Dictionary = {}) -> Dictionary:
	var early_support := _early_resource_support_payload(placements, route_graph)
	var contested_fronts := _contested_front_distribution_payload(placements, route_graph)
	var guard_pressure := _guard_pressure_payload(route_graph)
	var distance_comparisons := _travel_distance_comparisons_payload(placements, route_graph)
	var objective_pressure := _objective_reward_pressure_payload(objectives, route_graph)
	var producer_access := _core_economy_producer_access_payload(placements, route_graph, town_mine_dwelling)
	var contested_markers := _contested_objective_pressure_markers(town_mine_dwelling, guard_pressure, contested_fronts)
	var failures := []
	var warnings := []
	for section in [early_support, contested_fronts, guard_pressure, distance_comparisons, objective_pressure, producer_access, contested_markers]:
		if String(section.get("status", "")) == "fail":
			failures.append_array(section.get("failures", []))
		elif String(section.get("status", "")) == "warning":
			warnings.append_array(section.get("warnings", []))
	var status := "pass"
	if not failures.is_empty():
		status = "fail"
	elif not warnings.is_empty():
		status = "warning"
	return {
		"schema_id": "random_map_resource_encounter_fairness_report_v1",
		"status": status,
		"metadata": {
			"generator_version": String(normalized.get("generator_version", normalized.get("generator_version", GENERATOR_VERSION))),
			"normalized_seed": String(normalized.get("seed", normalized.get("normalized_seed", ""))),
			"profile_id": String(normalized.get("profile", {}).get("id", normalized.get("profile_id", ""))) if normalized.get("profile", {}) is Dictionary else "",
			"route_reachability_status": String(proof.get("status", "")),
			"zone_count": zones.size(),
		},
		"summary": {
			"early_resource_status": String(early_support.get("status", "")),
			"contested_front_status": String(contested_fronts.get("status", "")),
			"guard_pressure_status": String(guard_pressure.get("status", "")),
			"travel_distance_status": String(distance_comparisons.get("status", "")),
			"objective_pressure_status": String(objective_pressure.get("status", "")),
			"core_economy_producer_status": String(producer_access.get("status", "")),
			"contested_objective_pressure_status": String(contested_markers.get("status", "")),
		},
		"early_resource_support": early_support,
		"core_economy_producer_access": producer_access,
		"contested_front_distribution": contested_fronts,
		"contested_objective_pressure_markers": contested_markers,
		"guarded_reward_risk": guard_pressure.get("guarded_reward_risk", {}),
		"guard_pressure": guard_pressure,
		"travel_distance_comparisons": distance_comparisons,
		"objective_reward_pressure": objective_pressure,
		"failures": failures,
		"warnings": warnings,
		"classification_model": "pass_warning_fail_report_only_no_runtime_adoption",
	}

static func _core_economy_producer_access_payload(placements: Dictionary, route_graph: Dictionary, town_mine_dwelling: Dictionary) -> Dictionary:
	var mines_by_zone := {}
	for mine in town_mine_dwelling.get("mine_resource_producer_records", []):
		if not (mine is Dictionary):
			continue
		var zone_id := String(mine.get("zone_id", ""))
		if not mines_by_zone.has(zone_id):
			mines_by_zone[zone_id] = []
		mines_by_zone[zone_id].append(mine)
	var route_edges := _resource_route_edges_by_town(route_graph.get("edges", []))
	var per_player := []
	var failures := []
	var warnings := []
	for town in placements.get("towns", []):
		if not (town is Dictionary):
			continue
		var player_slot := int(town.get("player_slot", 0))
		if player_slot <= 0:
			continue
		var zone_id := String(town.get("zone_id", ""))
		var categories := {}
		var mine_records := []
		for mine in mines_by_zone.get(zone_id, []):
			if not (mine is Dictionary):
				continue
			var category := String(mine.get("original_resource_category_id", ""))
			categories[category] = true
			mine_records.append({
				"placement_id": String(mine.get("placement_id", "")),
				"category": category,
				"site_id": String(mine.get("site_id", "")),
				"frontier_metadata": mine.get("frontier_metadata", {}),
				"guard_pressure": mine.get("guard_pressure", {}),
			})
		var missing := []
		for required in ["timber", "ore"]:
			if not categories.has(required):
				missing.append(required)
		var route_lengths := []
		for edge in route_edges.get(String(town.get("placement_id", "")), []):
			if edge is Dictionary and bool(edge.get("path_found", false)):
				route_lengths.append(int(edge.get("path_length", 0)))
		var status := "pass"
		if not missing.is_empty():
			status = "fail"
			failures.append("player %d lacks core mine categories %s" % [player_slot, ",".join(missing)])
		elif route_lengths.is_empty():
			status = "warning"
			warnings.append("player %d has core mines but no measured producer route" % player_slot)
		per_player.append({
			"player_slot": player_slot,
			"zone_id": zone_id,
			"primary_town_placement_id": String(town.get("placement_id", "")),
			"required_core_categories": ["timber", "ore"],
			"present_categories": _sorted_keys(categories),
			"mine_records": mine_records,
			"producer_route_lengths": route_lengths,
			"starting_town_supported": missing.is_empty(),
			"status": status,
		})
	var status := "pass"
	if not failures.is_empty():
		status = "fail"
	elif not warnings.is_empty():
		status = "warning"
	return {
		"status": status,
		"per_player": per_player,
		"failures": failures,
		"warnings": warnings,
		"model": "per_player_start_zone_core_timber_ore_mine_access_plus_route_lengths",
	}

static func _contested_objective_pressure_markers(town_mine_dwelling: Dictionary, guard_pressure: Dictionary, contested_fronts: Dictionary) -> Dictionary:
	var markers := []
	var failures := []
	var warnings := []
	for mine in town_mine_dwelling.get("mine_resource_producer_records", []):
		if not (mine is Dictionary):
			continue
		var frontier: Dictionary = mine.get("frontier_metadata", {}) if mine.get("frontier_metadata", {}) is Dictionary else {}
		if bool(frontier.get("contested", false)) or bool(frontier.get("frontier", false)):
			markers.append({
				"placement_id": String(mine.get("placement_id", "")),
				"kind": "mine",
				"zone_id": String(mine.get("zone_id", "")),
				"category": String(mine.get("original_resource_category_id", "")),
				"pressure": mine.get("guard_pressure", {}),
				"classification": String(frontier.get("classification", "")),
			})
	for dwelling in town_mine_dwelling.get("dwelling_recruitment_site_records", []):
		if not (dwelling is Dictionary):
			continue
		if String(dwelling.get("zone_role", "")) in ["treasure", "junction"]:
			markers.append({
				"placement_id": String(dwelling.get("placement_id", "")),
				"kind": "neutral_dwelling",
				"zone_id": String(dwelling.get("zone_id", "")),
				"pressure": String(dwelling.get("guard_pressure", "")),
				"classification": "frontier_recruitment_pressure",
			})
	if markers.is_empty():
		warnings.append("no contested mine or dwelling pressure markers")
	var guarded_routes: int = guard_pressure.get("route_guards", []).size()
	var contest_routes: int = contested_fronts.get("per_start", []).size()
	if guarded_routes <= 0 or contest_routes <= 0:
		failures.append("contested pressure markers lack guarded route or contest front context")
	var status := "pass"
	if not failures.is_empty():
		status = "fail"
	elif not warnings.is_empty():
		status = "warning"
	return {
		"status": status,
		"markers": markers,
		"guarded_route_count": guarded_routes,
		"contest_front_count": contest_routes,
		"failures": failures,
		"warnings": warnings,
		"model": "frontier_mines_dwellings_plus_guarded_route_pressure",
	}

static func _early_resource_support_payload(placements: Dictionary, route_graph: Dictionary) -> Dictionary:
	var towns: Array = placements.get("towns", [])
	var resources_by_zone := _resources_by_zone(placements.get("resource_nodes", []))
	var resource_edges_by_town := _resource_route_edges_by_town(route_graph.get("edges", []))
	var per_start := []
	var failures := []
	var warnings := []
	for town in towns:
		if not (town is Dictionary):
			continue
		if int(town.get("player_slot", 0)) <= 0:
			continue
		var zone_id := String(town.get("zone_id", ""))
		var totals := {"gold": 0, "wood": 0, "ore": 0}
		var resource_records := []
		for resource in resources_by_zone.get(zone_id, []):
			if not (resource is Dictionary):
				continue
			var site_id := String(resource.get("site_id", ""))
			var value: Dictionary = SUPPORT_RESOURCE_VALUE_BY_SITE.get(site_id, {})
			for key in ["gold", "wood", "ore"]:
				totals[key] = int(totals.get(key, 0)) + int(value.get(key, 0))
			resource_records.append({
				"placement_id": String(resource.get("placement_id", "")),
				"site_id": site_id,
				"purpose": _resource_support_purpose(site_id),
				"value": _sorted_dict(value),
			})
		var missing := []
		for key in ["gold", "wood", "ore"]:
			if int(totals.get(key, 0)) < int(EARLY_RESOURCE_MINIMUMS.get(key, 0)):
				missing.append(key)
		var route_lengths := []
		for edge in resource_edges_by_town.get(String(town.get("placement_id", "")), []):
			if edge is Dictionary and bool(edge.get("path_found", false)):
				route_lengths.append(int(edge.get("path_length", 0)))
		var route_status := _spread_status(route_lengths, ROUTE_DISTANCE_WARNING_SPREAD, ROUTE_DISTANCE_FAIL_SPREAD)
		var status := "pass"
		if not missing.is_empty() or resource_records.size() < SUPPORT_RESOURCE_SITES.size():
			status = "fail"
			failures.append("start %s missing early support resources: %s" % [String(town.get("placement_id", "")), ",".join(missing)])
		elif route_status == "warning":
			status = "warning"
			warnings.append("start %s early support route distances are uneven" % String(town.get("placement_id", "")))
		per_start.append({
			"player_slot": int(town.get("player_slot", 0)),
			"zone_id": zone_id,
			"primary_town_placement_id": String(town.get("placement_id", "")),
			"minimums": _sorted_dict(EARLY_RESOURCE_MINIMUMS),
			"totals": _sorted_dict(totals),
			"resources": resource_records,
			"resource_route_lengths": route_lengths,
			"route_distance_status": route_status,
			"status": status,
		})
	var status := "pass"
	if not failures.is_empty():
		status = "fail"
	elif not warnings.is_empty():
		status = "warning"
	return {"status": status, "per_start": per_start, "failures": failures, "warnings": warnings}

static func _contested_front_distribution_payload(placements: Dictionary, route_graph: Dictionary) -> Dictionary:
	var start_zones := _start_zones_from_towns(placements.get("towns", []))
	var records := []
	var distances := []
	var pressure_values := []
	var failures := []
	var warnings := []
	for zone_id in start_zones:
		var edges := _edges_for_zone_and_role(route_graph.get("edges", []), String(zone_id), "contest_route")
		var route_count := 0
		var shortest := 0
		var pressure := 0
		for edge in edges:
			if not (edge is Dictionary):
				continue
			if bool(edge.get("path_found", false)):
				route_count += 1
				var length := int(edge.get("path_length", 0))
				shortest = length if shortest == 0 else min(shortest, length)
				distances.append(length)
				pressure += _effective_guard_pressure(edge)
		pressure_values.append(pressure)
		if route_count < 1:
			failures.append("start zone %s has no contest route front" % String(zone_id))
		records.append({
			"zone_id": String(zone_id),
			"contest_route_count": route_count,
			"nearest_contest_route_distance": shortest,
			"contest_guard_pressure": pressure,
		})
	var distance_status := _spread_status(distances, ROUTE_DISTANCE_WARNING_SPREAD, ROUTE_DISTANCE_FAIL_SPREAD)
	var pressure_status := _spread_status(pressure_values, PRESSURE_WARNING_SPREAD, PRESSURE_FAIL_SPREAD)
	if distance_status == "warning":
		warnings.append("contest route distances exceed warning spread")
	elif distance_status == "fail":
		failures.append("contest route distances exceed fail spread")
	if pressure_status == "warning":
		warnings.append("contest guard pressure exceeds warning spread")
	elif pressure_status == "fail":
		failures.append("contest guard pressure exceeds fail spread")
	var status := "pass"
	if not failures.is_empty():
		status = "fail"
	elif not warnings.is_empty():
		status = "warning"
	return {
		"status": status,
		"resource_front_model": "contest_routes_until_contested_resource_sites_exist",
		"per_start": records,
		"distance_spread": _spread_summary(distances),
		"guard_pressure_spread": _spread_summary(pressure_values),
		"failures": failures,
		"warnings": warnings,
	}

static func _guard_pressure_payload(route_graph: Dictionary) -> Dictionary:
	var route_guards := []
	var reward_risk := []
	var pressure_by_start := {}
	var failures := []
	var warnings := []
	for edge in route_graph.get("edges", []):
		if not (edge is Dictionary):
			continue
		var role := String(edge.get("role", ""))
		if not _route_has_layout_contract_role(edge, "guarded_route"):
			continue
		var guard_class := _guard_risk_class(edge)
		var pressure := _effective_guard_pressure(edge)
		var record := {
			"edge_id": String(edge.get("id", "")),
			"from": String(edge.get("from", "")),
			"to": String(edge.get("to", "")),
			"role": role,
			"path_length": int(edge.get("path_length", 0)),
			"raw_guard_value": int(edge.get("guard_value", 0)),
			"effective_guard_pressure": pressure,
			"risk_class": guard_class,
			"wide_suppresses_normal_guard": bool(edge.get("wide", false)),
			"border_guard_special_mode": bool(edge.get("border_guard", false)),
			"connection_guard_materialization_ids": edge.get("connection_guard_materialization_ids", []),
			"monster_reward_band_ids": edge.get("monster_reward_band_ids", []),
			"connectivity_classification": String(edge.get("connectivity_classification", "")),
		}
		route_guards.append(record)
		if _route_has_layout_contract_role(edge, "reward_route"):
			reward_risk.append(record)
		for endpoint_key in ["from", "to"]:
			var endpoint := String(edge.get(endpoint_key, ""))
			if endpoint.begins_with("start_"):
				pressure_by_start[endpoint] = int(pressure_by_start.get(endpoint, 0)) + pressure
	if route_guards.is_empty():
		failures.append("no route guard pressure records available")
	var pressure_values := []
	for key in _sorted_keys(pressure_by_start):
		pressure_values.append(int(pressure_by_start[key]))
	var pressure_status := _spread_status(pressure_values, PRESSURE_WARNING_SPREAD, PRESSURE_FAIL_SPREAD)
	if pressure_status == "warning":
		warnings.append("route guard pressure exceeds warning spread")
	elif pressure_status == "fail":
		failures.append("route guard pressure exceeds fail spread")
	var status := "pass"
	if not failures.is_empty():
		status = "fail"
	elif not warnings.is_empty():
		status = "warning"
	return {
		"status": status,
		"connection_payload_semantics": route_graph.get("connection_payload_semantics", {}),
		"connection_guard_materialization_summary": route_graph.get("connection_guard_materialization_summary", {}),
		"monster_reward_bands_summary": route_graph.get("monster_reward_bands_summary", {}),
		"route_guards": route_guards,
		"pressure_by_start_zone": _sorted_dict(pressure_by_start),
		"pressure_spread": _spread_summary(pressure_values),
		"guarded_reward_risk": {
			"status": "pass" if not reward_risk.is_empty() else "warning",
			"risk_classes": reward_risk,
			"model": "guard_value_distance_and_connection_semantics",
		},
		"failures": failures,
		"warnings": warnings,
	}

static func _travel_distance_comparisons_payload(placements: Dictionary, route_graph: Dictionary) -> Dictionary:
	var resources_by_town := _resource_route_edges_by_town(route_graph.get("edges", []))
	var records := []
	var town_to_resource_maxes := []
	var contest_distances := []
	var failures := []
	var warnings := []
	for town in placements.get("towns", []):
		if not (town is Dictionary):
			continue
		var town_id := String(town.get("placement_id", ""))
		var zone_id := String(town.get("zone_id", ""))
		var resource_lengths := []
		for edge in resources_by_town.get(town_id, []):
			if edge is Dictionary and bool(edge.get("path_found", false)):
				resource_lengths.append(int(edge.get("path_length", 0)))
		var contest_edges := _edges_for_zone_and_role(route_graph.get("edges", []), zone_id, "contest_route")
		var nearest_contest := 0
		for edge in contest_edges:
			if edge is Dictionary and bool(edge.get("path_found", false)):
				var length := int(edge.get("path_length", 0))
				nearest_contest = length if nearest_contest == 0 else min(nearest_contest, length)
		var max_resource := _max_int(resource_lengths)
		town_to_resource_maxes.append(max_resource)
		if nearest_contest > 0:
			contest_distances.append(nearest_contest)
		records.append({
			"player_slot": int(town.get("player_slot", 0)),
			"zone_id": zone_id,
			"start_contract": "primary_town_anchor_until_hero_start_generation_exists",
			"start_to_primary_town_distance": 0,
			"town_to_resource_route_lengths": resource_lengths,
			"max_town_to_resource_distance": max_resource,
			"nearest_contest_route_distance": nearest_contest,
		})
	var resource_status := _spread_status(town_to_resource_maxes, ROUTE_DISTANCE_WARNING_SPREAD, ROUTE_DISTANCE_FAIL_SPREAD)
	var contest_status := _spread_status(contest_distances, ROUTE_DISTANCE_WARNING_SPREAD, ROUTE_DISTANCE_FAIL_SPREAD)
	if resource_status == "warning":
		warnings.append("town-to-resource route distance spread exceeds warning threshold")
	elif resource_status == "fail":
		failures.append("town-to-resource route distance spread exceeds fail threshold")
	if contest_status == "warning":
		warnings.append("contest route distance spread exceeds warning threshold")
	elif contest_status == "fail":
		failures.append("contest route distance spread exceeds fail threshold")
	var status := "pass"
	if not failures.is_empty():
		status = "fail"
	elif not warnings.is_empty():
		status = "warning"
	return {
		"status": status,
		"per_start": records,
		"town_to_resource_distance_spread": _spread_summary(town_to_resource_maxes),
		"contest_route_distance_spread": _spread_summary(contest_distances),
		"failures": failures,
		"warnings": warnings,
	}

static func _objective_reward_pressure_payload(objectives: Dictionary, route_graph: Dictionary) -> Dictionary:
	var objective_records := []
	for bucket in ["victory", "defeat"]:
		if not (objectives.get(bucket, []) is Array):
			continue
		for objective in objectives.get(bucket, []):
			if not (objective is Dictionary):
				continue
			var objective_type := String(objective.get("type", ""))
			var supported := objective_type in ["town_owned_by_player", "town_not_owned_by_player", "encounter_resolved", "day_at_least", "flag_true", "session_flag_equals", "hook_fired"]
			objective_records.append({
				"id": String(objective.get("id", "")),
				"bucket": bucket,
				"type": objective_type,
				"supported_by_domain_rules": supported,
				"generated_support": String(objective.get("generated_support", "")),
			})
	var objective_count := objective_records.size()
	if objective_count == 0:
		return {
			"status": "pass",
			"supported": false,
			"objective_count": 0,
			"model": "no_generated_objective_pressure_until_supported_objectives_exist",
			"failures": [],
			"warnings": [],
		}
	var unsupported := []
	for record in objective_records:
		if record is Dictionary and not bool(record.get("supported_by_domain_rules", false)):
			unsupported.append(String(record.get("id", "")))
	if unsupported.is_empty():
		return {
			"status": "pass",
			"supported": true,
			"objective_count": objective_count,
			"objectives": objective_records,
			"route_edge_count": route_graph.get("edges", []).size(),
			"model": "generated_objectives_use_supported_scenario_rules",
			"failures": [],
			"warnings": [],
		}
	return {
		"status": "fail",
		"supported": false,
		"objective_count": objective_count,
		"objectives": objective_records,
		"route_edge_count": route_graph.get("edges", []).size(),
		"model": "generated_objectives_must_use_supported_scenario_rules",
		"failures": ["unsupported generated objective ids: %s" % ",".join(unsupported)],
		"warnings": [],
	}

static func _metadata(normalized: Dictionary) -> Dictionary:
	var selected_template: Dictionary = normalized.get("template", {}) if normalized.get("template", {}) is Dictionary else {}
	return {
		"generator_version": String(normalized.get("generator_version", GENERATOR_VERSION)),
		"normalized_seed": String(normalized.get("seed", "0")),
		"profile": normalized.get("profile", {}),
		"size": normalized.get("size", {}),
		"player_constraints": normalized.get("player_constraints", {}),
		"player_assignment": normalized.get("player_assignment", {}),
		"content_manifest_fingerprint": String(normalized.get("content_manifest_fingerprint", "")),
		"template_id": String(normalized.get("template_id", TEMPLATE_ID)),
		"template_selection": {
			"source": String(normalized.get("template_selection", {}).get("source", "")),
			"requested_template_id": String(normalized.get("template_selection", {}).get("requested_template_id", "")),
			"requested_profile_id": String(normalized.get("template_selection", {}).get("requested_profile_id", "")),
			"rejected": bool(normalized.get("template_selection", {}).get("rejected", false)),
			"failure_code": String(normalized.get("template_selection", {}).get("failure_code", "")),
			"rejection_reasons": normalized.get("template_selection", {}).get("rejection_reasons", []),
			"constraint_report": normalized.get("template_selection", {}).get("constraint_report", {}),
		},
		"template_grammar_preservation": {
			"catalog_schema_id": TEMPLATE_CATALOG_SCHEMA_ID,
			"template_id": String(selected_template.get("id", "")),
			"grammar_metadata": selected_template.get("grammar_metadata", {}),
			"unsupported_runtime_fields": selected_template.get("unsupported_runtime_fields", []),
			"runtime_policy": "expanded_catalog_fields_are_preserved_until_downstream_parity_slices_consume_them",
		},
		"source_lessons": [
			"staged_template_profile_pipeline",
			"runtime_zone_connection_graph",
			"terrain_owner_grid_before_writeout",
			"separate_object_resource_encounter_placements",
			"connection_payloads_classify_guarded_wide_border_routes",
			"roads_staged_as_overlay_payloads_before_durable_tile_writeout",
			"explicit_no_authored_content_write_boundary",
		],
	}

static func _template_selection_rejection_result(normalized: Dictionary) -> Dictionary:
	var selection: Dictionary = normalized.get("template_selection", {})
	var report := {
		"ok": false,
		"status": "fail",
		"schema_id": TEMPLATE_SELECTION_REJECTION_SCHEMA_ID,
		"failure_code": String(selection.get("failure_code", "template_selection_rejected")),
		"failures": selection.get("rejection_reasons", []),
		"template_selection": selection,
		"metadata": _metadata(normalized),
		"fallback_policy": "explicit_catalog_template_or_profile_requests_return_structured_rejection_instead_of_built_in_fallback",
	}
	return {
		"ok": false,
		"generated_map": {},
		"report": report,
	}

static func _route_graph_payload(links: Array, seeds: Dictionary) -> Dictionary:
	var edges := []
	for index in range(links.size()):
		var link: Dictionary = links[index]
		var from_zone := String(link.get("from", ""))
		var to_zone := String(link.get("to", ""))
		edges.append({
			"id": _route_edge_id(index + 1, from_zone, to_zone),
			"from": from_zone,
			"to": to_zone,
			"role": String(link.get("role", "")),
			"guard_value": int(link.get("guard_value", 0)),
			"guard": link.get("guard", {}),
			"wide": bool(link.get("wide", false)),
			"border_guard": bool(link.get("border_guard", false)),
			"player_filter": link.get("player_filter", {}),
			"special_payload": link.get("special_payload", {}),
			"unsupported_runtime_fields": link.get("unsupported_runtime_fields", []),
			"from_anchor": seeds.get(String(link.get("from", "")), {}),
			"to_anchor": seeds.get(String(link.get("to", "")), {}),
			"route_cell_anchor_candidate": _route_anchor_candidate([], seeds.get(from_zone, {}), seeds.get(to_zone, {})),
			"connection_guard_materialization_ids": [],
			"writeout_state": "graph_only_roads_deferred",
		})
	return {"nodes": _sorted_point_dict(seeds), "edges": edges}

static func _terrain_phase_summary(terrain_rows: Array, zones: Array) -> Dictionary:
	var terrain_counts := {}
	for row_value in terrain_rows:
		var row: Array = row_value
		for terrain_id in row:
			var key := String(terrain_id)
			terrain_counts[key] = int(terrain_counts.get(key, 0)) + 1
	return {
		"terrain_counts": _sorted_dict(terrain_counts),
		"zone_count": zones.size(),
		"blocked_terrain_ids": BLOCKED_TERRAIN_IDS,
	}

static func _terrain_transit_phase_summary(terrain_transit: Dictionary) -> Dictionary:
	return {
		"schema_id": String(terrain_transit.get("schema_id", "")),
		"signature": String(terrain_transit.get("terrain_transit_signature", "")),
		"zone_palette_count": terrain_transit.get("terrain_normalization", {}).get("zone_palettes", []).size(),
		"terrain_layer_count": terrain_transit.get("terrain_layers", []).size(),
		"coast_cell_count": int(terrain_transit.get("water_coast_passability", {}).get("coast_cell_count", 0)),
		"corridor_route_count": terrain_transit.get("transit_routes", {}).get("corridor_routes", []).size(),
		"cross_level_candidate_count": terrain_transit.get("transit_routes", {}).get("cross_level_candidates", []).size(),
		"unsupported_deferred": terrain_transit.get("unsupported_deferred", []),
	}

static func _build_terrain_transit_semantics(zone_layout: Dictionary, zones: Array, links: Array, surface_rows: Array, normalized: Dictionary) -> Dictionary:
	var zone_palettes := []
	var unsupported := []
	var deferred := []
	for zone in zones:
		if not (zone is Dictionary):
			continue
		var palette: Dictionary = zone.get("terrain_palette", {}) if zone.get("terrain_palette", {}) is Dictionary else {}
		if palette.is_empty():
			palette = _zone_terrain_palette_record(zone, String(zone.get("faction_id", "")), normalized.get("profile", {}).get("terrain_ids", CORE_TERRAIN_POOL), DeterministicRng.new(_positive_seed(String(zone.get("id", "")))))
		zone_palettes.append(palette)
		unsupported.append_array(palette.get("unsupported_terrain_ids", []))
		deferred.append_array(palette.get("deferred_terrain_ids", []))
	var terrain_layers := _terrain_layer_payloads(zone_layout, zones, surface_rows)
	var water_coast := _water_coast_passability_payload(zone_layout, surface_rows)
	var transit_routes := _transit_routes_payload(zone_layout, links, water_coast)
	deferred.append_array(transit_routes.get("deferred", []))
	var payload := {
		"schema_id": TERRAIN_TRANSIT_SCHEMA_ID,
		"normalization_policy": "zone_palette_to_known_original_terrain_or_explicit_unsupported_deferred_state",
		"terrain_normalization": {
			"known_original_terrain_ids": ORIGINAL_TERRAIN_IDS,
			"surface_scenario_terrain_ids": SURFACE_SCENARIO_TERRAIN_IDS,
			"zone_palettes": zone_palettes,
			"unsupported_terrain_ids": _unique_sorted_strings(unsupported),
			"deferred_terrain_ids": _unique_sorted_strings(deferred),
		},
		"terrain_layers": terrain_layers,
		"water_coast_passability": water_coast,
		"transit_routes": transit_routes,
		"unsupported_deferred": _unique_sorted_strings(unsupported + deferred),
		"writeout_policy": "staged_metadata_only_no_authored_terrain_or_transit_writeback",
	}
	payload["terrain_transit_signature"] = _hash32_hex(_stable_stringify({
		"terrain_normalization": payload.get("terrain_normalization", {}),
		"terrain_layers": payload.get("terrain_layers", []),
		"water_coast_passability": payload.get("water_coast_passability", {}),
		"transit_routes": payload.get("transit_routes", {}),
	}))
	return payload

static func _terrain_layer_payloads(zone_layout: Dictionary, zones: Array, surface_rows: Array) -> Array:
	var layers := []
	var levels: Array = zone_layout.get("levels", [])
	var zone_terrain := {}
	for zone in zones:
		if zone is Dictionary:
			zone_terrain[String(zone.get("id", ""))] = String(zone.get("terrain_id", "grass"))
	for level in levels:
		if not (level is Dictionary):
			continue
		var level_index := int(level.get("level_index", 0))
		var level_kind := String(level.get("kind", "surface"))
		var rows := surface_rows.duplicate(true) if level_index == 0 else _terrain_rows_for_level(level, zone_terrain, true)
		layers.append({
			"level_index": level_index,
			"level_kind": level_kind,
			"terrain_model": "surface_owner_grid_rows" if level_index == 0 else "underground_cave_rows_from_level_owner_grid",
			"default_terrain_id": UNDERGROUND_TERRAIN_ID if level_kind == "underground" else "",
			"biome_id": "biome_subterranean_underways" if level_kind == "underground" else "",
			"rows": rows,
			"terrain_counts": _terrain_counts(rows),
			"passability_grid": _passability_rows(rows),
			"movement_cost_grid": _movement_cost_rows(rows),
			"cave_metadata": {
				"is_cave": level_kind == "underground",
				"underground": level_kind == "underground",
				"materialization_state": "metadata_and_rows_only_transit_gate_objects_deferred" if level_kind == "underground" else "surface_layer",
			},
		})
	return layers

static func _terrain_rows_for_level(level: Dictionary, zone_terrain: Dictionary, underground: bool) -> Array:
	var owner_grid: Array = level.get("owner_grid", [])
	var water_lookup := _point_lookup(level.get("water_cells", []))
	var rows := []
	for y in range(owner_grid.size()):
		var source_row: Array = owner_grid[y]
		var row := []
		for x in range(source_row.size()):
			if water_lookup.has(_point_key(x, y)):
				row.append("water")
			elif underground:
				row.append(UNDERGROUND_TERRAIN_ID)
			else:
				row.append(String(zone_terrain.get(String(source_row[x]), "grass")))
		rows.append(row)
	return rows

static func _water_coast_passability_payload(zone_layout: Dictionary, surface_rows: Array) -> Dictionary:
	var water_cells: Array = zone_layout.get("surface_water_cells", [])
	var water_lookup := _point_lookup(water_cells)
	var coast_lookup := {}
	var classification_rows := []
	var passability_rows := []
	var movement_cost_rows := []
	for y in range(surface_rows.size()):
		var source_row: Array = surface_rows[y]
		var class_row := []
		var pass_row := []
		var cost_row := []
		for x in range(source_row.size()):
			var terrain_id := String(source_row[x])
			var classification := "water" if water_lookup.has(_point_key(x, y)) else "land"
			if classification == "land" and _adjacent_to_lookup(x, y, water_lookup):
				classification = "coast_land"
				coast_lookup[_point_key(x, y)] = true
			class_row.append(classification)
			pass_row.append(_terrain_is_passable(terrain_id))
			cost_row.append(_terrain_movement_cost(terrain_id))
		classification_rows.append(class_row)
		passability_rows.append(pass_row)
		movement_cost_rows.append(cost_row)
	return {
		"schema_id": "random_map_water_coast_passability_v1",
		"water_mode": String(zone_layout.get("policy", {}).get("water_mode", "land")),
		"water_cell_count": water_cells.size(),
		"coast_cell_count": coast_lookup.size(),
		"water_cells": water_cells,
		"coast_cells": _points_from_lookup(coast_lookup),
		"classification_rows": classification_rows,
		"passability_grid": passability_rows,
		"movement_cost_grid": movement_cost_rows,
		"water_passability": "impassable_until_explicit_boat_ferry_shipyard_or_bridge_transit_materializes",
		"coast_passability": "land_cells_adjacent_to_water_remain_passable_approach_candidates",
	}

static func _transit_routes_payload(zone_layout: Dictionary, links: Array, water_coast: Dictionary) -> Dictionary:
	var corridor_routes := []
	var by_key := {}
	var deferred := []
	for candidate in zone_layout.get("corridor_candidates", []):
		if not (candidate is Dictionary):
			continue
		var semantics := _transit_semantics_for_corridor(candidate, water_coast)
		var record: Dictionary = candidate.duplicate(true)
		record["transit_semantics"] = semantics
		record["route_key"] = _corridor_route_key(String(candidate.get("from", "")), String(candidate.get("to", "")), int(candidate.get("level_index", 0)))
		corridor_routes.append(record)
		by_key[String(record.get("route_key", ""))] = semantics
		by_key[_corridor_route_key(String(candidate.get("to", "")), String(candidate.get("from", "")), int(candidate.get("level_index", 0)))] = semantics
		deferred.append_array(semantics.get("deferred", []))
	var cross_level := _cross_level_transit_candidates(zone_layout)
	for candidate in cross_level:
		if candidate is Dictionary:
			deferred.append_array(candidate.get("transit_semantics", {}).get("deferred", []))
	var water_access := _water_access_transit_candidates(zone_layout, water_coast)
	for candidate in water_access:
		if candidate is Dictionary:
			deferred.append_array(candidate.get("transit_semantics", {}).get("deferred", []))
	return {
		"corridor_routes": corridor_routes,
		"by_route_key": by_key,
		"cross_level_candidates": cross_level,
		"water_access_candidates": water_access,
		"deferred": _unique_sorted_strings(deferred),
		"materialization_policy": "land_road_segments_are_staged_now_water_underground_cross_level_objects_are_candidates_only",
	}

static func _transit_semantics_for_corridor(candidate: Dictionary, water_coast: Dictionary) -> Dictionary:
	var level_kind := String(candidate.get("level_kind", "surface"))
	var crosses_water := String(candidate.get("mode", "land")) == "water"
	if crosses_water:
		return {
			"kind": "water_crossing_deferred",
			"route_class": "water_crossing",
			"passability": "deferred_unlock_required",
			"materialization_options": ["ferry", "boat", "shipyard", "bridge"],
			"required_unlock": true,
			"deferred": ["boat_shipyard_ferry_placement_deferred", "bridge_placement_deferred"],
			"materialization_state": "candidate_only_transit_object_not_materialized",
		}
	if level_kind == "underground":
		return {
			"kind": "underground_subterranean_connection_deferred",
			"route_class": "underground_land_corridor",
			"passability": "cave_land_passable_when_level_is_active",
			"materialization_options": ["subterranean_gate", "underground_road"],
			"required_unlock": false,
			"deferred": ["subterranean_gate_placement_deferred"],
			"materialization_state": "underground_metadata_only_surface_runtime_path_unchanged",
		}
	return {
		"kind": "land_road",
		"route_class": "surface_land",
		"passability": "passable_now",
		"materialization_options": ["road_overlay"],
		"required_unlock": false,
		"deferred": [],
		"water_context": "coast_access_available_transit_deferred" if int(water_coast.get("water_cell_count", 0)) > 0 else "none",
		"materialization_state": "road_overlay_staged",
	}

static func _cross_level_transit_candidates(zone_layout: Dictionary) -> Array:
	var levels: Array = zone_layout.get("levels", [])
	if levels.size() < 2:
		return []
	var surface: Dictionary = levels[0]
	var underground: Dictionary = levels[1]
	var surface_anchors: Dictionary = surface.get("anchor_points", {})
	var underground_anchors: Dictionary = underground.get("anchor_points", {})
	var result := []
	for zone_id in _sorted_keys(surface_anchors):
		if not underground_anchors.has(zone_id):
			continue
		result.append({
			"id": "cross_level_%s_surface_underground" % String(zone_id),
			"zone_id": String(zone_id),
			"from_level_index": int(surface.get("level_index", 0)),
			"to_level_index": int(underground.get("level_index", 1)),
			"from_anchor": surface_anchors[zone_id],
			"to_anchor": underground_anchors[zone_id],
			"transit_semantics": {
				"kind": "cross_level_subterranean_gate_deferred",
				"route_class": "cross_level",
				"passability": "deferred_unlock_required",
				"materialization_options": ["subterranean_gate", "two_way_portal"],
				"required_unlock": true,
				"deferred": ["subterranean_gate_placement_deferred", "cross_level_link_object_placement_deferred"],
				"materialization_state": "candidate_only_transit_object_not_materialized",
			},
		})
	return result

static func _water_access_transit_candidates(zone_layout: Dictionary, water_coast: Dictionary) -> Array:
	if int(water_coast.get("water_cell_count", 0)) <= 0:
		return []
	var coast_cells: Array = water_coast.get("coast_cells", [])
	if coast_cells.is_empty():
		return []
	var levels: Array = zone_layout.get("levels", [])
	if levels.is_empty() or not (levels[0] is Dictionary):
		return []
	var anchors: Dictionary = levels[0].get("anchor_points", {})
	var result := []
	var cursor := 0
	for zone_id in _sorted_keys(anchors):
		if cursor >= min(4, coast_cells.size()):
			break
		var coast: Dictionary = coast_cells[cursor]
		result.append({
			"id": "water_access_%s_%02d" % [String(zone_id), cursor + 1],
			"zone_id": String(zone_id),
			"from_anchor": anchors[zone_id],
			"to_coast": coast,
			"level_index": 0,
			"transit_semantics": {
				"kind": "water_crossing_deferred",
				"route_class": "water_access",
				"passability": "deferred_unlock_required",
				"materialization_options": ["ferry", "boat", "shipyard"],
				"required_unlock": true,
				"deferred": ["boat_shipyard_ferry_placement_deferred"],
				"materialization_state": "candidate_only_transit_object_not_materialized",
			},
		})
		cursor += 1
	return result

static func _transit_semantics_for_surface_link(link: Dictionary, terrain_transit: Dictionary) -> Dictionary:
	var key := _corridor_route_key(String(link.get("from", "")), String(link.get("to", "")), 0)
	var by_key: Dictionary = terrain_transit.get("transit_routes", {}).get("by_route_key", {})
	if by_key.has(key):
		return by_key[key]
	return {"kind": "land_road", "route_class": "surface_land", "passability": "passable_now", "materialization_state": "road_overlay_staged", "required_unlock": false, "deferred": []}

static func _corridor_route_key(from_zone: String, to_zone: String, level_index: int) -> String:
	return "%s->%s@%d" % [from_zone, to_zone, level_index]

static func _terrain_transit_validation(terrain_transit: Dictionary, generated_map: Dictionary = {}) -> Dictionary:
	var failures := []
	var warnings := []
	if String(terrain_transit.get("schema_id", "")) != TERRAIN_TRANSIT_SCHEMA_ID:
		failures.append("terrain transit schema mismatch")
	if String(terrain_transit.get("terrain_transit_signature", "")) == "":
		failures.append("terrain transit signature missing")
	for palette in terrain_transit.get("terrain_normalization", {}).get("zone_palettes", []):
		if not (palette is Dictionary):
			failures.append("non-dictionary terrain palette")
			continue
		var normalized := String(palette.get("normalized_terrain_id", ""))
		if not _terrain_is_known_original(normalized):
			failures.append("zone %s normalized to unknown terrain %s" % [String(palette.get("zone_id", "")), normalized])
	var water: Dictionary = terrain_transit.get("water_coast_passability", {})
	if String(water.get("water_mode", "land")) == "islands":
		if int(water.get("water_cell_count", 0)) <= 0:
			failures.append("islands water mode missing water cells")
		if int(water.get("coast_cell_count", 0)) <= 0:
			failures.append("islands water mode missing coast cells")
	var has_land := false
	var has_underground := false
	for route in terrain_transit.get("transit_routes", {}).get("corridor_routes", []):
		if not (route is Dictionary):
			continue
		var kind := String(route.get("transit_semantics", {}).get("kind", ""))
		if kind == "land_road":
			has_land = true
		if kind == "underground_subterranean_connection_deferred":
			has_underground = true
	if not has_land:
		failures.append("corridor transit semantics missing land road route")
	var level_count := int(generated_map.get("staging", {}).get("zone_layout", {}).get("dimensions", {}).get("level_count", 1))
	if level_count > 1:
		if not has_underground:
			failures.append("underground request missing underground corridor semantics")
		if terrain_transit.get("transit_routes", {}).get("cross_level_candidates", []).is_empty():
			failures.append("underground request missing cross-level candidates")
	var scenario: Dictionary = generated_map.get("scenario_record", {}) if generated_map.get("scenario_record", {}) is Dictionary else {}
	if not scenario.is_empty():
		if bool(scenario.get("selection", {}).get("availability", {}).get("campaign", true)) or bool(scenario.get("selection", {}).get("availability", {}).get("skirmish", true)):
			failures.append("terrain transit validation found campaign/skirmish adoption")
		if scenario.has("save_adoption") or scenario.has("alpha_parity_claim") or String(generated_map.get("write_policy", "")) != "staged_payload_only_no_authored_content_write":
			failures.append("terrain transit validation found save/writeback/parity claim")
	return {
		"ok": failures.is_empty(),
		"status": "pass" if failures.is_empty() else "fail",
		"failure_count": failures.size(),
		"warning_count": warnings.size(),
		"failures": failures,
		"warnings": warnings,
	}

static func _validate_road_paths(road_network: Dictionary, terrain_rows: Array, object_placements: Array, failures: Array) -> void:
	var occupied := _occupied_body_lookup(object_placements)
	for segment in road_network.get("road_segments", []):
		if not (segment is Dictionary):
			failures.append("non-dictionary road segment")
			continue
		var route_edge_id := String(segment.get("route_edge_id", ""))
		var cells: Array = segment.get("cells", [])
		if cells.is_empty():
			failures.append("road segment %s has no cells" % route_edge_id)
			continue
		for cell in cells:
			if not (cell is Dictionary):
				failures.append("road segment %s has non-dictionary cell" % route_edge_id)
				continue
			var x := int(cell.get("x", -1))
			var y := int(cell.get("y", -1))
			if not _point_in_rows(terrain_rows, x, y):
				failures.append("road segment %s leaves map bounds" % route_edge_id)
			elif not _terrain_cell_is_passable(terrain_rows, x, y):
				failures.append("road segment %s crosses impassable terrain at %d,%d" % [route_edge_id, x, y])
			if occupied.has(_point_key(x, y)):
				failures.append("road segment %s crosses blocked object body at %d,%d" % [route_edge_id, x, y])

static func _terrain_region_counts(terrain_rows: Array) -> Dictionary:
	var visited := {}
	var counts := {}
	for y in range(terrain_rows.size()):
		var row: Array = terrain_rows[y]
		for x in range(row.size()):
			var key := _point_key(x, y)
			if visited.has(key):
				continue
			var terrain_id := String(row[x])
			counts[terrain_id] = int(counts.get(terrain_id, 0)) + 1
			var queue := [_point_dict(x, y)]
			visited[key] = true
			var cursor := 0
			while cursor < queue.size():
				var point: Dictionary = queue[cursor]
				cursor += 1
				for offset in _cardinal_offsets():
					var nx: int = int(point.get("x", 0)) + int(offset.x)
					var ny: int = int(point.get("y", 0)) + int(offset.y)
					if not _point_in_rows(terrain_rows, nx, ny):
						continue
					var next_key := _point_key(nx, ny)
					if visited.has(next_key) or String(terrain_rows[ny][nx]) != terrain_id:
						continue
					visited[next_key] = true
					queue.append(_point_dict(nx, ny))
	return _sorted_dict(counts)

static func _annotate_pathing_metadata(object_placements: Array, towns: Array, resource_nodes: Array, encounters: Array, zone_grid: Array, terrain_rows: Array, occupied: Dictionary) -> void:
	var by_id := {}
	for placement in object_placements:
		if placement is Dictionary:
			by_id[String(placement.get("placement_id", ""))] = placement
			_apply_pathing_metadata(placement, zone_grid, terrain_rows, occupied)
	for town in towns:
		if town is Dictionary:
			_copy_shared_placement_metadata(town, by_id.get(String(town.get("placement_id", "")), {}))
	for resource in resource_nodes:
		if resource is Dictionary:
			_copy_shared_placement_metadata(resource, by_id.get(String(resource.get("placement_id", "")), {}))
	for encounter in encounters:
		if encounter is Dictionary:
			_copy_shared_placement_metadata(encounter, by_id.get(String(encounter.get("placement_id", "")), {}))

static func _apply_pathing_metadata(placement: Dictionary, zone_grid: Array, terrain_rows: Array, occupied: Dictionary) -> void:
	var point := _point_dict(int(placement.get("x", 0)), int(placement.get("y", 0)))
	var zone_id := String(placement.get("zone_id", _zone_at_point(zone_grid, point)))
	var catalog := _object_footprint_catalog_record_for_placement(placement)
	var runtime_body := _runtime_body_tiles_for_catalog(point, catalog)
	var approaches := _approach_tiles_for_catalog(point, zone_id, zone_grid, terrain_rows, occupied, catalog, runtime_body)
	placement["zone_id"] = zone_id
	placement["body_tiles"] = runtime_body
	placement["blocking_body"] = bool(catalog.get("passability_mask", {}).get("body_blocks_movement", true)) if not catalog.is_empty() else true
	placement["approach_tiles"] = approaches
	placement["visit_tile"] = approaches[0] if not approaches.is_empty() else point
	placement["pathing_status"] = "pass" if not approaches.is_empty() else "blocked_no_approach"
	_apply_object_footprint_metadata(placement, terrain_rows, occupied)

static func _copy_shared_placement_metadata(target: Dictionary, source: Dictionary) -> void:
	for key in ["zone_id", "faction_id", "body_tiles", "blocking_body", "approach_tiles", "visit_tile", "pathing_status", "player_slot", "player_type", "team_id", "object_footprint_catalog_ref", "footprint", "runtime_footprint", "body_mask", "runtime_body_mask", "visit_mask", "approach_mask", "passability_mask", "action_mask", "terrain_restrictions", "placement_predicates", "placement_predicate_results", "footprint_deferred"]:
		if source.has(key):
			target[key] = source[key]

static func _approach_tiles_for_catalog(point: Dictionary, preferred_zone_id: String, zone_grid: Array, terrain_rows: Array, occupied: Dictionary, catalog: Dictionary, runtime_body: Array) -> Array:
	if catalog.is_empty():
		return _approach_tiles_for_point(point, preferred_zone_id, zone_grid, terrain_rows, occupied)
	var result := []
	var body_lookup := _point_lookup(runtime_body)
	for offset in catalog.get("approach_mask", []):
		if not (offset is Dictionary):
			continue
		var nx: int = int(point.get("x", 0)) + int(offset.get("x", 0))
		var ny: int = int(point.get("y", 0)) + int(offset.get("y", 0))
		if not _point_in_rows(terrain_rows, nx, ny):
			continue
		var key := _point_key(nx, ny)
		if body_lookup.has(key) or occupied.has(key):
			continue
		if not _terrain_cell_is_passable(terrain_rows, nx, ny):
			continue
		if preferred_zone_id != "" and _zone_at_point(zone_grid, _point_dict(nx, ny)) != preferred_zone_id:
			continue
		result.append(_point_dict(nx, ny))
	if result.size() < 2:
		for fallback in _approach_tiles_for_point(point, preferred_zone_id, zone_grid, terrain_rows, occupied):
			if fallback is Dictionary and not _point_in_array(result, fallback):
				result.append(fallback)
	return result

static func _approach_tiles_for_point(point: Dictionary, preferred_zone_id: String, zone_grid: Array, terrain_rows: Array, occupied: Dictionary) -> Array:
	var result := []
	var x := int(point.get("x", 0))
	var y := int(point.get("y", 0))
	for offset in _cardinal_offsets():
		var nx: int = x + int(offset.x)
		var ny: int = y + int(offset.y)
		if not _point_in_rows(terrain_rows, nx, ny):
			continue
		if occupied.has(_point_key(nx, ny)):
			continue
		if not _terrain_cell_is_passable(terrain_rows, nx, ny):
			continue
		if preferred_zone_id != "" and _zone_at_point(zone_grid, _point_dict(nx, ny)) != preferred_zone_id:
			continue
		result.append(_point_dict(nx, ny))
	if result.is_empty():
		for offset in _cardinal_offsets():
			var nx: int = x + int(offset.x)
			var ny: int = y + int(offset.y)
			if _point_in_rows(terrain_rows, nx, ny) and not occupied.has(_point_key(nx, ny)) and _terrain_cell_is_passable(terrain_rows, nx, ny):
				result.append(_point_dict(nx, ny))
	if result.size() < 2:
		for radius in range(2, 5):
			for dy in range(-radius, radius + 1):
				for dx in range(-radius, radius + 1):
					if max(abs(dx), abs(dy)) != radius:
						continue
					var cx := x + dx
					var cy := y + dy
					if not _point_in_rows(terrain_rows, cx, cy):
						continue
					if occupied.has(_point_key(cx, cy)) or not _terrain_cell_is_passable(terrain_rows, cx, cy):
						continue
					if preferred_zone_id != "" and _zone_at_point(zone_grid, _point_dict(cx, cy)) != preferred_zone_id and radius < 4:
						continue
					var candidate := _point_dict(cx, cy)
					if not _point_in_array(result, candidate):
						result.append(candidate)
					if result.size() >= 2:
						return result
	return result

static func _occupied_body_lookup(object_placements: Array) -> Dictionary:
	var occupied := {}
	for placement in object_placements:
		if not (placement is Dictionary):
			continue
		for body in placement.get("body_tiles", []):
			if body is Dictionary:
				occupied[_point_key(int(body.get("x", 0)), int(body.get("y", 0)))] = String(placement.get("placement_id", ""))
	return occupied

static func _object_placements_by_zone_and_kind(object_placements: Array) -> Dictionary:
	var result := {}
	for placement in object_placements:
		if not (placement is Dictionary):
			continue
		var zone_id := String(placement.get("zone_id", ""))
		if not result.has(zone_id):
			result[zone_id] = {}
		var kind := String(placement.get("kind", ""))
		if not result[zone_id].has(kind):
			result[zone_id][kind] = []
		result[zone_id][kind].append(placement)
	return result

static func _route_nodes_payload(seeds: Dictionary, placements: Dictionary) -> Dictionary:
	var nodes := {}
	for zone_id in _sorted_keys(seeds):
		nodes["node_zone_%s" % String(zone_id)] = {
			"id": "node_zone_%s" % String(zone_id),
			"kind": "zone_anchor",
			"zone_id": String(zone_id),
			"point": seeds[zone_id],
			"required": false,
		}
	for placement in placements.get("object_placements", []):
		if not (placement is Dictionary):
			continue
		var placement_id := String(placement.get("placement_id", ""))
		var kind := String(placement.get("kind", ""))
		if kind not in ["town", "resource_site", "mine", "neutral_dwelling", "route_guard"]:
			continue
		var required_node := kind == "resource_site" or (kind in ["town", "mine", "neutral_dwelling"] and int(placement.get("player_slot", 0)) > 0)
		var node_id := "node_%s" % placement_id
		nodes[node_id] = {
			"id": node_id,
			"kind": kind,
			"placement_id": placement_id,
			"zone_id": String(placement.get("zone_id", "")),
			"point": _first_approach_or_body(placement),
			"body_tiles": placement.get("body_tiles", []),
			"required": required_node,
		}
	return nodes

static func _preferred_route_node_for_zone(zone_id: String, object_by_zone: Dictionary, route_nodes: Dictionary) -> Dictionary:
	var zone_objects: Dictionary = object_by_zone.get(zone_id, {})
	var towns: Array = zone_objects.get("town", [])
	if not towns.is_empty() and towns[0] is Dictionary:
		return route_nodes.get("node_%s" % String(towns[0].get("placement_id", "")), {"id": "node_zone_%s" % zone_id, "point": _point_dict(0, 0)})
	return route_nodes.get("node_zone_%s" % zone_id, {"id": "node_zone_%s" % zone_id, "point": _point_dict(0, 0)})

static func _first_approach_or_body(placement: Dictionary) -> Dictionary:
	var approaches: Array = placement.get("approach_tiles", [])
	if not approaches.is_empty() and approaches[0] is Dictionary:
		return approaches[0]
	var bodies: Array = placement.get("body_tiles", [])
	if not bodies.is_empty() and bodies[0] is Dictionary:
		return bodies[0]
	return _point_dict(int(placement.get("x", 0)), int(placement.get("y", 0)))

static func _route_classification(link: Dictionary, path_found: bool) -> String:
	if not path_found:
		return "blocked_connectivity"
	if bool(link.get("border_guard", false)):
		return "guarded_connectivity_border_guard"
	if bool(link.get("wide", false)):
		return "full_connectivity_wide_unguarded"
	if int(link.get("guard_value", 0)) > 0:
		return "guarded_connectivity"
	return "full_connectivity"

static func _route_edge_id(index: int, from_zone: String, to_zone: String) -> String:
	return "edge_%02d_%s_%s" % [index, from_zone, to_zone]

static func _route_anchor_candidate(path: Array, from_anchor: Dictionary, to_anchor: Dictionary) -> Dictionary:
	if not path.is_empty():
		var midpoint = path[int(floor(float(path.size() - 1) * 0.5))]
		if midpoint is Dictionary:
			return {
				"x": int(midpoint.get("x", 0)),
				"y": int(midpoint.get("y", 0)),
				"source": "route_path_midpoint",
			}
	if not from_anchor.is_empty() and not to_anchor.is_empty():
		return {
			"x": int(round((int(from_anchor.get("x", 0)) + int(to_anchor.get("x", 0))) * 0.5)),
			"y": int(round((int(from_anchor.get("y", 0)) + int(to_anchor.get("y", 0))) * 0.5)),
			"source": "anchor_midpoint_fallback",
		}
	return {}

static func _road_segment_payload(edge_id: String, path: Array, classification: String, edge: Dictionary) -> Dictionary:
	return {
		"id": "road_%s" % edge_id,
		"route_edge_id": edge_id,
		"overlay_id": ROAD_OVERLAY_ID,
		"cells": path,
		"cell_count": path.size(),
		"connectivity_classification": classification,
		"transit_semantics": edge.get("transit_semantics", {}),
		"role": String(edge.get("role", "")),
		"writeout_state": "staged_overlay_no_tile_bytes_written",
	}

static func _find_passable_path(start: Dictionary, goal: Dictionary, terrain_rows: Array, occupied: Dictionary) -> Array:
	if start.is_empty() or goal.is_empty():
		return []
	var start_x := int(start.get("x", 0))
	var start_y := int(start.get("y", 0))
	var goal_x := int(goal.get("x", 0))
	var goal_y := int(goal.get("y", 0))
	if not _point_in_rows(terrain_rows, start_x, start_y) or not _point_in_rows(terrain_rows, goal_x, goal_y):
		return []
	if occupied.has(_point_key(start_x, start_y)) or occupied.has(_point_key(goal_x, goal_y)):
		return []
	if not _terrain_cell_is_passable(terrain_rows, start_x, start_y) or not _terrain_cell_is_passable(terrain_rows, goal_x, goal_y):
		return []
	var start_key := _point_key(start_x, start_y)
	var goal_key := _point_key(goal_x, goal_y)
	var queue := [_point_dict(start_x, start_y)]
	var came_from := {start_key: ""}
	var cursor := 0
	while cursor < queue.size():
		var current: Dictionary = queue[cursor]
		cursor += 1
		var current_key := _point_key(int(current.get("x", 0)), int(current.get("y", 0)))
		if current_key == goal_key:
			break
		for offset in _cardinal_offsets():
			var nx: int = int(current.get("x", 0)) + int(offset.x)
			var ny: int = int(current.get("y", 0)) + int(offset.y)
			var next_key := _point_key(nx, ny)
			if came_from.has(next_key):
				continue
			if not _point_in_rows(terrain_rows, nx, ny):
				continue
			if occupied.has(next_key):
				continue
			if not _terrain_cell_is_passable(terrain_rows, nx, ny):
				continue
			came_from[next_key] = current_key
			queue.append(_point_dict(nx, ny))
	if not came_from.has(goal_key):
		return []
	var reversed_path := []
	var key := goal_key
	var guard: int = terrain_rows.size() * (terrain_rows[0].size() if not terrain_rows.is_empty() and terrain_rows[0] is Array else 1)
	while key != "" and guard > 0:
		var parts := key.split(",")
		reversed_path.append(_point_dict(int(parts[0]), int(parts[1])))
		key = String(came_from.get(key, ""))
		guard -= 1
	reversed_path.reverse()
	return reversed_path

static func _connect_adjacency(adjacency: Dictionary, a: String, b: String) -> void:
	if not adjacency.has(a):
		adjacency[a] = []
	if not adjacency.has(b):
		adjacency[b] = []
	if b not in adjacency[a]:
		adjacency[a].append(b)
	if a not in adjacency[b]:
		adjacency[b].append(a)

static func _reachability_proof(route_nodes: Dictionary, edges: Array, adjacency: Dictionary) -> Dictionary:
	var required_nodes := []
	for node_id in _sorted_keys(route_nodes):
		var node: Dictionary = route_nodes[node_id]
		if bool(node.get("required", false)):
			required_nodes.append(String(node_id))
	if required_nodes.is_empty():
		return {"status": "fail", "reason": "no_required_nodes", "required_nodes": []}
	var start_node: String = String(required_nodes[0])
	var visited := {start_node: true}
	var queue := [start_node]
	var cursor := 0
	while cursor < queue.size():
		var current := String(queue[cursor])
		cursor += 1
		for next_id in adjacency.get(current, []):
			var next_key := String(next_id)
			if visited.has(next_key):
				continue
			visited[next_key] = true
			queue.append(next_key)
	var unreachable := []
	for node_id in required_nodes:
		if not visited.has(node_id):
			unreachable.append(node_id)
	var blocked_edges := []
	for edge in edges:
		if edge is Dictionary and bool(edge.get("required", false)) and not bool(edge.get("path_found", false)):
			blocked_edges.append(String(edge.get("id", "")))
	return {
		"status": "pass" if unreachable.is_empty() and blocked_edges.is_empty() else "fail",
		"model": "required_nodes_connected_by_passable_staged_road_paths",
		"required_nodes": required_nodes,
		"reachable_required_nodes": required_nodes.size() - unreachable.size(),
		"unreachable_required_nodes": unreachable,
		"blocked_required_edges": blocked_edges,
	}

static func _route_counts_by_zone(edges: Array) -> Dictionary:
	var counts := {}
	for edge in edges:
		if not (edge is Dictionary):
			continue
		for endpoint_key in ["from", "to"]:
			var zone_id := String(edge.get(endpoint_key, ""))
			if zone_id.begins_with("rmg_"):
				continue
			if not counts.has(zone_id):
				counts[zone_id] = {}
			var role := String(edge.get("role", "route"))
			counts[zone_id][role] = int(counts[zone_id].get(role, 0)) + 1
			for contract_role in edge.get("layout_contract_roles", []):
				counts[zone_id][String(contract_role)] = int(counts[zone_id].get(String(contract_role), 0)) + 1
	return counts

static func _support_resource_count_for_zone(resource_nodes: Array, zone_id: String) -> int:
	var count := 0
	for resource in resource_nodes:
		if resource is Dictionary and String(resource.get("zone_id", "")) == zone_id:
			count += 1
	return count

static func _resources_by_zone(resource_nodes: Array) -> Dictionary:
	var result := {}
	for resource in resource_nodes:
		if not (resource is Dictionary):
			continue
		var zone_id := String(resource.get("zone_id", ""))
		if not result.has(zone_id):
			result[zone_id] = []
		result[zone_id].append(resource)
	return result

static func _start_zones_from_towns(towns: Array) -> Array:
	var result := []
	for town in towns:
		if town is Dictionary and int(town.get("player_slot", 0)) > 0:
			var zone_id := String(town.get("zone_id", ""))
			if zone_id != "" and zone_id not in result:
				result.append(zone_id)
	result.sort()
	return result

static func _resource_route_edges_by_town(edges: Array) -> Dictionary:
	var result := {}
	for edge in edges:
		if not (edge is Dictionary) or String(edge.get("role", "")) != "required_start_economy_route":
			continue
		var town_id := String(edge.get("from", ""))
		if not result.has(town_id):
			result[town_id] = []
		result[town_id].append(edge)
	return result

static func _edges_for_zone_and_role(edges: Array, zone_id: String, role: String) -> Array:
	var result := []
	for edge in edges:
		if not (edge is Dictionary):
			continue
		if String(edge.get("role", "")) != role and String(role) not in edge.get("layout_contract_roles", []):
			continue
		if String(edge.get("from", "")) == zone_id or String(edge.get("to", "")) == zone_id:
			result.append(edge)
	return result

static func _layout_contract_roles_for_route(role: String) -> Array:
	match role:
		"contest_route":
			return ["contest_route", "guarded_route"]
		"early_reward_route", "reward_to_junction":
			return ["early_reward_route", "reward_route", "guarded_route"]
		"template_connection":
			return ["contest_route", "early_reward_route", "reward_route", "guarded_route"]
		_:
			return []

static func _route_has_layout_contract_role(edge: Dictionary, role: String) -> bool:
	if String(edge.get("role", "")) == role:
		return true
	for contract_role in edge.get("layout_contract_roles", []):
		if String(contract_role) == role:
			return true
	return false

static func _resource_support_purpose(site_id: String) -> String:
	match site_id:
		"site_wood_wagon":
			return "early_wood_support"
		"site_ore_crates":
			return "early_ore_support"
		"site_waystone_cache":
			return "early_gold_support"
		_:
			return "unknown_resource_support"

static func _guard_risk_class(edge: Dictionary) -> String:
	if bool(edge.get("border_guard", false)):
		return "special_border_guard"
	if bool(edge.get("wide", false)):
		return "wide_unguarded_normal_guard_suppressed"
	var guard_value := int(edge.get("guard_value", 0))
	if guard_value <= 0:
		return "unguarded"
	if guard_value <= 200:
		return "low"
	if guard_value <= 700:
		return "medium"
	return "high"

static func _effective_guard_pressure(edge: Dictionary) -> int:
	if bool(edge.get("wide", false)):
		return 0
	var value := int(edge.get("guard_value", 0))
	if bool(edge.get("border_guard", false)):
		value += 500
	return value

static func _spread_status(values: Array, warning_threshold: int, fail_threshold: int) -> String:
	if values.size() <= 1:
		return "pass"
	var spread := int(_spread_summary(values).get("spread", 0))
	if spread > fail_threshold:
		return "fail"
	if spread > warning_threshold:
		return "warning"
	return "pass"

static func _spread_summary(values: Array) -> Dictionary:
	if values.is_empty():
		return {"count": 0, "min": 0, "max": 0, "spread": 0}
	var minimum := int(values[0])
	var maximum := int(values[0])
	for value in values:
		minimum = min(minimum, int(value))
		maximum = max(maximum, int(value))
	return {"count": values.size(), "min": minimum, "max": maximum, "spread": maximum - minimum}

static func _max_int(values: Array) -> int:
	var result := 0
	for value in values:
		result = max(result, int(value))
	return result

static func _cardinal_offsets() -> Array:
	return [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]

static func _terrain_is_passable(terrain_id: String) -> bool:
	return _terrain_is_known_original(terrain_id) and terrain_id not in BLOCKED_TERRAIN_IDS

static func _terrain_is_known_original(terrain_id: String) -> bool:
	return String(terrain_id) in ORIGINAL_TERRAIN_IDS

static func _normalize_terrain_id_for_generated_rows(terrain_id: String) -> String:
	var normalized := String(terrain_id)
	if normalized in SURFACE_SCENARIO_TERRAIN_IDS:
		return normalized
	match normalized:
		"mire":
			return "swamp"
		"hills", "ridge", "badlands", "wastes", "ash", "lava", "snow", "frost", "cavern", "underway":
			return "highland"
		"coast", "shore":
			return "water"
		_:
			return "grass" if not _terrain_is_known_original(normalized) else normalized

static func _terrain_movement_cost(terrain_id: String) -> int:
	return int(TERRAIN_MOVEMENT_COST.get(String(terrain_id), 999))

static func _unsupported_terrain_ids(terrain_ids: Array) -> Array:
	var result := []
	for terrain_id in terrain_ids:
		var text := String(terrain_id)
		if text != "" and not _terrain_is_known_original(text) and text not in result:
			result.append(text)
	result.sort()
	return result

static func _passable_known_terrain_ids(terrain_ids: Array) -> Array:
	var result := []
	for terrain_id in terrain_ids:
		var text := String(terrain_id)
		if text != "" and _terrain_is_passable(text) and text not in result:
			result.append(text)
	return result

static func _unique_sorted_strings(values: Array) -> Array:
	var seen := {}
	for value in values:
		var text := String(value)
		if text != "":
			seen[text] = true
	return _sorted_keys(seen)

static func _terrain_counts(terrain_rows: Array) -> Dictionary:
	var counts := {}
	for row_value in terrain_rows:
		var row: Array = row_value
		for terrain_id in row:
			var key := String(terrain_id)
			counts[key] = int(counts.get(key, 0)) + 1
	return _sorted_dict(counts)

static func _passability_rows(terrain_rows: Array) -> Array:
	var rows := []
	for row_value in terrain_rows:
		var source_row: Array = row_value
		var row := []
		for terrain_id in source_row:
			row.append(_terrain_is_passable(String(terrain_id)))
		rows.append(row)
	return rows

static func _movement_cost_rows(terrain_rows: Array) -> Array:
	var rows := []
	for row_value in terrain_rows:
		var source_row: Array = row_value
		var row := []
		for terrain_id in source_row:
			row.append(_terrain_movement_cost(String(terrain_id)))
		rows.append(row)
	return rows

static func _terrain_cell_is_passable(terrain_rows: Array, x: int, y: int) -> bool:
	if not _point_in_rows(terrain_rows, x, y):
		return false
	return _terrain_is_passable(String(terrain_rows[y][x]))

static func _biome_for_terrain(terrain_id: String) -> String:
	return String(BIOME_BY_TERRAIN.get(terrain_id, "biome_grasslands"))

static func _point_in_rows(rows: Array, x: int, y: int) -> bool:
	if y < 0 or y >= rows.size() or not (rows[y] is Array):
		return false
	var row: Array = rows[y]
	return x >= 0 and x < row.size()

static func _point_in_array(points: Array, point: Dictionary) -> bool:
	var key := _point_key(int(point.get("x", 0)), int(point.get("y", 0)))
	for existing in points:
		if existing is Dictionary and _point_key(int(existing.get("x", 0)), int(existing.get("y", 0))) == key:
			return true
	return false

static func _load_template_catalog() -> Dictionary:
	if not FileAccess.file_exists(TEMPLATE_CATALOG_PATH):
		return {"schema_id": "", "profiles": [], "templates": []}
	var file := FileAccess.open(TEMPLATE_CATALOG_PATH, FileAccess.READ)
	if file == null:
		return {"schema_id": "", "profiles": [], "templates": []}
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return {"schema_id": "", "profiles": [], "templates": []}
	return parsed

static func _generation_seed_payload(normalized: Dictionary) -> Dictionary:
	var profile: Dictionary = normalized.get("profile", {}).duplicate(true)
	if String(profile.get("template_id", "")).strip_edges() == "":
		profile.erase("template_id")
	var assignment: Dictionary = normalized.get("player_assignment", {}) if normalized.get("player_assignment", {}) is Dictionary else {}
	if not assignment.is_empty() and String(assignment.get("assignment_policy", "")) == "fixed_owner_slots_first_n_players_seeded_factions":
		profile["faction_ids"] = assignment.get("faction_pool", profile.get("faction_ids", []))
		profile.erase("town_ids")
	var manifest := {
		"faction_ids": profile.get("faction_ids", []),
		"town_ids": profile.get("town_ids", []),
		"resource_site_ids": profile.get("resource_site_ids", []),
		"encounter_ids": [String(profile.get("encounter_id", DEFAULT_ENCOUNTER_ID))],
		"terrain_ids": profile.get("terrain_ids", []),
	}
	var payload := {
		"generator_version": String(normalized.get("generator_version", GENERATOR_VERSION)),
		"seed": String(normalized.get("seed", "0")),
		"size": _generation_size_seed_payload(normalized.get("size", {})),
		"player_constraints": normalized.get("player_constraints", {}),
		"profile": profile,
		"content_manifest_fingerprint": _hash32_hex(_stable_stringify(manifest)),
	}
	if String(normalized.get("template_selection", {}).get("source", "")) == "content_catalog":
		payload["template_id"] = String(normalized.get("template_id", TEMPLATE_ID))
	return payload

static func _generation_size_seed_payload(size: Dictionary) -> Dictionary:
	var result := size.duplicate(true)
	if String(result.get("water_mode", "land")) == "land":
		result.erase("water_mode")
	if int(result.get("level_count", 1)) == 1:
		result.erase("level_count")
	if not bool(result.get("underground", false)):
		result.erase("underground")
	return result

static func _select_template_profile(input_config: Dictionary, size: Dictionary, player_constraints: Dictionary, seed: String, input_profile: Dictionary) -> Dictionary:
	var catalog := _load_template_catalog()
	var templates: Array = catalog.get("templates", [])
	var profiles: Array = catalog.get("profiles", [])
	var raw_profile = input_config.get("profile", {})
	var profile_id_was_explicit: bool = raw_profile is Dictionary and raw_profile.has("id") and String(raw_profile.get("id", "")).strip_edges() != ""
	var profile_template_was_explicit: bool = raw_profile is Dictionary and raw_profile.has("template_id") and String(raw_profile.get("template_id", "")).strip_edges() != ""
	var template_id_was_explicit: bool = input_config.has("template_id") and String(input_config.get("template_id", "")).strip_edges() != ""
	var requested_template_id := String(input_config.get("template_id", input_profile.get("template_id", ""))).strip_edges()
	var requested_profile_id := String(input_profile.get("id", "")).strip_edges() if profile_id_was_explicit else ""
	var explicit_catalog_request: bool = requested_template_id != "" or profile_template_was_explicit
	var profile_by_id := {}
	var profile_by_template := {}
	for profile in profiles:
		if not (profile is Dictionary):
			continue
		var profile_id := String(profile.get("id", ""))
		var profile_template_id := String(profile.get("template_id", ""))
		if profile_id != "":
			profile_by_id[profile_id] = profile
		if profile_template_id != "" and not profile_by_template.has(profile_template_id):
			profile_by_template[profile_template_id] = profile
	if requested_template_id == "" and requested_profile_id != "" and not profile_by_id.has(requested_profile_id):
		return {
			"template": {},
			"profile": {},
			"source": "built_in_fallback_unknown_explicit_profile",
			"requested_template_id": requested_template_id,
			"requested_profile_id": requested_profile_id,
		}
	var template_candidates := []
	var candidate_rejections := []
	var requested_template_seen := false
	for template in templates:
		if not (template is Dictionary):
			continue
		var template_id := String(template.get("id", ""))
		if requested_template_id != "" and template_id != requested_template_id:
			continue
		if requested_template_id != "" and template_id == requested_template_id:
			requested_template_seen = true
		if requested_template_id == "" and profile_by_id.has(requested_profile_id) and template_id != String(profile_by_id[requested_profile_id].get("template_id", "")):
			continue
		var constraint_report := _template_constraint_report(template, size, player_constraints)
		if not bool(constraint_report.get("matches", false)):
			candidate_rejections.append(constraint_report)
			continue
		template_candidates.append(template)
	var source := "content_catalog"
	if template_candidates.is_empty() and requested_template_id != "":
		source = "rejected_explicit_template"
		var failure_code := "template_constraints_failed" if requested_template_seen else "template_not_found"
		return {
			"template": {},
			"profile": {},
			"source": source,
			"rejected": true,
			"failure_code": failure_code,
			"rejection_reasons": _selection_rejection_reasons(failure_code, requested_template_id, requested_profile_id, candidate_rejections),
			"constraint_report": candidate_rejections[0] if not candidate_rejections.is_empty() else {},
			"candidate_rejections": candidate_rejections,
			"requested_template_id": requested_template_id,
			"requested_profile_id": requested_profile_id,
		}
	if template_candidates.is_empty() and profile_by_id.has(requested_profile_id):
		source = "rejected_explicit_profile"
		var requested_profile_template_id := String(profile_by_id[requested_profile_id].get("template_id", ""))
		return {
			"template": {},
			"profile": profile_by_id[requested_profile_id],
			"source": source,
			"rejected": true,
			"failure_code": "profile_template_constraints_failed",
			"rejection_reasons": _selection_rejection_reasons("profile_template_constraints_failed", requested_profile_template_id, requested_profile_id, candidate_rejections),
			"constraint_report": candidate_rejections[0] if not candidate_rejections.is_empty() else {},
			"candidate_rejections": candidate_rejections,
			"requested_template_id": requested_template_id,
			"requested_profile_id": requested_profile_id,
		}
	if template_candidates.is_empty():
		source = "built_in_fallback_no_catalog_match"
		if explicit_catalog_request or template_id_was_explicit:
			source = "rejected_explicit_template"
		return {
			"template": {},
			"profile": {},
			"source": source,
			"rejected": source.begins_with("rejected"),
			"failure_code": "no_catalog_template_matched_constraints",
			"rejection_reasons": _selection_rejection_reasons("no_catalog_template_matched_constraints", requested_template_id, requested_profile_id, candidate_rejections),
			"candidate_rejections": candidate_rejections,
			"requested_template_id": requested_template_id,
			"requested_profile_id": requested_profile_id,
		}
	template_candidates.sort_custom(Callable(RandomMapGeneratorRules, "_compare_template_id"))
	var selected_index := 0
	if requested_template_id == "" and not profile_by_id.has(requested_profile_id):
		selected_index = _stable_choice_index(template_candidates.size(), "%s:%s:%s" % [seed, String(size.get("preset", "")), _stable_stringify(player_constraints)])
	var selected_template: Dictionary = template_candidates[selected_index]
	var selected_profile: Dictionary = {}
	if profile_by_id.has(requested_profile_id) and String(profile_by_id[requested_profile_id].get("template_id", "")) == String(selected_template.get("id", "")):
		selected_profile = profile_by_id[requested_profile_id]
	elif profile_by_template.has(String(selected_template.get("id", ""))):
		selected_profile = profile_by_template[String(selected_template.get("id", ""))]
	return {
		"template": selected_template,
		"profile": selected_profile,
		"source": source,
		"rejected": false,
		"requested_template_id": requested_template_id,
		"requested_profile_id": requested_profile_id,
		"candidate_count": template_candidates.size(),
		"constraint_report": _template_constraint_report(selected_template, size, player_constraints),
	}

static func _template_matches_constraints(template: Dictionary, size: Dictionary, player_constraints: Dictionary) -> bool:
	return bool(_template_constraint_report(template, size, player_constraints).get("matches", false))

static func _template_constraint_report(template: Dictionary, size: Dictionary, player_constraints: Dictionary) -> Dictionary:
	var failures := []
	var size_score: Dictionary = template.get("size_score", {}) if template.get("size_score", {}) is Dictionary else {}
	var score := _template_map_size_score(template, size)
	if score < int(size_score.get("min", 1)) or score > int(size_score.get("max", 999999)):
		failures.append("size_score %d outside template range %d..%d" % [score, int(size_score.get("min", 1)), int(size_score.get("max", 999999))])
	var map_support: Dictionary = template.get("map_support", {}) if template.get("map_support", {}) is Dictionary else {}
	var requested_water_mode := String(size.get("water_mode", "land"))
	var supported_water_modes := _normalized_string_array(map_support.get("water_modes", ["land"]), ["land"])
	if not _water_mode_supported(requested_water_mode, supported_water_modes):
		failures.append("water_mode %s unsupported by template modes %s" % [requested_water_mode, ",".join(supported_water_modes)])
	var levels: Dictionary = map_support.get("levels", {}) if map_support.get("levels", {}) is Dictionary else {}
	var supported_counts := []
	if levels.get("supported_counts", []) is Array:
		for supported_count in levels.get("supported_counts", []):
			supported_counts.append(int(supported_count))
	if supported_counts.is_empty():
		supported_counts = [1]
	var requested_level_count := int(size.get("level_count", 1))
	if requested_level_count not in supported_counts:
		failures.append("level_count %d unsupported by template counts %s" % [requested_level_count, JSON.stringify(supported_counts)])
	var players: Dictionary = template.get("players", {}) if template.get("players", {}) is Dictionary else {}
	var humans: Dictionary = players.get("humans", {}) if players.get("humans", {}) is Dictionary else {}
	var total: Dictionary = players.get("total", {}) if players.get("total", {}) is Dictionary else {}
	var human_count := int(player_constraints.get("human_count", 1))
	var player_count := int(player_constraints.get("player_count", 2))
	if human_count < int(humans.get("min", 1)) or human_count > int(humans.get("max", 8)):
		failures.append("human_count %d outside template range %d..%d" % [human_count, int(humans.get("min", 1)), int(humans.get("max", 8))])
	if player_count < int(total.get("min", 2)) or player_count > int(total.get("max", 8)):
		failures.append("player_count %d outside template range %d..%d" % [player_count, int(total.get("min", 2)), int(total.get("max", 8))])
	var capacity := _template_start_capacity(template)
	if int(capacity.get("human_start_capacity", 0)) < human_count:
		failures.append("human start capacity %d below requested humans %d" % [int(capacity.get("human_start_capacity", 0)), human_count])
	if int(capacity.get("total_start_capacity", 0)) < player_count:
		failures.append("total start capacity %d below requested players %d" % [int(capacity.get("total_start_capacity", 0)), player_count])
	var graph_summary: Dictionary = template.get("graph_summary", {}) if template.get("graph_summary", {}) is Dictionary else {}
	var error_policy: Dictionary = template.get("error_policy", {}) if template.get("error_policy", {}) is Dictionary else {}
	if template.get("zones", []).is_empty():
		failures.append("template has no zones")
	if template.get("links", []).is_empty():
		failures.append("template has no links")
	if bool(error_policy.get("disconnected_source_graph", false)) or bool(graph_summary.has("connected") and not bool(graph_summary.get("connected", true))):
		failures.append("template source graph is disconnected under policy %s" % String(error_policy.get("policy", "unknown")))
	return {
		"matches": failures.is_empty(),
		"template_id": String(template.get("id", "")),
		"failures": failures,
		"requested": {
			"size_score": score,
			"water_mode": requested_water_mode,
			"level_count": requested_level_count,
			"human_count": human_count,
			"player_count": player_count,
		},
		"supported": {
			"size_score": size_score,
			"water_modes": supported_water_modes,
			"level_counts": supported_counts,
			"humans": humans,
			"total": total,
			"supported_config_count": int(players.get("supported_config_count", 0)),
			"team_mode": String(players.get("team_mode", "free_for_all")),
		},
		"capacity": capacity,
		"error_policy": error_policy,
		"graph_summary": graph_summary,
	}

static func _template_start_capacity(template: Dictionary) -> Dictionary:
	var human_slots := {}
	var total_slots := {}
	for zone in template.get("zones", []):
		if not (zone is Dictionary):
			continue
		var role := String(zone.get("role", ""))
		var owner_slot = zone.get("owner_slot", null)
		if owner_slot == null:
			continue
		var slot := int(owner_slot)
		if slot <= 0:
			continue
		if role == "human_start":
			human_slots[slot] = true
			total_slots[slot] = true
		elif role == "computer_start" or role.ends_with("_start"):
			total_slots[slot] = true
	return {
		"human_start_capacity": human_slots.size(),
		"total_start_capacity": total_slots.size(),
		"fixed_owner_slots": _sorted_int_keys(total_slots),
		"human_owner_slots": _sorted_int_keys(human_slots),
	}

static func _selection_rejection_reasons(failure_code: String, requested_template_id: String, requested_profile_id: String, candidate_rejections: Array) -> Array:
	var reasons := []
	match failure_code:
		"template_not_found":
			reasons.append("requested template %s was not found in the catalog" % requested_template_id)
		"profile_template_constraints_failed":
			reasons.append("requested profile %s template did not satisfy requested map constraints" % requested_profile_id)
		"template_constraints_failed":
			reasons.append("requested template %s did not satisfy requested map constraints" % requested_template_id)
		_:
			reasons.append("no catalog template satisfied requested map constraints")
	for rejection in candidate_rejections:
		if not (rejection is Dictionary):
			continue
		for failure in rejection.get("failures", []):
			reasons.append("%s: %s" % [String(rejection.get("template_id", "")), String(failure)])
	if reasons.is_empty():
		reasons.append(failure_code)
	return reasons

static func _zone_has_expanded_grammar_fields(zone: Dictionary) -> bool:
	for key in ["player_filter", "ownership", "player_towns", "neutral_towns", "town_policy", "mine_requirements", "resource_category_requirements", "treasure_bands", "monster_policy"]:
		if not zone.has(key):
			return false
	return true

static func _link_has_expanded_grammar_fields(link: Dictionary) -> bool:
	for key in ["player_filter", "guard", "special_payload", "unsupported_runtime_fields"]:
		if not link.has(key):
			return false
	return link.has("wide") and link.has("border_guard")

static func _map_size_score(size: Dictionary) -> int:
	var width := int(size.get("width", 16))
	var height := int(size.get("height", 12))
	var level_count := int(size.get("level_count", 1))
	return max(1, int((width * height * max(1, level_count)) / 0x510))

static func _template_map_size_score(template: Dictionary, size: Dictionary) -> int:
	var score := _map_size_score(size)
	var map_support: Dictionary = template.get("map_support", {}) if template.get("map_support", {}) is Dictionary else {}
	var water_modes := _normalized_string_array(map_support.get("water_modes", ["land"]), ["land"])
	if String(size.get("water_mode", "land")) == "islands" and "islands_size_score_halved" in water_modes:
		score = max(1, int(ceil(float(score) * 0.5)))
	return score

static func _water_mode_supported(requested_water_mode: String, supported_water_modes: Array) -> bool:
	if requested_water_mode in supported_water_modes:
		return true
	if requested_water_mode == "islands" and "islands_size_score_halved" in supported_water_modes:
		return true
	return false

static func _normalize_water_mode(value: Variant) -> String:
	var mode := String(value).strip_edges().to_lower()
	match mode:
		"land", "none", "dry":
			return "land"
		"island", "islands", "water", "mixed":
			return "islands"
		_:
			return mode if mode != "" else "land"

static func _stable_choice_index(size: int, seed_text: String) -> int:
	if size <= 0:
		return 0
	return int(_hash32_int(seed_text) % size)

static func _merge_profile_with_catalog(input_profile: Dictionary, catalog_profile: Dictionary, player_constraints: Dictionary) -> Dictionary:
	var merged := input_profile.duplicate(true)
	for key in ["label", "terrain_ids", "faction_ids", "encounter_id", "guard_strength_profile", "template_id"]:
		if not merged.has(key) and catalog_profile.has(key):
			merged[key] = catalog_profile[key]
	var terrain_ids := _normalized_string_array(merged.get("terrain_ids", CORE_TERRAIN_POOL), CORE_TERRAIN_POOL)
	var faction_ids := _normalized_string_array(merged.get("faction_ids", DEFAULT_FACTIONS), DEFAULT_FACTIONS)
	while faction_ids.size() < int(player_constraints.get("player_count", 2)):
		faction_ids.append(DEFAULT_FACTIONS[faction_ids.size() % DEFAULT_FACTIONS.size()])
	var town_ids := []
	for faction_id in faction_ids:
		town_ids.append(String(DEFAULT_TOWN_BY_FACTION.get(String(faction_id), "town_riverwatch")))
	var resource_site_ids := []
	for resource in SUPPORT_RESOURCE_SITES:
		resource_site_ids.append(String(resource.get("site_id", "")))
	merged["terrain_ids"] = terrain_ids
	merged["faction_ids"] = faction_ids.slice(0, int(player_constraints.get("player_count", 2)))
	merged["town_ids"] = town_ids.slice(0, int(player_constraints.get("player_count", 2)))
	merged["resource_site_ids"] = resource_site_ids
	merged["encounter_id"] = String(merged.get("encounter_id", DEFAULT_ENCOUNTER_ID))
	merged["guard_strength_profile"] = String(merged.get("guard_strength_profile", "core_low"))
	merged["template_family"] = String(merged.get("template_family", catalog_profile.get("template_family", "content_catalog_template_graph")))
	return merged

static func _build_player_assignment(template: Dictionary, profile: Dictionary, player_constraints: Dictionary, seed: String) -> Dictionary:
	if template.is_empty():
		return {}
	var player_count := int(player_constraints.get("player_count", 2))
	var human_count := int(player_constraints.get("human_count", 1))
	var team_mode := String(player_constraints.get("team_mode", "free_for_all"))
	var capacity := _template_start_capacity(template)
	var fixed_owner_slots: Array = capacity.get("fixed_owner_slots", [])
	var active_owner_slots := []
	for owner_slot in fixed_owner_slots:
		if int(owner_slot) > 0 and active_owner_slots.size() < player_count:
			active_owner_slots.append(int(owner_slot))
	var template_factions: Dictionary = template.get("faction_constraints", {}) if template.get("faction_constraints", {}) is Dictionary else {}
	var template_allowed := _normalized_string_array(template_factions.get("allowed", []), DEFAULT_FACTIONS)
	var profile_allowed := _normalized_string_array(profile.get("faction_ids", DEFAULT_FACTIONS), DEFAULT_FACTIONS)
	var base_pool := _intersection_string_arrays(profile_allowed, template_allowed)
	if base_pool.is_empty():
		base_pool = template_allowed if not template_allowed.is_empty() else profile_allowed
	var import_provenance: Dictionary = template.get("import_provenance", {}) if template.get("import_provenance", {}) is Dictionary else {}
	var seeded_faction_assignment := not import_provenance.is_empty()
	var rng := DeterministicRng.new(_positive_seed("%s:%s:player_assignment" % [seed, String(template.get("id", ""))]))
	var player_slots := []
	var by_owner_slot := {}
	var assigned_faction_ids := []
	var assigned_town_ids := []
	for index in range(active_owner_slots.size()):
		var owner_slot := int(active_owner_slots[index])
		var zone_allowed := _allowed_factions_for_owner_slot(template, owner_slot)
		var pool := _intersection_string_arrays(base_pool, zone_allowed) if not zone_allowed.is_empty() else base_pool.duplicate()
		if pool.is_empty():
			pool = base_pool.duplicate()
		if seeded_faction_assignment:
			pool.sort()
		var faction_id := String(pool[rng.next_index(pool.size())]) if seeded_faction_assignment else String(pool[index % pool.size()])
		if seeded_faction_assignment and pool.size() > 1:
			var guard := 0
			while faction_id in assigned_faction_ids and guard < pool.size():
				faction_id = String(pool[rng.next_index(pool.size())])
				guard += 1
		var player_slot := index + 1
		var player_type := "human" if player_slot <= human_count else "computer"
		var team_id := "team_%02d" % player_slot
		var town_id := String(DEFAULT_TOWN_BY_FACTION.get(faction_id, "town_riverwatch"))
		var slot_record := {
			"player_slot": player_slot,
			"owner_slot": owner_slot,
			"player_type": player_type,
			"faction_id": faction_id,
			"town_id": town_id,
			"team_id": team_id,
			"team_mode": team_mode,
			"ai_controlled": player_type != "human",
			"assignment_source": "fixed_owner_slot_seeded_faction_selection" if seeded_faction_assignment else "fixed_owner_slot_profile_order_preserved",
		}
		player_slots.append(slot_record)
		by_owner_slot[str(owner_slot)] = slot_record
		assigned_faction_ids.append(faction_id)
		assigned_town_ids.append(town_id)
	var teams := []
	for slot_record in player_slots:
		teams.append({
			"team_id": String(slot_record.get("team_id", "")),
			"player_slots": [int(slot_record.get("player_slot", 0))],
			"mode": "free_for_all",
		})
	return {
		"schema_id": "random_map_player_assignment_v1",
		"assignment_policy": "fixed_owner_slots_first_n_players_seeded_factions" if seeded_faction_assignment else "fixed_owner_slots_first_n_players_profile_order_preserved",
		"team_mode": team_mode,
		"team_metadata": {
			"mode": "free_for_all",
			"supported_now": team_mode == "free_for_all",
			"requested_mode": team_mode,
			"teams": teams,
		},
		"human_count": human_count,
		"computer_count": int(player_constraints.get("computer_count", max(0, player_count - human_count))),
		"player_count": player_count,
		"capacity": capacity,
		"active_owner_slots": active_owner_slots,
		"inactive_owner_slots": _inactive_owner_slots(fixed_owner_slots, active_owner_slots),
		"player_slots": player_slots,
		"player_slot_by_owner_slot": by_owner_slot,
		"assigned_faction_ids": assigned_faction_ids,
		"assigned_town_ids": assigned_town_ids,
		"faction_pool": base_pool,
	}

static func _allowed_factions_for_owner_slot(template: Dictionary, owner_slot: int) -> Array:
	var result := []
	for zone in template.get("zones", []):
		if not (zone is Dictionary) or zone.get("owner_slot", null) == null or int(zone.get("owner_slot", 0)) != owner_slot:
			continue
		result = _normalized_string_array(zone.get("allowed_faction_ids", []), [])
		var town_policy: Dictionary = zone.get("town_policy", {}) if zone.get("town_policy", {}) is Dictionary else {}
		result = _intersection_string_arrays(result, _normalized_string_array(town_policy.get("allowed_faction_ids", []), result)) if not result.is_empty() else _normalized_string_array(town_policy.get("allowed_faction_ids", []), [])
		break
	return result

static func _intersection_string_arrays(left: Array, right: Array) -> Array:
	var result := []
	for value in left:
		var text := String(value)
		if text in right and text not in result:
			result.append(text)
	return result

static func _inactive_owner_slots(fixed_owner_slots: Array, active_owner_slots: Array) -> Array:
	var result := []
	for owner_slot in fixed_owner_slots:
		if int(owner_slot) not in active_owner_slots:
			result.append(int(owner_slot))
	return result

static func _compare_template_id(a: Dictionary, b: Dictionary) -> bool:
	return String(a.get("id", "")) < String(b.get("id", ""))

static func _normalize_size(size_value: Variant) -> Dictionary:
	var preset := "small"
	var width := 16
	var height := 12
	var water_mode := "land"
	var level_count := 1
	if size_value is String:
		preset = String(size_value).strip_edges().to_lower()
		match preset:
			"medium":
				width = 24
				height = 18
			"large":
				width = 32
				height = 24
			_:
				preset = "small"
	elif size_value is Dictionary:
		preset = String(size_value.get("preset", "custom")).strip_edges().to_lower()
		width = int(size_value.get("width", width))
		height = int(size_value.get("height", height))
		water_mode = _normalize_water_mode(size_value.get("water_mode", size_value.get("water", water_mode)))
		level_count = clampi(int(size_value.get("level_count", size_value.get("levels", level_count))), 1, 2)
	width = clampi(width, 8, 64)
	height = clampi(height, 8, 48)
	return {"preset": preset, "width": width, "height": height, "water_mode": water_mode, "level_count": level_count, "underground": level_count > 1}

static func _normalize_player_constraints(value: Variant) -> Dictionary:
	var human_count := 1
	var computer_count := 1
	var player_count := 2
	var team_mode := "free_for_all"
	if value is Dictionary:
		human_count = clampi(int(value.get("human_count", value.get("humans", human_count))), 1, 8)
		if value.has("player_count") or value.has("total_count") or value.has("total"):
			player_count = clampi(int(value.get("player_count", value.get("total_count", value.get("total", player_count)))), 1, 8)
			player_count = max(player_count, human_count)
			computer_count = max(0, player_count - human_count)
		else:
			computer_count = clampi(int(value.get("computer_count", value.get("computers", computer_count))), 0, 7)
			player_count = clampi(human_count + computer_count, 1, 8)
		team_mode = String(value.get("team_mode", team_mode)).strip_edges().to_lower()
	if team_mode == "":
		team_mode = "free_for_all"
	return {"human_count": human_count, "computer_count": computer_count, "player_count": player_count, "team_mode": team_mode}

static func _normalize_profile(value: Variant, player_constraints: Dictionary) -> Dictionary:
	var profile: Dictionary = value if value is Dictionary else {}
	var profile_id := String(profile.get("id", "seeded_core_frontier")).strip_edges()
	if profile_id == "":
		profile_id = "seeded_core_frontier"
	var terrain_ids := _normalized_string_array(profile.get("terrain_ids", CORE_TERRAIN_POOL), CORE_TERRAIN_POOL)
	var faction_ids := _normalized_string_array(profile.get("faction_ids", DEFAULT_FACTIONS), DEFAULT_FACTIONS)
	while faction_ids.size() < int(player_constraints.get("player_count", 2)):
		faction_ids.append(DEFAULT_FACTIONS[faction_ids.size() % DEFAULT_FACTIONS.size()])
	var town_ids := []
	for faction_id in faction_ids:
		town_ids.append(String(DEFAULT_TOWN_BY_FACTION.get(String(faction_id), "town_riverwatch")))
	var resource_site_ids := []
	for resource in SUPPORT_RESOURCE_SITES:
		resource_site_ids.append(String(resource.get("site_id", "")))
	return {
		"id": profile_id,
		"label": String(profile.get("label", "Seeded Core Frontier")).strip_edges(),
		"template_id": String(profile.get("template_id", "")).strip_edges(),
		"template_family": "zone_connection_spoke",
		"terrain_ids": terrain_ids,
		"faction_ids": faction_ids.slice(0, int(player_constraints.get("player_count", 2))),
		"town_ids": town_ids.slice(0, int(player_constraints.get("player_count", 2))),
		"resource_site_ids": resource_site_ids,
		"encounter_id": String(profile.get("encounter_id", DEFAULT_ENCOUNTER_ID)),
		"guard_strength_profile": String(profile.get("guard_strength_profile", "core_low")),
	}

static func _normalized_string_array(value: Variant, fallback: Array) -> Array:
	var result := []
	if value is Array:
		for item in value:
			var text := String(item).strip_edges()
			if text != "" and text not in result:
				result.append(text)
	if result.is_empty():
		result = fallback.duplicate()
	return result

static func _terrain_rows_from_zone_layout(zone_layout: Dictionary, zones: Array) -> Array:
	var zone_grid: Array = zone_layout.get("surface_owner_grid", [])
	var water_lookup := _point_lookup(zone_layout.get("surface_water_cells", []))
	var zone_terrain := {}
	for zone in zones:
		if zone is Dictionary:
			zone_terrain[String(zone.get("id", ""))] = String(zone.get("terrain_id", "grass"))
	var rows := []
	for y in range(zone_grid.size()):
		var source_row: Array = zone_grid[y]
		var row := []
		for x in range(source_row.size()):
			if water_lookup.has(_point_key(x, y)):
				row.append("water")
			else:
				row.append(String(zone_terrain.get(String(source_row[x]), "grass")))
		rows.append(row)
	return rows

static func _terrain_rows_from_zone_grid(zone_grid: Array, zones: Array) -> Array:
	var zone_terrain := {}
	for zone in zones:
		if zone is Dictionary:
			zone_terrain[String(zone.get("id", ""))] = String(zone.get("terrain_id", "grass"))
	var rows := []
	for row_value in zone_grid:
		var source_row: Array = row_value
		var row := []
		for zone_id_value in source_row:
			row.append(String(zone_terrain.get(String(zone_id_value), "grass")))
		rows.append(row)
	return rows

static func _zone_area_targets(zone_ids: Array, base_sizes: Dictionary, total_cells: int) -> Dictionary:
	var targets := {}
	if zone_ids.is_empty():
		return targets
	var base_total := 0
	for zone_id in zone_ids:
		base_total += max(1, int(base_sizes.get(String(zone_id), 1)))
	var remainders := []
	var assigned := 0
	for zone_id_value in zone_ids:
		var zone_id := String(zone_id_value)
		var raw := float(total_cells) * float(max(1, int(base_sizes.get(zone_id, 1)))) / float(max(1, base_total))
		var target: int = max(1, int(floor(raw))) if total_cells >= zone_ids.size() else 0
		targets[zone_id] = target
		assigned += target
		remainders.append({"zone_id": zone_id, "remainder": raw - floor(raw)})
	remainders.sort_custom(Callable(RandomMapGeneratorRules, "_compare_area_remainder"))
	var difference := total_cells - assigned
	var cursor := 0
	while difference > 0 and not remainders.is_empty():
		var record: Dictionary = remainders[cursor % remainders.size()]
		var zone_id := String(record.get("zone_id", ""))
		targets[zone_id] = int(targets.get(zone_id, 0)) + 1
		difference -= 1
		cursor += 1
	while difference < 0 and not remainders.is_empty():
		var record: Dictionary = remainders[remainders.size() - 1 - (cursor % remainders.size())]
		var zone_id := String(record.get("zone_id", ""))
		if int(targets.get(zone_id, 0)) > 1:
			targets[zone_id] = int(targets.get(zone_id, 0)) - 1
			difference += 1
		cursor += 1
		if cursor > remainders.size() * 4:
			break
	return targets

static func _compare_area_remainder(a: Dictionary, b: Dictionary) -> bool:
	var left := float(a.get("remainder", 0.0))
	var right := float(b.get("remainder", 0.0))
	if is_equal_approx(left, right):
		return String(a.get("zone_id", "")) < String(b.get("zone_id", ""))
	return left > right

static func _layout_candidate_sort_key(x: int, y: int, seed: Dictionary, water_cells: Array) -> String:
	var dx := x - int(seed.get("x", 0))
	var dy := y - int(seed.get("y", 0))
	var water_penalty := 200000 if _point_lookup(water_cells).has(_point_key(x, y)) else 0
	var score := dx * dx + dy * dy + water_penalty
	return "%09d:%03d:%03d" % [score, y, x]

static func _compare_layout_candidate(a: Dictionary, b: Dictionary) -> bool:
	return String(a.get("sort_key", "")) < String(b.get("sort_key", ""))

static func _zones_by_sorted_ids(zones: Array, zone_ids: Array) -> Array:
	var by_id := {}
	for zone in zones:
		if zone is Dictionary:
			by_id[String(zone.get("id", ""))] = zone
	var result := []
	for zone_id in zone_ids:
		if by_id.has(String(zone_id)):
			result.append(by_id[String(zone_id)])
	return result

static func _seeds_for_layout_level(seeds: Dictionary, width: int, height: int, level_index: int) -> Dictionary:
	if level_index <= 0:
		return seeds.duplicate(true)
	var result := {}
	for zone_id in _sorted_keys(seeds):
		var seed: Dictionary = seeds[zone_id]
		var x := clampi(width - 1 - int(seed.get("x", 0)), 1, max(1, width - 2))
		var y := clampi(height - 1 - int(seed.get("y", 0)), 1, max(1, height - 2))
		result[String(zone_id)] = _point_dict(x, y)
	return _resolve_seed_collisions(result, width, height)

static func _water_cells_for_level(width: int, height: int, water_mode: String, level_index: int) -> Array:
	var cells := []
	if water_mode != "islands" or level_index != 0:
		return cells
	for y in range(height):
		for x in range(width):
			if x == 0 or y == 0 or x == width - 1 or y == height - 1:
				cells.append(_point_dict(x, y))
	return cells

static func _water_policy_payload(water_mode: String, water_cell_count: int) -> Dictionary:
	if water_mode == "islands":
		return {
			"requested": true,
			"mode": "islands",
			"supported_now": true,
			"surface_water_cell_count": water_cell_count,
			"implementation_state": "surface_water_ring_marks_island_boundary_transit_objects_deferred",
		}
	return {
		"requested": false,
		"mode": "land",
		"supported_now": true,
		"surface_water_cell_count": 0,
		"implementation_state": "land_only",
	}

static func _underground_policy_payload(level_count: int, template_support: Dictionary) -> Dictionary:
	var levels: Dictionary = template_support.get("levels", {}) if template_support.get("levels", {}) is Dictionary else {}
	if level_count > 1:
		return {
			"requested": true,
			"supported_now": true,
			"level_count": level_count,
			"surface": true,
			"underground": true,
			"template_level_metadata": levels,
			"implementation_state": "deterministic_second_level_zone_allocation_transit_objects_deferred",
		}
	return {
		"requested": false,
		"supported_now": true,
		"level_count": 1,
		"surface": true,
		"underground": false,
		"template_level_metadata": levels,
		"implementation_state": "surface_only",
	}

static func _corridor_candidates_from_links(links: Array, levels: Array, water_mode: String) -> Array:
	var candidates := []
	var index := 1
	for link in links:
		if not (link is Dictionary):
			continue
		for level in levels:
			if not (level is Dictionary):
				continue
			var anchors: Dictionary = level.get("anchor_points", {})
			var from_zone := String(link.get("from", ""))
			var to_zone := String(link.get("to", ""))
			var from_anchor: Dictionary = anchors.get(from_zone, {})
			var to_anchor: Dictionary = anchors.get(to_zone, {})
			var cells := _straight_corridor_cells(from_anchor, to_anchor)
			var water_lookup := _point_lookup(level.get("water_cells", []))
			var crosses_water := false
			for cell in cells:
				if cell is Dictionary and water_lookup.has(_point_key(int(cell.get("x", 0)), int(cell.get("y", 0)))):
					crosses_water = true
					break
			candidates.append({
				"id": "corridor_%03d_%s_%s_l%d" % [index, from_zone, to_zone, int(level.get("level_index", 0))],
				"from": from_zone,
				"to": to_zone,
				"from_anchor": from_anchor,
				"to_anchor": to_anchor,
				"level_index": int(level.get("level_index", 0)),
				"level_kind": String(level.get("kind", "surface")),
				"mode": "water" if crosses_water else "land",
				"water_policy_mode": water_mode,
				"intended_connection_class": _route_classification(link, true),
				"role": String(link.get("role", "")),
				"guard_value": int(link.get("guard_value", 0)),
				"wide": bool(link.get("wide", false)),
				"border_guard": bool(link.get("border_guard", false)),
				"candidate_cells": cells,
				"candidate_cell_count": cells.size(),
				"materialization_state": "candidate_only_guard_and_transit_materialization_deferred",
			})
			index += 1
	return candidates

static func _straight_corridor_cells(from_anchor: Dictionary, to_anchor: Dictionary) -> Array:
	if from_anchor.is_empty() or to_anchor.is_empty():
		return []
	var cells := []
	var x := int(from_anchor.get("x", 0))
	var y := int(from_anchor.get("y", 0))
	var goal_x := int(to_anchor.get("x", 0))
	var goal_y := int(to_anchor.get("y", 0))
	var step_x := 1 if goal_x >= x else -1
	while x != goal_x:
		cells.append(_point_dict(x, y))
		x += step_x
	var step_y := 1 if goal_y >= y else -1
	while y != goal_y:
		cells.append(_point_dict(x, y))
		y += step_y
	cells.append(_point_dict(goal_x, goal_y))
	return cells

static func _bounds_for_cells(cells: Array) -> Dictionary:
	if cells.is_empty():
		return {}
	var min_x := 999999
	var min_y := 999999
	var max_x := -1
	var max_y := -1
	for cell in cells:
		if not (cell is Dictionary):
			continue
		var x := int(cell.get("x", 0))
		var y := int(cell.get("y", 0))
		min_x = min(min_x, x)
		min_y = min(min_y, y)
		max_x = max(max_x, x)
		max_y = max(max_y, y)
	return {"min_x": min_x, "min_y": min_y, "max_x": max_x, "max_y": max_y}

static func _point_lookup(points: Array) -> Dictionary:
	var result := {}
	for point in points:
		if point is Dictionary:
			result[_point_key(int(point.get("x", 0)), int(point.get("y", 0)))] = true
	return result

static func _adjacent_to_lookup(x: int, y: int, lookup: Dictionary) -> bool:
	for offset in _cardinal_offsets():
		if lookup.has(_point_key(x + int(offset.x), y + int(offset.y))):
			return true
	return false

static func _points_from_lookup(lookup: Dictionary) -> Array:
	var result := []
	for key in _sorted_keys(lookup):
		var parts := String(key).split(",")
		if parts.size() != 2:
			continue
		result.append(_point_dict(int(parts[0]), int(parts[1])))
	return result

static func _zone_layout_phase_summary(zone_layout: Dictionary) -> Dictionary:
	return {
		"schema_id": String(zone_layout.get("schema_id", "")),
		"level_count": int(zone_layout.get("dimensions", {}).get("level_count", 0)),
		"water_mode": String(zone_layout.get("policy", {}).get("water_mode", "")),
		"surface_water_cell_count": int(zone_layout.get("policy", {}).get("water_policy", {}).get("surface_water_cell_count", 0)),
		"corridor_candidate_count": zone_layout.get("corridor_candidates", []).size(),
		"unsupported_runtime_features": zone_layout.get("unsupported_runtime_features", []),
	}

static func _zone_layout_validation(zone_layout: Dictionary, generated_map: Dictionary = {}) -> Dictionary:
	var failures := []
	var warnings := []
	if String(zone_layout.get("schema_id", "")) != ZONE_LAYOUT_SCHEMA_ID:
		failures.append("zone layout schema mismatch")
	var dimensions: Dictionary = zone_layout.get("dimensions", {}) if zone_layout.get("dimensions", {}) is Dictionary else {}
	var width := int(dimensions.get("width", 0))
	var height := int(dimensions.get("height", 0))
	var level_count := int(dimensions.get("level_count", 0))
	var levels: Array = zone_layout.get("levels", [])
	if width <= 0 or height <= 0 or levels.size() != level_count:
		failures.append("zone layout dimensions/level count mismatch")
	var water_mode := String(zone_layout.get("policy", {}).get("water_mode", "land"))
	var total_link_count := int(zone_layout.get("template_link_count", 0))
	if zone_layout.get("corridor_candidates", []).size() < total_link_count * max(1, level_count):
		failures.append("corridor candidates do not cover template links on each generated level")
	for level in levels:
		if not (level is Dictionary):
			failures.append("non-dictionary level layout")
			continue
		var owner_grid: Array = level.get("owner_grid", [])
		if owner_grid.size() != height:
			failures.append("level %d owner grid height mismatch" % int(level.get("level_index", 0)))
		var grid_cells := {}
		for y in range(owner_grid.size()):
			var row: Array = owner_grid[y]
			if row.size() != width:
				failures.append("level %d owner grid row %d width mismatch" % [int(level.get("level_index", 0)), y])
			for x in range(row.size()):
				grid_cells[_point_key(x, y)] = String(row[x])
		if grid_cells.size() != width * height:
			failures.append("level %d owner grid does not cover every cell" % int(level.get("level_index", 0)))
		var footprint_cells := {}
		var footprint_total := 0
		for footprint in level.get("zone_footprints", []):
			if not (footprint is Dictionary):
				failures.append("level %d has non-dictionary footprint" % int(level.get("level_index", 0)))
				continue
			var zone_id := String(footprint.get("zone_id", ""))
			var cells: Array = footprint.get("cells", [])
			footprint_total += cells.size()
			if cells.size() != int(footprint.get("cell_count", 0)):
				failures.append("footprint %s cell_count mismatch" % zone_id)
			var target := int(footprint.get("target_cell_count", 0))
			var tolerance: int = max(2, int(ceil(float(width * height) * 0.03)))
			if abs(cells.size() - target) > tolerance:
				failures.append("footprint %s area %d outside target %d tolerance %d" % [zone_id, cells.size(), target, tolerance])
			for cell in cells:
				if not (cell is Dictionary):
					failures.append("footprint %s has non-dictionary cell" % zone_id)
					continue
				var key := _point_key(int(cell.get("x", -1)), int(cell.get("y", -1)))
				if footprint_cells.has(key):
					failures.append("cell %s assigned to multiple footprints" % key)
				footprint_cells[key] = zone_id
				if String(grid_cells.get(key, "")) != zone_id:
					failures.append("cell %s footprint/grid zone mismatch" % key)
		if footprint_total != width * height:
			failures.append("level %d footprints cover %d cells instead of %d" % [int(level.get("level_index", 0)), footprint_total, width * height])
	if water_mode == "islands" and int(zone_layout.get("policy", {}).get("water_policy", {}).get("surface_water_cell_count", 0)) <= 0:
		failures.append("island water mode requested but no water cells were recorded")
	if water_mode == "land" and int(zone_layout.get("policy", {}).get("water_policy", {}).get("surface_water_cell_count", 0)) != 0:
		failures.append("land water mode unexpectedly recorded water cells")
	var scenario: Dictionary = generated_map.get("scenario_record", {}) if generated_map.get("scenario_record", {}) is Dictionary else {}
	if not scenario.is_empty():
		if bool(scenario.get("selection", {}).get("availability", {}).get("campaign", true)) or bool(scenario.get("selection", {}).get("availability", {}).get("skirmish", true)):
			failures.append("zone layout validation found campaign/skirmish adoption")
		if scenario.has("save_adoption") or scenario.has("alpha_parity_claim"):
			failures.append("zone layout validation found save/parity claim")
	return {
		"ok": failures.is_empty(),
		"status": "pass" if failures.is_empty() else "fail",
		"failure_count": failures.size(),
		"warning_count": warnings.size(),
		"failures": failures,
		"warnings": warnings,
	}

static func _nearest_zone_id(x: int, y: int, zones: Array, seeds: Dictionary) -> String:
	var best_id := String(zones[0].get("id", "")) if not zones.is_empty() and zones[0] is Dictionary else ""
	var best_score := INF
	for zone in zones:
		if not (zone is Dictionary):
			continue
		var zone_id := String(zone.get("id", ""))
		var seed: Dictionary = seeds.get(zone_id, {})
		var dx := float(x - int(seed.get("x", 0)))
		var dy := float(y - int(seed.get("y", 0))) * 1.12
		var weight := sqrt(float(max(1, int(zone.get("base_size", 1)))))
		var score := (dx * dx + dy * dy) / weight
		if score < best_score:
			best_score = score
			best_id = zone_id
	return best_id

static func _update_zone_geometry(zones: Array, zone_grid: Array) -> void:
	var by_id := {}
	for zone in zones:
		if zone is Dictionary:
			zone["bounds"] = {"min_x": 999999, "min_y": 999999, "max_x": -1, "max_y": -1}
			zone["cell_count"] = 0
			by_id[String(zone.get("id", ""))] = zone
	for y in range(zone_grid.size()):
		var row: Array = zone_grid[y]
		for x in range(row.size()):
			var zone_id := String(row[x])
			if not by_id.has(zone_id):
				continue
			var zone: Dictionary = by_id[zone_id]
			var bounds: Dictionary = zone.get("bounds", {})
			bounds["min_x"] = min(int(bounds.get("min_x", x)), x)
			bounds["min_y"] = min(int(bounds.get("min_y", y)), y)
			bounds["max_x"] = max(int(bounds.get("max_x", x)), x)
			bounds["max_y"] = max(int(bounds.get("max_y", y)), y)
			zone["bounds"] = bounds
			zone["cell_count"] = int(zone.get("cell_count", 0)) + 1

static func _zones_for_payload(zones: Array) -> Array:
	var payload := []
	for zone in zones:
		if zone is Dictionary:
			payload.append({
				"id": String(zone.get("id", "")),
				"source_id": String(zone.get("source_id", "")),
				"role": String(zone.get("role", "")),
				"owner_slot": zone.get("owner_slot", null),
				"player_slot": zone.get("player_slot", null),
				"player_type": String(zone.get("player_type", "neutral")),
				"team_id": String(zone.get("team_id", "")),
				"faction_id": String(zone.get("faction_id", "")),
				"terrain_id": String(zone.get("terrain_id", "")),
				"terrain_palette": zone.get("terrain_palette", {}),
				"base_size": int(zone.get("base_size", 0)),
				"bounds": zone.get("bounds", {}),
				"cell_count": int(zone.get("cell_count", 0)),
				"catalog_metadata": zone.get("catalog_metadata", {}),
			})
	return payload

static func _nearest_free_cell(x: int, y: int, preferred_zone_id: Variant, zone_grid: Array, terrain_rows: Array, occupied: Dictionary, rng: DeterministicRng) -> Dictionary:
	var height := zone_grid.size()
	var width: int = zone_grid[0].size() if height > 0 and zone_grid[0] is Array else 0
	x = clampi(x, 0, max(0, width - 1))
	y = clampi(y, 0, max(0, height - 1))
	for radius in range(max(width, height) + 1):
		var candidates := []
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if max(abs(dx), abs(dy)) != radius:
					continue
				var cx := x + dx
				var cy := y + dy
				if cx < 0 or cy < 0 or cx >= width or cy >= height:
					continue
				if occupied.has(_point_key(cx, cy)):
					continue
				if not _terrain_cell_is_passable(terrain_rows, cx, cy):
					continue
				if preferred_zone_id != null and radius < 3 and String(zone_grid[cy][cx]) != String(preferred_zone_id):
					continue
				candidates.append({"x": cx, "y": cy})
		if not candidates.is_empty():
			return candidates[rng.next_index(candidates.size())]
	return {}

static func _object_placement(placement_id: String, kind: String, faction_id: String, zone_id: String, point: Dictionary, extra: Dictionary) -> Dictionary:
	var payload := {
		"placement_id": placement_id,
		"kind": kind,
		"zone_id": zone_id,
		"faction_id": faction_id,
		"x": int(point.get("x", 0)),
		"y": int(point.get("y", 0)),
	}
	for key in _sorted_keys(extra):
		payload[String(key)] = extra[key]
	return payload

static func _placement_counts(placements: Array) -> Dictionary:
	var counts := {}
	for placement in placements:
		if not (placement is Dictionary):
			continue
		var kind := String(placement.get("kind", "unknown"))
		counts[kind] = int(counts.get(kind, 0)) + 1
	return _sorted_dict(counts)

static func _resolve_seed_collisions(seeds: Dictionary, width: int, height: int) -> Dictionary:
	var resolved := {}
	var occupied := {}
	for zone_id in _sorted_keys(seeds):
		var point: Dictionary = seeds[zone_id]
		var x := int(point.get("x", 0))
		var y := int(point.get("y", 0))
		var guard: int = max(1, width * height)
		while occupied.has(_point_key(x, y)) and guard > 0:
			x = clampi(x + 1, 1, max(1, width - 2))
			if occupied.has(_point_key(x, y)):
				y = clampi(y + 1, 1, max(1, height - 2))
			guard -= 1
		occupied[_point_key(x, y)] = true
		resolved[String(zone_id)] = _point_dict(x, y)
	return resolved

static func _zones_with_owner(zones: Array) -> Array:
	var result := []
	for zone in zones:
		if zone is Dictionary and zone.get("player_slot", null) != null:
			result.append(zone)
	result.sort_custom(Callable(RandomMapGeneratorRules, "_compare_owner_slot"))
	return result

static func _zones_without_owner(zones: Array) -> Array:
	var result := []
	for zone in zones:
		if zone is Dictionary and zone.get("player_slot", null) == null:
			result.append(zone)
	result.sort_custom(Callable(RandomMapGeneratorRules, "_compare_zone_id"))
	return result

static func _compare_owner_slot(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("owner_slot", 0)) < int(b.get("owner_slot", 0))

static func _compare_zone_id(a: Dictionary, b: Dictionary) -> bool:
	return String(a.get("id", "")) < String(b.get("id", ""))

static func _phase_record(phase: String, summary: Dictionary) -> Dictionary:
	return {"phase": phase, "summary": _sorted_dict(summary)}

static func _sorted_point_dict(points: Dictionary) -> Dictionary:
	var result := {}
	for key in _sorted_keys(points):
		result[String(key)] = points[key]
	return result

static func _sorted_dict(value: Dictionary) -> Dictionary:
	var result := {}
	for key in _sorted_keys(value):
		result[String(key)] = value[key]
	return result

static func _sorted_keys(value: Dictionary) -> Array:
	var keys := []
	for key in value.keys():
		keys.append(String(key))
	keys.sort()
	return keys

static func _sorted_int_keys(value: Dictionary) -> Array:
	var keys := []
	for key in value.keys():
		keys.append(int(key))
	keys.sort()
	return keys

static func _point_dict(x: int, y: int) -> Dictionary:
	return {"x": x, "y": y}

static func _mark_occupied(occupied: Dictionary, point: Dictionary) -> void:
	occupied[_point_key(int(point.get("x", 0)), int(point.get("y", 0)))] = true

static func _point_key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]

static func _zone_at_point(zone_grid: Array, point: Dictionary) -> String:
	var y := int(point.get("y", 0))
	var x := int(point.get("x", 0))
	if y < 0 or y >= zone_grid.size() or not (zone_grid[y] is Array):
		return ""
	var row: Array = zone_grid[y]
	if x < 0 or x >= row.size():
		return ""
	return String(row[x])

static func _positive_seed(seed_text: String) -> int:
	var hashed := _hash32_int(seed_text)
	return int(hashed % (RNG_MODULUS - 1)) + 1

static func _hash32_hex(text: String) -> String:
	var value := _hash32_int(text)
	var chars := []
	for _index in range(8):
		chars.push_front(HEX_DIGITS[int(value % 16)])
		value = int(value / 16)
	return "".join(chars)

static func _hash32_int(text: String) -> int:
	var value := 2166136261
	for index in range(text.length()):
		value = int((value ^ text.unicode_at(index)) % HASH_MODULUS)
		value = int((value * 16777619) % HASH_MODULUS)
	return value

static func _stable_stringify(value: Variant) -> String:
	if value is Dictionary:
		var parts := []
		for key in _sorted_keys(value):
			parts.append("%s:%s" % [JSON.stringify(String(key)), _stable_stringify(value[key])])
		return "{%s}" % ",".join(parts)
	if value is Array:
		var parts := []
		for item in value:
			parts.append(_stable_stringify(item))
		return "[%s]" % ",".join(parts)
	if value is String:
		return JSON.stringify(value)
	if value is bool:
		return "true" if bool(value) else "false"
	if value == null:
		return "null"
	return JSON.stringify(value)
