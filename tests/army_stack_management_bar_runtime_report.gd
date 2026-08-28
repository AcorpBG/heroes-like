extends Node

const REPORT_ID := "ARMY_STACK_MANAGEMENT_BAR_RUNTIME_REPORT"
const SAVE_SLOT := 9
const VIEWPORTS := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const TOWN_PLACEMENT_ID := "riverwatch_hold"
const UNIT_A := "unit_embercourt_fordhook_cadets"
const UNIT_B := "unit_embercourt_lantern_sappers"
const UNIT_C := "unit_embercourt_bargebow_crews"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_window_size := get_window().size
	var direct := _direct_rules_save_battle_case()
	if direct.is_empty():
		return
	var overworld_rows := []
	var town_rows := []
	for viewport in VIEWPORTS:
		var overworld_row := await _overworld_ui_case(viewport)
		if overworld_row.is_empty():
			return
		overworld_rows.append(overworld_row)
		var town_row := await _town_ui_case(viewport)
		if town_row.is_empty():
			return
		town_rows.append(town_row)
	get_window().size = original_window_size
	await get_tree().process_frame
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"report_id": REPORT_ID,
		"slot_count": HeroCommandRules.ARMY_SLOT_COUNT,
		"viewports": [[1280, 720], [1920, 1080]],
		"direct_rules_save_battle": direct,
		"overworld_rows": overworld_rows,
		"town_rows": town_rows,
		"save_version": SessionStateStore.SAVE_VERSION,
	})])
	get_tree().quit(0)

func _direct_rules_save_battle_case() -> Dictionary:
	var session = _fixture(true)
	var town := _town(session)
	var hero_id := String(session.overworld.get("active_hero_id", ""))
	var baseline_totals := _army_totals(session)
	var split := HeroCommandRules.manage_army_slots(session, town, hero_id, 0, hero_id, 2, "half")
	if not _require(bool(split.get("ok", false)) and String(split.get("operation", "")) == "split", "Half split failed.", split):
		return {}
	var merge := HeroCommandRules.manage_army_slots(session, town, hero_id, 2, hero_id, 3, "all")
	if not _require(bool(merge.get("ok", false)) and String(merge.get("operation", "")) == "merge", "Matching stack merge failed.", merge):
		return {}
	var swap := HeroCommandRules.manage_army_slots(session, town, hero_id, 1, hero_id, 3, "all")
	if not _require(bool(swap.get("ok", false)) and String(swap.get("operation", "")) == "swap", "Different-unit stack swap failed.", swap):
		return {}
	var move := HeroCommandRules.manage_army_slots(session, town, hero_id, 1, hero_id, 6, "all")
	if not _require(bool(move.get("ok", false)) and String(move.get("operation", "")) == "move", "Whole-stack positional move failed.", move):
		return {}
	var cross_split := HeroCommandRules.manage_army_slots(session, town, HeroCommandRules.HOLDER_GARRISON, 0, hero_id, 2, "1")
	if not _require(bool(cross_split.get("ok", false)) and String(cross_split.get("operation", "")) == "split", "Garrison-to-hero split failed.", cross_split):
		return {}
	var cross_swap := HeroCommandRules.manage_army_slots(session, town, HeroCommandRules.HOLDER_GARRISON, 4, hero_id, 6, "all")
	if not _require(bool(cross_swap.get("ok", false)) and String(cross_swap.get("operation", "")) == "swap", "Garrison-to-hero swap failed.", cross_swap):
		return {}
	var merge_after_swap := HeroCommandRules.manage_army_slots(session, town, hero_id, 6, hero_id, 3, "all")
	if not _require(bool(merge_after_swap.get("ok", false)) and String(merge_after_swap.get("operation", "")) == "merge", "Post-swap matching merge failed.", merge_after_swap):
		return {}
	var invalid := HeroCommandRules.manage_army_slots(session, town, hero_id, 0, hero_id, 3, "half")
	if not _require(not bool(invalid.get("ok", false)), "Split into a different occupied unit did not fail closed.", invalid):
		return {}
	if not _require(_army_totals(session) == baseline_totals, "Army management changed total unit authority.", {"before": baseline_totals, "after": _army_totals(session)}):
		return {}
	var over_capacity = _fixture(false)
	var over_capacity_hero_id := String(over_capacity.overworld.get("active_hero_id", ""))
	var over_capacity_stacks := []
	for slot_index in range(HeroCommandRules.ARMY_SLOT_COUNT + 1):
		over_capacity_stacks.append({"unit_id": UNIT_A if slot_index % 2 == 0 else UNIT_B, "count": slot_index + 1, "slot_index": slot_index})
	_set_hero_stacks(over_capacity, over_capacity_hero_id, over_capacity_stacks)
	var over_capacity_snapshot := HeroCommandRules.army_slot_snapshot(over_capacity, {}, over_capacity_hero_id)
	var over_capacity_result := HeroCommandRules.manage_army_slots(over_capacity, {}, over_capacity_hero_id, 0, over_capacity_hero_id, 6, "all")
	if not _require(not bool(over_capacity_snapshot.get("capacity_valid", true)) and not bool(over_capacity_result.get("ok", false)) and _hero_raw_troop_total(over_capacity, over_capacity_hero_id) == 36, "Seven-slot capacity did not fail closed without losing troops.", {"snapshot": over_capacity_snapshot, "result": over_capacity_result}):
		return {}

	var hero_slots_before_save := HeroCommandRules.army_slot_snapshot(session, town, hero_id)
	var garrison_slots_before_save := HeroCommandRules.army_slot_snapshot(session, town, HeroCommandRules.HOLDER_GARRISON)
	var save_result: Dictionary = SaveService.save_runtime_manual_session(session, SAVE_SLOT)
	var restored = SaveService.restore_manual_session(SAVE_SLOT)
	if not _require(bool(save_result.get("ok", false)) and restored != null, "Army slot state did not pass the real manual save/restore boundary.", save_result):
		return {}
	OverworldRules.normalize_overworld_state(restored)
	var restored_town := _town(restored)
	if not _require(
		HeroCommandRules.army_slot_snapshot(restored, restored_town, hero_id) == hero_slots_before_save
		and HeroCommandRules.army_slot_snapshot(restored, restored_town, HeroCommandRules.HOLDER_GARRISON) == garrison_slots_before_save,
		"Army slots changed across manual save/restore.",
		{"hero_before": hero_slots_before_save, "hero_after": HeroCommandRules.army_slot_snapshot(restored, restored_town, hero_id)}
	):
		return {}

	OverworldRules.clear_active_town_visit(restored)
	restored.game_state = "overworld"
	var encounter := _first_encounter(restored)
	restored.battle = BattleRules.create_battle_payload(restored, encounter)
	restored.game_state = "battle"
	var player_slots := []
	for stack_value in restored.battle.get("stacks", []):
		if stack_value is Dictionary and String(stack_value.get("side", "")) == "player":
			player_slots.append(int(stack_value.get("army_slot_index", -1)))
	if not _require(player_slots == _occupied_slot_indexes(hero_slots_before_save), "Battle entry did not preserve arranged hero stack order.", {"expected": _occupied_slot_indexes(hero_slots_before_save), "actual": player_slots}):
		return {}
	for index in range(restored.battle.get("stacks", []).size()):
		var stack = restored.battle.get("stacks", [])[index]
		if stack is Dictionary and String(stack.get("side", "")) == "enemy":
			stack["total_health"] = 0
			restored.battle["stacks"][index] = stack
	var outcome := BattleRules.resolve_if_battle_ready(restored)
	if not _require(String(outcome.get("state", "")) == "victory", "Battle survivor handoff did not resolve through a real victory.", outcome):
		return {}
	var survivor_snapshot := HeroCommandRules.army_slot_snapshot(restored, {}, hero_id)
	if not _require(_occupied_slot_indexes(survivor_snapshot) == player_slots and _army_totals(restored) == baseline_totals, "Battle survivor handoff corrupted slot order or unit totals.", survivor_snapshot):
		return {}
	return {
		"move_swap_merge_split": true,
		"invalid_split_rejected": true,
		"over_capacity_failed_closed": true,
		"cross_holder_exact": true,
		"manual_save_restore_exact": true,
		"battle_entry_order_exact": true,
		"battle_survivor_slots_exact": true,
		"player_slot_order": player_slots,
	}

func _overworld_ui_case(viewport: Vector2i) -> Dictionary:
	get_window().size = viewport
	await get_tree().process_frame
	await get_tree().process_frame
	var session = _fixture(false)
	SessionState.set_active_session(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var bar = shell.get_node_or_null("%ArmyManagement")
	var before: Dictionary = shell.call("validation_army_management_snapshot")
	if not _require(_bar_contract_exact(before, 1), "Overworld hero army bar contract failed.", before):
		shell.queue_free()
		return {}
	var hero_id := String(SessionState.ensure_active_session().overworld.get("active_hero_id", ""))
	var source: Button = _slot_button(bar, hero_id, 0)
	var destination: Button = _slot_button(bar, hero_id, 5)
	if not _require(source != null and destination != null, "Overworld army bar buttons were not live."):
		shell.queue_free()
		return {}
	source.grab_focus()
	await get_tree().process_frame
	await _press_ui_accept()
	destination.grab_focus()
	await get_tree().process_frame
	await _press_ui_accept()
	await get_tree().process_frame
	var after: Dictionary = shell.call("validation_army_management_snapshot")
	var moved_slot := _slot(after, hero_id, 5)
	if not _require(bool(moved_slot.get("occupied", false)) and String(moved_slot.get("unit_id", "")) == UNIT_A and int(moved_slot.get("count", 0)) == 10, "Overworld click-to-arrange did not move the live stack.", after):
		shell.queue_free()
		return {}
	var panel_rect: Rect2 = bar.get_global_rect()
	var contained := _buttons_contained(after, panel_rect) and get_viewport().get_visible_rect().encloses(panel_rect)
	var screenshot := _capture_if_requested("overworld", viewport)
	shell.queue_free()
	await get_tree().process_frame
	if not _require(contained, "Overworld army slots escaped their live panel.", after):
		return {}
	return {"ok": true, "viewport": [viewport.x, viewport.y], "slots": 7, "icons_loaded": true, "focusable": true, "click_move_exact": true, "contained": true, "screenshot": screenshot}

func _town_ui_case(viewport: Vector2i) -> Dictionary:
	get_window().size = viewport
	await get_tree().process_frame
	await get_tree().process_frame
	var session = _fixture(true)
	SessionState.set_active_session(session)
	var shell = load("res://scenes/town/TownShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	var tabs = shell.get_node_or_null("%ManagementTabs")
	if tabs != null:
		tabs.current_tab = 4
	await get_tree().process_frame
	await get_tree().process_frame
	var bar = shell.get_node_or_null("%ArmyManagement")
	var before: Dictionary = shell.call("validation_army_management_snapshot")
	if not _require(_bar_contract_exact(before, 2), "Town hero/garrison army bars failed their live contract.", before):
		shell.queue_free()
		return {}
	var hero_id := String(SessionState.ensure_active_session().overworld.get("active_hero_id", ""))
	var mode_button: Button = _text_button(bar, "Split Half")
	var source: Button = _slot_button(bar, HeroCommandRules.HOLDER_GARRISON, 0)
	var destination: Button = _slot_button(bar, hero_id, 2)
	if not _require(mode_button != null and source != null and destination != null, "Town split controls were not live."):
		shell.queue_free()
		return {}
	mode_button.grab_focus()
	await get_tree().process_frame
	await _press_ui_accept()
	source.grab_focus()
	await get_tree().process_frame
	await _press_ui_accept()
	destination.grab_focus()
	await get_tree().process_frame
	await _press_ui_accept()
	await get_tree().process_frame
	var after: Dictionary = shell.call("validation_army_management_snapshot")
	var garrison_source := _slot(after, HeroCommandRules.HOLDER_GARRISON, 0)
	var hero_split := _slot(after, hero_id, 2)
	if not _require(int(garrison_source.get("count", 0)) == 4 and String(hero_split.get("unit_id", "")) == UNIT_C and int(hero_split.get("count", 0)) == 4, "Town click-to-split did not mutate the exact holders.", after):
		shell.queue_free()
		return {}
	var panel_rect: Rect2 = bar.get_global_rect()
	var contained := _buttons_contained(after, panel_rect) and get_viewport().get_visible_rect().encloses(panel_rect)
	var screenshot := _capture_if_requested("town", viewport)
	shell.queue_free()
	await get_tree().process_frame
	if not _require(contained, "Town army slots escaped their live panel.", after):
		return {}
	return {"ok": true, "viewport": [viewport.x, viewport.y], "holders": 2, "slots": 14, "icons_loaded": true, "focusable": true, "click_split_exact": true, "contained": true, "screenshot": screenshot}

func _capture_if_requested(surface: String, viewport: Vector2i) -> String:
	var output_dir := OS.get_environment("HEROES_ARMY_STACK_BAR_CAPTURE_DIR").strip_edges()
	if output_dir == "" or DisplayServer.get_name() == "headless":
		return ""
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		return ""
	var path := output_dir.path_join("%s_%dx%d.png" % [surface, viewport.x, viewport.y])
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(path) != OK:
		return ""
	return path

func _fixture(at_town: bool):
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var hero_id := String(session.overworld.get("active_hero_id", ""))
	_set_hero_stacks(session, hero_id, [
		{"unit_id": UNIT_A, "count": 10, "slot_index": 0},
		{"unit_id": UNIT_B, "count": 4, "slot_index": 1},
		{"unit_id": UNIT_A, "count": 6, "slot_index": 3},
	])
	_set_town_garrison(session, [
		{"unit_id": UNIT_C, "count": 8, "slot_index": 0},
		{"unit_id": UNIT_B, "count": 3, "slot_index": 4},
	])
	if at_town:
		_move_active_hero_to_town(session, _town(session))
	else:
		OverworldRules.clear_active_town_visit(session)
		session.game_state = "overworld"
	return session

func _set_hero_stacks(session, hero_id: String, stacks: Array) -> void:
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == hero_id:
			var hero: Dictionary = heroes[index].duplicate(true)
			var army: Dictionary = hero.get("army", {}).duplicate(true) if hero.get("army", {}) is Dictionary else {}
			army["stacks"] = stacks.duplicate(true)
			hero["army"] = army
			heroes[index] = hero
	session.overworld["player_heroes"] = heroes
	var active := HeroCommandRules.hero_by_id(session, hero_id)
	session.overworld["hero"] = active.duplicate(true)
	session.overworld["army"] = active.get("army", {}).duplicate(true)
	HeroCommandRules.normalize_session(session)

func _set_town_garrison(session, stacks: Array) -> void:
	var towns: Array = session.overworld.get("towns", []) if session.overworld.get("towns", []) is Array else []
	for index in range(towns.size()):
		if towns[index] is Dictionary and String(towns[index].get("placement_id", "")) == TOWN_PLACEMENT_ID:
			var town: Dictionary = towns[index].duplicate(true)
			town["garrison"] = stacks.duplicate(true)
			towns[index] = town
	session.overworld["towns"] = towns

func _move_active_hero_to_town(session, town: Dictionary) -> void:
	var position := {"x": int(town.get("x", 0)), "y": int(town.get("y", 0))}
	session.overworld["hero_position"] = position.duplicate(true)
	var hero_id := String(session.overworld.get("active_hero_id", ""))
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == hero_id:
			var hero: Dictionary = heroes[index].duplicate(true)
			hero["position"] = position.duplicate(true)
			heroes[index] = hero
	session.overworld["player_heroes"] = heroes
	var active := HeroCommandRules.hero_by_id(session, hero_id)
	session.overworld["hero"] = active.duplicate(true)
	session.overworld["hero_position"] = position.duplicate(true)
	HeroCommandRules.normalize_session(session)
	var visit := OverworldRules.set_active_town_visit(session, TOWN_PLACEMENT_ID)
	if not bool(visit.get("ok", false)):
		_require(false, "Could not activate the Town fixture.", visit)
	session.game_state = "town"

func _town(session) -> Dictionary:
	for value in session.overworld.get("towns", []):
		if value is Dictionary and String(value.get("placement_id", "")) == TOWN_PLACEMENT_ID:
			return value
	return {}

func _first_encounter(session) -> Dictionary:
	for value in session.overworld.get("encounters", []):
		if value is Dictionary and not bool(value.get("resolved", false)):
			return value
	return {}

func _army_totals(session) -> Dictionary:
	var totals := {}
	var hero_id := String(session.overworld.get("active_hero_id", ""))
	for snapshot in [
		HeroCommandRules.army_slot_snapshot(session, _town(session), hero_id),
		HeroCommandRules.army_slot_snapshot(session, _town(session), HeroCommandRules.HOLDER_GARRISON),
	]:
		for slot_value in snapshot.get("slots", []):
			if slot_value is Dictionary and bool(slot_value.get("occupied", false)):
				var unit_id := String(slot_value.get("unit_id", ""))
				totals[unit_id] = int(totals.get(unit_id, 0)) + int(slot_value.get("count", 0))
	return totals

func _hero_raw_troop_total(session, hero_id: String) -> int:
	var total := 0
	var hero := HeroCommandRules.hero_by_id(session, hero_id)
	for stack_value in hero.get("army", {}).get("stacks", []):
		if stack_value is Dictionary:
			total += max(0, int(stack_value.get("count", 0)))
	return total

func _occupied_slot_indexes(snapshot: Dictionary) -> Array:
	var result := []
	for slot_value in snapshot.get("slots", []):
		if slot_value is Dictionary and bool(slot_value.get("occupied", false)):
			result.append(int(slot_value.get("slot_index", -1)))
	return result

func _bar_contract_exact(snapshot: Dictionary, holder_count: int) -> bool:
	var buttons: Array = snapshot.get("buttons", []) if snapshot.get("buttons", []) is Array else []
	if String(snapshot.get("model", "")) != "authoritative_seven_slot_army_bar" or int(snapshot.get("holder_count", 0)) != holder_count or int(snapshot.get("slot_count_per_holder", 0)) != 7 or buttons.size() != holder_count * 7:
		return false
	var occupied_count := 0
	for button_value in buttons:
		if not (button_value is Dictionary) or int(button_value.get("focus_mode", 0)) != Control.FOCUS_ALL or bool(button_value.get("disabled", false)):
			return false
		var key := String(button_value.get("key", ""))
		var slot := _slot_from_key(snapshot, key)
		if bool(slot.get("occupied", false)):
			occupied_count += 1
			if not bool(button_value.get("icon_loaded", false)) or int(slot.get("count", 0)) <= 0:
				return false
	return occupied_count > 0

func _buttons_contained(snapshot: Dictionary, panel_rect: Rect2) -> bool:
	for button_value in snapshot.get("buttons", []):
		if not (button_value is Dictionary):
			return false
		var rect_value: Dictionary = button_value.get("rect", {}) if button_value.get("rect", {}) is Dictionary else {}
		var rect := Rect2(float(rect_value.get("x", 0.0)), float(rect_value.get("y", 0.0)), float(rect_value.get("width", 0.0)), float(rect_value.get("height", 0.0)))
		if rect.size.x < 36.0 or rect.size.y < 46.0 or not panel_rect.encloses(rect):
			return false
	return true

func _slot(snapshot: Dictionary, holder_id: String, slot_index: int) -> Dictionary:
	for holder_value in snapshot.get("holders", []):
		if not (holder_value is Dictionary) or String(holder_value.get("holder_id", "")) != holder_id:
			continue
		var slots: Array = holder_value.get("slots", []) if holder_value.get("slots", []) is Array else []
		return slots[slot_index] if slot_index >= 0 and slot_index < slots.size() and slots[slot_index] is Dictionary else {}
	return {}

func _slot_from_key(snapshot: Dictionary, key: String) -> Dictionary:
	var split := key.rsplit(":", true, 1)
	if split.size() != 2:
		return {}
	return _slot(snapshot, String(split[0]), int(split[1]))

func _slot_button(root: Node, holder_id: String, slot_index: int) -> Button:
	if root == null:
		return null
	for child in root.find_children("*", "Button", true, false):
		if String(child.get_meta("holder_id", "")) == holder_id and int(child.get_meta("slot_index", -1)) == slot_index:
			return child as Button
	return null

func _text_button(root: Node, text: String) -> Button:
	if root == null:
		return null
	for child in root.find_children("*", "Button", true, false):
		if String(child.text) == text:
			return child as Button
	return null

func _press_ui_accept() -> void:
	var pressed := InputEventAction.new()
	pressed.action = &"ui_accept"
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await get_tree().process_frame
	var released := InputEventAction.new()
	released.action = &"ui_accept"
	released.pressed = false
	Input.parse_input_event(released)
	await get_tree().process_frame

func _require(condition: bool, message: String, evidence: Variant = {}) -> bool:
	if condition:
		return true
	push_error("%s %s" % [message, JSON.stringify(evidence)])
	get_tree().quit(1)
	return false
