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
	"native_random_map_zone_player_starts_foundation",
	"native_random_map_road_river_network_foundation",
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
	var player_constraints := _normalize_player_constraints(config.get("player_constraints", config.get("players", {})))
	var player_count := int(player_constraints.get("player_count", 2))
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
	var faction_ids := _repeated_to_count(_normalized_string_array(profile.get("faction_ids", []), DEFAULT_FACTIONS), DEFAULT_FACTIONS, player_count)
	var town_ids := _town_ids_for_factions(profile.get("town_ids", []), faction_ids, player_count)
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
		"player_constraints": player_constraints,
		"terrain_ids": terrain_ids,
		"faction_ids": faction_ids,
		"town_ids": town_ids,
		"full_generation_status": "not_implemented",
		"foundation_scope": "deterministic_config_identity_native_terrain_grid_zones_player_starts_and_road_river_networks_only",
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
	var player_assignment := _player_assignment_for_config(normalized)
	var zone_layout := _generate_zone_layout(normalized, player_assignment)
	var player_starts := _generate_player_starts(normalized, zone_layout, player_assignment)
	var road_network := _generate_road_network(normalized, zone_layout, player_starts)
	var river_network := _generate_river_network(normalized, road_network)
	var metadata := {
		"schema_id": "aurelion_native_random_map_foundation",
		"schema_version": 1,
		"generated": true,
		"generator_version": "native_rmg_foundation_v1",
		"generation_status": "partial_foundation",
		"full_generation_status": "not_implemented",
		"terrain_generation_status": "terrain_grid_generated",
		"zone_generation_status": "zones_generated_foundation",
		"player_start_generation_status": "player_starts_generated_foundation",
		"road_generation_status": "roads_generated_foundation",
		"river_generation_status": "rivers_generated_foundation",
		"normalized_config": normalized,
		"deterministic_identity": identity,
		"terrain_grid_signature": terrain_grid.get("signature", ""),
		"zone_layout_signature": zone_layout.get("signature", ""),
		"player_start_signature": player_starts.get("signature", ""),
		"road_network_signature": road_network.get("signature", ""),
		"route_graph_signature": road_network.get("route_graph", {}).get("signature", ""),
		"river_network_signature": river_network.get("signature", ""),
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
		"message": "Native RMG currently creates deterministic identity metadata, a terrain grid, foundation zones, player start anchors, and foundation road/river network records only; objects, towns, guards, validation parity, and package/session adoption are not implemented.",
		"context": {},
	}]
	return {
		"ok": true,
		"status": "partial_foundation",
		"generation_status": "partial_foundation",
		"terrain_generation_status": "terrain_grid_generated",
		"terrain_grid_status": "generated",
		"zone_generation_status": "zones_generated_foundation",
		"player_start_generation_status": "player_starts_generated_foundation",
		"road_generation_status": "roads_generated_foundation",
		"river_generation_status": "rivers_generated_foundation",
		"full_generation_status": "not_implemented",
		"normalized_config": normalized,
		"deterministic_identity": identity,
		"terrain_grid": terrain_grid,
		"player_assignment": player_assignment,
		"zone_layout": zone_layout,
		"player_starts": player_starts,
		"route_graph": road_network.get("route_graph", {}),
		"road_network": road_network,
		"river_network": river_network,
		"route_reachability_proof": road_network.get("route_reachability_proof", {}),
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
				"zone_count": zone_layout.get("zone_count", 0),
				"player_start_count": player_starts.get("start_count", 0),
				"road_segment_count": road_network.get("road_segment_count", 0),
				"road_cell_count": road_network.get("road_cell_count", 0),
				"river_segment_count": river_network.get("river_segment_count", 0),
				"river_cell_count": river_network.get("river_cell_count", 0),
				"object_count": map_document.get_object_count(),
			},
			"deterministic_identity": identity,
			"terrain_grid_status": terrain_grid.get("generation_status", ""),
			"terrain_grid_signature": terrain_grid.get("signature", ""),
			"zone_generation_status": zone_layout.get("generation_status", ""),
			"zone_layout_signature": zone_layout.get("signature", ""),
			"player_start_generation_status": player_starts.get("generation_status", ""),
			"player_start_signature": player_starts.get("signature", ""),
			"road_generation_status": road_network.get("generation_status", ""),
			"road_network_signature": road_network.get("signature", ""),
			"route_graph_signature": road_network.get("route_graph", {}).get("signature", ""),
			"route_reachability_status": road_network.get("route_reachability_proof", {}).get("status", ""),
			"river_generation_status": river_network.get("generation_status", ""),
			"river_network_signature": river_network.get("signature", ""),
			"remaining_parity_slices": [
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

func _normalize_player_constraints(value: Variant) -> Dictionary:
	var human_count := 1
	var computer_count := 1
	var player_count := 2
	var team_mode := "free_for_all"
	if value is Dictionary:
		human_count = clampi(int(value.get("human_count", value.get("humans", human_count))), 1, 8)
		if value.has("player_count") or value.has("total_count") or value.has("total"):
			player_count = clampi(int(value.get("player_count", value.get("total_count", value.get("total", player_count)))), 1, 8)
			player_count = max(player_count, human_count)
			computer_count = max(0, player_count - human_count)
		else:
			computer_count = clampi(int(value.get("computer_count", value.get("computers", computer_count))), 0, 7)
			player_count = clampi(human_count + computer_count, 1, 8)
		team_mode = String(value.get("team_mode", team_mode)).strip_edges().to_lower()
	if team_mode == "":
		team_mode = "free_for_all"
	return {"human_count": human_count, "computer_count": computer_count, "player_count": player_count, "team_mode": team_mode}

func _normalized_string_array(value: Variant, fallback: Array) -> Array:
	var result := []
	if value is Array:
		for item in value:
			var text := String(item).strip_edges()
			if text != "" and text not in result:
				result.append(text)
	return result if not result.is_empty() else fallback.duplicate()

func _repeated_to_count(source: Array, fallback: Array, count: int) -> Array:
	var base := source if not source.is_empty() else fallback
	var result := []
	for index in range(count):
		result.append(base[index % base.size()])
	return result

func _town_for_faction(faction_id: String) -> String:
	match faction_id:
		"faction_mireclaw":
			return "town_mirewatch"
		"faction_sunvault":
			return "town_sunspire"
		"faction_thornwake":
			return "town_thornhold"
		_:
			return "town_riverwatch"

func _town_ids_for_factions(value: Variant, faction_ids: Array, count: int) -> Array:
	var requested := _normalized_string_array(value, []) if value is Array else []
	var result := []
	for index in range(count):
		result.append(String(requested[index % requested.size()]) if not requested.is_empty() else _town_for_faction(String(faction_ids[index % faction_ids.size()])))
	return result

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

func _player_assignment_for_config(normalized: Dictionary) -> Dictionary:
	var constraints: Dictionary = normalized.get("player_constraints", {})
	var player_count := int(constraints.get("player_count", 2))
	var human_count := int(constraints.get("human_count", 1))
	var team_mode := String(constraints.get("team_mode", "free_for_all"))
	var faction_ids: Array = normalized.get("faction_ids", DEFAULT_FACTIONS)
	var town_ids: Array = normalized.get("town_ids", [])
	var player_slots := []
	var by_owner_slot := {}
	var active_owner_slots := []
	var assigned_faction_ids := []
	var assigned_town_ids := []
	var teams := []
	for index in range(player_count):
		var player_slot := index + 1
		var owner_slot := player_slot
		var player_type := "human" if player_slot <= human_count else "computer"
		var faction_id := String(faction_ids[index % faction_ids.size()])
		var town_id := String(town_ids[index % town_ids.size()]) if not town_ids.is_empty() else _town_for_faction(faction_id)
		var team_id := "team_%02d" % player_slot
		var slot := {
			"player_slot": player_slot,
			"owner_slot": owner_slot,
			"player_type": player_type,
			"faction_id": faction_id,
			"town_id": town_id,
			"team_id": team_id,
			"team_mode": team_mode,
			"ai_controlled": player_type != "human",
			"assignment_source": "native_foundation_fixed_owner_slot_profile_order",
		}
		player_slots.append(slot)
		by_owner_slot[str(owner_slot)] = slot
		active_owner_slots.append(owner_slot)
		assigned_faction_ids.append(faction_id)
		assigned_town_ids.append(town_id)
		teams.append({"team_id": team_id, "player_slots": [player_slot], "mode": "free_for_all"})
	return {
		"schema_id": "random_map_player_assignment_v1",
		"assignment_policy": "native_foundation_fixed_owner_slots_first_n_players_profile_order",
		"team_mode": team_mode,
		"team_metadata": {"mode": "free_for_all", "supported_now": team_mode == "free_for_all", "requested_mode": team_mode, "teams": teams},
		"human_count": human_count,
		"computer_count": int(constraints.get("computer_count", max(0, player_count - human_count))),
		"player_count": player_count,
		"capacity": {"human_start_capacity": human_count, "total_start_capacity": player_count, "fixed_owner_slots": active_owner_slots, "human_owner_slots": active_owner_slots.slice(0, human_count)},
		"active_owner_slots": active_owner_slots,
		"inactive_owner_slots": [],
		"player_slots": player_slots,
		"player_slot_by_owner_slot": by_owner_slot,
		"assigned_faction_ids": assigned_faction_ids,
		"assigned_town_ids": assigned_town_ids,
		"faction_pool": faction_ids,
	}

func _terrain_for_faction(faction_id: String) -> String:
	match faction_id:
		"faction_mireclaw":
			return "dirt"
		"faction_thornwake":
			return "rough"
		_:
			return "grass"

func _zone_palette(zone_id: String, faction_id: String, match_to_faction: bool, terrain_pool: Array, index: int) -> Dictionary:
	var selected := String(terrain_pool[index % terrain_pool.size()])
	var source := "profile_palette_foundation_order"
	var faction_terrain := _terrain_for_faction(faction_id)
	if match_to_faction and faction_terrain in terrain_pool:
		selected = faction_terrain
		source = "faction_match_profile_palette"
	return {
		"zone_id": zone_id,
		"faction_id": faction_id,
		"terrain_match_to_faction": match_to_faction,
		"profile_terrain_ids": terrain_pool,
		"catalog_allowed_terrain_ids": [],
		"faction_terrain_id": faction_terrain,
		"selected_terrain_id": selected,
		"normalized_terrain_id": selected,
		"original_terrain_id": selected,
		"biome_id": _biome_for_terrain(selected),
		"passable": _is_passable_terrain_id(selected),
		"selection_source": source,
		"fallback_used": false,
		"unsupported_terrain_ids": [],
		"deferred_terrain_ids": [],
		"deferred_reason": "",
	}

func _generate_zone_layout(normalized: Dictionary, player_assignment: Dictionary) -> Dictionary:
	var width := int(normalized.get("width", 36))
	var height := int(normalized.get("height", 36))
	var player_count := int(normalized.get("player_constraints", {}).get("player_count", 2))
	var terrain_pool := _normalized_terrain_pool(normalized.get("terrain_ids", CORE_TERRAIN_POOL))
	var zones := []
	var by_owner: Dictionary = player_assignment.get("player_slot_by_owner_slot", {})
	for index in range(player_count):
		var owner_slot := index + 1
		var assignment: Dictionary = by_owner.get(str(owner_slot), {})
		var zone_id := "start_%d" % owner_slot
		var faction_id := String(assignment.get("faction_id", ""))
		var palette := _zone_palette(zone_id, faction_id, true, terrain_pool, index)
		zones.append({"id": zone_id, "source_id": zone_id, "role": "human_start" if owner_slot == 1 else "computer_start", "owner_slot": owner_slot, "player_slot": owner_slot, "player_type": assignment.get("player_type", "human" if owner_slot == 1 else "computer"), "team_id": assignment.get("team_id", "team_%02d" % owner_slot), "faction_id": faction_id, "terrain_id": palette.get("normalized_terrain_id", "grass"), "terrain_palette": palette, "base_size": 18, "catalog_metadata": {"start_contract": "primary_town_anchor_deferred_to_later_native_slice", "native_foundation_source": "fallback_runtime_template"}})
	zones.append({"id": "junction_1", "source_id": "junction_1", "role": "junction", "owner_slot": null, "player_slot": null, "player_type": "neutral", "team_id": "", "faction_id": "", "terrain_id": String(terrain_pool[player_count % terrain_pool.size()]), "terrain_palette": _zone_palette("junction_1", "", false, terrain_pool, player_count), "base_size": 10, "catalog_metadata": {}})
	for index in range(max(2, player_count)):
		var zone_id := "reward_%d" % (index + 1)
		zones.append({"id": zone_id, "source_id": zone_id, "role": "treasure", "owner_slot": null, "player_slot": null, "player_type": "neutral", "team_id": "", "faction_id": "", "terrain_id": String(terrain_pool[(player_count + index + 1) % terrain_pool.size()]), "terrain_palette": _zone_palette(zone_id, "", false, terrain_pool, player_count + index + 1), "base_size": 8, "catalog_metadata": {}})
	var seeds := _place_foundation_zone_seeds(zones, normalized)
	var owner_grid := []
	for y in range(height):
		var row := []
		for x in range(width):
			row.append(_nearest_foundation_zone_id(x, y, zones, seeds))
		owner_grid.append(row)
	_apply_zone_geometry(zones, seeds, owner_grid)
	var layout := {
		"schema_id": "aurelion_native_rmg_zone_layout_v1",
		"schema_version": 1,
		"generation_status": "zones_generated_foundation",
		"full_generation_status": "not_implemented",
		"template_id": String(normalized.get("template_id", "")),
		"template_source": "native_foundation_fallback_runtime_template",
		"dimensions": {"width": width, "height": height, "level_count": int(normalized.get("level_count", 1))},
		"policy": {"zone_area_model": "native_foundation_weighted_nearest_seed", "water_mode": String(normalized.get("water_mode", "land")), "template_model": "fallback_runtime_template_until_catalog_parity_slice"},
		"zone_count": zones.size(),
		"zones": zones,
		"zone_seed_records": seeds,
		"levels": [{"level_index": 0, "kind": "surface", "owner_grid": owner_grid, "anchor_points": seeds, "allocation_model": "native_foundation_nearest_seed_weighted_owner_grid"}],
		"surface_owner_grid": owner_grid,
		"surface_water_cells": [],
		"unsupported_runtime_features": [],
	}
	layout["signature"] = _hash32_hex(_stable_stringify(layout))
	return layout

func _place_foundation_zone_seeds(zones: Array, normalized: Dictionary) -> Dictionary:
	var width := int(normalized.get("width", 36))
	var height := int(normalized.get("height", 36))
	var seed := String(normalized.get("normalized_seed", "0"))
	var center := Vector2((float(width) - 1.0) * 0.5, (float(height) - 1.0) * 0.5)
	var radius_x: float = max(3.0, float(width) * 0.36)
	var radius_y: float = max(2.0, float(height) * 0.32)
	var starts := zones.filter(func(zone: Dictionary) -> bool: return zone.get("player_slot", null) != null)
	var others := zones.filter(func(zone: Dictionary) -> bool: return zone.get("player_slot", null) == null)
	var angle_offset := float(_hash32_int("%s:zone_angle_offset" % seed) % 10000) / 10000.0 * TAU
	var seeds := {}
	for index in range(starts.size()):
		var zone: Dictionary = starts[index]
		var angle := angle_offset + TAU * float(index) / float(max(1, starts.size()))
		seeds[String(zone.get("id", ""))] = _point_dict(clampi(int(round(center.x + cos(angle) * radius_x)) + _signed_jitter("%s:%s:x" % [seed, String(zone.get("id", ""))]), 1, max(1, width - 2)), clampi(int(round(center.y + sin(angle) * radius_y)) + _signed_jitter("%s:%s:y" % [seed, String(zone.get("id", ""))]), 1, max(1, height - 2)))
	for index in range(others.size()):
		var zone: Dictionary = others[index]
		var role := String(zone.get("role", "treasure"))
		var angle := angle_offset + TAU * (float(index) + 0.5) / float(max(1, others.size()))
		var radius_scale := 0.18 if role == "junction" else 0.58
		seeds[String(zone.get("id", ""))] = _point_dict(clampi(int(round(center.x + cos(angle) * radius_x * radius_scale)) + _signed_jitter("%s:%s:x" % [seed, String(zone.get("id", ""))]), 1, max(1, width - 2)), clampi(int(round(center.y + sin(angle) * radius_y * radius_scale)) + _signed_jitter("%s:%s:y" % [seed, String(zone.get("id", ""))]), 1, max(1, height - 2)))
	return _resolve_point_collisions(seeds, width, height)

func _generate_player_starts(normalized: Dictionary, zone_layout: Dictionary, player_assignment: Dictionary) -> Dictionary:
	var width := int(normalized.get("width", 36))
	var height := int(normalized.get("height", 36))
	var player_count := int(normalized.get("player_constraints", {}).get("player_count", 2))
	var min_spacing: int = max(3, int(min(width, height) / max(3, player_count + 2)))
	var starts := []
	for zone in zone_layout.get("zones", []):
		if not (zone is Dictionary) or zone.get("player_slot", null) == null:
			continue
		var point := _usable_start_point(zone, zone_layout.get("surface_owner_grid", []), starts, min_spacing)
		var player_slot := int(zone.get("player_slot", 0))
		var assignment: Dictionary = player_assignment.get("player_slot_by_owner_slot", {}).get(str(int(zone.get("owner_slot", player_slot))), {})
		starts.append({"start_id": "player_start_%d" % player_slot, "player_slot": player_slot, "owner_slot": int(zone.get("owner_slot", player_slot)), "player_type": String(zone.get("player_type", "computer")), "team_id": String(zone.get("team_id", "")), "faction_id": String(zone.get("faction_id", "")), "town_id": String(assignment.get("town_id", _town_for_faction(String(zone.get("faction_id", ""))))), "zone_id": String(zone.get("id", "")), "zone_role": String(zone.get("role", "")), "x": int(point.get("x", 0)), "y": int(point.get("y", 0)), "level": 0, "bounds_status": "in_bounds" if int(point.get("x", 0)) >= 0 and int(point.get("x", 0)) < width and int(point.get("y", 0)) >= 0 and int(point.get("y", 0)) < height else "out_of_bounds", "spacing_model": "native_foundation_minimum_euclidean_tile_spacing", "primary_town_anchor_status": "reserved_not_materialized"})
	var payload := {"schema_id": "aurelion_native_rmg_player_starts_v1", "schema_version": 1, "generation_status": "player_starts_generated_foundation", "full_generation_status": "not_implemented", "start_count": starts.size(), "expected_player_count": player_count, "minimum_spacing_tiles": min_spacing, "starts": starts}
	payload["signature"] = _hash32_hex(_stable_stringify(payload))
	return payload

func _foundation_route_links(normalized: Dictionary) -> Array:
	var player_count := int(normalized.get("player_constraints", {}).get("player_count", 2))
	var links := []
	for index in range(player_count):
		var start_id := "start_%d" % (index + 1)
		var reward_id := "reward_%d" % ((index % max(2, player_count)) + 1)
		links.append({"from": start_id, "to": "junction_1", "role": "contest_route", "guard_value": 600, "wide": false, "border_guard": false})
		links.append({"from": start_id, "to": reward_id, "role": "early_reward_route", "guard_value": 150, "wide": false, "border_guard": false})
	for index in range(max(2, player_count)):
		links.append({"from": "reward_%d" % (index + 1), "to": "junction_1", "role": "reward_to_junction", "guard_value": 300, "wide": index == 0, "border_guard": false})
	return links

func _route_edge_id(index: int, from_zone: String, to_zone: String) -> String:
	return "edge_%02d_%s_%s" % [index, from_zone, to_zone]

func _route_classification(link: Dictionary, path_found: bool) -> String:
	if not path_found:
		return "blocked_connectivity"
	if bool(link.get("border_guard", false)):
		return "guarded_connectivity_border_guard"
	if bool(link.get("wide", false)):
		return "full_connectivity_wide_unguarded"
	if int(link.get("guard_value", 0)) > 0:
		return "guarded_connectivity"
	return "full_connectivity"

func _straight_route_cells(from_point: Dictionary, to_point: Dictionary, width: int, height: int, level: int) -> Array:
	if from_point.is_empty() or to_point.is_empty():
		return []
	var cells := []
	var x: int = clampi(int(from_point.get("x", 0)), 0, width - 1)
	var y: int = clampi(int(from_point.get("y", 0)), 0, height - 1)
	var goal_x: int = clampi(int(to_point.get("x", 0)), 0, width - 1)
	var goal_y: int = clampi(int(to_point.get("y", 0)), 0, height - 1)
	var step_x := 1 if goal_x >= x else -1
	while x != goal_x:
		cells.append(_cell_dict(x, y, level))
		x += step_x
	var step_y := 1 if goal_y >= y else -1
	while y != goal_y:
		cells.append(_cell_dict(x, y, level))
		y += step_y
	cells.append(_cell_dict(goal_x, goal_y, level))
	return cells

func _route_anchor_candidate(path: Array, from_anchor: Dictionary, to_anchor: Dictionary, level: int) -> Dictionary:
	if not path.is_empty() and path[int(floor(float(path.size() - 1) * 0.5))] is Dictionary:
		var midpoint: Dictionary = path[int(floor(float(path.size() - 1) * 0.5))]
		var result := _cell_dict(int(midpoint.get("x", 0)), int(midpoint.get("y", 0)), level)
		result["source"] = "route_path_midpoint"
		return result
	if not from_anchor.is_empty() and not to_anchor.is_empty():
		var result := _cell_dict(int(round((int(from_anchor.get("x", 0)) + int(to_anchor.get("x", 0))) * 0.5)), int(round((int(from_anchor.get("y", 0)) + int(to_anchor.get("y", 0))) * 0.5)), level)
		result["source"] = "anchor_midpoint_fallback"
		return result
	return {}

func _start_lookup_by_zone(player_starts: Dictionary) -> Dictionary:
	var result := {}
	for start in player_starts.get("starts", []):
		if start is Dictionary:
			result[String(start.get("zone_id", ""))] = start
	return result

func _build_route_nodes(zone_layout: Dictionary, player_starts: Dictionary) -> Dictionary:
	var nodes := {}
	for zone in zone_layout.get("zones", []):
		if not (zone is Dictionary):
			continue
		var zone_id := String(zone.get("id", ""))
		var anchor: Dictionary = zone.get("anchor", zone.get("center", {}))
		nodes["node_zone_%s" % zone_id] = {
			"id": "node_zone_%s" % zone_id,
			"kind": "zone_anchor",
			"zone_id": zone_id,
			"zone_role": String(zone.get("role", "")),
			"point": _cell_dict(int(anchor.get("x", 0)), int(anchor.get("y", 0)), 0),
			"required": false,
			"connectable_state": "foundation_zone_anchor",
		}
	for start in player_starts.get("starts", []):
		if not (start is Dictionary):
			continue
		var player_slot := int(start.get("player_slot", 0))
		nodes["node_player_start_%d" % player_slot] = {
			"id": "node_player_start_%d" % player_slot,
			"kind": "player_start_anchor",
			"start_id": String(start.get("start_id", "")),
			"zone_id": String(start.get("zone_id", "")),
			"player_slot": player_slot,
			"owner_slot": int(start.get("owner_slot", player_slot)),
			"point": _cell_dict(int(start.get("x", 0)), int(start.get("y", 0)), int(start.get("level", 0))),
			"required": true,
			"connectable_state": "foundation_player_start_anchor",
		}
	return nodes

func _preferred_node_id_for_zone(zone_id: String, start_by_zone: Dictionary) -> String:
	if start_by_zone.has(zone_id):
		return "node_player_start_%d" % int(start_by_zone.get(zone_id, {}).get("player_slot", 0))
	return "node_zone_%s" % zone_id

func _connect_adjacency(adjacency: Dictionary, a: String, b: String) -> void:
	if not adjacency.has(a):
		adjacency[a] = []
	if not adjacency.has(b):
		adjacency[b] = []
	if b not in adjacency[a]:
		adjacency[a].append(b)
	if a not in adjacency[b]:
		adjacency[b].append(a)

func _route_reachability_proof(nodes: Dictionary, edges: Array, adjacency: Dictionary) -> Dictionary:
	var required_nodes := []
	var keys := nodes.keys()
	keys.sort()
	for node_id in keys:
		if bool(nodes[node_id].get("required", false)):
			required_nodes.append(String(node_id))
	if required_nodes.is_empty():
		return {"status": "fail", "reason": "no_required_nodes", "required_nodes": []}
	var visited := {String(required_nodes[0]): true}
	var queue := [String(required_nodes[0])]
	var cursor := 0
	while cursor < queue.size():
		var current := String(queue[cursor])
		cursor += 1
		for next_id in adjacency.get(current, []):
			var next_key := String(next_id)
			if visited.has(next_key):
				continue
			visited[next_key] = true
			queue.append(next_key)
	var unreachable := []
	for node_id in required_nodes:
		if not visited.has(String(node_id)):
			unreachable.append(String(node_id))
	var blocked_edges := []
	for edge in edges:
		if edge is Dictionary and bool(edge.get("required", false)) and not bool(edge.get("path_found", false)):
			blocked_edges.append(String(edge.get("id", "")))
	return {
		"status": "pass" if unreachable.is_empty() and blocked_edges.is_empty() else "fail",
		"model": "required_player_start_nodes_connected_by_staged_native_road_paths",
		"required_nodes": required_nodes,
		"reachable_required_nodes": required_nodes.size() - unreachable.size(),
		"unreachable_required_nodes": unreachable,
		"blocked_required_edges": blocked_edges,
	}

func _generate_road_network(normalized: Dictionary, zone_layout: Dictionary, player_starts: Dictionary) -> Dictionary:
	var width := int(normalized.get("width", 36))
	var height := int(normalized.get("height", 36))
	var links := _foundation_route_links(normalized)
	var nodes := _build_route_nodes(zone_layout, player_starts)
	var start_by_zone := _start_lookup_by_zone(player_starts)
	var edges := []
	var road_segments := []
	var adjacency := {}
	var covered_start_ids := []
	var covered_zone_ids := []
	for index in range(links.size()):
		var link: Dictionary = links[index]
		var from_zone := String(link.get("from", ""))
		var to_zone := String(link.get("to", ""))
		var from_node_id := _preferred_node_id_for_zone(from_zone, start_by_zone)
		var to_node_id := _preferred_node_id_for_zone(to_zone, start_by_zone)
		var from_point: Dictionary = nodes.get(from_node_id, {}).get("point", {})
		var to_point: Dictionary = nodes.get(to_node_id, {}).get("point", {})
		var cells := _straight_route_cells(from_point, to_point, width, height, 0)
		var edge_id := _route_edge_id(index + 1, from_zone, to_zone)
		var classification := _route_classification(link, not cells.is_empty())
		var edge := {"id": edge_id, "from": from_zone, "to": to_zone, "from_node_id": from_node_id, "to_node_id": to_node_id, "role": String(link.get("role", "route")), "guard_value": int(link.get("guard_value", 0)), "wide": bool(link.get("wide", false)), "border_guard": bool(link.get("border_guard", false)), "required": true, "path_found": not cells.is_empty(), "cell_count": cells.size(), "from_point": from_point, "to_point": to_point, "route_cell_anchor_candidate": _route_anchor_candidate(cells, from_point, to_point, 0), "connectivity_classification": classification, "transit_semantics": {}}
		edges.append(edge)
		if not cells.is_empty():
			_connect_adjacency(adjacency, from_node_id, to_node_id)
		if start_by_zone.has(from_zone):
			var start_id := String(start_by_zone[from_zone].get("start_id", ""))
			if start_id not in covered_start_ids:
				covered_start_ids.append(start_id)
		for zone_id in [from_zone, to_zone]:
			if zone_id not in covered_zone_ids:
				covered_zone_ids.append(zone_id)
		road_segments.append({"id": "road_%s" % edge_id, "route_edge_id": edge_id, "overlay_id": "generated_dirt_road", "cells": cells, "cell_count": cells.size(), "connectivity_classification": classification, "role": String(link.get("role", "route")), "writeout_state": "staged_overlay_no_tile_bytes_written", "bounds_status": "in_bounds"})
	var reachability := _route_reachability_proof(nodes, edges, adjacency)
	var route_graph := {"schema_id": "aurelion_native_rmg_route_graph_v1", "schema_version": 1, "generation_status": "route_graph_generated_foundation", "full_generation_status": "not_implemented", "nodes": nodes, "edges": edges, "adjacency": adjacency, "required_reachability": reachability, "route_edge_count": edges.size(), "route_node_count": nodes.size()}
	route_graph["signature"] = _hash32_hex(_stable_stringify(route_graph))
	var road_cell_count := 0
	for segment in road_segments:
		road_cell_count += int(segment.get("cell_count", 0))
	var coverage := {"expected_player_start_count": int(player_starts.get("start_count", 0)), "covered_player_start_count": covered_start_ids.size(), "covered_player_start_ids": covered_start_ids, "covered_zone_ids": covered_zone_ids, "status": "pass" if covered_start_ids.size() == int(player_starts.get("start_count", 0)) else "partial"}
	var road_network := {"schema_id": "aurelion_native_rmg_road_network_v1", "schema_version": 1, "generation_status": "roads_generated_foundation", "full_generation_status": "not_implemented", "writeout_policy": "final_generated_tile_stream_no_authored_tile_write", "materialization_state": "staged_overlay_records_only_no_gameplay_adoption", "overlay_id": "generated_dirt_road", "route_graph": route_graph, "road_segments": road_segments, "road_segment_count": road_segments.size(), "road_cell_count": road_cell_count, "required_start_coverage": coverage, "route_reachability_proof": reachability}
	road_network["signature"] = _hash32_hex(_stable_stringify(road_network))
	return road_network

func _bounded_river_cells(normalized: Dictionary) -> Array:
	var width := int(normalized.get("width", 36))
	var height := int(normalized.get("height", 36))
	var seed := String(normalized.get("normalized_seed", "0"))
	var cells := []
	var min_y := 0 if height <= 2 else 1
	var max_y := height - 1 if height <= 2 else height - 2
	var base_x := clampi(1 + int(_hash32_int("%s:river_base_x" % seed) % max(1, width - 2)), 1, max(1, width - 2))
	for y in range(min_y, max_y + 1):
		cells.append(_cell_dict(clampi(base_x + _signed_jitter("%s:river_y:%d" % [seed, y]), 0, width - 1), y, 0))
	return cells

func _island_waterline_cells(normalized: Dictionary) -> Array:
	var width := int(normalized.get("width", 36))
	var height := int(normalized.get("height", 36))
	var cells := []
	for x in range(0, width, 2):
		cells.append(_cell_dict(x, 0, 0))
	for y in range(2, height, 2):
		cells.append(_cell_dict(width - 1, y, 0))
	return cells

func _bounds_for_cells(cells: Array) -> Dictionary:
	if cells.is_empty():
		return {}
	var min_x := 999999
	var min_y := 999999
	var max_x := -1
	var max_y := -1
	for cell in cells:
		if not (cell is Dictionary):
			continue
		min_x = min(min_x, int(cell.get("x", 0)))
		min_y = min(min_y, int(cell.get("y", 0)))
		max_x = max(max_x, int(cell.get("x", 0)))
		max_y = max(max_y, int(cell.get("y", 0)))
	return {"min_x": min_x, "min_y": min_y, "max_x": max_x, "max_y": max_y}

func _generate_river_network(normalized: Dictionary, road_network: Dictionary) -> Dictionary:
	var segments := []
	var river_cells := _bounded_river_cells(normalized)
	segments.append({"id": "river_foundation_01", "kind": "river", "route_feature_class": "bounded_waterline_feature", "cells": river_cells, "cell_count": river_cells.size(), "bounds": _bounds_for_cells(river_cells), "materialization_state": "bounded_route_feature_metadata_only_no_terrain_mutation"})
	if String(normalized.get("water_mode", "land")) == "islands":
		var waterline := _island_waterline_cells(normalized)
		segments.append({"id": "waterline_foundation_01", "kind": "shore_waterline", "route_feature_class": "island_border_waterline", "cells": waterline, "cell_count": waterline.size(), "bounds": _bounds_for_cells(waterline), "materialization_state": "waterline_metadata_only_existing_terrain_grid_unchanged"})
	var cell_count := 0
	for segment in segments:
		cell_count += int(segment.get("cell_count", 0))
	var network := {"schema_id": "aurelion_native_rmg_river_network_v1", "schema_version": 1, "generation_status": "rivers_generated_foundation", "full_generation_status": "not_implemented", "policy": {"water_mode": String(normalized.get("water_mode", "land")), "enabled": true, "route_feature_boundary": "foundation_records_only_no_passability_or_tile_mutation", "road_crossing_policy": "crossing_metadata_deferred_to_later_parity_slice"}, "river_segments": segments, "river_segment_count": segments.size(), "river_cell_count": cell_count, "related_road_network_signature": road_network.get("signature", ""), "materialization_state": "staged_route_feature_records_only_no_gameplay_adoption"}
	network["signature"] = _hash32_hex(_stable_stringify(network))
	return network

func _point_dict(x: int, y: int) -> Dictionary:
	return {"x": x, "y": y}

func _cell_dict(x: int, y: int, level: int) -> Dictionary:
	return {"x": x, "y": y, "level": level}

func _point_key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]

func _signed_jitter(key: String) -> int:
	return int(_hash32_int(key) % 3) - 1

func _resolve_point_collisions(points: Dictionary, width: int, height: int) -> Dictionary:
	var resolved := {}
	var occupied := {}
	var keys := points.keys()
	keys.sort()
	for key in keys:
		var point: Dictionary = points[key]
		var x := int(point.get("x", 0))
		var y := int(point.get("y", 0))
		var guard: int = max(1, width * height)
		while occupied.has(_point_key(x, y)) and guard > 0:
			x = clampi(x + 1, 1, max(1, width - 2))
			if occupied.has(_point_key(x, y)):
				y = clampi(y + 1, 1, max(1, height - 2))
			guard -= 1
		occupied[_point_key(x, y)] = true
		resolved[String(key)] = _point_dict(x, y)
	return resolved

func _nearest_foundation_zone_id(x: int, y: int, zones: Array, seeds: Dictionary) -> String:
	var best_id := String(zones[0].get("id", "")) if not zones.is_empty() else ""
	var best_score := INF
	for zone in zones:
		var seed: Dictionary = seeds.get(String(zone.get("id", "")), {})
		var dx := float(x - int(seed.get("x", 0)))
		var dy := float(y - int(seed.get("y", 0)))
		var score := (dx * dx + dy * dy) / sqrt(float(max(1, int(zone.get("base_size", 1)))))
		if score < best_score:
			best_score = score
			best_id = String(zone.get("id", ""))
	return best_id

func _apply_zone_geometry(zones: Array, seeds: Dictionary, owner_grid: Array) -> void:
	var counts := {}
	var bounds := {}
	for zone in zones:
		var zone_id := String(zone.get("id", ""))
		counts[zone_id] = 0
		bounds[zone_id] = {"min_x": 999999, "min_y": 999999, "max_x": -1, "max_y": -1}
	for y in range(owner_grid.size()):
		for x in range(owner_grid[y].size()):
			var zone_id := String(owner_grid[y][x])
			counts[zone_id] = int(counts.get(zone_id, 0)) + 1
			var zone_bounds: Dictionary = bounds.get(zone_id, {})
			zone_bounds["min_x"] = min(int(zone_bounds.get("min_x", x)), x)
			zone_bounds["min_y"] = min(int(zone_bounds.get("min_y", y)), y)
			zone_bounds["max_x"] = max(int(zone_bounds.get("max_x", x)), x)
			zone_bounds["max_y"] = max(int(zone_bounds.get("max_y", y)), y)
			bounds[zone_id] = zone_bounds
	for zone in zones:
		var zone_id := String(zone.get("id", ""))
		var anchor: Dictionary = seeds.get(zone_id, {})
		zone["anchor"] = anchor
		zone["center"] = _point_dict(int(anchor.get("x", 0)), int(anchor.get("y", 0)))
		zone["bounds"] = bounds.get(zone_id, {})
		zone["cell_count"] = int(counts.get(zone_id, 0))

func _start_far_enough(starts: Array, x: int, y: int, min_spacing: int) -> bool:
	for start in starts:
		var dx := x - int(start.get("x", 0))
		var dy := y - int(start.get("y", 0))
		if dx * dx + dy * dy < min_spacing * min_spacing:
			return false
	return true

func _usable_start_point(zone: Dictionary, owner_grid: Array, starts: Array, min_spacing: int) -> Dictionary:
	var anchor: Dictionary = zone.get("anchor", {})
	var ax := int(anchor.get("x", 0))
	var ay := int(anchor.get("y", 0))
	if _start_far_enough(starts, ax, ay, min_spacing):
		return _point_dict(ax, ay)
	var best := {}
	var best_score := 9223372036854775807
	var zone_id := String(zone.get("id", ""))
	for y in range(owner_grid.size()):
		for x in range(owner_grid[y].size()):
			if String(owner_grid[y][x]) != zone_id or not _start_far_enough(starts, x, y, min_spacing):
				continue
			var score := (x - ax) * (x - ax) + (y - ay) * (y - ay)
			if score < best_score:
				best_score = score
				best = _point_dict(x, y)
	return best if not best.is_empty() else _point_dict(ax, ay)

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
