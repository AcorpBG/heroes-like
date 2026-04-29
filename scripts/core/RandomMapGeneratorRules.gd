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
	{"purpose": "start_support_wood", "site_id": "site_wood_wagon", "offset": Vector2i(1, 0)},
	{"purpose": "start_support_ore", "site_id": "site_ore_crates", "offset": Vector2i(0, 1)},
	{"purpose": "start_support_cache", "site_id": "site_waystone_cache", "offset": Vector2i(-1, 0)},
]
const DEFAULT_ENCOUNTER_ID := "encounter_mire_raid"

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

	var placements := _place_generated_objects(zones, template.get("links", []), seeds, zone_grid, normalized, rng)
	phases.append(_phase_record("object_placement_staging", _placement_counts(placements.get("object_placements", []))))

	var terrain_rows := _terrain_rows_from_zone_grid(zone_grid, zones)
	var scenario_record := _build_scenario_record(normalized, terrain_rows, placements)
	var terrain_layers_record := _build_terrain_layers_record(normalized, template.get("links", []), seeds)
	var staging := _build_staging_payload(normalized, template, zones, seeds, zone_grid, placements)

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
	var ok := bool(first.get("ok", false)) and bool(second.get("ok", false)) and bool(third.get("ok", false)) and same_payload and same_signature and changed_seed_changes_payload
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
	var phase_names := []
	for phase in generated_map.get("phase_pipeline", []):
		if phase is Dictionary:
			phase_names.append(String(phase.get("phase", "")))
	for required_phase in ["template_profile", "runtime_zone_graph", "zone_seed_layout", "terrain_owner_grid", "object_placement_staging"]:
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
		if matched in terrain_ids:
			return matched
	if terrain_ids.is_empty():
		return "grass"
	return String(terrain_ids[rng.next_index(terrain_ids.size())])

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

static func _place_generated_objects(zones: Array, links: Array, seeds: Dictionary, zone_grid: Array, normalized: Dictionary, rng: DeterministicRng) -> Dictionary:
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
		var point := _nearest_free_cell(int(seed.get("x", 0)), int(seed.get("y", 0)), String(zone.get("id", "")), zone_grid, occupied, rng)
		if point.is_empty():
			continue
		var owner := "player" if int(zone.get("owner_slot", 0)) == 1 else "enemy"
		var faction_id := String(zone.get("faction_id", ""))
		var town_id := String(town_ids[player_index % town_ids.size()])
		var placement_id := "rmg_town_p%d" % (player_index + 1)
		var town := {"placement_id": placement_id, "town_id": town_id, "x": int(point.get("x", 0)), "y": int(point.get("y", 0)), "owner": owner}
		towns.append(town)
		placements.append(_object_placement(placement_id, "town", faction_id, String(zone.get("id", "")), point, {"town_id": town_id, "owner": owner, "purpose": "player_start"}))
		_mark_occupied(occupied, point)
		for resource_index in range(SUPPORT_RESOURCE_SITES.size()):
			var resource: Dictionary = SUPPORT_RESOURCE_SITES[resource_index]
			var support_point := _nearest_free_cell(
				int(point.get("x", 0)) + resource.get("offset", Vector2i.ZERO).x,
				int(point.get("y", 0)) + resource.get("offset", Vector2i.ZERO).y,
				String(zone.get("id", "")),
				zone_grid,
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
			occupied,
			rng
		)
		if guard_point.is_empty():
			continue
		var encounter_placement_id := "rmg_link_guard_%02d" % (index + 1)
		encounters.append({"placement_id": encounter_placement_id, "encounter_id": String(profile.get("encounter_id", DEFAULT_ENCOUNTER_ID)), "x": int(guard_point.get("x", 0)), "y": int(guard_point.get("y", 0)), "difficulty": "generated_core"})
		placements.append(_object_placement(encounter_placement_id, "route_guard", "", _zone_at_point(zone_grid, guard_point), guard_point, {"encounter_id": String(profile.get("encounter_id", DEFAULT_ENCOUNTER_ID)), "purpose": String(link.get("role", "route")), "guard_value": int(link.get("guard_value", 0)), "wide": bool(link.get("wide", false)), "border_guard": bool(link.get("border_guard", false))}))
		_mark_occupied(occupied, guard_point)
	return {
		"object_placements": placements,
		"towns": towns,
		"resource_nodes": resource_nodes,
		"encounters": encounters,
	}

static func _build_scenario_record(normalized: Dictionary, terrain_rows: Array, placements: Dictionary) -> Dictionary:
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
	}

static func _build_terrain_layers_record(normalized: Dictionary, links: Array, seeds: Dictionary) -> Dictionary:
	var profile: Dictionary = normalized.get("profile", {})
	var metadata := _metadata(normalized)
	return {
		"id": "generated_layers_%s_%s" % [String(profile.get("id", "seeded_core")), _hash32_hex(_stable_stringify(metadata))],
		"terrain_layer_status": "generated_staged_draft",
		"generated_metadata": metadata,
		"roads": [],
		"route_graph_stub": _route_graph_payload(links, seeds),
		"deferred": ["road_overlay_writeout", "river_overlay_writeout"],
	}

static func _build_staging_payload(normalized: Dictionary, template: Dictionary, zones: Array, seeds: Dictionary, zone_grid: Array, placements: Dictionary) -> Dictionary:
	return {
		"staging_schema": "random_map_generation_staging_v1",
		"template": template,
		"zones": _zones_for_payload(zones),
		"zone_seed_points": _sorted_point_dict(seeds),
		"terrain_owner_grid": zone_grid,
		"route_graph": _route_graph_payload(template.get("links", []), seeds),
		"object_placements": placements.get("object_placements", []),
		"metadata": _metadata(normalized),
		"editable_grid_model": "terrain_owner_grid_rows_plus_separate_object_placement_arrays",
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

static func _nearest_free_cell(x: int, y: int, preferred_zone_id: Variant, zone_grid: Array, occupied: Dictionary, rng: DeterministicRng) -> Dictionary:
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
