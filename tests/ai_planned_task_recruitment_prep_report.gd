extends Node

const REPORT_ID := "AI_PLANNED_TASK_RECRUITMENT_PREP_REPORT"
const SCENARIO_ID := "river-pass"
const FACTION_ID := "faction_mireclaw"
const DUSKFEN := "duskfen_bastion"
const PREP_UNIT := "unit_bog_brute"
const MARKET_WOOD_UNIT := "unit_mireclaw_mudglass_slingers"
const TREASURY := {
	"gold": 16000,
	"wood": 24,
	"ore": 24,
	"aetherglass": 12,
	"embergrain": 12,
	"peatwax": 12,
	"verdant_grafts": 12,
	"brass_scrip": 12,
	"memory_salt": 12,
}

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var town_front_context_case := _town_front_development_context_reuse()
	if town_front_context_case.is_empty():
		return
	var town_build_planned_context_case := _town_build_planned_task_context_reuse()
	if town_build_planned_context_case.is_empty():
		return
	var town_build_raid_capacity_context_case := _town_build_raid_capacity_context_reuse()
	if town_build_raid_capacity_context_case.is_empty():
		return
	var destination_roster_context_case := _recruit_destination_commander_roster_context_reuse()
	if destination_roster_context_case.is_empty():
		return
	var destination_roster_invalidation_case := _recruit_destination_commander_roster_invalidation()
	if destination_roster_invalidation_case.is_empty():
		return
	var live_turn_case := _live_turn_plans_before_same_turn_recruitment()
	if live_turn_case.is_empty():
		return
	var spell_study_case := _live_enemy_turn_studies_town_spell()
	if spell_study_case.is_empty():
		return
	var task_fit_spell_study_case := _live_enemy_turn_studies_task_fit_overworld_spell()
	if task_fit_spell_study_case.is_empty():
		return
	var template_role_fallback_case := _spell_study_uses_template_role_fallback()
	if template_role_fallback_case.is_empty():
		return
	var path_cache_case := _recruitment_path_cache_preserves_live_rescoring()
	if path_cache_case.is_empty():
		return
	var planned_case := _planned_task_recruitment_prepares_commander()
	if planned_case.is_empty():
		return
	var surplus_garrison_case := _surplus_garrison_prepares_planned_commander_without_recruits()
	if surplus_garrison_case.is_empty():
		return
	var post_recruit_surplus_case := _recruitment_and_surplus_garrison_prepare_same_commander()
	if post_recruit_surplus_case.is_empty():
		return
	var unit_fit_case := _recruitment_unit_priority_follows_destination()
	if unit_fit_case.is_empty():
		return
	var market_case := _market_backed_recruitment_covers_unit_material_cost()
	if market_case.is_empty():
		return
	var garrison_case := _critical_garrison_still_wins()
	if garrison_case.is_empty():
		return
	var ready_launch_case := _prepared_saved_task_launches_below_pressure()
	if ready_launch_case.is_empty():
		return
	var passive_budget_case := _passive_generated_encounters_do_not_block_ready_launch()
	if passive_budget_case.is_empty():
		return
	var same_turn_launch_case := _prepared_saved_task_launch_moves_same_turn()
	if same_turn_launch_case.is_empty():
		return
	var unplanned_gate_case := _unplanned_low_pressure_raid_stays_blocked()
	if unplanned_gate_case.is_empty():
		return
	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_status": "planned_task_recruitment_prep_live_behavior",
		"behavior_policy": "town_building_task_fit_spell_study_template_role_fallback_and_recruitment_prepare_same_turn_saved_commander_tasks_with_destination_fit_ready_tasks_launch_below_generic_pressure_surplus_mobilization_and_phase_scoped_path_reuse",
		"save_policy": "hero_task_state_live_persist_no_save_migration",
		"cases": [town_front_context_case, town_build_planned_context_case, town_build_raid_capacity_context_case, destination_roster_context_case, destination_roster_invalidation_case, live_turn_case, spell_study_case, task_fit_spell_study_case, template_role_fallback_case, path_cache_case, planned_case, surplus_garrison_case, post_recruit_surplus_case, unit_fit_case, market_case, garrison_case, ready_launch_case, passive_budget_case, same_turn_launch_case, unplanned_gate_case],
		"save_version_before": int(SessionStateStore.SAVE_VERSION),
		"save_version_after": int(SessionStateStore.SAVE_VERSION),
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _town_front_development_context_reuse() -> Dictionary:
	var session = _base_session()
	var town := _town_by_id(session, DUSKFEN)
	if town.is_empty():
		_fail("Town-front context fixture is missing Duskfen.")
		return {}
	var direct_front := OverworldRules.town_front_state(session, town)
	var development_metrics := OverworldRules.town_development_metrics(town, session)
	var reused_front := OverworldRules.town_front_state(session, town, development_metrics)
	if direct_front != reused_front:
		_fail("Town-front development context changed exact front state: direct=%s reused=%s" % [JSON.stringify(direct_front), JSON.stringify(reused_front)])
		return {}
	var authority_before: String = JSON.stringify(session.to_dict())
	EnemyTurnRules._town_build_profile_begin(true)
	var build_context := EnemyTurnRules._town_build_score_context(session, town, _enemy_config(), FACTION_ID)
	var build_profile := EnemyTurnRules._town_build_profile_finish()
	var build_counts: Dictionary = build_profile.get("counts", {}) if build_profile.get("counts", {}) is Dictionary else {}
	if build_context.get("town_front", {}) != direct_front:
		_fail("Town-build scoring did not retain exact direct local front state: %s" % JSON.stringify(build_context))
		return {}
	if int(build_counts.get("town_score_context_count", 0)) != 1 \
			or int(build_counts.get("town_front_development_metrics_reused", 0)) != 1:
		_fail("Town-build scoring did not consume one current development payload: %s" % JSON.stringify(build_profile))
		return {}
	if JSON.stringify(session.to_dict()) != authority_before:
		_fail("Town-build front-context reuse mutated session authority.")
		return {}
	var destination_context := EnemyTurnRules._recruit_destination_static_context(session, _enemy_config(), town, FACTION_ID)
	if destination_context.get("local_front", {}) != direct_front:
		_fail("Recruit destination did not retain exact local front state: %s" % JSON.stringify(destination_context))
		return {}
	return {
		"case_id": "recruit_destination_reuses_town_development_context",
		"front_active": bool(reused_front.get("active", false)),
		"front_mode": String(reused_front.get("mode", "")),
		"battle_readiness": int(development_metrics.get("battle_readiness", 0)),
		"logistics_summary": String(development_metrics.get("logistics", {}).get("summary", "")),
		"town_build_front_exact": true,
		"town_build_context_count": int(build_counts.get("town_score_context_count", 0)),
		"town_build_front_metrics_reused": int(build_counts.get("town_front_development_metrics_reused", 0)),
		"town_build_authority_exact": true,
	}

func _town_build_planned_task_context_reuse() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	_prepare_safe_recruiting_town(session)
	_mark_contestable_resources(session)
	var state := _enemy_state(session)
	state["pressure"] = 0
	state["raid_counter"] = 0
	state["commander_counter"] = 0
	state.erase("hero_task_state")
	_update_enemy_state(session, state)
	var plan_result := EnemyAdventureRules.plan_enemy_hero_task_board(session, config, state)
	if int(plan_result.get("planned_count", 0)) < 1:
		_fail("Town-build planned-context fixture could not create planned tasks: %s" % JSON.stringify(plan_result))
		return {}
	_update_enemy_state(session, plan_result.get("state", {}))
	var towns: Array = session.overworld.get("towns", []).duplicate(true)
	var primary_index := -1
	for index in range(towns.size()):
		var town_value = towns[index]
		if town_value is Dictionary and String(town_value.get("placement_id", "")) == DUSKFEN:
			primary_index = index
			break
	if primary_index < 0:
		_fail("Town-build planned-context fixture is missing Duskfen.")
		return {}
	var secondary: Dictionary = towns[primary_index].duplicate(true)
	secondary["placement_id"] = "duskfen_build_context_secondary"
	secondary["x"] = int(secondary.get("x", 0)) + 1
	secondary["last_build_day"] = 0
	towns.append(secondary)
	session.overworld["towns"] = towns
	var town_entries := [
		{"index": primary_index, "town": towns[primary_index]},
		{"index": towns.size() - 1, "town": towns[towns.size() - 1]},
	]
	var treasury := TREASURY.duplicate(true)
	var fresh_candidates := _fresh_build_candidates(session, town_entries, towns, treasury, config)
	var explicit_shared_context := {"planned_recruitment_profile_owner": "town_build"}
	var explicit_shared_candidates := []
	explicit_shared_candidates.append_array(EnemyTurnRules._enemy_town_build_candidates(session, towns[primary_index], primary_index, treasury, config, FACTION_ID, explicit_shared_context))
	explicit_shared_candidates.append_array(EnemyTurnRules._enemy_town_build_candidates(session, towns[towns.size() - 1], towns.size() - 1, treasury, config, FACTION_ID, explicit_shared_context))
	_sort_build_candidates(explicit_shared_candidates)
	var plans_by_town: Dictionary = explicit_shared_context.get("planned_saved_plans_by_town", {}) if explicit_shared_context.get("planned_saved_plans_by_town", {}) is Dictionary else {}
	var primary_plans: Dictionary = plans_by_town.get(DUSKFEN, {}) if plans_by_town.get(DUSKFEN, {}) is Dictionary else {}
	var secondary_plans: Dictionary = plans_by_town.get("duskfen_build_context_secondary", {}) if plans_by_town.get("duskfen_build_context_secondary", {}) is Dictionary else {}
	if explicit_shared_candidates != fresh_candidates or primary_plans.is_empty() or secondary_plans.is_empty():
		_fail("Town-build planned context did not preserve distinct town-keyed saved plans: keys=%s primary=%s secondary=%s" % [JSON.stringify(plans_by_town.keys()), JSON.stringify(primary_plans), JSON.stringify(secondary_plans)])
		return {}
	var authority_before: String = JSON.stringify(session.to_dict())
	EnemyTurnRules._town_build_profile_begin(true)
	var shared_candidates := EnemyTurnRules._enemy_empire_build_candidates(session, town_entries, towns, treasury, FACTION_ID, config)
	var shared_profile := EnemyTurnRules._town_build_profile_finish()
	var counts: Dictionary = shared_profile.get("counts", {}) if shared_profile.get("counts", {}) is Dictionary else {}
	if shared_candidates != fresh_candidates:
		_fail("Town-build shared planned context changed candidate arrays: fresh=%s shared=%s" % [JSON.stringify(fresh_candidates), JSON.stringify(shared_candidates)])
		return {}
	if int(counts.get("planned_live_tasks_loaded", 0)) != 1 \
			or int(counts.get("planned_live_tasks_reused", 0)) != 1 \
			or int(counts.get("planned_path_context_loaded", 0)) != 1 \
			or int(counts.get("planned_path_context_reused", 0)) != 1:
		_fail("Town-build planned context did not load once and reuse once: %s" % JSON.stringify(shared_profile))
		return {}
	if JSON.stringify(session.to_dict()) != authority_before:
		_fail("Town-build planned-context enumeration mutated session authority.")
		return {}
	var mutated_state := _enemy_state(session)
	var task_state: Dictionary = mutated_state.get("hero_task_state", {}) if mutated_state.get("hero_task_state", {}) is Dictionary else {}
	var tasks: Array = task_state.get("tasks", []).duplicate(true) if task_state.get("tasks", []) is Array else []
	if tasks.is_empty() or not (tasks[0] is Dictionary):
		_fail("Town-build planned-context fixture lost its live planned tasks before mutation.")
		return {}
	var first_task: Dictionary = tasks[0]
	first_task["priority"] = int(first_task.get("priority", 0)) + 17
	tasks[0] = first_task
	task_state["tasks"] = tasks
	mutated_state["hero_task_state"] = task_state
	_update_enemy_state(session, mutated_state)
	secondary = towns[towns.size() - 1]
	secondary["x"] = int(secondary.get("x", 0)) + 1
	towns[towns.size() - 1] = secondary
	session.overworld["towns"] = towns
	town_entries[1] = {"index": towns.size() - 1, "town": towns[towns.size() - 1]}
	var mutated_fresh_candidates := _fresh_build_candidates(session, town_entries, towns, treasury, config)
	EnemyTurnRules._town_build_profile_begin(true)
	var second_candidates := EnemyTurnRules._enemy_empire_build_candidates(session, town_entries, towns, treasury, FACTION_ID, config)
	var second_profile := EnemyTurnRules._town_build_profile_finish()
	var second_counts: Dictionary = second_profile.get("counts", {}) if second_profile.get("counts", {}) is Dictionary else {}
	if second_candidates != mutated_fresh_candidates \
			or int(second_counts.get("planned_live_tasks_loaded", 0)) != 1 \
			or int(second_counts.get("planned_live_tasks_reused", 0)) != 1 \
			or int(second_counts.get("planned_path_context_loaded", 0)) != 1 \
			or int(second_counts.get("planned_path_context_reused", 0)) != 1:
		_fail("A fresh town-build enumeration did not reload mutated current planned context: profile=%s fresh=%s shared=%s" % [JSON.stringify(second_profile), JSON.stringify(mutated_fresh_candidates), JSON.stringify(second_candidates)])
		return {}
	return {
		"case_id": "town_build_planned_task_context_reuse",
		"town_count": town_entries.size(),
		"candidate_count": shared_candidates.size(),
		"candidate_arrays_exact": true,
		"planned_live_tasks_loaded": int(counts.get("planned_live_tasks_loaded", 0)),
		"planned_live_tasks_reused": int(counts.get("planned_live_tasks_reused", 0)),
		"planned_path_context_loaded": int(counts.get("planned_path_context_loaded", 0)),
		"planned_path_context_reused": int(counts.get("planned_path_context_reused", 0)),
		"town_saved_plan_keys": plans_by_town.keys(),
		"fresh_enumeration_reloaded": true,
		"task_and_path_mutation_reloaded": true,
		"authority_exact": true,
	}

func _town_build_raid_capacity_context_reuse() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config().duplicate(true)
	config["max_active_raids"] = 1
	_prepare_safe_recruiting_town(session)
	_remove_active_pressure_hosts(session)
	var towns: Array = session.overworld.get("towns", []).duplicate(true)
	var primary_index := -1
	for index in range(towns.size()):
		var town_value = towns[index]
		if town_value is Dictionary and String(town_value.get("placement_id", "")) == DUSKFEN:
			primary_index = index
			break
	if primary_index < 0:
		_fail("Town-build raid-capacity fixture is missing Duskfen.")
		return {}
	var capital: Dictionary = towns[primary_index].duplicate(true)
	capital["placement_id"] = "nightglass_raid_capacity_capital"
	capital["town_id"] = "town_nightglass_redoubt"
	capital["x"] = int(capital.get("x", 0)) + 1
	capital["last_build_day"] = 0
	capital["built_buildings"] = [
		"building_town_hall",
		"building_blackbranch_den",
		"building_mire_pens",
		"building_lantern_archive",
	]
	towns.append(capital)
	session.overworld["towns"] = towns
	var capital_index := towns.size() - 1
	var town_entries := [
		{"index": primary_index, "town": towns[primary_index]},
		{"index": capital_index, "town": towns[capital_index]},
	]
	var treasury := TREASURY.duplicate(true)
	var base_limit := EnemyTurnRules._max_active_raids_for_strategy(session, config, FACTION_ID)
	if base_limit < 1 or EnemyTurnRules.active_raid_count(session, FACTION_ID) != 0:
		_fail("Town-build raid-capacity fixture did not begin below a positive clean limit: limit=%d active=%d" % [base_limit, EnemyTurnRules.active_raid_count(session, FACTION_ID)])
		return {}
	var below_capacity := _town_build_raid_capacity_enumeration(
		session,
		config,
		town_entries,
		treasury,
		true,
		"below_capacity"
	)
	if below_capacity.is_empty():
		return {}
	var added_host_ids := []
	for host_index in range(base_limit):
		var host_id := "raid_capacity_context_host_%d" % host_index
		_append_active_pressure_host(session, host_id, host_index)
		added_host_ids.append(host_id)
	if EnemyTurnRules.active_raid_count(session, FACTION_ID) != base_limit:
		_fail("Town-build raid-capacity fixture did not reach its exact active-host limit after add: limit=%d active=%d" % [base_limit, EnemyTurnRules.active_raid_count(session, FACTION_ID)])
		return {}
	var at_capacity := _town_build_raid_capacity_enumeration(
		session,
		config,
		town_entries,
		treasury,
		false,
		"at_capacity_after_active_host_add"
	)
	if at_capacity.is_empty():
		return {}
	var removed_host_id := String(added_host_ids[added_host_ids.size() - 1])
	_remove_encounter(session, removed_host_id)
	if EnemyTurnRules.active_raid_count(session, FACTION_ID) != base_limit - 1:
		_fail("Town-build raid-capacity fixture did not expose fresh capacity after active-host removal.")
		return {}
	var after_remove := _town_build_raid_capacity_enumeration(
		session,
		config,
		town_entries,
		treasury,
		true,
		"below_capacity_after_active_host_remove"
	)
	if after_remove.is_empty():
		return {}
	_append_active_pressure_host(session, removed_host_id, base_limit - 1)
	var after_readd := _town_build_raid_capacity_enumeration(
		session,
		config,
		town_entries,
		treasury,
		false,
		"at_capacity_after_active_host_readd"
	)
	if after_readd.is_empty():
		return {}
	towns = session.overworld.get("towns", []).duplicate(true)
	capital = towns[capital_index].duplicate(true)
	var capital_buildings: Array = capital.get("built_buildings", []).duplicate(true) if capital.get("built_buildings", []) is Array else []
	capital_buildings.append("building_nightglass_dominion")
	capital["built_buildings"] = capital_buildings
	towns[capital_index] = capital
	session.overworld["towns"] = towns
	town_entries[1] = {"index": capital_index, "town": towns[capital_index]}
	var capital_project := OverworldRules.town_capital_project_state(capital, session)
	var expanded_limit := EnemyTurnRules._max_active_raids_for_strategy(session, config, FACTION_ID)
	if int(capital_project.get("max_active_raids_bonus", 0)) != 1 or expanded_limit != base_limit + 1:
		_fail("Town-build raid-capacity fixture did not expose the capital max-slot mutation: project=%s base=%d expanded=%d" % [JSON.stringify(capital_project), base_limit, expanded_limit])
		return {}
	var after_capital_mutation := _town_build_raid_capacity_enumeration(
		session,
		config,
		town_entries,
		treasury,
		true,
		"below_capacity_after_capital_max_slot_mutation"
	)
	if after_capital_mutation.is_empty():
		return {}
	return {
		"case_id": "town_build_raid_capacity_context_reuse",
		"town_count": town_entries.size(),
		"base_max_active_raids": base_limit,
		"expanded_max_active_raids": expanded_limit,
		"below_capacity_fresh_vs_shared_candidates_exact": true,
		"at_capacity_fresh_vs_shared_candidates_exact": true,
		"candidate_order_and_selection_exact": true,
		"load_once_reuse_once_across_two_towns": true,
		"fresh_after_active_host_add_remove": true,
		"fresh_after_capital_max_slot_mutation": true,
		"single_town_direct_authority_exact": true,
		"capital_max_active_raids_bonus": int(capital_project.get("max_active_raids_bonus", 0)),
		"enumerations": [below_capacity, at_capacity, after_remove, after_readd, after_capital_mutation],
	}

func _town_build_raid_capacity_enumeration(
	session,
	config: Dictionary,
	town_entries: Array,
	treasury: Dictionary,
	expected_available: bool,
	stage: String
) -> Dictionary:
	var towns: Array = session.overworld.get("towns", [])
	var authority_before := JSON.stringify(session.to_dict())
	var fresh_candidates := _fresh_build_candidates(session, town_entries, towns, treasury, config)
	EnemyTurnRules._town_build_profile_begin(true)
	var shared_candidates := EnemyTurnRules._enemy_empire_build_candidates(session, town_entries, towns, treasury, FACTION_ID, config)
	var shared_profile := EnemyTurnRules._town_build_profile_finish()
	var counts: Dictionary = shared_profile.get("counts", {}) if shared_profile.get("counts", {}) is Dictionary else {}
	if fresh_candidates.is_empty() or shared_candidates != fresh_candidates:
		_fail("Town-build raid-capacity %s enumeration changed exact candidate arrays/order: fresh=%s shared=%s" % [stage, JSON.stringify(fresh_candidates), JSON.stringify(shared_candidates)])
		return {}
	if shared_candidates[0] != fresh_candidates[0]:
		_fail("Town-build raid-capacity %s enumeration changed exact selected candidate." % stage)
		return {}
	if int(counts.get("raid_capacity_loaded", 0)) != 1 or int(counts.get("raid_capacity_reused", 0)) != 1:
		_fail("Town-build raid-capacity %s enumeration did not load once and reuse once across two towns: %s" % [stage, JSON.stringify(shared_profile)])
		return {}
	var primary_index := int(town_entries[0].get("index", -1))
	if primary_index < 0 or primary_index >= towns.size() or not (towns[primary_index] is Dictionary):
		_fail("Town-build raid-capacity %s enumeration lost its single-town authority fixture." % stage)
		return {}
	var primary_town: Dictionary = towns[primary_index]
	var direct_context := EnemyTurnRules._town_build_score_context(session, primary_town, config, FACTION_ID, {})
	var single_town_candidates := EnemyTurnRules._enemy_town_build_candidates(session, primary_town, -1, treasury, config, FACTION_ID, {})
	var direct_best := EnemyTurnRules._best_build_candidate(session, primary_town, treasury, config, FACTION_ID)
	if bool(direct_context.get("raid_capacity_available", not expected_available)) != expected_available \
			or single_town_candidates.is_empty() \
			or direct_best != single_town_candidates[0]:
		_fail("Town-build raid-capacity %s single-town/direct authority drifted: expected_available=%s context=%s candidates=%s best=%s" % [stage, expected_available, JSON.stringify(direct_context), JSON.stringify(single_town_candidates), JSON.stringify(direct_best)])
		return {}
	if JSON.stringify(session.to_dict()) != authority_before:
		_fail("Town-build raid-capacity %s enumeration mutated session authority." % stage)
		return {}
	return {
		"stage": stage,
		"raid_capacity_available": expected_available,
		"active_raid_count": EnemyTurnRules.active_raid_count(session, FACTION_ID),
		"candidate_count": shared_candidates.size(),
		"selected_town_id": String(shared_candidates[0].get("town_placement_id", "")),
		"selected_building_id": String(shared_candidates[0].get("building_id", "")),
		"candidate_arrays_exact": true,
		"candidate_order_exact": true,
		"selected_candidate_exact": true,
		"raid_capacity_loaded": int(counts.get("raid_capacity_loaded", 0)),
		"raid_capacity_reused": int(counts.get("raid_capacity_reused", 0)),
		"single_town_direct_authority_exact": true,
		"authority_exact": true,
	}

func _fresh_build_candidates(session, town_entries: Array, towns: Array, treasury: Dictionary, config: Dictionary) -> Array:
	var candidates := []
	for entry_value in town_entries:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var town_index := int(entry.get("index", -1))
		if town_index < 0 or town_index >= towns.size() or not (towns[town_index] is Dictionary):
			continue
		candidates.append_array(EnemyTurnRules._enemy_town_build_candidates(session, towns[town_index], town_index, treasury, config, FACTION_ID, {}))
	_sort_build_candidates(candidates)
	return candidates

func _sort_build_candidates(candidates: Array) -> void:
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_score := float(a.get("final_score", 0.0))
		var b_score := float(b.get("final_score", 0.0))
		if is_equal_approx(a_score, b_score):
			var a_town := String(a.get("town_placement_id", ""))
			var b_town := String(b.get("town_placement_id", ""))
			if a_town == b_town:
				return String(a.get("building_id", "")) < String(b.get("building_id", ""))
			return a_town < b_town
		return a_score > b_score
	)

func _recruit_destination_commander_roster_context_reuse() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	_prepare_safe_recruiting_town(session)
	_mark_contestable_resources(session)
	var state := _enemy_state(session)
	state["pressure"] = 0
	state["raid_counter"] = 0
	state["commander_counter"] = 0
	state.erase("hero_task_state")
	_update_enemy_state(session, state)
	var plan_result := EnemyAdventureRules.plan_enemy_hero_task_board(session, config, state)
	if int(plan_result.get("planned_count", 0)) < 1:
		_fail("Destination roster-context fixture could not create planned tasks: %s" % JSON.stringify(plan_result))
		return {}
	_update_enemy_state(session, plan_result.get("state", {}))
	var town := _town_by_id(session, DUSKFEN)
	var scoring_authority_before := JSON.stringify(session.to_dict())
	var normalized_roster := EnemyAdventureRules.normalize_commander_roster(
		session,
		FACTION_ID,
		EnemyAdventureRules.commander_roster_for_faction(session, FACTION_ID)
	)
	var normalized_roster_before := JSON.stringify(normalized_roster)
	var fresh_rebuild := EnemyTurnRules._best_commander_rebuild_target(session, config, FACTION_ID)
	var precomputed_rebuild := EnemyTurnRules._best_commander_rebuild_target(
		session,
		config,
		FACTION_ID,
		normalized_roster
	)
	var fresh_planned_context := {}
	var fresh_planned := EnemyTurnRules._best_planned_task_recruitment_target(
		session,
		config,
		FACTION_ID,
		town,
		fresh_planned_context
	)
	var precomputed_planned_context := {}
	var precomputed_planned := EnemyTurnRules._best_planned_task_recruitment_target(
		session,
		config,
		FACTION_ID,
		town,
		precomputed_planned_context,
		normalized_roster
	)
	if fresh_rebuild != precomputed_rebuild:
		_fail("Precomputed commander roster changed exact rebuild scoring: fresh=%s precomputed=%s" % [JSON.stringify(fresh_rebuild), JSON.stringify(precomputed_rebuild)])
		return {}
	if fresh_planned != precomputed_planned:
		_fail("Precomputed commander roster changed exact planned-task scoring: fresh=%s precomputed=%s" % [JSON.stringify(fresh_planned), JSON.stringify(precomputed_planned)])
		return {}
	var fresh_destination_context := EnemyTurnRules._recruit_destination_static_context(session, config, town, FACTION_ID, {})
	fresh_destination_context["best_rebuild"] = fresh_rebuild
	fresh_destination_context["best_planned"] = fresh_planned
	var fresh_destination := EnemyTurnRules._choose_recruit_destination_breakdown(
		session,
		config,
		town,
		FACTION_ID,
		fresh_destination_context
	)
	EnemyTurnRules._reinforcement_profile_begin(true)
	var shared_destination_context := EnemyTurnRules._recruit_destination_static_context(session, config, town, FACTION_ID, {})
	var shared_destination := EnemyTurnRules._choose_recruit_destination_breakdown(
		session,
		config,
		town,
		FACTION_ID,
		shared_destination_context
	)
	var profile := EnemyTurnRules._reinforcement_profile_finish()
	var counts: Dictionary = profile.get("counts", {}) if profile.get("counts", {}) is Dictionary else {}
	if fresh_destination != shared_destination:
		_fail("Shared commander roster changed the full destination payload: fresh=%s shared=%s" % [JSON.stringify(fresh_destination), JSON.stringify(shared_destination)])
		return {}
	if int(counts.get("destination_commander_roster_loaded", 0)) != 1 \
			or int(counts.get("destination_commander_roster_shared_between_scorers", 0)) != 1:
		_fail("Destination scoring did not load one roster and share it across rebuild/planned scorers: %s" % JSON.stringify(profile))
		return {}
	if not (shared_destination_context.get("normalized_commander_roster", null) is Array):
		_fail("Destination scoring did not retain its normalized commander roster context.")
		return {}
	if JSON.stringify(normalized_roster) != normalized_roster_before:
		_fail("Destination scorers mutated the shared normalized commander roster.")
		return {}
	if JSON.stringify(session.to_dict()) != scoring_authority_before:
		_fail("Fresh/precomputed destination scoring mutated session authority.")
		return {}
	return {
		"case_id": "recruit_destination_commander_roster_context_reuse",
		"rebuild_scoring_exact": true,
		"planned_scoring_exact": true,
		"full_destination_exact": true,
		"destination_type": String(shared_destination.get("type", "")),
		"destination_actor_id": String(shared_destination.get("roster_hero_id", "")),
		"normalized_roster_count": normalized_roster.size(),
		"destination_commander_roster_loaded": int(counts.get("destination_commander_roster_loaded", 0)),
		"destination_commander_roster_shared_between_scorers": int(counts.get("destination_commander_roster_shared_between_scorers", 0)),
		"scoring_authority_exact": true,
	}

func _recruit_destination_commander_roster_invalidation() -> Dictionary:
	var field_case := _planned_and_rebuild_roster_invalidation()
	if field_case.is_empty():
		return {}
	var raid_case := _raid_roster_invalidation()
	if raid_case.is_empty():
		return {}
	var garrison_case := _garrison_only_roster_retention()
	if garrison_case.is_empty():
		return {}
	return {
		"case_id": "recruit_destination_commander_roster_invalidation_and_retention",
		"planned": field_case.get("planned", {}),
		"rebuild": field_case.get("rebuild", {}),
		"raid": raid_case,
		"garrison": garrison_case,
	}

func _planned_and_rebuild_roster_invalidation() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	_prepare_safe_recruiting_town(session)
	_mark_contestable_resources(session)
	var state := _enemy_state(session)
	state["pressure"] = 0
	state["raid_counter"] = 0
	state["commander_counter"] = 0
	state.erase("hero_task_state")
	_update_enemy_state(session, state)
	var plan_result := EnemyAdventureRules.plan_enemy_hero_task_board(session, config, state)
	if int(plan_result.get("planned_count", 0)) < 1:
		_fail("Roster invalidation fixture could not create planned tasks: %s" % JSON.stringify(plan_result))
		return {}
	_update_enemy_state(session, plan_result.get("state", {}))
	var town := _town_by_id(session, DUSKFEN)
	var destination_context := EnemyTurnRules._recruit_destination_static_context(session, config, town, FACTION_ID, {})
	var planned_before := EnemyTurnRules._choose_recruit_destination_breakdown(session, config, town, FACTION_ID, destination_context)
	if String(planned_before.get("type", "")) != "planned" or not (destination_context.get("normalized_commander_roster", null) is Array):
		_fail("Roster invalidation fixture did not cache a planned destination: %s" % JSON.stringify(planned_before))
		return {}
	var planned_actor_id := String(planned_before.get("roster_hero_id", ""))
	var planned_accepted := EnemyAdventureRules.reinforce_commander_roster_army(
		session,
		FACTION_ID,
		planned_actor_id,
		"unit_mire_slinger",
		1,
		String(planned_before.get("base_encounter_id", "")),
		int(planned_before.get("target_strength", 0))
	)
	if planned_accepted != 1:
		_fail("Roster invalidation fixture could not apply a real planned reinforcement: actor=%s accepted=%d" % [planned_actor_id, planned_accepted])
		return {}
	EnemyTurnRules._invalidate_recruit_destination_field_cache(destination_context)
	if destination_context.has("normalized_commander_roster"):
		_fail("Successful planned reinforcement retained a stale normalized commander roster.")
		return {}
	var planned_rescored := EnemyTurnRules._choose_recruit_destination_breakdown(session, config, town, FACTION_ID, destination_context)
	var planned_fresh_current := EnemyTurnRules._choose_recruit_destination_breakdown(session, config, town, FACTION_ID)
	if planned_rescored != planned_fresh_current:
		_fail("Planned reinforcement did not rescore from exact fresh current authority: cached=%s fresh=%s" % [JSON.stringify(planned_rescored), JSON.stringify(planned_fresh_current)])
		return {}
	if String(planned_rescored.get("type", "")) != "rebuild":
		_fail("Planned reinforcement fixture did not expose the real rebuild follow-up: %s" % JSON.stringify(planned_rescored))
		return {}
	var rebuild_actor_id := String(planned_rescored.get("roster_hero_id", ""))
	var rebuild_accepted := EnemyAdventureRules.reinforce_commander_roster_army(
		session,
		FACTION_ID,
		rebuild_actor_id,
		"unit_mire_slinger",
		1,
		String(planned_rescored.get("base_encounter_id", "")),
		int(planned_rescored.get("target_strength", 0))
	)
	if rebuild_accepted != 1:
		_fail("Roster invalidation fixture could not apply a real rebuild reinforcement: actor=%s accepted=%d" % [rebuild_actor_id, rebuild_accepted])
		return {}
	EnemyTurnRules._invalidate_recruit_destination_field_cache(destination_context)
	if destination_context.has("normalized_commander_roster"):
		_fail("Successful rebuild reinforcement retained a stale normalized commander roster.")
		return {}
	var rebuild_rescored := EnemyTurnRules._choose_recruit_destination_breakdown(session, config, town, FACTION_ID, destination_context)
	var rebuild_fresh_current := EnemyTurnRules._choose_recruit_destination_breakdown(session, config, town, FACTION_ID)
	if rebuild_rescored != rebuild_fresh_current:
		_fail("Rebuild reinforcement did not rescore from exact fresh current authority: cached=%s fresh=%s" % [JSON.stringify(rebuild_rescored), JSON.stringify(rebuild_fresh_current)])
		return {}
	return {
		"planned": {
			"successful_reinforcement": planned_accepted,
			"actor_id": planned_actor_id,
			"stale_roster_evicted": true,
			"fresh_current_rescore_exact": true,
			"destination_after": String(planned_rescored.get("type", "")),
		},
		"rebuild": {
			"successful_reinforcement": rebuild_accepted,
			"actor_id": rebuild_actor_id,
			"stale_roster_evicted": true,
			"fresh_current_rescore_exact": true,
			"destination_after": String(rebuild_rescored.get("type", "")),
		},
	}

func _raid_roster_invalidation() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	_prepare_safe_recruiting_town(session)
	var state := _enemy_state(session)
	state["pressure"] = 0
	state["raid_counter"] = 0
	state["commander_counter"] = 0
	state.erase("hero_task_state")
	_update_enemy_state(session, state)
	var spawn_points: Array = config.get("spawn_points", []) if config.get("spawn_points", []) is Array else []
	if spawn_points.is_empty() or not (spawn_points[0] is Dictionary):
		_fail("Raid roster invalidation fixture has no authored spawn point.")
		return {}
	var spawn_point: Dictionary = spawn_points[0]
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append({
		"placement_id": "recruitment_roster_cache_probe_raid",
		"encounter_id": "encounter_mire_raid",
		"spawned_by_faction_id": FACTION_ID,
		"x": int(spawn_point.get("x", 0)),
		"y": int(spawn_point.get("y", 0)),
		"target_kind": "resource",
		"target_placement_id": "river_free_company",
		"enemy_army": {
			"id": "recruitment_roster_cache_probe_army",
			"name": "Roster Cache Probe",
			"stacks": [{"unit_id": "unit_bog_brute", "count": 1}],
		},
	})
	session.overworld["encounters"] = encounters
	var town := _town_by_id(session, DUSKFEN)
	var destination_context := EnemyTurnRules._recruit_destination_static_context(session, config, town, FACTION_ID, {})
	var raid_before := EnemyTurnRules._choose_recruit_destination_breakdown(session, config, town, FACTION_ID, destination_context)
	if String(raid_before.get("type", "")) != "raid" or not (destination_context.get("normalized_commander_roster", null) is Array):
		_fail("Raid roster invalidation fixture did not cache the understrength raid destination: %s" % JSON.stringify(raid_before))
		return {}
	var raid_need_before := int(raid_before.get("raid_need", 0))
	var accepted := EnemyTurnRules._apply_reinforcement_to_raid(
		session,
		int(raid_before.get("index", -1)),
		"unit_mire_slinger",
		1
	)
	if accepted != 1:
		_fail("Raid roster invalidation fixture could not apply a real raid reinforcement: accepted=%d" % accepted)
		return {}
	EnemyTurnRules._invalidate_recruit_destination_field_cache(destination_context)
	if destination_context.has("normalized_commander_roster"):
		_fail("Successful raid reinforcement retained a stale normalized commander roster.")
		return {}
	var raid_rescored := EnemyTurnRules._choose_recruit_destination_breakdown(session, config, town, FACTION_ID, destination_context)
	var raid_fresh_current := EnemyTurnRules._choose_recruit_destination_breakdown(session, config, town, FACTION_ID)
	if raid_rescored != raid_fresh_current:
		_fail("Raid reinforcement did not rescore from exact fresh current authority: cached=%s fresh=%s" % [JSON.stringify(raid_rescored), JSON.stringify(raid_fresh_current)])
		return {}
	if int(raid_rescored.get("raid_need", 0)) >= raid_need_before:
		_fail("Fresh raid rescore did not consume current reinforced army strength: before=%d after=%d" % [raid_need_before, int(raid_rescored.get("raid_need", 0))])
		return {}
	return {
		"successful_reinforcement": accepted,
		"placement_id": "recruitment_roster_cache_probe_raid",
		"stale_roster_evicted": true,
		"fresh_current_rescore_exact": true,
		"raid_need_before": raid_need_before,
		"raid_need_after": int(raid_rescored.get("raid_need", 0)),
	}

func _garrison_only_roster_retention() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	_prepare_critical_recruiting_town(session)
	_mark_contestable_resources(session)
	var state := _enemy_state(session)
	state.erase("hero_task_state")
	_update_enemy_state(session, state)
	var plan_result := EnemyAdventureRules.plan_enemy_hero_task_board(session, config, state)
	_update_enemy_state(session, plan_result.get("state", {}))
	var town := _town_by_id(session, DUSKFEN)
	EnemyTurnRules._reinforcement_profile_begin(true)
	var recruit_result := EnemyTurnRules._recruit_town_forces(session, config, town, TREASURY.duplicate(true), FACTION_ID)
	var profile := EnemyTurnRules._reinforcement_profile_finish()
	var counts: Dictionary = profile.get("counts", {}) if profile.get("counts", {}) is Dictionary else {}
	if not bool(recruit_result.get("garrisoned", false)) or int(recruit_result.get("planned_batches", 0)) != 0 \
			or int(recruit_result.get("rebuild_batches", 0)) != 0 or int(recruit_result.get("raid_batches", 0)) != 0:
		_fail("Garrison-only cache-retention fixture delivered a field reinforcement: %s" % JSON.stringify(recruit_result))
		return {}
	if int(counts.get("destination_commander_roster_loaded", 0)) != 1 \
			or int(counts.get("destination_commander_roster_shared_between_scorers", 0)) != 1 \
			or int(counts.get("destination_commander_roster_invalidated", 0)) != 0:
		_fail("Garrison-only delivery did not retain its bounded roster context: %s" % JSON.stringify(profile))
		return {}
	return {
		"garrisoned": true,
		"field_batches": 0,
		"destination_commander_roster_loaded": int(counts.get("destination_commander_roster_loaded", 0)),
		"destination_commander_roster_shared_between_scorers": int(counts.get("destination_commander_roster_shared_between_scorers", 0)),
		"destination_commander_roster_invalidated": int(counts.get("destination_commander_roster_invalidated", 0)),
		"bounded_roster_retained": true,
	}

func _live_turn_plans_before_same_turn_recruitment() -> Dictionary:
	var session = _base_session()
	_set_enemy_treasury(session, TREASURY)
	_prepare_safe_recruiting_town(session)
	_mark_contestable_resources(session)
	var state := _enemy_state(session)
	state["pressure"] = 0
	state["raid_counter"] = 0
	state["commander_counter"] = 0
	state.erase("hero_task_state")
	_update_enemy_state(session, state)
	var active_before := _active_raid_count(session)
	if active_before != 0:
		_fail("Expected no active raids before same-turn prep case, got %d" % active_before)
		return {}
	var result := EnemyTurnRules.run_enemy_turn(session)
	var events: Array = result.get("events", []) if result.get("events", []) is Array else []
	var planned_index := _event_index(events, "ai_commander_task_planned")
	var build_index := _event_index(events, "ai_town_built")
	var prepared_index := _event_index(events, "ai_commander_prepared")
	if planned_index < 0:
		_fail("Live turn did not emit same-turn task planning: %s" % JSON.stringify(_event_types(events)))
		return {}
	if build_index < 0:
		_fail("Live turn did not build after same-turn task planning: %s" % JSON.stringify(_event_types(events)))
		return {}
	if prepared_index < 0:
		_fail("Live turn did not prepare a commander from newly planned tasks: %s" % JSON.stringify(_event_types(events)))
		return {}
	if planned_index > build_index or build_index > prepared_index:
		_fail("Live turn should plan before build and build before recruitment prep: %s" % JSON.stringify(_event_types(events)))
		return {}
	var build_event: Dictionary = events[build_index]
	var build_reason_codes: Array = _string_array(build_event.get("target_reason_codes", []))
	if build_reason_codes.is_empty():
		build_reason_codes = _string_array(build_event.get("reason_codes", []))
	if "prepares_commander_task" not in build_reason_codes:
		_fail("Same-turn build did not expose planned-task preparation reason codes: %s" % JSON.stringify(build_event))
		return {}
	var prepared_event: Dictionary = events[prepared_index]
	var actor_id := String(prepared_event.get("target_id", ""))
	if actor_id == "":
		_fail("Prepared event missing commander target id: %s" % JSON.stringify(prepared_event))
		return {}
	var continuity := _commander_continuity(session, actor_id)
	if int(continuity.get("current_strength", 0)) <= 0:
		_fail("Prepared commander did not gain same-turn continuity: actor=%s continuity=%s" % [actor_id, JSON.stringify(continuity)])
		return {}
	if not _has_task_for_actor(_enemy_state(session), actor_id):
		_fail("Prepared commander has no task-board record after live turn: actor=%s" % actor_id)
		return {}
	if EnemyTurnRules._post_raid_task_replan_required(0, ["hero_sable", "hero_vaska"], ["hero_sable", "hero_vaska"]):
		_fail("No-active-raid turn with an unchanged deployable commander set should skip duplicate post-raid planning.")
		return {}
	if not EnemyTurnRules._post_raid_task_replan_required(1, ["hero_sable"], ["hero_sable"]):
		_fail("An active raid must preserve full post-raid task reconciliation.")
		return {}
	if not EnemyTurnRules._post_raid_task_replan_required(0, ["hero_sable"], ["hero_sable", "hero_vaska"]):
		_fail("A newly deployable commander must preserve post-raid task planning.")
		return {}
	return {
		"case_id": "live_turn_plans_before_same_turn_recruitment",
		"active_raids_before": active_before,
		"prepared_actor_id": actor_id,
		"prepared_strength": int(continuity.get("current_strength", 0)),
		"idle_post_raid_plan_policy": "skip_when_no_active_raid_and_deployable_set_unchanged",
		"planned_event_index": planned_index,
		"build_event_index": build_index,
		"prepared_event_index": prepared_index,
		"build_reason_codes": build_reason_codes,
		"event_types": _event_types(events),
	}

func _live_enemy_turn_studies_town_spell() -> Dictionary:
	var session = _base_session()
	_set_enemy_treasury(session, TREASURY)
	_prepare_spell_study_town(session)
	var before_state := _enemy_state(session)
	before_state["pressure"] = 0
	before_state["raid_counter"] = 0
	before_state["commander_counter"] = 0
	before_state.erase("hero_task_state")
	_update_enemy_state(session, before_state)
	var before_known := _known_spell_count_by_commander(session)
	var accessible := TownRules.accessible_spell_ids(_town_by_id(session, DUSKFEN))
	if accessible.is_empty():
		_fail("Spell-study fixture town has no accessible spells.")
		return {}
	var result := EnemyTurnRules.run_enemy_turn(session)
	var events: Array = result.get("events", []) if result.get("events", []) is Array else []
	var study_event := _event_by_type(events, "ai_commander_studied_spell")
	if study_event.is_empty():
		_fail("Live enemy turn did not emit town spell study: %s" % JSON.stringify(_event_types(events)))
		return {}
	var actor_id := String(study_event.get("actor_id", ""))
	var learned_spell_id := String(study_event.get("learned_spell_id", ""))
	if actor_id == "" or learned_spell_id == "":
		_fail("Spell-study event missing actor or learned spell id: %s" % JSON.stringify(study_event))
		return {}
	if learned_spell_id not in accessible:
		_fail("Enemy commander learned a spell not accessible in the source town: spell=%s accessible=%s" % [learned_spell_id, JSON.stringify(accessible)])
		return {}
	var after_state := _commander_state(session, actor_id)
	if after_state.is_empty():
		_fail("Could not find commander after spell study: actor=%s" % actor_id)
		return {}
	if not SpellRules.knows_spell(after_state, learned_spell_id):
		_fail("Learned spell did not persist in commander spellbook: actor=%s spell=%s state=%s" % [actor_id, learned_spell_id, JSON.stringify(after_state.get("spellbook", {}))])
		return {}
	var after_known_count := _known_spell_count(after_state)
	if after_known_count <= int(before_known.get(actor_id, 0)):
		_fail("Commander known-spell count did not increase: actor=%s before=%d after=%d" % [actor_id, int(before_known.get(actor_id, 0)), after_known_count])
		return {}
	return {
		"case_id": "live_enemy_turn_studies_town_spell",
		"actor_id": actor_id,
		"learned_spell_id": learned_spell_id,
		"accessible_spell_count": accessible.size(),
		"known_spells_before": int(before_known.get(actor_id, 0)),
		"known_spells_after": after_known_count,
		"event_types": _event_types(events),
	}

func _live_enemy_turn_studies_task_fit_overworld_spell() -> Dictionary:
	var session = _base_session()
	_set_enemy_treasury(session, TREASURY)
	_prepare_spell_study_town(session)
	var accessible := TownRules.accessible_spell_ids(_town_by_id(session, DUSKFEN))
	var accessible_overworld := _spell_ids_with_context(accessible, "overworld")
	var accessible_battle := _spell_ids_with_context(accessible, "battle")
	if accessible_overworld.is_empty() or accessible_battle.is_empty():
		_fail("Task-fit spell-study fixture needs both overworld and battle spells: accessible=%s" % JSON.stringify(accessible))
		return {}
	var actor_id := "hero_sable"
	var before_state := _enemy_state(session)
	before_state["pressure"] = 0
	before_state["raid_counter"] = 0
	before_state["commander_counter"] = 0
	before_state["hero_task_state"] = {
		"schema_version": 1,
		"planner_epoch": 1,
		"tasks": [
			{
				"task_id": "test_task_fit_spell_study_explore",
				"owner_faction_id": FACTION_ID,
				"actor_kind": "commander_roster",
				"actor_id": actor_id,
				"task_class": "scout_frontier",
				"task_status": "planned",
				"target_kind": "explore",
				"target_id": "explore:5:5",
				"target_x": 5,
				"target_y": 5,
				"priority_reason_codes": ["strategic_task_planner", "exploration"],
				"assigned_day": int(session.day),
				"expires_day": int(session.day) + 10,
			},
		],
	}
	_update_enemy_state(session, before_state)
	var result := EnemyTurnRules.run_enemy_turn(session)
	var events: Array = result.get("events", []) if result.get("events", []) is Array else []
	var study_event := _event_by_type(events, "ai_commander_studied_spell")
	if study_event.is_empty():
		_fail("Task-fit spell-study turn did not emit town spell study: %s" % JSON.stringify(_event_types(events)))
		return {}
	var studied_actor_id := String(study_event.get("actor_id", ""))
	var learned_spell_id := String(study_event.get("learned_spell_id", ""))
	if studied_actor_id != actor_id:
		_fail("Exploration task-fit spell study used wrong commander: expected=%s event=%s" % [actor_id, JSON.stringify(study_event)])
		return {}
	if String(ContentService.get_spell(learned_spell_id).get("context", "")) != "overworld":
		_fail("Exploration commander should study an overworld spell, learned=%s event=%s" % [learned_spell_id, JSON.stringify(study_event)])
		return {}
	var role := String(ContentService.get_spell(learned_spell_id).get("primary_role", ""))
	if role.find("movement") < 0 and role.find("scout") < 0:
		_fail("Exploration commander learned overworld spell without movement/scouting role: spell=%s role=%s" % [learned_spell_id, role])
		return {}
	var after_state := _commander_state(session, actor_id)
	if not SpellRules.knows_spell(after_state, learned_spell_id):
		_fail("Task-fit learned spell did not persist in commander spellbook: actor=%s spell=%s" % [actor_id, learned_spell_id])
		return {}
	return {
		"case_id": "live_enemy_turn_task_fit_spell_study_prefers_overworld",
		"actor_id": actor_id,
		"task_kind": "explore",
		"learned_spell_id": learned_spell_id,
		"learned_spell_context": "overworld",
		"learned_spell_role": role,
		"accessible_overworld_spell_count": accessible_overworld.size(),
		"accessible_battle_spell_count": accessible_battle.size(),
		"event_types": _event_types(events),
	}

func _spell_study_uses_template_role_fallback() -> Dictionary:
	var session = _base_session()
	_prepare_spell_study_town(session)
	var town := _town_by_id(session, DUSKFEN)
	var spell := ContentService.get_spell("spell_briar_bind")
	if spell.is_empty():
		_fail("Template-role fallback fixture is missing spell_briar_bind.")
		return {}
	var minimal_commander := {
		"roster_hero_id": "hero_sable",
		"command": {"power": 2, "knowledge": 8},
		"spellbook": {"known_spell_ids": [], "mana": {"current": 24, "max": 24}},
	}
	var baseline_commander := minimal_commander.duplicate(true)
	baseline_commander["command_path"] = "magic"
	baseline_commander["archetype"] = "generic"
	var task := {"target_kind": "hero", "target_id": "hero_lyra"}
	var config := _enemy_config()
	var template_score := EnemyTurnRules._enemy_spell_study_score(
		spell,
		minimal_commander,
		{"roster_hero_id": "hero_sable"},
		task,
		config,
		town
	)
	var baseline_score := EnemyTurnRules._enemy_spell_study_score(
		spell,
		baseline_commander,
		{"roster_hero_id": "hero_sable"},
		task,
		config,
		town
	)
	if template_score <= baseline_score:
		_fail("Template-role fallback should raise hexcaller control-spell study score: template=%0.2f baseline=%0.2f" % [template_score, baseline_score])
		return {}
	return {
		"case_id": "spell_study_uses_template_role_fallback",
		"actor_id": "hero_sable",
		"template_archetype": String(ContentService.get_hero("hero_sable").get("archetype", "")),
		"spell_id": "spell_briar_bind",
		"spell_role": String(spell.get("primary_role", "")),
		"baseline_score": baseline_score,
		"template_fallback_score": template_score,
		"score_delta": template_score - baseline_score,
	}

func _planned_task_recruitment_prepares_commander() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	_set_enemy_treasury(session, TREASURY)
	_prepare_safe_recruiting_town(session)
	_mark_contestable_resources(session)
	var state := _enemy_state(session)
	state["pressure"] = 0
	state["raid_counter"] = 0
	state["commander_counter"] = 0
	state.erase("hero_task_state")
	_update_enemy_state(session, state)

	var plan_result := EnemyAdventureRules.plan_enemy_hero_task_board(session, config, state)
	if int(plan_result.get("planned_count", 0)) < 1:
		_fail("Expected planned tasks before recruitment prep, got %s" % JSON.stringify(plan_result))
		return {}
	_update_enemy_state(session, plan_result.get("state", {}))
	var town := _town_by_id(session, DUSKFEN)
	var destination := EnemyTurnRules._choose_recruit_destination_breakdown(session, config, town, FACTION_ID)
	if String(destination.get("type", "")) != "planned":
		_fail("Expected planned-task recruitment destination, got %s" % JSON.stringify(destination))
		return {}
	var actor_id := String(destination.get("roster_hero_id", ""))
	var before_strength := _commander_strength(session, actor_id)
	var treasury := TREASURY.duplicate(true)
	EnemyTurnRules._reinforcement_profile_begin(true)
	var recruit_result := EnemyTurnRules._recruit_town_forces(session, config, town, treasury, FACTION_ID)
	var recruit_profile := EnemyTurnRules._reinforcement_profile_finish()
	var recruit_counts: Dictionary = recruit_profile.get("counts", {}) if recruit_profile.get("counts", {}) is Dictionary else {}
	if int(recruit_result.get("planned_batches", 0)) < 1:
		_fail("Expected planned recruitment batch, got %s" % JSON.stringify(recruit_result))
		return {}
	if int(recruit_counts.get("destination_commander_roster_invalidated", 0)) < 1:
		_fail("Real planned recruitment did not invalidate its destination roster context: %s" % JSON.stringify(recruit_profile))
		return {}
	var after_strength := _commander_strength(session, actor_id)
	if after_strength <= before_strength:
		_fail("Planned recruitment did not increase commander continuity: before=%d after=%d actor=%s" % [before_strength, after_strength, actor_id])
		return {}
	var prepared_event := _event_by_type(recruit_result.get("events", []), "ai_commander_prepared")
	if prepared_event.is_empty():
		_fail("Planned recruitment did not emit ai_commander_prepared: %s" % JSON.stringify(recruit_result.get("events", [])))
		return {}
	return {
		"case_id": "safe_town_prepares_saved_task_commander",
		"destination": destination,
		"actor_id": actor_id,
		"before_strength": before_strength,
		"after_strength": after_strength,
		"planned_batches": int(recruit_result.get("planned_batches", 0)),
		"destination_commander_roster_invalidated": int(recruit_counts.get("destination_commander_roster_invalidated", 0)),
		"event_type": String(prepared_event.get("event_type", "")),
	}

func _recruitment_path_cache_preserves_live_rescoring() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	_prepare_safe_recruiting_town(session)
	_mark_contestable_resources(session)
	var state := _enemy_state(session)
	state["pressure"] = 0
	state["raid_counter"] = 0
	state["commander_counter"] = 0
	state.erase("hero_task_state")
	_update_enemy_state(session, state)
	var plan_result := EnemyAdventureRules.plan_enemy_hero_task_board(session, config, state)
	if int(plan_result.get("planned_count", 0)) < 1:
		_fail("Path-cache fixture could not create planned tasks: %s" % JSON.stringify(plan_result))
		return {}
	_update_enemy_state(session, plan_result.get("state", {}))
	var town := _town_by_id(session, DUSKFEN)
	var faction_context := {}
	EnemyTurnRules._reinforcement_profile_begin(true)
	var destination_context := EnemyTurnRules._recruit_destination_static_context(
		session,
		config,
		town,
		FACTION_ID,
		faction_context
	)
	var first_planned := EnemyTurnRules._choose_recruit_destination_breakdown(
		session,
		config,
		town,
		FACTION_ID,
		destination_context
	)
	EnemyTurnRules._invalidate_recruit_destination_field_cache(destination_context)
	var second_planned := EnemyTurnRules._choose_recruit_destination_breakdown(
		session,
		config,
		town,
		FACTION_ID,
		destination_context
	)
	if String(first_planned.get("type", "")) != "planned":
		_fail("Path-cache fixture did not select planned recruitment: %s" % JSON.stringify(first_planned))
		return {}
	if JSON.stringify(first_planned) != JSON.stringify(second_planned):
		_fail("Planned destination changed when immutable path state was reused: first=%s second=%s" % [JSON.stringify(first_planned), JSON.stringify(second_planned)])
		return {}
	var actor_id := String(first_planned.get("roster_hero_id", ""))
	var cached_plans_by_town: Dictionary = faction_context.get("planned_saved_plans_by_town", {})
	var cached_plans_by_actor: Dictionary = cached_plans_by_town.get(DUSKFEN, {})
	var actor_plan_before: Dictionary = cached_plans_by_actor.get(actor_id, {}).duplicate(true)
	var actor_strength_before := _commander_strength(session, actor_id)
	var accepted := EnemyAdventureRules.reinforce_commander_roster_army(
		session,
		FACTION_ID,
		actor_id,
		"unit_mire_slinger",
		1,
		String(first_planned.get("base_encounter_id", "")),
		int(first_planned.get("target_strength", 0))
	)
	if accepted != 1:
		_fail("Path-cache fixture could not apply one live commander reinforcement: actor=%s accepted=%d" % [actor_id, accepted])
		return {}
	var actor_strength_after := _commander_strength(session, actor_id)
	if actor_strength_after <= actor_strength_before:
		_fail("Live commander reinforcement did not update roster strength: before=%d after=%d" % [actor_strength_before, actor_strength_after])
		return {}
	var rescored_planned_target := EnemyTurnRules._best_planned_task_recruitment_target(
		session,
		config,
		FACTION_ID,
		town,
		faction_context
	)
	cached_plans_by_town = faction_context.get("planned_saved_plans_by_town", {})
	cached_plans_by_actor = cached_plans_by_town.get(DUSKFEN, {})
	var actor_plan_after: Dictionary = cached_plans_by_actor.get(actor_id, {})
	if actor_plan_before.is_empty() or JSON.stringify(actor_plan_before) != JSON.stringify(actor_plan_after):
		_fail("Live strength rescore changed Brakka's immutable cached route: before=%s after=%s" % [JSON.stringify(actor_plan_before), JSON.stringify(actor_plan_after)])
		return {}
	if String(rescored_planned_target.get("roster_hero_id", "")) == actor_id:
		_fail("Live planned-task scoring did not react to Brakka's changed strength: %s" % JSON.stringify(rescored_planned_target))
		return {}
	EnemyTurnRules._invalidate_recruit_destination_field_cache(destination_context)
	var rescored_destination := EnemyTurnRules._choose_recruit_destination_breakdown(
		session,
		config,
		town,
		FACTION_ID,
		destination_context
	)
	if String(rescored_destination.get("type", "")) != "rebuild":
		_fail("Live destination arbitration did not react to changed commander strength: %s" % JSON.stringify(rescored_destination))
		return {}
	var spawn_points: Array = config.get("spawn_points", []) if config.get("spawn_points", []) is Array else []
	if spawn_points.is_empty() or not (spawn_points[0] is Dictionary):
		_fail("Path-cache fixture has no authored spawn point.")
		return {}
	var spawn_point: Dictionary = spawn_points[0]
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append({
		"placement_id": "recruitment_path_cache_probe_raid",
		"encounter_id": "encounter_mire_raid",
		"spawned_by_faction_id": FACTION_ID,
		"x": int(spawn_point.get("x", 0)),
		"y": int(spawn_point.get("y", 0)),
		"target_kind": "resource",
		"target_placement_id": "river_free_company",
		"enemy_army": {
			"id": "recruitment_path_cache_probe_army",
			"name": "Path Cache Probe",
			"stacks": [{"unit_id": "unit_bog_brute", "count": 1}],
		},
	})
	session.overworld["encounters"] = encounters
	var first_raid := EnemyTurnRules._best_raid_reinforcement_target(
		session,
		config,
		FACTION_ID,
		town,
		faction_context
	)
	var second_raid := EnemyTurnRules._best_raid_reinforcement_target(
		session,
		config,
		FACTION_ID,
		town,
		faction_context
	)
	var reinforcement_profile := EnemyTurnRules._reinforcement_profile_finish()
	var counts: Dictionary = reinforcement_profile.get("counts", {})
	if String(first_raid.get("encounter", {}).get("placement_id", "")) != "recruitment_path_cache_probe_raid":
		_fail("Path-cache fixture did not select the understrength raid: %s" % JSON.stringify(first_raid))
		return {}
	if JSON.stringify(first_raid) != JSON.stringify(second_raid):
		_fail("Raid reinforcement destination changed when route context was reused: first=%s second=%s" % [JSON.stringify(first_raid), JSON.stringify(second_raid)])
		return {}
	for loaded_key in ["planned_live_tasks_loaded", "planned_path_context_loaded", "planned_saved_plan_loaded", "raid_route_context_loaded"]:
		if int(counts.get(loaded_key, 0)) < 1:
			_fail("Path-cache profile did not load %s: %s" % [loaded_key, JSON.stringify(reinforcement_profile)])
			return {}
	for reused_key in ["planned_live_tasks_reused", "planned_path_context_reused", "planned_saved_plan_reused", "raid_route_context_reused"]:
		if int(counts.get(reused_key, 0)) < 1:
			_fail("Path-cache profile did not reuse %s: %s" % [reused_key, JSON.stringify(reinforcement_profile)])
			return {}
	return {
		"case_id": "recruitment_path_cache_preserves_live_rescoring",
		"planned_actor_id": String(first_planned.get("roster_hero_id", "")),
		"planned_target_id": String(first_planned.get("target_id", "")),
		"planned_score": float(first_planned.get("planned_score", 0.0)),
		"actor_strength_before": actor_strength_before,
		"actor_strength_after": actor_strength_after,
		"best_planned_actor_after_live_reinforcement": String(rescored_planned_target.get("roster_hero_id", "")),
		"best_planned_target_after_live_reinforcement": String(rescored_planned_target.get("target_id", "")),
		"destination_after_live_reinforcement": String(rescored_destination.get("type", "")),
		"raid_placement_id": String(first_raid.get("encounter", {}).get("placement_id", "")),
		"raid_need": int(first_raid.get("need", 0)),
		"raid_supply_distance": int(first_raid.get("supply_distance", 0)),
		"profile_counts": counts,
	}

func _surplus_garrison_prepares_planned_commander_without_recruits() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	_set_enemy_treasury(session, {
		"gold": 0,
		"wood": 0,
		"ore": 0,
		"aetherglass": 0,
		"embergrain": 0,
		"peatwax": 0,
		"verdant_grafts": 0,
		"brass_scrip": 0,
		"memory_salt": 0,
	})
	_prepare_surplus_garrison_town(session)
	_mark_contestable_resources(session)
	var state := _enemy_state(session)
	state["pressure"] = 0
	state["raid_counter"] = 0
	state["commander_counter"] = 0
	state.erase("hero_task_state")
	_update_enemy_state(session, state)

	var plan_result := EnemyAdventureRules.plan_enemy_hero_task_board(session, config, state)
	if int(plan_result.get("planned_count", 0)) < 1:
		_fail("Expected planned tasks before surplus-garrison mobilization, got %s" % JSON.stringify(plan_result))
		return {}
	_update_enemy_state(session, plan_result.get("state", {}))
	var town := _town_by_id(session, DUSKFEN)
	if not (town.get("available_recruits", {}) is Dictionary) or not Dictionary(town.get("available_recruits", {})).is_empty():
		_fail("Surplus-garrison fixture should have no recruitable units: %s" % JSON.stringify(town.get("available_recruits", {})))
		return {}
	var destination := EnemyTurnRules._choose_recruit_destination_breakdown(session, config, town, FACTION_ID)
	if String(destination.get("type", "")) != "planned":
		_fail("Expected surplus-garrison town to choose planned preparation, got %s" % JSON.stringify(destination))
		return {}
	var actor_id := String(destination.get("roster_hero_id", ""))
	var before_strength := _commander_strength(session, actor_id)
	var before_garrison_strength := EnemyTurnRules._army_strength(town.get("garrison", []))
	var defense_target := int(destination.get("defense_target", 0))
	var treasury: Dictionary = _enemy_state(session).get("treasury", {}) if _enemy_state(session).get("treasury", {}) is Dictionary else {}
	EnemyTurnRules._reinforcement_profile_begin(true)
	var recruit_result := EnemyTurnRules._recruit_town_forces(session, config, town, treasury, FACTION_ID)
	var mobilize_profile := EnemyTurnRules._reinforcement_profile_finish()
	var mobilize_counts: Dictionary = mobilize_profile.get("counts", {}) if mobilize_profile.get("counts", {}) is Dictionary else {}
	if int(recruit_result.get("mobilized_batches", 0)) < 1:
		_fail("Expected surplus garrison to mobilize into planned commander prep, got %s" % JSON.stringify(recruit_result))
		return {}
	if int(mobilize_counts.get("destination_commander_roster_invalidated", 0)) < 1:
		_fail("Real surplus-garrison field transfer did not invalidate its destination roster context: %s" % JSON.stringify(mobilize_profile))
		return {}
	var after_strength := _commander_strength(session, actor_id)
	if after_strength <= before_strength:
		_fail("Surplus garrison mobilization did not increase commander continuity: before=%d after=%d actor=%s" % [before_strength, after_strength, actor_id])
		return {}
	var mobilized_town: Dictionary = recruit_result.get("town", {}) if recruit_result.get("town", {}) is Dictionary else {}
	var after_garrison_strength := EnemyTurnRules._army_strength(mobilized_town.get("garrison", []))
	if after_garrison_strength >= before_garrison_strength:
		_fail("Surplus garrison mobilization did not consume actual town garrison: before=%d after=%d" % [before_garrison_strength, after_garrison_strength])
		return {}
	if after_garrison_strength < defense_target:
		_fail("Surplus garrison mobilization stripped below defense target: target=%d after=%d" % [defense_target, after_garrison_strength])
		return {}
	if not Dictionary(mobilized_town.get("available_recruits", {})).is_empty():
		_fail("Surplus garrison mobilization should not create or consume recruit pool entries: %s" % JSON.stringify(mobilized_town.get("available_recruits", {})))
		return {}
	var prepared_event := _event_by_type(recruit_result.get("events", []), "ai_commander_prepared")
	if prepared_event.is_empty():
		_fail("Surplus garrison mobilization did not emit ai_commander_prepared: %s" % JSON.stringify(recruit_result.get("events", [])))
		return {}
	var reason_codes := _string_array(prepared_event.get("target_reason_codes", []))
	if reason_codes.is_empty():
		reason_codes = _string_array(prepared_event.get("reason_codes", []))
	if "surplus_garrison_mobilization" not in reason_codes:
		_fail("Surplus garrison event missed reason code: %s" % JSON.stringify(prepared_event))
		return {}
	return {
		"case_id": "surplus_garrison_prepares_planned_commander_without_recruits",
		"actor_id": actor_id,
		"before_strength": before_strength,
		"after_strength": after_strength,
		"before_garrison_strength": before_garrison_strength,
		"after_garrison_strength": after_garrison_strength,
		"defense_target": defense_target,
		"mobilized_batches": int(recruit_result.get("mobilized_batches", 0)),
		"destination_commander_roster_invalidated": int(mobilize_counts.get("destination_commander_roster_invalidated", 0)),
		"event_type": String(prepared_event.get("event_type", "")),
		"reason_codes": reason_codes,
	}

func _recruitment_and_surplus_garrison_prepare_same_commander() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	_set_enemy_treasury(session, TREASURY)
	_prepare_recruiting_surplus_garrison_town(session)
	_mark_contestable_resources(session)
	var state := _enemy_state(session)
	state["pressure"] = 0
	state["raid_counter"] = 0
	state["commander_counter"] = 0
	state.erase("hero_task_state")
	_update_enemy_state(session, state)

	var plan_result := EnemyAdventureRules.plan_enemy_hero_task_board(session, config, state)
	if int(plan_result.get("planned_count", 0)) < 1:
		_fail("Expected planned tasks before post-recruit surplus mobilization, got %s" % JSON.stringify(plan_result))
		return {}
	_update_enemy_state(session, plan_result.get("state", {}))
	var town := _town_by_id(session, DUSKFEN)
	var destination := EnemyTurnRules._choose_recruit_destination_breakdown(session, config, town, FACTION_ID)
	if String(destination.get("type", "")) != "planned":
		_fail("Expected recruit-plus-surplus town to choose planned preparation, got %s" % JSON.stringify(destination))
		return {}
	var actor_id := String(destination.get("roster_hero_id", ""))
	var before_strength := _commander_strength(session, actor_id)
	var before_garrison_strength := EnemyTurnRules._army_strength(town.get("garrison", []))
	var defense_target := int(destination.get("defense_target", 0))
	var treasury := TREASURY.duplicate(true)
	var recruit_result := EnemyTurnRules._recruit_town_forces(session, config, town, treasury, FACTION_ID)
	if int(recruit_result.get("planned_batches", 0)) < 1:
		_fail("Expected normal recruitment to prepare planned commander before reserve mobilization: %s" % JSON.stringify(recruit_result))
		return {}
	if int(recruit_result.get("mobilized_batches", 0)) < 1:
		_fail("Expected post-recruit surplus mobilization to continue preparing planned commander: %s" % JSON.stringify(recruit_result))
		return {}
	var after_strength := _commander_strength(session, actor_id)
	if after_strength <= before_strength:
		_fail("Recruit-plus-surplus prep did not increase commander continuity: before=%d after=%d actor=%s" % [before_strength, after_strength, actor_id])
		return {}
	var mobilized_town: Dictionary = recruit_result.get("town", {}) if recruit_result.get("town", {}) is Dictionary else {}
	var after_garrison_strength := EnemyTurnRules._army_strength(mobilized_town.get("garrison", []))
	if after_garrison_strength >= before_garrison_strength:
		_fail("Post-recruit surplus mobilization did not consume actual town garrison: before=%d after=%d" % [before_garrison_strength, after_garrison_strength])
		return {}
	if after_garrison_strength < defense_target:
		_fail("Post-recruit surplus mobilization stripped below defense target: target=%d after=%d" % [defense_target, after_garrison_strength])
		return {}
	var prepared_events := _events_by_type(recruit_result.get("events", []), "ai_commander_prepared")
	if prepared_events.size() < 2:
		_fail("Expected recruit and surplus commander-prepared events, got %s" % JSON.stringify(recruit_result.get("events", [])))
		return {}
	var surplus_event := _event_with_reason(prepared_events, "surplus_garrison_mobilization")
	if surplus_event.is_empty():
		_fail("Post-recruit surplus mobilization event missed reason code: %s" % JSON.stringify(prepared_events))
		return {}
	return {
		"case_id": "recruitment_and_surplus_garrison_prepare_same_commander",
		"actor_id": actor_id,
		"before_strength": before_strength,
		"after_strength": after_strength,
		"before_garrison_strength": before_garrison_strength,
		"after_garrison_strength": after_garrison_strength,
		"defense_target": defense_target,
		"planned_batches": int(recruit_result.get("planned_batches", 0)),
		"mobilized_batches": int(recruit_result.get("mobilized_batches", 0)),
		"prepared_event_count": prepared_events.size(),
		"surplus_reason_codes": _event_reason_codes(surplus_event),
	}

func _recruitment_unit_priority_follows_destination() -> Dictionary:
	var config := _enemy_config()
	var garrison_destination := {
		"type": "garrison",
		"decision_rule": "critical_garrison_gap",
		"reason_codes": ["garrison_safety"],
	}
	var magic_artifact_destination := {
		"type": "planned",
		"target_kind": "artifact",
		"reason_codes": ["artifact_pressure", "magic_support"],
		"commander_fit_bonus": 80,
		"commander_fit_profile": "hexcaller/magic",
	}
	var cutthroat_garrison_score := EnemyTurnRules._recruit_priority_for_destination(
		"unit_blackbranch_cutthroat",
		config,
		FACTION_ID,
		garrison_destination
	)
	var slinger_garrison_score := EnemyTurnRules._recruit_priority_for_destination(
		"unit_mire_slinger",
		config,
		FACTION_ID,
		garrison_destination
	)
	var cutthroat_magic_score := EnemyTurnRules._recruit_priority_for_destination(
		"unit_blackbranch_cutthroat",
		config,
		FACTION_ID,
		magic_artifact_destination
	)
	var slinger_magic_score := EnemyTurnRules._recruit_priority_for_destination(
		"unit_mire_slinger",
		config,
		FACTION_ID,
		magic_artifact_destination
	)
	if cutthroat_garrison_score <= slinger_garrison_score:
		_fail("Garrison destination should prefer sturdier melee over ranged support: cutthroat=%f slinger=%f" % [cutthroat_garrison_score, slinger_garrison_score])
		return {}
	if slinger_magic_score <= cutthroat_magic_score:
		_fail("Magic artifact preparation should prefer ranged support over generic melee: slinger=%f cutthroat=%f" % [slinger_magic_score, cutthroat_magic_score])
		return {}
	return {
		"case_id": "recruitment_unit_priority_changes_by_destination",
		"garrison_preferred_unit": "unit_blackbranch_cutthroat",
		"garrison_cutthroat_score": cutthroat_garrison_score,
		"garrison_slinger_score": slinger_garrison_score,
		"magic_artifact_preferred_unit": "unit_mire_slinger",
		"magic_slinger_score": slinger_magic_score,
		"magic_cutthroat_score": cutthroat_magic_score,
	}

func _market_backed_recruitment_covers_unit_material_cost() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	var treasury := {
		"gold": 2000,
		"wood": 0,
		"ore": 0,
		"aetherglass": 0,
		"embergrain": 0,
		"peatwax": 0,
		"verdant_grafts": 0,
		"brass_scrip": 0,
		"memory_salt": 0,
	}
	_prepare_market_recruiting_town(session)
	var town := _town_by_id(session, DUSKFEN)
	var direct_count := EnemyTurnRules._max_affordable_from_pool(treasury, ContentService.get_unit(MARKET_WOOD_UNIT).get("cost", {}))
	if direct_count != 0:
		_fail("Market recruitment fixture expected direct raw-stock affordability to be zero, got %d" % direct_count)
		return {}
	var report := EnemyTurnRules.town_recruitment_pressure_report(session, config, town, treasury.duplicate(true), FACTION_ID)
	var selected: Dictionary = report.get("selected_recruitment", {}) if report.get("selected_recruitment", {}) is Dictionary else {}
	if String(selected.get("unit_id", "")) != MARKET_WOOD_UNIT or int(selected.get("recruit_count", 0)) <= 0:
		_fail("Recruitment pressure report did not treat market-backed unit as affordable: %s" % JSON.stringify(report))
		return {}
	var recruit_result := EnemyTurnRules._recruit_town_forces(session, config, town, treasury, FACTION_ID)
	var recruited_town: Dictionary = recruit_result.get("town", {}) if recruit_result.get("town", {}) is Dictionary else {}
	var recruited_count := _garrison_count(recruited_town, MARKET_WOOD_UNIT)
	if recruited_count <= 0:
		_fail("Market-backed recruitment did not add wood-cost units to the garrison: %s" % JSON.stringify(recruit_result))
		return {}
	var market_usage: Dictionary = recruited_town.get("market_usage", {}) if recruited_town.get("market_usage", {}) is Dictionary else {}
	var buy_usage: Dictionary = market_usage.get("buy", {}) if market_usage.get("buy", {}) is Dictionary else {}
	if int(buy_usage.get("wood", 0)) < recruited_count:
		_fail("Market-backed recruitment did not consume wood buy cap: count=%d usage=%s" % [recruited_count, JSON.stringify(market_usage)])
		return {}
	if int(treasury.get("wood", 0)) != 0:
		_fail("Market-backed recruitment should spend bought wood immediately, treasury=%s" % JSON.stringify(treasury))
		return {}
	return {
		"case_id": "market_backed_recruitment_covers_unit_material_cost",
		"unit_id": MARKET_WOOD_UNIT,
		"direct_affordable_count": direct_count,
		"reported_recruit_count": int(selected.get("recruit_count", 0)),
		"actual_recruited_count": recruited_count,
		"market_buy_wood": int(buy_usage.get("wood", 0)),
		"gold_after": int(treasury.get("gold", 0)),
	}

func _critical_garrison_still_wins() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	_set_enemy_treasury(session, TREASURY)
	_prepare_critical_recruiting_town(session)
	_mark_contestable_resources(session)
	var state := _enemy_state(session)
	state.erase("hero_task_state")
	_update_enemy_state(session, state)
	var plan_result := EnemyAdventureRules.plan_enemy_hero_task_board(session, config, state)
	_update_enemy_state(session, plan_result.get("state", {}))
	var destination := EnemyTurnRules._choose_recruit_destination_breakdown(
		session,
		config,
		_town_by_id(session, DUSKFEN),
		FACTION_ID
	)
	if String(destination.get("type", "")) != "garrison" or String(destination.get("decision_rule", "")) != "critical_garrison_gap":
		_fail("Critical garrison should outrank planned prep, got %s" % JSON.stringify(destination))
		return {}
	if float(destination.get("planned_score", 0.0)) <= 0.0:
		_fail("Critical garrison case should still expose planned prep pressure, got %s" % JSON.stringify(destination))
		return {}
	return {
		"case_id": "critical_garrison_blocks_planned_task_prep",
		"destination_type": String(destination.get("type", "")),
		"decision_rule": String(destination.get("decision_rule", "")),
		"planned_score": float(destination.get("planned_score", 0.0)),
	}

func _prepared_saved_task_launches_below_pressure() -> Dictionary:
	var session = _base_session()
	var config := _high_threshold_config()
	_set_enemy_treasury(session, TREASURY)
	_prepare_ready_launch_recruiting_town(session)
	_mark_contestable_resources(session)
	var state := _enemy_state(session)
	state["pressure"] = 0
	state["raid_counter"] = 1
	state["commander_counter"] = 0
	state.erase("hero_task_state")
	_update_enemy_state(session, state)
	var plan_result := EnemyAdventureRules.plan_enemy_hero_task_board(session, config, state)
	if int(plan_result.get("planned_count", 0)) < 1:
		_fail("Expected planned tasks before ready launch, got %s" % JSON.stringify(plan_result))
		return {}
	_update_enemy_state(session, plan_result.get("state", {}))
	var town := _town_by_id(session, DUSKFEN)
	var destination := EnemyTurnRules._choose_recruit_destination_breakdown(session, config, town, FACTION_ID)
	if String(destination.get("type", "")) != "planned":
		_fail("Ready-launch setup did not choose planned preparation: %s" % JSON.stringify(destination))
		return {}
	var actor_id := String(destination.get("roster_hero_id", ""))
	var treasury := TREASURY.duplicate(true)
	var recruit_result := EnemyTurnRules._recruit_town_forces(session, config, town, treasury, FACTION_ID)
	if int(recruit_result.get("planned_batches", 0)) < 1:
		_fail("Ready-launch setup did not prepare a commander: %s" % JSON.stringify(recruit_result))
		return {}
	var prepared_strength := _commander_strength(session, actor_id)
	state = _enemy_state(session)
	state["pressure"] = 0
	_update_enemy_state(session, state)
	var ready_report := EnemyTurnRules._planned_task_launch_ready_report(session, config, state, FACTION_ID)
	if ready_report.is_empty():
		_fail("Prepared planned task was not launch-ready below pressure: actor=%s strength=%d" % [actor_id, prepared_strength])
		return {}
	var raid_ids: Array = config.get("raid_encounter_ids", []) if config.get("raid_encounter_ids", []) is Array else []
	if raid_ids.size() < 2:
		_fail("Ready-launch template-lock fixture needs multiple raid templates: %s" % JSON.stringify(config))
		return {}
	var rotated_encounter_id := String(raid_ids[int(state.get("raid_counter", 0)) % raid_ids.size()])
	var locked_encounter_id := String(ready_report.get("base_encounter_id", ""))
	if locked_encounter_id == "" or locked_encounter_id == rotated_encounter_id:
		_fail("Ready-launch fixture did not prove template rotation risk: ready=%s rotated=%s" % [JSON.stringify(ready_report), rotated_encounter_id])
		return {}
	if not EnemyTurnRules._can_launch_raid(session, config, state, FACTION_ID):
		_fail("Ready planned task could not launch below generic pressure: %s" % JSON.stringify(ready_report))
		return {}
	var before_raids := _active_raid_count(session)
	var spawn_result := EnemyTurnRules._spawn_raid(session, config, state)
	var after_raids := _active_raid_count(session)
	if after_raids <= before_raids:
		_fail("Ready planned task did not spawn below generic pressure: %s" % JSON.stringify(spawn_result))
		return {}
	var launched_actor_id := String(ready_report.get("actor_id", actor_id))
	var raid := _raid_for_actor_target(
		session,
		launched_actor_id,
		String(ready_report.get("target_kind", "")),
		String(ready_report.get("target_id", ""))
	)
	if raid.is_empty():
		_fail("Ready planned task did not produce its matching raid: ready=%s spawn=%s" % [JSON.stringify(ready_report), JSON.stringify(spawn_result)])
		return {}
	if String(raid.get("enemy_commander_state", {}).get("roster_hero_id", "")) != launched_actor_id:
		_fail("Ready launch used the wrong commander: expected=%s raid=%s" % [launched_actor_id, JSON.stringify(raid)])
		return {}
	if String(raid.get("target_placement_id", "")) != String(ready_report.get("target_id", "")):
		_fail("Ready launch did not preserve planned target: ready=%s raid=%s" % [JSON.stringify(ready_report), JSON.stringify(raid)])
		return {}
	if String(raid.get("encounter_id", "")) != locked_encounter_id:
		_fail("Ready launch did not preserve the prepared host template: ready=%s rotated=%s raid=%s" % [JSON.stringify(ready_report), rotated_encounter_id, JSON.stringify(raid)])
		return {}
	if _event_by_type(spawn_result.get("events", []), "ai_target_assigned").is_empty():
		_fail("Ready launch did not emit target assignment: %s" % JSON.stringify(spawn_result.get("events", [])))
		return {}
	return {
		"case_id": "prepared_saved_task_launches_below_generic_pressure",
		"pressure": int(state.get("pressure", 0)),
		"raid_threshold": int(config.get("raid_threshold", 0)),
		"actor_id": launched_actor_id,
		"prepared_strength": prepared_strength,
		"target_strength": int(ready_report.get("target_strength", 0)),
		"locked_encounter_id": locked_encounter_id,
		"rotated_encounter_id": rotated_encounter_id,
		"spawned_encounter_id": String(raid.get("encounter_id", "")),
		"target_kind": String(ready_report.get("target_kind", "")),
		"target_id": String(ready_report.get("target_id", "")),
		"active_raids_before": before_raids,
		"active_raids_after": after_raids,
	}

func _prepared_saved_task_launch_moves_same_turn() -> Dictionary:
	var session = _base_session()
	var config := _high_threshold_config()
	_set_enemy_treasury(session, TREASURY)
	_prepare_ready_launch_recruiting_town(session)
	_mark_contestable_resources(session)
	var state := _enemy_state(session)
	state["pressure"] = 0
	state["raid_counter"] = 1
	state["commander_counter"] = 0
	state.erase("hero_task_state")
	_update_enemy_state(session, state)
	var result := EnemyTurnRules._run_empire_cycle(session, config, state, false)
	var events: Array = result.get("events", []) if result.get("events", []) is Array else []
	var assigned_index := _event_index(events, "ai_target_assigned")
	var prepared_index := _event_index(events, "ai_commander_prepared")
	if prepared_index < 0:
		_fail("Same-turn launch movement did not prepare a commander: %s" % JSON.stringify(_event_types(events)))
		return {}
	if assigned_index < 0:
		_fail("Same-turn launch movement did not emit target assignment: %s" % JSON.stringify(_event_types(events)))
		return {}
	var launched := _first_active_raid_with_days(session, 1)
	if launched.is_empty():
		_fail("Same-turn launch movement did not leave an advanced active raid: %s" % JSON.stringify(session.overworld.get("encounters", [])))
		return {}
	if _raid_on_spawn_point(config, launched):
		_fail("Same-turn launched raid remained on its spawn point: %s" % JSON.stringify(launched))
		return {}
	if int(launched.get("goal_distance", 9999)) >= 9999 and not bool(launched.get("arrived", false)):
		_fail("Same-turn launched raid did not receive a live route target: %s" % JSON.stringify(launched))
		return {}
	return {
		"case_id": "prepared_saved_task_launch_moves_same_turn",
		"placement_id": String(launched.get("placement_id", "")),
		"target_kind": String(launched.get("target_kind", "")),
		"target_id": String(launched.get("target_placement_id", "")),
		"days_active": int(launched.get("days_active", 0)),
		"goal_distance": int(launched.get("goal_distance", 9999)),
		"position": {"x": int(launched.get("x", 0)), "y": int(launched.get("y", 0))},
		"event_types": _event_types(events),
	}

func _passive_generated_encounters_do_not_block_ready_launch() -> Dictionary:
	var session = _base_session()
	var config := _high_threshold_config()
	_set_enemy_treasury(session, TREASURY)
	_prepare_ready_launch_recruiting_town(session)
	_mark_contestable_resources(session)
	var state := _enemy_state(session)
	state["pressure"] = 0
	state["raid_counter"] = 1
	state["commander_counter"] = 0
	state.erase("hero_task_state")
	_update_enemy_state(session, state)
	var plan_result := EnemyAdventureRules.plan_enemy_hero_task_board(session, config, state)
	if int(plan_result.get("planned_count", 0)) < 1:
		_fail("Passive-budget case expected planned tasks, got %s" % JSON.stringify(plan_result))
		return {}
	_update_enemy_state(session, plan_result.get("state", {}))
	var town := _town_by_id(session, DUSKFEN)
	var treasury := TREASURY.duplicate(true)
	var recruit_result := EnemyTurnRules._recruit_town_forces(session, config, town, treasury, FACTION_ID)
	if int(recruit_result.get("planned_batches", 0)) < 1:
		_fail("Passive-budget case did not prepare a planned commander: %s" % JSON.stringify(recruit_result))
		return {}
	state = _enemy_state(session)
	state["pressure"] = 0
	_update_enemy_state(session, state)
	var ready_report := EnemyTurnRules._planned_task_launch_ready_report(session, config, state, FACTION_ID)
	if ready_report.is_empty():
		_fail("Passive-budget case ready task was not launch-ready: %s" % JSON.stringify(state.get("hero_task_state", {})))
		return {}
	var passive_count: int = max(1, int(config.get("max_active_raids", 3)))
	_append_passive_generated_faction_encounters(session, passive_count)
	var pressure_host_count_before := EnemyTurnRules.active_raid_count(session, FACTION_ID)
	if pressure_host_count_before != 0:
		_fail("Passive generated encounters consumed active pressure-host budget: count=%d encounters=%s" % [pressure_host_count_before, JSON.stringify(session.overworld.get("encounters", []))])
		return {}
	if not EnemyTurnRules._can_launch_raid(session, config, state, FACTION_ID):
		_fail("Passive generated encounters blocked a ready saved-task launch: ready=%s" % JSON.stringify(ready_report))
		return {}
	var spawn_result := EnemyTurnRules._spawn_raid(session, config, state)
	var pressure_host_count_after := EnemyTurnRules.active_raid_count(session, FACTION_ID)
	if pressure_host_count_after <= pressure_host_count_before:
		_fail("Ready saved-task launch did not create a pressure host with passive encounters present: %s" % JSON.stringify(spawn_result))
		return {}
	if _event_by_type(spawn_result.get("events", []), "ai_target_assigned").is_empty():
		_fail("Passive-budget ready launch did not emit target assignment: %s" % JSON.stringify(spawn_result.get("events", [])))
		return {}
	return {
		"case_id": "passive_generated_encounters_do_not_block_ready_saved_task_launch",
		"passive_generated_encounter_count": passive_count,
		"pressure_host_count_before": pressure_host_count_before,
		"pressure_host_count_after": pressure_host_count_after,
		"spawn_plan_source": String(spawn_result.get("spawn_plan_source", "")),
		"ready_actor_id": String(ready_report.get("actor_id", "")),
		"ready_target_id": String(ready_report.get("target_id", "")),
	}

func _unplanned_low_pressure_raid_stays_blocked() -> Dictionary:
	var session = _base_session()
	var config := _high_threshold_config()
	_mark_contestable_resources(session)
	var state := _enemy_state(session)
	state["pressure"] = 0
	state["raid_counter"] = 0
	state["commander_counter"] = 0
	state.erase("hero_task_state")
	_update_enemy_state(session, state)
	var ready_report := EnemyTurnRules._planned_task_launch_ready_report(session, config, state, FACTION_ID)
	if not ready_report.is_empty():
		_fail("Unplanned low-pressure case unexpectedly had a ready saved task: %s" % JSON.stringify(ready_report))
		return {}
	if EnemyTurnRules._can_launch_raid(session, config, state, FACTION_ID):
		_fail("Unplanned low-pressure raid bypassed the pressure threshold.")
		return {}
	return {
		"case_id": "unplanned_low_pressure_raid_stays_blocked",
		"pressure": int(state.get("pressure", 0)),
		"raid_threshold": int(config.get("raid_threshold", 0)),
		"ready_report_empty": ready_report.is_empty(),
	}

func _base_session():
	var session = ScenarioFactory.create_session(SCENARIO_ID, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	session.day = 12
	OverworldRules.normalize_overworld_state(session)
	OverworldRules.refresh_fog_of_war(session)
	EnemyTurnRules.normalize_enemy_states(session)
	EnemyAdventureRules.normalize_all_commander_rosters(session)
	return session

func _prepare_safe_recruiting_town(session) -> void:
	_update_duskfen_town(session, {
		"garrison": [
			{"unit_id": "unit_bog_brute", "count": 12},
			{"unit_id": "unit_mire_slinger", "count": 18},
		],
		"available_recruits": {PREP_UNIT: 4},
	})

func _prepare_ready_launch_recruiting_town(session) -> void:
	_update_duskfen_town(session, {
		"garrison": [
			{"unit_id": "unit_bog_brute", "count": 12},
			{"unit_id": "unit_mire_slinger", "count": 18},
		],
		"available_recruits": {PREP_UNIT: 99},
	})

func _prepare_surplus_garrison_town(session) -> void:
	_update_duskfen_town(session, {
		"garrison": [
			{"unit_id": "unit_bog_brute", "count": 90},
			{"unit_id": "unit_mire_slinger", "count": 90},
		],
		"available_recruits": {},
	})

func _prepare_recruiting_surplus_garrison_town(session) -> void:
	_update_duskfen_town(session, {
		"garrison": [
			{"unit_id": "unit_bog_brute", "count": 90},
			{"unit_id": "unit_mire_slinger", "count": 90},
		],
		"available_recruits": {PREP_UNIT: 1},
	})

func _prepare_critical_recruiting_town(session) -> void:
	_update_duskfen_town(session, {
		"garrison": [],
		"available_recruits": {PREP_UNIT: 4},
	})

func _prepare_market_recruiting_town(session) -> void:
	_update_duskfen_town(session, {
		"built_buildings": ["building_town_hall", "building_market_square"],
		"garrison": [],
		"available_recruits": {MARKET_WOOD_UNIT: 2},
		"market_usage": {},
	})

func _prepare_spell_study_town(session) -> void:
	var built_buildings := ["building_town_hall"]
	for building_id in _magic_building_ids_for_town(session, DUSKFEN):
		if building_id not in built_buildings:
			built_buildings.append(building_id)
	_update_duskfen_town(session, {
		"built_buildings": built_buildings,
		"last_build_day": int(session.day),
		"garrison": [
			{"unit_id": "unit_bog_brute", "count": 12},
			{"unit_id": "unit_mire_slinger", "count": 18},
		],
		"available_recruits": {},
	})

func _magic_building_ids_for_town(session, placement_id: String) -> Array:
	var town_state := _town_by_id(session, placement_id)
	var town_template := ContentService.get_town(String(town_state.get("town_id", "")))
	var building_ids := []
	for building_id_value in town_template.get("buildable_building_ids", []):
		var building_id := String(building_id_value)
		var building := ContentService.get_building(building_id)
		if int(building.get("spell_tier", 0)) > 0:
			building_ids.append(building_id)
	return building_ids

func _update_duskfen_town(session, patch: Dictionary) -> void:
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if not (town is Dictionary) or String(town.get("placement_id", "")) != DUSKFEN:
			continue
		for key in patch.keys():
			town[key] = patch[key]
		towns[index] = town
		session.overworld["towns"] = towns
		return
	_fail("Missing town %s" % DUSKFEN)

func _mark_contestable_resources(session) -> void:
	_set_resource_controller(session, "river_free_company", "player")
	_set_resource_controller(session, "river_signal_post", "player")

func _set_resource_controller(session, placement_id: String, faction_id: String) -> void:
	var nodes: Array = session.overworld.get("resource_nodes", [])
	for index in range(nodes.size()):
		var node = nodes[index]
		if not (node is Dictionary) or String(node.get("placement_id", "")) != placement_id:
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
		if state is Dictionary and String(state.get("faction_id", "")) == FACTION_ID:
			state["treasury"] = treasury.duplicate(true)
			states[index] = state
			session.overworld["enemy_states"] = states
			return
	_fail("Could not set enemy treasury")

func _commander_strength(session, actor_id: String) -> int:
	return int(_commander_continuity(session, actor_id).get("current_strength", 0))

func _garrison_count(town: Dictionary, unit_id: String) -> int:
	var count := 0
	for stack in town.get("garrison", []):
		if stack is Dictionary and String(stack.get("unit_id", "")) == unit_id:
			count += int(stack.get("count", 0))
	return count

func _commander_continuity(session, actor_id: String) -> Dictionary:
	for entry in EnemyAdventureRules.commander_roster_for_faction(session, FACTION_ID):
		if entry is Dictionary and String(entry.get("roster_hero_id", "")) == actor_id:
			return EnemyAdventureRules.commander_army_continuity(entry)
	return {}

func _commander_state(session, actor_id: String) -> Dictionary:
	for entry in EnemyAdventureRules.commander_roster_for_faction(session, FACTION_ID):
		if entry is Dictionary and String(entry.get("roster_hero_id", "")) == actor_id:
			var commander: Dictionary = entry.get("commander_state", {}) if entry.get("commander_state", {}) is Dictionary else {}
			return commander
	return {}

func _known_spell_count_by_commander(session) -> Dictionary:
	var counts := {}
	for entry in EnemyAdventureRules.commander_roster_for_faction(session, FACTION_ID):
		if not (entry is Dictionary):
			continue
		var actor_id := String(entry.get("roster_hero_id", ""))
		var commander: Dictionary = entry.get("commander_state", {}) if entry.get("commander_state", {}) is Dictionary else {}
		counts[actor_id] = _known_spell_count(commander)
	return counts

func _known_spell_count(commander_state: Dictionary) -> int:
	var spellbook: Dictionary = commander_state.get("spellbook", {}) if commander_state.get("spellbook", {}) is Dictionary else {}
	var known: Array = spellbook.get("known_spell_ids", []) if spellbook.get("known_spell_ids", []) is Array else []
	return known.size()

func _spell_ids_with_context(spell_ids: Array, context: String) -> Array:
	var output := []
	for spell_id_value in spell_ids:
		var spell_id := String(spell_id_value)
		if spell_id == "":
			continue
		if String(ContentService.get_spell(spell_id).get("context", "")) == context:
			output.append(spell_id)
	return output

func _active_raid_count(session) -> int:
	var count := 0
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary and String(encounter.get("spawned_by_faction_id", "")) == FACTION_ID:
			count += 1
	return count

func _append_passive_generated_faction_encounters(session, count: int) -> void:
	var encounters: Array = session.overworld.get("encounters", []) if session.overworld.get("encounters", []) is Array else []
	for index in range(max(0, count)):
		encounters.append({
			"placement_id": "passive_generated_faction_guard_%d" % index,
			"encounter_id": "encounter_mireclaw_patrol",
			"x": 2 + index,
			"y": 2,
			"spawned_by_faction_id": FACTION_ID,
			"neutral_encounter": {
				"category": "guard",
			},
		})
	session.overworld["encounters"] = encounters

func _append_active_pressure_host(session, placement_id: String, offset: int) -> void:
	var encounters: Array = session.overworld.get("encounters", []) if session.overworld.get("encounters", []) is Array else []
	encounters.append({
		"placement_id": placement_id,
		"encounter_id": "encounter_mire_raid",
		"x": 6 + offset,
		"y": 1,
		"difficulty": "pressure",
		"days_active": 1,
		"spawned_by_faction_id": FACTION_ID,
	})
	session.overworld["encounters"] = encounters

func _remove_active_pressure_hosts(session) -> void:
	var encounters := []
	var resolved = session.overworld.get("resolved_encounters", [])
	for encounter in session.overworld.get("encounters", []):
		if EnemyAdventureRules.is_active_pressure_host(encounter, FACTION_ID, resolved):
			continue
		encounters.append(encounter)
	session.overworld["encounters"] = encounters

func _remove_encounter(session, placement_id: String) -> void:
	var encounters := []
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary and String(encounter.get("placement_id", "")) == placement_id:
			continue
		encounters.append(encounter)
	session.overworld["encounters"] = encounters

func _first_active_raid_with_days(session, minimum_days: int) -> Dictionary:
	for encounter in session.overworld.get("encounters", []):
		if not (encounter is Dictionary):
			continue
		if String(encounter.get("spawned_by_faction_id", "")) != FACTION_ID:
			continue
		if int(encounter.get("days_active", 0)) >= minimum_days:
			return encounter
	return {}

func _raid_on_spawn_point(config: Dictionary, raid: Dictionary) -> bool:
	for point in config.get("spawn_points", []):
		if not (point is Dictionary):
			continue
		if int(point.get("x", -999)) == int(raid.get("x", 0)) and int(point.get("y", -999)) == int(raid.get("y", 0)):
			return true
	return false

func _has_task_for_actor(state: Dictionary, actor_id: String) -> bool:
	var task_state: Dictionary = state.get("hero_task_state", {}) if state.get("hero_task_state", {}) is Dictionary else {}
	for task_value in task_state.get("tasks", []):
		if task_value is Dictionary and String(task_value.get("actor_id", "")) == actor_id:
			return true
	return false

func _town_by_id(session, placement_id: String) -> Dictionary:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("placement_id", "")) == placement_id:
			return town
	_fail("Missing town %s" % placement_id)
	return {}

func _enemy_config() -> Dictionary:
	var scenario := ContentService.get_scenario(SCENARIO_ID)
	for config in scenario.get("enemy_factions", []):
		if config is Dictionary and String(config.get("faction_id", "")) == FACTION_ID:
			return config
	_fail("Could not find enemy config for %s" % FACTION_ID)
	return {}

func _high_threshold_config() -> Dictionary:
	var config := _enemy_config().duplicate(true)
	config["pressure_per_day"] = 0
	config["pressure_per_enemy_town"] = 0
	config["raid_threshold"] = 99
	return config

func _enemy_state(session) -> Dictionary:
	for state in session.overworld.get("enemy_states", []):
		if state is Dictionary and String(state.get("faction_id", "")) == FACTION_ID:
			return state
	_fail("Could not find enemy state for %s" % FACTION_ID)
	return {}

func _update_enemy_state(session, replacement: Dictionary) -> void:
	var states: Array = session.overworld.get("enemy_states", [])
	for index in range(states.size()):
		var state = states[index]
		if state is Dictionary and String(state.get("faction_id", "")) == String(replacement.get("faction_id", "")):
			states[index] = replacement
			session.overworld["enemy_states"] = states
			return
	_fail("Could not update enemy state for %s" % String(replacement.get("faction_id", "")))

func _event_by_type(events: Array, event_type: String) -> Dictionary:
	for event in events:
		if event is Dictionary and String(event.get("event_type", "")) == event_type:
			return event
	return {}

func _events_by_type(events: Variant, event_type: String) -> Array:
	var output := []
	if not (events is Array):
		return output
	for event in events:
		if event is Dictionary and String(event.get("event_type", "")) == event_type:
			output.append(event)
	return output

func _event_with_reason(events: Array, reason_code: String) -> Dictionary:
	for event in events:
		if not (event is Dictionary):
			continue
		if reason_code in _event_reason_codes(event):
			return event
	return {}

func _event_reason_codes(event: Dictionary) -> Array:
	var reason_codes := _string_array(event.get("target_reason_codes", []))
	if reason_codes.is_empty():
		reason_codes = _string_array(event.get("reason_codes", []))
	return reason_codes

func _raid_for_actor_target(session, actor_id: String, target_kind: String, target_id: String) -> Dictionary:
	for encounter in session.overworld.get("encounters", []):
		if not (encounter is Dictionary):
			continue
		if String(encounter.get("spawned_by_faction_id", "")) != FACTION_ID:
			continue
		var commander: Dictionary = encounter.get("enemy_commander_state", {}) if encounter.get("enemy_commander_state", {}) is Dictionary else {}
		if String(commander.get("roster_hero_id", "")) != actor_id:
			continue
		if String(encounter.get("target_kind", "")) != target_kind:
			continue
		if String(encounter.get("target_placement_id", "")) != target_id:
			continue
		return encounter
	return {}

func _event_index(events: Array, event_type: String) -> int:
	for index in range(events.size()):
		var event = events[index]
		if event is Dictionary and String(event.get("event_type", "")) == event_type:
			return index
	return -1

func _event_types(events: Array) -> Array:
	var types := []
	for event in events:
		if not (event is Dictionary):
			continue
		var event_type := String(event.get("event_type", ""))
		if event_type != "":
			types.append(event_type)
	return types

func _string_array(value: Variant) -> Array:
	var output := []
	if not (value is Array):
		return output
	for entry in value:
		var text := String(entry)
		if text != "" and text not in output:
			output.append(text)
	return output

func _fail(message: String) -> void:
	var payload := {"ok": false, "report_id": REPORT_ID, "error": message}
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	_failed = true
	get_tree().quit(1)
