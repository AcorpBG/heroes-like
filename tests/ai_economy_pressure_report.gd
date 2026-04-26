extends Node

const SCENARIO_ID := "river-pass"
const FACTION_ID := "faction_mireclaw"
const SIMPLE_PICKUPS := ["north_timber", "southern_ore", "eastern_cache"]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var cases := []
	var signal_case := _run_case(
		"signal_post_owned",
		["river_signal_post"],
		[]
	)
	if signal_case.is_empty():
		return
	cases.append(signal_case)

	var both_case := _run_case(
		"signal_post_and_free_company_owned",
		["river_signal_post", "river_free_company"],
		["river_free_company", "river_signal_post"]
	)
	if both_case.is_empty():
		return
	cases.append(both_case)

	var payload := {
		"ok": true,
		"scenario_id": SCENARIO_ID,
		"faction_id": FACTION_ID,
		"cases": cases,
	}
	print("AI_ECONOMY_PRESSURE_REPORT %s" % JSON.stringify(payload))
	get_tree().quit(0)

func _run_case(case_id: String, player_owned_placements: Array, required_order_prefix: Array) -> Dictionary:
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	OverworldRules.normalize_overworld_state(session)
	for placement_id in player_owned_placements:
		_set_resource_controller(session, String(placement_id), "player")

	var config := _enemy_config()
	var origin := {"x": 7, "y": 1}
	var report := EnemyAdventureRules.resource_pressure_report(session, config, origin, FACTION_ID, 0)
	var targets: Array = report.get("targets", [])
	var target_ids := []
	for target in targets:
		if target is Dictionary:
			target_ids.append(String(target.get("placement_id", "")))

	for index in range(required_order_prefix.size()):
		var expected := String(required_order_prefix[index])
		if index >= target_ids.size() or String(target_ids[index]) != expected:
			_fail("%s expected target %s at resource rank %d, got %s" % [case_id, expected, index + 1, target_ids])
			return {}

	for owned_id in player_owned_placements:
		var owned_rank := target_ids.find(String(owned_id))
		if owned_rank < 0:
			_fail("%s missing owned signal-yard resource target %s in report %s" % [case_id, owned_id, target_ids])
			return {}
		for pickup_id in SIMPLE_PICKUPS:
			var pickup_rank := target_ids.find(pickup_id)
			if pickup_rank >= 0 and pickup_rank < owned_rank:
				_fail("%s simple pickup %s outranked owned persistent site %s: %s" % [case_id, pickup_id, owned_id, target_ids])
				return {}

	var chosen := EnemyAdventureRules.choose_target(session, config, origin)
	var top_targets := targets.slice(0, min(5, targets.size()))
	return {
		"case_id": case_id,
		"resource_order": target_ids,
		"top_resource_targets": top_targets,
		"chosen_target_kind": String(chosen.get("target_kind", "")),
		"chosen_target_placement_id": String(chosen.get("target_placement_id", "")),
		"chosen_target_reason": String(chosen.get("target_debug_reason", "")),
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

func _enemy_config() -> Dictionary:
	var scenario := ContentService.get_scenario(SCENARIO_ID)
	for config in scenario.get("enemy_factions", []):
		if config is Dictionary and String(config.get("faction_id", "")) == FACTION_ID:
			return config
	_fail("Could not find enemy config for %s" % FACTION_ID)
	return {}

func _fail(message: String) -> void:
	var payload := {
		"ok": false,
		"scenario_id": SCENARIO_ID,
		"faction_id": FACTION_ID,
		"error": message,
	}
	push_error(message)
	print("AI_ECONOMY_PRESSURE_REPORT %s" % JSON.stringify(payload))
	get_tree().quit(1)
