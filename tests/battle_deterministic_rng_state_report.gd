extends Node

const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const BattleAiRulesScript = preload("res://scripts/core/BattleAiRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "BATTLE_DETERMINISTIC_RNG_STATE_REPORT"

var _errors: Array[String] = []
var _cases := {}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_validate_inert_metadata_invariance()
	_validate_consecutive_rolls_and_invalid_paths()
	_validate_player_ai_shared_stream()
	_validate_ai_scoring_mixed_stream_and_ranged()
	_validate_retaliation_draw_order()
	_validate_save_normalize_resume()
	_validate_legacy_missing_field_fallback()
	_validate_corrupt_state_recovery()
	var report := {
		"ok": _errors.is_empty(),
		"cases": _cases,
		"errors": _errors,
	}
	if _errors.is_empty():
		print("%s %s" % [REPORT_ID, JSON.stringify(report)])
	else:
		push_error("%s %s" % [REPORT_ID, JSON.stringify(report)])
	get_tree().quit(0 if _errors.is_empty() else 1)

func _validate_inert_metadata_invariance() -> void:
	var baseline := _battle_session(false)
	BattleRulesScript._ensure_damage_rng_state(baseline, baseline.battle)
	var variant := _clone_session(baseline)
	variant.battle[BattleRulesScript.PRESENTATION_SPEED_KEY] = BattleRulesScript.PRESENTATION_SPEED_INSTANT
	variant.battle[BattleRulesScript.TACTICAL_BRIEFING_KEY] = {
		"signature": "metadata-only-briefing",
		"shown": true,
		"shown_round": 1,
	}
	variant.battle["recent_events"] = ["Metadata-only event text must not reroll damage."]
	var target := BattleRulesScript._get_stack_by_id(variant.battle, "enemy_target")
	var abilities: Array = target.get("abilities", []).duplicate(true)
	if abilities.is_empty():
		abilities.append({"id": "shielding", "name": "Metadata A", "description": "Metadata B"})
	else:
		abilities[0]["name"] = "Renamed only for RNG invariance proof"
		abilities[0]["description"] = "Display text must not participate in the damage stream."
	_set_stack_field(variant.battle, "enemy_target", "abilities", abilities)
	variant.battle = _reverse_dictionary_order(variant.battle)

	var baseline_result := _run_player_attack(baseline)
	var variant_result := _run_player_attack(variant)
	_expect_equal("inert metadata damage", variant_result.get("damage", -1), baseline_result.get("damage", -2))
	_expect_equal("inert metadata state", _rng_state(variant), _rng_state(baseline))
	_expect_equal("inert metadata roll count", _roll_count(variant), 1)
	_cases["inert_metadata"] = {
		"damage": baseline_result.get("damage", 0),
		"state": _rng_state(baseline),
		"roll_count": _roll_count(baseline),
		"presentation_speed_variant": String(variant.battle.get(BattleRulesScript.PRESENTATION_SPEED_KEY, "")),
		"briefing_shown_variant": bool(variant.battle.get(BattleRulesScript.TACTICAL_BRIEFING_KEY, {}).get("shown", false)),
	}

func _validate_consecutive_rolls_and_invalid_paths() -> void:
	var session := _battle_session(false)
	BattleRulesScript._ensure_damage_rng_state(session, session.battle)
	var initial_state := _rng_state(session)
	var attacker := BattleRulesScript._get_stack_by_id(session.battle, "player_attacker")
	var target := BattleRulesScript._get_stack_by_id(session.battle, "enemy_target")
	BattleRulesScript._damage_range_preview(attacker, target, session.battle, false)
	BattleRulesScript._resolve_attack_action(session, attacker, {}, false)
	_expect_equal("preview and invalid state", _rng_state(session), initial_state)
	_expect_equal("preview and invalid roll count", _roll_count(session), 0)

	var rng := BattleRulesScript._damage_rng_for_battle(session)
	var first_damage := BattleRulesScript._calculate_damage(attacker, target, session.battle, rng, false, false, 1)
	var first_state := _rng_state(session)
	var first_count := _roll_count(session)
	var second_damage := BattleRulesScript._calculate_damage(attacker, target, session.battle, rng, false, false, 1)
	var second_state := _rng_state(session)
	_expect_equal("first actual roll count", first_count, 1)
	_expect_equal("second actual roll count", _roll_count(session), 2)
	_expect_true("first roll advances state", first_state != initial_state)
	_expect_true("second roll advances state", second_state != first_state)
	_cases["consecutive_rolls"] = {
		"damage": [first_damage, second_damage],
		"states": [initial_state, first_state, second_state],
		"roll_count": _roll_count(session),
	}

func _validate_player_ai_shared_stream() -> void:
	var player_session := _battle_session(false)
	var ai_session := _battle_session(false, true)
	BattleRulesScript._ensure_damage_rng_state(player_session, player_session.battle)
	BattleRulesScript._ensure_damage_rng_state(ai_session, ai_session.battle)
	var player := _run_player_attack(player_session)
	var ai := _run_ai_attack(ai_session)
	_expect_equal("player AI damage", ai.get("damage", -1), player.get("damage", -2))
	_expect_equal("player AI state", _rng_state(ai_session), _rng_state(player_session))
	_expect_equal("player AI roll count", _roll_count(ai_session), 1)
	_cases["player_ai"] = {
		"damage": player.get("damage", 0),
		"state": _rng_state(player_session),
		"roll_count": _roll_count(player_session),
	}

func _validate_ai_scoring_mixed_stream_and_ranged() -> void:
	var mixed := _battle_session(false)
	_set_stack_field(mixed.battle, "player_attacker", "retaliations", 0)
	_set_stack_field(mixed.battle, "player_attacker", "retaliations_left", 0)
	BattleRulesScript._ensure_damage_rng_state(mixed, mixed.battle)
	var expected := _clone_session(mixed)
	var expected_rng := BattleRulesScript._damage_rng_for_battle(expected)
	var expected_player := BattleRulesScript._get_stack_by_id(expected.battle, "player_attacker")
	var expected_enemy := BattleRulesScript._get_stack_by_id(expected.battle, "enemy_target")
	BattleRulesScript._calculate_damage(expected_player, expected_enemy, expected.battle, expected_rng, false, false, 1)
	BattleRulesScript._calculate_damage(expected_enemy, expected_player, expected.battle, expected_rng, false, false, 1)

	var enemy_before := BattleRulesScript._get_stack_by_id(mixed.battle, "enemy_target")
	var score_state := _rng_state(mixed)
	var score_count := _roll_count(mixed)
	BattleAiRulesScript.choose_enemy_action(mixed.battle, enemy_before, {})
	_expect_equal("AI scoring state", _rng_state(mixed), score_state)
	_expect_equal("AI scoring count", _roll_count(mixed), score_count)
	_run_player_attack(mixed)
	var enemy_after := BattleRulesScript._get_stack_by_id(mixed.battle, "enemy_target")
	var player_after := BattleRulesScript._get_stack_by_id(mixed.battle, "player_attacker")
	var ai_result := BattleRulesScript._resolve_ai_attack(mixed, enemy_after, player_after, false)
	_expect_true("mixed AI attack result", bool(ai_result.get("ok", false)))
	_expect_equal("mixed stream roll count", _roll_count(mixed), 2)
	_expect_equal("mixed stream state", _rng_state(mixed), _rng_state(expected))

	var ranged := _battle_session(false)
	var ranged_attacker := _stack("unit_ember_archer", "player", 0, "player_attacker", 2, 0, 3)
	_set_stack(ranged.battle, "player_attacker", ranged_attacker)
	_set_stack_field(ranged.battle, "enemy_target", "hex", {"q": 6, "r": 3})
	BattleRulesScript._ensure_battle_hex_state(ranged.battle)
	BattleRulesScript._ensure_damage_rng_state(ranged, ranged.battle)
	var ranged_target := BattleRulesScript._get_stack_by_id(ranged.battle, "enemy_target")
	var ranged_result := BattleRulesScript._resolve_attack_action(ranged, ranged_attacker, ranged_target, true)
	_expect_true("ranged primary result", bool(ranged_result.get("ok", false)))
	_expect_equal("ranged primary roll count", _roll_count(ranged), 1)
	_cases["ai_scoring_mixed_and_ranged"] = {
		"mixed_roll_count": _roll_count(mixed),
		"mixed_state": _rng_state(mixed),
		"ranged_roll_count": _roll_count(ranged),
	}

func _validate_retaliation_draw_order() -> void:
	var actual := _battle_session(true)
	BattleRulesScript._ensure_damage_rng_state(actual, actual.battle)
	var expected := _clone_session(actual)
	var expected_rng := BattleRulesScript._damage_rng_for_battle(expected)
	var expected_attacker := BattleRulesScript._get_stack_by_id(expected.battle, "player_attacker")
	var expected_target := BattleRulesScript._get_stack_by_id(expected.battle, "enemy_target")
	BattleRulesScript._calculate_damage(expected_attacker, expected_target, expected.battle, expected_rng, false, false, 1)
	BattleRulesScript._calculate_damage(expected_target, expected_attacker, expected.battle, expected_rng, false, true, 1)
	_run_player_attack(actual)
	_expect_equal("retaliation roll count", _roll_count(actual), 2)
	_expect_equal("retaliation next state", _rng_state(actual), _rng_state(expected))
	_cases["retaliation"] = {
		"roll_count": _roll_count(actual),
		"state": _rng_state(actual),
	}

func _validate_save_normalize_resume() -> void:
	var uninterrupted := _battle_session(false)
	BattleRulesScript._ensure_damage_rng_state(uninterrupted, uninterrupted.battle)
	_run_player_attack(uninterrupted)
	var encoded := JSON.stringify(uninterrupted.to_dict())
	var parsed = JSON.parse_string(encoded)
	var restored := SessionStateStoreScript.SessionData.new()
	restored.from_dict(parsed if parsed is Dictionary else {})
	var state_before_normalize := _rng_state(restored)
	var count_before_normalize := _roll_count(restored)
	var uninterrupted_normalized := BattleRulesScript.normalize_battle_state(uninterrupted)
	var restored_normalized := BattleRulesScript.normalize_battle_state(restored)
	_expect_true("uninterrupted normalization", uninterrupted_normalized)
	_expect_true("restored normalization", restored_normalized)
	_expect_equal("normalize preserves restored state", _rng_state(restored), state_before_normalize)
	_expect_equal("normalize preserves restored count", _roll_count(restored), count_before_normalize)
	_expect_equal("save boundary state", _rng_state(restored), _rng_state(uninterrupted))
	_expect_equal("save boundary count", _roll_count(restored), _roll_count(uninterrupted))

	var uninterrupted_rng := BattleRulesScript._damage_rng_for_battle(uninterrupted)
	var restored_rng := BattleRulesScript._damage_rng_for_battle(restored)
	var uninterrupted_next := BattleRulesScript._calculate_damage(
		BattleRulesScript._get_stack_by_id(uninterrupted.battle, "player_attacker"),
		BattleRulesScript._get_stack_by_id(uninterrupted.battle, "enemy_target"),
		uninterrupted.battle,
		uninterrupted_rng,
		false,
		false,
		1
	)
	var restored_next := BattleRulesScript._calculate_damage(
		BattleRulesScript._get_stack_by_id(restored.battle, "player_attacker"),
		BattleRulesScript._get_stack_by_id(restored.battle, "enemy_target"),
		restored.battle,
		restored_rng,
		false,
		false,
		1
	)
	_expect_equal("save resume next damage", restored_next, uninterrupted_next)
	_expect_equal("save resume next state", _rng_state(restored), _rng_state(uninterrupted))
	_expect_equal("save resume next count", _roll_count(restored), _roll_count(uninterrupted))
	_cases["save_resume"] = {
		"next_damage": uninterrupted_next,
		"state": _rng_state(uninterrupted),
		"roll_count": _roll_count(uninterrupted),
	}

func _validate_legacy_missing_field_fallback() -> void:
	var first := _battle_session(false)
	first.battle["combat_seed"] = 0
	first.battle.erase(BattleRulesScript.DAMAGE_RNG_VERSION_KEY)
	first.battle.erase(BattleRulesScript.DAMAGE_RNG_STATE_KEY)
	first.battle.erase(BattleRulesScript.DAMAGE_RNG_ROLL_COUNT_KEY)
	first.battle.erase(BattleRulesScript.DAMAGE_RNG_INTEGRITY_KEY)
	var second := _clone_session(first)
	second.battle[BattleRulesScript.PRESENTATION_SPEED_KEY] = BattleRulesScript.PRESENTATION_SPEED_FAST
	second.battle["recent_events"] = ["Different legacy metadata"]
	var first_ok := BattleRulesScript.normalize_battle_state(first)
	var second_ok := BattleRulesScript.normalize_battle_state(second)
	_expect_true("legacy first normalization", first_ok)
	_expect_true("legacy second normalization", second_ok)
	_expect_true("legacy seed persisted", int(first.battle.get("combat_seed", 0)) != 0)
	_expect_equal("legacy fallback seed", second.battle.get("combat_seed", 0), first.battle.get("combat_seed", 1))
	_expect_equal("legacy fallback state", _rng_state(second), _rng_state(first))
	_expect_equal("legacy fallback roll count", _roll_count(first), 0)
	_cases["legacy_fallback"] = {
		"combat_seed": int(first.battle.get("combat_seed", 0)),
		"state": _rng_state(first),
		"roll_count": _roll_count(first),
	}

func _validate_corrupt_state_recovery() -> void:
	var baseline := _battle_session(false)
	BattleRulesScript._ensure_damage_rng_state(baseline, baseline.battle)
	var initial_state := _rng_state(baseline)
	var initial_integrity := String(baseline.battle.get(BattleRulesScript.DAMAGE_RNG_INTEGRITY_KEY, ""))
	var corruptions := {
		"noncanonical_state": {BattleRulesScript.DAMAGE_RNG_STATE_KEY: "001"},
		"guard_mismatch": {BattleRulesScript.DAMAGE_RNG_INTEGRITY_KEY: "bad-guard"},
		"count_mismatch": {BattleRulesScript.DAMAGE_RNG_ROLL_COUNT_KEY: 7},
		"future_version": {BattleRulesScript.DAMAGE_RNG_VERSION_KEY: BattleRulesScript.DAMAGE_RNG_VERSION + 1},
	}
	var recovered := {}
	for case_id in corruptions:
		var session := _clone_session(baseline)
		for key in corruptions[case_id]:
			session.battle[key] = corruptions[case_id][key]
		BattleRulesScript._ensure_damage_rng_state(session, session.battle)
		_expect_equal("%s recovered state" % case_id, _rng_state(session), initial_state)
		_expect_equal("%s recovered count" % case_id, _roll_count(session), 0)
		_expect_equal(
			"%s recovered integrity" % case_id,
			String(session.battle.get(BattleRulesScript.DAMAGE_RNG_INTEGRITY_KEY, "")),
			initial_integrity
		)
		recovered[case_id] = true
	_cases["corrupt_state_recovery"] = recovered

func _battle_session(retaliates: bool, ai_attacker: bool = false) -> SessionStateStoreScript.SessionData:
	var session := SessionStateStoreScript.SessionData.new(
		"battle-deterministic-rng-state-report",
		"",
		"hero_report",
		1,
		{"resolved_encounters": []},
		"normal",
		SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	)
	var attacker_side := "enemy" if ai_attacker else "player"
	var target_side := "player" if ai_attacker else "enemy"
	var attacker_id := "enemy_attacker" if ai_attacker else "player_attacker"
	var target_id := "player_target" if ai_attacker else "enemy_target"
	var attacker_q := 5 if ai_attacker else 4
	var target_q := 4 if ai_attacker else 5
	var attacker := _stack("unit_river_guard", attacker_side, 0, attacker_id, 2, attacker_q, 3)
	var target := _stack("unit_bog_brute", target_side, 0, target_id, 10, target_q, 3)
	attacker["unit_hp"] = 100
	attacker["total_health"] = 200
	target["unit_hp"] = 100
	target["total_health"] = 1000
	target["retaliations"] = 1 if retaliates else 0
	target["retaliations_left"] = 1 if retaliates else 0
	session.battle = {
		"encounter_id": "",
		"resolved_key": "",
		"context": {"type": "encounter"},
		"position": {"x": 0, "y": 0},
		"round": 1,
		"max_rounds": 99,
		"distance": 0,
		"terrain": "plains",
		"battlefield_tags": [],
		"combat_seed": 73491021,
		"stacks": [attacker, target],
		"turn_order": [attacker_id],
		"turn_index": 0,
		"active_stack_id": attacker_id,
		"selected_target_id": target_id,
		"recent_events": [],
		"retreat_allowed": true,
		"surrender_allowed": true,
		"player_commander_state": {},
		"enemy_hero": {},
		BattleRulesScript.FIELD_OBJECTIVES_KEY: [],
		BattleRulesScript.PRESENTATION_SPEED_KEY: BattleRulesScript.PRESENTATION_SPEED_NORMAL,
		BattleRulesScript.TACTICAL_BRIEFING_KEY: {"signature": "rng-report", "shown": false, "shown_round": 0},
		BattleRulesScript.STACK_ANIMATION_STATES_KEY: {},
		BattleRulesScript.ANIMATION_EVENT_SERIAL_KEY: 0,
		BattleRulesScript.ANIMATION_EVENT_QUEUE_KEY: [],
	}
	BattleRulesScript._ensure_battle_hex_state(session.battle)
	return session

func _stack(unit_id: String, side: String, index: int, battle_id: String, count: int, q: int, r: int) -> Dictionary:
	var stack: Dictionary = BattleRulesScript._build_battle_stack(
		unit_id,
		count,
		side,
		index,
		{"source_type": "battle_deterministic_rng_state_report"}
	)
	stack["battle_id"] = battle_id
	stack["side"] = side
	stack["hex"] = {"q": q, "r": r}
	return stack

func _run_player_attack(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var attacker := BattleRulesScript._get_stack_by_id(session.battle, "player_attacker")
	var target := BattleRulesScript._get_stack_by_id(session.battle, "enemy_target")
	var health_before := int(target.get("total_health", 0))
	var result := BattleRulesScript._resolve_attack_action(session, attacker, target, false)
	var target_after := BattleRulesScript._get_stack_by_id(session.battle, "enemy_target")
	_expect_true("player attack result", bool(result.get("ok", false)))
	return {
		"damage": health_before - int(target_after.get("total_health", health_before)),
		"roll_count": _roll_count(session),
	}

func _run_ai_attack(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var attacker := BattleRulesScript._get_stack_by_id(session.battle, "enemy_attacker")
	var target := BattleRulesScript._get_stack_by_id(session.battle, "player_target")
	var health_before := int(target.get("total_health", 0))
	var result := BattleRulesScript._resolve_ai_attack(session, attacker, target, false)
	var target_after := BattleRulesScript._get_stack_by_id(session.battle, "player_target")
	_expect_true("AI attack result", bool(result.get("ok", false)))
	return {
		"damage": health_before - int(target_after.get("total_health", health_before)),
		"roll_count": _roll_count(session),
	}

func _clone_session(source: SessionStateStoreScript.SessionData) -> SessionStateStoreScript.SessionData:
	var clone := SessionStateStoreScript.SessionData.new()
	clone.from_dict(source.to_dict())
	return clone

func _reverse_dictionary_order(source: Dictionary) -> Dictionary:
	var reordered := {}
	var keys := source.keys()
	keys.reverse()
	for key in keys:
		reordered[key] = source[key]
	return reordered

func _set_stack_field(battle: Dictionary, battle_id: String, key: String, value: Variant) -> void:
	var stacks: Array = battle.get("stacks", [])
	for index in range(stacks.size()):
		var stack = stacks[index]
		if stack is Dictionary and String(stack.get("battle_id", "")) == battle_id:
			stack[key] = value
			stacks[index] = stack
			battle["stacks"] = stacks
			return
	_fail("Missing stack %s while setting %s." % [battle_id, key])

func _set_stack(battle: Dictionary, battle_id: String, replacement: Dictionary) -> void:
	var stacks: Array = battle.get("stacks", [])
	for index in range(stacks.size()):
		var stack = stacks[index]
		if stack is Dictionary and String(stack.get("battle_id", "")) == battle_id:
			stacks[index] = replacement
			battle["stacks"] = stacks
			return
	_fail("Missing stack %s while replacing it." % battle_id)

func _rng_state(session: SessionStateStoreScript.SessionData) -> String:
	return String(session.battle.get(BattleRulesScript.DAMAGE_RNG_STATE_KEY, ""))

func _roll_count(session: SessionStateStoreScript.SessionData) -> int:
	return int(session.battle.get(BattleRulesScript.DAMAGE_RNG_ROLL_COUNT_KEY, -1))

func _expect_equal(label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		_fail("%s expected %s, got %s." % [label, expected, actual])

func _expect_true(label: String, value: bool) -> void:
	if not value:
		_fail("%s failed." % label)

func _fail(message: String) -> void:
	_errors.append(message)
