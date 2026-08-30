extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const ScenarioRulesScript = preload("res://scripts/core/ScenarioRules.gd")
const ScenarioScriptRulesScript = preload("res://scripts/core/ScenarioScriptRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "HORIZON_COMPACT_SIX_CITADELS_SMOKE"
const OUTPUT_DIR := "res://.artifacts/horizon_compact_six_citadels_smoke"
const SCENARIO_ID := "horizon-compact-six-citadels"
const ATLAS_PATH := "res://art/overworld/runtime/objects/encounters/horizon_compact/horizon_compact_atlas.png"
const ATLAS_SHA256 := "58c14c56f362855e88f218bdd85f0b6f8af9c775528561d0341d7ab356f999a8"
const EXPECTED_TOWN_IDS := [
	"horizon_rainwrit_town",
	"horizon_hollowreed_town",
	"horizon_meridian_town",
	"horizon_crownroot_town",
	"horizon_blackbell_town",
	"horizon_pale_town",
]
const HOSTILE_TOWN_IDS := [
	"horizon_hollowreed_town",
	"horizon_meridian_town",
	"horizon_crownroot_town",
	"horizon_blackbell_town",
	"horizon_pale_town",
]
const CASES := [
	{"placement_id":"horizon_rainwrit_gate","encounter_id":"encounter_horizon_rainwrit_charter_gate","army_id":"army_horizon_rainwrit_charter_gate","faction_id":"faction_embercourt","auxiliary_id":"unit_embercourt_beaconline_writguard","objective_id":"horizon_rainwrit_sluice_line","objective_type":"cover_line","reward_key":"embergrain","victory_flag":"horizon_rainwrit_gate_broken","combat_seed":33101,"atlas_x":0},
	{"placement_id":"horizon_hollowreed_palisade","encounter_id":"encounter_horizon_hollowreed_moonfang_palisade","army_id":"army_horizon_hollowreed_moonfang_palisade","faction_id":"faction_mireclaw","auxiliary_id":"unit_mireclaw_fenbell_chainstalkers","objective_id":"horizon_hollowreed_snare_pool","objective_type":"hazard_zone","reward_key":"peatwax","victory_flag":"horizon_hollowreed_palisade_broken","combat_seed":33102,"atlas_x":48},
	{"placement_id":"horizon_meridian_array","encounter_id":"encounter_horizon_meridian_choir_array","army_id":"army_horizon_meridian_choir_array","faction_id":"faction_sunvault","auxiliary_id":"unit_sunvault_zenith_lensbearers","objective_id":"horizon_meridian_sighting_ring","objective_type":"lane_battery","reward_key":"aetherglass","victory_flag":"horizon_meridian_array_broken","combat_seed":33103,"atlas_x":96},
	{"placement_id":"horizon_crownroot_ring","encounter_id":"encounter_horizon_crownroot_oathseed_ring","army_id":"army_horizon_crownroot_oathseed_ring","faction_id":"faction_thornwake","auxiliary_id":"unit_thornwake_canopy_rammers","objective_id":"horizon_crownroot_shelter_arch","objective_type":"obstruction_line","reward_key":"verdant_grafts","victory_flag":"horizon_crownroot_ring_broken","combat_seed":33104,"atlas_x":144},
	{"placement_id":"horizon_blackbell_gantry","encounter_id":"encounter_horizon_blackbell_verdict_gantry","army_id":"army_horizon_blackbell_verdict_gantry","faction_id":"faction_brasshollow","auxiliary_id":"unit_brasshollow_pressure_lancers","objective_id":"horizon_blackbell_judgment_rail","objective_type":"breach_point","reward_key":"brass_scrip","victory_flag":"horizon_blackbell_gantry_broken","combat_seed":33105,"atlas_x":192},
	{"placement_id":"horizon_pale_mooring","encounter_id":"encounter_horizon_pale_sounding_ghost_mooring","army_id":"army_horizon_pale_sounding_ghost_mooring","faction_id":"faction_veilmourn","auxiliary_id":"unit_veilmourn_wakeglass_navigators","objective_id":"horizon_pale_sounding_bell","objective_type":"signal_beacon","reward_key":"memory_salt","victory_flag":"horizon_pale_mooring_broken","combat_seed":33106,"atlas_x":240},
]

var _errors: Array[String] = []
var _rows: Array = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	ContentService.clear_cache()
	var session: SessionStateStoreScript.SessionData = ScenarioFactory.create_session(
		SCENARIO_ID,
		"hard",
		SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	)
	_expect(session != null, "Horizon Compact must create a hard skirmish session.")
	if session == null:
		_finish()
		return
	OverworldRules.normalize_overworld_state(session)
	_validate_layout(session)
	_validate_pressure_hooks(session)

	var view = MapViewScript.new()
	view.size = Vector2(1280, 720)
	add_child(view)
	await get_tree().process_frame
	for case_value in CASES:
		_validate_and_resolve_encounter(session, view, case_value)
	view.queue_free()
	await get_tree().process_frame

	ScenarioScriptRulesScript.process_hooks(session)
	var fired_hook_ids: Array = session.overworld.get(ScenarioScriptRulesScript.SCRIPT_STATE_KEY, {}).get("fired_hook_ids", [])
	_expect("horizon_compact_all_writs_convened" in fired_hook_ids, "Six battle flags did not fire the one-time Horizon Compact hook.")
	_expect(bool(session.flags.get("horizon_compact_convened", false)), "The completed battle circuit did not set horizon_compact_convened.")
	for placement_id in HOSTILE_TOWN_IDS:
		var message := OverworldRules.capture_town_by_placement(session, placement_id)
		_expect(message != "" and String(_town(session, placement_id).get("owner", "")) == "player", "%s did not transfer through the live town-capture API." % placement_id)
	var scenario_result: Dictionary = ScenarioRulesScript.evaluate_session(session)
	_expect(String(scenario_result.get("status", "")) == "victory" and String(session.scenario_status) == "victory", "The twelve authored objectives did not complete the skirmish: %s" % JSON.stringify(scenario_result))
	_expect(_met_victory_objective_count(session) == 12, "The completed compact must satisfy all twelve victory objectives.")

	var authority_before := session.to_dict()
	var restored := SessionStateStoreScript.SessionData.new()
	restored.from_dict(authority_before)
	_expect(restored.to_dict() == authority_before, "Completed Horizon Compact authority did not round-trip exactly through save version %d." % SessionStateStoreScript.SAVE_VERSION)
	_expect(bool(restored.flags.get("horizon_compact_convened", false)) and restored.overworld.get("resolved_encounters", []).size() >= 6, "Save/load lost compact progression authority.")
	var capture_path := "%s/horizon_compact_atlas_preview.png" % OUTPUT_DIR
	_expect(_write_atlas_preview(capture_path), "Could not write the Horizon Compact atlas preview.")
	_write_json("%s/report.json" % OUTPUT_DIR, {
		"ok": _errors.is_empty(),
		"scenario_id": SCENARIO_ID,
		"case_count": CASES.size(),
		"town_count": session.overworld.get("towns", []).size(),
		"encounter_count": session.overworld.get("encounters", []).size(),
		"resource_node_count": ContentService.get_scenario(SCENARIO_ID).get("resource_nodes", []).size(),
		"artifact_node_count": session.overworld.get("artifact_nodes", []).size(),
		"enemy_faction_count": session.overworld.get("enemy_states", []).size(),
		"battle_victory_count": _rows.size(),
		"exact_identity_art_count": _rows.filter(func(row): return bool(row.get("exact_identity_art", false))).size(),
		"victory_objective_count": _met_victory_objective_count(session),
		"save_version": SessionStateStoreScript.SAVE_VERSION,
		"save_round_trip_exact": restored.to_dict() == authority_before,
		"single_consolidated_smoke": true,
		"visual_capture": capture_path,
		"rows": _rows,
		"errors": _errors,
	})
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"case_count":6,"battle_victory_count":6,"exact_identity_art_count":6,"town_count":6,"victory_objective_count":12,"save_version":SessionStateStoreScript.SAVE_VERSION,"single_consolidated_smoke":true})])
	_finish()


func _validate_layout(session: SessionStateStoreScript.SessionData) -> void:
	var scenario := ContentService.get_scenario(SCENARIO_ID)
	var map_size: Dictionary = scenario.get("map_size", {})
	_expect(int(map_size.get("width", 0)) == 24 and int(map_size.get("height", 0)) == 16, "Horizon Compact map size must remain 24x16.")
	_expect(String(scenario.get("player_faction_id", "")) == "faction_embercourt" and String(session.hero_id) == "hero_embercourt_belis_rainledger", "Belis Rainledger must lead the Embercourt opening.")
	_expect(String(scenario.get("player_army_id", "")) == "army_belis_grand_convergence_company", "Horizon Compact lost Belis's five-stack starting company.")
	_expect(session.overworld.get("towns", []).size() == 6 and session.overworld.get("encounters", []).size() == 6, "Horizon Compact must ship six towns and six signature encounters.")
	_expect(scenario.get("resource_nodes", []).size() == 15 and session.overworld.get("resource_nodes", []).size() >= 15 and session.overworld.get("artifact_nodes", []).size() == 3, "Horizon Compact authored or runtime economy breadth changed.")
	_expect(scenario.get("enemy_factions", []).size() == 5, "Horizon Compact must retain five independent hostile factions.")
	var occupied := {}
	for bucket in ["towns", "resource_nodes", "artifact_nodes", "encounters"]:
		for placement_value in session.overworld.get(bucket, []):
			if not (placement_value is Dictionary):
				continue
			var key := "%d,%d" % [int(placement_value.get("x", -1)), int(placement_value.get("y", -1))]
			_expect(not occupied.has(key), "Placement collision at %s between %s and %s." % [key, occupied.get(key, ""), placement_value.get("placement_id", "")])
			occupied[key] = String(placement_value.get("placement_id", ""))
	for placement_id in EXPECTED_TOWN_IDS:
		_expect(not _town(session, placement_id).is_empty(), "%s is missing from the live board." % placement_id)
	_expect(String(_town(session, "horizon_rainwrit_town").get("owner", "")) == "player", "Rainwrit must be the sole player-owned opening citadel.")
	for placement_id in HOSTILE_TOWN_IDS:
		_expect(String(_town(session, placement_id).get("owner", "")) == "enemy", "%s must begin hostile." % placement_id)


func _validate_pressure_hooks(session: SessionStateStoreScript.SessionData) -> void:
	var day_before := session.day
	session.day = 7
	var result := ScenarioScriptRulesScript.process_hooks(session)
	_expect("horizon_compact_day_three_stores" in result.get("fired_ids", []) and "horizon_compact_day_four_relief" in result.get("fired_ids", []) and "horizon_compact_unbroken_pressure" in result.get("fired_ids", []), "Opening stores, relief, and five-front pressure did not fire through live scenario hooks.")
	var pressured_factions := 0
	for faction_id in ["faction_mireclaw", "faction_sunvault", "faction_thornwake", "faction_brasshollow", "faction_veilmourn"]:
		for state_value in session.overworld.get("enemy_states", []):
			if state_value is Dictionary and String(state_value.get("faction_id", "")) == faction_id and int(state_value.get("pressure", 0)) >= 1:
				pressured_factions += 1
	_expect(pressured_factions == 5, "Day-seven pressure did not reach all five hostile factions.")
	var authority_after := session.to_dict()
	var repeat := ScenarioScriptRulesScript.process_hooks(session)
	_expect(not ("horizon_compact_unbroken_pressure" in repeat.get("fired_ids", [])) and session.to_dict() == authority_after, "Opening hooks repeated or mutated authority twice.")
	session.day = day_before


func _validate_and_resolve_encounter(session: SessionStateStoreScript.SessionData, view: Control, case: Dictionary) -> void:
	var placement_id := String(case.get("placement_id", ""))
	var encounter_id := String(case.get("encounter_id", ""))
	var placement := _encounter(session, placement_id)
	var encounter := ContentService.get_encounter(encounter_id)
	var army := ContentService.get_army_group(String(case.get("army_id", "")))
	_expect(not placement.is_empty() and String(placement.get("encounter_id", "")) == encounter_id and int(placement.get("combat_seed", 0)) == int(case.get("combat_seed", 0)), "%s placement identity or deterministic seed changed." % placement_id)
	_expect(String(encounter.get("enemy_group_id", "")) == String(case.get("army_id", "")) and String(encounter.get("affiliation", "")) == String(case.get("faction_id", "")), "%s encounter faction or army link changed." % encounter_id)
	_expect(army.get("stacks", []).size() == 3 and _army_has_unit(army, String(case.get("auxiliary_id", ""))), "%s must retain its faction-correct three-stack company and signature auxiliary." % String(case.get("army_id", "")))
	var objective := _objective(encounter.get("field_objectives", []), String(case.get("objective_id", "")))
	_expect(String(objective.get("type", "")) == String(case.get("objective_type", "")), "%s lost its distinct field objective." % encounter_id)
	_expect(encounter.get("rewards", {}).has(String(case.get("reward_key", ""))) and String(case.get("victory_flag", "")) in encounter.get("victory_flags", []), "%s lost its faction resource reward or victory flag." % encounter_id)

	var authority_before := session.to_dict()
	var battle := BattleRules.create_battle_payload(session, placement)
	_expect(session.to_dict() == authority_before, "%s battle materialization mutated scenario authority." % encounter_id)
	_expect(not battle.is_empty() and String(battle.get("encounter_id", "")) == encounter_id and String(battle.get("enemy_army_id", "")) == String(case.get("army_id", "")), "%s did not construct its exact production battle." % encounter_id)
	_expect(_side_stack_count(battle, "enemy") == 3 and not _objective(battle.get(BattleRules.FIELD_OBJECTIVES_KEY, []), String(case.get("objective_id", ""))).is_empty(), "%s battle payload lost a stack or its field objective." % encounter_id)
	session.battle = battle
	for stack_value in session.battle.get("stacks", []):
		if stack_value is Dictionary and String(stack_value.get("side", "")) == "enemy":
			stack_value["total_health"] = 0
	var resolution: Dictionary = BattleRules.resolve_if_battle_ready(session)
	_expect(String(resolution.get("state", "")) == "victory" and session.battle.is_empty(), "%s did not complete through live battle-victory finalization: %s" % [encounter_id, JSON.stringify(resolution)])
	_expect(OverworldRules.is_encounter_resolved(session, placement) and bool(session.flags.get(String(case.get("victory_flag", "")), false)), "%s victory did not persist its resolved placement and authored flag." % encounter_id)

	var presentation: Dictionary = view.call("validation_encounter_presentation_payload", placement)
	var asset_id := encounter_id
	var texture = view.call("_object_texture_for_asset", asset_id)
	var exact_identity_art: bool = String(presentation.get("identity_encounter_asset_id", "")) == asset_id and String(presentation.get("identity_encounter_path", "")) == ATLAS_PATH and bool(presentation.get("uses_identity_encounter_sprite", false)) and texture is AtlasTexture and texture.region == Rect2(float(case.get("atlas_x", 0)), 0.0, 48.0, 48.0)
	_expect(exact_identity_art, "%s did not resolve its exact compact-atlas identity region: %s" % [encounter_id, JSON.stringify(presentation)])
	_rows.append({"placement_id":placement_id,"encounter_id":encounter_id,"army_id":String(case.get("army_id", "")),"objective_id":String(case.get("objective_id", "")),"objective_type":String(case.get("objective_type", "")),"battle_stack_count":3,"battle_victory":String(resolution.get("state", "")) == "victory","exact_identity_art":exact_identity_art,"atlas_x":int(case.get("atlas_x", 0))})


func _met_victory_objective_count(session: SessionStateStoreScript.SessionData) -> int:
	var met := 0
	for objective_value in ContentService.get_scenario(SCENARIO_ID).get("objectives", {}).get("victory", []):
		if objective_value is Dictionary and ScenarioRulesScript.is_objective_met(session, String(objective_value.get("id", "")), "victory"):
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


func _army_has_unit(army: Dictionary, unit_id: String) -> bool:
	for value in army.get("stacks", []):
		if value is Dictionary and String(value.get("unit_id", "")) == unit_id and int(value.get("count", 0)) > 0:
			return true
	return false


func _side_stack_count(battle: Dictionary, side: String) -> int:
	var count := 0
	for value in battle.get("stacks", []):
		if value is Dictionary and String(value.get("side", "")) == side:
			count += 1
	return count


func _write_atlas_preview(path: String) -> bool:
	var atlas := Image.load_from_file(ProjectSettings.globalize_path(ATLAS_PATH))
	if atlas.is_empty() or atlas.get_size() != Vector2i(288, 48) or FileAccess.get_sha256(ATLAS_PATH) != ATLAS_SHA256:
		return false
	atlas.resize(1152, 192, Image.INTERPOLATE_NEAREST)
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
