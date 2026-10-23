extends RefCounted
## Turns a generated map's HoMM3 reward and economy objects into original
## sites with HoMM-style payloads: pile sizes, chest tiers, campfire hauls,
## scroll spells and which of the six rares a rare slot holds.
##
## Original-game content translation only. It never consumes the native RNG or
## changes a placement, mask or link: every roll is a stable hash of the
## placement id, so the same package always yields the same map.

const HumanEngine = preload("res://scripts/core/HumanEngine.gd")

const RARE_RESOURCES := ["aetherglass", "embergrain", "peatwax", "verdant_grafts", "brass_scrip", "memory_salt"]
const PILE_SITES := {
	"wood": "site_split_wood_pile",
	"ore": "site_quarry_chip_hod",
	"gold": "site_road_writ_purse",
	"aetherglass": "site_aetherglass_splinter_lot",
	"embergrain": "site_embergrain_sample_sack",
	"peatwax": "site_peatwax_votive_bundle",
	"verdant_grafts": "site_verdant_graft_bundle",
	"brass_scrip": "site_brass_scrip_case",
	"memory_salt": "site_memory_salt_jar",
}
const MINE_SITES := {
	"wood": "site_brightwood_sawmill",
	"ore": "site_ridge_quarry",
	"gold": "site_reef_coin_assay",
	"aetherglass": "site_aetherglass_lens_house",
	"embergrain": "site_embergrain_warm_granary",
	"peatwax": "site_peatwax_reed_yard",
	"verdant_grafts": "site_verdant_graft_nursery",
	"brass_scrip": "site_brass_scrip_mint",
	"memory_salt": "site_memory_salt_pan",
}

# HoMM3 chests: 1,000 gold or 500 XP, 1,500 or 1,000, 2,000 or 1,500.
const TREASURE_CHEST_TIERS := [[1000, 500], [1500, 1000], [2000, 1500]]

# HoMM3 creature banks keep their levels (docs/creature-banks.md; numbers from
# CRBANKS.TXT). A bank rolls one level per placement and pays that level's
# resources, troops, spell and artifacts; its guard fights as original units
# with the battle power of the native guard's budget, as generated neutral
# guards do. Guard and troop stacks are [HoMM3 creature AI value, headcount],
# and "units" names the original unit standing for each creature. Our units are
# weaker than HoMM3's, so troops and guards convert by battle power, not by
# headcount. A single-creature guard stands in five stacks; where the creature
# has an upgrade, half the placements field one of the five upgraded. "rares"
# are the HoMM3 mercury, sulfur, crystal and gems amounts, paid as four of our
# six rares shuffled per placement. Artifacts are HoMM3 classes
# (ArtifactRules.H3M_ARTIFACT_CLASS_RARITIES). Keys are "type:subtype" or "type".
const TYPE_PANDORA := 6
const BANK_LEVEL := "generated_bank_level"
# A translated site that fights no guard of its own (Pandora's Box, Warrior's
# Tomb): the native generator already set a guard beside it.
const UNGUARDED := "generated_reward_unguarded"
const GUARD_STACK_COUNT := 5
const UPGRADE_CHANCE_PCT := 50
const CREATURE_BANKS := {
	# Cyclops Stockpile: Cyclopes (Kings) as Gaugecoil Orewyrms.
	"16:0": {
		"site_id": "site_brasswake_depot",
		"units": {1266: "unit_neutral_gaugecoil_orewyrms", 1443: "unit_neutral_gaugecoil_orewyrms"},
		"upgrade": [1266, 1443],
		"levels": [
			{"chance": 30, "guard": [[1266, 20]], "rewards": {"wood": 4, "ore": 4}, "rares": [4, 4, 4, 4]},
			{"chance": 30, "guard": [[1266, 30]], "rewards": {"wood": 6, "ore": 6}, "rares": [6, 6, 6, 6]},
			{"chance": 30, "guard": [[1266, 40]], "rewards": {"wood": 8, "ore": 8}, "rares": [8, 8, 8, 8]},
			{"chance": 10, "guard": [[1266, 50]], "rewards": {"wood": 10, "ore": 10}, "rares": [10, 10, 10, 10]},
		],
	},
	# Dwarven Treasury: Dwarves (Battle Dwarves) as Kilnward Mallets, in the
	# Barrow Vault, a one-time site as every bank is.
	"16:1": {
		"site_id": "site_barrow_vault",
		"units": {138: "unit_neutral_kilnward_mallets", 209: "unit_neutral_kilnward_mallets"},
		"upgrade": [138, 209],
		"levels": [
			{"chance": 30, "guard": [[138, 50]], "rewards": {"gold": 2500}, "rares": [0, 0, 2, 0]},
			{"chance": 30, "guard": [[138, 75]], "rewards": {"gold": 4000}, "rares": [0, 0, 3, 0]},
			{"chance": 30, "guard": [[138, 100]], "rewards": {"gold": 5000}, "rares": [0, 0, 5, 0]},
			{"chance": 10, "guard": [[138, 150]], "rewards": {"gold": 7500}, "rares": [0, 0, 10, 0]},
		],
	},
	# Griffin Conservatory: Griffins (Royal) as Cliffhawk Wardens; its
	# Angels join as Noonshard Prism Kites.
	"16:2": {
		"site_id": "site_glassbound_eyrie",
		"units": {351: "unit_neutral_cliffhawk_wardens", 448: "unit_neutral_cliffhawk_wardens", 5019: "unit_neutral_noonshard_prism_kites"},
		"upgrade": [351, 448],
		"levels": [
			{"chance": 30, "guard": [[351, 50]], "troops": [[5019, 1]]},
			{"chance": 30, "guard": [[351, 100]], "troops": [[5019, 2]]},
			{"chance": 30, "guard": [[351, 150]], "troops": [[5019, 3]]},
			{"chance": 10, "guard": [[351, 200]], "troops": [[5019, 4]]},
		],
	},
	# Imp Cache: Imps (Familiars) as Charcoal Mauls.
	"16:3": {
		"site_id": "site_furnace_vault",
		"units": {50: "unit_neutral_charcoal_mauls", 60: "unit_neutral_charcoal_mauls"},
		"upgrade": [50, 60],
		"levels": [
			{"chance": 30, "guard": [[50, 100]], "rewards": {"gold": 1000}, "rares": [2, 0, 0, 0]},
			{"chance": 30, "guard": [[50, 150]], "rewards": {"gold": 1500}, "rares": [3, 0, 0, 0]},
			{"chance": 30, "guard": [[50, 200]], "rewards": {"gold": 2000}, "rares": [4, 0, 0, 0]},
			{"chance": 10, "guard": [[50, 300]], "rewards": {"gold": 3000}, "rares": [6, 0, 0, 0]},
		],
	},
	# Medusa Stores: Medusas (Queens) as Mireglass Belltoads.
	"16:4": {
		"site_id": "site_drowned_reliquary",
		"units": {517: "unit_neutral_mireglass_belltoads", 577: "unit_neutral_mireglass_belltoads"},
		"upgrade": [517, 577],
		"levels": [
			{"chance": 30, "guard": [[517, 20]], "rewards": {"gold": 2000}, "rares": [0, 5, 0, 0]},
			{"chance": 30, "guard": [[517, 30]], "rewards": {"gold": 3000}, "rares": [0, 6, 0, 0]},
			{"chance": 30, "guard": [[517, 40]], "rewards": {"gold": 4000}, "rares": [0, 8, 0, 0]},
			{"chance": 10, "guard": [[517, 50]], "rewards": {"gold": 5000}, "rares": [0, 10, 0, 0]},
		],
	},
	# Naga Bank: Nagas (Queens) as Fenmirror Gallowshells, in the Amber
	# Reliquary.
	"16:5": {
		"site_id": "site_amber_reliquary",
		"units": {2016: "unit_neutral_fenmirror_gallowshells", 2840: "unit_neutral_fenmirror_gallowshells"},
		"upgrade": [2016, 2840],
		"levels": [
			{"chance": 30, "guard": [[2016, 10]], "rewards": {"gold": 4000}, "rares": [0, 8, 0, 0]},
			{"chance": 30, "guard": [[2016, 15]], "rewards": {"gold": 6000}, "rares": [0, 12, 0, 0]},
			{"chance": 30, "guard": [[2016, 20]], "rewards": {"gold": 8000}, "rares": [0, 16, 0, 0]},
			{"chance": 10, "guard": [[2016, 30]], "rewards": {"gold": 12000}, "rares": [0, 24, 0, 0]},
		],
	},
	# Dragon Fly Hive: Dragon Flies as Bogbell Mauls; its Wyverns join as
	# Miremoon Crownmaws. Dragon Flies are already upgraded.
	"16:6": {
		"site_id": "site_hive_of_reeds",
		"units": {312: "unit_neutral_bogbell_mauls", 1350: "unit_neutral_miremoon_crownmaws"},
		"levels": [
			{"chance": 30, "guard": [[312, 30]], "troops": [[1350, 4]]},
			{"chance": 30, "guard": [[312, 45]], "troops": [[1350, 6]]},
			{"chance": 30, "guard": [[312, 60]], "troops": [[1350, 8]]},
			{"chance": 10, "guard": [[312, 90]], "troops": [[1350, 12]]},
		],
	},
	# Derelict Ship: Water Elementals as Tideglass Skyrays.
	"24": {
		"site_id": "site_storm_bell_wreck",
		"units": {315: "unit_neutral_tideglass_skyrays"},
		"levels": [
			{"chance": 30, "guard": [[315, 20]], "rewards": {"gold": 3000}},
			{"chance": 30, "guard": [[315, 30]], "rewards": {"gold": 3000}, "artifacts": ["treasure"]},
			{"chance": 30, "guard": [[315, 40]], "rewards": {"gold": 4000}, "artifacts": ["treasure"]},
			{"chance": 10, "guard": [[315, 60]], "rewards": {"gold": 6000}, "artifacts": ["minor"]},
		],
	},
	# Dragon Utopia: Green, Red, Gold and Black Dragons as Rootvault
	# Barkhulks, Deepforge Vaultwyrms, Quenchbell Ironbacks and Gloambell
	# Wake-Mantas.
	"25": {
		"site_id": "site_wyrmcrown_hoard",
		"units": {4872: "unit_neutral_rootvault_barkhulks", 4702: "unit_neutral_deepforge_vaultwyrms", 8613: "unit_neutral_quenchbell_ironbacks", 8721: "unit_neutral_gloambell_wake_mantas"},
		"levels": [
			{"chance": 30, "guard": [[4872, 8], [4702, 5], [8613, 2], [8721, 1]], "rewards": {"gold": 20000}, "artifacts": ["treasure", "minor", "major", "relic"]},
			{"chance": 30, "guard": [[4872, 8], [4702, 6], [8613, 3], [8721, 2]], "rewards": {"gold": 30000}, "artifacts": ["minor", "major", "relic", "relic"]},
			{"chance": 30, "guard": [[4872, 8], [4702, 6], [8613, 4], [8721, 3]], "rewards": {"gold": 40000}, "artifacts": ["major", "relic", "relic", "relic"]},
			{"chance": 10, "guard": [[4872, 8], [4702, 7], [8613, 6], [8721, 5]], "rewards": {"gold": 50000}, "artifacts": ["relic", "relic", "relic", "relic"]},
		],
	},
	# Pyramid: 40 Gold Golems and 20 Diamond Golems as Basalt Wardens and
	# Sumpstone Guards, guarding one spell of the highest tier.
	"63": {
		"site_id": "site_mirror_archive",
		"units": {600: "unit_neutral_basalt_wardens", 775: "unit_neutral_sumpstone_guards"},
		"levels": [
			{"chance": 100, "guard": [[600, 14], [600, 13], [600, 13], [775, 10], [775, 10]], "spell_tier": 5},
		],
	},
	# Crypt: Skeletons, Walking Dead, Wights and Vampires as Veilmourn's
	# Knellwake Wardens, Gravetide Anchors, Lastlight Keepers and Duskpass
	# Revenants.
	"84": {
		"site_id": "site_prism_ossuary",
		"units": {60: "unit_veilmourn_bellwake_oars_veteran", 98: "unit_veilmourn_wakechain_boarders_veteran", 252: "unit_veilmourn_mourning_lanterns_veteran", 555: "unit_veilmourn_mirrorkeel_reavers_veteran"},
		"levels": [
			{"chance": 30, "guard": [[60, 30], [98, 20]], "rewards": {"gold": 1500}},
			{"chance": 30, "guard": [[60, 25], [98, 20], [252, 5]], "rewards": {"gold": 2000}},
			{"chance": 30, "guard": [[60, 20], [98, 20], [252, 10], [555, 5]], "rewards": {"gold": 2500}, "artifacts": ["treasure"]},
			{"chance": 10, "guard": [[60, 20], [98, 20], [252, 10], [555, 10]], "rewards": {"gold": 5000}, "artifacts": ["treasure"]},
		],
	},
	# Shipwreck: Wights as Tidepool Cutters.
	"85": {
		"site_id": "site_wreck_locker",
		"units": {252: "unit_neutral_tidepool_cutters"},
		"levels": [
			{"chance": 30, "guard": [[252, 10]], "rewards": {"gold": 2000}},
			{"chance": 30, "guard": [[252, 15]], "rewards": {"gold": 3000}},
			{"chance": 30, "guard": [[252, 25]], "rewards": {"gold": 4000}, "artifacts": ["treasure"]},
			{"chance": 10, "guard": [[252, 50]], "rewards": {"gold": 5000}, "artifacts": ["minor"]},
		],
	},
}
# Warrior's Tomb: one artifact of a class rolled 30/50/15/5 and no guard of its
# own. HoMM3's morale penalty for robbing it is not carried over.
const WARRIORS_TOMB_SITE := "site_basalt_oath_tomb"
const WARRIORS_TOMB_CLASS_WEIGHTS := {"treasure": 30, "minor": 50, "major": 15, "relic": 5}
# Pandora's Box becomes a one-time casket with the box's own contents: gold,
# experience worth the same hero level, every spell of its levels (one of our
# schools when the box held one HoMM3 school) or troops of the same tier.
const PANDORA_SITE := "site_hushlock_casket"

const GATE_TYPES := [9, 33, 212, 215, 219]
const PORTAL_TYPES := [43, 44, 45]
const TRANSIT_MEANING_TYPES := [8, 9, 10, 33, 43, 44, 45, 87, 103, 111, 212, 215, 219]

# Creature level of each HoMM3 Creature Generator 1 subtype (by its .def).
const H3M_DWELLING_LEVEL := {
	0: 4, 1: 7, 2: 3, 3: 6, 4: 7, 5: 6, 6: 1, 7: 2, 8: 7, 9: 6,
	10: 7, 11: 3, 12: 2, 13: 5, 14: 6, 15: 3, 16: 4, 17: 2, 18: 5, 19: 2,
	20: 1, 21: 1, 22: 2, 23: 5, 24: 7, 25: 3, 26: 2, 27: 3, 28: 7, 29: 1,
	30: 2, 31: 4, 32: 6, 33: 4, 34: 5, 35: 5, 36: 6, 37: 4, 38: 4, 39: 3,
	40: 5, 41: 7, 42: 5, 43: 1, 44: 7, 45: 5, 46: 1, 47: 3, 48: 3, 49: 6,
	50: 4, 51: 6, 52: 5, 53: 4, 54: 1, 55: 2, 56: 1, 57: 2, 58: 4, 59: 1,
	60: 6, 61: 7, 62: 7, 63: 7, 64: 7, 65: 7, 66: 6, 67: 4, 68: 6, 69: 2,
	70: 5, 71: 4, 72: 3, 73: 1, 74: 1, 75: 2, 76: 3, 77: 3, 78: 2, 79: 5,
}

static var _dwelling_pool_cache: Dictionary = {}

## Returns the node the session should hold for a generated object, or an empty
## dictionary when this object type is not one of the translated reward types.
static func resolve(object: Dictionary, towns: Array = [], terrain_rows: Array = []) -> Dictionary:
	return HumanEngine.native_writing(&"GeneratedRewardRules.resolve", [object, towns, terrain_rows])

## Boats, keymaster's tents and dead-end portal networks become no resource site.
static func is_skipped(object: Dictionary) -> bool:
	return HumanEngine.native_writing(&"GeneratedRewardRules.is_skipped", [object])

## A HoMM3 boat's water tile, or {} for any other object.
static func boat_tile(object: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"GeneratedRewardRules.boat_tile", [object])

## The CREATURE_BANKS key of a HoMM3 object, or "" when it is no bank.
static func bank_key(type_id: int, subtype: int) -> String:
	return HumanEngine.native_writing(&"GeneratedRewardRules.bank_key", [type_id, subtype])

## The level, 1 to 4, a bank rolls at this placement.
static func bank_level_roll(key: String, bank_id: String) -> int:
	return HumanEngine.native_writing(&"GeneratedRewardRules.bank_level_roll", [key, bank_id])

## The native guard a bank fields at this placement and level, as [creature AI
## value, headcount] stacks: a single creature stands in five stacks, one of
## them upgraded on half the placements where the creature has an upgrade.
static func native_guard_stacks(key: String, bank_id: String, level: int) -> Array:
	return HumanEngine.native_writing(&"GeneratedRewardRules.native_guard_stacks", [key, bank_id, level])

## The guard a translated creature bank fields at its level, or [] for any
## other node, whose site keeps its own guard army.
static func bank_guard_stacks(node: Dictionary) -> Array:
	return HumanEngine.native_writing(&"GeneratedRewardRules.bank_guard_stacks", [node])

## Experience worth the same hero level as a HoMM3 amount, counted from level
## 1, to the nearest 50.
static func experience_for_h3m(amount: int) -> int:
	return HumanEngine.native_writing(&"GeneratedRewardRules.experience_for_h3m", [amount])
