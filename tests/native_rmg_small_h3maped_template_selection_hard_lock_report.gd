extends Node

const REPORT_ID := "NATIVE_RMG_SMALL_H3MAPED_TEMPLATE_SELECTION_HARD_LOCK_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ClassDB.class_exists("MapPackageService"):
		_fail("MapPackageService native class is not available.")
		return
	var service: Variant = ClassDB.instantiate("MapPackageService")
	var supported_config := _small_land_config("11", 3)
	var identity: Dictionary = service.random_map_config_identity(supported_config)
	var normalized: Dictionary = identity.get("normalized_config", {}) if identity.get("normalized_config", {}) is Dictionary else {}
	var selection: Dictionary = normalized.get("h3maped_template_selection", {}) if normalized.get("h3maped_template_selection", {}) is Dictionary else {}
	if not bool(identity.get("ok", false)) \
			or String(normalized.get("template_selection_mode", "")) != "h3maped_exe_rng" \
			or String(normalized.get("template_selection_authority", "")) != "h3maped_exe_rng_original_catalog" \
			or String(normalized.get("template_id", "")) != "h3maped_template_018" \
			or String(selection.get("source_template_id", "")) != "h3maped_template_018" \
			or int(selection.get("source_catalog_index", -1)) != 18 \
			or bool(normalized.get("translated_template_authority_used", true)) \
			or bool(normalized.get("archived_catalog_auto_used", true)):
		_fail("Supported Small-land identity did not lock to original h3maped template authority: %s" % JSON.stringify(identity))
		return

	var explicit_config := supported_config.duplicate(true)
	explicit_config["template_id"] = "translated_rmg_template_019_v1"
	var explicit_identity: Dictionary = service.random_map_config_identity(explicit_config)
	var explicit_normalized: Dictionary = explicit_identity.get("normalized_config", {}) if explicit_identity.get("normalized_config", {}) is Dictionary else {}
	if String(explicit_normalized.get("template_selection_mode", "")) != "h3maped_exe_rng" \
			or String(explicit_normalized.get("template_selection_authority", "")) != "h3maped_exe_rng_original_catalog" \
			or String(explicit_normalized.get("template_id", "")) != "h3maped_template_018" \
			or String(explicit_normalized.get("requested_template_id_before_h3maped_selection", "")) != "translated_rmg_template_019_v1" \
			or not bool(explicit_normalized.get("explicit_template_request_overridden_by_h3maped_reset", false)) \
			or bool(explicit_normalized.get("translated_template_authority_used", true)) \
			or bool(explicit_normalized.get("archived_catalog_auto_used", true)):
		_fail("Explicit translated-template request was not overridden by h3maped original authority: %s" % JSON.stringify(explicit_identity))
		return

	var generated: Dictionary = service.generate_random_map(explicit_config)
	var payload: Dictionary = generated.get("map_document_payload", {}) if generated.get("map_document_payload", {}) is Dictionary else {}
	var payload_metadata: Dictionary = payload.get("metadata", {}) if payload.get("metadata", {}) is Dictionary else {}
	if not bool(generated.get("ok", false)) \
			or String(generated.get("generation_status", generated.get("full_generation_status", ""))) != "h3maped_small_validated_package_ready" \
			or not _is_template_authority(String(generated.get("template_selection_authority", ""))) \
			or not _is_source_authority(String(generated.get("source_template_authority", ""))) \
			or String(generated.get("source_template_id", "")) != "h3maped_template_018" \
			or String(payload.get("source_template_id", "")) != "h3maped_template_018" \
			or not _is_template_authority(String(payload.get("template_selection_authority", ""))) \
			or not _is_template_authority(String(payload_metadata.get("template_selection_authority", ""))) \
			or bool(generated.get("translated_template_authority_used", true)) \
			or bool(generated.get("archived_catalog_auto_used", true)) \
			or bool(generated.get("template_selection_fallback_used", true)):
		_fail("Generated package did not preserve hard-locked h3maped template authority: %s" % JSON.stringify(generated))
		return

	var unsupported_cases := [
		{"case_id": "large_land", "config": _config_with_size(supported_config, 108, 108, 1, "land", "homm3_large")},
		{"case_id": "small_islands", "config": _config_with_size(supported_config, 36, 36, 1, "islands", "homm3_small")},
		{"case_id": "small_two_level", "config": _config_with_size(supported_config, 36, 36, 2, "land", "homm3_small")},
		{"case_id": "small_non_numeric_seed", "config": _small_land_config("jade", 3)},
	]
	for unsupported in unsupported_cases:
		var result: Dictionary = service.generate_random_map(unsupported.get("config", {}))
		if bool(result.get("ok", false)) \
				or bool(result.get("runtime_generation_allowed", true)) \
				or result.has("map_document_payload") \
				or bool(result.get("translated_template_authority_used", true)) \
				or bool(result.get("archived_catalog_auto_used", true)) \
				or bool(result.get("template_selection_fallback_used", true)) \
				or not String(result.get("generation_status", "")).contains("blocked") and String(result.get("generation_status", "")) != "archived_legacy_native_rmg_disabled":
			_fail("Unsupported config did not hard-block without fallback output for %s: %s" % [String(unsupported.get("case_id", "")), JSON.stringify(result)])
			return

	print("%s: ok" % REPORT_ID)
	get_tree().quit(0)

func _small_land_config(seed: String, player_count: int) -> Dictionary:
	return {
		"seed": seed,
		"size": {
			"width": 36,
			"height": 36,
			"level_count": 1,
			"water_mode": "land",
			"size_class_id": "homm3_small",
		},
		"player_constraints": {
			"human_count": 1,
			"player_count": player_count,
			"team_mode": "free_for_all",
		},
	}

func _config_with_size(base: Dictionary, width: int, height: int, level_count: int, water_mode: String, size_class_id: String) -> Dictionary:
	var config := base.duplicate(true)
	config["size"] = {
		"width": width,
		"height": height,
		"level_count": level_count,
		"water_mode": water_mode,
		"size_class_id": size_class_id,
	}
	return config

func _is_template_authority(value: String) -> bool:
	return value == "compiled_h3maped_original_catalog" or value == "h3maped_exe_rng_original_catalog"

func _is_source_authority(value: String) -> bool:
	return value == "compiled_h3maped_rng" or value == "h3maped_exe_rng"

func _fail(message: String) -> void:
	push_error("%s: %s" % [REPORT_ID, message])
	get_tree().quit(1)
