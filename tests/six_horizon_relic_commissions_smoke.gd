extends Node

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "SIX_HORIZON_RELIC_COMMISSIONS_SMOKE"
const OUTPUT_DIR := "res://.artifacts/six_horizon_relic_commissions_smoke"
const REPORT_PATH := OUTPUT_DIR + "/report.json"
const SCENARIO_ID := "ninefold-confluence"
const TABLE_ID := "artifact_source_horizon_citadel_commissions"
const CASES := [
	{"town_id":"town_rainwrit_bastion","placement_id":"ninefold_rainwrit_bastion","control_placement_id":"ninefold_embercourt_survey_camp","faction_id":"faction_embercourt","building_id":"building_embercourt_charter_flame","artifact_id":"artifact_rainwrit_beacon_seal","icon_path":"res://art/artifacts/runtime/rainwrit_beacon_seal.png","source_path":"res://art/artifacts/source/generated/horizon_relic_commissions/rainwrit_beacon_seal_source.png","source_sha256":"9e57e396db43ba4445770c2060f18034d5251346e8d979677b50549b98079b2e","runtime_sha256":"a24ad69542e9ea5a97baf937a3b980dd09ba9b33d80b536f71afe42179b214fd","cost":{"gold":1800,"wood":2,"embergrain":2},"bonuses":{"battle_defense":1,"overworld_movement":1,"daily_income":{"embergrain":1}}},
	{"town_id":"town_hollowreed_sanctuary","placement_id":"ninefold_hollowreed_sanctuary","control_placement_id":"ninefold_duskfen_gate","faction_id":"faction_mireclaw","building_id":"building_mireclaw_oathmire_court","artifact_id":"artifact_hollowreed_moonfang_drum","icon_path":"res://art/artifacts/runtime/hollowreed_moonfang_drum.png","source_path":"res://art/artifacts/source/generated/horizon_relic_commissions/hollowreed_moonfang_drum_source.png","source_sha256":"d3e001d6e8456882e62460f8956f0fa897ce3cf1760cb5b51ad1e23a03ae50d0","runtime_sha256":"99a9ccbb01d1e426678242e8cb7b7cc609fbe9fd34eabfe70b8f73e1f412ca80","cost":{"gold":1800,"wood":2,"peatwax":2},"bonuses":{"battle_attack":1,"battle_initiative":1,"daily_income":{"peatwax":1}}},
	{"town_id":"town_meridian_choirhold","placement_id":"ninefold_meridian_choirhold","control_placement_id":"ninefold_prismhearth_relay","faction_id":"faction_sunvault","building_id":"building_sunvault_zenith_court","artifact_id":"artifact_meridian_choir_prism","icon_path":"res://art/artifacts/runtime/meridian_choir_prism.png","source_path":"res://art/artifacts/source/generated/horizon_relic_commissions/meridian_choir_prism_source.png","source_sha256":"328fd09f68d9cf3be82a85d87f6cc83a02811d9e088dda0d2cb89c725bf7e4ca","runtime_sha256":"f7ca39e6425eaf86aa0ccdb0ddcabc3659428733ae0b1b3aab5c35a2ae0c3ccb","cost":{"gold":1800,"ore":2,"aetherglass":2},"bonuses":{"battle_spell_resistance_pct":8,"battle_initiative":1,"daily_income":{"aetherglass":1}}},
	{"town_id":"town_crownroot_refuge","placement_id":"ninefold_crownroot_refuge","control_placement_id":"ninefold_graftroot_caravan","faction_id":"faction_thornwake","building_id":"building_thornwake_rootlaw_moot","artifact_id":"artifact_crownroot_oathseed_censer","icon_path":"res://art/artifacts/runtime/crownroot_oathseed_censer.png","source_path":"res://art/artifacts/source/generated/horizon_relic_commissions/crownroot_oathseed_censer_source.png","source_sha256":"fba2b9b9cb591e42542297eede36196b7f8ef9d2ff978d7f83748c552893f77e","runtime_sha256":"7084fce708e47eec9511912e0f60f0c721d11afde4e8bb8cffab55ffd06fe424","cost":{"gold":1800,"wood":2,"verdant_grafts":2},"bonuses":{"battle_defense":1,"overworld_movement":1,"daily_income":{"verdant_grafts":1}}},
	{"town_id":"town_blackbell_foundry","placement_id":"ninefold_blackbell_foundry","control_placement_id":"ninefold_orevein_gantry","faction_id":"faction_brasshollow","building_id":"building_brasshollow_brassbound_directorate","artifact_id":"artifact_blackbell_verdict_gauge","icon_path":"res://art/artifacts/runtime/blackbell_verdict_gauge.png","source_path":"res://art/artifacts/source/generated/horizon_relic_commissions/blackbell_verdict_gauge_source.png","source_sha256":"66bfac3d17c8d9dcf5809589f4312534d588210b542980f2ae5a08294515d280","runtime_sha256":"867d56cd3540557be6f6648d6d7ae93996c712c3dc7a9ab1c298af1f112c7a28","cost":{"gold":1800,"ore":2,"brass_scrip":2},"bonuses":{"battle_attack":1,"battle_defense":1,"daily_income":{"brass_scrip":1}}},
	{"town_id":"town_pale_sounding_harbor","placement_id":"ninefold_pale_sounding_harbor","control_placement_id":"ninefold_bellwake_harbor","faction_id":"faction_veilmourn","building_id":"building_veilmourn_drowned_admiralty","artifact_id":"artifact_pale_sounding_memory_bell","icon_path":"res://art/artifacts/runtime/pale_sounding_memory_bell.png","source_path":"res://art/artifacts/source/generated/horizon_relic_commissions/pale_sounding_memory_bell_source.png","source_sha256":"aaff3e55ed4210feee531167c574a418c385c26c380ddce7255e3665b8f19fa5","runtime_sha256":"b4436cc3def1c393e6cf8e54569a1037c16fb510665aae35fa4faa12b0cb68a9","cost":{"gold":1800,"wood":1,"ore":1,"memory_salt":2},"bonuses":{"scouting_radius":1,"battle_initiative":1,"daily_income":{"memory_salt":1}}},
]

var _errors: Array[String] = []
var _rows: Array = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var baseline = ScenarioFactory.create_session(SCENARIO_ID, "hard", SessionState.LAUNCH_MODE_SKIRMISH)
	_expect(baseline != null, "Ninefold baseline session could not be created.")
	if baseline == null:
		_finish()
		return
	OverworldRules.normalize_overworld_state(baseline)
	var baseline_payload: Dictionary = baseline.to_dict()
	for case_value in CASES:
		print("%s CASE_START %s" % [REPORT_ID, String(case_value.get("town_id", ""))])
		_run_case(baseline_payload, case_value)
		print("%s CASE_DONE %s" % [REPORT_ID, String(case_value.get("town_id", ""))])
	_finish()

func _run_case(baseline_payload: Dictionary, case: Dictionary) -> void:
	var session := SessionStateStoreScript.SessionData.new()
	session.from_dict(baseline_payload)
	var placement_id := String(case.get("placement_id", ""))
	var control_placement_id := String(case.get("control_placement_id", ""))
	var town_id := String(case.get("town_id", ""))
	var building_id := String(case.get("building_id", ""))
	var artifact_id := String(case.get("artifact_id", ""))
	var town := _town(session, placement_id)
	_expect(String(town.get("town_id", "")) == town_id, "%s is missing from Ninefold." % town_id)
	town["owner"] = "player"
	session.day = 50
	session.game_state = "town"
	session.scenario_status = "in_progress"
	session.overworld["resources"] = {"gold":1000000,"wood":10000,"ore":10000,"aetherglass":10000,"embergrain":10000,"peatwax":10000,"verdant_grafts":10000,"brass_scrip":10000,"memory_salt":10000}
	_expect(bool(OverworldRules.set_active_town_visit(session, placement_id).get("ok", false)), "%s could not become the active Town." % town_id)
	_expect(_commission_actions_for_building(session, building_id).is_empty(), "%s exposed its relic before the service building was complete." % town_id)
	var built_ids: Array = []
	var built_ok := _ensure_building(session, building_id, {}, built_ids)
	_expect(built_ok and building_id in _town(session, placement_id).get("built_buildings", []), "%s did not complete its live build chain." % building_id)
	if not built_ok:
		_rows.append({"town_id":town_id,"building_id":building_id,"artifact_id":artifact_id,"built_building_count":built_ids.size(),"critical_failure":"build_chain"})
		return
	var actions := _commission_actions_for_building(session, building_id)
	var action: Dictionary = actions[0] if actions.size() == 1 and actions[0] is Dictionary else {}
	_expect(actions.size() == 1, "%s must expose exactly one horizon relic commission, got %d." % [town_id, actions.size()])
	if action.is_empty():
		_rows.append({"town_id":town_id,"building_id":building_id,"artifact_id":artifact_id,"built_building_count":built_ids.size(),"exact_single_action":false,"critical_failure":"commission_action_missing"})
		return
	_expect(String(action.get("building_id", "")) == building_id and String(action.get("artifact_id", "")) == artifact_id and String(action.get("artifact_reward_table_id", "")) == TABLE_ID, "%s exposed the wrong relic action: %s" % [town_id, JSON.stringify(action)])
	_expect(_cost_matches(action.get("cost", {}), case.get("cost", {})) and not bool(action.get("disabled", true)), "%s commission cost or affordability changed." % artifact_id)
	var icon = load(String(case.get("icon_path", "")))
	var source_image := Image.load_from_file(ProjectSettings.globalize_path(String(case.get("source_path", ""))))
	var art_exact: bool = (
		icon is Texture2D and icon.get_size() == Vector2(128, 128)
		and not source_image.is_empty() and source_image.detect_alpha() != Image.ALPHA_NONE
		and FileAccess.get_sha256(String(case.get("source_path", ""))) == String(case.get("source_sha256", ""))
		and FileAccess.get_sha256(String(case.get("icon_path", ""))) == String(case.get("runtime_sha256", ""))
	)
	_expect(art_exact, "%s did not load its exact transparent generated art." % artifact_id)
	var resources_before: Dictionary = session.overworld.get("resources", {}).duplicate(true)
	var result: Dictionary = TownRules.manage_artifact_at_active_town(session, "commission_artifact:%s" % building_id)
	var resources_after: Dictionary = session.overworld.get("resources", {}).duplicate(true)
	var hero: Dictionary = session.overworld.get("hero", {})
	var granted_exact := bool(result.get("ok", false)) and artifact_id in ArtifactRules.owned_artifact_ids(hero) and _artifact_equipped(hero, artifact_id)
	_expect(granted_exact, "%s was not granted and auto-equipped: %s" % [artifact_id, JSON.stringify(result)])
	var cost_spent_exactly := _cost_spent_exactly(resources_before, resources_after, case.get("cost", {}))
	_expect(cost_spent_exactly, "%s did not spend its exact commission cost." % artifact_id)
	var bonuses_live := _bonuses_match(ArtifactRules.aggregate_bonuses(hero), case.get("bonuses", {}), artifact_id)
	var claimed_town := _town(session, placement_id)
	var provenance_exact := (
		String(claimed_town.get("artifact_reward_id", "")) == artifact_id
		and String(claimed_town.get("artifact_reward_table_id", "")) == TABLE_ID
		and String(claimed_town.get("artifact_reward_service_building_id", "")) == building_id
		and String(claimed_town.get("artifact_reward_claimed_by_faction_id", "")) == String(case.get("faction_id", ""))
	)
	_expect(provenance_exact, "%s lost Town commission provenance." % artifact_id)
	var repeat_before: Dictionary = session.to_dict()
	var repeat: Dictionary = TownRules.manage_artifact_at_active_town(session, "commission_artifact:%s" % building_id)
	var repeat_blocked := not bool(repeat.get("ok", false)) and session.to_dict() == repeat_before and _commission_actions_for_building(session, building_id).is_empty()
	_expect(repeat_blocked, "%s repeat commission mutated state." % artifact_id)
	var restored := SessionStateStoreScript.SessionData.new()
	restored.from_dict(session.to_dict())
	var save_exact := restored.to_dict() == session.to_dict() and int(restored.save_version) == SessionStateStoreScript.SAVE_VERSION
	_expect(save_exact and artifact_id in ArtifactRules.owned_artifact_ids(restored.overworld.get("hero", {})), "%s did not survive save-version-%d round trip." % [artifact_id, SessionStateStoreScript.SAVE_VERSION])
	var control := _town(session, control_placement_id)
	control["owner"] = "player"
	var control_built: Array = control.get("built_buildings", []).duplicate(true)
	if building_id not in control_built:
		control_built.append(building_id)
	control["built_buildings"] = control_built
	control.erase("artifact_reward_id")
	var other_town_hidden := bool(OverworldRules.set_active_town_visit(session, control_placement_id).get("ok", false)) and _commission_actions_for_building(session, building_id).is_empty()
	_expect(other_town_hidden, "%s commission leaked to %s." % [artifact_id, String(control.get("town_id", ""))])
	_rows.append({"town_id":town_id,"building_id":building_id,"artifact_id":artifact_id,"built_building_count":built_ids.size(),"exact_single_action":actions.size()==1,"art_exact":art_exact,"granted_and_auto_equipped":granted_exact,"cost_spent_exactly":cost_spent_exactly,"bonuses_live":bonuses_live,"provenance_exact":provenance_exact,"repeat_blocked":repeat_blocked,"save_round_trip_exact":save_exact,"other_town_hidden":other_town_hidden})

func _ensure_building(session, building_id: String, trail: Dictionary, built_ids: Array) -> bool:
	var active := TownRules.get_active_town(session)
	if building_id in active.get("built_buildings", []):
		return true
	if trail.has(building_id):
		_expect(false, "Build dependency cycle reached %s." % building_id)
		return false
	var next_trail := trail.duplicate()
	next_trail[building_id] = true
	var building := ContentService.get_building(building_id)
	if building.is_empty():
		_expect(false, "Missing building %s." % building_id)
		return false
	var dependencies: Array = building.get("requires", []).duplicate(true)
	var upgrade_from := String(building.get("upgrade_from", ""))
	if upgrade_from != "" and upgrade_from not in dependencies:
		dependencies.append(upgrade_from)
	for dependency_value in dependencies:
		if not _ensure_building(session, String(dependency_value), next_trail, built_ids):
			return false
	session.day += 1
	var result: Dictionary = TownRules.build_active_town(session, building_id)
	if not bool(result.get("ok", false)):
		_expect(false, "Could not build %s: %s" % [building_id, JSON.stringify(result)])
		return false
	built_ids.append(building_id)
	return true

func _commission_actions_for_building(session, building_id: String) -> Array:
	var rows := []
	for value in TownRules.get_artifact_actions(session):
		if value is Dictionary and String(value.get("id", "")) == "commission_artifact:%s" % building_id:
			rows.append(value)
	return rows

func _town(session, placement_id: String) -> Dictionary:
	for value in session.overworld.get("towns", []):
		if value is Dictionary and String(value.get("placement_id", "")) == placement_id:
			return value
	return {}

func _artifact_equipped(hero: Dictionary, artifact_id: String) -> bool:
	var artifacts = hero.get("artifacts", {})
	var equipped = artifacts.get("equipped", {}) if artifacts is Dictionary else {}
	return equipped is Dictionary and artifact_id in equipped.values()

func _cost_matches(actual_value: Variant, expected_value: Variant) -> bool:
	var actual: Dictionary = actual_value if actual_value is Dictionary else {}
	var expected: Dictionary = expected_value if expected_value is Dictionary else {}
	for key in OverworldRules.LIVE_STOCKPILE_RESOURCE_KEYS:
		if int(actual.get(String(key), 0)) != int(expected.get(String(key), 0)):
			return false
	return true

func _cost_spent_exactly(before: Dictionary, after: Dictionary, cost_value: Variant) -> bool:
	var cost: Dictionary = cost_value if cost_value is Dictionary else {}
	for key in OverworldRules.LIVE_STOCKPILE_RESOURCE_KEYS:
		var id := String(key)
		if int(after.get(id, 0)) != int(before.get(id, 0)) - int(cost.get(id, 0)):
			return false
	return true

func _bonuses_match(actual: Dictionary, expected_value: Variant, artifact_id: String) -> bool:
	var expected: Dictionary = expected_value if expected_value is Dictionary else {}
	var matches := true
	for key_value in expected.keys():
		var key := String(key_value)
		if expected.get(key) is Dictionary:
			var actual_nested: Dictionary = actual.get(key, {}) if actual.get(key, {}) is Dictionary else {}
			for nested_key_value in (expected.get(key) as Dictionary).keys():
				var nested_key := String(nested_key_value)
				var nested_matches := int(actual_nested.get(nested_key, 0)) == int(expected.get(key, {}).get(nested_key, -1))
				matches = matches and nested_matches
				_expect(nested_matches, "%s live %s.%s bonus changed." % [artifact_id, key, nested_key])
		else:
			var value_matches := int(actual.get(key, 0)) == int(expected.get(key, -1))
			matches = matches and value_matches
			_expect(value_matches, "%s live %s bonus changed." % [artifact_id, key])
	return matches

func _finish() -> void:
	var report := {"ok":_errors.is_empty(),"report_id":REPORT_ID,"case_count":_rows.size(),"reward_table_id":TABLE_ID,"save_version":SessionStateStoreScript.SAVE_VERSION,"single_consolidated_smoke":true,"rows":_rows,"errors":_errors}
	var file := FileAccess.open(ProjectSettings.globalize_path(REPORT_PATH), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  ") + "\n")
	print("%s %s" % [REPORT_ID, JSON.stringify(report)])
	get_tree().quit(0 if _errors.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
		push_error("%s %s" % [REPORT_ID, message])
