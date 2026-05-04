extends Node

const RandomMapGeneratorRulesScript = preload("res://scripts/core/RandomMapGeneratorRules.gd")
const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const REPORT_ID := "RANDOM_MAP_ALL_TEMPLATE_MENU_WIRING_REPORT"

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

	var shell = load("res://scenes/menus/MainMenu.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	shell.call("validation_open_skirmish_stage")
	var snapshot: Dictionary = shell.call("validation_generated_random_map_snapshot")
	var controls: Dictionary = snapshot.get("controls", {}) if snapshot.get("controls", {}) is Dictionary else {}
	var menu_template_ids: Array = controls.get("template_option_ids", []) if controls.get("template_option_ids", []) is Array else []
	menu_template_ids.sort()
	if menu_template_ids != catalog_template_ids:
		_fail("Main menu generated template picker did not expose all catalog template ids: count=%d expected=%d" % [menu_template_ids.size(), catalog_template_ids.size()])
		return

	var built_count := 0
	var profile_coherence_failures := []
	for template in catalog_templates:
		if not (template is Dictionary):
			continue
		var template_id := String(template.get("id", ""))
		if not bool(shell.call("validation_select_generated_template", template_id)):
			_fail("Main menu could not select exposed template %s." % template_id)
			return
		var template_snapshot: Dictionary = shell.call("validation_generated_random_map_snapshot")
		var template_controls: Dictionary = template_snapshot.get("controls", {}) if template_snapshot.get("controls", {}) is Dictionary else {}
		var profile_ids: Array = template_controls.get("profile_option_ids", []) if template_controls.get("profile_option_ids", []) is Array else []
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
		_fail("Profile picker coherence failed: %s" % JSON.stringify(profile_coherence_failures))
		return

	var counts_by_template: Dictionary = setup_options.get("player_count_options_by_template", {}) if setup_options.get("player_count_options_by_template", {}) is Dictionary else {}
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"catalog_template_count": catalog_template_ids.size(),
		"catalog_profile_count": catalog_profile_ids.size(),
		"menu_template_option_count": menu_template_ids.size(),
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
