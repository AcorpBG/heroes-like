class_name TownDevelopmentRules
extends RefCounted

const DATA_PATH := "res://content/town_development.json"
const Heroes = preload("res://scripts/core/HeroCommandRules.gd")
const Progression = preload("res://scripts/core/HeroProgressionRules.gd")
const Artifacts = preload("res://scripts/core/ArtifactRules.gd")
const FactionServices = preload("res://scripts/core/FactionTownServices.gd")
const HumanEngine = preload("res://scripts/core/HumanEngine.gd")

static func faction_id(town: Dictionary) -> String:
	return HumanEngine.native(&"TownDevelopmentRules.faction_id", [town])

static var _active_memo := {}
static var _satisfied_memo := {}
static var _memo_sources := []

static func objective_artifact_ids(session) -> Array:
	return HumanEngine.native_writing(&"TownDevelopmentRules.objective_artifact_ids", [session])

static func visiting_active_hero(session, town: Dictionary) -> bool:
	return HumanEngine.native_writing(&"TownDevelopmentRules.visiting_active_hero", [session, town])

static func service_actions(session, town: Dictionary) -> Array:
	return HumanEngine.native_writing(&"TownDevelopmentRules.service_actions", [session, town])

static func perform_service(session, town: Dictionary, action_id: String) -> Dictionary:
	return HumanEngine.native_writing(&"TownDevelopmentRules.perform_service", [session, town, action_id])
