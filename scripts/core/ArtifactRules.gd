class_name ArtifactRules
extends RefCounted

const EQUIPMENT_SLOTS := ["boots", "banner", "armor", "trinket"]
const ARTIFACT_SCHEMA_ID := "artifact_taxonomy_v1"
const ARTIFACT_CLASSES := ["common", "crafted", "faction", "accord", "relic", "cursed", "set_piece", "old_measure", "scenario"]
const ARTIFACT_RARITIES := ["common", "uncommon", "rare", "epic", "legendary", "scenario"]
const ARTIFACT_ROLES := [
	"economy",
	"movement",
	"scouting",
	"combat",
	"defense",
	"morale",
	"magic",
	"resistance",
	"recruitment",
	"town_support",
	"route",
	"reward_modifier",
	"progression",
	"objective",
]
const ARTIFACT_ACCORD_AFFINITIES := ["beacon", "mire", "lens", "root", "furnace", "veil", "old_measure", "neutral", "none"]
const ARTIFACT_SOURCE_TAGS := [
	"pickup",
	"guarded_site",
	"shrine",
	"dwelling",
	"artifact_cache",
	"town",
	"battle_salvage",
	"campaign",
	"set_chain",
	"market",
	"objective",
]
const ARTIFACT_BONUS_TYPES := ["stat", "resource_income", "spell_modifier", "site_modifier", "town_modifier", "unit_tag_modifier", "adventure_effect", "tradeoff"]
const SLOT_LIMITS := {"boots": 1, "banner": 1, "armor": 1, "trinket": 2}

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
		"spell_modifiers": [],
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
		totals["spell_modifiers"].append_array(_artifact_spell_modifier_records(artifact, artifact_id))

	return totals

static func spell_affinity_records(hero_state: Dictionary, spell: Dictionary = {}) -> Array:
	var records := []
	var modifiers = aggregate_bonuses(hero_state).get("spell_modifiers", [])
	if not (modifiers is Array):
		return records
	for modifier_value in modifiers:
		if not (modifier_value is Dictionary):
			continue
		var modifier: Dictionary = modifier_value
		if not spell.is_empty() and not _spell_modifier_matches(modifier, spell):
			continue
		records.append(modifier.duplicate(true))
	return records

static func spell_mana_cost_delta(hero_state: Dictionary, spell: Dictionary) -> int:
	var delta := 0
	for modifier in spell_affinity_records(hero_state, spell):
		delta += int(modifier.get("mana_cost_delta", 0))
	return delta

static func spell_effect_amount_delta(hero_state: Dictionary, spell: Dictionary) -> int:
	var delta := 0
	for modifier in spell_affinity_records(hero_state, spell):
		delta += int(modifier.get("effect_amount_delta", 0))
	return delta

static func artifact_taxonomy(artifact_id: String) -> Dictionary:
	var artifact := ContentService.get_artifact(artifact_id)
	if artifact.is_empty():
		return {}
	return _artifact_taxonomy_payload(artifact)

static func artifact_taxonomy_summary(artifact_id: String) -> String:
	var taxonomy := artifact_taxonomy(artifact_id)
	if taxonomy.is_empty():
		return "Taxonomy unknown"
	var rarity := _title_label(String(taxonomy.get("rarity", "")))
	var family := _title_label(String(taxonomy.get("family", "")))
	var roles = taxonomy.get("roles", [])
	var role_labels := []
	if roles is Array:
		for role_value in roles:
			var role := String(role_value).strip_edges()
			if role == "":
				continue
			role_labels.append(_title_label(role))
	return "%s %s | %s" % [
		rarity,
		family,
		", ".join(role_labels) if not role_labels.is_empty() else "Role pending",
	]

static func artifact_schema_report(artifact_records: Array = []) -> Dictionary:
	var records := artifact_records
	if records.is_empty():
		var raw := ContentService.load_json(ContentService.ARTIFACTS_PATH)
		var raw_items = raw.get("items", [])
		if raw_items is Array:
			records = raw_items

	var report := {
		"ok": true,
		"schema_status": "artifact_taxonomy_schema_loaded",
		"schema_id": ARTIFACT_SCHEMA_ID,
		"artifact_count": 0,
		"complete_taxonomy_count": 0,
		"equip_constraint_count": 0,
		"bonus_metadata_count": 0,
		"risk_metadata_count": 0,
		"ui_summary_count": 0,
		"ai_hint_count": 0,
		"slot_counts": {},
		"rarity_counts": {},
		"class_counts": {},
		"family_counts": {},
		"role_counts": {},
		"source_tag_counts": {},
		"curse_tradeoff_counts": {"cursed": 0, "tradeoff": 0},
		"unsupported_records": [],
		"content_scope": "existing_artifact_records_only",
		"runtime_policy": {
			"save_version_bump": false,
			"equipment_runtime_migration": false,
			"source_reward_tables_active": false,
			"rare_resource_activation": false,
		},
	}
	var slot_counts: Dictionary = report["slot_counts"]
	var rarity_counts: Dictionary = report["rarity_counts"]
	var class_counts: Dictionary = report["class_counts"]
	var family_counts: Dictionary = report["family_counts"]
	var role_counts: Dictionary = report["role_counts"]
	var source_tag_counts: Dictionary = report["source_tag_counts"]
	var curse_tradeoff_counts: Dictionary = report["curse_tradeoff_counts"]
	var unsupported_records: Array = report["unsupported_records"]

	for artifact_value in records:
		if not (artifact_value is Dictionary):
			continue
		var artifact: Dictionary = artifact_value
		var artifact_id := String(artifact.get("id", "")).strip_edges()
		if artifact_id == "":
			continue
		report["artifact_count"] = int(report.get("artifact_count", 0)) + 1
		_increment_count(slot_counts, String(artifact.get("slot", "")))
		_increment_count(rarity_counts, String(artifact.get("rarity", "")))
		_increment_count(class_counts, String(artifact.get("artifact_class", "")))
		_increment_count(family_counts, String(artifact.get("family", "")))
		for role in _string_array(artifact.get("roles", [])):
			_increment_count(role_counts, role)
		for source_tag in _string_array(artifact.get("source_tags", [])):
			_increment_count(source_tag_counts, source_tag)

		var errors := _artifact_taxonomy_validation_errors(artifact)
		if errors.is_empty():
			report["complete_taxonomy_count"] = int(report.get("complete_taxonomy_count", 0)) + 1
		else:
			unsupported_records.append({"artifact_id": artifact_id, "issues": errors})

		if _equip_constraints_complete(artifact):
			report["equip_constraint_count"] = int(report.get("equip_constraint_count", 0)) + 1
		if _bonus_metadata_complete(artifact):
			report["bonus_metadata_count"] = int(report.get("bonus_metadata_count", 0)) + 1
		if _risk_metadata_complete(artifact):
			report["risk_metadata_count"] = int(report.get("risk_metadata_count", 0)) + 1
		if _artifact_ui_summary(artifact) != "":
			report["ui_summary_count"] = int(report.get("ui_summary_count", 0)) + 1
		if _ai_hints_complete(artifact):
			report["ai_hint_count"] = int(report.get("ai_hint_count", 0)) + 1

		var risk = artifact.get("risk", {})
		if risk is Dictionary:
			if bool(risk.get("cursed", false)):
				curse_tradeoff_counts["cursed"] = int(curse_tradeoff_counts.get("cursed", 0)) + 1
			if bool(risk.get("tradeoff", false)):
				curse_tradeoff_counts["tradeoff"] = int(curse_tradeoff_counts.get("tradeoff", 0)) + 1

	report["ok"] = int(report.get("artifact_count", 0)) > 0 and int(report.get("complete_taxonomy_count", 0)) == int(report.get("artifact_count", 0))
	return report

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
		message = "%s %s" % [
			source_verb,
			String(equip_result.get("suffix_message", artifact_name(artifact_id) + "."))
		]
		return {
			"ok": true,
			"hero": hero,
			"message": message,
			"duplicate": false,
			"auto_equipped": true,
			"artifact_id": artifact_id,
			"slot": slot,
			"effect_summary": artifact_effect_summary(artifact_id),
			"reward_role": artifact_reward_role(artifact_id),
		}

	message = "%s %s. %s" % [source_verb, artifact_name(artifact_id), _artifact_collection_note(hero, artifact_id)]
	return {
		"ok": true,
		"hero": hero,
		"message": message,
		"duplicate": false,
		"auto_equipped": false,
		"artifact_id": artifact_id,
		"slot": slot,
		"effect_summary": artifact_effect_summary(artifact_id),
		"reward_role": artifact_reward_role(artifact_id),
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

	var suffix_message := "%s. %s" % [artifact_name(artifact_id), _artifact_equipped_note(artifact_id, slot)]
	var message := "Equipped %s from pack into %s. %s" % [
		artifact_name(artifact_id),
		artifact_slot_label(artifact_id),
		_artifact_effect_line(artifact_id),
	]
	if swapped_out_id != "":
		message = "Swapped %s into %s and stowed %s in pack." % [
			artifact_name(artifact_id),
			artifact_slot_label(artifact_id),
			artifact_name(swapped_out_id),
		]
		message += " New: %s Was: %s." % [
			artifact_effect_summary(artifact_id),
			artifact_effect_summary(swapped_out_id),
		]
		suffix_message = "%s. Swapped into %s; stowed %s. New: %s Was: %s." % [
			artifact_name(artifact_id),
			artifact_slot_label(artifact_id),
			artifact_name(swapped_out_id),
			artifact_effect_summary(artifact_id),
			artifact_effect_summary(swapped_out_id),
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
		"message": "Stowed %s from %s into pack. Removed: %s." % [
			artifact_name(artifact_id),
			artifact_slot_label(artifact_id),
			artifact_effect_summary(artifact_id),
		],
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
	return "Artifacts: %s | Pack %d\n%s\n%s" % [
		", ".join(parts),
		inventory_count,
		describe_impact_summary(hero_state),
		describe_collection_summary(hero_state),
	]

static func describe_management(hero_state: Dictionary) -> String:
	hero_state = ensure_hero_artifacts(hero_state.duplicate(true))
	var equipped = hero_state.get("artifacts", {}).get("equipped", {})
	var inventory = hero_state.get("artifacts", {}).get("inventory", [])
	var lines := []

	lines.append("Equipped")
	for slot in EQUIPMENT_SLOTS:
		var artifact_id := String(equipped.get(slot, ""))
		if artifact_id == "":
			lines.append("- %s: empty | Ready for %s" % [slot.capitalize(), slot.capitalize()])
			continue
		lines.append(
			"- %s: %s | Equipped | %s | %s | %s" % [
				slot.capitalize(),
				artifact_name(artifact_id),
				artifact_taxonomy_summary(artifact_id),
				artifact_effect_summary(artifact_id),
				describe_single_artifact_impact(artifact_id),
			]
		)

	lines.append("Pack")
	if inventory is Array and not inventory.is_empty():
		for artifact_id_value in inventory:
			var artifact_id := String(artifact_id_value)
			if artifact_id == "":
				continue
			lines.append(
				"- %s | Pack | %s slot | %s | %s | %s | %s | %s" % [
					artifact_name(artifact_id),
					artifact_slot_label(artifact_id),
					artifact_taxonomy_summary(artifact_id),
					artifact_decision_summary(hero_state, artifact_id),
					artifact_set_context(artifact_id),
					artifact_effect_summary(artifact_id),
					describe_single_artifact_impact(artifact_id),
				]
			)
	else:
		lines.append("- Empty")

	lines.append(describe_bonus_summary(hero_state))
	lines.append(describe_impact_summary(hero_state))
	lines.append(describe_collection_summary(hero_state))
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

static func describe_impact_summary(hero_state: Dictionary) -> String:
	var sections := _bonus_impact_sections(aggregate_bonuses(hero_state), false)
	var impact := "no equipped bonuses" if sections.is_empty() else " | ".join(sections)
	return "Gear impact: %s" % impact

static func describe_battle_impact_summary(hero_state: Dictionary) -> String:
	var totals := aggregate_bonuses(hero_state)
	var parts := []
	if int(totals.get("battle_attack", 0)) > 0:
		parts.append("Attack +%d" % int(totals.get("battle_attack", 0)))
	if int(totals.get("battle_defense", 0)) > 0:
		parts.append("Defense +%d" % int(totals.get("battle_defense", 0)))
	if int(totals.get("battle_initiative", 0)) > 0:
		parts.append("Initiative +%d" % int(totals.get("battle_initiative", 0)))
	return "Command %s" % (", ".join(parts) if not parts.is_empty() else "no equipped battle bonuses")

static func describe_collection_summary(hero_state: Dictionary) -> String:
	var owned_count := owned_artifact_ids(hero_state).size()
	var total_count := ContentService.get_content_ids(ContentService.ARTIFACTS_PATH).size()
	if total_count <= 0:
		return "Collection: %d owned" % owned_count
	return "Collection: %d/%d known relics owned" % [owned_count, total_count]

static func describe_single_artifact_impact(artifact_id: String) -> String:
	var artifact := ContentService.get_artifact(artifact_id)
	var sections := _bonus_impact_sections(_artifact_bonus_totals(artifact), true)
	return "Impact %s" % ("no direct stat change" if sections.is_empty() else " | ".join(sections))

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
			var summary := "%s | %s | %s | %s | %s" % [
				artifact_decision_summary(hero_state, artifact_id),
				artifact_reward_role(artifact_id),
				artifact_set_context(artifact_id),
				describe_single_artifact_impact(artifact_id),
				artifact_effect_summary(artifact_id),
			]
			if equipped_id != "":
				label_prefix = "Swap In"
				summary = "%s | %s | %s | %s | %s" % [
					artifact_decision_summary(hero_state, artifact_id),
					artifact_reward_role(artifact_id),
					artifact_set_context(artifact_id),
					describe_single_artifact_impact(artifact_id),
					artifact_effect_summary(artifact_id),
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
					"summary": "%s slot | Move to pack | Removes %s | %s" % [
						artifact_slot_label(equipped_id),
						describe_single_artifact_impact(equipped_id),
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

static func artifact_slot_label(artifact_id: String) -> String:
	var slot := artifact_slot(artifact_id)
	return slot.capitalize() if slot != "" else "Carry"

static func artifact_type_label(artifact_id: String) -> String:
	match artifact_slot(artifact_id):
		"boots":
			return "Footgear"
		"banner":
			return "Command banner"
		"armor":
			return "Armor"
		"trinket":
			return "Trinket"
		_:
			return "Carry item"

static func artifact_set_context(artifact_id: String) -> String:
	var artifact := ContentService.get_artifact(artifact_id)
	if artifact.is_empty():
		return "Set unknown"
	var set_id := _artifact_set_id(artifact)
	if set_id == "":
		return "Standalone relic"
	return "Set %s" % _title_label(set_id)

static func artifact_effect_summary(artifact_id: String) -> String:
	return _artifact_effect_summary(ContentService.get_artifact(artifact_id))

static func artifact_reward_role(artifact_id: String) -> String:
	var artifact := ContentService.get_artifact(artifact_id)
	if artifact.is_empty():
		return "Equipment reward"
	var bonuses = artifact.get("bonuses", {})
	var income = bonuses.get("daily_income", {})
	if income is Dictionary:
		var income_dict: Dictionary = income
		for amount_value in income_dict.values():
			if int(amount_value) > 0:
				return "Economy reward"
	var movement := int(bonuses.get("overworld_movement", 0))
	var scouting := int(bonuses.get("scouting_radius", 0))
	if movement > 0 and scouting > 0:
		return "Exploration reward"
	if movement > 0:
		return "Movement reward"
	if scouting > 0:
		return "Scouting reward"
	if int(bonuses.get("battle_defense", 0)) > 0 and int(bonuses.get("battle_attack", 0)) <= 0:
		return "Defense reward"
	if int(bonuses.get("battle_attack", 0)) > 0 or int(bonuses.get("battle_initiative", 0)) > 0:
		return "Command reward"
	return "Equipment reward"

static func artifact_decision_summary(hero_state: Dictionary, artifact_id: String) -> String:
	var artifact := ContentService.get_artifact(artifact_id)
	if artifact.is_empty():
		return "Cannot equip"
	var slot := artifact_slot(artifact_id)
	if slot == "":
		return "Pack only"
	var location := locate_artifact(hero_state, artifact_id)
	var artifacts = normalize_hero_artifacts(hero_state.get("artifacts", {}))
	var equipped_id := String(artifacts.get("equipped", {}).get(slot, ""))
	match String(location.get("location", "missing")):
		"equipped":
			return "Equipped in %s; can stow to pack" % artifact_slot_label(artifact_id)
		"inventory":
			if equipped_id == "":
				return "Can equip to empty %s" % artifact_slot_label(artifact_id)
			return "Can swap with %s" % artifact_name(equipped_id)
		_:
			if equipped_id == "":
				return "Will auto-equip to empty %s" % artifact_slot_label(artifact_id)
			return "Will enter pack; can swap with %s" % artifact_name(equipped_id)

static func describe_artifact_short(artifact_id: String) -> String:
	if ContentService.get_artifact(artifact_id).is_empty():
		return "Artifact cache"
	return "%s | %s | %s | %s | %s" % [
		artifact_name(artifact_id),
		artifact_slot_label(artifact_id),
		artifact_taxonomy_summary(artifact_id),
		artifact_reward_role(artifact_id),
		artifact_effect_summary(artifact_id),
	]

static func describe_artifact_inspection(
	hero_state: Dictionary,
	artifact_id: String,
	collected: bool = false,
	collected_by_faction_id: String = ""
) -> String:
	var artifact := ContentService.get_artifact(artifact_id)
	if artifact.is_empty():
		return "Artifact cache\nUnknown relic record."
	var state := artifact_collection_state(hero_state, artifact_id, collected, collected_by_faction_id)
	return "%s\nSlot %s | %s | %s | %s\nTaxonomy: %s\nEffect: %s\n%s\nState: %s" % [
		artifact_name(artifact_id),
		artifact_slot_label(artifact_id),
		artifact_type_label(artifact_id),
		artifact_reward_role(artifact_id),
		artifact_set_context(artifact_id),
		artifact_taxonomy_summary(artifact_id),
		artifact_effect_summary(artifact_id),
		describe_single_artifact_impact(artifact_id),
		state,
	]

static func artifact_collection_state(
	hero_state: Dictionary,
	artifact_id: String,
	collected: bool = false,
	collected_by_faction_id: String = ""
) -> String:
	if collected:
		if collected_by_faction_id == "player":
			var owned_location := locate_artifact(hero_state, artifact_id)
			return _owned_location_label(artifact_id, owned_location)
		if collected_by_faction_id != "":
			return "Already claimed by %s" % collected_by_faction_id.capitalize()
		return "Already claimed"
	var location := locate_artifact(hero_state, artifact_id)
	if String(location.get("location", "missing")) != "missing":
		return _owned_location_label(artifact_id, location)
	var slot := artifact_slot(artifact_id)
	var artifacts = normalize_hero_artifacts(hero_state.get("artifacts", {}))
	var equipped_id := String(artifacts.get("equipped", {}).get(slot, ""))
	if slot != "" and equipped_id == "":
		return "Will auto-equip to empty %s slot" % artifact_slot_label(artifact_id)
	if slot != "" and equipped_id != "":
		return "Will enter pack; %s holds %s" % [artifact_slot_label(artifact_id), artifact_name(equipped_id)]
	return "Will enter pack"

static func describe_artifact(artifact_id: String) -> String:
	var artifact := ContentService.get_artifact(artifact_id)
	if artifact.is_empty():
		return "Artifact cache"
	return "%s | %s | %s | %s" % [
		artifact_name(artifact_id),
		artifact_taxonomy_summary(artifact_id),
		String(artifact.get("description", "Recovered equipment")),
		_artifact_effect_summary(artifact),
	]

static func _owned_location_label(artifact_id: String, location: Dictionary) -> String:
	match String(location.get("location", "missing")):
		"equipped":
			return "Equipped in %s slot" % artifact_slot_label(artifact_id)
		"inventory":
			return "Stored in pack"
		_:
			return "Not owned"

static func _artifact_effect_line(artifact_id: String) -> String:
	return "%s | %s." % [artifact_reward_role(artifact_id), artifact_effect_summary(artifact_id)]

static func _artifact_equipped_note(artifact_id: String, slot: String) -> String:
	return "Equipped in %s slot. %s" % [slot.capitalize(), _artifact_effect_line(artifact_id)]

static func _artifact_collection_note(hero_state: Dictionary, artifact_id: String) -> String:
	return "%s | %s | %s." % [
		artifact_slot_label(artifact_id),
		artifact_reward_role(artifact_id),
		artifact_effect_summary(artifact_id),
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
	var spell_parts := _artifact_spell_modifier_parts(_artifact_spell_modifier_records(artifact, String(artifact.get("id", ""))))
	if not spell_parts.is_empty():
		parts.append(", ".join(spell_parts))

	return ", ".join(parts) if not parts.is_empty() else "No bonuses"

static func _artifact_bonus_totals(artifact: Dictionary) -> Dictionary:
	var bonuses = artifact.get("bonuses", {}) if artifact is Dictionary else {}
	var totals := {
		"overworld_movement": 0,
		"scouting_radius": 0,
		"battle_attack": 0,
		"battle_defense": 0,
		"battle_initiative": 0,
		"daily_income": {"gold": 0, "wood": 0, "ore": 0},
		"spell_modifiers": [],
	}
	if not (bonuses is Dictionary):
		return totals
	totals["overworld_movement"] = int(bonuses.get("overworld_movement", 0))
	totals["scouting_radius"] = int(bonuses.get("scouting_radius", 0))
	totals["battle_attack"] = int(bonuses.get("battle_attack", 0))
	totals["battle_defense"] = int(bonuses.get("battle_defense", 0))
	totals["battle_initiative"] = int(bonuses.get("battle_initiative", 0))
	totals["daily_income"] = _merge_resources({}, bonuses.get("daily_income", {}))
	totals["spell_modifiers"] = _artifact_spell_modifier_records(artifact, String(artifact.get("id", "")))
	return totals

static func _bonus_impact_sections(totals: Dictionary, include_empty_sections: bool) -> Array:
	var sections := []
	var field_parts := []
	if int(totals.get("overworld_movement", 0)) > 0:
		field_parts.append("Move +%d" % int(totals.get("overworld_movement", 0)))
	if int(totals.get("scouting_radius", 0)) > 0:
		field_parts.append("Scout +%d" % int(totals.get("scouting_radius", 0)))
	if not field_parts.is_empty():
		sections.append("Field %s" % ", ".join(field_parts))
	elif include_empty_sections:
		sections.append("Field no change")

	var command_parts := []
	if int(totals.get("battle_attack", 0)) > 0:
		command_parts.append("Attack +%d" % int(totals.get("battle_attack", 0)))
	if int(totals.get("battle_defense", 0)) > 0:
		command_parts.append("Defense +%d" % int(totals.get("battle_defense", 0)))
	if int(totals.get("battle_initiative", 0)) > 0:
		command_parts.append("Initiative +%d" % int(totals.get("battle_initiative", 0)))
	if not command_parts.is_empty():
		sections.append("Command %s" % ", ".join(command_parts))
	elif include_empty_sections:
		sections.append("Command no change")

	var economy_parts := _resource_impact_parts(totals.get("daily_income", {}))
	if not economy_parts.is_empty():
		sections.append("Economy %s" % ", ".join(economy_parts))
	elif include_empty_sections:
		sections.append("Economy no income")

	var spell_parts := _artifact_spell_modifier_parts(totals.get("spell_modifiers", []))
	if not spell_parts.is_empty():
		sections.append("Magic %s" % ", ".join(spell_parts))
	elif include_empty_sections:
		sections.append("Magic no spell hook")
	return sections

static func _resource_impact_parts(value: Variant) -> Array:
	var parts := []
	if not (value is Dictionary):
		return parts
	for key in ["gold", "wood", "ore"]:
		var amount := int(value.get(key, 0))
		if amount > 0:
			parts.append("%d %s/day" % [amount, key])
	return parts

static func _artifact_set_id(artifact: Dictionary) -> String:
	for key in ["set_id", "artifact_set_id", "set"]:
		var value = artifact.get(key, "")
		if value is Dictionary:
			var nested_id := String(value.get("id", "")).strip_edges()
			if nested_id != "":
				return nested_id
		var label := String(value).strip_edges()
		if label != "":
			return label
	return ""

static func _artifact_spell_modifier_records(artifact: Dictionary, artifact_id: String) -> Array:
	var records := []
	if artifact.is_empty():
		return records
	var bonuses = artifact.get("bonuses", {})
	if not (bonuses is Dictionary):
		return records
	var modifiers = bonuses.get("spell_modifiers", [])
	if not (modifiers is Array):
		return records
	for modifier_value in modifiers:
		if not (modifier_value is Dictionary):
			continue
		var modifier: Dictionary = modifier_value
		var record := {
			"artifact_id": artifact_id,
			"artifact_name": String(artifact.get("name", artifact_id)),
			"school_id": String(modifier.get("school_id", "")),
			"context": String(modifier.get("context", "")),
			"effect_type": String(modifier.get("effect_type", "")),
			"mana_cost_delta": int(modifier.get("mana_cost_delta", 0)),
			"effect_amount_delta": int(modifier.get("effect_amount_delta", 0)),
			"public_summary": String(modifier.get("public_summary", "")),
		}
		records.append(record)
	return records

static func _spell_modifier_matches(modifier: Dictionary, spell: Dictionary) -> bool:
	if spell.is_empty():
		return true
	var effect = spell.get("effect", {})
	var effect_type := String(effect.get("type", "")) if effect is Dictionary else ""
	for key in ["school_id", "context", "effect_type", "primary_role"]:
		var required := String(modifier.get(key, "")).strip_edges()
		if required == "":
			continue
		var actual := ""
		match key:
			"school_id":
				actual = String(spell.get("school_id", ""))
			"context":
				actual = String(spell.get("context", ""))
			"effect_type":
				actual = effect_type
			"primary_role":
				actual = String(spell.get("primary_role", ""))
		if actual != required:
			return false
	return true

static func _artifact_spell_modifier_parts(value: Variant) -> Array:
	var parts := []
	if not (value is Array):
		return parts
	for modifier_value in value:
		if not (modifier_value is Dictionary):
			continue
		var modifier: Dictionary = modifier_value
		var school := _title_label(String(modifier.get("school_id", "spell")))
		var context := String(modifier.get("context", "spell")).replace("_", " ")
		var modifier_parts := []
		var mana_delta := int(modifier.get("mana_cost_delta", 0))
		var effect_delta := int(modifier.get("effect_amount_delta", 0))
		if mana_delta != 0:
			modifier_parts.append("%s mana" % _signed_amount_label(mana_delta))
		if effect_delta != 0:
			modifier_parts.append("%s effect" % _signed_amount_label(effect_delta))
		if modifier_parts.is_empty():
			continue
		parts.append("%s %s %s" % [school, context, ", ".join(modifier_parts)])
	return parts

static func _artifact_taxonomy_payload(artifact: Dictionary) -> Dictionary:
	return {
		"artifact_id": String(artifact.get("id", "")),
		"artifact_class": String(artifact.get("artifact_class", "")),
		"rarity": String(artifact.get("rarity", "")),
		"slot": String(artifact.get("slot", "")),
		"family": String(artifact.get("family", "")),
		"roles": _string_array(artifact.get("roles", [])),
		"accord_affinity": String(artifact.get("accord_affinity", "")),
		"faction_affinity": _string_array(artifact.get("faction_affinity", [])),
		"source_tags": _string_array(artifact.get("source_tags", [])),
		"set_id": _artifact_set_id(artifact),
		"cursed": bool((artifact.get("risk", {}) if artifact.get("risk", {}) is Dictionary else {}).get("cursed", false)),
		"tradeoff": bool((artifact.get("risk", {}) if artifact.get("risk", {}) is Dictionary else {}).get("tradeoff", false)),
		"ui_summary": _artifact_ui_summary(artifact),
	}

static func _artifact_taxonomy_validation_errors(artifact: Dictionary) -> Array:
	var errors := []
	var artifact_id := String(artifact.get("id", "")).strip_edges()
	if artifact_id == "":
		errors.append("missing_id")
	var slot := String(artifact.get("slot", "")).strip_edges()
	if slot not in EQUIPMENT_SLOTS:
		errors.append("unsupported_slot")
	var artifact_class := String(artifact.get("artifact_class", "")).strip_edges()
	if artifact_class not in ARTIFACT_CLASSES:
		errors.append("unsupported_artifact_class")
	var rarity := String(artifact.get("rarity", "")).strip_edges()
	if rarity not in ARTIFACT_RARITIES:
		errors.append("unsupported_rarity")
	var family := String(artifact.get("family", "")).strip_edges()
	if family == "":
		errors.append("missing_family")
	var roles := _string_array(artifact.get("roles", []))
	if roles.is_empty():
		errors.append("missing_roles")
	for role in roles:
		if role not in ARTIFACT_ROLES:
			errors.append("unsupported_role:%s" % role)
	var accord_affinity := String(artifact.get("accord_affinity", "")).strip_edges()
	if accord_affinity not in ARTIFACT_ACCORD_AFFINITIES:
		errors.append("unsupported_accord_affinity")
	var source_tags := _string_array(artifact.get("source_tags", []))
	if source_tags.is_empty():
		errors.append("missing_source_tags")
	for source_tag in source_tags:
		if source_tag not in ARTIFACT_SOURCE_TAGS:
			errors.append("unsupported_source_tag:%s" % source_tag)
	if not _equip_constraints_complete(artifact):
		errors.append("incomplete_equip_constraints")
	if not _bonus_metadata_complete(artifact):
		errors.append("incomplete_bonus_metadata")
	if not _risk_metadata_complete(artifact):
		errors.append("incomplete_risk_metadata")
	if _artifact_ui_summary(artifact) == "":
		errors.append("missing_ui_summary")
	if not _ai_hints_complete(artifact):
		errors.append("incomplete_ai_hints")
	var validation_tags = artifact.get("validation_tags", {})
	if not (validation_tags is Dictionary):
		errors.append("missing_validation_tags")
	else:
		var schema := String(validation_tags.get("schema", "")).strip_edges()
		if schema != ARTIFACT_SCHEMA_ID:
			errors.append("unsupported_schema")
		if String(validation_tags.get("save_behavior", "")).strip_edges() == "":
			errors.append("missing_save_behavior")
	return errors

static func _equip_constraints_complete(artifact: Dictionary) -> bool:
	var constraints = artifact.get("equip_constraints", {})
	if not (constraints is Dictionary):
		return false
	var slot := String(artifact.get("slot", "")).strip_edges()
	if slot == "" or slot not in EQUIPMENT_SLOTS:
		return false
	var expected_limit := int(SLOT_LIMITS.get(slot, 1))
	if int(constraints.get("slot_limit", 0)) != expected_limit:
		return false
	if not constraints.has("unique_per_hero"):
		return false
	if not (constraints.get("allowed_faction_ids", []) is Array):
		return false
	if not (constraints.get("required_tags", []) is Array):
		return false
	return true

static func _bonus_metadata_complete(artifact: Dictionary) -> bool:
	var metadata = artifact.get("bonus_metadata", [])
	if not (metadata is Array) or metadata.is_empty():
		return false
	for entry_value in metadata:
		if not (entry_value is Dictionary):
			return false
		var entry: Dictionary = entry_value
		var bonus_type := String(entry.get("bonus_type", "")).strip_edges()
		if bonus_type not in ARTIFACT_BONUS_TYPES:
			return false
		if String(entry.get("scope", "")).strip_edges() == "":
			return false
		if String(entry.get("public_summary", "")).strip_edges() == "":
			return false
	return true

static func _risk_metadata_complete(artifact: Dictionary) -> bool:
	var risk = artifact.get("risk", {})
	if not (risk is Dictionary):
		return false
	if not risk.has("cursed") or not risk.has("tradeoff"):
		return false
	if not (risk.get("warning_tags", []) is Array):
		return false
	return true

static func _ai_hints_complete(artifact: Dictionary) -> bool:
	var hints = artifact.get("ai_hints", {})
	if not (hints is Dictionary):
		return false
	if _string_array(hints.get("value_drivers", [])).is_empty():
		return false
	if _string_array(hints.get("preferred_hero_roles", [])).is_empty():
		return false
	if not (hints.get("preferred_faction_ids", []) is Array):
		return false
	if not (hints.get("combo_tags", []) is Array):
		return false
	return true

static func _artifact_ui_summary(artifact: Dictionary) -> String:
	var ui = artifact.get("ui", {})
	if ui is Dictionary:
		return String(ui.get("summary", "")).strip_edges()
	return ""

static func _string_array(value: Variant) -> Array:
	var result := []
	if value is Array:
		for item in value:
			var text := String(item).strip_edges()
			if text != "" and text not in result:
				result.append(text)
	elif value is String:
		var text := String(value).strip_edges()
		if text != "":
			result.append(text)
	return result

static func _increment_count(counts: Dictionary, key_value: String) -> void:
	var key := key_value.strip_edges()
	if key == "":
		key = "none"
	counts[key] = int(counts.get(key, 0)) + 1

static func _signed_amount_label(amount: int) -> String:
	if amount > 0:
		return "+%d" % amount
	return "%d" % amount

static func _title_label(value: String) -> String:
	var words := []
	for part in value.replace("-", "_").split("_"):
		var word := String(part).strip_edges()
		if word == "":
			continue
		words.append(word.capitalize())
	return " ".join(words) if not words.is_empty() else value

static func _merge_resources(base: Variant, delta: Variant) -> Dictionary:
	var merged := {"gold": 0, "wood": 0, "ore": 0}
	if base is Dictionary:
		for key in merged.keys():
			merged[key] = int(base.get(key, 0))
	if delta is Dictionary:
		for key in delta.keys():
			merged[String(key)] = int(merged.get(String(key), 0)) + int(delta[key])
	return merged
