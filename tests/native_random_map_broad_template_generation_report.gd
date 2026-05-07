extends Node

const RandomMapGeneratorRulesScript = preload("res://scripts/core/RandomMapGeneratorRules.gd")
const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const PackageSurfaceReportScript = preload("res://tests/native_random_map_package_surface_topology_report.gd")

const REPORT_ID := "NATIVE_RANDOM_MAP_BROAD_TEMPLATE_GENERATION_REPORT"
const REPORT_SCHEMA_ID := "native_random_map_broad_template_generation_report_v4"
const DEFAULT_TEMPLATE_LIMIT := 12
const SIZE_CASES := [
	{"id": "homm3_small", "width": 36, "height": 36, "score": 1},
	{"id": "homm3_medium", "width": 72, "height": 72, "score": 4},
	{"id": "homm3_large", "width": 108, "height": 108, "score": 9},
	{"id": "homm3_extra_large", "width": 144, "height": 144, "score": 16},
]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ClassDB.class_exists("MapPackageService"):
		_fail("MapPackageService native class is not available.")
		return
	var service: Variant = ClassDB.instantiate("MapPackageService")
	var metadata: Dictionary = service.get_api_metadata()
	if String(metadata.get("binding_kind", "")) != "native_gdextension" or not bool(metadata.get("native_extension_loaded", false)):
		_fail("Native GDExtension metadata did not prove native load: %s" % JSON.stringify(metadata))
		return
	var catalog: Dictionary = ContentService.load_json(RandomMapGeneratorRulesScript.TEMPLATE_CATALOG_PATH)
	var templates: Array = catalog.get("templates", []) if catalog.get("templates", []) is Array else []
	var profiles_by_template := _profiles_by_template(catalog)
	var summaries := []
	var failures := []
	var skipped := []
	var not_implemented := []
	var not_implemented_translated := []
	var status_counts := {}
	var eligible_count := 0
	var attempted_count := 0
	var water_mode := _requested_water_mode()
	var underground_enabled := _requested_underground_enabled()
	var level_count := 2 if underground_enabled else 1
	var case_limit := _template_case_limit()
	var explicit_ids := _explicit_template_ids()
	var surface_helper: Node = PackageSurfaceReportScript.new()
	for template in templates:
		if not (template is Dictionary):
			continue
		var template_id := String(template.get("id", ""))
		if not explicit_ids.is_empty() and not explicit_ids.has(template_id):
			skipped.append({
				"template_id": template_id,
				"reason": "not_in_explicit_template_filter",
			})
			continue
		var plan := _generation_plan(template, profiles_by_template, water_mode, underground_enabled)
		if plan.is_empty():
			skipped.append({
				"template_id": template_id,
				"reason": "no_supported_%s_%s_size_or_profile" % [water_mode, "underground" if underground_enabled else "surface"],
			})
			continue
		eligible_count += 1
		if explicit_ids.is_empty() and case_limit > 0 and attempted_count >= case_limit:
			skipped.append({
				"template_id": template_id,
				"reason": "bounded_default_case_limit",
			})
			continue
		attempted_count += 1
		var summary := _run_template_case(service, template, plan, surface_helper)
		if bool(summary.get("ok", false)):
			summaries.append(summary)
			var status_key := String(summary.get("full_generation_status", ""))
			status_counts[status_key] = int(status_counts.get(status_key, 0)) + 1
			if String(summary.get("full_generation_status", "")) == "not_implemented":
				not_implemented.append(String(summary.get("template_id", "")))
				if String(summary.get("template_id", "")).begins_with("translated_rmg_template_"):
					not_implemented_translated.append(String(summary.get("template_id", "")))
		else:
			failures.append(summary)
	surface_helper.free()
	if attempted_count == 0:
		_fail("Broad template report did not attempt any templates; skipped=%s" % JSON.stringify(skipped))
		return
	if not failures.is_empty():
		_fail("Broad template generation/package failures remain: %s" % JSON.stringify(failures))
		return
	if not not_implemented_translated.is_empty():
		_fail("Broad translated land/surface templates still report full_generation_status=not_implemented: %s" % JSON.stringify(not_implemented_translated))
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"schema_id": REPORT_SCHEMA_ID,
		"ok": true,
		"binding_kind": metadata.get("binding_kind", ""),
		"native_extension_loaded": metadata.get("native_extension_loaded", false),
		"catalog_template_count": templates.size(),
		"water_mode": water_mode,
		"underground_enabled": underground_enabled,
		"level_count": level_count,
		"eligible_template_count": eligible_count,
		"attempted_template_count": summaries.size(),
		"case_limit": case_limit,
		"explicit_template_ids": explicit_ids,
		"skipped_template_count": skipped.size(),
		"not_implemented_status_count": not_implemented.size(),
		"not_implemented_templates": not_implemented,
		"not_implemented_translated_status_count": not_implemented_translated.size(),
		"not_implemented_translated_templates": not_implemented_translated,
		"full_generation_status_counts": status_counts,
		"cases": summaries,
		"skipped": skipped,
		"remaining_gap": "This proves every attempted %s/%s catalog template with a coherent profile can generate, validate, convert, expose non-empty package surfaces, and keep object-only player-start, cross-zone, and all-town package routes closed under package visit-tile semantics. It does not prove exact HoMM3 byte/object-art parity, underground production parity, or player-facing support for every recovered template." % [water_mode, "underground" if underground_enabled else "surface"],
	})])
	get_tree().quit(0)

func _run_template_case(service: Variant, template: Dictionary, plan: Dictionary, surface_helper: Node) -> Dictionary:
	var template_id := String(template.get("id", ""))
	var profile_id := String(plan.get("profile_id", ""))
	var size_class_id := String(plan.get("size_class_id", "homm3_small"))
	var player_count := int(plan.get("player_count", 2))
	var water_mode := String(plan.get("water_mode", "land"))
	var underground_enabled := bool(plan.get("underground_enabled", false))
	var level_count := int(plan.get("level_count", 2 if underground_enabled else 1))
	var started_at_msec := Time.get_ticks_msec()
	print("%s_CASE_START %s" % [REPORT_ID, JSON.stringify({
		"template_id": template_id,
		"profile_id": profile_id,
		"size_class_id": size_class_id,
		"player_count": player_count,
		"water_mode": water_mode,
		"underground_enabled": underground_enabled,
		"level_count": level_count,
	})])
	var config := ScenarioSelectRulesScript.build_random_map_player_config(
		"broad-template-generation-%s-10184" % template_id,
		template_id,
		profile_id,
		player_count,
		water_mode,
		underground_enabled,
		size_class_id
	)
	var generate_started_at_msec := Time.get_ticks_msec()
	var generated: Dictionary = service.generate_random_map(config, {
		"startup_path": "broad_template_generation_%s_%s" % [water_mode, template_id],
	})
	var generate_elapsed_msec := Time.get_ticks_msec() - generate_started_at_msec
	if not bool(generated.get("ok", false)):
		return _case_failure(template_id, "generate_random_map_not_ok", _generation_failure_summary(generated))
	if String(generated.get("validation_status", "")) != "pass":
		return _case_failure(template_id, "validation_not_pass", _generation_failure_summary(generated))
	var normalized: Dictionary = generated.get("normalized_config", {}) if generated.get("normalized_config", {}) is Dictionary else {}
	var zone_layout: Dictionary = generated.get("zone_layout", {}) if generated.get("zone_layout", {}) is Dictionary else {}
	var road_network: Dictionary = generated.get("road_network", {}) if generated.get("road_network", {}) is Dictionary else {}
	var objects: Array = generated.get("object_placements", []) if generated.get("object_placements", []) is Array else []
	var towns: Array = generated.get("town_records", []) if generated.get("town_records", []) is Array else []
	var guards: Array = generated.get("guard_records", []) if generated.get("guard_records", []) is Array else []
	var active_zone_count := _active_zone_count(template, player_count)
	var active_link_metrics := _active_link_metrics(template, player_count)
	var runtime_graph_summary := _runtime_graph_semantics(template_id, zone_layout, active_zone_count, active_link_metrics, player_count, int(normalized.get("width", 0)), int(normalized.get("height", 0)))
	if not bool(runtime_graph_summary.get("ok", false)):
		return _case_failure(template_id, "runtime_zone_graph_semantics_invalid", runtime_graph_summary)
	if int(zone_layout.get("zone_count", 0)) != active_zone_count:
		return _case_failure(template_id, "active_zone_count_mismatch", {
			"actual": int(zone_layout.get("zone_count", 0)),
			"expected": active_zone_count,
		})
	if int(road_network.get("road_cell_count", 0)) <= 0 or int(road_network.get("road_segment_count", 0)) <= 0:
		return _case_failure(template_id, "roads_not_materialized", road_network)
	if objects.is_empty() or towns.is_empty() or guards.is_empty():
		return _case_failure(template_id, "playable_object_categories_missing", {
			"objects": objects.size(),
			"towns": towns.size(),
			"guards": guards.size(),
		})
	var adoption_started_at_msec := Time.get_ticks_msec()
	var adoption: Dictionary = service.convert_generated_payload(generated, {
		"feature_gate": "native_rmg_broad_template_generation_report",
		"session_save_version": 9,
		"scenario_id": "native_broad_template_generation_%s" % template_id,
	})
	var adoption_elapsed_msec := Time.get_ticks_msec() - adoption_started_at_msec
	if not bool(adoption.get("ok", false)):
		return _case_failure(template_id, "convert_generated_payload_not_ok", _adoption_failure_summary(adoption))
	var map_document: Variant = adoption.get("map_document", null)
	if map_document == null:
		return _case_failure(template_id, "map_document_missing", _adoption_failure_summary(adoption))
	var surface_started_at_msec := Time.get_ticks_msec()
	var surface := _package_surface(map_document, surface_helper)
	var surface_elapsed_msec := Time.get_ticks_msec() - surface_started_at_msec
	if int(surface.get("object_count", 0)) <= 0 or int(surface.get("road_cell_count", 0)) <= 0 or int(surface.get("zero_tile_road_count", 0)) > 0:
		return _case_failure(template_id, "package_surface_invalid", surface)
	if int(surface.get("object_only_start_reachable_pair_count", 0)) > 0:
		return _case_failure(template_id, "package_object_only_start_town_routes_reachable", surface)
	if int(surface.get("object_only_cross_zone_reachable_pair_count", 0)) > 0:
		return _case_failure(template_id, "package_object_only_cross_zone_town_routes_reachable", surface)
	if int(surface.get("object_only_all_town_reachable_pair_count", 0)) > 0:
		surface["route_closure_debug"] = _route_closure_debug(map_document, surface.get("object_only_all_town_reachable_pairs", []))
		return _case_failure(template_id, "package_object_only_all_town_routes_reachable", surface)
	var elapsed_msec := Time.get_ticks_msec() - started_at_msec
	print("%s_CASE_OK %s" % [REPORT_ID, JSON.stringify({
		"template_id": template_id,
		"elapsed_msec": elapsed_msec,
		"generate_elapsed_msec": generate_elapsed_msec,
		"adoption_elapsed_msec": adoption_elapsed_msec,
		"surface_elapsed_msec": surface_elapsed_msec,
	})])
	return {
		"ok": true,
		"template_id": template_id,
		"profile_id": profile_id,
		"size_class_id": size_class_id,
		"player_count": player_count,
		"water_mode": water_mode,
		"underground_enabled": underground_enabled,
		"level_count": level_count,
		"selection_policy": String(plan.get("selection_policy", "minimum_supported_land_surface")),
		"full_generation_status": String(generated.get("full_generation_status", "")),
		"status": String(generated.get("status", "")),
		"width": int(normalized.get("width", 0)),
		"height": int(normalized.get("height", 0)),
		"zone_count": int(zone_layout.get("zone_count", 0)),
		"road_cell_count": int(road_network.get("road_cell_count", 0)),
		"road_segment_count": int(road_network.get("road_segment_count", 0)),
		"object_count": objects.size(),
		"town_count": towns.size(),
		"guard_count": guards.size(),
		"runtime_zone_graph": runtime_graph_summary,
		"elapsed_msec": elapsed_msec,
		"generate_elapsed_msec": generate_elapsed_msec,
		"adoption_elapsed_msec": adoption_elapsed_msec,
		"surface_elapsed_msec": surface_elapsed_msec,
		"extension_profile": _extension_profile_summary(generated),
		"package_surface": surface,
	}

func _generation_plan(template: Dictionary, profiles_by_template: Dictionary, water_mode: String, underground_enabled: bool) -> Dictionary:
	var template_id := String(template.get("id", ""))
	var profile: Dictionary = profiles_by_template.get(template_id, {}) if profiles_by_template.get(template_id, {}) is Dictionary else {}
	if profile.is_empty():
		return {}
	var level_count := 2 if underground_enabled else 1
	var support: Dictionary = template.get("map_support", {}) if template.get("map_support", {}) is Dictionary else {}
	var water_modes: Array = support.get("water_modes", []) if support.get("water_modes", []) is Array else []
	if not _water_mode_supported(water_modes, water_mode):
		return {}
	var levels: Dictionary = support.get("levels", {}) if support.get("levels", {}) is Dictionary else {}
	var supported_counts: Array = levels.get("supported_counts", []) if levels.get("supported_counts", []) is Array else []
	if not supported_counts.is_empty() and not _array_has_int(supported_counts, level_count):
		return {}
	var size_score: Dictionary = template.get("size_score", {}) if template.get("size_score", {}) is Dictionary else {}
	var min_score := int(size_score.get("min", 1))
	var max_score := int(size_score.get("max", 16))
	var default_plan := _player_facing_size_default_plan(template_id, profile, min_score, max_score, water_mode, water_modes, level_count)
	if not default_plan.is_empty():
		return default_plan
	var connected_player_counts := _connected_player_counts_for_template(template)
	if connected_player_counts.is_empty():
		return {}
	var players: Dictionary = template.get("players", {}) if template.get("players", {}) is Dictionary else {}
	var total: Dictionary = players.get("total", {}) if players.get("total", {}) is Dictionary else {}
	var min_players := int(total.get("min", 2))
	var max_players := int(total.get("max", 8))
	var player_count := int(connected_player_counts[0])
	for candidate_count in connected_player_counts:
		var count := int(candidate_count)
		if count >= min_players and count <= max_players:
			player_count = count
			break
	var active_zone_count := _active_zone_count(template, player_count)
	var selected_size := {}
	for size_case in SIZE_CASES:
		var score := _effective_size_score(int(size_case.get("score", 1)), water_mode, water_modes, level_count)
		if score >= min_score and score <= max_score:
			if not _size_case_has_generation_area(size_case, active_zone_count, underground_enabled):
				continue
			selected_size = size_case
			break
	if selected_size.is_empty():
		return {}
	return {
		"profile_id": String(profile.get("id", "")),
		"size_class_id": String(selected_size.get("id", "homm3_small")),
		"player_count": player_count,
		"water_mode": water_mode,
		"underground_enabled": underground_enabled,
		"level_count": level_count,
		"selection_policy": "minimum_supported_%s_%s" % [water_mode, "underground" if underground_enabled else "surface"],
	}

func _size_case_has_generation_area(size_case: Dictionary, active_zone_count: int, underground_enabled: bool) -> bool:
	if not underground_enabled:
		return true
	var width: int = int(size_case.get("width", 36))
	var height: int = int(size_case.get("height", 36))
	var surface_area: int = width * height
	var required_area: int = max(36 * 36, active_zone_count * 256)
	return surface_area >= required_area

func _player_facing_size_default_plan(template_id: String, profile: Dictionary, min_score: int, max_score: int, water_mode: String, water_modes: Array, level_count: int) -> Dictionary:
	if water_mode != "land" or level_count != 1:
		return {}
	for size_case in SIZE_CASES:
		var size_class_id := String(size_case.get("id", ""))
		var score := _effective_size_score(int(size_case.get("score", 1)), water_mode, water_modes, level_count)
		if score < min_score or score > max_score:
			continue
		var defaults: Dictionary = ScenarioSelectRulesScript.random_map_size_class_default(size_class_id)
		if String(defaults.get("template_id", "")) != template_id:
			continue
		if not _runtime_template_active_graph_connected(_template_by_id(template_id), int(defaults.get("player_count", 2))):
			continue
		var default_profile_id := String(defaults.get("profile_id", ""))
		if default_profile_id != "" and default_profile_id != String(profile.get("id", "")):
			continue
		return {
			"profile_id": String(profile.get("id", "")),
			"size_class_id": size_class_id,
			"player_count": int(defaults.get("player_count", 2)),
			"water_mode": water_mode,
			"underground_enabled": false,
			"level_count": 1,
			"selection_policy": "player_facing_size_default",
		}
	return {}

func _requested_water_mode() -> String:
	var raw := OS.get_environment("NATIVE_RMG_BROAD_WATER_MODE").strip_edges().to_lower()
	return "islands" if raw == "islands" else "land"

func _requested_underground_enabled() -> bool:
	var raw := OS.get_environment("NATIVE_RMG_BROAD_UNDERGROUND").strip_edges().to_lower()
	return raw in ["1", "true", "yes", "on", "underground"]

func _water_mode_supported(water_modes: Array, water_mode: String) -> bool:
	if water_modes.is_empty():
		return water_mode == "land"
	if water_mode == "land":
		return water_modes.has("land")
	for mode_value in water_modes:
		var mode := String(mode_value)
		if mode == "islands" or mode == "islands_size_score_halved":
			return true
	return false

func _effective_size_score(score: int, water_mode: String, water_modes: Array, level_count: int) -> int:
	var effective: int = score * max(1, level_count)
	if water_mode == "islands" and water_modes.has("islands_size_score_halved"):
		effective = max(1, int(effective / 2))
	return effective

func _profiles_by_template(catalog: Dictionary) -> Dictionary:
	var result := {}
	for profile in catalog.get("profiles", []):
		if profile is Dictionary:
			result[String(profile.get("template_id", ""))] = profile
	return result

func _template_by_id(template_id: String) -> Dictionary:
	var catalog: Dictionary = ContentService.load_json(RandomMapGeneratorRulesScript.TEMPLATE_CATALOG_PATH)
	for template in catalog.get("templates", []):
		if template is Dictionary and String(template.get("id", "")) == template_id:
			return template
	return {}

func _array_has_int(values: Array, expected: int) -> bool:
	for value in values:
		if int(value) == expected:
			return true
	return false

func _template_case_limit() -> int:
	var raw := OS.get_environment("NATIVE_RMG_BROAD_TEMPLATE_LIMIT")
	if raw.strip_edges().is_empty():
		return DEFAULT_TEMPLATE_LIMIT
	return int(raw)

func _explicit_template_ids() -> Array:
	var raw := OS.get_environment("NATIVE_RMG_BROAD_TEMPLATE_IDS")
	var ids := []
	for item in raw.split(",", false):
		var id := String(item).strip_edges()
		if not id.is_empty():
			ids.append(id)
	return ids

func _active_zone_count(template: Dictionary, player_count: int) -> int:
	var count := 0
	for zone in template.get("zones", []):
		if zone is Dictionary and _player_filter_allows(zone, player_count):
			count += 1
	return count

func _connected_player_counts_for_template(template: Dictionary) -> Array:
	var players: Dictionary = template.get("players", {}) if template.get("players", {}) is Dictionary else {}
	var total: Dictionary = players.get("total", {}) if players.get("total", {}) is Dictionary else {}
	var min_count := clampi(int(total.get("min", 2)), 2, 8)
	var max_count := clampi(int(total.get("max", min_count)), min_count, 8)
	var counts := []
	for count in range(min_count, max_count + 1):
		if _runtime_template_active_graph_connected(template, count):
			counts.append(count)
	return counts

func _runtime_template_active_graph_connected(template: Dictionary, player_count: int) -> bool:
	var active_zone_ids := {}
	for zone in template.get("zones", []):
		if zone is Dictionary and _player_filter_allows(zone, player_count):
			var zone_id := String(zone.get("id", ""))
			if not zone_id.is_empty():
				active_zone_ids[zone_id] = true
	if active_zone_ids.is_empty():
		return false
	var adjacency := {}
	for zone_id in active_zone_ids.keys():
		adjacency[String(zone_id)] = []
	for link in template.get("links", []):
		if not (link is Dictionary) or not _player_filter_allows(link, player_count):
			continue
		var from_zone := String(link.get("from", ""))
		var to_zone := String(link.get("to", ""))
		if not active_zone_ids.has(from_zone) or not active_zone_ids.has(to_zone):
			continue
		if not adjacency[from_zone].has(to_zone):
			adjacency[from_zone].append(to_zone)
		if not adjacency[to_zone].has(from_zone):
			adjacency[to_zone].append(from_zone)
	var start_zone := String(active_zone_ids.keys()[0])
	var visited := {start_zone: true}
	var queue := [start_zone]
	var cursor := 0
	while cursor < queue.size():
		var current := String(queue[cursor])
		cursor += 1
		for next_value in adjacency.get(current, []):
			var next := String(next_value)
			if visited.has(next):
				continue
			visited[next] = true
			queue.append(next)
	return visited.size() == active_zone_ids.size()

func _active_link_metrics(template: Dictionary, player_count: int) -> Dictionary:
	var active_zone_ids := {}
	for zone in template.get("zones", []):
		if zone is Dictionary and _player_filter_allows(zone, player_count):
			var zone_id := String(zone.get("id", ""))
			if not zone_id.is_empty():
				active_zone_ids[zone_id] = true
	var count := 0
	var wide_count := 0
	var border_guard_count := 0
	var guard_value_sum := 0
	var endpoint_keys := {}
	for link in template.get("links", []):
		if not (link is Dictionary) or not _player_filter_allows(link, player_count):
			continue
		var from_zone := String(link.get("from", ""))
		var to_zone := String(link.get("to", ""))
		if not active_zone_ids.has(from_zone) or not active_zone_ids.has(to_zone):
			continue
		count += 1
		if bool(link.get("wide", false)):
			wide_count += 1
		if bool(link.get("border_guard", false)):
			border_guard_count += 1
		var guard: Dictionary = link.get("guard", {}) if link.get("guard", {}) is Dictionary else {}
		guard_value_sum += int(link.get("guard_value", guard.get("value", 0)))
		endpoint_keys["%s->%s" % [from_zone, to_zone]] = true
	return {
		"active_zone_ids": active_zone_ids,
		"active_link_count": count,
		"wide_link_count": wide_count,
		"border_guard_link_count": border_guard_count,
		"guard_value_sum": guard_value_sum,
		"endpoint_keys": endpoint_keys,
	}

func _player_filter_allows(record: Dictionary, player_count: int) -> bool:
	var player_filter: Dictionary = record.get("player_filter", {}) if record.get("player_filter", {}) is Dictionary else {}
	if player_filter.is_empty():
		return true
	var min_total := int(player_filter.get("min_total", 1))
	var max_total := int(player_filter.get("max_total", 8))
	return player_count >= min_total and player_count <= max_total

func _runtime_graph_semantics(template_id: String, zone_layout: Dictionary, expected_zone_count: int, active_link_metrics: Dictionary, player_count: int, width: int, height: int) -> Dictionary:
	var failures := []
	var runtime_graph: Dictionary = zone_layout.get("runtime_zone_graph", {}) if zone_layout.get("runtime_zone_graph", {}) is Dictionary else {}
	var validation: Dictionary = runtime_graph.get("validation", {}) if runtime_graph.get("validation", {}) is Dictionary else {}
	var zones: Array = runtime_graph.get("zones", []) if runtime_graph.get("zones", []) is Array else []
	var links: Array = runtime_graph.get("links", []) if runtime_graph.get("links", []) is Array else []
	if String(runtime_graph.get("schema_id", "")) != "aurelion_native_rmg_runtime_zone_graph_v1":
		failures.append("runtime_graph_schema_missing")
	if String(validation.get("status", "")) != "pass":
		failures.append("runtime_graph_validation_not_pass")
	if not bool(runtime_graph.get("template_supported_for_config", false)):
		failures.append("runtime_graph_template_not_supported_for_config")
	if String(runtime_graph.get("source_template_id", "")) != template_id:
		failures.append("runtime_graph_source_template_drifted")
	if int(runtime_graph.get("zone_count", 0)) != expected_zone_count or zones.size() != expected_zone_count:
		failures.append("runtime_graph_zone_count_drifted")
	var expected_link_count := int(active_link_metrics.get("active_link_count", 0))
	if int(runtime_graph.get("link_count", 0)) != expected_link_count or links.size() != expected_link_count:
		failures.append("runtime_graph_link_count_drifted")
	if int(validation.get("target_area_sum", 0)) != width * height or int(validation.get("cell_count_sum", 0)) != width * height:
		failures.append("runtime_graph_area_coverage_drifted")
	if int(validation.get("start_zone_count", 0)) != player_count:
		failures.append("runtime_graph_start_zone_count_drifted")
	if int(validation.get("wide_link_count", 0)) != int(active_link_metrics.get("wide_link_count", 0)):
		failures.append("runtime_graph_wide_link_count_drifted")
	if int(validation.get("border_guard_link_count", 0)) != int(active_link_metrics.get("border_guard_link_count", 0)):
		failures.append("runtime_graph_border_guard_link_count_drifted")
	var zone_metrics := _runtime_graph_zone_metrics(zones, player_count)
	if not bool(zone_metrics.get("ok", false)):
		failures.append("runtime_graph_zone_payload_semantics_missing")
	var link_metrics := _runtime_graph_link_metrics(links, active_link_metrics)
	if not bool(link_metrics.get("ok", false)):
		failures.append("runtime_graph_link_payload_semantics_missing")
	return {
		"ok": failures.is_empty(),
		"failures": failures,
		"zone_count": zones.size(),
		"expected_zone_count": expected_zone_count,
		"link_count": links.size(),
		"expected_link_count": expected_link_count,
		"start_zone_count": int(validation.get("start_zone_count", 0)),
		"wide_link_count": int(validation.get("wide_link_count", 0)),
		"border_guard_link_count": int(validation.get("border_guard_link_count", 0)),
		"guard_value_sum": int(link_metrics.get("guard_value_sum", 0)),
		"expected_guard_value_sum": int(active_link_metrics.get("guard_value_sum", 0)),
		"zone_metrics": zone_metrics,
		"link_metrics": link_metrics,
	}

func _runtime_graph_zone_metrics(zones: Array, player_count: int) -> Dictionary:
	var failures := []
	var start_count := 0
	var neutral_count := 0
	var target_sum := 0
	var cell_sum := 0
	for zone in zones:
		if not (zone is Dictionary):
			failures.append({"reason": "non_dictionary_zone"})
			continue
		var zone_id := String(zone.get("id", ""))
		for key in ["runtime_id", "source_template_id", "source_zone_id", "source_role", "source_owner_slot", "base_size", "target_area", "terrain_rules", "town_rules", "mine_rules", "resource_rules", "treasure_bands", "monster_rules", "adjacent_zone_ids", "runtime_links", "diagnostics"]:
			if not zone.has(key):
				failures.append({"zone_id": zone_id, "missing_key": key})
		if int(zone.get("target_area", 0)) <= 0 or int(zone.get("cell_count", 0)) <= 0:
			failures.append({"zone_id": zone_id, "reason": "missing_target_or_cell_area"})
		if String(zone.get("role", "")).contains("start"):
			start_count += 1
			if zone.get("owner_slot", null) == null or zone.get("player_slot", null) == null:
				failures.append({"zone_id": zone_id, "reason": "start_zone_missing_owner_or_player_slot"})
		if zone.get("owner_slot", null) == null:
			neutral_count += 1
		target_sum += int(zone.get("target_area", 0))
		cell_sum += int(zone.get("cell_count", 0))
	return {
		"ok": failures.is_empty(),
		"failures": failures.slice(0, min(8, failures.size())),
		"start_count": start_count,
		"expected_start_count": player_count,
		"neutral_count": neutral_count,
		"target_area_sum": target_sum,
		"cell_count_sum": cell_sum,
	}

func _runtime_graph_link_metrics(links: Array, active_link_metrics: Dictionary) -> Dictionary:
	var failures := []
	var endpoint_keys: Dictionary = active_link_metrics.get("endpoint_keys", {}) if active_link_metrics.get("endpoint_keys", {}) is Dictionary else {}
	var seen_endpoint_keys := {}
	var wide_count := 0
	var border_guard_count := 0
	var guard_value_sum := 0
	var repair_link_count := 0
	for link in links:
		if not (link is Dictionary):
			failures.append({"reason": "non_dictionary_link"})
			continue
		var runtime_id := String(link.get("runtime_id", ""))
		var from_zone := String(link.get("from_zone_id", link.get("from", "")))
		var to_zone := String(link.get("to_zone_id", link.get("to", "")))
		for key in ["runtime_id", "source_template_id", "from_zone_id", "to_zone_id", "value", "guard_value", "wide", "border_guard", "road_policy", "guard_policy", "diagnostics", "source"]:
			if not link.has(key):
				failures.append({"link": runtime_id, "missing_key": key})
		var forward_key := "%s->%s" % [from_zone, to_zone]
		var reverse_key := "%s->%s" % [to_zone, from_zone]
		if not endpoint_keys.has(forward_key) and not endpoint_keys.has(reverse_key):
			failures.append({"link": runtime_id, "reason": "runtime_link_endpoint_not_in_active_catalog", "from": from_zone, "to": to_zone})
		seen_endpoint_keys[forward_key] = true
		var guard_policy: Dictionary = link.get("guard_policy", {}) if link.get("guard_policy", {}) is Dictionary else {}
		var guard_value := int(link.get("guard_value", link.get("value", 0)))
		guard_value_sum += guard_value
		if bool(link.get("wide", false)):
			wide_count += 1
			if int(guard_policy.get("normal_guard_value", -1)) != 0 or not bool(guard_policy.get("wide_suppresses_normal_guard", false)):
				failures.append({"link": runtime_id, "reason": "wide_link_guard_not_suppressed"})
		else:
			if int(guard_policy.get("normal_guard_value", guard_value)) != guard_value:
				failures.append({"link": runtime_id, "reason": "normal_link_guard_value_not_preserved"})
		if bool(link.get("border_guard", false)):
			border_guard_count += 1
			if not bool(guard_policy.get("border_guard_special_mode", false)):
				failures.append({"link": runtime_id, "reason": "border_guard_policy_not_preserved"})
		if String(link.get("source", "")).contains("repair") or String(link.get("role", "")).contains("repair"):
			repair_link_count += 1
			failures.append({"link": runtime_id, "reason": "runtime_link_repair_substituted_for_catalog_semantics"})
	if guard_value_sum != int(active_link_metrics.get("guard_value_sum", 0)):
		failures.append({"reason": "runtime_link_guard_value_sum_drifted", "actual": guard_value_sum, "expected": int(active_link_metrics.get("guard_value_sum", 0))})
	if wide_count != int(active_link_metrics.get("wide_link_count", 0)):
		failures.append({"reason": "runtime_link_wide_count_drifted", "actual": wide_count, "expected": int(active_link_metrics.get("wide_link_count", 0))})
	if border_guard_count != int(active_link_metrics.get("border_guard_link_count", 0)):
		failures.append({"reason": "runtime_link_border_guard_count_drifted", "actual": border_guard_count, "expected": int(active_link_metrics.get("border_guard_link_count", 0))})
	return {
		"ok": failures.is_empty(),
		"failures": failures.slice(0, min(8, failures.size())),
		"wide_count": wide_count,
		"border_guard_count": border_guard_count,
		"guard_value_sum": guard_value_sum,
		"repair_link_count": repair_link_count,
		"seen_endpoint_count": seen_endpoint_keys.size(),
	}

func _package_surface(map_document: Variant, surface_helper: Node) -> Dictionary:
	var summary: Dictionary = surface_helper._package_surface_summary(map_document, "broad_template_package")
	var object_only_start: Dictionary = summary.get("object_only_start_town_topology", {}) if summary.get("object_only_start_town_topology", {}) is Dictionary else {}
	var object_only_cross_zone: Dictionary = summary.get("object_only_cross_zone_town_topology", {}) if summary.get("object_only_cross_zone_town_topology", {}) is Dictionary else {}
	var object_only_all: Dictionary = summary.get("object_only_town_topology", {}) if summary.get("object_only_town_topology", {}) is Dictionary else {}
	return {
		"object_count": int(summary.get("object_count", 0)),
		"town_count": int(summary.get("town_count", 0)),
		"guard_count": int(summary.get("guard_count", 0)),
		"zone_count": int(summary.get("zone_count", 0)),
		"road_count": int(summary.get("road_count", 0)),
		"road_cell_count": int(summary.get("road_unique_tile_count", 0)),
		"zero_tile_road_count": int(summary.get("zero_tile_road_count", 0)),
		"object_only_blocked_tile_count": int(summary.get("object_only_blocked_tile_count", 0)),
		"object_only_start_checked_pair_count": int(object_only_start.get("checked_pair_count", 0)),
		"object_only_start_reachable_pair_count": int(object_only_start.get("reachable_pair_count", 0)),
		"object_only_start_reachable_pairs": object_only_start.get("reachable_pairs", []),
		"object_only_cross_zone_checked_pair_count": int(object_only_cross_zone.get("checked_pair_count", 0)),
		"object_only_cross_zone_reachable_pair_count": int(object_only_cross_zone.get("reachable_pair_count", 0)),
		"object_only_cross_zone_reachable_pairs": object_only_cross_zone.get("reachable_pairs", []),
		"object_only_all_town_checked_pair_count": int(object_only_all.get("checked_pair_count", 0)),
		"object_only_all_town_reachable_pair_count": int(object_only_all.get("reachable_pair_count", 0)),
		"object_only_all_town_reachable_pairs": object_only_all.get("reachable_pairs", []),
	}

func _route_closure_debug(map_document: Variant, reachable_pairs: Variant) -> Dictionary:
	var target_lookup := {}
	if reachable_pairs is Array:
		for pair in reachable_pairs:
			if not (pair is Dictionary):
				continue
			var path_sample: Array = pair.get("path_sample", []) if pair.get("path_sample", []) is Array else []
			for point in path_sample:
				if point is Dictionary and point.has("x") and point.has("y"):
					target_lookup["%d:%d,%d" % [int(point.get("level", 0)), int(point.get("x", 0)), int(point.get("y", 0))]] = true
	var source_counts := {}
	var target_hits := {}
	var decorative_route_object_count := 0
	var guard_route_object_count := 0
	for index in range(int(map_document.get_object_count())):
		var object: Dictionary = map_document.get_object_by_index(index)
		var decorative_source := String(object.get("package_route_decorative_closure_mask_source", ""))
		var guard_source := String(object.get("package_route_guard_closure_mask_source", ""))
		if not decorative_source.is_empty():
			decorative_route_object_count += 1
			source_counts[decorative_source] = int(source_counts.get(decorative_source, 0)) + 1
		if not guard_source.is_empty():
			guard_route_object_count += 1
			source_counts[guard_source] = int(source_counts.get(guard_source, 0)) + 1
		var block_tiles: Array = object.get("package_block_tiles", []) if object.get("package_block_tiles", []) is Array else []
		for tile in block_tiles:
			if not (tile is Dictionary):
				continue
			var key := "%d:%d,%d" % [int(tile.get("level", 0)), int(tile.get("x", 0)), int(tile.get("y", 0))]
			if not target_lookup.has(key):
				continue
			if not target_hits.has(key):
				target_hits[key] = []
			target_hits[key].append({
				"kind": String(object.get("kind", "")),
				"placement_id": String(object.get("placement_id", "")),
				"decorative_source": decorative_source,
				"guard_source": guard_source,
			})
	return {
		"target_path_cell_count": target_lookup.size(),
		"target_block_hit_count": target_hits.size(),
		"target_block_hits": target_hits,
		"decorative_route_object_count": decorative_route_object_count,
		"guard_route_object_count": guard_route_object_count,
		"source_counts": source_counts,
	}

func _extension_profile_summary(generated: Dictionary) -> Dictionary:
	var profile: Dictionary = generated.get("extension_profile", {}) if generated.get("extension_profile", {}) is Dictionary else {}
	var object_summary: Dictionary = generated.get("object_placement_pipeline_summary", {}) if generated.get("object_placement_pipeline_summary", {}) is Dictionary else {}
	var object_profile: Dictionary = object_summary.get("runtime_phase_profile", {}) if object_summary.get("runtime_phase_profile", {}) is Dictionary else {}
	var town_guard_summary: Dictionary = generated.get("town_guard_placement", {}) if generated.get("town_guard_placement", {}) is Dictionary else {}
	var town_guard_profile: Dictionary = town_guard_summary.get("runtime_phase_profile", {}) if town_guard_summary.get("runtime_phase_profile", {}) is Dictionary else {}
	return {
		"total_elapsed_msec": float(profile.get("total_elapsed_msec", 0.0)),
		"top_phase_id": String(profile.get("top_phase_id", "")),
		"top_phase_elapsed_msec": float(profile.get("top_phase_elapsed_msec", 0.0)),
		"top_phases": _top_phases(profile.get("phases", []) if profile.get("phases", []) is Array else [], 5),
		"object_total_elapsed_msec": float(object_profile.get("total_elapsed_msec", 0.0)),
		"object_top_phase_id": String(object_profile.get("top_phase_id", "")),
		"object_top_phase_elapsed_msec": float(object_profile.get("top_phase_elapsed_msec", 0.0)),
		"object_top_phases": _top_phases(object_profile.get("phases", []) if object_profile.get("phases", []) is Array else [], 5),
		"town_guard_total_elapsed_msec": float(town_guard_profile.get("total_elapsed_msec", 0.0)),
		"town_guard_top_phase_id": String(town_guard_profile.get("top_phase_id", "")),
		"town_guard_top_phase_elapsed_msec": float(town_guard_profile.get("top_phase_elapsed_msec", 0.0)),
		"town_guard_top_phases": _top_phases(town_guard_profile.get("phases", []) if town_guard_profile.get("phases", []) is Array else [], 8),
	}

func _top_phases(phases: Array, count: int) -> Array:
	var remaining := phases.duplicate(true)
	var top := []
	for _index in range(count):
		var best_index := -1
		var best_elapsed := -1.0
		for phase_index in range(remaining.size()):
			var phase: Dictionary = remaining[phase_index] if remaining[phase_index] is Dictionary else {}
			var elapsed := float(phase.get("elapsed_msec", 0.0))
			if elapsed > best_elapsed:
				best_elapsed = elapsed
				best_index = phase_index
		if best_index < 0:
			break
		var best: Dictionary = remaining[best_index]
		top.append({
			"phase_id": String(best.get("phase_id", "")),
			"elapsed_msec": float(best.get("elapsed_msec", 0.0)),
			"percent_total": float(best.get("percent_total", 0.0)),
		})
		remaining.remove_at(best_index)
	return top

func _case_failure(template_id: String, reason: String, detail: Variant) -> Dictionary:
	return {
		"ok": false,
		"template_id": template_id,
		"reason": reason,
		"detail": detail,
	}

func _generation_failure_summary(generated: Dictionary) -> Dictionary:
	var validation_report: Dictionary = generated.get("validation_report", {}) if generated.get("validation_report", {}) is Dictionary else generated
	var failures: Array = validation_report.get("failures", []) if validation_report.get("failures", []) is Array else []
	var warnings: Array = validation_report.get("warnings", []) if validation_report.get("warnings", []) is Array else []
	return {
		"ok": bool(generated.get("ok", false)),
		"status": String(generated.get("status", "")),
		"validation_status": String(generated.get("validation_status", validation_report.get("validation_status", ""))),
		"normalized_player_constraints": _normalized_player_constraints(generated),
		"failure_count": int(validation_report.get("failure_count", failures.size())),
		"failures": _limited_issue_list(failures, 8),
		"warning_count": int(validation_report.get("warning_count", warnings.size())),
		"warnings": _limited_issue_list(warnings, 4),
		"component_counts": validation_report.get("component_counts", {}),
		"component_summaries": _component_statuses(validation_report.get("component_summaries", {})),
		"player_starts": _player_start_failure_status(generated.get("player_starts", {})),
		"start_zones": _start_zone_status(generated.get("zone_layout", {})),
		"combined_occupancy": _combined_occupancy_failure_status(generated.get("town_guard_placement", {})),
		"object_pipeline": _object_pipeline_failure_status(generated.get("object_placement_pipeline_summary", {})),
		"metrics": generated.get("metrics", {}),
		"full_generation_status": String(generated.get("full_generation_status", "")),
		"supported_parity_config": bool(generated.get("supported_parity_config", false)),
		"owner_compared_translated_profile_supported": bool(generated.get("owner_compared_translated_profile_supported", false)),
	}

func _adoption_failure_summary(adoption: Dictionary) -> Dictionary:
	return {
		"ok": bool(adoption.get("ok", false)),
		"status": String(adoption.get("status", "")),
		"errors": adoption.get("errors", []),
		"warnings": adoption.get("warnings", []),
	}

func _normalized_player_constraints(generated: Dictionary) -> Dictionary:
	var normalized: Dictionary = generated.get("normalized_config", {}) if generated.get("normalized_config", {}) is Dictionary else {}
	var constraints: Dictionary = normalized.get("player_constraints", {}) if normalized.get("player_constraints", {}) is Dictionary else {}
	return {
		"human_count": int(constraints.get("human_count", 0)),
		"computer_count": int(constraints.get("computer_count", 0)),
		"player_count": int(constraints.get("player_count", 0)),
	}

func _player_start_failure_status(player_starts: Variant) -> Dictionary:
	if not (player_starts is Dictionary):
		return {}
	var payload: Dictionary = player_starts
	var starts := []
	for start in payload.get("starts", []):
		if start is Dictionary:
			starts.append({
				"start_id": String(start.get("start_id", "")),
				"player_slot": int(start.get("player_slot", 0)),
				"owner_slot": int(start.get("owner_slot", 0)),
				"zone_id": String(start.get("zone_id", "")),
				"zone_role": String(start.get("zone_role", "")),
			})
	return {
		"start_count": int(payload.get("start_count", 0)),
		"expected_player_count": int(payload.get("expected_player_count", 0)),
		"starts": starts,
	}

func _start_zone_status(zone_layout: Variant) -> Array:
	var result := []
	if not (zone_layout is Dictionary):
		return result
	var zones: Array = zone_layout.get("zones", []) if zone_layout.get("zones", []) is Array else []
	for zone in zones:
		if not (zone is Dictionary):
			continue
		if zone.get("player_slot", null) != null or String(zone.get("role", "")).contains("start"):
			result.append({
				"id": String(zone.get("id", "")),
				"role": String(zone.get("role", "")),
				"source_role": String(zone.get("source_role", "")),
				"owner_slot": int(zone.get("owner_slot", 0)) if zone.get("owner_slot", null) != null else -1,
				"player_slot": int(zone.get("player_slot", 0)) if zone.get("player_slot", null) != null else -1,
				"player_type": String(zone.get("player_type", "")),
			})
	return result

func _combined_occupancy_failure_status(town_guard_placement: Variant) -> Dictionary:
	if not (town_guard_placement is Dictionary):
		return {}
	var payload: Dictionary = town_guard_placement
	var occupancy: Dictionary = payload.get("combined_occupancy_index", {}) if payload.get("combined_occupancy_index", {}) is Dictionary else {}
	var duplicates: Array = occupancy.get("duplicates", []) if occupancy.get("duplicates", []) is Array else []
	var limited := []
	for duplicate in duplicates:
		if limited.size() >= 6:
			break
		if duplicate is Dictionary:
			limited.append(duplicate)
	return {
		"status": String(occupancy.get("status", "")),
		"duplicate_primary_tile_count": int(occupancy.get("duplicate_primary_tile_count", 0)),
		"occupied_primary_tile_count": int(occupancy.get("occupied_primary_tile_count", 0)),
		"object_count": int(occupancy.get("object_count", 0)),
		"town_count": int(occupancy.get("town_count", 0)),
		"guard_count": int(occupancy.get("guard_count", 0)),
		"duplicates": limited,
	}

func _limited_issue_list(issues: Array, limit: int) -> Array:
	var result := []
	for issue in issues:
		if result.size() >= limit:
			break
		if issue is Dictionary:
			result.append({
				"code": String(issue.get("code", "")),
				"path": String(issue.get("path", "")),
				"message": String(issue.get("message", "")),
				"severity": String(issue.get("severity", "")),
			})
	return result

func _component_statuses(component_summaries: Variant) -> Dictionary:
	var result := {}
	if not (component_summaries is Dictionary):
		return result
	for key in component_summaries.keys():
		var summary: Variant = component_summaries[key]
		if summary is Dictionary:
			result[String(key)] = {
				"count": int(summary.get("count", 0)),
				"generation_status": String(summary.get("generation_status", "")),
				"validation_status": String(summary.get("validation_status", "")),
			}
	return result

func _object_pipeline_failure_status(summary: Variant) -> Dictionary:
	if not (summary is Dictionary):
		return {}
	var pipeline: Dictionary = summary
	var xl_cost: Dictionary = pipeline.get("xl_cost", {}) if pipeline.get("xl_cost", {}) is Dictionary else {}
	return {
		"validation_status": String(pipeline.get("validation_status", "")),
		"object_count": int(pipeline.get("object_count", 0)),
		"occupancy_status": String(pipeline.get("occupancy_status", "")),
		"body_tile_reference_count": int(pipeline.get("body_tile_reference_count", 0)),
		"body_overlap_count": int(pipeline.get("body_overlap_count", 0)),
		"missing_definition_count": int(pipeline.get("missing_definition_count", 0)),
		"missing_mask_count": int(pipeline.get("missing_mask_count", 0)),
		"missing_writeout_count": int(pipeline.get("missing_writeout_count", 0)),
		"limit_failure_count": int(pipeline.get("limit_failure_count", 0)),
		"limit_failures": pipeline.get("limit_failures", {}),
		"decorative_filler_count": int(pipeline.get("decorative_filler_count", 0)),
		"decorative_filler_ordinary_template_count": int(pipeline.get("decorative_filler_ordinary_template_count", 0)),
		"xl_cost_status": String(xl_cost.get("status", "")),
		"xl_cost_elapsed_msec": float(xl_cost.get("elapsed_msec", 0.0)),
	}

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
