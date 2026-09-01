extends "res://tests/eight_neutral_dwelling_musters_report.gd"

const AbilityRuntimeReportScript = preload("res://tests/unit_ability_runtime_report.gd")
const BattleAutoResolveRulesScript = preload("res://scripts/core/BattleAutoResolveRules.gd")

const BATCH_REPORT_ID := "SIX_FRONTIER_MYTHIC_HABITATS_SMOKE"
const BATCH_OUTPUT_DIR := "res://.artifacts/six_frontier_mythic_habitats_smoke"
const BATCH_ATLAS_PATH := "res://art/overworld/runtime/objects/resource_sites/frontier_mythic_habitats_atlas.png"
const BATCH_CASES := [
	{"scenario_id":"emberwell-censerwing-updraft","stem":"cindervane_updraft_roost","site_id":"site_cindervane_updraft_roost","placement_id":"cindervane_updraft_roost_habitat","guard_id":"cindervane_updraft_roost_front_3","encounter_id":"encounter_cindervane_updraft_roost_watch","unit_id":"unit_neutral_cindervane_censerwings","tier":5,"ability_ids":["harry","volley"],"unclaimed":"mapobj_cindervane_updraft_roost","claimed":"resource_site_neutral_cindervane_updraft_roost_controlled","region":Rect2(48,0,48,48),"identity_asset_id":"encounter_frontier_mythic_cindervane_updraft_roost_watch"},
	{"scenario_id":"fenhook-fenmirror-muster","stem":"fenmirror_shell_basin","site_id":"site_fenmirror_shell_basin","placement_id":"fenmirror_shell_basin_habitat","guard_id":"fenmirror_shell_basin_front_3","encounter_id":"encounter_fenmirror_shell_basin_watch","unit_id":"unit_neutral_fenmirror_gallowshells","tier":6,"ability_ids":["brace","shielding"],"unclaimed":"mapobj_fenmirror_shell_basin","claimed":"resource_site_neutral_fenmirror_shell_basin_controlled","region":Rect2(144,0,48,48),"identity_asset_id":"encounter_frontier_mythic_fenmirror_shell_basin_watch"},
	{"scenario_id":"glasswind-prismwake-crossing","stem":"prismwake_refraction_shelf","site_id":"site_prismwake_refraction_shelf","placement_id":"prismwake_refraction_shelf_habitat","guard_id":"prismwake_refraction_shelf_front_3","encounter_id":"encounter_prismwake_refraction_shelf_watch","unit_id":"unit_neutral_prismwake_raylings","tier":5,"ability_ids":["harry","volley"],"unclaimed":"mapobj_prismwake_refraction_shelf","claimed":"resource_site_neutral_prismwake_refraction_shelf_controlled","region":Rect2(240,0,48,48),"identity_asset_id":"encounter_frontier_mythic_prismwake_refraction_shelf_watch"},
	{"scenario_id":"boltroot-knotstag-circuit","stem":"knotstag_root_court","site_id":"site_knotstag_root_court","placement_id":"knotstag_root_court_habitat","guard_id":"knotstag_root_court_front_3","encounter_id":"encounter_knotstag_root_court_watch","unit_id":"unit_neutral_rootcrown_knotstags","tier":6,"ability_ids":["reach","shielding"],"unclaimed":"mapobj_knotstag_root_court","claimed":"resource_site_neutral_knotstag_root_court_controlled","region":Rect2(336,0,48,48),"identity_asset_id":"encounter_frontier_mythic_knotstag_root_court_watch"},
	{"scenario_id":"debtrune-gaugecoil-burrow","stem":"gaugecoil_pressure_burrow","site_id":"site_gaugecoil_pressure_burrow","placement_id":"gaugecoil_pressure_burrow_habitat","guard_id":"gaugecoil_pressure_burrow_front_3","encounter_id":"encounter_gaugecoil_pressure_burrow_watch","unit_id":"unit_neutral_gaugecoil_orewyrms","tier":6,"ability_ids":["brace","reach"],"unclaimed":"mapobj_gaugecoil_pressure_burrow","claimed":"resource_site_neutral_gaugecoil_pressure_burrow_controlled","region":Rect2(432,0,48,48),"identity_asset_id":"encounter_frontier_mythic_gaugecoil_pressure_burrow_watch"},
	{"scenario_id":"mistcorsair-gloambell-sounding","stem":"gloambell_sounding_deep","site_id":"site_gloambell_sounding_deep","placement_id":"gloambell_sounding_deep_habitat","guard_id":"gloambell_sounding_deep_front_3","encounter_id":"encounter_gloambell_sounding_deep_watch","unit_id":"unit_neutral_gloambell_wake_mantas","tier":7,"ability_ids":["harry","volley"],"unclaimed":"mapobj_gloambell_sounding_deep","claimed":"resource_site_neutral_gloambell_sounding_deep_controlled","region":Rect2(528,0,48,48),"identity_asset_id":"encounter_frontier_mythic_gloambell_sounding_deep_watch"},
]


func _validate_case(view: Control, case: Dictionary) -> void:
	await super._validate_case(view, case)
	var unit_id := String(case.get("unit_id", ""))
	var unit := ContentService.get_unit(unit_id)
	_expect(String(unit.get("content_status", "")) == "frontier_mythic_habitat_live", "%s is not marked live frontier-mythic content." % unit_id)
	_expect(int(unit.get("tier", 0)) == int(case.get("tier", 0)), "%s tier changed." % unit_id)
	_expect(_ability_ids(unit.get("abilities", [])) == case.get("ability_ids", []), "%s ability identity changed." % unit_id)
	var art := ContentService.get_unit_art(unit_id)
	var animation := ContentService.get_unit_animation(unit_id)
	for art_key in ["portrait", "battle_icon", "battle_standee", "overworld_icon"]:
		var art_path := String(art.get(art_key, ""))
		_expect(art_path != "" and load(art_path) is Texture2D, "%s lost its %s runtime art." % [unit_id, art_key])
	var animation_path := String(animation.get("sprite_sheet", ""))
	_expect(animation_path != "" and load(animation_path) is Texture2D, "%s lost its runtime animation sheet." % unit_id)
	_expect(String(art.get("curated_source_sha256", "")) != "" and art.get("curated_source_sha256") == animation.get("curated_source_sha256"), "%s runtime art provenance changed." % unit_id)

	var probe = AbilityRuntimeReportScript.new()
	var ability_results := {}
	for ability_id_value in case.get("ability_ids", []):
		var ability_id := String(ability_id_value)
		var result: Dictionary = probe.call("_runtime_consequence_for_ability", unit_id, ability_id)
		ability_results[ability_id] = result
		_expect(bool(result.get("ok", false)), "%s %s did not execute its live combat consequence: %s" % [unit_id, ability_id, JSON.stringify(result)])
	probe.free()

	var scenario_id := String(case.get("scenario_id", ""))
	var stem := String(case.get("stem", ""))
	var session = ScenarioFactory.create_session(scenario_id, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var scenario := ContentService.get_scenario(scenario_id)
	_expect(int(scenario.get("map_size", {}).get("width", 0)) == 18 and int(scenario.get("map_size", {}).get("height", 0)) == 14 and scenario.get("encounters", []).size() == 3, "%s lost its 18x14 three-front board." % scenario_id)
	var production_payloads := 0
	for index in range(1, 4):
		var placement_id := "%s_front_%d" % [stem, index]
		var front := _encounter(session, placement_id)
		var payload: Dictionary = BattleRulesScript.create_battle_payload(session, front)
		if not payload.is_empty() and String(payload.get("encounter_id", "")) == String(case.get("encounter_id", "")):
			production_payloads += 1
	_expect(production_payloads == 3, "%s did not construct all three authored production battles." % scenario_id)

	# One representative real battle per map; the other two fronts are payload-probed above.
	var live_front := _encounter(session, "%s_front_1" % stem)
	var battle_payload: Dictionary = BattleRulesScript.create_battle_payload(session, live_front)
	session.battle = battle_payload
	session.game_state = "battle"
	session.battle[BattleRulesScript.PRESENTATION_SPEED_KEY] = BattleRulesScript.PRESENTATION_SPEED_INSTANT
	var battle_result: Dictionary = BattleAutoResolveRulesScript.resolve_active_battle(session)
	var live_battle_victory: bool = bool(battle_result.get("completed", false)) and String(battle_result.get("state", "")) == "victory" and ("%s_front_1" % stem) in session.overworld.get("resolved_encounters", [])
	_expect(live_battle_victory, "%s representative live battle did not resolve as a victory: %s" % [scenario_id, JSON.stringify(battle_result)])
	for index in range(2, 4):
		_resolve_guard(session, "%s_front_%d" % [stem, index])
	var claim := OverworldRules._collect_resource_node_result(session, _resource_node_result(session, String(case.get("placement_id", ""))), true)
	_expect(bool(claim.get("ok", false)) and _army_counts(session, [unit_id]).get(unit_id, 0) >= 1, "%s did not recruit %s after all three watches cleared." % [scenario_id, unit_id])
	for town_index in range(session.overworld.get("towns", []).size()):
		var town: Dictionary = session.overworld["towns"][town_index]
		if String(town.get("placement_id", "")) == "%s_enemy_town" % stem:
			town["owner"] = "player"
			session.overworld["towns"][town_index] = town
	var victory_result: Dictionary = ScenarioRules.evaluate_session(session)
	var objective_victory := String(victory_result.get("status", "")) == "victory"
	_expect(objective_victory, "%s did not complete its six-objective route: %s" % [scenario_id, JSON.stringify(victory_result)])
	var presentation: Dictionary = view.call("validation_encounter_presentation_payload", live_front)
	var exact_identity := String(presentation.get("identity_encounter_asset_id", "")) == String(case.get("identity_asset_id", "")) and String(presentation.get("identity_encounter_path", "")) == String(art.get("overworld_icon", "")) and bool(presentation.get("uses_identity_encounter_sprite", false))
	_expect(exact_identity, "%s lost its exact creature encounter identity." % String(case.get("encounter_id", "")))
	var restored := _clone_session(session)
	var save_exact := restored.to_dict() == session.to_dict() and int(restored.save_version) == SessionStateStoreScript.SAVE_VERSION
	_expect(save_exact, "%s completed route did not round-trip through save version %d." % [scenario_id, SessionStateStoreScript.SAVE_VERSION])
	if not _rows.is_empty():
		_rows[-1]["unit_id"] = unit_id
		_rows[-1]["ability_results"] = ability_results
		_rows[-1]["production_payloads"] = production_payloads
		_rows[-1]["live_battle_victory"] = live_battle_victory
		_rows[-1]["objective_victory"] = objective_victory
		_rows[-1]["exact_identity_art"] = exact_identity
		_rows[-1]["completed_save_round_trip_exact"] = save_exact


func _ability_ids(abilities: Variant) -> Array:
	var result := []
	if abilities is Array:
		for value in abilities:
			if value is Dictionary:
				result.append(String(value.get("id", "")))
	return result


func _report_id() -> String:
	return BATCH_REPORT_ID


func _output_dir() -> String:
	return BATCH_OUTPUT_DIR


func _atlas_path() -> String:
	return BATCH_ATLAS_PATH


func _capture_environment_name() -> String:
	return "FRONTIER_MYTHIC_HABITAT_CAPTURE_DIR"


func _cases() -> Array:
	return BATCH_CASES
