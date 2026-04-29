extends Node

const RandomMapGeneratorRulesScript = preload("res://scripts/core/RandomMapGeneratorRules.gd")
const REPORT_ID := "RANDOM_MAP_TERRAIN_TRANSIT_SEMANTICS_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var generator = RandomMapGeneratorRulesScript.new()
	var base_config := _base_config("terrain-transit-10184", ["grass", "plains", "forest", "swamp", "highland"])
	var report: Dictionary = generator.terrain_transit_report(base_config)
	if not bool(report.get("ok", false)):
		_fail("Terrain/transit report failed: %s" % JSON.stringify(report))
		return
	var base_payload: Dictionary = generator.generate(base_config).get("generated_map", {})
	if not _assert_payload_boundaries(base_payload):
		return
	var base_semantics: Dictionary = base_payload.get("staging", {}).get("terrain_transit_semantics", {})
	if not _assert_normalization(base_semantics, false):
		return
	if not _assert_land_routes(base_semantics):
		return

	var underground_payload: Dictionary = generator.generate(_translated_config("terrain-transit-underground-10184", "land", 2, ["grass", "plains", "forest", "swamp", "highland"])).get("generated_map", {})
	if not _assert_payload_boundaries(underground_payload):
		return
	var underground_semantics: Dictionary = underground_payload.get("staging", {}).get("terrain_transit_semantics", {})
	if not _assert_underground_semantics(underground_semantics):
		return
	if not _assert_land_and_underground_routes(underground_semantics):
		return

	var water_payload: Dictionary = generator.generate(_translated_config("terrain-transit-water-10184", "islands", 1, ["grass", "plains", "forest", "swamp", "highland"])).get("generated_map", {})
	if not _assert_payload_boundaries(water_payload):
		return
	if not _assert_water_semantics(water_payload.get("staging", {}).get("terrain_transit_semantics", {})):
		return

	var unsupported_payload: Dictionary = generator.generate(_base_config("terrain-transit-unsupported-10184", ["unsupported_glass", "unsupported_bog"])).get("generated_map", {})
	if not _assert_payload_boundaries(unsupported_payload):
		return
	if not _assert_normalization(unsupported_payload.get("staging", {}).get("terrain_transit_semantics", {}), true):
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"stable_signature": base_payload.get("stable_signature", ""),
		"terrain_transit_signature": base_semantics.get("terrain_transit_signature", ""),
		"water_signature": water_payload.get("staging", {}).get("terrain_transit_semantics", {}).get("terrain_transit_signature", ""),
		"unsupported_signature": unsupported_payload.get("staging", {}).get("terrain_transit_semantics", {}).get("terrain_transit_signature", ""),
		"zone_palette_count": base_semantics.get("terrain_normalization", {}).get("zone_palettes", []).size(),
		"terrain_layers": underground_semantics.get("terrain_layers", []).size(),
		"corridor_routes": base_semantics.get("transit_routes", {}).get("corridor_routes", []).size(),
		"cross_level_candidates": underground_semantics.get("transit_routes", {}).get("cross_level_candidates", []).size(),
		"water_access_candidates": water_payload.get("staging", {}).get("terrain_transit_semantics", {}).get("transit_routes", {}).get("water_access_candidates", []).size(),
		"no_ui_save_adoption": base_payload.get("scenario_record", {}).get("selection", {}).get("availability", {}),
	})])
	get_tree().quit(0)

func _base_config(seed: String, terrain_ids: Array) -> Dictionary:
	return {
		"generator_version": RandomMapGeneratorRulesScript.GENERATOR_VERSION,
		"seed": seed,
		"size": {"preset": "terrain_transit", "width": 22, "height": 14, "water_mode": "land", "level_count": 1},
		"player_constraints": {"human_count": 1, "computer_count": 2},
		"profile": {
			"id": "terrain_transit_profile",
			"label": "Terrain Transit Profile",
			"terrain_ids": terrain_ids,
			"faction_ids": ["faction_embercourt", "faction_mireclaw", "faction_sunvault"],
		},
	}

func _translated_config(seed: String, water_mode: String, level_count: int, terrain_ids: Array) -> Dictionary:
	return {
		"generator_version": RandomMapGeneratorRulesScript.GENERATOR_VERSION,
		"seed": seed,
		"size": {"preset": "terrain_transit", "width": 36, "height": 30, "water_mode": water_mode, "level_count": level_count},
		"player_constraints": {"human_count": 2, "player_count": 4, "team_mode": "free_for_all"},
		"profile": {
			"id": "translated_rmg_profile_001_v1",
			"template_id": "translated_rmg_template_001_v1",
			"terrain_ids": terrain_ids,
			"faction_ids": ["faction_embercourt", "faction_mireclaw", "faction_sunvault", "faction_thornwake"],
		},
	}

func _assert_payload_boundaries(payload: Dictionary) -> bool:
	if payload.is_empty():
		_fail("Expected generated payload.")
		return false
	if String(payload.get("write_policy", "")) != "staged_payload_only_no_authored_content_write":
		_fail("Generated payload lost staged no-write policy.")
		return false
	var scenario: Dictionary = payload.get("scenario_record", {})
	if bool(scenario.get("selection", {}).get("availability", {}).get("campaign", true)) or bool(scenario.get("selection", {}).get("availability", {}).get("skirmish", true)):
		_fail("Terrain/transit slice adopted generated map into campaign or skirmish UI.")
		return false
	if scenario.has("save_adoption") or scenario.has("alpha_parity_claim"):
		_fail("Terrain/transit slice exposed save or parity claim metadata.")
		return false
	var layers: Dictionary = payload.get("terrain_layers_record", {})
	if layers.get("terrain_layers", []).is_empty() or layers.get("transit_routes", {}).is_empty():
		_fail("Terrain layers record did not pass through terrain/transit semantics.")
		return false
	return true

func _assert_normalization(semantics: Dictionary, expect_unsupported: bool) -> bool:
	if String(semantics.get("schema_id", "")) != RandomMapGeneratorRulesScript.TERRAIN_TRANSIT_SCHEMA_ID:
		_fail("Missing terrain/transit schema payload: %s" % JSON.stringify(semantics))
		return false
	var known: Array = semantics.get("terrain_normalization", {}).get("known_original_terrain_ids", [])
	var unsupported: Array = semantics.get("terrain_normalization", {}).get("unsupported_terrain_ids", [])
	if expect_unsupported and unsupported.is_empty():
		_fail("Unsupported terrain profile did not produce explicit unsupported terrain metadata.")
		return false
	for palette in semantics.get("terrain_normalization", {}).get("zone_palettes", []):
		if not (palette is Dictionary):
			_fail("Zone palette is not a dictionary.")
			return false
		var normalized := String(palette.get("normalized_terrain_id", ""))
		if normalized not in known:
			_fail("Zone palette normalized to unknown terrain without known-id mapping: %s" % JSON.stringify(palette))
			return false
		if not bool(palette.get("passable", false)):
			_fail("Zone palette selected impassable terrain for a generated zone: %s" % JSON.stringify(palette))
			return false
	return true

func _assert_water_semantics(semantics: Dictionary) -> bool:
	var water: Dictionary = semantics.get("water_coast_passability", {})
	if String(water.get("water_mode", "")) != "islands" or int(water.get("water_cell_count", 0)) <= 0 or int(water.get("coast_cell_count", 0)) <= 0:
		_fail("Island water mode missed water/coast passability metadata: %s" % JSON.stringify(water))
		return false
	if String(water.get("water_passability", "")).find("impassable") < 0:
		_fail("Water passability metadata did not mark water as deferred/impassable.")
		return false
	var found_water_access := false
	for candidate in semantics.get("transit_routes", {}).get("water_access_candidates", []):
		if candidate is Dictionary and String(candidate.get("transit_semantics", {}).get("kind", "")) == "water_crossing_deferred":
			found_water_access = true
			if "ferry" not in candidate.get("transit_semantics", {}).get("materialization_options", []):
				_fail("Water transit candidate missed ferry/boat/shipyard options: %s" % JSON.stringify(candidate))
				return false
	if not found_water_access:
		_fail("Island water mode did not produce deferred water transit candidates.")
		return false
	return true

func _assert_underground_semantics(semantics: Dictionary) -> bool:
	var underground_layer_found := false
	for layer in semantics.get("terrain_layers", []):
		if not (layer is Dictionary):
			continue
		if String(layer.get("level_kind", "")) == "underground":
			underground_layer_found = true
			if not bool(layer.get("cave_metadata", {}).get("is_cave", false)) or String(layer.get("default_terrain_id", "")) != "cavern":
				_fail("Underground layer missed cave metadata: %s" % JSON.stringify(layer))
				return false
	if not underground_layer_found:
		_fail("Underground request did not produce underground terrain layer metadata.")
		return false
	if semantics.get("transit_routes", {}).get("cross_level_candidates", []).is_empty():
		_fail("Underground request did not produce cross-level transit candidates.")
		return false
	return true

func _assert_land_and_underground_routes(semantics: Dictionary) -> bool:
	var kinds := {}
	for route in semantics.get("transit_routes", {}).get("corridor_routes", []):
		if route is Dictionary:
			kinds[String(route.get("transit_semantics", {}).get("kind", ""))] = true
	if not kinds.has("land_road") or not kinds.has("underground_subterranean_connection_deferred"):
		_fail("Corridor route semantics missed land or underground classifications: %s" % JSON.stringify(kinds))
		return false
	return true

func _assert_land_routes(semantics: Dictionary) -> bool:
	for route in semantics.get("transit_routes", {}).get("corridor_routes", []):
		if route is Dictionary and String(route.get("transit_semantics", {}).get("kind", "")) == "land_road":
			return true
	_fail("Corridor route semantics missed land road classification.")
	return false

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
