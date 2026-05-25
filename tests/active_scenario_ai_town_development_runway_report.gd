extends Node

const REPORT_SCHEMA := "active_scenario_ai_town_development_runway_report_v1"
const TARGET_TURNS := 30
const MIN_COMPLETION_DAY := 24
const MIN_CAMPAIGN_SCENARIO_COUNT := 15
const MIN_SKIRMISH_SCENARIO_COUNT := 16
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
const DELAYED_SOURCE_SAVE_RESUME_SLOT := 3
const SIGNATURE_TIER_COUNT := 7
const MIN_FACTION_COVERAGE := 6

var _errors := []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var only_scenario := OS.get_environment("ACTIVE_SCENARIO_AI_TOWN_RUNWAY_ONLY")
	var scenario_count := 0
	var campaign_scenario_count := 0
	var skirmish_scenario_count := 0
	var town_case_count := 0
	var campaign_town_case_count := 0
	var skirmish_town_case_count := 0
	var completed_case_count := 0
	var campaign_completed_case_count := 0
	var skirmish_completed_case_count := 0
	var pacing_floor_case_count := 0
	var campaign_pacing_floor_case_count := 0
	var skirmish_pacing_floor_case_count := 0
	var completion_day_min := 0
	var completion_day_max := 0
	var source_adoption_policy_case_count := 0
	var rare_spend_case_count := 0
	var same_day_guard_case_count := 0
	var full_session_case_count := 0
	var delayed_source_replay_case_count := 0
	var delayed_source_replay_completed_count := 0
	var delayed_source_save_resume_case_count := 0
	var delayed_source_save_resume_completed_count := 0
	var seven_tier_recruitment_case_count := 0
	var seven_tier_recruitment_candidate_count := 0
	var affordable_recruitment_case_count := 0
	var covered_faction_ids := {}
	var covered_ladder_faction_ids := {}
	var rows := []
	for scenario_id in ContentService.get_content_ids(ContentService.SCENARIOS_PATH):
		if only_scenario != "" and String(scenario_id) != only_scenario:
			continue
		var scenario := ContentService.get_scenario(String(scenario_id))
		if not _is_active_authored_scenario(scenario):
			continue
		var launch_surfaces := _launch_surfaces(scenario)
		scenario_count += 1
		if "campaign" in launch_surfaces:
			campaign_scenario_count += 1
		if "skirmish" in launch_surfaces:
			skirmish_scenario_count += 1
		for authored_town in _enemy_towns(scenario):
			var row := _run_enemy_town_case(String(scenario_id), scenario, authored_town)
			row["launch_surfaces"] = launch_surfaces
			rows.append(row)
			var row_faction_id := String(row.get("faction_id", ""))
			if row_faction_id != "":
				covered_faction_ids[row_faction_id] = true
			var recruitment_evidence: Dictionary = row.get("ai_recruitment_evidence", {}) if row.get("ai_recruitment_evidence", {}) is Dictionary else {}
			var ladder_faction_id := String(recruitment_evidence.get("ladder_faction_id", ""))
			if ladder_faction_id != "":
				covered_ladder_faction_ids[ladder_faction_id] = true
			town_case_count += 1
			if "campaign" in launch_surfaces:
				campaign_town_case_count += 1
			if "skirmish" in launch_surfaces:
				skirmish_town_case_count += 1
			if bool(row.get("completed", false)):
				completed_case_count += 1
				if "campaign" in launch_surfaces:
					campaign_completed_case_count += 1
				if "skirmish" in launch_surfaces:
					skirmish_completed_case_count += 1
				var completion_day := int(row.get("completion_day", 0))
				if completion_day_min == 0 or completion_day < completion_day_min:
					completion_day_min = completion_day
				completion_day_max = max(completion_day_max, completion_day)
				if bool(row.get("pacing_floor_ok", false)):
					pacing_floor_case_count += 1
					if "campaign" in launch_surfaces:
						campaign_pacing_floor_case_count += 1
					if "skirmish" in launch_surfaces:
						skirmish_pacing_floor_case_count += 1
			if bool(row.get("rare_spend_observed", false)):
				rare_spend_case_count += 1
			var source_evidence: Dictionary = row.get("source_evidence", {}) if row.get("source_evidence", {}) is Dictionary else {}
			if String(source_evidence.get("source_adoption_policy", "")) == "minimal_required_resource_coverage":
				source_adoption_policy_case_count += 1
			if bool(row.get("same_day_second_build_blocked", false)):
				same_day_guard_case_count += 1
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
			if bool(row.get("ai_seven_tier_recruitment_seen", false)):
				seven_tier_recruitment_case_count += 1
			seven_tier_recruitment_candidate_count += int(row.get("ai_recruitment_tier_candidate_count", 0))
			if bool(row.get("ai_recruitment_selected_seen", false)):
				affordable_recruitment_case_count += 1
			if not bool(row.get("ok", false)):
				_errors.append("%s/%s failed: %s" % [
					String(scenario_id),
					String(authored_town.get("placement_id", "")),
					String(row.get("error", "unknown AI runway failure")),
				])
	var covered_faction_id_rows := _sorted_keys(covered_faction_ids)
	var covered_ladder_faction_id_rows := _sorted_keys(covered_ladder_faction_ids)
	if covered_faction_id_rows.size() < MIN_FACTION_COVERAGE:
		_errors.append("AI town-development runway covered only %d controller factions: %s" % [
			covered_faction_id_rows.size(),
			covered_faction_id_rows,
		])
	if covered_ladder_faction_id_rows.size() < MIN_FACTION_COVERAGE:
		_errors.append("AI town-development runway covered only %d native ladder factions: %s" % [
			covered_ladder_faction_id_rows.size(),
			covered_ladder_faction_id_rows,
		])
	if campaign_scenario_count < MIN_CAMPAIGN_SCENARIO_COUNT:
		_errors.append("AI town-development runway covered only %d campaign scenarios" % campaign_scenario_count)
	if skirmish_scenario_count < MIN_SKIRMISH_SCENARIO_COUNT:
		_errors.append("AI town-development runway covered only %d skirmish scenarios" % skirmish_scenario_count)
	var report := {
		"ok": _errors.is_empty(),
		"schema": REPORT_SCHEMA,
		"target_turns": TARGET_TURNS,
		"min_completion_day": MIN_COMPLETION_DAY,
		"active_scenario_count": scenario_count,
		"campaign_scenario_count": campaign_scenario_count,
		"skirmish_scenario_count": skirmish_scenario_count,
		"enemy_town_case_count": town_case_count,
		"campaign_enemy_town_case_count": campaign_town_case_count,
		"skirmish_enemy_town_case_count": skirmish_town_case_count,
		"completed_case_count": completed_case_count,
		"campaign_completed_case_count": campaign_completed_case_count,
		"skirmish_completed_case_count": skirmish_completed_case_count,
		"pacing_floor_case_count": pacing_floor_case_count,
		"campaign_pacing_floor_case_count": campaign_pacing_floor_case_count,
		"skirmish_pacing_floor_case_count": skirmish_pacing_floor_case_count,
		"completion_day_min": completion_day_min,
		"completion_day_max": completion_day_max,
		"source_adoption_policy_case_count": source_adoption_policy_case_count,
		"rare_spend_case_count": rare_spend_case_count,
		"same_day_guard_case_count": same_day_guard_case_count,
		"full_session_case_count": full_session_case_count,
		"delayed_source_replay_case_count": delayed_source_replay_case_count,
		"delayed_source_replay_completed_count": delayed_source_replay_completed_count,
		"delayed_source_save_resume_case_count": delayed_source_save_resume_case_count,
		"delayed_source_save_resume_completed_count": delayed_source_save_resume_completed_count,
		"seven_tier_recruitment_case_count": seven_tier_recruitment_case_count,
		"seven_tier_recruitment_candidate_count": seven_tier_recruitment_candidate_count,
		"affordable_recruitment_case_count": affordable_recruitment_case_count,
		"unique_faction_count": covered_faction_id_rows.size(),
		"covered_faction_ids": covered_faction_id_rows,
		"unique_ladder_faction_count": covered_ladder_faction_id_rows.size(),
		"covered_ladder_faction_ids": covered_ladder_faction_id_rows,
		"min_faction_coverage": MIN_FACTION_COVERAGE,
		"delayed_source_save_resume_slot": DELAYED_SOURCE_SAVE_RESUME_SLOT,
		"delayed_source_route_steps_per_day": DELAYED_SOURCE_ROUTE_STEPS_PER_DAY,
		"delayed_guarded_source_extra_days": DELAYED_GUARDED_SOURCE_EXTRA_DAYS,
		"live_stockpile_resource_ids": LIVE_STOCKPILE_RESOURCE_IDS,
		"rare_resource_ids": RARE_RESOURCE_IDS,
		"cases": rows,
		"errors": _errors,
		"caveats": [
			"The report boots active authored scenarios and secures scenario-authored economy sources for the target enemy town faction.",
			"A second replay now delays target-faction source ownership by route-derived acquisition days and guarded-source delay before proving the same 30-turn AI development runway.",
			"The delayed-source AI replay saves and restores after delayed source acquisition plus rare-resource construction, then continues the development runway from the restored active scenario session.",
			"Construction now runs inside the full scenario session state with authored map, resource nodes, encounters, and enemy states preserved.",
			"Construction runs through EnemyTurnRules.run_enemy_town_economy_turn and EnemyTurnRules.town_governor_pressure_report for the target faction.",
			"Completed enemy towns must expose the faction seven-tier recruitment ladder through EnemyTurnRules.town_recruitment_pressure_report.",
			"This is AI town-development economy runway evidence, not final strategic AI quality, route safety, encounter pacing, or campaign balance approval.",
		],
	}
	print("ACTIVE_SCENARIO_AI_TOWN_DEVELOPMENT_RUNWAY_REPORT %s" % JSON.stringify(report))
	get_tree().quit(0 if _errors.is_empty() else 1)

func _run_enemy_town_case(scenario_id: String, scenario: Dictionary, authored_town: Dictionary) -> Dictionary:
	var placement_id := String(authored_town.get("placement_id", ""))
	var town_id := String(authored_town.get("town_id", ""))
	var town_template := ContentService.get_town(town_id)
	var faction_id := String(authored_town.get("controlling_faction_id", town_template.get("faction_id", "")))
	if faction_id == "":
		faction_id = String(town_template.get("faction_id", ""))
	var config := _enemy_config_for_faction(scenario, faction_id)
	var faction := ContentService.get_faction(faction_id)
	var profile: Dictionary = town_template.get("development_balance", {}) if town_template.get("development_balance", {}) is Dictionary else {}
	var target_turns: int = min(TARGET_TURNS, int(profile.get("target_complete_turns", TARGET_TURNS)))
	var target_buildings := _string_array(town_template.get("buildable_building_ids", []))
	var required_resource_ids := _required_build_resource_ids(target_buildings)
	var base_row := {
		"ok": false,
		"scenario_id": scenario_id,
		"town_placement_id": placement_id,
		"town_id": town_id,
		"faction_id": faction_id,
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
	if config.is_empty():
		base_row["error"] = "missing enemy faction config"
		return base_row
	if target_buildings.is_empty():
		base_row["error"] = "town has no buildable development target"
		return base_row
	if String(profile.get("rare_resource_id", "")) not in RARE_RESOURCE_IDS:
		base_row["error"] = "town development_balance missing live rare_resource_id"
		return base_row

	var start_tile := Vector2i(int(authored_town.get("x", 0)), int(authored_town.get("y", 0)))
	var source_session = ScenarioFactory.create_session(
		scenario_id,
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	if source_session == null:
		base_row["error"] = "ScenarioFactory.create_session returned null"
		return base_row
	OverworldRules.normalize_overworld_state(source_session)
	var source_evidence := _secure_development_sources(source_session, faction_id, required_resource_ids)
	var delayed_source_replay := _run_delayed_source_replay(
		scenario_id,
		placement_id,
		faction_id,
		config,
		start_tile,
		required_resource_ids,
		target_buildings
	)
	var source_town := _town(source_session, placement_id)
	if source_town.is_empty():
		base_row["error"] = "runtime scenario session missing enemy town placement"
		base_row["source_evidence"] = source_evidence
		base_row["delayed_source_replay"] = delayed_source_replay
		return base_row
	var session = source_session
	session.game_state = "overworld"
	session.scenario_status = "in_progress"
	_seed_enemy_treasury(session, faction_id, source_evidence.get("resources_after_claims", {}))
	var build_log := []
	var stalled_days := []
	var rare_spend_events := []
	var same_day_second_build_blocked := false
	var rare_treasury_tracked := _enemy_treasury_has_all_live_keys(session, faction_id)
	var governor_report := EnemyTurnRules.town_governor_pressure_report(session, config, faction_id)
	var governor_report_seen := int(governor_report.get("town_count", 0)) > 0

	for _turn in range(target_turns):
		var before_state := _enemy_state(session, faction_id)
		var before_treasury := _resources(before_state.get("treasury", {}))
		var expected_income := _enemy_daily_income(session, placement_id, faction_id)
		var before_built := _town_building_ids(_town(session, placement_id))
		var turn_result: Dictionary = EnemyTurnRules.run_enemy_town_economy_turn(session, faction_id)
		if not bool(turn_result.get("ok", false)):
			stalled_days.append({
				"day": int(session.day),
				"reason": "enemy_turn_failed",
				"message": String(turn_result.get("message", "")),
			})
		var after_state := _enemy_state(session, faction_id)
		var after_treasury := _resources(after_state.get("treasury", {}))
		var after_built := _town_building_ids(_town(session, placement_id))
		var built_today := _new_buildings(before_built, after_built)
		for building_id in built_today:
			var building := ContentService.get_building(String(building_id))
			var rare_cost := _rare_cost(building.get("cost", {}))
			if not rare_cost.is_empty():
				rare_spend_events.append({
					"day": int(session.day),
					"building_id": String(building_id),
					"spent": rare_cost,
					"treasury_before": before_treasury,
					"expected_income": expected_income,
					"treasury_after": after_treasury,
				})
			build_log.append({
				"day": int(session.day),
				"building_id": String(building_id),
				"cost": building.get("cost", {}),
				"treasury_before": before_treasury,
				"expected_income": expected_income,
				"treasury_after": after_treasury,
			})
		if not built_today.is_empty() and not same_day_second_build_blocked:
			var second_session = _clone_session(session)
			var built_count_before_second := _town_building_ids(_town(second_session, placement_id)).size()
			var second_result: Dictionary = EnemyTurnRules.run_enemy_town_economy_turn(second_session, faction_id)
			var built_count_after_second := _town_building_ids(_town(second_session, placement_id)).size()
			var second_events: Array = second_result.get("events", []) if second_result.get("events", []) is Array else []
			same_day_second_build_blocked = (
				built_count_after_second == built_count_before_second
				and _target_town_event_count(second_events, "ai_town_built", placement_id) == 0
			)
		if _missing_buildings(session, placement_id, target_buildings).is_empty():
			break
		if built_today.is_empty():
			stalled_days.append({
				"day": int(session.day),
				"reason": "no_enemy_build_selected",
				"treasury": after_treasury,
				"open_buildings": _open_building_ids(_town(session, placement_id), target_buildings),
			})
		session.day += 1

	var missing := _missing_buildings(session, placement_id, target_buildings)
	var completed := missing.is_empty()
	var completion_day := int(build_log[-1].get("day", 0)) if not build_log.is_empty() and completed else 0
	var pacing_floor_ok := completed and completion_day >= MIN_COMPLETION_DAY and completion_day <= TARGET_TURNS
	var recruitment_evidence := _ai_recruitment_evidence(session, config, placement_id, faction_id)
	base_row["ok"] = (
		completed
		and pacing_floor_ok
		and same_day_second_build_blocked
		and not rare_spend_events.is_empty()
		and rare_treasury_tracked
		and governor_report_seen
		and bool(recruitment_evidence.get("seven_tier_recruitment_seen", false))
		and bool(recruitment_evidence.get("selected_recruitment_seen", false))
		and bool(delayed_source_replay.get("ok", false))
		and String(session.scenario_id) == scenario_id
		and _source_covers_required_resources(source_evidence, required_resource_ids)
	)
	base_row["completed"] = completed
	base_row["completion_day"] = completion_day
	base_row["min_completion_day"] = MIN_COMPLETION_DAY
	base_row["pacing_floor_ok"] = pacing_floor_ok
	base_row["build_count"] = build_log.size()
	base_row["missing_buildings"] = missing
	base_row["same_day_second_build_blocked"] = same_day_second_build_blocked
	base_row["rare_treasury_tracked"] = rare_treasury_tracked
	base_row["governor_report_seen"] = governor_report_seen
	base_row["rare_spend_observed"] = not rare_spend_events.is_empty()
	base_row["ai_recruitment_evidence"] = recruitment_evidence
	base_row["ai_recruitment_candidate_count"] = int(recruitment_evidence.get("candidate_count", 0))
	base_row["ai_recruitment_tier_candidate_count"] = int(recruitment_evidence.get("tier_candidate_count", 0))
	base_row["ai_recruitment_affordable_candidate_count"] = int(recruitment_evidence.get("affordable_candidate_count", 0))
	base_row["ai_recruitment_selected_seen"] = bool(recruitment_evidence.get("selected_recruitment_seen", false))
	base_row["ai_seven_tier_recruitment_seen"] = bool(recruitment_evidence.get("seven_tier_recruitment_seen", false))
	base_row["rare_spend_events"] = rare_spend_events
	base_row["source_evidence"] = source_evidence
	base_row["delayed_source_replay_seen"] = true
	base_row["delayed_source_replay_ok"] = bool(delayed_source_replay.get("ok", false))
	base_row["delayed_source_replay"] = delayed_source_replay
	base_row["delayed_source_save_resume_seen"] = bool(delayed_source_replay.get("save_resume_seen", false))
	base_row["delayed_source_save_resume_ok"] = bool(delayed_source_replay.get("save_resume_ok", false))
	base_row["full_session_used"] = String(session.scenario_id) == scenario_id
	base_row["scenario_map_size"] = _map_size_payload(OverworldRules.derive_map_size(session))
	base_row["scenario_resource_node_count"] = _array_size(session.overworld.get("resource_nodes", []))
	base_row["scenario_encounter_count"] = _array_size(session.overworld.get("encounters", []))
	base_row["scenario_enemy_state_count"] = _array_size(session.overworld.get("enemy_states", []))
	base_row["ending_treasury"] = _resources(_enemy_state(session, faction_id).get("treasury", {}))
	base_row["stalled_days"] = stalled_days.slice(0, 5)
	base_row["build_log"] = build_log
	if not bool(base_row.get("ok", false)):
		base_row["error"] = _runway_error(base_row)
	return base_row

func _run_delayed_source_replay(
	scenario_id: String,
	placement_id: String,
	faction_id: String,
	config: Dictionary,
	start_tile: Vector2i,
	required_resource_ids: Array,
	target_buildings: Array
) -> Dictionary:
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
	session.game_state = "overworld"
	session.scenario_status = "in_progress"
	var source_schedule := _development_source_schedule(session, start_tile, required_resource_ids)
	var errors := []
	if not _schedule_covers_required_resources(source_schedule, required_resource_ids):
		errors.append("delayed AI replay source schedule does not cover all required non-gold resources")
	EnemyTurnRules.normalize_enemy_states(session)
	var build_log := []
	var stalled_days := []
	var rare_spend_events := []
	var save_resume := {}
	var delayed_source_seen := false
	var rare_treasury_tracked := _enemy_treasury_has_all_live_keys(session, faction_id)
	for _turn in range(TARGET_TURNS):
		var applied_sources := _apply_due_development_sources(session, source_schedule, int(session.day), faction_id)
		if not applied_sources.is_empty():
			delayed_source_seen = true
		var before_state := _enemy_state(session, faction_id)
		var before_treasury := _resources(before_state.get("treasury", {}))
		var expected_income := _enemy_daily_income(session, placement_id, faction_id)
		var before_built := _town_building_ids(_town(session, placement_id))
		var turn_result: Dictionary = EnemyTurnRules.run_enemy_town_economy_turn(session, faction_id)
		if not bool(turn_result.get("ok", false)):
			stalled_days.append({
				"day": int(session.day),
				"reason": "enemy_turn_failed",
				"message": String(turn_result.get("message", "")),
				"applied_sources": applied_sources,
			})
		var after_state := _enemy_state(session, faction_id)
		var after_treasury := _resources(after_state.get("treasury", {}))
		var after_built := _town_building_ids(_town(session, placement_id))
		var built_today := _new_buildings(before_built, after_built)
		for building_id in built_today:
			var building := ContentService.get_building(String(building_id))
			var rare_cost := _rare_cost(building.get("cost", {}))
			if not rare_cost.is_empty():
				rare_spend_events.append({
					"day": int(session.day),
					"building_id": String(building_id),
					"spent": rare_cost,
					"treasury_before": before_treasury,
					"expected_income": expected_income,
					"treasury_after": after_treasury,
				})
			build_log.append({
				"day": int(session.day),
				"building_id": String(building_id),
				"cost": building.get("cost", {}),
				"treasury_before": before_treasury,
				"expected_income": expected_income,
				"treasury_after": after_treasury,
				"applied_sources": applied_sources,
			})
			if save_resume.is_empty() and delayed_source_seen and not rare_cost.is_empty():
				save_resume = _delayed_source_save_resume_checkpoint(
					session,
					placement_id,
					faction_id,
					String(building_id),
					source_schedule,
					required_resource_ids
				)
				if save_resume.has("session"):
					session = save_resume.get("session")
				if not bool(save_resume.get("ok", false)):
					stalled_days.append({
						"day": int(session.day),
						"reason": "delayed_source_ai_save_resume_failed",
						"message": String(save_resume.get("error", "")),
					})
					break
		if _missing_buildings(session, placement_id, target_buildings).is_empty():
			break
		if built_today.is_empty():
			stalled_days.append({
				"day": int(session.day),
				"reason": "no_enemy_build_selected",
				"treasury": after_treasury,
				"open_buildings": _open_building_ids(_town(session, placement_id), target_buildings),
				"applied_sources": applied_sources,
			})
		session.day += 1
	var missing := _missing_buildings(session, placement_id, target_buildings)
	var completed := missing.is_empty()
	var recruitment_evidence := _ai_recruitment_evidence(session, config, placement_id, faction_id)
	if not completed:
		errors.append("enemy town did not complete delayed-source development replay")
	if rare_spend_events.is_empty():
		errors.append("delayed-source AI replay did not spend a rare resource")
	if not rare_treasury_tracked:
		errors.append("delayed-source AI replay did not preserve full enemy treasury keys")
	if not bool(recruitment_evidence.get("seven_tier_recruitment_seen", false)):
		errors.append("delayed-source AI replay did not expose seven-tier recruitment candidates")
	if not bool(recruitment_evidence.get("selected_recruitment_seen", false)):
		errors.append("delayed-source AI replay did not expose an affordable selected recruitment")
	if save_resume.is_empty():
		errors.append("delayed-source AI replay did not save/resume after source acquisition and rare construction")
	elif not bool(save_resume.get("ok", false)):
		errors.append("delayed-source AI save/resume failed: %s" % String(save_resume.get("error", "unknown")))
	return {
		"ok": errors.is_empty(),
		"schema": "active_scenario_ai_town_delayed_source_replay_v1",
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
		"same_day_second_build_blocked": null,
		"rare_treasury_tracked": rare_treasury_tracked,
		"rare_spend_observed": not rare_spend_events.is_empty(),
		"rare_spend_events": rare_spend_events,
		"ai_recruitment_evidence": recruitment_evidence,
		"save_resume_seen": not save_resume.is_empty(),
		"save_resume_ok": bool(save_resume.get("ok", false)),
		"save_resume": _without_session(save_resume),
		"ending_treasury": _resources(_enemy_state(session, faction_id).get("treasury", {})),
		"stalled_days": stalled_days.slice(0, 5),
		"build_log": build_log,
		"errors": errors,
		"error": "; ".join(errors),
	}

func _delayed_source_save_resume_checkpoint(
	session,
	placement_id: String,
	faction_id: String,
	built_building_id: String,
	source_schedule: Array,
	required_resource_ids: Array
) -> Dictionary:
	session.game_state = "overworld"
	session.scenario_status = "in_progress"
	var before_signature := _delayed_source_resume_signature(session, placement_id, faction_id, source_schedule, required_resource_ids)
	var save_result: Dictionary = SaveService.save_runtime_manual_session(session, DELAYED_SOURCE_SAVE_RESUME_SLOT)
	if not bool(save_result.get("ok", false)):
		return {"ok": false, "stage": "save", "error": String(save_result.get("message", ""))}
	var summary: Dictionary = SaveService.inspect_manual_slot(DELAYED_SOURCE_SAVE_RESUME_SLOT)
	var restored = SaveService.restore_manual_session(DELAYED_SOURCE_SAVE_RESUME_SLOT)
	if restored == null:
		return {"ok": false, "stage": "restore", "error": "restore_manual_session returned null", "summary": summary}
	OverworldRules.normalize_overworld_state(restored)
	EnemyTurnRules.normalize_enemy_states(restored)
	restored.game_state = "overworld"
	restored.scenario_status = "in_progress"
	var after_signature := _delayed_source_resume_signature(restored, placement_id, faction_id, source_schedule, required_resource_ids)
	var before_second_count := _town_building_ids(_town(restored, placement_id)).size()
	var second_result: Dictionary = EnemyTurnRules.run_enemy_town_economy_turn(restored, faction_id)
	var after_second_count := _town_building_ids(_town(restored, placement_id)).size()
	var second_events: Array = second_result.get("events", []) if second_result.get("events", []) is Array else []
	var same_day_guard_ok := (
		after_second_count == before_second_count
		and _target_town_event_count(second_events, "ai_town_built", placement_id) == 0
	)
	var signature_ok := JSON.stringify(before_signature) == JSON.stringify(after_signature)
	var resume_target_overworld := String(summary.get("resume_target", "")) == "overworld"
	var source_state_preserved := bool(after_signature.get("source_schedule_state_matches", false))
	var treasury_state_preserved := bool(after_signature.get("enemy_treasury_has_all_live_keys", false))
	var target_build_preserved := String(built_building_id) in _string_array(after_signature.get("target_town", {}).get("built_buildings", []))
	var ok := (
		signature_ok
		and same_day_guard_ok
		and resume_target_overworld
		and source_state_preserved
		and treasury_state_preserved
		and target_build_preserved
	)
	return {
		"ok": ok,
		"session": restored,
		"slot": DELAYED_SOURCE_SAVE_RESUME_SLOT,
		"built_building_id": built_building_id,
		"signature_ok": signature_ok,
		"same_day_guard_after_restore": same_day_guard_ok,
		"resume_target_overworld": resume_target_overworld,
		"source_state_preserved": source_state_preserved,
		"treasury_state_preserved": treasury_state_preserved,
		"target_build_preserved": target_build_preserved,
		"save_version": int(restored.save_version),
		"summary_resume_target": String(summary.get("resume_target", "")),
		"second_turn_event_count": _target_town_event_count(second_events, "ai_town_built", placement_id),
		"signature_before": before_signature,
		"signature_after": after_signature,
		"error": "" if ok else _delayed_source_save_resume_error(signature_ok, same_day_guard_ok, resume_target_overworld, source_state_preserved, treasury_state_preserved, target_build_preserved),
	}

func _delayed_source_save_resume_error(
	signature_ok: bool,
	same_day_guard_ok: bool,
	resume_target_overworld: bool,
	source_state_preserved: bool,
	treasury_state_preserved: bool,
	target_build_preserved: bool
) -> String:
	if not signature_ok:
		return "AI economy/town/source signature changed after restore"
	if not same_day_guard_ok:
		return "AI same-day build guard was not preserved after restore"
	if not resume_target_overworld:
		return "save summary did not resume to overworld"
	if not source_state_preserved:
		return "delayed source node state was not preserved"
	if not treasury_state_preserved:
		return "enemy treasury state did not preserve all live resources"
	if not target_build_preserved:
		return "target rare-resource building was not preserved"
	return "unknown delayed-source AI save/resume failure"

func _delayed_source_resume_signature(
	session,
	placement_id: String,
	faction_id: String,
	source_schedule: Array,
	required_resource_ids: Array
) -> Dictionary:
	return {
		"save_version": int(session.save_version),
		"scenario_id": String(session.scenario_id),
		"day": int(session.day),
		"game_state": String(session.game_state),
		"scenario_status": String(session.scenario_status),
		"enemy_treasury": _resources(_enemy_state(session, faction_id).get("treasury", {})),
		"enemy_treasury_has_all_live_keys": _enemy_treasury_has_all_live_keys(session, faction_id),
		"target_town": _town_development_signature(_town(session, placement_id)),
		"applied_source_nodes": _applied_source_node_signature(session, source_schedule),
		"source_schedule_state_matches": _applied_source_nodes_match_schedule(session, source_schedule, required_resource_ids, faction_id),
	}

func _town_development_signature(town: Dictionary) -> Dictionary:
	return {
		"placement_id": String(town.get("placement_id", "")),
		"town_id": String(town.get("town_id", "")),
		"owner": String(town.get("owner", "")),
		"controlling_faction_id": String(town.get("controlling_faction_id", "")),
		"built_buildings": _string_array(town.get("built_buildings", [])),
		"last_build_day": int(town.get("last_build_day", 0)),
		"available_recruits": _int_dictionary(town.get("available_recruits", {})),
	}

func _ai_recruitment_evidence(session, config: Dictionary, placement_id: String, faction_id: String) -> Dictionary:
	var town := _town(session, placement_id)
	var treasury := _resources(_enemy_state(session, faction_id).get("treasury", {}))
	var report: Dictionary = EnemyTurnRules.town_recruitment_pressure_report(session, config, town, treasury, faction_id)
	var candidates: Array = report.get("candidates", []) if report.get("candidates", []) is Array else []
	var town_template := ContentService.get_town(String(town.get("town_id", "")))
	var ladder_faction_id := String(town_template.get("faction_id", faction_id))
	var ladder_ids := _faction_ladder_ids(ladder_faction_id)
	var candidate_ids := {}
	var tier_candidate_count := 0
	var affordable_candidate_count := 0
	for candidate_value in candidates:
		if not (candidate_value is Dictionary):
			continue
		var candidate: Dictionary = candidate_value
		var unit_id := String(candidate.get("unit_id", ""))
		candidate_ids[unit_id] = true
		if unit_id in ladder_ids:
			tier_candidate_count += 1
		if int(candidate.get("recruit_count", 0)) > 0:
			affordable_candidate_count += 1
	var missing_ladder_ids := []
	for unit_id in ladder_ids:
		if not bool(candidate_ids.get(String(unit_id), false)):
			missing_ladder_ids.append(String(unit_id))
	var selected: Dictionary = report.get("selected_recruitment", {}) if report.get("selected_recruitment", {}) is Dictionary else {}
	return {
		"schema": "active_scenario_ai_town_recruitment_surface_v1",
		"placement_id": placement_id,
		"controller_faction_id": faction_id,
		"ladder_faction_id": ladder_faction_id,
		"candidate_count": candidates.size(),
		"tier_candidate_count": tier_candidate_count,
		"affordable_candidate_count": affordable_candidate_count,
		"expected_tier_count": SIGNATURE_TIER_COUNT,
		"ladder_unit_ids": ladder_ids,
		"missing_ladder_unit_ids": missing_ladder_ids,
		"seven_tier_recruitment_seen": ladder_ids.size() == SIGNATURE_TIER_COUNT and missing_ladder_ids.is_empty(),
		"selected_recruitment_seen": not selected.is_empty() and int(selected.get("recruit_count", 0)) > 0,
		"selected_recruitment": selected,
	}

func _faction_ladder_ids(faction_id: String) -> Array:
	var faction := ContentService.get_faction(faction_id)
	return _string_array(faction.get("unit_ladder_ids", []))

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

func _applied_source_nodes_match_schedule(session, source_schedule: Array, required_resource_ids: Array, faction_id: String) -> bool:
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
		if bool(schedule.get("persistent_control", false)) and String(node.get("collected_by_faction_id", "")) != faction_id:
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

func _clone_session(session):
	var clone = SessionStateStore.SessionData.new()
	clone.from_dict(session.to_dict())
	return clone

func _seed_enemy_treasury(session, faction_id: String, resources: Dictionary) -> void:
	EnemyTurnRules.normalize_enemy_states(session)
	var states: Array = session.overworld.get("enemy_states", [])
	for index in range(states.size()):
		if not (states[index] is Dictionary):
			continue
		var state: Dictionary = states[index]
		if String(state.get("faction_id", "")) != faction_id:
			continue
		state["treasury"] = _add_resource_sets(_resources(state.get("treasury", {})), _resources(resources))
		states[index] = state
		break
	session.overworld["enemy_states"] = states

func _secure_development_sources(session, faction_id: String, required_resource_ids: Array) -> Dictionary:
	var nodes: Array = session.overworld.get("resource_nodes", [])
	var treasury := _blank_resources()
	var source_rows := []
	var secured_nodes := []
	var secured_resource_ids := {}
	var secured_income := {}
	var secured_claims := {}
	var covered_resource_ids := {}
	for index in range(nodes.size()):
		if not (nodes[index] is Dictionary):
			continue
		if _source_covers_required_resources({"secured_resource_ids": _sorted_keys(covered_resource_ids)}, required_resource_ids):
			break
		var node: Dictionary = nodes[index]
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		if site.is_empty():
			continue
		var claim_rewards: Dictionary = site.get("claim_rewards", site.get("rewards", {})) if site.get("claim_rewards", site.get("rewards", {})) is Dictionary else {}
		var control_income: Dictionary = site.get("control_income", {}) if site.get("control_income", {}) is Dictionary else {}
		var persistent_control := bool(site.get("persistent_control", false))
		var relevant_claims := _filter_resources(claim_rewards, required_resource_ids)
		var relevant_income := _filter_resources(control_income, required_resource_ids)
		var applied_claims := {} if persistent_control else relevant_claims
		var applied_income := relevant_income if persistent_control else {}
		if applied_claims.is_empty() and applied_income.is_empty():
			continue
		var source_resource_ids := {}
		for resource_id in applied_claims.keys():
			source_resource_ids[String(resource_id)] = true
		for resource_id in applied_income.keys():
			source_resource_ids[String(resource_id)] = true
		var adds_uncovered_required_resource := false
		for resource_id in source_resource_ids.keys():
			if not bool(covered_resource_ids.get(String(resource_id), false)):
				adds_uncovered_required_resource = true
				break
		if not adds_uncovered_required_resource:
			continue
		if not applied_claims.is_empty():
			treasury = _add_resource_sets(treasury, applied_claims)
			node["collected"] = true
			node["collected_day"] = int(session.day)
			node["collected_by_faction_id"] = faction_id
			secured_claims = _add_resource_sets(secured_claims, applied_claims)
		if not applied_income.is_empty():
			node["collected_by_faction_id"] = faction_id
			secured_income = _add_resource_sets(secured_income, applied_income)
		for resource_id in applied_claims.keys():
			secured_resource_ids[String(resource_id)] = true
			covered_resource_ids[String(resource_id)] = true
		for resource_id in applied_income.keys():
			secured_resource_ids[String(resource_id)] = true
			covered_resource_ids[String(resource_id)] = true
		source_rows.append({
			"placement_id": String(node.get("placement_id", "")),
			"site_id": String(node.get("site_id", "")),
			"persistent_control": persistent_control,
			"claim_rewards": applied_claims,
			"control_income": applied_income,
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
		"source_adoption_policy": "minimal_required_resource_coverage",
		"secured_source_count": source_rows.size(),
		"secured_resource_ids": _sorted_keys(secured_resource_ids),
		"secured_claims": secured_claims,
		"secured_daily_income": secured_income,
		"resources_after_claims": treasury,
		"secured_resource_nodes": secured_nodes,
		"sources": source_rows,
	}

func _enemy_daily_income(session, placement_id: String, faction_id: String) -> Dictionary:
	var income := _blank_resources()
	var town := _town(session, placement_id)
	if not town.is_empty():
		income = _add_resource_sets(income, OverworldRules.town_income(town, session))
	income = _add_resource_sets(income, OverworldRules.controlled_resource_site_income(session, faction_id))
	return income

func _runway_error(row: Dictionary) -> String:
	if not bool(row.get("completed", false)):
		return "enemy town did not complete its active-scenario AI development runway"
	if not bool(row.get("pacing_floor_ok", false)):
		return "enemy town completed outside day-%d-to-day-%d pacing window" % [MIN_COMPLETION_DAY, TARGET_TURNS]
	if not bool(row.get("same_day_second_build_blocked", false)):
		return "enemy same-day second build was not blocked"
	if not bool(row.get("rare_spend_observed", false)):
		return "enemy high-tier rare-resource spend was not observed"
	if not bool(row.get("rare_treasury_tracked", false)):
		return "enemy treasury did not preserve all live stockpile resource keys"
	if not bool(row.get("governor_report_seen", false)):
		return "enemy town governor report did not cover the target faction"
	if not bool(row.get("full_session_used", false)):
		return "enemy development did not run inside the active scenario session"
	if not _source_covers_required_resources(row.get("source_evidence", {}), row.get("required_resource_ids", [])):
		return "secured scenario sources did not cover required enemy build resources"
	return "unknown AI runway failure"

func _source_covers_required_resources(source_evidence: Dictionary, required_resource_ids: Array) -> bool:
	var secured := _string_array(source_evidence.get("secured_resource_ids", []))
	for resource_id in required_resource_ids:
		if String(resource_id) in ["gold"]:
			continue
		if String(resource_id) not in secured:
			return false
	return true

func _enemy_treasury_has_all_live_keys(session, faction_id: String) -> bool:
	var treasury: Dictionary = _enemy_state(session, faction_id).get("treasury", {})
	for resource_id in LIVE_STOCKPILE_RESOURCE_IDS:
		if String(resource_id) not in treasury:
			return false
	return true

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

func _new_buildings(before: Array, after: Array) -> Array:
	var result := []
	for building_id in after:
		if String(building_id) not in before:
			result.append(String(building_id))
	return result

func _town_building_ids(town: Dictionary) -> Array:
	return _string_array(town.get("built_buildings", []))

func _target_town_event_count(events: Array, event_type: String, town_placement_id: String) -> int:
	var count := 0
	for event in events:
		if (
			event is Dictionary
			and String(event.get("event_type", "")) == event_type
			and String(event.get("actor_id", "")) == town_placement_id
		):
			count += 1
	return count

func _enemy_state(session, faction_id: String) -> Dictionary:
	for state in session.overworld.get("enemy_states", []):
		if state is Dictionary and String(state.get("faction_id", "")) == faction_id:
			return state
	return {}

func _town(session, placement_id: String) -> Dictionary:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("placement_id", "")) == placement_id:
			return town
	return {}

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

func _rare_cost(cost_value: Variant) -> Dictionary:
	var cost: Dictionary = cost_value if cost_value is Dictionary else {}
	var result := {}
	for resource_id in RARE_RESOURCE_IDS:
		if int(cost.get(resource_id, 0)) > 0:
			result[resource_id] = int(cost.get(resource_id, 0))
	return result

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

func _apply_due_development_sources(session, source_schedule: Array, day: int, faction_id: String) -> Array:
	var applied_rows := []
	var nodes: Array = session.overworld.get("resource_nodes", [])
	var claim_total := _blank_resources()
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
			node["collected_by_faction_id"] = faction_id
		var claims: Dictionary = row.get("claim_rewards", {}) if row.get("claim_rewards", {}) is Dictionary else {}
		if not claims.is_empty() and not bool(node.get("collected", false)):
			claim_total = _add_resource_sets(claim_total, claims)
			node["collected"] = true
			node["collected_day"] = day
			node["collected_by_faction_id"] = faction_id
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
	if not _resources_empty(claim_total):
		_seed_enemy_treasury(session, faction_id, claim_total)
	return applied_rows

func _resource_node_index(nodes: Array, placement_id: String) -> int:
	for index in range(nodes.size()):
		if nodes[index] is Dictionary and String(nodes[index].get("placement_id", "")) == placement_id:
			return index
	return -1

func _resources_empty(resources: Dictionary) -> bool:
	for resource_id in resources.keys():
		if int(resources.get(resource_id, 0)) > 0:
			return false
	return true

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

func _add_resource_sets(left: Dictionary, right: Dictionary) -> Dictionary:
	var result := _resources(left)
	for resource_id in right.keys():
		var id := String(resource_id)
		result[id] = int(result.get(id, 0)) + int(right.get(resource_id, 0))
	return result

func _resources(resources: Variant) -> Dictionary:
	var result := {}
	var source: Dictionary = resources if resources is Dictionary else {}
	for resource_id in LIVE_STOCKPILE_RESOURCE_IDS:
		result[String(resource_id)] = int(source.get(String(resource_id), 0))
	return result

func _blank_resources() -> Dictionary:
	return _resources({})

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
	return _is_launch_surface_available(scenario, "campaign") or _is_launch_surface_available(scenario, "skirmish")

func _launch_surfaces(scenario: Dictionary) -> Array:
	var surfaces := []
	if _is_launch_surface_available(scenario, "campaign"):
		surfaces.append("campaign")
	if _is_launch_surface_available(scenario, "skirmish"):
		surfaces.append("skirmish")
	return surfaces

func _is_launch_surface_available(scenario: Dictionary, surface_id: String) -> bool:
	var selection: Dictionary = scenario.get("selection", {}) if scenario.get("selection", {}) is Dictionary else {}
	var availability: Dictionary = selection.get("availability", {}) if selection.get("availability", {}) is Dictionary else {}
	return bool(availability.get(surface_id, false))

func _enemy_towns(scenario: Dictionary) -> Array:
	var result := []
	for town in scenario.get("towns", []):
		if town is Dictionary and String(town.get("owner", "")) == "enemy":
			result.append(town)
	return result

func _enemy_config_for_faction(scenario: Dictionary, faction_id: String) -> Dictionary:
	for config in scenario.get("enemy_factions", []):
		if config is Dictionary and String(config.get("faction_id", "")) == faction_id:
			return config
	return {}

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
