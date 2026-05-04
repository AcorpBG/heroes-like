extends Node

const REPORT_ID := "OVERWORLD_MAP_OBJECT_SPRITE_ASSET_REPORT"
const REPORT_SCHEMA_ID := "overworld_map_object_sprite_asset_report_v1"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var summary := _static_manifest_summary()
	if summary.is_empty():
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"schema_id": REPORT_SCHEMA_ID,
		"ok": true,
		"static_manifest": summary,
		"asset_policy": "original_generated_distinct_sprites_no_homm3_art_or_def_import",
	})])
	get_tree().quit(0)

func _static_manifest_summary() -> Dictionary:
	var art_manifest: Dictionary = ContentService.load_json("res://art/overworld/manifest.json")
	var object_assets: Dictionary = art_manifest.get("object_assets", {}) if art_manifest.get("object_assets", {}) is Dictionary else {}
	var map_object_manifest: Dictionary = ContentService.load_json("res://art/overworld/map_object_sprites.json")
	var distinct_asset_ids: Array = map_object_manifest.get("distinct_asset_ids", []) if map_object_manifest.get("distinct_asset_ids", []) is Array else []
	var mappings: Dictionary = map_object_manifest.get("object_sprite_mappings", {}) if map_object_manifest.get("object_sprite_mappings", {}) is Dictionary else {}
	var coverage: Dictionary = map_object_manifest.get("coverage", {}) if map_object_manifest.get("coverage", {}) is Dictionary else {}
	var map_objects: Dictionary = ContentService.load_json("res://content/map_objects.json")
	var items: Array = map_objects.get("items", []) if map_objects.get("items", []) is Array else []
	var decorative_count := 0
	var non_decorative_count := 0
	var mapped_asset_ids := {}
	for item_value in items:
		if not (item_value is Dictionary):
			continue
		var item: Dictionary = item_value
		var family := String(item.get("family", ""))
		if String(item.get("primary_class", "")) == "decoration" or family in ["blocker", "decoration"]:
			decorative_count += 1
		else:
			non_decorative_count += 1
	if decorative_count != 200 or non_decorative_count != 186:
		_fail("Unexpected authored map object split: decorative=%d non_decorative=%d." % [decorative_count, non_decorative_count])
		return {}
	if distinct_asset_ids.size() != 178 or mappings.size() != 178:
		_fail("Map object sprite manifest must map 178 gap objects to 178 distinct assets, found distinct=%d mapped=%d." % [distinct_asset_ids.size(), mappings.size()])
		return {}
	if int(coverage.get("total_distinct_authored_map_object_count_after_pass", 0)) != 386:
		_fail("Map object sprite coverage does not prove all 386 authored map objects after the pass: %s" % JSON.stringify(coverage))
		return {}
	for object_id_value in mappings.keys():
		var object_id := String(object_id_value)
		var mapping: Dictionary = mappings.get(object_id, {}) if mappings.get(object_id, {}) is Dictionary else {}
		var asset_id := String(mapping.get("asset_id", ""))
		if asset_id == "":
			_fail("Map object sprite mapping has an empty asset id for %s." % object_id)
			return {}
		if mapped_asset_ids.has(asset_id):
			_fail("Map object sprite mapping reused asset id %s for %s and %s." % [asset_id, mapped_asset_ids[asset_id], object_id])
			return {}
		mapped_asset_ids[asset_id] = object_id
	for asset_id_value in distinct_asset_ids:
		var asset_id := String(asset_id_value)
		if not mapped_asset_ids.has(asset_id):
			_fail("Map object distinct asset is not used by a mapping: %s" % asset_id)
			return {}
		var entry: Dictionary = object_assets.get(asset_id, {}) if object_assets.get(asset_id, {}) is Dictionary else {}
		if entry.is_empty():
			_fail("Map object distinct asset is missing from object_assets: %s" % asset_id)
			return {}
		var path := String(entry.get("path", ""))
		if not ResourceLoader.exists(path):
			_fail("Map object distinct runtime texture is not importable: %s -> %s" % [asset_id, path])
			return {}
		if _texture_has_visible_outer_alpha(path, 3):
			_fail("Map object distinct runtime texture has visible crop-border alpha: %s -> %s" % [asset_id, path])
			return {}
	return {
		"authored_map_object_count": items.size(),
		"decorative_or_blocker_foundation_count": decorative_count,
		"non_decorative_object_count": non_decorative_count,
		"new_distinct_asset_count": distinct_asset_ids.size(),
		"mapped_object_count": mappings.size(),
		"total_distinct_authored_map_object_count_after_pass": int(coverage.get("total_distinct_authored_map_object_count_after_pass", 0)),
	}

func _texture_has_visible_outer_alpha(path: String, border_px: int) -> bool:
	var image := Image.new()
	var error := image.load(ProjectSettings.globalize_path(path))
	if error != OK:
		_fail("Could not load map object runtime texture for alpha-border audit: %s" % path)
		return true
	var width := image.get_width()
	var height := image.get_height()
	for y in range(height):
		for x in range(border_px):
			if image.get_pixel(x, y).a > 0.03 or image.get_pixel(width - 1 - x, y).a > 0.03:
				return true
	for x in range(width):
		for y in range(border_px):
			if image.get_pixel(x, y).a > 0.03 or image.get_pixel(x, height - 1 - y).a > 0.03:
				return true
	return false

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
