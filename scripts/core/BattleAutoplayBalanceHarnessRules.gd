class_name BattleAutoplayBalanceHarnessRules
extends RefCounted

const ScenarioFactoryScript = preload("res://scripts/core/ScenarioFactory.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const BattleAiRulesScript = preload("res://scripts/core/BattleAiRules.gd")

const DEFAULT_SAMPLE_LIMIT := 6
const DEFAULT_MINIMUM_SAMPLE_COUNT := 3
const DEFAULT_STEP_LIMIT := 72
const COMBAT_FEEL_MIN_ACTION_DIVERSITY := 3
const COMBAT_FEEL_MAX_PRIMARY_ACTION_PCT := 70
const COMBAT_FEEL_MIN_TOTAL_DAMAGE_PER_ROUND := 12
const COMBAT_FEEL_MAX_TERMINAL_MARGIN_PCT := 65
const COMBAT_FEEL_MAX_OUTCOME_BIAS_PCT := 75
const COMBAT_FEEL_MAX_BURST_OR_GRIND_PCT := 50
const DEFAULT_SCENARIO_IDS := [
	"river-pass",
	"causeway-stand",
	"fen-crown",
	"stonewake-watch",
]
const TERMINAL_STATES := ["victory", "defeat", "hero_defeat", "retreat", "surrender", "stalemate"]

static func build_sampling_report(
	input_config: Dictionary = {},
	scenario_key: String = "battle_scenario_ids",
	limit_key: String = "battle_sample_limit"
) -> Dictionary:
	var scenario_ids: Array = input_config.get(scenario_key, DEFAULT_SCENARIO_IDS)
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
	var combat_feel_gate := _combat_feel_gate(aggregate, samples.size(), max_samples, requested_minimum)
	if samples.size() < requested_minimum:
		warnings.append("Battle autoplay sampled %d/%d required cases; add authored encounters or widen scenarios before treating the distribution as tuned." % [samples.size(), requested_minimum])
	elif samples.size() < max_samples:
		warnings.append("Battle autoplay reached %d/%d requested samples; current authored encounter breadth is narrow." % [samples.size(), max_samples])
	if completed_sample_count <= 0 and not samples.is_empty():
		warnings.append("Battle autoplay did not finish any sampled battle inside the step limit.")
	if stalled_sample_count > 0:
		warnings.append("Battle autoplay hit the step limit in %d sample(s); pacing or AI action choice needs inspection." % stalled_sample_count)
	if int(aggregate.get("invalid_order_count", 0)) > 0:
		warnings.append("Battle autoplay produced %d invalid player order(s); action choice or availability needs inspection." % int(aggregate.get("invalid_order_count", 0)))
	if int(aggregate.get("action_diversity_count", 0)) <= 1 and completed_sample_count > 0:
		warnings.append("Battle autoplay action mix collapsed to one order type; tactical depth needs inspection.")
	for gate_warning in combat_feel_gate.get("warnings", []):
		warnings.append(String(gate_warning))
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
			"average_player_damage_dealt": aggregate.get("average_player_damage_dealt", 0),
			"average_enemy_damage_dealt": aggregate.get("average_enemy_damage_dealt", 0),
			"average_total_damage_per_round": aggregate.get("average_total_damage_per_round", 0),
			"average_terminal_health_margin_pct": aggregate.get("average_terminal_health_margin_pct", 0),
			"average_initial_initiative_spread": aggregate.get("average_initial_initiative_spread", 0),
			"invalid_order_count": aggregate.get("invalid_order_count", 0),
			"action_diversity_count": aggregate.get("action_diversity_count", 0),
			"primary_action_id": String(aggregate.get("primary_action_id", "")),
			"primary_action_pct": aggregate.get("primary_action_pct", 0),
			"primary_outcome_state": String(aggregate.get("primary_outcome_state", "")),
			"primary_outcome_pct": aggregate.get("primary_outcome_pct", 0),
			"primary_pacing_band": String(aggregate.get("primary_pacing_band", "")),
			"primary_pacing_band_pct": aggregate.get("primary_pacing_band_pct", 0),
			"terrain_distribution": aggregate.get("terrain_distribution", {}),
			"scenario_distribution": aggregate.get("scenario_distribution", {}),
			"difficulty_distribution": aggregate.get("difficulty_distribution", {}),
			"pacing_band_distribution": aggregate.get("pacing_band_distribution", {}),
			"initial_role_distribution": aggregate.get("initial_role_distribution", {}),
			"initial_ability_distribution": aggregate.get("initial_ability_distribution", {}),
			"combat_feel_gate": combat_feel_gate,
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
	var initial_stack_profile := _stack_profile(session.battle)
	var battle_terrain := String(session.battle.get("terrain", "unknown"))
	var encounter_difficulty := int(session.battle.get("encounter_difficulty", 0))
	var steps := 0
	var player_order_count := 0
	var enemy_ready_ticks := 0
	var invalid_order_count := 0
	var last_round := int(session.battle.get("round", 1))
	var final_state := "continue"
	var action_counts := {}
	var damage_totals := {"player": 0, "enemy": 0}
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
		var decision := player_autoplay_decision_report(session, true)
		var action := String(decision.get("action", "defend"))
		var before_health := _side_health_totals(session.battle)
		var result: Dictionary = BattleRules.perform_player_action(session, action)
		if String(result.get("state", "")) == "invalid" and action != "defend":
			invalid_order_count += 1
			decision["fallback_from_action"] = action
			action = "defend"
			decision["action"] = action
			decision["fallback_reason"] = "selected_autoplay_order_invalid"
			result = BattleRules.perform_player_action(session, action)
		action_counts[action] = int(action_counts.get(action, 0)) + 1
		player_order_count += 1
		final_state = String(result.get("state", "continue"))
		var after_health := _side_health_totals(session.battle)
		if _is_terminal_state(final_state):
			after_health = _terminal_health_estimate(final_state, before_health, after_health)
		var player_damage_dealt: int = max(0, int(before_health.get("enemy", 0)) - int(after_health.get("enemy", 0)))
		var enemy_damage_dealt: int = max(0, int(before_health.get("player", 0)) - int(after_health.get("player", 0)))
		damage_totals["player"] = int(damage_totals.get("player", 0)) + player_damage_dealt
		damage_totals["enemy"] = int(damage_totals.get("enemy", 0)) + enemy_damage_dealt
		if compact_turn_log.size() < 12:
			compact_turn_log.append({
				"step": steps,
				"round": last_round,
				"stack_id": String(active_stack.get("battle_id", "")),
				"action": action,
				"state": final_state,
				"player_health_delta": int(after_health.get("player", 0)) - int(before_health.get("player", 0)),
				"enemy_health_delta": int(after_health.get("enemy", 0)) - int(before_health.get("enemy", 0)),
				"player_damage_dealt": player_damage_dealt,
				"enemy_damage_dealt": enemy_damage_dealt,
				"autoplay_decision": _compact_decision(decision),
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
	var player_remaining_pct := _remaining_pct(initial_health, final_health, "player")
	var enemy_remaining_pct := _remaining_pct(initial_health, final_health, "enemy")
	var completed_rounds: int = max(1, last_round)
	return {
		"scenario_id": scenario_id,
		"encounter_placement_id": String(encounter.get("placement_id", "")),
		"encounter_id": String(encounter.get("encounter_id", "")),
		"terrain": battle_terrain,
		"encounter_difficulty": encounter_difficulty,
		"steps_sampled": steps,
		"round_reached": last_round,
		"outcome_state": final_state,
		"completed": _is_terminal_state(final_state),
		"player_order_count": player_order_count,
		"enemy_ready_ticks": enemy_ready_ticks,
		"invalid_order_count": invalid_order_count,
		"action_counts": action_counts,
		"action_mix": _action_mix_summary(action_counts, player_order_count),
		"initial_health": initial_health,
		"final_health": final_health,
		"player_health_remaining_pct": player_remaining_pct,
		"enemy_health_remaining_pct": enemy_remaining_pct,
		"terminal_health_margin_pct": abs(player_remaining_pct - enemy_remaining_pct),
		"damage_totals": damage_totals,
		"damage_per_round": {
			"player": int(round(float(int(damage_totals.get("player", 0))) / float(completed_rounds))),
			"enemy": int(round(float(int(damage_totals.get("enemy", 0))) / float(completed_rounds))),
			"total": int(round(float(int(damage_totals.get("player", 0)) + int(damage_totals.get("enemy", 0))) / float(completed_rounds))),
		},
		"pacing_band": _pacing_band(final_state, last_round, steps, step_limit),
		"initial_stack_profile": initial_stack_profile,
		"initial_battle_signature": _signature_for(initial_signal),
		"final_signal_signature": _signature_for({
			"state": final_state,
			"battle": _battle_signal(session.battle),
			"status": String(session.scenario_status),
			"last_battle_outcome": String(session.flags.get("last_battle_outcome", "")),
		}),
		"turn_log": compact_turn_log,
	}

static func player_autoplay_decision_report(session: SessionStateStoreScript.SessionData, apply_selection: bool = false) -> Dictionary:
	if session == null or session.battle.is_empty():
		return {"action": "defend", "reason": "no_active_battle", "scoring_policy": "battle_ai_nonspell_tactical_order_v1"}
	var active_stack: Dictionary = BattleRules.get_active_stack(session.battle)
	if active_stack.is_empty() or String(active_stack.get("side", "")) != "player":
		return {"action": "defend", "reason": "no_active_player_stack", "scoring_policy": "battle_ai_nonspell_tactical_order_v1"}
	var decision := BattleAiRulesScript.choose_stack_tactical_order(session.battle, active_stack, "enemy")
	if decision.is_empty():
		_select_focus_enemy(session)
		return _fallback_player_autoplay_decision(session, "no_scored_tactical_order", apply_selection)
	var target_id := String(decision.get("target_battle_id", ""))
	if target_id != "" and String(decision.get("action", "")) in ["shoot", "strike"]:
		if apply_selection:
			var selection_result := BattleRules.select_target(session, target_id)
			decision["target_selection_ok"] = bool(selection_result.get("ok", false))
			decision["target_selection_message"] = String(selection_result.get("message", ""))
		else:
			decision["target_selection_ok"] = true
	var action := String(decision.get("action", "defend"))
	var availability: Dictionary = BattleRules.action_availability(session.battle)
	if bool(availability.get(action, false)):
		decision["reason"] = "scored_tactical_order"
		return decision
	return _fallback_player_autoplay_decision(session, "scored_order_unavailable", apply_selection, decision)

static func _fallback_player_autoplay_decision(
	session: SessionStateStoreScript.SessionData,
	reason: String,
	apply_selection: bool,
	scored_decision: Dictionary = {}
) -> Dictionary:
	_select_focus_enemy(session)
	var availability: Dictionary = BattleRules.action_availability(session.battle)
	var fallback_action := "defend"
	if bool(availability.get("shoot", false)):
		fallback_action = "shoot"
	elif bool(availability.get("strike", false)):
		fallback_action = "strike"
	elif bool(availability.get("advance", false)):
		fallback_action = "advance"
	return {
		"action": fallback_action,
		"target_battle_id": String(session.battle.get("selected_target_id", "")),
		"reason": reason,
		"scoring_policy": "battle_ai_nonspell_tactical_order_v1",
		"fallback_policy": "legacy_availability_order",
		"scored_decision": scored_decision,
		"applied_selection": apply_selection,
	}

static func _compact_decision(decision: Dictionary) -> Dictionary:
	var compact := {
		"action": String(decision.get("action", "")),
		"target_battle_id": String(decision.get("target_battle_id", "")),
		"reason": String(decision.get("reason", "")),
		"scoring_policy": String(decision.get("scoring_policy", "")),
	}
	if decision.has("score"):
		compact["score"] = float(decision.get("score", 0.0))
	if decision.has("candidate_scores"):
		compact["candidate_scores"] = decision.get("candidate_scores", {})
	if decision.has("fallback_policy"):
		compact["fallback_policy"] = String(decision.get("fallback_policy", ""))
	if decision.has("fallback_reason"):
		compact["fallback_reason"] = String(decision.get("fallback_reason", ""))
	return compact

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
	var invalid_order_count := 0
	var total_steps := 0
	var total_rounds := 0
	var total_player_remaining_pct := 0
	var total_enemy_remaining_pct := 0
	var total_player_damage_dealt := 0
	var total_enemy_damage_dealt := 0
	var total_damage_per_round := 0
	var total_terminal_margin_pct := 0
	var total_initial_initiative_spread := 0
	var terrain_distribution := {}
	var scenario_distribution := {}
	var difficulty_distribution := {}
	var pacing_band_distribution := {}
	var initial_role_distribution := {}
	var initial_ability_distribution := {}
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
		total_terminal_margin_pct += int(sample.get("terminal_health_margin_pct", 0))
		invalid_order_count += int(sample.get("invalid_order_count", 0))
		var damage_totals: Dictionary = sample.get("damage_totals", {}) if sample.get("damage_totals", {}) is Dictionary else {}
		total_player_damage_dealt += int(damage_totals.get("player", 0))
		total_enemy_damage_dealt += int(damage_totals.get("enemy", 0))
		var damage_per_round: Dictionary = sample.get("damage_per_round", {}) if sample.get("damage_per_round", {}) is Dictionary else {}
		total_damage_per_round += int(damage_per_round.get("total", 0))
		var terrain_id := String(sample.get("terrain", "unknown"))
		terrain_distribution[terrain_id] = int(terrain_distribution.get(terrain_id, 0)) + 1
		var scenario_id := String(sample.get("scenario_id", "unknown"))
		scenario_distribution[scenario_id] = int(scenario_distribution.get(scenario_id, 0)) + 1
		var difficulty_id := str(int(sample.get("encounter_difficulty", 0)))
		difficulty_distribution[difficulty_id] = int(difficulty_distribution.get(difficulty_id, 0)) + 1
		var pacing_band := String(sample.get("pacing_band", "unknown"))
		pacing_band_distribution[pacing_band] = int(pacing_band_distribution.get(pacing_band, 0)) + 1
		var profile: Dictionary = sample.get("initial_stack_profile", {}) if sample.get("initial_stack_profile", {}) is Dictionary else {}
		var initiative_profile: Dictionary = profile.get("initiative", {}) if profile.get("initiative", {}) is Dictionary else {}
		total_initial_initiative_spread += int(initiative_profile.get("spread", 0))
		_merge_count_map(initial_role_distribution, profile.get("role_counts", {}))
		_merge_count_map(initial_ability_distribution, profile.get("ability_counts", {}))
		var action_counts: Dictionary = sample.get("action_counts", {}) if sample.get("action_counts", {}) is Dictionary else {}
		for action in action_counts.keys():
			action_distribution[String(action)] = int(action_distribution.get(String(action), 0)) + int(action_counts[action])
	var count: int = max(1, samples.size())
	var primary_action := _primary_action(action_distribution)
	var primary_outcome := _primary_count_entry(distribution, "outcome")
	var primary_pacing_band := _primary_count_entry(pacing_band_distribution, "pacing_band")
	return {
		"distribution": distribution,
		"action_distribution": action_distribution,
		"completed_sample_count": completed_sample_count,
		"stalled_sample_count": stalled_sample_count,
		"invalid_order_count": invalid_order_count,
		"average_steps_sampled": int(round(float(total_steps) / float(count))),
		"average_round_reached": int(round(float(total_rounds) / float(count))),
		"average_player_health_remaining_pct": int(round(float(total_player_remaining_pct) / float(count))),
		"average_enemy_health_remaining_pct": int(round(float(total_enemy_remaining_pct) / float(count))),
		"average_player_damage_dealt": int(round(float(total_player_damage_dealt) / float(count))),
		"average_enemy_damage_dealt": int(round(float(total_enemy_damage_dealt) / float(count))),
		"average_total_damage_per_round": int(round(float(total_damage_per_round) / float(count))),
		"average_terminal_health_margin_pct": int(round(float(total_terminal_margin_pct) / float(count))),
		"average_initial_initiative_spread": int(round(float(total_initial_initiative_spread) / float(count))),
		"action_diversity_count": action_distribution.keys().size(),
		"primary_action_id": String(primary_action.get("action", "")),
		"primary_action_pct": int(primary_action.get("pct", 0)),
		"primary_outcome_state": String(primary_outcome.get("outcome", "")),
		"primary_outcome_pct": int(primary_outcome.get("pct", 0)),
		"primary_pacing_band": String(primary_pacing_band.get("pacing_band", "")),
		"primary_pacing_band_pct": int(primary_pacing_band.get("pct", 0)),
		"terrain_distribution": terrain_distribution,
		"scenario_distribution": scenario_distribution,
		"difficulty_distribution": difficulty_distribution,
		"pacing_band_distribution": pacing_band_distribution,
		"initial_role_distribution": initial_role_distribution,
		"initial_ability_distribution": initial_ability_distribution,
	}

static func _combat_feel_gate(aggregate: Dictionary, sample_count: int, requested_sample_limit: int, requested_minimum: int) -> Dictionary:
	var warnings := []
	var hard_failures := []
	var primary_pacing_band := String(aggregate.get("primary_pacing_band", ""))
	var burst_or_grind_pct := 0
	if primary_pacing_band in ["burst", "grind", "stalled"]:
		burst_or_grind_pct = int(aggregate.get("primary_pacing_band_pct", 0))
	if sample_count < requested_minimum:
		hard_failures.append("sample_count_below_minimum")
	elif sample_count < requested_sample_limit:
		warnings.append("sample_count_below_requested_limit")
	if int(aggregate.get("completed_sample_count", 0)) <= 0 and sample_count > 0:
		hard_failures.append("no_completed_samples")
	if int(aggregate.get("stalled_sample_count", 0)) > 0:
		warnings.append("stalled_samples_present")
	if int(aggregate.get("invalid_order_count", 0)) > 0:
		warnings.append("invalid_autoplay_orders_present")
	if int(aggregate.get("action_diversity_count", 0)) < COMBAT_FEEL_MIN_ACTION_DIVERSITY:
		warnings.append("low_action_diversity")
	if int(aggregate.get("primary_action_pct", 0)) > COMBAT_FEEL_MAX_PRIMARY_ACTION_PCT:
		warnings.append("dominant_action_over_threshold")
	if int(aggregate.get("average_total_damage_per_round", 0)) < COMBAT_FEEL_MIN_TOTAL_DAMAGE_PER_ROUND:
		warnings.append("low_damage_pacing")
	if int(aggregate.get("average_terminal_health_margin_pct", 0)) > COMBAT_FEEL_MAX_TERMINAL_MARGIN_PCT:
		warnings.append("high_terminal_health_margin")
	if int(aggregate.get("primary_outcome_pct", 0)) > COMBAT_FEEL_MAX_OUTCOME_BIAS_PCT:
		warnings.append("outcome_bias_over_threshold")
	if burst_or_grind_pct > COMBAT_FEEL_MAX_BURST_OR_GRIND_PCT:
		warnings.append("pacing_band_extreme_over_threshold")
	var status := "pass"
	if not hard_failures.is_empty():
		status = "fail"
	elif not warnings.is_empty():
		status = "warning"
	return {
		"status": status,
		"policy": "report_only_combat_feel_thresholds_v1",
		"sample_count": sample_count,
		"requested_sample_limit": requested_sample_limit,
		"minimum_sample_count": requested_minimum,
		"completed_sample_count": int(aggregate.get("completed_sample_count", 0)),
		"stalled_sample_count": int(aggregate.get("stalled_sample_count", 0)),
		"invalid_order_count": int(aggregate.get("invalid_order_count", 0)),
		"action_diversity_count": int(aggregate.get("action_diversity_count", 0)),
		"primary_action_id": String(aggregate.get("primary_action_id", "")),
		"primary_action_pct": int(aggregate.get("primary_action_pct", 0)),
		"average_total_damage_per_round": int(aggregate.get("average_total_damage_per_round", 0)),
		"average_terminal_health_margin_pct": int(aggregate.get("average_terminal_health_margin_pct", 0)),
		"primary_outcome_state": String(aggregate.get("primary_outcome_state", "")),
		"primary_outcome_pct": int(aggregate.get("primary_outcome_pct", 0)),
		"primary_pacing_band": primary_pacing_band,
		"primary_pacing_band_pct": int(aggregate.get("primary_pacing_band_pct", 0)),
		"burst_or_grind_pct": burst_or_grind_pct,
		"thresholds": {
			"min_action_diversity": COMBAT_FEEL_MIN_ACTION_DIVERSITY,
			"max_primary_action_pct": COMBAT_FEEL_MAX_PRIMARY_ACTION_PCT,
			"min_total_damage_per_round": COMBAT_FEEL_MIN_TOTAL_DAMAGE_PER_ROUND,
			"max_terminal_health_margin_pct": COMBAT_FEEL_MAX_TERMINAL_MARGIN_PCT,
			"max_outcome_bias_pct": COMBAT_FEEL_MAX_OUTCOME_BIAS_PCT,
			"max_burst_or_grind_pct": COMBAT_FEEL_MAX_BURST_OR_GRIND_PCT,
		},
		"warning_count": warnings.size(),
		"failure_count": hard_failures.size(),
		"warnings": warnings,
		"failures": hard_failures,
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

static func _stack_profile(battle: Dictionary) -> Dictionary:
	var side_stack_counts := {"player": 0, "enemy": 0}
	var side_unit_counts := {"player": 0, "enemy": 0}
	var ranged_stack_counts := {"player": 0, "enemy": 0}
	var role_counts := {}
	var ability_counts := {}
	var initiative_min := 2147483647
	var initiative_max := -2147483648
	var initiative_total := 0
	var initiative_count := 0
	for stack in battle.get("stacks", []):
		if not (stack is Dictionary):
			continue
		var side := String(stack.get("side", ""))
		if not side_stack_counts.has(side):
			continue
		var stack_count: int = max(0, int(stack.get("base_count", 0)))
		side_stack_counts[side] = int(side_stack_counts.get(side, 0)) + 1
		side_unit_counts[side] = int(side_unit_counts.get(side, 0)) + stack_count
		if bool(stack.get("ranged", false)):
			ranged_stack_counts[side] = int(ranged_stack_counts.get(side, 0)) + 1
		var unit: Dictionary = ContentService.get_unit(String(stack.get("unit_id", "")))
		var role := String(unit.get("role", "unknown"))
		role_counts[role] = int(role_counts.get(role, 0)) + 1
		var initiative := int(stack.get("initiative", 0))
		initiative_min = min(initiative_min, initiative)
		initiative_max = max(initiative_max, initiative)
		initiative_total += initiative
		initiative_count += 1
		var abilities: Array = stack.get("abilities", []) if stack.get("abilities", []) is Array else []
		for ability in abilities:
			if not (ability is Dictionary):
				continue
			var ability_id := String(ability.get("id", "unknown"))
			ability_counts[ability_id] = int(ability_counts.get(ability_id, 0)) + 1
	if initiative_count <= 0:
		initiative_min = 0
		initiative_max = 0
	return {
		"side_stack_counts": side_stack_counts,
		"side_unit_counts": side_unit_counts,
		"ranged_stack_counts": ranged_stack_counts,
		"role_counts": role_counts,
		"ability_counts": ability_counts,
		"ability_instance_count": _count_map_total(ability_counts),
		"initiative": {
			"min": initiative_min,
			"max": initiative_max,
			"spread": initiative_max - initiative_min,
			"average": int(round(float(initiative_total) / float(max(1, initiative_count)))),
		},
	}

static func _action_mix_summary(action_counts: Dictionary, player_order_count: int) -> Dictionary:
	var primary := _primary_action(action_counts)
	return {
		"distinct_action_count": action_counts.keys().size(),
		"primary_action_id": String(primary.get("action", "")),
		"primary_action_pct": int(primary.get("pct", 0)),
		"player_order_count": player_order_count,
	}

static func _primary_action(action_counts: Dictionary) -> Dictionary:
	var best_action := ""
	var best_count := 0
	var total := 0
	for action in action_counts.keys():
		var count := int(action_counts[action])
		total += count
		if count > best_count or (count == best_count and (best_action == "" or String(action) < best_action)):
			best_action = String(action)
			best_count = count
	return {
		"action": best_action,
		"count": best_count,
		"pct": int(round(float(best_count) * 100.0 / float(max(1, total)))),
	}

static func _primary_count_entry(counts: Dictionary, id_key: String) -> Dictionary:
	var best_id := ""
	var best_count := 0
	var total := 0
	for key in counts.keys():
		var count := int(counts[key])
		total += count
		if count > best_count or (count == best_count and (best_id == "" or String(key) < best_id)):
			best_id = String(key)
			best_count = count
	var result := {
		"count": best_count,
		"pct": int(round(float(best_count) * 100.0 / float(max(1, total)))),
	}
	result[id_key] = best_id
	return result

static func _pacing_band(final_state: String, round_reached: int, steps: int, step_limit: int) -> String:
	if final_state == "stalled_step_limit" or steps >= step_limit:
		return "stalled"
	if round_reached <= 2:
		return "burst"
	if round_reached <= 5:
		return "standard"
	if round_reached <= 8:
		return "extended"
	return "grind"

static func _merge_count_map(target: Dictionary, source_value: Variant) -> void:
	if not (source_value is Dictionary):
		return
	var source: Dictionary = source_value
	for key in source.keys():
		target[String(key)] = int(target.get(String(key), 0)) + int(source[key])

static func _count_map_total(source: Dictionary) -> int:
	var total := 0
	for key in source.keys():
		total += int(source[key])
	return total

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
