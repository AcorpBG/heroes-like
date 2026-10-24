class_name HeroCommandRules
extends RefCounted

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const OverworldLevelRulesScript = preload("res://scripts/core/OverworldLevelRules.gd")
const HeroProgressionRulesScript = preload("res://scripts/core/HeroProgressionRules.gd")
const SpellRulesScript = preload("res://scripts/core/SpellRules.gd")
const ArtifactRulesScript = preload("res://scripts/core/ArtifactRules.gd")
const PlayerRules = preload("res://scripts/core/PlayerIdentityRules.gd")
const DayEngine = preload("res://scripts/core/DayEngine.gd")
const HumanEngine = preload("res://scripts/core/HumanEngine.gd")
static var DifficultyRulesScript: Variant = load("res://scripts/core/DifficultyRules.gd")

const HALL_BUILDING_ID := "building_wayfarers_hall"
const HOLDER_GARRISON := "garrison"
const HERO_LIMIT := 4
const TAVERN_OFFER_SIZE := 2
const TAVERN_ROTATION_KEY := "tavern_rotation"
const ARMY_SLOT_COUNT := 7
const ARMY_SLOT_INDEX_KEY := "slot_index"
const TOWN_GARRISON_HERO_KEY := "garrison_hero_id"
const TOWN_GARRISON_HEROES_VERSION_KEY := "town_garrison_heroes_version"
const TOWN_GARRISON_HEROES_VERSION := 1
const DEFAULT_RECRUIT_COST := {"gold": 1200}
const BASE_SCOUT_RADIUS := 6
const TOWN_DEVELOPMENT_PATH := "res://content/town_development.json"
# Tavern veterans: about one offer in ten is level 2 and one in thirty level 3.
const TAVERN_LEVEL_TWO_PERCENT := 10
const TAVERN_LEVEL_THREE_PERCENT := 3
# HoMM3-like starting army: a tier-1 company always, often a second company
# (usually tier 2, sometimes the other tier-1 creature). Sizes are shares of
# the creature's weekly growth. The shares were cut when growth was rebalanced
# to equal weekly power per tier, so starting armies kept their strength.
const STARTING_SECOND_COMPANY_PERCENT := 75
const STARTING_SECOND_COMPANY_TIER_TWO_PERCENT := 70
const STARTING_FIRST_COMPANY_GROWTH_SHARE := [0.55, 1.1]
const STARTING_SECOND_COMPANY_GROWTH_SHARE := [0.33, 0.65]

static func normalize_session(session: SessionStateStoreScript.SessionData, primary_hero_id: String = "", default_position: Dictionary = {}, default_army: Dictionary = {}) -> void:
	HumanEngine.native_writing(&"HeroCommandRules.normalize_session", [session, primary_hero_id, default_position, default_army])

static func build_hero_from_template(hero_template: Dictionary, position: Dictionary = {}, army_state: Dictionary = {}, movement_source: Variant = null) -> Dictionary:
	return HumanEngine.native_writing(&"HeroCommandRules.build_hero_from_template", [hero_template, position, army_state, movement_source])

static func starting_army_for_hero(hero_template: Dictionary, seed_key: String) -> Dictionary:
	return HumanEngine.native_writing(&"HeroCommandRules.starting_army_for_hero", [hero_template, seed_key])

static func army_has_troops(army: Variant) -> bool:
	return HumanEngine.native_writing(&"HeroCommandRules.army_has_troops", [army])

## A new hero's growth seed (HeroProgressionRules.command_gain_stat): from the
## session and hero when a session is known, so the tavern's preview and the
## hire it shows roll alike, else drawn at random.
static func new_growth_seed(hero_id: String, session_source: Variant = null) -> String:
	return HumanEngine.native(&"HeroCommandRules.new_growth_seed", [hero_id, session_source])

## A new game's start hero is built before its session exists, so it drew a
## random growth seed. The session's creator calls this once the session is
## made, so the start hero is seeded from it like every later hire and two new
## games on the same map and seed level it up alike. Never called on load: a
## saved hero keeps the seed it was saved with.
static func seed_start_heroes_from_session(session: SessionStateStoreScript.SessionData) -> void:
	HumanEngine.native_writing(&"HeroCommandRules.seed_start_heroes_from_session", [session])

static func movement_max_for_hero(hero_state: Dictionary, movement_source: Variant = null) -> int:
	return HumanEngine.native_writing(&"HeroCommandRules.movement_max_for_hero", [hero_state, movement_source])

static func scouting_radius_for_hero(hero_state: Dictionary) -> int:
	return HumanEngine.native_writing(&"HeroCommandRules.scouting_radius_for_hero", [hero_state])

static func active_hero(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return HumanEngine.native_writing(&"HeroCommandRules.active_hero", [session])

static func primary_hero(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return primary_hero_from_overworld(session.overworld if session != null else {}, session.hero_id if session != null else "")

static func hero_by_id(session: SessionStateStoreScript.SessionData, hero_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"HeroCommandRules.hero_by_id", [session, hero_id])

static func hero_inspection_snapshot(session: SessionStateStoreScript.SessionData, hero_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"HeroCommandRules.hero_inspection_snapshot", [session, hero_id])

static func player_hero_count(session: SessionStateStoreScript.SessionData) -> int:
	return HumanEngine.native_writing(&"HeroCommandRules.player_hero_count", [session])

static func spend_active_hero_movement(session: SessionStateStoreScript.SessionData, amount: int, reason: String = "") -> Dictionary:
	return HumanEngine.native_writing(&"HeroCommandRules.spend_active_hero_movement", [session, amount, reason])

static func commit_active_hero(session: SessionStateStoreScript.SessionData) -> void:
	DayEngine.native_writing(&"HeroCommandRules.commit_active_hero", [session])

static func hero_template(payload: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"HeroCommandRules.hero_template", [payload])

static func hero_faction_label(payload: Dictionary, fallback_faction_id: String = "") -> String:
	return HumanEngine.native_writing(&"HeroCommandRules.hero_faction_label", [payload, fallback_faction_id])

static func hero_identity_summary(payload: Dictionary) -> String:
	var template := hero_template(payload)
	return String(template.get("identity_summary", ""))

static func hero_role_label(payload: Dictionary) -> String:
	return HumanEngine.native_writing(&"HeroCommandRules.hero_role_label", [payload])

static func hero_identity_context_line(payload: Dictionary, fallback_faction_id: String = "") -> String:
	return HumanEngine.native_writing(&"HeroCommandRules.hero_identity_context_line", [payload, fallback_faction_id])

static func hero_progress_context_line(hero_state: Dictionary) -> String:
	return HumanEngine.native_writing(&"HeroCommandRules.hero_progress_context_line", [hero_state])

static func hero_readiness_context_line(hero_state: Dictionary, include_position: bool = false) -> String:
	return HumanEngine.native_writing(&"HeroCommandRules.hero_readiness_context_line", [hero_state, include_position])

static func hero_profile_summary(payload: Dictionary, include_focus: bool = false) -> String:
	return HumanEngine.native_writing(&"HeroCommandRules.hero_profile_summary", [payload, include_focus])

static func stationed_heroes(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Array:
	return HumanEngine.native_writing(&"HeroCommandRules.stationed_heroes", [session, town])

static func town_garrison_hero(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"HeroCommandRules.town_garrison_hero", [session, town])

static func town_visiting_hero(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"HeroCommandRules.town_visiting_hero", [session, town])

## The army slot holder of the garrison row: the garrison hero, else the town.
static func town_garrison_holder_id(session: SessionStateStoreScript.SessionData, town: Dictionary) -> String:
	return HumanEngine.native_writing(&"HeroCommandRules.town_garrison_holder_id", [session, town])

## Places `hero_id` in the garrison, or sends the garrison hero out to the gate
## when `hero_id` is "". Entering an unheld garrison takes its troops into the
## hero's army (they must fit in seven slots); entering a held garrison swaps the
## two heroes, the old garrison hero leaving with its own army.
static func set_town_garrison_hero(session: SessionStateStoreScript.SessionData, town: Dictionary, hero_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"HeroCommandRules.set_town_garrison_hero", [session, town, hero_id])

static func town_recruitment_destination(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"HeroCommandRules.town_recruitment_destination", [session, town])

static func town_defense_force(session: SessionStateStoreScript.SessionData, town: Dictionary, preferred_hero_id: String = "") -> Dictionary:
	return HumanEngine.native_writing(&"HeroCommandRules.town_defense_force", [session, town, preferred_hero_id])

static func describe_town_defense_force(session: SessionStateStoreScript.SessionData, town: Dictionary) -> String:
	return HumanEngine.native_writing(&"HeroCommandRules.describe_town_defense_force", [session, town])

static func empty_owned_towns(session: SessionStateStoreScript.SessionData) -> Array:
	return HumanEngine.native_writing(&"HeroCommandRules.empty_owned_towns", [session])

static func get_tavern_actions(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Array:
	return HumanEngine.native_writing(&"HeroCommandRules.get_tavern_actions", [session, town])

static func army_addition_plan(stacks_value: Variant, additions: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"HeroCommandRules.army_addition_plan", [stacks_value, additions])

static func army_slot_snapshot(session: SessionStateStoreScript.SessionData, town: Dictionary, holder_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"HeroCommandRules.army_slot_snapshot", [session, town, holder_id])

static func manage_army_slots(session: SessionStateStoreScript.SessionData, town: Dictionary, source_holder_id: String, source_slot_index: int, target_holder_id: String, target_slot_index: int, amount_token: String = "all") -> Dictionary:
	return HumanEngine.native_writing(&"HeroCommandRules.manage_army_slots", [session, town, source_holder_id, source_slot_index, target_holder_id, target_slot_index, amount_token])

static func field_rendezvous_heroes(session: SessionStateStoreScript.SessionData) -> Array:
	return HumanEngine.native_writing(&"HeroCommandRules.field_rendezvous_heroes", [session])

static func get_field_transfer_actions(session: SessionStateStoreScript.SessionData) -> Array:
	normalize_session(session)
	var actions := []
	if session == null:
		return actions
	var active := active_hero(session)
	if active.is_empty():
		return actions
	for reserve_value in field_rendezvous_heroes(session):
		if not (reserve_value is Dictionary):
			continue
		var reserve: Dictionary = reserve_value
		_append_field_transfer_actions(actions, active, reserve)
		_append_field_transfer_actions(actions, reserve, active)
	return actions

static func transfer_field_stack(session: SessionStateStoreScript.SessionData, source_hero_id: String, target_hero_id: String, unit_id: String, amount_token: String) -> Dictionary:
	return HumanEngine.native_writing(&"HeroCommandRules.transfer_field_stack", [session, source_hero_id, target_hero_id, unit_id, amount_token])

static func transfer_field_artifact(session: SessionStateStoreScript.SessionData, source_hero_id: String, target_hero_id: String, artifact_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"HeroCommandRules.transfer_field_artifact", [session, source_hero_id, target_hero_id, artifact_id])

static func teach_field_spell(session: SessionStateStoreScript.SessionData, source_hero_id: String, target_hero_id: String, spell_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"HeroCommandRules.teach_field_spell", [session, source_hero_id, target_hero_id, spell_id])

# Hero meeting screen (HoMM-style exchange between two commanders on one
# field tile). Slot moves, merges, swaps and splits use manage_army_slots; the
# orders below cover the bulk and slot-precise artifact handoffs.
const FIELD_ARTIFACT_PACK_SLOT := "pack"

static func field_slot_action_id(source_hero_id: String, source_slot_index: int, target_hero_id: String, target_slot_index: int, amount_token: String = "all") -> String:
	return HumanEngine.native(&"HeroCommandRules.field_slot_action_id", [source_hero_id, source_slot_index, target_hero_id, target_slot_index, amount_token])

static func field_troops_all_action_id(source_hero_id: String, target_hero_id: String) -> String:
	return HumanEngine.native(&"HeroCommandRules.field_troops_all_action_id", [source_hero_id, target_hero_id])

static func field_artifact_place_action_id(source_hero_id: String, target_hero_id: String, artifact_id: String, target_slot: String = "") -> String:
	return HumanEngine.native(&"HeroCommandRules.field_artifact_place_action_id", [source_hero_id, target_hero_id, artifact_id, target_slot])

static func field_artifacts_all_action_id(source_hero_id: String, target_hero_id: String) -> String:
	return HumanEngine.native(&"HeroCommandRules.field_artifacts_all_action_id", [source_hero_id, target_hero_id])

static func field_spell_share_action_id(source_hero_id: String, target_hero_id: String, spell_id: String) -> String:
	return HumanEngine.native(&"HeroCommandRules.field_spell_share_action_id", [source_hero_id, target_hero_id, spell_id])

static func field_exchange_state(session: SessionStateStoreScript.SessionData, partner_hero_id: String = "") -> Dictionary:
	return HumanEngine.native_writing(&"HeroCommandRules.field_exchange_state", [session, partner_hero_id])

## The leading heroes that have fallen on a generated map, by id: none of them
## is brought back from the scenario or made leader again, and the next hero
## hired leads when no other is left.
const PRIMARY_FALLEN_FLAG := "primary_hero_fallen"

static func hero_recruit_cost(hero_template: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"HeroCommandRules.hero_recruit_cost", [hero_template])

## The two heroes every player tavern offers this week. A new pair is drawn
## at the start of each week from the faction's hireable heroes; a hired
## hero's place stays empty until then. Reading never changes the session.
static func tavern_offer_ids(session: SessionStateStoreScript.SessionData) -> Array:
	return HumanEngine.native_writing(&"HeroCommandRules.tavern_offer_ids", [session])

static func recruitable_hero_ids(session: SessionStateStoreScript.SessionData) -> Array:
	return HumanEngine.native_writing(&"HeroCommandRules.recruitable_hero_ids", [session])

static func primary_hero_from_overworld(overworld_state: Variant, primary_hero_id: String = "") -> Dictionary:
	if overworld_state is Dictionary:
		var player_heroes = overworld_state.get("player_heroes", [])
		if player_heroes is Array:
			for hero in player_heroes:
				if hero is Dictionary and bool(hero.get("is_primary", false)):
					return hero
			for hero in player_heroes:
				if hero is Dictionary and String(hero.get("id", "")) == primary_hero_id:
					return hero
			for hero in player_heroes:
				if hero is Dictionary:
					return hero
		var hero = overworld_state.get("hero", {})
		if hero is Dictionary:
			return hero
	return {}

static func active_hero_from_overworld(overworld_state: Variant) -> Dictionary:
	if overworld_state is Dictionary:
		var active_hero_id := String(overworld_state.get("active_hero_id", ""))
		var player_heroes = overworld_state.get("player_heroes", [])
		if player_heroes is Array:
			for hero in player_heroes:
				if hero is Dictionary and String(hero.get("id", "")) == active_hero_id:
					return hero
		var hero = overworld_state.get("hero", {})
		if hero is Dictionary:
			return hero
	return {}

static func hero_positions(session: SessionStateStoreScript.SessionData) -> Array:
	return HumanEngine.native_writing(&"HeroCommandRules.hero_positions", [session])

static func _hero_roster_line(hero: Dictionary, active_hero_id: String) -> String:
	return HumanEngine.native_writing(&"HeroCommandRules._hero_roster_line", [hero, active_hero_id])

static func _army_summary(army: Variant) -> String:
	return HumanEngine.native_writing(&"HeroCommandRules._army_summary", [army])

static func _stack_summary_from_array(stacks: Variant) -> String:
	return HumanEngine.native_writing(&"HeroCommandRules._stack_summary_from_array", [stacks])

static func _stationed_holder_ids(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Array:
	return HumanEngine.native_writing(&"HeroCommandRules._stationed_holder_ids", [session, town])

static func _append_field_transfer_actions(actions: Array, source: Dictionary, target: Dictionary) -> void:
	var source_id := String(source.get("id", ""))
	var target_id := String(target.get("id", ""))
	if source_id == "" or target_id == "":
		return
	var source_name := String(source.get("name", source_id))
	var target_name := String(target.get("name", target_id))
	for stack_value in source.get("army", {}).get("stacks", []):
		if not (stack_value is Dictionary):
			continue
		var stack: Dictionary = stack_value
		var unit_id := String(stack.get("unit_id", ""))
		var count := int(stack.get("count", 0))
		if unit_id == "" or count <= 0:
			continue
		var unit_name := String(ContentService.get_unit(unit_id).get("name", unit_id))
		var seen_transfer_counts := {}
		var admission := army_addition_plan(target.get("army", {}).get("stacks", []), {unit_id: 1})
		for amount_token_value in _transfer_amount_tokens(count):
			var amount_token := String(amount_token_value)
			var transfer_count := _resolve_transfer_amount(amount_token, count)
			if seen_transfer_counts.has(transfer_count):
				continue
			seen_transfer_counts[transfer_count] = true
			var blocker := "" if bool(admission.get("ok", false)) else String(admission.get("message", ""))
			if blocker == "" and _transfer_empties_hero_army(source_id, source.get("army", {}).get("stacks", []), transfer_count, count):
				blocker = "%s must keep at least one troop stack." % source_name
			actions.append({
				"id": "field_transfer:%s:%s:%s:%s" % [source_id, target_id, unit_id, amount_token],
				"label": "%s -> %s | %d %s" % [source_name, target_name, transfer_count, unit_name],
				"summary": "Move %s of %d %s from %s to %s; both commanders remain on this tile." % [
					_transfer_amount_label(amount_token, count),
					count,
					unit_name,
					source_name,
					target_name,
				],
				"source_hero_id": source_id,
				"target_hero_id": target_id,
				"unit_id": unit_id,
				"amount_token": amount_token,
				"transfer_count": transfer_count,
				"disabled": blocker != "",
				"disabled_reason": blocker,
			})

static func _transfer_empties_hero_army(holder_id: String, stacks: Variant, transfer_count: int, available: int, stack_leaves: bool = true) -> bool:
	return HumanEngine.native_writing(&"HeroCommandRules._transfer_empties_hero_army", [holder_id, stacks, transfer_count, available, stack_leaves])

static func _army_slot_holder_is_available(session: SessionStateStoreScript.SessionData, town: Dictionary, holder_id: String) -> bool:
	return HumanEngine.native_writing(&"HeroCommandRules._army_slot_holder_is_available", [session, town, holder_id])

static func _transfer_amount_tokens(count: int) -> Array:
	return HumanEngine.native(&"HeroCommandRules._transfer_amount_tokens", [count])

static func _transfer_amount_label(amount_token: String, available: int) -> String:
	return HumanEngine.native(&"HeroCommandRules._transfer_amount_label", [amount_token, available])

static func _resolve_transfer_amount(amount_token: String, available: int) -> int:
	return HumanEngine.native(&"HeroCommandRules._resolve_transfer_amount", [amount_token, available])

static func _holder_label(session: SessionStateStoreScript.SessionData, town: Dictionary, holder_id: String) -> String:
	return HumanEngine.native_writing(&"HeroCommandRules._holder_label", [session, town, holder_id])

static func get_town_transfer_actions(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Array:
	return HumanEngine.native_writing(&"HeroCommandRules.get_town_transfer_actions", [session, town])

static func transfer_town_stack(session: SessionStateStoreScript.SessionData, town: Dictionary, source_holder: String, target_holder: String, unit_id: String, amount_token: String) -> Dictionary:
	return HumanEngine.native_writing(&"HeroCommandRules.transfer_town_stack", [session, town, source_holder, target_holder, unit_id, amount_token])
