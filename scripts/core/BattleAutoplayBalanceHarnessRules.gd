class_name BattleAutoplayBalanceHarnessRules
extends RefCounted

const ScenarioFactoryScript = preload("res://scripts/core/ScenarioFactory.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const BattleAiRulesScript = preload("res://scripts/core/BattleAiRules.gd")

const DEFAULT_SAMPLE_LIMIT := 12
const DEFAULT_MINIMUM_SAMPLE_COUNT := 6
const DEFAULT_STEP_LIMIT := 72
const DEFAULT_DIFFICULTY_SWEEP_IDS := ["normal", "hard"]
const DIFFICULTY_SWEEP_SCHEMA := "battle_autoplay_difficulty_sweep_v1"
const DIFFICULTY_SWEEP_POLICY := "report_only_launch_difficulty_balance_probe"
const COMBAT_FEEL_MIN_ACTION_DIVERSITY := 3
const COMBAT_FEEL_MAX_PRIMARY_ACTION_PCT := 70
const COMBAT_FEEL_MIN_TOTAL_DAMAGE_PER_ROUND := 12
const COMBAT_FEEL_MAX_TERMINAL_MARGIN_PCT := 65
const COMBAT_FEEL_MAX_OUTCOME_BIAS_PCT := 75
const COMBAT_FEEL_MAX_BURST_OR_GRIND_PCT := 50
const BALANCE_MATRIX_MIN_DIFFICULTY_COHORTS := 3
const BALANCE_MATRIX_MIN_TERRAIN_COHORTS := 2
const BALANCE_MATRIX_MIN_ABILITY_COHORTS := 4
const BALANCE_MATRIX_TERMINAL_MARGIN_OUTLIER_PCT := 90
const TUNING_QUEUE_SCHEMA := "battle_autoplay_balance_tuning_queue_v1"
const TUNING_QUEUE_POLICY := "report_only_no_runtime_tuning"
const TUNING_QUEUE_SAMPLE_MARGIN_WATCH_PCT := 75
const TUNING_QUEUE_COHORT_MARGIN_WATCH_PCT := 70
const TUNING_QUEUE_COHORT_OUTCOME_WATCH_PCT := 90
const TUNING_QUEUE_HIGH_PRIORITY := 80
const TUNING_QUEUE_MEDIUM_PRIORITY := 50
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
			var sample := run_battle_sample(scenario_id, encounter, step_limit, String(input_config.get("battle_launch_difficulty", "normal")))
			if sample.is_empty():
				deferred.append("%s/%s could not create a battle payload." % [scenario_id, String(encounter.get("placement_id", ""))])
			else:
				samples.append(sample)
	var aggregate := _aggregate_samples(samples)
	var completed_sample_count := int(aggregate.get("completed_sample_count", 0))
	var stalled_sample_count := int(aggregate.get("stalled_sample_count", 0))
	var requested_minimum = min(minimum_samples, max_samples)
	var combat_feel_gate := _combat_feel_gate(aggregate, samples.size(), max_samples, requested_minimum)
	var tuning_queue := balance_tuning_queue(aggregate, samples, combat_feel_gate)
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
			"launch_difficulty_distribution": aggregate.get("launch_difficulty_distribution", {}),
			"pacing_band_distribution": aggregate.get("pacing_band_distribution", {}),
			"initial_role_distribution": aggregate.get("initial_role_distribution", {}),
			"initial_ability_distribution": aggregate.get("initial_ability_distribution", {}),
			"balance_matrix": aggregate.get("balance_matrix", {}),
			"balance_matrix_gate": aggregate.get("balance_matrix_gate", {}),
			"combat_feel_gate": combat_feel_gate,
			"balance_tuning_queue": tuning_queue,
			"policy": "deterministic_autoplay_sample_report_only",
		},
		"distribution": aggregate.get("distribution", {}),
		"action_distribution": aggregate.get("action_distribution", {}),
		"balance_tuning_queue": tuning_queue,
		"warnings": warnings,
		"deferred": deferred,
	}

static func build_difficulty_sweep_report(input_config: Dictionary = {}) -> Dictionary:
	var difficulty_ids: Array = input_config.get("battle_difficulty_sweep_ids", DEFAULT_DIFFICULTY_SWEEP_IDS)
	var rows := []
	var warnings := []
	var failures := []
	var row_by_difficulty := {}
	var sample_limit: int = max(1, int(input_config.get("battle_difficulty_sweep_sample_limit", DEFAULT_SAMPLE_LIMIT)))
	var minimum_samples: int = max(1, int(input_config.get("battle_difficulty_sweep_minimum_sample_count", min(DEFAULT_MINIMUM_SAMPLE_COUNT, sample_limit))))
	for difficulty_value in difficulty_ids:
		var difficulty_id := String(difficulty_value)
		var difficulty_config := input_config.duplicate(true)
		difficulty_config["battle_launch_difficulty"] = difficulty_id
		difficulty_config["battle_sample_limit"] = sample_limit
		difficulty_config["battle_minimum_sample_count"] = minimum_samples
		var report := build_sampling_report(difficulty_config)
		var summary: Dictionary = report.get("summary", {}) if report.get("summary", {}) is Dictionary else {}
		var gate: Dictionary = summary.get("combat_feel_gate", {}) if summary.get("combat_feel_gate", {}) is Dictionary else {}
		var matrix_gate: Dictionary = summary.get("balance_matrix_gate", {}) if summary.get("balance_matrix_gate", {}) is Dictionary else {}
		var tuning_queue: Dictionary = summary.get("balance_tuning_queue", {}) if summary.get("balance_tuning_queue", {}) is Dictionary else {}
		var row := {
			"difficulty_id": difficulty_id,
			"sample_count": int(summary.get("sample_count", 0)),
			"completed_sample_count": int(summary.get("completed_sample_count", 0)),
			"stalled_sample_count": int(summary.get("stalled_sample_count", 0)),
			"invalid_order_count": int(summary.get("invalid_order_count", 0)),
			"average_terminal_health_margin_pct": int(summary.get("average_terminal_health_margin_pct", 0)),
			"average_total_damage_per_round": int(summary.get("average_total_damage_per_round", 0)),
			"average_player_health_remaining_pct": int(summary.get("average_player_health_remaining_pct", 0)),
			"average_enemy_health_remaining_pct": int(summary.get("average_enemy_health_remaining_pct", 0)),
			"primary_outcome_state": String(summary.get("primary_outcome_state", "")),
			"primary_outcome_pct": int(summary.get("primary_outcome_pct", 0)),
			"combat_feel_gate_status": String(gate.get("status", "")),
			"balance_matrix_gate_status": String(matrix_gate.get("status", "")),
			"tuning_queue_status": String(tuning_queue.get("status", "")),
			"tuning_queue_item_count": int(tuning_queue.get("item_count", 0)),
			"tuning_queue_signature": String(tuning_queue.get("queue_signature", "")),
			"tuning_queue_categories": _array_of_strings(tuning_queue.get("coverage", {}).get("categories", []) if tuning_queue.get("coverage", {}) is Dictionary else []),
			"tuning_queue_top_contributors": tuning_queue.get("top_contributors", []),
			"launch_difficulty_distribution": summary.get("launch_difficulty_distribution", {}),
			"report_signature": _signature_for({
				"difficulty_id": difficulty_id,
				"summary": summary,
				"queue_signature": String(tuning_queue.get("queue_signature", "")),
			}),
		}
		if int(row.get("sample_count", 0)) < minimum_samples:
			failures.append("%s_sample_count_below_minimum" % difficulty_id)
		if int(row.get("stalled_sample_count", 0)) > 0:
			failures.append("%s_stalled_samples_present" % difficulty_id)
		if int(row.get("invalid_order_count", 0)) > 0:
			failures.append("%s_invalid_orders_present" % difficulty_id)
		if String(gate.get("status", "")) == "fail":
			failures.append("%s_combat_feel_gate_failed" % difficulty_id)
		if String(matrix_gate.get("status", "")) == "fail":
			failures.append("%s_balance_matrix_gate_failed" % difficulty_id)
		for report_warning in report.get("warnings", []):
			warnings.append("%s:%s" % [difficulty_id, String(report_warning)])
		rows.append(row)
		row_by_difficulty[difficulty_id] = row
	var deltas := _difficulty_sweep_deltas(row_by_difficulty)
	if difficulty_ids.size() < 2:
		failures.append("difficulty_sweep_requires_at_least_two_launch_difficulties")
	if not row_by_difficulty.has("normal"):
		failures.append("difficulty_sweep_missing_normal")
	if not row_by_difficulty.has("hard"):
		failures.append("difficulty_sweep_missing_hard")
	if bool(deltas.get("normal_vs_hard", {}).get("no_observed_effect", true)):
		failures.append("difficulty_sweep_no_observed_effect")
	var status := "pass"
	if not failures.is_empty():
		status = "fail"
	elif not warnings.is_empty():
		status = "warning"
	return {
		"schema": DIFFICULTY_SWEEP_SCHEMA,
		"policy": DIFFICULTY_SWEEP_POLICY,
		"status": status,
		"difficulty_ids": difficulty_ids,
		"sample_limit_per_difficulty": sample_limit,
		"minimum_sample_count_per_difficulty": minimum_samples,
		"rows": rows,
		"deltas": deltas,
		"warning_count": warnings.size(),
		"failure_count": failures.size(),
		"warnings": warnings,
		"failures": failures,
		"sweep_signature": _signature_for({
			"schema": DIFFICULTY_SWEEP_SCHEMA,
			"policy": DIFFICULTY_SWEEP_POLICY,
			"rows": rows,
			"deltas": deltas,
		}),
	}

static func _difficulty_sweep_deltas(row_by_difficulty: Dictionary) -> Dictionary:
	var result := {}
	if row_by_difficulty.has("normal") and row_by_difficulty.has("hard"):
		var normal_row: Dictionary = row_by_difficulty.get("normal", {}) if row_by_difficulty.get("normal", {}) is Dictionary else {}
		var hard_row: Dictionary = row_by_difficulty.get("hard", {}) if row_by_difficulty.get("hard", {}) is Dictionary else {}
		var row_delta := {
			"terminal_margin_delta": int(hard_row.get("average_terminal_health_margin_pct", 0)) - int(normal_row.get("average_terminal_health_margin_pct", 0)),
			"total_damage_per_round_delta": int(hard_row.get("average_total_damage_per_round", 0)) - int(normal_row.get("average_total_damage_per_round", 0)),
			"player_remaining_pct_delta": int(hard_row.get("average_player_health_remaining_pct", 0)) - int(normal_row.get("average_player_health_remaining_pct", 0)),
			"enemy_remaining_pct_delta": int(hard_row.get("average_enemy_health_remaining_pct", 0)) - int(normal_row.get("average_enemy_health_remaining_pct", 0)),
			"primary_outcome_changed": String(hard_row.get("primary_outcome_state", "")) != String(normal_row.get("primary_outcome_state", "")),
			"primary_outcome_pct_delta": int(hard_row.get("primary_outcome_pct", 0)) - int(normal_row.get("primary_outcome_pct", 0)),
		}
		row_delta["no_observed_effect"] = (
			int(row_delta.get("terminal_margin_delta", 0)) == 0
			and int(row_delta.get("total_damage_per_round_delta", 0)) == 0
			and int(row_delta.get("player_remaining_pct_delta", 0)) == 0
			and int(row_delta.get("enemy_remaining_pct_delta", 0)) == 0
			and not bool(row_delta.get("primary_outcome_changed", false))
			and int(row_delta.get("primary_outcome_pct_delta", 0)) == 0
		)
		result["normal_vs_hard"] = row_delta
	return result

static func balance_tuning_queue(aggregate: Dictionary, samples: Array, combat_feel_gate: Dictionary = {}) -> Dictionary:
	var items := []
	var coverage := {
		"sample_count": samples.size(),
		"combat_feel_gate_status": String(combat_feel_gate.get("status", "")),
		"combat_feel_warning_count": int(combat_feel_gate.get("warning_count", 0)),
		"combat_feel_failure_count": int(combat_feel_gate.get("failure_count", 0)),
		"balance_matrix_gate_status": "",
		"balance_matrix_warning_count": 0,
		"balance_matrix_failure_count": 0,
		"sample_watch_count": 0,
		"cohort_watch_count": 0,
		"gate_item_count": 0,
	}
	for failure in combat_feel_gate.get("failures", []):
		_append_tuning_item(items, "combat_feel_gate_failure", String(failure), 95, String(failure), 1, 0, "combat_feel_gate", {}, _owner_for_tuning_metric(String(failure)), _hint_for_tuning_metric(String(failure)))
		coverage["gate_item_count"] = int(coverage.get("gate_item_count", 0)) + 1
	for warning in combat_feel_gate.get("warnings", []):
		_append_tuning_item(items, "combat_feel_gate_warning", String(warning), 70, String(warning), 1, 0, "combat_feel_gate", {}, _owner_for_tuning_metric(String(warning)), _hint_for_tuning_metric(String(warning)))
		coverage["gate_item_count"] = int(coverage.get("gate_item_count", 0)) + 1
	var matrix: Dictionary = aggregate.get("balance_matrix", {}) if aggregate.get("balance_matrix", {}) is Dictionary else {}
	var matrix_gate: Dictionary = aggregate.get("balance_matrix_gate", {}) if aggregate.get("balance_matrix_gate", {}) is Dictionary else {}
	coverage["balance_matrix_gate_status"] = String(matrix_gate.get("status", ""))
	coverage["balance_matrix_warning_count"] = int(matrix_gate.get("warning_count", 0))
	coverage["balance_matrix_failure_count"] = int(matrix_gate.get("failure_count", 0))
	for failure in matrix_gate.get("failures", []):
		_append_tuning_item(items, "balance_matrix_gate_failure", String(failure), 95, String(failure), 1, 0, "balance_matrix_gate", {}, _owner_for_tuning_metric(String(failure)), _hint_for_tuning_metric(String(failure)))
		coverage["gate_item_count"] = int(coverage.get("gate_item_count", 0)) + 1
	for warning in matrix_gate.get("warnings", []):
		_append_tuning_item(items, "balance_matrix_gate_warning", String(warning), 65, String(warning), 1, 0, "balance_matrix_gate", {}, _owner_for_tuning_metric(String(warning)), _hint_for_tuning_metric(String(warning)))
		coverage["gate_item_count"] = int(coverage.get("gate_item_count", 0)) + 1
	for sample in samples:
		if not (sample is Dictionary):
			continue
		var sample_ref := _sample_tuning_ref(sample)
		var terminal_margin := int(sample.get("terminal_health_margin_pct", 0))
		if terminal_margin >= TUNING_QUEUE_SAMPLE_MARGIN_WATCH_PCT:
			_append_tuning_item(items, "sample_terminal_margin_watch", String(sample_ref.get("placement_id", "")), 80 if terminal_margin >= BALANCE_MATRIX_TERMINAL_MARGIN_OUTLIER_PCT else 60, "terminal_health_margin_pct", terminal_margin, TUNING_QUEUE_SAMPLE_MARGIN_WATCH_PCT, "sample", sample_ref, "encounter_tuning", "Inspect stack sizes, encounter difficulty label, terrain advantage, and first-contact distance for this sampled battle.")
			coverage["sample_watch_count"] = int(coverage.get("sample_watch_count", 0)) + 1
		var pacing_band := String(sample.get("pacing_band", ""))
		if pacing_band in ["burst", "grind", "stalled"]:
			_append_tuning_item(items, "sample_pacing_band_watch", String(sample_ref.get("placement_id", "")), 75 if pacing_band == "stalled" else 55, "pacing_band", pacing_band, "standard_or_extended", "sample", sample_ref, "encounter_tuning", "Review opening distance, speed, ranged pressure, and stack durability for the sampled battle pacing.")
			coverage["sample_watch_count"] = int(coverage.get("sample_watch_count", 0)) + 1
	var outliers: Array = matrix.get("terminal_margin_outliers", []) if matrix.get("terminal_margin_outliers", []) is Array else []
	for outlier in outliers:
		if not (outlier is Dictionary):
			continue
		_append_tuning_item(items, "matrix_terminal_margin_outlier", String(outlier.get("encounter_placement_id", "")), 85, "terminal_health_margin_pct", int(outlier.get("terminal_health_margin_pct", 0)), BALANCE_MATRIX_TERMINAL_MARGIN_OUTLIER_PCT, "balance_matrix", outlier, "encounter_tuning", "Retune the authored encounter or expected matchup before expanding this content band.")
		coverage["cohort_watch_count"] = int(coverage.get("cohort_watch_count", 0)) + 1
	for section_id in ["difficulty", "terrain", "scenario", "matchup", "ability_presence"]:
		var section: Dictionary = matrix.get(section_id, {}) if matrix.get(section_id, {}) is Dictionary else {}
		var cohort_ids: Array = section.keys()
		cohort_ids.sort()
		for cohort_id_value in cohort_ids:
			var cohort_id := String(cohort_id_value)
			var cohort: Dictionary = section.get(cohort_id, {}) if section.get(cohort_id, {}) is Dictionary else {}
			var sample_count := int(cohort.get("sample_count", 0))
			if sample_count <= 0:
				continue
			var cohort_ref := {"section": section_id, "cohort_id": cohort_id, "sample_count": sample_count}
			var average_margin := int(cohort.get("average_terminal_health_margin_pct", 0))
			if average_margin >= TUNING_QUEUE_COHORT_MARGIN_WATCH_PCT:
				_append_tuning_item(items, "cohort_terminal_margin_watch", "%s:%s" % [section_id, cohort_id], 70, "average_terminal_health_margin_pct", average_margin, TUNING_QUEUE_COHORT_MARGIN_WATCH_PCT, "cohort", cohort_ref, "encounter_tuning", "Compare this cohort against adjacent cohorts and adjust encounter rosters, stack counts, or terrain-specific pressure.")
				coverage["cohort_watch_count"] = int(coverage.get("cohort_watch_count", 0)) + 1
			var primary_outcome_pct := int(cohort.get("primary_outcome_pct", 0))
			if sample_count >= 2 and primary_outcome_pct >= TUNING_QUEUE_COHORT_OUTCOME_WATCH_PCT:
				_append_tuning_item(items, "cohort_outcome_bias_watch", "%s:%s" % [section_id, cohort_id], 65, "primary_outcome_pct", primary_outcome_pct, TUNING_QUEUE_COHORT_OUTCOME_WATCH_PCT, "cohort", cohort_ref, "encounter_tuning", "Check whether this cohort is intentionally one-sided or needs more varied encounter and matchup samples.")
				coverage["cohort_watch_count"] = int(coverage.get("cohort_watch_count", 0)) + 1
	var sorted_items := _sorted_tuning_items(items)
	var categories := {}
	var high_priority_count := 0
	var medium_priority_count := 0
	for item in sorted_items:
		if not (item is Dictionary):
			continue
		categories[String(item.get("category", ""))] = true
		var priority := int(item.get("priority", 0))
		if priority >= TUNING_QUEUE_HIGH_PRIORITY:
			high_priority_count += 1
		elif priority >= TUNING_QUEUE_MEDIUM_PRIORITY:
			medium_priority_count += 1
	var category_ids: Array = categories.keys()
	category_ids.sort()
	coverage["categories"] = category_ids
	var status := "clear"
	if high_priority_count > 0:
		status = "action_required"
	elif not sorted_items.is_empty():
		status = "watch"
	var queue := {
		"schema": TUNING_QUEUE_SCHEMA,
		"policy": TUNING_QUEUE_POLICY,
		"status": status,
		"sample_count": samples.size(),
		"item_count": sorted_items.size(),
		"high_priority_count": high_priority_count,
		"medium_priority_count": medium_priority_count,
		"coverage": coverage,
		"items": sorted_items,
		"top_contributors": sorted_items.slice(0, min(5, sorted_items.size())),
	}
	queue["queue_signature"] = _signature_for({
		"schema": TUNING_QUEUE_SCHEMA,
		"policy": TUNING_QUEUE_POLICY,
		"items": sorted_items,
	})
	return queue

static func run_battle_sample(scenario_id: String, encounter: Dictionary, step_limit: int = DEFAULT_STEP_LIMIT, launch_difficulty: String = "normal") -> Dictionary:
	var session: SessionStateStoreScript.SessionData = ScenarioFactoryScript.create_session(
		scenario_id,
		launch_difficulty,
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
	var encounter_difficulty := String(session.battle.get("encounter_difficulty", "unknown"))
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
		"launch_difficulty": String(session.difficulty),
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
	var launch_difficulty_distribution := {}
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
		var difficulty_id := String(sample.get("encounter_difficulty", "unknown"))
		difficulty_distribution[difficulty_id] = int(difficulty_distribution.get(difficulty_id, 0)) + 1
		var launch_difficulty_id := String(sample.get("launch_difficulty", "unknown"))
		launch_difficulty_distribution[launch_difficulty_id] = int(launch_difficulty_distribution.get(launch_difficulty_id, 0)) + 1
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
	var balance_matrix := _balance_matrix(samples)
	var balance_matrix_gate := _balance_matrix_gate(balance_matrix, samples.size())
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
		"launch_difficulty_distribution": launch_difficulty_distribution,
		"pacing_band_distribution": pacing_band_distribution,
		"initial_role_distribution": initial_role_distribution,
		"initial_ability_distribution": initial_ability_distribution,
		"balance_matrix": balance_matrix,
		"balance_matrix_gate": balance_matrix_gate,
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
	var side_power_scores := {"player": 0, "enemy": 0}
	var side_role_counts := {"player": {}, "enemy": {}}
	var side_ability_counts := {"player": {}, "enemy": {}}
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
		var side_roles: Dictionary = side_role_counts.get(side, {}) if side_role_counts.get(side, {}) is Dictionary else {}
		side_roles[role] = int(side_roles.get(role, 0)) + 1
		side_role_counts[side] = side_roles
		side_power_scores[side] = int(side_power_scores.get(side, 0)) + _stack_power_score(stack)
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
			var side_abilities: Dictionary = side_ability_counts.get(side, {}) if side_ability_counts.get(side, {}) is Dictionary else {}
			side_abilities[ability_id] = int(side_abilities.get(ability_id, 0)) + 1
			side_ability_counts[side] = side_abilities
	if initiative_count <= 0:
		initiative_min = 0
		initiative_max = 0
	var player_power: int = int(side_power_scores.get("player", 0))
	var enemy_power: int = int(side_power_scores.get("enemy", 0))
	var power_ratio_pct := int(round(float(player_power) * 100.0 / float(max(1, enemy_power))))
	return {
		"side_stack_counts": side_stack_counts,
		"side_unit_counts": side_unit_counts,
		"ranged_stack_counts": ranged_stack_counts,
		"side_power_scores": side_power_scores,
		"player_enemy_power_ratio_pct": power_ratio_pct,
		"matchup_band": _matchup_band(player_power, enemy_power),
		"role_counts": role_counts,
		"side_role_counts": side_role_counts,
		"ability_counts": ability_counts,
		"side_ability_counts": side_ability_counts,
		"ability_instance_count": _count_map_total(ability_counts),
		"initiative": {
			"min": initiative_min,
			"max": initiative_max,
			"spread": initiative_max - initiative_min,
			"average": int(round(float(initiative_total) / float(max(1, initiative_count)))),
		},
	}

static func _stack_power_score(stack: Dictionary) -> int:
	var count: int = max(0, int(stack.get("base_count", 0)))
	var average_damage: int = int(round(float(int(stack.get("min_damage", 1)) + int(stack.get("max_damage", 1))) / 2.0))
	var abilities: Array = stack.get("abilities", []) if stack.get("abilities", []) is Array else []
	var unit_score: int = (
		max(1, int(stack.get("unit_hp", 1)))
		+ max(0, int(stack.get("attack", 0))) * 4
		+ max(0, int(stack.get("defense", 0))) * 3
		+ max(1, average_damage) * 6
		+ max(0, int(stack.get("initiative", 0))) * 2
		+ max(0, int(stack.get("speed", 0))) * 2
		+ (8 if bool(stack.get("ranged", false)) else 0)
		+ abilities.size() * 5
	)
	return count * max(1, unit_score)

static func _matchup_band(player_power: int, enemy_power: int) -> String:
	var ratio_pct := int(round(float(max(0, player_power)) * 100.0 / float(max(1, enemy_power))))
	if ratio_pct <= 75:
		return "player_disadvantaged"
	if ratio_pct >= 125:
		return "player_advantaged"
	return "even"

static func _balance_matrix(samples: Array) -> Dictionary:
	var matrix := {
		"policy": "report_only_balance_matrix_v1",
		"schema": "battle_autoplay_balance_matrix_v1",
		"sample_count": samples.size(),
		"difficulty": {},
		"terrain": {},
		"scenario": {},
		"matchup": {},
		"ability_presence": {},
		"terminal_margin_outliers": [],
	}
	for sample in samples:
		if not (sample is Dictionary):
			continue
		var entry: Dictionary = sample
		_update_balance_cohort(matrix["difficulty"], String(entry.get("encounter_difficulty", "unknown")), entry)
		_update_balance_cohort(matrix["terrain"], String(entry.get("terrain", "unknown")), entry)
		_update_balance_cohort(matrix["scenario"], String(entry.get("scenario_id", "unknown")), entry)
		var profile: Dictionary = entry.get("initial_stack_profile", {}) if entry.get("initial_stack_profile", {}) is Dictionary else {}
		_update_balance_cohort(matrix["matchup"], String(profile.get("matchup_band", "unknown")), entry)
		var ability_counts: Dictionary = profile.get("ability_counts", {}) if profile.get("ability_counts", {}) is Dictionary else {}
		for ability_id in ability_counts.keys():
			_update_balance_cohort(matrix["ability_presence"], String(ability_id), entry)
		if int(entry.get("terminal_health_margin_pct", 0)) >= BALANCE_MATRIX_TERMINAL_MARGIN_OUTLIER_PCT:
			matrix["terminal_margin_outliers"].append({
				"scenario_id": String(entry.get("scenario_id", "")),
				"encounter_placement_id": String(entry.get("encounter_placement_id", "")),
				"encounter_id": String(entry.get("encounter_id", "")),
				"outcome_state": String(entry.get("outcome_state", "")),
				"terminal_health_margin_pct": int(entry.get("terminal_health_margin_pct", 0)),
				"matchup_band": String(profile.get("matchup_band", "unknown")),
				"terrain": String(entry.get("terrain", "unknown")),
				"encounter_difficulty": String(entry.get("encounter_difficulty", "unknown")),
			})
	for section_key in ["difficulty", "terrain", "scenario", "matchup", "ability_presence"]:
		var section: Dictionary = matrix.get(section_key, {}) if matrix.get(section_key, {}) is Dictionary else {}
		for cohort_id in section.keys():
			section[cohort_id] = _finalize_balance_cohort(section[cohort_id])
	return matrix

static func _update_balance_cohort(section: Dictionary, cohort_id: String, sample: Dictionary) -> void:
	var normalized_id := cohort_id if cohort_id != "" else "unknown"
	var cohort: Dictionary = section.get(normalized_id, {}) if section.get(normalized_id, {}) is Dictionary else {}
	if cohort.is_empty():
		cohort = {
			"sample_count": 0,
			"completed_sample_count": 0,
			"outcome_distribution": {},
			"pacing_band_distribution": {},
			"action_distribution": {},
			"terminal_margin_total": 0,
			"round_total": 0,
			"damage_per_round_total": 0,
		}
	cohort["sample_count"] = int(cohort.get("sample_count", 0)) + 1
	if bool(sample.get("completed", false)):
		cohort["completed_sample_count"] = int(cohort.get("completed_sample_count", 0)) + 1
	var outcomes: Dictionary = cohort.get("outcome_distribution", {}) if cohort.get("outcome_distribution", {}) is Dictionary else {}
	var outcome_id := String(sample.get("outcome_state", "unknown"))
	outcomes[outcome_id] = int(outcomes.get(outcome_id, 0)) + 1
	cohort["outcome_distribution"] = outcomes
	var pacing: Dictionary = cohort.get("pacing_band_distribution", {}) if cohort.get("pacing_band_distribution", {}) is Dictionary else {}
	var pacing_id := String(sample.get("pacing_band", "unknown"))
	pacing[pacing_id] = int(pacing.get(pacing_id, 0)) + 1
	cohort["pacing_band_distribution"] = pacing
	var action_distribution: Dictionary = cohort.get("action_distribution", {}) if cohort.get("action_distribution", {}) is Dictionary else {}
	var action_counts: Dictionary = sample.get("action_counts", {}) if sample.get("action_counts", {}) is Dictionary else {}
	for action_id in action_counts.keys():
		action_distribution[String(action_id)] = int(action_distribution.get(String(action_id), 0)) + int(action_counts[action_id])
	cohort["action_distribution"] = action_distribution
	cohort["terminal_margin_total"] = int(cohort.get("terminal_margin_total", 0)) + int(sample.get("terminal_health_margin_pct", 0))
	cohort["round_total"] = int(cohort.get("round_total", 0)) + int(sample.get("round_reached", 0))
	var damage_per_round: Dictionary = sample.get("damage_per_round", {}) if sample.get("damage_per_round", {}) is Dictionary else {}
	cohort["damage_per_round_total"] = int(cohort.get("damage_per_round_total", 0)) + int(damage_per_round.get("total", 0))
	section[normalized_id] = cohort

static func _finalize_balance_cohort(cohort: Dictionary) -> Dictionary:
	var sample_count: int = max(1, int(cohort.get("sample_count", 0)))
	var primary_outcome := _primary_count_entry(cohort.get("outcome_distribution", {}), "outcome")
	var primary_pacing := _primary_count_entry(cohort.get("pacing_band_distribution", {}), "pacing_band")
	var primary_action := _primary_action(cohort.get("action_distribution", {}))
	return {
		"sample_count": int(cohort.get("sample_count", 0)),
		"completed_sample_count": int(cohort.get("completed_sample_count", 0)),
		"outcome_distribution": cohort.get("outcome_distribution", {}),
		"primary_outcome_state": String(primary_outcome.get("outcome", "")),
		"primary_outcome_pct": int(primary_outcome.get("pct", 0)),
		"pacing_band_distribution": cohort.get("pacing_band_distribution", {}),
		"primary_pacing_band": String(primary_pacing.get("pacing_band", "")),
		"primary_pacing_band_pct": int(primary_pacing.get("pct", 0)),
		"action_distribution": cohort.get("action_distribution", {}),
		"primary_action_id": String(primary_action.get("action", "")),
		"primary_action_pct": int(primary_action.get("pct", 0)),
		"average_terminal_health_margin_pct": int(round(float(int(cohort.get("terminal_margin_total", 0))) / float(sample_count))),
		"average_round_reached": int(round(float(int(cohort.get("round_total", 0))) / float(sample_count))),
		"average_total_damage_per_round": int(round(float(int(cohort.get("damage_per_round_total", 0))) / float(sample_count))),
	}

static func _balance_matrix_gate(matrix: Dictionary, sample_count: int) -> Dictionary:
	var warnings := []
	var failures := []
	var difficulty: Dictionary = matrix.get("difficulty", {}) if matrix.get("difficulty", {}) is Dictionary else {}
	var terrain: Dictionary = matrix.get("terrain", {}) if matrix.get("terrain", {}) is Dictionary else {}
	var matchup: Dictionary = matrix.get("matchup", {}) if matrix.get("matchup", {}) is Dictionary else {}
	var ability_presence: Dictionary = matrix.get("ability_presence", {}) if matrix.get("ability_presence", {}) is Dictionary else {}
	var outliers: Array = matrix.get("terminal_margin_outliers", []) if matrix.get("terminal_margin_outliers", []) is Array else []
	if sample_count <= 0:
		failures.append("no_balance_matrix_samples")
	if difficulty.keys().size() < BALANCE_MATRIX_MIN_DIFFICULTY_COHORTS:
		warnings.append("difficulty_cohort_coverage_below_target")
	for required_difficulty in ["low", "medium", "high"]:
		if not difficulty.has(required_difficulty):
			warnings.append("missing_%s_difficulty_cohort" % required_difficulty)
	if terrain.keys().size() < BALANCE_MATRIX_MIN_TERRAIN_COHORTS:
		warnings.append("terrain_cohort_coverage_below_target")
	if matchup.keys().size() <= 0:
		failures.append("missing_matchup_cohort")
	if ability_presence.keys().size() < BALANCE_MATRIX_MIN_ABILITY_COHORTS:
		warnings.append("ability_presence_cohort_coverage_below_target")
	if not outliers.is_empty():
		warnings.append("terminal_margin_outliers_present")
	var status := "pass"
	if not failures.is_empty():
		status = "fail"
	elif not warnings.is_empty():
		status = "warning"
	return {
		"status": status,
		"policy": "report_only_balance_matrix_thresholds_v1",
		"sample_count": sample_count,
		"difficulty_cohort_count": difficulty.keys().size(),
		"terrain_cohort_count": terrain.keys().size(),
		"scenario_cohort_count": (matrix.get("scenario", {}) if matrix.get("scenario", {}) is Dictionary else {}).keys().size(),
		"matchup_cohort_count": matchup.keys().size(),
		"ability_presence_cohort_count": ability_presence.keys().size(),
		"terminal_margin_outlier_count": outliers.size(),
		"thresholds": {
			"min_difficulty_cohorts": BALANCE_MATRIX_MIN_DIFFICULTY_COHORTS,
			"min_terrain_cohorts": BALANCE_MATRIX_MIN_TERRAIN_COHORTS,
			"min_ability_presence_cohorts": BALANCE_MATRIX_MIN_ABILITY_COHORTS,
			"terminal_margin_outlier_pct": BALANCE_MATRIX_TERMINAL_MARGIN_OUTLIER_PCT,
		},
		"warning_count": warnings.size(),
		"failure_count": failures.size(),
		"warnings": warnings,
		"failures": failures,
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

static func _append_tuning_item(
	items: Array,
	category: String,
	ref_id: String,
	priority: int,
	metric: String,
	observed: Variant,
	target: Variant,
	source: String,
	context: Dictionary,
	suggested_owner: String,
	remediation_hint: String
) -> void:
	var item := {
		"category": category,
		"priority": priority,
		"priority_band": _tuning_priority_band(priority),
		"metric": metric,
		"observed": observed,
		"target": target,
		"source": source,
		"context": context,
		"suggested_owner": suggested_owner,
		"remediation_hint": remediation_hint,
	}
	item["id"] = "tuning_%s" % _hash32_hex(_stable_stringify({
		"category": category,
		"metric": metric,
		"ref_id": ref_id,
		"source": source,
	}))
	items.append(item)

static func _sample_tuning_ref(sample: Dictionary) -> Dictionary:
	return {
		"scenario_id": String(sample.get("scenario_id", "")),
		"placement_id": String(sample.get("encounter_placement_id", "")),
		"encounter_id": String(sample.get("encounter_id", "")),
		"outcome_state": String(sample.get("outcome_state", "")),
		"terrain": String(sample.get("terrain", "")),
		"encounter_difficulty": String(sample.get("encounter_difficulty", "")),
		"pacing_band": String(sample.get("pacing_band", "")),
	}

static func _tuning_priority_band(priority: int) -> String:
	if priority >= TUNING_QUEUE_HIGH_PRIORITY:
		return "high"
	if priority >= TUNING_QUEUE_MEDIUM_PRIORITY:
		return "medium"
	return "low"

static func _owner_for_tuning_metric(metric: String) -> String:
	if metric.contains("sample_count") or metric.contains("cohort") or metric.contains("missing_"):
		return "content_coverage"
	if metric.contains("invalid") or metric.contains("action"):
		return "battle_ai"
	if metric.contains("damage") or metric.contains("terminal") or metric.contains("outcome") or metric.contains("pacing"):
		return "encounter_tuning"
	return "balance_harness"

static func _hint_for_tuning_metric(metric: String) -> String:
	if metric.contains("sample_count") or metric.contains("cohort") or metric.contains("missing_"):
		return "Add or select more authored encounter samples before treating this balance band as stable."
	if metric.contains("invalid"):
		return "Inspect action availability, target selection, and fallback order generation for the sampled battle state."
	if metric.contains("action"):
		return "Review tactical scoring weights and available order incentives for excessive action repetition."
	if metric.contains("damage") or metric.contains("terminal"):
		return "Compare initial power ratio, stack durability, and damage pacing before retuning encounter rosters."
	if metric.contains("outcome"):
		return "Inspect whether the current win/loss skew is intended for this difficulty or cohort."
	if metric.contains("pacing"):
		return "Check opening distance, initiative, movement speed, ranged pressure, and stack sizes for pacing extremes."
	return "Inspect the linked report metric before making content or rules changes."

static func _sorted_tuning_items(items: Array) -> Array:
	var remaining := items.duplicate(true)
	var sorted := []
	while not remaining.is_empty():
		var best_index := 0
		for index in range(1, remaining.size()):
			if _tuning_item_before(remaining[index], remaining[best_index]):
				best_index = index
		sorted.append(remaining[best_index])
		remaining.remove_at(best_index)
	return sorted

static func _tuning_item_before(a: Variant, b: Variant) -> bool:
	if not (a is Dictionary) or not (b is Dictionary):
		return false
	var left: Dictionary = a
	var right: Dictionary = b
	var left_priority := int(left.get("priority", 0))
	var right_priority := int(right.get("priority", 0))
	if left_priority != right_priority:
		return left_priority > right_priority
	var left_category := String(left.get("category", ""))
	var right_category := String(right.get("category", ""))
	if left_category != right_category:
		return left_category < right_category
	return String(left.get("id", "")) < String(right.get("id", ""))

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

static func _array_of_strings(value: Variant) -> Array:
	var result := []
	if not (value is Array):
		return result
	for item in value:
		result.append(String(item))
	result.sort()
	return result

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
