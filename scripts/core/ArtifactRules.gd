class_name ArtifactRules
extends RefCounted

const EQUIPMENT_SLOTS := ["boots", "banner", "armor", "trinket"]

static func ensure_hero_artifacts(hero_state: Dictionary) -> Dictionary:
	var artifacts = normalize_hero_artifacts(hero_state.get("artifacts", {}))
	hero_state["artifacts"] = artifacts
	return hero_state

static func build_artifact_nodes(placements: Variant) -> Array:
	var nodes := []
	if not (placements is Array):
		return nodes

	for placement in placements:
		if not (placement is Dictionary):
			continue
		nodes.append(
			{
				"placement_id": String(placement.get("placement_id", "")),
				"artifact_id": String(placement.get("artifact_id", "")),
				"x": int(placement.get("x", 0)),
				"y": int(placement.get("y", 0)),
				"collected": bool(placement.get("collected", false)),
				"collected_by_faction_id": String(placement.get("collected_by_faction_id", "")),
				"collected_day": max(0, int(placement.get("collected_day", 0))),
			}
		)
	return nodes

static func normalize_artifact_nodes(nodes: Variant) -> Array:
	return build_artifact_nodes(nodes)

static func normalize_hero_artifacts(value: Variant) -> Dictionary:
	var equipped := _blank_equipped_slots()
	var inventory := []
	if value is Dictionary:
		var raw_equipped = value.get("equipped", {})
		if raw_equipped is Dictionary:
			for slot in EQUIPMENT_SLOTS:
				_register_equipped_candidate(String(raw_equipped.get(slot, "")), equipped, inventory)

		var raw_inventory = value.get("inventory", [])
		if raw_inventory is Array:
			for artifact_id_value in raw_inventory:
				_append_inventory_artifact(String(artifact_id_value), equipped, inventory)

	return {"equipped": equipped, "inventory": inventory}

static func owned_artifact_ids(hero_state: Dictionary) -> Array:
	var artifacts = normalize_hero_artifacts(hero_state.get("artifacts", {}))
	var artifact_ids := []
	for slot in EQUIPMENT_SLOTS:
		var equipped_id := String(artifacts.get("equipped", {}).get(slot, ""))
		if equipped_id != "" and equipped_id not in artifact_ids:
			artifact_ids.append(equipped_id)
	for artifact_id_value in artifacts.get("inventory", []):
		var artifact_id := String(artifact_id_value)
		if artifact_id != "" and artifact_id not in artifact_ids:
			artifact_ids.append(artifact_id)
	return artifact_ids

static func has_artifact(hero_state: Dictionary, artifact_id: String) -> bool:
	return String(locate_artifact(hero_state, artifact_id).get("location", "missing")) != "missing"

static func locate_artifact(hero_state: Dictionary, artifact_id: String) -> Dictionary:
	var artifacts = normalize_hero_artifacts(hero_state.get("artifacts", {}))
	if artifact_id == "":
		return {"location": "missing", "slot": ""}

	for slot in EQUIPMENT_SLOTS:
		if String(artifacts.get("equipped", {}).get(slot, "")) == artifact_id:
			return {"location": "equipped", "slot": slot}

	for inventory_id_value in artifacts.get("inventory", []):
		if String(inventory_id_value) == artifact_id:
			return {"location": "inventory", "slot": ""}

	return {"location": "missing", "slot": ""}

static func aggregate_bonuses(hero_state: Dictionary) -> Dictionary:
	hero_state = ensure_hero_artifacts(hero_state)
	var totals := {
		"overworld_movement": 0,
		"scouting_radius": 0,
		"battle_attack": 0,
		"battle_defense": 0,
		"battle_initiative": 0,
		"daily_income": {"gold": 0, "wood": 0, "ore": 0},
	}

	var equipped = hero_state.get("artifacts", {}).get("equipped", {})
	for slot in EQUIPMENT_SLOTS:
		var artifact_id := String(equipped.get(slot, ""))
		if artifact_id == "":
			continue
		var artifact := ContentService.get_artifact(artifact_id)
		var bonuses = artifact.get("bonuses", {})
		totals["overworld_movement"] = int(totals.get("overworld_movement", 0)) + int(bonuses.get("overworld_movement", 0))
		totals["scouting_radius"] = int(totals.get("scouting_radius", 0)) + int(bonuses.get("scouting_radius", 0))
		totals["battle_attack"] = int(totals.get("battle_attack", 0)) + int(bonuses.get("battle_attack", 0))
		totals["battle_defense"] = int(totals.get("battle_defense", 0)) + int(bonuses.get("battle_defense", 0))
		totals["battle_initiative"] = int(totals.get("battle_initiative", 0)) + int(bonuses.get("battle_initiative", 0))
		totals["daily_income"] = _merge_resources(totals.get("daily_income", {}), bonuses.get("daily_income", {}))

	return totals

static func claim_artifact(
	hero_state: Dictionary,
	artifact_id: String,
	source_verb: String = "Recovered",
	auto_equip: bool = true
) -> Dictionary:
	var hero = ensure_hero_artifacts(hero_state.duplicate(true))
	var artifact := ContentService.get_artifact(artifact_id)
	if artifact.is_empty():
		return {"ok": false, "hero": hero, "message": "Unknown artifact."}

	var location := locate_artifact(hero, artifact_id)
	if String(location.get("location", "missing")) != "missing":
		return {
			"ok": true,
			"hero": hero,
			"message": _already_owned_message(artifact_id, location, source_verb),
			"duplicate": true,
			"auto_equipped": false,
		}

	var artifacts = hero.get("artifacts", {})
	var inventory = artifacts.get("inventory", [])
	inventory.append(artifact_id)
	artifacts["inventory"] = inventory
	hero["artifacts"] = normalize_hero_artifacts(artifacts)

	var message := "%s %s." % [source_verb, artifact_name(artifact_id)]
	var slot := artifact_slot(artifact_id)
	if auto_equip and slot != "" and String(hero.get("artifacts", {}).get("equipped", {}).get(slot, "")) == "":
		var equip_result := equip_artifact(hero, artifact_id)
		hero = equip_result.get("hero", hero)
		message = "%s %s" % [source_verb, String(equip_result.get("suffix_message", artifact_name(artifact_id) + "."))]
		return {
			"ok": true,
			"hero": hero,
			"message": message,
			"duplicate": false,
			"auto_equipped": true,
		}

	return {
		"ok": true,
		"hero": hero,
		"message": message,
		"duplicate": false,
		"auto_equipped": false,
	}

static func pickup_artifact(hero_state: Dictionary, artifact_id: String) -> Dictionary:
	return claim_artifact(hero_state, artifact_id, "Recovered", true)

static func merge_hero_artifacts(base_artifacts: Variant, imported_artifacts: Variant) -> Dictionary:
	var merged = normalize_hero_artifacts(base_artifacts)
	var imported = normalize_hero_artifacts(imported_artifacts)
	var equipped = merged.get("equipped", {})
	var inventory = merged.get("inventory", [])

	for slot in EQUIPMENT_SLOTS:
		var imported_id := String(imported.get("equipped", {}).get(slot, ""))
		if imported_id == "" or _artifact_is_owned(equipped, inventory, imported_id):
			continue
		if String(equipped.get(slot, "")) == "":
			equipped[slot] = imported_id
		else:
			inventory.append(imported_id)

	for artifact_id_value in imported.get("inventory", []):
		_append_inventory_artifact(String(artifact_id_value), equipped, inventory)

	merged["equipped"] = equipped
	merged["inventory"] = inventory
	return normalize_hero_artifacts(merged)

static func perform_management_action(hero_state: Dictionary, action_id: String) -> Dictionary:
	if action_id.begins_with("equip_artifact:"):
		return equip_artifact(hero_state, action_id.trim_prefix("equip_artifact:"))
	if action_id.begins_with("unequip_artifact:"):
		return unequip_artifact(hero_state, action_id.trim_prefix("unequip_artifact:"))
	return {
		"ok": false,
		"hero": ensure_hero_artifacts(hero_state.duplicate(true)),
		"message": "That artifact order is not supported.",
	}

static func equip_artifact(hero_state: Dictionary, artifact_id: String) -> Dictionary:
	var hero = ensure_hero_artifacts(hero_state.duplicate(true))
	var artifact := ContentService.get_artifact(artifact_id)
	if artifact.is_empty():
		return {"ok": false, "hero": hero, "message": "That artifact is not known."}

	var slot := artifact_slot(artifact_id)
	if slot == "" or slot not in EQUIPMENT_SLOTS:
		return {"ok": false, "hero": hero, "message": "That artifact cannot be equipped."}

	var location := locate_artifact(hero, artifact_id)
	if String(location.get("location", "missing")) == "equipped":
		return {
			"ok": false,
			"hero": hero,
			"message": "%s is already equipped in the %s slot." % [artifact_name(artifact_id), slot],
		}
	if String(location.get("location", "missing")) != "inventory":
		return {"ok": false, "hero": hero, "message": "That artifact is not in the pack."}

	var artifacts = hero.get("artifacts", {})
	var equipped = artifacts.get("equipped", {})
	var inventory = artifacts.get("inventory", [])
	_remove_artifact_from_inventory(inventory, artifact_id)

	var swapped_out_id := String(equipped.get(slot, ""))
	if swapped_out_id != "":
		equipped[slot] = ""
		_append_inventory_artifact(swapped_out_id, equipped, inventory)

	equipped[slot] = artifact_id
	artifacts["equipped"] = equipped
	artifacts["inventory"] = inventory
	hero["artifacts"] = normalize_hero_artifacts(artifacts)

	var suffix_message := "%s and equipped it in the %s slot." % [artifact_name(artifact_id), slot]
	var message := "Equipped %s." % artifact_name(artifact_id)
	if swapped_out_id != "":
		message = "Swapped %s into the %s slot and stowed %s." % [
			artifact_name(artifact_id),
			slot,
			artifact_name(swapped_out_id),
		]
		suffix_message = "%s and swapped it into the %s slot, stowing %s." % [
			artifact_name(artifact_id),
			slot,
			artifact_name(swapped_out_id),
		]

	return {
		"ok": true,
		"hero": hero,
		"slot": slot,
		"swapped_out_artifact_id": swapped_out_id,
		"message": message,
		"suffix_message": suffix_message,
	}

static func unequip_artifact(hero_state: Dictionary, slot: String) -> Dictionary:
	var hero = ensure_hero_artifacts(hero_state.duplicate(true))
	if slot not in EQUIPMENT_SLOTS:
		return {"ok": false, "hero": hero, "message": "That equipment slot does not exist."}

	var artifacts = hero.get("artifacts", {})
	var equipped = artifacts.get("equipped", {})
	var artifact_id := String(equipped.get(slot, ""))
	if artifact_id == "":
		return {"ok": false, "hero": hero, "message": "No artifact is equipped there."}

	var inventory = artifacts.get("inventory", [])
	equipped[slot] = ""
	_append_inventory_artifact(artifact_id, equipped, inventory)
	artifacts["equipped"] = equipped
	artifacts["inventory"] = inventory
	hero["artifacts"] = normalize_hero_artifacts(artifacts)

	return {
		"ok": true,
		"hero": hero,
		"slot": slot,
		"message": "Stored %s in the pack." % artifact_name(artifact_id),
	}

static func describe_loadout(hero_state: Dictionary) -> String:
	hero_state = ensure_hero_artifacts(hero_state.duplicate(true))
	var equipped = hero_state.get("artifacts", {}).get("equipped", {})
	var parts := []
	for slot in EQUIPMENT_SLOTS:
		var artifact_id := String(equipped.get(slot, ""))
		parts.append(
			"%s %s" % [
				slot.capitalize(),
				artifact_name(artifact_id) if artifact_id != "" else "empty",
			]
		)

	var inventory = hero_state.get("artifacts", {}).get("inventory", [])
	var inventory_count: int = inventory.size() if inventory is Array else 0
	return "Artifacts: %s | Pack %d" % [", ".join(parts), inventory_count]

static func describe_management(hero_state: Dictionary) -> String:
	hero_state = ensure_hero_artifacts(hero_state.duplicate(true))
	var equipped = hero_state.get("artifacts", {}).get("equipped", {})
	var inventory = hero_state.get("artifacts", {}).get("inventory", [])
	var lines := []

	lines.append("Equipped")
	for slot in EQUIPMENT_SLOTS:
		var artifact_id := String(equipped.get(slot, ""))
		if artifact_id == "":
			lines.append("- %s: empty" % slot.capitalize())
			continue
		lines.append(
			"- %s: %s | %s" % [
				slot.capitalize(),
				artifact_name(artifact_id),
				_artifact_effect_summary(ContentService.get_artifact(artifact_id)),
			]
		)

	lines.append("Pack")
	if inventory is Array and not inventory.is_empty():
		for artifact_id_value in inventory:
			var artifact_id := String(artifact_id_value)
			if artifact_id == "":
				continue
			lines.append(
				"- %s | %s slot | %s" % [
					artifact_name(artifact_id),
					artifact_slot(artifact_id).capitalize(),
					_artifact_effect_summary(ContentService.get_artifact(artifact_id)),
				]
			)
	else:
		lines.append("- Empty")

	lines.append(describe_bonus_summary(hero_state))
	return "\n".join(lines)

static func describe_bonus_summary(hero_state: Dictionary) -> String:
	var totals := aggregate_bonuses(hero_state)
	var parts := []
	if int(totals.get("overworld_movement", 0)) > 0:
		parts.append("+%d move" % int(totals.get("overworld_movement", 0)))
	if int(totals.get("scouting_radius", 0)) > 0:
		parts.append("+%d scout" % int(totals.get("scouting_radius", 0)))
	if int(totals.get("battle_attack", 0)) > 0:
		parts.append("+%d attack" % int(totals.get("battle_attack", 0)))
	if int(totals.get("battle_defense", 0)) > 0:
		parts.append("+%d defense" % int(totals.get("battle_defense", 0)))
	if int(totals.get("battle_initiative", 0)) > 0:
		parts.append("+%d initiative" % int(totals.get("battle_initiative", 0)))

	var income = totals.get("daily_income", {})
	var income_parts := []
	if income is Dictionary:
		for key in ["gold", "wood", "ore"]:
			var amount := int(income.get(key, 0))
			if amount > 0:
				income_parts.append("%d %s" % [amount, key])
	if not income_parts.is_empty():
		parts.append("+%s/day" % ", ".join(income_parts))

	return "Bonuses: %s" % (", ".join(parts) if not parts.is_empty() else "none")

static func get_management_actions(hero_state: Dictionary) -> Array:
	hero_state = ensure_hero_artifacts(hero_state.duplicate(true))
	var actions := []
	var artifacts = hero_state.get("artifacts", {})
	var inventory = artifacts.get("inventory", [])
	var equipped = artifacts.get("equipped", {})

	if inventory is Array:
		for artifact_id_value in inventory:
			var artifact_id := String(artifact_id_value)
			if artifact_id == "":
				continue
			var artifact := ContentService.get_artifact(artifact_id)
			if artifact.is_empty():
				continue
			var slot := artifact_slot(artifact_id)
			var equipped_id := String(equipped.get(slot, ""))
			var label_prefix := "Equip"
			var summary := "%s slot | %s" % [slot.capitalize(), _artifact_effect_summary(artifact)]
			if equipped_id != "":
				label_prefix = "Swap In"
				summary = "%s slot | Stows %s | %s" % [
					slot.capitalize(),
					artifact_name(equipped_id),
					_artifact_effect_summary(artifact),
				]
			actions.append(
				{
					"id": "equip_artifact:%s" % artifact_id,
					"label": "%s %s" % [label_prefix, artifact_name(artifact_id)],
					"summary": summary,
				}
			)

	if equipped is Dictionary:
		for slot in EQUIPMENT_SLOTS:
			var equipped_id := String(equipped.get(slot, ""))
			if equipped_id == "":
				continue
			var equipped_artifact := ContentService.get_artifact(equipped_id)
			actions.append(
				{
					"id": "unequip_artifact:%s" % slot,
					"label": "Stow %s" % artifact_name(equipped_id),
					"summary": "%s slot | Move to pack | %s" % [
						slot.capitalize(),
						_artifact_effect_summary(equipped_artifact),
					],
				}
			)
	return actions

static func artifact_name(artifact_id: String) -> String:
	if artifact_id == "":
		return "Artifact"
	var artifact := ContentService.get_artifact(artifact_id)
	return String(artifact.get("name", artifact_id))

static func artifact_slot(artifact_id: String) -> String:
	if artifact_id == "":
		return ""
	var artifact := ContentService.get_artifact(artifact_id)
	var slot := String(artifact.get("slot", ""))
	return slot if slot in EQUIPMENT_SLOTS else ""

static func describe_artifact(artifact_id: String) -> String:
	var artifact := ContentService.get_artifact(artifact_id)
	if artifact.is_empty():
		return "Artifact cache"
	return "%s | %s | %s" % [
		artifact_name(artifact_id),
		String(artifact.get("description", "Recovered equipment")),
		_artifact_effect_summary(artifact),
	]

static func _blank_equipped_slots() -> Dictionary:
	var equipped := {}
	for slot in EQUIPMENT_SLOTS:
		equipped[slot] = ""
	return equipped

static func _register_equipped_candidate(artifact_id: String, equipped: Dictionary, inventory: Array) -> void:
	if artifact_id == "" or not _artifact_exists(artifact_id) or _artifact_is_owned(equipped, inventory, artifact_id):
		return
	var slot := artifact_slot(artifact_id)
	if slot == "":
		return
	if String(equipped.get(slot, "")) == "":
		equipped[slot] = artifact_id
	else:
		inventory.append(artifact_id)

static func _append_inventory_artifact(artifact_id: String, equipped: Dictionary, inventory: Array) -> void:
	if artifact_id == "" or not _artifact_exists(artifact_id) or _artifact_is_owned(equipped, inventory, artifact_id):
		return
	inventory.append(artifact_id)

static func _artifact_exists(artifact_id: String) -> bool:
	return artifact_id != "" and not ContentService.get_artifact(artifact_id).is_empty()

static func _artifact_is_owned(equipped: Dictionary, inventory: Array, artifact_id: String) -> bool:
	if artifact_id == "":
		return false
	for slot in EQUIPMENT_SLOTS:
		if String(equipped.get(slot, "")) == artifact_id:
			return true
	for inventory_id_value in inventory:
		if String(inventory_id_value) == artifact_id:
			return true
	return false

static func _remove_artifact_from_inventory(inventory: Array, artifact_id: String) -> bool:
	for index in range(inventory.size()):
		if String(inventory[index]) == artifact_id:
			inventory.remove_at(index)
			return true
	return false

static func _already_owned_message(artifact_id: String, location: Dictionary, source_verb: String) -> String:
	var location_name := String(location.get("location", "missing"))
	if location_name == "equipped":
		return "%s %s, but it is already equipped in the %s slot." % [
			source_verb,
			artifact_name(artifact_id),
			String(location.get("slot", "equipment")),
		]
	if location_name == "inventory":
		return "%s %s, but it is already in the pack." % [source_verb, artifact_name(artifact_id)]
	return "%s %s." % [source_verb, artifact_name(artifact_id)]

static func _artifact_effect_summary(artifact: Dictionary) -> String:
	if artifact.is_empty():
		return "No bonuses"
	var bonuses = artifact.get("bonuses", {})
	var parts := []
	if int(bonuses.get("overworld_movement", 0)) > 0:
		parts.append("+%d move" % int(bonuses.get("overworld_movement", 0)))
	if int(bonuses.get("scouting_radius", 0)) > 0:
		parts.append("+%d scout" % int(bonuses.get("scouting_radius", 0)))
	if int(bonuses.get("battle_attack", 0)) > 0:
		parts.append("+%d attack" % int(bonuses.get("battle_attack", 0)))
	if int(bonuses.get("battle_defense", 0)) > 0:
		parts.append("+%d defense" % int(bonuses.get("battle_defense", 0)))
	if int(bonuses.get("battle_initiative", 0)) > 0:
		parts.append("+%d initiative" % int(bonuses.get("battle_initiative", 0)))

	var income = bonuses.get("daily_income", {})
	var income_parts := []
	if income is Dictionary:
		for key in ["gold", "wood", "ore"]:
			var amount := int(income.get(key, 0))
			if amount > 0:
				income_parts.append("+%d %s/day" % [amount, key])
	if not income_parts.is_empty():
		parts.append(", ".join(income_parts))

	return ", ".join(parts) if not parts.is_empty() else "No bonuses"

static func _merge_resources(base: Variant, delta: Variant) -> Dictionary:
	var merged := {"gold": 0, "wood": 0, "ore": 0}
	if base is Dictionary:
		for key in merged.keys():
			merged[key] = int(base.get(key, 0))
	if delta is Dictionary:
		for key in delta.keys():
			merged[String(key)] = int(merged.get(String(key), 0)) + int(delta[key])
	return merged
