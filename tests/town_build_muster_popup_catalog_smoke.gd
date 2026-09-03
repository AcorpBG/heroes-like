extends Node

const TownShellScene = preload("res://scenes/town/TownShell.tscn")
const EnemyTurnRulesScript = preload("res://scripts/core/EnemyTurnRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const CAPTURE_DIR := "res://.artifacts/town_build_muster_popup_catalog"
const AUXILIARY_CASES := [
	{"faction_id": "faction_embercourt", "scenario_id": "three-hearth-auxiliary-charter", "town_id": "town_cinderlock_bastion", "building_id": "building_embercourt_beaconline_charter_house", "unit_id": "unit_embercourt_beaconline_writguard"},
	{"faction_id": "faction_mireclaw", "scenario_id": "bogbound-oath", "town_id": "town_duskfen", "building_id": "building_mireclaw_fenbell_hunt_lodge", "unit_id": "unit_mireclaw_fenbell_chainstalkers"},
	{"faction_id": "faction_sunvault", "scenario_id": "three-banner-field-commission", "town_id": "town_dawnmirror_observatory", "building_id": "building_sunvault_zenith_relay_hall", "unit_id": "unit_sunvault_zenith_lensbearers"},
	{"faction_id": "faction_thornwake", "scenario_id": "rootway-graftmarch", "town_id": "town_briarwheel_enclave", "building_id": "building_thornwake_canopy_breach_grove", "unit_id": "unit_thornwake_canopy_rammers"},
	{"faction_id": "faction_brasshollow", "scenario_id": "ashen-clausemarch", "town_id": "town_cindercoil_foundry", "building_id": "building_brasshollow_redline_charter_bay", "unit_id": "unit_brasshollow_pressure_lancers"},
	{"faction_id": "faction_veilmourn", "scenario_id": "false-channel-pursuit", "town_id": "town_gloamwake_anchorage", "building_id": "building_veilmourn_wakeglass_chart_house", "unit_id": "unit_veilmourn_wakeglass_navigators"},
]

var _errors := []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
	var original_size := get_window().size
	var rows := []
	for viewport_size in VIEWPORT_SIZES:
		var row: Dictionary = await _run_case(viewport_size)
		rows.append(row)
		if not bool(row.get("ok", false)):
			_errors.append("%s popup case failed: %s" % [viewport_size, JSON.stringify(row)])
	var auxiliary_rows := []
	for case_value in AUXILIARY_CASES:
		var auxiliary_row: Dictionary = await _run_auxiliary_case(case_value)
		auxiliary_rows.append(auxiliary_row)
		if not bool(auxiliary_row.get("ok", false)):
			_errors.append("%s auxiliary charter case failed: %s" % [case_value.get("faction_id", ""), JSON.stringify(auxiliary_row)])
	get_window().size = original_size
	var report := {
		"ok": _errors.is_empty(),
		"schema": "town_build_muster_popup_catalog_smoke_v2",
		"rows": rows,
		"auxiliary_rows": auxiliary_rows,
		"errors": _errors,
	}
	if _errors.is_empty():
		print("TOWN_BUILD_MUSTER_POPUP_CATALOG_SMOKE %s" % JSON.stringify(report))
	else:
		push_error("TOWN_BUILD_MUSTER_POPUP_CATALOG_SMOKE failed: %s" % JSON.stringify(report))
	get_tree().quit(0 if _errors.is_empty() else 1)

func _run_case(viewport_size: Vector2i) -> Dictionary:
	get_window().size = viewport_size
	await get_tree().process_frame
	await get_tree().process_frame
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var town := _first_player_town(session)
	if town.is_empty():
		return {"ok": false, "failure": "player_town_missing"}
	_move_active_hero_to_town(session, town)
	var visit_result: Dictionary = OverworldRules.set_active_town_visit(session, String(town.get("placement_id", "")))
	if not bool(visit_result.get("ok", false)):
		return {"ok": false, "failure": "town_visit", "result": visit_result}
	SessionState.set_active_session(session)
	var shell = TownShellScene.instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var town_template := ContentService.get_town(String(town.get("town_id", "")))
	var expected_build_ids := _unique_strings(town_template.get("starting_building_ids", []), town_template.get("buildable_building_ids", []))
	var expected_unit_ids := _town_unit_ids(expected_build_ids)
	var initial_snapshot: Dictionary = shell.call("validation_snapshot")
	if bool(initial_snapshot.get("narrow_layout_active", false)) and not bool(initial_snapshot.get("narrow_orders_open", false)):
		shell.call("validation_toggle_narrow_town_orders")
		await get_tree().process_frame

	var build_launcher := shell.get_node("%BuildAction") as Button
	build_launcher.grab_focus()
	var build_previous_focus := get_viewport().gui_get_focus_owner()
	shell.call("validation_open_town_catalog", "build")
	await get_tree().process_frame
	await get_tree().process_frame
	var build_snapshot: Dictionary = shell.call("validation_town_catalog_snapshot")
	var build_catalog: Array = TownRules.get_build_catalog(SessionState.ensure_active_session())
	var build_icons := _catalog_button_icon_count(shell.get_node("%BuildActions"))
	var build_contained := _rect_contains(build_snapshot.get("overlay_rect", Rect2()), build_snapshot.get("panel_rect", Rect2()))
	_capture("build", viewport_size)

	shell.call("validation_close_town_catalog")
	await get_tree().process_frame
	await get_tree().process_frame
	var build_close_focus := get_viewport().gui_get_focus_owner()
	var build_focus_returned := build_close_focus == build_previous_focus
	var muster_launcher := shell.get_node("%MusterAction") as Button
	muster_launcher.grab_focus()
	var muster_previous_focus := get_viewport().gui_get_focus_owner()
	shell.call("validation_open_town_catalog", "muster")
	await get_tree().process_frame
	await get_tree().process_frame
	var muster_snapshot: Dictionary = shell.call("validation_town_catalog_snapshot")
	var muster_catalog: Array = TownRules.get_muster_catalog(SessionState.ensure_active_session())
	var portrait_count := _texture_rect_count(shell.get_node("%RecruitActions"))
	var muster_contained := _rect_contains(muster_snapshot.get("overlay_rect", Rect2()), muster_snapshot.get("panel_rect", Rect2()))
	_capture("muster", viewport_size)
	shell.call("validation_close_town_catalog")
	await get_tree().process_frame
	await get_tree().process_frame
	var muster_close_focus := get_viewport().gui_get_focus_owner()
	var muster_focus_returned := muster_close_focus == muster_previous_focus

	var build_ids: Array = build_snapshot.get("build_ids", [])
	var muster_ids: Array = muster_snapshot.get("muster_ids", [])
	var build_statuses: Dictionary = build_snapshot.get("build_statuses", {})
	var muster_statuses: Dictionary = muster_snapshot.get("muster_statuses", {})
	var build_exact := build_ids == expected_build_ids and build_catalog.size() == expected_build_ids.size()
	var muster_exact := muster_ids == expected_unit_ids and muster_catalog.size() == expected_unit_ids.size()
	var build_states_complete := int(build_statuses.get("Built", 0)) > 0 and (int(build_statuses.get("Ready", 0)) + int(build_statuses.get("Trade", 0)) + int(build_statuses.get("Resources", 0))) > 0 and int(build_statuses.get("Locked", 0)) > 0
	var muster_states_complete := int(muster_statuses.get("Locked", 0)) > 0 and (int(muster_statuses.get("Ready", 0)) + int(muster_statuses.get("Empty", 0)) + int(muster_statuses.get("Resources", 0)) + int(muster_statuses.get("Trade", 0))) > 0
	var ok: bool = (
		build_exact
		and muster_exact
		and build_states_complete
		and muster_states_complete
		and bool(build_snapshot.get("open", false))
		and String(build_snapshot.get("mode", "")) == "build"
		and bool(build_snapshot.get("focus_inside", false))
		and bool(build_snapshot.get("build_grid_visible", false))
		and not bool(build_snapshot.get("muster_grid_visible", true))
		and int(build_snapshot.get("build_card_count", 0)) == expected_build_ids.size()
		and build_icons == expected_build_ids.size()
		and build_contained
		and build_focus_returned
		and bool(muster_snapshot.get("open", false))
		and String(muster_snapshot.get("mode", "")) == "muster"
		and bool(muster_snapshot.get("focus_inside", false))
		and bool(muster_snapshot.get("muster_grid_visible", false))
		and not bool(muster_snapshot.get("build_grid_visible", true))
		and not bool(muster_snapshot.get("confirm_build_visible", true))
		and int(muster_snapshot.get("muster_card_count", 0)) == expected_unit_ids.size()
		and portrait_count == expected_unit_ids.size()
		and muster_contained
		and muster_focus_returned
	)
	var row := {
		"ok": ok,
		"viewport_size": viewport_size,
		"expected_build_count": expected_build_ids.size(),
		"expected_muster_count": expected_unit_ids.size(),
		"build_icons": build_icons,
		"muster_portraits": portrait_count,
		"build_statuses": build_statuses,
		"muster_statuses": muster_statuses,
		"build_focus_returned": build_focus_returned,
		"muster_focus_returned": muster_focus_returned,
		"build_close_focus": String(build_close_focus.name) if build_close_focus != null else "",
		"muster_close_focus": String(muster_close_focus.name) if muster_close_focus != null else "",
		"build_previous_focus": String(build_previous_focus.name) if build_previous_focus != null else "",
		"muster_previous_focus": String(muster_previous_focus.name) if muster_previous_focus != null else "",
		"build_contained": build_contained,
		"muster_contained": muster_contained,
		"build_exact": build_exact,
		"muster_exact": muster_exact,
	}
	shell.queue_free()
	await get_tree().process_frame
	SessionState.reset_session()
	return row

func _run_auxiliary_case(case: Dictionary) -> Dictionary:
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	var session = ScenarioFactory.create_session(String(case.get("scenario_id", "")), "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var town := _player_town_by_template(session, String(case.get("town_id", "")))
	if town.is_empty():
		return {"ok": false, "failure": "player_auxiliary_town_missing", "case": case}
	session.day = 30
	var resources := {"gold": 100000, "wood": 1000, "ore": 1000, "aetherglass": 1000, "embergrain": 1000, "peatwax": 1000, "verdant_grafts": 1000, "brass_scrip": 1000, "memory_salt": 1000}
	session.overworld["resources"] = resources
	var building_id := String(case.get("building_id", ""))
	var unit_id := String(case.get("unit_id", ""))
	var building: Dictionary = ContentService.get_building(building_id)
	var built_buildings: Array = town.get("built_buildings", []).duplicate(true)
	for requirement_value in building.get("requires", []):
		_append_building_requirements(built_buildings, String(requirement_value))
	built_buildings.erase(building_id)
	town["built_buildings"] = built_buildings
	town["last_build_day"] = 29
	var available_recruits: Dictionary = town.get("available_recruits", {}).duplicate(true)
	available_recruits.erase(unit_id)
	town["available_recruits"] = available_recruits
	_move_active_hero_to_town(session, town)
	var visit_result: Dictionary = OverworldRules.set_active_town_visit(session, String(town.get("placement_id", "")))
	if not bool(visit_result.get("ok", false)):
		return {"ok": false, "failure": "auxiliary_town_visit", "result": visit_result, "case": case}
	SessionState.set_active_session(session)
	var build_action := _action_by_id(TownRules.get_build_actions(session), "build:%s" % building_id)
	var art: Dictionary = ContentService.get_building_art(building_id)
	var icon_path := TownRules.building_icon_path(building_id)
	var icon: Texture2D = load(icon_path)
	var ai_candidates: Array = EnemyTurnRulesScript._enemy_town_build_candidates(
		session,
		town,
		0,
		resources,
		{"faction_id": String(case.get("faction_id", ""))},
		String(case.get("faction_id", ""))
	)
	var ai_candidate := _row_by_key(ai_candidates, "building_id", building_id)
	var shell = TownShellScene.instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	var icon_button := Button.new()
	shell._apply_build_action_icon(icon_button, {"id": "build:%s" % building_id})
	var popup_icon_exact := icon_button.icon != null and icon_button.icon.resource_path == icon_path
	icon_button.free()
	shell.call("validation_open_town_catalog", "build")
	await get_tree().process_frame
	_capture("auxiliary_build_%s" % String(case.get("faction_id", "")).trim_prefix("faction_"), Vector2i(1280, 720))
	shell.call("validation_close_town_catalog")
	var build_result: Dictionary = TownRules.build_active_town(session, building_id)
	var built_town := _town_by_placement(session, String(town.get("placement_id", "")))
	var immediate_recruits := int(built_town.get("available_recruits", {}).get(unit_id, 0))
	var weekly_growth := int(OverworldRules.town_weekly_growth(built_town, session).get(unit_id, 0))
	shell.call("validation_open_town_catalog", "muster")
	await get_tree().process_frame
	await get_tree().process_frame
	var muster_snapshot: Dictionary = shell.call("validation_town_catalog_snapshot")
	_capture("auxiliary_muster_%s" % String(case.get("faction_id", "")).trim_prefix("faction_"), Vector2i(1280, 720))
	var army_before := _army_unit_count(session, unit_id)
	var recruit_result: Dictionary = TownRules.recruit_active_town(session, unit_id, 1)
	var army_after := _army_unit_count(session, unit_id)
	var restored := SessionStateStoreScript.SessionData.new()
	restored.from_dict(session.to_dict())
	var restored_town := _town_by_placement(restored, String(town.get("placement_id", "")))
	var building_data_exact := (
		String(building.get("faction_id", "")) == String(case.get("faction_id", ""))
		and String(building.get("category", "")) == "dwelling"
		and String(building.get("content_status", "")) == "auxiliary_charter_hall_live"
		and String(building.get("unlock_unit_id", "")) == unit_id
		and int(building.get("growth_bonus", {}).get(unit_id, 0)) == 2
	)
	var art_exact := (
		not art.is_empty()
		and String(art.get("building_id", "")) == building_id
		and String(art.get("icon_path", "")) == icon_path
		and icon != null
		and popup_icon_exact
	)
	var ok: bool = (
		building_data_exact
		and not build_action.is_empty()
		and not bool(build_action.get("disabled", true))
		and not ai_candidate.is_empty()
		and float(ai_candidate.get("final_score", 0.0)) > 0.0
		and art_exact
		and bool(build_result.get("ok", false))
		and building_id in built_town.get("built_buildings", [])
		and immediate_recruits >= 2
		and weekly_growth >= 2
		and unit_id in muster_snapshot.get("muster_ids", [])
		and bool(recruit_result.get("ok", false))
		and army_after == army_before + 1
		and building_id in restored_town.get("built_buildings", [])
		and restored.to_dict() == session.to_dict()
		and int(restored.save_version) == SessionStateStoreScript.SAVE_VERSION
	)
	var row := {
		"ok": ok,
		"faction_id": case.get("faction_id", ""),
		"scenario_id": case.get("scenario_id", ""),
		"town_id": case.get("town_id", ""),
		"building_id": building_id,
		"unit_id": unit_id,
		"building_data_exact": building_data_exact,
		"build_action_ready": not build_action.is_empty() and not bool(build_action.get("disabled", true)),
		"ai_score": float(ai_candidate.get("final_score", 0.0)),
		"art_exact": art_exact,
		"build_ok": bool(build_result.get("ok", false)),
		"build_message": build_result.get("message", ""),
		"immediate_recruits": immediate_recruits,
		"weekly_growth": weekly_growth,
		"muster_visible": unit_id in muster_snapshot.get("muster_ids", []),
		"recruit_ok": bool(recruit_result.get("ok", false)),
		"save_version": restored.save_version,
		"save_exact": restored.to_dict() == session.to_dict(),
	}
	shell.queue_free()
	await get_tree().process_frame
	SessionState.reset_session()
	return row

func _append_building_requirements(target: Array, building_id: String) -> void:
	if building_id == "" or building_id in target:
		return
	var building := ContentService.get_building(building_id)
	for requirement_value in building.get("requires", []):
		_append_building_requirements(target, String(requirement_value))
	target.append(building_id)

func _action_by_id(rows: Array, action_id: String) -> Dictionary:
	return _row_by_key(rows, "id", action_id)

func _row_by_key(rows: Array, key: String, expected: String) -> Dictionary:
	for row_value in rows:
		if row_value is Dictionary and String(row_value.get(key, "")) == expected:
			return row_value
	return {}

func _town_by_placement(session, placement_id: String) -> Dictionary:
	return _row_by_key(session.overworld.get("towns", []), "placement_id", placement_id)

func _player_town_by_template(session, town_id: String) -> Dictionary:
	for town_value in session.overworld.get("towns", []):
		if town_value is Dictionary and String(town_value.get("town_id", "")) == town_id and String(town_value.get("owner", "")) == "player":
			return town_value
	return {}

func _army_unit_count(session, unit_id: String) -> int:
	var total := 0
	for stack_value in session.overworld.get("army", {}).get("stacks", []):
		if stack_value is Dictionary and String(stack_value.get("unit_id", "")) == unit_id:
			total += int(stack_value.get("count", 0))
	return total

func _first_player_town(session) -> Dictionary:
	for town_value in session.overworld.get("towns", []):
		if town_value is Dictionary and String(town_value.get("owner", "")) == "player":
			return town_value
	return {}

func _move_active_hero_to_town(session, town: Dictionary) -> void:
	var position := {"x": int(town.get("x", 0)), "y": int(town.get("y", 0))}
	session.overworld["hero_position"] = position.duplicate(true)
	var hero = session.overworld.get("hero", {})
	if hero is Dictionary:
		hero["x"] = position.x
		hero["y"] = position.y
		hero["position"] = position.duplicate(true)
		session.overworld["hero"] = hero

func _unique_strings(first: Variant, second: Variant) -> Array:
	var result := []
	for source in [first, second]:
		if not (source is Array):
			continue
		for value in source:
			var text := String(value)
			if text != "" and text not in result:
				result.append(text)
	return result

func _string_array(value: Variant) -> Array:
	var result := []
	if value is Array:
		for item in value:
			result.append(String(item))
	return result

func _town_unit_ids(building_ids: Array) -> Array:
	var rows := []
	for building_id_value in building_ids:
		var unit_id := String(ContentService.get_building(String(building_id_value)).get("unlock_unit_id", ""))
		if unit_id == "" or unit_id in rows:
			continue
		rows.append(unit_id)
	rows.sort_custom(func(left, right):
		var left_unit := ContentService.get_unit(String(left))
		var right_unit := ContentService.get_unit(String(right))
		var left_tier := int(left_unit.get("tier", 0))
		var right_tier := int(right_unit.get("tier", 0))
		return left_tier < right_tier if left_tier != right_tier else String(left_unit.get("name", left)) < String(right_unit.get("name", right))
	)
	return rows

func _catalog_button_icon_count(node: Node) -> int:
	var count := 0
	if node is Button and node.icon != null:
		count += 1
	for child in node.get_children():
		count += _catalog_button_icon_count(child)
	return count

func _texture_rect_count(node: Node) -> int:
	var count := 1 if node is TextureRect and node.texture != null else 0
	for child in node.get_children():
		count += _texture_rect_count(child)
	return count

func _rect_contains(outer: Rect2, inner: Rect2) -> bool:
	return outer.has_point(inner.position) and outer.has_point(inner.end - Vector2.ONE)

func _capture(mode: String, viewport_size: Vector2i) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var image := get_viewport().get_texture().get_image()
	image.save_png("%s/%s_%dx%d.png" % [CAPTURE_DIR, mode, viewport_size.x, viewport_size.y])
