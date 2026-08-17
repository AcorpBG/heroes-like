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
	var commitment_control := _assert_commitment_summary_fallback_elision(shell, session)
	if commitment_control.is_empty():
		return
	var event_dispatch_control := _assert_event_dispatch_observation_context_reuse()
	if event_dispatch_control.is_empty():
		return
	var refresh_watch_control := _assert_refresh_watch_observation_context_reuse()
	if refresh_watch_control.is_empty():
		return
	_prepare_shell_state(shell, session, Vector2i(0, 1), 10)
	var reserve_id := _ensure_reserve_hero(session)
	shell.call("_refresh")
	var forecast_control := _assert_forecast_bundle_core_parity(session)
	if forecast_control.is_empty():
		return
	var objective_header_control := _assert_objective_header_surface_parity(session)
	if objective_header_control.is_empty():
		return
	var readiness_progress_control := _assert_field_readiness_progress_recap_parity(shell, session, "current_tile")
	if readiness_progress_control.is_empty():
		return
	if not _assert_forecast_bundle_surface_parity(shell, session, "current_tile"):
		return
	if not _assert_drawer_readiness_preload_parity(shell, "current_tile"):
		return
	var drawer_objective_control := _assert_drawer_objective_recap_preload_parity(shell, session, "current_tile")
	if drawer_objective_control.is_empty():
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
	if int(full_refresh_profile.get("objective_progress_recap_builds", 0)) != 1 \
			or int(full_refresh_profile.get("drawer_handoff_preloaded_objective_recap_reuses", 0)) != 1:
		_fail("Full refresh did not reuse its single objective progress recap for the drawer handoff.", full_refresh_profile)
		return
	if int(full_refresh_profile.get("field_readiness_preloaded_progress_recap_reuses", 0)) != 1:
		_fail("Full refresh did not reuse the objective progress recap in Field Readiness context construction.", full_refresh_profile)
		return
	if int(full_refresh_profile.get("event_dispatch_observation_context_builds", 0)) != 1 \
			or int(full_refresh_profile.get("event_dispatch_observation_context_reuses", 0)) != 2:
		_fail("Full refresh did not build one Event/Dispatch observation context and reuse it for both exact surfaces.", full_refresh_profile)
		return
	if int(full_refresh_profile.get("refresh_watch_observation_context_builds", 0)) != 1 \
			or int(full_refresh_profile.get("refresh_watch_observation_context_reuses", 0)) != 3:
		_fail("Full refresh did not build one watch context and reuse it across forecast, commitment, and Event/Dispatch surfaces.", full_refresh_profile)
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
		"objective_progress_recap_builds": int(full_refresh_profile.get("objective_progress_recap_builds", 0)),
		"drawer_handoff_preloaded_objective_recap_reuses": int(full_refresh_profile.get("drawer_handoff_preloaded_objective_recap_reuses", 0)),
		"field_readiness_preloaded_progress_recap_reuses": int(full_refresh_profile.get("field_readiness_preloaded_progress_recap_reuses", 0)),
		"objective_header_bundle_usec": int(objective_header_control.get("bundle_usec", 0)),
		"legacy_objective_header_usec": int(objective_header_control.get("legacy_usec", 0)),
		"legacy_objective_to_bundle_ratio": float(objective_header_control.get("legacy_usec", 0)) / float(maxi(int(objective_header_control.get("bundle_usec", 0)), 1)),
		"objective_header_surface_parity": true,
		"drawer_objective_recap_parity": true,
		"field_readiness_progress_recap_parity": true,
		"direct_readiness_progress_usec": int(readiness_progress_control.get("direct_usec", 0)),
		"preloaded_readiness_progress_usec": int(readiness_progress_control.get("preloaded_usec", 0)),
		"drawer_objective_authored_scenario_count": int(drawer_objective_control.get("scenario_count", 0)),
		"legacy_drawer_objective_usec": int(drawer_objective_control.get("legacy_usec", 0)),
		"shared_drawer_objective_usec": int(drawer_objective_control.get("shared_usec", 0)),
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
		"commitment_context_count": int(commitment_control.get("context_count", 0)),
		"commitment_legacy_median_usec": int(commitment_control.get("legacy_median_usec", 0)),
		"commitment_current_median_usec": int(commitment_control.get("current_median_usec", 0)),
		"commitment_current_to_legacy_ratio": float(commitment_control.get("current_median_usec", 0)) / float(maxi(int(commitment_control.get("legacy_median_usec", 0)), 1)),
		"commitment_full_refresh_usec": int(commitment_control.get("full_refresh_usec", 0)),
		"commitment_full_refresh_rail_usec": int(commitment_control.get("full_refresh_rail_usec", 0)),
		"commitment_context_output_parity": true,
		"commitment_summary_presence_semantics_exact": true,
		"commitment_full_refresh_authority_exact": true,
		"event_dispatch_fixture_count": int(event_dispatch_control.get("fixture_count", 0)),
		"event_dispatch_legacy_median_usec": int(event_dispatch_control.get("legacy_median_usec", 0)),
		"event_dispatch_shared_median_usec": int(event_dispatch_control.get("shared_median_usec", 0)),
		"event_dispatch_shared_to_legacy_ratio": float(event_dispatch_control.get("shared_median_usec", 0)) / float(maxi(int(event_dispatch_control.get("legacy_median_usec", 0)), 1)),
		"event_dispatch_whole_output_parity": true,
		"event_dispatch_session_authority_exact": true,
		"refresh_watch_fixture_count": int(refresh_watch_control.get("fixture_count", 0)),
		"refresh_watch_direct_median_usec": int(refresh_watch_control.get("direct_median_usec", 0)),
		"refresh_watch_shared_median_usec": int(refresh_watch_control.get("shared_median_usec", 0)),
		"refresh_watch_shared_to_direct_ratio": float(refresh_watch_control.get("shared_median_usec", 0)) / float(maxi(int(refresh_watch_control.get("direct_median_usec", 0)), 1)),
		"refresh_watch_whole_output_parity": true,
		"refresh_watch_detached_rebuild_exact": true,
		"refresh_authority_exact": true,
		"legacy_drawer_authority_exact": true,
	})])
	shell.queue_free()
	get_tree().quit(0)

func _assert_commitment_summary_fallback_elision(shell: Node, shell_session) -> Dictionary:
	var context_specs := [
		{"kind": "owned_town", "action_id": "visit_town"},
		{"kind": "enemy_town", "action_id": "capture_town"},
		{"kind": "neutral_town", "action_id": "capture_town"},
		{"kind": "resource", "action_id": "collect_resource"},
		{"kind": "artifact", "action_id": "collect_artifact"},
		{"kind": "encounter", "action_id": "enter_battle"},
		{"kind": "rendezvous", "action_id": "open_rendezvous"},
	]
	var context_rows := []
	for spec_value in context_specs:
		var spec: Dictionary = spec_value
		var fixture: Dictionary = _commitment_context_fixture(String(spec.get("kind", "")))
		var fixture_session = fixture.get("session", null)
		if fixture_session == null:
			_fail("Commitment fixture could not be created.", spec)
			return {}
		var actions: Array = OverworldRules.get_context_actions(fixture_session)
		if actions.is_empty() or not (actions[0] is Dictionary):
			_fail("Commitment fixture did not expose a live context action.", {"spec": spec, "actions": actions})
			return {}
		var action: Dictionary = actions[0]
		if String(action.get("id", "")) != String(spec.get("action_id", "")) or not action.has("summary"):
			_fail("Commitment fixture did not expose the exact authored summary action.", {"spec": spec, "action": action})
			return {}
		var authority_before: Dictionary = fixture_session.to_dict()
		var legacy_line := _legacy_eager_command_commitment_action_line(fixture_session)
		var current_line := OverworldRules._command_commitment_action_line(fixture_session)
		if current_line != legacy_line or current_line != String(action.get("summary", "")):
			_fail("Lazy commitment action line diverged from the independent eager control.", {
				"spec": spec,
				"legacy": legacy_line,
				"current": current_line,
				"summary": String(action.get("summary", "")),
			})
			return {}
		var summaryless: Dictionary = action.duplicate(true)
		summaryless.erase("summary")
		var expected_fallback := OverworldRules._context_action_briefing(
			fixture_session,
			summaryless,
			OverworldRules.get_active_context(fixture_session)
		)
		if OverworldRules._command_commitment_action_summary(fixture_session, summaryless) != expected_fallback:
			_fail("Summary-less commitment action did not use the exact briefing fallback.", spec)
			return {}
		var empty_summary: Dictionary = action.duplicate(true)
		empty_summary["summary"] = ""
		if OverworldRules._command_commitment_action_summary(fixture_session, empty_summary) != "":
			_fail("Present empty commitment summary did not remain authoritative.", spec)
			return {}
		if fixture_session.to_dict() != authority_before:
			_fail("Commitment context parity mutated session authority.", spec)
			return {}
		context_rows.append({"kind": spec.get("kind", ""), "action_id": action.get("id", ""), "summary": current_line})

	var empty_fixture: Dictionary = _commitment_context_fixture("empty")
	var empty_session = empty_fixture.get("session", null)
	var empty_actions: Array = OverworldRules.get_context_actions(empty_session)
	if not empty_actions.is_empty():
		_fail("Empty commitment fixture unexpectedly exposed a context action.", empty_actions)
		return {}
	var empty_before: Dictionary = empty_session.to_dict()
	var empty_line := OverworldRules._command_commitment_action_line(empty_session)
	if empty_line == "" or empty_session.to_dict() != empty_before:
		_fail("Empty commitment fallback was blank or mutated session authority.", {"line": empty_line})
		return {}

	var timing_fixture: Dictionary = _commitment_context_fixture("owned_town")
	var timing_session = timing_fixture.get("session", null)
	var legacy_batches := []
	var current_batches := []
	for batch_index in range(5):
		var legacy_started := Time.get_ticks_usec()
		for _sample in range(3):
			_legacy_eager_command_commitment_action_line(timing_session)
		legacy_batches.append(Time.get_ticks_usec() - legacy_started)
		var current_started := Time.get_ticks_usec()
		for _sample in range(3):
			OverworldRules._command_commitment_action_line(timing_session)
		current_batches.append(Time.get_ticks_usec() - current_started)
	var legacy_median := _integer_median(legacy_batches)
	var current_median := _integer_median(current_batches)
	if legacy_median <= 0 or current_median <= 0 or current_median * 4 > legacy_median * 3:
		_fail("Commitment summary fallback elision was not materially faster than the eager control.", {
			"legacy_batches": legacy_batches,
			"current_batches": current_batches,
			"legacy_median_usec": legacy_median,
			"current_median_usec": current_median,
		})
		return {}

	_set_active_hero_position(shell_session, Vector2i(0, 0))
	_set_active_hero_movement(shell_session, 10)
	shell_session.overworld["fog"] = {}
	OverworldRules.refresh_fog_of_war(shell_session)
	shell.call("_set_selected_tile", Vector2i(0, 0))
	shell.call("_refresh")
	var shell_authority_before: Dictionary = _refresh_authority(shell.call("validation_snapshot"))
	var shell_session_before: Dictionary = shell_session.to_dict()
	var commitment_panel = shell.get("_commitment_panel")
	var commitment_label = shell.get("_commitment_label")
	commitment_panel.visible = true
	shell.set("_debug_command_in_progress", true)
	shell.call("validation_reset_profile", true)
	var full_refresh_started := Time.get_ticks_usec()
	shell.call("_refresh")
	var full_refresh_usec := Time.get_ticks_usec() - full_refresh_started
	var full_refresh_profile: Dictionary = shell.call("validation_profile_snapshot")
	var expected_board := OverworldRules.describe_commitment_board(shell_session)
	if String(commitment_label.text) == "" or String(commitment_label.tooltip_text) != expected_board:
		_fail("Active-town full refresh did not preserve the exact commitment rail text.", {
			"expected": expected_board,
			"text": String(commitment_label.text),
			"tooltip": String(commitment_label.tooltip_text),
		})
		return {}
	if int(full_refresh_profile.get("refresh_commitment_rail_usec", 0)) <= 0:
		_fail("Active-town full refresh did not profile the commitment rail.", full_refresh_profile)
		return {}
	if shell_session.to_dict() != shell_session_before or _refresh_authority(shell.call("validation_snapshot")) != shell_authority_before:
		_fail("Active-town full refresh changed session or whole refresh authority.", {})
		return {}
	return {
		"context_count": context_rows.size() + 1,
		"legacy_median_usec": legacy_median,
		"current_median_usec": current_median,
		"full_refresh_usec": full_refresh_usec,
		"full_refresh_rail_usec": int(full_refresh_profile.get("refresh_commitment_rail_usec", 0)),
	}

func _assert_event_dispatch_observation_context_reuse() -> Dictionary:
	var ordinary = _session_with_map(12, 3)
	OverworldRules.normalize_overworld_state(ordinary)
	var pressure = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(pressure)
	_set_active_hero_position(pressure, Vector2i(3, 1))
	pressure.overworld["fog"] = {}
	OverworldRules.refresh_fog_of_war(pressure)
	var outcome = _session_with_map(12, 3)
	outcome.scenario_status = "victory"
	outcome.game_state = "outcome"
	outcome.scenario_summary = "River Pass secured."
	OverworldRules.normalize_overworld_state(outcome)
	var fixtures := [
		{"id": "idle", "session": ordinary},
		{"id": "message", "session": ordinary, "last_message": "Riverwatch Hold is ready."},
		{"id": "daybreak", "session": ordinary, "turn": "Day 2 begins."},
		{
			"id": "enemy_activity",
			"session": ordinary,
			"enemy": "Mireclaw advances.",
			"events": [{"event_type": "ai_target_assigned", "target_label": "Riverwatch Hold", "target_kind": "town", "faction_label": "Mireclaw"}],
		},
		{
			"id": "action_recap",
			"session": ordinary,
			"recap": {"happened": "Claimed North Wood.", "affected": "North Wood", "why_it_matters": "The route now pays wood.", "next_step": "Return to Riverwatch Hold."},
		},
		{"id": "pressure_watch", "session": pressure},
		{"id": "outcome", "session": outcome, "last_message": "The river road is secure."},
	]
	for fixture_value in fixtures:
		var fixture: Dictionary = fixture_value
		var probe = fixture.get("session", null)
		OverworldRules.normalize_overworld_state(probe)
		var authority_before: Dictionary = probe.to_dict()
		var legacy: Dictionary = _legacy_event_dispatch_bundle(probe, fixture)
		var shared: Dictionary = OverworldRules.describe_event_dispatch_surfaces(
			probe,
			String(fixture.get("last_message", "")),
			String(fixture.get("turn", "")),
			String(fixture.get("enemy", "")),
			fixture.get("events", []),
			fixture.get("recap", {})
		)
		if shared != legacy or probe.to_dict() != authority_before:
			_fail("Shared Event/Dispatch observations diverged from the independent legacy materializers.", {
				"fixture": fixture.get("id", ""),
				"legacy": legacy,
				"shared": shared,
			})
			return {}
	var legacy_batches := []
	var shared_batches := []
	for _batch in range(5):
		var legacy_started := Time.get_ticks_usec()
		for fixture_value in fixtures:
			_legacy_event_dispatch_bundle(fixture_value.get("session", null), fixture_value)
		legacy_batches.append(Time.get_ticks_usec() - legacy_started)
		var shared_started := Time.get_ticks_usec()
		for fixture_value in fixtures:
			OverworldRules.describe_event_dispatch_surfaces(
				fixture_value.get("session", null),
				String(fixture_value.get("last_message", "")),
				String(fixture_value.get("turn", "")),
				String(fixture_value.get("enemy", "")),
				fixture_value.get("events", []),
				fixture_value.get("recap", {})
			)
		shared_batches.append(Time.get_ticks_usec() - shared_started)
	var legacy_median := _integer_median(legacy_batches)
	var shared_median := _integer_median(shared_batches)
	if legacy_median <= 0 or shared_median <= 0 or shared_median * 4 > legacy_median * 3:
		_fail("Shared Event/Dispatch observations were not materially faster than independent legacy materialization.", {
			"legacy_batches": legacy_batches,
			"shared_batches": shared_batches,
			"legacy_median_usec": legacy_median,
			"shared_median_usec": shared_median,
		})
		return {}
	return {
		"fixture_count": fixtures.size(),
		"legacy_median_usec": legacy_median,
		"shared_median_usec": shared_median,
	}

func _legacy_event_dispatch_bundle(session, fixture: Dictionary) -> Dictionary:
	return {
		"event_feed": _legacy_event_feed_surface(
			session,
			String(fixture.get("last_message", "")),
			String(fixture.get("turn", "")),
			String(fixture.get("enemy", "")),
			fixture.get("events", []),
			fixture.get("recap", {})
		),
		"dispatch": _legacy_dispatch(session, String(fixture.get("last_message", ""))),
	}

func _legacy_dispatch(session, last_message: String) -> String:
	OverworldRules.normalize_overworld_state(session)
	var lead_line := "Latest order: %s" % last_message if last_message != "" else "The field table is waiting on fresh orders."
	var lines := [
		"Field Dispatch",
		"- %s" % lead_line,
		"- Active tile: %s" % OverworldRules._dispatch_context_brief(session),
		"- %s" % OverworldRules._local_visible_threat_summary(session, "No visible hostile pressure is crowding the active hero."),
	]
	var management_watch := OverworldRules.describe_management_watch(session)
	if management_watch != "":
		lines.append("- Management watch: %s" % management_watch)
	var defense_watch := OverworldRules.describe_defense_readiness_warnings(session, 1)
	if defense_watch != "No exposed town or route-defense warning is visible.":
		lines.append("- Defense readiness: %s" % defense_watch)
	var recent_events: String = OverworldRules._describe_recent_events(session, 2)
	if recent_events != "":
		lines.append("- Scenario pulse: %s" % recent_events)
	if session.scenario_status != "in_progress" and session.scenario_summary != "":
		lines.append("- Outcome pending: %s" % session.scenario_summary)
	return "\n".join(lines)

func _legacy_event_feed_surface(
	session,
	last_message: String,
	turn_resolution_summary: String,
	enemy_activity_summary: String,
	enemy_activity_events_value: Variant,
	action_recap_value: Variant
) -> Dictionary:
	OverworldRules.normalize_overworld_state(session)
	var recent_events := OverworldRules._describe_recent_events(session, 2)
	var action_recap := OverworldRules._normalize_post_action_recap(action_recap_value)
	var use_action_recap := turn_resolution_summary.strip_edges() == "" and enemy_activity_summary.strip_edges() == "" and not action_recap.is_empty()
	var happened := String(action_recap.get("happened", "")) if use_action_recap else OverworldRules._event_feed_happened_line(last_message, turn_resolution_summary, enemy_activity_summary, recent_events)
	var affected := String(action_recap.get("affected", "")) if use_action_recap else OverworldRules._event_feed_affected_line(session, enemy_activity_summary, enemy_activity_events_value)
	var why := String(action_recap.get("why_it_matters", "")) if use_action_recap else OverworldRules._event_feed_why_line(last_message, turn_resolution_summary, enemy_activity_summary, recent_events)
	var next_step := String(action_recap.get("next_step", "")) if use_action_recap else OverworldRules._event_feed_next_step_line(session)
	var watch := _legacy_event_feed_watch_line(session)
	var visible := OverworldRules._event_feed_visible_line(happened, turn_resolution_summary, enemy_activity_summary)
	var tooltip_lines := ["Field Feed"]
	tooltip_lines.append("- Happened: %s" % happened)
	if turn_resolution_summary.strip_edges() != "":
		tooltip_lines.append("- Daybreak result: %s" % turn_resolution_summary.strip_edges())
	if enemy_activity_summary.strip_edges() != "":
		tooltip_lines.append("- Recent enemy activity: %s" % enemy_activity_summary.strip_edges())
	if recent_events != "":
		tooltip_lines.append("- Scenario pulse: %s" % OverworldRules._short_player_text(recent_events, 180))
	if affected != "":
		tooltip_lines.append("- Affected: %s" % affected)
	if why != "":
		tooltip_lines.append("- Why it matters: %s" % why)
	if next_step != "":
		tooltip_lines.append("- Next: %s" % next_step)
	if watch != "":
		tooltip_lines.append("- Watch: %s" % watch)
	return {
		"visible_text": visible,
		"tooltip_text": "\n".join(tooltip_lines),
		"happened": happened,
		"affected": affected,
		"why_it_matters": why,
		"next_step": next_step,
		"watch": watch,
		"recent_events": recent_events,
		"enemy_activity_summary": enemy_activity_summary,
		"turn_resolution_summary": turn_resolution_summary,
		"post_action_recap": action_recap,
	}

func _legacy_event_feed_watch_line(session) -> String:
	var parts := []
	var route_pressure := OverworldRules.describe_route_interception_surface(session)
	if bool(route_pressure.get("active", false)):
		parts.append(String(route_pressure.get("cue_text", "")))
	var local_pressure := OverworldRules._local_visible_threat_summary(session, "")
	if local_pressure != "":
		parts.append(local_pressure)
	var management_watch := OverworldRules.describe_management_watch(session)
	if management_watch != "" and management_watch != "Town lines are stable.":
		parts.append(management_watch)
	var defense_watch := OverworldRules.describe_defense_readiness_warnings(session, 1)
	if defense_watch != "No exposed town or route-defense warning is visible.":
		parts.append("Defense readiness: %s" % defense_watch)
	if parts.is_empty():
		return "No urgent raid, convoy, or town-management warning is visible."
	return " | ".join(parts.slice(0, min(3, parts.size())))

func _assert_refresh_watch_observation_context_reuse() -> Dictionary:
	var ordinary = _session_with_map(12, 3)
	OverworldRules.normalize_overworld_state(ordinary)
	var pressure = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(pressure)
	_set_active_hero_position(pressure, Vector2i(3, 1))
	pressure.overworld["fog"] = {}
	OverworldRules.refresh_fog_of_war(pressure)
	var outcome = _session_with_map(12, 3)
	outcome.scenario_status = "victory"
	outcome.game_state = "outcome"
	outcome.scenario_summary = "River Pass secured."
	OverworldRules.normalize_overworld_state(outcome)
	var fixtures := [
		{"id": "idle", "session": ordinary},
		{"id": "message", "session": ordinary, "last_message": "Riverwatch Hold is ready."},
		{"id": "daybreak", "session": ordinary, "turn": "Day 2 begins."},
		{
			"id": "enemy_activity",
			"session": ordinary,
			"enemy": "Mireclaw advances.",
			"events": [{"event_type": "ai_target_assigned", "target_label": "Riverwatch Hold", "target_kind": "town", "faction_label": "Mireclaw"}],
		},
		{
			"id": "action_recap",
			"session": ordinary,
			"recap": {"happened": "Claimed North Wood.", "affected": "North Wood", "why_it_matters": "The route now pays wood.", "next_step": "Return to Riverwatch Hold."},
		},
		{"id": "pressure_watch", "session": pressure},
		{"id": "outcome", "session": outcome, "last_message": "The river road is secure."},
	]
	for fixture_value in fixtures:
		var fixture: Dictionary = fixture_value
		var probe = fixture.get("session", null)
		OverworldRules.normalize_overworld_state(probe)
		var authority_before: Dictionary = probe.to_dict()
		var independent: Dictionary = _legacy_refresh_watch_surfaces(probe, fixture)
		var direct: Dictionary = _direct_refresh_watch_surfaces(probe, fixture)
		var shared: Dictionary = _shared_refresh_watch_surfaces(probe, fixture)
		if direct != independent or shared != independent or probe.to_dict() != authority_before:
			_fail("Refresh watch context diverged from independent forecast, commitment, Event Feed, or Dispatch materializers.", {
				"fixture": fixture.get("id", ""),
				"independent": independent,
				"direct": direct,
				"shared": shared,
			})
			return {}
	var detach_probe = pressure
	var detach_authority_before: Dictionary = detach_probe.to_dict()
	var raw_context: Dictionary = OverworldRules._refresh_watch_observation_context(detach_probe)
	var fresh_context: Dictionary = OverworldRules._refresh_watch_observation_context(detach_probe)
	if raw_context.keys() != ["command_risk_forecast", "command_risk_surfaces", "local_pressure", "management_watch"] \
			or raw_context != fresh_context \
			or not (raw_context.get("command_risk_forecast", {}) is Dictionary) \
			or not (raw_context.get("command_risk_surfaces", {}) is Dictionary):
		_fail("Refresh watch context did not expose the exact detached ordered contract.", raw_context)
		return {}
	var raw_forecast: Dictionary = raw_context.get("command_risk_forecast", {})
	var raw_surfaces: Dictionary = raw_context.get("command_risk_surfaces", {})
	raw_forecast["summary"] = "mutated detached forecast"
	raw_surfaces["risk"] = "mutated detached surface"
	raw_context["local_pressure"] = "mutated detached pressure"
	raw_context["management_watch"] = "mutated detached management"
	if detach_probe.to_dict() != detach_authority_before \
			or OverworldRules._refresh_watch_observation_context(detach_probe) != fresh_context:
		_fail("Refresh watch context was session-aliased or failed to rebuild from live state.", raw_context)
		return {}
	var direct_batches := []
	var shared_batches := []
	for _batch in range(5):
		var direct_started := Time.get_ticks_usec()
		for fixture_value in fixtures:
			_direct_refresh_watch_surfaces(fixture_value.get("session", null), fixture_value)
		direct_batches.append(Time.get_ticks_usec() - direct_started)
		var shared_started := Time.get_ticks_usec()
		for fixture_value in fixtures:
			_shared_refresh_watch_surfaces(fixture_value.get("session", null), fixture_value)
		shared_batches.append(Time.get_ticks_usec() - shared_started)
	var direct_median := _integer_median(direct_batches)
	var shared_median := _integer_median(shared_batches)
	if direct_median <= 0 or shared_median <= 0 or shared_median * 4 > direct_median * 3:
		_fail("Refresh watch context reuse was not materially faster than fresh direct materialization.", {
			"direct_batches": direct_batches,
			"shared_batches": shared_batches,
			"direct_median_usec": direct_median,
			"shared_median_usec": shared_median,
		})
		return {}
	return {
		"fixture_count": fixtures.size(),
		"direct_median_usec": direct_median,
		"shared_median_usec": shared_median,
	}

func _direct_refresh_watch_surfaces(session, fixture: Dictionary) -> Dictionary:
	var event_dispatch := OverworldRules.describe_event_dispatch_surfaces(
		session,
		String(fixture.get("last_message", "")),
		String(fixture.get("turn", "")),
		String(fixture.get("enemy", "")),
		fixture.get("events", []),
		fixture.get("recap", {})
	)
	return {
		"forecast": OverworldRules.describe_end_turn_forecast_surfaces(session),
		"commitment": OverworldRules.describe_commitment_board(session),
		"event_feed": event_dispatch.get("event_feed", {}),
		"dispatch": event_dispatch.get("dispatch", ""),
	}

func _shared_refresh_watch_surfaces(session, fixture: Dictionary) -> Dictionary:
	var refresh_watch_context := OverworldRules._refresh_watch_observation_context(session)
	var event_dispatch := OverworldRules.describe_event_dispatch_surfaces(
		session,
		String(fixture.get("last_message", "")),
		String(fixture.get("turn", "")),
		String(fixture.get("enemy", "")),
		fixture.get("events", []),
		fixture.get("recap", {}),
		refresh_watch_context
	)
	return {
		"forecast": OverworldRules.describe_end_turn_forecast_surfaces(session, refresh_watch_context),
		"commitment": OverworldRules.describe_commitment_board(session, refresh_watch_context),
		"event_feed": event_dispatch.get("event_feed", {}),
		"dispatch": event_dispatch.get("dispatch", ""),
	}

func _legacy_refresh_watch_surfaces(session, fixture: Dictionary) -> Dictionary:
	return {
		"forecast": _legacy_refresh_watch_forecast(session),
		"commitment": _legacy_refresh_watch_commitment(session),
		"event_feed": _legacy_event_feed_surface(
			session,
			String(fixture.get("last_message", "")),
			String(fixture.get("turn", "")),
			String(fixture.get("enemy", "")),
			fixture.get("events", []),
			fixture.get("recap", {})
		),
		"dispatch": _legacy_dispatch(session, String(fixture.get("last_message", ""))),
	}

func _legacy_refresh_watch_forecast(session) -> Dictionary:
	OverworldRules.normalize_overworld_state(session)
	var next_day: int = int(session.day) + 1
	var income_line := OverworldRules._end_turn_income_forecast_line(session, next_day)
	var muster_line := OverworldRules._end_turn_muster_forecast_line(session, next_day)
	var movement_line := OverworldRules._end_turn_movement_forecast_line(session)
	var risk_line := OverworldRules._end_turn_risk_forecast_line(session)
	var management_line := OverworldRules.describe_management_watch(session)
	var full_lines := [
		"Next day: Day %d | %s | %s" % [next_day, income_line, muster_line],
		"- Movement: %s" % movement_line,
	]
	if risk_line != "":
		full_lines.append("- Pressure: %s" % risk_line)
	if management_line != "":
		full_lines.append("- Town lines: %s" % management_line)
	var compact_parts := ["Day %d" % next_day, income_line, movement_line]
	if risk_line != "":
		compact_parts.append(risk_line)
	return {"forecast": "\n".join(full_lines), "forecast_compact": " | ".join(compact_parts)}

func _legacy_refresh_watch_commitment(session) -> String:
	OverworldRules.normalize_overworld_state(session)
	return "\n".join([
		"Command Commitment",
		"- Immediate order: %s" % OverworldRules._command_commitment_action_line(session),
		"- Route pressure: %s" % OverworldRules._command_commitment_route_line(session),
		"- Coverage: %s" % OverworldRules._command_commitment_coverage_line(session),
		"- If you hold: %s" % OverworldRules._command_commitment_hold_line(session),
	])

func _legacy_eager_command_commitment_action_line(session) -> String:
	var context_actions := OverworldRules.get_context_actions(session)
	if context_actions.is_empty() or not (context_actions[0] is Dictionary):
		return ""
	var action: Dictionary = context_actions[0]
	return String(action.get("summary", OverworldRules._context_action_briefing(session, action, OverworldRules.get_active_context(session))))

func _commitment_context_fixture(kind: String) -> Dictionary:
	var session = _session_with_map(12, 3)
	match kind:
		"owned_town", "enemy_town", "neutral_town":
			var towns: Array = session.overworld.get("towns", [])
			var town: Dictionary = towns[0]
			town["owner"] = "player" if kind == "owned_town" else ("enemy" if kind == "enemy_town" else "neutral")
			towns[0] = town
			session.overworld["towns"] = towns
			_set_active_hero_position(session, Vector2i(0, 0))
		"resource", "artifact", "encounter":
			session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
			OverworldRules.normalize_overworld_state(session)
			var bucket_key := "resource_nodes" if kind == "resource" else ("artifact_nodes" if kind == "artifact" else "encounters")
			var bucket: Array = session.overworld.get(bucket_key, [])
			var entry: Dictionary = bucket[0]
			_set_active_hero_position(session, Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0))))
		"rendezvous":
			_set_active_hero_position(session, Vector2i(10, 1))
			var reserve_id := _ensure_reserve_hero(session)
			_set_roster_hero_position(session, reserve_id, Vector2i(10, 1))
		"empty":
			_set_active_hero_position(session, Vector2i(11, 1))
		_:
			return {}
	session.overworld["fog"] = {}
	OverworldRules.refresh_fog_of_war(session)
	return {"session": session}

func _set_roster_hero_position(session, hero_id: String, tile: Vector2i) -> void:
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == hero_id:
			var hero: Dictionary = heroes[index]
			hero["position"] = {"x": tile.x, "y": tile.y}
			heroes[index] = hero
			break
	session.overworld["player_heroes"] = heroes
	OverworldRules.normalize_overworld_state(session)

func _integer_median(values: Array) -> int:
	var ordered := values.duplicate()
	ordered.sort()
	return int(ordered[ordered.size() / 2])

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
			"progress_recap": ScenarioRules.describe_session_progress_recap(probe, false),
		}
		var bundled: Dictionary = OverworldRules.describe_objective_header_surfaces(probe)
		if bundled != expected or bundled.keys() != ["objective_brief", "objective_stakes", "progress_recap"] or probe.to_dict() != authority_before:
			_fail("Combined objective header surfaces diverged from independent production wrappers for %s." % String(row.get("id", "")), {
				"expected": expected,
				"bundled": bundled,
			})
			return {}
		bundled["objective_brief"] = "mutated detached objective brief"
		bundled["objective_stakes"] = "mutated detached objective stakes"
		bundled["progress_recap"] = "mutated detached progress recap"
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
	var expected_progress_recap := ScenarioRules.describe_session_progress_recap(session, false)
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
		if timed_bundle != {
			"objective_brief": expected_brief,
			"objective_stakes": expected_stakes,
			"progress_recap": expected_progress_recap,
		}:
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

func _assert_field_readiness_progress_recap_parity(shell: Node, session, label: String) -> Dictionary:
	var authority_before: Dictionary = session.to_dict()
	var forecast: Dictionary = OverworldRules.describe_end_turn_forecast_surfaces(session)
	var objective_header_surfaces: Dictionary = OverworldRules.describe_objective_header_surfaces(session)
	shell.call("validation_reset_profile", false)
	var direct_started := Time.get_ticks_usec()
	var direct_context: Dictionary = shell.call("_field_readiness_context", forecast)
	var direct_usec := Time.get_ticks_usec() - direct_started
	var direct_profile: Dictionary = shell.call("validation_profile_snapshot")
	if int(direct_profile.get("field_readiness_preloaded_progress_recap_reuses", 0)) != 0:
		_fail("Direct Field Readiness context unexpectedly reused a preloaded progress recap for %s." % label, direct_profile)
		return {}
	shell.call("validation_reset_profile", false)
	var preloaded_started := Time.get_ticks_usec()
	var preloaded_context: Dictionary = shell.call("_field_readiness_context", forecast, objective_header_surfaces)
	var preloaded_usec := Time.get_ticks_usec() - preloaded_started
	var preloaded_profile: Dictionary = shell.call("validation_profile_snapshot")
	if int(preloaded_profile.get("field_readiness_preloaded_progress_recap_reuses", 0)) != 1:
		_fail("Preloaded Field Readiness context did not reuse exactly one progress recap for %s." % label, preloaded_profile)
		return {}
	var direct_readiness: Dictionary = shell.call("_field_readiness_surface", {}, forecast, direct_context)
	var preloaded_readiness: Dictionary = shell.call("_field_readiness_surface", {}, forecast, preloaded_context)
	var direct_event: Dictionary = shell.call("_event_feed_surface", forecast, direct_context)
	var preloaded_event: Dictionary = shell.call("_event_feed_surface", forecast, preloaded_context)
	if direct_context != preloaded_context \
			or direct_readiness != preloaded_readiness \
			or direct_event != preloaded_event \
			or session.to_dict() != authority_before:
		_fail("Preloaded progress recap changed Field Readiness context, outputs, event surface, or session authority for %s." % label, {
			"direct_context": direct_context,
			"preloaded_context": preloaded_context,
			"direct_readiness": direct_readiness,
			"preloaded_readiness": preloaded_readiness,
			"direct_event": direct_event,
			"preloaded_event": preloaded_event,
		})
		return {}
	if direct_usec * 100 < preloaded_usec * 105:
		_fail("Preloaded progress recap did not remove at least five percent of direct Field Readiness context work for %s." % label, {
			"direct_usec": direct_usec,
			"preloaded_usec": preloaded_usec,
		})
		return {}
	return {"direct_usec": direct_usec, "preloaded_usec": preloaded_usec}

func _assert_drawer_objective_recap_preload_parity(shell: Node, session, label: String) -> Dictionary:
	var authority_before: Dictionary = session.to_dict()
	var readiness: Dictionary = shell.call("_field_readiness_surface")
	var forecast: Dictionary = OverworldRules.describe_end_turn_forecast_surfaces(session)
	var objective_header_surfaces: Dictionary = OverworldRules.describe_objective_header_surfaces(session)
	shell.call("validation_reset_profile", true)
	var legacy_started := Time.get_ticks_usec()
	var legacy: Dictionary = shell.call("_drawer_handoff_surfaces", readiness, forecast)
	var legacy_usec := Time.get_ticks_usec() - legacy_started
	var legacy_profile: Dictionary = shell.call("validation_profile_snapshot")
	if int(legacy_profile.get("drawer_handoff_preloaded_objective_recap_reuses", 0)) != 0:
		_fail("Default drawer handoff unexpectedly reused a preloaded objective recap for %s." % label, legacy_profile)
		return {}
	shell.call("validation_reset_profile", true)
	var shared_started := Time.get_ticks_usec()
	var shared: Dictionary = shell.call("_drawer_handoff_surfaces", readiness, forecast, objective_header_surfaces)
	var shared_usec := Time.get_ticks_usec() - shared_started
	var shared_profile: Dictionary = shell.call("validation_profile_snapshot")
	if int(shared_profile.get("drawer_handoff_preloaded_objective_recap_reuses", 0)) != 1:
		_fail("Preloaded drawer handoff did not reuse exactly one objective recap for %s." % label, shared_profile)
		return {}
	if shared != legacy or session.to_dict() != authority_before:
		_fail("Preloaded objective recap changed drawer handoff or session authority for %s." % label, {
			"legacy": legacy,
			"shared": shared,
		})
		return {}
	if legacy_usec * 100 < shared_usec * 105:
		_fail("Preloaded objective recap did not remove at least five percent of the default full-board handoff work for %s." % label, {
			"legacy_usec": legacy_usec,
			"shared_usec": shared_usec,
		})
		return {}
	var scenario_count := _assert_all_authored_drawer_objective_recap_parity()
	if scenario_count <= 0:
		return {}
	return {"legacy_usec": legacy_usec, "shared_usec": shared_usec, "scenario_count": scenario_count}

func _assert_all_authored_drawer_objective_recap_parity() -> int:
	var scenario_ids := ContentService.get_content_ids(ContentService.SCENARIOS_PATH)
	scenario_ids.sort()
	var checked := 0
	for scenario_id_value in scenario_ids:
		var scenario_id := String(scenario_id_value)
		var probe = ScenarioFactory.create_session(scenario_id, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
		if probe == null or probe.scenario_id == "":
			continue
		OverworldRules.normalize_overworld_state(probe)
		for day_offset in [0, 1]:
			probe.day += day_offset
			OverworldRules.normalize_overworld_state(probe)
			var authority_before: Dictionary = probe.to_dict()
			var legacy_line: String = _objective_line_with_prefix(OverworldRules.describe_objectives(probe), "Next step:")
			var recap := ScenarioRules.describe_session_progress_recap(probe, false)
			var shared_line: String = _objective_line_with_prefix(recap, "Next step:")
			if legacy_line != shared_line or probe.to_dict() != authority_before:
				_fail("Authored drawer objective recap diverged for %s/day%d." % [scenario_id, probe.day], {
					"legacy_line": legacy_line,
					"shared_line": shared_line,
				})
				return 0
		checked += 1
	return checked

func _objective_line_with_prefix(text: String, prefix: String) -> String:
	for raw_line in text.split("\n", false):
		var line := String(raw_line).strip_edges()
		if line.begins_with(prefix):
			return line
	return ""

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
