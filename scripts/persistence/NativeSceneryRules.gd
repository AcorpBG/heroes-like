extends RefCounted

# Original-game presentation of recovered nonvisitable bodies. This never
# invents placements or masks, and is only applied while starting a new session.
const MANIFEST := "res://art/overworld/native_scenery.json"

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
		for asset_id in entry.get("asset_ids", []):
			var path := String(assets.get(asset_id, {}).get("path", ""))
			if path == "" or not ResourceLoader.exists(path):
				return {"ok": false, "error": "native_scenery_raster_missing", "asset_id": asset_id}
	return {"ok": true}
