extends Node

const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const BattleAutoResolveRulesScript = preload("res://scripts/core/BattleAutoResolveRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "SIX_FACTION_ASCENDANT_COMPANIES_REPORT"
const OUTPUT_DIR := "res://.artifacts/six_faction_ascendant_companies_report"
const ATLAS_PATH := "res://art/overworld/runtime/objects/encounters/ascendant_companies/ascendant_companies_atlas.png"
const ASCENDANT_UNIT_IDS := [
	"unit_embercourt_beacon_lectors", "unit_embercourt_sluicefire_lindworms", "unit_embercourt_charter_colossus",
	"unit_mireclaw_sporewake_chanters", "unit_mireclaw_gorefen_rippers", "unit_mireclaw_drowned_antler_sovereign",
	"unit_sunvault_solar_array_striders", "unit_sunvault_aurora_ballistae", "unit_sunvault_daybreak_colossus",
	"unit_thornwake_stagknot_runners", "unit_thornwake_graft_matriarchs", "unit_thornwake_worldroot_bastion",
	"unit_brasshollow_debt_engine_exactors", "unit_brasshollow_crucible_crawlers", "unit_brasshollow_foundry_saint",
	"unit_veilmourn_obituary_scribes", "unit_veilmourn_mirrorkeel_reavers", "unit_veilmourn_fogbound_leviathan",
]
const CASES := [
	{"scenario_id":"tollbrand-blackwake-levy","hero_id":"hero_embercourt_helva_tollbrand","faction_id":"faction_embercourt","placement_id":"tollbrand_blackwake_levy","encounter_id":"encounter_helva_blackwake_levy","army_group_id":"army_helva_blackwake_levy","player_army_group_id":"army_helva_ascendant_company","rare_resource_id":"memory_salt","victory_flag":"tollbrand_blackwake_obituary_mooring_broken","objective_id":"blackwake_obituary_mooring","asset_id":"encounter_ascendant_blackwake_obituary_mooring","region":Rect2(0,0,48,48),"combat_seed":25903},
	{"scenario_id":"fenhook-daybreak-hunt","hero_id":"hero_tarn","faction_id":"faction_mireclaw","placement_id":"fenhook_daybreak_hunt","encounter_id":"encounter_tarn_daybreak_hunt","army_group_id":"army_tarn_daybreak_hunt","player_army_group_id":"army_tarn_ascendant_company","rare_resource_id":"aetherglass","victory_flag":"fenhook_daybreak_reed_prism_broken","objective_id":"daybreak_reed_prism","asset_id":"encounter_ascendant_daybreak_reed_prism","region":Rect2(48,0,48,48),"combat_seed":25913},
	{"scenario_id":"choirward-foundry-eclipse","hero_id":"hero_thalen","faction_id":"faction_sunvault","placement_id":"choirward_foundry_eclipse","encounter_id":"encounter_thalen_foundry_eclipse","army_group_id":"army_thalen_foundry_eclipse","player_army_group_id":"army_thalen_ascendant_company","rare_resource_id":"brass_scrip","victory_flag":"choirward_foundry_eclipse_gauge_broken","objective_id":"foundry_eclipse_gauge","asset_id":"encounter_ascendant_foundry_eclipse_gauge","region":Rect2(96,0,48,48),"combat_seed":25923},
	{"scenario_id":"greenbarrow-cinder-writ","hero_id":"hero_thornwake_merek_greenbarrow","faction_id":"faction_thornwake","placement_id":"greenbarrow_cinder_writ","encounter_id":"encounter_merek_cinder_writ","army_group_id":"army_merek_cinder_writ","player_army_group_id":"army_merek_ascendant_company","rare_resource_id":"embergrain","victory_flag":"greenbarrow_cinderwrit_graft_brazier_broken","objective_id":"cinderwrit_graft_brazier","asset_id":"encounter_ascendant_cinderwrit_graft_brazier","region":Rect2(144,0,48,48),"combat_seed":25933},
	{"scenario_id":"quench-gorefen-audit","hero_id":"hero_brasshollow_vellum_quench","faction_id":"faction_brasshollow","placement_id":"quench_gorefen_audit","encounter_id":"encounter_vellum_gorefen_audit","army_group_id":"army_vellum_gorefen_audit","player_army_group_id":"army_vellum_ascendant_company","rare_resource_id":"peatwax","victory_flag":"quench_gorefen_debt_totem_broken","objective_id":"gorefen_debt_totem","asset_id":"encounter_ascendant_gorefen_debt_totem","region":Rect2(192,0,48,48),"combat_seed":25943},
	{"scenario_id":"oriflag-worldroot-wake","hero_id":"hero_veilmourn_damar_oriflag","faction_id":"faction_veilmourn","placement_id":"oriflag_worldroot_wake","encounter_id":"encounter_damar_worldroot_wake","army_group_id":"army_damar_worldroot_wake","player_army_group_id":"army_damar_ascendant_company","rare_resource_id":"verdant_grafts","victory_flag":"oriflag_worldroot_wake_seal_broken","objective_id":"worldroot_wake_seal","asset_id":"encounter_ascendant_worldroot_wake_seal","region":Rect2(240,0,48,48),"combat_seed":25953},
]

var _errors: Array[String] = []
var _rows: Array = []
var _player_unit_ids: Dictionary = {}
var _enemy_unit_ids: Dictionary = {}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var view = MapViewScript.new()
	view.size = Vector2(1280, 720)
	add_child(view)
	await get_tree().process_frame
	for case_value in CASES:
		print("%s CASE_START %s" % [REPORT_ID, String(case_value.get("scenario_id", ""))])
		await _validate_case(view, case_value)
		print("%s CASE_DONE %s" % [REPORT_ID, String(case_value.get("scenario_id", ""))])
	_expect(_player_unit_ids.size() == ASCENDANT_UNIT_IDS.size() and _enemy_unit_ids.size() == ASCENDANT_UNIT_IDS.size(), "All eighteen ascendant units must appear in both player and enemy live battle contexts.")
	for unit_id in ASCENDANT_UNIT_IDS:
		_expect(_player_unit_ids.has(unit_id) and _enemy_unit_ids.has(unit_id), "%s did not reach both live battle sides." % unit_id)
	var report := {"ok":_errors.is_empty(),"case_count":CASES.size(),"unit_id_count":ASCENDANT_UNIT_IDS.size(),"atlas_path":ATLAS_PATH,"atlas_size":[288,48],"save_version":SessionStateStoreScript.SAVE_VERSION,"rows":_rows,"errors":_errors}
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
	print("%s STAGE scenario_loaded %s" % [REPORT_ID, scenario_id])
	var selection: Dictionary = scenario.get("selection", {}) if scenario.get("selection", {}) is Dictionary else {}
	var availability: Dictionary = selection.get("availability", {}) if selection.get("availability", {}) is Dictionary else {}
	_expect(bool(availability.get("skirmish", false)) and not bool(availability.get("campaign", true)), "%s must remain skirmish-only." % scenario_id)
	_expect(String(scenario.get("hero_id", "")) == String(case.get("hero_id", "")) and String(scenario.get("player_faction_id", "")) == String(case.get("faction_id", "")), "%s lost its selected hero or faction." % scenario_id)
	_expect((scenario.get("towns", []) as Array).size() == 2 and (scenario.get("objectives", {}).get("victory", []) as Array).size() == 4, "%s lost its two-town four-objective contract." % scenario_id)

	print("%s STAGE session_create_start %s" % [REPORT_ID, scenario_id])
	var session = ScenarioFactory.create_session(scenario_id, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	print("%s STAGE session_create_done %s" % [REPORT_ID, scenario_id])
	var encounter := _encounter(session, placement_id)
	if encounter.is_empty():
		_error("%s is missing live placement %s." % [scenario_id, placement_id])
		return
	_expect(String(encounter.get("encounter_id", "")) == encounter_id and int(encounter.get("combat_seed", 0)) == int(case.get("combat_seed", -1)), "%s resolves the wrong encounter or seed." % placement_id)
	_expect(bool(encounter.get("prefer_identity_landmark", false)), "%s lost exact-landmark preference." % placement_id)

	var definition := ContentService.get_encounter(encounter_id)
	var army_group := ContentService.get_army_group(String(case.get("army_group_id", "")))
	var player_army_group := ContentService.get_army_group(String(case.get("player_army_group_id", "")))
	_expect(String(definition.get("enemy_group_id", "")) == String(case.get("army_group_id", "")), "%s lost its army owner." % encounter_id)
	var objectives: Array = definition.get("field_objectives", []) if definition.get("field_objectives", []) is Array else []
	_expect(objectives.size() == 1 and String(objectives[0].get("id", "")) == String(case.get("objective_id", "")), "%s lost its tactical objective." % encounter_id)

	var tile := Vector2i(int(encounter.get("x", -1)), int(encounter.get("y", -1)))
	_set_active_hero_position(session, Vector2i(tile.x - 1, tile.y))
	OverworldRules._reveal_current_fog_sources(session)
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), tile)
	await get_tree().process_frame
	print("%s STAGE map_rendered %s" % [REPORT_ID, scenario_id])
	var identity: Dictionary = view.call("validation_encounter_presentation_payload", encounter)
	var texture = view.call("_object_texture_for_asset", String(case.get("asset_id", "")))
	var exact_art: bool = String(identity.get("identity_encounter_asset_id", "")) == String(case.get("asset_id", "")) and bool(identity.get("uses_identity_encounter_sprite", false)) and not bool(identity.get("uses_commander_sprite", true)) and texture is AtlasTexture and texture.region == case.get("region", Rect2()) and texture.atlas is Texture2D and texture.atlas.resource_path == ATLAS_PATH and texture.atlas.get_size() == Vector2(288, 48)
	_expect(exact_art, "%s exact landmark did not reach the live map renderer." % encounter_id)
	var capture_path := await _capture_if_requested(scenario_id)
	print("%s STAGE capture_done %s" % [REPORT_ID, scenario_id])

	var first := _clone_session(session)
	var second := _clone_session(session)
	var resources_before := _resource_snapshot(first)
	var battle := BattleRulesScript.create_battle_payload(first, _encounter(first, placement_id))
	var mirrored_battle := BattleRulesScript.create_battle_payload(second, _encounter(second, placement_id))
	_expect(not battle.is_empty() and not mirrored_battle.is_empty(), "%s did not construct a production battle." % encounter_id)
	if battle.is_empty() or mirrored_battle.is_empty():
		return
	_expect(_side_counts(battle, "enemy") == _army_counts(army_group), "%s enemy battle stacks diverged from its authored group." % encounter_id)
	_expect(_side_counts(battle, "player") == _army_counts(player_army_group), "%s player battle stacks diverged from its authored ascendant company." % scenario_id)
	_record_battle_units(battle)
	first.battle = battle
	second.battle = mirrored_battle
	first.game_state = "battle"
	second.game_state = "battle"
	first.battle[BattleRulesScript.PRESENTATION_SPEED_KEY] = BattleRulesScript.PRESENTATION_SPEED_INSTANT
	second.battle[BattleRulesScript.PRESENTATION_SPEED_KEY] = BattleRulesScript.PRESENTATION_SPEED_INSTANT
	print("%s STAGE battle_resolve_start %s" % [REPORT_ID, scenario_id])
	var first_result: Dictionary = BattleAutoResolveRulesScript.resolve_active_battle(first)
	var second_result: Dictionary = BattleAutoResolveRulesScript.resolve_active_battle(second)
	print("%s STAGE battle_resolve_done %s" % [REPORT_ID, scenario_id])
	var deterministic := first_result == second_result and JSON.stringify(first.to_dict()) == JSON.stringify(second.to_dict())
	_expect(bool(first_result.get("completed", false)) and String(first_result.get("state", "")) == "victory", "%s did not resolve as a viable medium boss: %s" % [encounter_id, first_result])
	_expect(deterministic, "%s fixed-seed battle was non-deterministic." % encounter_id)
	if String(first_result.get("state", "")) != "victory":
		return
	var resources_after := _resource_snapshot(first)
	var rare_id := String(case.get("rare_resource_id", ""))
	var gold_delta := int(resources_after.get("gold", 0)) - int(resources_before.get("gold", 0))
	var rare_delta := int(resources_after.get(rare_id, 0)) - int(resources_before.get(rare_id, 0))
	_expect(gold_delta == 240 and rare_delta == 1, "%s reward delta changed: gold=%d %s=%d." % [encounter_id, gold_delta, rare_id, rare_delta])
	_expect(placement_id in first.overworld.get("resolved_encounters", []) and bool(first.flags.get(String(case.get("victory_flag", "")), false)), "%s did not persist resolution and victory state." % encounter_id)
	var restored := _clone_session(first)
	_expect(int(restored.save_version) == SessionStateStoreScript.SAVE_VERSION and restored.to_dict() == first.to_dict(), "%s did not round-trip through save version %d." % [encounter_id, SessionStateStoreScript.SAVE_VERSION])
	_rows.append({"scenario_id":scenario_id,"hero_id":String(case.get("hero_id", "")),"encounter_id":encounter_id,"army_group_id":String(case.get("army_group_id", "")),"field_objective_id":String(case.get("objective_id", "")),"capture_path":capture_path,"gold_delta":gold_delta,"rare_resource_delta":rare_delta,"deterministic":deterministic,"save_round_trip_exact":restored.to_dict() == first.to_dict()})

func _capture_if_requested(stem: String) -> String:
	var capture_dir := OS.get_environment("ASCENDANT_COMPANY_CAPTURE_DIR")
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

func _side_counts(battle: Dictionary, side: String) -> Dictionary:
	var counts := {}
	for stack in battle.get("stacks", []):
		if not (stack is Dictionary) or String(stack.get("side", "")) != side:
			continue
		var unit_hp: int = max(1, int(stack.get("unit_hp", 1)))
		counts[String(stack.get("unit_id", ""))] = int(ceil(float(max(0, int(stack.get("total_health", 0)))) / float(unit_hp)))
	return counts

func _record_battle_units(battle: Dictionary) -> void:
	for stack in battle.get("stacks", []):
		if not (stack is Dictionary):
			continue
		var unit_id := String(stack.get("unit_id", ""))
		if String(stack.get("side", "")) == "player":
			_player_unit_ids[unit_id] = true
		elif String(stack.get("side", "")) == "enemy":
			_enemy_unit_ids[unit_id] = true

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
