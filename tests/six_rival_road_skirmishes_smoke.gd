extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const ScenarioRulesScript = preload("res://scripts/core/ScenarioRules.gd")
const ScenarioScriptRulesScript = preload("res://scripts/core/ScenarioScriptRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "SIX_RIVAL_ROAD_SKIRMISHES_SMOKE"
const OUTPUT_DIR := "res://.artifacts/six_rival_road_skirmishes_smoke"
const CASES := [
	{"scenario_id":"chainboom-graftwake-cordon","faction_id":"faction_mireclaw","hero_id":"hero_mireclaw_kessa_chainboom","army_id":"army_kessa_rival_road_company","home_id":"chainboom_home","enemy_town_id":"chainboom_enemy_town","enemy_faction_id":"faction_thornwake","relief_hook":"chainboom_relief","counterstroke_hook":"chainboom_counterstroke","pressure_hook":"chainboom_pressure_hook","completion_hook":"chainboom_road_hook","claim_hook":"chainboom_claim_recorded","completion_flag":"chainboom_graftwake_road_open","claim_flag":"chainboom_briarwheel_claim_recorded","spawned_front":{"placement_id":"chainboom_counterstroke_front","encounter_id":"encounter_graftbound_pilgrims"},"fronts":[{"placement_id":"chainboom_front_1","encounter_id":"encounter_graftroot_wardens"},{"placement_id":"chainboom_front_2","encounter_id":"encounter_mistcorsair_graftwake_cordon"},{"placement_id":"chainboom_front_3","encounter_id":"encounter_pollenhook_whistle_line"}]},
	{"scenario_id":"reedscript-redline-reckoning","faction_id":"faction_mireclaw","hero_id":"hero_mireclaw_pell_reedscript","army_id":"army_pell_rival_road_company","home_id":"reedscript_home","enemy_town_id":"reedscript_enemy_town","enemy_faction_id":"faction_brasshollow","relief_hook":"reedscript_relief","counterstroke_hook":"reedscript_counterstroke","pressure_hook":"reedscript_pressure_hook","completion_hook":"reedscript_reckoning_hook","claim_hook":"reedscript_claim_recorded","completion_flag":"reedscript_redline_recorded","claim_flag":"reedscript_blackbell_claim_recorded","spawned_front":{"placement_id":"reedscript_counterstroke_front","encounter_id":"encounter_mirrorstep_redline_calibrators"},"fronts":[{"placement_id":"reedscript_front_1","encounter_id":"encounter_orevein_exactors"},{"placement_id":"reedscript_front_2","encounter_id":"encounter_tallyspring_proving_rack"},{"placement_id":"reedscript_front_3","encounter_id":"encounter_redline_foreclosure"}]},
	{"scenario_id":"glassmarshal-fenbell-refraction","faction_id":"faction_sunvault","hero_id":"hero_sunvault_ilyr_glassmarshal","army_id":"army_ilyr_rival_road_company","home_id":"glassmarshal_home","enemy_town_id":"glassmarshal_enemy_town","enemy_faction_id":"faction_mireclaw","relief_hook":"glassmarshal_relief","counterstroke_hook":"glassmarshal_counterstroke","pressure_hook":"glassmarshal_pressure_hook","completion_hook":"glassmarshal_refraction_hook","claim_hook":"glassmarshal_claim_recorded","completion_flag":"glassmarshal_fenbell_refracted","claim_flag":"glassmarshal_nightglass_claim_recorded","spawned_front":{"placement_id":"glassmarshal_counterstroke_front","encounter_id":"encounter_drum_circle"},"fronts":[{"placement_id":"glassmarshal_front_1","encounter_id":"encounter_reedward_camp"},{"placement_id":"glassmarshal_front_2","encounter_id":"encounter_three_banner_fenbell_chainstalkers"},{"placement_id":"glassmarshal_front_3","encounter_id":"encounter_mirror_causeway"}]},
	{"scenario_id":"facetlane-last-sounding","faction_id":"faction_sunvault","hero_id":"hero_sunvault_renn_facetlane","army_id":"army_renn_rival_road_company","home_id":"facetlane_home","enemy_town_id":"facetlane_enemy_town","enemy_faction_id":"faction_veilmourn","relief_hook":"facetlane_relief","counterstroke_hook":"facetlane_counterstroke","pressure_hook":"facetlane_pressure_hook","completion_hook":"facetlane_sounding_hook","claim_hook":"facetlane_claim_recorded","completion_flag":"facetlane_last_sounding_marked","claim_flag":"facetlane_pale_claim_recorded","spawned_front":{"placement_id":"facetlane_counterstroke_front","encounter_id":"encounter_tollglass_drowned_tally"},"fronts":[{"placement_id":"facetlane_front_1","encounter_id":"encounter_bellwake_privateers"},{"placement_id":"facetlane_front_2","encounter_id":"encounter_gloamkeel_sounding_barricade"},{"placement_id":"facetlane_front_3","encounter_id":"encounter_drowned_bell_procession"}]},
	{"scenario_id":"thorncart-daybreak-tangle","faction_id":"faction_thornwake","hero_id":"hero_thornwake_halen_thorncart","army_id":"army_halen_rival_road_company","home_id":"thorncart_home","enemy_town_id":"thorncart_enemy_town","enemy_faction_id":"faction_sunvault","relief_hook":"thorncart_relief","counterstroke_hook":"thorncart_counterstroke","pressure_hook":"thorncart_pressure_hook","completion_hook":"thorncart_road_hook","claim_hook":"thorncart_claim_recorded","completion_flag":"thorncart_daybreak_road_grown","claim_flag":"thorncart_halo_claim_recorded","spawned_front":{"placement_id":"thorncart_counterstroke_front","encounter_id":"encounter_glasswing_sortie"},"fronts":[{"placement_id":"thorncart_front_1","encounter_id":"encounter_relay_pickets"},{"placement_id":"thorncart_front_2","encounter_id":"encounter_daynote_refraction_bench"},{"placement_id":"thorncart_front_3","encounter_id":"encounter_daybreak_array"}]},
	{"scenario_id":"pollenglass-lockglass-appeal","faction_id":"faction_thornwake","hero_id":"hero_thornwake_osmund_pollenglass","army_id":"army_osmund_rival_road_company","home_id":"pollenglass_home","enemy_town_id":"pollenglass_enemy_town","enemy_faction_id":"faction_embercourt","relief_hook":"pollenglass_relief","counterstroke_hook":"pollenglass_counterstroke","pressure_hook":"pollenglass_pressure_hook","completion_hook":"pollenglass_appeal_hook","claim_hook":"pollenglass_claim_recorded","completion_flag":"pollenglass_lockglass_appeal_lodged","claim_flag":"pollenglass_rainwrit_claim_recorded","spawned_front":{"placement_id":"pollenglass_counterstroke_front","encounter_id":"encounter_charter_guard"},"fronts":[{"placement_id":"pollenglass_front_1","encounter_id":"encounter_archive_wardens"},{"placement_id":"pollenglass_front_2","encounter_id":"encounter_lockglass_citation_field"},{"placement_id":"pollenglass_front_3","encounter_id":"encounter_charter_bastion_reserve"}]},
]

var _errors: Array[String] = []
var _rows: Array = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	ContentService.clear_cache()
	_validate_catalog_breadth()
	var view = MapViewScript.new()
	view.size = Vector2(1280, 720)
	add_child(view)
	await get_tree().process_frame
	for case_value in CASES:
		_validate_scenario(case_value, view)
	view.queue_free()
	await get_tree().process_frame
	var report := {
		"ok": _errors.is_empty(),
		"scenario_count": CASES.size(),
		"battle_victory_count": _rows.reduce(func(total, row): return total + int(row.get("battle_victory_count", 0)), 0),
		"exact_encounter_art_count": _rows.reduce(func(total, row): return total + int(row.get("exact_encounter_art_count", 0)), 0),
		"scenario_victory_count": _rows.filter(func(row): return bool(row.get("scenario_victory", false))).size(),
		"save_version": SessionStateStoreScript.SAVE_VERSION,
		"single_consolidated_smoke": true,
		"rows": _rows,
		"errors": _errors,
	}
	_write_json("%s/report.json" % OUTPUT_DIR, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"scenario_count":6,"battle_victory_count":24,"exact_encounter_art_count":24,"scenario_victory_count":6,"save_version":SessionStateStoreScript.SAVE_VERSION,"single_consolidated_smoke":true})])
	get_tree().quit(0 if _errors.is_empty() else 1)


func _validate_catalog_breadth() -> void:
	var scenario_ids := ContentService.get_content_ids(ContentService.SCENARIOS_PATH)
	_expect(scenario_ids.size() == 99, "Authored scenario catalog must contain 99 player-facing maps.")
	var skirmish_only := 0
	var faction_counts := {}
	var placed_encounter_ids := {}
	for scenario_id_value in scenario_ids:
		var scenario := ContentService.get_scenario(String(scenario_id_value))
		var availability: Dictionary = scenario.get("selection", {}).get("availability", {})
		if bool(availability.get("skirmish", false)) and not bool(availability.get("campaign", false)):
			skirmish_only += 1
			var faction_id := String(scenario.get("player_faction_id", ""))
			faction_counts[faction_id] = int(faction_counts.get(faction_id, 0)) + 1
		for placement_value in scenario.get("encounters", []):
			if placement_value is Dictionary:
				placed_encounter_ids[String(placement_value.get("encounter_id", ""))] = true
	_expect(skirmish_only == 21, "Skirmish-only catalog must rise from fifteen to twenty-one maps.")
	for faction_id in ["faction_mireclaw", "faction_sunvault", "faction_thornwake"]:
		_expect(int(faction_counts.get(faction_id, 0)) == 3, "%s must own three skirmish-only maps." % faction_id)
	_expect(placed_encounter_ids.has("encounter_mistcorsair_graftwake_cordon") and placed_encounter_ids.has("encounter_three_banner_fenbell_chainstalkers"), "Both formerly stranded non-systemic encounter identities must enter live scenario flow.")


func _validate_scenario(case: Dictionary, view: Control) -> void:
	var scenario_id := String(case.get("scenario_id", ""))
	var scenario := ContentService.get_scenario(scenario_id)
	var session: SessionStateStoreScript.SessionData = ScenarioFactory.create_session(scenario_id, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	_expect(session != null, "%s did not create a live skirmish session." % scenario_id)
	if session == null:
		return
	OverworldRules.normalize_overworld_state(session)
	var availability: Dictionary = scenario.get("selection", {}).get("availability", {})
	var map_size: Dictionary = scenario.get("map_size", {})
	var player_army := ContentService.get_army_group(String(case.get("army_id", "")))
	_expect(bool(availability.get("skirmish", false)) and not bool(availability.get("campaign", false)), "%s must remain visible only in the skirmish selector." % scenario_id)
	_expect(int(map_size.get("width", 0)) == 12 and int(map_size.get("height", 0)) == 8, "%s must remain a compact 12x8 rival-road map." % scenario_id)
	_expect(String(scenario.get("player_faction_id", "")) == String(case.get("faction_id", "")) and String(session.hero_id) == String(case.get("hero_id", "")), "%s lost its exact faction or roster hero." % scenario_id)
	_expect(String(scenario.get("player_army_id", "")) == String(case.get("army_id", "")) and String(player_army.get("faction_id", "")) == String(case.get("faction_id", "")) and player_army.get("stacks", []).size() == 4, "%s lost its exact four-stack player company." % scenario_id)
	_expect(session.overworld.get("towns", []).size() == 2 and session.overworld.get("encounters", []).size() == 3, "%s must ship two towns and three direct battle fronts." % scenario_id)
	_expect(scenario.get("resource_nodes", []).size() == 8 and session.overworld.get("artifact_nodes", []).size() == 1, "%s lost its eight-site economy or artifact route." % scenario_id)
	_expect(String(_town(session, String(case.get("home_id", ""))).get("owner", "")) == "player" and String(_town(session, String(case.get("enemy_town_id", ""))).get("owner", "")) == "enemy", "%s town ownership contract changed." % scenario_id)
	_validate_unique_placements(session, scenario_id)

	session.day = 6
	var opening_hooks := ScenarioScriptRulesScript.process_hooks(session)
	_expect(String(case.get("relief_hook", "")) in opening_hooks.get("fired_ids", []) and String(case.get("counterstroke_hook", "")) in opening_hooks.get("fired_ids", []) and String(case.get("pressure_hook", "")) in opening_hooks.get("fired_ids", []), "%s did not fire its relief, scripted counterstroke, and unresolved-road pressure hooks together." % scenario_id)
	_expect(session.overworld.get("encounters", []).size() == 4, "%s did not materialize exactly one optional scripted counterstroke." % scenario_id)
	var authority_after_hooks := session.to_dict()
	var repeated_hooks := ScenarioScriptRulesScript.process_hooks(session)
	_expect(repeated_hooks.get("fired_ids", []).is_empty() and session.to_dict() == authority_after_hooks, "%s repeated a one-time opening hook." % scenario_id)
	OverworldRules.normalize_overworld_state(session)

	var battle_victories := 0
	var exact_art_count := 0
	var battle_fronts: Array = case.get("fronts", []).duplicate(true)
	battle_fronts.append(case.get("spawned_front", {}))
	for front_value in battle_fronts:
		var front: Dictionary = front_value
		var placement_id := String(front.get("placement_id", ""))
		var encounter_id := String(front.get("encounter_id", ""))
		var placement := _encounter(session, placement_id)
		var encounter := ContentService.get_encounter(encounter_id)
		var enemy_army := ContentService.get_army_group(String(encounter.get("enemy_group_id", "")))
		_expect(String(placement.get("encounter_id", "")) == encounter_id and String(enemy_army.get("faction_id", "")) == String(case.get("enemy_faction_id", "")), "%s lost its exact encounter or rival-faction army." % placement_id)
		var presentation: Dictionary = view.call("validation_encounter_presentation_payload", placement)
		var asset_id := String(presentation.get("identity_encounter_asset_id", ""))
		var texture = view.call("_object_texture_for_asset", asset_id)
		var exact_art := bool(presentation.get("uses_identity_encounter_sprite", false)) and asset_id != "" and String(presentation.get("identity_encounter_path", "")) != "" and texture is Texture2D
		_expect(exact_art, "%s did not resolve its already-shipped exact encounter landmark." % placement_id)
		if exact_art:
			exact_art_count += 1
		var authority_before_battle := session.to_dict()
		var battle := BattleRules.create_battle_payload(session, placement)
		_expect(session.to_dict() == authority_before_battle and not battle.is_empty() and String(battle.get("enemy_army_id", "")) == String(encounter.get("enemy_group_id", "")), "%s battle materialization failed or mutated authority." % placement_id)
		if battle.is_empty():
			continue
		session.battle = battle
		for stack_value in session.battle.get("stacks", []):
			if stack_value is Dictionary and String(stack_value.get("side", "")) == "enemy":
				stack_value["total_health"] = 0
		var resolution: Dictionary = BattleRules.resolve_if_battle_ready(session)
		var live_victory := String(resolution.get("state", "")) == "victory" and session.battle.is_empty() and OverworldRules.is_encounter_resolved(session, placement)
		_expect(live_victory, "%s did not finalize through live Battle rules." % placement_id)
		if live_victory:
			battle_victories += 1

	ScenarioScriptRulesScript.process_hooks(session)
	var fired_ids: Array = session.overworld.get(ScenarioScriptRulesScript.SCRIPT_STATE_KEY, {}).get("fired_hook_ids", [])
	_expect(String(case.get("completion_hook", "")) in fired_ids and bool(session.flags.get(String(case.get("completion_flag", "")), false)), "%s did not persist its three-front completion hook." % scenario_id)
	var capture_message := OverworldRules.capture_town_by_placement(session, String(case.get("enemy_town_id", "")))
	_expect(capture_message != "" and String(_town(session, String(case.get("enemy_town_id", ""))).get("owner", "")) == "player", "%s enemy town did not transfer through live capture authority." % scenario_id)
	var claim_hooks := ScenarioScriptRulesScript.process_hooks(session)
	_expect(String(case.get("claim_hook", "")) in claim_hooks.get("fired_ids", []) and bool(session.flags.get(String(case.get("claim_flag", "")), false)), "%s did not grant and persist its post-claim reward hook." % scenario_id)
	var scenario_result: Dictionary = ScenarioRulesScript.evaluate_session(session)
	var scenario_victory := String(scenario_result.get("status", "")) == "victory" and String(session.scenario_status) == "victory"
	_expect(scenario_victory and _met_victory_objective_count(session, scenario_id) == 5, "%s did not satisfy all five authored victory objectives." % scenario_id)
	var authority_before_save := session.to_dict()
	var restored := SessionStateStoreScript.SessionData.new()
	restored.from_dict(authority_before_save)
	var save_exact := restored.save_version == SessionStateStoreScript.SAVE_VERSION and restored.to_dict() == authority_before_save
	_expect(save_exact, "%s did not round-trip exactly through save version %d." % [scenario_id, SessionStateStoreScript.SAVE_VERSION])
	_rows.append({"scenario_id":scenario_id,"battle_victory_count":battle_victories,"exact_encounter_art_count":exact_art_count,"scenario_victory":scenario_victory,"save_round_trip_exact":save_exact})


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
