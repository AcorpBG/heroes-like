extends RefCounted
## Turns a generated map's HoMM3 reward and economy objects into original
## sites with HoMM-style payloads: pile sizes, chest tiers, campfire hauls,
## scroll spells and which of the six rares a rare slot holds.
##
## Original-game content translation only. It never consumes the native RNG or
## changes a placement, mask or link: every roll is a stable hash of the
## placement id, so the same package always yields the same map.

const NodePayload = preload("res://scripts/core/ResourceNodePayloadRules.gd")

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

## Returns the node the session should hold for a generated object, or an empty
## dictionary when this object type is not one of the translated reward types.
static func resolve(object: Dictionary) -> Dictionary:
	var type_id := int(object.get("h3m_type_id", -1))
	var subtype := int(object.get("h3m_subtype", -1))
	var key := String(object.get("placement_id", "")).strip_edges()
	if type_id < 0 or key == "":
		return {}
	match type_id:
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
	return {}

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
