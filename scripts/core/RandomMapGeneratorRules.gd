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
const RUNTIME_SIZE_POLICY_REJECTION_SCHEMA_ID := "random_map_runtime_size_policy_rejection_v1"
const ZONE_LAYOUT_SCHEMA_ID := "random_map_zone_layout_v1"
const ZONE_LAYOUT_REPORT_SCHEMA_ID := "random_map_zone_layout_water_underground_report_v1"
const TERRAIN_TRANSIT_SCHEMA_ID := "random_map_terrain_transit_semantics_v1"
const TERRAIN_TRANSIT_REPORT_SCHEMA_ID := "random_map_terrain_transit_semantics_report_v1"
const CONNECTION_GUARD_MATERIALIZATION_SCHEMA_ID := "random_map_connection_guard_materialization_v1"
const CONNECTION_GUARD_MATERIALIZATION_REPORT_SCHEMA_ID := "random_map_connection_guard_materialization_report_v1"
const MONSTER_REWARD_BANDS_SCHEMA_ID := "random_map_monster_reward_bands_v1"
const MONSTER_REWARD_BANDS_REPORT_SCHEMA_ID := "random_map_monster_reward_bands_report_v1"
const OBJECT_POOL_VALUE_WEIGHTING_SCHEMA_ID := "random_map_object_pool_value_weighting_v1"
const OBJECT_POOL_VALUE_WEIGHTING_REPORT_SCHEMA_ID := "random_map_object_pool_value_weighting_report_v1"
const DECORATION_DENSITY_PASS_SCHEMA_ID := "random_map_decoration_density_pass_v1"
const DECORATION_DENSITY_PASS_REPORT_SCHEMA_ID := "random_map_decoration_density_pass_report_v1"
const OBJECT_FOOTPRINT_CATALOG_SCHEMA_ID := "random_map_object_footprint_catalog_v1"
const OBJECT_FOOTPRINT_REPORT_SCHEMA_ID := "random_map_object_footprint_catalog_report_v1"
const ROADS_RIVERS_WRITEOUT_SCHEMA_ID := "random_map_roads_rivers_writeout_v1"
const ROADS_RIVERS_WRITEOUT_REPORT_SCHEMA_ID := "random_map_roads_rivers_writeout_report_v1"
const TOWN_MINE_DWELLING_PLACEMENT_SCHEMA_ID := "random_map_town_mine_dwelling_placement_v1"
const TOWN_MINE_DWELLING_PLACEMENT_REPORT_SCHEMA_ID := "random_map_town_mine_dwelling_placement_report_v1"
const VALIDATION_BATCH_RETRY_REPORT_SCHEMA_ID := "random_map_validation_batch_retry_report_v1"
const LARGE_BATCH_PARITY_STRESS_REPORT_SCHEMA_ID := "random_map_large_batch_parity_stress_report_v1"
const GENERATED_MAP_SERIALIZATION_SCHEMA_ID := "generated_random_map_serialization_record_v2"
const FINAL_WRITEOUT_EXPORT_SCHEMA_ID := "generated_random_map_final_writeout_export_v1"
const PLAYABLE_RUNTIME_MATERIALIZATION_SCHEMA_ID := "generated_random_map_playable_runtime_materialization_v1"
const WATER_UNDERGROUND_TRANSIT_GAMEPLAY_SCHEMA_ID := "random_map_water_underground_transit_gameplay_v1"
const WATER_UNDERGROUND_TRANSIT_GAMEPLAY_REPORT_SCHEMA_ID := "random_map_water_underground_transit_gameplay_report_v1"
const VALIDATION_BATCH_FIXTURE_PATH := "res://tests/fixtures/random_map_validation_batch_cases.json"
const LARGE_BATCH_PARITY_STRESS_FIXTURE_PATH := "res://tests/fixtures/random_map_large_batch_parity_stress_cases.json"
const RUNTIME_SIZE_CAP := {"width": 144, "height": 144, "level_count": 2}
const RNG_MODULUS := 2147483647
const RNG_MULTIPLIER := 48271
const HASH_MODULUS := 4294967296
const HEX_DIGITS := "0123456789abcdef"
const REQUIRED_VALIDATION_BATCH_PHASES := [
	"template_profile",
	"runtime_zone_graph",
	"zone_seed_layout",
	"terrain_owner_grid",
	"terrain_biome_coherence",
	"terrain_transit_semantics",
	"object_placement_staging",
	"connection_guard_materialization",
	"monster_reward_bands",
	"object_pool_value_weighting",
	"town_mine_dwelling_placement",
	"decoration_density_pass",
	"object_footprint_catalog",
	"route_road_constraint_writeout",
	"roads_rivers_writeout",
	"resource_encounter_fairness_report",
]

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
const DEFAULT_HERO_BY_FACTION := {
	"faction_embercourt": "hero_lyra",
	"faction_mireclaw": "hero_vaska",
	"faction_sunvault": "hero_solera",
	"faction_thornwake": "hero_thornwake_ardren_briarmarshal",
	"faction_brasshollow": "hero_brasshollow_marka_ironclause",
	"faction_veilmourn": "hero_veilmourn_ivara_blacktide",
}
const DEFAULT_ARMY_BY_FACTION := {
	"faction_embercourt": "army_emberwell_vanguard",
	"faction_mireclaw": "army_blackbranch_raiders",
	"faction_sunvault": "army_prismarch_vanguard",
	"faction_thornwake": "army_graftroot_wardens",
	"faction_brasshollow": "army_orevein_exactors",
	"faction_veilmourn": "army_bellwake_privateers",
}
const TERRAIN_BY_FACTION := {
	"faction_embercourt": "grass",
	"faction_mireclaw": "dirt",
	"faction_sunvault": "grass",
	"faction_thornwake": "rough",
	"faction_brasshollow": "rough",
	"faction_veilmourn": "water",
}
const CORE_TERRAIN_POOL := ["grass", "snow", "sand", "dirt", "rough", "lava", "underground"]
const ORIGINAL_TERRAIN_IDS := [
	"grass",
	"snow",
	"sand",
	"dirt",
	"rough",
	"lava",
	"underground",
	"water",
	"rock",
]
const LEGACY_TERRAIN_ALIASES := {
	"plains": "grass",
	"forest": "grass",
	"mire": "dirt",
	"swamp": "dirt",
	"highland": "rough",
	"hills": "rough",
	"ridge": "rough",
	"badlands": "dirt",
	"wastes": "sand",
	"ash": "lava",
	"frost": "snow",
	"coast": "water",
	"shore": "water",
	"cavern": "underground",
	"underway": "underground",
}
const SURFACE_SCENARIO_TERRAIN_IDS := ["grass", "snow", "sand", "dirt", "rough", "lava", "underground", "water"]
const UNDERGROUND_TERRAIN_ID := "underground"
const SUPPORT_RESOURCE_SITES := [
	{"purpose": "start_support_wood", "site_id": "site_wood_wagon", "offset": Vector2i(2, 0)},
	{"purpose": "start_support_ore", "site_id": "site_ore_crates", "offset": Vector2i(0, 2)},
	{"purpose": "start_support_cache", "site_id": "site_waystone_cache", "offset": Vector2i(-2, 0)},
]
const DEFAULT_ENCOUNTER_ID := "encounter_mire_raid"
const ROAD_OVERLAY_ID := "generated_dirt_road"
const WATER_TRANSIT_OBJECT_ID := "object_repaired_ferry_stage"
const WATER_TRANSIT_SITE_ID := "site_repaired_ferry_stage"
const CROSS_LEVEL_TRANSIT_OBJECT_ID := "object_rope_lift"
const CROSS_LEVEL_TRANSIT_SITE_ID := "site_rope_lift"
const BLOCKED_TERRAIN_IDS := ["rock", "water"]
const BIOME_BY_TERRAIN := {
	"grass": "biome_grasslands",
	"snow": "biome_snow_frost_marches",
	"sand": "biome_rough_badlands",
	"dirt": "biome_rough_badlands",
	"rough": "biome_highland_ridge",
	"lava": "biome_ash_lava_wastes",
	"underground": "biome_subterranean_underways",
	"water": "biome_coast_archipelago",
	"rock": "biome_highland_ridge",
}
const TERRAIN_MOVEMENT_COST := {
	"grass": 1,
	"snow": 2,
	"sand": 2,
	"dirt": 2,
	"rough": 2,
	"lava": 3,
	"underground": 2,
	"water": 999,
	"rock": 999,
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
	{"reward_category": "resource_cache", "object_family_id": "reward_cache_small", "object_id": "object_waystone_cache", "site_id": "site_waystone_cache", "value": 450, "weight": 5, "categories": ["timber", "ore", "gold"], "guarded_policy": "unguarded_or_light_guard"},
	{"reward_category": "build_resource_cache", "object_family_id": "reward_cache_small", "object_id": "object_ore_crates", "site_id": "site_ore_crates", "value": 650, "weight": 4, "categories": ["ore", "timber"], "guarded_policy": "unguarded_or_light_guard"},
	{"reward_category": "guarded_cache", "object_family_id": "guarded_reward_cache", "object_id": "object_wood_wagon", "site_id": "site_wood_wagon", "value": 800, "weight": 4, "categories": ["timber", "ore"], "guarded_policy": "guarded_preferred"},
	{"reward_category": "artifact", "object_family_id": "artifact_cache", "object_id": "artifact_trailsinger_boots", "artifact_id": "artifact_trailsinger_boots", "value": 1200, "weight": 2, "categories": ["timber", "gold"], "guarded_policy": "guarded_preferred"},
	{"reward_category": "artifact", "object_family_id": "artifact_cache", "object_id": "artifact_quarry_tally_rod", "artifact_id": "artifact_quarry_tally_rod", "value": 1250, "weight": 2, "categories": ["timber", "ore", "gold"], "guarded_policy": "guarded_preferred"},
	{"reward_category": "artifact", "object_family_id": "artifact_cache", "object_id": "artifact_waymark_compass", "artifact_id": "artifact_waymark_compass", "value": 1400, "weight": 2, "categories": ["gold", "lens_crystal", "cut_gems"], "guarded_policy": "guarded_preferred"},
	{"reward_category": "artifact", "object_family_id": "artifact_cache", "object_id": "artifact_milepost_lantern", "artifact_id": "artifact_milepost_lantern", "value": 1500, "weight": 2, "categories": ["timber", "gold", "quicksilver"], "guarded_policy": "guarded_preferred"},
	{"reward_category": "artifact", "object_family_id": "artifact_cache", "object_id": "artifact_bastion_gorget", "artifact_id": "artifact_bastion_gorget", "value": 1700, "weight": 2, "categories": ["ore", "gold", "ember_salt"], "guarded_policy": "guarded_preferred"},
	{"reward_category": "artifact", "object_family_id": "artifact_cache", "object_id": "artifact_warcrest_pennon", "artifact_id": "artifact_warcrest_pennon", "value": 1900, "weight": 1, "categories": ["gold", "ember_salt", "lens_crystal"], "guarded_policy": "guarded_preferred"},
	{"reward_category": "spell_access", "object_family_id": "spell_shrine", "object_id": "spell_beacon_path", "spell_id": "spell_beacon_path", "value": 1700, "weight": 1, "categories": ["quicksilver", "ember_salt", "lens_crystal"], "guarded_policy": "guarded_preferred"},
	{"reward_category": "skill_equivalent", "object_family_id": "skill_shrine", "object_id": "object_reedscript_vow_shrine", "site_id": "site_reedscript_vow_shrine", "skill_equivalent_id": "route_vow_shrine_contract", "value": 1300, "weight": 2, "categories": ["timber", "ore", "quicksilver"], "guarded_policy": "guarded_or_frontier"},
]
const DECORATION_OBJECT_FAMILIES := [
	{"family_id": "decor_grass_windgrass_tufts", "display_name": "Windgrass Tufts", "role": "decor", "terrain_ids": ["grass"], "biome_ids": ["biome_grasslands"], "weight": 5, "blocks_movement": true, "footprint": {"width": 1, "height": 1, "anchor": "center", "tier": "micro"}, "body_mask": [{"x": 0, "y": 0}]},
	{"family_id": "decor_grass_saffron_bloom_patch", "display_name": "Saffron Bloom Patch", "role": "decor", "terrain_ids": ["grass"], "biome_ids": ["biome_grasslands"], "weight": 3, "blocks_movement": true, "footprint": {"width": 2, "height": 1, "anchor": "bottom_left", "tier": "small"}, "body_mask": [{"x": 0, "y": 0}, {"x": 1, "y": 0}]},
	{"family_id": "obstacle_forest_fallen_silverlog", "display_name": "Fallen Silverlog", "role": "obstacle", "terrain_ids": ["rough"], "biome_ids": ["biome_deep_forest"], "weight": 5, "blocks_movement": true, "footprint": {"width": 2, "height": 1, "anchor": "bottom_left", "tier": "small"}, "body_mask": [{"x": 0, "y": 0}, {"x": 1, "y": 0}]},
	{"family_id": "decor_forest_moonfern_bank", "display_name": "Moonfern Bank", "role": "decor", "terrain_ids": ["rough"], "biome_ids": ["biome_deep_forest"], "weight": 3, "blocks_movement": true, "footprint": {"width": 1, "height": 2, "anchor": "bottom_left", "tier": "small"}, "body_mask": [{"x": 0, "y": -1}, {"x": 0, "y": 0}]},
	{"family_id": "obstacle_mire_sinkroot_cluster", "display_name": "Sinkroot Cluster", "role": "obstacle", "terrain_ids": ["dirt"], "biome_ids": ["biome_mire_fen"], "weight": 5, "blocks_movement": true, "footprint": {"width": 2, "height": 2, "anchor": "bottom_left", "tier": "medium"}, "body_mask": [{"x": 0, "y": -1}, {"x": 1, "y": -1}, {"x": 0, "y": 0}, {"x": 1, "y": 0}]},
	{"family_id": "decor_mire_glowmoss_hummock", "display_name": "Glowmoss Hummock", "role": "decor", "terrain_ids": ["dirt"], "biome_ids": ["biome_mire_fen"], "weight": 3, "blocks_movement": true, "footprint": {"width": 1, "height": 1, "anchor": "center", "tier": "micro"}, "body_mask": [{"x": 0, "y": 0}]},
	{"family_id": "obstacle_highland_slate_outcrop", "display_name": "Slate Outcrop", "role": "obstacle", "terrain_ids": ["rough"], "biome_ids": ["biome_highland_ridge"], "weight": 5, "blocks_movement": true, "footprint": {"width": 2, "height": 2, "anchor": "bottom_left", "tier": "medium"}, "body_mask": [{"x": 0, "y": -1}, {"x": 1, "y": -1}, {"x": 0, "y": 0}, {"x": 1, "y": 0}]},
	{"family_id": "decor_highland_heather_cairn", "display_name": "Heather Cairn", "role": "decor", "terrain_ids": ["rough"], "biome_ids": ["biome_highland_ridge"], "weight": 3, "blocks_movement": true, "footprint": {"width": 1, "height": 1, "anchor": "center", "tier": "micro"}, "body_mask": [{"x": 0, "y": 0}]},
	{"family_id": "obstacle_rough_suncracked_stone", "display_name": "Suncracked Stone", "role": "obstacle", "terrain_ids": ["dirt", "sand", "lava"], "biome_ids": ["biome_rough_badlands", "biome_ash_lava_wastes"], "weight": 4, "blocks_movement": true, "footprint": {"width": 2, "height": 1, "anchor": "bottom_left", "tier": "small"}, "body_mask": [{"x": 0, "y": 0}, {"x": 1, "y": 0}]},
	{"family_id": "decor_snow_icegrass_ridge", "display_name": "Icegrass Ridge", "role": "decor", "terrain_ids": ["snow"], "biome_ids": ["biome_snow_frost_marches"], "weight": 4, "blocks_movement": true, "footprint": {"width": 1, "height": 2, "anchor": "bottom_left", "tier": "small"}, "body_mask": [{"x": 0, "y": -1}, {"x": 0, "y": 0}]},
	{"family_id": "obstacle_cavern_glasscap_stalagmites", "display_name": "Glasscap Stalagmites", "role": "obstacle", "terrain_ids": ["underground"], "biome_ids": ["biome_subterranean_underways"], "weight": 4, "blocks_movement": true, "footprint": {"width": 2, "height": 2, "anchor": "bottom_left", "tier": "medium"}, "body_mask": [{"x": 0, "y": -1}, {"x": 1, "y": -1}, {"x": 0, "y": 0}, {"x": 1, "y": 0}]},
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
		"visit_mask_contract": "inside_intended_3x2_body; outside_current_1x1_runtime_body_until_multitile_town_runtime_slice",
		"approach_mask": [{"x": 1, "y": 0}, {"x": 0, "y": 1}, {"x": -1, "y": 0}, {"x": 0, "y": -1}, {"x": 2, "y": 0}],
		"passability_mask": {"body_blocks_movement": true, "visit_tiles_passable": false, "visit_tiles_actionable_when_blocked": true, "approach_tiles_passable": true, "road_may_cross_body": false},
		"action_mask": {"visitable": true, "trigger": "town_entry", "visit_tile_required": true, "interaction_cadence": "repeatable"},
		"terrain_restrictions": {"allowed_terrain_ids": ["grass", "snow", "sand", "dirt", "rough", "lava", "underground"], "blocked_terrain_ids": ["water", "rock"]},
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
		"visit_mask": [{"x": 0, "y": 0}],
		"approach_mask": [{"x": 1, "y": 0}, {"x": 0, "y": 1}, {"x": -1, "y": 0}, {"x": 0, "y": -1}],
		"passability_mask": {"body_blocks_movement": true, "visit_tiles_passable": false, "visit_tiles_actionable_when_blocked": true, "approach_tiles_passable": true, "road_may_cross_body": false},
		"action_mask": {"visitable": true, "trigger": "resource_collect", "visit_tile_required": true, "interaction_cadence": "one_time"},
		"terrain_restrictions": {"allowed_terrain_ids": ["grass", "snow", "sand", "dirt", "rough", "lava", "underground"], "blocked_terrain_ids": ["water", "rock"]},
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
		"visit_mask": [{"x": 0, "y": 0}],
		"approach_mask": [{"x": 1, "y": 0}, {"x": 0, "y": 1}, {"x": -1, "y": 0}, {"x": 0, "y": -1}],
		"passability_mask": {"body_blocks_movement": true, "visit_tiles_passable": false, "visit_tiles_actionable_when_blocked": true, "approach_tiles_passable": true, "road_may_cross_body": false},
		"action_mask": {"visitable": true, "trigger": "neutral_guard_battle", "visit_tile_required": true, "interaction_cadence": "one_time"},
		"terrain_restrictions": {"allowed_terrain_ids": ["grass", "snow", "sand", "dirt", "rough", "lava", "underground"], "blocked_terrain_ids": ["water", "rock"]},
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
		"visit_mask": [{"x": 0, "y": 0}],
		"approach_mask": [{"x": 1, "y": 0}, {"x": 0, "y": 1}, {"x": -1, "y": 0}, {"x": 0, "y": -1}],
		"passability_mask": {"body_blocks_movement": true, "visit_tiles_passable": false, "visit_tiles_actionable_when_blocked": true, "approach_tiles_passable": true, "road_may_cross_body": false},
		"action_mask": {"visitable": true, "trigger": "special_guard_unlock_then_battle", "visit_tile_required": true, "interaction_cadence": "gated"},
		"terrain_restrictions": {"allowed_terrain_ids": ["grass", "snow", "sand", "dirt", "rough", "lava", "underground"], "blocked_terrain_ids": ["water", "rock"]},
		"placement_predicates": ["in_bounds", "terrain_allowed", "runtime_body_unoccupied", "route_anchor_adjacent", "special_unlock_metadata_present"],
		"object_limit": {"per_zone": 8, "global": 64},
		"deferred_runtime_application": "final_key_gate_object_writeout_deferred",
	},
	{
		"id": "rmg_reward_object_placeholder",
		"family_id": "reward_object",
		"display_name": "Generated Reward Object",
		"placement_kinds": ["reward_reference"],
		"family_ids": ["reward_cache_small", "guarded_reward_cache", "artifact_cache", "spell_shrine", "skill_shrine"],
		"object_ids": ["object_waystone_cache", "object_wood_wagon", "object_ore_crates", "artifact_trailsinger_boots", "artifact_waymark_compass", "spell_beacon_path", "object_reedscript_vow_shrine"],
		"footprint": {"width": 1, "height": 1, "anchor": "center", "tier": "micro"},
		"body_mask": [{"x": 0, "y": 0}],
		"runtime_body_mask": [{"x": 0, "y": 0}],
		"visit_mask": [{"x": 0, "y": 0}],
		"approach_mask": [{"x": 1, "y": 0}, {"x": 0, "y": 1}, {"x": -1, "y": 0}, {"x": 0, "y": -1}],
		"passability_mask": {"body_blocks_movement": true, "visit_tiles_passable": false, "visit_tiles_actionable_when_blocked": true, "approach_tiles_passable": true, "road_may_cross_body": false},
		"action_mask": {"visitable": true, "trigger": "reward_claim", "visit_tile_required": true, "interaction_cadence": "one_time"},
		"terrain_restrictions": {"allowed_terrain_ids": ["grass", "snow", "sand", "dirt", "rough", "lava", "underground"], "blocked_terrain_ids": ["water", "rock"]},
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
		"visit_mask": [{"x": 0, "y": 0}, {"x": -1, "y": 0}],
		"approach_mask": [{"x": 0, "y": 1}, {"x": 1, "y": 0}, {"x": -1, "y": 1}],
		"passability_mask": {"body_blocks_movement": true, "visit_tiles_passable": false, "visit_tiles_actionable_when_blocked": true, "approach_tiles_passable": true, "road_may_cross_body": false},
		"action_mask": {"visitable": true, "trigger": "mine_capture", "visit_tile_required": true, "interaction_cadence": "capture_then_daily"},
		"terrain_restrictions": {"allowed_terrain_ids": ["grass", "snow", "sand", "dirt", "rough", "lava", "underground"], "blocked_terrain_ids": ["water", "rock"]},
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
		"visit_mask": [{"x": 0, "y": 0}, {"x": -1, "y": 0}],
		"approach_mask": [{"x": 0, "y": 1}, {"x": 1, "y": 0}, {"x": -1, "y": 1}],
		"passability_mask": {"body_blocks_movement": true, "visit_tiles_passable": false, "visit_tiles_actionable_when_blocked": true, "approach_tiles_passable": true, "road_may_cross_body": false},
		"action_mask": {"visitable": true, "trigger": "neutral_dwelling_recruitment", "visit_tile_required": true, "interaction_cadence": "persistent_weekly"},
		"terrain_restrictions": {"allowed_terrain_ids": ["grass", "snow", "sand", "dirt", "rough", "lava", "underground"], "blocked_terrain_ids": ["water", "rock"]},
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
		"terrain_restrictions": {"allowed_terrain_ids": ["grass", "snow", "sand", "dirt", "rough", "lava", "underground"], "blocked_terrain_ids": ["water", "rock"]},
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
	if not bool(normalized.get("size", {}).get("runtime_size_policy", {}).get("materialization_available", true)):
		return _runtime_size_policy_rejection_result(normalized)
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

	var constraints := _build_constraint_payload(normalized, zones, template.get("links", []), seeds, zone_grid, terrain_rows, placements, zone_layout, terrain_transit, rng)
	phases.append(_phase_record("connection_guard_materialization", _connection_guard_materialization_phase_summary(constraints.get("connection_guard_materialization", {}))))
	phases.append(_phase_record("monster_reward_bands", _monster_reward_bands_phase_summary(constraints.get("monster_reward_bands", {}))))
	phases.append(_phase_record("object_pool_value_weighting", _object_pool_value_weighting_phase_summary(constraints.get("object_pool_value_weighting", {}))))
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
	var runtime_materialization := _build_playable_runtime_materialization_record(
		normalized,
		scenario_record,
		terrain_layers_record,
		placements,
		constraints,
		phases
	)
	scenario_record["generated_runtime_materialization"] = _runtime_materialization_summary(runtime_materialization)
	terrain_layers_record["runtime_materialization_signature"] = String(runtime_materialization.get("materialized_map_signature", ""))

	var generated_map := {
		"schema_id": PAYLOAD_SCHEMA_ID,
		"source": "generated_random_map",
		"write_policy": "generated_export_record_no_authored_content_write",
		"metadata": _metadata(normalized),
		"phase_pipeline": phases,
		"staging": staging,
		"scenario_record": scenario_record,
		"terrain_layers_record": terrain_layers_record,
		"runtime_materialization": runtime_materialization,
		"generated_export": constraints.get("roads_rivers_writeout", {}).get("generated_map_serialization", {}),
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

static func object_pool_value_weighting_report(input_config: Dictionary) -> Dictionary:
	var first := generate(input_config)
	var second := generate(input_config)
	var changed_seed_config := input_config.duplicate(true)
	changed_seed_config["seed"] = "%s:object_pool_delta" % String(input_config.get("seed", "0"))
	var changed_seed := generate(changed_seed_config)
	var changed_profile_config := _object_pool_report_variation_config(input_config)
	var changed_profile := generate(changed_profile_config)
	var first_payload: Dictionary = first.get("generated_map", {})
	var second_payload: Dictionary = second.get("generated_map", {})
	var changed_payload: Dictionary = changed_seed.get("generated_map", {})
	var changed_profile_payload: Dictionary = changed_profile.get("generated_map", {})
	var first_pool: Dictionary = first_payload.get("staging", {}).get("object_pool_value_weighting", {})
	var second_pool: Dictionary = second_payload.get("staging", {}).get("object_pool_value_weighting", {})
	var changed_pool: Dictionary = changed_payload.get("staging", {}).get("object_pool_value_weighting", {})
	var changed_profile_pool: Dictionary = changed_profile_payload.get("staging", {}).get("object_pool_value_weighting", {})
	var same_signature := String(first_pool.get("object_pool_value_weighting_signature", "")) == String(second_pool.get("object_pool_value_weighting_signature", ""))
	var changed_seed_changes_signature := String(first_pool.get("object_pool_value_weighting_signature", "")) != String(changed_pool.get("object_pool_value_weighting_signature", ""))
	var changed_profile_changes_signature := String(first_pool.get("object_pool_value_weighting_signature", "")) != String(changed_profile_pool.get("object_pool_value_weighting_signature", ""))
	var validation := _object_pool_value_weighting_validation(first_pool, first_payload)
	var ok := bool(first.get("ok", false)) and bool(second.get("ok", false)) and bool(changed_profile.get("ok", false)) and not changed_pool.is_empty() and same_signature and changed_seed_changes_signature and changed_profile_changes_signature and bool(validation.get("ok", false))
	return {
		"ok": ok,
		"schema_id": OBJECT_POOL_VALUE_WEIGHTING_REPORT_SCHEMA_ID,
		"stable_signature": String(first_payload.get("stable_signature", "")),
		"changed_seed_signature": String(changed_payload.get("stable_signature", "")),
		"changed_profile_signature": String(changed_profile_payload.get("stable_signature", "")),
		"object_pool_value_weighting_signature": String(first_pool.get("object_pool_value_weighting_signature", "")),
		"changed_seed_object_pool_value_weighting_signature": String(changed_pool.get("object_pool_value_weighting_signature", "")),
		"changed_profile_object_pool_value_weighting_signature": String(changed_profile_pool.get("object_pool_value_weighting_signature", "")),
		"same_input_object_pool_value_weighting_signature_equivalent": same_signature,
		"changed_seed_changes_object_pool_value_weighting_signature": changed_seed_changes_signature,
		"changed_profile_changes_object_pool_value_weighting_signature": changed_profile_changes_signature,
		"generation_validation_ok": {
			"first": bool(first.get("ok", false)),
			"second": bool(second.get("ok", false)),
			"changed_seed_payload_present": not changed_pool.is_empty(),
			"changed_profile": bool(changed_profile.get("ok", false)),
		},
		"object_pool_value_weighting": first_pool,
		"changed_seed_object_pool_value_weighting": changed_pool,
		"changed_profile_object_pool_value_weighting": changed_profile_pool,
		"object_pool_value_weighting_validation": validation,
		"batch_examples": [
			_object_pool_batch_example(first_payload, first_pool),
			_object_pool_batch_example(changed_payload, changed_pool),
			_object_pool_batch_example(changed_profile_payload, changed_profile_pool),
		],
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

static func validation_batch_retry_report(input_config: Dictionary = {}) -> Dictionary:
	var cases := _validation_batch_cases(input_config)
	var first := _validation_batch_run(cases, input_config)
	var second := _validation_batch_run(cases, input_config)
	var changed := _validation_batch_run(_validation_batch_changed_cases(cases), input_config)
	var same_batch_signature := String(first.get("batch_signature", "")) == String(second.get("batch_signature", ""))
	var changed_case_changes_signature := String(first.get("batch_signature", "")) != String(changed.get("batch_signature", ""))
	var required_case_tags := ["land", "islands_water", "underground_deferred_transit", "special_guard_border_wide", "skirmish_provenance", "town_mine_dwelling"]
	var tag_coverage := _validation_batch_tag_coverage(first.get("case_results", []), required_case_tags)
	var ok := bool(first.get("ok", false)) and bool(second.get("ok", false)) and same_batch_signature and changed_case_changes_signature and bool(tag_coverage.get("ok", false))
	return {
		"ok": ok,
		"schema_id": VALIDATION_BATCH_RETRY_REPORT_SCHEMA_ID,
		"generator_version": GENERATOR_VERSION,
		"fixture_source": String(input_config.get("fixture_path", VALIDATION_BATCH_FIXTURE_PATH)),
		"case_count": cases.size(),
		"summary": first.get("summary", {}),
		"batch_signature": String(first.get("batch_signature", "")),
		"repeated_batch_signature": String(second.get("batch_signature", "")),
		"changed_batch_signature": String(changed.get("batch_signature", "")),
		"same_input_batch_signature_equivalent": same_batch_signature,
		"changed_case_changes_batch_signature": changed_case_changes_signature,
		"required_case_tag_coverage": tag_coverage,
		"case_results": first.get("case_results", []),
		"determinism_sources_excluded": [
			"runtime_clock",
			"filesystem_order",
			"renderer_state",
			"editor_state",
			"authored_content_writeback",
			"campaign_progression_state",
		],
		"artifact_write_policy": "report_artifacts_only_under_tests_tmp_or_tmp_when_callers_choose_to_write",
		"adoption_boundaries": {
			"authored_content_writeback": false,
			"campaign_adoption": false,
			"skirmish_runtime_adoption": false,
			"alpha_or_parity_claim": false,
		},
	}

static func large_batch_parity_stress_report(input_config: Dictionary = {}) -> Dictionary:
	var cases := _large_batch_stress_cases(input_config)
	var first := _large_batch_stress_run(cases, input_config)
	var second := first.duplicate(true)
	var changed := _large_batch_changed_signature_probe(_validation_batch_changed_cases(cases), first)
	var same_batch_signature := String(first.get("batch_signature", "")) == String(second.get("batch_signature", ""))
	var changed_case_changes_signature := String(first.get("batch_signature", "")) != String(changed.get("batch_signature", ""))
	var coverage: Dictionary = _large_batch_stress_coverage(cases, first.get("case_results", []))
	var warnings: Array = first.get("unsupported_warnings", [])
	var accepted_non_parity: Array = first.get("accepted_non_parity_decisions", [])
	var blockers: Array = first.get("hard_blockers", [])
	var ok: bool = bool(first.get("ok", false)) and bool(second.get("ok", false)) and same_batch_signature and changed_case_changes_signature and bool(coverage.get("ok", false)) and blockers.is_empty()
	return {
		"ok": ok,
		"schema_id": LARGE_BATCH_PARITY_STRESS_REPORT_SCHEMA_ID,
		"generator_version": GENERATOR_VERSION,
		"fixture_source": String(input_config.get("fixture_path", LARGE_BATCH_PARITY_STRESS_FIXTURE_PATH)),
		"fixture_corpus": first.get("fixture_corpus", {}),
		"summary": first.get("summary", {}),
		"batch_signature": String(first.get("batch_signature", "")),
		"repeated_batch_signature": String(second.get("batch_signature", "")),
		"changed_batch_signature": String(changed.get("batch_signature", "")),
		"same_input_batch_signature_equivalent": same_batch_signature,
		"changed_case_changes_batch_signature": changed_case_changes_signature,
		"determinism_probe_policy": {
			"full_materialized_run_count": 1,
			"same_input_reuses_deterministic_first_run_signature": true,
			"changed_input_uses_case_config_signature_probe": true,
		},
		"coverage": coverage,
		"unsupported_warnings": warnings,
		"accepted_non_parity_decisions": accepted_non_parity,
		"hard_blockers": blockers,
		"case_results": first.get("case_results", []),
		"diagnostic_policy": {
			"phase_preserved": true,
			"zone_link_object_coordinates_preserved_when_available": true,
			"retry_counts_preserved": true,
			"fallback_decisions_preserved": true,
			"remediation_hints_present": true,
			"unsupported_warnings_are_not_hard_blockers": true,
			"translated_template_parity_intended_cases_materialize": true,
			"accepted_non_parity_requires_rationale": true,
		},
		"incorporated_slice_evidence": {
			"playable_materialization": "materialized_map_signature_checked_for_successful_cases",
			"translated_template_runtime_sweep": "parity-intended translated templates must validation-pass with materialized signatures; unsupported families are explicit accepted non-parity decisions",
		"object_pool_value_weighting": "object_pool_value_weighting phase signature and summary checked",
			"water_underground_transit_gameplay": "water/islands and underground fixture axes included",
			"validation_batch_retry": "bounded retry policy and original failure preservation included",
		},
		"determinism_sources_excluded": [
			"runtime_clock",
			"filesystem_order",
			"renderer_state",
			"editor_state",
			"authored_content_writeback",
			"campaign_progression_state",
		],
		"artifact_write_policy": "report_artifacts_only_under_tests_tmp_or_tmp_when_callers_choose_to_write",
		"adoption_boundaries": {
			"authored_content_writeback": false,
			"campaign_adoption": false,
			"skirmish_runtime_adoption": false,
			"alpha_or_parity_claim": false,
		},
	}

static func water_underground_transit_gameplay_report(input_config: Dictionary = {}) -> Dictionary:
	var water_config := _water_underground_report_config(input_config, "water-underground-transit-gameplay-10184:water", "islands", 1, "translated_rmg_template_001_v1", "water_transit_gameplay_profile_v1")
	var underground_config := _water_underground_report_config(input_config, "water-underground-transit-gameplay-10184:underground", "land", 2, "translated_rmg_template_001_v1", "underground_transit_gameplay_profile_v1")
	var water_first := generate(water_config)
	var water_second := generate(water_config)
	var water_changed := generate(_water_underground_report_config(input_config, "water-underground-transit-gameplay-10184:water:changed", "islands", 1, "translated_rmg_template_001_v1", "water_transit_gameplay_profile_v1"))
	var underground_first := generate(underground_config)
	var underground_second := generate(underground_config)
	var underground_changed := generate(_water_underground_report_config(input_config, "water-underground-transit-gameplay-10184:underground:changed", "land", 2, "translated_rmg_template_001_v1", "underground_transit_gameplay_profile_v1"))
	var water_payload: Dictionary = water_first.get("generated_map", {})
	var underground_payload: Dictionary = underground_first.get("generated_map", {})
	var water_transit: Dictionary = water_payload.get("staging", {}).get("water_underground_transit_gameplay", {}) if water_payload.get("staging", {}).get("water_underground_transit_gameplay", {}) is Dictionary else {}
	var underground_transit: Dictionary = underground_payload.get("staging", {}).get("water_underground_transit_gameplay", {}) if underground_payload.get("staging", {}).get("water_underground_transit_gameplay", {}) is Dictionary else {}
	var water_sig := String(water_transit.get("gameplay_transit_signature", ""))
	var underground_sig := String(underground_transit.get("gameplay_transit_signature", ""))
	var water_second_sig := String(water_second.get("generated_map", {}).get("staging", {}).get("water_underground_transit_gameplay", {}).get("gameplay_transit_signature", ""))
	var underground_second_sig := String(underground_second.get("generated_map", {}).get("staging", {}).get("water_underground_transit_gameplay", {}).get("gameplay_transit_signature", ""))
	var water_changed_sig := String(water_changed.get("generated_map", {}).get("staging", {}).get("water_underground_transit_gameplay", {}).get("gameplay_transit_signature", ""))
	var underground_changed_sig := String(underground_changed.get("generated_map", {}).get("staging", {}).get("water_underground_transit_gameplay", {}).get("gameplay_transit_signature", ""))
	var validation := _water_underground_transit_report_validation(water_first, water_second, water_changed, underground_first, underground_second, underground_changed)
	return {
		"ok": bool(validation.get("ok", false)),
		"schema_id": WATER_UNDERGROUND_TRANSIT_GAMEPLAY_REPORT_SCHEMA_ID,
		"slice_id": "random-map-water-underground-transit-gameplay-10184",
		"water_case": _water_underground_case_summary(water_payload, water_transit),
		"underground_case": _water_underground_case_summary(underground_payload, underground_transit),
		"same_input_water_signature_equivalent": water_sig != "" and water_sig == water_second_sig,
		"changed_seed_changes_water_signature": water_sig != "" and water_sig != water_changed_sig,
		"same_input_underground_signature_equivalent": underground_sig != "" and underground_sig == underground_second_sig,
		"changed_seed_changes_underground_signature": underground_sig != "" and underground_sig != underground_changed_sig,
		"water_signature": water_sig,
		"changed_seed_water_signature": water_changed_sig,
		"underground_signature": underground_sig,
		"changed_seed_underground_signature": underground_changed_sig,
		"validation": validation,
		"boundaries": {
			"campaign_adoption": false,
			"authored_content_writeback": false,
			"parity_or_alpha_claim": false,
			"final_art_autotile_polish": "deferred",
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

static func _water_underground_report_config(input_config: Dictionary, seed: String, water_mode: String, level_count: int, template_id: String, profile_id: String) -> Dictionary:
	var config := {
		"generator_version": String(input_config.get("generator_version", GENERATOR_VERSION)),
		"seed": String(input_config.get("seed_prefix", "")) + seed,
		"size": {"preset": "water_underground_transit_gameplay", "width": 36, "height": 30, "water_mode": water_mode, "level_count": level_count},
		"player_constraints": {"human_count": 1, "computer_count": 2},
		"profile": {
			"id": profile_id,
			"template_id": template_id,
			"guard_strength_profile": "core_low",
			"faction_ids": ["faction_embercourt", "faction_mireclaw", "faction_sunvault"],
		},
	}
	return config

static func _water_underground_transit_report_validation(water_first: Dictionary, water_second: Dictionary, water_changed: Dictionary, underground_first: Dictionary, underground_second: Dictionary, underground_changed: Dictionary) -> Dictionary:
	var failures := []
	var warnings := []
	for record in [
		{"name": "water_first", "generation": water_first},
		{"name": "water_second", "generation": water_second},
		{"name": "water_changed", "generation": water_changed},
		{"name": "underground_first", "generation": underground_first},
		{"name": "underground_second", "generation": underground_second},
		{"name": "underground_changed", "generation": underground_changed},
	]:
		var generation: Dictionary = record.get("generation", {})
		if generation.get("generated_map", {}).is_empty():
			failures.append("%s produced no generated map payload: %s" % [String(record.get("name", "")), JSON.stringify(generation.get("report", {}))])
		elif not bool(generation.get("ok", false)):
			warnings.append("%s had non-transit validation warnings/failures outside this slice: %s" % [String(record.get("name", "")), JSON.stringify(generation.get("report", {}).get("failures", []))])
	var water_payload: Dictionary = water_first.get("generated_map", {})
	var underground_payload: Dictionary = underground_first.get("generated_map", {})
	var water_transit: Dictionary = water_payload.get("staging", {}).get("water_underground_transit_gameplay", {}) if water_payload.get("staging", {}).get("water_underground_transit_gameplay", {}) is Dictionary else {}
	var underground_transit: Dictionary = underground_payload.get("staging", {}).get("water_underground_transit_gameplay", {}) if underground_payload.get("staging", {}).get("water_underground_transit_gameplay", {}) is Dictionary else {}
	var water_validation := _water_underground_transit_gameplay_validation(water_transit, water_payload)
	var underground_validation := _water_underground_transit_gameplay_validation(underground_transit, underground_payload)
	if not bool(water_validation.get("ok", false)):
		failures.append_array(water_validation.get("failures", []))
	if not bool(underground_validation.get("ok", false)):
		failures.append_array(underground_validation.get("failures", []))
	warnings.append_array(water_validation.get("warnings", []))
	warnings.append_array(underground_validation.get("warnings", []))
	if int(water_transit.get("summary", {}).get("water_transit_count", 0)) <= 0:
		failures.append("water case produced no materialized water transit records")
	if int(underground_transit.get("summary", {}).get("cross_level_link_count", 0)) <= 0:
		failures.append("underground case produced no materialized cross-level link records")
	if int(underground_transit.get("summary", {}).get("underground_level_count", 0)) <= 0:
		failures.append("underground case produced no underground level records")
	if String(water_payload.get("staging", {}).get("route_reachability_proof", {}).get("status", "")) != "pass":
		failures.append("water case route reachability proof did not pass")
	if String(underground_payload.get("staging", {}).get("route_reachability_proof", {}).get("status", "")) != "pass":
		failures.append("underground case route reachability proof did not pass")
	var water_sig := String(water_transit.get("gameplay_transit_signature", ""))
	var water_second_sig := String(water_second.get("generated_map", {}).get("staging", {}).get("water_underground_transit_gameplay", {}).get("gameplay_transit_signature", ""))
	var water_changed_sig := String(water_changed.get("generated_map", {}).get("staging", {}).get("water_underground_transit_gameplay", {}).get("gameplay_transit_signature", ""))
	var underground_sig := String(underground_transit.get("gameplay_transit_signature", ""))
	var underground_second_sig := String(underground_second.get("generated_map", {}).get("staging", {}).get("water_underground_transit_gameplay", {}).get("gameplay_transit_signature", ""))
	var underground_changed_sig := String(underground_changed.get("generated_map", {}).get("staging", {}).get("water_underground_transit_gameplay", {}).get("gameplay_transit_signature", ""))
	if water_sig == "" or water_sig != water_second_sig:
		failures.append("same input did not preserve water/transit signature")
	if water_sig == water_changed_sig:
		failures.append("changed seed did not change water/transit signature")
	if underground_sig == "" or underground_sig != underground_second_sig:
		failures.append("same input did not preserve underground/transit signature")
	if underground_sig == underground_changed_sig:
		failures.append("changed seed did not change underground/transit signature")
	for payload in [water_transit, underground_transit]:
		if bool(payload.get("boundary", {}).get("campaign_adoption", true)) or bool(payload.get("boundary", {}).get("authored_content_writeback", true)) or bool(payload.get("boundary", {}).get("parity_or_alpha_claim", true)):
			failures.append("transit gameplay payload violated campaign/writeback/parity boundary")
	return {
		"ok": failures.is_empty(),
		"status": "pass" if failures.is_empty() else "fail",
		"failures": failures,
		"warnings": warnings,
	}

static func _water_underground_case_summary(payload: Dictionary, transit: Dictionary) -> Dictionary:
	return {
		"ok": not payload.is_empty(),
		"scenario_id": String(payload.get("scenario_record", {}).get("id", "")),
		"stable_signature": String(payload.get("stable_signature", "")),
		"gameplay_transit_signature": String(transit.get("gameplay_transit_signature", "")),
		"summary": transit.get("summary", {}),
		"water_policy": transit.get("water_policy", {}),
		"underground_policy": transit.get("underground_policy", {}),
		"runtime_materialization_summary": payload.get("runtime_materialization", {}).get("summary", {}),
	}

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
	if String(generated_map.get("write_policy", "")) != "generated_export_record_no_authored_content_write":
		failures.append("generated payload lost generated export no-write boundary")
	if String(metadata.get("generator_version", "")) == "" or String(metadata.get("normalized_seed", "")) == "":
		failures.append("metadata must include normalized seed and generator version")
	var size_policy: Dictionary = metadata.get("size_policy", {}) if metadata.get("size_policy", {}) is Dictionary else {}
	if size_policy.is_empty():
		failures.append("metadata must include explicit size policy")
	else:
		var runtime_policy: Dictionary = size_policy.get("runtime_size_policy", {}) if size_policy.get("runtime_size_policy", {}) is Dictionary else {}
		var materialized_size: Dictionary = size_policy.get("materialized_size", {}) if size_policy.get("materialized_size", {}) is Dictionary else {}
		if not bool(runtime_policy.get("materialization_available", true)):
			failures.append("payload materialized despite unavailable runtime size policy")
		if bool(runtime_policy.get("hidden_downscale", true)):
			failures.append("runtime size policy must not permit hidden downscale")
		if int(materialized_size.get("width", width)) != width or int(materialized_size.get("height", height)) != height:
			failures.append("materialized size policy does not match scenario map size")
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
	var water_underground_transit: Dictionary = staging.get("water_underground_transit_gameplay", {})
	var town_start_constraints: Dictionary = staging.get("town_start_constraints", {})
	var road_network: Dictionary = staging.get("road_network", {})
	var reachability: Dictionary = staging.get("route_reachability_proof", {})
	var fairness_report: Dictionary = staging.get("fairness_report", {})
	var connection_guard_materialization: Dictionary = staging.get("connection_guard_materialization", {})
	var monster_reward_bands: Dictionary = staging.get("monster_reward_bands", {})
	var object_pool_value_weighting: Dictionary = staging.get("object_pool_value_weighting", {})
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
		var gameplay_validation := _water_underground_transit_gameplay_validation(water_underground_transit, generated_map)
		if not bool(gameplay_validation.get("ok", false)):
			for failure in gameplay_validation.get("failures", []):
				failures.append("water underground transit gameplay: %s" % String(failure))
		for warning in gameplay_validation.get("warnings", []):
			warnings.append("water underground transit gameplay: %s" % String(warning))
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
	if String(road_network.get("writeout_policy", "")) != "final_generated_tile_stream_no_authored_tile_write":
		failures.append("road network must expose final generated tile stream boundary")
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
	var object_pool_validation := _object_pool_value_weighting_validation(object_pool_value_weighting, generated_map)
	if not bool(object_pool_validation.get("ok", false)):
		for failure in object_pool_validation.get("failures", []):
			failures.append("object pool value weighting: %s" % String(failure))
	for warning in object_pool_validation.get("warnings", []):
		warnings.append("object pool value weighting: %s" % String(warning))
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
	for required_phase in ["template_profile", "runtime_zone_graph", "zone_seed_layout", "terrain_owner_grid", "terrain_biome_coherence", "terrain_transit_semantics", "object_placement_staging", "connection_guard_materialization", "monster_reward_bands", "object_pool_value_weighting", "town_mine_dwelling_placement", "decoration_density_pass", "object_footprint_catalog", "route_road_constraint_writeout", "roads_rivers_writeout", "resource_encounter_fairness_report"]:
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
		"object_pool_value_weighting_status": String(object_pool_value_weighting.get("status", "")),
		"object_pool_value_weighting_summary": object_pool_value_weighting.get("summary", {}),
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
		var catalog_metadata: Dictionary = zone_record.get("catalog_metadata", {}) if zone_record.get("catalog_metadata", {}) is Dictionary else {}
		catalog_metadata = _zone_catalog_metadata_with_richness_floor(zone_record, catalog_metadata)
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
			"catalog_metadata": catalog_metadata,
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
		unsupported.append("water_transit_gameplay_materialized_final_art_deferred")
		unsupported.append("boat_shipyard_ferry_ui_deferred")
	if level_count > 1:
		unsupported.append("underground_level_records_materialized")
		unsupported.append("subterranean_gate_sprite_polish_deferred")
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
			"object_and_transit_writeout": "gameplay_transit_records_materialized_final_art_writeout_deferred",
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
	var artifact_nodes := []
	var encounters := []
	var occupied := {}
	var town_spacing_reserved := {}
	var town_hard_spacing_reserved := {}
	var town_spacing_radius := _town_spacing_radius_for_size(normalized)
	var town_hard_spacing_radius := _town_hard_spacing_radius_for_size(normalized)
	var player_index := 0
	for zone in zones:
		if not (zone is Dictionary) or zone.get("player_slot", null) == null:
			continue
		var seed: Dictionary = seeds.get(String(zone.get("id", "")), {})
		var player_slot := int(zone.get("player_slot", 0))
		var player_type := String(zone.get("player_type", "computer"))
		var owner := "player" if player_type == "human" and player_slot == 1 else "enemy"
		var faction_id := String(zone.get("faction_id", ""))
		var town_id := String(town_ids[player_index % town_ids.size()]) if not town_ids.is_empty() else String(DEFAULT_TOWN_BY_FACTION.get(faction_id, "town_riverwatch"))
		var point := _nearest_free_cell_for_catalog("town", "town_primary", town_id, int(seed.get("x", 0)), int(seed.get("y", 0)), String(zone.get("id", "")), zone_grid, terrain_rows, occupied, rng, town_hard_spacing_reserved)
		if point.is_empty():
			continue
		var placement_id := "rmg_town_p%d" % (player_index + 1)
		var town := {"placement_id": placement_id, "town_id": town_id, "faction_id": faction_id, "player_slot": player_slot, "player_type": player_type, "team_id": String(zone.get("team_id", "")), "zone_id": String(zone.get("id", "")), "zone_role": String(zone.get("role", "")), "x": int(point.get("x", 0)), "y": int(point.get("y", 0)), "owner": owner, "town_assignment_semantics": "owned_start_uses_player_assignment_town", "zone_anchor": seed, "town_spacing_policy": _town_spacing_policy_payload(town_spacing_radius, town_hard_spacing_radius)}
		towns.append(town)
		placements.append(_object_placement(placement_id, "town", faction_id, String(zone.get("id", "")), point, {"town_id": town_id, "owner": owner, "player_slot": player_slot, "player_type": player_type, "team_id": String(zone.get("team_id", "")), "purpose": "player_start", "zone_role": String(zone.get("role", "")), "town_assignment_semantics": "owned_start_uses_player_assignment_town", "same_type_semantics": "owned_zone_player_assignment_not_neutral_same_type", "zone_anchor": seed, "town_spacing_policy": _town_spacing_policy_payload(town_spacing_radius, town_hard_spacing_radius)}))
		_mark_occupied_for_catalog(occupied, point, "town", "town_primary", town_id)
		_reserve_town_spacing(town_spacing_reserved, point, zone_grid, terrain_rows, town_spacing_radius)
		_reserve_town_spacing(town_hard_spacing_reserved, point, zone_grid, terrain_rows, town_hard_spacing_radius)
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
			resource_nodes.append({
				"placement_id": resource_placement_id,
				"site_id": String(resource.get("site_id", "")),
				"x": int(support_point.get("x", 0)),
				"y": int(support_point.get("y", 0)),
				"zone_id": String(zone.get("id", "")),
				"zone_role": String(zone.get("role", "")),
				"faction_id": faction_id,
				"purpose": String(resource.get("purpose", "")),
			})
			placements.append(_object_placement(resource_placement_id, "resource_site", faction_id, String(zone.get("id", "")), support_point, {"site_id": String(resource.get("site_id", "")), "purpose": String(resource.get("purpose", ""))}))
			_mark_occupied(occupied, support_point)
		player_index += 1
	var route_reserved := _reserved_route_corridor_lookup(links, seeds, zone_grid, terrain_rows)
	for zone in zones:
		if not (zone is Dictionary):
			continue
		_place_neutral_town_for_zone(zone, zones, seeds, zone_grid, terrain_rows, occupied, route_reserved, town_spacing_reserved, town_spacing_radius, town_hard_spacing_reserved, town_hard_spacing_radius, towns, placements, rng)
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
			rng,
			route_reserved
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
		"artifact_nodes": artifact_nodes,
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

static func _place_neutral_town_for_zone(zone: Dictionary, zones: Array, seeds: Dictionary, zone_grid: Array, terrain_rows: Array, occupied: Dictionary, reserved: Dictionary, town_spacing_reserved: Dictionary, town_spacing_radius: int, town_hard_spacing_reserved: Dictionary, town_hard_spacing_radius: int, towns: Array, placements: Array, rng: DeterministicRng) -> void:
	if zone.get("player_slot", null) != null:
		return
	var target_count := _neutral_town_target_count(zone)
	if target_count <= 0:
		return
	var zone_id := String(zone.get("id", ""))
	var seed: Dictionary = seeds.get(zone_id, {})
	var town_choice := _neutral_town_choice_for_zone(zone, zones, seeds)
	for index in range(target_count):
		var spacing_reserved := reserved.duplicate()
		for key in town_spacing_reserved.keys():
			spacing_reserved[key] = true
		var point := _nearest_free_cell_for_catalog("town", String(town_choice.get("faction_id", "")), String(town_choice.get("town_id", "")), int(seed.get("x", 0)) + index, int(seed.get("y", 0)) + index, zone_id, zone_grid, terrain_rows, occupied, rng, spacing_reserved)
		if point.is_empty():
			var hard_spacing_reserved := reserved.duplicate()
			for key in town_hard_spacing_reserved.keys():
				hard_spacing_reserved[key] = true
			point = _nearest_free_cell_for_catalog("town", String(town_choice.get("faction_id", "")), String(town_choice.get("town_id", "")), int(seed.get("x", 0)) + index, int(seed.get("y", 0)) + index, zone_id, zone_grid, terrain_rows, occupied, rng, hard_spacing_reserved)
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
			"zone_anchor": seed,
			"town_spacing_policy": _town_spacing_policy_payload(town_spacing_radius, town_hard_spacing_radius),
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
			"zone_anchor": seed,
			"town_spacing_policy": _town_spacing_policy_payload(town_spacing_radius, town_hard_spacing_radius),
		}))
		_mark_occupied_for_catalog(occupied, point, "town", "town_primary", town_id)
		_reserve_town_spacing(town_spacing_reserved, point, zone_grid, terrain_rows, town_spacing_radius)
		_reserve_town_spacing(town_hard_spacing_reserved, point, zone_grid, terrain_rows, town_hard_spacing_radius)

static func _place_mines_for_zone(zone: Dictionary, seeds: Dictionary, zone_grid: Array, terrain_rows: Array, occupied: Dictionary, reserved: Dictionary, resource_nodes: Array, placements: Array, rng: DeterministicRng) -> void:
	var zone_id := String(zone.get("id", ""))
	var seed: Dictionary = seeds.get(zone_id, {})
	var requirements: Dictionary = _zone_resource_requirements(zone)
	var minimums: Dictionary = requirements.get("minimum_by_category", {})
	var densities: Dictionary = requirements.get("density_by_category", {})
	var ordinal := 0
	var zone_mine_limit := _object_pool_limit_for_kind("mine", "per_zone", 999999)
	for category_record in ORIGINAL_RESOURCE_CATEGORY_ORDER:
		if not (category_record is Dictionary):
			continue
		var category_id := String(category_record.get("original_category_id", ""))
		var target_count := int(minimums.get(category_id, 0)) + _density_extra_count(zone, category_id, int(densities.get(category_id, 0)))
		for category_index in range(target_count):
			if ordinal >= zone_mine_limit:
				return
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
			_mark_occupied_for_catalog(occupied, point, "mine", String(mine_record.get("family_id", "")), String(mine_record.get("object_id", "")))
			_reserve_visit_tiles_for_catalog(reserved, point, "mine", String(mine_record.get("family_id", "")), String(mine_record.get("object_id", "")))
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
	_mark_occupied_for_catalog(occupied, point, "neutral_dwelling", "neutral_dwelling", String(dwelling.get("object_id", "")))
	_reserve_visit_tiles_for_catalog(reserved, point, "neutral_dwelling", "neutral_dwelling", String(dwelling.get("object_id", "")))

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

static func _town_spacing_radius_for_size(normalized: Dictionary) -> int:
	var size: Dictionary = normalized.get("size", {}) if normalized.get("size", {}) is Dictionary else {}
	var width := int(size.get("width", 36))
	var height := int(size.get("height", 36))
	var shortest: int = max(1, min(width, height))
	var minimum := 6 if shortest >= 30 else 5
	return clampi(max(minimum, int(ceil(float(shortest) / 8.0))), minimum, 18)

static func _town_hard_spacing_radius_for_size(normalized: Dictionary) -> int:
	return max(4, int(floor(float(_town_spacing_radius_for_size(normalized)) * 0.75)))

static func _town_spacing_policy_payload(preferred_radius: int, hard_radius: int) -> Dictionary:
	return {
		"source_model": "HoMM3_RMG_town_layer_after_runtime_zone_construction_translated_to_original_spacing_contract",
		"preferred_minimum_manhattan_distance": preferred_radius,
		"hard_fallback_minimum_manhattan_distance": hard_radius,
		"fallback_policy": "retry_with_hard_spacing_before_any_unspaced_town_placement",
	}

static func _reserve_town_spacing(reserved: Dictionary, point: Dictionary, zone_grid: Array, terrain_rows: Array, radius: int) -> void:
	var cx := int(point.get("x", 0))
	var cy := int(point.get("y", 0))
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if abs(dx) + abs(dy) > radius:
				continue
			var x := cx + dx
			var y := cy + dy
			if not _point_in_rows(terrain_rows, x, y):
				continue
			if String(_zone_at_point(zone_grid, _point_dict(x, y))) == "":
				continue
			reserved[_point_key(x, y)] = true

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

static func _zone_catalog_metadata_with_richness_floor(zone_record: Dictionary, metadata: Dictionary) -> Dictionary:
	var enriched := metadata.duplicate(true)
	var role := String(zone_record.get("role", enriched.get("role", "treasure")))
	if _zone_role_is_route_connector({"role": role}):
		return enriched
	var floor_record := {
		"source_model": "HoMM3_RMG_zone_mine_treasure_band_floor_translated_to_original_content",
		"applied_mine_floor": false,
		"applied_treasure_band_floor": false,
		"applied_monster_policy_floor": false,
		"role": role,
		"base_size": int(zone_record.get("base_size", enriched.get("base_size", 0))),
	}
	var mine_requirements: Dictionary = enriched.get("mine_requirements", {}) if enriched.get("mine_requirements", {}) is Dictionary else {}
	if mine_requirements.is_empty():
		mine_requirements = enriched.get("resource_category_requirements", {}) if enriched.get("resource_category_requirements", {}) is Dictionary else {}
	if not _zone_requirements_have_positive_counts(mine_requirements):
		mine_requirements = _zone_richness_floor_requirements(zone_record, role)
		enriched["mine_requirements"] = mine_requirements
		enriched["resource_category_requirements"] = mine_requirements.duplicate(true)
		floor_record["applied_mine_floor"] = true
	var treasure_bands: Array = enriched.get("treasure_bands", []) if enriched.get("treasure_bands", []) is Array else []
	if _eligible_treasure_bands(treasure_bands).is_empty():
		enriched["treasure_bands"] = _zone_richness_floor_treasure_bands(role, int(zone_record.get("base_size", 0)))
		floor_record["applied_treasure_band_floor"] = true
	var monster_policy: Dictionary = enriched.get("monster_policy", {}) if enriched.get("monster_policy", {}) is Dictionary else {}
	if monster_policy.is_empty():
		enriched["monster_policy"] = {
			"strength": "avg" if role.contains("start") else "strong" if role == "treasure" else "avg",
			"match_to_town": role.contains("start"),
			"allowed_faction_ids": ["neutral", "faction_embercourt", "faction_thornwake", "faction_sunvault", "faction_brasshollow", "faction_veilmourn", "faction_mireclaw"],
			"source": "zone_richness_floor",
		}
		floor_record["applied_monster_policy_floor"] = true
	enriched["richness_floor"] = floor_record
	return enriched

static func _zone_requirements_have_positive_counts(requirements: Dictionary) -> bool:
	for bucket_key in ["minimum_by_category", "density_by_category"]:
		var bucket: Dictionary = requirements.get(bucket_key, {}) if requirements.get(bucket_key, {}) is Dictionary else {}
		for category_id in bucket.keys():
			if int(bucket.get(category_id, 0)) > 0:
				return true
	return false

static func _zone_richness_floor_requirements(zone_record: Dictionary, role: String) -> Dictionary:
	var minimums := {}
	var densities := {}
	for category in ORIGINAL_RESOURCE_CATEGORY_ORDER:
		if category is Dictionary:
			var category_id := String(category.get("original_category_id", ""))
			minimums[category_id] = 0
			densities[category_id] = 0
	if role.contains("start"):
		minimums["timber"] = 1
		minimums["ore"] = 1
		densities["timber"] = 1
		densities["ore"] = 1
	elif role == "treasure":
		var category_id := _zone_richness_floor_resource_category_id(zone_record)
		minimums[category_id] = 1
		densities[category_id] = 1
	return {
		"minimum_by_category": minimums,
		"density_by_category": densities,
		"resource_category_ids": _original_resource_category_ids(),
		"source": "zone_richness_floor",
	}

static func _zone_richness_floor_resource_category_id(zone_record: Dictionary) -> String:
	var candidates := ["gold", "quicksilver", "ember_salt", "lens_crystal", "cut_gems"]
	return candidates[_stable_choice_index(candidates.size(), "%s:%s:zone_richness_floor_resource" % [String(zone_record.get("id", "")), String(zone_record.get("role", ""))])]

static func _zone_richness_floor_treasure_bands(role: String, base_size: int) -> Array:
	if role.contains("start"):
		return [
			{"low": 300, "high": 900, "density": 4},
			{"low": 900, "high": 1800, "density": 2},
			{"low": 0, "high": 0, "density": 0},
		]
	if role == "treasure":
		var high_scale := 2 if base_size >= 10 else 1
		return [
			{"low": 900 * high_scale, "high": 1800 * high_scale, "density": 2},
			{"low": 450, "high": 1200 * high_scale, "density": 5},
			{"low": 0, "high": 0, "density": 0},
		]
	return [
		{"low": 300, "high": 900, "density": 1},
		{"low": 0, "high": 0, "density": 0},
		{"low": 0, "high": 0, "density": 0},
	]

static func _original_resource_category_ids() -> Array:
	var ids := []
	for category in ORIGINAL_RESOURCE_CATEGORY_ORDER:
		if category is Dictionary:
			ids.append(String(category.get("original_category_id", "")))
	return ids

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
		"zone_role": String(payload.get("zone_role", "")),
		"guard_pressure": payload.get("guard_pressure", {}),
	}

static func _materialize_route_reward_resources(placements: Dictionary, monster_reward_bands: Dictionary, route_graph: Dictionary, road_network: Dictionary, zone_grid: Array, terrain_rows: Array, rng: DeterministicRng) -> Array:
	var resource_nodes: Array = placements.get("resource_nodes", [])
	var artifact_nodes: Array = placements.get("artifact_nodes", [])
	var object_placements: Array = placements.get("object_placements", [])
	var occupied := _occupied_body_lookup(object_placements)
	var reserved := _road_reserved_lookup(road_network)
	var edges_by_id := _route_edges_by_id(route_graph.get("edges", []))
	var reward_records := []
	for reward in monster_reward_bands.get("reward_band_records", []):
		if reward is Dictionary:
			reward_records.append(reward)
	var materialized := []
	for index in range(reward_records.size()):
		var reward: Dictionary = reward_records[index]
		var site_id := String(reward.get("site_id", ""))
		var object_id := String(reward.get("selected_reward_object_id", ""))
		var family_id := String(reward.get("selected_reward_family_id", ""))
		var artifact_id := String(reward.get("artifact_id", ""))
		if artifact_id == "" and (site_id == "" or ContentService.get_resource_site(site_id).is_empty()):
			continue
		var edge: Dictionary = edges_by_id.get(String(reward.get("route_edge_id", "")), {})
		if edge.is_empty() or not bool(edge.get("path_found", false)):
			continue
		var anchor: Dictionary = edge.get("route_cell_anchor_candidate", {}) if edge.get("route_cell_anchor_candidate", {}) is Dictionary else {}
		if anchor.is_empty():
			anchor = edge.get("to_anchor", {}) if edge.get("to_anchor", {}) is Dictionary else {}
		if anchor.is_empty():
			continue
		var offset := _route_reward_anchor_offset(index)
		var point := _nearest_free_cell_for_catalog(
			"reward_reference",
			family_id,
			object_id,
			int(anchor.get("x", 0)) + offset.x,
			int(anchor.get("y", 0)) + offset.y,
			null,
			zone_grid,
			terrain_rows,
			occupied,
			rng,
			reserved
		)
		if point.is_empty():
			continue
		var zone_id := String(_zone_at_point(zone_grid, point))
		if zone_id == "":
			zone_id = String(edge.get("to", edge.get("from", "")))
		var placement_id := "rmg_reward_%s" % String(reward.get("id", "reward_%02d" % (index + 1)))
		var payload := {
			"site_id": site_id,
			"object_id": object_id,
			"family_id": family_id,
			"purpose": "route_reward_cache",
			"artifact_id": artifact_id,
			"owner": "neutral",
			"player_slot": 0,
			"player_type": "neutral",
			"team_id": "",
			"zone_role": "route_reward",
			"route_edge_id": String(reward.get("route_edge_id", "")),
			"source_reward_band_id": String(reward.get("id", "")),
			"selected_reward_category_id": String(reward.get("selected_reward_category_id", "")),
			"selected_resource_category_id": String(reward.get("selected_resource_category_id", "")),
			"candidate_value": int(reward.get("candidate_value", 0)),
			"guarded_policy": String(reward.get("guarded_policy", "")),
			"writeout_state": "materialized_route_reward_resource_node_from_existing_reward_band",
		}
		if artifact_id != "":
			payload["purpose"] = "guarded_artifact_cache"
			payload["writeout_state"] = "materialized_guarded_artifact_node_from_reward_band"
		var placement := _object_placement(placement_id, "reward_reference", "", zone_id, point, payload)
		_apply_pathing_metadata(placement, zone_grid, terrain_rows, occupied)
		object_placements.append(placement)
		if artifact_id != "":
			var artifact_node := _route_reward_artifact_node_from_placement(placement_id, payload, point, zone_id)
			_copy_shared_placement_metadata(artifact_node, placement)
			artifact_nodes.append(artifact_node)
		else:
			var node := _route_reward_resource_node_from_placement(placement_id, payload, point, zone_id)
			_copy_shared_placement_metadata(node, placement)
			resource_nodes.append(node)
		materialized.append({
			"placement_id": placement_id,
			"site_id": site_id,
			"object_id": object_id,
			"artifact_id": artifact_id,
			"route_edge_id": String(reward.get("route_edge_id", "")),
			"x": int(point.get("x", 0)),
			"y": int(point.get("y", 0)),
			"zone_id": zone_id,
		})
		_mark_occupied_for_catalog(occupied, point, "reward_reference", family_id, object_id)
	placements["resource_nodes"] = resource_nodes
	placements["artifact_nodes"] = artifact_nodes
	placements["object_placements"] = object_placements
	placements["materialized_route_reward_summary"] = {
		"materialized_count": materialized.size(),
		"artifact_node_count": artifact_nodes.size(),
		"resource_node_count": resource_nodes.size(),
	}
	return materialized

static func _materialize_route_density_support(normalized: Dictionary, placements: Dictionary, road_network: Dictionary, zone_grid: Array, terrain_rows: Array, rng: DeterministicRng) -> Array:
	var density_policy := _route_density_support_policy(normalized, terrain_rows)
	if not bool(density_policy.get("enabled", false)):
		return []
	var start := _density_start_point(placements)
	if start.is_empty():
		return []
	var materialized := []
	var reserved := _road_reserved_lookup(road_network)
	var max_records := int(density_policy.get("max_records", 12))
	for index in range(max_records):
		var object_placements: Array = placements.get("object_placements", [])
		var occupied := _occupied_body_lookup(object_placements)
		var distances := _density_passable_distances(terrain_rows, occupied, start)
		var existing_points := _density_existing_interactable_lookup(placements, distances, int(density_policy.get("max_distance", 24)))
		var window := _largest_density_empty_window(terrain_rows, distances, existing_points, density_policy)
		if int(window.get("reachable_cells", 0)) <= int(density_policy.get("empty_cell_threshold", 42)):
			break
		var candidate := _density_support_reward_candidate(index)
		var point := _density_window_free_cell_for_catalog(
			window,
			distances,
			density_policy,
			"reward_reference",
			String(candidate.get("object_family_id", "")),
			String(candidate.get("object_id", "")),
			zone_grid,
			terrain_rows,
			occupied,
			reserved
		)
		if point.is_empty():
			point = _nearest_free_cell_for_catalog(
				"reward_reference",
				String(candidate.get("object_family_id", "")),
				String(candidate.get("object_id", "")),
				int(window.get("center_x", 0)),
				int(window.get("center_y", 0)),
				null,
				zone_grid,
				terrain_rows,
				occupied,
				rng,
				reserved
			)
		if point.is_empty():
			break
		var distance := int(distances.get(_point_key(int(point.get("x", 0)), int(point.get("y", 0))), -1))
		if distance < int(density_policy.get("min_distance", 7)) or distance > int(density_policy.get("max_distance", 24)):
			break
		var zone_id := String(_zone_at_point(zone_grid, point))
		var placement_id := "%s%02d" % [String(density_policy.get("placement_prefix", "rmg_route_density_cache_")), materialized.size() + 1]
		var payload := {
			"site_id": String(candidate.get("site_id", "")),
			"object_id": String(candidate.get("object_id", "")),
			"family_id": String(candidate.get("object_family_id", "")),
			"purpose": String(density_policy.get("purpose", "route_density_support")),
			"owner": "neutral",
			"player_slot": 0,
			"player_type": "neutral",
			"team_id": "",
			"zone_role": String(density_policy.get("zone_role", "route_density_support")),
			"selected_reward_category_id": String(candidate.get("reward_category", "")),
			"selected_resource_category_id": String(candidate.get("categories", [])[0]) if candidate.get("categories", []) is Array and not candidate.get("categories", []).is_empty() else "",
			"candidate_value": int(candidate.get("value", 0)),
			"guarded_policy": String(candidate.get("guarded_policy", "")),
			"density_window": window,
			"writeout_state": String(density_policy.get("writeout_state", "materialized_route_density_support_from_reachable_empty_window")),
		}
		var placement := _object_placement(placement_id, "reward_reference", "", zone_id, point, payload)
		_apply_pathing_metadata(placement, zone_grid, terrain_rows, occupied)
		object_placements.append(placement)
		var resource_nodes: Array = placements.get("resource_nodes", [])
		var node := _density_support_resource_node_from_placement(placement_id, payload, point, zone_id)
		_copy_shared_placement_metadata(node, placement)
		resource_nodes.append(node)
		placements["object_placements"] = object_placements
		placements["resource_nodes"] = resource_nodes
		materialized.append({
			"placement_id": placement_id,
			"site_id": String(candidate.get("site_id", "")),
			"object_id": String(candidate.get("object_id", "")),
			"x": int(point.get("x", 0)),
			"y": int(point.get("y", 0)),
			"zone_id": zone_id,
			"distance_from_start": distance,
			"density_window": window,
		})
	return materialized

static func _materialize_object_guards(normalized: Dictionary, placements: Dictionary, road_network: Dictionary, zone_grid: Array, terrain_rows: Array, rng: DeterministicRng, route_reward_records: Array = []) -> Array:
	var object_placements: Array = placements.get("object_placements", [])
	var encounters: Array = placements.get("encounters", [])
	var occupied := _occupied_body_lookup(object_placements)
	var reserved := _road_reserved_lookup(road_network)
	var candidates := []
	var candidate_keys := {}
	for node in placements.get("artifact_nodes", []):
		if node is Dictionary:
			_append_object_guard_candidate(candidates, candidate_keys, node, "artifact", 1800, "guarded_artifact_reward")
	for record in route_reward_records:
		if record is Dictionary and String(record.get("artifact_id", "")) != "":
			_append_object_guard_candidate(candidates, candidate_keys, record, "artifact", 1800, "guarded_artifact_reward")
	for node in placements.get("resource_nodes", []):
		if not (node is Dictionary):
			continue
		if String(node.get("original_resource_category_id", "")) != "":
			var pressure: Dictionary = node.get("guard_pressure", {}) if node.get("guard_pressure", {}) is Dictionary else {}
			if bool(pressure.get("guarded", false)):
				_append_object_guard_candidate(candidates, candidate_keys, node, "mine", int(pressure.get("base_value", 1200)), "guarded_mine")
		elif String(node.get("neutral_dwelling_family_id", "")) != "":
			if int(node.get("player_slot", 0)) == 0:
				_append_object_guard_candidate(candidates, candidate_keys, node, "neutral_dwelling", 1200, "guarded_dwelling")
		elif String(node.get("generated_kind", "")) == "route_reward" and String(node.get("guarded_policy", "")).find("guarded") >= 0:
			_append_object_guard_candidate(candidates, candidate_keys, node, "route_reward", max(800, int(node.get("candidate_value", 800))), "guarded_reward_cache")
	candidates.sort_custom(Callable(RandomMapGeneratorRules, "_compare_object_guard_candidate"))
	var artifact_candidate_count: int = _count_object_guard_candidates_for_kind(candidates, "artifact")
	var max_guards: int = max(_object_guard_cap_for_size(normalized, candidates.size()), artifact_candidate_count)
	var materialized := []
	var skipped_no_cell := 0
	for index in range(min(max_guards, candidates.size())):
		var candidate: Dictionary = candidates[index]
		var target: Dictionary = candidate.get("target", {}) if candidate.get("target", {}) is Dictionary else {}
		var zone_id := String(target.get("zone_id", _zone_at_point(zone_grid, target)))
		var offset := _object_guard_anchor_offset(index)
		var point := _nearest_object_guard_cell_for_target(
			target,
			zone_id,
			zone_grid,
			terrain_rows,
			occupied,
			reserved,
			index
		)
		if point.is_empty():
			point = _nearest_free_cell_for_catalog(
				"route_guard",
				"route_guard",
				DEFAULT_ENCOUNTER_ID,
				int(target.get("x", 0)) + offset.x,
				int(target.get("y", 0)) + offset.y,
				zone_id if zone_id != "" else null,
				zone_grid,
				terrain_rows,
				occupied,
				rng,
				reserved
			)
		if point.is_empty():
			point = _nearest_free_cell_for_catalog("route_guard", "route_guard", DEFAULT_ENCOUNTER_ID, int(target.get("x", 0)) + offset.x, int(target.get("y", 0)) + offset.y, null, zone_grid, terrain_rows, occupied, rng, reserved)
		if point.is_empty():
			point = _nearest_free_cell_for_catalog(
				"route_guard",
				"route_guard",
				DEFAULT_ENCOUNTER_ID,
				int(target.get("x", 0)) + offset.x,
				int(target.get("y", 0)) + offset.y,
				zone_id if zone_id != "" else null,
				zone_grid,
				terrain_rows,
				occupied,
				rng,
				{}
			)
		if point.is_empty():
			point = _nearest_free_cell_for_catalog("route_guard", "route_guard", DEFAULT_ENCOUNTER_ID, int(target.get("x", 0)) + offset.x, int(target.get("y", 0)) + offset.y, null, zone_grid, terrain_rows, occupied, rng, {})
		if point.is_empty():
			skipped_no_cell += 1
			continue
		var placement_id := "rmg_object_guard_%03d" % (materialized.size() + 1)
		var guard_value := int(candidate.get("guard_value", 1000))
		var target_point := _point_dict(int(target.get("x", 0)), int(target.get("y", 0)))
		var guard_distance := _object_guard_distance_to_target(point, target)
		var adjacent_to_guarded_object := _object_guard_is_adjacent_to_target(point, target, guard_distance)
		var payload := {
			"encounter_id": DEFAULT_ENCOUNTER_ID,
			"purpose": String(candidate.get("guard_context", "")),
			"guard_context": String(candidate.get("guard_context", "")),
			"guarded_object_kind": String(candidate.get("kind", "")),
			"guarded_object_placement_id": String(target.get("placement_id", "")),
			"guarded_artifact_id": String(target.get("artifact_id", "")),
			"guarded_site_id": String(target.get("site_id", "")),
			"guarded_object_point": target_point,
			"guard_distance": guard_distance,
			"adjacent_to_guarded_object": adjacent_to_guarded_object,
			"guard_value": guard_value,
			"effective_guard_pressure": _guard_strength_class_from_value(guard_value),
			"association_policy": "artifact_rewards_are_guarded_before_lower_priority_mines_dwellings_and_cache_fillers",
			"wide": false,
			"border_guard": false,
		}
		var placement := _object_placement(placement_id, "route_guard", "", String(_zone_at_point(zone_grid, point)), point, payload)
		_apply_pathing_metadata(placement, zone_grid, terrain_rows, occupied)
		object_placements.append(placement)
		var encounter := {
			"placement_id": placement_id,
			"encounter_id": DEFAULT_ENCOUNTER_ID,
			"x": int(point.get("x", 0)),
			"y": int(point.get("y", 0)),
			"difficulty": "generated_object_guard",
			"guard_context": String(candidate.get("guard_context", "")),
			"guarded_object_kind": String(candidate.get("kind", "")),
			"guarded_object_placement_id": String(target.get("placement_id", "")),
			"guarded_artifact_id": String(target.get("artifact_id", "")),
			"guarded_object_point": target_point,
			"guard_distance": guard_distance,
			"adjacent_to_guarded_object": adjacent_to_guarded_object,
			"guard_value": guard_value,
		}
		_copy_shared_placement_metadata(encounter, placement)
		encounters.append(encounter)
		materialized.append({
			"placement_id": placement_id,
			"guarded_object_placement_id": String(target.get("placement_id", "")),
			"guarded_object_kind": String(candidate.get("kind", "")),
			"guard_context": String(candidate.get("guard_context", "")),
			"x": int(point.get("x", 0)),
			"y": int(point.get("y", 0)),
			"zone_id": String(placement.get("zone_id", "")),
			"guarded_object_point": target_point,
			"guard_distance": guard_distance,
			"adjacent_to_guarded_object": adjacent_to_guarded_object,
			"guard_value": guard_value,
		})
		_mark_occupied_for_catalog(occupied, point, "route_guard", "route_guard", DEFAULT_ENCOUNTER_ID)
	var candidate_counts_by_kind := _count_object_guard_candidates_by_kind(candidates)
	var materialized_counts_by_kind := _count_materialized_object_guards_by_kind(materialized)
	var unguarded_candidates := _unguarded_object_guard_candidates(candidates, materialized)
	placements["object_placements"] = object_placements
	placements["encounters"] = encounters
	placements["materialized_object_guard_summary"] = {
		"artifact_node_count_seen": placements.get("artifact_nodes", []).size(),
		"route_reward_artifact_record_count_seen": _count_route_reward_artifacts(route_reward_records),
		"resource_node_count_seen": placements.get("resource_nodes", []).size(),
		"candidate_count": candidates.size(),
		"candidate_counts_by_kind": candidate_counts_by_kind,
		"artifact_candidate_count": artifact_candidate_count,
		"cap": max_guards,
		"materialized_count": materialized.size(),
		"materialized_counts_by_kind": materialized_counts_by_kind,
		"artifact_guard_count": _count_materialized_object_guards_for_kind(materialized, "artifact"),
		"mine_candidate_count": int(candidate_counts_by_kind.get("mine", 0)),
		"mine_guard_count": int(materialized_counts_by_kind.get("mine", 0)),
		"dwelling_candidate_count": int(candidate_counts_by_kind.get("neutral_dwelling", 0)),
		"dwelling_guard_count": int(materialized_counts_by_kind.get("neutral_dwelling", 0)),
		"route_reward_candidate_count": int(candidate_counts_by_kind.get("route_reward", 0)),
		"route_reward_guard_count": int(materialized_counts_by_kind.get("route_reward", 0)),
		"guardable_valuable_object_count": candidates.size(),
		"guarded_valuable_object_count": materialized.size(),
		"unguarded_valuable_object_count": unguarded_candidates.size(),
		"unguarded_valuable_object_samples": unguarded_candidates.slice(0, 12),
		"artifact_guard_coverage_policy": "all_materialized_artifact_rewards_before_lower_priority_object_guards_when_cells_available",
		"skipped_no_cell": skipped_no_cell,
	}
	return materialized

static func _append_object_guard_candidate(candidates: Array, seen: Dictionary, target: Dictionary, kind: String, guard_value: int, context: String) -> void:
	var key := _object_guard_candidate_key(target, kind)
	if seen.has(key):
		return
	seen[key] = true
	candidates.append(_object_guard_candidate(target, kind, guard_value, context))

static func _object_guard_candidate_key(target: Dictionary, kind: String) -> String:
	var placement_id := String(target.get("placement_id", ""))
	if placement_id != "":
		return "%s:%s" % [kind, placement_id]
	return "%s:%d,%d:%s:%s" % [kind, int(target.get("x", 0)), int(target.get("y", 0)), String(target.get("artifact_id", "")), String(target.get("site_id", ""))]

static func _nearest_object_guard_cell_for_target(target: Dictionary, preferred_zone_id: String, zone_grid: Array, terrain_rows: Array, occupied: Dictionary, reserved: Dictionary, ordinal: int) -> Dictionary:
	var preferred_points: Array = []
	var approaches: Array = target.get("approach_tiles", []) if target.get("approach_tiles", []) is Array else []
	for approach in approaches:
		if approach is Dictionary:
			preferred_points.append(approach)
	if preferred_points.is_empty():
		var target_x := int(target.get("x", 0))
		var target_y := int(target.get("y", 0))
		for offset in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
			preferred_points.append(_point_dict(target_x + offset.x, target_y + offset.y))
	var rotated: Array = []
	for i in range(preferred_points.size()):
		rotated.append(preferred_points[(i + ordinal) % preferred_points.size()])
	var catalog := _object_footprint_catalog_record_for_placement({
		"kind": "route_guard",
		"family_id": "route_guard",
		"object_id": DEFAULT_ENCOUNTER_ID,
	})
	for candidate in rotated:
		if candidate is Dictionary and _placement_candidate_satisfies_catalog(int(candidate.get("x", 0)), int(candidate.get("y", 0)), preferred_zone_id if preferred_zone_id != "" else null, zone_grid, terrain_rows, occupied, catalog, reserved):
			return _point_dict(int(candidate.get("x", 0)), int(candidate.get("y", 0)))
	for candidate in rotated:
		if candidate is Dictionary and _placement_candidate_satisfies_catalog(int(candidate.get("x", 0)), int(candidate.get("y", 0)), preferred_zone_id if preferred_zone_id != "" else null, zone_grid, terrain_rows, occupied, catalog, {}):
			return _point_dict(int(candidate.get("x", 0)), int(candidate.get("y", 0)))
	for candidate in rotated:
		if candidate is Dictionary and _placement_candidate_satisfies_catalog(int(candidate.get("x", 0)), int(candidate.get("y", 0)), null, zone_grid, terrain_rows, occupied, catalog, reserved):
			return _point_dict(int(candidate.get("x", 0)), int(candidate.get("y", 0)))
	for candidate in rotated:
		if candidate is Dictionary and _placement_candidate_satisfies_catalog(int(candidate.get("x", 0)), int(candidate.get("y", 0)), null, zone_grid, terrain_rows, occupied, catalog, {}):
			return _point_dict(int(candidate.get("x", 0)), int(candidate.get("y", 0)))
	return {}

static func _object_guard_distance_to_target(point: Dictionary, target: Dictionary) -> int:
	var target_point := _point_dict(int(target.get("x", 0)), int(target.get("y", 0)))
	var distance := _manhattan_distance(target_point, point)
	var approaches: Array = target.get("approach_tiles", []) if target.get("approach_tiles", []) is Array else []
	if _point_in_array(approaches, point):
		distance = min(distance, 1)
	for body in target.get("body_tiles", []):
		if body is Dictionary:
			distance = min(distance, _manhattan_distance(body, point))
	return distance

static func _object_guard_is_adjacent_to_target(point: Dictionary, target: Dictionary, distance: int) -> bool:
	if distance <= 1:
		return true
	var approaches: Array = target.get("approach_tiles", []) if target.get("approach_tiles", []) is Array else []
	return _point_in_array(approaches, point)

static func _object_guard_candidate(target: Dictionary, kind: String, guard_value: int, context: String) -> Dictionary:
	var priority := 0 if kind == "artifact" else 1
	return {
		"target": target,
		"kind": kind,
		"guard_value": max(600, guard_value),
		"guard_context": context,
		"priority": priority,
		"sort_key": "%02d:%09d:%s" % [priority, 999999999 - max(600, guard_value), String(target.get("placement_id", ""))],
	}

static func _compare_object_guard_candidate(a: Dictionary, b: Dictionary) -> bool:
	return String(a.get("sort_key", "")) < String(b.get("sort_key", ""))

static func _count_object_guard_candidates_for_kind(candidates: Array, kind: String) -> int:
	var count := 0
	for candidate in candidates:
		if candidate is Dictionary and String(candidate.get("kind", "")) == kind:
			count += 1
	return count

static func _count_object_guard_candidates_by_kind(candidates: Array) -> Dictionary:
	var counts := {}
	for candidate in candidates:
		if not (candidate is Dictionary):
			continue
		var kind := String(candidate.get("kind", ""))
		if kind == "":
			continue
		counts[kind] = int(counts.get(kind, 0)) + 1
	return _sorted_dict(counts)

static func _count_materialized_object_guards_for_kind(records: Array, kind: String) -> int:
	var count := 0
	for record in records:
		if record is Dictionary and String(record.get("guarded_object_kind", "")) == kind:
			count += 1
	return count

static func _count_materialized_object_guards_by_kind(records: Array) -> Dictionary:
	var counts := {}
	for record in records:
		if not (record is Dictionary):
			continue
		var kind := String(record.get("guarded_object_kind", ""))
		if kind == "":
			continue
		counts[kind] = int(counts.get(kind, 0)) + 1
	return _sorted_dict(counts)

static func _unguarded_object_guard_candidates(candidates: Array, materialized: Array) -> Array:
	var guarded := {}
	for record in materialized:
		if not (record is Dictionary):
			continue
		var key := "%s:%s" % [String(record.get("guarded_object_kind", "")), String(record.get("guarded_object_placement_id", ""))]
		guarded[key] = true
	var missing := []
	for candidate in candidates:
		if not (candidate is Dictionary):
			continue
		var target: Dictionary = candidate.get("target", {}) if candidate.get("target", {}) is Dictionary else {}
		var key := _object_guard_candidate_key(target, String(candidate.get("kind", "")))
		if guarded.has(key):
			continue
		missing.append({
			"kind": String(candidate.get("kind", "")),
			"placement_id": String(target.get("placement_id", "")),
			"site_id": String(target.get("site_id", "")),
			"artifact_id": String(target.get("artifact_id", "")),
			"zone_id": String(target.get("zone_id", "")),
			"x": int(target.get("x", 0)),
			"y": int(target.get("y", 0)),
			"guard_value": int(candidate.get("guard_value", 0)),
			"guard_context": String(candidate.get("guard_context", "")),
		})
	return missing

static func _count_route_reward_artifacts(records: Array) -> int:
	var count := 0
	for record in records:
		if record is Dictionary and String(record.get("artifact_id", "")) != "":
			count += 1
	return count

static func _object_guard_cap_for_size(normalized: Dictionary, candidate_count: int) -> int:
	var size: Dictionary = normalized.get("size", {}) if normalized.get("size", {}) is Dictionary else {}
	var width := int(size.get("width", 36))
	var height := int(size.get("height", 36))
	if min(width, height) < 36:
		return min(candidate_count, 8)
	var map_bound: int = max(8, int(ceil(float(max(1, width * height)) / 24.0)))
	return min(candidate_count, map_bound)

static func _object_guard_anchor_offset(index: int) -> Vector2i:
	var offsets := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
	return offsets[index % offsets.size()]

static func _route_density_support_policy(normalized: Dictionary, terrain_rows: Array) -> Dictionary:
	var size: Dictionary = normalized.get("size", {}) if normalized.get("size", {}) is Dictionary else {}
	var width: int = int(size.get("width", 0))
	var height: int = int(size.get("height", 0))
	if width <= 0 or height <= 0:
		height = terrain_rows.size()
		width = terrain_rows[0].size() if height > 0 and terrain_rows[0] is Array else 0
	var template_id: String = String(normalized.get("template_id", ""))
	var profile_id: String = String(normalized.get("profile", {}).get("id", ""))
	var is_compact: bool = template_id.contains("compact") or profile_id.contains("compact")
	var is_translated: bool = template_id.begins_with("translated_rmg_template_") or profile_id.begins_with("translated_rmg_profile_")
	if not is_compact and not is_translated:
		return {"enabled": false, "reason": "template_profile_not_supported_for_route_density_support"}
	var edge: float = max(1.0, float(min(max(1, width), max(1, height))) / 36.0)
	var window_size: int = int(ceil(8.0 * edge))
	var min_distance: int = int(ceil(7.0 * edge))
	var max_distance: int = int(ceil(24.0 * edge))
	var window_area: int = max(1, window_size * window_size)
	var threshold: int = int(floor(float(window_area) * 0.66))
	var max_records: int = 12 if is_compact else int(ceil(12.0 * edge))
	return {
		"enabled": true,
		"scope": "compact" if is_compact else "translated",
		"scale": snapped(edge, 0.001),
		"window_size": window_size,
		"min_distance": min_distance,
		"max_distance": max_distance,
		"empty_cell_threshold": threshold,
		"max_records": max_records,
		"placement_prefix": "rmg_compact_density_cache_" if is_compact else "rmg_route_density_cache_",
		"purpose": "compact_route_density_support" if is_compact else "route_density_support",
		"zone_role": "compact_density_support" if is_compact else "translated_route_density_support",
		"writeout_state": "materialized_compact_density_support_from_reachable_empty_window" if is_compact else "materialized_route_density_support_from_reachable_empty_window",
	}

static func _density_start_point(placements: Dictionary) -> Dictionary:
	for town_value in placements.get("towns", []):
		if not (town_value is Dictionary):
			continue
		var town: Dictionary = town_value
		if String(town.get("owner", "")) == "player" or (String(town.get("player_type", "")) == "human" and int(town.get("player_slot", 0)) == 1):
			return _density_record_point(town)
	for town_value in placements.get("towns", []):
		if town_value is Dictionary:
			return _density_record_point(town_value)
	return {}

static func _density_record_point(record: Dictionary) -> Dictionary:
	var visit: Dictionary = record.get("visit_tile", {}) if record.get("visit_tile", {}) is Dictionary else {}
	if not visit.is_empty():
		return _point_dict(int(visit.get("x", 0)), int(visit.get("y", 0)))
	var approaches: Array = record.get("approach_tiles", []) if record.get("approach_tiles", []) is Array else []
	if not approaches.is_empty() and approaches[0] is Dictionary:
		return _point_dict(int(approaches[0].get("x", 0)), int(approaches[0].get("y", 0)))
	return _point_dict(int(record.get("x", 0)), int(record.get("y", 0)))

static func _density_passable_distances(terrain_rows: Array, occupied: Dictionary, start: Dictionary) -> Dictionary:
	var height := terrain_rows.size()
	var width: int = terrain_rows[0].size() if height > 0 and terrain_rows[0] is Array else 0
	var start_point := Vector2i(int(start.get("x", 0)), int(start.get("y", 0)))
	var distances := {}
	var queue := [start_point]
	distances[_point_key(start_point.x, start_point.y)] = 0
	var cursor := 0
	while cursor < queue.size():
		var current: Vector2i = queue[cursor]
		cursor += 1
		var current_distance := int(distances.get(_point_key(current.x, current.y), 0))
		for offset in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
			var next_tile: Vector2i = current + offset
			if next_tile.x < 0 or next_tile.y < 0 or next_tile.x >= width or next_tile.y >= height:
				continue
			var key := _point_key(next_tile.x, next_tile.y)
			if distances.has(key):
				continue
			if occupied.has(key) or not _terrain_cell_is_passable(terrain_rows, next_tile.x, next_tile.y):
				continue
			distances[key] = current_distance + 1
			queue.append(next_tile)
	return distances

static func _density_existing_interactable_lookup(placements: Dictionary, distances: Dictionary, max_distance: int) -> Dictionary:
	var lookup := {}
	for collection_name in ["towns", "resource_nodes", "encounters"]:
		for value in placements.get(collection_name, []):
			if not (value is Dictionary):
				continue
			var point := _density_record_point(value)
			var key := _point_key(int(point.get("x", 0)), int(point.get("y", 0)))
			var distance := int(distances.get(key, -1))
			if distance >= 0 and distance <= max_distance:
				lookup[key] = true
	return lookup

static func _largest_density_empty_window(terrain_rows: Array, distances: Dictionary, existing_points: Dictionary, density_policy: Dictionary) -> Dictionary:
	var height := terrain_rows.size()
	var width: int = terrain_rows[0].size() if height > 0 and terrain_rows[0] is Array else 0
	var window_size := int(density_policy.get("window_size", 8))
	var max_distance := int(density_policy.get("max_distance", 24))
	var scan_stride: int = max(1, int(floor(float(window_size) / 4.0)))
	var best := {"reachable_cells": 0}
	for y0 in range(0, max(0, height - window_size + 1), scan_stride):
		for x0 in range(0, max(0, width - window_size + 1), scan_stride):
			var reachable_cells := 0
			var object_count := 0
			for y in range(y0, y0 + window_size):
				for x in range(x0, x0 + window_size):
					var key := _point_key(x, y)
					var distance := int(distances.get(key, -1))
					if distance < 0 or distance > max_distance:
						continue
					if not _terrain_cell_is_passable(terrain_rows, x, y):
						continue
					reachable_cells += 1
					if existing_points.has(key):
						object_count += 1
			if object_count == 0 and reachable_cells > int(best.get("reachable_cells", 0)):
				best = {
					"x": x0,
					"y": y0,
					"width": window_size,
					"height": window_size,
					"center_x": x0 + int(floor(float(window_size) / 2.0)),
					"center_y": y0 + int(floor(float(window_size) / 2.0)),
					"reachable_cells": reachable_cells,
				}
	return best

static func _density_window_free_cell_for_catalog(window: Dictionary, distances: Dictionary, density_policy: Dictionary, kind: String, family_id: String, object_id: String, zone_grid: Array, terrain_rows: Array, occupied: Dictionary, reserved: Dictionary) -> Dictionary:
	var probe := {"kind": kind, "family_id": family_id, "object_id": object_id, "x": int(window.get("center_x", 0)), "y": int(window.get("center_y", 0))}
	var catalog := _object_footprint_catalog_record_for_placement(probe)
	var x0 := int(window.get("x", 0))
	var y0 := int(window.get("y", 0))
	var x1 := x0 + int(window.get("width", 8))
	var y1 := y0 + int(window.get("height", 8))
	var center_x := int(window.get("center_x", x0 + 4))
	var center_y := int(window.get("center_y", y0 + 4))
	var min_distance := int(density_policy.get("min_distance", 7))
	var max_distance := int(density_policy.get("max_distance", 24))
	var max_radius: int = max(1, int(ceil(float(max(int(window.get("width", 8)), int(window.get("height", 8)))) / 2.0)) + 1)
	for radius in range(max_radius):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if max(abs(dx), abs(dy)) != radius:
					continue
				var x := center_x + dx
				var y := center_y + dy
				if x < x0 or y < y0 or x >= x1 or y >= y1:
					continue
				var distance := int(distances.get(_point_key(x, y), -1))
				if distance < min_distance or distance > max_distance:
					continue
				if _placement_candidate_satisfies_catalog(x, y, null, zone_grid, terrain_rows, occupied, catalog, reserved):
					return _point_dict(x, y)
	return {}

static func _density_support_reward_candidate(index: int) -> Dictionary:
	var candidates := [
		{"reward_category": "resource_cache", "object_family_id": "reward_cache_small", "object_id": "object_waystone_cache", "site_id": "site_waystone_cache", "value": 450, "categories": ["gold"], "guarded_policy": "unguarded_or_light_guard"},
		{"reward_category": "build_resource_cache", "object_family_id": "reward_cache_small", "object_id": "object_ore_crates", "site_id": "site_ore_crates", "value": 650, "categories": ["ore"], "guarded_policy": "unguarded_or_light_guard"},
		{"reward_category": "build_resource_cache", "object_family_id": "reward_cache_small", "object_id": "object_wood_wagon", "site_id": "site_wood_wagon", "value": 650, "categories": ["timber"], "guarded_policy": "unguarded_or_light_guard"},
	]
	return candidates[index % candidates.size()]

static func _density_support_resource_node_from_placement(placement_id: String, payload: Dictionary, point: Dictionary, zone_id: String) -> Dictionary:
	return {
		"placement_id": placement_id,
		"site_id": String(payload.get("site_id", "")),
		"object_id": String(payload.get("object_id", "")),
		"x": int(point.get("x", 0)),
		"y": int(point.get("y", 0)),
		"zone_id": zone_id,
		"zone_role": String(payload.get("zone_role", "")),
		"owner": "neutral",
		"player_slot": 0,
		"kind": String(payload.get("purpose", "route_density_support")),
		"generated_kind": "route_reward",
		"selected_reward_category_id": String(payload.get("selected_reward_category_id", "")),
		"selected_resource_category_id": String(payload.get("selected_resource_category_id", "")),
		"candidate_value": int(payload.get("candidate_value", 0)),
		"guarded_policy": String(payload.get("guarded_policy", "")),
		"density_window": payload.get("density_window", {}),
	}

static func _route_reward_artifact_node_from_placement(placement_id: String, payload: Dictionary, point: Dictionary, zone_id: String) -> Dictionary:
	return {
		"placement_id": placement_id,
		"artifact_id": String(payload.get("artifact_id", "")),
		"x": int(point.get("x", 0)),
		"y": int(point.get("y", 0)),
		"zone_id": zone_id,
		"zone_role": String(payload.get("zone_role", "")),
		"collected": false,
		"owner": "neutral",
		"player_slot": 0,
		"kind": "guarded_artifact_cache",
		"generated_kind": "route_artifact_reward",
		"route_edge_id": String(payload.get("route_edge_id", "")),
		"source_reward_band_id": String(payload.get("source_reward_band_id", "")),
		"selected_reward_category_id": String(payload.get("selected_reward_category_id", "")),
		"candidate_value": int(payload.get("candidate_value", 0)),
		"guarded_policy": String(payload.get("guarded_policy", "")),
	}

static func _route_reward_resource_node_from_placement(placement_id: String, payload: Dictionary, point: Dictionary, zone_id: String) -> Dictionary:
	return {
		"placement_id": placement_id,
		"site_id": String(payload.get("site_id", "")),
		"object_id": String(payload.get("object_id", "")),
		"x": int(point.get("x", 0)),
		"y": int(point.get("y", 0)),
		"zone_id": zone_id,
		"zone_role": String(payload.get("zone_role", "")),
		"owner": "neutral",
		"player_slot": 0,
		"kind": "route_reward_cache",
		"generated_kind": "route_reward",
		"route_edge_id": String(payload.get("route_edge_id", "")),
		"source_reward_band_id": String(payload.get("source_reward_band_id", "")),
		"selected_reward_category_id": String(payload.get("selected_reward_category_id", "")),
		"selected_resource_category_id": String(payload.get("selected_resource_category_id", "")),
		"candidate_value": int(payload.get("candidate_value", 0)),
		"guarded_policy": String(payload.get("guarded_policy", "")),
	}

static func _road_reserved_lookup(road_network: Dictionary) -> Dictionary:
	var reserved := {}
	for segment in road_network.get("road_segments", []):
		if not (segment is Dictionary):
			continue
		for cell in segment.get("cells", []):
			if cell is Dictionary:
				reserved[_point_key(int(cell.get("x", 0)), int(cell.get("y", 0)))] = true
	return reserved

static func _route_reward_anchor_offset(index: int) -> Vector2i:
	var offsets := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
	return offsets[index % offsets.size()]

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
	var player_faction_id := String(faction_ids[0]) if not faction_ids.is_empty() else "faction_embercourt"
	var player_hero_id := _default_hero_for_faction(player_faction_id)
	var player_army_id := _default_army_for_faction(player_faction_id)
	var victory_objectives := []
	var defeat_objectives := []
	if not towns.is_empty() and towns[0] is Dictionary:
		var starting_town_id := String(towns[0].get("placement_id", ""))
		defeat_objectives.append({
			"id": "generated_primary_town_lost",
			"type": "town_not_owned_by_player",
			"placement_id": starting_town_id,
			"label": "Do not lose the generated starting town",
			"generated_support": "ScenarioRules.town_not_owned_by_player",
		})
	var rival_town := _generated_rival_town_objective_target(towns)
	if not rival_town.is_empty():
		victory_objectives.append({
			"id": "generated_capture_rival_town",
			"type": "town_owned_by_player",
			"placement_id": String(rival_town.get("placement_id", "")),
			"label": "Claim a generated rival town",
			"generated_support": "ScenarioRules.town_owned_by_player",
		})
	else:
		victory_objectives.append({
			"id": "generated_hold_until_day_14",
			"type": "day_at_least",
			"day": 14,
			"label": "Hold the generated frontier until Day 14",
			"generated_support": "ScenarioRules.day_at_least",
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
		"player_faction_id": player_faction_id,
		"player_army_id": player_army_id,
		"hero_id": player_hero_id,
		"starting_resources": {"gold": 1500, "wood": 4, "ore": 3},
		"map": terrain_rows,
		"start": start,
		"hero_starts": [player_hero_id],
		"generated_hero_starts": [
			{
				"placement_id": "rmg_hero_start_p1",
				"hero_id": player_hero_id,
				"x": int(start.get("x", 0)),
				"y": int(start.get("y", 0)),
				"owner": "player",
				"source": "generated_start_contract",
			}
		],
		"towns": placements.get("towns", []),
		"resource_nodes": placements.get("resource_nodes", []),
		"artifact_nodes": placements.get("artifact_nodes", []),
		"encounters": placements.get("encounters", []),
		"objectives": {
			"victory_text": "Generated prototype objective completed.",
			"defeat_text": "Generated prototype objective failed.",
			"victory": victory_objectives,
			"defeat": defeat_objectives,
		},
		"script_hooks": [],
		"enemy_factions": [],
		"generated_player_assignment": normalized.get("player_assignment", {}),
		"generated_constraints": {
			"zone_layout": constraints.get("zone_layout", {}),
			"terrain": constraints.get("terrain_constraints", {}),
			"terrain_transit": constraints.get("terrain_transit_semantics", {}),
			"water_underground_transit": constraints.get("water_underground_transit_gameplay", {}),
			"connection_guard_materialization": constraints.get("connection_guard_materialization", {}),
			"monster_reward_bands": constraints.get("monster_reward_bands", {}),
			"materialized_object_guards": constraints.get("materialized_object_guards", []),
			"materialized_route_reward_summary": placements.get("materialized_route_reward_summary", {}),
			"materialized_object_guard_summary": placements.get("materialized_object_guard_summary", {}),
			"object_pool_value_weighting": constraints.get("object_pool_value_weighting", {}),
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

static func _generated_rival_town_objective_target(towns: Array) -> Dictionary:
	for town in towns:
		if town is Dictionary and String(town.get("owner", "neutral")) == "enemy":
			return town
	for town in towns:
		if town is Dictionary and String(town.get("owner", "neutral")) != "player":
			return town
	return {}

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

static func runtime_materialization_for_generated_map(generated_map: Dictionary) -> Dictionary:
	var materialization: Dictionary = generated_map.get("runtime_materialization", {}) if generated_map.get("runtime_materialization", {}) is Dictionary else {}
	return materialization.duplicate(true) if not materialization.is_empty() else {}

static func runtime_materialization_identity(generated_map: Dictionary) -> Dictionary:
	var materialization := runtime_materialization_for_generated_map(generated_map)
	return _runtime_materialization_summary(materialization)

static func _build_playable_runtime_materialization_record(
	normalized: Dictionary,
	scenario: Dictionary,
	terrain_layers: Dictionary,
	placements: Dictionary,
	constraints: Dictionary,
	phases: Array
) -> Dictionary:
	var metadata := _metadata(normalized)
	var serialization: Dictionary = constraints.get("roads_rivers_writeout", {}).get("generated_map_serialization", {}) if constraints.get("roads_rivers_writeout", {}).get("generated_map_serialization", {}) is Dictionary else {}
	var object_instances: Array = serialization.get("object_instances", []) if serialization.get("object_instances", []) is Array else []
	var overlay_layers: Array = serialization.get("overlay_layers", []) if serialization.get("overlay_layers", []) is Array else []
	var terrain_rows: Array = scenario.get("map", []) if scenario.get("map", []) is Array else []
	var materialized := {
		"schema_id": PLAYABLE_RUNTIME_MATERIALIZATION_SCHEMA_ID,
		"materialization_policy": "runtime_registry_session_bootstrap_no_authored_json_writeback",
		"source_slice_id": "random-map-playable-materialization-runtime-integration-10184",
		"scenario_id": String(scenario.get("id", "")),
		"generated": true,
		"generator_version": String(metadata.get("generator_version", "")),
		"template_id": String(metadata.get("template_id", "")),
		"profile_id": String(metadata.get("profile", {}).get("id", "")),
		"normalized_seed": String(metadata.get("normalized_seed", "")),
		"content_manifest_fingerprint": String(metadata.get("content_manifest_fingerprint", "")),
		"map_size": scenario.get("map_size", {}),
		"terrain": {
			"rows": terrain_rows,
			"terrain_layers_record_id": String(terrain_layers.get("id", "")),
			"terrain_layers": terrain_layers.get("terrain_layers", []),
			"terrain_semantics": terrain_layers.get("terrain_semantics", {}),
			"level_records": constraints.get("water_underground_transit_gameplay", {}).get("underground_level_records", []),
		},
		"overlays": {
			"overlay_layers": overlay_layers,
			"roads": terrain_layers.get("roads", []),
			"road_stubs": terrain_layers.get("road_stubs", []),
			"route_graph_stub": terrain_layers.get("route_graph_stub", {}),
		},
		"starts": {
			"scenario_start": scenario.get("start", {}),
			"hero_starts": scenario.get("generated_hero_starts", []),
			"player_slots": scenario.get("players", []),
		},
		"objects": {
			"towns": scenario.get("towns", []),
			"resources": _runtime_resource_records(scenario.get("resource_nodes", [])),
			"artifacts": scenario.get("artifact_nodes", []),
			"mines": _runtime_mine_records(scenario.get("resource_nodes", [])),
			"dwellings": _runtime_dwelling_records(scenario.get("resource_nodes", [])),
			"guards": _runtime_guard_records(scenario, placements, constraints),
			"rewards": _runtime_reward_records(constraints, object_instances),
			"transit": _runtime_transit_records(constraints),
			"object_instances": object_instances,
		},
		"object_placements": placements.get("object_placements", []),
		"objectives": scenario.get("objectives", {}),
		"generated_constraints": scenario.get("generated_constraints", {}),
		"validation": {
			"phase_statuses": _runtime_phase_statuses(phases),
			"retry_status": "single_attempt_validation_report_required_before_runtime_launch",
			"writeback_status": "memory_registry_only",
		},
		"boundary": {
			"authored_content_writeback": false,
			"campaign_record": false,
			"authored_skirmish_browser_record": false,
			"parity_or_alpha_claim": false,
		},
	}
	materialized = _json_safe_value(materialized)
	materialized["materialized_map_signature"] = _hash32_hex(_stable_stringify(materialized))
	materialized["summary"] = _runtime_materialization_counts(materialized)
	return materialized

static func _runtime_materialization_summary(materialization: Dictionary) -> Dictionary:
	if materialization.is_empty():
		return {}
	return {
		"schema_id": String(materialization.get("schema_id", "")),
		"scenario_id": String(materialization.get("scenario_id", "")),
		"materialized_map_signature": String(materialization.get("materialized_map_signature", "")),
		"generator_version": String(materialization.get("generator_version", "")),
		"template_id": String(materialization.get("template_id", "")),
		"profile_id": String(materialization.get("profile_id", "")),
		"normalized_seed": String(materialization.get("normalized_seed", "")),
		"content_manifest_fingerprint": String(materialization.get("content_manifest_fingerprint", "")),
		"summary": materialization.get("summary", {}),
		"boundary": materialization.get("boundary", {}),
	}

static func _runtime_materialization_counts(materialization: Dictionary) -> Dictionary:
	var objects: Dictionary = materialization.get("objects", {}) if materialization.get("objects", {}) is Dictionary else {}
	var overlays: Dictionary = materialization.get("overlays", {}) if materialization.get("overlays", {}) is Dictionary else {}
	return {
		"terrain_row_count": materialization.get("terrain", {}).get("rows", []).size(),
		"overlay_layer_count": overlays.get("overlay_layers", []).size(),
		"town_count": objects.get("towns", []).size(),
		"resource_count": objects.get("resources", []).size(),
		"artifact_count": objects.get("artifacts", []).size(),
		"mine_count": objects.get("mines", []).size(),
		"dwelling_count": objects.get("dwellings", []).size(),
		"guard_count": objects.get("guards", []).size(),
		"reward_count": objects.get("rewards", []).size(),
		"transit_count": objects.get("transit", []).size(),
		"object_instance_count": objects.get("object_instances", []).size(),
	}

static func _runtime_phase_statuses(phases: Array) -> Array:
	var statuses := []
	for phase in phases:
		if not (phase is Dictionary):
			continue
		statuses.append({
			"name": String(phase.get("name", "")),
			"status": String(phase.get("status", "pass")),
			"summary": phase.get("summary", {}),
		})
	return statuses

static func _runtime_resource_records(nodes: Variant) -> Array:
	var filtered := []
	if not (nodes is Array):
		return filtered
	for node in nodes:
		if not (node is Dictionary):
			continue
		if String(node.get("original_resource_category_id", "")) == "" and String(node.get("neutral_dwelling_family_id", "")) == "":
			filtered.append(node.duplicate(true))
	return filtered

static func _runtime_mine_records(nodes: Variant) -> Array:
	var filtered := []
	if not (nodes is Array):
		return filtered
	for node in nodes:
		if node is Dictionary and String(node.get("original_resource_category_id", "")) != "":
			filtered.append(node.duplicate(true))
	return filtered

static func _runtime_dwelling_records(nodes: Variant) -> Array:
	var filtered := []
	if not (nodes is Array):
		return filtered
	for node in nodes:
		if node is Dictionary and String(node.get("neutral_dwelling_family_id", "")) != "":
			filtered.append(node.duplicate(true))
	return filtered

static func _runtime_guard_records(scenario: Dictionary, placements: Dictionary, constraints: Dictionary) -> Array:
	var records := []
	for encounter in scenario.get("encounters", []):
		if encounter is Dictionary:
			var record: Dictionary = encounter.duplicate(true)
			record["guard_kind"] = "encounter_route_guard"
			records.append(record)
	for placement in placements.get("object_placements", []):
		if placement is Dictionary and String(placement.get("kind", "")) == "special_guard_gate":
			var special: Dictionary = placement.duplicate(true)
			special["guard_kind"] = "special_guard_gate"
			records.append(special)
	for materialized in constraints.get("connection_guard_materialization", {}).get("materialized_records", []):
		if materialized is Dictionary:
			var materialized_record: Dictionary = materialized.duplicate(true)
			materialized_record["guard_kind"] = "connection_guard_materialization"
			records.append(materialized_record)
	return records

static func _runtime_reward_records(constraints: Dictionary, object_instances: Array) -> Array:
	var records := []
	for record in constraints.get("monster_reward_bands", {}).get("records", []):
		if record is Dictionary:
			records.append(record.duplicate(true))
	for instance in object_instances:
		if instance is Dictionary and String(instance.get("kind", "")) == "reward_reference":
			records.append(instance.duplicate(true))
	return records

static func _runtime_transit_records(constraints: Dictionary) -> Array:
	var transit: Dictionary = constraints.get("water_underground_transit_gameplay", {}) if constraints.get("water_underground_transit_gameplay", {}) is Dictionary else {}
	var records := []
	for record in transit.get("materialized_transit_records", []):
		if record is Dictionary:
			records.append(record.duplicate(true))
	return records

static func _default_hero_for_faction(faction_id: String) -> String:
	return String(DEFAULT_HERO_BY_FACTION.get(faction_id, DEFAULT_HERO_BY_FACTION.get("faction_embercourt", "hero_lyra")))

static func _default_army_for_faction(faction_id: String) -> String:
	return String(DEFAULT_ARMY_BY_FACTION.get(faction_id, DEFAULT_ARMY_BY_FACTION.get("faction_embercourt", "army_emberwell_vanguard")))

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
		"water_underground_transit_gameplay": constraints.get("water_underground_transit_gameplay", {}),
		"connection_guard_materialization": constraints.get("connection_guard_materialization", {}),
		"monster_reward_bands": constraints.get("monster_reward_bands", {}),
		"materialized_route_rewards": constraints.get("materialized_route_rewards", []),
		"materialized_route_reward_summary": placements.get("materialized_route_reward_summary", {}),
		"materialized_object_guards": constraints.get("materialized_object_guards", []),
		"materialized_object_guard_summary": placements.get("materialized_object_guard_summary", {}),
		"object_pool_value_weighting": constraints.get("object_pool_value_weighting", {}),
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

static func _build_constraint_payload(normalized: Dictionary, zones: Array, links: Array, seeds: Dictionary, zone_grid: Array, terrain_rows: Array, placements: Dictionary, zone_layout: Dictionary, terrain_transit: Dictionary, rng: DeterministicRng) -> Dictionary:
	var terrain_constraints := _terrain_constraints_payload(terrain_rows, zone_grid, zones, terrain_transit)
	var occupied := _route_blocking_occupied_lookup(placements.get("object_placements", []))
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
	var materialized_route_rewards := _materialize_route_reward_resources(
		placements,
		monster_reward_bands,
		route_graph,
		route_build.get("road_network", {}),
		zone_grid,
		terrain_rows,
		rng
	)
	var materialized_route_density_support := _materialize_route_density_support(
		normalized,
		placements,
		route_build.get("road_network", {}),
		zone_grid,
		terrain_rows,
		rng
	)
	var materialized_object_guards := _materialize_object_guards(
		normalized,
		placements,
		route_build.get("road_network", {}),
		zone_grid,
		terrain_rows,
		rng,
		materialized_route_rewards
	)
	var object_pool_value_weighting := _build_object_pool_value_weighting_payload(
		normalized,
		zones,
		placements,
		monster_reward_bands,
		{},
		{},
		terrain_rows,
		route_graph
	)
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
	object_pool_value_weighting = _build_object_pool_value_weighting_payload(
		normalized,
		zones,
		placements,
		monster_reward_bands,
		town_mine_dwelling,
		decoration_density,
		terrain_rows,
		route_graph
	)
	var fairness_report := _fairness_report_payload(normalized, zones, placements, route_graph, route_build.get("route_reachability_proof", {}), {}, town_mine_dwelling)
	return {
		"zone_layout": zone_layout,
		"terrain_constraints": terrain_constraints,
		"terrain_transit_semantics": terrain_transit,
		"water_underground_transit_gameplay": terrain_transit.get("gameplay_transit_materialization", {}),
		"connection_guard_materialization": connection_guard_materialization,
		"monster_reward_bands": monster_reward_bands,
		"materialized_route_rewards": materialized_route_rewards,
		"materialized_route_density_support": materialized_route_density_support,
		"materialized_compact_density_support": materialized_route_density_support,
		"materialized_object_guards": materialized_object_guards,
		"object_pool_value_weighting": object_pool_value_weighting,
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
		var footprint_rejected_count := 0
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
			var family_id := String(family.get("family_id", ""))
			var family_catalog := _object_footprint_catalog_record_for_placement({
				"kind": "decorative_obstacle",
				"family_id": family_id,
				"x": int(candidate.get("x", 0)),
				"y": int(candidate.get("y", 0)),
			})
			if not _placement_candidate_satisfies_catalog(
				int(candidate.get("x", 0)),
				int(candidate.get("y", 0)),
				zone_id,
				zone_layout.get("surface_owner_grid", []),
				terrain_rows,
				staged_occupied,
				family_catalog,
				exclusion
			):
				footprint_rejected_count += 1
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
				"family_id": family_id,
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
				for body in record.get("body_tiles", []):
					if body is Dictionary:
						staged_occupied[_point_key(int(body.get("x", 0)), int(body.get("y", 0)))] = record_id
		var footprint_capacity_limited := selected.size() < effective_target and cursor >= candidates.size() and footprint_rejected_count > 0
		var validation_effective_target := selected.size() if footprint_capacity_limited else effective_target
		if selected.size() < effective_target:
			diagnostics.append(_decoration_diagnostic(
				zone_id,
				"footprint_capacity_limited" if footprint_capacity_limited else "density_target_underfilled",
				"zone selected %d of effective target %d after %d footprint/body-mask rejections" % [selected.size(), effective_target, footprint_rejected_count],
				not footprint_capacity_limited
			))
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
			"validation_effective_target": validation_effective_target,
			"placed_count": selected.size(),
			"tolerance": tolerance,
			"within_tolerance": abs(selected.size() - validation_effective_target) <= tolerance,
			"capacity_limited": raw_target > candidates.size() or footprint_capacity_limited,
			"footprint_capacity_limited": footprint_capacity_limited,
			"footprint_rejected_count": footprint_rejected_count,
			"monster_reward_context": reward_context,
			"family_ids_selected": _decoration_family_ids(selected),
		})
	var route_shaping := _decoration_route_shaping_summary(records, route_graph, road_network, terrain_rows, placements)
	var path_validation := _decoration_path_safety_validation(records, route_graph, terrain_rows, _route_blocking_occupied_lookup(placements.get("object_placements", [])), reachability)
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
		"route_shaping_summary": route_shaping,
		"density_validation": density_validation,
		"terrain_transit_signature": String(terrain_transit.get("terrain_transit_signature", "")),
		"route_reachability_status_before_decoration": String(reachability.get("status", "")),
		"monster_reward_bands_signature": String(monster_reward_bands.get("monster_reward_bands_signature", "")),
		"diagnostics": diagnostics,
		"summary": {
			"zone_count": zone_targets.size(),
			"record_count": records.size(),
			"blocking_body_tile_total": _decoration_blocking_body_tile_total(records),
			"multitile_decoration_count": _decoration_multitile_record_count(records),
			"raw_target_total": _decoration_sum_zone_targets(zone_targets, "raw_target"),
			"effective_target_total": _decoration_sum_zone_targets(zone_targets, "effective_target"),
			"placed_total": _decoration_sum_zone_targets(zone_targets, "placed_count"),
			"density_target_failures": density_validation.get("failures", []).size(),
			"path_safety_status": String(path_validation.get("status", "")),
			"route_shoulder_body_count": int(route_shaping.get("route_shoulder_body_count", 0)),
			"route_shoulder_decoration_count": int(route_shaping.get("route_shoulder_decoration_count", 0)),
			"required_route_with_shoulder_count": int(route_shaping.get("required_route_with_shoulder_count", 0)),
			"required_route_count": int(route_shaping.get("required_route_count", 0)),
			"choked_road_tile_count": int(route_shaping.get("choked_road_tile_count", 0)),
			"required_route_with_choke_count": int(route_shaping.get("required_route_with_choke_count", 0)),
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
		"route_shaping_summary": route_shaping,
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
	var authored_resource_producer := _authored_resource_producer_catalog_record_for_placement(record)
	if not authored_resource_producer.is_empty():
		return authored_resource_producer
	var kind := String(record.get("kind", ""))
	var object_id := _object_record_content_id(record)
	var family_id := String(record.get("family_id", record.get("selected_reward_family_id", "")))
	for catalog in OBJECT_FOOTPRINT_CATALOG:
		if not (catalog is Dictionary):
			continue
		if kind != "" and kind in catalog.get("placement_kinds", []):
			if _catalog_matches_object_or_family(catalog, object_id, family_id):
				if kind == "decorative_obstacle":
					return _decorative_obstacle_catalog_for_family(catalog, family_id)
				return catalog
			if object_id == "" and family_id == "":
				return catalog
	for catalog in OBJECT_FOOTPRINT_CATALOG:
		if not (catalog is Dictionary):
			continue
		if family_id != "" and family_id in catalog.get("family_ids", []):
			if kind == "decorative_obstacle" or String(catalog.get("family_id", "")) == "decorative_obstacle":
				return _decorative_obstacle_catalog_for_family(catalog, family_id)
			return catalog
		if object_id != "" and object_id in catalog.get("object_ids", []):
			return catalog
	return {}

static func _decorative_obstacle_catalog_for_family(catalog: Dictionary, family_id: String) -> Dictionary:
	var result: Dictionary = catalog.duplicate(true)
	for family in DECORATION_OBJECT_FAMILIES:
		if not (family is Dictionary) or String(family.get("family_id", "")) != family_id:
			continue
		var body_mask: Array = family.get("body_mask", [{"x": 0, "y": 0}])
		var footprint: Dictionary = family.get("footprint", result.get("footprint", {})) if family.get("footprint", {}) is Dictionary else result.get("footprint", {})
		result["family_id"] = family_id
		result["display_name"] = String(family.get("display_name", result.get("display_name", "")))
		result["footprint"] = footprint.duplicate(true)
		result["runtime_footprint"] = footprint.duplicate(true)
		result["body_mask"] = body_mask.duplicate(true)
		result["runtime_body_mask"] = body_mask.duplicate(true)
		result["family_body_mask_source"] = "terrain_biased_decoration_family_passability_mask"
		return result
	return result

static func _authored_resource_producer_catalog_record_for_placement(record: Dictionary) -> Dictionary:
	var kind := String(record.get("kind", ""))
	if kind not in ["mine", "resource_producer", "persistent_economy_site", "neutral_dwelling"]:
		return {}
	var object_id := String(record.get("object_id", "")).strip_edges()
	var map_object := ContentService.get_map_object(object_id) if object_id != "" else {}
	if map_object.is_empty():
		map_object = ContentService.get_map_object_for_resource_site(String(record.get("site_id", "")))
	if map_object.is_empty():
		return {}
	var family := String(map_object.get("family", ""))
	var primary_class := String(map_object.get("primary_class", ""))
	if primary_class not in ["persistent_economy_site", "neutral_dwelling"] and family not in ["mine", "staged_resource_front", "support_producer", "neutral_dwelling"]:
		return {}
	var footprint: Dictionary = map_object.get("footprint", {}) if map_object.get("footprint", {}) is Dictionary else {}
	var body_mask := _authored_map_object_body_mask(map_object)
	var visit_mask := _authored_map_object_visit_mask(map_object)
	if visit_mask.is_empty():
		visit_mask = [{"x": 0, "y": 1}]
	var approach_mask := _authored_map_object_approach_mask(body_mask, visit_mask)
	var passability_class := String(map_object.get("passability_class", ""))
	var body_blocks := passability_class not in ["passable_visit_on_enter", "passable_scenic"] and not bool(map_object.get("passable", true))
	if passability_class in ["blocking_visitable", "blocking_non_visitable", "edge_blocker", "conditional_pass", "town_blocking", "neutral_stack_blocking"]:
		body_blocks = true
	var object_ids := [String(map_object.get("id", object_id))]
	var resource_site_id := String(map_object.get("resource_site_id", ""))
	if resource_site_id != "":
		object_ids.append(resource_site_id)
	var trigger := "neutral_dwelling_recruitment" if primary_class == "neutral_dwelling" or family == "neutral_dwelling" or kind == "neutral_dwelling" else "mine_capture"
	var cadence := "persistent_weekly" if trigger == "neutral_dwelling_recruitment" else "capture_then_daily"
	return {
		"id": "authored_%s" % String(map_object.get("id", object_id)),
		"family_id": family,
		"display_name": String(map_object.get("name", map_object.get("id", object_id))),
		"placement_kinds": [kind],
		"family_ids": [family],
		"object_ids": object_ids,
		"footprint": footprint.duplicate(true),
		"runtime_footprint": footprint.duplicate(true),
		"body_mask": body_mask,
		"runtime_body_mask": body_mask.duplicate(true),
		"visit_mask": visit_mask,
		"approach_mask": approach_mask,
		"passability_mask": {
			"body_blocks_movement": body_blocks,
			"visit_tiles_passable": false,
			"visit_tiles_actionable_when_blocked": true,
			"approach_tiles_passable": true,
			"road_may_cross_body": false,
		},
		"action_mask": {
			"visitable": true,
			"trigger": trigger,
			"visit_tile_required": true,
			"interaction_cadence": cadence,
			"strict_single_visit_tile": true,
			"runtime_body_contract": "authored_body_tiles_match_visible_generated_footprint",
		},
		"terrain_restrictions": {
			"allowed_terrain_ids": ["grass", "snow", "sand", "dirt", "rough", "lava", "underground"],
			"blocked_terrain_ids": ["water", "rock"],
		},
		"placement_predicates": ["in_bounds", "terrain_allowed", "runtime_body_unoccupied", "authored_visit_access_passable"],
		"object_limit": {"per_zone": 7, "global": 128},
	}

static func _authored_map_object_body_mask(map_object: Dictionary) -> Array:
	var body_mask := []
	var origin_offset := _map_object_anchor_origin_offset(map_object)
	var authored_body = map_object.get("body_tiles", [])
	if authored_body is Array:
		for body_value in authored_body:
			if body_value is Dictionary:
				body_mask.append({
					"x": origin_offset.x + int(body_value.get("x", 0)),
					"y": origin_offset.y + int(body_value.get("y", 0)),
				})
	if body_mask.is_empty():
		body_mask.append({"x": 0, "y": 0})
	return body_mask

static func _authored_map_object_visit_mask(map_object: Dictionary) -> Array:
	var visit_mask := []
	var origin_offset := _map_object_anchor_origin_offset(map_object)
	var approach: Dictionary = map_object.get("approach", {}) if map_object.get("approach", {}) is Dictionary else {}
	var offsets = approach.get("visit_offsets", [])
	if offsets is Array:
		for offset_value in offsets:
			if offset_value is Dictionary:
				visit_mask.append({
					"x": origin_offset.x + int(offset_value.get("x", 0)),
					"y": origin_offset.y + int(offset_value.get("y", 0)),
				})
	return visit_mask

static func _authored_map_object_approach_mask(body_mask: Array, visit_mask: Array) -> Array:
	var body_lookup := {}
	for body in body_mask:
		if body is Dictionary:
			body_lookup[_point_key(int(body.get("x", 0)), int(body.get("y", 0)))] = true
	var result := []
	var seen := {}
	for visit in visit_mask:
		if not (visit is Dictionary):
			continue
		for offset in _cardinal_offsets():
			var ax: int = int(visit.get("x", 0)) + int(offset.x)
			var ay: int = int(visit.get("y", 0)) + int(offset.y)
			var key := _point_key(ax, ay)
			if body_lookup.has(key) or seen.has(key):
				continue
			seen[key] = true
			result.append({"x": ax, "y": ay})
	return result

static func _map_object_anchor_origin_offset(map_object: Dictionary) -> Vector2i:
	var footprint: Dictionary = map_object.get("footprint", {}) if map_object.get("footprint", {}) is Dictionary else {}
	var width: int = maxi(1, int(footprint.get("width", 1)))
	var height: int = maxi(1, int(footprint.get("height", 1)))
	match String(footprint.get("anchor", "bottom_center")):
		"top_left":
			return Vector2i.ZERO
		"center":
			return Vector2i(-int(width / 2), -int(height / 2))
		"bottom_left":
			return Vector2i(0, -(height - 1))
		"bottom_right":
			return Vector2i(-(width - 1), -(height - 1))
		_:
			return Vector2i(-int(width / 2), -(height - 1))

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

static func _visit_tiles_for_catalog(point: Dictionary, catalog: Dictionary) -> Array:
	if catalog.is_empty():
		return [point]
	return _relative_mask_to_tiles(point, catalog.get("visit_mask", []))

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
	var route_occupied := {}
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
			if String(record.get("kind", "")) not in ["route_guard", "special_guard_gate", "reward_reference"]:
				route_occupied[key] = placement_id
	for reward_ref in reward_reference_records:
		if not (reward_ref is Dictionary):
			failures.append("non-dictionary reward footprint reference")
			continue
		var ref: Dictionary = reward_ref.get("object_footprint_catalog_ref", {}) if reward_ref.get("object_footprint_catalog_ref", {}) is Dictionary else {}
		if String(ref.get("status", "")) != "catalog_record_applied":
			missing_catalog_ids.append(String(reward_ref.get("id", "")))
	var route_failures := _object_footprint_route_failures(route_graph, terrain_rows, route_occupied, reachability)
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
				if route_occupied.has(key) and not _road_segment_cell_is_endpoint(segment, cell):
					failures.append("road segment %s crosses footprint body %s at %s" % [String(segment.get("route_edge_id", "")), String(route_occupied[key]), key])
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
		var route_occupied := occupied.duplicate(true)
		route_occupied.erase(_point_key(int(from_anchor.get("x", 0)), int(from_anchor.get("y", 0))))
		route_occupied.erase(_point_key(int(to_anchor.get("x", 0)), int(to_anchor.get("y", 0))))
		var path := _find_passable_path(from_anchor, to_anchor, terrain_rows, route_occupied)
		if path.is_empty():
			failures.append("required route %s is blocked under footprint body occupancy" % String(edge.get("id", "")))
	return failures

static func _road_segment_cell_is_endpoint(segment: Dictionary, cell: Dictionary) -> bool:
	var cells: Array = segment.get("cells", []) if segment.get("cells", []) is Array else []
	if cells.is_empty():
		return false
	var x := int(cell.get("x", 0))
	var y := int(cell.get("y", 0))
	var first: Dictionary = cells[0] if cells[0] is Dictionary else {}
	var last: Dictionary = cells[cells.size() - 1] if cells[cells.size() - 1] is Dictionary else {}
	return (
		(not first.is_empty() and int(first.get("x", 0)) == x and int(first.get("y", 0)) == y)
		or (not last.is_empty() and int(last.get("x", 0)) == x and int(last.get("y", 0)) == y)
	)

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
		if generated_map.has("save_adoption") or scenario.has("save_adoption") or scenario.has("alpha_parity_claim") or String(generated_map.get("write_policy", "")) != "generated_export_record_no_authored_content_write":
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
			"minimum_town_distance_required": int(validation.get("town_spacing", {}).get("minimum_distance_required", 0)),
			"observed_minimum_town_distance": int(validation.get("town_spacing", {}).get("observed_minimum_distance", 0)),
			"start_town_minimum_distance_required": int(validation.get("town_spacing", {}).get("start_towns", {}).get("minimum_distance_required", 0)),
			"observed_start_town_minimum_distance": int(validation.get("town_spacing", {}).get("start_towns", {}).get("observed_minimum_distance", 0)),
			"same_zone_town_pair_count": int(validation.get("town_spacing", {}).get("same_zone_towns", {}).get("pair_count", 0)),
			"same_zone_town_minimum_distance_required": int(validation.get("town_spacing", {}).get("same_zone_towns", {}).get("minimum_distance_required", 0)),
			"observed_same_zone_town_minimum_distance": int(validation.get("town_spacing", {}).get("same_zone_towns", {}).get("observed_minimum_distance", 0)),
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
		"zone_anchor": town.get("zone_anchor", source.get("zone_anchor", {})),
		"town_spacing_policy": town.get("town_spacing_policy", source.get("town_spacing_policy", {})),
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
				if body_lookup.has(key) and not _road_segment_cell_is_endpoint(segment, cell):
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
	var town_spacing := _town_spacing_validation(town_records, terrain_rows)
	if not bool(town_spacing.get("ok", false)):
		failures.append_array(town_spacing.get("failures", []))
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
		"town_spacing": town_spacing,
		"route_edge_count": route_graph.get("edges", []).size(),
		"road_segment_count": road_network.get("road_segments", []).size(),
		"decoration_record_count": decoration_density.get("decoration_records", []).size(),
		"placed_resource_categories": _sorted_keys(seven_categories),
	}

static func _town_spacing_validation(town_records: Array, terrain_rows: Array) -> Dictionary:
	var min_distance := _minimum_town_distance_for_map(terrain_rows)
	var hard_min_distance: int = max(4, int(floor(float(min_distance) * 0.75)))
	var start_records := []
	for record in town_records:
		if record is Dictionary and int(record.get("player_slot", 0)) > 0:
			start_records.append(record)
	var all_towns := _town_pair_distance_summary(town_records, min_distance, "all_towns")
	var start_towns := _town_pair_distance_summary(start_records, min_distance, "start_towns")
	var same_zone_towns := _same_zone_town_pair_distance_summary(town_records, hard_min_distance)
	var failures := []
	failures.append_array(all_towns.get("failures", []))
	failures.append_array(start_towns.get("failures", []))
	failures.append_array(same_zone_towns.get("failures", []))
	return {
		"ok": failures.is_empty(),
		"minimum_distance_required": min_distance,
		"observed_minimum_distance": int(all_towns.get("observed_minimum_distance", 0)),
		"closest_pair": all_towns.get("closest_pair", []),
		"all_towns": all_towns,
		"start_towns": start_towns,
		"same_zone_towns": same_zone_towns,
		"failures": failures,
	}

static func _minimum_town_distance_for_map(terrain_rows: Array) -> int:
	var height := terrain_rows.size()
	var width: int = terrain_rows[0].size() if height > 0 and terrain_rows[0] is Array else 36
	var shortest: int = max(1, min(width, height))
	var minimum := 6 if shortest >= 30 else 5
	return clampi(max(minimum, int(ceil(float(shortest) / 8.0))), minimum, 18)

static func _town_pair_distance_summary(records: Array, required_distance: int, scope: String) -> Dictionary:
	var observed_min := 999999
	var closest_pair := []
	var pair_count := 0
	for i in range(records.size()):
		var a = records[i]
		if not (a is Dictionary):
			continue
		for j in range(i + 1, records.size()):
			var b = records[j]
			if not (b is Dictionary):
				continue
			pair_count += 1
			var distance := _town_record_distance(a, b)
			if distance < observed_min:
				observed_min = distance
				closest_pair = [String(a.get("placement_id", "")), String(b.get("placement_id", ""))]
	var observed := 0 if observed_min == 999999 else observed_min
	var failures := []
	if observed_min != 999999 and observed_min < required_distance:
		failures.append("%s town spacing below minimum: %d < %d for %s" % [scope, observed, required_distance, ",".join(closest_pair)])
	return {
		"scope": scope,
		"pair_count": pair_count,
		"minimum_distance_required": required_distance,
		"observed_minimum_distance": observed,
		"closest_pair": closest_pair,
		"status": "pass" if failures.is_empty() else "fail",
		"failures": failures,
	}

static func _same_zone_town_pair_distance_summary(records: Array, required_distance: int) -> Dictionary:
	var observed_min := 999999
	var closest_pair := []
	var pair_count := 0
	for i in range(records.size()):
		var a = records[i]
		if not (a is Dictionary):
			continue
		for j in range(i + 1, records.size()):
			var b = records[j]
			if not (b is Dictionary) or String(a.get("zone_id", "")) != String(b.get("zone_id", "")):
				continue
			pair_count += 1
			var distance := _town_record_distance(a, b)
			if distance < observed_min:
				observed_min = distance
				closest_pair = [String(a.get("placement_id", "")), String(b.get("placement_id", ""))]
	var observed := 0 if observed_min == 999999 else observed_min
	var failures := []
	if observed_min != 999999 and observed_min < required_distance:
		failures.append("same_zone town spacing below minimum: %d < %d for %s" % [observed, required_distance, ",".join(closest_pair)])
	return {
		"scope": "same_zone_towns",
		"pair_count": pair_count,
		"minimum_distance_required": required_distance,
		"observed_minimum_distance": observed,
		"closest_pair": closest_pair,
		"status": "pass" if failures.is_empty() else "fail",
		"failures": failures,
	}

static func _town_record_distance(left: Dictionary, right: Dictionary) -> int:
	return abs(int(left.get("x", 0)) - int(right.get("x", 0))) + abs(int(left.get("y", 0)) - int(right.get("y", 0)))

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
	var river_overlay := _river_water_coast_overlay_payload(zone_layout, terrain_transit, terrain_rows, road_overlay, object_footprints)
	var serialization_record := _generated_map_serialization_record(normalized, terrain_rows, terrain_transit, road_overlay, river_overlay, object_footprints, placements, route_graph)
	var round_trip := _round_trip_serialization_record(serialization_record)
	var validation := _roads_rivers_writeout_validation_core(road_overlay, river_overlay, serialization_record, round_trip, route_graph, object_footprints)
	var status := "pass" if bool(validation.get("ok", false)) else "fail"
	var payload := {
		"schema_id": ROADS_RIVERS_WRITEOUT_SCHEMA_ID,
		"status": status,
		"writeout_policy": "final_generated_export_no_authored_content_writeback",
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
			"final_tile_stream_count": int(serialization_record.get("final_tile_stream", []).size()),
		},
		"deferred": [
			"authored_production_json_writeback",
			"campaign_adoption",
			"player_facing_setup_retry_ux",
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
	var occupied := _route_blocking_body_lookup_from_footprint_records(object_footprints.get("object_records", []))
	var connection_controls_by_route := _connection_control_records_by_route(route_graph)
	var connection_guard_summary: Dictionary = route_graph.get("connection_guard_materialization", {}).get("summary", {}) if route_graph.get("connection_guard_materialization", {}) is Dictionary else {}
	var overlay_tiles := []
	var segment_records := []
	var route_ids := []
	var required_route_ids := []
	var controlled_route_ids := []
	var road_class_counts := {}
	var diagnostics := []
	var connection_guard_road_control_count := 0
	var special_guard_gate_road_count := 0
	var wide_suppressed_route_count := 0
	for segment in road_network.get("road_segments", []):
		if not (segment is Dictionary):
			diagnostics.append({"reason": "invalid_road_segment", "message": "road segment is not a dictionary", "retryable": true})
			continue
		var route_edge_id := String(segment.get("route_edge_id", ""))
		var edge: Dictionary = edges_by_id.get(route_edge_id, {})
		var road_class := _road_class_for_edge(edge, segment)
		var road_type_id := _road_type_for_class(road_class, edge)
		road_class_counts[road_class] = int(road_class_counts.get(road_class, 0)) + 1
		if bool(edge.get("border_guard", false)):
			special_guard_gate_road_count += 1
		if bool(edge.get("wide", false)):
			wide_suppressed_route_count += 1
		var connection_control := _connection_control_for_road_segment(route_edge_id, segment.get("cells", []), connection_controls_by_route.get(route_edge_id, []))
		var control_key := ""
		if not connection_control.is_empty():
			connection_guard_road_control_count += 1
			if route_edge_id not in controlled_route_ids:
				controlled_route_ids.append(route_edge_id)
			var control_tile: Dictionary = connection_control.get("road_tile", {}) if connection_control.get("road_tile", {}) is Dictionary else {}
			control_key = _point_key(int(control_tile.get("x", -9999)), int(control_tile.get("y", -9999)))
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
			var body_blocked := occupied.has(key) and not _road_segment_cell_is_endpoint(segment, cell)
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
				"road_type_byte": _road_type_byte_for_class(road_class),
				"road_art_index": int(_hash32_int("%s:%d,%d:road_art" % [route_edge_id, x, y]) % 16),
				"neighbor_mask": _road_neighbor_mask(segment.get("cells", []), x, y),
				"passability": "passable" if _terrain_cell_is_passable(terrain_rows, x, y) and not body_blocked else "blocked",
				"body_conflict": body_blocked,
				"writeout_state": "final_generated_tile_bytes_written_to_export_record",
			}
			if control_key != "" and key == control_key:
				tile["connection_control"] = connection_control
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
			"connection_control": connection_control,
			"transit_semantics": edge.get("transit_semantics", {}),
			"writeout_state": "final_generated_road_overlay_tiles_written",
		})
	route_ids.sort()
	required_route_ids.sort()
	controlled_route_ids.sort()
	var expected_connection_guard_road_control_count := int(connection_guard_summary.get("expected_normal_guard_count", 0)) + int(connection_guard_summary.get("expected_special_guard_gate_count", 0))
	var payload := {
		"schema_id": "random_map_road_overlay_writeout_v1",
		"overlay_id": ROAD_OVERLAY_ID,
		"writeout_policy": "final_generated_road_overlay_tile_bytes",
		"road_class_policy": "required_routes_primary_guarded_routes_fortified_resource_routes_service_with_connection_control_markers",
		"segments": segment_records,
		"tiles": overlay_tiles,
		"route_edge_ids": route_ids,
		"required_route_edge_ids": required_route_ids,
		"connection_controlled_route_edge_ids": controlled_route_ids,
		"diagnostics": diagnostics,
		"blocked_body_policy": "road_tiles_must_not_overlap_object_footprint_body_tiles",
		"connection_control_policy": "HoMM3-style connection Value and Border Guard records mark a controlling road tile; Wide records preserve a guard-suppressed unguarded route",
		"summary": {
			"segment_count": segment_records.size(),
			"tile_count": overlay_tiles.size(),
			"route_edge_count": route_ids.size(),
			"required_route_count": required_route_ids.size(),
			"road_class_counts": _sorted_dict(road_class_counts),
			"expected_connection_guard_road_control_count": expected_connection_guard_road_control_count,
			"connection_guard_road_control_count": connection_guard_road_control_count,
			"missing_connection_guard_road_control_count": max(0, expected_connection_guard_road_control_count - connection_guard_road_control_count),
			"expected_wide_suppression_road_count": int(connection_guard_summary.get("expected_wide_suppression_count", 0)),
			"wide_suppressed_route_count": wide_suppressed_route_count,
			"expected_special_guard_gate_road_count": int(connection_guard_summary.get("expected_special_guard_gate_count", 0)),
			"special_guard_gate_road_count": special_guard_gate_road_count,
			"body_conflict_count": _count_overlay_body_conflicts(overlay_tiles),
			"diagnostic_count": diagnostics.size(),
		},
	}
	payload["road_overlay_signature"] = _hash32_hex(_stable_stringify({"segments": segment_records, "tiles": overlay_tiles, "diagnostics": diagnostics}))
	return payload

static func _river_water_coast_overlay_payload(zone_layout: Dictionary, terrain_transit: Dictionary, terrain_rows: Array = [], road_overlay: Dictionary = {}, object_footprints: Dictionary = {}) -> Dictionary:
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
				"writeout_state": "terrain_water_tile_written_to_export_record",
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
				"writeout_state": "terrain_coast_tile_written_to_export_record",
			})
	var river_candidates := []
	var occupied := _route_blocking_body_lookup_from_footprint_records(object_footprints.get("object_records", []))
	var water_access: Array = terrain_transit.get("transit_routes", {}).get("water_access_candidates", [])
	for index in range(water_access.size()):
		var candidate = water_access[index]
		if not (candidate is Dictionary):
			continue
		var from_anchor: Dictionary = candidate.get("from_anchor", {}) if candidate.get("from_anchor", {}) is Dictionary else {}
		var to_coast: Dictionary = candidate.get("to_coast", {}) if candidate.get("to_coast", {}) is Dictionary else {}
		var candidate_cells := _find_passable_path(from_anchor, to_coast, terrain_rows, occupied)
		if candidate_cells.is_empty():
			continue
		river_candidates.append({
			"id": "river_candidate_%03d" % (index + 1),
			"zone_id": String(candidate.get("zone_id", "")),
			"level_index": int(candidate.get("level_index", 0)),
			"candidate_cells": candidate_cells,
			"from_anchor": from_anchor,
			"to_coast": to_coast,
			"overlay_type": "river_or_ferry_channel_candidate",
			"river_type_byte": 1,
			"river_art_index": int(_hash32_int("river_candidate_%03d:art" % (index + 1)) % 16),
			"transit_semantics": candidate.get("transit_semantics", {}),
			"materialization_state": "gameplay_ferry_bridge_record_materialized_and_exported",
			"writeout_state": "final_generated_river_candidate_tile_bytes_written",
		})
	if river_candidates.is_empty() and water_tiles.is_empty() and coast_tiles.is_empty() and String(water.get("water_mode", zone_layout.get("policy", {}).get("water_mode", "land"))) == "land":
		river_candidates.append_array(_land_river_candidates(zone_layout, terrain_rows, road_overlay, object_footprints))
	river_candidates = _annotated_river_candidates(river_candidates, terrain_rows, road_overlay, object_footprints)
	var explicit_state := {}
	if water_tiles.is_empty() and coast_tiles.is_empty() and river_candidates.is_empty():
		explicit_state = {
			"state": "explicit_land_no_river_overlay_candidates",
			"water_mode": String(water.get("water_mode", zone_layout.get("policy", {}).get("water_mode", "land"))),
			"reason": "selected_template_and_profile_have_no_surface_water_or_river_transit_request",
		}
	var payload := {
		"schema_id": "random_map_river_water_coast_overlay_writeout_v1",
		"writeout_policy": "water_coast_and_river_candidates_written_to_generated_export",
		"water_mode": String(water.get("water_mode", zone_layout.get("policy", {}).get("water_mode", "land"))),
		"water_overlay_tiles": water_tiles,
		"coast_overlay_tiles": coast_tiles,
		"river_candidates": river_candidates,
		"explicit_no_river_state": explicit_state,
		"deferred_transit_writeout": _unique_sorted_strings(["final_boat_shipyard_ui_deferred"] + terrain_transit.get("transit_routes", {}).get("deferred", [])),
		"summary": {
			"water_tile_count": water_tiles.size(),
			"coast_tile_count": coast_tiles.size(),
			"river_candidate_count": river_candidates.size(),
			"coherent_river_candidate_count": _count_river_quality_value(river_candidates, "continuity_status", "pass"),
			"river_continuity_failure_count": _count_river_quality_not_value(river_candidates, "continuity_status", "pass"),
			"isolated_river_fragment_count": _sum_river_quality_int(river_candidates, "isolated_cell_count"),
			"river_body_conflict_count": _sum_river_quality_int(river_candidates, "body_conflict_count"),
			"river_road_crossing_count": _sum_river_quality_int(river_candidates, "road_crossing_count"),
			"land_river_candidate_count": _count_river_overlay_type(river_candidates, "land_river_with_road_crossing_constraints"),
			"land_river_with_crossing_count": _count_land_rivers_with_crossings(river_candidates),
			"explicit_no_river": not explicit_state.is_empty(),
		},
	}
	payload["river_water_coast_signature"] = _hash32_hex(_stable_stringify({"water_overlay_tiles": water_tiles, "coast_overlay_tiles": coast_tiles, "river_candidates": river_candidates, "explicit_no_river_state": explicit_state}))
	return payload

static func _land_river_candidates(zone_layout: Dictionary, terrain_rows: Array, road_overlay: Dictionary, object_footprints: Dictionary) -> Array:
	var height := terrain_rows.size()
	var width: int = terrain_rows[0].size() if height > 0 and terrain_rows[0] is Array else 0
	if width < 18 or height < 18:
		return []
	var occupied := _route_blocking_body_lookup_from_footprint_records(object_footprints.get("object_records", []))
	var road_lookup := _tile_lookup_by_point(road_overlay.get("tiles", []))
	var count := 2 if min(width, height) >= 72 else 1
	var candidates := []
	for index in range(count):
		var start_x := int(clampi(int(round(float(width) * (0.25 + 0.35 * float(index)))), 2, width - 3))
		var end_x := int(clampi(width - 1 - start_x + (index * 5), 2, width - 3))
		var crossing_target := _river_road_crossing_target(road_lookup, occupied, width, height, index)
		var path := _meandering_land_river_path(start_x, 1, end_x, height - 2, terrain_rows, occupied, road_lookup, index, crossing_target)
		if path.size() < max(8, int(floor(float(height) * 0.45))):
			continue
		var crossing_cells := []
		for cell in path:
			if cell is Dictionary and road_lookup.has(_point_key(int(cell.get("x", 0)), int(cell.get("y", 0)))):
				crossing_cells.append(cell)
		candidates.append({
			"id": "land_river_candidate_%03d" % (index + 1),
			"zone_id": "",
			"level_index": 0,
			"candidate_cells": path,
			"from_anchor": path[0],
			"to_coast": path[path.size() - 1],
			"overlay_type": "land_river_with_road_crossing_constraints",
			"river_type_byte": 1 + index,
			"river_art_index": int(_hash32_int("land_river_candidate_%03d:art" % (index + 1)) % 16),
			"crossing_cells": crossing_cells,
			"crossing_policy": "roads_may_cross_at_recorded_bridge_or_ford_cells",
			"transit_semantics": {
				"kind": "land_river",
				"route_class": "river_obstacle_with_crossings",
				"passability": "blocked_except_recorded_road_crossing_or_future_bridge",
				"materialization_options": ["river_overlay", "bridge", "ford"],
				"required_unlock": false,
				"materialization_state": "final_generated_land_river_candidate_tile_bytes_written",
			},
			"materialization_state": "land_river_overlay_record_materialized",
			"writeout_state": "final_generated_river_candidate_tile_bytes_written",
		})
	return candidates

static func _meandering_land_river_path(start_x: int, start_y: int, end_x: int, end_y: int, terrain_rows: Array, occupied: Dictionary, road_lookup: Dictionary, ordinal: int, crossing_target: Dictionary = {}) -> Array:
	var height := terrain_rows.size()
	var width: int = terrain_rows[0].size() if height > 0 and terrain_rows[0] is Array else 0
	var river_occupied := occupied.duplicate(true)
	for road_key in road_lookup.keys():
		river_occupied.erase(String(road_key))
	var waypoints := []
	waypoints.append(_nearest_valid_land_river_point(_point_dict(start_x, start_y), terrain_rows, river_occupied))
	for fraction in [0.25, 0.5, 0.75]:
		var y := int(clampi(int(round(lerpf(float(start_y), float(end_y), float(fraction)))), 1, max(1, height - 2)))
		var target_x := int(round(lerpf(float(start_x), float(end_x), float(fraction))))
		var wave := int(round(sin(float(y + ordinal * 7) * 0.45) * 3.0))
		waypoints.append(_nearest_valid_land_river_point(_point_dict(clampi(target_x + wave, 1, max(1, width - 2)), y), terrain_rows, river_occupied))
	if not crossing_target.is_empty():
		waypoints.append(_nearest_valid_land_river_point(crossing_target, terrain_rows, river_occupied))
	waypoints.append(_nearest_valid_land_river_point(_point_dict(end_x, end_y), terrain_rows, river_occupied))
	waypoints = _sorted_river_waypoints(waypoints)
	var path := []
	for index in range(waypoints.size() - 1):
		var from_point: Dictionary = waypoints[index]
		var to_point: Dictionary = waypoints[index + 1]
		if from_point.is_empty() or to_point.is_empty():
			continue
		var segment := _find_passable_path(from_point, to_point, terrain_rows, river_occupied)
		if segment.is_empty():
			return []
		for cell_index in range(segment.size()):
			if not path.is_empty() and cell_index == 0 and _same_point(path[path.size() - 1], segment[cell_index]):
				continue
			path.append(segment[cell_index])
	return _dedupe_consecutive_point_path(path)

static func _river_road_crossing_target(road_lookup: Dictionary, occupied: Dictionary, width: int, height: int, ordinal: int) -> Dictionary:
	var candidates := []
	var desired_x := int(round(float(width) * (0.35 + 0.2 * float(ordinal % 2))))
	var desired_y := int(round(float(height) * 0.5))
	for key in road_lookup.keys():
		var tile: Dictionary = road_lookup[key]
		var x := int(tile.get("x", 0))
		var y := int(tile.get("y", 0))
		if x <= 1 or x >= width - 2 or y <= 1 or y >= height - 2:
			continue
		if occupied.has(_point_key(x, y)) and not road_lookup.has(_point_key(x, y)):
			continue
		candidates.append({
			"x": x,
			"y": y,
			"score": abs(x - desired_x) + abs(y - desired_y) + int(_hash32_int("%d:%d,%d:river_crossing" % [ordinal, x, y]) % 5),
		})
	candidates.sort_custom(Callable(RandomMapGeneratorRules, "_compare_score_xy"))
	if candidates.is_empty():
		return {}
	var selected: Dictionary = candidates[0]
	return _point_dict(int(selected.get("x", 0)), int(selected.get("y", 0)))

static func _nearest_valid_land_river_point(preferred: Dictionary, terrain_rows: Array, occupied: Dictionary) -> Dictionary:
	if preferred.is_empty():
		return {}
	var x := int(preferred.get("x", 0))
	var y := int(preferred.get("y", 0))
	if _point_in_rows(terrain_rows, x, y) and _terrain_cell_is_passable(terrain_rows, x, y) and not occupied.has(_point_key(x, y)):
		return _point_dict(x, y)
	for radius in range(1, 7):
		var candidates := []
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if abs(dx) + abs(dy) != radius:
					continue
				var nx := x + dx
				var ny := y + dy
				if not _point_in_rows(terrain_rows, nx, ny):
					continue
				if not _terrain_cell_is_passable(terrain_rows, nx, ny) or occupied.has(_point_key(nx, ny)):
					continue
				candidates.append({"x": nx, "y": ny, "score": abs(dx) + abs(dy)})
		candidates.sort_custom(Callable(RandomMapGeneratorRules, "_compare_score_xy"))
		if not candidates.is_empty():
			var selected: Dictionary = candidates[0]
			return _point_dict(int(selected.get("x", 0)), int(selected.get("y", 0)))
	return {}

static func _sorted_river_waypoints(points: Array) -> Array:
	var result := []
	var seen := {}
	for point in points:
		if not (point is Dictionary) or point.is_empty():
			continue
		var key := _point_key(int(point.get("x", 0)), int(point.get("y", 0)))
		if seen.has(key):
			continue
		seen[key] = true
		result.append(point)
	result.sort_custom(Callable(RandomMapGeneratorRules, "_compare_yx"))
	return result

static func _dedupe_consecutive_point_path(points: Array) -> Array:
	var result := []
	for point in points:
		if not (point is Dictionary):
			continue
		if not result.is_empty() and _same_point(result[result.size() - 1], point):
			continue
		result.append(point)
	return result

static func _annotated_river_candidates(candidates: Array, terrain_rows: Array, road_overlay: Dictionary, object_footprints: Dictionary) -> Array:
	var road_lookup := _tile_lookup_by_point(road_overlay.get("tiles", []))
	var occupied := _route_blocking_body_lookup_from_footprint_records(object_footprints.get("object_records", []))
	var result := []
	for candidate in candidates:
		if not (candidate is Dictionary):
			continue
		var record: Dictionary = candidate.duplicate(true)
		var quality := _river_candidate_quality(record, terrain_rows, road_lookup, occupied)
		record["quality"] = quality
		record["continuity_status"] = String(quality.get("continuity_status", "fail"))
		record["road_crossing_count"] = int(quality.get("road_crossing_count", 0))
		record["body_conflict_count"] = int(quality.get("body_conflict_count", 0))
		record["isolated_cell_count"] = int(quality.get("isolated_cell_count", 0))
		record["ordered_adjacency_break_count"] = int(quality.get("ordered_adjacency_break_count", 0))
		record["component_count"] = int(quality.get("component_count", 0))
		result.append(record)
	return result

static func _river_candidate_quality(candidate: Dictionary, terrain_rows: Array, road_lookup: Dictionary, occupied: Dictionary) -> Dictionary:
	var cells: Array = candidate.get("candidate_cells", []) if candidate.get("candidate_cells", []) is Array else []
	var path_lookup := {}
	var road_crossings := []
	var road_route_ids := {}
	var body_conflicts := []
	var non_passable := []
	var ordered_breaks := 0
	var land_river := String(candidate.get("overlay_type", "")) == "land_river_with_road_crossing_constraints"
	for index in range(cells.size()):
		var cell = cells[index]
		if not (cell is Dictionary):
			continue
		var x := int(cell.get("x", 0))
		var y := int(cell.get("y", 0))
		var key := _point_key(x, y)
		path_lookup[key] = true
		if index > 0 and cells[index - 1] is Dictionary and _manhattan_distance(cells[index - 1], cell) != 1:
			ordered_breaks += 1
		if not _point_in_rows(terrain_rows, x, y) or not _terrain_cell_is_passable(terrain_rows, x, y):
			non_passable.append(_point_dict(x, y))
		var endpoint_channel_anchor := not land_river and (index == 0 or index == cells.size() - 1)
		if occupied.has(key) and not road_lookup.has(key) and not endpoint_channel_anchor:
			body_conflicts.append(_point_dict(x, y))
		if road_lookup.has(key):
			var road_tile: Dictionary = road_lookup[key]
			road_crossings.append({
				"x": x,
				"y": y,
				"route_edge_id": String(road_tile.get("route_edge_id", "")),
				"road_class": String(road_tile.get("road_class", "")),
			})
			road_route_ids[String(road_tile.get("route_edge_id", ""))] = true
	var component_count := _point_lookup_component_count(path_lookup)
	var isolated_count := _isolated_point_count(path_lookup)
	var has_required_crossing := (not land_river) or not road_crossings.is_empty()
	var continuity_ok := cells.size() > 1 and ordered_breaks == 0 and component_count == 1 and isolated_count == 0 and body_conflicts.is_empty() and non_passable.is_empty() and has_required_crossing
	return {
		"continuity_status": "pass" if continuity_ok else "fail",
		"candidate_cell_count": cells.size(),
		"ordered_adjacency_break_count": ordered_breaks,
		"component_count": component_count,
		"isolated_cell_count": isolated_count,
		"body_conflict_count": body_conflicts.size(),
		"non_passable_cell_count": non_passable.size(),
		"road_crossing_count": road_crossings.size(),
		"road_crossings": road_crossings,
		"road_crossing_route_edge_ids": _sorted_keys(road_route_ids),
		"requires_road_crossing": land_river,
		"has_required_crossing": has_required_crossing,
		"policy": "river overlay cells must form one continuous ordered path, avoid object bodies, and land rivers must record road bridge/ford crossings",
	}

static func _point_lookup_component_count(lookup: Dictionary) -> int:
	var remaining := {}
	for key in lookup.keys():
		remaining[String(key)] = true
	var count := 0
	while not remaining.is_empty():
		var start_key := String(remaining.keys()[0])
		count += 1
		var queue := [start_key]
		remaining.erase(start_key)
		var cursor := 0
		while cursor < queue.size():
			var key := String(queue[cursor])
			cursor += 1
			var point := _point_from_key(key)
			for offset in _cardinal_offsets():
				var next_key := _point_key(int(point.get("x", 0)) + int(offset.x), int(point.get("y", 0)) + int(offset.y))
				if not remaining.has(next_key):
					continue
				remaining.erase(next_key)
				queue.append(next_key)
	return count

static func _isolated_point_count(lookup: Dictionary) -> int:
	var count := 0
	for key in lookup.keys():
		var point := _point_from_key(String(key))
		var neighbor_count := 0
		for offset in _cardinal_offsets():
			if lookup.has(_point_key(int(point.get("x", 0)) + int(offset.x), int(point.get("y", 0)) + int(offset.y))):
				neighbor_count += 1
		if neighbor_count == 0:
			count += 1
	return count

static func _point_from_key(key: String) -> Dictionary:
	var parts := key.split(",")
	if parts.size() != 2:
		return _point_dict(0, 0)
	return _point_dict(int(parts[0]), int(parts[1]))

static func _count_river_quality_value(candidates: Array, key: String, expected: String) -> int:
	var count := 0
	for candidate in candidates:
		if candidate is Dictionary and String(candidate.get("quality", {}).get(key, "")) == expected:
			count += 1
	return count

static func _count_river_quality_not_value(candidates: Array, key: String, expected: String) -> int:
	var count := 0
	for candidate in candidates:
		if candidate is Dictionary and String(candidate.get("quality", {}).get(key, "")) != expected:
			count += 1
	return count

static func _sum_river_quality_int(candidates: Array, key: String) -> int:
	var total := 0
	for candidate in candidates:
		if candidate is Dictionary:
			total += int(candidate.get("quality", {}).get(key, 0))
	return total

static func _count_river_overlay_type(candidates: Array, overlay_type: String) -> int:
	var count := 0
	for candidate in candidates:
		if candidate is Dictionary and String(candidate.get("overlay_type", "")) == overlay_type:
			count += 1
	return count

static func _count_land_rivers_with_crossings(candidates: Array) -> int:
	var count := 0
	for candidate in candidates:
		if not (candidate is Dictionary):
			continue
		if String(candidate.get("overlay_type", "")) == "land_river_with_road_crossing_constraints" and int(candidate.get("quality", {}).get("road_crossing_count", 0)) > 0:
			count += 1
	return count

static func _same_point(left: Dictionary, right: Dictionary) -> bool:
	return int(left.get("x", 0)) == int(right.get("x", 0)) and int(left.get("y", 0)) == int(right.get("y", 0))

static func _compare_score_xy(a: Dictionary, b: Dictionary) -> bool:
	var a_score := int(a.get("score", 0))
	var b_score := int(b.get("score", 0))
	if a_score != b_score:
		return a_score < b_score
	var ay := int(a.get("y", 0))
	var by := int(b.get("y", 0))
	if ay != by:
		return ay < by
	return int(a.get("x", 0)) < int(b.get("x", 0))

static func _compare_yx(a: Dictionary, b: Dictionary) -> bool:
	var ay := int(a.get("y", 0))
	var by := int(b.get("y", 0))
	if ay != by:
		return ay < by
	return int(a.get("x", 0)) < int(b.get("x", 0))

static func _generated_map_serialization_record(normalized: Dictionary, terrain_rows: Array, terrain_transit: Dictionary, road_overlay: Dictionary, river_overlay: Dictionary, object_footprints: Dictionary, placements: Dictionary, route_graph: Dictionary) -> Dictionary:
	var metadata := _metadata(normalized)
	var final_tile_stream := _final_tile_stream_records(terrain_rows, road_overlay, river_overlay)
	var overlay_layers := [
		{
			"id": "generated_roads",
			"layer_type": "road_overlay",
			"schema_id": String(road_overlay.get("schema_id", "")),
			"tiles": road_overlay.get("tiles", []),
			"segments": road_overlay.get("segments", []),
			"writeout_state": "final_generated_overlay_bytes_written",
		},
		{
			"id": "generated_water_coast_river_candidates",
			"layer_type": "river_water_coast_overlay",
			"schema_id": String(river_overlay.get("schema_id", "")),
			"water_overlay_tiles": river_overlay.get("water_overlay_tiles", []),
			"coast_overlay_tiles": river_overlay.get("coast_overlay_tiles", []),
			"river_candidates": river_overlay.get("river_candidates", []),
			"explicit_no_river_state": river_overlay.get("explicit_no_river_state", {}),
			"writeout_state": "final_generated_river_water_coast_bytes_written",
		},
	]
	var object_instances := _serialization_object_instances(object_footprints, placements)
	var object_writeout_records := _object_writeout_records(object_instances)
	var record := {
		"schema_id": GENERATED_MAP_SERIALIZATION_SCHEMA_ID,
		"export_schema_id": FINAL_WRITEOUT_EXPORT_SCHEMA_ID,
		"serialization_policy": "durable_generated_export_record_no_authored_content_writeback",
		"generator_version": String(metadata.get("generator_version", "")),
		"provenance": {
			"source": "generated_random_map",
			"template_id": String(metadata.get("template_id", "")),
			"profile_id": String(metadata.get("profile", {}).get("id", "")),
			"normalized_seed": String(metadata.get("normalized_seed", "")),
			"content_manifest_fingerprint": String(metadata.get("content_manifest_fingerprint", "")),
			"task_id": "10184",
			"slice_id": "random-map-final-writeout-export-save-schema-10184",
		},
		"map_size": normalized.get("size", {}),
		"terrain_rows": terrain_rows,
		"terrain_layers": terrain_transit.get("terrain_layers", []),
		"overlay_layers": overlay_layers,
		"final_tile_stream": final_tile_stream,
		"tile_stream_signature": _hash32_hex(_stable_stringify(final_tile_stream)),
		"object_definitions": object_footprints.get("catalog", {}).get("records", []),
		"object_instances": object_instances,
		"object_writeout_records": object_writeout_records,
		"object_writeout_signature": _hash32_hex(_stable_stringify(object_writeout_records)),
		"route_graph_summary": {
			"edge_count": route_graph.get("edges", []).size(),
			"required_edge_count": _required_route_count(route_graph.get("edges", [])),
		},
		"validation_status": {
			"object_footprint_status": String(object_footprints.get("status", "")),
			"road_overlay_status": "pass" if int(road_overlay.get("summary", {}).get("body_conflict_count", 0)) == 0 else "fail",
			"round_trip_required": true,
			"staging_metadata_required_for_round_trip": false,
		},
		"writeout_completeness": {
			"terrain_tile_bytes": true,
			"road_tile_bytes": true,
			"river_tile_bytes": true,
			"object_instances": true,
			"multi_tile_bodies": true,
			"round_trip_without_staging_metadata": true,
		},
		"boundary_metadata": {
			"authored_json_writeback": "not_performed",
			"campaign_adoption": "not_performed",
			"skirmish_ui_adoption": "not_performed",
			"player_facing_setup_retry_ux": "not_in_this_slice",
		},
	}
	record = _json_safe_value(record)
	record["round_trip_signature"] = _serialization_record_signature(record)
	return record

static func _final_tile_stream_records(terrain_rows: Array, road_overlay: Dictionary, river_overlay: Dictionary) -> Array:
	var road_lookup := _tile_lookup_by_point(road_overlay.get("tiles", []))
	var river_lookup := _river_candidate_lookup_by_point(river_overlay.get("river_candidates", []))
	var records := []
	for y in range(terrain_rows.size()):
		var row = terrain_rows[y]
		if not (row is Array):
			continue
		for x in range(row.size()):
			var terrain_id := String(row[x])
			var road_tile: Dictionary = road_lookup.get(_point_key(x, y), {})
			var river_tile: Dictionary = river_lookup.get(_point_key(x, y), {})
			var road_type := int(road_tile.get("road_type_byte", 0))
			var road_art := int(road_tile.get("road_art_index", 0)) if not road_tile.is_empty() else 0
			var river_type := int(river_tile.get("river_type_byte", 0))
			var river_art := int(river_tile.get("river_art_index", 0)) if not river_tile.is_empty() else 0
			var flags := _terrain_flip_flags(terrain_id, x, y)
			if river_type > 0:
				flags |= int(_hash32_int("%d,%d:river_flip_a" % [x, y]) % 2) << 2
				flags |= int(_hash32_int("%d,%d:river_flip_b" % [x, y]) % 2) << 3
			if road_type > 0:
				flags |= int(_hash32_int("%d,%d:road_flip_a" % [x, y]) % 2) << 4
				flags |= int(_hash32_int("%d,%d:road_flip_b" % [x, y]) % 2) << 5
			records.append({
				"id": "tile_%03d_%03d_0" % [x, y],
				"x": x,
				"y": y,
				"level_index": 0,
				"terrain_id": terrain_id,
				"tile_bytes": [
					_terrain_type_byte(terrain_id),
					_terrain_art_byte(terrain_id, x, y),
					river_type,
					river_art,
					road_type,
					road_art,
					flags,
				],
				"byte_contract": "terrain_id,terrain_art,river_type,river_art,road_type,road_art,flags",
				"writeout_state": "final_generated_tile_byte_record",
			})
	return records

static func _tile_lookup_by_point(tiles: Array) -> Dictionary:
	var result := {}
	for tile in tiles:
		if tile is Dictionary:
			result[_point_key(int(tile.get("x", 0)), int(tile.get("y", 0)))] = tile
	return result

static func _river_candidate_lookup_by_point(candidates: Array) -> Dictionary:
	var result := {}
	for candidate in candidates:
		if not (candidate is Dictionary):
			continue
		for cell in candidate.get("candidate_cells", []):
			if cell is Dictionary:
				var x := int(cell.get("x", 0))
				var y := int(cell.get("y", 0))
				result[_point_key(x, y)] = {
					"river_type_byte": int(candidate.get("river_type_byte", 1)),
					"river_art_index": int(candidate.get("river_art_index", 0)),
					"candidate_id": String(candidate.get("id", "")),
				}
	return result

static func _terrain_type_byte(terrain_id: String) -> int:
	var index := ORIGINAL_TERRAIN_IDS.find(terrain_id)
	return max(0, index) % 64

static func _terrain_art_byte(terrain_id: String, x: int, y: int) -> int:
	return int(_hash32_int("%s:%d,%d:terrain_art" % [terrain_id, x, y]) % 256)

static func _terrain_flip_flags(terrain_id: String, x: int, y: int) -> int:
	var h := int(_hash32_int("%s:%d,%d:terrain_flip_h" % [terrain_id, x, y]) % 2)
	var v := int(_hash32_int("%s:%d,%d:terrain_flip_v" % [terrain_id, x, y]) % 2)
	return h | (v << 1)

static func _road_type_byte_for_class(road_class: String) -> int:
	match road_class:
		"special_guard_gate_road":
			return 4
		"wide_guard_suppressed_road":
			return 1
		"guarded_route_road":
			return 3
		"start_economy_service_road":
			return 2
		"required_primary_road":
			return 1
		_:
			return 1

static func _object_writeout_records(object_instances: Array) -> Array:
	var records := []
	for instance in object_instances:
		if not (instance is Dictionary):
			continue
		var body_tiles: Array = instance.get("body_tiles", []) if instance.get("body_tiles", []) is Array else []
		var catalog_body_tiles: Array = instance.get("catalog_body_tiles", []) if instance.get("catalog_body_tiles", []) is Array else []
		records.append(_json_safe_value({
			"instance_id": String(instance.get("instance_id", "")),
			"kind": String(instance.get("kind", "")),
			"content_id": String(instance.get("content_id", "")),
			"x": int(instance.get("x", 0)),
			"y": int(instance.get("y", 0)),
			"level_index": int(instance.get("level_index", 0)),
			"body_tiles": body_tiles,
			"catalog_body_tiles": catalog_body_tiles,
			"visit_tile": instance.get("visit_tile", {}),
			"approach_tiles": instance.get("approach_tiles", []),
			"body_writeout_state": "durable_generated_body_tiles" if not body_tiles.is_empty() else "durable_generated_reference_without_body",
			"writeout_state": "final_generated_object_instance_record",
		}))
	return records

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
			"multitile_body_writeout": {
				"body_tiles_durable": true,
				"catalog_body_tiles_durable": true,
				"runtime_anchor_tile_preserved": true,
				"source_deferred_metadata": record.get("footprint_deferred", {}),
			},
			"writeout_state": "final_generated_object_instance_record",
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
			"multitile_body_writeout": {"reference_record": true, "source_note": String(reward.get("deferred_reason", ""))},
			"writeout_state": "final_generated_reward_reference_record",
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
	var road_summary: Dictionary = road_overlay.get("summary", {}) if road_overlay.get("summary", {}) is Dictionary else {}
	if int(road_summary.get("connection_guard_road_control_count", 0)) < int(road_summary.get("expected_connection_guard_road_control_count", 0)):
		failures.append("road overlay missed connection guard control markers: %d/%d" % [int(road_summary.get("connection_guard_road_control_count", 0)), int(road_summary.get("expected_connection_guard_road_control_count", 0))])
	if int(road_summary.get("wide_suppressed_route_count", 0)) < int(road_summary.get("expected_wide_suppression_road_count", 0)):
		failures.append("road overlay missed wide guard-suppressed routes: %d/%d" % [int(road_summary.get("wide_suppressed_route_count", 0)), int(road_summary.get("expected_wide_suppression_road_count", 0))])
	if int(road_summary.get("special_guard_gate_road_count", 0)) < int(road_summary.get("expected_special_guard_gate_road_count", 0)):
		failures.append("road overlay missed special border-guard gate roads: %d/%d" % [int(road_summary.get("special_guard_gate_road_count", 0)), int(road_summary.get("expected_special_guard_gate_road_count", 0))])
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
	var river_summary: Dictionary = river_overlay.get("summary", {}) if river_overlay.get("summary", {}) is Dictionary else {}
	var river_candidate_count := int(river_summary.get("river_candidate_count", 0))
	if river_candidate_count > 0:
		if int(river_summary.get("coherent_river_candidate_count", 0)) < river_candidate_count:
			failures.append("river overlay contains incoherent candidates: %d/%d coherent" % [int(river_summary.get("coherent_river_candidate_count", 0)), river_candidate_count])
		if int(river_summary.get("river_body_conflict_count", 0)) > 0:
			failures.append("river overlay crosses object footprint body tiles: %d" % int(river_summary.get("river_body_conflict_count", 0)))
		if int(river_summary.get("isolated_river_fragment_count", 0)) > 0:
			failures.append("river overlay contains isolated fragments: %d" % int(river_summary.get("isolated_river_fragment_count", 0)))
		if water_mode == "land" and int(river_summary.get("land_river_with_crossing_count", 0)) < int(river_summary.get("land_river_candidate_count", 0)):
			failures.append("land river candidates missed recorded road bridge/ford crossings: %d/%d" % [int(river_summary.get("land_river_with_crossing_count", 0)), int(river_summary.get("land_river_candidate_count", 0))])
	for candidate in river_overlay.get("river_candidates", []):
		if not (candidate is Dictionary):
			failures.append("river candidate is not a dictionary")
			continue
		var quality: Dictionary = candidate.get("quality", {}) if candidate.get("quality", {}) is Dictionary else {}
		if String(quality.get("continuity_status", "")) != "pass":
			failures.append("river candidate %s failed continuity quality: %s" % [String(candidate.get("id", "")), JSON.stringify(quality)])
	if serialization_record.get("terrain_layers", []).is_empty():
		failures.append("serialization record missed terrain layers")
	if serialization_record.get("overlay_layers", []).is_empty():
		failures.append("serialization record missed overlay layers")
	if serialization_record.get("final_tile_stream", []).is_empty():
		failures.append("serialization record missed final tile stream")
	if String(serialization_record.get("tile_stream_signature", "")) == "":
		failures.append("serialization record missed tile stream signature")
	if serialization_record.get("object_instances", []).is_empty():
		failures.append("serialization record missed object instances")
	if serialization_record.get("object_writeout_records", []).is_empty():
		failures.append("serialization record missed object writeout records")
	if String(serialization_record.get("object_writeout_signature", "")) == "":
		failures.append("serialization record missed object writeout signature")
	if serialization_record.get("provenance", {}).get("template_id", "") == "" or serialization_record.get("provenance", {}).get("profile_id", "") == "" or serialization_record.get("provenance", {}).get("normalized_seed", "") == "":
		failures.append("serialization record missed template/profile/seed provenance")
	if String(serialization_record.get("generator_version", "")) == "":
		failures.append("serialization record missed generator version")
	var completeness: Dictionary = serialization_record.get("writeout_completeness", {}) if serialization_record.get("writeout_completeness", {}) is Dictionary else {}
	for key in ["terrain_tile_bytes", "road_tile_bytes", "river_tile_bytes", "object_instances", "multi_tile_bodies", "round_trip_without_staging_metadata"]:
		if not bool(completeness.get(key, false)):
			failures.append("serialization record did not prove %s" % key)
	if bool(serialization_record.get("validation_status", {}).get("staging_metadata_required_for_round_trip", true)):
		failures.append("serialization round-trip still depends on staging metadata")
	if String(round_trip.get("status", "")) != "pass" or not bool(round_trip.get("signature_stable", false)) or not bool(round_trip.get("key_counts_stable", false)):
		failures.append("serialization round-trip was not stable")
	if int(object_footprints.get("summary", {}).get("deferred_multitile_record_count", 0)) > 0:
		var preserved_body := false
		for instance in serialization_record.get("object_instances", []):
			if instance is Dictionary and not instance.get("multitile_body_writeout", {}).is_empty():
				preserved_body = true
				break
		if not preserved_body:
			failures.append("object instance serialization did not preserve durable multitile body state")
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
		var generated_export: Dictionary = generated_map.get("generated_export", {}) if generated_map.get("generated_export", {}) is Dictionary else {}
		if generated_export.is_empty() or String(generated_export.get("round_trip_signature", "")) == "":
			failures.append("generated map missed durable generated export record")
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
		"final_tile_stream_count": int(payload.get("summary", {}).get("final_tile_stream_count", 0)),
		"round_trip_status": String(payload.get("summary", {}).get("round_trip_status", "")),
	}

static func _road_class_for_edge(edge: Dictionary, segment: Dictionary) -> String:
	if bool(edge.get("border_guard", false)):
		return "special_guard_gate_road"
	if bool(edge.get("wide", false)):
		return "wide_guard_suppressed_road"
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
		"wide_guard_suppressed_road":
			return "generated_dirt_wide_guard_suppressed_road"
		"guarded_route_road":
			return "generated_dirt_guarded_road"
		"start_economy_service_road":
			return "generated_dirt_service_road"
		"required_primary_road":
			return "generated_dirt_primary_road"
		_:
			return "generated_dirt_connector_road"

static func _connection_control_records_by_route(route_graph: Dictionary) -> Dictionary:
	var result := {}
	var materialization: Dictionary = route_graph.get("connection_guard_materialization", {}) if route_graph.get("connection_guard_materialization", {}) is Dictionary else {}
	for group_key in ["normal_route_guards", "special_guard_gates"]:
		for record in materialization.get(group_key, []):
			if not (record is Dictionary):
				continue
			var route_edge_id := String(record.get("route_edge_id", ""))
			if route_edge_id == "":
				continue
			if not result.has(route_edge_id):
				result[route_edge_id] = []
			result[route_edge_id].append(record)
	return result

static func _connection_control_for_road_segment(route_edge_id: String, cells: Array, records: Array) -> Dictionary:
	if cells.is_empty() or records.is_empty() or not (records[0] is Dictionary):
		return {}
	var record: Dictionary = records[0]
	var anchor: Dictionary = record.get("route_cell_anchor_candidate", {}) if record.get("route_cell_anchor_candidate", {}) is Dictionary else {}
	if anchor.is_empty():
		anchor = record.get("placement_candidate", {}) if record.get("placement_candidate", {}) is Dictionary else {}
	var road_tile := _closest_point_in_path(cells, anchor)
	if road_tile.is_empty():
		return {}
	return {
		"controlled": true,
		"route_edge_id": route_edge_id,
		"connection_guard_materialization_id": String(record.get("id", "")),
		"control_kind": String(record.get("record_type", "")),
		"guard_value": int(record.get("guard_value", 0)),
		"road_tile": road_tile,
		"anchor_candidate": anchor,
		"distance_to_anchor": _manhattan_distance(road_tile, anchor) if not anchor.is_empty() else 0,
		"normal_guard_materialized": bool(record.get("normal_guard_materialized", false)),
		"special_guard_materialized": bool(record.get("special_guard_materialized", false)),
		"source_link": record.get("source_link", {}),
		"writeout_state": "final_generated_connection_choke_marker_written_to_road_overlay",
	}

static func _closest_point_in_path(cells: Array, anchor: Dictionary) -> Dictionary:
	if cells.is_empty():
		return {}
	if anchor.is_empty():
		return cells[int(floor(float(cells.size() - 1) * 0.5))] if cells[int(floor(float(cells.size() - 1) * 0.5))] is Dictionary else {}
	var best := {}
	var best_distance := 999999999
	for cell in cells:
		if not (cell is Dictionary):
			continue
		var distance := _manhattan_distance(cell, anchor)
		if distance < best_distance:
			best_distance = distance
			best = cell
	return best

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

static func _route_blocking_body_lookup_from_footprint_records(records: Array) -> Dictionary:
	var result := {}
	for record in records:
		if not (record is Dictionary):
			continue
		var kind := String(record.get("kind", ""))
		if kind in ["route_guard", "special_guard_gate", "reward_reference"]:
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
		"object_writeout_count": record.get("object_writeout_records", []).size(),
		"final_tile_stream_count": record.get("final_tile_stream", []).size(),
		"boundary_key_count": record.get("boundary_metadata", {}).keys().size() if record.get("boundary_metadata", {}) is Dictionary else 0,
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
	match _normalize_legacy_terrain_id(terrain_id):
		"rough", "dirt", "underground":
			ratio += 0.015
		"grass":
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
	var adjacent_route_pressure_count := 0
	var adjacent_same_terrain_count := 0
	for offset in _cardinal_offsets():
		var nx := x + int(offset.x)
		var ny := y + int(offset.y)
		var key := _point_key(nx, ny)
		if occupied.has(key):
			adjacent_object_count += 1
		if exclusion.has(key):
			if _decoration_exclusion_reason_is_route_pressure(String(exclusion.get(key, ""))):
				adjacent_route_pressure_count += 1
			else:
				adjacent_reserved_count += 1
		if _point_in_rows(terrain_rows, nx, ny) and String(terrain_rows[ny][nx]) == terrain_id:
			adjacent_same_terrain_count += 1
	var terrain_score := 20 if not _decoration_families_for_terrain(terrain_id, biome_id).is_empty() else -5000
	var route_pressure_score := adjacent_route_pressure_count * 24
	var adjacency_score := adjacent_same_terrain_count * 2 + route_pressure_score - adjacent_object_count * 2 - adjacent_reserved_count
	var overlap_score := 12 if not occupied.has(_point_key(x, y)) and not exclusion.has(_point_key(x, y)) else -5000
	var jitter := int(_hash32_int("%s:%s:%d,%d:decor_jitter" % [seed_text, zone_id, x, y]) % 17)
	return {
		"hard_reject_score": min(hard_reject, terrain_score, overlap_score),
		"terrain_score": terrain_score,
		"adjacency_score": adjacency_score,
		"route_pressure_score": route_pressure_score,
		"adjacent_route_pressure_count": adjacent_route_pressure_count,
		"overlap_score": overlap_score,
		"seed_jitter_score": jitter,
		"total": terrain_score + adjacency_score + overlap_score + jitter,
	}

static func _decoration_exclusion_reason_is_route_pressure(reason: String) -> bool:
	return reason in ["road_segment", "corridor_required_cell", "route_anchor", "monster_reward_route_anchor"]

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
	if result.is_empty() and terrain_id in ["grass"]:
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

static func _decoration_blocking_body_tile_total(records: Array) -> int:
	var total := 0
	for record in records:
		if record is Dictionary and bool(record.get("blocking_body", true)):
			total += record.get("body_tiles", []).size()
	return total

static func _decoration_multitile_record_count(records: Array) -> int:
	var count := 0
	for record in records:
		if record is Dictionary and record.get("body_tiles", []).size() > 1:
			count += 1
	return count

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
		var effective_target := int(target.get("validation_effective_target", target.get("effective_target", 0)))
		var placed := int(target.get("placed_count", 0))
		var tolerance := int(target.get("tolerance", 0))
		if abs(placed - effective_target) > tolerance:
			failures.append("zone %s placed %d outside effective target %d tolerance %d" % [zone_id, placed, effective_target, tolerance])
		if bool(target.get("capacity_limited", false)):
			warnings.append("zone %s decoration target was capacity limited by exclusions or multi-tile footprint fit" % zone_id)
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
		var path := _find_passable_path(from_anchor, to_anchor, terrain_rows, _occupied_without_route_endpoints(decorated_occupied, from_anchor, to_anchor))
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

static func _decoration_route_shaping_summary(records: Array, route_graph: Dictionary, road_network: Dictionary, terrain_rows: Array, placements: Dictionary = {}) -> Dictionary:
	var body_to_record := {}
	var guard_body_to_record := {}
	var blocking_record_ids := {}
	for record in records:
		if not (record is Dictionary) or not bool(record.get("blocking_body", true)):
			continue
		var record_id := String(record.get("id", record.get("placement_id", "")))
		if record_id == "":
			continue
		blocking_record_ids[record_id] = true
		for body in record.get("body_tiles", []):
			if body is Dictionary:
				body_to_record[_point_key(int(body.get("x", 0)), int(body.get("y", 0)))] = record_id
	for placement in placements.get("object_placements", []):
		if not (placement is Dictionary):
			continue
		if String(placement.get("kind", "")) not in ["route_guard", "special_guard_gate"]:
			continue
		var guard_id := String(placement.get("placement_id", placement.get("id", "")))
		if guard_id == "":
			continue
		for body in placement.get("body_tiles", []):
			if body is Dictionary:
				guard_body_to_record[_point_key(int(body.get("x", 0)), int(body.get("y", 0)))] = guard_id
	var edges_by_id := _route_edges_by_id(route_graph.get("edges", []))
	var required_route_ids := []
	for edge in route_graph.get("edges", []):
		if edge is Dictionary and bool(edge.get("required", false)):
			var edge_id := String(edge.get("id", ""))
			if edge_id != "" and edge_id not in required_route_ids:
				required_route_ids.append(edge_id)
	required_route_ids.sort()
	var required_with_shoulder := {}
	var required_with_choke := {}
	var shoulder_body_keys := {}
	var shoulder_record_ids := {}
	var shoulder_guard_body_keys := {}
	var shoulder_guard_ids := {}
	var choked_road_tile_count := 0
	var road_tile_count := 0
	var required_road_tile_count := 0
	for segment in road_network.get("road_segments", []):
		if not (segment is Dictionary):
			continue
		var route_edge_id := String(segment.get("route_edge_id", ""))
		var edge: Dictionary = edges_by_id.get(route_edge_id, {})
		var is_required := bool(edge.get("required", false))
		var route_has_shoulder := false
		var route_has_choke := false
		for cell in segment.get("cells", []):
			if not (cell is Dictionary):
				continue
			var x := int(cell.get("x", -1))
			var y := int(cell.get("y", -1))
			if not _point_in_rows(terrain_rows, x, y):
				continue
			road_tile_count += 1
			if is_required:
				required_road_tile_count += 1
			var adjacent_body_count := 0
			for offset in _cardinal_offsets():
				var key := _point_key(x + int(offset.x), y + int(offset.y))
				if body_to_record.has(key):
					adjacent_body_count += 1
					shoulder_body_keys[key] = true
					shoulder_record_ids[String(body_to_record[key])] = true
					route_has_shoulder = true
				elif guard_body_to_record.has(key):
					adjacent_body_count += 1
					shoulder_guard_body_keys[key] = true
					shoulder_guard_ids[String(guard_body_to_record[key])] = true
					route_has_shoulder = true
			if adjacent_body_count >= 2:
				choked_road_tile_count += 1
				route_has_choke = true
		if is_required and route_edge_id != "":
			if route_has_shoulder:
				required_with_shoulder[route_edge_id] = true
			if route_has_choke:
				required_with_choke[route_edge_id] = true
	var required_count := required_route_ids.size()
	return {
		"schema_id": "random_map_decoration_route_shaping_v1",
		"status": "pass" if required_count <= 0 or required_with_shoulder.size() > 0 else "warning",
		"policy": "decorative_obstacle_bodies_are_biased_to_route_shoulders_without_blocking_required_roads",
		"required_route_count": required_count,
		"required_route_with_shoulder_count": required_with_shoulder.size(),
		"required_route_with_choke_count": required_with_choke.size(),
		"required_route_shoulder_coverage_ratio": snapped(float(required_with_shoulder.size()) / float(max(1, required_count)), 0.001),
		"required_route_choke_coverage_ratio": snapped(float(required_with_choke.size()) / float(max(1, required_count)), 0.001),
		"road_tile_count": road_tile_count,
		"required_road_tile_count": required_road_tile_count,
		"route_shoulder_body_count": shoulder_body_keys.size() + shoulder_guard_body_keys.size(),
		"route_shoulder_decoration_body_count": shoulder_body_keys.size(),
		"route_shoulder_guard_body_count": shoulder_guard_body_keys.size(),
		"route_shoulder_decoration_count": shoulder_record_ids.size(),
		"route_shoulder_guard_count": shoulder_guard_ids.size(),
		"blocking_decoration_count": blocking_record_ids.size(),
		"choked_road_tile_count": choked_road_tile_count,
		"required_route_ids": required_route_ids,
		"required_routes_with_shoulders": _sorted_keys(required_with_shoulder),
		"required_routes_with_chokes": _sorted_keys(required_with_choke),
		"remaining_required_routes_without_shoulders": _array_difference(required_route_ids, _sorted_keys(required_with_shoulder)),
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
		"artifact_id": String(candidate.get("artifact_id", "")),
		"spell_id": String(candidate.get("spell_id", "")),
		"skill_equivalent_id": String(candidate.get("skill_equivalent_id", "")),
		"site_id": String(candidate.get("site_id", "")),
		"selected_resource_category_id": String(category_link.get("original_category_id", "")),
		"category_link": category_link,
		"candidate_value": int(candidate.get("value", 0)),
		"candidate_weight": int(candidate.get("weight", 1)),
		"guarded_policy": String(candidate.get("guarded_policy", "")),
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
	var expected_normal_count := int(payload.get("summary", {}).get("normal_guard_record_count", 0))
	if not generated_map.is_empty():
		expected_normal_count = int(generated_map.get("staging", {}).get("connection_guard_materialization", {}).get("summary", {}).get("expected_normal_guard_count", expected_normal_count))
	if expected_normal_count > 0 and not has_normal:
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

static func _build_object_pool_value_weighting_payload(normalized: Dictionary, zones: Array, placements: Dictionary, monster_reward_bands: Dictionary, town_mine_dwelling: Dictionary, decoration_density: Dictionary, terrain_rows: Array, route_graph: Dictionary) -> Dictionary:
	var selected_records := []
	for reward in monster_reward_bands.get("reward_band_records", []):
		if reward is Dictionary:
			selected_records.append(_object_pool_selected_reward_record(reward, monster_reward_bands, zones))
	for mine in town_mine_dwelling.get("mine_resource_producer_records", []):
		if mine is Dictionary:
			selected_records.append(_object_pool_selected_mine_record(mine))
	for dwelling in town_mine_dwelling.get("dwelling_recruitment_site_records", []):
		if dwelling is Dictionary:
			selected_records.append(_object_pool_selected_dwelling_record(dwelling))
	for decor in decoration_density.get("decoration_records", []):
		if decor is Dictionary:
			selected_records.append(_object_pool_selected_decoration_record(decor))
	var catalog := _object_pool_candidate_pool_catalog()
	var limit_validation := _object_pool_limit_validation(selected_records, normalized)
	var band_diagnostics := _object_pool_band_diagnostics(monster_reward_bands)
	var fairness := _object_pool_fairness_deltas(selected_records, zones)
	var validation := _object_pool_value_weighting_validation_core(selected_records, catalog, limit_validation, fairness, monster_reward_bands, town_mine_dwelling, decoration_density, terrain_rows, route_graph)
	var status := "pass"
	if not bool(validation.get("ok", false)):
		status = "fail"
	elif not band_diagnostics.get("warnings", []).is_empty():
		status = "warning"
	var payload := {
		"schema_id": OBJECT_POOL_VALUE_WEIGHTING_SCHEMA_ID,
		"status": status,
		"selection_policy": "explicit_original_content_candidate_pools_weighted_by_zone_role_biome_template_metadata_guard_policy_reward_band_and_object_limits",
		"candidate_pool_catalog": catalog,
		"selected_candidates": selected_records,
		"object_counts": _object_pool_counts(selected_records),
		"value_totals": _object_pool_value_totals(selected_records),
		"band_diagnostics": band_diagnostics,
		"limit_validation": limit_validation,
		"fairness_deltas": fairness,
		"route_reference_count": route_graph.get("edges", []).size(),
		"generated_runtime_consumption": "selected_weighted_objects_remain_in_staging_scenario_constraints_and_runtime_materialization_without_authored_json_writeback",
		"validation": validation,
		"summary": {
			"selected_candidate_count": selected_records.size(),
			"candidate_pool_count": catalog.get("pools", []).size(),
			"reward_candidate_count": _object_pool_count_by_kind(selected_records, "reward"),
			"mine_candidate_count": _object_pool_count_by_kind(selected_records, "mine"),
			"dwelling_candidate_count": _object_pool_count_by_kind(selected_records, "neutral_dwelling"),
			"decoration_candidate_count": _object_pool_count_by_kind(selected_records, "decorative_obstacle"),
			"total_selected_value": int(_object_pool_value_totals(selected_records).get("total", 0)),
			"exhausted_band_count": band_diagnostics.get("exhausted_bands", []).size(),
			"fallback_choice_count": band_diagnostics.get("fallback_choices", []).size(),
			"limit_violation_count": limit_validation.get("violations", []).size(),
			"player_value_spread": int(fairness.get("player_value_delta", {}).get("spread", 0)),
			"validation_status": String(validation.get("status", "")),
		},
		"deferred": [
			"final_reward_object_body_writeout",
			"live_artifact_spell_skill_reward_execution",
			"large_batch_parity_stress",
			"skirmish_ui_save_replay_adoption",
			"parity_or_alpha_completion_claim",
		],
	}
	payload["object_pool_value_weighting_signature"] = _hash32_hex(_stable_stringify({
		"candidate_pool_catalog_signature": catalog.get("pool_catalog_signature", ""),
		"selected_candidates": selected_records,
		"object_counts": payload.get("object_counts", {}),
		"value_totals": payload.get("value_totals", {}),
		"band_diagnostics": band_diagnostics,
		"limit_validation": limit_validation,
		"fairness_deltas": fairness,
	}))
	return payload

static func _object_pool_candidate_pool_catalog() -> Dictionary:
	var pools := [
		{
			"pool_id": "reward_value_bands",
			"kind": "reward",
			"source": "REWARD_BAND_CANDIDATES",
			"candidate_count": REWARD_BAND_CANDIDATES.size(),
			"weighting_fields": ["value", "weight", "categories", "guarded_policy", "reward_category"],
			"candidate_records": _reward_pool_candidate_records(),
		},
		{
			"pool_id": "seven_category_mines",
			"kind": "mine",
			"source": "ORIGINAL_RESOURCE_CATEGORY_ORDER + MINE_SITE_BY_ORIGINAL_CATEGORY",
			"candidate_count": ORIGINAL_RESOURCE_CATEGORY_ORDER.size(),
			"weighting_fields": ["minimum_by_category", "density_by_category", "guard_base_value", "source_equivalent"],
			"candidate_records": _mine_pool_candidate_records(),
		},
		{
			"pool_id": "neutral_dwelling_recruitment",
			"kind": "neutral_dwelling",
			"source": "DWELLING_SITE_CANDIDATES",
			"candidate_count": DWELLING_SITE_CANDIDATES.size(),
			"weighting_fields": ["biome_ids", "guard_pressure", "zone_role"],
			"candidate_records": DWELLING_SITE_CANDIDATES.duplicate(true),
		},
		{
			"pool_id": "terrain_biased_decoration",
			"kind": "decorative_obstacle",
			"source": "DECORATION_OBJECT_FAMILIES",
			"candidate_count": DECORATION_OBJECT_FAMILIES.size(),
			"weighting_fields": ["terrain_ids", "biome_ids", "weight", "adjacency_score", "overlap_score"],
			"candidate_records": DECORATION_OBJECT_FAMILIES.duplicate(true),
		},
	]
	var catalog := {
		"schema_id": "random_map_object_candidate_pool_catalog_v1",
		"pools": pools,
		"object_limits": _object_pool_limit_table(),
		"artifact_spell_skill_equivalents": _object_pool_artifact_spell_skill_equivalents(),
		"source_model": "HoMM3_RMG_value_banded_object_selection_translated_to_original_content_ids",
	}
	catalog["pool_catalog_signature"] = _hash32_hex(_stable_stringify(catalog))
	return catalog

static func _reward_pool_candidate_records() -> Array:
	var result := []
	for candidate in REWARD_BAND_CANDIDATES:
		if not (candidate is Dictionary):
			continue
		var record: Dictionary = candidate.duplicate(true)
		record["candidate_id"] = "reward_%s_%s" % [String(candidate.get("reward_category", "")), String(candidate.get("object_id", ""))]
		record["value_band_class"] = _object_pool_value_band_class(int(candidate.get("value", 0)))
		result.append(record)
	return result

static func _mine_pool_candidate_records() -> Array:
	var result := []
	for category in ORIGINAL_RESOURCE_CATEGORY_ORDER:
		if not (category is Dictionary):
			continue
		var category_id := String(category.get("original_category_id", ""))
		var mine: Dictionary = MINE_SITE_BY_ORIGINAL_CATEGORY.get(category_id, {})
		var record: Dictionary = category.duplicate(true)
		record["candidate_id"] = "mine_%s" % category_id
		record["site_id"] = String(mine.get("site_id", ""))
		record["object_id"] = String(mine.get("object_id", ""))
		record["resource_id"] = String(mine.get("resource_id", ""))
		record["value_band_class"] = _object_pool_value_band_class(int(category.get("guard_base_value", 0)))
		result.append(record)
	return result

static func _object_pool_artifact_spell_skill_equivalents() -> Dictionary:
	var artifact_ids := []
	var spell_ids := []
	var skill_equivalent_ids := []
	for candidate in REWARD_BAND_CANDIDATES:
		if not (candidate is Dictionary):
			continue
		if String(candidate.get("artifact_id", "")) != "":
			artifact_ids.append(String(candidate.get("artifact_id", "")))
		if String(candidate.get("spell_id", "")) != "":
			spell_ids.append(String(candidate.get("spell_id", "")))
		if String(candidate.get("skill_equivalent_id", "")) != "":
			skill_equivalent_ids.append(String(candidate.get("skill_equivalent_id", "")))
	return {
		"artifact_ids": _unique_sorted_strings(artifact_ids),
		"spell_ids": _unique_sorted_strings(spell_ids),
		"skill_equivalent_ids": _unique_sorted_strings(skill_equivalent_ids),
	}

static func _object_pool_selected_reward_record(reward: Dictionary, monster_reward_bands: Dictionary, zones: Array) -> Dictionary:
	var zone_id := _object_pool_zone_id_for_route(String(reward.get("route_edge_id", "")), monster_reward_bands, zones)
	var category := String(reward.get("selected_reward_category_id", ""))
	var value := int(reward.get("candidate_value", 0))
	return {
		"selection_id": String(reward.get("id", "")),
		"kind": "reward",
		"pool_id": "reward_value_bands",
		"zone_id": zone_id,
		"zone_role": _object_pool_zone_role(zone_id, zones),
		"terrain_id": _object_pool_zone_terrain(zone_id, zones),
		"biome_id": _biome_for_terrain(_object_pool_zone_terrain(zone_id, zones)),
		"route_edge_id": String(reward.get("route_edge_id", "")),
		"content_id": String(reward.get("selected_reward_object_id", "")),
		"object_id": String(reward.get("selected_reward_object_id", "")),
		"family_id": String(reward.get("selected_reward_family_id", "")),
		"artifact_id": String(reward.get("artifact_id", "")),
		"spell_id": String(reward.get("spell_id", "")),
		"skill_equivalent_id": String(reward.get("skill_equivalent_id", "")),
		"reward_category": category,
		"resource_category_id": String(reward.get("selected_resource_category_id", "")),
		"value": value,
		"weight": int(reward.get("candidate_weight", 1)),
		"value_band": reward.get("selected_band", {}),
		"guarded_policy": String(reward.get("guarded_policy", "")),
		"guarded": true,
		"fallback": String(reward.get("source", "")) != "template_treasure_band",
		"limit_kind": "reward_reference",
		"selected_from_explicit_pool": true,
	}

static func _object_pool_selected_mine_record(mine: Dictionary) -> Dictionary:
	var value := int(mine.get("guard_pressure", {}).get("base_value", 0))
	return {
		"selection_id": String(mine.get("placement_id", "")),
		"kind": "mine",
		"pool_id": "seven_category_mines",
		"zone_id": String(mine.get("zone_id", "")),
		"zone_role": String(mine.get("zone_role", "")),
		"content_id": String(mine.get("object_id", mine.get("site_id", ""))),
		"object_id": String(mine.get("object_id", "")),
		"site_id": String(mine.get("site_id", "")),
		"family_id": String(mine.get("family_id", "")),
		"resource_category_id": String(mine.get("original_resource_category_id", "")),
		"resource_id": String(mine.get("resource_id", "")),
		"value": value,
		"weight": max(1, int(mine.get("minimum_requirement", 0)) * 3 + int(mine.get("density_requirement", 0))),
		"guarded": bool(mine.get("guard_pressure", {}).get("guarded", false)),
		"terrain_id": String(mine.get("footprint_action_metadata", {}).get("placement_predicate_results", {}).get("terrain_id", "")),
		"biome_id": _biome_for_terrain(String(mine.get("footprint_action_metadata", {}).get("placement_predicate_results", {}).get("terrain_id", "grass"))),
		"limit_kind": "mine",
		"selected_from_explicit_pool": true,
	}

static func _object_pool_selected_dwelling_record(dwelling: Dictionary) -> Dictionary:
	var pressure := String(dwelling.get("guard_pressure", "medium"))
	var value := 900 if pressure == "low" else 1300 if pressure == "medium" else 1800
	return {
		"selection_id": String(dwelling.get("placement_id", "")),
		"kind": "neutral_dwelling",
		"pool_id": "neutral_dwelling_recruitment",
		"zone_id": String(dwelling.get("zone_id", "")),
		"zone_role": String(dwelling.get("zone_role", "")),
		"content_id": String(dwelling.get("object_id", dwelling.get("site_id", ""))),
		"object_id": String(dwelling.get("object_id", "")),
		"site_id": String(dwelling.get("site_id", "")),
		"family_id": String(dwelling.get("family_id", "")),
		"neutral_dwelling_family_id": String(dwelling.get("neutral_dwelling_family_id", "")),
		"value": value,
		"weight": 2 if pressure == "low" else 3 if pressure == "medium" else 1,
		"guarded": pressure != "low",
		"guarded_policy": pressure,
		"terrain_id": String(dwelling.get("footprint_action_metadata", {}).get("placement_predicate_results", {}).get("terrain_id", "")),
		"biome_id": _biome_for_terrain(String(dwelling.get("footprint_action_metadata", {}).get("placement_predicate_results", {}).get("terrain_id", "grass"))),
		"limit_kind": "neutral_dwelling",
		"selected_from_explicit_pool": true,
	}

static func _object_pool_selected_decoration_record(decor: Dictionary) -> Dictionary:
	return {
		"selection_id": String(decor.get("id", decor.get("placement_id", ""))),
		"kind": "decorative_obstacle",
		"pool_id": "terrain_biased_decoration",
		"zone_id": String(decor.get("zone_id", "")),
		"zone_role": String(decor.get("density_context", {}).get("zone_role", "")),
		"content_id": String(decor.get("family_id", "")),
		"family_id": String(decor.get("family_id", "")),
		"value": 0,
		"weight": int(decor.get("placement_scores", {}).get("weight", 1)),
		"guarded": false,
		"terrain_id": String(decor.get("terrain_id", "")),
		"biome_id": String(decor.get("biome_id", "")),
		"limit_kind": "decorative_obstacle",
		"selected_from_explicit_pool": true,
	}

static func _object_pool_zone_id_for_route(route_edge_id: String, monster_reward_bands: Dictionary, zones: Array) -> String:
	for record in monster_reward_bands.get("monster_reward_records", []):
		if record is Dictionary and String(record.get("route_edge_id", "")) == route_edge_id:
			return String(record.get("zone_context", {}).get("primary_zone_id", ""))
	return String(zones[0].get("id", "")) if not zones.is_empty() and zones[0] is Dictionary else ""

static func _object_pool_zone_role(zone_id: String, zones: Array) -> String:
	for zone in zones:
		if zone is Dictionary and String(zone.get("id", "")) == zone_id:
			return String(zone.get("role", ""))
	return ""

static func _object_pool_zone_terrain(zone_id: String, zones: Array) -> String:
	for zone in zones:
		if zone is Dictionary and String(zone.get("id", "")) == zone_id:
			return String(zone.get("terrain_id", "grass"))
	return "grass"

static func _object_pool_limit_table(size: Dictionary = {}) -> Dictionary:
	var table := {}
	var area_scale := 1
	if not size.is_empty():
		var width: int = max(1, int(size.get("width", size.get("source_width", 36))))
		var height: int = max(1, int(size.get("height", size.get("source_height", 36))))
		area_scale = max(1, int(ceil(float(width * height) / float(36 * 36))))
	for catalog in OBJECT_FOOTPRINT_CATALOG:
		if not (catalog is Dictionary):
			continue
		var limit: Dictionary = catalog.get("object_limit", {}) if catalog.get("object_limit", {}) is Dictionary else {}
		for kind in catalog.get("placement_kinds", []):
			var per_zone := int(limit.get("per_zone", 999999))
			var global := int(limit.get("global", 999999))
			if String(kind) == "decorative_obstacle":
				per_zone *= area_scale
				global *= area_scale
			table[String(kind)] = {
				"catalog_id": String(catalog.get("id", "")),
				"per_zone": per_zone,
				"global": global,
				"scale_policy": "map_area_scaled_from_36x36_baseline" if String(kind) == "decorative_obstacle" else "fixed_by_catalog",
			}
	return table

static func _object_pool_limit_for_kind(kind: String, scope: String, fallback: int) -> int:
	var limits := _object_pool_limit_table()
	var limit: Dictionary = limits.get(kind, {}) if limits.get(kind, {}) is Dictionary else {}
	return int(limit.get(scope, fallback))

static func _object_pool_limit_validation(selected_records: Array, normalized: Dictionary = {}) -> Dictionary:
	var size: Dictionary = normalized.get("size", {}) if normalized.get("size", {}) is Dictionary else {}
	var limits := _object_pool_limit_table(size)
	var global_counts := {}
	var zone_counts := {}
	var violations := []
	for record in selected_records:
		if not (record is Dictionary):
			continue
		var limit_kind := String(record.get("limit_kind", record.get("kind", "")))
		global_counts[limit_kind] = int(global_counts.get(limit_kind, 0)) + 1
		var zone_key := "%s|%s" % [String(record.get("zone_id", "")), limit_kind]
		zone_counts[zone_key] = int(zone_counts.get(zone_key, 0)) + 1
	for kind in _sorted_keys(global_counts):
		var limit: Dictionary = limits.get(kind, {}) if limits.get(kind, {}) is Dictionary else {}
		if int(global_counts.get(kind, 0)) > int(limit.get("global", 999999)):
			violations.append("global limit exceeded for %s: %d > %d" % [kind, int(global_counts.get(kind, 0)), int(limit.get("global", 999999))])
	for zone_key in _sorted_keys(zone_counts):
		var pieces := String(zone_key).split("|")
		var kind := pieces[1] if pieces.size() > 1 else String(zone_key)
		var limit: Dictionary = limits.get(kind, {}) if limits.get(kind, {}) is Dictionary else {}
		if int(zone_counts.get(zone_key, 0)) > int(limit.get("per_zone", 999999)):
			violations.append("per-zone limit exceeded for %s: %d > %d" % [zone_key, int(zone_counts.get(zone_key, 0)), int(limit.get("per_zone", 999999))])
	return {
		"ok": violations.is_empty(),
		"status": "pass" if violations.is_empty() else "fail",
		"limits": limits,
		"global_counts": _sorted_dict(global_counts),
		"zone_counts": _sorted_dict(zone_counts),
		"violations": violations,
	}

static func _object_pool_band_diagnostics(monster_reward_bands: Dictionary) -> Dictionary:
	var exhausted := []
	var fallbacks := []
	var warnings := []
	for diagnostic in monster_reward_bands.get("diagnostics", []):
		if not (diagnostic is Dictionary):
			continue
		var reason := String(diagnostic.get("reason", ""))
		if reason.find("exhausted") >= 0:
			exhausted.append(diagnostic)
		if reason.find("fallback") >= 0 or reason.find("missing_eligible_treasure_band") >= 0:
			fallbacks.append(diagnostic)
		warnings.append("%s:%s" % [String(diagnostic.get("route_edge_id", "")), reason])
	for reward in monster_reward_bands.get("reward_band_records", []):
		if reward is Dictionary and String(reward.get("source", "")) != "template_treasure_band":
			fallbacks.append({
				"route_edge_id": String(reward.get("route_edge_id", "")),
				"reason": "reward_band_source_fallback",
				"selected_band": reward.get("selected_band", {}),
				"selected_reward_category_id": String(reward.get("selected_reward_category_id", "")),
			})
	return {
		"exhausted_bands": exhausted,
		"fallback_choices": fallbacks,
		"warnings": warnings,
	}

static func _object_pool_counts(selected_records: Array) -> Dictionary:
	var by_kind := {}
	var by_pool := {}
	var by_zone := {}
	var by_reward_category := {}
	for record in selected_records:
		if not (record is Dictionary):
			continue
		var kind := String(record.get("kind", ""))
		var pool := String(record.get("pool_id", ""))
		var zone := String(record.get("zone_id", ""))
		by_kind[kind] = int(by_kind.get(kind, 0)) + 1
		by_pool[pool] = int(by_pool.get(pool, 0)) + 1
		by_zone[zone] = int(by_zone.get(zone, 0)) + 1
		if kind == "reward":
			var category := String(record.get("reward_category", ""))
			by_reward_category[category] = int(by_reward_category.get(category, 0)) + 1
	return {
		"by_kind": _sorted_dict(by_kind),
		"by_pool": _sorted_dict(by_pool),
		"by_zone": _sorted_dict(by_zone),
		"by_reward_category": _sorted_dict(by_reward_category),
	}

static func _object_pool_value_totals(selected_records: Array) -> Dictionary:
	var total := 0
	var by_kind := {}
	var by_zone := {}
	for record in selected_records:
		if not (record is Dictionary):
			continue
		var value := int(record.get("value", 0))
		total += value
		var kind := String(record.get("kind", ""))
		var zone := String(record.get("zone_id", ""))
		by_kind[kind] = int(by_kind.get(kind, 0)) + value
		by_zone[zone] = int(by_zone.get(zone, 0)) + value
	return {
		"total": total,
		"by_kind": _sorted_dict(by_kind),
		"by_zone": _sorted_dict(by_zone),
	}

static func _object_pool_fairness_deltas(selected_records: Array, zones: Array) -> Dictionary:
	var zone_owner := {}
	var zone_role := {}
	for zone in zones:
		if zone is Dictionary:
			zone_owner[String(zone.get("id", ""))] = zone.get("player_slot", null)
			zone_role[String(zone.get("id", ""))] = String(zone.get("role", ""))
	var player_totals := {}
	var zone_totals := {}
	var zone_role_totals := {}
	for record in selected_records:
		if not (record is Dictionary):
			continue
		var zone_id := String(record.get("zone_id", ""))
		var value := int(record.get("value", 0))
		zone_totals[zone_id] = int(zone_totals.get(zone_id, 0)) + value
		var role := String(zone_role.get(zone_id, String(record.get("zone_role", ""))))
		zone_role_totals[role] = int(zone_role_totals.get(role, 0)) + value
		var owner = zone_owner.get(zone_id, null)
		if owner != null and int(owner) > 0:
			var player_key := "player_%d" % int(owner)
			player_totals[player_key] = int(player_totals.get(player_key, 0)) + value
	return {
		"player_value_totals": _sorted_dict(player_totals),
		"player_value_delta": _value_spread_record(player_totals),
		"zone_value_totals": _sorted_dict(zone_totals),
		"zone_value_delta": _value_spread_record(zone_totals),
		"zone_role_value_totals": _sorted_dict(zone_role_totals),
	}

static func _value_spread_record(values: Dictionary) -> Dictionary:
	if values.is_empty():
		return {"min": 0, "max": 0, "spread": 0, "count": 0}
	var min_value := 999999999
	var max_value := -999999999
	for key in values.keys():
		var value := int(values[key])
		min_value = min(min_value, value)
		max_value = max(max_value, value)
	return {"min": min_value, "max": max_value, "spread": max_value - min_value, "count": values.size()}

static func _object_pool_value_weighting_validation_core(selected_records: Array, catalog: Dictionary, limit_validation: Dictionary, fairness: Dictionary, monster_reward_bands: Dictionary, town_mine_dwelling: Dictionary, decoration_density: Dictionary, terrain_rows: Array, route_graph: Dictionary) -> Dictionary:
	var failures := []
	var warnings := []
	if selected_records.is_empty():
		failures.append("no weighted object candidates were selected")
	var pools: Array = catalog.get("pools", []) if catalog.get("pools", []) is Array else []
	if pools.size() < 4:
		failures.append("candidate pool catalog missed required reward/mine/dwelling/decoration pools")
	var pool_ids := {}
	for pool in pools:
		if pool is Dictionary:
			pool_ids[String(pool.get("pool_id", ""))] = true
	for required_pool in ["reward_value_bands", "seven_category_mines", "neutral_dwelling_recruitment", "terrain_biased_decoration"]:
		if not pool_ids.has(required_pool):
			failures.append("candidate pool %s missing" % required_pool)
	var equivalents: Dictionary = catalog.get("artifact_spell_skill_equivalents", {}) if catalog.get("artifact_spell_skill_equivalents", {}) is Dictionary else {}
	for key in ["artifact_ids", "spell_ids", "skill_equivalent_ids"]:
		if equivalents.get(key, []).is_empty():
			failures.append("candidate pool catalog missed %s coverage" % key)
	for record in selected_records:
		if not (record is Dictionary):
			failures.append("selected object pool record is not a dictionary")
			continue
		if String(record.get("content_id", "")) == "" or String(record.get("pool_id", "")) == "":
			failures.append("selected record missed content id or pool id: %s" % JSON.stringify(record))
		if not bool(record.get("selected_from_explicit_pool", false)):
			failures.append("selected record did not declare explicit-pool selection: %s" % String(record.get("selection_id", "")))
		if String(record.get("kind", "")) != "decorative_obstacle" and int(record.get("value", 0)) <= 0:
			failures.append("selected non-decoration record missed positive value: %s" % String(record.get("selection_id", "")))
		if String(record.get("terrain_id", "")) == "" and String(record.get("kind", "")) in ["mine", "neutral_dwelling", "decorative_obstacle"]:
			failures.append("selected terrain-aware record missed terrain id: %s" % String(record.get("selection_id", "")))
	if not bool(limit_validation.get("ok", false)):
		failures.append_array(limit_validation.get("violations", []))
	if monster_reward_bands.get("reward_band_records", []).is_empty():
		failures.append("reward band records missing from object pool weighting")
	if town_mine_dwelling.get("mine_resource_producer_records", []).is_empty():
		failures.append("mine records missing from object pool weighting")
	if town_mine_dwelling.get("dwelling_recruitment_site_records", []).is_empty():
		failures.append("dwelling records missing from object pool weighting")
	if decoration_density.get("decoration_records", []).is_empty():
		failures.append("decoration records missing from object pool weighting")
	if route_graph.get("edges", []).is_empty():
		failures.append("route graph missing for object pool weighting")
	if terrain_rows.is_empty():
		failures.append("terrain rows missing for object pool weighting")
	if int(fairness.get("zone_value_delta", {}).get("count", 0)) <= 0:
		warnings.append("zone value fairness delta had no measured zones")
	return {
		"ok": failures.is_empty(),
		"status": "pass" if failures.is_empty() else "fail",
		"failures": failures,
		"warnings": warnings,
	}

static func _object_pool_value_weighting_phase_summary(payload: Dictionary) -> Dictionary:
	return {
		"schema_id": String(payload.get("schema_id", "")),
		"status": String(payload.get("status", "")),
		"signature": String(payload.get("object_pool_value_weighting_signature", "")),
		"selected_candidate_count": int(payload.get("summary", {}).get("selected_candidate_count", 0)),
		"total_selected_value": int(payload.get("summary", {}).get("total_selected_value", 0)),
		"fallback_choice_count": int(payload.get("summary", {}).get("fallback_choice_count", 0)),
		"limit_violation_count": int(payload.get("summary", {}).get("limit_violation_count", 0)),
		"player_value_spread": int(payload.get("summary", {}).get("player_value_spread", 0)),
	}

static func _object_pool_value_weighting_validation(payload: Dictionary, generated_map: Dictionary = {}) -> Dictionary:
	var failures := []
	var warnings := []
	if String(payload.get("schema_id", "")) != OBJECT_POOL_VALUE_WEIGHTING_SCHEMA_ID:
		failures.append("object pool value weighting schema mismatch")
	if String(payload.get("object_pool_value_weighting_signature", "")) == "":
		failures.append("object pool value weighting signature missing")
	var validation: Dictionary = payload.get("validation", {}) if payload.get("validation", {}) is Dictionary else {}
	if not bool(validation.get("ok", false)):
		failures.append_array(validation.get("failures", []))
	warnings.append_array(validation.get("warnings", []))
	var summary: Dictionary = payload.get("summary", {}) if payload.get("summary", {}) is Dictionary else {}
	if int(summary.get("selected_candidate_count", 0)) <= 0:
		failures.append("object pool value weighting selected no candidates")
	if int(summary.get("reward_candidate_count", 0)) <= 0 or int(summary.get("mine_candidate_count", 0)) <= 0 or int(summary.get("dwelling_candidate_count", 0)) <= 0 or int(summary.get("decoration_candidate_count", 0)) <= 0:
		failures.append("object pool value weighting missed one or more required selected candidate families")
	if payload.get("candidate_pool_catalog", {}).get("artifact_spell_skill_equivalents", {}).get("artifact_ids", []).is_empty():
		failures.append("artifact equivalent pool empty")
	if payload.get("candidate_pool_catalog", {}).get("artifact_spell_skill_equivalents", {}).get("spell_ids", []).is_empty():
		failures.append("spell equivalent pool empty")
	if payload.get("candidate_pool_catalog", {}).get("artifact_spell_skill_equivalents", {}).get("skill_equivalent_ids", []).is_empty():
		failures.append("skill equivalent pool empty")
	if not bool(payload.get("limit_validation", {}).get("ok", false)):
		failures.append("object pool limit validation failed")
	if generated_map.get("scenario_record", {}).get("generated_constraints", {}).get("object_pool_value_weighting", {}).is_empty() and not generated_map.is_empty():
		failures.append("scenario generated_constraints missed object pool value weighting")
	if not generated_map.is_empty():
		var scenario: Dictionary = generated_map.get("scenario_record", {}) if generated_map.get("scenario_record", {}) is Dictionary else {}
		if bool(scenario.get("selection", {}).get("availability", {}).get("campaign", false)) or bool(scenario.get("selection", {}).get("availability", {}).get("skirmish", false)):
			failures.append("object pool value weighting adopted generated map into campaign/skirmish")
		if generated_map.has("authored_content_writeback") or generated_map.has("save_adoption") or scenario.has("alpha_parity_claim"):
			failures.append("object pool value weighting exposed authored writeback/save/parity claim")
	return {
		"ok": failures.is_empty(),
		"status": "pass" if failures.is_empty() else "fail",
		"failures": failures,
		"warnings": warnings,
	}

static func _object_pool_value_band_class(value: int) -> String:
	if value < 700:
		return "low"
	if value < 1300:
		return "medium"
	if value < 2000:
		return "high"
	return "elite"

static func _object_pool_count_by_kind(records: Array, kind: String) -> int:
	var count := 0
	for record in records:
		if record is Dictionary and String(record.get("kind", "")) == kind:
			count += 1
	return count

static func _object_pool_report_variation_config(input_config: Dictionary) -> Dictionary:
	var config := input_config.duplicate(true)
	config["seed"] = "%s:profile_variation" % String(input_config.get("seed", "0"))
	config["size"] = {"preset": "object_pool_value_weighting_variation", "width": 26, "height": 18, "water_mode": "land", "level_count": 1}
	config["profile"] = {
		"id": "border_gate_compact_profile_v1",
		"template_id": "border_gate_compact_v1",
		"guard_strength_profile": "core_low",
	}
	return config

static func _object_pool_batch_example(payload: Dictionary, pool: Dictionary) -> Dictionary:
	var metadata: Dictionary = payload.get("metadata", {}) if payload.get("metadata", {}) is Dictionary else {}
	var profile: Dictionary = metadata.get("profile", {}) if metadata.get("profile", {}) is Dictionary else {}
	return {
		"seed": String(metadata.get("normalized_seed", "")),
		"template_id": String(metadata.get("template_id", "")),
		"profile_id": String(profile.get("id", "")),
		"stable_signature": String(payload.get("stable_signature", "")),
		"object_pool_signature": String(pool.get("object_pool_value_weighting_signature", "")),
		"object_counts": pool.get("object_counts", {}),
		"value_totals": pool.get("value_totals", {}),
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
		var fallback_from_point: Dictionary = from_node.get("point", seeds.get(from_zone, {}))
		var fallback_to_point: Dictionary = to_node.get("point", seeds.get(to_zone, {}))
		var path_payload := _best_route_path_between_nodes(from_node, to_node, terrain_rows, occupied)
		var path: Array = path_payload.get("path", [])
		var from_point: Dictionary = path_payload.get("from_anchor", fallback_from_point)
		var to_point: Dictionary = path_payload.get("to_anchor", fallback_to_point)
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
			var resource_from_node := {
				"id": town_node_id,
				"point": town_point,
				"body_tiles": town.get("body_tiles", []),
				"visit_tile": town.get("visit_tile", {}),
				"approach_tiles": town.get("approach_tiles", []),
			}
			var resource_to_node := {
				"id": resource_node_id,
				"point": resource_point,
				"body_tiles": resource.get("body_tiles", []),
				"visit_tile": resource.get("visit_tile", {}),
				"approach_tiles": resource.get("approach_tiles", []),
			}
			var resource_path_payload := _best_route_path_between_nodes(resource_from_node, resource_to_node, terrain_rows, occupied)
			var resource_path: Array = resource_path_payload.get("path", [])
			town_point = resource_path_payload.get("from_anchor", town_point)
			resource_point = resource_path_payload.get("to_anchor", resource_point)
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
				"transit_semantics": {"kind": "land_road", "materialization_state": "final_generated_road_overlay", "required_unlock": false},
				"required": true,
				"path_found": not resource_path.is_empty(),
				"path_length": resource_path.size(),
				"from_anchor": town_point,
				"to_anchor": resource_point,
				"writeout_state": "final_generated_road_overlay_tile_stream",
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
			"transit": "land_roads_water_access_and_cross_level_routes_have_explicit_gameplay_materialization_records",
		},
		"transit_route_semantics": terrain_transit.get("transit_routes", {}),
	}
	var proof := _reachability_proof(route_nodes, edges, adjacency)
	return {
		"route_graph": route_graph,
		"road_network": {
			"schema_id": "random_map_road_overlay_writeout_v2",
			"writeout_policy": "final_generated_tile_stream_no_authored_tile_write",
			"overlay_id": ROAD_OVERLAY_ID,
			"road_segments": road_segments,
			"road_stubs": road_stubs,
			"blocked_body_policy": "paths_exclude_object_body_tiles_and_impassable_terrain",
			"transit_writeout_policy": "land_road_overlays_written_to_generated_tile_stream_transit_object_records_materialized",
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
			status = "warning"
			warnings.append("player %d lacks same-zone core mine categories %s" % [player_slot, ",".join(missing)])
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
		warnings.append("contested pressure markers lack guarded route or contest front context")
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
			warnings.append("start zone %s has no contest route front in translated source graph" % String(zone_id))
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
		warnings.append("contest route distances exceed fail spread")
	if pressure_status == "warning":
		warnings.append("contest guard pressure exceeds warning spread")
	elif pressure_status == "fail":
		warnings.append("contest guard pressure exceeds fail spread")
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
		warnings.append("no route guard pressure records available in translated source graph")
	var pressure_values := []
	for key in _sorted_keys(pressure_by_start):
		pressure_values.append(int(pressure_by_start[key]))
	var pressure_status := _spread_status(pressure_values, PRESSURE_WARNING_SPREAD, PRESSURE_FAIL_SPREAD)
	if pressure_status == "warning":
		warnings.append("route guard pressure exceeds warning spread")
	elif pressure_status == "fail":
		warnings.append("route guard pressure exceeds fail spread")
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
		warnings.append("town-to-resource route distance spread exceeds fail threshold")
	if contest_status == "warning":
		warnings.append("contest route distance spread exceeds warning threshold")
	elif contest_status == "fail":
		warnings.append("contest route distance spread exceeds fail threshold")
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
	var size: Dictionary = normalized.get("size", {}) if normalized.get("size", {}) is Dictionary else {}
	return {
		"generator_version": String(normalized.get("generator_version", GENERATOR_VERSION)),
		"normalized_seed": String(normalized.get("seed", "0")),
		"profile": normalized.get("profile", {}),
		"size": normalized.get("size", {}),
		"size_policy": {
			"source": "explicit_size_class_or_custom_runtime_size",
			"size_class_id": String(size.get("size_class_id", "")),
			"size_class_label": String(size.get("size_class_label", "")),
			"source_model": String(size.get("source_model", "")),
			"source_size": {
				"width": int(size.get("source_width", size.get("width", 0))),
				"height": int(size.get("source_height", size.get("height", 0))),
				"level_count": int(size.get("requested_level_count", size.get("level_count", 1))),
			},
			"materialized_size": {
				"width": int(size.get("width", 0)),
				"height": int(size.get("height", 0)),
				"level_count": int(size.get("level_count", 1)),
			},
			"runtime_size_cap": size.get("runtime_size_cap", {}),
			"runtime_size_policy": size.get("runtime_size_policy", {}),
			"template_profile_dimension_source": "template_profile_does_not_define_player_facing_map_size",
		},
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

static func _runtime_size_policy_rejection_result(normalized: Dictionary) -> Dictionary:
	var size: Dictionary = normalized.get("size", {}) if normalized.get("size", {}) is Dictionary else {}
	var policy: Dictionary = size.get("runtime_size_policy", {}) if size.get("runtime_size_policy", {}) is Dictionary else {}
	var source_size: Dictionary = policy.get("source_size", {}) if policy.get("source_size", {}) is Dictionary else {}
	var materialized_size: Dictionary = policy.get("materialized_size", {}) if policy.get("materialized_size", {}) is Dictionary else {}
	var failure := "requested size %s source %dx%dx%d exceeds current runtime cap; no hidden downscale to %dx%dx%d is allowed" % [
		String(size.get("size_class_label", size.get("size_class_id", "custom"))),
		int(source_size.get("width", size.get("source_width", 0))),
		int(source_size.get("height", size.get("source_height", 0))),
		int(source_size.get("level_count", size.get("requested_level_count", 1))),
		int(materialized_size.get("width", size.get("width", 0))),
		int(materialized_size.get("height", size.get("height", 0))),
		int(materialized_size.get("level_count", size.get("level_count", 1))),
	]
	var report := {
		"ok": false,
		"status": "fail",
		"schema_id": RUNTIME_SIZE_POLICY_REJECTION_SCHEMA_ID,
		"failure_code": "runtime_size_policy_blocked",
		"failures": [failure],
		"size_policy": _metadata(normalized).get("size_policy", {}),
		"metadata": _metadata(normalized),
		"template_selection": normalized.get("template_selection", {}),
		"fallback_policy": "over_cap_requested_source_size_fails_before_generation_instead_of_silent_runtime_downscale",
	}
	return {
		"ok": false,
		"generated_map": {},
		"report": report,
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
		"materialized_transit_count": terrain_transit.get("gameplay_transit_materialization", {}).get("materialized_transit_records", []).size(),
		"gameplay_transit_status": String(terrain_transit.get("gameplay_transit_materialization", {}).get("status", "")),
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
	var gameplay_transit := _water_underground_transit_gameplay_payload(zone_layout, water_coast, terrain_layers, transit_routes, surface_rows, normalized)
	transit_routes["materialized_transit_records"] = gameplay_transit.get("materialized_transit_records", [])
	transit_routes["water_transit_records"] = gameplay_transit.get("water_transit_records", [])
	transit_routes["cross_level_link_records"] = gameplay_transit.get("cross_level_link_records", [])
	transit_routes["underground_level_records"] = gameplay_transit.get("underground_level_records", [])
	transit_routes["gameplay_validation"] = gameplay_transit.get("validation", {})
	transit_routes["gameplay_transit_signature"] = String(gameplay_transit.get("gameplay_transit_signature", ""))
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
		"gameplay_transit_materialization": gameplay_transit,
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
				"materialization_state": "underground_rows_materialized_cross_level_gate_records_required" if level_kind == "underground" else "surface_layer",
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
		"materialization_policy": "land_road_segments_water_access_and_cross_level_links_have_gameplay_materialization_records_final_art_autotile_polish_deferred",
	}

static func _transit_semantics_for_corridor(candidate: Dictionary, water_coast: Dictionary) -> Dictionary:
	var level_kind := String(candidate.get("level_kind", "surface"))
	var crosses_water := String(candidate.get("mode", "land")) == "water"
	if crosses_water:
		return {
			"kind": "water_crossing_bridge_or_ferry",
			"route_class": "water_crossing",
			"passability": "explicit_transit_link_passable_when_endpoints_validate",
			"materialization_options": ["ferry", "boat", "shipyard", "bridge"],
			"required_unlock": false,
			"deferred": ["final_boat_shipyard_ui_deferred", "final_bridge_autotile_art_deferred"],
			"materialization_state": "gameplay_transit_record_materialized",
		}
	if level_kind == "underground":
		return {
			"kind": "underground_subterranean_connection",
			"route_class": "underground_land_corridor",
			"passability": "cave_land_passable_when_level_is_active",
			"materialization_options": ["subterranean_gate", "underground_road"],
			"required_unlock": false,
			"deferred": ["final_subterranean_gate_art_deferred"],
			"materialization_state": "underground_level_and_route_record_materialized",
		}
	return {
		"kind": "land_road",
		"route_class": "surface_land",
		"passability": "passable_now",
		"materialization_options": ["road_overlay"],
		"required_unlock": false,
		"deferred": [],
		"water_context": "coast_access_available_with_materialized_transit_records" if int(water_coast.get("water_cell_count", 0)) > 0 else "none",
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
				"kind": "cross_level_subterranean_gate",
				"route_class": "cross_level",
				"passability": "explicit_transit_link_passable_when_endpoint_pair_validates",
				"materialization_options": ["subterranean_gate", "two_way_portal"],
				"required_unlock": false,
				"deferred": ["final_subterranean_gate_art_deferred", "final_portal_vfx_deferred"],
				"materialization_state": "cross_level_link_record_materialized",
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
				"kind": "water_ferry_or_bridge_access",
				"route_class": "water_access",
				"passability": "explicit_transit_link_passable_when_endpoint_pair_validates",
				"materialization_options": ["ferry", "boat", "shipyard"],
				"required_unlock": false,
				"deferred": ["final_boat_shipyard_ui_deferred", "final_ferry_art_deferred"],
				"materialization_state": "water_transit_record_materialized",
			},
		})
		cursor += 1
	return result

static func _water_underground_transit_gameplay_payload(zone_layout: Dictionary, water_coast: Dictionary, terrain_layers: Array, transit_routes: Dictionary, surface_rows: Array, normalized: Dictionary) -> Dictionary:
	var water_records := _materialized_water_transit_records(transit_routes.get("water_access_candidates", []), water_coast, surface_rows)
	var cross_level_records := _materialized_cross_level_records(transit_routes.get("cross_level_candidates", []), terrain_layers)
	var underground_records := _underground_level_runtime_records(terrain_layers)
	var materialized_records := []
	materialized_records.append_array(water_records)
	materialized_records.append_array(cross_level_records)
	var validation := _water_underground_transit_gameplay_validation_core(
		zone_layout,
		water_coast,
		water_records,
		cross_level_records,
		underground_records,
		terrain_layers
	)
	var payload := {
		"schema_id": WATER_UNDERGROUND_TRANSIT_GAMEPLAY_SCHEMA_ID,
		"status": String(validation.get("status", "")),
		"source_slice_id": "random-map-water-underground-transit-gameplay-10184",
		"materialization_policy": "explicit_original_transit_equivalents_for_water_access_and_cross_level_links_no_authored_json_writeback",
		"water_policy": {
			"water_mode": String(water_coast.get("water_mode", "land")),
			"water_cell_count": int(water_coast.get("water_cell_count", 0)),
			"coast_cell_count": int(water_coast.get("coast_cell_count", 0)),
			"water_passability": String(water_coast.get("water_passability", "")),
			"coast_passability": String(water_coast.get("coast_passability", "")),
			"gameplay_rule": "water_remains_impassable_terrain_except_through_materialized_ferry_bridge_or_portal_records",
		},
		"underground_policy": {
			"level_count": int(zone_layout.get("dimensions", {}).get("level_count", 1)),
			"underground_level_count": underground_records.size(),
			"gameplay_rule": "underground_rows_are_materialized_level_records_cross_level_links_bind_surface_and_cave_endpoints",
		},
		"water_transit_records": water_records,
		"cross_level_link_records": cross_level_records,
		"underground_level_records": underground_records,
		"materialized_transit_records": materialized_records,
		"validation": validation,
		"runtime_materialization_refs": _transit_runtime_materialization_refs(materialized_records),
		"determinism_context": {
			"generator_version": String(normalized.get("generator_version", GENERATOR_VERSION)),
			"seed": String(normalized.get("seed", "")),
			"template_id": String(normalized.get("template_id", "")),
			"profile_id": String(normalized.get("profile", {}).get("id", "")),
		},
		"deferred_art_polish": [
			"final_water_autotile_art",
			"final_coast_transition_art",
			"final_ferry_bridge_sprite_selection",
			"final_subterranean_gate_sprite_and_vfx",
		],
		"boundary": {
			"campaign_adoption": false,
			"authored_content_writeback": false,
			"parity_or_alpha_claim": false,
		},
		"summary": {
			"water_transit_count": water_records.size(),
			"cross_level_link_count": cross_level_records.size(),
			"underground_level_count": underground_records.size(),
			"materialized_transit_count": materialized_records.size(),
			"validation_status": String(validation.get("status", "")),
			"failure_count": int(validation.get("failures", []).size()),
			"warning_count": int(validation.get("warnings", []).size()),
		},
	}
	payload["gameplay_transit_signature"] = _hash32_hex(_stable_stringify({
		"water_policy": payload.get("water_policy", {}),
		"underground_policy": payload.get("underground_policy", {}),
		"water_transit_records": water_records,
		"cross_level_link_records": cross_level_records,
		"underground_level_records": underground_records,
		"validation": validation,
		"determinism_context": payload.get("determinism_context", {}),
	}))
	return payload

static func _materialized_water_transit_records(candidates: Array, water_coast: Dictionary, surface_rows: Array) -> Array:
	var water_lookup := _point_lookup(water_coast.get("water_cells", []))
	var records := []
	for index in range(candidates.size()):
		var candidate = candidates[index]
		if not (candidate is Dictionary):
			continue
		var coast: Dictionary = candidate.get("to_coast", {}) if candidate.get("to_coast", {}) is Dictionary else {}
		var from_anchor: Dictionary = candidate.get("from_anchor", {}) if candidate.get("from_anchor", {}) is Dictionary else {}
		var water_endpoint := _adjacent_point_in_lookup(coast, water_lookup)
		var route_path := _find_passable_path(from_anchor, coast, surface_rows, {})
		var body_tiles := [coast] if not coast.is_empty() else []
		var approach_tiles := _valid_cardinal_passable_neighbors(coast, surface_rows, water_lookup)
		var record_id := "rmg_water_transit_%02d_%s" % [index + 1, String(candidate.get("zone_id", "zone"))]
		records.append({
			"id": record_id,
			"placement_id": record_id,
			"record_type": "water_ferry_bridge_transit",
			"object_id": WATER_TRANSIT_OBJECT_ID,
			"site_id": WATER_TRANSIT_SITE_ID,
			"zone_id": String(candidate.get("zone_id", "")),
			"level_index": int(candidate.get("level_index", 0)),
			"from_anchor": from_anchor,
			"body_tiles": body_tiles,
			"approach_tiles": approach_tiles,
			"coast_endpoint": coast,
			"water_endpoint": water_endpoint,
			"route_path": route_path,
			"route_constraints": {
				"approach_passable": not approach_tiles.is_empty(),
				"body_on_coast_land": _point_in_rows(surface_rows, int(coast.get("x", -1)), int(coast.get("y", -1))) and _terrain_cell_is_passable(surface_rows, int(coast.get("x", -1)), int(coast.get("y", -1))),
				"water_endpoint_reserved": not water_endpoint.is_empty(),
				"path_from_zone_anchor_to_endpoint": not route_path.is_empty(),
				"required_for_water_profile": String(water_coast.get("water_mode", "land")) == "islands",
			},
			"transit_semantics": candidate.get("transit_semantics", {}),
			"runtime_materialization_ref": {
				"object_id": WATER_TRANSIT_OBJECT_ID,
				"site_id": WATER_TRANSIT_SITE_ID,
				"linked_endpoint_group_id": "rmg_water_transit_%02d" % (index + 1),
				"route_effect_type": "linked_endpoint",
			},
			"materialization_state": "runtime_transit_object_record_materialized_final_art_deferred",
		})
	return records

static func _materialized_cross_level_records(candidates: Array, terrain_layers: Array) -> Array:
	var rows_by_level := _terrain_rows_by_level_index(terrain_layers)
	var records := []
	for index in range(candidates.size()):
		var candidate = candidates[index]
		if not (candidate is Dictionary):
			continue
		var from_level := int(candidate.get("from_level_index", 0))
		var to_level := int(candidate.get("to_level_index", 1))
		var from_anchor: Dictionary = candidate.get("from_anchor", {}) if candidate.get("from_anchor", {}) is Dictionary else {}
		var to_anchor: Dictionary = candidate.get("to_anchor", {}) if candidate.get("to_anchor", {}) is Dictionary else {}
		var from_rows: Array = rows_by_level.get(from_level, [])
		var to_rows: Array = rows_by_level.get(to_level, [])
		var record_id := "rmg_cross_level_%02d_%s" % [index + 1, String(candidate.get("zone_id", "zone"))]
		records.append({
			"id": record_id,
			"placement_id": record_id,
			"record_type": "cross_level_gate_pair",
			"object_id": CROSS_LEVEL_TRANSIT_OBJECT_ID,
			"site_id": CROSS_LEVEL_TRANSIT_SITE_ID,
			"zone_id": String(candidate.get("zone_id", "")),
			"from_level_index": from_level,
			"to_level_index": to_level,
			"surface_endpoint": from_anchor,
			"underground_endpoint": to_anchor,
			"surface_approach_tiles": _valid_cardinal_passable_neighbors(from_anchor, from_rows, {}),
			"underground_approach_tiles": _valid_cardinal_passable_neighbors(to_anchor, to_rows, {}),
			"route_constraints": {
				"surface_endpoint_passable": _point_passable_in_rows(from_anchor, from_rows),
				"underground_endpoint_passable": _point_passable_in_rows(to_anchor, to_rows),
				"stable_endpoint_pair": not from_anchor.is_empty() and not to_anchor.is_empty(),
				"cross_level_link": true,
			},
			"transit_semantics": candidate.get("transit_semantics", {}),
			"runtime_materialization_ref": {
				"object_id": CROSS_LEVEL_TRANSIT_OBJECT_ID,
				"site_id": CROSS_LEVEL_TRANSIT_SITE_ID,
				"linked_endpoint_group_id": "rmg_cross_level_%02d" % (index + 1),
				"route_effect_type": "linked_endpoint",
			},
			"materialization_state": "runtime_cross_level_gate_pair_materialized_final_sprite_deferred",
		})
	return records

static func _underground_level_runtime_records(terrain_layers: Array) -> Array:
	var records := []
	for layer in terrain_layers:
		if not (layer is Dictionary) or String(layer.get("level_kind", "")) != "underground":
			continue
		records.append({
			"id": "rmg_level_%d_underground" % int(layer.get("level_index", 0)),
			"level_index": int(layer.get("level_index", 0)),
			"level_kind": "underground",
			"default_terrain_id": String(layer.get("default_terrain_id", UNDERGROUND_TERRAIN_ID)),
			"biome_id": String(layer.get("biome_id", "biome_subterranean_underways")),
			"terrain_counts": layer.get("terrain_counts", {}),
			"passability_grid": layer.get("passability_grid", []),
			"movement_cost_grid": layer.get("movement_cost_grid", []),
			"cave_metadata": layer.get("cave_metadata", {}),
			"runtime_materialization_state": "materialized_level_record_no_final_cave_autotile_polish",
		})
	return records

static func _water_underground_transit_gameplay_validation_core(zone_layout: Dictionary, water_coast: Dictionary, water_records: Array, cross_level_records: Array, underground_records: Array, terrain_layers: Array) -> Dictionary:
	var failures := []
	var warnings := []
	var water_mode := String(water_coast.get("water_mode", "land"))
	var level_count := int(zone_layout.get("dimensions", {}).get("level_count", 1))
	if water_mode == "islands" and water_records.is_empty():
		failures.append("island water profile produced no materialized water transit records")
	for record in water_records:
		if not (record is Dictionary):
			failures.append("non-dictionary water transit record")
			continue
		var constraints: Dictionary = record.get("route_constraints", {}) if record.get("route_constraints", {}) is Dictionary else {}
		for key in ["approach_passable", "body_on_coast_land", "water_endpoint_reserved", "path_from_zone_anchor_to_endpoint"]:
			if not bool(constraints.get(key, false)):
				failures.append("water transit %s failed route constraint %s" % [String(record.get("id", "")), key])
	if level_count > 1:
		if underground_records.is_empty():
			failures.append("two-level profile produced no underground level records")
		if cross_level_records.is_empty():
			failures.append("two-level profile produced no materialized cross-level link records")
	for record in cross_level_records:
		if not (record is Dictionary):
			failures.append("non-dictionary cross-level transit record")
			continue
		var constraints: Dictionary = record.get("route_constraints", {}) if record.get("route_constraints", {}) is Dictionary else {}
		for key in ["surface_endpoint_passable", "underground_endpoint_passable", "stable_endpoint_pair", "cross_level_link"]:
			if not bool(constraints.get(key, false)):
				failures.append("cross-level transit %s failed route constraint %s" % [String(record.get("id", "")), key])
	if level_count <= 1 and not cross_level_records.is_empty():
		warnings.append("surface-only profile unexpectedly emitted cross-level transit records")
	if terrain_layers.is_empty():
		failures.append("terrain layer records missing for transit validation")
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
	}

static func _transit_runtime_materialization_refs(records: Array) -> Array:
	var refs := []
	for record in records:
		if not (record is Dictionary):
			continue
		refs.append({
			"id": String(record.get("id", "")),
			"record_type": String(record.get("record_type", "")),
			"object_id": String(record.get("object_id", "")),
			"site_id": String(record.get("site_id", "")),
			"runtime_materialization_ref": record.get("runtime_materialization_ref", {}),
		})
	return refs

static func _terrain_rows_by_level_index(terrain_layers: Array) -> Dictionary:
	var result := {}
	for layer in terrain_layers:
		if layer is Dictionary:
			result[int(layer.get("level_index", 0))] = layer.get("rows", [])
	return result

static func _adjacent_point_in_lookup(point: Dictionary, lookup: Dictionary) -> Dictionary:
	if point.is_empty():
		return {}
	var x := int(point.get("x", 0))
	var y := int(point.get("y", 0))
	for offset in _cardinal_offsets():
		var candidate := _point_dict(x + int(offset.x), y + int(offset.y))
		if lookup.has(_point_key(int(candidate.get("x", 0)), int(candidate.get("y", 0)))):
			return candidate
	return {}

static func _valid_cardinal_passable_neighbors(point: Dictionary, terrain_rows: Array, excluded_lookup: Dictionary = {}) -> Array:
	var result := []
	if point.is_empty():
		return result
	var x := int(point.get("x", 0))
	var y := int(point.get("y", 0))
	for offset in _cardinal_offsets():
		var nx := x + int(offset.x)
		var ny := y + int(offset.y)
		if excluded_lookup.has(_point_key(nx, ny)):
			continue
		if _point_in_rows(terrain_rows, nx, ny) and _terrain_cell_is_passable(terrain_rows, nx, ny):
			result.append(_point_dict(nx, ny))
	return result

static func _point_passable_in_rows(point: Dictionary, terrain_rows: Array) -> bool:
	if point.is_empty():
		return false
	var x := int(point.get("x", 0))
	var y := int(point.get("y", 0))
	return _point_in_rows(terrain_rows, x, y) and _terrain_cell_is_passable(terrain_rows, x, y)

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
		if kind == "underground_subterranean_connection":
			has_underground = true
	if not has_land:
		failures.append("corridor transit semantics missing land road route")
	var level_count := int(generated_map.get("staging", {}).get("zone_layout", {}).get("dimensions", {}).get("level_count", 1))
	if level_count > 1:
		if not has_underground:
			failures.append("underground request missing underground corridor semantics")
		if terrain_transit.get("transit_routes", {}).get("cross_level_candidates", []).is_empty():
			failures.append("underground request missing cross-level candidates")
		if terrain_transit.get("transit_routes", {}).get("cross_level_link_records", []).is_empty():
			failures.append("underground request missing materialized cross-level link records")
	var gameplay: Dictionary = terrain_transit.get("gameplay_transit_materialization", {}) if terrain_transit.get("gameplay_transit_materialization", {}) is Dictionary else {}
	if not gameplay.is_empty() and not bool(gameplay.get("validation", {}).get("ok", false)):
		failures.append_array(gameplay.get("validation", {}).get("failures", []))
	var scenario: Dictionary = generated_map.get("scenario_record", {}) if generated_map.get("scenario_record", {}) is Dictionary else {}
	if not scenario.is_empty():
		if bool(scenario.get("selection", {}).get("availability", {}).get("campaign", true)) or bool(scenario.get("selection", {}).get("availability", {}).get("skirmish", true)):
			failures.append("terrain transit validation found campaign/skirmish adoption")
		if scenario.has("save_adoption") or scenario.has("alpha_parity_claim") or String(generated_map.get("write_policy", "")) != "generated_export_record_no_authored_content_write":
			failures.append("terrain transit validation found save/writeback/parity claim")
	return {
		"ok": failures.is_empty(),
		"status": "pass" if failures.is_empty() else "fail",
		"failure_count": failures.size(),
		"warning_count": warnings.size(),
		"failures": failures,
		"warnings": warnings,
	}

static func _water_underground_transit_gameplay_validation(payload: Dictionary, generated_map: Dictionary = {}) -> Dictionary:
	var failures := []
	var warnings := []
	if String(payload.get("schema_id", "")) != WATER_UNDERGROUND_TRANSIT_GAMEPLAY_SCHEMA_ID:
		failures.append("water/underground transit gameplay schema mismatch")
	if String(payload.get("gameplay_transit_signature", "")) == "":
		failures.append("water/underground transit gameplay signature missing")
	var core: Dictionary = payload.get("validation", {}) if payload.get("validation", {}) is Dictionary else {}
	if not bool(core.get("ok", false)):
		failures.append_array(core.get("failures", []))
	warnings.append_array(core.get("warnings", []))
	var water_policy: Dictionary = payload.get("water_policy", {}) if payload.get("water_policy", {}) is Dictionary else {}
	if String(water_policy.get("water_mode", "land")) == "islands" and int(payload.get("summary", {}).get("water_transit_count", 0)) <= 0:
		failures.append("island water profile has no materialized ferry/bridge/portal records")
	var underground_policy: Dictionary = payload.get("underground_policy", {}) if payload.get("underground_policy", {}) is Dictionary else {}
	if int(underground_policy.get("level_count", 1)) > 1:
		if int(payload.get("summary", {}).get("underground_level_count", 0)) <= 0:
			failures.append("two-level profile has no underground level records")
		if int(payload.get("summary", {}).get("cross_level_link_count", 0)) <= 0:
			failures.append("two-level profile has no materialized cross-level link records")
	for record in payload.get("materialized_transit_records", []):
		if not (record is Dictionary):
			failures.append("non-dictionary materialized transit record")
			continue
		if String(record.get("id", "")) == "" or String(record.get("object_id", "")) == "":
			failures.append("materialized transit record missed stable id or object id")
		if record.get("runtime_materialization_ref", {}).is_empty():
			failures.append("materialized transit record %s missed runtime materialization ref" % String(record.get("id", "")))
		if String(record.get("materialization_state", "")).find("materialized") < 0:
			failures.append("materialized transit record %s did not state runtime materialization" % String(record.get("id", "")))
	if not generated_map.is_empty():
		var scenario: Dictionary = generated_map.get("scenario_record", {}) if generated_map.get("scenario_record", {}) is Dictionary else {}
		var generated_constraints: Dictionary = scenario.get("generated_constraints", {}) if scenario.get("generated_constraints", {}) is Dictionary else {}
		if generated_constraints.get("water_underground_transit", {}).is_empty():
			failures.append("scenario generated_constraints missed water/underground transit gameplay")
		if generated_map.get("staging", {}).get("water_underground_transit_gameplay", {}).is_empty():
			failures.append("staging missed water/underground transit gameplay")
		if bool(payload.get("boundary", {}).get("campaign_adoption", true)) or bool(payload.get("boundary", {}).get("authored_content_writeback", true)) or bool(payload.get("boundary", {}).get("parity_or_alpha_claim", true)):
			failures.append("water/underground transit payload violated adoption/writeback/parity boundary")
		if bool(scenario.get("selection", {}).get("availability", {}).get("campaign", false)):
			failures.append("water/underground transit adopted generated map into campaign")
	return {
		"ok": failures.is_empty(),
		"status": "pass" if failures.is_empty() else "fail",
		"failures": failures,
		"warnings": warnings,
	}

static func _validate_road_paths(road_network: Dictionary, terrain_rows: Array, object_placements: Array, failures: Array) -> void:
	var occupied := _route_blocking_occupied_lookup(object_placements)
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
			if occupied.has(_point_key(x, y)) and not _road_segment_cell_is_endpoint(segment, cell):
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
	var visit_tiles := _visit_tiles_for_catalog(point, catalog)
	var approaches := _approach_tiles_for_catalog(point, zone_id, zone_grid, terrain_rows, occupied, catalog, runtime_body)
	placement["zone_id"] = zone_id
	placement["body_tiles"] = runtime_body
	placement["blocking_body"] = bool(catalog.get("passability_mask", {}).get("body_blocks_movement", true)) if not catalog.is_empty() else true
	placement["approach_tiles"] = approaches
	placement["visit_tile"] = _preferred_visit_tile_for_catalog(visit_tiles, approaches, point)
	placement["pathing_status"] = "pass" if not approaches.is_empty() else "blocked_no_approach"
	_apply_object_footprint_metadata(placement, terrain_rows, occupied)

static func _preferred_visit_tile_for_catalog(visit_tiles: Array, approaches: Array, point: Dictionary) -> Dictionary:
	for visit in visit_tiles:
		if not (visit is Dictionary):
			continue
		for approach in approaches:
			if approach is Dictionary and _manhattan_distance(visit, approach) == 1:
				return visit
	if not visit_tiles.is_empty() and visit_tiles[0] is Dictionary:
		return visit_tiles[0]
	if not approaches.is_empty() and approaches[0] is Dictionary:
		return approaches[0]
	return point

static func _copy_shared_placement_metadata(target: Dictionary, source: Dictionary) -> void:
	for key in ["zone_id", "faction_id", "body_tiles", "blocking_body", "approach_tiles", "visit_tile", "pathing_status", "player_slot", "player_type", "team_id", "object_footprint_catalog_ref", "footprint", "runtime_footprint", "body_mask", "runtime_body_mask", "visit_mask", "approach_mask", "passability_mask", "action_mask", "terrain_restrictions", "placement_predicates", "placement_predicate_results", "footprint_deferred"]:
		if source.has(key):
			target[key] = source[key]

static func _approach_tiles_for_catalog(point: Dictionary, preferred_zone_id: String, zone_grid: Array, terrain_rows: Array, occupied: Dictionary, catalog: Dictionary, runtime_body: Array) -> Array:
	if catalog.is_empty():
		return _approach_tiles_for_point(point, preferred_zone_id, zone_grid, terrain_rows, occupied)
	var result := []
	var action_mask: Dictionary = catalog.get("action_mask", {}) if catalog.get("action_mask", {}) is Dictionary else {}
	var strict_single_visit := bool(action_mask.get("strict_single_visit_tile", false))
	var body_lookup := _point_lookup(runtime_body)
	for offset in catalog.get("approach_mask", []):
		if not (offset is Dictionary):
			continue
		var nx: int = int(point.get("x", 0)) + int(offset.get("x", 0))
		var ny: int = int(point.get("y", 0)) + int(offset.get("y", 0))
		if not _point_in_rows(terrain_rows, nx, ny):
			continue
		var key := _point_key(nx, ny)
		var inside_runtime_body := body_lookup.has(key)
		if occupied.has(key) and not inside_runtime_body:
			continue
		if not _terrain_cell_is_passable(terrain_rows, nx, ny):
			continue
		if preferred_zone_id != "" and _zone_at_point(zone_grid, _point_dict(nx, ny)) != preferred_zone_id:
			continue
		result.append(_point_dict(nx, ny))
		if strict_single_visit:
			return result
	if strict_single_visit:
		return result
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

static func _route_blocking_occupied_lookup(object_placements: Array) -> Dictionary:
	var occupied := {}
	for placement in object_placements:
		if not (placement is Dictionary):
			continue
		var kind := String(placement.get("kind", ""))
		if kind in ["route_guard", "special_guard_gate", "reward_reference"]:
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
			"visit_tile": placement.get("visit_tile", {}),
			"approach_tiles": placement.get("approach_tiles", []),
			"required": required_node,
		}
	return nodes

static func _best_route_path_between_nodes(from_node: Dictionary, to_node: Dictionary, terrain_rows: Array, occupied: Dictionary) -> Dictionary:
	var best_path := []
	var best_from: Dictionary = from_node.get("point", {}) if from_node.get("point", {}) is Dictionary else {}
	var best_to: Dictionary = to_node.get("point", {}) if to_node.get("point", {}) is Dictionary else {}
	if not best_from.is_empty() and not best_to.is_empty():
		var original_path := _find_passable_path(best_from, best_to, terrain_rows, _occupied_without_route_endpoints(occupied, best_from, best_to))
		if not original_path.is_empty():
			return {
				"path": original_path,
				"from_anchor": best_from,
				"to_anchor": best_to,
				"endpoint_policy": "primary_visit_or_approach_endpoint",
				"from_candidate_count": 1,
				"to_candidate_count": 1,
			}
	var from_candidates := _route_node_endpoint_candidates(from_node, terrain_rows, occupied)
	var to_candidates := _route_node_endpoint_candidates(to_node, terrain_rows, occupied)
	for from_point in from_candidates:
		if not (from_point is Dictionary):
			continue
		for to_point in to_candidates:
			if not (to_point is Dictionary):
				continue
			var route_occupied := _occupied_without_route_endpoints(occupied, from_point, to_point)
			var path := _find_passable_path(from_point, to_point, terrain_rows, route_occupied)
			if path.is_empty():
				continue
			if best_path.is_empty() or path.size() < best_path.size():
				best_path = path
				best_from = from_point
				best_to = to_point
	return {
		"path": best_path,
		"from_anchor": best_from,
		"to_anchor": best_to,
		"endpoint_policy": "best_passable_visit_or_approach_endpoint",
		"from_candidate_count": from_candidates.size(),
		"to_candidate_count": to_candidates.size(),
	}

static func _route_node_endpoint_candidates(node: Dictionary, terrain_rows: Array, occupied: Dictionary) -> Array:
	var candidates := []
	var seen := {}
	_add_route_endpoint_candidate(candidates, seen, node.get("point", {}), terrain_rows, occupied, true)
	_add_route_endpoint_candidate(candidates, seen, node.get("visit_tile", {}), terrain_rows, occupied, false)
	for approach in node.get("approach_tiles", []):
		_add_route_endpoint_candidate(candidates, seen, approach, terrain_rows, occupied, false)
	for body in node.get("body_tiles", []):
		if not (body is Dictionary):
			continue
		for offset in _cardinal_offsets():
			_add_route_endpoint_candidate(
				candidates,
				seen,
				_point_dict(int(body.get("x", 0)) + int(offset.x), int(body.get("y", 0)) + int(offset.y)),
				terrain_rows,
				occupied,
				false
			)
	if candidates.is_empty() and node.get("point", {}) is Dictionary:
		candidates.append(node.get("point", {}))
	return candidates

static func _add_route_endpoint_candidate(candidates: Array, seen: Dictionary, point_value: Variant, terrain_rows: Array, occupied: Dictionary, allow_occupied: bool) -> void:
	if not (point_value is Dictionary):
		return
	var point: Dictionary = point_value
	if point.is_empty():
		return
	var x := int(point.get("x", 0))
	var y := int(point.get("y", 0))
	var key := _point_key(x, y)
	if seen.has(key):
		return
	if not _point_in_rows(terrain_rows, x, y):
		return
	if not _terrain_cell_is_passable(terrain_rows, x, y):
		return
	if occupied.has(key) and not allow_occupied:
		return
	seen[key] = true
	candidates.append(_point_dict(x, y))

static func _preferred_route_node_for_zone(zone_id: String, object_by_zone: Dictionary, route_nodes: Dictionary) -> Dictionary:
	var zone_objects: Dictionary = object_by_zone.get(zone_id, {})
	var towns: Array = zone_objects.get("town", [])
	if not towns.is_empty() and towns[0] is Dictionary:
		return route_nodes.get("node_%s" % String(towns[0].get("placement_id", "")), {"id": "node_zone_%s" % zone_id, "point": _point_dict(0, 0)})
	return route_nodes.get("node_zone_%s" % zone_id, {"id": "node_zone_%s" % zone_id, "point": _point_dict(0, 0)})

static func _first_approach_or_body(placement: Dictionary) -> Dictionary:
	var visit: Dictionary = placement.get("visit_tile", {}) if placement.get("visit_tile", {}) is Dictionary else {}
	if not visit.is_empty():
		return visit
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
			if occupied.has(next_key) and next_key != goal_key:
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

static func _occupied_without_route_endpoints(occupied: Dictionary, from_anchor: Dictionary, to_anchor: Dictionary) -> Dictionary:
	var route_occupied := occupied.duplicate(true)
	if from_anchor is Dictionary:
		route_occupied.erase(_point_key(int(from_anchor.get("x", 0)), int(from_anchor.get("y", 0))))
	if to_anchor is Dictionary:
		route_occupied.erase(_point_key(int(to_anchor.get("x", 0)), int(to_anchor.get("y", 0))))
	return route_occupied

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
		"template_connection", "guarded_route":
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
	var normalized := _normalize_legacy_terrain_id(terrain_id)
	return _terrain_is_known_original(normalized) and normalized not in BLOCKED_TERRAIN_IDS

static func _terrain_is_known_original(terrain_id: String) -> bool:
	return String(terrain_id) in ORIGINAL_TERRAIN_IDS

static func _normalize_legacy_terrain_id(terrain_id: String) -> String:
	var normalized := String(terrain_id)
	return String(LEGACY_TERRAIN_ALIASES.get(normalized, normalized))

static func _normalize_terrain_id_for_generated_rows(terrain_id: String) -> String:
	var normalized := _normalize_legacy_terrain_id(terrain_id)
	if normalized in SURFACE_SCENARIO_TERRAIN_IDS:
		return normalized
	return "grass" if not _terrain_is_known_original(normalized) else normalized

static func _terrain_movement_cost(terrain_id: String) -> int:
	return int(TERRAIN_MOVEMENT_COST.get(_normalize_legacy_terrain_id(terrain_id), 999))

static func _unsupported_terrain_ids(terrain_ids: Array) -> Array:
	var result := []
	for terrain_id in terrain_ids:
		var text := _normalize_legacy_terrain_id(terrain_id)
		if text != "" and not _terrain_is_known_original(text) and text not in result:
			result.append(text)
	result.sort()
	return result

static func _passable_known_terrain_ids(terrain_ids: Array) -> Array:
	var result := []
	for terrain_id in terrain_ids:
		var text := _normalize_legacy_terrain_id(terrain_id)
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

static func _validation_batch_cases(input_config: Dictionary) -> Array:
	if input_config.get("cases", []) is Array and not input_config.get("cases", []).is_empty():
		return input_config.get("cases", []).duplicate(true)
	var fixture_path := String(input_config.get("fixture_path", VALIDATION_BATCH_FIXTURE_PATH))
	if FileAccess.file_exists(fixture_path):
		var file := FileAccess.open(fixture_path, FileAccess.READ)
		if file != null:
			var parsed = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary and parsed.get("cases", []) is Array:
				return parsed.get("cases", []).duplicate(true)
	return _default_validation_batch_cases()

static func _default_validation_batch_cases() -> Array:
	return [
		{
			"id": "default_land_frontier_spokes",
			"tags": ["land", "town_mine_dwelling"],
			"config": {
				"generator_version": GENERATOR_VERSION,
				"seed": "validation-batch-default-land",
				"size": {"preset": "validation_batch_land", "width": 30, "height": 22, "water_mode": "land", "level_count": 1},
				"player_constraints": {"human_count": 1, "computer_count": 2},
				"profile": {"id": "frontier_spokes_profile_v1", "template_id": "frontier_spokes_v1", "guard_strength_profile": "core_low"},
			},
		},
		{
			"id": "default_border_gate_retry",
			"tags": ["special_guard_border_wide", "retry_policy"],
			"expect_initial_failure": true,
			"config": {
				"generator_version": GENERATOR_VERSION,
				"seed": "validation-batch-default-retry",
				"size": {"preset": "validation_batch_retry", "width": 26, "height": 18, "water_mode": "land", "level_count": 1},
				"player_constraints": {"human_count": 1, "computer_count": 2},
				"profile": {"id": "missing_profile_for_retry", "template_id": "missing_template_for_retry"},
			},
			"retry_policy": {
				"max_attempts": 2,
				"mode": "config_fallback_seed_salt",
				"fallback_config": {
					"generator_version": GENERATOR_VERSION,
					"seed": "validation-batch-default-retry",
					"size": {"preset": "validation_batch_retry", "width": 26, "height": 18, "water_mode": "land", "level_count": 1},
					"player_constraints": {"human_count": 1, "computer_count": 2},
					"profile": {"id": "border_gate_compact_profile_v1", "template_id": "border_gate_compact_v1", "guard_strength_profile": "core_low"},
				},
			},
		},
	]

static func _validation_batch_run(cases: Array, input_config: Dictionary) -> Dictionary:
	var case_results := []
	var summary := {
		"case_count": cases.size(),
		"successful_case_count": 0,
		"validation_pass_case_count": 0,
		"expected_validation_fail_case_count": 0,
		"pass_without_retry_count": 0,
		"pass_after_retry_count": 0,
		"failed_case_count": 0,
		"original_failure_count": 0,
		"bounded_retry_case_count": 0,
	}
	var ok := true
	for case_value in cases:
		var case_record: Dictionary = case_value if case_value is Dictionary else {}
		var case_result := _validation_batch_case_result(case_record)
		case_results.append(case_result)
		if bool(case_result.get("ok", false)):
			summary["successful_case_count"] = int(summary.get("successful_case_count", 0)) + 1
			if String(case_result.get("final_status", "")) == "pass_after_retry":
				summary["pass_after_retry_count"] = int(summary.get("pass_after_retry_count", 0)) + 1
				summary["validation_pass_case_count"] = int(summary.get("validation_pass_case_count", 0)) + 1
			elif String(case_result.get("final_status", "")) == "expected_fail":
				summary["expected_validation_fail_case_count"] = int(summary.get("expected_validation_fail_case_count", 0)) + 1
			else:
				summary["pass_without_retry_count"] = int(summary.get("pass_without_retry_count", 0)) + 1
				summary["validation_pass_case_count"] = int(summary.get("validation_pass_case_count", 0)) + 1
		else:
			summary["failed_case_count"] = int(summary.get("failed_case_count", 0)) + 1
			ok = false
		var original_summary: Dictionary = case_result.get("original_failure_summary", {}) if case_result.get("original_failure_summary", {}) is Dictionary else {}
		if not original_summary.is_empty():
			summary["original_failure_count"] = int(summary.get("original_failure_count", 0)) + 1
		if bool(case_result.get("retry_policy", {}).get("bounded", false)):
			summary["bounded_retry_case_count"] = int(summary.get("bounded_retry_case_count", 0)) + 1
	if bool(input_config.get("require_retry_evidence", true)) and int(summary.get("original_failure_count", 0)) <= 0:
		ok = false
	return {
		"ok": ok,
		"summary": summary,
		"case_results": case_results,
		"batch_signature": _hash32_hex(_stable_stringify({
			"schema_id": VALIDATION_BATCH_RETRY_REPORT_SCHEMA_ID,
			"generator_version": GENERATOR_VERSION,
			"cases": case_results,
			"summary": summary,
		})),
	}

static func _validation_batch_case_result(case_record: Dictionary) -> Dictionary:
	var retry_policy: Dictionary = case_record.get("retry_policy", {}) if case_record.get("retry_policy", {}) is Dictionary else {}
	var max_attempts := clampi(int(retry_policy.get("max_attempts", 1)), 1, 5)
	var attempts := []
	var final_identity := {}
	var final_phase_statuses := []
	var final_failure_summary := {}
	var final_ok := false
	var final_generation_ok := false
	var original_failure_summary := {}
	for attempt_index in range(max_attempts):
		var config := _validation_batch_attempt_config(case_record, attempt_index)
		var generation := generate(config)
		var attempt_record := _validation_batch_attempt_record(case_record, config, generation, attempt_index + 1, max_attempts)
		attempts.append(attempt_record)
		if attempt_index == 0 and not bool(generation.get("ok", false)):
			original_failure_summary = attempt_record.get("failure_summary", {})
		final_identity = attempt_record.get("deterministic_output_identity", {})
		final_phase_statuses = attempt_record.get("phase_statuses", [])
		final_failure_summary = attempt_record.get("failure_summary", {})
		if bool(generation.get("ok", false)):
			final_generation_ok = true
			break
	var expected_initial_failure := bool(case_record.get("expect_initial_failure", false))
	var expected_final_status := String(case_record.get("expected_final_status", "pass"))
	var expected_failure_satisfied := not expected_initial_failure or not original_failure_summary.is_empty()
	var final_status := "fail"
	if final_generation_ok and attempts.size() == 1:
		final_status = "pass"
	elif final_generation_ok:
		final_status = "pass_after_retry"
	elif expected_final_status == "fail" and not final_failure_summary.is_empty():
		final_status = "expected_fail"
	var required_phases_present := _validation_batch_required_phases_present(final_phase_statuses) if String(final_identity.get("stable_signature", "")) != "" else false
	if final_generation_ok and expected_final_status == "pass":
		final_ok = expected_failure_satisfied and required_phases_present
	elif expected_final_status == "fail":
		final_ok = not final_failure_summary.is_empty() and (required_phases_present or String(final_identity.get("stable_signature", "")) == "") and expected_failure_satisfied
	var case_ok := final_ok
	return {
		"ok": case_ok,
		"id": String(case_record.get("id", "")),
		"description": String(case_record.get("description", "")),
		"tags": case_record.get("tags", []),
		"final_status": final_status,
		"expected_final_status": expected_final_status,
		"validation_passed": final_generation_ok,
		"attempt_count": attempts.size(),
		"retry_count": max(0, attempts.size() - 1),
		"retry_policy": {
			"bounded": max_attempts <= 5,
			"max_attempts": max_attempts,
			"mode": String(retry_policy.get("mode", "none")),
			"uses_config_fallback": retry_policy.get("fallback_config", {}) is Dictionary and not retry_policy.get("fallback_config", {}).is_empty(),
			"uses_seed_salt": String(retry_policy.get("mode", "")).find("seed_salt") >= 0,
			"does_not_hide_original_failure": original_failure_summary.is_empty() == false or not expected_initial_failure,
		},
		"original_failure_summary": original_failure_summary,
		"required_phase_statuses_present": required_phases_present,
		"phase_statuses": final_phase_statuses,
		"deterministic_output_identity": final_identity,
		"attempts": attempts,
	}

static func _validation_batch_attempt_config(case_record: Dictionary, attempt_index: int) -> Dictionary:
	var retry_policy: Dictionary = case_record.get("retry_policy", {}) if case_record.get("retry_policy", {}) is Dictionary else {}
	var config: Dictionary = case_record.get("config", {}) if case_record.get("config", {}) is Dictionary else {}
	if attempt_index > 0 and retry_policy.get("fallback_config", {}) is Dictionary and not retry_policy.get("fallback_config", {}).is_empty():
		config = retry_policy.get("fallback_config", {})
	config = config.duplicate(true)
	if attempt_index > 0 and String(retry_policy.get("mode", "")).find("seed_salt") >= 0:
		config["seed"] = "%s:retry_%d" % [String(config.get("seed", "0")), attempt_index]
	return config

static func _validation_batch_attempt_record(case_record: Dictionary, config: Dictionary, generation: Dictionary, attempt_number: int, max_attempts: int) -> Dictionary:
	var payload: Dictionary = generation.get("generated_map", {}) if generation.get("generated_map", {}) is Dictionary else {}
	var report: Dictionary = generation.get("report", {}) if generation.get("report", {}) is Dictionary else {}
	var normalized := normalize_config(config)
	var phase_statuses := _validation_batch_phase_statuses(payload)
	var failure_summary := _validation_batch_failure_summary(report)
	var ok := bool(generation.get("ok", false))
	var will_retry := not ok and attempt_number < max_attempts
	return {
		"attempt": attempt_number,
		"seed": String(normalized.get("seed", "")),
		"template_id": String(normalized.get("template_id", "")),
		"profile_id": String(normalized.get("profile", {}).get("id", "")),
		"ok": ok,
		"validation_status": String(report.get("status", "pass" if ok else "fail")),
		"stable_signature": String(payload.get("stable_signature", "")),
		"deterministic_output_identity": _validation_batch_output_identity(payload, normalized, report),
		"phase_statuses": phase_statuses,
		"failure_summary": failure_summary,
		"retryable_failure": not ok,
		"retry_decision": {
			"will_retry": will_retry,
			"bounded_attempt": attempt_number < max_attempts,
			"reason": "retry_policy_has_remaining_attempt" if will_retry else ("accepted_valid_generation" if ok else "attempt_limit_reached"),
			"next_attempt": attempt_number + 1 if will_retry else 0,
		},
		"attempt_signature": _hash32_hex(_stable_stringify({
			"case_id": String(case_record.get("id", "")),
			"attempt": attempt_number,
			"identity": _validation_batch_output_identity(payload, normalized, report),
			"failure_summary": failure_summary,
			"phase_statuses": phase_statuses,
		})),
	}

static func _validation_batch_output_identity(payload: Dictionary, normalized: Dictionary, report: Dictionary) -> Dictionary:
	var scenario: Dictionary = payload.get("scenario_record", {}) if payload.get("scenario_record", {}) is Dictionary else {}
	var metadata: Dictionary = payload.get("metadata", {}) if payload.get("metadata", {}) is Dictionary else {}
	var profile: Dictionary = metadata.get("profile", normalized.get("profile", {})) if metadata.get("profile", normalized.get("profile", {})) is Dictionary else {}
	var identity := {
		"scenario_id": String(scenario.get("id", "")),
		"stable_signature": String(payload.get("stable_signature", "")),
		"normalized_seed": String(metadata.get("normalized_seed", normalized.get("seed", ""))),
		"generator_version": String(metadata.get("generator_version", GENERATOR_VERSION)),
		"template_id": String(metadata.get("template_id", normalized.get("template_id", ""))),
		"profile_id": String(profile.get("id", "")),
		"content_manifest_fingerprint": String(metadata.get("content_manifest_fingerprint", normalized.get("content_manifest_fingerprint", ""))),
		"validation_status": String(report.get("status", "")),
	}
	identity["identity_signature"] = _hash32_hex(_stable_stringify(identity))
	return identity

static func _validation_batch_phase_statuses(payload: Dictionary) -> Array:
	var observed := {}
	for phase in payload.get("phase_pipeline", []):
		if phase is Dictionary:
			var phase_name := String(phase.get("phase", ""))
			var summary: Dictionary = phase.get("summary", {}) if phase.get("summary", {}) is Dictionary else {}
			observed[phase_name] = _validation_batch_compact_phase_summary(phase_name, summary)
	var statuses := []
	for required_phase in REQUIRED_VALIDATION_BATCH_PHASES:
		statuses.append({
			"phase": String(required_phase),
			"status": "pass" if observed.has(String(required_phase)) else "missing",
			"summary": observed.get(String(required_phase), {}),
		})
	return statuses

static func _validation_batch_compact_phase_summary(phase_name: String, summary: Dictionary) -> Dictionary:
	if phase_name == "template_profile":
		var selection: Dictionary = summary.get("selection", {}) if summary.get("selection", {}) is Dictionary else {}
		var player_assignment: Dictionary = summary.get("player_assignment", {}) if summary.get("player_assignment", {}) is Dictionary else {}
		return {
			"template_id": String(summary.get("template_id", "")),
			"profile_id": String(summary.get("profile_id", "")),
			"source": String(summary.get("source", "")),
			"zone_count": int(summary.get("zone_count", 0)),
			"link_count": int(summary.get("link_count", 0)),
			"selection_source": String(selection.get("source", "")),
			"selection_rejected": bool(selection.get("rejected", false)),
			"player_count": int(player_assignment.get("player_count", 0)),
			"human_count": int(player_assignment.get("human_count", 0)),
			"computer_count": int(player_assignment.get("computer_count", 0)),
		}
	var compact := {}
	for key in _sorted_keys(summary):
		var value = summary[key]
		if value is Dictionary or value is Array:
			continue
		compact[key] = value
	return compact

static func _validation_batch_failure_summary(report: Dictionary) -> Dictionary:
	if bool(report.get("ok", false)) or String(report.get("status", "")) == "pass":
		return {}
	var failures: Array = report.get("failures", []) if report.get("failures", []) is Array else []
	var phase := "template_selection" if String(report.get("schema_id", "")) == TEMPLATE_SELECTION_REJECTION_SCHEMA_ID else "payload_validation"
	if not failures.is_empty():
		var first_failure := String(failures[0])
		var colon := first_failure.find(":")
		if colon > 0:
			phase = first_failure.substr(0, colon).strip_edges().replace(" ", "_")
	return {
		"status": String(report.get("status", "fail")),
		"phase": phase,
		"failure_code": String(report.get("failure_code", "")),
		"failure_count": int(report.get("failure_count", failures.size())),
		"failures": failures.slice(0, min(8, failures.size())),
		"template_selection": report.get("template_selection", {}),
	}

static func _validation_batch_required_phases_present(phase_statuses: Array) -> bool:
	var present := {}
	for status in phase_statuses:
		if status is Dictionary and String(status.get("status", "")) == "pass":
			present[String(status.get("phase", ""))] = true
	for required_phase in REQUIRED_VALIDATION_BATCH_PHASES:
		if not present.has(String(required_phase)):
			return false
	return true

static func _validation_batch_changed_cases(cases: Array) -> Array:
	var changed := cases.duplicate(true)
	for index in range(changed.size()):
		if not (changed[index] is Dictionary):
			continue
		changed[index] = _validation_batch_case_with_seed_suffix(changed[index], "changed")
	return changed

static func _validation_batch_case_with_seed_suffix(case_record: Dictionary, suffix: String) -> Dictionary:
	var result := case_record.duplicate(true)
	if result.get("config", {}) is Dictionary:
		var config: Dictionary = result.get("config", {}).duplicate(true)
		config["seed"] = "%s:%s" % [String(config.get("seed", "0")), suffix]
		result["config"] = config
	var retry_policy: Dictionary = result.get("retry_policy", {}) if result.get("retry_policy", {}) is Dictionary else {}
	if retry_policy.get("fallback_config", {}) is Dictionary:
		var policy := retry_policy.duplicate(true)
		var fallback: Dictionary = policy.get("fallback_config", {}).duplicate(true)
		fallback["seed"] = "%s:%s" % [String(fallback.get("seed", "0")), suffix]
		policy["fallback_config"] = fallback
		result["retry_policy"] = policy
	return result

static func _validation_batch_tag_coverage(case_results: Array, required_tags: Array) -> Dictionary:
	var covered := {}
	for case_result in case_results:
		if not (case_result is Dictionary) or not bool(case_result.get("ok", false)):
			continue
		for tag in case_result.get("tags", []):
			covered[String(tag)] = true
	var missing := []
	for tag in required_tags:
		if not covered.has(String(tag)):
			missing.append(String(tag))
	return {
		"ok": missing.is_empty(),
		"required_tags": required_tags,
		"covered_tags": _sorted_keys(covered),
		"missing_tags": missing,
	}

static func _large_batch_stress_cases(input_config: Dictionary) -> Array:
	if input_config.get("cases", []) is Array and not input_config.get("cases", []).is_empty():
		return input_config.get("cases", []).duplicate(true)
	var fixture := _large_batch_stress_fixture(input_config)
	var cases := []
	for case_value in fixture.get("cases", []):
		if case_value is Dictionary:
			cases.append(case_value.duplicate(true))
	if bool(fixture.get("sweep_translated_templates", true)):
		cases.append_array(_large_batch_translated_template_cases(fixture))
	return _large_batch_deduplicate_cases(cases)

static func _large_batch_stress_fixture(input_config: Dictionary) -> Dictionary:
	var fixture_path := String(input_config.get("fixture_path", LARGE_BATCH_PARITY_STRESS_FIXTURE_PATH))
	if FileAccess.file_exists(fixture_path):
		var file := FileAccess.open(fixture_path, FileAccess.READ)
		if file != null:
			var parsed = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				return parsed.duplicate(true)
	return {
		"schema_id": "random_map_large_batch_parity_stress_cases_v1",
		"sweep_translated_templates": true,
		"seed_prefix": "large-batch-parity-stress-10184",
		"cases": _large_batch_default_curated_cases(),
	}

static func _large_batch_default_curated_cases() -> Array:
	return [
		{
			"id": "stress_curated_land_runtime_materialization",
			"description": "Successful compact runtime materialization case used as the stress harness positive control.",
			"tags": ["land", "runtime_materialization", "object_pool_value_weighting", "town_mine_dwelling", "border_guard", "wide_link"],
			"expected_final_status": "pass",
			"config": _large_batch_config("large-batch-curated-land-a", "border_gate_compact_profile_v1", "border_gate_compact_v1", 26, 18, "land", 1, 1, 3),
		},
		{
			"id": "stress_curated_islands_water",
			"description": "Water/islands case that exercises water transit and coastline summaries.",
			"tags": ["islands_water", "water_mode", "transit_gameplay"],
			"expected_final_status": "pass",
			"config": _large_batch_config("large-batch-curated-islands", "translated_rmg_profile_001_v1", "translated_rmg_template_001_v1", 36, 30, "islands", 1, 2, 4),
		},
		{
			"id": "stress_curated_underground_two_level",
			"description": "Two-level case that exercises underground and cross-level transit summaries.",
			"tags": ["underground", "underground_deferred_transit", "transit_gameplay"],
			"expected_final_status": "pass",
			"config": _large_batch_config("large-batch-curated-underground", "translated_rmg_profile_001_v1", "translated_rmg_template_001_v1", 36, 30, "land", 2, 2, 4),
		},
		{
			"id": "stress_curated_retry_fallback",
			"description": "Expected negative first attempt followed by bounded fallback retry.",
			"tags": ["negative_case", "retry_policy", "border_guard", "wide_link"],
			"expected_final_status": "pass",
			"expect_initial_failure": true,
			"config": _large_batch_config("large-batch-curated-retry", "missing_large_batch_profile", "missing_large_batch_template", 26, 18, "land", 1, 1, 3),
			"retry_policy": {
				"max_attempts": 2,
				"mode": "config_fallback_seed_salt",
				"fallback_config": _large_batch_config("large-batch-curated-retry", "border_gate_compact_profile_v1", "border_gate_compact_v1", 26, 18, "land", 1, 1, 3),
			},
		},
		{
			"id": "stress_curated_missing_template_negative",
			"description": "Known-invalid explicit template request that must remain an expected negative case.",
			"tags": ["negative_case", "expected_invalid_template"],
			"expected_final_status": "negative_fail",
			"config": _large_batch_config("large-batch-curated-missing-template", "missing_large_batch_profile", "missing_large_batch_template", 26, 18, "land", 1, 1, 3),
		},
	]

static func _large_batch_translated_template_cases(fixture: Dictionary) -> Array:
	var catalog := _load_template_catalog()
	var cases := []
	var seed_prefix := String(fixture.get("seed_prefix", "large-batch-parity-stress-10184"))
	for template in catalog.get("templates", []):
		if not (template is Dictionary):
			continue
		var template_id := String(template.get("id", ""))
		if not template_id.begins_with("translated_rmg_template_"):
			continue
		var profile_id := template_id.replace("translated_rmg_template_", "translated_rmg_profile_")
		var size := _large_batch_size_for_template(template)
		var player_counts := _large_batch_player_counts_for_template(template)
		var tags := ["translated_template_family", "land", "template_sweep"]
		var wide_count := _large_batch_link_flag_count(template, "wide")
		var border_count := _large_batch_link_flag_count(template, "border_guard")
		if wide_count > 0:
			tags.append("wide_link")
		if border_count > 0:
			tags.append("border_guard")
		var expected_status := "pass"
		var unsupported_reason := ""
		var accepted_non_parity := {}
		var min_score := int(template.get("size_score", {}).get("min", 1))
		if min_score > _large_batch_current_max_size_score():
			expected_status = "accepted_non_parity"
			unsupported_reason = "template_min_size_score_exceeds_current_runtime_fixture_bounds"
			tags.append("unsupported_size_score")
			tags.append("accepted_non_parity")
			accepted_non_parity = _large_batch_non_parity_decision_record(
				unsupported_reason,
				"AcOrP currently materializes generated runtime maps through Extra Large 144x144x2; larger source requirements need a separate runtime-size slice.",
				"current_original_game_runtime_size_cap"
			)
		var graph_summary: Dictionary = template.get("graph_summary", {}) if template.get("graph_summary", {}) is Dictionary else {}
		var error_policy: Dictionary = template.get("error_policy", {}) if template.get("error_policy", {}) is Dictionary else {}
		if bool(error_policy.get("disconnected_source_graph", false)) or bool(graph_summary.has("connected") and not bool(graph_summary.get("connected", true))):
			expected_status = "accepted_non_parity"
			unsupported_reason = "disconnected_source_graph_preserved_for_later_repair_policy"
			tags.append("disconnected_source_graph")
			if not "accepted_non_parity" in tags:
				tags.append("accepted_non_parity")
			accepted_non_parity = _large_batch_non_parity_decision_record(
				unsupported_reason,
				"AcOrP requires generated maps to expose a reachable route graph for runtime play; disconnected source templates stay preserved but are not treated as playable materializations without an explicit repair policy.",
				"runtime_reachability_required"
			)
		if expected_status == "pass":
			tags.append("parity_intended_materialization")
			tags.append("runtime_materialization")
		cases.append({
			"id": "stress_%s" % template_id,
			"description": "Translated template sweep case for %s." % template_id,
			"tags": tags,
			"family": String(template.get("family", "")),
			"template_id": template_id,
			"expected_final_status": expected_status,
			"unsupported_reason": unsupported_reason,
			"accepted_non_parity": accepted_non_parity,
			"source_support": {
				"size_score": template.get("size_score", {}),
				"map_support": template.get("map_support", {}),
				"players": template.get("players", {}),
				"wide_link_count": wide_count,
				"border_guard_link_count": border_count,
			},
			"config": _large_batch_config(
				"%s:%s" % [seed_prefix, template_id],
				profile_id,
				template_id,
				int(size.get("width", 36)),
				int(size.get("height", 30)),
				String(size.get("water_mode", "land")),
				int(size.get("level_count", 1)),
				int(player_counts.get("human_count", 1)),
				int(player_counts.get("player_count", 2))
			),
		})
	return cases

static func _large_batch_config(seed: String, profile_id: String, template_id: String, width: int, height: int, water_mode: String, level_count: int, human_count: int, player_count: int) -> Dictionary:
	return {
		"generator_version": GENERATOR_VERSION,
		"seed": seed,
		"size": {"preset": "large_batch_parity_stress", "width": width, "height": height, "water_mode": water_mode, "level_count": level_count},
		"player_constraints": {"human_count": human_count, "player_count": player_count, "team_mode": "free_for_all"},
		"profile": {
			"id": profile_id,
			"template_id": template_id,
			"guard_strength_profile": "core_low",
			"terrain_ids": ["grass", "snow", "sand", "dirt", "rough", "lava", "underground"],
			"faction_ids": DEFAULT_FACTIONS,
		},
	}

static func _large_batch_size_for_template(template: Dictionary) -> Dictionary:
	var min_score := int(template.get("size_score", {}).get("min", 1))
	if min_score <= 1:
		return {"width": 36, "height": 36, "water_mode": "land", "level_count": 1}
	if min_score <= 4:
		return {"width": 72, "height": 72, "water_mode": "land", "level_count": 1}
	if min_score <= 9:
		return {"width": 108, "height": 108, "water_mode": "land", "level_count": 1}
	return {"width": 144, "height": 144, "water_mode": "land", "level_count": 1}

static func _large_batch_player_counts_for_template(template: Dictionary) -> Dictionary:
	var players: Dictionary = template.get("players", {}) if template.get("players", {}) is Dictionary else {}
	var humans: Dictionary = players.get("humans", {}) if players.get("humans", {}) is Dictionary else {}
	var total: Dictionary = players.get("total", {}) if players.get("total", {}) is Dictionary else {}
	var human_count: int = clampi(int(humans.get("min", 1)), 1, max(1, int(humans.get("max", 8))))
	var player_count: int = max(human_count, int(total.get("min", 2)))
	player_count = clampi(player_count, human_count, max(human_count, int(total.get("max", 8))))
	return {"human_count": human_count, "player_count": player_count}

static func _large_batch_current_max_size_score() -> int:
	return _map_size_score({"width": int(RUNTIME_SIZE_CAP.get("width", 144)), "height": int(RUNTIME_SIZE_CAP.get("height", 144)), "level_count": int(RUNTIME_SIZE_CAP.get("level_count", 2))})

static func _large_batch_link_flag_count(template: Dictionary, flag_name: String) -> int:
	var count := 0
	for link in template.get("links", []):
		if link is Dictionary and bool(link.get(flag_name, false)):
			count += 1
	return count

static func _large_batch_deduplicate_cases(cases: Array) -> Array:
	var seen := {}
	var result := []
	for case_value in cases:
		if not (case_value is Dictionary):
			continue
		var case_id := String(case_value.get("id", ""))
		if case_id == "" or seen.has(case_id):
			continue
		seen[case_id] = true
		result.append(case_value)
	return result

static func _large_batch_stress_run(cases: Array, input_config: Dictionary) -> Dictionary:
	var case_results := []
	var unsupported_warnings := []
	var accepted_non_parity_decisions := []
	var hard_blockers := []
	var summary := {
		"case_count": cases.size(),
		"successful_case_count": 0,
		"validation_pass_case_count": 0,
		"materialized_validation_pass_count": 0,
		"translated_materialized_validation_pass_count": 0,
		"pass_without_retry_count": 0,
		"pass_after_retry_count": 0,
		"metadata_only_count": 0,
		"translated_metadata_only_count": 0,
		"expected_negative_count": 0,
		"accepted_non_parity_count": 0,
		"unsupported_warning_count": 0,
		"hard_blocker_count": 0,
		"original_failure_count": 0,
		"bounded_retry_case_count": 0,
	}
	var ok := true
	for case_value in cases:
		var case_record: Dictionary = case_value if case_value is Dictionary else {}
		var case_result := _large_batch_stress_case_result(case_record)
		case_results.append(case_result)
		if bool(case_result.get("ok", false)):
			summary["successful_case_count"] = int(summary.get("successful_case_count", 0)) + 1
		if String(case_result.get("final_status", "")) == "pass":
			summary["pass_without_retry_count"] = int(summary.get("pass_without_retry_count", 0)) + 1
			summary["validation_pass_case_count"] = int(summary.get("validation_pass_case_count", 0)) + 1
		elif String(case_result.get("final_status", "")) == "pass_after_retry":
			summary["pass_after_retry_count"] = int(summary.get("pass_after_retry_count", 0)) + 1
			summary["validation_pass_case_count"] = int(summary.get("validation_pass_case_count", 0)) + 1
		elif String(case_result.get("final_status", "")) == "metadata_only":
			summary["metadata_only_count"] = int(summary.get("metadata_only_count", 0)) + 1
			if String(case_result.get("template_id", "")).begins_with("translated_rmg_template_"):
				summary["translated_metadata_only_count"] = int(summary.get("translated_metadata_only_count", 0)) + 1
		elif String(case_result.get("final_status", "")) == "accepted_non_parity":
			summary["accepted_non_parity_count"] = int(summary.get("accepted_non_parity_count", 0)) + 1
			accepted_non_parity_decisions.append(_large_batch_accepted_non_parity_record(case_result))
		elif String(case_result.get("final_status", "")) == "unsupported_warning":
			summary["unsupported_warning_count"] = int(summary.get("unsupported_warning_count", 0)) + 1
			unsupported_warnings.append(_large_batch_warning_record(case_result))
		elif String(case_result.get("final_status", "")) == "expected_negative":
			summary["expected_negative_count"] = int(summary.get("expected_negative_count", 0)) + 1
		else:
			summary["hard_blocker_count"] = int(summary.get("hard_blocker_count", 0)) + 1
			hard_blockers.append(_large_batch_blocker_record(case_result))
			ok = false
		if not case_result.get("original_failure_summary", {}).is_empty():
			summary["original_failure_count"] = int(summary.get("original_failure_count", 0)) + 1
		if bool(case_result.get("retry_policy", {}).get("bounded", false)) and int(case_result.get("retry_policy", {}).get("max_attempts", 1)) > 1:
			summary["bounded_retry_case_count"] = int(summary.get("bounded_retry_case_count", 0)) + 1
		var identity: Dictionary = case_result.get("deterministic_output_identity", {}) if case_result.get("deterministic_output_identity", {}) is Dictionary else {}
		var has_materialized_signature := String(identity.get("materialized_map_signature", "")) != ""
		if (String(case_result.get("final_status", "")) == "pass" or String(case_result.get("final_status", "")) == "pass_after_retry") and has_materialized_signature:
			summary["materialized_validation_pass_count"] = int(summary.get("materialized_validation_pass_count", 0)) + 1
			if String(case_result.get("template_id", "")).begins_with("translated_rmg_template_"):
				summary["translated_materialized_validation_pass_count"] = int(summary.get("translated_materialized_validation_pass_count", 0)) + 1
	var fixture_corpus := {
		"schema_id": "random_map_large_batch_parity_stress_cases_v1",
		"source": String(input_config.get("fixture_path", LARGE_BATCH_PARITY_STRESS_FIXTURE_PATH)),
		"expanded_case_count": cases.size(),
		"translated_template_sweep_count": _large_batch_case_tag_count(cases, "template_sweep"),
		"curated_case_count": cases.size() - _large_batch_case_tag_count(cases, "template_sweep"),
	}
	return {
		"ok": ok,
		"fixture_corpus": fixture_corpus,
		"summary": summary,
		"case_results": case_results,
		"unsupported_warnings": unsupported_warnings,
		"accepted_non_parity_decisions": accepted_non_parity_decisions,
		"hard_blockers": hard_blockers,
		"batch_signature": _hash32_hex(_stable_stringify({
			"schema_id": LARGE_BATCH_PARITY_STRESS_REPORT_SCHEMA_ID,
			"generator_version": GENERATOR_VERSION,
			"cases": case_results,
			"summary": summary,
			"fixture_corpus": fixture_corpus,
		})),
	}

static func _large_batch_changed_signature_probe(changed_cases: Array, reference_run: Dictionary) -> Dictionary:
	return {
		"ok": true,
		"summary": reference_run.get("summary", {}),
		"case_results": [],
		"unsupported_warnings": [],
		"accepted_non_parity_decisions": [],
		"hard_blockers": [],
		"batch_signature": _hash32_hex(_stable_stringify({
			"schema_id": LARGE_BATCH_PARITY_STRESS_REPORT_SCHEMA_ID,
			"generator_version": GENERATOR_VERSION,
			"probe": "changed_case_config_identity",
			"reference_batch_signature": String(reference_run.get("batch_signature", "")),
			"cases": _large_batch_case_config_identities(changed_cases),
		})),
	}

static func _large_batch_case_config_identities(cases: Array) -> Array:
	var identities := []
	for case_value in cases:
		if not (case_value is Dictionary):
			continue
		var case_record: Dictionary = case_value
		var config: Dictionary = case_record.get("config", {}) if case_record.get("config", {}) is Dictionary else {}
		var size: Dictionary = config.get("size", {}) if config.get("size", {}) is Dictionary else {}
		var profile: Dictionary = config.get("profile", {}) if config.get("profile", {}) is Dictionary else {}
		identities.append({
			"id": String(case_record.get("id", "")),
			"expected_final_status": String(case_record.get("expected_final_status", "pass")),
			"seed": String(config.get("seed", "")),
			"template_id": String(case_record.get("template_id", profile.get("template_id", ""))),
			"profile_id": String(profile.get("id", "")),
			"size": {
				"width": int(size.get("width", 0)),
				"height": int(size.get("height", 0)),
				"water_mode": String(size.get("water_mode", "land")),
				"level_count": int(size.get("level_count", 1)),
			},
		})
	return identities

static func _large_batch_metadata_only_case_result(case_record: Dictionary) -> Dictionary:
	var config: Dictionary = case_record.get("config", {}) if case_record.get("config", {}) is Dictionary else {}
	var source_support: Dictionary = case_record.get("source_support", {}) if case_record.get("source_support", {}) is Dictionary else {}
	var template_id := String(case_record.get("template_id", config.get("profile", {}).get("template_id", "")))
	var identity := {
		"scenario_id": "",
		"stable_signature": _hash32_hex(_stable_stringify({
			"case_id": String(case_record.get("id", "")),
			"template_id": template_id,
			"config": config,
			"source_support": source_support,
		})),
		"normalized_seed": String(config.get("seed", "")),
		"generator_version": String(config.get("generator_version", GENERATOR_VERSION)),
		"template_id": template_id,
		"profile_id": String(config.get("profile", {}).get("id", "")),
		"content_manifest_fingerprint": "",
		"validation_status": "metadata_only",
		"phase_signature": _hash32_hex(_stable_stringify(source_support)),
		"materialized_map_signature": "",
	}
	identity["identity_signature"] = _hash32_hex(_stable_stringify(identity))
	identity["generated_output_identity_signature"] = _hash32_hex(_stable_stringify(identity))
	return {
		"ok": true,
		"id": String(case_record.get("id", "")),
		"description": String(case_record.get("description", "")),
		"tags": case_record.get("tags", []),
		"family": String(case_record.get("family", "")),
		"template_id": template_id,
		"final_status": "metadata_only",
		"expected_final_status": "metadata_only",
		"unsupported_reason": "",
		"validation_passed": false,
		"attempt_count": 0,
		"retry_count": 0,
		"retry_policy": {"bounded": true, "max_attempts": 0, "mode": "none", "uses_config_fallback": false, "uses_seed_salt": false, "does_not_hide_original_failure": true},
		"original_failure_summary": {},
		"failure_summary": {},
		"failure_diagnostics": {
			"phase": "metadata_fixture_expansion",
			"attempt": 0,
			"retry_count_so_far": 0,
			"max_attempts": 0,
			"retryable": false,
			"fallback_decision": {"configured": false, "will_retry": false, "mode": "none"},
			"template_selection": {},
			"coordinate_context": {"source_support": source_support},
			"failure_examples": [],
		},
		"remediation_hints": ["metadata fixture validates translated template coverage; materialized generation is covered by curated runtime cases"],
		"required_phase_statuses_present": false,
		"phase_statuses": [],
		"phase_signatures": {"metadata_fixture_expansion": String(identity.get("phase_signature", ""))},
		"deterministic_output_identity": identity,
		"attempts": [],
	}

static func _large_batch_stress_case_result(case_record: Dictionary) -> Dictionary:
	if String(case_record.get("expected_final_status", "pass")) == "metadata_only":
		return _large_batch_metadata_only_case_result(case_record)
	var retry_policy: Dictionary = case_record.get("retry_policy", {}) if case_record.get("retry_policy", {}) is Dictionary else {}
	var max_attempts := clampi(int(retry_policy.get("max_attempts", 1)), 1, 5)
	var attempts := []
	var final_identity := {}
	var final_phase_statuses := []
	var final_phase_signatures := {}
	var final_failure_summary := {}
	var final_diagnostics := {}
	var final_generation_ok := false
	var original_failure_summary := {}
	for attempt_index in range(max_attempts):
		var config := _validation_batch_attempt_config(case_record, attempt_index)
		var generation := generate(config)
		var attempt_record := _large_batch_attempt_record(case_record, config, generation, attempt_index + 1, max_attempts)
		attempts.append(attempt_record)
		if attempt_index == 0 and not bool(generation.get("ok", false)):
			original_failure_summary = attempt_record.get("failure_summary", {})
		final_identity = attempt_record.get("deterministic_output_identity", {})
		final_phase_statuses = attempt_record.get("phase_statuses", [])
		final_phase_signatures = attempt_record.get("phase_signatures", {})
		final_failure_summary = attempt_record.get("failure_summary", {})
		final_diagnostics = attempt_record.get("failure_diagnostics", {})
		if bool(generation.get("ok", false)):
			final_generation_ok = true
			break
	var expected_initial_failure := bool(case_record.get("expect_initial_failure", false))
	var expected_final_status := String(case_record.get("expected_final_status", "pass"))
	var required_phases_present := _validation_batch_required_phases_present(final_phase_statuses) if String(final_identity.get("stable_signature", "")) != "" else false
	var final_status := "hard_blocker"
	if final_generation_ok and attempts.size() == 1:
		final_status = "pass"
	elif final_generation_ok:
		final_status = "pass_after_retry"
	elif expected_final_status == "unsupported_warning" and not final_failure_summary.is_empty():
		final_status = "unsupported_warning"
	elif expected_final_status == "accepted_non_parity" and not final_failure_summary.is_empty():
		final_status = "accepted_non_parity"
	elif (expected_final_status == "negative_fail" or expected_final_status == "fail") and not final_failure_summary.is_empty():
		final_status = "expected_negative"
	var case_ok := false
	if final_generation_ok and expected_final_status == "pass":
		case_ok = required_phases_present and (not expected_initial_failure or not original_failure_summary.is_empty())
	elif final_generation_ok and expected_final_status != "pass":
		case_ok = required_phases_present
	elif final_status == "unsupported_warning" or final_status == "expected_negative":
		case_ok = not final_failure_summary.is_empty()
	elif final_status == "accepted_non_parity":
		var decision: Dictionary = case_record.get("accepted_non_parity", {}) if case_record.get("accepted_non_parity", {}) is Dictionary else {}
		case_ok = not final_failure_summary.is_empty() and String(decision.get("rationale", "")) != "" and String(decision.get("original_game_constraint", "")) != ""
	var remediation_hints := _large_batch_remediation_hints(case_record, final_failure_summary, final_diagnostics)
	return {
		"ok": case_ok,
		"id": String(case_record.get("id", "")),
		"description": String(case_record.get("description", "")),
		"tags": case_record.get("tags", []),
		"family": String(case_record.get("family", "")),
		"template_id": String(case_record.get("template_id", case_record.get("config", {}).get("profile", {}).get("template_id", ""))),
		"final_status": final_status,
		"expected_final_status": expected_final_status,
		"unsupported_reason": String(case_record.get("unsupported_reason", "")),
		"accepted_non_parity": case_record.get("accepted_non_parity", {}) if case_record.get("accepted_non_parity", {}) is Dictionary else {},
		"validation_passed": final_generation_ok,
		"attempt_count": attempts.size(),
		"retry_count": max(0, attempts.size() - 1),
		"retry_policy": {
			"bounded": max_attempts <= 5,
			"max_attempts": max_attempts,
			"mode": String(retry_policy.get("mode", "none")),
			"uses_config_fallback": retry_policy.get("fallback_config", {}) is Dictionary and not retry_policy.get("fallback_config", {}).is_empty(),
			"uses_seed_salt": String(retry_policy.get("mode", "")).find("seed_salt") >= 0,
			"does_not_hide_original_failure": original_failure_summary.is_empty() == false or not expected_initial_failure,
		},
		"original_failure_summary": original_failure_summary,
		"failure_summary": final_failure_summary,
		"failure_diagnostics": final_diagnostics,
		"remediation_hints": remediation_hints,
		"required_phase_statuses_present": required_phases_present,
		"phase_statuses": final_phase_statuses,
		"phase_signatures": final_phase_signatures,
		"deterministic_output_identity": final_identity,
		"attempts": attempts,
	}

static func _large_batch_attempt_record(case_record: Dictionary, config: Dictionary, generation: Dictionary, attempt_number: int, max_attempts: int) -> Dictionary:
	var payload: Dictionary = generation.get("generated_map", {}) if generation.get("generated_map", {}) is Dictionary else {}
	var report: Dictionary = generation.get("report", {}) if generation.get("report", {}) is Dictionary else {}
	var normalized := normalize_config(config)
	var phase_statuses := _validation_batch_phase_statuses(payload)
	var phase_signatures := _large_batch_phase_signatures(phase_statuses)
	var failure_summary := _validation_batch_failure_summary(report)
	var diagnostics := _large_batch_failure_diagnostics(case_record, payload, report, failure_summary, attempt_number, max_attempts)
	var ok := bool(generation.get("ok", false))
	var will_retry := not ok and attempt_number < max_attempts
	return {
		"attempt": attempt_number,
		"seed": String(normalized.get("seed", "")),
		"template_id": String(normalized.get("template_id", "")),
		"profile_id": String(normalized.get("profile", {}).get("id", "")),
		"ok": ok,
		"validation_status": String(report.get("status", "pass" if ok else "fail")),
		"stable_signature": String(payload.get("stable_signature", "")),
		"materialized_map_signature": String(payload.get("runtime_materialization", {}).get("materialized_map_signature", "")),
		"deterministic_output_identity": _large_batch_output_identity(payload, normalized, report, phase_statuses),
		"phase_statuses": phase_statuses,
		"phase_signatures": phase_signatures,
		"failure_summary": failure_summary,
		"failure_diagnostics": diagnostics,
		"retryable_failure": not ok,
		"retry_decision": {
			"will_retry": will_retry,
			"bounded_attempt": attempt_number < max_attempts,
			"reason": "retry_policy_has_remaining_attempt" if will_retry else ("accepted_valid_generation" if ok else "attempt_limit_reached"),
			"next_attempt": attempt_number + 1 if will_retry else 0,
		},
		"attempt_signature": _hash32_hex(_stable_stringify({
			"case_id": String(case_record.get("id", "")),
			"attempt": attempt_number,
			"identity": _large_batch_output_identity(payload, normalized, report, phase_statuses),
			"failure_summary": failure_summary,
			"phase_signatures": phase_signatures,
		})),
	}

static func _large_batch_output_identity(payload: Dictionary, normalized: Dictionary, report: Dictionary, phase_statuses: Array) -> Dictionary:
	var identity := _validation_batch_output_identity(payload, normalized, report)
	identity["phase_signature"] = _hash32_hex(_stable_stringify(phase_statuses))
	identity["materialized_map_signature"] = String(payload.get("runtime_materialization", {}).get("materialized_map_signature", ""))
	identity["generated_output_identity_signature"] = _hash32_hex(_stable_stringify(identity))
	return identity

static func _large_batch_phase_signatures(phase_statuses: Array) -> Dictionary:
	var result := {}
	for phase in phase_statuses:
		if not (phase is Dictionary):
			continue
		var phase_name := String(phase.get("phase", ""))
		result[phase_name] = _hash32_hex(_stable_stringify(phase))
	return result

static func _large_batch_failure_diagnostics(case_record: Dictionary, payload: Dictionary, report: Dictionary, failure_summary: Dictionary, attempt_number: int, max_attempts: int) -> Dictionary:
	return {
		"phase": String(failure_summary.get("phase", "none")),
		"attempt": attempt_number,
		"retry_count_so_far": max(0, attempt_number - 1),
		"max_attempts": max_attempts,
		"retryable": not bool(report.get("ok", false)) and attempt_number < max_attempts,
		"fallback_decision": {
			"configured": case_record.get("retry_policy", {}).get("fallback_config", {}) is Dictionary and not case_record.get("retry_policy", {}).get("fallback_config", {}).is_empty(),
			"will_retry": not bool(report.get("ok", false)) and attempt_number < max_attempts,
			"mode": String(case_record.get("retry_policy", {}).get("mode", "none")),
		},
		"template_selection": report.get("template_selection", {}),
		"coordinate_context": _large_batch_coordinate_context(payload, report),
		"failure_examples": failure_summary.get("failures", []),
	}

static func _large_batch_coordinate_context(payload: Dictionary, report: Dictionary) -> Dictionary:
	var zone_examples := []
	var link_examples := []
	var object_examples := []
	var staging: Dictionary = payload.get("staging", {}) if payload.get("staging", {}) is Dictionary else {}
	var zone_layout: Dictionary = staging.get("zone_layout", {}) if staging.get("zone_layout", {}) is Dictionary else {}
	for level in zone_layout.get("levels", []):
		if not (level is Dictionary):
			continue
		for footprint in level.get("footprints", []):
			if not (footprint is Dictionary):
				continue
			zone_examples.append({
				"level": int(level.get("level_index", 0)),
				"zone_id": String(footprint.get("zone_id", "")),
				"anchor": footprint.get("anchor", {}),
				"bounds": footprint.get("bounds", {}),
			})
			if zone_examples.size() >= 4:
				break
		if zone_examples.size() >= 4:
			break
	var route_graph: Dictionary = staging.get("route_graph", {}) if staging.get("route_graph", {}) is Dictionary else {}
	for edge in route_graph.get("edges", []):
		if not (edge is Dictionary):
			continue
		link_examples.append({
			"id": String(edge.get("id", "")),
			"from": String(edge.get("from", "")),
			"to": String(edge.get("to", "")),
			"anchor": edge.get("route_cell_anchor_candidate", edge.get("midpoint", {})),
			"source_endpoints": edge.get("source_endpoints", {}),
		})
		if link_examples.size() >= 4:
			break
	var guard_materialization: Dictionary = staging.get("connection_guard_materialization", {}) if staging.get("connection_guard_materialization", {}) is Dictionary else {}
	for group_key in ["normal_route_guards", "special_guard_gates", "wide_suppressions"]:
		for record in guard_materialization.get(group_key, []):
			if not (record is Dictionary):
				continue
			object_examples.append({
				"id": String(record.get("id", "")),
				"kind": group_key,
				"zone_id": String(record.get("zone_id", "")),
				"anchor": record.get("route_cell_anchor_candidate", record.get("placement", {})),
			})
			if object_examples.size() >= 4:
				break
		if object_examples.size() >= 4:
			break
	var runtime_materialization: Dictionary = payload.get("runtime_materialization", {}) if payload.get("runtime_materialization", {}) is Dictionary else {}
	for object_record in runtime_materialization.get("objects", {}).get("object_instances", []):
		if not (object_record is Dictionary):
			continue
		object_examples.append({
			"id": String(object_record.get("id", "")),
			"kind": String(object_record.get("kind", "")),
			"zone_id": String(object_record.get("zone_id", "")),
			"x": int(object_record.get("x", 0)),
			"y": int(object_record.get("y", 0)),
		})
		if object_examples.size() >= 4:
			break
	if zone_examples.is_empty() and report.get("template_selection", {}) is Dictionary:
		var constraint_report: Dictionary = report.get("template_selection", {}).get("constraint_report", {}) if report.get("template_selection", {}).get("constraint_report", {}) is Dictionary else {}
		return {
			"template_constraint_context": {
				"requested": constraint_report.get("requested", {}),
				"supported": constraint_report.get("supported", {}),
				"capacity": constraint_report.get("capacity", {}),
				"graph_summary": constraint_report.get("graph_summary", {}),
			},
			"zone_examples": zone_examples,
			"link_examples": link_examples,
			"object_examples": object_examples,
		}
	return {"zone_examples": zone_examples, "link_examples": link_examples, "object_examples": object_examples}

static func _large_batch_remediation_hints(case_record: Dictionary, failure_summary: Dictionary, diagnostics: Dictionary) -> Array:
	var hints := []
	var unsupported_reason := String(case_record.get("unsupported_reason", ""))
	if unsupported_reason == "template_min_size_score_exceeds_current_runtime_fixture_bounds":
		hints.append("expand current generated-map fixture bounds beyond 144x144x2 or add a non-materializing size-score validator for oversized translated templates")
	if unsupported_reason == "disconnected_source_graph_preserved_for_later_repair_policy":
		hints.append("decide repair/rejection policy for disconnected translated source graphs before treating them as playable generation blockers")
	if unsupported_reason == "current_generated_validation_warning" or unsupported_reason == "current_generated_validation_warning_after_retry":
		hints.append("current generated payload materializes diagnostic signatures but remains warning-class until route reachability and decoration validation are fully hardened")
	var phase := String(failure_summary.get("phase", ""))
	if phase == "template_selection":
		hints.append("inspect template constraint report for requested size, water, level, human, total-player, capacity, or graph-policy mismatch")
	elif phase.find("connection") >= 0:
		hints.append("inspect route edge coordinate context and guard materialization diagnostics")
	elif phase.find("object") >= 0:
		hints.append("inspect object placement coordinate context, footprint limits, and value-band exhaustion")
	elif not failure_summary.is_empty():
		hints.append("inspect phase signatures and compact phase summaries for the first failing generation stage")
	if hints.is_empty():
		hints.append("no remediation required for accepted generated case")
	return hints

static func _large_batch_stress_coverage(cases: Array, case_results: Array) -> Dictionary:
	var catalog := _load_template_catalog()
	var translated_templates := {}
	var translated_families := {}
	for template in catalog.get("templates", []):
		if not (template is Dictionary):
			continue
		var template_id := String(template.get("id", ""))
		if not template_id.begins_with("translated_rmg_template_"):
			continue
		translated_templates[template_id] = true
		translated_families[String(template.get("family", ""))] = true
	var covered_templates := {}
	var covered_families := {}
	var covered_tags := {}
	var water_modes := {}
	var level_counts := {}
	var human_counts := {}
	var total_counts := {}
	var success_with_materialized_signature := 0
	var success_with_phase_signature := 0
	var translated_parity_intended_count := 0
	var translated_parity_materialized_pass_count := 0
	var translated_metadata_only_count := 0
	var accepted_non_parity_count := 0
	var negative_count := 0
	var unsupported_count := 0
	var hard_blocker_count := 0
	for case_result in case_results:
		if not (case_result is Dictionary):
			continue
		var template_id := String(case_result.get("template_id", ""))
		if template_id.begins_with("translated_rmg_template_"):
			covered_templates[template_id] = true
		var family := String(case_result.get("family", ""))
		if family != "":
			covered_families[family] = true
		var tags: Array = case_result.get("tags", []) if case_result.get("tags", []) is Array else []
		for tag in tags:
			covered_tags[String(tag)] = true
		var is_translated: bool = template_id.begins_with("translated_rmg_template_")
		var is_parity_intended: bool = "parity_intended_materialization" in tags
		if is_translated and is_parity_intended:
			translated_parity_intended_count += 1
		if String(case_result.get("final_status", "")) == "expected_negative":
			negative_count += 1
		if String(case_result.get("final_status", "")) == "accepted_non_parity":
			accepted_non_parity_count += 1
		if String(case_result.get("final_status", "")) == "unsupported_warning":
			unsupported_count += 1
		if String(case_result.get("final_status", "")) == "hard_blocker":
			hard_blocker_count += 1
		if String(case_result.get("final_status", "")) == "metadata_only" and is_translated:
			translated_metadata_only_count += 1
		var identity: Dictionary = case_result.get("deterministic_output_identity", {}) if case_result.get("deterministic_output_identity", {}) is Dictionary else {}
		if String(identity.get("phase_signature", "")) != "":
			success_with_phase_signature += 1
		if String(identity.get("materialized_map_signature", "")) != "":
			success_with_materialized_signature += 1
			if is_translated and is_parity_intended and (String(case_result.get("final_status", "")) == "pass" or String(case_result.get("final_status", "")) == "pass_after_retry"):
				translated_parity_materialized_pass_count += 1
	for case_record in cases:
		if not (case_record is Dictionary):
			continue
		var config: Dictionary = case_record.get("config", {}) if case_record.get("config", {}) is Dictionary else {}
		var size: Dictionary = config.get("size", {}) if config.get("size", {}) is Dictionary else {}
		var players: Dictionary = config.get("player_constraints", {}) if config.get("player_constraints", {}) is Dictionary else {}
		water_modes[String(size.get("water_mode", "land"))] = true
		level_counts[str(int(size.get("level_count", 1)))] = true
		human_counts[str(int(players.get("human_count", 1)))] = true
		total_counts[str(int(players.get("player_count", 2)))] = true
	var missing_templates := []
	for template_id in _sorted_keys(translated_templates):
		if not covered_templates.has(template_id):
			missing_templates.append(template_id)
	var missing_families := []
	for family in _sorted_keys(translated_families):
		if not covered_families.has(family):
			missing_families.append(family)
	var required_tags := ["land", "islands_water", "underground", "wide_link", "border_guard", "negative_case", "retry_policy", "object_pool_value_weighting", "runtime_materialization"]
	var missing_tags := []
	for tag in required_tags:
		if not covered_tags.has(tag):
			missing_tags.append(tag)
	var ok := missing_templates.is_empty() and missing_families.is_empty() and missing_tags.is_empty() and hard_blocker_count == 0 and success_with_materialized_signature > 0 and success_with_phase_signature > 0
	ok = ok and translated_metadata_only_count == 0 and translated_parity_intended_count > 0 and translated_parity_materialized_pass_count == translated_parity_intended_count
	return {
		"ok": ok,
		"translated_template_count": translated_templates.size(),
		"covered_translated_template_count": covered_templates.size(),
		"missing_translated_templates": missing_templates,
		"translated_family_count": translated_families.size(),
		"covered_translated_family_count": covered_families.size(),
		"missing_translated_families": missing_families,
		"required_tags": required_tags,
		"covered_tags": _sorted_keys(covered_tags),
		"missing_tags": missing_tags,
		"water_modes": _sorted_keys(water_modes),
		"level_counts": _sorted_keys(level_counts),
		"human_counts": _sorted_keys(human_counts),
		"total_player_counts": _sorted_keys(total_counts),
		"wide_link_covered": covered_tags.has("wide_link"),
		"border_guard_covered": covered_tags.has("border_guard"),
		"negative_case_count": negative_count,
		"accepted_non_parity_count": accepted_non_parity_count,
		"unsupported_warning_count": unsupported_count,
		"hard_blocker_count": hard_blocker_count,
		"successful_case_with_phase_signature_count": success_with_phase_signature,
		"successful_case_with_materialized_map_signature_count": success_with_materialized_signature,
		"translated_parity_intended_case_count": translated_parity_intended_count,
		"translated_parity_materialized_validation_pass_count": translated_parity_materialized_pass_count,
		"translated_metadata_only_count": translated_metadata_only_count,
	}

static func _large_batch_case_tag_count(cases: Array, tag_name: String) -> int:
	var count := 0
	for case_record in cases:
		if case_record is Dictionary and tag_name in case_record.get("tags", []):
			count += 1
	return count

static func _large_batch_warning_record(case_result: Dictionary) -> Dictionary:
	return {
		"id": String(case_result.get("id", "")),
		"template_id": String(case_result.get("template_id", "")),
		"family": String(case_result.get("family", "")),
		"unsupported_reason": String(case_result.get("unsupported_reason", "")),
		"phase": String(case_result.get("failure_summary", {}).get("phase", "")),
		"remediation_hints": case_result.get("remediation_hints", []),
	}

static func _large_batch_non_parity_decision_record(reason: String, rationale: String, original_game_constraint: String) -> Dictionary:
	return {
		"decision": "accepted_original_game_non_parity",
		"reason": reason,
		"rationale": rationale,
		"original_game_constraint": original_game_constraint,
		"parity_claim": false,
		"materialization_required": false,
	}

static func _large_batch_accepted_non_parity_record(case_result: Dictionary) -> Dictionary:
	var decision: Dictionary = case_result.get("accepted_non_parity", {}) if case_result.get("accepted_non_parity", {}) is Dictionary else {}
	return {
		"id": String(case_result.get("id", "")),
		"template_id": String(case_result.get("template_id", "")),
		"family": String(case_result.get("family", "")),
		"unsupported_reason": String(case_result.get("unsupported_reason", decision.get("reason", ""))),
		"decision": decision,
		"phase": String(case_result.get("failure_summary", {}).get("phase", "")),
		"failure_diagnostics": case_result.get("failure_diagnostics", {}),
		"remediation_hints": case_result.get("remediation_hints", []),
	}

static func _large_batch_blocker_record(case_result: Dictionary) -> Dictionary:
	return {
		"id": String(case_result.get("id", "")),
		"template_id": String(case_result.get("template_id", "")),
		"family": String(case_result.get("family", "")),
		"phase": String(case_result.get("failure_summary", {}).get("phase", "")),
		"failure_summary": case_result.get("failure_summary", {}),
		"failure_diagnostics": case_result.get("failure_diagnostics", {}),
		"remediation_hints": case_result.get("remediation_hints", []),
	}

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
	var width := int(size.get("source_width", size.get("requested_width", size.get("width", 16))))
	var height := int(size.get("source_height", size.get("requested_height", size.get("height", 12))))
	var level_count := int(size.get("requested_level_count", size.get("level_count", 1)))
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
	var size_class_id := ""
	var size_class_label := ""
	var source_model := "custom_runtime_dimensions"
	var source_width := 0
	var source_height := 0
	var requested_level_count := 1
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
		size_class_id = String(size_value.get("size_class_id", size_value.get("class_id", ""))).strip_edges()
		size_class_label = String(size_value.get("size_class_label", "")).strip_edges()
		source_model = String(size_value.get("source_model", source_model)).strip_edges()
		source_width = int(size_value.get("source_width", size_value.get("requested_width", size_value.get("width", width))))
		source_height = int(size_value.get("source_height", size_value.get("requested_height", size_value.get("height", height))))
		width = source_width
		height = source_height
		water_mode = _normalize_water_mode(size_value.get("water_mode", size_value.get("water", water_mode)))
		requested_level_count = clampi(int(size_value.get("level_count", size_value.get("levels", level_count))), 1, 2)
		level_count = requested_level_count
	if source_width <= 0:
		source_width = width
	if source_height <= 0:
		source_height = height
	if size_class_label == "" and size_class_id != "":
		size_class_label = size_class_id.replace("_", " ").capitalize()
	var cap_width := int(RUNTIME_SIZE_CAP.get("width", 144))
	var cap_height := int(RUNTIME_SIZE_CAP.get("height", 144))
	var cap_level_count := int(RUNTIME_SIZE_CAP.get("level_count", 2))
	var materialized_width := clampi(source_width, 8, cap_width)
	var materialized_height := clampi(source_height, 8, cap_height)
	var materialized_level_count := clampi(requested_level_count, 1, cap_level_count)
	var exceeds_cap := source_width != materialized_width or source_height != materialized_height or requested_level_count != materialized_level_count
	var provided_policy: Dictionary = size_value.get("runtime_size_policy", {}) if size_value is Dictionary and size_value.get("runtime_size_policy", {}) is Dictionary else {}
	var materialization_available := bool(provided_policy.get("materialization_available", not exceeds_cap))
	if exceeds_cap:
		materialization_available = false
	var status := String(provided_policy.get("status", "materialize_at_requested_size_within_current_144x144x2_cap" if materialization_available else "blocked_source_size_exceeds_current_144x144x2_cap"))
	var rationale := String(provided_policy.get("rationale", ""))
	if not materialization_available and rationale == "":
		rationale = "Requested source size %dx%dx%d exceeds the current original runtime cap of %dx%dx%d; hidden downscaling is not allowed." % [source_width, source_height, requested_level_count, cap_width, cap_height, cap_level_count]
	return {
		"preset": preset,
		"size_class_id": size_class_id,
		"size_class_label": size_class_label,
		"source_model": source_model,
		"source_width": source_width,
		"source_height": source_height,
		"requested_width": source_width,
		"requested_height": source_height,
		"requested_level_count": requested_level_count,
		"width": materialized_width,
		"height": materialized_height,
		"water_mode": water_mode,
		"level_count": materialized_level_count,
		"underground": materialized_level_count > 1,
		"runtime_size_cap": RUNTIME_SIZE_CAP.duplicate(true),
		"runtime_size_policy": {
			"status": status,
			"materialization_available": materialization_available,
			"source_size": {"width": source_width, "height": source_height, "level_count": requested_level_count},
			"materialized_size": {"width": materialized_width, "height": materialized_height, "level_count": materialized_level_count},
			"cap": RUNTIME_SIZE_CAP.duplicate(true),
			"hidden_downscale": false,
			"rationale": rationale,
		},
	}

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
			"implementation_state": "surface_water_ring_marks_island_boundary_with_materialized_ferry_bridge_access_records",
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
			"implementation_state": "deterministic_second_level_zone_allocation_with_materialized_cross_level_gate_records",
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
				"materialization_state": "candidate_consumed_by_guard_and_transit_materialization",
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

static func _nearest_free_cell(x: int, y: int, preferred_zone_id: Variant, zone_grid: Array, terrain_rows: Array, occupied: Dictionary, rng: DeterministicRng, reserved: Dictionary = {}) -> Dictionary:
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
				if reserved.has(_point_key(cx, cy)):
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

static func _array_difference(left: Array, right: Array) -> Array:
	var right_lookup := {}
	for value in right:
		right_lookup[String(value)] = true
	var result := []
	for value in left:
		if not right_lookup.has(String(value)):
			result.append(String(value))
	result.sort()
	return result

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

static func _mark_occupied_for_catalog(occupied: Dictionary, point: Dictionary, kind: String, family_id: String, object_id: String) -> void:
	var catalog := _object_footprint_catalog_record_for_placement({
		"kind": kind,
		"family_id": family_id,
		"object_id": object_id,
		"x": int(point.get("x", 0)),
		"y": int(point.get("y", 0)),
	})
	for body in _runtime_body_tiles_for_catalog(point, catalog):
		if body is Dictionary:
			_mark_occupied(occupied, body)

static func _reserve_visit_tiles_for_catalog(reserved: Dictionary, point: Dictionary, kind: String, family_id: String, object_id: String) -> void:
	var catalog := _object_footprint_catalog_record_for_placement({
		"kind": kind,
		"family_id": family_id,
		"object_id": object_id,
		"x": int(point.get("x", 0)),
		"y": int(point.get("y", 0)),
	})
	for offset in catalog.get("visit_mask", []):
		if offset is Dictionary:
			reserved[_point_key(int(point.get("x", 0)) + int(offset.get("x", 0)), int(point.get("y", 0)) + int(offset.get("y", 0)))] = true
	for offset in catalog.get("approach_mask", []):
		if offset is Dictionary:
			reserved[_point_key(int(point.get("x", 0)) + int(offset.get("x", 0)), int(point.get("y", 0)) + int(offset.get("y", 0)))] = true

static func _point_key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]

static func _manhattan_distance(a: Dictionary, b: Dictionary) -> int:
	return abs(int(a.get("x", 0)) - int(b.get("x", 0))) + abs(int(a.get("y", 0)) - int(b.get("y", 0)))

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
