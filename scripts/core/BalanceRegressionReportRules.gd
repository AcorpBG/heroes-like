class_name BalanceRegressionReportRules
extends RefCounted

const RandomMapGeneratorRulesScript = preload("res://scripts/core/RandomMapGeneratorRules.gd")
const ScenarioFactoryScript = preload("res://scripts/core/ScenarioFactory.gd")
const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_SCHEMA_ID := "balance_regression_report_suite_v1"
const REPORT_ID := "BALANCE_REGRESSION_REPORT_SUITE"
const HEX_DIGITS := "0123456789abcdef"
const LIVE_RESOURCE_IDS := ["gold", "wood", "ore"]
const REQUIRED_SECTION_IDS := [
	"faction_content_balance_snapshot",
	"economy_pressure_resource_viability",
	"scenario_viability",
	"battle_outcome_distribution",
	"ai_objective_pressure",
	"save_replay_stability",
]

static func build_report(input_config: Dictionary = {}) -> Dictionary:
	ContentService.clear_generated_scenario_drafts()
	var generated_sample := _generated_map_case(input_config, "skirmish-ui-save-replay-10184")
	var sections := [
		_faction_content_balance_snapshot(),
		_economy_pressure_resource_viability(input_config, generated_sample),
		_scenario_viability(input_config, generated_sample),
		_battle_outcome_distribution(input_config),
		_ai_objective_pressure(input_config),
		_save_replay_stability(input_config, generated_sample),
	]
	var section_map := {}
	var status_counts := {"pass": 0, "warning": 0, "deferred": 0, "fail": 0}
	for section in sections:
		if not (section is Dictionary):
			continue
		var section_id := String(section.get("section_id", ""))
		var status := String(section.get("status", "fail"))
		section_map[section_id] = section
		status_counts[status] = int(status_counts.get(status, 0)) + 1
	var missing_sections := []
	for section_id in REQUIRED_SECTION_IDS:
		if not section_map.has(section_id):
			missing_sections.append(section_id)
	var overall_status := "pass"
	if not missing_sections.is_empty() or int(status_counts.get("fail", 0)) > 0:
		overall_status = "fail"
	elif int(status_counts.get("deferred", 0)) > 0 or int(status_counts.get("warning", 0)) > 0:
		overall_status = "warning"
	var suite_signature := suite_signature_for_sections(sections, status_counts, missing_sections)
	return {
		"ok": overall_status != "fail",
		"report_id": REPORT_ID,
		"schema_id": REPORT_SCHEMA_ID,
		"status": overall_status,
		"status_counts": status_counts,
		"section_count": sections.size(),
		"required_sections": REQUIRED_SECTION_IDS,
		"missing_sections": missing_sections,
		"sections": sections,
		"section_signatures": _section_signature_index(sections),
		"suite_signature": suite_signature,
		"self_signature_check": suite_signature == suite_signature_for_sections(sections, status_counts, missing_sections),
		"reporting_policy": {
			"automatic_tuning": false,
			"runtime_balance_changes": false,
			"authored_content_writeback": false,
			"alpha_or_parity_claim": false,
			"hidden_content_dump": false,
		},
	}

static func suite_signature_for_sections(sections: Array, status_counts: Dictionary, missing_sections: Array) -> String:
	return _signature_for({
		"schema_id": REPORT_SCHEMA_ID,
		"sections": _section_signature_index(sections),
		"status_counts": status_counts,
		"missing_sections": missing_sections,
	})

static func compact_summary(report: Dictionary) -> Dictionary:
	var sections := []
	for section in report.get("sections", []):
		if not (section is Dictionary):
			continue
		sections.append({
			"section_id": String(section.get("section_id", "")),
			"status": String(section.get("status", "")),
			"signature": String(section.get("signature", "")),
			"summary": section.get("summary", {}),
			"deferred": section.get("deferred", []),
			"warnings": section.get("warnings", []),
		})
	return {
		"ok": bool(report.get("ok", false)),
		"schema_id": String(report.get("schema_id", "")),
		"status": String(report.get("status", "")),
		"status_counts": report.get("status_counts", {}),
		"suite_signature": String(report.get("suite_signature", "")),
		"sections": sections,
		"reporting_policy": report.get("reporting_policy", {}),
	}

static func _faction_content_balance_snapshot() -> Dictionary:
	var factions: Array = _content_items(ContentService.FACTIONS_PATH)
	var units: Array = _content_items(ContentService.UNITS_PATH)
	var heroes: Array = _content_items(ContentService.HEROES_PATH)
	var towns: Array = _content_items(ContentService.TOWNS_PATH)
	var faction_rows := []
	var warnings := []
	for faction in factions:
		if not (faction is Dictionary):
			continue
		var faction_id := String(faction.get("id", ""))
		var faction_units := _items_matching(units, "faction_id", faction_id)
		var faction_heroes := _items_matching(heroes, "faction_id", faction_id)
		var faction_towns := _items_matching(towns, "faction_id", faction_id)
		var tier_counts := {}
		var role_counts := {}
		var total_growth := 0
		var weekly_recruit_cost := _empty_resource_pool()
		for unit in faction_units:
			if not (unit is Dictionary):
				continue
			var tier := str(int(unit.get("tier", 0)))
			tier_counts[tier] = int(tier_counts.get(tier, 0)) + 1
			var role := String(unit.get("role", "unknown"))
			role_counts[role] = int(role_counts.get(role, 0)) + 1
			var growth: int = max(0, int(unit.get("growth", 0)))
			total_growth += growth
			_add_scaled_cost(weekly_recruit_cost, unit.get("cost", {}), growth)
		var playable_surface_count := (1 if faction_units.size() > 0 else 0) + (1 if faction_heroes.size() > 0 else 0) + (1 if faction_towns.size() > 0 else 0)
		if playable_surface_count < 3:
			warnings.append("%s has incomplete unit/hero/town content surface." % faction_id)
		faction_rows.append({
			"faction_id": faction_id,
			"unit_count": faction_units.size(),
			"hero_count": faction_heroes.size(),
			"town_count": faction_towns.size(),
			"tier_counts": tier_counts,
			"role_counts": role_counts,
			"total_growth": total_growth,
			"weekly_recruit_cost": weekly_recruit_cost,
			"economy_base_income": _resource_pool(faction.get("economy", {}).get("base_income", {})),
			"content_status": faction.get("content_status", {}),
		})
	faction_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("faction_id", "")) < String(b.get("faction_id", ""))
	)
	var completed_surfaces := 0
	for row in faction_rows:
		if int(row.get("unit_count", 0)) > 0 and int(row.get("hero_count", 0)) > 0 and int(row.get("town_count", 0)) > 0:
			completed_surfaces += 1
	var status := "pass" if completed_surfaces >= 2 and warnings.is_empty() else "warning"
	return _section(
		"faction_content_balance_snapshot",
		status,
		{
			"faction_count": faction_rows.size(),
			"factions_with_unit_hero_town_surface": completed_surfaces,
			"unit_count": units.size(),
			"hero_count": heroes.size(),
			"town_count": towns.size(),
		},
		{
			"factions": faction_rows,
			"warnings": warnings,
		},
		warnings,
		[]
	)

static func _economy_pressure_resource_viability(input_config: Dictionary, generated_sample: Dictionary = {}) -> Dictionary:
	var scenarios: Array = _content_items(ContentService.SCENARIOS_PATH)
	var scenario_rows := []
	var warnings := []
	var failures := []
	for scenario in scenarios:
		if not (scenario is Dictionary):
			continue
		var scenario_id := String(scenario.get("id", ""))
		var starts := _resource_pool(scenario.get("starting_resources", {}))
		var resource_nodes: Array = scenario.get("resource_nodes", []) if scenario.get("resource_nodes", []) is Array else []
		var available := {}
		for resource_id in LIVE_RESOURCE_IDS:
			available[resource_id] = int(starts.get(resource_id, 0))
		for node in resource_nodes:
			if not (node is Dictionary):
				continue
			var site := ContentService.get_resource_site(String(node.get("site_id", "")))
			for source_key in ["rewards", "claim_rewards", "control_income"]:
				var pool: Dictionary = _resource_pool(site.get(source_key, {}))
				for resource_id in LIVE_RESOURCE_IDS:
					available[resource_id] = int(available.get(resource_id, 0)) + int(pool.get(resource_id, 0))
		var missing_live_support := []
		for resource_id in LIVE_RESOURCE_IDS:
			if int(available.get(resource_id, 0)) <= 0:
				missing_live_support.append(resource_id)
		if int(starts.get("gold", 0)) <= 0:
			failures.append("%s has no starting gold." % scenario_id)
		elif not missing_live_support.is_empty():
			warnings.append("%s has limited visible support for %s." % [scenario_id, ", ".join(missing_live_support)])
		scenario_rows.append({
			"scenario_id": scenario_id,
			"starting_resources": starts,
			"resource_node_count": resource_nodes.size(),
			"visible_live_resource_support": available,
			"missing_live_resource_support": missing_live_support,
		})
	var rmg_case := generated_sample if not generated_sample.is_empty() else _generated_map_case(input_config, "balance-economy-pressure-10184")
	var rmg_fairness: Dictionary = rmg_case.get("generated_map", {}).get("staging", {}).get("fairness_report", {}) if rmg_case.get("generated_map", {}) is Dictionary else {}
	if not bool(rmg_case.get("ok", false)):
		var failed_report: Dictionary = rmg_case.get("report", {}) if rmg_case.get("report", {}) is Dictionary else {}
		warnings.append("Generated-map economy pressure sample is unavailable: status=%s failures=%d warnings=%d." % [
			String(failed_report.get("status", "unknown")),
			int(failed_report.get("failure_count", 0)),
			int(failed_report.get("warning_count", 0)),
		])
	elif String(rmg_fairness.get("status", "")) not in ["pass", "warning"]:
		warnings.append("Generated-map fairness report did not return pass/warning: %s" % JSON.stringify(rmg_fairness.get("summary", {})))
	var status := "pass"
	if not failures.is_empty():
		status = "fail"
	elif not warnings.is_empty():
		status = "warning"
	return _section(
		"economy_pressure_resource_viability",
		status,
		{
			"scenario_count": scenario_rows.size(),
			"generated_fairness_status": String(rmg_fairness.get("status", "deferred" if rmg_fairness.is_empty() else "")),
			"warning_count": warnings.size(),
			"failure_count": failures.size(),
		},
		{
			"scenarios": scenario_rows,
			"generated_map_fairness_summary": rmg_fairness.get("summary", {}),
			"generated_map_fairness_signature": _signature_for(rmg_fairness),
			"warnings": warnings,
			"failures": failures,
		},
		warnings,
		[]
	)

static func _scenario_viability(input_config: Dictionary, generated_sample: Dictionary = {}) -> Dictionary:
	var scenarios: Array = _content_items(ContentService.SCENARIOS_PATH)
	var rows := []
	var warnings := []
	var failures := []
	for scenario in scenarios:
		if not (scenario is Dictionary):
			continue
		var scenario_id := String(scenario.get("id", ""))
		var session = ScenarioFactoryScript.create_session(scenario_id, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
		OverworldRules.normalize_overworld_state(session)
		var map_size := OverworldRules.derive_map_size(session)
		var availability: Dictionary = scenario.get("selection", {}).get("availability", {}) if scenario.get("selection", {}) is Dictionary else {}
		var row := {
			"scenario_id": scenario_id,
			"available_campaign": bool(availability.get("campaign", false)),
			"available_skirmish": bool(availability.get("skirmish", false)),
			"map_size": {"x": map_size.x, "y": map_size.y},
			"hero_id": String(session.hero_id),
			"town_count": session.overworld.get("towns", []).size(),
			"resource_node_count": session.overworld.get("resource_nodes", []).size(),
			"encounter_count": session.overworld.get("encounters", []).size(),
			"enemy_state_count": session.overworld.get("enemy_states", []).size(),
			"terrain_layer_loaded": not session.overworld.get("terrain_layers", {}).is_empty(),
		}
		if String(session.scenario_id) != scenario_id or String(session.hero_id) == "":
			failures.append("%s did not bootstrap with a hero." % scenario_id)
		if bool(availability.get("skirmish", false)) and int(row.get("enemy_state_count", 0)) <= 0:
			warnings.append("%s is skirmish-visible with no enemy states." % scenario_id)
		if map_size.x <= 0 or map_size.y <= 0:
			failures.append("%s produced an invalid map size." % scenario_id)
		rows.append(row)
	var generated_session_result := _generated_session_viability(input_config, generated_sample)
	if not bool(generated_session_result.get("ok", false)):
		warnings.append("Generated-safe scenario viability is deferred: %s" % String(generated_session_result.get("reason", "")))
	var status := "pass"
	if not failures.is_empty():
		status = "fail"
	elif not warnings.is_empty():
		status = "warning"
	return _section(
		"scenario_viability",
		status,
		{
			"authored_scenario_count": rows.size(),
			"generated_safe_status": String(generated_session_result.get("status", "")),
			"warning_count": warnings.size(),
			"failure_count": failures.size(),
		},
		{
			"authored_scenarios": rows,
			"generated_safe_scenario": generated_session_result,
			"warnings": warnings,
			"failures": failures,
		},
		warnings,
		[]
	)

static func _battle_outcome_distribution(input_config: Dictionary) -> Dictionary:
	var sample_scenarios: Array = input_config.get("battle_sample_scenarios", ["river-pass"])
	var samples := []
	var warnings := []
	var deferred := []
	for scenario_id_value in sample_scenarios:
		var scenario_id := String(scenario_id_value)
		var scenario := ContentService.get_scenario(scenario_id)
		if scenario.is_empty():
			deferred.append("Missing battle sample scenario: %s." % scenario_id)
			continue
		var encounters: Array = scenario.get("encounters", []) if scenario.get("encounters", []) is Array else []
		if encounters.is_empty():
			deferred.append("%s has no encounter placements for battle sampling." % scenario_id)
			continue
		var sample := _run_battle_sample(scenario_id, encounters[0])
		if sample.is_empty():
			deferred.append("%s first encounter could not be sampled by current battle resolver." % scenario_id)
		else:
			samples.append(sample)
	var distribution := {}
	for sample in samples:
		var outcome := String(sample.get("outcome_state", "unknown"))
		distribution[outcome] = int(distribution.get(outcome, 0)) + 1
	if samples.size() < 3:
		warnings.append("Battle distribution sample is intentionally narrow until Phase 3 has a full headless runner.")
	var status := "warning"
	if samples.is_empty():
		status = "deferred"
	elif deferred.is_empty() and warnings.is_empty():
		status = "pass"
	return _section(
		"battle_outcome_distribution",
		status,
		{
			"sample_count": samples.size(),
			"distribution": distribution,
			"policy": "deterministic_autoplay_sample_report_only",
		},
		{
			"samples": samples,
			"distribution": distribution,
			"warnings": warnings,
			"deferred": deferred,
		},
		warnings,
		deferred
	)

static func _ai_objective_pressure(input_config: Dictionary) -> Dictionary:
	var sample_scenarios: Array = input_config.get("ai_pressure_scenarios", ["river-pass", "prismhearth-watch"])
	var cases := []
	var warnings := []
	var deferred := []
	for scenario_id_value in sample_scenarios:
		var scenario_id := String(scenario_id_value)
		var scenario := ContentService.get_scenario(scenario_id)
		if scenario.is_empty():
			deferred.append("Missing AI pressure scenario: %s." % scenario_id)
			continue
		var session = ScenarioFactoryScript.create_session(scenario_id, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
		OverworldRules.normalize_overworld_state(session)
		var enemy_configs: Array = scenario.get("enemy_factions", []) if scenario.get("enemy_factions", []) is Array else []
		for config in enemy_configs:
			if not (config is Dictionary):
				continue
			var faction_id := String(config.get("faction_id", ""))
			var origin := _enemy_origin(config)
			var resource_report := EnemyAdventureRules.resource_pressure_report(session, config, origin, faction_id, 5)
			var chosen := EnemyAdventureRules.choose_target(session, config, origin)
			var governor := EnemyTurnRules.town_governor_pressure_report(session, config, faction_id)
			var top_target_ids := []
			for target in resource_report.get("targets", []):
				if target is Dictionary:
					top_target_ids.append(String(target.get("placement_id", "")))
			if top_target_ids.is_empty() and session.overworld.get("resource_nodes", []).size() > 0:
				warnings.append("%s/%s produced no resource pressure targets." % [scenario_id, faction_id])
			cases.append({
				"scenario_id": scenario_id,
				"faction_id": faction_id,
				"origin": origin,
				"resource_target_count": int(resource_report.get("target_count", 0)),
				"top_resource_target_ids": top_target_ids,
				"chosen_target_kind": String(chosen.get("target_kind", "")),
				"chosen_target_placement_id": String(chosen.get("target_placement_id", "")),
				"town_governor_town_count": int(governor.get("town_count", 0)),
				"pressure_signature": _signature_for({
					"resource_targets": top_target_ids,
					"chosen": _target_signal(chosen),
					"town_count": int(governor.get("town_count", 0)),
				}),
			})
	var status := "pass"
	if cases.is_empty():
		status = "deferred"
	elif not warnings.is_empty() or not deferred.is_empty():
		status = "warning"
	return _section(
		"ai_objective_pressure",
		status,
		{
			"case_count": cases.size(),
			"warning_count": warnings.size(),
			"deferred_count": deferred.size(),
		},
		{
			"cases": cases,
			"warnings": warnings,
			"deferred": deferred,
		},
		warnings,
		deferred
	)

static func _save_replay_stability(input_config: Dictionary, generated_sample: Dictionary = {}) -> Dictionary:
	var checks := []
	var warnings := []
	var deferred := []
	var scenario_id := String(input_config.get("save_stability_scenario_id", "river-pass"))
	var session = ScenarioFactoryScript.create_session(scenario_id, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var payload := session.to_dict()
	var normalized := SessionStateStoreScript.normalize_payload(payload)
	var restore_result: Dictionary = SaveService._normalize_restore_result(payload, "manual")
	checks.append({
		"case_id": "authored_session_payload_normalize_restore",
		"ok": bool(restore_result.get("ok", false)),
		"scenario_id": scenario_id,
		"save_version": int(normalized.get("save_version", 0)),
		"resume_target": String(restore_result.get("resume_target", "")),
		"signature": _signature_for(_save_payload_signal(normalized)),
	})
	if not bool(restore_result.get("ok", false)):
		warnings.append("Authored session payload did not restore through SaveService.")
	var setup := ScenarioSelectRulesScript.build_random_map_skirmish_setup(_random_map_config("balance-save-replay-10184"), "normal")
	if bool(setup.get("ok", false)):
		var generated_session: SessionStateStoreScript.SessionData = ScenarioSelectRulesScript.start_random_map_skirmish_session(_random_map_config("balance-save-replay-10184"), "normal")
		var generated_payload := generated_session.to_dict()
		ContentService.clear_generated_scenario_drafts()
		var generated_restore: Dictionary = SaveService._normalize_restore_result(generated_payload, "manual")
		checks.append({
			"case_id": "generated_map_seed_config_restore",
			"ok": bool(generated_restore.get("ok", false)),
			"scenario_id": String(generated_payload.get("scenario_id", "")),
			"replay_boundary": String(generated_payload.get("flags", {}).get("generated_random_map_replay_metadata", {}).get("replay_boundary", "")),
			"provenance_signature": _signature_for(generated_payload.get("flags", {}).get("generated_random_map_provenance", {})),
			"restore_resume_target": String(generated_restore.get("resume_target", "")),
		})
		if not bool(generated_restore.get("ok", false)):
			warnings.append("Generated skirmish provenance payload did not restore.")
	else:
		deferred.append("Generated-map save/replay sample unavailable: %s" % JSON.stringify(setup.get("validation", setup)))
	var status := "pass"
	if not deferred.is_empty() or not warnings.is_empty():
		status = "warning"
	return _section(
		"save_replay_stability",
		status,
		{
			"check_count": checks.size(),
			"save_version": int(SessionStateStoreScript.SAVE_VERSION),
			"warning_count": warnings.size(),
			"deferred_count": deferred.size(),
		},
		{
			"checks": checks,
			"warnings": warnings,
			"deferred": deferred,
			"save_policy": "metadata_restore_report_only_no_save_version_bump",
		},
		warnings,
		deferred
	)

static func _run_battle_sample(scenario_id: String, encounter: Dictionary) -> Dictionary:
	var session = ScenarioFactoryScript.create_session(scenario_id, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	session.battle = BattleRules.create_battle_payload(session, encounter)
	if session.battle.is_empty():
		return {}
	var first_signature := _signature_for(_battle_signal(session.battle))
	var guard := 0
	var final_state := "continue"
	while guard < 24 and not session.battle.is_empty():
		guard += 1
		var ready_result := BattleRules.resolve_if_battle_ready(session)
		final_state = String(ready_result.get("state", "continue"))
		if final_state not in ["", "continue", "invalid"]:
			break
		if session.battle.is_empty():
			break
		var active_stack := BattleRules.get_active_stack(session.battle)
		if String(active_stack.get("side", "")) != "player":
			continue
		_select_first_living_enemy(session)
		var availability := BattleRules.action_availability(session.battle)
		var action := "defend"
		if bool(availability.get("shoot", false)):
			action = "shoot"
		elif bool(availability.get("strike", false)):
			action = "strike"
		elif bool(availability.get("advance", false)):
			action = "advance"
		var result := BattleRules.perform_player_action(session, action)
		final_state = String(result.get("state", "continue"))
		if final_state not in ["", "continue", "invalid"]:
			break
	return {
		"scenario_id": scenario_id,
		"encounter_placement_id": String(encounter.get("placement_id", "")),
		"encounter_id": String(encounter.get("encounter_id", "")),
		"turns_sampled": guard,
		"outcome_state": final_state,
		"initial_battle_signature": first_signature,
		"final_signal_signature": _signature_for({
			"state": final_state,
			"battle": _battle_signal(session.battle),
			"status": String(session.scenario_status),
		}),
	}

static func _select_first_living_enemy(session) -> void:
	for stack in session.battle.get("stacks", []):
		if not (stack is Dictionary):
			continue
		if String(stack.get("side", "")) == "enemy" and int(stack.get("count", 0)) > 0 and int(stack.get("total_health", 0)) > 0:
			BattleRules.select_target(session, String(stack.get("battle_id", "")))
			return

static func _generated_session_viability(input_config: Dictionary, generated_sample: Dictionary = {}) -> Dictionary:
	var generated := generated_sample if not generated_sample.is_empty() else _generated_map_case(input_config, "balance-scenario-viability-10184")
	if not bool(generated.get("ok", false)):
		return {
			"ok": false,
			"status": "deferred",
			"reason": "generation_failed",
			"validation": generated.get("report", {}),
		}
	var payload: Dictionary = generated.get("generated_map", {})
	var scenario: Dictionary = payload.get("scenario_record", {})
	var session: SessionStateStoreScript.SessionData = ScenarioFactoryScript.create_generated_draft_session(payload, "normal")
	OverworldRules.normalize_overworld_state(session)
	var map_size := OverworldRules.derive_map_size(session)
	ContentService.unregister_generated_scenario_draft(String(scenario.get("id", "")))
	var ok: bool = session.scenario_id == String(scenario.get("id", "")) and map_size.x > 0 and map_size.y > 0 and session.overworld.get("towns", []).size() > 0
	return {
		"ok": ok,
		"status": "pass" if ok else "warning",
		"scenario_id": String(scenario.get("id", "")),
		"template_id": String(payload.get("metadata", {}).get("template_id", "")),
		"stable_signature": String(payload.get("stable_signature", "")),
		"map_size": {"x": map_size.x, "y": map_size.y},
		"town_count": session.overworld.get("towns", []).size(),
		"resource_node_count": session.overworld.get("resource_nodes", []).size(),
		"encounter_count": session.overworld.get("encounters", []).size(),
		"write_policy": String(payload.get("write_policy", "")),
	}

static func _generated_map_case(input_config: Dictionary, seed: String) -> Dictionary:
	var config: Dictionary = input_config.get("random_map_config", {}) if input_config.get("random_map_config", {}) is Dictionary else {}
	if config.is_empty():
		config = _random_map_config(seed)
	var generator = RandomMapGeneratorRulesScript.new()
	return generator.generate(config)

static func _random_map_config(seed: String) -> Dictionary:
	return {
		"generator_version": RandomMapGeneratorRulesScript.GENERATOR_VERSION,
		"seed": seed,
		"size": {"preset": "balance_regression_report", "width": 26, "height": 18, "water_mode": "land", "level_count": 1},
		"player_constraints": {"human_count": 1, "computer_count": 2},
		"profile": {
			"id": "border_gate_compact_profile_v1",
			"template_id": "border_gate_compact_v1",
			"guard_strength_profile": "core_low",
			"faction_ids": ["faction_embercourt", "faction_mireclaw", "faction_sunvault"],
		},
	}

static func _enemy_origin(config: Dictionary) -> Dictionary:
	var spawn_points: Array = config.get("spawn_points", []) if config.get("spawn_points", []) is Array else []
	if not spawn_points.is_empty() and spawn_points[0] is Dictionary:
		return {"x": int(spawn_points[0].get("x", 0)), "y": int(spawn_points[0].get("y", 0))}
	return {"x": 0, "y": 0}

static func _target_signal(target: Dictionary) -> Dictionary:
	return {
		"target_kind": String(target.get("target_kind", "")),
		"target_placement_id": String(target.get("target_placement_id", "")),
		"target_id": String(target.get("target_id", "")),
	}

static func _save_payload_signal(payload: Dictionary) -> Dictionary:
	return {
		"save_version": int(payload.get("save_version", 0)),
		"scenario_id": String(payload.get("scenario_id", "")),
		"hero_id": String(payload.get("hero_id", "")),
		"day": int(payload.get("day", 0)),
		"launch_mode": String(payload.get("launch_mode", "")),
		"game_state": String(payload.get("game_state", "")),
		"scenario_status": String(payload.get("scenario_status", "")),
		"overworld_counts": _overworld_counts(payload.get("overworld", {})),
	}

static func _overworld_counts(overworld_value: Variant) -> Dictionary:
	var overworld: Dictionary = overworld_value if overworld_value is Dictionary else {}
	return {
		"towns": overworld.get("towns", []).size() if overworld.get("towns", []) is Array else 0,
		"resource_nodes": overworld.get("resource_nodes", []).size() if overworld.get("resource_nodes", []) is Array else 0,
		"encounters": overworld.get("encounters", []).size() if overworld.get("encounters", []) is Array else 0,
		"enemy_states": overworld.get("enemy_states", []).size() if overworld.get("enemy_states", []) is Array else 0,
	}

static func _battle_signal(battle: Dictionary) -> Dictionary:
	if battle.is_empty():
		return {}
	var side_counts := {"player": 0, "enemy": 0}
	var living_counts := {"player": 0, "enemy": 0}
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
		"active_stack_side": String(BattleRules.get_active_stack(battle).get("side", "")),
	}

static func _section(section_id: String, status: String, summary: Dictionary, evidence: Dictionary, warnings: Array, deferred: Array) -> Dictionary:
	var payload := {
		"section_id": section_id,
		"status": status,
		"summary": summary,
		"evidence": evidence,
		"warnings": warnings,
		"deferred": deferred,
	}
	payload["signature"] = _signature_for({
		"section_id": section_id,
		"status": status,
		"summary": summary,
		"evidence": evidence,
		"warnings": warnings,
		"deferred": deferred,
	})
	return payload

static func _section_signature_index(sections: Array) -> Dictionary:
	var index := {}
	for section in sections:
		if section is Dictionary:
			index[String(section.get("section_id", ""))] = String(section.get("signature", ""))
	return index

static func _content_items(path: String) -> Array:
	var raw: Dictionary = ContentService.load_json(path)
	var items: Array = raw.get("items", raw.get("entries", []))
	return items if items is Array else []

static func _items_matching(items: Array, key: String, value: String) -> Array:
	var result := []
	for item in items:
		if item is Dictionary and String(item.get(key, "")) == value:
			result.append(item)
	return result

static func _empty_resource_pool() -> Dictionary:
	var pool := {}
	for resource_id in LIVE_RESOURCE_IDS:
		pool[resource_id] = 0
	return pool

static func _resource_pool(value: Variant) -> Dictionary:
	var pool := _empty_resource_pool()
	if value is Dictionary:
		for resource_id in LIVE_RESOURCE_IDS:
			pool[resource_id] = max(0, int(value.get(resource_id, 0)))
	return pool

static func _add_scaled_cost(target: Dictionary, cost_value: Variant, scale: int) -> void:
	if not (cost_value is Dictionary):
		return
	for resource_id in LIVE_RESOURCE_IDS:
		target[resource_id] = int(target.get(resource_id, 0)) + (max(0, int(cost_value.get(resource_id, 0))) * max(0, scale))

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
	return JSON.stringify(value)

static func _hash32_hex(text: String) -> String:
	var value := 2166136261
	for index in range(text.length()):
		value = int((value ^ text.unicode_at(index)) * 16777619) & 0xffffffff
	var chars := []
	for shift in [28, 24, 20, 16, 12, 8, 4, 0]:
		chars.append(HEX_DIGITS[(value >> shift) & 0xf])
	return "".join(chars)
