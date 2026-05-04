extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")

const REPORT_ID := "NATIVE_RANDOM_MAP_HOMM3_RE_OBJECT_TABLE_PROXY_REPORT"
const REPORT_SCHEMA_ID := "native_random_map_homm3_re_object_table_proxy_report_v1"
const HOMM3_RE_REWARD_OBJECT_PROXY_CATALOG := "res://content/homm3_re_reward_object_proxy_catalog.json"

const CASES := [
	{
		"id": "small_frontier_proxy_seed_a",
		"seed": "native-object-proxy-small-a",
		"template_id": "frontier_spokes_v1",
		"profile_id": "frontier_spokes_profile_v1",
		"size_class_id": "homm3_small",
		"player_count": 3,
		"min_reward_catalog_ids": 3,
		"min_proxy_objects": 3,
	},
	{
		"id": "large_translated_042_proxy_seed_a",
		"seed": "native-object-proxy-large-a",
		"template_id": "translated_rmg_template_042_v1",
		"profile_id": "translated_rmg_profile_042_v1",
		"size_class_id": "homm3_large",
		"player_count": 4,
		"min_reward_catalog_ids": 8,
		"min_proxy_objects": 8,
		"expect_relic": true,
	},
	{
		"id": "xl_translated_043_proxy_seed_b",
		"seed": "native-object-proxy-xl-b",
		"template_id": "translated_rmg_template_043_v1",
		"profile_id": "translated_rmg_profile_043_v1",
		"size_class_id": "homm3_extra_large",
		"player_count": 8,
		"min_reward_catalog_ids": 8,
		"min_proxy_objects": 8,
		"expect_relic": true,
	},
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

	var catalog := _load_json(HOMM3_RE_REWARD_OBJECT_PROXY_CATALOG)
	var catalog_summary := _validate_catalog(catalog)
	if catalog_summary.is_empty():
		return

	var summaries := []
	var aggregate_reward_catalog_ids := {}
	var aggregate_reward_buckets := {}
	var aggregate_proxy_objects := {}
	var aggregate_tiers := {}
	for case_record in CASES:
		var summary := _run_case(service, case_record)
		if summary.is_empty():
			return
		summaries.append(summary)
		_merge_counts(aggregate_reward_catalog_ids, summary.get("reward_catalog_id_counts", {}))
		_merge_counts(aggregate_reward_buckets, summary.get("reward_table_bucket_counts", {}))
		_merge_counts(aggregate_proxy_objects, summary.get("native_proxy_object_counts", {}))
		_merge_counts(aggregate_tiers, summary.get("reward_value_tier_counts", {}))

	for required_tier in ["minor", "medium", "major", "relic"]:
		if not aggregate_tiers.has(required_tier):
			_fail("Broad sample missed expected reward value tier %s: %s" % [required_tier, JSON.stringify(aggregate_tiers)])
			return
	if aggregate_reward_catalog_ids.size() < 10:
		_fail("Broad sample reward object source diversity stayed low: %s" % JSON.stringify(aggregate_reward_catalog_ids))
		return
	if aggregate_proxy_objects.size() < 10:
		_fail("Broad sample native proxy object diversity stayed low: %s" % JSON.stringify(aggregate_proxy_objects))
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"schema_id": REPORT_SCHEMA_ID,
		"ok": true,
		"binding_kind": metadata.get("binding_kind", ""),
		"native_extension_loaded": metadata.get("native_extension_loaded", false),
		"source_catalog": catalog_summary,
		"case_count": summaries.size(),
		"cases": summaries,
		"broad_sample": {
			"unique_reward_catalog_id_count": aggregate_reward_catalog_ids.size(),
			"unique_reward_table_bucket_count": aggregate_reward_buckets.size(),
			"unique_native_proxy_object_count": aggregate_proxy_objects.size(),
			"reward_value_tiers": aggregate_tiers.keys(),
			"top_reward_catalog_ids": _top_counts(aggregate_reward_catalog_ids, 12),
			"top_reward_table_buckets": _top_counts(aggregate_reward_buckets, 12),
			"top_native_proxy_objects": _top_counts(aggregate_proxy_objects, 12),
		},
		"remaining_gap": "This is HoMM3-re object/reward table source identity mapped to original proxy content. It does not import HoMM3 art/DEF assets and does not claim exact HoMM3-re object-table, placement, byte, or full RMG parity.",
	})])
	get_tree().quit(0)

func _run_case(service: Variant, case_record: Dictionary) -> Dictionary:
	var config := ScenarioSelectRulesScript.build_random_map_player_config(
		String(case_record.get("seed", "")),
		String(case_record.get("template_id", "")),
		String(case_record.get("profile_id", "")),
		int(case_record.get("player_count", 4)),
		"land",
		false,
		String(case_record.get("size_class_id", "homm3_small"))
	)
	var generated: Dictionary = service.generate_random_map(config)
	var case_id := String(case_record.get("id", "case"))
	if not bool(generated.get("ok", false)):
		_fail("%s native generation failed: %s" % [case_id, JSON.stringify(generated)])
		return {}
	if String(generated.get("validation_status", "")) != "pass":
		_fail("%s native validation failed: %s" % [case_id, JSON.stringify(generated.get("validation_report", {}))])
		return {}

	var normalized: Dictionary = generated.get("normalized_config", {}) if generated.get("normalized_config", {}) is Dictionary else {}
	var zones: Array = generated.get("zone_layout", {}).get("zones", []) if generated.get("zone_layout", {}) is Dictionary else []
	var objects: Array = generated.get("object_placements", []) if generated.get("object_placements", []) is Array else []
	var guards: Array = generated.get("guard_records", []) if generated.get("guard_records", []) is Array else []
	var towns: Array = generated.get("town_records", []) if generated.get("town_records", []) is Array else []
	var road_cells := int(generated.get("road_network", {}).get("road_cell_count", 0))
	var fill_summary: Dictionary = generated.get("object_placement", {}).get("fill_coverage_summary", {}) if generated.get("object_placement", {}) is Dictionary else {}

	if road_cells <= 0:
		_fail("%s lost road cells." % case_id)
		return {}
	if objects.size() < max(32, zones.size() * 5):
		_fail("%s object density regressed: objects=%d zones=%d." % [case_id, objects.size(), zones.size()])
		return {}
	if float(fill_summary.get("decoration_blocker_body_coverage_ratio", 0.0)) < 0.12:
		_fail("%s decoration fill coverage regressed: %s" % [case_id, JSON.stringify(fill_summary)])
		return {}

	var proxy_summary := _proxy_summary(case_id, objects, guards, bool(case_record.get("expect_relic", false)))
	if proxy_summary.is_empty():
		return {}
	if int(proxy_summary.get("unique_reward_catalog_id_count", 0)) < int(case_record.get("min_reward_catalog_ids", 1)):
		_fail("%s reward object table source diversity stayed low: %s" % [case_id, JSON.stringify(proxy_summary)])
		return {}
	if int(proxy_summary.get("unique_native_proxy_object_count", 0)) < int(case_record.get("min_proxy_objects", 1)):
		_fail("%s native proxy object diversity stayed low: %s" % [case_id, JSON.stringify(proxy_summary)])
		return {}

	var adoption: Dictionary = service.convert_generated_payload(generated, {
		"feature_gate": "native_rmg_homm3_re_object_table_proxy_report",
		"session_save_version": 9,
		"scenario_id": "native_object_table_proxy_%s" % case_id,
	})
	if not bool(adoption.get("ok", false)):
		_fail("%s convert_generated_payload failed: %s" % [case_id, JSON.stringify(adoption)])
		return {}
	var map_document: Variant = adoption.get("map_document", null)
	if map_document == null or int(map_document.get_object_count()) < objects.size() + towns.size() + guards.size():
		_fail("%s package surface dropped generated records." % case_id)
		return {}

	return {
		"id": case_id,
		"template_id": String(case_record.get("template_id", "")),
		"size": "%dx%d" % [int(normalized.get("width", 0)), int(normalized.get("height", 0))],
		"zone_count": zones.size(),
		"object_count": objects.size(),
		"town_count": towns.size(),
		"guard_count": guards.size(),
		"road_cell_count": road_cells,
		"fill_coverage": fill_summary,
		"proxy_summary": proxy_summary,
		"reward_catalog_id_counts": proxy_summary.get("reward_catalog_id_counts", {}),
		"reward_table_bucket_counts": proxy_summary.get("reward_table_bucket_counts", {}),
		"native_proxy_object_counts": proxy_summary.get("native_proxy_object_counts", {}),
		"reward_value_tier_counts": proxy_summary.get("reward_value_tier_counts", {}),
		"package_object_count": int(map_document.get_object_count()),
	}

func _proxy_summary(case_id: String, objects: Array, guards: Array, expect_relic: bool) -> Dictionary:
	var source_kinds := {}
	var reward_catalog_ids := {}
	var reward_table_buckets := {}
	var native_proxy_objects := {}
	var native_proxy_families := {}
	var reward_tiers := {}
	var reward_categories := {}
	var value_by_tier := {}
	var reward_count := 0
	var mapped_value_banded_count := 0
	var mapped_value_guarded_count := 0
	var guarded_by_id := {}
	for guard in guards:
		if guard is Dictionary and String(guard.get("protected_target_type", "")) == "object_placement":
			guarded_by_id[String(guard.get("protected_object_placement_id", ""))] = guard
	for object in objects:
		if not (object is Dictionary):
			continue
		var kind := String(object.get("kind", ""))
		if ["resource_site", "mine", "neutral_dwelling", "reward_reference"].has(kind):
			_validate_common_proxy_fields(case_id, object)
		if kind != "reward_reference":
			continue
		reward_count += 1
		var source_kind := String(object.get("homm3_re_reward_object_source_kind", ""))
		var catalog_id := String(object.get("homm3_re_reward_object_catalog_id", ""))
		var bucket := String(object.get("homm3_re_reward_table_bucket", ""))
		var native_proxy_object := String(object.get("native_proxy_object_id", ""))
		var native_proxy_family := String(object.get("native_proxy_family", ""))
		var tier := String(object.get("reward_value_tier", ""))
		var category := String(object.get("reward_category", object.get("category_id", "")))
		var value := int(object.get("reward_value", 0))
		if source_kind == "" or catalog_id == "" or bucket == "" or native_proxy_object == "" or native_proxy_family == "":
			_fail("%s reward_reference missed HoMM3-re object table/proxy provenance: %s" % [case_id, JSON.stringify(object)])
			return {}
		if String(object.get("homm3_re_art_asset_policy", "")) != "provenance_only_original_proxy_art":
			_fail("%s reward_reference missed legal asset policy: %s" % [case_id, JSON.stringify(object)])
			return {}
		if value <= 0 or String(object.get("homm3_re_value_source_model", "")) == "":
			_fail("%s reward_reference missed value band provenance: %s" % [case_id, JSON.stringify(object)])
			return {}
		if value < int(object.get("homm3_re_reward_band_low", 0)) or value > int(object.get("homm3_re_reward_band_high", 0)):
			_fail("%s reward value escaped source band: %s" % [case_id, JSON.stringify(object)])
			return {}
		if value >= 6000 and not guarded_by_id.has(String(object.get("placement_id", ""))):
			_fail("%s high/relic proxy reward was not guarded: %s" % [case_id, JSON.stringify(object)])
			return {}
		if guarded_by_id.has(String(object.get("placement_id", ""))):
			var guard: Dictionary = guarded_by_id[String(object.get("placement_id", ""))]
			var ratio := float(guard.get("guard_reward_value_ratio", 0.0))
			if value >= 2500 and (ratio < 0.30 or ratio > 1.25):
				_fail("%s guard/reward ratio regressed for proxy reward: %s" % [case_id, JSON.stringify(guard)])
				return {}
			mapped_value_guarded_count += 1
		source_kinds[source_kind] = int(source_kinds.get(source_kind, 0)) + 1
		reward_catalog_ids[catalog_id] = int(reward_catalog_ids.get(catalog_id, 0)) + 1
		reward_table_buckets[bucket] = int(reward_table_buckets.get(bucket, 0)) + 1
		native_proxy_objects[native_proxy_object] = int(native_proxy_objects.get(native_proxy_object, 0)) + 1
		native_proxy_families[native_proxy_family] = int(native_proxy_families.get(native_proxy_family, 0)) + 1
		reward_tiers[tier] = int(reward_tiers.get(tier, 0)) + 1
		reward_categories[category] = int(reward_categories.get(category, 0)) + 1
		value_by_tier[tier] = max(int(value_by_tier.get(tier, 0)), value)
		mapped_value_banded_count += 1
	if reward_count <= 0:
		_fail("%s generated no reward references." % case_id)
		return {}
	if expect_relic and not reward_tiers.has("relic"):
		_fail("%s expected a relic-tier proxy reward in a large sample: %s" % [case_id, JSON.stringify(reward_tiers)])
		return {}
	if reward_categories.size() < 3 and objects.size() > 120:
		_fail("%s reward proxy categories stayed too narrow: %s" % [case_id, JSON.stringify(reward_categories)])
		return {}
	return {
		"reward_count": reward_count,
		"mapped_value_banded_count": mapped_value_banded_count,
		"mapped_value_guarded_count": mapped_value_guarded_count,
		"unique_reward_catalog_id_count": reward_catalog_ids.size(),
		"unique_reward_table_bucket_count": reward_table_buckets.size(),
		"unique_native_proxy_object_count": native_proxy_objects.size(),
		"unique_native_proxy_family_count": native_proxy_families.size(),
		"source_kind_counts": source_kinds,
		"reward_catalog_id_counts": reward_catalog_ids,
		"reward_table_bucket_counts": reward_table_buckets,
		"native_proxy_object_counts": native_proxy_objects,
		"native_proxy_family_counts": native_proxy_families,
		"reward_value_tier_counts": reward_tiers,
		"reward_category_counts": reward_categories,
		"max_value_by_tier": value_by_tier,
	}

func _validate_common_proxy_fields(case_id: String, object: Dictionary) -> void:
	if String(object.get("homm3_re_reward_object_source_kind", "")) == "":
		_fail("%s value object missed HoMM3-re source kind: %s" % [case_id, JSON.stringify(object)])
		return
	if int(object.get("homm3_re_object_type_id", 0)) <= 0 or String(object.get("homm3_re_object_type_name", "")) == "":
		_fail("%s value object missed HoMM3-re type identity: %s" % [case_id, JSON.stringify(object)])
		return
	if String(object.get("native_proxy_object_id", "")) == "" or String(object.get("native_proxy_family", "")) == "":
		_fail("%s value object missed native proxy identity: %s" % [case_id, JSON.stringify(object)])
		return
	if String(object.get("homm3_re_art_asset_policy", "")) != "provenance_only_original_proxy_art":
		_fail("%s value object missed provenance-only asset policy: %s" % [case_id, JSON.stringify(object)])
		return

func _validate_catalog(catalog: Dictionary) -> Dictionary:
	if String(catalog.get("schema_id", "")) != "homm3_re_reward_object_proxy_catalog_v1":
		_fail("Unexpected reward object proxy catalog schema: %s" % String(catalog.get("schema_id", "")))
		return {}
	if String(catalog.get("asset_policy", "")) != "provenance_only_original_proxy_art":
		_fail("Reward object proxy catalog missed legal asset boundary: %s" % JSON.stringify(catalog.get("asset_policy", "")))
		return {}
	var entries: Array = catalog.get("entries", []) if catalog.get("entries", []) is Array else []
	var generated_kinds := {}
	var type_ids := {}
	var proxy_buckets := {}
	for entry in entries:
		if not (entry is Dictionary):
			continue
		generated_kinds[String(entry.get("generated_kind", ""))] = true
		type_ids[str(entry.get("homm3_re_object_type_id", ""))] = true
		proxy_buckets[String(entry.get("proxy_bucket", ""))] = true
		if String(entry.get("homm3_re_object_def_ref", "")) == "":
			_fail("Proxy catalog entry missed DEF provenance name: %s" % JSON.stringify(entry))
			return {}
	for required_kind in ["reward_reference", "resource_site", "mine", "neutral_dwelling"]:
		if not generated_kinds.has(required_kind):
			_fail("Proxy catalog missed generated kind %s." % required_kind)
			return {}
	for required_bucket in ["minor_resource", "medium_guarded_cache", "major_artifact", "relic_artifact", "resource_mine", "neutral_dwelling"]:
		if not proxy_buckets.has(required_bucket):
			_fail("Proxy catalog missed proxy bucket %s: %s" % [required_bucket, JSON.stringify(proxy_buckets)])
			return {}
	return {
		"entry_count": entries.size(),
		"generated_kinds": generated_kinds.keys(),
		"unique_homm3_re_type_id_count": type_ids.size(),
		"proxy_buckets": proxy_buckets.keys(),
		"asset_policy": catalog.get("asset_policy", ""),
	}

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}

func _merge_counts(target: Dictionary, source: Dictionary) -> void:
	for key in source.keys():
		target[key] = int(target.get(key, 0)) + int(source.get(key, 0))

func _top_counts(counts: Dictionary, limit: int) -> Array:
	var rows := []
	for key in counts.keys():
		rows.append({"key": String(key), "count": int(counts[key])})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("count", 0)) == int(b.get("count", 0)):
			return String(a.get("key", "")) < String(b.get("key", ""))
		return int(a.get("count", 0)) > int(b.get("count", 0))
	)
	return rows.slice(0, limit)

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
