extends RefCounted
## What an overworld action gave the player, for the floating gain text above
## the hero (OverworldGainFloaters). The shell takes a snapshot before an
## action and compares it with the state after, so every source counts
## (pickups, chests, mines, dwellings, visit buildings, reward choices, hires)
## without each rule reporting it. Read-only; presentation only.

const OverworldRulesScript = preload("res://scripts/core/OverworldRules.gd")
const ArtifactRulesScript = preload("res://scripts/core/ArtifactRules.gd")
const SpellRulesScript = preload("res://scripts/core/SpellRules.gd")
const HumanEngine = preload("res://scripts/core/HumanEngine.gd")

const STAT_NAMES := {"attack": "Attack", "defense": "Defense", "power": "Spell power", "knowledge": "Knowledge"}
const BOOST_NAMES := {"cohesion": "Cohesion", "momentum": "Momentum"}

## The parts of the session an overworld gain can change.
static func snapshot(session) -> Dictionary:
	return HumanEngine.native_writing(&"OverworldGainFeed.snapshot", [session])

## One line per gain, in the order they float: sites claimed, artifacts,
## resources gained, troops, command, spells, experience, mana, movement,
## battle boosts, then resources spent. Each line is {text, icon, tone}.
## `movement_walked` is the movement the action's walk spent, so a stable at
## the end of a route shows what it restored rather than the net change.
static func gains(before: Dictionary, after: Dictionary, movement_walked: int = 0) -> Array:
	return HumanEngine.native_writing(&"OverworldGainFeed.gains", [before, after, movement_walked])
