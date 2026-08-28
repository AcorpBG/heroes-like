extends Node

const SessionDataScript = preload("res://scripts/core/SessionStateStore.gd")
const REPORT_ID := "ARTIFACT_ICON_RUNTIME_REPORT"
const ARTIFACT_ID := "artifact_trailsinger_boots"
const ARTIFACT_SLOT := "boots"
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const EXPECTED_ICONS := {
	"artifact_trailsinger_boots": "res://art/artifacts/runtime/trailsinger_boots.png",
	"artifact_quarry_tally_rod": "res://art/artifacts/runtime/quarry_tally_rod.png",
	"artifact_warcrest_pennon": "res://art/artifacts/runtime/warcrest_pennon.png",
	"artifact_bastion_gorget": "res://art/artifacts/runtime/bastion_gorget.png",
	"artifact_waymark_compass": "res://art/artifacts/runtime/waymark_compass.png",
	"artifact_milepost_lantern": "res://art/artifacts/runtime/milepost_lantern.png",
	"artifact_tollstone_ring": "res://art/artifacts/runtime/tollstone_ring.png",
	"artifact_mudglass_beads": "res://art/artifacts/runtime/mudglass_beads.png",
	"artifact_choir_tuning_fork": "res://art/artifacts/runtime/choir_tuning_fork.png",
	"artifact_living_bridge_knot": "res://art/artifacts/runtime/living_bridge_knot.png",
	"artifact_pressure_gauge_reliquary": "res://art/artifacts/runtime/pressure_gauge_reliquary.png",
	"artifact_black_sail_compass": "res://art/artifacts/runtime/black_sail_compass.png",
	"artifact_rainstar_sextant": "res://art/artifacts/runtime/rainstar_sextant.png",
	"artifact_asterfall_mantle": "res://art/artifacts/runtime/asterfall_mantle.png",
	"artifact_cometwake_pennon": "res://art/artifacts/runtime/cometwake_pennon.png",
}

var _original_ui_scale_percent := 100

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_window_size := get_window().size
	_original_ui_scale_percent = SettingsService.ui_scale_percent()
	SettingsService.set_ui_scale_percent(100)
	await get_tree().process_frame
	var catalog := _catalog_contract()
	if not bool(catalog.get("ok", false)):
		_fail("Artifact icon catalog failed: %s" % JSON.stringify(catalog), original_window_size)
		return
	var rows := []
	for viewport_size in VIEWPORT_SIZES:
		for surface in ["overworld", "town"]:
			var row: Dictionary = await _surface_case(viewport_size, surface)
			rows.append(row)
			if not bool(row.get("ok", false)):
				_fail("Artifact icon surface failed: %s" % JSON.stringify(row), original_window_size)
				return
	get_window().size = original_window_size
	SettingsService.set_ui_scale_percent(_original_ui_scale_percent)
	await get_tree().process_frame
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": true, "catalog": catalog, "rows": rows})])
	get_tree().quit(0)

func _catalog_contract() -> Dictionary:
	var icon_ids := []
	var icon_paths := []
	var rows := []
	for artifact_id in EXPECTED_ICONS:
		var artifact := ContentService.get_artifact(artifact_id)
		var ui: Dictionary = artifact.get("ui", {}) if artifact.get("ui", {}) is Dictionary else {}
		var icon_id := String(ui.get("icon_id", ""))
		var icon_path := String(ui.get("icon_path", ""))
		var texture := load(icon_path) as Texture2D if ResourceLoader.exists(icon_path, "Texture2D") else null
		var size := texture.get_size() if texture != null else Vector2.ZERO
		rows.append({"artifact_id": artifact_id, "icon_id": icon_id, "icon_path": icon_path, "size": size})
		icon_ids.append(icon_id)
		icon_paths.append(icon_path)
	var distinct_ids := icon_ids.duplicate()
	distinct_ids.sort()
	var distinct_paths := icon_paths.duplicate()
	distinct_paths.sort()
	return {
		"ok": (
			rows.size() == EXPECTED_ICONS.size()
			and distinct_ids.size() == EXPECTED_ICONS.size()
			and distinct_paths.size() == EXPECTED_ICONS.size()
			and _all_unique(distinct_ids)
			and _all_unique(distinct_paths)
			and rows.all(func(row): return not String(row.get("icon_id", "")).contains("placeholder") and String(row.get("icon_path", "")) == String(EXPECTED_ICONS.get(String(row.get("artifact_id", "")), "")) and row.get("size", Vector2.ZERO) == Vector2(128.0, 128.0))
			and ArtifactRules.artifact_icon_path("artifact_missing") == ""
			and ArtifactRules.artifact_id_for_management_action({}, "equip_artifact:artifact_missing") == ""
		),
		"artifact_count": rows.size(),
		"distinct_icon_id_count": distinct_ids.size(),
		"distinct_icon_path_count": distinct_paths.size(),
		"rows": rows,
	}

func _surface_case(viewport_size: Vector2i, surface: String) -> Dictionary:
	get_window().size = viewport_size
	await get_tree().process_frame
	await get_tree().process_frame
	if get_window().size != viewport_size:
		return {"ok": false, "failure": "window_size", "surface": surface, "actual": get_window().size}
	var session = _artifact_session(surface == "town")
	SessionState.set_active_session(session)
	var scene_path := "res://scenes/town/TownShell.tscn" if surface == "town" else "res://scenes/overworld/OverworldShell.tscn"
	var shell = load(scene_path).instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	if surface == "town":
		var management_tabs := shell.get_node_or_null("%ManagementTabs") as TabContainer
		if management_tabs == null:
			return await _finish_case(shell, {"ok": false, "failure": "management_tabs_missing", "surface": surface})
		management_tabs.current_tab = 4
	else:
		shell.validation_open_command_drawer()
	await get_tree().process_frame
	await get_tree().process_frame
	var live_session = SessionState.ensure_active_session()
	var container := shell.get_node_or_null("%ArtifactActions") as Container
	if container == null:
		return await _finish_case(shell, {"ok": false, "failure": "artifact_actions_missing", "surface": surface})
	var actions: Array = TownRules.get_artifact_actions(live_session) if surface == "town" else OverworldRules.get_artifact_actions(live_session)
	var initial_buttons := _button_contract(container, actions, live_session)
	var equip_action_id := "equip_artifact:%s" % ARTIFACT_ID
	var equip_button := _button_for_action(container, actions, equip_action_id)
	if equip_button == null or not _icon_exact(equip_button, EXPECTED_ICONS[ARTIFACT_ID]):
		return await _finish_case(shell, {"ok": false, "failure": "equip_icon_missing", "surface": surface, "buttons": initial_buttons})
	var live_before: Dictionary = live_session.to_dict()
	var control = SessionDataScript.SessionData.new()
	control.from_dict(live_before.duplicate(true))
	var equip_control: Dictionary = _apply_control_action(control, surface, equip_action_id)
	equip_button.emit_signal("pressed")
	await get_tree().process_frame
	await get_tree().process_frame
	var equip_exact := bool(equip_control.get("ok", false)) and live_session.to_dict() == control.to_dict()
	var stow_actions: Array = TownRules.get_artifact_actions(live_session) if surface == "town" else OverworldRules.get_artifact_actions(live_session)
	var stow_action_id := "unequip_artifact:%s" % ARTIFACT_SLOT
	var stow_button := _button_for_action(container, stow_actions, stow_action_id)
	var stow_icon_exact := stow_button != null and _icon_exact(stow_button, EXPECTED_ICONS[ARTIFACT_ID])
	var stow_control: Dictionary = _apply_control_action(control, surface, stow_action_id)
	if stow_button != null:
		stow_button.emit_signal("pressed")
	await get_tree().process_frame
	await get_tree().process_frame
	var final_actions: Array = TownRules.get_artifact_actions(live_session) if surface == "town" else OverworldRules.get_artifact_actions(live_session)
	var final_buttons := _button_contract(container, final_actions, live_session)
	var row := {
		"ok": (
			bool(initial_buttons.get("ok", false))
			and equip_exact
			and stow_icon_exact
			and bool(stow_control.get("ok", false))
			and live_session.to_dict() == control.to_dict()
			and bool(final_buttons.get("ok", false))
		),
		"viewport_size": viewport_size,
		"surface": surface,
		"initial_buttons": initial_buttons,
		"equip_exact": equip_exact,
		"stow_icon_exact": stow_icon_exact,
		"stow_exact": bool(stow_control.get("ok", false)) and live_session.to_dict() == control.to_dict(),
		"final_buttons": final_buttons,
	}
	return await _finish_case(shell, row)

func _button_contract(container: Container, actions: Array, session) -> Dictionary:
	var buttons := []
	for action_value in actions:
		if not (action_value is Dictionary):
			continue
		var action: Dictionary = action_value
		var button := _button_for_action(container, actions, String(action.get("id", "")))
		var artifact_id := ArtifactRules.artifact_id_for_management_action(session.overworld.get("hero", {}), String(action.get("id", "")))
		var expected_path := ArtifactRules.artifact_icon_path(artifact_id)
		var button_rect: Rect2 = button.get_global_rect() if button != null else Rect2()
		var container_rect := container.get_global_rect()
		buttons.append({
			"action_id": String(action.get("id", "")),
			"artifact_id": artifact_id,
			"expected_path": expected_path,
			"button_present": button != null,
			"copy_exact": button != null and button.text == String(action.get("label", "")) and button.tooltip_text.contains(String(action.get("summary", ""))),
			"icon_exact": button != null and ((_icon_exact(button, expected_path)) if expected_path != "" else button.icon == null),
			"contained": button != null and get_viewport().get_visible_rect().encloses(button_rect),
			"visible": button != null and button.is_visible_in_tree(),
			"button_rect": button_rect,
			"container_rect": container_rect,
			"viewport_rect": get_viewport().get_visible_rect(),
		})
	return {"ok": buttons.size() == actions.size() and buttons.all(func(row): return bool(row.get("button_present", false)) and bool(row.get("copy_exact", false)) and bool(row.get("icon_exact", false)) and bool(row.get("contained", false)) and bool(row.get("visible", false))), "button_count": buttons.size(), "action_count": actions.size(), "buttons": buttons}

func _button_for_action(container: Container, actions: Array, action_id: String) -> Button:
	var expected_label := ""
	for action_value in actions:
		if action_value is Dictionary and String(action_value.get("id", "")) == action_id:
			expected_label = String(action_value.get("label", ""))
			break
	for child in container.get_children():
		if child is Button and child.text == expected_label:
			return child
	return null

func _apply_control_action(control, surface: String, action_id: String) -> Dictionary:
	if surface != "town":
		return OverworldRules.perform_artifact_action(control, action_id)
	var action := _action_for_id(TownRules.get_artifact_actions(control), action_id)
	var before := TownRules.town_action_consequence_signature(control)
	var result: Dictionary = TownRules.manage_artifact_at_active_town(control, action_id)
	var recap := TownRules.build_town_action_recap(control, "order", action_id, action, result, before)
	if bool(recap.get("active", false)):
		control.flags["last_town_action_recap"] = recap.duplicate(true)
	return result

func _action_for_id(actions: Array, action_id: String) -> Dictionary:
	for action_value in actions:
		if action_value is Dictionary and String(action_value.get("id", "")) == action_id:
			return action_value.duplicate(true)
	return {}

func _icon_exact(button: Button, expected_path: String) -> bool:
	return button.icon != null and button.icon.resource_path == expected_path and button.expand_icon and button.get_theme_constant("icon_max_width") == 24

func _artifact_session(at_town: bool):
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	hero["artifacts"] = ArtifactRules.normalize_hero_artifacts({"equipped": {}, "inventory": [ARTIFACT_ID]})
	session.overworld["hero"] = hero
	var active_hero_id := String(session.overworld.get("active_hero_id", hero.get("id", "")))
	var player_heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for index in range(player_heroes.size()):
		if player_heroes[index] is Dictionary and String(player_heroes[index].get("id", "")) == active_hero_id:
			player_heroes[index] = hero.duplicate(true)
			break
	session.overworld["player_heroes"] = player_heroes
	if at_town:
		var town := _first_player_town(session)
		if not town.is_empty():
			_move_active_hero_to_town(session, town)
	return session

func _first_player_town(session) -> Dictionary:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("owner", "")) == "player":
			return town
	return {}

func _move_active_hero_to_town(session, town: Dictionary) -> void:
	var position := {"x": int(town.get("x", 0)), "y": int(town.get("y", 0))}
	session.overworld["hero_position"] = position.duplicate(true)
	var active_hero: Dictionary = session.overworld.get("hero", {})
	active_hero["position"] = position.duplicate(true)
	session.overworld["hero"] = active_hero
	var heroes: Array = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			heroes[index]["position"] = position.duplicate(true)
	session.overworld["player_heroes"] = heroes

func _all_unique(values: Array) -> bool:
	for index in range(values.size()):
		if values.find(values[index]) != index:
			return false
	return true

func _finish_case(shell: Node, result: Dictionary) -> Dictionary:
	if shell != null and is_instance_valid(shell):
		shell.queue_free()
		await get_tree().process_frame
	return result

func _fail(message: String, original_window_size: Vector2i) -> void:
	get_window().size = original_window_size
	SettingsService.set_ui_scale_percent(_original_ui_scale_percent)
	push_error(message)
	get_tree().quit(1)
