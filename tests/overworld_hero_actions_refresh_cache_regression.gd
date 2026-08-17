extends Node

const REPORT_ID := "OVERWORLD_HERO_ACTIONS_REFRESH_CACHE_REGRESSION"
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var session = _session_with_map(12, 3)
	var opened := await _open_shell(session)
	var shell: Node = opened.get("shell", null)
	session = opened.get("session", session)
	_prepare_shell_state(shell, session, Vector2i(0, 1), 10)
	var reserve_id := _ensure_reserve_hero(session)
	shell.call("_refresh")
	var forecast_control := _assert_forecast_bundle_core_parity(session)
	if forecast_control.is_empty():
		return
	var objective_header_control := _assert_objective_header_surface_parity(session)
	if objective_header_control.is_empty():
		return
	if not _assert_forecast_bundle_surface_parity(shell, session, "current_tile"):
		return
	if not _assert_drawer_readiness_preload_parity(shell, "current_tile"):
		return
	var refresh_session_before: Dictionary = session.to_dict()
	var refresh_authority_before: Dictionary = _refresh_authority(shell.call("validation_snapshot"))
	shell.set("_debug_command_in_progress", true)
	shell.call("validation_reset_profile", true)
	var refresh_started := Time.get_ticks_usec()
	shell.call("_refresh")
	var full_refresh_usec := Time.get_ticks_usec() - refresh_started
	var full_refresh_profile: Dictionary = shell.call("validation_profile_snapshot")
	var refresh_authority_after: Dictionary = _refresh_authority(shell.call("validation_snapshot"))
	if int(full_refresh_profile.get("field_readiness_surface_calls", 0)) != 2 or int(full_refresh_profile.get("field_readiness_surface_base_event_calls", 0)) != 1:
		_fail("Full refresh did not materialize one status readiness plus one event-feed readiness surface.", full_refresh_profile)
		return
	if int(full_refresh_profile.get("field_readiness_context_builds", 0)) != 1 \
			or int(full_refresh_profile.get("field_readiness_context_reuses", 0)) != 2 \
			or int(full_refresh_profile.get("field_readiness_context_materializations", 0)) != 2:
		_fail("Full refresh did not build one readiness context and reuse it for both exact surfaces.", full_refresh_profile)
		return
	if int(full_refresh_profile.get("drawer_handoff_preloaded_readiness_reuses", 0)) != 1:
		_fail("Full refresh did not reuse the current readiness payload for drawer handoff synchronization.", full_refresh_profile)
		return
	if int(full_refresh_profile.get("end_turn_forecast_bundle_builds", 0)) != 1 or int(full_refresh_profile.get("end_turn_forecast_bundle_reuses", 0)) != 4:
		_fail("Full refresh did not build one end-turn forecast bundle and reuse it across the four remaining consumers.", full_refresh_profile)
		return
	if int(full_refresh_profile.get("objective_stakes_surface_builds", 0)) != 1 \
			or int(full_refresh_profile.get("objective_stakes_surface_reuses", 0)) != 2 \
			or int(full_refresh_profile.get("objective_stakes_surface_materializations", 0)) != 2:
		_fail("Full refresh did not build one objective-stakes surface and reuse it for both exact header outputs.", full_refresh_profile)
		return
	if session.to_dict() != refresh_session_before or refresh_authority_after != refresh_authority_before:
		_fail("Readiness reuse changed session or whole refresh surface authority.", {
			"before": refresh_authority_before,
			"after": refresh_authority_after,
		})
		return
	var event_context_control := _assert_event_readiness_context_parity(shell, session, "full_refresh")
	if event_context_control.is_empty():
		return
	shell.call("validation_reset_profile", false)
	var legacy_drawer_started := Time.get_ticks_usec()
	shell.call("_refresh_tooltip_context_drawer_surfaces")
	var legacy_drawer_extra_usec := Time.get_ticks_usec() - legacy_drawer_started
	var legacy_drawer_profile: Dictionary = shell.call("validation_profile_snapshot")
	var legacy_drawer_authority: Dictionary = _refresh_authority(shell.call("validation_snapshot"))
	if int(legacy_drawer_profile.get("field_readiness_surface_calls", 0)) != 1 or int(legacy_drawer_profile.get("field_readiness_surface_base_event_calls", 0)) != 0:
		_fail("Legacy default drawer control did not perform exactly one no-base readiness derivation.", legacy_drawer_profile)
		return
	if int(legacy_drawer_profile.get("drawer_handoff_preloaded_readiness_reuses", 0)) != 0:
		_fail("Legacy default drawer control unexpectedly used the preloaded readiness path.", legacy_drawer_profile)
		return
	if legacy_drawer_extra_usec * 5 < full_refresh_usec:
		_fail("Removed drawer readiness work was not at least 20 percent of the optimized full refresh.", {
			"legacy_drawer_extra_usec": legacy_drawer_extra_usec,
			"full_refresh_usec": full_refresh_usec,
		})
		return
	if session.to_dict() != refresh_session_before or legacy_drawer_authority != refresh_authority_after:
		_fail("Legacy default drawer control changed session or refresh surface authority.", {
			"candidate": refresh_authority_after,
			"legacy": legacy_drawer_authority,
		})
		return

	var initial_snapshot: Dictionary = shell.call("validation_snapshot")
	if _hero_action_count(initial_snapshot) < 2:
		_fail("Hero action setup did not expose an active and reserve commander.", initial_snapshot)
		return

	shell.call("validation_reset_profile", true)
	var target := Vector2i(8, 1)
	var selection: Dictionary = shell.call("validation_select_tile", target.x, target.y)
	var selection_profile: Dictionary = shell.call("validation_profile_snapshot")
	if not bool(selection.get("ok", false)):
		_fail("Route selection failed during hero action cache regression.", selection)
		return
	if int(selection_profile.get("hero_actions_cache_misses", 0)) != 0:
		_fail("Route-selection refresh rebuilt hero actions despite an unchanged hero command signature.", selection_profile)
		return
	if int(selection_profile.get("hero_actions_cache_hits", 0)) <= 0:
		_fail("Route-selection refresh did not reuse cached hero actions.", selection_profile)
		return
	if not _assert_drawer_readiness_preload_parity(shell, "selected_route"):
		return
	if not _assert_forecast_bundle_surface_parity(shell, session, "selected_route"):
		return

	shell.call("validation_reset_profile", true)
	var switch_result := OverworldRules.switch_active_hero(session, reserve_id)
	if not bool(switch_result.get("ok", false)):
		_fail("Active hero switch setup failed.", switch_result)
		return
	shell.call("_refresh")
	var switch_profile: Dictionary = shell.call("validation_profile_snapshot")
	var switch_snapshot: Dictionary = shell.call("validation_snapshot")
	if int(switch_profile.get("hero_actions_cache_misses", 0)) <= 0:
		_fail("Active hero change did not invalidate cached hero actions.", switch_profile)
		return
	if not _hero_action_disabled_for(switch_snapshot, reserve_id):
		_fail("Active hero disabled state did not update after cache invalidation.", switch_snapshot)
		return

	shell.call("validation_reset_profile", true)
	var new_roster_id := _append_roster_hero(session)
	shell.call("_refresh")
	var roster_profile: Dictionary = shell.call("validation_profile_snapshot")
	var roster_snapshot: Dictionary = shell.call("validation_snapshot")
	if int(roster_profile.get("hero_actions_cache_misses", 0)) <= 0:
		_fail("Roster membership change did not invalidate cached hero actions.", roster_profile)
		return
	if not _hero_action_present(roster_snapshot, new_roster_id):
		_fail("Roster membership/order change did not reach hero action surfaces.", roster_snapshot)
		return

	shell.call("validation_reset_profile", true)
	_set_active_pending_specialty_choices(session, [
		{"level": 2, "options": ["spellwright", "drillmaster", "borderwarden"]},
	])
	shell.call("_refresh")
	var specialty_profile: Dictionary = shell.call("validation_profile_snapshot")
	var specialty_snapshot: Dictionary = shell.call("validation_snapshot")
	if int(specialty_profile.get("hero_actions_cache_misses", 0)) <= 0:
		_fail("Nested pending specialty choices did not invalidate cached hero actions.", specialty_profile)
		return
	if not _action_present(specialty_snapshot.get("specialty_actions", []), "choose_specialty:spellwright"):
		_fail("Nested pending specialty choices did not reach the live specialty action surface.", specialty_snapshot)
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"selection_cache_hits": int(selection_profile.get("hero_actions_cache_hits", 0)),
		"selection_cache_misses": int(selection_profile.get("hero_actions_cache_misses", 0)),
		"active_switch_cache_misses": int(switch_profile.get("hero_actions_cache_misses", 0)),
		"roster_cache_misses": int(roster_profile.get("hero_actions_cache_misses", 0)),
		"nested_specialty_cache_misses": int(specialty_profile.get("hero_actions_cache_misses", 0)),
		"hero_action_count_after_roster": _hero_action_count(roster_snapshot),
		"full_refresh_usec": full_refresh_usec,
		"legacy_drawer_extra_usec": legacy_drawer_extra_usec,
		"legacy_extra_to_full_refresh_ratio": float(legacy_drawer_extra_usec) / float(maxi(full_refresh_usec, 1)),
		"field_readiness_surface_calls": int(full_refresh_profile.get("field_readiness_surface_calls", 0)),
		"field_readiness_surface_base_event_calls": int(full_refresh_profile.get("field_readiness_surface_base_event_calls", 0)),
		"field_readiness_context_builds": int(full_refresh_profile.get("field_readiness_context_builds", 0)),
		"field_readiness_context_reuses": int(full_refresh_profile.get("field_readiness_context_reuses", 0)),
		"field_readiness_context_materializations": int(full_refresh_profile.get("field_readiness_context_materializations", 0)),
		"drawer_handoff_preloaded_readiness_reuses": int(full_refresh_profile.get("drawer_handoff_preloaded_readiness_reuses", 0)),
		"end_turn_forecast_bundle_builds": int(full_refresh_profile.get("end_turn_forecast_bundle_builds", 0)),
		"end_turn_forecast_bundle_reuses": int(full_refresh_profile.get("end_turn_forecast_bundle_reuses", 0)),
		"objective_stakes_surface_builds": int(full_refresh_profile.get("objective_stakes_surface_builds", 0)),
		"objective_stakes_surface_reuses": int(full_refresh_profile.get("objective_stakes_surface_reuses", 0)),
		"objective_stakes_surface_materializations": int(full_refresh_profile.get("objective_stakes_surface_materializations", 0)),
		"objective_header_bundle_usec": int(objective_header_control.get("bundle_usec", 0)),
		"legacy_objective_header_usec": int(objective_header_control.get("legacy_usec", 0)),
		"legacy_objective_to_bundle_ratio": float(objective_header_control.get("legacy_usec", 0)) / float(maxi(int(objective_header_control.get("bundle_usec", 0)), 1)),
		"objective_header_surface_parity": true,
		"forecast_bundle_usec": int(forecast_control.get("bundle_usec", 0)),
		"legacy_forecast_usec": int(forecast_control.get("legacy_usec", 0)),
		"legacy_to_bundle_ratio": float(forecast_control.get("legacy_usec", 0)) / float(maxi(int(forecast_control.get("bundle_usec", 0)), 1)),
		"forecast_bundle_core_parity": true,
		"forecast_bundle_surface_parity": true,
		"drawer_readiness_preload_parity": true,
		"event_readiness_context_parity": true,
		"legacy_event_readiness_usec": int(event_context_control.get("legacy_usec", 0)),
		"shared_event_readiness_usec": int(event_context_control.get("shared_usec", 0)),
		"legacy_event_to_shared_ratio": float(event_context_control.get("legacy_usec", 0)) / float(maxi(int(event_context_control.get("shared_usec", 0)), 1)),
		"refresh_authority_exact": true,
		"legacy_drawer_authority_exact": true,
	})])
	shell.queue_free()
	get_tree().quit(0)

func _open_shell(session) -> Dictionary:
	var active_session = SessionState.set_active_session(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	var shell_session = shell.get("_session")
	if shell_session != null:
		active_session = shell_session
	return {"shell": shell, "session": active_session}

func _prepare_shell_state(shell: Node, session, position: Vector2i, movement_points: int) -> void:
	_set_active_hero_position(session, position)
	_set_active_hero_movement(session, movement_points)
	session.overworld["fog"] = {}
	OverworldRules.refresh_fog_of_war(session)
	shell.call("_set_selected_tile", position)
	shell.call("_refresh")

func _session_with_map(width: int, height: int):
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var rows := []
	for _y in range(height):
		var row := []
		for _x in range(width):
			row.append("grass")
		rows.append(row)
	session.overworld["map"] = rows
	session.overworld["map_size"] = {"width": width, "height": height, "x": width, "y": height}
	session.overworld["terrain_layers"] = {}
	session.overworld["towns"] = [
		{
			"placement_id": "riverwatch_hold",
			"town_id": "town_riverwatch",
			"x": 0,
			"y": 0,
			"owner": "player",
		}
	]
	session.overworld["resource_nodes"] = []
	session.overworld["artifact_nodes"] = []
	session.overworld["encounters"] = []
	session.overworld["resolved_encounters"] = []
	OverworldRules.refresh_fog_of_war(session)
	return session

func _ensure_reserve_hero(session) -> String:
	OverworldRules.normalize_overworld_state(session)
	var active_id := String(session.overworld.get("active_hero_id", ""))
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for hero_value in heroes:
		if hero_value is Dictionary and String(hero_value.get("id", "")) != active_id:
			return String(hero_value.get("id", ""))
	var reserve_id := "hero_caelen" if active_id != "hero_caelen" else "hero_mira"
	heroes.append(_reserve_hero_state(reserve_id, Vector2i(1, 1), 7))
	session.overworld["player_heroes"] = heroes
	OverworldRules.normalize_overworld_state(session)
	return reserve_id

func _append_roster_hero(session) -> String:
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	var used_ids := {}
	for hero_value in heroes:
		if hero_value is Dictionary:
			used_ids[String(hero_value.get("id", ""))] = true
	var candidate_ids := ["hero_mira", "hero_seren", "hero_torren"]
	var selected_id := ""
	for candidate_id in candidate_ids:
		if not used_ids.has(candidate_id):
			selected_id = candidate_id
			break
	if selected_id == "":
		selected_id = "hero_varis"
	heroes.append(_reserve_hero_state(selected_id, Vector2i(2, 1), 6))
	session.overworld["player_heroes"] = heroes
	OverworldRules.normalize_overworld_state(session)
	return selected_id

func _reserve_hero_state(hero_id: String, position: Vector2i, movement_points: int) -> Dictionary:
	var template := ContentService.get_hero(hero_id)
	return {
		"id": hero_id,
		"name": String(template.get("name", hero_id)),
		"faction_id": String(template.get("faction_id", "")),
		"archetype": String(template.get("archetype", "")),
		"roster_summary": String(template.get("roster_summary", "")),
		"is_primary": false,
		"position": {"x": position.x, "y": position.y},
		"movement": {"current": movement_points, "max": movement_points},
		"base_movement": movement_points,
		"level": 1,
		"experience": 0,
		"specialties": [],
		"army": {"id": "%s_army" % hero_id, "name": "Reserve Army", "stacks": []},
		"command": template.get("command", {}).duplicate(true) if template.get("command", {}) is Dictionary else {},
	}

func _set_active_hero_position(session, tile: Vector2i) -> void:
	var position := {"x": tile.x, "y": tile.y}
	session.overworld["hero_position"] = position.duplicate(true)
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	hero["position"] = position.duplicate(true)
	session.overworld["hero"] = hero
	var active_hero_id := String(session.overworld.get("active_hero_id", hero.get("id", "")))
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for index in range(heroes.size()):
		if not (heroes[index] is Dictionary):
			continue
		var entry: Dictionary = heroes[index]
		if String(entry.get("id", "")) == active_hero_id:
			entry["position"] = position.duplicate(true)
			heroes[index] = entry
			break
	session.overworld["player_heroes"] = heroes

func _set_active_hero_movement(session, movement_points: int) -> void:
	var movement := {"current": movement_points, "max": movement_points}
	session.overworld["movement"] = movement.duplicate(true)
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	hero["base_movement"] = movement_points
	hero["level"] = 1
	hero["experience"] = 0
	hero["specialties"] = []
	hero["movement"] = movement.duplicate(true)
	session.overworld["hero"] = hero
	var active_hero_id := String(session.overworld.get("active_hero_id", hero.get("id", "")))
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for index in range(heroes.size()):
		if not (heroes[index] is Dictionary):
			continue
		var entry: Dictionary = heroes[index]
		if String(entry.get("id", "")) == active_hero_id:
			entry["base_movement"] = movement_points
			entry["level"] = 1
			entry["experience"] = 0
			entry["specialties"] = []
			entry["movement"] = movement.duplicate(true)
			heroes[index] = entry
			break
	session.overworld["player_heroes"] = heroes

func _set_active_pending_specialty_choices(session, choices: Array) -> void:
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	hero["level"] = 2
	hero["pending_specialty_choices"] = choices.duplicate(true)
	session.overworld["hero"] = hero
	var active_hero_id := String(session.overworld.get("active_hero_id", hero.get("id", "")))
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for index in range(heroes.size()):
		if not (heroes[index] is Dictionary):
			continue
		var entry: Dictionary = heroes[index]
		if String(entry.get("id", "")) == active_hero_id:
			entry["level"] = 2
			entry["pending_specialty_choices"] = choices.duplicate(true)
			heroes[index] = entry
			break
	session.overworld["player_heroes"] = heroes

func _hero_action_count(snapshot: Dictionary) -> int:
	var surfaces: Array = snapshot.get("hero_action_surfaces", []) if snapshot.get("hero_action_surfaces", []) is Array else []
	return surfaces.size()

func _hero_action_present(snapshot: Dictionary, hero_id: String) -> bool:
	var hero_name := String(ContentService.get_hero(hero_id).get("name", hero_id))
	for surface in _hero_action_surfaces(snapshot):
		if String(surface.get("text", "")).contains(hero_name):
			return true
	return false

func _hero_action_disabled_for(snapshot: Dictionary, hero_id: String) -> bool:
	var hero_name := String(ContentService.get_hero(hero_id).get("name", hero_id))
	for surface in _hero_action_surfaces(snapshot):
		if String(surface.get("text", "")).contains(hero_name):
			return bool(surface.get("disabled", false))
	return false

func _action_present(actions: Variant, action_id: String) -> bool:
	if not (actions is Array):
		return false
	for action_value in actions:
		if action_value is Dictionary and String(action_value.get("id", "")) == action_id:
			return true
	return false

func _hero_action_surfaces(snapshot: Dictionary) -> Array:
	return snapshot.get("hero_action_surfaces", []) if snapshot.get("hero_action_surfaces", []) is Array else []

func _assert_forecast_bundle_core_parity(session) -> Dictionary:
	var ordinary := SessionStateStoreScript.SessionData.new()
	ordinary.from_dict(session.to_dict())
	var pressured := SessionStateStoreScript.SessionData.new()
	pressured.from_dict(session.to_dict())
	var pressured_towns: Array = pressured.overworld.get("towns", []) if pressured.overworld.get("towns", []) is Array else []
	for index in range(pressured_towns.size()):
		if not (pressured_towns[index] is Dictionary) or String(pressured_towns[index].get("owner", "neutral")) != "player":
			continue
		var pressured_town: Dictionary = pressured_towns[index]
		pressured_town["recovery"] = {"pressure": 4, "last_event_day": pressured.day}
		pressured_towns[index] = pressured_town
		break
	pressured.overworld["towns"] = pressured_towns
	var day_transition := SessionStateStoreScript.SessionData.new()
	day_transition.from_dict(session.to_dict())
	day_transition.day = 7
	var transition_movement: Dictionary = day_transition.overworld.get("movement", {}) if day_transition.overworld.get("movement", {}) is Dictionary else {}
	transition_movement["current"] = 0
	day_transition.overworld["movement"] = transition_movement
	for row in [
		{"id": "ordinary", "session": ordinary},
		{"id": "pressured", "session": pressured},
		{"id": "day_transition", "session": day_transition},
	]:
		var probe = row.get("session")
		OverworldRules.normalize_overworld_state(probe)
		var authority_before: Dictionary = probe.to_dict()
		var expected := {
			"forecast": OverworldRules.describe_end_turn_forecast(probe),
			"forecast_compact": OverworldRules.describe_end_turn_forecast_compact(probe),
		}
		var bundled: Dictionary = OverworldRules.describe_end_turn_forecast_surfaces(probe)
		if bundled != expected or bundled.keys() != ["forecast", "forecast_compact"] or probe.to_dict() != authority_before:
			_fail("Combined end-turn forecast diverged from independent production wrappers for %s." % String(row.get("id", "")), {
				"expected": expected,
				"bundled": bundled,
			})
			return {}
		bundled["forecast"] = "mutated detached control"
		bundled["forecast_compact"] = "mutated detached control"
		if probe.to_dict() != authority_before or OverworldRules.describe_end_turn_forecast_surfaces(probe) != expected:
			_fail("Combined end-turn forecast was not detached or failed to rebuild from live state for %s." % String(row.get("id", "")))
			return {}
	var expected_full := OverworldRules.describe_end_turn_forecast(session)
	var expected_compact := OverworldRules.describe_end_turn_forecast_compact(session)
	var bundle_started := Time.get_ticks_usec()
	var timed_bundle: Dictionary = OverworldRules.describe_end_turn_forecast_surfaces(session)
	var bundle_usec := Time.get_ticks_usec() - bundle_started
	var legacy_started := Time.get_ticks_usec()
	for _index in range(3):
		if OverworldRules.describe_end_turn_forecast(session) != expected_full:
			_fail("Legacy full forecast timing control changed output.")
			return {}
	for _index in range(5):
		if OverworldRules.describe_end_turn_forecast_compact(session) != expected_compact:
			_fail("Legacy compact forecast timing control changed output.")
			return {}
	var legacy_usec := Time.get_ticks_usec() - legacy_started
	if timed_bundle != {"forecast": expected_full, "forecast_compact": expected_compact} or legacy_usec < bundle_usec * 2:
		_fail("Combined forecast did not preserve exact output or remove at least half of the legacy three-full/five-compact work.", {
			"bundle_usec": bundle_usec,
			"legacy_usec": legacy_usec,
			"bundle": timed_bundle,
		})
		return {}
	return {"bundle_usec": bundle_usec, "legacy_usec": legacy_usec}

func _assert_objective_header_surface_parity(session) -> Dictionary:
	var ordinary := SessionStateStoreScript.SessionData.new()
	ordinary.from_dict(session.to_dict())
	var pressured := SessionStateStoreScript.SessionData.new()
	pressured.from_dict(session.to_dict())
	var pressured_towns: Array = pressured.overworld.get("towns", []) if pressured.overworld.get("towns", []) is Array else []
	for index in range(pressured_towns.size()):
		if pressured_towns[index] is Dictionary and String(pressured_towns[index].get("owner", "neutral")) == "player":
			var town: Dictionary = pressured_towns[index]
			town["recovery"] = {"pressure": 4, "last_event_day": pressured.day}
			pressured_towns[index] = town
			break
	pressured.overworld["towns"] = pressured_towns
	var day_transition := SessionStateStoreScript.SessionData.new()
	day_transition.from_dict(session.to_dict())
	day_transition.day = 7
	var campaign := SessionStateStoreScript.SessionData.new()
	campaign.from_dict(session.to_dict())
	campaign.launch_mode = SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN
	var missing := SessionStateStoreScript.SessionData.new()
	missing.from_dict(session.to_dict())
	missing.scenario_id = ""
	for row in [
		{"id": "ordinary", "session": ordinary},
		{"id": "pressured", "session": pressured},
		{"id": "day_transition", "session": day_transition},
		{"id": "campaign", "session": campaign},
		{"id": "missing", "session": missing},
	]:
		var probe = row.get("session")
		OverworldRules.normalize_overworld_state(probe)
		var authority_before: Dictionary = probe.to_dict()
		var expected := {
			"objective_brief": OverworldRules.describe_objective_brief(probe),
			"objective_stakes": OverworldRules.describe_objective_stakes_board(probe),
		}
		var bundled: Dictionary = OverworldRules.describe_objective_header_surfaces(probe)
		if bundled != expected or bundled.keys() != ["objective_brief", "objective_stakes"] or probe.to_dict() != authority_before:
			_fail("Combined objective header surfaces diverged from independent production wrappers for %s." % String(row.get("id", "")), {
				"expected": expected,
				"bundled": bundled,
			})
			return {}
		bundled["objective_brief"] = "mutated detached objective brief"
		bundled["objective_stakes"] = "mutated detached objective stakes"
		if probe.to_dict() != authority_before or OverworldRules.describe_objective_header_surfaces(probe) != expected:
			_fail("Combined objective header surfaces were not detached or failed to rebuild for %s." % String(row.get("id", "")))
			return {}
	var raw_surface: Dictionary = OverworldRules._objective_stakes_surface(session)
	if raw_surface.is_empty():
		_fail("Objective stakes detach control requires a nonempty live surface.")
		return {}
	var expected_surface: Dictionary = raw_surface.duplicate(true)
	raw_surface["context_line"] = "mutated detached objective context"
	var raw_incomplete: Array = raw_surface.get("incomplete_objectives", []) if raw_surface.get("incomplete_objectives", []) is Array else []
	raw_incomplete.append("mutated detached objective")
	raw_surface["incomplete_objectives"] = raw_incomplete
	if OverworldRules._objective_stakes_surface(session) != expected_surface:
		_fail("Objective stakes surface was session-aliased or failed to rebuild from live state.")
		return {}
	var expected_brief := OverworldRules.describe_objective_brief(session)
	var expected_stakes := OverworldRules.describe_objective_stakes_board(session)
	var legacy_started := Time.get_ticks_usec()
	for _index in range(6):
		if OverworldRules.describe_objective_brief(session) != expected_brief \
				or OverworldRules.describe_objective_stakes_board(session) != expected_stakes:
			_fail("Legacy objective header timing control changed output.")
			return {}
	var legacy_usec := Time.get_ticks_usec() - legacy_started
	var bundle_started := Time.get_ticks_usec()
	var timed_bundle: Dictionary = {}
	for _index in range(6):
		timed_bundle = OverworldRules.describe_objective_header_surfaces(session)
		if timed_bundle != {"objective_brief": expected_brief, "objective_stakes": expected_stakes}:
			_fail("Combined objective header timing control changed output.", timed_bundle)
			return {}
	var bundle_usec := Time.get_ticks_usec() - bundle_started
	if legacy_usec * 100 < bundle_usec * 105:
		_fail("Combined objective header surfaces did not remove at least five percent of the legacy two-build work.", {
			"legacy_usec": legacy_usec,
			"bundle_usec": bundle_usec,
		})
		return {}
	return {"bundle_usec": bundle_usec, "legacy_usec": legacy_usec}

func _assert_forecast_bundle_surface_parity(shell: Node, session, label: String) -> bool:
	var authority_before: Dictionary = session.to_dict()
	var bundle: Dictionary = OverworldRules.describe_end_turn_forecast_surfaces(session)
	var default_readiness: Dictionary = shell.call("_field_readiness_surface")
	var preloaded_readiness: Dictionary = shell.call("_field_readiness_surface", {}, bundle)
	var readiness_context: Dictionary = shell.call("_field_readiness_context", bundle)
	var context_readiness: Dictionary = shell.call("_field_readiness_surface", {}, bundle, readiness_context)
	var default_status: Dictionary = shell.call("_status_forecast_surface")
	var preloaded_status: Dictionary = shell.call("_status_forecast_surface", bundle)
	var default_event: Dictionary = shell.call("_event_feed_surface")
	var preloaded_event: Dictionary = shell.call("_event_feed_surface", bundle)
	var context_event: Dictionary = shell.call("_event_feed_surface", bundle, readiness_context)
	var default_end_turn: Dictionary = shell.call("_end_turn_confirmation_surface", default_readiness)
	var preloaded_end_turn: Dictionary = shell.call("_end_turn_confirmation_surface", preloaded_readiness)
	if default_readiness != preloaded_readiness \
			or default_readiness != context_readiness \
			or default_status != preloaded_status \
			or default_event != preloaded_event \
			or default_event != context_event \
			or default_end_turn != preloaded_end_turn:
		_fail("Preloaded forecast changed readiness, status, event, or End Turn surfaces for %s." % label, {
			"default_readiness": default_readiness,
			"preloaded_readiness": preloaded_readiness,
			"context_readiness": context_readiness,
			"default_status": default_status,
			"preloaded_status": preloaded_status,
			"default_event": default_event,
			"preloaded_event": preloaded_event,
			"context_event": context_event,
			"default_end_turn": default_end_turn,
			"preloaded_end_turn": preloaded_end_turn,
		})
		return false
	var original_drawer := String(shell.get("_active_drawer"))
	for drawer in ["", "command", "frontier"]:
		shell.set("_active_drawer", drawer)
		var default_drawer: Dictionary = shell.call("_drawer_handoff_surfaces", default_readiness)
		var preloaded_drawer: Dictionary = shell.call("_drawer_handoff_surfaces", preloaded_readiness, bundle)
		if default_drawer != preloaded_drawer:
			shell.set("_active_drawer", original_drawer)
			_fail("Preloaded forecast changed drawer handoff surfaces for %s/%s." % [label, drawer], {
				"default": default_drawer,
				"preloaded": preloaded_drawer,
			})
			return false
	shell.call("_set_collapsed_frontier_indicator")
	var default_collapsed := _frontier_ui_authority(shell)
	shell.call("_set_collapsed_frontier_indicator", bundle)
	var preloaded_collapsed := _frontier_ui_authority(shell)
	shell.call("_refresh_frontier_drawer")
	var default_frontier := _frontier_ui_authority(shell)
	shell.call("_refresh_frontier_drawer", bundle)
	var preloaded_frontier := _frontier_ui_authority(shell)
	shell.set("_active_drawer", original_drawer)
	shell.call("_refresh")
	if default_collapsed != preloaded_collapsed or default_frontier != preloaded_frontier or session.to_dict() != authority_before:
		_fail("Preloaded forecast changed collapsed/open Frontier or session authority for %s." % label, {
			"default_collapsed": default_collapsed,
			"preloaded_collapsed": preloaded_collapsed,
			"default_frontier": default_frontier,
			"preloaded_frontier": preloaded_frontier,
		})
		return false
	return true

func _assert_event_readiness_context_parity(shell: Node, session, label: String) -> Dictionary:
	var authority_before: Dictionary = session.to_dict()
	var bundle: Dictionary = OverworldRules.describe_end_turn_forecast_surfaces(session)
	shell.call("validation_reset_profile", false)
	var legacy_started := Time.get_ticks_usec()
	var legacy_readiness: Dictionary = shell.call("_field_readiness_surface", {}, bundle)
	var legacy_event: Dictionary = shell.call("_event_feed_surface", bundle)
	var legacy_usec := Time.get_ticks_usec() - legacy_started
	var legacy_profile: Dictionary = shell.call("validation_profile_snapshot")
	if int(legacy_profile.get("field_readiness_context_builds", 0)) != 2 \
			or int(legacy_profile.get("field_readiness_context_reuses", 0)) != 0 \
			or int(legacy_profile.get("field_readiness_context_materializations", 0)) != 2:
		_fail("Legacy event-readiness control did not build two independent contexts for %s." % label, legacy_profile)
		return {}
	shell.call("validation_reset_profile", false)
	var shared_started := Time.get_ticks_usec()
	var shared_context: Dictionary = shell.call("_field_readiness_context", bundle)
	var shared_readiness: Dictionary = shell.call("_field_readiness_surface", {}, bundle, shared_context)
	var shared_event: Dictionary = shell.call("_event_feed_surface", bundle, shared_context)
	var shared_usec := Time.get_ticks_usec() - shared_started
	var shared_profile: Dictionary = shell.call("validation_profile_snapshot")
	if int(shared_profile.get("field_readiness_context_builds", 0)) != 1 \
			or int(shared_profile.get("field_readiness_context_reuses", 0)) != 2 \
			or int(shared_profile.get("field_readiness_context_materializations", 0)) != 2:
		_fail("Shared event-readiness control did not build once and reuse twice for %s." % label, shared_profile)
		return {}
	if legacy_readiness != shared_readiness or legacy_event != shared_event:
		_fail("Shared event-readiness context changed exact surfaces for %s." % label, {
			"legacy_readiness": legacy_readiness,
			"shared_readiness": shared_readiness,
			"legacy_event": legacy_event,
			"shared_event": shared_event,
		})
		return {}
	if legacy_usec * 100 < shared_usec * 105:
		_fail("Shared event-readiness context did not remove at least five percent of the legacy two-build work for %s." % label, {
			"legacy_usec": legacy_usec,
			"shared_usec": shared_usec,
		})
		return {}
	var expected_context: Dictionary = shared_context.duplicate(true)
	shared_context["progress_line"] = "mutated detached readiness control"
	var nested_mutation_count := 0
	for key in ["simple_destination", "active_site_order", "route_target_handoff", "town_entry_handoff"]:
		var nested: Dictionary = shared_context.get(key, {}) if shared_context.get(key, {}) is Dictionary else {}
		if not nested.is_empty():
			nested["visible_text"] = "mutated detached readiness control"
			nested_mutation_count += 1
	if nested_mutation_count <= 0:
		_fail("Shared readiness context exposed no nested detached payload for %s." % label, shared_context)
		return {}
	var rebuilt_context: Dictionary = shell.call("_field_readiness_context", bundle)
	if session.to_dict() != authority_before or rebuilt_context != expected_context:
		_fail("Shared readiness context was session-aliased or did not rebuild from live state for %s." % label, {
			"expected": expected_context,
			"rebuilt": rebuilt_context,
		})
		return {}
	return {
		"legacy_usec": legacy_usec,
		"shared_usec": shared_usec,
		"nested_detach_count": nested_mutation_count,
	}

func _frontier_ui_authority(shell: Node) -> Dictionary:
	var names := ["FrontierIndicator", "Visibility", "Objectives", "Threats", "Forecast"]
	var authority := {}
	for node_name in names:
		var label: Label = shell.get_node("%%%s" % node_name) as Label
		authority[node_name] = {"text": label.text, "tooltip_text": label.tooltip_text}
	return authority

func _assert_drawer_readiness_preload_parity(shell: Node, label: String) -> bool:
	var original_drawer := String(shell.get("_active_drawer"))
	for drawer in ["", "command", "frontier"]:
		shell.set("_active_drawer", drawer)
		var readiness: Dictionary = shell.call("_field_readiness_surface")
		var default_surface: Dictionary = shell.call("_drawer_handoff_surfaces")
		var preloaded_surface: Dictionary = shell.call("_drawer_handoff_surfaces", readiness)
		if preloaded_surface != default_surface:
			shell.set("_active_drawer", original_drawer)
			_fail("Preloaded drawer readiness diverged from the fresh default for %s/%s." % [label, drawer], {
				"default": default_surface,
				"preloaded": preloaded_surface,
			})
			return false
	shell.set("_active_drawer", original_drawer)
	return true

func _refresh_authority(snapshot: Dictionary) -> Dictionary:
	var keys := [
		"status_visible_text",
		"status_tooltip_text",
		"status_forecast",
		"context_summary",
		"context_visible_text",
		"hero_action_surfaces",
		"specialty_action_surfaces",
		"spell_action_surfaces",
		"event_visible_text",
		"event_tooltip_text",
		"event_feed",
		"action_context",
		"field_readiness",
		"objective_brief_visible_text",
		"objective_brief_tooltip_text",
		"end_turn_button_text",
		"end_turn_tooltip_text",
		"end_turn_confirmation",
		"drawer_handoff",
		"command_drawer_button_text",
		"command_drawer_tooltip_text",
		"frontier_drawer_button_text",
		"frontier_drawer_tooltip_text",
		"map_cue_text",
		"map_cue_tooltip_text",
		"selected_route_decision",
		"primary_action",
		"context_actions",
	]
	var authority := {}
	for key in keys:
		authority[key] = snapshot.get(key).duplicate(true) if snapshot.get(key) is Dictionary or snapshot.get(key) is Array else snapshot.get(key)
	return authority

func _fail(message: String, context: Variant = {}) -> void:
	push_error("%s: %s %s" % [REPORT_ID, message, JSON.stringify(context)])
	get_tree().quit(1)
