extends RefCounted
## Presentation-only terrain skins. Identity selection remains with the town
## manifest; this helper never touches a session, placement, owner or RNG.

const HumanEngine = preload("res://scripts/core/HumanEngine.gd")

static func resolve(base_asset_id: String, terrain: String, skins: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"TownBiomeArtRules.resolve", [base_asset_id, terrain, skins])
