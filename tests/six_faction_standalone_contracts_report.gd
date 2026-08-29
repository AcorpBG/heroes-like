extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const BattleAutoResolveRulesScript = preload("res://scripts/core/BattleAutoResolveRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "SIX_FACTION_STANDALONE_CONTRACTS_REPORT"
const OUTPUT_DIR := "res://.artifacts/six_faction_standalone_contracts_report"
const ATLAS_PATH := "res://art/overworld/runtime/objects/encounters/standalone_contracts/standalone_contracts_atlas.png"
const CASES := [
	{"scenario_id":"tollglass-relief-run","hero_id":"hero_torren","faction_id":"faction_embercourt","placement_id":"tollglass_drowned_tally","encounter_id":"encounter_tollglass_drowned_tally","army_group_id":"army_tollglass_drowned_tally","rare_resource_id":"memory_salt","victory_flag":"tollglass_drowned_tally_broken","objective_id":"sunken_toll_chest","asset_id":"encounter_contract_tollglass_drowned_tally","region":Rect2(0,0,48,48),"combat_seed":25103},
	{"scenario_id":"muckscript-reliquary-hunt","hero_id":"hero_sable","faction_id":"faction_mireclaw","placement_id":"muckscript_prism_inquest","encounter_id":"encounter_muckscript_prism_inquest","army_group_id":"army_muckscript_prism_inquest","rare_resource_id":"aetherglass","victory_flag":"muckscript_prism_inquest_broken","objective_id":"prism_censor_reliquary","asset_id":"encounter_contract_muckscript_prism_inquest","region":Rect2(48,0,48,48),"combat_seed":25203},
	{"scenario_id":"mirrorstep-gauge-race","hero_id":"hero_varis","faction_id":"faction_sunvault","placement_id":"mirrorstep_redline_calibrators","encounter_id":"encounter_mirrorstep_redline_calibrators","army_group_id":"army_mirrorstep_redline_calibrators","rare_resource_id":"brass_scrip","victory_flag":"mirrorstep_redline_calibrators_broken","objective_id":"redline_calibration_gate","asset_id":"encounter_contract_mirrorstep_redline_calibrators","region":Rect2(96,0,48,48),"combat_seed":25303},
	{"scenario_id":"briarmarshal-fen-cordon","hero_id":"hero_thornwake_ardren_briarmarshal","faction_id":"faction_thornwake","placement_id":"briarmarshal_drum_cordon","encounter_id":"encounter_briarmarshal_drum_cordon","army_group_id":"army_briarmarshal_drum_cordon","rare_resource_id":"peatwax","victory_flag":"briarmarshal_drum_cordon_broken","objective_id":"briarbound_war_drum","asset_id":"encounter_contract_briarmarshal_drum_cordon","region":Rect2(144,0,48,48),"combat_seed":25403},
	{"scenario_id":"railhead-charter-seizure","hero_id":"hero_brasshollow_kuld_varn","faction_id":"faction_brasshollow","placement_id":"railhead_lockward_auditors","encounter_id":"encounter_railhead_lockward_auditors","army_group_id":"army_railhead_lockward_auditors","rare_resource_id":"embergrain","victory_flag":"railhead_lockward_auditors_broken","objective_id":"charter_lockgate_railhead","asset_id":"encounter_contract_railhead_lockward_auditors","region":Rect2(192,0,48,48),"combat_seed":25503},
	{"scenario_id":"mistcorsair-graftwake-raid","hero_id":"hero_veilmourn_cela_mistcorsair","faction_id":"faction_veilmourn","placement_id":"mistcorsair_graftwake_cordon","encounter_id":"encounter_mistcorsair_graftwake_cordon","army_group_id":"army_mistcorsair_graftwake_cordon","rare_resource_id":"verdant_grafts","victory_flag":"mistcorsair_graftwake_cordon_broken","objective_id":"graftwake_root_mooring","asset_id":"encounter_contract_mistcorsair_graftwake_cordon","region":Rect2(240,0,48,48),"combat_seed":25603},
]

var _errors: Array[String] = []
var _rows: Array = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var view = MapViewScript.new()
	view.size = Vector2(1280, 720)
	add_child(view)
	await get_tree().process_frame
	for case_value in CASES:
		await _validate_case(view, case_value)
	var report := {"ok":_errors.is_empty(),"case_count":CASES.size(),"atlas_path":ATLAS_PATH,"atlas_size":[288,48],"save_version":SessionStateStoreScript.SAVE_VERSION,"rows":_rows,"errors":_errors}
	_write_json("%s/report.json" % OUTPUT_DIR, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"case_count":CASES.size(),"save_version":SessionStateStoreScript.SAVE_VERSION})])
	view.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _errors.is_empty() else 1)

func _validate_case(view: Control, case: Dictionary) -> void:
	var scenario_id := String(case.get("scenario_id", ""))
	var placement_id := String(case.get("placement_id", ""))
	var encounter_id := String(case.get("encounter_id", ""))
	var scenario := ContentService.get_scenario(scenario_id)
	var selection: Dictionary = scenario.get("selection", {}) if scenario.get("selection", {}) is Dictionary else {}
	var availability: Dictionary = selection.get("availability", {}) if selection.get("availability", {}) is Dictionary else {}
	_expect(bool(availability.get("skirmish", false)) and not bool(availability.get("campaign", true)), "%s must remain skirmish-only." % scenario_id)
	_expect(String(scenario.get("hero_id", "")) == String(case.get("hero_id", "")) and String(scenario.get("player_faction_id", "")) == String(case.get("faction_id", "")), "%s lost its selected hero or faction." % scenario_id)
	_expect((scenario.get("towns", []) as Array).size() == 2 and (scenario.get("objectives", {}).get("victory", []) as Array).size() == 4, "%s lost its two-town four-objective contract." % scenario_id)

	var session = ScenarioFactory.create_session(scenario_id, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	var encounter := _encounter(session, placement_id)
	if encounter.is_empty():
		_error("%s is missing live placement %s." % [scenario_id, placement_id])
		return
	_expect(String(encounter.get("encounter_id", "")) == encounter_id and int(encounter.get("combat_seed", 0)) == int(case.get("combat_seed", -1)), "%s resolves the wrong encounter or seed." % placement_id)
	_expect(bool(encounter.get("prefer_identity_landmark", false)), "%s lost exact-landmark preference." % placement_id)

	var definition := ContentService.get_encounter(encounter_id)
	var army_group := ContentService.get_army_group(String(case.get("army_group_id", "")))
	_expect(String(definition.get("enemy_group_id", "")) == String(case.get("army_group_id", "")), "%s lost its army owner." % encounter_id)
	var objectives: Array = definition.get("field_objectives", []) if definition.get("field_objectives", []) is Array else []
	_expect(objectives.size() == 1 and String(objectives[0].get("id", "")) == String(case.get("objective_id", "")), "%s lost its tactical objective." % encounter_id)

	var tile := Vector2i(int(encounter.get("x", -1)), int(encounter.get("y", -1)))
	_set_active_hero_position(session, Vector2i(tile.x - 1, tile.y))
	OverworldRules._reveal_current_fog_sources(session)
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), tile)
	await get_tree().process_frame
	var identity: Dictionary = view.call("validation_encounter_presentation_payload", encounter)
	var texture = view.call("_object_texture_for_asset", String(case.get("asset_id", "")))
	var exact_art: bool = String(identity.get("identity_encounter_asset_id", "")) == String(case.get("asset_id", "")) and bool(identity.get("uses_identity_encounter_sprite", false)) and not bool(identity.get("uses_commander_sprite", true)) and texture is AtlasTexture and texture.region == case.get("region", Rect2()) and texture.atlas is Texture2D and texture.atlas.resource_path == ATLAS_PATH and texture.atlas.get_size() == Vector2(288, 48)
	_expect(exact_art, "%s exact landmark did not reach the live map renderer." % encounter_id)
	var capture_path := await _capture_if_requested(scenario_id)

	var first := _clone_session(session)
	var second := _clone_session(session)
	var resources_before := _resource_snapshot(first)
	var battle := BattleRulesScript.create_battle_payload(first, _encounter(first, placement_id))
	var mirrored_battle := BattleRulesScript.create_battle_payload(second, _encounter(second, placement_id))
	_expect(not battle.is_empty() and not mirrored_battle.is_empty(), "%s did not construct a production battle." % encounter_id)
	if battle.is_empty() or mirrored_battle.is_empty():
		return
	_expect(_enemy_counts(battle) == _army_counts(army_group), "%s battle stacks diverged from its authored group." % encounter_id)
	first.battle = battle
	second.battle = mirrored_battle
	first.game_state = "battle"
	second.game_state = "battle"
	first.battle[BattleRulesScript.PRESENTATION_SPEED_KEY] = BattleRulesScript.PRESENTATION_SPEED_INSTANT
	second.battle[BattleRulesScript.PRESENTATION_SPEED_KEY] = BattleRulesScript.PRESENTATION_SPEED_INSTANT
	var first_result: Dictionary = BattleAutoResolveRulesScript.resolve_active_battle(first)
	var second_result: Dictionary = BattleAutoResolveRulesScript.resolve_active_battle(second)
	var deterministic := first_result == second_result and JSON.stringify(first.to_dict()) == JSON.stringify(second.to_dict())
	_expect(bool(first_result.get("completed", false)) and String(first_result.get("state", "")) == "victory", "%s did not resolve as a viable medium boss: %s" % [encounter_id, first_result])
	_expect(deterministic, "%s fixed-seed battle was non-deterministic." % encounter_id)
	if String(first_result.get("state", "")) != "victory":
		return
	var resources_after := _resource_snapshot(first)
	var rare_id := String(case.get("rare_resource_id", ""))
	var gold_delta := int(resources_after.get("gold", 0)) - int(resources_before.get("gold", 0))
	var rare_delta := int(resources_after.get(rare_id, 0)) - int(resources_before.get(rare_id, 0))
	_expect(gold_delta == 210 and rare_delta == 1, "%s reward delta changed: gold=%d %s=%d." % [encounter_id, gold_delta, rare_id, rare_delta])
	_expect(placement_id in first.overworld.get("resolved_encounters", []) and bool(first.flags.get(String(case.get("victory_flag", "")), false)), "%s did not persist resolution and victory state." % encounter_id)
	var restored := _clone_session(first)
	_expect(int(restored.save_version) == SessionStateStoreScript.SAVE_VERSION and restored.to_dict() == first.to_dict(), "%s did not round-trip through save version %d." % [encounter_id, SessionStateStoreScript.SAVE_VERSION])
	_rows.append({"scenario_id":scenario_id,"hero_id":String(case.get("hero_id", "")),"encounter_id":encounter_id,"army_group_id":String(case.get("army_group_id", "")),"field_objective_id":String(case.get("objective_id", "")),"capture_path":capture_path,"gold_delta":gold_delta,"rare_resource_delta":rare_delta,"deterministic":deterministic,"save_round_trip_exact":restored.to_dict() == first.to_dict()})

func _capture_if_requested(stem: String) -> String:
	var capture_dir := OS.get_environment("STANDALONE_CONTRACT_CAPTURE_DIR")
	if capture_dir == "":
		return ""
	await RenderingServer.frame_post_draw
	var absolute_dir := ProjectSettings.globalize_path(capture_dir)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var path := absolute_dir.path_join("%s.png" % stem)
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(path) != OK:
		_error("Could not save visual capture %s." % path)
		return ""
	return path

func _encounter(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	for value in session.overworld.get("encounters", []):
		if value is Dictionary and String(value.get("placement_id", "")) == placement_id:
			return value
	return {}

func _clone_session(source: SessionStateStoreScript.SessionData) -> SessionStateStoreScript.SessionData:
	var clone := SessionStateStoreScript.SessionData.new()
	clone.from_dict(source.to_dict())
	return clone

func _resource_snapshot(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var resources: Dictionary = session.overworld.get("resources", {}) if session.overworld.get("resources", {}) is Dictionary else {}
	return resources.duplicate(true)

func _set_active_hero_position(session: SessionStateStoreScript.SessionData, tile: Vector2i) -> void:
	var position := {"x":tile.x,"y":tile.y}
	session.overworld["hero_position"] = position.duplicate(true)
	var active_hero = session.overworld.get("hero", {})
	if active_hero is Dictionary:
		active_hero["position"] = position.duplicate(true)
		session.overworld["hero"] = active_hero
	var heroes = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		var hero = heroes[index]
		if hero is Dictionary and String(hero.get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			hero["position"] = position.duplicate(true)
			heroes[index] = hero
	session.overworld["player_heroes"] = heroes

func _army_counts(army: Dictionary) -> Dictionary:
	var counts := {}
	for stack in army.get("stacks", []):
		if stack is Dictionary:
			counts[String(stack.get("unit_id", ""))] = int(stack.get("count", 0))
	return counts

func _enemy_counts(battle: Dictionary) -> Dictionary:
	var counts := {}
	for stack in battle.get("stacks", []):
		if not (stack is Dictionary) or String(stack.get("side", "")) != "enemy":
			continue
		var unit_hp: int = max(1, int(stack.get("unit_hp", 1)))
		counts[String(stack.get("unit_id", ""))] = int(ceil(float(max(0, int(stack.get("total_health", 0)))) / float(unit_hp)))
	return counts

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_error(message)

func _error(message: String) -> void:
	_errors.append(message)
	push_error(message)

func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_error("Unable to write report %s." % path)
		return
	file.store_string(JSON.stringify(payload, "  "))
