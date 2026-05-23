class_name BattleAutoplayBalanceHarnessRules
extends RefCounted

const ScenarioFactoryScript = preload("res://scripts/core/ScenarioFactory.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const DEFAULT_SAMPLE_LIMIT := 6
const DEFAULT_MINIMUM_SAMPLE_COUNT := 3
const DEFAULT_STEP_LIMIT := 72
const TERMINAL_STATES := ["victory", "defeat", "hero_defeat", "retreat", "surrender", "stalemate"]

static func build_sampling_report(
	input_config: Dictionary = {},
	scenario_key: String = "battle_scenario_ids",
	limit_key: String = "battle_sample_limit"
) -> Dictionary:
	var scenario_ids: Array = input_config.get(scenario_key, ["river-pass"])
	var max_samples: int = max(1, int(input_config.get(limit_key, DEFAULT_SAMPLE_LIMIT)))
	var minimum_samples: int = max(1, int(input_config.get("battle_minimum_sample_count", DEFAULT_MINIMUM_SAMPLE_COUNT)))
	var step_limit: int = max(1, int(input_config.get("battle_autoplay_step_limit", DEFAULT_STEP_LIMIT)))
	var samples := []
	var warnings := []
	var deferred := []
	for scenario_id_value in scenario_ids:
		if samples.size() >= max_samples:
			break
		var scenario_id := String(scenario_id_value)
		var scenario := ContentService.get_scenario(scenario_id)
		if scenario.is_empty():
			deferred.append("Missing battle scenario %s." % scenario_id)
			continue
		var encounters: Array = scenario.get("encounters", []) if scenario.get("encounters", []) is Array else []
		if encounters.is_empty():
			deferred.append("%s has no encounter placements for battle sampling." % scenario_id)
			continue
		for encounter in encounters:
			if samples.size() >= max_samples:
				break
			if not (encounter is Dictionary):
				continue
			var sample := run_battle_sample(scenario_id, encounter, step_limit)
			if sample.is_empty():
				deferred.append("%s/%s could not create a battle payload." % [scenario_id, String(encounter.get("placement_id", ""))])
			else:
				samples.append(sample)
	var aggregate := _aggregate_samples(samples)
	var completed_sample_count := int(aggregate.get("completed_sample_count", 0))
	var stalled_sample_count := int(aggregate.get("stalled_sample_count", 0))
	var requested_minimum = min(minimum_samples, max_samples)
	if samples.size() < requested_minimum:
		warnings.append("Battle autoplay sampled %d/%d required cases; add authored encounters or widen scenarios before treating the distribution as tuned." % [samples.size(), requested_minimum])
	elif samples.size() < max_samples:
		warnings.append("Battle autoplay reached %d/%d requested samples; current authored encounter breadth is narrow." % [samples.size(), max_samples])
	if completed_sample_count <= 0 and not samples.is_empty():
		warnings.append("Battle autoplay did not finish any sampled battle inside the step limit.")
	if stalled_sample_count > 0:
		warnings.append("Battle autoplay hit the step limit in %d sample(s); pacing or AI action choice needs inspection." % stalled_sample_count)
	return {
		"samples": samples,
		"summary": {
			"sample_count": samples.size(),
			"requested_sample_limit": max_samples,
			"minimum_sample_count": requested_minimum,
			"step_limit": step_limit,
			"completed_sample_count": completed_sample_count,
			"stalled_sample_count": stalled_sample_count,
			"distribution": aggregate.get("distribution", {}),
			"action_distribution": aggregate.get("action_distribution", {}),
			"average_steps_sampled": aggregate.get("average_steps_sampled", 0),
			"average_round_reached": aggregate.get("average_round_reached", 0),
			"average_player_health_remaining_pct": aggregate.get("average_player_health_remaining_pct", 0),
			"average_enemy_health_remaining_pct": aggregate.get("average_enemy_health_remaining_pct", 0),
			"policy": "deterministic_autoplay_sample_report_only",
		},
		"distribution": aggregate.get("distribution", {}),
		"action_distribution": aggregate.get("action_distribution", {}),
		"warnings": warnings,
		"deferred": deferred,
	}

static func run_battle_sample(scenario_id: String, encounter: Dictionary, step_limit: int = DEFAULT_STEP_LIMIT) -> Dictionary:
	var session: SessionStateStoreScript.SessionData = ScenarioFactoryScript.create_session(
		scenario_id,
		"normal",
		SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	)
	if session == null or session.scenario_id == "":
		return {}
	session.battle = BattleRules.create_battle_payload(session, encounter)
	if session.battle.is_empty():
		return {}
	var initial_signal := _battle_signal(session.battle)
	var initial_health := _side_health_totals(session.battle)
	var steps := 0
	var player_order_count := 0
	var enemy_ready_ticks := 0
	var invalid_order_count := 0
	var last_round := int(session.battle.get("round", 1))
	var final_state := "continue"
	var action_counts := {}
	var compact_turn_log := []
	var last_health: Dictionary = initial_health.duplicate(true)
	while steps < step_limit and not session.battle.is_empty():
		steps += 1
		last_round = int(session.battle.get("round", last_round))
		last_health = _side_health_totals(session.battle)
		var ready_result: Dictionary = BattleRules.resolve_if_battle_ready(session)
		final_state = String(ready_result.get("state", "continue"))
		if _is_terminal_state(final_state):
			last_health = _terminal_health_estimate(final_state, last_health, last_health)
			break
		if session.battle.is_empty():
			break
		var active_stack: Dictionary = BattleRules.get_active_stack(session.battle)
		if String(active_stack.get("side", "")) != "player":
			enemy_ready_ticks += 1
			continue
		var action := _choose_player_autoplay_action(session)
		var before_health := _side_health_totals(session.battle)
		var result: Dictionary = BattleRules.perform_player_action(session, action)
		if String(result.get("state", "")) == "invalid" and action != "defend":
			invalid_order_count += 1
			action = "defend"
			result = BattleRules.perform_player_action(session, action)
		action_counts[action] = int(action_counts.get(action, 0)) + 1
		player_order_count += 1
		final_state = String(result.get("state", "continue"))
		var after_health := _side_health_totals(session.battle)
		if _is_terminal_state(final_state):
			after_health = _terminal_health_estimate(final_state, before_health, after_health)
		if compact_turn_log.size() < 12:
			compact_turn_log.append({
				"step": steps,
				"round": last_round,
				"stack_id": String(active_stack.get("battle_id", "")),
				"action": action,
				"state": final_state,
				"player_health_delta": int(after_health.get("player", 0)) - int(before_health.get("player", 0)),
				"enemy_health_delta": int(after_health.get("enemy", 0)) - int(before_health.get("enemy", 0)),
			})
		if _is_terminal_state(final_state):
			last_health = _terminal_health_estimate(final_state, before_health, after_health)
			break
		last_health = after_health
	var final_health := _side_health_totals(session.battle)
	if session.battle.is_empty():
		final_health = last_health.duplicate(true)
	if not _is_terminal_state(final_state) and steps >= step_limit:
		final_state = "stalled_step_limit"
	return {
		"scenario_id": scenario_id,
		"encounter_placement_id": String(encounter.get("placement_id", "")),
		"encounter_id": String(encounter.get("encounter_id", "")),
		"steps_sampled": steps,
		"round_reached": last_round,
		"outcome_state": final_state,
		"completed": _is_terminal_state(final_state),
		"player_order_count": player_order_count,
		"enemy_ready_ticks": enemy_ready_ticks,
		"invalid_order_count": invalid_order_count,
		"action_counts": action_counts,
		"initial_health": initial_health,
		"final_health": final_health,
		"player_health_remaining_pct": _remaining_pct(initial_health, final_health, "player"),
		"enemy_health_remaining_pct": _remaining_pct(initial_health, final_health, "enemy"),
		"initial_battle_signature": _signature_for(initial_signal),
		"final_signal_signature": _signature_for({
			"state": final_state,
			"battle": _battle_signal(session.battle),
			"status": String(session.scenario_status),
			"last_battle_outcome": String(session.flags.get("last_battle_outcome", "")),
		}),
		"turn_log": compact_turn_log,
	}

static func _choose_player_autoplay_action(session: SessionStateStoreScript.SessionData) -> String:
	_select_focus_enemy(session)
	var availability: Dictionary = BattleRules.action_availability(session.battle)
	if bool(availability.get("shoot", false)):
		return "shoot"
	if bool(availability.get("strike", false)):
		return "strike"
	if bool(availability.get("advance", false)):
		return "advance"
	return "defend"

static func _select_focus_enemy(session: SessionStateStoreScript.SessionData) -> void:
	var best_id := ""
	var best_score := 2147483647
	for stack in session.battle.get("stacks", []):
		if not (stack is Dictionary):
			continue
		if String(stack.get("side", "")) != "enemy":
			continue
		if int(stack.get("count", 0)) <= 0 or int(stack.get("total_health", 0)) <= 0:
			continue
		var score := int(stack.get("total_health", 0)) * 1000 + int(stack.get("count", 0))
		if score < best_score:
			best_score = score
			best_id = String(stack.get("battle_id", ""))
	if best_id != "":
		BattleRules.select_target(session, best_id)

static func _aggregate_samples(samples: Array) -> Dictionary:
	var distribution := {}
	var action_distribution := {}
	var completed_sample_count := 0
	var stalled_sample_count := 0
	var total_steps := 0
	var total_rounds := 0
	var total_player_remaining_pct := 0
	var total_enemy_remaining_pct := 0
	for sample in samples:
		if not (sample is Dictionary):
			continue
		var outcome := String(sample.get("outcome_state", "unknown"))
		distribution[outcome] = int(distribution.get(outcome, 0)) + 1
		if bool(sample.get("completed", false)):
			completed_sample_count += 1
		if outcome == "stalled_step_limit":
			stalled_sample_count += 1
		total_steps += int(sample.get("steps_sampled", 0))
		total_rounds += int(sample.get("round_reached", 0))
		total_player_remaining_pct += int(sample.get("player_health_remaining_pct", 0))
		total_enemy_remaining_pct += int(sample.get("enemy_health_remaining_pct", 0))
		var action_counts: Dictionary = sample.get("action_counts", {}) if sample.get("action_counts", {}) is Dictionary else {}
		for action in action_counts.keys():
			action_distribution[String(action)] = int(action_distribution.get(String(action), 0)) + int(action_counts[action])
	var count: int = max(1, samples.size())
	return {
		"distribution": distribution,
		"action_distribution": action_distribution,
		"completed_sample_count": completed_sample_count,
		"stalled_sample_count": stalled_sample_count,
		"average_steps_sampled": int(round(float(total_steps) / float(count))),
		"average_round_reached": int(round(float(total_rounds) / float(count))),
		"average_player_health_remaining_pct": int(round(float(total_player_remaining_pct) / float(count))),
		"average_enemy_health_remaining_pct": int(round(float(total_enemy_remaining_pct) / float(count))),
	}

static func _side_health_totals(battle: Dictionary) -> Dictionary:
	var totals := {"player": 0, "enemy": 0}
	for stack in battle.get("stacks", []):
		if not (stack is Dictionary):
			continue
		var side := String(stack.get("side", ""))
		if not totals.has(side):
			continue
		totals[side] = int(totals.get(side, 0)) + max(0, int(stack.get("total_health", 0)))
	return totals

static func _remaining_pct(initial_health: Dictionary, final_health: Dictionary, side: String) -> int:
	var initial_value: int = max(0, int(initial_health.get(side, 0)))
	if initial_value <= 0:
		return 0
	return int(round(float(max(0, int(final_health.get(side, 0)))) * 100.0 / float(initial_value)))

static func _terminal_health_estimate(state: String, before_health: Dictionary, after_health: Dictionary) -> Dictionary:
	var estimate: Dictionary = after_health.duplicate(true)
	if int(estimate.get("player", 0)) <= 0 and int(estimate.get("enemy", 0)) <= 0:
		estimate = before_health.duplicate(true)
	match state:
		"victory":
			estimate["enemy"] = 0
		"defeat", "hero_defeat":
			estimate["player"] = 0
		_:
			pass
	return estimate

static func _battle_signal(battle: Dictionary) -> Dictionary:
	if battle.is_empty():
		return {}
	var side_counts := {"player": 0, "enemy": 0}
	var living_counts := {"player": 0, "enemy": 0}
	var health_totals := _side_health_totals(battle)
	for stack in battle.get("stacks", []):
		if not (stack is Dictionary):
			continue
		var side := String(stack.get("side", ""))
		side_counts[side] = int(side_counts.get(side, 0)) + 1
		if int(stack.get("count", 0)) > 0 and int(stack.get("total_health", 0)) > 0:
			living_counts[side] = int(living_counts.get(side, 0)) + 1
	return {
		"encounter_id": String(battle.get("encounter_id", "")),
		"round": int(battle.get("round", 0)),
		"distance": int(battle.get("distance", 0)),
		"side_counts": side_counts,
		"living_counts": living_counts,
		"health_totals": health_totals,
		"active_stack_side": String(BattleRules.get_active_stack(battle).get("side", "")),
	}

static func _is_terminal_state(state: String) -> bool:
	return state in TERMINAL_STATES

static func _signature_for(value: Variant) -> String:
	return _hash32_hex(_stable_stringify(value))

static func _stable_stringify(value: Variant) -> String:
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort()
		var parts := []
		for key in keys:
			parts.append("%s:%s" % [JSON.stringify(String(key)), _stable_stringify(value[key])])
		return "{%s}" % ",".join(parts)
	if value is Array:
		var parts := []
		for item in value:
			parts.append(_stable_stringify(item))
		return "[%s]" % ",".join(parts)
	if value is float:
		return "%.6f" % value
	return JSON.stringify(value)

static func _hash32_hex(text: String) -> String:
	var h := 2166136261
	for index in range(text.length()):
		h = h ^ text.unicode_at(index)
		h = (h * 16777619) & 0xffffffff
	return "%08x" % h
