extends Node

const REPORT_ID := "AI_COMMANDER_ROLE_STATE_REPORT"
const RIVER_PASS := "river-pass"
const GLASSROAD := "glassroad-sundering"
const MIRECLAW := "faction_mireclaw"
const EMBERCOURT := "faction_embercourt"
const RIVER_ORIGIN := {"x": 7, "y": 1}
const GLASSROAD_ORIGIN := {"x": 9, "y": 1}

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var cases := []
	cases.append(_mireclaw_free_company_retaker())
	cases.append(_mireclaw_free_company_raider())
	cases.append(_mireclaw_signal_post_companion())
	cases.append(_embercourt_glassroad_relay_defender())
	cases.append(_embercourt_glassroad_relay_retaker())
	cases.append(_embercourt_glassroad_stabilizer())
	cases.append(_commander_recovery_blocks_assignment())
	cases.append(_commander_memory_continuity())
	if _failed:
		return

	var public_events := []
	for case_report in cases:
		if not (case_report is Dictionary):
			continue
		var event: Dictionary = case_report.get("public_role_event", {})
		if not event.is_empty():
			public_events.append(event)
	var leak_check := EnemyAdventureRules.commander_role_public_leak_check(public_events)
	if not bool(leak_check.get("ok", false)):
		_fail(String(leak_check.get("error", "public leak check failed")))
		return

	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_status": "report_fixture_only",
		"day": 1,
		"cases": cases,
		"public_leak_check": leak_check,
		"caveats": [
			"Report fixture annotations are test-only and are not saved or production JSON.",
			"Role proposals do not change live target selection, raid advancement, pathing, save format, or AI behavior.",
			"Detailed score rows remain in supporting_evidence only; public role events stay compact.",
		],
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _mireclaw_free_company_retaker() -> Dictionary:
	var session = _base_session(RIVER_PASS)
	_set_resource_controller(session, "river_free_company", "player")
	_set_resource_controller(session, "river_signal_post", "player")
	return _resource_case(
		session,
		MIRECLAW,
		RIVER_ORIGIN,
		"mireclaw_free_company_retaker",
		"hero_vaska",
		"river_free_company",
		{"fixture_previous_controller": MIRECLAW},
		EnemyAdventureRules.COMMANDER_ROLE_RETAKER,
		"assigned",
		"valid",
		"recruit and income denial",
		["persistent_income_denial", "recruit_denial", "route_pressure", "player_town_support"],
		1,
		"riverwatch_hold",
		"docs/strategic-ai-capture-countercapture-defense-proof-report.md"
	)

func _mireclaw_free_company_raider() -> Dictionary:
	var session = _base_session(RIVER_PASS)
	_set_resource_controller(session, "river_free_company", "player")
	_set_resource_controller(session, "river_signal_post", "player")
	return _resource_case(
		session,
		MIRECLAW,
		RIVER_ORIGIN,
		"mireclaw_free_company_raider",
		"hero_vaska",
		"river_free_company",
		{"fixture_denial_only": true},
		EnemyAdventureRules.COMMANDER_ROLE_RAIDER,
		"assigned",
		"valid",
		"recruit and income denial",
		["persistent_income_denial", "recruit_denial", "route_pressure", "player_town_support"],
		1,
		"riverwatch_hold",
		"docs/strategic-ai-capture-countercapture-defense-proof-report.md"
	)

func _mireclaw_signal_post_companion() -> Dictionary:
	var session = _base_session(RIVER_PASS)
	_set_resource_controller(session, "river_free_company", "player")
	_set_resource_controller(session, "river_signal_post", "player")
	return _resource_case(
		session,
		MIRECLAW,
		RIVER_ORIGIN,
		"mireclaw_signal_post_companion",
		"hero_sable",
		"river_signal_post",
		{"fixture_primary_target_covered": "river_free_company"},
		EnemyAdventureRules.COMMANDER_ROLE_RAIDER,
		"assigned",
		"valid",
		"income and route vision denial",
		["persistent_income_denial", "route_vision", "player_town_support"],
		2,
		"riverwatch_hold",
		"docs/strategic-ai-capture-countercapture-defense-proof-report.md"
	)

func _embercourt_glassroad_relay_defender() -> Dictionary:
	var session = _base_session(GLASSROAD)
	_set_resource_controller(session, "glassroad_watch_relay", EMBERCOURT)
	return _resource_case(
		session,
		EMBERCOURT,
		GLASSROAD_ORIGIN,
		"embercourt_glassroad_relay_defender",
		"hero_caelen",
		"glassroad_watch_relay",
		{"fixture_threatened_by_player_front": true},
		EnemyAdventureRules.COMMANDER_ROLE_DEFENDER,
		"assigned",
		"valid",
		"income and route vision denial",
		["persistent_income_denial", "route_vision", "player_town_support"],
		-1,
		"halo_spire_bridgehead",
		"docs/strategic-ai-glassroad-defense-proof-report.md"
	)

func _embercourt_glassroad_relay_retaker() -> Dictionary:
	var session = _base_session(GLASSROAD)
	_set_resource_controller(session, "glassroad_watch_relay", "player")
	_set_resource_controller(session, "glassroad_starlens", "player")
	return _resource_case(
		session,
		EMBERCOURT,
		GLASSROAD_ORIGIN,
		"embercourt_glassroad_relay_retaker",
		"hero_caelen",
		"glassroad_watch_relay",
		{"fixture_previous_controller": EMBERCOURT},
		EnemyAdventureRules.COMMANDER_ROLE_RETAKER,
		"assigned",
		"valid",
		"income and route vision denial",
		["persistent_income_denial", "route_vision", "player_town_support"],
		1,
		"halo_spire_bridgehead",
		"docs/strategic-ai-glassroad-defense-proof-report.md"
	)

func _embercourt_glassroad_stabilizer() -> Dictionary:
	var session = _base_session(GLASSROAD)
	_set_resource_controller(session, "glassroad_starlens", EMBERCOURT)
	var case_report := _resource_case(
		session,
		EMBERCOURT,
		GLASSROAD_ORIGIN,
		"embercourt_glassroad_stabilizer",
		"hero_seren",
		"glassroad_starlens",
		{"fixture_recently_secured": true},
		EnemyAdventureRules.COMMANDER_ROLE_STABILIZER,
		"assigned",
		"valid",
		"route pressure",
		["route_pressure"],
		-1,
		"halo_spire_bridgehead",
		"docs/strategic-ai-glassroad-defense-proof-report.md"
	)
	var site := ContentService.get_resource_site("site_starlens_sanctum")
	var response: Dictionary = site.get("response_profile", {})
	var profile := {
		"action_label": String(response.get("action_label", "")),
		"watch_days": int(response.get("watch_days", 0)),
		"readiness_bonus": int(response.get("readiness_bonus", 0)),
		"pressure_bonus": int(response.get("pressure_bonus", 0)),
		"recovery_relief": int(response.get("recovery_relief", 0)),
	}
	if profile != {
		"action_label": "Relight Shrine",
		"watch_days": 3,
		"readiness_bonus": 1,
		"pressure_bonus": 1,
		"recovery_relief": 2,
	}:
		_fail("Unexpected Starlens response profile %s" % profile)
		return {}
	case_report["supporting_evidence"]["starlens_response_profile"] = profile
	return case_report

func _commander_recovery_blocks_assignment() -> Dictionary:
	var session = _base_session(RIVER_PASS)
	_set_resource_controller(session, "river_free_company", "player")
	_patch_commander_entry(
		session,
		MIRECLAW,
		"hero_vaska",
		{
			"status": EnemyAdventureRules.COMMANDER_STATUS_RECOVERING,
			"recovery_day": int(session.day) + 2,
		}
	)
	var config := _enemy_config(RIVER_PASS, MIRECLAW)
	var commander := _commander_entry(session, MIRECLAW, "hero_vaska")
	var target_view := EnemyAdventureRules.commander_role_resource_target_view(session, config, MIRECLAW, "river_free_company", RIVER_ORIGIN)
	var proposal := EnemyAdventureRules.commander_role_proposal_for_resource_target(session, config, MIRECLAW, commander, target_view, {})
	var fallback_commander := _commander_entry(session, MIRECLAW, "hero_sable")
	var fallback_proposal := EnemyAdventureRules.commander_role_proposal_for_resource_target(session, config, MIRECLAW, fallback_commander, target_view, {"fixture_previous_controller": MIRECLAW})
	var empty_target := _empty_target()
	var public_event := EnemyAdventureRules.commander_role_public_event(session, config, MIRECLAW, commander, empty_target, proposal)
	_assert_case_core("commander_recovery_blocks_assignment", empty_target, proposal, EnemyAdventureRules.COMMANDER_ROLE_RECOVERING, "cooldown", "blocked", "commander recovering", ["commander_recovery"], "")
	if String(fallback_proposal.get("role", "")) != EnemyAdventureRules.COMMANDER_ROLE_RETAKER:
		_fail("Recovery fallback expected retaker proposal, got %s" % fallback_proposal)
		return {}
	var report := _case_payload(
		"commander_recovery_blocks_assignment",
		RIVER_PASS,
		MIRECLAW,
		{"fixture_recovery_day": int(session.day) + 2},
		_commander_snapshot(commander),
		EnemyAdventureRules.commander_role_active_encounter_link(session, MIRECLAW, "hero_vaska"),
		empty_target,
		proposal,
		{
			"attractive_blocked_target": _target_snapshot(target_view),
			"fallback_commander": _commander_snapshot(fallback_commander),
			"fallback_role_proposal": fallback_proposal,
			"reference_report": "docs/strategic-ai-town-governor-pressure-report-gate-review.md",
		},
		public_event
	)
	report["case_pass_criteria"] = [
		"Recovering commander remains blocked even while Free Company is attractive.",
		"Separate available commander can still receive the Free Company role proposal.",
	]
	return report

func _commander_memory_continuity() -> Dictionary:
	var session = _base_session(RIVER_PASS)
	_set_resource_controller(session, "river_free_company", "player")
	_set_resource_controller(session, "river_signal_post", "player")
	_patch_commander_entry(
		session,
		MIRECLAW,
		"hero_vaska",
		{
			"target_memory": {
				"focus_target_kind": "resource",
				"focus_target_id": "river_free_company",
				"focus_target_label": "Riverwatch Free Company Yard",
				"focus_pressure_count": 2,
				"front_label": "Riverwatch signal yard",
				"front_x": 0,
				"front_y": 4,
			},
		}
	)
	var report := _resource_case(
		session,
		MIRECLAW,
		RIVER_ORIGIN,
		"commander_memory_continuity",
		"hero_vaska",
		"river_free_company",
		{"fixture_previous_controller": MIRECLAW},
		EnemyAdventureRules.COMMANDER_ROLE_RETAKER,
		"assigned",
		"valid",
		"recruit and income denial",
		["persistent_income_denial", "recruit_denial"],
		1,
		"riverwatch_hold",
		"docs/strategic-ai-capture-countercapture-defense-proof-report.md"
	)
	if not String(report.get("commander", {}).get("memory_summary", "")).contains("Riverwatch Free Company Yard"):
		_fail("Commander memory continuity omitted Free Company memory summary")
		return {}
	if not String(report.get("role_proposal", {}).get("report_debug_reason", "")).contains("target memory"):
		_fail("Commander memory continuity omitted report/debug memory explanation")
		return {}
	return report

func _resource_case(
	session,
	faction_id: String,
	origin: Dictionary,
	case_id: String,
	commander_id: String,
	target_id: String,
	fixture_state: Dictionary,
	expected_role: String,
	expected_status: String,
	expected_validity: String,
	expected_public_reason: String,
	required_codes: Array,
	expected_rank: int,
	accepted_full_selector_target_id: String,
	reference_report: String
) -> Dictionary:
	var config := _enemy_config(String(session.scenario_id), faction_id)
	var commander := _commander_entry(session, faction_id, commander_id)
	var target_view := EnemyAdventureRules.commander_role_resource_target_view(session, config, faction_id, target_id, origin)
	var proposal := EnemyAdventureRules.commander_role_proposal_for_resource_target(session, config, faction_id, commander, target_view, fixture_state)
	_assert_case_core(case_id, target_view, proposal, expected_role, expected_status, expected_validity, expected_public_reason, required_codes, target_id)
	if _failed:
		return {}
	var public_event := EnemyAdventureRules.commander_role_public_event(session, config, faction_id, commander, target_view, proposal)
	var chosen := EnemyAdventureRules.choose_target(session, config, origin)
	var resource_rank := _resource_rank(session, config, faction_id, origin, target_id)
	if expected_rank > 0 and resource_rank != expected_rank:
		_fail("%s expected resource rank %d for %s, got %d" % [case_id, expected_rank, target_id, resource_rank])
		return {}
	return _case_payload(
		case_id,
		String(session.scenario_id),
		faction_id,
		fixture_state,
		_commander_snapshot(commander),
		EnemyAdventureRules.commander_role_active_encounter_link(session, faction_id, commander_id),
		_target_snapshot(target_view),
		proposal,
		{
			"resource_rank": resource_rank,
			"accepted_full_selector_target_id": accepted_full_selector_target_id,
			"actual_full_selector_target_id": String(chosen.get("target_placement_id", "")),
			"resource_score_breakdown": target_view.get("resource_breakdown", {}),
			"reference_report": reference_report,
		},
		public_event
	)

func _assert_case_core(
	case_id: String,
	target_view: Dictionary,
	proposal: Dictionary,
	expected_role: String,
	expected_status: String,
	expected_validity: String,
	expected_public_reason: String,
	required_codes: Array,
	expected_target_id: String
) -> void:
	if String(target_view.get("target_id", "")) != expected_target_id:
		_fail("%s expected target %s, got %s" % [case_id, expected_target_id, target_view.get("target_id", "")])
		return
	if String(proposal.get("role", "")) != expected_role:
		_fail("%s expected role %s, got %s" % [case_id, expected_role, proposal])
		return
	if String(proposal.get("role_status", "")) != expected_status:
		_fail("%s expected role status %s, got %s" % [case_id, expected_status, proposal])
		return
	if String(proposal.get("validity", "")) != expected_validity:
		_fail("%s expected validity %s, got %s" % [case_id, expected_validity, proposal])
		return
	if String(proposal.get("public_reason", "")) != expected_public_reason:
		_fail("%s expected public reason %s, got %s" % [case_id, expected_public_reason, proposal])
		return
	for code in required_codes:
		if String(code) not in proposal.get("priority_reason_codes", []):
			_fail("%s missing reason code %s in %s" % [case_id, code, proposal.get("priority_reason_codes", [])])
			return

func _case_payload(
	case_id: String,
	scenario_id: String,
	faction_id: String,
	fixture_state: Dictionary,
	commander: Dictionary,
	active_link: Dictionary,
	target: Dictionary,
	proposal: Dictionary,
	supporting_evidence: Dictionary,
	public_event: Dictionary
) -> Dictionary:
	return {
		"case_id": case_id,
		"scenario_id": scenario_id,
		"faction_id": faction_id,
		"fixture_state": fixture_state,
		"commander": commander,
		"active_encounter_link": active_link,
		"target": target,
		"role_proposal": proposal,
		"supporting_evidence": supporting_evidence,
		"public_role_event": public_event,
		"case_pass_criteria": [
			"Exact target, role, status, public reason, and required reason codes match the fixture plan.",
			"Public role event remains compact and score-free.",
		],
	}

func _base_session(scenario_id: String):
	var session = ScenarioFactory.create_session(
		scenario_id,
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	OverworldRules.normalize_overworld_state(session)
	OverworldRules.refresh_fog_of_war(session)
	EnemyAdventureRules.normalize_all_commander_rosters(session)
	return session

func _target_snapshot(target_view: Dictionary) -> Dictionary:
	return {
		"target_kind": String(target_view.get("target_kind", "")),
		"target_id": String(target_view.get("target_id", "")),
		"target_label": String(target_view.get("target_label", "")),
		"target_x": int(target_view.get("target_x", 0)),
		"target_y": int(target_view.get("target_y", 0)),
		"front_id": String(target_view.get("front_id", "")),
		"origin_kind": String(target_view.get("origin_kind", "")),
		"origin_id": String(target_view.get("origin_id", "")),
		"controller_id": String(target_view.get("controller_id", "")),
	}

func _empty_target() -> Dictionary:
	return {
		"target_kind": "",
		"target_id": "",
		"target_label": "",
		"target_x": 0,
		"target_y": 0,
		"front_id": "",
		"origin_kind": "",
		"origin_id": "",
	}

func _commander_snapshot(commander: Dictionary) -> Dictionary:
	return {
		"roster_hero_id": String(commander.get("roster_hero_id", "")),
		"status": String(commander.get("status", "")),
		"active_placement_id": String(commander.get("active_placement_id", "")),
		"recovery_day": int(commander.get("recovery_day", 0)),
		"army_status": EnemyAdventureRules.commander_army_status(commander),
		"memory_summary": EnemyAdventureRules.commander_memory_summary(commander),
	}

func _resource_rank(session, config: Dictionary, faction_id: String, origin: Dictionary, placement_id: String) -> int:
	var report := EnemyAdventureRules.resource_pressure_report(session, config, origin, faction_id, 0)
	var targets: Array = report.get("targets", [])
	for index in range(targets.size()):
		var target = targets[index]
		if target is Dictionary and String(target.get("placement_id", "")) == placement_id:
			return index + 1
	return -1

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

func _commander_entry(session, faction_id: String, roster_hero_id: String) -> Dictionary:
	var roster := _ensure_roster(session, faction_id)
	for entry in roster:
		if entry is Dictionary and String(entry.get("roster_hero_id", "")) == roster_hero_id:
			return entry
	_fail("Could not find commander %s for %s" % [roster_hero_id, faction_id])
	return {}

func _patch_commander_entry(session, faction_id: String, roster_hero_id: String, patch: Dictionary) -> void:
	var states: Array = session.overworld.get("enemy_states", [])
	for state_index in range(states.size()):
		var state = states[state_index]
		if not (state is Dictionary) or String(state.get("faction_id", "")) != faction_id:
			continue
		var roster: Array = EnemyAdventureRules.normalize_commander_roster(session, faction_id, state.get("commander_roster", []))
		for index in range(roster.size()):
			var entry = roster[index]
			if not (entry is Dictionary) or String(entry.get("roster_hero_id", "")) != roster_hero_id:
				continue
			var updated: Dictionary = entry.duplicate(true)
			for key in patch.keys():
				updated[key] = patch[key]
			if patch.has("target_memory"):
				var commander_state: Dictionary = updated.get("commander_state", {}).duplicate(true)
				commander_state["target_memory"] = patch["target_memory"]
				updated["commander_state"] = commander_state
			roster[index] = updated
			state["commander_roster"] = roster
			states[state_index] = state
			session.overworld["enemy_states"] = states
			return
	_fail("Could not patch commander %s for %s" % [roster_hero_id, faction_id])

func _ensure_roster(session, faction_id: String) -> Array:
	EnemyAdventureRules.normalize_all_commander_rosters(session)
	var states: Array = session.overworld.get("enemy_states", [])
	for index in range(states.size()):
		var state = states[index]
		if not (state is Dictionary) or String(state.get("faction_id", "")) != faction_id:
			continue
		var roster: Array = EnemyAdventureRules.normalize_commander_roster(session, faction_id, state.get("commander_roster", []))
		state["commander_roster"] = roster
		states[index] = state
		session.overworld["enemy_states"] = states
		return roster
	_fail("Could not find enemy state for %s" % faction_id)
	return []

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
