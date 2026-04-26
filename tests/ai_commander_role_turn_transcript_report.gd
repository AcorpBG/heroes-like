extends Node

const REPORT_ID := "AI_COMMANDER_ROLE_TURN_TRANSCRIPT_REPORT"
const RIVER_PASS := "river-pass"
const GLASSROAD := "glassroad-sundering"
const MIRECLAW := "faction_mireclaw"
const EMBERCOURT := "faction_embercourt"
const TREASURY := {"gold": 5200, "wood": 8, "ore": 8}

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var cases := []
	var river_case := _river_pass_mireclaw_signal_yard_turn()
	if river_case.is_empty():
		return
	cases.append(river_case)
	var glassroad_case := _glassroad_embercourt_relay_turn()
	if glassroad_case.is_empty():
		return
	cases.append(glassroad_case)

	var public_events := []
	for case_report in cases:
		if not (case_report is Dictionary):
			continue
		if not bool(case_report.get("ok", false)):
			_fail("Case %s did not pass transcript checks" % String(case_report.get("case_id", "")))
			return
		for event in case_report.get("public_transcript_events", []):
			if event is Dictionary:
				public_events.append(event)
	var leak_check := EnemyAdventureRules.commander_role_turn_transcript_public_leak_check(public_events)
	if not bool(leak_check.get("ok", false)):
		_fail(String(leak_check.get("error", "public transcript leak check failed")))
		return

	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_status": "derived_turn_transcript_report_only",
		"behavior_policy": "observe_existing_enemy_turn_only",
		"save_policy": "no_commander_role_state_write",
		"cases": cases,
		"public_leak_check": leak_check,
		"validation_caveats": [
			"Each fixture calls EnemyTurnRules.run_enemy_turn once; current run_enemy_turn does not increment session.day by itself.",
			"Transcript records are derived from fixture snapshots and compact existing event vocabulary only.",
			"Town-governor records are supporting references, not transcript authority or score-table public output.",
		],
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _river_pass_mireclaw_signal_yard_turn() -> Dictionary:
	var session = _base_session(RIVER_PASS)
	var config := _enemy_config(RIVER_PASS, MIRECLAW)
	_set_enemy_state_patch(session, MIRECLAW, {"treasury": TREASURY.duplicate(true), "pressure": 0})
	_set_resource_controller(session, "river_free_company", "player")
	_set_resource_controller(session, "river_signal_post", "player")
	_add_active_resource_raid(
		session,
		config,
		MIRECLAW,
		"hero_vaska",
		"transcript_mireclaw_vaska_raid",
		"encounter_mire_raid",
		"river_free_company",
		{"x": 1, "y": 4}
	)
	var before_options := {
		"origin": {"x": 7, "y": 1},
		"supporting_front_id": "riverwatch_signal_yard",
		"role_assignments": [
			{"roster_hero_id": "hero_vaska", "target_id": "river_free_company", "fixture_state": {"fixture_previous_controller": MIRECLAW}},
			{"roster_hero_id": "hero_sable", "target_id": "river_signal_post", "fixture_state": {"fixture_primary_target_covered": "river_free_company"}},
		],
		"town_governor_reports": [EnemyTurnRules.town_governor_pressure_report(session, config, MIRECLAW)],
	}
	var before_snapshot := EnemyAdventureRules.commander_role_turn_snapshot(session, config, MIRECLAW, before_options)
	var turn_result := EnemyTurnRules.run_enemy_turn(session)
	var after_options := {
		"origin": {"x": 7, "y": 1},
		"supporting_front_id": "riverwatch_signal_yard",
		"role_assignments": [
			{"roster_hero_id": "hero_vaska", "target_id": "river_free_company", "fixture_state": {"fixture_threatened_by_player_front": true}},
			{"roster_hero_id": "hero_sable", "target_id": "river_signal_post", "fixture_state": {"fixture_primary_target_covered": "river_free_company"}},
		],
		"town_governor_reports": [EnemyTurnRules.town_governor_pressure_report(session, config, MIRECLAW)],
	}
	var after_snapshot := EnemyAdventureRules.commander_role_turn_snapshot(session, config, MIRECLAW, after_options)
	var report := EnemyAdventureRules.commander_role_turn_transcript_report(
		before_snapshot,
		after_snapshot,
		config,
		turn_result,
		{
			"case_id": "river_pass_mireclaw_signal_yard_turn",
			"fixture_setup": {
				"resource_controllers": {
					"river_free_company": "player",
					"river_signal_post": "player",
				},
				"active_raid": "transcript_mireclaw_vaska_raid",
				"behavior_call_count": 1,
			},
		}
	)
	_assert_case(report, "river_pass_mireclaw_signal_yard_turn", "river_free_company")
	return report

func _glassroad_embercourt_relay_turn() -> Dictionary:
	var session = _base_session(GLASSROAD)
	var config := _enemy_config(GLASSROAD, EMBERCOURT)
	_set_enemy_state_patch(session, EMBERCOURT, {"treasury": TREASURY.duplicate(true), "pressure": 0})
	_set_resource_controller(session, "glassroad_watch_relay", "player")
	_set_resource_controller(session, "glassroad_starlens", EMBERCOURT)
	_add_active_resource_raid(
		session,
		config,
		EMBERCOURT,
		"hero_caelen",
		"transcript_embercourt_caelen_raid",
		"encounter_ember_raid",
		"glassroad_watch_relay",
		{"x": 3, "y": 3}
	)
	var before_options := {
		"origin": {"x": 9, "y": 1},
		"supporting_front_id": "glassroad_charter_front",
		"role_assignments": [
			{"roster_hero_id": "hero_caelen", "target_id": "glassroad_watch_relay", "fixture_state": {"fixture_previous_controller": EMBERCOURT}},
			{"roster_hero_id": "hero_seren", "target_id": "glassroad_starlens", "fixture_state": {"fixture_recently_secured": true}},
		],
		"town_governor_reports": [EnemyTurnRules.town_governor_pressure_report(session, config, EMBERCOURT)],
	}
	var before_snapshot := EnemyAdventureRules.commander_role_turn_snapshot(session, config, EMBERCOURT, before_options)
	var turn_result := EnemyTurnRules.run_enemy_turn(session)
	var after_options := {
		"origin": {"x": 9, "y": 1},
		"supporting_front_id": "glassroad_charter_front",
		"role_assignments": [
			{"roster_hero_id": "hero_caelen", "target_id": "glassroad_watch_relay", "fixture_state": {"fixture_threatened_by_player_front": true}},
			{"roster_hero_id": "hero_seren", "target_id": "glassroad_starlens", "fixture_state": {"fixture_recently_secured": true}},
		],
		"town_governor_reports": [EnemyTurnRules.town_governor_pressure_report(session, config, EMBERCOURT)],
	}
	var after_snapshot := EnemyAdventureRules.commander_role_turn_snapshot(session, config, EMBERCOURT, after_options)
	var report := EnemyAdventureRules.commander_role_turn_transcript_report(
		before_snapshot,
		after_snapshot,
		config,
		turn_result,
		{
			"case_id": "glassroad_embercourt_relay_turn",
			"fixture_setup": {
				"resource_controllers": {
					"glassroad_watch_relay": "player",
					"glassroad_starlens": EMBERCOURT,
				},
				"active_raid": "transcript_embercourt_caelen_raid",
				"behavior_call_count": 1,
			},
		}
	)
	_assert_case(report, "glassroad_embercourt_relay_turn", "glassroad_watch_relay")
	_assert_role_present(report.get("derived_role_proposals", {}).get("before_turn", []), "hero_seren", EnemyAdventureRules.COMMANDER_ROLE_STABILIZER)
	_assert_role_present(report.get("derived_role_proposals", {}).get("after_turn", []), "hero_caelen", EnemyAdventureRules.COMMANDER_ROLE_DEFENDER)
	return report

func _assert_case(report: Dictionary, case_id: String, expected_arrival_target_id: String) -> void:
	if report.is_empty():
		_fail("%s returned an empty transcript report" % case_id)
		return
	if not bool(report.get("ok", false)):
		_fail("%s transcript report failed: %s" % [case_id, JSON.stringify(report)])
		return
	if report.get("phase_records", []).size() != 9:
		_fail("%s expected 9 phase records, got %d" % [case_id, report.get("phase_records", []).size()])
		return
	if report.get("raid_movement_summary", []).is_empty():
		_fail("%s missing raid movement summary" % case_id)
		return
	if _arrival_for_target(report.get("raid_arrival_summary", []), expected_arrival_target_id).is_empty():
		_fail("%s missing arrival summary for %s" % [case_id, expected_arrival_target_id])
		return
	if report.get("town_governor_supporting_event_refs", []).is_empty():
		_fail("%s missing town-governor supporting refs" % case_id)
		return
	if report.get("public_transcript_events", []).is_empty():
		_fail("%s missing public transcript events" % case_id)
		return
	var no_ops: Array = report.get("target_no_op_records", [])
	if no_ops.is_empty():
		_fail("%s expected at least one recognized no-op record" % case_id)
		return
	for no_op in no_ops:
		if not (no_op is Dictionary):
			continue
		if String(no_op.get("no_op_reason", "")) not in EnemyAdventureRules.COMMANDER_ROLE_TURN_NO_OP_REASONS:
			_fail("%s used unrecognized no-op reason %s" % [case_id, no_op.get("no_op_reason", "")])
			return

func _assert_role_present(proposals: Array, roster_hero_id: String, role: String) -> void:
	for proposal in proposals:
		if not (proposal is Dictionary):
			continue
		if String(proposal.get("roster_hero_id", "")) == roster_hero_id and String(proposal.get("role", "")) == role:
			return
	_fail("Missing role %s for %s in proposals %s" % [role, roster_hero_id, JSON.stringify(proposals)])

func _arrival_for_target(arrivals: Array, target_id: String) -> Dictionary:
	for arrival in arrivals:
		if arrival is Dictionary and String(arrival.get("target_id", "")) == target_id:
			return arrival
	return {}

func _base_session(scenario_id: String):
	var session = ScenarioFactory.create_session(
		scenario_id,
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	OverworldRules.normalize_overworld_state(session)
	OverworldRules.refresh_fog_of_war(session)
	EnemyTurnRules.normalize_enemy_states(session)
	EnemyAdventureRules.normalize_all_commander_rosters(session)
	return session

func _add_active_resource_raid(
	session,
	config: Dictionary,
	faction_id: String,
	roster_hero_id: String,
	placement_id: String,
	encounter_id: String,
	target_id: String,
	origin: Dictionary
) -> void:
	var target := _resource_target(session, target_id)
	if target.is_empty():
		_fail("Missing resource target %s" % target_id)
		return
	var target_view := EnemyAdventureRules.commander_role_resource_target_view(session, config, faction_id, target_id, origin)
	var raid := {
		"placement_id": placement_id,
		"encounter_id": encounter_id,
		"x": int(origin.get("x", 0)),
		"y": int(origin.get("y", 0)),
		"difficulty": "pressure",
		"combat_seed": hash("%s:%s" % [String(session.scenario_id), placement_id]),
		"spawned_by_faction_id": faction_id,
		"days_active": 0,
		"arrived": false,
		"goal_distance": 9999,
		"target_kind": "resource",
		"target_placement_id": target_id,
		"target_label": String(target.get("label", target_id)),
		"target_x": int(target.get("x", 0)),
		"target_y": int(target.get("y", 0)),
		"goal_x": int(target.get("x", 0)),
		"goal_y": int(target.get("y", 0)),
		"target_public_reason": String(target_view.get("public_reason", "")),
		"target_reason_codes": target_view.get("reason_codes", []),
		"target_public_importance": String(target_view.get("public_importance", "high")),
		"target_debug_reason": String(target_view.get("debug_reason", "")),
	}
	raid["enemy_commander_state"] = EnemyAdventureRules.build_raid_commander_state(
		raid,
		roster_hero_id,
		faction_id,
		session,
		{},
		EnemyAdventureRules.commander_roster_for_faction(session, faction_id)
	)
	raid = EnemyAdventureRules.ensure_raid_army(raid, session)
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append(raid)
	session.overworld["encounters"] = encounters
	EnemyAdventureRules.normalize_all_commander_rosters(session)

func _resource_target(session, placement_id: String) -> Dictionary:
	for node in session.overworld.get("resource_nodes", []):
		if not (node is Dictionary) or String(node.get("placement_id", "")) != placement_id:
			continue
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		return {
			"x": int(node.get("x", 0)),
			"y": int(node.get("y", 0)),
			"label": String(site.get("name", placement_id)),
		}
	return {}

func _set_resource_controller(session, placement_id: String, faction_id: String) -> void:
	var nodes: Array = session.overworld.get("resource_nodes", [])
	for index in range(nodes.size()):
		var node = nodes[index]
		if not (node is Dictionary):
			continue
		if String(node.get("placement_id", "")) != placement_id:
			continue
		node["collected"] = true
		node["collected_by_faction_id"] = faction_id
		node["collected_day"] = max(1, int(session.day))
		nodes[index] = node
		session.overworld["resource_nodes"] = nodes
		return
	_fail("Could not find resource placement %s" % placement_id)

func _set_enemy_state_patch(session, faction_id: String, patch: Dictionary) -> void:
	var states: Array = session.overworld.get("enemy_states", [])
	for index in range(states.size()):
		var state = states[index]
		if not (state is Dictionary):
			continue
		if String(state.get("faction_id", "")) != faction_id:
			continue
		for key in patch.keys():
			state[key] = patch[key]
		states[index] = state
		session.overworld["enemy_states"] = states
		EnemyAdventureRules.normalize_all_commander_rosters(session)
		return
	_fail("Could not patch enemy state for %s" % faction_id)

func _enemy_config(scenario_id: String, faction_id: String) -> Dictionary:
	var scenario := ContentService.get_scenario(scenario_id)
	for config in scenario.get("enemy_factions", []):
		if config is Dictionary and String(config.get("faction_id", "")) == faction_id:
			return config
	_fail("Could not find enemy config for %s in %s" % [faction_id, scenario_id])
	return {}

func _fail(message: String) -> void:
	var payload := {
		"ok": false,
		"report_id": REPORT_ID,
		"error": message,
	}
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	_failed = true
	get_tree().quit(1)
