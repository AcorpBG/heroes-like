extends Node

const REPORT_SCHEMA := "active_scenario_town_development_runway_report_v1"
const TARGET_TURNS := 30
const TARGET_TIER_COUNT := 7
const LIVE_STOCKPILE_RESOURCE_IDS := [
	"gold",
	"wood",
	"ore",
	"aetherglass",
	"embergrain",
	"peatwax",
	"verdant_grafts",
	"brass_scrip",
	"memory_salt",
]
const COMMON_MARKET_RESOURCE_IDS := ["wood", "ore"]
const RARE_RESOURCE_IDS := [
	"aetherglass",
	"embergrain",
	"peatwax",
	"verdant_grafts",
	"brass_scrip",
	"memory_salt",
]
const DELAYED_SOURCE_ROUTE_STEPS_PER_DAY := 12
const DELAYED_GUARDED_SOURCE_EXTRA_DAYS := 1
const DELAYED_SOURCE_SAVE_RESUME_SLOT := 2

var _errors := []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var only_scenario := OS.get_environment("ACTIVE_SCENARIO_TOWN_RUNWAY_ONLY")
	var scenario_count := 0
	var town_case_count := 0
	var completed_case_count := 0
	var rare_spend_case_count := 0
	var full_session_case_count := 0
	var delayed_source_replay_case_count := 0
	var delayed_source_replay_completed_count := 0
	var delayed_source_save_resume_case_count := 0
	var delayed_source_save_resume_completed_count := 0
	var recruitment_end_to_end_case_count := 0
	var seven_tier_recruitment_case_count := 0
	var recruited_unit_case_count := 0
	var rows := []
	for scenario_id in ContentService.get_content_ids(ContentService.SCENARIOS_PATH):
		if only_scenario != "" and String(scenario_id) != only_scenario:
			continue
		var scenario := ContentService.get_scenario(String(scenario_id))
		if not _is_active_authored_scenario(scenario):
			continue
		scenario_count += 1
		for authored_town in _player_towns(scenario):
			var row := _run_town_case(String(scenario_id), authored_town)
			rows.append(row)
			town_case_count += 1
			if bool(row.get("completed", false)):
				completed_case_count += 1
			if bool(row.get("rare_spend_observed", false)):
				rare_spend_case_count += 1
			if bool(row.get("full_session_used", false)):
				full_session_case_count += 1
			if bool(row.get("delayed_source_replay_seen", false)):
				delayed_source_replay_case_count += 1
			if bool(row.get("delayed_source_replay_ok", false)):
				delayed_source_replay_completed_count += 1
			if bool(row.get("delayed_source_save_resume_seen", false)):
				delayed_source_save_resume_case_count += 1
			if bool(row.get("delayed_source_save_resume_ok", false)):
				delayed_source_save_resume_completed_count += 1
			if bool(row.get("recruitment_end_to_end_ok", false)):
				recruitment_end_to_end_case_count += 1
			seven_tier_recruitment_case_count += int(row.get("recruitment_case_count", 0))
			recruited_unit_case_count += int(row.get("recruited_unit_case_count", 0))
			if not bool(row.get("ok", false)):
				_errors.append("%s/%s failed: %s" % [
					String(scenario_id),
					String(authored_town.get("placement_id", "")),
					String(row.get("error", "unknown runway failure")),
				])
	var report := {
		"ok": _errors.is_empty(),
		"schema": REPORT_SCHEMA,
		"target_turns": TARGET_TURNS,
		"active_scenario_count": scenario_count,
		"player_town_case_count": town_case_count,
		"completed_case_count": completed_case_count,
		"rare_spend_case_count": rare_spend_case_count,
		"full_session_case_count": full_session_case_count,
		"delayed_source_replay_case_count": delayed_source_replay_case_count,
		"delayed_source_replay_completed_count": delayed_source_replay_completed_count,
		"delayed_source_save_resume_case_count": delayed_source_save_resume_case_count,
		"delayed_source_save_resume_completed_count": delayed_source_save_resume_completed_count,
		"delayed_source_save_resume_slot": DELAYED_SOURCE_SAVE_RESUME_SLOT,
		"delayed_source_route_steps_per_day": DELAYED_SOURCE_ROUTE_STEPS_PER_DAY,
		"delayed_guarded_source_extra_days": DELAYED_GUARDED_SOURCE_EXTRA_DAYS,
		"recruitment_end_to_end_case_count": recruitment_end_to_end_case_count,
		"seven_tier_recruitment_case_count": seven_tier_recruitment_case_count,
		"recruited_unit_case_count": recruited_unit_case_count,
		"live_stockpile_resource_ids": LIVE_STOCKPILE_RESOURCE_IDS,
		"common_market_resource_ids": COMMON_MARKET_RESOURCE_IDS,
		"rare_resource_ids": RARE_RESOURCE_IDS,
		"cases": rows,
		"errors": _errors,
		"caveats": [
			"The report boots active authored scenarios and secures authored economy sources to isolate town development runway from route safety and encounter pacing.",
			"A second replay now delays source ownership by route-derived acquisition days and guarded-source delay before proving the same 30-turn development runway.",
			"The delayed-source replay saves and restores after delayed source acquisition plus rare-resource construction, then continues the development runway from the restored active scenario session.",
			"Construction now runs inside the full scenario session state with authored map, resource nodes, encounters, and enemy states preserved.",
			"Build execution still runs through live OverworldRules.build_in_active_town, and post-build TownRules.get_build_actions proves same-day build actions are blocked.",
			"After development, each full-session player town must expose and recruit through its owning faction seven-tier ladder.",
			"Day advancement uses a focused active-scenario economy-day step with live town and controlled resource-site income instead of the full strategic enemy turn loop.",
			"This is active-scenario economy runway evidence, not final scenario-wide route balance or campaign pacing approval.",
		],
	}
	print("ACTIVE_SCENARIO_TOWN_DEVELOPMENT_RUNWAY_REPORT %s" % JSON.stringify(report))
	get_tree().quit(0 if _errors.is_empty() else 1)

func _run_town_case(scenario_id: String, authored_town: Dictionary) -> Dictionary:
	var placement_id := String(authored_town.get("placement_id", ""))
	var town_id := String(authored_town.get("town_id", ""))
	var town_template := ContentService.get_town(town_id)
	var faction := ContentService.get_faction(String(town_template.get("faction_id", "")))
	var profile: Dictionary = town_template.get("development_balance", {}) if town_template.get("development_balance", {}) is Dictionary else {}
	var target_turns: int = min(TARGET_TURNS, int(profile.get("target_complete_turns", TARGET_TURNS)))
	var target_buildings := _string_array(town_template.get("buildable_building_ids", []))
	var required_resource_ids := _required_build_resource_ids(target_buildings)
	var base_row := {
		"ok": false,
		"scenario_id": scenario_id,
		"town_placement_id": placement_id,
		"town_id": town_id,
		"faction_id": String(faction.get("id", "")),
		"target_turns": target_turns,
		"target_building_count": target_buildings.size(),
		"required_resource_ids": required_resource_ids,
		"rare_resource_id": String(profile.get("rare_resource_id", "")),
	}
	if town_template.is_empty():
		base_row["error"] = "missing town template"
		return base_row
	if faction.is_empty():
		base_row["error"] = "missing faction template"
		return base_row
	if target_buildings.is_empty():
		base_row["error"] = "town has no buildable development target"
		return base_row
	if String(profile.get("rare_resource_id", "")) not in RARE_RESOURCE_IDS:
		base_row["error"] = "town development_balance missing live rare_resource_id"
		return base_row

	var signature_order := _signature_order(faction)
	var source_session = ScenarioFactory.create_session(
		scenario_id,
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	if source_session == null:
		base_row["error"] = "ScenarioFactory.create_session returned null"
		return base_row
	OverworldRules.normalize_overworld_state(source_session)
	var source_evidence := _secure_development_sources(source_session, required_resource_ids)
	var delayed_source_replay := _run_delayed_source_replay(
		scenario_id,
		authored_town,
		required_resource_ids,
		target_buildings,
		signature_order
	)
	var source_town := _town(source_session, placement_id)
	if source_town.is_empty():
		base_row["error"] = "runtime scenario session missing player town placement"
		base_row["source_evidence"] = source_evidence
		base_row["delayed_source_replay"] = delayed_source_replay
		return base_row
	var session = source_session
	session.game_state = "town"
	session.scenario_status = "in_progress"
	var select_result := _set_active_town(session, placement_id)
	if not bool(select_result.get("ok", false)):
		base_row["error"] = "unable to select player town: %s" % String(select_result.get("message", ""))
		base_row["source_evidence"] = source_evidence
		return base_row

	var build_log := []
	var stalled_days := []
	var rare_spend_events := []
	var same_day_reject_ok := false
	var build_actions_after_build_blocked := false
	var market_common_only := true
	var economy_day_advance_count := 0
	var post_completion_economy_day_count := 0

	for _turn in range(target_turns):
		_set_active_town(session, placement_id)
		var selected_id := _select_building_id(session, placement_id, target_buildings, signature_order)
		if selected_id == "":
			stalled_days.append({
				"day": int(session.day),
				"reason": "no_affordable_build_action",
				"resources": _resources(session),
				"open_buildings": _open_building_ids(_town(session, placement_id), target_buildings),
			})
		else:
			var before_resources := _resources(session)
			var selected_building := ContentService.get_building(selected_id)
			var build_result: Dictionary = OverworldRules.build_in_active_town(session, selected_id)
			if not bool(build_result.get("ok", false)):
				stalled_days.append({
					"day": int(session.day),
					"reason": "build_failed",
					"building_id": selected_id,
					"message": String(build_result.get("message", "")),
				})
			else:
				var after_resources := _resources(session)
				var rare_delta := _rare_resource_spend(selected_building.get("cost", {}), before_resources, after_resources)
				if not rare_delta.is_empty():
					rare_spend_events.append({
						"day": int(session.day),
						"building_id": selected_id,
						"spent": rare_delta,
					})
				var same_day_result: Dictionary = OverworldRules.build_in_active_town(session, selected_id)
				if not bool(same_day_result.get("ok", true)) and String(same_day_result.get("message", "")).contains("already completed a build order today"):
					same_day_reject_ok = true
				build_actions_after_build_blocked = TownRules.get_build_actions(session).is_empty()
				build_log.append({
					"day": int(session.day),
					"building_id": selected_id,
					"message": String(build_result.get("message", "")),
					"resources_before": before_resources,
					"resources_after": after_resources,
				})
				market_common_only = market_common_only and _market_actions_common_only(session)
				if _missing_buildings(session, placement_id, target_buildings).is_empty():
					break
		var turn_result: Dictionary = _advance_active_scenario_economy_day(session)
		if not bool(turn_result.get("ok", false)):
			stalled_days.append({
				"day": int(session.day),
				"reason": "economy_day_advance_failed",
				"message": String(turn_result.get("message", "")),
			})
		else:
			economy_day_advance_count += 1

	var missing := _missing_buildings(session, placement_id, target_buildings)
	var completed := missing.is_empty()
	while completed and int(session.day) < TARGET_TURNS:
		var completion_turn_result: Dictionary = _advance_active_scenario_economy_day(session)
		if not bool(completion_turn_result.get("ok", false)):
			stalled_days.append({
				"day": int(session.day),
				"reason": "post_completion_economy_day_advance_failed",
				"message": String(completion_turn_result.get("message", "")),
			})
			break
		economy_day_advance_count += 1
		post_completion_economy_day_count += 1
	var recruitment_report := _recruitment_end_to_end_report(session, placement_id, faction) if completed else {
		"ok": false,
		"errors": ["town did not complete development before recruitment check"],
	}
	base_row["ok"] = (
		completed
		and same_day_reject_ok
		and build_actions_after_build_blocked
		and not rare_spend_events.is_empty()
		and market_common_only
		and bool(recruitment_report.get("ok", false))
		and bool(delayed_source_replay.get("ok", false))
		and String(session.scenario_id) == scenario_id
		and economy_day_advance_count > 0
		and _source_covers_required_resources(source_evidence, required_resource_ids)
	)
	base_row["completed"] = completed
	base_row["completion_day"] = int(build_log[-1].get("day", 0)) if not build_log.is_empty() else 0
	base_row["build_count"] = build_log.size()
	base_row["missing_buildings"] = missing
	base_row["same_day_reject_ok"] = same_day_reject_ok
	base_row["build_actions_after_build_blocked"] = build_actions_after_build_blocked
	base_row["rare_spend_observed"] = not rare_spend_events.is_empty()
	base_row["rare_spend_events"] = rare_spend_events
	base_row["market_common_only"] = market_common_only
	base_row["recruitment_end_to_end_ok"] = bool(recruitment_report.get("ok", false))
	base_row["recruitment_case_count"] = int(recruitment_report.get("case_count", 0))
	base_row["recruited_unit_case_count"] = int(recruitment_report.get("recruited_unit_case_count", 0))
	base_row["recruitment_report"] = recruitment_report
	base_row["source_evidence"] = source_evidence
	base_row["delayed_source_replay_seen"] = true
	base_row["delayed_source_replay_ok"] = bool(delayed_source_replay.get("ok", false))
	base_row["delayed_source_replay"] = delayed_source_replay
	base_row["delayed_source_save_resume_seen"] = bool(delayed_source_replay.get("save_resume_seen", false))
	base_row["delayed_source_save_resume_ok"] = bool(delayed_source_replay.get("save_resume_ok", false))
	base_row["full_session_used"] = String(session.scenario_id) == scenario_id
	base_row["focused_economy_day_advance_count"] = economy_day_advance_count
	base_row["post_completion_economy_day_count"] = post_completion_economy_day_count
	base_row["scenario_map_size"] = _map_size_payload(OverworldRules.derive_map_size(session))
	base_row["scenario_resource_node_count"] = _array_size(session.overworld.get("resource_nodes", []))
	base_row["scenario_encounter_count"] = _array_size(session.overworld.get("encounters", []))
	base_row["scenario_enemy_state_count"] = _array_size(session.overworld.get("enemy_states", []))
	base_row["ending_resources"] = _resources(session)
	base_row["stalled_days"] = stalled_days.slice(0, 5)
	base_row["build_log"] = build_log
	if not bool(base_row.get("ok", false)):
		base_row["error"] = _runway_error(base_row)
	return base_row

func _run_delayed_source_replay(
	scenario_id: String,
	authored_town: Dictionary,
	required_resource_ids: Array,
	target_buildings: Array,
	signature_order: Dictionary
) -> Dictionary:
	var placement_id := String(authored_town.get("placement_id", ""))
	var session = ScenarioFactory.create_session(
		scenario_id,
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	if session == null:
		return {
			"ok": false,
			"error": "ScenarioFactory.create_session returned null",
		}
	OverworldRules.normalize_overworld_state(session)
	session.game_state = "town"
	session.scenario_status = "in_progress"
	var select_result := _set_active_town(session, placement_id)
	if not bool(select_result.get("ok", false)):
		return {
			"ok": false,
			"error": "unable to select player town: %s" % String(select_result.get("message", "")),
		}
	var start_tile := Vector2i(int(authored_town.get("x", 0)), int(authored_town.get("y", 0)))
	var source_schedule := _development_source_schedule(session, start_tile, required_resource_ids)
	var errors := []
	if not _schedule_covers_required_resources(source_schedule, required_resource_ids):
		errors.append("delayed replay source schedule does not cover all required non-gold resources")
	var build_log := []
	var stalled_days := []
	var rare_spend_events := []
	var save_resume := {}
	var delayed_source_seen := false
	for _turn in range(TARGET_TURNS):
		var applied_sources := _apply_due_development_sources(session, source_schedule, int(session.day))
		if not applied_sources.is_empty():
			delayed_source_seen = true
		var selected_id := _select_building_id(session, placement_id, target_buildings, signature_order)
		if selected_id == "":
			stalled_days.append({
				"day": int(session.day),
				"reason": "no_affordable_build_action",
				"resources": _resources(session),
				"open_buildings": _open_building_ids(_town(session, placement_id), target_buildings),
				"applied_sources": applied_sources,
			})
		else:
			var before_resources := _resources(session)
			var selected_building := ContentService.get_building(selected_id)
			var build_result: Dictionary = OverworldRules.build_in_active_town(session, selected_id)
			if not bool(build_result.get("ok", false)):
				stalled_days.append({
					"day": int(session.day),
					"reason": "build_failed",
					"building_id": selected_id,
					"message": String(build_result.get("message", "")),
					"applied_sources": applied_sources,
				})
			else:
				var after_resources := _resources(session)
				var rare_delta := _rare_resource_spend(selected_building.get("cost", {}), before_resources, after_resources)
				if not rare_delta.is_empty():
					rare_spend_events.append({
						"day": int(session.day),
						"building_id": selected_id,
						"spent": rare_delta,
					})
				build_log.append({
					"day": int(session.day),
					"building_id": selected_id,
					"resources_before": before_resources,
					"resources_after": after_resources,
					"applied_sources": applied_sources,
				})
				if save_resume.is_empty() and delayed_source_seen and not rare_delta.is_empty():
					save_resume = _delayed_source_save_resume_checkpoint(
						session,
						placement_id,
						selected_id,
						source_schedule,
						required_resource_ids
					)
					if save_resume.has("session"):
						session = save_resume.get("session")
					if not bool(save_resume.get("ok", false)):
						stalled_days.append({
							"day": int(session.day),
							"reason": "delayed_source_save_resume_failed",
							"message": String(save_resume.get("error", "")),
						})
						break
				if _missing_buildings(session, placement_id, target_buildings).is_empty():
					break
		var turn_result: Dictionary = _advance_active_scenario_economy_day(session)
		if not bool(turn_result.get("ok", false)):
			stalled_days.append({
				"day": int(session.day),
				"reason": "economy_day_advance_failed",
				"message": String(turn_result.get("message", "")),
			})
			break
	var missing := _missing_buildings(session, placement_id, target_buildings)
	var completed := missing.is_empty()
	if not completed:
		errors.append("town did not complete delayed-source development replay")
	if rare_spend_events.is_empty():
		errors.append("delayed-source replay did not spend a rare resource")
	if save_resume.is_empty():
		errors.append("delayed-source replay did not save/resume after source acquisition and rare construction")
	elif not bool(save_resume.get("ok", false)):
		errors.append("delayed-source save/resume failed: %s" % String(save_resume.get("error", "unknown")))
	return {
		"ok": errors.is_empty(),
		"schema": "active_scenario_town_delayed_source_replay_v1",
		"target_turns": TARGET_TURNS,
		"route_steps_per_day": DELAYED_SOURCE_ROUTE_STEPS_PER_DAY,
		"guarded_source_extra_days": DELAYED_GUARDED_SOURCE_EXTRA_DAYS,
		"source_schedule": _source_schedule_payload(source_schedule),
		"source_schedule_covers_required_resources": _schedule_covers_required_resources(source_schedule, required_resource_ids),
		"completed": completed,
		"completion_day": int(build_log[-1].get("day", 0)) if not build_log.is_empty() and completed else 0,
		"completion_margin_days": TARGET_TURNS - int(build_log[-1].get("day", 0)) if not build_log.is_empty() and completed else -1,
		"build_count": build_log.size(),
		"missing_buildings": missing,
		"rare_spend_observed": not rare_spend_events.is_empty(),
		"rare_spend_events": rare_spend_events,
		"save_resume_seen": not save_resume.is_empty(),
		"save_resume_ok": bool(save_resume.get("ok", false)),
		"save_resume": _without_session(save_resume),
		"ending_resources": _resources(session),
		"stalled_days": stalled_days.slice(0, 5),
		"build_log": build_log,
		"errors": errors,
		"error": "; ".join(errors),
	}

func _delayed_source_save_resume_checkpoint(
	session,
	placement_id: String,
	built_building_id: String,
	source_schedule: Array,
	required_resource_ids: Array
) -> Dictionary:
	session.game_state = "town"
	session.scenario_status = "in_progress"
	_set_active_town(session, placement_id)
	var before_signature := _delayed_source_resume_signature(session, placement_id, source_schedule, required_resource_ids)
	var save_result: Dictionary = SaveService.save_runtime_manual_session(session, DELAYED_SOURCE_SAVE_RESUME_SLOT)
	if not bool(save_result.get("ok", false)):
		return {"ok": false, "stage": "save", "error": String(save_result.get("message", ""))}
	var summary: Dictionary = SaveService.inspect_manual_slot(DELAYED_SOURCE_SAVE_RESUME_SLOT)
	var restored = SaveService.restore_manual_session(DELAYED_SOURCE_SAVE_RESUME_SLOT)
	if restored == null:
		return {"ok": false, "stage": "restore", "error": "restore_manual_session returned null", "summary": summary}
	OverworldRules.normalize_overworld_state(restored)
	restored.game_state = "town"
	restored.scenario_status = "in_progress"
	_set_active_town(restored, placement_id)
	var after_signature := _delayed_source_resume_signature(restored, placement_id, source_schedule, required_resource_ids)
	var same_day_result: Dictionary = OverworldRules.build_in_active_town(restored, built_building_id)
	var same_day_guard_ok := (
		not bool(same_day_result.get("ok", true))
		and String(same_day_result.get("message", "")).contains("already completed a build order today")
	)
	var actions_blocked := TownRules.get_build_actions(restored).is_empty()
	var signature_ok := JSON.stringify(before_signature) == JSON.stringify(after_signature)
	var resume_target_town := String(summary.get("resume_target", "")) == "town"
	var active_town_preserved := String(restored.flags.get("active_town_placement_id", "")) == placement_id
	var source_state_preserved := bool(after_signature.get("source_schedule_state_matches", false))
	var ok := signature_ok and same_day_guard_ok and actions_blocked and resume_target_town and active_town_preserved and source_state_preserved
	return {
		"ok": ok,
		"session": restored,
		"slot": DELAYED_SOURCE_SAVE_RESUME_SLOT,
		"built_building_id": built_building_id,
		"signature_ok": signature_ok,
		"same_day_guard_after_restore": same_day_guard_ok,
		"build_actions_after_restore_blocked": actions_blocked,
		"resume_target_town": resume_target_town,
		"active_town_preserved": active_town_preserved,
		"source_state_preserved": source_state_preserved,
		"save_version": int(restored.save_version),
		"summary_resume_target": String(summary.get("resume_target", "")),
		"same_day_reject_message": String(same_day_result.get("message", "")),
		"signature_before": before_signature,
		"signature_after": after_signature,
		"error": "" if ok else _delayed_source_save_resume_error(signature_ok, same_day_guard_ok, actions_blocked, resume_target_town, active_town_preserved, source_state_preserved),
	}

func _delayed_source_save_resume_error(
	signature_ok: bool,
	same_day_guard_ok: bool,
	actions_blocked: bool,
	resume_target_town: bool,
	active_town_preserved: bool,
	source_state_preserved: bool
) -> String:
	if not signature_ok:
		return "session economy/town/source signature changed after restore"
	if not same_day_guard_ok:
		return "same-day build guard was not preserved after restore"
	if not actions_blocked:
		return "build actions remained visible after restoring same-day build state"
	if not resume_target_town:
		return "save summary did not resume to town"
	if not active_town_preserved:
		return "active town placement flag was not preserved"
	if not source_state_preserved:
		return "delayed source node state was not preserved"
	return "unknown delayed-source save/resume failure"

func _delayed_source_resume_signature(session, placement_id: String, source_schedule: Array, required_resource_ids: Array) -> Dictionary:
	return {
		"save_version": int(session.save_version),
		"scenario_id": String(session.scenario_id),
		"day": int(session.day),
		"game_state": String(session.game_state),
		"scenario_status": String(session.scenario_status),
		"active_town_placement_id": String(session.flags.get("active_town_placement_id", "")),
		"resources": _resources(session),
		"town": _town_development_signature(_town(session, placement_id)),
		"applied_source_nodes": _applied_source_node_signature(session, source_schedule),
		"source_schedule_state_matches": _applied_source_nodes_match_schedule(session, source_schedule, required_resource_ids),
	}

func _town_development_signature(town: Dictionary) -> Dictionary:
	return {
		"placement_id": String(town.get("placement_id", "")),
		"town_id": String(town.get("town_id", "")),
		"built_buildings": _string_array(town.get("built_buildings", [])),
		"last_build_day": int(town.get("last_build_day", 0)),
		"available_recruits": _int_dictionary(town.get("available_recruits", {})),
	}

func _applied_source_node_signature(session, source_schedule: Array) -> Array:
	var nodes: Array = session.overworld.get("resource_nodes", []) if session.overworld.get("resource_nodes", []) is Array else []
	var rows := []
	for schedule_value in source_schedule:
		if not (schedule_value is Dictionary):
			continue
		var schedule: Dictionary = schedule_value
		if not bool(schedule.get("applied", false)):
			continue
		var placement_id := String(schedule.get("placement_id", ""))
		var node := _resource_node_by_placement_id(nodes, placement_id)
		rows.append({
			"placement_id": placement_id,
			"site_id": String(schedule.get("site_id", "")),
			"collected": bool(node.get("collected", false)),
			"collected_day": int(node.get("collected_day", 0)),
			"collected_by_faction_id": String(node.get("collected_by_faction_id", "")),
			"resource_ids": _string_array(schedule.get("resource_ids", [])),
		})
	return rows

func _applied_source_nodes_match_schedule(session, source_schedule: Array, required_resource_ids: Array) -> bool:
	var nodes: Array = session.overworld.get("resource_nodes", []) if session.overworld.get("resource_nodes", []) is Array else []
	var covered := {}
	var any_applied := false
	for schedule_value in source_schedule:
		if not (schedule_value is Dictionary):
			continue
		var schedule: Dictionary = schedule_value
		if not bool(schedule.get("applied", false)):
			continue
		any_applied = true
		var node := _resource_node_by_placement_id(nodes, String(schedule.get("placement_id", "")))
		if node.is_empty():
			return false
		if bool(schedule.get("persistent_control", false)) and String(node.get("collected_by_faction_id", "")) != "player":
			return false
		var claims: Dictionary = schedule.get("claim_rewards", {}) if schedule.get("claim_rewards", {}) is Dictionary else {}
		if not claims.is_empty() and not bool(node.get("collected", false)):
			return false
		for resource_id in _string_array(schedule.get("resource_ids", [])):
			covered[resource_id] = true
	if not any_applied:
		return false
	for resource_id in required_resource_ids:
		var id := String(resource_id)
		if id == "gold":
			continue
		if bool(covered.get(id, false)):
			return true
	return false

func _recruitment_end_to_end_report(session, placement_id: String, faction: Dictionary) -> Dictionary:
	_set_active_town(session, placement_id)
	var ladder_ids := _string_array(faction.get("unit_ladder_ids", []))
	var rows := []
	var errors := []
	var recruited_count := 0
	var before_army := _army_stack_counts(session)
	if ladder_ids.size() != TARGET_TIER_COUNT:
		errors.append("%s unit ladder must expose seven tiers" % String(faction.get("id", "")))
	for index in range(ladder_ids.size()):
		var unit_id := String(ladder_ids[index])
		var expected_tier := index + 1
		var action := _recruit_action_for(session, placement_id, unit_id)
		var row := {
			"ok": false,
			"unit_id": unit_id,
			"expected_tier": expected_tier,
			"action_found": not action.is_empty(),
		}
		if action.is_empty():
			row["error"] = "missing recruit action"
			errors.append("%s missing recruit action for %s" % [String(faction.get("id", "")), unit_id])
			rows.append(row)
			continue
		var unit := ContentService.get_unit(unit_id)
		var before_count := int(_army_stack_counts(session).get(unit_id, 0))
		var available_before := int(action.get("available_count", 0))
		var weekly_growth := int(action.get("weekly_growth", 0))
		var direct_affordable_count := int(action.get("direct_affordable_count", 0))
		row["unit_name"] = String(unit.get("name", unit_id))
		row["unit_tier"] = int(action.get("unit_tier", 0))
		row["tier_label"] = String(action.get("tier_label", ""))
		row["available_before"] = available_before
		row["weekly_growth"] = weekly_growth
		row["direct_affordable_count"] = direct_affordable_count
		row["unit_cost"] = action.get("unit_cost", {})
		if int(unit.get("tier", 0)) != expected_tier or int(action.get("unit_tier", 0)) != expected_tier:
			row["error"] = "tier mismatch"
		elif available_before <= 0:
			row["error"] = "no recruits available"
		elif weekly_growth <= 0:
			row["error"] = "weekly growth missing"
		elif direct_affordable_count <= 0:
			row["error"] = "not directly affordable"
		elif not String(action.get("summary", "")).contains("Tier %d" % expected_tier):
			row["error"] = "summary missing tier label"
		else:
			var recruit_result: Dictionary = OverworldRules.recruit_in_active_town(session, unit_id, 1)
			var after_count := int(_army_stack_counts(session).get(unit_id, 0))
			row["recruit_result_ok"] = bool(recruit_result.get("ok", false))
			row["recruit_message"] = String(recruit_result.get("message", ""))
			row["army_count_before"] = before_count
			row["army_count_after"] = after_count
			if not bool(recruit_result.get("ok", false)):
				row["error"] = "recruit action failed"
			elif after_count != before_count + 1:
				row["error"] = "field army did not receive recruit"
			else:
				row["ok"] = true
				recruited_count += 1
		if not bool(row.get("ok", false)):
			errors.append("%s %s tier %d recruitment failed: %s" % [
				String(faction.get("id", "")),
				unit_id,
				expected_tier,
				String(row.get("error", "unknown")),
			])
		rows.append(row)
	var after_army := _army_stack_counts(session)
	return {
		"ok": errors.is_empty() and ladder_ids.size() == TARGET_TIER_COUNT and recruited_count == TARGET_TIER_COUNT,
		"faction_id": String(faction.get("id", "")),
		"case_count": rows.size(),
		"recruited_unit_case_count": recruited_count,
		"army_before": before_army,
		"army_after": after_army,
		"tiers": rows,
		"errors": errors,
	}

func _recruit_action_for(session, placement_id: String, unit_id: String) -> Dictionary:
	_set_active_town(session, placement_id)
	for action_value in TownRules.get_recruit_actions(session):
		if action_value is Dictionary and String(action_value.get("id", "")) == "recruit:%s" % unit_id:
			return action_value
	return {}

func _army_stack_counts(session) -> Dictionary:
	var counts := {}
	for stack_value in session.overworld.get("army", {}).get("stacks", []):
		if not (stack_value is Dictionary):
			continue
		var unit_id := String(stack_value.get("unit_id", ""))
		if unit_id == "":
			continue
		counts[unit_id] = int(counts.get(unit_id, 0)) + int(stack_value.get("count", 0))
	return counts

func _secure_development_sources(session, required_resource_ids: Array) -> Dictionary:
	var nodes: Array = session.overworld.get("resource_nodes", [])
	var source_rows := []
	var secured_nodes := []
	var secured_resource_ids := {}
	var secured_income := {}
	var secured_claims := {}
	for index in range(nodes.size()):
		if not (nodes[index] is Dictionary):
			continue
		var node: Dictionary = nodes[index]
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		if site.is_empty():
			continue
		var claim_rewards: Dictionary = site.get("claim_rewards", site.get("rewards", {})) if site.get("claim_rewards", site.get("rewards", {})) is Dictionary else {}
		var control_income: Dictionary = site.get("control_income", {}) if site.get("control_income", {}) is Dictionary else {}
		var relevant_claims := _filter_resources(claim_rewards, required_resource_ids)
		var relevant_income := _filter_resources(control_income, required_resource_ids)
		if relevant_claims.is_empty() and relevant_income.is_empty():
			continue
		if bool(site.get("persistent_control", false)):
			node["collected_by_faction_id"] = "player"
		if not relevant_claims.is_empty() and not bool(node.get("collected", false)):
			_add_to_session_resources(session, relevant_claims)
			node["collected"] = true
			node["collected_day"] = int(session.day)
			secured_claims = _add_resource_sets(secured_claims, relevant_claims)
		if not relevant_income.is_empty() and bool(site.get("persistent_control", false)):
			secured_income = _add_resource_sets(secured_income, relevant_income)
		for resource_id in relevant_claims.keys():
			secured_resource_ids[String(resource_id)] = true
		for resource_id in relevant_income.keys():
			secured_resource_ids[String(resource_id)] = true
		source_rows.append({
			"placement_id": String(node.get("placement_id", "")),
			"site_id": String(node.get("site_id", "")),
			"persistent_control": bool(site.get("persistent_control", false)),
			"claim_rewards": relevant_claims,
			"control_income": relevant_income,
		})
		secured_nodes.append({
			"placement_id": String(node.get("placement_id", "")),
			"site_id": String(node.get("site_id", "")),
			"x": int(node.get("x", 0)),
			"y": int(node.get("y", 0)),
			"collected": bool(node.get("collected", false)),
			"collected_day": int(node.get("collected_day", 0)),
			"collected_by_faction_id": String(node.get("collected_by_faction_id", "")),
		})
		nodes[index] = node
	session.overworld["resource_nodes"] = nodes
	return {
		"secured_source_count": source_rows.size(),
		"secured_resource_ids": _sorted_keys(secured_resource_ids),
		"secured_claims": secured_claims,
		"secured_daily_income": secured_income,
		"resources_after_claims": _resources(session),
		"secured_resource_nodes": secured_nodes,
		"sources": source_rows,
	}

func _runway_error(row: Dictionary) -> String:
	if not bool(row.get("completed", false)):
		return "town did not complete its active-scenario development runway"
	if not bool(row.get("same_day_reject_ok", false)):
		return "same-day second build was not rejected"
	if not bool(row.get("build_actions_after_build_blocked", false)):
		return "build action surface did not block after same-day build"
	if not bool(row.get("rare_spend_observed", false)):
		return "high-tier rare-resource spend was not observed"
	if not bool(row.get("market_common_only", false)):
		return "market actions included non-common resources"
	if not bool(row.get("recruitment_end_to_end_ok", false)):
		return "post-development seven-tier recruitment did not complete"
	if not bool(row.get("full_session_used", false)):
		return "development did not run inside the active scenario session"
	if int(row.get("focused_economy_day_advance_count", 0)) <= 0:
		return "focused active-scenario economy day advance was not exercised"
	if not _source_covers_required_resources(row.get("source_evidence", {}), row.get("required_resource_ids", [])):
		return "secured scenario sources did not cover required build resources"
	return "unknown runway failure"

func _advance_active_scenario_economy_day(session) -> Dictionary:
	if session == null:
		return {"ok": false, "message": "missing session"}
	session.day = int(session.day) + 1
	var recovery_messages := _advance_active_scenario_recovery(session)
	var town_income := {}
	var weekly_growth := {}
	var should_apply_weekly_growth := OverworldRules.is_weekly_growth_day(int(session.day))
	var towns: Array = session.overworld.get("towns", []) if session.overworld.get("towns", []) is Array else []
	for index in range(towns.size()):
		if not (towns[index] is Dictionary):
			continue
		var town: Dictionary = towns[index]
		if String(town.get("owner", "neutral")) != "player":
			continue
		if should_apply_weekly_growth:
			var growth := OverworldRules.town_weekly_growth(town, session)
			if not growth.is_empty():
				town["available_recruits"] = _add_recruit_sets(town.get("available_recruits", {}), growth)
				weekly_growth = _add_recruit_sets(weekly_growth, growth)
				towns[index] = town
	session.overworld["towns"] = towns
	for town in session.overworld.get("towns", []):
		if not (town is Dictionary) or String(town.get("owner", "neutral")) != "player":
			continue
		town_income = _add_resource_sets(
			town_income,
			DifficultyRules.scale_income_resources(session, OverworldRules.town_income(town, session))
		)
	var site_income := DifficultyRules.scale_income_resources(session, OverworldRules.controlled_resource_site_income(session, "player"))
	var total_income := _add_resource_sets(town_income, site_income)
	_add_to_session_resources(session, total_income)
	return {
		"ok": true,
		"message": "Focused active-scenario economy day advanced.",
		"day": int(session.day),
		"town_income": _normalized_resources(town_income),
		"site_income": _normalized_resources(site_income),
		"total_income": _normalized_resources(total_income),
		"recovery_messages": recovery_messages,
		"weekly_growth": weekly_growth,
	}

func _advance_active_scenario_recovery(session) -> Array:
	var messages := []
	var towns: Array = session.overworld.get("towns", []) if session.overworld.get("towns", []) is Array else []
	for town_value in towns:
		if not (town_value is Dictionary):
			continue
		var town: Dictionary = town_value
		var recovery: Dictionary = OverworldRules.town_recovery_state(session, town)
		var pressure := int(recovery.get("pressure", 0))
		if pressure <= 0:
			continue
		var relief: int = max(1, int(recovery.get("relief_per_day", 1)))
		var message := OverworldRules.relieve_town_recovery_pressure(
			session,
			String(town.get("placement_id", "")),
			relief,
			"focused active-scenario economy day"
		)
		if message != "":
			messages.append(message)
	return messages

func _source_covers_required_resources(source_evidence: Dictionary, required_resource_ids: Array) -> bool:
	var secured := _string_array(source_evidence.get("secured_resource_ids", []))
	for resource_id in required_resource_ids:
		if String(resource_id) in ["gold"]:
			continue
		if String(resource_id) not in secured:
			return false
	return true

func _select_building_id(session, placement_id: String, target_buildings: Array, signature_order: Dictionary) -> String:
	var actions := []
	var town := _town(session, placement_id)
	var resources := _resources(session)
	for building_id_value in OverworldRules.get_town_build_options(town, int(session.day)):
		var building_id := String(building_id_value)
		if building_id not in target_buildings:
			continue
		var building := ContentService.get_building(building_id)
		var readiness: Dictionary = OverworldRules.town_cost_readiness(town, resources, building.get("cost", {}), int(session.day))
		if not bool(readiness.get("direct_affordable", false)):
			continue
		actions.append(building_id)
	actions.sort_custom(func(a, b): return _build_sort_key(a, target_buildings, signature_order) < _build_sort_key(b, target_buildings, signature_order))
	return String(actions[0]) if not actions.is_empty() else ""

func _build_sort_key(building_id: String, target_buildings: Array, signature_order: Dictionary) -> String:
	var signature_rank := int(signature_order.get(building_id, 99))
	var target_rank := target_buildings.find(building_id)
	if target_rank < 0:
		target_rank = 999
	return "%03d:%03d:%s" % [signature_rank, target_rank, building_id]

func _signature_order(faction: Dictionary) -> Dictionary:
	var order := {}
	var signature_ids := _string_array(faction.get("signature_building_ids", []))
	for index in range(signature_ids.size()):
		order[signature_ids[index]] = index + 1
	return order

func _open_building_ids(town: Dictionary, target_buildings: Array) -> Array:
	var result := []
	for building_id in target_buildings:
		if bool(OverworldRules.get_town_build_status(town, String(building_id)).get("buildable", false)):
			result.append(String(building_id))
	return result

func _missing_buildings(session, placement_id: String, target_buildings: Array) -> Array:
	var town := _town(session, placement_id)
	var built := _string_array(town.get("built_buildings", []))
	var missing := []
	for building_id in target_buildings:
		if String(building_id) not in built:
			missing.append(String(building_id))
	return missing

func _town(session, placement_id: String) -> Dictionary:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("placement_id", "")) == placement_id:
			return town
	return {}

func _set_active_town(session, placement_id: String) -> Dictionary:
	return OverworldRules.set_active_town_visit(session, placement_id)

func _market_actions_common_only(session) -> bool:
	for action_value in TownRules.get_market_actions(session):
		if not (action_value is Dictionary):
			continue
		var action: Dictionary = action_value
		var resource_id := String(action.get("resource_id", ""))
		if resource_id != "" and resource_id not in COMMON_MARKET_RESOURCE_IDS:
			return false
	return true

func _required_build_resource_ids(target_buildings: Array) -> Array:
	var ids := {}
	for building_id in target_buildings:
		var building := ContentService.get_building(String(building_id))
		var cost: Dictionary = building.get("cost", {}) if building.get("cost", {}) is Dictionary else {}
		for resource_id in cost.keys():
			var id := String(resource_id)
			if id in LIVE_STOCKPILE_RESOURCE_IDS:
				ids[id] = true
	return _sorted_keys(ids)

func _rare_resource_spend(cost_value: Variant, before: Dictionary, after: Dictionary) -> Dictionary:
	var cost: Dictionary = cost_value if cost_value is Dictionary else {}
	var spent := {}
	for resource_id in RARE_RESOURCE_IDS:
		if int(cost.get(resource_id, 0)) <= 0:
			continue
		var delta := int(before.get(resource_id, 0)) - int(after.get(resource_id, 0))
		if delta > 0:
			spent[resource_id] = delta
	return spent

func _development_source_schedule(session, start_tile: Vector2i, required_resource_ids: Array) -> Array:
	var rows := []
	var nodes: Array = session.overworld.get("resource_nodes", [])
	for node_value in nodes:
		if not (node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		if site.is_empty():
			continue
		var claim_rewards: Dictionary = site.get("claim_rewards", site.get("rewards", {})) if site.get("claim_rewards", site.get("rewards", {})) is Dictionary else {}
		var control_income: Dictionary = site.get("control_income", {}) if site.get("control_income", {}) is Dictionary else {}
		var relevant_claims := _filter_resources(claim_rewards, required_resource_ids)
		var relevant_income := _filter_resources(control_income, required_resource_ids)
		if relevant_claims.is_empty() and relevant_income.is_empty():
			continue
		var target_tile := Vector2i(int(node.get("x", 0)), int(node.get("y", 0)))
		var route := _find_route(session, start_tile, target_tile)
		if route.is_empty():
			continue
		var route_steps: int = max(0, route.size() - 1)
		var guarded := _resource_source_has_guard(session, node)
		var acquisition_day: int = max(1, int(ceil(float(route_steps) / float(DELAYED_SOURCE_ROUTE_STEPS_PER_DAY))))
		if guarded:
			acquisition_day += DELAYED_GUARDED_SOURCE_EXTRA_DAYS
		rows.append({
			"placement_id": String(node.get("placement_id", "")),
			"site_id": String(node.get("site_id", "")),
			"x": int(node.get("x", 0)),
			"y": int(node.get("y", 0)),
			"persistent_control": bool(site.get("persistent_control", false)),
			"claim_rewards": relevant_claims,
			"control_income": relevant_income,
			"resource_ids": _source_resource_ids(relevant_claims, relevant_income),
			"route_steps": route_steps,
			"guarded": guarded,
			"acquisition_day": acquisition_day,
			"applied": false,
		})
	rows.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if int(left.get("acquisition_day", 999999)) != int(right.get("acquisition_day", 999999)):
			return int(left.get("acquisition_day", 999999)) < int(right.get("acquisition_day", 999999))
		if int(left.get("route_steps", 999999)) != int(right.get("route_steps", 999999)):
			return int(left.get("route_steps", 999999)) < int(right.get("route_steps", 999999))
		return String(left.get("placement_id", "")) < String(right.get("placement_id", ""))
	)
	return rows

func _apply_due_development_sources(session, source_schedule: Array, day: int) -> Array:
	var applied_rows := []
	var nodes: Array = session.overworld.get("resource_nodes", [])
	for index in range(source_schedule.size()):
		if not (source_schedule[index] is Dictionary):
			continue
		var row: Dictionary = source_schedule[index]
		if bool(row.get("applied", false)) or int(row.get("acquisition_day", 999999)) > day:
			continue
		var node_index := _resource_node_index(nodes, String(row.get("placement_id", "")))
		if node_index < 0:
			continue
		var node: Dictionary = nodes[node_index]
		if bool(row.get("persistent_control", false)):
			node["collected_by_faction_id"] = "player"
		var claims: Dictionary = row.get("claim_rewards", {}) if row.get("claim_rewards", {}) is Dictionary else {}
		if not claims.is_empty() and not bool(node.get("collected", false)):
			_add_to_session_resources(session, claims)
			node["collected"] = true
			node["collected_day"] = day
		nodes[node_index] = node
		row["applied"] = true
		source_schedule[index] = row
		applied_rows.append({
			"placement_id": String(row.get("placement_id", "")),
			"site_id": String(row.get("site_id", "")),
			"acquisition_day": int(row.get("acquisition_day", 0)),
			"resource_ids": _string_array(row.get("resource_ids", [])),
			"claim_rewards": claims,
			"control_income": row.get("control_income", {}),
		})
	session.overworld["resource_nodes"] = nodes
	return applied_rows

func _resource_node_index(nodes: Array, placement_id: String) -> int:
	for index in range(nodes.size()):
		if nodes[index] is Dictionary and String(nodes[index].get("placement_id", "")) == placement_id:
			return index
	return -1

func _source_resource_ids(claim_rewards: Dictionary, control_income: Dictionary) -> Array:
	var ids := {}
	for resources in [claim_rewards, control_income]:
		for resource_id in resources.keys():
			ids[String(resource_id)] = true
	return _sorted_keys(ids)

func _source_schedule_payload(source_schedule: Array) -> Array:
	var rows := []
	for row_value in source_schedule:
		if not (row_value is Dictionary):
			continue
		var row: Dictionary = row_value
		rows.append({
			"placement_id": String(row.get("placement_id", "")),
			"site_id": String(row.get("site_id", "")),
			"x": int(row.get("x", 0)),
			"y": int(row.get("y", 0)),
			"persistent_control": bool(row.get("persistent_control", false)),
			"resource_ids": _string_array(row.get("resource_ids", [])),
			"route_steps": int(row.get("route_steps", 0)),
			"guarded": bool(row.get("guarded", false)),
			"acquisition_day": int(row.get("acquisition_day", 0)),
			"applied": bool(row.get("applied", false)),
		})
	return rows

func _schedule_covers_required_resources(source_schedule: Array, required_resource_ids: Array) -> bool:
	var covered := {}
	for row_value in source_schedule:
		if not (row_value is Dictionary):
			continue
		var row: Dictionary = row_value
		for resource_id in _string_array(row.get("resource_ids", [])):
			covered[resource_id] = true
	for resource_id in required_resource_ids:
		var id := String(resource_id)
		if id == "gold":
			continue
		if not bool(covered.get(id, false)):
			return false
	return true

func _find_route(session, start_tile: Vector2i, target_tile: Vector2i) -> Array:
	var map_size := OverworldRules.derive_map_size(session)
	if not _in_bounds(start_tile, map_size) or not _in_bounds(target_tile, map_size):
		return []
	var start_key := _tile_key(start_tile)
	var queue := [start_tile]
	var visited := {start_key: true}
	var parent := {}
	var head := 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		if current == target_tile:
			return _reconstruct_route(parent, start_tile, target_tile)
		for neighbor in _neighbors(current):
			if not _in_bounds(neighbor, map_size):
				continue
			var neighbor_key := _tile_key(neighbor)
			if bool(visited.get(neighbor_key, false)):
				continue
			if OverworldRules.tile_step_cuts_blocked_corner(session, current, neighbor):
				continue
			var is_destination: bool = neighbor == target_tile
			if OverworldRules.tile_is_blocked(session, neighbor.x, neighbor.y) and not (is_destination and OverworldRules.tile_is_actionable_route_destination(session, neighbor.x, neighbor.y)):
				continue
			if not is_destination and OverworldRules.tile_has_route_interaction(session, neighbor.x, neighbor.y):
				continue
			visited[neighbor_key] = true
			parent[neighbor_key] = current
			queue.append(neighbor)
	return []

func _reconstruct_route(parent: Dictionary, start_tile: Vector2i, target_tile: Vector2i) -> Array:
	var route := [target_tile]
	var current := target_tile
	var guard := 0
	while current != start_tile and guard < 10000:
		guard += 1
		var current_key := _tile_key(current)
		if not parent.has(current_key):
			return []
		current = parent[current_key]
		route.push_front(current)
	return route

func _neighbors(tile: Vector2i) -> Array:
	return [
		Vector2i(tile.x - 1, tile.y - 1),
		Vector2i(tile.x, tile.y - 1),
		Vector2i(tile.x + 1, tile.y - 1),
		Vector2i(tile.x - 1, tile.y),
		Vector2i(tile.x + 1, tile.y),
		Vector2i(tile.x - 1, tile.y + 1),
		Vector2i(tile.x, tile.y + 1),
		Vector2i(tile.x + 1, tile.y + 1),
	]

func _in_bounds(tile: Vector2i, map_size: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < map_size.x and tile.y < map_size.y

func _tile_key(tile: Vector2i) -> String:
	return "%d,%d" % [tile.x, tile.y]

func _resource_source_has_guard(session, node: Dictionary) -> bool:
	var placement_id := String(node.get("placement_id", ""))
	for encounter in session.overworld.get("encounters", []):
		if not (encounter is Dictionary):
			continue
		if OverworldRules.is_encounter_resolved(session, encounter):
			continue
		if String(encounter.get("target_kind", "")) == "resource" and String(encounter.get("target_placement_id", "")) == placement_id:
			return true
		var dx: int = abs(int(encounter.get("x", 0)) - int(node.get("x", 0)))
		var dy: int = abs(int(encounter.get("y", 0)) - int(node.get("y", 0)))
		if max(dx, dy) <= 1:
			return true
	return false

func _filter_resources(resources: Dictionary, allowed: Array) -> Dictionary:
	var result := {}
	for resource_id in resources.keys():
		var id := String(resource_id)
		if id in allowed and int(resources.get(resource_id, 0)) > 0:
			result[id] = int(resources.get(resource_id, 0))
	return result

func _add_to_session_resources(session, resources: Dictionary) -> void:
	var pool: Dictionary = session.overworld.get("resources", {})
	for resource_id in resources.keys():
		var id := String(resource_id)
		pool[id] = int(pool.get(id, 0)) + int(resources.get(resource_id, 0))
	session.overworld["resources"] = pool

func _add_resource_sets(left: Dictionary, right: Dictionary) -> Dictionary:
	var result := left.duplicate(true)
	for resource_id in right.keys():
		var id := String(resource_id)
		result[id] = int(result.get(id, 0)) + int(right.get(resource_id, 0))
	return result

func _add_recruit_sets(left: Variant, right: Variant) -> Dictionary:
	var result := {}
	if left is Dictionary:
		for unit_id in left.keys():
			result[String(unit_id)] = int(left.get(unit_id, 0))
	if right is Dictionary:
		for unit_id in right.keys():
			result[String(unit_id)] = int(result.get(String(unit_id), 0)) + int(right.get(unit_id, 0))
	return result

func _resources(session) -> Dictionary:
	var result := {}
	for resource_id in LIVE_STOCKPILE_RESOURCE_IDS:
		result[String(resource_id)] = int(session.overworld.get("resources", {}).get(String(resource_id), 0))
	return result

func _normalized_resources(resources: Dictionary) -> Dictionary:
	var result := {}
	for resource_id in LIVE_STOCKPILE_RESOURCE_IDS:
		result[String(resource_id)] = int(resources.get(String(resource_id), 0))
	return result

func _int_dictionary(value: Variant) -> Dictionary:
	var result := {}
	if not (value is Dictionary):
		return result
	for key in value.keys():
		result[String(key)] = int(value.get(key, 0))
	return result

func _resource_node_by_placement_id(nodes: Array, placement_id: String) -> Dictionary:
	for node_value in nodes:
		if node_value is Dictionary and String(node_value.get("placement_id", "")) == placement_id:
			return node_value
	return {}

func _without_session(payload: Dictionary) -> Dictionary:
	var result := {}
	for key in payload.keys():
		if String(key) == "session":
			continue
		result[key] = payload.get(key)
	return result

func _array_size(value: Variant) -> int:
	return value.size() if value is Array else 0

func _map_size_payload(size: Vector2i) -> Dictionary:
	return {"width": size.x, "height": size.y}

func _is_active_authored_scenario(scenario: Dictionary) -> bool:
	var selection: Dictionary = scenario.get("selection", {}) if scenario.get("selection", {}) is Dictionary else {}
	var availability: Dictionary = selection.get("availability", {}) if selection.get("availability", {}) is Dictionary else {}
	return bool(availability.get("campaign", false)) or bool(availability.get("skirmish", false))

func _player_towns(scenario: Dictionary) -> Array:
	var result := []
	for town in scenario.get("towns", []):
		if town is Dictionary and String(town.get("owner", "")) == "player":
			result.append(town)
	return result

func _string_array(values: Variant) -> Array:
	var result := []
	if not (values is Array):
		return result
	for value in values:
		result.append(String(value))
	return result

func _sorted_keys(values: Dictionary) -> Array:
	var keys := []
	for key in values.keys():
		keys.append(String(key))
	keys.sort()
	return keys
