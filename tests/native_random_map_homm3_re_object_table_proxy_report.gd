extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")

const REPORT_ID := "NATIVE_RANDOM_MAP_HOMM3_RE_OBJECT_TABLE_PROXY_REPORT"
const REPORT_SCHEMA_ID := "native_random_map_homm3_re_object_table_proxy_report_v2"
const ELIGIBILITY_PATH := "res://content/random_map_object_eligibility.json"
const MAP_OBJECTS_PATH := "res://content/map_objects.json"
const RESOURCE_SITES_PATH := "res://content/resource_sites.json"
const ARTIFACTS_PATH := "res://content/artifacts.json"

const CASES := [
	{"id": "small", "seed": "native-object-pool-small", "template": "frontier_spokes_v1", "profile": "frontier_spokes_profile_v1", "size": "homm3_small", "players": 3},
	{"id": "medium", "seed": "native-object-pool-medium", "template": "translated_rmg_template_041_v1", "profile": "translated_rmg_profile_041_v1", "size": "homm3_medium", "players": 4},
	{"id": "large", "seed": "native-object-pool-large", "template": "translated_rmg_template_042_v1", "profile": "translated_rmg_profile_042_v1", "size": "homm3_large", "players": 4},
	{"id": "extra_large", "seed": "native-object-pool-extra-large", "template": "translated_rmg_template_043_v1", "profile": "translated_rmg_profile_043_v1", "size": "homm3_extra_large", "players": 8},
]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ClassDB.class_exists("MapPackageService"):
		_fail("MapPackageService native class is unavailable.")
		return
	var registry := _load_json(ELIGIBILITY_PATH)
	var authored := _load_json(MAP_OBJECTS_PATH)
	var sites := _load_json(RESOURCE_SITES_PATH)
	var artifacts := _load_json(ARTIFACTS_PATH)
	var static_summary := _validate_registry(registry, authored, sites, artifacts)
	if static_summary.is_empty():
		return

	var service: Variant = ClassDB.instantiate("MapPackageService")
	var case_summaries := []
	var selected_ids := {}
	var aggregate_resolution_counts := {}
	for case_record in CASES:
		var summary := _run_case(service, case_record, static_summary.get("candidate_ids_by_pool", {}))
		if summary.is_empty():
			return
		case_summaries.append(summary)
		for candidate_id in summary.get("selected_candidate_ids", []):
			selected_ids[String(candidate_id)] = true
		_merge_counts(aggregate_resolution_counts, summary.get("resolution_counts", {}))
	if selected_ids.size() < 24:
		_fail("Small through Extra Large cases selected too little authored-object diversity: %d" % selected_ids.size())
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"schema_id": REPORT_SCHEMA_ID,
		"ok": true,
		"static_registry": static_summary.get("public_summary", {}),
		"cases": case_summaries,
		"aggregate_resolution_counts": aggregate_resolution_counts,
		"unique_selected_candidate_count": selected_ids.size(),
		"native_generation_boundary": registry.get("native_generation_boundary", ""),
	})])
	get_tree().quit(0)

func _validate_registry(registry: Dictionary, authored: Dictionary, sites: Dictionary, artifacts: Dictionary) -> Dictionary:
	if String(registry.get("schema_id", "")) != "aurelion_random_map_object_eligibility_v1":
		_fail("Eligibility registry schema is missing or invalid.")
		return {}
	var site_ids := _id_set(sites.get("items", []))
	var artifact_ids := _id_set(artifacts.get("items", []))
	var candidate_ids_by_pool := {}
	var eligible_ids := {}
	for pool_value in registry.get("authored_pools", []):
		if not (pool_value is Dictionary):
			continue
		var pool: Dictionary = pool_value
		var pool_id := String(pool.get("id", ""))
		var ids := {}
		if String(pool.get("content_domain", "")) == "artifact":
			ids = artifact_ids.duplicate()
		else:
			for item_value in authored.get("items", []):
				if item_value is Dictionary and _matches_pool(item_value, pool, site_ids):
					ids[String(item_value.get("id", ""))] = true
					eligible_ids[String(item_value.get("id", ""))] = pool_id
		candidate_ids_by_pool[pool_id] = ids
		if ids.is_empty():
			_fail("Eligibility pool %s has no candidates." % pool_id)
			return {}

	var excluded_ids := {}
	for item_value in authored.get("items", []):
		if not (item_value is Dictionary):
			continue
		var item: Dictionary = item_value
		var object_id := String(item.get("id", ""))
		var decisions := []
		if eligible_ids.has(object_id):
			decisions.append("eligible:%s" % String(eligible_ids[object_id]))
		for exclusion_value in registry.get("authored_exclusions", []):
			if exclusion_value is Dictionary and _matches_exclusion(item, exclusion_value, site_ids):
				decisions.append("excluded:%s" % String(exclusion_value.get("id", "")))
				excluded_ids[object_id] = String(exclusion_value.get("id", ""))
		if decisions.size() != 1:
			_fail("Authored object %s has %d eligibility decisions: %s" % [object_id, decisions.size(), JSON.stringify(decisions)])
			return {}
	if authored.get("items", []).size() != 422 or eligible_ids.size() != 336 or excluded_ids.size() != 86:
		_fail("Eligibility totals drifted: authored=%d eligible=%d excluded=%d" % [authored.get("items", []).size(), eligible_ids.size(), excluded_ids.size()])
		return {}
	for source_type in registry.get("source_type_pools", {}).keys():
		var pool_id := String(registry.get("source_type_pools", {})[source_type])
		if not candidate_ids_by_pool.has(pool_id) or candidate_ids_by_pool[pool_id].is_empty():
			_fail("Source type %s resolves to empty or unknown pool %s." % [source_type, pool_id])
			return {}
	return {
		"candidate_ids_by_pool": candidate_ids_by_pool,
		"public_summary": {
			"authored_object_count": 422,
			"eligible_object_count": 336,
			"excluded_object_count": 86,
			"artifact_candidate_count": artifact_ids.size(),
			"source_type_pool_count": registry.get("source_type_pools", {}).size(),
			"pool_candidate_counts": _set_sizes(candidate_ids_by_pool),
		},
	}

func _run_case(service: Variant, case_record: Dictionary, candidate_ids_by_pool: Dictionary) -> Dictionary:
	var config := ScenarioSelectRulesScript.build_random_map_player_config(
		String(case_record.get("seed", "")), String(case_record.get("template", "")),
		String(case_record.get("profile", "")), int(case_record.get("players", 4)),
		"land", false, String(case_record.get("size", "homm3_small")))
	var first: Dictionary = service.generate_random_map(config)
	var case_id := String(case_record.get("id", "case"))
	if not bool(first.get("ok", false)) or String(first.get("status", "")) != "complete":
		_fail("%s generation failed: %s" % [case_id, JSON.stringify(first)])
		return {}
	if not bool(first.get("map_validation", {}).get("ok", false)) or not bool(first.get("scenario_validation", {}).get("ok", false)):
		_fail("%s document validation failed." % case_id)
		return {}
	var adoption: Dictionary = service.convert_generated_payload(first, {"feature_gate": REPORT_ID})
	if not bool(adoption.get("ok", false)):
		_fail("%s package/session conversion failed: %s" % [case_id, JSON.stringify(adoption)])
		return {}
	var first_rows := _object_rows(first.get("map_document", null), candidate_ids_by_pool, case_id)
	if first_rows.is_empty():
		return {}
	return {
		"id": case_id,
		"size_class_id": case_record.get("size", ""),
		"payload_hash": first.get("final_payload_fnv1a32", ""),
		"payload_byte_count": first.get("final_payload_byte_count", 0),
		"runtime_object_count": first.get("runtime_object_count", 0),
		"package_object_count": int(adoption.get("map_document", null).get_object_count()),
		"mapped_object_count": first_rows.get("mapped_object_count", 0),
		"unclassified_visitable_count": first_rows.get("unclassified_visitable_count", 0),
		"selected_candidate_ids": first_rows.get("selected_candidate_ids", []),
		"resolution_counts": first_rows.get("resolution_counts", {}),
		"deterministic_selection_formula_verified": true,
	}

func _object_rows(map_document: Variant, candidate_ids_by_pool: Dictionary, case_id: String) -> Dictionary:
	if map_document == null:
		_fail("%s has no map document." % case_id)
		return {}
	var signature := []
	var selected_ids := {}
	var resolution_counts := {}
	var mapped_count := 0
	var unclassified_visitable_count := 0
	for index in range(int(map_document.get_object_count())):
		var object: Dictionary = map_document.get_object_by_index(index)
		var status := String(object.get("native_authored_pool_resolution_status", ""))
		resolution_counts[status] = int(resolution_counts.get(status, 0)) + 1
		var visit_tiles: Array = object.get("package_visit_tiles", []) if object.get("package_visit_tiles", []) is Array else []
		if not visit_tiles.is_empty() and status not in ["mapped", "native_runtime_passthrough"]:
			unclassified_visitable_count += 1
		if status != "mapped":
			continue
		mapped_count += 1
		var pool_id := String(object.get("native_authored_pool_id", ""))
		var candidate_id := String(object.get("native_authored_pool_candidate_id", ""))
		var selection_mode := String(object.get("native_authored_pool_selection_mode", ""))
		if not candidate_ids_by_pool.has(pool_id):
			_fail("%s selected unknown pool %s." % [case_id, pool_id])
			return {}
		if selection_mode == "stable_source_ordinal_pool_index" and not candidate_ids_by_pool[pool_id].has(candidate_id):
			_fail("%s selected candidate %s outside pool %s." % [case_id, candidate_id, pool_id])
			return {}
		var source_index := String(object.get("placement_id", "")).get_slice("_object_", 1).to_int()
		var source_token := "%s:%d:%d:%d:%s" % [map_document.get_map_id(), source_index, int(object.get("h3m_type_id", -1)), int(object.get("h3m_subtype", -1)), pool_id]
		var expected_selection_token := _hash32_hex(source_token)
		var sorted_candidates: Array = candidate_ids_by_pool[pool_id].keys()
		sorted_candidates.sort()
		var expected_candidate_id := String(sorted_candidates[_hash32_int(expected_selection_token) % sorted_candidates.size()])
		if String(object.get("object_id", "")) != candidate_id \
				or selection_mode not in ["existing_exact_catalog_identity", "stable_source_ordinal_pool_index"] \
				or (selection_mode == "stable_source_ordinal_pool_index" and candidate_id != expected_candidate_id) \
				or (selection_mode == "stable_source_ordinal_pool_index" and String(object.get("native_authored_pool_selection_token", "")) != expected_selection_token) \
				or (selection_mode == "existing_exact_catalog_identity" and not String(object.get("native_authored_pool_selection_token", "")).begins_with("exact_catalog:")) \
				or (selection_mode == "existing_exact_catalog_identity" and String(object.get("homm3_re_reward_object_catalog_path", "")) == "") \
				or String(object.get("native_authored_pool_registry_schema", "")) != "aurelion_random_map_object_eligibility_v1" \
				or not bool(object.get("native_authored_pool_source_placement_unchanged", false)) \
				or not bool(object.get("native_authored_pool_final_payload_unchanged", false)):
			_fail("%s mapped object lost identity or generation-boundary provenance: %s" % [case_id, JSON.stringify(object)])
			return {}
		selected_ids[candidate_id] = true
		signature.append([object.get("placement_id", ""), pool_id, candidate_id, object.get("native_authored_pool_selection_token", "")])
	if unclassified_visitable_count != 0 or mapped_count <= 0:
		_fail("%s has mapped=%d unclassified_visitable=%d." % [case_id, mapped_count, unclassified_visitable_count])
		return {}
	return {
		"mapped_object_count": mapped_count,
		"unclassified_visitable_count": unclassified_visitable_count,
		"selected_candidate_ids": selected_ids.keys(),
		"selection_signature": signature,
		"resolution_counts": resolution_counts,
	}

func _matches_pool(item: Dictionary, pool: Dictionary, site_ids: Dictionary) -> bool:
	var explicit: bool = String(item.get("id", "")) in pool.get("explicit_object_ids", [])
	if pool.has("primary_classes") and String(item.get("primary_class", "")) not in pool.get("primary_classes", []) and not explicit:
		return false
	if pool.has("families") and String(item.get("family", "")) not in pool.get("families", []):
		return false
	if String(item.get("runtime_boundary", {}).get("status", "")) in pool.get("exclude_runtime_statuses", []):
		return false
	return not bool(pool.get("require_resource_site", false)) or site_ids.has(String(item.get("resource_site_id", "")))

func _matches_exclusion(item: Dictionary, exclusion: Dictionary, site_ids: Dictionary) -> bool:
	if exclusion.has("primary_classes") and String(item.get("primary_class", "")) not in exclusion.get("primary_classes", []):
		return false
	if exclusion.has("families") and String(item.get("family", "")) not in exclusion.get("families", []):
		return false
	if exclusion.has("runtime_statuses") and String(item.get("runtime_boundary", {}).get("status", "")) not in exclusion.get("runtime_statuses", []):
		return false
	if bool(exclusion.get("require_missing_resource_site", false)) and site_ids.has(String(item.get("resource_site_id", ""))):
		return false
	return true

func _id_set(items: Variant) -> Dictionary:
	var result := {}
	for item in items if items is Array else []:
		if item is Dictionary and String(item.get("id", "")) != "":
			result[String(item.get("id", ""))] = true
	return result

func _set_sizes(sets: Dictionary) -> Dictionary:
	var result := {}
	for key in sets.keys():
		result[String(key)] = sets[key].size()
	return result

func _merge_counts(target: Dictionary, source: Dictionary) -> void:
	for key in source.keys():
		target[key] = int(target.get(key, 0)) + int(source[key])

func _hash32_int(text: String) -> int:
	var value: int = 2166136261
	for index in range(text.length()):
		value = (value ^ text.unicode_at(index)) & 0xFFFFFFFF
		value = (value * 16777619) & 0xFFFFFFFF
	return value

func _hash32_hex(text: String) -> String:
	return "%08x" % _hash32_int(text)

func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var value: Variant = JSON.parse_string(file.get_as_text())
	return value if value is Dictionary else {}

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
