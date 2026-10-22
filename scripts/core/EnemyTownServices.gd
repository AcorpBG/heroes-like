extends RefCounted

const Development = preload("res://scripts/core/TownDevelopmentRules.gd")
const Artifacts = preload("res://scripts/core/ArtifactRules.gd")
const Levels = preload("res://scripts/core/OverworldLevelRules.gd")
const Players = preload("res://scripts/core/PlayerIdentityRules.gd")
const TurnEngine = preload("res://scripts/core/TurnEngine.gd")
## AI weights (content/ai_hero_weights.json): a hero in its own town spends at
## most TOWN_SPEND_SHARE of the gold above GOLD_RESERVE on upgrades and on an
## artifact, buys one only for a loadout gain of MIN_PURCHASE_GAIN or more, and
## scores loadouts with the LOADOUT_ values. AiHeroRules puts a computer
## player's set in place (apply_ai_weights, which passes it on to the faction
## services' useful_to_ai); until it does, the default set.
static var GOLD_RESERVE: int
static var TOWN_SPEND_SHARE: float
static var MIN_PURCHASE_GAIN: float
static var LOADOUT_VALUES: Dictionary = {}
static var LOADOUT_GOLD_INCOME_VALUE: float
static var LOADOUT_INCOME_VALUE: float
static var LOADOUT_SCHOOL_RESISTANCE_VALUE: float
static var LOADOUT_SPELL_EFFECT_VALUE: float
static var LOADOUT_MANA_COST_VALUE: float
static var _ai_weights_ready := false

static func visit(town: Dictionary, raid: Dictionary, treasury: Dictionary, day: int, controller: String) -> Dictionary:
	return TurnEngine.native_writing(&"EnemyTownServices.visit", [town, raid, treasury, day, controller])
