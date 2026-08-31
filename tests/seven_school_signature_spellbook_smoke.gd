extends Node

const SessionDataScript = preload("res://scripts/core/SessionStateStore.gd")
const SCENARIO_ID := "horizon-compact-six-citadels"
const CASES := [
	{
		"spell_id": "spell_beacon_lockfire_muster",
		"school_id": "beacon",
		"town_placement_id": "horizon_rainwrit_town",
		"building_id": "building_embercourt_beacon_court",
	},
	{
		"spell_id": "spell_mire_moonfen_dragnet",
		"school_id": "mire",
		"town_placement_id": "horizon_hollowreed_town",
		"building_id": "building_mireclaw_sporewake_shrine",
	},
	{
		"spell_id": "spell_lens_seven_facet_refrain",
		"school_id": "lens",
		"town_placement_id": "horizon_meridian_town",
		"building_id": "building_sunvault_zenith_observatory",
	},
	{
		"spell_id": "spell_root_heartwood_renewal",
		"school_id": "root",
		"town_placement_id": "horizon_crownroot_town",
		"building_id": "building_thornwake_sporeglass_hothouse",
	},
	{
		"spell_id": "spell_furnace_redline_overdrive",
		"school_id": "furnace",
		"town_placement_id": "horizon_blackbell_town",
		"building_id": "building_brasshollow_boiler_cathedral",
	},
	{
		"spell_id": "spell_veil_drowned_bell_verdict",
		"school_id": "veil",
		"town_placement_id": "horizon_pale_town",
		"building_id": "building_veilmourn_obituary_vault",
	},
	{
		"spell_id": "spell_old_measure_unbroken_meridian",
		"school_id": "old_measure",
		"town_placement_id": "horizon_rainwrit_town",
		"building_id": "building_embercourt_beacon_court",
	},
]


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var rows := []
	for case_value in CASES:
		var row := await _run_case(case_value)
		rows.append(row)
		if not bool(row.get("ok", false)):
			push_error("Seven-school signature spellbook smoke failed: %s" % JSON.stringify(row))
			get_tree().quit(1)
			return
	print("SEVEN_SCHOOL_SIGNATURE_SPELLBOOK_SMOKE %s" % JSON.stringify({
		"ok": true,
		"scenario_id": SCENARIO_ID,
		"spell_count": rows.size(),
		"school_count": rows.map(func(row): return String(row.get("school_id", ""))).size(),
		"town_ui_icon_rows": rows.filter(func(row): return bool(row.get("town_ui_icon_exact", false))).size(),
		"town_study_rows": rows.filter(func(row): return bool(row.get("learned", false))).size(),
		"battle_cast_rows": rows.filter(func(row): return bool(row.get("cast_ok", false))).size(),
		"save_round_trip_rows": rows.filter(func(row): return bool(row.get("save_round_trip_exact", false))).size(),
		"save_version": SessionDataScript.SAVE_VERSION,
		"rows": rows,
	}))
	get_tree().quit(0)


func _run_case(case: Dictionary) -> Dictionary:
	var spell_id := String(case.get("spell_id", ""))
	var school_id := String(case.get("school_id", ""))
	var placement_id := String(case.get("town_placement_id", ""))
	var building_id := String(case.get("building_id", ""))
	var spell := ContentService.get_spell(spell_id)
	var expected_icon_path := "res://art/magic/runtime/spells/%s.png" % spell_id
	if spell.is_empty() or String(spell.get("school_id", "")) != school_id or int(spell.get("tier", 0)) != 3:
		return {"ok": false, "failure": "spell_contract", "spell_id": spell_id, "spell": spell}
	if SpellRules.spell_icon_path(spell_id) != expected_icon_path or not ResourceLoader.exists(expected_icon_path, "Texture2D"):
		return {"ok": false, "failure": "icon_contract", "spell_id": spell_id, "icon_path": SpellRules.spell_icon_path(spell_id)}
	var texture := load(expected_icon_path) as Texture2D
	if texture == null or texture.get_size() != Vector2(128.0, 128.0):
		return {"ok": false, "failure": "icon_texture", "spell_id": spell_id, "size": texture.get_size() if texture != null else Vector2.ZERO}

	var session = ScenarioFactory.create_session(SCENARIO_ID, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var town := _town_by_placement(session, placement_id)
	if town.is_empty():
		return {"ok": false, "failure": "town_missing", "spell_id": spell_id, "placement_id": placement_id}
	town["owner"] = "player"
	var built_buildings: Array = town.get("built_buildings", []) if town.get("built_buildings", []) is Array else []
	if building_id not in built_buildings:
		built_buildings.append(building_id)
	town["built_buildings"] = built_buildings
	_move_active_hero_to_town(session, town)
	_set_active_hero_spellbook(session, [])
	var visit_result := OverworldRules.set_active_town_visit(session, placement_id)
	if not bool(visit_result.get("ok", false)) or TownRules.current_spell_tier(town) < 3 or spell_id not in TownRules.accessible_spell_ids(town):
		return {
			"ok": false,
			"failure": "town_study_route",
			"spell_id": spell_id,
			"visit_result": visit_result,
			"spell_tier": TownRules.current_spell_tier(town),
			"accessible_spell_ids": TownRules.accessible_spell_ids(town),
		}

	SessionState.set_active_session(session)
	var shell = load("res://scenes/town/TownShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var tabs := shell.get_node_or_null("%ManagementTabs") as TabContainer
	if tabs == null:
		return await _finish_case(shell, {"ok": false, "failure": "town_tabs_missing", "spell_id": spell_id})
	tabs.current_tab = 2
	await get_tree().process_frame
	await get_tree().process_frame
	var live_session = SessionState.ensure_active_session()
	var actions := TownRules.get_spell_learning_actions(live_session)
	var action_id := "learn_spell:%s" % spell_id
	var action_index := _action_index(actions, action_id)
	var study_actions := shell.get_node_or_null("%StudyActions") as Container
	var buttons := _child_buttons(study_actions)
	var button: Button = buttons[action_index] if action_index >= 0 and action_index < buttons.size() else null
	var town_ui_icon_exact := (
		button != null
		and not button.disabled
		and button.icon != null
		and button.icon.resource_path == expected_icon_path
		and button.expand_icon
		and button.get_theme_constant("icon_max_width") == 24
	)
	if not town_ui_icon_exact:
		return await _finish_case(shell, {
			"ok": false,
			"failure": "town_ui_icon",
			"spell_id": spell_id,
			"action_index": action_index,
			"action_count": actions.size(),
			"button_count": buttons.size(),
			"button_icon_path": button.icon.resource_path if button != null and button.icon != null else "",
		})
	button.emit_signal("pressed")
	await get_tree().process_frame
	await get_tree().process_frame
	var learned := SpellRules.knows_spell(live_session.overworld.get("hero", {}), spell_id)
	if not learned:
		return await _finish_case(shell, {"ok": false, "failure": "town_study_action", "spell_id": spell_id})
	await _finish_case(shell, {})

	var enemy_town := _first_enemy_town(live_session)
	if enemy_town.is_empty():
		return {"ok": false, "failure": "enemy_town_missing", "spell_id": spell_id}
	live_session.battle = BattleRules.create_town_assault_payload(live_session, String(enemy_town.get("placement_id", "")))
	_stage_player_turn(live_session.battle, String(spell.get("effect", {}).get("type", "")))
	var commander_before: Dictionary = live_session.battle.get("player_commander_state", {}) if live_session.battle.get("player_commander_state", {}) is Dictionary else {}
	var mana_before: int = int(SpellRules.mana_state(commander_before).get("current", 0))
	var cast_result := BattleRules.cast_player_spell(live_session, spell_id)
	var commander_after: Dictionary = live_session.battle.get("player_commander_state", {}) if live_session.battle.get("player_commander_state", {}) is Dictionary else {}
	var mana_after: int = int(SpellRules.mana_state(commander_after).get("current", 0))
	var spell_event_exact := false
	for event_value in BattleRules.animation_event_queue(live_session.battle):
		if event_value is Dictionary and String(event_value.get("spell_id", "")) == spell_id:
			spell_event_exact = true
			break
	var payload := live_session.to_dict()
	var restored = SessionDataScript.SessionData.new()
	restored.from_dict(payload.duplicate(true))
	var save_round_trip_exact: bool = restored.to_dict() == payload and restored.save_version == SessionDataScript.SAVE_VERSION
	var cast_ok: bool = bool(cast_result.get("ok", false)) and mana_before - mana_after == int(spell.get("mana_cost", 0)) and spell_event_exact
	return {
		"ok": town_ui_icon_exact and learned and cast_ok and save_round_trip_exact,
		"spell_id": spell_id,
		"school_id": school_id,
		"town_placement_id": placement_id,
		"building_id": building_id,
		"town_ui_icon_exact": town_ui_icon_exact,
		"learned": learned,
		"cast_ok": cast_ok,
		"spell_event_exact": spell_event_exact,
		"mana_before": mana_before,
		"mana_after": mana_after,
		"save_round_trip_exact": save_round_trip_exact,
	}


func _town_by_placement(session, placement_id: String) -> Dictionary:
	for town_value in session.overworld.get("towns", []):
		if town_value is Dictionary and String(town_value.get("placement_id", "")) == placement_id:
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
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	hero["position"] = position.duplicate(true)
	session.overworld["hero"] = hero
	var active_hero_id := String(session.overworld.get("active_hero_id", hero.get("id", "")))
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == active_hero_id:
			heroes[index]["position"] = position.duplicate(true)
	session.overworld["player_heroes"] = heroes


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
	session.overworld["player_heroes"] = heroes


func _stage_player_turn(battle: Dictionary, effect_type: String) -> void:
	var player_id := ""
	var enemy_id := ""
	for stack_value in battle.get("stacks", []):
		if not (stack_value is Dictionary):
			continue
		var stack: Dictionary = stack_value
		if player_id == "" and String(stack.get("side", "")) == "player":
			player_id = String(stack.get("battle_id", ""))
			if effect_type == "recover_ally":
				stack["total_health"] = max(1, int(stack.get("total_health", 1)) - 50)
		elif enemy_id == "" and String(stack.get("side", "")) == "enemy":
			enemy_id = String(stack.get("battle_id", ""))
			stack["base_count"] = max(200, int(stack.get("base_count", 0)))
			stack["total_health"] = int(stack.get("base_count", 200)) * max(1, int(stack.get("unit_hp", 1)))
	battle["active_stack_id"] = player_id
	battle["selected_target_id"] = enemy_id
	battle["commander_spell_cast_rounds"] = {}


func _action_index(actions: Array, action_id: String) -> int:
	for index in range(actions.size()):
		if actions[index] is Dictionary and String(actions[index].get("id", "")) == action_id:
			return index
	return -1


func _child_buttons(container: Container) -> Array:
	var buttons := []
	if container == null:
		return buttons
	for child in container.get_children():
		if child is Button:
			buttons.append(child)
	return buttons


func _finish_case(shell: Node, result: Dictionary) -> Dictionary:
	if shell != null and is_instance_valid(shell):
		shell.queue_free()
		await get_tree().process_frame
	return result
