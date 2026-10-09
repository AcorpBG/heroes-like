extends Node

## Drives the real hero meeting screen inside OverworldShell against the real
## HeroCommandRules/OverworldRules orders: slot move, refused last-stack move,
## keyboard merge, swap, shift-split, Split-button split, drag & drop, move-all
## troops both ways, artifact click/drag/refusal/swap, move-all artifacts,
## spell teaching, Escape/Done close and a manual save round trip.

const REPORT_ID := "HERO_EXCHANGE_SCREEN_REPORT"
const SAVE_SLOT := 6
const VIEWPORTS := [Vector2i(1920, 1080), Vector2i(1280, 720)]
const UNIT_A := "unit_embercourt_fordhook_cadets"
const UNIT_B := "unit_embercourt_lantern_sappers"
const UNIT_C := "unit_embercourt_bargebow_crews"
const BOOTS_ID := "artifact_trailsinger_boots"
const GORGET_ID := "artifact_bastion_gorget"
const ROD_ID := "artifact_quarry_tally_rod"
const COMPASS_ID := "artifact_waymark_compass"
const LANTERN_ID := "artifact_milepost_lantern"
const STANDARD_ID := "artifact_bridgefire_standard"
const ACTIVE_SPELLS := ["spell_cinder_burst", "spell_beacon_path"]
const RESERVE_SPELLS := ["spell_briar_bind", "spell_graft_mend"]

var _shell: Node
var _screen: Control
var _session
var _active_id := ""
var _reserve_id := ""
var _baseline_totals := {}
var _screenshots := []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_window_size := get_window().size
	get_window().size = VIEWPORTS[0]
	await get_tree().process_frame
	if not await _open_shell():
		return
	var layout := await _layout_case(VIEWPORTS[0])
	if layout.is_empty():
		return
	var army := await _army_case()
	if army.is_empty():
		return
	var artifacts := await _artifact_case()
	if artifacts.is_empty():
		return
	var spells := _spell_case()
	if spells.is_empty():
		return
	var closing := await _close_case()
	if closing.is_empty():
		return
	var saved := _save_case()
	if saved.is_empty():
		return
	var partners := await _partner_case()
	if partners.is_empty():
		return
	_shell.queue_free()
	await get_tree().process_frame
	get_window().size = VIEWPORTS[1]
	await get_tree().process_frame
	if not await _open_shell():
		return
	var small_layout := await _layout_case(VIEWPORTS[1])
	if small_layout.is_empty():
		return
	_shell.queue_free()
	await get_tree().process_frame
	get_window().size = original_window_size
	await get_tree().process_frame
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"report_id": REPORT_ID,
		"layouts": [layout, small_layout],
		"army": army,
		"artifacts": artifacts,
		"spells": spells,
		"closing": closing,
		"save": saved,
		"partners": partners,
		"screenshots": _screenshots,
		"save_version": SessionStateStore.SAVE_VERSION,
	})])
	get_tree().quit(0)

func _open_shell() -> bool:
	var fixture := _fixture()
	_session = fixture.get("session")
	_active_id = String(fixture.get("active_id", ""))
	_reserve_id = String(fixture.get("reserve_id", ""))
	_baseline_totals = _unit_totals()
	SessionState.set_active_session(_session)
	_shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(_shell)
	for _frame in range(3):
		await get_tree().process_frame
	_session = _shell.get("_session")
	var surface: Dictionary = _shell.call("validation_open_hero_exchange", _reserve_id)
	await get_tree().process_frame
	_screen = _shell.call("validation_hero_exchange")
	if _screen == null or not bool(surface.get("exchange_open", false)) or String(surface.get("exchange_partner_id", "")) != _reserve_id:
		_fail("The hero meeting screen did not open for the co-located reserve commander.", surface)
		return false
	if String(_shell.call("_overworld_gameplay_movement_blocked_reason")) != "hero_exchange_open":
		_fail("The open meeting screen did not block map movement.")
		return false
	return true

func _layout_case(viewport: Vector2i) -> Dictionary:
	await get_tree().process_frame
	var snapshot: Dictionary = _screen.call("validation_snapshot")
	var sides: Dictionary = snapshot.get("sides", {})
	var checks := {
		"visible": bool(snapshot.get("visible", false)),
		"heroes_face_each_other": String(sides.get("left", {}).get("hero_id", "")) == _active_id and String(sides.get("right", {}).get("hero_id", "")) == _reserve_id,
		"panel_inside_viewport": bool(snapshot.get("panel_inside_viewport", false)),
		"no_scrollbars": int(snapshot.get("scroll_containers", -1)) == 0,
		"seven_slots_each": (sides.get("left", {}).get("army", []) as Array).size() == HeroCommandRules.ARMY_SLOT_COUNT and (sides.get("right", {}).get("army", []) as Array).size() == HeroCommandRules.ARMY_SLOT_COUNT,
		"art_loaded": int(snapshot.get("loaded_art_cells", 0)) >= 8,
		"cells_focusable": int(snapshot.get("focusable_cells", 0)) >= 2 * (HeroCommandRules.ARMY_SLOT_COUNT + ArtifactRules.EQUIPMENT_SLOTS.size()),
		"done_focusable": bool(snapshot.get("done_focusable", false)),
	}
	if not _checks_pass(checks):
		return _fail("%dx%d meeting layout failed." % [viewport.x, viewport.y], {"checks": checks, "snapshot": snapshot})
	# Selecting a stack highlights legal targets; Shift-click opens the split slider.
	_press("left", "army", "0")
	await get_tree().process_frame
	var selected: Dictionary = _screen.call("validation_snapshot")
	_capture("selected_%dx%d" % [viewport.x, viewport.y])
	_press("right", "army", "3", true)
	await get_tree().process_frame
	var split_open: Dictionary = _screen.call("validation_snapshot")
	_capture("split_%dx%d" % [viewport.x, viewport.y])
	_cancel()
	await get_tree().process_frame
	_cancel()
	await get_tree().process_frame
	var cleared: Dictionary = _screen.call("validation_snapshot")
	if not bool(split_open.get("split_open", false)) or (selected.get("legal_targets", []) as Array).is_empty() \
		or bool(cleared.get("split_open", true)) or not (cleared.get("selected", {}) as Dictionary).is_empty() or not bool(cleared.get("visible", false)):
		return _fail("Selection, split popout or Escape layering failed.", {"selected": selected, "split": split_open, "cleared": cleared})
	return {"viewport": [viewport.x, viewport.y], "checks": checks, "legal_targets_when_selected": (selected.get("legal_targets", []) as Array).size()}

func _army_case() -> Dictionary:
	# 1. Move a whole stack into an empty slot of the partner.
	_press("left", "army", "1")
	_press("right", "army", "4")
	await get_tree().process_frame
	if not _army_is({_active_id: {0: [UNIT_A, 10]}, _reserve_id: {0: [UNIT_A, 4], 2: [UNIT_C, 2], 4: [UNIT_B, 5]}}):
		return _fail("Click move did not place the stack in the chosen partner slot.", _armies())
	# 2. The active hero's last stack may not leave: refused by the rules, explained, no mutation.
	_press("left", "army", "0")
	var preview: Dictionary = _screen.call("validation_snapshot")
	var before := _armies()
	_press("right", "army", "0")
	await get_tree().process_frame
	var refused: Dictionary = _screen.call("validation_snapshot")
	if "right:army:0" in preview.get("legal_targets", []) or _armies() != before \
		or not String(refused.get("status", "")).contains("must keep at least one troop stack") or String(refused.get("status_tone", "")) != "red":
		return _fail("Emptying a hero was not refused with a visible reason.", {"preview": preview, "refused": refused, "armies": _armies()})
	# 3. Keyboard merge: partner stack onto the same creature.
	await _keyboard_press(_cell("right", "army", "0"))
	await _keyboard_press(_cell("left", "army", "0"))
	if not _army_is({_active_id: {0: [UNIT_A, 14]}, _reserve_id: {2: [UNIT_C, 2], 4: [UNIT_B, 5]}}):
		return _fail("Keyboard merge did not combine the matching stacks.", _armies())
	# 4. Swap different creatures across heroes.
	_press("left", "army", "0")
	_press("right", "army", "2")
	await get_tree().process_frame
	if not _army_is({_active_id: {0: [UNIT_C, 2]}, _reserve_id: {2: [UNIT_A, 14], 4: [UNIT_B, 5]}}):
		return _fail("Cross-hero swap did not exchange the two stacks.", _armies())
	# 5. Shift-click split onto an empty slot of the other hero.
	_press("right", "army", "2")
	_press("left", "army", "3", true)
	var split: Dictionary = _screen.call("validation_snapshot")
	if not bool(split.get("split_open", false)) or int(split.get("split_max", 0)) != 13 or int(split.get("split_min", 0)) != 1:
		return _fail("Shift-click did not open the split slider.", split)
	_screen.call("set_split_amount", 5)
	_screen.call("confirm_split")
	await get_tree().process_frame
	if not _army_is({_active_id: {0: [UNIT_C, 2], 3: [UNIT_A, 5]}, _reserve_id: {2: [UNIT_A, 9], 4: [UNIT_B, 5]}}):
		return _fail("Split did not move the chosen amount.", _armies())
	# 6. Split button inside one hero's own formation.
	var split_button: Button = _screen.find_child("SplitStack", true, false)
	split_button.button_pressed = true
	_press("left", "army", "0")
	_press("left", "army", "6")
	var own_split: Dictionary = _screen.call("validation_snapshot")
	if not bool(own_split.get("split_open", false)) or int(own_split.get("split_max", 0)) != 1:
		return _fail("The Split button did not arm a split.", own_split)
	_screen.find_child("ConfirmSplit", true, false).emit_signal("pressed")
	await get_tree().process_frame
	if not _army_is({_active_id: {0: [UNIT_C, 1], 3: [UNIT_A, 5], 6: [UNIT_C, 1]}, _reserve_id: {2: [UNIT_A, 9], 4: [UNIT_B, 5]}}):
		return _fail("Split-button split did not divide the stack.", _armies())
	# 7. Drag & drop a stack between heroes.
	var source: Control = _cell("right", "army", "4")
	var target: Control = _cell("left", "army", "5")
	var payload = source.call("_get_drag_data", Vector2.ZERO)
	if not bool(target.call("_can_drop_data", Vector2.ZERO, payload)):
		return _fail("A legal stack drop was rejected.", payload)
	target.call("_drop_data", Vector2.ZERO, payload)
	await get_tree().process_frame
	if not _army_is({_active_id: {0: [UNIT_C, 1], 3: [UNIT_A, 5], 5: [UNIT_B, 5], 6: [UNIT_C, 1]}, _reserve_id: {2: [UNIT_A, 9]}}):
		return _fail("Drag and drop did not move the stack.", _armies())
	var blocked_payload = _cell("right", "army", "2").call("_get_drag_data", Vector2.ZERO)
	var blocked_drop := bool(_cell("left", "army", "3").call("_can_drop_data", Vector2.ZERO, blocked_payload))
	var blocked_status := String(_screen.call("validation_snapshot").get("status", ""))
	if blocked_drop or not blocked_status.contains("must keep at least one troop stack"):
		return _fail("Dragging the partner's last stack away was not refused with a reason.", blocked_status)
	# 8. Move all troops to the active hero: the partner keeps one creature.
	_press_button("TroopsAllLeft")
	await get_tree().process_frame
	if not _army_is({_active_id: {0: [UNIT_C, 1], 3: [UNIT_A, 13], 5: [UNIT_B, 5], 6: [UNIT_C, 1]}, _reserve_id: {2: [UNIT_A, 1]}}):
		return _fail("Move-all toward the active hero did not leave one creature behind.", _armies())
	# 9. Move all troops to the partner: merges, free slots, lowest tier keeps one.
	_press_button("TroopsAllRight")
	await get_tree().process_frame
	if not _army_is({_active_id: {3: [UNIT_A, 1]}, _reserve_id: {0: [UNIT_C, 2], 2: [UNIT_A, 13], 5: [UNIT_B, 5]}}):
		return _fail("Move-all toward the partner did not merge, place and keep one creature.", _armies())
	if _unit_totals() != _baseline_totals:
		return _fail("Troop exchanges changed total unit counts.", {"before": _baseline_totals, "after": _unit_totals()})
	return {
		"click_move": true,
		"last_stack_refused_with_reason": true,
		"keyboard_merge": true,
		"swap": true,
		"shift_split": true,
		"split_button": true,
		"drag_drop": true,
		"drag_refusal_reason": true,
		"move_all_both_ways_keeps_one": true,
		"unit_totals_preserved": true,
	}

func _artifact_case() -> Dictionary:
	# Click hands an artifact to the partner (matching empty slot).
	_press("left", "equip", "boots")
	await get_tree().process_frame
	if _location(_reserve_id, BOOTS_ID) != "equipped:boots" or ArtifactRules.has_artifact(_hero(_active_id), BOOTS_ID):
		return _fail("Clicking worn boots did not hand them to the partner's boots slot.", _artifacts())
	# Drag onto the other hero's backpack.
	_drag(_cell("right", "equip", "boots"), _cell("left", "pack", "0"))
	await get_tree().process_frame
	if _location(_active_id, BOOTS_ID) != "inventory:":
		return _fail("Dropping on the backpack did not stow the artifact there.", _artifacts())
	# Incompatible slot: refused with the reason, no mutation.
	var before := _artifacts()
	var payload = _cell("left", "pack", "0").call("_get_drag_data", Vector2.ZERO)
	var allowed := bool(_cell("right", "equip", "banner").call("_can_drop_data", Vector2.ZERO, payload))
	var status := String(_screen.call("validation_snapshot").get("status", ""))
	if allowed or not status.contains("boots slot") or _artifacts() != before:
		return _fail("An incompatible slot drop was not refused with a reason.", status)
	# Rearrange own gear: backpack to the boots slot.
	_drag(_cell("left", "pack", "0"), _cell("left", "equip", "boots"))
	await get_tree().process_frame
	if _location(_active_id, BOOTS_ID) != "equipped:boots":
		return _fail("Dropping on an own equipment slot did not equip the artifact.", _artifacts())
	# Drop onto the partner's occupied trinket slot: it is worn, the old one goes to the backpack.
	_drag(_cell("left", "equip", "trinket"), _cell("right", "equip", "trinket"))
	await get_tree().process_frame
	if _location(_reserve_id, ROD_ID) != "equipped:trinket" or _location(_reserve_id, LANTERN_ID) != "inventory:":
		return _fail("Slot-precise handoff did not displace the worn trinket into the backpack.", _artifacts())
	# Move all artifacts to the partner and back.
	_press_button("ArtifactsAllRight")
	await get_tree().process_frame
	var active_after := ArtifactRules.owned_artifact_ids(_hero(_active_id))
	if not active_after.is_empty() or _location(_reserve_id, GORGET_ID) != "equipped:armor" or _location(_reserve_id, COMPASS_ID) != "equipped:trinket_2":
		return _fail("Move-all artifacts did not hand every artifact over.", _artifacts())
	_press_button("ArtifactsAllLeft")
	await get_tree().process_frame
	if not ArtifactRules.owned_artifact_ids(_hero(_reserve_id)).is_empty() or ArtifactRules.owned_artifact_ids(_hero(_active_id)).size() != 6:
		return _fail("Move-all artifacts back did not return all six artifacts.", _artifacts())
	for artifact_id in [BOOTS_ID, GORGET_ID, ROD_ID, COMPASS_ID, LANTERN_ID, STANDARD_ID]:
		if _global_artifact_count(artifact_id) != 1:
			return _fail("An artifact was duplicated or lost.", {"artifact_id": artifact_id, "artifacts": _artifacts()})
	var snapshot: Dictionary = _screen.call("validation_snapshot")
	var left: Dictionary = snapshot.get("sides", {}).get("left", {})
	if (left.get("inventory", []) as Array).size() + _worn_count(left.get("equipped", {})) != 6:
		return _fail("The screen did not re-render the artifacts after the orders.", snapshot)
	return {
		"click_handoff": true,
		"drag_to_backpack": true,
		"incompatible_slot_refused": true,
		"own_gear_rearranged": true,
		"slot_precise_displacement": true,
		"move_all_both_ways": true,
		"no_duplicates": true,
	}

func _spell_case() -> Dictionary:
	var snapshot: Dictionary = _screen.call("validation_snapshot")
	var teachable: Array = snapshot.get("sides", {}).get("left", {}).get("teachable", [])
	if teachable.size() != 2:
		return _fail("The active hero's teachable spells were not listed.", snapshot)
	var spell_id := String(teachable[0])
	_press("left", "spell", "0")
	if not SpellRules.knows_spell(_hero(_reserve_id), spell_id) or not SpellRules.knows_spell(_hero(_active_id), spell_id):
		return _fail("Clicking a spell did not teach it while keeping it.", spell_id)
	var after: Array = _screen.call("validation_snapshot").get("sides", {}).get("left", {}).get("teachable", [])
	if after.size() != 1 or spell_id in after:
		return _fail("The taught spell stayed in the teach strip.", after)
	return {"taught": spell_id, "source_keeps_spell": true, "strip_updated": true}

func _close_case() -> Dictionary:
	_cancel()
	await get_tree().process_frame
	var surface: Dictionary = _shell.call("validation_snapshot").get("rendezvous", {})
	if bool(surface.get("exchange_open", true)) or String(_shell.call("_overworld_gameplay_movement_blocked_reason")) == "hero_exchange_open":
		return _fail("Escape did not close the meeting screen.", surface)
	var sheet: Control = _shell.call("validation_open_hero_sheet")
	await get_tree().process_frame
	await get_tree().process_frame
	var meet_button: Button = sheet.find_child("Meet_%s" % _reserve_id, true, false) as Button if sheet != null else null
	if _reserve_id not in surface.get("meet_hero_ids", []) or meet_button == null or not meet_button.is_visible_in_tree() or meet_button.disabled or meet_button.focus_mode != Control.FOCUS_ALL:
		return _fail("The hero sheet did not offer a Meet button for the partner.", surface)
	_capture("hero_sheet_meet_1920x1080")
	sheet.close_sheet()
	await get_tree().process_frame
	_shell.call("_on_context_action_pressed", "open_rendezvous")
	await get_tree().process_frame
	if not _screen.visible:
		return _fail("The Meet context action did not reopen the meeting screen.")
	_press_button("DoneExchange")
	await get_tree().process_frame
	if _screen.visible:
		return _fail("Done did not close the meeting screen.")
	return {"escape_closes": true, "meet_button": true, "context_action_opens": true, "done_closes": true}

func _save_case() -> Dictionary:
	HeroCommandRules.normalize_session(_session)
	OverworldRules.normalize_overworld_state(_session)
	var armies := _armies()
	var artifacts := _artifacts()
	var save_result: Dictionary = SaveService.save_runtime_manual_session(_session, SAVE_SLOT)
	var restored = SaveService.restore_manual_session(SAVE_SLOT)
	if not bool(save_result.get("ok", false)) or restored == null:
		return _fail("The exchanged state did not save and restore.", save_result)
	OverworldRules.normalize_overworld_state(restored)
	var restored_session = _session
	_session = restored
	var restored_armies := _armies()
	var restored_artifacts := _artifacts()
	_session = restored_session
	if restored_armies != armies or restored_artifacts != artifacts:
		return _fail("Exchanged armies or artifacts changed across save/restore.", {"before": armies, "after": restored_armies})
	return {"save_resume_preserved": true}

func _partner_case() -> Dictionary:
	# A third commander on the tile: the screen offers a partner switch.
	var third_id := "hero_mira" if "hero_mira" not in [_active_id, _reserve_id] else "hero_seren"
	var third := HeroCommandRules.build_hero_from_template(
		ContentService.get_hero(third_id),
		{"x": 1, "y": 1},
		{"id": "%s_army" % third_id, "name": "Third Army", "stacks": [
			{"unit_id": UNIT_B, "count": 3, "slot_index": 0},
			{"unit_id": UNIT_C, "count": 1, "slot_index": 1},
		]},
		_session
	)
	var heroes: Array = _session.overworld.get("player_heroes", [])
	heroes.append(third)
	_session.overworld["player_heroes"] = heroes
	HeroCommandRules.normalize_session(_session)
	_shell.call("validation_open_hero_exchange", _reserve_id)
	await get_tree().process_frame
	if int(_screen.call("validation_snapshot").get("partner_count", 0)) != 2:
		return _fail("Two partners on the tile did not offer a partner switch.", _screen.call("validation_snapshot"))
	_press_button("Partner_%s" % third_id)
	await get_tree().process_frame
	var switched: Dictionary = _screen.call("validation_snapshot")
	if String(switched.get("sides", {}).get("right", {}).get("hero_id", "")) != third_id:
		return _fail("The partner switch did not face the third commander.", switched)
	_press("right", "army", "0")
	_press("left", "army", "6")
	await get_tree().process_frame
	var active_slots: Dictionary = HeroCommandRules.army_slot_snapshot(_session, {}, _active_id)
	var moved: Dictionary = active_slots.get("slots", [])[6]
	if String(moved.get("unit_id", "")) != UNIT_B or int(moved.get("count", 0)) != 3:
		return _fail("A move with the switched partner did not reach the active hero.", active_slots)
	_press_button("DoneExchange")
	await get_tree().process_frame
	return {"partner_switch": true, "switched_partner_move": true}

# --- Helpers --------------------------------------------------------------

func _fixture() -> Dictionary:
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var active := HeroCommandRules.active_hero(session).duplicate(true)
	var active_id := String(active.get("id", ""))
	active["position"] = {"x": 1, "y": 1}
	active["army"] = {"id": "%s_army" % active_id, "name": "Field Army", "stacks": [
		{"unit_id": UNIT_A, "count": 10, "slot_index": 0},
		{"unit_id": UNIT_B, "count": 5, "slot_index": 1},
	]}
	for artifact_id in [BOOTS_ID, GORGET_ID, ROD_ID, COMPASS_ID]:
		active = ArtifactRules.claim_artifact(active, artifact_id, "Fixture", true).get("hero", active)
	active = _with_spells(active, ACTIVE_SPELLS)
	var reserve_id := "hero_caelen" if active_id != "hero_caelen" else "hero_mira"
	var reserve := HeroCommandRules.build_hero_from_template(
		ContentService.get_hero(reserve_id),
		{"x": 1, "y": 1},
		{"id": "%s_army" % reserve_id, "name": "Reserve Army", "stacks": [
			{"unit_id": UNIT_A, "count": 4, "slot_index": 0},
			{"unit_id": UNIT_C, "count": 2, "slot_index": 2},
		]},
		session
	)
	for artifact_id in [LANTERN_ID, STANDARD_ID]:
		reserve = ArtifactRules.claim_artifact(reserve, artifact_id, "Fixture", true).get("hero", reserve)
	reserve = _with_spells(reserve, RESERVE_SPELLS)
	session.overworld["player_heroes"] = [active, reserve]
	session.overworld["active_hero_id"] = active_id
	session.overworld["hero"] = active.duplicate(true)
	session.overworld["army"] = active.get("army", {}).duplicate(true)
	session.overworld["hero_position"] = active.get("position", {}).duplicate(true)
	session.overworld["movement"] = active.get("movement", {}).duplicate(true)
	session.scenario_status = "in_progress"
	session.game_state = "overworld"
	HeroCommandRules.normalize_session(session)
	OverworldRules.refresh_fog_of_war(session)
	return {"session": session, "active_id": active_id, "reserve_id": reserve_id}

func _with_spells(hero: Dictionary, spell_ids: Array) -> Dictionary:
	var updated := SpellRules.ensure_hero_spellbook(hero.duplicate(true))
	var spellbook: Dictionary = updated.get("spellbook", {}).duplicate(true)
	spellbook["known_spell_ids"] = spell_ids.duplicate()
	updated["spellbook"] = spellbook
	return updated

func _cell(side: String, kind: String, key: String) -> Control:
	return _screen.call("cell", side, kind, key)

func _press(side: String, kind: String, key: String, shift: bool = false) -> void:
	_screen.call("press_cell", _cell(side, kind, key), shift)

func _press_button(button_name: String) -> void:
	var button: Button = _screen.find_child(button_name, true, false)
	if button != null and not button.disabled:
		button.emit_signal("pressed")

func _drag(source: Control, target: Control) -> void:
	var payload = source.call("_get_drag_data", Vector2.ZERO)
	if bool(target.call("_can_drop_data", Vector2.ZERO, payload)):
		target.call("_drop_data", Vector2.ZERO, payload)

func _keyboard_press(target: Control) -> void:
	target.grab_focus()
	await get_tree().process_frame
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

func _cancel() -> void:
	var pressed := InputEventAction.new()
	pressed.action = &"ui_cancel"
	pressed.pressed = true
	Input.parse_input_event(pressed)
	var released := InputEventAction.new()
	released.action = &"ui_cancel"
	released.pressed = false
	Input.parse_input_event(released)

func _hero(hero_id: String) -> Dictionary:
	return HeroCommandRules.hero_by_id(_session, hero_id)

func _armies() -> Dictionary:
	var armies := {}
	for hero_id in [_active_id, _reserve_id]:
		var slots := {}
		for stack in HeroCommandRules.hero_inspection_snapshot(_session, hero_id).get("inspection_army_slots", []):
			slots[int(stack.get("slot_index", -1))] = [String(stack.get("unit_id", "")), int(stack.get("count", 0))]
		armies[hero_id] = slots
	return armies

func _army_is(expected: Dictionary) -> bool:
	return _armies() == expected

func _unit_totals() -> Dictionary:
	var totals := {}
	for hero_id in [_active_id, _reserve_id]:
		for stack in HeroCommandRules.hero_by_id(_session, hero_id).get("army", {}).get("stacks", []):
			var unit_id := String(stack.get("unit_id", ""))
			totals[unit_id] = int(totals.get(unit_id, 0)) + int(stack.get("count", 0))
	return totals

func _artifacts() -> Dictionary:
	var rows := {}
	for hero_id in [_active_id, _reserve_id]:
		rows[hero_id] = ArtifactRules.normalize_hero_artifacts(_hero(hero_id).get("artifacts", {}))
	return rows

func _location(hero_id: String, artifact_id: String) -> String:
	var location := ArtifactRules.locate_artifact(_hero(hero_id), artifact_id)
	return "%s:%s" % [String(location.get("location", "")), String(location.get("slot", ""))]

func _global_artifact_count(artifact_id: String) -> int:
	var count := 0
	for hero_value in _session.overworld.get("player_heroes", []):
		if hero_value is Dictionary and ArtifactRules.has_artifact(hero_value, artifact_id):
			count += 1
	return count

func _worn_count(equipped: Dictionary) -> int:
	var count := 0
	for artifact_id in equipped.values():
		if String(artifact_id) != "":
			count += 1
	return count

func _checks_pass(checks: Dictionary) -> bool:
	for value in checks.values():
		if not bool(value):
			return false
	return true

func _capture(label: String) -> void:
	var output_dir := OS.get_environment("HEROES_HERO_EXCHANGE_CAPTURE_DIR").strip_edges()
	if output_dir == "" or DisplayServer.get_name() == "headless":
		return
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		return
	var path := output_dir.path_join("hero_exchange_%s.png" % label)
	var image := get_viewport().get_texture().get_image()
	if image != null and not image.is_empty() and image.save_png(path) == OK:
		_screenshots.append(path)

func _fail(message: String, payload: Variant = {}) -> Dictionary:
	push_error("%s failed: %s payload=%s" % [REPORT_ID, message, JSON.stringify(payload)])
	get_tree().quit(1)
	return {}
