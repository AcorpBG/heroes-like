class_name RandomMapGeneratorRules
extends RefCounted

const GENERATOR_VERSION := "random_map_seeded_core_v1"
const PAYLOAD_SCHEMA_ID := "generated_random_map_payload_v1"
const REPORT_SCHEMA_ID := "random_map_seed_determinism_report_v1"
const TEMPLATE_ID := "aurelion_seeded_spoke_profile_v1"
const RNG_MODULUS := 2147483647
const RNG_MULTIPLIER := 48271
const HASH_MODULUS := 4294967296
const HEX_DIGITS := "0123456789abcdef"

const DEFAULT_FACTIONS := [
	"faction_embercourt",
	"faction_mireclaw",
	"faction_sunvault",
	"faction_thornwake",
]
const DEFAULT_TOWN_BY_FACTION := {
	"faction_embercourt": "town_riverwatch",
	"faction_mireclaw": "town_duskfen",
	"faction_sunvault": "town_prismhearth",
	"faction_thornwake": "town_thornwake_graftroot_caravan",
	"faction_brasshollow": "town_brasshollow_orevein_gantry",
	"faction_veilmourn": "town_veilmourn_bellwake_harbor",
}
const TERRAIN_BY_FACTION := {
	"faction_embercourt": "grass",
	"faction_mireclaw": "swamp",
	"faction_sunvault": "plains",
	"faction_thornwake": "forest",
	"faction_brasshollow": "highland",
	"faction_veilmourn": "water",
}
const CORE_TERRAIN_POOL := ["grass", "plains", "forest", "swamp", "highland"]
const SUPPORT_RESOURCE_SITES := [
	{"purpose": "start_support_wood", "site_id": "site_wood_wagon", "offset": Vector2i(2, 0)},
	{"purpose": "start_support_ore", "site_id": "site_ore_crates", "offset": Vector2i(0, 2)},
	{"purpose": "start_support_cache", "site_id": "site_waystone_cache", "offset": Vector2i(-2, 0)},
]
const DEFAULT_ENCOUNTER_ID := "encounter_mire_raid"
const ROAD_OVERLAY_ID := "generated_dirt_road"
const BLOCKED_TERRAIN_IDS := ["water"]
const BIOME_BY_TERRAIN := {
	"grass": "biome_grasslands",
	"plains": "biome_grasslands",
	"forest": "biome_deep_forest",
	"swamp": "biome_mire_fen",
	"mire": "biome_mire_fen",
	"highland": "biome_highland_ridge",
	"hills": "biome_highland_ridge",
	"ridge": "biome_highland_ridge",
	"water": "biome_coast_archipelago",
	"coast": "biome_coast_archipelago",
	"shore": "biome_coast_archipelago",
}
const TERRAIN_MOVEMENT_COST := {
	"grass": 1,
	"plains": 1,
	"forest": 2,
	"swamp": 2,
	"mire": 2,
	"highland": 2,
	"hills": 2,
	"ridge": 2,
	"water": 999,
}
const SUPPORT_RESOURCE_VALUE_BY_SITE := {
	"site_wood_wagon": {"gold": 0, "wood": 4, "ore": 0},
	"site_ore_crates": {"gold": 0, "wood": 0, "ore": 4},
	"site_waystone_cache": {"gold": 900, "wood": 0, "ore": 0},
}
const EARLY_RESOURCE_MINIMUMS := {"gold": 600, "wood": 4, "ore": 4}
const ROUTE_DISTANCE_WARNING_SPREAD := 10
const ROUTE_DISTANCE_FAIL_SPREAD := 20
const PRESSURE_WARNING_SPREAD := 900
const PRESSURE_FAIL_SPREAD := 1800

class DeterministicRng:
	var _state := 1

	func _init(seed_value: int) -> void:
		_state = max(1, seed_value)

	func next_float() -> float:
		_state = int((_state * RandomMapGeneratorRules.RNG_MULTIPLIER) % RandomMapGeneratorRules.RNG_MODULUS)
		return float(_state) / float(RandomMapGeneratorRules.RNG_MODULUS)

	func next_index(size: int) -> int:
		if size <= 0:
			return 0
		return min(size - 1, int(floor(next_float() * float(size))))

	func jitter(amount: float) -> float:
		return (next_float() * 2.0 - 1.0) * amount

static func generate(input_config: Dictionary) -> Dictionary:
	var normalized := normalize_config(input_config)
	var rng := DeterministicRng.new(_positive_seed(_stable_stringify(normalized)))
	var phases := []

	var template := _build_runtime_template(normalized)
	phases.append(_phase_record("template_profile", template))

	var zones := _build_runtime_zones(template, normalized, rng)
	phases.append(_phase_record("runtime_zone_graph", {"zone_count": zones.size(), "link_count": template.get("links", []).size()}))

	var seeds := _place_zone_seeds(zones, normalized, rng)
	phases.append(_phase_record("zone_seed_layout", {"seed_count": seeds.size()}))

	var zone_grid := _assign_cells_to_zones(zones, seeds, normalized)
	phases.append(_phase_record("terrain_owner_grid", {"width": int(normalized.get("size", {}).get("width", 0)), "height": int(normalized.get("size", {}).get("height", 0))}))

	var terrain_rows := _terrain_rows_from_zone_grid(zone_grid, zones)
	phases.append(_phase_record("terrain_biome_coherence", _terrain_phase_summary(terrain_rows, zones)))

	var placements := _place_generated_objects(zones, template.get("links", []), seeds, zone_grid, terrain_rows, normalized, rng)
	phases.append(_phase_record("object_placement_staging", _placement_counts(placements.get("object_placements", []))))

	var constraints := _build_constraint_payload(normalized, zones, template.get("links", []), seeds, zone_grid, terrain_rows, placements)
	phases.append(_phase_record("route_road_constraint_writeout", {
		"road_segment_count": int(constraints.get("road_network", {}).get("road_segments", []).size()),
		"required_reachability": String(constraints.get("route_reachability_proof", {}).get("status", "unknown")),
	}))
	phases.append(_phase_record("resource_encounter_fairness_report", {
		"status": String(constraints.get("fairness_report", {}).get("status", "unknown")),
		"start_count": int(constraints.get("fairness_report", {}).get("early_resource_support", {}).get("per_start", []).size()),
		"guard_route_count": int(constraints.get("fairness_report", {}).get("guard_pressure", {}).get("route_guards", []).size()),
	}))

	var scenario_record := _build_scenario_record(normalized, terrain_rows, placements, constraints)
	var terrain_layers_record := _build_terrain_layers_record(normalized, constraints)
	var staging := _build_staging_payload(normalized, template, zones, seeds, zone_grid, placements, constraints)

	var generated_map := {
		"schema_id": PAYLOAD_SCHEMA_ID,
		"source": "generated_random_map",
		"write_policy": "staged_payload_only_no_authored_content_write",
		"metadata": _metadata(normalized),
		"phase_pipeline": phases,
		"staging": staging,
		"scenario_record": scenario_record,
		"terrain_layers_record": terrain_layers_record,
	}
	generated_map["stable_signature"] = _hash32_hex(_stable_stringify(generated_map))

	var report := validate_generated_payload(generated_map)
	return {
		"ok": bool(report.get("ok", false)),
		"generated_map": generated_map,
		"report": report,
	}

static func seed_determinism_report(input_config: Dictionary) -> Dictionary:
	var first := generate(input_config)
	var second := generate(input_config)
	var changed_config := input_config.duplicate(true)
	changed_config["seed"] = "%s:changed" % String(input_config.get("seed", "0"))
	var third := generate(changed_config)
	var first_payload: Dictionary = first.get("generated_map", {})
	var second_payload: Dictionary = second.get("generated_map", {})
	var third_payload: Dictionary = third.get("generated_map", {})
	var same_payload := _stable_stringify(first_payload) == _stable_stringify(second_payload)
	var same_signature := String(first_payload.get("stable_signature", "")) == String(second_payload.get("stable_signature", ""))
	var changed_seed_changes_payload := String(first_payload.get("stable_signature", "")) != String(third_payload.get("stable_signature", ""))
	var first_validation: Dictionary = first.get("report", {})
	var second_validation: Dictionary = second.get("report", {})
	var third_validation: Dictionary = third.get("report", {})
	var ok := bool(first.get("ok", false)) and bool(second.get("ok", false)) and same_payload and same_signature and changed_seed_changes_payload
	return {
		"ok": ok,
		"schema_id": REPORT_SCHEMA_ID,
		"generator_version": String(first_payload.get("metadata", {}).get("generator_version", "")),
		"normalized_seed": String(first_payload.get("metadata", {}).get("normalized_seed", "")),
		"profile_id": String(first_payload.get("metadata", {}).get("profile", {}).get("id", "")),
		"same_input_payload_equivalent": same_payload,
		"same_input_signature_equivalent": same_signature,
		"changed_seed_changes_payload": changed_seed_changes_payload,
		"stable_signature": String(first_payload.get("stable_signature", "")),
		"changed_seed_signature": String(third_payload.get("stable_signature", "")),
		"first_validation": first_validation,
		"second_validation": second_validation,
		"changed_seed_validation": third_validation,
		"determinism_sources_excluded": [
			"runtime_clock",
			"filesystem_order",
			"renderer_state",
			"editor_state",
			"unordered_dictionary_iteration",
		],
	}

static func resource_encounter_fairness_report(generated_map: Dictionary) -> Dictionary:
	var staging: Dictionary = generated_map.get("staging", {})
	var scenario: Dictionary = generated_map.get("scenario_record", {})
	var placements := {
		"object_placements": staging.get("object_placements", []),
		"towns": scenario.get("towns", []),
		"resource_nodes": scenario.get("resource_nodes", []),
		"encounters": scenario.get("encounters", []),
	}
	return _fairness_report_payload(
		generated_map.get("metadata", {}),
		staging.get("zones", []),
		placements,
		staging.get("route_graph", {}),
		staging.get("route_reachability_proof", {}),
		scenario.get("objectives", {})
	)

static func normalize_config(input_config: Dictionary) -> Dictionary:
	var generator_version := String(input_config.get("generator_version", GENERATOR_VERSION)).strip_edges()
	if generator_version == "":
		generator_version = GENERATOR_VERSION
	var normalized_seed := String(input_config.get("seed", "0")).strip_edges()
	if normalized_seed == "":
		normalized_seed = "0"
	var size := _normalize_size(input_config.get("size", input_config.get("map_size", "small")))
	var player_constraints := _normalize_player_constraints(input_config.get("player_constraints", input_config.get("players", {})))
	var profile := _normalize_profile(input_config.get("profile", {}), player_constraints)
	var content_manifest := {
		"faction_ids": profile.get("faction_ids", []),
		"town_ids": profile.get("town_ids", []),
		"resource_site_ids": profile.get("resource_site_ids", []),
		"encounter_ids": [String(profile.get("encounter_id", DEFAULT_ENCOUNTER_ID))],
		"terrain_ids": profile.get("terrain_ids", []),
	}
	return {
		"generator_version": generator_version,
		"seed": normalized_seed,
		"size": size,
		"player_constraints": player_constraints,
		"profile": profile,
		"content_manifest_fingerprint": _hash32_hex(_stable_stringify(content_manifest)),
	}

static func validate_generated_payload(generated_map: Dictionary) -> Dictionary:
	var failures := []
	var warnings := []
	var metadata: Dictionary = generated_map.get("metadata", {})
	var scenario: Dictionary = generated_map.get("scenario_record", {})
	var staging: Dictionary = generated_map.get("staging", {})
	var terrain_rows: Array = scenario.get("map", [])
	var map_size: Dictionary = scenario.get("map_size", {})
	var width := int(map_size.get("width", 0))
	var height := int(map_size.get("height", 0))
	if String(generated_map.get("schema_id", "")) != PAYLOAD_SCHEMA_ID:
		failures.append("payload schema_id mismatch")
	if String(generated_map.get("write_policy", "")) != "staged_payload_only_no_authored_content_write":
		failures.append("generated payload lost no-write boundary")
	if String(metadata.get("generator_version", "")) == "" or String(metadata.get("normalized_seed", "")) == "":
		failures.append("metadata must include normalized seed and generator version")
	if terrain_rows.size() != height:
		failures.append("terrain row count %d did not match height %d" % [terrain_rows.size(), height])
	for y in range(terrain_rows.size()):
		var row = terrain_rows[y]
		if not (row is Array) or row.size() != width:
			failures.append("terrain row %d width mismatch" % y)
	var placement_ids := {}
	for placement in staging.get("object_placements", []):
		if not (placement is Dictionary):
			failures.append("non-dictionary object placement")
			continue
		var placement_id := String(placement.get("placement_id", ""))
		if placement_id == "":
			failures.append("object placement missing placement_id")
		if placement_ids.has(placement_id):
			failures.append("duplicate placement_id %s" % placement_id)
		placement_ids[placement_id] = true
		var x := int(placement.get("x", -1))
		var y := int(placement.get("y", -1))
		if x < 0 or y < 0 or x >= width or y >= height:
			failures.append("placement %s is out of bounds" % placement_id)
	var route_graph: Dictionary = staging.get("route_graph", {})
	if route_graph.get("edges", []).is_empty():
		failures.append("route graph must expose at least one generated edge")
	var terrain_constraints: Dictionary = staging.get("terrain_constraints", {})
	var town_start_constraints: Dictionary = staging.get("town_start_constraints", {})
	var road_network: Dictionary = staging.get("road_network", {})
	var reachability: Dictionary = staging.get("route_reachability_proof", {})
	var fairness_report: Dictionary = staging.get("fairness_report", {})
	if terrain_constraints.is_empty():
		failures.append("terrain constraints payload missing")
	if String(terrain_constraints.get("coherence_model", "")) == "":
		failures.append("terrain constraints must expose coherence model")
	if terrain_constraints.get("passability_grid", []).is_empty():
		failures.append("terrain constraints must expose passability grid")
	for zone_summary in terrain_constraints.get("zone_biome_summary", []):
		if zone_summary is Dictionary and String(zone_summary.get("role", "")).contains("start") and not bool(zone_summary.get("passable", false)):
			failures.append("start zone %s uses impassable terrain" % String(zone_summary.get("zone_id", "")))
	if String(town_start_constraints.get("schema_id", "")) != "random_map_town_start_constraints_v1":
		failures.append("town/start constraints payload missing")
	for start_constraint in town_start_constraints.get("player_starts", []):
		if not (start_constraint is Dictionary):
			failures.append("non-dictionary start constraint")
			continue
		if String(start_constraint.get("viability", "")) != "pass":
			failures.append("start constraint %s is not viable" % String(start_constraint.get("primary_town_placement_id", "")))
		if int(start_constraint.get("contest_route_count", 0)) < 1 or int(start_constraint.get("expansion_route_count", 0)) < 1:
			failures.append("start constraint %s lacks expansion or contest route" % String(start_constraint.get("primary_town_placement_id", "")))
	if String(road_network.get("writeout_policy", "")) != "staged_overlay_payload_only_no_authored_tile_write":
		failures.append("road network must keep staged no-write overlay boundary")
	if road_network.get("road_segments", []).is_empty():
		failures.append("road network must expose staged road segments")
	if String(reachability.get("status", "")) != "pass":
		failures.append("required route reachability proof failed")
	_validate_road_paths(road_network, terrain_rows, staging.get("object_placements", []), failures)
	if String(fairness_report.get("schema_id", "")) != "random_map_resource_encounter_fairness_report_v1":
		failures.append("resource/encounter fairness report missing")
	else:
		if String(fairness_report.get("status", "")) == "fail":
			failures.append("resource/encounter fairness report failed")
		for fairness_warning in fairness_report.get("warnings", []):
			warnings.append(String(fairness_warning))
	var phase_names := []
	for phase in generated_map.get("phase_pipeline", []):
		if phase is Dictionary:
			phase_names.append(String(phase.get("phase", "")))
	for required_phase in ["template_profile", "runtime_zone_graph", "zone_seed_layout", "terrain_owner_grid", "terrain_biome_coherence", "object_placement_staging", "route_road_constraint_writeout", "resource_encounter_fairness_report"]:
		if required_phase not in phase_names:
			failures.append("missing generation phase %s" % required_phase)
	if scenario.get("towns", []).is_empty():
		warnings.append("minimal core payload has no town placements")
	if scenario.get("resource_nodes", []).is_empty():
		warnings.append("minimal core payload has no resource nodes")
	return {
		"ok": failures.is_empty(),
		"status": "pass" if failures.is_empty() else "fail",
		"failure_count": failures.size(),
		"warning_count": warnings.size(),
		"failures": failures,
		"warnings": warnings,
		"map_size": {"width": width, "height": height},
		"placement_counts": _placement_counts(staging.get("object_placements", [])),
		"route_edge_count": int(route_graph.get("edges", []).size()),
		"road_segment_count": int(road_network.get("road_segments", []).size()),
		"required_reachability_status": String(reachability.get("status", "")),
		"fairness_status": String(fairness_report.get("status", "")),
		"fairness_summary": fairness_report.get("summary", {}),
	}

static func _build_runtime_template(normalized: Dictionary) -> Dictionary:
	var player_count := int(normalized.get("player_constraints", {}).get("player_count", 2))
	var zones := []
	for index in range(player_count):
		zones.append({
			"id": "start_%d" % (index + 1),
			"role": "human_start" if index == 0 else "computer_start",
			"base_size": 18,
			"owner_slot": index + 1,
			"terrain_match_to_faction": true,
		})
	zones.append({"id": "junction_1", "role": "junction", "base_size": 10, "owner_slot": null, "terrain_match_to_faction": false})
	for index in range(max(2, player_count)):
		zones.append({"id": "reward_%d" % (index + 1), "role": "treasure", "base_size": 8, "owner_slot": null, "terrain_match_to_faction": false})
	var links := []
	for index in range(player_count):
		var start_id := "start_%d" % (index + 1)
		var reward_id := "reward_%d" % ((index % max(2, player_count)) + 1)
		links.append({"from": start_id, "to": "junction_1", "role": "contest_route", "guard_value": 600, "wide": false, "border_guard": false})
		links.append({"from": start_id, "to": reward_id, "role": "early_reward_route", "guard_value": 150, "wide": false, "border_guard": false})
	for index in range(max(2, player_count)):
		links.append({"from": "reward_%d" % (index + 1), "to": "junction_1", "role": "reward_to_junction", "guard_value": 300, "wide": index == 0, "border_guard": false})
	return {
		"id": TEMPLATE_ID,
		"model": "staged_template_profile_graph",
		"zones": zones,
		"links": links,
	}

static func _build_runtime_zones(template: Dictionary, normalized: Dictionary, rng: DeterministicRng) -> Array:
	var profile: Dictionary = normalized.get("profile", {})
	var faction_ids: Array = profile.get("faction_ids", [])
	var terrain_ids: Array = profile.get("terrain_ids", [])
	var zones := []
	for zone_record in template.get("zones", []):
		if not (zone_record is Dictionary):
			continue
		var owner_slot = zone_record.get("owner_slot", null)
		var faction_id := ""
		if owner_slot != null:
			faction_id = String(faction_ids[(int(owner_slot) - 1) % faction_ids.size()])
		var terrain_id := _zone_terrain(zone_record, faction_id, terrain_ids, rng)
		zones.append({
			"id": String(zone_record.get("id", "")),
			"source_id": String(zone_record.get("id", "")),
			"role": String(zone_record.get("role", "treasure")),
			"owner_slot": owner_slot,
			"player_slot": owner_slot,
			"faction_id": faction_id,
			"terrain_id": terrain_id,
			"base_size": int(zone_record.get("base_size", 1)),
			"anchor": {},
			"bounds": {},
			"cell_count": 0,
		})
	return zones

static func _zone_terrain(zone_record: Dictionary, faction_id: String, terrain_ids: Array, rng: DeterministicRng) -> String:
	if bool(zone_record.get("terrain_match_to_faction", false)) and TERRAIN_BY_FACTION.has(faction_id):
		var matched := String(TERRAIN_BY_FACTION.get(faction_id))
		if matched in terrain_ids and _terrain_is_passable(matched):
			return matched
	if terrain_ids.is_empty():
		return "grass"
	var passable_choices := []
	for terrain_id in terrain_ids:
		if _terrain_is_passable(String(terrain_id)):
			passable_choices.append(String(terrain_id))
	if not passable_choices.is_empty():
		return String(passable_choices[rng.next_index(passable_choices.size())])
	return "grass"

static func _place_zone_seeds(zones: Array, normalized: Dictionary, rng: DeterministicRng) -> Dictionary:
	var size: Dictionary = normalized.get("size", {})
	var width := int(size.get("width", 16))
	var height := int(size.get("height", 12))
	var center: Vector2 = Vector2((float(width) - 1.0) * 0.5, (float(height) - 1.0) * 0.5)
	var radius_x: float = max(3.0, float(width) * 0.36)
	var radius_y: float = max(2.0, float(height) * 0.32)
	var starts: Array = _zones_with_owner(zones)
	var others: Array = _zones_without_owner(zones)
	var angle_offset: float = rng.next_float() * TAU
	var seeds: Dictionary = {}
	for index in range(starts.size()):
		var zone: Dictionary = starts[index]
		var angle := angle_offset + TAU * float(index) / float(max(1, starts.size()))
		seeds[String(zone.get("id", ""))] = _point_dict(
			clampi(int(round(center.x + cos(angle) * radius_x + rng.jitter(1.0))), 1, max(1, width - 2)),
			clampi(int(round(center.y + sin(angle) * radius_y + rng.jitter(1.0))), 1, max(1, height - 2))
		)
	for index in range(others.size()):
		var zone: Dictionary = others[index]
		var role := String(zone.get("role", "treasure"))
		var angle := angle_offset + TAU * (float(index) + 0.5) / float(max(1, others.size()))
		var radius_scale := 0.18 if role == "junction" else 0.58
		seeds[String(zone.get("id", ""))] = _point_dict(
			clampi(int(round(center.x + cos(angle) * radius_x * radius_scale + rng.jitter(1.4))), 1, max(1, width - 2)),
			clampi(int(round(center.y + sin(angle) * radius_y * radius_scale + rng.jitter(1.2))), 1, max(1, height - 2))
		)
	return _resolve_seed_collisions(seeds, width, height)

static func _assign_cells_to_zones(zones: Array, seeds: Dictionary, normalized: Dictionary) -> Array:
	var size: Dictionary = normalized.get("size", {})
	var width := int(size.get("width", 16))
	var height := int(size.get("height", 12))
	var zone_grid := []
	for y in range(height):
		var row := []
		for x in range(width):
			row.append(_nearest_zone_id(x, y, zones, seeds))
		zone_grid.append(row)
	for zone in zones:
		if not (zone is Dictionary):
			continue
		var seed: Dictionary = seeds.get(String(zone.get("id", "")), {})
		if not seed.is_empty():
			zone_grid[int(seed.get("y", 0))][int(seed.get("x", 0))] = String(zone.get("id", ""))
	_update_zone_geometry(zones, zone_grid)
	return zone_grid

static func _place_generated_objects(zones: Array, links: Array, seeds: Dictionary, zone_grid: Array, terrain_rows: Array, normalized: Dictionary, rng: DeterministicRng) -> Dictionary:
	var profile: Dictionary = normalized.get("profile", {})
	var town_ids: Array = profile.get("town_ids", [])
	var placements := []
	var towns := []
	var resource_nodes := []
	var encounters := []
	var occupied := {}
	var player_index := 0
	for zone in zones:
		if not (zone is Dictionary) or zone.get("owner_slot", null) == null:
			continue
		var seed: Dictionary = seeds.get(String(zone.get("id", "")), {})
		var point := _nearest_free_cell(int(seed.get("x", 0)), int(seed.get("y", 0)), String(zone.get("id", "")), zone_grid, terrain_rows, occupied, rng)
		if point.is_empty():
			continue
		var owner := "player" if int(zone.get("owner_slot", 0)) == 1 else "enemy"
		var faction_id := String(zone.get("faction_id", ""))
		var town_id := String(town_ids[player_index % town_ids.size()])
		var placement_id := "rmg_town_p%d" % (player_index + 1)
		var town := {"placement_id": placement_id, "town_id": town_id, "faction_id": faction_id, "player_slot": int(zone.get("owner_slot", 0)), "x": int(point.get("x", 0)), "y": int(point.get("y", 0)), "owner": owner}
		towns.append(town)
		placements.append(_object_placement(placement_id, "town", faction_id, String(zone.get("id", "")), point, {"town_id": town_id, "owner": owner, "player_slot": int(zone.get("owner_slot", 0)), "purpose": "player_start"}))
		_mark_occupied(occupied, point)
		for resource_index in range(SUPPORT_RESOURCE_SITES.size()):
			var resource: Dictionary = SUPPORT_RESOURCE_SITES[resource_index]
			var support_point := _nearest_free_cell(
				int(point.get("x", 0)) + resource.get("offset", Vector2i.ZERO).x,
				int(point.get("y", 0)) + resource.get("offset", Vector2i.ZERO).y,
				String(zone.get("id", "")),
				zone_grid,
				terrain_rows,
				occupied,
				rng
			)
			if support_point.is_empty():
				continue
			var resource_placement_id := "rmg_%s_p%d" % [String(resource.get("purpose", "resource")), player_index + 1]
			resource_nodes.append({"placement_id": resource_placement_id, "site_id": String(resource.get("site_id", "")), "x": int(support_point.get("x", 0)), "y": int(support_point.get("y", 0))})
			placements.append(_object_placement(resource_placement_id, "resource_site", faction_id, String(zone.get("id", "")), support_point, {"site_id": String(resource.get("site_id", "")), "purpose": String(resource.get("purpose", ""))}))
			_mark_occupied(occupied, support_point)
		player_index += 1
	for index in range(links.size()):
		var link: Dictionary = links[index]
		var from_seed: Dictionary = seeds.get(String(link.get("from", "")), {})
		var to_seed: Dictionary = seeds.get(String(link.get("to", "")), {})
		if from_seed.is_empty() or to_seed.is_empty():
			continue
		var guard_point := _nearest_free_cell(
			int(round((int(from_seed.get("x", 0)) + int(to_seed.get("x", 0))) * 0.5)),
			int(round((int(from_seed.get("y", 0)) + int(to_seed.get("y", 0))) * 0.5)),
			null,
			zone_grid,
			terrain_rows,
			occupied,
			rng
		)
		if guard_point.is_empty():
			continue
		var encounter_placement_id := "rmg_link_guard_%02d" % (index + 1)
		encounters.append({"placement_id": encounter_placement_id, "encounter_id": String(profile.get("encounter_id", DEFAULT_ENCOUNTER_ID)), "x": int(guard_point.get("x", 0)), "y": int(guard_point.get("y", 0)), "difficulty": "generated_core"})
		placements.append(_object_placement(encounter_placement_id, "route_guard", "", _zone_at_point(zone_grid, guard_point), guard_point, {"encounter_id": String(profile.get("encounter_id", DEFAULT_ENCOUNTER_ID)), "purpose": String(link.get("role", "route")), "guard_value": int(link.get("guard_value", 0)), "wide": bool(link.get("wide", false)), "border_guard": bool(link.get("border_guard", false))}))
		_mark_occupied(occupied, guard_point)
	_annotate_pathing_metadata(placements, towns, resource_nodes, encounters, zone_grid, terrain_rows, occupied)
	return {
		"object_placements": placements,
		"towns": towns,
		"resource_nodes": resource_nodes,
		"encounters": encounters,
	}

static func _build_scenario_record(normalized: Dictionary, terrain_rows: Array, placements: Dictionary, constraints: Dictionary) -> Dictionary:
	var metadata := _metadata(normalized)
	var size: Dictionary = normalized.get("size", {})
	var player_constraints: Dictionary = normalized.get("player_constraints", {})
	var profile: Dictionary = normalized.get("profile", {})
	var towns: Array = placements.get("towns", [])
	var start := {"x": 0, "y": 0}
	if not towns.is_empty() and towns[0] is Dictionary:
		start = {"x": int(towns[0].get("x", 0)), "y": int(towns[0].get("y", 0))}
	var scenario_id := "generated_%s_%s" % [String(profile.get("id", "seeded_core")), _hash32_hex(_stable_stringify(metadata))]
	var faction_ids: Array = profile.get("faction_ids", [])
	return {
		"id": scenario_id,
		"name": "Generated Prototype %s" % String(profile.get("label", "Seeded Core")),
		"generated": true,
		"generated_metadata": metadata,
		"selection": {
			"summary": "Generated deterministic prototype map for tooling inspection.",
			"recommended_difficulty": "normal",
			"map_size_label": "%dx%d generated" % [int(size.get("width", 0)), int(size.get("height", 0))],
			"player_summary": "%d generated player slots." % int(player_constraints.get("player_count", 0)),
			"enemy_summary": "Generated opponents are staged only; runtime adoption is deferred.",
			"availability": {"campaign": false, "skirmish": false},
		},
		"map_size": {"width": int(size.get("width", 0)), "height": int(size.get("height", 0))},
		"player_faction_id": String(faction_ids[0]) if not faction_ids.is_empty() else "faction_embercourt",
		"player_army_id": "",
		"hero_id": "",
		"starting_resources": {"gold": 1500, "wood": 4, "ore": 3},
		"map": terrain_rows,
		"start": start,
		"hero_starts": [],
		"towns": placements.get("towns", []),
		"resource_nodes": placements.get("resource_nodes", []),
		"artifact_nodes": [],
		"encounters": placements.get("encounters", []),
		"objectives": {
			"victory_text": "Generated prototype objective completed.",
			"defeat_text": "Generated prototype objective failed.",
			"victory": [],
			"defeat": [],
		},
		"script_hooks": [],
		"enemy_factions": [],
		"generated_constraints": {
			"terrain": constraints.get("terrain_constraints", {}),
			"town_starts": constraints.get("town_start_constraints", {}),
			"roads": constraints.get("road_network", {}),
			"reachability": constraints.get("route_reachability_proof", {}),
			"fairness": constraints.get("fairness_report", {}),
		},
	}

static func _build_terrain_layers_record(normalized: Dictionary, constraints: Dictionary) -> Dictionary:
	var profile: Dictionary = normalized.get("profile", {})
	var metadata := _metadata(normalized)
	var road_network: Dictionary = constraints.get("road_network", {})
	return {
		"id": "generated_layers_%s_%s" % [String(profile.get("id", "seeded_core")), _hash32_hex(_stable_stringify(metadata))],
		"terrain_layer_status": "generated_staged_draft",
		"generated_metadata": metadata,
		"roads": road_network.get("road_segments", []),
		"road_stubs": road_network.get("road_stubs", []),
		"route_graph_stub": constraints.get("route_graph", {}),
		"deferred": ["durable_road_tile_writeout", "river_overlay_writeout"],
	}

static func _build_staging_payload(normalized: Dictionary, template: Dictionary, zones: Array, seeds: Dictionary, zone_grid: Array, placements: Dictionary, constraints: Dictionary) -> Dictionary:
	return {
		"staging_schema": "random_map_generation_staging_v1",
		"template": template,
		"zones": _zones_for_payload(zones),
		"zone_seed_points": _sorted_point_dict(seeds),
		"terrain_owner_grid": zone_grid,
		"terrain_constraints": constraints.get("terrain_constraints", {}),
		"town_start_constraints": constraints.get("town_start_constraints", {}),
		"road_network": constraints.get("road_network", {}),
		"route_reachability_proof": constraints.get("route_reachability_proof", {}),
		"route_graph": constraints.get("route_graph", _route_graph_payload(template.get("links", []), seeds)),
		"fairness_report": constraints.get("fairness_report", {}),
		"object_placements": placements.get("object_placements", []),
		"metadata": _metadata(normalized),
		"editable_grid_model": "terrain_owner_grid_rows_plus_separate_object_placement_arrays",
	}

static func _build_constraint_payload(normalized: Dictionary, zones: Array, links: Array, seeds: Dictionary, zone_grid: Array, terrain_rows: Array, placements: Dictionary) -> Dictionary:
	var terrain_constraints := _terrain_constraints_payload(terrain_rows, zone_grid, zones)
	var occupied := _occupied_body_lookup(placements.get("object_placements", []))
	var route_build := _build_route_and_road_payload(links, seeds, placements, terrain_rows, occupied)
	var town_start_constraints := _town_start_constraints_payload(zones, placements, route_build.get("route_graph", {}), route_build.get("route_reachability_proof", {}))
	var fairness_report := _fairness_report_payload(normalized, zones, placements, route_build.get("route_graph", {}), route_build.get("route_reachability_proof", {}))
	return {
		"terrain_constraints": terrain_constraints,
		"town_start_constraints": town_start_constraints,
		"road_network": route_build.get("road_network", {}),
		"route_graph": route_build.get("route_graph", _route_graph_payload(links, seeds)),
		"route_reachability_proof": route_build.get("route_reachability_proof", {}),
		"fairness_report": fairness_report,
		"metadata": _metadata(normalized),
	}

static func _terrain_constraints_payload(terrain_rows: Array, zone_grid: Array, zones: Array) -> Dictionary:
	var passability_rows := []
	var biome_rows := []
	var terrain_counts := {}
	var blocked_cells := []
	for y in range(terrain_rows.size()):
		var terrain_row: Array = terrain_rows[y]
		var pass_row := []
		var biome_row := []
		for x in range(terrain_row.size()):
			var terrain_id := String(terrain_row[x])
			var passable := _terrain_is_passable(terrain_id)
			pass_row.append(passable)
			biome_row.append(_biome_for_terrain(terrain_id))
			terrain_counts[terrain_id] = int(terrain_counts.get(terrain_id, 0)) + 1
			if not passable:
				blocked_cells.append(_point_dict(x, y))
		passability_rows.append(pass_row)
		biome_rows.append(biome_row)
	var zone_summaries := []
	for zone in zones:
		if not (zone is Dictionary):
			continue
		var terrain_id := String(zone.get("terrain_id", "grass"))
		zone_summaries.append({
			"zone_id": String(zone.get("id", "")),
			"role": String(zone.get("role", "")),
			"biome_id": _biome_for_terrain(terrain_id),
			"terrain_id": terrain_id,
			"passable": _terrain_is_passable(terrain_id),
			"cell_count": int(zone.get("cell_count", 0)),
			"bounds": zone.get("bounds", {}),
		})
	return {
		"coherence_model": "zone_biome_fill_with_deterministic_island_smoothing_and_passability_grid",
		"biome_by_terrain": _sorted_dict(BIOME_BY_TERRAIN),
		"passability_source": "content_biome_passable_semantics_collapsed_for_generated_payload",
		"passability_grid": passability_rows,
		"biome_grid": biome_rows,
		"blocked_cells": blocked_cells,
		"terrain_counts": _sorted_dict(terrain_counts),
		"region_count_by_terrain": _terrain_region_counts(terrain_rows),
		"zone_biome_summary": zone_summaries,
	}

static func _build_route_and_road_payload(links: Array, seeds: Dictionary, placements: Dictionary, terrain_rows: Array, occupied: Dictionary) -> Dictionary:
	var object_by_zone := _object_placements_by_zone_and_kind(placements.get("object_placements", []))
	var route_nodes := _route_nodes_payload(seeds, placements)
	var road_segments := []
	var road_stubs := []
	var edges := []
	var adjacency := {}
	var edge_index := 1
	for link in links:
		if not (link is Dictionary):
			continue
		var from_zone := String(link.get("from", ""))
		var to_zone := String(link.get("to", ""))
		var from_node := _preferred_route_node_for_zone(from_zone, object_by_zone, route_nodes)
		var to_node := _preferred_route_node_for_zone(to_zone, object_by_zone, route_nodes)
		var from_point: Dictionary = from_node.get("point", seeds.get(from_zone, {}))
		var to_point: Dictionary = to_node.get("point", seeds.get(to_zone, {}))
		var path := _find_passable_path(from_point, to_point, terrain_rows, occupied)
		var classification := _route_classification(link, not path.is_empty())
		var edge_id := "edge_%02d_%s_%s" % [edge_index, from_zone, to_zone]
		var required := String(link.get("role", "")) in ["contest_route", "early_reward_route", "reward_to_junction"]
		var edge := {
			"id": edge_id,
			"from": from_zone,
			"to": to_zone,
			"from_node": String(from_node.get("id", from_zone)),
			"to_node": String(to_node.get("id", to_zone)),
			"role": String(link.get("role", "")),
			"guard_value": int(link.get("guard_value", 0)),
			"wide": bool(link.get("wide", false)),
			"border_guard": bool(link.get("border_guard", false)),
			"connectivity_classification": classification,
			"required": required,
			"path_found": not path.is_empty(),
			"path_length": path.size(),
			"from_anchor": from_point,
			"to_anchor": to_point,
			"writeout_state": "staged_road_overlay_payload_no_tile_write",
		}
		edges.append(edge)
		if not path.is_empty():
			road_segments.append(_road_segment_payload(edge_id, path, classification, edge))
			road_stubs.append({"edge_id": edge_id, "node_id": String(from_node.get("id", "")), "point": from_point, "role": "from_stub"})
			road_stubs.append({"edge_id": edge_id, "node_id": String(to_node.get("id", "")), "point": to_point, "role": "to_stub"})
			_connect_adjacency(adjacency, String(from_node.get("id", from_zone)), String(to_node.get("id", to_zone)))
		edge_index += 1
	for town in placements.get("towns", []):
		if not (town is Dictionary):
			continue
		var town_placement_id := String(town.get("placement_id", ""))
		var town_node_id := "node_%s" % town_placement_id
		var town_point := _first_approach_or_body(town)
		for resource in placements.get("resource_nodes", []):
			if not (resource is Dictionary) or String(resource.get("zone_id", "")) != String(town.get("zone_id", "")):
				continue
			var resource_node_id := "node_%s" % String(resource.get("placement_id", ""))
			var resource_point := _first_approach_or_body(resource)
			var resource_path := _find_passable_path(town_point, resource_point, terrain_rows, occupied)
			var resource_edge_id := "edge_%02d_%s_%s" % [edge_index, town_placement_id, String(resource.get("placement_id", ""))]
			var resource_classification := "full_connectivity" if not resource_path.is_empty() else "blocked_connectivity"
			var resource_edge := {
				"id": resource_edge_id,
				"from": town_placement_id,
				"to": String(resource.get("placement_id", "")),
				"from_node": town_node_id,
				"to_node": resource_node_id,
				"role": "required_start_economy_route",
				"guard_value": 0,
				"wide": false,
				"border_guard": false,
				"connectivity_classification": resource_classification,
				"required": true,
				"path_found": not resource_path.is_empty(),
				"path_length": resource_path.size(),
				"from_anchor": town_point,
				"to_anchor": resource_point,
				"writeout_state": "staged_road_overlay_payload_no_tile_write",
			}
			edges.append(resource_edge)
			if not resource_path.is_empty():
				road_segments.append(_road_segment_payload(resource_edge_id, resource_path, resource_classification, resource_edge))
				road_stubs.append({"edge_id": resource_edge_id, "node_id": town_node_id, "point": town_point, "role": "town_stub"})
				road_stubs.append({"edge_id": resource_edge_id, "node_id": resource_node_id, "point": resource_point, "role": "resource_stub"})
				_connect_adjacency(adjacency, town_node_id, resource_node_id)
			edge_index += 1
	var route_graph := {
		"nodes": route_nodes,
		"edges": edges,
		"connection_payload_semantics": {
			"value": "normal_guard_value",
			"wide": "suppresses_normal_guard",
			"border_guard": "special_guarded_connection_mode",
		},
	}
	var proof := _reachability_proof(route_nodes, edges, adjacency)
	return {
		"route_graph": route_graph,
		"road_network": {
			"schema_id": "random_map_road_overlay_staging_v1",
			"writeout_policy": "staged_overlay_payload_only_no_authored_tile_write",
			"overlay_id": ROAD_OVERLAY_ID,
			"road_segments": road_segments,
			"road_stubs": road_stubs,
			"blocked_body_policy": "paths_exclude_object_body_tiles_and_impassable_terrain",
		},
		"route_reachability_proof": proof,
	}

static func _town_start_constraints_payload(zones: Array, placements: Dictionary, route_graph: Dictionary, proof: Dictionary) -> Dictionary:
	var route_counts := _route_counts_by_zone(route_graph.get("edges", []))
	var starts := []
	var towns: Array = placements.get("towns", [])
	for town in towns:
		if not (town is Dictionary):
			continue
		var zone_id := String(town.get("zone_id", ""))
		var counts: Dictionary = route_counts.get(zone_id, {})
		var approach_tiles: Array = town.get("approach_tiles", [])
		var support_count := _support_resource_count_for_zone(placements.get("resource_nodes", []), zone_id)
		var viable := approach_tiles.size() >= 2 and support_count >= SUPPORT_RESOURCE_SITES.size() and int(counts.get("contest_route", 0)) >= 1 and int(counts.get("early_reward_route", 0)) >= 1 and String(proof.get("status", "")) == "pass"
		starts.append({
			"player_slot": int(town.get("player_slot", 0)),
			"owner": String(town.get("owner", "")),
			"zone_id": zone_id,
			"primary_town_placement_id": String(town.get("placement_id", "")),
			"town_id": String(town.get("town_id", "")),
			"faction_id": String(town.get("faction_id", "")),
			"body_tiles": town.get("body_tiles", []),
			"approach_tiles": approach_tiles,
			"minimum_approach_tiles_required": 2,
			"support_resource_count": support_count,
			"expansion_route_count": int(counts.get("early_reward_route", 0)),
			"contest_route_count": int(counts.get("contest_route", 0)),
			"viability": "pass" if viable else "fail",
		})
	return {
		"schema_id": "random_map_town_start_constraints_v1",
		"townless_start_profile": false,
		"player_starts": starts,
		"required_primary_town_count": towns.size(),
		"reachability_status": String(proof.get("status", "")),
	}

static func _fairness_report_payload(normalized: Dictionary, zones: Array, placements: Dictionary, route_graph: Dictionary, proof: Dictionary, objectives: Dictionary = {}) -> Dictionary:
	var early_support := _early_resource_support_payload(placements, route_graph)
	var contested_fronts := _contested_front_distribution_payload(placements, route_graph)
	var guard_pressure := _guard_pressure_payload(route_graph)
	var distance_comparisons := _travel_distance_comparisons_payload(placements, route_graph)
	var objective_pressure := _objective_reward_pressure_payload(objectives, route_graph)
	var failures := []
	var warnings := []
	for section in [early_support, contested_fronts, guard_pressure, distance_comparisons, objective_pressure]:
		if String(section.get("status", "")) == "fail":
			failures.append_array(section.get("failures", []))
		elif String(section.get("status", "")) == "warning":
			warnings.append_array(section.get("warnings", []))
	var status := "pass"
	if not failures.is_empty():
		status = "fail"
	elif not warnings.is_empty():
		status = "warning"
	return {
		"schema_id": "random_map_resource_encounter_fairness_report_v1",
		"status": status,
		"metadata": {
			"generator_version": String(normalized.get("generator_version", normalized.get("generator_version", GENERATOR_VERSION))),
			"normalized_seed": String(normalized.get("seed", normalized.get("normalized_seed", ""))),
			"profile_id": String(normalized.get("profile", {}).get("id", normalized.get("profile_id", ""))) if normalized.get("profile", {}) is Dictionary else "",
			"route_reachability_status": String(proof.get("status", "")),
			"zone_count": zones.size(),
		},
		"summary": {
			"early_resource_status": String(early_support.get("status", "")),
			"contested_front_status": String(contested_fronts.get("status", "")),
			"guard_pressure_status": String(guard_pressure.get("status", "")),
			"travel_distance_status": String(distance_comparisons.get("status", "")),
			"objective_pressure_status": String(objective_pressure.get("status", "")),
		},
		"early_resource_support": early_support,
		"contested_front_distribution": contested_fronts,
		"guarded_reward_risk": guard_pressure.get("guarded_reward_risk", {}),
		"guard_pressure": guard_pressure,
		"travel_distance_comparisons": distance_comparisons,
		"objective_reward_pressure": objective_pressure,
		"failures": failures,
		"warnings": warnings,
		"classification_model": "pass_warning_fail_report_only_no_runtime_adoption",
	}

static func _early_resource_support_payload(placements: Dictionary, route_graph: Dictionary) -> Dictionary:
	var towns: Array = placements.get("towns", [])
	var resources_by_zone := _resources_by_zone(placements.get("resource_nodes", []))
	var resource_edges_by_town := _resource_route_edges_by_town(route_graph.get("edges", []))
	var per_start := []
	var failures := []
	var warnings := []
	for town in towns:
		if not (town is Dictionary):
			continue
		var zone_id := String(town.get("zone_id", ""))
		var totals := {"gold": 0, "wood": 0, "ore": 0}
		var resource_records := []
		for resource in resources_by_zone.get(zone_id, []):
			if not (resource is Dictionary):
				continue
			var site_id := String(resource.get("site_id", ""))
			var value: Dictionary = SUPPORT_RESOURCE_VALUE_BY_SITE.get(site_id, {})
			for key in ["gold", "wood", "ore"]:
				totals[key] = int(totals.get(key, 0)) + int(value.get(key, 0))
			resource_records.append({
				"placement_id": String(resource.get("placement_id", "")),
				"site_id": site_id,
				"purpose": _resource_support_purpose(site_id),
				"value": _sorted_dict(value),
			})
		var missing := []
		for key in ["gold", "wood", "ore"]:
			if int(totals.get(key, 0)) < int(EARLY_RESOURCE_MINIMUMS.get(key, 0)):
				missing.append(key)
		var route_lengths := []
		for edge in resource_edges_by_town.get(String(town.get("placement_id", "")), []):
			if edge is Dictionary and bool(edge.get("path_found", false)):
				route_lengths.append(int(edge.get("path_length", 0)))
		var route_status := _spread_status(route_lengths, ROUTE_DISTANCE_WARNING_SPREAD, ROUTE_DISTANCE_FAIL_SPREAD)
		var status := "pass"
		if not missing.is_empty() or resource_records.size() < SUPPORT_RESOURCE_SITES.size():
			status = "fail"
			failures.append("start %s missing early support resources: %s" % [String(town.get("placement_id", "")), ",".join(missing)])
		elif route_status == "warning":
			status = "warning"
			warnings.append("start %s early support route distances are uneven" % String(town.get("placement_id", "")))
		per_start.append({
			"player_slot": int(town.get("player_slot", 0)),
			"zone_id": zone_id,
			"primary_town_placement_id": String(town.get("placement_id", "")),
			"minimums": _sorted_dict(EARLY_RESOURCE_MINIMUMS),
			"totals": _sorted_dict(totals),
			"resources": resource_records,
			"resource_route_lengths": route_lengths,
			"route_distance_status": route_status,
			"status": status,
		})
	var status := "pass"
	if not failures.is_empty():
		status = "fail"
	elif not warnings.is_empty():
		status = "warning"
	return {"status": status, "per_start": per_start, "failures": failures, "warnings": warnings}

static func _contested_front_distribution_payload(placements: Dictionary, route_graph: Dictionary) -> Dictionary:
	var start_zones := _start_zones_from_towns(placements.get("towns", []))
	var records := []
	var distances := []
	var pressure_values := []
	var failures := []
	var warnings := []
	for zone_id in start_zones:
		var edges := _edges_for_zone_and_role(route_graph.get("edges", []), String(zone_id), "contest_route")
		var route_count := 0
		var shortest := 0
		var pressure := 0
		for edge in edges:
			if not (edge is Dictionary):
				continue
			if bool(edge.get("path_found", false)):
				route_count += 1
				var length := int(edge.get("path_length", 0))
				shortest = length if shortest == 0 else min(shortest, length)
				distances.append(length)
				pressure += _effective_guard_pressure(edge)
		pressure_values.append(pressure)
		if route_count < 1:
			failures.append("start zone %s has no contest route front" % String(zone_id))
		records.append({
			"zone_id": String(zone_id),
			"contest_route_count": route_count,
			"nearest_contest_route_distance": shortest,
			"contest_guard_pressure": pressure,
		})
	var distance_status := _spread_status(distances, ROUTE_DISTANCE_WARNING_SPREAD, ROUTE_DISTANCE_FAIL_SPREAD)
	var pressure_status := _spread_status(pressure_values, PRESSURE_WARNING_SPREAD, PRESSURE_FAIL_SPREAD)
	if distance_status == "warning":
		warnings.append("contest route distances exceed warning spread")
	elif distance_status == "fail":
		failures.append("contest route distances exceed fail spread")
	if pressure_status == "warning":
		warnings.append("contest guard pressure exceeds warning spread")
	elif pressure_status == "fail":
		failures.append("contest guard pressure exceeds fail spread")
	var status := "pass"
	if not failures.is_empty():
		status = "fail"
	elif not warnings.is_empty():
		status = "warning"
	return {
		"status": status,
		"resource_front_model": "contest_routes_until_contested_resource_sites_exist",
		"per_start": records,
		"distance_spread": _spread_summary(distances),
		"guard_pressure_spread": _spread_summary(pressure_values),
		"failures": failures,
		"warnings": warnings,
	}

static func _guard_pressure_payload(route_graph: Dictionary) -> Dictionary:
	var route_guards := []
	var reward_risk := []
	var pressure_by_start := {}
	var failures := []
	var warnings := []
	for edge in route_graph.get("edges", []):
		if not (edge is Dictionary):
			continue
		var role := String(edge.get("role", ""))
		if role not in ["contest_route", "early_reward_route", "reward_to_junction"]:
			continue
		var guard_class := _guard_risk_class(edge)
		var pressure := _effective_guard_pressure(edge)
		var record := {
			"edge_id": String(edge.get("id", "")),
			"from": String(edge.get("from", "")),
			"to": String(edge.get("to", "")),
			"role": role,
			"path_length": int(edge.get("path_length", 0)),
			"raw_guard_value": int(edge.get("guard_value", 0)),
			"effective_guard_pressure": pressure,
			"risk_class": guard_class,
			"wide_suppresses_normal_guard": bool(edge.get("wide", false)),
			"border_guard_special_mode": bool(edge.get("border_guard", false)),
			"connectivity_classification": String(edge.get("connectivity_classification", "")),
		}
		route_guards.append(record)
		if role in ["early_reward_route", "reward_to_junction"]:
			reward_risk.append(record)
		for endpoint_key in ["from", "to"]:
			var endpoint := String(edge.get(endpoint_key, ""))
			if endpoint.begins_with("start_"):
				pressure_by_start[endpoint] = int(pressure_by_start.get(endpoint, 0)) + pressure
	if route_guards.is_empty():
		failures.append("no route guard pressure records available")
	var pressure_values := []
	for key in _sorted_keys(pressure_by_start):
		pressure_values.append(int(pressure_by_start[key]))
	var pressure_status := _spread_status(pressure_values, PRESSURE_WARNING_SPREAD, PRESSURE_FAIL_SPREAD)
	if pressure_status == "warning":
		warnings.append("route guard pressure exceeds warning spread")
	elif pressure_status == "fail":
		failures.append("route guard pressure exceeds fail spread")
	var status := "pass"
	if not failures.is_empty():
		status = "fail"
	elif not warnings.is_empty():
		status = "warning"
	return {
		"status": status,
		"connection_payload_semantics": route_graph.get("connection_payload_semantics", {}),
		"route_guards": route_guards,
		"pressure_by_start_zone": _sorted_dict(pressure_by_start),
		"pressure_spread": _spread_summary(pressure_values),
		"guarded_reward_risk": {
			"status": "pass" if not reward_risk.is_empty() else "warning",
			"risk_classes": reward_risk,
			"model": "guard_value_distance_and_connection_semantics",
		},
		"failures": failures,
		"warnings": warnings,
	}

static func _travel_distance_comparisons_payload(placements: Dictionary, route_graph: Dictionary) -> Dictionary:
	var resources_by_town := _resource_route_edges_by_town(route_graph.get("edges", []))
	var records := []
	var town_to_resource_maxes := []
	var contest_distances := []
	var failures := []
	var warnings := []
	for town in placements.get("towns", []):
		if not (town is Dictionary):
			continue
		var town_id := String(town.get("placement_id", ""))
		var zone_id := String(town.get("zone_id", ""))
		var resource_lengths := []
		for edge in resources_by_town.get(town_id, []):
			if edge is Dictionary and bool(edge.get("path_found", false)):
				resource_lengths.append(int(edge.get("path_length", 0)))
		var contest_edges := _edges_for_zone_and_role(route_graph.get("edges", []), zone_id, "contest_route")
		var nearest_contest := 0
		for edge in contest_edges:
			if edge is Dictionary and bool(edge.get("path_found", false)):
				var length := int(edge.get("path_length", 0))
				nearest_contest = length if nearest_contest == 0 else min(nearest_contest, length)
		var max_resource := _max_int(resource_lengths)
		town_to_resource_maxes.append(max_resource)
		if nearest_contest > 0:
			contest_distances.append(nearest_contest)
		records.append({
			"player_slot": int(town.get("player_slot", 0)),
			"zone_id": zone_id,
			"start_contract": "primary_town_anchor_until_hero_start_generation_exists",
			"start_to_primary_town_distance": 0,
			"town_to_resource_route_lengths": resource_lengths,
			"max_town_to_resource_distance": max_resource,
			"nearest_contest_route_distance": nearest_contest,
		})
	var resource_status := _spread_status(town_to_resource_maxes, ROUTE_DISTANCE_WARNING_SPREAD, ROUTE_DISTANCE_FAIL_SPREAD)
	var contest_status := _spread_status(contest_distances, ROUTE_DISTANCE_WARNING_SPREAD, ROUTE_DISTANCE_FAIL_SPREAD)
	if resource_status == "warning":
		warnings.append("town-to-resource route distance spread exceeds warning threshold")
	elif resource_status == "fail":
		failures.append("town-to-resource route distance spread exceeds fail threshold")
	if contest_status == "warning":
		warnings.append("contest route distance spread exceeds warning threshold")
	elif contest_status == "fail":
		failures.append("contest route distance spread exceeds fail threshold")
	var status := "pass"
	if not failures.is_empty():
		status = "fail"
	elif not warnings.is_empty():
		status = "warning"
	return {
		"status": status,
		"per_start": records,
		"town_to_resource_distance_spread": _spread_summary(town_to_resource_maxes),
		"contest_route_distance_spread": _spread_summary(contest_distances),
		"failures": failures,
		"warnings": warnings,
	}

static func _objective_reward_pressure_payload(objectives: Dictionary, route_graph: Dictionary) -> Dictionary:
	var objective_count := 0
	if objectives.has("victory") and objectives.get("victory", []) is Array:
		objective_count += objectives.get("victory", []).size()
	if objectives.has("defeat") and objectives.get("defeat", []) is Array:
		objective_count += objectives.get("defeat", []).size()
	if objective_count == 0:
		return {
			"status": "pass",
			"supported": false,
			"objective_count": 0,
			"model": "no_generated_objective_pressure_until_supported_objectives_exist",
			"failures": [],
			"warnings": [],
		}
	return {
		"status": "warning",
		"supported": true,
		"objective_count": objective_count,
		"route_edge_count": route_graph.get("edges", []).size(),
		"model": "placeholder_requires_objective_route_links_in_later_slice",
		"failures": [],
		"warnings": ["generated objectives exist but objective-route pressure links are not staged"],
	}

static func _metadata(normalized: Dictionary) -> Dictionary:
	return {
		"generator_version": String(normalized.get("generator_version", GENERATOR_VERSION)),
		"normalized_seed": String(normalized.get("seed", "0")),
		"profile": normalized.get("profile", {}),
		"size": normalized.get("size", {}),
		"player_constraints": normalized.get("player_constraints", {}),
		"content_manifest_fingerprint": String(normalized.get("content_manifest_fingerprint", "")),
		"template_id": TEMPLATE_ID,
		"source_lessons": [
			"staged_template_profile_pipeline",
			"runtime_zone_connection_graph",
			"terrain_owner_grid_before_writeout",
			"separate_object_resource_encounter_placements",
			"connection_payloads_classify_guarded_wide_border_routes",
			"roads_staged_as_overlay_payloads_before_durable_tile_writeout",
			"explicit_no_authored_content_write_boundary",
		],
	}

static func _route_graph_payload(links: Array, seeds: Dictionary) -> Dictionary:
	var edges := []
	for index in range(links.size()):
		var link: Dictionary = links[index]
		edges.append({
			"id": "edge_%02d_%s_%s" % [index + 1, String(link.get("from", "")), String(link.get("to", ""))],
			"from": String(link.get("from", "")),
			"to": String(link.get("to", "")),
			"role": String(link.get("role", "")),
			"guard_value": int(link.get("guard_value", 0)),
			"wide": bool(link.get("wide", false)),
			"border_guard": bool(link.get("border_guard", false)),
			"from_anchor": seeds.get(String(link.get("from", "")), {}),
			"to_anchor": seeds.get(String(link.get("to", "")), {}),
			"writeout_state": "graph_only_roads_deferred",
		})
	return {"nodes": _sorted_point_dict(seeds), "edges": edges}

static func _terrain_phase_summary(terrain_rows: Array, zones: Array) -> Dictionary:
	var terrain_counts := {}
	for row_value in terrain_rows:
		var row: Array = row_value
		for terrain_id in row:
			var key := String(terrain_id)
			terrain_counts[key] = int(terrain_counts.get(key, 0)) + 1
	return {
		"terrain_counts": _sorted_dict(terrain_counts),
		"zone_count": zones.size(),
		"blocked_terrain_ids": BLOCKED_TERRAIN_IDS,
	}

static func _validate_road_paths(road_network: Dictionary, terrain_rows: Array, object_placements: Array, failures: Array) -> void:
	var occupied := _occupied_body_lookup(object_placements)
	for segment in road_network.get("road_segments", []):
		if not (segment is Dictionary):
			failures.append("non-dictionary road segment")
			continue
		var route_edge_id := String(segment.get("route_edge_id", ""))
		var cells: Array = segment.get("cells", [])
		if cells.is_empty():
			failures.append("road segment %s has no cells" % route_edge_id)
			continue
		for cell in cells:
			if not (cell is Dictionary):
				failures.append("road segment %s has non-dictionary cell" % route_edge_id)
				continue
			var x := int(cell.get("x", -1))
			var y := int(cell.get("y", -1))
			if not _point_in_rows(terrain_rows, x, y):
				failures.append("road segment %s leaves map bounds" % route_edge_id)
			elif not _terrain_cell_is_passable(terrain_rows, x, y):
				failures.append("road segment %s crosses impassable terrain at %d,%d" % [route_edge_id, x, y])
			if occupied.has(_point_key(x, y)):
				failures.append("road segment %s crosses blocked object body at %d,%d" % [route_edge_id, x, y])

static func _terrain_region_counts(terrain_rows: Array) -> Dictionary:
	var visited := {}
	var counts := {}
	for y in range(terrain_rows.size()):
		var row: Array = terrain_rows[y]
		for x in range(row.size()):
			var key := _point_key(x, y)
			if visited.has(key):
				continue
			var terrain_id := String(row[x])
			counts[terrain_id] = int(counts.get(terrain_id, 0)) + 1
			var queue := [_point_dict(x, y)]
			visited[key] = true
			var cursor := 0
			while cursor < queue.size():
				var point: Dictionary = queue[cursor]
				cursor += 1
				for offset in _cardinal_offsets():
					var nx: int = int(point.get("x", 0)) + int(offset.x)
					var ny: int = int(point.get("y", 0)) + int(offset.y)
					if not _point_in_rows(terrain_rows, nx, ny):
						continue
					var next_key := _point_key(nx, ny)
					if visited.has(next_key) or String(terrain_rows[ny][nx]) != terrain_id:
						continue
					visited[next_key] = true
					queue.append(_point_dict(nx, ny))
	return _sorted_dict(counts)

static func _annotate_pathing_metadata(object_placements: Array, towns: Array, resource_nodes: Array, encounters: Array, zone_grid: Array, terrain_rows: Array, occupied: Dictionary) -> void:
	var by_id := {}
	for placement in object_placements:
		if placement is Dictionary:
			by_id[String(placement.get("placement_id", ""))] = placement
			_apply_pathing_metadata(placement, zone_grid, terrain_rows, occupied)
	for town in towns:
		if town is Dictionary:
			_copy_shared_placement_metadata(town, by_id.get(String(town.get("placement_id", "")), {}))
	for resource in resource_nodes:
		if resource is Dictionary:
			_copy_shared_placement_metadata(resource, by_id.get(String(resource.get("placement_id", "")), {}))
	for encounter in encounters:
		if encounter is Dictionary:
			_copy_shared_placement_metadata(encounter, by_id.get(String(encounter.get("placement_id", "")), {}))

static func _apply_pathing_metadata(placement: Dictionary, zone_grid: Array, terrain_rows: Array, occupied: Dictionary) -> void:
	var point := _point_dict(int(placement.get("x", 0)), int(placement.get("y", 0)))
	var zone_id := String(placement.get("zone_id", _zone_at_point(zone_grid, point)))
	var approaches := _approach_tiles_for_point(point, zone_id, zone_grid, terrain_rows, occupied)
	placement["zone_id"] = zone_id
	placement["body_tiles"] = [point]
	placement["blocking_body"] = true
	placement["approach_tiles"] = approaches
	placement["visit_tile"] = approaches[0] if not approaches.is_empty() else point
	placement["pathing_status"] = "pass" if not approaches.is_empty() else "blocked_no_approach"

static func _copy_shared_placement_metadata(target: Dictionary, source: Dictionary) -> void:
	for key in ["zone_id", "faction_id", "body_tiles", "blocking_body", "approach_tiles", "visit_tile", "pathing_status", "player_slot"]:
		if source.has(key):
			target[key] = source[key]

static func _approach_tiles_for_point(point: Dictionary, preferred_zone_id: String, zone_grid: Array, terrain_rows: Array, occupied: Dictionary) -> Array:
	var result := []
	var x := int(point.get("x", 0))
	var y := int(point.get("y", 0))
	for offset in _cardinal_offsets():
		var nx: int = x + int(offset.x)
		var ny: int = y + int(offset.y)
		if not _point_in_rows(terrain_rows, nx, ny):
			continue
		if occupied.has(_point_key(nx, ny)):
			continue
		if not _terrain_cell_is_passable(terrain_rows, nx, ny):
			continue
		if preferred_zone_id != "" and _zone_at_point(zone_grid, _point_dict(nx, ny)) != preferred_zone_id:
			continue
		result.append(_point_dict(nx, ny))
	if result.is_empty():
		for offset in _cardinal_offsets():
			var nx: int = x + int(offset.x)
			var ny: int = y + int(offset.y)
			if _point_in_rows(terrain_rows, nx, ny) and not occupied.has(_point_key(nx, ny)) and _terrain_cell_is_passable(terrain_rows, nx, ny):
				result.append(_point_dict(nx, ny))
	if result.size() < 2:
		for radius in range(2, 5):
			for dy in range(-radius, radius + 1):
				for dx in range(-radius, radius + 1):
					if max(abs(dx), abs(dy)) != radius:
						continue
					var cx := x + dx
					var cy := y + dy
					if not _point_in_rows(terrain_rows, cx, cy):
						continue
					if occupied.has(_point_key(cx, cy)) or not _terrain_cell_is_passable(terrain_rows, cx, cy):
						continue
					if preferred_zone_id != "" and _zone_at_point(zone_grid, _point_dict(cx, cy)) != preferred_zone_id and radius < 4:
						continue
					var candidate := _point_dict(cx, cy)
					if not _point_in_array(result, candidate):
						result.append(candidate)
					if result.size() >= 2:
						return result
	return result

static func _occupied_body_lookup(object_placements: Array) -> Dictionary:
	var occupied := {}
	for placement in object_placements:
		if not (placement is Dictionary):
			continue
		for body in placement.get("body_tiles", []):
			if body is Dictionary:
				occupied[_point_key(int(body.get("x", 0)), int(body.get("y", 0)))] = String(placement.get("placement_id", ""))
	return occupied

static func _object_placements_by_zone_and_kind(object_placements: Array) -> Dictionary:
	var result := {}
	for placement in object_placements:
		if not (placement is Dictionary):
			continue
		var zone_id := String(placement.get("zone_id", ""))
		if not result.has(zone_id):
			result[zone_id] = {}
		var kind := String(placement.get("kind", ""))
		if not result[zone_id].has(kind):
			result[zone_id][kind] = []
		result[zone_id][kind].append(placement)
	return result

static func _route_nodes_payload(seeds: Dictionary, placements: Dictionary) -> Dictionary:
	var nodes := {}
	for zone_id in _sorted_keys(seeds):
		nodes["node_zone_%s" % String(zone_id)] = {
			"id": "node_zone_%s" % String(zone_id),
			"kind": "zone_anchor",
			"zone_id": String(zone_id),
			"point": seeds[zone_id],
			"required": false,
		}
	for placement in placements.get("object_placements", []):
		if not (placement is Dictionary):
			continue
		var placement_id := String(placement.get("placement_id", ""))
		var kind := String(placement.get("kind", ""))
		if kind not in ["town", "resource_site", "route_guard"]:
			continue
		var node_id := "node_%s" % placement_id
		nodes[node_id] = {
			"id": node_id,
			"kind": kind,
			"placement_id": placement_id,
			"zone_id": String(placement.get("zone_id", "")),
			"point": _first_approach_or_body(placement),
			"body_tiles": placement.get("body_tiles", []),
			"required": kind in ["town", "resource_site"],
		}
	return nodes

static func _preferred_route_node_for_zone(zone_id: String, object_by_zone: Dictionary, route_nodes: Dictionary) -> Dictionary:
	var zone_objects: Dictionary = object_by_zone.get(zone_id, {})
	var towns: Array = zone_objects.get("town", [])
	if not towns.is_empty() and towns[0] is Dictionary:
		return route_nodes.get("node_%s" % String(towns[0].get("placement_id", "")), {"id": "node_zone_%s" % zone_id, "point": _point_dict(0, 0)})
	return route_nodes.get("node_zone_%s" % zone_id, {"id": "node_zone_%s" % zone_id, "point": _point_dict(0, 0)})

static func _first_approach_or_body(placement: Dictionary) -> Dictionary:
	var approaches: Array = placement.get("approach_tiles", [])
	if not approaches.is_empty() and approaches[0] is Dictionary:
		return approaches[0]
	var bodies: Array = placement.get("body_tiles", [])
	if not bodies.is_empty() and bodies[0] is Dictionary:
		return bodies[0]
	return _point_dict(int(placement.get("x", 0)), int(placement.get("y", 0)))

static func _route_classification(link: Dictionary, path_found: bool) -> String:
	if not path_found:
		return "blocked_connectivity"
	if bool(link.get("border_guard", false)):
		return "guarded_connectivity_border_guard"
	if bool(link.get("wide", false)):
		return "full_connectivity_wide_unguarded"
	if int(link.get("guard_value", 0)) > 0:
		return "guarded_connectivity"
	return "full_connectivity"

static func _road_segment_payload(edge_id: String, path: Array, classification: String, edge: Dictionary) -> Dictionary:
	return {
		"id": "road_%s" % edge_id,
		"route_edge_id": edge_id,
		"overlay_id": ROAD_OVERLAY_ID,
		"cells": path,
		"cell_count": path.size(),
		"connectivity_classification": classification,
		"role": String(edge.get("role", "")),
		"writeout_state": "staged_overlay_no_tile_bytes_written",
	}

static func _find_passable_path(start: Dictionary, goal: Dictionary, terrain_rows: Array, occupied: Dictionary) -> Array:
	if start.is_empty() or goal.is_empty():
		return []
	var start_x := int(start.get("x", 0))
	var start_y := int(start.get("y", 0))
	var goal_x := int(goal.get("x", 0))
	var goal_y := int(goal.get("y", 0))
	if not _point_in_rows(terrain_rows, start_x, start_y) or not _point_in_rows(terrain_rows, goal_x, goal_y):
		return []
	if occupied.has(_point_key(start_x, start_y)) or occupied.has(_point_key(goal_x, goal_y)):
		return []
	if not _terrain_cell_is_passable(terrain_rows, start_x, start_y) or not _terrain_cell_is_passable(terrain_rows, goal_x, goal_y):
		return []
	var start_key := _point_key(start_x, start_y)
	var goal_key := _point_key(goal_x, goal_y)
	var queue := [_point_dict(start_x, start_y)]
	var came_from := {start_key: ""}
	var cursor := 0
	while cursor < queue.size():
		var current: Dictionary = queue[cursor]
		cursor += 1
		var current_key := _point_key(int(current.get("x", 0)), int(current.get("y", 0)))
		if current_key == goal_key:
			break
		for offset in _cardinal_offsets():
			var nx: int = int(current.get("x", 0)) + int(offset.x)
			var ny: int = int(current.get("y", 0)) + int(offset.y)
			var next_key := _point_key(nx, ny)
			if came_from.has(next_key):
				continue
			if not _point_in_rows(terrain_rows, nx, ny):
				continue
			if occupied.has(next_key):
				continue
			if not _terrain_cell_is_passable(terrain_rows, nx, ny):
				continue
			came_from[next_key] = current_key
			queue.append(_point_dict(nx, ny))
	if not came_from.has(goal_key):
		return []
	var reversed_path := []
	var key := goal_key
	var guard: int = terrain_rows.size() * (terrain_rows[0].size() if not terrain_rows.is_empty() and terrain_rows[0] is Array else 1)
	while key != "" and guard > 0:
		var parts := key.split(",")
		reversed_path.append(_point_dict(int(parts[0]), int(parts[1])))
		key = String(came_from.get(key, ""))
		guard -= 1
	reversed_path.reverse()
	return reversed_path

static func _connect_adjacency(adjacency: Dictionary, a: String, b: String) -> void:
	if not adjacency.has(a):
		adjacency[a] = []
	if not adjacency.has(b):
		adjacency[b] = []
	if b not in adjacency[a]:
		adjacency[a].append(b)
	if a not in adjacency[b]:
		adjacency[b].append(a)

static func _reachability_proof(route_nodes: Dictionary, edges: Array, adjacency: Dictionary) -> Dictionary:
	var required_nodes := []
	for node_id in _sorted_keys(route_nodes):
		var node: Dictionary = route_nodes[node_id]
		if bool(node.get("required", false)):
			required_nodes.append(String(node_id))
	if required_nodes.is_empty():
		return {"status": "fail", "reason": "no_required_nodes", "required_nodes": []}
	var start_node: String = String(required_nodes[0])
	var visited := {start_node: true}
	var queue := [start_node]
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
		if not visited.has(node_id):
			unreachable.append(node_id)
	var blocked_edges := []
	for edge in edges:
		if edge is Dictionary and bool(edge.get("required", false)) and not bool(edge.get("path_found", false)):
			blocked_edges.append(String(edge.get("id", "")))
	return {
		"status": "pass" if unreachable.is_empty() and blocked_edges.is_empty() else "fail",
		"model": "required_nodes_connected_by_passable_staged_road_paths",
		"required_nodes": required_nodes,
		"reachable_required_nodes": required_nodes.size() - unreachable.size(),
		"unreachable_required_nodes": unreachable,
		"blocked_required_edges": blocked_edges,
	}

static func _route_counts_by_zone(edges: Array) -> Dictionary:
	var counts := {}
	for edge in edges:
		if not (edge is Dictionary):
			continue
		for endpoint_key in ["from", "to"]:
			var zone_id := String(edge.get(endpoint_key, ""))
			if zone_id.begins_with("rmg_"):
				continue
			if not counts.has(zone_id):
				counts[zone_id] = {}
			var role := String(edge.get("role", "route"))
			counts[zone_id][role] = int(counts[zone_id].get(role, 0)) + 1
	return counts

static func _support_resource_count_for_zone(resource_nodes: Array, zone_id: String) -> int:
	var count := 0
	for resource in resource_nodes:
		if resource is Dictionary and String(resource.get("zone_id", "")) == zone_id:
			count += 1
	return count

static func _resources_by_zone(resource_nodes: Array) -> Dictionary:
	var result := {}
	for resource in resource_nodes:
		if not (resource is Dictionary):
			continue
		var zone_id := String(resource.get("zone_id", ""))
		if not result.has(zone_id):
			result[zone_id] = []
		result[zone_id].append(resource)
	return result

static func _start_zones_from_towns(towns: Array) -> Array:
	var result := []
	for town in towns:
		if town is Dictionary:
			var zone_id := String(town.get("zone_id", ""))
			if zone_id != "" and zone_id not in result:
				result.append(zone_id)
	result.sort()
	return result

static func _resource_route_edges_by_town(edges: Array) -> Dictionary:
	var result := {}
	for edge in edges:
		if not (edge is Dictionary) or String(edge.get("role", "")) != "required_start_economy_route":
			continue
		var town_id := String(edge.get("from", ""))
		if not result.has(town_id):
			result[town_id] = []
		result[town_id].append(edge)
	return result

static func _edges_for_zone_and_role(edges: Array, zone_id: String, role: String) -> Array:
	var result := []
	for edge in edges:
		if not (edge is Dictionary):
			continue
		if String(edge.get("role", "")) != role:
			continue
		if String(edge.get("from", "")) == zone_id or String(edge.get("to", "")) == zone_id:
			result.append(edge)
	return result

static func _resource_support_purpose(site_id: String) -> String:
	match site_id:
		"site_wood_wagon":
			return "early_wood_support"
		"site_ore_crates":
			return "early_ore_support"
		"site_waystone_cache":
			return "early_gold_support"
		_:
			return "unknown_resource_support"

static func _guard_risk_class(edge: Dictionary) -> String:
	if bool(edge.get("border_guard", false)):
		return "special_border_guard"
	if bool(edge.get("wide", false)):
		return "wide_unguarded_normal_guard_suppressed"
	var guard_value := int(edge.get("guard_value", 0))
	if guard_value <= 0:
		return "unguarded"
	if guard_value <= 200:
		return "low"
	if guard_value <= 700:
		return "medium"
	return "high"

static func _effective_guard_pressure(edge: Dictionary) -> int:
	if bool(edge.get("wide", false)):
		return 0
	var value := int(edge.get("guard_value", 0))
	if bool(edge.get("border_guard", false)):
		value += 500
	return value

static func _spread_status(values: Array, warning_threshold: int, fail_threshold: int) -> String:
	if values.size() <= 1:
		return "pass"
	var spread := int(_spread_summary(values).get("spread", 0))
	if spread > fail_threshold:
		return "fail"
	if spread > warning_threshold:
		return "warning"
	return "pass"

static func _spread_summary(values: Array) -> Dictionary:
	if values.is_empty():
		return {"count": 0, "min": 0, "max": 0, "spread": 0}
	var minimum := int(values[0])
	var maximum := int(values[0])
	for value in values:
		minimum = min(minimum, int(value))
		maximum = max(maximum, int(value))
	return {"count": values.size(), "min": minimum, "max": maximum, "spread": maximum - minimum}

static func _max_int(values: Array) -> int:
	var result := 0
	for value in values:
		result = max(result, int(value))
	return result

static func _cardinal_offsets() -> Array:
	return [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]

static func _terrain_is_passable(terrain_id: String) -> bool:
	return terrain_id not in BLOCKED_TERRAIN_IDS

static func _terrain_cell_is_passable(terrain_rows: Array, x: int, y: int) -> bool:
	if not _point_in_rows(terrain_rows, x, y):
		return false
	return _terrain_is_passable(String(terrain_rows[y][x]))

static func _biome_for_terrain(terrain_id: String) -> String:
	return String(BIOME_BY_TERRAIN.get(terrain_id, "biome_grasslands"))

static func _point_in_rows(rows: Array, x: int, y: int) -> bool:
	if y < 0 or y >= rows.size() or not (rows[y] is Array):
		return false
	var row: Array = rows[y]
	return x >= 0 and x < row.size()

static func _point_in_array(points: Array, point: Dictionary) -> bool:
	var key := _point_key(int(point.get("x", 0)), int(point.get("y", 0)))
	for existing in points:
		if existing is Dictionary and _point_key(int(existing.get("x", 0)), int(existing.get("y", 0))) == key:
			return true
	return false

static func _normalize_size(size_value: Variant) -> Dictionary:
	var preset := "small"
	var width := 16
	var height := 12
	if size_value is String:
		preset = String(size_value).strip_edges().to_lower()
		match preset:
			"medium":
				width = 24
				height = 18
			"large":
				width = 32
				height = 24
			_:
				preset = "small"
	elif size_value is Dictionary:
		preset = String(size_value.get("preset", "custom")).strip_edges().to_lower()
		width = int(size_value.get("width", width))
		height = int(size_value.get("height", height))
	width = clampi(width, 8, 64)
	height = clampi(height, 8, 48)
	return {"preset": preset, "width": width, "height": height}

static func _normalize_player_constraints(value: Variant) -> Dictionary:
	var human_count := 1
	var computer_count := 1
	if value is Dictionary:
		human_count = clampi(int(value.get("human_count", value.get("humans", human_count))), 1, 4)
		computer_count = clampi(int(value.get("computer_count", value.get("computers", computer_count))), 1, 3)
	var player_count := clampi(human_count + computer_count, 2, 4)
	if human_count >= player_count:
		human_count = 1
		computer_count = player_count - 1
	return {"human_count": human_count, "computer_count": computer_count, "player_count": player_count, "team_mode": "free_for_all"}

static func _normalize_profile(value: Variant, player_constraints: Dictionary) -> Dictionary:
	var profile: Dictionary = value if value is Dictionary else {}
	var profile_id := String(profile.get("id", "seeded_core_frontier")).strip_edges()
	if profile_id == "":
		profile_id = "seeded_core_frontier"
	var terrain_ids := _normalized_string_array(profile.get("terrain_ids", CORE_TERRAIN_POOL), CORE_TERRAIN_POOL)
	var faction_ids := _normalized_string_array(profile.get("faction_ids", DEFAULT_FACTIONS), DEFAULT_FACTIONS)
	while faction_ids.size() < int(player_constraints.get("player_count", 2)):
		faction_ids.append(DEFAULT_FACTIONS[faction_ids.size() % DEFAULT_FACTIONS.size()])
	var town_ids := []
	for faction_id in faction_ids:
		town_ids.append(String(DEFAULT_TOWN_BY_FACTION.get(String(faction_id), "town_riverwatch")))
	var resource_site_ids := []
	for resource in SUPPORT_RESOURCE_SITES:
		resource_site_ids.append(String(resource.get("site_id", "")))
	return {
		"id": profile_id,
		"label": String(profile.get("label", "Seeded Core Frontier")).strip_edges(),
		"template_family": "zone_connection_spoke",
		"terrain_ids": terrain_ids,
		"faction_ids": faction_ids.slice(0, int(player_constraints.get("player_count", 2))),
		"town_ids": town_ids.slice(0, int(player_constraints.get("player_count", 2))),
		"resource_site_ids": resource_site_ids,
		"encounter_id": String(profile.get("encounter_id", DEFAULT_ENCOUNTER_ID)),
		"guard_strength_profile": String(profile.get("guard_strength_profile", "core_low")),
	}

static func _normalized_string_array(value: Variant, fallback: Array) -> Array:
	var result := []
	if value is Array:
		for item in value:
			var text := String(item).strip_edges()
			if text != "" and text not in result:
				result.append(text)
	if result.is_empty():
		result = fallback.duplicate()
	return result

static func _terrain_rows_from_zone_grid(zone_grid: Array, zones: Array) -> Array:
	var zone_terrain := {}
	for zone in zones:
		if zone is Dictionary:
			zone_terrain[String(zone.get("id", ""))] = String(zone.get("terrain_id", "grass"))
	var rows := []
	for row_value in zone_grid:
		var source_row: Array = row_value
		var row := []
		for zone_id_value in source_row:
			row.append(String(zone_terrain.get(String(zone_id_value), "grass")))
		rows.append(row)
	return rows

static func _nearest_zone_id(x: int, y: int, zones: Array, seeds: Dictionary) -> String:
	var best_id := String(zones[0].get("id", "")) if not zones.is_empty() and zones[0] is Dictionary else ""
	var best_score := INF
	for zone in zones:
		if not (zone is Dictionary):
			continue
		var zone_id := String(zone.get("id", ""))
		var seed: Dictionary = seeds.get(zone_id, {})
		var dx := float(x - int(seed.get("x", 0)))
		var dy := float(y - int(seed.get("y", 0))) * 1.12
		var weight := sqrt(float(max(1, int(zone.get("base_size", 1)))))
		var score := (dx * dx + dy * dy) / weight
		if score < best_score:
			best_score = score
			best_id = zone_id
	return best_id

static func _update_zone_geometry(zones: Array, zone_grid: Array) -> void:
	var by_id := {}
	for zone in zones:
		if zone is Dictionary:
			zone["bounds"] = {"min_x": 999999, "min_y": 999999, "max_x": -1, "max_y": -1}
			zone["cell_count"] = 0
			by_id[String(zone.get("id", ""))] = zone
	for y in range(zone_grid.size()):
		var row: Array = zone_grid[y]
		for x in range(row.size()):
			var zone_id := String(row[x])
			if not by_id.has(zone_id):
				continue
			var zone: Dictionary = by_id[zone_id]
			var bounds: Dictionary = zone.get("bounds", {})
			bounds["min_x"] = min(int(bounds.get("min_x", x)), x)
			bounds["min_y"] = min(int(bounds.get("min_y", y)), y)
			bounds["max_x"] = max(int(bounds.get("max_x", x)), x)
			bounds["max_y"] = max(int(bounds.get("max_y", y)), y)
			zone["bounds"] = bounds
			zone["cell_count"] = int(zone.get("cell_count", 0)) + 1

static func _zones_for_payload(zones: Array) -> Array:
	var payload := []
	for zone in zones:
		if zone is Dictionary:
			payload.append({
				"id": String(zone.get("id", "")),
				"source_id": String(zone.get("source_id", "")),
				"role": String(zone.get("role", "")),
				"owner_slot": zone.get("owner_slot", null),
				"player_slot": zone.get("player_slot", null),
				"faction_id": String(zone.get("faction_id", "")),
				"terrain_id": String(zone.get("terrain_id", "")),
				"base_size": int(zone.get("base_size", 0)),
				"bounds": zone.get("bounds", {}),
				"cell_count": int(zone.get("cell_count", 0)),
			})
	return payload

static func _nearest_free_cell(x: int, y: int, preferred_zone_id: Variant, zone_grid: Array, terrain_rows: Array, occupied: Dictionary, rng: DeterministicRng) -> Dictionary:
	var height := zone_grid.size()
	var width: int = zone_grid[0].size() if height > 0 and zone_grid[0] is Array else 0
	x = clampi(x, 0, max(0, width - 1))
	y = clampi(y, 0, max(0, height - 1))
	for radius in range(max(width, height) + 1):
		var candidates := []
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if max(abs(dx), abs(dy)) != radius:
					continue
				var cx := x + dx
				var cy := y + dy
				if cx < 0 or cy < 0 or cx >= width or cy >= height:
					continue
				if occupied.has(_point_key(cx, cy)):
					continue
				if not _terrain_cell_is_passable(terrain_rows, cx, cy):
					continue
				if preferred_zone_id != null and radius < 3 and String(zone_grid[cy][cx]) != String(preferred_zone_id):
					continue
				candidates.append({"x": cx, "y": cy})
		if not candidates.is_empty():
			return candidates[rng.next_index(candidates.size())]
	return {}

static func _object_placement(placement_id: String, kind: String, faction_id: String, zone_id: String, point: Dictionary, extra: Dictionary) -> Dictionary:
	var payload := {
		"placement_id": placement_id,
		"kind": kind,
		"zone_id": zone_id,
		"faction_id": faction_id,
		"x": int(point.get("x", 0)),
		"y": int(point.get("y", 0)),
	}
	for key in _sorted_keys(extra):
		payload[String(key)] = extra[key]
	return payload

static func _placement_counts(placements: Array) -> Dictionary:
	var counts := {}
	for placement in placements:
		if not (placement is Dictionary):
			continue
		var kind := String(placement.get("kind", "unknown"))
		counts[kind] = int(counts.get(kind, 0)) + 1
	return _sorted_dict(counts)

static func _resolve_seed_collisions(seeds: Dictionary, width: int, height: int) -> Dictionary:
	var resolved := {}
	var occupied := {}
	for zone_id in _sorted_keys(seeds):
		var point: Dictionary = seeds[zone_id]
		var x := int(point.get("x", 0))
		var y := int(point.get("y", 0))
		var guard: int = max(1, width * height)
		while occupied.has(_point_key(x, y)) and guard > 0:
			x = clampi(x + 1, 1, max(1, width - 2))
			if occupied.has(_point_key(x, y)):
				y = clampi(y + 1, 1, max(1, height - 2))
			guard -= 1
		occupied[_point_key(x, y)] = true
		resolved[String(zone_id)] = _point_dict(x, y)
	return resolved

static func _zones_with_owner(zones: Array) -> Array:
	var result := []
	for zone in zones:
		if zone is Dictionary and zone.get("owner_slot", null) != null:
			result.append(zone)
	result.sort_custom(Callable(RandomMapGeneratorRules, "_compare_owner_slot"))
	return result

static func _zones_without_owner(zones: Array) -> Array:
	var result := []
	for zone in zones:
		if zone is Dictionary and zone.get("owner_slot", null) == null:
			result.append(zone)
	result.sort_custom(Callable(RandomMapGeneratorRules, "_compare_zone_id"))
	return result

static func _compare_owner_slot(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("owner_slot", 0)) < int(b.get("owner_slot", 0))

static func _compare_zone_id(a: Dictionary, b: Dictionary) -> bool:
	return String(a.get("id", "")) < String(b.get("id", ""))

static func _phase_record(phase: String, summary: Dictionary) -> Dictionary:
	return {"phase": phase, "summary": _sorted_dict(summary)}

static func _sorted_point_dict(points: Dictionary) -> Dictionary:
	var result := {}
	for key in _sorted_keys(points):
		result[String(key)] = points[key]
	return result

static func _sorted_dict(value: Dictionary) -> Dictionary:
	var result := {}
	for key in _sorted_keys(value):
		result[String(key)] = value[key]
	return result

static func _sorted_keys(value: Dictionary) -> Array:
	var keys := []
	for key in value.keys():
		keys.append(String(key))
	keys.sort()
	return keys

static func _point_dict(x: int, y: int) -> Dictionary:
	return {"x": x, "y": y}

static func _mark_occupied(occupied: Dictionary, point: Dictionary) -> void:
	occupied[_point_key(int(point.get("x", 0)), int(point.get("y", 0)))] = true

static func _point_key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]

static func _zone_at_point(zone_grid: Array, point: Dictionary) -> String:
	var y := int(point.get("y", 0))
	var x := int(point.get("x", 0))
	if y < 0 or y >= zone_grid.size() or not (zone_grid[y] is Array):
		return ""
	var row: Array = zone_grid[y]
	if x < 0 or x >= row.size():
		return ""
	return String(row[x])

static func _positive_seed(seed_text: String) -> int:
	var hashed := _hash32_int(seed_text)
	return int(hashed % (RNG_MODULUS - 1)) + 1

static func _hash32_hex(text: String) -> String:
	var value := _hash32_int(text)
	var chars := []
	for _index in range(8):
		chars.push_front(HEX_DIGITS[int(value % 16)])
		value = int(value / 16)
	return "".join(chars)

static func _hash32_int(text: String) -> int:
	var value := 2166136261
	for index in range(text.length()):
		value = int((value ^ text.unicode_at(index)) % HASH_MODULUS)
		value = int((value * 16777619) % HASH_MODULUS)
	return value

static func _stable_stringify(value: Variant) -> String:
	if value is Dictionary:
		var parts := []
		for key in _sorted_keys(value):
			parts.append("%s:%s" % [JSON.stringify(String(key)), _stable_stringify(value[key])])
		return "{%s}" % ",".join(parts)
	if value is Array:
		var parts := []
		for item in value:
			parts.append(_stable_stringify(item))
		return "[%s]" % ",".join(parts)
	if value is String:
		return JSON.stringify(value)
	if value is bool:
		return "true" if bool(value) else "false"
	if value == null:
		return "null"
	return JSON.stringify(value)
