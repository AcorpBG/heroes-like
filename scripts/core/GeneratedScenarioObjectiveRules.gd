extends RefCounted

const PlayerRules = preload("res://scripts/core/PlayerIdentityRules.gd")
const Adventure = preload("res://scripts/core/EnemyAdventureRules.gd")
const HumanEngine = preload("res://scripts/core/HumanEngine.gd")
const KIND := "defeat_generated_rivals"

static func progress(session) -> Dictionary:
	return HumanEngine.native_writing(&"GeneratedScenarioObjectiveRules.progress", [session])
