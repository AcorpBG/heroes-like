extends Node

const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const BattleBoardViewScript = preload("res://scenes/battle/BattleBoardView.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "SIX_MARCHLAND_LOCAL_RETINUES_SMOKE"
const OUTPUT_DIR := "res://.artifacts/six_marchland_local_retinues_smoke"
const REPORT_PATH := OUTPUT_DIR + "/report.json"
const CONTACT_SHEET_PATH := OUTPUT_DIR + "/local_retinues_contact_sheet.png"
const STATUS := "marchland_local_retinue_live"
const BATCH_ID := "content-six-marchland-local-retinues-10184"
const CASES := [
	{"prefix":"amberweir","scenario_id":"rainledger-amberweir-long-march","town_id":"town_amberweir_granary","army_id":"army_amberweir_long_march_company","faction_id":"faction_embercourt","unit_id":"unit_embercourt_amberweir_lockpike_wardens","building_id":"building_embercourt_amberweir_sluiceguard_lock","role":"melee","ability_ids":["reach","brace"]},
	{"prefix":"moonbite","scenario_id":"votivejaw-moonbite-long-march","town_id":"town_moonbite_reedshrine","army_id":"army_moonbite_long_march_company","faction_id":"faction_mireclaw","unit_id":"unit_mireclaw_moonbite_votive_drummers","building_id":"building_mireclaw_moonbite_votive_drum_court","role":"ranged","ability_ids":["harry","volley"]},
	{"prefix":"splitprism","scenario_id":"facetlane-splitprism-long-march","town_id":"town_splitprism_duelcourt","army_id":"army_splitprism_long_march_company","faction_id":"faction_sunvault","unit_id":"unit_sunvault_splitprism_parallax_fencers","building_id":"building_sunvault_splitprism_parallax_duel_hall","role":"melee","ability_ids":["reach","backstab"]},
	{"prefix":"woundroot","scenario_id":"greenbarrow-woundroot-long-march","town_id":"town_woundroot_hearthgrove","army_id":"army_woundroot_long_march_company","faction_id":"faction_thornwake","unit_id":"unit_thornwake_woundroot_hearthseed_slingers","building_id":"building_thornwake_woundroot_hearthseed_nursery","role":"ranged","ability_ids":["harry","volley"]},
	{"prefix":"whitegauge","scenario_id":"gaugesavant-whitegauge-long-march","town_id":"town_whitegauge_calibration_yard","army_id":"army_whitegauge_long_march_company","faction_id":"faction_brasshollow","unit_id":"unit_brasshollow_whitegauge_datum_lancers","building_id":"building_brasshollow_whitegauge_datum_railhouse","role":"melee","ability_ids":["reach","brace"]},
	{"prefix":"dreamwake","scenario_id":"wakeoracle-dreamwake-long-march","town_id":"town_dreamwake_oracle_harbor","army_id":"army_dreamwake_long_march_company","faction_id":"faction_veilmourn","unit_id":"unit_veilmourn_dreamwake_tideglass_oracles","building_id":"building_veilmourn_dreamwake_tideglass_oratory","role":"ranged","ability_ids":["harry","volley"]},
]

var _errors: Array[String] = []
var _rows: Array = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	ContentService.clear_cache()
	_expect(ContentService.get_content_ids(ContentService.UNITS_PATH).size() == 160, "Current unit catalog must contain exactly 160 units.")
	_expect(ContentService.get_content_ids(ContentService.BUILDINGS_PATH).size() == 160, "Expanded building catalog must contain exactly 160 buildings.")
	for case_value in CASES:
		await _run_case(case_value)
	var contact_sheet_exact := _write_contact_sheet(ProjectSettings.globalize_path(CONTACT_SHEET_PATH))
	_expect(contact_sheet_exact, "The local-retinue unit and dwelling contact sheet could not be written.")
	var report := {
		"ok": _errors.is_empty(), "case_count": CASES.size(),
		"exclusive_route_count": _count_rows("exclusive_route"),
		"five_stack_company_count": _count_rows("five_stack_company"),
		"town_build_count": _count_rows("town_build"),
		"town_recruit_count": _count_rows("town_recruit"),
		"battle_victory_count": _count_rows("battle_victory"),
		"battle_art_count": _count_rows("battle_art"),
		"save_round_trip_count": _count_rows("save_round_trip"),
		"contact_sheet_path": CONTACT_SHEET_PATH,
		"save_version": SessionStateStoreScript.SAVE_VERSION,
		"single_consolidated_smoke": true, "rows": _rows, "errors": _errors,
	}
	_write_json(REPORT_PATH, report)
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok":true,"case_count":6,"exclusive_route_count":6,"five_stack_company_count":6,"town_build_count":6,"town_recruit_count":6,"battle_victory_count":6,"battle_art_count":6,"save_round_trip_count":6,"single_consolidated_smoke":true})])
	get_tree().quit(0 if _errors.is_empty() else 1)


func _run_case(case: Dictionary) -> void:
	var unit_id := String(case.get("unit_id", ""))
	var building_id := String(case.get("building_id", ""))
	var town_id := String(case.get("town_id", ""))
	var unit := ContentService.get_unit(unit_id)
	var building := ContentService.get_building(building_id)
	var town_template := ContentService.get_town(town_id)
	var exact_content: bool = (
		String(unit.get("faction_id", "")) == String(case.get("faction_id", ""))
		and String(unit.get("role", "")) == String(case.get("role", ""))
		and int(unit.get("tier", 0)) == 4 and int(unit.get("growth", 0)) == 3
		and String(unit.get("content_status", "")) == STATUS and String(unit.get("content_batch_id", "")) == BATCH_ID
		and _ability_ids(unit.get("abilities", [])) == case.get("ability_ids", [])
		and String(building.get("faction_id", "")) == String(case.get("faction_id", ""))
		and String(building.get("unlock_unit_id", "")) == unit_id
		and int(building.get("growth_bonus", {}).get(unit_id, 0)) == 3
		and String(building.get("content_status", "")) == STATUS
		and String(town_template.get("marchland_seat", {}).get("local_retinue_unit_id", "")) == unit_id
		and String(town_template.get("marchland_seat", {}).get("local_retinue_building_id", "")) == building_id
	)
	_expect(exact_content, "%s content contract changed." % unit_id)
	var exclusive_owners := []
	for candidate_town_id in ContentService.get_content_ids(ContentService.TOWNS_PATH):
		if building_id in ContentService.get_town(String(candidate_town_id)).get("buildable_building_ids", []):
			exclusive_owners.append(String(candidate_town_id))
	var exclusive_route := exclusive_owners == [town_id]
	_expect(exclusive_route, "%s leaked outside its exact town: %s" % [building_id, JSON.stringify(exclusive_owners)])
	_validate_art_contract(unit_id, building_id)

	var session: SessionStateStoreScript.SessionData = ScenarioFactory.create_session(String(case.get("scenario_id", "")), "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	_expect(session != null, "%s did not create a live skirmish session." % case.get("scenario_id", ""))
	if session == null:
		return
	OverworldRules.normalize_overworld_state(session)
	var company_stacks: Array = session.overworld.get("army", {}).get("stacks", [])
	var retinue_stack := _row_by_key(company_stacks, "unit_id", unit_id)
	var five_stack_company := company_stacks.size() == 5 and int(retinue_stack.get("count", 0)) == 4
	_expect(five_stack_company, "%s did not launch in its exact five-stack Marchland company." % unit_id)

	var home := _town(session, "%s_home" % String(case.get("prefix", "")))
	_prepare_town_for_build(session, home, building_id, unit_id)
	var build_action := _row_by_key(TownRules.get_build_catalog(session), "building_id", building_id)
	var build_result: Dictionary = TownRules.build_active_town(session, building_id)
	var built_home := _town(session, "%s_home" % String(case.get("prefix", "")))
	var town_build: bool = not build_action.is_empty() and not bool(build_action.get("disabled", true)) and bool(build_result.get("ok", false)) and building_id in built_home.get("built_buildings", []) and int(built_home.get("available_recruits", {}).get(unit_id, 0)) >= 3 and int(OverworldRules.town_weekly_growth(built_home, session).get(unit_id, 0)) >= 3
	_expect(town_build, "%s did not build and establish live growth: %s" % [building_id, JSON.stringify(build_result)])
	var before_recruit := _army_unit_count(session, unit_id)
	var recruit_result: Dictionary = TownRules.recruit_active_town(session, unit_id, 1)
	var town_recruit := bool(recruit_result.get("ok", false)) and _army_unit_count(session, unit_id) == before_recruit + 1
	_expect(town_recruit, "%s did not recruit through live town authority: %s" % [unit_id, JSON.stringify(recruit_result)])

	var placement := _encounter(session, "%s_front_1" % String(case.get("prefix", "")))
	var battle: Dictionary = BattleRulesScript.create_battle_payload(session, placement)
	var player_retinue := _battle_stack(battle.get("stacks", []), unit_id, "player")
	_expect(not battle.is_empty() and int(player_retinue.get("base_count", 0)) >= 4, "%s did not enter the production battle payload." % unit_id)
	session.battle = battle
	session.game_state = "battle"
	var battle_art := await _validate_battle_art(session, unit_id)
	for stack_value in session.battle.get("stacks", []):
		if stack_value is Dictionary and String(stack_value.get("side", "")) == "enemy":
			stack_value["total_health"] = 0
	var resolution: Dictionary = BattleRulesScript.resolve_if_battle_ready(session)
	var battle_victory := String(resolution.get("state", "")) == "victory" and OverworldRules.is_encounter_resolved(session, placement)
	_expect(battle_victory, "%s battle did not resolve through live victory authority." % unit_id)
	var authority := session.to_dict()
	var restored := SessionStateStoreScript.SessionData.new()
	restored.from_dict(authority.duplicate(true))
	var save_round_trip: bool = int(restored.save_version) == SessionStateStoreScript.SAVE_VERSION and restored.to_dict() == authority and building_id in _town(restored, "%s_home" % String(case.get("prefix", ""))).get("built_buildings", [])
	_expect(save_round_trip, "%s did not round-trip through save version %d." % [unit_id, SessionStateStoreScript.SAVE_VERSION])
	_rows.append({"unit_id":unit_id,"building_id":building_id,"exclusive_route":exclusive_route,"five_stack_company":five_stack_company,"town_build":town_build,"town_recruit":town_recruit,"battle_victory":battle_victory,"battle_art":battle_art,"save_round_trip":save_round_trip})
	SessionState.set_active_session(null)


func _validate_art_contract(unit_id: String, building_id: String) -> void:
	var paths := [
		"res://art/units/source/curated/%s.png" % unit_id,
		"res://art/units/portraits/%s.png" % unit_id,
		"res://art/units/battle_icons/%s.png" % unit_id,
		"res://art/units/battle_standees/%s.png" % unit_id,
		"res://art/units/overworld_icons/%s.png" % unit_id,
		"res://art/animation/runtime/units/%s.png" % unit_id,
		"res://art/towns/source/buildings/curated/%s.png" % building_id,
		"res://art/towns/runtime/buildings/%s.png" % building_id,
	]
	var sizes := [Vector2i(512,512),Vector2i(384,512),Vector2i(160,160),Vector2i(192,224),Vector2i(96,96),Vector2i(256,896),Vector2i(1254,1254),Vector2i(256,256)]
	for index in range(paths.size()):
		var image := _load_image(paths[index])
		_expect(image != null and image.get_size() == sizes[index], "%s art surface is missing or changed size." % paths[index])
	var unit_art := ContentService.get_unit_art(unit_id)
	var animation := ContentService.get_unit_animation(unit_id)
	var building_art := ContentService.get_building_art(building_id)
	_expect(String(unit_art.get("curated_source", "")) == paths[0] and String(animation.get("sprite_sheet", "")) == paths[5] and String(building_art.get("source_path", "")) == paths[6] and String(building_art.get("icon_path", "")) == paths[7], "%s manifest route changed." % unit_id)


func _prepare_town_for_build(session: SessionStateStoreScript.SessionData, town: Dictionary, building_id: String, unit_id: String) -> void:
	session.day = 30
	session.overworld["resources"] = {"gold":100000,"wood":1000,"ore":1000,"aetherglass":1000,"embergrain":1000,"peatwax":1000,"verdant_grafts":1000,"brass_scrip":1000,"memory_salt":1000}
	var built: Array = town.get("built_buildings", []).duplicate(true)
	for requirement_value in ContentService.get_building(building_id).get("requires", []):
		_append_building_requirements(built, String(requirement_value))
	built.erase(building_id)
	town["built_buildings"] = built
	town["last_build_day"] = 29
	var available: Dictionary = town.get("available_recruits", {}).duplicate(true)
	available.erase(unit_id)
	town["available_recruits"] = available
	var position := {"x":int(town.get("x",0)),"y":int(town.get("y",0))}
	session.overworld["hero_position"] = position.duplicate(true)
	var hero: Dictionary = session.overworld.get("hero", {})
	hero["x"] = position.x
	hero["y"] = position.y
	hero["position"] = position.duplicate(true)
	session.overworld["hero"] = hero
	var visit := OverworldRules.set_active_town_visit(session, String(town.get("placement_id", "")))
	_expect(bool(visit.get("ok", false)), "%s could not establish its live town visit." % building_id)


func _append_building_requirements(target: Array, building_id: String) -> void:
	if building_id == "" or building_id in target:
		return
	for requirement_value in ContentService.get_building(building_id).get("requires", []):
		_append_building_requirements(target, String(requirement_value))
	target.append(building_id)


func _validate_battle_art(session: SessionStateStoreScript.SessionData, unit_id: String) -> bool:
	SessionState.set_active_session(session)
	var board = BattleBoardViewScript.new()
	board.size = Vector2(1000, 620)
	add_child(board)
	board.set_battle_state(session)
	await get_tree().process_frame
	await get_tree().process_frame
	var summary: Dictionary = board.validation_unit_art_summary()
	var matches: Array = summary.get("stacks", []).filter(func(entry): return entry is Dictionary and String(entry.get("unit_id", "")) == unit_id and bool(entry.get("loaded", false)) and bool(entry.get("battle_standee_loaded", false)) and bool(entry.get("animation_loaded", false)))
	board.queue_free()
	await get_tree().process_frame
	var exact := not matches.is_empty()
	_expect(exact, "%s did not load its icon, standee, and animation on the live battle board." % unit_id)
	return exact


func _write_contact_sheet(path: String) -> bool:
	var cell := Vector2i(640, 360)
	var sheet := Image.create(cell.x * 3, cell.y * 2, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("18202b"))
	for index in range(CASES.size()):
		var unit_id := String(CASES[index].get("unit_id", ""))
		var building_id := String(CASES[index].get("building_id", ""))
		var portrait := _load_image("res://art/units/portraits/%s.png" % unit_id)
		var building := _load_image("res://art/towns/runtime/buildings/%s.png" % building_id)
		if portrait == null or building == null:
			return false
		portrait.resize(240, 320, Image.INTERPOLATE_LANCZOS)
		building.resize(288, 288, Image.INTERPOLATE_LANCZOS)
		var origin := Vector2i((index % 3) * cell.x, (index / 3) * cell.y)
		sheet.blend_rect(portrait, Rect2i(Vector2i.ZERO, portrait.get_size()), origin + Vector2i(42,20))
		sheet.blend_rect(building, Rect2i(Vector2i.ZERO, building.get_size()), origin + Vector2i(310,36))
	return sheet.save_png(path) == OK


func _town(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	return _row_by_key(session.overworld.get("towns", []), "placement_id", placement_id)


func _encounter(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	return _row_by_key(session.overworld.get("encounters", []), "placement_id", placement_id)


func _row_by_key(rows: Variant, key: String, expected: String) -> Dictionary:
	for row_value in rows if rows is Array else []:
		if row_value is Dictionary and String(row_value.get(key, "")) == expected:
			return row_value
	return {}


func _battle_stack(stacks: Variant, unit_id: String, side: String) -> Dictionary:
	for stack_value in stacks if stacks is Array else []:
		if stack_value is Dictionary and String(stack_value.get("unit_id", "")) == unit_id and String(stack_value.get("side", "")) == side:
			return stack_value
	return {}


func _ability_ids(abilities: Variant) -> Array:
	var ids := []
	for ability in abilities if abilities is Array else []:
		if ability is Dictionary:
			ids.append(String(ability.get("id", "")))
	return ids


func _army_unit_count(session: SessionStateStoreScript.SessionData, unit_id: String) -> int:
	var total := 0
	for stack_value in session.overworld.get("army", {}).get("stacks", []):
		if stack_value is Dictionary and String(stack_value.get("unit_id", "")) == unit_id:
			total += int(stack_value.get("count", 0))
	return total


func _load_image(path: String) -> Image:
	var image := Image.new()
	return image if image.load(ProjectSettings.globalize_path(path)) == OK else null


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
