class_name TownRules
extends RefCounted
const TownDevelopment = preload("res://scripts/core/TownDevelopmentRules.gd")

const BUILDING_CATEGORY_IDS := ["civic", "dwelling", "economy", "support", "magic"]
const MARKET_GOLD := "gold"

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
static var OverworldRulesScript: Variant = load("res://scripts/core/OverworldRules.gd")
static var HeroCommandRulesScript: Variant = load("res://scripts/core/HeroCommandRules.gd")
const SpellRulesScript = preload("res://scripts/core/SpellRules.gd")
const ArtifactRulesScript = preload("res://scripts/core/ArtifactRules.gd")
const HeroProgressionRulesScript = preload("res://scripts/core/HeroProgressionRules.gd")
const HumanEngine = preload("res://scripts/core/HumanEngine.gd")
static var EnemyAdventureRulesScript: Variant = load("res://scripts/core/EnemyAdventureRules.gd")
static var ScenarioRulesScript: Variant = load("res://scripts/core/ScenarioRules.gd")

static var _read_scope_session_id := ""
static var _read_scope_depth := 0
static var _read_scope_cache := {}

const FACTION_SPELL_SCHOOL_ACCESS := {
	"faction_embercourt": ["beacon", "furnace"],
	"faction_mireclaw": ["mire", "root"],
	"faction_sunvault": ["lens", "beacon"],
	"faction_thornwake": ["root", "mire"],
	"faction_brasshollow": ["furnace", "old_measure"],
	"faction_veilmourn": ["veil", "old_measure"],
}

static func building_id_for_action(action_id: String) -> String:
	return HumanEngine.native(&"TownRules.building_id_for_action", [action_id])

static func building_category_icon_path(building_id: String) -> String:
	return HumanEngine.native(&"TownRules.building_category_icon_path", [building_id])

static func building_icon_path(building_id: String, faction_id: String = "") -> String:
	return HumanEngine.native(&"TownRules.building_icon_path", [building_id, faction_id])

static func faction_crest_icon_path(faction_id: String) -> String:
	return HumanEngine.native(&"TownRules.faction_crest_icon_path", [faction_id])

static func begin_read_scope(session: SessionStateStoreScript.SessionData) -> void:
	HumanEngine.native_writing(&"TownRules.begin_read_scope", [session])

static func end_read_scope(session: SessionStateStoreScript.SessionData) -> void:
	HumanEngine.native_writing(&"TownRules.end_read_scope", [session])

static func can_visit_active_town(session: SessionStateStoreScript.SessionData) -> bool:
	return HumanEngine.native_writing(&"TownRules.can_visit_active_town", [session])

static func can_visit_active_town_bridge(session) -> bool:
	return can_visit_active_town(session)

static func get_active_town(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return HumanEngine.native_writing(&"TownRules.get_active_town", [session])

static func describe_status(session: SessionStateStoreScript.SessionData) -> String:
	return HumanEngine.native_writing(&"TownRules.describe_status", [session])

static func describe_header(session: SessionStateStoreScript.SessionData) -> String:
	return HumanEngine.native_writing(&"TownRules.describe_header", [session])

static func describe_summary(session: SessionStateStoreScript.SessionData) -> String:
	return HumanEngine.native_writing(&"TownRules.describe_summary", [session])

static func describe_production_overview(session: SessionStateStoreScript.SessionData) -> String:
	return HumanEngine.native_writing(&"TownRules.describe_production_overview", [session])

static func describe_outlook_board(session: SessionStateStoreScript.SessionData) -> String:
	return HumanEngine.native_writing(&"TownRules.describe_outlook_board", [session])

static func describe_command_ledger(session: SessionStateStoreScript.SessionData) -> String:
	return HumanEngine.native_writing(&"TownRules.describe_command_ledger", [session])

static func describe_defense(session: SessionStateStoreScript.SessionData) -> String:
	return HumanEngine.native_writing(&"TownRules.describe_defense", [session])

static func describe_threats(session: SessionStateStoreScript.SessionData) -> String:
	return HumanEngine.native_writing(&"TownRules.describe_threats", [session])

static func describe_event_feed(session: SessionStateStoreScript.SessionData, last_message: String = "", action_recap: Dictionary = {}) -> String:
	return HumanEngine.native_writing(&"TownRules.describe_event_feed", [session, last_message, action_recap])

static func town_handoff_recap(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return HumanEngine.native_writing(&"TownRules.town_handoff_recap", [session])

static func town_departure_confirmation(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return HumanEngine.native_writing(&"TownRules.town_departure_confirmation", [session])

static func town_order_target_handoff(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return HumanEngine.native_writing(&"TownRules.town_order_target_handoff", [session])

static func town_action_consequence_signature(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return HumanEngine.native_writing(&"TownRules.town_action_consequence_signature", [session])

static func build_town_action_recap(session: SessionStateStoreScript.SessionData, lane: String, action_id: String, action: Dictionary, result: Dictionary, before: Dictionary, after_signature: Dictionary = {}) -> Dictionary:
	return HumanEngine.native_writing(&"TownRules.build_town_action_recap", [session, lane, action_id, action, result, before, after_signature])

static func describe_buildings(session: SessionStateStoreScript.SessionData) -> String:
	return HumanEngine.native_writing(&"TownRules.describe_buildings", [session])

static func describe_recruitment(session: SessionStateStoreScript.SessionData) -> String:
	return HumanEngine.native_writing(&"TownRules.describe_recruitment", [session])

static func describe_market(session: SessionStateStoreScript.SessionData) -> String:
	return HumanEngine.native_writing(&"TownRules.describe_market", [session])

static func describe_spell_access(session: SessionStateStoreScript.SessionData) -> String:
	return HumanEngine.native_writing(&"TownRules.describe_spell_access", [session])

static func describe_artifacts(session: SessionStateStoreScript.SessionData) -> String:
	return HumanEngine.native_writing(&"TownRules.describe_artifacts", [session])

static func describe_heroes(session: SessionStateStoreScript.SessionData) -> String:
	return HumanEngine.native_writing(&"TownRules.describe_heroes", [session])

static func describe_specialties(session: SessionStateStoreScript.SessionData) -> String:
	return HumanEngine.native_writing(&"TownRules.describe_specialties", [session])

static func describe_tavern(session: SessionStateStoreScript.SessionData) -> String:
	return HumanEngine.native_writing(&"TownRules.describe_tavern", [session])

static func describe_transfer(session: SessionStateStoreScript.SessionData) -> String:
	return HumanEngine.native_writing(&"TownRules.describe_transfer", [session])

static func describe_responses(session: SessionStateStoreScript.SessionData) -> String:
	return HumanEngine.native_writing(&"TownRules.describe_responses", [session])

static func get_build_actions(session: SessionStateStoreScript.SessionData) -> Array:
	return HumanEngine.native_writing(&"TownRules.get_build_actions", [session])

static func get_recruit_actions(session: SessionStateStoreScript.SessionData) -> Array:
	return HumanEngine.native_writing(&"TownRules.get_recruit_actions", [session])

static func get_build_catalog(session: SessionStateStoreScript.SessionData) -> Array:
	return HumanEngine.native_writing(&"TownRules.get_build_catalog", [session])

static func get_muster_catalog(session: SessionStateStoreScript.SessionData) -> Array:
	return HumanEngine.native_writing(&"TownRules.get_muster_catalog", [session])

static func get_market_actions(session: SessionStateStoreScript.SessionData) -> Array:
	return HumanEngine.native_writing(&"TownRules.get_market_actions", [session])

static func get_hero_actions(session: SessionStateStoreScript.SessionData) -> Array:
	return HumanEngine.native_writing(&"TownRules.get_hero_actions", [session])

static func get_tavern_actions(session: SessionStateStoreScript.SessionData) -> Array:
	return HumanEngine.native_writing(&"TownRules.get_tavern_actions", [session])

static func get_transfer_actions(session: SessionStateStoreScript.SessionData) -> Array:
	return HumanEngine.native_writing(&"TownRules.get_transfer_actions", [session])

static func get_response_actions(session: SessionStateStoreScript.SessionData) -> Array:
	return HumanEngine.native_writing(&"TownRules.get_response_actions", [session])

static func get_spell_learning_actions(session: SessionStateStoreScript.SessionData) -> Array:
	return HumanEngine.native_writing(&"TownRules.get_spell_learning_actions", [session])

static func get_artifact_actions(session: SessionStateStoreScript.SessionData) -> Array:
	return HumanEngine.native_writing(&"TownRules.get_artifact_actions", [session])

static func get_specialty_actions(session: SessionStateStoreScript.SessionData) -> Array:
	return HumanEngine.native_writing(&"TownRules.get_specialty_actions", [session])

static func build_active_town(session: SessionStateStoreScript.SessionData, building_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"TownRules.build_active_town", [session, building_id])

static func switch_active_hero_at_town(session: SessionStateStoreScript.SessionData, hero_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"TownRules.switch_active_hero_at_town", [session, hero_id])

## `runtime_normalized`: the caller (the Town screen) has just runtime-normalized
## the session in its order preflight, so the order skips a second full pass.
static func recruit_active_town(session: SessionStateStoreScript.SessionData, unit_id: String, requested_count: int = -1, runtime_normalized: bool = false) -> Dictionary:
	return HumanEngine.native_writing(&"TownRules.recruit_active_town", [session, unit_id, requested_count, runtime_normalized])

static func perform_market_action(session: SessionStateStoreScript.SessionData, action_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"TownRules.perform_market_action", [session, action_id])

# --- market desk ----------------------------------------------------------------

## The market popout trades any resource for any other, HoMM3 style: gold buys
## a resource, a resource sells for gold, or one resource converts straight
## into another, rare resources included. A conversion charges the received
## resource at the midpoint of this market's buy and sell price and takes the
## given resource at its sell price, so it beats selling for gold and buying
## back but never pays for itself in a round trip. Every mode follows the
## town's market state (market tier, local abundance and each resource's
## economy value). A conversion counts against the given resource's weekly
## sell limit and the received resource's weekly buy limit.

static func market_action_label(action_id: String) -> String:
	return HumanEngine.native(&"TownRules.market_action_label", [action_id])

static func hire_hero_at_active_town(session: SessionStateStoreScript.SessionData, hero_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"TownRules.hire_hero_at_active_town", [session, hero_id])

static func transfer_in_active_town(session: SessionStateStoreScript.SessionData, action_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"TownRules.transfer_in_active_town", [session, action_id])

static func manage_army_slots_in_active_town(session: SessionStateStoreScript.SessionData, source_holder_id: String, source_slot_index: int, target_holder_id: String, target_slot_index: int, amount_token: String = "all") -> Dictionary:
	return HumanEngine.native_writing(&"TownRules.manage_army_slots_in_active_town", [session, source_holder_id, source_slot_index, target_holder_id, target_slot_index, amount_token])

## Moves a hero into the active town's garrison ("" sends the garrison hero out
## to the gate). See HeroCommandRules.set_town_garrison_hero.
static func set_garrison_hero_in_active_town(session: SessionStateStoreScript.SessionData, hero_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"TownRules.set_garrison_hero_in_active_town", [session, hero_id])

static func perform_response_action(session: SessionStateStoreScript.SessionData, action_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"TownRules.perform_response_action", [session, action_id])

static func learn_spell_at_active_town(session: SessionStateStoreScript.SessionData, spell_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"TownRules.learn_spell_at_active_town", [session, spell_id])

static func teach_visiting_heroes(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"TownRules.teach_visiting_heroes", [session, town])

static func manage_artifact_at_active_town(session: SessionStateStoreScript.SessionData, action_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"TownRules.manage_artifact_at_active_town", [session, action_id])

static func choose_specialty_at_active_town(session: SessionStateStoreScript.SessionData, specialty_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"TownRules.choose_specialty_at_active_town", [session, specialty_id])

static func current_spell_tier(town: Dictionary) -> int:
	return HumanEngine.native_writing(&"TownRules.current_spell_tier", [town])

static func accessible_spell_ids(town: Dictionary) -> Array:
	return HumanEngine.native_writing(&"TownRules.accessible_spell_ids", [town])

static func _town_build_recommendation_score(town: Dictionary, action: Dictionary) -> int:
	return HumanEngine.native_writing(&"TownRules._town_build_recommendation_score", [town, action])

static func _town_recruit_recommendation_score(action: Dictionary) -> int:
	return HumanEngine.native_writing(&"TownRules._town_recruit_recommendation_score", [action])

static func _recruit_choice_impact_line(unit_id: String, ready_count: int, available_count: int) -> String:
	return HumanEngine.native(&"TownRules._recruit_choice_impact_line", [unit_id, ready_count, available_count])

static func _action_recommendation_line(lane: String, label: String, ready: bool, market_coverable: bool, shortfall_summary: String, impact_line: String) -> String:
	return HumanEngine.native(&"TownRules._action_recommendation_line", [lane, label, ready, market_coverable, shortfall_summary, impact_line])

static func _unit_tier_label(unit_tier: int) -> String:
	return HumanEngine.native(&"TownRules._unit_tier_label", [unit_tier])

static func _signed_int(value: int) -> String:
	return HumanEngine.native(&"TownRules._signed_int", [value])

static func _next_town_action_line(session: SessionStateStoreScript.SessionData, town: Dictionary) -> String:
	return HumanEngine.native_writing(&"TownRules._next_town_action_line", [session, town])

static func _town_handoff_affected_line(town_name: String, front: Dictionary, occupation: Dictionary, logistics: Dictionary, ready_response: Dictionary) -> String:
	return HumanEngine.native_writing(&"TownRules._town_handoff_affected_line", [town_name, front, occupation, logistics, ready_response])

static func _town_handoff_why_line(town: Dictionary, front: Dictionary, occupation: Dictionary, logistics: Dictionary, recovery: Dictionary, ready_response: Dictionary) -> String:
	return HumanEngine.native_writing(&"TownRules._town_handoff_why_line", [town, front, occupation, logistics, recovery, ready_response])

static func _short_town_handoff_text(text: String, max_chars: int) -> String:
	return HumanEngine.native(&"TownRules._short_town_handoff_text", [text, max_chars])

static func _short_action_label(action: Dictionary, fallback: String) -> String:
	return HumanEngine.native_writing(&"TownRules._short_action_label", [action, fallback])

static func _action_projection_line(action: Dictionary) -> String:
	return HumanEngine.native_writing(&"TownRules._action_projection_line", [action])

static func _market_coverage_line(readiness: Dictionary) -> String:
	return HumanEngine.native_writing(&"TownRules._market_coverage_line", [readiness])

static func _cost_shortfall_line(readiness: Dictionary) -> String:
	return HumanEngine.native_writing(&"TownRules._cost_shortfall_line", [readiness])

static func _cost_readiness_line(resources: Dictionary, cost: Variant, readiness: Dictionary) -> String:
	return HumanEngine.native_writing(&"TownRules._cost_readiness_line", [resources, cost, readiness])

static func _stores_after_cost_line(resources: Dictionary, cost: Variant) -> String:
	return HumanEngine.native_writing(&"TownRules._stores_after_cost_line", [resources, cost])

static func _recruit_affordability_label(direct_count: int, market_count: int, shortfall_summary: String) -> String:
	return HumanEngine.native(&"TownRules._recruit_affordability_label", [direct_count, market_count, shortfall_summary])

static func _disabled_reason_line(ready: bool, market_coverable: bool, market_summary: String, shortfall_summary: String) -> String:
	return HumanEngine.native(&"TownRules._disabled_reason_line", [ready, market_coverable, market_summary, shortfall_summary])

static func _max_market_affordable_count(session: SessionStateStoreScript.SessionData, town: Dictionary, resources: Dictionary, unit_cost: Variant, available_count: int) -> int:
	return HumanEngine.native_writing(&"TownRules._max_market_affordable_count", [session, town, resources, unit_cost, available_count])

static func _multiply_resource_cost(cost: Variant, multiplier: int) -> Dictionary:
	return HumanEngine.native_writing(&"TownRules._multiply_resource_cost", [cost, multiplier])

static func _building_line(building_id: String, state: String, build_status: Dictionary = {}) -> String:
	return HumanEngine.native_writing(&"TownRules._building_line", [building_id, state, build_status])

static func _describe_building_names(building_ids: Variant) -> String:
	var names := []
	if building_ids is Array:
		for building_id_value in building_ids:
			var building := ContentService.get_building(String(building_id_value))
			names.append(String(building.get("name", building_id_value)))
	return ", ".join(names)

static func _town_name(town: Dictionary) -> String:
	return HumanEngine.native_writing(&"TownRules._town_name", [town])

static func _town_identity_summary(town: Dictionary) -> String:
	var town_template := ContentService.get_town(String(town.get("town_id", "")))
	var summary := String(town_template.get("identity_summary", ""))
	if summary != "":
		return summary
	var faction := ContentService.get_faction(String(town_template.get("faction_id", "")))
	return String(faction.get("identity_summary", "No town identity has been authored yet."))

static func _army_summary(army: Variant) -> String:
	var stacks = army.get("stacks", []) if army is Dictionary else []
	var parts := []
	if stacks is Array:
		for stack in stacks:
			if not (stack is Dictionary):
				continue
			var count := int(max(0, int(stack.get("count", 0))))
			if count <= 0:
				continue
			var unit_id := String(stack.get("unit_id", ""))
			var unit_name := String(ContentService.get_unit(unit_id).get("name", unit_id))
			parts.append("%s x%d" % [unit_name, count])
	return ", ".join(parts) if not parts.is_empty() else "No troops"

static func _town_pressure_label(town: Dictionary) -> String:
	return HumanEngine.native_writing(&"TownRules._town_pressure_label", [town])

static func _describe_vulnerability_penalties(penalties: Dictionary) -> String:
	return HumanEngine.native_writing(&"TownRules._describe_vulnerability_penalties", [penalties])

const ENEMY_HERO_WATCH_RADIUS := 10

static func _max_affordable_count(session: SessionStateStoreScript.SessionData, unit_cost: Variant) -> int:
	return HumanEngine.native_writing(&"TownRules._max_affordable_count", [session, unit_cost])

static func _merge_resources(base: Variant, delta: Variant) -> Dictionary:
	var merged := {"gold": 0, "wood": 0, "ore": 0}
	if base is Dictionary:
		for key in merged.keys():
			merged[key] = int(base.get(key, 0))
	if delta is Dictionary:
		for key in delta.keys():
			var resource_key := String(key)
			if resource_key == "experience":
				continue
			merged[resource_key] = int(merged.get(resource_key, 0)) + int(delta[key])
	return merged

static func _describe_resources(resources: Variant, empty_label: String = "none") -> String:
	return HumanEngine.native_writing(&"TownRules._describe_resources", [resources, empty_label])

static func _resource_keys_for_payload(value: Variant) -> Array:
	return HumanEngine.native_writing(&"TownRules._resource_keys_for_payload", [value])

static func _describe_recruit_delta(delta: Variant) -> String:
	return HumanEngine.native_writing(&"TownRules._describe_recruit_delta", [delta])

static func _town_unit_ids(town: Dictionary) -> Array:
	return HumanEngine.native_writing(&"TownRules._town_unit_ids", [town])

static func _unit_is_unlocked_in_town(town: Dictionary, unit_id: String) -> bool:
	return HumanEngine.native_writing(&"TownRules._unit_is_unlocked_in_town", [town, unit_id])

static func _unlock_building_for_unit(town: Dictionary, unit_id: String) -> String:
	return HumanEngine.native_writing(&"TownRules._unlock_building_for_unit", [town, unit_id])

static func _town_artifact_service_actions(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Array:
	return HumanEngine.native_writing(&"TownRules._town_artifact_service_actions", [session, town])
