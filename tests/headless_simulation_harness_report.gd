extends Node

const HeadlessSimulationHarnessRulesScript = preload("res://scripts/core/HeadlessSimulationHarnessRules.gd")
const REPORT_ID := "HEADLESS_SIMULATION_HARNESS_REPORT"
const FORBIDDEN_CLAIM_TOKENS := [
	"manual_play_replacement\":true",
	"alpha_or_parity_claim\":true",
	"parity_complete",
	"alpha_complete",
	"production_ready",
]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var first: Dictionary = HeadlessSimulationHarnessRulesScript.build_report()
	if not _assert_report(first):
		return
	print("%s %s" % [REPORT_ID, JSON.stringify(HeadlessSimulationHarnessRulesScript.compact_summary(first))])
	get_tree().quit(0)

func _assert_report(first: Dictionary) -> bool:
	if not bool(first.get("ok", false)):
		_fail("Headless simulation harness did not produce an acceptable report: %s" % JSON.stringify(first))
		return false
	if String(first.get("schema_id", "")) != HeadlessSimulationHarnessRulesScript.REPORT_SCHEMA_ID:
		_fail("Headless simulation harness schema mismatch: %s" % JSON.stringify(first))
		return false
	if String(first.get("harness_signature", "")) == "" or not bool(first.get("self_signature_check", false)):
		_fail("Headless simulation harness signature is missing or not reproducible.")
		return false
	var required_subsystems: Array = HeadlessSimulationHarnessRulesScript.REQUIRED_SUBSYSTEM_IDS
	var case_signatures: Dictionary = first.get("case_signatures", {})
	for subsystem_id in required_subsystems:
		if not case_signatures.has(String(subsystem_id)) or String(case_signatures.get(String(subsystem_id), "")) == "":
			_fail("Headless simulation harness missed subsystem signature: %s" % subsystem_id)
			return false
	var statuses := {}
	for simulation_case in first.get("cases", []):
		if not (simulation_case is Dictionary):
			_fail("Headless simulation harness case was not a dictionary.")
			return false
		var status := String(simulation_case.get("status", ""))
		statuses[status] = int(statuses.get(status, 0)) + 1
		if status not in ["pass", "warning", "deferred"]:
			_fail("Headless simulation harness returned unsupported case status: %s / %s" % [simulation_case.get("subsystem_id", ""), status])
			return false
	var battle_case := _find_case(first, "battle_resolver_sampling")
	if battle_case.is_empty():
		_fail("Headless simulation harness is missing battle resolver sampling evidence.")
		return false
	var battle_summary: Dictionary = battle_case.get("summary", {})
	var battle_evidence: Dictionary = battle_case.get("evidence", {})
	if int(battle_summary.get("sample_count", 0)) <= 0:
		_fail("Battle resolver sampling did not emit any autoplay samples.")
		return false
	if int(battle_summary.get("sample_count", 0)) < int(battle_summary.get("requested_sample_limit", 0)):
		_fail("Battle resolver sampling did not reach the requested default sample breadth: %s" % battle_summary)
		return false
	if int(battle_summary.get("step_limit", 0)) <= 0 or int(battle_summary.get("average_steps_sampled", 0)) <= 0:
		_fail("Battle resolver sampling is missing autoplay pacing metrics.")
		return false
	var action_distribution: Dictionary = battle_summary.get("action_distribution", {}) if battle_summary.get("action_distribution", {}) is Dictionary else {}
	if action_distribution.is_empty():
		_fail("Battle resolver sampling is missing action distribution metrics.")
		return false
	var scenario_distribution: Dictionary = battle_summary.get("scenario_distribution", {}) if battle_summary.get("scenario_distribution", {}) is Dictionary else {}
	if scenario_distribution.keys().size() <= 1:
		_fail("Battle resolver sampling did not sample multiple authored scenarios: %s" % battle_summary)
		return false
	var difficulty_distribution: Dictionary = battle_summary.get("difficulty_distribution", {}) if battle_summary.get("difficulty_distribution", {}) is Dictionary else {}
	for required_difficulty in ["low", "medium", "high"]:
		if not difficulty_distribution.has(required_difficulty):
			_fail("Battle resolver sampling did not preserve authored difficulty labels: %s" % battle_summary)
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
		"combat_feel_gate",
	]:
		if not battle_summary.has(String(required_summary_field)):
			_fail("Battle resolver sampling is missing combat-feel diagnostic field: %s" % required_summary_field)
			return false
	if not _assert_combat_feel_gate(battle_summary):
		return false
	if int(battle_summary.get("average_total_damage_per_round", 0)) <= 0:
		_fail("Battle resolver sampling did not expose positive damage pacing evidence.")
		return false
	var battle_samples: Array = battle_evidence.get("samples", []) if battle_evidence.get("samples", []) is Array else []
	if battle_samples.is_empty():
		_fail("Battle resolver sampling is missing per-sample evidence.")
		return false
	var first_battle_sample: Dictionary = battle_samples[0]
	for required_field in ["terrain", "encounter_difficulty", "steps_sampled", "round_reached", "initial_health", "final_health", "player_health_remaining_pct", "enemy_health_remaining_pct", "terminal_health_margin_pct", "action_counts", "action_mix", "damage_totals", "damage_per_round", "pacing_band", "initial_stack_profile"]:
		if not first_battle_sample.has(String(required_field)):
			_fail("Battle resolver sample is missing field: %s" % required_field)
			return false
	var initial_stack_profile: Dictionary = first_battle_sample.get("initial_stack_profile", {}) if first_battle_sample.get("initial_stack_profile", {}) is Dictionary else {}
	if not initial_stack_profile.has("initiative") or not initial_stack_profile.has("role_counts") or not initial_stack_profile.has("ability_counts"):
		_fail("Battle resolver sample is missing stack role/ability/initiative diagnostics.")
		return false
	if int(statuses.get("pass", 0)) <= 0:
		_fail("Headless simulation harness did not pass any mature subsystem.")
		return false
	if int(statuses.get("warning", 0)) <= 0 and int(statuses.get("deferred", 0)) <= 0:
		_fail("Headless simulation harness should expose immature surfaces as warning/deferred evidence.")
		return false
	var policy: Dictionary = first.get("reporting_policy", {})
	if bool(policy.get("manual_play_replacement", true)) or bool(policy.get("automatic_tuning", true)) or bool(policy.get("runtime_balance_changes", true)) or bool(policy.get("authored_content_writeback", true)) or bool(policy.get("generated_campaign_adoption", true)) or bool(policy.get("alpha_or_parity_claim", true)):
		_fail("Headless simulation harness violated report-only boundaries: %s" % JSON.stringify(policy))
		return false
	var serialized := JSON.stringify(HeadlessSimulationHarnessRulesScript.compact_summary(first)).to_lower()
	for token in FORBIDDEN_CLAIM_TOKENS:
		if serialized.find(token) >= 0:
			_fail("Headless simulation compact report contains forbidden claim token: %s" % token)
			return false
	return true

func _assert_combat_feel_gate(battle_summary: Dictionary) -> bool:
	var gate: Dictionary = battle_summary.get("combat_feel_gate", {}) if battle_summary.get("combat_feel_gate", {}) is Dictionary else {}
	if gate.is_empty():
		_fail("Battle resolver sampling is missing combat-feel threshold gate evidence.")
		return false
	if String(gate.get("policy", "")) != "report_only_combat_feel_thresholds_v1":
		_fail("Battle resolver sampling combat-feel gate policy mismatch: %s" % gate)
		return false
	if String(gate.get("status", "")) not in ["pass", "warning", "fail"]:
		_fail("Battle resolver sampling combat-feel gate status is unsupported: %s" % gate)
		return false
	var thresholds: Dictionary = gate.get("thresholds", {}) if gate.get("thresholds", {}) is Dictionary else {}
	if thresholds.is_empty() or not thresholds.has("max_terminal_health_margin_pct") or not thresholds.has("min_total_damage_per_round"):
		_fail("Battle resolver sampling combat-feel gate is missing threshold metadata: %s" % gate)
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
			_fail("Battle resolver sampling combat-feel gate is missing field: %s" % required_gate_field)
			return false
	var warnings: Array = gate.get("warnings", []) if gate.get("warnings", []) is Array else []
	var failures: Array = gate.get("failures", []) if gate.get("failures", []) is Array else []
	if warnings.size() != int(gate.get("warning_count", -1)) or failures.size() != int(gate.get("failure_count", -1)):
		_fail("Battle resolver sampling combat-feel gate counts do not match warning/failure arrays: %s" % gate)
		return false
	if int(gate.get("sample_count", -1)) != int(battle_summary.get("sample_count", -2)):
		_fail("Battle resolver sampling combat-feel gate sample count does not align with summary: %s" % gate)
		return false
	if int(gate.get("average_terminal_health_margin_pct", -1)) != int(battle_summary.get("average_terminal_health_margin_pct", -2)):
		_fail("Battle resolver sampling combat-feel gate terminal margin does not align with summary: %s" % gate)
		return false
	return true

func _find_case(report: Dictionary, subsystem_id: String) -> Dictionary:
	for simulation_case in report.get("cases", []):
		if simulation_case is Dictionary and String(simulation_case.get("subsystem_id", "")) == subsystem_id:
			return simulation_case
	return {}

func _fail(message: String) -> void:
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)
