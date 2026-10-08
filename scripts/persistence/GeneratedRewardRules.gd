extends RefCounted
## Turns a generated map's HoMM3 reward and economy objects into original
## sites with HoMM-style payloads: pile sizes, chest tiers, campfire hauls,
## scroll spells and which of the six rares a rare slot holds.
##
## Original-game content translation only. It never consumes the native RNG or
## changes a placement, mask or link: every roll is a stable hash of the
## placement id, so the same package always yields the same map.

const NodePayload = preload("res://scripts/core/ResourceNodePayloadRules.gd")
const NativeTransit = preload("res://scripts/core/NativeTransitRules.gd")

const RARE_RESOURCES := ["aetherglass", "embergrain", "peatwax", "verdant_grafts", "brass_scrip", "memory_salt"]
const COLLECTIBLE_RESOURCES := ["wood", "ore", "aetherglass", "embergrain", "peatwax", "verdant_grafts", "brass_scrip", "memory_salt"]
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
# HoMM3 resource and mine subtypes: 0 wood, 1 mercury, 2 ore, 3 sulfur,
# 4 crystal, 5 gems, 6 gold. The four rare kinds spread over all six rares.
const H3M_COMMON_RESOURCE_BY_SUBTYPE := {0: "wood", 2: "ore", 6: "gold"}
const H3M_RARE_SUBTYPES := [1, 3, 4, 5]

const TYPE_CAMPFIRE := 12
const TYPE_FLOTSAM := 29
const TYPE_LEAN_TO := 39
const TYPE_MINE := 53
const TYPE_MYSTICAL_GARDEN := 55
const TYPE_RANDOM_RESOURCE := 76
const TYPE_RESOURCE := 79
const TYPE_SEA_CHEST := 82
const TYPE_SPELL_SCROLL := 93
const TYPE_TREASURE_CHEST := 101
const TYPE_WAGON := 105
const TYPE_WATER_WHEEL := 109
const TYPE_WINDMILL := 112
const TYPE_ABANDONED_MINE := 220

const TREASURE_CHEST_SITE := "site_waystone_cache"
const CAMPFIRE_SITE := "site_wayfarer_camp_cache"
const FLOTSAM_SITE := "site_millroad_plank_stack"
const SPELL_SCROLL_SITE := "site_spell_scroll"
const WATER_WHEEL_SITES := ["site_charter_countinghouse", "site_tide_kiln"]
const WINDMILL_SITES := ["site_wind_press", "site_saw_chain", "site_smelter_annex"]
const MYSTICAL_GARDEN_SITE := "site_orchard_levy_post"
const WIND_PRESS_SITE := "site_wind_press"
# HoMM3 chests: 1,000 gold or 500 XP, 1,500 or 1,000, 2,000 or 1,500.
const TREASURE_CHEST_TIERS := [[1000, 500], [1500, 1000], [2000, 1500]]
# Scroll spells lean to the lower tiers; tier 5 is never found on the map.
const SCROLL_TIER_WEIGHTS := {1: 40, 2: 30, 3: 20, 4: 10}

# HoMM3 visit buildings become the original building with the same role
# (docs/visit-buildings.md).
const VISIT_SITE_BY_TYPE := {
	4: "site_visit_proving_rostrum",
	11: "site_tide_bell_shrine",
	13: "site_contract_scribe_booth",
	14: "site_root_accord_ring",
	23: "site_visit_drum_cairn",
	27: "site_lens_calibration_cart",
	28: "site_root_accord_ring",
	30: "site_root_accord_ring",
	31: "site_wayfarer_menders_tent",
	32: "site_visit_facet_orrery",
	37: "site_lens_calibration_cart",
	38: "site_root_accord_ring",
	41: "site_visit_grand_archive",
	47: "site_visit_arcane_collegium",
	48: "site_visit_moonspring",
	49: "site_visit_ley_well",
	51: "site_visit_bell_spire",
	52: "site_root_accord_ring",
	56: "site_wayfarer_menders_tent",
	61: "site_visit_clamp_forge",
	64: "site_furnace_oath_marker",
	94: "site_courier_change_post",
	96: "site_wayfarer_infirmary",
	99: "site_market_caravanserai",
	100: "site_visit_lorestone",
	102: "site_visit_elder_graft_tree",
	107: "site_visit_war_college",
	110: "site_ash_cooler_kitchen",
	221: "site_market_caravanserai",
}
const SPELL_SHRINE_BY_TYPE := {88: ["site_oath_ember_shrine", 1], 89: ["site_reedscript_vow_shrine", 2], 90: ["site_prism_measure_shrine", 3]}
const SCOUTING_TYPES := [42, 58, 60]
const SCOUTING_SITES := ["site_watchtower_beacon", "site_mist_lighthouse", "site_hilltop_signal_nest", "site_marsh_listener_post", "site_prism_survey_frame", "site_underway_echo_well", "site_coast_bell_watch"]
const SIGN_TYPES := [59, 91]
const SIGN_SITES := ["site_mile_writ_sign", "site_reed_knot_waypost", "site_switchback_cairn", "site_ash_road_marker", "site_underway_chalk_index"]
const LANDMARK_TYPES := [57]
const LANDMARK_SITES := ["site_ember_signal_brazier", "site_bog_drum_totem", "site_prism_relay_lens", "site_thornwake_graft_arch", "site_brasshollow_gauge_shrine", "site_veilmourn_bell_mast", "site_granary_lock_exchange", "site_blackwater_shrine_marker", "site_prism_yard_standard"]
# Witch Hut, University and Scholar teach in HoMM3; until skill sites exist
# they become one of the growth buildings.
const LEARNING_TYPES := [81, 104, 113]
const GROWTH_SITES := ["site_visit_bell_spire", "site_visit_drum_cairn", "site_visit_clamp_forge", "site_visit_facet_orrery", "site_visit_lorestone", "site_oath_ember_shrine"]
const FORTUNE_TYPE := 30
const ELDER_TREE_TYPE := 102

# HoMM3 creature dwellings become one of our dwellings of the same tier
# (docs/creature-dwellings.md). A dwelling of a town creature belongs to the
# faction of the nearest town; a neutral creature's dwelling stays neutral.
# HoMM3 transit objects by meaning (docs/water-travel.md). Boats become boat
# entities and keymaster's tents are left off: gates open by payment, so no
# key is needed. Border guards, gates, garrisons and quest guards become the
# pay-to-open gate that suits their terrain; portals and subterranean gates
# keep their native passage with matching art. Each portal kind has its own art
# (docs/portal-networks.md), and a portal network whose two sides are the same
# zone is left off: it never takes a traveller anywhere new.
const TYPE_BOAT := 8
const TYPE_KEYMASTER := 10
const TYPE_SHIPYARD := 87
const TYPE_WHIRLPOOL := 111
const TYPE_SUBTERRANEAN_GATE := 103
const SKIPPED_TYPES := [TYPE_BOAT, TYPE_KEYMASTER]
const GATE_TYPES := [9, 33, 212, 215, 219]
const PORTAL_TYPES := [43, 44, 45]
const TRANSIT_MEANING_TYPES := [8, 9, 10, 33, 43, 44, 45, 87, 103, 111, 212, 215, 219]
const SHIPYARD_SITE := "site_shipyard"
const WHIRLPOOL_SITE := "site_whirlpool"
const PORTAL_SITES := {45: "site_wayring", 43: "site_waygate", 44: "site_wayfall"}
const UNDERGATE_SITE := "site_basalt_undergate"
const GATE_SITES := ["site_charter_bar_gate", "site_thorn_seal_gate", "site_brass_toll_arch", "site_reef_chain_boom", "site_frost_toll_bar", "site_ash_sluice_lock", "site_toll_chain_court", "site_root_lease_gate", "site_pressure_rail_stop"]
const GATE_SITES_BY_TERRAIN := {
	"grass": ["site_charter_bar_gate", "site_toll_chain_court", "site_thorn_seal_gate"],
	"dirt": ["site_charter_bar_gate", "site_brass_toll_arch"],
	"sand": ["site_toll_chain_court", "site_reef_chain_boom"],
	"snow": ["site_frost_toll_bar"],
	"swamp": ["site_thorn_seal_gate", "site_root_lease_gate", "site_reef_chain_boom"],
	"rough": ["site_brass_toll_arch", "site_pressure_rail_stop", "site_charter_bar_gate"],
	"underground": ["site_brass_toll_arch", "site_pressure_rail_stop"],
	"lava": ["site_ash_sluice_lock"],
}

const TYPE_CREATURE_GENERATOR := 17
const TYPE_MULTI_GENERATOR := 20
const TYPE_REFUGEE_CAMP := 78
const TYPE_RANDOM_DWELLING := 216
const TYPE_RANDOM_DWELLING_BY_LEVEL := 217
const TYPE_RANDOM_DWELLING_BY_FACTION := 218
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
# Dragons, Enchanters, Sharpshooters, Halflings, Peasants, Boars, Mummies,
# Nomads, Rogues and Trolls have no town.
const H3M_NEUTRAL_DWELLING_SUBTYPES := [62, 63, 64, 65, 66, 67, 73, 74, 75, 76, 77, 78, 79]
# Elemental Conflux and Golem Factory.
const MULTI_DWELLING_BY_SUBTYPE := {0: "site_five_bough_veteran_grove", 1: "site_three_gauge_chapter_foundry"}
const REFUGEE_CAMP_SITE := "site_dwelling_drifters_camp"
const RANDOM_DWELLING_TIER_WEIGHTS := {1: 25, 2: 20, 3: 18, 4: 15, 5: 10, 6: 7, 7: 5}

static var _dwelling_pool_cache: Dictionary = {}

## Returns the node the session should hold for a generated object, or an empty
## dictionary when this object type is not one of the translated reward types.
static func resolve(object: Dictionary, towns: Array = [], terrain_rows: Array = []) -> Dictionary:
	var type_id := int(object.get("h3m_type_id", -1))
	var subtype := int(object.get("h3m_subtype", -1))
	var key := String(object.get("placement_id", "")).strip_edges()
	if type_id < 0 or key == "":
		return {}
	if type_id in GATE_TYPES:
		return _node(object, _gate_site(object, key, terrain_rows), "resource_site", {})
	if type_id in PORTAL_TYPES:
		return _node(object, String(PORTAL_SITES[type_id]), String(object.get("kind", "resource_site")), {})
	match type_id:
		TYPE_SHIPYARD:
			return _node(object, SHIPYARD_SITE, "resource_site", {})
		TYPE_WHIRLPOOL:
			return _node(object, WHIRLPOOL_SITE, "resource_site", {})
		TYPE_SUBTERRANEAN_GATE:
			return _node(object, UNDERGATE_SITE, String(object.get("kind", "resource_site")), {})
		TYPE_CREATURE_GENERATOR:
			var level := int(H3M_DWELLING_LEVEL.get(subtype, 0))
			if level <= 0:
				return {}
			var neutral := subtype in H3M_NEUTRAL_DWELLING_SUBTYPES
			return _dwelling(object, key, level, "" if neutral else _nearest_town_faction(object, towns))
		TYPE_MULTI_GENERATOR:
			return _node(object, String(MULTI_DWELLING_BY_SUBTYPE.get(subtype, MULTI_DWELLING_BY_SUBTYPE[0])), String(object.get("kind", "neutral_dwelling")), {})
		TYPE_REFUGEE_CAMP:
			return _node(object, REFUGEE_CAMP_SITE, String(object.get("kind", "neutral_dwelling")), {})
		TYPE_RANDOM_DWELLING, TYPE_RANDOM_DWELLING_BY_FACTION:
			return _dwelling(object, key, _weighted_tier(key), _nearest_town_faction(object, towns))
		TYPE_RANDOM_DWELLING_BY_LEVEL:
			return _dwelling(object, key, clampi(subtype + 1, 1, 7), _nearest_town_faction(object, towns))
		TYPE_RESOURCE:
			var resource_id := String(H3M_COMMON_RESOURCE_BY_SUBTYPE.get(subtype, ""))
			if resource_id == "" and subtype in H3M_RARE_SUBTYPES:
				resource_id = _pick(RARE_RESOURCES, key, "rare")
			return _pile(object, key, resource_id) if resource_id != "" else {}
		TYPE_RANDOM_RESOURCE:
			return _pile(object, key, _random_resource_id(key))
		TYPE_LEAN_TO:
			var resource_id := _pick(COLLECTIBLE_RESOURCES, key, "lean_to")
			return _node(object, PILE_SITES[resource_id], "reward_reference", {NodePayload.PAYLOAD_REWARDS: {resource_id: _roll_range(key, "amount", 1, 5)}}, resource_id)
		TYPE_WAGON:
			var resource_id := _pick(COLLECTIBLE_RESOURCES, key, "wagon")
			return _node(object, PILE_SITES[resource_id], "reward_reference", {NodePayload.PAYLOAD_REWARDS: {resource_id: _roll_range(key, "amount", 2, 5)}}, resource_id)
		TYPE_CAMPFIRE:
			var resource_id := _pick(COLLECTIBLE_RESOURCES, key, "campfire")
			return _node(object, CAMPFIRE_SITE, "reward_reference", {NodePayload.PAYLOAD_REWARDS: {
				"gold": 100 * _roll_range(key, "gold", 4, 6),
				resource_id: _roll_range(key, "amount", 4, 6),
			}})
		TYPE_FLOTSAM:
			var hauls := [{"wood": 5}, {"wood": 5, "gold": 200}, {"wood": 10, "gold": 500}]
			return _node(object, FLOTSAM_SITE, "reward_reference", {NodePayload.PAYLOAD_REWARDS: hauls[_roll(key, "haul", hauls.size())]})
		TYPE_SEA_CHEST:
			return _node(object, PILE_SITES["gold"], "reward_reference", {NodePayload.PAYLOAD_REWARDS: {"gold": 1500}}, "gold")
		TYPE_TREASURE_CHEST:
			var tier: Array = TREASURE_CHEST_TIERS[_roll(key, "tier", TREASURE_CHEST_TIERS.size())]
			return _node(object, TREASURE_CHEST_SITE, "reward_reference", {
				NodePayload.PAYLOAD_REWARDS: {"gold": int(tier[0])},
				NodePayload.PAYLOAD_REWARD_CHOICES: treasure_chest_choices(int(tier[0]), int(tier[1])),
			})
		TYPE_SPELL_SCROLL:
			var spell_id := _scroll_spell_id(key)
			return _node(object, SPELL_SCROLL_SITE, "reward_reference", {NodePayload.PAYLOAD_SPELL_IDS: [spell_id]} if spell_id != "" else {})
		TYPE_MINE:
			var mine_resource := String(H3M_COMMON_RESOURCE_BY_SUBTYPE.get(subtype, ""))
			if mine_resource == "" and subtype in H3M_RARE_SUBTYPES:
				mine_resource = _pick(RARE_RESOURCES, key, "rare_mine")
			return _node(object, MINE_SITES[mine_resource], "mine", {}, mine_resource) if mine_resource != "" else {}
		TYPE_ABANDONED_MINE:
			var mine_resource := _pick(MINE_SITES.keys(), key, "abandoned_mine")
			return _node(object, MINE_SITES[mine_resource], "mine", {}, mine_resource)
		TYPE_WATER_WHEEL:
			return _node(object, _pick(WATER_WHEEL_SITES, key, "water_wheel"), "resource_site", {})
		TYPE_WINDMILL:
			var site_id := _pick(WINDMILL_SITES, key, "windmill")
			var payload := {}
			if site_id == WIND_PRESS_SITE:
				payload[NodePayload.PAYLOAD_REWARDS] = {_pick(RARE_RESOURCES, key, "wind_press"): _roll_range(key, "amount", 3, 6)}
			return _node(object, site_id, "resource_site", payload)
		TYPE_MYSTICAL_GARDEN:
			return _node(object, MYSTICAL_GARDEN_SITE, "resource_site", {})
	return _visit_building(object, key, type_id)

static func _visit_building(object: Dictionary, key: String, type_id: int) -> Dictionary:
	if SPELL_SHRINE_BY_TYPE.has(type_id):
		var shrine: Array = SPELL_SHRINE_BY_TYPE[type_id]
		var spell_id := _tier_spell_id(key, int(shrine[1]))
		return _node(object, String(shrine[0]), "resource_site", {NodePayload.PAYLOAD_SPELL_IDS: [spell_id]} if spell_id != "" else {})
	if VISIT_SITE_BY_TYPE.has(type_id):
		var payload := {}
		if type_id == ELDER_TREE_TYPE:
			# HoMM3: a third of the trees are free, a third ask 2,000 gold, a third 10 of a rare.
			match _roll(key, "tree_price", 3):
				1:
					payload[NodePayload.PAYLOAD_VISIT] = {"cost": {"gold": 2000}}
				2:
					payload[NodePayload.PAYLOAD_VISIT] = {"cost": {_pick(RARE_RESOURCES, key, "tree_rare"): 10}}
		elif type_id == FORTUNE_TYPE:
			payload[NodePayload.PAYLOAD_VISIT] = {"effects": {"battle_boosts": {"momentum": _roll_range(key, "fortune", 1, 3)}}}
		return _node(object, String(VISIT_SITE_BY_TYPE[type_id]), "resource_site", payload)
	if type_id in SCOUTING_TYPES:
		return _node(object, _pick(SCOUTING_SITES, key, "scouting"), "resource_site", {})
	if type_id in SIGN_TYPES:
		return _node(object, _pick(SIGN_SITES, key, "sign"), "resource_site", {})
	if type_id in LANDMARK_TYPES:
		return _node(object, _pick(LANDMARK_SITES, key, "landmark"), "resource_site", {})
	if type_id in LEARNING_TYPES:
		return _node(object, _pick(GROWTH_SITES, key, "learning"), "resource_site", {})
	if String(object.get("native_authored_pool_id", "")) == "interactable_site":
		return _node(object, _pick(_visit_fallback_sites(), key, "visit_fallback"), "resource_site", {})
	return {}

## Boats, keymaster's tents and dead-end portal networks become no resource site.
static func is_skipped(object: Dictionary) -> bool:
	return int(object.get("h3m_type_id", -1)) in SKIPPED_TYPES or NativeTransit.is_dead_end(object)

## A HoMM3 boat's water tile, or {} for any other object.
static func boat_tile(object: Dictionary) -> Dictionary:
	if int(object.get("h3m_type_id", -1)) != TYPE_BOAT:
		return {}
	var visit: Dictionary = object.get("visit_tile", {}) if object.get("visit_tile", {}) is Dictionary else {}
	var level := int(visit.get("level", object.get("level", 0)))
	return {"x": int(visit.get("x", object.get("x", 0))), "y": int(visit.get("y", object.get("y", 0))), "level": level}

static func _gate_site(object: Dictionary, key: String, terrain_rows: Array) -> String:
	var options: Array = GATE_SITES
	var x := int(object.get("x", -1))
	var y := int(object.get("y", -1))
	if int(object.get("level", 0)) == 0 and y >= 0 and y < terrain_rows.size() and terrain_rows[y] is Array and x >= 0 and x < terrain_rows[y].size():
		var terrain := ContentService.normalize_terrain_id(String(terrain_rows[y][x]))
		options = GATE_SITES_BY_TERRAIN.get(terrain, GATE_SITES)
	return _pick(options, key, "gate")

## Our dwelling of this tier: the faction's when the faction has one, a
## neutral one otherwise, then the nearest tier that has one.
static func _dwelling(object: Dictionary, key: String, tier: int, faction_id: String) -> Dictionary:
	var pools := _dwelling_pools()
	var site_id := ""
	for distance in range(0, 7):
		for candidate_tier in [tier - distance, tier + distance]:
			if candidate_tier < 1 or candidate_tier > 7 or site_id != "":
				continue
			var faction_pool: Array = pools.get("%s|%d" % [faction_id, candidate_tier], []) if faction_id != "" else []
			var pool: Array = faction_pool if not faction_pool.is_empty() else pools.get("|%d" % candidate_tier, [])
			if not pool.is_empty():
				site_id = _pick(pool, key, "dwelling")
		if site_id != "":
			break
	return _node(object, site_id, String(object.get("kind", "neutral_dwelling")), {}) if site_id != "" else {}

## Single-creature dwellings with a map object, keyed "faction|tier" (the
## faction is empty for neutral creatures).
static func _dwelling_pools() -> Dictionary:
	if not _dwelling_pool_cache.is_empty():
		return _dwelling_pool_cache
	for site in ContentService.load_json("res://content/resource_sites.json").get("items", []):
		if not (site is Dictionary) or String(site.get("family", "")) != "neutral_dwelling" or String(site.get("dwelling_kind", "single")) != "single":
			continue
		var site_id := String(site.get("id", ""))
		var recruits = site.get("weekly_recruits", {})
		if ContentService.get_map_object_for_resource_site(site_id).is_empty() or not (recruits is Dictionary) or recruits.size() != 1:
			continue
		var unit := ContentService.get_unit(String(recruits.keys()[0]))
		var pool_key := "%s|%d" % [String(unit.get("faction_id", "")), int(unit.get("tier", 1))]
		var pool: Array = _dwelling_pool_cache.get(pool_key, [])
		pool.append(site_id)
		_dwelling_pool_cache[pool_key] = pool
	for pool_key in _dwelling_pool_cache.keys():
		_dwelling_pool_cache[pool_key].sort()
	return _dwelling_pool_cache

static func _nearest_town_faction(object: Dictionary, towns: Array) -> String:
	var best := ""
	var best_distance := 1 << 30
	var level := int(object.get("level", 0))
	for town in towns:
		if not (town is Dictionary) or int(town.get("level", 0)) != level:
			continue
		var distance := absi(int(town.get("x", 0)) - int(object.get("x", 0))) + absi(int(town.get("y", 0)) - int(object.get("y", 0)))
		var faction_id := String(town.get("faction_id", ""))
		if faction_id == "":
			faction_id = String(ContentService.get_town(String(town.get("town_id", ""))).get("faction_id", ""))
		if faction_id != "" and distance < best_distance:
			best_distance = distance
			best = faction_id
	return best

static func _weighted_tier(key: String) -> int:
	var total := 0
	for tier in RANDOM_DWELLING_TIER_WEIGHTS.keys():
		total += int(RANDOM_DWELLING_TIER_WEIGHTS[tier])
	var roll := _roll(key, "dwelling_tier", total)
	for tier in [1, 2, 3, 4, 5, 6, 7]:
		roll -= int(RANDOM_DWELLING_TIER_WEIGHTS[tier])
		if roll < 0:
			return tier
	return 1

static func _visit_fallback_sites() -> Array:
	var sites := []
	for site_id in VISIT_SITE_BY_TYPE.values():
		if String(site_id) not in sites:
			sites.append(String(site_id))
	for shrine in SPELL_SHRINE_BY_TYPE.values():
		sites.append(String(shrine[0]))
	sites.sort()
	return sites

static func _tier_spell_id(key: String, tier: int) -> String:
	var candidates := []
	for spell in ContentService.load_json("res://content/spells.json").get("items", []):
		if spell is Dictionary and int(spell.get("tier", 0)) == tier and String(spell.get("id", "")) != "":
			candidates.append(String(spell.get("id", "")))
	candidates.sort()
	return _pick(candidates, key, "shrine_spell")

static func treasure_chest_choices(gold: int, experience: int) -> Array:
	return [
		{"id": "gold", "label": "Take %s gold" % _thousands(gold), "rewards": {"gold": gold}},
		{"id": "experience", "label": "Gain %s experience" % _thousands(experience), "rewards": {"experience": experience}},
	]

static func _pile(object: Dictionary, key: String, resource_id: String) -> Dictionary:
	var amount := 0
	if resource_id == "gold":
		amount = 100 * _roll_range(key, "amount", 5, 10)
	elif resource_id in RARE_RESOURCES:
		amount = _roll_range(key, "amount", 3, 6)
	else:
		amount = _roll_range(key, "amount", 5, 10)
	return _node(object, PILE_SITES[resource_id], "reward_reference", {NodePayload.PAYLOAD_REWARDS: {resource_id: amount}}, resource_id)

static func _node(object: Dictionary, site_id: String, kind: String, payload: Dictionary, resource_id: String = "") -> Dictionary:
	var node: Dictionary = object.duplicate(true)
	node["site_id"] = site_id
	node["kind"] = kind
	node["native_record_kind"] = kind
	if resource_id != "":
		node["resource_id"] = resource_id
	else:
		node.erase("resource_id")
	var map_object := ContentService.get_map_object_for_resource_site(site_id)
	var object_id := String(map_object.get("id", "")).strip_edges()
	if object_id != "":
		node["object_id"] = object_id
	for payload_key in payload.keys():
		node[payload_key] = payload[payload_key]
	node["generated_reward_translation"] = "h3m_type_%d" % int(object.get("h3m_type_id", -1))
	return node

static func _random_resource_id(key: String) -> String:
	# HoMM3 rolls the seven resources evenly; the four rare slots spread over six rares.
	var subtypes := [0, 1, 2, 3, 4, 5, 6]
	var subtype := int(subtypes[_roll(key, "random_resource", subtypes.size())])
	var resource_id := String(H3M_COMMON_RESOURCE_BY_SUBTYPE.get(subtype, ""))
	return resource_id if resource_id != "" else _pick(RARE_RESOURCES, key, "rare")

static func _scroll_spell_id(key: String) -> String:
	var total := 0
	for tier in SCROLL_TIER_WEIGHTS.keys():
		total += int(SCROLL_TIER_WEIGHTS[tier])
	var roll := _roll(key, "scroll_tier", total)
	var chosen_tier := 1
	for tier in [1, 2, 3, 4]:
		roll -= int(SCROLL_TIER_WEIGHTS[tier])
		if roll < 0:
			chosen_tier = tier
			break
	var candidates := []
	for spell in ContentService.load_json("res://content/spells.json").get("items", []):
		if spell is Dictionary and int(spell.get("tier", 0)) == chosen_tier and String(spell.get("id", "")) != "":
			candidates.append(String(spell.get("id", "")))
	candidates.sort()
	return _pick(candidates, key, "scroll_spell") if not candidates.is_empty() else ""

static func _pick(options: Array, key: String, salt: String) -> String:
	return String(options[_roll(key, salt, options.size())]) if not options.is_empty() else ""

static func _roll_range(key: String, salt: String, low: int, high: int) -> int:
	return low + _roll(key, salt, high - low + 1)

static func _roll(key: String, salt: String, count: int) -> int:
	return _hash32("%s|%s" % [key, salt]) % max(1, count)

static func _hash32(text: String) -> int:
	# FNV-1a with a MurmurHash3 finalizer, so the low bits used by small
	# moduli do not follow the parity of the input bytes.
	var value := 2166136261
	for byte in text.to_utf8_buffer():
		value = ((value ^ byte) * 16777619) & 0xffffffff
	value ^= value >> 16
	value = (value * 0x85ebca6b) & 0xffffffff
	value ^= value >> 13
	value = (value * 0xc2b2ae35) & 0xffffffff
	value ^= value >> 16
	return value

static func _thousands(value: int) -> String:
	var digits := str(value)
	var grouped := ""
	while digits.length() > 3:
		grouped = "," + digits.substr(digits.length() - 3) + grouped
		digits = digits.substr(0, digits.length() - 3)
	return digits + grouped
