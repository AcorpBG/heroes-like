extends Node

const RandomMapGeneratorRulesScript = preload("res://scripts/core/RandomMapGeneratorRules.gd")
const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const REPORT_ID := "RANDOM_MAP_HOMM3_SIZE_DEFAULT_MENU_WIRING_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var catalog: Dictionary = ContentService.load_json(RandomMapGeneratorRulesScript.TEMPLATE_CATALOG_PATH)
	var catalog_templates: Array = catalog.get("templates", []) if catalog.get("templates", []) is Array else []
	var catalog_profiles: Array = catalog.get("profiles", []) if catalog.get("profiles", []) is Array else []
	if catalog_templates.size() != 56 or catalog_profiles.size() != 56:
		_fail("Catalog did not expose expected 56 templates/profiles: %d/%d" % [catalog_templates.size(), catalog_profiles.size()])
		return

	var setup_options := ScenarioSelectRulesScript.random_map_player_setup_options()
	var exposed_templates: Array = setup_options.get("templates", []) if setup_options.get("templates", []) is Array else []
	var exposed_profiles: Array = setup_options.get("profiles", []) if setup_options.get("profiles", []) is Array else []
	var catalog_template_ids := _ids(catalog_templates)
	var exposed_template_ids := _ids(exposed_templates)
	var catalog_profile_ids := _ids(catalog_profiles)
	var exposed_profile_ids := _ids(exposed_profiles)
	if catalog_template_ids != exposed_template_ids:
		_fail("Rules setup template ids did not match catalog ids: missing=%s extra=%s" % [JSON.stringify(_difference(catalog_template_ids, exposed_template_ids)), JSON.stringify(_difference(exposed_template_ids, catalog_template_ids))])
		return
	if catalog_profile_ids != exposed_profile_ids:
		_fail("Rules setup profile ids did not match catalog ids.")
		return
	var size_defaults: Dictionary = setup_options.get("size_class_defaults", {}) if setup_options.get("size_class_defaults", {}) is Dictionary else {}
	for size_class_id in ["homm3_small", "homm3_medium", "homm3_large", "homm3_extra_large"]:
		if not (size_defaults.get(size_class_id, {}) is Dictionary):
			_fail("Rules setup missed internal size default for %s." % size_class_id)
			return

	var shell = load("res://scenes/menus/MainMenu.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	shell.call("validation_open_skirmish_stage")
	var snapshot: Dictionary = shell.call("validation_generated_random_map_snapshot")
	var controls: Dictionary = snapshot.get("controls", {}) if snapshot.get("controls", {}) is Dictionary else {}
	for forbidden_key in ["template_options", "template_option_ids", "profile_options", "profile_option_ids"]:
		if controls.has(forbidden_key):
			_fail("Main menu generated player controls still exposed manual %s: %s" % [forbidden_key, JSON.stringify(controls)])
			return
	var internal_provenance: Dictionary = controls.get("internal_template_provenance", {}) if controls.get("internal_template_provenance", {}) is Dictionary else {}
	if bool(internal_provenance.get("template_picker_visible", true)) or bool(internal_provenance.get("profile_picker_visible", true)):
		_fail("Manual template/profile pickers remained visible: %s" % JSON.stringify(internal_provenance))
		return

	var built_count := 0
	var profile_coherence_failures := []
	for template in catalog_templates:
		if not (template is Dictionary):
			continue
		var template_id := String(template.get("id", ""))
		var profile_ids := []
		for profile in catalog_profiles:
			if profile is Dictionary and String(profile.get("template_id", "")) == template_id:
				profile_ids.append(String(profile.get("id", "")))
		if profile_ids.is_empty():
			profile_coherence_failures.append("%s has no profile options" % template_id)
			continue
		for profile_id in profile_ids:
			var profile := _profile_by_id(catalog_profiles, String(profile_id))
			if String(profile.get("template_id", "")) != template_id:
				profile_coherence_failures.append("%s exposed mismatched profile %s" % [template_id, String(profile_id)])
		var size_class_id := _size_class_for_template(template)
		var player_counts := ScenarioSelectRulesScript.random_map_player_count_options_for_template(template_id)
		if player_counts.is_empty():
			_fail("Template %s did not expose player counts." % template_id)
			return
		var config := ScenarioSelectRulesScript.build_random_map_player_config(
			"all-template-menu-wiring-%s" % template_id,
			template_id,
			String(profile_ids[0]),
			int(player_counts[0]),
			"land",
			false,
			size_class_id
		)
		if String(config.get("profile", {}).get("template_id", "")) != template_id or String(config.get("profile", {}).get("id", "")) != String(profile_ids[0]):
			_fail("Build config did not preserve selected template/profile: %s" % JSON.stringify(config.get("profile", {})))
			return
		built_count += 1
	if not profile_coherence_failures.is_empty():
		_fail("Catalog profile coherence failed: %s" % JSON.stringify(profile_coherence_failures))
		return

	var size_default_failures := []
	for size_class_id in ["homm3_small", "homm3_medium", "homm3_large", "homm3_extra_large"]:
		if not bool(shell.call("validation_select_generated_size_class", size_class_id)):
			_fail("Main menu could not select generated size class %s." % size_class_id)
			return
		var size_snapshot: Dictionary = shell.call("validation_generated_random_map_snapshot")
		var size_controls: Dictionary = size_snapshot.get("controls", {}) if size_snapshot.get("controls", {}) is Dictionary else {}
		var provenance: Dictionary = size_controls.get("internal_template_provenance", {}) if size_controls.get("internal_template_provenance", {}) is Dictionary else {}
		var defaults := ScenarioSelectRulesScript.random_map_size_class_default(size_class_id)
		if String(provenance.get("template_id", "")) != String(defaults.get("template_id", "")) or String(provenance.get("profile_id", "")) != String(defaults.get("profile_id", "")):
			size_default_failures.append({
				"size_class_id": size_class_id,
				"provenance": provenance,
				"defaults": defaults,
			})
		var default_config := ScenarioSelectRulesScript.build_random_map_player_config(
			"size-default-menu-wiring-%s" % size_class_id,
			"",
			"",
			int(defaults.get("player_count", 3)),
			"land",
			false,
			size_class_id
		)
		if String(default_config.get("profile", {}).get("template_id", "")) != String(defaults.get("template_id", "")) or String(default_config.get("profile", {}).get("id", "")) != String(defaults.get("profile_id", "")):
			size_default_failures.append({
				"size_class_id": size_class_id,
				"default_config_profile": default_config.get("profile", {}),
				"defaults": defaults,
			})
	if not size_default_failures.is_empty():
		_fail("Size default template/profile derivation failed: %s" % JSON.stringify(size_default_failures))
		return

	var counts_by_template: Dictionary = setup_options.get("player_count_options_by_template", {}) if setup_options.get("player_count_options_by_template", {}) is Dictionary else {}
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"catalog_template_count": catalog_template_ids.size(),
		"catalog_profile_count": catalog_profile_ids.size(),
		"manual_template_player_controls_visible": bool(internal_provenance.get("template_picker_visible", true)),
		"manual_profile_player_controls_visible": bool(internal_provenance.get("profile_picker_visible", true)),
		"built_config_count": built_count,
		"default_template_id": setup_options.get("default_template_id", ""),
		"player_count_options_by_template_count": counts_by_template.size(),
	})])
	get_tree().quit(0)

func _ids(records: Array) -> Array:
	var ids := []
	for record in records:
		if record is Dictionary:
			ids.append(String(record.get("id", "")))
	ids.sort()
	return ids

func _difference(left: Array, right: Array) -> Array:
	var right_lookup := {}
	for value in right:
		right_lookup[String(value)] = true
	var result := []
	for value in left:
		if not right_lookup.has(String(value)):
			result.append(String(value))
	return result

func _profile_by_id(profiles: Array, profile_id: String) -> Dictionary:
	for profile in profiles:
		if profile is Dictionary and String(profile.get("id", "")) == profile_id:
			return profile
	return {}

func _size_class_for_template(template: Dictionary) -> String:
	var size_score: Dictionary = template.get("size_score", {}) if template.get("size_score", {}) is Dictionary else {}
	var min_score := int(size_score.get("min", 1))
	var max_score := int(size_score.get("max", 32))
	if min_score <= 1 and max_score >= 1:
		return "homm3_small"
	if min_score <= 4 and max_score >= 4:
		return "homm3_medium"
	if min_score <= 9 and max_score >= 9:
		return "homm3_large"
	return "homm3_extra_large"

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
