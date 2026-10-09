extends RefCounted

const PROFILES_PATH := "res://content/generated_neutral_encounter_profiles.json"
const COMPANIES_PATH := "res://content/generated_neutral_companies.json"
const CREATURE_IDLE_PATH := "res://art/overworld/creature_idle.json"
const QUANTITY_POLICY := "native_budget_as_battle_power_v1"
# The native generator only fields a creature whose usual stack fits the
# budget (about 10 to 100), so its headcount says whether a guard is small or
# large for its tier. Large guards lean to veterans and warbands, small ones
# to levies and packs.
const SMALL_NATIVE_QUANTITY := 20
const LARGE_NATIVE_QUANTITY := 50
const LARGE_KINDS := ["elite", "cadre", "warband", "host"]
const SMALL_KINDS := ["levy", "pack"]
const LEANING_WEIGHT := 3

static var _families_source: Dictionary = {}
static var _families_by_tier: Dictionary = {}

# Original-game content translation only. Never consumes the native RNG or
# changes a generated placement, mask, link, or serialized source quantity.
# The native budget (headcount x creature value) becomes battle power, so a
# guard's strength follows the generator's budget whatever tier it rolled.
static func resolve(placement: Dictionary) -> Dictionary:
	if not placement.has("native_guard_quantity"):
		return {"ok": true, "encounter": placement.duplicate(true), "legacy": true}
	var quantity := int(placement.get("native_guard_quantity", -1))
	var source_level := int(placement.get("native_guard_level", -1))
	var subtype := int(placement.get("native_guard_creature_subtype", -1))
	var source_value := int(placement.get("native_guard_ai_value", -1))
	if quantity <= 0 or quantity > 65535 or source_level < 0 or source_level > 6 or subtype < 0 or source_value <= 0:
		return {"ok": false, "error": "native_neutral_quantity_or_species_invalid", "placement_id": placement.get("placement_id", "")}
	var catalog := ContentService.load_json(COMPANIES_PATH)
	var company := _pick_company(catalog, source_level + 1, String(placement.get("placement_id", "")), quantity)
	if company.is_empty():
		return {"ok": false, "error": "native_neutral_tier_has_no_original_profile"}
	var budget := quantity * source_value
	var rate := float(catalog.get("power_per_native_value", 0.0))
	var result := _apply_company(placement, company, float(budget) * rate)
	if bool(result.get("ok", false)):
		var provenance: Dictionary = result.encounter.generated_neutral_profile
		provenance["source_quantity"] = quantity
		provenance["source_subtype"] = subtype
		provenance["source_level"] = source_level
		provenance["source_value"] = source_value
		provenance["native_budget"] = budget
		provenance["power_per_native_value"] = rate
		provenance["quantity_policy"] = QUANTITY_POLICY
	return result

## One family (a unit line or neutral lead) by placement, then one of its
## companies, leaning by how large the native guard is for its tier.
static func _pick_company(catalog: Dictionary, tier: int, placement_id: String, quantity: int) -> Dictionary:
	var families: Array = _company_families(catalog).get(tier, [])
	if families.is_empty():
		return {}
	var members: Array = families[_stable_key("company_family_v1:" + placement_id) % families.size()]
	var weights: Array = []
	var total := 0
	for company in members:
		var kind := String(company.get("kind", "")).split("_")[0]
		var weight := 1
		if (quantity >= LARGE_NATIVE_QUANTITY and kind in LARGE_KINDS) or (quantity <= SMALL_NATIVE_QUANTITY and kind in SMALL_KINDS):
			weight = LEANING_WEIGHT
		weights.append(weight)
		total += weight
	var roll := _stable_key("company_kind_v1:" + placement_id) % total
	for index in range(members.size()):
		roll -= int(weights[index])
		if roll < 0:
			return members[index]
	return members[members.size() - 1]

static func _company_families(catalog: Dictionary) -> Dictionary:
	if is_same(catalog, _families_source):
		return _families_by_tier
	var by_tier: Dictionary = {}
	var family_index: Dictionary = {}
	for company in catalog.get("companies", []):
		var tier := int(company.get("tier", -1))
		var key := "%d|%s" % [tier, String(company.get("family", ""))]
		if not family_index.has(key):
			family_index[key] = []
			if not by_tier.has(tier):
				by_tier[tier] = []
			by_tier[tier].append(family_index[key])
		family_index[key].append(company)
	_families_source = catalog
	_families_by_tier = by_tier
	return by_tier

## Each slot gets its share of the power, as whole creatures of its unit. A
## support too small for one creature passes its share to the lead.
static func _apply_company(placement: Dictionary, company: Dictionary, power: float) -> Dictionary:
	var encounter_id := String(company.get("encounter_id", ""))
	if ContentService.get_encounter(encounter_id).is_empty():
		return {"ok": false, "error": "native_neutral_original_profile_missing", "company_id": company.get("id", "")}
	var slots: Array = company.get("slots", [])
	if slots.is_empty():
		return {"ok": false, "error": "native_neutral_original_profile_missing", "company_id": company.get("id", "")}
	var primary_id := String(slots[0].get("unit_id", ""))
	var asset_id := String(company.get("asset_id", ""))
	if not _company_art_ready(asset_id, primary_id):
		return {"ok": false, "error": "native_neutral_original_art_missing", "asset_id": asset_id, "unit_id": primary_id}
	var counts: Array = []
	var carried := 0.0
	for index in range(slots.size()):
		var unit_power := _unit_power(String(slots[index].get("unit_id", "")))
		if unit_power <= 0.0:
			return {"ok": false, "error": "native_neutral_original_profile_missing", "unit_id": slots[index].get("unit_id", "")}
		var share := float(slots[index].get("share", 0.0))
		var count := int(round(power * share / unit_power))
		if index > 0 and count < 1:
			carried += share
			count = 0
		counts.append(count)
	counts[0] = maxi(1, int(round(power * (float(slots[0].get("share", 0.0)) + carried) / _unit_power(primary_id))))
	var seed := _stable_key(String(placement.get("placement_id", "")))
	var primary_groups := mini(int(counts[0]), 1 + (seed / 3) % 3)
	var stacks: Array = []
	for index in range(primary_groups):
		stacks.append({"unit_id": primary_id, "count": int(counts[0]) / primary_groups + (1 if index < int(counts[0]) % primary_groups else 0)})
	var total := int(counts[0])
	for index in range(1, slots.size()):
		if int(counts[index]) > 0:
			stacks.append({"unit_id": String(slots[index].get("unit_id", "")), "count": int(counts[index])})
			total += int(counts[index])
	var army := {
		"id": "army_" + String(company.get("id", "")),
		"name": String(company.get("name", "")),
		"affiliation": "neutral",
		"stacks": stacks,
	}
	var encounter := placement.duplicate(true)
	encounter["encounter_id"] = encounter_id
	encounter["object_id"] = encounter_id
	encounter["enemy_army"] = army
	encounter["prefer_identity_landmark"] = true
	encounter["generated_neutral_profile"] = {
		"version": 2,
		"company_id": String(company.get("id", "")),
		"encounter_id": encounter_id,
		"asset_id": asset_id,
		"primary_unit_id": primary_id,
		"kind": String(company.get("kind", "")),
		"faction_id": String(company.get("faction_id", "")),
		# Whole numbers, so saves round-trip them exactly.
		"power_target": int(round(power)),
		"power": int(round(_army_power(stacks))),
		"total_quantity": total,
		"formation": "pure" if stacks.size() == primary_groups else "mixed",
	}
	return {"ok": true, "encounter": encounter}

## A dedicated actor painting when the company names one, otherwise the lead
## unit's overworld idle animation.
static func _company_art_ready(asset_id: String, unit_id: String) -> bool:
	if asset_id != "":
		var asset: Dictionary = ContentService.load_json("res://art/overworld/manifest.json").get("object_assets", {}).get(asset_id, {})
		return not asset.is_empty() and ResourceLoader.exists(String(asset.get("path", "")))
	var idle: Dictionary = ContentService.load_json(CREATURE_IDLE_PATH).get("units", {}).get(unit_id, {})
	return not idle.is_empty() and ResourceLoader.exists(String(idle.get("path", "")))

## Original stacks with the battle power of native ones: each native stack,
## [creature value, headcount], becomes its paired unit with value x headcount
## x power_per_native_value of power. Stacks of one unit pool their power before
## it becomes whole creatures (at least one), then share them by budget, so a
## guard split in five small stacks keeps its strength. Empty when a unit or the
## rate is missing.
static func stacks_for_native_budget(native_stacks: Array, unit_ids: Array) -> Array:
	var rate := float(ContentService.load_json(COMPANIES_PATH).get("power_per_native_value", 0.0))
	if rate <= 0.0 or native_stacks.size() > unit_ids.size():
		return []
	var budgets := []
	var pooled := {}
	for index in range(native_stacks.size()):
		var unit_id := String(unit_ids[index])
		if _unit_power(unit_id) <= 0.0:
			return []
		var native: Array = native_stacks[index]
		var budget := maxf(0.0, float(native[0]) * float(native[1]) * rate)
		budgets.append(budget)
		pooled[unit_id] = float(pooled.get(unit_id, 0.0)) + budget
	var counts := []
	counts.resize(native_stacks.size())
	counts.fill(0)
	for unit_id in pooled.keys():
		var total := maxi(1, int(round(float(pooled[unit_id]) / _unit_power(String(unit_id)))))
		var shares := []
		var given := 0
		for index in range(native_stacks.size()):
			if String(unit_ids[index]) != String(unit_id):
				continue
			var exact := float(total) * float(budgets[index]) / float(pooled[unit_id]) if float(pooled[unit_id]) > 0.0 else float(total)
			counts[index] = int(floor(exact))
			given += int(counts[index])
			shares.append([exact - floor(exact), index])
			if float(pooled[unit_id]) <= 0.0:
				break
		# The creatures left over go to the stacks with the largest remainders.
		shares.sort_custom(func(a, b): return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
		for share_index in range(mini(total - given, shares.size())):
			counts[int(shares[share_index][1])] += 1
	var stacks := []
	for index in range(native_stacks.size()):
		if int(counts[index]) > 0:
			stacks.append({"unit_id": String(unit_ids[index]), "count": int(counts[index])})
	return stacks

static func _unit_power(unit_id: String) -> float:
	return _army_power([{"unit_id": unit_id, "count": 1}])

static func _army_power(stacks: Array) -> float:
	# Loaded on use, as BattleRules does, to keep the AI rules out of this preload graph.
	return float(load("res://scripts/core/AiHeroRules.gd").army_power(stacks))

static func resolve_supplemental(placement: Dictionary, site_id: String) -> Dictionary:
	var catalog := ContentService.load_json(PROFILES_PATH)
	var encounter_id := String(catalog.get("supplemental_sites", {}).get(site_id, ""))
	var profile := {}
	for candidate in catalog.get("profiles", []):
		if String(candidate.get("encounter_id", "")) == encounter_id:
			profile = candidate
	if profile.is_empty():
		return {"ok": false, "error": "supplemental_neutral_site_profile_missing", "site_id": site_id}
	var previous := ContentService.get_encounter(String(placement.get("encounter_id", "")))
	var previous_army := ContentService.get_army_group(String(previous.get("enemy_group_id", "")))
	var budget := _army_strength(previous_army)
	var army := ContentService.get_army_group(String(profile.get("army_group_id", "")))
	var minimum_cost := budget + 1
	for stack in army.get("stacks", []):
		minimum_cost = mini(minimum_cost, _unit_strength(String(stack.get("unit_id", ""))))
	if budget <= 0 or minimum_cost <= 0:
		return {"ok": false, "error": "supplemental_neutral_original_army_missing"}
	# This is the pre-existing original-game supplemental guard, not a native
	# creature record. Keep its established army-strength ceiling; never invent
	# native quantity/level metadata for it.
	for quantity in range(budget / minimum_cost, 0, -1):
		var result := _apply_profile(placement, profile, quantity)
		if not bool(result.get("ok", false)):
			return result
		if _army_strength(result.encounter.enemy_army) <= budget:
			result.encounter.generated_neutral_profile["quantity_policy"] = "existing_supplemental_army_strength_ceiling"
			result.encounter.generated_neutral_profile["original_strength_ceiling"] = budget
			result.encounter.generated_neutral_profile["site_id"] = site_id
			return result
	return {"ok": false, "error": "supplemental_neutral_budget_cannot_fit_unit"}

static func _army_strength(army: Dictionary) -> int:
	var total := 0
	for stack in army.get("stacks", []):
		total += int(stack.get("count", 0)) * _unit_strength(String(stack.get("unit_id", "")))
	return total

static func with_authored_guard_art(placement: Dictionary) -> Dictionary:
	var result := placement.duplicate(true)
	var encounter_id := String(result.get("encounter_id", ""))
	for profile in ContentService.load_json(PROFILES_PATH).get("profiles", []):
		if String(profile.get("encounter_id", "")) != encounter_id:
			continue
		result["prefer_identity_landmark"] = true
		result["generated_neutral_profile"] = {
			"version": 1, "encounter_id": encounter_id,
			"asset_id": String(profile.get("asset_id", "")),
			"quantity_policy": "authored_guard_contract_unchanged",
		}
		break
	return result

## A guard that fields its own army shows its strongest stack's unit, in that
## unit's overworld idle pose, as a generated company without a painting of
## its own does. Unchanged when the unit has no idle art.
static func with_lead_unit_art(placement: Dictionary, quantity_policy: String) -> Dictionary:
	var result := placement.duplicate(true)
	var stacks: Array = result.get("enemy_army", {}).get("stacks", []) if result.get("enemy_army", {}) is Dictionary else []
	var lead := ""
	var lead_power := -1.0
	var total := 0
	var unit_ids := []
	for stack in stacks:
		if not (stack is Dictionary):
			continue
		var power := _army_power([stack])
		total += int(stack.get("count", 0))
		if String(stack.get("unit_id", "")) not in unit_ids:
			unit_ids.append(String(stack.get("unit_id", "")))
		if power > lead_power:
			lead_power = power
			lead = String(stack.get("unit_id", ""))
	if lead == "" or not _company_art_ready("", lead):
		return result
	result["prefer_identity_landmark"] = true
	result["generated_neutral_profile"] = {
		"version": 2,
		"encounter_id": String(result.get("encounter_id", "")),
		"asset_id": "",
		"primary_unit_id": lead,
		"quantity_policy": quantity_policy,
		"power": int(round(_army_power(stacks))),
		"total_quantity": total,
		"formation": "pure" if unit_ids.size() == 1 else "mixed",
	}
	return result

static func _unit_strength(unit_id: String) -> int:
	var unit := ContentService.get_unit(unit_id)
	if unit.is_empty(): return 0
	return maxi(6, int(unit.get("hp", 1)) + int(unit.get("min_damage", 1)) + int(unit.get("max_damage", 1)) + (3 if bool(unit.get("ranged", false)) else 0))

static func _apply_profile(placement: Dictionary, profile: Dictionary, quantity: int) -> Dictionary:
	var encounter_id := String(profile.get("encounter_id", ""))
	var definition := ContentService.get_encounter(encounter_id)
	var asset_id := String(profile.get("asset_id", ""))
	var art := ContentService.load_json("res://art/overworld/manifest.json")
	var asset: Dictionary = art.get("object_assets", {}).get(asset_id, {})
	if asset.is_empty() or not ResourceLoader.exists(String(asset.get("path", ""))):
		return {"ok": false, "error": "native_neutral_original_art_missing", "asset_id": asset_id}
	var army := ContentService.get_army_group(String(profile.get("army_group_id", ""))).duplicate(true)
	var base_stacks: Array = army.get("stacks", [])
	if definition.is_empty() or base_stacks.is_empty():
		return {"ok": false, "error": "native_neutral_original_profile_missing"}
	var seed := _stable_key(String(placement.get("placement_id", "")))
	var primary_id := String(base_stacks[0].get("unit_id", ""))
	var stacks: Array = []
	var support_count := 0
	if seed % 3 != 0 and base_stacks.size() > 1 and quantity >= 4:
		support_count = quantity / 4
	var primary_count := quantity - support_count
	var primary_groups := mini(primary_count, 1 + (seed / 3) % 3)
	for index in range(primary_groups):
		stacks.append({"unit_id": primary_id, "count": primary_count / primary_groups + (1 if index < primary_count % primary_groups else 0)})
	if support_count > 0:
		var support_index := 1 + (seed / 9) % (base_stacks.size() - 1)
		stacks.append({"unit_id": String(base_stacks[support_index].get("unit_id", "")), "count": support_count})
	army["stacks"] = stacks
	var encounter := placement.duplicate(true)
	encounter["encounter_id"] = encounter_id
	encounter["object_id"] = encounter_id
	encounter["enemy_army"] = army
	encounter["prefer_identity_landmark"] = true
	encounter["generated_neutral_profile"] = {
		"version": 1,
		"encounter_id": encounter_id,
		"asset_id": asset_id,
		"total_quantity": quantity,
		"formation": "pure" if support_count == 0 else "mixed",
	}
	return {"ok": true, "encounter": encounter}

static func _stable_key(value: String) -> int:
	return value.sha256_text().substr(0, 8).hex_to_int()
