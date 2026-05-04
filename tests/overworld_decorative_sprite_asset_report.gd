extends Node

const NativeRandomMapPackageSessionBridgeScript = preload("res://scripts/persistence/NativeRandomMapPackageSessionBridge.gd")
const OverworldMapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")

const REPORT_ID := "OVERWORLD_DECORATIVE_SPRITE_ASSET_REPORT"
const REPORT_SCHEMA_ID := "overworld_decorative_sprite_asset_report_v1"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var static_summary := _static_manifest_summary()
	if static_summary.is_empty():
		return
	var runtime_summary: Dictionary = await _native_runtime_presentation_summary(static_summary)
	if runtime_summary.is_empty():
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"schema_id": REPORT_SCHEMA_ID,
		"ok": true,
		"static_manifest": static_summary,
		"runtime_presentation": runtime_summary,
		"asset_policy": "original_generated_distinct_sprites_no_homm3_art_or_def_import",
	})])
	get_tree().quit(0)

func _static_manifest_summary() -> Dictionary:
	var art_manifest: Dictionary = ContentService.load_json("res://art/overworld/manifest.json")
	var object_assets: Dictionary = art_manifest.get("object_assets", {}) if art_manifest.get("object_assets", {}) is Dictionary else {}
	var decorative_manifest: Dictionary = ContentService.load_json("res://art/overworld/decorative_object_sprites.json")
	var distinct_asset_ids: Array = decorative_manifest.get("distinct_asset_ids", []) if decorative_manifest.get("distinct_asset_ids", []) is Array else []
	var legacy_archetypes: Array = decorative_manifest.get("legacy_archetype_asset_ids", []) if decorative_manifest.get("legacy_archetype_asset_ids", []) is Array else []
	var mappings: Dictionary = decorative_manifest.get("object_sprite_mappings", {}) if decorative_manifest.get("object_sprite_mappings", {}) is Dictionary else {}
	var map_objects: Dictionary = ContentService.load_json("res://content/map_objects.json")
	var items: Array = map_objects.get("items", []) if map_objects.get("items", []) is Array else []
	var decorative_object_count := 0
	var missing_mappings := []
	var mapped_asset_ids := {}
	for item_value in items:
		if not (item_value is Dictionary):
			continue
		var item: Dictionary = item_value
		var object_id := String(item.get("id", ""))
		var is_decorative := String(item.get("primary_class", "")) == "decoration" or String(item.get("family", "")) in ["blocker", "decoration"]
		if not is_decorative:
			continue
		decorative_object_count += 1
		if not mappings.has(object_id):
			missing_mappings.append(object_id)
			continue
		var mapping: Dictionary = mappings.get(object_id, {}) if mappings.get(object_id, {}) is Dictionary else {}
		var mapped_asset_id := String(mapping.get("asset_id", ""))
		if mapped_asset_id == "":
			_fail("Decorative sprite mapping has an empty asset id for %s." % object_id)
			return {}
		if mapped_asset_ids.has(mapped_asset_id):
			_fail("Decorative sprite mapping reused asset id %s for %s and %s." % [mapped_asset_id, mapped_asset_ids[mapped_asset_id], object_id])
			return {}
		mapped_asset_ids[mapped_asset_id] = object_id
	if decorative_object_count != 200:
		_fail("Expected 200 authored decorative/blocker objects, found %d." % decorative_object_count)
		return {}
	if not missing_mappings.is_empty():
		_fail("Decorative sprite manifest missed mappings: %s" % JSON.stringify(missing_mappings))
		return {}
	if legacy_archetypes.size() != 16:
		_fail("Decorative sprite manifest must preserve 16 representative generated assets, found %d." % legacy_archetypes.size())
		return {}
	if distinct_asset_ids.size() != 200 or mapped_asset_ids.size() != 200:
		_fail("Decorative sprite manifest must map 200 objects to 200 distinct asset ids, found distinct=%d mapped=%d." % [distinct_asset_ids.size(), mapped_asset_ids.size()])
		return {}
	for asset_id_value in distinct_asset_ids:
		var asset_id := String(asset_id_value)
		if not mapped_asset_ids.has(asset_id):
			_fail("Decorative distinct asset is not used by a mapping: %s" % asset_id)
			return {}
		var entry: Dictionary = object_assets.get(asset_id, {}) if object_assets.get(asset_id, {}) is Dictionary else {}
		if entry.is_empty():
			_fail("Decorative distinct asset is missing from object_assets: %s" % asset_id)
			return {}
		var path := String(entry.get("path", ""))
		if not ResourceLoader.exists(path):
			_fail("Decorative distinct runtime texture is not importable: %s -> %s" % [asset_id, path])
			return {}
		if _texture_has_visible_outer_alpha(path, 3):
			_fail("Decorative distinct runtime texture has visible crop-border alpha: %s -> %s" % [asset_id, path])
			return {}
	return {
		"authored_decorative_or_blocker_object_count": decorative_object_count,
		"mapped_object_count": mappings.size(),
		"distinct_asset_count": distinct_asset_ids.size(),
		"legacy_archetype_asset_count": legacy_archetypes.size(),
	}

func _texture_has_visible_outer_alpha(path: String, border_px: int) -> bool:
	var image := Image.new()
	var error := image.load(ProjectSettings.globalize_path(path))
	if error != OK:
		_fail("Could not load decorative runtime texture for alpha-border audit: %s" % path)
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

func _native_runtime_presentation_summary(static_summary: Dictionary) -> Dictionary:
	if not ClassDB.class_exists("MapPackageService"):
		_fail("MapPackageService native class is not available.")
		return {}
	var service: Variant = ClassDB.instantiate("MapPackageService")
	var metadata: Dictionary = service.get_api_metadata()
	if String(metadata.get("binding_kind", "")) != "native_gdextension" or not bool(metadata.get("native_extension_loaded", false)):
		_fail("Native GDExtension metadata did not prove native load: %s" % JSON.stringify(metadata))
		return {}
	var config := ScenarioSelectRulesScript.build_random_map_player_config(
		"decorative-sprite-asset-report-10184",
		"border_gate_compact_v1",
		"border_gate_compact_profile_v1",
		3,
		"land",
		false,
		"homm3_small"
	)
	var generated: Dictionary = service.generate_random_map(config)
	if not bool(generated.get("ok", false)):
		_fail("Native generation failed: %s" % JSON.stringify(generated))
		return {}
	var adoption: Dictionary = service.convert_generated_payload(generated, {
		"feature_gate": "overworld_decorative_sprite_asset_report",
		"session_save_version": 9,
		"scenario_id": "decorative_sprite_asset_report_10184",
	})
	if not bool(adoption.get("ok", false)):
		_fail("Native adoption failed: %s" % JSON.stringify(adoption))
		return {}
	var session: Variant = NativeRandomMapPackageSessionBridgeScript.build_session_from_adoption(adoption, "normal", {})
	OverworldRules.normalize_overworld_state(session)
	var map_size := OverworldRules.derive_map_size(session)
	session.overworld["fog"] = _all_visible_fog(map_size.x, map_size.y)
	var map_objects: Array = session.overworld.get("map_objects", []) if session.overworld.get("map_objects", []) is Array else []
	if map_objects.is_empty():
		_fail("Bridge did not expose decorative map_objects in overworld state.")
		return {}
	var art_manifest: Dictionary = ContentService.load_json("res://art/overworld/manifest.json")
	var object_assets: Dictionary = art_manifest.get("object_assets", {}) if art_manifest.get("object_assets", {}) is Dictionary else {}
	var decorative_manifest: Dictionary = ContentService.load_json("res://art/overworld/decorative_object_sprites.json")
	var mappings: Dictionary = decorative_manifest.get("object_sprite_mappings", {}) if decorative_manifest.get("object_sprite_mappings", {}) is Dictionary else {}
	var target_object: Dictionary = {}
	var target_asset_id := ""
	var town_tiles := _town_tile_keys(session)
	for object_value in map_objects:
		if not (object_value is Dictionary):
			continue
		var object: Dictionary = object_value
		var object_tile := Vector2i(int(object.get("x", -1)), int(object.get("y", -1)))
		if town_tiles.has(_tile_key(object_tile)):
			continue
		var object_id := String(object.get("object_id", ""))
		var mapping: Dictionary = mappings.get(object_id, {}) if mappings.get(object_id, {}) is Dictionary else {}
		var asset_id := String(mapping.get("asset_id", ""))
		if asset_id == "" or not object_assets.has(asset_id):
			continue
		target_object = object
		target_asset_id = asset_id
		break
	if target_object.is_empty():
		_fail("Generated decorative objects did not resolve through the decorative sprite mapping.")
		return {}
	var view: Variant = OverworldMapViewScript.new()
	view.size = Vector2(960, 640)
	add_child(view)
	var target_tile := Vector2i(int(target_object.get("x", -1)), int(target_object.get("y", -1)))
	view.set_map_state(session, session.overworld.get("map", []), map_size, target_tile)
	await get_tree().process_frame
	var presentation: Dictionary = view.validation_tile_presentation(target_tile)
	remove_child(view)
	view.queue_free()
	var art: Dictionary = presentation.get("art_presentation", {}) if presentation.get("art_presentation", {}) is Dictionary else {}
	var sprite_asset_ids: Array = art.get("sprite_asset_ids", []) if art.get("sprite_asset_ids", []) is Array else []
	if not bool(presentation.get("has_decorative_object", false)):
		_fail("OverworldMapView did not index the generated decorative object: %s" % JSON.stringify(presentation))
		return {}
	if not bool(art.get("uses_asset_sprite", false)) or bool(art.get("fallback_procedural_marker", false)):
		_fail("Decorative object presentation did not use an asset sprite: %s" % JSON.stringify(art))
		return {}
	if target_asset_id not in sprite_asset_ids:
		_fail("Decorative object presentation used the wrong asset ids: expected=%s actual=%s" % [target_asset_id, JSON.stringify(sprite_asset_ids)])
		return {}
	return {
		"binding_kind": metadata.get("binding_kind", ""),
		"native_extension_loaded": metadata.get("native_extension_loaded", false),
		"generated_decoration_count": map_objects.size(),
		"mapped_static_object_count": int(static_summary.get("mapped_object_count", 0)),
		"distinct_static_asset_count": int(static_summary.get("distinct_asset_count", 0)),
		"sample_object_id": String(target_object.get("object_id", "")),
		"sample_placement_id": String(target_object.get("placement_id", "")),
		"sample_tile": {"x": target_tile.x, "y": target_tile.y},
		"sample_asset_id": target_asset_id,
		"presentation": {
			"has_decorative_object": bool(presentation.get("has_decorative_object", false)),
			"uses_asset_sprite": bool(art.get("uses_asset_sprite", false)),
			"fallback_procedural_marker": bool(art.get("fallback_procedural_marker", false)),
			"sprite_asset_ids": sprite_asset_ids,
		},
	}

func _all_visible_fog(width: int, height: int) -> Dictionary:
	var visible := []
	var explored := []
	for _y in range(height):
		var visible_row := []
		var explored_row := []
		for _x in range(width):
			visible_row.append(true)
			explored_row.append(true)
		visible.append(visible_row)
		explored.append(explored_row)
	return {
		"visible_tiles": visible,
		"explored_tiles": explored,
		"visible_count": width * height,
		"explored_count": width * height,
		"total_tiles": width * height,
	}

func _town_tile_keys(session: Variant) -> Dictionary:
	var keys := {}
	var towns: Array = session.overworld.get("towns", []) if session.overworld.get("towns", []) is Array else []
	for town_value in towns:
		if town_value is Dictionary:
			keys[_tile_key(Vector2i(int(town_value.get("x", -1)), int(town_value.get("y", -1))))] = true
	return keys

func _tile_key(tile: Vector2i) -> String:
	return "%d,%d" % [tile.x, tile.y]

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
