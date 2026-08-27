extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const REPORT_ID := "TOWN_ENTITY_CACHE_ACTIVE_REFRESH_REGRESSION"
const GENERATED_LARGE_SEED := "town-entry-cache-regression-large-10184"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var previous_general := OS.get_environment("HEROES_PROFILE_LOG")
	OS.set_environment("HEROES_PROFILE_LOG", "1")
	SaveService.validation_clear_general_profile_log()
	ContentService.clear_generated_scenario_drafts()
	SessionState.reset_session()

	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var first_town := _first_player_town(session)
	if first_town.is_empty():
		_finish_fail("No player town was available for the town cache regression.")
		return
	var second_town := _ensure_second_player_town(session, first_town)
	_give_resources(session)
	_move_active_hero_to_town(session, first_town)
	var first_id := String(first_town.get("placement_id", ""))
	var second_id := String(second_town.get("placement_id", ""))
	var visit_result: Dictionary = OverworldRules.set_active_town_visit(session, first_id)
	if not bool(visit_result.get("ok", false)):
		_finish_fail("Could not prepare first active town visit.", visit_result)
		return
	SessionState.set_active_session(session)
	session = SessionState.ensure_active_session()
	AppRouter.validation_prepare_town_handoff_without_scene_change()

	OverworldRules.validation_set_pathing_profile_capture_enabled(true)
	var shell = load("res://scenes/town/TownShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame

	var entry_snapshot: Dictionary = shell.call("validation_town_entity_cache_snapshot")
	if not _assert_snapshot(entry_snapshot, first_id, false, true, "initial entry"):
		return
	var lookup_profile: Dictionary = OverworldRules.validation_pathing_profile_snapshot()
	if int(lookup_profile.get("town_placement_lookup_full_scan_count", 0)) != 0:
		_finish_fail("Town entry scanned all towns after active-town visit handoff.", lookup_profile)
		return

	var records: Array = SaveService.validation_general_profile_log_last_records(20)
	if _has_save_surface_build_record(records):
		_finish_fail("Ordinary town entry built the expensive save surface.", records)
		return
	var entry_cache: Dictionary = entry_snapshot.get("last_cache_result", {}) if entry_snapshot.get("last_cache_result", {}) is Dictionary else {}
	if String(entry_cache.get("cache_key", "")) != "%s|full" % first_id or bool(entry_cache.get("minimal", true)) or String(entry_cache.get("signature", "")).find("|tab:") >= 0:
		_finish_fail("Initial Town entry did not populate one tab-independent full entity state.", entry_snapshot)
		return

	var tab_reuse: Dictionary = await _assert_management_tab_full_state_reuse(shell, session, first_id)
	if tab_reuse.is_empty():
		return

	var hit_snapshot: Dictionary = shell.call("validation_force_minimal_refresh")
	if not _assert_snapshot(hit_snapshot, first_id, true, true, "same-town current-tab refresh"):
		return
	var full_build_snapshot: Dictionary = shell.call("validation_force_refresh")
	if not _assert_snapshot(full_build_snapshot, first_id, true, true, "same-town explicit full refresh"):
		return
	var full_again_snapshot: Dictionary = shell.call("validation_force_refresh")
	if not _assert_snapshot(full_again_snapshot, first_id, true, true, "same-town full refresh after explicit full build"):
		return
	var same_shell_records: Array = SaveService.validation_general_profile_log_last_records(40)
	var same_shell_hit_record := _find_town_refresh_record(same_shell_records, true)
	if same_shell_hit_record.is_empty():
		_finish_fail("Same-shell town refresh did not expose a cache-hit profile record.", same_shell_records)
		return
	if not _assert_cache_hit_refresh_is_light(same_shell_hit_record, "same-shell cache-hit refresh"):
		return

	SaveService.validation_clear_general_profile_log()
	shell.queue_free()
	await get_tree().process_frame
	var leave_result: Dictionary = AppRouter.validation_prepare_overworld_handoff_without_scene_change()
	if not bool(leave_result.get("ok", false)):
		_finish_fail("Could not prepare ordinary town exit handoff for re-entry coverage.", leave_result)
		return
	_simulate_overworld_resource_movement(session, first_town)
	OverworldRules.set_active_town_visit(session, first_id)
	var reenter_result: Dictionary = AppRouter.validation_prepare_town_handoff_without_scene_change()
	if not bool(reenter_result.get("ok", false)):
		_finish_fail("Could not prepare ordinary same-town re-entry handoff.", reenter_result)
		return
	var reentry_shell = load("res://scenes/town/TownShell.tscn").instantiate()
	add_child(reentry_shell)
	await get_tree().process_frame
	await get_tree().process_frame
	var reentry_snapshot: Dictionary = reentry_shell.call("validation_town_entity_cache_snapshot")
	if not _assert_snapshot(reentry_snapshot, first_id, true, true, "same-town scene re-entry"):
		return
	var reentry_records: Array = SaveService.validation_general_profile_log_last_records(40)
	if _has_save_surface_build_record(reentry_records):
		_finish_fail("Ordinary same-town re-entry built the expensive save surface.", reentry_records)
		return
	var ready_record := _find_town_ready_record(reentry_records)
	if ready_record.is_empty():
		_finish_fail("Same-town re-entry did not expose a town_ready profile record.", reentry_records)
		return
	if not _assert_town_ready_reentry_is_light(ready_record):
		return
	var reentry_hit_record := _find_town_refresh_record(reentry_records, true)
	if reentry_hit_record.is_empty():
		_finish_fail("Same-town re-entry refresh did not expose a cache-hit profile record.", reentry_records)
		return
	if not _assert_cache_hit_refresh_is_light(reentry_hit_record, "same-town scene re-entry cache-hit refresh"):
		return
	if _has_town_refresh_cache_miss_record(reentry_records):
		_finish_fail("Ordinary same-town re-entry triggered a full town cache rebuild after the cache-hit refresh.", reentry_records)
		return
	reentry_shell.queue_free()
	await get_tree().process_frame
	OverworldRules.set_active_town_visit(session, first_id)
	AppRouter.validation_prepare_town_handoff_without_scene_change()
	shell = load("res://scenes/town/TownShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame

	OverworldRules.set_active_town_visit(session, second_id)
	OverworldRules.validation_set_pathing_profile_capture_enabled(true)
	var second_snapshot: Dictionary = shell.call("validation_force_refresh")
	if not _assert_snapshot(second_snapshot, second_id, false, true, "second-town refresh"):
		return
	if int(second_snapshot.get("entry_count", 0)) < 2:
		_finish_fail("Per-town cache did not keep separate entries after visiting two towns.", second_snapshot)
		return

	OverworldRules.set_active_town_visit(session, first_id)
	OverworldRules.validation_set_pathing_profile_capture_enabled(true)
	var first_again_snapshot: Dictionary = shell.call("validation_force_refresh")
	if not _assert_snapshot(first_again_snapshot, first_id, true, true, "first-town return"):
		return
	_warm_save_summary_cache()
	var resource_hit_authority := _authority_snapshot(session, shell)
	var resource_hit_ledger: Dictionary = shell.call("validation_resource_ledger_snapshot")
	if not _assert_economy_ledger_parity(shell, resource_hit_ledger, "resource-only full cache hit"):
		return
	if not _assert_departure_parity(shell, session, "resource-only full cache hit"):
		return
	if not _assert_exact_authority(_authority_snapshot(session, shell), resource_hit_authority, "resource-only full cache-hit parity"):
		return
	var context_invalidation_row: Dictionary = await _assert_economy_context_invalidates_once_then_hits_fast(
		shell,
		session,
		first_id,
		second_id
	)
	if context_invalidation_row.is_empty():
		return

	var action_invalidation_rows := []
	for lane in ["build", "recruit", "market"]:
		var action_id := _first_enabled_action(shell, lane)
		if action_id == "":
			_finish_fail("No enabled %s action was available for cache invalidation coverage." % lane, shell.call("validation_action_catalog"))
			return
		var invalidation_row: Dictionary = await _assert_action_invalidates_once_then_hits_fast(
			shell,
			session,
			lane,
			action_id,
			first_id,
			second_id
		)
		if invalidation_row.is_empty():
			return
		action_invalidation_rows.append(invalidation_row)

	var generated_large_metrics: Dictionary = await _assert_generated_large_reentry_fast()
	if generated_large_metrics.is_empty():
		return

	OS.set_environment("HEROES_PROFILE_LOG", previous_general)
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"scenario_id": session.scenario_id,
		"first_town": first_id,
		"second_town": second_id,
		"action_invalidation_rows": action_invalidation_rows,
		"economy_context_invalidation": context_invalidation_row,
		"management_tab_full_state_reuse": tab_reuse,
		"same_town_minimal_full_entry_count": int(full_again_snapshot.get("entry_count", 0)),
		"generated_large_reentry": generated_large_metrics,
	})])
	ContentService.clear_generated_scenario_drafts()
	get_tree().quit(0)

func _assert_management_tab_full_state_reuse(shell: Node, session, expected_placement_id: String) -> Dictionary:
	var management_tabs := shell.get_node_or_null("%ManagementTabs") as TabContainer
	if management_tabs == null or management_tabs.get_tab_count() != 5:
		_finish_fail("Town full-state reuse requires the exact five live management tabs.")
		return {}
	var authority_before := _authority_snapshot(session, shell)
	authority_before.erase("focus_owner")
	var rows := []
	var maximum_refresh_ms := 0.0
	for tab in [1, 2, 3, 4, 0]:
		SaveService.validation_clear_general_profile_log()
		management_tabs.current_tab = tab
		await get_tree().process_frame
		await get_tree().process_frame
		var refresh_records := _town_refresh_records(SaveService.validation_general_profile_log_last_records(10))
		if refresh_records.size() != 1:
			_finish_fail("Management-tab change did not emit exactly one focused Town refresh.", {"tab": tab, "records": refresh_records})
			return {}
		var record: Dictionary = refresh_records[0]
		if not _assert_cache_hit_refresh_is_light(record, "management tab %d full-state reuse" % tab):
			return {}
		var metadata: Dictionary = record.get("metadata", {}) if record.get("metadata", {}) is Dictionary else {}
		var cache_result: Dictionary = metadata.get("town_entity_cache", {}) if metadata.get("town_entity_cache", {}) is Dictionary else {}
		var signature := String(cache_result.get("signature", ""))
		if String(cache_result.get("cache_key", "")) != "%s|full" % expected_placement_id or bool(cache_result.get("minimal", true)) or signature.find("|mode:full|") < 0 or signature.find("|tab:") >= 0:
			_finish_fail("Management-tab refresh did not reuse the tab-independent full entity state.", {"tab": tab, "record": record})
			return {}
		OverworldRules.begin_normalized_read_scope(session)
		TownRules.begin_read_scope(session)
		var town := TownRules.get_active_town(session)
		var cached_state: Dictionary = shell.call("_active_town_entity_view_state", town, false)
		var direct_state: Dictionary = shell.call("_build_active_town_entity_view_state", false)
		shell.call("_refresh_active_town_dynamic_view_state", direct_state, town, false)
		TownRules.end_read_scope(session)
		OverworldRules.end_normalized_read_scope(session)
		if cached_state != direct_state:
			_finish_fail("Cached full Town entity state diverged from the fresh direct-plus-dynamic materializer.", {
				"tab": tab,
				"first_difference": _first_exact_difference(direct_state, cached_state),
			})
			return {}
		var total_ms := float(record.get("total_ms", 0.0))
		maximum_refresh_ms = maxf(maximum_refresh_ms, total_ms)
		rows.append({
			"tab": tab,
			"total_ms": total_ms,
			"cache_build_ms": float(record.get("buckets_ms", {}).get("town_entity_cache_build", -1.0)),
			"cache_dynamic_ms": float(record.get("buckets_ms", {}).get("town_entity_cache_dynamic", -1.0)),
			"whole_state_exact": true,
		})
	var authority_after := _authority_snapshot(session, shell)
	authority_after.erase("focus_owner")
	if authority_after != authority_before:
		_finish_fail("Management-tab full-state reuse changed session, town, save, or route authority.", {"before": authority_before, "after": authority_after})
		return {}
	if maximum_refresh_ms >= 150.0:
		_finish_fail("Management-tab full-state reuse did not remove the profiled 297-320 ms hitch.", {"maximum_refresh_ms": maximum_refresh_ms, "rows": rows})
		return {}
	return {
		"rows": rows,
		"maximum_refresh_ms": maximum_refresh_ms,
		"full_cache_build_count": 1,
		"tab_cache_hit_count": rows.size(),
		"whole_state_exact": true,
	}

func _generated_large_session():
	var setup := ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(
		ScenarioSelectRulesScript.build_random_map_player_config(
			GENERATED_LARGE_SEED,
			"translated_rmg_template_042_v1",
			"translated_rmg_profile_042_v1",
			4,
			"land",
			false,
			"homm3_large"
		),
		"normal",
		ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY
	)
	if not bool(setup.get("ok", false)):
		push_error("Generated Large setup failed: %s" % JSON.stringify(setup))
		return null
	return ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup)

func _assert_generated_large_reentry_fast() -> Dictionary:
	ContentService.clear_generated_scenario_drafts()
	SessionState.reset_session()
	SaveService.validation_clear_general_profile_log()
	var large_session = _generated_large_session()
	if large_session == null or large_session.scenario_id == "":
		_finish_fail("Could not create generated Large session for town cache regression.")
		return {}
	OverworldRules.normalize_overworld_state(large_session)
	var town := _first_player_town(large_session)
	if town.is_empty():
		_finish_fail("Generated Large session had no player town.")
		return {}
	_move_active_hero_to_town(large_session, town)
	var placement_id := String(town.get("placement_id", ""))
	var visit_result: Dictionary = OverworldRules.set_active_town_visit(large_session, placement_id)
	if not bool(visit_result.get("ok", false)):
		_finish_fail("Could not prepare generated Large active town visit.", visit_result)
		return {}
	SessionState.set_active_session(large_session)
	large_session = SessionState.ensure_active_session()
	AppRouter.validation_prepare_town_handoff_without_scene_change()

	var shell = load("res://scenes/town/TownShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	var entry_snapshot: Dictionary = shell.call("validation_town_entity_cache_snapshot")
	if not _assert_snapshot(entry_snapshot, placement_id, false, true, "generated Large initial town entry"):
		return {}
	if _has_save_surface_build_record(SaveService.validation_general_profile_log_last_records(40)):
		_finish_fail("Generated Large ordinary town entry built the expensive save surface.", SaveService.validation_general_profile_log_last_records(40))
		return {}

	SaveService.validation_clear_general_profile_log()
	shell.queue_free()
	await get_tree().process_frame
	AppRouter.validation_prepare_overworld_handoff_without_scene_change()
	_simulate_overworld_resource_movement(large_session, town)
	OverworldRules.set_active_town_visit(large_session, placement_id)
	AppRouter.validation_prepare_town_handoff_without_scene_change()
	var reentry_shell = load("res://scenes/town/TownShell.tscn").instantiate()
	add_child(reentry_shell)
	await get_tree().process_frame
	await get_tree().process_frame
	var reentry_snapshot: Dictionary = reentry_shell.call("validation_town_entity_cache_snapshot")
	if not _assert_snapshot(reentry_snapshot, placement_id, true, true, "generated Large same-town re-entry"):
		return {}
	var records: Array = SaveService.validation_general_profile_log_last_records(40)
	if _has_save_surface_build_record(records):
		_finish_fail("Generated Large ordinary same-town re-entry built the expensive save surface.", records)
		return {}
	if _has_town_refresh_cache_miss_record(records):
		_finish_fail("Generated Large ordinary same-town re-entry triggered a full town cache rebuild.", records)
		return {}
	var ready_record := _find_town_ready_record(records)
	if ready_record.is_empty():
		_finish_fail("Generated Large same-town re-entry did not expose town_ready.", records)
		return {}
	if not _assert_town_ready_reentry_is_light(ready_record):
		return {}
	var refresh_record := _find_town_refresh_record(records, true)
	if refresh_record.is_empty():
		_finish_fail("Generated Large same-town re-entry did not expose a cache-hit refresh.", records)
		return {}
	if not _assert_cache_hit_refresh_is_light(refresh_record, "generated Large same-town cache-hit re-entry refresh"):
		return {}
	_warm_save_summary_cache()
	var authority_before_ledger := _authority_snapshot(large_session, reentry_shell)
	var ledger_snapshot: Dictionary = reentry_shell.call("validation_resource_ledger_snapshot")
	if not _assert_economy_ledger_parity(reentry_shell, ledger_snapshot, "generated Large cache-hit resource refresh"):
		return {}
	if not _assert_departure_parity(reentry_shell, large_session, "generated Large cache-hit resource refresh"):
		return {}
	var authority_after_ledger := _authority_snapshot(large_session, reentry_shell)
	if not _assert_exact_authority(authority_after_ledger, authority_before_ledger, "generated Large cached/direct ledger comparison"):
		return {}
	reentry_shell.queue_free()
	await get_tree().process_frame
	var refresh_buckets: Dictionary = refresh_record.get("buckets_ms", {}) if refresh_record.get("buckets_ms", {}) is Dictionary else {}
	var ready_buckets: Dictionary = ready_record.get("buckets_ms", {}) if ready_record.get("buckets_ms", {}) is Dictionary else {}
	ContentService.clear_generated_scenario_drafts()
	return {
		"seed": GENERATED_LARGE_SEED,
		"scenario_id": large_session.scenario_id,
		"town_placement_id": placement_id,
		"town_ready_total_ms": float(ready_record.get("total_ms", 0.0)),
		"town_ready_first_refresh_ms": float(ready_buckets.get("first_refresh", 0.0)),
		"town_refresh_total_ms": float(refresh_record.get("total_ms", 0.0)),
		"town_refresh_save_surface_ms": float(refresh_buckets.get("save_surface", 0.0)),
		"town_refresh_cache_build_ms": float(refresh_buckets.get("town_entity_cache_build", 0.0)),
		"town_refresh_stage_ms": float(refresh_buckets.get("stage", 0.0)),
		"rendered_economy_readability_surface": ledger_snapshot.get("rendered_economy_readability_surface", {}),
		"direct_economy_readability_surface": ledger_snapshot.get("economy_readability_surface", {}),
	}

func _assert_snapshot(snapshot: Dictionary, expected_placement_id: String, expected_hit: bool, expected_save_skip: bool, label: String) -> bool:
	if String(snapshot.get("active_placement_id", "")) != expected_placement_id:
		_finish_fail("%s used the wrong active town." % label, snapshot)
		return false
	if bool(snapshot.get("last_cache_hit", false)) != expected_hit:
		_finish_fail("%s had the wrong cache hit/miss state." % label, snapshot)
		return false
	if not bool(snapshot.get("active_cached", false)):
		_finish_fail("%s did not leave the active town cached." % label, snapshot)
		return false
	if bool(snapshot.get("save_surface_skipped_hidden", false)) != expected_save_skip:
		_finish_fail("%s had the wrong save-surface skip state." % label, snapshot)
		return false
	var cache_result: Dictionary = snapshot.get("last_cache_result", {}) if snapshot.get("last_cache_result", {}) is Dictionary else {}
	var signature := String(cache_result.get("signature", ""))
	if signature.length() > 4096 or signature.find("{") >= 0 or signature.find("player_heroes") >= 0 or signature.find("last_action_recap") >= 0:
		_finish_fail("%s used a large JSON-style town cache signature." % label, cache_result)
		return false
	for volatile_token in ["resources:", "active_hero:", "move=", "pos=", "stationed:", "recap:"]:
		if signature.find(String(volatile_token)) >= 0:
			_finish_fail("%s included volatile overworld state in the expensive town cache signature." % label, cache_result)
			return false
	if float(cache_result.get("signature_ms", 99999.0)) > 50.0:
		_finish_fail("%s spent too long constructing the town cache signature." % label, cache_result)
		return false
	return true

func _first_player_town(session) -> Dictionary:
	for candidate in session.overworld.get("towns", []):
		if candidate is Dictionary and String(candidate.get("owner", "")) == "player":
			return candidate
	return {}

func _ensure_second_player_town(session, first_town: Dictionary) -> Dictionary:
	var towns: Array = session.overworld.get("towns", []) if session.overworld.get("towns", []) is Array else []
	for town_value in towns:
		if town_value is Dictionary and String(town_value.get("owner", "")) == "player" and String(town_value.get("placement_id", "")) != String(first_town.get("placement_id", "")):
			return town_value
	var second := first_town.duplicate(true)
	second["placement_id"] = "%s_cache_peer" % String(first_town.get("placement_id", "town"))
	second["x"] = int(first_town.get("x", 0)) + 1
	second["y"] = int(first_town.get("y", 0))
	var built_buildings: Array = first_town.get("built_buildings", []) if first_town.get("built_buildings", []) is Array else []
	var available_recruits: Dictionary = first_town.get("available_recruits", {}) if first_town.get("available_recruits", {}) is Dictionary else {}
	second["built_buildings"] = built_buildings.duplicate(true)
	second["available_recruits"] = available_recruits.duplicate(true)
	towns.append(second)
	session.overworld["towns"] = towns
	return second

func _give_resources(session) -> void:
	session.overworld["resources"] = {
		"gold": 99999,
		"wood": 999,
		"ore": 999,
	}

func _move_active_hero_to_town(session, town: Dictionary) -> void:
	var position := {"x": int(town.get("x", 0)), "y": int(town.get("y", 0))}
	_set_active_hero_position(session, position)

func _simulate_overworld_resource_movement(session, town: Dictionary) -> void:
	var resources: Dictionary = session.overworld.get("resources", {}) if session.overworld.get("resources", {}) is Dictionary else {}
	resources["gold"] = int(resources.get("gold", 0)) + 150
	resources["wood"] = int(resources.get("wood", 0)) + 2
	resources["ore"] = int(resources.get("ore", 0)) + 1
	session.overworld["resources"] = resources
	var movement: Dictionary = session.overworld.get("movement", {}) if session.overworld.get("movement", {}) is Dictionary else {}
	movement["current"] = max(0, int(movement.get("current", movement.get("max", 14))) - 2)
	session.overworld["movement"] = movement
	var position := {"x": int(town.get("x", 0)) + 2, "y": int(town.get("y", 0))}
	_set_active_hero_position(session, position)

func _set_active_hero_position(session, position: Dictionary) -> void:
	session.overworld["hero_position"] = position.duplicate(true)
	var active_hero = session.overworld.get("hero", {})
	if active_hero is Dictionary:
		active_hero["position"] = position.duplicate(true)
		session.overworld["hero"] = active_hero
	var heroes = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		var hero = heroes[index]
		if hero is Dictionary and String(hero.get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			hero["position"] = position.duplicate(true)
			heroes[index] = hero
	session.overworld["player_heroes"] = heroes

func _first_enabled_action(shell: Node, lane: String) -> String:
	var catalog: Dictionary = shell.call("validation_action_catalog")
	var actions: Array = catalog.get(lane, []) if catalog.get(lane, []) is Array else []
	for action in actions:
		if action is Dictionary and not bool(action.get("disabled", false)):
			return String(action.get("id", ""))
	return ""

func _assert_economy_context_invalidates_once_then_hits_fast(
	shell: Node,
	session,
	expected_placement_id: String,
	preserved_placement_id: String
) -> Dictionary:
	var encounter_id := _first_unresolved_encounter_id(session)
	if encounter_id == "":
		_finish_fail("Town economy-context cache coverage could not find an unresolved encounter.", session.overworld.get("encounters", []))
		return {}
	var stable_focus := shell.get_node_or_null("%Leave")
	if not (stable_focus is Control):
		_finish_fail("Town economy-context cache coverage could not find the stable Leave focus control.")
		return {}
	stable_focus.grab_focus()
	await get_tree().process_frame
	_warm_save_summary_cache()
	var save_before := _save_authority_snapshot()
	var route_before := _route_authority_snapshot(shell, session)
	var focus_before := _focus_owner_name()
	var resolved: Array = session.overworld.get("resolved_encounters", []) if session.overworld.get("resolved_encounters", []) is Array else []
	resolved = resolved.duplicate(true)
	resolved.append(encounter_id)
	session.overworld["resolved_encounters"] = resolved
	var post_mutation_authority := _authority_snapshot(session, shell)
	SaveService.validation_clear_general_profile_log()
	var miss_snapshot: Dictionary = shell.call("validation_force_refresh")
	await get_tree().process_frame
	if not _assert_snapshot(miss_snapshot, expected_placement_id, false, true, "after economy-context encounter resolution"):
		return {}
	var cached_placements: Array = miss_snapshot.get("cached_placements", []) if miss_snapshot.get("cached_placements", []) is Array else []
	if not cached_placements.has(preserved_placement_id):
		_finish_fail("Economy-context invalidation removed a non-active town cache entry.", miss_snapshot)
		return {}
	var miss_records := _town_refresh_records(SaveService.validation_general_profile_log_last_records(20))
	if miss_records.size() != 1 or bool((miss_records[0] as Dictionary).get("metadata", {}).get("town_entity_cache_hit", false)):
		_finish_fail("Economy-context mutation did not produce exactly one cache-miss refresh.", miss_records)
		return {}
	if _save_authority_snapshot() != save_before or _route_authority_snapshot(shell, session) != route_before or _focus_owner_name() != focus_before:
		_finish_fail("Economy-context cache miss changed save, route, or focus authority.", {
			"save_before": save_before,
			"save_after": _save_authority_snapshot(),
			"route_before": route_before,
			"route_after": _route_authority_snapshot(shell, session),
			"focus_before": focus_before,
			"focus_after": _focus_owner_name(),
		})
		return {}
	SaveService.validation_clear_general_profile_log()
	var hit_snapshot: Dictionary = shell.call("validation_force_refresh")
	await get_tree().process_frame
	if not _assert_snapshot(hit_snapshot, expected_placement_id, true, true, "after economy-context cache rebuild"):
		return {}
	var hit_records := _town_refresh_records(SaveService.validation_general_profile_log_last_records(20))
	if hit_records.size() != 1 or not _assert_cache_hit_refresh_is_light(hit_records[0], "economy-context follow-up cache hit"):
		return {}
	var ledger_snapshot: Dictionary = shell.call("validation_resource_ledger_snapshot")
	if not _assert_economy_ledger_parity(shell, ledger_snapshot, "economy-context follow-up cache hit"):
		return {}
	if not _assert_exact_authority(_authority_snapshot(session, shell), post_mutation_authority, "economy-context follow-up cache hit"):
		return {}
	return {
		"resolved_encounter_id": encounter_id,
		"miss_refresh_count": miss_records.size(),
		"hit_refresh_count": hit_records.size(),
		"hit_total_ms": float((hit_records[0] as Dictionary).get("total_ms", 0.0)),
		"signature": String((hit_snapshot.get("last_cache_result", {}) as Dictionary).get("signature", "")),
	}

func _first_unresolved_encounter_id(session) -> String:
	var resolved: Array = session.overworld.get("resolved_encounters", []) if session.overworld.get("resolved_encounters", []) is Array else []
	for encounter_value in session.overworld.get("encounters", []):
		if not (encounter_value is Dictionary):
			continue
		var encounter_id := String(encounter_value.get("placement_id", encounter_value.get("id", encounter_value.get("encounter_id", ""))))
		if encounter_id != "" and not resolved.has(encounter_id):
			return encounter_id
	return ""

func _assert_action_invalidates_once_then_hits_fast(
	shell: Node,
	session,
	lane: String,
	action_id: String,
	expected_placement_id: String,
	preserved_placement_id: String
) -> Dictionary:
	var stable_focus := shell.get_node_or_null("%Leave")
	if not (stable_focus is Control):
		_finish_fail("Town cache action coverage could not find the stable Leave focus control.", {"lane": lane})
		return {}
	stable_focus.grab_focus()
	await get_tree().process_frame
	_warm_save_summary_cache()
	var before_action := _action_domain_snapshot(session)
	var save_before := _save_authority_snapshot()
	var route_before := _route_authority_snapshot(shell, session)
	SaveService.validation_clear_general_profile_log()
	var action_result: Dictionary = shell.call("validation_perform_town_action", action_id)
	await get_tree().process_frame
	if not bool(action_result.get("ok", false)) or not bool(action_result.get("state_changed", false)):
		_finish_fail("Real %s action did not change its authoritative domain." % lane, action_result)
		return {}
	var after_action := _action_domain_snapshot(session)
	if not _assert_expected_action_domain_change(lane, before_action, after_action):
		return {}
	var miss_snapshot: Dictionary = shell.call("validation_town_entity_cache_snapshot")
	if not _assert_snapshot(miss_snapshot, expected_placement_id, false, true, "after real %s action" % lane):
		return {}
	var cached_placements: Array = miss_snapshot.get("cached_placements", []) if miss_snapshot.get("cached_placements", []) is Array else []
	if not cached_placements.has(preserved_placement_id):
		_finish_fail("Real %s action invalidated a non-active town cache entry." % lane, miss_snapshot)
		return {}
	var miss_records := _town_refresh_records(SaveService.validation_general_profile_log_last_records(20))
	if miss_records.size() != 1 or bool((miss_records[0] as Dictionary).get("metadata", {}).get("town_entity_cache_hit", false)):
		_finish_fail("Real %s action did not produce exactly one cache-miss refresh." % lane, miss_records)
		return {}
	if _save_authority_snapshot() != save_before:
		_finish_fail("Real %s action changed save bytes or the SaveService summary cache." % lane, {
			"before": save_before,
			"after": _save_authority_snapshot(),
		})
		return {}
	if _route_authority_snapshot(shell, session) != route_before:
		_finish_fail("Real %s action changed route authority." % lane, {
			"before": route_before,
			"after": _route_authority_snapshot(shell, session),
		})
		return {}
	if not await _await_town_action_focus_release(shell, lane):
		return {}

	var post_action_authority := _authority_snapshot(session, shell)
	SaveService.validation_clear_general_profile_log()
	var hit_snapshot: Dictionary = shell.call("validation_force_refresh")
	await get_tree().process_frame
	if not _assert_snapshot(hit_snapshot, expected_placement_id, true, true, "cache hit after real %s action" % lane):
		return {}
	var hit_records := _town_refresh_records(SaveService.validation_general_profile_log_last_records(20))
	if hit_records.size() != 1:
		_finish_fail("Post-%s refresh did not emit exactly one cache-hit profile record." % lane, hit_records)
		return {}
	var hit_record: Dictionary = hit_records[0]
	if not _assert_cache_hit_refresh_is_light(hit_record, "post-%s cache-hit refresh" % lane):
		return {}
	var ledger_snapshot: Dictionary = shell.call("validation_resource_ledger_snapshot")
	if not _assert_economy_ledger_parity(shell, ledger_snapshot, "post-%s cache-hit refresh" % lane):
		return {}
	if not _assert_exact_authority(_authority_snapshot(session, shell), post_action_authority, "post-%s cache-hit refresh" % lane):
		return {}
	return {
		"lane": lane,
		"action_id": action_id,
		"miss_refresh_count": miss_records.size(),
		"hit_refresh_count": hit_records.size(),
		"hit_total_ms": float(hit_record.get("total_ms", 0.0)),
		"hit_dynamic_ms": float((hit_snapshot.get("last_cache_result", {}) as Dictionary).get("dynamic_ms", 0.0)),
	}

func _await_town_action_focus_release(shell: Node, lane: String) -> bool:
	var stage = shell.get_node_or_null("%TownStage")
	var blocker := shell.get_node_or_null("%TownActionInputBlocker") as Control
	if stage == null or blocker == null or not stage.has_method("validation_town_action_presentation_snapshot"):
		_finish_fail("Real %s action could not observe the authored Town completion presentation." % lane)
		return false
	var deadline_msec := Time.get_ticks_msec() + 2000
	while bool(stage.validation_town_action_presentation_snapshot().get("active", false)) and Time.get_ticks_msec() < deadline_msec:
		await get_tree().process_frame
	await get_tree().process_frame
	var presentation: Dictionary = stage.validation_town_action_presentation_snapshot()
	var focus_owner := get_viewport().gui_get_focus_owner()
	if (
		bool(presentation.get("active", true))
		or blocker.visible
		or focus_owner == null
		or focus_owner == blocker
		or not shell.is_ancestor_of(focus_owner)
	):
		_finish_fail("Real %s action did not release its completion presentation back to Town focus." % lane, {
			"presentation": presentation,
			"blocker_visible": blocker.visible,
			"focus_owner": String(focus_owner.name) if focus_owner != null else "",
		})
		return false
	return true

func _assert_expected_action_domain_change(lane: String, before: Dictionary, after: Dictionary) -> bool:
	var changed := false
	match lane:
		"build":
			changed = before.get("built_buildings", []) != after.get("built_buildings", []) and before.get("resources", {}) != after.get("resources", {})
		"recruit":
			changed = before.get("available_recruits", {}) != after.get("available_recruits", {}) and before.get("army", {}) != after.get("army", {})
		"market":
			changed = before.get("market_usage", {}) != after.get("market_usage", {}) and before.get("resources", {}) != after.get("resources", {})
	if not changed:
		_finish_fail("Real %s action did not change the expected live town domain." % lane, {"before": before, "after": after})
	return changed

func _action_domain_snapshot(session) -> Dictionary:
	var town := TownRules.get_active_town(session)
	return {
		"built_buildings": (town.get("built_buildings", []) as Array).duplicate(true) if town.get("built_buildings", []) is Array else [],
		"available_recruits": (town.get("available_recruits", {}) as Dictionary).duplicate(true) if town.get("available_recruits", {}) is Dictionary else {},
		"market_usage": (town.get("market_usage", {}) as Dictionary).duplicate(true) if town.get("market_usage", {}) is Dictionary else {},
		"resources": (session.overworld.get("resources", {}) as Dictionary).duplicate(true) if session.overworld.get("resources", {}) is Dictionary else {},
		"army": (session.overworld.get("army", {}) as Dictionary).duplicate(true) if session.overworld.get("army", {}) is Dictionary else {},
	}

func _assert_economy_ledger_parity(shell: Node, snapshot: Dictionary, label: String) -> bool:
	var rendered: Dictionary = snapshot.get("rendered_economy_readability_surface", {}) if snapshot.get("rendered_economy_readability_surface", {}) is Dictionary else {}
	var direct: Dictionary = snapshot.get("economy_readability_surface", {}) if snapshot.get("economy_readability_surface", {}) is Dictionary else {}
	if rendered.is_empty() or rendered != direct:
		_finish_fail("%s rendered cached economy ledger diverged from the direct rules control." % label, {"rendered": rendered, "direct": direct})
		return false
	if String(snapshot.get("resources_visible_text", "")) != String(snapshot.get("resources_text", "")):
		_finish_fail("%s rendered stale stockpile text." % label, snapshot)
		return false
	var full_ledger := String(snapshot.get("resources_full_ledger_text", ""))
	var tooltip := String(snapshot.get("resources_tooltip_text", ""))
	if full_ledger == "" or tooltip.find(full_ledger) < 0:
		_finish_fail("%s rendered tooltip omitted the exact full stockpile ledger." % label, snapshot)
		return false
	var direct_catalog: Dictionary = shell.call("validation_action_catalog")
	var readiness := _direct_economy_action_readiness(direct_catalog)
	if not _assert_rendered_action_copy_parity(
		snapshot.get("rendered_build_actions", []),
		direct_catalog.get("build", []),
		"build",
		label
	):
		return false
	if not _assert_rendered_action_copy_parity(
		snapshot.get("rendered_recruit_actions", []),
		direct_catalog.get("recruit", []),
		"recruit",
		label
	):
		return false
	for key in readiness.keys():
		if int(direct.get(String(key), -1)) != int(readiness.get(key, -2)):
			_finish_fail("%s cached economy action readiness diverged at %s." % [label, key], {"surface": direct, "control": readiness})
			return false
	for required_key in [
		"tooltip_text",
		"daily_town_income",
		"daily_field_income",
		"field_site_count",
		"build_bottleneck_resource_id",
		"player_readable_next_build",
		"player_readable_build_bottleneck",
		"player_readable_next_muster",
	]:
		if not direct.has(required_key):
			_finish_fail("%s economy ledger omitted %s." % [label, required_key], direct)
			return false
	return true

func _assert_departure_parity(shell: Node, session, label: String) -> bool:
	var direct: Dictionary = TownRules.town_departure_confirmation(session)
	if direct.is_empty():
		_finish_fail("%s direct departure control was empty." % label)
		return false
	var leave_button := shell.get_node_or_null("%Leave")
	if not (leave_button is Button):
		_finish_fail("%s could not inspect the rendered departure button." % label)
		return false
	if leave_button.text != String(direct.get("button_label", "")):
		_finish_fail("%s rendered departure button copy diverged from the direct control." % label, {"rendered": leave_button.text, "direct": direct})
		return false
	if leave_button.tooltip_text != String(direct.get("tooltip_text", "")):
		_finish_fail("%s rendered departure tooltip diverged from the direct control." % label, {"rendered": leave_button.tooltip_text, "direct": direct})
		return false
	for key in [
		"ready_response_action_count",
		"affected",
		"why_it_matters",
		"next_step",
		"movement_current",
		"movement_max",
	]:
		if not direct.has(key):
			_finish_fail("%s direct departure control omitted %s." % [label, key], direct)
			return false
	return true

func _assert_rendered_action_copy_parity(rendered_value: Variant, direct_value: Variant, lane: String, label: String) -> bool:
	if not (rendered_value is Array) or rendered_value.is_empty():
		return true
	var direct_by_id := {}
	if direct_value is Array:
		for action_value in direct_value:
			if action_value is Dictionary:
				direct_by_id[String(action_value.get("id", ""))] = action_value
	var fields := [
		"summary",
		"recommendation_line",
		"affordability_label",
		"button_label",
		"disabled",
		"disabled_reason",
	]
	if lane == "build":
		fields.append_array(["ledger_line", "direct_affordable", "market_coverable", "shortfall_summary"])
	else:
		fields.append_array(["available_count", "direct_affordable_count", "market_affordable_count", "shortfall_summary"])
	for rendered_action_value in rendered_value:
		if not (rendered_action_value is Dictionary):
			continue
		var action_id := String(rendered_action_value.get("id", ""))
		var direct_action: Dictionary = direct_by_id.get(action_id, {}) if direct_by_id.get(action_id, {}) is Dictionary else {}
		if direct_action.is_empty():
			_finish_fail("%s rendered %s action %s was absent from the direct control." % [label, lane, action_id], rendered_action_value)
			return false
		for field in fields:
			if rendered_action_value.get(String(field)) != direct_action.get(String(field)):
				_finish_fail("%s rendered %s action %s diverged at %s." % [label, lane, action_id, field], {
					"rendered": rendered_action_value,
					"direct": direct_action,
				})
				return false
	return true

func _direct_economy_action_readiness(catalog: Dictionary) -> Dictionary:
	var summary := {
		"build_ready_order_count": 0,
		"build_market_order_count": 0,
		"build_blocked_order_count": 0,
		"muster_ready_unit_count": 0,
		"muster_market_unit_count": 0,
		"muster_blocked_unit_count": 0,
	}
	var build_actions: Array = catalog.get("build", []) if catalog.get("build", []) is Array else []
	for action_value in build_actions:
		if not (action_value is Dictionary):
			continue
		if bool(action_value.get("direct_affordable", false)):
			summary["build_ready_order_count"] += 1
		elif bool(action_value.get("market_coverable", false)):
			summary["build_market_order_count"] += 1
		else:
			summary["build_blocked_order_count"] += 1
	var recruit_actions: Array = catalog.get("recruit", []) if catalog.get("recruit", []) is Array else []
	for action_value in recruit_actions:
		if not (action_value is Dictionary):
			continue
		var available: int = max(0, int(action_value.get("available_count", 0)))
		var direct_count: int = max(0, int(action_value.get("direct_affordable_count", 0)))
		var market_count: int = max(0, int(action_value.get("market_affordable_count", 0)))
		if direct_count > 0:
			summary["muster_ready_unit_count"] += direct_count
		elif market_count > 0:
			summary["muster_market_unit_count"] += market_count
		else:
			summary["muster_blocked_unit_count"] += available
	return summary

func _authority_snapshot(session, shell: Node) -> Dictionary:
	return {
		"session": JSON.stringify(session.to_dict()),
		"town": JSON.stringify(TownRules.get_active_town(session)),
		"resources": JSON.stringify(session.overworld.get("resources", {})),
		"market_usage": JSON.stringify(TownRules.get_active_town(session).get("market_usage", {})),
		"save": _save_authority_snapshot(),
		"route": _route_authority_snapshot(shell, session),
		"focus_owner": _focus_owner_name(),
	}

func _assert_exact_authority(actual: Dictionary, expected: Dictionary, label: String) -> bool:
	if actual != expected:
		_finish_fail("%s changed session, town, resource, market, save, route, or focus authority." % label, {"expected": expected, "actual": actual})
		return false
	return true

func _save_authority_snapshot() -> Dictionary:
	var files := {}
	for path in [
		"user://saves/autosave.json",
		"user://saves/slot1.json",
		"user://saves/slot2.json",
		"user://saves/slot3.json",
		"user://saves/campaign_progression.json",
	]:
		files[path] = {
			"exists": FileAccess.file_exists(path),
			"size": FileAccess.get_size(path) if FileAccess.file_exists(path) else -1,
			"sha256": FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "",
		}
	return {
		"files": files,
		"summary_cache": SaveService.validation_summary_cache_snapshot(),
	}

func _warm_save_summary_cache() -> void:
	SaveService.inspect_autosave()
	for slot in [1, 2, 3]:
		SaveService.inspect_manual_slot(slot)

func _route_authority_snapshot(shell: Node, session) -> Dictionary:
	var current_scene := get_tree().current_scene
	return {
		"current_scene_instance_id": current_scene.get_instance_id() if current_scene != null else 0,
		"shell_inside_tree": shell.is_inside_tree(),
		"shell_scene_path": shell.scene_file_path,
		"scenario_id": session.scenario_id,
		"scenario_status": session.scenario_status,
		"game_state": session.game_state,
		"day": session.day,
	}

func _focus_owner_name() -> String:
	var focus_owner := get_viewport().gui_get_focus_owner()
	return String(focus_owner.name) if focus_owner != null else ""

func _town_refresh_records(records: Array) -> Array:
	var matches := []
	for record in records:
		if record is Dictionary and String(record.get("surface", "")) == "town" and String(record.get("phase", "")) == "refresh":
			matches.append(record)
	return matches

func _has_save_surface_build_record(records: Array) -> bool:
	for record in records:
		if record is Dictionary and String(record.get("surface", "")) == "save" and String(record.get("event", "")) == "build_in_session_save_surface":
			return true
	return false

func _has_town_refresh_cache_miss_record(records: Array) -> bool:
	for record in records:
		if not (record is Dictionary):
			continue
		if String(record.get("surface", "")) != "town" or String(record.get("phase", "")) != "refresh":
			continue
		var buckets: Dictionary = record.get("buckets_ms", {}) if record.get("buckets_ms", {}) is Dictionary else {}
		if float(buckets.get("town_entity_cache_miss", 0.0)) >= 1.0 or float(buckets.get("town_entity_cache_build", 0.0)) > 0.001:
			return true
	return false

func _find_town_refresh_record(records: Array, hit: bool) -> Dictionary:
	for record in records:
		if not (record is Dictionary):
			continue
		if String(record.get("surface", "")) != "town" or String(record.get("phase", "")) != "refresh":
			continue
		var metadata: Dictionary = record.get("metadata", {}) if record.get("metadata", {}) is Dictionary else {}
		if bool(metadata.get("town_entity_cache_hit", false)) == hit:
			return record
	return {}

func _find_town_ready_record(records: Array) -> Dictionary:
	for record in records:
		if record is Dictionary and String(record.get("surface", "")) == "town" and String(record.get("phase", "")) == "entry" and String(record.get("event", "")) == "town_ready":
			return record
	return {}

func _assert_cache_hit_refresh_is_light(record: Dictionary, label: String) -> bool:
	var buckets: Dictionary = record.get("buckets_ms", {}) if record.get("buckets_ms", {}) is Dictionary else {}
	if float(buckets.get("town_entity_cache_hit", 0.0)) < 1.0:
		_finish_fail("%s was not a cache-hit refresh." % label, record)
		return false
	if float(buckets.get("town_entity_cache_build", 99999.0)) > 0.001:
		_finish_fail("%s rebuilt the town entity cache." % label, buckets)
		return false
	if float(buckets.get("stage", 99999.0)) > 50.0:
		_finish_fail("%s still spent too long refreshing the town stage." % label, buckets)
		return false
	if float(buckets.get("save_surface", 99999.0)) > 50.0:
		_finish_fail("%s still spent too long refreshing hidden save controls." % label, buckets)
		return false
	if float(record.get("total_ms", 99999.0)) > 1000.0:
		_finish_fail("%s exceeded the sub-1s cache-hit refresh target." % label, record)
		return false
	return true

func _assert_town_ready_reentry_is_light(record: Dictionary) -> bool:
	var buckets: Dictionary = record.get("buckets_ms", {}) if record.get("buckets_ms", {}) is Dictionary else {}
	if float(buckets.get("normalize_overworld", 99999.0)) > 50.0:
		_finish_fail("Same-town re-entry normalized the whole overworld.", buckets)
		return false
	if float(buckets.get("first_refresh", 99999.0)) > 1000.0:
		_finish_fail("Same-town re-entry first refresh exceeded the sub-1s target.", buckets)
		return false
	var metadata: Dictionary = record.get("metadata", {}) if record.get("metadata", {}) is Dictionary else {}
	if not bool(metadata.get("town_entity_cache_hit", false)):
		_finish_fail("Same-town re-entry town_ready did not reuse the town entity cache.", record)
		return false
	return true

func _first_exact_difference(expected: Variant, actual: Variant, path: String = "$") -> Dictionary:
	if typeof(expected) != typeof(actual):
		return {"path": path, "expected_type": type_string(typeof(expected)), "actual_type": type_string(typeof(actual))}
	if expected is Dictionary:
		var expected_dictionary: Dictionary = expected
		var actual_dictionary: Dictionary = actual
		var expected_keys: Array = expected_dictionary.keys()
		expected_keys.sort()
		var actual_keys: Array = actual_dictionary.keys()
		actual_keys.sort()
		if expected_keys != actual_keys:
			return {"path": path, "expected_keys": expected_keys, "actual_keys": actual_keys}
		for key in expected_keys:
			var nested: Dictionary = _first_exact_difference(expected_dictionary.get(key), actual_dictionary.get(key), "%s.%s" % [path, key])
			if not nested.is_empty():
				return nested
		return {}
	if expected is Array:
		var expected_array: Array = expected
		var actual_array: Array = actual
		if expected_array.size() != actual_array.size():
			return {"path": path, "expected_size": expected_array.size(), "actual_size": actual_array.size()}
		for index in range(expected_array.size()):
			var nested: Dictionary = _first_exact_difference(expected_array[index], actual_array[index], "%s[%d]" % [path, index])
			if not nested.is_empty():
				return nested
		return {}
	if expected != actual:
		return {"path": path, "expected": expected, "actual": actual}
	return {}

func _finish_fail(message: String, details: Variant = {}) -> void:
	OS.set_environment("HEROES_PROFILE_LOG", "")
	ContentService.clear_generated_scenario_drafts()
	push_error("%s %s" % [message, JSON.stringify(details)])
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "message": message, "details": details})])
	get_tree().quit(1)
