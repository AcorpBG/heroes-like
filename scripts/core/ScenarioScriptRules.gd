class_name ScenarioScriptRules
extends RefCounted

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const ScenarioRulesScript = preload("res://scripts/core/ScenarioRules.gd")
const EnemyTurnRulesScript = preload("res://scripts/core/EnemyTurnRules.gd")
const HeroCommandRulesScript = preload("res://scripts/core/HeroCommandRules.gd")
const ArtifactRulesScript = preload("res://scripts/core/ArtifactRules.gd")
const PlayerIdentityRulesScript = preload("res://scripts/core/PlayerIdentityRules.gd")
const HumanEngine = preload("res://scripts/core/HumanEngine.gd")

const SCRIPT_STATE_KEY := "scenario_script_state"
const PENDING_REINFORCEMENTS_KEY := "pending_reinforcements"
const MAX_CHAIN_REACTIONS := 16
const EVENT_LOG_LIMIT := 24

static func build_script_state() -> Dictionary:
	return HumanEngine.native(&"ScenarioScriptRules.build_script_state", [])

static func describe_recent_events(session: SessionStateStoreScript.SessionData, limit: int = 2) -> String:
	return HumanEngine.native_writing(&"ScenarioScriptRules.describe_recent_events", [session, limit])
