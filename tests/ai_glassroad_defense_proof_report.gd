extends Node

const SCENARIO_ID := "glassroad-sundering"
const FACTION_ID := "faction_embercourt"
const ENEMY_TOWN := "riverwatch_market"
const FRONT_TOWN := "halo_spire_bridgehead"
const PRIMARY_SITE := "glassroad_watch_relay"
const COMPANION_SITE := "glassroad_starlens"
const COMPANION_ENCOUNTER := "glassroad_beacon_wardens"
const ORIGIN := {"x": 9, "y": 1}
const SIMPLE_PICKUPS := ["glassroad_timber", "glassroad_ore", "market_cache"]
const TREASURY := {"gold": 7200, "wood": 12, "ore": 12}
const SCORE_KEYS := [
	"base_value",
	"persistent_income_value",
	"recruit_value",
	"scarcity_value",
	"denial_value",
	"route_pressure_value",
	"town_enablement_value",
	"objective_value",
	"faction_bias",
	"travel_cost",
	"guard_cost",
	"assignment_penalty",
	"final_priority",
	"final_score",
	"income_value",
	"growth_value",
	"pressure_value",
	"category_bonus",
	"raid_score",
]
const PUBLIC_EVENT_KEYS := [
	"event_id",
	"day",
	"sequence",
	"event_type",
	"faction_id",
	"faction_label",
	"actor_id",
	"actor_label",
	"target_kind",
	"target_id",
	"target_label",
	"target_x",
	"target_y",
	"visibility",
	"public_importance",
	"summary",
	"reason_codes",
	"public_reason",
	"debug_reason",
	"state_policy",
]

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var session = _base_session()
	_set_resource_controller(session, PRIMARY_SITE, "player")
	_set_resource_controller(session, COMPANION_SITE, "player")
	if _failed:
		return

	var config := _enemy_config()
	if config.is_empty():
		return
	var fixture_sanity := _fixture_sanity(session, config)
	if _failed:
		return

	var resource_report := EnemyAdventureRules.resource_pressure_report(session, config, ORIGIN, FACTION_ID, 0)
	var targets: Array = resource_report.get("targets", [])
	var target_ids := _target_ids(targets)
	_assert_resource_order(target_ids)
	if _failed:
		return
	var relay := _target_by_id(targets, PRIMARY_SITE)
	var starlens := _target_by_id(targets, COMPANION_SITE)
	if relay.is_empty() or starlens.is_empty():
		_fail("Missing Glassroad relay or Starlens target in resource report")
		return
	_assert_public_reason(relay, "relay target", "income and route vision denial", ["persistent_income_denial", "route_vision", "player_town_support"])
	_assert_public_reason(starlens, "starlens target", "route pressure", ["route_pressure"])
	if _failed:
		return

	var chosen := EnemyAdventureRules.choose_target(session, config, ORIGIN)
	var chosen_snapshot := _target_snapshot(chosen)
	if String(chosen_snapshot.get("target_kind", "")) != "town" or String(chosen_snapshot.get("target_placement_id", "")) != FRONT_TOWN:
		_fail("Expected full selector town-front sanity target %s, got %s" % [FRONT_TOWN, chosen_snapshot])
		return
	if String(chosen_snapshot.get("public_reason", "")) != "town siege remains the main front":
		_fail("Expected town-front public reason, got %s" % chosen_snapshot.get("public_reason", ""))
		return
	var pressure_event := EnemyAdventureRules.ai_pressure_summary_event(session, config, chosen, {})
	_assert_event(pressure_event, "ai_pressure_summary", FRONT_TOWN, "town siege remains the main front", ["town_siege", "objective_front"])
	if _failed:
		return

	var assignment_event := _assignment_event_from_breakdown(session, config, relay)
	_assert_event(assignment_event, "ai_target_assigned", PRIMARY_SITE, "income and route vision denial", ["persistent_income_denial", "route_vision", "player_town_support"])
	if _failed:
		return

	var seizure_case := _run_seizure_case()
	var seizure_event: Dictionary = seizure_case.get("event", {})
	var seizure_supported := bool(seizure_case.get("supported", false))
	if seizure_supported:
		_assert_event(seizure_event, "ai_site_seized", PRIMARY_SITE, "income and route vision denial", ["site_seized", "persistent_income_denial", "route_vision"])
		if _failed:
			return
	else:
		var blocker := String(seizure_case.get("blocker", ""))
		if blocker == "":
			_fail("Relay seizure was unsupported but did not report an exact blocker")
			return

	var starlens_surface := _starlens_stabilization_surface(starlens)
	if _failed:
		return

	var town_governor := _town_governor_stabilization()
	if town_governor.is_empty():
		return

	var public_events := [assignment_event, pressure_event]
	if seizure_supported:
		public_events.append(seizure_event)
	for event in town_governor.get("events", []):
		if event is Dictionary:
			public_events.append(event)
	var public_leak_check := _public_leak_check(public_events)
	if not bool(public_leak_check.get("ok", false)):
		_fail(String(public_leak_check.get("error", "public leak check failed")))
		return

	var state_need_decision := "defer_defense_specific_state"
	var caveats := [
		"Full choose_target sanity remains the Halo Spire town front and is accepted for this proof.",
		"Starlens stabilization is a report/debug surface, not a second broad seizure path.",
		"Detailed score fields remain in report/debug target and town-governor tables only.",
		"This is deterministic proof scaffolding, not a live-client enemy-turn pacing transcript.",
	]
	if not seizure_supported:
		state_need_decision = "plan_defense_specific_state_only_if_blocker_requires_it"
		caveats.append(String(seizure_case.get("blocker", "")))

	var payload := {
		"ok": true,
		"scenario_id": SCENARIO_ID,
		"faction_id": FACTION_ID,
		"selected_path": {
			"primary_site": PRIMARY_SITE,
			"companion_site": COMPANION_SITE,
			"town_front": FRONT_TOWN,
			"enemy_town": ENEMY_TOWN,
			"companion_encounter": COMPANION_ENCOUNTER,
			"origin": ORIGIN,
		},
		"fixture_sanity": fixture_sanity,
		"resource_order": target_ids,
		"top_resource_targets": targets.slice(0, min(6, targets.size())),
		"chosen_target_sanity": chosen_snapshot,
		"pressure_event": pressure_event,
		"assignment_event": assignment_event,
		"seizure_or_blocker": seizure_case,
		"site_controller_before": String(seizure_case.get("controller_before", "")),
		"site_controller_after": String(seizure_case.get("controller_after", "")),
		"starlens_stabilization_surface": starlens_surface,
		"town_governor_stabilization": town_governor,
		"public_leak_check": public_leak_check,
		"state_need_decision": state_need_decision,
		"caveats": caveats,
	}
	print("AI_GLASSROAD_DEFENSE_PROOF_REPORT %s" % JSON.stringify(payload))
	get_tree().quit(0)

func _base_session():
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	OverworldRules.normalize_overworld_state(session)
	OverworldRules.refresh_fog_of_war(session)
	return session

func _fixture_sanity(session, config: Dictionary) -> Dictionary:
	var scenario := ContentService.get_scenario(SCENARIO_ID)
	if String(scenario.get("player_faction_id", "")) != "faction_sunvault":
		_fail("Expected Sunvault player faction in %s" % SCENARIO_ID)
		return {}
	if String(config.get("faction_id", "")) != FACTION_ID:
		_fail("Expected Embercourt enemy config in %s" % SCENARIO_ID)
		return {}
	var priority_targets: Array = config.get("priority_target_placement_ids", [])
	for placement_id in [FRONT_TOWN, PRIMARY_SITE, COMPANION_SITE, COMPANION_ENCOUNTER]:
		if String(placement_id) not in priority_targets:
			_fail("Enemy priority target list missing %s" % placement_id)
			return {}
	var strategy_overrides: Dictionary = config.get("strategy_overrides", {})
	var site_weights: Dictionary = strategy_overrides.get("site_family_weights", {})
	var raid_weights: Dictionary = strategy_overrides.get("raid_target_weights", {})
	var raid_strategy: Dictionary = strategy_overrides.get("raid", {})
	_assert_float("faction_outpost override", site_weights.get("faction_outpost", 0.0), 1.55)
	_assert_float("frontier_shrine override", site_weights.get("frontier_shrine", 0.0), 1.2)
	_assert_float("town target override", raid_weights.get("town", 0.0), 1.4)
	_assert_float("resource target override", raid_weights.get("resource", 0.0), 0.95)
	_assert_float("encounter target override", raid_weights.get("encounter", 0.0), 1.2)
	_assert_float("town siege override", raid_strategy.get("town_siege_weight", 0.0), 1.5)
	if _failed:
		return {}
	var relay_node := _resource_node(session, PRIMARY_SITE)
	var starlens_node := _resource_node(session, COMPANION_SITE)
	var relay_site := ContentService.get_resource_site(String(relay_node.get("site_id", "")))
	var starlens_site := ContentService.get_resource_site(String(starlens_node.get("site_id", "")))
	return {
		"enemy_label": String(config.get("label", "")),
		"player_faction_id": String(scenario.get("player_faction_id", "")),
		"enemy_faction_id": String(config.get("faction_id", "")),
		"priority_target_placement_ids": priority_targets,
		"spawn_points": config.get("spawn_points", []),
		"strategy_overrides": strategy_overrides,
		"front_town": _town_snapshot(session, FRONT_TOWN),
		"enemy_town": _town_snapshot(session, ENEMY_TOWN),
		"relay_site_facts": _site_fact_snapshot(relay_node, relay_site),
		"starlens_site_facts": _site_fact_snapshot(starlens_node, starlens_site),
		"companion_encounter": _encounter_snapshot(session, COMPANION_ENCOUNTER),
	}

func _assignment_event_from_breakdown(session, config: Dictionary, breakdown: Dictionary) -> Dictionary:
	var actor := {
		"placement_id": "glassroad_report_relay_raid",
		"encounter_id": "encounter_lantern_patrol",
		"spawned_by_faction_id": FACTION_ID,
		"x": int(ORIGIN.get("x", 0)),
		"y": int(ORIGIN.get("y", 0)),
		"target_kind": "resource",
		"target_placement_id": String(breakdown.get("placement_id", "")),
		"target_label": String(breakdown.get("target_label", "")),
		"target_x": 0,
		"target_y": 0,
		"target_reason_codes": breakdown.get("reason_codes", []),
		"target_public_reason": String(breakdown.get("public_reason", "")),
		"target_public_importance": String(breakdown.get("public_importance", "high")),
		"target_debug_reason": String(breakdown.get("debug_reason", "")),
	}
	var node := _resource_node(session, String(breakdown.get("placement_id", "")))
	actor["target_x"] = int(node.get("x", 0))
	actor["target_y"] = int(node.get("y", 0))
	return EnemyAdventureRules.ai_target_assignment_event(session, config, actor, {})

func _run_seizure_case() -> Dictionary:
	var session = _base_session()
	_set_resource_controller(session, PRIMARY_SITE, "player")
	if _failed:
		return {}
	var before := _resource_controller(session, PRIMARY_SITE)
	_add_relay_raid(session)
	var before_state := _enemy_state()
	var result := EnemyAdventureRules.advance_raids(session, _enemy_config(), FACTION_ID, before_state.duplicate(true))
	var after_state: Dictionary = result.get("state", {})
	var events: Array = result.get("events", [])
	var event := _event_by_type_and_target(events, "ai_site_seized", PRIMARY_SITE)
	var after := _resource_controller(session, PRIMARY_SITE)
	var blocker := ""
	var supported := after == FACTION_ID and not event.is_empty()
	if not supported:
		if after != FACTION_ID:
			blocker = "advance_raids did not flip %s controller from %s to %s; controller after was %s" % [PRIMARY_SITE, before, FACTION_ID, after]
		elif event.is_empty():
			blocker = "advance_raids flipped %s to %s but emitted no ai_site_seized event for the relay" % [PRIMARY_SITE, after]
		else:
			blocker = "advance_raids produced an unexpected relay seizure state"
	return {
		"supported": supported,
		"blocker": blocker,
		"controller_before": before,
		"controller_after": after,
		"event": event,
		"events": events,
		"message": String(result.get("message", "")),
		"enemy_state_delta": _state_delta(before_state, after_state),
	}

func _add_relay_raid(session) -> void:
	var node := _resource_node(session, PRIMARY_SITE)
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append(
		{
			"placement_id": "glassroad_report_relay_seizure_raid",
			"encounter_id": "encounter_lantern_patrol",
			"x": int(node.get("x", 0)),
			"y": int(node.get("y", 0)),
			"difficulty": "pressure",
			"combat_seed": hash("%s:%s" % [SCENARIO_ID, "glassroad_report_relay_seizure_raid"]),
			"spawned_by_faction_id": FACTION_ID,
			"days_active": 0,
			"arrived": true,
			"goal_distance": 0,
			"target_kind": "resource",
			"target_placement_id": PRIMARY_SITE,
			"target_label": "Prism Watch Relay",
			"target_x": int(node.get("x", 0)),
			"target_y": int(node.get("y", 0)),
			"goal_x": int(node.get("x", 0)),
			"goal_y": int(node.get("y", 0)),
			"target_public_reason": "income and route vision denial",
			"target_reason_codes": ["persistent_income_denial", "route_vision", "player_town_support"],
			"target_public_importance": "high",
			"target_debug_reason": "denies 25 gold daily, route vision, player-town support",
		}
	)
	session.overworld["encounters"] = encounters

func _starlens_stabilization_surface(starlens: Dictionary) -> Dictionary:
	var site := ContentService.get_resource_site("site_starlens_sanctum")
	var response: Dictionary = site.get("response_profile", {})
	if String(starlens.get("public_reason", "")) != "route pressure":
		_fail("Starlens expected public reason route pressure, got %s" % starlens.get("public_reason", ""))
		return {}
	for code in ["route_pressure"]:
		if String(code) not in starlens.get("reason_codes", []):
			_fail("Starlens missing reason code %s" % code)
			return {}
	if String(response.get("action_label", "")) != "Relight Shrine":
		_fail("Starlens response profile expected Relight Shrine, got %s" % response.get("action_label", ""))
		return {}
	return {
		"placement_id": COMPANION_SITE,
		"target_label": String(starlens.get("target_label", "")),
		"rank": 2,
		"public_reason": String(starlens.get("public_reason", "")),
		"reason_codes": starlens.get("reason_codes", []),
		"debug_reason": String(starlens.get("debug_reason", "")),
		"site_id": "site_starlens_sanctum",
		"claim_rewards": site.get("claim_rewards", {}),
		"learn_spell_id": String(site.get("learn_spell_id", "")),
		"response_profile": {
			"action_label": String(response.get("action_label", "")),
			"watch_days": int(response.get("watch_days", 0)),
			"readiness_bonus": int(response.get("readiness_bonus", 0)),
			"pressure_bonus": int(response.get("pressure_bonus", 0)),
			"recovery_relief": int(response.get("recovery_relief", 0)),
		},
	}

func _town_governor_stabilization() -> Dictionary:
	var session = _base_session()
	_set_enemy_treasury(session, TREASURY)
	if _failed:
		return {}
	var report := EnemyTurnRules.town_governor_pressure_report(session, _enemy_config(), FACTION_ID)
	var town_report := _town_report_by_id(report.get("towns", []), ENEMY_TOWN)
	if town_report.is_empty():
		_fail("Missing Riverwatch Market town governor report")
		return {}
	var selected_build: Dictionary = town_report.get("build", {}).get("selected_build", {})
	var selected_recruitment: Dictionary = town_report.get("recruitment", {}).get("selected_recruitment", {})
	if String(selected_build.get("building_id", "")) != "building_market_square":
		_fail("Expected Riverwatch selected build building_market_square, got %s" % selected_build)
		return {}
	if String(selected_build.get("category", "")) != "economy":
		_fail("Expected Market Square category economy, got %s" % selected_build.get("category", ""))
		return {}
	var dominant := _dominant_build_components(selected_build)
	if not _component_present(dominant, "weighted_market_value") or not _component_present(dominant, "weighted_income_value"):
		_fail("Expected Market Square dominant market and income components, got %s" % dominant)
		return {}
	var destination: Dictionary = selected_recruitment.get("destination", {})
	if String(destination.get("type", "")) != "garrison":
		_fail("Expected Riverwatch recruitment destination garrison, got %s" % destination)
		return {}
	if String(destination.get("public_reason", "")) != "stabilizes garrison":
		_fail("Expected Riverwatch recruitment reason stabilizes garrison, got %s" % destination.get("public_reason", ""))
		return {}
	if "garrison_safety" not in destination.get("reason_codes", []):
		_fail("Riverwatch recruitment missing garrison_safety reason code")
		return {}
	var events := []
	for event in town_report.get("events", []):
		if event is Dictionary:
			events.append(event)
	for event_type in ["ai_town_built", "ai_town_recruited", "ai_garrison_reinforced"]:
		if _event_by_type(events, event_type).is_empty():
			_fail("Riverwatch governor missing event %s" % event_type)
			return {}
	return {
		"town_placement_id": String(town_report.get("placement_id", "")),
		"strategic_role": String(town_report.get("strategic_role", "")),
		"garrison_strength": int(town_report.get("garrison_strength", 0)),
		"desired_garrison_strength": int(town_report.get("desired_garrison_strength", 0)),
		"selected_build": {
			"building_id": String(selected_build.get("building_id", "")),
			"building_label": String(selected_build.get("building_label", "")),
			"category": String(selected_build.get("category", "")),
			"public_reason": String(selected_build.get("public_reason", "")),
			"reason_codes": selected_build.get("reason_codes", []),
			"debug_reason": String(selected_build.get("debug_reason", "")),
			"dominant_debug_components": dominant,
		},
		"selected_recruitment": {
			"unit_id": String(selected_recruitment.get("unit_id", "")),
			"unit_label": String(selected_recruitment.get("unit_label", "")),
			"recruit_count": int(selected_recruitment.get("recruit_count", 0)),
			"destination": {
				"type": String(destination.get("type", "")),
				"decision_rule": String(destination.get("decision_rule", "")),
				"public_reason": String(destination.get("public_reason", "")),
				"reason_codes": destination.get("reason_codes", []),
				"debug_reason": String(destination.get("debug_reason", "")),
				"garrison_score": float(destination.get("garrison_score", 0.0)),
				"raid_score": float(destination.get("raid_score", 0.0)),
				"rebuild_score": float(destination.get("rebuild_score", 0.0)),
			},
		},
		"events": events,
	}

func _assert_resource_order(target_ids: Array) -> void:
	if target_ids.size() < 2 or String(target_ids[0]) != PRIMARY_SITE or String(target_ids[1]) != COMPANION_SITE:
		_fail("Expected %s then %s at top of resource order, got %s" % [PRIMARY_SITE, COMPANION_SITE, target_ids])
		return
	for owned_id in [PRIMARY_SITE, COMPANION_SITE]:
		var owned_rank := target_ids.find(owned_id)
		if owned_rank < 0:
			_fail("Missing owned Glassroad site %s in resource order %s" % [owned_id, target_ids])
			return
		for pickup_id in SIMPLE_PICKUPS:
			var pickup_rank := target_ids.find(pickup_id)
			if pickup_rank >= 0 and pickup_rank < owned_rank:
				_fail("Simple pickup %s outranked owned persistent site %s: %s" % [pickup_id, owned_id, target_ids])
				return

func _assert_public_reason(record: Dictionary, label: String, expected_reason: String, required_codes: Array) -> void:
	if String(record.get("public_reason", "")) != expected_reason:
		_fail("%s expected public reason %s, got %s" % [label, expected_reason, record.get("public_reason", "")])
		return
	for code in required_codes:
		if String(code) not in record.get("reason_codes", []):
			_fail("%s missing reason code %s in %s" % [label, code, record.get("reason_codes", [])])
			return

func _assert_event(event: Dictionary, event_type: String, target_id: String, expected_reason: String, required_codes: Array) -> void:
	if event.is_empty():
		_fail("Missing event %s for %s" % [event_type, target_id])
		return
	if String(event.get("event_type", "")) != event_type:
		_fail("Expected event type %s, got %s" % [event_type, event.get("event_type", "")])
		return
	if String(event.get("target_id", "")) != target_id:
		_fail("Expected event target %s, got %s" % [target_id, event.get("target_id", "")])
		return
	if String(event.get("public_reason", "")) != expected_reason:
		_fail("%s expected public reason %s, got %s" % [event_type, expected_reason, event.get("public_reason", "")])
		return
	for code in required_codes:
		if String(code) not in event.get("reason_codes", []):
			_fail("%s missing reason code %s in %s" % [event_type, code, event.get("reason_codes", [])])
			return

func _public_leak_check(events: Array) -> Dictionary:
	for event in events:
		if not (event is Dictionary):
			continue
		for key in event.keys():
			if String(key) not in PUBLIC_EVENT_KEYS:
				return {"ok": false, "error": "%s leaked non-compact key %s" % [event.get("event_type", "event"), key]}
		var event_text := JSON.stringify(event)
		for key in SCORE_KEYS:
			if event.has(key) or event_text.contains(key):
				return {"ok": false, "error": "%s leaked score token %s" % [event.get("event_type", "event"), key]}
	return {
		"ok": true,
		"checked_events": events.size(),
		"allowed_public_event_keys": PUBLIC_EVENT_KEYS,
		"blocked_score_keys": SCORE_KEYS,
	}

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

func _set_enemy_treasury(session, treasury: Dictionary) -> void:
	var states: Array = session.overworld.get("enemy_states", [])
	for index in range(states.size()):
		var state = states[index]
		if not (state is Dictionary):
			continue
		if String(state.get("faction_id", "")) != FACTION_ID:
			continue
		state["treasury"] = treasury.duplicate(true)
		states[index] = state
		session.overworld["enemy_states"] = states
		return
	_fail("Could not set enemy treasury for %s" % FACTION_ID)

func _resource_node(session, placement_id: String) -> Dictionary:
	for node in session.overworld.get("resource_nodes", []):
		if node is Dictionary and String(node.get("placement_id", "")) == placement_id:
			return node
	_fail("Could not find resource node %s" % placement_id)
	return {}

func _resource_controller(session, placement_id: String) -> String:
	for node in session.overworld.get("resource_nodes", []):
		if node is Dictionary and String(node.get("placement_id", "")) == placement_id:
			return String(node.get("collected_by_faction_id", ""))
	return ""

func _town_snapshot(session, placement_id: String) -> Dictionary:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("placement_id", "")) == placement_id:
			return {
				"placement_id": String(town.get("placement_id", "")),
				"town_id": String(town.get("town_id", "")),
				"x": int(town.get("x", 0)),
				"y": int(town.get("y", 0)),
				"owner": String(town.get("owner", "")),
			}
	return {}

func _encounter_snapshot(session, placement_id: String) -> Dictionary:
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary and String(encounter.get("placement_id", "")) == placement_id:
			return {
				"placement_id": String(encounter.get("placement_id", "")),
				"encounter_id": String(encounter.get("encounter_id", "")),
				"x": int(encounter.get("x", 0)),
				"y": int(encounter.get("y", 0)),
			}
	return {}

func _site_fact_snapshot(node: Dictionary, site: Dictionary) -> Dictionary:
	var response: Dictionary = site.get("response_profile", {})
	return {
		"placement_id": String(node.get("placement_id", "")),
		"site_id": String(node.get("site_id", "")),
		"x": int(node.get("x", 0)),
		"y": int(node.get("y", 0)),
		"name": String(site.get("name", "")),
		"family": String(site.get("family", "")),
		"persistent_control": bool(site.get("persistent_control", false)),
		"claim_rewards": site.get("claim_rewards", {}),
		"control_income": site.get("control_income", {}),
		"vision_radius": int(site.get("vision_radius", 0)),
		"pressure_guard": int(site.get("pressure_guard", 0)),
		"learn_spell_id": String(site.get("learn_spell_id", "")),
		"response_profile": {
			"action_label": String(response.get("action_label", "")),
			"watch_days": int(response.get("watch_days", 0)),
			"quality_bonus": int(response.get("quality_bonus", 0)),
			"readiness_bonus": int(response.get("readiness_bonus", 0)),
			"pressure_bonus": int(response.get("pressure_bonus", 0)),
			"recovery_relief": int(response.get("recovery_relief", 0)),
		},
	}

func _target_snapshot(target: Dictionary) -> Dictionary:
	return {
		"target_kind": String(target.get("target_kind", "")),
		"target_placement_id": String(target.get("target_placement_id", "")),
		"target_label": String(target.get("target_label", "")),
		"priority": int(target.get("priority", target.get("final_priority", 0))),
		"public_reason": String(target.get("target_public_reason", target.get("public_reason", ""))),
		"debug_reason": String(target.get("target_debug_reason", target.get("debug_reason", ""))),
		"reason_codes": target.get("target_reason_codes", target.get("reason_codes", [])),
	}

func _dominant_build_components(build: Dictionary) -> Array:
	var components := [
		{"key": "weighted_market_value", "value": float(build.get("weighted_market_value", 0.0))},
		{"key": "weighted_income_value", "value": float(build.get("weighted_income_value", 0.0))},
		{"key": "weighted_growth_value", "value": float(build.get("weighted_growth_value", 0.0))},
		{"key": "weighted_quality_value", "value": float(build.get("weighted_quality_value", 0.0))},
		{"key": "weighted_readiness_value", "value": float(build.get("weighted_readiness_value", 0.0))},
		{"key": "weighted_pressure_value", "value": float(build.get("weighted_pressure_value", 0.0))},
		{"key": "garrison_need_bonus", "value": float(build.get("garrison_need_bonus", 0.0))},
		{"key": "raid_need_bonus", "value": float(build.get("raid_need_bonus", 0.0))},
	]
	components.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("value", 0.0)) > float(b.get("value", 0.0))
	)
	var result := []
	for component in components:
		if float(component.get("value", 0.0)) <= 0.0:
			continue
		result.append(component)
		if result.size() >= 4:
			break
	return result

func _component_present(components: Array, key: String) -> bool:
	for component in components:
		if component is Dictionary and String(component.get("key", "")) == key:
			return true
	return false

func _state_delta(before: Dictionary, after: Dictionary) -> Dictionary:
	return {
		"pressure_before": int(before.get("pressure", 0)),
		"pressure_after": int(after.get("pressure", 0)),
		"pressure_delta": int(after.get("pressure", 0)) - int(before.get("pressure", 0)),
		"treasury_before": before.get("treasury", {}),
		"treasury_after": after.get("treasury", {}),
	}

func _target_ids(targets: Array) -> Array:
	var ids := []
	for target in targets:
		if target is Dictionary:
			ids.append(String(target.get("placement_id", "")))
	return ids

func _target_by_id(targets: Array, placement_id: String) -> Dictionary:
	for target in targets:
		if target is Dictionary and String(target.get("placement_id", "")) == placement_id:
			return target
	return {}

func _event_by_type_and_target(events: Array, event_type: String, target_id: String) -> Dictionary:
	for event in events:
		if not (event is Dictionary):
			continue
		if String(event.get("event_type", "")) == event_type and String(event.get("target_id", "")) == target_id:
			return event
	return {}

func _event_by_type(events: Array, event_type: String) -> Dictionary:
	for event in events:
		if event is Dictionary and String(event.get("event_type", "")) == event_type:
			return event
	return {}

func _town_report_by_id(towns: Array, placement_id: String) -> Dictionary:
	for town in towns:
		if town is Dictionary and String(town.get("placement_id", "")) == placement_id:
			return town
	return {}

func _enemy_config() -> Dictionary:
	var scenario := ContentService.get_scenario(SCENARIO_ID)
	for config in scenario.get("enemy_factions", []):
		if config is Dictionary and String(config.get("faction_id", "")) == FACTION_ID:
			return config
	_fail("Could not find enemy config for %s" % FACTION_ID)
	return {}

func _enemy_state() -> Dictionary:
	return {
		"faction_id": FACTION_ID,
		"pressure": 0,
		"treasury": {},
		"raid_counter": 0,
		"commander_counter": 0,
		"commander_roster": [],
	}

func _assert_float(label: String, actual_value: Variant, expected: float) -> void:
	if abs(float(actual_value) - expected) > 0.01:
		_fail("%s expected %.2f, got %s" % [label, expected, actual_value])

func _fail(message: String) -> void:
	var payload := {
		"ok": false,
		"scenario_id": SCENARIO_ID,
		"faction_id": FACTION_ID,
		"error": message,
	}
	push_error(message)
	print("AI_GLASSROAD_DEFENSE_PROOF_REPORT %s" % JSON.stringify(payload))
	_failed = true
	get_tree().quit(1)
