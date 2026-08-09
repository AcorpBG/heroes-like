extends Node

const BattleAutoResolveRulesScript = preload("res://scripts/core/BattleAutoResolveRules.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "BATTLE_QUICK_RESOLVE_RUNTIME_REPORT"
const SCENARIO_ID := "river-pass"
const ENCOUNTER_PLACEMENT_ID := "river_pass_hollow_mire"


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var terminal_case := _validate_deterministic_terminal_resolution()
	if terminal_case.is_empty():
		return
	var failure_case := _validate_non_mutating_failure_boundaries()
	if failure_case.is_empty():
		return
	var live_guard_case := _validate_live_battle_safety_guards()
	if live_guard_case.is_empty():
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"report_id": REPORT_ID,
		"terminal_resolution": terminal_case,
		"non_mutating_failures": failure_case,
		"live_battle_safety": live_guard_case,
	})])
	get_tree().quit(0)


func _validate_deterministic_terminal_resolution() -> Dictionary:
	var fixture := _active_encounter_session()
	if fixture == null:
		return {}
	var first := _clone_session(fixture)
	var second := _clone_session(fixture)
	var resources_before := _resource_snapshot(first)
	var troops_before := _player_battle_troop_count(first.battle)
	var mana_before := _battle_player_mana(first.battle)
	var first_result: Dictionary = BattleAutoResolveRulesScript.resolve_active_battle(first)
	var second_result: Dictionary = BattleAutoResolveRulesScript.resolve_active_battle(second)
	if not bool(first_result.get("ok", false)) or not bool(first_result.get("completed", false)):
		_fail("Quick resolve did not reach a successful terminal state: %s" % JSON.stringify(first_result))
		return {}
	if String(first_result.get("state", "")) != "victory":
		_fail("Authored quick-resolve fixture must end in victory: %s" % JSON.stringify(first_result))
		return {}
	if bool(first_result.get("battle_active", true)) or not first.battle.is_empty():
		_fail("Terminal quick resolve did not clear the active battle payload: %s" % JSON.stringify(first_result))
		return {}
	if int(first_result.get("forbidden_exit_orders", -1)) != 0:
		_fail("Quick resolve attempted a forbidden retreat or surrender: %s" % JSON.stringify(first_result))
		return {}
	var action_counts: Dictionary = first_result.get("action_counts", {}) if first_result.get("action_counts", {}) is Dictionary else {}
	if int(action_counts.get("cast_spell", 0)) <= 0 or action_counts.size() < 2:
		_fail("Quick resolve did not exercise spell use and action diversity: %s" % JSON.stringify(first_result))
		return {}
	var mana_after := _overworld_player_mana(first)
	if mana_after >= mana_before:
		_fail("Terminal quick resolve did not commit actual commander mana spend: before=%d after=%d" % [mana_before, mana_after])
		return {}
	var troops_after := _overworld_player_troop_count(first)
	if troops_after >= troops_before:
		_fail("Terminal quick resolve did not commit any actual player casualties: before=%d after=%d" % [troops_before, troops_after])
		return {}
	var resources_after := _resource_snapshot(first)
	if int(resources_after.get("gold", 0)) < int(resources_before.get("gold", 0)) + 180:
		_fail("Hollow Mire gold reward was not applied by terminal quick resolve: before=%s after=%s" % [JSON.stringify(resources_before), JSON.stringify(resources_after)])
		return {}
	if int(resources_after.get("ore", 0)) < int(resources_before.get("ore", 0)) + 2:
		_fail("Hollow Mire ore reward was not applied by terminal quick resolve: before=%s after=%s" % [JSON.stringify(resources_before), JSON.stringify(resources_after)])
		return {}
	if not bool(first.flags.get("mire_cleared", false)):
		_fail("Hollow Mire objective flag was not advanced by terminal quick resolve.")
		return {}
	if not _array_has_string(first.overworld.get("resolved_encounters", []), ENCOUNTER_PLACEMENT_ID):
		_fail("Hollow Mire encounter was not recorded as resolved after quick resolve.")
		return {}
	if first_result != second_result or JSON.stringify(first.to_dict()) != JSON.stringify(second.to_dict()):
		_fail("Identical quick-resolve sessions diverged. first=%s second=%s" % [JSON.stringify(first_result), JSON.stringify(second_result)])
		return {}
	return {
		"state": String(first_result.get("state", "")),
		"steps": int(first_result.get("steps", 0)),
		"player_orders": int(first_result.get("player_orders", 0)),
		"action_counts": action_counts,
		"mana_before": mana_before,
		"mana_after": mana_after,
		"troops_before": troops_before,
		"troops_after": troops_after,
		"resources_before": resources_before,
		"resources_after": resources_after,
		"objective_flag": bool(first.flags.get("mire_cleared", false)),
		"resolved_encounter": true,
		"forbidden_exit_orders": int(first_result.get("forbidden_exit_orders", -1)),
		"deterministic_terminal_session": true,
	}


func _validate_non_mutating_failure_boundaries() -> Dictionary:
	var invalid_limit_session := _active_encounter_session()
	if invalid_limit_session == null:
		return {}
	var invalid_limit_before := JSON.stringify(invalid_limit_session.to_dict())
	var invalid_limit_result: Dictionary = BattleAutoResolveRulesScript.resolve_active_battle(invalid_limit_session, 0)
	if bool(invalid_limit_result.get("ok", true)) or String(invalid_limit_result.get("stop_reason", "")) != "invalid_step_limit":
		_fail("Non-positive quick-resolve step limit did not return its structured failure: %s" % JSON.stringify(invalid_limit_result))
		return {}
	if JSON.stringify(invalid_limit_session.to_dict()) != invalid_limit_before:
		_fail("Rejected quick-resolve step limit mutated the live session.")
		return {}
	var no_battle_session := ScenarioFactory.create_session(SCENARIO_ID, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	var no_battle_before := JSON.stringify(no_battle_session.to_dict())
	var no_battle_result: Dictionary = BattleAutoResolveRulesScript.resolve_active_battle(no_battle_session)
	if bool(no_battle_result.get("ok", true)) or String(no_battle_result.get("stop_reason", "")) != "no_active_battle":
		_fail("Missing-battle quick resolve did not return its structured failure: %s" % JSON.stringify(no_battle_result))
		return {}
	if JSON.stringify(no_battle_session.to_dict()) != no_battle_before:
		_fail("Rejected missing-battle quick resolve mutated the session.")
		return {}
	return {
		"invalid_step_limit": String(invalid_limit_result.get("stop_reason", "")),
		"no_active_battle": String(no_battle_result.get("stop_reason", "")),
		"helper_boundary_no_mutation": true,
	}


func _validate_live_battle_safety_guards() -> Dictionary:
	var step_limited := _active_encounter_session()
	if step_limited == null:
		return {}
	var step_result: Dictionary = BattleAutoResolveRulesScript.resolve_active_battle(step_limited, 1)
	if bool(step_result.get("completed", true)) or String(step_result.get("stop_reason", "")) != "step_limit_reached":
		_fail("One-step quick resolve did not stop safely at the configured limit: %s" % JSON.stringify(step_result))
		return {}
	if not bool(step_result.get("battle_active", false)) or step_limited.battle.is_empty():
		_fail("Step-limited quick resolve discarded the still-live battle: %s" % JSON.stringify(step_result))
		return {}
	if not BattleRulesScript.normalize_battle_state(step_limited):
		_fail("Step-limited quick resolve left an invalid live battle payload.")
		return {}
	if int(step_result.get("invalid_orders", -1)) != 0:
		_fail("Step-limited quick resolve emitted an invalid player order: %s" % JSON.stringify(step_result))
		return {}
	return {
		"step_limit_state": String(step_result.get("state", "")),
		"step_limit_stop_reason": String(step_result.get("stop_reason", "")),
		"invalid_orders": int(step_result.get("invalid_orders", -1)),
		"action_counts": step_result.get("action_counts", {}),
		"battle_active": true,
		"normalize_resume_valid": true,
	}


func _active_encounter_session() -> SessionStateStoreScript.SessionData:
	var session = ScenarioFactory.create_session(SCENARIO_ID, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	var encounter := _encounter(session, ENCOUNTER_PLACEMENT_ID)
	if encounter.is_empty():
		_fail("Quick-resolve fixture is missing authored encounter %s." % ENCOUNTER_PLACEMENT_ID)
		return null
	session.battle = BattleRulesScript.create_battle_payload(session, encounter)
	session.game_state = "battle"
	if session.battle.is_empty():
		_fail("Quick-resolve fixture could not create an active battle payload.")
		return null
	session.battle[BattleRulesScript.PRESENTATION_SPEED_KEY] = BattleRulesScript.PRESENTATION_SPEED_INSTANT
	session.battle["retreat_allowed"] = true
	session.battle["surrender_allowed"] = true
	return session


func _encounter(session, placement_id: String) -> Dictionary:
	for value in session.overworld.get("encounters", []):
		if value is Dictionary and String(value.get("placement_id", "")) == placement_id:
			return value
	return {}


func _clone_session(source: SessionStateStoreScript.SessionData) -> SessionStateStoreScript.SessionData:
	var clone := SessionStateStoreScript.SessionData.new()
	clone.from_dict(source.to_dict())
	return clone


func _resource_snapshot(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var resources: Dictionary = session.overworld.get("resources", {}) if session.overworld.get("resources", {}) is Dictionary else {}
	return resources.duplicate(true)


func _player_battle_troop_count(battle: Dictionary) -> int:
	var total := 0
	for value in battle.get("stacks", []):
		if value is Dictionary and String(value.get("side", "")) == "player":
			var unit_hp: int = max(1, int(value.get("unit_hp", 1)))
			total += int(ceil(float(max(0, int(value.get("total_health", 0)))) / float(unit_hp)))
	return total


func _overworld_player_troop_count(session: SessionStateStoreScript.SessionData) -> int:
	var army: Dictionary = session.overworld.get("army", {}) if session.overworld.get("army", {}) is Dictionary else {}
	var total := 0
	for value in army.get("stacks", []):
		if value is Dictionary:
			total += max(0, int(value.get("count", 0)))
	return total


func _battle_player_mana(battle: Dictionary) -> int:
	var commander: Dictionary = battle.get("player_commander_state", {}) if battle.get("player_commander_state", {}) is Dictionary else {}
	var spellbook: Dictionary = commander.get("spellbook", {}) if commander.get("spellbook", {}) is Dictionary else {}
	var mana: Dictionary = spellbook.get("mana", {}) if spellbook.get("mana", {}) is Dictionary else {}
	return int(mana.get("current", 0))


func _overworld_player_mana(session: SessionStateStoreScript.SessionData) -> int:
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	var spellbook: Dictionary = hero.get("spellbook", {}) if hero.get("spellbook", {}) is Dictionary else {}
	var mana: Dictionary = spellbook.get("mana", {}) if spellbook.get("mana", {}) is Dictionary else {}
	return int(mana.get("current", 0))


func _array_has_string(value: Variant, expected: String) -> bool:
	if not (value is Array):
		return false
	for item in value:
		if String(item) == expected:
			return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)
