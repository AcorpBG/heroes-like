extends Node

const REPORT_ID := "OVERWORLD_ROUTE_TOOLTIP_SMOKE"
const GENERATED_COMPACT_MAP_CUE_TOOLTIP := "Map art and controls are loaded; save summary and detailed rails are deferred off routine generated-map frames."

var _original_session = null
var _original_window_size := Vector2i.ZERO
var _original_files: Dictionary = {}
var _original_summary_cache: Dictionary = {}
var _original_settings: Dictionary = {}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_original_session = SessionState.active_session
	_original_window_size = get_window().size
	_original_files = _capture_file_states(_authority_paths())
	_original_summary_cache = SaveService.validation_summary_cache_snapshot()
	_original_settings = _canonical_settings_transaction(SettingsService.validation_settings_transaction_snapshot())
	if not _assert_town_control_label_mapping_contract():
		return
	var route_rows: Array = await _assert_route_cue_width_matrix()
	if route_rows.is_empty():
		return
	if not await _assert_existing_town_spell_and_action_consequences():
		return
	_cleanup()
	var cleanup_checks := {
		"files_exact": _capture_file_states(_authority_paths()) == _original_files,
		"save_cache_exact": SaveService.validation_summary_cache_snapshot() == _original_summary_cache,
		"settings_exact": _canonical_settings_transaction(SettingsService.validation_settings_transaction_snapshot()) == _original_settings,
		"session_identity_exact": is_same(SessionState.active_session, _original_session),
		"window_size_exact": get_window().size == _original_window_size,
	}
	if not _checks_exact(cleanup_checks):
		_fail("Route tooltip smoke cleanup did not restore full files/cache/settings/session/window authority.", cleanup_checks)
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"widths": [1280, 1920],
		"town_wood_open_town_wood_inverse": true,
		"adjacent_open_2_2_march_selected_step_1": true,
		"current_and_no_movement_disabled_rows": true,
		"bound_no_op": true,
		"feedback_priority": true,
		"generated_pending_compact_policies": true,
		"full_authority": true,
		"existing_town_spell_action_consequences": true,
		"rows": route_rows,
	})])
	get_tree().quit(0)

func _assert_existing_town_spell_and_action_consequences() -> bool:
	var session = ScenarioFactory.create_session(
		"river-pass",
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	SessionState.set_active_session(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame

	_set_active_hero_position(session, Vector2i(1, 2))
	var movement: Dictionary = session.overworld.get("movement", {})
	movement["current"] = int(movement.get("max", movement.get("current", 0)))
	session.overworld["movement"] = movement
	OverworldRules.refresh_fog_of_war(session)
	shell.call("_refresh")

	var snapshot: Dictionary = shell.call("validation_select_tile", 1, 0)
	var route_decision: Dictionary = snapshot.get("selected_route_decision", {})
	var decision_brief: Dictionary = route_decision.get("decision_brief", {})
	var joined := "\n".join([
		String(route_decision.get("decision_brief_text", "")),
		String(decision_brief.get("affected", "")),
		String(decision_brief.get("why_it_matters", "")),
		String(decision_brief.get("next_step", "")),
		String(snapshot.get("map_cue_text", "")),
		String(snapshot.get("map_cue_tooltip_text", "")),
		String(snapshot.get("map_tooltip", "")),
		String(snapshot.get("primary_action", {}).get("summary", "")),
	])
	if String(route_decision.get("status", "")) != "reachable":
		_fail("Route tooltip smoke: Wood Wagon route should be reachable.", snapshot)
		return false
	if String(route_decision.get("action_kind", "")) != "move/collect":
		_fail("Route tooltip smoke: Wood Wagon route should expose move/collect.", snapshot)
		return false
	if not _assert_text_contains_all(
		"Route tooltip smoke",
		joined,
		[
			"Decision Brief",
			"Affected:",
			"Wood Wagon route",
			"Objective:",
			"Claim Duskfen Bastion",
			"Why it matters:",
			"Next:",
			"Commit Advance to Site now.",
			"Try: Advance to Site [Enter]",
		]
	):
		return false
	if not _assert_no_ai_score_leak("Route tooltip smoke", joined):
		return false
	if not _assert_town_entry_handoff_cue(shell):
		return false
	if not await _assert_overworld_spell_check_cue(shell):
		return false
	shell.queue_free()
	await _settle()
	return true

func _assert_town_control_label_mapping_contract() -> bool:
	var expected_labels := {
		"player": "Your Control",
		"enemy": "Enemy Control",
		"neutral": "Neutral Control",
		"unsupported_internal_owner": "Unknown Control",
	}
	for owner_value in expected_labels:
		var expected := String(expected_labels[owner_value])
		var overworld_label := OverworldRules.town_control_label(owner_value)
		var town_label := TownRules.town_control_label(owner_value)
		if overworld_label != expected \
				or town_label != expected \
				or overworld_label.contains(owner_value) \
				or town_label.contains(owner_value):
			_fail("Town control-label mapping did not remain exact and shared for %s." % owner_value, {
				"expected": expected,
				"overworld": overworld_label,
				"town": town_label,
			})
			return false
	return true

func _assert_route_cue_width_matrix() -> Array:
	var rows: Array = []
	for width in [1280, 1920]:
		var row: Dictionary = await _assert_route_cue_width(width)
		if row.is_empty():
			return []
		rows.append(row)
	return rows

func _assert_route_cue_width(width: int) -> Dictionary:
	var height := 1080 if width == 1920 else 720
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	_set_active_hero_position(session, Vector2i(1, 2))
	var movement: Dictionary = session.overworld.get("movement", {})
	movement["current"] = int(movement.get("max", movement.get("current", 0)))
	session.overworld["movement"] = movement
	OverworldRules.refresh_fog_of_war(session)
	SessionState.set_active_session(session)
	get_window().size = Vector2i(width, height)
	var host := Control.new()
	host.name = "RouteTooltipHost%d" % width
	host.size = Vector2(float(width), float(height))
	add_child(host)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	host.add_child(shell)
	await _settle()
	var shell_session = shell.get("_session")
	if shell_session != null:
		session = shell_session
	_set_active_hero_position(session, Vector2i(1, 2))
	movement = session.overworld.get("movement", {})
	movement["current"] = int(movement.get("max", movement.get("current", 0)))
	session.overworld["movement"] = movement
	OverworldRules.refresh_fog_of_war(session)
	shell.call("_refresh")
	await _settle()
	if Vector2i(host.size) != Vector2i(width, height):
		_fail("%dx%d route tooltip host size was not exact." % [width, height], {"host_size": host.size})
		await _discard_host(host)
		return {}

	var authority_before: Dictionary = _route_authority(shell, session)
	var town: Dictionary = shell.call("validation_select_tile", 0, 2)
	if not _assert_live_town_control_surfaces(shell, session, town, width):
		await _discard_host(host)
		return {}
	if not _assert_exact_route_surface(shell, town, {
		"label": "town", "tile": {"x": 0, "y": 2}, "action_id": "march_selected", "action_label": "Visit Town",
		"cue": "Try: Visit Town [Enter]", "button": "Visit Town [Enter]", "destination": "Riverwatch Hold",
		"status": "reachable", "action_kind": "town", "steps": 1, "cost": 1, "after": 13, "next": {"x": 0, "y": 2},
		"tooltip": "Visit Town Riverwatch Hold. Move to Riverwatch Hold; 1 step, Move 14->13. Try Visit Town with Enter or Space now.",
		"required": [],
		"forbidden": ["Wood Wagon route", "Advance to Site"],
	}):
		await _discard_host(host)
		return {}
	var town_payload := _route_cue_payload(town)

	var wood: Dictionary = shell.call("validation_select_tile", 1, 0)
	if not _assert_exact_route_surface(shell, wood, {
		"label": "wood", "tile": {"x": 1, "y": 0}, "action_id": "advance_route", "action_label": "Advance to Site",
		"cue": "Try: Advance to Site [Enter]", "button": "Advance to Site [Enter]", "destination": "Wood Wagon",
		"status": "reachable", "action_kind": "move/collect", "steps": 2, "cost": 2, "after": 12, "next": {"x": 1, "y": 1},
		"tooltip": "Advance to Site Wood Wagon. Move to Wood Wagon; 2 steps, Move 14->12. Try Advance to Site with Enter or Space now.",
		"required": [],
		"forbidden": ["Route: Riverwatch Hold |", "Visit Town"],
	}):
		await _discard_host(host)
		return {}
	var town_hover: Dictionary = shell.call("validation_hover_tile", 0, 2)
	var hover_text := String(town_hover.get("map_tooltip", ""))
	if not hover_text.contains("Town: Riverwatch Hold | Your Control | ") \
			or hover_text.contains("Owner Player") \
			or hover_text.contains("Town: Player"):
		_fail("%d visible Town hover did not expose exact player-facing control copy." % width, town_hover)
		await _discard_host(host)
		return {}
	shell.call("validation_hover_tile", 1, 0)
	var wood_payload := _route_cue_payload(wood)

	var open: Dictionary = shell.call("validation_select_tile", 2, 2)
	if not _assert_exact_route_surface(shell, open, {
		"label": "open", "tile": {"x": 2, "y": 2}, "action_id": "march_selected", "action_label": "March",
		"cue": "Try: March [Enter]", "button": "March [Enter]", "destination": "2,2",
		"status": "reachable", "action_kind": "move", "steps": 1, "cost": 1, "after": 13, "next": {"x": 2, "y": 2},
		"tooltip": "Route: 2,2 | Move | 1 step | reachable today | Move 14->13 | Next step: 2,2 via Grassland (arrives at target). Press Enter or Space to commit this route order. Try March with Enter or Space now.",
		"required": [],
		"forbidden": ["Wood Wagon route", "Route: Riverwatch Hold |", "Advance to Site", "Visit Town"],
	}):
		await _discard_host(host)
		return {}

	var town_inverse: Dictionary = shell.call("validation_select_tile", 0, 2)
	if _route_cue_payload(town_inverse) != town_payload:
		_fail("%d town inverse did not restore the exact cue/action/button/route payload." % width, {
			"before": town_payload, "after": _route_cue_payload(town_inverse),
		})
		await _discard_host(host)
		return {}
	var wood_inverse: Dictionary = shell.call("validation_select_tile", 1, 0)
	if _route_cue_payload(wood_inverse) != wood_payload:
		_fail("%d Wood Wagon inverse did not restore the exact cue/action/button/route payload." % width, {
			"before": wood_payload, "after": _route_cue_payload(wood_inverse),
		})
		await _discard_host(host)
		return {}
	var bound_no_op: Dictionary = shell.call("validation_select_tile", 1, 0)
	if _route_cue_payload(bound_no_op) != wood_payload:
		_fail("%d same-tile bound no-op changed the Wood Wagon cue/action/button/route payload." % width, {
			"before": wood_payload, "after": _route_cue_payload(bound_no_op),
		})
		await _discard_host(host)
		return {}

	var current: Dictionary = shell.call("validation_select_tile", 1, 2)
	if not _assert_exact_route_surface(shell, current, {
		"label": "current", "tile": {"x": 1, "y": 2}, "action_id": "", "action_label": "", "action_payload_empty": true,
		"cue": "Move 14/14 | Select destination", "button": "Select Site", "action_disabled": false, "button_disabled": true,
		"button_tooltip": "Current position. Select a mapped destination to plot a route.", "destination": "Frontier Rare Exchange",
		"status": "current", "action_kind": "hold", "steps": 0, "cost": 0, "after": 14, "next": {"x": -1, "y": -1},
		"required": ["Route: Frontier Rare Exchange", "current tile", "Select a visible destination or open a command drawer."],
		"forbidden": ["Wood Wagon route", "Route: Riverwatch Hold |", "Advance to Site", "Visit Town", "Commit March", "Try:"],
	}):
		await _discard_host(host)
		return {}

	var movement_before_disabled: Dictionary = session.overworld.get("movement", {}).duplicate(true)
	var zero_movement: Dictionary = movement_before_disabled.duplicate(true)
	zero_movement["current"] = 0
	session.overworld["movement"] = zero_movement
	HeroCommandRules.commit_active_hero(session)
	var zero_movement_mirror_checks := _movement_mirror_checks(session, zero_movement)
	if not _checks_exact(zero_movement_mirror_checks):
		_fail("%d zero-movement fixture did not commit all active-hero mirrors exactly." % width, zero_movement_mirror_checks)
		await _discard_host(host)
		return {}
	shell.call("_refresh")
	var no_movement: Dictionary = shell.call("validation_select_tile", 1, 0)
	if not _assert_exact_route_surface(shell, no_movement, {
		"label": "no_movement", "tile": {"x": 1, "y": 0}, "action_id": "", "action_label": "", "action_payload_empty": true,
		"cue": "Route: Wood Wagon | no movement | Move 0->0", "button": "Select Site", "action_disabled": false, "button_disabled": true,
		"button_tooltip_matches_cue": true, "destination": "Wood Wagon", "route_action_label": "Advance to Site",
		"status": "no_movement", "action_kind": "move/collect", "steps": 2, "cost": 2, "after": 0, "next": {"x": 1, "y": 1},
		"reason": "No movement left today.",
		"required": ["Route: Wood Wagon", "No movement left today.", "Decision Brief"],
		"forbidden": ["Route: Riverwatch Hold |", "Visit Town", "Try Advance to Site with Enter or Space now."],
	}):
		await _discard_host(host)
		return {}
	session.overworld["movement"] = movement_before_disabled
	HeroCommandRules.commit_active_hero(session)
	var restored_movement_mirror_checks := _movement_mirror_checks(session, movement_before_disabled)
	if not _checks_exact(restored_movement_mirror_checks):
		_fail("%d restored movement fixture did not commit all active-hero mirrors exactly." % width, restored_movement_mirror_checks)
		await _discard_host(host)
		return {}
	shell.call("_refresh")
	var normal_route_restored: Dictionary = shell.call("validation_select_tile", 1, 0)
	if _route_cue_payload(normal_route_restored) != wood_payload:
		_fail("%d restoring movement did not restore the exact normal Wood Wagon cue." % width, _route_cue_payload(normal_route_restored))
		await _discard_host(host)
		return {}

	var feedback_event_before := _rendered_event_payload(normal_route_restored)
	shell.call("_record_action_feedback", "system", "Route feedback priority")
	var feedback: Dictionary = shell.call("validation_select_tile", 0, 2)
	var feedback_checks := {
		"action_current": String(feedback.get("primary_action_id", "")) == "march_selected",
		"cue_feedback_priority": String(feedback.get("map_cue_text", "")) == "System: Route feedback priority",
		"tooltip_feedback_priority": String(feedback.get("map_cue_tooltip_text", "")).begins_with("System: Route feedback priority."),
		"route_not_rendered_over_feedback": not String(feedback.get("map_cue_text", "")).contains("Visit Town"),
		"event_feedback_byte_exact": _rendered_event_payload(feedback) == feedback_event_before,
	}
	if not _checks_exact(feedback_checks) or not _assert_current_readiness_surfaces(shell, feedback, "%d feedback-preserved Town" % width, ["Wood Wagon route", "Advance to Site"], false):
		_fail("%d route refresh did not preserve action-feedback cue priority." % width, {"checks": feedback_checks, "snapshot": _route_cue_payload(feedback)})
		await _discard_host(host)
		return {}
	shell.set("_action_feedback", {})
	var restored_town: Dictionary = shell.call("validation_select_tile", 0, 2)
	if _route_cue_payload(restored_town) != town_payload:
		_fail("%d clearing feedback did not restore the exact current Town cue." % width, _route_cue_payload(restored_town))
		await _discard_host(host)
		return {}

	var recap := {
		"happened": "Route recap remains authoritative.",
		"affected": "The prior order result remains visible.",
		"why_it_matters": "A destination preview must not overwrite resolved action context.",
		"next_step": "Review the next route without replacing this recap.",
		"cue_text": "Route recap remains authoritative",
		"tooltip_text": "Resolved Route Recap\n- The prior order result remains visible.",
	}
	shell.set("_last_action_recap", recap.duplicate(true))
	shell.call("_refresh")
	var recap_before: Dictionary = shell.call("validation_snapshot")
	var recap_event_before := _rendered_event_payload(recap_before)
	var recap_wood: Dictionary = shell.call("validation_select_tile", 1, 0)
	var recap_checks := {
		"action_current": String(recap_wood.get("primary_action_id", "")) == "advance_route",
		"recap_event_byte_exact": _rendered_event_payload(recap_wood) == recap_event_before,
		"recap_payload_exact": recap_wood.get("post_action_recap", {}) == recap,
	}
	if not _checks_exact(recap_checks) or not _assert_current_readiness_surfaces(shell, recap_wood, "%d recap-preserved Wood" % width, ["Route: Riverwatch Hold |", "Visit Town"], false):
		_fail("%d targeted route refresh overwrote the active recap Event surface or left other readiness controls stale." % width, {
			"checks": recap_checks,
			"before": recap_event_before,
			"after": _rendered_event_payload(recap_wood),
		})
		await _discard_host(host)
		return {}
	shell.set("_last_action_recap", {})
	var recap_released: Dictionary = shell.call("validation_select_tile", 1, 0)
	if _route_cue_payload(recap_released) != wood_payload:
		_fail("%d clearing the recap did not restore the exact current Wood readiness surface." % width, {
			"before": wood_payload,
			"after": _route_cue_payload(recap_released),
		})
		await _discard_host(host)
		return {}

	session.flags["generated_random_map"] = true
	session.flags["generated_overworld_deferred_autosave_pending"] = true
	shell.call("_refresh")
	var opening: Dictionary = shell.call("validation_snapshot")
	var opening_checks := {
		"opening_text_exact": String(opening.get("map_cue_text", "")) == "Opening generated map",
		"opening_tooltip_exact": String(opening.get("map_cue_tooltip_text", "")) == GENERATED_COMPACT_MAP_CUE_TOOLTIP,
	}
	if not _checks_exact(opening_checks):
		_fail("%d full generated-opening MapCue policy was not established exactly." % width, {"checks": opening_checks, "snapshot": _route_cue_payload(opening)})
		await _discard_host(host)
		return {}
	var opening_text := String(opening.get("map_cue_text", ""))
	var opening_tooltip := String(opening.get("map_cue_tooltip_text", ""))
	var opening_readiness_payload := _rendered_readiness_payload(opening)
	var pending: Dictionary = shell.call("validation_select_tile", 1, 0)
	var pending_checks := {
		"action_advanced": String(pending.get("primary_action_id", "")) == "advance_route",
		"action_label_current": String(pending.get("primary_action", {}).get("label", "")) == "Advance to Site",
		"cue_opening_byte_exact": String(pending.get("map_cue_text", "")) == opening_text,
		"tooltip_opening_byte_exact": String(pending.get("map_cue_tooltip_text", "")) == opening_tooltip,
		"readiness_opening_byte_exact": _rendered_readiness_payload(pending) == opening_readiness_payload,
	}
	if not _checks_exact(pending_checks):
		_fail("%d targeted Wood selection changed the exact full generated-opening MapCue surface." % width, {"checks": pending_checks, "opening": _route_cue_payload(opening), "after": _route_cue_payload(pending)})
		await _discard_host(host)
		return {}
	session.flags.erase("generated_overworld_deferred_autosave_pending")
	var pending_released: Dictionary = shell.call("validation_select_tile", 1, 0)
	var pending_release_checks := {
		"action_current": String(pending_released.get("primary_action_id", "")) == "advance_route",
		"wood_cue_current": String(pending_released.get("map_cue_text", "")) == "Try: Advance to Site [Enter]",
		"compact_tooltip_exact": String(pending_released.get("map_cue_tooltip_text", "")) == GENERATED_COMPACT_MAP_CUE_TOOLTIP,
		"readiness_compact_byte_exact": _rendered_readiness_payload(pending_released) == opening_readiness_payload,
	}
	if not _checks_exact(pending_release_checks):
		_fail("%d pending release did not publish current Wood text with compact generated tooltip." % width, {"checks": pending_release_checks, "snapshot": _route_cue_payload(pending_released)})
		await _discard_host(host)
		return {}
	session.flags.erase("generated_random_map")
	var compact_released: Dictionary = shell.call("validation_select_tile", 1, 0)
	if _route_cue_payload(compact_released) != wood_payload:
		_fail("%d compact release did not restore the exact normal Wood Wagon cue." % width, _route_cue_payload(compact_released))
		await _discard_host(host)
		return {}

	var authority_after: Dictionary = _route_authority(shell, session)
	var authority_checks: Dictionary = _route_authority_checks(authority_before, authority_after, session)
	if not _checks_exact(authority_checks):
		_fail("%d cue-only route matrix changed full session/files/cache/settings/routes authority." % width, {
			"checks": authority_checks, "before": authority_before, "after": authority_after,
		})
		await _discard_host(host)
		return {}
	await _discard_host(host)
	return {
		"width": width,
		"height": height,
		"town_wood_open_town_wood_inverse": true,
		"adjacent_open_2_2_march_selected_step_1": true,
		"current_and_no_movement_disabled_rows": true,
		"bound_no_op": true,
		"feedback_priority": true,
		"generated_pending_compact_policies": true,
		"authority_exact": true,
	}

func _assert_live_town_control_surfaces(shell: Node, session, snapshot: Dictionary, width: int) -> bool:
	var context_text := String(snapshot.get("context_summary", ""))
	var rail_text := String(snapshot.get("selected_tile_rail_text", ""))
	var decision: Dictionary = snapshot.get("selected_route_decision", {}) if snapshot.get("selected_route_decision", {}) is Dictionary else {}
	var scenario_id_before := String(session.scenario_id)
	session.scenario_id = ""
	var route_affected := String(shell.call("_route_decision_affected_text", decision))
	session.scenario_id = scenario_id_before
	var checks := {
		"context_control_exact": context_text.contains("Riverwatch Hold | Embercourt League | Your Control | Frontier Stronghold"),
		"rail_control_exact": rail_text.contains("Your Control | "),
		"route_affected_exact": route_affected == "Riverwatch Hold route | Town: Your Control",
		"context_raw_owner_absent": not context_text.contains("Owner Player"),
		"rail_raw_owner_absent": not rail_text.contains("Owner Player"),
		"route_raw_owner_absent": not route_affected.contains("Town: Player"),
		"scenario_restored_exact": String(session.scenario_id) == scenario_id_before,
	}
	if not _checks_exact(checks):
		_fail("%d selected Town surfaces did not expose exact player-facing control copy." % width, {
			"checks": checks,
			"context": context_text,
			"rail": rail_text,
			"route_affected": route_affected,
		})
		return false
	return true

func _assert_exact_route_surface(shell: Node, snapshot: Dictionary, expected: Dictionary) -> bool:
	var action: Dictionary = snapshot.get("primary_action", {}) if snapshot.get("primary_action", {}) is Dictionary else {}
	var decision: Dictionary = snapshot.get("selected_route_decision", {}) if snapshot.get("selected_route_decision", {}) is Dictionary else {}
	var next_step: Dictionary = decision.get("next_step", {}) if decision.get("next_step", {}) is Dictionary else {}
	var tooltip := String(snapshot.get("map_cue_tooltip_text", ""))
	var required_exact := true
	for token in expected.get("required", []):
		required_exact = required_exact and tooltip.contains(String(token))
	var stale_free := true
	for token in expected.get("forbidden", []):
		stale_free = stale_free and not tooltip.contains(String(token))
	var expected_action_disabled := bool(expected.get("action_disabled", expected.get("disabled", false)))
	var expected_button_disabled := bool(expected.get("button_disabled", expected.get("disabled", false)))
	var checks := {
		"selected_tile_exact": snapshot.get("selected_tile", {}) == expected.get("tile", {}),
		"action_id_exact": String(snapshot.get("primary_action_id", "")) == String(expected.get("action_id", "")),
		"action_payload_empty_exact": action.is_empty() == bool(expected.get("action_payload_empty", false)),
		"action_payload_id_exact": String(action.get("id", "")) == String(expected.get("action_id", "")),
		"action_label_exact": String(action.get("label", "")) == String(expected.get("action_label", "")),
		"button_text_exact": String(snapshot.get("primary_action_button_text", "")) == String(expected.get("button", "")),
		"action_disabled_exact": bool(action.get("disabled", false)) == expected_action_disabled,
		"button_disabled_exact": bool(snapshot.get("primary_action_button_disabled", true)) == expected_button_disabled,
		"button_tooltip_exact": not expected.has("button_tooltip") or String(snapshot.get("primary_action_button_tooltip_text", "")) == String(expected.get("button_tooltip", "")),
		"button_tooltip_matches_cue": not bool(expected.get("button_tooltip_matches_cue", false)) or String(snapshot.get("primary_action_button_tooltip_text", "")) == tooltip,
		"cue_text_exact": String(snapshot.get("map_cue_text", "")) == String(expected.get("cue", "")),
		"cue_text_current": String(snapshot.get("map_cue_text", "")) == String(shell.call("_map_cue_text")),
		"cue_tooltip_current": tooltip == String(shell.call("_map_cue_tooltip")),
		"tooltip_exact": not expected.has("tooltip") or tooltip == String(expected.get("tooltip", "")),
		"tooltip_required_exact": required_exact,
		"tooltip_stale_free": stale_free,
		"route_destination_exact": String(decision.get("destination", "")) == String(expected.get("destination", "")),
		"route_status_exact": String(decision.get("status", "")) == String(expected.get("status", "")),
		"route_reason_exact": String(decision.get("blocked_reason", "")) == String(expected.get("reason", "")),
		"route_action_kind_exact": String(decision.get("action_kind", "")) == String(expected.get("action_kind", "")),
		"route_action_label_exact": not expected.has("route_action_label") or String(decision.get("action_label", "")) == String(expected.get("route_action_label", "")),
		"route_steps_exact": int(decision.get("steps", -1)) == int(expected.get("steps", -1)),
		"route_cost_exact": int(decision.get("movement_cost", -1)) == int(expected.get("cost", -1)),
		"route_movement_after_exact": int(decision.get("movement_after_order", -1)) == int(expected.get("after", -1)),
		"route_next_step_exact": {"x": int(next_step.get("x", -1)), "y": int(next_step.get("y", -1))} == expected.get("next", {}),
	}
	if not _checks_exact(checks):
		_fail("Route tooltip %s surface was not current and exact." % String(expected.get("label", "route")), {
			"checks": checks, "snapshot": _route_cue_payload(snapshot),
		})
		return false
	if not _assert_current_readiness_surfaces(shell, snapshot, String(expected.get("label", "route")), expected.get("forbidden", []), true):
		return false
	return true

func _assert_current_readiness_surfaces(shell: Node, snapshot: Dictionary, label: String, stale_tokens: Array, expect_event_current: bool) -> bool:
	var session = shell.get("_session")
	var readiness: Dictionary = shell.call("_field_readiness_surface")
	var end_turn: Dictionary = shell.call("_end_turn_confirmation_surface", readiness)
	var drawer: Dictionary = shell.call("_drawer_handoff_surfaces", readiness)
	var expected_objective_tooltip := String(shell.call("_join_tooltip_sections", [
		OverworldRules.describe_objective_stakes_board(session),
		String(readiness.get("tooltip_text", "")),
	]))
	var event_surface: Dictionary = _expected_route_event_surface(shell, readiness)
	var action_context: Dictionary = shell.call("_action_context_surface", event_surface, readiness)
	var expected_event_visible := String(shell.call("_trim_rail_visible_text", String(action_context.get("visible_text", "")), 1, 42))
	var command: Dictionary = drawer.get("command", {}) if drawer.get("command", {}) is Dictionary else {}
	var frontier: Dictionary = drawer.get("frontier", {}) if drawer.get("frontier", {}) is Dictionary else {}
	var checks := {
		"field_readiness_current": snapshot.get("field_readiness", {}) == readiness,
		"objective_brief_tooltip_current": String(snapshot.get("objective_brief_tooltip_text", "")) == expected_objective_tooltip,
		"event_visible_current_or_preserved": not expect_event_current or String(snapshot.get("event_visible_text", "")) == expected_event_visible,
		"event_tooltip_current_or_preserved": not expect_event_current or String(snapshot.get("event_tooltip_text", "")) == String(action_context.get("tooltip_text", "")),
		"end_turn_payload_current": snapshot.get("end_turn_confirmation", {}) == end_turn,
		"end_turn_button_current": String(snapshot.get("end_turn_button_text", "")) == String(end_turn.get("button_text", "")),
		"end_turn_tooltip_current": String(snapshot.get("end_turn_tooltip_text", "")) == String(end_turn.get("tooltip_text", "")),
		"drawer_payload_current": snapshot.get("drawer_handoff", {}) == drawer,
		"command_button_current": String(snapshot.get("command_drawer_button_text", "")) == String(command.get("button_text", "")),
		"command_tooltip_current": String(snapshot.get("command_drawer_tooltip_text", "")) == String(command.get("tooltip_text", "")),
		"frontier_button_current": String(snapshot.get("frontier_drawer_button_text", "")) == String(frontier.get("button_text", "")),
		"frontier_tooltip_current": String(snapshot.get("frontier_drawer_tooltip_text", "")) == String(frontier.get("tooltip_text", "")),
	}
	var actual_text_parts: Array = [
		String(snapshot.get("objective_brief_tooltip_text", "")),
		String(snapshot.get("end_turn_button_text", "")),
		String(snapshot.get("end_turn_tooltip_text", "")),
		String(snapshot.get("command_drawer_button_text", "")),
		String(snapshot.get("command_drawer_tooltip_text", "")),
		String(snapshot.get("frontier_drawer_button_text", "")),
		String(snapshot.get("frontier_drawer_tooltip_text", "")),
	]
	if expect_event_current:
		actual_text_parts.append(String(snapshot.get("event_visible_text", "")))
		actual_text_parts.append(String(snapshot.get("event_tooltip_text", "")))
	var actual_text := "\n".join(actual_text_parts)
	for stale_token_value in stale_tokens:
		var stale_token := String(stale_token_value)
		checks["stale_absent_%s" % stale_token] = stale_token == "" or not actual_text.contains(stale_token)
	if not _checks_exact(checks):
		_fail("Route tooltip %s rendered readiness controls were not current and stale-free." % label, {
			"checks": checks,
			"expected": {
				"readiness": readiness,
				"objective_tooltip": expected_objective_tooltip,
				"event": action_context,
				"end_turn": end_turn,
				"drawer": drawer,
			},
			"actual": _rendered_readiness_payload(snapshot),
		})
		return false
	return true

func _expected_route_event_surface(shell: Node, readiness: Dictionary) -> Dictionary:
	var session = shell.get("_session")
	var event_surface := OverworldRules.describe_event_feed_surface(
		session,
		String(shell.get("_last_message")),
		String(shell.get("_last_turn_resolution_text")),
		String(shell.get("_last_enemy_activity_text")),
		shell.get("_last_enemy_activity_events"),
		shell.get("_last_action_recap")
	)
	event_surface["field_readiness"] = readiness
	if bool(shell.call("_field_feed_is_idle")):
		var visible_text := String(readiness.get("visible_text", "")).strip_edges()
		if visible_text != "":
			event_surface["visible_text"] = visible_text
		event_surface["tooltip_text"] = String(shell.call("_join_tooltip_sections", [
			String(event_surface.get("tooltip_text", "")),
			String(readiness.get("tooltip_text", "")),
		]))
	event_surface["dispatch_text"] = OverworldRules.describe_dispatch(session, String(shell.get("_last_message")))
	return event_surface

func _route_cue_payload(snapshot: Dictionary) -> Dictionary:
	return {
		"selected_tile": snapshot.get("selected_tile", {}).duplicate(true),
		"primary_action_id": String(snapshot.get("primary_action_id", "")),
		"primary_action": snapshot.get("primary_action", {}).duplicate(true),
		"primary_action_button_text": String(snapshot.get("primary_action_button_text", "")),
		"primary_action_button_disabled": bool(snapshot.get("primary_action_button_disabled", true)),
		"primary_action_button_tooltip_text": String(snapshot.get("primary_action_button_tooltip_text", "")),
		"selected_route_decision": snapshot.get("selected_route_decision", {}).duplicate(true),
		"map_cue_text": String(snapshot.get("map_cue_text", "")),
		"map_cue_tooltip_text": String(snapshot.get("map_cue_tooltip_text", "")),
		"rendered_readiness": _rendered_readiness_payload(snapshot),
	}

func _rendered_event_payload(snapshot: Dictionary) -> Dictionary:
	return {
		"visible_text": String(snapshot.get("event_visible_text", "")),
		"tooltip_text": String(snapshot.get("event_tooltip_text", "")),
	}

func _rendered_readiness_payload(snapshot: Dictionary) -> Dictionary:
	return {
		"objective_brief_tooltip_text": String(snapshot.get("objective_brief_tooltip_text", "")),
		"event": _rendered_event_payload(snapshot),
		"end_turn_button_text": String(snapshot.get("end_turn_button_text", "")),
		"end_turn_tooltip_text": String(snapshot.get("end_turn_tooltip_text", "")),
		"command_drawer_button_text": String(snapshot.get("command_drawer_button_text", "")),
		"command_drawer_tooltip_text": String(snapshot.get("command_drawer_tooltip_text", "")),
		"frontier_drawer_button_text": String(snapshot.get("frontier_drawer_button_text", "")),
		"frontier_drawer_tooltip_text": String(snapshot.get("frontier_drawer_tooltip_text", "")),
	}

func _movement_mirror_checks(session, expected: Dictionary) -> Dictionary:
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	var active_hero_id := String(session.overworld.get("active_hero_id", ""))
	var matching_active_heroes := 0
	var active_player_movement: Dictionary = {}
	for row in session.overworld.get("player_heroes", []):
		if row is Dictionary and String(row.get("id", "")) == active_hero_id:
			matching_active_heroes += 1
			active_player_movement = row.get("movement", {}).duplicate(true) if row.get("movement", {}) is Dictionary else {}
	return {
		"top_level_movement_exact": session.overworld.get("movement", {}) == expected,
		"hero_movement_exact": hero.get("movement", {}) == expected,
		"one_matching_active_player_hero": matching_active_heroes == 1,
		"active_player_hero_movement_exact": active_player_movement == expected,
	}

func _assert_town_entry_handoff_cue(shell: Node) -> bool:
	var session = SessionState.ensure_active_session()
	_set_active_hero_position(session, Vector2i(0, 2))
	var movement: Dictionary = session.overworld.get("movement", {})
	movement["current"] = int(movement.get("max", movement.get("current", 0)))
	session.overworld["movement"] = movement
	OverworldRules.refresh_fog_of_war(session)
	shell.call("validation_select_tile", 0, 2)
	shell.call("_refresh")

	var snapshot: Dictionary = shell.call("validation_snapshot")
	var handoff: Dictionary = snapshot.get("town_entry_handoff", {})
	var readiness: Dictionary = snapshot.get("field_readiness", {})
	var readiness_handoff: Dictionary = readiness.get("town_entry_handoff", {})
	var primary_action: Dictionary = snapshot.get("primary_action", {})
	var action_handoff: Dictionary = primary_action.get("town_entry_handoff", {}) if primary_action.get("town_entry_handoff", {}) is Dictionary else {}
	var consequence_checks := {
		"primary_action_id_exact": String(snapshot.get("primary_action_id", "")) == "visit_town",
		"primary_payload_id_exact": String(primary_action.get("id", "")) == "visit_town",
		"primary_label_exact": String(primary_action.get("label", "")) == "Visit Town",
		"button_text_exact": String(snapshot.get("primary_action_button_text", "")) == "Visit Town [Enter]",
		"button_enabled_exact": not bool(snapshot.get("primary_action_button_disabled", true)),
		"handoff_nonempty": not handoff.is_empty(),
		"readiness_nonempty": not readiness.is_empty(),
		"readiness_handoff_exact": readiness_handoff == handoff,
		"action_handoff_exact": action_handoff == handoff,
		"town_name_exact": String(handoff.get("town_name", "")) == "Riverwatch Hold",
		"field_position_exact": String(handoff.get("field_position", "")) == "0,2",
		"movement_line_exact": String(handoff.get("movement_line", "")) == "Move 14/14",
		"return_order_exact": String(handoff.get("return_order", "")) == "Leave",
		"selected_tile_exact": snapshot.get("selected_tile", {}) == {"x": 0, "y": 2},
		"hero_position_exact": session.overworld.get("hero_position", {}) == {"x": 0, "y": 2},
	}
	if not _checks_exact(consequence_checks):
		_fail("Town entry handoff smoke: exact Visit Town consequence authority changed.", consequence_checks)
		return false
	var joined := "\n".join([
		String(snapshot.get("primary_action_button_text", "")),
		String(snapshot.get("primary_action_button_tooltip_text", "")),
		String(snapshot.get("selected_tile_rail_text", "")),
		String(snapshot.get("town_entry_handoff_visible_text", "")),
		String(snapshot.get("town_entry_handoff_tooltip_text", "")),
		String(handoff.get("visible_text", "")),
		String(handoff.get("tooltip_text", "")),
		String(handoff.get("summary_text", "")),
		String(readiness.get("visible_text", "")),
		String(readiness.get("tooltip_text", "")),
		String(readiness_handoff.get("visible_text", "")),
		String(readiness_handoff.get("tooltip_text", "")),
		String(primary_action.get("summary", "")),
		String(action_handoff.get("tooltip_text", "")),
	])
	if String(snapshot.get("primary_action_id", "")) != "visit_town":
		_fail("Town entry handoff smoke: selected town should expose Visit Town.", snapshot)
		return false
	if not _assert_text_contains_all(
		"Town entry handoff smoke",
		joined,
		[
			"Visit Town [Enter]",
			"Town handoff:",
			"Town Entry Handoff",
			"Enter: Visit Town opens Riverwatch Hold management.",
			"Field position: active hero remains at 0,2.",
			"Movement: Move",
			"Return: Leave returns to the overworld; the day does not advance.",
			"State change:",
			"Leave returns to the field at 0,2",
			"Primary Order Check",
			"Enter/Space enters the town without ending the day",
		]
	):
		return false
	if not _assert_no_ai_score_leak("Town entry handoff smoke", joined):
		return false
	return true

func _assert_overworld_spell_check_cue(shell: Node) -> bool:
	var session = SessionState.ensure_active_session()
	var movement: Dictionary = session.overworld.get("movement", {})
	movement["current"] = int(movement.get("max", movement.get("current", 0)))
	session.overworld["movement"] = movement
	shell.call("_refresh")

	var full_snapshot: Dictionary = shell.call("validation_snapshot")
	var full_spell_action := _action_by_id(full_snapshot.get("spell_actions", []), "cast_spell:spell_waystride")
	var full_text := _spell_surface_text(full_snapshot, full_spell_action)
	if full_spell_action.is_empty() or not bool(full_spell_action.get("disabled", false)):
		_fail("Overworld spell check smoke: full movement should block Waystride.", full_snapshot)
		return false
	if not _assert_text_contains_all(
		"Overworld spell blocked check smoke",
		full_text,
		[
			"Spell check:",
			"Spell Check",
			"Blocked x0/1",
			"Waystride",
			"Mana",
			"Movement",
			"Best spell:",
			"Next practical action:",
			"Spell Cast Check",
			"State change: casting spends mana",
		]
	):
		return false
	if not _assert_no_ai_score_leak("Overworld spell blocked check smoke", full_text):
		return false

	var start := OverworldRules.hero_position(session)
	var safe_step: Vector2i = shell.call("_first_validation_safe_step", start)
	if safe_step.x < 0:
		_fail("Overworld spell check smoke: could not find a safe step.", full_snapshot)
		return false
	shell.call("validation_select_tile", safe_step.x, safe_step.y)
	var move_result: Dictionary = shell.call("validation_perform_primary_action")
	await get_tree().process_frame
	if not bool(move_result.get("ok", false)):
		_fail("Overworld spell check smoke: movement setup failed.", move_result)
		return false
	var ready_snapshot: Dictionary = shell.call("validation_snapshot")
	var ready_spell_action := _action_by_id(ready_snapshot.get("spell_actions", []), "cast_spell:spell_waystride")
	var ready_text := _spell_surface_text(ready_snapshot, ready_spell_action)
	if ready_spell_action.is_empty() or bool(ready_spell_action.get("disabled", false)):
		_fail("Overworld spell check smoke: spent movement should ready Waystride.", ready_snapshot)
		return false
	if not _assert_text_contains_all(
		"Overworld spell ready check smoke",
		ready_text,
		[
			"Spell check:",
			"Spell Check",
			"Ready x1/1",
			"Waystride",
			"Mana",
			"Movement",
			"Best spell:",
			"Next practical action:",
			"Spell Cast Check",
			"Cast now",
			"State change: casting spends mana",
		]
	):
		return false
	if not _assert_no_ai_score_leak("Overworld spell ready check smoke", ready_text):
		return false
	return true

func _spell_surface_text(snapshot: Dictionary, spell_action: Dictionary) -> String:
	var action_surfaces := []
	for surface in (snapshot.get("spell_action_surfaces", []) if snapshot.get("spell_action_surfaces", []) is Array else []):
		if surface is Dictionary:
			action_surfaces.append("%s\n%s" % [String(surface.get("text", "")), String(surface.get("tooltip", ""))])
	return "\n".join([
		String(snapshot.get("spell_check_visible_text", "")),
		String(snapshot.get("spell_check_tooltip_text", "")),
		String(spell_action.get("spell_check_tooltip_text", "")),
		"\n".join(action_surfaces),
	])

func _action_by_id(actions: Variant, action_id: String) -> Dictionary:
	if not (actions is Array):
		return {}
	for action in actions:
		if action is Dictionary and String(action.get("id", "")) == action_id:
			return action
	return {}

func _set_active_hero_position(session, tile: Vector2i) -> void:
	session.overworld["hero_position"] = {"x": tile.x, "y": tile.y}
	var hero: Dictionary = session.overworld.get("hero", {})
	hero["position"] = {"x": tile.x, "y": tile.y}
	session.overworld["hero"] = hero
	var active_hero_id := String(session.overworld.get("active_hero_id", hero.get("id", "")))
	var heroes: Array = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		if not (heroes[index] is Dictionary):
			continue
		var entry: Dictionary = heroes[index]
		if String(entry.get("id", "")) == active_hero_id:
			entry["position"] = {"x": tile.x, "y": tile.y}
			heroes[index] = entry
			break
	session.overworld["player_heroes"] = heroes

func _assert_text_contains_all(label: String, text: String, needles: Array) -> bool:
	for needle in needles:
		if text.find(String(needle)) < 0:
			_fail("%s missing '%s'." % [label, String(needle)], {"text": text})
			return false
	return true

func _assert_no_ai_score_leak(label: String, text: String) -> bool:
	for token in ["base_value", "persistent_income_value", "final_priority", "assignment_penalty", "route_pressure_value", "denial_value", "debug_reason", "final_score", "income_value", "growth_value", "pressure_value", "category_bonus", "raid_score"]:
		if text.find(token) >= 0:
			_fail("%s leaked AI score/debug token %s." % [label, token], {"text": text})
			return false
	return true

func _route_authority(shell: Node, session) -> Dictionary:
	var snapshot: Dictionary = shell.call("validation_snapshot")
	return {
		"session": session.to_dict().duplicate(true),
		"files": _capture_file_states(_authority_paths()),
		"save_cache": SaveService.validation_summary_cache_snapshot(),
		"settings": _canonical_settings_transaction(SettingsService.validation_settings_transaction_snapshot()),
		"routes": {
			"safe_quit": AppRouter.validation_safe_quit_snapshot(),
			"safe_close": AppRouter.validation_safe_close_guard_snapshot(),
			"active_play_return": AppRouter.validation_active_play_return_snapshot(),
			"battle_entry": AppRouter.validation_battle_entry_snapshot(),
			"battle_resolution": AppRouter.validation_battle_resolution_checkpoint_snapshot(),
			"scenario_outcome": AppRouter.validation_scenario_outcome_route_snapshot(),
		},
		"shell_counts": {
			"battle_entry_request_count": int(snapshot.get("battle_entry_request_count", 0)),
			"battle_entry_success_count": int(snapshot.get("battle_entry_success_count", 0)),
			"battle_entry_failure_count": int(snapshot.get("battle_entry_failure_count", 0)),
			"manual_save_attempt_count": int(snapshot.get("manual_save_attempt_count", 0)),
			"manual_save_success_count": int(snapshot.get("manual_save_success_count", 0)),
			"manual_save_failure_count": int(snapshot.get("manual_save_failure_count", 0)),
			"return_to_menu_request_count": int(snapshot.get("return_to_menu_request_count", 0)),
		},
		"session_ref": session,
		"shell_session_ref": shell.get("_session"),
		"active_session_ref": SessionState.active_session,
		"session_id": String(session.session_id),
		"game_state": String(session.game_state),
		"scenario_status": String(session.scenario_status),
	}

func _route_authority_checks(before: Dictionary, after: Dictionary, session) -> Dictionary:
	return {
		"session_payload_exact": before.get("session", {}) == after.get("session", {}),
		"files_exact": before.get("files", {}) == after.get("files", {}),
		"save_cache_exact": before.get("save_cache", {}) == after.get("save_cache", {}),
		"settings_exact": before.get("settings", {}) == after.get("settings", {}),
		"routes_exact": before.get("routes", {}) == after.get("routes", {}),
		"shell_counts_exact": before.get("shell_counts", {}) == after.get("shell_counts", {}),
		"session_id_exact": String(before.get("session_id", "")) == String(after.get("session_id", "")),
		"game_state_exact": String(before.get("game_state", "")) == String(after.get("game_state", "")),
		"scenario_status_exact": String(before.get("scenario_status", "")) == String(after.get("scenario_status", "")),
		"before_session_identity": is_same(before.get("session_ref"), session),
		"after_session_identity": is_same(after.get("session_ref"), session),
		"session_ref_exact": is_same(before.get("session_ref"), after.get("session_ref")),
		"shell_session_ref_exact": is_same(before.get("shell_session_ref"), after.get("shell_session_ref")) and is_same(after.get("shell_session_ref"), session),
		"active_session_ref_exact": is_same(before.get("active_session_ref"), after.get("active_session_ref")) and is_same(after.get("active_session_ref"), session),
	}

func _canonical_settings_transaction(transaction: Dictionary) -> Dictionary:
	var canonical: Dictionary = transaction.duplicate(true)
	var canonical_input_map := {}
	var input_map: Dictionary = transaction.get("input_map", {}) if transaction.get("input_map", {}) is Dictionary else {}
	for action_value in input_map.keys():
		var action := String(action_value)
		var action_state: Dictionary = input_map.get(action_value, {}) if input_map.get(action_value, {}) is Dictionary else {}
		var canonical_events: Array = []
		var events: Array = action_state.get("events", []) if action_state.get("events", []) is Array else []
		for event_value in events:
			if event_value is InputEvent:
				canonical_events.append(_canonical_stored_input_event(event_value as InputEvent))
			else:
				canonical_events.append({"class": "", "as_text": var_to_str(event_value), "stored_properties": []})
		canonical_input_map[action] = {
			"action": action,
			"exists": bool(action_state.get("exists", false)),
			"deadzone": float(action_state.get("deadzone", 0.5)),
			"events": canonical_events,
		}
	canonical["input_map"] = canonical_input_map
	return canonical

func _canonical_stored_input_event(event: InputEvent) -> Dictionary:
	var stored_properties: Array = []
	for property_value in event.get_property_list():
		if not (property_value is Dictionary):
			continue
		var property: Dictionary = property_value
		var property_name := String(property.get("name", ""))
		var property_usage := int(property.get("usage", 0))
		if property_name == "script" or (property_usage & PROPERTY_USAGE_STORAGE) == 0:
			continue
		stored_properties.append({"name": property_name, "value": var_to_str(event.get(property_name))})
	return {
		"class": event.get_class(),
		"as_text": event.as_text(),
		"stored_properties": stored_properties,
	}

func _authority_paths() -> Array:
	var autosave_path := "%s/%s" % [SaveService.SAVE_DIR, SaveService.AUTOSAVE_FILE]
	var progression_path := "%s/%s" % [SaveService.SAVE_DIR, SaveService.PROGRESSION_FILE]
	var paths: Array = [
		autosave_path,
		progression_path,
		SettingsService.SETTINGS_FILE,
		SettingsService.SETTINGS_CANDIDATE_FILE,
		SettingsService.SETTINGS_BACKUP_FILE,
	]
	for durable_path in [autosave_path, progression_path]:
		var artifacts: Dictionary = SaveService.validation_transaction_artifact_paths(durable_path)
		paths.append(String(artifacts.get("candidate", "%s.candidate" % durable_path)))
		paths.append(String(artifacts.get("backup", "%s.backup" % durable_path)))
	for slot in SaveService.MANUAL_SLOT_IDS:
		var slot_path := "%s/%s%d.json" % [SaveService.SAVE_DIR, SaveService.SAVE_PREFIX, int(slot)]
		paths.append(slot_path)
		var slot_artifacts: Dictionary = SaveService.validation_transaction_artifact_paths(slot_path)
		paths.append(String(slot_artifacts.get("candidate", "%s.candidate" % slot_path)))
		paths.append(String(slot_artifacts.get("backup", "%s.backup" % slot_path)))
	return paths

func _capture_file_states(paths: Array) -> Dictionary:
	var states := {}
	for path_value in paths:
		var path := String(path_value)
		states[path] = {
			"exists": FileAccess.file_exists(path),
			"bytes": FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray(),
		}
	return states

func _restore_file_states(states: Dictionary) -> void:
	for path_value in states.keys():
		var path := String(path_value)
		var state: Dictionary = states[path_value]
		if not bool(state.get("exists", false)):
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			continue
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_buffer(state.get("bytes", PackedByteArray()))
			file.close()

func _checks_exact(checks: Dictionary) -> bool:
	for value in checks.values():
		if not bool(value):
			return false
	return true

func _discard_host(host: Control) -> void:
	if host != null and is_instance_valid(host):
		host.queue_free()
	await _settle()

func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

func _cleanup() -> void:
	_restore_file_states(_original_files)
	SaveService._slot_summary_cache = _original_summary_cache.duplicate(true)
	SessionState.active_session = _original_session
	if _original_window_size != Vector2i.ZERO:
		get_window().size = _original_window_size

func _fail(message: String, payload: Dictionary) -> void:
	_cleanup()
	push_error("%s payload=%s" % [message, payload])
	get_tree().quit(1)
