class_name RandomMapGeneratorRules
extends RefCounted

const HumanEngine = preload("res://scripts/core/HumanEngine.gd")

const GENERATOR_VERSION := "random_map_seeded_core_v1"
const TEMPLATE_CATALOG_PATH := "res://content/random_map_template_catalog.json"
const RUNTIME_SIZE_POLICY_REJECTION_SCHEMA_ID := "random_map_runtime_size_policy_rejection_v1"

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
const DWELLING_SITE_CANDIDATES := [
	{"site_id": "site_bogbell_croft", "object_id": "object_bogbell_croft", "neutral_dwelling_family_id": "neutral_dwelling_bogbell_croft", "biome_ids": ["biome_mire_fen", "biome_deep_forest"], "guard_pressure": "low"},
	{"site_id": "site_greenbranch_copse", "object_id": "object_greenbranch_copse", "neutral_dwelling_family_id": "neutral_dwelling_greenbranch_copse", "biome_ids": ["biome_deep_forest", "biome_grasslands"], "guard_pressure": "medium"},
	{"site_id": "site_crystal_sump", "object_id": "object_crystal_sump", "neutral_dwelling_family_id": "neutral_dwelling_crystal_sump", "biome_ids": ["biome_subterranean_underways", "biome_highland_ridge"], "guard_pressure": "medium"},
	{"site_id": "site_kite_signal_eyrie", "object_id": "object_kite_signal_eyrie", "neutral_dwelling_family_id": "neutral_dwelling_kite_signal_eyrie", "biome_ids": ["biome_highland_ridge", "biome_coast_archipelago"], "guard_pressure": "medium"},
	{"site_id": "site_saltpan_camp", "object_id": "object_saltpan_camp", "neutral_dwelling_family_id": "neutral_dwelling_saltpan_camp", "biome_ids": ["biome_rough_badlands", "biome_coast_archipelago"], "guard_pressure": "high"},
	{"site_id": "site_cliffhawk_roost", "object_id": "object_cliffhawk_roost", "neutral_dwelling_family_id": "neutral_dwelling_cliffhawk_roost", "biome_ids": ["biome_highland_ridge", "biome_grasslands"], "guard_pressure": "low"},
]

static func normalize_config(input_config: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"RandomMapGeneratorRules.normalize_config", [input_config])
