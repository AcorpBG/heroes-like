extends RefCounted

const PROFILES_PATH := "res://content/generated_neutral_encounter_profiles.json"

# Original-game content translation only. Never consumes the native RNG or
# changes a generated placement, mask, link, or serialized source quantity.
static func resolve(placement: Dictionary) -> Dictionary:
	if not placement.has("native_guard_quantity"):
		return {"ok": true, "encounter": placement.duplicate(true), "legacy": true}
	var quantity := int(placement.get("native_guard_quantity", -1))
	var source_level := int(placement.get("native_guard_level", -1))
	var subtype := int(placement.get("native_guard_creature_subtype", -1))
	if quantity <= 0 or quantity > 65535 or source_level < 0 or source_level > 6 or subtype < 0:
		return {"ok": false, "error": "native_neutral_quantity_or_species_invalid", "placement_id": placement.get("placement_id", "")}
	var catalog := ContentService.load_json(PROFILES_PATH)
	var candidates: Array = []
	for profile in catalog.get("profiles", []):
		if int(profile.get("tier", -1)) == source_level + 1:
			candidates.append(profile)
	if candidates.is_empty():
		return {"ok": false, "error": "native_neutral_tier_has_no_original_profile"}
	var profile: Dictionary = candidates[_stable_key("native_species_v1:%d" % subtype) % candidates.size()]
	var result := _apply_profile(placement, profile, quantity)
	if bool(result.get("ok", false)):
		var provenance: Dictionary = result.encounter.generated_neutral_profile
		provenance["source_quantity"] = quantity
		provenance["source_subtype"] = subtype
		provenance["source_level"] = source_level
		provenance["quantity_policy"] = "preserve_native_total_headcount"
	return result

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
