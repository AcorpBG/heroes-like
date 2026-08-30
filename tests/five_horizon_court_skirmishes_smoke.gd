extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const ScenarioRulesScript = preload("res://scripts/core/ScenarioRules.gd")
const ScenarioScriptRulesScript = preload("res://scripts/core/ScenarioScriptRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "FIVE_HORIZON_COURT_SKIRMISHES_SMOKE"
const OUTPUT_DIR := "res://.artifacts/five_horizon_court_skirmishes_smoke"
const ATLAS_PATH := "res://art/overworld/runtime/objects/encounters/horizon_courts/horizon_courts_atlas.png"
const ATLAS_SHA256 := "62f9782641416f7251efe446cfa3bbe4b9f07d432c598b5e4e5f429819286955"
const CASES := [
	{"scenario_id":"hollowreed-noonwire-dispute","faction_id":"faction_mireclaw","hero_id":"hero_mireclaw_zhorra_fenwake","army_id":"army_zhorra_grand_convergence_company","home_id":"hollowreed_court_home","home_town_id":"town_hollowreed_sanctuary","enemy_town_id":"hollowreed_court_enemy_town","enemy_faction_id":"faction_sunvault","relief_hook":"hollowreed_relief","pressure_hook":"hollowreed_pressure_hook","completion_hook":"hollowreed_compact_hook","completion_flag":"hollowreed_noonwire_compact","fronts":["hollowreed_court_front_1","hollowreed_court_front_2","hollowreed_court_front_3"],"identity_placement":"hollowreed_court_front_2","encounter_id":"encounter_horizon_court_meridian_noonwire_tribunal","signature_army_id":"army_horizon_court_meridian_noonwire_tribunal","objective_id":"horizon_meridian_noonwire","objective_type":"lane_battery","reward_key":"aetherglass","victory_flag":"horizon_meridian_noonwire_broken","atlas_x":0},
	{"scenario_id":"meridian-rootglass-appeal","faction_id":"faction_sunvault","hero_id":"hero_sunvault_mirro_halometer","army_id":"army_mirro_grand_convergence_company","home_id":"meridian_court_home","home_town_id":"town_meridian_choirhold","enemy_town_id":"meridian_court_enemy_town","enemy_faction_id":"faction_thornwake","relief_hook":"meridian_relief","pressure_hook":"meridian_pressure_hook","completion_hook":"meridian_appeal_hook","completion_flag":"meridian_rootglass_appeal","fronts":["meridian_court_front_1","meridian_court_front_2","meridian_court_front_3"],"identity_placement":"meridian_court_front_2","encounter_id":"encounter_horizon_court_crownroot_rootglass_jury","signature_army_id":"army_horizon_court_crownroot_rootglass_jury","objective_id":"horizon_crownroot_rootglass","objective_type":"obstruction_line","reward_key":"verdant_grafts","victory_flag":"horizon_crownroot_rootglass_broken","atlas_x":48},
	{"scenario_id":"crownroot-quenchline-verdict","faction_id":"faction_thornwake","hero_id":"hero_thornwake_nara_graftsibyl","army_id":"army_nara_grand_convergence_company","home_id":"crownroot_court_home","home_town_id":"town_crownroot_refuge","enemy_town_id":"crownroot_court_enemy_town","enemy_faction_id":"faction_brasshollow","relief_hook":"crownroot_relief","pressure_hook":"crownroot_pressure_hook","completion_hook":"crownroot_verdict_hook","completion_flag":"crownroot_quenchline_verdict","fronts":["crownroot_court_front_1","crownroot_court_front_2","crownroot_court_front_3"],"identity_placement":"crownroot_court_front_2","encounter_id":"encounter_horizon_court_blackbell_quenchline_assize","signature_army_id":"army_horizon_court_blackbell_quenchline_assize","objective_id":"horizon_blackbell_quenchline","objective_type":"breach_point","reward_key":"brass_scrip","victory_flag":"horizon_blackbell_quenchline_broken","atlas_x":96},
	{"scenario_id":"blackbell-saltwake-foreclosure","faction_id":"faction_brasshollow","hero_id":"hero_brasshollow_harro_debtrune","army_id":"army_harro_grand_convergence_company","home_id":"blackbell_court_home","home_town_id":"town_blackbell_foundry","enemy_town_id":"blackbell_court_enemy_town","enemy_faction_id":"faction_veilmourn","relief_hook":"blackbell_relief","pressure_hook":"blackbell_pressure_hook","completion_hook":"blackbell_foreclosure_hook","completion_flag":"blackbell_saltwake_foreclosure","fronts":["blackbell_court_front_1","blackbell_court_front_2","blackbell_court_front_3"],"identity_placement":"blackbell_court_front_2","encounter_id":"encounter_horizon_court_pale_saltwake_board","signature_army_id":"army_horizon_court_pale_saltwake_board","objective_id":"horizon_pale_saltwake","objective_type":"signal_beacon","reward_key":"memory_salt","victory_flag":"horizon_pale_saltwake_broken","atlas_x":144},
	{"scenario_id":"pale-sounding-tidewrit-reckoning","faction_id":"faction_veilmourn","hero_id":"hero_veilmourn_orso_nightchart","army_id":"army_orso_grand_convergence_company","home_id":"pale_court_home","home_town_id":"town_pale_sounding_harbor","enemy_town_id":"pale_court_enemy_town","enemy_faction_id":"faction_embercourt","relief_hook":"pale_relief","pressure_hook":"pale_pressure_hook","completion_hook":"pale_reckoning_hook","completion_flag":"pale_sounding_tidewrit_reckoning","fronts":["pale_court_front_1","pale_court_front_2","pale_court_front_3"],"identity_placement":"pale_court_front_2","encounter_id":"encounter_horizon_court_rainwrit_tidewrit_assize","signature_army_id":"army_horizon_court_rainwrit_tidewrit_assize","objective_id":"horizon_rainwrit_tidewrit","objective_type":"cover_line","reward_key":"embergrain","victory_flag":"horizon_rainwrit_tidewrit_broken","atlas_x":192},
]

var _errors: Array[String] = []
var _rows: Array = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	ContentService.clear_cache()
	var view = MapViewScript.new()
	view.size = Vector2(1280, 720)
	add_child(view)
	await get_tree().process_frame
	for case_value in CASES:
		_validate_scenario(case_value, view)
	view.queue_free()
	await get_tree().process_frame
	var capture_path := "%s/horizon_courts_atlas_preview.png" % OUTPUT_DIR
	_expect(_write_atlas_preview(capture_path), "Could not write the Horizon court atlas preview.")
	_write_json("%s/report.json" % OUTPUT_DIR, {
		"ok": _errors.is_empty(),
		"scenario_count": CASES.size(),
		"battle_victory_count": _rows.reduce(func(total, row): return total + int(row.get("battle_victory_count", 0)), 0),
		"exact_identity_art_count": _rows.filter(func(row): return bool(row.get("exact_identity_art", false))).size(),
		"victory_count": _rows.filter(func(row): return bool(row.get("scenario_victory", false))).size(),
		"save_version": SessionStateStoreScript.SAVE_VERSION,
		"single_consolidated_smoke": true,
		"visual_capture": capture_path,
		"rows": _rows,
		"errors": _errors,
	})
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"scenario_count":5,"battle_victory_count":15,"exact_identity_art_count":5,"victory_count":5,"save_version":SessionStateStoreScript.SAVE_VERSION,"single_consolidated_smoke":true})])
	_finish()


func _validate_scenario(case: Dictionary, view: Control) -> void:
	var scenario_id := String(case.get("scenario_id", ""))
	var scenario := ContentService.get_scenario(scenario_id)
	var session: SessionStateStoreScript.SessionData = ScenarioFactory.create_session(scenario_id, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	_expect(session != null, "%s did not create a live skirmish session." % scenario_id)
	if session == null:
		return
	OverworldRules.normalize_overworld_state(session)
	var map_size: Dictionary = scenario.get("map_size", {})
	_expect(int(map_size.get("width", 0)) == 12 and int(map_size.get("height", 0)) == 8, "%s must remain a compact 12x8 court map." % scenario_id)
	_expect(String(scenario.get("player_faction_id", "")) == String(case.get("faction_id", "")) and String(session.hero_id) == String(case.get("hero_id", "")), "%s lost its player faction or lead hero." % scenario_id)
	_expect(String(scenario.get("player_army_id", "")) == String(case.get("army_id", "")), "%s lost its convergence starting company." % scenario_id)
	_expect(session.overworld.get("towns", []).size() == 2 and session.overworld.get("encounters", []).size() == 3, "%s must ship two courts and three authored battles." % scenario_id)
	_expect(scenario.get("resource_nodes", []).size() == 8 and session.overworld.get("resource_nodes", []).size() >= 8 and session.overworld.get("artifact_nodes", []).size() == 1, "%s lost its authored economy or artifact route." % scenario_id)
	_expect(String(_town(session, String(case.get("home_id", ""))).get("town_id", "")) == String(case.get("home_town_id", "")) and String(_town(session, String(case.get("home_id", ""))).get("owner", "")) == "player", "%s does not open with its formerly enemy-only Horizon court under player control." % scenario_id)
	_expect(String(_town(session, String(case.get("enemy_town_id", ""))).get("owner", "")) == "enemy", "%s rival court must begin hostile." % scenario_id)
	_validate_unique_placements(session, scenario_id)

	var original_day := session.day
	session.day = 5
	var hook_result := ScenarioScriptRulesScript.process_hooks(session)
	_expect(String(case.get("relief_hook", "")) in hook_result.get("fired_ids", []) and String(case.get("pressure_hook", "")) in hook_result.get("fired_ids", []), "%s did not fire its timed relief and unresolved-court pressure together." % scenario_id)
	var authority_after_hooks := session.to_dict()
	var repeated_hooks := ScenarioScriptRulesScript.process_hooks(session)
	_expect(repeated_hooks.get("fired_ids", []).is_empty() and session.to_dict() == authority_after_hooks, "%s repeated a one-time opening hook or mutated authority twice." % scenario_id)
	session.day = original_day

	var battle_victories := 0
	var exact_identity_art := false
	for placement_id_value in case.get("fronts", []):
		var placement_id := String(placement_id_value)
		var placement := _encounter(session, placement_id)
		_expect(not placement.is_empty(), "%s is missing placement %s." % [scenario_id, placement_id])
		if placement.is_empty():
			continue
		var encounter_id := String(placement.get("encounter_id", ""))
		var authority_before_battle := session.to_dict()
		var battle := BattleRules.create_battle_payload(session, placement)
		_expect(session.to_dict() == authority_before_battle and not battle.is_empty(), "%s battle materialization failed or mutated scenario authority." % placement_id)
		session.battle = battle
		for stack_value in session.battle.get("stacks", []):
			if stack_value is Dictionary and String(stack_value.get("side", "")) == "enemy":
				stack_value["total_health"] = 0
		var resolution: Dictionary = BattleRules.resolve_if_battle_ready(session)
		var live_victory := String(resolution.get("state", "")) == "victory" and session.battle.is_empty() and OverworldRules.is_encounter_resolved(session, placement)
		_expect(live_victory, "%s did not complete through live battle-victory finalization: %s" % [placement_id, JSON.stringify(resolution)])
		if live_victory:
			battle_victories += 1
		if placement_id == String(case.get("identity_placement", "")):
			exact_identity_art = _validate_signature_encounter(case, placement, encounter_id, view)

	ScenarioScriptRulesScript.process_hooks(session)
	var fired_hook_ids: Array = session.overworld.get(ScenarioScriptRulesScript.SCRIPT_STATE_KEY, {}).get("fired_hook_ids", [])
	_expect(String(case.get("completion_hook", "")) in fired_hook_ids and bool(session.flags.get(String(case.get("completion_flag", "")), false)), "%s did not fire and persist its one-time three-front completion hook." % scenario_id)
	var capture_message := OverworldRules.capture_town_by_placement(session, String(case.get("enemy_town_id", "")))
	_expect(capture_message != "" and String(_town(session, String(case.get("enemy_town_id", ""))).get("owner", "")) == "player", "%s rival court did not transfer through the live capture API." % scenario_id)
	var scenario_result: Dictionary = ScenarioRulesScript.evaluate_session(session)
	var scenario_victory := String(scenario_result.get("status", "")) == "victory" and String(session.scenario_status) == "victory"
	_expect(scenario_victory and _met_victory_objective_count(session, scenario_id) == 5, "%s did not satisfy all five authored victory objectives: %s" % [scenario_id, JSON.stringify(scenario_result)])
	var authority_before_save := session.to_dict()
	var restored := SessionStateStoreScript.SessionData.new()
	restored.from_dict(authority_before_save)
	_expect(restored.to_dict() == authority_before_save and bool(restored.flags.get(String(case.get("completion_flag", "")), false)), "%s authority did not round-trip exactly through save version %d." % [scenario_id, SessionStateStoreScript.SAVE_VERSION])
	_rows.append({"scenario_id":scenario_id,"battle_victory_count":battle_victories,"exact_identity_art":exact_identity_art,"scenario_victory":scenario_victory,"save_round_trip_exact":restored.to_dict() == authority_before_save})


func _validate_signature_encounter(case: Dictionary, placement: Dictionary, encounter_id: String, view: Control) -> bool:
	_expect(encounter_id == String(case.get("encounter_id", "")), "%s signature placement changed encounter identity." % encounter_id)
	var encounter := ContentService.get_encounter(encounter_id)
	var army := ContentService.get_army_group(String(case.get("signature_army_id", "")))
	var objective := _objective(encounter.get("field_objectives", []), String(case.get("objective_id", "")))
	_expect(String(encounter.get("enemy_group_id", "")) == String(case.get("signature_army_id", "")) and army.get("stacks", []).size() == 3, "%s lost its exact three-stack court company." % encounter_id)
	_expect(String(objective.get("type", "")) == String(case.get("objective_type", "")) and encounter.get("rewards", {}).has(String(case.get("reward_key", ""))) and String(case.get("victory_flag", "")) in encounter.get("victory_flags", []), "%s lost its distinct field objective, resource reward, or victory flag." % encounter_id)
	_expect(bool(SessionStateStoreScript.SessionData.new() != null), "SessionData construction failed.")
	var presentation: Dictionary = view.call("validation_encounter_presentation_payload", placement)
	var texture = view.call("_object_texture_for_asset", encounter_id)
	var exact: bool = String(presentation.get("identity_encounter_asset_id", "")) == encounter_id and String(presentation.get("identity_encounter_path", "")) == ATLAS_PATH and bool(presentation.get("uses_identity_encounter_sprite", false)) and texture is AtlasTexture and texture.region == Rect2(float(case.get("atlas_x", 0)), 0.0, 48.0, 48.0) and texture.atlas.get_size() == Vector2(240, 48)
	_expect(exact, "%s did not resolve its exact Horizon court atlas region: %s" % [encounter_id, JSON.stringify(presentation)])
	return exact


func _validate_unique_placements(session: SessionStateStoreScript.SessionData, scenario_id: String) -> void:
	var occupied := {}
	for bucket in ["towns", "resource_nodes", "artifact_nodes", "encounters"]:
		for value in session.overworld.get(bucket, []):
			if not (value is Dictionary):
				continue
			var key := "%d,%d" % [int(value.get("x", -1)), int(value.get("y", -1))]
			_expect(not occupied.has(key), "%s placement collision at %s between %s and %s." % [scenario_id, key, occupied.get(key, ""), value.get("placement_id", "")])
			occupied[key] = String(value.get("placement_id", ""))


func _met_victory_objective_count(session: SessionStateStoreScript.SessionData, scenario_id: String) -> int:
	var met := 0
	for value in ContentService.get_scenario(scenario_id).get("objectives", {}).get("victory", []):
		if value is Dictionary and ScenarioRulesScript.is_objective_met(session, String(value.get("id", "")), "victory"):
			met += 1
	return met


func _town(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	for value in session.overworld.get("towns", []):
		if value is Dictionary and String(value.get("placement_id", "")) == placement_id:
			return value
	return {}


func _encounter(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	for value in session.overworld.get("encounters", []):
		if value is Dictionary and String(value.get("placement_id", "")) == placement_id:
			return value
	return {}


func _objective(objectives: Variant, objective_id: String) -> Dictionary:
	for value in objectives if objectives is Array else []:
		if value is Dictionary and String(value.get("id", "")) == objective_id:
			return value
	return {}


func _write_atlas_preview(path: String) -> bool:
	var atlas := Image.load_from_file(ProjectSettings.globalize_path(ATLAS_PATH))
	if atlas.is_empty() or atlas.get_size() != Vector2i(240, 48) or FileAccess.get_sha256(ATLAS_PATH) != ATLAS_SHA256:
		return false
	atlas.resize(960, 192, Image.INTERPOLATE_NEAREST)
	return atlas.save_png(path) == OK


func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_error("Could not write %s." % path)
		return
	file.store_string(JSON.stringify(payload, "  ") + "\n")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_error(message)


func _error(message: String) -> void:
	_errors.append(message)
	push_error("%s %s" % [REPORT_ID, message])


func _finish() -> void:
	get_tree().quit(0 if _errors.is_empty() else 1)
