extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const ScenarioRulesScript = preload("res://scripts/core/ScenarioRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "NAMED_RIVAL_BANNER_CHALLENGES_SMOKE"
const OUTPUT_DIR := "res://.artifacts/named_rival_banner_challenges_smoke"
const REPORT_PATH := OUTPUT_DIR + "/report.json"
const ATLAS_PATH := "res://art/overworld/runtime/objects/resource_sites/named_rival_banners_atlas.png"
const CASES := [
	{"scenario_id":"powderwrit-tollreaver-rival-banner-challenge","prefix":"tollmoon","player_hero":"hero_embercourt_maela_powderwrit","player_army":"army_tollmoon_challenge_company","rival_hero":"hero_orrik","rival_faction":"faction_mireclaw","rival_encounter":"encounter_tollmoon_named_rival_company","rival_army":"army_tollmoon_rival_company","site_id":"site_named_rival_tollmoon_claim_post","asset_id":"resource_site_named_rival_tollmoon_claim_post","region":Rect2(0,0,48,48)},
	{"scenario_id":"fenhook-facetlane-rival-banner-challenge","prefix":"facetline","player_hero":"hero_tarn","player_army":"army_facetline_challenge_company","rival_hero":"hero_sunvault_renn_facetlane","rival_faction":"faction_sunvault","rival_encounter":"encounter_facetline_named_rival_company","rival_army":"army_facetline_rival_company","site_id":"site_named_rival_facetline_duel_standard","asset_id":"resource_site_named_rival_facetline_duel_standard","region":Rect2(48,0,48,48)},
	{"scenario_id":"choirward-greenbarrow-rival-banner-challenge","prefix":"greenbarrow","player_hero":"hero_thalen","player_army":"army_greenbarrow_challenge_company","rival_hero":"hero_thornwake_merek_greenbarrow","rival_faction":"faction_thornwake","rival_encounter":"encounter_greenbarrow_named_rival_company","rival_army":"army_greenbarrow_rival_company","site_id":"site_named_rival_greenbarrow_recovery_mark","asset_id":"resource_site_named_rival_greenbarrow_recovery_mark","region":Rect2(96,0,48,48)},
	{"scenario_id":"pollenglass-bellfounder-rival-banner-challenge","prefix":"bellfounder","player_hero":"hero_thornwake_osmund_pollenglass","player_army":"army_bellfounder_challenge_company","rival_hero":"hero_brasshollow_oren_bellfounder","rival_faction":"faction_brasshollow","rival_encounter":"encounter_bellfounder_named_rival_company","rival_army":"army_bellfounder_rival_company","site_id":"site_named_rival_bellfounder_siege_gauge","asset_id":"resource_site_named_rival_bellfounder_siege_gauge","region":Rect2(144,0,48,48)},
	{"scenario_id":"heatpriest-vanehook-rival-banner-challenge","prefix":"vanehook","player_hero":"hero_brasshollow_odrik_heatpriest","player_army":"army_vanehook_challenge_company","rival_hero":"hero_veilmourn_ruln_vanehook","rival_faction":"faction_veilmourn","rival_encounter":"encounter_vanehook_named_rival_company","rival_army":"army_vanehook_rival_company","site_id":"site_named_rival_vanehook_wake_pennant","asset_id":"resource_site_named_rival_vanehook_wake_pennant","region":Rect2(192,0,48,48)},
	{"scenario_id":"oriflag-pikeward-rival-banner-challenge","prefix":"pikeward","player_hero":"hero_veilmourn_damar_oriflag","player_army":"army_pikeward_challenge_company","rival_hero":"hero_torren","rival_faction":"faction_embercourt","rival_encounter":"encounter_pikeward_named_rival_company","rival_army":"army_pikeward_rival_company","site_id":"site_named_rival_pikeward_charter_fork","asset_id":"resource_site_named_rival_pikeward_charter_fork","region":Rect2(240,0,48,48)},
]

var _errors: Array[String] = []
var _rows: Array = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	get_window().size = Vector2i(1280, 720)
	ContentService.clear_cache()
	var atlas := load(ATLAS_PATH) as Texture2D
	_expect(atlas != null and atlas.get_size() == Vector2(288, 48), "Named-rival banner atlas must remain 288x48.")
	var view = MapViewScript.new()
	view.size = Vector2(1280, 720)
	add_child(view)
	await get_tree().process_frame
	for case_value in CASES:
		await _run_case(view, case_value)
	var report := {
		"ok":_errors.is_empty(), "case_count":CASES.size(),
		"exact_player_identity_count":_count_rows("exact_player_identity"),
		"exact_banner_art_count":_count_rows("exact_banner_art"),
		"exact_rival_overworld_count":_count_rows("exact_rival_overworld"),
		"exact_rival_battle_count":_count_rows("exact_rival_battle"),
		"scoped_dependency_count":_count_rows("scoped_dependency"),
		"enemy_recapture_pending_count":_count_rows("enemy_recapture_pending"),
		"production_battle_count":_rows.reduce(func(total,row): return total + int(row.get("production_battle_count",0)),0),
		"production_claim_count":_rows.reduce(func(total,row): return total + int(row.get("production_claim_count",0)),0),
		"production_town_capture_count":_count_rows("production_town_capture"),
		"scenario_victory_count":_count_rows("scenario_victory"),
		"save_round_trip_count":_count_rows("save_round_trip_exact"),
		"save_version":SessionStateStoreScript.SAVE_VERSION,
		"single_consolidated_smoke":true, "rows":_rows, "errors":_errors,
	}
	_write_json(REPORT_PATH, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"case_count":6,"production_battle_count":18,"production_claim_count":18,"production_town_capture_count":6,"scenario_victory_count":6,"single_consolidated_smoke":true})])
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)


func _run_case(view: Control, case: Dictionary) -> void:
	var scenario_id := String(case.get("scenario_id", ""))
	var prefix := String(case.get("prefix", ""))
	var scenario := ContentService.get_scenario(scenario_id)
	var session = ScenarioFactory.create_session(scenario_id, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	_expect(session != null, "%s did not create a production skirmish session." % scenario_id)
	if session == null:
		return
	OverworldRules.normalize_overworld_state(session)
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	var company := ContentService.get_army_group(String(case.get("player_army", "")))
	var exact_player_identity: bool = String(scenario.get("hero_id", "")) == String(case.get("player_hero", "")) and String(scenario.get("player_army_id", "")) == String(case.get("player_army", "")) and String(hero.get("id", "")) == String(case.get("player_hero", "")) and company.get("stacks", []).size() == 5
	_expect(exact_player_identity, "%s lost its exact underused player hero or five-stack company." % scenario_id)

	var west_result := _resource_node_result(session, "%s_banner_west" % prefix)
	var west_node: Dictionary = west_result.get("node", {})
	var banner_asset := String(view.call("_resource_asset_id", west_node))
	var banner_texture = view.call("_object_texture_for_asset", banner_asset)
	var exact_banner_art: bool = String(west_node.get("site_id", "")) == String(case.get("site_id", "")) and banner_asset == String(case.get("asset_id", "")) and banner_texture is AtlasTexture and banner_texture.atlas.resource_path == ATLAS_PATH and banner_texture.region == case.get("region")
	_expect(exact_banner_art, "%s did not resolve its exact command-banner atlas region." % scenario_id)

	var final_placement := _encounter(session, "%s_named_rival" % prefix)
	var presentation: Dictionary = view.call("validation_encounter_presentation_payload", final_placement)
	var exact_rival_overworld: bool = String(presentation.get("hero_id", "")) == String(case.get("rival_hero", "")) and String(presentation.get("spawned_by_faction_id", "")) == String(case.get("rival_faction", "")) and bool(presentation.get("uses_commander_sprite", false)) and String(presentation.get("sprite_path", "")) != ""
	_expect(exact_rival_overworld, "%s did not render its exact roster rival as the hostile overworld actor: %s" % [scenario_id, JSON.stringify(presentation)])
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), Vector2i(int(final_placement.get("x",0)), int(final_placement.get("y",0))))
	await get_tree().process_frame
	var capture_path := await _capture_if_requested(scenario_id)

	var control_objective: Dictionary = scenario.get("objectives", {}).get("victory", [])[0]
	var control_objective_id := String(control_objective.get("id", ""))
	var scoped := ScenarioRulesScript.evaluate_session_for_event(session, {"event_type":"resource_site_control_changed","resource_site_placement_ids":["%s_banner_west" % prefix]})
	var scoped_profile: Dictionary = scoped.get("profile", {})
	var scoped_dependency: bool = String(scoped_profile.get("dependency_mode", "")) == "scoped" and int(scoped_profile.get("objectives_checked",0)) >= 1
	_expect(scoped_dependency, "%s did not expose scoped command-banner dependencies." % scenario_id)

	var production_battle_count := 0
	var production_claim_count := 0
	var exact_rival_battle: bool = false
	for suffix in ["west_company", "south_company", "named_rival"]:
		var placement_id := "%s_%s" % [prefix, suffix]
		var placement := _encounter(session, placement_id)
		var battle := BattleRulesScript.create_battle_payload(session, placement)
		_expect(not battle.is_empty(), "%s could not materialize through live Battle rules." % placement_id)
		if suffix == "named_rival" and not battle.is_empty():
			var enemy_hero: Dictionary = battle.get("enemy_hero", {}) if battle.get("enemy_hero", {}) is Dictionary else {}
			var rival_template := ContentService.get_hero(String(case.get("rival_hero", "")))
			var rival_army := ContentService.get_army_group(String(case.get("rival_army", "")))
			exact_rival_battle = String(placement.get("encounter_id", "")) == String(case.get("rival_encounter", "")) and String(battle.get("enemy_army_id", "")) == String(case.get("rival_army", "")) and rival_army.get("stacks", []).size() == 5 and String(enemy_hero.get("roster_hero_id", "")) == String(case.get("rival_hero", "")) and String(enemy_hero.get("name", "")) == String(rival_template.get("name", ""))
			_expect(exact_rival_battle, "%s did not hydrate the exact roster-backed rival and five-stack company." % placement_id)
		if _resolve_battle(session, placement, battle):
			production_battle_count += 1
		var banner_suffix: String = "west" if suffix == "west_company" else ("south" if suffix == "south_company" else "east")
		var claim := OverworldRules._collect_resource_node_result(session, _resource_node_result(session, "%s_banner_%s" % [prefix,banner_suffix]), true)
		if bool(claim.get("ok", false)):
			production_claim_count += 1
	_expect(production_battle_count == 3 and production_claim_count == 3, "%s did not resolve and claim all three live fronts." % scenario_id)

	var recapture_probe := _clone_session(session)
	_set_site_owner(recapture_probe, "%s_banner_west" % prefix, "enemy")
	var enemy_recapture_pending: bool = not ScenarioRulesScript.is_objective_met(recapture_probe, control_objective_id, "victory")
	_expect(enemy_recapture_pending, "%s ignored enemy recapture of a required command banner." % scenario_id)
	var capture_message := OverworldRules.capture_town_by_placement(session, "%s_rival_town" % prefix)
	var production_town_capture: bool = capture_message != "" and String(_town(session, "%s_rival_town" % prefix).get("owner", "")) == "player"
	_expect(production_town_capture, "%s rival town did not transfer through live capture authority." % scenario_id)
	var outcome: Dictionary = ScenarioRulesScript.evaluate_session(session)
	var scenario_victory: bool = String(outcome.get("status", "")) == "victory" and String(session.scenario_status) == "victory"
	_expect(scenario_victory, "%s did not win after the rival, banners, and town were secured: %s" % [scenario_id, JSON.stringify(outcome)])
	var restored := _clone_session(session)
	var save_exact: bool = restored.save_version == SessionStateStoreScript.SAVE_VERSION and restored.to_dict() == session.to_dict()
	_expect(save_exact, "%s did not round-trip exactly through save version %d." % [scenario_id, SessionStateStoreScript.SAVE_VERSION])
	_rows.append({"scenario_id":scenario_id,"exact_player_identity":exact_player_identity,"exact_banner_art":exact_banner_art,"exact_rival_overworld":exact_rival_overworld,"exact_rival_battle":exact_rival_battle,"scoped_dependency":scoped_dependency,"enemy_recapture_pending":enemy_recapture_pending,"production_battle_count":production_battle_count,"production_claim_count":production_claim_count,"production_town_capture":production_town_capture,"scenario_victory":scenario_victory,"save_round_trip_exact":save_exact,"capture_path":capture_path})


func _resolve_battle(session: SessionStateStoreScript.SessionData, placement: Dictionary, battle: Dictionary) -> bool:
	if battle.is_empty():
		return false
	session.battle = battle
	session.game_state = "battle"
	for stack_value in session.battle.get("stacks", []):
		if stack_value is Dictionary and String(stack_value.get("side", "")) == "enemy":
			stack_value["total_health"] = 0
	var result: Dictionary = BattleRulesScript.resolve_if_battle_ready(session)
	return String(result.get("state", "")) == "victory" and session.battle.is_empty() and OverworldRules.is_encounter_resolved(session, placement)


func _resource_node_result(session, placement_id: String) -> Dictionary:
	var nodes: Array = session.overworld.get("resource_nodes", [])
	for index in range(nodes.size()):
		if nodes[index] is Dictionary and String(nodes[index].get("placement_id", "")) == placement_id:
			return {"index":index,"node":nodes[index]}
	return {}


func _encounter(session, placement_id: String) -> Dictionary:
	for value in session.overworld.get("encounters", []):
		if value is Dictionary and String(value.get("placement_id", "")) == placement_id:
			return value
	return {}


func _town(session, placement_id: String) -> Dictionary:
	for value in session.overworld.get("towns", []):
		if value is Dictionary and String(value.get("placement_id", "")) == placement_id:
			return value
	return {}


func _set_site_owner(session, placement_id: String, owner: String) -> void:
	var nodes: Array = session.overworld.get("resource_nodes", [])
	for index in range(nodes.size()):
		if nodes[index] is Dictionary and String(nodes[index].get("placement_id", "")) == placement_id:
			nodes[index]["collected_by_faction_id"] = owner
			session.overworld["resource_nodes"] = nodes
			return


func _clone_session(session: SessionStateStoreScript.SessionData) -> SessionStateStoreScript.SessionData:
	var clone := SessionStateStoreScript.SessionData.new()
	clone.from_dict(session.to_dict())
	return clone


func _capture_if_requested(scenario_id: String) -> String:
	var directory := OS.get_environment("NAMED_RIVAL_CAPTURE_DIR")
	if directory == "":
		return ""
	DirAccess.make_dir_recursive_absolute(directory)
	await get_tree().process_frame
	var path := directory.path_join("%s.png" % scenario_id)
	var image := get_viewport().get_texture().get_image()
	return path if not image.is_empty() and image.save_png(path) == OK else ""


func _count_rows(key: String) -> int:
	return _rows.filter(func(row): return bool(row.get(key, false))).size()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
		push_error("%s %s" % [REPORT_ID, message])


func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "  "))
