extends Node

const TownShellScene = preload("res://scenes/town/TownShell.tscn")
const TownStageViewScript = preload("res://scenes/town/TownStageView.gd")
const VIEWPORT_SIZES := [Vector2i(2048, 1079), Vector2i(1280, 720)]
const FACTION_IDS := [
	"faction_embercourt",
	"faction_mireclaw",
	"faction_sunvault",
	"faction_thornwake",
	"faction_brasshollow",
	"faction_veilmourn",
]
const STAGE_IDS := ["village", "developing", "fully_built"]
const DIRECT_MODES := ["build", "muster", "spells", "trade", "log"]
const EXPECTED_TITLES := {
	"build": "Construction Ledger",
	"muster": "Muster Hall",
	"spells": "Spell Study",
	"trade": "Town Market",
	"log": "Town Log & Logistics",
}
const CAPTURE_DIR := "res://.artifacts/town_screen_layout_and_dialog_controls/captures"

var _errors: Array = []
var _original_window_size := Vector2i.ZERO
var _original_content_scale_size := Vector2i.ZERO

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_original_window_size = get_window().size
	_original_content_scale_size = get_window().content_scale_size
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
	var layout_rows: Array = []
	for viewport_size in VIEWPORT_SIZES:
		layout_rows.append(await _run_shell_case(viewport_size))
	var hotspot_rows := await _run_hotspot_matrix()
	get_window().size = _original_window_size
	get_window().content_scale_size = _original_content_scale_size
	SessionState.reset_session()
	var report := {
		"ok": _errors.is_empty(),
		"schema": "town_screen_layout_and_dialog_controls_report_v1",
		"layout_rows": layout_rows,
		"hotspot_rows": hotspot_rows,
		"layout_resolution_count": layout_rows.size(),
		"hotspot_case_count": hotspot_rows.size(),
		"direct_action_count": DIRECT_MODES.size(),
		"errors": _errors,
	}
	print("TOWN_SCREEN_LAYOUT_AND_DIALOG_CONTROLS_REPORT %s" % JSON.stringify(report))
	get_tree().quit(0 if _errors.is_empty() else 1)

func _run_shell_case(viewport_size: Vector2i) -> Dictionary:
	get_window().content_scale_size = viewport_size
	get_window().size = viewport_size
	await get_tree().process_frame
	await get_tree().process_frame
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var town := _first_player_town(session)
	if town.is_empty():
		_errors.append("%s has no player town" % viewport_size)
		return {"ok": false, "viewport_size": viewport_size, "failure": "player_town_missing"}
	_move_active_hero_to_town(session, town)
	var visit: Dictionary = OverworldRules.set_active_town_visit(session, String(town.get("placement_id", "")))
	if not bool(visit.get("ok", false)):
		_errors.append("%s could not enter player town" % viewport_size)
		return {"ok": false, "viewport_size": viewport_size, "failure": "town_visit_failed", "visit": visit}
	SessionState.set_active_session(session)
	var shell = TownShellScene.instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var layout: Dictionary = shell.call("validation_owner_town_layout_snapshot")
	var controls: Dictionary = shell.call("validation_direct_action_controls_snapshot")
	var control_rows: Array = controls.get("rows", []) if controls.get("rows", []) is Array else []
	var sidebar_rect: Rect2 = layout.get("sidebar_rect", Rect2())
	var controls_exact := control_rows.size() == DIRECT_MODES.size()
	for index in range(control_rows.size()):
		var row: Dictionary = control_rows[index]
		var rect: Rect2 = row.get("rect", Rect2())
		controls_exact = controls_exact \
			and bool(row.get("visible", false)) \
			and bool(row.get("icon_loaded", false)) \
			and bool(row.get("icon_only", false)) \
			and int(row.get("focus_mode", Control.FOCUS_NONE)) == Control.FOCUS_ALL \
			and String(row.get("tooltip_text", "")) != "" \
			and String(row.get("accessibility_name", "")) != "" \
			and String(row.get("accessibility_description", "")) != "" \
			and sidebar_rect.encloses(rect)
		for prior_index in range(index):
			var prior_rect: Rect2 = Dictionary(control_rows[prior_index]).get("rect", Rect2())
			controls_exact = controls_exact and not rect.intersects(prior_rect)
	var main_route: Dictionary = shell.call("validation_activate_main_building_hotspot")
	var route_exact := bool(main_route.get("same_authoritative_build_route", false))
	shell.call("validation_close_town_catalog")
	var dialog_rows: Array = []
	for mode_value in DIRECT_MODES:
		var mode := String(mode_value)
		var result: Dictionary = shell.call("validation_activate_direct_action", mode)
		var exact := bool(result.get("dialog_open", false)) \
			and String(result.get("active_dialog_mode", "")) == mode \
			and String(result.get("dialog_title", "")) == String(EXPECTED_TITLES[mode])
		if not exact:
			_errors.append("%s direct %s dialog route failed: %s" % [viewport_size, mode, result])
		dialog_rows.append({"mode": mode, "title": result.get("dialog_title", ""), "exact": exact})
		shell.call("validation_close_town_catalog")
		await get_tree().process_frame
	var hotspot: Dictionary = main_route.get("hotspot", {}) if main_route.get("hotspot", {}) is Dictionary else {}
	var layout_exact := bool(layout.get("header_single_row", false)) \
		and float(layout.get("header_height_ratio", 1.0)) <= 0.10 \
		and float(layout.get("scenic_area_ratio", 0.0)) >= 0.78 \
		and bool(layout.get("scenic_reaches_viewport_edges", false)) \
		and bool(layout.get("sidebar_overlays_scenic", false)) \
		and bool(layout.get("footer_overlays_scenic", false)) \
		and bool(layout.get("sidebar_contained", false)) \
		and bool(layout.get("footer_contained", false)) \
		and not bool(layout.get("legacy_management_tabs_visible", true)) \
		and bool(layout.get("direct_action_dock_visible", false))
	var hotspot_exact := bool(hotspot.get("visible", false)) \
		and bool(hotspot.get("contained", false)) \
		and int(hotspot.get("focus_mode", Control.FOCUS_NONE)) == Control.FOCUS_ALL \
		and String(hotspot.get("tooltip_text", "")) != "" \
		and String(hotspot.get("accessibility_name", "")) != ""
	var capture_path := "%s/town_%dx%d.png" % [CAPTURE_DIR, viewport_size.x, viewport_size.y]
	var capture_ok := true
	if DisplayServer.get_name() != "headless":
		var image: Image = get_viewport().get_texture().get_image()
		capture_ok = image != null and not image.is_empty() and image.save_png(ProjectSettings.globalize_path(capture_path)) == OK
	var ok := layout_exact and controls_exact and route_exact and hotspot_exact and dialog_rows.all(func(row): return bool(row.get("exact", false))) and capture_ok
	if not ok:
		_errors.append("%s layout contract failed: layout=%s controls=%s route=%s hotspot=%s capture=%s" % [viewport_size, layout_exact, controls_exact, route_exact, hotspot_exact, capture_ok])
	var row := {
		"ok": ok,
		"viewport_size": viewport_size,
		"layout": layout,
		"controls": controls,
		"dialog_rows": dialog_rows,
		"main_building_route_exact": route_exact,
		"hotspot_exact": hotspot_exact,
		"capture_path": capture_path,
		"capture_ok": capture_ok,
	}
	shell.queue_free()
	await get_tree().process_frame
	SessionState.reset_session()
	return row

func _run_hotspot_matrix() -> Array:
	var fixture = TownStageViewScript.new()
	fixture.position = Vector2.ZERO
	fixture.size = Vector2(1280.0, 620.0)
	add_child(fixture)
	await get_tree().process_frame
	var rows: Array = []
	for faction_id_value in FACTION_IDS:
		var faction_id := String(faction_id_value)
		var town_template := _first_town_for_faction(faction_id)
		var catalog_ids := _catalog_ids(town_template)
		# Development now adds individual integrated buildings to the same village
		# base. Exercise empty/partial/full build sets, not the retired art tiers.
		var developing_count := mini(catalog_ids.size() - 1, maxi(1, catalog_ids.size() / 2))
		var built_by_stage := {
			"village": _string_array(town_template.get("starting_building_ids", [])),
			"developing": catalog_ids.slice(0, developing_count),
			"fully_built": catalog_ids,
		}
		for stage_id_value in STAGE_IDS:
			var stage_id := String(stage_id_value)
			fixture.set_precomputed_town_state(null, {
				"town": {"town_id": town_template.get("id", ""), "placement_id": "hotspot_fixture", "built_buildings": built_by_stage[stage_id]},
				"town_template": town_template,
				"faction": ContentService.get_faction(faction_id),
			})
			await get_tree().process_frame
			var summary: Dictionary = fixture.validation_main_building_hotspot_summary()
			var normalized: Rect2 = summary.get("normalized_rect", Rect2())
			var exact := String(summary.get("faction_id", "")) == faction_id \
				and String(summary.get("stage_id", "")) == "village" \
				and normalized.position.x >= 0.0 and normalized.position.y >= 0.0 \
				and normalized.end.x <= 1.0 and normalized.end.y <= 1.0 \
				and normalized.size.x > 0.0 and normalized.size.y > 0.0 \
				and bool(summary.get("visible", false)) \
				and bool(summary.get("contained", false))
			if not exact:
				_errors.append("Hotspot mapping failed for %s %s: %s" % [faction_id, stage_id, summary])
			rows.append({"faction_id": faction_id, "fixture_build_state": stage_id, "base_stage_id": summary.get("stage_id", ""), "exact": exact, "normalized_rect": normalized, "destination_rect": summary.get("destination_rect", Rect2())})
	fixture.queue_free()
	await get_tree().process_frame
	return rows

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

func _first_town_for_faction(faction_id: String) -> Dictionary:
	for town_id_value in ContentService.get_content_ids(ContentService.TOWNS_PATH):
		var town_template := ContentService.get_town(String(town_id_value))
		if String(town_template.get("faction_id", "")) == faction_id:
			return town_template
	return {}

func _catalog_ids(town_template: Dictionary) -> Array:
	var result: Array = []
	for source in [town_template.get("starting_building_ids", []), town_template.get("buildable_building_ids", [])]:
		for value in source if source is Array else []:
			var building_id := String(value)
			if building_id != "" and building_id not in result:
				result.append(building_id)
	return result

func _string_array(values: Variant) -> Array:
	var result: Array = []
	for value in values if values is Array else []:
		var text := String(value)
		if text != "" and text not in result:
			result.append(text)
	return result
