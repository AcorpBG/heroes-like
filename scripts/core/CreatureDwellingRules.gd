extends RefCounted
## HoMM3-style creature dwellings. A dwelling makes one creature (a few
## multi-creature dwellings make several) at that creature's weekly growth.
## A hero hires them at the dwelling; tier 1 creatures are free. Unhired
## creatures do not carry over: the population resets each week. Tier 5 and
## higher dwellings keep a guard of three weeks of their creature, and every
## side has to beat that guard once before it can flag the dwelling. Each
## flagged dwelling adds +1 weekly growth for its creature in the owner's
## towns. See docs/creature-dwellings.md.

const HumanEngine = preload("res://scripts/core/HumanEngine.gd")
static var _human_engine_mode: int = HumanEngine.mode


const FAMILY := "neutral_dwelling"
const KIND_REFUGEE_CAMP := "refugee_camp"
const POPULATION := "dwelling_population"
const POPULATION_WEEK := "dwelling_week"
const GUARD_BEATEN := "dwelling_guard_beaten"
const GUARD_SURVIVORS := "dwelling_guard_survivors"
const WEEK_LENGTH := 7
const GUARD_MIN_TIER := 5
const GUARD_WEEKS := 3
const FREE_TIER := 1
const NODE_KEYS := [POPULATION, POPULATION_WEEK, GUARD_BEATEN, GUARD_SURVIVORS]

static var _refugee_pool: Array = []
static var _base_by_upgrade: Dictionary = {}
## AI weight (content/ai_hero_weights.json): the least week_value counts a
## creature worth. AiHeroRules puts a computer player's set in place
## (apply_ai_weights); until it does, the default set.
static var AI_CREATURE_MIN_VALUE: int
static var _ai_weights_ready := false

static func apply_ai_weights(weights: Dictionary) -> void:
	AI_CREATURE_MIN_VALUE = int(weights["dwelling_creature_min_value"])
	_ai_weights_ready = true

static func is_dwelling(site: Dictionary) -> bool:
	return String(site.get("family", "")) == FAMILY

static func is_refugee_camp(site: Dictionary) -> bool:
	return is_dwelling(site) and String(site.get("dwelling_kind", "")) == KIND_REFUGEE_CAMP

static func week_index(day: int) -> int:
	return int(floor(float(max(1, day) - 1) / float(WEEK_LENGTH)))

static func unit_tier(unit_id: String) -> int:
	return int(ContentService.get_unit(unit_id).get("tier", 1))

## The creatures this dwelling offers this week.
static func creatures(node: Dictionary, site: Dictionary, day: int) -> Array:
	if is_refugee_camp(site):
		var unit_id := refugee_unit(node, day)
		return [unit_id] if unit_id != "" else []
	var result := []
	var recruits = site.get("weekly_recruits", {})
	if recruits is Dictionary:
		for unit_id in recruits.keys():
			result.append(String(unit_id))
	return result

## One week of each creature: its town growth.
static func weekly_growth(node: Dictionary, site: Dictionary, day: int) -> Dictionary:
	var growth := {}
	var authored = site.get("weekly_recruits", {})
	for unit_id in creatures(node, site, day):
		var amount := int(ContentService.get_unit(unit_id).get("growth", 1))
		if not is_refugee_camp(site) and authored is Dictionary and authored.has(unit_id):
			amount = int(authored[unit_id])
		growth[unit_id] = max(1, amount)
	return growth

## Creatures still available to hire this week.
static func population(node: Dictionary, site: Dictionary, day: int) -> Dictionary:
	var stored = node.get(POPULATION, {})
	if int(node.get(POPULATION_WEEK, -1)) == week_index(day) and stored is Dictionary:
		return stored.duplicate(true)
	return weekly_growth(node, site, day)

static func take(node: Dictionary, site: Dictionary, unit_id: String, count: int, day: int) -> void:
	var available := population(node, site, day)
	available[unit_id] = max(0, int(available.get(unit_id, 0)) - max(0, count))
	node[POPULATION] = available
	node[POPULATION_WEEK] = week_index(day)

static func unit_cost(unit_id: String) -> Dictionary:
	var unit := ContentService.get_unit(unit_id)
	if int(unit.get("tier", 1)) <= FREE_TIER:
		return {}
	var cost = unit.get("cost", {})
	return cost.duplicate(true) if cost is Dictionary else {}

static func hire_cost(hires: Dictionary) -> Dictionary:
	var total := {}
	for unit_id in hires.keys():
		var count := int(hires[unit_id])
		var cost := unit_cost(String(unit_id))
		for key in cost.keys():
			total[key] = int(total.get(key, 0)) + int(cost[key]) * count
	return total

## The Drifters' Camp offers a different base creature each week, rolled from
## a stable hash of the placement and the week.
static func refugee_unit(node: Dictionary, day: int) -> String:
	var pool := _refugee_candidates()
	if pool.is_empty():
		return ""
	var key := "%s|refugee|%d" % [String(node.get("placement_id", "")), week_index(day)]
	return String(pool[_stable_roll(key, pool.size())])

static func _refugee_candidates() -> Array:
	if not _refugee_pool.is_empty():
		return _refugee_pool
	var town_units := {}
	for building in ContentService.load_json("res://content/buildings.json").get("items", []):
		if building is Dictionary and not bool(building.get("retired_from_town_tree", false)):
			town_units[String(building.get("unlock_unit_id", ""))] = true
	for unit in ContentService.load_json("res://content/units.json").get("items", []):
		if not (unit is Dictionary):
			continue
		var unit_id := String(unit.get("id", ""))
		var neutral := String(unit.get("faction_id", "")) == ""
		if unit_id == "" or base_unit_id(unit_id) != unit_id:
			continue
		if neutral or town_units.has(unit_id):
			_refugee_pool.append(unit_id)
	_refugee_pool.sort()
	return _refugee_pool

## The unupgraded unit a creature belongs to (veterans share their base
## creature's dwelling and town growth).
static func base_unit_id(unit_id: String) -> String:
	if _base_by_upgrade.is_empty():
		for unit in ContentService.load_json("res://content/units.json").get("items", []):
			if unit is Dictionary and String(unit.get("upgrade_to", "")) != "":
				_base_by_upgrade[String(unit.get("upgrade_to", ""))] = String(unit.get("id", ""))
		_base_by_upgrade["__loaded__"] = ""
	return String(_base_by_upgrade.get(unit_id, unit_id))

## The creature that guards the dwelling: its strongest creature of tier 5
## or higher. Refugee camps are never guarded.
static func guard_unit(node: Dictionary, site: Dictionary, day: int) -> String:
	if is_refugee_camp(site):
		return ""
	var best := ""
	for unit_id in creatures(node, site, day):
		var tier := unit_tier(unit_id)
		if tier >= GUARD_MIN_TIER and (best == "" or tier > unit_tier(best)):
			best = unit_id
	return best

static func is_guarded(node: Dictionary, site: Dictionary, day: int) -> bool:
	return guard_unit(node, site, day) != ""

static func guard_beaten(node: Dictionary, side: String) -> bool:
	var beaten = node.get(GUARD_BEATEN, {})
	return beaten is Dictionary and beaten.has(side)

## True while this side still has to fight the guard.
static func guard_blocks(node: Dictionary, site: Dictionary, side: String, day: int) -> bool:
	return is_guarded(node, site, day) and not guard_beaten(node, side) and not guard_stacks(node, site, side, day).is_empty()

static func full_guard(node: Dictionary, site: Dictionary, day: int) -> Array:
	var unit_id := guard_unit(node, site, day)
	if unit_id == "":
		return []
	var growth := int(weekly_growth(node, site, day).get(unit_id, 1))
	return [{"unit_id": unit_id, "count": GUARD_WEEKS * max(1, growth)}]

## The guard this side faces: survivors of its own failed attack this week,
## otherwise the full guard, which returns at the start of every week.
static func guard_stacks(node: Dictionary, site: Dictionary, side: String, day: int) -> Array:
	if not is_guarded(node, site, day) or guard_beaten(node, side):
		return []
	var survivors = node.get(GUARD_SURVIVORS, {})
	if survivors is Dictionary and survivors.has(side) and survivors[side] is Dictionary:
		var record: Dictionary = survivors[side]
		if int(record.get("week", -1)) == week_index(day) and record.get("stacks", []) is Array:
			return record.get("stacks", []).duplicate(true)
	return full_guard(node, site, day)

static func record_guard_result(node: Dictionary, side: String, survivor_stacks: Array, won: bool, day: int) -> void:
	var survivors = node.get(GUARD_SURVIVORS, {})
	if not (survivors is Dictionary):
		survivors = {}
	if won:
		var beaten = node.get(GUARD_BEATEN, {})
		if not (beaten is Dictionary):
			beaten = {}
		beaten[side] = day
		node[GUARD_BEATEN] = beaten
		survivors.erase(side)
	else:
		survivors[side] = {"week": week_index(day), "stacks": survivor_stacks.duplicate(true)}
	if survivors.is_empty():
		node.erase(GUARD_SURVIVORS)
	else:
		node[GUARD_SURVIVORS] = survivors

static func describe_creatures(node: Dictionary, site: Dictionary, day: int) -> String:
	var parts := []
	var growth := weekly_growth(node, site, day)
	for unit_id in growth.keys():
		parts.append("%d %s" % [int(growth[unit_id]), String(ContentService.get_unit(unit_id).get("name", unit_id))])
	return ", ".join(parts)

## A short line for map tooltips and the context panel.
static func summary(node: Dictionary, site: Dictionary, day: int) -> String:
	if _human_engine_mode == HumanEngine.GDSCRIPT:
		return summary__gd(node, site, day)
	if _human_engine_mode == HumanEngine.NATIVE:
		return HumanEngine.native(&"CreatureDwellingRules.summary", [node, site, day])
	var result = summary__gd(node, site, day)
	HumanEngine.check(&"CreatureDwellingRules.summary", [node, site, day], result)
	return result

static func summary__gd(node: Dictionary, site: Dictionary, day: int) -> String:
	if is_refugee_camp(site):
		var unit_id := refugee_unit(node, day)
		return "This week %s; a new creature each week" % describe_creatures(node, site, day) if unit_id != "" else "A new creature each week"
	var parts := ["Hire %s a week" % describe_creatures(node, site, day)]
	for unit_id in creatures(node, site, day):
		if unit_tier(unit_id) <= FREE_TIER:
			parts.append("free")
			break
	var guard := full_guard(node, site, day)
	if not guard.is_empty():
		parts.append("guarded by %d %s" % [int(guard[0].get("count", 0)), String(ContentService.get_unit(String(guard[0].get("unit_id", ""))).get("name", ""))])
	return ", ".join(parts)

## Gold-equivalent value of a week's creatures, for AI targeting.
static func week_value(node: Dictionary, site: Dictionary, day: int, available_only: bool = false) -> int:
	if not _ai_weights_ready:
		apply_ai_weights(ContentService.default_ai_hero_weights())
	var value := 0
	var counts := population(node, site, day) if available_only else weekly_growth(node, site, day)
	for unit_id in counts.keys():
		var unit := ContentService.get_unit(String(unit_id))
		var price := 0
		var cost = unit.get("cost", {})
		if cost is Dictionary:
			price = int(cost.get("gold", 0))
		value += int(counts[unit_id]) * max(AI_CREATURE_MIN_VALUE, price)
	return value

static func _stable_roll(key: String, size: int) -> int:
	if size <= 0:
		return 0
	var hash_value := 2166136261
	for byte in key.to_utf8_buffer():
		hash_value = ((hash_value ^ int(byte)) * 16777619) & 0xffffffff
	hash_value ^= hash_value >> 16
	hash_value = (hash_value * 0x85ebca6b) & 0xffffffff
	hash_value ^= hash_value >> 13
	hash_value = (hash_value * 0xc2b2ae35) & 0xffffffff
	hash_value ^= hash_value >> 16
	return int(hash_value % size)
