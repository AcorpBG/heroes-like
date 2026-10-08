extends Node
## Town garrison rows (docs/town-garrison-rows.md) on a generated skirmish: the
## HoMM garrison/visiting hero rules, the save round trip and one-time migration,
## the Town screen army panel (rows, command squares, resource bar, town list,
## hero sheet, slot and portrait orders) and the overworld garrison medallion
## and hero-list badge.

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const LevelRules = preload("res://scripts/core/OverworldLevelRules.gd")
const TownShellScene = preload("res://scenes/town/TownShell.tscn")
const OverworldShellScene = preload("res://scenes/overworld/OverworldShell.tscn")
const REPORT_ID := "TOWN_GARRISON_ROWS_REPORT"
const SEED := "town-garrison-rows-20261008"
const PLAYER_FACTION_ID := "faction_embercourt"
const PLAYER_HERO_ID := "hero_caelen"

var _checks := 0
var _failures := []

func _ready() -> void:
	call_deferred("_run")

func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame

func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		push_error("%s check failed: %s" % [REPORT_ID, label])

func _run() -> void:
	var session = _start_session()
	if session == null:
		_finish()
		return
	var town := _player_town(session)
	_check(not town.is_empty(), "the generated map gives the player a town")
	if town.is_empty():
		_finish()
		return
	town["built_buildings"].append(HeroCommandRules.HALL_BUILDING_ID)
	session.overworld["resources"]["gold"] = int(session.overworld["resources"].get("gold", 0)) + 50000
	var primary_id := String(session.overworld.get("active_hero_id", ""))
	_station(session, primary_id, town)
	var second_id := _add_second_hero(session, town, primary_id)
	_check(second_id != "", "a second commander joins at the town")
	HeroCommandRules.set_active_hero(session, primary_id)
	_station(session, second_id, town)
	_rules_section(session, town, primary_id, second_id)
	session = _save_section(session, town, primary_id, second_id)
	town = _player_town(session)
	_migration_section(session, primary_id, second_id)
	await _town_ui_section(session, primary_id, second_id)
	await _overworld_section(SessionState.ensure_active_session(), primary_id, second_id)
	_finish()

# --- rules -----------------------------------------------------------------

func _rules_section(session, town: Dictionary, primary_id: String, second_id: String) -> void:
	_check(String(HeroCommandRules.town_visiting_hero(session, town).get("id", "")) == primary_id, "the active hero visits at the gate")
	_check(HeroCommandRules.town_garrison_hero(session, town).is_empty(), "no garrison hero before an order")
	_check(HeroCommandRules.town_garrison_holder_id(session, town) == HeroCommandRules.HOLDER_GARRISON, "the garrison row is the town's own troops")
	var second_army := _army_stacks(session, second_id)
	var shared_unit := String(second_army[0].get("unit_id", "")) if not second_army.is_empty() else ""
	var new_unit := _unit_not_in(second_army)
	_set_town_garrison(session, town, [{"unit_id": shared_unit, "count": 4}, {"unit_id": new_unit, "count": 3}])
	var before_troops := _troops(_army_stacks(session, second_id))
	var enter: Dictionary = HeroCommandRules.set_town_garrison_hero(session, town, second_id)
	_check(bool(enter.get("ok", false)) and String(enter.get("operation", "")) == "garrison", "the second hero enters the garrison: %s" % enter.get("message", ""))
	town = _player_town(session)
	_check(String(HeroCommandRules.town_garrison_hero(session, town).get("id", "")) == second_id, "the second hero holds the garrison")
	_check(HeroCommandRules._valid_stack_count(town.get("garrison", [])) == 0, "the town's own garrison troops joined the hero")
	_check(_troops(_army_stacks(session, second_id)) == before_troops + 7, "the garrison hero's army took the 7 garrison troops")
	_check(_has_unit(_army_stacks(session, second_id), new_unit), "a new unit took a free slot")
	var defender := HeroCommandRules.town_defending_hero(session, town)
	_check(String(defender.get("id", "")) == second_id, "the garrison hero defends the town")
	var force := HeroCommandRules.town_defense_force(session, town)
	_check(int(force.get("troops", 0)) == _troops(_army_stacks(session, second_id)), "the defense force is the garrison hero's army")
	var positions := {}
	for row in HeroCommandRules.hero_positions(session):
		positions[String(row.get("id", ""))] = String(row.get("garrison_town_placement_id", ""))
	_check(positions.get(second_id, "") == String(town.get("placement_id", "")) and positions.get(primary_id, "x") == "", "hero positions mark only the garrison hero")
	var swap: Dictionary = HeroCommandRules.set_town_garrison_hero(session, town, primary_id)
	town = _player_town(session)
	_check(bool(swap.get("ok", false)) and String(swap.get("operation", "")) == "swap", "clicking across swaps the heroes: %s" % swap.get("message", ""))
	_check(String(HeroCommandRules.town_garrison_hero(session, town).get("id", "")) == primary_id and String(HeroCommandRules.town_visiting_hero(session, town).get("id", "")) == second_id, "after the swap the primary holds the garrison and the second visits")
	var blocked: Dictionary = HeroCommandRules.set_town_garrison_hero(session, town, "")
	_check(not bool(blocked.get("ok", true)), "a garrison hero cannot step out while another hero waits at the gate")
	# Walking the visitor away frees the gate; the garrison hero may then step out.
	_move_off(session, second_id, town)
	var release: Dictionary = HeroCommandRules.set_town_garrison_hero(session, town, "")
	town = _player_town(session)
	_check(bool(release.get("ok", false)) and HeroCommandRules.town_garrison_hero(session, town).is_empty(), "the garrison hero steps out to the gate: %s" % release.get("message", ""))
	_check(String(HeroCommandRules.town_visiting_hero(session, town).get("id", "")) == primary_id, "the released hero now visits")
	# Troops that do not fit refuse the order and change nothing.
	var saved_army := _army_stacks(session, primary_id)
	var full := []
	for unit_id in _unit_ids(7):
		full.append({"unit_id": unit_id, "count": 1})
	_set_army(session, primary_id, full)
	var extra := _unit_not_in(full)
	_set_town_garrison(session, town, [{"unit_id": extra, "count": 2}])
	var refused: Dictionary = HeroCommandRules.set_town_garrison_hero(session, town, primary_id)
	town = _player_town(session)
	_check(not bool(refused.get("ok", true)) and String(refused.get("message", "")).find("no room") >= 0, "a full army refuses the garrison's troops: %s" % refused.get("message", ""))
	_check(HeroCommandRules.town_garrison_hero(session, town).is_empty() and HeroCommandRules._valid_stack_count(town.get("garrison", [])) == 1, "the refused order changed nothing")
	_set_army(session, primary_id, saved_army)
	_set_town_garrison(session, town, [])
	# Leaving the town clears the garrison status.
	_check(bool(HeroCommandRules.set_town_garrison_hero(session, town, primary_id).get("ok", false)), "the primary re-enters the garrison")
	_move_off(session, primary_id, town)
	HeroCommandRules.normalize_session(session)
	town = _player_town(session)
	_check(HeroCommandRules.town_garrison_hero(session, town).is_empty() and String(town.get(HeroCommandRules.TOWN_GARRISON_HERO_KEY, "")) == "", "a garrison hero that walks away leaves the garrison")
	_station(session, primary_id, town)
	_station(session, second_id, town)

# --- saves -----------------------------------------------------------------

func _save_section(session, town: Dictionary, primary_id: String, second_id: String):
	_check(bool(HeroCommandRules.set_town_garrison_hero(session, town, second_id).get("ok", false)), "the second hero holds the garrison before saving")
	var restored = SessionStateStore.new_session_data()
	restored.from_dict(session.to_dict())
	OverworldRules.normalize_overworld_state(restored)
	var restored_town := _player_town(restored)
	_check(String(HeroCommandRules.town_garrison_hero(restored, restored_town).get("id", "")) == second_id, "the garrison hero survives a save round trip")
	_check(String(HeroCommandRules.town_visiting_hero(restored, restored_town).get("id", "")) == primary_id, "the visiting hero survives a save round trip")
	return SessionState.set_active_session(restored)

func _migration_section(session, primary_id: String, second_id: String) -> void:
	var legacy: Dictionary = session.to_dict()
	legacy["overworld"].erase(HeroCommandRules.TOWN_GARRISON_HEROES_VERSION_KEY)
	for town in legacy["overworld"].get("towns", []):
		town.erase(HeroCommandRules.TOWN_GARRISON_HERO_KEY)
	var migrated = SessionStateStore.new_session_data()
	migrated.from_dict(legacy)
	OverworldRules.normalize_overworld_state(migrated)
	var town := _player_town(migrated)
	_check(String(HeroCommandRules.town_garrison_hero(migrated, town).get("id", "")) == second_id, "an old save gives the non-active of two town heroes the garrison")
	_check(int(migrated.overworld.get(HeroCommandRules.TOWN_GARRISON_HEROES_VERSION_KEY, 0)) == HeroCommandRules.TOWN_GARRISON_HEROES_VERSION, "the migration runs once")
	# Once migrated, a released garrison stays released.
	_check(bool(HeroCommandRules.set_town_garrison_hero(migrated, town, "").get("ok", false)) or not HeroCommandRules.town_visiting_hero(migrated, town).is_empty(), "the migrated garrison follows the normal rules")

# --- Town screen -----------------------------------------------------------

func _town_ui_section(session, primary_id: String, second_id: String) -> void:
	var town := _player_town(session)
	var second_town := _other_town(session, town)
	if not second_town.is_empty():
		second_town["owner"] = "player"
	_check(String(HeroCommandRules.town_garrison_hero(session, town).get("id", "")) == second_id, "the Town screen opens with a garrison hero")
	var visit: Dictionary = OverworldRules.set_active_town_visit(session, String(town.get("placement_id", "")))
	_check(bool(visit.get("ok", false)), "the town opens")
	session.game_state = "town"
	session = SessionState.set_active_session(session)
	var shell = TownShellScene.instantiate()
	add_child(shell)
	await _frames(8)
	var rows = shell.get("_army_rows")
	var snapshot: Dictionary = rows.validation_snapshot()
	_check(bool(snapshot.get("visible", false)) and int(snapshot.get("command_count", 0)) == 4, "the army panel shows with four command squares: %s" % snapshot)
	_check(String(snapshot.rows.garrison.hero_id) == second_id and String(snapshot.rows.visiting.hero_id) == primary_id, "the rows show the garrison and visiting heroes")
	_check(int(snapshot.rows.garrison.cell_count) == 7 and int(snapshot.rows.visiting.cell_count) == 7, "each row has seven slots")
	var bar: Control = shell.get("_resource_bar_panel")
	var overlay: Control = shell.get("_town_catalog_overlay")
	_check(bar != null and bar.is_visible_in_tree() and bar.z_index > overlay.z_index, "the resource bar shows above the popouts")
	_check(bar.find_child("ResourceIconStrip", true, false) != null, "the resource bar uses the overworld's inline icons")
	_check(not (shell.get("_sidebar_shell_panel") as Control).visible and not (shell.get("_footer_panel") as Control).visible, "the Command card and footer are retired")
	_check(not (shell.get("_log_action_button") as Control).visible, "the Town Log command is retired")
	_check(String((shell.get("_leave_button") as Control).get_parent().name) == "TopBar", "Return to Field sits in the banner")
	var switcher: Control = shell.get("_town_switcher")
	var player_towns := 0
	for entry in session.overworld.get("towns", []):
		if entry is Dictionary and String(entry.get("owner", "")) == "player":
			player_towns += 1
	var current := 0
	for button in switcher.get_children():
		if bool(button.get_meta("current", false)):
			current += 1
	_check(switcher.get_child_count() == player_towns and current == 1, "the town list shows every owned town with the current one marked (%d of %d)" % [switcher.get_child_count(), player_towns])
	var kinds := []
	for plaque in shell.get("_town_stage_view").call("_status_plaque_payloads"):
		kinds.append(String(plaque.get("kind", "")))
	_check("guard" not in kinds and "garrison" not in kinds, "the stage no longer repeats troop counts")
	await _construction_section(shell, bar)
	# Slot orders through the rows.
	var visiting_before := _troops(_army_stacks(session, primary_id))
	var garrison_before := _troops(_army_stacks(session, second_id))
	var move_slot := _occupied_slot(session, primary_id, 1)
	var empty_garrison := _empty_slot(session, second_id)
	if move_slot >= 0 and empty_garrison >= 0:
		var moving := _slot_count(session, primary_id, move_slot)
		rows.validation_press_slot("visiting", move_slot)
		rows.validation_press_slot("garrison", empty_garrison)
		await _frames(2)
		_check(_troops(_army_stacks(session, primary_id)) == visiting_before - moving and _troops(_army_stacks(session, second_id)) == garrison_before + moving, "click, click moves a stack from the visiting row to the garrison")
	var split_from := _occupied_slot(session, primary_id, 0)
	var split_to := _empty_slot(session, primary_id)
	if split_from >= 0 and split_to >= 0 and _slot_count(session, primary_id, split_from) > 1:
		rows.validation_press_slot("visiting", split_from)
		rows.validation_press_slot("visiting", split_to, true)
		rows.validation_confirm_split(1)
		await _frames(2)
		_check(_slot_count(session, primary_id, split_to) == 1, "Shift opens the split and moves the chosen amount")
	rows.validation_press_portrait("visiting")
	rows.validation_press_portrait("garrison")
	await _frames(2)
	town = _player_town(session)
	_check(String(HeroCommandRules.town_garrison_hero(session, town).get("id", "")) == primary_id, "clicking the visiting portrait then the garrison portrait swaps the heroes")
	rows.validation_press_portrait("garrison")
	rows.validation_press_portrait("garrison")
	await _frames(3)
	var sheet = shell.get("_hero_sheet")
	_check(is_instance_valid(sheet) and sheet.visible, "clicking a selected hero portrait again opens the hero sheet")
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	shell._input(cancel)
	_check(shell.is_inside_tree() and String(session.game_state) == "town", "Escape over the hero sheet does not leave the town")
	if is_instance_valid(sheet):
		sheet.hide()
	var any_slot := _occupied_slot(session, primary_id, 0)
	if any_slot >= 0:
		rows.validation_press_slot("garrison", any_slot)
		shell._input(cancel)
		_check(shell.is_inside_tree() and (rows.validation_snapshot().selection as Dictionary).is_empty(), "Escape clears a slot selection before it would leave the town")
	shell.queue_free()
	await _frames(2)

## The construction screen leaves the stockpile to the town's resource bar and
## keeps Close where View in town was; V still views a building in the town.
func _construction_section(shell, bar: Control) -> void:
	shell.call("validation_open_town_catalog", "build")
	await _frames(3)
	var screen = shell.get("_construction_screen")
	_check(screen != null and screen.visible, "the construction screen opens")
	if screen == null or not screen.visible:
		return
	_check(screen.find_child("ConstructionResources", true, false) == null, "the construction header has no resource strip")
	_check(screen.find_child("ConstructionViewInTown", true, false) == null, "the View in town button is gone")
	var close_button := screen.find_child("ConstructionClose", true, false) as Button
	_check(close_button != null and close_button.is_visible_in_tree() and String(close_button.get_parent().name) == "ConstructionButtons", "Close sits beside the build button")
	var bar_top := bar.get_global_rect().position.y
	var detail_bottom: float = (screen.get("_detail_panel") as Control).get_global_rect().end.y
	var legend: Control = screen.get("_legend_row")
	_check(bar.is_visible_in_tree() and detail_bottom <= bar_top and legend.get_global_rect().end.y <= bar_top, "the board and detail panel end above the resource bar (%.0f, %.0f, bar %.0f)" % [detail_bottom, legend.get_global_rect().end.y, bar_top])
	var key := InputEventKey.new()
	key.keycode = KEY_V
	key.pressed = true
	screen._unhandled_key_input(key)
	await _frames(2)
	_check(screen.is_peeking() and String(shell.get("_town_stage_view").get("_construction_preview_id")) != "", "V shows the selected building in the town")
	var peek_rect: Rect2 = (screen.get("_peek_bar") as Control).get_global_rect()
	_check(not peek_rect.intersects((shell.get("_army_rows") as Control).get_global_rect()), "the town view's Back bar clears the army rows")
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	shell._input(cancel)
	await _frames(2)
	_check(screen.visible and not screen.is_peeking(), "Escape returns from the town view to the board")
	close_button.emit_signal("pressed")
	await _frames(2)
	_check(not screen.visible and shell.is_inside_tree(), "Close returns to the town")

# --- overworld -------------------------------------------------------------

func _overworld_section(session, primary_id: String, second_id: String) -> void:
	var town := _player_town(session)
	HeroCommandRules.set_town_garrison_hero(session, town, second_id)
	OverworldRules.clear_active_town_visit(session)
	session.game_state = "overworld"
	HeroCommandRules.set_active_hero(session, primary_id)
	session = SessionState.set_active_session(session)
	var shell = OverworldShellScene.instantiate()
	add_child(shell)
	await _frames(10)
	var map_view = shell.get("_map_view")
	var entrance: Dictionary = LevelRules.town_entrance(_player_town(session))
	var key: String = map_view.call("_tile_key", Vector2i(int(entrance.get("x", 0)), int(entrance.get("y", 0))))
	var garrisoned: Dictionary = map_view.get("_garrison_heroes_by_tile")
	var on_tile: Array = map_view.get("_heroes_by_tile").get(key, [])
	_check(String(garrisoned.get(key, {}).get("id", "")) == second_id, "the map hangs the garrison hero's medallion on the town")
	_check(on_tile.size() == 1 and String(on_tile[0].get("id", "")) == primary_id, "only the visiting hero stands at the gate on the map")
	var badge_found := false
	for button in (shell.get("_hero_actions") as Container).get_children():
		if String(button.get_meta("hero_id", "")) == second_id:
			var badge := button.get_node_or_null("GarrisonBadge") as Control
			badge_found = badge != null and badge.visible
	_check(badge_found, "the hero list marks the garrison hero with G")
	shell.queue_free()
	await _frames(2)

# --- helpers ---------------------------------------------------------------

func _start_session():
	var config := ScenarioSelectRulesScript.build_random_map_player_config(SEED, "", "", 2, "land", false, "homm3_small", ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_SIZE_DEFAULT, PLAYER_FACTION_ID, PLAYER_HERO_ID)
	var setup := ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(config, "normal", ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY)
	if not bool(setup.get("ok", false)):
		_check(false, "small generated setup: %s" % JSON.stringify(setup).left(300))
		return null
	var session = ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup)
	OverworldRules.normalize_overworld_state(session)
	return SessionState.set_active_session(session)

func _player_town(session) -> Dictionary:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("owner", "")) == "player":
			return town
	return {}

func _other_town(session, town: Dictionary) -> Dictionary:
	for entry in session.overworld.get("towns", []):
		if entry is Dictionary and String(entry.get("placement_id", "")) != String(town.get("placement_id", "")):
			return entry
	return {}

func _station(session, hero_id: String, town: Dictionary) -> void:
	var entrance: Dictionary = LevelRules.town_entrance(town)
	var heroes: Array = session.overworld.get("player_heroes", [])
	for hero in heroes:
		if String(hero.get("id", "")) == hero_id:
			hero["position"] = {"x": int(entrance.get("x", 0)), "y": int(entrance.get("y", 0))}
	if hero_id == String(session.overworld.get("active_hero_id", "")):
		OverworldRules._set_active_hero_position(session, Vector2i(int(entrance.get("x", 0)), int(entrance.get("y", 0))))
	HeroCommandRules.normalize_session(session)

## A second commander of the player's faction, built like a tavern hire.
func _add_second_hero(session, town: Dictionary, primary_id: String) -> String:
	var entrance: Dictionary = LevelRules.town_entrance(town)
	for hero_id_value in ContentService.get_faction(PLAYER_FACTION_ID).get("hero_ids", []):
		var hero_id := String(hero_id_value)
		if hero_id == "" or hero_id == primary_id or not HeroCommandRules.hero_by_id(session, hero_id).is_empty():
			continue
		var hero := HeroCommandRules.build_hero_from_template(ContentService.get_hero(hero_id), {"x": int(entrance.get("x", 0)), "y": int(entrance.get("y", 0))}, {}, session)
		if hero.is_empty():
			continue
		hero["army"] = HeroCommandRules.starting_army_for_hero(ContentService.get_hero(hero_id), "town-garrison-rows")
		session.overworld["player_heroes"].append(hero)
		HeroCommandRules.normalize_session(session)
		return hero_id
	return ""

func _move_off(session, hero_id: String, town: Dictionary) -> void:
	var entrance: Dictionary = LevelRules.town_entrance(town)
	for hero in session.overworld.get("player_heroes", []):
		if String(hero.get("id", "")) == hero_id:
			hero["position"] = {"x": int(entrance.get("x", 0)) + 1, "y": int(entrance.get("y", 0)) + 1}
	if hero_id == String(session.overworld.get("active_hero_id", "")):
		OverworldRules._set_active_hero_position(session, Vector2i(int(entrance.get("x", 0)) + 1, int(entrance.get("y", 0)) + 1))
	HeroCommandRules.normalize_session(session)

func _army_stacks(session, hero_id: String) -> Array:
	var hero := HeroCommandRules.hero_by_id(session, hero_id)
	return hero.get("army", {}).get("stacks", []) if hero.get("army", {}) is Dictionary else []

func _set_army(session, hero_id: String, stacks: Array) -> void:
	HeroCommandRules._set_holder_stacks(session, _player_town(session), hero_id, HeroCommandRules._slotted_stacks(stacks))

func _set_town_garrison(session, town: Dictionary, stacks: Array) -> void:
	HeroCommandRules._set_holder_stacks(session, town, HeroCommandRules.HOLDER_GARRISON, stacks)

func _troops(stacks: Array) -> int:
	var total := 0
	for stack in stacks:
		if stack is Dictionary:
			total += int(stack.get("count", 0))
	return total

func _has_unit(stacks: Array, unit_id: String) -> bool:
	for stack in stacks:
		if stack is Dictionary and String(stack.get("unit_id", "")) == unit_id:
			return true
	return false

func _occupied_slot(session, hero_id: String, skip: int) -> int:
	var found := 0
	for stack in HeroCommandRules._slotted_stacks(_army_stacks(session, hero_id)):
		if found == skip:
			return int(stack.get("slot_index", -1))
		found += 1
	return -1

func _empty_slot(session, hero_id: String) -> int:
	var used := {}
	for stack in HeroCommandRules._slotted_stacks(_army_stacks(session, hero_id)):
		used[int(stack.get("slot_index", -1))] = true
	for index in range(HeroCommandRules.ARMY_SLOT_COUNT):
		if not used.has(index):
			return index
	return -1

func _slot_count(session, hero_id: String, slot_index: int) -> int:
	for stack in HeroCommandRules._slotted_stacks(_army_stacks(session, hero_id)):
		if int(stack.get("slot_index", -1)) == slot_index:
			return int(stack.get("count", 0))
	return 0

func _unit_ids(count: int) -> Array:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://content/units.json"))
	var ids := []
	for item in data.get("items", []):
		if ids.size() >= count:
			break
		ids.append(String(item.get("id", "")))
	return ids

func _unit_not_in(stacks: Array) -> String:
	for unit_id in _unit_ids(40):
		if not _has_unit(stacks, unit_id):
			return unit_id
	return ""

func _finish() -> void:
	ContentService.clear_generated_scenario_drafts()
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": _failures.is_empty(), "checks": _checks, "failures": _failures})])
	get_tree().quit(0 if _failures.is_empty() else 1)
