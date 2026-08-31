extends Node

const SessionDataScript = preload("res://scripts/core/SessionStateStore.gd")
const BattleBoardViewScript = preload("res://scenes/battle/BattleBoardView.gd")
const SCENARIO_ID := "horizon-compact-six-citadels"
const BATTLE_VFX_MANIFEST_PATH := "res://content/battle_vfx_manifest.json"
const CAPTURE_DIR := "user://seven_school_signature_battle_vfx"
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
	var capture_dir_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
	if capture_dir_error != OK:
		push_error("Seven-school signature spellbook smoke could not create capture directory: %s" % capture_dir_error)
		get_tree().quit(1)
		return
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
		"exact_battle_vfx_rows": rows.filter(func(row): return bool(row.get("exact_battle_vfx", false))).size(),
		"reduced_motion_rows": rows.filter(func(row): return bool(row.get("reduced_motion_fallback", false))).size(),
		"consequence_parity_rows": rows.filter(func(row): return bool(row.get("consequence_parity", false))).size(),
		"accessible_vfx_rows": rows.filter(func(row): return bool(row.get("accessible_vfx", false))).size(),
		"capture_count": rows.reduce(func(count, row): return count + int(row.get("capture_count", 0)), 0),
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
	var pre_cast_payload: Dictionary = live_session.to_dict()
	var reduced_session = SessionDataScript.SessionData.new()
	reduced_session.from_dict(pre_cast_payload.duplicate(true))
	SettingsService.ensure_settings()
	var original_reduce_motion := SettingsService.reduced_motion_enabled()
	var original_reduce_flashes := SettingsService.reduced_flashes_enabled()
	SettingsService.settings["accessibility"]["reduce_motion"] = false
	SettingsService.settings["accessibility"]["reduce_flashes"] = false
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
	var cue_id := "vfx_%s" % spell_id
	var expected_vfx_path := "res://art/battle/vfx/%s.png" % spell_id
	var cue_spec := _battle_vfx_cue(cue_id)
	var normal_presentation := await _battle_presentation(live_session, "%s_normal.png" % spell_id)
	var normal_summary: Dictionary = normal_presentation.get("summary", {}) if normal_presentation.get("summary", {}) is Dictionary else {}
	var normal_cue := _cue_record_with_vfx(normal_summary, cue_id)
	var normal_vfx := _vfx_entry_for_cue(normal_summary, cue_id)
	var selected_normal_vfx: Array = normal_cue.get("selected_vfx_cue_ids", []) if normal_cue.get("selected_vfx_cue_ids", []) is Array else []
	var generic_secondary := selected_normal_vfx.any(func(value): return String(value).begins_with("vfx_placeholder_"))
	var exact_battle_vfx := (
		selected_normal_vfx.has(cue_id)
		and bool(normal_vfx.get("asset_loaded", false))
		and String(normal_vfx.get("asset_path", "")) == expected_vfx_path
		and String(normal_vfx.get("asset_render_mode", "")) == "spell_target"
		and String(normal_vfx.get("kind", "")) == spell_id
		and generic_secondary
	)
	var accessible_vfx := (
		String(cue_spec.get("spell_id", "")) == spell_id
		and String(cue_spec.get("texture_path", "")) == expected_vfx_path
		and String(cue_spec.get("source_path", "")).begins_with("res://art/battle/source/generated/seven_school_signature_vfx/")
		and not String(cue_spec.get("alt_text", "")).strip_edges().is_empty()
	)
	var normal_authority: Dictionary = live_session.to_dict()
	SettingsService.settings["accessibility"]["reduce_motion"] = true
	SettingsService.settings["accessibility"]["reduce_flashes"] = true
	var reduced_result := BattleRules.cast_player_spell(reduced_session, spell_id)
	var reduced_authority: Dictionary = reduced_session.to_dict()
	var reduced_presentation := await _battle_presentation(reduced_session, "%s_reduced.png" % spell_id, true)
	var reduced_summary: Dictionary = reduced_presentation.get("summary", {}) if reduced_presentation.get("summary", {}) is Dictionary else {}
	var reduced_cast_cue := _cue_record_for_event(reduced_summary, "battle_unit_cast")
	var reduced_selected_vfx: Array = reduced_cast_cue.get("selected_vfx_cue_ids", []) if reduced_cast_cue.get("selected_vfx_cue_ids", []) is Array else []
	var reduced_motion_fallback := (
		not _summary_has_selected_vfx(reduced_summary, cue_id)
		and (
			reduced_cast_cue.is_empty()
			or reduced_selected_vfx.has("cast_icon_anchor")
		)
	)
	var consequence_parity := JSON.stringify(reduced_result) == JSON.stringify(cast_result) and reduced_authority == normal_authority
	SettingsService.settings["accessibility"]["reduce_motion"] = original_reduce_motion
	SettingsService.settings["accessibility"]["reduce_flashes"] = original_reduce_flashes
	var payload := live_session.to_dict()
	var restored = SessionDataScript.SessionData.new()
	restored.from_dict(payload.duplicate(true))
	var save_round_trip_exact: bool = restored.to_dict() == payload and restored.save_version == SessionDataScript.SAVE_VERSION
	var cast_ok: bool = bool(cast_result.get("ok", false)) and mana_before - mana_after == int(spell.get("mana_cost", 0)) and spell_event_exact
	var capture_count := int(bool(normal_presentation.get("capture_ok", false))) + int(bool(reduced_presentation.get("capture_ok", false)))
	return {
		"ok": town_ui_icon_exact and learned and cast_ok and exact_battle_vfx and reduced_motion_fallback and consequence_parity and accessible_vfx and capture_count == 2 and save_round_trip_exact,
		"spell_id": spell_id,
		"school_id": school_id,
		"town_placement_id": placement_id,
		"building_id": building_id,
		"town_ui_icon_exact": town_ui_icon_exact,
		"learned": learned,
		"cast_ok": cast_ok,
		"spell_event_exact": spell_event_exact,
		"cue_id": cue_id,
		"vfx_path": expected_vfx_path,
		"exact_battle_vfx": exact_battle_vfx,
		"generic_secondary": generic_secondary,
		"accessible_vfx": accessible_vfx,
		"reduced_motion_fallback": reduced_motion_fallback,
		"consequence_parity": consequence_parity,
		"normal_selected_vfx": selected_normal_vfx,
		"reduced_selected_vfx": reduced_selected_vfx,
		"capture_count": capture_count,
		"normal_capture": String(normal_presentation.get("capture_path", "")),
		"reduced_capture": String(reduced_presentation.get("capture_path", "")),
		"mana_before": mana_before,
		"mana_after": mana_after,
		"save_round_trip_exact": save_round_trip_exact,
	}


func _battle_vfx_cue(cue_id: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(BATTLE_VFX_MANIFEST_PATH)
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return {}
	var cues: Dictionary = parsed.get("cues", {}) if parsed.get("cues", {}) is Dictionary else {}
	return cues.get(cue_id, {}) if cues.get(cue_id, {}) is Dictionary else {}


func _battle_presentation(session, filename: String, immediate_summary: bool = false) -> Dictionary:
	var view := BattleBoardViewScript.new()
	view.size = Vector2(960.0, 540.0)
	add_child(view)
	view.set_battle_state(session)
	var summary: Dictionary = view.validation_unit_art_summary() if immediate_summary else {}
	await get_tree().process_frame
	if not immediate_summary:
		await get_tree().create_timer(0.04).timeout
		summary = view.validation_unit_art_summary()
	var capture_path := ProjectSettings.globalize_path("%s/%s" % [CAPTURE_DIR, filename])
	var image := get_viewport().get_texture().get_image()
	var capture_ok := image != null and not image.is_empty() and image.save_png(capture_path) == OK
	view.queue_free()
	await get_tree().process_frame
	return {"summary": summary, "capture_ok": capture_ok, "capture_path": capture_path}


func _cue_record_with_vfx(summary: Dictionary, cue_id: String) -> Dictionary:
	var cue_playback: Dictionary = summary.get("cue_playback", {}) if summary.get("cue_playback", {}) is Dictionary else {}
	var records: Dictionary = cue_playback.get("active_records", {}) if cue_playback.get("active_records", {}) is Dictionary else {}
	for record_value in records.values():
		if record_value is Dictionary and record_value.get("selected_vfx_cue_ids", []).has(cue_id):
			return record_value
	return {}


func _cue_record_for_event(summary: Dictionary, event_id: String) -> Dictionary:
	var cue_playback: Dictionary = summary.get("cue_playback", {}) if summary.get("cue_playback", {}) is Dictionary else {}
	var records: Dictionary = cue_playback.get("active_records", {}) if cue_playback.get("active_records", {}) is Dictionary else {}
	for record_value in records.values():
		if record_value is Dictionary and String(record_value.get("event_id", "")) == event_id:
			return record_value
	return {}


func _vfx_entry_for_cue(summary: Dictionary, cue_id: String) -> Dictionary:
	var vfx_playback: Dictionary = summary.get("vfx_playback", {}) if summary.get("vfx_playback", {}) is Dictionary else {}
	var entries: Array = vfx_playback.get("active_draw_entries", []) if vfx_playback.get("active_draw_entries", []) is Array else []
	for entry_value in entries:
		if entry_value is Dictionary and String(entry_value.get("cue_id", "")) == cue_id:
			return entry_value
	return {}


func _summary_has_selected_vfx(summary: Dictionary, cue_id: String) -> bool:
	return not _cue_record_with_vfx(summary, cue_id).is_empty()


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
