extends RefCounted

# Original-game presentation of recovered nonvisitable bodies. This never
# invents placements or masks, and is only applied while starting a new session.
const MANIFEST := "res://art/overworld/native_scenery.json"
const PRESENTATION_VERSION := 2

static func asset_candidates(object: Dictionary, biome_id: String) -> Array:
	var version := int(object.get("native_scenery_art_version", 0))
	if version < 1: return []
	var manifest := ContentService.load_json(MANIFEST)
	var entry := policy(object)
	if version >= PRESENTATION_VERSION and entry.has("landscape_family"):
		return manifest.get("landscape_palettes", {}).get(String(entry.landscape_family), {}).get(biome_id, [])
	return entry.get("asset_ids", [])

static func policy(object: Dictionary) -> Dictionary:
	return ContentService.load_json(MANIFEST).get("source_types", {}).get(str(int(object.get("h3m_type_id", -1))), {})

static func is_scenery(object: Dictionary) -> bool:
	return not policy(object).is_empty()

static func validate(objects: Array) -> Dictionary:
	var checked := {}
	var assets: Dictionary = ContentService.load_json("res://art/overworld/manifest.json").get("object_assets", {})
	for object in objects:
		var type_id := int(object.get("h3m_type_id", -1))
		if type_id < 0: continue
		var entry := policy(object)
		var kind := String(object.get("kind", ""))
		if entry.is_empty():
			if kind == "decorative_obstacle" or (kind == "h3m_object" and object.get("package_visit_tiles", []).is_empty()):
				return {"ok": false, "error": "native_scenery_type_unmapped", "type_id": type_id}
			continue
		if not object.get("package_visit_tiles", []).is_empty():
			return {"ok": false, "error": "native_scenery_unexpected_interaction", "type_id": type_id}
		if checked.has(type_id): continue
		checked[type_id] = true
		var candidates: Array = entry.get("asset_ids", []).duplicate()
		var family := String(entry.get("landscape_family", ""))
		if family != "":
			var palettes: Dictionary = ContentService.load_json(MANIFEST).get("landscape_palettes", {}).get(family, {})
			if palettes.size() != 9:
				return {"ok":false,"error":"native_scenery_biome_palette_missing","family":family}
			for biome_id in palettes:
				if palettes[biome_id].is_empty():return {"ok":false,"error":"native_scenery_biome_palette_empty","family":family,"biome_id":biome_id}
				candidates.append_array(palettes[biome_id])
		elif candidates.is_empty():
			return {"ok":false,"error":"native_scenery_semantic_art_missing","type_id":type_id}
		for asset_id in candidates:
			var path := String(assets.get(asset_id, {}).get("path", ""))
			if path == "" or not ResourceLoader.exists(path):
				return {"ok": false, "error": "native_scenery_raster_missing", "asset_id": asset_id}
	return {"ok": true}
