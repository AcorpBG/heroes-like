extends RefCounted
## Presentation-only terrain skins. Identity selection remains with the town
## manifest; this helper never touches a session, placement, owner or RNG.

static func resolve(base_asset_id: String, terrain: String, skins: Dictionary) -> Dictionary:
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
