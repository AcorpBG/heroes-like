extends Node

const SessionDataScript = preload("res://scripts/core/SessionStateStore.gd")
const TownShellScene = preload("res://scenes/town/TownShell.tscn")

const REPORT_ID := "SIX_HORIZON_CAPSTONE_MONUMENTS_SMOKE"
const OUTPUT_DIR := "res://.artifacts/content_six_horizon_capstone_monuments"
const REPORT_PATH := OUTPUT_DIR + "/report.json"
const SCENARIO_ID := "horizon-compact-six-citadels"
const CASES := [
	{"faction_id":"faction_embercourt","town_id":"town_rainwrit_bastion","placement_id":"horizon_rainwrit_town","building_id":"building_embercourt_rainwrit_stormseal_treasury","unit_id":"unit_embercourt_cinderseal_bombardiers","rare_resource_id":"embergrain","cost":{"gold":3600,"wood":2,"ore":3},"requires":["building_embercourt_charter_bastion","building_embercourt_drake_sluice"],"income":{"gold":220,"embergrain":1},"growth":1,"discount":5,"readiness":4,"pressure":1,"recovery":0,"source_sha":"f9ed22a1f01c0f799ce5f0780145734285e449055317c0cceb9840fb92065aa0","icon_sha":"e23a4d6a344e9b36067bb9e06bd488799113cfe2820979f22191f918e5b30bff"},
	{"faction_id":"faction_mireclaw","town_id":"town_hollowreed_sanctuary","placement_id":"horizon_hollowreed_town","building_id":"building_mireclaw_hollowreed_moonwax_ossuary","unit_id":"unit_mireclaw_mireglass_reedcasters","rare_resource_id":"peatwax","cost":{"gold":3400,"wood":1,"ore":1},"requires":["building_mireclaw_boneboom_palisade","building_mireclaw_chainboom_ferry"],"income":{"peatwax":1},"growth":1,"discount":5,"readiness":3,"pressure":0,"recovery":1,"source_sha":"561eb353633c2eec4b3b4669cf65e87aa8c4c19c7d8669e7d2b2c8af0384adc6","icon_sha":"aaca6fa6dec529a725931bc9cc3cfc8fe36f7b13fca0b829a8f7abc485484387"},
	{"faction_id":"faction_sunvault","town_id":"town_meridian_choirhold","placement_id":"horizon_meridian_town","building_id":"building_sunvault_meridian_seven_facet_orrery","unit_id":"unit_sunvault_noonfacet_sentinels","rare_resource_id":"aetherglass","cost":{"gold":3700,"wood":1,"ore":3},"requires":["building_sunvault_zenith_relay_hall","building_sunvault_harmonic_cloister"],"income":{"gold":100,"aetherglass":1},"growth":1,"discount":5,"readiness":6,"pressure":0,"recovery":0,"source_sha":"0397c47818c71ee0ee4714de61b14bfb6a1467de6fd9644719571b4965062274","icon_sha":"977088d9bd572ac74456dd3edf83e89291dc2a22c661d7ea87b0e47a11d448ee"},
	{"faction_id":"faction_thornwake","town_id":"town_crownroot_refuge","placement_id":"horizon_crownroot_town","building_id":"building_thornwake_crownroot_heartseed_parliament","unit_id":"unit_thornwake_dawnseed_bolters","rare_resource_id":"verdant_grafts","cost":{"gold":2900,"wood":1,"ore":1},"requires":["building_thornwake_rootlaw_moot","building_thornwake_barkmantle_run"],"income":{"wood":1,"verdant_grafts":1},"growth":2,"discount":4,"readiness":0,"pressure":0,"recovery":1,"source_sha":"322c93b66027af8124e211d129c8ae4ae4b050fe353c3c9758f7e496a6dad734","icon_sha":"7ac048d60c26e948e5aee2f0e7d5550dfa032b35fa83e731c8fec03665843fea"},
	{"faction_id":"faction_brasshollow","town_id":"town_blackbell_foundry","placement_id":"horizon_blackbell_town","building_id":"building_brasshollow_blackbell_grand_assay_bell","unit_id":"unit_brasshollow_gaugeplate_bailiffs","rare_resource_id":"brass_scrip","cost":{"gold":3800,"wood":1,"ore":4},"requires":["building_brasshollow_redline_charter_bay","building_brasshollow_boiler_cathedral"],"income":{"ore":1,"brass_scrip":1},"growth":1,"discount":8,"readiness":6,"pressure":1,"recovery":0,"source_sha":"8433baa4f45e0c807687da7e3f0fb9b23aaf08850dd161231efe45e56bca79f9","icon_sha":"24c1e3301006d133381650c0da7029f89f0915e8167866710d85c7614592569d"},
	{"faction_id":"faction_veilmourn","town_id":"town_pale_sounding_harbor","placement_id":"horizon_pale_town","building_id":"building_veilmourn_pale_sounding_last_memory_beacon","unit_id":"unit_veilmourn_tidehook_deckhands","rare_resource_id":"memory_salt","cost":{"gold":3500,"wood":2,"ore":2},"requires":["building_veilmourn_wakeglass_chart_house","building_veilmourn_saltwake_factor"],"income":{"gold":120,"memory_salt":1},"growth":1,"discount":5,"readiness":4,"pressure":1,"recovery":0,"source_sha":"964e48096769671c66b09026d14fa347ea7bd748d010e6c8c30ba15df5007aab","icon_sha":"60da6a1381bcbd78e2d3652e4d282e99622fc2ef4181c8a986aed51bd59f0a17"},
]

var _errors: Array[String] = []
var _rows: Array = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	get_window().size = Vector2i(1280, 720)
	ContentService.clear_cache()
	_expect(ContentService.get_content_ids(ContentService.BUILDINGS_PATH).size() == 154, "Capstone batch must remain present in the expanded 154-building catalog.")
	for case_value in CASES:
		await _run_case(case_value)
	_finish()


func _run_case(case: Dictionary) -> void:
	var building_id := String(case.get("building_id", ""))
	var town_id := String(case.get("town_id", ""))
	var placement_id := String(case.get("placement_id", ""))
	var unit_id := String(case.get("unit_id", ""))
	var building := ContentService.get_building(building_id)
	var town_template := ContentService.get_town(town_id)
	var art := ContentService.get_building_art(building_id)
	var icon_path := String(art.get("icon_path", ""))
	var source_path := String(art.get("source_path", ""))
	var icon := load(icon_path) as Texture2D
	var source := Image.load_from_file(ProjectSettings.globalize_path(source_path))
	var exact_content: bool = (
		String(building.get("content_status", "")) == "horizon_capstone_monument_live"
		and String(building.get("faction_id", "")) == String(case.get("faction_id", ""))
		and String(building.get("category", "")) == "civic"
		and _integer_dictionary_equal(building.get("cost", {}), case.get("cost", {}))
		and _string_array_equal(building.get("requires", []), case.get("requires", []))
		and _integer_dictionary_equal(building.get("income", {}), case.get("income", {}))
		and _single_integer_entry_equal(building.get("growth_bonus", {}), unit_id, int(case.get("growth", 0)))
		and _single_integer_entry_equal(building.get("recruitment_discount_percent", {}), unit_id, int(case.get("discount", 0)))
		and int(building.get("readiness_bonus", 0)) == int(case.get("readiness", 0))
		and int(building.get("pressure_bonus", 0)) == int(case.get("pressure", 0))
		and int(building.get("recovery_relief", 0)) == int(case.get("recovery", 0))
		and building_id in town_template.get("buildable_building_ids", [])
	)
	var exact_art: bool = icon != null and icon.get_size() == Vector2(256, 256) and not source.is_empty() and source.get_size() == Vector2i(1254, 1254) and source.detect_alpha() and FileAccess.get_sha256(source_path) == String(case.get("source_sha", "")) and FileAccess.get_sha256(icon_path) == String(case.get("icon_sha", "")) and TownRules.building_icon_path(building_id) == icon_path
	_expect(exact_content, "%s content or exact citadel route changed." % building_id)
	_expect(exact_art, "%s exact art or resolver changed." % building_id)
	var route_owners := []
	for candidate_town_id in ContentService.get_content_ids(ContentService.TOWNS_PATH):
		var candidate := ContentService.get_town(String(candidate_town_id))
		if building_id in candidate.get("starting_building_ids", []) or building_id in candidate.get("buildable_building_ids", []):
			route_owners.append(String(candidate_town_id))
	_expect(route_owners == [town_id], "%s leaked outside its exact citadel: %s." % [building_id, JSON.stringify(route_owners)])

	var session: SessionDataScript.SessionData = ScenarioFactory.create_session(SCENARIO_ID, "normal", SessionDataScript.LAUNCH_MODE_SKIRMISH)
	_expect(session != null, "%s could not create the live six-citadel scenario." % building_id)
	if session == null:
		return
	OverworldRules.normalize_overworld_state(session)
	var town := _town(session, placement_id)
	_expect(String(town.get("town_id", "")) == town_id, "%s live placement changed." % town_id)
	if String(town.get("owner", "")) != "player":
		OverworldRules.capture_town_by_placement(session, placement_id)
	town = _town(session, placement_id)
	_prepare_locked_case(session, town, building_id, case.get("requires", []))
	var locked_action := _build_action(session, building_id)
	var initially_locked: bool = not locked_action.is_empty() and bool(locked_action.get("disabled", false)) and String(locked_action.get("catalog_status", "")) == "Locked"
	_expect(initially_locked, "%s did not begin locked behind its exact prerequisite chain: %s." % [building_id, JSON.stringify(locked_action)])

	var built_dependencies := []
	for requirement_value in case.get("requires", []):
		if not _ensure_building(session, String(requirement_value), {}, built_dependencies):
			return
	var before_town := _town(session, placement_id)
	var before_income_raw := OverworldRules.town_income(before_town)
	var before_income := OverworldRules.town_income(before_town, session)
	var before_growth := OverworldRules.town_weekly_growth(before_town)
	var before_effective_growth := OverworldRules.town_weekly_growth(before_town, session)
	var before_recruit_cost := OverworldRules.town_recruit_cost(session, before_town, unit_id)
	var before_readiness := OverworldRules.town_battle_readiness(before_town, session)
	var before_pressure := OverworldRules.town_pressure_output(before_town, session)
	var before_recovery := OverworldRules._town_recovery_relief_rating(session, before_town)
	session.day += 1
	var stores_before: Dictionary = session.overworld.get("resources", {}).duplicate(true)
	var build_result := TownRules.build_active_town(session, building_id)
	var stores_after: Dictionary = session.overworld.get("resources", {}).duplicate(true)
	var built_town := _town(session, placement_id)
	var after_income_raw := OverworldRules.town_income(built_town)
	var after_income := OverworldRules.town_income(built_town, session)
	var after_growth := OverworldRules.town_weekly_growth(built_town)
	var after_effective_growth := OverworldRules.town_weekly_growth(built_town, session)
	var after_recruit_cost := OverworldRules.town_recruit_cost(session, built_town, unit_id)
	var after_readiness := OverworldRules.town_battle_readiness(built_town, session)
	var after_pressure := OverworldRules.town_pressure_output(built_town, session)
	var after_recovery := OverworldRules._town_recovery_relief_rating(session, built_town)
	var built_exact: bool = bool(build_result.get("ok", false)) and building_id in built_town.get("built_buildings", []) and _cost_spent_exactly(stores_before, stores_after, case.get("cost", {}))
	# Town development metrics deliberately compose authored bonuses with role,
	# logistics, reinforcement-quality, and capital-project effects. Prove the
	# capstone's exact authored payload above, then require the live aggregate to
	# contain at least that contribution instead of pretending the aggregate is
	# a raw field projection.
	var effects_exact: bool = (
		_delta_contains_at_least(before_income_raw, after_income_raw, case.get("income", {}))
		and int(after_income.get(String(case.get("rare_resource_id", "")), 0)) > int(before_income.get(String(case.get("rare_resource_id", "")), 0))
		and int(after_growth.get(unit_id, 0)) - int(before_growth.get(unit_id, 0)) == int(case.get("growth", 0))
		and int(after_effective_growth.get(unit_id, 0)) >= int(before_effective_growth.get(unit_id, 0))
		and int(after_recruit_cost.get("gold", 0)) < int(before_recruit_cost.get("gold", 0))
		and after_readiness - before_readiness >= int(case.get("readiness", 0))
		and after_pressure - before_pressure >= int(case.get("pressure", 0))
		and after_recovery - before_recovery >= int(case.get("recovery", 0))
	)
	_expect(built_exact, "%s did not build through production authority with exact cost: %s." % [building_id, JSON.stringify(build_result)])
	_expect(effects_exact, "%s live effects changed: income=%s growth=%s cost=%s readiness=%d pressure=%d recovery=%d." % [building_id, JSON.stringify(_delta(before_income, after_income)), JSON.stringify(_delta(before_growth, after_growth)), JSON.stringify([before_recruit_cost, after_recruit_cost]), after_readiness - before_readiness, after_pressure - before_pressure, after_recovery - before_recovery])

	var popup_exact: bool = await _validate_live_popup(session, case)
	var authority := session.to_dict()
	var restored := SessionDataScript.SessionData.new()
	restored.from_dict(authority.duplicate(true))
	var save_exact: bool = int(restored.save_version) == SessionDataScript.SAVE_VERSION and restored.to_dict() == authority and building_id in _town(restored, placement_id).get("built_buildings", [])
	_expect(save_exact, "%s did not survive save-version-%d round trip." % [building_id, SessionDataScript.SAVE_VERSION])
	_rows.append({"building_id":building_id,"town_id":town_id,"content_exact":exact_content,"art_exact":exact_art,"initially_locked":initially_locked,"dependency_build_count":built_dependencies.size(),"built_exact":built_exact,"effects_exact":effects_exact,"popup_exact":popup_exact,"save_round_trip_exact":save_exact,"rare_income":int(after_income.get(String(case.get("rare_resource_id", "")), 0)) - int(before_income.get(String(case.get("rare_resource_id", "")), 0)),"weekly_growth_delta":int(after_growth.get(unit_id, 0)) - int(before_growth.get(unit_id, 0))})
	SessionState.set_active_session(null)


func _prepare_locked_case(session: SessionDataScript.SessionData, town: Dictionary, building_id: String, requirements: Variant) -> void:
	session.day = 30
	session.overworld["resources"] = {"gold":100000,"wood":1000,"ore":1000,"aetherglass":1000,"embergrain":1000,"peatwax":1000,"verdant_grafts":1000,"brass_scrip":1000,"memory_salt":1000}
	var built: Array = town.get("built_buildings", []).duplicate(true)
	built.erase(building_id)
	for requirement_value in requirements if requirements is Array else []:
		built.erase(String(requirement_value))
	town["built_buildings"] = built
	town["last_build_day"] = 29
	_move_active_hero_to_town(session, town)
	var visit := OverworldRules.set_active_town_visit(session, String(town.get("placement_id", "")))
	_expect(bool(visit.get("ok", false)), "%s could not establish its live town visit." % building_id)


func _ensure_building(session: SessionDataScript.SessionData, building_id: String, trail: Dictionary, built_ids: Array) -> bool:
	var active := TownRules.get_active_town(session)
	if building_id in active.get("built_buildings", []):
		return true
	if trail.has(building_id):
		_expect(false, "Build dependency cycle reached %s." % building_id)
		return false
	var building := ContentService.get_building(building_id)
	if building.is_empty():
		_expect(false, "Missing dependency building %s." % building_id)
		return false
	var next_trail := trail.duplicate()
	next_trail[building_id] = true
	var dependencies: Array = building.get("requires", []).duplicate(true)
	var upgrade_from := String(building.get("upgrade_from", ""))
	if upgrade_from != "" and upgrade_from not in dependencies:
		dependencies.append(upgrade_from)
	for dependency_value in dependencies:
		if not _ensure_building(session, String(dependency_value), next_trail, built_ids):
			return false
	session.day += 1
	var result := TownRules.build_active_town(session, building_id)
	if not bool(result.get("ok", false)):
		_expect(false, "Could not build dependency %s: %s." % [building_id, JSON.stringify(result)])
		return false
	built_ids.append(building_id)
	return true


func _validate_live_popup(session: SessionDataScript.SessionData, case: Dictionary) -> bool:
	# Building the complete capstone chain can satisfy this scenario's victory
	# objective. The Town shell correctly routes completed sessions to Outcome,
	# so use a presentation-only copy held in progress while preserving the
	# authoritative completed session for the save round-trip below.
	var presentation := SessionDataScript.SessionData.new()
	presentation.from_dict(session.to_dict())
	presentation.scenario_status = "in_progress"
	presentation.game_state = "town"
	SessionState.set_active_session(presentation)
	var shell = TownShellScene.instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	shell.call("validation_open_town_catalog", "build")
	await get_tree().process_frame
	await get_tree().process_frame
	var snapshot: Dictionary = shell.call("validation_town_catalog_snapshot")
	var actions: Array = TownRules.get_build_catalog(SessionState.ensure_active_session())
	var buttons := _buttons_in(shell.get_node_or_null("%BuildActions"))
	var building_id := String(case.get("building_id", ""))
	var action_index := -1
	for index in range(actions.size()):
		if TownRules.building_id_for_action(String(actions[index].get("id", ""))) == building_id:
			action_index = index
			break
	var button: Button = buttons[action_index] if action_index >= 0 and action_index < buttons.size() else null
	var popup_exact: bool = bool(snapshot.get("open", false)) and String(snapshot.get("mode", "")) == "build" and building_id in snapshot.get("build_ids", []) and button != null and button.icon != null and button.icon.resource_path == TownRules.building_icon_path(building_id) and button.expand_icon and button.get_theme_constant("icon_max_width") == 46
	var catalog_scroll := shell.get_node_or_null("%TownCatalogScroll") as ScrollContainer
	if popup_exact and catalog_scroll != null:
		catalog_scroll.ensure_control_visible(button)
		await get_tree().process_frame
		await get_tree().process_frame
	var capture := get_viewport().get_texture().get_image()
	var capture_path := "%s/%s_build_popup.png" % [OUTPUT_DIR, building_id]
	popup_exact = popup_exact and not capture.is_empty() and capture.save_png(capture_path) == OK
	_expect(popup_exact, "%s did not render its exact icon through the live Build popup." % building_id)
	shell.queue_free()
	await get_tree().process_frame
	return popup_exact


func _build_action(session: SessionDataScript.SessionData, building_id: String) -> Dictionary:
	for action_value in TownRules.get_build_catalog(session):
		if action_value is Dictionary and TownRules.building_id_for_action(String(action_value.get("id", ""))) == building_id:
			return action_value
	return {}


func _town(session: SessionDataScript.SessionData, placement_id: String) -> Dictionary:
	for value in session.overworld.get("towns", []):
		if value is Dictionary and String(value.get("placement_id", "")) == placement_id:
			return value
	return {}


func _move_active_hero_to_town(session: SessionDataScript.SessionData, town: Dictionary) -> void:
	var position := {"x":int(town.get("x", 0)),"y":int(town.get("y", 0))}
	session.overworld["hero_position"] = position.duplicate(true)
	var hero: Dictionary = session.overworld.get("hero", {})
	hero["x"] = int(position.x)
	hero["y"] = int(position.y)
	hero["position"] = position.duplicate(true)
	session.overworld["hero"] = hero


func _delta(before: Dictionary, after: Dictionary) -> Dictionary:
	var result := {}
	for key_value in before.keys() + after.keys():
		var key := String(key_value)
		var value := int(after.get(key, 0)) - int(before.get(key, 0))
		if value != 0:
			result[key] = value
	return result


func _delta_matches(before: Dictionary, after: Dictionary, expected_value: Variant) -> bool:
	var expected: Dictionary = expected_value if expected_value is Dictionary else {}
	return _integer_dictionary_equal(_delta(before, after), expected)


func _delta_contains_at_least(before: Dictionary, after: Dictionary, expected_value: Variant) -> bool:
	var expected: Dictionary = expected_value if expected_value is Dictionary else {}
	var actual := _delta(before, after)
	for key_value in expected.keys():
		var key := String(key_value)
		if int(actual.get(key, 0)) < int(expected.get(key, 0)):
			return false
	return true


func _integer_dictionary_equal(left_value: Variant, right_value: Variant) -> bool:
	var left: Dictionary = left_value if left_value is Dictionary else {}
	var right: Dictionary = right_value if right_value is Dictionary else {}
	if left.size() != right.size():
		return false
	for key_value in left.keys():
		var key := String(key_value)
		if not right.has(key) or int(left.get(key, 0)) != int(right.get(key, 0)):
			return false
	return true


func _string_array_equal(left_value: Variant, right_value: Variant) -> bool:
	var left: Array = left_value if left_value is Array else []
	var right: Array = right_value if right_value is Array else []
	if left.size() != right.size():
		return false
	for index in range(left.size()):
		if String(left[index]) != String(right[index]):
			return false
	return true


func _single_integer_entry_equal(value: Variant, key: String, expected: int) -> bool:
	var dictionary: Dictionary = value if value is Dictionary else {}
	return dictionary.size() == 1 and dictionary.has(key) and int(dictionary.get(key, 0)) == expected


func _cost_spent_exactly(before: Dictionary, after: Dictionary, cost_value: Variant) -> bool:
	var cost: Dictionary = cost_value if cost_value is Dictionary else {}
	for resource_id in OverworldRules.LIVE_STOCKPILE_RESOURCE_KEYS:
		var key := String(resource_id)
		if int(after.get(key, 0)) != int(before.get(key, 0)) - int(cost.get(key, 0)):
			return false
	return true


func _buttons_in(node: Node) -> Array:
	var buttons := []
	if node == null:
		return buttons
	if node is Button:
		buttons.append(node)
	for child in node.get_children():
		buttons.append_array(_buttons_in(child))
	return buttons


func _finish() -> void:
	var report := {"ok":_errors.is_empty(),"report_id":REPORT_ID,"case_count":_rows.size(),"exact_content_count":_rows.filter(func(row): return bool(row.get("content_exact", false))).size(),"catalog_building_count":ContentService.get_content_ids(ContentService.BUILDINGS_PATH).size(),"exact_art_count":_rows.filter(func(row): return bool(row.get("art_exact", false))).size(),"live_popup_count":_rows.filter(func(row): return bool(row.get("popup_exact", false))).size(),"production_build_count":_rows.filter(func(row): return bool(row.get("built_exact", false))).size(),"live_effect_count":_rows.filter(func(row): return bool(row.get("effects_exact", false))).size(),"save_version":SessionDataScript.SAVE_VERSION,"single_consolidated_smoke":true,"rows":_rows,"errors":_errors}
	var file := FileAccess.open(ProjectSettings.globalize_path(REPORT_PATH), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  ") + "\n")
	print("%s %s" % [REPORT_ID, JSON.stringify(report)])
	get_tree().quit(0 if _errors.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_errors.append(message)
	push_error("%s %s" % [REPORT_ID, message])
