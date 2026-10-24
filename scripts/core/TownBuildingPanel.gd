class_name TownBuildingPanel
extends RefCounted

## Read-only model for the popout opened by clicking a built Town building.
## Every building shows its description, effects and upgrade line (from
## TownConstructionBoard). Dwellings add recruitment and troop upgrades, the
## magic guild its spell shelves by level, the tavern its hireable heroes, the
## market its trading desk, and service buildings their visit and artifact
## orders. The popout is the only market and magic guild window. Never mutates
## session state; TownShell owns every order.

const SCHEMA := "town_building_panel_v1"
const TownRulesScript = preload("res://scripts/core/TownRules.gd")
const OverworldRulesScript = preload("res://scripts/core/OverworldRules.gd")
const HeroCommandRulesScript = preload("res://scripts/core/HeroCommandRules.gd")
const HeroProgressionRulesScript = preload("res://scripts/core/HeroProgressionRules.gd")
const SpellRulesScript = preload("res://scripts/core/SpellRules.gd")
const Board = preload("res://scripts/core/TownConstructionBoard.gd")
const HumanEngine = preload("res://scripts/core/HumanEngine.gd")

const KIND_DWELLING := "dwelling"
const KIND_GUILD := "guild"
const KIND_TAVERN := "tavern"
const KIND_MARKET := "market"
const KIND_ARTIFACTS := "artifact_exchange"
const KIND_TRAINING := "training"
const KIND_BUILDING := "building"

## `options.market_need` is a cost the player opened the market to cover; the
## market desk then suggests the trade for its first missing resource.
static func build(session, building_id: String, options: Dictionary = {}) -> Dictionary:
	return HumanEngine.native_writing(&"TownBuildingPanel.build", [session, building_id, options])

## The built market building whose popout trades for this town (its highest
## stage), or "" without a market.
static func market_building_id(town: Dictionary) -> String:
	return String(OverworldRulesScript.town_market_state(town).get("building_id", "")) if not town.is_empty() else ""

## The built magic guild stage whose popout shows this town's spells, or "".
static func guild_building_id(town: Dictionary) -> String:
	var best_id := ""
	var best_tier := 0
	for building_id_value in town.get("built_buildings", []):
		var building := ContentService.get_building(String(building_id_value))
		if int(building.get("spell_tier", 0)) > best_tier:
			best_tier = int(building.get("spell_tier", 0))
			best_id = String(building_id_value)
	return best_id

## Every creature the town can muster, as the same recruit cards the dwelling
## popouts show, with all stationed-troop upgrades. Read-only.
static func muster(session) -> Dictionary:
	if session == null:
		return {}
	var town: Dictionary = TownRulesScript.get_active_town(session)
	if town.is_empty():
		return {}
	var units := []
	for row_value in TownRulesScript.get_muster_catalog(session):
		if row_value is Dictionary:
			units.append(recruit_card(row_value))
	var troop_upgrades := []
	for action in TownRulesScript.get_response_actions(session):
		if String(action.get("id", "")).begins_with("town_upgrade:"):
			troop_upgrades.append(_action_entry(action))
	var resources: Dictionary = session.overworld.get("resources", {}) if session.overworld.get("resources", {}) is Dictionary else {}
	return {
		"schema": SCHEMA,
		"kind": "muster",
		"units": units,
		"destination": String(HeroCommandRulesScript.town_recruitment_destination(session, town).get("summary", "")),
		"troop_upgrades": troop_upgrades,
		"resources": resources.duplicate(true),
	}

## One muster catalog row as a recruit card: the creature's battle profile
## plus reserve, growth, price and what the stores can pay for now.
static func recruit_card(row: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"TownBuildingPanel.recruit_card", [row])

static func _action_entry(action: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"TownBuildingPanel._action_entry", [action])
