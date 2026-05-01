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

	var hit_snapshot: Dictionary = shell.call("validation_force_minimal_refresh")
	if not _assert_snapshot(hit_snapshot, first_id, true, true, "same-town current-tab refresh"):
		return
	var full_build_snapshot: Dictionary = shell.call("validation_force_refresh")
	if not _assert_snapshot(full_build_snapshot, first_id, false, true, "same-town explicit full refresh"):
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

	var build_action := _first_enabled_build_action(shell)
	if build_action == "":
		_finish_fail("No enabled build action was available for active-town invalidation coverage.", shell.call("validation_action_catalog"))
		return
	var build_result: Dictionary = shell.call("validation_perform_town_action", build_action)
	if not bool(build_result.get("ok", false)):
		_finish_fail("Build action did not change town state for cache invalidation coverage.", build_result)
		return
	var after_build_snapshot: Dictionary = shell.call("validation_town_entity_cache_snapshot")
	var cached_placements: Array = after_build_snapshot.get("cached_placements", []) if after_build_snapshot.get("cached_placements", []) is Array else []
	if not cached_placements.has(second_id):
		_finish_fail("Build action invalidated a non-active town cache entry.", after_build_snapshot)
		return
	if not _assert_snapshot(after_build_snapshot, first_id, false, true, "after active-town build"):
		return

	var refresh_records: Array = SaveService.validation_general_profile_log_last_records(40)
	var cache_hit_record := _find_town_refresh_record(refresh_records, true)
	if cache_hit_record.is_empty():
		_finish_fail("Town refresh profile records did not expose a cache hit.", refresh_records)
		return
	var cache_miss_record := _find_town_refresh_record(refresh_records, false)
	if cache_miss_record.is_empty():
		_finish_fail("Town refresh profile records did not expose a cache miss.", refresh_records)
		return
	var hit_metadata: Dictionary = cache_hit_record.get("metadata", {}) if cache_hit_record.get("metadata", {}) is Dictionary else {}
	if not bool(hit_metadata.get("save_surface_skipped_hidden", false)):
		_finish_fail("Town refresh profile did not expose hidden save-surface skip.", cache_hit_record)
		return
	var hit_buckets: Dictionary = cache_hit_record.get("buckets_ms", {}) if cache_hit_record.get("buckets_ms", {}) is Dictionary else {}
	if not hit_buckets.has("town_entity_cache_signature") or not hit_buckets.has("town_entity_cache_build"):
		_finish_fail("Town refresh profile did not expose town cache signature/build sub-buckets.", cache_hit_record)
		return
	if float(hit_buckets.get("town_entity_cache_signature", 99999.0)) > 50.0:
		_finish_fail("Town cache signature bucket stayed too expensive.", hit_buckets)
		return

	var generated_large_metrics: Dictionary = await _assert_generated_large_reentry_fast()
	if generated_large_metrics.is_empty():
		return

	OS.set_environment("HEROES_PROFILE_LOG", previous_general)
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"scenario_id": session.scenario_id,
		"first_town": first_id,
		"second_town": second_id,
		"build_action": build_action,
		"same_town_minimal_full_entry_count": int(full_again_snapshot.get("entry_count", 0)),
		"cache_hit_buckets": cache_hit_record.get("buckets_ms", {}),
		"generated_large_reentry": generated_large_metrics,
	})])
	ContentService.clear_generated_scenario_drafts()
	get_tree().quit(0)

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

func _first_enabled_build_action(shell: Node) -> String:
	var catalog: Dictionary = shell.call("validation_action_catalog")
	var actions: Array = catalog.get("build", []) if catalog.get("build", []) is Array else []
	for action in actions:
		if action is Dictionary and not bool(action.get("disabled", false)):
			return String(action.get("id", ""))
	return ""

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

func _finish_fail(message: String, details: Variant = {}) -> void:
	OS.set_environment("HEROES_PROFILE_LOG", "")
	ContentService.clear_generated_scenario_drafts()
	push_error("%s %s" % [message, JSON.stringify(details)])
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "message": message, "details": details})])
	get_tree().quit(1)
