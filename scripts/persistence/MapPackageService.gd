extends RefCounted

const MapDocumentScript = preload("res://scripts/persistence/MapDocument.gd")
const ScenarioDocumentScript = preload("res://scripts/persistence/ScenarioDocument.gd")

const API_ID := "aurelion_map_package_api"
const API_VERSION := "0.1.0"
const PACKAGE_SCHEMA_VERSION := 1
const MAP_SCHEMA_ID := "aurelion_map_document"
const SCENARIO_SCHEMA_ID := "aurelion_scenario_document"
const MAP_PACKAGE_EXTENSION := ".amap"
const SCENARIO_PACKAGE_EXTENSION := ".ascenario"
const BINDING_KIND := "gdscript_compatibility_shim"

const CAPABILITIES := [
	"api_metadata",
	"typed_map_document_stub",
	"typed_scenario_document_stub",
	"stable_not_implemented_errors",
	"native_random_map_config_identity",
	"native_random_map_foundation_stub",
	"native_random_map_terrain_grid_foundation",
	"headless_binding_smoke",
]

const CORE_TERRAIN_POOL := ["grass", "snow", "sand", "dirt", "rough", "lava", "underground"]
const DEFAULT_FACTIONS := ["faction_embercourt", "faction_mireclaw", "faction_sunvault", "faction_thornwake"]
const TERRAIN_ID_BY_CODE := ["grass", "snow", "sand", "dirt", "rough", "lava", "underground", "water"]

func get_api_version() -> String:
	return API_VERSION

func get_api_metadata() -> Dictionary:
	return {
		"ok": true,
		"api_id": API_ID,
		"api_version": API_VERSION,
		"binding_kind": BINDING_KIND,
		"native_extension_loaded": false,
		"map_schema_id": MAP_SCHEMA_ID,
		"scenario_schema_id": SCENARIO_SCHEMA_ID,
		"package_schema_version": PACKAGE_SCHEMA_VERSION,
		"map_package_extension": MAP_PACKAGE_EXTENSION,
		"scenario_package_extension": SCENARIO_PACKAGE_EXTENSION,
		"capabilities": get_capabilities(),
		"status": "skeleton",
	}

func get_capabilities() -> PackedStringArray:
	return PackedStringArray(CAPABILITIES)

func get_schema_ids() -> Dictionary:
	return {
		"map_document": MAP_SCHEMA_ID,
		"scenario_document": SCENARIO_SCHEMA_ID,
		"map_validation_report": "aurelion_map_validation_report",
		"scenario_validation_report": "aurelion_scenario_validation_report",
	}

func create_map_document_stub(initial_state: Dictionary = {}) -> Variant:
	return MapDocumentScript.new(initial_state)

func create_scenario_document_stub(initial_state: Dictionary = {}) -> Variant:
	return ScenarioDocumentScript.new(initial_state)

func load_map_package(path: String, options: Dictionary = {}) -> Dictionary:
	return _not_implemented("load_map_package", "not_implemented", path, options)

func load_scenario_package(path: String, options: Dictionary = {}) -> Dictionary:
	return _not_implemented("load_scenario_package", "not_implemented", path, options)

func validate_map_document(map_document: Variant, options: Dictionary = {}) -> Dictionary:
	return _validation_not_implemented("validate_map_document", "aurelion_map_validation_report")

func validate_scenario_document(scenario_document: Variant, map_document: Variant, options: Dictionary = {}) -> Dictionary:
	return _validation_not_implemented("validate_scenario_document", "aurelion_scenario_validation_report")

func save_map_package(map_document: Variant, path: String, options: Dictionary = {}) -> Dictionary:
	return _not_implemented("save_map_package", "not_implemented", path, options)

func save_scenario_package(scenario_document: Variant, path: String, options: Dictionary = {}) -> Dictionary:
	return _not_implemented("save_scenario_package", "not_implemented", path, options)

func migrate_map_package(source_path: String, target_path: String, target_version: int, options: Dictionary = {}) -> Dictionary:
	return _not_implemented("migrate_map_package", "not_implemented", source_path, options)

func migrate_scenario_package(source_path: String, target_path: String, target_version: int, options: Dictionary = {}) -> Dictionary:
	return _not_implemented("migrate_scenario_package", "not_implemented", source_path, options)

func convert_legacy_scenario_record(scenario_record: Dictionary, terrain_layers_record: Dictionary, options: Dictionary = {}) -> Dictionary:
	return _not_implemented("convert_legacy_scenario_record", "not_implemented", "", options)

func convert_generated_payload(generated_map: Dictionary, options: Dictionary = {}) -> Dictionary:
	return _not_implemented("convert_generated_payload", "not_implemented", "", options)

func compute_document_hash(document: Variant, options: Dictionary = {}) -> Dictionary:
	return _not_implemented("compute_document_hash", "not_implemented", "", options)

func inspect_package(path: String, options: Dictionary = {}) -> Dictionary:
	return _not_implemented("inspect_package", "not_implemented", path, options)

func normalize_random_map_config(config: Dictionary) -> Dictionary:
	var size: Dictionary = config.get("size", {}) if config.get("size", {}) is Dictionary else {}
	var profile: Dictionary = config.get("profile", {}) if config.get("profile", {}) is Dictionary else {}
	var seed := String(config.get("seed", "0")).strip_edges()
	if seed == "":
		seed = "0"
	var template_id := String(config.get("template_id", "")).strip_edges()
	if template_id == "":
		template_id = String(profile.get("template_id", "")).strip_edges()
	var profile_id := String(profile.get("id", config.get("profile_id", ""))).strip_edges()
	var water_mode := String(size.get("water_mode", config.get("water_mode", "land"))).strip_edges()
	if water_mode != "islands":
		water_mode = "land"
	var terrain_ids := _normalized_terrain_pool(_normalized_string_array(profile.get("terrain_ids", []), CORE_TERRAIN_POOL))
	var faction_ids := _normalized_string_array(profile.get("faction_ids", []), DEFAULT_FACTIONS)
	return {
		"schema_id": "aurelion_native_random_map_foundation",
		"schema_version": 1,
		"generator_version": "native_rmg_foundation_v1",
		"seed": seed,
		"normalized_seed": seed,
		"width": _foundation_dimension(config, size, "width", "requested_width", 36),
		"height": _foundation_dimension(config, size, "height", "requested_height", 36),
		"level_count": clampi(int(size.get("level_count", config.get("level_count", 1))), 1, 2),
		"template_id": template_id,
		"profile_id": profile_id,
		"size_class_id": String(size.get("size_class_id", config.get("size_class_id", ""))).strip_edges(),
		"water_mode": water_mode,
		"terrain_ids": terrain_ids,
		"faction_ids": faction_ids,
		"full_generation_status": "not_implemented",
		"foundation_scope": "deterministic_config_identity_and_native_terrain_grid_only",
	}

func random_map_config_identity(config: Dictionary) -> Dictionary:
	var normalized := normalize_random_map_config(config)
	var canonical := _stable_stringify(normalized)
	var signature := _hash32_hex(canonical)
	return {
		"ok": true,
		"schema_id": "aurelion_native_random_map_identity",
		"schema_version": 1,
		"algorithm": "canonical_variant_fnv1a32_foundation",
		"signature": signature,
		"config_hash": "fnv1a32:%s" % signature,
		"map_id": "native_rmg_%s" % signature,
		"normalized_seed": String(normalized.get("normalized_seed", "")),
		"width": int(normalized.get("width", 0)),
		"height": int(normalized.get("height", 0)),
		"level_count": int(normalized.get("level_count", 1)),
		"template_id": String(normalized.get("template_id", "")),
		"profile_id": String(normalized.get("profile_id", "")),
		"canonical_config": canonical,
		"normalized_config": normalized,
		"full_generation_status": "not_implemented",
	}

func generate_random_map(config: Dictionary, options: Dictionary = {}) -> Dictionary:
	var normalized := normalize_random_map_config(config)
	var identity := random_map_config_identity(config)
	var terrain_grid := _generate_terrain_grid(normalized)
	var metadata := {
		"schema_id": "aurelion_native_random_map_foundation",
		"schema_version": 1,
		"generated": true,
		"generator_version": "native_rmg_foundation_v1",
		"generation_status": "partial_foundation",
		"full_generation_status": "not_implemented",
		"terrain_generation_status": "terrain_grid_generated",
		"normalized_config": normalized,
		"deterministic_identity": identity,
		"terrain_grid_signature": terrain_grid.get("signature", ""),
		"options_keys": options.keys(),
	}
	var map_document: Variant = create_map_document_stub({
		"map_id": identity.get("map_id", ""),
		"map_hash": identity.get("config_hash", ""),
		"source_kind": "generated",
		"width": int(normalized.get("width", 36)),
		"height": int(normalized.get("height", 36)),
		"level_count": int(normalized.get("level_count", 1)),
		"metadata": metadata,
	})
	var warnings := [{
		"code": "full_generation_not_implemented",
		"severity": "warning",
		"path": "generate_random_map",
		"message": "Native RMG currently creates deterministic identity metadata and a terrain grid only; objects, roads, rivers, towns, guards, validation parity, and package/session adoption are not implemented.",
		"context": {},
	}]
	return {
		"ok": true,
		"status": "partial_foundation",
		"generation_status": "partial_foundation",
		"terrain_generation_status": "terrain_grid_generated",
		"terrain_grid_status": "generated",
		"full_generation_status": "not_implemented",
		"normalized_config": normalized,
		"deterministic_identity": identity,
		"terrain_grid": terrain_grid,
		"map_document": map_document,
		"map_metadata": metadata,
		"report": {
			"schema_id": "aurelion_native_random_map_foundation_report",
			"schema_version": 1,
			"status": "partial_foundation",
			"failure_count": 0,
			"warning_count": warnings.size(),
			"failures": [],
			"warnings": warnings,
			"metrics": {
				"width": map_document.get_width(),
				"height": map_document.get_height(),
				"level_count": map_document.get_level_count(),
				"tile_count": map_document.get_tile_count(),
				"terrain_grid_tile_count": terrain_grid.get("tile_count", 0),
				"terrain_palette_count": terrain_grid.get("terrain_palette_ids", []).size(),
				"object_count": map_document.get_object_count(),
			},
			"deterministic_identity": identity,
			"terrain_grid_status": terrain_grid.get("generation_status", ""),
			"terrain_grid_signature": terrain_grid.get("signature", ""),
			"remaining_parity_slices": [
				"native-rmg-zone-player-starts-10184",
				"native-rmg-road-river-network-10184",
				"native-rmg-object-placement-foundation-10184",
				"native-rmg-town-guard-placement-10184",
				"native-rmg-validation-provenance-parity-10184",
				"native-rmg-package-session-adoption-10184",
			],
		},
		"adoption_status": "not_authoritative_no_runtime_call_site_adoption",
	}

func _validation_not_implemented(operation: String, report_schema_id: String) -> Dictionary:
	return {
		"ok": false,
		"status": "fail",
		"error_code": "not_implemented",
		"message": "%s is not implemented in the Slice 1 package API skeleton." % operation,
		"report": {
			"schema_id": report_schema_id,
			"schema_version": 1,
			"status": "fail",
			"failure_count": 1,
			"warning_count": 0,
			"failures": [{
				"code": "not_implemented",
				"severity": "fail",
				"path": operation,
				"message": "Validation is stubbed in Slice 1.",
				"context": {},
			}],
			"warnings": [],
			"metrics": {},
		},
		"recoverable": true,
	}

func _foundation_dimension(root: Dictionary, size: Dictionary, key: String, alternate_key: String, fallback: int) -> int:
	var value := int(size.get(key, 0))
	if value <= 0:
		value = int(size.get(alternate_key, 0))
	if value <= 0:
		value = int(root.get(key, fallback))
	return clampi(value, 8, 144)

func _normalized_string_array(value: Variant, fallback: Array) -> Array:
	var result := []
	if value is Array:
		for item in value:
			var text := String(item).strip_edges()
			if text != "" and text not in result:
				result.append(text)
	return result if not result.is_empty() else fallback.duplicate()

func _normalized_terrain_pool(requested: Array) -> Array:
	var result := []
	for terrain_id_value in requested:
		var terrain_id := String(terrain_id_value)
		if _is_passable_terrain_id(terrain_id) and terrain_id not in result:
			result.append(terrain_id)
	return result if not result.is_empty() else CORE_TERRAIN_POOL.duplicate()

func _is_supported_terrain_id(terrain_id: String) -> bool:
	return terrain_id in TERRAIN_ID_BY_CODE

func _is_passable_terrain_id(terrain_id: String) -> bool:
	return _is_supported_terrain_id(terrain_id) and terrain_id != "water"

func _biome_for_terrain(terrain_id: String) -> String:
	match terrain_id:
		"snow":
			return "biome_snow_frost_marches"
		"sand", "dirt":
			return "biome_rough_badlands"
		"rough":
			return "biome_highland_ridge"
		"lava":
			return "biome_ash_lava_wastes"
		"underground":
			return "biome_subterranean_underways"
		"water":
			return "biome_coast_archipelago"
		_:
			return "biome_grasslands"

func _terrain_code_for_id(terrain_id: String) -> int:
	return max(0, TERRAIN_ID_BY_CODE.find(terrain_id))

func _terrain_seed_records(normalized: Dictionary, terrain_pool: Array) -> Array:
	var records := []
	var width := int(normalized.get("width", 36))
	var height := int(normalized.get("height", 36))
	var seed := String(normalized.get("normalized_seed", "0"))
	for index in range(terrain_pool.size()):
		var terrain_id := String(terrain_pool[index])
		var seed_key := "%s:terrain_seed:%s:%d" % [seed, terrain_id, index]
		records.append({
			"terrain_id": terrain_id,
			"biome_id": _biome_for_terrain(terrain_id),
			"x": 1 + int(_hash32_int("%s:x" % seed_key) % max(1, width - 2)),
			"y": 1 + int(_hash32_int("%s:y" % seed_key) % max(1, height - 2)),
			"selection_source": "profile_palette_deterministic_seed",
		})
	return records

func _terrain_for_cell(x: int, y: int, level: int, terrain_pool: Array, seeds: Array, normalized: Dictionary) -> String:
	var width := int(normalized.get("width", 36))
	var height := int(normalized.get("height", 36))
	if level == 0 and String(normalized.get("water_mode", "land")) == "islands" and (x == 0 or y == 0 or x == width - 1 or y == height - 1):
		return "water"
	if level > 0 and "underground" in terrain_pool:
		return "underground"
	var best_terrain := String(terrain_pool[0])
	var best_score := 9223372036854775807
	var seed := String(normalized.get("normalized_seed", "0"))
	for record_value in seeds:
		var record: Dictionary = record_value
		var dx := x - int(record.get("x", 0))
		var dy := y - int(record.get("y", 0))
		var jitter := int(_hash32_int("%s:terrain_cell:%d:%d:%d:%s" % [seed, level, x, y, String(record.get("terrain_id", ""))]) % 97)
		var score := dx * dx * 100 + dy * dy * 126 - jitter
		if score < best_score:
			best_score = score
			best_terrain = String(record.get("terrain_id", best_terrain))
	return best_terrain

func _generate_terrain_grid(normalized: Dictionary) -> Dictionary:
	var width := int(normalized.get("width", 36))
	var height := int(normalized.get("height", 36))
	var level_count := int(normalized.get("level_count", 1))
	var terrain_pool := _normalized_terrain_pool(normalized.get("terrain_ids", CORE_TERRAIN_POOL))
	var seeds := _terrain_seed_records(normalized, terrain_pool)
	var levels := []
	var aggregate_counts := {}
	for level in range(level_count):
		var terrain_codes := PackedInt32Array()
		terrain_codes.resize(width * height)
		var counts := {}
		var biome_counts := {}
		for y in range(height):
			for x in range(width):
				var terrain_id := _terrain_for_cell(x, y, level, terrain_pool, seeds, normalized)
				var biome_id := _biome_for_terrain(terrain_id)
				var flat_index := y * width + x
				terrain_codes[flat_index] = _terrain_code_for_id(terrain_id)
				counts[terrain_id] = int(counts.get(terrain_id, 0)) + 1
				biome_counts[biome_id] = int(biome_counts.get(biome_id, 0)) + 1
				aggregate_counts[terrain_id] = int(aggregate_counts.get(terrain_id, 0)) + 1
		var level_record := {
			"level_index": level,
			"level_kind": "surface" if level == 0 else "underground",
			"width": width,
			"height": height,
			"tile_count": width * height,
			"terrain_code_u16": terrain_codes,
			"terrain_counts": counts,
			"biome_counts": biome_counts,
		}
		level_record["signature"] = _hash32_hex(_stable_stringify(level_record))
		levels.append(level_record)
	var biome_by_terrain := {}
	for terrain_id in TERRAIN_ID_BY_CODE:
		biome_by_terrain[String(terrain_id)] = _biome_for_terrain(String(terrain_id))
	var grid := {
		"schema_id": "aurelion_native_rmg_terrain_grid_v1",
		"schema_version": 1,
		"generation_status": "terrain_grid_generated",
		"full_generation_status": "not_implemented",
		"width": width,
		"height": height,
		"level_count": level_count,
		"tile_count": width * height * level_count,
		"terrain_id_by_code": TERRAIN_ID_BY_CODE,
		"biome_id_by_terrain_id": biome_by_terrain,
		"terrain_palette_ids": terrain_pool,
		"zone_seed_model": "deterministic_terrain_palette_voronoi_seed_grid",
		"terrain_seed_records": seeds,
		"terrain_counts": aggregate_counts,
		"levels": levels,
	}
	grid["signature"] = _hash32_hex(_stable_stringify(grid))
	return grid

func _hash32_hex(text: String) -> String:
	var value := _hash32_int(text)
	var chars := []
	for _index in range(8):
		chars.push_front("0123456789abcdef"[int(value % 16)])
		value = int(value / 16)
	return "".join(chars)

func _hash32_int(text: String) -> int:
	var value := 2166136261
	for index in range(text.length()):
		value = int((value ^ text.unicode_at(index)) % 4294967296)
		value = int((value * 16777619) % 4294967296)
	return value

func _stable_stringify(value: Variant) -> String:
	if value is Dictionary:
		var parts := []
		var keys: Array = value.keys()
		keys.sort()
		for key in keys:
			parts.append("%s:%s" % [String(key).c_escape(), _stable_stringify(value[key])])
		return "{%s}" % ",".join(parts)
	if value is Array:
		var parts := []
		for item in value:
			parts.append(_stable_stringify(item))
		return "[%s]" % ",".join(parts)
	if value is PackedInt32Array:
		var parts := []
		for item in value:
			parts.append("int:%d" % int(item))
		return "[%s]" % ",".join(parts)
	if value is PackedStringArray:
		var parts := []
		for item in value:
			parts.append("string:%s" % String(item).c_escape())
		return "[%s]" % ",".join(parts)
	if value is String:
		return "string:%s" % String(value).c_escape()
	if value is bool:
		return "bool:true" if bool(value) else "bool:false"
	if value == null:
		return "null"
	if value is int:
		return "int:%d" % int(value)
	if value is float:
		return "float:%s" % String.num(float(value))
	return "variant:%s" % String(value).c_escape()

func _not_implemented(operation: String, error_code: String, path: String, options: Dictionary) -> Dictionary:
	return {
		"ok": false,
		"status": "fail",
		"error_code": error_code,
		"message": "%s is not implemented in the Slice 1 package API skeleton." % operation,
		"operation": operation,
		"path": path,
		"report": {
			"schema_id": "aurelion_package_operation_report",
			"schema_version": 1,
			"status": "fail",
			"failures": [{
				"code": error_code,
				"severity": "fail",
				"path": operation,
				"message": "Package conversion/read/write is intentionally unavailable in Slice 1.",
				"context": {"options_keys": options.keys()},
			}],
			"warnings": [],
		},
		"recoverable": true,
	}
