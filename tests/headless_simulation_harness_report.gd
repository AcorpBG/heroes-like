extends Node

const HeadlessSimulationHarnessRulesScript = preload("res://scripts/core/HeadlessSimulationHarnessRules.gd")
const BattleAutoplayBalanceHarnessRulesScript = preload("res://scripts/core/BattleAutoplayBalanceHarnessRules.gd")
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
	var live_ai_case := _find_case(first, "strategic_ai_live_turn_execution")
	if live_ai_case.is_empty():
		_fail("Headless simulation harness is missing live strategic AI turn execution evidence.")
		return false
	if not _assert_live_ai_turn_execution(live_ai_case):
		return false
	var live_route_case := _find_case(first, "strategic_ai_live_route_progression")
	if live_route_case.is_empty():
		_fail("Headless simulation harness is missing live strategic AI route progression evidence.")
		return false
	if not _assert_live_ai_route_progression(live_route_case):
		return false
	var live_defense_case := _find_case(first, "strategic_ai_live_town_defense_retask")
	if live_defense_case.is_empty():
		_fail("Headless simulation harness is missing live strategic AI town-defense retask evidence.")
		return false
	if not _assert_live_ai_town_defense_retask(live_defense_case):
		return false
	var live_retake_case := _find_case(first, "strategic_ai_live_town_retake_assault")
	if live_retake_case.is_empty():
		_fail("Headless simulation harness is missing live strategic AI town-retake assault evidence.")
		return false
	if not _assert_live_ai_town_retake_assault(live_retake_case):
		return false
	var live_grouping_case := _find_case(first, "strategic_ai_live_raid_assault_grouping")
	if live_grouping_case.is_empty():
		_fail("Headless simulation harness is missing live strategic AI raid assault grouping evidence.")
		return false
	if not _assert_live_ai_raid_assault_grouping(live_grouping_case):
		return false
	var live_regroup_case := _find_case(first, "strategic_ai_live_regroup_retreat")
	if live_regroup_case.is_empty():
		_fail("Headless simulation harness is missing live strategic AI regroup/retreat evidence.")
		return false
	if not _assert_live_ai_regroup_retreat(live_regroup_case):
		return false
	var live_recruitment_case := _find_case(first, "strategic_ai_live_recruitment_delivery")
	if live_recruitment_case.is_empty():
		_fail("Headless simulation harness is missing live strategic AI recruitment delivery evidence.")
		return false
	if not _assert_live_ai_recruitment_delivery(live_recruitment_case):
		return false
	var multi_scenario_case := _find_case(first, "strategic_ai_multi_scenario_pressure_coverage")
	if multi_scenario_case.is_empty():
		_fail("Headless simulation harness is missing multi-scenario strategic AI pressure coverage evidence.")
		return false
	if not _assert_live_ai_multi_scenario_pressure_coverage(multi_scenario_case):
		return false
	var battle_summary: Dictionary = battle_case.get("summary", {})
	var battle_evidence: Dictionary = battle_case.get("evidence", {})
	if int(battle_summary.get("sample_count", 0)) <= 0:
		_fail("Battle resolver sampling did not emit any autoplay samples.")
		return false
	if int(battle_summary.get("sample_count", 0)) < int(battle_summary.get("requested_sample_limit", 0)):
		_fail("Battle resolver sampling did not reach the requested default sample breadth: %s" % battle_summary)
		return false
	if int(battle_summary.get("requested_sample_limit", 0)) < BattleAutoplayBalanceHarnessRulesScript.DEFAULT_SAMPLE_LIMIT:
		_fail("Battle resolver sampling did not use the expanded default sample limit: %s" % battle_summary)
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
		"balance_matrix",
		"balance_matrix_gate",
		"combat_feel_gate",
	]:
		if not battle_summary.has(String(required_summary_field)):
			_fail("Battle resolver sampling is missing combat-feel diagnostic field: %s" % required_summary_field)
			return false
	if not _assert_combat_feel_gate(battle_summary):
		return false
	if not _assert_balance_matrix_gate(battle_summary):
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
	if not initial_stack_profile.has("initiative") or not initial_stack_profile.has("role_counts") or not initial_stack_profile.has("ability_counts") or not initial_stack_profile.has("side_power_scores") or not initial_stack_profile.has("matchup_band") or not initial_stack_profile.has("side_role_counts") or not initial_stack_profile.has("side_ability_counts"):
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

func _assert_live_ai_recruitment_delivery(live_recruitment_case: Dictionary) -> bool:
	if String(live_recruitment_case.get("status", "")) != "pass":
		_fail("Live strategic AI recruitment delivery did not pass: %s" % JSON.stringify(live_recruitment_case))
		return false
	var summary: Dictionary = live_recruitment_case.get("summary", {}) if live_recruitment_case.get("summary", {}) is Dictionary else {}
	var evidence: Dictionary = live_recruitment_case.get("evidence", {}) if live_recruitment_case.get("evidence", {}) is Dictionary else {}
	if String(summary.get("town_id", "")) != "duskfen_bastion" or String(summary.get("target_id", "")) != "river_free_company":
		_fail("Live strategic AI recruitment delivery used unexpected town/target ids: %s" % summary)
		return false
	if String(summary.get("unit_id", "")) != "unit_bog_brute":
		_fail("Live strategic AI recruitment delivery used unexpected unit id: %s" % summary)
		return false
	if int(summary.get("desired_before", 0)) <= int(summary.get("before_strength", 0)):
		_fail("Live strategic AI recruitment delivery fixture had no raid strength need: %s" % summary)
		return false
	if int(summary.get("after_strength", 0)) <= int(summary.get("before_strength", 0)):
		_fail("Live strategic AI recruitment delivery did not increase raid strength: %s" % summary)
		return false
	if int(summary.get("town_recruits_after", 9999)) >= int(summary.get("town_recruits_before", 0)):
		_fail("Live strategic AI recruitment delivery did not consume town recruits: %s" % summary)
		return false
	if int(summary.get("raid_unit_after", 0)) < 5:
		_fail("Live strategic AI recruitment delivery did not add recruits to the raid army: %s" % summary)
		return false
	if int(summary.get("town_recruit_event_count", 0)) < 1 or int(summary.get("raid_reinforcement_event_count", 0)) < 1:
		_fail("Live strategic AI recruitment delivery is missing recruitment/reinforcement events: %s" % summary)
		return false
	var event_types: Array = evidence.get("event_types", []) if evidence.get("event_types", []) is Array else []
	if "ai_town_recruited" not in event_types or "ai_raid_reinforced" not in event_types:
		_fail("Live strategic AI recruitment delivery missing event type evidence: %s" % event_types)
		return false
	var raid: Dictionary = evidence.get("raid", {}) if evidence.get("raid", {}) is Dictionary else {}
	if String(raid.get("target_kind", "")) != "resource" or String(raid.get("target_placement_id", "")) != "river_free_company":
		_fail("Live strategic AI recruitment delivery lost the active raid target: %s" % raid)
		return false
	if String(evidence.get("save_policy", "")) != "no_hero_task_state_write_no_save_migration":
		_fail("Live strategic AI recruitment delivery save policy changed: %s" % evidence)
		return false
	var leak_tokens: Array = evidence.get("public_event_leak_tokens", []) if evidence.get("public_event_leak_tokens", []) is Array else []
	if not leak_tokens.is_empty():
		_fail("Live strategic AI recruitment delivery leaked internal public-event tokens: %s" % leak_tokens)
		return false
	return true

func _assert_live_ai_multi_scenario_pressure_coverage(multi_scenario_case: Dictionary) -> bool:
	if String(multi_scenario_case.get("status", "")) != "pass":
		_fail("Multi-scenario strategic AI pressure coverage did not pass: %s" % JSON.stringify(multi_scenario_case))
		return false
	var summary: Dictionary = multi_scenario_case.get("summary", {}) if multi_scenario_case.get("summary", {}) is Dictionary else {}
	var evidence: Dictionary = multi_scenario_case.get("evidence", {}) if multi_scenario_case.get("evidence", {}) is Dictionary else {}
	if int(summary.get("scenario_count", 0)) < 5 or int(summary.get("faction_case_count", 0)) < 9:
		_fail("Multi-scenario strategic AI pressure coverage is too narrow: %s" % summary)
		return false
	if int(summary.get("launched_faction_count", 0)) != int(summary.get("faction_case_count", -1)):
		_fail("Multi-scenario strategic AI pressure coverage did not launch for every faction: %s" % summary)
		return false
	if int(summary.get("target_assignment_event_count", 0)) < int(summary.get("faction_case_count", 0)):
		_fail("Multi-scenario strategic AI pressure coverage is missing target assignment events: %s" % summary)
		return false
	if String(summary.get("prismhearth_controller_town_id", "")) != "halo_spire" or String(summary.get("prismhearth_controlling_faction_id", "")) != "faction_mireclaw":
		_fail("Prismhearth occupied Halo Spire did not remain a Mireclaw AI base: %s" % summary)
		return false
	var scenario_ids := []
	for row in evidence.get("scenarios", []):
		if row is Dictionary:
			scenario_ids.append(String(row.get("scenario_id", "")))
	for required_id in ["river-pass", "prismhearth-watch", "glassroad-sundering", "glassfen-breakers", "ninefold-confluence"]:
		if required_id not in scenario_ids:
			_fail("Multi-scenario strategic AI pressure coverage missed scenario: %s" % required_id)
			return false
	var faction_cases: Array = evidence.get("faction_cases", []) if evidence.get("faction_cases", []) is Array else []
	var saw_prismhearth := false
	for row in faction_cases:
		if not (row is Dictionary):
			continue
		if int(row.get("owned_base_count", 0)) <= 0 or not bool(row.get("launched", false)):
			_fail("Multi-scenario strategic AI pressure coverage has an unlaunched faction row: %s" % row)
			return false
		if String(row.get("scenario_id", "")) == "prismhearth-watch" and String(row.get("faction_id", "")) == "faction_mireclaw":
			var town: Dictionary = row.get("controller_town", {}) if row.get("controller_town", {}) is Dictionary else {}
			if String(town.get("placement_id", "")) == "halo_spire" and String(town.get("controlling_faction_id", "")) == "faction_mireclaw":
				saw_prismhearth = true
	if not saw_prismhearth:
		_fail("Multi-scenario strategic AI pressure coverage did not include Prismhearth Halo Spire controller evidence.")
		return false
	var event_types: Array = evidence.get("event_types", []) if evidence.get("event_types", []) is Array else []
	if "ai_target_assigned" not in event_types:
		_fail("Multi-scenario strategic AI pressure coverage missing ai_target_assigned event evidence: %s" % event_types)
		return false
	if String(evidence.get("save_policy", "")) != "no_hero_task_state_write_no_save_migration":
		_fail("Multi-scenario strategic AI pressure coverage save policy changed: %s" % evidence)
		return false
	var leak_tokens: Array = evidence.get("public_event_leak_tokens", []) if evidence.get("public_event_leak_tokens", []) is Array else []
	if not leak_tokens.is_empty():
		_fail("Multi-scenario strategic AI pressure coverage leaked internal public-event tokens: %s" % leak_tokens)
		return false
	return true

func _assert_live_ai_regroup_retreat(live_regroup_case: Dictionary) -> bool:
	if String(live_regroup_case.get("status", "")) != "pass":
		_fail("Live strategic AI regroup/retreat did not pass: %s" % JSON.stringify(live_regroup_case))
		return false
	var summary: Dictionary = live_regroup_case.get("summary", {}) if live_regroup_case.get("summary", {}) is Dictionary else {}
	var evidence: Dictionary = live_regroup_case.get("evidence", {}) if live_regroup_case.get("evidence", {}) is Dictionary else {}
	if String(summary.get("target_id", "")) != "river_free_company" or String(summary.get("regroup_town_id", "")) != "duskfen_bastion":
		_fail("Live strategic AI regroup/retreat used unexpected target/town ids: %s" % summary)
		return false
	if not bool(summary.get("regroup_needed_before", false)):
		_fail("Live strategic AI regroup/retreat fixture was not understrength before the turn: %s" % summary)
		return false
	if int(summary.get("after_strength", 0)) <= int(summary.get("before_strength", 0)):
		_fail("Live strategic AI regroup/retreat did not increase raid strength: %s" % summary)
		return false
	if int(summary.get("garrison_after", 9999)) >= int(summary.get("garrison_before", 0)):
		_fail("Live strategic AI regroup/retreat did not pull from town garrison: %s" % summary)
		return false
	if String(summary.get("resource_controller_after", "")) == "faction_mireclaw":
		_fail("Live strategic AI regroup/retreat captured the offensive target instead of retreating: %s" % summary)
		return false
	if int(summary.get("target_assignment_event_count", 0)) < 1 or int(summary.get("regroup_event_count", 0)) < 1:
		_fail("Live strategic AI regroup/retreat is missing assignment/regroup events: %s" % summary)
		return false
	var raid: Dictionary = evidence.get("raid", {}) if evidence.get("raid", {}) is Dictionary else {}
	if String(raid.get("target_kind", "")) != "" or String(raid.get("last_regroup_town_id", "")) != "duskfen_bastion":
		_fail("Live strategic AI regroup/retreat did not clear target and record Duskfen: %s" % raid)
		return false
	if String(evidence.get("save_policy", "")) != "no_hero_task_state_write_no_save_migration":
		_fail("Live strategic AI regroup/retreat save policy changed: %s" % evidence)
		return false
	var event_types: Array = evidence.get("event_types", []) if evidence.get("event_types", []) is Array else []
	if "ai_target_assigned" not in event_types or "ai_raid_regrouped" not in event_types:
		_fail("Live strategic AI regroup/retreat missing event type evidence: %s" % event_types)
		return false
	var leak_tokens: Array = evidence.get("public_event_leak_tokens", []) if evidence.get("public_event_leak_tokens", []) is Array else []
	if not leak_tokens.is_empty():
		_fail("Live strategic AI regroup/retreat leaked internal public-event tokens: %s" % leak_tokens)
		return false
	return true

func _assert_live_ai_route_progression(live_route_case: Dictionary) -> bool:
	if String(live_route_case.get("status", "")) != "pass":
		_fail("Live strategic AI route progression did not pass: %s" % JSON.stringify(live_route_case))
		return false
	var summary: Dictionary = live_route_case.get("summary", {}) if live_route_case.get("summary", {}) is Dictionary else {}
	var evidence: Dictionary = live_route_case.get("evidence", {}) if live_route_case.get("evidence", {}) is Dictionary else {}
	if String(summary.get("target_id", "")) != "river_free_company":
		_fail("Live strategic AI route progression used an unexpected target: %s" % summary)
		return false
	if not bool(summary.get("assigned_target", false)) or not bool(summary.get("seized_target", false)):
		_fail("Live strategic AI route progression did not assign and seize its target: %s" % summary)
		return false
	if String(summary.get("target_controller", "")) != "faction_mireclaw":
		_fail("Live strategic AI route progression did not leave target under Mireclaw control: %s" % summary)
		return false
	if int(summary.get("initial_goal_distance", 0)) <= int(summary.get("final_goal_distance", 9999)):
		_fail("Live strategic AI route progression did not reduce route distance: %s" % summary)
		return false
	if int(summary.get("initial_goal_distance", 0)) <= 0 or int(summary.get("final_goal_distance", -1)) != 0:
		_fail("Live strategic AI route progression has invalid initial/final route distance: %s" % summary)
		return false
	if int(summary.get("turns_simulated", 0)) < 2:
		_fail("Live strategic AI route progression did not exercise multiple turns: %s" % summary)
		return false
	if int(summary.get("target_assignment_event_count", 0)) < 1 or int(summary.get("site_seizure_event_count", 0)) < 1:
		_fail("Live strategic AI route progression is missing assignment/seizure events: %s" % summary)
		return false
	var route_records: Array = evidence.get("route_records", []) if evidence.get("route_records", []) is Array else []
	if route_records.size() != int(summary.get("turns_simulated", -1)):
		_fail("Live strategic AI route progression route records do not match turn count: %s" % evidence)
		return false
	if route_records.is_empty() or String(route_records[0].get("target_id", "")) != "river_free_company":
		_fail("Live strategic AI route progression first route record does not show target assignment: %s" % route_records)
		return false
	var last_record: Dictionary = route_records[route_records.size() - 1]
	if not bool(last_record.get("arrived", false)) or String(last_record.get("controller", "")) != "faction_mireclaw":
		_fail("Live strategic AI route progression last record did not arrive and seize: %s" % last_record)
		return false
	if String(evidence.get("save_policy", "")) != "no_hero_task_state_write_no_save_migration":
		_fail("Live strategic AI route progression save policy changed: %s" % evidence)
		return false
	var leak_tokens: Array = evidence.get("public_event_leak_tokens", []) if evidence.get("public_event_leak_tokens", []) is Array else []
	if not leak_tokens.is_empty():
		_fail("Live strategic AI route progression leaked internal public-event tokens: %s" % leak_tokens)
		return false
	return true

func _assert_live_ai_town_defense_retask(live_defense_case: Dictionary) -> bool:
	if String(live_defense_case.get("status", "")) != "pass":
		_fail("Live strategic AI town-defense retask did not pass: %s" % JSON.stringify(live_defense_case))
		return false
	var summary: Dictionary = live_defense_case.get("summary", {}) if live_defense_case.get("summary", {}) is Dictionary else {}
	var evidence: Dictionary = live_defense_case.get("evidence", {}) if live_defense_case.get("evidence", {}) is Dictionary else {}
	if String(summary.get("town_id", "")) != "duskfen_bastion" or String(summary.get("previous_target_id", "")) != "river_free_company":
		_fail("Live strategic AI town-defense retask used unexpected town/previous target ids: %s" % summary)
		return false
	if bool(summary.get("regroup_needed_before", true)):
		_fail("Live strategic AI town-defense fixture should not need regroup: %s" % summary)
		return false
	if int(summary.get("target_assignment_event_count", 0)) < 1:
		_fail("Live strategic AI town-defense retask is missing assignment event evidence: %s" % summary)
		return false
	if String(summary.get("resource_controller_after", "")) == "faction_mireclaw":
		_fail("Live strategic AI town-defense retask captured the old resource target: %s" % summary)
		return false
	var raid: Dictionary = evidence.get("raid", {}) if evidence.get("raid", {}) is Dictionary else {}
	if String(raid.get("target_kind", "")) != "town" or String(raid.get("target_placement_id", "")) != "duskfen_bastion":
		_fail("Live strategic AI town-defense retask raid did not defend Duskfen: %s" % raid)
		return false
	var reason_codes: Array = evidence.get("target_reason_codes", []) if evidence.get("target_reason_codes", []) is Array else []
	if "town_defense" not in reason_codes or "front_stabilization" not in reason_codes:
		_fail("Live strategic AI town-defense retask missed reason code evidence: %s" % reason_codes)
		return false
	var event_types: Array = evidence.get("event_types", []) if evidence.get("event_types", []) is Array else []
	if "ai_target_assigned" not in event_types:
		_fail("Live strategic AI town-defense retask missing assignment event type evidence: %s" % event_types)
		return false
	if String(evidence.get("save_policy", "")) != "no_hero_task_state_write_no_save_migration":
		_fail("Live strategic AI town-defense retask save policy changed: %s" % evidence)
		return false
	var leak_tokens: Array = evidence.get("public_event_leak_tokens", []) if evidence.get("public_event_leak_tokens", []) is Array else []
	if not leak_tokens.is_empty():
		_fail("Live strategic AI town-defense retask leaked internal public-event tokens: %s" % leak_tokens)
		return false
	return true

func _assert_live_ai_town_retake_assault(live_retake_case: Dictionary) -> bool:
	if String(live_retake_case.get("status", "")) != "pass":
		_fail("Live strategic AI town-retake assault did not pass: %s" % JSON.stringify(live_retake_case))
		return false
	var summary: Dictionary = live_retake_case.get("summary", {}) if live_retake_case.get("summary", {}) is Dictionary else {}
	var evidence: Dictionary = live_retake_case.get("evidence", {}) if live_retake_case.get("evidence", {}) is Dictionary else {}
	if String(summary.get("town_id", "")) != "duskfen_bastion":
		_fail("Live strategic AI town-retake assault used unexpected town id: %s" % summary)
		return false
	if String(summary.get("selector_target_kind", "")) != "town" or String(summary.get("selector_target_id", "")) != "duskfen_bastion":
		_fail("Live strategic AI town-retake selector did not prefer Duskfen: %s" % summary)
		return false
	if int(summary.get("target_assignment_event_count", 0)) < 1:
		_fail("Live strategic AI town-retake assault is missing assignment event evidence: %s" % summary)
		return false
	if String(summary.get("battle_context_type", "")) != "town_defense" or String(summary.get("battle_town_id", "")) != "duskfen_bastion":
		_fail("Live strategic AI town-retake assault did not queue a Duskfen town-defense battle: %s" % summary)
		return false
	var raid: Dictionary = evidence.get("raid", {}) if evidence.get("raid", {}) is Dictionary else {}
	if String(raid.get("target_kind", "")) != "town" or String(raid.get("target_placement_id", "")) != "duskfen_bastion":
		_fail("Live strategic AI town-retake raid did not target Duskfen: %s" % raid)
		return false
	var event_types: Array = evidence.get("event_types", []) if evidence.get("event_types", []) is Array else []
	if "ai_target_assigned" not in event_types:
		_fail("Live strategic AI town-retake assault missing assignment event type evidence: %s" % event_types)
		return false
	if String(evidence.get("save_policy", "")) != "no_hero_task_state_write_no_save_migration":
		_fail("Live strategic AI town-retake assault save policy changed: %s" % evidence)
		return false
	var leak_tokens: Array = evidence.get("public_event_leak_tokens", []) if evidence.get("public_event_leak_tokens", []) is Array else []
	if not leak_tokens.is_empty():
		_fail("Live strategic AI town-retake assault leaked internal public-event tokens: %s" % leak_tokens)
		return false
	return true

func _assert_live_ai_raid_assault_grouping(live_grouping_case: Dictionary) -> bool:
	if String(live_grouping_case.get("status", "")) != "pass":
		_fail("Live strategic AI raid assault grouping did not pass: %s" % JSON.stringify(live_grouping_case))
		return false
	var summary: Dictionary = live_grouping_case.get("summary", {}) if live_grouping_case.get("summary", {}) is Dictionary else {}
	var evidence: Dictionary = live_grouping_case.get("evidence", {}) if live_grouping_case.get("evidence", {}) is Dictionary else {}
	if String(summary.get("town_id", "")) != "duskfen_bastion":
		_fail("Live strategic AI raid assault grouping used unexpected town id: %s" % summary)
		return false
	if int(summary.get("active_before", 0)) < 2 or int(summary.get("active_after", 99)) >= int(summary.get("active_before", 0)):
		_fail("Live strategic AI raid assault grouping did not reduce active raid pressure: %s" % summary)
		return false
	if int(summary.get("leader_strength_after", 0)) < int(summary.get("leader_strength_before", 0)) + int(summary.get("support_strength_before", 0)):
		_fail("Live strategic AI raid assault grouping did not transfer support strength: %s" % summary)
		return false
	if int(summary.get("grouping_event_count", 0)) < 1:
		_fail("Live strategic AI raid assault grouping is missing ai_raid_grouped evidence: %s" % summary)
		return false
	if String(summary.get("battle_context_type", "")) != "town_defense" or String(summary.get("battle_town_id", "")) != "duskfen_bastion":
		_fail("Live strategic AI raid assault grouping did not continue into Duskfen town defense: %s" % summary)
		return false
	var resolved: Array = evidence.get("resolved_encounters", []) if evidence.get("resolved_encounters", []) is Array else []
	if String(summary.get("support_id", "")) not in resolved:
		_fail("Live strategic AI raid assault grouping did not resolve the support host: %s" % evidence)
		return false
	var event_types: Array = evidence.get("event_types", []) if evidence.get("event_types", []) is Array else []
	if "ai_raid_grouped" not in event_types:
		_fail("Live strategic AI raid assault grouping missing event type evidence: %s" % event_types)
		return false
	if String(evidence.get("save_policy", "")) != "no_hero_task_state_write_no_save_migration":
		_fail("Live strategic AI raid assault grouping save policy changed: %s" % evidence)
		return false
	var leak_tokens: Array = evidence.get("public_event_leak_tokens", []) if evidence.get("public_event_leak_tokens", []) is Array else []
	if not leak_tokens.is_empty():
		_fail("Live strategic AI raid assault grouping leaked internal public-event tokens: %s" % leak_tokens)
		return false
	return true

func _assert_live_ai_turn_execution(live_ai_case: Dictionary) -> bool:
	if String(live_ai_case.get("status", "")) != "pass":
		_fail("Live strategic AI turn execution did not pass: %s" % JSON.stringify(live_ai_case))
		return false
	var summary: Dictionary = live_ai_case.get("summary", {}) if live_ai_case.get("summary", {}) is Dictionary else {}
	var evidence: Dictionary = live_ai_case.get("evidence", {}) if live_ai_case.get("evidence", {}) is Dictionary else {}
	if String(summary.get("primary_target_id", "")) != "river_free_company" or String(summary.get("companion_target_id", "")) != "river_signal_post":
		_fail("Live strategic AI turn execution used unexpected target ids: %s" % summary)
		return false
	if int(summary.get("resource_fronts_seized", 0)) < 2:
		_fail("Live strategic AI turn execution did not seize both resource fronts: %s" % summary)
		return false
	if int(summary.get("target_assignment_event_count", 0)) < 2 or int(summary.get("site_seizure_event_count", 0)) < 2:
		_fail("Live strategic AI turn execution is missing assignment/seizure event evidence: %s" % summary)
		return false
	if not bool(summary.get("reserved_unique_targets", false)):
		_fail("Live strategic AI turn execution did not prove companion target reservation: %s" % summary)
		return false
	var controllers_after: Dictionary = evidence.get("controllers_after", {}) if evidence.get("controllers_after", {}) is Dictionary else {}
	if String(controllers_after.get("river_free_company", "")) != "faction_mireclaw" or String(controllers_after.get("river_signal_post", "")) != "faction_mireclaw":
		_fail("Live strategic AI turn execution did not leave both sites under Mireclaw control: %s" % evidence)
		return false
	var primary_raid: Dictionary = evidence.get("primary_raid", {}) if evidence.get("primary_raid", {}) is Dictionary else {}
	var companion_raid: Dictionary = evidence.get("companion_raid", {}) if evidence.get("companion_raid", {}) is Dictionary else {}
	if String(primary_raid.get("target_placement_id", "")) != "river_free_company" or not bool(primary_raid.get("arrived", false)):
		_fail("Live strategic AI primary raid did not arrive at Free Company: %s" % primary_raid)
		return false
	if String(companion_raid.get("target_placement_id", "")) != "river_signal_post" or not bool(companion_raid.get("arrived", false)):
		_fail("Live strategic AI companion raid did not arrive at Signal Post: %s" % companion_raid)
		return false
	if String(evidence.get("save_policy", "")) != "no_hero_task_state_write_no_save_migration":
		_fail("Live strategic AI turn execution save policy changed: %s" % evidence)
		return false
	var leak_tokens: Array = evidence.get("public_event_leak_tokens", []) if evidence.get("public_event_leak_tokens", []) is Array else []
	if not leak_tokens.is_empty():
		_fail("Live strategic AI turn execution leaked internal public-event tokens: %s" % leak_tokens)
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

func _assert_balance_matrix_gate(battle_summary: Dictionary) -> bool:
	var matrix: Dictionary = battle_summary.get("balance_matrix", {}) if battle_summary.get("balance_matrix", {}) is Dictionary else {}
	var gate: Dictionary = battle_summary.get("balance_matrix_gate", {}) if battle_summary.get("balance_matrix_gate", {}) is Dictionary else {}
	if String(matrix.get("schema", "")) != "battle_autoplay_balance_matrix_v1":
		_fail("Battle resolver sampling balance matrix schema mismatch: %s" % matrix)
		return false
	if String(matrix.get("policy", "")) != "report_only_balance_matrix_v1":
		_fail("Battle resolver sampling balance matrix policy mismatch: %s" % matrix)
		return false
	if String(gate.get("policy", "")) != "report_only_balance_matrix_thresholds_v1":
		_fail("Battle resolver sampling balance matrix gate policy mismatch: %s" % gate)
		return false
	if String(gate.get("status", "")) not in ["pass", "warning", "fail"]:
		_fail("Battle resolver sampling balance matrix gate status is unsupported: %s" % gate)
		return false
	if String(gate.get("status", "")) != "pass":
		_fail("Battle resolver sampling balance matrix gate must pass without terminal-margin warnings: %s" % gate)
		return false
	for section_id in ["difficulty", "terrain", "scenario", "matchup", "ability_presence"]:
		var section: Dictionary = matrix.get(section_id, {}) if matrix.get(section_id, {}) is Dictionary else {}
		if section.is_empty():
			_fail("Battle resolver sampling balance matrix missing section: %s" % section_id)
			return false
	var difficulty: Dictionary = matrix.get("difficulty", {}) if matrix.get("difficulty", {}) is Dictionary else {}
	for required_difficulty in ["low", "medium", "high"]:
		if not difficulty.has(required_difficulty):
			_fail("Battle resolver sampling balance matrix missing difficulty cohort: %s" % required_difficulty)
			return false
	if int(gate.get("sample_count", -1)) != int(battle_summary.get("sample_count", -2)):
		_fail("Battle resolver sampling balance matrix gate sample count does not align with summary: %s" % gate)
		return false
	var outliers: Array = matrix.get("terminal_margin_outliers", []) if matrix.get("terminal_margin_outliers", []) is Array else []
	if outliers.size() != int(gate.get("terminal_margin_outlier_count", -1)):
		_fail("Battle resolver sampling balance matrix outlier count does not match gate: %s" % gate)
		return false
	if not outliers.is_empty():
		_fail("Battle resolver sampling balance matrix still has terminal-margin outliers: %s" % outliers)
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
