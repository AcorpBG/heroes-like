extends RefCounted
## Presentation-only terrain skins. Identity selection remains with the town
## manifest; this helper never touches a session, placement, owner or RNG.

const HumanEngine = preload("res://scripts/core/HumanEngine.gd")
static var _human_engine_mode: int = HumanEngine.mode

static func resolve(base_asset_id: String, terrain: String, skins: Dictionary) -> Dictionary:
	if _human_engine_mode == HumanEngine.GDSCRIPT:
		return resolve__gd(base_asset_id, terrain, skins)
	if _human_engine_mode == HumanEngine.NATIVE:
		return HumanEngine.native_writing(&"TownBiomeArtRules.resolve", [base_asset_id, terrain, skins])
	var before := HumanEngine.before_writing(&"TownBiomeArtRules.resolve", [base_asset_id, terrain, skins])
	var result = resolve__gd(base_asset_id, terrain, skins)
	HumanEngine.check_writing(&"TownBiomeArtRules.resolve", before, [base_asset_id, terrain, skins], result)
	return result

static func resolve__gd(base_asset_id: String, terrain: String, skins: Dictionary) -> Dictionary:
	var aliases: Dictionary = skins.get("terrain_aliases", {})
	var biome := String(aliases.get(terrain, ""))
	var entries: Dictionary = skins.get("appearances", {})
	var entry: Dictionary = entries.get(base_asset_id, {})
	var variants: Dictionary = entry.get("biome_asset_ids", {})
	var selected := String(variants.get(biome, base_asset_id))
	return {
		"base_asset_id": base_asset_id,
		"render_asset_id": selected,
		"terrain": terrain,
		"biome_id": biome,
		"uses_biome_variant": selected != base_asset_id,
	}
