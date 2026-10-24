class_name ArtifactRules
extends RefCounted

const ARTIFACT_SLOTS := ["boots", "banner", "armor", "trinket"]
const EQUIPMENT_SLOTS := ["boots", "banner", "armor", "trinket", "trinket_2"]
const ARTIFACT_SCHEMA_ID := "artifact_taxonomy_v1"
const ARTIFACT_SOURCE_REWARD_SCHEMA_ID := "artifact_source_reward_v1"
const NodePayload = preload("res://scripts/core/ResourceNodePayloadRules.gd")
const BattleEngine = preload("res://scripts/core/BattleEngine.gd")
const HumanEngine = preload("res://scripts/core/HumanEngine.gd")
const ARTIFACT_CLASSES := ["common", "crafted", "faction", "accord", "relic", "cursed", "set_piece", "old_measure", "scenario"]
const ARTIFACT_RARITIES := ["common", "uncommon", "rare", "epic", "legendary", "scenario"]
# The rarities each HoMM3 artifact class draws from on generated maps, in order:
# a relic falls back to a rare artifact once the hero holds every epic one.
const H3M_ARTIFACT_CLASS_RARITIES := {
	"treasure": [["common", "uncommon"]],
	"minor": [["uncommon"]],
	"major": [["rare"]],
	"relic": [["epic"], ["rare"]],
}
const ARTIFACT_REWARD_GUARD_TIERS := ["unguarded", "light", "standard", "heavy", "elite", "sovereign", "apex", "ambush"]
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
const DAILY_INCOME_RESOURCE_IDS := [
	"gold",
	"wood",
	"ore",
	"aetherglass",
	"embergrain",
	"peatwax",
	"verdant_grafts",
	"brass_scrip",
	"memory_salt",
]

## The sets whose bonuses are active, each as [set record, its piece ids], in
## catalog order; shared and read-only, rebuilt when the content changes.
static var _active_set_catalog := []
static var _active_set_sources := []

static func ensure_hero_artifacts(hero_state: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"ArtifactRules.ensure_hero_artifacts", [hero_state])

static func build_artifact_nodes(placements: Variant, scenario_id: String = "") -> Array:
	return HumanEngine.native_writing(&"ArtifactRules.build_artifact_nodes", [placements, scenario_id])

static func normalize_hero_artifacts(value: Variant) -> Dictionary:
	return HumanEngine.native_writing(&"ArtifactRules.normalize_hero_artifacts", [value])

static func owned_artifact_ids(hero_state: Dictionary) -> Array:
	return HumanEngine.native_writing(&"ArtifactRules.owned_artifact_ids", [hero_state])

static func locate_artifact(hero_state: Dictionary, artifact_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"ArtifactRules.locate_artifact", [hero_state, artifact_id])

static func aggregate_bonuses(hero_state: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"ArtifactRules.aggregate_bonuses", [hero_state])

static func artifact_set_runtime_state(hero_state: Dictionary) -> Array:
	return HumanEngine.native_writing(&"ArtifactRules.artifact_set_runtime_state", [hero_state])

static func spell_affinity_records(hero_state: Dictionary, spell: Dictionary = {}) -> Array:
	return BattleEngine.native_writing(&"ArtifactRules.spell_affinity_records", [hero_state, spell])

static func artifact_equip_runtime_report(hero_state: Dictionary) -> Dictionary:
	var hero := ensure_hero_artifacts(hero_state.duplicate(true))
	var artifacts = hero.get("artifacts", {})
	var equipped = artifacts.get("equipped", {})
	var inventory = artifacts.get("inventory", [])
	var bonuses := aggregate_bonuses(hero)
	var equipped_artifacts := []
	for slot in EQUIPMENT_SLOTS:
		var artifact_id := String(equipped.get(slot, ""))
		if artifact_id == "":
			continue
		equipped_artifacts.append(
			{
				"slot": slot,
				"name": artifact_name(artifact_id),
				"effect_summary": artifact_effect_summary(artifact_id),
				"impact_summary": describe_single_artifact_impact(artifact_id),
			}
		)

	var spell_modifiers = bonuses.get("spell_modifiers", [])
	var daily_income := _common_resource_delta(bonuses.get("daily_income", {}))
	var rare_income := _rare_resource_delta(bonuses.get("daily_income", {}))
	var live_contexts := {
		"equipment_management": owned_artifact_ids(hero).size() > 0,
		"adventure_movement": int(bonuses.get("overworld_movement", 0)) != 0,
		"adventure_scouting": int(bonuses.get("scouting_radius", 0)) != 0,
		"battle_command": (
			int(bonuses.get("battle_attack", 0)) != 0
			or int(bonuses.get("battle_defense", 0)) != 0
			or int(bonuses.get("battle_initiative", 0)) != 0
		),
		"daily_common_income": not daily_income.is_empty(),
		"daily_rare_income": not rare_income.is_empty(),
		"spell_modifiers": spell_modifiers is Array and not spell_modifiers.is_empty(),
	}

	return {
		"ok": equipped_artifacts.size() > 0,
		"schema_status": "artifact_equip_runtime_effects_loaded",
		"equipped_slot_count": equipped_artifacts.size(),
		"inventory_artifact_count": inventory.size() if inventory is Array else 0,
		"equipped_artifacts": equipped_artifacts,
		"management_action_count": get_management_actions(hero).size(),
		"aggregate_bonuses": {
			"overworld_movement": int(bonuses.get("overworld_movement", 0)),
			"scouting_radius": int(bonuses.get("scouting_radius", 0)),
			"battle_attack": int(bonuses.get("battle_attack", 0)),
			"battle_defense": int(bonuses.get("battle_defense", 0)),
			"battle_initiative": int(bonuses.get("battle_initiative", 0)),
			"daily_common_income": daily_income,
			"daily_rare_income": rare_income,
			"spell_modifier_count": spell_modifiers.size() if spell_modifiers is Array else 0,
		},
		"live_contexts": live_contexts,
		"active_sets": bonuses.get("active_sets", []),
		"slot_surface": {
			"active_slots": EQUIPMENT_SLOTS.duplicate(),
			"active_trinket_slots": 2,
			"target_trinket_slots": int(SLOT_LIMITS.get("trinket", 1)),
			"second_trinket_slot_live": true,
		},
		"not_live_contexts": [
			"source_reward_drop_execution",
			"ai_valuation_behavior",
		],
		"runtime_policy": {
			"save_version_bump": false,
			"source_reward_execution": false,
			"set_bonuses_active": true,
			"ai_valuation_behavior": false,
			"rare_resource_activation": true,
			"broad_ui_overhaul": false,
		},
	}

static func merge_hero_artifacts(base_artifacts: Variant, imported_artifacts: Variant) -> Dictionary:
	return HumanEngine.native(&"ArtifactRules.merge_hero_artifacts", [base_artifacts, imported_artifacts])

static func equip_artifact(hero_state: Dictionary, artifact_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"ArtifactRules.equip_artifact", [hero_state, artifact_id])

static func equipment_slot_accepts(slot: String, artifact_id: String) -> bool:
	return HumanEngine.native(&"ArtifactRules.equipment_slot_accepts", [slot, artifact_id])

static func unequip_artifact(hero_state: Dictionary, slot: String) -> Dictionary:
	return HumanEngine.native_writing(&"ArtifactRules.unequip_artifact", [hero_state, slot])

static func describe_loadout(hero_state: Dictionary) -> String:
	hero_state = ensure_hero_artifacts(hero_state.duplicate(true))
	var equipped = hero_state.get("artifacts", {}).get("equipped", {})
	var parts := []
	for slot in EQUIPMENT_SLOTS:
		var artifact_id := String(equipped.get(slot, ""))
		parts.append(
			"%s %s" % [
				_equipment_slot_label(slot),
				artifact_name(artifact_id) if artifact_id != "" else "empty",
			]
		)

	var inventory = hero_state.get("artifacts", {}).get("inventory", [])
	var inventory_count: int = inventory.size() if inventory is Array else 0
	return "Artifacts: %s | Pack %d\n%s\n%s\n%s" % [
		", ".join(parts),
		inventory_count,
		describe_impact_summary(hero_state),
		describe_set_bonus_summary(hero_state),
		describe_collection_summary(hero_state),
	]

static func describe_set_bonus_summary(hero_state: Dictionary) -> String:
	return HumanEngine.native_writing(&"ArtifactRules.describe_set_bonus_summary", [hero_state])

static func describe_impact_summary(hero_state: Dictionary) -> String:
	return HumanEngine.native_writing(&"ArtifactRules.describe_impact_summary", [hero_state])

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
	return HumanEngine.native_writing(&"ArtifactRules.describe_collection_summary", [hero_state])

static func describe_single_artifact_impact(artifact_id: String) -> String:
	return HumanEngine.native(&"ArtifactRules.describe_single_artifact_impact", [artifact_id])

static func get_management_actions(hero_state: Dictionary) -> Array:
	return HumanEngine.native_writing(&"ArtifactRules.get_management_actions", [hero_state])

static func artifact_name(artifact_id: String) -> String:
	return HumanEngine.native(&"ArtifactRules.artifact_name", [artifact_id])

static func artifact_id_for_management_action(hero_state: Dictionary, action_id: String) -> String:
	return HumanEngine.native_writing(&"ArtifactRules.artifact_id_for_management_action", [hero_state, action_id])

static func artifact_icon_path(artifact_id: String) -> String:
	return HumanEngine.native(&"ArtifactRules.artifact_icon_path", [artifact_id])

static func artifact_slot(artifact_id: String) -> String:
	return HumanEngine.native(&"ArtifactRules.artifact_slot", [artifact_id])

static func artifact_slot_label(artifact_id: String) -> String:
	return HumanEngine.native(&"ArtifactRules.artifact_slot_label", [artifact_id])

static func artifact_set_context(artifact_id: String) -> String:
	return HumanEngine.native(&"ArtifactRules.artifact_set_context", [artifact_id])

static func artifact_effect_summary(artifact_id: String) -> String:
	return HumanEngine.native(&"ArtifactRules.artifact_effect_summary", [artifact_id])

static func artifact_reward_role(artifact_id: String) -> String:
	return HumanEngine.native(&"ArtifactRules.artifact_reward_role", [artifact_id])

static func artifact_decision_summary(hero_state: Dictionary, artifact_id: String) -> String:
	return HumanEngine.native_writing(&"ArtifactRules.artifact_decision_summary", [hero_state, artifact_id])

static func describe_artifact_short(artifact_id: String) -> String:
	return HumanEngine.native(&"ArtifactRules.describe_artifact_short", [artifact_id])

static func describe_artifact_inspection(hero_state: Dictionary, artifact_id: String, collected: bool = false, collected_by_faction_id: String = "") -> String:
	return HumanEngine.native_writing(&"ArtifactRules.describe_artifact_inspection", [hero_state, artifact_id, collected, collected_by_faction_id])

static func artifact_collection_state(hero_state: Dictionary, artifact_id: String, collected: bool = false, collected_by_faction_id: String = "") -> String:
	return HumanEngine.native_writing(&"ArtifactRules.artifact_collection_state", [hero_state, artifact_id, collected, collected_by_faction_id])

static func describe_artifact(artifact_id: String) -> String:
	return HumanEngine.native(&"ArtifactRules.describe_artifact", [artifact_id])

static func _equipment_slot_label(slot: String) -> String:
	return HumanEngine.native(&"ArtifactRules._equipment_slot_label", [slot])

static func _bonus_impact_sections(totals: Dictionary, include_empty_sections: bool) -> Array:
	return HumanEngine.native(&"ArtifactRules._bonus_impact_sections", [totals, include_empty_sections])

static func _common_resource_delta(value: Variant) -> Dictionary:
	var result := {}
	if not (value is Dictionary):
		return result
	for key in ["gold", "wood", "ore"]:
		var amount := int(value.get(key, 0))
		if amount != 0:
			result[key] = amount
	return result

static func _rare_resource_delta(value: Variant) -> Dictionary:
	var result := {}
	if not (value is Dictionary):
		return result
	for key_value in value.keys():
		var key := String(key_value)
		if key in ["gold", "wood", "ore"]:
			continue
		var amount := int(value.get(key, 0))
		if amount != 0:
			result[key] = amount
	return result
