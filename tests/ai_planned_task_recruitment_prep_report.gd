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
	var live_turn_case := _live_turn_plans_before_same_turn_recruitment()
	if live_turn_case.is_empty():
		return
	var spell_study_case := _live_enemy_turn_studies_town_spell()
	if spell_study_case.is_empty():
		return
	var planned_case := _planned_task_recruitment_prepares_commander()
	if planned_case.is_empty():
		return
	var surplus_garrison_case := _surplus_garrison_prepares_planned_commander_without_recruits()
	if surplus_garrison_case.is_empty():
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
		"behavior_policy": "town_building_spell_study_and_recruitment_prepare_same_turn_saved_commander_tasks_with_destination_fit_and_ready_tasks_launch_below_generic_pressure_plus_surplus_garrison_mobilization",
		"save_policy": "hero_task_state_live_persist_no_save_migration",
		"cases": [live_turn_case, spell_study_case, planned_case, surplus_garrison_case, unit_fit_case, market_case, garrison_case, ready_launch_case, same_turn_launch_case, unplanned_gate_case],
		"save_version_before": int(SessionStateStore.SAVE_VERSION),
		"save_version_after": int(SessionStateStore.SAVE_VERSION),
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

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
	return {
		"case_id": "live_turn_plans_before_same_turn_recruitment",
		"active_raids_before": active_before,
		"prepared_actor_id": actor_id,
		"prepared_strength": int(continuity.get("current_strength", 0)),
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
	var recruit_result := EnemyTurnRules._recruit_town_forces(session, config, town, treasury, FACTION_ID)
	if int(recruit_result.get("planned_batches", 0)) < 1:
		_fail("Expected planned recruitment batch, got %s" % JSON.stringify(recruit_result))
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
		"event_type": String(prepared_event.get("event_type", "")),
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
	var recruit_result := EnemyTurnRules._recruit_town_forces(session, config, town, treasury, FACTION_ID)
	if int(recruit_result.get("mobilized_batches", 0)) < 1:
		_fail("Expected surplus garrison to mobilize into planned commander prep, got %s" % JSON.stringify(recruit_result))
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
		"event_type": String(prepared_event.get("event_type", "")),
		"reason_codes": reason_codes,
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
	var raid := _raid_for_actor_target(
		session,
		actor_id,
		String(ready_report.get("target_kind", "")),
		String(ready_report.get("target_id", ""))
	)
	if raid.is_empty():
		_fail("Ready planned task did not produce its matching raid: ready=%s" % JSON.stringify(ready_report))
		return {}
	if String(raid.get("enemy_commander_state", {}).get("roster_hero_id", "")) != actor_id:
		_fail("Ready launch used the wrong commander: expected=%s raid=%s" % [actor_id, JSON.stringify(raid)])
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
		"actor_id": actor_id,
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

func _active_raid_count(session) -> int:
	var count := 0
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary and String(encounter.get("spawned_by_faction_id", "")) == FACTION_ID:
			count += 1
	return count

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
