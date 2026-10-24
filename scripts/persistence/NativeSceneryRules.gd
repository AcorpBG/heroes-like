extends RefCounted

const HumanEngine = preload("res://scripts/core/HumanEngine.gd")
static var _human_engine_mode: int = HumanEngine.mode

# Original-game presentation of recovered nonvisitable bodies. This never
# invents placements or masks. Versioned appearance selection also works on reload.
const MANIFEST := "res://art/overworld/native_scenery.json"
const PRESENTATION_VERSION := 2
static var _candidate_cache: Dictionary = {}
# The map view draws through the native policy and art candidates, memoized by
# what they read: the object's type and art version, the biome and the terrain
# (the manifest stays the same while the game runs).
static var _drawn_policies: Dictionary = {}
static var _drawn_candidates: Dictionary = {}

static func drawn_policy(object: Dictionary) -> Dictionary:
	var type_id: Variant = object.get("h3m_type_id", -1)
	if not _drawn_policies.has(type_id):
		_drawn_policies[type_id] = policy(object)
	return _drawn_policies[type_id]

static func drawn_asset_candidates(object: Dictionary, biome_id: String, terrain_id: String = "") -> Array:
	var memo_key := [object.get("native_scenery_art_version", 0), object.get("h3m_type_id", -1), biome_id, terrain_id]
	if not _drawn_candidates.has(memo_key):
		_drawn_candidates[memo_key] = asset_candidates(object, biome_id, terrain_id)
	return _drawn_candidates[memo_key]

static func asset_candidates(object: Dictionary, biome_id: String, terrain_id: String = "") -> Array:
	if _human_engine_mode == HumanEngine.GDSCRIPT:
		return asset_candidates__gd(object, biome_id, terrain_id)
	if _human_engine_mode == HumanEngine.NATIVE:
		return HumanEngine.native_writing(&"NativeSceneryRules.asset_candidates", [object, biome_id, terrain_id])
	var before := HumanEngine.before_writing(&"NativeSceneryRules.asset_candidates", [object, biome_id, terrain_id])
	var result = asset_candidates__gd(object, biome_id, terrain_id)
	HumanEngine.check_writing(&"NativeSceneryRules.asset_candidates", before, [object, biome_id, terrain_id], result)
	return result

static func asset_candidates__gd(object: Dictionary, biome_id: String, terrain_id: String = "") -> Array:
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
	var entry := drawn_policy(object)
	var art_biome := String(entry.get("variation_biome", biome_id))
	if not entry.has("variation_biome"):
		var terrain_pool: Array = manifest.get("terrain_mountain_palettes", {}).get(terrain_id, [])
		if not terrain_pool.is_empty(): return terrain_pool
	return manifest.get("mountain_palettes", {}).get(art_biome, [])

static func policy(object: Dictionary) -> Dictionary:
	if _human_engine_mode == HumanEngine.GDSCRIPT:
		return policy__gd(object)
	if _human_engine_mode == HumanEngine.NATIVE:
		return HumanEngine.native(&"NativeSceneryRules.policy", [object])
	var result = policy__gd(object)
	HumanEngine.check(&"NativeSceneryRules.policy", [object], result)
	return result

static func policy__gd(object: Dictionary) -> Dictionary:
	return ContentService.load_json(MANIFEST).get("source_types", {}).get(str(int(object.get("h3m_type_id", -1))), {})

static func vegetation_candidates(object: Dictionary, biome_id: String, terrain_id: String, family: String = "") -> Array:
	var manifest := ContentService.load_json(MANIFEST)
	var entry := drawn_policy(object)
	if family == "": family = String(entry.get("landscape_family", entry.get("variation_family", "")))
	if not entry.has("variation_biome"):
		var terrain_pool: Array = manifest.get("terrain_vegetation_palettes", {}).get(terrain_id, {}).get(family, [])
		if not terrain_pool.is_empty(): return terrain_pool
	return manifest.get("vegetation_palettes", {}).get(family, {}).get(String(entry.get("variation_biome", biome_id)), [])

static func ground_modulate(object: Dictionary, biome_id: String, asset_id: String) -> Color:
	if int(object.get("native_scenery_art_version", 0)) < PRESENTATION_VERSION:
		return Color.WHITE
	var tones: Dictionary = ContentService.load_json(MANIFEST).get("grounding_tints", {}).get(biome_id, {})
	var entry := drawn_policy(object)
	var family := String(entry.get("landscape_family", entry.get("variation_family", "")))
	if asset_id.begins_with("plains_grove_v2_"): family = "woods"
	if asset_id.begins_with("native_vegetation_"): family = asset_id.trim_prefix("native_vegetation_").get_slice("_", 0)
	# Opaque lighting modulation ties scenery to its ground without fading
	# collision silhouettes, repainting source art or tinting interactable sites.
	return Color(String(tones.get(family, tones.get("base", "ffffff"))))

static func body_scale(object: Dictionary, asset_id: String, edge: bool = false, terrain_id: String = "") -> Vector2:
	var entry := drawn_policy(object)
	var family := String(entry.get("landscape_family", entry.get("variation_family", "")))
	if asset_id.begins_with("plains_grove_v2_"): family = "woods"
	var rules := ContentService.load_json("res://art/overworld/scenery_scale.json")
	var profile: Dictionary = rules.get("families", {}).get(family, {"width":1.0,"height":1.0})
	var bounds := Vector2(float(profile.get("width",1.0)), float(profile.get("height",1.0)))
	var terrain_limits: Dictionary = rules.get("terrain_height_limits",{}).get(terrain_id,{})
	if terrain_limits.has(family): bounds.y=minf(bounds.y,float(terrain_limits[family]))
	if asset_id.begins_with("biome_component_v2_"):
		var cell := int(asset_id.get_slice("_", asset_id.get_slice_count("_") - 1))
		if cell in rules.get(family + "_low_cells", []):
			var low: Dictionary = rules.low_limits
			bounds = bounds.min(Vector2(float(low.width),float(low.height)))
	if edge:
		bounds = bounds.min(Vector2(float(profile.get("edge_width",bounds.x)),float(profile.get("edge_height",bounds.y))))
	return bounds
