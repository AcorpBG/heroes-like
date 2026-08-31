extends Node

const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const ScenarioRulesScript = preload("res://scripts/core/ScenarioRules.gd")
const ScenarioScriptRulesScript = preload("res://scripts/core/ScenarioScriptRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")

const REPORT_ID := "SIX_MARCHLAND_SEATS_SMOKE"
const OUTPUT_DIR := "res://.artifacts/six_marchland_seats_smoke"
const REPORT_PATH := OUTPUT_DIR + "/report.json"
const CONTACT_SHEET_PATH := OUTPUT_DIR + "/marchland_seats_contact_sheet.png"
const CASES := [
	{"prefix":"amberweir","scenario_id":"rainledger-amberweir-long-march","town_id":"town_amberweir_granary","hero_id":"hero_embercourt_belis_rainledger","faction_id":"faction_embercourt","rival_hero_id":"hero_orrik","growth_unit_id":"unit_embercourt_bargebow_crews","backdrop":"res://art/towns/runtime/backdrops/marchland_seats/town_amberweir_granary.png"},
	{"prefix":"moonbite","scenario_id":"votivejaw-moonbite-long-march","town_id":"town_moonbite_reedshrine","hero_id":"hero_mireclaw_nix_votivejaw","faction_id":"faction_mireclaw","rival_hero_id":"hero_sunvault_essa_daynote","growth_unit_id":"unit_mireclaw_mudglass_slingers","backdrop":"res://art/towns/runtime/backdrops/marchland_seats/town_moonbite_reedshrine.png"},
	{"prefix":"splitprism","scenario_id":"facetlane-splitprism-long-march","town_id":"town_splitprism_duelcourt","hero_id":"hero_sunvault_renn_facetlane","faction_id":"faction_sunvault","rival_hero_id":"hero_thornwake_veyra_seedseer","growth_unit_id":"unit_sunvault_mirror_duelists","backdrop":"res://art/towns/runtime/backdrops/marchland_seats/town_splitprism_duelcourt.png"},
	{"prefix":"woundroot","scenario_id":"greenbarrow-woundroot-long-march","town_id":"town_woundroot_hearthgrove","hero_id":"hero_thornwake_merek_greenbarrow","faction_id":"faction_thornwake","rival_hero_id":"hero_brasshollow_pava_ashmeter","growth_unit_id":"unit_thornwake_sporeglass_menders","backdrop":"res://art/towns/runtime/backdrops/marchland_seats/town_woundroot_hearthgrove.png"},
	{"prefix":"whitegauge","scenario_id":"gaugesavant-whitegauge-long-march","town_id":"town_whitegauge_calibration_yard","hero_id":"hero_brasshollow_lina_gaugesavant","faction_id":"faction_brasshollow","rival_hero_id":"hero_veilmourn_thir_obituaryink","growth_unit_id":"unit_brasshollow_gaugefire_arbalists","backdrop":"res://art/towns/runtime/backdrops/marchland_seats/town_whitegauge_calibration_yard.png"},
	{"prefix":"dreamwake","scenario_id":"wakeoracle-dreamwake-long-march","town_id":"town_dreamwake_oracle_harbor","hero_id":"hero_veilmourn_morwen_wakeoracle","faction_id":"faction_veilmourn","rival_hero_id":"hero_embercourt_helva_tollbrand","growth_unit_id":"unit_veilmourn_mourning_lanterns","backdrop":"res://art/towns/runtime/backdrops/marchland_seats/town_dreamwake_oracle_harbor.png"},
]

var _errors: Array[String] = []
var _rows: Array = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	ContentService.clear_cache()
	get_window().size = Vector2i(1280, 720)
	var view = MapViewScript.new()
	view.size = Vector2(1280, 720)
	add_child(view)
	await get_tree().process_frame
	for case_value in CASES:
		await _run_case(view, case_value)
	view.queue_free()
	await get_tree().process_frame
	var contact_sheet_exact := _write_contact_sheet(ProjectSettings.globalize_path(CONTACT_SHEET_PATH))
	_expect(contact_sheet_exact, "The six-backdrop Marchland Seats contact sheet could not be written.")
	var report := {
		"ok": _errors.is_empty(),
		"case_count": CASES.size(),
		"direct_battle_victory_count": _sum_rows("direct_battle_victory_count"),
		"counterstroke_battle_victory_count": _sum_rows("counterstroke_battle_victory_count"),
		"named_rival_count": _count_rows("named_rival_exact"),
		"town_build_count": _count_rows("town_build_ok"),
		"town_recruit_count": _count_rows("town_recruit_ok"),
		"exact_scenic_art_count": _count_rows("scenic_exact"),
		"scenario_victory_count": _count_rows("scenario_victory"),
		"save_round_trip_count": _count_rows("save_round_trip_exact"),
		"map_capture_count": _rows.filter(func(row): return String(row.get("capture_path", "")) != "").size(),
		"contact_sheet_path": CONTACT_SHEET_PATH,
		"save_version": SessionStateStoreScript.SAVE_VERSION,
		"single_consolidated_smoke": true,
		"rows": _rows,
		"errors": _errors,
	}
	_write_json(REPORT_PATH, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"case_count":6,"direct_battle_victory_count":24,"counterstroke_battle_victory_count":6,"named_rival_count":6,"town_build_count":6,"town_recruit_count":6,"exact_scenic_art_count":6,"scenario_victory_count":6,"save_round_trip_count":6,"map_capture_count":6,"single_consolidated_smoke":true})])
	get_tree().quit(0 if _errors.is_empty() else 1)


func _run_case(view: Control, case: Dictionary) -> void:
	var scenario_id := String(case.get("scenario_id", ""))
	var prefix := String(case.get("prefix", ""))
	var scenario: Dictionary = ContentService.get_scenario(scenario_id)
	var template: Dictionary = ContentService.get_town(String(case.get("town_id", "")))
	var session: SessionStateStoreScript.SessionData = ScenarioFactory.create_session(scenario_id, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	_expect(session != null, "%s did not create a live skirmish session." % scenario_id)
	if session == null:
		return
	OverworldRules.normalize_overworld_state(session)
	var exact_launch: bool = (
		String(session.hero_id) == String(case.get("hero_id", ""))
		and String(scenario.get("player_faction_id", "")) == String(case.get("faction_id", ""))
		and int(scenario.get("map_size", {}).get("width", 0)) == 18
		and int(scenario.get("map_size", {}).get("height", 0)) == 12
		and not bool(scenario.get("selection", {}).get("availability", {}).get("campaign", true))
		and bool(scenario.get("selection", {}).get("availability", {}).get("skirmish", false))
		and scenario.get("towns", []).size() == 2
		and scenario.get("encounters", []).size() == 4
		and scenario.get("resource_nodes", []).size() == 10
		and scenario.get("artifact_nodes", []).size() == 2
		and scenario.get("script_hooks", []).size() == 5
	)
	_expect(exact_launch, "%s lost its exact long-form scenario composition." % scenario_id)
	var home := _town(session, "%s_home" % prefix)
	_expect(String(home.get("town_id", "")) == String(case.get("town_id", "")) and String(home.get("owner", "")) == "player", "%s did not open at its exact new player town." % scenario_id)
	var scenic_path := String(case.get("backdrop", ""))
	var scenic_texture = load(scenic_path) if ResourceLoader.exists(scenic_path, "Texture2D") else null
	var scenic_exact: bool = scenic_texture is Texture2D and scenic_texture.get_size() == Vector2(1600, 900) and String(template.get("scenic_backdrop_path", "")) == scenic_path and String(template.get("content_status", "")) == "marchland_seat_live"
	_expect(scenic_exact, "%s did not resolve its exact 1600x900 scenic backdrop." % scenario_id)

	session.day = 3
	session.overworld["resources"] = {"gold":1000000,"wood":10000,"ore":10000,"aetherglass":10000,"embergrain":10000,"peatwax":10000,"verdant_grafts":10000,"brass_scrip":10000,"memory_salt":10000}
	home["last_build_day"] = 2
	var growth_unit_id := String(case.get("growth_unit_id", ""))
	var available: Dictionary = home.get("available_recruits", {}).duplicate(true)
	available[growth_unit_id] = maxi(4, int(available.get(growth_unit_id, 0)))
	home["available_recruits"] = available
	var visit := OverworldRules.set_active_town_visit(session, "%s_home" % prefix)
	session.game_state = "town"
	var build_row := _first_enabled(TownRules.get_build_catalog(session))
	var build_result := TownRules.build_active_town(session, String(build_row.get("building_id", ""))) if not build_row.is_empty() else {}
	OverworldRules.set_active_town_visit(session, "%s_home" % prefix)
	var before_recruit := _army_unit_count(session, growth_unit_id)
	var recruit_result := TownRules.recruit_active_town(session, growth_unit_id, 1)
	var town_build_ok := bool(visit.get("ok", false)) and bool(build_result.get("ok", false))
	var town_recruit_ok := bool(recruit_result.get("ok", false)) and _army_unit_count(session, growth_unit_id) == before_recruit + 1
	_expect(town_build_ok, "%s could not execute one legal production town build: %s" % [scenario_id, JSON.stringify(build_result)])
	_expect(town_recruit_ok, "%s could not execute one legal production town recruit: %s" % [scenario_id, JSON.stringify(recruit_result)])
	session.game_state = "overworld"

	var direct_battle_victory_count := 0
	var named_rival_exact := false
	for index in range(1, 5):
		var rival := String(case.get("rival_hero_id", "")) if index == 4 else ""
		var battle_result := _resolve_production_battle(session, "%s_front_%d" % [prefix, index], rival)
		if bool(battle_result.get("victory", false)):
			direct_battle_victory_count += 1
		if index == 4:
			named_rival_exact = bool(battle_result.get("named_rival_exact", false))
		if index == 2:
			var hook_result := ScenarioScriptRulesScript.process_hooks(session)
			_expect("%s_counterstroke" % prefix in hook_result.get("fired_ids", []) or not _encounter(session, "%s_counterstroke" % prefix).is_empty(), "%s did not trigger its exact central counterstroke." % scenario_id)
	_expect(direct_battle_victory_count == 4, "%s resolved %d of four direct production battles." % [scenario_id, direct_battle_victory_count])
	_expect(named_rival_exact, "%s did not hydrate its roster-backed final rival." % scenario_id)
	var counterstroke_result := _resolve_production_battle(session, "%s_counterstroke" % prefix)
	var counterstroke_battle_victory_count := 1 if bool(counterstroke_result.get("victory", false)) else 0
	_expect(counterstroke_battle_victory_count == 1, "%s did not resolve its triggered counterstroke." % scenario_id)
	var capture_message := OverworldRules.capture_town_by_placement(session, "%s_enemy_town" % prefix)
	_expect(capture_message != "" and String(_town(session, "%s_enemy_town" % prefix).get("owner", "")) == "player", "%s enemy seat did not transfer through live capture authority." % scenario_id)
	var outcome := ScenarioRulesScript.evaluate_session(session)
	var scenario_victory := String(outcome.get("status", "")) == "victory" and String(session.scenario_status) == "victory"
	_expect(scenario_victory, "%s did not complete its full six-objective chain: %s" % [scenario_id, JSON.stringify(outcome)])

	var hero_position: Dictionary = session.overworld.get("hero_position", {"x":2,"y":5})
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), Vector2i(int(hero_position.get("x", 2)), int(hero_position.get("y", 5))))
	await get_tree().process_frame
	var capture_path := await _capture_map(scenario_id)
	_expect(capture_path != "", "%s map capture failed." % scenario_id)
	var restored := _clone_session(session)
	var save_exact := int(restored.save_version) == SessionStateStoreScript.SAVE_VERSION and restored.to_dict() == session.to_dict()
	_expect(save_exact, "%s did not round-trip exactly through save version %d." % [scenario_id, SessionStateStoreScript.SAVE_VERSION])
	_rows.append({
		"scenario_id":scenario_id,"town_id":case.get("town_id", ""),"hero_id":case.get("hero_id", ""),"exact_launch":exact_launch,
		"direct_battle_victory_count":direct_battle_victory_count,"counterstroke_battle_victory_count":counterstroke_battle_victory_count,
		"named_rival_exact":named_rival_exact,"town_build_ok":town_build_ok,"town_recruit_ok":town_recruit_ok,"scenic_exact":scenic_exact,
		"scenario_victory":scenario_victory,"save_round_trip_exact":save_exact,"capture_path":capture_path,
	})


func _resolve_production_battle(session: SessionStateStoreScript.SessionData, placement_id: String, expected_rival_hero_id: String = "") -> Dictionary:
	var placement := _encounter(session, placement_id)
	if placement.is_empty():
		return {"victory":false,"named_rival_exact":false}
	var payload: Dictionary = BattleRulesScript.create_battle_payload(session, placement)
	if payload.is_empty():
		return {"victory":false,"named_rival_exact":false}
	var enemy_hero: Dictionary = payload.get("enemy_hero", {}) if payload.get("enemy_hero", {}) is Dictionary else {}
	var named_rival_exact := expected_rival_hero_id == "" or String(enemy_hero.get("roster_hero_id", "")) == expected_rival_hero_id
	session.battle = payload
	session.game_state = "battle"
	for index in range(session.battle.get("stacks", []).size()):
		var stack = session.battle.get("stacks", [])[index]
		if stack is Dictionary and String(stack.get("side", "")) == "enemy":
			stack["total_health"] = 0
			session.battle["stacks"][index] = stack
	var result := BattleRulesScript.resolve_if_battle_ready(session)
	return {"victory":String(result.get("state", "")) == "victory" and OverworldRules.is_encounter_resolved(session, placement),"named_rival_exact":named_rival_exact}


func _encounter(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	for value in session.overworld.get("encounters", []):
		if value is Dictionary and String(value.get("placement_id", "")) == placement_id:
			return value
	return {}


func _town(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	for value in session.overworld.get("towns", []):
		if value is Dictionary and String(value.get("placement_id", "")) == placement_id:
			return value
	return {}


func _first_enabled(rows: Array) -> Dictionary:
	for row_value in rows:
		if row_value is Dictionary and not bool(row_value.get("disabled", true)):
			return row_value
	return {}


func _army_unit_count(session: SessionStateStoreScript.SessionData, unit_id: String) -> int:
	var total := 0
	for stack_value in session.overworld.get("army", {}).get("stacks", []):
		if stack_value is Dictionary and String(stack_value.get("unit_id", "")) == unit_id:
			total += int(stack_value.get("count", 0))
	return total


func _clone_session(source: SessionStateStoreScript.SessionData) -> SessionStateStoreScript.SessionData:
	var clone := SessionStateStoreScript.SessionData.new()
	clone.from_dict(source.to_dict())
	return clone


func _capture_map(stem: String) -> String:
	var directory := OS.get_environment("SIX_MARCHLAND_SEATS_CAPTURE_DIR")
	if directory == "":
		return ""
	DirAccess.make_dir_recursive_absolute(directory)
	await get_tree().process_frame
	var path := directory.path_join("%s.png" % stem)
	var image := get_viewport().get_texture().get_image()
	return path if not image.is_empty() and image.save_png(path) == OK else ""


func _write_contact_sheet(path: String) -> bool:
	var cell := Vector2i(480, 270)
	var sheet := Image.create(cell.x * 3, cell.y * 2, false, Image.FORMAT_RGB8)
	for index in range(CASES.size()):
		var source := Image.load_from_file(ProjectSettings.globalize_path(String(CASES[index].get("backdrop", ""))))
		if source.is_empty():
			return false
		source.resize(cell.x, cell.y, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(source, Rect2i(Vector2i.ZERO, cell), Vector2i((index % 3) * cell.x, (index / 3) * cell.y))
	return sheet.save_png(path) == OK


func _sum_rows(key: String) -> int:
	return _rows.reduce(func(total,row): return total + int(row.get(key, 0)), 0)


func _count_rows(key: String) -> int:
	return _rows.filter(func(row): return bool(row.get(key, false))).size()


func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "  ") + "\n")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
		push_error("%s %s" % [REPORT_ID, message])
