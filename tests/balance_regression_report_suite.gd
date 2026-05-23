extends Node

const BalanceRegressionReportRulesScript = preload("res://scripts/core/BalanceRegressionReportRules.gd")
const REPORT_ID := "BALANCE_REGRESSION_REPORT_SUITE"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var first: Dictionary = BalanceRegressionReportRulesScript.build_report()
	if not _assert_report(first):
		return
	print("%s %s" % [REPORT_ID, JSON.stringify(BalanceRegressionReportRulesScript.compact_summary(first))])
	get_tree().quit(0)

func _assert_report(first: Dictionary) -> bool:
	if not bool(first.get("ok", false)):
		_fail("Balance regression report did not produce an acceptable report: %s" % JSON.stringify(first))
		return false
	if String(first.get("schema_id", "")) != BalanceRegressionReportRulesScript.REPORT_SCHEMA_ID:
		_fail("Balance regression report schema mismatch: %s" % JSON.stringify(first))
		return false
	if String(first.get("suite_signature", "")) == "" or not bool(first.get("self_signature_check", false)):
		_fail("Balance regression suite signature is missing or not reproducible from section signatures.")
		return false
	var required_sections: Array = BalanceRegressionReportRulesScript.REQUIRED_SECTION_IDS
	var section_signatures: Dictionary = first.get("section_signatures", {})
	for section_id in required_sections:
		if not section_signatures.has(String(section_id)) or String(section_signatures.get(String(section_id), "")) == "":
			_fail("Balance regression report missing required section signature: %s" % section_id)
			return false
	var statuses := {}
	for section in first.get("sections", []):
		if not (section is Dictionary):
			_fail("Balance regression report section was not a dictionary.")
			return false
		var status := String(section.get("status", ""))
		statuses[status] = int(statuses.get(status, 0)) + 1
		if status not in ["pass", "warning", "deferred"]:
			_fail("Balance regression report section returned unsupported status: %s / %s" % [section.get("section_id", ""), status])
			return false
	var battle_section := _find_section(first, "battle_outcome_distribution")
	if battle_section.is_empty():
		_fail("Balance regression report is missing battle outcome distribution evidence.")
		return false
	var battle_summary: Dictionary = battle_section.get("summary", {})
	var battle_evidence: Dictionary = battle_section.get("evidence", {})
	var action_distribution: Dictionary = battle_summary.get("action_distribution", {}) if battle_summary.get("action_distribution", {}) is Dictionary else {}
	var battle_samples: Array = battle_evidence.get("samples", []) if battle_evidence.get("samples", []) is Array else []
	if int(battle_summary.get("sample_count", 0)) <= 0 or battle_samples.is_empty():
		_fail("Battle outcome distribution did not emit autoplay samples.")
		return false
	if int(battle_summary.get("sample_count", 0)) < int(battle_summary.get("requested_sample_limit", 0)):
		_fail("Battle outcome distribution did not reach the requested default sample breadth: %s" % battle_summary)
		return false
	if int(battle_summary.get("step_limit", 0)) <= 0 or int(battle_summary.get("average_round_reached", 0)) <= 0:
		_fail("Battle outcome distribution is missing pacing metrics.")
		return false
	if action_distribution.is_empty():
		_fail("Battle outcome distribution is missing action metrics.")
		return false
	var scenario_distribution: Dictionary = battle_summary.get("scenario_distribution", {}) if battle_summary.get("scenario_distribution", {}) is Dictionary else {}
	if scenario_distribution.keys().size() <= 1:
		_fail("Battle outcome distribution did not sample multiple authored scenarios: %s" % battle_summary)
		return false
	var difficulty_distribution: Dictionary = battle_summary.get("difficulty_distribution", {}) if battle_summary.get("difficulty_distribution", {}) is Dictionary else {}
	for required_difficulty in ["low", "medium", "high"]:
		if not difficulty_distribution.has(required_difficulty):
			_fail("Battle outcome distribution did not preserve authored difficulty labels: %s" % battle_summary)
			return false
	for required_summary_field in [
		"average_player_damage_dealt",
		"average_enemy_damage_dealt",
		"average_total_damage_per_round",
		"average_terminal_health_margin_pct",
		"average_initial_initiative_spread",
		"action_diversity_count",
		"primary_action_id",
		"primary_action_pct",
		"primary_outcome_state",
		"primary_outcome_pct",
		"primary_pacing_band",
		"primary_pacing_band_pct",
		"terrain_distribution",
		"scenario_distribution",
		"difficulty_distribution",
		"pacing_band_distribution",
		"initial_role_distribution",
		"initial_ability_distribution",
		"balance_matrix",
		"balance_matrix_gate",
		"combat_feel_gate",
	]:
		if not battle_summary.has(String(required_summary_field)):
			_fail("Battle outcome distribution summary is missing combat-feel diagnostic field: %s" % required_summary_field)
			return false
	if not _assert_combat_feel_gate(battle_summary):
		return false
	if not _assert_balance_matrix_gate(battle_summary):
		return false
	if int(battle_summary.get("action_diversity_count", 0)) <= 0 or String(battle_summary.get("primary_action_id", "")) == "":
		_fail("Battle outcome distribution did not expose a usable action-mix diagnostic: %s" % battle_summary)
		return false
	if int(battle_summary.get("average_total_damage_per_round", 0)) <= 0:
		_fail("Battle outcome distribution did not expose positive damage pacing evidence: %s" % battle_summary)
		return false
	var first_battle_sample: Dictionary = battle_samples[0]
	for required_field in ["terrain", "encounter_difficulty", "initial_health", "final_health", "player_health_remaining_pct", "enemy_health_remaining_pct", "terminal_health_margin_pct", "action_counts", "action_mix", "damage_totals", "damage_per_round", "pacing_band", "initial_stack_profile"]:
		if not first_battle_sample.has(String(required_field)):
			_fail("Battle outcome distribution sample is missing field: %s" % required_field)
			return false
	var turn_log: Array = first_battle_sample.get("turn_log", []) if first_battle_sample.get("turn_log", []) is Array else []
	if turn_log.is_empty() or not (turn_log[0] is Dictionary) or not (turn_log[0].get("autoplay_decision", {}) is Dictionary):
		_fail("Battle outcome distribution sample is missing scored autoplay decision evidence: %s" % first_battle_sample)
		return false
	var autoplay_decision: Dictionary = turn_log[0].get("autoplay_decision", {})
	if String(autoplay_decision.get("scoring_policy", "")) != "battle_ai_nonspell_tactical_order_v1":
		_fail("Battle outcome distribution did not use the shared tactical autoplay scoring policy: %s" % autoplay_decision)
		return false
	var initial_stack_profile: Dictionary = first_battle_sample.get("initial_stack_profile", {}) if first_battle_sample.get("initial_stack_profile", {}) is Dictionary else {}
	if not initial_stack_profile.has("initiative") or not initial_stack_profile.has("role_counts") or not initial_stack_profile.has("ability_counts") or not initial_stack_profile.has("side_power_scores") or not initial_stack_profile.has("matchup_band") or not initial_stack_profile.has("side_role_counts") or not initial_stack_profile.has("side_ability_counts"):
		_fail("Battle outcome distribution sample is missing stack role/ability/initiative diagnostics: %s" % first_battle_sample)
		return false
	if int(statuses.get("pass", 0)) <= 0:
		_fail("Balance regression report did not pass any mature surface.")
		return false
	if int(statuses.get("warning", 0)) <= 0 and int(statuses.get("deferred", 0)) <= 0:
		_fail("Balance regression report should expose immature foundation surfaces as warning/deferred evidence.")
		return false
	var policy: Dictionary = first.get("reporting_policy", {})
	if bool(policy.get("automatic_tuning", true)) or bool(policy.get("runtime_balance_changes", true)) or bool(policy.get("authored_content_writeback", true)) or bool(policy.get("alpha_or_parity_claim", true)):
		_fail("Balance regression report violated report-only boundaries: %s" % JSON.stringify(policy))
		return false
	var serialized := JSON.stringify(BalanceRegressionReportRulesScript.compact_summary(first)).to_lower()
	for forbidden in ["automatic_tuning\":true", "alpha_or_parity_claim\":true", "parity_complete", "alpha_complete", "production_ready"]:
		if serialized.find(forbidden) >= 0:
			_fail("Balance regression compact report contains forbidden claim token: %s" % forbidden)
			return false
	return true

func _assert_combat_feel_gate(battle_summary: Dictionary) -> bool:
	var gate: Dictionary = battle_summary.get("combat_feel_gate", {}) if battle_summary.get("combat_feel_gate", {}) is Dictionary else {}
	if gate.is_empty():
		_fail("Battle outcome distribution is missing combat-feel threshold gate evidence.")
		return false
	if String(gate.get("policy", "")) != "report_only_combat_feel_thresholds_v1":
		_fail("Battle outcome distribution combat-feel gate policy mismatch: %s" % gate)
		return false
	if String(gate.get("status", "")) not in ["pass", "warning", "fail"]:
		_fail("Battle outcome distribution combat-feel gate status is unsupported: %s" % gate)
		return false
	var thresholds: Dictionary = gate.get("thresholds", {}) if gate.get("thresholds", {}) is Dictionary else {}
	if thresholds.is_empty() or not thresholds.has("max_terminal_health_margin_pct") or not thresholds.has("min_total_damage_per_round"):
		_fail("Battle outcome distribution combat-feel gate is missing threshold metadata: %s" % gate)
		return false
	for required_gate_field in [
		"warning_count",
		"failure_count",
		"warnings",
		"failures",
		"primary_outcome_pct",
		"primary_pacing_band_pct",
	]:
		if not gate.has(String(required_gate_field)):
			_fail("Battle outcome distribution combat-feel gate is missing field: %s" % required_gate_field)
			return false
	var warnings: Array = gate.get("warnings", []) if gate.get("warnings", []) is Array else []
	var failures: Array = gate.get("failures", []) if gate.get("failures", []) is Array else []
	if warnings.size() != int(gate.get("warning_count", -1)) or failures.size() != int(gate.get("failure_count", -1)):
		_fail("Battle outcome distribution combat-feel gate counts do not match warning/failure arrays: %s" % gate)
		return false
	if int(gate.get("sample_count", -1)) != int(battle_summary.get("sample_count", -2)):
		_fail("Battle outcome distribution combat-feel gate sample count does not align with summary: %s" % gate)
		return false
	if int(gate.get("average_terminal_health_margin_pct", -1)) != int(battle_summary.get("average_terminal_health_margin_pct", -2)):
		_fail("Battle outcome distribution combat-feel gate terminal margin does not align with summary: %s" % gate)
		return false
	return true

func _assert_balance_matrix_gate(battle_summary: Dictionary) -> bool:
	var matrix: Dictionary = battle_summary.get("balance_matrix", {}) if battle_summary.get("balance_matrix", {}) is Dictionary else {}
	var gate: Dictionary = battle_summary.get("balance_matrix_gate", {}) if battle_summary.get("balance_matrix_gate", {}) is Dictionary else {}
	if String(matrix.get("schema", "")) != "battle_autoplay_balance_matrix_v1":
		_fail("Battle outcome distribution balance matrix schema mismatch: %s" % matrix)
		return false
	if String(matrix.get("policy", "")) != "report_only_balance_matrix_v1":
		_fail("Battle outcome distribution balance matrix policy mismatch: %s" % matrix)
		return false
	if String(gate.get("policy", "")) != "report_only_balance_matrix_thresholds_v1":
		_fail("Battle outcome distribution balance matrix gate policy mismatch: %s" % gate)
		return false
	if String(gate.get("status", "")) not in ["pass", "warning", "fail"]:
		_fail("Battle outcome distribution balance matrix gate status is unsupported: %s" % gate)
		return false
	if String(gate.get("status", "")) == "fail":
		_fail("Battle outcome distribution balance matrix gate failed: %s" % gate)
		return false
	for section_id in ["difficulty", "terrain", "scenario", "matchup", "ability_presence"]:
		var section: Dictionary = matrix.get(section_id, {}) if matrix.get(section_id, {}) is Dictionary else {}
		if section.is_empty():
			_fail("Battle outcome distribution balance matrix missing section: %s" % section_id)
			return false
	var difficulty: Dictionary = matrix.get("difficulty", {}) if matrix.get("difficulty", {}) is Dictionary else {}
	for required_difficulty in ["low", "medium", "high"]:
		if not difficulty.has(required_difficulty):
			_fail("Battle outcome distribution balance matrix missing difficulty cohort: %s" % required_difficulty)
			return false
	if int(gate.get("sample_count", -1)) != int(battle_summary.get("sample_count", -2)):
		_fail("Battle outcome distribution balance matrix gate sample count does not align with summary: %s" % gate)
		return false
	var outliers: Array = matrix.get("terminal_margin_outliers", []) if matrix.get("terminal_margin_outliers", []) is Array else []
	if outliers.size() != int(gate.get("terminal_margin_outlier_count", -1)):
		_fail("Battle outcome distribution balance matrix outlier count does not match gate: %s" % gate)
		return false
	return true

func _find_section(report: Dictionary, section_id: String) -> Dictionary:
	for section in report.get("sections", []):
		if section is Dictionary and String(section.get("section_id", "")) == section_id:
			return section
	return {}

func _fail(message: String) -> void:
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)
