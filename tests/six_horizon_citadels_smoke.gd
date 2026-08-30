extends Node

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const MapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")

const REPORT_ID := "SIX_HORIZON_CITADELS_SMOKE"
const OUTPUT_DIR := "res://.artifacts/six_horizon_citadels_smoke"
const REPORT_PATH := OUTPUT_DIR + "/report.json"
const CONTACT_SHEET_PATH := OUTPUT_DIR + "/horizon_citadels_contact_sheet.png"
const SCENARIO_ID := "ninefold-confluence"
const ATLAS_PATH := "res://art/overworld/runtime/objects/towns/identity_atlases/horizon_citadels_atlas.png"
const CASES := [
	{"town_id":"town_rainwrit_bastion","faction_id":"faction_embercourt","placement_id":"ninefold_rainwrit_bastion","position":Vector2i(11,8),"owner":"player","role":"floodgate_levy_court","asset_id":"town_identity_rainwrit_bastion","atlas_region":Rect2(0,0,128,128),"objective_id":"hold_rainwrit_bastion"},
	{"town_id":"town_hollowreed_sanctuary","faction_id":"faction_mireclaw","placement_id":"ninefold_hollowreed_sanctuary","position":Vector2i(34,59),"owner":"enemy","role":"oathmire_sanctuary","asset_id":"town_identity_hollowreed_sanctuary","atlas_region":Rect2(128,0,128,128),"objective_id":"claim_hollowreed_sanctuary"},
	{"town_id":"town_meridian_choirhold","faction_id":"faction_sunvault","placement_id":"ninefold_meridian_choirhold","position":Vector2i(37,31),"owner":"enemy","role":"resonant_horizon_hold","asset_id":"town_identity_meridian_choirhold","atlas_region":Rect2(256,0,128,128),"objective_id":"claim_meridian_choirhold"},
	{"town_id":"town_crownroot_refuge","faction_id":"faction_thornwake","placement_id":"ninefold_crownroot_refuge","position":Vector2i(27,49),"owner":"enemy","role":"living_recovery_refuge","asset_id":"town_identity_crownroot_refuge","atlas_region":Rect2(384,0,128,128),"objective_id":"claim_crownroot_refuge"},
	{"town_id":"town_blackbell_foundry","faction_id":"faction_brasshollow","placement_id":"ninefold_blackbell_foundry","position":Vector2i(46,38),"owner":"enemy","role":"quenchbell_fortress","asset_id":"town_identity_blackbell_foundry","atlas_region":Rect2(512,0,128,128),"objective_id":"claim_blackbell_foundry"},
	{"town_id":"town_pale_sounding_harbor","faction_id":"faction_veilmourn","placement_id":"ninefold_pale_sounding_harbor","position":Vector2i(55,49),"owner":"enemy","role":"echo_chart_harbor","asset_id":"town_identity_pale_sounding_harbor","atlas_region":Rect2(640,0,128,128),"objective_id":"claim_pale_sounding_harbor"},
]

var _errors: Array = []
var _rows: Array = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	print("%s stage=start" % REPORT_ID)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var scenario: Dictionary = ContentService.get_scenario(SCENARIO_ID)
	_expect(not scenario.is_empty(), "Ninefold scenario is missing.")
	_expect(scenario.get("towns", []).size() == 12, "Ninefold must contain twelve live towns.")
	_expect(scenario.get("objectives", {}).get("victory", []).size() == 11, "Ninefold must expose eleven victory objectives.")
	_expect(scenario.get("objectives", {}).get("defeat", []).size() == 5, "Ninefold must expose five defeat objectives.")
	print("%s stage=create_session" % REPORT_ID)
	var session = ScenarioFactory.create_session(SCENARIO_ID, "hard", SessionState.LAUNCH_MODE_SKIRMISH)
	print("%s stage=session_ready" % REPORT_ID)
	_expect(session != null, "Ninefold live session could not be created.")
	if session == null:
		_finish(false)
		return
	var initial_enemy_count := 0
	for case in CASES:
		var placed := _town_by_placement(session, String(case.get("placement_id", "")))
		if String(placed.get("owner", "")) == "enemy":
			initial_enemy_count += 1
	_expect(initial_enemy_count == 5, "The five rival Horizon Citadels must remain visible to strategic AI as enemy towns.")
	session.day = 50
	session.overworld["resources"] = {
		"gold": 1000000, "wood": 10000, "ore": 10000, "aetherglass": 10000,
		"embergrain": 10000, "peatwax": 10000, "verdant_grafts": 10000,
		"brass_scrip": 10000, "memory_salt": 10000,
	}
	var art_manifest := _load_json("res://art/overworld/manifest.json")
	var view = MapViewScript.new()
	add_child(view)
	await get_tree().process_frame
	for case_value in CASES:
		print("%s stage=case town=%s" % [REPORT_ID, case_value.get("town_id", "")])
		_run_case(session, scenario, art_manifest, view, case_value)
	print("%s stage=cases_ready" % REPORT_ID)
	view.queue_free()
	var before_save: Dictionary = session.to_dict()
	var restored := SessionStateStoreScript.SessionData.new()
	restored.from_dict(before_save)
	var save_exact := restored.to_dict() == before_save and int(restored.save_version) == SessionStateStoreScript.SAVE_VERSION
	_expect(save_exact, "Save v9 round trip changed Horizon Citadel ownership, buildings, garrisons, or recruitment state.")
	print("%s stage=contact_sheet" % REPORT_ID)
	var contact_sheet_exact := _write_contact_sheet(ProjectSettings.globalize_path(CONTACT_SHEET_PATH))
	_expect(contact_sheet_exact, "Could not write the six-town visual contact sheet.")
	_finish(_errors.is_empty(), {
		"case_count": _rows.size(),
		"build_execution_count": _rows.filter(func(row): return bool(row.get("build_ok", false))).size(),
		"recruit_execution_count": _rows.filter(func(row): return bool(row.get("recruit_ok", false))).size(),
		"exact_scenic_art_count": _rows.filter(func(row): return bool(row.get("scenic_exact", false))).size(),
		"exact_overworld_identity_count": _rows.filter(func(row): return bool(row.get("identity_exact", false))).size(),
		"initial_enemy_town_count": initial_enemy_count,
		"save_version": SessionStateStoreScript.SAVE_VERSION,
		"save_round_trip_exact": save_exact,
		"contact_sheet_path": CONTACT_SHEET_PATH,
		"single_consolidated_smoke": true,
		"rows": _rows,
	})

func _run_case(session, scenario: Dictionary, art_manifest: Dictionary, view: Node, case: Dictionary) -> void:
	var town_id := String(case.get("town_id", ""))
	var placement_id := String(case.get("placement_id", ""))
	var template: Dictionary = ContentService.get_town(town_id)
	var town: Dictionary = _town_by_placement(session, placement_id)
	var authored_town: Dictionary = _town_by_placement_value(scenario.get("towns", []), placement_id)
	var expected_position: Vector2i = case.get("position", Vector2i(-1, -1))
	var data_exact: bool = (
		not template.is_empty()
		and not town.is_empty()
		and String(template.get("faction_id", "")) == String(case.get("faction_id", ""))
		and String(template.get("strategic_role", "")) == String(case.get("role", ""))
		and String(template.get("content_status", "")) == "horizon_citadels_live"
		and template.get("buildable_building_ids", []).size() >= 20
		and template.get("garrison", []).size() == 3
		and Vector2i(int(authored_town.get("x", -1)), int(authored_town.get("y", -1))) == expected_position
		and String(authored_town.get("owner", "")) == String(case.get("owner", ""))
		and _objective_exists(scenario, String(case.get("objective_id", "")))
	)
	_expect(data_exact, "%s lost its exact authored template, placement, owner, or objective." % town_id)
	var scenic_path := String(template.get("scenic_backdrop_path", ""))
	var scenic_texture = load(scenic_path) if ResourceLoader.exists(scenic_path, "Texture2D") else null
	var scenic_exact: bool = scenic_texture is Texture2D and scenic_texture.get_size() == Vector2(1600, 900)
	_expect(scenic_exact, "%s scenic backdrop did not resolve at 1600x900." % town_id)
	var asset_id := String(case.get("asset_id", ""))
	var asset: Dictionary = art_manifest.get("object_assets", {}).get(asset_id, {})
	var identity_texture = view.call("_object_texture_for_asset", asset_id)
	var identity_exact: bool = (
		art_manifest.get("town_identity_sprites", {}).get(town_id, "") == asset_id
		and String(asset.get("path", "")) == ATLAS_PATH
		and _rect_from_array(asset.get("atlas_region", [])) == case.get("atlas_region", Rect2())
		and identity_texture is AtlasTexture
		and identity_texture.region == case.get("atlas_region", Rect2())
	)
	_expect(identity_exact, "%s overworld identity did not resolve its exact atlas crop." % town_id)
	town["owner"] = "player"
	town["last_build_day"] = 49
	var starter_unit_id := _starter_unit_id(template)
	var recruits: Dictionary = town.get("available_recruits", {}).duplicate(true)
	recruits[starter_unit_id] = max(2, int(recruits.get(starter_unit_id, 0)))
	town["available_recruits"] = recruits
	var visit: Dictionary = OverworldRules.set_active_town_visit(session, placement_id)
	session.game_state = "town"
	var build_catalog: Array = TownRules.get_build_catalog(session)
	var muster_catalog: Array = TownRules.get_muster_catalog(session)
	var build_row := _first_enabled(build_catalog)
	var build_result: Dictionary = TownRules.build_active_town(session, String(build_row.get("building_id", ""))) if not build_row.is_empty() else {}
	OverworldRules.set_active_town_visit(session, placement_id)
	var recruit_before := _army_unit_count(session, starter_unit_id)
	var recruit_result: Dictionary = TownRules.recruit_active_town(session, starter_unit_id, 1)
	var recruit_after := _army_unit_count(session, starter_unit_id)
	var current_town: Dictionary = _town_by_placement(session, placement_id)
	var build_ok: bool = bool(build_result.get("ok", false)) and String(build_row.get("building_id", "")) in current_town.get("built_buildings", [])
	var recruit_ok: bool = bool(recruit_result.get("ok", false)) and recruit_after == recruit_before + 1
	_expect(bool(visit.get("ok", false)) and build_catalog.size() >= 20 and muster_catalog.size() >= 3, "%s did not open its live build and muster management route." % town_id)
	_expect(build_ok, "%s could not execute one legal live construction order: %s" % [town_id, JSON.stringify(build_result)])
	_expect(recruit_ok, "%s could not execute one legal live recruitment order: %s" % [town_id, JSON.stringify(recruit_result)])
	_rows.append({
		"town_id": town_id, "faction_id": case.get("faction_id", ""), "placement_id": placement_id,
		"data_exact": data_exact, "scenic_exact": scenic_exact, "identity_exact": identity_exact,
		"build_catalog_count": build_catalog.size(), "muster_catalog_count": muster_catalog.size(),
		"built_building_id": build_row.get("building_id", ""), "build_ok": build_ok,
		"recruited_unit_id": starter_unit_id, "recruit_ok": recruit_ok,
	})

func _starter_unit_id(template: Dictionary) -> String:
	for building_id_value in template.get("starting_building_ids", []):
		var unit_id := String(ContentService.get_building(String(building_id_value)).get("unlock_unit_id", ""))
		if unit_id != "":
			return unit_id
	return ""

func _first_enabled(rows: Array) -> Dictionary:
	for row_value in rows:
		if row_value is Dictionary and not bool(row_value.get("disabled", true)):
			return row_value
	return {}

func _town_by_placement(session, placement_id: String) -> Dictionary:
	return _town_by_placement_value(session.overworld.get("towns", []), placement_id)

func _town_by_placement_value(rows: Variant, placement_id: String) -> Dictionary:
	if rows is Array:
		for row_value in rows:
			if row_value is Dictionary and String(row_value.get("placement_id", "")) == placement_id:
				return row_value
	return {}

func _objective_exists(scenario: Dictionary, objective_id: String) -> bool:
	for kind in ["victory", "defeat"]:
		for objective_value in scenario.get("objectives", {}).get(kind, []):
			if objective_value is Dictionary and String(objective_value.get("id", "")) == objective_id:
				return true
	return false

func _army_unit_count(session, unit_id: String) -> int:
	var total := 0
	for stack_value in session.overworld.get("army", {}).get("stacks", []):
		if stack_value is Dictionary and String(stack_value.get("unit_id", "")) == unit_id:
			total += int(stack_value.get("count", 0))
	return total

func _rect_from_array(value: Variant) -> Rect2:
	if value is Array and value.size() == 4:
		return Rect2(float(value[0]), float(value[1]), float(value[2]), float(value[3]))
	return Rect2()

func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text()) if file != null else null
	return parsed if parsed is Dictionary else {}

func _write_contact_sheet(path: String) -> bool:
	var cell := Vector2i(480, 270)
	var sheet := Image.create(cell.x * 3, cell.y * 2, false, Image.FORMAT_RGB8)
	for index in range(CASES.size()):
		var town := ContentService.get_town(String(CASES[index].get("town_id", "")))
		var source := Image.load_from_file(ProjectSettings.globalize_path(String(town.get("scenic_backdrop_path", ""))))
		if source.is_empty():
			return false
		source.resize(cell.x, cell.y, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(source, Rect2i(Vector2i.ZERO, cell), Vector2i((index % 3) * cell.x, (index / 3) * cell.y))
	return sheet.save_png(path) == OK

func _finish(ok: bool, extra: Dictionary = {}) -> void:
	var report := {"ok": ok, "errors": _errors}
	report.merge(extra, true)
	var file := FileAccess.open(ProjectSettings.globalize_path(REPORT_PATH), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  ") + "\n")
	if ok:
		print("%s %s" % [REPORT_ID, JSON.stringify(report)])
	else:
		push_error("%s failed: %s" % [REPORT_ID, JSON.stringify(report)])
	get_tree().quit(0 if ok else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
		push_error("%s %s" % [REPORT_ID, message])
