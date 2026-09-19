extends RefCounted

# Original-game presentation of recovered nonvisitable bodies. This never
# invents placements or masks. Versioned appearance selection also works on reload.
const MANIFEST := "res://art/overworld/native_scenery.json"
const PRESENTATION_VERSION := 2
static var _candidate_cache: Dictionary = {}

static func asset_candidates(object: Dictionary, biome_id: String, terrain_id: String = "") -> Array:
	var version := int(object.get("native_scenery_art_version", 0))
	if version < 1: return []
	var cache_key := "%d|%s|%s|%s" % [version, object.get("h3m_type_id", -1), biome_id, terrain_id]
	if _candidate_cache.has(cache_key): return _candidate_cache[cache_key]
	var manifest := ContentService.load_json(MANIFEST)
	var entry := policy(object)
	if version >= PRESENTATION_VERSION:
		var family := String(entry.get("landscape_family", entry.get("variation_family", "")))
		if family != "":
			var terrain_pool: Array = manifest.get("terrain_component_palettes", {}).get(terrain_id, {}).get(family, [])
			if not entry.has("variation_biome") and not terrain_pool.is_empty():
				_candidate_cache[cache_key] = terrain_pool
				return terrain_pool
			var art_biome := String(entry.get("variation_biome", biome_id))
			# Production component palettes replace the old few-source clusters.
			# Every family now owns independently painted source silhouettes.
			var components: Array = manifest.get("component_palettes", {}).get(family, {}).get(art_biome, [])
			if not components.is_empty():
				_candidate_cache[cache_key] = components
				return components
			var seeds: Array = manifest.get("landscape_palettes", {}).get(family, {}).get(art_biome, [])
			var candidates: Array = entry.get("asset_ids", []).duplicate()
			var additions: Array = seeds.duplicate()
			additions.append_array(manifest.get("library_palettes", {}).get(family, {}).get(art_biome, []))
			# Harsh-biome woods intentionally use their native dead trees. Include
			# the assembled deadwood too, rather than repeating the lone master.
			for asset in seeds:
				if String(asset).begins_with("cohesive_library_") and String(asset).ends_with("_000"):
					additions.append_array(manifest.get("library_palettes", {}).get("deadwood", {}).get(art_biome, []))
					break
			for asset in additions:
				if asset not in candidates: candidates.append(asset)
			_candidate_cache[cache_key] = candidates
			return candidates
	return entry.get("asset_ids", [])

static func mountain_candidates(object: Dictionary, biome_id: String, terrain_id: String) -> Array:
	var manifest := ContentService.load_json(MANIFEST)
	var entry := policy(object)
	var art_biome := String(entry.get("variation_biome", biome_id))
	if not entry.has("variation_biome"):
		var terrain_pool: Array = manifest.get("terrain_mountain_palettes", {}).get(terrain_id, [])
		if not terrain_pool.is_empty(): return terrain_pool
	return manifest.get("mountain_palettes", {}).get(art_biome, [])

static func policy(object: Dictionary) -> Dictionary:
	return ContentService.load_json(MANIFEST).get("source_types", {}).get(str(int(object.get("h3m_type_id", -1))), {})

static func vegetation_candidates(object: Dictionary, biome_id: String, terrain_id: String, family: String = "") -> Array:
	var manifest := ContentService.load_json(MANIFEST)
	var entry := policy(object)
	if family == "": family = String(entry.get("landscape_family", entry.get("variation_family", "")))
	if not entry.has("variation_biome"):
		var terrain_pool: Array = manifest.get("terrain_vegetation_palettes", {}).get(terrain_id, {}).get(family, [])
		if not terrain_pool.is_empty(): return terrain_pool
	return manifest.get("vegetation_palettes", {}).get(family, {}).get(String(entry.get("variation_biome", biome_id)), [])

static func ground_modulate(object: Dictionary, biome_id: String, asset_id: String) -> Color:
	if int(object.get("native_scenery_art_version", 0)) < PRESENTATION_VERSION:
		return Color.WHITE
	var tones: Dictionary = ContentService.load_json(MANIFEST).get("grounding_tints", {}).get(biome_id, {})
	var entry := policy(object)
	var family := String(entry.get("landscape_family", entry.get("variation_family", "")))
	if asset_id.begins_with("plains_grove_v2_"): family = "woods"
	if asset_id.begins_with("native_vegetation_"): family = asset_id.trim_prefix("native_vegetation_").get_slice("_", 0)
	# Opaque lighting modulation ties scenery to its ground without fading
	# collision silhouettes, repainting source art or tinting interactable sites.
	return Color(String(tones.get(family, tones.get("base", "ffffff"))))

static func body_scale(object: Dictionary, asset_id: String, edge: bool = false) -> Vector2:
	var entry := policy(object)
	var family := String(entry.get("landscape_family", entry.get("variation_family", "")))
	if asset_id.begins_with("plains_grove_v2_"): family = "woods"
	var rules := ContentService.load_json("res://art/overworld/scenery_scale.json")
	var profile: Dictionary = rules.get("families", {}).get(family, {"width":1.0,"height":1.0})
	var bounds := Vector2(float(profile.get("width",1.0)), float(profile.get("height",1.0)))
	if asset_id.begins_with("biome_component_v2_"):
		var cell := int(asset_id.get_slice("_", asset_id.get_slice_count("_") - 1))
		if cell in rules.get(family + "_low_cells", []):
			var low: Dictionary = rules.low_limits
			bounds = bounds.min(Vector2(float(low.width),float(low.height)))
	if edge:
		bounds = bounds.min(Vector2(float(profile.get("edge_width",bounds.x)),float(profile.get("edge_height",bounds.y))))
	return bounds

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
		for biome_id in ContentService.load_json(MANIFEST).get("landscape_palettes", {}).get("rock", {}):
			candidates.append_array(asset_candidates(object, biome_id))
		for asset_id in candidates:
			var path := String(assets.get(asset_id, {}).get("path", ""))
			if path == "" or not ResourceLoader.exists(path):
				return {"ok": false, "error": "native_scenery_raster_missing", "asset_id": asset_id}
	return {"ok": true}
