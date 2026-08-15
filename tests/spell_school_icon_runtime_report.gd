extends Node

const SessionDataScript = preload("res://scripts/core/SessionStateStore.gd")
const REPORT_ID := "SPELL_SCHOOL_ICON_RUNTIME_REPORT"
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const SURFACES := ["overworld", "town", "battle"]
const SURFACE_SPELL_IDS := {
	"overworld": "spell_waystride",
	"battle": "spell_stone_veil",
}
const EXPECTED_ICONS := {
	"beacon": "res://art/magic/runtime/schools/beacon.png",
	"mire": "res://art/magic/runtime/schools/mire.png",
	"lens": "res://art/magic/runtime/schools/lens.png",
	"root": "res://art/magic/runtime/schools/root.png",
	"furnace": "res://art/magic/runtime/schools/furnace.png",
	"veil": "res://art/magic/runtime/schools/veil.png",
	"old_measure": "res://art/magic/runtime/schools/old_measure.png",
}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_window_size := get_window().size
	var catalog := _catalog_contract()
	if not bool(catalog.get("ok", false)):
		_fail("Spell school icon catalog failed: %s" % JSON.stringify(catalog), original_window_size)
		return
	var rows := []
	for viewport_size in VIEWPORT_SIZES:
		for surface in SURFACES:
			var row: Dictionary = await _surface_case(viewport_size, surface)
			rows.append(row)
			if not bool(row.get("ok", false)):
				_fail("Spell school icon surface failed: %s" % JSON.stringify(row), original_window_size)
				return
	SessionState.reset_session()
	get_window().size = original_window_size
	await get_tree().process_frame
	await get_tree().process_frame
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": true, "catalog": catalog, "rows": rows})])
	get_tree().quit(0)

func _catalog_contract() -> Dictionary:
	var raw_manifest := ContentService.load_json(ContentService.SPELL_SCHOOL_ICONS_PATH)
	var manifest_rows: Array = raw_manifest.get("items", []) if raw_manifest.get("items", []) is Array else []
	var manifest_contract := []
	var manifest_ids := []
	var manifest_paths := []
	for row_value in manifest_rows:
		if not (row_value is Dictionary):
			continue
		var row: Dictionary = row_value
		var school_id := String(row.get("id", ""))
		var icon_path := String(row.get("icon_path", ""))
		var texture := load(icon_path) as Texture2D if ResourceLoader.exists(icon_path, "Texture2D") else null
		manifest_contract.append({
			"school_id": school_id,
			"icon_id": String(row.get("icon_id", "")),
			"icon_path": icon_path,
			"material_language": String(row.get("material_language", "")),
			"size": texture.get_size() if texture != null else Vector2.ZERO,
		})
		manifest_ids.append(school_id)
		manifest_paths.append(icon_path)
	var spells_raw := ContentService.load_json(ContentService.SPELLS_PATH)
	var spells: Array = spells_raw.get("items", []) if spells_raw.get("items", []) is Array else []
	var spell_rows := []
	for spell_value in spells:
		if not (spell_value is Dictionary):
			continue
		var spell: Dictionary = spell_value
		var spell_id := String(spell.get("id", ""))
		var school_id := String(spell.get("school_id", ""))
		var expected_path := String(EXPECTED_ICONS.get(school_id, ""))
		spell_rows.append({
			"spell_id": spell_id,
			"school_id": school_id,
			"resolved_path": SpellRules.spell_school_icon_path(spell_id),
			"expected_path": expected_path,
		})
	var sorted_ids := manifest_ids.duplicate()
	sorted_ids.sort()
	var sorted_expected_ids: Array = EXPECTED_ICONS.keys()
	sorted_expected_ids.sort()
	return {
		"ok": (
			manifest_contract.size() == 7
			and sorted_ids == sorted_expected_ids
			and _all_unique(manifest_paths)
			and manifest_contract.all(func(row): return String(row.get("icon_id", "")) == "spell_school_sigil_%s" % String(row.get("school_id", "")) and String(row.get("icon_path", "")) == String(EXPECTED_ICONS.get(String(row.get("school_id", "")), "")) and String(row.get("material_language", "")) != "" and row.get("size", Vector2.ZERO) == Vector2(128.0, 128.0))
			and spell_rows.size() == 112
			and spell_rows.all(func(row): return String(row.get("resolved_path", "")) == String(row.get("expected_path", "")) and String(row.get("resolved_path", "")) != "")
			and SpellRules.spell_id_for_action("cast_spell:spell_missing") == ""
			and SpellRules.spell_id_for_action("learn_spell:spell_missing") == ""
			and SpellRules.spell_school_icon_path("spell_missing") == ""
		),
		"school_count": manifest_contract.size(),
		"spell_count": spell_rows.size(),
		"distinct_icon_path_count": manifest_paths.size() if _all_unique(manifest_paths) else 0,
		"manifest": manifest_contract,
		"spells": spell_rows,
	}

func _surface_case(viewport_size: Vector2i, surface: String) -> Dictionary:
	get_window().size = viewport_size
	await get_tree().process_frame
	await get_tree().process_frame
	if get_window().size != viewport_size:
		return {"ok": false, "failure": "window_size", "surface": surface, "actual": get_window().size}
	var fixture := _surface_fixture(surface)
	var session = fixture.get("session")
	var spell_id := String(fixture.get("spell_id", ""))
	if session == null or spell_id == "":
		return {"ok": false, "failure": "fixture", "surface": surface, "fixture": fixture}
	SessionState.set_active_session(session)
	var scene_path := _surface_scene_path(surface)
	var shell = load(scene_path).instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	if surface == "overworld":
		shell.validation_open_command_drawer()
	elif surface == "town":
		var management_tabs := shell.get_node_or_null("%ManagementTabs") as TabContainer
		if management_tabs == null:
			return await _finish_case(shell, {"ok": false, "failure": "management_tabs", "surface": surface})
		management_tabs.current_tab = 2
	await get_tree().process_frame
	await get_tree().process_frame
	var live_session = shell.get("_session")
	if live_session == null:
		live_session = SessionState.ensure_active_session()
	var container := shell.get_node_or_null(_surface_container_path(surface)) as Container
	if container == null:
		return await _finish_case(shell, {"ok": false, "failure": "container", "surface": surface})
	var actions := _surface_actions(surface, live_session)
	var buttons := _button_contract(shell, container, actions, surface)
	var action_id := _surface_action_id(surface, spell_id)
	var action := _action_for_id(actions, action_id)
	var button := _button_for_action(shell, container, actions, surface, action_id)
	if action.is_empty() or button == null or button.disabled:
		return await _finish_case(shell, {"ok": false, "failure": "action_button", "surface": surface, "action_id": action_id, "actions": actions, "buttons": buttons})
	button.grab_focus()
	await get_tree().process_frame
	var focus_exact := get_viewport().gui_get_focus_owner() == button
	var expected_icon_path := SpellRules.spell_school_icon_path(spell_id)
	var selected_icon_exact := _icon_exact(button, expected_icon_path)
	var invalid_button := Button.new()
	invalid_button.text = "Invalid spell control"
	shell.call("_apply_spell_action_icon", invalid_button, {"id": _surface_action_id(surface, "spell_missing")})
	var invalid_fail_closed := invalid_button.icon == null and invalid_button.text == "Invalid spell control"
	invalid_button.free()
	var live_before: Dictionary = live_session.to_dict()
	var control = SessionDataScript.SessionData.new()
	control.from_dict(live_before.duplicate(true))
	var control_result := _apply_control_action(control, surface, action, spell_id)
	var save_before := SaveService.latest_loadable_summary()
	button.emit_signal("pressed")
	await get_tree().process_frame
	await get_tree().process_frame
	var save_after := SaveService.latest_loadable_summary()
	var live_after: Dictionary = live_session.to_dict()
	var row := {
		"ok": (
			bool(buttons.get("ok", false))
			and focus_exact
			and selected_icon_exact
			and invalid_fail_closed
			and bool(control_result.get("ok", false))
			and live_after == control.to_dict()
			and save_after == save_before
		),
		"viewport_size": viewport_size,
		"surface": surface,
		"spell_id": spell_id,
		"school_id": String(ContentService.get_spell(spell_id).get("school_id", "")),
		"action_id": action_id,
		"buttons": buttons,
		"focus_exact": focus_exact,
		"selected_icon_exact": selected_icon_exact,
		"invalid_fail_closed": invalid_fail_closed,
		"control_ok": bool(control_result.get("ok", false)),
		"session_exact": live_after == control.to_dict(),
		"save_authority_exact": save_after == save_before,
	}
	if not bool(row.get("ok", false)):
		row["control_result"] = control_result
		row["session_differences"] = _recursive_exact_differences(control.to_dict(), live_after)
	return await _finish_case(shell, row)

func _surface_fixture(surface: String) -> Dictionary:
	if surface == "town":
		var town_session = _base_session()
		var town := _first_player_town(town_session)
		if town.is_empty():
			return {}
		var built_buildings: Array = town.get("built_buildings", []) if town.get("built_buildings", []) is Array else []
		if "building_lantern_archive" not in built_buildings:
			built_buildings.append("building_lantern_archive")
		town["built_buildings"] = built_buildings
		_move_active_hero_to_town(town_session, town)
		_set_active_hero_spellbook(town_session, [])
		var learning_actions := TownRules.get_spell_learning_actions(town_session)
		for action_value in learning_actions:
			if action_value is Dictionary:
				var spell_id := SpellRules.spell_id_for_action(String(action_value.get("id", "")))
				if spell_id != "":
					return {"session": town_session, "spell_id": spell_id}
		return {}
	if surface == "battle":
		var battle_session = _base_session()
		var battle_spell_id := String(SURFACE_SPELL_IDS.get("battle", ""))
		_set_active_hero_spellbook(battle_session, [battle_spell_id])
		var enemy_town := _first_enemy_town(battle_session)
		if enemy_town.is_empty():
			return {}
		battle_session.battle = BattleRules.create_town_assault_payload(battle_session, String(enemy_town.get("placement_id", "")))
		_stage_player_turn(battle_session.battle)
		return {"session": battle_session, "spell_id": battle_spell_id}
	var overworld_session = _base_session()
	var overworld_spell_id := String(SURFACE_SPELL_IDS.get("overworld", ""))
	_set_active_hero_spellbook(overworld_session, [overworld_spell_id])
	var overworld_hero: Dictionary = overworld_session.overworld.get("hero", {}) if overworld_session.overworld.get("hero", {}) is Dictionary else {}
	overworld_hero["movement"] = {"current": 2, "max": 12}
	overworld_session.overworld["hero"] = overworld_hero
	overworld_session.overworld["movement"] = {"current": 2, "max": 12}
	var active_hero_id := String(overworld_session.overworld.get("active_hero_id", overworld_hero.get("id", "")))
	var overworld_heroes: Array = overworld_session.overworld.get("player_heroes", []) if overworld_session.overworld.get("player_heroes", []) is Array else []
	for index in range(overworld_heroes.size()):
		if overworld_heroes[index] is Dictionary and String(overworld_heroes[index].get("id", "")) == active_hero_id:
			overworld_heroes[index] = overworld_hero.duplicate(true)
			break
	overworld_session.overworld["player_heroes"] = overworld_heroes
	return {"session": overworld_session, "spell_id": overworld_spell_id}

func _base_session():
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	return session

func _set_active_hero_spellbook(session, spell_ids: Array) -> void:
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	hero = SpellRules.ensure_hero_spellbook(hero)
	var spellbook: Dictionary = hero.get("spellbook", {}) if hero.get("spellbook", {}) is Dictionary else {}
	spellbook["known_spell_ids"] = spell_ids.duplicate()
	spellbook["mana"] = {"current": 40, "max": 40}
	hero["spellbook"] = spellbook
	session.overworld["hero"] = hero
	var active_hero_id := String(session.overworld.get("active_hero_id", hero.get("id", "")))
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == active_hero_id:
			heroes[index] = hero.duplicate(true)
			break
	session.overworld["player_heroes"] = heroes

func _stage_player_turn(battle: Dictionary) -> void:
	var player_id := ""
	var enemy_id := ""
	for stack_value in battle.get("stacks", []):
		if not (stack_value is Dictionary):
			continue
		if player_id == "" and String(stack_value.get("side", "")) == "player":
			player_id = String(stack_value.get("battle_id", ""))
		elif enemy_id == "" and String(stack_value.get("side", "")) == "enemy":
			enemy_id = String(stack_value.get("battle_id", ""))
	battle["active_stack_id"] = player_id
	battle["selected_target_id"] = enemy_id
	battle["commander_spell_cast_rounds"] = {}

func _surface_scene_path(surface: String) -> String:
	match surface:
		"town":
			return "res://scenes/town/TownShell.tscn"
		"battle":
			return "res://scenes/battle/BattleShell.tscn"
		_:
			return "res://scenes/overworld/OverworldShell.tscn"

func _surface_container_path(surface: String) -> String:
	return "%StudyActions" if surface == "town" else "%SpellActions"

func _surface_actions(surface: String, session) -> Array:
	match surface:
		"town":
			return TownRules.get_spell_learning_actions(session)
		"battle":
			return BattleRules.get_spell_actions(session)
		_:
			return OverworldRules.get_spell_actions(session)

func _surface_action_id(surface: String, spell_id: String) -> String:
	return "%s:%s" % ["learn_spell" if surface == "town" else "cast_spell", spell_id]

func _action_for_id(actions: Array, action_id: String) -> Dictionary:
	for action_value in actions:
		if action_value is Dictionary and String(action_value.get("id", "")) == action_id:
			return action_value.duplicate(true)
	return {}

func _button_contract(shell: Node, container: Container, actions: Array, surface: String) -> Dictionary:
	var button_rows := []
	var buttons := []
	for child in container.get_children():
		if child is Button:
			buttons.append(child)
	for index in range(actions.size()):
		var action: Dictionary = actions[index] if actions[index] is Dictionary else {}
		var button: Button = buttons[index] if index < buttons.size() else null
		var spell_id := SpellRules.spell_id_for_action(String(action.get("id", "")))
		var expected_path := SpellRules.spell_school_icon_path(spell_id)
		var expected_text := _expected_button_text(shell, surface, action)
		var expected_tooltip := _expected_button_tooltip(shell, surface, action)
		var rect := button.get_global_rect() if button != null else Rect2()
		button_rows.append({
			"action_id": String(action.get("id", "")),
			"spell_id": spell_id,
			"expected_path": expected_path,
			"present": button != null,
			"copy_exact": button != null and button.text == expected_text and button.tooltip_text == expected_tooltip,
			"disabled_exact": button != null and button.disabled == bool(action.get("disabled", false)),
			"icon_exact": button != null and _icon_exact(button, expected_path),
			"focusable": button != null and button.focus_mode != Control.FOCUS_NONE,
			"visible": button != null and button.is_visible_in_tree(),
			"contained": button != null and get_viewport().get_visible_rect().encloses(rect),
			"rect": rect,
		})
	return {
		"ok": button_rows.size() == actions.size() and buttons.size() == actions.size() and button_rows.all(func(row): return bool(row.get("present", false)) and bool(row.get("copy_exact", false)) and bool(row.get("disabled_exact", false)) and bool(row.get("icon_exact", false)) and bool(row.get("focusable", false)) and bool(row.get("visible", false)) and bool(row.get("contained", false))),
		"action_count": actions.size(),
		"button_count": buttons.size(),
		"rows": button_rows,
	}

func _button_for_action(shell: Node, container: Container, actions: Array, surface: String, action_id: String) -> Button:
	var expected_action_index := -1
	for index in range(actions.size()):
		if actions[index] is Dictionary and String(actions[index].get("id", "")) == action_id:
			expected_action_index = index
			break
	if expected_action_index < 0:
		return null
	var buttons := []
	for child in container.get_children():
		if child is Button:
			buttons.append(child)
	return buttons[expected_action_index] if expected_action_index < buttons.size() else null

func _expected_button_text(shell: Node, surface: String, action: Dictionary) -> String:
	if surface == "battle":
		return String(shell.call("_battle_spell_action_button_text", action))
	return String(action.get("label", action.get("id", "Action")))

func _expected_button_tooltip(shell: Node, surface: String, action: Dictionary) -> String:
	if surface == "battle":
		return String(shell.call("_battle_spell_action_tooltip", action))
	if surface == "town":
		return String(shell.call("_town_action_button_tooltip", action, "study"))
	var spell_check: Dictionary = shell.call("_spell_action_check_surface", action)
	return String(shell.call("_join_tooltip_sections", [String(action.get("summary", "")), String(spell_check.get("tooltip_text", ""))]))

func _apply_control_action(control, surface: String, action: Dictionary, spell_id: String) -> Dictionary:
	var action_id := String(action.get("id", ""))
	if surface == "overworld":
		var result := OverworldRules.cast_overworld_spell(control, spell_id)
		var recap: Dictionary = result.get("post_action_recap", {}) if result.get("post_action_recap", {}) is Dictionary else {}
		if not recap.is_empty():
			control.flags["last_overworld_action_recap"] = recap.duplicate(true)
		return result
	if surface == "town":
		var before := TownRules.town_action_consequence_signature(control)
		var result := TownRules.learn_spell_at_active_town(control, spell_id)
		var recap := TownRules.build_town_action_recap(control, "order", action_id, action, result, before)
		if bool(recap.get("active", false)):
			control.flags["last_town_action_recap"] = recap.duplicate(true)
		return result
	var context := BattleRules.post_action_recap_context(control, action_id)
	var result := BattleRules.cast_player_spell(control, spell_id)
	var recap := BattleRules.post_action_recap_payload(control, result, action_id, context)
	if not recap.is_empty():
		control.flags["last_battle_action_recap"] = recap.duplicate(true)
	return result

func _icon_exact(button: Button, expected_path: String) -> bool:
	return expected_path != "" and button.icon != null and button.icon.resource_path == expected_path and button.expand_icon and button.get_theme_constant("icon_max_width") == 24

func _first_player_town(session) -> Dictionary:
	for town_value in session.overworld.get("towns", []):
		if town_value is Dictionary and String(town_value.get("owner", "")) == "player":
			return town_value
	return {}

func _first_enemy_town(session) -> Dictionary:
	for town_value in session.overworld.get("towns", []):
		if town_value is Dictionary and String(town_value.get("owner", "")) == "enemy":
			return town_value
	return {}

func _move_active_hero_to_town(session, town: Dictionary) -> void:
	var position := {"x": int(town.get("x", 0)), "y": int(town.get("y", 0))}
	session.overworld["hero_position"] = position.duplicate(true)
	var hero: Dictionary = session.overworld.get("hero", {})
	hero["position"] = position.duplicate(true)
	session.overworld["hero"] = hero
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
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

func _recursive_exact_differences(expected: Variant, actual: Variant, path: String = "$") -> Array:
	var differences := []
	if typeof(expected) != typeof(actual):
		return [{"path": path, "expected_type": typeof(expected), "actual_type": typeof(actual)}]
	if expected is Dictionary:
		var keys: Array = expected.keys()
		for key in actual.keys():
			if key not in keys:
				keys.append(key)
		keys.sort_custom(func(left, right): return String(left) < String(right))
		for key in keys:
			if not expected.has(key) or not actual.has(key):
				differences.append({"path": "%s[%s]" % [path, JSON.stringify(key)], "expected_present": expected.has(key), "actual_present": actual.has(key)})
			else:
				differences.append_array(_recursive_exact_differences(expected.get(key), actual.get(key), "%s[%s]" % [path, JSON.stringify(key)]))
		return differences
	if expected is Array:
		if expected.size() != actual.size():
			differences.append({"path": path, "expected_size": expected.size(), "actual_size": actual.size()})
		for index in range(min(expected.size(), actual.size())):
			differences.append_array(_recursive_exact_differences(expected[index], actual[index], "%s[%d]" % [path, index]))
		return differences
	if expected != actual:
		differences.append({"path": path, "expected": expected, "actual": actual})
	return differences

func _fail(message: String, original_window_size: Vector2i) -> void:
	get_window().size = original_window_size
	push_error(message)
	get_tree().quit(1)
