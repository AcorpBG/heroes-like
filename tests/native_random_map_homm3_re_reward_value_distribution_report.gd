extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")

const REPORT_ID := "NATIVE_RANDOM_MAP_HOMM3_RE_REWARD_VALUE_DISTRIBUTION_REPORT"
const REPORT_SCHEMA_ID := "native_random_map_homm3_re_reward_value_distribution_report_v1"

const CASES := [
	{
		"id": "small_frontier_spokes_seed_a",
		"seed": "native-reward-value-small-a",
		"template_id": "frontier_spokes_v1",
		"profile_id": "frontier_spokes_profile_v1",
		"size_class_id": "homm3_small",
		"player_count": 3,
	},
	{
		"id": "medium_translated_024_seed_a",
		"seed": "native-reward-value-medium-a",
		"template_id": "translated_rmg_template_024_v1",
		"profile_id": "translated_rmg_profile_024_v1",
		"size_class_id": "homm3_medium",
		"player_count": 4,
	},
	{
		"id": "large_translated_042_seed_a",
		"seed": "native-reward-value-large-a",
		"template_id": "translated_rmg_template_042_v1",
		"profile_id": "translated_rmg_profile_042_v1",
		"size_class_id": "homm3_large",
		"player_count": 4,
	},
	{
		"id": "xl_translated_043_seed_b",
		"seed": "native-reward-value-xl-b",
		"template_id": "translated_rmg_template_043_v1",
		"profile_id": "translated_rmg_profile_043_v1",
		"size_class_id": "homm3_extra_large",
		"player_count": 8,
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

	var summaries := []
	for case_record in CASES:
		var summary := _run_case(service, case_record)
		if summary.is_empty():
			return
		summaries.append(summary)

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"schema_id": REPORT_SCHEMA_ID,
		"ok": true,
		"binding_kind": metadata.get("binding_kind", ""),
		"native_extension_loaded": metadata.get("native_extension_loaded", false),
		"case_count": summaries.size(),
		"cases": summaries,
		"remaining_gap": "Native reward values now derive from catalog zone treasure bands and guard values scale from protected rewards for supported original content proxies. This is not exact HoMM3-re reward table, object art, or byte placement parity.",
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
	var width := int(normalized.get("width", 0))
	var height := int(normalized.get("height", 0))
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

	var zone_stats := _zone_value_stats(zones, objects, towns)
	var barren := _barren_playable_zones(zones, zone_stats)
	if not barren.is_empty():
		_fail("%s has playable land zones without meaningful value content: %s" % [case_id, JSON.stringify(barren)])
		return {}

	var reward_summary := _reward_summary(case_id, objects)
	if reward_summary.is_empty():
		return {}
	var guard_summary := _guard_reward_summary(case_id, objects, guards)
	if guard_summary.is_empty():
		return {}
	var scaling := _zone_scaling_summary(case_id, zone_stats)
	if scaling.is_empty():
		return {}

	var adoption: Dictionary = service.convert_generated_payload(generated, {
		"feature_gate": "native_rmg_reward_value_distribution_report",
		"session_save_version": 9,
		"scenario_id": "native_reward_value_%s" % case_id,
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
		"size": "%dx%d" % [width, height],
		"zone_count": zones.size(),
		"object_count": objects.size(),
		"town_count": towns.size(),
		"guard_count": guards.size(),
		"road_cell_count": road_cells,
		"fill_coverage": fill_summary,
		"reward_summary": reward_summary,
		"guard_reward_summary": guard_summary,
		"zone_scaling_summary": scaling,
		"package_object_count": int(map_document.get_object_count()),
	}

func _zone_value_stats(zones: Array, objects: Array, towns: Array) -> Dictionary:
	var stats := {}
	for zone in zones:
		if not (zone is Dictionary):
			continue
		var zone_id := String(zone.get("id", ""))
		stats[zone_id] = {
			"zone_id": zone_id,
			"role": String(zone.get("role", "")),
			"terrain_id": String(zone.get("terrain_id", "")),
			"cell_count": int(zone.get("cell_count", 0)),
			"value_object_count": 0,
			"reward_count": 0,
			"reward_value_sum": 0,
			"max_reward_value": 0,
			"zone_value_budget": 0,
			"town_count": 0,
		}
	for object in objects:
		if not (object is Dictionary):
			continue
		var zone_id := String(object.get("zone_id", ""))
		if not stats.has(zone_id):
			continue
		var stat: Dictionary = stats[zone_id]
		var kind := String(object.get("kind", ""))
		if ["resource_site", "mine", "neutral_dwelling", "reward_reference"].has(kind):
			stat["value_object_count"] = int(stat.get("value_object_count", 0)) + 1
			stat["zone_value_budget"] = max(int(stat.get("zone_value_budget", 0)), int(object.get("zone_value_budget", 0)))
		if kind == "reward_reference":
			var reward_value := int(object.get("reward_value", 0))
			stat["reward_count"] = int(stat.get("reward_count", 0)) + 1
			stat["reward_value_sum"] = int(stat.get("reward_value_sum", 0)) + reward_value
			stat["max_reward_value"] = max(int(stat.get("max_reward_value", 0)), reward_value)
	for town in towns:
		if town is Dictionary and stats.has(String(town.get("zone_id", ""))):
			var stat: Dictionary = stats[String(town.get("zone_id", ""))]
			stat["town_count"] = int(stat.get("town_count", 0)) + 1
			stat["value_object_count"] = int(stat.get("value_object_count", 0)) + 1
	return stats

func _barren_playable_zones(zones: Array, zone_stats: Dictionary) -> Array:
	var barren := []
	for zone in zones:
		if not (zone is Dictionary):
			continue
		var zone_id := String(zone.get("id", ""))
		var role := String(zone.get("role", ""))
		var terrain_id := String(zone.get("terrain_id", ""))
		if role == "junction" or terrain_id == "water" or int(zone.get("cell_count", 0)) <= 0:
			continue
		var stat: Dictionary = zone_stats.get(zone_id, {})
		if int(stat.get("value_object_count", 0)) <= 0:
			barren.append({"zone_id": zone_id, "role": role, "terrain_id": terrain_id})
	return barren

func _reward_summary(case_id: String, objects: Array) -> Dictionary:
	var reward_count := 0
	var categories := {}
	var tiers := {}
	var banded_count := 0
	var values := []
	for object in objects:
		if not (object is Dictionary) or String(object.get("kind", "")) != "reward_reference":
			continue
		reward_count += 1
		var value := int(object.get("reward_value", 0))
		if value <= 0 or String(object.get("homm3_re_value_source_model", "")) == "":
			_fail("%s reward object missed value-band provenance: %s" % [case_id, JSON.stringify(object)])
			return {}
		if value < int(object.get("homm3_re_reward_band_low", 0)) or value > int(object.get("homm3_re_reward_band_high", 0)):
			_fail("%s reward value escaped its source band: %s" % [case_id, JSON.stringify(object)])
			return {}
		categories[String(object.get("reward_category", object.get("category_id", "")))] = true
		tiers[String(object.get("reward_value_tier", ""))] = true
		banded_count += 1
		values.append(value)
	if reward_count <= 0:
		_fail("%s generated no rewards." % case_id)
		return {}
	if categories.size() < 2:
		_fail("%s reward category mix is too narrow: %s" % [case_id, JSON.stringify(categories.keys())])
		return {}
	values.sort()
	return {
		"reward_count": reward_count,
		"banded_reward_count": banded_count,
		"reward_category_count": categories.size(),
		"reward_categories": categories.keys(),
		"reward_value_tiers": tiers.keys(),
		"min_reward_value": int(values.front()),
		"max_reward_value": int(values.back()),
	}

func _guard_reward_summary(case_id: String, objects: Array, guards: Array) -> Dictionary:
	var guarded_by_id := {}
	var guarded_values := []
	var unguarded_high_value := []
	var medium_value_count := 0
	var medium_guarded_count := 0
	var high_value_count := 0
	for guard in guards:
		if guard is Dictionary and String(guard.get("protected_target_type", "")) == "object_placement":
			guarded_by_id[String(guard.get("protected_object_placement_id", ""))] = guard
	for object in objects:
		if not (object is Dictionary) or String(object.get("kind", "")) != "reward_reference":
			continue
		var value := int(object.get("reward_value", 0))
		if value < 2500:
			continue
		var placement_id := String(object.get("placement_id", ""))
		if not guarded_by_id.has(placement_id):
			if value >= 6000:
				high_value_count += 1
				unguarded_high_value.append({"placement_id": placement_id, "value": value, "tier": object.get("reward_value_tier", "")})
			else:
				medium_value_count += 1
			continue
		var guard: Dictionary = guarded_by_id[placement_id]
		var ratio := float(guard.get("guard_reward_value_ratio", 0.0))
		if ratio < 0.30 or ratio > 1.25:
			_fail("%s guard/reward ratio is outside the translated band: guard=%s reward=%s" % [case_id, JSON.stringify(guard), JSON.stringify(object)])
			return {}
		var max_distance := 20 if value >= 6000 else 12
		if int(guard.get("guard_distance", 99)) > max_distance or not bool(guard.get("near_guarded_object", false)):
			_fail("%s reward guard was not placed near protected object: %s" % [case_id, JSON.stringify(guard)])
			return {}
		if value >= 6000:
			high_value_count += 1
		else:
			medium_value_count += 1
			medium_guarded_count += 1
		guarded_values.append({"reward_value": value, "guard_value": int(guard.get("guard_value", 0)), "ratio": ratio})
	if not unguarded_high_value.is_empty():
		_fail("%s major/relic reward objects were left unguarded: %s" % [case_id, JSON.stringify(unguarded_high_value.slice(0, 8))])
		return {}
	if medium_value_count >= 4 and medium_guarded_count <= 0:
		_fail("%s medium reward objects had no near guards at all" % case_id)
		return {}
	return {
		"guarded_valuable_reward_count": guarded_values.size(),
		"high_value_reward_count": high_value_count,
		"medium_value_reward_count": medium_value_count,
		"medium_guarded_reward_count": medium_guarded_count,
		"sample_guarded_values": guarded_values.slice(0, 8),
	}

func _zone_scaling_summary(case_id: String, zone_stats: Dictionary) -> Dictionary:
	var comparable := []
	for zone_id in zone_stats.keys():
		var stat: Dictionary = zone_stats[zone_id]
		if int(stat.get("reward_count", 0)) <= 0 or int(stat.get("zone_value_budget", 0)) <= 0:
			continue
		comparable.append(stat)
	if comparable.size() < 2:
		return {"comparable_zone_count": comparable.size(), "status": "not_enough_distinct_reward_zones"}
	comparable.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("zone_value_budget", 0)) < int(b.get("zone_value_budget", 0))
	)
	var low: Dictionary = comparable.front()
	var high: Dictionary = comparable.back()
	if int(high.get("zone_value_budget", 0)) > int(low.get("zone_value_budget", 0)) and int(high.get("max_reward_value", 0)) < int(low.get("max_reward_value", 0)):
		_fail("%s reward values did not scale with zone budget: low=%s high=%s" % [case_id, JSON.stringify(low), JSON.stringify(high)])
		return {}
	return {
		"comparable_zone_count": comparable.size(),
		"lowest_budget_zone": {
			"zone_id": low.get("zone_id", ""),
			"budget": low.get("zone_value_budget", 0),
			"max_reward_value": low.get("max_reward_value", 0),
			"reward_count": low.get("reward_count", 0),
		},
		"highest_budget_zone": {
			"zone_id": high.get("zone_id", ""),
			"budget": high.get("zone_value_budget", 0),
			"max_reward_value": high.get("max_reward_value", 0),
			"reward_count": high.get("reward_count", 0),
		},
	}

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
