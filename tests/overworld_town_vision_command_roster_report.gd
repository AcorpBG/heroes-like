extends Node

const ScenarioFactoryScript = preload("res://scripts/core/ScenarioFactory.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "OVERWORLD_OWNED_ROSTER_VISUAL_POLISH_REPORT"
const ARTIFACT_DIR := "res://.artifacts/overworld_owned_roster_visual_polish_10235"
const VIEWPORTS := [Vector2i(1920, 1080), Vector2i(1280, 720)]
const MAP_SIZE := Vector2i(20, 20)
const PLAYER_TOWN := {"placement_id": "vision_player", "town_id": "town_riverwatch", "x": 5, "y": 5, "owner": "player"}
const ENEMY_TOWN := {"placement_id": "vision_enemy", "town_id": "town_duskfen", "x": 14, "y": 5, "owner": "enemy"}
const NEUTRAL_TOWN := {"placement_id": "vision_neutral", "town_id": "town_prismhearth", "x": 14, "y": 14, "owner": "neutral"}

var _failures: Array = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var vision := _validate_town_vision()
	var ui := await _validate_command_roster()
	_finish({
		"town_vision": vision,
		"command_roster": ui,
		"save_version": SessionStateStoreScript.SAVE_VERSION,
		"native_rmg_output_changed": false,
	})


func _validate_town_vision() -> Dictionary:
	var session = ScenarioFactoryScript.create_session("river-pass", "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	session.overworld["map"] = _blank_map(MAP_SIZE)
	session.overworld["map_size"] = {"width": MAP_SIZE.x, "height": MAP_SIZE.y}
	session.overworld["player_heroes"] = []
	session.overworld["resource_nodes"] = []
	session.overworld["towns"] = [PLAYER_TOWN.duplicate(true), ENEMY_TOWN.duplicate(true), NEUTRAL_TOWN.duplicate(true)]
	session.overworld["fog"] = {}
	OverworldRules.refresh_fog_of_war(session)
	var radius := OverworldRules.player_town_vision_radius()
	var expected_initial := _expected_town_tiles([PLAYER_TOWN], radius, MAP_SIZE)
	var initial := _fog_exact_summary(session, expected_initial)
	if radius != 5:
		_failures.append("player town vision radius is not the documented radius five")
	if not bool(initial.get("exact", false)) or int(initial.get("explored_count", 0)) != 61:
		_failures.append("initial player-town vision is not the exact centered radius-five diamond")
	if OverworldRules.is_tile_explored(session, int(ENEMY_TOWN.x), int(ENEMY_TOWN.y)):
		_failures.append("enemy town revealed its center for the player")
	if OverworldRules.is_tile_explored(session, int(NEUTRAL_TOWN.x), int(NEUTRAL_TOWN.y)):
		_failures.append("neutral town revealed its center for the player")

	var towns: Array = session.overworld.get("towns", [])
	var former_player: Dictionary = towns[0]
	former_player["owner"] = "enemy"
	towns[0] = former_player
	var captured: Dictionary = towns[2]
	captured["owner"] = "player"
	towns[2] = captured
	session.overworld["towns"] = towns
	OverworldRules.refresh_fog_of_war(session)
	var expected_after_capture := expected_initial.duplicate(true)
	for key in _expected_town_tiles([captured], radius, MAP_SIZE).keys():
		expected_after_capture[key] = true
	var after_capture := _fog_exact_summary(session, expected_after_capture)
	if not bool(after_capture.get("exact", false)) or int(after_capture.get("explored_count", 0)) != 122:
		_failures.append("captured town did not add exactly one new radius-five permanent source")
	if not OverworldRules.is_tile_explored(session, int(PLAYER_TOWN.x), int(PLAYER_TOWN.y)):
		_failures.append("losing a former source erased permanent exploration")

	var restored := SessionStateStoreScript.SessionData.new()
	restored.from_dict(session.to_dict())
	OverworldRules.refresh_fog_of_war(restored)
	var restored_summary := _fog_exact_summary(restored, expected_after_capture)
	if not bool(restored_summary.get("exact", false)) or restored.save_version != SessionStateStoreScript.SAVE_VERSION:
		_failures.append("town exploration did not survive the version-nine serialization round trip")
	return {
		"radius": radius,
		"initial": initial,
		"after_capture": after_capture,
		"restored": restored_summary,
		"enemy_and_neutral_excluded": true,
		"former_source_memory_retained": true,
	}


func _validate_command_roster() -> Dictionary:
	SessionState.reset_session()
	var session = ScenarioFactoryScript.create_session("ninefold-confluence", "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state_for_runtime(session)
	session = SessionState.set_active_session(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	for _frame in range(8):
		await get_tree().process_frame

	var normal_initial: Dictionary = shell.validation_command_roster_snapshot()
	_validate_roster_snapshot(normal_initial, session, "untouched_normal_play")
	var active_hero_id := String(session.overworld.get("active_hero_id", ""))
	var active_hero_button := _roster_button(shell.get_node("%HeroActions"), "hero_id", active_hero_id)
	if active_hero_button == null:
		_failures.append("untouched normal play is missing its authoritative active hero card")
	else:
		active_hero_button.emit_signal("pressed")
		for _frame in range(2):
			await get_tree().process_frame
	var active_hero_position := HeroCommandRules.hero_position_by_id(session, active_hero_id)
	var after_hero_focus: Dictionary = shell.validation_snapshot()
	if int(after_hero_focus.get("selected_tile", {}).get("x", -1)) != int(active_hero_position.get("x", -2)) or int(after_hero_focus.get("selected_tile", {}).get("y", -1)) != int(active_hero_position.get("y", -2)):
		_failures.append("active owned hero card did not center the authoritative hero")

	var target_town: Dictionary = _last_player_town(session)
	var target_town_button := _roster_button(shell.get_node("%TownActions"), "town_placement_id", String(target_town.get("placement_id", "")))
	if target_town_button == null:
		_failures.append("untouched normal play is missing an authoritative owned-town card")
	else:
		target_town_button.emit_signal("pressed")
		for _frame in range(2):
			await get_tree().process_frame
	var after_town: Dictionary = shell.validation_snapshot()
	if int(after_town.get("selected_tile", {}).get("x", -1)) != int(target_town.get("x", -2)) or int(after_town.get("selected_tile", {}).get("y", -1)) != int(target_town.get("y", -2)):
		_failures.append("owned-town card did not route through authoritative town selection")
	var selected_roster: Dictionary = shell.validation_command_roster_snapshot()
	if int(selected_roster.get("selected_town_button_count", 0)) != 1:
		_failures.append("owned-town roster did not expose exactly one selected holding")

	var captures := []
	var layouts := []
	for viewport in VIEWPORTS:
		get_window().size = viewport
		get_window().content_scale_size = viewport
		await get_tree().process_frame
		await get_tree().process_frame
		shell._focus_active_hero_from_roster()
		await get_tree().process_frame
		var layout: Dictionary = shell.validation_map_first_layout_snapshot()
		var roster: Dictionary = shell.validation_command_roster_snapshot()
		_validate_layout(layout, viewport)
		_validate_roster_snapshot(roster, session, "untouched_normal_play_%dx%d" % [viewport.x, viewport.y])
		layouts.append({"viewport": {"width": viewport.x, "height": viewport.y}, "layout": layout, "roster": roster})
		var capture_path := await _capture("owned_roster_normal_%dx%d" % [viewport.x, viewport.y])
		captures.append(capture_path)
		if capture_path == "":
			_failures.append("owned-roster normal-play capture failed at %s" % viewport)

	var normal_play := {
		"fixture": "untouched_ninefold_confluence",
		"synthetic_ownership": false,
		"authoritative_player_hero_ids": _expected_player_hero_ids(session),
		"authoritative_player_town_ids": _expected_player_town_ids(session),
		"excluded_non_player_town_ids": _expected_non_player_town_ids(session),
		"initial": normal_initial,
		"after_hero_focus": {
			"active_hero_id": active_hero_id,
			"selected_tile": after_hero_focus.get("selected_tile", {}),
		},
		"after_town_select": {
			"placement_id": String(target_town.get("placement_id", "")),
			"selected_tile": after_town.get("selected_tile", {}),
		},
		"layouts": layouts,
		"captures": captures,
	}

	shell.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	var overflow := await _validate_synthetic_overflow_roster()
	return {
		"initial": normal_initial,
		"normal_play": normal_play,
		"overflow": overflow,
		"layouts": layouts,
		"captures": captures,
	}


func _validate_synthetic_overflow_roster() -> Dictionary:
	SessionState.reset_session()
	var session = ScenarioFactoryScript.create_session("ninefold-confluence", "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	var hero_specs := [
		{"id": "hero_caelen", "x": 19, "y": 26},
		{"id": "hero_lyra", "x": 23, "y": 30},
		{"id": "hero_seren", "x": 27, "y": 26},
	]
	var heroes: Array = session.overworld.get("player_heroes", [])
	for spec in hero_specs:
		var hero := HeroCommandRules.build_hero_from_template(
			ContentService.get_hero(String(spec.id)),
			{"x": int(spec.x), "y": int(spec.y)},
			{"id": "%s_test_army" % String(spec.id), "name": "Test Company", "stacks": []},
			session
		)
		heroes.append(hero)
	session.overworld["player_heroes"] = heroes
	var towns: Array = session.overworld.get("towns", [])
	var owned_templates := []
	for town_value in towns:
		if town_value is Dictionary and String(town_value.get("owner", "neutral")) == "player":
			owned_templates.append(town_value)
	for index in range(3):
		var town: Dictionary = owned_templates[index % owned_templates.size()].duplicate(true)
		town["placement_id"] = "synthetic_owned_overflow_%d" % index
		town["owner"] = "player"
		town["x"] = 18 + index * 2
		town["y"] = 22
		towns.append(town)
	session.overworld["towns"] = towns
	OverworldRules.normalize_overworld_state_for_runtime(session)
	session = SessionState.set_active_session(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	for _frame in range(8):
		await get_tree().process_frame

	var initial: Dictionary = shell.validation_command_roster_snapshot()
	_validate_roster_snapshot(initial, session, "synthetic_overflow_only")
	var target_hero_id := "hero_caelen"
	var target_hero_button := _roster_button(shell.get_node("%HeroActions"), "hero_id", target_hero_id)
	if target_hero_button == null:
		_failures.append("target reserve hero roster card is missing")
	else:
		target_hero_button.emit_signal("pressed")
		for _frame in range(3):
			await get_tree().process_frame
	var hero_position := HeroCommandRules.hero_position_by_id(session, target_hero_id)
	var after_hero: Dictionary = shell.validation_snapshot()
	if String(session.overworld.get("active_hero_id", "")) != target_hero_id:
		_failures.append("reserve hero card did not route through authoritative hero switching")
	if int(after_hero.get("selected_tile", {}).get("x", -1)) != int(hero_position.get("x", -2)) or int(after_hero.get("selected_tile", {}).get("y", -1)) != int(hero_position.get("y", -2)):
		_failures.append("reserve hero card did not center/select the activated hero")

	var scrolled: Dictionary = shell.validation_scroll_command_roster_to_end()
	await get_tree().process_frame
	if not bool(scrolled.get("overflow_available", false)) or int(shell.validation_command_roster_snapshot().get("scroll_vertical", 0)) <= 0:
		_failures.append("larger hero/town roster is not reachable through bounded scrolling")
	return {
		"fixture": "synthetic_overflow_only_no_visual_evidence",
		"synthetic_ownership": true,
		"initial": initial,
		"after_hero_switch": {
			"active_hero_id": String(session.overworld.get("active_hero_id", "")),
			"selected_tile": after_hero.get("selected_tile", {}),
		},
		"overflow": scrolled,
		"captures": [],
	}


func _validate_roster_snapshot(snapshot: Dictionary, session, fixture: String) -> void:
	var expected_hero_ids := _expected_player_hero_ids(session)
	var expected_town_ids := _expected_player_town_ids(session)
	var non_player_town_ids := _expected_non_player_town_ids(session)
	var actual_hero_ids := _entry_ids(snapshot.get("hero_entries", []), "hero_id")
	var actual_town_ids := _entry_ids(snapshot.get("town_entries", []), "town_placement_id")
	var expected_heroes := expected_hero_ids.size()
	var expected_towns := expected_town_ids.size()
	if int(snapshot.get("hero_count", -1)) != expected_heroes or int(snapshot.get("town_count", -1)) != expected_towns:
		_failures.append("%s roster does not cover every player hero and owned town" % fixture)
	if actual_hero_ids != expected_hero_ids:
		_failures.append("%s hero cards differ from the authoritative player_heroes ids" % fixture)
	if actual_town_ids != expected_town_ids:
		_failures.append("%s town cards differ from authoritative player-owned placement ids" % fixture)
	for town_id in non_player_town_ids:
		if actual_town_ids.has(town_id):
			_failures.append("%s roster exposed non-player town %s" % [fixture, town_id])
	for key in ["all_icons_loaded", "all_focusable", "all_accessible", "columns_side_by_side"]:
		if not bool(snapshot.get(key, false)):
			_failures.append("%s right-rail roster contract failed: %s" % [fixture, key])
	if int(snapshot.get("active_hero_button_count", 0)) != 1:
		_failures.append("%s roster does not expose exactly one active hero" % fixture)
	if _unique_entry_ids(snapshot.get("hero_entries", []), "hero_id") != expected_heroes:
		_failures.append("%s hero roster has missing or duplicate identities" % fixture)
	if _unique_entry_ids(snapshot.get("town_entries", []), "town_placement_id") != expected_towns:
		_failures.append("%s town roster has missing or duplicate placement identities" % fixture)
	var all_entries: Array = []
	all_entries.append_array(snapshot.get("hero_entries", []))
	all_entries.append_array(snapshot.get("town_entries", []))
	for entry_value in all_entries:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var rect := _rect_from_payload(entry.get("rect", {}))
		if String(entry.get("owner", "")) != "player":
			_failures.append("%s roster card is not explicitly player-owned" % fixture)
		if String(entry.get("visual_model", "")) != "ornamental_art_card":
			_failures.append("%s roster card lost the ornamental visual model" % fixture)
		if int(entry.get("icon_alignment", -1)) != HORIZONTAL_ALIGNMENT_CENTER:
			_failures.append("%s roster art is not centered" % fixture)
		if float(entry.get("minimum_height", 0.0)) < 64.0 or rect.size.y < 64.0 or rect.size.x < 56.0 or rect.size.x / maxf(rect.size.y, 1.0) > 1.45:
			_failures.append("%s roster entry is still a thin bar instead of a compact art card" % fixture)


func _validate_layout(layout: Dictionary, viewport: Vector2i) -> void:
	var root := _rect_from_payload(layout.get("viewport", {}))
	var map := _rect_from_payload(layout.get("map", {}))
	var rail := _rect_from_payload(layout.get("rail", {}))
	var footer := _rect_from_payload(layout.get("footer", {}))
	var minimap := _rect_from_payload(layout.get("minimap", {}))
	if not root.encloses(map) or not root.encloses(rail) or not root.encloses(footer) or not rail.encloses(minimap):
		_failures.append("responsive roster layout escaped the viewport at %s" % viewport)
	if map.intersects(rail) or map.intersects(footer) or rail.intersects(footer):
		_failures.append("responsive roster layout overlaps at %s" % viewport)
	if float(layout.get("map_width_share", 0.0)) < (0.78 if viewport.x >= 1900 else 0.76):
		_failures.append("paired roster reduced the dominant map share at %s" % viewport)


func _fog_exact_summary(session, expected: Dictionary) -> Dictionary:
	var actual := {}
	for y in range(MAP_SIZE.y):
		for x in range(MAP_SIZE.x):
			if OverworldRules.is_tile_explored(session, x, y):
				actual["%d,%d" % [x, y]] = true
	var missing := []
	var unexpected := []
	for key in expected.keys():
		if not actual.has(key):
			missing.append(key)
	for key in actual.keys():
		if not expected.has(key):
			unexpected.append(key)
	return {
		"explored_count": actual.size(),
		"expected_count": expected.size(),
		"missing": missing,
		"unexpected": unexpected,
		"exact": missing.is_empty() and unexpected.is_empty(),
	}


func _expected_town_tiles(towns: Array, radius: int, map_size: Vector2i) -> Dictionary:
	var expected := {}
	for town in towns:
		if not (town is Dictionary):
			continue
		var origin := Vector2i(int(town.get("x", 0)), int(town.get("y", 0)))
		for y in range(maxi(0, origin.y - radius), mini(map_size.y - 1, origin.y + radius) + 1):
			for x in range(maxi(0, origin.x - radius), mini(map_size.x - 1, origin.x + radius) + 1):
				if abs(x - origin.x) + abs(y - origin.y) <= radius:
					expected["%d,%d" % [x, y]] = true
	return expected


func _blank_map(size: Vector2i) -> Array:
	var rows := []
	for _y in range(size.y):
		var row := []
		for _x in range(size.x):
			row.append("grass")
		rows.append(row)
	return rows


func _last_player_town(session) -> Dictionary:
	var result := {}
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("owner", "neutral")) == "player":
			result = town
	return result


func _roster_button(container: Container, metadata_key: String, value: String) -> Button:
	for child in container.get_children():
		if child is Button and String(child.get_meta(metadata_key, "")) == value:
			return child as Button
	return null


func _unique_entry_ids(entries: Array, key: String) -> int:
	var ids := {}
	for entry in entries:
		if entry is Dictionary:
			var id := String(entry.get(key, ""))
			if id != "":
				ids[id] = true
	return ids.size()


func _entry_ids(entries: Array, key: String) -> Array:
	var ids := []
	for entry in entries:
		if entry is Dictionary:
			var id := String(entry.get(key, ""))
			if id != "":
				ids.append(id)
	ids.sort()
	return ids


func _expected_player_hero_ids(session) -> Array:
	var ids := []
	for hero in session.overworld.get("player_heroes", []):
		if hero is Dictionary:
			var hero_id := String(hero.get("id", ""))
			if hero_id != "":
				ids.append(hero_id)
	ids.sort()
	return ids


func _expected_player_town_ids(session) -> Array:
	var ids := []
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("owner", "neutral")) == "player":
			var placement_id := String(town.get("placement_id", ""))
			if placement_id != "":
				ids.append(placement_id)
	ids.sort()
	return ids


func _expected_non_player_town_ids(session) -> Array:
	var ids := []
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("owner", "neutral")) != "player":
			var placement_id := String(town.get("placement_id", ""))
			if placement_id != "":
				ids.append(placement_id)
	ids.sort()
	return ids


func _rect_from_payload(value: Variant) -> Rect2:
	var payload: Dictionary = value if value is Dictionary else {}
	return Rect2(float(payload.get("x", 0.0)), float(payload.get("y", 0.0)), float(payload.get("width", 0.0)), float(payload.get("height", 0.0)))


func _capture(stem: String) -> String:
	var absolute_dir := ProjectSettings.globalize_path(ARTIFACT_DIR)
	if DirAccess.make_dir_recursive_absolute(absolute_dir) != OK:
		return ""
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		return ""
	var path := absolute_dir.path_join("%s.png" % stem)
	return path if image.save_png(path) == OK else ""


func _finish(payload: Dictionary) -> void:
	payload["ok"] = _failures.is_empty()
	payload["failures"] = _failures.duplicate(true)
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	if _failures.is_empty():
		get_tree().quit(0)
		return
	for failure in _failures:
		push_error("%s: %s" % [REPORT_ID, String(failure)])
	get_tree().quit(1)
